"""Canonical eff + inspect text from structured ability dicts (heroes and enemies)."""
from __future__ import annotations

from typing import Any


def turns(count: int) -> str:
    return f"{count} turn" + ("" if count == 1 else "s")


def _t(count: int) -> str:
    return f", {count}t" if count > 1 else ""


def _int(raw: dict[str, Any], key: str, default: int = 0) -> int:
    value = raw.get(key, default)
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _bool(raw: dict[str, Any], key: str) -> bool:
    return bool(raw.get(key, False))


def _freeze_eff(raw: dict[str, Any], side: str) -> str | None:
    """Kev 2026-07-10: name the dice, drop the '(repeat 1)' jargon.
    Repeats > 1 get a ' x2' suffix."""
    n_all = _int(raw, "freezeAllEnemyDice")
    n_one = _int(raw, "freezeEnemyDice")
    n_any = _int(raw, "freezeAnyDice")
    count = max(n_all, n_one, n_any)
    if count <= 0:
        return None
    if n_all > 0:
        base = "freeze all enemy dice" if side == "hero" else "freeze all hero dice"
    elif n_any > 0:
        base = "freeze any die"
    else:
        base = "freeze target die" if side == "hero" else "freeze a hero die"
    return base + (f" x{count}" if count > 1 else "")


def _freeze_inspect(raw: dict[str, Any]) -> str | None:
    freeze_any = max(
        _int(raw, "freezeAnyDice"),
        _int(raw, "freezeEnemyDice"),
        _int(raw, "freezeAllEnemyDice"),
    )
    if freeze_any <= 0:
        return None
    duration = turns(freeze_any)
    if _int(raw, "freezeAllEnemyDice") > 0:
        return f"Freeze all enemy dice for {duration}."
    if _int(raw, "freezeEnemyDice") > 0:
        return f"Freeze the target's die for {duration}."
    return f"Freeze the target's die for {duration}."


