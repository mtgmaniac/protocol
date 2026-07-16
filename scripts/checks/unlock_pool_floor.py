#!/usr/bin/env python3
"""Unlock bucket data gate (Build F): pool floor + completeness + CSV pin.

The unlock design is ordered buckets + battle-count gates (THE FENCE,
docs/TRUTH.md). This gate pins:

1. COMPLETENESS — every live consumable, gear piece, and draftable relic
   sits in EXACTLY one bucket; boss relics in none; no unknown ids; every
   non-zero bucket holds 2-4 items (the ruling); the schedule is strictly
   increasing with buckets == gates + 1.
2. POOL FLOOR — bucket 0 meets the approved minimums, so a future rebalance
   can't starve first-run screens or dead-screen an intercept draft. The
   minimums live HERE (enforcement) and in unlocks.data.json (documentation);
   a duplicated constant is a delay fuse, so the copies are pinned equal.
   Rarity sub-floors trace to live event cards: salvageCache/blackMarketNode
   draft 3 rare+ gear, deepCache drafts 2 legendary (any), memorialProtocol/
   ghostFrequency grant a rare consumable, abandonedArmory drafts 3 uncommon+
   consumables — an empty offer trips the zero-options choice guard, and a
   guard firing is always a bug in the offer roll.
3. CSV PIN — docs/UNLOCK_BUCKETS.csv is the Kev-approval artifact; its
   id -> bucket mapping, unlock battles, types, and rarities must equal the
   runtime data. Approving the CSV approves the shipped buckets, exactly.

Lowering any floor here needs BASELINE-APPROVED-BY-KEV (INVARIANTS #13 —
floors loosen downward); raising is free.
"""
import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
UNLOCKS = ROOT / "data" / "raw" / "unlocks.data.json"
CSV_PATH = ROOT / "docs" / "UNLOCK_BUCKETS.csv"

# Approved bucket-0 minimums (Build F Phase 0 pool-floor math).
FLOORS = {
    "consumable": 12,
    "gear": 10,
    "relic": 6,
    "consumable_common": 8,
    "consumable_uncommon_plus": 2,
    "consumable_rare_plus": 1,
    "gear_rare_plus": 3,
    "legendary_total": 2,
}
RARITY_ORDER = ["common", "uncommon", "rare", "legendary"]


def _load_items():
    """id -> (type, rarity, name, boss_relic) for every live entry."""
    out = {}
    items = json.loads((ROOT / "data" / "raw" / "items.data.json").read_text(encoding="utf-8"))
    for entry in items.get("items", []):
        out[entry["id"]] = ("consumable", entry.get("rarity", ""), entry.get("name", ""), False)
    gear = json.loads((ROOT / "data" / "raw" / "gear.data.json").read_text(encoding="utf-8"))
    for entry in gear.get("gear", []):
        out[entry["id"]] = ("gear", entry.get("rarity", ""), entry.get("name", ""), False)
    relics = json.loads((ROOT / "data" / "raw" / "relics.data.json").read_text(encoding="utf-8"))
    for entry in relics:
        out[entry["id"]] = ("relic", "-", entry.get("name", ""), bool(entry.get("bossRelic", False)))
    return out


def _rarity_at_least(rarity, floor_name):
    if rarity not in RARITY_ORDER:
        return False
    return RARITY_ORDER.index(rarity) >= RARITY_ORDER.index(floor_name)


