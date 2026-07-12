#!/usr/bin/env python3
"""Portrait measuring sheets (fix/portrait-framing Step 1).

Renders every LIVE hero portrait (base + evolutions, enumerated from
heroes.data.json) at NATIVE resolution with a horizontal gridline every 10 px
so head_top / chin y-coordinates can be read off by eye and declared by hand in
portrait_anchors.json. No detection of any kind happens here or anywhere else.

Grid: minor line every 10 px, brighter line every 50 px, y-coordinate LABELS in
the left margin every 50 px (10 px labels physically can't be readable text —
count minor lines from the nearest labeled 50).

Output: debug_artifacts/portrait_framing/sheet_<n>.png (6 portraits per sheet).
"""
from PIL import Image, ImageDraw
import json
import os

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
PORTRAIT_DIR = os.path.join(ROOT, "assets", "portraits")
OUT_DIR = os.path.join(ROOT, "debug_artifacts", "portrait_framing")

MARGIN_L = 64          # label gutter per portrait
HEADER_H = 34          # filename strip
PER_SHEET = 6
MINOR = (80, 200, 220, 110)    # 10 px lines
MAJOR = (255, 230, 90, 170)    # 50 px lines (labeled)
LABEL = (255, 230, 90)


def live_files():
    data = json.load(open(os.path.join(ROOT, "data", "raw", "heroes.data.json"), encoding="utf-8"))
    heroes = data["heroes"] if isinstance(data, dict) and "heroes" in data else data
    files = []
    for h in heroes:
        hid = h.get("id")
        files.append("%s.png" % hid)
        for e in (h.get("evolutions") or []):
            files.append("%s_%s.png" % (hid, e.get("id")))
    return sorted(files)


def gridded(path):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    cell = Image.new("RGB", (MARGIN_L + w, HEADER_H + h), (16, 16, 20))
    cell.paste(im, (MARGIN_L, HEADER_H))
    d = ImageDraw.Draw(cell, "RGBA")
    d.text((MARGIN_L + 4, 8), os.path.basename(path), fill=(255, 255, 255))
    for y in range(0, h, 10):
        major = (y % 50 == 0)
        d.line([(MARGIN_L, HEADER_H + y), (MARGIN_L + w, HEADER_H + y)],
               fill=MAJOR if major else MINOR, width=1)
        if major:
            d.text((6, HEADER_H + y - 5), str(y), fill=LABEL)
    return cell


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    files = live_files()
    print("live portraits:", len(files))
    sheets = [files[i:i + PER_SHEET] for i in range(0, len(files), PER_SHEET)]
    for si, group in enumerate(sheets, 1):
        cells = [gridded(os.path.join(PORTRAIT_DIR, f)) for f in group]
        wsum = sum(c.width for c in cells) + 8 * (len(cells) + 1)
        hmax = max(c.height for c in cells) + 16
        sheet = Image.new("RGB", (wsum, hmax), (10, 10, 12))
        x = 8
        for c in cells:
            sheet.paste(c, (x, 8))
            x += c.width + 8
        out = os.path.join(OUT_DIR, "sheet_%d.png" % si)
        sheet.save(out)
        print("wrote", out, sheet.size, "->", ", ".join(group))


if __name__ == "__main__":
    main()
