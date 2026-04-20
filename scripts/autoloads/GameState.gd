# Stores run-level state that persists while the player moves between scenes.
extends Node


var selected_units: Array = []
var current_battle: int = 0
var selected_operation_id: String = ""
var relics: Array = []
var consumables: Array = []
var gear_by_unit: Dictionary = {}
var equipped_gear: Dictionary = {}
var pending_reward_item_ids: Array = []
var claimed_reward_item_id: String = ""
var total_battles: int = 10
var last_run_result: String = ""
var unit_xp: Dictionary = {}
var unit_levels: Dictionary = {}
var unit_evolutions: Dictionary = {}
var pending_evolution_unit_id: String = ""

const XP_PER_BATTLE := 50
const XP_TO_EVOLVE := 100
const SQUAD_UNIT_LIMIT := 3

var _reward_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func start_run(unit_ids: Array, operation_id: String = "") -> void:
	_reward_rng.randomize()
	selected_units = unit_ids.duplicate()
	enforce_squad_limit()
	selected_operation_id = operation_id
	current_battle = 0
	var operation: OperationData = DataManager.get_operation(selected_operation_id) as OperationData
	if operation != null:
		total_battles = operation.battles.size()
	else:
		total_battles = 10
	relics.clear()
	consumables.clear()
	gear_by_unit.clear()
	equipped_gear.clear()
	pending_reward_item_ids.clear()
	claimed_reward_item_id = ""
	last_run_result = ""
	unit_xp.clear()
	unit_levels.clear()
	unit_evolutions.clear()
	pending_evolution_unit_id = ""
	for unit_id in selected_units:
		unit_xp[str(unit_id)] = 0
		unit_levels[str(unit_id)] = 1


func enforce_squad_limit() -> void:
	if selected_units.size() <= SQUAD_UNIT_LIMIT:
		return
	selected_units = selected_units.slice(0, SQUAD_UNIT_LIMIT)


func advance_to_next_battle() -> void:
	current_battle += 1


func reset_run() -> void:
	selected_units.clear()
	current_battle = 0
	selected_operation_id = ""
	relics.clear()
	consumables.clear()
	gear_by_unit.clear()
	equipped_gear.clear()
	pending_reward_item_ids.clear()
	claimed_reward_item_id = ""
	last_run_result = ""
	unit_xp.clear()
	unit_levels.clear()
	unit_evolutions.clear()
	pending_evolution_unit_id = ""


func prepare_battle_rewards() -> void:
	pending_reward_item_ids = _roll_reward_item_ids()
	claimed_reward_item_id = ""


func get_pending_reward_items() -> Array:
	var rewards: Array = []
	for item_id in pending_reward_item_ids:
		var item: ItemData = DataManager.get_item(str(item_id)) as ItemData
		if item != null:
			rewards.append(item)
	return rewards


func claim_reward(item_id: String, target_unit_id: String = "") -> bool:
	var item: ItemData = DataManager.get_item(item_id) as ItemData
	if item == null:
		return false
	if not pending_reward_item_ids.has(item_id):
		return false

	match item.item_type:
		"gear":
			if target_unit_id == "":
				return false
			var unit_gear: Array = gear_by_unit.get(target_unit_id, []).duplicate()
			unit_gear.append(item_id)
			gear_by_unit[target_unit_id] = unit_gear
			equipped_gear[target_unit_id] = unit_gear.duplicate()
		"consumable":
			consumables.append(item_id)
		"relic":
			if not relics.is_empty():
				return false
			relics.append(item_id)
		_:
			return false

	claimed_reward_item_id = item_id
	pending_reward_item_ids.clear()
	return true


func get_gear_display_names(unit_id: String) -> Array:
	var gear_names: Array = []
	var gear_ids: Array = gear_by_unit.get(unit_id, [])
	for gear_id in gear_ids:
		var item: ItemData = DataManager.get_item(str(gear_id)) as ItemData
		if item != null:
			gear_names.append(item.display_name)
	return gear_names


