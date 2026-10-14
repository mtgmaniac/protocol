# Per-battle loss rates, pre-traits game (sim)

Read-only analysis. Game state = first parent of the traits merge 404b2f0, i.e. `55f4ff3` ("Working rules; sim size break runs its real leg only on change (G-59)"), run from a scratch worktree. No game code or data touched.


## Highest loss-rate battles

**l1 (first evolutions)** — top 10 battles by loss rate (of runs that reached it):

| Rank | Operation | Battle | Loss rate | Reached | Fights |
|---|---|---|---|---|---|
| 1 | Mantle Hunt | 10 (boss) | 79.4% | 86.3% | 2589 |
| 2 | Signal Purge | 10 (boss) | 64.5% | 70.2% | 2105 |
| 3 | Hive | 10 (boss) | 57.5% | 70.2% | 2107 |
| 4 | Veil | 10 (boss) | 48.4% | 43.9% | 1316 |
| 5 | Facility | 10 (boss) | 39.1% | 56.6% | 1699 |
| 6 | Veil | 4 | 24.3% | 92.4% | 2772 |
| 7 | Facility | 5 | 22.5% | 80.7% | 2422 |
| 8 | Veil | 7 | 16.0% | 62.4% | 1871 |
| 9 | Facility | 4 | 15.0% | 94.9% | 2848 |
| 10 | Signal Purge | 5 | 14.5% | 90.7% | 2721 |

**l1_evo2 (second evolutions)** — top 10 battles by loss rate (of runs that reached it):

| Rank | Operation | Battle | Loss rate | Reached | Fights |
|---|---|---|---|---|---|
| 1 | Mantle Hunt | 10 (boss) | 79.1% | 86.2% | 2585 |
| 2 | Signal Purge | 10 (boss) | 69.5% | 68.2% | 2045 |
| 3 | Hive | 10 (boss) | 54.7% | 74.9% | 2248 |
| 4 | Veil | 10 (boss) | 39.7% | 42.7% | 1282 |
| 5 | Facility | 10 (boss) | 30.4% | 61.0% | 1830 |
| 6 | Veil | 4 | 23.8% | 92.4% | 2772 |
| 7 | Facility | 5 | 17.4% | 81.1% | 2433 |
| 8 | Veil | 7 | 16.9% | 63.7% | 1912 |
| 9 | Veil | 9 | 16.0% | 50.9% | 1527 |
| 10 | Signal Purge | 5 | 14.6% | 90.7% | 2722 |

## Variants far deadlier than their siblings

Criterion: ≥100 fights, loss rate ≥10 points above all other lineups in the same battle, z ≥ 3 (two-proportion).

| Policy | Operation | Battle | Lineup | Fights | Loss rate | Siblings' loss rate | Sibling fights |
|---|---|---|---|---|---|---|---|
| l1 | Facility | 4 | Patrol Enforcer + Volt Enforcer | 1348 | 26.0% | 5.0% | 1500 |
| l1 | Hive | 4 | Broodwarden + Skitterling | 685 | 15.3% | 4.7% | 2175 |
| l1 | Veil | 4 | Phaseblade + Phaseblade | 1358 | 42.6% | 6.6% | 1414 |
| l1 | Veil | 5 | Phaseblade + Phaseblade | 826 | 21.2% | 2.7% | 1273 |
| l1 | Signal Purge | 5 | Circuit Acolyte + False Image | 1752 | 19.9% | 4.7% | 969 |
| l1_evo2 | Facility | 4 | Patrol Enforcer + Volt Enforcer | 1348 | 25.0% | 5.2% | 1500 |
| l1_evo2 | Veil | 4 | Phaseblade + Phaseblade | 1358 | 41.9% | 6.5% | 1414 |
| l1_evo2 | Veil | 5 | Phaseblade + Phaseblade | 827 | 18.0% | 2.1% | 1284 |
| l1_evo2 | Veil | 9 | Aegis Anchor + Phaseblade + Shard Drone | 394 | 23.6% | 13.4% | 1133 |
| l1_evo2 | Signal Purge | 5 | Circuit Acolyte + False Image | 1753 | 20.5% | 4.0% | 969 |

## Facility — l1 (first evolutions)

3000 runs, 1034 cleared (34.5%), 1966 failed. Seeds 100000–102999.

| Battle | Reached | Fights | Loss rate | Share of all losses | Hero deaths (avg) | HP lost (% squad max) | Rounds med / p90 |
|---|---|---|---|---|---|---|---|
| 1 | 100.0% | 3000 | **0.0%** | 0.0% | 0.07 | 19% | 5 / 6 |
| 2 | 100.0% | 3000 | **0.0%** | 0.0% | 0.06 | 17% | 5 / 6 |
| 3 | 100.0% | 3000 | **5.1%** | 7.7% | 0.76 | 43% | 6 / 9 |
| 4 | 94.9% | 2848 | **15.0%** | 21.7% | 1.11 | 46% | 6 / 10 |
| 5 | 80.7% | 2422 | **22.5%** | 27.7% | 1.48 | 56% | 8 / 14 |
| 6 | 62.6% | 1877 | **0.9%** | 0.8% | 0.50 | 31% | 6 / 9 |
| 7 | 62.0% | 1861 | **0.1%** | 0.1% | 0.24 | 20% | 5 / 8 |
| 8 | 62.0% | 1860 | **1.3%** | 1.3% | 0.53 | 31% | 6 / 10 |
| 9 | 61.2% | 1835 | **7.4%** | 6.9% | 0.85 | 41% | 7 / 12 |
| 10 (boss) | 56.6% | 1699 | **39.1%** | 33.8% | 1.52 | 60% | 10 / 17 |

Lineup variants (Facility, l1):

| Battle | Lineup (as rolled) | Fights | Loss rate | Hero deaths | Rounds med |
|---|---|---|---|---|---|
| 2 | Scrap Drone + Static Skimmer | 915 | 0.0% | 0.05 | 4 |
| 2 | Rust Drone + Static Skimmer | 792 | 0.0% | 0.06 | 5 |
| 2 | Rust Drone + Rust Drone | 440 | 0.0% | 0.09 | 5 |
| 2 | Static Skimmer + Static Skimmer | 427 | 0.0% | 0.04 | 5 |
| 2 | Scrap Drone + Scrap Drone | 426 | 0.0% | 0.11 | 4 |
| 3 | Static Skimmer + Volt Enforcer | 489 | 0.6% | 0.53 | 6 |
| 3 | Patrol Enforcer + Rust Drone | 483 | 6.8% | 0.94 | 6 |
| 3 | Patrol Enforcer + Scrap Drone | 482 | 5.0% | 0.77 | 6 |
| 3 | Scrap Drone + Volt Enforcer | 468 | 1.9% | 0.54 | 6 |
| 3 | Patrol Enforcer + Static Skimmer | 453 | 3.1% | 0.81 | 6 |
| 3 | Rust Drone + Volt Enforcer | 450 | 1.3% | 0.55 | 6 |
| 3 | Patrol Enforcer + Volt Enforcer | 46 ⚠ low-sample | 32.6% | 1.72 | 8 |
| 3 | Volt Enforcer + Volt Enforcer | 22 ⚠ low-sample | 22.7% | 1.68 | 8 |
| 3 | Patrol Enforcer + Patrol Enforcer | 16 ⚠ low-sample | 31.2% | 1.94 | 6 |
| 3 | Patrol Enforcer + Rust Drone + Scrap Drone | 14 ⚠ low-sample | 71.4% | 2.43 | 8 |
| 3 | Scrap Drone + Static Skimmer + Volt Enforcer | 12 ⚠ low-sample | 41.7% | 2.00 | 8 |
| 3 | Patrol Enforcer + Rust Drone + Static Skimmer | 10 ⚠ low-sample | 70.0% | 2.40 | 8 |
| 3 | Rust Drone + Static Skimmer + Volt Enforcer | 10 ⚠ low-sample | 30.0% | 1.90 | 9 |
| 3 | Patrol Enforcer + Scrap Drone + Static Skimmer | 9 ⚠ low-sample | 11.1% | 1.22 | 7 |
| 3 | Rust Drone + Scrap Drone + Volt Enforcer | 9 ⚠ low-sample | 0.0% | 1.11 | 7 |
| 3 | Patrol Enforcer + Scrap Drone + Scrap Drone | 7 ⚠ low-sample | 85.7% | 2.86 | 9 |
| 3 | Patrol Enforcer + Static Skimmer + Static Skimmer | 5 ⚠ low-sample | 20.0% | 1.60 | 9 |
| 3 | Static Skimmer + Static Skimmer + Volt Enforcer | 5 ⚠ low-sample | 0.0% | 1.40 | 8 |
| 3 | Patrol Enforcer + Rust Drone + Rust Drone | 4 ⚠ low-sample | 50.0% | 2.50 | 8 |
| 3 | Rust Drone + Rust Drone + Volt Enforcer | 3 ⚠ low-sample | 66.7% | 2.33 | 11 |
| 3 | Scrap Drone + Scrap Drone + Volt Enforcer | 3 ⚠ low-sample | 33.3% | 1.33 | 11 |
| 4 | Heavy Warden | 1365 | 2.3% | 0.56 | 6 |
| 4 | Patrol Enforcer + Volt Enforcer | 1348 | 26.0% | 1.64 | 7 |
| 4 | Patrol Enforcer | 21 ⚠ low-sample | 0.0% | 0.05 | 3 |
| 4 | Patrol Enforcer + Rust Drone + Volt Enforcer | 20 ⚠ low-sample | 80.0% | 2.80 | 7 |
| 4 | Volt Enforcer | 19 ⚠ low-sample | 0.0% | 0.00 | 3 |
| 4 | Patrol Enforcer + Scrap Drone + Volt Enforcer | 18 ⚠ low-sample | 55.6% | 2.39 | 7 |
| 4 | Heavy Warden + Rust Drone | 16 ⚠ low-sample | 12.5% | 0.94 | 9 |
| 4 | Heavy Warden + Static Skimmer | 16 ⚠ low-sample | 12.5% | 1.12 | 7 |
| 4 | Patrol Enforcer + Static Skimmer + Volt Enforcer | 15 ⚠ low-sample | 86.7% | 2.80 | 8 |
| 4 | Heavy Warden + Scrap Drone | 10 ⚠ low-sample | 10.0% | 1.00 | 8 |
| 5 | Shield Enforcer + Shield Enforcer | 2273 | 20.9% | 1.44 | 8 |
| 5 | Shield Enforcer + Volt Enforcer | 36 ⚠ low-sample | 13.9% | 1.17 | 7 |
| 5 | Rust Drone + Shield Enforcer + Shield Enforcer | 32 ⚠ low-sample | 75.0% | 2.62 | 9 |
| 5 | Patrol Enforcer + Shield Enforcer | 31 ⚠ low-sample | 19.4% | 1.39 | 7 |
| 5 | Scrap Drone + Shield Enforcer + Shield Enforcer | 28 ⚠ low-sample | 78.6% | 2.57 | 9 |
| 5 | Shield Enforcer + Shield Enforcer + Static Skimmer | 22 ⚠ low-sample | 63.6% | 2.32 | 10 |
| 6 | Patrol Enforcer + Rust Drone + Scrap Drone | 234 | 1.7% | 0.56 | 6 |
| 6 | Scrap Drone + Static Skimmer + Volt Enforcer | 215 | 0.0% | 0.36 | 6 |
| 6 | Patrol Enforcer + Rust Drone + Static Skimmer | 207 | 1.4% | 0.57 | 6 |
| 6 | Rust Drone + Scrap Drone + Volt Enforcer | 205 | 0.0% | 0.45 | 6 |
| 6 | Patrol Enforcer + Scrap Drone + Static Skimmer | 203 | 0.5% | 0.50 | 6 |
| 6 | Rust Drone + Static Skimmer + Volt Enforcer | 182 | 0.5% | 0.48 | 6 |
| 6 | Static Skimmer + Static Skimmer + Volt Enforcer | 117 | 0.0% | 0.49 | 6 |
| 6 | Scrap Drone + Scrap Drone + Volt Enforcer | 112 | 1.8% | 0.45 | 6 |
| 6 | Patrol Enforcer + Rust Drone + Rust Drone | 108 | 2.8% | 0.60 | 6 |
| 6 | Patrol Enforcer + Scrap Drone + Scrap Drone | 104 | 1.9% | 0.54 | 5 |
| 6 | Rust Drone + Rust Drone + Volt Enforcer | 101 | 0.0% | 0.50 | 7 |
| 6 | Patrol Enforcer + Static Skimmer + Static Skimmer | 89 ⚠ low-sample | 0.0% | 0.54 | 6 |
| 7 | Heavy Warden + Static Skimmer | 598 | 0.2% | 0.23 | 5 |
| 7 | Heavy Warden + Rust Drone | 583 | 0.0% | 0.25 | 6 |
| 7 | Heavy Warden + Scrap Drone | 578 | 0.0% | 0.22 | 5 |
| 7 | Heavy Warden + Rust Drone + Static Skimmer | 18 ⚠ low-sample | 0.0% | 0.56 | 7 |
| 7 | Heavy Warden + Rust Drone + Scrap Drone | 15 ⚠ low-sample | 0.0% | 0.47 | 7 |
| 7 | Scrap Drone + Volt Enforcer | 9 ⚠ low-sample | 0.0% | 0.11 | 4 |
| 7 | Patrol Enforcer + Static Skimmer | 9 ⚠ low-sample | 0.0% | 0.22 | 4 |
| 7 | Heavy Warden + Scrap Drone + Static Skimmer | 9 ⚠ low-sample | 0.0% | 0.78 | 6 |
| 7 | Rust Drone + Volt Enforcer | 8 ⚠ low-sample | 0.0% | 0.00 | 4 |
| 7 | Static Skimmer + Volt Enforcer | 7 ⚠ low-sample | 0.0% | 0.00 | 4 |
| 7 | Patrol Enforcer + Scrap Drone | 7 ⚠ low-sample | 0.0% | 0.14 | 5 |
| 7 | Heavy Warden + Rust Drone + Rust Drone | 6 ⚠ low-sample | 0.0% | 0.33 | 8 |
| 7 | Heavy Warden + Scrap Drone + Scrap Drone | 6 ⚠ low-sample | 0.0% | 0.50 | 8 |
| 7 | Patrol Enforcer + Rust Drone | 5 ⚠ low-sample | 0.0% | 0.20 | 4 |
| 7 | Heavy Warden + Static Skimmer + Static Skimmer | 3 ⚠ low-sample | 0.0% | 0.33 | 8 |
| 8 | Heavy Warden + Patrol Enforcer | 875 | 1.1% | 0.54 | 6 |
| 8 | Heavy Warden + Volt Enforcer | 872 | 0.8% | 0.50 | 6 |
| 8 | Patrol Enforcer + Volt Enforcer | 30 ⚠ low-sample | 0.0% | 0.23 | 5 |
| 8 | Volt Enforcer + Volt Enforcer | 21 ⚠ low-sample | 0.0% | 0.14 | 6 |
| 8 | Patrol Enforcer + Patrol Enforcer | 15 ⚠ low-sample | 0.0% | 0.27 | 4 |
| 8 | Heavy Warden + Rust Drone + Volt Enforcer | 14 ⚠ low-sample | 28.6% | 1.36 | 8 |
| 8 | Heavy Warden + Patrol Enforcer + Rust Drone | 11 ⚠ low-sample | 0.0% | 0.82 | 9 |
| 8 | Heavy Warden + Scrap Drone + Volt Enforcer | 10 ⚠ low-sample | 0.0% | 1.50 | 9 |
| 8 | Heavy Warden + Patrol Enforcer + Scrap Drone | 6 ⚠ low-sample | 16.7% | 1.00 | 8 |
| 8 | Heavy Warden + Static Skimmer + Volt Enforcer | 4 ⚠ low-sample | 50.0% | 2.00 | 8 |
| 8 | Heavy Warden + Patrol Enforcer + Static Skimmer | 2 ⚠ low-sample | 50.0% | 2.00 | 10 |
| 9 | Patrol Enforcer + Rust Drone + Shield Enforcer | 314 | 9.6% | 0.92 | 7 |
| 9 | Rust Drone + Shield Enforcer + Volt Enforcer | 309 | 6.1% | 0.81 | 7 |
| 9 | Patrol Enforcer + Scrap Drone + Shield Enforcer | 303 | 9.9% | 0.97 | 7 |
| 9 | Shield Enforcer + Static Skimmer + Volt Enforcer | 294 | 5.1% | 0.81 | 7 |
| 9 | Scrap Drone + Shield Enforcer + Volt Enforcer | 290 | 5.5% | 0.72 | 7 |
| 9 | Patrol Enforcer + Shield Enforcer + Static Skimmer | 282 | 8.9% | 0.86 | 7 |
| 9 | Patrol Enforcer + Static Skimmer + Volt Enforcer | 11 ⚠ low-sample | 9.1% | 1.00 | 6 |
| 9 | Scrap Drone + Volt Enforcer + Volt Enforcer | 7 ⚠ low-sample | 0.0% | 0.29 | 5 |
| 9 | Patrol Enforcer + Rust Drone + Volt Enforcer | 6 ⚠ low-sample | 0.0% | 0.50 | 6 |
| 9 | Patrol Enforcer + Scrap Drone + Volt Enforcer | 4 ⚠ low-sample | 0.0% | 0.50 | 6 |
| 9 | Patrol Enforcer + Patrol Enforcer + Rust Drone | 4 ⚠ low-sample | 0.0% | 0.75 | 4 |
| 9 | Rust Drone + Volt Enforcer + Volt Enforcer | 3 ⚠ low-sample | 0.0% | 1.00 | 9 |
| 9 | Patrol Enforcer + Patrol Enforcer + Scrap Drone | 3 ⚠ low-sample | 0.0% | 0.33 | 5 |
| 9 | Patrol Enforcer + Patrol Enforcer + Static Skimmer | 3 ⚠ low-sample | 0.0% | 0.33 | 4 |
| 9 | Static Skimmer + Volt Enforcer + Volt Enforcer | 2 ⚠ low-sample | 0.0% | 0.00 | 6 |

