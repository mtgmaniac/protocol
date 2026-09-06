#!/usr/bin/env python3
"""Verify concise ability targets against coded effects (G-9).

Hero self is implicit; enemy self stays explicit. Group targets name their side.
Compare (effect, target) counts so duplicate or misplaced suffixes also fail.
Equipment still cannot carry (self). Replaces NK-17's abbreviated suffixes.
"""
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def required_targets(a, side):
    targets = []
    own = "" if side == "hero" else "self"
    friends = "all heroes" if side == "hero" else "all enemies"
    foes = "all enemies" if side == "hero" else "all heroes"
    if max(a.get("dmg", 0), a.get("dMin", 0), a.get("dMax", 0)) > 0:
        targets.append(("damage", foes if a.get("blastAll") else ""))
    if a.get("shieldAllyAll") and a.get("shieldAlly", 0) > 0:
        targets.append(("shield", "all enemies"))
    else:
        if a.get("shield", 0) > 0:
            scope = friends if a.get("shieldAll") else "lowest HP" if a.get("shieldLowest") else "hero" if a.get("shTgt") else own
            targets.append(("shield", scope))
        if side == "enemy" and a.get("shieldAlly", 0) > 0:
            targets.append(("shield", "ally"))
    if a.get("heal", 0) > 0:
        scope = friends if a.get("healAll") else "lowest HP" if a.get("healLowest") else "hero" if a.get("healTgt") else own
        targets.append(("heal", scope))
    if side == "hero" and a.get("rfm", 0) > 0:
        targets.append(("roll", "hero" if a.get("rfmTgt") else "all heroes"))
    if side == "enemy" and a.get("rfm", 0) > 0:
        targets.append(("roll", ""))
    if a.get("erb", 0) > 0:
        targets.append(("roll", "all enemies" if a.get("erbAll") else "self"))
    if a.get("rfe", 0) > 0:
        targets.append(("roll", "all enemies" if a.get("rfeAll") else ""))
    return Counter(targets)


def actual_targets(eff):
    targets = []
    for clause in eff.split(","):
        if "vs frozen" in clause or "per other pack member" in clause:
            continue
        match = re.match(r"\s*[+−-]?\d+ (damage|dmg|heal|shield|roll)\b(.*)", clause)
        if not match:
            continue
        kind, tail = match.groups()
        scopes = re.findall(r"\(([^)]+)\)", tail)
        targets.append((kind, scopes[0] if scopes else ""))
        targets.extend((kind, extra) for extra in scopes[1:])
    return Counter(targets)


def walk(node, path=""):
    if isinstance(node, dict):
        if isinstance(node.get("eff"), str):
            yield path, node
        for key, value in node.items():
            yield from walk(value, f"{path}/{key}")
    elif isinstance(node, list):
        for index, value in enumerate(node):
            yield from walk(value, f"{path}[{index}]")


def strings(node):
    if isinstance(node, str):
        yield node
    elif isinstance(node, dict):
        for value in node.values():
            yield from strings(value)
    elif isinstance(node, list):
        for value in node:
            yield from strings(value)


def main():
    failures = []
    for name, side in [("heroes", "hero"), ("enemies", "enemy")]:
        data = json.loads((ROOT / f"data/raw/{name}.data.json").read_text(encoding="utf8"))
        for path, ability in walk(data):
            expected = required_targets(ability, side)
            actual = actual_targets(ability["eff"])
            if expected != actual:
                failures.append(f"{side} {path}: expected {dict(expected)}, found {dict(actual)} | {ability['eff']}")
    for name in ["gear", "items", "relics"]:
        data = json.loads((ROOT / f"data/raw/{name}.data.json").read_text(encoding="utf8"))
        failures.extend(f"{name}: equipment cannot carry (self): {s}" for s in strings(data) if "(self)" in s)
    for failure in failures:
        print(failure)
    print("[EFFECT_TARGET] " + ("FAIL" if failures else "PASS"))
    return bool(failures)


if __name__ == "__main__":
    raise SystemExit(main())
