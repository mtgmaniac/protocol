#!/usr/bin/env python3
"""State-hash tripwire (Build J Item 1, per the Build E pair).

Proof that a presentation-layer change did not touch combat state: runs one
pinned seeded sim run (the sim exercises CombatManager/BattleEngine and NEVER
loads the battle scene, feedback, or card view) and compares the SHA-256 of
its telemetry — every resolve step's full state trajectory — against the
recorded pre-change digest. Byte-identical telemetry == byte-identical state
application order.

  python scripts/debug/state_hash_tripwire.py            # compare (exit 1 on drift)
  python scripts/debug/state_hash_tripwire.py --record   # pin the current digest
"""
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DIGEST_FILE = Path(__file__).resolve().parent / "state_hash_tripwire.digest"
GODOT = os.environ.get("GODOT", r"C:\Users\Kev\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe")
OUT = ROOT / "results" / "_tripwire" / "run.jsonl"
ARGS = ["--seed", "31337", "--squad", "shield,medic,combat", "--op", "hive",
        "--policy", "l1", "--out", str(OUT.relative_to(ROOT)).replace("\\", "/")]


def run_digest() -> str:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    if OUT.exists():
        OUT.unlink()
    subprocess.run([GODOT, "--headless", "--path", str(ROOT),
                    "res://scenes/sim/sim_main.tscn", "--"] + ARGS,
                   check=True, capture_output=True)
    body = "\n".join(l for l in OUT.read_text(encoding="utf-8").splitlines()
                     if '"run_header"' not in l)  # header carries harness flags, not state
    return hashlib.sha256(body.encode("utf-8")).hexdigest()


def main() -> int:
    digest = run_digest()
    if "--record" in sys.argv:
        DIGEST_FILE.write_text(digest + "\n")
        print(f"[TRIPWIRE] recorded {digest}")
        return 0
    if not DIGEST_FILE.exists():
        print("[TRIPWIRE] no recorded digest; run with --record first", file=sys.stderr)
        return 2
    pinned = DIGEST_FILE.read_text().strip()
    if digest == pinned:
        print(f"[TRIPWIRE] PASS - state trajectory byte-identical ({digest[:16]}...)")
        return 0
    print(f"[TRIPWIRE] FAIL - state drift!\n  pinned  {pinned}\n  current {digest}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
