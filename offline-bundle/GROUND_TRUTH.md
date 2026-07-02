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
- Burn (the single universal DoT name): `4 burn 3t` (amount, keyword, turns; turns omitted if 1)
- Heal: `8 heal ally` · `13 heal all` · `11 heal lowest`
- Shield (always one round, no duration suffix): `ally 9 shield` · `all 14 shield` · `lowest 7 shield`
- Roll effects: `+3 roll ally` · `-2 roll all enemies 2t` · `+1 roll self 2t`
- Protocol: `+2 protocol`
- Status: `freeze (1 reveal skip)` · `freeze all (2 reveal skips)` · `cloak` · `self ward` · `ally ward` · `taunt` · `rampage +1`
- Combo: `8 dmg + 4 burn 2t` · `6 dmg all + -2 roll all enemies`
- Phase 2 bosses: `19 dmg (P2: 26)` · `wipe shields` · `summon 40%`

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

- **Consumables** (`items.data.json`): 34 items, rarities common→legendary. Types: `heal`, `shield`, `rollBuff`, `revive`, `cloak`/`cloakAll`, `ward`, `enemyRfe`, `enemyDmg`, `enemyBurn`, `enemyRerollDie`/`enemyRerollAll`, `enemyDieFreeze`. (XP consumables removed in pkg1.5.)
- **Gear** (`gear.data.json`): 10 passives (rollBonus, battleStartShield, maxHpBonus, burnDmgBonus, battleStartCloak, healOnKill, protocolOnBattleStart, surviveOnce, firstAbilityDmgBonus, dmgReduction).
- **Relics** (`relics.data.json`): 13 run-modifiers (Iron Curtain, Opening Gambit, Bulwark Aura, Nanite Field, Plague Protocol, Overcharge, Signal Jam, Coordinated Strike, Resonance Cascade, Gravity Well, Protocol Override, Entropy Leak, Chain Reaction).

XP: **`XP_TO_EVOLVE = 100`**. Per win: alive → **`20 + round(avg effective roll)`**; dead → **`round(avg effective roll)`** only. One evolution stop per win (extras deferred). First evo typically ~fight 3–4.

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
