"""Crisp text step 3b (2026-10-20): overflow / readability captures and sheets.

  python scripts/checks/text_overflow.py capture <phase> [--root <project>] [screen ...]
      Shoots each screen on both canvases into
      debug_artifacts/overflow/<phase>/<screen>_<canvas>.png (+ .json, the
      text_size_capture.gd text rows). --root runs another checkout (the
      "before" worktree); the captures still land in this checkout.
  python scripts/checks/text_overflow.py sheets
      Before/after sheets per screen and canvas, and overflow_<phase>.json:
      every text row whose ink leaves its node or box, or is trimmed.
  python scripts/checks/text_overflow.py zoom <phase> <screen> <text prefix>
      4x nearest zoom of one line at 640x960 and its stroke-evenness score.

Godot: GODOT_BIN (a console exe with the main exe beside it). Captures run
windowed with a scratch APPDATA, so the dev profile is never touched.
"""
import json
import os
import subprocess
import sys
import tempfile
from collections import Counter
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import text_40_80_120 as t48  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "debug_artifacts" / "overflow"
GODOT = t48.GODOT
SCREENS = ["squad", "squad_info", "briefing", "inspect", "evolution", "evolution_all", "unlock",
           "help_units", "reward", "run_end", "battle"]
CANVASES = t48.CANVASES
POPUP_LAYER = {"inspect": "inspect_popup", "help_units": "help_menu", "help_settings": "help_menu"}


def capture(phase: str, args: list) -> None:
    project = ROOT
    if "--root" in args:
        i = args.index("--root")
        project = Path(args[i + 1])
        args = args[:i] + args[i + 2:]
    screens = args or SCREENS
    appdata = tempfile.mkdtemp(prefix="overflow_appdata_")
    env = dict(os.environ, APPDATA=appdata)
    for canvas in CANVASES:
        for screen in screens:
            png = OUT / phase / f"{screen}_{canvas}.png"
            cmd = [GODOT, "--path", str(project), "-s", "res://scripts/debug/text_size_capture.gd",
                   f"--capture-window={canvas}", f"--tsc-screen={screen}", f"--tsc-out={png.as_posix()}"]
            try:
                res = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=150, encoding="utf-8", errors="replace")
                line = [l for l in res.stdout.splitlines() if "[TEXT_SIZE_CAPTURE]" in l]
                errs = [l for l in (res.stdout + res.stderr).splitlines() if "SCRIPT ERROR" in l or "Parse Error" in l]
                print(phase, canvas, screen, line[-1] if line else "NO OUTPUT rc=%s" % res.returncode, flush=True)
                for e in errs[:5]:
                    print("   ", e)
            except subprocess.TimeoutExpired:
                print(phase, canvas, screen, "TIMEOUT", flush=True)


def _rows(phase: str, screen: str, canvas: str) -> dict:
    p = OUT / phase / f"{screen}_{canvas}.json"
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else {"labels": []}


def overflow(phase: str) -> list:
    """Text whose ink leaves its node or its box, or that is trimmed, in screen px."""
    found = []
    for canvas in CANVASES:
        for screen in SCREENS:
            data = _rows(phase, screen, canvas)
            s = data.get("final_scale", 1.0) if canvas == "640x960" else 1.0
            for r in data["labels"]:
                if screen in POPUP_LAYER and r["layer"] != POPUP_LAYER[screen]:
                    continue
                ox, oy = t48._overlap(r["ink"], r["clip"])
                if ox <= 0 or oy <= 0:
                    continue
                why = []
                if not r["wraps"] and r["text_w"] > r["inner_w"] + 1.0:
                    why.append(("trimmed: %d of %d px shown" if r["trims"] else "wider than its node by %d px") %
                               ((r["inner_w"] * s, r["text_w"] * s) if r["trims"] else ((r["text_w"] - r["inner_w"]) * s,)))
                if r["content_h"] > r["inner_h"] + 1.0:
                    why.append("taller than its node by %d px" % ((r["content_h"] - r["inner_h"]) * s))
                if r["box_rect"] and not t48._inside(r["ink"], r["box_rect"]):
                    why.append("ink leaves its box (%s)" % r["box"].split("/")[-1])
                if why:
                    found.append({"canvas": canvas, "screen": screen, "text": r["text"], "font": r["font"],
                                  "size": r["size"], "why": why, "path": r["path"]})
    return found


def sheets() -> None:
    out = OUT / "sheets"
    for screen in SCREENS:
        for canvas in CANVASES:
            b, a = OUT / "before" / f"{screen}_{canvas}.png", OUT / "after" / f"{screen}_{canvas}.png"
            if b.exists() and a.exists():
                t48.side_by_side(b, a, out / f"{screen}_{canvas}.png", ("BEFORE 42d684b  %s %s" % (screen, canvas), "AFTER step 3b"))
    for phase in ("before", "after"):
        (OUT / f"overflow_{phase}.json").write_text(json.dumps(overflow(phase), indent=1), encoding="utf-8")


def zoom(phase: str, screen: str, prefix: str) -> None:
    data = _rows(phase, screen, "640x960")
    row = next(r for r in data["labels"] if r["text"].startswith(prefix))
    s = data["final_scale"]
    k = row["size"] * row["scale"] * s / 16.0
    x, y, w, h = row["ink"]
    line_h = h / max(1, row["lines"])
    box = (int(x * s) - 3, int(y * s), int((x + w) * s) + 3, int((y + line_h) * s))
    img = Image.open(OUT / phase / f"{screen}_640x960.png").convert("RGB")
    crop = img.crop(box)
    (OUT / "sheets").mkdir(parents=True, exist_ok=True)
    name = "zoom4x_%s_%s" % (phase, screen)
    crop.resize((crop.width * 4, crop.height * 4), Image.NEAREST).save(OUT / "sheets" / (name + ".png"))
    colours = Counter(crop.get_flattened_data() if hasattr(crop, "get_flattened_data") else crop.getdata())
    bg = colours.most_common(1)[0][0]
    want = row.get("ink_color", "")
    ink = None
    if want:
        target = tuple(int(want[i:i + 2], 16) for i in (0, 2, 4))
        near = [(n, c) for c, n in colours.items() if sum(abs(c[i] - target[i]) for i in range(3)) <= 24]
        ink = max(near)[1] if near else None
    if ink is None:
        ink = max(colours, key=lambda c: sum(abs(c[i] - bg[i]) for i in range(3)) * (colours[c] > 20))
    hist = t48.stroke_runs(img, box, ink, 40, skip_edges=True)
    kk = int(round(k))
    report = {"phase": phase, "screen": screen, "text": row["text"], "font": row["font"], "size": row["size"],
              "screen_px_per_font_px": round(k, 4), "crop_px": box, "ink": "%02x%02x%02x" % ink, "k": kk,
              "runs": dict(sorted(hist.items())), "evenness": round(t48.evenness(hist, kk), 4)}
    print(json.dumps(report))
    (OUT / "sheets" / (name + ".json")).write_text(json.dumps(report, indent=1), encoding="utf-8")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "capture":
        capture(sys.argv[2], sys.argv[3:])
    elif cmd == "sheets":
        sheets()
    elif cmd == "zoom":
        zoom(sys.argv[2], sys.argv[3], sys.argv[4])
