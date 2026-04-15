# Resolves a minimal first-pass combat loop using the rolled ability metadata.
class_name CombatManager
extends RefCounted

var _hero_states: Array = []
var _enemy_states: Array = []
var _round_log: Array = []
var _round_events: Array = []

var _active_relic_effects: Array = []  # Array of effect Dictionaries from DataManager
var _chain_reaction_active: bool = false


func setup_battle(hero_units: Array, enemy_units: Array) -> void:
	_hero_states.clear()
	_enemy_states.clear()

	for hero in hero_units:
		_hero_states.append(_create_runtime_state(hero))

	for enemy in enemy_units:
		_enemy_states.append(_create_runtime_state(enemy, _next_enemy_instance_id(enemy)))


func get_hero_states() -> Array:
	return _hero_states


func get_enemy_states() -> Array:
	return _enemy_states


# --- Relic setup and helpers ---

func setup_relics(relic_ids: Array) -> void:
	_active_relic_effects.clear()
	for relic_id in relic_ids:
		var item: ItemData = DataManager.get_item(str(relic_id)) as ItemData
		if item != null and item.effect != null:
			_active_relic_effects.append(item.effect.duplicate())


func has_relic(effect_type: String) -> bool:
	for eff in _active_relic_effects:
		if str(eff.get("type", "")) == effect_type:
			return true
	return false


func _get_relic_value(effect_type: String, key: String, default_val) -> Variant:
	for eff in _active_relic_effects:
		if str(eff.get("type", "")) == effect_type:
			return eff.get(key, default_val)
	return default_val


# --- Gear setup ---

func setup_gear(gear_by_unit: Dictionary) -> void:
	# gear_by_unit: { unit_id: Array[item_id_string] }
	for hero_state in _hero_states:
		var unit_id: String = str(hero_state["id"])
		var gear_ids: Array = gear_by_unit.get(unit_id, [])
		for gear_id in gear_ids:
			var item: ItemData = DataManager.get_item(str(gear_id)) as ItemData
			if item == null or item.effect == null:
				continue
			_apply_gear_passive(hero_state, item.effect)


func _apply_gear_passive(hero_state: Dictionary, effect: Dictionary) -> void:
	var effect_type: String = str(effect.get("type", ""))
	match effect_type:
		"rollBonus":
			hero_state["perm_roll_buff"] = int(hero_state.get("perm_roll_buff", 0)) + int(effect.get("amount", 0))
		"dotDmgBonus":
			hero_state["gear_dot_bonus"] = int(hero_state.get("gear_dot_bonus", 0)) + int(effect.get("amount", 0))
		"dmgReduction":
			hero_state["gear_dmg_reduction"] = int(hero_state.get("gear_dmg_reduction", 0)) + int(effect.get("amount", 0))
		"surviveOnce":
			hero_state["gear_survive_once"] = true
			hero_state["gear_survive_once_used"] = false
		"firstAbilityDmgBonus":
			hero_state["gear_first_dmg_bonus"] = int(hero_state.get("gear_first_dmg_bonus", 0)) + int(effect.get("amount", 0))
			hero_state["gear_first_dmg_fired"] = false
		"healOnKill":
			hero_state["gear_heal_on_kill"] = int(hero_state.get("gear_heal_on_kill", 0)) + int(effect.get("amount", 0))
		"protocolOnBattleStart":
			hero_state["gear_protocol_on_start"] = int(hero_state.get("gear_protocol_on_start", 0)) + int(effect.get("amount", 0))


# --- Battle-start relic effects ---

func apply_battle_start_relic_effects(battle_index: int) -> void:
	# openingGambit: random enemy + random hero take 50% maxHP damage
	if has_relic("battleStartHalfHp"):
		var living_enemies = _enemy_states.filter(func(e): return not e["dead"])
		var living_heroes = _hero_states.filter(func(h): return not h["dead"])
		if not living_enemies.is_empty():
			var target_enemy = living_enemies[randi() % living_enemies.size()]
			var dmg = int(target_enemy["max_hp"]) / 2
			_damage_state(target_enemy, dmg)
			_log("Opening Gambit: %s takes %d damage!" % [target_enemy["unit"].display_name, dmg])
		if not living_heroes.is_empty():
			var target_hero = living_heroes[randi() % living_heroes.size()]
			var dmg = int(target_hero["max_hp"]) / 2
			_damage_state(target_hero, dmg)
			_log("Opening Gambit: %s takes %d damage!" % [target_hero["unit"].display_name, dmg])

	# plagueProtocol: all enemies start with 3 DoT
	if has_relic("enemyDotPermanent"):
		var dot_amt = int(_get_relic_value("enemyDotPermanent", "amount", 3))
		for enemy_state in _enemy_states:
			if not enemy_state["dead"]:
				_apply_poison(enemy_state, dot_amt, 9999)
				_log("Plague Protocol: %s starts with %d DoT." % [enemy_state["unit"].display_name, dot_amt])

	# signalJam: all enemies start with permanent -2 RFE
	if has_relic("enemyStartRfe"):
		var rfe_amt = int(_get_relic_value("enemyStartRfe", "amount", 2))
		for enemy_state in _enemy_states:
			if not enemy_state["dead"]:
				enemy_state["perm_rfe"] = int(enemy_state.get("perm_rfe", 0)) + rfe_amt
				_log("Signal Jam: %s permanently at -%d roll." % [enemy_state["unit"].display_name, rfe_amt])

	# coordinatedStrike: all heroes start with permanent +2 roll buff
	if has_relic("heroStartRollBuff"):
		var buff_amt = int(_get_relic_value("heroStartRollBuff", "amount", 2))
		for hero_state in _hero_states:
			if not hero_state["dead"]:
				hero_state["perm_roll_buff"] = int(hero_state.get("perm_roll_buff", 0)) + buff_amt
				_log("Coordinated Strike: %s permanently at +%d roll." % [hero_state["unit"].display_name, buff_amt])

	# entropyLeak: enemies lose 5 maxHP per battle already cleared
	if has_relic("enemyHpEscalation"):
		var reduction_per_battle = int(_get_relic_value("enemyHpEscalation", "reductionPerBattle", 5))
		var total_reduction = battle_index * reduction_per_battle
		if total_reduction > 0:
			for enemy_state in _enemy_states:
				var new_max = maxi(1, int(enemy_state["max_hp"]) - total_reduction)
				enemy_state["max_hp"] = new_max
				enemy_state["current_hp"] = mini(int(enemy_state["current_hp"]), new_max)
				_log("Entropy Leak: %s max HP reduced by %d." % [enemy_state["unit"].display_name, total_reduction])


