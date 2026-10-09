#!/usr/bin/env python3
"""Roll windows gate (Kev 2026-10-08, G-53).

Every unit rolls a d20 into one of five bands. The bands' ranges live in the
data (`range` on each ability: heroes.data.json for heroes and evolutions,
enemies.data.json per enemy kit) and nowhere else. This gate checks the data:

  * every hero, every evolution and every enemy kit has exactly five bands, in
    band order, contiguous, covering 1-20 with no gap and no overlap
  * only Pyro, Wraith and Spine Stalker have a top band wider than one face
    (19-20); every other unit's top band is the 20 alone (Phaseblade's went
    back to the 20 on 2026-10-08, pending the summons decision, G-55)
  * `heroZones` (the per-hero copy at the top of heroes.data.json) matches the
    base abilities' ranges
  * every enemy unit's kit exists, and no kit is shared by a unit that has the
    wide top and one that does not
  * no shared enemy range table has come back in code (ENEMY_ZONE_RANGES), and
    DataManager builds enemy bands from each ability's `range`

Then it proves it can fail: each rule is broken in memory and must be reported.
The loaded resources, the inspect table and the band-shifting gear are checked
at run time by scripts/debug/roll_windows_test.gd (gate `roll windows live`).

Exit 0 = pass, 1 = drift.
"""
from __future__ import annotations

import copy
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HEROES = ROOT / "data" / "raw" / "heroes.data.json"
ENEMIES = ROOT / "data" / "raw" / "enemies.data.json"
DATA_MANAGER = ROOT / "scripts" / "autoloads" / "DataManager.gd"
ZONES = ["recharge", "strike", "surge", "crit", "overload"]
# The only units whose top band is wider than one face.
WIDE_TOP_EVOLUTIONS = {"pyro": "Pyro", "wraith": "Wraith"}
WIDE_TOP_ENEMIES = {"Spine Stalker"}
WIDE_TOP = [19, 20]
NARROW_TOP = [20, 20]
SHARED_TABLE = "ENEMY_ZONE_RANGES"


def band_errors(label: str, bands: list) -> list[str]:
    """`bands` is the unit's [low, high] pairs in band order."""
    errors: list[str] = []
    if len(bands) != 5:
        return [f"{label}: {len(bands)} bands, not five"]
    for index, pair in enumerate(bands):
        if not (isinstance(pair, list) and len(pair) == 2 and all(isinstance(v, int) for v in pair)):
            return [f"{label}: band {index + 1} has no [low, high] range ({pair!r})"]
        if pair[0] > pair[1]:
            errors.append(f"{label}: band {index + 1} is empty ({pair[0]}-{pair[1]})")
    if bands[0][0] != 1:
        errors.append(f"{label}: band 1 starts at {bands[0][0]}, not 1")
    if bands[-1][1] != 20:
        errors.append(f"{label}: the top band ends at {bands[-1][1]}, not 20")
    for index in range(4):
        low_next, high = bands[index + 1][0], bands[index][1]
        if low_next > high + 1:
            errors.append(f"{label}: faces {high + 1}-{low_next - 1} fall between band {index + 1} and band {index + 2}")
        elif low_next <= high:
            errors.append(f"{label}: band {index + 1} and band {index + 2} overlap on {low_next}-{high}")
    return errors


def top_errors(label: str, bands: list, wide: bool) -> list[str]:
    if len(bands) != 5 or not isinstance(bands[-1], list):
        return []
    want = WIDE_TOP if wide else NARROW_TOP
    if bands[-1] == want:
        return []
    shown = "-".join(str(v) for v in bands[-1])
    if wide:
        return [f"{label}: the top band is {shown}; this unit's is 19-20"]
    return [f"{label}: the top band is {shown}; only Pyro, Wraith and Spine Stalker go wider than the 20"]


def ability_bands(label: str, abilities: list) -> tuple[list, list[str]]:
    zones = [a.get("zone") for a in abilities]
    errors = [] if zones == ZONES else [f"{label}: bands are {zones}, not the five in order"]
    return [a.get("range") for a in abilities], errors


