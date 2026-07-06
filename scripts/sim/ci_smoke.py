#!/usr/bin/env python3
"""Balance CI smoke — nightly regression against an accepted baseline (Package E).

Runs a FIXED sim batch (deterministic → the metrics are exact), computes the
balance metrics, and diffs them against scripts/sim/baseline.json. Any balance
shift beyond tolerance exits non-zero — so a data/rule change that silently
creates an outlier gets caught the next morning, turning balance into a
regression test.

  python scripts/sim/ci_smoke.py                 # diff vs baseline (CI)
  python scripts/sim/ci_smoke.py --runs 2000     # heavier nightly
  python scripts/sim/ci_smoke.py --update-baseline   # accept current as baseline

Because the sim is byte-deterministic and the batch config is pinned, an
UNCHANGED tree reproduces the baseline exactly; tolerances only absorb trivial
float noise.
"""
import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASELINE = Path(__file__).resolve().parent / "baseline.json"

# Pinned CI batch config — changing any of these invalidates the baseline.
CI_POLICY = "l1"
CI_SEED_BASE = 900000
CI_RUNS = 300

# Regression tolerances.
TOL_OVERALL = 0.02     # overall clear-rate drift (pp)
TOL_OP = 0.05          # per-op clear-rate drift
TOL_LIFT = 0.30        # content log-odds lift drift
TOL_HERO = 0.05        # per-hero clear-rate drift


def build_metrics(runs: int) -> dict:
    # Batch into results/ (the sim writes reliably to project-relative paths;
    # a system-temp dir outside the project breaks its FileAccess).
    name = "_ci_smoke"
    out_dir = ROOT / "results" / name
    if out_dir.exists():
        shutil.rmtree(out_dir)
    subprocess.run([sys.executable, str(ROOT / "scripts/sim/batch.py"),
                    "--name", name, "--runs", str(runs), "--policy", CI_POLICY,
                    "--seed-base", str(CI_SEED_BASE)],
                   check=True)
    out = subprocess.run([sys.executable, str(ROOT / "scripts/sim/analyze.py"),
                          str(out_dir), "--metrics"],
                         check=True, capture_output=True, text=True)
    shutil.rmtree(out_dir, ignore_errors=True)
    return json.loads(out.stdout)


def diff(cur: dict, base: dict) -> list:
    flags = []
    if abs(cur["overall_clear"] - base["overall_clear"]) > TOL_OVERALL:
        flags.append(f"overall clear {base['overall_clear']:.1%} → {cur['overall_clear']:.1%}")
    for op, rate in cur["clear_by_op"].items():
        b = base["clear_by_op"].get(op)
        if b is not None and abs(rate - b) > TOL_OP:
            flags.append(f"op {op} clear {b:.1%} → {rate:.1%}")
    for h, rate in cur["clear_by_hero"].items():
        b = base["clear_by_hero"].get(h)
        if b is not None and abs(rate - b) > TOL_HERO:
            flags.append(f"hero {h} clear {b:.1%} → {rate:.1%}")
    cur_lift, base_lift = cur.get("content_lift", {}), base.get("content_lift", {})
    for c in set(cur_lift) | set(base_lift):
        cv, bv = cur_lift.get(c), base_lift.get(c)
        if cv is None:
            flags.append(f"content {c} dropped from the fit (was lift {bv:+.2f})")
        elif bv is None:
            if abs(cv) > TOL_LIFT:
                flags.append(f"content {c} NEW in the fit at lift {cv:+.2f}")
        elif abs(cv - bv) > TOL_LIFT:
            flags.append(f"content {c} lift {bv:+.2f} → {cv:+.2f}")
    return flags


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    ap = argparse.ArgumentParser(description="Balance CI smoke vs baseline")
    ap.add_argument("--runs", type=int, default=CI_RUNS)
    ap.add_argument("--update-baseline", action="store_true")
    args = ap.parse_args()

    cur = build_metrics(args.runs)

    if args.update_baseline:
        BASELINE.write_text(json.dumps(cur, indent=2))
        print(f"[CI] baseline updated: {BASELINE} "
              f"({cur['runs']} runs, overall clear {cur['overall_clear']:.1%})")
        return 0

    if not BASELINE.exists():
        print(f"[CI] no baseline at {BASELINE}; run --update-baseline first", file=sys.stderr)
        return 2
    base = json.loads(BASELINE.read_text())
    if cur["runs"] != base["runs"]:
        print(f"[CI] note: run count differs (baseline {base['runs']}, now {cur['runs']}); "
              "clear rates comparable, exact match not expected.")
    flags = diff(cur, base)
    if flags:
        print(f"[CI] BALANCE REGRESSION — {len(flags)} metric(s) moved beyond tolerance:")
        for f in flags:
            print(f"  ⚠ {f}")
        print("\nIf intended, re-accept with: python scripts/sim/ci_smoke.py --update-baseline")
        return 1
    print(f"[CI] PASS — {cur['runs']} runs, overall clear {cur['overall_clear']:.1%}, "
          "no metric moved beyond tolerance.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