# --- Battle-start gear effects ---

func apply_battle_start_gear_effects() -> void:
	for hero_state in _hero_states:
		if hero_state["dead"]:
			continue
		var gear_ids: Array = GameState.gear_by_unit.get(str(hero_state["id"]), [])
		for gear_id in gear_ids:
			var item: ItemData = DataManager.get_item(str(gear_id)) as ItemData
			if item == null or item.effect == null:
				continue
			var effect_type: String = str(item.effect.get("type", ""))
			match effect_type:
				"battleStartShield":
					_add_shield_stack(hero_state, int(item.effect.get("amount", 0)), 1)
					_log("%s: Combat Plating grants %d shield." % [hero_state["unit"].display_name, int(item.effect.get("amount", 0))])
				"battleStartCloak":
					hero_state["cloaked"] = true
					_log("%s starts battle cloaked (Phase Weave)." % hero_state["unit"].display_name)
				"maxHpBonus":
					var bonus: int = int(item.effect.get("amount", 0))
					hero_state["max_hp"] = int(hero_state["max_hp"]) + bonus
					hero_state["current_hp"] = int(hero_state["current_hp"]) + bonus
					_log("%s: Stim Injector +%d max HP." % [hero_state["unit"].display_name, bonus])


# --- Per-enemy-turn relic effects ---

func apply_enemy_turn_start_relic_effects() -> void:
	# bulwarkAura: all heroes gain 3 shield
	if has_relic("heroShieldPerTurn"):
		var amt = int(_get_relic_value("heroShieldPerTurn", "amount", 3))
		for hero_state in _hero_states:
			if not hero_state["dead"]:
				_add_shield_stack(hero_state, amt, 1)

	# naniteField: all heroes heal 3 HP
	if has_relic("heroHealPerTurn"):
		var amt = int(_get_relic_value("heroHealPerTurn", "amount", 3))
		for hero_state in _hero_states:
			if not hero_state["dead"]:
				_heal_state(hero_state, amt)

	# gravityWell: all living enemies take 2 damage
	if has_relic("auraEnemyDmg"):
		var amt = int(_get_relic_value("auraEnemyDmg", "amount", 2))
		for enemy_state in _enemy_states:
			if not enemy_state["dead"]:
				_damage_state(enemy_state, amt)


# --- Damage multiplier helpers ---

func _get_hero_dmg_mult() -> float:
	return float(_get_relic_value("heroDmgMult", "mult", 1.0))


func _get_enemy_dmg_mult() -> float:
	return float(_get_relic_value("enemyDmgMult", "mult", 1.0))


# --- DoT bonus helper ---

func _get_total_dot_bonus() -> int:
	var max_bonus: int = 0
	for h in _hero_states:
		if not h["dead"]:
			max_bonus = maxi(max_bonus, int(h.get("gear_dot_bonus", 0)))
	return max_bonus


# PUBLIC: Returns the effective roll for a state factoring in RFE stacks and roll buff.
# battle_scene passes nudge on top of this, so nudge is NOT included here.
func get_effective_roll(state: Dictionary, raw_roll: int) -> int:
	var rfe: int = _get_total_rfe(state) + int(state.get("perm_rfe", 0))
	var buff: int = int(state.get("roll_buff", 0)) + int(state.get("perm_roll_buff", 0))
	return clampi(raw_roll + buff - rfe, 1, 20)


func resolve_round(hero_rolls: Dictionary, enemy_rolls: Dictionary, dice_manager: DiceManager) -> Dictionary:
	_round_log.clear()
	_round_events.clear()
	for hero_state in _hero_states:
		if hero_state["dead"]:
			continue
		if int(hero_state.get("cower_turns", 0)) > 0:
			_log("%s is cowered and cannot act." % hero_state["unit"].display_name)
			continue
		var roll_value: Variant = hero_rolls.get(hero_state["id"], null)
		if roll_value == null:
			continue
		var ability_entry: Dictionary = dice_manager.get_ability_for_roll(hero_state["unit"], int(roll_value))
		_log("%s uses %s." % [hero_state["unit"].display_name, str(ability_entry.get("ability_name", "Unknown"))])
		_emit_action_event(hero_state, "hero", str(ability_entry.get("ability_name", "Unknown")))
		_apply_hero_ability(hero_state, ability_entry)

	# Check phase 2 transitions after hero abilities land (boss may cross threshold mid-round)
	_check_phase_two_transitions()

	if _all_states_dead(_enemy_states):
		_log("All enemies are down.")
		return {"result": "victory", "log": _round_log.duplicate(), "events": _round_events.duplicate(true)}

	# Apply per-enemy-turn relic effects before enemies act
	apply_enemy_turn_start_relic_effects()

	var ordered_enemy_states: Array = _enemy_states.duplicate()
	ordered_enemy_states.reverse()
	for enemy_state in ordered_enemy_states:
		if enemy_state["dead"]:
			continue
		var enemy_roll_value: Variant = enemy_rolls.get(enemy_state["id"], null)
		if enemy_roll_value == null:
			continue
		var enemy_ability_entry: Dictionary = dice_manager.get_ability_for_roll(enemy_state["unit"], int(enemy_roll_value))
		_log("%s uses %s." % [enemy_state["unit"].display_name, str(enemy_ability_entry.get("ability_name", "Unknown"))])
		_emit_action_event(enemy_state, "enemy", str(enemy_ability_entry.get("ability_name", "Unknown")))
		_apply_enemy_ability(enemy_state, enemy_ability_entry)

	_tick_end_of_round_states()
	# Re-check after DoT ticks (poison might push enemy across phase 2 threshold)
	_check_phase_two_transitions()

	if _all_states_dead(_enemy_states):
		_log("All enemies are down.")
		return {"result": "victory", "log": _round_log.duplicate(), "events": _round_events.duplicate(true)}

	if _all_states_dead(_hero_states):
		_log("The squad has been wiped out.")
		return {"result": "defeat", "log": _round_log.duplicate(), "events": _round_events.duplicate(true)}

	return {"result": "ongoing", "log": _round_log.duplicate(), "events": _round_events.duplicate(true)}