def check(heroes: dict, enemies: dict, data_manager: str, other_sources: dict) -> list[str]:
    failures: list[str] = []
    hero_zones = heroes.get("heroZones", {})
    seen_wide: set = set()
    for hero in heroes.get("heroes", []):
        label = hero.get("name", hero.get("id", "?"))
        bands, errors = ability_bands(label, hero.get("abilities", []))
        failures += errors + band_errors(label, bands) + top_errors(label, bands, False)
        copy_rows = hero_zones.get(hero.get("id"))
        want_rows = [[pair[0], pair[1], zone] for pair, zone in zip(bands, ZONES)] if all(isinstance(p, list) and len(p) == 2 for p in bands) else None
        if copy_rows != want_rows:
            failures.append(f"{label}: heroZones does not match the abilities' ranges")
        for evo in hero.get("evolutions", []):
            evo_label = evo.get("name", evo.get("id", "?"))
            wide = evo.get("id") in WIDE_TOP_EVOLUTIONS
            if wide:
                seen_wide.add(evo.get("id"))
            evo_bands, evo_errors = ability_bands(evo_label, evo.get("abilities", []))
            failures += evo_errors + band_errors(evo_label, evo_bands) + top_errors(evo_label, evo_bands, wide)
    if set(hero_zones) != {hero.get("id") for hero in heroes.get("heroes", [])}:
        failures.append("heroZones does not list exactly the heroes")
    for missing in sorted(set(WIDE_TOP_EVOLUTIONS) - seen_wide):
        failures.append(f"evolution '{missing}' ({WIDE_TOP_EVOLUTIONS[missing]}) is not in the data")

    kits: dict = enemies.get("enemyAbilities", {})
    kit_wide: dict = {}
    seen_enemies: set = set()
    for name, unit in enemies.get("enemyUnitDefs", {}).items():
        kit = unit.get("type")
        if kit not in kits:
            failures.append(f"{name}: kit '{kit}' is not in enemyAbilities")
            continue
        wide = name in WIDE_TOP_ENEMIES
        if wide:
            seen_enemies.add(name)
        if kit_wide.setdefault(kit, wide) != wide:
            failures.append(f"{name}: kit '{kit}' is shared with a unit that has a different top band")
    for missing in sorted(WIDE_TOP_ENEMIES - seen_enemies):
        failures.append(f"enemy '{missing}' is not in the data")
    for kit, suite in kits.items():
        label = f"enemy kit {kit}"
        if list(suite.keys()) != ZONES:
            failures.append(f"{label}: bands are {list(suite.keys())}, not the five in order")
            continue
        bands = [suite[zone].get("range") for zone in ZONES]
        failures += band_errors(label, bands) + top_errors(label, bands, kit_wide.get(kit, False))
        if kit not in kit_wide:
            failures.append(f"{label}: no enemy unit uses it")

    if SHARED_TABLE in data_manager:
        failures.append(f"DataManager.gd defines {SHARED_TABLE}: enemy ranges are in the data, per kit")
    if 'ability_entry.get("range", [])' not in data_manager.split("func _build_enemy_dice_ranges", 1)[-1].split("\nfunc ", 1)[0]:
        failures.append("DataManager._build_enemy_dice_ranges does not read each ability's `range`")
    for path, text in other_sources.items():
        if SHARED_TABLE in text:
            failures.append(f"{path} carries its own {SHARED_TABLE} table")
    return failures


def sources() -> dict:
    found: dict = {}
    for pattern in ("scripts/**/*.gd", "scripts/**/*.py"):
        for path in ROOT.glob(pattern):
            if path.resolve() in (Path(__file__).resolve(), DATA_MANAGER.resolve()):
                continue
            found[path.relative_to(ROOT).as_posix()] = path.read_text(encoding="utf-8", errors="replace")
    return found


def hero(heroes: dict, hero_id: str) -> dict:
    return next(h for h in heroes["heroes"] if h["id"] == hero_id)


def evolution(heroes: dict, hero_id: str, evo_id: str) -> dict:
    return next(e for e in hero(heroes, hero_id)["evolutions"] if e["id"] == evo_id)


