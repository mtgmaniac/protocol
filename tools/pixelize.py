"""Turn a large raw source image into final-size pixel art.

The sanctioned exception to docs/ART_SPEC.md's "never downscale" rule (Kev,
2026-10-17): a raw AI-generated source may be large, but the file that ships is
written at the exact final art size, so the game still shows it one texel per
art pixel. Steps:

1. Area (box) downscale to the exact target size: every output pixel is the
   mean of the source pixels it covers. No resampling filter, no sharpening.
2. Median-cut quantize to about 32 colours, no dithering (flat tones);
   optionally a few of them kept for lamps and embers (`--accents`).
3. Save the final-size PNG (8-bit sRGB, RGB).

The source must already have the target aspect (crop it first; `fit_aspect`
centre-crops). Raw sources live in assets/art_incoming/ (.gdignore: never
imported, never shipped).

    python tools/pixelize.py SRC OUT --size 270x600 [--colors 32] [--accents 4]
        [--crop left,top,right,bottom]

Also imported by tools/build_backdrops.py (the title and victory images).
"""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

DEFAULT_COLORS = 32
## Accent pixels (see quantize): HSV saturation and value (0-255) at least these.
ACCENT_SAT = 0.45
ACCENT_VALUE = 90


def fit_aspect(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Centre-crop `image` to the aspect of `size` (no scaling)."""
    w, h = image.size
    target = size[0] / size[1]
    if abs(w / h - target) < 1e-4:
        return image
    if w / h > target:
        new_w = round(h * target)
        left = (w - new_w) // 2
        return image.crop((left, 0, left + new_w, h))
    new_h = round(w / target)
    top = (h - new_h) // 2
    return image.crop((0, top, w, top + new_h))


def box_downscale(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Area-average downscale to exactly `size`."""
    return fit_aspect(image.convert("RGB"), size).resize(size, Image.Resampling.BOX)


def _median_cut(image: Image.Image, colors: int) -> Image.Image:
    return image.quantize(colors=colors, method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE).convert("RGB")


def quantize(image: Image.Image, colors: int = DEFAULT_COLORS, accents: int = 0) -> Image.Image:
    """Median-cut palette of `colors`, no dithering, back to RGB.

    `accents` > 0 keeps that many of the colours for the small, saturated,
    lit pixels (lamps, embers): median cut weighs colours by how many pixels
    use them, so a handful of lamps on a dark field would otherwise merge into
    the field and vanish. They are cut on their own palette."""
    image = image.convert("RGB")
    if accents <= 0:
        return _median_cut(image, colors)
    import numpy as np
    a = np.asarray(image).astype(float)
    hi = a.max(axis=-1)
    sat = np.where(hi > 0, (hi - a.min(axis=-1)) / np.maximum(hi, 1.0), 0.0)
    lit = (sat >= ACCENT_SAT) & (hi >= ACCENT_VALUE)
    out = np.asarray(_median_cut(image, colors - accents)).copy()
    if lit.any():
        strip = Image.fromarray(a[lit][None].round().astype(np.uint8))
        out[lit] = np.asarray(_median_cut(strip, accents))[0]
    return Image.fromarray(out)


def pixelize(image: Image.Image, size: tuple[int, int], colors: int = DEFAULT_COLORS, accents: int = 0) -> Image.Image:
    return quantize(box_downscale(image, size), colors, accents)


def save(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(path, optimize=True)


def _size(text: str) -> tuple[int, int]:
    w, h = text.lower().split("x")
    return int(w), int(h)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("src", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--size", type=_size, required=True, help="final art size, e.g. 270x600")
    parser.add_argument("--colors", type=int, default=DEFAULT_COLORS)
    parser.add_argument("--accents", type=int, default=0, help="colours kept for small lit, saturated pixels")
    parser.add_argument("--crop", type=str, default="", help="crop the source first: left,top,right,bottom")
    args = parser.parse_args()
    src = Image.open(args.src)
    if args.crop:
        src = src.crop(tuple(int(v) for v in args.crop.split(",")))
    out = pixelize(src, args.size, args.colors, args.accents)
    save(out, args.out)
    print(f"{args.out}: {out.size[0]}x{out.size[1]}, {len(out.getcolors(1 << 16) or [])} colours")


if __name__ == "__main__":
    main()
