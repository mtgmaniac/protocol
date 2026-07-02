#!/usr/bin/env python3
"""Static gap audit: gear/relic effect types vs combat_manager + GameState handlers."""

from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

GEAR_HANDLED = {
    "rollBonus", "burnDmgBonus", "dmgReduction", "surviveOnce", "firstAbilityDmgBonus",
    "healOnKill", "protocolOnBattleStart", "battleStartShield", "battleStartCloak",
    "battleStartCloakRoll",
    "maxHpBonus", "lifesteal", "firstAbilityEcho", "shieldPierce", "healShieldBonus",
    "protocolOnKill", "protocolOnKillAny",
    # pkg3.4 pool
    "overloadBandCompress", "surgeBandExtend", "nudgeMaySubtract", "firstNudgeFree",
    "protocolOnNat20", "burnImmediateTick", "detonateBonus", "battleStartMark",
    "protocolOnDieTamper", "tauntAbove50", "deathDamageAll", "syncRollBonus",
}

RELIC_HANDLED = {
    "enemyDmgMult", "battleStartHalfHp", "heroShieldPerTurn", "heroHealPerTurn",
    "enemyBurnPermanent", "heroDmgMult", "enemyStartRfe", "heroStartRollBuff",
    "burnAmplified", "auraEnemyDmg", "protocolOnItemUse", "enemyHpEscalation",
    "chainReaction", "allyDeathHealAll", "critResolveTwice", "rewardsNoCommon",
    "protocolCarryover", "battleStartConsumable", "reviveNoPenalty",
    "lowHpSquadRollBuff", "healGrantsShieldAll",
}

GAMESTATE_ONLY = {"rewardsNoCommon", "reviveNoPenalty", "battleStartConsumable"}


def load_effect_types(path: Path, key: str | None) -> dict[str, list[str]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    entries = data[key] if key else data
    usage: dict[str, list[str]] = defaultdict(list)
    for entry in entries:
        effect = entry.get("effect") or {}
        et = str(effect.get("type", ""))
        if et:
            usage[et].append(str(entry.get("id", "?")))
    return usage


def main() -> int:
    gear = load_effect_types(ROOT / "data/raw/gear.data.json", "gear")
    relic = load_effect_types(ROOT / "data/raw/relics.data.json", None)

    gaps: list[str] = []
    print("=== Gear effect types ===")
    for et in sorted(gear):
        ok = et in GEAR_HANDLED
        print(f"  {'OK' if ok else 'GAP'} {et}: {gear[et]}")
        if not ok:
            gaps.append(f"gear:{et}")

    print("\n=== Relic effect types ===")
    for et in sorted(relic):
        handled = et in RELIC_HANDLED
        print(f"  {'OK' if handled else 'GAP'} {et}: {relic[et]}")
        if not handled:
            gaps.append(f"relic:{et}")

    print("\n=== Handlers with no data yet ===")
    for et in sorted(GEAR_HANDLED - set(gear.keys())):
        print(f"  gear handler unused in data: {et}")
    for et in sorted(RELIC_HANDLED - set(relic.keys())):
        print(f"  relic handler unused in data: {et}")

    if gaps:
        print("\nUnhandled effect types:", ", ".join(gaps))
        return 1
    print("\nAll gear/relic effect types in data are handled.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
