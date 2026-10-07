#!/usr/bin/env python3
"""Run one headless Godot test clean, then prove it can fail.

    python scripts/checks/break_gate.py --tag AUTO_PICK \
        --script scripts/debug/auto_pick_test.gd \
        --break-arg=--auto-pick-break= --breaks off,any_count,no_cue

The test prints `[TAG] PASS` or `[TAG] FAIL ...`. This runner requires:

    clean        `[TAG] PASS`, no script error
    each break   the same test, launched with <break-arg><mode> (a debug-build
                 seam the game never sets), must print `[TAG] FAIL`. A run that
                 crashes or prints neither line does not count as caught.

Prints `[TAG_GATE] PASS` only when the clean run passes AND every deliberate
break is detected. Used by the `auto-select target` and `no animations` gates.
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get(
    "GODOT_BIN",
    "C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe",
)
RUN_TIMEOUT_S = 90


def run(script: str, extra: list[str]) -> str | None:
    cmd = [GODOT, "--headless", "--path", str(ROOT), "-s", script, "--"] + extra
    try:
        proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=RUN_TIMEOUT_S)
    except subprocess.TimeoutExpired:
        return None
    return (proc.stdout or "") + (proc.stderr or "")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--tag", required=True)
    ap.add_argument("--script", required=True)
    ap.add_argument("--break-arg", required=True)
    ap.add_argument("--breaks", required=True)
    args = ap.parse_args()
    passed, failed = f"[{args.tag}] PASS", f"[{args.tag}] FAIL"
    ok = True

    print("-- clean run", flush=True)
    out = run(args.script, [])
    if out is None:
        print(f"   FAIL timed out after {RUN_TIMEOUT_S}s")
        ok = False
    elif "SCRIPT ERROR" in out or passed not in out:
        ok = False
        lines = [line for line in out.splitlines() if failed in line or "SCRIPT ERROR" in line]
        for line in (lines or out.strip().splitlines()[-8:]):
            print(f"   {line}")
    else:
        print("   ok")

    for mode in [m for m in args.breaks.split(",") if m]:
        print(f"-- deliberate break: {mode}", flush=True)
        out = run(args.script, [args.break_arg + mode])
        caught = [line for line in (out or "").splitlines() if failed + " - " in line]
        if out is not None and failed in out and "SCRIPT ERROR" not in out and passed not in out:
            print(f"   ok   detected ({caught[0].split(' - ', 1)[1] if caught else 'failed'})")
        else:
            reason = "timed out" if out is None else ("still passed" if passed in out else "did not report a failure")
            print(f"   FAIL the test {reason} with '{mode}' - the gate cannot see this break")
            ok = False
    print(f"[{args.tag}_GATE] {'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
