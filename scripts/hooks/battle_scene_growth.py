#!/usr/bin/env python3
"""pre-commit hook body: module growth warnings (never blocks).

The architecture review (docs/ARCHITECTURE_REVIEW_JUL2026.md) ordered the
battle-scene god object SPLIT, not grown — and the extracted modules must not
quietly become god objects themselves. If a commit pushes a watched file past
its recorded high-water mark, print a loud warning telling the author to
extract instead. Warning only — exit 0 always. RAISING a mark here requires
BASELINE-APPROVED-BY-KEV in the commit message (threshold_guard, INVARIANTS
#13); lowering after a split is always free.
"""
import subprocess
import sys

# High-water marks (INVARIANTS #13: raises need the KEV token; lowering free).
HIGH_WATER_LINES = 2610          # scripts/battle/battle_scene.gd (post-extraction, 2026-07-06)
PROTOCOL_ACTIONS_HIGH_WATER = 971  # scripts/battle/protocol_actions.gd (at extraction, 2026-07-06)

WATCHED = [
    ("scripts/battle/battle_scene.gd", HIGH_WATER_LINES),
    ("scripts/battle/protocol_actions.gd", PROTOCOL_ACTIONS_HIGH_WATER),
]


def main() -> int:
    staged = subprocess.run(["git", "diff", "--cached", "--name-only"],
                            capture_output=True, text=True,
                            encoding="utf-8", errors="replace").stdout.split()
    for target, mark in WATCHED:
        if target not in staged:
            continue
        content = subprocess.run(["git", "show", f":{target}"],
                                 capture_output=True, text=True,
                                 encoding="utf-8", errors="replace").stdout
        lines = content.count("\n")
        if lines > mark:
            print(f"[GROWTH] WARNING: {target} is {lines} lines (high-water mark {mark}).")
            print("[GROWTH] The architecture review says these files get SPLIT, not grown —")
            print("[GROWTH] extract into a module instead. Committing anyway (warning only);")
            print("[GROWTH] raising the mark in scripts/hooks/battle_scene_growth.py needs")
            print("[GROWTH] BASELINE-APPROVED-BY-KEV in the commit message (INVARIANTS #13).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