func get_inventory_summary() -> String:
	return "Relics: %d | Consumables: %d | Equipped Gear: %d" % [
		relics.size(),
		consumables.size(),
		_count_total_equipped_gear(),
	]


func get_battle_progress_text() -> String:
	return "Battle %d/%d" % [current_battle, total_battles]


func is_final_battle() -> bool:
	return current_battle >= total_battles


func finish_run(result: String) -> void:
	last_run_result = result
	pending_reward_item_ids.clear()


func get_unit_xp(unit_id: String) -> int:
	return int(unit_xp.get(unit_id, 0))


func get_unit_level(unit_id: String) -> int:
	return int(unit_levels.get(unit_id, 1))


func get_unit_xp_ratio(unit_id: String) -> float:
	var current_xp: int = get_unit_xp(unit_id)
	return clampf(float(current_xp % XP_TO_EVOLVE) / float(XP_TO_EVOLVE), 0.0, 1.0)


func get_unit_evolution_name(unit_id: String) -> String:
	return str(unit_evolutions.get(unit_id, ""))


func award_battle_xp() -> void:
	for unit_id_variant in selected_units:
		var unit_id: String = str(unit_id_variant)
		var new_total: int = get_unit_xp(unit_id) + XP_PER_BATTLE
		unit_xp[unit_id] = new_total
		var new_level: int = 1 + int(floor(float(new_total) / float(XP_TO_EVOLVE)))
		unit_levels[unit_id] = max(new_level, 1)
		if pending_evolution_unit_id == "" and get_unit_evolution_name(unit_id) == "" and new_total >= XP_TO_EVOLVE:
			pending_evolution_unit_id = unit_id


func has_pending_evolution() -> bool:
	return pending_evolution_unit_id != ""


func get_pending_evolution_paths() -> Array:
	if pending_evolution_unit_id == "":
		return []

	var unit: UnitData = DataManager.get_unit(pending_evolution_unit_id) as UnitData
	if unit == null:
		return []

	return _group_evolution_paths(unit.evolution_paths)


func apply_pending_evolution(path_name: String) -> bool:
	if pending_evolution_unit_id == "":
		return false
	if path_name == "":
		return false

	unit_evolutions[pending_evolution_unit_id] = path_name
	pending_evolution_unit_id = ""
	return true


func get_run_unit_data(unit_id: String) -> UnitData:
	var base_unit: UnitData = DataManager.get_unit(unit_id) as UnitData
	if base_unit == null:
		return null

	var evolved_name: String = get_unit_evolution_name(unit_id)
	if evolved_name == "":
		return base_unit

	var built_unit: UnitData = base_unit.duplicate(true) as UnitData
	if built_unit == null:
		return base_unit

	var grouped_paths: Array = _group_evolution_paths(base_unit.evolution_paths)
	for path_variant in grouped_paths:
		var path: Dictionary = path_variant
		if str(path.get("name", "")) != evolved_name:
			continue
		built_unit.display_name = evolved_name
		var hp_bonus: int = int(path.get("hp", 0))
		if hp_bonus > 0:
			built_unit.max_hp = hp_bonus
		var ability_map: Dictionary = path.get("abilities_by_zone", {})
		var merged_ranges: Array[Dictionary] = []
		for base_range in built_unit.dice_ranges:
			var zone: String = str(base_range.get("zone", ""))
			if ability_map.has(zone):
				merged_ranges.append((ability_map[zone] as Dictionary).duplicate(true))
			else:
				merged_ranges.append(base_range.duplicate(true))
		built_unit.dice_ranges = merged_ranges
		return built_unit

	return base_unit


func get_pending_evolution_unit_id() -> String:
	return pending_evolution_unit_id


