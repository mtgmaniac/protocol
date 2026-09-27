# Overload Protocol — framing editor handoff

2026-09-27. Branch `framing-editor`, fast-forwarded into `main` and pushed.
Read `docs/TRUTH.md` ("Framing data"), `docs/tools/FRAMING_TOOL.md`, and then
`TASK_QUEUE.md` ("Framing pass (Kev)").

## What landed

- **One framing entry per asset, used on every screen.**
  `assets/portraits/portrait_anchors.json` moves to schema 2, with sections for
  heroes, enemies, bosses, items and relics plus per-class `_targets`. The
  per-portrait offsets that lived in code now live in the file as `legacy_*`
  fields: pulse_pyro's zoom, the breaker family's anchor-Y, and the Scrap and
  Rust Drone 5 px seat.
- **One helper per asset class.** Portraits keep `PixelUI.cover_fit_portrait`,
  which now reads the entry. `use_anchors` frames from head_top/chin/center_x
  as fractions of the frame. Items and relics go through the new
  `PixelUI.fit_item_art` (`make_item_art`, with `make_integer_icon` as the
  integer-law form). The hero 6 px seat is now one class rule; it used to be
  two copies, one in the battle card and one in the Squad Selector.
- **Sites routed through the helpers.** Help › Units thumbnails had a private
  cover-fit. The Starting Directive picker, the inventory (Item button), the
  inspect popup header and the inspect gear rows all used raw TextureRects.
- **Editor:** `dev/framing_editor/FramingEditor.tscn`, dev only. `dev/*` is now
  in both the Web and Android exclude filters. A real `--export-pack` of each
  preset lists 0 files under `dev/` (`scripts/checks/pck_list.py`).
- **Stray-pixel scan (detection only):** `scripts/assets/stray_pixel_scan.py`
  writes `dev/framing_editor/stray_scan.json`. It flags 61 of 152 assets:
  10 heroes, 17 enemies, 4 bosses, 22 items and 8 relics. Nanite Field
  suggests `left: 44`. Nothing is applied until Kev accepts a suggestion.
- **Gates:** `framing data`, `framing sites`, `framing editor` and
  `framing sheet`. The sheet is `debug_artifacts/framing/capture_sheet.png`.
- The offline `portrait_frame_crop.py` reads schema 2, and its destructive
  `apply` mode is retired (source images are never modified).

## Visible changes (intended)

With no new anchor data, captures were pixel-identical to the pre-task build.
The comparison covered squad select, encounter, a battle, a boss battle with
evolved Pyro and Breaker, relic, item, unit and enemy popups, the reward
screen, inventory and relic inspect, the Directive picker and run end. Two
sites changed on purpose, because they now share the framing of every other
screen:

- **Help › Units rows** use the shared cover-fit (hero zoom, pads and seat), so
  their thumbnails match the battle card. They are a little tighter than the
  old private fit.
- **Unlock screen and evolution hero portraits** get the 6 px hero seat that
  the battle card and Squad Selector already had.

## Not routed / open

- The parked landscape battle plate (`LANDSCAPE_BATTLE_ENABLED = false`) still
  shows native-aspect art. It is dead in production and already an open
  landscape question in TRUTH.
- The inventory (136), inspect header (84), gear row (64) and Directive (168)
  scaled item art by non-integer factors before this task, against the
  INVARIANTS integer-icon rule. They are kept pixel-identical. Switching one is
  a one-word mode change at its call.
- The Android preset excludes nothing but `dev/*`. Its pack is 422 MB with
  `debug_artifacts/`, `docs/` and `legacy-angular/` inside. This is flagged as
  a separate task.
