"""Combat-sponginess benchmark (2026-09) — analytic 1v1 time-to-kill model.
MEASUREMENT ONLY. Reads the runtime dump (dump_balance.gd), never game code.

Isolates raw durability from squad play: ONE hero kit attacks ONE enemy until
it dies (uniform d20, no Protocol spends, no items/relics/gear, no squad
support), while that enemy plays its own kit on the same clock (its shields
last one opposing phase, heals apply). The reverse direction runs each
enemy's kit against one hero's raw HP. What the model keeps (mirrors
combat_manager): one-round shields (enemy-phase shields cover the next hero
phase), ignSh/breach bypass, burn stacks ticking at the burning unit's action,
detonate = sum(amt * turns_left), execute +8 below 25%, mark +50% next hit,
self-heal. What it drops: chain/blast splash (single target only), roll
buffs/debuffs, jam, freeze, spike, taunt, cloak, summons, boss cadences except
where noted in the report. Use it for RELATIVE durability; the sim is the
source for absolute encounter pacing.

  python tools/sponginess/model.py -o results/sponginess/model.json
"""
import argparse
import json
import random
import statistics as st
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BALANCE = ROOT / "results" / "sponginess" / "balance_facility.json"
TRIALS = 4000
EXECUTE_BONUS = 8
EXECUTE_PCT = 25


def face_for(kit, roll):
    for z in kit:
        if z["min"] <= roll <= z["max"]:
            return z["raw"]
    return kit[-1]["raw"]


def num(raw, key):
    v = raw.get(key, 0)
    try:
        return float(v or 0)
    except (TypeError, ValueError):
        return 0.0


