# Dice rework verification — 2026-09-26–27

## Scope and starting point

Resumed `dice-face-snap-p0` at `7deffe7`, after Claude's step 9. The tree was
clean and five commits ahead of the locally recorded origin. G-24 governs;
G-25–G-30 are recorded rulings. No merge, web export, authored balance edits,
baseline re-pin, or enforcement-threshold changes are part of this work.

The starting fast gate passed every check except the obsolete Option-C dice
contract and the battle-layout assertion expecting seeded live rolls. The
initial sandboxed attempt could not open Godot's user log and crashed before
tests; rerunning with log-directory access resolved that environment issue.
Player-profile isolation passed.

## Implementation and regressions

`1cfa5e4` replaces the dice gate with eight acceptance criteria:

- (a) The physically upward numeral equals the effective acted value.
- (b) Printed labels stay static, except a reprint at deliberate tumble start;
  the REWRITE marker also remains static.
- (c) Upright settling keeps the same physical top face, starts with tilt under
  90 degrees, finishes flat/upright, and travels no more than 180 degrees in yaw.
- (d) Pre-roll modifier ranges hold, including +3, penalties, jam, rewrite,
  forced 20 and Resonant Chorus.
- (e) Pending-roll placement restores the raw face and labels without throwing;
  the existing separate-process checkpoint gate additionally covers real reloads.
- (f) Frozen dice retain their full pose and shown value across later rolls;
  a pending hijack survives a frozen tick and resumes after thaw.
- (g) Set acts on exactly the chosen value and prints plain 1–20, including
  Set to the value already showing, across five modifier configurations.
- (h) Engine Nudge, Set and Reroll refuse frozen dice with unchanged rolls,
  Protocol, free-action flags and RNG, including the repeat-only freeze flag.

Coverage includes all 20 scripted faces in seven slots, unrigged physics
throws, live hijack, Sync Antenna, after-landing items, Nudge past a jam cap,
all-3/all-20 dice, and Deep Freeze on a buffed enemy. The layout fixture now
scripts physical landings explicitly and passes all 1,177 checks.

The new gate exposed and fixed two presentation bugs left after step 9:

1. Setting a modified die to its existing effective value skipped the reprint.
   The tray now checks the requested plain print as well as the changed value.
2. Between rounds, an absent effective roll fell back to the old raw face,
   starting a tip-over on modified/frozen dice. Live polling now waits for a
   revealed value instead. This removed the frozen-motion and label failures.

The scene's outdated comment was corrected and its delegate simplified, bringing
`battle_scene.gd` below the existing 3,640-line watermark. No threshold moved.
No additional design ruling or exception to G-24 was needed.

## Targeted results

- `dice_face_gate.gd`: all eight criteria pass; final targeted run counted
  a=6,834, b=18,854, c=33,901, d=142, e=8, f=890, g=210, h=12, zero failures.
  Per-frame counts vary with scheduling.
- `python scripts/checks/dice_face_mutations.py`: all eight injected violations
  detected; each run exits 1 and fails its corresponding criterion, with no
  script errors. Logs: `results/dice_contract/mutation_[a-h].log`.
- `battle_layout_test.gd`: 1,177 checks, zero failures.
- Optional rider-counter fixture: hero/enemy repeats, Capacitor Protocol,
  echoes and reinforcement requests counted correctly.
- `python scripts/checks/dice_metrics_check.py`: 104 ordinary seeded telemetry
  records identical with counters off/on, excluding the shifted envelope `t`.

## Full gate and balance

Full-gate log: `debug_artifacts/dice_final_gate.log`.
`python scripts/verify_gate.py` exited **0**: every hard gate passed, player
profile isolation passed, and the pinned 300-run balance simulation passed
with zero failed workers. Overall clear rate: **25.00% → 27.67% (+2.67 pp)**.

| Operation | Pinned baseline | Current 300 seeds | Delta (pp) |
|---|---:|---:|---:|
| facility | 36.62% | 40.85% | +4.23 |
| hive | 22.03% | 23.73% | +1.70 |
| stellarMenagerie | 16.67% | 22.92% | +6.25 |
| veil | 24.62% | 26.15% | +1.53 |
| voidCirclet | 21.05% | 21.05% | +0.00 |

Relative to the last 300-run observation in the previous handoff (28.00%
overall), this is −0.33 pp overall: facility +1.41, hive 0.00,
stellarMenagerie +2.09, veil 0.00, voidCirclet −5.27 pp. That observation was
not the pinned baseline. No baseline re-pin was performed.

The separate `DiceTrayPhysicsProbe.tscn` also passed: eight rolls, **zero
penetrations, flyovers, frozen displacement, tilted rests and corner tilts**.
Average settling time was 3.21 s, maximum 3.71 s. Its log is
`debug_artifacts/dice_physics_final.log`.

The precision batch uses 6,000 seeds, yielding 1,152–1,238 runs per operation
(worst-case 95% current-rate half-width below 2.9 pp). The first 300 seeds were
independently checked to match the full-gate wins/counts exactly in every
operation. The batch completed **6,000/6,000 runs in 816.2 seconds, zero failed**.
The report validated complete terminal results and one rider-counter record
per combat round before calculating rates.

Full table and machine-readable counts:
[DICE_BALANCE_2026-09-27.md](DICE_BALANCE_2026-09-27.md) and
[DICE_BALANCE_2026-09-27.json](DICE_BALANCE_2026-09-27.json).
Overall clear rate is **26.32%**, +1.32 pp against the historical pin. Current
operation rates are facility 37.93%, hive 24.30%, stellarMenagerie 20.11%,
veil 22.61%, voidCirclet 27.32%. Every current 95% interval has a margin below
±2.9 pp; every point-estimate delta against the pin remains within ±10 pp.

Frozen-20 observations: **5,553 hero repeats** (14.71 per 1,000 combat rounds)
and **1,876 enemy repeats**; **403 Capacitor grants / 565 nominal Protocol**,
**179 echoes**, and **214 successful enemy reinforcement requests**. These
measure observed frequency, not the causal balance lift of frozen-20 riders.

Reproduce the precision run and report:

```powershell
$env:PROTOCOL_DICE_METRICS='1'
python -u scripts/sim/batch.py --name dice_g24_20260927_6000 --runs 6000 --policy l1 --seed-base 900000 --workers 15
python scripts/sim/dice_balance_report.py results/dice_g24_20260927_6000 --out docs/DICE_BALANCE_2026-09-27.md
```

`3cebf7b` adds optional `PROTOCOL_DICE_METRICS=1` telemetry, its determinism check,
and `scripts/sim/dice_balance_report.py`. The counters observe resolved combat
logs, not speculative rolls. Ordinary telemetry remains unchanged by default.
The large batch uses the pinned L1/random squad/random operation sampling design
and seed base 900000; its first 300 seeds reproduce the CI comparison.

## Remaining raw readers and verification limits

Step 9's inventory remains unchanged: L1's reroll heuristic and enemy-freeze
item target still use raw values; `_current_raw_hero_rolls` is unused by the
corrected enemy freeze pick; the card's explicit raw/effective debug text and
unstamped freeze-capture fallback still read raw values. These are documented
carry-overs, not silent policy changes in this verification pass.

These are automated Godot checks. Kev's visual playtest in Godot and physical
phone review remain required before merging. No claim is made about the feel
of the animations or visual quality on a real phone. The historical baseline
contains only 300 total runs; a larger current sample tightens current-rate
intervals, not the historical pin's uncertainty or causal attribution of drift.
