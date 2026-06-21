#!/usr/bin/env python3
import json
from pathlib import Path

heroes = json.loads((Path(__file__).resolve().parents[2] / "data/raw/heroes.data.json").read_text(encoding="utf-8"))
for hero in heroes["heroes"]:
    print(f"\n### {hero['name']} ({hero['id']}) — HP {hero['hp']}")
    for ab in hero["abilities"]:
        z = ab.get("zone", "?")
        r = ab.get("range", [0, 0])
        print(f"  {z:9} d{r[0]}-{r[1]:<2}  {ab.get('name', '?'):26} {ab.get('eff', '')}")
