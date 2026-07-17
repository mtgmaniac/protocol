#!/usr/bin/env python3
"""Cycle-0 balance dashboard (the reusable per-cycle deliverable format).

Reads the results/cycle0/ batch tree produced by cycle0_batches.py and emits
the dashboard markdown:

  1. Per-op win rate (L1) — Baseline v2, dead-v1 alongside for context only
  2. L1/L2 gap per op (matched seeds) — the boredom dashboard
  3. Bucket-0 vs full-pool delta per op (matched seeds)
  4. Kill curve — run-ending battle distribution per op, comps named under spikes
  5. Turns-per-battle distribution per op (slog detector)
  6. Protocol economy per policy tier (spend timing/totals; hoarding check)
  7. Top-20 content outliers by |lift| (matched-seed A/B arms), flag |lift| >= 5pp
  8. Prediction scorecard (pre-registered guesses, honestly scored)

  python scripts/sim/dashboard_cycle0.py [--root results/cycle0] [-o out.md]

Uses only the stdlib (no pandas) so it runs anywhere the repo runs.
"""
import argparse
import json
import sys
from collections import Counter, defaultdict
from math import sqrt
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

OPS = ["facility", "hive", "veil", "voidCirclet", "stellarMenagerie"]
OP_LABEL = {
    "facility": "Facility", "hive": "Hive", "veil": "Veil",
    "voidCirclet": "Null Synod", "stellarMenagerie": "Accretion",
}
# Dead v1 numbers (context only; recorded historical in TRUTH.md).
V1 = {"overall": 0.283, "facility": 0.592, "hive": 0.085, "veil": 0.169,
      "voidCirclet": 0.404, "stellarMenagerie": 0.083}


def load_run(path: Path) -> dict:
    """One run JSONL -> flat record with everything the dashboard needs."""
    rec = {"result": "", "battles_cleared": 0, "defeat_battle": None,
           "defeat_comp": None, "rounds_by_battle": [], "spends_by_battle": {},
           "protocol_left_by_battle": {}, "op": "", "seed": None,
           "granted": (), "policy": ""}
    comp_by_battle = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        o = json.loads(line)
        t = o.get("type")
        if t == "run_header":
            rec["op"] = o.get("op", "")
            rec["policy"] = o.get("policy", "")
            rec["granted"] = tuple(o.get("granted", []))
        elif t == "battle_start":
            comp_by_battle[o["index"]] = tuple(o.get("comp", []))
        elif t == "round":
            idx = o["index"]
            n = rec["spends_by_battle"].setdefault(idx, [0, 0])  # [count, cost]
            for sp in o.get("spends", []):
                n[0] += 1
                n[1] += int(sp.get("cost", 0))
        elif t == "battle_end":
            idx = o["index"]
            rec["rounds_by_battle"].append((idx, int(o.get("rounds", 0))))
            rec["protocol_left_by_battle"][idx] = int(o.get("protocol_left", 0))
            if o.get("result") == "defeat":
                rec["defeat_battle"] = idx
                rec["defeat_comp"] = comp_by_battle.get(idx)
        elif t == "run_end":
            rec["result"] = o.get("result", "")
            rec["battles_cleared"] = int(o.get("battles_cleared", 0))
    rec["seed"] = int(path.stem.split("_")[1])
    return rec


def load_dir(d: Path) -> list:
    return [load_run(p) for p in sorted(d.glob("run_*.jsonl"))]


def rate(runs: list) -> float:
    return sum(r["result"] == "victory" for r in runs) / len(runs) if runs else 0.0


def ci95(p: float, n: int) -> float:
    return 1.96 * sqrt(p * (1 - p) / n) if n else 0.0


# ── Sections ──────────────────────────────────────────────────────────────────
def sec_baseline(l1: dict) -> str:
    out = ["## 1 · Baseline v2 — per-operation win rate (L1, full pools)", "",
           "| Operation | n | v2 clear | 95% CI | dead v1 (context) | drift |",
           "|---|--:|--:|--:|--:|--:|"]
    total_w = total_n = 0
    for op in OPS:
        runs = l1.get(op, [])
        n = len(runs)
        p = rate(runs)
        total_w += sum(r["result"] == "victory" for r in runs)
        total_n += n
        v1 = V1.get(op)
        out.append(f"| {OP_LABEL[op]} (`{op}`) | {n} | **{p:.1%}** | ±{ci95(p, n):.1%} "
                   f"| {v1:.1%} | {(p - v1) * 100:+.1f}pp |")
    overall = total_w / total_n if total_n else 0
    out.append(f"| **Overall (op-balanced)** | {total_n} | **{overall:.1%}** "
               f"| ±{ci95(overall, total_n):.1%} | {V1['overall']:.1%} "
               f"| {(overall - V1['overall']) * 100:+.1f}pp |")
    out += ["", "_v1 is DEAD as a comparison (pre taunt-G-4, pre item-cap-4, pre "
            "NK-17, pre harness fix) — shown for context only. Overall here is "
            "op-balanced (equal n per op), unlike v1's random-op draw._"]
    return "\n".join(out)


