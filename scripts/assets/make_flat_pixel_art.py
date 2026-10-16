"""Flat pixel prototype A: PLACEHOLDER tray art generator.

Writes into assets/battle_tray/:
  flat_backdrop_tile.png      the dark, low-contrast wall texture behind the cards
  flat_floor_plates.png       Facility floor: top-down deck plates
  flat_floor_hive.png         Hive floor: organic resin cells

Every texture is a light gray MASK. The battle painter multiplies it by a PixelUI
tint token named in data/raw/battle-tray-scenes.json, so the operation's color
lives in data and PixelUI, never here. One texel is one art pixel (4 design px).
Hard edges, a few flat tones, no gradients. Run from the repo root:
    python scripts/assets/make_flat_pixel_art.py
then let Godot reimport (open the editor, or any headless run).
"""
from pathlib import Path

from PIL import Image

OUT = Path("assets/battle_tray")


def gray(v, a=255):
    return (v, v, v, a)


def backdrop():
    # Staggered slabs, two tones apart: reads as a wall without pulling the eye.
    body, seam, lit, fleck = gray(214), gray(176), gray(232), gray(196)
    w, h = 16, 24
    im = Image.new("RGBA", (w, h), body)
    for x in range(w):
        im.putpixel((x, 0), seam)
        im.putpixel((x, 12), seam)
        im.putpixel((x, 1), lit)
        im.putpixel((x, 13), lit)
    for y in range(1, 12):
        im.putpixel((0, y), seam)
    for y in range(13, 24):
        im.putpixel((8, y), seam)
    for x, y in ((5, 6), (11, 4), (3, 18), (13, 20), (12, 17)):
        im.putpixel((x, y), fleck)
    im.save(OUT / "flat_backdrop_tile.png")


def floor_plates():
    # Square deck plates: a dark seam, a lit top-left lip, corner bolts, scuffs.
    body, seam, lit, scuff, bolt = gray(224), gray(150), gray(250), gray(206), gray(255)
    w, h = 16, 16
    im = Image.new("RGBA", (w, h), body)
    for x in range(w):
        im.putpixel((x, 0), seam)
        im.putpixel((x, 1), lit)
    for y in range(h):
        im.putpixel((0, y), seam)
        im.putpixel((1, y), lit)
    for x, y in ((3, 3), (13, 3), (3, 13), (13, 13)):
        im.putpixel((x, y), bolt)
    for x, y in ((6, 8), (7, 8), (8, 9), (10, 11), (11, 11)):
        im.putpixel((x, y), scuff)
    im.save(OUT / "flat_floor_plates.png")


def floor_hive():
    # Resin cells: rounded blobs with dark membranes, a glint in some cells.
    body, membrane, glint, pit = gray(222), gray(140), gray(255), gray(190)
    w, h = 16, 16
    im = Image.new("RGBA", (w, h), body)
    # Membrane lines (a staggered, hand-placed honeycomb-ish net; tiles seamlessly).
    net = [
        (0, 0), (1, 0), (2, 0), (3, 0), (4, 1), (5, 2), (5, 3), (5, 4), (4, 5), (3, 6),
        (2, 6), (1, 6), (0, 6), (15, 6), (14, 5), (13, 4), (13, 3), (13, 2), (14, 1), (15, 0),
        (6, 2), (7, 2), (8, 2), (9, 2), (10, 2), (11, 2), (12, 2),
        (5, 5), (6, 6), (7, 7), (7, 8), (7, 9), (6, 10), (5, 11), (4, 12), (4, 13), (4, 14),
        (3, 15), (8, 10), (9, 11), (10, 12), (11, 12), (12, 12), (13, 13), (13, 14), (14, 15),
        (12, 11), (13, 10), (14, 9), (14, 8), (14, 7),
    ]
    for x, y in net:
        im.putpixel((x % w, y % h), membrane)
    for x, y in ((9, 5), (2, 3), (10, 14), (1, 10)):
        im.putpixel((x, y), glint)
    for x, y in ((10, 6), (3, 3), (11, 15), (2, 11), (10, 8)):
        im.putpixel((x, y), pit)
    im.save(OUT / "flat_floor_hive.png")


if __name__ == "__main__":
    backdrop()
    floor_plates()
    floor_hive()
    print("wrote", OUT / "flat_backdrop_tile.png", OUT / "flat_floor_plates.png", OUT / "flat_floor_hive.png")