func _roll_reward_item_ids() -> Array:
	var chosen_ids: Array = []
	var can_offer_relic: bool = relics.is_empty()
	var forced_relic_battle: bool = current_battle == 5 and can_offer_relic

	if forced_relic_battle:
		var relic_id: String = _pick_random_item_id("relic", chosen_ids)
		if relic_id != "":
			chosen_ids.append(relic_id)

	while chosen_ids.size() < 3:
		var reward_type: String = _roll_reward_type(forced_relic_battle)
		if reward_type == "relic" and not can_offer_relic:
			reward_type = "gear"
		var item_id: String = _pick_random_item_id(reward_type, chosen_ids)
		if item_id == "":
			item_id = _pick_any_available_reward(chosen_ids)
		if item_id == "":
			break
		chosen_ids.append(item_id)

	return chosen_ids


func _roll_reward_type(force_no_extra_relic: bool) -> String:
	var roll: int = _reward_rng.randi_range(1, 100)
	if not force_no_extra_relic and roll >= 96:
		return "relic"
	if roll >= 73:
		return "gear"
	return "consumable"


func _pick_random_item_id(item_type: String, excluded_ids: Array) -> String:
	if item_type == "relic" and not relics.is_empty():
		return ""
	var pool: Array = []
	for item_key in DataManager.items.keys():
		var item: ItemData = DataManager.items[item_key] as ItemData
		if item == null:
			continue
		if item.item_type != item_type:
			continue
		if excluded_ids.has(item.id):
			continue
		pool.append(item.id)

	if pool.is_empty():
		return ""

	var index: int = _reward_rng.randi_range(0, pool.size() - 1)
	return str(pool[index])


func _pick_any_available_reward(excluded_ids: Array) -> String:
	for reward_type in ["consumable", "gear", "relic"]:
		if reward_type == "relic" and not relics.is_empty():
			continue
		var item_id: String = _pick_random_item_id(reward_type, excluded_ids)
		if item_id != "":
			return item_id
	return ""


func _count_total_equipped_gear() -> int:
	var total: int = 0
	for unit_id in gear_by_unit.keys():
		total += (gear_by_unit[unit_id] as Array).size()
	return total


func _group_evolution_paths(evolution_entries: Array) -> Array:
	var grouped: Dictionary = {}
	for entry_variant in evolution_entries:
		var entry: Dictionary = entry_variant
		var path_name: String = str(entry.get("name", ""))
		if path_name == "":
			continue
		if not grouped.has(path_name):
			grouped[path_name] = {
				"name": path_name,
				"focus": str(entry.get("focus", "")),
				"hp": int(entry.get("hp", 0)),
				"abilities_by_zone": {},
			}

		var grouped_entry: Dictionary = grouped[path_name]
		if str(grouped_entry.get("focus", "")) == "" and str(entry.get("focus", "")) != "":
			grouped_entry["focus"] = str(entry.get("focus", ""))
		if int(grouped_entry.get("hp", 0)) <= 0 and int(entry.get("hp", 0)) > 0:
			grouped_entry["hp"] = int(entry.get("hp", 0))

		var ability_list: Array = entry.get("abilities", [])
		if ability_list.is_empty():
			grouped[path_name] = grouped_entry
			continue
		var ability_entry: Dictionary = ability_list[0]
		var zone: String = str(ability_entry.get("zone", ""))
		var range_pair: Array = ability_entry.get("range", [])
		var min_roll: int = int(ability_entry.get("min", range_pair[0] if range_pair.size() > 0 else 0))
		var max_roll: int = int(ability_entry.get("max", range_pair[1] if range_pair.size() > 1 else min_roll))
		var ability_name: String = str(ability_entry.get("ability_name", ability_entry.get("name", "")))
		var raw_entry: Dictionary = ability_entry.get("raw", ability_entry).duplicate(true)
		grouped_entry["abilities_by_zone"][zone] = {
			"min": min_roll,
			"max": max_roll,
			"zone": zone,
			"ability_name": ability_name,
			"description": str(raw_entry.get("eff", ability_entry.get("description", ""))),
			"raw": raw_entry,
		}
		grouped[path_name] = grouped_entry

	var grouped_paths: Array = []
	for path_name in grouped.keys():
		grouped_paths.append(grouped[path_name])
	return grouped_paths
