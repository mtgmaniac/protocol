"""Crisp text step 1 (2026-10-19): captures and sheets for the 40 / 80 / 120 preview.

  python scripts/checks/text_40_80_120.py capture <phase> [screen ...]
      phase: before | after | alt_a | alt_b. Shoots every screen on both
      canvases (alt_* only Help SETTINGS and squad select at 640x960) into
      debug_artifacts/text_40_80_120/<phase>/<screen>_<canvas>.png (+ .json).
  python scripts/checks/text_40_80_120.py sheets
      Before/after sheets, the alternate sheets, the 4x body-line zoom with its
      stroke-evenness score, and overflow.json from the after captures.

Godot: GODOT_BIN (a console exe with the main exe beside it). Captures run
windowed with a scratch APPDATA so the dev profile is never touched.
"""
import json
import os
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "debug_artifacts" / "text_40_80_120"
GODOT = os.environ.get("GODOT_BIN", "C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe")
SCREENS = ["title", "squad", "squad_info", "battle", "inspect", "help_settings", "help_units", "reward"]
CANVASES = ["640x960", "1080x2400"]
ALT_SCREENS = ["help_settings", "squad"]


def capture(phase: str, screens: list) -> None:
    canvases = ["640x960"] if phase.startswith("alt_") else CANVASES
    if os.environ.get("TSC_CANVAS"):
        canvases = [os.environ["TSC_CANVAS"]]
    screens = screens or (ALT_SCREENS if phase.startswith("alt_") else SCREENS)
    appdata = tempfile.mkdtemp(prefix="tsc_appdata_")
    env = dict(os.environ, APPDATA=appdata)
    for canvas in canvases:
        for screen in screens:
            png = OUT / phase / f"{screen}_{canvas}.png"
            args = [GODOT, "--path", str(ROOT), "-s", "res://scripts/debug/text_size_capture.gd",
                    f"--capture-window={canvas}", f"--tsc-screen={screen}", f"--tsc-out={png.as_posix()}"]
            if phase.startswith("alt_"):
                args.append(f"--crisp-alt={phase[4:]}")
            try:
                res = subprocess.run(args, env=env, capture_output=True, text=True, timeout=120, encoding="utf-8", errors="replace")
                line = [l for l in res.stdout.splitlines() if "[TEXT_SIZE_CAPTURE]" in l]
                errs = [l for l in (res.stdout + res.stderr).splitlines() if "SCRIPT ERROR" in l or "Parse Error" in l]
                print(phase, canvas, screen, line[-1] if line else "NO OUTPUT rc=%s" % res.returncode)
                for e in errs[:5]:
                    print("   ", e)
            except subprocess.TimeoutExpired:
                print(phase, canvas, screen, "TIMEOUT")


def _font(size: int):
    for name in ("consola.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def side_by_side(left: Path, right: Path, out: Path, titles: tuple) -> None:
    a, b = Image.open(left).convert("RGB"), Image.open(right).convert("RGB")
    pad, head = 16, 40
    w = a.width + b.width + pad * 3
    h = max(a.height, b.height) + head + pad
    sheet = Image.new("RGB", (w, h), (24, 24, 28))
    d = ImageDraw.Draw(sheet)
    f = _font(22)
    d.text((pad, 8), titles[0], fill=(230, 230, 230), font=f)
    d.text((pad * 2 + a.width, 8), titles[1], fill=(230, 230, 230), font=f)
    sheet.paste(a, (pad, head))
    sheet.paste(b, (pad * 2 + a.width, head))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)


def stroke_runs(img: Image.Image, box: tuple, ink: tuple, tol: int = 60, skip_edges: bool = False) -> Counter:
    im = img.convert("RGB").crop(box)
    w, h = im.size
    px = im.load()
    mask = [[sum(abs(px[x, y][c] - ink[c]) for c in range(3)) <= tol for x in range(w)] for y in range(h)]
    out = Counter()
    for y in range(h):
        n = 0
        for x in range(w + 1):
            if x < w and mask[y][x]:
                n += 1
            elif n:
                if not (skip_edges and (x == w or x - n == 0)):
                    out[n] += 1
                n = 0
    for x in range(w):
        n = 0
        for y in range(h + 1):
            if y < h and mask[y][x]:
                n += 1
            elif n:
                if not (skip_edges and (y == h or y - n == 0)):
                    out[n] += 1
                n = 0
    return out