func _next_enemy_instance_id(enemy: Resource) -> String:
	var base_id: String = str(enemy.id)
	var next_index: int = 1
	for state_variant in _enemy_states:
		var state: Dictionary = state_variant
		var state_unit: Object = state.get("unit") as Object
		if state_unit != null and str(state_unit.get("id")) == base_id:
			next_index += 1
	return "%s#%d" % [base_id, next_index]


func _create_runtime_state(unit: Resource, runtime_id: String = "") -> Dictionary:
	var state_id: String = runtime_id if runtime_id != "" else str(unit.id)
	return {
		"id": state_id,
		"unit": unit,
		"current_hp": unit.max_hp,
		"max_hp": unit.max_hp,
		"shield": 0,
		"shield_stacks": [],
		"dead": false,
		"poison": 0,
		"poison_turns": 0,
		"poison_skip_next_tick": false,
		"rfe_stacks": [],
		"roll_buff": 0,
		"roll_buff_turns": 0,
		"dmg_scale": 1.0,
		"selected_target_id": "",
		"target_display": "--",
		"cloaked": false,
		"cower_turns": 0,
		"die_freeze_turns": 0,
		"rampage_charges": 0,
		"counter_pct": 0,
		"cursed": false,
		"taunting": false,
		"frozen_die_value": 0,
		"die_freeze_consumed_this_round": false,
		"perm_roll_buff": 0,
		"perm_rfe": 0,
		"gear_dot_bonus": 0,
		"gear_dmg_reduction": 0,
		"gear_survive_once": false,
		"gear_survive_once_used": false,
		"gear_first_dmg_bonus": 0,
		"gear_first_dmg_fired": false,
		"gear_heal_on_kill": 0,
		"gear_protocol_on_start": 0,
		"in_phase_two": false,
	}


# --- Shield stack helpers ---

func _get_total_shield(state: Dictionary) -> int:
	var total: int = 0
	for stack in state.get("shield_stacks", []):
		total += int(stack["amt"])
	return total


func _add_shield_stack(state: Dictionary, amount: int, turns: int) -> void:
	state["shield_stacks"].append({"amt": amount, "turns_left": turns})
	state["shield"] = _get_total_shield(state)
	_log("%s gains %d shield (%dt)." % [state["unit"].display_name, amount, turns])
	_emit_event(state, "shield", amount, _resolve_side_for_state(state))


# --- RFE stack helpers ---

func _get_total_rfe(state: Dictionary) -> int:
	var total: int = 0
	for stack in state.get("rfe_stacks", []):
		total += int(stack["amt"])
	return total


func _add_rfe_stack(state: Dictionary, amount: int, turns: int) -> void:
	state["rfe_stacks"].append({"amt": amount, "turns_left": turns})
	_log("%s gets -%d to rolls (%dt)." % [state["unit"].display_name, amount, turns])


func _add_roll_buff(state: Dictionary, amount: int, turns: int) -> void:
	if state.is_empty() or bool(state.get("dead", false)) or amount <= 0:
		return
	state["roll_buff"] = int(state.get("roll_buff", 0)) + amount
	state["roll_buff_turns"] = maxi(int(state.get("roll_buff_turns", 0)), turns)
	_log("%s gains +%d roll buff (%dt)." % [state["unit"].display_name, amount, turns])
	_emit_event(state, "roll_buff", amount, _resolve_side_for_state(state))


