#!/usr/bin/env python3
"""Pool-draw choke point gate (Build F).

DataManager.pool_ids is the ONE sanctioned enumeration of the item tables —
it owns the unlocked-bucket filter, and call sites cannot opt out (same
architecture rule as make_integer_icon and the font loader: one owner, or
the next grant path silently bypasses the gate).

This scan bans, in every .gd outside scripts/autoloads/DataManager.gd:
  - the token `DataManager.items` (raw table access — iteration or indexing);
  - raw loads of the three item table files (a file-level bypass).

Single-id lookups stay on DataManager.get_item — lookups are not pool draws.
Pre-Build-F code FAILS this scan (GameState.gd held four raw iterations).
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPTS = ROOT / "scripts"
OWNER = SCRIPTS / "autoloads" / "DataManager.gd"

# Read-only DIAGNOSTIC sweeps that must see every raw entry (all fields, no
# unlock filter — they report, they never draw). Each exemption is named, not
# a directory: a new harness that wants raw tables gets reviewed here.
RAW_FILE_EXEMPT = {
    SCRIPTS / "debug" / "rollbuff_scope_audit.gd",  # pip-rendering report over raw effect fields
}

RAW_TABLE = re.compile(r"DataManager\.items\b")
RAW_FILES = re.compile(r"data/raw/(items|gear|relics)\.data\.json")


def _gd_files():
    for path in SCRIPTS.rglob("*.gd"):
        if path.resolve() == OWNER.resolve():
            continue
        yield path


def main() -> int:
    problems = []
    for path in _gd_files():
        text = path.read_text(encoding="utf-8", errors="replace")
        for line_no, line in enumerate(text.splitlines(), 1):
            if RAW_TABLE.search(line):
                problems.append(
                    f"{path.relative_to(ROOT)}:{line_no}: raw DataManager.items access - route through DataManager.pool_ids"
                )
            if RAW_FILES.search(line) and path.resolve() not in {p.resolve() for p in RAW_FILE_EXEMPT}:
                problems.append(
                    f"{path.relative_to(ROOT)}:{line_no}: raw item-table file load - DataManager owns the item tables"
                )
    for problem in problems:
        print(problem)
    if problems:
        print(f"[POOL_CHOKE] FAIL - {len(problems)} violation(s)")
        return 1
    print("[POOL_CHOKE] PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
