#!/usr/bin/env python3
"""commit-msg hook body: the baseline ceremony (docs/INVARIANTS.md #9, G-58).

The sim pins are scripts/sim/baseline.json (the l1 tripwire, 300 runs) and
scripts/sim/baseline_pins.json (the l1_evo2 tripwire and both 1,500-run size
pins). When either is staged:

1. The two files must have been written together (`pinned_with`). Re-pinning
   only the tripwire would hide a change from the size check for good. No
   token overrides this: run `ci_smoke.py --update-baseline`.
2. If a SIZE pin moves beyond the size line vs HEAD (ci_smoke.SIZE_OP_PTS per
   operation, ci_smoke.SIZE_OVERALL_PTS overall), the commit is ABORTED unless
   the message contains BASELINE-APPROVED-BY-KEV. A human signs off on a real
   move that size (precedents: voidCirclet +26, freeze=repeat -27.7).

The 300-run tripwire pins are not judged: a move there says combat changed,
and its size is noise (G-57). Dumb and loud on purpose.
Usage (from the commit-msg shim): baseline_ceremony.py <msg-file>
"""
import hashlib
import json
import re
import subprocess
import sys

BASELINE = "scripts/sim/baseline.json"
PINS = "scripts/sim/baseline_pins.json"
CI_SMOKE = "scripts/sim/ci_smoke.py"
TOKEN = "BASELINE-APPROVED-BY-KEV"


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True,
                          encoding="utf-8", errors="replace").stdout


def digest(metrics: dict) -> str:
    """Must equal ci_smoke.digest (the sim size break gate checks that it does)."""
    return hashlib.sha256(json.dumps(metrics, sort_keys=True).encode("utf-8")).hexdigest()


def read_line(name: str):
    """The size line lives in ci_smoke.py only; read the version being committed."""
    m = re.search(r"^%s\s*=\s*(-?[0-9.]+)" % re.escape(name), git("show", f":{CI_SMOKE}"), re.MULTILINE)
    return float(m.group(1)) if m else None


def beyond_the_line(old: dict, new: dict, op_pts: float, overall_pts: float) -> list:
    out = []
    for policy in sorted(set(old) | set(new)):
        a, b = old.get(policy), new.get(policy)
        if a is None or b is None:
            continue  # a policy pinned for the first time has nothing to compare
        d = round((b["overall_clear"] - a["overall_clear"]) * 100, 2)
        if abs(d) > overall_pts:
            out.append(f"{policy} overall {a['overall_clear']:.4f} -> {b['overall_clear']:.4f} ({d:+.1f} pts, line {overall_pts:g})")
        for op in sorted(set(a["clear_by_op"]) | set(b["clear_by_op"])):
            x, y = a["clear_by_op"].get(op, 0.0), b["clear_by_op"].get(op, 0.0)
            d = round((y - x) * 100, 2)
            if abs(d) > op_pts:
                out.append(f"{policy} {op} {x:.4f} -> {y:.4f} ({d:+.1f} pts, line {op_pts:g})")
    return out


def main() -> int:
    staged = git("diff", "--cached", "--name-only").split()
    if BASELINE not in staged and PINS not in staged:
        return 0
    try:
        base = json.loads(git("show", f":{BASELINE}"))
        pins = json.loads(git("show", f":{PINS}"))
    except Exception as exc:  # noqa: BLE001
        print(f"[CEREMONY] cannot read the sim pins as committed ({exc}).")
        print(f"[CEREMONY] {BASELINE} and {PINS} are written together by ci_smoke.py --update-baseline. Aborting.")
        return 1
    if pins.get("pinned_with") != digest(base):
        print(f"[CEREMONY] COMMIT ABORTED: {PINS} was not written together with {BASELINE}.")
        print("[CEREMONY] Re-pinning one without the other hides a change from the size check.")
        print("[CEREMONY] Run: python scripts/sim/ci_smoke.py --update-baseline, and stage both files.")
        return 1
    head_raw = git("show", f"HEAD:{PINS}")
    if not head_raw.strip():
        return 0  # the first size pins: nothing to compare
    op_pts, overall_pts = read_line("SIZE_OP_PTS"), read_line("SIZE_OVERALL_PTS")
    if op_pts is None or overall_pts is None:
        print(f"[CEREMONY] cannot read the size line from {CI_SMOKE}; refusing to guess. Aborting.")
        return 1
    try:
        beyond = beyond_the_line(json.loads(head_raw).get("size", {}), pins.get("size", {}), op_pts, overall_pts)
    except Exception as exc:  # noqa: BLE001
        print(f"[CEREMONY] cannot compare the size pins ({exc}); refusing to guess. Aborting.")
        return 1
    if not beyond:
        return 0
    msg = open(sys.argv[1], encoding="utf-8", errors="replace").read()
    if TOKEN in msg:
        print(f"[CEREMONY] size-pin move beyond the line approved via {TOKEN}:")
        for line in beyond:
            print(f"[CEREMONY]   {line}")
        return 0
    print("[CEREMONY] COMMIT ABORTED: the 1,500-run size pins move beyond the line:")
    for line in beyond:
        print(f"[CEREMONY]   {line}")
    print("[CEREMONY] A human signs off on a real move this size (docs/INVARIANTS.md #9;")
    print("[CEREMONY] precedent: the voidCirclet +26 incident). If Kev has approved,")
    print(f"[CEREMONY] add the literal token {TOKEN} to the commit message and retry.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
