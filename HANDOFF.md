# Overload Protocol — handoff (for a cold pickup)

2026-09-26. Repo `C:/Users/Kev/Documents/protocol`, remote
`github.com/mtgmaniac/protocol`.
Read `docs/TRUTH.md`, `docs/INVARIANTS.md`, `docs/DECISIONS_RESOLVED.md`, then
`TASK_QUEUE.md` ("Open backlog (2026-09-26)"). Do not edit legacy Angular code.

## The task

**P0: dice.** Branch **`dice-face-snap-p0`**, pushed, **not merged**. `main` is
unchanged at `2d06c9a`. Kev tests in Godot before any merge. No web export.

**Governing ruling: G-24** (DECISIONS_RESOLVED, top). Dice are real dice:
- Faces are static; numbers never change or flash while a die tumbles.
- The face that physically lands up is the roll.
- After settling, the die rotates so its top face reads upright. This is the
  only automatic motion after landing.
- A die moves to a different face only on a deliberate change (Nudge, Set,
  reroll, hijack), shown as the die tipping over onto the new face.

**Also in force:**
- **G-23:** freeze locks the number on the face. A frozen die keeps exactly the
  effective value it showed when it froze, whatever happens to modifiers later.
- **G-25:** Set overrides modifiers. The engine already resolves Set that way;
  the presentation is not built yet.
- **G-26:** tutorial dice use a short scripted tumble straight onto the
  scripted face. Not built yet.
- The top "Dice face" entry, items 1, 2, 6, 7: one value source, the modifier
  classification, live hijack.

Background and evidence: `docs/audits/DICE_FACE_AUDIT.md` (§11 = G-24).

## Commits on the branch (oldest first)

| Commit | What | Status |
|---|---|---|
| `26cde56` | P3 backlog rows, `dump_balance.gd.uid` | kept |
| `9433f63` | Phase 1 audit and probes | kept |
| `c6bdb6c` | One value source: every die reads `battle_scene._die_value` (engine effective roll); hijack moved into the engine (`BattleEngine.hijack_value`), shown live; `dice_landed()` | kept |
| `9313d79` | Option C (scrambling digits, face-rig relabel) | removed by `656692d` |
| `ad4d633` | `dice face` gate (Option C version), card ±Roll chip reads a static `CombatManager.roll_modifier_totals_of`, parked landscape tag docking | gate needs a rewrite (step 7) |
| `692386d` | Windowed before/after capture script | kept |
| `27729b6` | TASK_QUEUE P0 status | kept |
| `c964167` | G-23: freeze captures the effective value; gate criterion (d) | kept |
| `ba221e7` | Earlier handoff, `.uid` files | — |
| `fa9fcb4` | **G-24 step 1:** ruling, TRUTH, INVARIANTS #1 reworded | done |
| `e2c19be` | **G-24 step 2:** live raw = landed face (`DiceTray3D.get_hero_rolls` / `get_enemy_rolls`); skip-visuals and the sim keep the seeded stream; tutorial rig restored as before 1171eb8 | done (tutorial superseded by G-26) |
| `8d73aba` | **G-24 step 3:** on settle, the ready-to-roll checkpoint is re-saved with the landed raws as a pending roll (`BattleCheckpoint.with_pending_roll`); CONTINUE places the dice (`DiceTray3D.place_rolls`) without throwing; `battle checkpoint` gate rewritten, passes | done |
| `656692d` | **G-24 step 4:** Option C removed (no FaceRig, no scramble); upright snap restored (`_start_upright_snap`), keeps the landed face; highlight follows the physical face up (`face_up` meta) | done |
| `1761c8b` | **G-24 step 5:** pre-roll modifiers printed on the faces before the throw (`BattleEngine.pre_roll_raw` / `pre_roll_face_value`, the scene's `face_values` entry, the tray's `_print_faces`) | done |
| `0b7add0` | Audit §11 and the previous handoff | — |
| `c912483` | G-25 and G-26 recorded, not implemented | — |
| (this commit) | This handoff | — |

**Step 4 status: finished** (`656692d`). Steps 1–5 are all committed, compile,
and pass their targeted tests. Work resumes at step 6.

## What's left

### Step 6: deliberate changes tip over (not started)

Replace the interim `DiceTray3D._show_value_in_place` (currently an instant turn
to a face printing the value) with a tip-over of about 0.25–0.35 s onto a face
that prints the new value, then the upright snap. Reroll keeps its animation.
Frozen dice never move (G-23).
- **Set (G-25):** clear the printed labels to plain 1–20 (`printed_values` meta
  → natural numbers; `_reset_face_labels` reads it), then a short tumble onto
  the chosen face. Labels stay static during the motion.
