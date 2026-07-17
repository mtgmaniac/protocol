#!/usr/bin/env python3
"""Cycle-1 Stage-1 Phase A batches (Fix Hive — measurement).

Hive arms all use seed-base 220000 = Cycle-0 baseline_v2_hive, so every arm is
matched-seed against the v2 hive baseline AND each other. Riders reuse their
Cycle-0 counterpart bases (l2_b0: 210000 = facility; recal: 500000 = outlier
control) for the same reason.

Phase B (combined best-scalar x best-comp + its L2 confirm) launches after
Phase A results pick the winners.
"""
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / "scripts" / "sim" / "batch.py"
HIVE_BASE = 220000


def run_batch(name: str, extra: list) -> None:
    cmd = [sys.executable, str(BATCH), "--name", name, "--out-root",
           str(ROOT / "results" / "cycle1")] + extra
    t0 = time.time()
    proc = subprocess.run(cmd)
    print(f"[CYCLE1A] {name}: rc={proc.returncode} in {time.time()-t0:.0f}s", flush=True)


def main() -> int:
    t0 = time.time()
    for val in ("0.72", "0.75", "0.78", "0.81"):
        run_batch(f"hive_hp{val.replace('.', '')}",
                  ["--runs", "1000", "--policy", "l1", "--op", "hive",
                   "--seed-base", str(HIVE_BASE),
                   "--tuning", f"enemy_hp_scalar@hive={val}"])
    run_batch("hive_dmg085",
              ["--runs", "1000", "--policy", "l1", "--op", "hive",
               "--seed-base", str(HIVE_BASE),
               "--tuning", "enemy_dmg_scalar@hive=0.85"])
    run_batch("hive_compA",  # b4: heavy + fodder (kills the double-Stalker roll)
              ["--runs", "1000", "--policy", "l1", "--op", "hive",
               "--seed-base", str(HIVE_BASE), "--battle-slots", "4=heavy,fodder"])
    run_batch("hive_compB",  # b4: elite + 2 fodder (one Stalker, swarm flavor)
              ["--runs", "1000", "--policy", "l1", "--op", "hive",
               "--seed-base", str(HIVE_BASE), "--battle-slots", "4=elite,fodder,fodder"])
    # Riders
    run_batch("l2_b0_facility",
              ["--runs", "1000", "--policy", "l2", "--op", "facility",
               "--seed-base", "210000", "--pool-buckets", "0"])
    run_batch("recal_overcharge",
              ["--runs", "500", "--policy", "l1", "--seed-base", "500000",
               "--grant", "overcharge"])
    run_batch("recal_ironCurtain",
              ["--runs", "500", "--policy", "l1", "--seed-base", "500000",
               "--grant", "ironCurtain"])
    print(f"[CYCLE1A] ALL PHASE-A BATCHES DONE in {(time.time()-t0)/60:.1f} min", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