func _apply_hero_ability(hero_state: Dictionary, ability_entry: Dictionary) -> void:
	var raw: Dictionary = ability_entry.get("raw", {})
	var damage: int = int(raw.get("dmg", 0))
	var heal: int = int(raw.get("heal", 0))
	var shield: int = int(raw.get("shield", 0))
	var sh_turns: int = int(raw.get("shT", 1))
	var hits_all: bool = bool(raw.get("blastAll", false))
	var heal_all: bool = bool(raw.get("healAll", false))
	var shield_all: bool = bool(raw.get("shieldAll", false))
	var heal_lowest: bool = bool(raw.get("healLowest", false))
	var shield_targeted: bool = bool(raw.get("shTgt", false))
	var heal_targeted: bool = bool(raw.get("healTgt", false))
	var poison_amount: int = int(raw.get("dot", 0))
	var poison_turns: int = int(raw.get("dT", 0))
	var roll_buff_amount: int = int(raw.get("rfm", 0))
	var roll_buff_turns: int = int(raw.get("rfmT", 1))
	var roll_buff_targeted: bool = bool(raw.get("rfmTgt", false)) or shield_targeted or heal_targeted

	if damage > 0:
		# First-ability damage bonus from gear
		var first_bonus: int = 0
		if not bool(hero_state.get("gear_first_dmg_fired", false)) and int(hero_state.get("gear_first_dmg_bonus", 0)) > 0:
			first_bonus = int(hero_state["gear_first_dmg_bonus"])
			hero_state["gear_first_dmg_fired"] = true
		var final_dmg: int = int(ceil(float(damage + first_bonus) * _get_hero_dmg_mult()))

		if hits_all:
			for enemy_state in _enemy_states:
				_damage_state(enemy_state, final_dmg)
		else:
			var target_enemy: Dictionary = _find_target_by_id(_enemy_states, str(hero_state.get("selected_target_id", "")))
			if target_enemy.is_empty():
				target_enemy = _first_living_state(_enemy_states)
			if not target_enemy.is_empty():
				var counter: int = int(target_enemy.get("counter_pct", 0))
				if counter > 0 and randi_range(1, 100) <= counter:
					_log("%s COUNTERS %s's attack! Damage reflected!" % [target_enemy["unit"].display_name, hero_state["unit"].display_name])
					_emit_event(hero_state, "damage", final_dmg, "hero")
					_damage_state(hero_state, final_dmg)
					target_enemy["counter_pct"] = 0
				else:
					target_enemy["counter_pct"] = 0
					_damage_state(target_enemy, final_dmg)
					_apply_poison(target_enemy, poison_amount, poison_turns)

	if shield > 0:
		if shield_all:
			for ally_state in _hero_states:
				if not ally_state["dead"]:
					_add_shield_stack(ally_state, shield, sh_turns)
		elif shield_targeted:
			var shield_target: Dictionary = _find_target_by_id(_hero_states, str(hero_state.get("selected_target_id", "")))
			if shield_target.is_empty():
				shield_target = _lowest_hp_state(_hero_states)
			if not shield_target.is_empty():
				_add_shield_stack(shield_target, shield, sh_turns)
		else:
			_add_shield_stack(hero_state, shield, sh_turns)

	if heal > 0:
		if heal_all:
			for ally_state in _hero_states:
				_heal_state(ally_state, heal)
		elif heal_lowest or heal_targeted:
			var heal_target: Dictionary = _find_target_by_id(_hero_states, str(hero_state.get("selected_target_id", "")))
			if heal_target.is_empty():
				heal_target = _lowest_hp_state(_hero_states)
			if not heal_target.is_empty():
				_heal_state(heal_target, heal)
		else:
			_heal_state(hero_state, heal)

	if roll_buff_amount > 0:
		if roll_buff_targeted:
			var roll_buff_target: Dictionary = _find_target_by_id(_hero_states, str(hero_state.get("selected_target_id", "")))
			if roll_buff_target.is_empty():
				roll_buff_target = hero_state
			_add_roll_buff(roll_buff_target, roll_buff_amount, roll_buff_turns)
		else:
			for ally_state in _hero_states:
				if not ally_state["dead"]:
					_add_roll_buff(ally_state, roll_buff_amount, roll_buff_turns)

	if damage <= 0 and poison_amount > 0:
		var poison_target: Dictionary = _find_target_by_id(_enemy_states, str(hero_state.get("selected_target_id", "")))
		if poison_target.is_empty():
			poison_target = _first_living_state(_enemy_states)
		_apply_poison(poison_target, poison_amount, poison_turns)

	# RFE application (roll debuff on enemies)
	var rfe_amount: int = int(raw.get("rfe", 0))
	var rfe_turns: int = int(raw.get("rfT", 1))
	var rfe_all: bool = bool(raw.get("rfeAll", false))
	if rfe_amount > 0:
		if rfe_all:
			for enemy_state in _enemy_states:
				if not enemy_state["dead"]:
					_add_rfe_stack(enemy_state, rfe_amount, rfe_turns)
		else:
			var rfe_target: Dictionary = _find_target_by_id(_enemy_states, str(hero_state.get("selected_target_id", "")))
			if rfe_target.is_empty():
				rfe_target = _first_living_state(_enemy_states)
			if not rfe_target.is_empty():
				_add_rfe_stack(rfe_target, rfe_amount, rfe_turns)

	# Cloak application
	if bool(raw.get("cloak", false)):
		hero_state["cloaked"] = true
		_log("%s is now cloaked." % hero_state["unit"].display_name)
		_emit_event(hero_state, "cloak", 0, "hero")
	if bool(raw.get("cloakAll", false)):
		for ally_state in _hero_states:
			if not ally_state["dead"]:
				ally_state["cloaked"] = true
				_log("%s is now cloaked." % ally_state["unit"].display_name)
				_emit_event(ally_state, "cloak", 0, "hero")

	# Freeze die application
	var freeze_enemy: int = int(raw.get("freezeEnemyDice", 0))
	var freeze_all_enemy: int = int(raw.get("freezeAllEnemyDice", 0))
	var freeze_any: int = int(raw.get("freezeAnyDice", 0))
	var freeze_amount: int = maxi(maxi(freeze_enemy, freeze_all_enemy), freeze_any)
	if freeze_amount > 0:
		if freeze_all_enemy > 0:
			for es in _enemy_states:
				if not es["dead"]:
					_freeze_die_state(es, freeze_amount)
		else:
			var freeze_target: Dictionary = {}
			if freeze_any > 0:
				freeze_target = _find_target_by_id(_hero_states, str(hero_state.get("selected_target_id", "")))
			if freeze_target.is_empty():
				freeze_target = _find_target_by_id(_enemy_states, str(hero_state.get("selected_target_id", "")))
			if freeze_target.is_empty():
				freeze_target = _first_living_state(_enemy_states)
			if not freeze_target.is_empty():
				_freeze_die_state(freeze_target, freeze_amount)


