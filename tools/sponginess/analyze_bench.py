"""Combat-sponginess benchmark (2026-09) — JSONL analyzer. MEASUREMENT ONLY.

Reads sim runs written by scripts/sim/batch.py (real combat_manager event
streams) and derives pacing / durability metrics. Event semantics (verified
against live streams, 2026-09-21):
  - `damage` is the only real HP loss. `chain`/`pierce`/`breach`/`mark`/
    `spike` are markers that ride alongside a `damage`.
  - A `damage` on the ACTOR'S OWN side right after its action_start is a burn
    tick (start-of-action DoT); preceded by a `spike` marker it is spike
    retaliation from the enemy being hit.
  - `block` = damage absorbed by shields (on the side named).
  - `heal`/`leech` on a side = HP restored; enemy `revive` (Assembly Line)
    restores the dead drone at hp_after AND emits a `heal` for that HP (so
    effective HP counts heal only; never add revive_hp on top).
  - `burn` = a burn stack being applied (not damage).

  python tools/sponginess/analyze_bench.py results/sponginess/baseline__default__l1 ... -o out.json
"""
import argparse
import glob
import json
import statistics as st
import sys
from collections import defaultdict
from pathlib import Path

OFFENSIVE = {"damage", "block", "chain", "pierce", "breach"}
SUSTAIN = {"heal", "shield", "revive", "cleanse", "leech"}


def pct(values, q):
    if not values:
        return 0.0
    s = sorted(values)
    k = (len(s) - 1) * q
    f = int(k)
    c = min(f + 1, len(s) - 1)
    return s[f] + (s[c] - s[f]) * (k - f)


def summarize(values):
    if not values:
        return {"n": 0}
    return {"n": len(values), "mean": round(st.mean(values), 3), "median": round(pct(values, 0.5), 3),
            "p10": round(pct(values, 0.10), 3), "p90": round(pct(values, 0.90), 3), "p95": round(pct(values, 0.95), 3)}


def bucket(frac):
    for edge, label in ((0.10, "<10%"), (0.20, "10-20%"), (0.30, "20-30%"), (0.40, "30-40%")):
        if frac < edge:
            return label
    return "40%+"


BUCKETS = ["<10%", "10-20%", "20-30%", "30-40%", "40%+"]


