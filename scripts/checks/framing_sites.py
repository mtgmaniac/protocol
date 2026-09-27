#!/usr/bin/env python3
"""Framing sites gate — every portrait / item / relic display goes through its helper.

ONE framing entry per asset (assets/portraits/portrait_anchors.json) only
works if no screen frames art on its own. Static rules over the game scripts
(scripts/**, minus scripts/debug + scripts/sim; PixelUI and DataManager are the
helpers / loader themselves):

  R1 portraits  — a TextureRect given a portrait texture (either side of the
                  `.texture =` mentions "portrait") lives in a file that calls
                  PixelUI.cover_fit_portrait, and its function never picks a
                  TextureRect STRETCH_KEEP_ASPECT* mode (private framing).
  R2 item art   — item / relic art (`<x>.icon`, a payload "icon") is never
                  assigned to a TextureRect directly; it goes through
                  PixelUI.make_item_art / make_integer_icon.
  R3 no local   — no screen reads the framing tags (hero_portrait,
     framing      portrait_key, framing_*), and no function nudges a portrait
                  after the helper (`cover_fit_portrait(...)` followed by
                  `position(.x|.y) +=`) — per-screen offsets are what the
                  shared data replaces.
  R4 no bypass  — no script outside DataManager names a portrait or item-art
     loads        path (res://assets/portraits, res://assets/icons/items), so
                  nothing loads art without the framing tag.
  R5 dev only   — every export preset excludes the dev/ tree (the framing
                  editor), web AND Android.

Known exception (documented in docs/tools/FRAMING_TOOL.md): the PARKED
landscape battle plate (compact_unit_card._battle_plate, LANDSCAPE_BATTLE_
ENABLED = false) shows the native-aspect artwork without the portrait window.

Exit 0 = pass, 1 = violation.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SKIP_DIRS = ("scripts/debug/", "scripts/sim/")
HELPERS = {"scripts/ui/pixel_ui.gd", "scripts/autoloads/DataManager.gd"}
ASSIGN = re.compile(r"^\s*([\w\.\[\]\"]+)\.texture\s*=\s*(.+)$")
ITEM_RHS = re.compile(r"\.icon\b|get\(\"icon\"|\[\"icon\"\]")
TAG_READ = re.compile(r"(get_meta|has_meta|set_meta)\(\"(hero_portrait|portrait_key|framing_\w*)\"")
ART_PATH = re.compile(r"res://assets/(portraits|icons/items)")


def game_scripts() -> list[Path]:
    out = []
    for path in sorted((ROOT / "scripts").rglob("*.gd")):
        rel = path.relative_to(ROOT).as_posix()
        if not rel.startswith(SKIP_DIRS):
            out.append(path)
    return out


def functions(lines: list[str]) -> list[tuple[int, int]]:
    """(start, end) line ranges of top-level funcs (static or not)."""
    starts = [i for i, l in enumerate(lines) if re.match(r"^(static\s+)?func\s", l)]
    return [(s, starts[k + 1] if k + 1 < len(starts) else len(lines)) for k, s in enumerate(starts)]


def enclosing(ranges: list[tuple[int, int]], i: int) -> tuple[int, int]:
    for s, e in ranges:
        if s <= i < e:
            return s, e
    return i, i + 1


def check_source(rel: str, src: str) -> list[str]:
    errors: list[str] = []
    lines = src.splitlines()
    ranges = functions(lines)
    is_helper = rel in HELPERS
    for i, line in enumerate(lines):
        code = line.split("#", 1)[0]
        m = ASSIGN.match(code)
        if m and not is_helper:
            lhs, rhs = m.group(1), m.group(2)
            s, e = enclosing(ranges, i)
            icon_vars = {mm.group(1) for l in lines[s:i]
                         for mm in [re.match(r"^\s*var\s+(\w+)[^=]*=\s*(.+)$", l.split("#", 1)[0])]
                         if mm and ITEM_RHS.search(mm.group(2))}
            if ITEM_RHS.search(rhs) or rhs.strip() in icon_vars:
                errors.append(f"R2 {rel}:{i + 1}: item/relic art assigned directly - use PixelUI.make_item_art")
            if "portrait" in (lhs + rhs).lower():
                s, e = enclosing(ranges, i)
                if "PixelUI.cover_fit_portrait(" not in src:
                    errors.append(f"R1 {rel}:{i + 1}: portrait texture in a file that never calls PixelUI.cover_fit_portrait")
                if any("STRETCH_KEEP_ASPECT" in l.split("#", 1)[0] for l in lines[s:e]):
                    errors.append(f"R1 {rel}:{i + 1}: portrait framed by a TextureRect keep-aspect mode, not the helper")
        if is_helper:
            continue
        if TAG_READ.search(code):
            errors.append(f"R3 {rel}:{i + 1}: screen reads a framing tag - framing belongs to the helper")
        if "cover_fit_portrait(" in code:
            s, e = enclosing(ranges, i)
            for j in range(i + 1, e):
                if re.search(r"\bposition(\.[xy])?\s*[+-]=", lines[j].split("#", 1)[0]):
                    errors.append(f"R3 {rel}:{j + 1}: portrait nudged after the helper - put the offset in the framing data")
        if ART_PATH.search(code):
            errors.append(f"R4 {rel}:{i + 1}: art path outside DataManager - load through DataManager so it is tagged")
    return errors


def check_exports() -> list[str]:
    cfg = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    errors = []
    for block in re.split(r"(?m)^\[preset\.\d+\]\s*$", cfg)[1:]:
        name = re.search(r'(?m)^name="([^"]*)"', block)
        excl = re.search(r'(?m)^exclude_filter="([^"]*)"', block)
        filters = [f.strip() for f in (excl.group(1) if excl else "").split(",")]
        if "dev/*" not in filters:
            errors.append(f"R5 export preset '{name.group(1) if name else '?'}': exclude_filter lacks dev/* (the framing editor would ship)")
    return errors


def main() -> int:
    errors: list[str] = []
    count = 0
    for path in game_scripts():
        rel = path.relative_to(ROOT).as_posix()
        errors += check_source(rel, path.read_text(encoding="utf-8"))
        count += 1
    errors += check_exports()
    errors = list(dict.fromkeys(errors))
    if errors:
        print(f"[FRAMING_SITES] FAIL - {len(errors)} violation(s):")
        for e in errors:
            print(f"   {e}")
        return 1
    print(f"[FRAMING_SITES] PASS - {count} scripts: every portrait/item/relic site uses its helper; dev/ excluded from every export preset")
    return 0


if __name__ == "__main__":
    sys.exit(main())
