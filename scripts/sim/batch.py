#!/usr/bin/env python3
"""Balance-sim batch driver (Package C.1).

Spawns N parallel headless Godot workers, each running one seeded sim run to a
JSONL file, plus a manifest.json describing the batch (so a batch is
reproducible from its manifest alone).

  # 2000 L1 runs, uniform-random squads + ops (the Stage-1 regression pool)
  python scripts/sim/batch.py --name screen_l1 --runs 2000 --policy l1

  # a forced-content A/B arm on fixed config (Stage-2)
  python scripts/sim/batch.py --name coldlogic_arm --runs 1000 --policy l1 \\
      --squad avalanche,combat,pulse --op stellarMenagerie --grant coldLogic
  python scripts/sim/batch.py --name coldlogic_ctrl --runs 1000 --policy l1 \\
      --squad avalanche,combat,pulse --op stellarMenagerie   # matched seeds

Determinism: run seed = base-seed + index; random squad/op (when not fixed) are
drawn from a Python RNG seeded with base-seed, so the whole batch reproduces.
Each worker is itself byte-deterministic (the sim's own guarantee).
"""
import argparse
import concurrent.futures
import json
import os
import random
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_GODOT = r"C:\Users\Kev\Downloads\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
SCENE = "res://scenes/sim/sim_main.tscn"

# Canonical roster / operations (GROUND_TRUTH.md; internal ids are stable).
HEROES = ["pulse", "combat", "shield", "avalanche", "medic", "engineer", "ghost", "breaker"]
OPS = ["facility", "hive", "veil", "voidCirclet", "stellarMenagerie"]


def godot_bin() -> str:
    return os.environ.get("GODOT", DEFAULT_GODOT)


def run_one(seed: int, squad: str, op: str, policy: str, grant: str, archetype: str, tuning: str, pool_buckets: str, battle_slots: str, enemy_hp: str, hero_hp: str, item_field: str, order_mode: str, out_path: Path) -> dict:
    args = [godot_bin(), "--headless", "--path", str(ROOT), SCENE, "--",
            "--seed", str(seed), "--squad", squad, "--op", op,
            "--policy", policy, "--out", str(out_path)]
    if grant:
        args += ["--grant", grant]
    if order_mode:
        args += ["--order-mode", order_mode]
    if archetype:
        args += ["--archetype", archetype]
    if tuning:
        args += ["--tuning", tuning]
    if pool_buckets != "":
        args += ["--pool-buckets", pool_buckets]
    if battle_slots:
        args += ["--battle-slots", battle_slots]
    if enemy_hp:
        args += ["--enemy-hp", enemy_hp]
    if hero_hp:
        args += ["--hero-hp", hero_hp]
    if item_field:
        args += ["--item-field", item_field]
    t0 = time.time()
    proc = subprocess.run(args, capture_output=True, text=True)
    if proc.returncode != 0:
        # Transient parallel-spawn flake (observed ~0.2% under a full worker
        # pool, 0xC0000409, not seed-reproducible — Cycle 0). The sim is
        # deterministic, so one retry is safe: same seed+config, same bytes.
        proc = subprocess.run(args, capture_output=True, text=True)
    return {"seed": seed, "rc": proc.returncode, "secs": round(time.time() - t0, 2),
            "out": str(out_path), "stderr_tail": proc.stderr.strip().splitlines()[-1:] if proc.returncode else []}


