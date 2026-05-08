# Angular to Godot Mapping

This document now exists mostly as migration context, not as the primary source
of truth for the live game. The Godot project is already well past the
"placeholder shell" stage, but Angular is still useful when checking original
mechanics or older design intent.

Last refreshed on 2026-05-08.

## Status of the Migration

What is already real in Godot:

- portrait-oriented home / unit-select flow
- battle scene with hero and enemy cards
- 3D dice tray and resolved readouts
- protocol system in battle
- consumable/reward flow
- evolution flow
- themed UI assets and shared header

What Angular is still good for:

- original mechanic reference
- older effect semantics
- ability and item wording comparisons
- checking whether a rule was intentionally changed during the port

## High-Value System Map

| Angular source | Historical responsibility | Current Godot owner |
|---|---|---|
| `game-state.service.ts` | Run state, inventory, progression, overlays | `GameState.gd` plus scene-local controllers |
| `combat.service.ts` | Combat resolution, damage, healing, deaths | `combat_manager.gd` |
| `dice.service.ts` | D20 rolls, effective rolls, ability lookup | `dice_manager.gd` and `dice_tray_3d.gd` |
| `hero-state.service.ts` | Mutable hero runtime state | hero runtime dictionaries in `combat_manager.gd` |
| `enemy-state.service.ts` | Mutable enemy runtime state | enemy runtime dictionaries in `combat_manager.gd` |
| `protocol.service.ts` | Protocol rules | battle logic in `battle_scene.gd` and supporting combat logic |
| `targeting.service.ts` | Target selection rules | targeting flow in `battle_scene.gd` |
| `evolution.service.ts` | XP and branching upgrades | `GameState.gd` plus `evolution_screen.gd` |
| `item.service.ts` | Reward generation and item effects | `GameState.gd`, `reward_screen.gd`, and combat item helpers |
| battle component tree | Battlefield UI shell | `BattleScene.tscn` + `battle_scene.gd` |

## Important Current Differences

These older assumptions are no longer true:

- Angular landscape assumptions do not apply to the live Godot UI
- the live Godot battle uses compact runtime-built cards, not the old card scene
- the Godot project is no longer just "data first, shell later"

## When to Use Angular

Use Angular only when you need one of these:

1. confirm a mechanic’s original intended timing
2. check whether a raw effect key existed in the prototype
3. compare item/ability semantics after a Godot refactor

Do **not** use Angular as the visual source of truth for:

- current layout
- current phone sizing
- current header/footer structure
- current battle card ownership

## Current Best Migration Advice

If a future assistant needs to compare systems:

- trust the Godot repo first for what is live
- use Angular only to resolve historical ambiguity
- if Angular and Godot disagree, document the difference instead of silently
  "correcting" Godot back to Angular
