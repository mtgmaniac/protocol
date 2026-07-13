#!/usr/bin/env python3
"""Doc ⇄ project.godot consistency gate (2026-07-12).

The lesson of the whole portrait week: a duplicated constant is a bug with a
delay fuse. One true value (in TRUTH.md / project.godot) and four stale copies
elsewhere is exactly the 320×486 and 450×1000 failure mode. So we stop trusting
prose to stay in sync and CHECK it: this gate reads the LIVE values out of
`project.godot` and fails if any canonical/reference doc states a contradicting
value.

Enforced today:
  * preview + internal resolution (window override / viewport, from [display])
  * preview scale (window_width_override / viewport_width)
  * main scene basename (run/main_scene)

Scope: the docs agents load as truth. Historical/meta trees (docs/archive,
docs/wiki, docs/audit) are intentionally NOT scanned — they legitimately quote
old values while narrating a fix. Lines carrying a historical marker
(old / was / masked / until / superseded / …) are skipped everywhere.

Prints "[DOC_CONSISTENCY] PASS" only when clean; the verify gate keys on that.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GODOT_PROJECT = ROOT / "project.godot"

# Docs that state CURRENT truth (relative to repo root).
SCOPED_DOCS = [
    "CLAUDE.md",
    "docs/CLAUDE.md",
    "docs/TRUTH.md",
    "docs/INVARIANTS.md",
    "docs/AI_AGENT_GAME_REFERENCE.md",
    "docs/BATTLE_UI_V2_SPEC.md",
    "docs/GDD.md",
    "docs/ROADMAP.md",
    "offline-bundle/GROUND_TRUTH.md",
    "offline-bundle/CODEBASE_MAP.md",
]

# A line about the past is allowed to name an old value.
HISTORICAL = re.compile(
    r"\b(old|older|was|were|formerly|former|masked|until|previously|"
    r"historic|no longer|used to|deprecated|legacy|superseded|stale|earlier|reverted)\b",
    re.IGNORECASE,
)
# Portrait-window aspects (e.g. 328×380) are a DIFFERENT concept from the
# display resolution; never treat those tokens as a screen size.
PORTRAIT_CTX = re.compile(r"portrait|region|HERO_PORTRAIT|aspect|thumb|token|tile|card frame", re.IGNORECASE)

# Lines that are actually talking about the display/window resolution.
DISPLAY_CTX = re.compile(r"preview|desktop|viewport|internal|authored layout|window override|render", re.IGNORECASE)

RES_TOKEN = re.compile(r"(\d{3,4})\s*[x×X]\s*(\d{3,4})")
SCALE_TOKEN = re.compile(r"(\d\.\d{2,4})\s*[x×]?")
TSCN_TOKEN = re.compile(r"([A-Za-z0-9_]+)\.tscn")


def read_godot_values() -> dict:
    text = GODOT_PROJECT.read_text(encoding="utf-8")

    def grab(key: str) -> str:
        m = re.search(rf"^{re.escape(key)}=(.+)$", text, re.MULTILINE)
        return m.group(1).strip().strip('"') if m else ""

    vw = int(grab("window/size/viewport_width") or 0)
    vh = int(grab("window/size/viewport_height") or 0)
    ww = int(grab("window/size/window_width_override") or 0)
    wh = int(grab("window/size/window_height_override") or 0)
    main_scene = grab("run/main_scene")  # res://scenes/ui/MainMenu.tscn
    main_stem = Path(main_scene.replace("res://", "")).stem if main_scene else ""
    scale = round(ww / vw, 4) if vw else 0.0
    return {
        "viewport": f"{vw}x{vh}",
        "preview": f"{ww}x{wh}",
        "allowed_res": {f"{vw}x{vh}", f"{ww}x{wh}"},
        "scale": scale,
        "main_stem": main_stem,
    }


def norm_res(a: str, b: str) -> str:
    return f"{int(a)}x{int(b)}"


def check() -> list:
    v = read_godot_values()
    violations = []

    for rel in SCOPED_DOCS:
        p = ROOT / rel
        if not p.exists():
            continue
        for i, raw in enumerate(p.read_text(encoding="utf-8").splitlines(), start=1):
            line = raw.strip()
            if not line or HISTORICAL.search(line):
                continue

            # --- resolution tokens (only when the line is about the display) ---
            if DISPLAY_CTX.search(line) and not PORTRAIT_CTX.search(line):
                for a, b in RES_TOKEN.findall(line):
                    tok = norm_res(a, b)
                    if tok not in v["allowed_res"]:
                        violations.append(
                            f"{rel}:{i}: display resolution `{a}x{b}` disagrees with "
                            f"project.godot (viewport {v['viewport']}, preview {v['preview']}) "
                            f"— line: {line[:90]}"
                        )

            # --- preview scale (catch the old 0.42 / 0.4167 class) ---
            if re.search(r"preview", line, re.IGNORECASE) and re.search(r"scale|[×x]\b|≈|=", line):
                for tok in SCALE_TOKEN.findall(line):
                    val = float(tok)
                    if 0.1 <= val <= 0.95 and abs(val - v["scale"]) > 0.001:
                        violations.append(
                            f"{rel}:{i}: preview scale `{tok}` disagrees with project.godot "
                            f"({v['scale']} = {v['preview'].split('x')[0]}/{v['viewport'].split('x')[0]}) "
                            f"— line: {line[:90]}"
                        )

            # --- main scene basename ---
            if re.search(r"main[\s_]*scene", line, re.IGNORECASE):
                for stem in TSCN_TOKEN.findall(line):
                    if v["main_stem"] and stem != v["main_stem"]:
                        violations.append(
                            f"{rel}:{i}: main scene `{stem}.tscn` disagrees with "
                            f"project.godot run/main_scene ({v['main_stem']}.tscn) "
                            f"— line: {line[:90]}"
                        )
    return violations


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    v = read_godot_values()
    print(
        f"── doc ⇄ project.godot: preview {v['preview']} ({v['scale']}x), "
        f"viewport {v['viewport']}, main {v['main_stem']}.tscn",
        flush=True,
    )
    violations = check()
    if violations:
        print("   FAIL — docs disagree with project.godot:")
        for msg in violations:
            print(f"     • {msg}")
        print(
            "\n   A project.godot value has one true home. Fix the doc(s) above to "
            "match, or\n   if the line is describing history, add a marker word "
            "(old/was/masked/…).",
        )
        return 1
    print("   [DOC_CONSISTENCY] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
