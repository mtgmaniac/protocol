# Facility post-stat-pass balance audit — 2026-07-31

## Verdict

**REVERT OR REDUCE THE STAT PASS**

The pass achieves two intended texture changes: battles 1–2 remain safe and
Scrapmaster's share of Facility deaths drops materially. It is nevertheless a
much larger difficulty move than intended. Matched L1 Facility clear rate falls
from **56.6% to 34.6% (-22.1pp)**, below the initial 45–52% evaluation range;
the CI-sized check is even lower at 32.4%. Pre-boss deaths rise most at battles
3–5, while Scrapmaster itself becomes harder for every entrant (37.4% to
53.4% death rate). No new number is proposed here.

The smallest follow-up investigation is the combined seven-unit HP-plus-damage
pass, especially the Patrol/Volt and Guard-heavy pre-boss encounters. Separately,
the fixed starter squad without Strike is an outlier; Medic itself is not
mandatory.

## Tested state and validity

- Branch: `main`
- Commit: `72a72ca5bd5bb5eec7e7a54f3a9e87b7614762ae`
- Stat-pass commit: `03ae250 Apply Facility light-hybrid difficulty pass`
- The live `data/raw/enemies.data.json` is byte-identical to that pass for
  enemy data. Its only data-file changes were the seven non-boss Facility
  families and the corresponding unit HP values; the commit changed no
  non-Facility enemy data.
- `SCRAPMASTER` remains HP 140 and the `boss` direct-damage family remains
  12/17/21/26. It did not appear in the stat-pass diff.
- Fresh-profile heroes are exactly Strike Unit (`combat`), Field Engineer
  (`engineer`), Splice Medic (`medic`), and Pulse Tech (`pulse`), as pinned by
  `unlock_progression_test.gd`.

### Live Facility values

| Unit / family | Before | Live after |
|---|---|---|
| Scrap Drone / `scrap` | 35 HP; 7/10/15/20 | 40 HP; 8/11/16/21 |
| Rust Drone / `rust` | 40 HP; 6/9/12/14 | 45 HP; 7/10/13/15 |
| Static Skimmer / `signalSkimmer` | 35 HP; 5/8/11/13 | 40 HP; 6/9/12/14 |
| Patrol Elite / `patrol` | 55 HP; 15/18/21/23 | 60 HP; 16/19/22/24 |
| Guard Elite / `guard` | 65 HP; 12/11/15/18 | 70 HP; 13/12/16/19 |
| Volt Elite / `volt` | 70 HP; 9/11/13/15 | 75 HP; 10/12/14/16 |
| Heavy Warden / `warden` | 105 HP; 11/11/24/29 | 110 HP; 12/12/25/30 |

Values are direct damage in the four nonzero ability bands. Status, shield,
heal, AI, ranges, battle composition, and `battleEnemyScale` were not changed.
The simulator uses current DataManager-loaded raw data and no `--enemy-hp` or
other balance override; all final manifests record blank override fields.

## Method

The comparison baseline is `docs/balance_snapshot_2026-07.md` and its generated
`results/snap_*` telemetry, captured immediately before `03ae250`. The primary
before/after L1 comparison uses the same 2,000 seed range and deterministic
random squad/operation picker. This yields the same 376 Facility seeds on each
side, enabling seed-level outcome comparison.

The harness runs the shared combat engine and BattleEngine, records JSONL
telemetry, and keeps drafting, rewards, evolution, Protocol, consumables, and
route beats active. Fixed-squad cohorts use `--squad` and `--op facility`; their
manifests confirm the requested lock. All final batches completed with the
expected trace count and **zero failed runs**.

Commands executed (worker count only controls throughput, not seeds or results):

```text
python scripts/sim/batch.py --name post_stats_l1 --runs 2000 --policy l1 --seed-base 100000
python scripts/sim/analyze.py results/post_stats_l1 -o results/post_stats_l1_report.md
python scripts/sim/analyze.py results/post_stats_l1 --metrics
python scripts/sim/batch.py --name post_stats_l0 --runs 600 --policy l0 --seed-base 100000 --workers 8
python scripts/sim/batch.py --name post_stats_l2 --runs 300 --policy l2 --seed-base 100000 --workers 8
python scripts/sim/analyze.py --skillband results/post_stats_l1 results/post_stats_l2
python scripts/sim/batch.py --name post_stats_ci --runs 300 --policy l1 --seed-base 900000 --workers 8
python scripts/sim/analyze.py results/post_stats_ci --metrics

python scripts/sim/batch.py --name post_squad_combat_engineer_medic --runs 1000 --policy l1 --seed-base 100000 --workers 4 --squad combat,engineer,medic --op facility
python scripts/sim/batch.py --name post_squad_pulse_engineer_medic --runs 1000 --policy l1 --seed-base 100000 --workers 4 --squad pulse,engineer,medic --op facility
python scripts/sim/batch.py --name post_squad_combat_pulse_medic --runs 1000 --policy l1 --seed-base 100000 --workers 4 --squad combat,pulse,medic --op facility
python scripts/sim/batch.py --name post_squad_combat_engineer_pulse --runs 1000 --policy l1 --seed-base 100000 --workers 4 --squad combat,engineer,pulse --op facility
```

