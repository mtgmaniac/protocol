#!/usr/bin/env python3
"""Cycle-2 Stage-1 batches: controls v2.1 + the 8x5 hero portfolio.

Controls are re-run because BOTH the Cycle-1 Hive bake and the Cycle-2 taunt
policy fix changed run outcomes — the Cycle-0 controls are a different era.
Same per-op seed bases as Cycle 0 (210000 + idx*10000), so seeds stay the
canonical per-op sets.

Hero arms: forced inclusion (hero + 2 uniform others) on the SAME seeds per
op. Lift = P(win | hero forced) - P(win | control) on matched seeds.
n=1000/cell -> per-cell lift SE ~= 2.1pp at p~0.3 (conservative independent
bound); the 5-op MEAN's SE ~= 0.9pp.
"""
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / "scripts" / "sim" / "batch.py"

OPS = ["facility", "hive", "veil", "voidCirclet", "stellarMenagerie"]
HEROES = ["pulse", "combat", "shield", "avalanche", "medic", "engineer", "ghost", "breaker"]
BASE = 210000


def run_batch(name: str, extra: list) -> None:
    cmd = [sys.executable, str(BATCH), "--name", name, "--out-root",
           str(ROOT / "results" / "cycle2")] + extra
    t0 = time.time()
    proc = subprocess.run(cmd)
    print(f"[CYCLE2] {name}: rc={proc.returncode} in {time.time()-t0:.0f}s", flush=True)


def main() -> int:
    t0 = time.time()
    for idx, op in enumerate(OPS):
        run_batch(f"ctrl_{op}",
                  ["--runs", "1000", "--policy", "l1", "--op", op,
                   "--seed-base", str(BASE + idx * 10000)])
    for hero in HEROES:
        for idx, op in enumerate(OPS):
            run_batch(f"hero_{hero}_{op}",
                      ["--runs", "1000", "--policy", "l1", "--op", op,
                       "--seed-base", str(BASE + idx * 10000),
                       "--include-hero", hero])
    print(f"[CYCLE2] ALL STAGE-1 BATCHES DONE in {(time.time()-t0)/60:.1f} min", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
