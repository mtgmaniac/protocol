@tool
class_name AbilityAudit
extends RefCounted

const HEROES_DATA_PATH := "res://data/raw/heroes.data.json"
const AUDIT_ROLL := 10

const EFFECT_FIELDS := [
	"dmg",
	"dMin",
	"dMax",
	"dot",
	"dT",
	"rfe",
	"rfT",
	"rfeAll",
	"rfm",
	"rfmT",
	"rfmTgt",
	"heal",
	"healTgt",
	"healAll",
	"healLowest",
	"shield",
	"shT",
	"shTgt",
	"shieldAll",
	"blastAll",
	"ignSh",
	"cloak",
	"freezeAnyDice",
	"freezeEnemyDice",
	"freezeAllEnemyDice",
	"taunt",
	"revive",
]

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []
var _started_msec: int = 0
var _timeout_msec: int = 10000


func run(timeout_msec: int = 10000) -> Dictionary:
	_passed = 0
	_failed = 0
	_failures.clear()
	_started_msec = Time.get_ticks_msec()
	_timeout_msec = maxi(timeout_msec, 1000)

	print("Ability Audit: reading %s" % HEROES_DATA_PATH)
	var abilities: Array[Dictionary] = _load_hero_abilities()
	if abilities.is_empty():
		_record_failure("heroes.data.json", "load", "at least one hero ability", "no abilities parsed")
		_print_summary()
		return _result()

	for effect_field in EFFECT_FIELDS:
		if _timed_out():
			_record_failure("Ability Audit", "timeout", "complete within %d ms" % _timeout_msec, "stopped after %d ms" % (Time.get_ticks_msec() - _started_msec))
			break
		var ability: Dictionary = _find_ability_for_field(abilities, effect_field)
		if ability.is_empty():
			_record_failure("Missing ability", effect_field, "at least one ability using %s" % effect_field, "none found")
			continue
		_run_effect_audit(effect_field, ability)

	_print_summary()
	return _result()


func _timed_out() -> bool:
	return Time.get_ticks_msec() - _started_msec > _timeout_msec


func _result() -> Dictionary:
	return {
		"passed": _passed,
		"failed": _failed,
		"failures": _failures.duplicate(),
	}


func _load_hero_abilities() -> Array[Dictionary]:
	var parsed: Variant = _parse_json_file(HEROES_DATA_PATH)
	if not (parsed is Dictionary):
		return []

	var abilities: Array[Dictionary] = []
	for hero_variant in (parsed as Dictionary).get("heroes", []):
		var hero: Dictionary = hero_variant
		var hero_name: String = str(hero.get("name", hero.get("id", "Unknown Hero")))
		_collect_abilities_from_list(abilities, hero_name, "base", hero.get("abilities", []))
		for evolution_variant in hero.get("evolutions", []):
			var evolution: Dictionary = evolution_variant
			_collect_abilities_from_list(abilities, hero_name, str(evolution.get("name", "evolution")), evolution.get("abilities", []))
	return abilities


func _collect_abilities_from_list(out: Array[Dictionary], hero_name: String, source_name: String, ability_list: Array) -> void:
	for ability_variant in ability_list:
		var raw: Dictionary = ability_variant
		out.append({
			"hero_name": hero_name,
			"source_name": source_name,
			"ability_name": str(raw.get("name", "Unnamed Ability")),
			"raw": raw.duplicate(true),
		})


func _parse_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("Ability audit missing JSON file: %s" % path)
		return null
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed == null:
		push_warning("Ability audit failed to parse JSON file: %s" % path)
	return parsed


func _find_ability_for_field(abilities: Array[Dictionary], effect_field: String) -> Dictionary:
	var best: Dictionary = {}
	var best_score: int = -1
	for ability in abilities:
		var raw: Dictionary = ability.get("raw", {})
		if not raw.has(effect_field):
			continue
		if not _field_is_meaningful(raw, effect_field):
			continue
		var score: int = _score_ability_for_field(raw, effect_field)
		if score > best_score:
			best = ability
			best_score = score
	return best


func _field_is_meaningful(raw: Dictionary, effect_field: String) -> bool:
	var value: Variant = raw.get(effect_field)
	if value is bool:
		return bool(value)
	if value is int or value is float:
		return int(value) > 0
	return value != null


