# Overload Protocol — TRUTH (Canonical Reference)

*Generated 2026-07-06 by reconciling `offline-bundle/GROUND_TRUTH.md` against the live code and data on `feat/keyword-batch` (post keyword-batch, post unlock system). **When any doc disagrees with this file, this file wins.** When this file disagrees with code, the code wins — fix this file and record the correction.*

---

## ⚠️ Doc adjudications (carried + new)

Verdicts from GROUND_TRUTH, re-verified against current code, plus corrections found during this reconciliation:

| Question | Stale claim (where) | **TRUTH (verified in code)** |
|---|---|---|
| Orientation | landscape (old GDD/ROADMAP) | **Portrait 1080×2400**, preview 450×1000 (`project.godot`) |
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
5. Shields last **one opposing action phase** (per-side expiry, CONFIRMED per Kev 2026-07-06, DECISIONS_RESOLVED #2): granted this round, absorb through this round's opposing phase, gone at the round-end tick (no `shT` field exists anywhere in data — audited 2026-07-07, zero offenders). Enemy-phase grants survive one tick so they cover exactly one hero phase. **The SINGLE named exception is `shieldsPersist`** (Mantle Core relic / MANTLE TYRANT standing rule), which keeps shields until broken — nothing else may persist a shield.
6. Protocol resets each battle (does NOT carry over; Overflow relic carries 50%).
7. **Freeze = REPEAT** (one keyword, identical both sides; per Kev 2026-07-06, FINAL — restores the original design intent, supersedes both the next-turn lockout and the fix-1.4 bank/thaw banked-face model, see `docs/DECISIONS_RESOLVED.md` #1): a frozen die crusts and stays static in the tray as a hard physics blocker other dice bounce off. On each of its next N rolls it does NOT reroll — it keeps the same face, and its unit **acts again on that same result: same zone, same ability**. Targeting is re-picked fresh on each repeat (manual pick for heroes, personality choke-point for enemies); only the die result is locked. After its authored N repeats the die thaws and rerolls normally. The target still acts normally the round it is frozen. While frozen the die is **immune to Jam, Rewrite, and Hijack**, and can't be Rerolled/Set/Twin-Fates-overwritten. Any freeze ability with **no damage component** (incl. shield+freeze / heal+freeze) uses `freezeAnyDice` — one manual pick, EITHER side (freezing an ally repeats their good roll on purpose); freeze riders on damaging abilities stay enemy-side. **Enemy AI freeze targets the hero's LOWEST revealed die** — deterministic, no randi (taunt still overrides; cloak still hides). Re-freezing adds repeats; a frozen unit whose repeated ability applies freeze chains legally (each repeat decrements — no infinite loop). Deep Freeze directive extends the repeat count. Cosmetic `freeze_flavor`: ice (default) / petrify.
8. **Firewall** (internal field `ward`, displayed Firewall/FW): blocks the next ability that targets the unit, then breaks; an AoE that includes the unit is blocked for that unit only.
9. Zone names in data: `recharge` (low) → `strike` → `surge` → `crit` → `overload` (the 20).
10. **Buff/DoT timers are independent instances** (per Kev 2026-07-06, FINAL — resolves old DECISIONS #3, see `docs/DECISIONS_RESOLVED.md`): roll buffs (`rfm` heroes / `erb` enemies, identical) and Burn no longer refresh on re-cast. Each application is its own instance with its own remaining duration; the effective value is the SUM of live instances; each expires on its own clock. Contract: an Nt roll-buff instance cast on turn T is live turns T..T+N-1 (one turn is spent at EVERY round-end tick, including the cast round) — canonical case: +3/2t cast turn 1 plus +5/2t cast turn 2 → turn 2 total +8, turn 3 total +5, turn 4 zero. Burn instances keep their skip-first-tick timing (an Nt burn deals N ticks over the N rounds after application) but run independent clocks; the display aggregates ONE chip: summed value, longest remaining duration. Consequence worth knowing: a 1t roll buff cast mid-round expires at that same round's tick and never shapes a roll — the three authored 1t casualties (Cover Field, Aegis Bash, Emergency Signal) were corrected to 2t on 2026-07-06 as timer-contract repairs (restoring the authored one-subsequent-roll intent), not tuning; no 1t mid-round roll buff remains in data.

## Protocol economy (battle_engine.gd / battle_scene.gd)

- **Income:** start each battle at **0**, gain **+1 at the END of every turn**. Cap **10** (`MAX_PROTOCOL`).
- **Costs:** Nudge **1** (+3 to effective roll) · Reroll **2** · Set-a-die **3** (`SET_DIE_COST`) · Item **1 flat** (all rarities).
- **+protocol sources:** gear `protocolOnBattleStart`, `protocolOnKill`, `protocolOnNat20` (Overload Capacitor), `protocolOnDieTamper` (Mirror Plate); relics `protocolCarryover`, `protocolOnItemUse` (Protocol Override — items cost 0 AND grant +1), `protocolOnMarkedKill` (Salvage Directive +2), `protocolOnShieldBreak` (Salvage Rig +1, boss relic); enemy `siphon: N` drains the pool on hit (floor 0).
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

**Legacy id quirks (do NOT change):** Strike Unit=`combat`, Spike Guard=`shield`, Splice Medic=`medic`. Freeze belongs to the Avalanche line only (hero-side); ±Roll chips to the Signal Breaker line only. Starters: `combat`, `avalanche`, `medic`.

## Ability eff text syntax (canonical)

Format: `[value type] [modifier] [target] [duration]`, joined by ` + `. Numbers first, type second, target third, duration last; target omitted for single enemy; duration omitted when instant.
- Damage `12 dmg` · `9 dmg all` · `10 dmg + pierce` · Burn `4 burn 3t` · Heal `8 heal ally` / `13 heal all` / `11 heal lowest` · Shield (one round, no suffix) `ally 9 shield` / `all 14 shield` · Roll `+3 roll ally` / `-2 roll all enemies 2t` · Protocol `+2 protocol` · Status `freeze (repeat 1)` / `freeze any (repeat 1)` / `freeze all (repeat 1)` / `cloak` / `self firewall` / `taunt` / `rampage +1` · Boss extras `wipe shields` / `summon 40%` (no phase-2 syntax).

### Data field glossary
`dmg` · `burn`+`burnT` · `heal`(+`healTgt`/`healAll`/`healLowest`) · `shield`(+`shieldAll`/`shTgt`/`shieldLowest`) · `rfe`+`rfT`(+`rfeAll`) · `rfm`+`rfmT`(+`rfmTgt`) · `ignSh` (pierce) · `blastAll` · `cloak` · `ward`(+`wardTgt`; displayed Firewall) · `taunt` / `enemySelfTaunt` · `revive` · `freezeAnyDice`/`freezeEnemyDice`/`freezeAllEnemyDice` (+`freeze_flavor`). **Max ONE manually-picked component per hero ability** (audit-enforced).

### Keyword engine (combat_manager.gd handlers ↔ keywords.data.json ↔ EffectPip codes)

| Keyword | Pip | Rule (verified) |
|---|---|---|
| Chain | CH | also hits lowest-HP other enemy at 60% round down; ×2 adds a jump |
| Detonate | DT | consume finite Burn: amount × remaining turns immediate; a PERMANENT burn adds one tick's damage and is NOT consumed (per Kev 2026-07-06 — `DETONATE_MAX_TURNS` removed, resolves old DECISIONS #4) |
| Execute | EX | target below 25% max HP after base damage → +8 flat bonus |
| Breach | BR | destroy all shield on target (or every enemy) before damage |
| Leech | LC | attacker heals 50% of HP damage dealt (after shields) |
| Mark | MK | next real hit +50% round up, then consumed |
| Spike | SP | this round, damaging the carrier costs N back; never persists |
| Jam | JM | target's next roll capped at **10** (`JAM_CAP`); die status, no chip |
| Rewrite | RW | target's next roll SET to 3; telegraphed |
| Hijack | HJ | enemy-only: next roll copies heroes' current highest die (voidScribe Checksum Copy, voidGlimmer Afterimage, spewer Mimic Gland) |
| Siphon | SI | enemy-only: on hit drain N Protocol (floor 0) |
| Taunt | T | unified (Lure deleted): "The taunted unit can only target the taunter." Hero-side redirects all enemy aim (overrides everything, even cloak); enemy-side (`lured_by_id` internal) restricts the hit hero's legal targets to the taunter + TAUNT chip on the hero's card |

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

**Targeting personalities (`scripts/battle/targeting_personality.gd`):** every hostile single-hero pick goes through ONE choke-point `personality_pick_target(enemy_state, hero_states, assignments_so_far)`, shared by UI and headless sim; no `randi()`. **SYSTEMATIC** (left→right by slot) · **WOUNDED** (lowest-HP) · **PACK** (joins an already-assigned hero; none → WOUNDED) · **SPITEFUL** (last hero to damage it, `last_attacker_id`, cleared on that hero's death; none → SYSTEMATIC). Universal: taunt overrides everything; cloaked heroes skipped; dead/illegal preferred target → the STATED fallback only (old "pure debuff → highest HP" special case REMOVED). Resolution: unit `targeting` field → kit table → SYSTEMATIC. Kit defaults: Facility SYSTEMATIC (guard/patrol/volt PACK; warden/boss WOUNDED) · Hive PACK (stalker/hiveBoss WOUNDED) · Veil WOUNDED (veilPrism/veilShard SYSTEMATIC) · Synod SYSTEMATIC (voidBinder/voidChanneler/voidCircletBoss WOUNDED; voidGlimmer SPITEFUL) · Accretion SPITEFUL (beastWolf/beastMonkey PACK; beastLynx WOUNDED). `ai_type` is UNTOUCHED and independent (nat20 elite summons + summon-injection guard). Enemy inspect shows "TARGETING: NAME — definition."

**Boss standing rules** (one always-on rule per boss, from turn 1, `BOSS_STANDING_RULES` keyed by display name): SCRAPMASTER — ASSEMBLY LINE, every 2nd enemy phase from its first activation rebuilds one destroyed Scrap Drone at 50% HP (DECISIONS_RESOLVED #5) · Hive Matriarch — THE BROOD, spawns a Bloodmite every 3 rounds · CONCLAVE OVERSEER — THE COURT, while any ally lives gains a Firewall each round start · ROOT HIEROPHANT — ROOT ACCESS, every round Rewrites the squad's highest die to 3 · MANTLE TYRANT — ACCRETION, +6 shield every round start, shields persist and stack. Round-start rules fire before the hero phase; turn-cadence rules at the start of the enemy phase.

---

## Rewards

- **Consumables:** 25 (`items.data.json`). **Gear:** 31 passives (`gear.data.json`). **Relics:** 35 = 30 draftable + 5 boss relics (`bossRelic: true`: Salvage Rig, Chitin Graft, Resonant Chorus, Root Access, Mantle Core); boss relics excluded from normal drafts, unlocked by first op clear, offered as Starting Directives at DEPLOY.
- **XP:** `XP_TO_EVOLVE = 100`, `XP_TO_DIRECTIVE = 250`. Per win: alive → `20 + round(avg effective roll)`; dead → `round(avg effective roll)`. One progression stop per win (extras deferred).
- **Directives (tier-3 passives):** at 250 XP an evolved unit picks 1 of 2 path-scoped directives (`directives` block per evolution). Full list in `heroes.data.json`; handlers in combat_manager (+battle_scene for Deep Cells).

## Save system + progression (SaveManager autoload)

`user://save.json`, `save_version: 1`: `{tutorial_done, stats: {runs_started, runs_won_by_op, best_clear, best_clear_by_op, nat20s, deaths}, unlocks: {boss_relics, heroes: ["combat","avalanche","medic"], operations: ["facility"], hero_ladder_rung: 0, heroes_new: []}, onboarding: {primers_seen: []}, settings: {}}`. Headless runs keep the profile in memory and **read as fully unlocked** so sim/audit can pick any hero/op. `onboarding.primers_seen` drives the keyword primers (one-shot micro-tutorials, `docs/PRIMERS.md`); pre-primer veteran saves are grandfathered with all current primers seen.

- **Hero ladder** (ONE rung max per run end; overshoot defers): (1) facility best_clear ≥ 6 OR runs_started ≥ 3 → **engineer** · (2) facility won → **shield** · (3) hive best_clear ≥ 6 → **pulse** · (4) hive won → **ghost** · (5) veil best_clear ≥ 6 → **breaker**.
- **Operation chain** (uncapped): boss clear unlocks the next — facility → hive → veil → voidCirclet → stellarMenagerie.
- **Grandfather clause:** pre-unlock-schema profiles that have played unlock everything, ladder maxed.
- `check_new_unlocks()` feeds the run-end UNLOCKED panel; `heroes_new` drives the NEW badge (cleared on first squad add). Locked heroes/ops render as black silhouettes + `[ LOCKED ]`, no hints. Dev tools (help menu SETTINGS): UNLOCK ALL, RESET SAVE PROFILE (two-step), RESET PRIMERS.

## Run structure

- **Templated slots:** fixed comps (b1, b10, one signature per op) or slot patterns rolled ONCE at run start (`GameState.resolved_battle_comps`); previews always show exact comps.
- **Beats:** battle-5 relic draft = INTERCEPT: RELIC CACHE (renders through the reward picker in event chrome). The draft fires on `GameState.drafted_relic_count() == 0` — a pkg5 Starting Directive boss relic never consumes the slot and is excluded from the offer (the 2026-07-06 battle-5 soft-lock fix; regression-pinned). Exactly 3 random beats per run in distinct gaps from {after b2,b3,b4,b6,b7,b8} — the relic battle's gap is structurally excluded; Fork/Intercept 50/50 with ≥1 of each; b6+ = major tier.
- **Zero-options guard (permanent fixture):** any between-battle choice screen (reward, relic cache, intercept, route fork, evolution/directive) that builds ZERO interactive options asserts loudly in debug and auto-resolves a logged default in release (`scripts/ui/choice_screen_guard.gd`, `[CHOICE_GUARD]` log tag + telemetry stub) so a playtest build can never soft-lock on a dead screen. A guard firing is always a bug in the offer roll — fix the offer, never widen the guard.
- **Route Fork:** standard vs flagged (same comp + 1 of 10 modifiers from `GameState.BATTLE_MODIFIERS`, no repeats; SUPPLY GRADE +2 = reward ladder two rows deeper, cap row 10).
- **Intercept:** 11 minor + 11 major cards (`GameState.INTERCEPT_CARDS`), drawn without replacement; Memorial Protocol redraws without a recent death.

---

## Battle UI geometry (layout contract)

Five stacked bands, portrait, 1080×2400 (preview 450×1000): Header 144 — Enemy rail 768 — Center rail 432 (dice + centered action button) — Hero rail 768 — Footer 144 (**Reroll, Nudge, Set, Item** + PROTOCOL n/m pips). Header height == footer height; all unit cards identical outer size; dice align to card slots; result tags are uniform die-docked plates (below hero dice, above enemy dice, never occluding the sprite). No scrolling. Touch-first.

## UI & feedback

**Keyword primers** (`docs/PRIMERS.md`): one-shot micro-tutorials — first sighting of a mechanic pauses the feedback at a group boundary and spotlights one rule sentence (data: `primers.data.json`; max one per turn; suppressed in tutorial/headless/auto battle; observer-only, never touches combat outcomes). The tutorial and primers share `SpotlightLayer`.
Chip doctrine: card chips are ONLY Burn / Mark / ±Roll / Firewall / Taunt (cap 3, +N overflow badge). Cloak = ghosted portrait · Freeze/Petrify = die crust (ice cyan / stone gray) · Jam = die tint + "JAM ≤10" marker · Rewrite/Hijack = pending die marker + readout entry · Spike = readout pip only. Result die face renders bright with a light outline, non-result faces dimmed ~40%. Nat-20 = gold wash + shake + stinger. Keyword feedback table: `offline-bundle/ANIMATION.md`.

## Visual identity

Deep navy bg; pixel art; `m5x7` font; hard edges, no gradients. Meaning-based color (current, post terminal-UI pass): **cyan/teal = player + primary actions** (teal primary buttons, corner brackets) · **red/rust = enemy/damage** · **green = HP bars and heals ONLY** · **amber = protocol pips, risk/confirm actions, unlock accents** · **gold = commit/reward moments**. `PixelUI` (`scripts/ui/pixel_ui.gd`) is the single source of truth for visual constants; `theme_overload.tres` mirrors it.

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

## Sim baseline (current)

`scripts/sim/baseline.json` — **post crit-banking checkpoint, accepted per Kev 2026-07-06 (BASELINE-APPROVED-BY-KEV)**: policy **l1** (greedy), **300 runs**, overall clear **0.2867**; per-op: facility **0.592**, voidCirclet **0.404**, veil **0.215**, hive **0.068**, stellarMenagerie **0.063**. voidCirclet's +10.5 vs the prior checkpoint is mechanically coherent: frozen dice are immune to Rewrite and Hijack, so ally banking directly counters ROOT HIEROPHANT's Root Access standing rule. Avalanche (**0.237**) remains the known repricing target; no ability numbers move until that ruling. Deferred balance numbers (DECISIONS_RESOLVED #6–#10, #17) re-anchor to this checkpoint. Historical reference only: repeat-freeze checkpoint 0.2533, pre-repeat 0.53 (`3901e06`), "flat sim ~1.7%". Design target stays: 25–40% skilled full-clear of facility in real play.

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
2. **RULED, pending** — shield per-side expiry reading.
3. **RESOLVED & IMPLEMENTED — independent instance timers (rfm/erb/burn).** See combat rule 10.
4. **RESOLVED & IMPLEMENTED — permanent-burn Detonate = one tick, not consumed.**
5. **RULED, pending** — SCRAPMASTER "every other turn" cadence.
6. **RULED, pending** — INTERCEPT_CARDS numbers.
7. **RULED, pending** — route modifier numbers.
8. **RULED, pending** — boss cadence numbers.
9. **RULED, pending** — execute bonus.
10. **RULED, pending** — chain jump ratio.
11. **RULED, pending** — Reverse Gimbal UX.
12. **RULED, pending** — cloak hostile-only untargetability.
13. **RULED, pending** — tutorial runs in `runs_started`.
14. **RULED, pending** — directive Marks single-target on AoE.
15. **RULED, pending** — mid-run re-equip.
16. **RULED, pending** — active shield total readout.
17. **RESOLVED — voidCirclet 68% accepted; compensating Synod pass owed** (folds into the post-semantics rebalance).

Shipped adjudications without a number (cloak 2 clauses, pierce+breach kept
distinct, taunt unified, jam cap 10, ECS rejected) are recorded as K1–K5 in
DECISIONS_RESOLVED.md.
