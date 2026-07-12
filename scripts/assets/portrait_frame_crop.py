#!/usr/bin/env python3
"""Anchor-based portrait framing (fix/portrait-framing).

Consumes assets/portraits/portrait_anchors.json — HAND-DECLARED head_top/chin
per portrait. NO pixel measurement or head detection happens here, ever; the
2026-07-12 framing failure came from exactly that. The transform is pure
arithmetic from the anchors:

    head_height = chin - head_top
    scale       = _target_head_height / head_height        (bicubic, whole image)
    crop        = fixed _crop_height tall, width = _crop_height * card aspect,
                  horizontally centered, top edge at scaled head_top - _head_top_margin

Head height is normalized FIRST, so the one constant crop height lands the
bottom edge at the same anatomical point on every unit. Out-of-bounds crop
areas are PADDED with the portrait's own background color — never shifted.

The card portrait-region aspect is READ from scripts/ui/home_screen.gd
(BATTLE_PORTRAIT_REGION, the canonical battle-card portrait region), not guessed.

Usage:
    python scripts/assets/portrait_frame_crop.py                    # preview grid only
    python scripts/assets/portrait_frame_crop.py apply              # overwrite the PNGs
    python scripts/assets/portrait_frame_crop.py compare 448,560    # multi-height preview
"""
from PIL import Image, ImageDraw
import json
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
PORTRAIT_DIR = os.path.join(ROOT, "assets", "portraits")
ANCHORS_PATH = os.path.join(PORTRAIT_DIR, "portrait_anchors.json")
OUT_DIR = os.path.join(ROOT, "debug_artifacts", "portrait_framing")
ORIGINAL_SIZE = (592, 880)
# In-game cutout portraits draw PORTRAIT_TOP_PAD px below the region top
# (PixelUI.cover_fit_portrait) — the preview mirrors it so approval == shipped look.
RUNTIME_TOP_PAD = 12


def card_region():
    """Read the ONE portrait region (design px) from PixelUI — the single source
    of truth (HERO_PORTRAIT_REGION, measured live from the battle card)."""
    src = open(os.path.join(ROOT, "scripts", "ui", "pixel_ui.gd"), encoding="utf-8").read()
    m = re.search(r"HERO_PORTRAIT_REGION\s*:?=\s*Vector2\(\s*([\d.]+)\s*,\s*([\d.]+)\s*\)", src)
    if not m:
        raise SystemExit("HERO_PORTRAIT_REGION not found in pixel_ui.gd")
    return float(m.group(1)), float(m.group(2))


def live_files():
    data = json.load(open(os.path.join(ROOT, "data", "raw", "heroes.data.json"), encoding="utf-8"))
    heroes = data["heroes"] if isinstance(data, dict) and "heroes" in data else data
    out = []
    for h in heroes:
        hid = h.get("id")
        out.append(hid)
        for e in (h.get("evolutions") or []):
            out.append("%s_%s" % (hid, e.get("id")))
    return sorted(out)


