#!/usr/bin/env python3
"""Build I Stage-2 re-measure: fresh controls + 3x5 hero portfolio + combined.

Post-kit-surgery build. Controls are fresh (kit changes shift every random
squad containing the three heroes). Hero arms force-include one changed hero;
the combined arm fixes the squad to all three (shield,medic,combat). Per-op
seed bases 210000+idx*10000 as always.
"""
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / "scripts" / "sim" / "batch.py"
OPS = ["facility", "hive", "veil", "voidCirclet", "stellarMenagerie"]
BASE = 210000


def run_batch(name: str, extra: list, base: int) -> None:
    cmd = [sys.executable, str(BATCH), "--name", name, "--runs", "1000",
           "--seed-base", str(base), "--policy", "l1",
           "--out-root", str(ROOT / "results" / "buildI")] + extra
    t0 = time.time()
    proc = subprocess.run(cmd)
    print(f"[BUILDI] {name}: rc={proc.returncode} in {time.time()-t0:.0f}s", flush=True)


def main() -> int:
    t0 = time.time()
    for idx, op in enumerate(OPS):
        base = BASE + idx * 10000
        run_batch(f"ctrl_{op}", ["--op", op], base)
    for hero in ("shield", "medic", "combat"):
        for idx, op in enumerate(OPS):
            base = BASE + idx * 10000
            run_batch(f"h_{hero}_{op}", ["--op", op, "--include-hero", hero], base)
    for idx, op in enumerate(OPS):
        base = BASE + idx * 10000
        run_batch(f"trio_{op}", ["--op", op, "--squad", "shield,medic,combat"], base)
    print(f"[BUILDI] ALL STAGE-2 BATCHES DONE in {(time.time()-t0)/60:.1f} min", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
