#!/usr/bin/env python3
"""Cycle-4 Phase A: era refresh (Item 1) + Veil diagnosis probes (Item 2a).

Era refresh: L2 and bucket-0 tiers on the CURRENT build (post-Hive-fix,
post-reprice), per-op seed bases 210000+idx*10000 — matched against the
Baseline v3 equiv_* arms. Veil probes: one HP point and one attack point at
0.85 (the Hive method) to identify the efficient lever before any sweep.
"""
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / "scripts" / "sim" / "batch.py"
OPS = ["facility", "hive", "veil", "voidCirclet", "stellarMenagerie"]
BASE = 210000


def run_batch(name: str, extra: list, policy: str = "l1", base: int = BASE) -> None:
    cmd = [sys.executable, str(BATCH), "--name", name, "--runs", "1000",
           "--seed-base", str(base), "--policy", policy,
           "--out-root", str(ROOT / "results" / "cycle4")] + extra
    t0 = time.time()
    proc = subprocess.run(cmd)
    print(f"[CYCLE4A] {name}: rc={proc.returncode} in {time.time()-t0:.0f}s", flush=True)


def main() -> int:
    t0 = time.time()
    for idx, op in enumerate(OPS):
        base = BASE + idx * 10000
        run_batch(f"l2v4_{op}", ["--op", op], policy="l2", base=base)
    for idx, op in enumerate(OPS):
        base = BASE + idx * 10000
        run_batch(f"b0v4_{op}", ["--op", op, "--pool-buckets", "0"], base=base)
    veil_base = BASE + 2 * 10000
    run_batch("veil_hp085", ["--op", "veil", "--tuning", "enemy_hp_scalar@veil=0.85"], base=veil_base)
    run_batch("veil_dmg085", ["--op", "veil", "--tuning", "enemy_dmg_scalar@veil=0.85"], base=veil_base)
    print(f"[CYCLE4A] ALL PHASE-A BATCHES DONE in {(time.time()-t0)/60:.1f} min", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
