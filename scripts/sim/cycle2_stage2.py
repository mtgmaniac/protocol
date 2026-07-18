#!/usr/bin/env python3
"""Cycle-2 Stage-2 flag arms (content portfolio confirmations).

- overcharge / ironCurtain: forced per-op profiles (are they flat-OP or
  spiked-OP?) — 2 x 5 ops x 1000 L1 vs the Cycle-2 per-op controls
  (ctrl_<op>, same seed bases).
- Dead-relic dozen: fresh mixed-op control + L1 arms + the L2 confirm cells
  (the Cycle-0 conditional-content gate, finally executed). All post-taunt-fix,
  post-bake, additive relic estimand (grants ride the directive slot).
"""
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / "scripts" / "sim" / "batch.py"

OPS = ["facility", "hive", "veil", "voidCirclet", "stellarMenagerie"]
BASE = 210000
MIX_BASE = 700000
DEAD_DOZEN = ["curatedCache", "martyrdomProtocol", "overflowBuffer", "overflowVent",
              "twinFates", "mercyProtocol", "salvageDirective", "chainDoctrine",
              "scavengerManifest", "resonanceCascade", "protocolOverride", "standingOrder"]


def run_batch(name: str, extra: list) -> None:
    cmd = [sys.executable, str(BATCH), "--name", name, "--out-root",
           str(ROOT / "results" / "cycle2")] + extra
    t0 = time.time()
    proc = subprocess.run(cmd)
    print(f"[CYCLE2S2] {name}: rc={proc.returncode} in {time.time()-t0:.0f}s", flush=True)


def main() -> int:
    t0 = time.time()
    # overcharge / ironCurtain per-op profiles (vs ctrl_<op>, matched seeds).
    for relic in ("overcharge", "ironCurtain"):
        for idx, op in enumerate(OPS):
            run_batch(f"flag_{relic}_{op}",
                      ["--runs", "1000", "--policy", "l1", "--op", op,
                       "--seed-base", str(BASE + idx * 10000), "--grant", relic])
    # Dead-dozen: mixed-op controls (L1 + L2), then arms at both tiers.
    run_batch("mixctrl_l1", ["--runs", "500", "--policy", "l1", "--seed-base", str(MIX_BASE)])
    run_batch("mixctrl_l2", ["--runs", "500", "--policy", "l2", "--seed-base", str(MIX_BASE)])
    for relic in DEAD_DOZEN:
        run_batch(f"dead_{relic}_l1",
                  ["--runs", "500", "--policy", "l1", "--seed-base", str(MIX_BASE),
                   "--grant", relic])
        run_batch(f"dead_{relic}_l2",
                  ["--runs", "500", "--policy", "l2", "--seed-base", str(MIX_BASE),
                   "--grant", relic])
    print(f"[CYCLE2S2] ALL STAGE-2 BATCHES DONE in {(time.time()-t0)/60:.1f} min", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
