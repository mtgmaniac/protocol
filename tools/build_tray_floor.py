"""Install and check the per-operation dice tray floor images.

Kev, 2026-10-17 (DECISIONS_RESOLVED G-84, replacing G-79's one reticle floor):
each operation has its own tray floor, drawn pixel-exact at the tray's final
art size, 260 x 223 art px (the 1040 x 892 design px tray at 1080 x 2400, at
1 art px = 4 design px). The files are copied AS-IS from assets/art_incoming/
(tray_<op>.png): no conversion, resampling or quantizing. A source of any
other size is refused, never scaled. battle_bay_floor.gd draws each one texel
per art pixel, centred on the tray; the data entries are `tray_floors` in
data/raw/battle-tray-scenes.json.

    python tools/build_tray_floor.py            # copies the sources, prints the checks
    python tools/build_tray_floor.py --check    # measures the shipped files only

Luminance is Rec. 601 luma, 0-255. The dice must be the highest-contrast
objects in the tray, so the checks print each floor's range and the reticle's
peak, and (when the source is present) that the shipped file is byte-identical.
"""
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OPERATIONS = ("facility", "hive", "mantle", "signal", "veil")
SIZE = (260, 223)
## Luma above the floor's median that marks a reticle pixel.
RETICLE_THRESHOLD = 12.0
LUMA = np.array([0.299, 0.587, 0.114])


def source(op: str) -> Path:
    return ROOT / f"assets/art_incoming/tray_{op}.png"


def shipped(op: str) -> Path:
    return ROOT / f"assets/battle_tray/tray_floor_{op}.png"


def measure(op: str) -> bool:
    path = shipped(op)
    im = Image.open(path)
    ok = im.size == SIZE
    a = np.asarray(im.convert("RGB")).astype(float)
    L = a @ LUMA
    median = float(np.median(L))
    reticle = L > median + RETICLE_THRESHOLD
    floor = L[~reticle]
    print(f"{path.relative_to(ROOT)}: {im.size[0]}x{im.size[1]} art px{'' if ok else ' WRONG SIZE'}")
    print(f"  floor luma {floor.min():.1f} - {floor.max():.1f} (median {median:.1f}), "
        f"reticle peak {L[reticle].max() if reticle.any() else 0:.1f}, "
        f"{len(np.unique(a.reshape(-1, 3), axis=0))} colours")
    if source(op).exists():
        same = source(op).read_bytes() == path.read_bytes()
        print(f"  byte-identical to its source: {same}")
        ok = ok and same
    return ok


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="measure the shipped files only")
    args = parser.parse_args()
    if not args.check:
        for op in OPERATIONS:
            size = Image.open(source(op)).size
            if size != SIZE:
                sys.exit(f"{source(op).name} is {size[0]}x{size[1]}, not {SIZE[0]}x{SIZE[1]}: refused (never scaled)")
            shutil.copyfile(source(op), shipped(op))
    results = [measure(op) for op in OPERATIONS]
    sys.exit(0 if all(results) else 1)


if __name__ == "__main__":
    main()
