#!/usr/bin/env python3
"""Web loader palette gate — the loader's colors are COPIES of PixelUI tokens.

web/shell.html paints before the engine exists, so it cannot read PixelUI; its
colors are literal copies. A duplicated constant is a delay fuse, so this gate
checks every copy instead of trusting it:

  * every hex / rgb() color in the shell's loader <style> block equals a PixelUI
    color token (scripts/ui/pixel_ui.gd: Color("rrggbb") and Color(r, g, b[, a]))
  * project.godot application/boot_splash/bg_color equals PixelUI.DT_FIELD_BG
    (the engine's splash must match the loader it replaces: no flash)

Exit 0 = pass, 1 = drift.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PIXEL_UI = ROOT / "scripts" / "ui" / "pixel_ui.gd"
SHELL = ROOT / "web" / "shell.html"
PROJECT = ROOT / "project.godot"


def pixel_ui_tokens() -> dict[str, str]:
    """rrggbb -> token name, for every literal Color in PixelUI."""
    tokens: dict[str, str] = {}
    src = PIXEL_UI.read_text(encoding="utf-8")
    for name, hexv in re.findall(r'(?:const|static var)\s+(\w+)\s*:?=\s*Color\("([0-9a-fA-F]{6})', src):
        tokens.setdefault(hexv.lower(), name)
    for name, r, g, b in re.findall(
            r'(?:const|static var)\s+(\w+)\s*:?=\s*Color\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)', src):
        hexv = "".join(f"{round(float(c) * 255):02x}" for c in (r, g, b))
        tokens.setdefault(hexv, name)
    return tokens


def main() -> int:
    tokens = pixel_ui_tokens()
    failures: list[str] = []
    html = SHELL.read_text(encoding="utf-8")
    style = re.search(r"<style>(.*?)</style>", html, re.S)
    if style is None:
        failures.append("web/shell.html has no <style> block")
        css = ""
    else:
        # Drop the generated data-URI block: base64 can contain '#'-free hex-looking runs.
        css = re.sub(r"/\* LOADER-ASSETS-BEGIN.*?LOADER-ASSETS-END \*/", "", style.group(1), flags=re.S)
    checked = 0
    for hexv in re.findall(r"#([0-9a-fA-F]{6})\b", css):
        checked += 1
        if hexv.lower() not in tokens:
            failures.append(f"shell.html color #{hexv} is not a PixelUI token")
    for r, g, b in re.findall(r"rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)", css):
        checked += 1
        hexv = f"{int(r):02x}{int(g):02x}{int(b):02x}"
        if hexv not in tokens:
            failures.append(f"shell.html color rgb({r}, {g}, {b}) is not a PixelUI token")
    if checked == 0:
        failures.append("no colors found in the loader style block - the gate is checking nothing")

    project = PROJECT.read_text(encoding="utf-8")
    m = re.search(r"^boot_splash/bg_color=Color\(([^)]*)\)", project, re.M)
    field_bg = next((h for h, n in tokens.items() if n == "DT_FIELD_BG"), None)
    if m is None:
        failures.append("project.godot has no application/boot_splash/bg_color")
    else:
        parts = [float(x) for x in m.group(1).split(",")[:3]]
        hexv = "".join(f"{round(c * 255):02x}" for c in parts)
        if hexv != field_bg:
            failures.append(f"boot_splash/bg_color #{hexv} != PixelUI.DT_FIELD_BG #{field_bg}")

    if failures:
        for f in failures:
            print(f"[WEB_LOADER_PALETTE] FAIL - {f}")
        return 1
    print(f"[WEB_LOADER_PALETTE] PASS ({checked} loader colors + boot splash match PixelUI)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
