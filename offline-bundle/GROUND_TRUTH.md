# Overload Protocol — GROUND TRUTH (Offline Reference)
*Generated for offline work. This reconciles every conflicting doc in the repo. When a doc disagrees with this file, this file wins — it was built by reading the actual `data/raw/` content and `scripts/` code, not the stale design docs.*

---

## ⚠️ Doc conflicts resolved

Your repo has TWO generations of docs that disagree. Here's the verdict on each conflict, with the winner based on what the **code and data actually do**:

| Question | Stale docs say | Current docs say | **TRUTH (what code does)** |
|---|---|---|---|
| Orientation | landscape (`GDD.md`, `ROADMAP.md`, `docs/CLAUDE.md`, `PHASE_0_STATUS.md`) | portrait 1080×2400 (`BATTLE_UI_V2_SPEC.md`, `AI_AGENT_GAME_REFERENCE.md`) | **Portrait 1080×2400**, preview 450×1000 |
| Squad size | 4 units | 3 units | **3** (`GameState.SQUAD_UNIT_LIMIT := 3`) |
| Healer name | Systems Medic | Splice Medic | **Splice Medic**, callsign SPLICE |
| Operations | "build 1 faction first" | 5 operations | **5 fully defined** in `battle-modes.json` |
| Project phase | Phase 0 setup (`PHASE_0_STATUS.md`) | mid-implementation | **Well past Phase 0** — battle loop runs |
| Main scene | — | UnitSelect | **`res://scenes/ui/UnitSelect.tscn`** |

**Stale/ignore these docs:** `PHASE_0_STATUS.md` (entirely obsolete), the landscape/4-unit claims in `GDD.md`, `ROADMAP.md`, and `docs/CLAUDE.md`.
**Trust these docs:** `AI_AGENT_GAME_REFERENCE.md` (updated 2026-04-19, matches code) and `BATTLE_UI_V2_SPEC.md`.

---

## The game in one paragraph

