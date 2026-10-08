"""Self / Summon icon options (proposal only; nothing in assets/ is touched).

Each option is drawn on the icon set's 32x32 cell grid and saved at the set's
128 px native size. The figure is the existing one, lifted from self.png, so
every option keeps the set's own body shape and shading.

  python make_icons.py <repo root> <out dir>
"""
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(sys.argv[1])
OUT = Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)
PIPS = ROOT / "assets" / "ui" / "pips"
CELL = 4
BG = (11, 15, 19, 255)          # INSPECT_BG
PANEL = (16, 22, 28, 255)

WHITE = [(250, 250, 246), (232, 228, 219), (216, 213, 204), (196, 193, 184)]   # light -> shade
PURPLE = [(176, 122, 206), (133, 77, 161), (104, 62, 130), (74, 46, 92)]


def figure() -> Image.Image:
    """The set's own figure, cut from self.png (cells 9..22 x 4..25)."""
    src = Image.open(PIPS / "self.png").convert("RGBA")
    box = (9 * CELL, 4 * CELL, 23 * CELL, 26 * CELL)
    fig = src.crop(box)
    # Drop the ring's stray dark specks that fall inside the crop.
    px = fig.load()
    for y in range(fig.size[1]):
        for x in range(fig.size[0]):
            r, g, b, a = px[x, y]
            if a < 200 or (r + g + b) // 3 < 110:
                px[x, y] = (0, 0, 0, 0)
    return fig


FIG = figure()
FIG_W, FIG_H = FIG.size[0] // CELL, FIG.size[1] // CELL   # 14 x 22 cells


def canvas() -> Image.Image:
    return Image.new("RGBA", (128, 128), (0, 0, 0, 0))


def put_figure(img: Image.Image, cx: int, top: int) -> None:
    """Paste the figure with its left edge at cell cx, top at cell `top`."""
    img.alpha_composite(FIG, (cx * CELL, top * CELL))


def cells(img: Image.Image, art: list[str], ox: int, oy: int, ramp: list, seed: int) -> None:
    """Draw ASCII cells. '#' = lit, '+' = mid, '-' = shade; tone also falls
    off down the shape, with a little grain, like the rest of the set."""
    rng = random.Random(seed)
    draw = ImageDraw.Draw(img)
    rows = len(art)
    for y, row in enumerate(art):
        for x, ch in enumerate(row):
            if ch in " .":
                continue
            base = {"#": 0, "+": 1, "-": 2}[ch]
            # Light from above: the tone slides one step down the ramp over
            # the shape's height, cell by cell, with a little grain.
            t = base + (y / max(rows - 1, 1)) * 1.2
            lo = min(len(ramp) - 1, int(t))
            hi = min(len(ramp) - 1, lo + 1)
            f = t - int(t)
            r, g, b = [round(ramp[lo][k] * (1 - f) + ramp[hi][k] * f) for k in range(3)]
            j = rng.randint(-5, 5)
            col = (max(0, min(255, r + j)), max(0, min(255, g + j)), max(0, min(255, b + j)), 255)
            px, py = (ox + x) * CELL, (oy + y) * CELL
            draw.rectangle([px, py, px + CELL - 1, py + CELL - 1], fill=col)


# ── Self ──────────────────────────────────────────────────────────────────────
def self_pointer() -> Image.Image:
    """A: a marker arrow over the unit's head ("this one")."""
    img = canvas()
    arrow = [
        "############",
        ".##########.",
        "..+######+..",
        "...+####+...",
        "....+##+....",
        ".....++.....",
    ]
    cells(img, arrow, 10, 0, WHITE, 11)
    put_figure(img, 9, 9)
    return img