def main() -> int:
    problems = []
    items = _load_items()
    data = json.loads(UNLOCKS.read_text(encoding="utf-8"))
    schedule = data.get("schedule", [])
    buckets = data.get("buckets", [])

    # 1. Structure + completeness.
    if len(buckets) != len(schedule) + 1:
        problems.append(f"{len(buckets)} buckets but {len(schedule)} gates (+1 expected)")
    if schedule != sorted(schedule) or len(set(schedule)) != len(schedule):
        problems.append(f"schedule not strictly increasing: {schedule}")
    bucket_of = {}
    for index, bucket in enumerate(buckets):
        if index > 0 and not (2 <= len(bucket) <= 4):
            problems.append(f"bucket {index} holds {len(bucket)} items — the ruling is 2-4")
        for item_id in bucket:
            if item_id in bucket_of:
                problems.append(f"'{item_id}' in bucket {bucket_of[item_id]} AND {index}")
            bucket_of[item_id] = index
            if item_id not in items:
                problems.append(f"bucket {index} references unknown item '{item_id}'")
            elif items[item_id][3]:
                problems.append(f"boss relic '{item_id}' in bucket {index} — boss relics are event-gated, never bucketed")
    for item_id, (item_type, _rarity, _name, boss) in items.items():
        if boss:
            continue
        if item_id not in bucket_of:
            problems.append(f"live {item_type} '{item_id}' is in NO bucket — every item must be assigned")

    # 2. Pool floor (bucket 0).
    zero = [items[i] for i in buckets[0] if i in items] if buckets else []
    counts = {
        "consumable": sum(1 for t, r, n, b in zero if t == "consumable"),
        "gear": sum(1 for t, r, n, b in zero if t == "gear"),
        "relic": sum(1 for t, r, n, b in zero if t == "relic"),
        "consumable_common": sum(1 for t, r, n, b in zero if t == "consumable" and r == "common"),
        "consumable_uncommon_plus": sum(1 for t, r, n, b in zero if t == "consumable" and _rarity_at_least(r, "uncommon")),
        "consumable_rare_plus": sum(1 for t, r, n, b in zero if t == "consumable" and _rarity_at_least(r, "rare")),
        "gear_rare_plus": sum(1 for t, r, n, b in zero if t == "gear" and _rarity_at_least(r, "rare")),
        "legendary_total": sum(1 for t, r, n, b in zero if r == "legendary"),
    }
    for key, minimum in FLOORS.items():
        if counts.get(key, 0) < minimum:
            problems.append(f"bucket 0 floor: {key} = {counts.get(key, 0)}, approved minimum {minimum}")
    data_floors = data.get("floors", {})
    if {k: int(v) for k, v in data_floors.items()} != FLOORS:
        problems.append(f"unlocks.data.json floors {data_floors} != approved {FLOORS} — the copies are pinned equal")

    # 3. CSV pin (the Kev-approval artifact matches the shipped data).
    csv_rows = {}
    with CSV_PATH.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            csv_rows[row["id"]] = row
    for item_id, bucket_index in bucket_of.items():
        row = csv_rows.get(item_id)
        if row is None:
            problems.append(f"'{item_id}' missing from UNLOCK_BUCKETS.csv")
            continue
        if int(row["bucket"]) != bucket_index:
            problems.append(f"CSV bucket for '{item_id}' is {row['bucket']}, data says {bucket_index}")
        expected_battle = 0 if bucket_index == 0 else int(schedule[bucket_index - 1])
        if int(row["unlock_battle"]) != expected_battle:
            problems.append(f"CSV unlock_battle for '{item_id}' is {row['unlock_battle']}, schedule says {expected_battle}")
        item_type, rarity, name, _boss = items[item_id]
        if row["type"] != item_type:
            problems.append(f"CSV type for '{item_id}' is {row['type']}, data says {item_type}")
        if row["rarity"] != rarity:
            problems.append(f"CSV rarity for '{item_id}' is {row['rarity']}, data says {rarity}")
    for item_id in csv_rows:
        if item_id not in bucket_of:
            problems.append(f"CSV row '{item_id}' is not in any shipped bucket")

    for problem in problems:
        print(problem)
    if problems:
        print(f"[POOL_FLOOR] FAIL - {len(problems)} violation(s)")
        return 1
    print(f"[POOL_FLOOR] PASS - {len(bucket_of)} items across {len(buckets)} buckets, {len(schedule)} gates")
    return 0


if __name__ == "__main__":
    sys.exit(main())
