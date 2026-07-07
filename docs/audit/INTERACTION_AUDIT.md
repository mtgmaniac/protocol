# Overload Protocol — Interaction & Coherence Audit

_Compiled 2026-07-07 against the working tree on branch `docs/audit-and-wiki`. Companion to the [knowledge wiki](../wiki/INDEX.md)._

This audit hunts two things: (1) effects that **function correctly but no longer make sense** after a later rebalance or rename (the canonical class: "an item sets max protocol to 8 — a buff when the cap was 7, a debuff now that the cap is 10"), and (2) genuine **interaction bugs** — order-of-operations traps, dead triggers, degenerate combos. It was built from a 100% entity-by-entity read of `data/raw/`, the combat manager, the protocol/dice/targeting code, the beat/reward/save systems, every ability string, and every design doc, cross-checked with `git log`/`blame`.

**Ground-truth basis:** the locked design intent in [`docs/TRUTH.md`](../TRUTH.md), [`docs/INVARIANTS.md`](../INVARIANTS.md), and [`docs/DECISIONS_RESOLVED.md`](../DECISIONS_RESOLVED.md). Where code disagrees with those, **code is "what is," the ground-truth list is "what should be," and the gap is a finding** — a behavior that matches a closed ruling is *not* a finding.

## Statistics

**97 findings** after dedupe: **5 broken · 8 degenerate · 15 dead · 52 confusing · 0 strictly-inverted · 17 needs-Kev-ruling.**

