# Overload Protocol — TRUTH (Canonical Reference)

*Generated 2026-07-06 by reconciling `offline-bundle/GROUND_TRUTH.md` against the live code and data on `feat/keyword-batch` (post keyword-batch, post unlock system). **When any doc disagrees with this file, this file wins.** When this file disagrees with code, the code wins — fix this file and record the correction.*

---

## ⚠️ Doc adjudications (carried + new)

Verdicts from GROUND_TRUTH, re-verified against current code, plus corrections found during this reconciliation:

| Question | Stale claim (where) | **TRUTH (verified in code)** |
|---|---|---|
| Orientation | landscape (old GDD/ROADMAP) | **Portrait 1080×2400**, preview 540×1200 = exactly half (`project.godot`, INVARIANTS #14) |
| Squad size | 4 units | **3** (`GameState.SQUAD_UNIT_LIMIT := 3`) |
| Healer name | Systems Medic | **Splice Medic**, callsign SPLICE |
| Operations | "build 1 faction first" | **5 fully defined** (`battle-modes.json` order) |
| Boss phases | phase-2 systems | **Standing rules** from turn 1 (`combat_manager.BOSS_STANDING_RULES`) |
| Main scene | UnitSelect (GROUND_TRUTH §conflicts) | **`res://scenes/ui/MainMenu.tscn`** — splash boot scene; BEGIN → UnitSelect (`project.godot:run/main_scene`) |
| Footer actions | "Reroll, Nudge, Item" (GROUND_TRUTH §UI geometry) | **Reroll, Nudge, Set, Item** (`scripts/battle/protocol_actions.gd` — the protocol-spend module extracted from battle_scene, architecture review §1 rec 1) |
| Protocol color | "green = protocol" (GROUND_TRUTH §visual identity) | **Protocol pips are amber** (`PixelUI.DT_AMBER`); green is reserved for **HP bars / heal** |
| Jam cap | 12 | **10** (`combat_manager.JAM_CAP := 10`, keyword batch Task 5) |
| Ward | "Ward", 17 enemy instances | **Firewall** (code FW; internal field still `ward`), enemy instances culled to **10** (6 Veil + 4 Synod); hero-side 3 renamed not culled |
| Lure | separate keyword | **Deleted** — unified into **Taunt** both directions |
| Cloak | 3 clauses (first attack gains Pierce) | **2 clauses** — pierce-from-cloak removed (keyword batch Task 7) |
| Freeze semantics | banked-face bank/thaw model (GROUND_TRUTH §7); later a next-turn static lockout | **FREEZE = REPEAT** (per Kev 2026-07-06, FINAL): the crusted die keeps its face and its unit acts AGAIN on that result for N repeats, then thaws. Both older models are dead — full lineage in `docs/DECISIONS_RESOLVED.md` #1 |
| Cross-run unlocks | "out of scope" (GROUND_TRUTH §out of scope) | **In scope and shipped**: hero ladder + operation chain in SaveManager (persistent XP remains out of scope) |
| Sim clear rate | "flat sim ~1.7%" (TASK_QUEUE); 0.53 pre-repeat; 0.2533 pre-crit-banking | **`scripts/sim/baseline.json`**: policy `l1`, 300 runs — overall **0.2867**, facility **0.5915** (post crit-banking checkpoint, BASELINE-APPROVED-BY-KEV 2026-07-06). Older figures are reference only |

**Docs archived** (in `docs/archive/`, do not use): PHASE_0_STATUS.md, CURSOR_HANDOFF.md, HANDOFF_loadout_item_bugs.md, ANGULAR_TO_GODOT_MAPPING.md, BASELINE.md.
**Living docs:** `docs/INVARIANTS.md` (the WHY rules — read immediately after this file), `docs/DECISIONS_RESOLVED.md` (closed rulings — never relitigate), `docs/TASK_TEMPLATE.md` (every task's skeleton), `docs/AI_AGENT_GAME_REFERENCE.md` (runtime map), `docs/BATTLE_UI_V2_SPEC.md` (layout contract), `docs/GDD.md` (design intent only), `offline-bundle/CODEBASE_MAP.md`. `offline-bundle/GROUND_TRUTH.md` is superseded by this file.

---

## The game in one paragraph

Portrait mobile (Android-first, Godot 4.6) dark sci-fi tactical dice roguelike. Pick **3** specialists from the 8-hero roster (3 starters; the rest unlock via the hero ladder), choose an unlocked operation (facility first; each boss clear unlocks the next), fight **10 battles** (boss on #10). Each turn every living unit rolls a D20; the roll lands in one of five zones (recharge/strike/surge/crit/overload) that maps to that unit's ability. Player resolves abilities (chosen order, manual targeting where needed), then enemies resolve. Protocol is a battle-only resource for dice manipulation (Reroll / Nudge / Set / Item). Between battles: pick 1 of 3 rewards (gear/consumable), Relic at battle 5, units earn XP and evolve (2 branching paths each, directives at 250 XP). Win = beat the boss; lose = full wipe.

---

## Combat rules (authoritative)

1. All dice roll simultaneously at turn start.
2. Player resolves first, in any order; then surviving enemies resolve.
3. End of turn: status effects tick, dice reset.
4. A unit that dies mid-turn does not act.
5. Shields last **one opposing action phase** (per-side expiry, CONFIRMED per Kev 2026-07-06, DECISIONS_RESOLVED #2): granted this round, absorb through this round's opposing phase, gone at the round-end tick (no `shT` field exists anywhere in data — audited 2026-07-07, zero offenders). Enemy-phase grants survive one tick so they cover exactly one hero phase. **The SINGLE named exception is `shieldsPersist`** (Mantle Core relic / MANTLE TYRANT standing rule), which keeps shields until broken — nothing else may persist a shield. A unit's **total shield is capped at its max HP** (`_cap_shield_at_max_hp`), so persistent shields can't accumulate without bound from per-round drips like Bulwark Aura / Aegis Field (audit A-034). Aegis Field (`healGrantsShieldAll`) only fires on **friendly** heals — an enemy heal no longer shields the squad (audit A-033).
6. Protocol resets each battle (does NOT carry over; Overflow relic carries 50%).
7. **Freeze = REPEAT** (one keyword, identical both sides; per Kev 2026-07-06, FINAL — restores the original design intent, supersedes both the next-turn lockout and the fix-1.4 bank/thaw banked-face model, see `docs/DECISIONS_RESOLVED.md` #1): a frozen die crusts and stays static in the tray as a hard physics blocker other dice bounce off. On each of its next N rolls it does NOT reroll — it keeps the same face, and its unit **acts again on that same result: same zone, same ability**. Targeting is re-picked fresh on each repeat (manual pick for heroes, personality choke-point for enemies); only the die result is locked. After its authored N repeats the die thaws and rerolls normally. While frozen the die is **fully immune to alteration** — Jam, Rewrite, Hijack, **Nudge**, Reroll, Set, and Twin-Fates all bounce off (one clean rule: "a frozen die can't be altered", per Kev NK-03). 20-face riders (Overload Capacitor Protocol, the 20s stat, Overload Loop, the enemy elite-summon roll) fire **once, on the original resolution — never on a freeze repeat** (per Kev NK-04); enemy summon rolls respect the freeze decrement. Any freeze ability with **no damage component** (incl. shield+freeze / heal+freeze) uses `freezeAnyDice` — one manual pick, EITHER side (freezing an ally repeats their good roll on purpose); freeze riders on damaging abilities stay enemy-side. **Enemy AI freeze targets the hero's LOWEST revealed die** — deterministic, no randi (taunt still overrides; cloak still hides). Re-freezing adds repeats; a frozen unit whose repeated ability applies freeze chains legally (each repeat decrements — no infinite loop). Deep Freeze directive extends the repeat count. Cosmetic `freeze_flavor`: ice (default) / petrify.
8. **Firewall** (internal field `ward`, displayed Firewall/FW): blocks the next ability that targets the unit, then breaks; an AoE that includes the unit is blocked for that unit only.
9. Zone names in data: `recharge` (low) → `strike` → `surge` → `crit` → `overload` (the 20). **These five words are INTERNAL KEYS ONLY** (Batch 2 band-vocabulary rule): never use them to name or describe dice bands in player-facing copy, documentation, or design discussion — player text refers to a band by its numeric range ("1–4", "20") or not at all, and never claims higher bands are strictly stronger (they are not). Proper nouns are exempt (Strike Unit, Overload Protocol, Overload Capacitor, Core Surge, etc.).
10. **Buff/DoT timers are independent instances** (per Kev 2026-07-06, FINAL — resolves old DECISIONS #3, see `docs/DECISIONS_RESOLVED.md`): roll buffs (`rfm` heroes / `erb` enemies, identical) and Burn no longer refresh on re-cast. Each application is its own instance with its own remaining duration; the effective value is the SUM of live instances; each expires on its own clock. Canonical stacking case: +3/2t cast turn 1 plus +5/2t cast turn 2 → turn 2 total +8, turn 3 total +5, turn 4 zero. Burn instances run independent clocks; the display aggregates ONE chip: summed value, longest remaining duration.
   **Duration convention (Kev 2026-07-13, supersedes the old "N−1 / eat-a-turn" encoding):** a duration field stores **N effective turns** — the status is present for exactly N turns and absent on turn N+1. Whether the CAST round counts toward N depends on whether the buff can shape that round's roll:
   - **Current-roll buffs** (items — fed into `get_effective_roll` before the beneficiary commits) shape the cast round, so it counts; they do NOT skip the cast-round tick (`_add_roll_buff(..., shapes_current_roll=true)`). A `turns:1` item grants exactly one roll (the current).
   - **Future-shaping buffs** (enemy self-buffs cast after their roll is spent; reactive relics like Emergency Signal) cannot shape the cast round, so it does NOT count; they skip the cast-round tick (`shapes_current_roll=false`). A `turns:1` enemy buff shapes exactly one subsequent roll.

   Two application timings, one meaning of N. **Never fix an off-by-one by shrinking the number** — that hides the timing bug and makes the field mean something other than its name; fix the tick (the `skip_next_tick` flag). Burn / RFE / enemy-hostile `rfm` already carry the skip flag (`N = N`); freeze is consumption-gated (`N` repeats). History: this replaced a broken encoding where roll buffs alone lacked the skip flag, so `erbT` silently meant N−1 — the "three 1t casualties corrected to 2t" on 2026-07-06 were bandaging that; on 2026-07-13 the tick was fixed and all 30 enemy `erbT` + Emergency Signal were decremented to their true effective values (behavior-preserving). Display renders the stored value directly, no arithmetic.

## Protocol economy (battle_engine.gd / battle_scene.gd)

- **Income:** start each battle at **0**, gain **+1 at the END of every turn**. Cap **10** (`MAX_PROTOCOL`).
- **Costs:** Nudge **1** (+3 to effective roll) · Reroll **2** · Set-a-die **4** (`SET_DIE_COST`) · Item **1 flat** (all rarities).
- **+protocol sources:** gear `protocolOnBattleStart`, `protocolOnKill`, `protocolOnNat20` (Overload Capacitor — grants at resolution when a die's FINAL face is 20, amount read from gear data, once per die, not on freeze repeats), `protocolOnDieTamper` (Mirror Plate — only an ENEMY tamper pays out; friendly freeze-any on an ally does not, audit A-062); relics `protocolCarryover`, `protocolOnItemUse` (Protocol Override — items cost 0 AND grant +1, **except protocol-gain items, which get no bonus +1** so they can't print Protocol for free, audit A-063), `protocolOnMarkedKill` (Salvage Directive +2), `protocolOnShieldBreak` (Salvage Rig +1, boss relic); enemy `siphon: N` drains the pool on hit (floor 0). **Summoned/rebuilt enemies grant no kill economy** (Protocol, Bounty, Chitin, Kill Switch, Momentum, Scavenger) — prevents stall-farming boss reinforcements (per Kev NK-10).
- **Discounts/overflow:** Priming Charge — first Nudge free; Root Access boss relic — first Set each battle 0; Overflow Vent — protocol past the cap deals 2 dmg/point to a random enemy; Twin Fates — once per battle copy one hero die to another, free.
- Footer shows "PROTOCOL n/m" with amber segment pips.

---

## The 8 heroes (heroes.data.json — COMPLETE)

Each has 5 base abilities + 2 evolution paths (each path = 5 abilities + 2 directives). Callsign in combat, full name in menus.

| ID | Name | Callsign | Category | HP | Evolutions |
|---|---|---|---|---|---|
| `pulse` | Pulse Tech | PULSE | damage | 45 | Pyro (PYRO) / Arc (ARC) |
| `combat` | Strike Unit | STRIKE | damage | 55 | Bladecore (BLADE) / Ravager (RAVAGER) |
| `shield` | Spike Guard | SPIKE | defense | 55 | Bulwark (BULWARK) / Sentinel (SENTINEL) |
| `avalanche` | Avalanche Suit | AVALANCHE | defense | 55 | Glacier (GLACIER) / Trench (TRENCH) |
| `medic` | Splice Medic | SPLICE | support | 50 | Combat Medic (MEDIC) / Synth (SYNTH) |
| `engineer` | Field Engineer | ENGINEER | support | 50 | Overclocked (OVERCLOCKED) / Phantom (PHANTOM) |
| `ghost` | Ghost Operative | GHOST | control | 45 | Shadow (SHADOW) / Wraith (WRAITH) |
| `breaker` | Signal Breaker | BREAKER | control | 45 | Noise (NOISE) / Nullwire (NULLWIRE) |

**Legacy id quirks (do NOT change):** Strike Unit=`combat`, Spike Guard=`shield`, Splice Medic=`medic`. Freeze belongs to the Avalanche line only (hero-side); ±Roll chips to the Signal Breaker line only. Starters: `combat`, `engineer`, `medic` (Batch-1 swap 2026-07-11 — Field Engineer replaced Avalanche Suit as a starter; Avalanche now unlocks at hero-ladder rung 1).

**Unit Category is INTERNAL-ONLY (Batch 2, do NOT surface player-side):** the `pickerCategory` field (damage/defense/support/control) stays in the data and drives backend ordering + role-badge tint, but is **never shown to the player as text** (`home_screen.gd:869` hides the category chip). Do not "fix" it back into any card/detail UI — its absence from player copy is deliberate. **Violation looks like:** a category label rendered on a unit card, squad tile, or detail panel; or code reading `picker_category` to build visible player text.

## Ability eff text syntax (canonical)

Format: `[value type] [modifier] [target] [duration]`, clauses joined by `, ` (comma-space); AoE marked with a trailing `(all)`. Numbers first, type second, target third, duration last; target omitted for single enemy; duration omitted when instant. (Per Kev NK-17: the comma / `(all)` house style is canonical — the data uses it 100%; the earlier ` + ` / bare-`all` grammar was never adopted and is corrected here.)
- Damage `12 dmg` · `9 dmg (all)` · `10 dmg, pierce` · Burn `4 burn 3t` · Heal `8 heal ally` / `13 heal all` / `11 heal lowest` · Shield (one round, no suffix) `ally 9 shield` / `all 14 shield` · Roll `+3 roll ally` / `-2 roll all enemies 2t` · Protocol `+2 protocol` · Status `freeze (repeat 1)` / `freeze any (repeat 1)` / `freeze all (repeat 1)` / `cloak` / `self firewall` / `taunt` / `rampage +1` · Boss extras `wipe shields` / `summon 40%` (no phase-2 syntax).
- **Target suffix is gate-enforced (Polish Build D, INVARIANTS #17):** a value clause (dmg / shield / heal / roll) carries the parenthetical suffix its computed scope requires — `(self)` for a self-buff, `(all)` for AoE, `(lowest)` for lowest-target, none for single-target — matching how `effect_pip.gd` derives scope from the structured fields. `scripts/checks/effect_text_target.py` checks every enemy + hero ability (count-based, so a doubled `(self)` fails like a missing one); keyword-only clauses keep their own convention. The Build-D sweep added the missing `(self)` to 27 enemy self-buffs and the missing `(all)` to 5 hero AoE clauses.
- **Equipment self-buff exception (Build G amendment, Kev 2026-07-15):** GEAR and RELIC (and consumable) effects that buff the HOLDER omit the `(self)` marker AND the self-target icon — equipment context makes the holder implicit, so a holder-buff reads bare ("5 shield", never "5 shield (self)") and its pip row carries no circled-figure marker (`EffectPip.effects_from_passive` strips the `self` scope; `all` / `lowest` scopes stay). ABILITY eff text keeps NK-17 exactly as-is. Gate-enforced both directions by `scripts/checks/effect_text_target.py`: abilities must carry their computed suffix; gear/relic/item text must carry NO `(self)` anywhere.

**Roll-modifier duration display (rewritten 2026-07-13 — the number now means
what it says):** every duration field stores **effective turns** (see #10), so
eff text and the pip both render the stored value **directly, no arithmetic**.
A future-shaping buff of `erbT:1` shows no suffix (a single subsequent roll, like
a one-round shield: `+1 roll (self)`); `erbT:2` shows `2t` (`+2 roll (all), 2t`).
Debuffs likewise: `−2 roll, 2t`. (This replaces the Batch-1 "eff text shows N−1"
convention, which existed only to paper over the roll-buff tick bug — that bug is
fixed, the backend values were decremented to their true effective counts, and
display arithmetic is gone. Do NOT reintroduce an N−1 rule.)

### Data field glossary
`dmg` · `burn`+`burnT` · `heal`(+`healTgt`/`healAll`/`healLowest`) · `shield`(+`shieldAll`/`shTgt`/`shieldLowest`) · `rfe`+`rfT`(+`rfeAll`) · `rfm`+`rfmT`(+`rfmTgt`) · `ignSh` (pierce) · `blastAll` · `cloak` · `ward`(+`wardTgt`; displayed Firewall) · `taunt` / `enemySelfTaunt` · `revive` · `freezeAnyDice`/`freezeEnemyDice`/`freezeAllEnemyDice` (+`freeze_flavor`). **Max ONE manually-picked component per hero ability** (audit-enforced).

**⚠ Every effect field needs a pip branch (2026-07-12):** the battle readout strip
renders PIPS, not eff text — an effect that exists in an ability's eff string but has
no branch in `EffectPip.effects_from_ability_raw` is **invisible to the player in
battle and unteachable by the primer system** (primers key on rendered icons).
Precedent: `gainProtocol` was in four eff strings ("+N protocol") but had no pip
branch — Field Patch, a starting-trio unit whose job is teaching the Protocol
economy, showed no protocol pip at all until the 2026-07-12 fix. **When adding a new
effect field: add the `effects_from_ability_raw` branch in the same change.** Enemy
ability fields are fully covered. Gear/relic passives are a different pipeline —
cards display their desc text prominently, so the 26 types on the generic-tag
fallback are **ruled fine as-is (Kev 2026-07-12): leave them.**

**Conditional-modifier notation (Kev ruling 2026-07-12 — the standard):** a
conditional bonus renders as a **+N suffix + condition icon on the base pip** —
Shatter Lance reads `10 +5❄` (10 dmg, 5 more if frozen), Permafrost Aegis `14 +8❄`.
NOT a second pip (eats the 3-pip budget), NOT a tint (a blue number says "cold", it
doesn't say "+5"). The notation is base + bonus + condition-icon and generalizes to
every future conditional (vs-burning, vs-marked, vs-shielded); long-press eff text
carries the full wording. This matters: Shatter Lance / Permafrost Aegis are the
whole payoff of the Glacier branch — before this the freeze→bigger-hit synergy that
defines the evolution was invisible. Implemented via `bonus`/`bonus_icon` on the
effect dict (`EffectPip._append_effect` → `build_group` / `estimate_display_width`);
the condition icon participates in first-sight primer teaching like any other icon.

### Keyword engine (combat_manager.gd handlers ↔ keywords.data.json ↔ EffectPip codes)

| Keyword | Pip | Rule (verified) |
|---|---|---|
| Chain | CH | also hits lowest-HP other enemy at 50% round down; ×2 adds a jump |
| Detonate | DT | consume finite Burn: amount × remaining turns immediate; a PERMANENT burn adds one tick's damage and is NOT consumed (per Kev 2026-07-06 — `DETONATE_MAX_TURNS` removed, resolves old DECISIONS #4) |
| Execute | EX | target below 25% max HP after base damage → +8 flat bonus |
| Breach | BR | destroy all shield on target (or every enemy) before damage |
| Leech | LC | hero side: attacker heals 50% of HP damage dealt (after shields). Enemy side carries a tunable `lifestealPct` (35–55%) shown in eff text as "lifesteal N%" — same LC pip, intentional per-kit variant (per Kev NK-09) |
| Spike + flat riders | SP | Spike and flat vs-state riders (Cold Logic, Deep Cuts, Shatterpoint) fire **once per ABILITY per target**, not per damage packet (per Kev NK-06) — a multi-packet ability (base + execute + detonate + chain) can't stack them |
| Mark | MK | next real hit +50% round up, then consumed |
| Spike | SP | this round, damaging the carrier costs N back; never persists |
| Jam | JM | target's next roll capped at **10** (`JAM_CAP`); die status, no chip |
| Rewrite | RW | target's next roll SET to 3; telegraphed |
| Hijack | HJ | enemy-only: next roll copies heroes' current highest die (voidScribe Checksum Copy, voidGlimmer Afterimage, spewer Mimic Gland) |
| Siphon | SI | enemy-only: on hit drain N Protocol (floor 0) |
| Taunt | T | unified (Lure deleted): "The taunted unit can only target the taunter." **SINGLE-TARGET (Build G ruling G-4, Kev 2026-07-15):** a hero taunt is a manual ONE-ENEMY pick — that enemy gets `lured_by_id` and every one of its targeting paths (`_resolve_enemy_hero_target`, the freeze lowest-die pick, `personality_pick_target`) redirects to the taunter, overriding cloak; other enemies keep their personalities; multiple heroes may taunt different enemies in one round; a firewall blocks (and is consumed by) the taunt; no pick supplied (sim/auto) falls back deterministically via `_hostile_single_target`. Enemy-side keeps its shapes: beastHyena's lure restricts the hit hero; veilPrism's `enemySelfTaunt` self-aura restricts all heroes (each taunted unit → the one taunter, def-consistent). The TAUNT chip sits on whichever unit is LURED, either side. Anchor Frame gear keeps its stance aura pending its own ruling — the one remaining aura-form taunt. **Both sides clear at round end** (per Kev NK-08) |
| Pack Bonus | — | enemy-only (Accretion `beastMonkey`/`beastWolf`): a `packBonus` attack deals **+1 per OTHER living pack member of the same KIND** (`enemy_type`, so Obsidian + Slag hounds pack together); self excluded. Fixed 2026-07-08 — the count compared unique instance ids (`beastWolf#1` vs `#2`) so it never fired; now compares `enemy_type` |

**Cloak (2 clauses):** untargetable by hostile single-target abilities — friendly picks on cloaked allies are ALWAYS legal (CONFIRMED, DECISIONS_RESOLVED #12); breaks when the unit deals damage OR is hit by an AoE. The "first attack from Cloak gains Pierce" clause is REMOVED. Friendly picks on cloaked allies stay legal.
**One keyword per ability** (pierce counts), **two allowed in overload** — audit-enforced.

---

## Enemies (enemies.data.json — 5 factions, 38 unit defs / 37 kits)

| Operation | Label | Identity | Boss (b10 escort) |
|---|---|---|---|
| `facility` | Facility sweep | drones: jam, shields, breach bait | SCRAPMASTER (+2 Scrap Drones) |
| `hive` | Hive incursion | swarm: burn, siphon, summons, spike | Hive Matriarch (+Spine Stalker) |
| `veil` | Veil Concord | lattice: ally shields, firewalls, buffs | CONCLAVE OVERSEER (+Aegis Anchor) |
| `voidCirclet` | Null Synod | machine cult: rewrite, hijack, siphon, ±roll | ROOT HIEROPHANT (+Checksum Scribe) |
| `stellarMenagerie` | The Accretion | igneous beasts: accrete, petrify, spike, cloak | MANTLE TYRANT (+Geode Panther) |

Enemy firewall instances: exactly **10** (6 Veil: Lattice Link, Fortress Lash, Conclave Bulwark, Harmonic Mend, Annulment, Synaptic Tune · 4 Synod: Seal Sigil, Init Collar, Mass Snare, Hierophant Mantle). Enemies don't use Protocol.

**Targeting personalities (`scripts/battle/targeting_personality.gd`):** every hostile single-hero pick goes through ONE choke-point `personality_pick_target(enemy_state, hero_states, assignments_so_far)`, shared by UI and headless sim; no `randi()`. **SYSTEMATIC** (left→right by slot) · **WOUNDED** (lowest-HP) · **PACK** (joins an already-assigned hero; none → WOUNDED) · **SPITEFUL** (last hero to damage it, `last_attacker_id`, cleared on that hero's death; none → SYSTEMATIC). Universal: taunt overrides everything; cloaked heroes skipped; dead/illegal preferred target → the STATED fallback only (old "pure debuff → highest HP" special case REMOVED). Resolution: unit `targeting` field → kit table → SYSTEMATIC. Kit defaults: Facility SYSTEMATIC (guard/patrol/volt PACK; warden/boss WOUNDED) · Hive PACK (stalker/hiveBoss WOUNDED) · Veil WOUNDED (veilPrism/veilShard SYSTEMATIC) · Synod SYSTEMATIC (voidBinder/voidChanneler/voidCircletBoss WOUNDED; voidGlimmer SPITEFUL) · Accretion SPITEFUL (beastWolf/beastMonkey PACK; beastLynx WOUNDED). `ai_type` is UNTOUCHED and independent (20-face elite summons + summon-injection guard). Enemy inspect shows "TARGETING: NAME — definition."

**Boss standing rules** (one always-on rule per boss, from turn 1, `BOSS_STANDING_RULES` keyed by display name): SCRAPMASTER — ASSEMBLY LINE, every 2nd enemy phase from its first activation rebuilds one destroyed Scrap Drone at 50% HP (DECISIONS_RESOLVED #5) · Hive Matriarch — THE BROOD, spawns a Bloodmite every 3 rounds · CONCLAVE OVERSEER — THE COURT, while any ally lives gains a Firewall each round start · ROOT HIEROPHANT — ROOT ACCESS, every round Rewrites the squad's highest die to 3 · MANTLE TYRANT — ACCRETION, +6 shield every round start, shields persist and stack. Round-start rules fire before the hero phase; turn-cadence rules at the start of the enemy phase.

---

## Rewards

- **Consumables:** 25 (`items.data.json`). **Gear:** 31 passives (`gear.data.json`) — **unique per run**: an owned gear id is never re-offered, so numeric passives can't stack (per Kev NK-13). Consumables are exempt (they're spent). **Relics:** 35 = 30 draftable + 5 boss relics (`bossRelic: true`: Salvage Rig, Chitin Graft, Resonant Chorus, Root Access, Mantle Core); boss relics excluded from normal drafts, unlocked by first op clear, offered as Starting Directives at DEPLOY.
- **Rarity ladders:** an effect family may span **any number of rarity tiers** — 2-, 3-, and 4-tier chains are all permitted (roll-buff and gainProtocol run four tiers; enemyRfe three). The old "single-entry + max 4 two-tier pairs" cap is **removed** (per Kev NK-12); no pool content was cut.
- **XP:** `XP_TO_EVOLVE = 100`, `XP_TO_DIRECTIVE = 250`. Per win: alive → `20 + round(avg effective roll)`; dead → `round(avg effective roll)`. One progression stop per win (extras deferred).
- **Directives (tier-3 passives):** at 250 XP an evolved unit picks 1 of 2 path-scoped directives (`directives` block per evolution). Full list in `heroes.data.json`; handlers in combat_manager (+battle_scene for Deep Cells).

## Save system + progression (SaveManager autoload)

`user://save.json`, `save_version: 1`: `{tutorial_done, stats: {runs_started, runs_won_by_op, best_clear, best_clear_by_op, nat20s, deaths, battles_fought}, unlocks: {boss_relics, heroes: ["combat","engineer","medic"], operations: ["facility"], hero_ladder_rung: 0, heroes_new: [], item_gates_awarded: 0}, onboarding: {primers_seen: []}, settings: {}}`. Headless runs keep the profile in memory and **read as fully unlocked** so sim/audit can pick any hero/op. `onboarding.primers_seen` drives the keyword primers (one-shot micro-tutorials, `docs/PRIMERS.md`); pre-primer veteran saves are grandfathered with all current primers seen.

- **Hero ladder** (ONE rung max per run end; overshoot defers): (1) facility best_clear ≥ 6 OR runs_started ≥ 3 → **avalanche** (Batch-1 swap: this rung-1 gate moved from engineer to avalanche when engineer became a starter; tutorial runs no longer increment runs_started per DECISIONS_RESOLVED #13; profiles that already banked tutorial runs keep the count — grandfathered, no retroactive adjustment) · (2) facility won → **shield** · (3) hive best_clear ≥ 6 → **pulse** · (4) hive won → **ghost** · (5) veil best_clear ≥ 6 → **breaker**.
- **Operation chain** (uncapped): boss clear unlocks the next — facility → hive → veil → voidCirclet → stellarMenagerie.
- **Grandfather clause:** pre-unlock-schema profiles that have played unlock everything, ladder maxed.
- `check_new_unlocks()` feeds the **UnlockScreen** (Build F — the old run-end amber UNLOCKED panel is retired); `heroes_new` drives the NEW badge (cleared on first squad add). Locked heroes/ops render as black silhouettes + `[ LOCKED ]`, no hints. Dev tools (help menu SETTINGS): UNLOCK ALL (now includes item gates), RESET SAVE PROFILE (two-step), RESET PRIMERS.

### Unlock progression — THE FENCE (Build F, Kev 2026-07-15)

Unlock progression is **ordered buckets + battle-count gates**, and nothing else.
**FORBIDDEN, now and forever without a Kev ruling:** unlock trees, unlock currency,
a collection screen, per-item unlock ceremonies, mid-run pool changes. The moment a
future change wants any of those, it has left the sanctioned design.

- **Metric: BATTLES FOUGHT** — every encounter entered counts exactly once, win or
  lose. Not rounds (farmable). Losing runs progress unlocks.
- **Earning vs awarding are split:** the battle counter accrues during play, but
  gates are **evaluated at run end only**. Pools never change composition mid-run.
  Everything crossed during a run lands together on the unlock screen.
- Consumables, gear, AND draftable relics are bucket-gated. Boss relics stay
  **event-gated** (kill boss → unlock), outside the battle schedule; they join the
  unified unlock screen when earned.
- Buckets are small (2–4 items), hand-ordered simple → weird (complexity ordering is
  design work, CSV-approved by Kev — never a heuristic).
- Schedule shape: **escalating spacing** — fast early, continuously widening tail
  (gates 1–4 every 3 battles, then gaps grow one at a time: +4, +6, +7, +8… up to +15
  at the last gate; exact counts are tuning, the shape is the design; see the Build H
  retune below for the current thresholds). A first run opens several buckets even on a
  loss.
- **All sim baselines assume FULL pools** — the balance sim and every harness draft
  pool run fully unlocked, explicitly pinned in the harness.

**Shipped mechanics (Build F):** `stats.battles_fought` increments exactly once per
encounter entered (`battle_scene._init_live_battle`, live entries only — review
re-entries and the tutorial never reach it; a retreat still counted its entry).
`unlocks.item_gates_awarded` advances ONLY in `SaveManager._evaluate_item_gates`
(run end); a retreat-abandoned run has no run end, so its crossings catch up on the
next completed run's screen — deferred, never dropped. Buckets + schedule + floors
live in `data/raw/unlocks.data.json`, hand-ordered and pinned equal to the approval
CSV `docs/UNLOCK_BUCKETS.csv` by the `pool floor` gate
(`scripts/checks/unlock_pool_floor.py` — completeness: every live consumable/gear/
draftable relic in exactly one bucket, non-zero buckets 2–4 items, bucket-0 floors
incl. the rarity sub-floors the intercept drafts need). **The pool choke point is
`DataManager.pool_ids(item_type)`** — the ONE sanctioned enumeration of the item
tables; every draw (reward drafts, battle-5 relic cache, intercept drafts, event
consumable grants, Foundry) routes through it and call sites cannot opt out
(`scripts/checks/pool_choke.py` bans `DataManager.items` outside DataManager.gd).
Isolated contexts (headless smokes, capture rigs) read full pools structurally;
`sim_runner` and `ability_audit` additionally call
`DataManager.pin_pools_fully_unlocked()` (the explicit Task-3 pin);
`force_pool_gating_for_test()` re-enables gating for the unlock regressions.
Item-gate grandfather: a played profile that predates the schema loads with every
gate awarded. **UnlockScreen** (`scenes/ui/UnlockScreen.tscn`): run summary →
UNLOCKS (only if the delta is non-empty — never an empty ceremony; victory AND
failure) → home. Transmission-window chrome; sections biggest news first — BOSS
RELIC (major-event gold card, full description; boss relics no longer unlock
silently) → NEW UNIT → NEW OPERATION → NEW RELICS → NEW ITEMS (4-across
`make_integer_icon` grids, name beneath); the screen scrolls on
fat runs, icons never shrink; single CONTINUE. **Build G polish (items 4–6,
Kev 2026-07-15):** section titles wear the Build-A filled header strip
(`component_header_style` plate, INVARIANTS #7 — headers rank, not body text);
EVERY grid icon rides the emblem plate uniformly (`make_integer_icon`
`force_plate` — a lone low-res plate read as a selection highlight); EVERY
element long-presses to its InspectPopup (boss relic card → `resolve_item`,
unit row → `resolve_unit`, operation row → the new `resolve_operation`, grids →
`resolve_item`). **The separate one-time operation-unlock popup is RETIRED
(ruled):** `OperationBriefingOverlay.present_unlock` is deleted; the NEW
OPERATION section shows the operation name (Title-Case label — battle-modes
labels fixed to "Facility Sweep" / "Hive Incursion") with its one-sentence
origin line beneath at body tier, and building the row acknowledges
`operation_origins_seen` so the one-time flag stays coherent. The deployment
slate's first-run behavior is unchanged. Regressions:
`scripts/debug/unlock_progression_test.gd` (counter integrity, run-end-only,
delta correctness, boss-relic announcement, sim pin) + the two checks above, all
in `verify_gate.py`. Captures: `scripts/debug/unlock_screen_capture.gd`
(`--capture-scenario=single|fat|boss`).

**Schedule retune — Build H (Kev 2026-07-17, data-only).** The middle of the
schedule opened too fast: the original gates put ~81% of the catalog in a player's
hands by battle ~50 (roughly run 6–7) while they were likely still in Hive. The
*ends* were correct — the start must NOT slow down (bucket 0 is floor-locked for the
intercept drafts, and the run-1/run-2 drip does anti-repetition work) and the tail was
already paced right — so this retune stretches only the middle. Same 17 gates, same
buckets, same bucket membership and order; **thresholds only.**
- OLD: `3 / 6 / 9 / 12 / 15 / 20 / 25 / 30 / 35 / 40 / 45 / 50 / 58 / 67 / 76 / 86 / 96`
- NEW: `3 / 6 / 9 / 12 / 16 / 22 / 29 / 37 / 45 / 54 / 63 / 73 / 84 / 96 / 109 / 123 / 138`
- Positional remap: the first four gates are unchanged; the 15-bucket now opens at 16,
  the 20-bucket at 22, … the 96-bucket at 138.
- Target curve (design intent, ~7 battles/early run): ~55% of catalog by run 3, ~70% by
  run 7, 100% around run 15–18 (~5–6 hours).
- **This schedule is an explicit playtest observable.** The next retune input is how
  demo testers react to pool variety — overwhelmed (too fast) vs starved (too slow) —
  NOT developer feel. Retune is a two-file edit (`unlocks.data.json` +
  `UNLOCK_BUCKETS.csv`, pinned equal by the pool-floor gate) by construction.
- Grandfather-safe in both directions: awarded gates persist as
  `unlocks.item_gates_awarded` (a monotonic counter advanced only forward at run end)
  and pools read from THAT counter, never re-derived from `battles_fought` vs the
  schedule at load — so a threshold change can never re-lock content a profile already
  holds. The pre-schema fully-unlocked grandfather is untouched.

## Run structure

- **Operation lore presentation:** the squad-select encounter carousel shows the selected operation's compact accepted site line; its existing detail panel shows accepted origin + descriptive threat summary when no hero is selected, and preserves the hero dossier when one is selected. An operation newly awarded at run end announces itself in the UnlockScreen's NEW OPERATION section — name + one-sentence origin at body tier (Build G, ruled: the separate one-time popup is retired). Every run stops before battle 1 on an ENGAGE-gated deployment slate. Battle 10 loads the battlefield first, then requires ENGAGE on a boss alert whose standing-rule mechanic is sourced from `CombatManager.BOSS_STANDING_RULES`; after acknowledgement the alert is dismissed (no persistent on-board reminder — the rule stays available via long-press inspect on the boss). Only origin acknowledgement is persisted in `SaveManager.onboarding`; old saves mark already-unlocked origins seen.

- **Item & relic caps (Polish Build D, Kev 2026-07-15):** consumables cap at **4** (`GameState.MAX_CONSUMABLES`, single source; `LoadoutMenu` derives its slot count from it). A pickup at cap opens the **discard picker** (`LoadoutMenu.open_discard`) — incoming stats shown, held items inspectable, **ABANDON**/tap-outside keeps all four and drops the incoming; nothing is destroyed by a dismissal, and a non-interactive event grant at cap forfeits explicitly. Relics cap at **2** (`GameState.MAX_RELICS`, one choke `_grant_relic`); they display **only** in the LoadoutMenu (one row per relic, up to two, no placeholder) and never on battle chrome. See INVARIANTS #15/#16.

- **Templated slots:** fixed comps (b1, b10, one signature per op) or slot patterns rolled ONCE at run start (`GameState.resolved_battle_comps`); previews always show exact comps.
- **Beats:** battle-5 relic draft = INTERCEPT: RELIC CACHE (renders through the reward picker in event chrome). The draft fires on `GameState.drafted_relic_count() == 0` — a pkg5 Starting Directive boss relic never consumes the slot and is excluded from the offer (the 2026-07-06 battle-5 soft-lock fix; regression-pinned). Exactly 3 random beats per run in distinct gaps from {after b2,b3,b4,b6,b7,b8} — the relic battle's gap is structurally excluded; Fork/Intercept 50/50 with ≥1 of each; b6+ = major tier.
- **Zero-options guard (permanent fixture):** any between-battle choice screen (reward, relic cache, intercept, route fork, evolution/directive) that builds ZERO interactive options asserts loudly in debug and auto-resolves a logged default in release (`scripts/ui/choice_screen_guard.gd`, `[CHOICE_GUARD]` log tag + telemetry stub) so a playtest build can never soft-lock on a dead screen. A guard firing is always a bug in the offer roll — fix the offer, never widen the guard.
- **Route Fork:** standard vs flagged (same comp + 1 of 10 modifiers from `GameState.BATTLE_MODIFIERS`, no repeats; SUPPLY GRADE +2 = reward ladder two rows deeper, cap row 10). A flagged route into the **battle-5 relic cache** (which has no rarity ladder) does NOT spend the grade — it **carries forward to the next item draft** (per Kev NK-15). **Intercept-armed modifiers consume the fork no-repeats pool** and won't silently overwrite an already-armed modifier; declined fork modifiers may still be re-offered (per Kev NK-16, audit A-077).
- **Intercept:** 11 minor + 11 major cards (`GameState.INTERCEPT_CARDS`), drawn without replacement; Memorial Protocol redraws without a recent death. **Draft picks commit directly (Build G item 9, ruled):** a pure item draft's select + CONFIRM on the reward screen is the ONE interaction — the intercept result stage no longer reconfirms it (`intercept_screen.draft_commits_directly`: skip when a drafted item exists and the effects produced no unseen info; reveal-type results and forfeit notes still show the stage). The Build-D at-cap discard picker is NOT a reconfirm and still fires from the reward screen's CONFIRM path.

---

## Battle UI geometry (layout contract)

Five stacked bands, portrait, 1080×2400 (preview 540×1200): Header 144 — Enemy rail (flex, floor 768) — Center rail (dice + centered action button; floor **540**, not the old spec's 432 — 432 clipped the readout pips into the dice, `battle_layout.gd`) — Hero rail (flex, floor 768) — Footer 144 (**Reroll, Nudge, Set, Item** + PROTOCOL n/m pips). The two rails share leftover height via EXPAND (adapts across phone aspects, stretch aspect = expand). Header height == footer height; all unit cards identical outer size; dice align to card slots; result tags are uniform die-docked plates (below hero dice, above enemy dice, never occluding the sprite). No scrolling. Touch-first.

**Safe area (Android Builds #1–#2, 2026-07-13, Pixel-8-verified):**
`PixelUI.safe_top/right/bottom/left` (four named ints, DESIGN px, all 0 on
desktop) is the single source of truth for display-cutout / gesture-bar insets;
`PixelUI.refresh_safe_insets` computes them (ceil, never floor — INVARIANTS #14)
and the always-alive `PersistentHeader` autoload drives refresh (ready + root
`size_changed`) and emits `safe_area_changed`. The header BAND grows by
`safe_top` (chrome paints under the punch-hole; only the Bar content shifts down
— `band_height()` = 144 + inset is what overlays clear); every between-battle
screen adds the insets to its authored edge margins at build time.
**Battle band ruling (Build #2):** the DICE FIELD absorbs the entire inset
budget — the board shifts below the grown band and above the gesture reserve,
and the center band gives up exactly `safe_top + safe_bottom`; rails, footer,
and header content keep their authored heights (desktop pixel-identical). The
Build-#1 footer bottom-pad mechanism is replaced by this. **Gesture reserve
(Build #2):** Android's `get_display_safe_area()` is cutout-only (Pixel 8
reported bottom 0 with a live gesture bar), so `safe_bottom` carries a floor of
`PixelUI.SAFE_BOTTOM_RESERVE` = 56 on Android only (`bottom_reserve()`), folded
into the same single inset — no parallel path. **Font root cause (Build #2, PROVEN
against the shipped Build-#1 APK's file list):** two call sites — 
`PixelUI.get_pixel_font` and `dice_tray_3d._get_dice_number_font` — loaded the
font via `FontFile.load_dynamic_font("res://assets/fonts/m5x7.ttf")`, the RAW
source path. Exports pack only the IMPORTED artifact + `.import` remap (the
APK contains `m5x7.ttf-*.fontdata` but **no raw `.ttf`**), so on device both
loads failed and each site's own silent `SystemFont` fallback rendered the
Android system font — every label AND the die numerals ("Bug 2" was never the
dice). Fixed: both sites load the imported resource via `load()` (single
source: `get_pixel_font`; the dice tray delegates), failing LOUDLY
(`push_error`) if it can't. Side effect: the six Phase-0 import params
(antialiasing=0 etc.) are now actually in effect on this path — desktop text
is not bit-identical, marginally crisper. `m5x7.ttf.import` also pins
`allow_system_fallback=false` (defense-in-depth for the theme path, NOT the
proven mechanism), and the diagnostic overlay's page 0 prints
`font_name`/`font_path`/`ttf_exists` (the on-device verdict line). Never load
a font (or any imported resource) by raw source path — the safe-area test
scans for `load_dynamic_font` at source level. Regression: `scripts/debug/safe_area_test.gd`
(in `verify_gate.py`). **The `SafeAreaDebug` overlay is a STANDING instrument
(Build #3 ruling — kept, not deleted):** two tap-toggled pages (display info
incl. the font-identity tripwire + m5x7 font ladder), default OFF, armed by the
Settings > DEBUG toggle (debug builds only — the section is structurally absent
in release; persisted via SaveManager `safe_area_overlay`) or the
`SAFE_AREA_DEBUG=1` / `SAFE_AREA_DEBUG_LADDER=1` env vars the capture harness
uses; arms/disarms live, never headless. The next device with new cutout
geometry gets diagnosed in one launch. **Footer bleed (Build #3):** the footer
sat 6.5px past the screen bottom (pre-existing; NOT the Build-#2 font fix —
measured identical under both loaders): `_position_zone_dividers` derived the
divider from the hero cards with no regard for the footer's 128px minimum, and
the grow-BOTH container split the 13px overflow half below the screen. Fixed at
the one writer: the divider clamps so the footer always gets its live combined
minimum above `safe_bottom` — footer bottom now lands EXACTLY on
screen − inset, whole design pixels, at zero insets and the Pixel 8 budget.
**Glyph coverage law (Build #3):** `allow_system_fallback=false` means an
m5x7-uncovered codepoint is a tofu box on device — every player-facing string
(data JSON + UI copy) is ASCII-only, enforced by the `glyph coverage` gate
(`scripts/debug/glyph_coverage_check.gd`, real `has_char()` coverage, never a
blocklist). The 2026-07-14 sweep replaced 159 sites (em dashes, `→`/`≤`/`▸`
arrows, nav `◀▶`, item/status glyph tables — incl. pre-existing double-encoded
mojibake in `compact_unit_card`/`ability_readout`). ETC2/ASTC: the project
setting is pinned true (stowaway since Build #1's commit) but is currently a
NO-OP — all 343 texture imports are Lossless (mode 0, correct for
NEAREST-filtered pixel art; platform-neutral); no texture uses VRAM
compression, so no etc2 artifacts exist and none are needed.

## UI & feedback

**Keyword primers** (`docs/PRIMERS.md`): one-shot micro-tutorials — first sighting of a mechanic pauses the feedback at a group boundary and spotlights one rule sentence (data: `primers.data.json`; full drain per turn; suppressed in headless/auto battle; in the scripted tutorial exactly ONE showcase primer displays — Kev 2026-07-21, see the tutorial block; observer-only, never touches combat outcomes). The tutorial and primers share `SpotlightLayer`.

**Rigged onboarding tutorial — v2, HONEST RIG (2026-07-20, supersedes the
Batch-5 script wholesale).** `scripts/ui/tutorial_controller.gd` +
`GameState.start_tutorial_run`. Principle: **rig the inputs, never fake the
outputs** — scripted dice and drone aim; real statlines, real damage, real HP.
- **The fight:** starting trio (Strike Unit / Field Engineer / Splice Medic) vs
  ONE Scrap Drone at its REAL 35-HP statline (the old 10-HP override is
  deleted). Drone roll rigged to 6 both turns = Stab, 7 dmg (the kit has no
  8-dmg band — copy was fixed to the engine per the v2 ruling), aimed at
  Strike via its real SYSTEMATIC slot-0 personality.
- **Rig v2.3 (Prompt-6 delta): MARK IS OUT OF THE DRILL.** Strike rolls 9
  (Suppression Fire, 6 dmg) instead of Target Lock — mark is taught by its
  PRIMER at first real-play sighting (suppression never writes
  `primers_seen`, so it fires). Cast order is carried by the first-assign
  beat line ("Your squad fires in the order you assign") plus the visible
  order badges. **Neither leech NOR mark appears on any rigged band**
  (smoke-asserted, including nudged +3 variants; no rigged band reaches 20 —
  the v2.1 leech/Shock-Therapy analysis stands).
  **Turn 1** rolls {combat 9, engineer 12, medic 2}: Suppression Fire 6 +
  Overdrive 11 = 17 (35 → 18) — with no setup effects the turn-1 math is
  **ORDER-INVARIANT** (audit-asserted under a fully reversed cast order),
  which is its own stall-proofing; Diagnostic Pulse (3 heal + 3 shield on
  Strike — the heal overflows at full HP, honest and harmless) soaks 3 of
  the Stab (Strike takes 4). **Turn 2** rolls {combat 8 → Nudged 11,
  engineer 12, medic 6}: the band jump (Suppression Fire 6 → Rail Strike 10
  — and the player FELT the 6 land in turn 1), a plain Overdrive 11,
  Infusion heal — the kill closes ON DICE (10 + 11 = 21 into 18). Protocol
  entering turn 2 is exactly 1 (income only): the "exactly one Nudge"
  framing, and a second Nudge is simply unaffordable (0-PP press refused,
  smoke-asserted).
- **Item lesson = SIGNPOST (Prompt-5 delta, rationale recorded):** the v2.1
  rig banked exactly 1 Protocol into turn 2, the Nudge spent it, and items
  cost 1 — so the item-USE beat was only survivable via the items_free
  fiction, which also mis-taught the item economy (a granted freebie whose
  cost was never paid). Both the Shock Charge grant and the tutorial
  items_free effect are DELETED; the item beat is now an informational
  tap-through signpost (right after the band-jump beat, holing the footer
  item button — it renders with an empty loadout) stating the REAL cost:
  "using one costs 1 Protocol, same as a Nudge, and doesn't spend a die"
  (verified against `item_protocol_cost`: flat 1). The `item_used` tutorial
  event emission remains as generic plumbing, currently unconsumed.
- **25 steps (v2.4, primer-showcase delta — Kev 2026-07-21)**: no status-badge
  beat (chip teaching is DELEGATED TO PRIMERS, Kev ruling); the order-badges
  beat is DELETED (playtest ruling — no badge explanation, no resequencing
  encouragement); beat 3 introduces the DRONE only (the squad is carried by
  the bands beat); both friendly picks stay (shield T1, heal T2); beat 15
  (right after the turn-2 waiter) is the PRIMER-SHOWCASE EXPLAINER — it holes
  Splice Medic's pip readout and names the one-time-tip mechanic, with copy
  that stands alone on a replay where nothing displayed. Step gate schema has the optional `hero` payload
  predicate — `assigned` gates match a SPECIFIC hero — plus the `item_used`
  event emitted where `_apply_item_effect` resolves. Spotlight keys:
  `die:<unit_id>` / `card:<unit_id>` (fall back to the unit), `item` (footer
  consumable button), `enemy_card` / `enemy_pip` / `enemy_die` (the first
  enemy's card / ability pip / die — the telegraph beat's separate holes).
- **Two-stage assign spotlight (playtest items 5/6 — THE RULE):** every step
  gated on `assigned` with a `hero` predicate spotlights the hero's die +
  card (separate holes) as stage 1; when THAT hero's `targeting_started`
  fires, the holes MOVE to the legal target(s) — enemy card + die for
  hostile picks, the legal ally card(s) for friendly picks — so the player
  never taps into dimmed screen. Reuses `targeting_started` + `set_holes`,
  coach text unchanged through the swap; smoke-asserted on every gated beat.
- **FIRST-RUN CHOICE OVERLAY (Kev ruling 2026-07-21; revised same day — the
  briefly-restored in-drill Skip button is OUT again, so the playtest
  SKIP-deletion stands for the drill itself).** BEGIN on a profile with
  `SaveManager.tutorial_done` unset raises a one-question modal over the
  darkened splash (`main_menu._show_first_run_prompt`: "This is your first
  time playing - want to run the tutorial?") — unmissable, no menu
  discovery. **RUN TUTORIAL** enters the drill with
  `GameState.tutorial_continue_to_play` set, so `TutorialController._finish`
  exits seamlessly into the squad picker; **SKIP TUTORIAL sets the SAME
  `tutorial_done` flag** (one flag, two paths in) and heads straight into
  the squad picker without ever entering the drill. Manual replays (splash
  TUTORIAL button / Help → REPLAY TUTORIAL) return to the menu as before and
  never reset the flag. Deleting the `user://` save re-triggers first-run
  behavior (the intended reset path). Mid-drill abandonment remains via the
  header back button (return-to-menu → `reset_run()`, which clears
  `tutorial_mode` and the continue flag — `tutorial_done` stays unset, so
  the next BEGIN asks again).
- **Coachmark placement (playtest item 9):** the coach stays HIDDEN until it
  is placed (`SpotlightLayer.spotlight` — the placement await used to render
  one frame at the previous position, the "blip"), and a step whose target
  rects haven't laid out yet waits (bounded) before spotlighting
  (`_layout_step` retry). Both fixes are generic — every step and the primer
  coachmarks inherit them.
- **Stall-proofing (the drill must be unable to dead-end):** the kill needs
  NO resource beyond the dice, and with no setup effects the totals are
  ORDER-INVARIANT — any resequence lands the identical 35 → 18 → dead line;
  a Nudge at 0 PP is refused (the pick never arms) and a nudged 14 stays
  inside Rail Strike's 11-15 band. Audit-pinned (5 kill-math regressions
  incl. the reversed-order arms). The old items_free crutch is gone with the
  item beat.
- **Coach panel sizes to its text (Prompt-6):** the coachmark panel derives
  its width from measured text bounds (the label's own resolved m5x7 font)
  plus the named paddings — no fixed full-screen width. Copy longer than one
  line wraps regardless, so it contributes its BALANCED width (unwrapped
  width split over the fewest lines, plus word-boundary slack) — short cards
  (WELCOME / DRILL COMPLETE) shrink to fit and center, long copy wraps into
  even lines. **Height shrink-wraps too (2026-07-21 fix):** the card is
  measured visible-but-transparent during placement — a HIDDEN Container
  never re-sorts its children, so the old `visible = false` blip fix made
  the autowrap label report a stale line count at its previous width and
  every card carried dead space below its text (the WELCOME card measured
  at ~zero width was worst). Measured height ceils to a whole design px; no
  artificial minimum — padding + one text line + the hint line is already
  the natural floor. Applies to every coach placement (tutorial AND primers
  — shared SpotlightLayer); positions round to whole px; the bottom anchor
  clears `PixelUI.safe_bottom`.
- **Dice-settle rig:** the scripted values are handed to the tray BEFORE the
  physics roll (`dice_tray_3d.set_rigged_results`, consumed one-shot in
  `_resolve_landed_die_face`), so the settle presentation rotates the RIGGED
  face up — the old post-settle repaint (a visible wrong-number snap) is
  deleted. Headless keeps the dict-level rig.
- **Primer showcase — ONE primer fires in the drill (Kev ruling 2026-07-21,
  supersedes full tutorial suppression):** the primer manager now exists in
  tutorial battles and `keyword_primer.gd` caps the drill at exactly ONE
  displayed primer (`TUTORIAL_SHOWCASE_CAP`); it is marked seen as normal
  ("don't have to redo that one"), everything past the cap stays suppressed
  and unmarked and fires in the first real battle (smoke-asserted). The
  natural sighting is CLEANSE: Splice Medic's turn-2 Infusion (10 heal,
  cleanse) is the drill's only non-exempt icon — `primer_cleanse` is new
  (icon_first_seen/cleanse, roll-sighted only; cleanse emits no feedback
  event) and fires in real play too. `battle_scene` emits the `rolled`
  tutorial event only AFTER the primer drain, so the showcase modal and the
  tutorial coach never overlap. The showcase respects the ability-primers
  opt-out and headless suppression.
- Pinned by `tutorial_smoke_test.gd`: THREE scenarios (happy path with exact
  rig math + spotlight-retarget assertions on every gated beat + the
  no-leech sweep + the cleanse-showcase display/seen assertions, the
  stall-proof resequence/double-Nudge path, and the first-run choice — SKIP
  sets the flag and lands on the squad picker, RUN TUTORIAL enters the drill
  and finishing continues to the squad picker). Tutorial capture:
  `--capture-tutorial
  [--capture-rolled | --capture-tutorial-step=N |
  --capture-tutorial-select=<unit>]` (windowed; the select flag drives stage
  2 of a two-stage assign beat).

**Pip / scope-marker icons** (`assets/ui/pips/`, `PixelUI.PIP_ICON_BY_KEY`, `EffectPip`): scope markers sit after the value — `all` = the AoE cardinal-arrow burst (Batch 5: re-cut from the 8-arrow starburst that read like freeze), `self` = circled figure, `lowest` = the new **target_lowest** reticle (replaces the old "↓" text; heal-lowest / shield-lowest fold into a `lowest` scope). Taunt / leech / summon icons were also re-cut from the Batch-5 sheets.

> **Scope-marker rule (Kev 2026-07-13):** a scope marker describes the
> **ability's** targeting, not each individual effect's. It appears **at most
> once per scope, per pip.** If every effect on an ability shares a scope, that
> marker is emitted once; if effects genuinely differ in scope, each distinct
> scope is emitted once — never the same marker twice. This generalizes the
> older "no ability uses the `all` sign twice" invariant to every scope (`self`,
> `all`, `lowest`, and any future one). The marker sits on the **LAST** effect
> carrying that scope, so a wholly single-scope ability renders its one marker at
> the **END** of the row, not wedged between effects — ECM Hiss reads
> "`🛡5 🎲+1 ⊙`", not "`🛡5 ⊙ 🎲+1`". Enforced at the single producer
> (`EffectPip.dedupe_scope_markers`, applied by `effects_from_ability_raw` /
> `effects_from_passive`), so every surface — readout, die-docked tag, inspect,
> first-sight primer — is de-duped once. (The ECM Hiss "`⊙ … ⊙`" bug: 5 shield
> (self) + +1 roll (self) had stamped two self markers.)

**View Battlefield** (between-battle choices): `battle_scene` captures the final combat state at victory into transient `GameState.battle_review_state` (skipped headless/auto). Reward, Intercept, and evolution/directive choices show `VIEW BATTLEFIELD` when that state exists; it re-enters the real battle scene read-only, then returns to the originating choice. Reward/Intercept offers, selection, recipient/swap choice, and scroll state are retained in the transient picker session; no reward rolls again and no event transaction can commit twice.
Chip doctrine: card chips are Burn / **Shield** / Mark / ±Roll / Firewall / Taunt (cap 3, +N overflow badge). The Shield chip was RESTORED per Kev 2026-07-06 (DECISIONS_RESOLVED #16, reversing the pkg8.1 cut): active shield total, both sides, live on grant/break/expiry, dropping at the per-side phase tick (rule 5). Cloak = ghosted portrait · Freeze/Petrify = die crust (ice cyan / stone gray) · Jam = **die numeral shows the CAPPED value** (Build G item 2 — the reveal feeds the jam cap through `_display_face_for_entry`, mirroring `get_effective_roll`; regression `jam_display_test.gd`) + die tint + "JAM ≤10" marker · **Firewall = portrait-corner FW badge** (Build G item 11, ruled — portrait-tier state marker on `warded`, both sides, cleared on break/expiry; the chip alone kept losing the 3-chip priority contest into the +N overflow; regression `firewall_display_test.gd`) plus its chip when the row has room · Rewrite/Hijack = pending die marker + readout entry · Spike = readout pip only. Result die face renders bright with a light outline, non-result faces dimmed ~40%. A **final die face of 20** = gold wash + shake + stinger + ability-name slam — however the die reached 20 (rolled, Nudged, Set, buffed); there is **no separate "natural 20"** (per Kev NK-02, the raw-vs-shown-face concept was removed game-wide — every 20-triggered effect keys only on the die's final effective face). Keyword feedback table: `offline-bundle/ANIMATION.md`.

## Visual identity

Deep navy bg; pixel art; `m5x7` font; hard edges, no gradients. Meaning-based color (current, post terminal-UI pass): **cyan/teal = player + primary actions** (teal primary buttons, corner brackets) · **red/rust = enemy/damage** · **green = HP bars and heals ONLY** · **amber = protocol pips, risk/confirm actions, unlock accents** · **gold = commit/reward moments**. `PixelUI` (`scripts/ui/pixel_ui.gd`) is the single source of truth for visual constants; `theme_overload.tres` mirrors it.

**Capitalization law (Polish Build A, ruled by Kev 2026-07-14):**
**ALL CAPS** = major alerts, page headings, buttons, small metadata labels
("ROLL: 1 - 4"), unit callsigns on battle cards, keyword names as
chips/headers (the primer "BURN: ..." label form). **Title Case** = ability
names and other proper nouns wherever they appear. **Sentence case** = ability
body text, lore, help copy, battle-log narration — and keyword mentions inline
are ALWAYS lowercase ("applies burn", never "applies BURN" or "applies Burn").
Hint-tier text is Sentence case game-wide ("Tap to continue >", "Tap anywhere
to close"). Intel-popup titles are page headings (ALL CAPS). Protocol-action
names (Nudge / Reroll / Set) and the resource word "Protocol" stay Title Case
as proper nouns. Gate: `scripts/checks/caps_law.py` (in `verify_gate.py`)
enforces the mechanical subset — data-JSON body text (no ALL-CAPS or
Title-Case keyword inline; not all-caps bodies), data-JSON name fields (no
all-upper / all-lower), `.tscn` Button `text` ALL CAPS, and no literal
`"..."` `.to_upper()` in scripts. Tier judgments on `.gd`-authored label
strings are EYES-ONLY. Prefer authoring the final casing; `.to_upper()` is for
genuinely dynamic values (names from data) plus the ONE central transform in
`style_primary_button`.

**Six-component law (Polish Build A — the border-noise fix):** every panel
FRAME is exactly one of six components, built ONLY by
`PixelUI.component_style` / `style_component` (mirrored as theme type
variations `CardNormal` / `CardSelected` / `CardEnemy` / `CardReward` /
`ModalPanel` / `CardMajorEvent` in `theme_overload.tres`):
1. **normal_card** — quiet frame + filled header strip (`hero_tint` variant for
   player-side surfaces).
2. **selected_card** — strong cyan border: the ONLY routine use of strong cyan.
   Battle-card selection is CYAN now (`SELECT_LINE = DT_CYAN` — the old gold
   selection was the biggest strong-gold leak).
3. **enemy_card** — rust chrome (meaning-first color law).
4. **reward_card** — amber accent; rarity borders ride the accent param.
5. **modal** — INSPECT chrome over a dim scrim (help menu, inspect popup,
   loadout chooser, SET-die popup, round-complete popup, coach/primer card,
   directive picker; the legacy sci-fi ninepatch help overlays migrated here).
6. **major_event** — the ceremonial tier (relics, evolutions, bosses): strong
   gold here and ONLY here (evolution choice cards wear it now).
ONE frame width for all six (4 design px) — rank is border COLOR, never width
(width flips would move content margins and make selection jump layouts).
Secondary grouping = spacing + filled plates (INVARIANTS #7), never extra
frames (battle log and home detail bar dropped their stroked outlines; the
route-fork banner and standard route card dropped resting strong cyan; the
flagged route card wears enemy chrome). Gate:
`scripts/checks/component_contract.py` (in `verify_gate.py`) — no `.tscn`
StyleBox, no `StyleBoxFlat/Texture.new()` outside `pixel_ui.gd`, no strong
accent tokens (`DT_CYAN`, `DT_CYAN_BRIGHT`, `GOLD_ACCENT`) or Color literals
(except `Color.TRANSPARENT`) in panel-factory calls outside `pixel_ui.gd`.
WHICH of the six a surface picks is eyes-tier (the component usage map).
Known none-of-the-six (reported, not seventh-ed): the transmission windows
(`style_transmission_panel` — intercept / route fork / run-end), the dice-tray
combat-zone frame, footer/header bars, and sub-components (chips, badges,
pips, HP tracks, sliders — they inherit a card's accent). The dead legacy
protocol-footer LED display (texture + lights, built then always hidden) was
DELETED from battle_scene.

**Reward presentation (Polish Build B, Kev ruling — SUPERSEDES the old
perfect-square reward card):** ordinary rewards are WIDE HORIZONTAL ROWS on
the Reward component — large item art LEFT (128 design px box), name +
rarity/type metadata + effect pips + description RIGHT with reading room. The
full row width is the tap target (min height comfortably over the 96px floor);
tapping SELECTS (Selected component + cyan brackets), the bottom CONFIRM
commits, CONFIRM is progress-locked until a selection exists. RELIC offers
stay ceremonial: two large Major-event (gold) cards — deliberately a tier
above ordinary rows, split builders on purpose
(`reward_screen._create_reward_row` / `_create_relic_card`). **Integer icon
law:** item art renders ONLY at whole-integer multiples of native
(`PixelUI.make_integer_icon`; 128 native → 1x rows / 2x relic cards); low-res
art (≤48 native — only `gravityWell` at 32 is live) renders at EXACTLY 4x on
a framed Reward-chrome emblem plate. The 5 boss-relic icons were normalized
from oddball AI-gen sizes (338–481) to 128 nearest-neighbor (2026-07-14). The
other 24 32×32 files in `assets/icons/items/` are UNREFERENCED legacy content
(art-regeneration backlog). Gate: `scripts/debug/reward_model_test.gd` (in
`verify_gate.py`) — selection model, row geometry, integer scale, containment
at inset budgets (0,0) and (132,56).

**Squad/operation selection (Polish Build B):** the composition is FROZEN —
operation carousel, squad row, hero blurb panel, DEPLOY; enrichment adds ZERO
new framed panels (gate: `scripts/debug/panel_count_test.gd`, pinned at 11
framed panels; an empty-feeling screen is fixed with spacing, never a frame).
Added within existing modules: one metadata clearance line in the carousel
card ("CLEARED" / "BEST: BATTLE N" / "NO CLEARANCE"; blank while locked) and
the operation-lore SLOT under the carousel (unframed one-sentence flavor from
the `lore` field in `battle-modes.json` via `OperationData.lore`; empty until
Build C authors copy, and an empty slot renders nothing). The mechanical
threat summary moved to Build C (authored operation data).

**Body-copy tier (Polish Build A):** long-form prose reads at
`PixelUI.FONT_BODY_MIN` (42 design → 64 rendered, one ladder step above
`FONT_INFO_MIN`) with the game's first line-spacing token
(`BODY_LINE_SPACING` = 10, applied via `PixelUI.style_body_label`). Migrated:
help bullets + keyword definitions, inspect free-form description, evolution
path-focus / directive descs, intercept + route-fork blurbs, home kit blurb
(raw-px screens author `scale_font_size(FONT_BODY_MIN)`). Titles, buttons,
names, numbers, and table-ish rows (inspect ability/gear rows, bestiary
stats, help syntax sub-lines, reward/item cards pending Prompt B) keep their
sizes — deliberately, to avoid name-under-description rank inversions.

**Header chevron buttons (Task 4 finding, 2026-07-14):** the two dev-mode
header buttons are NOT speed controls — Debug (single chevron) = auto-complete
the current turn, Debug2 (double chevron) = auto-complete the battle
(`battle_scene._on_auto_turn_button_pressed` / `_on_auto_battle_button_pressed`;
hidden unless SETTINGS > DEV developer mode). Label proposal pending Kev's
ruling: "AUTO TURN" / "AUTO BATTLE" (not "1X"/"2X" — they are not speeds).

## Run report + feedback channel (2026-07-30, stranger-readiness)

**Run report parity:** victory and defeat share ONE run-end screen
(`run_end_screen.gd`) and ONE compact THIS RUN block (`_run_report_text` — the
old defeat structure is the template): battle progress, `Duration | Turns`,
inventory counts, `Fallen: <full hero names | none>`. Per-run sources are
in-memory `GameState` accumulators only (`run_hero_deaths` — dead-at-battle-end
union, defeat unions the whole squad; `run_total_turns` — `_round_number`
recorded at both battle-finish sites; `run_start_unix` — wall clock), cleared in
`start_run`/`reset_run`, never persisted. SERVICE RECORD (lifetime save stats)
is unchanged and ends with the sentence-case pointer "Thoughts? FEEDBACK on the
main menu." Captures: `run_end_capture.gd` seeds representative rows.

## Audio (2026-07-11 music pass)

**SFX:** `AudioManager` autoload — runtime `SFX` bus, pooled players, pitch/volume
randomization, `set_suppressed` for harnesses. **Music:** `MusicManager` autoload
(`scripts/autoloads/MusicManager.gd`) — runtime `Music` bus + one lowpass filter,
two-player crossfade pair, tracks in `assets/audio/music/sci_fi_loop_N.ogg`
(OGG, `loop=true` in import; only the 6 mapped files ship).

- **Track lifecycle (the encounter identity rule):** the faction track starts once at
  encounter start and plays continuously and uninterrupted until encounter end — no
  stop/restart/crossfade between battles. Track changes at exactly THREE moments:
  boot→title (`sci_fi_loop_1`), encounter start (`_launch_run` →
  `play_for_faction`), encounter end (`run_end_screen._ready` → loop 1). Same-key
  `play_track` is a strict no-op (title→deploy never restarts). Any other
  `play_track`/`play_for_faction` caller is a bug. Tutorial stays on loop 1.
- **Faction map** (`FACTION_TRACKS`; hive=4 spec-fixed, rest are op-order
  placeholders pending an ear pass): facility=2, hive=4, veil=3, voidCirclet=5,
  stellarMenagerie=6.
- **Intensity states** (`set_combat(bool)`, the ONLY thing battle screens touch):
  combat = full user volume / 20000 Hz / pitch 1.06 over 0.5s; non-combat = −6 dB /
  1400 Hz / 1.0 over 1.0s; SINE IN_OUT, playback position never jumps. Wired:
  `battle_scene._ready` true; the four `battle_over = true` sites + `_exit_tree`
  false. Pitch stays ≤1.06 (Godot resamples — higher goes cartoon).
- **Sequenced combat entry (Batch 5):** the encounter-start crossfade and the battle
  scene's `set_combat(true)` fire back-to-back, so they must NOT overlap or the still-
  dominant OUTGOING track gets the pitch/volume boost (the "record drag"). Three rules:
  (1) `play_for_faction` brings the incoming faction track in ALREADY at combat pitch;
  (2) `_set_pitch` touches only the ACTIVE (incoming) player, never the outgoing one;
  (3) `set_combat(true)` DEFERS its state ramp (via `_fade_tween.finished`) while a
  crossfade is in flight — the old track fades out first, then the lone faction track
  rises to battle state. Battles 2–10 (no crossfade) still snap immediately.
- **Volume model:** default music level is **30%** (`DEFAULT_MUSIC_VOLUME`; a saved
  `music_volume` in settings.cfg still wins). Music bus = `_user_music_db + _state_db + _duck_db` — every
  operation is an offset from the user's configured level; slider moves apply
  immediately mid-anything. Nat-20 duck (`duck_for_stinger`, hooked in
  `battle_feedback._celebrate_overload`): −8 dB, 0.04s attack / 0.30s hold / 0.45s
  release, restores to the state target.
- **Settings** (`user://settings.cfg` `[audio]`): `muted` + `sfx_volume`
  (AudioManager), `music_enabled` + `music_volume` (MusicManager). UI in help-menu
  SETTINGS: Music toggle, Music/SFX volume sliders (`_add_slider_row`), Mute-all.
- **Headless:** MusicManager runs its full state machine but never starts playback
  (dummy driver; a live OGG playback at exit leaks past ObjectDB cleanup).
  Regression: `scripts/debug/music_smoke_test.gd` (in `verify_gate.py`).

**Splash logo:** the main menu title is `scenes/ui/TitleLogo.tscn` — three stacked layers (`assets/ui/logo_base/core/protocol.png`: dimmed base + two additive-blend glow layers), Tween-driven boot-in → desynced idle pulses → 5–9s glitch tear → flare-out on BEGIN (`scripts/ui/title_logo.gd`; timings are `@export` tunables). BEGIN/TUTORIAL stay disabled until `boot_finished`. Sequence via the `boot_finished`/`flare_finished` signals, not by awaiting the methods — a coroutine await that dies mid-flight (quit at menu) leaks a GDScriptFunctionState cycle. The old static `logo_scifi_overload_protocol.png` is no longer referenced.

## Assets — portraits (2026-07-07 wiring pass)

**Hero portraits:** base art `assets/portraits/<hero_id>.png` (`DataManager.HERO_PORTRAIT_BY_ID`). **Evolved art convention: `assets/portraits/<hero_id>_<evo_id>.png`**, where `evo_id` is the evolution entry's `id` field in `heroes.data.json` — the lowercased callsign, schema-enforced (pyro, arc, blade, ravager, bulwark, sentinel, glacier, trench, medic, synth, overclocked, phantom, shadow, wraith, noise, nullwire). `DataManager.get_evolution_portrait()` resolves it; a missing file silently falls back to the base portrait (never errors, never blanks). The swap rides `GameState.get_run_unit_data()`, so every run-unit surface (battle cards, equip labels, sim) inherits it; the evolution screen previews each branch's own portrait. All 24 files (8 base overwrites + 16 evolutions) installed 2026-07-07. Both art styles pass through the crop-to-content contract (`_crop_to_content`, cutout vs full-bleed tag). **Portrait region (single source of truth, fix/portrait-region 2026-07-12):** the hero portrait window is **`PixelUI.HERO_PORTRAIT_REGION` = 328 × 380, aspect 0.863** — measured live from the battle card (stable pre/post-roll). Every screen that displays a hero portrait uses this aspect; a screen needing a different physical size scales this aspect — it does not define its own. Do not define a portrait window anywhere else, and do not hardcode a second aspect. Portraits are authored to this window. A *taller* display frame cover-fits by height and trims the sides, which is harmless. A *shorter* frame trims the bottom and destroys the framing — that was the 320×486 bug: squad select and the battle card showed different windows onto the same art, and every framing pass authored against the wrong one. Four divergent windows ("liars") were fixed at once: squad tiles (320×486), the encounter boss thumb (same stale aspect), the evolution branch portraits (private 170×210 + centered cover), and the run-end unlock row (144×144 square). All portrait surfaces route through `PixelUI.cover_fit_portrait` (top-anchored for cutout/matted art, `PORTRAIT_TOP_PAD` scales with the frame so small tiles frame identically to the battle card, not just similarly). Current art state: **pristine 592×880 originals** (the 2026-07-12 destructive normalization crops were reverted — a standalone restore commit exists on main); hero portraits load WHOLE via `DataManager._finalize_hero_portrait` (no runtime silhouette-crop — that runtime crop was how earlier framing passes were silently undone). Hand-declared framing anchors live in `assets/portraits/portrait_anchors.json` (head_top/chin per portrait, consumed by `scripts/assets/portrait_frame_crop.py`) for the pending anchor-based crop pass — anchors are authored data; **never derive head positions from pixels.**

**Hero display zoom (Kev 2026-07-12):** heroes render through `PixelUI.HERO_PORTRAIT_ZOOM = 1.2` (display-time only; PNGs stay pristine) so hero helmets match the enemy-card framing — **enemies are the framing reference and are never zoomed.** Per-portrait hooks: `HERO_PORTRAIT_ZOOM_OVERRIDES` (empty by design) and `HERO_PORTRAIT_ANCHOR_Y_OVERRIDES` (fraction of frame height, positive = art up) — the breaker family carries anchor overrides (0.105/0.166/0.237, derived from the hand-declared `head_top` anchors) because its source art seats the body lower to fit tall antennas/crown. **Design ruling (Kev): it is acceptable for antennas, crowns, and silhouette flourishes to be cropped out of the portrait frame. The head is what must be framed consistently, not the headgear. Never adjust the framing to preserve an antenna.**

**Enemy portraits:** `assets/portraits/enemies/` via `ENEMY_PORTRAIT_BY_NAME` (bare filenames only — no `res://` long forms), fallback `_slugify(display_name).png`. As of 2026-07-07 all 38 unit defs have explicit map entries and every one resolves. Legacy-era files renamed to current unit names (git history preserves the lineage): rift_macaque→pumice_macaque, eclipse_panther→geode_panther, ridge_drake→magma_drake, eclipse_raptor→pyroclast_raptor, thunder_ape→basalt_ape, void_reaver→mantle_tyrant, sparksprite→glitch_sprite, levyn_acolyte→init_acolyte, chronicle_scribe→checksum_scribe, geas_binder→axiom_binder, glimmer_double→forked_double, arc_titan_channeler→daemon_channeler, circlet_hierophant→root_hierophant, whitenoise_skimmer→static_skimmer, void_hound→obsidian_hound.

**Hound art gap CLOSED (2026-07-07 Accretion drop):** Slag Hound has its own `slag_hound.png`; Obsidian Hound keeps `obsidian_hound.png`. No shared enemy art files remain.

**Quarantine:** unreferenced files live in `assets/portraits/enemies/unused/` (cyber_phoenix, harmonic_hexnode, veil_spare) — kept, not deleted.

---

## Verify commands (supersedes docs/archive/BASELINE.md)

Godot binary: `C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe`

```
npm run validate-data                                          # JSON schema gate
<godot> --headless <proj> scenes/debug/AbilityAuditRunner.tscn # ability audit (214+ regressions, expect 0 failed)
<godot> --headless <proj> -s scripts/debug/flow_smoke_test.gd  # full scene-flow smoke
<godot> --headless <proj> -s scripts/debug/tutorial_smoke_test.gd
<godot> --headless <proj> -s scripts/debug/primer_smoke_test.gd    # keyword primers
<godot> --headless <proj> -s scripts/debug/run_smoke_test.gd   # one full headless run
<godot> <proj> -- --debug-battle                                # windowed battle + screenshot
python scripts/sim/ci_smoke.py                                 # balance diff vs baseline.json
python scripts/sim/sweep.py --name X --knob K --values ...     # balance workbench (measurement only; scripts/sim/README.md)
```
Gotcha: `--check-only -s file.gd` false-fails on autoload identifiers; compile-check by `load()` from a headless SceneTree or just run the audit.

## Balance doctrine — portfolio balance (Kev ruling, Cycle 2, 2026-07-17)

**Content is balanced on its MEAN lift across operations, not per-fight.
Situational spikes are desirable** — a hero who is REALLY good on one operation
and weak on another is a specialist, and specialists are why squad/draft
choices matter. The constraint is the portfolio average; **the variance is the
feature.** Shapes and verdicts: high mean everywhere → overpowered (nerf
candidate) · low mean everywhere → dead (buff candidate) · fine mean, flat
profile → balanced-but-boring (acceptable, note it) · **fine mean, high
variance → THE TARGET SHAPE (protect it)**. Rarity prices the bands: higher
rarity legitimately buys a higher mean. The operation reorder is PARKED (current
order kept; comprehension is a demo-tester question; the parked data-edit exists
if they hit a wall) — bands are set for the current order.

**Audit-count provenance:** the ability-audit floor moved 228 → **234** in Build
G Lane 2 (`0de9ab3`, taunt single-target G-4) — six taunt-targeting regressions
(taunt-requires-enemy, taunter/taunted/free-target scenarios). NOT from the
Cycle-1 Hive bake, which reclassified nothing (heavies floored at 90 precisely
to keep classification fixed; audit 234/0 before and after the bake).

## Sim baseline (current)

**Baseline v2 — Cycle 0 re-baseline (2026-07-17, LOCKED; Synod attribution
resolved Cycle 1).** Policy **l1**, **1000 runs per operation** (random squads,
fixed op, matched seed sets across arms), post-Phase-0 harness fixes. Per-op
clear: **facility 0.547 · hive 0.035→0.293 (Cycle-1 Hive retune, below) · veil
0.148 · voidCirclet 0.274 · stellarMenagerie 0.120**. Full dashboard:
`docs/sweeps/2026-07-17_cycle0_dashboard.md` (the reusable per-cycle format —
`scripts/sim/dashboard_cycle0.py`). `scripts/sim/baseline.json` (the CI pin) was
re-pinned post-Cycle-1-bake (BASELINE-APPROVED-BY-KEV — Kev's Stage-2 approval
2026-07-17 is the ceremony sign-off; the pre-Cycle-1 pin was the dead v1).

**Cycle 1 — Hive retune (2026-07-17, BAKED, Kev-approved Stage 2).** Scalar was
the instrument, literal data is the law: `enemy_hp_scalar@hive=0.75` dialed the
band, then LITERAL HP landed in `enemies.data.json` and the scalar ships inert
at 1.0. Skitterling 40→30 · Bloodmite 35→26 · Spine Stalker 65→49 ·
Broodwarden 115→**90** (⚑ floored: `DataManager.HEAVY_HP_MIN=90` classifies
roles from data HP — dropping below 90 would EMPTY hive's heavy pool and break
slot comps) · Caustic Spewer 90→**90** (⚑ uncut, same floor) · Hive Matriarch
180→135. Attack values unchanged (HP is ~1.7× the more efficient dial — hive's
problem was durability/exposure, not incoming damage). Comp: hive b4
`heavyOrElites` → `heavy, fodder` in `battle-modes.json`, killing the
double-Spine-Stalker degeneracy (hive's elite pool has ONE member, so "two
elites" always duplicated him — 37% defeat rate at b4). **Result: hive L1
0.035 → 0.293** (band 25–40 ✓), b3-4 defeat share 29%→12% (facility-normal),
Matriarch still a real wall (79% of defeats). **L2 51.5% — the L1/L2 gap
widened +7.1→+22.2pp** (winnable AND skill-expressive). **Equivalence proof:**
the baked build reproduced the approved arm **byte-identically on all 1000
matched seeds** (`hive_equivalence` vs `hive_bakepreview`), win rate exactly
0.293. Ability audit 234/0 unchanged. Other operations' data and baselines
untouched. Stage-1 report: `docs/sweeps/2026-07-17_cycle1_stage1_hive.md`.

- **v1 baselines are DEAD as comparison targets** (they predate taunt-G-4,
  MAX_CONSUMABLES 3→4, the NK-17 sweeps, the unlock system, every polish build, and
  the Cycle-0 harness fix). Historical record — v1 (locked, pre-polish): overall
  **0.283** / facility **0.592** / hive **0.085** / veil **0.169** / nullSynod
  (`voidCirclet`) **0.404** / accretion (`stellarMenagerie`) **0.083**. (Doc
  correction: the on-disk `baseline.json` is the post-Batch-1 re-pin — overall
  0.3133 / facility 0.6338 — not the 2026-07-06 crit-banking figures this section
  previously quoted. Older checkpoints: crit-banking 0.2867, repeat-freeze 0.2533,
  pre-repeat 0.53, "flat sim ~1.7%".)
- **Decision-density gap (L1↔L2) is a first-class metric from Cycle 0 on** — the
  boredom dashboard, reported every cycle. Cycle-0 gaps (matched seeds, n=1000/op):
  facility **+25.1pp** · hive **+7.1** · veil **+8.5** · voidCirclet **+29.5** ·
  stellarMenagerie **+10.3**. Small gap = greedy play is near-optimal (obvious turns).
- **Bucket-0 arm (non-baseline):** the new-player pool BEATS full pools at L1 on
  every op (+4.6 to +17.0pp) — L1's rarity-greedy drafting picks late-bucket
  situational content over bucket-0 staples; pool dilution is real at greedy skill.
  Harness arm `--pool-buckets N`; the fully-unlocked baseline pin is unchanged.
- **Proposed target bands (PROPOSALS for Kev's ruling, not law):** facility
  0.55–0.65; each subsequent operation ~10 points below the previous; final
  operation 0.15–0.25. Cycle 0 ran under the CURRENT op order (facility, hive,
  veil, voidCirclet, stellarMenagerie) — the pending reorder ruling has not landed.
- **Standing caveat:** the sim measures winnability, not fun; cognitive-load and
  turn-feel problems are invisible to every policy tier (demo-tester territory).
  Headline numbers describe full-unlock (veteran) pools except the bucket-0 arm.

**Cycle 3 — The Reprice (2026-07-19, BAKED, Kev-approved Stage 2).** Approved
set #1–4, sweep-dialed and baked as literals (Cycle-1 protocol): **Overcharge**
130%→**110%** (lift +32.4→+15.3pp) · **Iron Curtain** 75%→**90%** (+31.0→+15.1)
· **Predator Lens** → `rollBonusNat20Protocol` {+3 rolls, +1 Protocol on a 20}
(+10.6pp, +4.3 over Neural Splice — the rarity mispricing resolved by rider) ·
**Ghost flat tax G2** Probe 7→5 / Breach 9→7 / Blade 13→12 / Exec 16→14 (mean
+7.1→**+5.2**, hive/synod spikes preserved, spread 16.0 — shape kept per
doctrine). **Equivalence proof: 5000/5000 runs byte-identical** to the approved
verification arm across all five ops. Audit **234/0, zero delta**. NK-17 text
in the same commits. **Baseline v3 (per-op, approved-set/equiv arms, n=1000):
facility 0.538 · hive 0.305 · veil 0.143 · voidCirclet 0.292 · stellarMenagerie
0.113.** CI pin re-accepted post-bake (ceremony = Kev's Stage-2 approval).
**DEFERRED with evidence** (docs/sweeps/2026-07-18_cycle3_stage2_table.md):
Shield (9 sweep points flat incl. outside-lever probes; **L2 −8.1 — dead at
both tiers, structural**), Medic (heal-value ceiling: doubling heals = +0.6pp
mean; L1 triage caps healing), Combat (Candidate-B carve measured dead: mean
UP +6.4, spread COLLAPSED 7.1 — execute is op-agnostic under focus-fire; pure
trim −12 flat = −0.6pp and flat), Pulse (chain-fizzle hypothesis FALSE —
Facility has the highest chain rate). PROTECTED verdicts: Vengeance Protocol
(L2 +1.0), Band Compressor (L1 −2.2 → L2 +2.8, skill-gated), avalanche/
breaker/engineer untouched per ruling. **Dead-dozen Cycle-4 worklist:**
curatedCache the lone both-tier corpse; salvageDirective the clearest
skill-gate (+2.6 L2); rest neutral-at-L2 (n=500, SE 3.1pp).

**Cycle 4 — Era refresh, Veil, Mantle Tyrant, rarity audit (2026-07-19, BAKED,
Kev-approved R4 checkpoint).** Full report:
`docs/sweeps/2026-07-19_cycle4_report.md`. **Veil** to the ruled 30–40 band via
HP literals at 0.85 (levers tied in diagnosis; HP picked on cascade tiebreak;
Overseer owns only 30% of deaths — not boss-shaped): Shardmite 34 · Prism
Charger 32 · Aegis Anchor 58 · Nullblade 60 · Synapse Herald 65 · Stormweaver
**90⚑ floored** (HEAVY_HP_MIN) · Resonance Warden 100 · CONCLAVE OVERSEER 153
— **14.3% → 33.3%**, equivalence 1000/1000. **MANTLE TYRANT boss rule:
ACCRETION fires every 2ND round** (value 6 kept; cadence beat value per swept
point; `MANTLE_SHIELD_CADENCE := 2`; briefing copy + two audit regressions
updated, 234/0): Accretion **11.3% → 16.3%**, clear-of-reached 13% → 19% —
still the game's hardest wall (Hierophant 34%, Scrapmaster 62%). Metric
ruling-note: the death-share target is arithmetically share-bound on
Accretion's short road; clear-of-reached is the comparable wall metric.
**Baseline v4 (changed ops only): veil 0.333 · stellarMenagerie 0.163**;
facility/hive/voidCirclet v3 numbers stand — the combined final arm showed
EXACT +0.0pp on all three (op-local changes are byte-invisible elsewhere).
**Era refresh:** fresh L2 gaps (facility +25.5 · hive +18.6 · veil +6.7 ·
synod +23.3 · accretion +9.0) and bucket-0 deltas (+6.2..+14.4 — attenuated
post-reprice, still positive everywhere). **Rarity audit (curatedCache stays
AS-IS per revised ruling):** tier medians rank correctly in every era/method —
mislabeling hypothesis rejected; R5 shortlist (demote priming_charge,
reverse_gimbal ⚑#11-pending, deep_zero_pin; no promotions; grounding_clip
cleared — observational selection bias again) awaits ruling; NO rarity
changes shipped. Veil b4 spike (26–28% of deaths) reported as a future
comp-shaped item. CI pin re-accepted post-bakes.

**R5 shortlist — CLOSED (Kev ruling, 2026-07-19).** deep_zero_pin rare →
**uncommon**: APPROVED and shipped (items.data.json + UNLOCK_BUCKETS.csv, pin
holds). Cascade verified: six rare consumables remain full-pool and the
bucket-0 floor pair (harmonic_injector, core_surge) is intact — the
zero-options guard cannot trip on rare-consumable grants; no hard-coded
rarity strings anywhere (display metadata is data-driven); curatedCache
unaffected (its filter is commons-only); pool-floor gate PASS. Seeded draw
test through the real `_pick_random_reward_by_rarity`: 0/500 rare draws
offer it, 69/500 uncommon draws do. Rarity is outside NK-17 grammar — no
effect-text change. **Era annotation:** content-arm lifts involving
deep_zero_pin measured before 2026-07-19 predate its draft-frequency change.
priming_charge: **HELD** (coupled to curatedCache's filter zone — revisit
with curatedCache's structural question). reverse_gimbal: **HELD**
(DECISIONS #11 pending on the same item). No other rarity changes.

**Build I — Kit surgery: Shield / Medic (+CLEANSE) / Combat (2026-07-19,
values RULED not swept).** Kits: Spike Guard Taunt Protocol "taunt, spike 3" ·
Enforce "6 shield, spike 3" (rider rides the SHIELDED target — engine rule:
spike+shTgt grants where the shield lands) · Splice Medic Diagnostic Pulse
"3 heal, 3 shield" · Infusion "10 heal, cleanse" · Strike Unit Target Lock
"mark" (0 dmg) · Suppression 6 · Rail 10. **CLEANSE (new instant keyword,
code CL):** removes the target's unit-level negatives — burn stacks, negative
roll-buff stacks (positives survive), jam, lure, mark; **die states excluded
by ruling** (a frozen die stays frozen — freeze-as-repeat can be a banked
choice); no-op casts legal; golden-tinted heal glyph pip (PIP color only —
amber-gold chrome reserve NOT implicated); sole carrier: Infusion.
**Overheal-to-shield: REJECTED (Kev) — never re-propose.** Overpenetration:
SHELVED; its return condition ("balanced-but-flat") HALF-fires — Combat
measured OVER-band and flat (+6.3 mean, spread 8.3). Engine fix exposed by
the 0-dmg band: mark historically applied only inside the damage pass —
mark-without-damage now mirrors burn-without-damage. Tutorial cascade: drone
13→10 HP; the audit's kill-math mirror rebuilt to the live Batch-5 rig (was
a stale pre-Batch-5 mirror). **Audit floor 234 → 236** (two cleanse
regressions). **Re-measure (3×5 + trio, n=1000, fresh controls): Shield
−8.3 mean (MISS, backward; Synod +7.7 spike intact, spread 31.5), Medic
−8.4 (MISS; cleanse ≈ worthless at L1's triage timing), Combat +6.3
(MISS; ruled trim moved 0.1pp — flat levers inert at L1, fifth
demonstration).** Cross-check PASS: hive 33.3% ≥ 25%; controls +0.6..+2.8pp
uniform upward drift (three adjusted heroes in the pool) — within paired
noise, baselines NOT updated (proposed: fold into next refresh). Trio arm
(shield,medic,combat): +18.3 Synod / +12.7 Accretion / −26.0 Hive / −23.7
Veil — a hyper-specialist composition. Base/evo inconsistency report (Kev
follow-up input): Medic evolutions LOSE cleanse entirely; Shield evolutions
lose the taunt-spike pairing; Bladecore's Target Paint keeps damage on mark
(upgrade, noted); Ravager has no mark band.

**Build J — Enemy status timing + bezel bars (2026-07-19/20, presentation
only).** **Item 1:** status chips land at their CAUSING beat. Combat state
still applies fully at resolve (untouched — proven by the state-hash tripwire
`scripts/debug/state_hash_tripwire.py`, byte-identical pre/post); the leak was
an earlier group's card refresh re-rendering ALL chips from live state.
Deferral: pre-resolve token snapshot → (chip, last-causing-group) plan in
BattleFeedback → snapshot-value substitution while suppressed → release at the
group's impact beat → unconditional clear at sequence end. Side-agnostic;
skip/auto path renders end-state immediately; cleanse's beat gates chip
REMOVAL. Presentation-order test `scripts/debug/status_timing_test.gd`
(headless, planner-level; fails on pre-Build-J code). **Known remaining leak
(flagged, out of Item-1 scope): die-crust visuals (`_sync_die_status_visuals`)
have the same early-application class — a future item.** **Item 2:** the
bottom gesture reserve renders PURE BLACK (`PixelUI.DT_BEZEL_BLACK #000000`,
device-bezel blend, intentionally outside the DT palette; painted globally by
PersistentHeader, inert at zero insets); the top inset stays header chrome BY
DESIGN. Conservative trims `SAFE_TOP_TRIM`/`SAFE_BOTTOM_TRIM` = 4 design px,
subtracted post-ceil via the pure `apply_inset_trims` — never negative, and
the Android bottom never below `BEZEL_BOTTOM_FLOOR` 48 (tests T12/T13; suite
T1–T13 green; desktop inert). Capture-harness fix: `--capture-insets` was
silently broken (the desktop resize refresh wiped simulated values — captures
showed zero-inset layouts); now pinned via `PixelUI.sim_insets_pinned`, and
`--capture-insets-raw` reproduces the pre-Build-J presentation for
comparisons. Pixel-verified at the Pixel-8 budget: strip (0,0,0), insets
132/56 → 128/52.

**Pure-mark targeting fix (2026-07-20).** Since Build I made Target Lock a
0-dmg mark band, the ability never entered manual targeting:
`battle_scene._get_manual_target_side` had no branch for `mark`, so the ability
auto-assigned and combat_manager's pure-mark path silently marked the
first-living-enemy fallback (invisible in single-enemy fights, player-silent in
multi-enemy ones). **Rule: every hostile flag combat_manager resolves through
`_hostile_single_target` on a hero ability must appear in the manual-targeting
disjunction.** `mark`, `jam`, and `rewrite` are now in it (jam/rewrite are
no-ops today — every authored hero jam/rewrite rides a damaging band — but the
resolution paths read `selected_target_id`, so a future 0-dmg jam/rewrite band
would have regressed identically); hijack/siphon are enemy-only and breach only
resolves inside the damage pass, so they take no branch. Mark-with-damage
already routed through the `dmg > 0` clause — this changes only the 0-damage
case, still ONE manual pick per ability (INVARIANTS #12). A firewall still
blocks (and is consumed by) the pure mark. Tutorial: Strike's turn-1 Target
Lock is now a real targeting step like the other two picks (forced-manual mode
already expected this; the step script's `targeting_started`/`assigned` gates
are unchanged). **Audit floor 236 → 241** (+3 targeting cases, +2 mark
regressions).

**Player-chosen cast order (2026-07-20, Model A: assignment order = firing
order).** Heroes no longer resolve in fixed squad order — the order the player
COMMITS assignments is the order heroes fire. No new UI surface: meaning was
added to the taps the player already makes.
- **Stamping:** every hero acquires an integer `cast_stamp` (on the hero state,
  like `selected_target_id`) during the targeting phase, monotonically
  increasing within the round. Auto-assigned heroes (no manual pick: self /
  all-target / no-legal-target / taunt-forced) stamp immediately when the phase
  begins, in squad order — a player who never interacts gets today's default.
  Manual-pick heroes stamp when their target tap lands (a single-legal-target
  auto-assign stamps at phase start like an auto).
- **Resequencing (the ONLY reorder mechanism):** re-tapping an assigned hero's
  card unassigns it — stamp cleared; manual abilities return to the pending
  queue and immediately re-open targeting (a retarget stays two taps), auto
  abilities and taunt-locked heroes move straight to the END of the order in
  one tap. Recommitting always appends a fresh stamp. Nudge/Set/Reroll re-run
  assignment (pre-existing behavior), so a die modification also recommits the
  hero at the end of the order.
- **Resolution:** at END TURN heroes fire in ascending stamp order
  (`combat_manager._hero_states_in_cast_order`); a living, rolled hero somehow
  unstamped (defensive case) appends in squad order and `push_warning`s — in
  normal play everyone is stamped. Stamps clear at round resolution.
  `_hero_states` itself STAYS in squad order — every non-resolution iteration
  (battle-start effects, income, XP, enemy SYSTEMATIC slot-order targeting)
  is unchanged. The old L2 `set_hero_order` array reorder is REPLACED by stamp
  writing (it used to leak the firing order into enemy targeting — a
  sim-vs-live divergence, fixed).
- **Enemy timing untouched:** all heroes fire, then enemies. Intra-hero only.
- **Kill-mid-sequence (documented existing rules, NOT new behavior):** if an
  earlier hero kills a later hero's target, `_find_target_by_id` skips dead
  states, so `_hostile_single_target` retargets the later hero to the FIRST
  LIVING non-cloaked enemy in slot order (taunt lure still overrides); with no
  living enemy the ability logs "finds no visible target - the attack fizzles."
  Friendly picks fall back per-effect (heal/shield → lowest-HP living ally).
  A hero killed mid-phase (enemy Spike) keeps its stamp but does not act
  (combat rule 4).
- **UI:** assigned hero cards wear a firing-rank badge (numeral on a filled
  plate, portrait top-LEFT corner — firewall badge owns top-right), sourced
  from the stamp rank, gone at resolution. The battle log records
  "Cast order: A -> B -> C" each round (logged by the engine's round log, so
  the live log panel shows it without scene code).
- **Sim:** L1 stamps squad order explicitly (control, behavior-identical).
  L2 gains an `order_mode` seam: "search" (default — its pre-existing order
  permutation search, unchanged), "setups" (setups-first heuristic: heroes
  whose selected ability applies mark/breach stamp first, ties squad order, no
  lookahead), "squad" (identity control for matched-seed A/B). Round telemetry
  carries `cast_order` (planned firing order, add-only field); batch.py passes
  `--order-mode` through. The state-hash tripwire digest was re-recorded for
  the add-only telemetry field (state trajectory verified unchanged, see
  commit).
- **Tutorial redesign around this mechanic is DEFERRED** (tracked in
  TASK_QUEUE) — the existing 23-step script passes unchanged.

**Taunt stale-arm note (Build G) — RESOLVED by Cycle 0:** the taunt-single-target
sim pass has now run; every formerly stale-baselined taunt arm is measured in
Baseline v2. Avalanche repricing remains the known open target; no ability numbers
move until that ruling.

## Out of scope (don't build)

Cross-run persistent **XP**; node map between battles; multiplayer; narrative; full audio mix. *(Cross-run **unlocks** are IN scope and shipped — hero ladder + operation chain above.)*

---

## DECISIONS (all 17 adjudicated — see docs/DECISIONS_RESOLVED.md; do not relitigate)

Every item below has been ruled by Kev (2026-07 decision review). Questions and
rulings live in `docs/DECISIONS_RESOLVED.md` under the same numbers. Items marked
*pending* are ruled but not yet implemented — **their ruling text must be
transcribed into DECISIONS_RESOLVED.md before implementation; never implement a
ruling from chat memory.**

1. **RESOLVED & IMPLEMENTED — Freeze = repeat** (full bank/thaw → lockout → repeat lineage under #1).
2. **RESOLVED & IMPLEMENTED — shield per-side expiry** (2026-07-07, zero data offenders). See combat rule 5.
3. **RESOLVED & IMPLEMENTED — independent instance timers (rfm/erb/burn).** See combat rule 10.
4. **RESOLVED & IMPLEMENTED — permanent-burn Detonate = one tick, not consumed.**
5. **RESOLVED & IMPLEMENTED — ASSEMBLY LINE cadence from first activation** (2026-07-07).
6. **RULED, pending** — INTERCEPT_CARDS numbers.
7. **RULED, pending** — route modifier numbers.
8. **RULED, pending** — boss cadence numbers.
9. **RULED, pending** — execute bonus.
10. **RESOLVED & IMPLEMENTED (Batch-1, 2026-07-11)** — chain jump ratio `chain_ratio` set 0.6→0.5 (baseline NOT re-pinned; full balance pass follows).
11. **RULED, pending** — Reverse Gimbal UX.
12. **RESOLVED & IMPLEMENTED — cloak hostile-only untargetability** (2026-07-07).
13. **RESOLVED & IMPLEMENTED — tutorial runs excluded from `runs_started`** (2026-07-07, grandfathered).
14. **RESOLVED & IMPLEMENTED — directive Marks single-target on AoE** (2026-07-07).
15. **RESOLVED & IMPLEMENTED — mid-run re-equip REJECTED** (2026-07-07, stand-in permanent).
16. **RESOLVED & IMPLEMENTED — shield chip restored** (2026-07-07).
17. **RESOLVED — voidCirclet 68% accepted; compensating Synod pass owed** (folds into the post-semantics rebalance).

Shipped adjudications without a number (cloak 2 clauses, pierce+breach kept
distinct, taunt unified, jam cap 10, ECS rejected) are recorded as K1–K5 in
DECISIONS_RESOLVED.md.