def breaks(heroes: dict, enemies: dict, data_manager: str) -> list:
    """(name, heroes, enemies, DataManager source, other sources) per deliberate break."""
    out = []

    def add(name: str, mutate) -> None:
        h, e = copy.deepcopy(heroes), copy.deepcopy(enemies)
        state = {"dm": data_manager, "other": {}}
        mutate(h, e, state)
        out.append((name, h, e, state["dm"], state["other"]))

    def gap(h, e, s):
        hero(h, "pulse")["abilities"][1]["range"][0] += 1
    add("a gap between two hero bands", gap)

    def overlap(h, e, s):
        e["enemyAbilities"]["scrap"]["strike"]["range"][1] += 1
    add("two enemy bands overlap", overlap)

    def short(h, e, s):
        evolution(h, "combat", "ravager")["abilities"][4]["range"] = [19, 19]
        evolution(h, "combat", "ravager")["abilities"][3]["range"][1] = 18
    add("an evolution stops at 19", short)

    def four(h, e, s):
        hero(h, "medic")["abilities"].pop(2)
    add("a hero with four bands", four)

    def no_range(h, e, s):
        del e["enemyAbilities"]["hiveBoss"]["surge"]["range"]
    add("an enemy band with no range", no_range)

    def wide_hero(h, e, s):
        hero(h, "combat")["abilities"][3]["range"][1] = 18
        hero(h, "combat")["abilities"][4]["range"] = [19, 20]
        h["heroZones"]["combat"][3][1] = 18
        h["heroZones"]["combat"][4][0] = 19
    add("Strike Unit given a 19-20 top", wide_hero)

    def wide_enemy(h, e, s):
        e["enemyAbilities"]["boss"]["crit"]["range"][1] = 18
        e["enemyAbilities"]["boss"]["overload"]["range"] = [19, 20]
    add("a boss given a 19-20 top", wide_enemy)

    def phaseblade(h, e, s):
        e["enemyAbilities"]["veilNull"]["crit"]["range"][1] = 18
        e["enemyAbilities"]["veilNull"]["overload"]["range"] = [19, 20]
    add("Phaseblade given its 19-20 top back", phaseblade)

    def narrow(h, e, s):
        evolution(h, "pulse", "pyro")["abilities"][3]["range"][1] = 19
        evolution(h, "pulse", "pyro")["abilities"][4]["range"] = [20, 20]
    add("Pyro's top narrowed to the 20", narrow)

    def zones_copy(h, e, s):
        h["heroZones"]["ghost"][0][1] = 2
        h["heroZones"]["ghost"][1][0] = 3
    add("heroZones left on the old ranges", zones_copy)

    def table(h, e, s):
        s["dm"] = data_manager + '\nconst %s := {"recharge": Vector2i(1, 4)}\n' % SHARED_TABLE
    add("the shared enemy table back in DataManager", table)

    def copy_table(h, e, s):
        s["other"] = {"scripts/debug/some_tool.py": "%s = {'recharge': (1, 4)}" % SHARED_TABLE}
    add("a tool script with its own enemy table", copy_table)
    return out


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    heroes = json.loads(HEROES.read_text(encoding="utf-8"))
    enemies = json.loads(ENEMIES.read_text(encoding="utf-8"))
    data_manager = DATA_MANAGER.read_text(encoding="utf-8")
    units = len(heroes["heroes"]) + sum(len(h["evolutions"]) for h in heroes["heroes"])
    print(f"-- roll windows: {units} heroes and evolutions, {len(enemies['enemyAbilities'])} enemy kits, "
          f"{len(enemies['enemyUnitDefs'])} enemy units")
    failures = check(heroes, enemies, data_manager, sources())
    for failure in failures:
        print(f"   FAIL {failure}")
    undetected = 0
    for name, h, e, dm, other in breaks(heroes, enemies, data_manager):
        caught = check(h, e, dm, other)
        if caught:
            print(f"   ok   break detected: {name} ({caught[0]})")
        else:
            undetected += 1
            print(f"   FAIL break NOT detected: {name}")
    if failures or undetected:
        print(f"[ROLL_WINDOWS] FAIL - {len(failures)} drift(s), {undetected} undetected break(s)")
        return 1
    print("[ROLL_WINDOWS] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