class Acc:
    def __init__(self):
        self.battles = []                 # per-battle dicts
        self.enemy = defaultdict(lambda: defaultdict(list))   # name -> metric -> [values]
        self.enemy_hits = defaultdict(lambda: defaultdict(int))  # name -> bucket -> count (hero hits on it)
        self.enemy_hit_raw = defaultdict(list)                 # name -> [raw hit amounts incl. blocked]
        self.hero = defaultdict(lambda: defaultdict(list))
        self.hero_face = defaultdict(lambda: defaultdict(list))  # hero:ability -> [damage per action]
        self.enemy_attack = defaultdict(list)                  # enemy name -> [dmg+block per damaging action]
        self.enemy_attack_frac = defaultdict(lambda: defaultdict(int))
        self.runs = 0
        self.run_results = []
        self.last_standing = defaultdict(list)  # enemy -> [single-enemy rounds in wins where it was last]
        self.round_threat = defaultdict(list)   # solo|multi -> [incoming (hp+block) / squad max HP per round]
        self.round_out = defaultdict(list)      # solo|multi -> [squad output per round]

    # ------------------------------------------------------------------
    def add_run(self, path):
        lines = [json.loads(l) for l in open(path, encoding="utf-8")]
        self.runs += 1
        battle = None
        for line in lines:
            t = line["type"]
            if t == "battle_start":
                battle = self._new_battle(line)
            elif t == "round" and battle is not None:
                self._round(battle, line)
            elif t == "battle_end" and battle is not None:
                self._end_battle(battle, line)
                battle = None
            elif t == "progression":
                pass
            elif t == "run_end":
                self.run_results.append((line["result"], line["battles_cleared"]))

    def _new_battle(self, line):
        return {
            "index": line["index"], "comp": line["comp"], "modifier": line.get("modifier", ""),
            "rounds": [], "enemies": {}, "hero_max": {}, "actions": [],
            "spends": defaultdict(int),
        }

    def _enemy(self, b, e):
        eid = e["target_id"]
        inst = b["enemies"].get(eid)
        if inst is None:
            label = e["target_name"] + (" (B10)" if b["index"] == 10 else "")
            inst = {"name": label, "max_hp": int(e.get("hp_max", 0)), "hp_dmg": 0, "blocked": 0,
                    "heal": 0, "revive_hp": 0, "shield_gen": 0, "hit_actions": [], "killed_round": None,
                    "first_round": None, "revives": 0, "deaths": 0, "touch_actions": set(), "dmg_out": 0}
            b["enemies"][eid] = inst
        return inst

    def _round(self, b, line):
        r = line["round"]
        rd = {"round": r, "out_hp": 0, "out_block": 0, "in_hp": 0, "in_block": 0, "dot_to_enemy": 0,
              "dot_to_hero": 0, "enemy_hp_after": sum(line.get("enemy_hp", [])),
              "alive_enemies_after": sum(1 for h in line.get("enemy_hp", []) if h > 0),
              "hero_heal": 0, "hero_shield": 0, "enemy_heal": 0, "enemy_shield": 0, "enemy_revive": 0,
              "enemy_hp_list": list(line.get("enemy_hp", []))}
        for s in line.get("spends", []):
            b["spends"][s["kind"]] += 1
        actor = None
        act = None
        prev = None
        for e in line["events"]:
            et = e["type"]
            if et == "action_start":
                actor = e
                act = {"side": e["side"], "actor": e["actor_id"], "name": e["actor_name"], "ability": e["ability"],
                       "zone": e["zone"], "types": set(), "dmg": 0, "block": 0, "hits": []}
                b["actions"].append(act)
                prev = e
                continue
            side = e.get("side")
            if side == "hero" and e.get("target_id"):
                b["hero_max"][e["target_id"]] = max(b["hero_max"].get(e["target_id"], 0), int(e.get("hp_max", 0)))
            if side == "enemy" and e.get("target_id"):
                inst = self._enemy(b, e)
                if inst["first_round"] is None:
                    inst["first_round"] = r
            own_side = actor is not None and side == actor["side"]
            if et == "damage":
                amt = int(e["amount"])
                if own_side:
                    if prev is not None and prev["type"] == "spike":
                        # spike retaliation: enemy-caused hero damage
                        rd["in_hp"] += amt
                    elif side == "enemy":
                        rd["dot_to_enemy"] += amt
                        rd["out_hp"] += amt
                        self._enemy(b, e)["hp_dmg"] += amt
                    else:
                        rd["dot_to_hero"] += amt
                        rd["in_hp"] += amt
                else:
                    if side == "enemy":
                        rd["out_hp"] += amt
                        inst = self._enemy(b, e)
                        inst["hp_dmg"] += amt
                        if act is not None:
                            act["dmg"] += amt
                            act["types"].add("damage")
                            act["hits"].append((e["target_id"], amt, int(e.get("hp_max", 1)), int(e.get("hp_after", 0))))
                    else:
                        rd["in_hp"] += amt
                        if act is not None:
                            act["dmg"] += amt
                            act["types"].add("damage")
                            act["hits"].append((e["target_id"], amt, int(e.get("hp_max", 1)), int(e.get("hp_after", 0))))
                if side == "enemy" and not own_side and act is not None:
                    self._enemy(b, e)["touch_actions"].add(id(act))
                if side == "enemy" and int(e.get("hp_after", 1)) <= 0:
                    inst = self._enemy(b, e)
                    inst["deaths"] += 1
                    if inst["killed_round"] is None or inst["revives"] > 0:
                        inst["killed_round"] = r
            elif et == "block":
                amt = int(e["amount"])
                if side == "enemy":
                    rd["out_block"] += amt
                    self._enemy(b, e)["blocked"] += amt
                else:
                    rd["in_block"] += amt
                if act is not None and not own_side and side == "enemy":
                    self._enemy(b, e)["touch_actions"].add(id(act))
                if act is not None and not own_side:
                    act["block"] += amt
                    act["types"].add("block")
            elif et in ("heal", "leech"):
                amt = int(e["amount"])
                if side == "hero":
                    rd["hero_heal"] += amt
                else:
                    rd["enemy_heal"] += amt
                    self._enemy(b, e)["heal"] += amt
                if act is not None:
                    act["types"].add("heal")
            elif et == "shield":
                amt = int(e["amount"])
                if side == "hero":
                    rd["hero_shield"] += amt
                else:
                    rd["enemy_shield"] += amt
                    self._enemy(b, e)["shield_gen"] += amt
                if act is not None:
                    act["types"].add("shield")
            elif et == "revive":
                if side == "enemy":
                    inst = self._enemy(b, e)
                    inst["revives"] += 1
                    inst["revive_hp"] += int(e.get("hp_after", 0))
                    rd["enemy_revive"] += int(e.get("hp_after", 0))
                if act is not None:
                    act["types"].add("revive")
            else:
                if act is not None:
                    act["types"].add(et)
            prev = e
        b["rounds"].append(rd)

    def _end_battle(self, b, line):
        rounds = b["rounds"]
        n = len(rounds)
        result = line["result"]
        start_enemy_hp = sum(inst["max_hp"] for inst in b["enemies"].values())
        squad_max = sum(b["hero_max"].values()) or 1
        out_per_round = [rd["out_hp"] + rd["out_block"] for rd in rounds]
        mean_out = st.mean(out_per_round) if out_per_round else 0
        hp_out_mean = st.mean([rd["out_hp"] for rd in rounds]) if rounds else 0
        # "decided": remaining enemy HP after round r is <= one average round
        # of the squad's HP damage -> it should end next round.
        decided = None
        for i, rd in enumerate(rounds):
            if rd["enemy_hp_after"] <= hp_out_mean:
                decided = i + 1
                break
        cleanup_extra = max(0, n - (decided + 1)) if (result == "victory" and decided is not None) else 0
        # Low-threat tail: consecutive final rounds of a win where incoming
        # damage (HP + blocked) stayed under 5% of squad max HP.
        tail = 0
        if result == "victory":
            for rd in reversed(rounds):
                if rd["in_hp"] + rd["in_block"] <= 0.05 * squad_max:
                    tail += 1
                else:
                    break
        # Single-enemy rounds: rounds that STARTED with exactly one enemy alive.
        single = 0
        prev_alive = len(b["comp"])
        prev_hp = None
        last_name = None
        for rd in rounds:
            bucket_key = "solo" if prev_alive == 1 else "multi"
            self.round_threat[bucket_key].append((rd["in_hp"] + rd["in_block"]) / squad_max)
            self.round_out[bucket_key].append(rd["out_hp"] + rd["out_block"])
            if prev_alive == 1:
                single += 1
                if prev_hp is not None:
                    alive_slots = [i for i, h in enumerate(prev_hp) if h > 0]
                    if alive_slots and alive_slots[0] < len(b["comp"]):
                        last_name = b["comp"][alive_slots[0]] + (" (B10)" if b["index"] == 10 else "")
            prev_alive = rd["alive_enemies_after"]
            prev_hp = rd["enemy_hp_list"]
        if result == "victory" and last_name is not None:
            self.last_standing[last_name].append(single)
        hero_actions = [a for a in b["actions"] if a["side"] == "hero"]
        enemy_actions = [a for a in b["actions"] if a["side"] == "enemy"]
        for a in enemy_actions:
            src = b["enemies"].get(a["actor"])
            if src is not None:
                src["dmg_out"] += a["dmg"] + a["block"]
        drones = [i for i in b["enemies"].values() if i["name"].startswith("Scrap Drone")]
        bosses = [i for i in b["enemies"].values() if i["name"].startswith("Scrapmaster")]
        hero_out_drone = sum(i["hp_dmg"] + i["blocked"] for i in drones)
        hero_out_boss = sum(i["hp_dmg"] + i["blocked"] for i in bosses)
        off = [a for a in hero_actions if a["types"] & {"damage", "block"}]
        sus = [a for a in hero_actions if not (a["types"] & {"damage", "block"}) and a["types"] & {"heal", "shield", "revive", "cleanse"}]
        util = [a for a in hero_actions if a not in off and a not in sus]
        rec = {
            "index": b["index"], "comp": " + ".join(sorted(b["comp"])), "modifier": b["modifier"], "result": result,
            "rounds": n, "hero_actions": len(hero_actions), "offensive_actions": len(off),
            "sustain_actions": len(sus), "utility_actions": len(util),
            "enemy_actions": len(enemy_actions),
            "dmg_dealt_hp": sum(rd["out_hp"] for rd in rounds), "dmg_blocked_by_enemy": sum(rd["out_block"] for rd in rounds),
            "dot_to_enemy": sum(rd["dot_to_enemy"] for rd in rounds),
            "dmg_taken_hp": sum(rd["in_hp"] for rd in rounds), "dmg_blocked_by_heroes": sum(rd["in_block"] for rd in rounds),
            "hero_heal": sum(rd["hero_heal"] for rd in rounds), "hero_shield_gen": sum(rd["hero_shield"] for rd in rounds),
            "enemy_heal": sum(rd["enemy_heal"] for rd in rounds), "enemy_shield_gen": sum(rd["enemy_shield"] for rd in rounds),
            "enemy_revive_hp": sum(rd["enemy_revive"] for rd in rounds),
            "start_enemy_hp": start_enemy_hp, "squad_max_hp": squad_max,
            "rerolls": b["spends"].get("reroll", 0), "nudges": b["spends"].get("nudge", 0),
            "sets": b["spends"].get("set", 0), "items": b["spends"].get("item", 0),
            "decided_round": decided, "cleanup_extra": cleanup_extra, "low_threat_tail": tail,
            "single_enemy_rounds": single, "mean_out_per_round": mean_out,
            "hero_deaths": len(line.get("deaths", [])),
            "incoming_raw": sum(rd["in_hp"] + rd["in_block"] for rd in rounds),
            "drone_kills": sum(i["deaths"] for i in drones), "rebuilds": sum(i["revives"] for i in drones),
            "boss_present": bool(bosses),
            "boss_killed_round": bosses[0]["killed_round"] if bosses else None,
            "drone_out_share": hero_out_drone / max(hero_out_drone + hero_out_boss, 1) if bosses else None,
        }
        self.battles.append(rec)
        # Per-hero action stats.
        for a in hero_actions:
            h = self.hero[a["actor"]]
            h["actions"].append(1)
            if a in off:
                h["off_dmg"].append(a["dmg"] + a["block"])
                self.hero_face[f"{a['actor']}:{a['ability']}"]["dmg"].append(a["dmg"] + a["block"])
            h["is_off"].append(1 if a in off else 0)
            h["is_sus"].append(1 if a in sus else 0)
        # Per-enemy hits + instance stats.
        for a in off:
            for (tid, amt, hmax, hafter) in a["hits"]:
                inst = b["enemies"].get(tid)
                if inst is None:
                    continue
                self.enemy_hits[inst["name"]][bucket(amt / max(hmax, 1))] += 1
                self.enemy_hit_raw[inst["name"]].append(amt)
                inst["hit_actions"].append(id(a))
        for inst in b["enemies"].values():
            name = inst["name"]
            m = self.enemy[name]
            m["max_hp"].append(inst["max_hp"])
            # Assembly Line emits `revive` AND a `heal` for the restored HP, so
            # heal already carries the rebuild; revive_hp is informational.
            m["ehp"].append(inst["max_hp"] + inst["blocked"] + inst["heal"])
            m["blocked"].append(inst["blocked"])
            m["heal"].append(inst["heal"])
            m["revive_hp"].append(inst["revive_hp"])
            m["shield_gen"].append(inst["shield_gen"])
            if inst["killed_round"] is not None:
                m["rounds_alive"].append(inst["killed_round"] - (inst["first_round"] or 1) + 1)
                m["actions_to_kill"].append(len(set(inst["hit_actions"])))
            m["killed"].append(1 if inst["killed_round"] is not None else 0)
            alive_to = inst["killed_round"] if inst["killed_round"] is not None else n
            alive = max(alive_to - (inst["first_round"] or 1) + 1, 1)
            m["dmg_out"].append(inst["dmg_out"])
            m["dmg_out_per_round"].append(inst["dmg_out"] / alive)
            if inst["killed_round"] is not None and inst["revives"] == 0:
                m["actions_to_kill_incl_block"].append(len(inst["touch_actions"]))
        for a in enemy_actions:
            if a["types"] & {"damage", "block"}:
                self.enemy_attack[a["name"]].append(a["dmg"] + a["block"])
                for (tid, amt, hmax, hafter) in a["hits"]:
                    self.enemy_attack_frac[a["name"]][bucket(amt / max(hmax, 1))] += 1

    # ------------------------------------------------------------------
    def report(self):
        wins = [b for b in self.battles if b["result"] == "victory"]
        by_index = defaultdict(list)
        for b in self.battles:
            by_index[b["index"]].append(b)
        by_comp = defaultdict(list)
        for b in self.battles:
            by_comp[(b["index"] == 10, b["comp"])].append(b)

        def block(bs):
            won = [b for b in bs if b["result"] == "victory"]
            tot_rounds = sum(b["rounds"] for b in won) or 1
            return {
                "battles": len(bs), "win_rate": round(len(won) / max(len(bs), 1), 3),
                "rounds_win": summarize([b["rounds"] for b in won]),
                "hero_actions_win": summarize([b["hero_actions"] for b in won]),
                "offensive_actions_win": summarize([b["offensive_actions"] for b in won]),
                "sustain_share": round(sum(b["sustain_actions"] for b in won) / max(sum(b["hero_actions"] for b in won), 1), 3),
                "dmg_dealt_hp": summarize([b["dmg_dealt_hp"] for b in won]),
                "dmg_blocked_by_enemy": summarize([b["dmg_blocked_by_enemy"] for b in won]),
                "dmg_taken_hp": summarize([b["dmg_taken_hp"] for b in won]),
                "dmg_blocked_by_heroes": summarize([b["dmg_blocked_by_heroes"] for b in won]),
                "hero_heal": summarize([b["hero_heal"] for b in won]),
                "hero_shield_gen": summarize([b["hero_shield_gen"] for b in won]),
                "enemy_heal": summarize([b["enemy_heal"] for b in won]),
                "enemy_revive_hp": summarize([b["enemy_revive_hp"] for b in won]),
                "start_enemy_hp": summarize([b["start_enemy_hp"] for b in won]),
                "rerolls": summarize([b["rerolls"] for b in won]),
                "nudges": summarize([b["nudges"] for b in won]),
                "cleanup_extra": summarize([b["cleanup_extra"] for b in won]),
                "cleanup_share": round(sum(b["cleanup_extra"] for b in won) / tot_rounds, 3),
                "battles_with_cleanup_ge2": round(sum(1 for b in won if b["cleanup_extra"] >= 2) / max(len(won), 1), 3),
                "low_threat_tail": summarize([b["low_threat_tail"] for b in won]),
                "low_threat_share": round(sum(b["low_threat_tail"] for b in won) / tot_rounds, 3),
                "single_enemy_rounds": summarize([b["single_enemy_rounds"] for b in won]),
                "out_per_round": summarize([b["mean_out_per_round"] for b in won]),
                "hero_deaths_per_battle": round(sum(b["hero_deaths"] for b in bs) / max(len(bs), 1), 3),
                "flawless_win_share": round(sum(1 for b in won if b["hero_deaths"] == 0) / max(len(won), 1), 3),
                "dmg_taken_all": summarize([b["dmg_taken_hp"] for b in bs]),
                "incoming_raw_all": summarize([b["incoming_raw"] for b in bs]),
                "incoming_per_round_all": summarize([b["incoming_raw"] / max(b["rounds"], 1) for b in bs]),
                "drone_kills": summarize([b["drone_kills"] for b in bs if b["boss_present"]]),
                "rebuilds": summarize([b["rebuilds"] for b in bs if b["boss_present"]]),
                "boss_kill_round": summarize([b["boss_killed_round"] for b in bs if b["boss_killed_round"] is not None]),
                "drone_out_share": summarize([b["drone_out_share"] for b in bs if b["drone_out_share"] is not None]),
                "rounds_after_boss_dead_win": summarize([b["rounds"] - b["boss_killed_round"] for b in won if b["boss_killed_round"] is not None]),
            }

        out = {
            "runs": self.runs,
            "clear_rate": round(sum(1 for r in self.run_results if r[0] == "victory") / max(len(self.run_results), 1), 3),
            "all_battles": block(self.battles),
            "by_index": {i: block(bs) for i, bs in sorted(by_index.items())},
            "by_comp": {f"{'B10 ' if k[0] else ''}{k[1]}": block(bs) for k, bs in sorted(by_comp.items(), key=lambda kv: -len(kv[1])) if len(bs) >= 20},
            "enemies": {}, "heroes": {}, "hero_faces": {}, "enemy_attacks": {},
        }
        for name, m in self.enemy.items():
            hits = self.enemy_hits[name]
            tot = sum(hits.values()) or 1
            out["enemies"][name] = {
                "instances": len(m["max_hp"]), "max_hp": summarize(m["max_hp"]), "effective_hp": summarize(m["ehp"]),
                "blocked": summarize(m["blocked"]), "heal": summarize(m["heal"]), "revive_hp": summarize(m["revive_hp"]),
                "shield_gen": summarize(m["shield_gen"]),
                "rounds_alive_to_kill": summarize(m["rounds_alive"]), "hero_actions_to_kill": summarize(m["actions_to_kill"]),
                "kill_rate": round(sum(m["killed"]) / max(len(m["killed"]), 1), 3),
                "hit_size": summarize(self.enemy_hit_raw[name]),
                "hit_buckets": {k: round(hits.get(k, 0) / tot, 3) for k in BUCKETS},
                "dmg_out": summarize(m["dmg_out"]), "dmg_out_per_round": summarize(m["dmg_out_per_round"]),
                "actions_to_kill_incl_block": summarize(m["actions_to_kill_incl_block"]),
            }
        for hid, h in self.hero.items():
            out["heroes"][hid] = {
                "actions": len(h["actions"]), "offensive_share": round(st.mean(h["is_off"]), 3) if h["is_off"] else 0,
                "sustain_share": round(st.mean(h["is_sus"]), 3) if h["is_sus"] else 0,
                "dmg_per_offensive_action": summarize(h["off_dmg"]),
            }
        for key, f in self.hero_face.items():
            if len(f["dmg"]) >= 30:
                out["hero_faces"][key] = summarize(f["dmg"])
        out["round_threat"] = {k: {"incoming_pct_squad_hp": summarize(v), "rounds": len(v),
                                   "share_rounds_under_5pct": round(sum(1 for x in v if x <= 0.05) / max(len(v), 1), 3),
                                   "squad_output": summarize(self.round_out[k])}
                               for k, v in self.round_threat.items()}
        tot_wins = sum(len(v) for v in self.last_standing.values()) or 1
        out["last_standing"] = {n: {"share_of_wins": round(len(v) / tot_wins, 3), "solo_rounds": summarize(v)}
                                for n, v in sorted(self.last_standing.items(), key=lambda kv: -len(kv[1]))}
        for name, vals in self.enemy_attack.items():
            fr = self.enemy_attack_frac[name]
            tot = sum(fr.values()) or 1
            out["enemy_attacks"][name] = {"dmg_per_damaging_action": summarize(vals),
                                          "hit_buckets": {k: round(fr.get(k, 0) / tot, 3) for k in BUCKETS}}
        return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("dirs", nargs="+")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--max-runs", type=int, default=0, help="first N seeds per batch (matched-seed comparisons)")
    args = ap.parse_args()
    acc = Acc()
    for d in args.dirs:
        paths = sorted(glob.glob(str(Path(d) / "run_*.jsonl")))
        if args.max_runs:
            paths = paths[:args.max_runs]
        for path in paths:
            acc.add_run(path)
    rep = acc.report()
    Path(args.out).write_text(json.dumps(rep, indent=1))
    print(f"[ANALYZE] {acc.runs} runs, {len(acc.battles)} battles -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
