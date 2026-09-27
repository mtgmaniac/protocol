#!/usr/bin/env python3
"""End-of-round battle checkpoint gate (save system, 2026-09-21).

Runs scripts/debug/battle_checkpoint_test.gd as SEPARATE Godot processes (a real
reload: fresh autoloads, fresh scene, state only from disk) and compares them:

    full    play the battle straight through
    save    play to the round-3 checkpoint, roll round 4, quit once it settles
    resume  CONTINUE from the save leg's run.json: round 4's dice come back
            placed from the pending roll (G-24), then finish
    save_phys / resume_phys  the same refresh with an unrigged physics roll

Asserted per config:
  * the restored battle state is EXACTLY the checkpointed one (combat units,
    HP, deaths/revives, shields, burn/mark/jam/freeze/roll stacks, summons,
    Protocol, spend flags, round, RNG stream positions, XP accumulators) and
    the run block (consumables etc.) matches
  * round 4's dice are the SAME in all three legs and a CONTINUE throws no
    die: a refresh after landing restores identical dice (also for an
    unrigged physics roll)
  * resuming ends in the same run state as never leaving (XP, rewards, items
    applied exactly once) and the finished battle leaves no checkpoint behind
and, on the first config, that an older-version run save is discarded cleanly,
that a checkpoint with an unknown format still loads and restarts the battle
from its entry, and that the restarted battle has the SAME RNG streams at entry
(the 64-bit seeds survive the save exactly). Live opening dice are physics
(G-24) and are not compared.

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
SCRIPT = "scripts/debug/battle_checkpoint_test.gd"
OUT_DIR = ROOT / "results" / "battle_checkpoint"
LEG_TIMEOUT_S = 150

# battle 5: the fixed double Shield Enforcer fight (ally shields, roll buffs),
#           won mid-run -> reward flow (rewards/XP exactly once)
# battle 10: the Scrapmaster (Assembly Line summons/rebuilds), won -> run end
CONFIGS = [
    {"name": "b5_shields", "battle": 5, "fallbacks": True},
    {"name": "b10_boss", "battle": 10, "fallbacks": False},
]


def run_leg(config: dict, leg: str) -> dict | None:
    out = OUT_DIR / f"{config['name']}_{leg}.json"
    if out.exists():
        out.unlink()
    cmd = [GODOT, "--headless", "--path", str(ROOT), "-s", SCRIPT, "--",
           "--leg", leg, "--battle", str(config["battle"]), "--out", str(out)]
    try:
        proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=LEG_TIMEOUT_S)
    except subprocess.TimeoutExpired:
        print(f"[BATTLE_CHECKPOINT] {config['name']}/{leg}: TIMED OUT after {LEG_TIMEOUT_S}s")
        return None
    if not out.exists():
        tail = "\n".join((proc.stdout + proc.stderr).strip().splitlines()[-12:])
        print(f"[BATTLE_CHECKPOINT] {config['name']}/{leg}: no result written (rc {proc.returncode})\n{tail}")
        return None
    record = json.loads(out.read_text())
    for err in record.get("errors", []):
        print(f"[BATTLE_CHECKPOINT] {config['name']}/{leg}: {err}")
    return record


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    failures: list[str] = []

    def check(ok: bool, what: str) -> None:
        print(f"  {'ok  ' if ok else 'FAIL'} {what}")
        if not ok:
            failures.append(what)

    for config in CONFIGS:
        name = config["name"]
        print(f"-- {name} (battle {config['battle']})", flush=True)
        full = run_leg(config, "full")
        save = run_leg(config, "save")
        resume = run_leg(config, "resume") if save else None
        legs = {"full": full, "save": save, "resume": resume}
        for leg, rec in legs.items():
            check(rec is not None and not rec.get("errors"), f"{name}: {leg} leg ran clean")
        if not (full and save and resume):
            continue
        check(save["post_roll_state"] == resume["post_roll_state"],
              f"{name}: restored battle state + pending roll == the state after the original landing (exact)")
        check(save["post_roll_run"] == resume["post_roll_run"],
              f"{name}: restored run block == the run block after the original landing")
        check(full["checkpoint_state"] == save["checkpoint_state"],
              f"{name}: two independent plays reach the same checkpoint (determinism)")
        rolls = [(r["round4_hero_rolls"], r["round4_enemy_rolls"]) for r in (full, save, resume)]
        check(rolls[0] == rolls[1] == rolls[2],
              f"{name}: round-4 dice identical across full / save / resume "
              f"(hero {rolls[2][0]}, enemy {rolls[2][1]})")
        check(full["after_run"] == resume["after_run"],
              f"{name}: resumed run ends identical to never leaving (XP, rewards, items once)")
        check(full["after_scene"] == resume["after_scene"] and full["after_screen"] == resume["after_screen"],
              f"{name}: same post-battle flow ({resume['after_scene']}, run.json screen '{resume['after_screen']}')")
        check(bool(resume["after_checkpoint_empty"]) and bool(full["after_checkpoint_empty"]),
              f"{name}: no battle checkpoint left behind after the battle")
        if config["battle"] == 10:
            check(int(resume["summoned_in_checkpoint"]) > 0, f"{name}: a summoned/rebuilt unit survived the reload")
        if config["fallbacks"]:
            for leg in ("resume_old", "resume_bad"):
                if run_leg(config, "save") is None:
                    check(False, f"{name}: save leg re-run for {leg}")
                    continue
                rec = run_leg(config, leg)
                check(rec is not None and not rec.get("errors"),
                      f"{name}: {leg} - " + ("an older run save is discarded cleanly" if leg == "resume_old"
                                             else "loads and restarts the battle from its entry"))
                if leg == "resume_bad" and rec is not None:
                    check(bool(rec.get("entry_streams")) and rec.get("entry_streams") == save.get("entry_streams"),
                          f"{name}: the restarted battle's RNG streams at entry == the original's "
                          f"({rec.get('entry_streams', '').strip()})")
            # G-24: an UNRIGGED physics roll survives a refresh identically.
            save_p = run_leg(config, "save_phys")
            resume_p = run_leg(config, "resume_phys") if save_p else None
            check(save_p is not None and not save_p.get("errors") and resume_p is not None and not resume_p.get("errors"),
                  f"{name}: physics save/resume legs ran clean")
            if save_p and resume_p:
                same_p = (save_p["round4_hero_rolls"], save_p["round4_enemy_rolls"]) == \
                         (resume_p["round4_hero_rolls"], resume_p["round4_enemy_rolls"])
                check(same_p, f"{name}: roll, settle, reload -> identical physics dice "
                              f"(hero {resume_p['round4_hero_rolls']}, enemy {resume_p['round4_enemy_rolls']})")

    config = CONFIGS[0]
    save_r = run_leg(config, "save_reroll")
    resume_r = run_leg(config, "resume_reroll") if save_r else None
    check(bool(save_r and resume_r) and not (save_r or {}).get("errors") and not (resume_r or {}).get("errors"), "live reroll save/resume legs ran clean")
    if save_r and resume_r:
        for key in ["round4_hero_rolls", "round4_enemy_rolls", "post_roll_state", "post_roll_run"]:
            check(save_r[key] == resume_r[key], f"reroll reload preserves {key} (including cost and consumed item)")

    if failures:
        print(f"[BATTLE_CHECKPOINT] FAIL - {len(failures)} check(s)")
        return 1
    print("[BATTLE_CHECKPOINT] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
