#!/usr/bin/env python3
"""Prove the boss relic gates catch real rule breaks (boss relic rework, G-34..G-41).

Each case patches ONE rule in the production source, runs the gate that owns
it, and requires the gate to FAIL naming the right section; the source is
restored afterwards (always, via finally) and checked byte-identical.

    python scripts/checks/boss_relic_mutations.py            # boss relic gate cases
    python scripts/checks/boss_relic_mutations.py --checkpoint   # + the Heretic refresh legs (slow)

Run with an isolated APPDATA when Godot may be open (the checkpoint legs write
the dev run save).
"""
import argparse
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
GODOT = os.environ.get("GODOT_BIN", "C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe")
GATE = [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/boss_relic_test.gd"]

# (name, file, original text, broken text, section the gate must report)
CASES = [
    ("Scrap Converter reads the natural, not the printed face", "scripts/battle/battle_engine.gd",
     "if combat_manager.get_effective_roll(state, raw) <= max_face:", "if raw <= max_face:", "Scrap Converter"),
    ("Blood Frenzy freezes once per kill, not once per round", "scripts/battle/combat_manager.gd",
     "\t\t\t\t\tand int(killer_state.get(\"blood_frenzy_round\", -1)) != _battle_round:", "\t\t\t\t\tand true:", "Blood Frenzy"),
    ("Firewall Hack is never used up", "scripts/battle/battle_engine.gd",
     "\tbs.firewall_hack_used = true\n", "\tpass\n", "Firewall Hack"),
    ("Heretic Signal re-throws frozen dice", "scripts/battle/battle_engine.gd",
     "if bool(state.get(\"dead\", false)) or not rolls.has(uid) or not can_alter_die(state):",
     "if bool(state.get(\"dead\", false)) or not rolls.has(uid):", "Heretic Signal"),
    ("Tectonic Charge never holds", "scripts/battle/combat_manager.gd",
     "return has_relic(\"heroesHoldRoundOne\") and _battle_round == 0", "return false", "Tectonic Charge"),
    ("Overheal Relay deals no damage", "scripts/battle/combat_manager.gd",
     "var overheal: int = amount - healed_amount", "var overheal: int = 0", "Overheal Relay"),
    ("Spillover Charge never wraps to the first slot", "scripts/battle/combat_manager.gd",
     "_enemy_states[(start + step) % count]", "_enemy_states[mini(start + step, count - 1)]", "Spillover Charge"),
    ("the profile keeps the old boss relic ids", "scripts/autoloads/SaveManager.gd",
     "var current_id: String = current_relic_id(str(relic_id))", "var current_id: String = str(relic_id)", "save migration"),
]
CHECKPOINT_CASE = ("the checkpoint forgets Heretic Signal was used", "scripts/battle/battle_checkpoint.gd",
                   "\"heretic_signal_used\": bs.heretic_signal_used,", "\"heretic_signal_used\": false,",
                   "after the reload Heretic Signal stays used for the battle")


def run_case(name: str, rel: str, old: str, new: str, needle: str, cmd: list, timeout: int) -> bool:
    path = ROOT / rel
    original = path.read_bytes()
    text = original.decode("utf-8")
    if text.count(old) != 1:
        print(f"[RELIC_MUTATIONS] {name}: patch target not found exactly once in {rel}")
        return False
    try:
        path.write_bytes(text.replace(old, new).encode("utf-8"))
        proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
        log = proc.stdout + proc.stderr
    finally:
        path.write_bytes(original)
    assert path.read_bytes() == original, f"{rel} was not restored"
    caught = proc.returncode != 0 and needle in log and "SCRIPT ERROR" not in log
    tag = "detected" if caught else "MISSED"
    print(f"[RELIC_MUTATIONS] {name}: {tag}", flush=True)
    if not caught:
        print("\n".join(log.strip().splitlines()[-15:]))
    return caught


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--checkpoint", action="store_true", help="also break the Heretic refresh path (slow)")
    args = ap.parse_args()
    missed = []
    for name, rel, old, new, section in CASES:
        if not run_case(name, rel, old, new, f"FAIL [{section}]", GATE, 300):
            missed.append(name)
    if args.checkpoint:
        name, rel, old, new, needle = CHECKPOINT_CASE
        cmd = [sys.executable, str(ROOT / "scripts" / "checks" / "battle_checkpoint_gate.py")]
        if not run_case(name, rel, old, new, f"FAIL {needle}", cmd, 1800):
            missed.append(name)
    total = len(CASES) + (1 if args.checkpoint else 0)
    print(f"[RELIC_MUTATIONS] {'FAIL' if missed else 'PASS'}: {total} deliberate breaks, {len(missed)} missed")
    return 1 if missed else 0


if __name__ == "__main__":
    sys.exit(main())
