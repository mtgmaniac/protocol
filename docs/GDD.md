# Overload Protocol — Game Design Document

> **Agents:** Prefer `docs/AI_AGENT_GAME_REFERENCE.md`, `docs/BATTLE_UI_V2_SPEC.md`, and `offline-bundle/GROUND_TRUTH.md` for runtime truth. This GDD is design context; when it conflicts with code/data, ground truth wins.

**Version:** 0.3 (Active Development)
**Platform:** Mobile First (Android), portrait 1080×2400 (preview 450×1000)
**Engine:** Godot 4.6
**Developer:** Solo (Kev)
**Status:** Battle loop running; ongoing combat/UI/content work

---

## 1. Vision Statement

Overload Protocol is a dark sci-fi tactical dice roguelike where you command a squad of three specialists against increasingly dangerous alien threats. Every run is a 15–30 minute puzzle of dice manipulation, squad synergy, and risk management. Inspired by the pure mechanical tension of Slice & Dice, the run structure of Slay the Spire, and the dark unit identity of Starcraft.

**Core feeling:** Tense, satisfying, and skilful. The player should feel like they earned every win and understand every loss.

---

## 2. Core Pillars

| Pillar | What it means |
|---|---|
| **Tactical tension** | Every dice roll matters. Every decision has consequences. |
| **Squad identity** | Your 3 units feel distinct and synergize in meaningful ways. |
| **Run variety** | Who you pick, what you fight, and what items you find create different runs. |
| **Readable chaos** | Dice are random but manipulable. The player always has agency. |

---

## 3. Aesthetic

- **Tone:** Dark, gritty, cold. Space gothic. Think Starcraft meets Dead Space.
- **Palette:** Deep blacks, metallics, biopunk greens and purples, warning reds.
- **UI:** Tactical HUD aesthetic. Clean readouts, damage numbers, status bars.
- **Units:** Portrait-based. Each unit has a distinct silhouette and visual identity.
- **Enemies:** Same portrait UI as players — mirrored battlefield.

---

## 4. Game Loop

### The Run
```
Select 3 Heroes (from 8)
        ↓
Select Operation (1 of 5)
        ↓
Battle 1 → Battle 2 → ... → Battle 9 → Boss (Battle 10)
        ↓
After each battle: Choose 1 of 3 rewards (consumable or gear)
After Battle 5: Choose a Relic (run-wide modifier)
        ↓
Win: Defeat the Boss
Lose: All units wiped in a single battle
```

### One Battle Turn
```
All units + enemies roll their dice simultaneously
        ↓
Player resolves their units' abilities (in chosen order)
        ↓
Surviving enemies resolve their abilities
        ↓
Dice reset, new turn begins
        ↓
Battle ends when one side is fully eliminated
```

### Between Battles
- Gear and items persist
- Dead units resurrect at start of next battle with partial HP penalty
- Protocol Bar resets each battle

---

## 5. Units

### Roster (8 Total, Player Picks 3)

| Unit | Category | Playstyle |
|---|---|---|
| **Pulse Tech** | damage | Elemental single-target and AoE |
| **Strike Unit** | damage | High single-target damage, pierce |
| **Spite Guard** | defense | Shields, counterattack, punishment |
| **Avalanche Suit** | defense | Heavy area attacks, rampage |
| **Splice Medic** | support | Team heals, resurrection support |
| **Field Engineer** | support | Protocol generation, shields, squad buffs |
| **Ghost Operative** | control | Cloak, high-risk high-reward burst |
| **Signal Breaker** | control | DoT, disruption, counterspell |

### Unit Card (What Appears on the Battlefield)
Each unit is represented as a permanent portrait card. It displays:
- Portrait art
- HP bar
- Current dice result
- Current ability (mapped to dice roll)
- Status effects (frozen, DoT, cloaked, etc.)
- Gear slots
- XP bar
- Level / Evolution indicator

### Dice Ranges (D20)
Each unit maps dice roll ranges to 5 abilities. Ranges vary per unit. Example structure:

```
1–5:   Weak / Passive ability
6–9:   Defensive ability (shield or heal)
10–15: Standard ability (attack or support)
16–19: Strong ability (heavy attack or team effect)
20:    Signature / Ultimate ability
```

Exact ranges are defined per-unit in unit metadata files.

### Evolution
- Units gain **50 XP per battle won**; evolve at **100 XP** (~fight 2 for survivors)
- Player chooses one of **two branching paths** (each path = full 5-zone kit + callsign)
- Evolution persists for the run; resets on run end

---

## 6. Dice System

### The Roll
- One D20 per living unit per turn (player and enemy)
- All dice rolled simultaneously at turn start
- Result maps directly to the unit's ability chart

### Manipulation Methods