def evenness(hist: Counter, k: int) -> float:
    """Share of ink runs that are a whole multiple of k screen px."""
    total = sum(hist.values())
    return sum(v for length, v in hist.items() if length % k == 0) / total if total else 0.0


def _rows(phase: str, screen: str, canvas: str) -> dict:
    p = OUT / phase / f"{screen}_{canvas}.json"
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else {"labels": []}


def _inside(inner, outer, slack=1.0):
    return (inner[0] >= outer[0] - slack and inner[1] >= outer[1] - slack
            and inner[0] + inner[2] <= outer[0] + outer[2] + slack and inner[1] + inner[3] <= outer[1] + outer[3] + slack)


def _overlap(a, b):
    return min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0]), min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1])


# Which layer a screen is about: pop-up screens report only the pop-up's text.
SCREEN_LAYER = {"inspect": "inspect_popup", "help_settings": "help_menu", "help_units": "help_menu"}


def overflow(phase: str) -> list:
    """Text whose ink leaves its node, its box or the canvas, is trimmed, or overlaps other text.

    Every measure is in that canvas's screen px. Text scrolled out of view is skipped."""
    found = []
    for canvas in CANVASES:
        for screen in SCREENS:
            data = _rows(phase, screen, canvas)
            s = data.get("final_scale", 1.0) if canvas == "640x960" else 1.0
            vis = [0, 0] + data.get("visible_rect", [0, 0])
            shown = []
            for r in data["labels"]:
                if screen in SCREEN_LAYER and r["layer"] != SCREEN_LAYER[screen]:
                    continue
                ink, clip = r["ink"], r["clip"]
                ox, oy = _overlap(ink, clip)
                if ox <= 0 or oy <= 0:
                    continue  # scrolled out of view
                why = []
                if not r["wraps"] and r["text_w"] > r["inner_w"] + 1.0:
                    if r["trims"]:
                        why.append("trimmed: %d of %d px shown" % (r["inner_w"] * s, r["text_w"] * s))
                    else:
                        why.append("wider than its node by %d px" % ((r["text_w"] - r["inner_w"]) * s))
                if r["content_h"] > r["inner_h"] + 1.0:
                    why.append("taller than its node by %d px" % ((r["content_h"] - r["inner_h"]) * s))
                if r["box_rect"] and not _inside(ink, r["box_rect"]):
                    why.append("ink leaves its box (%s)" % r["box"].split("/")[-1])
                if not _inside(ink, vis):
                    why.append("ink leaves the canvas")
                if why:
                    found.append({"canvas": canvas, "screen": screen, "text": r["text"], "size": r["size"], "why": why, "path": r["path"]})
                shown.append(r)
            for i in range(len(shown)):
                for j in range(i + 1, len(shown)):
                    ra, rb = shown[i], shown[j]
                    if ra["layer"] != rb["layer"] or ra["text"] == rb["text"] and abs(ra["ink"][0] - rb["ink"][0]) < 8:
                        continue
                    if ra["path"].startswith(rb["path"] + "/") or rb["path"].startswith(ra["path"] + "/"):
                        continue
                    ix, iy = _overlap(ra["ink"], rb["ink"])
                    if ix * s > 1 and iy * s > 1:
                        found.append({"canvas": canvas, "screen": screen, "text": ra["text"], "size": ra["size"],
                                      "why": ["ink overlaps '%s' (%dx%d px)" % (rb["text"][:30], ix * s, iy * s)], "path": ra["path"]})
    return found


