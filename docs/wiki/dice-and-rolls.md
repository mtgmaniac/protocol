# Dice and Rolls

> Part of the [Overload Protocol wiki](INDEX.md). See also: [protocol-economy.md](protocol-economy.md), [targeting.md](targeting.md), [combat-resolution.md](combat-resolution.md), [keywords.md](keywords.md), [statuses-and-chips.md](statuses-and-chips.md).

## How it works

### The D20 and its five zones

Every living unit rolls one D20 at turn start; all dice roll simultaneously (`scripts/battle/battle_scene.gd:521` `_begin_targeting_phase`). The roll lands in one of five zones, each mapped to one authored ability: `recharge` (low) → `strike` → `surge` → `crit` → `overload` (the 20). Zone lookup is `DiceManager.get_ability_for_roll` (`scripts/battle/dice_manager.gd:10`), a simple min/max scan over the unit's `dice_ranges`.

Zone thresholds are **per-unit data**, not global constants:

| Unit | band 1 | band 2 | band 3 | band 4 | top |
|---|---|---|---|---|---|
| Pulse Tech (`pulse`) | 1–5 | 6–9 | 10–13 | 14–19 | 20 |
| ↳ Pyro Specialist | 1–6 | 7–9 | 10–12 | 13–18 | 19–20 |
| ↳ Arc Specialist | 1–3 | 4–8 | 9–14 | 15–19 | 20 |
| Strike Unit (`combat`) | 1–5 | 6–10 | 11–14 | 15–19 | 20 |
| ↳ Blade Trooper | 1–3 | 4–8 | 9–15 | 16–19 | 20 |
| ↳ Ravager | 1–7 | 8–9 | 10–11 | 12–19 | 20 |
| Spike Guard (`shield`) | 1–2 | 3–8 | 9–15 | 16–19 | 20 |
| ↳ Bulwark | 1–2 | 3–10 | 11–17 | 18–19 | 20 |
| ↳ Sentinel | 1–2 | 3–7 | 8–14 | 15–19 | 20 |
| Avalanche Suit (`avalanche`) | 1–3 | 4–9 | 10–14 | 15–19 | 20 |
| ↳ Glacier Rig | 1–3 | 4–11 | 12–16 | 17–19 | 20 |
| ↳ Trench Rig | 1–2 | 3–9 | 10–16 | 17–19 | 20 |
| Splice Medic (`medic`) | 1–4 | 5–9 | 10–14 | 15–19 | 20 |
| ↳ Combat Medic | 1–3 | 4–9 | 10–15 | 16–19 | 20 |
| ↳ Synth Medic | 1–3 | 4–8 | 9–13 | 14–19 | 20 |
| Field Engineer (`engineer`) | 1–4 | 5–10 | 11–14 | 15–19 | 20 |
| ↳ Overclock Engineer | 1–6 | 7–9 | 10–13 | 14–19 | 20 |
| ↳ Phantom Engineer | 1–3 | 4–10 | 11–15 | 16–19 | 20 |
| Ghost Operative (`ghost`) | 1–6 | 7–10 | 11–13 | 14–19 | 20 |
| ↳ Shadow Operative | 1–4 | 5–7 | 8–10 | 11–19 | 20 |
| ↳ Wraith | 1–6 | 7–10 | 11–14 | 15–18 | 19–20 |
| Signal Breaker (`breaker`) | 1–2 | 3–9 | 10–15 | 16–19 | 20 |
| ↳ Noise Specialist | 1–2 | 3–10 | 11–16 | 17–19 | 20 |
| ↳ Nullwire | 1–4 | 5–8 | 9–15 | 16–19 | 20 |

Ranges as of the 2026-10-08 roll windows (DECISIONS_RESOLVED G-53). Source: the `range` on each ability in `data/raw/heroes.data.json` (base kits and evolutions); `heroZones` at the top of that file is a copy of the base ranges, kept equal by the `roll windows` gate. **Enemy kits carry their own `range` per band** in `data/raw/enemies.data.json`: one shape per operation, adjusted by role (table in TRUTH, "Roll windows"). There is no shared enemy table. Only Pyro, Wraith and Spine Stalker have a top band wider than the 20 (19–20); roles are by kit (G-55).

### Runtime band shifts (heroes only)