## Hive — l1 (first evolutions)

3000 runs, 896 cleared (29.9%), 2104 failed. Seeds 100000–102999.

| Battle | Reached | Fights | Loss rate | Share of all losses | Hero deaths (avg) | HP lost (% squad max) | Rounds med / p90 |
|---|---|---|---|---|---|---|---|
| 1 | 100.0% | 3000 | **0.0%** | 0.0% | 0.00 | 5% | 2 / 3 |
| 2 | 100.0% | 3000 | **0.0%** | 0.0% | 0.02 | 12% | 3 / 5 |
| 3 | 100.0% | 2999 | **4.6%** | 6.6% | 0.61 | 38% | 5 / 8 |
| 4 | 95.3% | 2860 | **7.3%** | 9.9% | 0.77 | 36% | 7 / 13 |
| 5 | 88.4% | 2652 | **5.0%** | 6.3% | 0.58 | 29% | 5 / 10 |
| 6 | 84.0% | 2519 | **0.7%** | 0.9% | 0.39 | 25% | 5 / 8 |
| 7 | 83.4% | 2501 | **0.0%** | 0.0% | 0.03 | 9% | 4 / 7 |
| 8 | 83.3% | 2500 | **1.5%** | 1.8% | 0.27 | 23% | 6 / 10 |
| 9 | 82.1% | 2462 | **14.4%** | 16.9% | 0.93 | 45% | 8 / 15 |
| 10 (boss) | 70.2% | 2107 | **57.5%** | 57.6% | 2.07 | 72% | 12 / 20 |

Lineup variants (Hive, l1):

| Battle | Lineup (as rolled) | Fights | Loss rate | Hero deaths | Rounds med |
|---|---|---|---|---|---|
| 2 | Bloodmite + Skitterling | 1444 | 0.0% | 0.02 | 3 |
| 2 | Skitterling + Skitterling | 779 | 0.1% | 0.05 | 4 |
| 2 | Bloodmite + Bloodmite | 777 | 0.0% | 0.00 | 3 |
| 3 | Skitterling + Spine Stalker | 1435 | 4.1% | 0.64 | 5 |
| 3 | Bloodmite + Spine Stalker | 1400 | 2.7% | 0.46 | 5 |
| 3 | Spine Stalker + Spine Stalker | 92 ⚠ low-sample | 29.3% | 1.63 | 7 |
| 3 | Bloodmite + Bloodmite + Spine Stalker | 30 ⚠ low-sample | 16.7% | 1.20 | 7 |
| 3 | Bloodmite + Skitterling + Spine Stalker | 24 ⚠ low-sample | 20.8% | 1.54 | 6 |
| 3 | Skitterling + Skitterling + Spine Stalker | 18 ⚠ low-sample | 27.8% | 1.61 | 8 |
| 4 | Broodwarden + Skitterling | 685 | 15.3% | 1.11 | 8 |
| 4 | Bloodmite + Caustic Spewer | 680 | 1.3% | 0.46 | 6 |
| 4 | Caustic Spewer + Skitterling | 670 | 2.5% | 0.63 | 7 |
| 4 | Bloodmite + Broodwarden | 669 | 9.3% | 0.87 | 8 |
| 4 | Bloodmite + Spine Stalker | 43 ⚠ low-sample | 7.0% | 0.51 | 5 |
| 4 | Skitterling + Spine Stalker | 43 ⚠ low-sample | 0.0% | 0.56 | 5 |
| 4 | Bloodmite + Caustic Spewer + Skitterling | 24 ⚠ low-sample | 8.3% | 1.04 | 8 |
| 4 | Bloodmite + Broodwarden + Skitterling | 13 ⚠ low-sample | 38.5% | 1.69 | 11 |
| 4 | Caustic Spewer + Skitterling + Skitterling | 11 ⚠ low-sample | 18.2% | 1.36 | 9 |
| 4 | Bloodmite + Bloodmite + Broodwarden | 8 ⚠ low-sample | 37.5% | 1.75 | 9 |
| 4 | Bloodmite + Bloodmite + Caustic Spewer | 8 ⚠ low-sample | 0.0% | 0.88 | 6 |
| 4 | Broodwarden + Skitterling + Skitterling | 6 ⚠ low-sample | 0.0% | 1.00 | 8 |
| 5 | Spine Stalker + Spine Stalker | 1305 | 8.5% | 0.96 | 6 |
| 5 | Broodwarden | 623 | 0.6% | 0.22 | 5 |
| 5 | Caustic Spewer | 603 | 0.0% | 0.09 | 4 |
| 5 | Spine Stalker | 45 ⚠ low-sample | 0.0% | 0.00 | 3 |
| 5 | Bloodmite + Spine Stalker + Spine Stalker | 22 ⚠ low-sample | 27.3% | 1.59 | 8 |
| 5 | Skitterling + Spine Stalker + Spine Stalker | 20 ⚠ low-sample | 55.0% | 2.20 | 7 |
| 5 | Broodwarden + Skitterling | 13 ⚠ low-sample | 7.7% | 0.62 | 8 |
| 5 | Bloodmite + Caustic Spewer | 8 ⚠ low-sample | 0.0% | 0.12 | 6 |
| 5 | Bloodmite + Broodwarden | 8 ⚠ low-sample | 0.0% | 0.62 | 6 |
| 5 | Caustic Spewer + Skitterling | 5 ⚠ low-sample | 0.0% | 0.40 | 6 |
| 6 | Bloodmite + Skitterling + Spine Stalker | 1272 | 0.5% | 0.40 | 5 |
| 6 | Bloodmite + Bloodmite + Spine Stalker | 629 | 0.2% | 0.30 | 5 |
| 6 | Skitterling + Skitterling + Spine Stalker | 618 | 1.8% | 0.47 | 5 |
| 7 | Broodwarden | 2347 | 0.0% | 0.03 | 4 |
| 7 | Spine Stalker | 75 ⚠ low-sample | 0.0% | 0.00 | 2 |
| 7 | Broodwarden + Skitterling | 43 ⚠ low-sample | 0.0% | 0.14 | 5 |
| 7 | Bloodmite + Broodwarden | 36 ⚠ low-sample | 0.0% | 0.28 | 6 |
| 8 | Caustic Spewer + Spine Stalker | 1197 | 0.3% | 0.17 | 5 |
| 8 | Broodwarden + Spine Stalker | 1168 | 2.2% | 0.34 | 6 |
| 8 | Spine Stalker + Spine Stalker | 62 ⚠ low-sample | 0.0% | 0.13 | 4 |
| 8 | Bloodmite + Broodwarden + Spine Stalker | 25 ⚠ low-sample | 12.0% | 0.88 | 7 |
| 8 | Caustic Spewer + Skitterling + Spine Stalker | 18 ⚠ low-sample | 5.6% | 0.67 | 7 |
| 8 | Bloodmite + Caustic Spewer + Spine Stalker | 16 ⚠ low-sample | 0.0% | 0.69 | 7 |
| 8 | Broodwarden + Skitterling + Spine Stalker | 14 ⚠ low-sample | 28.6% | 1.29 | 9 |
| 9 | Carapace Beetle + Skitterling + Spine Stalker | 1217 | 15.9% | 1.01 | 8 |
| 9 | Bloodmite + Carapace Beetle + Spine Stalker | 1181 | 13.5% | 0.88 | 8 |
| 9 | Bloodmite + Spine Stalker + Spine Stalker | 39 ⚠ low-sample | 2.6% | 0.41 | 5 |
| 9 | Skitterling + Spine Stalker + Spine Stalker | 25 ⚠ low-sample | 4.0% | 0.44 | 5 |

## Veil — l1 (first evolutions)

3000 runs, 676 cleared (22.5%), 2321 failed. Seeds 100000–102999.

| Battle | Reached | Fights | Loss rate | Share of all losses | Hero deaths (avg) | HP lost (% squad max) | Rounds med / p90 |
|---|---|---|---|---|---|---|---|
| 1 | 100.0% | 3000 | **0.0%** | 0.0% | 0.05 | 17% | 4 / 5 |
| 2 | 100.0% | 3000 | **0.0%** | 0.0% | 0.06 | 17% | 4 / 5 |
| 3 | 100.0% | 2999 | **7.6%** | 9.8% | 0.72 | 42% | 6 / 10 |
| 4 | 92.4% | 2772 | **24.3%** | 29.0% | 1.23 | 49% | 6 / 11 |
| 5 | 70.0% | 2099 | **10.0%** | 9.0% | 0.72 | 33% | 6 / 10 |
| 6 | 63.0% | 1890 | **1.0%** | 0.8% | 0.35 | 28% | 6 / 9 |
| 7 | 62.4% | 1871 | **16.0%** | 12.9% | 0.89 | 42% | 7 / 14 |
| 8 | 52.4% | 1571 | **4.4%** | 3.0% | 0.60 | 31% | 6 / 11 |
| 9 | 50.1% | 1502 | **12.4%** | 8.0% | 0.92 | 43% | 7 / 12 |
| 10 (boss) | 43.9% | 1316 | **48.4%** | 27.4% | 2.05 | 74% | 10 / 15 |

Lineup variants (Veil, l1):