def sheets(base: str = "") -> None:
    root = OUT / base if base else OUT
    out = root / "sheets"
    pre = (base + "/") if base else ""
    for screen in SCREENS:
        for canvas in CANVASES:
            b, a = root / "before" / f"{screen}_{canvas}.png", root / "after" / f"{screen}_{canvas}.png"
            if b.exists() and a.exists() and canvas == "640x960":
                side_by_side(b, a, out / f"{screen}_640x960_before_after.png", ("BEFORE  %s %s" % (screen, canvas), "AFTER 40/80/120"))
    for screen in ALT_SCREENS if not base else []:
        main = OUT / "after" / f"{screen}_640x960.png"
        for alt, label in (("alt_a", "ALT (a): 48-group at 80"), ("alt_b", "ALT (b): headings at 120")):
            p = OUT / alt / f"{screen}_640x960.png"
            if main.exists() and p.exists():
                side_by_side(main, p, out / f"{screen}_640x960_{alt}.png", ("AFTER 40/80/120", label))
    (root / "overflow.json").write_text(json.dumps(overflow(pre + "after"), indent=1), encoding="utf-8")
    (root / "overflow_before.json").write_text(json.dumps(overflow(pre + "before"), indent=1), encoding="utf-8")


def zoom(phase: str, screen: str, text_prefix: str, k: int) -> None:
    """4x nearest zoom of one body line at 640x960 and its stroke-evenness score.

    The crop is the label's first line (its ink rect, one line tall, 3 px of
    margin) so no glyph is cut; runs touching the crop edge are left out."""
    data = _rows(phase, screen, "640x960")
    row = next(r for r in data["labels"] if r["text"].startswith(text_prefix))
    s = data["final_scale"]
    x, y, w, h = row["ink"]
    line_h = h / max(1, row["lines"])
    box = (int(x * s) - 3, int(y * s), int((x + w) * s) + 3, int((y + line_h) * s))
    img = Image.open(OUT / phase / f"{screen}_640x960.png").convert("RGB")
    crop = img.crop(box)
    sheet_dir = OUT / phase.rsplit("/", 1)[0] / "sheets" if "/" in phase else OUT / "sheets"
    sheet_dir.mkdir(parents=True, exist_ok=True)
    tag = phase.rsplit("/", 1)[-1]
    crop.resize((crop.width * 4, crop.height * 4), Image.NEAREST).save(sheet_dir / f"zoom4x_{tag}_{screen}.png")
    colours = Counter(crop.get_flattened_data() if hasattr(crop, "get_flattened_data") else crop.getdata())
    bg = colours.most_common(1)[0][0]
    ink = max(colours, key=lambda c: sum(abs(c[i] - bg[i]) for i in range(3)) * (colours[c] > 20))
    hist = stroke_runs(img, box, ink, 40, skip_edges=True)
    report = {"phase": phase, "screen": screen, "text": row["text"], "size": row["size"], "drawn_screen_px_per_font_px": row["size"] * s / 16,
              "crop_px": box, "ink": "%02x%02x%02x" % ink, "colours_in_crop": len(colours), "k": k,
              "runs": dict(sorted(hist.items())), "evenness": round(evenness(hist, k), 4)}
    print(json.dumps(report))
    (sheet_dir / f"zoom4x_{tag}_{screen}.json").write_text(json.dumps(report, indent=1), encoding="utf-8")


