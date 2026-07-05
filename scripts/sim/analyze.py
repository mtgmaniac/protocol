#!/usr/bin/env python3
"""Balance-sim aggregation + Stage-1 regression + report (Package C.2).

Reads a batch of run JSONL files and produces a markdown balance report:
descriptive tables (hero / op / protocol / keyword / enemy) plus the Stage-1
logistic regression that flags over/under-powered content by win-rate lift.

  python scripts/sim/analyze.py results/screen_l1 -o results/report_screen_l1.md

Stage-2 A/B (matched-seed forced-content arm vs control):
  python scripts/sim/analyze.py --ab results/coldlogic_arm results/coldlogic_ctrl

Requires pandas + statsmodels + scipy (see scripts/sim/requirements.txt).
"""
import argparse
import json
import sys
from pathlib import Path

import pandas as pd
import numpy as np
import statsmodels.api as sm
from scipy import stats

# Round-event keywords whose realized value we audit (event type -> label).
KEYWORD_EVENTS = {
    "chain": "Chain", "detonate": "Detonate", "execute": "Execute",
    "breach": "Breach", "leech": "Leech", "spike": "Spike",
    "mark_consumed": "Mark", "siphon": "Siphon", "block": "Ward/Block",
    "freeze": "Freeze", "hijack": "Hijack",
}


def load_run(path: Path) -> dict:
    """Collapse one run's JSONL into a single flat record."""
    header, run_end = {}, {}
    acquired, evolutions, directives = [], [], []
    spend_counts = {"nudge": 0, "reroll": 0, "set": 0}
    kw = {label: {"n": 0, "amt": 0} for label in KEYWORD_EVENTS.values()}
    enemy_dmg, enemy_appear = {}, {}
    battles_played = 0
    defeat_comp = []

    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        o = json.loads(line)
        t = o.get("type")
        if t == "run_header":
            header = o
        elif t == "run_end":
            run_end = o
        elif t == "draft" and o.get("picked"):
            for opt in o.get("options", []):
                if opt.get("id") == o["picked"]:
                    acquired.append((o["picked"], opt.get("type", ""), opt.get("rarity", "")))
        elif t == "progression":
            (evolutions if o.get("kind") == "evolution" else directives).append(o.get("picked", ""))
        elif t == "battle_start":
            battles_played += 1
            for name in o.get("comp", []):
                enemy_appear[name] = enemy_appear.get(name, 0) + 1
        elif t == "round":
            for sp in o.get("spends", []):
                if sp.get("kind") in spend_counts:
                    spend_counts[sp["kind"]] += 1
            actor = None
            for ev in o.get("events", []):
                et = ev.get("type", "")
                if et == "action_start":
                    actor = (ev.get("actor_name"), ev.get("side"))
                elif et in KEYWORD_EVENTS:
                    kw[KEYWORD_EVENTS[et]]["n"] += 1
                    kw[KEYWORD_EVENTS[et]]["amt"] += int(ev.get("amount", 0))
                if et == "damage" and ev.get("side") == "hero" and actor and actor[1] == "enemy":
                    enemy_dmg[actor[0]] = enemy_dmg.get(actor[0], 0) + int(ev.get("amount", 0))
        elif t == "battle_end" and o.get("result") == "defeat":
            defeat_comp = o.get("index")

    rec = {
        "seed": header.get("seed"),
        "policy": header.get("policy"),
        "op": header.get("op"),
        "squad": tuple(header.get("squad", [])),
        "granted": tuple(header.get("granted", [])),
        "result": run_end.get("result"),
        "battles_cleared": run_end.get("battles_cleared", 0),
        "full_clear": int(run_end.get("result") == "victory"),
        "battles_played": battles_played,
        "defeat_battle": defeat_comp,
    }
    for h in header.get("squad", []):
        rec[f"hero__{h}"] = 1
    for item_id, itype, _ in acquired:
        rec[f"{itype}__{item_id}"] = 1
    for ev in evolutions:
        rec[f"evo__{ev}"] = 1
    for d in directives:
        rec[f"dir__{d}"] = 1
    rec["_spends"] = spend_counts
    rec["_kw"] = kw
    rec["_enemy_dmg"] = enemy_dmg
    rec["_enemy_appear"] = enemy_appear
    return rec