| Battle | Lineup (as rolled) | Fights | Loss rate | Hero deaths | Rounds med |
|---|---|---|---|---|---|
| 2 | Shard Drone + Shard Drone | 1508 | 0.0% | 0.03 | 4 |
| 2 | Prism Charger + Prism Charger | 1492 | 0.1% | 0.08 | 4 |
| 3 | Phaseblade + Shard Drone | 1415 | 5.6% | 0.63 | 6 |
| 3 | Phaseblade + Prism Charger | 1405 | 5.7% | 0.67 | 6 |
| 3 | Phaseblade + Phaseblade | 77 ⚠ low-sample | 45.5% | 2.06 | 8 |
| 3 | Phaseblade + Prism Charger + Shard Drone | 49 ⚠ low-sample | 28.6% | 1.57 | 8 |
| 3 | Phaseblade + Prism Charger + Prism Charger | 29 ⚠ low-sample | 37.9% | 1.72 | 7 |
| 3 | Phaseblade + Shard Drone + Shard Drone | 24 ⚠ low-sample | 33.3% | 1.67 | 7 |
| 4 | Phaseblade + Phaseblade | 1358 | 42.6% | 1.93 | 8 |
| 4 | Resonance Warden | 671 | 5.5% | 0.64 | 6 |
| 4 | Stormweaver | 607 | 1.2% | 0.27 | 5 |
| 4 | Phaseblade | 41 ⚠ low-sample | 0.0% | 0.20 | 4 |
| 4 | Phaseblade + Phaseblade + Prism Charger | 27 ⚠ low-sample | 74.1% | 2.63 | 7 |
| 4 | Phaseblade + Phaseblade + Shard Drone | 26 ⚠ low-sample | 80.8% | 2.62 | 8 |
| 4 | Prism Charger + Stormweaver | 13 ⚠ low-sample | 7.7% | 0.54 | 7 |
| 4 | Shard Drone + Stormweaver | 12 ⚠ low-sample | 0.0% | 0.67 | 6 |
| 4 | Prism Charger + Resonance Warden | 9 ⚠ low-sample | 44.4% | 1.67 | 7 |
| 4 | Resonance Warden + Shard Drone | 8 ⚠ low-sample | 50.0% | 1.75 | 9 |
| 5 | Phaseblade + Phaseblade | 826 | 21.2% | 1.34 | 7 |
| 5 | Resonance Warden | 603 | 2.7% | 0.40 | 5 |
| 5 | Stormweaver | 590 | 0.5% | 0.15 | 4 |
| 5 | Phaseblade | 31 ⚠ low-sample | 0.0% | 0.06 | 3 |
| 5 | Phaseblade + Phaseblade + Shard Drone | 13 ⚠ low-sample | 61.5% | 2.38 | 10 |
| 5 | Phaseblade + Phaseblade + Prism Charger | 13 ⚠ low-sample | 53.8% | 2.31 | 9 |
| 5 | Resonance Warden + Shard Drone | 7 ⚠ low-sample | 0.0% | 0.71 | 7 |
| 5 | Prism Charger + Stormweaver | 6 ⚠ low-sample | 0.0% | 0.50 | 5 |
| 5 | Prism Charger + Resonance Warden | 5 ⚠ low-sample | 0.0% | 0.80 | 6 |
| 5 | Shard Drone + Stormweaver | 5 ⚠ low-sample | 0.0% | 0.80 | 7 |
| 6 | Phaseblade + Prism Charger + Shard Drone | 958 | 1.0% | 0.34 | 6 |
| 6 | Phaseblade + Shard Drone + Shard Drone | 480 | 0.4% | 0.33 | 5 |
| 6 | Phaseblade + Prism Charger + Prism Charger | 452 | 1.5% | 0.39 | 6 |
| 7 | Aegis Anchor + Aegis Anchor | 1791 | 15.9% | 0.89 | 7 |
| 7 | Aegis Anchor + Phaseblade | 44 ⚠ low-sample | 4.5% | 0.41 | 6 |
| 7 | Aegis Anchor + Aegis Anchor + Prism Charger | 19 ⚠ low-sample | 36.8% | 1.74 | 9 |
| 7 | Aegis Anchor + Aegis Anchor + Shard Drone | 17 ⚠ low-sample | 35.3% | 1.53 | 10 |
| 8 | Phaseblade + Resonance Warden | 739 | 6.8% | 0.75 | 7 |
| 8 | Phaseblade + Stormweaver | 733 | 1.6% | 0.42 | 6 |
| 8 | Phaseblade + Phaseblade | 47 ⚠ low-sample | 2.1% | 0.43 | 5 |
| 8 | Phaseblade + Prism Charger + Resonance Warden | 16 ⚠ low-sample | 18.8% | 1.56 | 10 |
| 8 | Phaseblade + Prism Charger + Stormweaver | 15 ⚠ low-sample | 13.3% | 0.87 | 7 |
| 8 | Phaseblade + Shard Drone + Stormweaver | 13 ⚠ low-sample | 0.0% | 0.62 | 6 |
| 8 | Phaseblade + Resonance Warden + Shard Drone | 8 ⚠ low-sample | 12.5% | 1.25 | 8 |
| 9 | Aegis Anchor + Phaseblade + Shard Drone | 371 | 14.0% | 1.01 | 7 |
| 9 | Phaseblade + Relay Herald + Shard Drone | 366 | 9.0% | 0.77 | 7 |
| 9 | Aegis Anchor + Phaseblade + Prism Charger | 362 | 18.0% | 1.09 | 7 |
| 9 | Phaseblade + Prism Charger + Relay Herald | 356 | 9.8% | 0.85 | 7 |
| 9 | Phaseblade + Phaseblade + Shard Drone | 27 ⚠ low-sample | 0.0% | 0.52 | 7 |
| 9 | Phaseblade + Phaseblade + Prism Charger | 20 ⚠ low-sample | 5.0% | 0.85 | 8 |

## Signal Purge — l1 (first evolutions)

3000 runs, 740 cleared (24.7%), 2252 failed. Seeds 100000–102999.

| Battle | Reached | Fights | Loss rate | Share of all losses | Hero deaths (avg) | HP lost (% squad max) | Rounds med / p90 |
|---|---|---|---|---|---|---|---|
| 1 | 100.0% | 3000 | **0.8%** | 1.1% | 0.49 | 34% | 6 / 9 |
| 2 | 99.2% | 2975 | **0.0%** | 0.0% | 0.05 | 13% | 4 / 6 |
| 3 | 99.2% | 2975 | **6.6%** | 8.7% | 0.76 | 43% | 7 / 11 |
| 4 | 92.7% | 2780 | **2.1%** | 2.6% | 0.44 | 26% | 6 / 9 |
| 5 | 90.7% | 2721 | **14.5%** | 17.5% | 0.96 | 45% | 6 / 11 |
| 6 | 77.5% | 2326 | **2.6%** | 2.7% | 0.54 | 32% | 6 / 11 |
| 7 | 75.5% | 2265 | **0.0%** | 0.0% | 0.19 | 17% | 6 / 8 |
| 8 | 75.5% | 2265 | **1.8%** | 1.8% | 0.38 | 31% | 7 / 11 |
| 9 | 74.1% | 2224 | **5.4%** | 5.3% | 0.63 | 38% | 7 / 13 |
| 10 (boss) | 70.2% | 2105 | **64.5%** | 60.3% | 2.33 | 82% | 12 / 18 |

Lineup variants (Signal Purge, l1):

| Battle | Lineup (as rolled) | Fights | Loss rate | Hero deaths | Rounds med |
|---|---|---|---|---|---|
| 3 | False Image + Signal Wisp | 1424 | 1.7% | 0.73 | 6 |
| 3 | Circuit Acolyte + Signal Wisp | 1400 | 7.4% | 0.67 | 7 |
| 3 | Circuit Acolyte + Signal Wisp + Signal Wisp | 47 ⚠ low-sample | 44.7% | 1.87 | 11 |
| 3 | Circuit Acolyte + False Image | 38 ⚠ low-sample | 52.6% | 2.16 | 8 |
| 3 | False Image + Signal Wisp + Signal Wisp | 35 ⚠ low-sample | 42.9% | 2.03 | 9 |
| 3 | False Image + False Image | 16 ⚠ low-sample | 31.2% | 1.88 | 7 |
| 3 | Circuit Acolyte + Circuit Acolyte | 15 ⚠ low-sample | 40.0% | 1.67 | 9 |
| 4 | Oath Binder | 2610 | 2.0% | 0.44 | 6 |
| 4 | Oath Binder + Signal Wisp | 85 ⚠ low-sample | 8.2% | 0.94 | 8 |
| 4 | Circuit Acolyte | 43 ⚠ low-sample | 0.0% | 0.05 | 4 |
| 4 | False Image | 42 ⚠ low-sample | 0.0% | 0.19 | 4 |
| 5 | Circuit Acolyte + False Image | 1752 | 19.9% | 1.28 | 7 |
| 5 | Ash Channeler | 849 | 0.4% | 0.24 | 5 |
| 5 | Circuit Acolyte + False Image + Signal Wisp | 65 ⚠ low-sample | 66.2% | 2.34 | 9 |
| 5 | Ash Channeler + Signal Wisp | 21 ⚠ low-sample | 0.0% | 0.62 | 7 |
| 5 | Circuit Acolyte | 20 ⚠ low-sample | 0.0% | 0.10 | 4 |
| 5 | False Image | 14 ⚠ low-sample | 0.0% | 0.07 | 3 |
| 6 | False Image + Signal Wisp + Signal Wisp | 1176 | 1.4% | 0.54 | 6 |
| 6 | Circuit Acolyte + Signal Wisp + Signal Wisp | 1150 | 3.8% | 0.54 | 7 |
| 7 | Oath Binder + Signal Wisp | 1074 | 0.0% | 0.17 | 6 |
| 7 | Ash Channeler + Signal Wisp | 1059 | 0.0% | 0.20 | 5 |
| 7 | Ash Channeler + Signal Wisp + Signal Wisp | 39 ⚠ low-sample | 0.0% | 0.46 | 7 |
| 7 | Oath Binder + Signal Wisp + Signal Wisp | 36 ⚠ low-sample | 0.0% | 0.56 | 7 |
| 7 | Circuit Acolyte + Signal Wisp | 32 ⚠ low-sample | 0.0% | 0.12 | 5 |
| 7 | False Image + Signal Wisp | 25 ⚠ low-sample | 0.0% | 0.04 | 5 |
| 8 | Circuit Acolyte + Oath Binder | 546 | 1.5% | 0.33 | 7 |
| 8 | False Image + Oath Binder | 539 | 1.9% | 0.42 | 7 |
| 8 | Ash Channeler + Circuit Acolyte | 532 | 1.9% | 0.36 | 6 |
| 8 | Ash Channeler + False Image | 509 | 1.0% | 0.39 | 6 |
| 8 | Circuit Acolyte + False Image | 37 ⚠ low-sample | 0.0% | 0.19 | 5 |
| 8 | Ash Channeler + False Image + Signal Wisp | 22 ⚠ low-sample | 0.0% | 0.27 | 6 |
| 8 | Ash Channeler + Circuit Acolyte + Signal Wisp | 22 ⚠ low-sample | 13.6% | 0.91 | 9 |
| 8 | Circuit Acolyte + Circuit Acolyte | 17 ⚠ low-sample | 0.0% | 0.29 | 6 |
| 8 | Circuit Acolyte + Oath Binder + Signal Wisp | 15 ⚠ low-sample | 26.7% | 1.20 | 10 |
| 8 | False Image + Oath Binder + Signal Wisp | 15 ⚠ low-sample | 0.0% | 0.80 | 8 |
| 8 | False Image + False Image | 11 ⚠ low-sample | 9.1% | 0.55 | 5 |
| 9 | Cipher Scribe + Circuit Acolyte + Signal Wisp | 1103 | 7.7% | 0.69 | 8 |
| 9 | Cipher Scribe + False Image + Signal Wisp | 1061 | 2.8% | 0.55 | 7 |
| 9 | Circuit Acolyte + False Image + Signal Wisp | 31 ⚠ low-sample | 6.5% | 0.94 | 8 |
| 9 | Circuit Acolyte + Circuit Acolyte + Signal Wisp | 15 ⚠ low-sample | 6.7% | 0.93 | 6 |
| 9 | False Image + False Image + Signal Wisp | 14 ⚠ low-sample | 7.1% | 0.93 | 6 |

## Mantle Hunt — l1 (first evolutions)

3000 runs, 521 cleared (17.4%), 2466 failed. Seeds 100000–102999.

| Battle | Reached | Fights | Loss rate | Share of all losses | Hero deaths (avg) | HP lost (% squad max) | Rounds med / p90 |
|---|---|---|---|---|---|---|---|
| 1 | 100.0% | 3000 | **0.0%** | 0.0% | 0.00 | 4% | 3 / 4 |
| 2 | 100.0% | 3000 | **0.0%** | 0.0% | 0.03 | 14% | 4 / 6 |
| 3 | 100.0% | 2999 | **4.3%** | 5.2% | 0.59 | 37% | 7 / 12 |
| 4 | 95.7% | 2870 | **0.4%** | 0.4% | 0.21 | 18% | 5 / 8 |
| 5 | 95.3% | 2859 | **3.7%** | 4.3% | 0.35 | 32% | 7 / 13 |
| 6 | 91.8% | 2753 | **0.9%** | 1.0% | 0.30 | 23% | 7 / 11 |
| 7 | 90.9% | 2728 | **0.1%** | 0.2% | 0.12 | 19% | 6 / 11 |
| 8 | 90.8% | 2724 | **1.7%** | 1.8% | 0.37 | 32% | 8 / 14 |
| 9 | 89.3% | 2679 | **3.4%** | 3.6% | 0.47 | 30% | 8 / 14 |
| 10 (boss) | 86.3% | 2589 | **79.4%** | 83.3% | 2.58 | 87% | 10 / 18 |

