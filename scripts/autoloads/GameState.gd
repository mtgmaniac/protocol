# Stores run-level state that persists while the player moves between scenes.
extends Node

# Hard cap on carried consumables — matches the in-battle LoadoutMenu's slot count
# (loadout_menu.gd ITEM_SLOTS). Picking up a consumable while full requires swapping one out.
const MAX_CONSUMABLES := 3


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
## unit_id -> chosen Directive name (tier-3 passives, pkg6).
var unit_directives: Dictionary = {}
var pending_evolution_unit_id: String = ""
var deferred_evolution_unit_ids: Array = []
var carried_protocol: int = 0
## Dead Man's Hand relic: the first squad wipe each RUN is survived at 1 HP.
var dead_mans_hand_used: bool = false
## Starting Directive (pkg5): an unlocked boss relic picked at run start.
## It does not consume the battle-5 relic draft — a directive run ends with
## two relics by design.
var starting_directive_relic_id: String = ""
## Templated battle comps (pkg7.1): slot battles are rolled ONCE at run start
## so previews always show exact comps. One entry per battle:
## {"names": [display names], "cloaked": [display names]}.
var resolved_battle_comps: Array = []
# True only for the scripted onboarding encounter (rigged dice + coachmarks). In-memory;
# the tutorial is opt-in from the splash / Help, so it needs no persistence.
var tutorial_mode: bool = false

const XP_SURVIVAL_BONUS := 20
const XP_TO_EVOLVE := 100
## Tier-3 progression (pkg6): evolved units hitting this pick a Directive.
const XP_TO_DIRECTIVE := 250
const SQUAD_UNIT_LIMIT := 3

var _battle_effective_rolls: Dictionary = {}
var _battle_end_alive: Dictionary = {}

## Post-win rarity ladder (round = current_battle when rewards roll). Round 5 = relic only.
const RELIC_ONLY_ROUND := 5
const FIRST_RELIC_ROUND := 5
const RELIC_CHOICE_COUNT := 2

const DRAFT_RARITY_BY_ROUND: Dictionary = {
	1: {"common": 85, "uncommon": 10, "rare": 4, "legendary": 1},
	2: {"common": 70, "uncommon": 20, "rare": 8, "legendary": 2},
	3: {"common": 55, "uncommon": 28, "rare": 14, "legendary": 3},
	4: {"common": 40, "uncommon": 35, "rare": 20, "legendary": 5},
	6: {"common": 35, "uncommon": 35, "rare": 22, "legendary": 8},
	7: {"common": 28, "uncommon": 38, "rare": 26, "legendary": 8},
	8: {"common": 20, "uncommon": 40, "rare": 30, "legendary": 10},
	9: {"common": 15, "uncommon": 38, "rare": 32, "legendary": 15},
	10: {"common": 10, "uncommon": 35, "rare": 35, "legendary": 20},
}

var _reward_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func start_run(unit_ids: Array, operation_id: String = "") -> void:
	tutorial_mode = false
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
	_resolve_battle_comps(operation)
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
	unit_directives.clear()
	pending_evolution_unit_id = ""
	deferred_evolution_unit_ids.clear()
	carried_protocol = 0
	dead_mans_hand_used = false
	starting_directive_relic_id = ""
	_battle_effective_rolls.clear()
	_battle_end_alive.clear()
	for unit_id in selected_units:
		unit_xp[str(unit_id)] = 0
		unit_levels[str(unit_id)] = 1
	# DESIGN-TODO(kev): tutorial runs count toward runs_started too.
	SaveManager.record_run_started()


# Launch the rigged onboarding encounter: forced trio (Pulse Tech required for the Nudge
# demo), first operation, battle 1. battle_scene reads tutorial_mode to rig dice/enemy and
# spawn the coachmark controller.
func start_tutorial_run() -> void:
	var op_ids: Array = DataManager.get_operation_order()
	var op_id: String = str(op_ids[0]) if not op_ids.is_empty() else ""
	start_run(["pulse", "combat", "ghost"], op_id)
	current_battle = 1
	tutorial_mode = true


