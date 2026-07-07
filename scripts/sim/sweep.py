#!/usr/bin/env python3
"""Balance workbench — knob sweep runner (measurement only).

Sweeps one knob (or a small 2-knob grid) across declared values at a fixed
policy, reusing the UNMODIFIED engine: values are injected per run via the
sim's --tuning seam and never touch data files or shipped constants. Emits a
markdown report + CSV with clear rates per operation and per hero at every
point, deltas vs scripts/sim/baseline.json, and a flag for any per-op rate
inside the 25-40% skilled-clear target band.

  # the worked example: where does hive enter the target band?
  python scripts/sim/sweep.py --name hive_hp --knob enemy_hp_scalar@hive \\
      --values 0.7,0.8,0.9,1.0 --runs 300

  # a 2-knob grid (cartesian product)
  python scripts/sim/sweep.py --name exec_chain --knob execute_bonus \\
      --values 8,12 --knob chain_ratio --values 0.6,0.8 --runs 300

Knobs and ranges are validated against scripts/sim/knobs.json. Determinism:
every point uses the same --seed-base, so runs are seed-matched across points
(a point differs from another ONLY by the knob value). Same command twice →
identical outputs (the sim's own byte-determinism guarantee).
"""
import argparse
import csv
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SIM = Path(__file__).resolve().parent
BASELINE = SIM / "baseline.json"
KNOBS = SIM / "knobs.json"
BAND = (0.25, 0.40)  # skilled-clear target band (TRUTH.md pinned target)

OPS = ["facility", "hive", "veil", "voidCirclet", "stellarMenagerie"]


def load_registry() -> dict:
    reg = json.loads(KNOBS.read_text(encoding="utf-8"))
    return {k["id"]: k for k in reg.get("knobs", [])}


def validate_knob(registry: dict, knob: str, values: list) -> None:
    base = knob.split("@", 1)[0]
    if base not in registry:
        sys.exit(f"[SWEEP] unknown knob '{base}' — declare it in scripts/sim/knobs.json first "
                 f"(known: {', '.join(sorted(registry))})")
    lo, hi = registry[base]["range"]
    for v in values:
        if not (lo <= v <= hi):
            sys.exit(f"[SWEEP] {base}={v} outside declared range [{lo}, {hi}] (knobs.json)")


def run_point(name: str, tuning: str, runs: int, policy: str, seed_base: int, workers: int) -> dict:
    out_dir = ROOT / "results" / name
    if out_dir.exists():
        shutil.rmtree(out_dir)
    cmd = [sys.executable, str(SIM / "batch.py"), "--name", name, "--runs", str(runs),
           "--policy", policy, "--seed-base", str(seed_base)]
    if tuning:
        cmd += ["--tuning", tuning]
    if workers:
        cmd += ["--workers", str(workers)]
    subprocess.run(cmd, check=True)
    out = subprocess.run([sys.executable, str(SIM / "analyze.py"), str(out_dir), "--metrics"],
                         check=True, capture_output=True, text=True)
    shutil.rmtree(out_dir, ignore_errors=True)
    return json.loads(out.stdout)


def fmt_pct(x) -> str:
    return f"{x * 100:.1f}%" if x is not None else "—"


