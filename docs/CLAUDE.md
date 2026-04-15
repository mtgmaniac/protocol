# CLAUDE.md — AI Assistant Context for Overload Protocol

This file tells AI assistants (Claude, Cursor, etc.) everything they need to know about this project to be maximally helpful. Read this before doing any work in this repo.

---

## What This Game Is

**Overload Protocol** is a dark sci-fi tactical dice roguelike built in Godot 4, targeting mobile in landscape orientation. The player commands a squad of 4 specialist units against 10 increasingly difficult battles of enemies, with a boss on Battle 10.

Full design details are in `docs/GDD.md`. Full implementation plan is in `docs/ROADMAP.md`.

---

## Engine and Language

- **Engine:** Godot 4.x
- **Language:** GDScript (not C#)
- **Platform target:** Mobile first (Android + iOS), landscape orientation
- **Secondary target:** HTML5 export for browser sharing

When writing code, always use GDScript unless specifically asked otherwise.

---

## Developer Context

- Solo developer, learning to code with AI assistance
- No prior Godot experience
- Prefers explanations alongside code (explain what a node does, why a pattern is used)
- AI is the primary interface for building this game

**Always explain what your code does and why in plain language. Treat the developer as a smart beginner.**

---

## Project Architecture

### Autoloads (Global Singletons)
These are always available from any script:

| Autoload | File | Purpose |
|---|---|---|
| `GameState` | `scripts/autoloads/GameState.gd` | Holds all run-persistent data (units, gear, relics, battle number) |
| `DataManager` | `scripts/autoloads/DataManager.gd` | Loads and serves all game data (units, items, enemies) |
| `SceneManager` | `scripts/autoloads/SceneManager.gd` | Handles scene transitions |

### Key Scenes

| Scene | File | Purpose |
|---|---|---|
| Main Menu | `scenes/ui/MainMenu.tscn` | Start screen |
| Unit Select | `scenes/ui/UnitSelect.tscn` | Pick 4 heroes before a run |
| Battle | `scenes/battle/BattleScene.tscn` | Core gameplay screen |
| Reward Screen | `scenes/ui/RewardScreen.tscn` | Post-battle item selection |
| Evolution Screen | `scenes/ui/EvolutionScreen.tscn` | Unit level-up branching choice |

### Key Scripts

| Script | Purpose |
|---|---|
| `scripts/battle/DiceManager.gd` | Rolls dice, maps results to abilities, handles manipulation |
| `scripts/battle/CombatManager.gd` | Resolves abilities, applies damage/healing/status effects |
| `scripts/battle/ProtocolBar.gd` | Manages the in-battle protocol resource |
| `scripts/units/UnitCard.gd` | Controls a unit portrait card node |

---

## Core Game Data Structures

### UnitData (Resource)
```gdscript
var id: String            # e.g. "strike_unit"
var display_name: String  # e.g. "Strike Unit"
var max_hp: int
var portrait: Texture2D
var dice_ranges: Array    # Array of {min, max, ability_name, ability_type, value, target}
var passives: Array       # Passive abilities (not dice-triggered)
var evolution_paths: Array # Two evolution options per level-up
```

### DiceRange entry
```gdscript
{
  "min": 16,
  "max": 19,
  "ability_name": "Heavy Strike",
  "ability_type": "damage",  # damage | shield | heal | aoe_damage | aoe_heal | special
  "value": 18,               # damage dealt, shield amount, heal amount, etc.
  "target": "single_enemy"   # single_enemy | all_enemies | single_ally | all_allies | self
}
```

### GameState run data
```gdscript
selected_units: Array     # Array of unit IDs chosen at start
current_battle: int       # 1–10
relics: Array             # Active relic IDs
consumables: Array        # Held consumable item IDs
gear_by_unit: Dictionary  # { unit_id: [item_id, item_id] }
```

---

## The 8 Player Units

| ID | Name | Role |
|---|---|---|
| `pulse_tech` | Pulse Tech | Protocol/utility — manipulates dice and protocol bar |
| `strike_unit` | Strike Unit | DPS — high single-target damage, pierce shields |
| `spite_guard` | Spite Guard | Tank/counter — heavy shields, counterattack |
| `avalanche_suit` | Avalanche Suit | AoE DPS — area attacks, rampage ability |
| `systems_medic` | Systems Medic | Healer — team heals, resurrection support |
| `field_engineer` | Field Engineer | Buffer — gear synergies, team passive buffs |
| `ghost_operative` | Ghost Operative | Burst — cloak, high-risk burst damage |
| `signal_breaker` | Signal Breaker | Debuffer — poison, counterspell, disruption |

---

## Combat Rules (Important for Logic)

1. All dice (player and enemy) are rolled simultaneously at the start of each turn
2. Player resolves their abilities first (in any order they choose)
3. Then surviving enemies resolve their abilities
4. End of turn: status effects tick, dice reset
5. A unit that dies mid-turn does NOT get to act (if it dies in player phase, it doesn't act in enemy phase either)
6. Shields are per-turn (expire at end of turn unless a specific ability says otherwise)
7. The Protocol Bar is a battle-only resource — it does NOT carry between battles
8. Frozen units must use the same dice result next turn (the die does not re-roll)

---

## Status Effects

| Effect | ID | Behaviour |
|---|---|---|
| Frozen | `frozen` | Die locked to same value next turn |
| Poisoned | `poisoned` | Takes X damage at end of each turn |
| Cloaked | `cloaked` | Cannot be targeted by single-target abilities |
| Rampaging | `rampaging` | Damage doubled, cannot use defensive abilities |
| Counterspell | `counterspell` | Next hostile ability targeting this unit is negated |

---

## UI / UX Rules

- **Mobile first always.** Touch targets minimum 44x44px.
- **Landscape orientation.** Do not build portrait layouts.
- **Player units on left half, enemies on right half** of battle screen (or bottom/top — confirm with Kev).
- **Everything readable at arm's length** on a phone screen.
- **Dark palette.** Background blacks/deep greys. Accent colours: biopunk green, warning red, metallic silver.
- **No cluttered menus.** The battlefield is the primary screen. Keep it clean.

---

## What's Out of Scope (Do Not Build Yet)

- Persistent player-level XP system across runs
- Overworld or node map between battles (Slay the Spire style)
- Full 5 operations (build 1 fully first)
- Multiplayer
- Story/narrative content
- Full audio mix

---

## Current Phase

Check `docs/ROADMAP.md` for the current phase checkpoint. Always work within the current phase unless explicitly asked to jump ahead.

---

## Coding Conventions

- Use `snake_case` for variables and functions (GDScript standard)
- Use `PascalCase` for class names and node names
- Every script file should have a comment at the top explaining what it does
- Emit signals for cross-node communication rather than direct references where possible
- Keep scenes self-contained — a UnitCard should work with any UnitData resource passed to it
- Prefer composition over inheritance where practical in Godot
