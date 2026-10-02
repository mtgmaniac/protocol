#!/usr/bin/env python3
"""State code round-trip gate (dev tool, 2026-10-02).

Runs scripts/debug/state_code_test.gd as two SEPARATE Godot processes:

    export   play a battle round (end-of-round checkpoint in the run save),
             export the code; in process: it decodes back, damaged codes are
             refused; then the run save is erased
    import   launched with --load-state=<code>: SaveManager imports it at boot;
             the run save and profile must equal the export's, CONTINUE must
             resume the battle at the same round

and checks the Python decoder (scripts/debug/state_code_decode.py) reads the
same code to the same run save. Then it proves it can fail: each deliberate
break (passed only to the test via --state-code-break, a debug-build seam the
game never sets) must make the round trip fail:

    drop_run     the export leaves the run save out of the code
    no_checksum  decode stops checking the checksum
    import_noop  the import writes nothing

Exit 0 = the round trip holds AND every break is detected.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get(
    "GODOT_BIN",
    "C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe",
)
SCRIPT = "scripts/debug/state_code_test.gd"
OUT_ROOT = ROOT / "results" / "state_code"
LEG_TIMEOUT_S = 120
BREAKS = ["drop_run", "no_checksum", "import_noop"]

sys.path.insert(0, str(ROOT / "scripts" / "debug"))
import state_code_decode  # noqa: E402


def run_leg(out: Path, leg: str, extra: list[str]) -> dict | None:
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
    return json.loads(record.read_text(encoding="utf-8"))


def round_trip(name: str, break_mode: str = "") -> list[str]:
    """Runs export + import (+ the Python decoder); returns the failures."""
    out = OUT_ROOT / name
    out.mkdir(parents=True, exist_ok=True)
    seam = [f"--state-code-break={break_mode}"] if break_mode else []
    failures: list[str] = []
    export = run_leg(out, "export", seam)
    if export is None:
        return ["export leg did not run"]
    failures += [f"export: {e}" for e in export.get("errors", [])]
    code_file = out / "code.txt"
    if not code_file.exists():
        return failures + ["export wrote no code"]
    imported = run_leg(out, "import", seam + [f"--load-state={code_file}"])
    if imported is None:
        failures.append("import leg did not run")
    else:
        failures += [f"import: {e}" for e in imported.get("errors", [])]
    try:
        payload = state_code_decode.decode(code_file.read_text(encoding="utf-8"))
        if payload.get("run_save") != export.get("run_save"):
            failures.append("python decoder: run save differs from the exported one")
    except Exception as exc:  # noqa: BLE001 - any decoder failure is a gate failure
        failures.append(f"python decoder: {exc}")
    return failures


def main() -> int:
    OUT_ROOT.mkdir(parents=True, exist_ok=True)
    ok = True
    print("-- round trip", flush=True)
    failures = round_trip("clean")
    for f in failures:
        print(f"   FAIL {f}")
    if failures:
        ok = False
    else:
        export = json.loads((OUT_ROOT / "clean" / "export.json").read_text(encoding="utf-8"))
        print(f"   ok   export -> separate-process import -> CONTINUE at round {export.get('round')} "
              f"({export.get('code_length')} characters)")
    for mode in BREAKS:
        print(f"-- deliberate break: {mode}", flush=True)
        caught = round_trip(f"break_{mode}", mode)
        if caught:
            print(f"   ok   detected ({caught[0]})")
        else:
            print(f"   FAIL the round trip still passed with '{mode}' - the gate cannot see this break")
            ok = False
    print(f"[STATE_CODE] {'PASS' if ok else 'FAIL'}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
