"""Slice a contact sheet of sprites into individual cut-out PNGs.

Reusable pipeline tool (Prompt 6, Icon/Portrait Slice & Wire). Cuts a sheet laid
out left-to-right, top-to-bottom into an even COLS x ROWS grid, keys the (black)
background to transparency per cell, tight-crops each sprite INCLUDING its glow,
pads to a centered square (for item icons), and resizes to the canonical size
with a premultiplied-alpha downscale (so no black fringe bleeds into soft edges).

Empty cells (no content above threshold) are skipped and emit no file. Outputs
go to a scratch dir; nothing is written into assets/ here (wiring is a separate,
post-approval step).

Background keying: a pixel is "background" only if it is BOTH dark (max channel <
--thresh) AND connected to the cell border (4-way flood fill). That protects
interior dark outlines / crevices from being punched transparent, while faint
panel divider lines (dark, border-connected) are removed. Glow is bright, so it
is never keyed out.

    python scripts/assets/slice_sheet.py \
        --sheet /tmp/sheet.png --cols 5 --rows 2 --size 32 \
        --ids patch_kit,triage_broadcast,scrap_plate,... \
        --out /tmp/cut --contact /tmp/cut/_contact.png

--ids maps grid position -> output id (row-major). Use '-' or '' for a position
to force-skip it. Extra grid cells beyond the id list are ignored.
"""
import argparse
import os
from collections import deque

from PIL import Image, ImageDraw, ImageFont
import numpy as np


def _exterior_bg_mask(value: np.ndarray, thresh: int) -> np.ndarray:
    """Border-connected dark pixels = exterior background. 4-way flood fill."""
    h, w = value.shape
    dark = value < thresh
    ext = np.zeros((h, w), dtype=bool)
    dq = deque()
    for x in range(w):
        for y in (0, h - 1):
            if dark[y, x] and not ext[y, x]:
                ext[y, x] = True
                dq.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if dark[y, x] and not ext[y, x]:
                ext[y, x] = True
                dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and dark[ny, nx] and not ext[ny, nx]:
                ext[ny, nx] = True
                dq.append((ny, nx))
    return ext


def _cut_cell(rgb: np.ndarray, thresh: int, floor: int = 0) -> Image.Image | None:
    """Return an RGBA cut-out for one cell, or None if the cell is empty.

    floor > 0 also removes faint INTERIOR panels (islands the border flood-fill
    can't reach): alpha ramps 0->255 over [floor, floor+RAMP] of max-channel
    value, so a dim chip-frame behind a glyph is keyed out while the bright glyph
    (and its glow) survive. floor == 0 keeps the original binary-alpha behavior.
    """
    value = rgb.max(axis=2)
    ext_bg = _exterior_bg_mask(value, thresh)
    if floor > 0:
        ramp = 30.0
        alpha = np.clip((value.astype(np.float64) - float(floor)) / ramp, 0.0, 1.0)
        alpha[ext_bg] = 0.0
        content = alpha > 0.15
    else:
        alpha = np.where(ext_bg, 0.0, 1.0)
        content = ~ext_bg
    # Drop specks: require a meaningful content area to treat the cell as filled.
    if content.sum() < 150:
        return None
    ys, xs = np.where(content)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    crop_rgb = rgb[y0:y1, x0:x1].astype(np.uint8)
    crop_a = (alpha[y0:y1, x0:x1] * 255.0).round().astype(np.uint8)
    rgba = np.dstack([crop_rgb, crop_a])
    return Image.fromarray(rgba, "RGBA")


