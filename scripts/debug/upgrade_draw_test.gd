# Upgrade-draw regression (Build G item 3): every item "upgrade" draw succeeds
# at EVERY unlock state, including a fresh 0-gate profile, with pool gating
# FORCED live (the zero-options doctrine: an empty offer is always a bug).
# Pins dynamically what unlock_pool_floor.py pins statically — the bucket-0
# floors were sized to exactly these draws:
#   • salvageCache / blackMarketNode: 3x rare+ gear
#   • deepCache: 2x legendary (any kind)
#   • driftingWreck: 3x uncommon+ gear
#   • abandonedArmory: 3x uncommon+ consumables
#   • memorialProtocol / ghostFrequency: 1 rare consumable grant
#   • theFoundry: one gear of the NEXT rarity tier, excluding the fed gear
#     (tightest case: feeding a legendary must still return a legendary)
# Plus the ELITE PRESENCE comp shaper (enemy role pools, NOT item-gated):
# whenever its precondition holds, shaping must add exactly one elite.
# Run: godot --headless --path . -s scripts/debug/upgrade_draw_test.gd
extends SceneTree

const GATE_MAX := 17
const SEEDS := [7, 1001, 40404, 987654, 2026]

var _errors: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond and _errors.size() < 40:
		_errors.append(label)


func _initialize() -> void:
	await process_frame
	var gs: Node = root.get_node("/root/GameState")
	var dm: Node = root.get_node("/root/DataManager")
	var sm: Node = root.get_node("/root/SaveManager")

	# ── Item draws under FORCED gating at every unlock state ──────────────────
	dm.call("force_pool_gating_for_test")
	sm.set("data", sm.call("default_data"))
	for gates in range(0, GATE_MAX + 1):
		(sm.get("data")["unlocks"] as Dictionary)["item_gates_awarded"] = gates
		for seed_value in SEEDS:
			gs.call("start_run", ["combat", "engineer", "medic"], "facility", seed_value)
			var rare_gear: Array = gs.call("roll_intercept_draft", "gear", "rare", 3)
			_check(rare_gear.size() == 3, "salvage/blackMarket 3x rare+ gear at %d gates seed %d (got %d)" % [gates, seed_value, rare_gear.size()])
			var deep: Array = gs.call("roll_intercept_draft", "any", "legendary", 2)
			_check(deep.size() == 2, "deepCache 2x legendary at %d gates seed %d (got %d)" % [gates, seed_value, deep.size()])
			var wreck: Array = gs.call("roll_intercept_draft", "gear", "uncommon", 3)
			_check(wreck.size() == 3, "driftingWreck 3x uncommon+ gear at %d gates seed %d (got %d)" % [gates, seed_value, wreck.size()])
			var armory: Array = gs.call("roll_intercept_draft", "consumable", "uncommon", 3)
			_check(armory.size() == 3, "abandonedArmory 3x uncommon+ consumables at %d gates seed %d (got %d)" % [gates, seed_value, armory.size()])
			var rare_consumable: String = str(gs.call("_pick_random_reward_by_rarity", "rare", [], "consumable"))
			_check(rare_consumable != "", "rare consumable event grant at %d gates seed %d" % [gates, seed_value])
			# Foundry ladder: uncommon->rare and rare/legendary->legendary, and
			# the tightest case — feed a legendary, exclude it, still draw one.
			_check(str(gs.call("_pick_random_gear_by_rarity", "rare", [])) != "", "Foundry rare tier at %d gates seed %d" % [gates, seed_value])
			var legendaries: Array = []
			for item_id in dm.call("pool_ids", "gear"):
				var item: ItemData = dm.call("get_item", str(item_id)) as ItemData
				if item != null and item.rarity == "legendary":
					legendaries.append(item.id)
			_check(not legendaries.is_empty(), "gated gear pool holds a legendary at %d gates" % gates)
			if not legendaries.is_empty():
				var fed: String = str(legendaries[0])
				_check(str(gs.call("_pick_random_gear_by_rarity", "legendary", [fed])) != "", "Foundry legendary->legendary excluding the fed gear at %d gates seed %d" % [gates, seed_value])

	# ── ELITE PRESENCE shaping: precondition true => exactly one slot upgrades ─
	var op_ids: Array = dm.call("get_operation_order")
	var shaped_cases := 0
	for op_variant in op_ids:
		var op_id: String = str(op_variant)
		var elite_pool: Array = dm.call("get_role_pool", op_id, "elite")
		for seed_value in SEEDS:
			gs.call("start_run", ["combat", "engineer", "medic"], op_id, seed_value)
			var comps: Array = gs.get("resolved_battle_comps")
			# Battle 10 excluded ON PURPOSE: the shaper treats the BOSS as "a
			# non-elite slot" and would replace it — reported as a pre-F bug
			# (Build G item 3 Phase 0), pending a ruling; do not pin it here.
			for comp_index in mini(comps.size(), 9):
				var comp: Dictionary = comps[comp_index] as Dictionary
				var names: Array = comp.get("names", [])
				if not bool(gs.call("_modifier_precondition_ok", "elitePresence", names)):
					continue
				var shaped: Dictionary = gs.call("_shape_comp_for_modifier", "elitePresence", comp)
				var before: int = _count_in_pool(names, elite_pool)
				var after: int = _count_in_pool(shaped.get("names", []), elite_pool)
				shaped_cases += 1
				_check(after == before + 1, "ELITE PRESENCE upgrades exactly one slot (op %s seed %d battle %d: %d -> %d | %s => %s)" % [op_id, seed_value, comp_index + 1, before, after, str(names), str(shaped.get("names", []))])
	_check(shaped_cases > 0, "elite presence probe exercised at least one comp")

	if _errors.is_empty():
		print("[UPGRADE_DRAW] PASS (%d elite shapings checked)" % shaped_cases)
		quit(0)
	else:
		for e in _errors:
			push_error("[UPGRADE_DRAW] " + e)
		print("[UPGRADE_DRAW] FAIL - %d check(s)" % _errors.size())
		quit(1)


func _count_in_pool(names: Array, pool: Array) -> int:
	var n := 0
	for name_variant in names:
		if pool.has(str(name_variant)):
			n += 1
	return n