def load_dir(d: Path) -> pd.DataFrame:
    runs = [load_run(p) for p in sorted(d.glob("run_*.jsonl"))]
    if not runs:
        sys.exit(f"no run_*.jsonl in {d}")
    df = pd.DataFrame(runs)
    onehot = [c for c in df.columns if "__" in c]
    df[onehot] = df[onehot].fillna(0).astype(int)
    return df


# ── Descriptive tables ────────────────────────────────────────────────────────
def hero_table(df: pd.DataFrame) -> str:
    rows = []
    for c in sorted(c for c in df.columns if c.startswith("hero__")):
        hero = c.split("__", 1)[1]
        incl = df[df[c] == 1]
        if len(incl) == 0:
            continue
        rows.append((hero, len(incl), incl["full_clear"].mean(), incl["battles_cleared"].mean()))
    rows.sort(key=lambda r: -r[2])
    out = ["| Hero | Runs | Clear rate | Avg depth |", "|---|--:|--:|--:|"]
    for h, n, cr, depth in rows:
        out.append(f"| {h} | {n} | {cr:.1%} | {depth:.1f} |")
    return "\n".join(out)


def op_table(df: pd.DataFrame) -> str:
    g = df.groupby("op").agg(runs=("full_clear", "size"), clear=("full_clear", "mean"),
                             depth=("battles_cleared", "mean")).sort_values("clear", ascending=False)
    out = ["| Operation | Runs | Clear rate | Avg depth |", "|---|--:|--:|--:|"]
    for op, r in g.iterrows():
        out.append(f"| {op} | {int(r.runs)} | {r.clear:.1%} | {r.depth:.1f} |")
    return "\n".join(out)


def protocol_table(df: pd.DataFrame) -> str:
    tot = {"nudge": 0, "reroll": 0, "set": 0}
    for s in df["_spends"]:
        for k in tot:
            tot[k] += s[k]
    grand = sum(tot.values()) or 1
    # Correlate per-run total spends with full clear.
    df = df.copy()
    df["_spend_total"] = df["_spends"].apply(lambda s: sum(s.values()))
    corr = df["_spend_total"].corr(df["full_clear"])
    out = ["| Protocol action | Total | Share |", "|---|--:|--:|"]
    for k in ("nudge", "reroll", "set"):
        out.append(f"| {k.capitalize()} | {tot[k]} | {tot[k]/grand:.1%} |")
    out.append("")
    out.append(f"Spend-total ↔ full-clear correlation: **{corr:+.3f}** "
               f"(mean {df['_spend_total'].mean():.1f} spends/run).")
    return "\n".join(out)


def keyword_table(df: pd.DataFrame) -> str:
    agg = {label: {"n": 0, "amt": 0} for label in KEYWORD_EVENTS.values()}
    for kw in df["_kw"]:
        for label, v in kw.items():
            agg[label]["n"] += v["n"]
            agg[label]["amt"] += v["amt"]
    out = ["| Keyword | Triggers | Total value | Per trigger |", "|---|--:|--:|--:|"]
    for label, v in sorted(agg.items(), key=lambda kv: -kv[1]["n"]):
        per = v["amt"] / v["n"] if v["n"] else 0
        out.append(f"| {label} | {v['n']} | {v['amt']} | {per:.1f} |")
    return "\n".join(out)


def enemy_table(df: pd.DataFrame) -> str:
    dmg, appear = {}, {}
    for d in df["_enemy_dmg"]:
        for k, v in d.items():
            dmg[k] = dmg.get(k, 0) + v
    for a in df["_enemy_appear"]:
        for k, v in a.items():
            appear[k] = appear.get(k, 0) + v
    rows = []
    for name, ap in appear.items():
        rows.append((name, ap, dmg.get(name, 0), dmg.get(name, 0) / ap if ap else 0))
    rows.sort(key=lambda r: -r[3])
    out = ["| Enemy | Appearances | Damage dealt | Dmg / appearance |", "|---|--:|--:|--:|"]
    for name, ap, dm, per in rows:
        out.append(f"| {name} | {ap} | {dm} | {per:.1f} |")
    return "\n".join(out)


