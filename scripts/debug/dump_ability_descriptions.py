#!/usr/bin/env python3
"""Dump every hero and enemy ability with data eff + hero-style description text."""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HEROES_PATH = ROOT / "data/raw/heroes.data.json"
ENEMIES_PATH = ROOT / "data/raw/enemies.data.json"
OUT_PATH = ROOT / "docs/ABILITY_DESCRIPTIONS_FULL.md"

ENEMY_ZONE_RANGES = {
    "recharge": (1, 4),
    "strike": (5, 10),
    "surge": (11, 16),
    "crit": (17, 19),
    "overload": (20, 20),
}
ZONES = ["recharge", "strike", "surge", "crit", "overload"]


def turns(count: int) -> str:
    return f"{count} turn" + ("" if count == 1 else "s")


def inspect_resolver_ability_text(raw: dict) -> str:
    """Mirror scripts/ui/inspect_resolver.gd::_ability_text (current runtime)."""
    if not raw:
        return ""
    parts: list[str] = []
    dmg = int(raw.get("dmg", 0) or 0)
    d_min = int(raw.get("dMin", 0) or 0)
    d_max = int(raw.get("dMax", 0) or 0)
    if dmg > 0:
        suffix = " to all enemies" if raw.get("blastAll") else ""
        parts.append(f"Deal {dmg} damage{suffix}.")
    elif d_min > 0 or d_max > 0:
        parts.append(f"Deal {d_min}-{d_max} damage.")
    burn = int(raw.get("burn", 0) or 0)
    if burn > 0:
        dt = int(raw.get("burnT", 0) or 0)
        suffix = f" for {turns(dt)}" if dt > 0 else ""
        parts.append(f"Deal {burn} damage per turn{suffix}.")
    heal = int(raw.get("heal", 0) or 0)
    if heal > 0:
        scope = " to all allies" if raw.get("healAll") else ""
        parts.append(f"Restore {heal} HP{scope}.")
    shield = int(raw.get("shield", 0) or 0)
    if shield > 0:
        parts.append(f"Gain {shield} shield this round.")
    rfe = int(raw.get("rfe", 0) or 0)
    if rfe > 0:
        parts.append(f"Reduce an enemy die by {rfe}.")
    rfm = int(raw.get("rfm", 0) or 0)
    if rfm > 0:
        parts.append(f"Raise a hero die by {rfm}.")
    if raw.get("revive") or raw.get("reviveAll"):
        pct = int(raw.get("revivePct", 50) or 50)
        parts.append(f"Revive a fallen ally at {pct}% max HP.")
    if raw.get("cloak"):
        parts.append("Cloak: untargetable by hostile single-target abilities; breaks on dealing damage or an AoE hit.")
    if raw.get("taunt"):
        parts.append("Taunt: enemies must target this unit.")
    if raw.get("ignSh"):
        parts.append("Pierces enemy shields.")
    if not parts:
        return str(raw.get("eff", ""))
    return " ".join(parts)


def main() -> None:
    heroes = json.loads(HEROES_PATH.read_text(encoding="utf-8"))
    enemies = json.loads(ENEMIES_PATH.read_text(encoding="utf-8"))

    lines: list[str] = [
        "# Ability descriptions — full catalog",
        "",
        "Generated from `data/raw/heroes.data.json` and `data/raw/enemies.data.json`.",
        "",
        "Each entry shows:",
        "- **Data `eff`**: terse string stored in JSON",
        "- **Inspect text**: what `InspectResolver._ability_text()` produces today",
        "",
        "---",
        "",
        "## Heroes",
        "",
    ]

    hero_count = 0
    for hero in heroes["heroes"]:
        hid = hero["id"]
        hname = hero["name"]
        lines.append(f"### {hname} (`{hid}`) — Base")
        lines.append("")
        for ab in hero.get("abilities", []):
            hero_count += 1
            _append_ability(lines, ab)
        for evo in hero.get("evolutions", []):
            ename = evo.get("name", evo.get("id", "Evo"))
            lines.append(f"### {hname} (`{hid}`) — Evolution: {ename}")
            lines.append("")
            for ab in evo.get("abilities", []):
                hero_count += 1
                _append_ability(lines, ab)

    lines.extend(
        [
            "---",
            "",
            "## Enemies",
            "",
            "Abilities are keyed by enemy **type** (shared across all units of that type).",
            "",
        ]
    )

    enemy_count = 0
    for etype, suite in enemies["enemyAbilities"].items():
        lines.append(f"### Type: `{etype}`")
        lines.append("")
        for zone in ZONES:
            ab = suite.get(zone, {})
            if not ab:
                continue
            enemy_count += 1
            lo, hi = ENEMY_ZONE_RANGES[zone]
            roll = f"{lo}-{hi}" if lo != hi else str(lo)
            name = ab.get("name", "")
            eff = ab.get("eff", "")
            text = inspect_resolver_ability_text(ab)
            lines.append(f"- **{name}** (`{zone}`, roll {roll})")
            lines.append(f"  - Data `eff`: {eff}")
            lines.append(f"  - Inspect text: {text}")
            lines.append("")

    lines.extend(
        [
            "---",
            "",
            f"**Totals:** {hero_count} hero abilities, {enemy_count} enemy zone abilities.",
            "",
        ]
    )

    OUT_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {OUT_PATH}")
    print(f"Hero abilities: {hero_count}")
    print(f"Enemy abilities: {enemy_count}")


def _append_ability(lines: list[str], ab: dict) -> None:
    zone = ab.get("zone", "")
    rng = ab.get("range", [])
    roll = f"{rng[0]}-{rng[1]}" if len(rng) == 2 else ""
    name = ab.get("name", "")
    eff = ab.get("eff", "")
    text = inspect_resolver_ability_text(ab)
    lines.append(f"- **{name}** (`{zone}`, roll {roll})")
    lines.append(f"  - Data `eff`: {eff}")
    lines.append(f"  - Inspect text: {text}")
    lines.append("")


if __name__ == "__main__":
    main()
