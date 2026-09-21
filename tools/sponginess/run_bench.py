"""Combat-sponginess benchmark (2026-09) — batch orchestrator. MEASUREMENT ONLY.

Drives scripts/sim/batch.py (the real combat_manager, headless, seeded) over a
fixed set of Facility squads and tuning scenarios. Every scenario reuses the
same seed range, so points differ only by the scenario's knobs. Nothing here
writes game data: knobs ride the sim's in-memory --tuning / --enemy-hp seams.

  python tools/sponginess/run_bench.py --scenarios baseline --runs 600
  python tools/sponginess/run_bench.py --scenarios hp85,dmg115 --runs 400
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BATCH = ROOT / "scripts" / "sim" / "batch.py"
OUT_ROOT = ROOT / "results" / "sponginess"
BALANCE = OUT_ROOT / "balance_facility.json"

SQUADS = {
    "default": "combat,engineer,medic",     # new-player default selection
    "highdmg": "combat,pulse,ghost",
    "defensive": "shield,medic,engineer",
    "mix_pcs": "pulse,combat,shield",        # sim/CI default squad
    "mix_cmb": "combat,medic,breaker",
    "mix_apm": "avalanche,pulse,medic",
    "mix_gse": "ghost,shield,engineer",
}


def hero_damage_spec(mult: float) -> str:
    """ability_field tuning keys scaling every hero ability's direct damage
    (dmg/dMin/dMax) by mult, rounded to whole numbers (the engine's ints)."""
    data = json.loads(BALANCE.read_text())
    keys = []
    for hid, hero in data["heroes"].items():
        kits = [("base", hero["base"])] + [(e["name"], e["abilities"]) for e in hero["evolutions"]]
        for path, kit in kits:
            for ab in kit:
                raw = ab["raw"]
                dmg = float(raw.get("dmg", 0) or 0)
                if dmg <= 0:
                    continue
                new = int(round(dmg * mult))
                for field in ("dmg", "dMin", "dMax"):
                    keys.append(f"ability:{hid}/{path}/{ab['name']}/{field}={new}")
    return ",".join(keys)


def weak_face_spec(max_dmg: int, bonus: int) -> str:
    """+bonus direct damage on every hero face whose damage is 1..max_dmg
    (the low rolls that barely move a health bar); other faces untouched."""
    data = json.loads(BALANCE.read_text())
    keys = []
    for hid, hero in data["heroes"].items():
        kits = [("base", hero["base"])] + [(e["name"], e["abilities"]) for e in hero["evolutions"]]
        for path, kit in kits:
            for ab in kit:
                dmg = float(ab["raw"].get("dmg", 0) or 0)
                if 0 < dmg <= max_dmg:
                    for field in ("dmg", "dMin", "dMax"):
                        keys.append(f"ability:{hid}/{path}/{ab['name']}/{field}={int(dmg) + bonus}")
    return ",".join(keys)


# Targeted package C (baseline evidence, see the report): Shield Enforcer
# ally/self shields cut ~40%, Heavy Warden HP 110->95 with its self-heals
# 7->4 / 6->3, Scrapmaster Assembly Line rebuild 50% -> 25%.
GUARD_SHIELD_CUT = {"recharge": 4, "strike": 4, "surge": 5, "crit": 4, "overload": 8}
C_TUNING = ",".join([f"enemy_ability:Shield Enforcer/{z}/shieldAlly={v}" for z, v in GUARD_SHIELD_CUT.items()] +
                    ["enemy_ability:Heavy Warden/recharge/heal=4", "enemy_ability:Heavy Warden/overload/heal=3",
                     "scrapmaster_rebuild_pct=25"])
C_ENEMY_HP = "Heavy Warden=95"


def enemy_damage_spec(names, mult: float) -> str:
    """enemy_ability keys scaling the named enemies' face damage (dmg field)."""
    data = json.loads(BALANCE.read_text())
    keys = []
    for name in names:
        for z in data["enemies"][name]["zones"]:
            dmg = float(z["raw"].get("dmg", 0) or 0)
            if dmg > 0:
                keys.append(f"enemy_ability:{name}/{z['zone']}/dmg={int(round(dmg * mult))}")
    return ",".join(keys)


def join(*specs):
    return ",".join(x for x in specs if x)


def enemy_hp_spec(overrides: dict) -> str:
    data = json.loads(BALANCE.read_text())
    parts = []
    for name, mult in overrides.items():
        base = int(data["enemies"][name]["hp"])
        parts.append(f"{name}={int(round(base * mult))}")
    return ";".join(parts)


# name -> dict(tuning=..., enemy_hp=...). Filled lazily (needs the dump).
def scenarios() -> dict:
    s = {"baseline": {}}
    for pct in (90, 85, 80, 75):
        s[f"hp{pct}"] = {"tuning": f"enemy_hp_scalar@facility={pct / 100}"}
    for pct in (110, 115, 120):
        s[f"dmg{pct}"] = {"tuning": hero_damage_spec(pct / 100)}
    s["C_targeted"] = {"tuning": C_TUNING, "enemy_hp": C_ENEMY_HP}
    s["D_mixed"] = {"tuning": join("enemy_hp_scalar@facility=0.9", C_TUNING, weak_face_spec(6, 2)), "enemy_hp": C_ENEMY_HP}
    s["E_fast_deadly"] = {"tuning": "enemy_hp_scalar@facility=0.8,enemy_dmg_scalar@facility=1.15"}
    s["F_targeted_threat"] = {"tuning": join(C_TUNING, "enemy_dmg_scalar@facility=1.1"), "enemy_hp": C_ENEMY_HP}
    # Round 2 (after the first scenario read): Volt Enforcer is the low-threat
    # / high-durability outlier the targeted package missed.
    c2_hp = C_ENEMY_HP + ";Volt Enforcer=65"
    s["C2_targeted_volt"] = {"tuning": C_TUNING, "enemy_hp": c2_hp}
    s["G_hp85_dmg110"] = {"tuning": "enemy_hp_scalar@facility=0.85,enemy_dmg_scalar@facility=1.1"}
    s["H_C2_punchy"] = {"tuning": join(C_TUNING, weak_face_spec(6, 2), "enemy_dmg_scalar@facility=1.1"), "enemy_hp": c2_hp}
    # Round 3: give the difficulty back ONLY on the units that lost durability
    # (their own damage faces +20%), and a calibrated global both-sides cut.
    s["I_C2_threat_on_tuned"] = {"tuning": join(C_TUNING, enemy_damage_spec(
        ["Shield Enforcer", "Heavy Warden", "Volt Enforcer", "Scrapmaster"], 1.2)), "enemy_hp": c2_hp}
    s["E2_hp80_dmg125"] = {"tuning": "enemy_hp_scalar@facility=0.8,enemy_dmg_scalar@facility=1.25"}
    s.update(k_scenarios())
    return s


# Round 4 (Kev 2026-09-21): durability -> threat trades on the three genuine
# sponge outliers ONLY. Scrapmaster is untouched in every K scenario:
# Assembly Line stays at 50% (intentional; re-killing drones is a trap).
# Each tier: Shield Enforcer shieldAlly per zone, Heavy Warden HP + heals
# (recharge/overload), Volt Enforcer HP, and a face-damage multiplier applied
# to the same three enemies.
K_TIERS = {
    "light": {"se_shield": (5, 5, 7, 5, 10), "hw_hp": 100, "hw_heal": (5, 4), "volt_hp": 70},
    "mid":   {"se_shield": (4, 4, 5, 4, 8),  "hw_hp": 95,  "hw_heal": (4, 3), "volt_hp": 65},
    "deep":  {"se_shield": (3, 3, 4, 4, 6),  "hw_hp": 90,  "hw_heal": (3, 2), "volt_hp": 60},
}
ZONES = ("recharge", "strike", "surge", "crit", "overload")


def k_package(tier: str, dmg_mult, only: str = "") -> dict:
    """only: "" = all three, else one of se|hw|volt (attribution runs).
    dmg_mult: one multiplier, or {"se"|"hw"|"volt": mult} per enemy."""
    t = K_TIERS[tier]
    tuning, hp, dmg_names = [], [], []
    if isinstance(dmg_mult, dict):
        key = {"Shield Enforcer": "se", "Heavy Warden": "hw", "Volt Enforcer": "volt"}
        out = k_package(tier, 1.0, only)
        out["tuning"] = join(",".join(x for x in out["tuning"].split(",") if "/dmg=" not in x),
                             *[enemy_damage_spec([n], m) for n, k in key.items() for m in [dmg_mult[k]]
                               if only in ("", k)])
        return out
    if only in ("", "se"):
        tuning += [f"enemy_ability:Shield Enforcer/{z}/shieldAlly={v}" for z, v in zip(ZONES, t["se_shield"])]
        dmg_names.append("Shield Enforcer")
    if only in ("", "hw"):
        tuning += [f"enemy_ability:Heavy Warden/recharge/heal={t['hw_heal'][0]}",
                   f"enemy_ability:Heavy Warden/overload/heal={t['hw_heal'][1]}"]
        hp.append(f"Heavy Warden={t['hw_hp']}")
        dmg_names.append("Heavy Warden")
    if only in ("", "volt"):
        hp.append(f"Volt Enforcer={t['volt_hp']}")
        dmg_names.append("Volt Enforcer")
    return {"tuning": join(",".join(tuning), enemy_damage_spec(dmg_names, dmg_mult)), "enemy_hp": ";".join(hp)}


def k_scenarios() -> dict:
    return {
        "K_light_d110": k_package("light", 1.10),
        "K_mid_d110": k_package("mid", 1.10),
        "K_mid_d120": k_package("mid", 1.20),
        "K_mid_d130": k_package("mid", 1.30),
        "K_deep_d130": k_package("deep", 1.30),
        "K_deep_d140": k_package("deep", 1.40),
        "Kse_mid_d120": k_package("mid", 1.20, "se"),
        "Khw_mid_d120": k_package("mid", 1.20, "hw"),
        "Kvolt_mid_d120": k_package("mid", 1.20, "volt"),
        # Round 4b: per-enemy calibration from the isolation runs.
        "K_mid_cal1": k_package("mid", {"se": 1.15, "hw": 1.20, "volt": 1.10}),
        "K_mid_cal2": k_package("mid", {"se": 1.15, "hw": 1.20, "volt": 1.15}),
        "K_mid_cal3": k_package("mid", {"se": 1.15, "hw": 1.10, "volt": 1.10}),
        # Round 4c: final confirmation package (Kev 2026-09-21) — explicit faces.
        "K_final": k_final(),
        # Live data after the package landed: no overrides (must reproduce K_final).
        "live_final": {},
    }


def k_final() -> dict:
    out = k_package("mid", 1.0)
    faces = {"Shield Enforcer": (13, 12, 17, 21), "Heavy Warden": (12, 12, 26, 32), "Volt Enforcer": (10, 12, 14, 16)}
    dmg = [f"enemy_ability:{n}/{z}/dmg={v}" for n, vals in faces.items()
           for z, v in zip(("strike", "surge", "crit", "overload"), vals)]
    out["tuning"] = join(",".join(x for x in out["tuning"].split(",") if "/dmg=" not in x), ",".join(dmg))
    return out


def extra_scenarios() -> dict:
    """Targeted / mixed / both-sides scenarios (defined after the baseline
    read; see the report for the evidence behind each)."""
    return json.loads((OUT_ROOT / "extra_scenarios.json").read_text()) if (OUT_ROOT / "extra_scenarios.json").exists() else {}


def run(name: str, squad_key: str, cfg: dict, runs: int, policy: str, seed_base: int) -> None:
    batch_name = f"sponginess/{name}__{squad_key}__{policy}"
    cmd = [sys.executable, str(BATCH), "--name", batch_name, "--runs", str(runs),
           "--policy", policy, "--op", "facility", "--seed-base", str(seed_base)]
    if squad_key != "random":
        cmd += ["--squad", SQUADS[squad_key]]
    if cfg.get("tuning"):
        cmd += ["--tuning", cfg["tuning"]]
    if cfg.get("enemy_hp"):
        cmd += ["--enemy-hp", cfg["enemy_hp"]]
    print(f"[BENCH] {batch_name}", flush=True)
    subprocess.run(cmd, check=True, cwd=ROOT)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scenarios", default="baseline")
    ap.add_argument("--squads", default=",".join(list(SQUADS) + ["random"]))
    ap.add_argument("--runs", type=int, default=600)
    ap.add_argument("--policy", default="l1")
    ap.add_argument("--seed-base", type=int, default=500000)
    args = ap.parse_args()
    table = scenarios()
    table.update(extra_scenarios())
    for name in args.scenarios.split(","):
        cfg = table[name]
        for squad_key in args.squads.split(","):
            run(name, squad_key, cfg, args.runs, args.policy, args.seed_base)
    return 0


if __name__ == "__main__":
    sys.exit(main())