Portrait mobile (Android-first, Godot 4.6) dark sci-fi tactical dice roguelike. Pick **3 of 8** specialists, choose **1 of 5 operations**, fight **10 battles** (boss on #10). Each turn every living unit rolls a D20; the roll lands in one of five zones (recharge/strike/surge/crit/overload) that maps to that unit's ability. Player resolves abilities (in chosen order, manual targeting where needed), then enemies resolve. Protocol Bar is a battle-only resource for dice manipulation (Reroll/Nudge + Item). Between battles: pick 1 of 3 rewards (gear/consumable), Relic at battle 5, units earn XP and evolve (2 branching paths each). Win = beat the boss; lose = full wipe.

---

## Combat rules (authoritative)

1. All dice roll simultaneously at turn start.
2. Player resolves first, in any order; then surviving enemies resolve.
3. End of turn: status effects tick, dice reset.
4. A unit that dies mid-turn does not act.
5. Shields last **one round**: granted this round, absorb through this round's opposing phase, gone at the round-end tick (no `shT` field exists). Enemy-phase grants survive one tick so they cover exactly one hero phase. Exception: `shieldsPersist` (Mantle Core relic / MANTLE TYRANT rule) keeps shields until broken.
6. Protocol Bar resets each battle (does NOT carry over).
7. **Freeze** (one keyword, identical both sides — former Cower merged in): the die locks in the tray (physical blocker) and the unit **skips its next N reveals** (`freezeAnyDice` / `freezeEnemyDice` / `freezeAllEnemyDice`; hero freezes on enemies cancel the imminent action). Cosmetic `freeze_flavor`: ice (default) / petrify.
7b. **Ward** (`ward: true`, replaces Counterspell): blocks the next ability that targets the unit, then breaks; an AoE that includes the unit is blocked for that unit only.
8. Zone names in data: `recharge` (low) → `strike` → `surge` → `crit` → `overload` (the 20).

## Protocol economy (implemented in battle_scene.gd / combat_manager.gd)
Battle-only resource for dice manipulation; resets each battle (unless the Overflow relic carries 50%).
- **Income:** start each battle at **0**, gain **+1 at the END of every turn**. Cap **10** (`MAX_PROTOCOL`).
- **Costs:** Nudge **1** (+**3** to effective roll) · Reroll **2** · Set-a-die **3** · Item **1 flat** (all rarities).
- **Model:** 1 income ≈ one protocol action per turn; bank turns for bigger plays.
- **+protocol sources:** gear `protocolOnBattleStart`, `protocolOnKill`, `protocolOnNat20` (Overload Capacitor), `protocolOnDieTamper` (Mirror Plate); relics `protocolCarryover`, `protocolOnItemUse` (Protocol Override — items cost 0 AND grant +1), `protocolOnMarkedKill` (Salvage Directive +2), `protocolOnShieldBreak` (Salvage Rig +1, boss relic); enemy `siphon: N` drains the pool on hit (floor 0).
- **Discounts/overflow:** Priming Charge gear — first Nudge free; Root Access boss relic — first Set each battle costs 0; Overflow Vent relic — protocol gained past the cap deals 2 damage per point to a random enemy; Twin Fates relic — once per battle copy one hero die to another, free.

---

## The 8 heroes (from heroes.data.json — COMPLETE)

Each has 5 base abilities + 2 evolution paths (each path = 5 abilities). Callsign in combat, full name in menus.

| ID | Name | Callsign | Class | Category | HP | Evolutions (evo callsign) |
|---|---|---|---|---|---|---|
| `pulse` | Pulse Tech | PULSE | Energy Wielder | damage | 45 | Pyro Specialist (PYRO) / Arc Specialist (ARC) |
| `combat` | Strike Unit | STRIKE | Strike Ops | damage | 55 | Bladecore (BLADE) / Ravager (RAVAGER) |
| `shield` | Spike Guard | SPIKE | Antagonist Plate | defense | 55 | Bulwark (BULWARK) / Sentinel (SENTINEL) |
| `avalanche` | Avalanche Suit | AVALANCHE | Squad Shell | defense | 55 | Glacier Mantle (GLACIER) / Trench Rig (TRENCH) |
| `medic` | Splice Medic | SPLICE | Combat Augmentor | support | 50 | Combat Medic (MEDIC) / Synth Warden (SYNTH) |
| `engineer` | Field Engineer | ENGINEER | Support Tech | support | 50 | Overclocked (OVERCLOCKED) / Phantom (PHANTOM) |
| `ghost` | Ghost Operative | GHOST | Infiltrator | control | 45 | Shadow Operative (SHADOW) / Wraith (WRAITH) |
| `breaker` | Signal Breaker | BREAKER | Comms Interdictor | control | 45 | Noise Floor (NOISE) / Nullwire (NULLWIRE) |

All 24 kits (8 base + 16 evolutions) were replaced wholesale in pkg3.1 per the master tables — Cryo Specialist became Arc Specialist (chain-focused), Spite Guard was renamed Spike Guard (SPIKE, spike-keyword identity). **Note internal IDs are legacy quirks:** Strike Unit=`combat`, Spike Guard=`shield`, Splice Medic=`medic`. Do NOT change existing ids. Freeze belongs to the Avalanche line only (hero-side); ±Roll chips belong to the Signal Breaker line only.

## Ability eff text syntax (canonical — all abilities in workbook now use this)
Format: `[value type] [modifier] [target] [duration]`. Effects joined by ` + `. Rules: numbers first, type second, target third, duration last. Target omitted when single enemy (default). Duration omitted when instant.
- Damage: `12 dmg` · `9 dmg all` · `10 dmg + pierce`
- Burn (the single universal DoT name): `4 burn 3t` (amount, keyword, turns; turns omitted if 1)
- Heal: `8 heal ally` · `13 heal all` · `11 heal lowest`
- Shield (always one round, no duration suffix): `ally 9 shield` · `all 14 shield` · `lowest 7 shield`
- Roll effects: `+3 roll ally` · `-2 roll all enemies 2t` · `+1 roll self 2t`
- Protocol: `+2 protocol`
- Status: `freeze (1 reveal skip)` · `freeze all (2 reveal skips)` · `cloak` · `self ward` · `ally ward` · `taunt` · `rampage +1`
- Combo: `8 dmg + 4 burn 2t` · `6 dmg all + -2 roll all enemies`
- Boss extras: `wipe shields` · `summon 40%` (no phase-2 syntax — bosses run standing rules instead)

### Ability field glossary (data keys)
`dmg` direct damage · `burn`+`burnT` damage-over-time amount + turns · `heal` (+`healTgt`/`healAll`/`healLowest`) · `shield` (+`shieldAll`/`shTgt`/`shieldLowest`; one round, no duration field) · `rfe`+`rfT` enemy roll reduction + turns (+`rfeAll`) · `rfm`+`rfmT` ally roll buff (+`rfmTgt`) · `ignSh` pierce shields · `blastAll` hit all enemies · `cloak` · `ward` (+`wardTgt`) · `taunt` · `revive` · `freezeAnyDice`/`freezeEnemyDice`/`freezeAllEnemyDice` N reveal skips (+ cosmetic `freeze_flavor`: ice/petrify).

**Targeting rule (enforced by audit_ability_keywords.py):** max ONE manually-picked component per hero ability; everything else auto-targets self / all / lowest. Components sharing a pick (dmg+burn+freeze on one enemy; healTgt+shTgt+rfmTgt+wardTgt on one ally) count once.

### Keyword engine (pkg2 — combat_manager.gd handlers, keywords.data.json entries, EffectPip codes)

| Keyword | Pip | Field | Rule |
|---|---|---|---|
| Chain | CH | `chain: N` | damage also hits the lowest-HP other enemy at 60% (round down); N = extra jumps; `chainExtraJump` relic hook |
| Detonate | DT | `detonate: true` | consume target's Burn: burn × remaining turns immediate damage, Burn cleared; `gear_detonate_bonus` +50% hook |
| Execute | EX | `execute: true` | target below 25% max HP after base damage → +8 bonus (`execute_threshold_pct` hook) |
| Breach | BR | `breach` / `breachAll` | destroy all shield on target (or every enemy) before damage |
| Leech | LC | `leech: true` | attacker heals 50% of HP damage dealt (after shields) |
| Mark | MK | `mark: true` | status chip; next real attack on target +50% round up, then consumed (`mark_consumed_this_hit` kill hook) |
| Spike | SP | `spike: N` (both sides) | this round, any unit damaging the carrier takes N; never persists past the round; readout pip only |
| Jam | JM | `jam` / `jamAll` (both sides) | target's next roll capped at 12 (`JAM_CAP`); die status, no chip |
| Rewrite | RW | `rewrite: true` (both sides) | target's next roll SET to 3 (`REWRITE_VALUE`); telegraphed; `apply_rewrite_to_state` boss hook |
| Hijack | HJ | `hijack: true` (enemy) | enemy's next roll copies the heroes' current highest die |
| Siphon | SI | `siphon: N` (enemy) | on hit, drain N Protocol (floor 0) via `take_pending_protocol_drain` |

**Cloak (reworked):** untargetable by hostile single-target abilities (manual targeting, AI, and resolve-time retarget all skip cloaked units); breaks when the unit deals damage OR is hit by an AoE; the first attack made from Cloak gains Pierce. `battleStartCloak` gear inherits.

**One keyword per ability** (pierce counts), **two allowed in the overload zone** — enforced by `audit_ability_keywords.py`.

---

## Enemies (from enemies.data.json — COMPLETE, 5 factions)

38 enemy unit defs / 37 ability kits across 5 operations. Structure: `enemyAbilities[type]` (5-zone table) + `enemyUnitDefs[Name]` (hp, dMin/dMax, type, ai, callsign ≤8 chars, optional `accrete`, `startsCloaked`) + `battleEnemyScale` (per-battle hp/dmg multipliers). All 24 core kits were reworked in pkg3.3 around faction identities.

| Operation key | Label / callsign | Faction identity | Boss (battle-10 escort) |
|---|---|---|---|
| `facility` | Facility sweep / FACILITY | drones: jam, shields, breach bait | SCRAPMASTER (+2 Scrap Drones) |
| `hive` | Hive incursion / HIVE | swarm: burn, siphon-free drain, summons, spike carriers | Hive Matriarch (+Spine Stalker) |
| `veil` | Veil Concord / VEIL | lattice: ally shields, wards, buffs | CONCLAVE OVERSEER (+Aegis Anchor) |
| `voidCirclet` | Null Synod / SYNOD | machine cult: rewrite, hijack, siphon, ±roll | ROOT HIEROPHANT (+Checksum Scribe) |
| `stellarMenagerie` | The Accretion / ACCRETION | igneous beasts: accrete shields, petrify freezes, spike, cloak | MANTLE TYRANT (+Geode Panther) |

Signature units: Forked Double `startsCloaked`; Basalt Ape accrete 3 + spike 5; Magma Drake accrete 4; Geode Panther cloak + petrify freeze (`freeze_flavor: petrify`); Pyroclast Raptor lure. Enemies don't use Protocol (Siphon drains the heroes' pool).

