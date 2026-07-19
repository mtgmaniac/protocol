#!/usr/bin/env python3
"""Cycle-4 Phase B: Veil HP curve + Tyrant wall sweep + rarity fresh arms.

Veil: HP is the chosen lever (probes tied at 0.85: hp +20.4 vs dmg +19.7;
tiebreak = cascade mechanics — HP literals cascade nowhere). 0.85 already
measured at 34.7%; the curve places the band edges.

Tyrant: mantle_round_shield value 5/4, cadence 2, and value-5 x cadence-2 —
success is death share 83% -> 70-75 with the wall still the game's hardest.

Rarity: fresh current-era forced arms for the four cross-table flags, plus a
fresh mixed control at the same base (the Avalanche selection-bias lesson).
"""
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / "scripts" / "sim" / "batch.py"
VEIL_BASE = 230000
ACC_BASE = 250000
MIX_BASE = 850000


def run_batch(name: str, extra: list, base: int) -> None:
    cmd = [sys.executable, str(BATCH), "--name", name, "--runs", "1000",
           "--seed-base", str(base), "--policy", "l1",
           "--out-root", str(ROOT / "results" / "cycle4")] + extra
    t0 = time.time()
    proc = subprocess.run(cmd)
    print(f"[CYCLE4B] {name}: rc={proc.returncode} in {time.time()-t0:.0f}s", flush=True)


def main() -> int:
    t0 = time.time()
    for val in ("0.82", "0.88", "0.90"):
        run_batch(f"veil_hp{val.replace('.', '')}",
                  ["--op", "veil", "--tuning", f"enemy_hp_scalar@veil={val}"], VEIL_BASE)
    run_batch("tyrant_v5", ["--op", "stellarMenagerie",
              "--tuning", "mantle_round_shield@stellarMenagerie=5"], ACC_BASE)
    run_batch("tyrant_v4", ["--op", "stellarMenagerie",
              "--tuning", "mantle_round_shield@stellarMenagerie=4"], ACC_BASE)
    run_batch("tyrant_c2", ["--op", "stellarMenagerie",
              "--tuning", "mantle_shield_cadence@stellarMenagerie=2"], ACC_BASE)
    run_batch("tyrant_v5c2", ["--op", "stellarMenagerie",
              "--tuning", "mantle_round_shield@stellarMenagerie=5,mantle_shield_cadence@stellarMenagerie=2"], ACC_BASE)
    run_batch("rarity_ctrl", [], MIX_BASE)
    for item in ("priming_charge", "reverse_gimbal", "grounding_clip", "deep_zero_pin"):
        run_batch(f"rarity_{item}", ["--grant", item], MIX_BASE)
    print(f"[CYCLE4B] ALL PHASE-B BATCHES DONE in {(time.time()-t0)/60:.1f} min", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
