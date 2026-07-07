#!/usr/bin/env python3
"""commit-msg hook body: the threshold ratchet (docs/INVARIANTS.md #13).

RAISING any enforcement threshold requires BASELINE-APPROVED-BY-KEV in the
commit message; LOWERING is always free. Precedent: the battle_scene watermark
3378->3416 self-raise. Dumb and loud. Usage: threshold_guard.py <msg-file>
"""
import re
import subprocess
import sys

TOKEN = "BASELINE-APPROVED-BY-KEV"

# (file, constant, direction) triplets guarded. direction "max": RAISING
# loosens (needs the token); "min": LOWERING loosens (floors, e.g. required
# audit pass count). Tightening is always free. Adding a threshold? List it.
WATCHED = [
    ("scripts/hooks/battle_scene_growth.py", "HIGH_WATER_LINES", "max"),
    ("scripts/hooks/baseline_ceremony.py", "CEREMONY_PTS", "max"),
    ("scripts/sim/ci_smoke.py", "TOL_OVERALL", "max"),
    ("scripts/sim/ci_smoke.py", "TOL_OP", "max"),
    ("scripts/sim/ci_smoke.py", "TOL_HERO", "max"),
    ("scripts/sim/ci_smoke.py", "TOL_LIFT", "max"),
    ("scripts/verify_gate.py", "AUDIT_MIN_PASSED", "min"),
]


def git_show(ref: str) -> str:
    return subprocess.run(["git", "show", ref], capture_output=True, text=True,
                          encoding="utf-8", errors="replace").stdout


def read_const(source: str, name: str):
    m = re.search(rf"^{name}\s*=\s*([0-9.]+)", source, re.MULTILINE)
    return float(m.group(1)) if m else None


def main() -> int:
    staged_files = subprocess.run(["git", "diff", "--cached", "--name-only"],
                                  capture_output=True, text=True,
                                  encoding="utf-8", errors="replace").stdout.split()
    raises = []
    for path, const, direction in WATCHED:
        if path not in staged_files:
            continue
        old = read_const(git_show(f"HEAD:{path}"), const)
        new = read_const(git_show(f":{path}"), const)
        if old is None or new is None:
            continue  # constant renamed/added — the invariant text is the backstop
        loosened = new > old if direction == "max" else new < old
        if loosened:
            raises.append(f"{path}::{const} {old:g} -> {new:g} ({direction} threshold loosened)")
    if not raises:
        return 0
    msg = open(sys.argv[1], encoding="utf-8", errors="replace").read()
    if TOKEN in msg:
        print("[RATCHET] threshold raise approved via %s:" % TOKEN)
        for line in raises:
            print(f"[RATCHET]   {line}")
        return 0
    print("[RATCHET] COMMIT ABORTED — enforcement threshold RAISED without sign-off:")
    for line in raises:
        print(f"[RATCHET]   {line}")
    print("[RATCHET] Raising a threshold loosens enforcement (docs/INVARIANTS.md #13;")
    print(f"[RATCHET] precedent: the 3378->3416 watermark self-raise). Lowering is free.")
    print(f"[RATCHET] If Kev approved, add the literal token {TOKEN} to the message.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