**Boss standing rules (pkg4 — replaces the deleted phase-2 system):** one always-on rule per boss, active from turn 1, keyed by display name in `combat_manager.gd` `BOSS_STANDING_RULES` (single text source for the battle-start log line and the inspect popup):

| Boss | Rule |
|---|---|
| SCRAPMASTER | ASSEMBLY LINE — every other round, rebuilds one destroyed Scrap Drone at 50% HP |
| Hive Matriarch | THE BROOD — spawns a Bloodmite every 3 rounds |
| CONCLAVE OVERSEER | THE COURT — while any ally lives, gains Ward at the start of each round |
| ROOT HIEROPHANT | ROOT ACCESS — every round, Rewrites the squad's highest die to 3 |
| MANTLE TYRANT | ACCRETION — +6 shield at every round start; its shields persist and stack |

Round-start rules (Ward, mantle shield) fire before the hero phase; turn-cadence rules (rebuild, brood, root access) fire at the start of the enemy phase. Battle-10 escorts are pinned per operation: SCRAPMASTER +2 Scrap Drones · Matriarch +Spine Stalker · Overseer +Aegis Anchor · ROOT +Checksum Scribe · MANTLE +Geode Panther.

---

## Rewards (all COMPLETE)

- **Consumables** (`items.data.json`): 25 items after the pkg3.6 once-per-effect cleanup. Dice/freeze/reroll/protocol ladders kept intact (`rollBuff` ×4, `enemyRfe` ×3, `enemyRerollDie`/`enemyRerollAll`, `enemyDieFreeze`/`enemyDieFreezeAll` ×3, `gainProtocol` ×4); one entry per behavior for `heal`/`healAll`, `shield`/`shieldAll`, `enemyDmg`, `enemyBurn`, `revive`, `cloak`/`cloakAll`. (XP consumables removed in pkg1.5.)
- **Gear** (`gear.data.json`): 31 passives — the pinned pkg3.4 pool. Includes dice-band shapers (`overloadBandCompress` Band Compressor, `surgeBandExtend` Wide Aperture — runtime overrides in DiceManager.get_adjusted_ranges), nudge/set economy (`nudgeMaySubtract` Reverse Gimbal, `firstNudgeFree` Priming Charge), protocol taps (`protocolOnNat20`, `protocolOnDieTamper`), keyword hooks (`burnImmediateTick` Ignition Coil, `detonateBonus` Payload Fuse, `battleStartMark` Targeting Optic), and squad tools (`tauntAbove50` Anchor Frame, `deathDamageAll` Killswitch Relay, `syncRollBonus` Sync Antenna).
- **Relics** (`relics.data.json`): 35 total — 30 draftable run-modifiers + 5 boss relics flagged `bossRelic: true` (Salvage Rig, Chitin Graft, Resonant Chorus, Root Access, Mantle Core). Boss relics are excluded from normal drafts (GameState `_roll_relic_choice_ids`); they unlock via the pkg5 save system. Every relic effect type has a combat/scene handler and an audit regression (`audit_gear_relic_effects.py` + ability audit).

