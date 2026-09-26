#!/usr/bin/env python3
"""Prove each G-24..G-30 dice criterion detects an injected bad state.

Runs sequentially: each case must exit 1, report its own criterion failing,
and contain no script/runtime errors. Does not modify production source.
"""
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT_BIN", "C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe")


def main():
    out = ROOT / "results/dice_contract"
    out.mkdir(parents=True, exist_ok=True)
    failures = []
    for kind in "abcdefgh":
        proc = subprocess.run([GODOT, "--headless", "--path", str(ROOT),
                               "-s", "scripts/debug/dice_face_gate.gd", "--", f"--break={kind}"],
                              cwd=ROOT, capture_output=True, text=True, timeout=90)
        log = proc.stdout + proc.stderr
        (out / f"mutation_{kind}.log").write_text(log, encoding="utf-8")
        found = re.search(rf"\({kind}\) checks=\d+ failures=([1-9]\d*)", log)
        ok = proc.returncode == 1 and found and "ERROR:" not in log and f"injected violation ({kind})" in log
        print(f"[DICE_MUTATIONS] {kind}: {'detected' if ok else 'FAILED'}", flush=True)
        if not ok:
            failures.append(kind)
    print(f"[DICE_MUTATIONS] {'FAIL' if failures else 'PASS'}: 8 criteria, {len(failures)} missed")
    return bool(failures)


if __name__ == "__main__":
    raise SystemExit(main())