def _pad_square(im: Image.Image, margin: float) -> Image.Image:
    """Center the sprite on a transparent square; `margin` = fraction of the
    square left as breathing room on the longer side (each edge)."""
    w, h = im.size
    long_side = max(w, h)
    side = int(round(long_side / (1.0 - 2.0 * margin)))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im, ((side - w) // 2, (side - h) // 2))
    return canvas


def _resize_premult(im: Image.Image, size: int) -> Image.Image:
    """Downscale with premultiplied alpha so transparent (black) pixels don't
    bleed dark fringe into soft edges. Then un-premultiply."""
    arr = np.asarray(im).astype(np.float64)
    rgb = arr[:, :, :3]
    a = arr[:, :, 3:4] / 255.0
    premult = Image.fromarray((rgb * a).clip(0, 255).astype(np.uint8), "RGB")
    alpha = Image.fromarray(arr[:, :, 3].astype(np.uint8), "L")
    pm = np.asarray(premult.resize((size, size), Image.LANCZOS)).astype(np.float64)
    al = np.asarray(alpha.resize((size, size), Image.LANCZOS)).astype(np.float64) / 255.0
    al = al[:, :, None]  # (H,W,1) so it broadcasts against the (H,W,3) RGB
    with np.errstate(divide="ignore", invalid="ignore"):
        out_rgb = np.where(al > 0, pm / al, 0.0)
    out = np.dstack([out_rgb.clip(0, 255), (al[:, :, 0] * 255.0).clip(0, 255)]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def slice_sheet(sheet_path, cols, rows, ids, out_dir, size, thresh, margin, floor=0):
    sheet = Image.open(sheet_path).convert("RGB")
    arr = np.asarray(sheet).astype(int)
    H, W, _ = arr.shape
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for r in range(rows):
        for c in range(cols):
            idx = r * cols + c
            if idx >= len(ids):
                continue
            entity_id = ids[idx].strip()
            x0, x1 = int(round(W * c / cols)), int(round(W * (c + 1) / cols))
            y0, y1 = int(round(H * r / rows)), int(round(H * (r + 1) / rows))
            cell = arr[y0:y1, x0:x1]
            cut = _cut_cell(cell, thresh, floor)
            if cut is None:
                print(f"  cell r{r}c{c} [{entity_id or '-'}]: EMPTY, skipped")
                continue
            if entity_id in ("", "-"):
                print(f"  cell r{r}c{c}: content present but id blanked, skipped")
                continue
            square = _pad_square(cut, margin)
            final = _resize_premult(square, size)
            path = os.path.join(out_dir, f"{entity_id}.png")
            final.save(path)
            written.append((entity_id, path, cut.size))
            print(f"  cell r{r}c{c} -> {entity_id}.png  (bbox {cut.size[0]}x{cut.size[1]} -> {size}x{size})")
    return written


def make_contact_sheet(written, out_path, cell=140, cols=5):
    """Labeled contact sheet: each crop scaled up (NEAREST) with its id beneath."""
    if not written:
        return
    rows = (len(written) + cols - 1) // cols
    pad, labelh = 12, 22
    cw, ch = cell + pad, cell + labelh + pad
    sheet = Image.new("RGB", (cols * cw, rows * ch), (18, 18, 22))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("arial.ttf", 15)
    except Exception:
        font = ImageFont.load_default()
    # checker so transparency is visible
    for i, (entity_id, path, _bbox) in enumerate(written):
        r, c = divmod(i, cols)
        ox, oy = c * cw + pad // 2, r * ch + pad // 2
        checker = Image.new("RGB", (cell, cell), (40, 40, 46))
        cd = ImageDraw.Draw(checker)
        for yy in range(0, cell, 10):
            for xx in range(0, cell, 10):
                if (xx // 10 + yy // 10) % 2:
                    cd.rectangle([xx, yy, xx + 9, yy + 9], fill=(52, 52, 60))
        icon = Image.open(path).convert("RGBA").resize((cell, cell), Image.NEAREST)
        checker.paste(icon, (0, 0), icon)
        sheet.paste(checker, (ox, oy))
        draw.text((ox, oy + cell + 3), entity_id, fill=(230, 230, 120), font=font)
    sheet.save(out_path)
    print(f"contact sheet -> {out_path}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", required=True)
    ap.add_argument("--cols", type=int, required=True)
    ap.add_argument("--rows", type=int, required=True)
    ap.add_argument("--ids", required=True, help="comma-separated, row-major; '-' skips")
    ap.add_argument("--out", required=True)
    ap.add_argument("--size", type=int, default=32)
    ap.add_argument("--thresh", type=int, default=24, help="bg darkness ceiling (max channel)")
    ap.add_argument("--margin", type=float, default=0.06, help="square breathing room per edge")
    ap.add_argument("--floor", type=int, default=0, help="value floor: also keys out faint INTERIOR panels behind glyphs (0 = off)")
    ap.add_argument("--contact", default="")
    args = ap.parse_args()
    ids = args.ids.split(",")
    print(f"Slicing {args.sheet}  {args.cols}x{args.rows}  size={args.size} thresh={args.thresh} floor={args.floor}")
    written = slice_sheet(args.sheet, args.cols, args.rows, ids, args.out, args.size, args.thresh, args.margin, args.floor)
    print(f"{len(written)} sprite(s) written to {args.out}")
    if args.contact:
        make_contact_sheet(written, args.contact, cols=args.cols)


if __name__ == "__main__":
    main()
