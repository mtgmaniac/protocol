"""Flat pixel polish B: PLACEHOLDER operation backdrops.

Writes into assets/battle_backdrops/:
  placeholder_facility_backdrop_01.png    an ordinary Facility battle
  placeholder_facility_backdrop_boss.png  the Facility boss battle (battle 10)

Both are 270 x 600 art px (one texel = 4 design px = the battle scene's art
grid), dark and low-contrast so the cards and the tray read first; see
docs/BACKDROP_SPEC.md for the real art's rules. Drawn with hard-edged flat
tones, no gradients. Run from the repo root, then let Godot reimport:
    python scripts/assets/make_placeholder_backdrops.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path("assets/battle_backdrops")
W, H = 270, 600

BASE = (14, 15, 17)
SEAM = (10, 11, 12)
PANEL_LIT = (20, 21, 23)
GIRDER = (25, 24, 22)
GIRDER_LIT = (31, 30, 27)
RIVET = (36, 34, 30)
PIPE = (19, 21, 23)
PIPE_LIT = (27, 29, 31)
LAMP = (44, 33, 18)
LAMP_DIM = (28, 22, 14)
MACHINE = (11, 12, 13)
MACHINE_EDGE = (22, 22, 23)
EMBER = (46, 20, 15)
EMBER_DIM = (30, 15, 12)


def wall(draw):
    draw.rectangle([0, 0, W - 1, H - 1], fill=BASE)
    for x in range(0, W, 18):
        draw.line([x, 0, x, H - 1], fill=SEAM)
        draw.line([x + 1, 0, x + 1, H - 1], fill=PANEL_LIT)
    for y in range(0, H, 46):
        draw.line([0, y, W - 1, y], fill=SEAM)


def girder(draw, y):
    draw.rectangle([0, y, W - 1, y + 5], fill=GIRDER)
    draw.line([0, y, W - 1, y], fill=GIRDER_LIT)
    for x in range(4, W, 12):
        draw.point([x, y + 3], fill=RIVET)


def braces(draw, y0, y1):
    for x in range(0, W, 54):
        draw.line([x, y0 + 6, x + 27, y1 - 1], fill=GIRDER, width=2)
        draw.line([x + 54, y0 + 6, x + 27, y1 - 1], fill=GIRDER, width=2)


def pipes(draw):
    for x in (6, 14, 252, 260):
        draw.rectangle([x, 0, x + 4, H - 1], fill=PIPE)
        draw.line([x + 1, 0, x + 1, H - 1], fill=PIPE_LIT)
        for y in range(30, H, 90):
            draw.rectangle([x - 1, y, x + 5, y + 3], fill=GIRDER)


def machine(draw, x, y, w, h):
    draw.rectangle([x, y, x + w, y + h], fill=MACHINE)
    draw.rectangle([x, y, x + w, y + h], outline=MACHINE_EDGE)
    for i in range(x + 4, x + w - 4, 8):
        draw.line([i, y + 4, i, y + h - 4], fill=SEAM)


def lamps(draw, spots):
    for x, y in spots:
        draw.rectangle([x - 1, y - 1, x + 3, y + 4], fill=LAMP_DIM)
        draw.rectangle([x, y, x + 2, y + 3], fill=LAMP)


def ordinary():
    im = Image.new("RGB", (W, H), BASE)
    draw = ImageDraw.Draw(im)
    wall(draw)
    braces(draw, 44, 150)
    for y in (44, 150, 330, 520):
        girder(draw, y)
    machine(draw, 112, 70, 46, 70)
    machine(draw, 30, 360, 60, 120)
    machine(draw, 180, 380, 56, 100)
    pipes(draw)
    lamps(draw, [(24, 60), (244, 60), (134, 160), (24, 300), (244, 300), (134, 540)])
    im.save(OUT / "placeholder_facility_backdrop_01.png")


def boss():
    im = Image.new("RGB", (W, H), BASE)
    draw = ImageDraw.Draw(im)
    wall(draw)
    braces(draw, 44, 150)
    for y in (44, 150, 330, 520):
        girder(draw, y)
    # The foundry furnace: a big ring behind the boss row, embers in its mouth.
    cx, cy = 135, 104
    for r, colour in ((58, MACHINE_EDGE), (54, MACHINE), (40, MACHINE_EDGE), (36, (8, 8, 9))):
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=colour)
    for i, (x, y) in enumerate([(120, 120), (128, 126), (138, 122), (148, 128), (132, 112), (144, 116)]):
        draw.rectangle([x, y, x + 2, y + 2], fill=EMBER if i % 2 == 0 else EMBER_DIM)
    machine(draw, 30, 360, 60, 120)
    machine(draw, 180, 380, 56, 100)
    pipes(draw)
    lamps(draw, [(24, 60), (244, 60), (24, 300), (244, 300)])
    im.save(OUT / "placeholder_facility_backdrop_boss.png")


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    ordinary()
    boss()
    print("wrote", OUT / "placeholder_facility_backdrop_01.png", OUT / "placeholder_facility_backdrop_boss.png")
