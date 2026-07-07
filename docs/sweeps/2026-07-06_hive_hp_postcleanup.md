# Hive enemy-HP sweep — post-cleanup rerun (fixed L1 policy)

*Cleanup-batch step 7 (2026-07-06): rerun of the worked example against the
accepted post-repeat checkpoint, with the timer-contract corrections and the
L1 crit-banking heuristic in the tree. Measurement only. Supersedes the
pre-cleanup numbers in `2026-07-06_hive_hp_example.md` for planning purposes.*

**ANSWER (unchanged bracket, higher plateau): hive enters the 25-40% band at
enemy HP scalar ~= 0.75-0.78** (30.5% / 28.8%). The 0.70/0.72 plateau overshoots
harder than pre-cleanup (52.5% vs 45.8% — crit banking helps everywhere); 0.8
undershoots at 18.6%. Non-hive columns carry the crit-banking lift vs the
checkpoint (voidCirclet +10.5, facility +4.2) and are identical across points
(seed-matched controls).

Note: one worker failure occurred in the first refinement attempt and did NOT
reproduce on the identical seeds+tuning (300/300 clean twice after) — an
environmental process-spawn flake, not sim non-determinism; the determinism
matrix passed byte-identical the same hour.

---

## Coarse sweep (0.7 -> 1.0)

Policy **l1**, 300 runs/point, seed-base 900000 (seed-matched across points). Deltas vs `baseline.json` (overall 25.3%). `✦` = inside the **25–40% skilled-clear target band**.

| point | overall | facility | hive | veil | voidCirclet | stellarMenagerie |
|---|---|---|---|---|---|---|
| enemy_hp_scalar@hive=0.7 | 37.7% | 59.2% (+4.2) | 52.5% (+45.8) | 21.5% (-1.5) | 40.4% (+10.5) | 6.2% (+4.2) |
| enemy_hp_scalar@hive=0.8 | 31.0% | 59.2% (+4.2) | 18.6% (+11.9) | 21.5% (-1.5) | 40.4% (+10.5) | 6.2% (+4.2) |
| enemy_hp_scalar@hive=0.9 | 28.7% | 59.2% (+4.2) | 6.8% (+0.0) | 21.5% (-1.5) | 40.4% (+10.5) | 6.2% (+4.2) |
| enemy_hp_scalar@hive=1 | 28.7% | 59.2% (+4.2) | 6.8% (+0.0) | 21.5% (-1.5) | 40.4% (+10.5) | 6.2% (+4.2) |

## Per-hero clear rates

| point | avalanche | breaker | combat | engineer | ghost | medic | pulse | shield |
|---|---|---|---|---|---|---|---|---|
| enemy_hp_scalar@hive=0.7 | 29.8% | 38.3% | 44.4% | 38.7% | 48.4% | 32.4% | 37.4% | 29.9% |
| enemy_hp_scalar@hive=0.8 | 22.8% | 29.6% | 38.5% | 30.6% | 39.5% | 26.7% | 32.7% | 26.2% |
| enemy_hp_scalar@hive=0.9 | 22.8% | 27.0% | 34.2% | 28.8% | 35.5% | 24.8% | 31.8% | 23.4% |
| enemy_hp_scalar@hive=1 | 23.7% | 25.2% | 35.9% | 29.7% | 34.7% | 24.8% | 29.9% | 24.3% |

## Target-band summary

- **hive** never enters the 25–40% band across this sweep (enemy_hp_scalar@hive=0.7 → 52.5%, enemy_hp_scalar@hive=0.8 → 18.6%, enemy_hp_scalar@hive=0.9 → 6.8%, enemy_hp_scalar@hive=1 → 6.8%)

> Measurement only — no data or engine constants were changed. To SHIP a value,
> commit it as the real constant/data, then the baseline ceremony applies
> (docs/INVARIANTS.md #9).

---

## Refinement (0.72 -> 0.78)

Policy **l1**, 300 runs/point, seed-base 900000 (seed-matched across points). Deltas vs `baseline.json` (overall 25.3%). `✦` = inside the **25–40% skilled-clear target band**.

| point | overall | facility | hive | veil | voidCirclet | stellarMenagerie |
|---|---|---|---|---|---|---|
| enemy_hp_scalar@hive=0.72 | 37.7% | 59.2% (+4.2) | 52.5% (+45.8) | 21.5% (-1.5) | 40.4% (+10.5) | 6.2% (+4.2) |
| enemy_hp_scalar@hive=0.75 | 33.3% | 59.2% (+4.2) | 30.5% (+23.7) ✦ | 21.5% (-1.5) | 40.4% (+10.5) | 6.2% (+4.2) |
| enemy_hp_scalar@hive=0.78 | 33.0% | 59.2% (+4.2) | 28.8% (+22.0) ✦ | 21.5% (-1.5) | 40.4% (+10.5) | 6.2% (+4.2) |

## Per-hero clear rates

| point | avalanche | breaker | combat | engineer | ghost | medic | pulse | shield |
|---|---|---|---|---|---|---|---|---|
| enemy_hp_scalar@hive=0.72 | 28.1% | 38.3% | 44.4% | 39.6% | 48.4% | 32.4% | 38.3% | 29.9% |
| enemy_hp_scalar@hive=0.75 | 26.3% | 31.3% | 40.2% | 36.9% | 41.9% | 26.7% | 34.6% | 27.1% |
| enemy_hp_scalar@hive=0.78 | 24.6% | 31.3% | 37.6% | 33.3% | 41.1% | 29.5% | 35.5% | 29.9% |

## Target-band summary

- **hive** is inside the 25–40% band at: enemy_hp_scalar@hive=0.75, enemy_hp_scalar@hive=0.78

> Measurement only — no data or engine constants were changed. To SHIP a value,
> commit it as the real constant/data, then the baseline ceremony applies
> (docs/INVARIANTS.md #9).