# --- Templated battle comps (pkg7.1) ---
# Fixed battles keep their authored comp; slot battles roll from the op
# faction's role pools once per run.
func _resolve_battle_comps(operation: OperationData) -> void:
	resolved_battle_comps.clear()
	if operation == null:
		return
	var faction: String = selected_operation_id
	for battle_variant in operation.battles:
		var battle: Dictionary = battle_variant
		var names: Array = (battle.get("enemy_names", []) as Array).duplicate()
		var cloaked: Array = (battle.get("cloaked_names", []) as Array).duplicate()
		if names.is_empty():
			names = _roll_slot_names(faction, battle.get("slots", []))
		resolved_battle_comps.append({"names": names, "cloaked": cloaked})


func _roll_slot_names(faction: String, slots: Array) -> Array:
	var names: Array = []
	for slot_variant in slots:
		var slot: String = str(slot_variant)
		if slot == "heavyOrElites":
			# 50/50: one heavy or two elites.
			if _reward_rng.randi_range(0, 1) == 0:
				names.append(_pick_from_role_pool(faction, "heavy", []))
			else:
				var first_elite: String = _pick_from_role_pool(faction, "elite", [])
				names.append(first_elite)
				names.append(_pick_from_role_pool(faction, "elite", [first_elite]))
		else:
			names.append(_pick_from_role_pool(faction, slot, []))
	# Drop any empty picks (missing pools) and respect the field cap.
	var cleaned: Array = []
	for name_variant in names:
		if str(name_variant) != "" and cleaned.size() < SQUAD_UNIT_LIMIT:
			cleaned.append(name_variant)
	return cleaned


# Rolls one name from the faction's role pool, avoiding `used` when possible.
func _pick_from_role_pool(faction: String, role: String, used: Array) -> String:
	var pool: Array = DataManager.get_role_pool(faction, role)
	var fresh: Array = pool.filter(func(n): return not used.has(n))
	if not fresh.is_empty():
		pool = fresh
	if pool.is_empty():
		return ""
	return str(pool[_reward_rng.randi_range(0, pool.size() - 1)])


# The exact comp for the current battle (1-based current_battle).
func get_current_battle_comp() -> Dictionary:
	var index: int = current_battle - 1
	if index < 0 or index >= resolved_battle_comps.size():
		return {}
	return resolved_battle_comps[index]


# Starting Directive: adopt an unlocked boss relic as the run's opening relic.
# Call after start_run (start_run clears relics and the directive id).
func set_starting_directive(relic_id: String) -> void:
	if relic_id == "" or not SaveManager.get_unlocked_boss_relics().has(relic_id):
		return
	starting_directive_relic_id = relic_id
	if not relics.has(relic_id):
		relics.append(relic_id)


func enforce_squad_limit() -> void:
	if selected_units.size() <= SQUAD_UNIT_LIMIT:
		return
	selected_units = selected_units.slice(0, SQUAD_UNIT_LIMIT)


func has_relic_effect(effect_type: String) -> bool:
	for relic_id in relics:
		var item: ItemData = DataManager.get_item(str(relic_id)) as ItemData
		if item == null or item.effect == null:
			continue
		if str(item.effect.get("type", "")) == effect_type:
			return true
	return false


func save_protocol_carryover(unspent_protocol: int, carry_pct: int) -> void:
	if carry_pct <= 0 or unspent_protocol <= 0:
		carried_protocol = 0
		return
	carried_protocol = int(floor(float(unspent_protocol) * float(carry_pct) / 100.0))


func take_carried_protocol() -> int:
	var amount: int = carried_protocol
	carried_protocol = 0
	return amount


func grant_battle_start_consumables(count: int) -> void:
	var granted: int = maxi(count, 0)
	for _i in range(granted):
		if consumables.size() >= MAX_CONSUMABLES:
			break
		var item_id: String = _pick_random_item_id("consumable", consumables)
		if item_id == "":
			break
		consumables.append(item_id)


func is_consumables_full() -> bool:
	return consumables.size() >= MAX_CONSUMABLES


func get_revive_hp_pct(default_pct: int) -> int:
	if has_relic_effect("reviveNoPenalty"):
		return 100
	return default_pct


func advance_to_next_battle() -> void:
	current_battle += 1


