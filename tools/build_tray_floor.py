"""Build the dice tray floor image from its raw source.

Kev, 2026-10-17 (UI batch A5, DECISIONS_RESOLVED G-79): the dice tray floor is
one image, a flat dark charcoal surface with a faint diagonal texture and one
thin gray targeting reticle at its centre. It replaces the procedural
"grate + ember" floor of G-76. The raw AI-generated source sits in
assets/art_incoming/ (never imported, never shipped); this script writes the
final-size art through tools/pixelize.py (area downscale, median-cut quantize,
no dithering).

The output is the tray's exact art size: the live tray is 1040 x 892 design px
at 1080 x 2400 (battle_ui_capture.gd --capture-layout-report, "tray"), so
260 x 223 art px at 1 art px = 4 design px. The source is wider than the tray:
pixelize centre-crops it to the tray's aspect, which keeps the reticle (centred
in the source) centred. battle_bay_floor.gd draws it one texel per art pixel,
centred on the tray.

    python tools/build_tray_floor.py            # writes the image, prints the checks
    python tools/build_tray_floor.py --check    # measures the shipped file only

Luminance is Rec. 601 luma, 0-255. The dice must be the highest-contrast
objects in the tray, so the checks print the floor's range and the reticle's
peak.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelize  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/art_incoming/tray_reticle_raw.png"
OUT = ROOT / "assets/battle_tray/tray_floor_reticle.png"
TRAY_DESIGN = (1040, 892)
ART_PX = 4
SIZE = (TRAY_DESIGN[0] // ART_PX, TRAY_DESIGN[1] // ART_PX)   # (260, 223)
COLORS = 32
## The source's reticle is centred at (723.5, 538.5) of 1448 x 1086, 4.5 px above
## the middle; dropping its bottom 9 rows centres it vertically before pixelize
## centre-crops the width.
SOURCE_CROP = (0, 0, 1448, 1077)
## Luma above the floor's median that marks a reticle pixel.
RETICLE_THRESHOLD = 12.0
LUMA = np.array([0.299, 0.587, 0.114])


## Art px from the image centre that the reticle reaches (its tick ends sit at
## about 47). A reticle-bright pixel further out is a speck of the source's
## texture that the quantize merged into the reticle tone: it becomes the floor.
RETICLE_REACH = 52


def build() -> Image.Image:
    out = np.asarray(pixelize.pixelize(Image.open(SOURCE).crop(SOURCE_CROP), SIZE, COLORS)).copy()
    L = out.astype(float) @ LUMA
    yy, xx = np.mgrid[0:SIZE[1], 0:SIZE[0]]
    far = np.hypot(xx - (SIZE[0] - 1) / 2, yy - (SIZE[1] - 1) / 2) > RETICLE_REACH
    specks = far & (L > np.median(L) + RETICLE_THRESHOLD)
    if specks.any():
        colours, counts = np.unique(out.reshape(-1, 3), axis=0, return_counts=True)
        out[specks] = colours[counts.argmax()]
        print(f"  {int(specks.sum())} stray reticle-tone px outside the reticle set to the floor colour")
    return Image.fromarray(out)


def measure(path: Path) -> None:
    a = np.asarray(Image.open(path).convert("RGB")).astype(float)
    L = a @ LUMA
    median = float(np.median(L))
    reticle = L > median + RETICLE_THRESHOLD
    floor = L[~reticle]
    ys, xs = np.nonzero(reticle)
    print(f"{path.relative_to(ROOT)}: {a.shape[1]}x{a.shape[0]} art px")
    print(f"  floor luma {floor.min():.1f} - {floor.max():.1f} (median {median:.1f})")
    if reticle.any():
        print(f"  reticle peak luma {L[reticle].max():.1f}, {int(reticle.sum())} px, "
            f"centre ({(xs.min() + xs.max()) / 2:.1f}, {(ys.min() + ys.max()) / 2:.1f}) "
            f"of ({(a.shape[1] - 1) / 2:.1f}, {(a.shape[0] - 1) / 2:.1f})")
    print(f"  {len(np.unique(a.reshape(-1, 3), axis=0))} colours")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="measure the shipped file only")
    args = parser.parse_args()
    if not args.check:
        pixelize.save(build(), OUT)
    measure(OUT)


if __name__ == "__main__":
    main()
