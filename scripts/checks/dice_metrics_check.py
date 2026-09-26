#!/usr/bin/env python3
"""Optional frozen-rider telemetry must leave the seeded battle unchanged."""
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT_BIN", "C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe")


def main():
    out = ROOT / "results/dice_contract"
    out.mkdir(parents=True, exist_ok=True)
    runs = []
    for enabled in (False, True):
        path = out / f"metrics_{int(enabled)}.jsonl"
        env = dict(os.environ, PROTOCOL_DICE_METRICS="1" if enabled else "0")
        proc = subprocess.run([GODOT, "--headless", "--path", str(ROOT), "res://scenes/sim/sim_main.tscn", "--",
                               "--seed", "900123", "--squad", "avalanche,combat,medic", "--op", "facility",
                               "--policy", "l1", "--out", str(path)], env=env, capture_output=True, text=True, timeout=90)
        (out / f"metrics_{int(enabled)}.log").write_text(proc.stdout + proc.stderr, encoding="utf-8")
        if proc.returncode or "ERROR:" in proc.stderr:
            raise RuntimeError(proc.stdout + proc.stderr)
        records = [json.loads(line) for line in path.read_text().splitlines()]
        if enabled:
            assert sum(x["type"] == "frozen_riders" for x in records) == sum(x["type"] == "round" for x in records)
        ordinary = [{k: v for k, v in row.items() if k != "t"} for row in records if row["type"] != "frozen_riders"]
        runs.append(ordinary)
    assert runs[0] == runs[1], "Optional metrics changed the seeded run"
    print(f"[DICE_METRICS] PASS: {len(runs[0])} ordinary records identical, excluding envelope t")


if __name__ == "__main__":
    main()
