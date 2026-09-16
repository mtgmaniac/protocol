#!/usr/bin/env python3
"""Resume-determinism gate (save system, G2).

A seeded run played straight through must end in the SAME state as the same run
saved partway, reloaded, and continued. That is the whole promise of the run
save: not "a run resumes" but "the run that resumes is the one you left".

Three SEPARATE GODOT PROCESSES per config, which is the only honest reading of
"reload into a fresh scene tree" — an in-process reload keeps every autoload,
every cached Resource and the whole global RNG alive, so it cannot see the class
of bug this gate exists to catch:

    A  full     --battles-only N
    B  save     --battles-only N --checkpoint-at K      (parks and exits)
    C  resume   --battles-only N --resume               (loads B's save)

then A's fingerprint is compared against C's.

Rolls come from the harness's SeededRollProvider, not the physics tray — G2 asks
for the non-physics roll path, and physics results are non-deterministic by
design (docs/INVARIANTS.md #1: the tray is presentation).

Exit 0 = pass, 1 = a divergence or a leg that failed to run.
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
SCENE = "res://scenes/sim/sim_main.tscn"
OUT_DIR = ROOT / "results" / "resume"
LEG_TIMEOUT_S = 180

# Two configs for the same reason tests/sim_determinism.sh uses two: one squad
# and op never fires the summon / vent / charge branches, so a single config
# would leave a whole class of state unexercised. The second is summon-heavy.
# Checkpoints land at different depths so the gate covers both an early node
# (little accumulated state) and a late one (gear, XP, spent beats).
CONFIGS = [
    {"name": "facility", "squad": "pulse,combat,shield", "op": "facility",
     "policy": "l1", "battles": 6, "checkpoint": 4},
    {"name": "synod", "squad": "medic,ghost,breaker", "op": "voidCirclet",
     "policy": "l1", "battles": 5, "checkpoint": 2},
]
SEED = 4242

# Fields that CANNOT match across separately-launched processes, and why.
# Everything else must be identical — the exclusion list is deliberately tiny,
# because each entry is a hole in the gate.
IGNORED = {
    # Wall-clock stamp taken by start_run, feeding only the run-report duration
    # line. Leg A and leg B started at different moments, so their lineages
    # legitimately differ. (It IS restored correctly: leg C carries leg B's
    # value rather than minting a new one, which is what the save has to do.)
    "/run/run_start_unix",
    # A per-PROCESS counter, not run state: leg C only played the battles after
    # the checkpoint, so it counts fewer by construction.
    "/battles_cleared",
}


def run_leg(config: dict, extra: list[str], label: str) -> bool:
    cmd = [
        GODOT, "--headless", "--path", str(ROOT), SCENE, "--",
        "--seed", str(SEED), "--squad", config["squad"], "--op", config["op"],
        "--policy", config["policy"], "--battles-only", str(config["battles"]),
        "--out", str(OUT_DIR / f"{config['name']}_{label}.jsonl"),
    ] + extra
    try:
        proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True,
                              timeout=LEG_TIMEOUT_S)
    except subprocess.TimeoutExpired:
        print(f"   FAIL - {config['name']}/{label} timed out after {LEG_TIMEOUT_S}s")
        return False
    if proc.returncode != 0:
        print(f"   FAIL - {config['name']}/{label} exited {proc.returncode}")
        print("\n".join(((proc.stdout or "") + (proc.stderr or "")).splitlines()[-12:]))
        return False
    return True


def user_dir() -> Path:
    return Path(os.environ.get("APPDATA", "")) / "Godot" / "app_userdata" / "Overload Protocol"


def clear_run_save() -> None:
    """Every leg starts from a known state; a stale save would let leg C resume
    something leg B never wrote, which would pass for the wrong reason."""
    for suffix in ("", ".bak", ".tmp"):
        victim = user_dir() / f"dev_run.json{suffix}"
        if victim.exists():
            victim.unlink()


def diff(a, b, path: str = "") -> list[str]:
    if path in IGNORED:
        return []
    if type(a) is not type(b):
        return [f"{path}: type {type(a).__name__} vs {type(b).__name__}"]
    out: list[str] = []
    if isinstance(a, dict):
        for key in sorted(set(a) | set(b)):
            if key not in a:
                out.append(f"{path}/{key}: present only after resume")
            elif key not in b:
                out.append(f"{path}/{key}: lost across the resume")
            else:
                out += diff(a[key], b[key], f"{path}/{key}")
    elif isinstance(a, list):
        if len(a) != len(b):
            out.append(f"{path}: length {len(a)} vs {len(b)}")
        else:
            for i, (x, y) in enumerate(zip(a, b)):
                out += diff(x, y, f"{path}[{i}]")
    elif a != b:
        out.append(f"{path}: {a!r} vs {b!r}")
    return out


def check(config: dict) -> bool:
    name = config["name"]
    full_fp = OUT_DIR / f"{name}_fp_full.json"
    resumed_fp = OUT_DIR / f"{name}_fp_resumed.json"
    for stale in (full_fp, resumed_fp):
        if stale.exists():
            stale.unlink()

    clear_run_save()
    if not run_leg(config, ["--fingerprint", str(full_fp)], "full"):
        return False
    clear_run_save()
    if not run_leg(config, ["--checkpoint-at", str(config["checkpoint"])], "save"):
        return False
    if not (user_dir() / "dev_run.json").exists():
        print(f"   FAIL - {name}: the checkpoint leg wrote no run save")
        return False
    if not run_leg(config, ["--resume", "--fingerprint", str(resumed_fp)], "resume"):
        return False

    if not full_fp.exists() or not resumed_fp.exists():
        print(f"   FAIL - {name}: a leg produced no fingerprint")
        return False
    a = json.loads(full_fp.read_text(encoding="utf-8"))
    b = json.loads(resumed_fp.read_text(encoding="utf-8"))

    # The resumed leg must actually have played past the checkpoint; a run that
    # stopped immediately would trivially "match" on the fields we compare.
    if b.get("result") != a.get("result"):
        print(f"   FAIL - {name}: resumed run ended '{b.get('result')}', "
              f"uninterrupted ended '{a.get('result')}'")
        return False
    # Both RNG streams must land on the same position, or the runs only LOOK
    # identical and would diverge on the next draw.
    for stream in ("provider_state", "policy_rng_state"):
        if a.get(stream) != b.get(stream):
            print(f"   FAIL - {name}: {stream} diverged ({a.get(stream)} vs {b.get(stream)})")
            return False

    diffs = diff(a, b)
    if diffs:
        print(f"   FAIL - {name}: {len(diffs)} field(s) diverged across the resume")
        for line in diffs[:15]:
            print(f"      {line}")
        return False
    print(f"   {name}: identical at battle {config['battles']} "
          f"(checkpointed before battle {config['checkpoint']})")
    return True


def main() -> int:
    # The gate runs as a subprocess of verify_gate, whose pipe is not UTF-8 on
    # Windows; keep output ASCII so a failure message stays readable.
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:  # noqa: BLE001 - never let logging setup fail the gate
        pass
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    ok = True
    for config in CONFIGS:
        ok = check(config) and ok
    clear_run_save()
    if ok:
        print("[SAVE_RESUME] PASS")
        return 0
    print("[SAVE_RESUME] FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
