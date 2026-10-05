#!/usr/bin/env python3
"""Reroll hop gate (G-47, Kev 2026-10-05).

Runs scripts/debug/reroll_hop_gate.gd: 10,000 rerolls on a six-die tray, each a
real hop in the die's own slot, judged on every physics step. The hops are
sharded over several Godot processes (physics is single-threaded) and pooled:

    uniform   landed faces uniform over 1-20 (chi-square), AND uniform for dice
              that start on 1-5, 6-10, 11-15 and 16-20 each, AND a die lands on
              its own starting face about 1 time in 20
    contact   the hopping die never touches another die; no other die moves
    slot      the hopping die never leaves its slot
    snap      the face that lands up is the face that ends up (the snap never
              changes it) and it is the raw roll

Then proves it can fail: each deliberate break (passed only to the test via
--break) must exit 1 with its own criterion failing. 'start' removes the launch
randomization (the die leaves in the pose it rested in).

Exit 0 = the clean run passes AND every break is detected.
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get(
    "GODOT_BIN",
    "C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe",
)
SCRIPT = "scripts/debug/reroll_hop_gate.gd"
CLEAN_HOPS = 10000
SHARDS = 8
MIN_PER_GROUP = 500
SEED = 20261005
BREAK_HOPS = {"uniform": 40, "start": 500, "contact": 40, "slot": 40, "snap": 40}
LEG_TIMEOUT_S = 900


def launch(extra: list[str]) -> subprocess.Popen:
    cmd = [GODOT, "--headless", "--path", str(ROOT), "-s", SCRIPT, "--"] + extra
    # Output goes to a file: a pipe nobody is reading fills up and stalls the leg.
    log = tempfile.TemporaryFile(mode="w+", encoding="utf-8", errors="replace")
    proc = subprocess.Popen(cmd, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, text=True)
    proc.log = log  # type: ignore[attr-defined]
    return proc


def finish(proc: subprocess.Popen) -> tuple[int, str]:
    try:
        proc.wait(timeout=LEG_TIMEOUT_S)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.wait()
        return -1, f"TIMED OUT after {LEG_TIMEOUT_S}s"
    proc.log.seek(0)  # type: ignore[attr-defined]
    out = proc.log.read()  # type: ignore[attr-defined]
    proc.log.close()  # type: ignore[attr-defined]
    return proc.returncode, out


def run(extra: list[str]) -> tuple[int, str]:
    return finish(launch(extra))


def main() -> int:
    ok = True
    work = Path(tempfile.mkdtemp(prefix="reroll_hop_"))
    per_shard = CLEAN_HOPS // SHARDS
    print(f"-- clean: {CLEAN_HOPS} rerolls in {SHARDS} shards, plus {len(BREAK_HOPS)} deliberate breaks", flush=True)
    shards = [
        launch([f"--n={per_shard}", f"--seed={SEED + i}", f"--pairs-out={work / f'shard{i}.txt'}", "--physics-only"])
        for i in range(SHARDS)
    ]
    breaks = {kind: launch([f"--n={n}", f"--break={kind}", "--min-group=100"]) for kind, n in BREAK_HOPS.items()}
    for i, proc in enumerate(shards):
        rc, log = finish(proc)
        if i == 0:
            for line in log.splitlines():
                if line.startswith("[REROLL_HOP]") and "PASS" not in line and "FAIL" not in line:
                    print("   shard0 " + line)
        if rc != 0 or "[REROLL_HOP] PASS" not in log or "SCRIPT ERROR" in log:
            tail = "\n".join(l for l in log.splitlines() if "REROLL_HOP" in l or "ERROR" in l)
            print(f"   FAIL shard {i} (rc {rc})\n{tail}")
            ok = False
    files = ",".join(str(work / f"shard{i}.txt") for i in range(SHARDS))
    rc, log = run([f"--n={CLEAN_HOPS}", f"--analyze={files}", f"--min-group={MIN_PER_GROUP}"])
    for line in log.splitlines():
        if line.startswith("[REROLL_HOP]") and "PASS" not in line and "FAIL" not in line:
            print("   " + line)
    if rc != 0 or "[REROLL_HOP] PASS" not in log or "SCRIPT ERROR" in log:
        print(f"   FAIL pooled uniformity (rc {rc})")
        ok = False
    for kind, proc in breaks.items():
        rc, log = finish(proc)
        caught = re.search(rf"\({'uniform' if kind == 'start' else kind}\) failures=([1-9]\d*)", log)
        if rc == 1 and caught and f"injected violation ({kind})" in log and "SCRIPT ERROR" not in log:
            print(f"-- deliberate break {kind}: ok, detected (failures={caught.group(1)})")
        else:
            print(f"-- deliberate break {kind}: FAIL, not detected (rc {rc})")
            ok = False
    shutil.rmtree(work, ignore_errors=True)
    print(f"[REROLL_HOP_GATE] {'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
