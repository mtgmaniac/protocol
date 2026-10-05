#!/usr/bin/env python3
"""Reroll hop gate (G-47, Kev 2026-10-05).

Runs scripts/debug/reroll_hop_gate.gd: 1,000 rerolls on a six-die tray, each a
real hop in the die's own slot, judged on every physics step:

    uniform   landed faces uniform over 1-20 (chi-square, p 0.001)
    contact   the hopping die never touches another die; no other die moves
    slot      the hopping die never leaves its slot
    snap      the face that lands up is the face that ends up (the snap never
              changes it) and it is the raw roll

Then proves it can fail: each deliberate break (passed only to the test via
--break) must exit 1 with its own criterion failing.

Exit 0 = the clean run passes AND every break is detected.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get(
    "GODOT_BIN",
    "C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe",
)
SCRIPT = "scripts/debug/reroll_hop_gate.gd"
CLEAN_HOPS = 1000
BREAK_HOPS = 40
BREAKS = ["uniform", "contact", "slot", "snap"]
LEG_TIMEOUT_S = 600


def run(extra: list[str]) -> tuple[int, str]:
    cmd = [GODOT, "--headless", "--path", str(ROOT), "-s", SCRIPT, "--"] + extra
    try:
        proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=LEG_TIMEOUT_S)
    except subprocess.TimeoutExpired:
        return -1, f"TIMED OUT after {LEG_TIMEOUT_S}s"
    return proc.returncode, proc.stdout + proc.stderr


def main() -> int:
    ok = True
    print(f"-- clean: {CLEAN_HOPS} rerolls", flush=True)
    rc, log = run([f"--n={CLEAN_HOPS}"])
    for line in log.splitlines():
        if line.startswith("[REROLL_HOP]") and "PASS" not in line and "FAIL" not in line:
            print("   " + line)
    if rc != 0 or "[REROLL_HOP] PASS" not in log or "SCRIPT ERROR" in log:
        print(f"   FAIL clean run (rc {rc})")
        ok = False
    for kind in BREAKS:
        print(f"-- deliberate break: {kind}", flush=True)
        rc, log = run([f"--n={BREAK_HOPS}", f"--break={kind}"])
        caught = re.search(rf"\({kind}\) failures=([1-9]\d*)", log)
        if rc == 1 and caught and f"injected violation ({kind})" in log and "SCRIPT ERROR" not in log:
            print(f"   ok   detected ({kind} failures={caught.group(1)})")
        else:
            print(f"   FAIL the '{kind}' break was not detected (rc {rc})")
            ok = False
    print(f"[REROLL_HOP_GATE] {'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
