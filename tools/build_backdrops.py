"""Build the title backdrop and the Operation Cleared images from raw sources.

Kev, 2026-10-17 (DECISIONS_RESOLVED G-76): a space backdrop on the title
screen; one "Operation Cleared" image per operation on the victory screen
(Facility first). Raw AI-generated sources sit in assets/art_incoming/ (never
imported, never shipped); this script writes the final-size art through
tools/pixelize.py (area downscale, median-cut quantize, no dithering).

Both outputs are the bleed canvas of docs/ART_SPEC.md: the 270 x 600 art px
core (the 20:9 screen) centred in 338 x 660, so 16:9 and 21:9 phones see art,
not the plain screen colour, at their extra edges.

    python tools/build_backdrops.py            # writes both, prints the checks
    python tools/build_backdrops.py --check    # measures the shipped files only

Title treatment (ART_SPEC "Title screen backdrop"):
- Stars are re-placed as crisp art pixels: every star blob of the downscaled
  image is cleared to the space colour and redrawn at its centre. The four-point
  sparkles keep their cross, toned down to plain-star brightness.
- Safe zone (core art px x 20-250, y 130-470): luminance at most 20, so the
  stars there are kept faint.
- Everywhere else: highlights at most 48 (the planet is scaled toward the space
  colour until its rim is 48), saturation at most 35% (HSV).
- Bleed: the space colour with a sparse, seeded starfield; the planet is carried
  past the core's sides along its own limb (a circle fitted to the rim,
  mirrored about the core edge at the same radius) and mirrored downward.

Luminance is Rec. 601 luma, 0-255.
"""
from __future__ import annotations

import argparse
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixelize  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
INCOMING = ROOT / "assets/art_incoming"
VICTORY_SOURCE_CROP = (3, 0, 411, 935)
VICTORY_ACCENTS = 5      # palette entries kept for the lamps and the ember eye
TITLE_OUT = ROOT / "assets/ui/title/title_backdrop.png"
VICTORY_OUT = ROOT / "assets/ui/victory/victory_facility.png"