def main() -> int:
    ap = argparse.ArgumentParser(description="Parallel balance-sim batch runner")
    ap.add_argument("--name", required=True, help="batch name -> results/<name>/")
    ap.add_argument("--runs", type=int, default=1000)
    ap.add_argument("--policy", default="l1")
    ap.add_argument("--seed-base", type=int, default=100000)
    ap.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 4) - 1))
    ap.add_argument("--squad", default="", help="fixed squad (else uniform 3-of-8 per run)")
    ap.add_argument("--include-hero", default="",
                    help="forced-inclusion arm: squad = this hero + 2 uniform from the rest (portfolio cells)")
    ap.add_argument("--op", default="", help="fixed op (else uniform per run)")
    ap.add_argument("--grant", default="", help="forced content ids for a Stage-2 arm")
    ap.add_argument("--archetype", default="", help="draft bias: burn|control|protocol|value")
    ap.add_argument("--tuning", default="",
                    help="balance-workbench knobs 'key[@op]=value,...' (scripts/sim/knobs.json; measurement only)")
    ap.add_argument("--pool-buckets", default="",
                    help="restrict draft pools to unlock buckets 0..N (harness-side, NON-baseline; '0' = new-player pool)")
    ap.add_argument("--battle-slots", default="",
                    help="in-memory slot-template override 'N=slot,slot;...' (comp instrument, measurement only)")
    ap.add_argument("--enemy-hp", default="",
                    help="in-memory enemy data max_hp override 'Name=hp;...' (bake preview, measurement only)")
    ap.add_argument("--hero-hp", default="",
                    help="in-memory hero data max_hp override 'id=hp;...' (sweep instrument, measurement only)")
    ap.add_argument("--item-field", default="",
                    help="in-memory ItemData.effect override 'id/key=value;...' (sweep instrument, measurement only)")
    ap.add_argument("--order-mode", default="",
                    help="L2 cast-order mode: search (default) | setups | squad (the ordering A/B seam)")
    ap.add_argument("--out-root", default=str(ROOT / "results"))
    args = ap.parse_args()

    out_dir = Path(args.out_root) / args.name
    out_dir.mkdir(parents=True, exist_ok=True)

    picker = random.Random(args.seed_base)  # reproducible squad/op draws
    jobs = []
    others = [h for h in HEROES if h != args.include_hero]
    for i in range(args.runs):
        seed = args.seed_base + i
        if args.include_hero:
            squad = ",".join([args.include_hero] + picker.sample(others, 2))
        else:
            squad = args.squad or ",".join(picker.sample(HEROES, 3))
        op = args.op or picker.choice(OPS)
        jobs.append((seed, squad, op, args.policy, args.grant, args.archetype, args.tuning, args.pool_buckets, args.battle_slots, args.enemy_hp, args.hero_hp, args.item_field, args.order_mode, out_dir / f"run_{seed}.jsonl"))

    manifest = {
        "name": args.name, "runs": args.runs, "policy": args.policy,
        "seed_base": args.seed_base, "squad": args.squad or "random",
        "include_hero": args.include_hero,
        "op": args.op or "random", "grant": args.grant,
        "archetype": args.archetype, "tuning": args.tuning,
        "pool_buckets": args.pool_buckets, "battle_slots": args.battle_slots,
        "enemy_hp": args.enemy_hp, "hero_hp": args.hero_hp,
        "item_field": args.item_field, "order_mode": args.order_mode,
        "godot": godot_bin(),
    }
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2))

    print(f"[BATCH] {args.name}: {args.runs} runs, policy={args.policy}, "
          f"{args.workers} workers -> {out_dir}")
    t0 = time.time()
    done = 0
    failures = 0
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        futs = [pool.submit(run_one, *job) for job in jobs]
        for fut in concurrent.futures.as_completed(futs):
            res = fut.result()
            done += 1
            if res["rc"] != 0:
                failures += 1
                print(f"  ! seed {res['seed']} rc={res['rc']} {res['stderr_tail']}", file=sys.stderr)
            if done % max(1, args.runs // 20) == 0 or done == args.runs:
                elapsed = time.time() - t0
                rate = done / elapsed * 60 if elapsed else 0
                print(f"  {done}/{args.runs}  ({rate:.0f} runs/min, {failures} failed)")
    elapsed = time.time() - t0
    print(f"[BATCH] {args.name} done: {done} runs in {elapsed:.1f}s, {failures} failed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