Generated traces and the L1 report are under `results/post_stats_*` and
`results/post_squad_*`; they are gitignored and are not part of this commit.

## Before and after

| Metric | Before | After | Change |
|---|---:|---:|---:|
| Facility L0 clear (600) | 13.1% | 4.7% | -8.4pp |
| Facility L1 clear (2,000 overall; 376 Facility) | 56.6% | 34.6% | -22.1pp |
| Facility L2 clear (300 overall) | 72.3% | 59.6% | -12.8pp |
| L1→L2 Facility skill gap | +15.7pp | +25.0pp | +9.3pp |
| CI Facility L1 clear (300, seed 900000) | 63.4% | 32.4% | -31.0pp |
| Mean Facility depth (battles cleared) | 9.11 | 8.07 | -1.04 |
| Mean total turns/run | 67.5 | 66.5 | -1.0 |
| Scrapmaster death rate among entrants | 37.4% | 53.4% | +16.1pp |
| Scrapmaster share of Facility deaths | 77.9% | 60.6% | -17.3pp |
| Scrapmaster clear given entry | 62.7% | 46.6% | -16.1pp |

The skill gap widens rather than collapses, so skill expression remains healthy.
The change is not a duration problem: encounters take a little longer, but
earlier defeats reduce full-run turns. It is a survival/attrition problem.

### L1 Facility attrition and duration

Rates are deaths among entrants to that battle. The matched baseline and post
sample each contain 376 Facility runs.

| Battle | Before death | After death | Change | Before turns | After turns |
|---|---:|---:|---:|---:|---:|
| 1 | 0.0% | 0.0% | +0.0pp | 4.48 | 5.02 |
| 2 | 0.0% | 0.0% | +0.0pp | 4.37 | 4.89 |
| 3 | 0.8% | 4.0% | +3.2pp | 5.91 | 6.65 |
| 4 | 4.8% | 11.9% | +7.1pp | 7.06 | 7.67 |
| 5 | 1.7% | 4.1% | +2.4pp | 7.32 | 8.46 |
| 6 | 0.0% | 1.6% | +1.6pp | 6.47 | 7.04 |
| 7 | 0.0% | 0.0% | +0.0pp | 6.92 | 7.38 |
| 8 | 0.6% | 3.3% | +2.8pp | 8.32 | 9.52 |
| 9 | 2.0% | 3.8% | +1.8pp | 7.46 | 8.36 |
| 10 Scrapmaster | 37.4% | 53.4% | +16.1pp | 13.09 | 13.21 |

Battles 1–2 meet the forgiving-runway goal. The pass produces the desired
pre-boss attrition, but the b3–b5 increase is substantial and Scrapmaster still
causes 149 of 246 total post-pass Facility defeats—the largest single threat by
far, even though no longer nearly four-fifths of all deaths. The common post
boss failure is unchanged in composition (Scrap Drone / Scrapmaster / Scrap
Drone); the common new pre-boss failures are Patrol+Volt (34 total across both
orders) and Guard+Guard (10).

## Matched seed changes

Of 376 matched Facility seeds, **167 changed outcome**: 125 wins became losses
and 42 losses became wins. The positive flips confirm the stat pass changes
combat/reward trajectories, not merely one deterministic boss threshold.

- 83 of the 125 win→loss flips reached battle 10 and then lost; 21 now fail at
  battle 3, with the remainder distributed across battles 2, 4, 5, 7, and 8.
- 42 loss→win flips clear battle 10; the remainder shift their failure depth.
- Thus the net loss is mainly worse boss entry/outcome plus real early/mid-run
  attrition, not an all-or-nothing first-encounter spike.

## Hero, evolution, Protocol, and consumables

The random-roster L1 hero clear rates all decline, not just a single support
hero: Strike 35.5%→31.4%, Engineer 32.3%→29.3%, Medic 32.1%→27.9%, Pulse
34.6%→31.5%, Ghost 40.9%→35.5%, and Shield 24.8%→20.9%. This is consistent
with operation-wide pressure, with Shield/Avalanche still at the lower end.

