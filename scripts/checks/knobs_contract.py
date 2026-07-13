#!/usr/bin/env python3
"""knobs.json defaults ⇄ shipped data contract gate (2026-07-12).

scripts/sim/knobs.json states its own law: "defaults MUST be the shipped value
so an empty tuning dict is byte-identical." For `ability_field` knobs that means
the `default` must equal the current value of the field the `tuning_key` points
at in data/raw/heroes.data.json. This actually broke: after Batch-1 retuned the
GLACIER line, glacier_lance_dmg still defaulted to 12 (shipped 10),
glacier_lance_frozen_bonus to 6 (shipped 5), and glacier_aegis_shield pointed at
a `shield` field that no longer exists on Permafrost Aegis (now dmg/vsFrozenBonus).
Silent drift → the balance sweep would inject phantom values.

This gate resolves every ability_field tuning_key the same way sim_runner.gd does
(heroId/PathName/AbilityName/field; PathName "base" → hero.abilities, else the
matching evolution's abilities) and fails on: unknown hero/path/ability, a MISSING
field (phantom knob), or default ≠ shipped value.

Engine-tuning knobs are covered separately by ci_smoke (byte-identity proof); this
gate scopes to ability_field, the class that drifted.

Prints "[KNOBS_CONTRACT] PASS" only when clean; the verify gate keys on that.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
KNOBS = ROOT / "scripts" / "sim" / "knobs.json"
HEROES = ROOT / "data" / "raw" / "heroes.data.json"


def resolve(heroes_by_id: dict, tuning_key: str):
    """Return (status, value) mirroring sim_runner._apply_ability_field_tuning."""
    if not tuning_key.startswith("ability:"):
        return ("NOT_ABILITY_KEY", None)
    parts = tuning_key[len("ability:"):].split("/")
    if len(parts) != 4:
        return ("BAD_PATH", None)
    hero_id, path_name, ability_name, field = parts
    hero = heroes_by_id.get(hero_id)
    if hero is None:
        return ("NO_HERO", None)
    if path_name == "base":
        abilities = hero.get("abilities", [])
    else:
        evo = next((e for e in hero.get("evolutions", []) if e.get("name") == path_name), None)
        if evo is None:
            return ("NO_PATH", None)
        abilities = evo.get("abilities", [])
    ability = next((a for a in abilities if a.get("name") == ability_name), None)
    if ability is None:
        return ("NO_ABILITY", None)
    if field not in ability:
        return ("NO_FIELD", None)
    return ("OK", ability[field])


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

    registry = json.loads(KNOBS.read_text(encoding="utf-8"))
    heroes_by_id = {h["id"]: h for h in json.loads(HEROES.read_text(encoding="utf-8"))["heroes"]}

    ability_knobs = [k for k in registry["knobs"] if k.get("kind") == "ability_field"]
    print(f"── knobs.json contract: {len(ability_knobs)} ability_field knobs vs shipped data", flush=True)

    violations = []
    for k in ability_knobs:
        kid = k.get("id", "?")
        status, val = resolve(heroes_by_id, k.get("tuning_key", ""))
        if status != "OK":
            violations.append(
                f"{kid}: tuning_key `{k.get('tuning_key')}` -> {status} "
                f"(field does not resolve in heroes.data.json)"
            )
            continue
        if val != k.get("default"):
            violations.append(
                f"{kid}: default {k.get('default')} != shipped {val} "
                f"(`{k.get('tuning_key')}`)"
            )

    if violations:
        print("   FAIL — knobs.json defaults drifted from shipped data:")
        for msg in violations:
            print(f"     • {msg}")
        print(
            "\n   Fix: set each knob's `default` to the shipped heroes.data.json value "
            "(or\n   retarget/remove a knob whose field no longer exists). An empty tuning "
            "dict\n   must reproduce the shipped game byte-for-byte (INVARIANTS #9).",
        )
        return 1
    print("   [KNOBS_CONTRACT] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
