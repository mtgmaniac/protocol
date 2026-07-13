#!/usr/bin/env python3
"""The full verification gate, one command (successor kit, 2026-07-06).

Runs every hard gate, then the balance sim, and prints per-op clear-rate deltas
vs scripts/sim/baseline.json as a table. Dumb and loud on purpose.

  python scripts/verify_gate.py                # everything (sim = 300 runs, ~minutes)
  python scripts/verify_gate.py --skip-sim     # hard gates only (fast)
  python scripts/verify_gate.py --runs 100     # quicker, noisier sim

Exit codes: 0 = all green · 1 = a hard gate FAILED · 3 = gates green but a
per-op delta exceeds the ±10-point ceremony line (baseline update requires
Kev's sign-off: commit message must contain BASELINE-APPROVED-BY-KEV — see
docs/INVARIANTS.md #9).
"""
import argparse
import re
import json
import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get(
    "GODOT_BIN",
    "C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe",
)
BASELINE = ROOT / "scripts" / "sim" / "baseline.json"
CEREMONY_PTS = 10.0  # per-op clear-rate points
# Audit pass-count FLOOR: "0 failed" alone can't see tests silently vanishing
# (precedent: the Job-2a extraction cost 6 recordings unnoticed until a manual
# count check). Raise when adding tests; LOWERING needs BASELINE-APPROVED-BY-KEV
# (threshold_guard, inverted polarity — floors loosen downward).
AUDIT_MIN_PASSED = 228

GATES = [
    ("validate-data", ["npm", "run", "validate-data"], "validates against schemas", True),
    # Anti-drift gates (pure-python, fast): a duplicated constant is a bug with a
    # delay fuse — check the copies instead of trusting them to stay in sync.
    ("doc consistency", [sys.executable, str(ROOT / "scripts" / "checks" / "doc_consistency.py")], "[DOC_CONSISTENCY] PASS", False),
    ("knobs contract", [sys.executable, str(ROOT / "scripts" / "checks" / "knobs_contract.py")], "[KNOBS_CONTRACT] PASS", False),
    ("ability audit", [GODOT, "--headless", "--path", str(ROOT), "scenes/debug/AbilityAuditRunner.tscn"], ", 0 failed", False),
    ("flow smoke", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/flow_smoke_test.gd"], "[FLOW_SMOKE] PASS", False),
    ("tutorial smoke", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/tutorial_smoke_test.gd"], "[TUTORIAL_SMOKE] PASS", False),
    ("primer smoke", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/primer_smoke_test.gd"], "[PRIMER_SMOKE] PASS", False),
    ("music smoke", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/music_smoke_test.gd"], "[MUSIC_SMOKE] PASS", False),
    ("freeze regression", [GODOT, "--headless", "--path", str(ROOT), "scenes/debug/freeze_engine_regression.tscn"], "[FREEZE] RESULT: freeze = repeat", False),
    # Batch 4 combat-bug regressions (each launches a live battle).
    ("protocol cancel", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/protocol_cancel_test.gd"], "[PROTOCOL_CANCEL] PASS", False),
    ("die reroll visual", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/die_reroll_visual_test.gd"], "[DIE_REROLL] PASS", False),
    ("auto-target preview", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/auto_target_preview_test.gd"], "[AUTO_PREVIEW] PASS", False),
    ("item burn preview", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/item_burn_preview_test.gd"], "[ITEM_BURN] PASS", False),
]


def run_gate(name: str, cmd: list, needle: str, use_shell: bool) -> bool:
    print(f"── {name} ...", flush=True)
    try:
        proc = subprocess.run(
            " ".join(cmd) if use_shell else cmd,
            shell=use_shell, cwd=ROOT, capture_output=True, text=True, timeout=600,
        )
    except Exception as exc:  # noqa: BLE001 — a dead gate must print, not raise
        print(f"   FAIL ({exc})")
        return False
    out = (proc.stdout or "") + (proc.stderr or "")
    ok = needle in out
    if name == "ability audit":
        ok = ok and "FAIL" not in out.replace("0 failed", "")
        m = re.search(r"Ability Audit Complete: (\d+) passed", out)
        if m and int(m.group(1)) < AUDIT_MIN_PASSED:
            print(f"   FAIL — audit recorded {m.group(1)} passes, floor is {AUDIT_MIN_PASSED}: tests are silently vanishing")
            ok = False
    print(f"   {'PASS' if ok else 'FAIL'}")
    if not ok:
        tail = "\n".join(out.strip().splitlines()[-12:])
        print(f"   ── last output ──\n{tail}")
    return ok


def sim_deltas(runs: int) -> int:
    sys.path.insert(0, str(ROOT / "scripts" / "sim"))
    import ci_smoke  # noqa: E402 — reuse the pinned batch config, one source of truth

    print(f"── balance sim ({runs} runs, pinned ci_smoke config) ...", flush=True)
    cur = ci_smoke.build_metrics(runs)
    base = json.loads(BASELINE.read_text())
    print(f"\n   overall clear: {base['overall_clear']:.4f} -> {cur['overall_clear']:.4f} "
          f"({(cur['overall_clear'] - base['overall_clear']) * 100:+.1f} pts)")
    print(f"   {'operation':<18}{'baseline':>10}{'current':>10}{'delta':>9}")
    beyond = []
    for op in sorted(base["clear_by_op"]):
        b = base["clear_by_op"][op]
        c = cur["clear_by_op"].get(op, 0.0)
        d = (c - b) * 100
        flag = "  <-- BEYOND ±10" if abs(d) > CEREMONY_PTS else ""
        if flag:
            beyond.append(op)
        print(f"   {op:<18}{b:>10.4f}{c:>10.4f}{d:>+8.1f}{flag}")
    if beyond:
        print(
            "\n   ⚠ CEREMONY: per-op drift beyond ±10 points ({}). A human signs off\n"
            "   on drift this size (precedents: voidCirclet +26, freeze=repeat −27.7).\n"
            "   Do NOT run ci_smoke.py --update-baseline; the baseline commit must\n"
            "   contain BASELINE-APPROVED-BY-KEV or the commit-msg hook aborts it."
            .format(", ".join(beyond))
        )
        return 3
    print("   within tolerance.")
    return 0


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    ap = argparse.ArgumentParser(description="Full verification gate + baseline delta table")
    ap.add_argument("--skip-sim", action="store_true")
    ap.add_argument("--runs", type=int, default=300)
    args = ap.parse_args()

    failed = [name for name, cmd, needle, sh in GATES if not run_gate(name, cmd, needle, sh)]
    if failed:
        print(f"\nGATE FAILED: {', '.join(failed)}")
        return 1
    if args.skip_sim:
        print("\nAll hard gates PASS (sim skipped).")
        return 0
    try:
        rc = sim_deltas(args.runs)
    except Exception as exc:  # noqa: BLE001 — a crashed sim leg must FAIL loudly
        print(f"\nGATE FAILED: balance sim crashed ({exc})")
        return 1
    print("\nAll hard gates PASS." + ("" if rc == 0 else " Balance drift needs the ceremony — see above."))
    return rc


if __name__ == "__main__":
    sys.exit(main())