Evolution remains active but occurs less often because runs end earlier. The
eight L1 path picks total 5,380 after the pass versus 5,610 before; every path
is still selected (post counts range from Noise Floor 97 to Pyro Specialist
133 in the 2,000-run random cohort). There is no evolution fallback or missing
progression event.

Facility Protocol behavior is almost unchanged in shape: before/after totals
were Nudge 17,681/17,463, Reroll 2,250/2,199, Set 17/19, and item casts
954/893. Per run, item use declined only 2.54→2.38. The pass did not disable or
crowd out Protocol, Set, or consumables; L1's continued near-zero Set use is a
known policy characteristic rather than new behavior.

## Four fresh-starter squads — 1,000 matched Facility L1 runs each

All four use seed base 100000, the same policy, normal reward/evolution and
consumable behavior, and fixed Facility operation. “Hero deaths” below are
battle-end down events, so a revived hero can appear more than once.

| Squad | Clear | Mean depth | Mean turns | Boss entry | Boss clear | Boss share deaths | Common failure |
|---|---:|---:|---:|---:|---:|---:|---|
| Strike / Engineer / Medic | **60.8%** | 9.24 | 64.4 | 92.6% | 65.7% | 81.1% | Scrapmaster (318) |
| Pulse / Engineer / Medic | **38.6%** | 8.87 | 67.6 | 88.7% | 43.5% | 81.6% | Scrapmaster (501) |
| Strike / Pulse / Medic | **52.3%** | 9.14 | 64.4 | 91.2% | 57.4% | 81.6% | Scrapmaster (389) |
| Strike / Engineer / Pulse | **58.3%** | 9.25 | 53.9 | 92.8% | 62.8% | 82.7% | Scrapmaster (345) |

The requested questions resolve as follows:

- **Medic is not mandatory.** The no-Medic Strike/Engineer/Pulse squad clears
  58.3%, only 2.5pp behind the original trio, and has the shortest runs.
- **The original trio is the best measured squad, but not uniquely so.**
  Strike/Engineer/Pulse is close enough that it is a genuine alternative.
- **Pulse creates an alternative playstyle when retained alongside Strike and
  Engineer.** It does not rescue the Pulse/Engineer/Medic composition: that
  squad is 22.2pp behind the original trio and is the clear fresh-roster
  outlier.
- **The trap signal is absence of Strike, not absence of Medic.** Pulse/Engineer/
  Medic also posts 3,091 Pulse battle-end downs per 1,000 runs, versus 954
  Engineer and 927 Strike downs in the no-Medic alternative.
- All squads still evolve their members in roughly 93–96% of runs and use
  Protocol/items normally. Example post spends/run: original trio 47.2 Nudge,
  9.1 Reroll, 2.5 item; Pulse/Engineer/Medic 49.7, 10.1, 2.5; no-Medic 36.6,
  7.4, 2.5.

So the fourth starter has not erased choice, but the choice is uneven: three
compositions span 52.3–60.8% while the one without Strike drops to 38.6%.

## Limitations

1. The simulator deliberately pins reward pools fully unlocked for stable
   balance comparison. These are fresh-*starter-roster* tests, not a simulation
   of a brand-new account's gated item pool. The four cohorts share that same
   pool, so their relative comparison is valid.
2. L1 and L2 are deterministic policy proxies, not player samples. L1's low
   Set use and drafting preferences should not be read as player preference.
3. The random L1 population has 376 Facility runs because operations are
   uniformly sampled. The matched CI sample and four 1,000-run fixed cohorts
   corroborate direction, but a dedicated 2,000-run random-Facility-only cohort
   would tighten the absolute confidence interval.
4. There was no pre-pass fixed-squad quartet, so those four results establish
   post-pass relative choice, not per-squad before/after deltas.
5. `analyze.py`'s optional ridge content screen emitted convergence warnings in
   its bootstrap fit. Descriptive outcome, telemetry, and trace-validation
   results above do not depend on that regression; no invalid state, impossible
   battle, stale data mirror, or failed run was observed.

## Final assessment

The pass moves Facility in the intended *shape*—safe opening, real mid-run
attrition, less boss-concentrated deaths, healthy skill gap—but overshoots in
*magnitude*. The L1 result is 22.1pp lower, not a moderate move, and one
fresh-starter composition is conspicuously weak. **REVERT OR REDUCE THE STAT
PASS.**
