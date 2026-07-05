# L0 — uniform-random policy (Package B.2). The cheapest full exercise of the
# decision surface: every hook picks uniformly among LEGAL options through the
# policy's seeded rng. L0 is the telemetry-pipeline floor and the baseline the
# L1 heuristics must beat; it embodies zero game knowledge on purpose.
class_name PolicyL0Random
# Path-extends (not class_name) so a fresh checkout's headless run parses
# before the editor rebuilds the global class cache.
extends "res://scripts/sim/policies/player_policy.gd"

# Chance per round that L0 attempts one protocol spend at all (keeps random
# play from burning the pool every single round).
const SPEND_CHANCE := 0.35


func describe() -> String:
	return "l0"


func decide_round(engine: BattleEngine, bs: BattleState, cm: CombatManager, _gs: Node) -> Array:
	var spends: Array = []
	# Random hero targets: each living hero aims at a random living enemy.
	var living_enemies: Array = []
	for enemy_state_variant in cm.get_enemy_states():
		if not bool((enemy_state_variant as Dictionary).get("dead", false)):
			living_enemies.append(enemy_state_variant)
	for hero_state_variant in cm.get_hero_states():
		var hero_state: Dictionary = hero_state_variant
		if bool(hero_state.get("dead", false)) or living_enemies.is_empty():
			continue
		var pick: Dictionary = living_enemies[rng.randi_range(0, living_enemies.size() - 1)]
		hero_state["selected_target_id"] = str(pick["id"])

	# At most one random spend per round, only when affordable.
	if rng.randf() >= SPEND_CHANCE:
		return spends
	var living_heroes: Array = []
	for hero_state_variant in cm.get_hero_states():
		var hero_state: Dictionary = hero_state_variant
		if not bool(hero_state.get("dead", false)) and bs.hero_rolls.has(str(hero_state["id"])):
			living_heroes.append(str(hero_state["id"]))
	if living_heroes.is_empty():
		return spends
	var unit_id: String = str(living_heroes[rng.randi_range(0, living_heroes.size() - 1)])
	var options: Array = []
	if bs.protocol_points >= 1:
		options.append("nudge")
	if bs.protocol_points >= 2:
		options.append("reroll")
	if bs.protocol_points >= engine.set_cost(bs):
		options.append("set")
	if options.is_empty():
		return spends
	match str(options[rng.randi_range(0, options.size() - 1)]):
		"nudge":
			var nudged: Dictionary = engine.apply_nudge(bs, unit_id, false, false)
			if str(nudged.get("kind", "")) == "applied":
				spends.append({"kind": "nudge", "unit": unit_id, "cost": int(nudged.get("cost", 1)), "detail": "+3"})
		"reroll":
			var new_roll: int = engine.apply_reroll(bs, unit_id)
			spends.append({"kind": "reroll", "unit": unit_id, "cost": 2, "detail": "-> %d" % new_roll})
		"set":
			var value: int = rng.randi_range(1, 20)
			var paid: int = engine.apply_set(bs, unit_id, value)
			spends.append({"kind": "set", "unit": unit_id, "cost": paid, "detail": "= %d" % value})
	return spends


func choose_draft(items: Array, gs: Node) -> Dictionary:
	var viable: Array = []
	for item_variant in items:
		var item: ItemData = item_variant as ItemData
		if item == null:
			continue
		if item.item_type == "consumable" and (gs.get("consumables") as Array).size() >= int(gs.get("MAX_CONSUMABLES")):
			continue
		viable.append(item)
	# Random viable option; a small chance to skip entirely keeps "no pick"
	# exercised too.
	if viable.is_empty() or rng.randf() < 0.05:
		return {"id": "", "target_unit": ""}
	var picked: ItemData = viable[rng.randi_range(0, viable.size() - 1)]
	var target_unit: String = ""
	if picked.item_type == "gear":
		var units: Array = gs.get("selected_units")
		target_unit = str(units[rng.randi_range(0, units.size() - 1)])
	return {"id": picked.id, "target_unit": target_unit}


func choose_fork(_modifier_id: String, _gs: Node) -> bool:
	return rng.randf() < 0.5


func choose_intercept(_card_id: String, card: Dictionary, gs: Node) -> Dictionary:
	var choices: Array = card.get("choices", [])
	var legal: Array = []
	for i in choices.size():
		var choice: Dictionary = choices[i]
		match str(choice.get("pick", "")):
			"consumable":
				if not (gs.get("consumables") as Array).is_empty():
					legal.append(i)
			"gear":
				if not _all_equipped_gear(gs).is_empty():
					legal.append(i)
			_:
				legal.append(i)
	if legal.is_empty():
		return {"choice": 0, "hero_id": _first_unit(gs), "gear": {}}
	var choice_index: int = int(legal[rng.randi_range(0, legal.size() - 1)])
	var units: Array = gs.get("selected_units")
	var hero_id: String = str(units[rng.randi_range(0, units.size() - 1)]) if not units.is_empty() else ""
	var gear_context: Dictionary = {}
	if str((choices[choice_index] as Dictionary).get("pick", "")) == "gear":
		var gear_entries: Array = _all_equipped_gear(gs)
		if not gear_entries.is_empty():
			gear_context = gear_entries[rng.randi_range(0, gear_entries.size() - 1)]
			hero_id = str(gear_context.get("hero_id", hero_id))
	return {"choice": choice_index, "hero_id": hero_id, "gear": gear_context}


func choose_intercept_draft(options: Array, _gs: Node) -> String:
	if options.is_empty():
		return ""
	return str(options[rng.randi_range(0, options.size() - 1)])


func choose_evolution(paths: Array, _gs: Node) -> String:
	if paths.is_empty():
		return ""
	return str((paths[rng.randi_range(0, paths.size() - 1)] as Dictionary).get("name", ""))


func choose_directive(choices: Array, _gs: Node) -> String:
	if choices.is_empty():
		return ""
	return str((choices[rng.randi_range(0, choices.size() - 1)] as Dictionary).get("name", ""))


func _all_equipped_gear(gs: Node) -> Array:
	var entries: Array = []
	var gear_by_unit: Dictionary = gs.get("gear_by_unit")
	for hero_id in gear_by_unit.keys():
		for gear_id in gear_by_unit[hero_id]:
			entries.append({"hero_id": str(hero_id), "gear_id": str(gear_id)})
	return entries