func _score_ability_for_field(raw: Dictionary, effect_field: String) -> int:
	var score: int = 0
	match effect_field:
		"rfT":
			score += int(raw.get("rfT", 0)) * 10
			score += int(raw.get("rfe", 0))
		"shT":
			score += int(raw.get("shT", 0)) * 10
			score += int(raw.get("shield", 0))
		"rfmT":
			score += int(raw.get("rfmT", 0)) * 10
			score += int(raw.get("rfm", 0))
		"dT":
			score += int(raw.get("dT", 0)) * 10
			score += int(raw.get("dot", 0))
		_:
			score += int(raw.get(effect_field, 1)) if not (raw.get(effect_field) is bool) else 1
	return score


func _run_effect_audit(effect_field: String, ability: Dictionary) -> void:
	var ability_name: String = _ability_label(ability)
	var raw: Dictionary = (ability.get("raw", {}) as Dictionary).duplicate(true)
	var context: Dictionary = _build_context(raw, ability_name)
	var manager: CombatManager = context["manager"]
	var actor: Dictionary = context["actor"]
	var ally_a: Dictionary = context["ally_a"]
	var ally_b: Dictionary = context["ally_b"]
	var enemy_a: Dictionary = context["enemy_a"]
	var enemy_b: Dictionary = context["enemy_b"]

	match effect_field:
		"dmg", "dMin", "dMax", "dot", "dT", "rfe", "rfT", "freezeEnemyDice", "ignSh":
			actor["selected_target_id"] = str(enemy_a["id"])
		"healTgt", "shTgt", "rfmTgt", "freezeAnyDice", "revive":
			actor["selected_target_id"] = str(ally_a["id"])

	_prepare_state_for_effect(effect_field, context)

	var before: Dictionary = _snapshot_context(context)
	var result: Dictionary = manager.resolve_round({str(actor["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var after: Dictionary = _snapshot_context(context)
	var assertion: Dictionary = _assert_effect(effect_field, raw, before, after, result)

	if bool(assertion.get("ok", false)):
		_record_pass(ability_name, effect_field)
	else:
		_record_failure(
			ability_name,
			effect_field,
			str(assertion.get("expected", "")),
			str(assertion.get("actual", ""))
		)


func _build_context(raw: Dictionary, ability_name: String) -> Dictionary:
	var actor_unit: UnitData = _make_unit("audit_actor", "Audit Actor", ability_name, raw)
	var ally_a_unit: UnitData = _make_unit("audit_ally_a", "Audit Ally A", "Noop", {})
	var ally_b_unit: UnitData = _make_unit("audit_ally_b", "Audit Ally B", "Noop", {})
	var enemy_a_unit: EnemyData = _make_enemy("audit_enemy_a", "Audit Enemy A")
	var enemy_b_unit: EnemyData = _make_enemy("audit_enemy_b", "Audit Enemy B")

	var manager: CombatManager = CombatManager.new()
	manager.setup_battle([actor_unit, ally_a_unit, ally_b_unit], [enemy_a_unit, enemy_b_unit])
	var heroes: Array = manager.get_hero_states()
	var enemies: Array = manager.get_enemy_states()

	return {
		"manager": manager,
		"actor": heroes[0],
		"ally_a": heroes[1],
		"ally_b": heroes[2],
		"enemy_a": enemies[0],
		"enemy_b": enemies[1],
	}


func _make_unit(id: String, display_name: String, ability_name: String, raw: Dictionary) -> UnitData:
	var unit: UnitData = UnitData.new()
	unit.id = id
	unit.display_name = display_name
	unit.max_hp = 100
	unit.dice_ranges = [_make_ability_entry(ability_name, raw)]
	return unit


func _make_enemy(id: String, display_name: String) -> EnemyData:
	var enemy: EnemyData = EnemyData.new()
	enemy.id = id
	enemy.display_name = display_name
	enemy.max_hp = 100
	enemy.dice_ranges = [_make_ability_entry("Noop", {})]
	return enemy


func _make_ability_entry(ability_name: String, raw: Dictionary) -> Dictionary:
	return {
		"min": 1,
		"max": 20,
		"zone": "audit",
		"ability_name": ability_name,
		"description": str(raw.get("eff", "")),
		"raw": raw.duplicate(true),
	}


func _prepare_state_for_effect(effect_field: String, context: Dictionary) -> void:
	var actor: Dictionary = context["actor"]
	var ally_a: Dictionary = context["ally_a"]
	var ally_b: Dictionary = context["ally_b"]
	var enemy_a: Dictionary = context["enemy_a"]
	var enemy_b: Dictionary = context["enemy_b"]

	actor["last_die_value"] = 7
	ally_a["last_die_value"] = 8
	enemy_a["last_die_value"] = 9
	enemy_b["last_die_value"] = 10

	match effect_field:
		"heal":
			actor["current_hp"] = 40
		"healTgt", "healLowest":
			ally_a["current_hp"] = 25
			ally_b["current_hp"] = 80
		"healAll":
			actor["current_hp"] = 50
			ally_a["current_hp"] = 40
			ally_b["current_hp"] = 30
		"shield", "shT":
			actor["shield_stacks"] = []
			actor["shield"] = 0
		"shTgt":
			ally_a["shield_stacks"] = []
			ally_a["shield"] = 0
		"shieldAll":
			for state in [actor, ally_a, ally_b]:
				state["shield_stacks"] = []
				state["shield"] = 0
		"rfm", "rfmT":
			for state in [actor, ally_a, ally_b]:
				state["roll_buff"] = 0
				state["roll_buff_turns"] = 0
		"rfmTgt":
			ally_a["roll_buff"] = 0
			ally_a["roll_buff_turns"] = 0
		"rfe", "rfT", "rfeAll":
			for state in [enemy_a, enemy_b]:
				state["rfe_stacks"] = []
		"ignSh":
			enemy_a["shield_stacks"] = [{"amt": 25, "turns_left": 3}]
			enemy_a["shield"] = 25
		"freezeAnyDice":
			ally_a["die_freeze_turns"] = 0
			ally_a["frozen_die_value"] = 0
		"freezeEnemyDice":
			enemy_a["die_freeze_turns"] = 0
			enemy_a["frozen_die_value"] = 0
		"freezeAllEnemyDice":
			for state in [enemy_a, enemy_b]:
				state["die_freeze_turns"] = 0
				state["frozen_die_value"] = 0
		"revive":
			ally_a["dead"] = true
			ally_a["current_hp"] = 0


func _snapshot_context(context: Dictionary) -> Dictionary:
	return {
		"actor": _snapshot_state(context["actor"]),
		"ally_a": _snapshot_state(context["ally_a"]),
		"ally_b": _snapshot_state(context["ally_b"]),
		"enemy_a": _snapshot_state(context["enemy_a"]),
		"enemy_b": _snapshot_state(context["enemy_b"]),
	}


func _snapshot_state(state: Dictionary) -> Dictionary:
	return {
		"id": str(state.get("id", "")),
		"hp": int(state.get("current_hp", 0)),
		"max_hp": int(state.get("max_hp", 0)),
		"dead": bool(state.get("dead", false)),
		"shield": int(state.get("shield", 0)),
		"shield_stacks": (state.get("shield_stacks", []) as Array).duplicate(true),
		"poison": int(state.get("poison", 0)),
		"poison_turns": int(state.get("poison_turns", 0)),
		"rfe_total": _sum_stack_amounts(state.get("rfe_stacks", [])),
		"rfe_stacks": (state.get("rfe_stacks", []) as Array).duplicate(true),
		"roll_buff": int(state.get("roll_buff", 0)),
		"roll_buff_turns": int(state.get("roll_buff_turns", 0)),
		"cloaked": bool(state.get("cloaked", false)),
		"freeze_turns": int(state.get("die_freeze_turns", 0)),
		"frozen_die_value": int(state.get("frozen_die_value", 0)),
		"taunting": bool(state.get("taunting", false)),
	}


func _sum_stack_amounts(stacks: Array) -> int:
	var total: int = 0
	for stack_variant in stacks:
		var stack: Dictionary = stack_variant
		total += int(stack.get("amt", 0))
	return total


func _assert_effect(effect_field: String, raw: Dictionary, before: Dictionary, after: Dictionary, result: Dictionary) -> Dictionary:
	var events: Array = result.get("events", [])
	var damage_amount: int = int(raw.get("dmg", raw.get("dMin", 0)))
	var dot_amount: int = int(raw.get("dot", 0))
	var dot_turns: int = int(raw.get("dT", 0))
	var rfe_amount: int = int(raw.get("rfe", 0))
	var rfe_turns: int = int(raw.get("rfT", 1))
	var roll_buff_amount: int = int(raw.get("rfm", 0))
	var roll_buff_turns: int = int(raw.get("rfmT", 1))
	var heal_amount: int = int(raw.get("heal", 0))
	var shield_amount: int = int(raw.get("shield", 0))
	var shield_turns: int = int(raw.get("shT", 1))

	match effect_field:
		"dmg", "dMin", "dMax":
			return _expect_int_delta(effect_field, damage_amount, before.enemy_a.hp - after.enemy_a.hp, "enemy HP loss")
		"dot":
			return _expect_int_delta(effect_field, dot_amount, after.enemy_a.poison, "enemy poison amount")
		"dT":
			return _expect_int_delta(effect_field, dot_turns, after.enemy_a.poison_turns, "enemy poison turns")
		"rfe":
			return _expect_min_int(effect_field, rfe_amount, after.enemy_a.rfe_total, "target enemy RFE")
		"rfT":
			return _expect_min_int(effect_field, maxi(rfe_turns - 1, 0), _max_stack_turns(after.enemy_a.rfe_stacks), "target enemy remaining RFE turns after end tick")
		"rfeAll":
			return _expect_bool(effect_field, after.enemy_a.rfe_total > 0 and after.enemy_b.rfe_total > 0, "RFE on all enemies", "enemy_a=%d enemy_b=%d" % [after.enemy_a.rfe_total, after.enemy_b.rfe_total])
		"rfm":
			return _expect_event_amount(effect_field, events, "roll_buff", roll_buff_amount, "hero")
		"rfmT":
			return _expect_bool(effect_field, _has_event(events, "roll_buff", roll_buff_amount, "hero"), "roll buff event for %d over %d turns" % [roll_buff_amount, roll_buff_turns], "events=%s" % str(events))
		"rfmTgt":
			return _expect_bool(effect_field, _has_target_event(events, "roll_buff", roll_buff_amount, "hero", "audit_ally_a"), "roll buff on selected ally", "events=%s" % str(events))
		"heal":
			return _expect_event_amount(effect_field, events, "heal", heal_amount, "hero")
		"healTgt":
			return _expect_bool(effect_field, _has_target_event(events, "heal", heal_amount, "hero", "audit_ally_a"), "heal on selected ally", "events=%s" % str(events))
		"healAll":
			return _expect_bool(effect_field, _count_events(events, "heal", "hero") >= 3, "heal events for all allies", "events=%s" % str(events))
		"healLowest":
			return _expect_bool(effect_field, _has_target_event(events, "heal", heal_amount, "hero", "audit_ally_a"), "heal on lowest HP ally", "events=%s" % str(events))
		"shield":
			return _expect_event_amount(effect_field, events, "shield", shield_amount, "hero")
		"shT":
			return _expect_bool(effect_field, _has_event(events, "shield", shield_amount, "hero") and shield_turns > 0, "shield event with shT=%d" % shield_turns, "events=%s" % str(events))
		"shTgt":
			return _expect_bool(effect_field, _has_target_event(events, "shield", shield_amount, "hero", "audit_ally_a"), "shield on selected ally", "events=%s" % str(events))
		"shieldAll":
			return _expect_bool(effect_field, _count_events(events, "shield", "hero") >= 3, "shield events for all allies", "events=%s" % str(events))
		"blastAll":
			return _expect_bool(effect_field, before.enemy_a.hp > after.enemy_a.hp and before.enemy_b.hp > after.enemy_b.hp, "damage on all enemies", "enemy_a_delta=%d enemy_b_delta=%d" % [before.enemy_a.hp - after.enemy_a.hp, before.enemy_b.hp - after.enemy_b.hp])
		"ignSh":
			return _expect_bool(effect_field, after.enemy_a.hp == before.enemy_a.hp - damage_amount and after.enemy_a.shield == before.enemy_a.shield, "pierce ignores shield and deals %d HP damage" % damage_amount, "hp_delta=%d shield_after=%d" % [before.enemy_a.hp - after.enemy_a.hp, after.enemy_a.shield])
		"cloak":
			return _expect_bool(effect_field, after.actor.cloaked, "actor cloaked", "cloaked=%s" % str(after.actor.cloaked))
		"freezeAnyDice":
			return _expect_bool(effect_field, after.ally_a.freeze_turns > 0 and after.ally_a.frozen_die_value == 8, "selected ally die frozen", "turns=%d value=%d" % [after.ally_a.freeze_turns, after.ally_a.frozen_die_value])
		"freezeEnemyDice":
			return _expect_bool(effect_field, after.enemy_a.freeze_turns > 0 and after.enemy_a.frozen_die_value == 9, "selected enemy die frozen", "turns=%d value=%d" % [after.enemy_a.freeze_turns, after.enemy_a.frozen_die_value])
		"freezeAllEnemyDice":
			return _expect_bool(effect_field, after.enemy_a.freeze_turns > 0 and after.enemy_b.freeze_turns > 0, "all enemy dice frozen", "enemy_a=%d enemy_b=%d" % [after.enemy_a.freeze_turns, after.enemy_b.freeze_turns])
		"taunt":
			return _expect_bool(effect_field, after.actor.taunting, "actor taunting after hero taunt ability", "taunting=%s" % str(after.actor.taunting))
		"revive":
			return _expect_bool(effect_field, not after.ally_a.dead and after.ally_a.hp == int(after.ally_a.max_hp * 0.5), "selected fallen ally revived at 50%% HP", "dead=%s hp=%d" % [str(after.ally_a.dead), after.ally_a.hp])

	return {"ok": false, "expected": "known assertion for %s" % effect_field, "actual": "no assertion implemented"}


func _max_stack_turns(stacks: Array) -> int:
	var max_turns: int = 0
	for stack_variant in stacks:
		var stack: Dictionary = stack_variant
		max_turns = maxi(max_turns, int(stack.get("turns_left", 0)))
	return max_turns


func _expect_int_delta(effect_field: String, expected: int, actual: int, label: String) -> Dictionary:
	return _expect_bool(effect_field, actual == expected, "%s == %d" % [label, expected], "%s == %d" % [label, actual])


func _expect_min_int(effect_field: String, expected_min: int, actual: int, label: String) -> Dictionary:
	return _expect_bool(effect_field, actual >= expected_min, "%s >= %d" % [label, expected_min], "%s == %d" % [label, actual])


func _expect_event_amount(effect_field: String, events: Array, event_type: String, amount: int, side: String) -> Dictionary:
	return _expect_bool(effect_field, _has_event(events, event_type, amount, side), "%s event amount %d side %s" % [event_type, amount, side], "events=%s" % str(events))


func _expect_bool(_effect_field: String, ok: bool, expected: String, actual: String) -> Dictionary:
	return {
		"ok": ok,
		"expected": expected,
		"actual": actual,
	}


func _has_event(events: Array, event_type: String, amount: int, side: String) -> bool:
	for event_variant in events:
		var event: Dictionary = event_variant
		if str(event.get("type", "")) == event_type and int(event.get("amount", 0)) == amount and str(event.get("side", "")) == side:
			return true
	return false


func _has_target_event(events: Array, event_type: String, amount: int, side: String, target_id: String) -> bool:
	for event_variant in events:
		var event: Dictionary = event_variant
		if str(event.get("type", "")) != event_type:
			continue
		if int(event.get("amount", 0)) != amount:
			continue
		if str(event.get("side", "")) != side:
			continue
		if str(event.get("target_id", "")) == target_id:
			return true
	return false


func _count_events(events: Array, event_type: String, side: String) -> int:
	var count: int = 0
	for event_variant in events:
		var event: Dictionary = event_variant
		if str(event.get("type", "")) == event_type and str(event.get("side", "")) == side:
			count += 1
	return count


func _ability_label(ability: Dictionary) -> String:
	return "%s / %s / %s" % [
		str(ability.get("hero_name", "Unknown Hero")),
		str(ability.get("source_name", "base")),
		str(ability.get("ability_name", "Unnamed Ability")),
	]


func _record_pass(ability_name: String, effect_field: String) -> void:
	_passed += 1
	print("PASS [%s] %s" % [effect_field, ability_name])


func _record_failure(ability_name: String, effect_field: String, expected: String, actual: String) -> void:
	_failed += 1
	var message: String = "FAIL [%s] %s | expected: %s | actual: %s" % [effect_field, ability_name, expected, actual]
	_failures.append(message)
	push_warning(message)


func _print_summary() -> void:
	print("Ability Audit Complete: %d passed, %d failed" % [_passed, _failed])
	if not _failures.is_empty():
		print("Ability Audit Failures:")
		for failure in _failures:
			print("  - %s" % failure)
