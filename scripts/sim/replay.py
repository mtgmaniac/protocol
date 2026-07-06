#!/usr/bin/env python3
"""Balance-sim replay printer (Package B.4).

Renders a sim JSONL file (schema: telemetry_schema.md) as a human-readable
run replay. Zero dependencies; pure stdlib.

  python scripts/sim/replay.py results/run_12345.jsonl
  python scripts/sim/replay.py results/run_12345.jsonl --battle 3   # one battle
  python scripts/sim/replay.py results/run_12345.jsonl --rounds     # per-round detail (default)
  python scripts/sim/replay.py results/run_12345.jsonl --summary    # battles + picks only
"""
import argparse
import json
import sys

# Event types whose amount reads as damage-ish (red channel) vs support.
DAMAGE_EVENTS = {"damage", "burn", "chain", "detonate", "spike", "execute"}
SUPPORT_EVENTS = {"heal", "shield", "roll_buff"}


def fmt_rolls(raw: dict, eff: dict) -> str:
    parts = []
    for uid in raw:
        r = raw[uid]
        e = eff.get(uid, r)
        parts.append(f"{uid} {r}" if int(e) == int(r) else f"{uid} {r}->{e}")
    return ", ".join(parts) if parts else "-"


def fmt_event(ev: dict) -> str | None:
    t = ev.get("type", "")
    amt = ev.get("amount", 0)
    tgt = ev.get("target_name", ev.get("target_id", "?"))
    if t == "action_start":
        zone = ev.get("zone", "")
        zone_sfx = f" [{zone}]" if zone else ""
        return f"{ev.get('actor_name', '?')} uses {ev.get('ability', '?')}{zone_sfx}"
    if t in DAMAGE_EVENTS:
        hp = ev.get("hp_after", None)
        hp_sfx = f" (hp {hp})" if hp is not None else ""
        return f"  {t}: {tgt} -{amt}{hp_sfx}"
    if t in SUPPORT_EVENTS:
        return f"  {t}: {tgt} +{amt}"
    if t == "summon":
        return f"  summon: {ev.get('summon_name', '?')} (by {tgt})"
    if t == "freeze":
        return f"  freeze: {tgt} die locked at {amt}"
    if t == "block":
        return f"  {'firewall NEGATES' if int(amt) <= 0 else f'shield blocks {amt}'}: {tgt}"
    if t in ("jam", "rewrite", "hijack", "mark", "siphon", "leech", "breach",
             "cloak", "decloak", "taunt", "curse", "lure", "wipe_shields",
             "spike_up", "hijack_primed", "mark_consumed", "hijack_roll"):
        return f"  {t}: {tgt}" + (f" ({amt})" if amt else "")
    return None  # skip noise types silently


def main() -> int:
    ap = argparse.ArgumentParser(description="Render sim JSONL as a replay")
    ap.add_argument("path")
    ap.add_argument("--battle", type=int, default=0, help="only this battle index")
    ap.add_argument("--summary", action="store_true", help="battles + picks only")
    ap.add_argument("--rounds", action="store_true", help="per-round detail (default)")
    args = ap.parse_args()
    show_rounds = not args.summary

    try:
        lines = open(args.path, encoding="utf-8").read().splitlines()
    except OSError as e:
        print(f"cannot read {args.path}: {e}", file=sys.stderr)
        return 1

    for line in lines:
        if not line.strip():
            continue
        obj = json.loads(line)
        t = obj.get("type", "")
        idx = int(obj.get("index", 0))
        if args.battle and t in ("battle_start", "round", "battle_end") and idx != args.battle:
            continue

        if t == "run_header":
            print(f"== RUN seed={obj.get('seed')} policy={obj.get('policy')} "
                  f"op={obj.get('op')} squad={','.join(obj.get('squad', []))} "
                  f"(sim {obj.get('sim_version')}, schema {obj.get('schema_version')}) ==")
        elif t == "battle_start":
            mod = obj.get("modifier", "")
            mod_sfx = f"  [MODIFIER: {mod}]" if mod else ""
            effects = obj.get("battle_effects", {})
            eff_sfx = f"  [EFFECTS: {effects}]" if effects else ""
            print(f"\n-- BATTLE {idx}: {' + '.join(obj.get('comp', []))}"
                  f"{mod_sfx}{eff_sfx}  (squad hp {obj.get('squad_hp')}, protocol {obj.get('protocol')})")
        elif t == "round" and show_rounds:
            print(f" R{obj.get('round')}  heroes[{fmt_rolls(obj.get('hero_rolls', {}), obj.get('eff_hero_rolls', {}))}]"
                  f"  enemies[{fmt_rolls(obj.get('enemy_rolls', {}), obj.get('eff_enemy_rolls', {}))}]")
            for spend in obj.get("spends", []):
                print(f"   $ {spend.get('kind')}: {spend.get('unit', '')} "
                      f"cost {spend.get('cost', 0)} {spend.get('detail', '')}".rstrip())
            for ev in obj.get("events", []):
                rendered = fmt_event(ev)
                if rendered:
                    print(f"   {rendered}")
            print(f"   hp: squad {obj.get('squad_hp')} | enemies {obj.get('enemy_hp')} | protocol {obj.get('protocol')}")
        elif t == "battle_end":
            deaths = obj.get("deaths", [])
            death_sfx = f"  deaths: {','.join(deaths)}" if deaths else ""
            print(f"-- BATTLE {idx} {str(obj.get('result', '')).upper()} in {obj.get('rounds')} rounds"
                  f"  (squad hp {obj.get('squad_hp')}, protocol left {obj.get('protocol_left')}){death_sfx}")
        elif t == "draft":
            opts = " | ".join(f"{o.get('id')}({o.get('rarity')},{o.get('type')})" for o in obj.get("options", []))
            picked = obj.get("picked", "") or "(skipped)"
            tgt = obj.get("target_unit", "")
            tgt_sfx = f" -> {tgt}" if tgt else ""
            print(f"   DRAFT after b{idx}: [{opts}]  picked {picked}{tgt_sfx}")
        elif t == "beat":
            detail = ""
            if obj.get("beat_type") == "fork":
                detail = f" modifier={obj.get('modifier', '?')} took_flagged={obj.get('took_flagged', '?')}"
            elif obj.get("beat_type") == "intercept":
                detail = (f" card={obj.get('card', '?')} choice={obj.get('choice', '?')}"
                          + (f" hero={obj['hero']}" if obj.get("hero") else "")
                          + (f" drafted={obj['drafted']}" if obj.get("drafted") else ""))
            print(f"   BEAT after b{obj.get('after_battle')}: {obj.get('beat_type')}"
                  f" ({obj.get('tier')}){detail}")
        elif t == "progression":
            print(f"   {str(obj.get('kind', '')).upper()}: {obj.get('unit')} picked "
                  f"{obj.get('picked')} from {obj.get('options')}")
        elif t == "run_end":
            print(f"\n== RUN END: {str(obj.get('result', '')).upper()} — "
                  f"{obj.get('battles_cleared')} battles cleared ==")
    return 0


if __name__ == "__main__":
    sys.exit(main())
