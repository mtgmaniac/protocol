#!/usr/bin/env python3
"""Component-contract gate (Polish Build A, Task 2 — the border-noise fix).

The six standard components (PixelUI.component_style: normal_card /
selected_card / enemy_card / reward_card / modal / major_event) are the ONLY
panel-frame language. PixelUI (scripts/ui/pixel_ui.gd) is the single source of
truth for stylebox construction; strong cyan borders are legal only on
Selected, strong gold only on Major-event.

WHAT THIS GATE ENFORCES (mechanical subset):
  1. No .tscn under scenes/ declares a StyleBox SubResource (scene-local
     panel/frame overrides are banned; the tree is currently clean — this
     rule keeps it that way).
  2. No StyleBoxFlat.new() / StyleBoxTexture.new() / StyleBoxEmpty is
     constructed outside scripts/ui/pixel_ui.gd (StyleBoxEmpty is allowed —
     it renders nothing, so it can't add border noise).
  3. Outside pixel_ui.gd, the panel-style factories (make_hard_style /
     make_panel_style / style_panel) must not receive a strong accent
     (DT_CYAN, DT_CYAN_BRIGHT, GOLD_ACCENT) or ANY Color literal (hex or
     component form). Strong accents come only from
     component_style("selected_card"/"major_event"); colors come only from
     PixelUI tokens.

NOT gate-enforceable (needs eyes — the component usage map is the record):
  - Whether a surface picked the RIGHT component of the six.
  - A strong token laundered through a local const before the style call
    (migration removed the known cases; this gate catches the common
    regression of typing a token straight into a style call).

Exit 0 = pass, 1 = violations.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCENES = ROOT / "scenes"
SCRIPTS = ROOT / "scripts"
PIXEL_UI = SCRIPTS / "ui" / "pixel_ui.gd"

STRONG_TOKENS = ["DT_CYAN_BRIGHT", "DT_CYAN", "GOLD_ACCENT"]
_FACTORY_CALL = re.compile(
    r"(?:make_hard_style|make_panel_style|style_panel)\s*\((?P<args>[^()]*(?:\([^()]*\)[^()]*)*)\)",
    re.S,
)
# Color literals and named color constants are banned in factory args — except
# Color.TRANSPARENT, which means "no color", not a color choice.
_COLOR_LITERAL = re.compile(r"\bColor\s*\(|\bColor\.(?!TRANSPARENT\b)[A-Z]")


def _gd_files():
    for gd in SCRIPTS.rglob("*.gd"):
        if gd == PIXEL_UI or "debug" in gd.parts:
            continue
        yield gd


def check_tscn_styleboxes() -> list[str]:
    problems = []
    for tscn in SCENES.rglob("*.tscn"):
        for i, line in enumerate(tscn.read_text(encoding="utf-8").splitlines(), 1):
            if 'type="StyleBox' in line:
                problems.append(
                    f"[scene-stylebox] {tscn.relative_to(ROOT)}:{i}: scene-local StyleBox "
                    f"declared — panels reference the six PixelUI components instead")
    return problems


def check_raw_construction() -> list[str]:
    problems = []
    pat = re.compile(r"StyleBox(?:Flat|Texture)\.new\(")
    for gd in _gd_files():
        for i, line in enumerate(gd.read_text(encoding="utf-8").splitlines(), 1):
            if pat.search(line):
                problems.append(
                    f"[raw-stylebox] {gd.relative_to(ROOT)}:{i}: StyleBox constructed outside "
                    f"PixelUI — use component_style / a PixelUI helper")
    return problems


def check_strong_accents() -> list[str]:
    problems = []
    for gd in _gd_files():
        text = gd.read_text(encoding="utf-8")
        for m in _FACTORY_CALL.finditer(text):
            args = m.group("args")
            line_no = text.count("\n", 0, m.start()) + 1
            for tok in STRONG_TOKENS:
                if re.search(rf"\b{tok}\b", args):
                    problems.append(
                        f"[strong-border] {gd.relative_to(ROOT)}:{line_no}: {tok} passed to a "
                        f"panel factory — strong accents only via component_style "
                        f"(selected_card / major_event)")
                    break
            else:
                if _COLOR_LITERAL.search(args):
                    problems.append(
                        f"[color-literal] {gd.relative_to(ROOT)}:{line_no}: Color literal in a "
                        f"panel factory call — colors come from PixelUI tokens "
                        f"(INVARIANTS #7)")
    return problems


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    problems = check_tscn_styleboxes() + check_raw_construction() + check_strong_accents()
    for p in problems:
        print("  " + p)
    if problems:
        print(f"[COMPONENT_CONTRACT] FAIL - {len(problems)} violation(s)")
        return 1
    print("[COMPONENT_CONTRACT] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