func _apply_enemy_ability(enemy_state: Dictionary, ability_entry: Dictionary) -> void:
	var raw: Dictionary = ability_entry.get("raw", {})
	# Phase 2: substitute enhanced damage value when boss has crossed its HP threshold
	var damage: int = int(raw.get("dmg", 0))
	if bool(enemy_state.get("in_phase_two", false)) and raw.has("dmgP2"):
		damage = int(raw.get("dmgP2", damage))
	var heal: int = int(raw.get("heal", 0))
	var shield: int = int(raw.get("shield", 0))
	var sh_turns: int = int(raw.get("shT", 1))
	var shield_ally: int = int(raw.get("shieldAlly", 0))
	var shield_ally_turns: int = int(raw.get("shAllyT", 1))
	var poison_amount: int = int(raw.get("dot", 0))
	var poison_turns: int = int(raw.get("dT", 0))

	if shield > 0:
		_add_shield_stack(enemy_state, shield, sh_turns)

	if shield_ally > 0:
		var enemy_ally: Dictionary = _find_target_by_id(_enemy_states, str(enemy_state.get("selected_target_id", "")))
		if enemy_ally.is_empty():
			enemy_ally = _first_living_state(_enemy_states)
		if not enemy_ally.is_empty():
			_add_shield_stack(enemy_ally, shield_ally, shield_ally_turns)

	if heal > 0:
		_heal_state(enemy_state, heal)

	if damage > 0:
		var target_hero: Dictionary = _find_target_by_id(_hero_states, str(enemy_state.get("selected_target_id", "")))
		if target_hero.is_empty():
			target_hero = _first_living_state(_hero_states)
		if not target_hero.is_empty():
			# Apply damage scaling from battle index
			var scaled_damage: int = int(round(float(damage) * float(enemy_state.get("dmg_scale", 1.0))))
			# Rampage: double damage and consume one charge
			var final_damage: int = scaled_damage
			if final_damage > 0 and int(enemy_state.get("rampage_charges", 0)) > 0:
				final_damage = scaled_damage * 2
				enemy_state["rampage_charges"] = int(enemy_state["rampage_charges"]) - 1
				_log("%s triggers Rampage! (2× damage)" % enemy_state["unit"].display_name)
			# Pack bonus: +1 per living same-id ally (excluding self)
			if bool(raw.get("packBonus", false)) and final_damage > 0:
				var pack_count: int = 0
				for es in _enemy_states:
					if es == enemy_state:
						continue
					if not es["dead"] and str(es["id"]) == str(enemy_state["id"]):
						pack_count += 1
				if pack_count > 0:
					final_damage += pack_count
					_log("%s pack bonus +%d (pack size: %d)." % [enemy_state["unit"].display_name, pack_count, pack_count])
			# Apply enemy damage multiplier relic
			final_damage = int(floor(float(final_damage) * _get_enemy_dmg_mult()))
			_damage_state(target_hero, final_damage)
			_apply_poison(target_hero, poison_amount, poison_turns)
			# Lifesteal: heal self for % of damage dealt
			var lifesteal_pct: int = int(raw.get("lifestealPct", 0))
			if lifesteal_pct > 0 and final_damage > 0:
				var heal_amount: int = int(floor(float(final_damage) * float(lifesteal_pct) / 100.0))
				if heal_amount > 0:
					_heal_state(enemy_state, heal_amount)
					_log("%s lifesteals %d HP." % [enemy_state["unit"].display_name, heal_amount])
			# wipeShields: boss overload strips all hero shield stacks after the hit lands
			if bool(raw.get("wipeShields", false)):
				for hero_state in _hero_states:
					if not bool(hero_state["dead"]):
						hero_state["shield_stacks"].clear()
						hero_state["shield"] = 0
				_log("%s wipes all hero shields!" % enemy_state["unit"].display_name)
				_emit_event(enemy_state, "wipe_shields", 0, "enemy")

	if damage <= 0 and poison_amount > 0:
		var poison_target: Dictionary = _find_target_by_id(_hero_states, str(enemy_state.get("selected_target_id", "")))
		if poison_target.is_empty():
			poison_target = _first_living_state(_hero_states)
		if not poison_target.is_empty():
			_apply_poison(poison_target, poison_amount, poison_turns)

	# RFE on heroes (roll debuff from enemies using rfm/rfmT keys)
	var rfm_amount: int = int(raw.get("rfm", 0))
	var rfm_turns: int = int(raw.get("rfmT", 1))
	if rfm_amount > 0:
		var hero_target: Dictionary = _find_target_by_id(_hero_states, str(enemy_state.get("selected_target_id", "")))
		if hero_target.is_empty():
			hero_target = _first_living_state(_hero_states)
		if not hero_target.is_empty():
			_add_rfe_stack(hero_target, rfm_amount, rfm_turns)

	# ERB: enemy roll buff
	var erb_amount: int = int(raw.get("erb", 0))
	var erb_turns: int = int(raw.get("erbT", 1))
	var erb_all: bool = bool(raw.get("erbAll", false))
	if erb_amount > 0:
		if erb_all:
			for es in _enemy_states:
				if not es["dead"]:
					es["roll_buff"] = int(es.get("roll_buff", 0)) + erb_amount
					es["roll_buff_turns"] = maxi(int(es.get("roll_buff_turns", 0)), erb_turns)
					_log("%s gains +%d roll buff (%dt)." % [es["unit"].display_name, erb_amount, erb_turns])
		else:
			enemy_state["roll_buff"] = int(enemy_state.get("roll_buff", 0)) + erb_amount
			enemy_state["roll_buff_turns"] = maxi(int(enemy_state.get("roll_buff_turns", 0)), erb_turns)
			_log("%s gains +%d roll buff (%dt)." % [enemy_state["unit"].display_name, erb_amount, erb_turns])

	# Cower: apply to targeted hero or all heroes
	var cower_t: int = int(raw.get("cowerT", 0))
	var cower_all: bool = bool(raw.get("cowerAll", false))
	if cower_t > 0 or cower_all:
		var cower_amount: int = maxi(cower_t, 1)
		if cower_all:
			for hero_state in _hero_states:
				if not hero_state["dead"]:
					hero_state["cower_turns"] = maxi(int(hero_state.get("cower_turns", 0)), cower_amount)
					_log("%s is cowered for %d turn(s)." % [hero_state["unit"].display_name, cower_amount])
		else:
			var cower_target: Dictionary = _find_target_by_id(_hero_states, str(enemy_state.get("selected_target_id", "")))
			if cower_target.is_empty():
				cower_target = _first_living_state(_hero_states)
			if not cower_target.is_empty():
				cower_target["cower_turns"] = maxi(int(cower_target.get("cower_turns", 0)), cower_amount)
				_log("%s is cowered for %d turn(s)." % [cower_target["unit"].display_name, cower_amount])

	# Rampage grants (self or all enemies)
	var grant_rampage: int = int(raw.get("grantRampage", 0))
	var grant_rampage_all: bool = bool(raw.get("grantRampageAll", false))
	if grant_rampage > 0 or grant_rampage_all:
		var charges: int = maxi(grant_rampage, 1)
		if grant_rampage_all:
			for es in _enemy_states:
				if not es["dead"]:
					es["rampage_charges"] = int(es.get("rampage_charges", 0)) + charges
					_log("%s gains %d rampage charge(s)." % [es["unit"].display_name, charges])
		else:
			enemy_state["rampage_charges"] = int(enemy_state.get("rampage_charges", 0)) + charges
			_log("%s gains %d rampage charge(s)." % [enemy_state["unit"].display_name, charges])

	# Counterspell: prime enemy to reflect next hero attack
	var counter_pct: int = int(raw.get("counterspellPct", 0))
	if counter_pct > 0:
		enemy_state["counter_pct"] = counter_pct
		_log("%s is primed to counter (%d%%)." % [enemy_state["unit"].display_name, counter_pct])

	# Curse dice: targeted hero rolls twice and keeps lower next round
	if bool(raw.get("curseDice", false)):
		var curse_target: Dictionary = _find_target_by_id(_hero_states, str(enemy_state.get("selected_target_id", "")))
		if curse_target.is_empty():
			curse_target = _first_living_state(_hero_states)
		if not curse_target.is_empty():
			curse_target["cursed"] = true
			_log("%s is CURSED — next roll will be the lower of two dice." % curse_target["unit"].display_name)
			_emit_event(curse_target, "curse", 0, "hero")

	# Taunt: force all heroes to target this enemy next player phase
	if bool(raw.get("enemySelfTaunt", false)):
		for es in _enemy_states:
			es["taunting"] = false
		enemy_state["taunting"] = true
		_log("%s is taunting — all heroes must target it!" % enemy_state["unit"].display_name)

	# Summon: probabilistic reinforcement on qualifying ability rolls
	var summon_chance: int = int(raw.get("summonChance", 0))
	var summon_name: String = str(raw.get("summonName", ""))
	if summon_chance > 0 and summon_name != "":
		if randi_range(1, 100) <= summon_chance:
			_log("%s calls for reinforcements — %s incoming!" % [enemy_state["unit"].display_name, summon_name])
			_round_events.append({
				"type": "summon",
				"amount": 0,
				"side": "enemy",
				"target_name": str(enemy_state["unit"].display_name),
				"summon_name": summon_name,
			})