def format_eff(raw: dict[str, Any], side: str) -> str:
    """Canonical short eff line (Kev 2026-07-10 style pass).

    RULES:
    - Chunk ORDER mirrors the effect-pip order (EffectPip.effects_from_ability_raw)
      so the text always reads in the same sequence as the pips above it.
    - Scope qualifiers are parenthesized suffixes: (all) / (self) / (lowest).
      A targeted ally heal/shield is the plain form — "ally" is insinuated.
    - Freeze names the dice ("freeze any die", "freeze all enemy dice") — no
      repeat/reveal jargon; repeats > 1 get " x2".
    - Keywords are their bare glossary names ("leech", "pierce", "taunt") —
      rules live in the glossary + first-sighting primers, not here.
    """
    if not raw:
        return ""

    parts: list[str] = []

    # 1. damage
    dmg = _int(raw, "dmg")
    dmg_p2 = _int(raw, "dmgP2")
    d_min = _int(raw, "dMin")
    d_max = _int(raw, "dMax")
    if dmg > 0:
        chunk = f"{dmg} dmg"
        if dmg_p2 > 0:
            chunk += f" (P2 {dmg_p2})"
        if _bool(raw, "blastAll"):
            chunk += " (all)"
        parts.append(chunk)
    elif d_min > 0 or d_max > 0:
        parts.append(f"{d_min} dmg" if d_min == d_max else f"{d_min}-{d_max} dmg")

    # 2. burn
    burn = _int(raw, "burn")
    if burn > 0:
        parts.append(f"{burn} burn{_t(_int(raw, 'burnT'))}")

    # 3. shield (self/targeted/all), then the ally-shield field
    shield = _int(raw, "shield")
    shield_p2 = _int(raw, "shieldP2")
    if shield > 0:
        chunk = f"{shield} shield"
        if shield_p2 > 0:
            chunk += f" (P2 {shield_p2})"
        if _bool(raw, "shieldAll"):
            chunk += " (all)"
        elif _bool(raw, "shieldLowest"):
            chunk += " (lowest)"
        elif not _bool(raw, "shTgt") and (side == "hero" or _int(raw, "shieldAlly") > 0):
            # Hero self-shield is always qualified; an enemy's is only when the
            # same ability ALSO grants an ally shield (else "6 shield, 6 shield").
            chunk += " (self)"
        parts.append(chunk)
    shield_ally = _int(raw, "shieldAlly")
    if shield_ally > 0:
        parts.append(f"{shield_ally} shield" + (" (all)" if _bool(raw, "shieldAllyAll") else ""))

    # 4. heal — plain for a targeted ally; qualify self / lowest / all
    heal = _int(raw, "heal")
    if heal > 0:
        chunk = f"{heal} heal"
        if _bool(raw, "healAll"):
            chunk += " (all)"
        elif _bool(raw, "healLowest"):
            chunk += " (lowest)"
        elif not _bool(raw, "healTgt") and side == "hero":
            # A hero heal without healTgt heals SELF (combat_manager contract);
            # an enemy's plain heal reads as self-heal without the qualifier.
            chunk += " (self)"
        parts.append(chunk)

    # 5. -roll (hero rfe / enemy rfm are both hostile roll reductions)
    if side == "hero":
        rfe = _int(raw, "rfe")
        if rfe > 0:
            parts.append(f"-{rfe} roll" + (" (all)" if _bool(raw, "rfeAll") else "") + _t(_int(raw, "rfT")))
    else:
        rfm = _int(raw, "rfm")
        if rfm > 0:
            parts.append(f"-{rfm} roll{_t(_int(raw, 'rfmT'))}")

    # 6. +roll (hero rfm / enemy erb)
    if side == "hero":
        rfm = _int(raw, "rfm")
        if rfm > 0:
            parts.append(f"+{rfm} roll" + ("" if _bool(raw, "rfmTgt") else " (all)") + _t(_int(raw, "rfmT")))
    else:
        erb = _int(raw, "erb")
        if erb > 0:
            parts.append(f"+{erb} roll" + (" (all)" if _bool(raw, "erbAll") else "") + _t(_int(raw, "erbT")))

    # 7+. keywords, in pip order
    if _bool(raw, "ignSh"):
        parts.append("pierce")
    chain = _int(raw, "chain")
    if chain > 0:
        parts.append("chain" if chain == 1 else f"chain x{chain}")
    if _bool(raw, "detonate"):
        parts.append("detonate")
    if _bool(raw, "execute"):
        parts.append("execute")
    if _bool(raw, "breachAll"):
        parts.append("breach (all)")
    elif _bool(raw, "breach"):
        parts.append("breach")
    elif _bool(raw, "wipeShields"):
        parts.append("wipe shields")
    if _bool(raw, "leech"):
        parts.append("leech")
    lifesteal = _int(raw, "lifestealPct")
    if lifesteal > 0:
        parts.append(f"lifesteal {lifesteal}%")
    if _bool(raw, "mark"):
        parts.append("mark")
    spike = _int(raw, "spike")
    if spike > 0:
        parts.append(f"spike {spike}")
    if _bool(raw, "jamAll"):
        parts.append("jam (all)")
    elif _bool(raw, "jam"):
        parts.append("jam")
    if _bool(raw, "rewrite"):
        parts.append("rewrite")
    if _bool(raw, "hijack"):
        parts.append("hijack")
    siphon = _int(raw, "siphon")
    if siphon > 0:
        parts.append(f"siphon {siphon}")
    if _bool(raw, "cloak"):
        parts.append("cloak")
    if _bool(raw, "ward"):
        parts.append("firewall")
    freeze_eff = _freeze_eff(raw, side)
    if freeze_eff:
        parts.append(freeze_eff)
    if _bool(raw, "enemySelfTaunt") or _bool(raw, "taunt"):
        parts.append("taunt")
    if _bool(raw, "reviveAll"):
        parts.append(f"revive all {_int(raw, 'revivePct', 50)}%")
    elif _bool(raw, "revive"):
        parts.append(f"revive {_int(raw, 'revivePct', 50)}%")
    if _bool(raw, "grantRampageAll"):
        parts.append("rampage +1 (all)")
    elif _int(raw, "grantRampage") > 0:
        parts.append(f"rampage +{_int(raw, 'grantRampage')}")

    # trailers with no pip
    if _bool(raw, "packBonus"):
        parts.append("pack bonus")
    if _int(raw, "summonChance") > 0:
        parts.append(f"summon ({_int(raw, 'summonChance')}%)")
    if _int(raw, "vsFrozenBonus") > 0:
        parts.append(f"+{_int(raw, 'vsFrozenBonus')} vs frozen")
    protocol = _int(raw, "gainProtocol")
    if protocol > 0:
        parts.append(f"+{protocol} protocol")

    if not parts:
        return "—"
    return ", ".join(parts)


