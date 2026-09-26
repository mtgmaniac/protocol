# Overload Protocol — handoff

2026-09-26. Repo `C:/Users/Kev/Documents/protocol`.
Read `docs/TRUTH.md`, `docs/INVARIANTS.md`, `docs/DECISIONS_RESOLVED.md`, then
`TASK_QUEUE.md` ("Open backlog (2026-09-26)"). Do not edit legacy Angular code.

## Current state

**Branch `dice-face-snap-p0` is waiting for Kev to test it in Godot. Do not
merge until he approves.** It was branched from `main` at `2d06c9a`. `main` and
`origin/main` are unchanged.

This branch fixes the P0 "a die lands on one face, then snaps to another".
- Full report: `docs/audits/DICE_FACE_AUDIT.md`.
- Rulings: the "Dice face" entry at the top of `DECISIONS_RESOLVED.md`, and
  **G-23 (freeze locks the number on the face)**.

| Commit | What |
|---|---|
| `26cde56` | Housekeeping: three P3 backlog rows, `dump_balance.gd.uid` |
| `9433f63` | Phase 1 audit report and probes (root cause: roll rigged before the throw, physics lands freely, tween rotates the rigged face up) |
| `c6bdb6c` | One value source: the tray's copy of the effective-roll rule is deleted; every die reads `battle_scene._die_value`; hijack moved into the engine and shows live; pre-roll overrides applied before the throw; `dice_landed()` |
| `9313d79` | Option C: digits scramble while the die tumbles, the value is placed on the face that landed up by turning only the face rig, digits lock, no rotation after settle |
| `ad4d633` | `dice face` hard gate (a/b/c), plus fixes the full gate surfaced (card roll chip, parked landscape tag docking) |
| `692386d` | Windowed before/after roll capture (`scripts/debug/dice_roll_capture.gd`) |
| `27729b6` | TASK_QUEUE P0 status |
| `c964167` | G-23: freeze locks the effective value it showed; gate criterion (d) |
| (this commit) | New scripts' `.uid` files and this handoff |

**Verification:**
- `python scripts/verify_gate.py`: all hard gates pass. `dice face` takes about
  36 s of its 90 s budget.
- Sim, 300 runs: overall 0.2800. Every operation is within ±10 of the baseline:
  facility +2.8, hive +1.7, stellarMenagerie +4.2, veil +1.5, voidCirclet +5.3.
  **The baseline was not re-pinned.**
- The before/after capture is in gitignored `debug_artifacts/dice_roll/`.
- Not yet checked on a phone (see TASK_QUEUE P2).

## Unresolved (for Kev)

These came from the G-23 interaction check. None conflicts with G-23; none was
changed.

1. **Hijack × freeze doesn't match the premise.** Nothing keeps a hijack pending
   while the enemy's die is frozen. The round-end tick clears `hijack_pending`
   after one reveal regardless of freeze, so a frozen hijacker loses its hijack.
   Rulings only say "frozen dice are immune to Hijack". Needs Kev to say which
   behaviour is intended.
2. **Frozen 20s are more reachable.** A buffed or Nudged value that reaches 20
   now freezes as 20. Under G-8, 20-face riders (Overload Loop echo, Overload
   Capacitor, the 20s stat, enemy elite-summon chance) fire on every frozen turn.
   It is consistent with NK-02 and G-8, but it is a real power increase for
   freeze-any-die "banking".
3. **The enemy AI freeze pick still reads raw faces.** It uses
   `_freeze_pick_hero_lowest_die` and `_current_raw_hero_rolls`, while dice now
   show effective values, so "lowest revealed die" may not be the lowest die the
   player sees.
4. **The sim policy reads raw values too.** The L1 policy's freeze banking
   (`_ally_bank_target`) picks allies by raw-roll band. Its Nudge guard checks
   only `die_freeze_repeat_this_round`, while the UI blocks Nudge, Set and Reroll
   on any frozen die. The engine's `apply_nudge`/`apply_set`/`apply_reroll` have
   no frozen guard of their own.
5. **Deep Freeze Charge** still pins to 1 (G-9). The die now shows 1 from the
   moment it is used. Before, in that round it acted on 1 plus modifiers.

## Cautions

- Godot console: `C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe`.
- Don't run gates concurrently: gate startup kills headless Godot processes.
- Captures must run windowed; a headless viewport renders nothing.
- Roll values now exist from the start of the throw. Use
  `battle_scene.dice_landed()` for "the dice have landed". Tearing a battle down
  mid-roll leaks coroutines and crashes at exit.