func _damage_state(state: Dictionary, amount: int) -> void:
	if state.is_empty() or state["dead"] or amount <= 0:
		return

	# Cloak: 80% dodge chance — all-or-nothing, consumed on any attempt
	if bool(state.get("cloaked", false)):
		if randf() < 0.80:
			_log("%s evades the attack (cloaked)!" % state["unit"].display_name)
			_emit_event(state, "evade", 0, _resolve_side_for_state(state))
			state["cloaked"] = false
			return
		else:
			_log("%s's cloak failed to evade!" % state["unit"].display_name)
			state["cloaked"] = false

	# Gear: dmgReduction for hero states
	if _is_hero_state(state):
		var reduction: int = int(state.get("gear_dmg_reduction", 0))
		if reduction > 0:
			amount = maxi(0, amount - reduction)
			if amount == 0:
				return

	var remaining_damage: int = amount

	# Absorb damage from shield stacks in FIFO order
	var stacks: Array = state.get("shield_stacks", [])
	var total_absorbed: int = 0
	var i: int = 0
	while i < stacks.size() and remaining_damage > 0:
		var stack: Dictionary = stacks[i]
		var available: int = int(stack["amt"])
		var absorbed: int = mini(available, remaining_damage)
		stack["amt"] = available - absorbed
		remaining_damage -= absorbed
		total_absorbed += absorbed
		i += 1

	# Remove depleted stacks
	var surviving_stacks: Array = []
	for stack in stacks:
		if int(stack["amt"]) > 0:
			surviving_stacks.append(stack)
	state["shield_stacks"] = surviving_stacks
	state["shield"] = _get_total_shield(state)

	if total_absorbed > 0:
		_log("%s absorbs %d damage with shields." % [state["unit"].display_name, total_absorbed])
		_emit_event(state, "block", total_absorbed, _resolve_side_for_state(state))

	if remaining_damage <= 0:
		return

	state["current_hp"] = maxi(0, int(state["current_hp"]) - remaining_damage)
	_log("%s takes %d damage." % [state["unit"].display_name, remaining_damage])
	_emit_event(state, "damage", remaining_damage, _resolve_side_for_state(state))

	if int(state["current_hp"]) <= 0:
		# Gear: surviveOnce check
		if bool(state.get("gear_survive_once", false)) and not bool(state.get("gear_survive_once_used", false)):
			state["current_hp"] = 1
			state["gear_survive_once_used"] = true
			_log("%s survives on Dead Man's Chip at 1 HP!" % state["unit"].display_name)
			_emit_event(state, "survive", 1, _resolve_side_for_state(state))
		else:
			state["current_hp"] = 0
			state["dead"] = true
			_clear_active_statuses_for_down_state(state)
			_cancel_targets_involving_down_state(state)
			_log("%s is down." % state["unit"].display_name)
			_on_unit_killed(state)