def sec_gap(l1: dict, l2: dict) -> str:
    out = ["## 2 · Decision density — L1 vs L2 gap (matched seeds)", "",
           "| Operation | L1 | L2 | Gap | Discordant seeds |",
           "|---|--:|--:|--:|--:|"]
    for op in OPS:
        a = {r["seed"]: r["result"] == "victory" for r in l1.get(op, [])}
        b = {r["seed"]: r["result"] == "victory" for r in l2.get(op, [])}
        common = sorted(set(a) & set(b))
        pa = sum(a[s] for s in common) / len(common)
        pb = sum(b[s] for s in common) / len(common)
        disc = sum(a[s] != b[s] for s in common)
        out.append(f"| {OP_LABEL[op]} | {pa:.1%} | {pb:.1%} | **{(pb - pa) * 100:+.1f}pp** "
                   f"| {disc} |")
    out += ["", "_The boredom dashboard: a SMALL gap means greedy play is "
            "near-optimal there (obvious turns). First-class metric from this "
            "cycle on. Matched seeds; discordant = seeds where the tiers "
            "disagree (McNemar-style evidence base)._"]
    return "\n".join(out)


def sec_bucket0(l1: dict, b0: dict) -> str:
    out = ["## 3 · Bucket-0 pools vs full pools (L1, matched seeds — NON-baseline arm)", "",
           "| Operation | Full pools | Bucket-0 | Delta |", "|---|--:|--:|--:|"]
    for op in OPS:
        a = {r["seed"]: r["result"] == "victory" for r in l1.get(op, [])}
        b = {r["seed"]: r["result"] == "victory" for r in b0.get(op, [])}
        common = sorted(set(a) & set(b))
        pa = sum(a[s] for s in common) / len(common)
        pb = sum(b[s] for s in common) / len(common)
        out.append(f"| {OP_LABEL[op]} | {pa:.1%} | {pb:.1%} | **{(pb - pa) * 100:+.1f}pp** |")
    out += ["", "_The true new-player pool the fully-unlocked sim never measured. "
            "Harness-side restriction through the live pool choke point; the "
            "baseline sim pin is untouched._"]
    return "\n".join(out)


def sec_killcurve(l1: dict) -> str:
    out = ["## 4 · Kill curve — run-ending battle (L1 defeats)", ""]
    for op in OPS:
        runs = l1.get(op, [])
        defeats = [r for r in runs if r["result"] == "defeat"]
        n = len(defeats)
        if not n:
            continue
        hist = Counter(r["defeat_battle"] for r in defeats)
        row = "  ".join(f"b{b}:{hist.get(b, 0) * 100 // n}%" for b in range(1, 11))
        out.append(f"**{OP_LABEL[op]}** ({n} defeats): {row}")
        # Spike = modal battle holding > 25% of defeats -> name its comps.
        modal, cnt = hist.most_common(1)[0]
        if cnt / n > 0.25:
            comps = Counter(r["defeat_comp"] for r in defeats
                            if r["defeat_battle"] == modal and r["defeat_comp"])
            top = "; ".join(f"{' + '.join(c)} ({k})" for c, k in comps.most_common(3))
            out.append(f"  ↳ **spike at battle {modal}** ({cnt / n:.0%} of defeats). "
                       f"Top comps: {top}")
        out.append("")
    return "\n".join(out)


