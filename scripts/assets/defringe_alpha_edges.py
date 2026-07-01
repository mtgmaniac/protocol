"""Defringe cutout art: remove baked white halo pixels on transparent edges.

Root cause this fixes: portraits/icons that were cut out of a white background
keep semi-transparent edge pixels whose RGB is near-white. Godot renders those
pixels faithfully (alpha > 0), so they show up as stray white specks around the
sprite — `process/fix_alpha_border` can't help because it only rewrites RGB
under *fully* transparent pixels.

The fix recolors each semi-transparent near-white pixel to the alpha-weighted
average color of nearby opaque pixels (keeping its alpha), which is what the
edge would have looked like if the art had been authored on transparency.

Pipeline tool, not a one-off: run it again whenever new cutout art lands.

    python scripts/assets/defringe_alpha_edges.py            # fix in place
    python scripts/assets/defringe_alpha_edges.py --dry-run  # report only
"""
import glob
import os
import sys

from PIL import Image

TARGET_GLOBS = [
    "assets/portraits/*.png",
    "assets/portraits/enemies/*.png",
    "assets/icons/items/*.png",
]
WHITE_MIN = 200        # channel floor for "suspiciously white"
OPAQUE_MIN = 220       # alpha floor for donor pixels
SEARCH_RADIUS = 3      # how far to look for donor color


def defringe(path: str, dry_run: bool) -> int:
    im = Image.open(path).convert("RGBA")
    px = im.load()
    w, h = im.size
    fixed = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0 or a == 255:
                continue
            if r < WHITE_MIN or g < WHITE_MIN or b < WHITE_MIN:
                continue
            # Alpha-weighted average of opaque neighbours = the sprite color
            # this edge pixel should be blending from.
            sr = sg = sb = sw = 0
            for dy in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1):
                for dx in range(-SEARCH_RADIUS, SEARCH_RADIUS + 1):
                    nx, ny = x + dx, y + dy
                    if nx < 0 or ny < 0 or nx >= w or ny >= h:
                        continue
                    nr, ng, nb, na = px[nx, ny]
                    if na < OPAQUE_MIN:
                        continue
                    if nr >= WHITE_MIN and ng >= WHITE_MIN and nb >= WHITE_MIN:
                        continue  # don't copy from other halo pixels
                    sr += nr * na
                    sg += ng * na
                    sb += nb * na
                    sw += na
            if sw == 0:
                continue  # isolated speck far from the sprite: leave it
            px[x, y] = (sr // sw, sg // sw, sb // sw, a)
            fixed += 1
    if fixed and not dry_run:
        im.save(path)
    return fixed


def main() -> None:
    dry_run = "--dry-run" in sys.argv
    root = os.path.join(os.path.dirname(__file__), "..", "..")
    os.chdir(os.path.abspath(root))
    total_files = 0
    for pattern in TARGET_GLOBS:
        for path in sorted(glob.glob(pattern)):
            fixed = defringe(path, dry_run)
            if fixed:
                total_files += 1
                print(f"{'would fix' if dry_run else 'fixed':9} {path}: {fixed} px")
    print(f"{total_files} file(s) with white fringe")


if __name__ == "__main__":
    main()