# ── Stage-1 regression ────────────────────────────────────────────────────────
# Ridge-penalized logistic with bootstrap CIs. Ridge (not plain MLE) because
# content one-hots are sparse and collinear — plain MLE hits quasi-separation
# and returns ±huge CIs. Feature set is deliberately EXOGENOUS/acquired content
# only (squad heroes + drafted relics/gear/consumables); evolution/Directive
# picks are survival-confounded (a unit only evolves if it got deep), so they
# would predict outcome trivially — they get the descriptive pick-rate table
# instead. Stage-1 is a SCREEN to flag tails; Stage-2 forced arms give clean
# causal lift.
def _ridge_fit(X: pd.DataFrame, y: pd.Series, alpha: float):
    return sm.Logit(y, X).fit_regularized(alpha=alpha, L1_wt=0.0, disp=0, maxiter=200)


def stage1_regression(df: pd.DataFrame, min_support: int = 25,
                      alpha: float = 2.0, n_boot: int = 200) -> str:
    content_cols = [c for c in df.columns if c.split("__", 1)[0] in
                    ("relic", "gear", "consumable", "hero")]
    op_dummies = pd.get_dummies(df["op"], prefix="op", drop_first=True).astype(int)
    keep = [c for c in content_cols
            if df[c].sum() >= min_support and 0 < df[df[c] == 1]["full_clear"].sum() < df[c].sum()]
    if not keep:
        return "_Not enough content support for a Stage-1 fit (need a larger batch)._"
    feat = keep + list(op_dummies.columns)
    base = pd.concat([df[keep], op_dummies], axis=1).astype(float)
    base = sm.add_constant(base, has_constant="add")
    y = df["full_clear"].astype(float)
    point = _ridge_fit(base, y, alpha).params

    # Nonparametric bootstrap over runs for CIs (percentile method).
    rng = np.random.default_rng(0)  # deterministic report
    n = len(df)
    boot = {c: [] for c in keep}
    for _ in range(n_boot):
        idx = rng.integers(0, n, n)
        try:
            p = _ridge_fit(base.iloc[idx], y.iloc[idx], alpha).params
            for c in keep:
                boot[c].append(p.get(c, 0.0))
        except Exception:
            continue
    rows = []
    for c in keep:
        vals = np.array(boot[c]) if boot[c] else np.array([0.0])
        lo, hi = np.percentile(vals, [2.5, 97.5])
        rows.append((c, float(point.get(c, 0.0)), lo, hi, int(df[c].sum())))
    rows.sort(key=lambda r: -abs(r[1]))
    out = ["Ridge logistic (α=%.1f): `full_clear ~ content + op controls`. "
           "Coefficient = log-odds lift; CI = 2.5/97.5%% bootstrap (%d resamples). "
           "Ranked by |lift|." % (alpha, n_boot), "",
           "| Content | Lift (log-odds) | 95% CI | Runs |", "|---|--:|--:|--:|"]
    for name, coef, lo, hi, sup in rows[:15]:
        flag = " ⚠️" if (lo > 0 or hi < 0) else ""
        out.append(f"| {name}{flag} | {coef:+.2f} | [{lo:+.2f}, {hi:+.2f}] | {sup} |")
    out.append("")
    out.append("_%d content features over %d runs (min support %d). "
               "⚠️ = bootstrap CI excludes 0. Evolutions/Directives excluded "
               "(survival-confounded) — see pick-rate table. Stage-1 screens "
               "tails; Stage-2 arms confirm causally._" % (len(keep), len(df), min_support))
    return "\n".join(out)