XP: **`XP_TO_EVOLVE = 100`**, **`XP_TO_DIRECTIVE = 250`**. Per win: alive → **`20 + round(avg effective roll)`**; dead → **`round(avg effective roll)`** only. One progression stop per win (extras deferred — evolutions and directives share the queue). First evo typically ~fight 3–4.

## Directives (pkg6 — tier-3 passives)

Evolved units keep accruing XP; at 250 the evolution screen offers **1 of 2 Directives** scoped to the unit's evolution path (`directives` block per evolution in heroes.data.json; schema `#/$defs/directive`). The pick lands on `GameState.unit_directives` → `UnitData.directive` → hero state `directive_type`/`directive_effect`; handlers live in combat_manager (battle_scene for Deep Cells' protocol cap). Static coverage: `DIRECTIVE_HANDLED` in audit_gear_relic_effects.py; runtime: 13 audit regressions + the flow-smoke forced-250-XP step.

Pyro: Flashpoint (burn ticks on apply) / Slow Roast (burns +1t) · Arc: Conductor (chain +1 jump) / Amplifier (chain 100%) · Bladecore: Serrated (pierce also breaches) / Momentum (kill → +4 next ability) · Ravager: Deep Cuts (+3 vs burning) / Open Veins (overload detonates after) · Bulwark: Rampart (your shields +2) / Bunker Doctrine (your shields grant allies Spike 3) · Sentinel: Ironclad (taunting −2 incoming) / Counterweight (spike +4) · Glacier: Deep Freeze (freezes 2 reveals) / Shatterpoint (+6 vs frozen) · Trench: Field Triage (heals grant 3 shield) / Entrench (start 10 shield) · Combat Medic: Combat Sense (hits mark) / Field Surgeon (Surge Revive 100%) · Synth: Overcharge Mesh (squad shields +2) / Lazarus Loop (Mass Revival 50%) · Overclocked: Deep Cells (protocol cap +2) / Surge Wiring (Bias Charge +2) · Phantom: Silent Running (non-damage re-cloaks) / Ambush Wiring (cloak attacks +5) · Shadow: Ghostblade (decloak strike executes) / Vanish (below 50% cloak, once) · Wraith: Marked for Death (hits mark) / Reaper (execute below 35%) · Noise: Wall of Static (rfeAll also jams, cap 15) / Feedback (2 dmg/round under roll-downs) · Nullwire: Hard Lock (rfe also jams) / Signal Theft (+1 protocol per roll-down).