func _freeze_die_state(state: Dictionary, freeze_amount: int) -> void:
	state["die_freeze_turns"] = maxi(int(state.get("die_freeze_turns", 0)), freeze_amount)
	var last_die_value: int = int(state.get("last_die_value", state.get("frozen_die_value", 0)))
	if last_die_value > 0:
		state["frozen_die_value"] = last_die_value
	_log("%s's die is frozen at %d for %d reveal(s)." % [state["unit"].display_name, int(state.get("frozen_die_value", 0)), freeze_amount])
	_emit_event(state, "freeze", int(state.get("frozen_die_value", 0)), _resolve_side_for_state(state))


func _on_unit_killed(dead_state: Dictionary) -> void:
	if _chain_reaction_active:
		return
	_chain_reaction_active = true

	# Chain Reaction relic: other living enemies take damage when an enemy dies
	if has_relic("chainReaction") and not _is_hero_state(dead_state):
		var chain_dmg = int(_get_relic_value("chainReaction", "amount", 4))
		for enemy_state in _enemy_states:
			if not enemy_state["dead"] and enemy_state != dead_state:
				_damage_state(enemy_state, chain_dmg)
		_log("Chain Reaction triggers!")

	# Scavenger Rig (gear): heroes with healOnKill heal when any enemy dies
	if not _is_hero_state(dead_state):
		for hero_state in _hero_states:
			if not hero_state["dead"]:
				var heal_on_kill: int = int(hero_state.get("gear_heal_on_kill", 0))
				if heal_on_kill > 0:
					_heal_state(hero_state, heal_on_kill)
					_log("%s Scavenger Rig heals %d on kill." % [hero_state["unit"].display_name, heal_on_kill])

	_chain_reaction_active = false


func _clear_active_statuses_for_down_state(state: Dictionary) -> void:
	state["shield"] = 0
	state["shield_stacks"] = []
	state["poison"] = 0
	state["poison_turns"] = 0
	state["poison_skip_next_tick"] = false
	state["rfe_stacks"] = []
	state["roll_buff"] = 0
	state["roll_buff_turns"] = 0
	state["dmg_scale"] = 1.0
	state["cloaked"] = false
	state["cower_turns"] = 0
	state["die_freeze_turns"] = 0
	state["rampage_charges"] = 0
	state["counter_pct"] = 0
	state["cursed"] = false
	state["taunting"] = false
	state["frozen_die_value"] = 0
	state["die_freeze_consumed_this_round"] = false
	state["perm_rfe"] = 0
	state["in_phase_two"] = false


func _cancel_targets_involving_down_state(down_state: Dictionary) -> void:
	var down_id: String = str(down_state.get("id", ""))
	for state_variant in _hero_states + _enemy_states:
		var state: Dictionary = state_variant
		if state == down_state or str(state.get("selected_target_id", "")) == down_id:
			state["selected_target_id"] = ""
			state["target_display"] = "--"


func _is_hero_state(state: Dictionary) -> bool:
	for h in _hero_states:
		if h == state:
			return true
	return false


func _heal_state(state: Dictionary, amount: int) -> void:
	if state.is_empty() or state["dead"] or amount <= 0:
		return
	var before_hp: int = int(state["current_hp"])
	state["current_hp"] = mini(int(state["max_hp"]), int(state["current_hp"]) + amount)
	var healed_amount: int = int(state["current_hp"]) - before_hp
	if healed_amount > 0:
		_log("%s heals %d HP." % [state["unit"].display_name, healed_amount])
		_emit_event(state, "heal", healed_amount, _resolve_side_for_state(state))


func _apply_poison(state: Dictionary, amount: int, turns: int) -> void:
	if state.is_empty() or state["dead"] or amount <= 0 or turns <= 0:
		return
	state["poison"] = int(state["poison"]) + amount
	state["poison_turns"] = maxi(int(state["poison_turns"]), turns)
	state["poison_skip_next_tick"] = true
	_log("%s is poisoned for %d over %d turns." % [state["unit"].display_name, amount, turns])
	_emit_event(state, "poison", amount, _resolve_side_for_state(state))


func _first_living_state(states: Array) -> Dictionary:
	for state in states:
		if not state["dead"]:
			return state
	return {}


