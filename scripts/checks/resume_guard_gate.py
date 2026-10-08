#!/usr/bin/env python3
"""Resume guard gate (G-48, Kev 2026-10-06).

Runs scripts/debug/resume_guard_test.gd as SEPARATE Godot processes, because
"the next launch" is only honest in a fresh process:

    unit        the rules, in process
    seed        a run parked mid-battle with the rewards as its earlier point
    normal      real menu CONTINUE: the battle resumes at its round, the marker
                is set while loading and clear once loaded
    progress    next launch: no option. Then a resume whose load raised an
                error: the marker stays until a round resolves
    hang        real menu CONTINUE, the process dies as the screen loads
    auto_blocked  web display recovery on that launch: the page reloaded itself,
                but the last resume never finished, so nothing resumes by itself
    after_hang  next launch: RESUME EARLIER POINT and its line, CONTINUE still
                the main button, the state code still exports; the option puts
                the rewards back, says so, and CONTINUE resumes them
    auto        web display recovery from a healthy save: the menu resumes with
                no tap through CONTINUE's own path, round restored

Ruled (Kev): "a resume that hangs on load must produce the RESUME EARLIER POINT
option on the next launch, and a normal resume must not."

Then it proves it can fail. Each deliberate break is passed only through the
debug-build `--resume-guard-break=` seam the game never sets, and must make the
named leg fail:

    no_marker     CONTINUE writes no marker            -> after_hang
    never_clear   the marker is never cleared          -> normal
    routing_save  CONTINUE re-saves before the screen  -> normal (the round is lost)
    no_prev       the previous screen is never kept    -> seed
    auto_past_marker  the display recovery ignores the marker -> auto_blocked

Exit 0 = the guard holds AND every break is detected.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get(
    "GODOT_BIN",
    "C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe",
)
SCRIPT = "scripts/debug/resume_guard_test.gd"
OUT_ROOT = ROOT / "results" / "resume_guard"
LEG_TIMEOUT_S = 120
# break mode -> (legs to run from the clean snapshot, the leg that must fail)
BREAKS = {
    "no_marker": (["hang", "after_hang"], "after_hang"),
    "never_clear": (["normal"], "normal"),
    "routing_save": (["normal"], "normal"),
    "no_prev": (["seed"], "seed"),
    "auto_past_marker": (["hang", "auto_blocked"], "auto_blocked"),
}


def run_leg(out: Path, leg: str, extra: list[str]) -> list[str] | None:
    """Runs one leg; returns its failures, or None when it did not run."""
    record = out / f"{leg}.json"
    if record.exists():
        record.unlink()
    cmd = [GODOT, "--headless", "--path", str(ROOT), "-s", SCRIPT, "--", "--leg", leg, "--out", str(out)] + extra
    try:
        proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=LEG_TIMEOUT_S)
    except subprocess.TimeoutExpired:
        print(f"   {leg}: TIMED OUT after {LEG_TIMEOUT_S}s")
        return None
    (out / f"{leg}.log").write_text(proc.stdout + proc.stderr, encoding="utf-8")
    if "SCRIPT ERROR" in proc.stdout + proc.stderr:
        print(f"   {leg}: script error (see {out / (leg + '.log')})")
        return None
    if not record.exists():
        print(f"   {leg}: no result written (rc {proc.returncode})")
        return None
    return list(json.loads(record.read_text(encoding="utf-8")).get("errors", []))


def main() -> int:
    if OUT_ROOT.exists():
        shutil.rmtree(OUT_ROOT)
    clean = OUT_ROOT / "clean"
    clean.mkdir(parents=True)
    ok = True

    print("-- the guard", flush=True)
    # `normal` and `hang` start from the seed's snapshot; `progress` and
    # `after_hang` are the launch AFTER them and read what they left behind.
    plan = [("unit", []), ("seed", []), ("normal", ["--restore"]), ("progress", []),
            ("hang", ["--restore"]), ("auto_blocked", []), ("after_hang", []), ("auto", ["--restore"])]
    for leg, extra in plan:
        failures = run_leg(clean, leg, extra)
        if failures is None:
            ok = False
            break
        for failure in failures:
            print(f"   FAIL {leg}: {failure}")
        if failures:
            ok = False
        else:
            print(f"   ok   {leg}")

    snapshot = clean / "snapshot"
    for mode, (legs, must_fail) in BREAKS.items():
        print(f"-- deliberate break: {mode}", flush=True)
        out = OUT_ROOT / f"break_{mode}"
        out.mkdir(parents=True)
        if snapshot.exists():
            shutil.copytree(snapshot, out / "snapshot")
        if (clean / "seed.json").exists() and "seed" not in legs:
            shutil.copy(clean / "seed.json", out / "seed.json")
        caught: list[str] | None = []
        for index, leg in enumerate(legs):
            extra = [f"--resume-guard-break={mode}"] + (["--restore"] if index == 0 and leg != "seed" else [])
            failures = run_leg(out, leg, extra)
            if leg == must_fail:
                caught = failures
        if caught:
            print(f"   ok   detected ({caught[0]})")
        elif caught is None:
            print(f"   FAIL the '{must_fail}' leg did not run under '{mode}'")
            ok = False
        else:
            print(f"   FAIL '{must_fail}' still passed with '{mode}' - the gate cannot see this break")
            ok = False
    print(f"[RESUME_GUARD] {'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
