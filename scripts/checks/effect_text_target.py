#!/usr/bin/env python3
"""NK-17 target-suffix gate (Polish Build D, 2026-07-15).

Ability effect text (`eff`) is AUTHORED per-ability in data/raw/{enemies,heroes}.data.json.
The canonical grammar (docs/TRUTH.md "Ability eff text syntax", ruling NK-17) requires a
value-bearing clause whose COMPUTED target scope is self / all / lowest to carry the matching
parenthetical suffix — `(self)` / `(all)` / `(lowest)` — and single-target clauses to carry
none. The scope is derived here exactly as scripts/ui/effect_pip.gd derives it from the
structured fields, so authored text can never silently drift from what the die actually does
(the observed bug: Scrap's self-shield "8 shield" rendered no (self) marker).

Only VALUE clauses (dmg / shield / heal / roll) are policed. Keyword clauses author their own
target convention (`cloak`, `firewall`, `jam`, `spike`, `rampage +1 (all)`, `summon (40%)`,
`wipe shields`) and are intentionally out of scope. Count-based, so a DOUBLE suffix (the
historical double-stamp bug) fails just like a missing one.

  python scripts/checks/effect_text_target.py   ->  [EFFECT_TARGET] PASS | FAIL
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FILES = [
    (ROOT / "data" / "raw" / "enemies.data.json", "enemy"),
    (ROOT / "data" / "raw" / "heroes.data.json", "hero"),
]
VALUE_WORDS = ("dmg", "shield", "heal", "roll")
SCOPES = ("self", "all", "lowest")


def required_scopes(a: dict, side: str) -> dict:
    """Scope suffixes a correct eff string must carry, mirroring effect_pip.gd."""
    req = {"self": 0, "all": 0, "lowest": 0}

    has_dmg = int(a.get("dmg", 0)) > 0 or int(a.get("dMin", 0)) > 0 or int(a.get("dMax", 0)) > 0
    if has_dmg and a.get("blastAll"):
        req["all"] += 1

    shield = int(a.get("shield", 0))
    if shield > 0 and not a.get("shieldAllyAll"):
        if a.get("shieldAll"):
            req["all"] += 1
        elif a.get("shieldLowest"):
            req["lowest"] += 1
        elif a.get("shTgt"):
            pass  # single ally target — no suffix
        else:
            req["self"] += 1
    if a.get("shieldAllyAll") and int(a.get("shieldAlly", 0)) > 0:
        req["all"] += 1  # shield_ally rendered "(all)"

    heal = int(a.get("heal", 0))
    if heal > 0:
        if a.get("healAll"):
            req["all"] += 1
        elif a.get("healLowest"):
            req["lowest"] += 1
        elif a.get("healTgt"):
            pass
        else:
            req["self"] += 1

    # Roll modifiers. rfm is squad-shared "all" unless targeted (hero side); enemy rfm is a
    # hostile "-N roll" with no scope. erb is the enemy self-buff mirror. rfe is the hero's
    # enemy-roll debuff (all only when rfeAll).
    if int(a.get("rfm", 0)) > 0 and side == "hero" and not a.get("rfmTgt"):
        req["all"] += 1
    if int(a.get("erb", 0)) > 0:
        req["all" if a.get("erbAll") else "self"] += 1
    if int(a.get("rfe", 0)) > 0 and a.get("rfeAll"):
        req["all"] += 1

    return req


def actual_scopes(eff: str) -> dict:
    """Suffixes actually present on VALUE clauses (keyword clauses excluded)."""
    got = {"self": 0, "all": 0, "lowest": 0}
    for clause in eff.split(","):
        if not any(w in clause for w in VALUE_WORDS):
            continue
        for scope in SCOPES:
            got[scope] += len(re.findall(r"\(%s\)" % scope, clause))
    return got


def walk(node, path=""):
    if isinstance(node, dict):
        if isinstance(node.get("eff"), str):
            yield path, node
        for k, v in node.items():
            yield from walk(v, "%s/%s" % (path, k))
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from walk(v, "%s[%d]" % (path, i))


def main() -> int:
    failures = []
    for fpath, side in FILES:
        data = json.loads(fpath.read_text(encoding="utf-8"))
        for path, ability in walk(data):
            eff = ability.get("eff", "")
            req = required_scopes(ability, side)
            got = actual_scopes(eff)
            for scope in SCOPES:
                if req[scope] != got[scope]:
                    failures.append(
                        "%s %s: expected %d (%s) on value clauses, found %d | %r"
                        % (side, path, req[scope], scope, got[scope], eff)
                    )
    if failures:
        print("[EFFECT_TARGET] FAIL — %d ability(ies) with a wrong target suffix:" % len(failures))
        for f in failures:
            print("   " + f)
        return 1
    print("[EFFECT_TARGET] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