def self_loop() -> Image.Image:
    """B: an arrow that leaves the unit and curves back into it."""
    img = canvas()
    put_figure(img, 3, 5)
    loop = [
        "..########..",
        ".##########.",
        "###......###",
        "##........##",
        "..........##",
        "..........##",
        "..........##",
        "..........##",
        "..........##",
        "..........##",
        "....#.....##",
        "...##....###",
        "..#########.",
        ".#########..",
        "..##........",
        "...##.......",
        "....#.......",
    ]
    cells(img, loop, 18, 4, WHITE, 12)
    return img


def self_brackets() -> Image.Image:
    """C: the unit between two square brackets."""
    img = canvas()
    put_figure(img, 9, 5)
    left = ["#####"] * 2 + ["##..."] * 24 + ["#####"] * 2
    right = [row[::-1] for row in left]
    cells(img, left, 2, 2, WHITE, 13)
    cells(img, right, 25, 2, WHITE, 14)
    return img


# ── Summon ────────────────────────────────────────────────────────────────────
def summon_plus() -> Image.Image:
    """A: the unit with a plus ("one more unit")."""
    img = canvas()
    put_figure(img, 4, 8)
    plus = [
        "....####....",
        "....####....",
        "....####....",
        "....####....",
        "############",
        "############",
        "############",
        "############",
        "....####....",
        "....####....",
        "....####....",
        "....####....",
    ]
    cells(img, plus, 19, 1, PURPLE, 21)
    return img


def summon_gate() -> Image.Image:
    """B: the unit stepping out of a gate."""
    img = canvas()
    gate = (
        ["..######################.."]
        + [".########################."]
        + ["###....................###"] * 1
        + ["###....................###"] * 24
        + ["##########################"] * 2
    )
    cells(img, gate, 3, 1, PURPLE, 22)
    put_figure(img, 9, 5)
    return img


def summon_call() -> Image.Image:
    """C: the unit sending out a call."""
    img = canvas()
    put_figure(img, 2, 8)
    waves = [
        ".........###..",
        "..........###.",
        "...........###",
        ".....###....##",
        "......###...##",
        ".......##...##",
        "##.....##...##",
        "###....##...##",
        "###....##...##",
        "##.....##...##",
        ".......##...##",
        "......###...##",
        ".....###....##",
        "...........###",
        "..........###.",
        ".........###..",
    ]
    cells(img, waves, 17, 1, PURPLE, 23)
    return img


OPTIONS = {
    "self": [("A_pointer", self_pointer), ("B_loop", self_loop), ("C_brackets", self_brackets)],
    "summon": [("A_plus", summon_plus), ("B_gate", summon_gate), ("C_call", summon_call)],
}
NOTES = {
    "self_A_pointer": "A  Marker arrow",
    "self_B_loop": "B  Return arrow",
    "self_C_brackets": "C  Brackets",
    "summon_A_plus": "A  Plus",
    "summon_B_gate": "B  Gate",
    "summon_C_call": "C  Call",
}

# ── Sheets ────────────────────────────────────────────────────────────────────
FONT_PATH = ROOT / "assets" / "fonts" / "m5x7.ttf"


def font(px: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_PATH), px)


def at_size(icon: Image.Image, px: int) -> Image.Image:
    # The game draws pips with nearest sampling (EffectPip, TEXTURE_FILTER_NEAREST).
    return icon.resize((px, px), Image.NEAREST)