| Method | Source | Effect |
|---|---|---|
| **Nudge** | Protocol Bar (small cost) | +/- small value to a die |
| **Reroll** | Protocol Bar (medium cost) | Reroll one die completely |
| **Set** | Protocol Bar (large cost) | Force a die to any value |
| **Freeze** | Enemy/Hero ability | Die locked, same result next turn |
| **Modify** | Abilities | Increase or decrease die value |

### Protocol Bar
- Battle-only resource; **resets to 0 each battle** (unless a relic carries a % over)
- **+1 at end of every turn**, cap **10**
- Spend actions: **Nudge 1** (+3 to a die, once per die per turn) · **Reroll 2** · **Set 3** (pick 1–20) · **Item 1** (flat, all rarities)
- Additional income from abilities (`gainProtocol`), gear, and relics

---

## 7. Combat System

### Turn Structure
1. Roll phase — all dice rolled simultaneously
2. Player phase — player resolves unit abilities in chosen order
3. Enemy phase — surviving enemies resolve abilities
4. End of turn — status effects tick, dice reset

### Damage Model
- Units have HP bars
- Shields absorb damage before HP (shields don't carry between turns unless specified)
- DoT (data key `dot`) ticks at end of enemy phase
- Dead units are removed from the field; their dice no longer roll

### Status Effects
| Effect | Behaviour |
|---|---|
| Frozen | Dice locked to same value next turn |
| DoT (burning/poison flavor) | Takes X damage at end of each turn |
| Cloaked | Untargetable by single-target abilities |
| Rampaging | Deals double damage, cannot use defensive abilities |
| Counterspell | Next hostile ability targeting this unit is negated |

### Enemies
- Mirror the player's structure: portrait cards, dice rolls, ability ranges
- Each enemy has 5 abilities mapped to D20 ranges
- Enemy dice visible to player (telegraphed intent)
- Enemy does not use Protocol Bar

---

## 8. Progression Systems

### Within a Battle
- Protocol Bar charges
- Status effects accumulate
- Units die permanently for the battle (but resurrect next battle)

### Between Battles (Run-persistent)
- **Gear:** Equipment items placed on units. Modify stats or add passive abilities.
- **Consumables:** One-time use items (potions, grenades, etc.)
- **Relics:** Chosen at Battle 5. Run-wide passive modifiers. One relic per run.

### Reward Structure
After each battle, choose 1 of 3 rewards:
- Can be consumables (immediate use or saved)
- Can be gear (equip to a unit)
- After Battle 5: one guaranteed Relic choice instead

### Run Reset
Everything resets on: full wipe OR completion of Battle 10.

### Future: Player-Level Progression *(Out of scope for demo)*
- Persistent XP across runs
- Unlock new units, items, operations
- Not in current development scope

---

## 9. Operations

**5 operations** are defined in `data/raw/battle-modes.json`. Player picks one at run start. Each operation is **10 battles** (boss on fight 10), themed enemy faction, and a unique boss unit.

| ID | Theme | Boss (fight 10) |
|---|---|---|
| `facility` | Corporate drones, ECM, scrap | SCRAPMASTER |
| `hive` | Insectoid swarm | Hive Matriarch |
| `veil` | Harmonic / resonance | Conclave Overseer |
| `voidCirclet` | Cult casters | Circlet Hierophant |
| `stellarMenagerie` | Beasts | Void Reaver |

Enemy stats in Godot use flat `enemyUnitDefs` per fight. Balance-sim scaling keys are lab-only.

---

## 10. Reward Items (Design Notes)

### Gear
- Equips to a specific unit
- Persists until run ends
- Examples: +shield, +damage modifier, passive on roll 20, etc.

### Consumables
- One-time use during battle
- Examples: Heal a unit, modify a dice, apply a status

### Relics
- Run-wide passive
- Only one per run, chosen at Battle 5
- Examples: All units start with +2 protocol per turn, all 20s deal double damage, etc.

---

## 11. UI / UX Design Goals

- **Mobile first:** All interactions thumb-friendly. Large touch targets. Portrait (vertical) orientation, 1080×2400 internal, 450×1000 preview.
- **At-a-glance clarity:** Player should always know exactly what every die result will do.
- **Minimal menus:** Fewer screens, more battlefield.
- **Tactile feedback:** Dice roll animations, damage numbers floating, satisfying hit feedback.
- **Dark HUD aesthetic:** Inspired by sci-fi tactical interfaces, not card game pastels.

---

## 12. Out of Scope for Demo

- Player-level persistent XP and unlock system
- Overworld / node map between battles
- Multiplayer
- Story / narrative content
- Full audio implementation

---

## 13. Demo Success Criteria

A successful demo means:
- All 5 operations fully playable (10 battles each)
- All 8 units selectable with distinct mechanics
- Dice system fully functional with Protocol Bar
- Gear, consumable, and Relic reward loop working
- Clean, readable mobile UI
- Feels good to show friends
