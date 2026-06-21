#!/usr/bin/env python3
"""Dump unit abilities for design review."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ZONES = ["recharge", "strike", "surge", "crit", "overload"]


def fmt(ab: dict) -> str:
    parts = []
    if ab.get("dmg"):
        s = f"{ab['dmg']} dmg"
        if ab.get("dmgP2"):
            s += f" (P2 {ab['dmgP2']})"
        parts.append(s)
    if ab.get("dot"):
        parts.append(f"{ab['dot']} dot {ab.get('dT', 2)}t")
    if ab.get("heal"):
        parts.append(f"{ab['heal']} heal")
    if ab.get("shield"):
        parts.append(f"{ab['shield']} sh {ab.get('shT', 2)}t")
    if ab.get("shieldP2"):
        parts.append(f"P2 sh {ab['shieldP2']}")
    if ab.get("rfm"):
        parts.append(f"-{ab['rfm']} roll {ab.get('rfmT', 1)}t")
    if ab.get("erb"):
        erb = f"+{ab['erb']} roll"
        if ab.get("erbAll"):
            erb += " all"
        parts.append(f"{erb} {ab.get('erbT', 1)}t")
    if ab.get("shieldAlly"):
        parts.append(f"{ab['shieldAlly']} sh ally")
    if ab.get("wipeShields"):
        parts.append("wipe sh")
    if ab.get("blastAll"):
        parts.append("blast all")
    if ab.get("lifestealPct"):
        parts.append(f"ls {ab['lifestealPct']}%")
    if ab.get("packBonus"):
        parts.append("pack+")
    if ab.get("cowerAll"):
        parts.append("cower all")
    if ab.get("grantRampageAll"):
        parts.append(f"rampage all +{ab['grantRampageAll']}")
    if ab.get("summon"):
        parts.append(f"summon {ab['summon']}")
    if ab.get("shieldAll"):
        parts.append(f"{ab.get('shield', 0)} sh all")
    if ab.get("healAll"):
        parts.append(f"{ab.get('heal', 0)} heal all")
    if ab.get("healLowest"):
        parts.append(f"{ab.get('heal', 0)} heal lowest")
    if ab.get("ignSh"):
        parts.append("ign sh")
    if ab.get("multiHit"):
        parts.append("multi")
    if not parts:
        return (ab.get("eff") or "—")[:50]
    return "; ".join(parts)


enemies = json.loads((ROOT / "data/raw/enemies.data.json").read_text(encoding="utf-8"))
heroes = json.loads((ROOT / "data/raw/heroes.data.json").read_text(encoding="utf-8"))

print("=== ENEMY SUITES ===")
for t, suite in enemies["enemyAbilities"].items():
    print(f"\n[{t}]")
    for z in ZONES:
        ab = suite.get(z, {})
        print(f"  {z:9} {ab.get('name', '?'):24} {fmt(ab)}")

print("\n=== ENEMY UNITS (by type) ===")
by_type: dict[str, list] = {}
for name, d in enemies["enemyUnitDefs"].items():
    by_type.setdefault(d["type"], []).append((name, d))
for t in sorted(by_type):
    for name, d in by_type[t]:
        print(f"  {name:24} hp={d['hp']:3} d={d.get('dMin','?')}-{d.get('dMax','?')} ai={d['ai']}")

print("\n=== HEROES ===")
for h in heroes["heroes"]:
    print(f"\n{h['id']} | {h.get('name', h['id'])} | hp={h.get('hp')} | {h.get('focus', '')}")
    abl = h.get("abilities", {})
    if isinstance(abl, list):
        for entry in abl:
            z = entry.get("zone", "?")
            raw = entry
            print(f"  {z:9} {raw.get('name', '?'):24} {fmt(raw)}")
    else:
        for z in ZONES:
            ab = abl.get(z, {})
            if ab:
                print(f"  {z:9} {ab.get('name', '?'):24} {fmt(ab)}")
    for evo in h.get("evolutions", []):
        print(f"  EVO -> {evo.get('name')} ({evo.get('focus', '')}) hp={evo.get('hp')}")
        for ab in evo.get("abilities", []):
            z = ab.get("zone", "?")
            print(f"    {z:9} {ab.get('name', '?'):24} {fmt(ab)}")
