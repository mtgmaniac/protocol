#!/usr/bin/env python3
"""Write canonical eff strings into heroes.data.json and enemies.data.json."""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT / "scripts" / "debug") not in sys.path:
    sys.path.insert(0, str(ROOT / "scripts" / "debug"))

from ability_text_format import format_eff  # noqa: E402

HEROES_PATH = ROOT / "data/raw/heroes.data.json"
ENEMIES_PATH = ROOT / "data/raw/enemies.data.json"


def apply_eff(ab: dict, side: str) -> bool:
    new_eff = format_eff(ab, side)
    old_eff = str(ab.get("eff", ""))
    if old_eff != new_eff:
        ab["eff"] = new_eff
        return True
    return False


def main() -> None:
    heroes = json.loads(HEROES_PATH.read_text(encoding="utf-8"))
    enemies = json.loads(ENEMIES_PATH.read_text(encoding="utf-8"))
    hero_changes = 0
    enemy_changes = 0

    for hero in heroes["heroes"]:
        for ab in hero.get("abilities", []):
            if apply_eff(ab, "hero"):
                hero_changes += 1
        for evo in hero.get("evolutions", []):
            for ab in evo.get("abilities", []):
                if apply_eff(ab, "hero"):
                    hero_changes += 1

    for suite in enemies["enemyAbilities"].values():
        for ab in suite.values():
            if apply_eff(ab, "enemy"):
                enemy_changes += 1

    HEROES_PATH.write_text(json.dumps(heroes, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    ENEMIES_PATH.write_text(json.dumps(enemies, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Updated {hero_changes} hero eff strings, {enemy_changes} enemy eff strings")


if __name__ == "__main__":
    main()
