#!/usr/bin/env python3
"""Framing data gate — assets/portraits/portrait_anchors.json (schema 2).

The file holds ONE framing entry per asset, read on every screen by
PixelUI.cover_fit_portrait / PixelUI.fit_item_art. This gate keeps it honest:

  * shape: _schema == 2, the five sections exist, _targets has a sane
    head_top / head_height fraction per portrait section
  * every key names a real, live asset in the right section:
      heroes  -> a live hero portrait (base or evolution, heroes.data.json)
      enemies -> a non-boss enemy's portrait file basename
      bosses  -> an operation boss's portrait file basename (boss = the
                 operation's highest-HP enemy, DataManager._load_enemy_portraits)
      items   -> a consumable / gear id with art (DataManager.ITEM_ICON_BY_ID)
      relics  -> a relic id with art (DataManager.RELIC_ICON_BY_ID)
  * every field is known and every value is in range for its image
    (head_top < chin inside the image, centres inside, insets leave art).

Exit 0 = pass, 1 = fail.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "assets" / "portraits" / "portrait_anchors.json"
DM = ROOT / "scripts" / "autoloads" / "DataManager.gd"
PORTRAITS = ROOT / "assets" / "portraits"
SECTIONS = ("heroes", "enemies", "bosses", "items", "relics")
PORTRAIT_FIELDS = {"head_top", "chin", "center_x", "use_anchors", "insets", "reviewed", "stray",
                   "legacy_zoom", "legacy_anchor_y", "legacy_down_px"}
ART_FIELDS = {"center_x", "center_y", "scale", "insets", "reviewed", "stray"}
INSET_EDGES = {"left", "top", "right", "bottom"}
MIN_ART_SHARE = 0.25  # insets must leave at least this share of each axis (and 8 px)


def gd_dict(src: str, name: str) -> dict[str, str]:
    start = src.index(f"{name} := {{")
    end = src.index("\n}", start)
    return dict(re.findall(r'"([^"]+)":\s*"([^"]+)"', src[start:end]))


def slugify(name: str) -> str:
    out = name.lower().strip()
    for a, b in ((" ", "_"), ("-", "_"), ("/", "_"), (".", "")):
        out = out.replace(a, b)
    return out


def res_path(path: str) -> Path:
    return ROOT / path.replace("res://", "")


def live_assets() -> dict[str, dict[str, Path]]:
    src = DM.read_text(encoding="utf-8")
    out: dict[str, dict[str, Path]] = {s: {} for s in SECTIONS}
    heroes = json.loads((ROOT / "data" / "raw" / "heroes.data.json").read_text(encoding="utf-8"))["heroes"]
    hero_files = gd_dict(src, "HERO_PORTRAIT_BY_ID")
    for hero in heroes:
        base = hero_files.get(hero["id"], "")
        if base:
            out["heroes"][Path(base).stem] = PORTRAITS / base
        for evo in hero.get("evolutions") or []:
            key = f"{hero['id']}_{evo['id']}"
            if (PORTRAITS / f"{key}.png").exists():
                out["heroes"][key] = PORTRAITS / f"{key}.png"
    enemy_files = gd_dict(src, "ENEMY_PORTRAIT_BY_NAME")
    defs = json.loads((ROOT / "data" / "raw" / "enemies.data.json").read_text(encoding="utf-8"))["enemyUnitDefs"]
    modes = json.loads((ROOT / "data" / "raw" / "battle-modes.json").read_text(encoding="utf-8"))["modes"]
    bosses = set()
    for op in modes.values():
        names = {e["name"] for b in op.get("battles", []) for e in b.get("enemies", []) if e["name"] in defs}
        if names:
            bosses.add(max(names, key=lambda n: defs[n]["hp"]))
    for name in defs:
        file_name = enemy_files.get(name, f"{slugify(name)}.png")
        path = PORTRAITS / "enemies" / file_name
        if path.exists():
            out["bosses" if name in bosses else "enemies"][path.stem] = path
    for section, table in (("items", "ITEM_ICON_BY_ID"), ("relics", "RELIC_ICON_BY_ID")):
        for item_id, path in gd_dict(src, table).items():
            if res_path(path).exists():
                out[section][item_id] = res_path(path)
    return out


def main() -> int:
    errors: list[str] = []
    try:
        data = json.loads(DATA.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        print(f"[FRAMING_DATA] FAIL - cannot parse {DATA.name}: {exc}")
        return 1
    if data.get("_schema") != 2:
        errors.append("_schema must be 2")
    targets = data.get("_targets", {})
    for section in ("heroes", "enemies", "bosses"):
        t = targets.get(section)
        if not isinstance(t, dict):
            errors.append(f"_targets.{section} missing")
            continue
        top, height = t.get("head_top"), t.get("head_height")
        if not all(isinstance(v, (int, float)) for v in (top, height)) or not (0 <= top < 0.5 and 0.1 <= height <= 0.9 and top + height < 1.0):
            errors.append(f"_targets.{section} out of range: {t}")
    live = live_assets()
    sizes: dict[Path, tuple[int, int]] = {}
    counts = {}
    for section in SECTIONS:
        entries = data.get(section)
        if not isinstance(entries, dict):
            errors.append(f"section '{section}' missing")
            continue
        counts[section] = len(entries)
        fields = PORTRAIT_FIELDS if section in ("heroes", "enemies", "bosses") else ART_FIELDS
        for key, entry in entries.items():
            where = f"{section}.{key}"
            if key not in live[section]:
                other = [s for s in SECTIONS if key in live[s]]
                errors.append(f"{where}: no live asset with this key" + (f" (it is in '{other[0]}')" if other else ""))
                continue
            if not isinstance(entry, dict):
                errors.append(f"{where}: entry must be an object")
                continue
            unknown = set(entry) - fields
            if unknown:
                errors.append(f"{where}: unknown field(s) {sorted(unknown)}")
            path = live[section][key]
            if path not in sizes:
                with Image.open(path) as im:
                    sizes[path] = im.size
            w, h = sizes[path]

            def num(name: str, lo: float, hi: float, integer: bool = False) -> None:
                if name not in entry:
                    return
                v = entry[name]
                if isinstance(v, bool) or not isinstance(v, (int, float)) or (integer and int(v) != v):
                    errors.append(f"{where}.{name}: {v!r} is not a {'whole ' if integer else ''}number")
                elif not lo <= v <= hi:
                    errors.append(f"{where}.{name}: {v} outside [{lo}, {hi}]")

            for flag in ("use_anchors", "reviewed"):
                if flag in entry and not isinstance(entry[flag], bool):
                    errors.append(f"{where}.{flag}: must be true/false")
            if "stray" in entry and entry["stray"] != "rejected":
                errors.append(f"{where}.stray: only 'rejected' is meaningful")
            insets = entry.get("insets", {})
            if not isinstance(insets, dict) or set(insets) - INSET_EDGES:
                errors.append(f"{where}.insets: must be an object of {sorted(INSET_EDGES)}")
                insets = {}
            for edge, v in insets.items():
                if isinstance(v, bool) or not isinstance(v, int) or v < 0:
                    errors.append(f"{where}.insets.{edge}: {v!r} must be a whole number >= 0")
            if (w - insets.get("left", 0) - insets.get("right", 0) < max(8, w * MIN_ART_SHARE)
                    or h - insets.get("top", 0) - insets.get("bottom", 0) < max(8, h * MIN_ART_SHARE)):
                errors.append(f"{where}.insets: leave less than {MIN_ART_SHARE:.0%} of a {w}x{h} image")
            if section in ("heroes", "enemies", "bosses"):
                num("head_top", 0, h - 1, True)
                num("chin", 1, h, True)
                num("center_x", 0, w, True)
                num("legacy_zoom", 0.5, 2.0)
                num("legacy_anchor_y", -0.5, 0.5)
                num("legacy_down_px", -40, 40)
                if ("head_top" in entry) != ("chin" in entry):
                    errors.append(f"{where}: head_top and chin come as a pair")
                elif "head_top" in entry and not entry["chin"] - entry["head_top"] >= 16:
                    errors.append(f"{where}: chin must sit at least 16 px below head_top")
                if entry.get("use_anchors") and "head_top" not in entry:
                    errors.append(f"{where}: use_anchors needs head_top and chin")
            else:
                num("center_x", 0, w, True)
                num("center_y", 0, h, True)
                num("scale", 0.25, 4.0)
    if errors:
        print(f"[FRAMING_DATA] FAIL - {len(errors)} problem(s):")
        for e in errors:
            print(f"   {e}")
        return 1
    print("[FRAMING_DATA] PASS - " + ", ".join(f"{s} {counts.get(s, 0)}/{len(live[s])}" for s in SECTIONS)
          + " entries/assets")
    return 0


if __name__ == "__main__":
    sys.exit(main())