func reset_run() -> void:
	tutorial_mode = false
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
	unit_directives.clear()
	pending_evolution_unit_id = ""
	deferred_evolution_unit_ids.clear()
	carried_protocol = 0
	starting_directive_relic_id = ""
	_battle_effective_rolls.clear()
	_battle_end_alive.clear()


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


# `swap_consumable_id`: when consumables are full, the id of the held consumable to discard
# to make room for the new one (the reward screen prompts for this).
func claim_reward(item_id: String, target_unit_id: String = "", swap_consumable_id: String = "") -> bool:
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
			if consumables.size() >= MAX_CONSUMABLES:
				# Full — a valid swap target is required; the UI guarantees one.
				if swap_consumable_id == "" or not consumables.has(swap_consumable_id):
					return false
				consumables.erase(swap_consumable_id)
			consumables.append(item_id)
		"relic":
			# The Starting Directive doesn't consume the battle-5 draft slot.
			var drafted_relics: int = relics.size()
			if starting_directive_relic_id != "" and relics.has(starting_directive_relic_id):
				drafted_relics -= 1
			if drafted_relics > 0:
				return false
			relics.append(item_id)
		_:
			return false

	claimed_reward_item_id = item_id
	pending_reward_item_ids.clear()
	return true


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
	SaveManager.record_run_finished(result, selected_operation_id, current_battle)


func get_unit_xp(unit_id: String) -> int:
	return int(unit_xp.get(unit_id, 0))


func get_unit_level(unit_id: String) -> int:
	return int(unit_levels.get(unit_id, 1))


func get_unit_evolution_name(unit_id: String) -> String:
	return str(unit_evolutions.get(unit_id, ""))


func get_unit_directive_name(unit_id: String) -> String:
	return str(unit_directives.get(unit_id, ""))


# True when the pending progression stop is a tier-3 Directive pick
# (the unit already evolved) rather than an evolution branch pick.
func is_pending_directive_stage() -> bool:
	return pending_evolution_unit_id != "" and get_unit_evolution_name(pending_evolution_unit_id) != ""


# The 1-of-2 Directive choices scoped to the pending unit's evolution path.
func get_pending_directive_choices() -> Array:
	if pending_evolution_unit_id == "":
		return []
	var unit: UnitData = DataManager.get_unit(pending_evolution_unit_id) as UnitData
	if unit == null:
		return []
	var evolved_name: String = get_unit_evolution_name(pending_evolution_unit_id)
	for path_variant in _group_evolution_paths(unit.evolution_paths):
		var path: Dictionary = path_variant
		if str(path.get("name", "")) == evolved_name:
			return (path.get("directives", []) as Array).duplicate(true)
	return []


func apply_pending_directive(directive_name: String) -> bool:
	if pending_evolution_unit_id == "" or directive_name == "":
		return false
	var valid: bool = false
	for choice_variant in get_pending_directive_choices():
		if str((choice_variant as Dictionary).get("name", "")) == directive_name:
			valid = true
	if not valid:
		return false
	unit_directives[pending_evolution_unit_id] = directive_name
	pending_evolution_unit_id = ""
	return true


func begin_battle_xp_tracking() -> void:
	_battle_effective_rolls.clear()
	_battle_end_alive.clear()


func record_hero_effective_roll(unit_id: String, effective_roll: int) -> void:
	if effective_roll <= 0:
		return
	var key: String = str(unit_id)
	if not _battle_effective_rolls.has(key):
		_battle_effective_rolls[key] = []
	(_battle_effective_rolls[key] as Array).append(effective_roll)


func capture_battle_end_survival(hero_states: Array) -> void:
	_battle_end_alive.clear()
	for state_variant in hero_states:
		var state: Dictionary = state_variant
		var unit_id: String = _squad_unit_id_from_state(state)
		if unit_id == "":
			continue
		_battle_end_alive[unit_id] = not bool(state.get("dead", false))


