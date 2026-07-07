# Worked example — hive enemy HP scalar (balance workbench)

*The shipped worked example for `scripts/sim/sweep.py` (see scripts/sim/README.md).
Copied from `results/sweeps/` (gitignored) on 2026-07-06; reproduce with the
commands below — same seeds, byte-deterministic.*

```
python scripts/sim/sweep.py --name hive_hp_example --knob enemy_hp_scalar@hive --values 0.7,0.8,0.9,1.0 --runs 300
python scripts/sim/sweep.py --name hive_hp_refine  --knob enemy_hp_scalar@hive --values 0.72,0.75,0.78 --runs 300
```

**ANSWER: hive enters the 25-40%% skilled-clear band at enemy HP scalar ≈ 0.75-0.78**
(27.1%% / 25.4%%). Below that there is a cliff — 0.72 and 0.70 both read 45.8%%
(hits-to-kill breakpoints plateau under rounding), overshooting the band; 0.8
undershoots at 22.0%%. Context: measured on the post-freeze=repeat engine whose
baseline re-acceptance is still pending the ±10 ceremony, so the non-hive columns
carry the known regression deltas — they are seed-matched controls and identical
at every point, which is the workbench behaving correctly.

---

## Coarse sweep (0.7 → 1.0)


Policy **l1**, 300 runs/point, seed-base 900000 (seed-matched across points). Deltas vs `baseline.json` (overall 53.0%). `✦` = inside the **25–40% skilled-clear target band**.

| point | overall | facility | hive | veil | voidCirclet | stellarMenagerie |
|---|---|---|---|---|---|---|
| enemy_hp_scalar@hive=0.7 | 33.0% | 54.9% (-22.5) | 45.8% (+25.4) | 23.1% (-29.2) | 29.8% (-38.6) ✦ | 2.1% (-37.5) |
| enemy_hp_scalar@hive=0.8 | 28.3% | 54.9% (-22.5) | 22.0% (+1.7) | 23.1% (-29.2) | 29.8% (-38.6) ✦ | 2.1% (-37.5) |
| enemy_hp_scalar@hive=0.9 | 25.3% | 54.9% (-22.5) | 6.8% (-13.6) | 23.1% (-29.2) | 29.8% (-38.6) ✦ | 2.1% (-37.5) |
| enemy_hp_scalar@hive=1 | 25.3% | 54.9% (-22.5) | 6.8% (-13.6) | 23.1% (-29.2) | 29.8% (-38.6) ✦ | 2.1% (-37.5) |

## Per-hero clear rates

| point | avalanche | breaker | combat | engineer | ghost | medic | pulse | shield |
|---|---|---|---|---|---|---|---|---|
| enemy_hp_scalar@hive=0.7 | 16.7% | 40.9% | 40.2% | 37.8% | 41.9% | 28.6% | 30.8% | 25.2% |
| enemy_hp_scalar@hive=0.8 | 15.8% | 33.0% | 36.8% | 34.2% | 33.1% | 23.8% | 27.1% | 21.5% |
| enemy_hp_scalar@hive=0.9 | 13.2% | 30.4% | 31.6% | 28.8% | 29.8% | 22.9% | 26.2% | 18.7% |
| enemy_hp_scalar@hive=1 | 13.2% | 28.7% | 32.5% | 30.6% | 29.8% | 22.9% | 24.3% | 19.6% |

## Target-band summary

- **hive** never enters the 25–40% band across this sweep (enemy_hp_scalar@hive=0.7 → 45.8%, enemy_hp_scalar@hive=0.8 → 22.0%, enemy_hp_scalar@hive=0.9 → 6.8%, enemy_hp_scalar@hive=1 → 6.8%)

> Measurement only — no data or engine constants were changed. To SHIP a value,
> commit it as the real constant/data, then the baseline ceremony applies
> (docs/INVARIANTS.md #9).

---

## Refinement (0.72 → 0.78)


Policy **l1**, 300 runs/point, seed-base 900000 (seed-matched across points). Deltas vs `baseline.json` (overall 53.0%). `✦` = inside the **25–40% skilled-clear target band**.

| point | overall | facility | hive | veil | voidCirclet | stellarMenagerie |
|---|---|---|---|---|---|---|
| enemy_hp_scalar@hive=0.72 | 33.0% | 54.9% (-22.5) | 45.8% (+25.4) | 23.1% (-29.2) | 29.8% (-38.6) ✦ | 2.1% (-37.5) |
| enemy_hp_scalar@hive=0.75 | 29.3% | 54.9% (-22.5) | 27.1% (+6.8) ✦ | 23.1% (-29.2) | 29.8% (-38.6) ✦ | 2.1% (-37.5) |
| enemy_hp_scalar@hive=0.78 | 29.0% | 54.9% (-22.5) | 25.4% (+5.1) ✦ | 23.1% (-29.2) | 29.8% (-38.6) ✦ | 2.1% (-37.5) |

## Per-hero clear rates

| point | avalanche | breaker | combat | engineer | ghost | medic | pulse | shield |
|---|---|---|---|---|---|---|---|---|
| enemy_hp_scalar@hive=0.72 | 14.9% | 40.9% | 41.9% | 38.7% | 41.1% | 28.6% | 31.8% | 24.3% |
| enemy_hp_scalar@hive=0.75 | 15.8% | 33.9% | 36.8% | 36.0% | 35.5% | 24.8% | 29.0% | 21.5% |
| enemy_hp_scalar@hive=0.78 | 14.9% | 33.0% | 35.9% | 34.2% | 33.9% | 25.7% | 29.0% | 24.3% |

## Target-band summary

- **hive** is inside the 25–40% band at: enemy_hp_scalar@hive=0.75, enemy_hp_scalar@hive=0.78

> Measurement only — no data or engine constants were changed. To SHIP a value,
> commit it as the real constant/data, then the baseline ceremony applies
> (docs/INVARIANTS.md #9).