- **Still unresolved, ask Kev:** the other cases where no face prints the new
  value. Today the die keeps showing its old number, which breaks the rule
  that a die shows the value the unit acts on.
  - Nudge past a jam cap, or any Nudge on an all-3 (rewrite) or all-20
    (forced 20) die.
  - A hijack copy outside the enemy's printed range (hijack can't be printed
    before the roll).
  - After-landing roll-buff or penalty items that push past the printed range.
  - Deep Freeze Charge pinning a buffed enemy to 1.

  The G-25 pattern (clear the labels to plain 1–20, then tumble) is the obvious
  candidate. It is **not ruled**.

### Step 7: gate (rewrite `scripts/debug/dice_face_gate.gd`)

Criteria:
- (a) The locked top-face numeral always equals the effective value.
- (b) No face label changes while a die is in motion.
- (c) After settling, a die never lands on a different face.
- (d) A pre-roll +3 unit never shows 1–3.
- (e) A refresh after landing restores identical dice. Already proven in
  `scripts/checks/battle_checkpoint_gate.py`; reference it or fold it in.
- (f) The G-23 freeze checks stay.

Break each criterion once on purpose.
- **Conflict for (c):** Kev wrote "the upright snap rotates less than 90°". An
  upright read can need up to 180° of spin. Probe: median 92°, 141 of 280 dice
  over 90°; the flattening tilt is at most 33°. Proposed: same top face and
  tilt < 90°, spin unbounded. **Confirm with Kev.**
- **Old gate part A** feeds the tray synthetic values, which is obsolete under
  G-24: the landed face decides. Some old scenarios write `frozen_die_value`
  straight into state; capture it through `item_freeze_die` or
  `_freeze_die_state` instead.
- Fix `scripts/debug/battle_layout_test.gd`, which asserts seeded live hero
  rolls `{"combat":12,...}`. Live rolls are physics now: rig them through
  `dice_tray_3d.set_rigged_results` or drop the assertion.

### Step 8: full gate and balance sim

Run `python scripts/verify_gate.py`. Report the sim delta against the last
numbers: overall 0.2800; facility 0.3944, hive 0.2373, stellarMenagerie 0.2083,
veil 0.2615, voidCirclet 0.2632. **Do not re-pin the baseline.** Commit after
each step and update this file.

### G-26: tutorial

Replace the rig (set in `battle_scene._begin_targeting_phase`, applied in
`DiceTray3D._resolve_landed_die_face`) with a short scripted tumble that lands
on the scripted face. No turn after landing.

## Current gate state

`--skip-sim` passes except:
- `dice face`: still encodes Option C (step 7).
- `battle layout`: the seeded-live-roll assertion above.

The sim has not been run since G-24.

## Other open items for Kev (reported, not changed)

- **Hijack × freeze:** the round-end tick clears a frozen hijacker's hijack;
  nothing keeps it pending.
- **Frozen 20s:** a buffed or Nudged 20 can now freeze as 20, and the 20-face
  riders then fire on every repeat (G-8).
- **Raw vs shown values:** the enemy AI's freeze pick
  (`_freeze_pick_hero_lowest_die`) and the sim's L1 freeze banking read raw
  faces, while dice show effective values.
- **Frozen guard:** `BattleEngine.apply_nudge` / `apply_set` / `apply_reroll`
  have no frozen guard; the UI blocks them, and the sim's Nudge guard checks
  only the repeat flag.
- **REWRITE marker:** the marker above a die cycles its digits (pkg8.4). Kev
  said "no scrambling digits anywhere". Remove it?
- **Refresh mid-tumble:** a refresh while the dice are still tumbling throws
  again. Nothing had been shown, so this is accepted under G-24.

## Cautions

- Godot console: `C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe`.
- Don't run gates concurrently: gate startup kills headless Godot processes.
- Captures must run windowed (no `--headless`).
- Live roll values exist only after landing. `battle_scene.dice_landed()` means
  the dice have landed. Tearing a battle down mid-roll leaks coroutines and
  crashes at exit.
- Headless 8× physics: raise `Engine.physics_ticks_per_second` and
  `Engine.time_scale` together (see `dice_face_gate.gd`).
- Physics landings differ between processes. Tests comparing legs pin the
  landed values through `set_rigged_results` (see
  `battle_checkpoint_test.gd::_roll`).
