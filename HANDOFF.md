# Overload Protocol — current handoff

## 00. Merges, cleanup and two framing fixes (all on `main`, pushed)

2026-09-27.

**Merged into `main`:**
- `codex/dice-rules-containment` (section 0 below), fast-forward.
- `framing-pass` (Kev's framing pass, `portrait_anchors.json` only), merge
  commit, no conflicts. The merged file is byte-identical to `framing-pass`.
- Both local branches deleted with `git branch -d`; the spare worktree
  `..\protocol-framing` is removed. The remote branches are left in place.

**Framing editor test fixed after the merge.** Kev's pass anchored engineer
and patrol_elite and accepted Nanite Field's inset, so 7 of the 34 `framing
editor` checks lost the starting state they assumed. The byte-exact
round-trip still runs on the live file; the behaviour checks now load a
frozen fixture (`dev/framing_editor/framing_editor_fixture.json`, the
pre-pass data from `630f307`) copied to `user://`.

**Portrait backdrop.** `PixelUI.cover_fit_portrait` puts a solid black
frame-sized backdrop behind every portrait (internal `ColorRect`,
`show_behind_parent`). Wherever framing leaves the art short of its frame, the
gap is now black on every screen instead of the host frame's colour: the
brown strip above the Hive boss on the encounter panel, and the brown edges
on enemy battle cards. All live portrait art is opaque, so nothing else
changes. Before/after captures of squad select (Hive, Facility, Veil), the
Hive boss battle and a Facility battle: every changed pixel went black, and no
other pixel moved. No values in `portrait_anchors.json` changed.

**Static Field icon.** Static Field now uses Shield Array's art and framing
entry (`items/buckler_array`) through `DataManager.RELIC_ICON_SHARED_BY_ID`.
It no longer has its own relic row in the framing editor, so framing Shield
Array frames both. A probe confirmed both items resolve to the same entry, and
the inspect popups show the same icon.

**`project.godot`.** The uncommitted change was only the `config/icon` line
moving; Godot rewrites it on every launch (it came back after each capture
run). It was discarded each time and never committed.

**Verification:** after the merges: dice face, tutorial recorded throws (both
sizes), tutorial smoke and the four framing gates passed. After the fixes: the
four framing gates passed. Full gate `python scripts/verify_gate.py --skip-sim` with an isolated APPDATA: exit 0, all 64 hard gates pass, including save resume, battle checkpoint and profile isolation. The sim was skipped (combat and balance unchanged).

**Kev still needs to check in Godot (F5):**
- Tutorial scripted rounds: dice stay inside the tray and bounce off its
  walls, same as the free rounds.
- Reroll, Nudge and Set: pips hide while the die moves and come back after it
  lands.
- Portraits: framing looks right on squad select, battle cards, the
  encounter panel and the help menu, with black behind any zoomed-out art.
- Static Field shows the Shield Array icon.
- Still open from section 0: `battle_scene.gd` is 8 lines over its
  high-water mark (warning only), and web and phone output were not checked.

## 0. Dice rules follow-up (merged into `main` 2026-09-27)

2026-09-27. Two dice bugs are fixed, and the dice rules are now written down in
one place: TRUTH "Dice rules", with the new rulings G-31 and G-32. Merged into
`main` before Kev's visual check, at his request; he checks on `main`.

**Bug 1: tutorial recorded throws left the tray.** Cause: the recorder and its
gate ran headless, where the root window is 64×64. The "expand" stretch turns
that into a 2400×2400 visible rect, so the tray laid out 2360 px wide (walls
at x = ±10.5) instead of the phone's 1040 px (±4.63). All 64 recorded tracks
went outside the real tray, and 32 landed outside it before the upright snap
pulled them in. The gate compared the recorded bounds against the same wrong
headless tray, so it passed. Fix: the recorder forces 1080×2400, checks the
tray, and discards any throw where a die leaves it (0 of 24 needed
discarding). Frames are stored tray-normalised (format v2). Playback maps
them onto the live tray and only plays a variant that stays inside on every
frame; if none fits, the dice are thrown live. All scripted rounds were
re-recorded.

**Bug 2: ability pips rode a rerolled die.** Cause: die tags follow the die's
live screen position every frame, and on Reroll the readout keeps the old
roll until the new raw is committed after settling. Nudge, Set and hijack
tip-overs had the mirror problem: the new pips appeared before the die
reached its new face. Fix: `DiceTray3D` tracks per-die motion.
`value_displays_hidden()` hides the pip tag, the inspect hit-area and the
top-face highlight while the die moves. They also stay hidden until the face
the die rests on is the value the unit acts on.

**Also found by the new gate:** result slots were clamped to fixed constants,
not the live walls, so on a narrower tray a settled die could sit partly
off-screen. Slots are now clamped to the live tray.

**Gate:** `dice face` has two new criteria, checked on every drawn frame:
(i) the die stays inside the visible tray, landing included; (j) value
displays are hidden mid-motion and correct after settling. It also adds a
tutorial and live-scene part. It fails if any path is never exercised: live
throw (tray and scene), recorded playback, hero Reroll, enemy item reroll,
Nudge, Set, reprint and hijack. It runs at 1080×2400 and 540×1200, and so does
`tutorial recorded throws`. The mutation runner now covers a–j, and all 10 are
detected. With the hide rule disabled in production code, (j) fails with the
reported symptom.

**Verification:** full gate `python scripts/verify_gate.py --skip-sim`, with
an isolated APPDATA, exit 0: all hard gates pass, including dice face at both
sizes, tutorial recorded throws at both sizes, tutorial smoke, die reroll
visual, battle checkpoint, save resume and profile isolation. Tutorial throws
also pass at 720×1280 (a wider tray). Combat and balance are unchanged, so
the sim was skipped.

**Open:** Kev's visual check in Godot: scripted tutorial rounds stay in the
tray, and pips hide during Reroll, Nudge and Set. `battle_scene.gd` is 3648
lines against a high-water mark of 3640 (warning only; the mark is unchanged).
Web and phone rendering were not checked.

2026-09-27. `main` carries two finished pieces of work, each waiting on Kev's
visual review in Godot:

1. **Framing editor.** Branch `framing-editor`, fast-forwarded into `main`.
2. **Tutorial real rolls.** Branch `codex/tutorial-real-rolls`, merged into
   `main` on 2026-09-27.

The earlier dice rework, through `d5c25e1`, is approved and done. Its evidence
stays in `docs/DICE_REWORK_VERIFICATION_2026-09-26.md` and
`docs/DICE_BALANCE_2026-09-27.md`. Do not restart it.

Read `docs/TRUTH.md`, `docs/INVARIANTS.md`, `docs/DECISIONS_RESOLVED.md`, this
file and `TASK_QUEUE.md`. G-24 governs all dice. The revised G-26 specifies
recorded real throws for the three scripted tutorial rounds. All approved
rulings are closed.

## 1. Framing editor

Read TRUTH ("Framing data") and `docs/tools/FRAMING_TOOL.md`, then the
"Framing pass (Kev)" entry in `TASK_QUEUE.md`.

### What landed

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

### Visible changes (intended)

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

### Not routed / open

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

### Verification

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

## 2. Tutorial real rolls

### Outcome safety first

Actual BattleEngine simulations ran 1,000 seeds per battle under each of two
policies: 4,000 battles, zero losses and zero engine stalls. The same seeds
are paired across policies. Median/max victory rounds:

| Battle | Basic | L1 |
|---|---:|---:|
| 1 | 3 / 7 | 3 / 5 |
| 2 | 4.5 / 7 | 4 / 7 |

These are seeded engine simulations, not 4,000 UI playthroughs. SCRAP data and
the existing retry prompt remain unchanged. Full methods and raw results:
[TUTORIAL_OUTCOMES_2026-09-27.md](docs/TUTORIAL_OUTCOMES_2026-09-27.md).

### Completed work

| Commit | Step |
|---|---|
| `4ee386d` | 1: approved scripted/free schedule and rulings |
| `7d05a85` | 2: delete post-landing tutorial override; free later rounds |
| `4a72c7f` | 3: outcome simulation and results |
| `2ca0952` | 4: conditional Burn reminder and honest Reroll hint |
| `7d90891` | 5: real hero/enemy physics rerolls and checkpoint restoration |

Step 6 replaces generated tumbles with recorded live throws. Only battle 1
rounds 1–2 and battle 2 round 1 are scripted. The recorder uses the live
physics launch and tray; 24 throws produced 64 saved tracks and 128 measured
die trajectories. Four variants per slot share their selected variant across
the throw. Meshes are oriented before launch, labels stay static, the visible
top determines the result, and the normal same-face upright snap follows.

Hero Reroll, Phase Scrambler and Cascade Jammer physically rethrow affected
unfrozen dice. After settling, the checkpoint preserves pending raws, paid
costs, consumed items and other dice's Nudge/Set state. A fresh process restores
these dice without throwing again or duplicating roll-start effects.

The final integration also corrects the active-roll input guard so the first
Roll remains available, and keeps the engine's all-enemy reroll guard aligned
with frozen-repeat rules. Enemy rerolls clear their previous target before
recalculating intents, fixing attack-to-support target drift on refresh.

### Copy changes

1. YOUR PLAN appends “Watch Burn deal damage at the end of this turn.” only
   while an enemy is alive and burning when the beat appears. Its base text
   stays “Choose your targets and attack order. Spend Protocol if useful.”
2. REROLL: “You have 2 Protocol.” becomes “You have enough Protocol to reroll.”
   The remaining cost/action explanation is unchanged.

No other tutorial copy changed. See
[copy inventory](docs/TUTORIAL_ROLL_COPY_2026-09-27.md).

### Verification and remaining limits

**Implementation and automated verification are complete.** Full gate: exit 0,
all hard gates and profile isolation PASS, including real-input tutorial and
fresh-process reroll checkpoint restoration. The pinned 300-run comparison
has zero failed runs; overall clear is 25.00% to 27.67%, all operations within
the unchanged ±10-point limit. The physics probe passes eight throws with zero
penetrations, flyovers, frozen drift or tilted rests. Both deliberately broken
recorded-throw checks are detected. No baseline re-pin was performed.

The recorded-throw gate verifies the three scripted rounds' requested top
values, per-frame static labels, actual tutorial tray bounds, and per-slot
travel/time within measured live ranges. It also checks free physics launches
preserve the landed raw. Both deliberately broken criteria are detected.

Full measurements, exact commands and verification evidence:
[TUTORIAL_REAL_ROLLS_2026-09-27.md](docs/TUTORIAL_REAL_ROLLS_2026-09-27.md).
Old dice verification and 6,000-run balance evidence remain in
`docs/DICE_REWORK_VERIFICATION_2026-09-26.md` and
`docs/DICE_BALANCE_2026-09-27.md`; do not restart those tasks.

Kev's Godot visual review remains: throw feel, Reroll feel, sound timing,
tutorial transitions and refresh after Reroll. Physical-phone rendering and
web output are not visually verified. No web export was produced. The balance
baseline and enforcement thresholds have not changed.

Godot: `C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe`.
Run gates serially: `verify_gate.py` kills stale headless Godot processes at
startup. These runs used normal Godot log-directory access; restricted log
access can crash the executable before tests start. Profile isolation remains
enforced. Regenerate recordings when live launch, tray or physics settings
change, then rerun the motion gate and mutation proof.