CORE = (270, 600)
CANVAS = (338, 660)
PAD = ((CANVAS[0] - CORE[0]) // 2, (CANVAS[1] - CORE[1]) // 2)   # (34, 30)
SAFE = (20, 130, 250, 470)   # core art px: x0, y0, x1, y1 (exclusive ends)
SAFE_MAX = 20.0
HIGHLIGHT_MAX = 48.0
SAT_MAX = 0.35
LUMA = np.array([0.299, 0.587, 0.114])
COLORS = 32
STAR_LEVELS = 4          # palette entries kept back for the stars
STAR_THRESHOLD = 16.0    # luma above the space colour that marks a star pixel
PLANET_SEARCH_Y = 470    # the planet rim is looked for below this core row
PLANET_KNEE_TOP = HIGHLIGHT_MAX - 1.0 - 11.7   # luma over space the knee tends to
PLANET_KNEE = 50.0       # body (~32 over space) lands near 29, the rim near 45
RIM_HAZE = 30.0         # px above the rim where the planet's haze still shows
SAT_TARGET = 0.33        # clamp a little under the limit so rounding stays under it


def luma(a: np.ndarray) -> np.ndarray:
    return a[..., :3] @ LUMA


def hsv_sat(a: np.ndarray) -> np.ndarray:
    hi = a.max(axis=-1)
    lo = a.min(axis=-1)
    return np.where(hi > 0, (hi - lo) / np.maximum(hi, 1e-6), 0.0)


def clamp_saturation(a: np.ndarray, limit: float = SAT_TARGET) -> np.ndarray:
    sat = hsv_sat(a)
    hi = a.max(axis=-1, keepdims=True)
    k = np.where(sat > limit, limit / np.maximum(sat, 1e-6), 1.0)[..., None]
    return hi - (hi - a) * k


# ── title ────────────────────────────────────────────────────────────────────

def _fit_rim(L: np.ndarray, space_l: float) -> tuple[float, float, float]:
    """Circle (cx, cy, R) through the planet's top rim, outliers dropped."""
    xs, ys = [], []
    for x in range(L.shape[1]):
        col = L[PLANET_SEARCH_Y:, x]
        hits = np.nonzero(col > space_l + 25.0)[0]
        if hits.size:
            xs.append(x)
            ys.append(PLANET_SEARCH_Y + hits[0])
    xs = np.array(xs, float)
    ys = np.array(ys, float)
    keep = np.ones(xs.size, bool)
    for _ in range(4):
        A = np.c_[2 * xs[keep], 2 * ys[keep], np.ones(keep.sum())]
        b = xs[keep] ** 2 + ys[keep] ** 2
        cx, cy, c = np.linalg.lstsq(A, b, rcond=None)[0]
        R = math.sqrt(c + cx * cx + cy * cy)
        resid = np.abs(np.hypot(xs - cx, ys - cy) - R)
        keep = resid < 2.5
    return cx, cy, R


def _star_blobs(L: np.ndarray, planet: np.ndarray, space_l: float) -> list[dict]:
    from scipy import ndimage
    mask = (L > space_l + STAR_THRESHOLD * 0.5) & ~planet
    labels, _ = ndimage.label(mask)
    blobs = []
    for i, sl in enumerate(ndimage.find_objects(labels), start=1):
        region = labels[sl] == i
        peak = float(L[sl][region].max())
        if peak < space_l + STAR_THRESHOLD:
            continue
        h = sl[0].stop - sl[0].start
        w = sl[1].stop - sl[1].start
        ys, xs = np.nonzero(region)
        weights = L[sl][region] - space_l
        cy = sl[0].start + float((ys * weights).sum() / weights.sum())
        cx = sl[1].start + float((xs * weights).sum() / weights.sum())
        blobs.append({"slice": sl, "region": region, "peak": peak,
                      "x": int(round(cx)), "y": int(round(cy)), "sparkle": min(h, w) >= 6})
    return blobs


def _in_safe(x: int, y: int) -> bool:
    return SAFE[0] <= x < SAFE[2] and SAFE[1] <= y < SAFE[3]


def build_title() -> Image.Image:
    raw = Image.open(INCOMING / "title_space_raw.png")
    core = np.asarray(pixelize.box_downscale(raw, CORE)).astype(float)
    space = np.median(core.reshape(-1, 3), axis=0)
    space_l = float(space @ LUMA)
    L = luma(core)
    cx, cy, R = _fit_rim(L, space_l)
    yy, xx = np.mgrid[0:CORE[1], 0:CORE[0]]
    # The planet and its thin atmosphere glow (a few px above the rim).
    planet = np.hypot(xx - cx, yy - cy) < R + 6.0

    # Stars: clear each blob to space, remember where it was.
    blobs = _star_blobs(L, planet, space_l)
    for blob in blobs:
        sl = blob["slice"]
        core[sl][blob["region"]] = space
    # The planet: its brightness over space goes through a soft knee that tops
    # out under 48, so the rim stays the brightest line and the body still reads.
    excess = core - space
    e = np.maximum(luma(core) - space_l, 0.0)
    e_new = PLANET_KNEE_TOP * (1.0 - np.exp(-e / PLANET_KNEE))
    gain = np.where(e > 1e-6, e_new / np.maximum(e, 1e-6), 1.0)
    core[planet] = space + excess[planet] * gain[planet][:, None]

    # Bleed canvas: the core mirrored outward (the space keeps its faint
    # texture, no seam); near the planet the mirror keeps the radius instead,
    # so the rim, the glow and the haze continue along the planet's own curve.
    canvas = np.empty((CANVAS[1], CANVAS[0], 3), float)
    for Y in range(CANVAS[1]):
        for X in range(CANVAS[0]):
            x, y = X - PAD[0], Y - PAD[1]
            if 0 <= x < CORE[0] and 0 <= y < CORE[1]:
                canvas[Y, X] = core[y, x]
                continue
            sx = -x - 1 if x < 0 else (2 * CORE[0] - 1 - x if x >= CORE[0] else x)
            sy = -y - 1 if y < 0 else (2 * CORE[1] - 1 - y if y >= CORE[1] else y)
            if x != sx and y < CORE[1] and math.hypot(x - cx, y - cy) < R + RIM_HAZE:
                r = math.hypot(x - cx, y - cy)
                dy = math.sqrt(max(r * r - (sx - cx) ** 2, 0.0))
                sy = min(max(int(round(cy - dy if y < cy else cy + dy)), 0), CORE[1] - 1)
            canvas[Y, X] = core[sy, sx]
    canvas = clamp_saturation(canvas)

    # Quantize the field (stars held back), then draw the stars on top.
    field = pixelize.quantize(Image.fromarray(np.clip(canvas, 0, 255).round().astype(np.uint8)), COLORS - STAR_LEVELS)
    out = np.asarray(field).astype(float).copy()
    space_q = np.median(out.reshape(-1, 3), axis=0)
    star_dir = np.array([137.0, 167.0, 203.0])   # the source stars' cool white
    star_dir = star_dir / float(star_dir @ LUMA)

    def star(level: float) -> np.ndarray:
        return clamp_saturation((space_q + star_dir * (level - float(space_q @ LUMA)))[None])[0].round()

    bright, mid, faint, safe = star(44.0), star(34.0), star(26.0), star(SAFE_MAX)
    peaks = sorted(b["peak"] for b in blobs)
    cut_hi = peaks[int(len(peaks) * 0.66)] if peaks else 0.0
    cut_lo = peaks[int(len(peaks) * 0.33)] if peaks else 0.0

    def plot(X: int, Y: int, colour: np.ndarray) -> None:
        if 0 <= X < CANVAS[0] and 0 <= Y < CANVAS[1]:
            out[Y, X] = colour

    def place(x: int, y: int, level_peak: float, sparkle: bool) -> None:
        if _in_safe(x, y):
            centre = safe
            arm = None   # faint stars only: no cross inside the safe zone
        else:
            # Plain-star brightness: a sparkle's centre is a bright plain star.
            centre = bright if (sparkle or level_peak >= cut_hi) else (mid if level_peak >= cut_lo else faint)
            arm = faint if sparkle else None
        X, Y = x + PAD[0], y + PAD[1]
        plot(X, Y, centre)
        if arm is not None:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                plot(X + dx, Y + dy, arm)

    for blob in blobs:
        place(blob["x"], blob["y"], blob["peak"], blob["sparkle"])
    # A sparse starfield in the bleed, about the core's density, seeded.
    rng = np.random.default_rng(20261017)
    density = len(blobs) / float(CORE[0] * PLANET_SEARCH_Y)
    for _ in range(int(round(density * (CANVAS[0] * CANVAS[1] - CORE[0] * CORE[1]) * 0.6))):
        while True:
            X = int(rng.integers(0, CANVAS[0]))
            Y = int(rng.integers(0, PAD[1] + PLANET_SEARCH_Y))
            x, y = X - PAD[0], Y - PAD[1]
            if not (0 <= x < CORE[0] and 0 <= y < CORE[1]) and math.hypot(x - cx, y - cy) > R + RIM_HAZE:
                break
        plot(X, Y, faint if rng.random() < 0.6 else mid)

    out = _enforce_limits(clamp_saturation(out).round(), PAD)
    print(f"title: rim circle centre ({cx:.1f}, {cy:.1f}) core px, radius {R:.1f}; "
          f"{len(blobs)} stars "
          f"({sum(b['sparkle'] for b in blobs)} sparkles)")
    return Image.fromarray(out.astype(np.uint8))


def _enforce_limits(out: np.ndarray, pad: tuple[int, int]) -> np.ndarray:
    """Any pixel over its zone's limit takes the nearest palette colour under it."""
    palette = np.unique(out.reshape(-1, 3), axis=0)
    pal_l = luma(palette)
    L = luma(out)
    limit = np.full(L.shape, HIGHLIGHT_MAX)
    limit[pad[1] + SAFE[1]:pad[1] + SAFE[3], pad[0] + SAFE[0]:pad[0] + SAFE[2]] = SAFE_MAX
    for Y, X in np.argwhere(L > limit):
        ok = palette[pal_l <= limit[Y, X]]
        out[Y, X] = ok[np.argmin(((ok - out[Y, X]) ** 2).sum(axis=1))]
    return out


# ── victory ──────────────────────────────────────────────────────────────────

def build_victory() -> Image.Image:
    # The source has a dark frame line down both sides (3 px left, 5 right):
    # cropped, or the mirrored bleed would repeat it as a seam.
    raw = Image.open(INCOMING / "victory_facility_raw.png").crop(VICTORY_SOURCE_CROP)
    core = np.asarray(pixelize.box_downscale(raw, CORE))
    # Bleed: the scene mirrored outward (sky up, rubble down, towers sideways).
    canvas = np.pad(core, ((PAD[1], PAD[1]), (PAD[0], PAD[0]), (0, 0)), mode="symmetric")
    return pixelize.quantize(Image.fromarray(canvas), COLORS, VICTORY_ACCENTS)


# ── checks ───────────────────────────────────────────────────────────────────

def measure_title(path: Path) -> None:
    a = np.asarray(Image.open(path).convert("RGB")).astype(float)
    assert a.shape[1] == CANVAS[0] and a.shape[0] == CANVAS[1], a.shape
    core = a[PAD[1]:PAD[1] + CORE[1], PAD[0]:PAD[0] + CORE[0]]
    L = luma(a)
    Lc = luma(core)
    safe = Lc[SAFE[1]:SAFE[3], SAFE[0]:SAFE[2]]
    rest = np.ones(L.shape, bool)
    rest[PAD[1] + SAFE[1]:PAD[1] + SAFE[3], PAD[0] + SAFE[0]:PAD[0] + SAFE[2]] = False
    Lr = L[rest]
    sat = hsv_sat(a)
    colours = len(np.unique(a.reshape(-1, 3), axis=0))
    print(f"{path.name}: {a.shape[1]}x{a.shape[0]}, {colours} colours")
    print(f"  safe zone (core x {SAFE[0]}-{SAFE[2]}, y {SAFE[1]}-{SAFE[3]}): luma min {safe.min():.1f}, "
          f"median {np.median(safe):.1f}, max {safe.max():.1f} (limit {SAFE_MAX:.0f})")
    print(f"  everywhere else: luma p5 {np.percentile(Lr, 5):.1f}, median {np.median(Lr):.1f}, "
          f"p95 {np.percentile(Lr, 95):.1f}, max {Lr.max():.1f} (limit {HIGHLIGHT_MAX:.0f}); "
          f"{(Lr > 30).mean() * 100:.2f}% over 30, {((Lr >= 8) & (Lr <= 30)).mean() * 100:.1f}% in 8-30")
    print(f"  saturation (HSV): max {sat.max() * 100:.1f}% (limit {SAT_MAX * 100:.0f}%)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="measure the shipped files only")
    args = parser.parse_args()
    if not args.check:
        pixelize.save(build_title(), TITLE_OUT)
        pixelize.save(build_victory(), VICTORY_OUT)
    measure_title(TITLE_OUT)
    v = Image.open(VICTORY_OUT).convert("RGB")
    print(f"{VICTORY_OUT.name}: {v.size[0]}x{v.size[1]}, {len(v.getcolors(1 << 16))} colours")


if __name__ == "__main__":
    main()