Lineup variants (Mantle Hunt, l1):

| Battle | Lineup (as rolled) | Fights | Loss rate | Hero deaths | Rounds med |
|---|---|---|---|---|---|
| 2 | Pumice Climber + Slag Hound | 710 | 0.0% | 0.01 | 4 |
| 2 | Obsidian Hound + Pumice Climber | 672 | 0.0% | 0.03 | 5 |
| 2 | Obsidian Hound + Slag Hound | 603 | 0.2% | 0.04 | 4 |
| 2 | Slag Hound + Slag Hound | 346 | 0.0% | 0.04 | 4 |
| 2 | Obsidian Hound + Obsidian Hound | 340 | 0.0% | 0.05 | 5 |
| 2 | Pumice Climber + Pumice Climber | 329 | 0.0% | 0.03 | 4 |
| 3 | Geode Panther + Obsidian Hound | 503 | 3.6% | 0.65 | 7 |
| 3 | Cinder Raptor + Slag Hound | 486 | 1.4% | 0.39 | 8 |
| 3 | Cinder Raptor + Pumice Climber | 477 | 2.5% | 0.41 | 8 |
| 3 | Geode Panther + Pumice Climber | 465 | 3.0% | 0.62 | 7 |
| 3 | Geode Panther + Slag Hound | 448 | 2.9% | 0.60 | 7 |
| 3 | Cinder Raptor + Obsidian Hound | 433 | 2.5% | 0.48 | 8 |
| 3 | Cinder Raptor + Geode Panther | 42 ⚠ low-sample | 38.1% | 1.74 | 10 |
| 3 | Geode Panther + Geode Panther | 28 ⚠ low-sample | 35.7% | 1.82 | 10 |
| 3 | Cinder Raptor + Cinder Raptor | 17 ⚠ low-sample | 41.2% | 1.88 | 12 |
| 3 | Geode Panther + Pumice Climber + Slag Hound | 13 ⚠ low-sample | 15.4% | 1.31 | 10 |
| 3 | Cinder Raptor + Pumice Climber + Slag Hound | 13 ⚠ low-sample | 15.4% | 1.00 | 12 |
| 3 | Geode Panther + Obsidian Hound + Slag Hound | 12 ⚠ low-sample | 16.7% | 1.17 | 8 |
| 3 | Geode Panther + Obsidian Hound + Pumice Climber | 11 ⚠ low-sample | 45.5% | 2.09 | 11 |
| 3 | Cinder Raptor + Obsidian Hound + Slag Hound | 10 ⚠ low-sample | 10.0% | 0.80 | 9 |
| 3 | Cinder Raptor + Obsidian Hound + Pumice Climber | 9 ⚠ low-sample | 11.1% | 1.33 | 12 |
| 3 | Cinder Raptor + Slag Hound + Slag Hound | 9 ⚠ low-sample | 22.2% | 1.11 | 10 |
| 3 | Cinder Raptor + Obsidian Hound + Obsidian Hound | 6 ⚠ low-sample | 50.0% | 2.33 | 12 |
| 3 | Cinder Raptor + Pumice Climber + Pumice Climber | 6 ⚠ low-sample | 0.0% | 1.50 | 13 |
| 3 | Geode Panther + Obsidian Hound + Obsidian Hound | 5 ⚠ low-sample | 20.0% | 1.60 | 11 |
| 3 | Geode Panther + Slag Hound + Slag Hound | 3 ⚠ low-sample | 33.3% | 1.00 | 7 |
| 3 | Geode Panther + Pumice Climber + Pumice Climber | 3 ⚠ low-sample | 33.3% | 2.33 | 11 |
| 4 | Geode Panther | 2779 | 0.3% | 0.19 | 5 |
| 4 | Geode Panther + Obsidian Hound | 35 ⚠ low-sample | 2.9% | 0.83 | 7 |
| 4 | Geode Panther + Pumice Climber | 30 ⚠ low-sample | 3.3% | 0.63 | 7 |
| 4 | Geode Panther + Slag Hound | 26 ⚠ low-sample | 3.8% | 0.85 | 6 |
| 5 | Cinder Raptor + Geode Panther | 1397 | 6.6% | 0.56 | 8 |
| 5 | Basalt Ape | 669 | 0.1% | 0.11 | 6 |
| 5 | Magma Drake | 669 | 0.4% | 0.13 | 6 |
| 5 | Cinder Raptor | 22 ⚠ low-sample | 0.0% | 0.00 | 5 |
| 5 | Geode Panther | 20 ⚠ low-sample | 0.0% | 0.15 | 4 |
| 5 | Basalt Ape + Slag Hound | 15 ⚠ low-sample | 0.0% | 0.07 | 9 |
| 5 | Cinder Raptor + Geode Panther + Obsidian Hound | 14 ⚠ low-sample | 28.6% | 1.43 | 10 |
| 5 | Cinder Raptor + Geode Panther + Slag Hound | 14 ⚠ low-sample | 21.4% | 1.64 | 9 |
| 5 | Basalt Ape + Obsidian Hound | 9 ⚠ low-sample | 0.0% | 0.44 | 8 |
| 5 | Cinder Raptor + Geode Panther + Pumice Climber | 8 ⚠ low-sample | 37.5% | 1.50 | 10 |
| 5 | Magma Drake + Pumice Climber | 7 ⚠ low-sample | 0.0% | 0.29 | 9 |
| 5 | Magma Drake + Slag Hound | 7 ⚠ low-sample | 0.0% | 0.29 | 8 |
| 5 | Magma Drake + Obsidian Hound | 5 ⚠ low-sample | 0.0% | 0.20 | 7 |
| 5 | Basalt Ape + Pumice Climber | 3 ⚠ low-sample | 0.0% | 0.33 | 8 |
| 6 | Geode Panther + Obsidian Hound + Slag Hound | 317 | 0.9% | 0.38 | 7 |
| 6 | Geode Panther + Pumice Climber + Slag Hound | 309 | 1.3% | 0.36 | 7 |
| 6 | Cinder Raptor + Obsidian Hound + Slag Hound | 304 | 0.0% | 0.20 | 7 |
| 6 | Geode Panther + Obsidian Hound + Pumice Climber | 292 | 1.7% | 0.42 | 7 |
| 6 | Cinder Raptor + Obsidian Hound + Pumice Climber | 290 | 0.0% | 0.18 | 7 |
| 6 | Cinder Raptor + Pumice Climber + Slag Hound | 286 | 0.3% | 0.19 | 7 |
| 6 | Geode Panther + Pumice Climber + Pumice Climber | 177 | 0.6% | 0.44 | 6 |
| 6 | Geode Panther + Obsidian Hound + Obsidian Hound | 161 | 3.7% | 0.55 | 7 |
| 6 | Cinder Raptor + Slag Hound + Slag Hound | 161 | 0.0% | 0.21 | 7 |
| 6 | Cinder Raptor + Obsidian Hound + Obsidian Hound | 159 | 0.6% | 0.22 | 7 |
| 6 | Cinder Raptor + Pumice Climber + Pumice Climber | 151 | 0.0% | 0.19 | 7 |
| 6 | Geode Panther + Slag Hound + Slag Hound | 146 | 2.7% | 0.36 | 6 |
| 7 | Magma Drake + Pumice Climber | 456 | 0.0% | 0.12 | 6 |
| 7 | Basalt Ape + Obsidian Hound | 455 | 0.9% | 0.11 | 7 |
| 7 | Basalt Ape + Pumice Climber | 422 | 0.0% | 0.10 | 7 |
| 7 | Magma Drake + Obsidian Hound | 422 | 0.0% | 0.14 | 6 |
| 7 | Magma Drake + Slag Hound | 420 | 0.0% | 0.13 | 6 |
| 7 | Basalt Ape + Slag Hound | 398 | 0.0% | 0.07 | 7 |
| 7 | Cinder Raptor + Pumice Climber | 16 ⚠ low-sample | 0.0% | 0.06 | 5 |
| 7 | Magma Drake + Obsidian Hound + Slag Hound | 15 ⚠ low-sample | 0.0% | 0.53 | 11 |
| 7 | Cinder Raptor + Slag Hound | 14 ⚠ low-sample | 0.0% | 0.00 | 5 |
| 7 | Geode Panther + Pumice Climber | 14 ⚠ low-sample | 0.0% | 0.00 | 5 |
| 7 | Geode Panther + Slag Hound | 13 ⚠ low-sample | 0.0% | 0.00 | 6 |
| 7 | Geode Panther + Obsidian Hound | 12 ⚠ low-sample | 0.0% | 0.00 | 4 |
| 7 | Cinder Raptor + Obsidian Hound | 12 ⚠ low-sample | 0.0% | 0.00 | 6 |
| 7 | Basalt Ape + Obsidian Hound + Pumice Climber | 9 ⚠ low-sample | 0.0% | 0.22 | 8 |
| 7 | Basalt Ape + Pumice Climber + Slag Hound | 9 ⚠ low-sample | 0.0% | 0.11 | 7 |
| 7 | Magma Drake + Obsidian Hound + Pumice Climber | 7 ⚠ low-sample | 0.0% | 0.29 | 6 |
| 7 | Magma Drake + Obsidian Hound + Obsidian Hound | 6 ⚠ low-sample | 0.0% | 0.17 | 6 |
| 7 | Basalt Ape + Obsidian Hound + Obsidian Hound | 6 ⚠ low-sample | 0.0% | 0.67 | 8 |
| 7 | Basalt Ape + Slag Hound + Slag Hound | 5 ⚠ low-sample | 0.0% | 0.00 | 7 |
| 7 | Magma Drake + Pumice Climber + Slag Hound | 5 ⚠ low-sample | 0.0% | 0.40 | 7 |
| 7 | Magma Drake + Pumice Climber + Pumice Climber | 5 ⚠ low-sample | 0.0% | 0.20 | 6 |
| 7 | Basalt Ape + Pumice Climber + Pumice Climber | 3 ⚠ low-sample | 0.0% | 0.33 | 10 |
| 7 | Basalt Ape + Obsidian Hound + Slag Hound | 3 ⚠ low-sample | 0.0% | 0.33 | 11 |
| 7 | Magma Drake + Slag Hound + Slag Hound | 1 ⚠ low-sample | 0.0% | 1.00 | 6 |
| 8 | Geode Panther + Magma Drake | 679 | 1.6% | 0.39 | 8 |
| 8 | Basalt Ape + Geode Panther | 649 | 1.8% | 0.33 | 8 |
| 8 | Cinder Raptor + Magma Drake | 625 | 1.4% | 0.40 | 8 |
| 8 | Basalt Ape + Cinder Raptor | 619 | 1.3% | 0.34 | 9 |
| 8 | Cinder Raptor + Geode Panther | 42 ⚠ low-sample | 0.0% | 0.19 | 7 |
| 8 | Geode Panther + Geode Panther | 20 ⚠ low-sample | 5.0% | 0.40 | 6 |
| 8 | Cinder Raptor + Cinder Raptor | 15 ⚠ low-sample | 0.0% | 0.20 | 8 |
| 8 | Basalt Ape + Cinder Raptor + Pumice Climber | 9 ⚠ low-sample | 0.0% | 0.56 | 9 |
| 8 | Basalt Ape + Geode Panther + Obsidian Hound | 9 ⚠ low-sample | 11.1% | 1.00 | 9 |
| 8 | Cinder Raptor + Magma Drake + Obsidian Hound | 8 ⚠ low-sample | 0.0% | 0.62 | 10 |
| 8 | Cinder Raptor + Magma Drake + Slag Hound | 8 ⚠ low-sample | 12.5% | 0.88 | 10 |
| 8 | Basalt Ape + Cinder Raptor + Slag Hound | 6 ⚠ low-sample | 0.0% | 0.67 | 10 |
| 8 | Geode Panther + Magma Drake + Slag Hound | 6 ⚠ low-sample | 0.0% | 0.67 | 8 |
| 8 | Basalt Ape + Cinder Raptor + Obsidian Hound | 6 ⚠ low-sample | 0.0% | 0.17 | 11 |
| 8 | Geode Panther + Magma Drake + Obsidian Hound | 5 ⚠ low-sample | 0.0% | 1.00 | 8 |
| 8 | Geode Panther + Magma Drake + Pumice Climber | 5 ⚠ low-sample | 0.0% | 1.00 | 10 |
| 8 | Basalt Ape + Geode Panther + Slag Hound | 5 ⚠ low-sample | 20.0% | 0.80 | 9 |
| 8 | Basalt Ape + Geode Panther + Pumice Climber | 4 ⚠ low-sample | 25.0% | 1.00 | 14 |
| 8 | Cinder Raptor + Magma Drake + Pumice Climber | 4 ⚠ low-sample | 0.0% | 1.00 | 12 |
| 9 | Cinder Raptor + Geode Panther + Slag Hound | 450 | 1.3% | 0.33 | 8 |
| 9 | Cinder Raptor + Geode Panther + Pumice Climber | 438 | 2.5% | 0.42 | 8 |
| 9 | Cinder Raptor + Geode Panther + Obsidian Hound | 422 | 2.4% | 0.45 | 8 |
| 9 | Geode Panther + Geode Panther + Pumice Climber | 256 | 5.9% | 0.67 | 8 |
| 9 | Cinder Raptor + Cinder Raptor + Obsidian Hound | 237 | 1.3% | 0.35 | 9 |
| 9 | Cinder Raptor + Cinder Raptor + Pumice Climber | 213 | 2.8% | 0.35 | 8 |
| 9 | Geode Panther + Geode Panther + Slag Hound | 202 | 3.0% | 0.63 | 8 |
| 9 | Cinder Raptor + Cinder Raptor + Slag Hound | 196 | 2.6% | 0.35 | 9 |
| 9 | Geode Panther + Geode Panther + Obsidian Hound | 195 | 6.7% | 0.69 | 7 |
| 9 | Cinder Raptor + Geode Panther + Geode Panther | 29 ⚠ low-sample | 27.6% | 1.38 | 10 |
| 9 | Cinder Raptor + Cinder Raptor + Geode Panther | 24 ⚠ low-sample | 20.8% | 1.04 | 10 |
| 9 | Cinder Raptor + Cinder Raptor + Cinder Raptor | 11 ⚠ low-sample | 0.0% | 0.36 | 10 |
| 9 | Geode Panther + Geode Panther + Geode Panther | 6 ⚠ low-sample | 33.3% | 1.83 | 10 |

