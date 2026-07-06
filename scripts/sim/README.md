# Balance sim (headless Godot)

Runs the **real** `combat_manager.gd` head­less — never a reimplementation of
the rules (that's the whole point; the old JS sim drifted and was deleted). Two
laws: **one rules engine** (rules stuck in `battle_scene` get extracted into the
shared UI-free `BattleEngine`, not duplicated) and **determinism** (same seed +
same config → byte-identical JSONL). Full architecture + coupling map:
[`DECOUPLING_NOTES.md`](DECOUPLING_NOTES.md).

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