def sec_turns(l1: dict) -> str:
    out = ["## 5 · Turns per battle (L1) — slog detector", "",
           "| Operation | mean | p50 | p90 | max | rounds>8 share | 500-cap stalls |",
           "|---|--:|--:|--:|--:|--:|--:|"]
    for op in OPS:
        rounds = [r2 for r in l1.get(op, []) for (_i, r2) in r["rounds_by_battle"]]
        if not rounds:
            continue
        rs = sorted(rounds)
        n = len(rs)
        mean = sum(rs) / n
        p50, p90 = rs[n // 2], rs[int(n * 0.9)]
        slog = sum(x > 8 for x in rs) / n
        stalls = sum(x >= 500 for x in rs)
        out.append(f"| {OP_LABEL[op]} | {mean:.1f} | {p50} | {p90} | {rs[-1]} | {slog:.1%} | {stalls} |")
    out += ["", "_A 500-cap stall is a battle the ROUND_SAFETY_CAP ended with no "
            "result; the runner then advances the run as neither victory nor "
            "defeat (harness quirk, recorded — rare: stall comps can deadlock "
            "against L1's kit)._"]
    return "\n".join(out)


def sec_protocol(l1: dict, l2: dict) -> str:
    out = ["## 6 · Protocol economy per policy tier", "",
           "| Tier | spends/run | cost/run | spend share b1-3 | b4-6 | b7-10 "
           "| mean leftover at battle end (b1-3 / b4-6 / b7-10) |",
           "|---|--:|--:|--:|--:|--:|--:|"]
    for label, tier in (("L1", l1), ("L2", l2)):
        runs = [r for op in OPS for r in tier.get(op, [])]
        if not runs:
            continue
        n = len(runs)
        tot_sp = tot_cost = 0
        phase_sp = [0, 0, 0]
        left = defaultdict(list)
        for r in runs:
            for b, (cnt, cost) in r["spends_by_battle"].items():
                tot_sp += cnt
                tot_cost += cost
                phase_sp[0 if b <= 3 else 1 if b <= 6 else 2] += cnt
            for b, pl in r["protocol_left_by_battle"].items():
                left[0 if b <= 3 else 1 if b <= 6 else 2].append(pl)
        share = [f"{p / tot_sp:.0%}" if tot_sp else "0%" for p in phase_sp]
        lo = " / ".join(f"{sum(v) / len(v):.1f}" if v else "-" for v in
                        (left[0], left[1], left[2]))
        out.append(f"| {label} | {tot_sp / n:.1f} | {tot_cost / n:.1f} "
                   f"| {share[0]} | {share[1]} | {share[2]} | {lo} |")
    out += ["", "_Hoarding-equilibrium check: compare leftover protocol at battle "
            "end across phases and tiers — a hoarding tier shows fat early "
            "leftovers spent late (or never)._"]
    return "\n".join(out)


def sec_outliers(arms_root: Path) -> str:
    ctrl_dir = arms_root / "outlier_control"
    if not ctrl_dir.exists():
        return "## 7 · Content outliers\n\n_outlier batches missing._", {}
    ctrl = {r["seed"]: r["result"] == "victory" for r in load_dir(ctrl_dir)}
    rows = []
    for arm_dir in sorted(arms_root.glob("arm_*")):
        item_id = arm_dir.name[4:]
        arm = {r["seed"]: r["result"] == "victory" for r in load_dir(arm_dir)}
        common = sorted(set(arm) & set(ctrl))
        if not common:
            continue
        n = len(common)
        pa = sum(arm[s] for s in common) / n
        pc = sum(ctrl[s] for s in common) / n
        lift = (pa - pc) * 100
        se = sqrt(max(pa * (1 - pa), 1e-9) / n + max(pc * (1 - pc), 1e-9) / n) * 100
        rows.append((item_id, lift, pa, pc, n, se))
    rows.sort(key=lambda r: -abs(r[1]))
    out = ["## 7 · Content outliers — forced-grant A/B vs matched-seed control", "",
           f"_Control clear: **{sum(ctrl.values()) / len(ctrl):.1%}** over "
           f"{len(ctrl)} runs (random squads + ops). Lift = arm − control, "
           "matched seeds; ±SE is the conservative independent-sample bound. "
           "Flag ⚑ = |lift| ≥ 5pp. Granted from battle 1 (not the natural draft "
           "point) — a documented upward bias on early-gated content._", "",
           "_**Estimand caveat (relics):** a granted relic counts as drafted, so "
           "the battle-5 relic cache never rolls in relic arms "
           "(`GameState._roll_reward_item_ids`, `drafted_relic_count()==0` gate). "
           "Relic lifts are therefore **substitution** effects — this relic from "
           "battle 1 INSTEAD OF the natural battle-5 choice-of-2 — while "
           "gear/consumable lifts are **additive** (drafts continue normally). "
           "Rankings within a type are comparable; magnitudes across types are "
           "not._", "",
           "| # | Content | Lift | Arm | Ctrl | ±SE | n |", "|--:|---|--:|--:|--:|--:|--:|"]
    for i, (item_id, lift, pa, pc, n, se) in enumerate(rows[:20], 1):
        flag = " ⚑" if abs(lift) >= 5 else ""
        out.append(f"| {i} | `{item_id}`{flag} | **{lift:+.1f}pp** | {pa:.1%} "
                   f"| {pc:.1%} | {se:.1f}pp | {n} |")
    flagged = sum(1 for r in rows if abs(r[1]) >= 5)
    out += ["", f"_{len(rows)} arms screened; **{flagged}** past ±5pp. Full table "
            "in the results tree (`arm_*/`)._"]
    return "\n".join(out), {r[0]: r[1] for r in rows}


def sec_predictions(l1: dict, l2: dict, lifts: dict) -> str:
    out = ["## 8 · Prediction check (pre-registered, honestly scored)", ""]

    def verdict(name, guess, actual, hit):
        mark = "✅" if hit else "❌"
        return f"- {mark} **{name}** — guessed: {guess}. Measured: {actual}."

    strong = [("Vengeance Protocol", "martyrdomProtocol"),
              ("Dead Man's Hand", "deadMansHand"),
              ("Band Compressor", "band_compressor"),
              ("Iron Curtain", "ironCurtain")]
    for label, iid in strong:
        lv = lifts.get(iid)
        if lv is None:
            out.append(f"- ⚠️ **{label}** — no arm data.")
            continue
        out.append(verdict(label, "strongly positive", f"{lv:+.1f}pp", lv >= 5))
    pl, ns = lifts.get("predator_lens"), lifts.get("neural_splice")
    if pl is not None and ns is not None:
        close = abs(pl - ns) <= 3
        out.append(verdict("Predator Lens vs Neural Splice (identical effect, "
                           "different rarity)", "similar lift = mispricing",
                           f"predator {pl:+.1f}pp vs splice {ns:+.1f}pp", close))
    # Gap ordering guesses.
    gaps = {}
    for op in OPS:
        a = {r["seed"]: r["result"] == "victory" for r in l1.get(op, [])}
        b = {r["seed"]: r["result"] == "victory" for r in l2.get(op, [])}
        common = set(a) & set(b)
        if common:
            gaps[op] = (sum(b[s] for s in common) - sum(a[s] for s in common)) / len(common)
    if gaps:
        smallest = min(gaps, key=lambda o: abs(gaps[o]))
        widest = max(gaps, key=lambda o: abs(gaps[o]))
        out.append(verdict("Facility smallest L1/L2 gap",
                           "facility", f"smallest = {OP_LABEL[smallest]} "
                           f"({gaps[smallest] * 100:+.1f}pp)", smallest == "facility"))
        out.append(verdict("Null Synod widest L1/L2 gap",
                           "voidCirclet", f"widest = {OP_LABEL[widest]} "
                           f"({gaps[widest] * 100:+.1f}pp)", widest == "voidCirclet"))
    return "\n".join(out)


HEADER_CAVEATS = """\
> **Standing caveats.** The sim measures **WINNABILITY, not fun**. Cognitive-load
> problems (Veil) and turn-feel problems are invisible to every policy tier;
> those belong to the demo testers. All of Cycle 0 ran at **full unlock** except
> arm 3 (bucket-0) — the headline numbers describe a **veteran's pools**.
> Batches ran under the CURRENT operation order (facility, hive, veil,
> voidCirclet, stellarMenagerie — the pending reorder ruling has NOT landed).
> MEASUREMENT ONLY: zero game-data changes in this cycle."""


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=str(ROOT / "results" / "cycle0"))
    ap.add_argument("-o", "--out", default="")
    args = ap.parse_args()
    root = Path(args.root)

    l1 = {op: load_dir(root / f"baseline_v2_{op}") for op in OPS}
    l2 = {op: load_dir(root / f"l2_{op}") for op in OPS}
    b0 = {op: load_dir(root / f"b0_{op}") for op in OPS}
    outlier_md, lifts = sec_outliers(root)

    parts = ["# Balance Cycle 0 — Re-Baseline Dashboard", "", HEADER_CAVEATS, "",
             sec_baseline(l1), "", sec_gap(l1, l2), "", sec_bucket0(l1, b0), "",
             sec_killcurve(l1), "", sec_turns(l1), "", sec_protocol(l1, l2), "",
             outlier_md, "", sec_predictions(l1, l2, lifts), ""]
    report = "\n".join(parts)
    if args.out:
        Path(args.out).write_text(report, encoding="utf-8")
        print(f"wrote {args.out}")
    else:
        print(report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
