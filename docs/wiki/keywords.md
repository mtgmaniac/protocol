# Keywords

> Part of the [Overload Protocol wiki](INDEX.md). See also: [combat-resolution.md](combat-resolution.md), [statuses-and-chips.md](statuses-and-chips.md), [shields-and-ward.md](shields-and-ward.md), [dice-and-rolls.md](dice-and-rolls.md), [enemies.md](enemies.md), [heroes.md](heroes.md).

## How it works

The canonical player-facing sentences live in `data/raw/keywords.data.json` (help menu, tooltips and pip codes all read it — pip codes are single-sourced via `EffectPip.keyword_code()`, `scripts/ui/effect_pip.gd:17`). The engine handlers live in `scripts/battle/combat_manager.gd`. Rule: **one keyword per ability, two allowed on overload faces; pierce counts** (enforced by `scripts/debug/audit_ability_keywords.py`, NOT by the Godot ability audit — see findings). First sightings show a one-sentence primer (`data/raw/primers.data.json`).

Legend: *timing* = where in the round it resolves · *feedback* = `battle_feedback.gd` beat.

### Chain (CH)

- **Rule:** after the primary single-target hit, the attack jumps to the lowest-HP other living enemy at 60% of base damage, round down; `chain: 2` adds a second jump to the next lowest not yet hit. Chain Doctrine relic and the Conductor directive each add a jump; Amplifier makes jumps carry full base damage (`combat_manager.gd:1465-1497`).
- **Timing:** last step of the damage pass — after detonate/execute/burn/mark on the primary (`:1280`). Jumps still run when the primary hit was Firewall-blocked (the ward negates the ability only for its own carrier).
- **Formula:** `floor(base_damage × 0.6)` (tuning key `chain_ratio`; number DEFERRED to the balance pass, DECISIONS_RESOLVED #10). "Lowest HP" is by **ratio** (current/max), and cloaked enemies can't be jumped to (`:2312`).
- **Carriers:** Pulse Tech — Static Ping, Singularity Burst (+ Arc line) per TRUTH.
- **Feedback:** cyan tracer from actor to jumped target (`battle_feedback.gd:435`), red `-N` float.
- **Audit:** `_run_chain_regression` (`ability_audit.gd:815`) pins 10 → 6 and the ×2 second jump.

### Detonate (DT)

- **Rule:** consumes the target's finite Burn stacks for `amount × remaining_turns` immediate damage each; a PERMANENT burn (plagueProtocol) adds exactly one tick's damage and is NOT consumed (per Kev 2026-07-06, DECISIONS_RESOLVED #4). Payload Fuse gear: whole burst ×1.5 round up (`combat_manager.gd:1421-1458`).
- **Timing:** immediately after the ability's own damage lands on the primary target (`:1257`); Open Veins makes every overload-zone hit detonate after its damage (`:1260`).
- **Note:** the burst is delivered through `_damage_state` with an attacker, so it can consume a standing Mark (×1.5) and trigger Spike.
- **Single source:** `get_expected_detonate_burst()` (`:1429`) feeds both combat and the live DT pip preview (`battle_card_view.gd:361`).
- **Feedback:** burn-chip flash then ember burst (`battle_feedback.gd:437`).
- **Audit:** `_run_detonate_regression` (`ability_audit.gd:860`) — finite, fizzle, permanent, and mixed-stack cases.

### Execute (EX)

- **Rule:** if the target sits strictly below 25% max HP **after the base damage**, deal a flat +8 bonus (`combat_manager.gd:1404-1418`; tuning key `execute_bonus`, number DEFERRED, DECISIONS #9). Reaper directive raises the threshold via per-state `execute_threshold_pct` (`:836`).
- **Timing:** after base damage and after Detonate (a detonate burst can push the target below the threshold); Ghostblade's decloak-execute rides the same hook (`:1262-1267`).
- **Note:** the bonus goes through `_damage_state` with an attacker — it respects shields and can trip Spike.
- **Feedback:** deep-red flash, oversized `EXECUTE -N` float, heavier hit-pause (`battle_feedback.gd:141-145, 262, 311`).
- **Audit:** `_run_execute_regression` (`ability_audit.gd:932`) pins fire-below/inert-above.

### Breach (BR)

- **Rule:** destroy ALL shield on the target before the damage lands; `breachAll` strips every enemy first, even on a single-target hit (`combat_manager.gd:1391-1401, 1214-1248`). Serrated directive: this hero's Pierce attacks also Breach (`:1216`).
- **Timing:** before the damage of the same hit; blocked wholesale by Firewall (the strip is part of the ability).
- **Distinct from Pierce by ruling** (DECISIONS_RESOLVED K2): Breach destroys, Pierce ignores-and-leaves.
- **Enemy mirror:** `wipeShields` (boss "wipe shields" clause) clears every hero shield before an AoE (`:1563`, `:1605`, `_wipe_all_hero_shields :1967`) and renders as the BR pip (`effect_pip.gd:246`).
- **Feedback:** gold shield-shatter burst (`battle_feedback.gd:439`).
- **Audit:** `_run_breach_regression` (`ability_audit.gd:963`).

### Leech (LC)

- **Rule:** the attacker heals 50% (round down) of the HP damage actually dealt — after shields, after reduction (`combat_manager.gd:1282-1301`; `_damage_state` returns HP damage for exactly this).
- **Timing:** once, after the whole damage pass; AoE leech sums HP damage across all struck enemies. Chain-jump damage is NOT counted (`:1280` vs `:1231`).
- **Enemy mirror:** `lifestealPct` (authored as a percent) — same LC pip (`effect_pip.gd:251`, handler `combat_manager.gd:1576-1595`); hero gear `lifesteal` heals per hit inside `_damage_state` (`:1891`).
- **Feedback:** dim red return tracer from the drained enemy + paired green heal number (`battle_feedback.gd:443`, event pair at `combat_manager.gd:1287-1301`).
- **Audit:** `_run_leech_regression` (`ability_audit.gd:1007`) — heals 5 off a 10 hit, heals 0 through shields.

### Siphon (SI) — enemy-only

- **Rule:** on a hit that connects (even fully shield-absorbed), drain N Protocol from the player pool, floor 0 (`combat_manager.gd:1597-1603`; the drain is queued via `_pending_protocol_drain :565` and applied by the caller, `battle_engine.resolve_step :62`).
- **Timing:** enemy phase, immediately after its damage component resolves; requires `attack_connected` (a Firewall or a fizzled/no-target attack drains nothing).
- **Feedback:** amber pip drifts from the protocol bar to the enemy (`battle_feedback.gd:450`).
- **Audit:** `_run_siphon_regression` (`ability_audit.gd:1160`).

### Mark (MK)

- **Rule:** persistent chip; the next hit with an attacker deals +50% round up (`ceil(amount × 1.5)`), then the Mark is consumed. Burn ticks and aura chip damage leave it standing (`combat_manager.gd:1377-1388, 1803-1812`).
- **Timing:** applied AFTER the marking hit's own damage (`:1276`), so it never boosts itself. Consumption happens before shield absorption — a fully absorbed hit still eats the Mark. The multiplier applies before flat bonuses (Cold Logic / Deep Cuts / Shatterpoint are added after, un-multiplied).
- **Directive Marks** (Combat Sense / Marked for Death) land only on the primary target of single-target hits — never AoE (DECISIONS_RESOLVED #14, `:1273`).
- **Sources beyond abilities:** Targeting Optic gear (battle start, `:479`), Firing Solution intercept (`battle_engine.gd:113`), items (`apply_item_mark :1387`). Salvage Directive refunds +2 Protocol when a Marked target dies to the consuming hit (`mark_consumed_this_hit`, `:2147`).
- **Feedback:** gold `◎ MARKED` float; `mark_consumed` event carries the boosted number.
- **Audit:** `_run_mark_regression` (`ability_audit.gd:1039`) — 3 then ceil(4.5)=5.

### Spike (SP)

- **Rule:** this round, any attacker whose damaging attempt connects with the carrier takes N back; never persists past the round (`combat_manager.gd:1061-1069, 1832-1882, tick :2509`). Highest value wins on re-application (`maxi`), Counterweight +4, Bunker Doctrine gives shield-holders Spike 3.
- **Timing:** retaliation fires inside the attacker's own `_damage_state` call, after shield absorption is computed — it triggers even when shields ate the whole hit, but NOT when gear damage-reduction zeroed the hit (early return `:1801`). The retaliation carries no attacker: it can't loop two spiked units, can't consume Marks, can't trigger the other unit's Spike.
- **Per-side expiry:** enemy-phase Spike sets `spike_skip_next_tick` so it covers exactly the next hero phase (`:1702-1710`) — same asymmetry as shields.
- **Carriers (approved per TRUTH):** Spine Stalker, Carapace Beetle, Basalt Ape, Volt Elite; hero-side via Spike Guard kit + directives.
- **Feedback:** rust spark burst on the attacker; readout pip only, no chip (`battle_feedback.gd:441`).
- **Audit:** `_run_spike_regression` (`ability_audit.gd:1070`).

### Jam (JM) — die status

- **Rule:** the target's next roll is capped at 10 (`JAM_CAP := 10`, `combat_manager.gd:1304`; keyword-batch K4, was 12). Re-jamming keeps the LOWEST cap (`:1350`). Wall of Static's cap-15 clause is the one sanctioned exception (`:1168`).
- **Timing:** applied mid-round it survives the imminent tick and caps the NEXT reveal, then clears at that round's tick (`:2503`). Battle-start jams (Static Field relic, jammingField modifier) cap the first roll directly (`apply_battle_start_jam :1358`).
- **Interactions:** frozen dice are immune (`:1347`); the cap binds the effective roll BEFORE the player's Nudge, so Nudge/Set can beat it (`battle_engine.gd:463`); Mirror Plate grants Protocol when an enemy jams a hero die (`:1355`).
- **Feedback:** die tint + "JAM ≤10" marker, static flicker (`battle_feedback.gd:458`); primer at `primers.data.json`.
- **Audit:** `_run_jam_regression` (`ability_audit.gd:1090`).

### Rewrite (RW) — die status

- **Rule:** the target's next roll is SET to 3 (`REWRITE_VALUE := 3`, `combat_manager.gd:1305`), telegraphed: applied this turn, fires at the next reveal, then clears (`:1308-1321`, tick `:2493`).
- **Precedence:** in `get_effective_roll` it trumps buffs/rfe/jam (`:537`) — but a player Set replaces it outright and a Nudge stacks on the 3 (`battle_engine.gd:461-465`). Frozen dice are immune (`:1314`). Mirror Plate pays out on hero dice (`:1321`).
- **Boss hook:** ROOT HIEROPHANT's Root Access rewrites the squad's highest effective die every round via `apply_rewrite_to_state` (`:1336`, rule at `:263`) — no ward/cloak check.
- **Feedback:** pending die marker; die scramble-then-slam-to-3 (`battle_feedback.gd:461`).
- **Audit:** `_run_rewrite_regression` (`ability_audit.gd:1110`).

### Hijack (HJ) — enemy-only die status

- **Rule:** the enemy's next roll copies the heroes' current highest die (`combat_manager.gd:1679-1685`, consumption at `:650-661`). The copy happens at round start from the heroes' EFFECTIVE rolls; the enemy's raw roll is kept for records.
- **Timing:** primed in the enemy phase (`hijack_pending` + skip flag), fires at exactly one reveal, then clears (`:2487`). A frozen hijacker keeps its crusted face instead (`:656`).
- **Carriers (per TRUTH):** voidScribe Checksum Copy, voidGlimmer Afterimage, spewer Mimic Gland.
- **Feedback:** ghost die label drifts from the hero rail to the enemy card (`battle_feedback.gd:455`).
- **Audit:** `_run_hijack_regression` (`ability_audit.gd:1130`), freeze immunity case (`:2508`).

### Taunt (T) — unified (Lure deleted, DECISIONS_RESOLVED K3)

- **One sentence:** "The taunted unit can only target the taunter."
- **Hero-side** (`raw.taunt` on a hero ability): the hero sets `taunting`; every hostile single-target enemy pick is overridden to them — beats assigned intents, personalities, even Cloak (`_get_taunting_hero_state :2382`, `_resolve_enemy_hero_target :198`, `_freeze_pick_hero_lowest_die :2034`). Only one ally taunts at a time (`:1040-1046`). Anchor Frame gear taunts passively above 50% HP; explicit taunts win (`:2386`). **Hero taunt has no round-end expiry** — it lasts until the hero dies or another ally taunts (see findings).
- **Enemy-side single** (`raw.taunt` on an enemy ability, internal `lured_by_id`): the struck hero's hostile picks are restricted to the taunter for exactly one hero phase (`:1693-1700`, `_hostile_single_target :1736`, tick clear `:2479`). Renders the TAUNT chip on the hero card (`battle_card_view.gd:442`).
- **Enemy self-taunt** (`enemySelfTaunt`): all heroes must target this enemy next player phase; cleared every round end (`:1720-1724`, `:2418-2421`). No chip renders for it.
- **Audit:** covered inside targeting/personality regressions; taunt-over-cloak via choke-point tests.

### Cloak (C) — 2 clauses (pierce-from-cloak REMOVED, DECISIONS_RESOLVED K1/#12)

- **Rule:** untargetable by hostile single-target abilities (friendly picks always legal); breaks when the unit deals damage or is hit by an AoE (`combat_manager.gd:947, 1538, 1733-1760`).
- **Resolution detail:** a hostile pick landing on a cloaked unit retargets to the first living non-cloaked unit in slot order; everyone cloaked → the ability fizzles (`_hostile_single_target :1736`). AoE hits land normally and tear the cloak (`_break_cloak_on_aoe :1756`). Chain jumps skip cloaked enemies (`:2318`).
- **Sources:** abilities (`cloak`/`cloakAll`), gear (battleStartCloak/Roll), items, Vanish and Silent Running directives; Geode Panther re-cloaks on recharge.
- **Display:** ghosted portrait, no chip; decloak = portrait resolves sharp (`battle_feedback.gd:464, 603`).
- **Audit:** `_run_cloak_regression` (`ability_audit.gd:712`) — retarget, AoE break, decloak-without-pierce.

### Pierce (P) — `ignSh`

- **Rule:** the damage ignores shields entirely; the shield is not removed and still blocks other attackers (`combat_manager.gd:1841`). Counts as a keyword for the one-per-ability budget (INVARIANTS #3).
- **Timing:** evaluated at absorption time inside `_damage_state`; emits a feedback-only `pierce` event when it visibly matters (shielded target, `:1777`).
- **Related:** gear `shieldPierce` is a partial-pierce budget (N points skip shields, rest absorbs, `:1849`); Serrated turns Pierce into Pierce+Breach (`:1216`).
- **Audit:** effect-audit `ignSh` case asserts full HP damage with the shield intact (`ability_audit.gd:3637`).

### Freeze — FREEZE = REPEAT (DECISIONS_RESOLVED #1, final)

- **Rule:** the die crusts at its current face and does not reroll; on each of its next N rolls the unit acts AGAIN on that face — same zone, same ability, targeting re-picked fresh. Then it thaws. Identical both sides.
- **Engine:** `_freeze_die_state` (`combat_manager.gd:2016`) adds repeats (`die_freeze_turns`), locks `frozen_die_value` (falls back to `last_die_value`); `battle_engine.apply_frozen_roll_overrides :513` re-imposes the face; the repeat flag is spent at the round-end tick (`:2402-2416`).
- **Immunities:** while frozen the die can't be Jammed (`:1347`), Rewritten (`:1314`), Hijacked (`:656`), Rerolled/Set/Twin-Fated or item-rerolled (`battle_engine.gd:309-325`).
- **Targeting:** hero `freezeAnyDice` = one manual pick, EITHER side (freezing an ally repeats a good roll on purpose); freeze riders on damaging hero abilities stay enemy-side (`:1101-1125`). Enemy AI freeze always crusts the hero's LOWEST revealed die — deterministic, taunt overrides, cloak hides (`_freeze_pick_hero_lowest_die :2033`).
- **Extras:** re-freezing adds repeats; chained freezes decrement legally (no loop); Deep Freeze +1 repeat (`:1107`); Cold Logic relic +4 damage vs frozen-die enemies (`:1815`); Shatter Lance's `vsFrozenBonus` rider (`:1252`) and Shatterpoint directive (`:1827`) — the ONLY sanctioned "shatter" carriers, plus Cold Logic.
- **Cosmetic:** `freeze_flavor` ice / petrify (Accretion) — die crust tint only (`battle_feedback.gd:39-48`).
- **Audit:** `_run_enemy_freeze_regression` (`ability_audit.gd:538`), `_run_freeze_regression :2459` (re-freeze adds), `_run_freeze_repeat_regressions :2477` (immunity ×3, chain unwind, lowest-die pick, ally repeat), plus `freeze_engine_regression.gd`.

## Why it works that way

- The dice-suppression budget is SPENT: jam / rewrite / hijack / freeze is the ceiling (INVARIANTS #4). `curseDice` is a dead fifth (see findings).
- Pierce/Breach kept distinct (K2), Cloak trimmed to 2 clauses (K1), Taunt unified (K3), Jam cap 10 (K4) — all Kev-ruled; do not relitigate.
- Chain ratio, execute bonus, and boss cadences are BALANCE-TODO constants behind the sweep-only tuning seam (`combat_manager.gd:112-131`), deferred by DECISIONS #8–#10.

## What it replaced

| Dead mechanic | Replaced by | Where recorded |
|---|---|---|
| Counterspell-% | deterministic Ward → displayed **Firewall** | TRUTH doc adjudications |
| Retaliate | **Spike** | ground truth (keyword batch) |
| Venom / Decay DoT flavors | **Burn**, game-wide | TRUTH ("DoT renamed Burn") |
| Cower | merged into **Freeze** (Petrify = Accretion cosmetic) | TRUTH |
| Lure | **Taunt**, both directions (internal `lured_by_id` kept) | K3, commit 0bd652c |
| Freeze bank/thaw + lockout | **Freeze = repeat** | DECISIONS #1, 52e2fa5 |
| `DETONATE_MAX_TURNS` cap | permanent-burn one-tick rule | DECISIONS #4 |
| Pierce-from-Cloak clause | removed | K1, commit 4474ab3 |
| `curseDice` (roll twice keep lower) | removed from data (3b16f36); handlers remain dead | findings |
| `shT` multi-round shields | never existed in current data (audited, zero offenders) | DECISIONS #2 |

## File locations

- `data/raw/keywords.data.json` — canonical defs + pip codes
- `data/raw/primers.data.json` — first-sighting one-liners
- `scripts/battle/combat_manager.gd` — every handler
- `scripts/ui/effect_pip.gd` — pip rendering registry
- `scripts/battle/battle_feedback.gd` — keyword feedback beats
- `scripts/debug/ability_audit.gd`, `scripts/debug/audit_ability_keywords.py` — enforcement

## Known edge cases

- Detonate and Execute bursts are "real hits": they consume Marks and trip Spike.
- Leech ignores chain-jump damage; only matters on two-keyword overload faces.
- Mark is consumed by a fully shield-absorbed hit but NOT by a hit zeroed by damage-reduction gear.
- An AoE + single-target-rider enemy ability (e.g. blastAll + jam) still takes a personality pick for the rider (`_ability_targets_single_hero :179`).
- `_get_total_burn_bonus` takes the MAX burn-gear bonus across living heroes and applies it to every enemy burn tick, whoever applied the burn (`combat_manager.gd:525, 2440`).

## ⚠ Open findings

<!-- AUDIT-LINKS:keywords -->
- [A-004](../audit/INTERACTION_AUDIT.md#a-004) - [confusing] leech tracer points at the pre-retarget enemy
- [A-008](../audit/INTERACTION_AUDIT.md#a-008) - [dead] curseDice - wired 5th die-tamper with zero data
- [A-021](../audit/INTERACTION_AUDIT.md#a-021) - [needs-Kev] reserved mechanic words in flavor ability names
- [A-022](../audit/INTERACTION_AUDIT.md#a-022) - [confusing] chain targets lowest HP ratio, text says lowest-HP
- [A-023](../audit/INTERACTION_AUDIT.md#a-023) - [confusing] spike triggers on absorbed but not reduced hits
- [A-024](../audit/INTERACTION_AUDIT.md#a-024) - [needs-Kev] spike/flat riders pay out per damage packet
- [A-025](../audit/INTERACTION_AUDIT.md#a-025) - [confusing] leech ignores chain-jump damage (latent)
- [A-029](../audit/INTERACTION_AUDIT.md#a-029) - [needs-Kev] hero-side Taunt never expires
- [A-030](../audit/INTERACTION_AUDIT.md#a-030) - [confusing] keywords.json comment says green = protocol
- [A-031](../audit/INTERACTION_AUDIT.md#a-031) - [needs-Kev] enemy 'lifesteal N%' vs hero 'Leech' naming
- [A-087](../audit/INTERACTION_AUDIT.md#a-087) - [confusing] GDD still describes the dead freeze lockout
