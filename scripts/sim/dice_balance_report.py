#!/usr/bin/env python3
"""Summarize a PROTOCOL_DICE_METRICS=1 batch against the untouched pin.

The first 300 seeds of a 900000-base random squad/op batch also reproduce the
pinned CI sampling design. Larger samples estimate current operation rates;
they do not eliminate the historical pin's small-sample uncertainty.
"""
import argparse
from collections import Counter, defaultdict
import json
from math import sqrt
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def wilson(wins, n):
    z = 1.96
    p = wins / n
    den = 1 + z * z / n
    center = (p + z * z / (2 * n)) / den
    half = z * sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / den
    return center - half, center + half


def summarize(directory):
    ops, ci, riders = defaultdict(Counter), defaultdict(Counter), defaultdict(Counter)
    errors = []
    for path in sorted(directory.glob("run_*.jsonl")):
        header, end, counts = {}, {}, Counter()
        rounds = 0
        records = 0
        for line in path.read_text(encoding="utf-8").splitlines():
            obj = json.loads(line)
            kind = obj["type"]
            if kind == "run_header":
                header = obj
            elif kind == "run_end":
                end = obj
            elif kind == "round":
                rounds += 1
            elif kind == "frozen_riders":
                records += 1
                counts.update({key: obj[key] for key in ("hero_repeats", "enemy_repeats", "capacitor_triggers", "capacitor_protocol", "echoes", "enemy_reinforcements")})
        if not header or not end or records != rounds:
            errors.append(path.name)
            continue
        op = header["op"]
        win = int(end.get("result") == "victory")
        ops[op].update(runs=1, wins=win)
        if 900000 <= int(header["seed"]) < 900300:
            ci[op].update(runs=1, wins=win)
        riders[op].update(counts)
        riders[op].update(rounds=rounds, runs_with_hero_repeat=int(counts["hero_repeats"] > 0), runs_with_enemy_repeat=int(counts["enemy_repeats"] > 0))
    if errors:
        raise ValueError(f"Incomplete telemetry: {errors[:10]}")
    return ops, ci, riders


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("directory", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    baseline = json.loads((ROOT / "scripts/sim/baseline.json").read_text())
    ops, ci, riders = summarize(args.directory)
    manifest = json.loads((args.directory / "manifest.json").read_text())
    if sum(x["runs"] for x in ops.values()) != manifest["runs"]:
        raise ValueError("Completed runs do not match manifest")
    if manifest["seed_base"] != 900000 or manifest["squad"] != "random" or manifest["op"] != "random" or manifest["policy"] != "l1":
        raise ValueError("Batch does not match pinned sampling design")
    lines = ["# G-24–G-30 balance verification", "", f"Batch: `{args.directory.name}`; L1, seed base 900000, random squads/operations, {manifest['runs']:,} completed runs. Baseline unchanged.", ""]
    for title, group in [("Pinned 300-seed comparison", ci), ("Larger current-rate estimate", ops)]:
        lines += [f"## {title}", "", "| Operation | Runs | Pinned clear | Current clear | Delta (pp) | Current 95% Wilson interval |", "|---|---:|---:|---:|---:|---:|"]
        for op, row in sorted(group.items()):
            rate = row["wins"] / row["runs"]
            b = baseline["clear_by_op"][op]
            lo, hi = wilson(row["wins"], row["runs"])
            lines.append(f"| {op} | {row['runs']} | {b:.2%} | {rate:.2%} | {(rate-b)*100:+.2f} | {lo:.2%}–{hi:.2%} |")
        total = sum(x["runs"] for x in group.values())
        wins = sum(x["wins"] for x in group.values())
        lines += ["", f"Overall: {wins}/{total} = {wins/total:.2%}; pinned {baseline['overall_clear']:.2%}; delta {(wins/total-baseline['overall_clear'])*100:+.2f} pp.", ""]
    lines += ["The 300-seed table measures reproducible drift on the pinned sampling design. The larger table estimates current win rates; the historical pin has only 300 total runs, so its uncertainty remains and the larger table alone cannot establish a ±3-point causal change.", "", "## Frozen-20 rider frequency", "", "Counts below are **resolved frozen-20 turns**, not rolls that were frozen but never acted. Hero repeats each trigger the lifetime-20 rider once. Capacitor and echo counts require the corresponding equipment/relic; enemy reinforcement counts are successful requests, not all eligible summon rolls.", "", "| Operation | Combat rounds | Hero repeats | Runs with hero repeat | Enemy repeats | Capacitor triggers / Protocol | Echoes | Enemy reinforcements |", "|---|---:|---:|---:|---:|---:|---:|---:|"]
    totals = Counter()
    for op, row in sorted(riders.items()):
        totals.update(row)
        lines.append(f"| {op} | {row['rounds']} | {row['hero_repeats']} | {row['runs_with_hero_repeat']}/{ops[op]['runs']} | {row['enemy_repeats']} | {row['capacitor_triggers']} / {row['capacitor_protocol']} | {row['echoes']} | {row['enemy_reinforcements']} |")
    lines += ["", f"Total hero frozen-20 repeats: {totals['hero_repeats']} ({1000*totals['hero_repeats']/totals['rounds']:.2f} per 1,000 combat rounds). Enemy repeats: {totals['enemy_repeats']}. Capacitor: {totals['capacitor_triggers']} grants / {totals['capacitor_protocol']} Protocol. Echoes: {totals['echoes']}. Enemy reinforcement requests: {totals['enemy_reinforcements']}.", ""]
    args.out.write_text("\n".join(lines), encoding="utf-8")
    args.out.with_suffix(".json").write_text(json.dumps({"manifest": manifest, "operations": ops, "ci300": ci, "frozen_riders": riders}, indent=2), encoding="utf-8")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
