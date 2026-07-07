# Balance sim (headless Godot)

Runs the **real** `combat_manager.gd` head­less — never a reimplementation of
the rules (that's the whole point; the old JS sim drifted and was deleted). Two
laws: **one rules engine** (rules stuck in `battle_scene` get extracted into the
shared UI-free `BattleEngine`, not duplicated) and **determinism** (same seed +
same config → byte-identical JSONL). Full architecture + coupling map:
[`DECOUPLING_NOTES.md`](DECOUPLING_NOTES.md).

> **Rules reference:** [`docs/TRUTH.md`](../../docs/TRUTH.md) is the canonical game-rules
> doc (wins every doc conflict) and documents the current `baseline.json` numbers.

## One run

```bash
GODOT='…/Godot_v4.6.2-stable_win64_console.exe'
"$GODOT" --headless --path . res://scenes/sim/sim_main.tscn -- \
    --seed 12345 --squad pulse,combat,shield --op facility \
    --policy l1 --out results/run.jsonl
```

Flags: `--policy stub|l0|l1|l2` · `--archetype burn|control|protocol|value`
(draft bias, layered on l1/l2) · `--grant id[@unit],…` (force content for a
Stage-2 arm) · `--battles-only N` · `--bench N` (throughput, no JSONL).

Policies: **stub** (auto-target, no spends) · **L0** random-legal (floor) ·
**L1** greedy heuristic (the workhorse; focus fire + band-aware spends) · **L2**
exact round solver (searches order × targets × spends on the real engine).

## Analysis (needs `pip install -r requirements.txt`)

```bash
python scripts/sim/replay.py results/run.jsonl [--battle N | --summary]
python scripts/sim/batch.py --name screen --runs 20000 --policy l1   # parallel
python scripts/sim/analyze.py results/screen -o report.md            # report
python scripts/sim/analyze.py --ab results/arm results/ctrl          # Stage-2
python scripts/sim/analyze.py --skillband results/l1 results/l2      # skill gap
```

`analyze.py` produces the balance report: hero/op clear rates, protocol spend
distribution, keyword realized value, enemy damage-per-appearance, and the
**Stage-1** ridge-logistic content-lift screen (bootstrap CIs). `--ab` is the
**Stage-2** matched-seed causal test; `--skillband` is the L1↔L2 gap.

## Balance workbench (knob sweeps — measurement only)

Sweeps a tunable knob (or a 2-knob grid) across a value range at fixed policy,
**without changing any data file, constant, or combat rule**: values are
injected per run through the `--tuning` seam and vanish with the process. The
knob registry (ids, kinds, ranges, and THE PATTERN FOR ADDING KNOBS) is
[`knobs.json`](knobs.json); sweep.py refuses unknown knobs and out-of-range
values.

```bash
# One knob: where does hive enter the 25-40% skilled-clear band?
python scripts/sim/sweep.py --name hive_hp --knob enemy_hp_scalar@hive \
    --values 0.7,0.8,0.9,1.0 --runs 300

# Small grid (max 2 knobs, cartesian):
python scripts/sim/sweep.py --name exec_chain --knob execute_bonus --values 8,12 \
    --knob chain_ratio --values 0.6,0.8 --runs 300 --policy l2
```

Output → `results/sweeps/<name>/`: `report.md` (per-op and per-hero clear
rates at every point, **deltas vs `baseline.json`**, `✦` flags on any per-op
rate inside the 25–40% target band, and a band summary for the swept op),
`report.csv` (same, flat), `point_*.json` (raw metrics per point).

Knob kinds: `state_scalar` (`enemy_hp_scalar`, `enemy_dmg_scalar` — applied to
enemy states at spawn and to summons; qualify per op with `@op`, e.g.
`enemy_hp_scalar@hive`, or leave global), `engine_tuning` (boss cadence
`scrapmaster_rebuild_pct` / `brood_cadence` / `mantle_round_shield`, plus
`execute_bonus`, `chain_ratio` — routed to `combat_manager.set_tuning()`,
whose getters default to the shipped constants), and `ability_field` (a path
into heroes.data.json — tuning key `ability:heroId/PathName|base/AbilityName/field`
— resolved IN MEMORY against DataManager's loaded hero data at sim spawn,
never written to disk; the registry entry carries a `tuning_key` and sweep.py
translates the knob id automatically). Shipped ability_field knobs cover the
Glacier line's rider values (`glacier_weave_shield`, `glacier_salvo_dmg`,
`glacier_lance_dmg`, `glacier_lance_frozen_bonus`, `glacier_aegis_shield`,
`glacier_zero_dmg`) — measurement prep for the flagged GLACIER repricing;
sweeps inform that ruling, they do not ship numbers.

```bash
# ability_field example: how much does Shatter Lance's frozen bonus matter?
python scripts/sim/sweep.py --name lance_bonus --knob glacier_lance_frozen_bonus \
    --values 2,6,10,14 --runs 300
```

Guarantees (verify after touching the seam):
- **Zero drift when idle:** an empty tuning dict is byte-identical to the
  pre-seam engine — `python scripts/sim/ci_smoke.py` must PASS unchanged.
- **Determinism:** same seed + same `--tuning` → byte-identical JSONL (points
  are seed-matched, so two points differ ONLY by the knob value). Re-check
  with `tests/sim_determinism.sh` after seam changes.
- **Shipping a value:** a sweep result is evidence, not a change. Commit the
  winner as the real constant/data, run the full gate, and the ±10 baseline
  ceremony applies (docs/INVARIANTS.md #9). Knobs behind ruled-pending
  decisions (execute_bonus #9, chain_ratio #10) need their ruling transcribed
  into docs/DECISIONS_RESOLVED.md first.

Worked example (committed): [`docs/sweeps/2026-07-06_hive_hp_example.md`](../../docs/sweeps/2026-07-06_hive_hp_example.md)
— hive enemy-HP scalar 0.7→1.0 plus a 0.72–0.78 refinement, 300 runs/point:
hive enters the 25–40% band at **≈0.75–0.78**, with a breakpoint cliff below
(0.70/0.72 both overshoot to 45.8%). Live sweep outputs land in
`results/sweeps/<name>/` (gitignored); copy reports worth keeping into
`docs/sweeps/`.

## CI regression test

```bash
python scripts/sim/ci_smoke.py                   # diff vs baseline.json (exit≠0 on drift)
python scripts/sim/ci_smoke.py --update-baseline # re-accept after an intended change
```

The sim is byte-deterministic and the CI batch is pinned, so an unchanged tree
reproduces `baseline.json` exactly — any data/rule change that shifts balance
is caught the next morning.

## Files

`sim_runner.gd` + `scenes/sim/sim_main.tscn` (entry) · `roll_provider.gd` /
`seeded_roll_provider.gd` / `physics_roll_provider.gd` (the d20 seam) ·
`telemetry.gd` + `telemetry_schema.md` (JSONL) · `policies/` (stub/L0/L1/L2) ·
`batch.py` / `analyze.py` / `replay.py` / `ci_smoke.py` (Python tooling).
Rules live in `scripts/battle/battle_engine.gd` + `combat_manager.gd`.

## Gate

`tests/sim_determinism.sh [seed]` — a config matrix × all four policies must be
byte-identical across two runs. Run after any change to the sim path.
