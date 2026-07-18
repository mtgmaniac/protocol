#!/usr/bin/env python3
"""Cycle-3 Phase A: sweep grid (heroes + content), mixed-op, matched seeds.

Design: seed base 800000, n=1000/arm, random squads+ops UNLESS the arm sweeps
a hero — hero arms force-include the swept hero, and each swept hero gets its
own forced-inclusion control at CURRENT values (hctrl_*) on the same seeds, so
a hero sweep point's lift is read against its own control (squad composition
held identical per seed). Content arms read against the plain control (c3ctrl).

Protected heroes (avalanche, breaker, engineer) and taunt/Synod mechanics are
untouched by construction — no arm here references them.
"""
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / "scripts" / "sim" / "batch.py"
BASE = 800000
N = "1000"


def run_batch(name: str, extra: list) -> None:
    cmd = [sys.executable, str(BATCH), "--name", name, "--runs", N,
           "--seed-base", str(BASE), "--policy", "l1",
           "--out-root", str(ROOT / "results" / "cycle3")] + extra
    t0 = time.time()
    proc = subprocess.run(cmd)
    print(f"[CYCLE3A] {name}: rc={proc.returncode} in {time.time()-t0:.0f}s", flush=True)


# (name, extra-args) — hero sweep points express changes via the ability_field
# tuning seam (in-memory, measurement only) / --hero-hp.
ARMS = [
    # Controls
    ("c3ctrl", []),
    ("hctrl_shield", ["--include-hero", "shield"]),
    ("hctrl_ghost", ["--include-hero", "ghost"]),
    ("hctrl_combat", ["--include-hero", "combat"]),
    ("hctrl_medic", ["--include-hero", "medic"]),
    # SHIELD floor-raise (op-agnostic only: base HP / non-taunt shield values)
    ("shield_S1_hp65", ["--include-hero", "shield", "--hero-hp", "shield=65"]),
    ("shield_S2_shields", ["--include-hero", "shield",
     "--tuning", "ability:shield/base/Enforce/shield=9,ability:shield/base/Spike Stance/shield=7"]),
    ("shield_S3_mixed", ["--include-hero", "shield", "--hero-hp", "shield=60",
     "--tuning", "ability:shield/base/Enforce/shield=8"]),
    # GHOST flat tax (cloak untouched)
    ("ghost_G1_minus1", ["--include-hero", "ghost",
     "--tuning", "ability:ghost/base/Probe Strike/dmg=6,ability:ghost/base/System Breach/dmg=8,"
                 "ability:ghost/base/Phase Blade/dmg=12,ability:ghost/base/Execution Protocol/dmg=15"]),
    ("ghost_G2_minus2", ["--include-hero", "ghost",
     "--tuning", "ability:ghost/base/Probe Strike/dmg=5,ability:ghost/base/System Breach/dmg=7,"
                 "ability:ghost/base/Phase Blade/dmg=12,ability:ghost/base/Execution Protocol/dmg=14"]),
    # COMBAT carve — Candidate B "Terminal Ballistics" (Rail Strike -> finisher)
    ("combat_C1_carve_trim", ["--include-hero", "combat",
     "--tuning", "ability:combat/base/Rail Strike/dmg=8,ability:combat/base/Rail Strike/execute=1,"
                 "ability:combat/base/Suppression Fire/dmg=6"]),
    ("combat_C2_carve_lite", ["--include-hero", "combat",
     "--tuning", "ability:combat/base/Rail Strike/dmg=9,ability:combat/base/Rail Strike/execute=1,"
                 "ability:combat/base/Suppression Fire/dmg=6"]),
    ("combat_C3_carve_only", ["--include-hero", "combat",
     "--tuning", "ability:combat/base/Rail Strike/dmg=8,ability:combat/base/Rail Strike/execute=1"]),
    # MEDIC numeric buff (branch B: heal content profiles fine)
    ("medic_M1_heals", ["--include-hero", "medic",
     "--tuning", "ability:medic/base/Diagnostic Pulse/heal=6,ability:medic/base/Infusion/heal=11"]),
    ("medic_M2_heals_big", ["--include-hero", "medic",
     "--tuning", "ability:medic/base/Diagnostic Pulse/heal=7,ability:medic/base/Infusion/heal=12"]),
    ("medic_M3_heals_hp", ["--include-hero", "medic", "--hero-hp", "medic=55",
     "--tuning", "ability:medic/base/Diagnostic Pulse/heal=6,ability:medic/base/Infusion/heal=11"]),
    # OVERCHARGE nerf sweep (130% -> 110/115/120)
    ("oc_110", ["--grant", "overcharge", "--item-field", "overcharge/mult=1.10"]),
    ("oc_115", ["--grant", "overcharge", "--item-field", "overcharge/mult=1.15"]),
    ("oc_120", ["--grant", "overcharge", "--item-field", "overcharge/mult=1.20"]),
    # IRON CURTAIN nerf sweep (75% -> 85/88/90)
    ("ic_085", ["--grant", "ironCurtain", "--item-field", "ironCurtain/mult=0.85"]),
    ("ic_088", ["--grant", "ironCurtain", "--item-field", "ironCurtain/mult=0.88"]),
    ("ic_090", ["--grant", "ironCurtain", "--item-field", "ironCurtain/mult=0.90"]),
    # PREDATOR LENS rider vs Neural Splice reference (same seeds)
    ("pred_current", ["--grant", "predator_lens"]),
    ("splice_ref", ["--grant", "neural_splice"]),
    ("pred_rider1", ["--grant", "predator_lens",
     "--item-field", "predator_lens/type=rollBonusNat20Protocol;predator_lens/protocol=1"]),
]


def main() -> int:
    t0 = time.time()
    for name, extra in ARMS:
        run_batch(name, extra)
    print(f"[CYCLE3A] ALL PHASE-A BATCHES DONE in {(time.time()-t0)/60:.1f} min", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
