"""Stroke-run check for pixel text in a screenshot (ui-fix 2026-10-16).

A pixel font drawn at a whole number k of screen px per font pixel has every
horizontal and vertical ink run a multiple of k. Uneven scaling (1.33 or 1.44
screen px per font pixel) leaves runs of k and k+1 in the same glyph.

  python scripts/checks/stroke_runs.py IMAGE x0,y0,x1,y1 RRGGBB [tolerance]

Prints the run-length histogram and the largest k that divides every run.
"""
import sys
from collections import Counter
from math import gcd

from PIL import Image


def runs(mask, w, h):
    out = Counter()
    for y in range(h):
        n = 0
        for x in range(w + 1):
            if x < w and mask[y][x]:
                n += 1
            elif n:
                out[n] += 1
                n = 0
    for x in range(w):
        n = 0
        for y in range(h + 1):
            if y < h and mask[y][x]:
                n += 1
            elif n:
                out[n] += 1
                n = 0
    return out


def main() -> int:
    path, box, ink = sys.argv[1], sys.argv[2], sys.argv[3]
    tol = int(sys.argv[4]) if len(sys.argv) > 4 else 60
    x0, y0, x1, y1 = (int(v) for v in box.split(","))
    ink_rgb = tuple(int(ink[i:i + 2], 16) for i in (0, 2, 4))
    im = Image.open(path).convert("RGB").crop((x0, y0, x1, y1))
    w, h = im.size
    px = im.load()
    mask = [[sum(abs(px[x, y][c] - ink_rgb[c]) for c in range(3)) <= tol for x in range(w)] for y in range(h)]
    hist = runs(mask, w, h)
    k = 0
    for length in hist:
        k = gcd(k, length)
    print("runs %s  common k=%d" % (dict(sorted(hist.items())), k))
    return 0


if __name__ == "__main__":
    sys.exit(main())