`DiceManager.get_adjusted_ranges` (`scripts/battle/dice_manager.gd:30`) shifts band edges at resolve time without touching authored data:
- **Band Compressor** gear (`overloadBandCompress`): overload becomes 19–20, the band below ends at 18.
- **Wide Aperture** gear (`surgeBandExtend`): surge extends N lower.
- **Standing Order** relic (`critBandExtend`): every crit band extends 1 down.
- **Splice Deal** intercept (`splice_bands` in `GameState.hero_run_mods`): overload 19–20 + recharge widens 2.
- A shift never empties the band it takes from: that band always keeps one face, so a two-face band gives up one (Ravager's 8–9 under Wide Aperture gives one face, not two).

### Where the roll value comes from (determinism fence)

All roll values enter combat through the `RollProvider` seam (`scripts/sim/roll_provider.gd`, INVARIANTS #1):
- **Live game:** the battle's seeded d20 stream decides every face BEFORE the dice are thrown (`battle_scene._begin_targeting_phase`, same path as skip-visuals). `DiceTray3D` throws real rigid-body D20s with scrambling numerals and, on settle, places the unit's effective value (`battle_scene._die_value`) on whichever face landed up by turning only the face rig (Option C, `docs/audits/DICE_FACE_AUDIT.md`). The tray never decides a value.
- **Headless fallback / rerolls:** `PhysicsRollProvider` (`scripts/sim/physics_roll_provider.gd`) wraps `DiceManager.roll_d20()` = `randi_range(1, 20)` (`scripts/battle/dice_manager.gd:7`).
- **Balance sim:** `SeededRollProvider` (`scripts/sim/seeded_roll_provider.gd`) — per-run seeded stream, byte-reproducible.

Beyond the settled face, **no gameplay reads tray state**: `DiceTray3D`'s other public getters are screen positions/bounds/diameters for UI docking only. Freeze/Jam/Rewrite/Hijack all operate on roll VALUES in `combat_manager`/`BattleEngine`, never on physics. The four non-d20 random combat picks (Opening Salvo targets, Dead Man's Charge, elite-summon chance) now route through the provider seam via `combat_manager.roll_provider` (ruling NK-01, 2026-07-08), so the sim reproduces them from a seed without the old global-RNG workaround.

### The effective-roll pipeline

`BattleEngine.effective_hero_roll` (`scripts/battle/battle_engine.gd:453`) resolves in strict priority order:

1. **Frozen repeat** — if `die_freeze_repeat_this_round`, the crusted face (`frozen_die_value`) IS the result. Nothing else applies: no Set, no Nudge, no buffs, no jam, no rewrite.
2. **Set** — an absolute effective value (1–20) chosen by the player, overriding nudge and buffs.
3. Otherwise `combat_manager.get_effective_roll(raw)` **plus the player's Nudge**, clamped 1–20.

`combat_manager.get_effective_roll` (`scripts/battle/combat_manager.gd:535`) itself layers, in order:
1. **Rewrite pending** → the roll is SET to 3 (`REWRITE_VALUE`, :1305) — trumps every other modifier.
2. raw + roll-buff total − RFE total (summed independent instances + permanent mods), clamped 1–20.
3. **Jam cap** → `min(effective, jam_cap)` (default `JAM_CAP := 10`, :1304).

Nudge is deliberately NOT inside `get_effective_roll` — the scene/engine adds it on top, so Nudge can lift a jammed die's displayed result past the cap (jam caps the buffed raw, then +3 lands after). Enemies use the same pipeline minus Set/Nudge (`effective_enemy_roll`, `battle_engine.gd:468`).

**20-triggered effects key off the die's FINAL effective face** (ruling NK-02, 2026-07-08 — the "natural 20" concept was removed game-wide). A die Set, Nudged, or buffed to 20 fires the identical suite (Overload Loop double-resolve, Overload Capacitor Protocol, the 20s stat, elite summons, name-slam) as a rolled 20. There is no longer a raw-vs-shown split for these; `resolve_round` still carries a raw dict, but only the enemy-freeze "lowest revealed die" pick reads it — no 20-check does.

### Protocol dice actions (see [protocol-economy.md](protocol-economy.md) for costs)

- **Reroll (2 PP):** redraws the raw die via the provider and clears that hero's Nudge/Set (`battle_engine.gd:210`). Blocked on frozen dice (`protocol_actions.gd:85`).
- **Nudge (1 PP):** +3 to the effective roll, once per die per turn (`battle_engine.gd:231`). Reverse Gimbal gear: tap again to flip +3 ↔ −3, free (DECISIONS_RESOLVED #11). Priming Charge gear: holder's first Nudge each battle is free.
- **Set (3 PP):** forces an absolute effective roll via a slider popup; overrides any prior Nudge (`battle_engine.gd:254`, `protocol_actions.gd:452-664`). First Set free with Root Access boss relic.
- **Twin Fates (free, once/battle, relic):** copies one hero die's RAW result onto another, clearing the target's Nudge/Set (`battle_engine.gd:266`; two-tap flow `protocol_actions.gd:108-122`). Cannot overwrite a frozen die (`protocol_actions.gd:112`).

### Die-attack statuses: Jam, Rewrite, Hijack

All three are **die statuses, not chips** — they render on the die itself (tint/markers, `dice_tray_3d.gd:1767-1853`; wiring `battle_scene.gd:597` `_sync_die_status_visuals`).

- **Jam** (`_apply_jam`, `combat_manager.gd:1344`): next roll capped at `JAM_CAP` = 10. Re-jams keep the LOWER cap. Applied mid-round it survives the imminent tick and caps the next reveal; battle-start jams (Static Field relic, :391) cap the first roll directly. Wall of Static directive uses its own intentional cap 15 (:1169). Cleared at the round-end tick after it bites (`_tick_state`).
- **Rewrite** (`_apply_rewrite`, :1311): next roll SET to 3, telegraphed one round ahead (`rewrite_skip_next_tick`). SIGNAL HIERARCH's standing rule rewrites the squad's highest die every round via `apply_rewrite_to_state` (:1336).
- **Hijack** (enemy-only): the enemy's next roll copies the heroes' current highest die (`hijack_pending` set at :1682, consumed at resolve start :650-662). Skips one tick, fires at exactly one reveal.

**Mirror Plate** gear: when an **enemy** Jams, Rewrites, or Freezes a hero die, the holder gains +2 Protocol (`_grant_mirror_plate_protocol`). A friendly `freezeAnyDice` on an ally does NOT pay out (audit A-062, fixed 2026-07-08 — the freeze source is threaded so only enemy tampers grant).

### Freeze = repeat (DECISIONS_RESOLVED #1, final)

A frozen die crusts static in the tray at its current face — a real physics blocker other dice bounce off (`_prepare_frozen_die`, `dice_tray_3d.gd:1234`, collision left ON). Engine state:

- `_freeze_die_state` (`combat_manager.gd:2016`): adds `die_freeze_turns` (re-freezing stacks repeats), captures the current face into `frozen_die_value` (falls back to `last_die_value`).
- At each subsequent roll, `apply_frozen_roll_overrides` (`battle_engine.gd:513`) replaces the fresh roll with the locked face and `record_roll_values_for_states` (:529) stamps `die_freeze_repeat_this_round` — the unit **acts again on that same result: same zone, same ability**. Targeting is re-picked fresh each repeat.
- The repeat is spent at the round-end tick; at 0 the die thaws (`frozen_die_value` cleared, `combat_manager.gd:2406-2416`).
- **Immunities while frozen (FULL — ruling NK-03, 2026-07-08):** a frozen die can't be altered at all — Jam (:1347), Rewrite (:1314), Hijack (:656), **Nudge**, Reroll, Set, Twin-Fates, and item-rerolls all fizzle. The UI guards now check `die_freeze_turns > 0` (`protocol_actions.gd`), so the block holds from the moment of freezing, including the freeze round itself. Roll-relic overrides (forced 20s, Resonant Chorus floor) still skip frozen dice (`battle_scene.gd:1419`).
- **20-face riders under repeat (ruling NK-04):** a frozen 20 fires its riders (Overload Capacitor, the 20s stat, Overload Loop, the enemy elite-summon roll) **once, on the original resolution — not on each repeat**. The riders are gated on `not die_freeze_repeat_this_round`.
- **Enemy AI freeze** targets the hero's LOWEST revealed die — deterministic (`_freeze_pick_hero_lowest_die`, `combat_manager.gd:2033`): taunt overrides, cloaked heroes skipped, unrevealed dice count as 21, ties break to slot order.
- **Hero-side:** `freezeAnyDice` = one manual pick, EITHER side (freezing an ally repeats their good roll on purpose); freeze riders on damaging abilities stay enemy-side (`combat_manager.gd:1101-1125`). Deep Freeze directive adds +1 repeat. Firewall blocks hostile freeze picks; it never blocks a friendly `freezeAnyDice` pick.
- Cosmetic `freeze_flavor`: ice (cyan crust) / petrify (stone gray) — `dice_tray_3d.gd:1738`.

## Why it works that way

- The provider seam exists so the headless sim reproduces any battle byte-identically from a seed (INVARIANTS #1); a mechanic reading physical dice positions is forbidden by design.
- Freeze=repeat replaced two dead models (bank/thaw, then next-turn lockout) because "keeps its face; the unit acts again on it" fits one sentence (INVARIANTS #5; full lineage in DECISIONS_RESOLVED #1, landed `52e2fa5`).
- Jam cap 10 (was 12) clips the surge band without deleting crit fishing (DECISIONS_RESOLVED K4, commit `b219162`).
- The dice-suppression complexity budget is SPENT: jam/rewrite/hijack/freeze is the ceiling (INVARIANTS #4).
- Per-hero zone tables are the tuning surface for hero identity (wide crit = swingy control heroes); enemy kits share one table so enemy telegraphs are learnable.

## What it replaced

- Freeze lineage: fix-1.4 banked-face model → next-turn static lockout (`die_freeze_consumed_this_round`, item `skips`) → repeat (2026-07-06, `52e2fa5`). Both prior models purged from code, data, and tests.
- Jam cap 12 → 10 (keyword batch Task 5).
- Protocol spends lived inline in `battle_scene.gd`; extracted to `BattleEngine` (sim A.1, `c718d1a`) then the UI half to `ProtocolActions` (`a51e03b`).
- The dice were once a flat 2D readout; the 3D physics tray with hand-toss throws is the Jul 2026 physics overhaul.

## File locations

- `scripts/battle/dice_manager.gd` — zone lookup + runtime band shifts
- `scripts/battle/dice_tray_3d.gd` — 3D tray: physics roll, settle, face resolve, die-status visuals
- `scripts/battle/battle_engine.gd` — effective-roll pipeline, roll sourcing, frozen overrides, spend rules
- `scripts/battle/battle_state.gd` — roll/nudge/set dicts + protocol pool container
- `scripts/battle/protocol_actions.gd` — spend UI, pick sub-phases, legality guards
- `scripts/battle/combat_manager.gd` — `get_effective_roll`, jam/rewrite/hijack/freeze state
- `scripts/sim/roll_provider.gd`, `physics_roll_provider.gd`, `seeded_roll_provider.gd` — the determinism seam
- `data/raw/heroes.data.json` and `data/raw/enemies.data.json` (`range` per ability); gates `scripts/checks/roll_windows.py`, `scripts/debug/roll_windows_test.gd`

## Known edge cases

- A frozen 20's riders (Overload Capacitor, the 20s stat, Overload Loop, enemy elite-summon) fire **once, on the original resolution — not per repeat** (ruling NK-04, 2026-07-08). The riders are gated on `not die_freeze_repeat_this_round` in the resolve loop (`combat_manager.gd` hero loop) and the enemy summon path.
- A frozen die is **fully immune** — Nudge, Set, Reroll, Twin-Fates, Jam, Rewrite, and Hijack all bounce off from the moment it freezes (ruling NK-03, 2026-07-08). One clean rule: "a frozen die can't be altered."
- Reroll clears Nudge and Set; Set clears Nudge; Twin Fates clears the target's Nudge and Set.
- A jammed die that also gets Rewritten resolves as 3 (rewrite trumps jam).
- Hijack copies the heroes' current highest EFFECTIVE die (`resolve_step` hands `resolve_round` the effective hero rolls), including a frozen hero face; `BattleEngine.hijack_value` shows it live on the enemy die.
- `_freeze_pick_hero_lowest_die`: if every hero is cloaked/unrevealed, falls back to the first living uncloaked hero; ward on the picked hero blocks the freeze rider.
- The die shows the effective roll from the one source (`battle_scene._die_value`); the tray keeps no copy of the rule. Frozen dice show their crusted repeat value.
- Reroll animation (`reroll_die_to_result`) takes the provider's value and animates TO it — reroll randomness is software RNG, not physics, even in live play.

## ⚠ Open findings

<!-- AUDIT-LINKS:dice-and-rolls -->
- [A-008](../audit/INTERACTION_AUDIT.md#a-008) - [dead] curseDice - wired 5th die-tamper with zero data
- [A-009](../audit/INTERACTION_AUDIT.md#a-009) - [confusing] engine reroll/Set/Twin-Fates lack freeze guards (UI-only)
- [A-014](../audit/INTERACTION_AUDIT.md#a-014) - [confusing] Nudge prompt omits the Reverse Gimbal flip
- [A-015](../audit/INTERACTION_AUDIT.md#a-015) - [confusing] stale sim_runner comment on Overflow Vent RNG

Resolved (2026-07-08 fix pass): [A-010](../audit/INTERACTION_AUDIT.md#a-010), [A-011](../audit/INTERACTION_AUDIT.md#a-011), [A-012](../audit/INTERACTION_AUDIT.md#a-012), [A-013](../audit/INTERACTION_AUDIT.md#a-013)