func award_battle_xp() -> void:
	var newly_crossed_threshold: Array = []
	for unit_id_variant in selected_units:
		var unit_id: String = str(unit_id_variant)
		# Fully progressed (evolution + directive) units stop accruing.
		if get_unit_directive_name(unit_id) != "":
			continue
		var xp_before: int = get_unit_xp(unit_id)
		var gain: int = _compute_battle_xp_gain(unit_id)
		var new_total: int = xp_before + gain
		unit_xp[unit_id] = new_total
		var new_level: int = 1 + int(floor(float(new_total) / float(XP_TO_EVOLVE)))
		unit_levels[unit_id] = maxi(new_level, 1)
		var threshold: int = XP_TO_DIRECTIVE if get_unit_evolution_name(unit_id) != "" else XP_TO_EVOLVE
		if xp_before < threshold and new_total >= threshold:
			newly_crossed_threshold.append(unit_id)

	_queue_evolution_after_win(newly_crossed_threshold)
	_battle_effective_rolls.clear()
	_battle_end_alive.clear()


func _compute_battle_xp_gain(unit_id: String) -> int:
	var rolls: Array = _battle_effective_rolls.get(unit_id, [])
	var avg_roll: int = 0
	if not rolls.is_empty():
		var total: int = 0
		for roll_variant in rolls:
			total += int(roll_variant)
		avg_roll = roundi(float(total) / float(rolls.size()))
	if bool(_battle_end_alive.get(unit_id, false)):
		return XP_SURVIVAL_BONUS + avg_roll
	return avg_roll


func _queue_evolution_after_win(newly_crossed_threshold: Array) -> void:
	if pending_evolution_unit_id != "":
		return

	var ready: Array = []
	for unit_id_variant in deferred_evolution_unit_ids:
		var unit_id: String = str(unit_id_variant)
		if _is_evolution_eligible(unit_id) and not ready.has(unit_id):
			ready.append(unit_id)
	for unit_id_variant in newly_crossed_threshold:
		var unit_id: String = str(unit_id_variant)
		if _is_evolution_eligible(unit_id) and not ready.has(unit_id):
			ready.append(unit_id)
	# Catch units already past their next threshold when it opened (e.g. a
	# unit that banked 250+ XP before its evolution stop resolved).
	for unit_id_variant in selected_units:
		var unit_id: String = str(unit_id_variant)
		if _is_evolution_eligible(unit_id) and not ready.has(unit_id):
			ready.append(unit_id)

	if ready.is_empty():
		return

	var ordered: Array = []
	for unit_id_variant in deferred_evolution_unit_ids:
		var unit_id: String = str(unit_id_variant)
		if ready.has(unit_id):
			ordered.append(unit_id)
	for unit_id_variant in newly_crossed_threshold:
		var unit_id: String = str(unit_id_variant)
		if ready.has(unit_id) and not ordered.has(unit_id):
			ordered.append(unit_id)
	for unit_id_variant in selected_units:
		var unit_id: String = str(unit_id_variant)
		if ready.has(unit_id) and not ordered.has(unit_id):
			ordered.append(unit_id)

	pending_evolution_unit_id = str(ordered[0])
	deferred_evolution_unit_ids.clear()
	for i in range(1, ordered.size()):
		deferred_evolution_unit_ids.append(str(ordered[i]))


func _is_evolution_eligible(unit_id: String) -> bool:
	if get_unit_evolution_name(unit_id) == "":
		return get_unit_xp(unit_id) >= XP_TO_EVOLVE
	return get_unit_directive_name(unit_id) == "" and get_unit_xp(unit_id) >= XP_TO_DIRECTIVE


func _squad_unit_id_from_state(state: Dictionary) -> String:
	var unit: Variant = state.get("unit")
	if unit is UnitData:
		return str((unit as UnitData).id)
	if unit != null:
		return str(unit.get("id"))
	return str(state.get("id", ""))


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
		var path_callsign: String = str(path.get("callsign", ""))
		if path_callsign != "":
			built_unit.callsign = path_callsign
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
		# Attach the chosen tier-3 Directive so combat can read its passive.
		var directive_name: String = get_unit_directive_name(unit_id)
		if directive_name != "":
			for directive_variant in path.get("directives", []):
				if str((directive_variant as Dictionary).get("name", "")) == directive_name:
					built_unit.directive = (directive_variant as Dictionary).duplicate(true)
		return built_unit

	return base_unit


func get_pending_evolution_unit_id() -> String:
	return pending_evolution_unit_id


