"""Combat-sponginess benchmark (2026-09) — scenario comparison. MEASUREMENT ONLY.

Analyzes every results/sponginess/<scenario>__<squad>__<policy> batch (cached
per batch), pools the squads per scenario, and prints/writes deltas vs the
baseline. Seeds are matched across scenarios, so deltas isolate the knobs.

  python tools/sponginess/compare.py -o results/sponginess/compare.json
"""
import argparse
import glob
import json
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RES = ROOT / "results" / "sponginess"
ANALYZE = ROOT / "tools" / "sponginess" / "analyze_bench.py"


MATCHED_RUNS = 400  # scenario batches run 400 seeds; baseline is cut to the same seeds


def analyzed(dirs, out):
    if not out.exists():
        subprocess.run([sys.executable, str(ANALYZE), *[str(d) for d in dirs], "-o", str(out),
                        "--max-runs", str(MATCHED_RUNS)], check=True)
    return json.loads(out.read_text())


def metrics(rep):
    a = rep["all_battles"]
    idx = rep["by_index"]
    en = rep["enemies"]

    def g(d, *path, default=0):
        for p in path:
            if not isinstance(d, dict) or p not in d:
                return default
            d = d[p]
        return d
    early = [idx[k] for k in ("1", "2", "3") if k in idx]
    mid = [idx[k] for k in ("4", "5", "6") if k in idx]
    late = [idx[k] for k in ("7", "8", "9") if k in idx]

    def avg_rounds(blocks):
        n = sum(g(b, "rounds_win", "n") for b in blocks) or 1
        return sum(g(b, "rounds_win", "mean") * g(b, "rounds_win", "n") for b in blocks) / n
    return {
        "clear_rate": rep["clear_rate"],
        "rounds_mean": g(a, "rounds_win", "mean"), "rounds_median": g(a, "rounds_win", "median"),
        "rounds_p90": g(a, "rounds_win", "p90"),
        "hero_actions": g(a, "hero_actions_win", "mean"),
        "offensive_actions": g(a, "offensive_actions_win", "mean"),
        "dmg_taken_per_battle": g(a, "dmg_taken_all", "mean"),
        "hero_deaths_per_battle": g(a, "hero_deaths_per_battle"),
        "flawless_win_share": g(a, "flawless_win_share"),
        "sustain_share": g(a, "sustain_share"),
        "single_enemy_rounds": g(a, "single_enemy_rounds", "mean"),
        "low_threat_share": g(a, "low_threat_share"),
        "cleanup_extra": g(a, "cleanup_extra", "mean"),
        "early_rounds": avg_rounds(early), "mid_rounds": avg_rounds(mid), "late_rounds": avg_rounds(late),
        "b5_rounds": g(idx, "5", "rounds_win", "mean"), "b5_win": g(idx, "5", "win_rate"),
        "b10_rounds_mean": g(idx, "10", "rounds_win", "mean"), "b10_rounds_p90": g(idx, "10", "rounds_win", "p90"),
        "b10_win": g(idx, "10", "win_rate"),
        "warden_actions_to_kill": g(en, "Heavy Warden", "hero_actions_to_kill", "median"),
        "guard_actions_to_kill": g(en, "Shield Enforcer", "hero_actions_to_kill", "median"),
        "guard_ehp": g(en, "Shield Enforcer", "effective_hp", "mean"),
        "warden_ehp": g(en, "Heavy Warden", "effective_hp", "mean"),
        "boss_actions_to_kill": g(en, "Scrapmaster (B10)", "hero_actions_to_kill", "median"),
        "drone_b10_ehp": g(en, "Scrap Drone (B10)", "effective_hp", "mean"),
        "hits_under_10pct_warden": g(en, "Heavy Warden", "hit_buckets", "<10%"),
        "hits_under_10pct_boss": g(en, "Scrapmaster (B10)", "hit_buckets", "<10%"),
        "incoming_per_battle": g(a, "incoming_raw_all", "mean"),
        "incoming_per_round": g(a, "incoming_per_round_all", "mean"),
        "rounds_by_battle": {k: g(v, "rounds_win", "mean") for k, v in idx.items()},
        "win_by_battle": {k: g(v, "win_rate") for k, v in idx.items()},
        "incoming_by_battle": {k: g(v, "incoming_raw_all", "mean") for k, v in idx.items()},
        "deaths_by_battle": {k: g(v, "hero_deaths_per_battle") for k, v in idx.items()},
        "b10": {k: g(idx, "10", k, "mean") for k in ("drone_kills", "rebuilds", "boss_kill_round", "drone_out_share",
                                                    "rounds_after_boss_dead_win", "incoming_per_round_all")}
               | {"hero_actions": g(idx, "10", "hero_actions_win", "mean"), "deaths": g(idx, "10", "hero_deaths_per_battle"),
                  "dmg_taken": g(idx, "10", "dmg_taken_all", "mean")},
        "enemy": {n: {"ehp": g(en, n, "effective_hp", "mean"), "atk_med": g(en, n, "hero_actions_to_kill", "median"),
                      "atk_mean": g(en, n, "hero_actions_to_kill", "mean"),
                      "atk_blk_mean": g(en, n, "actions_to_kill_incl_block", "mean"),
                      "rounds_alive": g(en, n, "rounds_alive_to_kill", "mean"),
                      "dmg_out": g(en, n, "dmg_out", "mean"), "dmg_out_pr": g(en, n, "dmg_out_per_round", "mean"),
                      "hits_lt10": g(en, n, "hit_buckets", "<10%"),
                      "last_share": g(rep, "last_standing", n, "share_of_wins"),
                      "last_solo": g(rep, "last_standing", n, "solo_rounds", "mean")}
                  for n in ("Shield Enforcer", "Heavy Warden", "Volt Enforcer", "Patrol Enforcer", "Rust Drone",
                            "Scrapmaster (B10)", "Scrap Drone (B10)")},
        "solo_threat": g(rep, "round_threat", "solo", "incoming_pct_squad_hp", "mean"),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--policy", default="l1")
    ap.add_argument("--only", default="", help="comma list of scenarios to (re)analyze")
    ap.add_argument("--cache", default="cache_v2")
    args = ap.parse_args()
    by_scen = defaultdict(list)
    for d in sorted(glob.glob(str(RES / f"*__*__{args.policy}"))):
        name = Path(d).name
        scen, squad, _ = name.split("__")
        if args.only and scen not in args.only.split(","):
            continue
        by_scen[scen].append((squad, Path(d)))
    cache = RES / args.cache
    cache.mkdir(exist_ok=True)
    out = {}
    for scen, items in by_scen.items():
        per_squad = {}
        for squad, d in items:
            per_squad[squad] = metrics(analyzed([d], cache / f"{d.name}.json"))
        pooled = metrics(analyzed([d for _, d in items], cache / f"{scen}__pooled__{args.policy}.json"))
        out[scen] = {"pooled": pooled, "squads": per_squad, "n_squads": len(items)}
    Path(args.out).write_text(json.dumps(out, indent=1))
    base = out.get("baseline", {}).get("pooled", {})
    keys = ["clear_rate", "rounds_mean", "rounds_p90", "hero_actions", "dmg_taken_per_battle", "hero_deaths_per_battle",
            "early_rounds", "mid_rounds", "late_rounds", "b5_rounds", "b10_rounds_mean", "b10_rounds_p90", "b10_win"]
    print("scenario".ljust(18) + "".join(k[:10].rjust(11) for k in keys))
    for scen, v in out.items():
        p = v["pooled"]
        print(scen.ljust(18) + "".join(f"{p.get(k, 0):11.3f}" for k in keys))


if __name__ == "__main__":
    main()