def evolution_pickrate_table(df: pd.DataFrame) -> str:
    # Sibling pick-rate: within each hero's two evolution paths, how often each
    # was chosen (conditional on the hero evolving). A near-100% split flags a
    # dead sibling. L1 is deterministic, so this reflects L1's fixed preference
    # rather than balance per se — noted.
    evo_cols = [c for c in df.columns if c.startswith("evo__")]
    if not evo_cols:
        return "_No evolutions recorded._"
    counts = {c.split("__", 1)[1]: int(df[c].sum()) for c in evo_cols}
    out = ["| Evolution | Times picked |", "|---|--:|"]
    for name, n in sorted(counts.items(), key=lambda kv: -kv[1]):
        out.append(f"| {name} | {n} |")
    out.append("")
    out.append("_L1 is deterministic — this is L1's fixed preference, not a "
               "free-choice rate. Archetype/L2 drafting (Package D) gives the "
               "balance-relevant version._")
    return "\n".join(out)


# ── Reports ───────────────────────────────────────────────────────────────────
def full_report(d: Path) -> str:
    df = load_dir(d)
    clear = df["full_clear"].mean()
    policy = df["policy"].iloc[0]
    parts = [
        f"# Balance report — `{d.name}`", "",
        f"- Runs: **{len(df)}**  ·  policy: **{policy}**",
        f"- Full-clear rate: **{clear:.1%}**  ·  mean depth: **{df['battles_cleared'].mean():.1f}**/10",
        "",
        "## Heroes", hero_table(df), "",
        "## Operations", op_table(df), "",
        "## Protocol economy", protocol_table(df), "",
        "## Keyword realized value", keyword_table(df), "",
        "## Enemies (damage per appearance)", enemy_table(df), "",
        "## Stage-1 content lift", stage1_regression(df), "",
        "## Evolution pick rates", evolution_pickrate_table(df), "",
        "> Consumables are drafted but not yet USED in battle (Package D adds the "
        "item-use policy), so consumable lift reads near-zero until then.",
    ]
    return "\n".join(parts)


def ab_report(treat: Path, ctrl: Path) -> str:
    dt, dc = load_dir(treat), load_dir(ctrl)
    # Matched-seed two-proportion test on full-clear rate.
    mt = dt.set_index("seed")["full_clear"]
    mc = dc.set_index("seed")["full_clear"]
    common = mt.index.intersection(mc.index)
    a, b = mt.loc[common], mc.loc[common]
    n = len(common)
    pa, pb = a.mean(), b.mean()
    se = np.sqrt(pa * (1 - pa) / n + pb * (1 - pb) / n) if n else 0
    z = (pa - pb) / se if se else 0
    p = 2 * (1 - stats.norm.cdf(abs(z)))
    grant = dt["granted"].iloc[0]
    return "\n".join([
        f"# A/B forced-content arm", "",
        f"- Treatment `{treat.name}` (grant: {list(grant)}) vs control `{ctrl.name}`",
        f"- Matched seeds: **{n}**",
        f"- Treatment clear: **{pa:.1%}**  ·  control clear: **{pb:.1%}**",
        f"- Lift: **{pa - pb:+.1%}**  ·  z = {z:+.2f}, p = {p:.4f}"
        + ("  **(significant)**" if p < 0.05 else "  (n.s.)"),
    ])


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # report has ↔ / ⚠️
    except Exception:
        pass
    ap = argparse.ArgumentParser(description="Aggregate a sim batch into a balance report")
    ap.add_argument("dir", nargs="?", help="batch results dir")
    ap.add_argument("-o", "--out", help="write markdown here (else stdout)")
    ap.add_argument("--ab", nargs=2, metavar=("TREAT", "CTRL"), help="A/B compare two dirs")
    args = ap.parse_args()
    if args.ab:
        report = ab_report(Path(args.ab[0]), Path(args.ab[1]))
    elif args.dir:
        report = full_report(Path(args.dir))
    else:
        ap.error("give a batch dir or --ab TREAT CTRL")
    if args.out:
        Path(args.out).write_text(report, encoding="utf-8")
        print(f"wrote {args.out}")
    else:
        print(report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
