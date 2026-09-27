# G-24–G-30 balance verification

Batch: `dice_g24_20260927_6000`; L1, seed base 900000, random squads/operations, 6,000 completed runs. Baseline unchanged.

## Pinned 300-seed comparison

| Operation | Runs | Pinned clear | Current clear | Delta (pp) | Current 95% Wilson interval |
|---|---:|---:|---:|---:|---:|
| facility | 71 | 36.62% | 40.85% | +4.23 | 30.17%–52.46% |
| hive | 59 | 22.03% | 23.73% | +1.70 | 14.69%–35.98% |
| stellarMenagerie | 48 | 16.67% | 22.92% | +6.25 | 13.31%–36.54% |
| veil | 65 | 24.62% | 26.15% | +1.53 | 17.02%–37.95% |
| voidCirclet | 57 | 21.05% | 21.05% | +0.00 | 12.47%–33.29% |

Overall: 83/300 = 27.67%; pinned 25.00%; delta +2.67 pp.

## Larger current-rate estimate

| Operation | Runs | Pinned clear | Current clear | Delta (pp) | Current 95% Wilson interval |
|---|---:|---:|---:|---:|---:|
| facility | 1152 | 36.62% | 37.93% | +1.31 | 35.18%–40.77% |
| hive | 1210 | 22.03% | 24.30% | +2.27 | 21.96%–26.79% |
| stellarMenagerie | 1238 | 16.67% | 20.11% | +3.44 | 17.97%–22.44% |
| veil | 1203 | 24.62% | 22.61% | -2.01 | 20.34%–25.06% |
| voidCirclet | 1197 | 21.05% | 27.32% | +6.27 | 24.87%–29.91% |

Overall: 1579/6000 = 26.32%; pinned 25.00%; delta +1.32 pp.

The 300-seed table measures reproducible drift on the pinned sampling design. The larger table estimates current win rates; the historical pin has only 300 total runs, so its uncertainty remains and the larger table alone cannot establish a ±3-point causal change.

## Frozen-20 rider frequency

Counts below are **resolved frozen-20 turns**, not rolls that were frozen but never acted. Hero repeats each trigger the lifetime-20 rider once. Capacitor and echo counts require the corresponding equipment/relic; Protocol totals are emitted grants before cap/overflow. Enemy reinforcement counts are successful requests, not all eligible summon rolls.

| Operation | Combat rounds | Hero repeats | Runs with hero repeat | Enemy repeats | Capacitor triggers / Protocol | Echoes | Enemy reinforcements |
|---|---:|---:|---:|---:|---:|---:|---:|
| facility | 68350 | 733 | 334/1152 | 303 | 39 / 47 | 15 | 0 |
| hive | 71307 | 801 | 361/1210 | 365 | 69 / 108 | 41 | 0 |
| stellarMenagerie | 94949 | 1974 | 679/1238 | 369 | 169 / 243 | 74 | 25 |
| veil | 60801 | 617 | 322/1203 | 297 | 21 / 28 | 14 | 93 |
| voidCirclet | 82179 | 1428 | 417/1197 | 542 | 105 / 139 | 35 | 96 |

Total hero frozen-20 repeats: 5553 (14.71 per 1,000 combat rounds). Enemy repeats: 1876. Capacitor: 403 grants / 565 Protocol. Echoes: 179. Enemy reinforcement requests: 214.