func _roll_reward_item_ids() -> Array:
	var round: int = current_battle
	if round == RELIC_ONLY_ROUND:
		if relics.is_empty():
			return _roll_relic_choice_ids(RELIC_CHOICE_COUNT)
		return []

	var chosen_ids: Array = []
	while chosen_ids.size() < 3:
		var rarity: String = _pick_draft_rarity_for_round(round)
		var item_id: String = _pick_random_reward_by_rarity(rarity, chosen_ids)
		if item_id == "":
			item_id = _pick_any_available_reward(chosen_ids)
		if item_id == "":
			break
		chosen_ids.append(item_id)
	return chosen_ids


func _roll_relic_choice_ids(count: int) -> Array:
	var chosen: Array = []
	var excluded: Array = []
	while chosen.size() < count:
		var relic_id: String = _pick_random_item_id("relic", chosen + excluded)
		if relic_id == "":
			break
		# Boss relics never appear in the battle-5 draft — they unlock via
		# first operation clears (pkg5 Starting Directive).
		var relic_item: ItemData = DataManager.get_item(relic_id) as ItemData
		if relic_item != null and relic_item.boss_relic:
			excluded.append(relic_id)
			continue
		chosen.append(relic_id)
	return chosen


func _pick_draft_rarity_for_round(round: int) -> String:
	var weights: Dictionary = DRAFT_RARITY_BY_ROUND.get(round, DRAFT_RARITY_BY_ROUND.get(10, {}))
	if weights.is_empty():
		weights = DRAFT_RARITY_BY_ROUND[1]
	var roll: int = _reward_rng.randi_range(1, 100)
	var cumulative: int = 0
	for tier in ["common", "uncommon", "rare", "legendary"]:
		cumulative += int(weights.get(tier, 0))
		if roll <= cumulative:
			return tier
	return "common"


func _pick_random_reward_by_rarity(rarity: String, excluded_ids: Array) -> String:
	var pool: Array = []
	for item_key in DataManager.items.keys():
		var item: ItemData = DataManager.items[item_key] as ItemData
		if item == null:
			continue
		if item.item_type != "consumable" and item.item_type != "gear":
			continue
		if str(item.rarity) != rarity:
			continue
		if excluded_ids.has(item.id):
			continue
		if has_relic_effect("rewardsNoCommon") and str(item.rarity) == "common":
			continue
		pool.append(item.id)
	if pool.is_empty():
		return ""
	var index: int = _reward_rng.randi_range(0, pool.size() - 1)
	return str(pool[index])


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
		if has_relic_effect("rewardsNoCommon") and str(item.rarity) == "common":
			continue
		pool.append(item.id)

	if pool.is_empty():
		return ""

	var index: int = _reward_rng.randi_range(0, pool.size() - 1)
	return str(pool[index])


func _pick_any_available_reward(excluded_ids: Array) -> String:
	for reward_type in ["consumable", "gear"]:
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
				"callsign": str(entry.get("callsign", "")),
				"focus": str(entry.get("focus", "")),
				"hp": int(entry.get("hp", 0)),
				"abilities_by_zone": {},
				"directives": (entry.get("directives", []) as Array).duplicate(true),
			}

		var grouped_entry: Dictionary = grouped[path_name]
		if str(grouped_entry.get("callsign", "")) == "" and str(entry.get("callsign", "")) != "":
			grouped_entry["callsign"] = str(entry.get("callsign", ""))
		if str(grouped_entry.get("focus", "")) == "" and str(entry.get("focus", "")) != "":
			grouped_entry["focus"] = str(entry.get("focus", ""))
		if int(grouped_entry.get("hp", 0)) <= 0 and int(entry.get("hp", 0)) > 0:
			grouped_entry["hp"] = int(entry.get("hp", 0))

		var ability_list: Array = entry.get("abilities", [])
		if ability_list.is_empty():
			grouped[path_name] = grouped_entry
			continue
		# Each evolution entry carries its FULL 5-zone kit — register every
		# ability (a single-entry read here silently kept the base kit for
		# all zones but the first).
		for ability_entry_variant in ability_list:
			var ability_entry: Dictionary = ability_entry_variant
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