## Facility — l1_evo2 (second evolutions)

3000 runs, 1273 cleared (42.4%), 1727 failed. Seeds 100000–102999.

| Battle | Reached | Fights | Loss rate | Share of all losses | Hero deaths (avg) | HP lost (% squad max) | Rounds med / p90 |
|---|---|---|---|---|---|---|---|
| 1 | 100.0% | 3000 | **0.0%** | 0.0% | 0.07 | 19% | 5 / 6 |
| 2 | 100.0% | 3000 | **0.0%** | 0.0% | 0.06 | 17% | 5 / 6 |
| 3 | 100.0% | 3000 | **5.1%** | 8.8% | 0.76 | 43% | 6 / 9 |
| 4 | 94.9% | 2848 | **14.6%** | 24.0% | 1.10 | 46% | 6 / 10 |
| 5 | 81.1% | 2433 | **17.4%** | 24.5% | 1.39 | 54% | 9 / 15 |
| 6 | 67.0% | 2010 | **1.1%** | 1.3% | 0.52 | 28% | 6 / 9 |
| 7 | 66.3% | 1988 | **0.2%** | 0.2% | 0.21 | 18% | 5 / 8 |
| 8 | 66.1% | 1984 | **1.2%** | 1.4% | 0.46 | 29% | 6 / 10 |
| 9 | 65.3% | 1960 | **6.6%** | 7.5% | 0.85 | 40% | 7 / 13 |
| 10 (boss) | 61.0% | 1830 | **30.4%** | 32.3% | 1.22 | 49% | 11 / 18 |

Lineup variants (Facility, l1_evo2):

| Battle | Lineup (as rolled) | Fights | Loss rate | Hero deaths | Rounds med |
|---|---|---|---|---|---|
| 2 | Scrap Drone + Static Skimmer | 915 | 0.0% | 0.05 | 4 |
| 2 | Rust Drone + Static Skimmer | 792 | 0.0% | 0.06 | 5 |
| 2 | Rust Drone + Rust Drone | 440 | 0.0% | 0.09 | 5 |
| 2 | Static Skimmer + Static Skimmer | 427 | 0.0% | 0.04 | 5 |
| 2 | Scrap Drone + Scrap Drone | 426 | 0.0% | 0.11 | 4 |
| 3 | Static Skimmer + Volt Enforcer | 489 | 0.6% | 0.53 | 6 |
| 3 | Patrol Enforcer + Rust Drone | 483 | 6.8% | 0.94 | 6 |
| 3 | Patrol Enforcer + Scrap Drone | 482 | 5.0% | 0.77 | 6 |
| 3 | Scrap Drone + Volt Enforcer | 468 | 1.9% | 0.54 | 6 |
| 3 | Patrol Enforcer + Static Skimmer | 453 | 3.1% | 0.81 | 6 |
| 3 | Rust Drone + Volt Enforcer | 450 | 1.3% | 0.55 | 6 |
| 3 | Patrol Enforcer + Volt Enforcer | 46 ⚠ low-sample | 32.6% | 1.72 | 8 |
| 3 | Volt Enforcer + Volt Enforcer | 22 ⚠ low-sample | 22.7% | 1.68 | 8 |
| 3 | Patrol Enforcer + Patrol Enforcer | 16 ⚠ low-sample | 31.2% | 1.94 | 6 |
| 3 | Patrol Enforcer + Rust Drone + Scrap Drone | 14 ⚠ low-sample | 71.4% | 2.43 | 8 |
| 3 | Scrap Drone + Static Skimmer + Volt Enforcer | 12 ⚠ low-sample | 41.7% | 2.00 | 8 |
| 3 | Patrol Enforcer + Rust Drone + Static Skimmer | 10 ⚠ low-sample | 70.0% | 2.40 | 8 |
| 3 | Rust Drone + Static Skimmer + Volt Enforcer | 10 ⚠ low-sample | 30.0% | 1.90 | 9 |
| 3 | Patrol Enforcer + Scrap Drone + Static Skimmer | 9 ⚠ low-sample | 11.1% | 1.22 | 7 |
| 3 | Rust Drone + Scrap Drone + Volt Enforcer | 9 ⚠ low-sample | 0.0% | 1.11 | 7 |
| 3 | Patrol Enforcer + Scrap Drone + Scrap Drone | 7 ⚠ low-sample | 85.7% | 2.86 | 9 |
| 3 | Patrol Enforcer + Static Skimmer + Static Skimmer | 5 ⚠ low-sample | 20.0% | 1.60 | 9 |
| 3 | Static Skimmer + Static Skimmer + Volt Enforcer | 5 ⚠ low-sample | 0.0% | 1.40 | 8 |
| 3 | Patrol Enforcer + Rust Drone + Rust Drone | 4 ⚠ low-sample | 50.0% | 2.50 | 8 |
| 3 | Rust Drone + Rust Drone + Volt Enforcer | 3 ⚠ low-sample | 66.7% | 2.33 | 11 |
| 3 | Scrap Drone + Scrap Drone + Volt Enforcer | 3 ⚠ low-sample | 33.3% | 1.33 | 11 |
| 4 | Heavy Warden | 1365 | 2.3% | 0.56 | 6 |
| 4 | Patrol Enforcer + Volt Enforcer | 1348 | 25.0% | 1.62 | 7 |
| 4 | Patrol Enforcer | 21 ⚠ low-sample | 0.0% | 0.05 | 3 |
| 4 | Patrol Enforcer + Rust Drone + Volt Enforcer | 20 ⚠ low-sample | 85.0% | 2.85 | 7 |
| 4 | Volt Enforcer | 19 ⚠ low-sample | 0.0% | 0.00 | 3 |
| 4 | Patrol Enforcer + Scrap Drone + Volt Enforcer | 18 ⚠ low-sample | 61.1% | 2.50 | 7 |
| 4 | Heavy Warden + Rust Drone | 16 ⚠ low-sample | 18.8% | 1.00 | 9 |
| 4 | Heavy Warden + Static Skimmer | 16 ⚠ low-sample | 12.5% | 1.19 | 7 |
| 4 | Patrol Enforcer + Static Skimmer + Volt Enforcer | 15 ⚠ low-sample | 80.0% | 2.67 | 8 |
| 4 | Heavy Warden + Scrap Drone | 10 ⚠ low-sample | 10.0% | 1.10 | 9 |
| 5 | Shield Enforcer + Shield Enforcer | 2284 | 16.0% | 1.36 | 9 |
| 5 | Shield Enforcer + Volt Enforcer | 36 ⚠ low-sample | 8.3% | 1.03 | 8 |
| 5 | Rust Drone + Shield Enforcer + Shield Enforcer | 32 ⚠ low-sample | 62.5% | 2.28 | 8 |
| 5 | Patrol Enforcer + Shield Enforcer | 31 ⚠ low-sample | 12.9% | 1.23 | 7 |
| 5 | Scrap Drone + Shield Enforcer + Shield Enforcer | 28 ⚠ low-sample | 57.1% | 2.14 | 9 |
| 5 | Shield Enforcer + Shield Enforcer + Static Skimmer | 22 ⚠ low-sample | 68.2% | 2.41 | 10 |
| 6 | Patrol Enforcer + Rust Drone + Scrap Drone | 250 | 3.2% | 0.66 | 6 |
| 6 | Patrol Enforcer + Rust Drone + Static Skimmer | 231 | 1.3% | 0.63 | 6 |
| 6 | Patrol Enforcer + Scrap Drone + Static Skimmer | 228 | 0.9% | 0.55 | 6 |
| 6 | Rust Drone + Scrap Drone + Volt Enforcer | 217 | 0.5% | 0.39 | 6 |
| 6 | Scrap Drone + Static Skimmer + Volt Enforcer | 216 | 0.9% | 0.37 | 6 |
| 6 | Rust Drone + Static Skimmer + Volt Enforcer | 192 | 0.5% | 0.42 | 6 |
| 6 | Patrol Enforcer + Scrap Drone + Scrap Drone | 121 | 0.8% | 0.58 | 5 |
| 6 | Static Skimmer + Static Skimmer + Volt Enforcer | 117 | 0.9% | 0.61 | 6 |
| 6 | Scrap Drone + Scrap Drone + Volt Enforcer | 116 | 0.9% | 0.41 | 5 |
| 6 | Patrol Enforcer + Rust Drone + Rust Drone | 113 | 0.9% | 0.72 | 7 |
| 6 | Rust Drone + Rust Drone + Volt Enforcer | 109 | 0.0% | 0.47 | 6 |
| 6 | Patrol Enforcer + Static Skimmer + Static Skimmer | 100 | 1.0% | 0.54 | 6 |
| 7 | Heavy Warden + Static Skimmer | 632 | 0.0% | 0.19 | 5 |
| 7 | Heavy Warden + Scrap Drone | 624 | 0.2% | 0.18 | 5 |
| 7 | Heavy Warden + Rust Drone | 624 | 0.2% | 0.22 | 5 |
| 7 | Heavy Warden + Rust Drone + Static Skimmer | 17 ⚠ low-sample | 0.0% | 0.53 | 7 |
| 7 | Heavy Warden + Rust Drone + Scrap Drone | 15 ⚠ low-sample | 6.7% | 0.53 | 7 |
| 7 | Scrap Drone + Volt Enforcer | 10 ⚠ low-sample | 0.0% | 0.10 | 4 |
| 7 | Patrol Enforcer + Static Skimmer | 10 ⚠ low-sample | 0.0% | 0.30 | 4 |
| 7 | Heavy Warden + Rust Drone + Rust Drone | 9 ⚠ low-sample | 0.0% | 0.33 | 7 |
| 7 | Static Skimmer + Volt Enforcer | 9 ⚠ low-sample | 0.0% | 0.00 | 4 |
| 7 | Heavy Warden + Scrap Drone + Static Skimmer | 9 ⚠ low-sample | 11.1% | 1.22 | 6 |
| 7 | Patrol Enforcer + Scrap Drone | 8 ⚠ low-sample | 0.0% | 0.38 | 4 |
| 7 | Rust Drone + Volt Enforcer | 6 ⚠ low-sample | 0.0% | 0.00 | 4 |
| 7 | Heavy Warden + Scrap Drone + Scrap Drone | 6 ⚠ low-sample | 0.0% | 0.33 | 6 |
| 7 | Patrol Enforcer + Rust Drone | 5 ⚠ low-sample | 0.0% | 0.00 | 3 |
| 7 | Heavy Warden + Static Skimmer + Static Skimmer | 4 ⚠ low-sample | 0.0% | 0.75 | 6 |
| 8 | Heavy Warden + Patrol Enforcer | 936 | 0.6% | 0.45 | 6 |
| 8 | Heavy Warden + Volt Enforcer | 921 | 0.7% | 0.44 | 6 |
| 8 | Patrol Enforcer + Volt Enforcer | 31 ⚠ low-sample | 6.5% | 0.32 | 4 |
| 8 | Volt Enforcer + Volt Enforcer | 22 ⚠ low-sample | 0.0% | 0.18 | 6 |
| 8 | Patrol Enforcer + Patrol Enforcer | 19 ⚠ low-sample | 0.0% | 0.26 | 4 |
| 8 | Heavy Warden + Rust Drone + Volt Enforcer | 13 ⚠ low-sample | 0.0% | 1.08 | 9 |
| 8 | Heavy Warden + Patrol Enforcer + Rust Drone | 12 ⚠ low-sample | 41.7% | 1.83 | 10 |
| 8 | Heavy Warden + Scrap Drone + Volt Enforcer | 12 ⚠ low-sample | 0.0% | 1.25 | 8 |
| 8 | Heavy Warden + Patrol Enforcer + Scrap Drone | 8 ⚠ low-sample | 37.5% | 1.50 | 8 |
| 8 | Heavy Warden + Patrol Enforcer + Static Skimmer | 5 ⚠ low-sample | 0.0% | 0.60 | 10 |
| 8 | Heavy Warden + Static Skimmer + Volt Enforcer | 5 ⚠ low-sample | 40.0% | 1.60 | 9 |
| 9 | Patrol Enforcer + Scrap Drone + Shield Enforcer | 326 | 6.1% | 0.87 | 7 |
| 9 | Rust Drone + Shield Enforcer + Volt Enforcer | 325 | 4.3% | 0.77 | 7 |
| 9 | Patrol Enforcer + Rust Drone + Shield Enforcer | 324 | 9.3% | 0.90 | 8 |
| 9 | Shield Enforcer + Static Skimmer + Volt Enforcer | 320 | 6.2% | 0.85 | 8 |
| 9 | Patrol Enforcer + Shield Enforcer + Static Skimmer | 314 | 9.6% | 0.93 | 8 |
| 9 | Scrap Drone + Shield Enforcer + Volt Enforcer | 302 | 5.3% | 0.77 | 7 |
| 9 | Patrol Enforcer + Static Skimmer + Volt Enforcer | 12 ⚠ low-sample | 0.0% | 0.75 | 5 |
| 9 | Patrol Enforcer + Rust Drone + Volt Enforcer | 7 ⚠ low-sample | 0.0% | 0.71 | 6 |
| 9 | Scrap Drone + Volt Enforcer + Volt Enforcer | 7 ⚠ low-sample | 0.0% | 0.71 | 7 |
| 9 | Rust Drone + Volt Enforcer + Volt Enforcer | 5 ⚠ low-sample | 0.0% | 0.80 | 5 |
| 9 | Patrol Enforcer + Scrap Drone + Volt Enforcer | 5 ⚠ low-sample | 0.0% | 1.00 | 6 |
| 9 | Patrol Enforcer + Patrol Enforcer + Scrap Drone | 4 ⚠ low-sample | 0.0% | 0.25 | 5 |
| 9 | Patrol Enforcer + Patrol Enforcer + Rust Drone | 4 ⚠ low-sample | 0.0% | 0.75 | 6 |
| 9 | Patrol Enforcer + Patrol Enforcer + Static Skimmer | 3 ⚠ low-sample | 0.0% | 1.00 | 6 |
| 9 | Static Skimmer + Volt Enforcer + Volt Enforcer | 2 ⚠ low-sample | 0.0% | 1.00 | 9 |

