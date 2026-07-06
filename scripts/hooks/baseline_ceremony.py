#!/usr/bin/env python3
"""commit-msg hook body: the baseline ceremony (docs/INVARIANTS.md #9).

If scripts/sim/baseline.json is staged and ANY per-op clear rate moves more
than ±10 points vs HEAD, the commit is ABORTED unless the commit message
contains BASELINE-APPROVED-BY-KEV. Encodes the rule that a human signs off on
large balance drift (precedents: voidCirclet +26, freeze=repeat −27.7).
Dumb and loud on purpose. Usage (from the commit-msg shim): baseline_ceremony.py <msg-file>
"""
import json
import subprocess
import sys

BASELINE = "scripts/sim/baseline.json"
CEREMONY_PTS = 10.0
TOKEN = "BASELINE-APPROVED-BY-KEV"


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True,
                          encoding="utf-8", errors="replace").stdout


def main() -> int:
    staged = git("diff", "--cached", "--name-only")
    if BASELINE not in staged.split():
        return 0
    head_raw = git("show", f"HEAD:{BASELINE}")
    if not head_raw.strip():
        return 0  # first baseline ever — nothing to compare
    staged_raw = git("show", f":{BASELINE}")
    try:
        old = json.loads(head_raw)["clear_by_op"]
        new = json.loads(staged_raw)["clear_by_op"]
    except Exception as exc:  # noqa: BLE001
        print(f"[CEREMONY] cannot parse baseline.json ({exc}) — refusing to guess. Aborting.")
        return 1
    beyond = []
    for op in sorted(set(old) | set(new)):
        d = (new.get(op, 0.0) - old.get(op, 0.0)) * 100
        if abs(d) > CEREMONY_PTS:
            beyond.append(f"{op} {old.get(op, 0.0):.4f} -> {new.get(op, 0.0):.4f} ({d:+.1f} pts)")
    if not beyond:
        return 0
    msg = open(sys.argv[1], encoding="utf-8", errors="replace").read()
    if TOKEN in msg:
        print(f"[CEREMONY] baseline drift beyond ±10 approved via {TOKEN}:")
        for line in beyond:
            print(f"[CEREMONY]   {line}")
        return 0
    print("[CEREMONY] COMMIT ABORTED — baseline.json update with per-op drift beyond ±10 points:")
    for line in beyond:
        print(f"[CEREMONY]   {line}")
    print(f"[CEREMONY] A human signs off on drift this size (docs/INVARIANTS.md #9;")
    print(f"[CEREMONY] precedent: the voidCirclet +26 incident). If Kev has approved,")
    print(f"[CEREMONY] add the literal token {TOKEN} to the commit message and retry.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