func _lowest_hp_state(states: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_ratio: float = 2.0
	for state in states:
		if state["dead"]:
			continue
		var max_hp: int = maxi(int(state["max_hp"]), 1)
		var ratio: float = float(state["current_hp"]) / float(max_hp)
		if ratio < best_ratio:
			best_ratio = ratio
			best = state
	return best


func _all_states_dead(states: Array) -> bool:
	for state in states:
		if not state["dead"]:
			return false
	return true


func _find_target_by_id(states: Array, target_id: String) -> Dictionary:
	if target_id == "":
		return {}
	for state in states:
		if state["dead"]:
			continue
		if str(state["id"]) == target_id:
			return state
	return {}


func _tick_end_of_round_states() -> void:
	for hero_state in _hero_states:
		_tick_state(hero_state)

	for enemy_state in _enemy_states:
		_tick_state(enemy_state)

	# Decrement cower turns for all living heroes
	for hero_state in _hero_states:
		if not hero_state["dead"] and int(hero_state.get("cower_turns", 0)) > 0:
			hero_state["cower_turns"] = int(hero_state["cower_turns"]) - 1

	# Clear taunt on all enemies at end of round (re-applied each round if enemy rolls it again)
	for enemy_state in _enemy_states:
		if not enemy_state["dead"]:
			enemy_state["taunting"] = false


func _tick_state(state: Dictionary) -> void:
	if state["dead"]:
		return

	if int(state["poison_turns"]) > 0 and int(state["poison"]) > 0:
		if bool(state.get("poison_skip_next_tick", false)):
			state["poison_skip_next_tick"] = false
		else:
			var dot_bonus: int = int(_get_relic_value("dotAmplified", "bonus", 0)) + _get_total_dot_bonus()
			var tick_dmg: int = int(state["poison"]) + dot_bonus
			_log("%s takes %d poison damage." % [state["unit"].display_name, tick_dmg])
			_damage_state(state, tick_dmg)
			state["poison_turns"] = int(state["poison_turns"]) - 1
			if int(state["poison_turns"]) <= 0:
				state["poison"] = 0
				state["poison_skip_next_tick"] = false

	# Tick shield stacks: decrement turns_left, remove expired
	if not state["dead"]:
		var new_shield_stacks: Array = []
		for stack in state.get("shield_stacks", []):
			var tl: int = int(stack["turns_left"]) - 1
			if tl > 0:
				new_shield_stacks.append({"amt": stack["amt"], "turns_left": tl})
		state["shield_stacks"] = new_shield_stacks
		state["shield"] = _get_total_shield(state)

	# Tick RFE stacks: decrement turns_left, remove expired
	if not state["dead"]:
		var new_rfe_stacks: Array = []
		for stack in state.get("rfe_stacks", []):
			var tl: int = int(stack["turns_left"]) - 1
			if tl > 0:
				new_rfe_stacks.append({"amt": stack["amt"], "turns_left": tl})
		state["rfe_stacks"] = new_rfe_stacks

	# Tick roll buff
	if int(state.get("roll_buff_turns", 0)) > 0:
		state["roll_buff_turns"] = int(state["roll_buff_turns"]) - 1
		if int(state["roll_buff_turns"]) <= 0:
			state["roll_buff"] = 0
			state["roll_buff_turns"] = 0


# --- Phase 2 threshold ---

func _check_phase_two_transitions() -> void:
	for enemy_state in _enemy_states:
		if bool(enemy_state["dead"]) or bool(enemy_state.get("in_phase_two", false)):
			continue
		var unit: EnemyData = enemy_state["unit"] as EnemyData
		if unit == null or int(unit.phase_two_threshold) <= 0:
			continue
		if int(enemy_state["current_hp"]) <= int(unit.phase_two_threshold):
			enemy_state["in_phase_two"] = true
			_log("%s ENTERS PHASE 2!" % unit.display_name)
			_emit_event(enemy_state, "phase2", 0, "enemy")


# --- Public item application methods ---

func apply_item_heal(target_state: Dictionary, amount: int) -> void:
	_heal_state(target_state, amount)


func apply_item_shield(target_state: Dictionary, amount: int, turns: int) -> void:
	_add_shield_stack(target_state, amount, turns)


func apply_item_roll_buff(target_state: Dictionary, amount: int, turns: int) -> void:
	target_state["roll_buff"] = int(target_state.get("roll_buff", 0)) + amount
	target_state["roll_buff_turns"] = maxi(int(target_state.get("roll_buff_turns", 0)), turns)


func apply_item_revive(target_state: Dictionary, hp_pct: int) -> void:
	if not bool(target_state.get("dead", true)):
		return
	target_state["dead"] = false
	target_state["current_hp"] = maxi(1, int(target_state["max_hp"]) * hp_pct / 100)
	target_state["cower_turns"] = 0
	target_state["poison"] = 0
	target_state["poison_turns"] = 0
	target_state["poison_skip_next_tick"] = false
	_log("%s is revived at %d HP!" % [target_state["unit"].display_name, int(target_state["current_hp"])])
	_emit_event(target_state, "heal", int(target_state["current_hp"]), "hero")


func apply_item_rfe(target_state: Dictionary, amount: int, turns: int) -> void:
	_add_rfe_stack(target_state, amount, turns)


func apply_item_damage(target_state: Dictionary, amount: int) -> void:
	_damage_state(target_state, amount)


func apply_item_dot(target_state: Dictionary, amount: int, turns: int) -> void:
	_apply_poison(target_state, amount, turns)


# --- Summon injection ---

func inject_enemy(enemy_data: EnemyData) -> Dictionary:
	var new_state: Dictionary = _create_runtime_state(enemy_data, _next_enemy_instance_id(enemy_data))
	_enemy_states.append(new_state)
	_log("%s has been summoned to the field!" % enemy_data.display_name)
	return new_state


# --- Log / event helpers ---

func _log(message: String) -> void:
	_round_log.append(message)


func _emit_event(state: Dictionary, event_type: String, amount: int, side: String) -> void:
	_round_events.append({
		"type": event_type,
		"amount": amount,
		"side": side,
		"target_id": str(state["id"]),
		"target_name": str(state["unit"].display_name),
	})


func _emit_action_event(state: Dictionary, side: String, ability_name: String) -> void:
	_round_events.append({
		"type": "action_start",
		"amount": 0,
		"side": side,
		"actor_id": str(state["id"]),
		"actor_name": str(state["unit"].display_name),
		"ability": ability_name,
	})


func _resolve_side_for_state(state: Dictionary) -> String:
	for hero_state in _hero_states:
		if hero_state == state:
			return "hero"
	return "enemy"
