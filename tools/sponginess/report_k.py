"""Round-4 report (durability -> threat trades, Scrapmaster strategy study).
MEASUREMENT ONLY. Reads compare.py outputs and prints markdown tables.

  python tools/sponginess/report_k.py --l1 results/sponginess/compare_k.json \
      --focus results/sponginess/compare_k_focus.json --norekill results/sponginess/compare_k_norekill.json
"""
import argparse
import json

SQUADS = ["default", "highdmg", "defensive", "mix_pcs", "mix_cmb", "mix_apm", "mix_gse", "random"]
TUNED = ["Shield Enforcer", "Heavy Warden", "Volt Enforcer"]


def row(cells):
    return "| " + " | ".join(str(c) for c in cells) + " |"


def f(x, nd=2):
    return f"{x:.{nd}f}" if isinstance(x, (int, float)) else str(x)


def pct(x):
    return f"{100 * x:.1f}%"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--l1", required=True)
    ap.add_argument("--focus")
    ap.add_argument("--norekill")
    ap.add_argument("--order", default="")
    args = ap.parse_args()
    d = json.load(open(args.l1))
    order = args.order.split(",") if args.order else list(d)
    base = d["baseline"]["pooled"]

    print("\n### Pooled\n")
    print(row(["Scenario", "Clear", "Δ", "Early (B1-3)", "Mid (B4-6)", "Late (B7-9)", "B5 rnds / win", "B10 rnds / win",
               "Hero actions / win", "Incoming / battle", "Incoming / round", "Hero deaths / battle", "Solo rnds", "Solo-round threat"]))
    print(row(["---"] * 14))
    for s in order:
        p = d[s]["pooled"]
        print(row([s, pct(p["clear_rate"]), f"{100 * (p['clear_rate'] - base['clear_rate']):+.1f}", f(p["early_rounds"]),
                   f(p["mid_rounds"]), f(p["late_rounds"]), f"{f(p['b5_rounds'])} / {pct(p['b5_win'])}",
                   f"{f(p['b10_rounds_mean'])} / {pct(p['b10_win'])}", f(p["hero_actions"], 1),
                   f(p["incoming_per_battle"], 1), f(p["incoming_per_round"], 1), f(p["hero_deaths_per_battle"]),
                   f(p["single_enemy_rounds"]), pct(p["solo_threat"])]))

    print("\n### Per battle — rounds in wins (win %)\n")
    print(row(["Scenario"] + [f"B{i}" for i in range(1, 11)]))
    print(row(["---"] * 11))
    for s in order:
        p = d[s]["pooled"]
        print(row([s] + [f"{f(p['rounds_by_battle'].get(str(i), 0))} ({100 * p['win_by_battle'].get(str(i), 0):.0f}%)"
                         for i in range(1, 11)]))
    print("\n### Per battle — incoming damage (HP + blocked) per battle\n")
    print(row(["Scenario"] + [f"B{i}" for i in range(1, 11)]))
    print(row(["---"] * 11))
    for s in order:
        p = d[s]["pooled"]
        print(row([s] + [f(p["incoming_by_battle"].get(str(i), 0), 0) for i in range(1, 11)]))

    for n in TUNED + ["Patrol Enforcer", "Rust Drone"]:
        print(f"\n### {n}\n")
        print(row(["Scenario", "EHP", "Actions to kill (mean, HP hits)", "…incl. shield hits", "Rounds alive",
                   "Dmg dealt / life", "Dmg dealt / round alive", "Hits < 10%", "Last-standing share", "Solo rounds when last"]))
        print(row(["---"] * 10))
        for s in order:
            e = d[s]["pooled"]["enemy"][n]
            print(row([s, f(e["ehp"], 1), f(e["atk_mean"], 1), f(e["atk_blk_mean"], 1), f(e["rounds_alive"], 1),
                       f(e["dmg_out"], 1), f(e["dmg_out_pr"], 1), pct(e["hits_lt10"]), pct(e["last_share"]),
                       f(e["last_solo"])]))

    print("\n### Per-squad clear rate (Δ pts vs baseline)\n")
    print(row(["Scenario"] + SQUADS + ["max |Δ|"]))
    print(row(["---"] * (len(SQUADS) + 2)))
    for s in order:
        sq = d[s]["squads"]
        cells, mx = [], 0
        for k in SQUADS:
            v = sq[k]["clear_rate"]
            dv = 100 * (v - d["baseline"]["squads"][k]["clear_rate"])
            mx = max(mx, abs(dv))
            cells.append(f"{100 * v:.0f}% ({dv:+.0f})" if s != "baseline" else f"{100 * v:.0f}%")
        print(row([s] + cells + [f"{mx:.1f}"]))

    pols = [("l1", d)]
    if args.focus:
        pols.append(("l1_focus", json.load(open(args.focus))))
    if args.norekill:
        pols.append(("l1_norekill", json.load(open(args.norekill))))
    if len(pols) > 1:
        print("\n### Scrapmaster (B10) by policy\n")
        print(row(["Scenario", "Policy", "Run clear", "B10 win", "B10 rnds mean / p90", "Hero actions / win",
                   "Drone kills", "Rebuilds", "Squad dmg into drones", "Boss dies round", "Incoming / round",
                   "Dmg taken", "Hero deaths"]))
        print(row(["---"] * 13))
        for s in order:
            for pol, dd in pols:
                if s not in dd:
                    continue
                p = dd[s]["pooled"]
                b = p["b10"]
                print(row([s, pol, pct(p["clear_rate"]), pct(p["b10_win"]), f"{f(p['b10_rounds_mean'])} / {f(p['b10_rounds_p90'], 0)}",
                           f(b["hero_actions"], 1), f(b["drone_kills"]), f(b["rebuilds"]), pct(b["drone_out_share"]),
                           f(b["boss_kill_round"], 1), f(b["incoming_per_round_all"], 1), f(b["dmg_taken"], 0), f(b["deaths"])]))
        print("\n### B10 win by squad and policy\n")
        print(row(["Scenario", "Policy"] + SQUADS))
        print(row(["---"] * (len(SQUADS) + 2)))
        for s in order:
            for pol, dd in pols:
                if s not in dd:
                    continue
                print(row([s, pol] + [f"{100 * dd[s]['squads'][k]['b10_win']:.0f}% / {f(dd[s]['squads'][k]['b10_rounds_mean'], 1)}r"
                                      for k in SQUADS]))


if __name__ == "__main__":
    main()