## Hive — l1_evo2 (second evolutions)

3000 runs, 1019 cleared (34.0%), 1981 failed. Seeds 100000–102999.

| Battle | Reached | Fights | Loss rate | Share of all losses | Hero deaths (avg) | HP lost (% squad max) | Rounds med / p90 |
|---|---|---|---|---|---|---|---|
| 1 | 100.0% | 3000 | **0.0%** | 0.0% | 0.00 | 5% | 2 / 3 |
| 2 | 100.0% | 3000 | **0.0%** | 0.1% | 0.02 | 12% | 3 / 5 |
| 3 | 100.0% | 2999 | **4.6%** | 7.0% | 0.61 | 38% | 5 / 8 |
| 4 | 95.3% | 2860 | **7.0%** | 10.0% | 0.77 | 36% | 7 / 13 |
| 5 | 88.7% | 2661 | **3.8%** | 5.1% | 0.54 | 27% | 5 / 9 |
| 6 | 85.3% | 2559 | **0.6%** | 0.8% | 0.37 | 24% | 5 / 8 |
| 7 | 84.8% | 2544 | **0.0%** | 0.0% | 0.01 | 7% | 4 / 7 |
| 8 | 84.8% | 2544 | **0.5%** | 0.7% | 0.20 | 20% | 6 / 10 |
| 9 | 84.4% | 2531 | **11.2%** | 14.3% | 0.84 | 42% | 8 / 17 |
| 10 (boss) | 74.9% | 2248 | **54.7%** | 62.0% | 1.95 | 69% | 13 / 21 |

Lineup variants (Hive, l1_evo2):

| Battle | Lineup (as rolled) | Fights | Loss rate | Hero deaths | Rounds med |
|---|---|---|---|---|---|
| 2 | Bloodmite + Skitterling | 1444 | 0.0% | 0.02 | 3 |
| 2 | Skitterling + Skitterling | 779 | 0.1% | 0.05 | 4 |
| 2 | Bloodmite + Bloodmite | 777 | 0.0% | 0.00 | 3 |
| 3 | Skitterling + Spine Stalker | 1435 | 4.1% | 0.64 | 5 |
| 3 | Bloodmite + Spine Stalker | 1400 | 2.7% | 0.46 | 5 |
| 3 | Spine Stalker + Spine Stalker | 92 ⚠ low-sample | 29.3% | 1.63 | 7 |
| 3 | Bloodmite + Bloodmite + Spine Stalker | 30 ⚠ low-sample | 16.7% | 1.20 | 7 |
| 3 | Bloodmite + Skitterling + Spine Stalker | 24 ⚠ low-sample | 20.8% | 1.54 | 6 |
| 3 | Skitterling + Skitterling + Spine Stalker | 18 ⚠ low-sample | 27.8% | 1.61 | 8 |
| 4 | Broodwarden + Skitterling | 685 | 14.3% | 1.10 | 8 |
| 4 | Bloodmite + Caustic Spewer | 680 | 1.2% | 0.46 | 6 |
| 4 | Caustic Spewer + Skitterling | 670 | 2.5% | 0.65 | 7 |
| 4 | Bloodmite + Broodwarden | 669 | 9.6% | 0.87 | 8 |
| 4 | Bloodmite + Spine Stalker | 43 ⚠ low-sample | 7.0% | 0.49 | 5 |
| 4 | Skitterling + Spine Stalker | 43 ⚠ low-sample | 0.0% | 0.56 | 5 |
| 4 | Bloodmite + Caustic Spewer + Skitterling | 24 ⚠ low-sample | 4.2% | 0.96 | 7 |
| 4 | Bloodmite + Broodwarden + Skitterling | 13 ⚠ low-sample | 38.5% | 1.62 | 11 |
| 4 | Caustic Spewer + Skitterling + Skitterling | 11 ⚠ low-sample | 9.1% | 1.09 | 9 |
| 4 | Bloodmite + Bloodmite + Broodwarden | 8 ⚠ low-sample | 25.0% | 1.50 | 9 |
| 4 | Bloodmite + Bloodmite + Caustic Spewer | 8 ⚠ low-sample | 0.0% | 0.88 | 6 |
| 4 | Broodwarden + Skitterling + Skitterling | 6 ⚠ low-sample | 0.0% | 1.00 | 12 |
| 5 | Spine Stalker + Spine Stalker | 1310 | 6.2% | 0.92 | 5 |
| 5 | Broodwarden | 627 | 0.3% | 0.15 | 5 |
| 5 | Caustic Spewer | 601 | 0.0% | 0.07 | 4 |
| 5 | Spine Stalker | 45 ⚠ low-sample | 0.0% | 0.04 | 3 |
| 5 | Bloodmite + Spine Stalker + Spine Stalker | 22 ⚠ low-sample | 31.8% | 1.59 | 7 |
| 5 | Skitterling + Spine Stalker + Spine Stalker | 21 ⚠ low-sample | 42.9% | 1.95 | 7 |
| 5 | Broodwarden + Skitterling | 14 ⚠ low-sample | 21.4% | 0.79 | 8 |
| 5 | Bloodmite + Caustic Spewer | 8 ⚠ low-sample | 0.0% | 0.50 | 6 |
| 5 | Bloodmite + Broodwarden | 8 ⚠ low-sample | 0.0% | 0.88 | 6 |
| 5 | Caustic Spewer + Skitterling | 5 ⚠ low-sample | 0.0% | 0.40 | 6 |
| 6 | Bloodmite + Skitterling + Spine Stalker | 1292 | 0.3% | 0.38 | 5 |
| 6 | Skitterling + Skitterling + Spine Stalker | 635 | 1.7% | 0.44 | 5 |
| 6 | Bloodmite + Bloodmite + Spine Stalker | 632 | 0.0% | 0.28 | 4 |
| 7 | Broodwarden | 2388 | 0.0% | 0.01 | 4 |
| 7 | Spine Stalker | 80 ⚠ low-sample | 0.0% | 0.01 | 3 |
| 7 | Broodwarden + Skitterling | 44 ⚠ low-sample | 0.0% | 0.05 | 5 |
| 7 | Bloodmite + Broodwarden | 32 ⚠ low-sample | 0.0% | 0.03 | 5 |
| 8 | Caustic Spewer + Spine Stalker | 1208 | 0.2% | 0.13 | 5 |
| 8 | Broodwarden + Spine Stalker | 1197 | 0.3% | 0.23 | 6 |
| 8 | Spine Stalker + Spine Stalker | 65 ⚠ low-sample | 0.0% | 0.18 | 4 |
| 8 | Bloodmite + Broodwarden + Spine Stalker | 25 ⚠ low-sample | 8.0% | 0.76 | 8 |
| 8 | Caustic Spewer + Skitterling + Spine Stalker | 17 ⚠ low-sample | 5.9% | 0.59 | 7 |
| 8 | Broodwarden + Skitterling + Spine Stalker | 16 ⚠ low-sample | 12.5% | 1.00 | 8 |
| 8 | Bloodmite + Caustic Spewer + Spine Stalker | 16 ⚠ low-sample | 12.5% | 0.94 | 7 |
| 9 | Carapace Beetle + Skitterling + Spine Stalker | 1252 | 13.7% | 0.92 | 8 |
| 9 | Bloodmite + Carapace Beetle + Spine Stalker | 1216 | 9.1% | 0.78 | 8 |
| 9 | Bloodmite + Spine Stalker + Spine Stalker | 38 ⚠ low-sample | 0.0% | 0.42 | 5 |
| 9 | Skitterling + Spine Stalker + Spine Stalker | 25 ⚠ low-sample | 0.0% | 0.36 | 5 |

## Veil — l1_evo2 (second evolutions)

3000 runs, 773 cleared (25.8%), 2227 failed. Seeds 100000–102999.

| Battle | Reached | Fights | Loss rate | Share of all losses | Hero deaths (avg) | HP lost (% squad max) | Rounds med / p90 |
|---|---|---|---|---|---|---|---|
| 1 | 100.0% | 3000 | **0.0%** | 0.0% | 0.05 | 17% | 4 / 5 |
| 2 | 100.0% | 3000 | **0.0%** | 0.0% | 0.06 | 17% | 4 / 5 |
| 3 | 100.0% | 2999 | **7.6%** | 10.2% | 0.72 | 42% | 6 / 10 |
| 4 | 92.4% | 2772 | **23.8%** | 29.7% | 1.22 | 49% | 6 / 11 |
| 5 | 70.4% | 2111 | **8.3%** | 7.9% | 0.67 | 31% | 6 / 10 |
| 6 | 64.5% | 1935 | **1.2%** | 1.0% | 0.35 | 25% | 5 / 9 |
| 7 | 63.7% | 1912 | **16.9%** | 14.5% | 0.88 | 42% | 7 / 15 |
| 8 | 52.9% | 1588 | **3.8%** | 2.7% | 0.51 | 29% | 6 / 10 |
| 9 | 50.9% | 1527 | **16.0%** | 11.0% | 0.97 | 44% | 8 / 13 |
| 10 (boss) | 42.7% | 1282 | **39.7%** | 22.9% | 1.72 | 66% | 10 / 17 |

Lineup variants (Veil, l1_evo2):

| Battle | Lineup (as rolled) | Fights | Loss rate | Hero deaths | Rounds med |
|---|---|---|---|---|---|
| 2 | Shard Drone + Shard Drone | 1508 | 0.0% | 0.03 | 4 |
| 2 | Prism Charger + Prism Charger | 1492 | 0.1% | 0.08 | 4 |
| 3 | Phaseblade + Shard Drone | 1415 | 5.6% | 0.63 | 6 |
| 3 | Phaseblade + Prism Charger | 1405 | 5.7% | 0.67 | 6 |
| 3 | Phaseblade + Phaseblade | 77 ⚠ low-sample | 45.5% | 2.06 | 8 |
| 3 | Phaseblade + Prism Charger + Shard Drone | 49 ⚠ low-sample | 28.6% | 1.57 | 8 |
| 3 | Phaseblade + Prism Charger + Prism Charger | 29 ⚠ low-sample | 37.9% | 1.72 | 7 |
| 3 | Phaseblade + Shard Drone + Shard Drone | 24 ⚠ low-sample | 33.3% | 1.67 | 7 |
| 4 | Phaseblade + Phaseblade | 1358 | 41.9% | 1.92 | 8 |
| 4 | Resonance Warden | 671 | 5.2% | 0.64 | 6 |
| 4 | Stormweaver | 607 | 1.0% | 0.26 | 5 |
| 4 | Phaseblade | 41 ⚠ low-sample | 0.0% | 0.22 | 4 |
| 4 | Phaseblade + Phaseblade + Prism Charger | 27 ⚠ low-sample | 77.8% | 2.63 | 7 |
| 4 | Phaseblade + Phaseblade + Shard Drone | 26 ⚠ low-sample | 84.6% | 2.73 | 8 |
| 4 | Prism Charger + Stormweaver | 13 ⚠ low-sample | 7.7% | 0.62 | 6 |
| 4 | Shard Drone + Stormweaver | 12 ⚠ low-sample | 0.0% | 0.67 | 6 |
| 4 | Prism Charger + Resonance Warden | 9 ⚠ low-sample | 33.3% | 1.33 | 7 |
| 4 | Resonance Warden + Shard Drone | 8 ⚠ low-sample | 50.0% | 1.75 | 9 |
| 5 | Phaseblade + Phaseblade | 827 | 18.0% | 1.27 | 7 |
| 5 | Resonance Warden | 608 | 1.5% | 0.35 | 5 |
| 5 | Stormweaver | 594 | 0.2% | 0.12 | 4 |
| 5 | Phaseblade | 32 ⚠ low-sample | 0.0% | 0.06 | 3 |
| 5 | Phaseblade + Phaseblade + Shard Drone | 13 ⚠ low-sample | 46.2% | 1.92 | 8 |
| 5 | Phaseblade + Phaseblade + Prism Charger | 13 ⚠ low-sample | 69.2% | 2.31 | 10 |
| 5 | Resonance Warden + Shard Drone | 7 ⚠ low-sample | 28.6% | 1.00 | 8 |
| 5 | Prism Charger + Stormweaver | 6 ⚠ low-sample | 0.0% | 0.67 | 6 |
| 5 | Shard Drone + Stormweaver | 6 ⚠ low-sample | 0.0% | 0.67 | 6 |
| 5 | Prism Charger + Resonance Warden | 5 ⚠ low-sample | 0.0% | 0.60 | 9 |
| 6 | Phaseblade + Prism Charger + Shard Drone | 966 | 0.8% | 0.34 | 5 |
| 6 | Phaseblade + Shard Drone + Shard Drone | 495 | 1.6% | 0.36 | 5 |
| 6 | Phaseblade + Prism Charger + Prism Charger | 474 | 1.5% | 0.36 | 5 |
| 7 | Aegis Anchor + Aegis Anchor | 1833 | 16.8% | 0.88 | 7 |
| 7 | Aegis Anchor + Phaseblade | 45 ⚠ low-sample | 0.0% | 0.29 | 5 |
| 7 | Aegis Anchor + Aegis Anchor + Prism Charger | 17 ⚠ low-sample | 35.3% | 1.71 | 12 |
| 7 | Aegis Anchor + Aegis Anchor + Shard Drone | 17 ⚠ low-sample | 58.8% | 2.00 | 10 |
| 8 | Phaseblade + Resonance Warden | 760 | 4.3% | 0.57 | 6 |
| 8 | Phaseblade + Stormweaver | 733 | 2.7% | 0.41 | 6 |
| 8 | Phaseblade + Phaseblade | 48 ⚠ low-sample | 2.1% | 0.33 | 5 |
| 8 | Phaseblade + Prism Charger + Resonance Warden | 16 ⚠ low-sample | 31.2% | 1.38 | 7 |
| 8 | Phaseblade + Shard Drone + Stormweaver | 14 ⚠ low-sample | 7.1% | 0.86 | 7 |
| 8 | Phaseblade + Prism Charger + Stormweaver | 13 ⚠ low-sample | 0.0% | 0.54 | 7 |
| 8 | Phaseblade + Resonance Warden + Shard Drone | 4 ⚠ low-sample | 25.0% | 1.75 | 8 |
| 9 | Aegis Anchor + Phaseblade + Shard Drone | 394 | 23.6% | 1.19 | 8 |
| 9 | Phaseblade + Prism Charger + Relay Herald | 364 | 13.7% | 0.88 | 8 |
| 9 | Phaseblade + Relay Herald + Shard Drone | 358 | 10.6% | 0.80 | 8 |
| 9 | Aegis Anchor + Phaseblade + Prism Charger | 356 | 16.9% | 1.00 | 7 |
| 9 | Phaseblade + Phaseblade + Shard Drone | 28 ⚠ low-sample | 7.1% | 0.71 | 7 |
| 9 | Phaseblade + Phaseblade + Prism Charger | 27 ⚠ low-sample | 7.4% | 0.70 | 6 |

