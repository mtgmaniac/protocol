#!/usr/bin/env python3
"""Cycle-0 batch driver (Balance re-baseline — MEASUREMENT ONLY).

Runs the four Cycle-0 arms sequentially via batch.py:

  1. baseline_v2_<op>  — L1, fixed op, random squads, 1000 runs/op
  2. l2_<op>           — L2 on the SAME seed sets (decision-density gap)
  3. b0_<op>           — L1 + --pool-buckets 0 on the SAME seeds (new-player pool;
                         explicitly NON-baseline)
  4. outlier control + one --grant arm per non-boss item id (matched seeds)

Seed discipline: per-op seed base is fixed (BASE_OP + index*10000), identical
across arms 1-3, so every (seed, squad, op) triple matches across policy tiers
and pool restriction. Outlier arms all share OUTLIER_BASE, so every arm is
matched-seed against the shared control.

CI math (recorded in the dashboard): n=1000/op gives a 95% CI half-width of
at most ±3.1pp on a single rate (worst case p=0.5); matched-seed pairing makes
the L1/L2 and B0 comparisons tighter than independent-sample math. Outlier arms
n=500: two-proportion SE vs control ≈ 2.9pp at p≈0.3 → 95% CI ≈ ±5.7pp
(conservative; matched seeds correlate outcomes, shrinking true SE), so the
±5pp flag is a SCREEN, not a confirmation.
"""
import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / "scripts" / "sim" / "batch.py"

OPS = ["facility", "hive", "veil", "voidCirclet", "stellarMenagerie"]
RUNS_PER_OP = 1000
BASE_OP = 210000          # per-op seed base = BASE_OP + op_index * 10000
OUTLIER_BASE = 500000
OUTLIER_RUNS = 500


def run_batch(name: str, extra: list) -> None:
    cmd = [sys.executable, str(BATCH), "--name", name, "--out-root",
           str(ROOT / "results" / "cycle0")] + extra
    t0 = time.time()
    proc = subprocess.run(cmd)
    print(f"[CYCLE0] {name}: rc={proc.returncode} in {time.time()-t0:.0f}s", flush=True)
    if proc.returncode != 0:
        print(f"[CYCLE0] WARNING: {name} had failures", flush=True)


def grantable_ids() -> list:
    items = json.loads((ROOT / "data/raw/items.data.json").read_text(encoding="utf-8"))
    gear = json.loads((ROOT / "data/raw/gear.data.json").read_text(encoding="utf-8"))
    relics = json.loads((ROOT / "data/raw/relics.data.json").read_text(encoding="utf-8"))
    ids = [e["id"] for e in items["items"]]
    ids += [e["id"] for e in gear["gear"]]
    ids += [e["id"] for e in relics if not e.get("bossRelic", False)]
    return ids


def main() -> int:
    t0 = time.time()
    # 1-3: per-op arms, matched seed bases.
    for idx, op in enumerate(OPS):
        base = BASE_OP + idx * 10000
        run_batch(f"baseline_v2_{op}",
                  ["--runs", str(RUNS_PER_OP), "--policy", "l1", "--op", op,
                   "--seed-base", str(base)])
    for idx, op in enumerate(OPS):
        base = BASE_OP + idx * 10000
        run_batch(f"l2_{op}",
                  ["--runs", str(RUNS_PER_OP), "--policy", "l2", "--op", op,
                   "--seed-base", str(base)])
    for idx, op in enumerate(OPS):
        base = BASE_OP + idx * 10000
        run_batch(f"b0_{op}",
                  ["--runs", str(RUNS_PER_OP), "--policy", "l1", "--op", op,
                   "--seed-base", str(base), "--pool-buckets", "0"])
    # 4: outlier screen — shared control + one grant arm per id, matched seeds.
    run_batch("outlier_control",
              ["--runs", str(OUTLIER_RUNS), "--seed-base", str(OUTLIER_BASE),
               "--policy", "l1"])
    for item_id in grantable_ids():
        run_batch(f"arm_{item_id}",
                  ["--runs", str(OUTLIER_RUNS), "--seed-base", str(OUTLIER_BASE),
                   "--policy", "l1", "--grant", item_id])
    print(f"[CYCLE0] ALL BATCHES DONE in {(time.time()-t0)/60:.1f} min", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
