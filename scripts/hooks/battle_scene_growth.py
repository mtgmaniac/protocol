#!/usr/bin/env python3
"""pre-commit hook body: battle_scene.gd growth warning (never blocks).

battle_scene.gd is the god object the architecture review
(docs/ARCHITECTURE_REVIEW_JUL2026.md) ordered SPLIT, not grown. If a commit
pushes it past the recorded high-water mark, print a loud warning telling the
author to extract into battle_engine / battle_card_view / a new module instead.
Warning only — exit 0 always; raise the mark here when a split lands.
"""
import subprocess
import sys

TARGET = "scripts/battle/battle_scene.gd"
HIGH_WATER_LINES = 3378  # as of 52e2fa5 (2026-07-06)


def main() -> int:
    staged = subprocess.run(["git", "diff", "--cached", "--name-only"],
                            capture_output=True, text=True,
                            encoding="utf-8", errors="replace").stdout.split()
    if TARGET not in staged:
        return 0
    content = subprocess.run(["git", "show", f":{TARGET}"],
                             capture_output=True, text=True,
                             encoding="utf-8", errors="replace").stdout
    lines = content.count("\n")
    if lines > HIGH_WATER_LINES:
        print(f"[GROWTH] WARNING: {TARGET} is {lines} lines (high-water mark {HIGH_WATER_LINES}).")
        print("[GROWTH] The architecture review (docs/ARCHITECTURE_REVIEW_JUL2026.md) says this")
        print("[GROWTH] file gets SPLIT, not grown — extract into battle_engine.gd,")
        print("[GROWTH] battle_card_view.gd, or a new module. Committing anyway (warning only);")
        print("[GROWTH] if the growth is justified, raise HIGH_WATER_LINES in scripts/hooks/battle_scene_growth.py.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