## Signal Purge — l1_evo2 (second evolutions)

3000 runs, 623 cleared (20.8%), 2377 failed. Seeds 100000–102999.

| Battle | Reached | Fights | Loss rate | Share of all losses | Hero deaths (avg) | HP lost (% squad max) | Rounds med / p90 |
|---|---|---|---|---|---|---|---|
| 1 | 100.0% | 3000 | **0.8%** | 1.1% | 0.49 | 34% | 6 / 9 |
| 2 | 99.2% | 2975 | **0.0%** | 0.0% | 0.05 | 13% | 4 / 6 |
| 3 | 99.2% | 2975 | **6.6%** | 8.2% | 0.76 | 43% | 7 / 11 |
| 4 | 92.7% | 2780 | **2.1%** | 2.4% | 0.44 | 26% | 6 / 9 |
| 5 | 90.7% | 2722 | **14.6%** | 16.7% | 0.96 | 45% | 6 / 11 |
| 6 | 77.5% | 2324 | **2.5%** | 2.5% | 0.53 | 30% | 6 / 11 |
| 7 | 75.5% | 2265 | **0.0%** | 0.0% | 0.15 | 15% | 6 / 9 |
| 8 | 75.5% | 2264 | **2.3%** | 2.2% | 0.40 | 30% | 7 / 12 |
| 9 | 73.7% | 2211 | **7.5%** | 7.0% | 0.69 | 38% | 7 / 13 |
| 10 (boss) | 68.2% | 2045 | **69.5%** | 59.8% | 2.37 | 82% | 12 / 20 |

Lineup variants (Signal Purge, l1_evo2):

| Battle | Lineup (as rolled) | Fights | Loss rate | Hero deaths | Rounds med |
|---|---|---|---|---|---|
| 3 | False Image + Signal Wisp | 1424 | 1.7% | 0.73 | 6 |
| 3 | Circuit Acolyte + Signal Wisp | 1400 | 7.4% | 0.67 | 7 |
| 3 | Circuit Acolyte + Signal Wisp + Signal Wisp | 47 ⚠ low-sample | 44.7% | 1.87 | 11 |
| 3 | Circuit Acolyte + False Image | 38 ⚠ low-sample | 52.6% | 2.16 | 8 |
| 3 | False Image + Signal Wisp + Signal Wisp | 35 ⚠ low-sample | 42.9% | 2.03 | 9 |
| 3 | False Image + False Image | 16 ⚠ low-sample | 31.2% | 1.88 | 7 |
| 3 | Circuit Acolyte + Circuit Acolyte | 15 ⚠ low-sample | 40.0% | 1.67 | 9 |
| 4 | Oath Binder | 2610 | 2.0% | 0.43 | 6 |
| 4 | Oath Binder + Signal Wisp | 85 ⚠ low-sample | 8.2% | 0.95 | 8 |
| 4 | Circuit Acolyte | 43 ⚠ low-sample | 0.0% | 0.05 | 4 |
| 4 | False Image | 42 ⚠ low-sample | 0.0% | 0.19 | 4 |
| 5 | Circuit Acolyte + False Image | 1753 | 20.5% | 1.30 | 7 |
| 5 | Ash Channeler | 849 | 0.0% | 0.18 | 5 |
| 5 | Circuit Acolyte + False Image + Signal Wisp | 65 ⚠ low-sample | 60.0% | 2.28 | 9 |
| 5 | Ash Channeler + Signal Wisp | 21 ⚠ low-sample | 0.0% | 0.52 | 7 |
| 5 | Circuit Acolyte | 20 ⚠ low-sample | 0.0% | 0.10 | 3 |
| 5 | False Image | 14 ⚠ low-sample | 0.0% | 0.00 | 3 |
| 6 | False Image + Signal Wisp + Signal Wisp | 1168 | 0.9% | 0.53 | 6 |
| 6 | Circuit Acolyte + Signal Wisp + Signal Wisp | 1156 | 4.2% | 0.53 | 7 |
| 7 | Oath Binder + Signal Wisp | 1072 | 0.0% | 0.14 | 6 |
| 7 | Ash Channeler + Signal Wisp | 1060 | 0.1% | 0.15 | 5 |
| 7 | Ash Channeler + Signal Wisp + Signal Wisp | 39 ⚠ low-sample | 0.0% | 0.46 | 7 |
| 7 | Circuit Acolyte + Signal Wisp | 37 ⚠ low-sample | 0.0% | 0.08 | 5 |
| 7 | Oath Binder + Signal Wisp + Signal Wisp | 33 ⚠ low-sample | 0.0% | 0.33 | 7 |
| 7 | False Image + Signal Wisp | 24 ⚠ low-sample | 0.0% | 0.17 | 4 |
| 8 | Circuit Acolyte + Oath Binder | 539 | 2.0% | 0.33 | 7 |
| 8 | Ash Channeler + Circuit Acolyte | 539 | 2.4% | 0.39 | 7 |
| 8 | False Image + Oath Binder | 536 | 2.6% | 0.42 | 7 |
| 8 | Ash Channeler + False Image | 515 | 1.4% | 0.41 | 6 |
| 8 | Circuit Acolyte + False Image | 35 ⚠ low-sample | 8.6% | 0.43 | 5 |
| 8 | Ash Channeler + Circuit Acolyte + Signal Wisp | 22 ⚠ low-sample | 18.2% | 0.95 | 10 |
| 8 | Ash Channeler + False Image + Signal Wisp | 20 ⚠ low-sample | 0.0% | 0.70 | 7 |
| 8 | Circuit Acolyte + Circuit Acolyte | 17 ⚠ low-sample | 0.0% | 0.18 | 7 |
| 8 | Circuit Acolyte + Oath Binder + Signal Wisp | 15 ⚠ low-sample | 0.0% | 0.60 | 9 |
| 8 | False Image + Oath Binder + Signal Wisp | 14 ⚠ low-sample | 7.1% | 0.50 | 8 |
| 8 | False Image + False Image | 12 ⚠ low-sample | 0.0% | 0.67 | 7 |
| 9 | Cipher Scribe + Circuit Acolyte + Signal Wisp | 1093 | 10.6% | 0.76 | 8 |
| 9 | Cipher Scribe + False Image + Signal Wisp | 1057 | 4.2% | 0.61 | 7 |
| 9 | Circuit Acolyte + False Image + Signal Wisp | 33 ⚠ low-sample | 9.1% | 0.70 | 6 |
| 9 | False Image + False Image + Signal Wisp | 14 ⚠ low-sample | 7.1% | 0.79 | 7 |
| 9 | Circuit Acolyte + Circuit Acolyte + Signal Wisp | 14 ⚠ low-sample | 14.3% | 1.07 | 7 |

## Mantle Hunt — l1_evo2 (second evolutions)

3000 runs, 540 cleared (18.0%), 2460 failed. Seeds 100000–102999.

| Battle | Reached | Fights | Loss rate | Share of all losses | Hero deaths (avg) | HP lost (% squad max) | Rounds med / p90 |
|---|---|---|---|---|---|---|---|
| 1 | 100.0% | 3000 | **0.0%** | 0.0% | 0.00 | 4% | 3 / 4 |
| 2 | 100.0% | 3000 | **0.0%** | 0.0% | 0.03 | 14% | 4 / 6 |
| 3 | 100.0% | 2999 | **4.3%** | 5.2% | 0.59 | 37% | 7 / 12 |
| 4 | 95.7% | 2870 | **0.3%** | 0.3% | 0.21 | 18% | 5 / 8 |
| 5 | 95.4% | 2862 | **3.7%** | 4.3% | 0.38 | 30% | 7 / 13 |
| 6 | 91.9% | 2756 | **0.4%** | 0.4% | 0.31 | 22% | 7 / 11 |
| 7 | 91.5% | 2745 | **0.0%** | 0.0% | 0.09 | 15% | 6 / 11 |
| 8 | 91.5% | 2745 | **1.3%** | 1.5% | 0.33 | 28% | 8 / 14 |
| 9 | 90.3% | 2709 | **4.6%** | 5.0% | 0.56 | 31% | 8 / 15 |
| 10 (boss) | 86.2% | 2585 | **79.1%** | 83.1% | 2.56 | 86% | 11 / 21 |

Lineup variants (Mantle Hunt, l1_evo2):