def label_runs(img: Image.Image, r: dict, s: float) -> tuple:
    """Horizontal and vertical ink runs of one label at 640x960 (screen px).

    The ink colour is the commonest colour far from the commonest (background)
    colour inside the label's visible ink rect; runs touching the crop are
    left out, so a glyph cut by the crop never counts."""
    x, y, w, h = r["ink"]
    cx, cy, cw, ch = r["clip"]
    x0, y0 = max(x, cx), max(y, cy)
    x1, y1 = min(x + w, cx + cw), min(y + h, cy + ch)
    box = (int(x0 * s) - 1, int(y0 * s) - 1, int(x1 * s) + 2, int(y1 * s) + 2)
    if box[2] - box[0] < 3 or box[3] - box[1] < 3:
        return Counter(), Counter()
    crop = img.crop(box)
    cols = Counter(crop.get_flattened_data() if hasattr(crop, "get_flattened_data") else crop.getdata())
    bg = cols.most_common(1)[0][0]
    ink = None
    if r.get("ink_color"):
        hx = r["ink_color"]
        want = tuple(int(hx[i:i + 2], 16) for i in (0, 2, 4))
        near = [(n, c) for c, n in cols.items() if sum(abs(c[i] - want[i]) for i in range(3)) <= 24]
        ink = max(near)[1] if near else None
    if ink is None:
        far = [(n, c) for c, n in cols.items() if sum(abs(c[i] - bg[i]) for i in range(3)) > 90]
        if not far:
            return Counter(), Counter()
        ink = max(far)[1]
    W, H = crop.size
    px = crop.load()
    m = [[sum(abs(px[i, j][k] - ink[k]) for k in range(3)) <= 24 for i in range(W)] for j in range(H)]
    # A bar or divider under the text (an HP fill, the header rule) inks a
    # whole row: blank those rows so only glyphs are measured.
    for j in range(H):
        if sum(m[j]) >= 0.9 * W:
            m[j] = [False] * W
    hr, vr = Counter(), Counter()
    for j in range(H):
        n = 0
        for i in range(W + 1):
            if i < W and m[j][i]:
                n += 1
            elif n:
                if i - n > 0 and i < W:
                    hr[n] += 1
                n = 0
    for i in range(W):
        n = 0
        for j in range(H + 1):
            if j < H and m[j][i]:
                n += 1
            elif n:
                if j - n > 0 and j < H:
                    vr[n] += 1
                n = 0
    return hr, vr


def evenness_all(phase: str) -> dict:
    """Per drawn size at 640x960: the share of ink runs that are a whole
    multiple of k (screen px per font pixel), columns (horizontal runs) and
    rows, and every label with an odd run."""
    by_size = {}
    uneven = []
    for screen in SCREENS:
        data = _rows(phase, screen, "640x960")
        if not data["labels"]:
            continue
        s = data["final_scale"]
        img = Image.open(OUT / phase / f"{screen}_640x960.png").convert("RGB")
        for r in data["labels"]:
            if screen in SCREEN_LAYER and r.get("layer") != SCREEN_LAYER[screen]:
                continue
            drawn = r["size"] * r["scale"]
            k = drawn * s / 16.0
            if abs(k - round(k)) > 0.01 or round(k) < 1:
                key = "%g (k %.2f)" % (drawn, k)
                kk = None
            else:
                key = "%d" % round(drawn)
                kk = int(round(k))
            hr, vr = label_runs(img, r, s)
            if not hr:
                continue
            e = by_size.setdefault(key, {"labels": 0, "h_runs": 0, "h_even": 0, "v_runs": 0, "v_even": 0, "uneven_labels": 0})
            e["labels"] += 1
            e["h_runs"] += sum(hr.values())
            e["v_runs"] += sum(vr.values())
            if kk:
                he = sum(v for n, v in hr.items() if n % kk == 0)
                ve = sum(v for n, v in vr.items() if n % kk == 0)
                e["h_even"] += he
                e["v_even"] += ve
                if he < sum(hr.values()) or ve < sum(vr.values()):
                    e["uneven_labels"] += 1
                    uneven.append({"screen": screen, "text": r["text"][:40], "size": key, "x_frac": round((r["ink"][0] * s) % 1, 2),
                                   "odd_h": {n: v for n, v in hr.items() if n % kk}, "odd_v": {n: v for n, v in vr.items() if n % kk}})
    for e in by_size.values():
        e["columns_even"] = round(e["h_even"] / e["h_runs"], 4) if e["h_runs"] else None
        e["rows_even"] = round(e["v_even"] / e["v_runs"], 4) if e["v_runs"] else None
    return {"by_size": by_size, "uneven": uneven}


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "capture":
        capture(sys.argv[2], sys.argv[3:])
    elif cmd == "sheets":
        sheets(sys.argv[2] if len(sys.argv) > 2 else "")
    elif cmd == "evenness":
        res = evenness_all(sys.argv[2])
        out = OUT / sys.argv[2] / "evenness.json"
        out.write_text(json.dumps(res, indent=1), encoding="utf-8")
        for k, e in sorted(res["by_size"].items()):
            print(k, {x: e[x] for x in ("labels", "uneven_labels", "columns_even", "rows_even")})
    elif cmd == "zoom":
        zoom(sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5]))
