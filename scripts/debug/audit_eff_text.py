#!/usr/bin/env python3
"""Compare or normalize ability `eff` strings vs combat field semantics."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / "data" / "raw"
HEROES_PATH = ROOT / "heroes.data.json"
ENEMIES_PATH = ROOT / "enemies.data.json"


def norm(s: str) -> str:
    return re.sub(r"\s+", " ", s.strip().lower())


def turn_suffix(turns: int) -> str:
    return f", {turns}t" if turns > 1 else ""


def hero_expected(raw: dict) -> str:
    parts: list[str] = []
    dmg = raw.get("dmg") or 0
    dmin, dmax = raw.get("dMin") or 0, raw.get("dMax") or 0

    if dmg > 0:
        s = f"{dmg} dmg"
        if raw.get("blastAll") or raw.get("multiHit"):
            s += " (all)"
        if raw.get("ignSh"):
            s += ", pierce"
        parts.append(s)
    elif dmin > 0 and dmax > 0 and dmin != dmax:
        s = f"{dmin}-{dmax} dmg"
        if raw.get("blastAll") or raw.get("multiHit"):
            s += " (all)"
        parts.append(s)

    heal = raw.get("heal") or 0
    if heal > 0:
        if raw.get("healAll"):
            parts.append(f"all {heal} heal")
        elif raw.get("healLowest"):
            parts.append(f"lowest {heal} heal")
        elif raw.get("healTgt"):
            parts.append(f"{heal} heal (ally)")
        elif dmg > 0 or (dmin and dmax):
            parts.append(f"heal self {heal}")
        else:
            parts.append(f"self {heal} heal")

    shield = raw.get("shield") or 0
    if shield > 0:
        t = turn_suffix(raw.get("shT") or 0)
        if raw.get("shieldAll"):
            parts.append(f"all {shield} shield{t}")
        elif raw.get("shTgt"):
            parts.append(f"ally {shield} shield{t}")
        else:
            parts.append(f"self {shield} shield{t}")

    dot = raw.get("dot") or 0
    if dot > 0:
        parts.append(f"{dot} DoT{turn_suffix(raw.get('dT') or 0)}")

    rfe = raw.get("rfe") or 0
    if rfe > 0:
        t = turn_suffix(raw.get("rfT") or 0)
        if raw.get("rfeAll"):
            parts.append(f"all -{rfe} roll{t}")
        else:
            parts.append(f"-{rfe} roll{t}")

    rfm = raw.get("rfm") or 0
    if rfm > 0:
        t = turn_suffix(raw.get("rfmT") or 0)
        if raw.get("rfmTgt"):
            parts.append(f"+{rfm} roll ally{t}")
        elif raw.get("shTgt") and shield > 0:
            parts.append(f"+{rfm} roll any ally{t}")
        else:
            parts.append(f"+{rfm} squad roll{t}")

    if raw.get("revive"):
        parts.append("revive 50%")
    if raw.get("cloak"):
        parts.append("Cloak")
    if raw.get("taunt"):
        parts.append("taunt (picked enemy targets you)")

    for key in ("freezeAllEnemyDice", "freezeEnemyDice", "freezeAnyDice"):
        v = raw.get(key) or 0
        if v > 0:
            sk = "s" if v > 1 else ""
            parts.append(f"freeze ({v} reveal skip{sk})")

    return ", ".join(parts) if parts else "—"


def enemy_expected(raw: dict) -> str:
    parts: list[str] = []
    dmg = raw.get("dmg") or 0
    if dmg > 0:
        p2 = raw.get("dmgP2")
        if p2 and p2 != dmg:
            parts.append(f"{dmg} dmg (P2 {p2})")
        else:
            parts.append(f"{dmg} dmg")

    dot = raw.get("dot") or 0
    if dot > 0:
        parts.append(f"{dot} DoT{turn_suffix(raw.get('dT') or 0)}")

    rfm = raw.get("rfm") or 0
    if rfm > 0:
        parts.append(f"-{rfm} roll{turn_suffix(raw.get('rfmT') or 0)}")

    if raw.get("wipeShields"):
        parts.append("wipe shields")

    heal = raw.get("heal") or 0
    if heal > 0:
        parts.append(f"{heal} heal")

    shield = raw.get("shield") or 0
    if shield > 0:
        parts.append(f"{shield} shield{turn_suffix(raw.get('shT') or 0)}")

    sa = raw.get("shieldAlly") or 0
    if sa > 0:
        ally_t = raw.get("shAllyT") or raw.get("shT") or 1
        parts.append(f"ally {sa} shield{turn_suffix(ally_t)}")

    if raw.get("enemySelfTaunt"):
        parts.append("taunt (all heroes must target this enemy)")

    rfe = raw.get("rfe") or 0
    if rfe > 0:
        parts.append(f"-{rfe} roll{turn_suffix(raw.get('rfT') or 0)}")

    ls = raw.get("lifestealPct") or 0
    if ls > 0:
        parts.append(f"lifesteal {ls}%")

    erb = raw.get("erb") or 0
    if erb > 0:
        t = turn_suffix(raw.get("erbT") or 0)
        if raw.get("erbAll"):
            parts.append(f"+{erb} roll to allies{t}")
        else:
            parts.append(f"+{erb} roll{t}")

    sc = raw.get("summonChance") or 0
    if sc > 0:
        parts.append(f"summon ~{sc}% nat20")

    cp = raw.get("counterspellPct") or 0
    if cp > 0:
        parts.append(f"counter C {cp}%")

    gr = raw.get("grantRampage") or 0
    if gr > 0:
        parts.append(f"rampage +{gr}")

    gra = raw.get("grantRampageAll") or 0
    if gra > 0:
        parts.append(f"rampage all +{gra}")

    ct = raw.get("cowerT") or 0
    if ct > 0:
        parts.append(f"cower all {ct}r" if raw.get("cowerAll") else f"cower {ct}r")

    return ", ".join(parts) if parts else "—"


def ability_fields(ab: dict) -> dict:
    skip = {"zone", "range", "name", "eff"}
    return {k: v for k, v in ab.items() if k not in skip}


def collect_issues(heroes: dict, enemies: dict) -> list[tuple]:
    issues: list[tuple] = []
    for hero in heroes.get("heroes", []):
        hn = hero.get("name", "?")
        for ab in hero.get("abilities", []):
            exp = hero_expected(ability_fields(ab))
            eff = ab.get("eff", "")
            if norm(eff) != norm(exp):
                issues.append(("hero", hn, ab.get("name"), ab.get("zone"), eff, exp))
        for evo in hero.get("evolutions", []):
            en = evo.get("name", "?")
            for ab in evo.get("abilities", []):
                exp = hero_expected(ability_fields(ab))
                eff = ab.get("eff", "")
                if norm(eff) != norm(exp):
                    issues.append(("evo", f"{hn}/{en}", ab.get("name"), ab.get("zone"), eff, exp))

    for etype, zones in enemies.get("enemyAbilities", {}).items():
        for zone, ab in zones.items():
            exp = enemy_expected(dict(ab))
            eff = ab.get("eff", "")
            if norm(eff) != norm(exp):
                issues.append(("enemy", etype, ab.get("name"), zone, eff, exp))
    return issues


def apply_normalization(heroes: dict, enemies: dict) -> int:
    changed = 0
    for hero in heroes.get("heroes", []):
        for ab in hero.get("abilities", []):
            exp = hero_expected(ability_fields(ab))
            if ab.get("eff", "") != exp:
                ab["eff"] = exp
                changed += 1
        for evo in hero.get("evolutions", []):
            for ab in evo.get("abilities", []):
                exp = hero_expected(ability_fields(ab))
                if ab.get("eff", "") != exp:
                    ab["eff"] = exp
                    changed += 1

    for zones in enemies.get("enemyAbilities", {}).values():
        for ab in zones.values():
            exp = enemy_expected(dict(ab))
            if ab.get("eff", "") != exp:
                ab["eff"] = exp
                changed += 1
    return changed


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main() -> int:
    apply = "--apply" in sys.argv
    heroes = json.loads(HEROES_PATH.read_text(encoding="utf-8"))
    enemies = json.loads(ENEMIES_PATH.read_text(encoding="utf-8"))

    if apply:
        changed = apply_normalization(heroes, enemies)
        write_json(HEROES_PATH, heroes)
        write_json(ENEMIES_PATH, enemies)
        print(f"Normalized {changed} ability eff strings.")
        issues = collect_issues(heroes, enemies)
        print(f"Remaining mismatches: {len(issues)}")
        return 0 if not issues else 1

    issues = collect_issues(heroes, enemies)
    print(f"Total eff mismatches vs canonical rules: {len(issues)}")
    for row in issues:
        print("---")
        print(f"{row[0]} | {row[1]} | {row[2]} ({row[3]})")
        print(f"  eff:      {row[4]}")
        print(f"  expected: {row[5]}")
    return 0 if not issues else 1


if __name__ == "__main__":
    sys.exit(main())