> On the "inverted" class specifically: the codebase has **no literal `setMaxProtocol`/old-cap item** — the hypothetical from the brief does not exist here (verified: no `setMaxProtocol` handler; Rogue Engineer's cap-8 is an *authored per-run override*, not a stale constant). The nearest live instances of "value divorced from the current rule" are the **data-knob-disconnected** family ([A-016](#a-016), [A-017](#a-017), [A-079](#a-079)) and **[A-066 Deep Zero Pin](#a-066)**, whose upside inverted from "always strong" to "situational" when freeze changed from lockout to repeat. All are catalogued below.

**Severity vocabulary:** `broken` = does not work / wrong result · `inverted` = a buff reads as a debuff (or vice-versa) under current constants · `dead` = references a removed system or can never fire · `degenerate` = a combo/order that produces clearly-unintended results · `confusing` = text/behavior or doc/code mismatch that misleads but doesn't malfunction · `NEEDS-KEV-RULING` = ambiguous; might be intentional (listed separately, [below](#needs-kev-ruling)).

**How to read a finding:** `ID — name` → `file:line` → *what it does now* → *why it's wrong/suspect* → **severity** → *one-line fix*. Original per-agent finding ids are kept in parentheses for traceability. Each finding links to the wiki page that documents the system.

---

## 1. Combat engine & resolution

See [combat-resolution.md](../wiki/combat-resolution.md).

### A-001 — Unseeded `randi()` in combat outcomes (determinism fence) {#a-001}
- **Where:** `combat_manager.gd:380` & `:385` (Opening Salvo relic picks its enemy + hero victims), `:2113` (Dead Man's Charge picks the hit hero), `:2640` (`randi_range(1,100)` rolls the nat-20 elite summon chance).
- **Now:** four combat-outcome draws use Godot's **global** RNG, not the seeded `RollProvider` seam. The sim stays reproducible only because `sim_runner.gd` seeds the global RNG per run (a salted 4th stream, added at `58450f7` "close a determinism hole"). Overflow Vent in the same era does it right (`battle_engine.gd:194`, `roll_provider.rand_index`).
- **Why suspect:** INVARIANTS #1 names "`randi()` anywhere in combat/targeting code" as the exact violation shape; live-game rolls are unseeded and frame-order can perturb them relative to the sim.
- **Severity:** NEEDS-KEV-RULING (flagged by 6 agents; see [needs-Kev](#nk-01)) — bless the seeded-global stream or route these four sites through the provider.
- **Fix:** pass the engine's `roll_provider` into these picks (Overflow Vent pattern). → [combat-resolution](../wiki/combat-resolution.md)

### A-002 — `_on_unit_killed` re-entrancy guard swallows nested death processing {#a-002}
- **Where:** `combat_manager.gd:2087-2091` (`_chain_reaction_active` early-return), with hero damage dealt inside the guard at `:2110-2115` (Dead Man's Charge) and enemy damage at `:2157-2170` (Killswitch Relay). (cc-14, items-relics-10)
- **Now:** any unit killed *by* an on-kill effect skips its own `_on_unit_killed` entirely: a hero dying to Dead Man's Charge isn't counted in `record_hero_death`, doesn't clear SPITEFUL grudges, and can't fire Killswitch Relay / Dead Man's Hand; an enemy dying to Relay/Chain splash grants no protocol-on-kill, Chitin Graft, Bounty Chip, or Scavenger drop.
- **Why suspect:** the guard was meant to stop infinite recursion but drops bookkeeping and player-promised triggers, not just recursion.
- **Severity:** degenerate.
- **Fix:** process deaths on a work-queue (iterative), or at minimum record hero deaths / SPITEFUL clears outside the guard. → [combat-resolution](../wiki/combat-resolution.md)

### A-003 — `healLowest` follows a stale selected pick before falling back to lowest {#a-003}
- **Where:** `combat_manager.gd:991-996` (heal path folds `heal_lowest` with `heal_targeted`); contrast `shieldLowest` at `:972-976` which always takes the lowest. (cc-15)
- **Now:** `healLowest` first resolves `selected_target_id` against heroes and only falls back to `_lowest_hp_state` when empty — a stale/auto-assigned ally pick diverts an "11 heal lowest" face to the picked ally instead of the lowest-HP one.
- **Why suspect:** asymmetric with `shieldLowest`; the eff grammar says "heal lowest" is auto-targeted (no pick). Only `shieldLowest` has a regression.
- **Severity:** confusing.
- **Fix:** give `healLowest` its own branch that ignores `selected_target_id`; add the regression. → [combat-resolution](../wiki/combat-resolution.md)

### A-004 — Leech return-tracer can point at the wrong enemy after a cloak retarget {#a-004}
- **Where:** `combat_manager.gd:1299` (`source_id` = the hero's original `selected_target_id`). (cc-17)
- **Now:** if `_hostile_single_target` retargeted (original pick cloaked/dead), the leech feedback draws its drain line from a unit that wasn't hit.
- **Why suspect:** feedback-only, but visually misattributes the drain.
- **Severity:** confusing.
- **Fix:** thread the actual `target_enemy` id into the leech event. → [keywords](../wiki/keywords.md)

### A-005 — Enemy resolution runs reverse slot order (undocumented) {#a-005}
- **Where:** `combat_manager.gd:715-716` (`ordered_enemy_states.reverse()`). (cc-20)
- **Now:** enemies act right-to-left while intents and PACK assignment run left-to-right. Present since the initial commit, no comment.
- **Why suspect:** not wrong, but an undocumented asymmetry that PACK-follow and boss-last timing silently depend on. RATIONALE: unconfirmed.
- **Severity:** confusing.
- **Fix:** add a WHY comment or a DECISIONS entry pinning the order. → [combat-resolution](../wiki/combat-resolution.md)

### A-006 — Overload name-slam fires on *effective* 20, ground-truth says nat-20 {#a-006}
- **Where:** `battle_feedback.gd:92-98` (fires on `zone == "overload"`); zone from effective roll at `combat_manager.gd:2695-2701` (commented "intended"). (cc-18)
- **Now:** verified the slam fires on a natural-20 overload; it ALSO fires on any die nudged/buffed/Set into the overload zone. Code comments + TRUTH's feedback note call this intentional; the locked list says "Nat-20 overload fires the ability-name slam."
- **Why suspect:** ground-truth phrasing vs a coded-and-commented intent with no DECISIONS number.
- **Severity:** NEEDS-KEV-RULING ([NK](#nk-02)) — recommend blessing effective-20 (already commented as intended).
- **Fix:** one-line ruling record. → [combat-resolution](../wiki/combat-resolution.md)

### A-007 — "Audit-enforced" keyword/pick rules aren't in the gated audit {#a-007}
- **Where:** `scripts/debug/audit_ability_keywords.py:74-256` is the only enforcement; `ability_audit.gd:338` checks handled-fields only; `verify_gate.py:39` runs only the Godot audit. (cc-03)
- **Now:** TRUTH + INVARIANTS #3/#12 call the one-keyword and one-pick rules "audit-enforced," but the GDScript audit that `verify_gate`/hooks run never counts keywords or manual picks — only the standalone python script does, and nothing runs it automatically.
- **Why suspect:** an enforcement claim with no gate behind it; a data change violating the budget passes every gated check.
- **Severity:** confusing.
- **Fix:** add `audit_ability_keywords.py` to `verify_gate.py` (or port the two counts into `ability_audit.gd`). → [keywords](../wiki/keywords.md)

---

## 2. Dice, rolls & die statuses

See [dice-and-rolls.md](../wiki/dice-and-rolls.md).

### A-008 — `curseDice` is a dead, unimplemented 5th die-tamper mechanic {#a-008}
- **Where:** `combat_manager.gd:189,1713-1717,2201`; `battle_scene.gd:562-564`; `battle_card_view.gd:80-81`; `enemies.data.schema.json:124`. (cc-02, dp-01, enemies-04)
- **Now:** the handler sets `cursed = true` and logs "roll twice keep lower," but **no roll-twice logic exists** and no enemy in data carries `curseDice` (0 occurrences, never implemented since `253ee07`). Battle_scene clears the flag with zero effect; the only display is in dead code.
- **Why suspect:** triple-dead; and if ever authored it would be a **fifth** dice-suppression mechanic against INVARIANTS #4 (budget spent at jam/rewrite/hijack/freeze).
- **Severity:** dead.
- **Fix:** delete the handler, schema key, `cursed` state/chip, and the targeting hook. → [keywords](../wiki/keywords.md)

### A-009 — BattleEngine spend cores lack freeze-legality guards (UI-only enforcement) {#a-009}
- **Where:** `battle_engine.gd:210,254,266` (`apply_reroll`/`apply_set`/`twin_fates_copy`, no freeze check) vs UI guards `protocol_actions.gd:85,102,112`; `item_enemy_reroll` DOES guard engine-side (`battle_engine.gd:312`). (dp-06, items-relics-15)
- **Now:** the engine will reroll/Set/Twin-Fates-overwrite a frozen die if called directly; only the live UI blocks it. DECISIONS #1 ruled frozen dice immune, but the rule is written only in the UI, not at the shared-rules altitude the sim uses.
- **Why suspect:** a future policy or L2 solver can silently violate the ruling; the A.1 extraction's whole point is one rule written once.
- **Severity:** confusing (latent sim-correctness bug).
- **Fix:** early-return in the three engine methods when the target is frozen. → [dice-and-rolls](../wiki/dice-and-rolls.md)

### A-010 — Set/Nudge freeze-guard window is looser than TRUTH's sentence {#a-010}
- **Where:** `protocol_actions.gd:102,333` guard on `die_freeze_repeat_this_round`; `:85,112` guard on `die_freeze_turns`; TRUTH rule 7 says a frozen die "can't be Rerolled/Set/Twin-Fates-overwritten." (dp-07)
- **Now:** a die frozen *this* round (repeats not started) can still be Nudged and Set for the current action; Reroll and Twin Fates are blocked from the freeze moment. Behaviorally coherent (Nudge/Set shape only this round's zone; the captured raw face is what repeats) but stricter in the doc than in code.
- **Severity:** NEEDS-KEV-RULING ([NK](#nk-03)) — confirm "acts normally the round it is frozen" includes Nudge/Set, then tighten TRUTH to "while repeating."
- **Fix:** doc precision, or align the Set guard to `die_freeze_turns`. → [dice-and-rolls](../wiki/dice-and-rolls.md)

### A-011 — Which raw-20 riders re-fire on every freeze *repeat* {#a-011}
- **Where:** hero side `battle_scene.gd:1445-1450` (`raw_roll==20` → Overload Capacitor +2 PP + `record_nat20()`), `combat_manager.gd:685-688` (Overload Loop resolves twice); enemy side `battle_engine.gd:513-523` keeps a frozen 20 as raw 20, `combat_manager.gd:2628-2641` re-rolls the summon chance each repeat. (dp-08, int-10)
- **Now:** a frozen die repeating a 20 keeps `raw==20` each round, so **every repeat** re-grants +2 Protocol, re-increments the lifetime nat-20 stat, re-doubles under Overload Loop, and (enemy side) re-rolls the reinforcement chance — freeze turns a one-shot crit rider into a per-round engine.
- **Why suspect:** "acts again on that same result" arguably includes crit riders (crit-banking is the sim's sanctioned Root Access counter), but stat inflation, per-repeat protocol income, and a **re-rolled probability** likely aren't intended.
- **Severity:** NEEDS-KEV-RULING ([NK](#nk-04)) — one ruling for all raw-20/summon riders under repeat.
- **Fix:** if unintended, gate the riders on `not die_freeze_repeat_this_round`. → [dice-and-rolls](../wiki/dice-and-rolls.md)

### A-012 — Raw-20 riders fire on dice whose face was rewritten/jammed away; forced-20s ignore Rewrite {#a-012}
- **Where:** `combat_manager.gd:535-538` (rewrite → effective 3 regardless of raw), `:543-545` (jam caps effective ≤10), `:683-687` (Overload Loop keys on **raw** 20); `battle_scene.gd:1445-1450` (Capacitor/stat on raw); `:1412-1431` (`_apply_roll_relic_overrides` skips only *frozen* dice). (int-04)
- **Now:** (a) a natural 20 on a rewrite-pending die resolves as the face-3 ability but still doubles under Overload Loop, grants Capacitor +2, and bumps the nat-20 stat; jam ≤10 is the same shape. (b) Vengeance Protocol / Dead Man's Hand set the once-per-battle forced 20 on a die the ROOT HIEROPHANT rewrote that round (it rewrites the **highest** die — exactly the forced 20): the "NATURAL 20!" log fires, then the unit acts on a 3, silently eating the relic's one shot.
- **Why suspect:** three raw-keyed hooks and one effective-keyed pipeline disagree about what "natural 20" means when a tamper intervenes.
- **Severity:** degenerate (order-of-operations).
- **Fix:** clear rewrite/jam when a forced 20 lands (or gate the raw-20 riders on the die not being tampered); one ruling for all four hooks. → [dice-and-rolls](../wiki/dice-and-rolls.md)

### A-013 — Twin Fates copy of a 20 is a nat-20 for Overload Loop but not for Capacitor/stats {#a-013}
- **Where:** `battle_engine.gd:266-274` (`twin_fates_copy` writes the raw dict), `combat_manager.gd:683-687` (Loop keys on raw → copied 20 doubles), `battle_scene.gd:557-560` (Capacitor/`record_nat20` scan runs once at roll time, before Twin Fates in the player phase). (int-11)
- **Now:** copying an ally's natural 20 gives the recipient the full crit resolution (double, slam) but not the roll-time nat-20 rewards; two consumer layers disagree on whether the copy "is" a natural 20.
- **Severity:** confusing.
- **Fix:** pick one rule (suggest: a copied 20 is a natural 20 everywhere — re-run the Capacitor scan after a copy). → [dice-and-rolls](../wiki/dice-and-rolls.md)

### A-014 — Nudge phase prompt omits the Reverse Gimbal re-tap {#a-014}
- **Where:** `battle_scene.gd:1853` ("...once per die.") vs the flip path `protocol_actions.gd:334-337`; same omission in `inspect_resolver.gd:22`. (dp-10)
- **Now:** with Reverse Gimbal the same die is re-tappable to flip +3 ↔ −3 (ruled shipping, DECISIONS #11), but the prompt says "once per die" unconditionally.
- **Severity:** confusing.
- **Fix:** append "(Reverse Gimbal: tap again to flip)" when the gear is present. → [dice-and-rolls](../wiki/dice-and-rolls.md)

### A-015 — Stale `sim_runner` comment lumps Overflow Vent with global-RNG consumers {#a-015}
- **Where:** `sim_runner.gd:215-217` vs `battle_engine.gd:194`. (dp-11)
- **Now:** the comment says Overflow Vent draws from the global stream, but the vent was moved onto `roll_provider.rand_index` at the A.1 extraction; Chain Reaction has no randomness at all.
- **Severity:** confusing.
- **Fix:** trim the comment to "summon / Dead Man's Charge / Opening Salvo." → [dice-and-rolls](../wiki/dice-and-rolls.md)

---

## 3. Protocol economy

See [protocol-economy.md](../wiki/protocol-economy.md). **Costs verified correct everywhere** (Nudge 1 / Reroll 2 / Set 3 / item 1 flat); **no old-cap (7/8/12) constant exists on this surface.**

### A-016 — Overload Capacitor amount hardcoded, ignores gear data {#a-016}
- **Where:** `battle_scene.gd:1448-1450` (`_gain_protocol(2)` literal) vs `gear.data.json:26` (`amount: 2`). (dp-03)
- **Now:** the data field is never read; they agree today (2), so no visible bug, but retuning the gear silently does nothing.
- **Severity:** confusing.
- **Fix:** read the amount via the gear lookup (as `protocolOnDieTamper` does). → [protocol-economy](../wiki/protocol-economy.md)

### A-017 — Overflow Vent per-point damage hardcoded, ignores relic data {#a-017}
- **Where:** `battle_engine.gd:189` (`per_point := 2` literal) vs `relics.data.json:175` (`amount: 2`). (dp-04)
- **Now:** the relic's `amount` is dead data.
- **Severity:** confusing.
- **Fix:** `get_relic_value("protocolOverflowDamage","amount",2)`. → [protocol-economy](../wiki/protocol-economy.md)

### A-018 — Battle-start protocol overflow handled differently by source {#a-018}
- **Where:** `battle_scene.gd:247` (gear start protocol raw-clamped, overflow lost, vent never fires) vs `:1375-1378` (intercept start protocol via `_gain_protocol`, vent eligible). (dp-05)
- **Now:** two different overflow rules for one moment (battle start). Reachable with Rogue Engineer cap-8 + Overflow carryover + Mainline Bus + an intercept.
- **Severity:** confusing.
- **Fix:** route gear start protocol through `_gain_protocol` too. → [protocol-economy](../wiki/protocol-economy.md)

### A-019 — Duplicate `MAX_PROTOCOL` / `SET_DIE_COST` constants (engine vs scene) {#a-019}
- **Where:** `battle_engine.gd:17-18` (authoritative) vs `battle_scene.gd:80,91` (UI-string copies). (dp-12)
- **Now:** both define `10` / `3`; a cap/cost change touching one file desyncs the hint text from behavior. **This is the exact drift class the audit hunts — nothing currently mismatches.**
- **Severity:** confusing.
- **Fix:** scene reads `BattleEngine.SET_DIE_COST` / `MAX_PROTOCOL`. → [protocol-economy](../wiki/protocol-economy.md)

### A-020 — Dead protocol/gear effect handlers with no data {#a-020}
- **Where:** `combat_manager.gd:333` (`burnDmgBonus`), `:358` (`protocolOnKillAny`), `:468` (`battleStartCloakRoll`); `battle_engine.gd:384` (item `"ward"`). (dp-09, items-relics-17)
- **Now:** four fully-coded effect paths (each audit-whitelisted "no data yet") that no entry uses.
- **Severity:** dead.
- **Fix:** keep if reserved for future content, else cull with the next protocol audit. → [items-and-gear](../wiki/items-and-gear.md)

---

## 4. Keywords & statuses

See [keywords.md](../wiki/keywords.md) and [statuses-and-chips.md](../wiki/statuses-and-chips.md).

### A-021 — Reserved mechanic words in non-keyword ability names {#a-021}
- **Where:** `enemies.data.json:421` "Venom Nip" (dead DoT flavor), `:817` "Crystal Shatter" (Shatter is Glacier/Cold-Logic only), `:58` "ECM Jam" (no Jam), `:312` "Chain Strike" (no Chain). (cc-08, cc-10, enemies-14)
- **Now:** four player-visible ability names use reserved/dead mechanic words the abilities don't carry. Primer-era players learn keywords by word, so these read as false positives; "Venom" specifically resurrects a flavor TRUTH calls dead. A flavor-name precedent exists (`TASK_QUEUE.md:303` kept "Venom Nip") but predates the keyword primers.
- **Severity:** NEEDS-KEV-RULING ([NK](#nk-05)) — flavor names vs keyword legibility.
- **Fix:** rename if ruled (e.g. Searing Nip / Crystal Break / ECM Hiss / Arc Strike). → [enemies](../wiki/enemies.md)

### A-022 — Chain/heal-lowest/shield-lowest pick lowest HP *ratio*, text says "lowest-HP" {#a-022}
- **Where:** `combat_manager.gd:2312-2339` (`_lowest_hp_state` uses `current/max`) vs `keywords.data.json:15` ("the lowest-HP other enemy"). (cc-11)
- **Now:** with mixed max-HP enemies the jump goes to the lowest **percentage**, not fewest hit points (30/200 beats 20/40). The chain regression uses equal max HP so it can't catch it.
- **Severity:** confusing.
- **Fix:** switch the helpers to absolute HP, or amend the def to "most-wounded." → [keywords](../wiki/keywords.md)

### A-023 — Spike def/engine mismatch on absorbed vs reduced hits {#a-023}
- **Where:** `combat_manager.gd:1793-1801` (dmgReduction early-return, no spike) vs `:1832-1882` (spike fires post-shield-absorption); `keywords.data.json:71` ("any enemy that damages this unit"). (cc-12)
- **Now:** a hit fully absorbed by shields still triggers Spike (deliberate, commented); a hit zeroed by gear reduction returns before the spike read and doesn't. Two edge cases of "damages" pull opposite ways.
- **Severity:** confusing.
- **Fix:** pick one rule (suggest: trigger on any connecting attempt) and align def + reduction path. → [keywords](../wiki/keywords.md)

### A-024 — Spike and flat vs-state riders pay out once *per damage packet* {#a-024}
- **Where:** spike read+fire per `_damage_state` (`combat_manager.gd:1832-1882`); packets of one ability at base `:1256`, detonate `:1458`, execute `:1418`, chain jumps `:1497`; riders per call — Cold Logic `:1815`, Deep Cuts/Shatterpoint `:1822-1830`. (int-07)
- **Now:** a detonate+execute face on a spiked Volt Elite (4) returns 4 **per packet** (up to 12 from one ability); conversely a frozen+burning target eats Cold Logic +4 **and** Shatterpoint +6 **and** Deep Cuts +3 on the base hit, again on the execute packet, again on a detonate burst. Keyword texts are written per-hit; the engine's real unit is the invisible damage packet.
- **Severity:** NEEDS-KEV-RULING ([NK](#nk-06)) — is the packet or the ability the trigger unit?
- **Fix:** debounce per-ability (a memo like `_ability_ward_blocked_ids`) or document packet semantics. → [keywords](../wiki/keywords.md)

### A-025 — Leech does not count chain-jump damage {#a-025}
- **Where:** `combat_manager.gd:1280` (chain call discards dealt HP), `:1282` (leech totals primary+AoE only). (cc-19)
- **Now:** on a face carrying both leech and chain (legal only in overload), the 50% heal ignores the chain hit. No such face exists in data yet — the trap arms silently when one is authored.
- **Severity:** confusing.
- **Fix:** have `_apply_chain_jumps` return dealt HP into `leech_hp_dealt`, or document the exclusion. → [keywords](../wiki/keywords.md)

### A-026 — Dead `venom`/`fire`/`bleed` chip kinds in the card renderer {#a-026}
- **Where:** `compact_unit_card.gd:710` (`kind in ["burn","venom","fire","bleed"]`). (cc-09)
- **Now:** three chip kinds no producer ever emits — dead flavor aliases from the pre-Burn-rename era.
- **Severity:** dead.
- **Fix:** reduce to `kind == "burn"`. → [statuses-and-chips](../wiki/statuses-and-chips.md)

### A-027 — Write-only legacy status strings in `BattleCardView.update_card_view` {#a-027}
- **Where:** `battle_card_view.gd:31-90` (`status_list` etc. built every refresh, never read — only CompactUnitCard renders). (cc-05)
- **Now:** a full legacy list (SH/BRN/RFE/CLOAK/FROZEN/**RAGE**/**CURSED**/TAUNT/FIREWALL/MARK/DOWN) is computed and discarded; it misdocuments the chip set (CURSED and RAGE were never chips) and wastes a per-refresh allocation.
- **Severity:** dead.
- **Fix:** delete the dead locals (keep `chosen_entry`). → [statuses-and-chips](../wiki/statuses-and-chips.md)

### A-028 — Taunt chip: six-chip doctrine vs the locked five {#a-028}
- **Where:** `battle_card_view.gd:384-445`; `docs/TRUTH.md` §UI & feedback. (cc-07, arch-12)
- **Now:** code renders six chips (burn, shield, mark, ±roll, firewall, taunt-on-a-lured-hero); TRUTH lists those six, but the audit's locked ground-truth lists **exactly five** (no Taunt). Additionally, neither a self-taunting hero nor enemy renders any chip — only the *lured* hero does.
- **Severity:** NEEDS-KEV-RULING ([NK](#nk-07)) — is the TAUNT chip canon (doctrine = six), or should enemy-side taunt get a non-chip surface? And should the taunting unit get a marker?
- **Fix:** per ruling; align TRUTH + the ground-truth list. → [statuses-and-chips](../wiki/statuses-and-chips.md)

### A-029 — Hero-side Taunt never expires {#a-029}
- **Where:** `combat_manager.gd:1040-1046` (set), `:2418-2421` (round-end clear is **enemy-only**), `:2175` (cleared on down). (cc-06)
- **Now:** a taunting hero redirects all enemy aim forever (until death or another ally taunts). Enemy self-taunt clears each round end; enemy-side lure lasts one phase — three durations for one unified keyword whose def is a single duration-less sentence.
- **Severity:** NEEDS-KEV-RULING ([NK](#nk-08)) — permanent stance, or clear at round end like enemy self-taunt?
- **Fix:** one line in `_tick_end_of_round_states`, or document the stance in the keyword def. → [keywords](../wiki/keywords.md)

### A-030 — `keywords.data.json` header comment says green is reserved for Protocol {#a-030}
- **Where:** `keywords.data.json:2`. (cc-13)
- **Now:** the comment says "green reserved for Protocol"; INVARIANTS #7 reserves green for HP/heals only — Protocol is **amber**. Stale doctrine in a canonical data file will steer a future styling pass wrong. (Same class: [A-093](#a-093) ANIMATION.md.)
- **Severity:** confusing.
- **Fix:** "(protocol amber; green reserved for HP/heals)". → [keywords](../wiki/keywords.md)

### A-031 — "lifesteal N%" vs "Leech": one mechanic, two player-visible names {#a-031}
- **Where:** 11 enemy abilities with `lifestealPct` 35–55% (`enemies.data.json:411,464,518,574,631,662,686,739,774,1957,2066`); both render the LC Leech pip (`effect_pip.gd:249-253`); TRUTH defines Leech as fixed 50%. (enemies-13)
- **Now:** hero side says "leech" (50%), enemy eff text says "lifesteal 45%," same pip; TRUTH doesn't mention the enemy percent-variant.
- **Severity:** NEEDS-KEV-RULING ([NK](#nk-09)) — unify eff wording to "leech N%," or accept the split and document it in TRUTH.
- **Fix:** one term in eff text + a TRUTH sentence. → [keywords](../wiki/keywords.md)

---

## 5. Shields & Firewall

See [shields-and-ward.md](../wiki/shields-and-ward.md).

### A-032 — Duplicated `shieldsPersist` block in battle-start relic effects {#a-032}
- **Where:** `combat_manager.gd:396-399` and `:403-408` (same `has_relic("shieldsPersist")` loop twice; only the second logs). (cc-04, items-relics-03, heroes-09)
- **Now:** the Mantle Core flag is set twice per battle start — harmless (idempotent) but dead weight and a divergence trap.
- **Severity:** dead.
- **Fix:** delete the first (log-less) block. → [shields-and-ward](../wiki/shields-and-ward.md)

### A-033 — Aegis Field triggers on ENEMY heals — enemy sustain shields your squad {#a-033}
- **Where:** `combat_manager.gd:2224-2249` (the `healGrantsShieldAll` branch at `:2243` has **no side/healer gate**, unlike the two branches above it); enemy heal sites `:713` (regenerative modifier), `:1534` (enemy heal faces), `:1580,1594` (enemy lifesteal); desc `relics.data.json:145` ("Any heal grants all allies 3 shield."). (int-01)
- **Now:** every effective heal of any state — including enemies — grants all living **heroes** +3 shield (further +2 each via Overcharge Mesh). With the REGENERATIVE modifier, 3 enemy heals/round → 9-15 free squad shield/round; any lifesteal enemy arms your defense as it drains you.
- **Why suspect:** the relic reads as player-side synergy; triggering off the opposing side's sustain inverts two enemy identities into player buffs. The literal desc ("Any heal") is why this needs a ruling, not a silent fix.
- **Severity:** degenerate.
- **Fix:** gate the branch on `_is_hero_state(state)` and tighten the desc, or bless the literal reading. → [shields-and-ward](../wiki/shields-and-ward.md)

### A-034 — Mantle Core turns per-round shield drips into an unbounded stacking engine {#a-034}
- **Where:** `combat_manager.gd:2517-2526` (expiry skipped entirely when `shields_persist`); periodic grants Bulwark Aura `:492-496`, Nanite Field→Aegis `:499-503`, Overcharge Mesh `:876-880`; only counter `_wipe_all_hero_shields` `:1967-1976`. (int-02)
- **Now:** without Mantle Core these grants die at the round tick (bounded). With it, every periodic grant accumulates forever — Bulwark Aura alone = +3(+2)/hero/round uncapped; generation quickly exceeds basic-enemy output. Only the 7 `wipeShields` faces reset it; a battle without a wipeShields carrier has no counter.
- **Why suspect:** shields balance on one-round expiry (DECISIONS #2); the single persist exception was ruled for identity, but nothing bounds persist × per-round generators.
- **Severity:** degenerate.
- **Fix:** cap persisted stacks (e.g. max = maxHP), or make periodic-source shields always expire under persist. → [shields-and-ward](../wiki/shields-and-ward.md)

### A-035 — Salvage Rig never fires on Breach-destroyed shields {#a-035}
- **Where:** grant path `combat_manager.gd:1863-1870` (damage-absorb branch only); Breach zeroes stacks at `_breach_shields:1392-1401` with no grant. (items-relics-08)
- **Now:** "+1 Protocol when an enemy shield fully breaks" pays only when damage chews the last point; Breach (the most explicit shield-destruction verb) skips it entirely.
- **Severity:** confusing.
- **Fix:** add the `protocolOnShieldBreak` grant inside `_breach_shields`, or document the exclusion. → [relics](../wiki/relics.md)

---

## 6. Heroes & abilities

See [heroes.md](../wiki/heroes.md). **All 120 live abilities pass the keyword budget and one-pick rule; all ground-truth spot checks (Cover Fire, Pulse chain, Arc-not-Cryo, freeze/±roll line ownership, 32 directives @250 XP) PASS.** Findings are documentation rot, enforcement gaps, and one dead legendary.

### A-036 — `docs/ABILITY_DESCRIPTIONS_FULL.md` is an untracked fossil of a dead data era {#a-036}
- **Where:** the whole file (1491 lines, **untracked** — no git history) + generator `scripts/debug/dump_ability_descriptions.py`. (heroes-01, enemies-17)
- **Now:** claims to show current inspect text but predates the keyword batch: Cryo Specialist, "Spite Guard," freeze "(1 reveal skip)" (dead lockout), "Cloak: 80% chance to evade," multi-round shields "shield, 2t," "DoT" naming, a literal "Retaliate" ability, "cower 1r," "26 dmg (P2 34)" phase-2 numbers.
- **Why suspect:** text lies about behavior on ≥6 dead mechanics; anyone reading it as reference resurrects dead models (INVARIANTS #10).
- **Severity:** dead.
- **Fix:** regenerate from current data and commit, or delete both files — stop it being an untracked landmine. → [heroes](../wiki/heroes.md)

### A-037 — Schema doc-string still cites the dead CRYO callsign {#a-037}
- **Where:** `heroes.data.schema.json:139` ("e.g. CRYO, PYRO"). The `evolutionId` enum correctly has `arc`, no `cryo`. (heroes-02)
- **Severity:** confusing.
- **Fix:** change the example to "(e.g. PYRO, ARC)". → [heroes](../wiki/heroes.md)

### A-038 — Evolution-screen help claims portraits aren't evolved yet {#a-038}
- **Where:** `evolution_screen.gd:122` ("Portraits currently reuse the base unit art...") contradicted by `_get_path_portrait` (`:382-390`) and TRUTH §Assets (24 portraits installed). (heroes-03)
- **Severity:** confusing.
- **Fix:** delete the line or replace with "Each card previews the evolved unit's art." → [heroes](../wiki/heroes.md)

### A-039 — Wideband Hiss eff text omits its 1-turn duration {#a-039}
- **Where:** `heroes.data.json:2512-2521` (eff "all -2 roll", no `rfT`); engine default 1t at `combat_manager.gd:1026`. (heroes-04)
- **Now:** the roll-down lasts exactly 1 turn but the string carries no duration while every other rfe ability writes "2t"/"3t" — a player can't distinguish it from a permanent debuff.
- **Severity:** confusing.
- **Fix:** eff → "all -2 roll, 1t" (+ explicit `rfT: 1`). → [heroes](../wiki/heroes.md)

### A-040 — `heroAbility` schema accepts unknown fields silently {#a-040}
- **Where:** `heroes.data.schema.json:58` (`additionalProperties: true`), while `directive.effect` and `heroDefinition` are `false`. (heroes-06)
- **Now:** a typo'd or smuggled field (`shT`, a resurrected dead-mechanic key) validates clean; `validate-data` can't catch it. The legal-field list is already enumerated.
- **Severity:** confusing (enforcement gap).
- **Fix:** flip to `additionalProperties: false` and run validate-data (heroes file audited clean by hand). → [heroes](../wiki/heroes.md)

### A-041 — Sync Antenna's +3 never reaches the effective roll — the legendary is mechanically dead {#a-041}
- **Where:** `battle_scene.gd:1469-1475` writes `sync_state["roll_buff"] += 3` (a **display cache**); the effective path `battle_engine.gd:453-465` → `combat_manager.gd:550-554` sums `roll_buff_stacks + perm_roll_buff` only — the `roll_buff` field is never read (verified). No audit regression mentions "sync." (int-03)
- **Now:** when two heroes match, the log and three UI surfaces show a phantom +3, but `build_effective_rolls` never sees it. The legendary gear's entire effect is display-only.
- **Severity:** broken.
- **Fix:** grant a real 1-turn stack via `_add_roll_buff(state, 3, 1)` (or a field the effective path reads); add a regression. → [items-and-gear](../wiki/items-and-gear.md)

---

## 7. Directives

See [directives.md](../wiki/directives.md).

### A-042 — "Feedback" directive ticks on OTHER sources' roll-downs {#a-042}
- **Where:** tag set `combat_manager.gd:1175-1176`; tick condition `:2530-2533` (`_get_total_rfe(state) > 0`); tag cleared only when ALL rfe stacks expire `:2548`. (heroes-05)
- **Now:** once the noise carrier tags an enemy, the 2/round chip keeps firing while **any** rfe stack (from any hero, item, or future source) is live — the carrier's own stacks expiring doesn't stop it. Desc says "Enemies under YOUR roll-downs." Latent today (single-Breaker squads have no other rfe source).
- **Severity:** confusing.
- **Fix:** track carrier-attributed rfe stacks, or reword the desc. → [directives](../wiki/directives.md)

---

## 8. Enemies & bosses

See [enemies.md](../wiki/enemies.md), [bosses.md](../wiki/bosses.md), [factions.md](../wiki/factions.md). **Firewall instances (10), spike carriers (4), hijack (3), siphon (Synod only), summon species, ASSEMBLY LINE cadence, and boss escorts all verified correct.**

### A-043 — Bestiary shows old faction names "VOID CIRCLET" / "STELLAR MENAGERIE" {#a-043}
- **Where:** `help_menu.gd:41-42` (`BESTIARY_FACTION_LABEL`). Verified: the labels render literally. (enemies-01)
- **Now:** player-visible section headers use the dead faction names; `battle-modes.json` already labels them "Null Synod" / "The Accretion."
- **Severity:** broken (naming contract).
- **Fix:** label "NULL SYNOD" / "THE ACCRETION" (source from the battle-modes label, not a second constant). → [factions](../wiki/factions.md)

### A-044 — "Circlet Cataclysm" — old faction name inside a boss ability {#a-044}
- **Where:** `enemies.data.json:1683` (ROOT HIEROPHANT surge). Verified. (enemies-02)
- **Now:** player-visible ability name uses the dead "Circlet"; every other Synod string was renamed.
- **Severity:** broken (naming contract).
- **Fix:** rename (e.g. "Synod Cataclysm"); regenerate eff docs. → [bosses](../wiki/bosses.md)

### A-045 — "Reaver Mantle" legacy boss name + duplicated "Total Eclipse" {#a-045}
- **Where:** `enemies.data.json:2054` ("Reaver Mantle," the boss's dead `void_reaver` name), `:2099` "Total Eclipse" == veilNull's `:1080`. (enemies-15)
- **Severity:** confusing.
- **Fix:** rename the MANTLE TYRANT faces. → [bosses](../wiki/bosses.md)

### A-046 — `packBonus` never fires — compares unique runtime ids {#a-046}
- **Where:** `combat_manager.gd:1552-1561` increments `pack_count` only when another state has the same `id`, but every state id is unique (`base#N`, `:750-758`). (enemies-03)
- **Now:** `pack_count` is always 0; the Pumice Macaque / Hound pack-bonus damage never lands — the Accretion pack identity is a no-op.
- **Severity:** dead.
- **Fix:** compare `unit.id` (species) or `enemy_type`, not the runtime state id. → [enemies](../wiki/enemies.md)

### A-047 — `battleEnemyScale` is schema-required dead data {#a-047}
- **Where:** `enemies.data.json:2494-2535` (10 per-battle hp/dmg multipliers); schema requires it (`enemies.data.schema.json:6,18-31`); **zero consumers** in scripts. `AGENTS.md:79` cites a nonexistent sim `--scaled` flag. (enemies-05)
- **Now:** a stale squad-4-era scaling table required by the schema but read by nothing.
- **Severity:** dead.
- **Fix:** delete the table + schema requirement (or wire it); correct `AGENTS.md:79`. → [enemies](../wiki/enemies.md)

### A-048 — `trackHpScale` loaded but never read {#a-048}
- **Where:** `battle-modes.json:12,98,174,256,339` → `DataManager.gd:411` → `operation_data.gd:12`; zero readers. (enemies-06)
- **Now:** parsed into `OperationData.track_hp_scale` and never used; combat uses flat stats every fight.
- **Severity:** dead.
- **Fix:** remove the field + loader line, or wire it. → [operations](../wiki/operations.md)

### A-049 — Forked Double's `summonElite: true` is inert {#a-049}
- **Where:** `enemies.data.json:2398-2407`; gate `combat_manager.gd:2636`. (enemies-10)
- **Now:** the flag is set but the voidGlimmer kit has no `summonChance` in any zone (the only thing the gate checks).
- **Severity:** dead.
- **Fix:** drop the flag, or author the summon. → [enemies](../wiki/enemies.md)

### A-050 — `commsHex` — dead enemyType enum entry {#a-050}
- **Where:** `enemies.data.schema.json:74`; no kit or unit uses it (matches the quarantined `harmonic_hexnode` art). (enemies-11)
- **Severity:** dead.
- **Fix:** remove from the enum. → [enemies](../wiki/enemies.md)

### A-051 — Phase-2 sfx leftover {#a-051}
- **Where:** `AudioManager.gd:12` ("phase2" in the sfx registry) + `assets/audio/sfx/phase2.wav`; the `phase2` event was deleted with the phase-2 system. (enemies-16)
- **Severity:** dead.
- **Fix:** remove the registry entry + quarantine the wav. → [bosses](../wiki/bosses.md)

### A-052 — THE BROOD has a hidden field-cap condition (and borrows the hero squad constant) {#a-052}
- **Where:** `combat_manager.gd:254` (`_battle_round % 3 == 0 and _count_living_enemies() < GameState.SQUAD_UNIT_LIMIT`). (enemies-08)
- **Now:** spawns only on rounds 3/6/9… **and** only below 3 living enemies; the rule text says only "every 3 rounds." The enemy field cap reuses `SQUAD_UNIT_LIMIT` (hero squad size). See also [A-082](#a-082).
- **Severity:** confusing.
- **Fix:** rule text "…every 3 rounds while it has an open slot"; give the enemy cap its own constant. → [bosses](../wiki/bosses.md)

### A-053 — MANTLE TYRANT's freeze renders ICE, not the faction's Petrify {#a-053}
- **Where:** `enemies.data.json:2098-2110` ("Total Eclipse," no `freeze_flavor`); default "ice" at `combat_manager.gd:1637`. Geode Panther correctly sets `petrify`. (enemies-09)
- **Now:** the Accretion boss's squad-wide freeze crusts ice cyan, inconsistent with the faction's petrify identity.
- **Severity:** confusing.
- **Fix:** add `"freeze_flavor": "petrify"` to the overload. → [bosses](../wiki/bosses.md)

### A-054 — Stale summon comment "Veil Concord ... natural 20 only" {#a-054}
- **Where:** `combat_manager.gd:1726`. Synod (4 kits + boss) and Accretion (Pyroclast Raptor) also summon via the same path. (enemies-19)
- **Severity:** confusing.
- **Fix:** update the comment. → [enemies](../wiki/enemies.md)

### A-055 — `grantRampageAll` typed integer in schema, read as boolean {#a-055}
- **Where:** schema `enemies.data.schema.json:119` (integer) vs `combat_manager.gd:1649` (`bool(...)`) and `:1651` (`maxi(grant,1)`). (enemies-20)
- **Now:** works today (bool(1)=true), but authoring `3` still grants exactly 1 charge — the integer is a lie.
- **Severity:** confusing.
- **Fix:** make the schema boolean, or honor the integer as the charge count. → [enemies](../wiki/enemies.md)

### A-056 — TRUTH says Hive carries siphon; no hive kit does {#a-056}
- **Where:** `docs/TRUTH.md:115` vs data — siphon carriers are Synod only (voidWisp/voidAcolyte/voidBinder/voidChanneler). Hive's drain is `lifestealPct` (leech). (enemies-12)
- **Now:** code wins → the TRUTH hive-identity line is stale (conflates lifesteal with Protocol siphon).
- **Severity:** confusing.
- **Fix:** TRUTH hive identity → "burn, leech, summons, spike." → [factions](../wiki/factions.md)

### A-057 — Boss reinforcement rules × on-kill economy = unbounded stall farm {#a-057}
- **Where:** rebuild/brood cadence `combat_manager.gd:240-262`; `_is_basic_enemy` `:1959-1964` (drones + bloodmites qualify); per-kill payouts `:2124-2145` (Kill Switch heal, Bounty Chip +1, Chitin Graft +3), momentum bank `:2152-2155` (`+=`, uncapped); carryover `GameState.gd:757-767` (Overflow Buffer 50%). (int-09)
- **Now:** SCRAPMASTER and MATRIARCH re-supply a basic enemy on a fixed clock forever; a stalling player harvests protocol, heals, and momentum every 2-3 rounds indefinitely and carries 5 protocol into the next battle. Nothing bounds it.
- **Severity:** NEEDS-KEV-RULING ([NK](#nk-10)) — acceptable (bosses still deal damage), or exclude summoned/rebuilt units from kill payouts?
- **Fix:** flag injected states `summoned:true` and skip payouts for them. → [bosses](../wiki/bosses.md)

### A-058 — Battle-start "all enemies" relic effects never touch summoned or rebuilt enemies {#a-058}
- **Where:** battle-start loops run once over the initial roster — `combat_manager.gd:411-416` (Plague Protocol perm burn), `:419-424` (Signal Jam `perm_rfe`), `:435-442` (Entropy Leak 85% HP); `inject_enemy` builds a fresh state without them (`:2652-2666`); `_revive_state` (`:2064`) doesn't reapply, and Signal Jam's `perm_rfe` is also cleared on down (`:2205`). (int-08, cc-16)
- **Now:** every brooded Bloodmite, rebuilt Scrap Drone, and nat-20 elite arrives burn-free, jam-free, full-HP. Against THE BROOD (an endless-summon boss) Plague Protocol silently stops covering the reinforcement stream that *is* the fight; the log still says "permanently."
- **Severity:** confusing.
- **Fix:** apply battle-start enemy relic state inside a shared `inject_enemy`/`_revive_state` helper. → [relics](../wiki/relics.md)

### A-059 — Decoy Beacon skips enemy ACTIONS but not enemy-phase standing rules {#a-059}
- **Where:** the decoy check lives only in the action loop (`combat_manager.gd:721-723`); earlier phase-start hooks still fire — boss roundStart `:645` (OVERSEER ward, MANTLE +6), accrete `:698-704`, HIEROPHANT rewrite `:707`, regenerative heals `:710-713`. (int-12)
- **Now:** on a decoyed round 1 the enemy "wastes its turn," yet MANTLE TYRANT still banks +6 persistent shield, accrete units armor up, and regenerative comps heal (feeding [A-033](#a-033)). The intercept's "whole line wastes turn 1" is only true of dice actions.
- **Severity:** confusing.
- **Fix:** one sentence in the intercept text ("bosses' standing rules still apply"), or move the decoy check above the phase-start hooks. → [beats-and-events](../wiki/beats-and-events.md)

### A-060 — Frozen internal ids `voidCirclet` / `stellarMenagerie` — occurrence inventory {#a-060}
- **Where:** `battle-modes.json` mode keys, `enemies.data.json` kit ids (`void*`, `beast*`), schemas, `DataManager`, `SaveManager`, `targeting_personality`, sim files, `.godot` caches, `legacy-angular/` art. (enemies-21)
- **Now:** per INVARIANTS #11 these ids are **permanent** (saves/telemetry/sim key on them). Recorded as a standing-exemption inventory, not a fix list — the audit brief treats "old faction names anywhere" as findings, but the invariant supersedes for internal ids. Only *player-visible* strings ([A-043](#a-043), [A-044](#a-044), [A-045](#a-045)) are actionable.
- **Severity:** NEEDS-KEV-RULING ([NK](#nk-11)) — confirm the standing exemption; no action expected. → [factions](../wiki/factions.md)

---

## 9. Items, gear & relics

See [items-and-gear.md](../wiki/items-and-gear.md), [relics.md](../wiki/relics.md). **Boss-relic set (exactly 5), boss-relic draft exclusion, no `shT`, no XP-consumable remnants, no old-cap values — all verified clean.**

### A-061 — Defib Spark is unusable — the only `allyDead` item hard-cancels on tap {#a-061}
- **Where:** `protocol_actions.gd:763-765` (unconditional `_cancel_item_targeting`); the scaffolding `PHASE_ITEM_PICK_DEAD` (`battle_scene.gd:82,1960-1962`) is never entered and returns no legal targets. The engine handler works (`battle_engine.gd:392`). Cancel string present since `253ee07`. (items-relics-01)
- **Now:** a drafted uncommon consumable that can never be activated; also strands Mercy Protocol's item-revive half.
- **Severity:** broken.
- **Fix:** wire `"allyDead"` to `PHASE_ITEM_PICK_DEAD` and return dead-hero ids for that phase. → [items-and-gear](../wiki/items-and-gear.md)

### A-062 — Mirror Plate triggers on FRIENDLY ability-freezes; item freezes never trigger it {#a-062}
- **Where:** grant `combat_manager.gd:1326-1332`, called unconditionally from `_freeze_die_state` `:2027`; item path `battle_engine.gd:332-341` (no grant). (items-relics-04)
- **Now:** desc says "When an **enemy** Jams/Rewrites/Freezes this unit's die, gain 2 Protocol," but a hero using a `freezeAnyDice` ability to bank an ally's roll pays the holder +2 every cast (re-freeze re-grants); meanwhile item freezes bypass the grant — the two friendly paths disagree.
- **Severity:** degenerate (text/behavior + free recurring Protocol on an already-good action).
- **Fix:** gate the grant on the source being an enemy state. → [items-and-gear](../wiki/items-and-gear.md)

### A-063 — Protocol Override makes every gainProtocol consumable a free Protocol printer {#a-063}
- **Where:** cost `battle_engine.gd:287-294`, +1 grant `protocol_actions.gd:934-945`. (items-relics-06)
- **Now:** with Protocol Override, items cost 0 **and** refund +1 — Protocol Cell nets +3 (desc "net +1"), Mainline Cache nets +6. All four "(net +N after use cost)" parentheticals also break under Supply Drone (0) and Sealed Supplies (2). Bounded (bag cap 3) so not infinite, but strictly-positive economy with zero decision cost, and the card text lies whenever any cost modifier is live.
- **Severity:** degenerate.
- **Fix:** drop the "(net …)" parentheticals; consider Protocol Override granting +1 only for non-gainProtocol items. → [relics](../wiki/relics.md)

### A-064 — Tier structure exceeds "single-entry effects + max 4 two-tier pairs" {#a-064}
- **Where:** `items.data.json` (rollBuff ×4, gainProtocol ×4, enemyRfe ×3, anyDieFreeze ×2), `gear.data.json` (five pairs: rollBonus, maxHpBonus, protocolOnBattleStart, lifesteal, firstAbilityDmgBonus). (items-relics-05)
- **Now:** 6 two-tier pairs + two 4-tier chains + one 3-tier chain across the pool vs the ground-truth "max 4 two-tier pairs."
- **Severity:** NEEDS-KEV-RULING ([NK](#nk-12)) — does the rule cover consumable rarity chains, and is the count per-file or pool-wide?
- **Fix:** ruling first; if enforced pool-wide, collapse the 3/4-tier chains and drop one gear pair. → [items-and-gear](../wiki/items-and-gear.md)

### A-065 — Duplicate gear can be drafted and stacked without limit {#a-065}
- **Where:** `GameState.gd:1217-1235` (`excluded_ids` covers only the current 3-card roll), `claim_reward:853-856` (appends unconditionally), `_apply_gear_passive` (`+=`). (items-relics-13)
- **Now:** the same gear id can be re-offered and equipped onto the same unit; numeric passives stack (2× Predator Lens = +6 all rolls; 2× Hemophage Nexus = 80% lifesteal). Nothing says gear is unique, but the pools read as designed-unique and mid-run re-equip was rejected (#15).
- **Severity:** NEEDS-KEV-RULING ([NK](#nk-13)) — unique-per-run?
- **Fix:** if unique, exclude owned gear ids in the reward roll. → [items-and-gear](../wiki/items-and-gear.md)

### A-066 — Deep Zero Pin was authored under freeze-as-lockout; under freeze=repeat its upside inverted {#a-066}
- **Where:** `items.data.json:184-191`; semantics changed `52e2fa5` (2026-07-06), effect predates it (`a21eaf4`). (items-relics-16)
- **Now:** "Freeze all enemy dice — each repeats that result." The text was rewritten in the freeze pass, but the **effect** was tuned for lockout (mass action denial); under repeat it **replays** every enemy die, including crits — a rare-rarity item whose value inverted from "always strong" to "only good when the revealed enemy round is weak." Cryo Gel/Web survived (player picks the die); the ALL variant didn't. **This is the closest live instance of the brief's inversion class.**
- **Severity:** NEEDS-KEV-RULING ([NK](#nk-14)) — repricing/redesign for the balance pass.
- **Fix:** e.g. "freeze all enemy dice currently in recharge/strike." → [items-and-gear](../wiki/items-and-gear.md)

### A-067 — Resonant Chorus floors only HERO dice; desc says "Turn 1 dice" {#a-067}
- **Where:** `battle_scene.gd:1413,1428-1431` (loops `get_hero_states()` only). (items-relics-07)
- **Severity:** confusing.
- **Fix:** desc → "Your turn-1 dice can't land below 8." → [relics](../wiki/relics.md)

### A-068 — Item damage carries no attacker — Mark and Cold Logic silently skip it {#a-068}
- **Where:** Mark gate `combat_manager.gd:1807`, Cold Logic `:1815` (both require a non-empty attacker); item entry passes none (`battle_engine.gd:406-409`). (items-relics-09)
- **Now:** Shock Charge on a Marked or frozen enemy deals flat 10 — no +50% Mark consumption, no Cold Logic +4; neither desc states the item exclusion.
- **Severity:** confusing.
- **Fix:** decide whether item damage is a "real hit"; pass a source state or note the exclusion. → [items-and-gear](../wiki/items-and-gear.md)

### A-069 — Plague Protocol's burn is PERMANENT but the desc reads like a normal burn {#a-069}
- **Where:** `combat_manager.gd:411-416` (`PERMANENT_BURN_TURNS := 9999`). (items-relics-11)
- **Now:** "All enemies begin every battle with 3 Burn" is a never-expiring stack (ticks all battle; Detonate takes one tick and doesn't consume it, DECISIONS #4). Every other burn is finite with a duration; the omission hides the relic's real value and its special Detonate rule.
- **Severity:** confusing.
- **Fix:** desc → "…with 3 permanent Burn." → [relics](../wiki/relics.md)

### A-070 — Triage Gel grants no shield on self-heals {#a-070}
- **Where:** `combat_manager.gd:2233-2237` (`state != healer_state` gate). (items-relics-12)
- **Now:** "Your heals also grant 3 shield" — but self-heals and full-HP heals (amount 0) grant nothing.
- **Severity:** confusing.
- **Fix:** drop the self-exclusion, or desc → "Your heals on allies also grant 3 shield." → [items-and-gear](../wiki/items-and-gear.md)

### A-071 — Consumable DROPS filter differently from reward drafts {#a-071}
- **Where:** `GameState.gd:770-778` (drops pass the held `consumables` as `excluded_ids`) and `:1256` (Curated Cache strips commons inside `_pick_random_item_id`); reward drafts CAN duplicate (`:857-863`). (items-relics-14)
- **Now:** battle-start/first-kill drops never duplicate a held item and silently strip commons (desc says "Rewards"); with a near-full bag the drop pool can empty → no drop, no message.
- **Severity:** confusing.
- **Fix:** stop passing `consumables` as exclusions (or document both quirks); align "Rewards" wording. → [rewards-and-shop](../wiki/rewards-and-shop.md)

### A-072 — Overload Loop doubles only raw hero 20s — generic desc {#a-072}
- **Where:** `combat_manager.gd:685-687` (`raw_roll == 20`, hero loop only). (items-relics-18)
- **Now:** "Natural 20s resolve their effects twice" — enemy nat-20s never double (fine, unstated), and a Band Compressor 19 landing in the overload band doesn't double. Forced nat-20s DO double and feed Capacitor (consistent). See also [A-011](#a-011)/[A-012](#a-012).
- **Severity:** confusing.
- **Fix:** desc → "Your natural 20s resolve twice"; note the Band Compressor exclusion. → [relics](../wiki/relics.md)

### A-073 — Salvage Directive misses mark-kills finished by a follow-up packet {#a-073}
- **Where:** `mark_consumed_this_hit` reset per `_damage_state` call (`combat_manager.gd:1806`), set at `:1810`, kill hook `:1927`, refund requires the flag on the corpse `:2147`. (int-05)
- **Now:** the base hit consumes the Mark but leaves the target alive <25%; the same ability's execute/detonate packet re-enters `_damage_state`, resets the flag, and kills — Salvage Directive checks the flag on the corpse and pays nothing. Marked+execute is the exact kill line the relic advertises.
- **Severity:** confusing.
- **Fix:** track "mark consumed this ABILITY" (clear at ability start), not per-packet. → [relics](../wiki/relics.md)

### A-074 — Echo Matrix replays the full keyword suite, not "its damage" {#a-074}
- **Where:** `combat_manager.gd:1144-1146` (re-invokes `_apply_hero_ability_damage` with the same entry; only burn zeroed); re-reads breach/detonate/execute/mark/chain at `:1229-1280`; desc `gear.data.json:19` ("echoes its damage"). (int-06)
- **Now:** the echo re-executes (a second +8 execute the first pass often enabled), re-chains, re-breaches, and — with Combat Sense / Marked for Death — **consumes the Mark its own first pass applied** for +50% on the echo (so the mark never reaches the squad). On chain/execute overload faces it approaches Overload Loop as a rare gear.
- **Severity:** degenerate.
- **Fix:** echo only the damage packets (strip keywords), or re-desc "resolves its damage effects twice." → [items-and-gear](../wiki/items-and-gear.md)

---

## 10. Beats, events & run structure

See [beats-and-events.md](../wiki/beats-and-events.md). **Beat algorithm, b5 relic draft + soft-lock fix, and XP economy all verified correct.**

### A-075 — Intercept zero-options guard replays the battle just won {#a-075}
- **Where:** `intercept_screen.gd:146` (`ensure_options("intercept", count, SceneManager.go_to_battle)` — no `advance_to_next_battle()`). Every legit exit advances first. (meta-01)
- **Now:** in a release build a guard fire re-loads the **same** battle number: same comp, re-rolled rewards, double XP for one slot.
- **Severity:** broken.
- **Fix:** pass `_continue_to_battle` as the guard default. → [beats-and-events](../wiki/beats-and-events.md)

### A-076 — Flagged route into battle 5 pays for SUPPLY GRADE +2 and gets nothing {#a-076}
- **Where:** `GameState.gd:1163-1169` (`_roll_reward_item_ids` consumes the supply grade before the round-5 relic-only early return). (meta-03)
- **Now:** a fork after b4 → flagged b5 shows "◆ SUPPLY GRADE +2," but the relic cache has no rarity ladder, so the reward bonus is spent on nothing. Deliberate in code (comment), never adjudicated.
- **Severity:** NEEDS-KEV-RULING ([NK](#nk-15)) — carry the grade to the b6 draft, or accept "spent on the cache"?
- **Fix:** if ruled, don't zero the grade on the relic-only branch. → [beats-and-events](../wiki/beats-and-events.md)

### A-077 — Single-slot modifier arming — silent overwrites and precondition bypass {#a-077}
- **Where:** `GameState.gd:334-335` (fork accept), `:373-380` (Prisoner Exchange promote), `:584-587` (intercept armModifier) — three writers on one string slot, last-writer-wins, no logging; promote skips `_modifier_precondition_ok`. (meta-04)
- **Now:** "promote elitePresence for N+1 → beat after N arms another modifier" silently discards the promoted one; and promote can arm ELITE PRESENCE on an all-elite comp with zero observable delta (violating the fork-offer invariant).
- **Severity:** degenerate.
- **Fix:** make promote/arm additive-or-reject (keep first, log) and run the precondition in promote. → [beats-and-events](../wiki/beats-and-events.md)

### A-078 — Intercept consumable grants silently vanish at the 3-slot cap {#a-078}
- **Where:** `GameState.gd:580-583` (appends only if under cap); `intercept_screen.gd:263-279` (still prints "Acquired: <name>"). (meta-05)
- **Now:** at cap the item is rolled and dropped with no swap prompt (the reward screen HAS a swap flow), while the result stage claims the player received it.
- **Severity:** confusing.
- **Fix:** reuse the reward swap stage, or print "inventory full — item lost." → [beats-and-events](../wiki/beats-and-events.md)

### A-079 — `BATTLE_MODIFIERS` numeric fields are display-only duplicates of hardcoded effects {#a-079}
- **Where:** `GameState.gd:256-267` (amount/cap/fromTurn) vs the hooks that hardcode the same literals (`combat_manager.gd:56-67,710-713,2110-2115`; `battle_engine.gd:72-74,287-294`). (meta-07)
- **Now:** hardened `amount:8`, ferocity `2`, deadMansCharge `4`, regenerative `3`, blackout `fromTurn:3`, jammingField `cap:10` are never read; each hook hardcodes the value. **The exact "written when cap was 7" breeding ground** — a balance pass editing the dict (DECISIONS #7 targets it) changes descriptions but not behavior. All pairs agree today.
- **Severity:** confusing.
- **Fix:** have the hooks read the dict (single source), or strip the numeric fields and generate descs. → [beats-and-events](../wiki/beats-and-events.md)

### A-080 — Route-fork zero-options guard counts children, not options {#a-080}
- **Where:** `route_fork_screen.gd:107` (`ensure_options(..., column.get_child_count(), …)`). (meta-08)
- **Now:** the column always holds ≥5 children (labels/blurb/gap), so the guard can never see 0 — harmless only because the STANDARD card is unconditional. A future conditional card would soft-lock invisibly.
- **Severity:** confusing.
- **Fix:** count route cards built (0/1/2), not column children. → [beats-and-events](../wiki/beats-and-events.md)

### A-081 — LoadoutMenu shows only `relics[0]` — Starting Directive runs hide the drafted relic {#a-081}
- **Where:** `protocol_actions.gd:711-715`, `loadout_menu.gd:52,111-112` (takes one relic). (meta-09)
- **Now:** a Starting Directive run legitimately carries two relics after b5, but index 0 is always the Starting Directive, so the drafted relic is never inspectable from the battle screen.
- **Severity:** confusing.
- **Fix:** render all owned relics in the RELIC section. → [beats-and-events](../wiki/beats-and-events.md)

### A-082 — Enemy field cap reuses `SQUAD_UNIT_LIMIT` (hero constant) {#a-082}
- **Where:** `battle_scene.gd:1783`, `sim_runner.gd:567`, `GameState.gd:198,355`. (meta-10)
- **Now:** enemy rosters are truncated at the **hero** squad-size constant (3). Harmless today (max authored comp is 3), but a "4-enemy fight" would require touching the hero constant or silently drop the 4th. Squad-size-assumption class.
- **Severity:** confusing.
- **Fix:** introduce `ENEMY_FIELD_LIMIT := 3` at the enemy-side sites. → [beats-and-events](../wiki/beats-and-events.md)

### A-083 — Modifier "no repeats" only binds accepted forks {#a-083}
- **Where:** `GameState.gd:331-335` (append on accept only), `:584-585` (armModifier never appends). (meta-11)
- **Now:** a declined fork modifier returns to the pool; intercept-armed modifiers never mark used, so a fork can offer HARDENED after an intercept already inflicted it.
- **Severity:** NEEDS-KEV-RULING ([NK](#nk-16)) — do intercept-armed modifiers consume the pool, and may declined ones be re-offered?
- **Fix:** if ruled, append to `used_battle_modifiers` in armModifier/promote too. → [beats-and-events](../wiki/beats-and-events.md)

### A-084 — DECOY BEACON comment/behavior drift (hidden vs disabled) {#a-084}
- **Where:** `GameState.gd:395-396` (comment "hidden without one") vs `intercept_screen.gd:137-141` (rendered disabled). (meta-12)
- **Severity:** confusing (doc-vs-code only; behavior is fine).
- **Fix:** update the GameState comment to "disabled." → [beats-and-events](../wiki/beats-and-events.md)

---

## 11. Save & meta

See [save-system.md](../wiki/save-system.md). **Save schema, both grandfather clauses, headless full-unlock reads, and the hero-ladder/operation-chain rules all verified correct.**

### A-085 — Hero/operation unlock-hint API is dead code contradicting the no-hints doctrine {#a-085}
- **Where:** `SaveManager.gd:37-43,348-357` (`HERO_UNLOCK_HINT` + both hint functions, zero callers). home_screen renders locked entries as `[ LOCKED ]` with no hint; TRUTH codifies "no hints." (meta-06)
- **Severity:** dead.
- **Fix:** delete the constants + both functions (or move the strings to a design doc). → [save-system](../wiki/save-system.md)

---

## 12. Docs & tooling (design-doc rot)

Stale living-doc claims that contradict current code/TRUTH and would mislead a future session. See [conventions.md](../wiki/conventions.md), [decision-log.md](../wiki/decision-log.md).

### A-086 — TRUTH's eff-grammar separator matches no data file {#a-086}
- **Where:** `docs/TRUTH.md:82` ("joined by ` + `", examples `10 dmg + pierce`) vs all of `data/raw/*.json` (comma/`(all)` style: "14 dmg, pierce"); generators emit commas. (heroes-07, enemies-18)
- **Now:** zero eff strings use the documented " + " join; data is 100% consistent on the comma style. Code wins → TRUTH is stale, **but** the "canonical grammar" is cited by DECISIONS #2's reasoning, so a silent doc fix could disturb a ruling.
- **Severity:** NEEDS-KEV-RULING ([NK](#nk-17)) — is the comma/`(all)` house style canon (fix TRUTH), or was " + " an intended normalization that never ran (fix ~160 strings)?
- **Fix:** one-line TRUTH correction (likely) or a data normalization pass. → [conventions](../wiki/conventions.md)

### A-087 — GDD still describes the DEAD freeze lockout model {#a-087}
- **Where:** `docs/GDD.md` §6 & §7 ("Die locked; the unit skips its next N reveals"). (arch-01)
- **Now:** TRUTH rule 7 / DECISIONS #1 is FREEZE = REPEAT; lockout is dead model #2. INVARIANTS #10's violation example is literally "an old doc paragraph still describes it."
- **Severity:** confusing.
- **Fix:** rewrite both GDD freeze rows to the repeat wording, cite DECISIONS #1. → [keywords](../wiki/keywords.md)

### A-088 — GDD boss table uses pre-pkg3.3 boss names {#a-088}
- **Where:** `docs/GDD.md:279-287` (Circlet Hierophant, Void Reaver). (arch-02)
- **Now:** renamed ROOT HIEROPHANT / MANTLE TYRANT; a session authoring from the GDD would reintroduce dead names.
- **Severity:** confusing.
- **Fix:** update the two names (ids stay). → [bosses](../wiki/bosses.md)

### A-089 — 450×1000 preview size stale across four living docs {#a-089}
- **Where:** `GDD.md`, `docs/CLAUDE.md:13`, `AI_AGENT_GAME_REFERENCE.md:19`, `BATTLE_UI_V2_SPEC.md`, `PRIMERS.md`. (arch-03)
- **Now:** `project.godot` window is **540×1200** (changed `8f2da05`); only TRUTH was updated. The entire even-stroke rationale (INVARIANTS #14) depends on the half-scale window — a doc telling an agent to verify at 450×1000 reintroduces the shimmer bug class.
- **Severity:** confusing.
- **Fix:** sweep 450×1000 → 540×1200 in living docs (leave `archive/`). → [conventions](../wiki/conventions.md)

### A-090 — `docs/CLAUDE.md` "do not contradict" table says main scene is UnitSelect {#a-090}
- **Where:** `docs/CLAUDE.md:19`; `project.godot` main scene is `MainMenu.tscn`. (arch-04)
- **Now:** a "do not contradict" table that contradicts code; also omits the SaveManager/AudioManager/PersistentHeader autoloads.
- **Severity:** confusing.
- **Fix:** update the row + autoload list, or demote the table with a pointer to TRUTH. → [conventions](../wiki/conventions.md)

### A-091 — `AI_AGENT_GAME_REFERENCE` points to the deleted TypeScript sim {#a-091}
- **Where:** `docs/AI_AGENT_GAME_REFERENCE.md:28` ("scripts/debug/balance_sim_*.ts"); deleted at `a864ad6`. §13 also cites the superseded GROUND_TRUTH.md. (arch-05)
- **Severity:** dead.
- **Fix:** point to `scripts/sim/` (GDScript) + `ci_smoke.py`/`sweep.py`; content truth → `docs/TRUTH.md`. → [conventions](../wiki/conventions.md)

### A-092 — `BATTLE_UI_V2_SPEC` references deleted UnitCard/BattleHeader scenes as existing {#a-092}
- **Where:** `docs/BATTLE_UI_V2_SPEC.md:53,94`; neither scene exists (header is the `PersistentHeader` autoload). §6's 432px center rail also contradicts the shipped 540px. (arch-06)
- **Severity:** confusing.
- **Fix:** replace §2/§4 with PersistentHeader + CompactUnitCard reality; note the 540px center band. → [conventions](../wiki/conventions.md)

### A-093 — `ANIMATION.md` guardrail says "green = protocol/heal" {#a-093}
- **Where:** `offline-bundle/ANIMATION.md:6`. TRUTH cites this file as the live keyword-feedback table, so its "do not violate" header carries authority. Protocol is amber. (arch-07) Same class as [A-030](#a-030).
- **Severity:** confusing.
- **Fix:** "cyan/teal player, amber protocol/risk, green HP+heal only." → [conventions](../wiki/conventions.md)

### A-094 — `CODEBASE_MAP.md` is cited as living but materially stale {#a-094}
- **Where:** `offline-bundle/CODEBASE_MAP.md:20,59,64,94` (combat_manager "~970 lines" now >2600; "three autoloads"; "no TODO/FIXME"; no ProtocolActions/BattleEngine/SaveManager). (arch-08)
- **Now:** triage guidance ("protocol economy → battle_scene.gd") points at the wrong owner.
- **Severity:** confusing.
- **Fix:** refresh the map, or drop it from the living-docs list. → [conventions](../wiki/conventions.md)

### A-095 — GDD "one relic per run" contradicts the Starting Directive design {#a-095}
- **Where:** `docs/GDD.md:258`. pkg5 adds a Starting Directive boss relic at DEPLOY plus the b5 draft ("two relics by design"). (arch-09)
- **Now:** a relic-count assumption baked into new code (UI slots, guards) would regress the b5 soft-lock territory. See [A-081](#a-081).
- **Severity:** confusing.
- **Fix:** GDD → "one drafted relic per run; a Starting Directive boss relic may precede it." → [relics](../wiki/relics.md)

### A-096 — TASK_QUEUE parking lot lists "Task 7 — Rename dot→burn" as future work {#a-096}
- **Where:** `TASK_QUEUE.md:297-306`; the rename landed pkg1.1 (`7122fb0`). (arch-10)
- **Severity:** dead.
- **Fix:** mark the entry Done (pkg1.1) or delete it. → [decision-log](../wiki/decision-log.md)

### A-097 — GDD battle-card description lists gear slots / XP bar / level indicator {#a-097}
- **Where:** `docs/GDD.md:94-104`; the live CompactUnitCard has Name / Portrait / HP / pips / Status — no gear slots, XP bar, or level on battle cards. (arch-13)
- **Severity:** confusing.
- **Fix:** align §5 with the five-band card, or mark the extras "menu surfaces only." → [conventions](../wiki/conventions.md)

---

## Severity summary table

Sorted broken → degenerate → dead → confusing. **NEEDS-KEV-RULING items are excluded here — see the [next section](#needs-kev-ruling).**

| ID | Name | System | Severity | One-liner |
|---|---|---|---|---|
| [A-041](#a-041) | Sync Antenna dead legendary | Heroes/Gear | broken | +3 written to a display cache the effective-roll path never reads |
| [A-043](#a-043) | Bestiary old faction names | Enemies | broken | "VOID CIRCLET"/"STELLAR MENAGERIE" render as player-visible labels |
| [A-044](#a-044) | "Circlet Cataclysm" boss ability | Bosses | broken | dead faction name in a ROOT HIEROPHANT ability |
| [A-061](#a-061) | Defib Spark unusable | Items | broken | the only `allyDead` item hard-cancels on tap; never worked |
| [A-075](#a-075) | Intercept guard replays battle | Beats | broken | release-build guard fire re-runs the won battle (double XP) |
| [A-002](#a-002) | Nested-death guard swallows hooks | Combat | degenerate | on-kill deaths skip stats/SPITEFUL/Killswitch/Bounty |
| [A-012](#a-012) | Raw-20 riders vs rewrite/jam | Dice | degenerate | crit rewards fire on dice tampered to 3/≤10; forced-20 eaten by Rewrite |
| [A-033](#a-033) | Aegis Field on enemy heals | Shields | degenerate | enemy sustain grants your whole squad shield |
| [A-034](#a-034) | Mantle Core unbounded shields | Shields | degenerate | persist × per-round drips = uncapped shield engine |
| [A-062](#a-062) | Mirror Plate friendly-freeze | Items | degenerate | banking an ally's die prints the holder +2 Protocol each cast |
| [A-063](#a-063) | Protocol Override free printer | Relics | degenerate | gainProtocol items cost 0 AND refund +1; desc math lies |
| [A-074](#a-074) | Echo Matrix replays keywords | Gear | degenerate | re-runs execute/chain/breach and eats its own fresh Mark |
| [A-077](#a-077) | Single-slot modifier arming | Beats | degenerate | last-writer-wins overwrite + precondition bypass |
| [A-008](#a-008) | curseDice dead 5th tamper | Dice | dead | fully-wired handler, zero data, no roll effect |
| [A-020](#a-020) | Dead protocol/gear handlers | Protocol | dead | four coded effect paths no data uses |
| [A-026](#a-026) | Dead venom/fire/bleed chips | Statuses | dead | chip kinds no producer emits |
| [A-027](#a-027) | Write-only legacy status strings | Statuses | dead | CURSED/RAGE list computed every refresh, never read |
| [A-032](#a-032) | Duplicated shieldsPersist block | Shields | dead | Mantle Core flag set twice per battle start |
| [A-036](#a-036) | ABILITY_DESCRIPTIONS fossil | Heroes | dead | untracked doc teaching 6 dead mechanics |
| [A-046](#a-046) | packBonus never fires | Enemies | dead | compares unique runtime ids → always +0 |
| [A-047](#a-047) | battleEnemyScale dead data | Enemies | dead | schema-required, zero consumers |
| [A-048](#a-048) | trackHpScale dead data | Operations | dead | loaded into OperationData, never read |
| [A-049](#a-049) | Forked Double summonElite inert | Enemies | dead | flag set, kit has no summonChance |
| [A-050](#a-050) | commsHex dead enum | Enemies | dead | enemyType value no unit uses |
| [A-051](#a-051) | phase-2 sfx leftover | Bosses | dead | registered sound with no emitter |
| [A-085](#a-085) | Unlock-hint dead code | Save | dead | hint API contradicts the no-hints doctrine, zero callers |
| [A-091](#a-091) | Deleted TS sim reference | Docs | dead | AI_AGENT_GAME_REFERENCE points at deleted `.ts` files |
| [A-096](#a-096) | dot→burn parking-lot entry | Docs | dead | lists a landed rename as future work |
| [A-003](#a-003) | healLowest follows stale pick | Combat | confusing | diverges from shieldLowest; can miss the lowest ally |
| [A-004](#a-004) | Leech tracer wrong enemy | Combat | confusing | draws drain from the pre-retarget pick |
| [A-005](#a-005) | Reverse enemy resolution order | Combat | confusing | undocumented right-to-left iteration |
| [A-007](#a-007) | Keyword rules not gated | Combat | confusing | "audit-enforced" rules run in no gated check |
| [A-009](#a-009) | Engine freeze guards missing | Dice | confusing | reroll/Set/Twin-Fates guarded only in UI |
| [A-013](#a-013) | Twin Fates copy-20 semantics | Dice | confusing | copied 20 doubles but grants no Capacitor/stat |
| [A-014](#a-014) | Nudge prompt omits Gimbal | Dice | confusing | "once per die" ignores the flip re-tap |
| [A-015](#a-015) | Stale sim_runner comment | Dice | confusing | lumps Overflow Vent with global-RNG consumers |
| [A-016](#a-016) | Overload Capacitor hardcoded | Protocol | confusing | +2 literal ignores gear `amount` |
| [A-017](#a-017) | Overflow Vent hardcoded | Protocol | confusing | 2 dmg/pt literal ignores relic `amount` |
| [A-018](#a-018) | Battle-start overflow split | Protocol | confusing | gear start protocol clamps, intercept vents |
| [A-019](#a-019) | Duplicate protocol constants | Protocol | confusing | MAX_PROTOCOL/SET_DIE_COST in two files |
| [A-022](#a-022) | Chain targets lowest ratio | Keywords | confusing | "lowest-HP" text, lowest-% behavior |
| [A-023](#a-023) | Spike absorbed vs reduced | Keywords | confusing | shield-absorbed triggers, reduction-zeroed doesn't |
| [A-025](#a-025) | Leech ignores chain damage | Keywords | confusing | 50% heal off primary only (latent) |
| [A-030](#a-030) | keywords.json green comment | Keywords | confusing | stale "green = protocol" doctrine in canon data |
| [A-035](#a-035) | Salvage Rig vs breach | Relics | confusing | +1 Protocol skips breach-destroyed shields |
| [A-037](#a-037) | Schema CRYO callsign | Heroes | confusing | dead callsign in the validity file |
| [A-038](#a-038) | Evo-screen portrait text | Heroes | confusing | says a shipped feature doesn't exist |
| [A-039](#a-039) | Wideband Hiss no duration | Heroes | confusing | 1t debuff reads as permanent |
| [A-040](#a-040) | heroAbility schema open | Heroes | confusing | additionalProperties:true hides typos |
| [A-042](#a-042) | Feedback ticks foreign rfe | Directives | confusing | fires on any roll-down, not the carrier's |
| [A-045](#a-045) | Reaver Mantle legacy name | Bosses | confusing | dead boss name + duplicated "Total Eclipse" |
| [A-052](#a-052) | THE BROOD hidden cap | Bosses | confusing | inspect text omits the <3-enemies condition |
| [A-053](#a-053) | MANTLE freeze is ice | Bosses | confusing | Accretion boss shows ice, not petrify |
| [A-054](#a-054) | Stale summon comment | Enemies | confusing | "Veil-only" comment; 3 factions summon |
| [A-055](#a-055) | grantRampageAll int/bool | Enemies | confusing | integer schema read as boolean |
| [A-056](#a-056) | TRUTH hive siphon | Factions | confusing | hive drain is leech, not siphon |
| [A-058](#a-058) | Battle-start relics skip summons | Enemies | confusing | perm burn/jam/HP never hit reinforcements |
| [A-059](#a-059) | Decoy skips only actions | Beats | confusing | boss standing rules still fire on a decoyed round |
| [A-067](#a-067) | Resonant Chorus hero-only | Relics | confusing | floors hero dice; desc says "Turn 1 dice" |
| [A-068](#a-068) | Item damage no attacker | Items | confusing | Mark/Cold Logic skip item hits |
| [A-069](#a-069) | Plague Protocol perma-burn | Relics | confusing | permanent burn described as normal |
| [A-070](#a-070) | Triage Gel self-heal gap | Items | confusing | no shield on self/full-HP heals |
| [A-071](#a-071) | Drops filter vs drafts | Rewards | confusing | drops dedupe + strip commons silently |
| [A-072](#a-072) | Overload Loop desc | Relics | confusing | doubles raw hero 20s only; desc generic |
| [A-073](#a-073) | Salvage Directive packet miss | Relics | confusing | refund lost when a follow-up packet kills |
| [A-078](#a-078) | Intercept item lost at cap | Beats | confusing | "Acquired" printed for a dropped item |
| [A-079](#a-079) | Modifier numeric fields dead | Beats | confusing | dict values never read; balance-pass trap |
| [A-080](#a-080) | Route-fork guard blind | Beats | confusing | counts children, can never see 0 |
| [A-081](#a-081) | LoadoutMenu one relic | Beats | confusing | drafted relic hidden on directive runs |
| [A-082](#a-082) | Enemy cap = hero constant | Beats | confusing | SQUAD_UNIT_LIMIT aliased for enemy field |
| [A-084](#a-084) | DECOY comment drift | Beats | confusing | comment "hidden," code "disabled" |
| [A-087](#a-087) | GDD dead freeze lockout | Docs | confusing | living doc still teaches the dead model |
| [A-088](#a-088) | GDD old boss names | Docs | confusing | Circlet Hierophant / Void Reaver |
| [A-089](#a-089) | 450×1000 preview stale | Docs | confusing | four docs cite the pre-540×1200 window |
| [A-090](#a-090) | CLAUDE.md main scene | Docs | confusing | "do not contradict" table contradicts code |
| [A-092](#a-092) | UI spec deleted scenes | Docs | confusing | references UnitCard/BattleHeader as existing |
| [A-093](#a-093) | ANIMATION.md green | Docs | confusing | "green = protocol" guardrail |
| [A-094](#a-094) | CODEBASE_MAP stale | Docs | confusing | line counts + autoloads + owners wrong |
| [A-095](#a-095) | GDD one-relic-per-run | Docs | confusing | contradicts Starting Directive design |
| [A-097](#a-097) | GDD battle-card chrome | Docs | confusing | lists gear slots/XP bar not on cards |

---

## Needs Kev ruling {#needs-kev-ruling}

Ambiguous items — each might be intentional. Listed, not guess-fixed.

- **NK-01 — Seeded-global RNG vs the determinism fence.** ([A-001](#a-001)) {#nk-01} Four combat draws (`combat_manager.gd:380/385/2113/2640` — Opening Salvo, Dead Man's Charge, elite summon) use Godot's global RNG, not the `RollProvider` seam INVARIANTS #1 mandates. The sim stays reproducible via a per-run global seed (a documented workaround, `58450f7`). **Question:** bless the seeded-global stream by amending INVARIANTS #1, or route these four sites through the provider? (Flagged independently by 6 agents; recommended fix is to reroute for one true seam.)
- **NK-02 — Overload slam on effective 20.** ([A-006](#a-006)) {#nk-02} The name-slam fires on any die pushed into the overload zone, not only a raw 20. Coded and commented as intended; the ground-truth list says "Nat-20." **Question:** bless effective-20 celebrations (recommended), or gate the slam on `raw == 20`?
- **NK-03 — Nudge/Set on a freshly-frozen die.** ([A-010](#a-010)) {#nk-03} A die frozen this round can still be Nudged/Set for the current action (Reroll/Twin-Fates are blocked). TRUTH reads stricter ("can't be Set"). **Question:** confirm "acts normally the round it is frozen" includes Nudge/Set, then tighten TRUTH's wording — or enforce strict immunity?
- **NK-04 — Which raw-20/summon riders re-fire per freeze repeat.** ([A-011](#a-011)) {#nk-04} A frozen 20 re-grants Overload Capacitor, re-increments the nat-20 stat, re-doubles under Overload Loop, and (enemy side) **re-rolls the summon chance** every repeat. **Question:** are crit riders and probability re-rolls part of "acts again on that result," or should they fire once?
- **NK-05 — Reserved mechanic words in flavor names.** ([A-021](#a-021)) {#nk-05} "Venom Nip," "Crystal Shatter," "ECM Jam," "Chain Strike" use dead/reserved keyword words. A flavor-name precedent exists (kept "Venom Nip") but predates the keyword primers. **Question:** rename for keyword legibility, or keep flavor names and rule the reservation covers mechanics only?
- **NK-06 — Spike/flat-rider trigger unit: packet or ability.** ([A-024](#a-024)) {#nk-06} Spike and vs-state riders (Cold Logic/Deep Cuts/Shatterpoint) fire once per damage *packet*, so a multi-packet ability (execute/detonate/chain) multiplies them. **Question:** is the packet or the whole ability the intended trigger unit?
- **NK-07 — The TAUNT chip and the chip doctrine.** ([A-028](#a-028)) {#nk-07} Code renders six chips (incl. a TAUNT chip on lured heroes); the ground-truth list says five (no Taunt); TRUTH says six. The taunting *unit* has no chip. **Question:** is the TAUNT chip canon (doctrine = six), and should the taunting unit get a marker?
- **NK-08 — Hero Taunt duration.** ([A-029](#a-029)) {#nk-08} Hero-side taunt never expires (permanent redirect); enemy self-taunt clears each round. **Question:** is hero Taunt a permanent stance, or should it clear at round end?
- **NK-09 — "lifesteal N%" vs "Leech".** ([A-031](#a-031)) {#nk-09} 11 enemy abilities say "lifesteal 45%" but render the Leech pip; TRUTH defines Leech as fixed 50%. **Question:** unify the eff wording to "leech N%," or accept the split and document the enemy percent-variant in TRUTH?
- **NK-10 — Stall-farming boss reinforcements.** ([A-057](#a-057)) {#nk-10} SCRAPMASTER/MATRIARCH re-supply basic enemies on a clock; kill-triggered economy (Bounty/Chitin/Kill Switch/momentum) pays out on each, unbounded. **Question:** acceptable (bosses still deal damage), or exclude summoned/rebuilt units from kill payouts?
- **NK-11 — Frozen internal-id exemption.** ([A-060](#a-060)) {#nk-11} `voidCirclet`/`stellarMenagerie` persist as internal ids per INVARIANTS #11 while the brief calls "old faction names anywhere" findings. **Question:** confirm the standing exemption (no action expected; only player-visible strings are fixed).
- **NK-12 — Pool tier budget.** ([A-064](#a-064)) {#nk-12} The item/gear pool has 6 two-tier pairs + two 4-tier + one 3-tier chain vs "max 4 two-tier pairs." **Question:** does the rule cover consumable rarity chains, and is the count per-file or pool-wide?
- **NK-13 — Duplicate gear.** ([A-065](#a-065)) {#nk-13} The same gear id can be re-drafted and stacked (2× Predator Lens = +6 rolls). **Question:** is gear unique-per-run?
- **NK-14 — Deep Zero Pin repricing.** ([A-066](#a-066)) {#nk-14} A rare item tuned for freeze-as-lockout (mass denial) now *replays* every enemy die under freeze=repeat — upside inverted. **Question:** reprice/redesign in the balance pass (e.g. only freeze low-band dice)?
- **NK-15 — SUPPLY GRADE +2 on a flagged battle 5.** ([A-076](#a-076)) {#nk-15} A flagged route into b5 promises "+2 supply grade" but the relic cache has no rarity ladder, so it buys nothing. **Question:** carry the grade to the b6 draft, or accept "spent on the cache"?
- **NK-16 — Modifier "no repeats" scope.** ([A-083](#a-083)) {#nk-16} Declined fork modifiers return to the pool; intercept-armed modifiers never mark used, so a fork can re-offer HARDENED after an intercept inflicted it. **Question:** do intercept armings consume the fork pool, and may declined modifiers be re-offered?
- **NK-17 — Eff-text grammar canon.** ([A-086](#a-086)) {#nk-17} Data uses comma/`(all)` style; TRUTH documents a " + " join that no file uses; the grammar is cited by DECISIONS #2's reasoning. **Question:** is the comma style canon (fix TRUTH), or was " + " an intended normalization sweep never run (fix ~160 strings)?

---

## Coverage checklist

Every entity class was audited (100%, no sampling). Compiled from the seven read agents' coverage logs.

**Heroes** — 8/8 base kits, 16/16 evolutions, 120/120 abilities, 32/32 directives. All keyword-budget and one-pick checks pass; all ground-truth spot checks pass. ✅
**Enemies** — 38/38 unit defs, 37/37 kits (all 5 zones each), 5/5 bosses (standing-rule code + cadence), 5/5 operations, full targeting kit table, summon guard. ✅
**Items / gear / relics** — 25/25 consumables, 31/31 gear, 35/35 relics (30 draftable + 5 boss, set verified). ✅
**Keywords / statuses** — 26 keyword defs + all die statuses + every chip/pip kind; freeze/jam/rewrite/hijack/spike/leech/chain/detonate/execute/breach/mark/taunt/cloak/pierce/siphon all traced to handlers. ✅
**Dice / protocol** — 5 protocol actions, 16 +protocol sources, 6 sinks, 5 discounts, 4 die statuses, all zone tables (8 heroes + 37 kits), determinism seam. ✅
**Targeting** — 4 personalities + fallbacks, choke point, taunt/cloak overrides, one-manual-pick invariant. ✅
**Beats / run structure** — 10/10 BATTLE_MODIFIERS, 22/22 INTERCEPT_CARDS, beat scheduler, route forks, zero-options guards, templated slots. ✅
**Save / meta** — 15 save fields, 5 ladder rungs, operation chain, both grandfather clauses, headless reads, XP economy. ✅
**Engine constants** — MAX_PROTOCOL, SET_DIE_COST, JAM_CAP, XP thresholds, PERMANENT_BURN_TURNS, boss cadence consts. ✅
**Cross-system interactions** — 28 relic×gear×item×ability×boss×modifier pairs examined (12 findings + 16 verified-clean pairs recorded in the interactions log). ✅
**Docs** — TRUTH, INVARIANTS, DECISIONS_RESOLVED, GDD, ROADMAP, CLAUDE (root + docs), AI_AGENT_GAME_REFERENCE, BATTLE_UI_V2_SPEC, PRIMERS, EFFECT_PIP_GUIDE, TASK_TEMPLATE, TASK_QUEUE, archive/*, offline-bundle (GROUND_TRUTH, ANIMATION, CODEBASE_MAP), all schemas. ✅

**Two acknowledged gaps** (no history signal, low risk): `offline-bundle/AUDIO.md` and `battle-modes.schema.json` git history were not exhausted; four decision-log entries carry `RATIONALE: unconfirmed`. Neither surface produced a finding on the code side.

---

_Cross-links: every finding above links to its wiki page; each wiki page's "⚠ Open findings" section links back here. See the [wiki INDEX](../wiki/INDEX.md)._