- Kev's framing pass: review the stray flags, turn on anchor framing per
  asset, set the enemy and boss `_targets` (they start equal to the heroes'),
  and mark assets reviewed.

## Verification

- Full gate `python scripts/verify_gate.py --skip-sim`: every gate passed
  except `save resume` and `battle checkpoint`. Kev had a play session running,
  and it shares `dev_run.json` in the app-data dir ("--resume found no usable
  run save"). The pre-task code failed the same way under the same conditions.
  Re-run with an isolated app-data dir (`APPDATA=<scratch>`), both passed on the
  new code. Profile isolation passed.
- New gates: `framing data` (mutation-tested: unknown id, wrong section, chin
  above head, oversized/fractional insets, centre outside, unknown field,
  use_anchors without anchors, bad target, all caught), `framing sites`
  (catches all five pre-task violations in `git show 1bd0e4c`), `framing
  editor` (34 checks, including head fractions equal on all 5 hero sites) and
  `framing sheet` (25/25 site frames).
- Pixel identity: two baseline runs were deterministic. The only diffs were
  profile state and the run-end clock, neither of which is framing.

---

# Previous handoff — dice rework

2026-09-26. Branch `dice-face-snap-p0`; **do not merge or web-export**.
Kev reviews in Godot before a merge. Read `docs/TRUTH.md`, then
`docs/INVARIANTS.md`, `docs/DECISIONS_RESOLVED.md`, this file and `TASK_QUEUE.md`.

## Governing rulings

G-24: static printed faces; the physical live landing decides the raw roll;
the upright snap keeps the same top face. G-23 locks the shown effective value
while frozen. G-25 restores a plain 1–20 die on Set. G-26 scripts tutorial
tumbles directly onto the target face. G-27 permits reprints at deliberate
change start when the new value is absent. G-28 allows tilt flattening under
90 degrees and up to 180 degrees of yaw. G-29 removes cycling REWRITE digits.
G-30 keeps hijack pending throughout a freeze and resumes it after thaw.
All are recorded; **none is an open design question**.

## Completed commits

| Commit | Work |
|---|---|
| `fa9fcb4` | G-24 ruling and invariant update |
| `e2c19be` | Live raw roll comes from the physical landed face |
| `8d73aba` | Settled pending rolls survive refresh without a new throw |
| `656692d` | Option C removed; same-face upright snap restored |
| `1761c8b` | Pre-roll modifiers printed before throwing |
| `c912483` | G-25/G-26 recorded |
| `60f8caa` | Previous handoff; its step-6 starting point is now obsolete |
| `56fd173` | G-27–G-30 recorded |
| `e05e044` | Step 6: deliberate tip-overs and reprints |
| `d3068c3` | Step 7: tutorial scripted tumbles |
| `b8dcfeb` | Step 8: static REWRITE marker; hijack waits through freeze |
| `7deffe7` | Step 9: engine frozen guards; effective-value freeze pick/banking |
| `1cfa5e4` | Step 10: eight-criterion gate, mutation proof, layout fixture; fixes unchanged-value Set reprint and between-round frozen motion |
| `3cebf7b` | Optional frozen-20 rider telemetry, determinism check and balance report |

The inherited working tree was clean at `7deffe7`; no steps 1–9 were redone.
The replacement gate exposed two real presentation bugs, both fixed in step 10.
No authored ability/data numbers, baseline, or enforcement thresholds changed.
`battle_scene.gd` is back below the 3,640-line watermark.

## Verification

Detailed evidence: [DICE_REWORK_VERIFICATION_2026-09-26.md](docs/DICE_REWORK_VERIFICATION_2026-09-26.md).

- Starting fast gate: only obsolete `dice face` and seeded-live `battle layout` failed.
- Replacement dice gate: all eight criteria pass, including raw-face/label
  restoration, frozen poses, Set across five modifier states, and engine guards.
- Mutation proof: all eight deliberately broken criteria detected, no script errors.
- Battle layout: 1,177 checks, zero failures.
- Optional measurement off/on: 104 ordinary seeded records identical, excluding
  the shifted telemetry envelope counter. Counter fixture also passed.
- Full gate (including its pinned 300-run sim): exit 0, all hard gates and
  profile isolation pass. Overall clear 25.00% → 27.67%; every op within ±10 pp.
- Physics probe: eight rolls, zero penetration, flyover, frozen drift or tilt.
- Precision balance report: see closeout below.

## Remaining inventory / limits

No new exception to G-24 was required. Test in Godot before merging, including
visual motion, same-value Set, tutorial rolls, and frozen dice across rounds.
Physical phone review remains open. Automated transform/label checks do not
claim that animation feel or phone rendering has been visually approved.

Step 9 identified but did not change: L1's raw-based reroll heuristic and enemy
freeze-item target; unused `_current_raw_hero_rolls`; the explicit raw/effective
card debug text; and raw `last_die_value` as an unstamped freeze fallback.
Do not silently change sim policy while interpreting the balance comparison.

The historical pin contains 300 runs. A larger current sample makes current
per-operation estimates more precise, but cannot remove the pin's sampling
uncertainty or attribute every difference solely to this dice rework.

Godot: `C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe`.
Do not run gates concurrently: `verify_gate.py` terminates stale headless Godot
processes at startup. Restricted log access can crash Godot before it starts;
these verified runs used access to its normal log directory. Real player
profile isolation remains enforced.

## Closeout

**Steps 1–11 are complete.** All implementation and automated verification are
done; remaining work is Kev's visual review in Godot before any merge.

The precision batch completed 6,000 runs, zero failures, with 1,152–1,238 runs
per operation. Overall clear rate is 26.32% vs pinned 25.00%. Every operation
is within ±10 pp of the pin; current-rate 95% margins are below ±2.9 pp.

| Operation | Pinned | Current (6,000 runs) | Delta (pp) |
|---|---:|---:|---:|
| facility | 36.62% | 37.93% | +1.31 |
| hive | 22.03% | 24.30% | +2.27 |
| stellarMenagerie | 16.67% | 20.11% | +3.44 |
| veil | 24.62% | 22.61% | −2.01 |
| voidCirclet | 21.05% | 27.32% | +6.27 |

Frozen-20 counts: 5,553 hero repeats (14.71 / 1,000 combat rounds), 1,876 enemy
repeats; 403 Capacitor grants / 565 nominal Protocol, 179 echoes, 214 enemy
reinforcement requests. See [full balance report](docs/DICE_BALANCE_2026-09-27.md)
for per-operation counts, intervals and the matched 300-seed comparison.

The baseline remains unchanged; no merge or web export was performed. No new
design question or exception to G-24 was required. Earlier handoff blockers
are resolved, not work to restart.
