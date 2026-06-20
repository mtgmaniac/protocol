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
5. Shields are per-turn unless the ability specifies `shT` > 1.
6. Protocol Bar resets each battle (does NOT carry over).
7. Frozen dice keep their value and skip the next N reveals (`freezeAnyDice` / `freezeEnemyDice` / `freezeAllEnemyDice`).
8. Zone names in data: `recharge` (low) → `strike` → `surge` → `crit` → `overload` (the 20).

## Protocol economy (implemented in battle_scene.gd / combat_manager.gd)
Battle-only resource for dice manipulation; resets each battle (unless the Overflow relic carries 50%).
- **Income:** start each battle at **0**, gain **+1 at the END of every turn**. Cap **10** (`MAX_PROTOCOL`).
- **Costs:** Nudge **1** (+**3** to effective roll) · Reroll **2** · Set-a-die **3** · Item **1 flat** (all rarities).
- **Model:** 1 income ≈ one protocol action per turn; bank turns for bigger plays.
- **+protocol sources:** gear `protocolOnBattleStart`, `protocolOnKill`, `protocolOnKillAny`; relics `protocolCarryover`, `protocolOnItemUse` (Protocol Override — items cost 0 AND grant +1).

---

## The 8 heroes (from heroes.data.json — COMPLETE)

Each has 5 base abilities + 2 evolution paths (each path = 5 abilities). Callsign in combat, full name in menus.

| ID | Name | Callsign | Class | Category | HP | Evolutions (evo callsign) |
|---|---|---|---|---|---|---|
| `pulse` | Pulse Tech | PULSE | Energy Wielder | damage | 40 | Cryo Specialist (CRYO) / Pyro Specialist (PYRO) |
| `combat` | Strike Unit | STRIKE | Strike Ops | damage | 55 | Bladecore (BLADE) / Ravager (RAVAGER) |
| `shield` | Spite Guard | SPITE | Antagonist Plate | defense | 60 | Bulwark (BULWARK) / Sentinel (SENTINEL) |
| `avalanche` | Avalanche Suit | AVALANCHE | Squad Shell | defense | 55 | Glacier Mantle (GLACIER) / Trench Rig (TRENCH) |
| `medic` | Splice Medic | SPLICE | Combat Augmentor | support | 45 | Combat Medic (MEDIC) / Synth Warden (SYNTH) |
| `engineer` | Field Engineer | ENGINEER | Support Tech | support | 50 | Overclocked (OVERCLOCKED) / Wraith Engineer (PHANTOM) |
| `ghost` | Ghost Operative | GHOST | Infiltrator | control | 40 | Shadow Operative (SHADOW) / Wraith (WRAITH) |
| `breaker` | Signal Breaker | BREAKER | Comms Interdictor | control | 45 | Noise Floor (NOISE) / Nullwire (NULLWIRE) |

**Callsign collision resolved:** Wraith Engineer uses PHANTOM (not WRAITH) to avoid collision with Ghost's Wraith. **Note internal IDs are legacy quirks:** Strike Unit=`combat`, Spite Guard=`shield`, Splice Medic=`medic`. Do NOT change existing ids.

## Ability eff text syntax (canonical — all abilities in workbook now use this)
Format: `[value type] [modifier] [target] [duration]`. Effects joined by ` + `. Rules: numbers first, type second, target third, duration last. Target omitted when single enemy (default). Duration omitted when instant.
- Damage: `12 dmg` · `9 dmg all` · `10 dmg + pierce`
- DoT: `4 dot 3t` (amount, keyword, turns; turns omitted if 1)
- Heal: `8 heal ally` · `13 heal all` · `11 heal lowest`
- Shield: `9 shield ally` · `14 shield all 2t`
- Roll effects: `+3 roll ally` · `-2 roll all enemies 2t` · `+1 roll self 2t`
- Protocol: `+2 protocol`
- Status: `freeze any die 1 skip` · `cloak` · `taunt` · `counterspell 40%` · `rampage +1`
- Combo: `8 dmg + 4 dot 2t` · `6 dmg all + -2 roll all enemies`
- Phase 2 bosses: `19 dmg (P2: 26)` · `wipe shields` · `summon 40%`

### Ability field glossary (data keys)
`dmg` direct damage · `dot`+`dT` damage-over-time amount + turns · `heal` (+`healTgt`/`healAll`/`healLowest`) · `shield`+`shT` (+`shieldAll`/`shTgt`) · `rfe`+`rfT` enemy roll reduction + turns (+`rfeAll`) · `rfm`+`rfmT` ally roll buff (+`rfmTgt`) · `ignSh` pierce shields · `blastAll` hit all enemies · `cloak` · `taunt` · `revive` · `freezeAnyDice`/`freezeEnemyDice`/`freezeAllEnemyDice` N reveals.

---

## Enemies (from enemies.data.json — COMPLETE, 6 factions)

39 enemy defs across 5 operations + comms units. Structure: `enemyAbilities[type]` (5-zone table) + `enemyUnitDefs[Name]` (hp, dMin/dMax, type, ai, callsign) + `battleEnemyScale` (per-battle hp/dmg multipliers).

| Operation (battle-modes order) | Faction flavor | Boss |
|---|---|---|
| `facility` | Corporate drones, ECM skimmers, hexnodes | SCRAPMASTER |
| `hive` | Insectoid swarm | Hive Matriarch |
| `veil` | Harmonic/resonance | Conclave Overseer |
| `voidCirclet` | Cult casters | Circlet Hierophant |
| `stellarMenagerie` | Beasts | Void Reaver |

AI types seen: `dumb` (and others per unit). Enemies don't use Protocol. Some have phase-two thresholds (`phase_two_threshold`, `phase_two_damage_preview_*`) and `can_summon_elite`.

---

## Rewards (all COMPLETE)

- **Consumables** (`items.data.json`): 37 items, rarities common→legendary. Types: `heal`, `shield`, `rollBuff`, `revive`, `cloak`/`cloakAll`, `enemyRfe`, `enemyDmg`, `enemyBurn`, `xpBoost`, `enemyRerollDie`/`enemyRerollAll`, `enemyDieFreeze`.
- **Gear** (`gear.data.json`): 10 passives (rollBonus, battleStartShield, maxHpBonus, burnDmgBonus, battleStartCloak, healOnKill, protocolOnBattleStart, surviveOnce, firstAbilityDmgBonus, dmgReduction).
- **Relics** (`relics.data.json`): 13 run-modifiers (Iron Curtain, Opening Gambit, Bulwark Aura, Nanite Field, Plague Protocol, Overcharge, Signal Jam, Coordinated Strike, Resonance Cascade, Gravity Well, Protocol Override, Entropy Leak, Chain Reaction).

XP: `XP_PER_BATTLE = 50`, `XP_TO_EVOLVE = 100` (so evolution triggers ~battle 2–3 for survivors).

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
