#!/usr/bin/env python3
"""Cycle-3 Phase B: combined per-op arms + refreshed hero rows + Shield L2 pair.

Winners under test (Stage-2 candidates):
  Ghost G2   — Probe 5 / Breach 7 / Blade 12 / Exec 14 (flat tax)
  Combat C1  — Rail 8 + execute / Suppression 6 (carve; MEAN MISS FLAGGED —
               Phase B measures whether the spread criterion lands)
  Medic M5   — Diagnostic 8 / Infusion 14 / hp 55
  Shield     — NO CHANGE (defer recommendation; L2 mixed pair = evidence)
  Content    — overcharge 1.10, ironCurtain 0.90, predator_lens rider (+3 & +1
               Protocol on 20)

comb_<op>: everything together, system-level (content via item-field so the
repriced items appear in natural drafts), vs ctrl_<op> (Cycle-2 v2.1, same
seeds, same policy era). Hero rows isolate each hero change alone.
"""
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / "scripts" / "sim" / "batch.py"
OPS = ["facility", "hive", "veil", "voidCirclet", "stellarMenagerie"]
BASE = 210000

G2 = ("ability:ghost/base/Probe Strike/dmg=5,ability:ghost/base/System Breach/dmg=7,"
      "ability:ghost/base/Phase Blade/dmg=12,ability:ghost/base/Execution Protocol/dmg=14")
C1 = ("ability:combat/base/Rail Strike/dmg=8,ability:combat/base/Rail Strike/execute=1,"
      "ability:combat/base/Suppression Fire/dmg=6")
M5 = "ability:medic/base/Diagnostic Pulse/heal=8,ability:medic/base/Infusion/heal=14"
ITEMS = ("overcharge/mult=1.10;ironCurtain/mult=0.90;"
         "predator_lens/type=rollBonusNat20Protocol;predator_lens/protocol=1")


def run_batch(name: str, extra: list, runs: str = "1000", policy: str = "l1",
              base: int = BASE) -> None:
    cmd = [sys.executable, str(BATCH), "--name", name, "--runs", runs,
           "--seed-base", str(base), "--policy", policy,
           "--out-root", str(ROOT / "results" / "cycle3")] + extra
    t0 = time.time()
    proc = subprocess.run(cmd)
    print(f"[CYCLE3B] {name}: rc={proc.returncode} in {time.time()-t0:.0f}s", flush=True)


def main() -> int:
    t0 = time.time()
    for idx, op in enumerate(OPS):
        base = BASE + idx * 10000
        combined_tuning = ",".join([G2, C1, M5])
        run_batch(f"comb_{op}",
                  ["--op", op, "--tuning", combined_tuning, "--hero-hp", "medic=55",
                   "--item-field", ITEMS], base=base)
    for idx, op in enumerate(OPS):
        base = BASE + idx * 10000
        run_batch(f"g2_{op}", ["--op", op, "--include-hero", "ghost",
                               "--tuning", G2], base=base)
        run_batch(f"c1_{op}", ["--op", op, "--include-hero", "combat",
                               "--tuning", C1], base=base)
        run_batch(f"m5_{op}", ["--op", op, "--include-hero", "medic",
                               "--tuning", M5, "--hero-hp", "medic=55"], base=base)
    # Shield skill-test pair (mixed-op L2) — deferral evidence.
    run_batch("ctrl_l2_mixed", [], policy="l2", base=800000)
    run_batch("shield_l2_mixed", ["--include-hero", "shield"], policy="l2", base=800000)
    print(f"[CYCLE3B] ALL PHASE-B BATCHES DONE in {(time.time()-t0)/60:.1f} min", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