| Battle | Lineup (as rolled) | Fights | Loss rate | Hero deaths | Rounds med |
|---|---|---|---|---|---|
| 2 | Pumice Climber + Slag Hound | 710 | 0.0% | 0.01 | 4 |
| 2 | Obsidian Hound + Pumice Climber | 672 | 0.0% | 0.03 | 5 |
| 2 | Obsidian Hound + Slag Hound | 603 | 0.2% | 0.04 | 4 |
| 2 | Slag Hound + Slag Hound | 346 | 0.0% | 0.04 | 4 |
| 2 | Obsidian Hound + Obsidian Hound | 340 | 0.0% | 0.05 | 5 |
| 2 | Pumice Climber + Pumice Climber | 329 | 0.0% | 0.03 | 4 |
| 3 | Geode Panther + Obsidian Hound | 503 | 3.6% | 0.65 | 7 |
| 3 | Cinder Raptor + Slag Hound | 486 | 1.4% | 0.39 | 8 |
| 3 | Cinder Raptor + Pumice Climber | 477 | 2.5% | 0.41 | 8 |
| 3 | Geode Panther + Pumice Climber | 465 | 3.0% | 0.62 | 7 |
| 3 | Geode Panther + Slag Hound | 448 | 2.9% | 0.60 | 7 |
| 3 | Cinder Raptor + Obsidian Hound | 433 | 2.5% | 0.48 | 8 |
| 3 | Cinder Raptor + Geode Panther | 42 ⚠ low-sample | 38.1% | 1.74 | 10 |
| 3 | Geode Panther + Geode Panther | 28 ⚠ low-sample | 35.7% | 1.82 | 10 |
| 3 | Cinder Raptor + Cinder Raptor | 17 ⚠ low-sample | 41.2% | 1.88 | 12 |
| 3 | Geode Panther + Pumice Climber + Slag Hound | 13 ⚠ low-sample | 15.4% | 1.31 | 10 |
| 3 | Cinder Raptor + Pumice Climber + Slag Hound | 13 ⚠ low-sample | 15.4% | 1.00 | 12 |
| 3 | Geode Panther + Obsidian Hound + Slag Hound | 12 ⚠ low-sample | 16.7% | 1.17 | 8 |
| 3 | Geode Panther + Obsidian Hound + Pumice Climber | 11 ⚠ low-sample | 45.5% | 2.09 | 11 |
| 3 | Cinder Raptor + Obsidian Hound + Slag Hound | 10 ⚠ low-sample | 10.0% | 0.80 | 9 |
| 3 | Cinder Raptor + Obsidian Hound + Pumice Climber | 9 ⚠ low-sample | 11.1% | 1.33 | 12 |
| 3 | Cinder Raptor + Slag Hound + Slag Hound | 9 ⚠ low-sample | 22.2% | 1.11 | 10 |
| 3 | Cinder Raptor + Obsidian Hound + Obsidian Hound | 6 ⚠ low-sample | 50.0% | 2.33 | 12 |
| 3 | Cinder Raptor + Pumice Climber + Pumice Climber | 6 ⚠ low-sample | 0.0% | 1.50 | 13 |
| 3 | Geode Panther + Obsidian Hound + Obsidian Hound | 5 ⚠ low-sample | 20.0% | 1.60 | 11 |
| 3 | Geode Panther + Slag Hound + Slag Hound | 3 ⚠ low-sample | 33.3% | 1.00 | 7 |
| 3 | Geode Panther + Pumice Climber + Pumice Climber | 3 ⚠ low-sample | 33.3% | 2.33 | 11 |
| 4 | Geode Panther | 2779 | 0.2% | 0.19 | 5 |
| 4 | Geode Panther + Obsidian Hound | 35 ⚠ low-sample | 2.9% | 0.77 | 7 |
| 4 | Geode Panther + Pumice Climber | 30 ⚠ low-sample | 3.3% | 0.67 | 7 |
| 4 | Geode Panther + Slag Hound | 26 ⚠ low-sample | 3.8% | 0.85 | 6 |
| 5 | Cinder Raptor + Geode Panther | 1399 | 6.8% | 0.62 | 8 |
| 5 | Basalt Ape | 670 | 0.0% | 0.09 | 6 |
| 5 | Magma Drake | 669 | 0.3% | 0.13 | 6 |
| 5 | Cinder Raptor | 22 ⚠ low-sample | 0.0% | 0.05 | 6 |
| 5 | Geode Panther | 20 ⚠ low-sample | 0.0% | 0.05 | 4 |
| 5 | Basalt Ape + Slag Hound | 15 ⚠ low-sample | 0.0% | 0.07 | 9 |
| 5 | Cinder Raptor + Geode Panther + Obsidian Hound | 14 ⚠ low-sample | 35.7% | 1.93 | 12 |
| 5 | Cinder Raptor + Geode Panther + Slag Hound | 14 ⚠ low-sample | 7.1% | 1.43 | 10 |
| 5 | Basalt Ape + Obsidian Hound | 9 ⚠ low-sample | 0.0% | 0.22 | 7 |
| 5 | Cinder Raptor + Geode Panther + Pumice Climber | 8 ⚠ low-sample | 37.5% | 1.75 | 12 |
| 5 | Magma Drake + Pumice Climber | 7 ⚠ low-sample | 0.0% | 0.14 | 8 |
| 5 | Magma Drake + Slag Hound | 7 ⚠ low-sample | 0.0% | 0.29 | 9 |
| 5 | Magma Drake + Obsidian Hound | 5 ⚠ low-sample | 0.0% | 0.20 | 7 |
| 5 | Basalt Ape + Pumice Climber | 3 ⚠ low-sample | 0.0% | 0.00 | 7 |
| 6 | Geode Panther + Obsidian Hound + Slag Hound | 316 | 0.6% | 0.38 | 7 |
| 6 | Geode Panther + Pumice Climber + Slag Hound | 310 | 0.0% | 0.38 | 6 |
| 6 | Cinder Raptor + Obsidian Hound + Slag Hound | 300 | 0.3% | 0.23 | 7 |
| 6 | Geode Panther + Obsidian Hound + Pumice Climber | 293 | 1.0% | 0.46 | 7 |
| 6 | Cinder Raptor + Obsidian Hound + Pumice Climber | 292 | 0.3% | 0.18 | 7 |
| 6 | Cinder Raptor + Pumice Climber + Slag Hound | 285 | 0.4% | 0.17 | 7 |
| 6 | Geode Panther + Pumice Climber + Pumice Climber | 178 | 0.0% | 0.39 | 7 |
| 6 | Geode Panther + Obsidian Hound + Obsidian Hound | 160 | 1.2% | 0.56 | 7 |
| 6 | Cinder Raptor + Slag Hound + Slag Hound | 160 | 0.0% | 0.16 | 7 |
| 6 | Cinder Raptor + Obsidian Hound + Obsidian Hound | 158 | 0.0% | 0.28 | 7 |
| 6 | Cinder Raptor + Pumice Climber + Pumice Climber | 154 | 0.0% | 0.19 | 7 |
| 6 | Geode Panther + Slag Hound + Slag Hound | 150 | 0.7% | 0.35 | 6 |
| 7 | Basalt Ape + Obsidian Hound | 461 | 0.0% | 0.10 | 7 |
| 7 | Magma Drake + Pumice Climber | 458 | 0.0% | 0.12 | 6 |
| 7 | Magma Drake + Obsidian Hound | 435 | 0.0% | 0.10 | 6 |
| 7 | Basalt Ape + Pumice Climber | 419 | 0.0% | 0.09 | 7 |
| 7 | Magma Drake + Slag Hound | 416 | 0.0% | 0.06 | 6 |
| 7 | Basalt Ape + Slag Hound | 403 | 0.0% | 0.06 | 7 |
| 7 | Cinder Raptor + Pumice Climber | 16 ⚠ low-sample | 0.0% | 0.06 | 5 |
| 7 | Magma Drake + Obsidian Hound + Slag Hound | 15 ⚠ low-sample | 0.0% | 0.27 | 9 |
| 7 | Cinder Raptor + Slag Hound | 14 ⚠ low-sample | 0.0% | 0.00 | 5 |
| 7 | Geode Panther + Pumice Climber | 14 ⚠ low-sample | 0.0% | 0.00 | 5 |
| 7 | Geode Panther + Slag Hound | 13 ⚠ low-sample | 0.0% | 0.00 | 5 |
| 7 | Geode Panther + Obsidian Hound | 12 ⚠ low-sample | 0.0% | 0.00 | 5 |
| 7 | Cinder Raptor + Obsidian Hound | 11 ⚠ low-sample | 0.0% | 0.00 | 5 |
| 7 | Basalt Ape + Obsidian Hound + Pumice Climber | 9 ⚠ low-sample | 0.0% | 0.11 | 7 |
| 7 | Basalt Ape + Pumice Climber + Slag Hound | 9 ⚠ low-sample | 0.0% | 0.11 | 6 |
| 7 | Magma Drake + Obsidian Hound + Pumice Climber | 7 ⚠ low-sample | 0.0% | 0.29 | 8 |
| 7 | Magma Drake + Obsidian Hound + Obsidian Hound | 6 ⚠ low-sample | 0.0% | 0.17 | 6 |
| 7 | Basalt Ape + Slag Hound + Slag Hound | 5 ⚠ low-sample | 0.0% | 0.20 | 7 |
| 7 | Magma Drake + Pumice Climber + Slag Hound | 5 ⚠ low-sample | 0.0% | 0.20 | 14 |
| 7 | Magma Drake + Pumice Climber + Pumice Climber | 5 ⚠ low-sample | 0.0% | 0.60 | 8 |
| 7 | Basalt Ape + Obsidian Hound + Obsidian Hound | 5 ⚠ low-sample | 0.0% | 0.40 | 7 |
| 7 | Basalt Ape + Pumice Climber + Pumice Climber | 3 ⚠ low-sample | 0.0% | 0.33 | 7 |
| 7 | Basalt Ape + Obsidian Hound + Slag Hound | 3 ⚠ low-sample | 0.0% | 0.00 | 10 |
| 7 | Magma Drake + Slag Hound + Slag Hound | 1 ⚠ low-sample | 0.0% | 0.00 | 6 |
| 8 | Geode Panther + Magma Drake | 676 | 1.2% | 0.32 | 7 |
| 8 | Basalt Ape + Geode Panther | 656 | 0.8% | 0.33 | 8 |
| 8 | Cinder Raptor + Magma Drake | 633 | 1.9% | 0.36 | 8 |
| 8 | Basalt Ape + Cinder Raptor | 623 | 0.3% | 0.26 | 9 |
| 8 | Cinder Raptor + Geode Panther | 45 ⚠ low-sample | 2.2% | 0.24 | 7 |
| 8 | Geode Panther + Geode Panther | 20 ⚠ low-sample | 0.0% | 0.30 | 6 |
| 8 | Cinder Raptor + Cinder Raptor | 14 ⚠ low-sample | 0.0% | 0.14 | 8 |
| 8 | Cinder Raptor + Magma Drake + Obsidian Hound | 9 ⚠ low-sample | 0.0% | 0.67 | 13 |
| 8 | Basalt Ape + Cinder Raptor + Pumice Climber | 9 ⚠ low-sample | 11.1% | 0.78 | 12 |
| 8 | Basalt Ape + Geode Panther + Obsidian Hound | 9 ⚠ low-sample | 11.1% | 1.11 | 11 |
| 8 | Cinder Raptor + Magma Drake + Slag Hound | 7 ⚠ low-sample | 0.0% | 1.00 | 12 |
| 8 | Basalt Ape + Cinder Raptor + Slag Hound | 6 ⚠ low-sample | 0.0% | 0.33 | 12 |
| 8 | Geode Panther + Magma Drake + Slag Hound | 6 ⚠ low-sample | 16.7% | 0.67 | 10 |
| 8 | Basalt Ape + Geode Panther + Slag Hound | 6 ⚠ low-sample | 0.0% | 0.33 | 10 |
| 8 | Basalt Ape + Cinder Raptor + Obsidian Hound | 6 ⚠ low-sample | 0.0% | 0.00 | 12 |
| 8 | Geode Panther + Magma Drake + Obsidian Hound | 5 ⚠ low-sample | 0.0% | 0.40 | 8 |
| 8 | Basalt Ape + Geode Panther + Pumice Climber | 5 ⚠ low-sample | 0.0% | 0.40 | 10 |
| 8 | Cinder Raptor + Magma Drake + Pumice Climber | 5 ⚠ low-sample | 40.0% | 1.40 | 9 |
| 8 | Geode Panther + Magma Drake + Pumice Climber | 5 ⚠ low-sample | 60.0% | 2.40 | 9 |
| 9 | Cinder Raptor + Geode Panther + Slag Hound | 446 | 1.8% | 0.39 | 8 |
| 9 | Cinder Raptor + Geode Panther + Pumice Climber | 440 | 3.0% | 0.49 | 8 |
| 9 | Cinder Raptor + Geode Panther + Obsidian Hound | 430 | 4.2% | 0.54 | 8 |
| 9 | Geode Panther + Geode Panther + Pumice Climber | 254 | 9.8% | 0.88 | 8 |
| 9 | Cinder Raptor + Cinder Raptor + Obsidian Hound | 244 | 3.3% | 0.45 | 9 |
| 9 | Cinder Raptor + Cinder Raptor + Pumice Climber | 219 | 0.5% | 0.32 | 8 |
| 9 | Geode Panther + Geode Panther + Slag Hound | 203 | 5.9% | 0.75 | 8 |
| 9 | Cinder Raptor + Cinder Raptor + Slag Hound | 202 | 3.0% | 0.38 | 9 |
| 9 | Geode Panther + Geode Panther + Obsidian Hound | 197 | 6.6% | 0.77 | 8 |
| 9 | Cinder Raptor + Geode Panther + Geode Panther | 31 ⚠ low-sample | 35.5% | 1.68 | 11 |
| 9 | Cinder Raptor + Cinder Raptor + Geode Panther | 24 ⚠ low-sample | 20.8% | 1.08 | 9 |
| 9 | Cinder Raptor + Cinder Raptor + Cinder Raptor | 11 ⚠ low-sample | 0.0% | 0.82 | 11 |
| 9 | Geode Panther + Geode Panther + Geode Panther | 8 ⚠ low-sample | 50.0% | 1.88 | 9 |
## Method

- **Sim:** the repo's headless sim (`scenes/sim/sim_main.tscn`, real `combat_manager.gd`), policies `l1` and
  `l1_evo2`. Random squad (3 of 8 heroes, uniform) per run; squads are matched across operations and policies
  (seed `100000+i`, squad from `random.Random(100000).sample`, same as `batch.py`'s picker).
- **Runs:** 3,000 per operation per policy (30,000 total), seeds 100000–102999.
- **Reached:** runs with a `battle_start` for this battle / all runs of that op+policy.
- **Loss rate:** `battle_end.result == defeat` / runs that reached the battle. Battle 10 losses are the boss.
- **Share of all losses:** losses at this battle / all failed (defeat) runs of that operation+policy.
- **Stalemates:** 24 l1 runs (Veil 3, Signal Purge 8, Mantle Hunt 13) hit the 500-round cap at the battle 10 boss.
  They are neither a loss nor a clear, so they sit in "Reached" and the Fights count but not in the loss rate
  (their 500-round fights also lift that boss row's rounds p90). Not seen with l1_evo2.
- **Hero deaths:** `len(battle_end.deaths)` — heroes down at the end of the fight, averaged over fights that
  occurred. In a lost fight this is every hero. Heroes revived between battles are counted again if they fall again.
- **HP lost:** (sum of squad HP at `battle_start` − sum at `battle_end`) / squad max HP, averaged per fight. The
  telemetry has no max-HP field, so squad max is the running per-hero maximum of observed HP through that
  fight. Because dead heroes start the next fight partially revived, a lost fight's HP-lost reads as the HP the
  squad had when it started, not an absolute figure; net heals during a fight reduce it.
- **Rounds:** `battle_end.rounds` for every fight that occurred at that battle (wins and losses), median and
  linear-interpolated 90th percentile.
- **Lineup variants:** keyed by the sorted multiset of enemy display names in `battle_start.comp` (starting
  lineup; summons not included). Route modifiers (e.g. deadMansCharge) are NOT split out and mix inside each
  lineup row. Rows with an extra enemy beyond the base lineup (most of the low-sample rows) come from the route
  modifiers `overrun` / `elitePresence` (checked on Facility 4: all 135 such fights carry one of those two). Variants under 100 fights are flagged ⚠ low-sample. The cross-op table above shows only battles that
  rolled more than one lineup.
- **Not in the data:** gear/relic/evolution draft choices are the policy's; item drafts differ run to run.