## Save system (pkg5 — SaveManager autoload)

`user://save.json`, `save_version: 1`: `{tutorial_done, stats: {runs_started, runs_won_by_op, best_clear, nat20s, deaths}, unlocks: {boss_relics: []}, settings: {}}`. Headless runs (audits/smokes) keep the profile in memory — no disk writes. Hooks: `GameState.start_run` → runs_started; `GameState.finish_run` → best_clear ratchet + victory increments `runs_won_by_op[op]` and unlocks that op's boss relic (facility→salvageRig · hive→chitinGraft · veil→resonantChorus · voidCirclet→rootAccess · stellarMenagerie→mantleCore); post-roll nat 20s; hero deaths; tutorial completion. **Starting Directive:** at DEPLOY, unlocked boss relics are offered as the run's opening relic (`GameState.starting_directive_relic_id`); the battle-5 relic draft still happens — a directive run ends with two relics by design. The run-end screen shows the SERVICE RECORD stats block. (Audio settings persist separately in `user://settings.cfg` via AudioManager.)

---

## Run structure (pkg7)

**Templated slots (7.1):** battle-modes battles are fixed comps (b1, b10, one signature per op) or slot patterns rolled ONCE at run start from per-faction role pools (`GameState.resolved_battle_comps` — previews always show exact comps). Classification documented in battle-modes.schema.json.

**Beats (7.2):** battle-5 relic draft renders as INTERCEPT: RELIC CACHE. Exactly 3 random beats per run in distinct gaps from {after b2,b3,b4,b6,b7,b8}, Fork/Intercept 50/50 with ≥1 of each; b6+ beats are major-tier. `SceneManager.go_to_next_battle_or_beat()` routes the post-victory flow.

**Route Fork (7.3):** RouteForkScreen — standard vs flagged (same comp + 1 of 10 modifiers, no repeats per run, preconditions on Overrun/Warded + SUPPLY GRADE +2 = reward ladder two rows deeper, cap row 10). Modifier ids in `GameState.BATTLE_MODIFIERS`; combat hooks in combat_manager (`setup_battle_modifier`), Blackout/Sealed Supplies in battle_scene.

**Intercept (7.4):** InterceptScreen — 11 minor + 11 major cards (`GameState.INTERCEPT_CARDS`), shuffled per run, drawn without replacement; Memorial Protocol redraws without a recent death. Effect engine: hero run-mods (roll bonus / max HP / start cloaked-warded / nat-20 echo / Splice bands), next-battle effects (protocol, 70% spawns, items free, decoy, marked highest, income debt, −1 enemy), follow-up promotion, Rogue Engineer (+1/battle, cap 8), gear rotate/destroy/Foundry.

**Gates:** `run_smoke_test.gd` plays one full run headless; flow smoke covers fork + intercept screens.

---

## Battle UI V2 geometry (the layout contract)

Five stacked bands, portrait. At 1080×2400 / (450×1000 preview):
- Header: 144 / 60 px — battle label
- Enemy rail: 768 / 320 px
- Center rail: 432 / 180 px — dice + centered action button
- Hero rail: 768 / 320 px
- Footer: 144 / 60 px — **Reroll, Nudge, Item** (Item opens a menu, not many slots)

Rules: header height == footer height; all unit cards identical outer size; hero and enemy card structure identical; dice align to card slots; readouts in a dedicated strip outside cards; center button exactly centered. No scrolling. Touch-first.

---

## Visual identity

Deep navy bg; meaning-based color: **cyan = player, red = enemy/damage, green = protocol/heal, gold = commit/reward**. Pixel art, `m5x7` font (`assets/fonts/m5x7.ttf`). Flat — no gradients, no glows. Cold/industrial; explicitly NOT "sci-fi Slice & Dice."

---

## Out of scope (don't build)

Cross-run persistent XP/unlocks; node map between battles; multiplayer; narrative; full audio mix.