def format_inspect(raw: dict[str, Any], side: str) -> str:
    """Full sentences; hostile/target effects first, then ally buffs."""
    if not raw:
        return ""

    hostile: list[str] = []
    friendly: list[str] = []

    if _bool(raw, "wipeShields"):
        hostile.append("Remove all hero shields.")

    dmg = _int(raw, "dmg")
    dmg_p2 = _int(raw, "dmgP2")
    d_min = _int(raw, "dMin")
    d_max = _int(raw, "dMax")
    blast_all = _bool(raw, "blastAll")

    if dmg > 0:
        if side == "enemy" and blast_all:
            hostile.append(f"Deal {dmg} damage to all heroes.")
        elif blast_all:
            hostile.append(f"Deal {dmg} damage to all enemies.")
        else:
            hostile.append(f"Deal {dmg} damage.")
        if dmg_p2 > 0:
            hostile.append(f"Phase 2: deals {dmg_p2} damage instead.")
    elif d_min > 0 or d_max > 0:
        hostile.append(
            f"Deal {d_min} damage." if d_min == d_max else f"Deal {d_min}-{d_max} damage."
        )

    burn = _int(raw, "burn")
    if burn > 0:
        d_t = _int(raw, "burnT")
        suffix = f" for {turns(d_t)}" if d_t > 0 else ""
        hostile.append(f"Deal {burn} damage per turn{suffix}.")

    if _bool(raw, "ignSh"):
        hostile.append("Pierces enemy shields." if side == "hero" else "Pierces hero shields.")

    lifesteal = _int(raw, "lifestealPct")
    if lifesteal > 0:
        hostile.append(f"Heal for {lifesteal}% of damage dealt.")

    if side == "hero":
        rfe = _int(raw, "rfe")
        if rfe > 0:
            rf_t = _int(raw, "rfT")
            suffix = f" for {turns(rf_t)}" if rf_t > 0 else ""
            if _bool(raw, "rfeAll"):
                hostile.append(f"Reduce all enemy rolls by {rfe}{suffix}.")
            else:
                hostile.append(f"Reduce an enemy roll by {rfe}{suffix}.")
    else:
        rfm = _int(raw, "rfm")
        if rfm > 0:
            rfm_t = _int(raw, "rfmT")
            suffix = f" for {turns(rfm_t)}" if rfm_t > 0 else ""
            hostile.append(f"Reduce a hero roll by {rfm}{suffix}.")

    freeze_line = _freeze_inspect(raw)
    if freeze_line:
        hostile.append(freeze_line)

    if _bool(raw, "curseDice"):
        hostile.append("Target hero rolls twice next turn and keeps the lower result.")

    freeze_all = _int(raw, "freezeAllEnemyDice")
    freeze_one = _int(raw, "freezeEnemyDice")
    if freeze_all > 0:
        hostile.append(
            f"Freezes every hero die: locked in the tray, skipping the next "
            f"{freeze_all} reveal{'s' if freeze_all > 1 else ''}."
        )
    elif freeze_one > 0:
        hostile.append(
            f"Freezes the target hero's die: locked in the tray, skipping the next "
            f"{freeze_one} reveal{'s' if freeze_one > 1 else ''}."
        )

    if _bool(raw, "packBonus"):
        hostile.append("Damage increases by the number of living allies of the same type.")

    summon = _int(raw, "summonChance")
    if summon > 0:
        hostile.append(f"{summon}% chance to summon an elite on natural 20 overload.")

    heal = _int(raw, "heal")
    if heal > 0:
        if _bool(raw, "healAll"):
            friendly.append(f"Restore {heal} HP to all allies.")
        elif _bool(raw, "healLowest"):
            friendly.append(f"Restore {heal} HP to the lowest-HP ally.")
        elif _bool(raw, "healTgt"):
            friendly.append(f"Restore {heal} HP to an ally.")
        elif side == "hero" and dmg > 0:
            friendly.append(f"Restore {heal} HP to self.")
        elif side == "enemy":
            friendly.append(f"Restore {heal} HP.")
        else:
            friendly.append(f"Restore {heal} HP.")

    shield = _int(raw, "shield")
    shield_p2 = _int(raw, "shieldP2")
    if shield > 0:
        if _bool(raw, "shieldAll"):
            friendly.append(f"Grant {shield} shield to all allies this round.")
        elif _bool(raw, "shTgt"):
            friendly.append(f"Grant {shield} shield to an ally this round.")
        else:
            friendly.append(f"Gain {shield} shield this round.")
        if shield_p2 > 0:
            friendly.append(f"Phase 2: gain {shield_p2} shield instead.")

    shield_ally = _int(raw, "shieldAlly")
    if shield_ally > 0:
        if _bool(raw, "shieldAllyAll"):
            friendly.append(f"Grant {shield_ally} shield to all allies this round.")
        else:
            friendly.append(f"Grant {shield_ally} shield to an ally this round.")

    if side == "hero":
        rfm = _int(raw, "rfm")
        if rfm > 0:
            rfm_t = _int(raw, "rfmT")
            suffix = f" for {turns(rfm_t)}" if rfm_t > 0 else ""
            if _bool(raw, "rfmTgt"):
                friendly.append(f"Increase an ally's roll by {rfm}{suffix}.")
            else:
                friendly.append(f"Increase all squad rolls by {rfm}{suffix}.")
    else:
        erb = _int(raw, "erb")
        if erb > 0:
            erb_t = _int(raw, "erbT")
            suffix = f" for {turns(erb_t)}" if erb_t > 0 else ""
            if _bool(raw, "erbAll"):
                friendly.append(f"Increase all ally enemies' rolls by {erb}{suffix}.")
            else:
                friendly.append(f"Increase this enemy's roll by {erb}{suffix}.")

    if _bool(raw, "ward"):
        friendly.append("Firewall: blocks the next ability that targets this unit, then breaks.")

    if _bool(raw, "grantRampageAll"):
        friendly.append("Grant Rampage to all enemies.")
    elif _int(raw, "grantRampage") > 0:
        friendly.append("Gain Rampage (next hit deals double damage).")

    if _bool(raw, "enemySelfTaunt"):
        friendly.append("Taunt: all heroes must target this enemy.")
    elif _bool(raw, "taunt"):
        friendly.append("Taunt: enemies must target this unit.")

    if _bool(raw, "cloak"):
        friendly.append("Cloak: untargetable by hostile single-target abilities; breaks on dealing damage or an AoE hit.")

    if _bool(raw, "reviveAll"):
        friendly.append(f"Revive all fallen allies at {_int(raw, 'revivePct', 50)}% max HP.")
    elif _bool(raw, "revive"):
        friendly.append(f"Revive a fallen ally at {_int(raw, 'revivePct', 50)}% max HP.")

    protocol = _int(raw, "gainProtocol")
    if protocol > 0:
        friendly.append(f"Gain {protocol} Protocol.")

    parts = hostile + friendly
    if not parts:
        return "No effect."
    return " ".join(parts)