def in_band(x) -> bool:
    return x is not None and BAND[0] <= x <= BAND[1]


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    ap = argparse.ArgumentParser(description="Balance-workbench knob sweep (measurement only)")
    ap.add_argument("--name", required=True, help="sweep name -> results/sweeps/<name>/")
    ap.add_argument("--knob", action="append", required=True,
                    help="knob id, optionally op-qualified: enemy_hp_scalar@hive (repeat for a grid, max 2)")
    ap.add_argument("--values", action="append", required=True,
                    help="comma list of values for the matching --knob (same order)")
    ap.add_argument("--runs", type=int, default=300, help="runs per grid point")
    ap.add_argument("--policy", default="l1", help="l1 (default) or l2")
    ap.add_argument("--seed-base", type=int, default=900000)
    ap.add_argument("--workers", type=int, default=0, help="0 = batch.py default")
    args = ap.parse_args()

    if len(args.knob) != len(args.values) or len(args.knob) > 2:
        sys.exit("[SWEEP] give one --values list per --knob (max 2 knobs)")
    registry = load_registry()
    axes = []
    for knob, values_csv in zip(args.knob, args.values):
        values = [float(v) for v in values_csv.split(",") if v.strip() != ""]
        validate_knob(registry, knob, values)
        axes.append((knob, values))

    baseline = json.loads(BASELINE.read_text(encoding="utf-8"))
    base_ops = baseline.get("clear_by_op", {})

    # Grid points (1 or 2 axes).
    # Knob ids translate to their tuning keys (ability_field knobs carry a
    # long "ability:..." path in the registry; others key by id).
    def tuning_key(knob: str) -> str:
        base, _, qual = knob.partition("@")
        key = registry[base].get("tuning_key", base)
        return f"{key}@{qual}" if qual else key

    points = [[(tuning_key(axes[0][0]), v)] for v in axes[0][1]]
    if len(axes) == 2:
        points = [p + [(tuning_key(axes[1][0]), v2)] for p in points for v2 in axes[1][1]]

    sweep_dir = ROOT / "results" / "sweeps" / args.name
    sweep_dir.mkdir(parents=True, exist_ok=True)
    swept_ops = sorted({k.split("@", 1)[1] for k, _ in [kv for p in points for kv in p] if "@" in k})

    results = []
    for i, point in enumerate(points):
        tuning = ",".join(f"{k}={v:g}" for k, v in point)
        label = " ".join(f"{k}={v:g}" for k, v in point)
        print(f"[SWEEP] point {i + 1}/{len(points)}: {label} ({args.runs} runs, policy {args.policy})")
        metrics = run_point(f"_sweep_{args.name}_{i}", tuning, args.runs, args.policy,
                            args.seed_base, args.workers)
        (sweep_dir / f"point_{i}.json").write_text(json.dumps(
            {"tuning": tuning, "metrics": metrics}, indent=2), encoding="utf-8")
        results.append({"label": label, "tuning": tuning, "metrics": metrics})

    # ── CSV: one row per (point, scope) with clear rates flat ──────────────────
    heroes = sorted(baseline.get("clear_by_hero", {}))
    with open(sweep_dir / "report.csv", "w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(["point", "tuning", "overall"] + [f"op_{o}" for o in OPS] + [f"hero_{h}" for h in heroes])
        for r in results:
            m = r["metrics"]
            w.writerow([r["label"], r["tuning"], f"{m['overall_clear']:.4f}"]
                       + [f"{m['clear_by_op'].get(o, 0):.4f}" for o in OPS]
                       + [f"{m['clear_by_hero'].get(h, 0):.4f}" for h in heroes])

    # ── Markdown report ────────────────────────────────────────────────────────
    lines = [f"# Sweep: {args.name}", "",
             f"Policy **{args.policy}**, {args.runs} runs/point, seed-base {args.seed_base} "
             f"(seed-matched across points). Deltas vs `baseline.json` "
             f"(overall {fmt_pct(baseline['overall_clear'])}). "
             f"`✦` = inside the **25–40% skilled-clear target band**.", ""]
    header = "| point | overall | " + " | ".join(OPS) + " |"
    sep = "|---" * (2 + len(OPS)) + "|"
    lines += [header, sep]
    for r in results:
        m = r["metrics"]
        cells = [r["label"], fmt_pct(m["overall_clear"])]
        for o in OPS:
            cur = m["clear_by_op"].get(o)
            base = base_ops.get(o)
            delta = (cur - base) * 100 if (cur is not None and base is not None) else None
            flag = " ✦" if in_band(cur) else ""
            cells.append(f"{fmt_pct(cur)} ({delta:+.1f}){flag}" if delta is not None else fmt_pct(cur))
        lines.append("| " + " | ".join(cells) + " |")
    lines += ["", "## Per-hero clear rates", ""]
    hero_header = "| point | " + " | ".join(heroes) + " |"
    lines += [hero_header, "|---" * (1 + len(heroes)) + "|"]
    for r in results:
        m = r["metrics"]
        lines.append("| " + r["label"] + " | "
                     + " | ".join(fmt_pct(m["clear_by_hero"].get(h)) for h in heroes) + " |")

    # Band summary for the swept op(s) — the question a sweep exists to answer.
    lines += ["", "## Target-band summary", ""]
    focus_ops = swept_ops if swept_ops else OPS
    for op in focus_ops:
        hits = [r["label"] for r in results if in_band(r["metrics"]["clear_by_op"].get(op))]
        if hits:
            lines.append(f"- **{op}** is inside the 25–40% band at: {', '.join(hits)}")
        else:
            rates = ", ".join(f"{r['label']} → {fmt_pct(r['metrics']['clear_by_op'].get(op))}" for r in results)
            lines.append(f"- **{op}** never enters the 25–40% band across this sweep ({rates})")
    lines += ["", "> Measurement only — no data or engine constants were changed. To SHIP a value,",
              "> commit it as the real constant/data, then the baseline ceremony applies",
              "> (docs/INVARIANTS.md #9)."]
    (sweep_dir / "report.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"[SWEEP] done → {sweep_dir / 'report.md'} (+ report.csv, point_*.json)")
    print("\n".join(lines[-(len(focus_ops) + 4):]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