def hero_vs_enemy(kit, enemy, hp_mult=1.0, dmg_mult=1.0, rng=None, max_rounds=60):
    ehp = max(1, round(enemy["hp"] * hp_mult))
    hp = ehp
    shield = 0            # enemy shield covering the coming hero phase
    burns = []            # [amt, turns_left]
    marked = False
    actions = 0
    hits = []
    ekit = enemy["zones"]
    for _ in range(max_rounds):
        # Enemy burn ticks at its own action; resolve at start of its phase below.
        raw = face_for(kit, rng.randint(1, 20))
        actions += 1
        dmg = round(num(raw, "dmg") * dmg_mult)
        if dmg > 0:
            if marked:
                dmg = int(-(-dmg * 1.5 // 1))
                marked = False
            if raw.get("breach") or raw.get("ignSh"):
                absorbed = 0
                if raw.get("breach"):
                    shield = 0
            else:
                absorbed = min(shield, dmg)
                shield -= absorbed
            real = dmg - absorbed
            hp -= real
            hits.append((dmg, real))
            if raw.get("detonate") and burns:
                burst = sum(a * t for a, t in burns)
                burns = []
                hp -= burst
            if hp > 0 and raw.get("execute") and hp * 100 < ehp * EXECUTE_PCT:
                hp -= EXECUTE_BONUS
        if raw.get("mark"):
            marked = True
        if num(raw, "burn") > 0:
            burns.append([num(raw, "burn"), max(1, int(num(raw, "burnT")))])
        if hp <= 0:
            return actions, hits
        # Hero-phase shields on the enemy expire at the round tick; the enemy
        # now acts: burn tick first, then its face.
        shield = 0
        if burns:
            hp -= sum(a for a, _ in burns)
            burns = [[a, t - 1] for a, t in burns if t - 1 > 0]
            if hp <= 0:
                return actions, hits
        eraw = face_for(ekit, rng.randint(1, 20))
        shield += int(num(eraw, "shield") + num(eraw, "shieldAlly"))
        hp = min(ehp, hp + int(num(eraw, "heal")))
    return actions, hits


def enemy_vs_hero(ekit, hero_hp, dmg_mult=1.0, rng=None, max_rounds=60):
    hp = hero_hp
    actions = 0
    burns = []
    for _ in range(max_rounds):
        if burns:
            hp -= sum(a for a, _ in burns)
            burns = [[a, t - 1] for a, t in burns if t - 1 > 0]
            if hp <= 0:
                return actions
        raw = face_for(ekit, rng.randint(1, 20))
        actions += 1
        dmg = round(num(raw, "dmg") * dmg_mult)
        hp -= dmg
        if num(raw, "burn") > 0:
            burns.append([num(raw, "burn"), max(1, int(num(raw, "burnT")))])
        if hp <= 0:
            return actions
    return actions


def summ(values):
    s = sorted(values)
    return {"mean": round(st.mean(s), 2), "median": s[len(s) // 2], "p10": s[int(len(s) * 0.10)], "p90": s[int(len(s) * 0.90)]}


def face_table(kit, target_hp):
    rows = []
    for z in kit:
        raw = z["raw"]
        dmg = num(raw, "dmg")
        rows.append({"zone": z["zone"], "range": [z["min"], z["max"]], "name": z["name"], "dmg": dmg,
                     "burn": num(raw, "burn"), "burnT": num(raw, "burnT"),
                     "pct_of_target": round(dmg / target_hp, 3) if target_hp else 0,
                     "p_face": (z["max"] - z["min"] + 1) / 20})
    return rows


def expected_face_dmg(kit):
    return sum(num(z["raw"], "dmg") * (z["max"] - z["min"] + 1) / 20 for z in kit)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--hp-mult", type=float, default=1.0)
    ap.add_argument("--dmg-mult", type=float, default=1.0)
    args = ap.parse_args()
    data = json.loads(BALANCE.read_text())
    rng = random.Random(20260921)
    out = {"hero_vs_enemy": {}, "enemy_vs_hero": {}, "hero_kits": {}, "enemy_kits": {}}
    kits = {}
    for hid, h in data["heroes"].items():
        kits[f"{hid}/base"] = (h["base"], h["hp"])
        for e in h["evolutions"]:
            kits[f"{hid}/{e['name']}"] = (e["abilities"], e["hp"] or h["hp"])
    for key, (kit, hp) in kits.items():
        out["hero_kits"][key] = {"hp": hp, "expected_face_dmg": round(expected_face_dmg(kit), 2),
                                 "p_zero_dmg_face": round(sum((z["max"] - z["min"] + 1) / 20 for z in kit if num(z["raw"], "dmg") <= 0), 2)}
    for name, en in data["enemies"].items():
        ek = en["zones"]
        out["enemy_kits"][name] = {"hp": en["hp"], "role": en["role"], "expected_face_dmg": round(expected_face_dmg(ek), 2),
                                   "expected_self_shield_per_round": round(sum((num(z["raw"], "shield") + num(z["raw"], "shieldAlly")) * (z["max"] - z["min"] + 1) / 20 for z in ek), 2),
                                   "expected_self_heal_per_round": round(sum(num(z["raw"], "heal") * (z["max"] - z["min"] + 1) / 20 for z in ek), 2),
                                   "faces": face_table(ek, 0)}
        for key, (kit, hp) in kits.items():
            acts, fracs, lowfrac = [], [], 0
            for _ in range(TRIALS):
                a, hits = hero_vs_enemy(kit, en, args.hp_mult, args.dmg_mult, rng)
                acts.append(a)
                for dmg, real in hits:
                    fracs.append(real / en["hp"])
                    if real / en["hp"] < 0.10:
                        lowfrac += 1
            out["hero_vs_enemy"].setdefault(name, {})[key] = {
                "actions_to_kill": summ(acts),
                "mean_pct_hp_per_hit": round(st.mean(fracs), 3) if fracs else 0,
                "share_hits_under_10pct": round(lowfrac / max(len(fracs), 1), 3)}
        for key, (kit, hp) in kits.items():
            acts = [enemy_vs_hero(ek, hp, 1.0, rng) for _ in range(TRIALS)]
            out["enemy_vs_hero"].setdefault(name, {})[key] = {"actions_to_kill": summ(acts), "hero_hp": hp}
    Path(args.out).write_text(json.dumps(out, indent=1))
    print(f"[MODEL] {len(kits)} kits x {len(data['enemies'])} enemies -> {args.out}")


if __name__ == "__main__":
    main()
