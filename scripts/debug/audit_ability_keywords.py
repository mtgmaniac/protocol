#!/usr/bin/env python3
"""Static gap audit: ability JSON keys vs combat_manager handlers."""

from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HEROES_PATH = ROOT / "data" / "raw" / "heroes.data.json"
ENEMIES_PATH = ROOT / "data" / "raw" / "enemies.data.json"

META_KEYS = frozenset({"zone", "range", "name", "eff", "callsign", "focus", "hp"})

# Keys read in combat_manager._apply_hero_ability / _apply_enemy_ability
HERO_HANDLED = frozenset({
    "dmg", "dMin", "dMax", "heal", "shield", "shT", "blastAll", "healAll", "shieldAll",
    "healLowest", "shTgt", "healTgt", "dot", "dT", "rfm", "rfmT", "rfmTgt", "ignSh",
    "rfe", "rfT", "rfeAll", "taunt", "revive", "cloak", "cloakAll",
    "freezeEnemyDice", "freezeAllEnemyDice", "freezeAnyDice", "gainProtocol",
})

ENEMY_HANDLED = frozenset({
    "dmg", "dmgP2", "heal", "shield", "shieldP2", "shT", "shieldAlly", "shAllyT",
    "shieldAllyAll", "blastAll", "dot", "dT",
    "packBonus", "lifestealPct", "wipeShields", "rfm", "rfmT", "erb", "erbT", "erbAll",
    "cowerT", "cowerAll", "grantRampage", "grantRampageAll", "counterspellPct",
    "curseDice", "enemySelfTaunt", "summonChance", "summonName",
})

PREVIEW_ONLY = frozenset({"dMin", "dMax"})
TARGETING_ONLY = frozenset({"rfeOnly"})


def is_meaningful(value) -> bool:
    if value is None or value == "" or value == []:
        return False
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value > 0
    return True


def collect_abilities() -> list[dict]:
    out: list[dict] = []
    heroes = json.loads(HEROES_PATH.read_text(encoding="utf-8"))
    for hero in heroes.get("heroes", []):
        hid = str(hero.get("id", "?"))
        for raw in hero.get("abilities", []):
            out.append({"side": "hero", "label": f"{hid}/base/{raw.get('name', '?')}", "raw": raw})
        for evo in hero.get("evolutions", []):
            en = str(evo.get("name", "evo"))
            for raw in evo.get("abilities", []):
                out.append({"side": "hero", "label": f"{hid}/{en}/{raw.get('name', '?')}", "raw": raw})

    enemies = json.loads(ENEMIES_PATH.read_text(encoding="utf-8"))
    for etype, zones in enemies.get("enemyAbilities", {}).items():
        for zone, raw in zones.items():
            if not raw:
                continue
            out.append({
                "side": "enemy",
                "label": f"{etype}/{zone}/{raw.get('name', '?')}",
                "raw": raw,
            })
    return out


def main() -> int:
    abilities = collect_abilities()
    gaps: dict[str, list[str]] = defaultdict(list)
    key_counts: dict[str, dict[str, int]] = defaultdict(lambda: {"hero": 0, "enemy": 0})

    for entry in abilities:
        side = entry["side"]
        label = entry["label"]
        raw = entry["raw"]
        handled = HERO_HANDLED if side == "hero" else ENEMY_HANDLED
        for key, value in raw.items():
            if key in META_KEYS or not is_meaningful(value):
                continue
            key_counts[key][side] += 1
            if key in PREVIEW_ONLY or key in TARGETING_ONLY:
                continue
            if key not in handled:
                gaps[key].append(label)

    print("=== Ability keyword usage ===")
    for key in sorted(key_counts):
        c = key_counts[key]
        print(f"  {key:22} hero={c['hero']:3}  enemy={c['enemy']:3}")

    print("\n=== Classified metadata (not combat gaps) ===")
    for key in sorted(TARGETING_ONLY & set(key_counts.keys())):
        print(f"  targeting-only: {key}  hero={key_counts[key]['hero']}  enemy={key_counts[key]['enemy']}")
    for key in sorted(PREVIEW_ONLY & set(key_counts.keys())):
        print(f"  preview-only:   {key}  hero={key_counts[key]['hero']}  enemy={key_counts[key]['enemy']}")

    print("\n=== GAP: keys in data not handled by combat_manager ===")
    if not gaps:
        print("  (none)")
    else:
        for key in sorted(gaps):
            labels = gaps[key]
            sample = labels[:5]
            extra = f" (+{len(labels) - 5} more)" if len(labels) > 5 else ""
            print(f"\n  {key}  ({len(labels)} abilities)")
            for s in sample:
                print(f"    - {s}")
            if extra:
                print(f"    {extra}")

    print("\n=== HANDLED keys never used in data ===")
    used_hero = {k for k, c in key_counts.items() if c["hero"] > 0}
    used_enemy = {k for k, c in key_counts.items() if c["enemy"] > 0}
    for key in sorted(HERO_HANDLED - used_hero - PREVIEW_ONLY):
        print(f"  hero: {key}")
    for key in sorted(ENEMY_HANDLED - used_enemy):
        print(f"  enemy: {key}")

    return 1 if gaps else 0


if __name__ == "__main__":
    raise SystemExit(main())
