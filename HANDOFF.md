# Overload Protocol — handoff

2026-09-26. Repo `C:/Users/Kev/Documents/protocol`.
Read `docs/TRUTH.md`, `docs/INVARIANTS.md`, `docs/DECISIONS_RESOLVED.md`, then
`TASK_QUEUE.md` ("Open backlog (2026-09-26)"). Do not edit legacy Angular code.

## Current state

**Branch `dice-face-snap-p0`: G-24 is mid-implementation and stopped before
step 6 on a question for Kev.** Do not merge. `main` and `origin/main` are
unchanged (`2d06c9a`). Kev will test in Godot. No web export was made.

**Ruling G-24** (dice are real dice): static faces; the face that physically
lands up is the roll; one upright snap after settling; a face change only on a
deliberate change, shown as a tip-over. It supersedes Option C and the
2026-09-21 "RNG is authoritative for faces" follow-up. **G-23** (freeze locks
the number on the face) stands. Full story: `docs/audits/DICE_FACE_AUDIT.md`,
§6–11.

### Commits on the branch (oldest first)

| Commit | What |
|---|---|
| `26cde56` | P3 backlog rows, `dump_balance.gd.uid` |
| `9433f63` | Phase 1 audit and probes |
| `c6bdb6c` | One value source (`battle_scene._die_value`); hijack in the engine; `dice_landed()` — **kept** |
| `9313d79` | Option C presentation — **removed by `656692d`** |
| `ad4d633` | `dice face` gate (Option C version), card chip, landscape tag docking |
| `692386d` | Before/after capture script |
| `27729b6` | TASK_QUEUE P0 status |
| `c964167` | G-23 freeze locks the shown value, gate (d) — **kept** |
| `ba221e7` | Previous handoff, `.uid` files |
| `fa9fcb4` | G-24 step 1: ruling, TRUTH, INVARIANTS #1 |
| `e2c19be` | G-24 step 2: the landed face is the live raw; tutorial rig as before 1171eb8 |
| `8d73aba` | G-24 step 3: pending roll in the checkpoint; CONTINUE places the dice; checkpoint gate updated |
| `656692d` | G-24 step 4: Option C removed, upright snap restored |
| `1761c8b` | G-24 step 5: pre-roll modifiers printed on the faces |
| (this commit) | Audit §11 and this handoff |

## Waiting on Kev

1. **Step 6: unprintable values.** Printed faces can't show every value a
   deliberate change produces:
   - Set to 1–3 on a +3 die.
   - Nudge or Set past a jam cap.
   - Anything on an all-3 (rewrite) or all-20 (forced 20) die.
   - A hijack copy outside the enemy's printed range.
   - Deep Freeze Charge's pin to 1 on a buffed enemy.

   Options:
   - (a) Reprint the die's faces as part of the deliberate tip-over.
   - (b) Print only natural numbers and show modifiers another way. The landed
     face would then differ from the effective value, which conflicts with G-24.
   - (c) Something else.

   Until decided, deliberate changes use an instant turn to a face that prints
   the value. When none exists, the die keeps showing its old number, which
   breaks the rule that the die shows the value the unit acts on.
2. **Tutorial rig vs G-24.** The pre-1171eb8 rig Kev asked to keep turns the
   scripted face up after landing, so tutorial dice still visibly change face.
   G-24 has no tutorial exception. Keep it, or change it?
3. **Gate (c) threshold.** "The upright snap rotates less than 90°" can't hold:
   making a numeral read upright needs up to 180° of yaw. Probe, 280 dice:
   median 92°, 141 dice over 90°; the flattening tilt is at most 33°.
   Proposal: (c) = keeps the same top face and the flattening tilt < 90°, with
   yaw unbounded.
4. **G-23 open items**, carried over:
   - The round-end tick clears a frozen hijacker's hijack; nothing keeps it
     pending.
   - Buffed or Nudged 20s can freeze as 20, and the 20 riders then fire on
     every repeat.
   - The enemy AI's freeze pick and the sim's L1 banking read raw faces.
   - The engine's Nudge, Set and Reroll have no frozen guard of their own
     (the UI blocks them).
5. **Pre-existing:** the REWRITE marker above a die cycles its digits (pkg8.4
   feedback, not the die faces). Kev said "no scrambling digits anywhere".
   Remove it?

## Not done yet (after Kev answers)

- **Step 6:** the tip-over animation, about 0.25–0.35 s.
- **Step 7:** rewrite `dice face` for criteria (a)–(f), break each criterion
  once, and fix `battle layout`'s seeded-live-roll assertion.
- **Step 8:** full gate and balance sim.

**Gate state now:** `dice face` and `battle layout` fail (old assumptions,
step 7). Everything else passes `--skip-sim`. The sim has not been run since
G-24.

## Cautions

- Godot console: `C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe`.
- Don't run gates concurrently: gate startup kills headless Godot processes.
- Captures must run windowed.
- Live roll values exist only after landing. `battle_scene.dice_landed()` means
  the dice have landed. Tearing a battle down mid-roll crashes at exit.
- Headless 8× physics: raise `Engine.physics_ticks_per_second` and
  `Engine.time_scale` together (see `dice_face_gate.gd`).
