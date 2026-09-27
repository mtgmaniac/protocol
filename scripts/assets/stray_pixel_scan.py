#!/usr/bin/env python3
"""Stray-pixel scan — DETECTION ONLY. Never sets framing anchors, never edits art.

AI cut-sheet art sometimes carries a fragment of the NEIGHBOURING sprite at
its edge (e.g. the Nanite Field relic: a thin vertical sliver left of the
art). For every live asset image (heroes, enemies, bosses, items, relics —
the same asset list the framing-data gate uses) this finds detached pixel
fragments that either touch an image edge or sit wholly in the margin between
an edge and the main art, and suggests per-edge crop insets that would trim
them. The framing editor shows the flags; Kev accepts (the suggestion is
copied into the asset's `insets`) or rejects (`"stray": "rejected"`).

  ink          alpha > 24 for cutout art; any channel > 10/255 (just above
               the flat black mat, so dark outlines still count as art) for
               opaque matted busts; opaque scenic (full-bleed) art is skipped -
               it has no margin to hold a fragment. A matted bust's bottom
               margin is not scanned: the torso fades into the mat by design.
  main art     8-connected ink components of at least 10% of the largest
               one, then GROWN: any component within GAP px of the main art
               joins it, repeated until stable - so dither, glow and a
               fading torso chained to the silhouette count as the art, while
               a fragment across a real gap does not
  fragment     any other group of >= MIN_FRAGMENT_PX ink pixels lying wholly
               in the MARGIN - outside the main art's bounding box on one
               side (between it and an image edge), whether or not it
               reaches the edge (Nanite Field's sliver stops 42 px short)
  suggestion   the smallest single-edge inset that removes each fragment;
               margin fragments never need an inset that trims the art

Coordinates are source pixels as on disk (before the enemy mirror).

Usage:  python scripts/assets/stray_pixel_scan.py        # writes dev/framing_editor/stray_scan.json
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "checks"))
from framing_data import SECTIONS, live_assets  # noqa: E402  (one asset list, shared)

OUT = ROOT / "dev" / "framing_editor" / "stray_scan.json"
INK_ALPHA = 24
INK_CHANNEL = 10  # just above the flat near-black mat (DataManager _MAT_MAX_CHANNEL = 6)
MAIN_SHARE = 0.10
GAP = 3
MIN_FRAGMENT_PX = 6
FULL_BLEED_SHARE = 0.90


def ink_mask(img: Image.Image) -> tuple[np.ndarray | None, str]:
    rgba = np.asarray(img.convert("RGBA"))
    alpha = rgba[:, :, 3]
    if (alpha < 250).mean() > 0.02:
        return alpha > INK_ALPHA, "cutout"
    bright = rgba[:, :, :3].max(axis=2) > INK_CHANNEL
    if bright.mean() > FULL_BLEED_SHARE:
        return None, "full-bleed (skipped)"
    return bright, "matted"


def scan(path: Path) -> dict:
    with Image.open(path) as img:
        mask, style = ink_mask(img)
        w, h = img.size
    result = {"size": [w, h], "style": style, "fragments": [], "insets": {}}
    if mask is None or not mask.any():
        return result
    labels, count = ndimage.label(mask, structure=np.ones((3, 3), dtype=int))
    sizes = ndimage.sum(mask, labels, index=range(1, count + 1)).astype(int)
    boxes = ndimage.find_objects(labels)
    biggest = sizes.max()
    in_main = np.zeros(count + 1, dtype=bool)
    in_main[1:] = sizes >= biggest * MAIN_SHARE
    while True:
        halo = ndimage.binary_dilation(in_main[labels], structure=np.ones((3, 3), dtype=bool), iterations=GAP)
        grown = in_main.copy()
        grown[np.unique(labels[halo])] = True
        grown[0] = False
        if (grown == in_main).all():
            break
        in_main = grown
    main = [i for i in range(count) if in_main[i + 1]]
    m_left = min(boxes[i][1].start for i in main)
    m_right = max(boxes[i][1].stop for i in main)  # exclusive
    m_top = min(boxes[i][0].start for i in main)
    m_bottom = max(boxes[i][0].stop for i in main)
    insets = {"left": 0, "top": 0, "right": 0, "bottom": 0}
    for i in range(count):
        if i in main or sizes[i] < MIN_FRAGMENT_PX or boxes[i] is None:
            continue
        ys, xs = boxes[i]
        left, right, top, bottom = xs.start, xs.stop, ys.start, ys.stop
        # Margin sides this fragment sits wholly in, and the inset each needs.
        options = {}
        if right <= m_left:
            options["left"] = right
        if left >= m_right:
            options["right"] = w - left
        if bottom <= m_top:
            options["top"] = bottom
        if top >= m_bottom and style != "matted":
            options["bottom"] = h - top
        if not options:
            continue
        edge = min(options, key=options.get)
        insets[edge] = max(insets[edge], options[edge])
        result["fragments"].append({"bbox": [int(left), int(top), int(right - left), int(bottom - top)],
                                    "pixels": int(sizes[i]), "edge": edge,
                                    "touches_edge": bool(left == 0 or top == 0 or right == w or bottom == h)})
    result["insets"] = {k: int(v) for k, v in insets.items() if v}
    return result


def main() -> int:
    live = live_assets()
    report: dict = {"_doc": "Generated by scripts/assets/stray_pixel_scan.py - detection only; "
                            "suggestions are applied only when Kev accepts them in the framing editor.",
                    "_params": {"ink_alpha": INK_ALPHA, "ink_channel": INK_CHANNEL, "main_share": MAIN_SHARE,
                                                "gap": GAP, "min_fragment_px": MIN_FRAGMENT_PX}}
    flagged = 0
    for section in SECTIONS:
        report[section] = {}
        for key, path in sorted(live[section].items()):
            r = scan(path)
            if r["fragments"]:
                flagged += 1
                report[section][key] = r
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(report, indent=1) + "\n", encoding="utf-8")
    total = sum(len(v) for v in live.values())
    print(f"[STRAY_SCAN] {flagged} of {total} assets flagged -> {OUT.relative_to(ROOT).as_posix()}")
    for section in SECTIONS:
        for key, r in report[section].items():
            frag = r["fragments"]
            print(f"   {section:7s} {key:24s} {len(frag):3d} fragment(s)  suggest {r['insets']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