def bg_color(im):
    """The portrait's own background: median of the four corners."""
    px = im.load()
    samples = []
    w, h = im.size
    for cx, cy in [(0, 0), (w - 12, 0), (0, h - 12), (w - 12, h - 12)]:
        for dx in range(0, 12, 3):
            for dy in range(0, 12, 3):
                samples.append(px[cx + dx, cy + dy])
    samples.sort()
    return samples[len(samples) // 2]


def frame_one(name, anchors, crop_w, crop_h, target_head, margin):
    path = os.path.join(PORTRAIT_DIR, name + ".png")
    im = Image.open(path).convert("RGB")
    if im.size != ORIGINAL_SIZE:
        raise SystemExit("%s is %s, not the original %s — refusing to crop non-pristine art"
                         % (name, im.size, ORIGINAL_SIZE))
    a = anchors[name]
    head_height = a["chin"] - a["head_top"]
    scale = target_head / float(head_height)
    sw, sh = round(im.width * scale), round(im.height * scale)
    scaled = im.resize((sw, sh), Image.BICUBIC)
    left = round((sw - crop_w) / 2.0)
    top = round(a["head_top"] * scale) - margin
    pad_l = max(0, -left)
    pad_t = max(0, -top)
    pad_r = max(0, (left + crop_w) - sw)
    pad_b = max(0, (top + crop_h) - sh)
    canvas = Image.new("RGB", (crop_w, crop_h), bg_color(im))
    src = scaled.crop((max(0, left), max(0, top),
                       min(sw, left + crop_w), min(sh, top + crop_h)))
    canvas.paste(src, (pad_l, pad_t))
    pads = {"L": pad_l, "T": pad_t, "R": pad_r, "B": pad_b}
    return canvas, scale, {k: v for k, v in pads.items() if v > 0}


def simulate_card(crop, region_w, region_h):
    """Mirror the in-game render: cover-fit into the region, cutout top pad."""
    fw, fh = int(region_w), int(region_h)
    sc = max(fw / crop.width, fh / crop.height)
    r = crop.resize((round(crop.width * sc), round(crop.height * sc)), Image.BICUBIC)
    tile = Image.new("RGB", (fw, fh), (10, 20, 28))
    tile.paste(r, ((fw - r.width) // 2, RUNTIME_TOP_PAD))
    return tile


def load_config():
    raw = json.load(open(ANCHORS_PATH, encoding="utf-8"))
    meta = {k: raw[k] for k in raw if k.startswith("_")}
    anchors = {k: v for k, v in raw.items() if not k.startswith("_")}
    live = live_files()
    missing = [n for n in live if n not in anchors]
    extra = [n for n in anchors if n not in live]
    if missing or extra:
        raise SystemExit("anchor/live mismatch — missing anchors: %s · anchors without live file: %s"
                         % (missing, extra))
    return meta, anchors, live


def build_grid(live, anchors, crop_h, target_head, margin, region_w, region_h,
               apply_mode=False, quiet=False):
    crop_w = round(crop_h * (region_w / region_h))
    tiles = []
    pad_report = []
    for name in live:
        crop, scale, pads = frame_one(name, anchors, crop_w, crop_h, target_head, margin)
        if apply_mode:
            crop.save(os.path.join(PORTRAIT_DIR, name + ".png"))
        if pads:
            pad_report.append((name, pads, crop_w, crop_h))
        if not quiet:
            note = " PADDED[%s]" % ",".join("%s%d" % (k, v) for k, v in pads.items()) if pads else ""
            print("  %-22s scale=%.3f%s%s" % (name, scale, " (upscaled)" if scale > 1.0 else "", note))
        tile = simulate_card(crop, region_w, region_h).resize(
            (int(region_w) // 2, int(region_h) // 2), Image.BICUBIC)
        labeled = Image.new("RGB", (tile.width, tile.height + 16), (18, 18, 22))
        labeled.paste(tile, (0, 16))
        ImageDraw.Draw(labeled).text((3, 2), name, fill=(255, 255, 140))
        tiles.append(labeled)
    cols = 8
    rows = (len(tiles) + cols - 1) // cols
    pad = 6
    tw, th = tiles[0].width, tiles[0].height
    grid = Image.new("RGB", (cols * (tw + pad) + pad, rows * (th + pad) + pad), (24, 24, 28))
    for i, t in enumerate(tiles):
        grid.paste(t, (pad + (i % cols) * (tw + pad), pad + (i // cols) * (th + pad)))
    return grid, pad_report


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "preview"
    meta, anchors, live = load_config()
    target_head = int(meta["_target_head_height"])
    margin = int(meta["_head_top_margin"])
    region_w, region_h = card_region()
    os.makedirs(OUT_DIR, exist_ok=True)

    if mode == "compare":
        heights = [int(h) for h in sys.argv[2].split(",")] if len(sys.argv) > 2 else [448, 560, 700, 880]
        sections = []
        for ch in heights:
            grid, pad_report = build_grid(live, anchors, ch, target_head, margin,
                                          region_w, region_h, quiet=True)
            head_pct = 100.0 * target_head * (region_h / ch) / region_h
            visible_gap = RUNTIME_TOP_PAD + margin * (region_h / ch)
            label = ("_crop_height %d   |   head = %.0f%% of card height   |   visible head gap %.1f px   |   %d/%d portraits padded"
                     % (ch, head_pct, visible_gap, len(pad_report), len(live)))
            print("== " + label)
            for name, pads, cw2, ch2 in pad_report:
                detail = ", ".join("%s %dpx (%.0f%%)" % (
                    {"L": "left", "T": "top", "R": "right", "B": "bottom"}[k], v,
                    100.0 * v / (ch2 if k in "TB" else cw2)) for k, v in pads.items())
                print("     %-22s %s" % (name, detail))
            header = Image.new("RGB", (grid.width, 26), (40, 40, 20))
            ImageDraw.Draw(header).text((8, 6), label, fill=(255, 235, 130))
            sections.append(header)
            sections.append(grid)
        total_h = sum(s.height for s in sections)
        sheet = Image.new("RGB", (sections[0].width, total_h), (24, 24, 28))
        y = 0
        for s in sections:
            sheet.paste(s, (0, y)); y += s.height
        out = os.path.join(OUT_DIR, "crop_height_compare.png")
        sheet.save(out)
        print("compare sheet (no asset writes): " + out)
        return

    apply_mode = mode == "apply"
    crop_h = int(meta["_crop_height"])
    crop_w = round(crop_h * (region_w / region_h))
    print("card region %dx%d (aspect %.4f) -> crop %dx%d, target head %d, margin %d"
          % (region_w, region_h, region_w / region_h, crop_w, crop_h, target_head, margin))
    grid, _ = build_grid(live, anchors, crop_h, target_head, margin,
                         region_w, region_h, apply_mode=apply_mode)
    out = os.path.join(OUT_DIR, "preview_grid.png")
    grid.save(out)
    print(("APPLIED %d portraits + " % len(live) if apply_mode else "preview only — no asset files written; ")
          + "grid: " + out)


if __name__ == "__main__":
    main()