def pip_row(icon: Image.Image, kind: str, px: int) -> Image.Image:
    """The icon where the game puts it: Self after a value, Summon before one."""
    shield = Image.open(PIPS / "shield.png").convert("RGBA")
    f = font(int(px * 1.2))
    row = Image.new("RGBA", (int(px * 4.6), px + 8), PANEL)
    d = ImageDraw.Draw(row)
    x = 6
    if kind == "self":
        row.alpha_composite(at_size(shield, px), (x, 4))
        x += px + 4
        d.text((x, 4 + px // 2), "5", font=f, fill=(120, 190, 235), anchor="lm")
        x += int(d.textlength("5", font=f)) + 6
        row.alpha_composite(at_size(icon, int(px * 0.95)), (x, 4))
    else:
        row.alpha_composite(at_size(icon, px), (x, 4))
        x += px + 4
        d.text((x, 4 + px // 2), "42%", font=f, fill=(223, 233, 236), anchor="lm")
    return row


def sheet(kind: str) -> None:
    current = Image.open(PIPS / f"{kind}.png").convert("RGBA")
    entries = [(f"Current {kind}", current)]
    for name, fn in OPTIONS[kind]:
        icon = fn()
        icon.save(OUT / f"{kind}_{name}.png")
        entries.append((NOTES[f"{kind}_{name}"], icon))
    col_w, big = 340, 256
    head = 70
    h = head + 44 + big + 30 + 40 + 60 + 36 + 60 + 36 + 60 + 40
    img = Image.new("RGBA", (col_w * len(entries) + 40, h), BG)
    d = ImageDraw.Draw(img)
    d.text((20, 14), f"{kind.upper()} ICON OPTIONS", font=font(48), fill=(223, 233, 236))
    for i, (label, icon) in enumerate(entries):
        x = 20 + i * col_w
        y = head
        d.text((x, y), label, font=font(32), fill=(95, 216, 234) if i else (138, 153, 166))
        y += 44
        img.alpha_composite(icon.resize((big, big), Image.NEAREST), (x, y))
        y += big + 30
        # Actual pip sizes: 40 design px is what a 1080-wide phone shows; the
        # 540x1200 desktop preview shows the same pip at half that.
        d.text((x, y), "pip size: phone 40 px / preview 20 px", font=font(16), fill=(113, 130, 143))
        y += 40
        img.alpha_composite(at_size(icon, 40), (x, y))
        img.alpha_composite(at_size(icon, 20), (x + 70, y + 10))
        y += 60
        d.text((x, y), "in a pip row (phone)", font=font(16), fill=(113, 130, 143))
        y += 36
        img.alpha_composite(pip_row(icon, kind, 40), (x, y))
        y += 60
        d.text((x, y), "in a pip row (preview)", font=font(16), fill=(113, 130, 143))
        y += 36
        img.alpha_composite(pip_row(icon, kind, 20), (x, y))
    img.save(OUT / f"{kind}_options.png")
    print(OUT / f"{kind}_options.png", img.size)


def side_by_side() -> None:
    """Every Self option beside every Summon option at pip size: the pairs the
    player has to tell apart."""
    selfs = [("cur", Image.open(PIPS / "self.png").convert("RGBA"))] + [(n[0], fn()) for n, fn in OPTIONS["self"]]
    summons = [("cur", Image.open(PIPS / "summon.png").convert("RGBA"))] + [(n[0], fn()) for n, fn in OPTIONS["summon"]]
    cw, ch = 150, 70
    img = Image.new("RGBA", (130 + cw * len(summons), 110 + ch * len(selfs)), BG)
    d = ImageDraw.Draw(img)
    d.text((20, 12), "SELF vs SUMMON AT PIP SIZE (40 px and 20 px)", font=font(32), fill=(223, 233, 236))
    for j, (sn, _) in enumerate(summons):
        d.text((130 + j * cw, 62), f"Summon {sn}", font=font(16), fill=(138, 153, 166))
    for i, (name, s_icon) in enumerate(selfs):
        y = 100 + i * ch
        d.text((20, y + 12), f"Self {name}", font=font(16), fill=(138, 153, 166))
        for j, (_, m_icon) in enumerate(summons):
            x = 130 + j * cw
            img.alpha_composite(at_size(s_icon, 40), (x, y))
            img.alpha_composite(at_size(m_icon, 40), (x + 44, y))
            img.alpha_composite(at_size(s_icon, 20), (x + 96, y + 10))
            img.alpha_composite(at_size(m_icon, 20), (x + 118, y + 10))
    img.save(OUT / "self_vs_summon_pip_size.png")
    print(OUT / "self_vs_summon_pip_size.png", img.size)


sheet("self")
sheet("summon")
side_by_side()
