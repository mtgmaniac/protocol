#!/usr/bin/env python3
"""Static gap audit: ability JSON keys vs combat_manager handlers."""

from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HEROES_PATH = ROOT / "data" / "raw" / "heroes.data.json"
ENEMIES_PATH = ROOT / "data" / "raw" / "enemies.data.json"

META_KEYS = frozenset({"zone", "range", "name", "eff", "callsign", "focus", "hp", "freeze_flavor"})

# Keys read in combat_manager._apply_hero_ability / _apply_enemy_ability
HERO_HANDLED = frozenset({
    "dmg", "dMin", "dMax", "heal", "shield", "blastAll", "healAll", "shieldAll",
    "healLowest", "shieldLowest", "shTgt", "healTgt", "burn", "burnT", "rfm", "rfmT", "rfmTgt", "ignSh",
    "rfe", "rfT", "rfeAll", "taunt", "revive", "reviveAll", "revivePct", "cloak", "cloakAll",
    "ward", "wardTgt", "chain", "detonate", "execute", "breach", "breachAll", "leech", "mark",
    "freezeEnemyDice", "freezeAllEnemyDice", "freezeAnyDice", "gainProtocol",
})

ENEMY_HANDLED = frozenset({
    "dmg", "dmgP2", "heal", "shield", "shieldP2", "shieldAlly",
    "shieldAllyAll", "blastAll", "burn", "burnT",
    "packBonus", "lifestealPct", "wipeShields", "rfm", "rfmT", "erb", "erbT", "erbAll",
    "freezeEnemyDice", "freezeAllEnemyDice", "grantRampage", "grantRampageAll", "ward",
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


def manual_pick_sides(raw: dict) -> set[str]:
    """Distinct manual target picks a hero ability demands.

    Components that share the same pick (dmg + burn + freezeEnemyDice on one
    enemy; healTgt + shTgt + rfmTgt + wardTgt on one ally) count once. Auto
    targets (self / all / lowest) never count. revive consumes healTgt as its
    dead-ally pick.
    """
    sides: set[str] = set()
    if is_meaningful(raw.get("freezeAnyDice")):
        sides.add("any")
    if is_meaningful(raw.get("reviveAll")):
        pass
    elif is_meaningful(raw.get("revive")):
        sides.add("dead_hero")
    elif (
        is_meaningful(raw.get("healTgt"))
        or is_meaningful(raw.get("shTgt"))
        or is_meaningful(raw.get("rfmTgt"))
        or is_meaningful(raw.get("wardTgt"))
    ):
        sides.add("ally")
    single_enemy = (
        (is_meaningful(raw.get("dmg")) and not is_meaningful(raw.get("blastAll")))
        or (is_meaningful(raw.get("burn")) and not is_meaningful(raw.get("blastAll")))
        or (is_meaningful(raw.get("rfe")) and not is_meaningful(raw.get("rfeAll")))
        or is_meaningful(raw.get("rfeOnly"))
        or is_meaningful(raw.get("freezeEnemyDice"))
    )
    if single_enemy:
        sides.add("enemy")
    return sides


def main() -> int:
    abilities = collect_abilities()
    gaps: dict[str, list[str]] = defaultdict(list)
    key_counts: dict[str, dict[str, int]] = defaultdict(lambda: {"hero": 0, "enemy": 0})
    multi_pick_violations: list[str] = []

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
        if side == "hero":
            picks = manual_pick_sides(raw)
            if len(picks) > 1:
                multi_pick_violations.append(f"{label} -> picks {sorted(picks)}")

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

    print("\n=== TARGETING RULE: max one manual pick per hero ability ===")
    if not multi_pick_violations:
        print("  (none)")
    else:
        for violation in multi_pick_violations:
            print(f"  FAIL {violation}")

    return 1 if (gaps or multi_pick_violations) else 0


if __name__ == "__main__":
    raise SystemExit(main())
