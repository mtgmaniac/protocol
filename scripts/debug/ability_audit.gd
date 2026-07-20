@tool
class_name AbilityAudit
extends RefCounted

const HEROES_DATA_PATH := "res://data/raw/heroes.data.json"
const ENEMIES_DATA_PATH := "res://data/raw/enemies.data.json"
const BATTLE_SCENE_SCRIPT := preload("res://scripts/battle/battle_scene.gd")
const PROTOCOL_ACTIONS_SCRIPT := preload("res://scripts/battle/protocol_actions.gd")
const AUDIT_ROLL := 10

const META_FIELDS := [
	"zone",
	"range",
	"name",
	"eff",
	"callsign",
	"focus",
	"hp",
]

const PREVIEW_ONLY_FIELDS := [
	"dMin",
	"dMax",
]

const TARGETING_ONLY_FIELDS := [
	"rfeOnly",
]

const HERO_HANDLED_FIELDS := [
	"dmg",
	"heal",
	"shield",
	"blastAll",
	"healAll",
	"shieldAll",
	"healLowest",
	"shieldLowest",
	"shTgt",
	"healTgt",
	"burn",
	"burnT",
	"rfm",
	"rfmT",
	"rfmTgt",
	"ignSh",
	"rfe",
	"rfT",
	"rfeAll",
	"taunt",
	"revive",
	"reviveAll",
	"revivePct",
	"cloak",
	"cloakAll",
	"ward",
	"wardTgt",
	"chain",
	"detonate",
	"execute",
	"breach",
	"breachAll",
	"leech",
	"mark",
	"spike",
	"jam",
	"jamAll",
	"rewrite",
	"vsFrozenBonus",
	"freezeEnemyDice",
	"freezeAllEnemyDice",
	"freezeAnyDice",
	"freeze_flavor",
	"gainProtocol",
]

const ENEMY_HANDLED_FIELDS := [
	"dmg",
	"heal",
	"shield",
	"shieldAlly",
	"shieldAllyAll",
	"blastAll",
	"burn",
	"burnT",
	"packBonus",
	"lifestealPct",
	"wipeShields",
	"rfm",
	"rfmT",
	"erb",
	"erbT",
	"erbAll",
	"freezeEnemyDice",
	"freezeAllEnemyDice",
	"freeze_flavor",
	"grantRampage",
	"grantRampageAll",
	"ward",
	"spike",
	"jam",
	"jamAll",
	"rewrite",
	"hijack",
	"siphon",
	"cloak",
	"taunt",
	"enemySelfTaunt",
	"summonChance",
	"summonName",
]

# Data-driven effect audit coverage: every field here must appear on at least
# one hero ability in data. rfm/rfmT/rfmTgt left the hero kits in pkg3 (roll
# buffs are item/gear-only now) — their handlers stay covered by targeted
# regressions instead. freezeAnyDice is back in the Avalanche line (freeze =
# repeat, per Kev 2026-07-06: non-damage freezes target ANY unit).
const EFFECT_FIELDS := [
	"dmg",
	"dMin",
	"dMax",
	"burn",
	"burnT",
	"rfe",
	"rfT",
	"rfeAll",
	"heal",
	"healTgt",
	"healAll",
	"healLowest",
	"shield",
	"shTgt",
	"shieldAll",
	"shieldLowest",
	"blastAll",
	"ignSh",
	"cloak",
	"freezeEnemyDice",
	"freezeAllEnemyDice",
	"freezeAnyDice",
	"taunt",
	"revive",
]

var _passed: int = 0
var _failed: int = 0
var _failures: Array[String] = []
var _notes: Array[String] = []
var _started_msec: int = 0
var _timeout_msec: int = 10000


func run(timeout_msec: int = 10000) -> Dictionary:
	_passed = 0
	_failed = 0
	_failures.clear()
	_notes.clear()
	_started_msec = Time.get_ticks_msec()
	_timeout_msec = maxi(timeout_msec, 1000)
	# Sim pin (Build F, Task 3): audit regressions draw from FULL pools,
	# explicitly — audit results never depend on profile unlock state.
	DataManager.pin_pools_fully_unlocked()

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

	_run_targeting_audits()
	_run_keyword_gap_audit()
	_run_regression_audits()
	_run_text_alignment_audits()

	_print_summary()
	return _result()


func _timed_out() -> bool:
	return Time.get_ticks_msec() - _started_msec > _timeout_msec


func _result() -> Dictionary:
	return {
		"passed": _passed,
		"failed": _failed,
		"failures": _failures.duplicate(),
		"notes": _notes.duplicate(),
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


func _load_enemy_abilities() -> Array[Dictionary]:
	var parsed: Variant = _parse_json_file(ENEMIES_DATA_PATH)
	if not (parsed is Dictionary):
		return []

	var abilities: Array[Dictionary] = []
	var enemy_abilities: Dictionary = (parsed as Dictionary).get("enemyAbilities", {})
	for enemy_type in enemy_abilities.keys():
		var ability_set: Dictionary = enemy_abilities[enemy_type]
		for zone in ["recharge", "strike", "surge", "crit", "overload"]:
			var raw: Dictionary = ability_set.get(zone, {})
			if raw.is_empty():
				continue
			abilities.append({
				"enemy_type": str(enemy_type),
				"source_name": str(zone),
				"ability_name": str(raw.get("name", "Unnamed Ability")),
				"raw": raw.duplicate(true),
			})
	return abilities


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
		"rfmT":
			score += int(raw.get("rfmT", 0)) * 10
			score += int(raw.get("rfm", 0))
		"burnT":
			score += int(raw.get("burnT", 0)) * 10
			score += int(raw.get("burn", 0))
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
		"dmg", "dMin", "dMax", "burn", "burnT", "rfe", "rfT", "freezeEnemyDice", "ignSh":
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


func _run_keyword_gap_audit() -> void:
	var hero_abilities: Array[Dictionary] = _load_hero_abilities()
	var enemy_abilities: Array[Dictionary] = _load_enemy_abilities()
	var gaps: Dictionary = {}

	for ability in hero_abilities:
		_collect_keyword_gaps(ability, "hero", gaps)
	for ability in enemy_abilities:
		_collect_keyword_gaps(ability, "enemy", gaps)

	if gaps.is_empty():
		_record_pass("Keyword gap audit", "all keys handled or classified")
		return

	for field in gaps.keys():
		var labels: Array = gaps[field]
		_record_failure(
			"Keyword gap audit",
			str(field),
			"handled in combat_manager or classified as preview/targeting metadata",
			"%d abilities: %s" % [labels.size(), ", ".join(labels.slice(0, 3))]
		)


func _collect_keyword_gaps(ability: Dictionary, side: String, gaps: Dictionary) -> void:
	var raw: Dictionary = ability.get("raw", {})
	var label: String = _ability_label(ability) if side == "hero" else _enemy_ability_label(ability)
	var handled: Array = HERO_HANDLED_FIELDS if side == "hero" else ENEMY_HANDLED_FIELDS

	for field in raw.keys():
		var field_name: String = str(field)
		if field_name in META_FIELDS:
			continue
		if field_name in PREVIEW_ONLY_FIELDS or field_name in TARGETING_ONLY_FIELDS:
			continue
		if field_name in handled:
			continue
		if not _field_is_meaningful(raw, field_name):
			continue
		if not gaps.has(field_name):
			gaps[field_name] = []
		(gaps[field_name] as Array).append(label)


func _enemy_ability_label(ability: Dictionary) -> String:
	return "%s / %s / %s" % [
		str(ability.get("enemy_type", "Unknown Enemy")),
		str(ability.get("source_name", "zone")),
		str(ability.get("ability_name", "Unnamed Ability")),
	]


func _run_targeting_audits() -> void:
	var battle_scene: Control = BATTLE_SCENE_SCRIPT.new() as Control
	if battle_scene == null:
		_record_failure("Targeting", "battle_scene", "BattleScene script instantiates", "new() returned null")
		return

	var cases: Array[Dictionary] = [
		{"name": "single damage requires enemy", "raw": {"dmg": 5}, "manual": "enemy"},
		{"name": "single burn requires enemy", "raw": {"burn": 2, "burnT": 2}, "manual": "enemy"},
		{"name": "single roll debuff requires enemy", "raw": {"rfe": 2, "rfT": 1}, "manual": "enemy"},
		{"name": "rfeOnly debuff requires enemy", "raw": {"rfe": 2, "rfT": 1, "rfeOnly": true}, "manual": "enemy"},
		{"name": "blast all requires no manual target", "raw": {"dmg": 5, "blastAll": true}, "manual": ""},
		{"name": "heal all requires no manual target", "raw": {"heal": 5, "healAll": true}, "manual": ""},
		{"name": "shield all requires no manual target", "raw": {"shield": 5, "shieldAll": true}, "manual": ""},
		{"name": "mixed healAll plus single damage requires enemy", "raw": {"dmg": 6, "heal": 7, "healAll": true}, "manual": "enemy"},
		{"name": "mixed shieldAll plus single rfe requires enemy", "raw": {"rfe": 2, "rfT": 2, "shield": 8, "shieldAll": true}, "manual": "enemy"},
		{"name": "targeted heal requires hero", "raw": {"heal": 6, "healTgt": true}, "manual": "hero"},
		{"name": "targeted shield requires hero", "raw": {"shield": 6, "shTgt": true}, "manual": "hero"},
		{"name": "targeted ward requires hero", "raw": {"ward": true, "wardTgt": true}, "manual": "hero"},
		{"name": "self ward requires no manual target", "raw": {"ward": true}, "manual": ""},
		{"name": "lowest shield requires no manual target", "raw": {"shield": 7, "shieldLowest": true}, "manual": ""},
		{"name": "lowest heal requires no manual target", "raw": {"heal": 8, "healLowest": true}, "manual": ""},
		{"name": "revive requires dead hero", "raw": {"revive": true}, "manual": "dead_hero"},
		{"name": "revive all requires no manual target", "raw": {"reviveAll": true, "revivePct": 30}, "manual": ""},
		{"name": "revive with healTgt still requires dead hero", "raw": {"revive": true, "healTgt": true, "revivePct": 70}, "manual": "dead_hero"},
		{"name": "freeze any requires any", "raw": {"freezeAnyDice": 1}, "manual": "any"},
		# Single-target taunt (Build G ruling G-4): the cast picks ONE enemy.
		{"name": "taunt requires enemy", "raw": {"taunt": true}, "manual": "enemy"},
		{"name": "self shield plus taunt still requires enemy", "raw": {"shield": 7, "taunt": true}, "manual": "enemy"},
	]

	for case in cases:
		var actual: String = str(battle_scene.call("_get_manual_target_side", {"raw": case["raw"]}))
		_expect_and_record(
			"Targeting / %s" % str(case["name"]),
			"manual_side",
			str(case["manual"]),
			actual
		)

	var self_state: Dictionary = {"id": "self", "selected_target_id": "", "target_display": "--"}
	battle_scene.call("_auto_assign_hero_target", self_state, {"raw": {"shield": 5}})
	_expect_and_record("Targeting / self shield auto target", "auto_target", "self:Self", "%s:%s" % [str(self_state.get("selected_target_id", "")), str(self_state.get("target_display", ""))])

	var all_state: Dictionary = {"id": "hero", "selected_target_id": "", "target_display": "--"}
	battle_scene.call("_auto_assign_hero_target", all_state, {"raw": {"heal": 5, "healAll": true}})
	_expect_and_record("Targeting / healAll auto target", "auto_target", ":All Squad", "%s:%s" % [str(all_state.get("selected_target_id", "")), str(all_state.get("target_display", ""))])
	battle_scene.free()


func _run_regression_audits() -> void:
	_run_enemy_shield_ally_regression()
	_run_enemy_freeze_regression()
	_run_burn_timing_regression()
	_run_roll_modifier_timing_regressions()
	_run_shield_timing_regression()
	_run_cloak_regression()
	_run_taunt_regression()
	_run_cleanse_regressions()
	_run_ward_regressions()
	_run_shield_lowest_regression()
	_run_new_gear_regressions()
	_run_new_relic_regressions()
	_run_boss_standing_rule_regressions()
	_run_boss_fight_data_regressions()
	_run_save_manager_regressions()
	_run_starting_directive_regressions()
	_run_evolution_kit_regression()
	_run_directive_progression_regressions()
	_run_directive_combat_regressions()
	_run_battle_slot_regressions()
	_run_beat_regressions()
	_run_relic_cache_regression()
	_run_route_modifier_regressions()
	_run_intercept_regressions()
	_run_chain_regression()
	_run_detonate_regression()
	_run_execute_regression()
	_run_breach_regression()
	_run_leech_regression()
	_run_mark_regression()
	_run_spike_regression()
	_run_jam_regression()
	_run_rewrite_regression()
	_run_hijack_regression()
	_run_siphon_regression()
	_run_rampage_regression()
	_run_freeze_regression()
	_run_freeze_repeat_regressions()
	_run_instance_timer_regressions()
	_run_down_cleanup_regression()
	_run_summon_slot_regression()
	_run_summon_end_to_end_regression()
	_run_enemy_roll_buff_expiry_regression()
	_run_band_coverage_audit()
	_run_gear_lifesteal_regression()
	_run_gear_shield_pierce_regression()
	_run_relic_ally_death_heal_regression()
	_run_revive_pct_regression()
	_run_revive_all_regression()
	_run_gear_first_ability_echo_regression()
	_run_gear_heal_shield_bonus_regression()
	_run_gear_protocol_on_kill_regression()
	_run_gear_protocol_on_kill_any_regression()
	_run_relic_crit_resolve_twice_regression()
	_run_relic_rewards_no_common_regression()
	_run_relic_protocol_carryover_regression()
	_run_relic_battle_start_consumable_regression()
	_run_relic_revive_no_penalty_regression()
	_run_relic_low_hp_squad_roll_buff_regression()
	_run_relic_heal_grants_shield_all_regression()
	_run_relic_protocol_on_item_use_regression()
	_run_relic_battle_start_state_regression()
	_run_relic_per_turn_aura_regression()
	_run_tutorial_kill_math_regression()


func _run_enemy_shield_ally_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Noop", {})
	var actor_unit: EnemyData = _make_enemy("audit_enemy_actor", "Audit Enemy Actor", "Ally Shield Regression", {
		"shield": 5,
		"shieldAlly": 7,
	})
	var ally_unit: EnemyData = _make_enemy("audit_enemy_ally", "Audit Enemy Ally")
	manager.setup_battle([hero_unit], [actor_unit, ally_unit])

	var enemies: Array = manager.get_enemy_states()
	var actor: Dictionary = enemies[0]
	var ally: Dictionary = enemies[1]
	actor["selected_target_id"] = str(actor["id"])

	# Enemy shields are granted during the enemy phase (after heroes acted), so
	# they survive the imminent round-end tick to cover exactly one hero phase,
	# then expire at the following round's end tick.
	manager.resolve_round({}, {str(actor["id"]): AUDIT_ROLL}, DiceManager.new())
	var actor_shield_r1: int = int(actor.get("shield", 0))
	var ally_shield_r1: int = int(ally.get("shield", 0))
	manager.resolve_round({}, {}, DiceManager.new())
	var actor_shield_r2: int = int(actor.get("shield", 0))
	var ally_shield_r2: int = int(ally.get("shield", 0))
	var ok: bool = actor_shield_r1 == 5 and ally_shield_r1 == 7 and actor_shield_r2 == 0 and ally_shield_r2 == 0
	if ok:
		_record_pass("Regression / enemy shieldAlly", "shieldAlly")
	else:
		_record_failure(
			"Regression / enemy shieldAlly",
			"shieldAlly",
			"self 5 / ally 7 after granting round; both 0 after the next round",
			"r1 self=%d ally=%d, r2 self=%d ally=%d" % [actor_shield_r1, ally_shield_r1, actor_shield_r2, ally_shield_r2]
		)


func _run_enemy_freeze_regression() -> void:
	# Freeze = repeat (per Kev 2026-07-06): an enemy freeze crusts the hero's
	# die; on the hero's next roll the die keeps its face and the hero ACTS
	# AGAIN on that result, then the die thaws.
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Strike", {"dmg": 5})
	var enemy_unit: EnemyData = _make_enemy("audit_freeze_enemy", "Audit Freeze Enemy", "Freeze Regression", {
		"freezeEnemyDice": 1,
	})
	manager.setup_battle([hero_unit], [enemy_unit])

	var hero: Dictionary = manager.get_hero_states()[0]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	enemy["selected_target_id"] = str(hero["id"])
	hero["last_die_value"] = 12

	manager.resolve_round({}, {str(enemy["id"]): AUDIT_ROLL}, DiceManager.new())
	var frozen_after_apply: bool = int(hero.get("die_freeze_turns", 0)) == 1 and not bool(hero.get("die_freeze_repeat_this_round", false))

	# Next round: the crusted die keeps its face (repeat flag set at roll time
	# by battle_engine.record_roll_values_for_states; mimic that here) — the
	# hero ACTS on the repeated result, then the freeze clears.
	hero["selected_target_id"] = str(enemy["id"])
	hero["die_freeze_repeat_this_round"] = true
	var enemy_hp_before: int = int(enemy["current_hp"])
	manager.resolve_round({str(hero["id"]): 12}, {}, DiceManager.new())
	var hero_repeated: bool = int(enemy["current_hp"]) == enemy_hp_before - 5
	var freeze_cleared: bool = int(hero.get("die_freeze_turns", 0)) == 0 and not bool(hero.get("die_freeze_repeat_this_round", false))

	if frozen_after_apply and hero_repeated and freeze_cleared:
		_record_pass("Regression / enemy freeze makes hero repeat result", "freezeEnemyDice")
	else:
		_record_failure(
			"Regression / enemy freeze makes hero repeat result",
			"freezeEnemyDice",
			"hero frozen after enemy phase, acts again on the frozen face, freeze then clears",
			"frozen=%s repeated=%s cleared=%s turns=%d" % [str(frozen_after_apply), str(hero_repeated), str(freeze_cleared), int(hero.get("die_freeze_turns", 0))]
		)

	# Hero-side parity: a hero freeze crusts the enemy's die. The enemy still
	# lands its hit the round it is frozen (freeze applies during the hero
	# phase), then next round its die keeps the frozen face and the enemy acts
	# AGAIN on that result — same zone, same ability — and the freeze clears.
	var repeat_manager: CombatManager = CombatManager.new()
	var freezer_unit: UnitData = _make_unit("audit_freezer", "Audit Freezer", "Flash Freeze", {"freezeEnemyDice": 1})
	var striker_enemy: EnemyData = _make_enemy("audit_striker", "Audit Striker", "Claw", {"dmg": 9})
	repeat_manager.setup_battle([freezer_unit], [striker_enemy])
	var freezer: Dictionary = repeat_manager.get_hero_states()[0]
	var striker: Dictionary = repeat_manager.get_enemy_states()[0]
	freezer["selected_target_id"] = str(striker["id"])
	striker["selected_target_id"] = str(freezer["id"])
	striker["last_die_value"] = 15
	var hero_hp_before: int = int(freezer["current_hp"])
	# Round 1: freeze cast — the enemy still lands its hit and is left frozen
	# with its die face preserved.
	repeat_manager.resolve_round({str(freezer["id"]): AUDIT_ROLL}, {str(striker["id"]): 15}, DiceManager.new())
	var striker_acted_r1: bool = int(freezer["current_hp"]) == hero_hp_before - 9
	var striker_frozen_after: bool = int(striker.get("die_freeze_turns", 0)) == 1 and int(striker.get("frozen_die_value", 0)) == 15
	# Round 2: the crusted die repeats its 15 — the enemy hits AGAIN for the
	# same damage (fresh personality pick), then the freeze clears.
	striker["die_freeze_repeat_this_round"] = true
	var freezer_hp_after_r1: int = int(freezer["current_hp"])
	repeat_manager.resolve_round({}, {str(striker["id"]): 15}, DiceManager.new())
	var striker_repeated_r2: bool = int(freezer["current_hp"]) == freezer_hp_after_r1 - 9
	var striker_cleared: bool = int(striker.get("die_freeze_turns", 0)) == 0 and int(striker.get("frozen_die_value", 0)) == 0
	if striker_acted_r1 and striker_frozen_after and striker_repeated_r2 and striker_cleared:
		_record_pass("Regression / hero freeze makes enemy repeat result", "freezeEnemyDice")
	else:
		_record_failure(
			"Regression / hero freeze makes enemy repeat result",
			"freezeEnemyDice",
			"enemy hits R1, frozen at 15, hits again R2 on the repeat, then thaws",
			"acted=%s frozen=%s repeated=%s cleared=%s" % [str(striker_acted_r1), str(striker_frozen_after), str(striker_repeated_r2), str(striker_cleared)]
		)


func _run_burn_timing_regression() -> void:
	var context: Dictionary = _build_context({"burn": 3, "burnT": 2}, "Burn Timing Regression")
	var manager: CombatManager = context["manager"]
	var actor: Dictionary = context["actor"]
	var enemy: Dictionary = context["enemy_a"]
	actor["selected_target_id"] = str(enemy["id"])

	var before_hp: int = int(enemy["current_hp"])
	manager.resolve_round({str(actor["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var after_first_hp: int = int(enemy["current_hp"])
	var after_first_turns: int = int(enemy["burn_turns"])
	var after_first_burn: int = int(enemy["burn"])
	manager.resolve_round({}, {}, DiceManager.new())

	var ok: bool = (
		after_first_hp == before_hp
		and after_first_burn == 3
		and after_first_turns == 2
		and int(enemy["current_hp"]) == before_hp - 3
		and int(enemy["burn_turns"]) == 1
	)
	if ok:
		_record_pass("Regression / burn skip-next-tick", "burn")
	else:
		_record_failure(
			"Regression / burn skip-next-tick",
			"burn",
			"first round no tick, second round ticks once",
			"hp before=%d after_first=%d after_second=%d burn=%d turns_after_first=%d turns_after_second=%d" % [before_hp, after_first_hp, int(enemy["current_hp"]), after_first_burn, after_first_turns, int(enemy["burn_turns"])]
		)


func _run_roll_modifier_timing_regressions() -> void:
	var debuff_context: Dictionary = _build_context({"rfe": 2, "rfT": 1}, "RFE Timing Regression")
	var debuff_manager: CombatManager = debuff_context["manager"]
	var debuff_actor: Dictionary = debuff_context["actor"]
	var debuff_enemy: Dictionary = debuff_context["enemy_a"]
	debuff_actor["selected_target_id"] = str(debuff_enemy["id"])
	debuff_manager.resolve_round({str(debuff_actor["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var debuffed_roll: int = debuff_manager.get_effective_roll(debuff_enemy, 10)
	debuff_manager.resolve_round({}, {}, DiceManager.new())
	var cleared_debuff_roll: int = debuff_manager.get_effective_roll(debuff_enemy, 10)
	_expect_and_record("Regression / RFE timing", "rfe", "8 then 10", "%d then %d" % [debuffed_roll, cleared_debuff_roll])

	# Duration convention (Kev 2026-07-13): a future-shaping buff stores EFFECTIVE
	# turns and skips its cast-round tick, so `rfmT:1` covers exactly the next roll
	# (behavior-identical to the old off-by-one `rfmT:2`, which is why this reads
	# 13 then 10 unchanged after the encoding fix).
	var buff_context: Dictionary = _build_context({"rfm": 3, "rfmT": 1}, "Roll Buff Timing Regression")
	var buff_manager: CombatManager = buff_context["manager"]
	var buff_actor: Dictionary = buff_context["actor"]
	buff_manager.resolve_round({str(buff_actor["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var buffed_roll: int = buff_manager.get_effective_roll(buff_actor, 10)
	buff_manager.resolve_round({}, {}, DiceManager.new())
	var cleared_buff_roll: int = buff_manager.get_effective_roll(buff_actor, 10)
	_expect_and_record("Regression / roll buff timing", "rfm", "13 then 10", "%d then %d" % [buffed_roll, cleared_buff_roll])


func _run_shield_timing_regression() -> void:
	# Hero shields last one round: granted in the hero phase, they absorb the
	# same round's enemy phase and are gone after that round's end tick.
	var context: Dictionary = _build_context({"shield": 5}, "Shield Timing Regression")
	var manager: CombatManager = context["manager"]
	var actor: Dictionary = context["actor"]
	var result: Dictionary = manager.resolve_round({str(actor["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var events: Array = result.get("events", [])
	var granted: bool = _has_event(events, "shield", 5, "hero")
	var shield_after_round: int = int(actor.get("shield", 0))
	var ok: bool = granted and shield_after_round == 0
	if ok:
		_record_pass("Regression / shield one-round expiry", "shield")
	else:
		_record_failure(
			"Regression / shield one-round expiry",
			"shield",
			"shield granted during the round, expired at the same round's end tick",
			"granted=%s shield_after_round=%d" % [str(granted), shield_after_round]
		)

	# shields_persist (Mantle Core / MANTLE TYRANT): shields survive round-end
	# ticks and are only consumed by damage.
	var persist_context: Dictionary = _build_context({"shield": 5}, "Shield Persist Regression")
	var persist_manager: CombatManager = persist_context["manager"]
	var persist_actor: Dictionary = persist_context["actor"]
	persist_actor["shields_persist"] = true
	persist_manager.resolve_round({str(persist_actor["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	persist_manager.resolve_round({}, {}, DiceManager.new())
	var persist_shield: int = int(persist_actor.get("shield", 0))
	if persist_shield == 5:
		_record_pass("Regression / shields_persist survives ticks", "shield")
	else:
		_record_failure(
			"Regression / shields_persist survives ticks",
			"shield",
			"persistent shield still 5 after two round-end ticks",
			"shield=%d" % persist_shield
		)


# Build G ruling G-4: hero taunt marks ONE enemy — only the taunted enemy
# redirects to the taunter (through every enemy targeting path); other enemies
# keep their own personalities; a firewall blocks (and is consumed by) the
# taunt; the mark clears at the round-end tick (NK-08).
func _run_taunt_regression() -> void:
	# Redirect is per-enemy: two SYSTEMATIC enemies would both hit slot 0 —
	# the taunted one crosses to the slot-1 taunter, the free one does not.
	var manager: CombatManager = CombatManager.new()
	var ally_unit: UnitData = _make_unit("audit_ally", "Audit Ally", "Noop", {})
	var taunter_unit: UnitData = _make_unit("audit_taunter", "Audit Taunter", "Taunt Protocol", {"taunt": true})
	manager.setup_battle(
		[ally_unit, taunter_unit],
		[_make_enemy("audit_taunted", "Audit Taunted", "Fang", {"dmg": 7}), _make_enemy("audit_free", "Audit Free", "Claw", {"dmg": 5})]
	)
	var ally: Dictionary = manager.get_hero_states()[0]
	var taunter: Dictionary = manager.get_hero_states()[1]
	var taunted: Dictionary = manager.get_enemy_states()[0]
	var free_enemy: Dictionary = manager.get_enemy_states()[1]
	taunter["selected_target_id"] = str(taunted["id"])
	manager.resolve_round(
		{str(ally["id"]): AUDIT_ROLL, str(taunter["id"]): AUDIT_ROLL},
		{str(taunted["id"]): AUDIT_ROLL, str(free_enemy["id"]): AUDIT_ROLL},
		DiceManager.new()
	)
	var single_redirect: bool = (
		int(taunter["current_hp"]) == 100 - 7
		and int(ally["current_hp"]) == 100 - 5
	)
	if single_redirect:
		_record_pass("Regression / taunt redirects ONLY the taunted enemy", "taunt")
	else:
		_record_failure("Regression / taunt redirects ONLY the taunted enemy", "taunt", "taunter takes 7 (taunted enemy), ally takes 5 (free enemy)", "taunter_hp=%d ally_hp=%d" % [int(taunter["current_hp"]), int(ally["current_hp"])])
	if str(taunted.get("lured_by_id", "")) == "" and not bool(taunter.get("taunting", false)):
		_record_pass("Regression / taunt clears at round end (NK-08)", "taunt")
	else:
		_record_failure("Regression / taunt clears at round end (NK-08)", "taunt", "lured_by_id empty + taunting false after the tick", "lured=%s taunting=%s" % [str(taunted.get("lured_by_id", "")), str(taunter.get("taunting", false))])

	# A firewalled enemy blocks the taunt (and the block consumes the wall):
	# no lure lands, the enemy keeps its own pick (slot-0 ally under SYSTEMATIC).
	var ward_manager: CombatManager = CombatManager.new()
	ward_manager.setup_battle(
		[_make_unit("audit_ally", "Audit Ally", "Noop", {}), _make_unit("audit_taunter", "Audit Taunter", "Taunt Protocol", {"taunt": true})],
		[_make_enemy("audit_warded", "Audit Warded", "Fang", {"dmg": 7})]
	)
	var ward_ally: Dictionary = ward_manager.get_hero_states()[0]
	var ward_taunter: Dictionary = ward_manager.get_hero_states()[1]
	var warded_enemy: Dictionary = ward_manager.get_enemy_states()[0]
	warded_enemy["warded"] = true
	ward_taunter["selected_target_id"] = str(warded_enemy["id"])
	ward_manager.resolve_round(
		{str(ward_ally["id"]): AUDIT_ROLL, str(ward_taunter["id"]): AUDIT_ROLL},
		{str(warded_enemy["id"]): AUDIT_ROLL},
		DiceManager.new()
	)
	var ward_blocked: bool = (
		not bool(warded_enemy.get("warded", false))
		and int(ward_ally["current_hp"]) == 100 - 7
		and int(ward_taunter["current_hp"]) == 100
	)
	if ward_blocked:
		_record_pass("Regression / firewall blocks the taunt and breaks", "taunt")
	else:
		_record_failure("Regression / firewall blocks the taunt and breaks", "taunt", "ward consumed, enemy keeps its own pick (ally takes 7)", "warded=%s ally_hp=%d taunter_hp=%d" % [str(warded_enemy.get("warded", false)), int(ward_ally["current_hp"]), int(ward_taunter["current_hp"])])

	# Choke-point law: only the LURED enemy's pick crosses to the taunter, and
	# taunt beats cloak (doctrine) — asserted at personality_pick_target itself.
	var pick_heroes: Array = [
		{"id": "slot0", "dead": false, "cloaked": false, "current_hp": 50, "max_hp": 50},
		{"id": "slot1", "dead": false, "cloaked": true, "current_hp": 50, "max_hp": 50},
	]
	var lured_pick: Dictionary = TargetingPersonality.personality_pick_target({"lured_by_id": "slot1"}, pick_heroes, {})
	var free_pick: Dictionary = TargetingPersonality.personality_pick_target({"lured_by_id": ""}, pick_heroes, {})
	if str(lured_pick.get("id", "")) == "slot1" and str(free_pick.get("id", "")) == "slot0":
		_record_pass("Regression / lure is per-enemy at the choke-point, beats cloak", "taunt")
	else:
		_record_failure("Regression / lure is per-enemy at the choke-point, beats cloak", "taunt", "lured -> its cloaked taunter; unlured -> personality pick", "lured=%s free=%s" % [str(lured_pick.get("id", "")), str(free_pick.get("id", ""))])


func _run_cloak_regression() -> void:
	# Cloak = untargetable by single-target abilities: the attack retargets to
	# a visible unit; the cloaked one is untouched and stays cloaked.
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Rail Strike", {"dmg": 8})
	var cloaked_enemy: EnemyData = _make_enemy("audit_cloaked", "Audit Cloaked")
	var visible_enemy: EnemyData = _make_enemy("audit_visible", "Audit Visible")
	manager.setup_battle([hero_unit], [cloaked_enemy, visible_enemy])
	var hero: Dictionary = manager.get_hero_states()[0]
	var cloaked: Dictionary = manager.get_enemy_states()[0]
	var visible: Dictionary = manager.get_enemy_states()[1]
	cloaked["cloaked"] = true
	hero["selected_target_id"] = str(cloaked["id"])
	var cloaked_before: int = int(cloaked["current_hp"])
	var visible_before: int = int(visible["current_hp"])
	manager.resolve_round({str(hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var retargeted: bool = (
		int(cloaked["current_hp"]) == cloaked_before
		and int(visible["current_hp"]) == visible_before - 8
		and bool(cloaked.get("cloaked", false))
	)
	if retargeted:
		_record_pass("Regression / cloak untargetable, attack retargets", "cloak")
	else:
		_record_failure("Regression / cloak untargetable, attack retargets", "cloak", "cloaked untouched + still cloaked; visible takes 8", "cloaked_delta=%d visible_delta=%d cloaked=%s" % [cloaked_before - int(cloaked["current_hp"]), visible_before - int(visible["current_hp"]), str(cloaked.get("cloaked", false))])

	# An AoE that includes the cloaked unit hits it and breaks the cloak.
	var aoe_manager: CombatManager = CombatManager.new()
	aoe_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Ghost Volley", {"dmg": 6, "blastAll": true})], [_make_enemy("audit_cloaked", "Audit Cloaked")])
	var aoe_hero: Dictionary = aoe_manager.get_hero_states()[0]
	var aoe_enemy: Dictionary = aoe_manager.get_enemy_states()[0]
	aoe_enemy["cloaked"] = true
	var aoe_before: int = int(aoe_enemy["current_hp"])
	aoe_manager.resolve_round({str(aoe_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	if int(aoe_enemy["current_hp"]) == aoe_before - 6 and not bool(aoe_enemy.get("cloaked", false)):
		_record_pass("Regression / AoE breaks cloak and hits", "cloak")
	else:
		_record_failure("Regression / AoE breaks cloak and hits", "cloak", "cloak broken and 6 damage taken", "delta=%d cloaked=%s" % [aoe_before - int(aoe_enemy["current_hp"]), str(aoe_enemy.get("cloaked", false))])

	# Dealing damage breaks the cloak, but the attack no longer pierces —
	# the target's shield absorbs it like any other hit.
	var strike_manager: CombatManager = CombatManager.new()
	strike_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Phase Blade", {"dmg": 9})], [_make_enemy("audit_enemy", "Audit Enemy")])
	var strike_hero: Dictionary = strike_manager.get_hero_states()[0]
	var strike_enemy: Dictionary = strike_manager.get_enemy_states()[0]
	strike_hero["cloaked"] = true
	strike_hero["selected_target_id"] = str(strike_enemy["id"])
	strike_enemy["shield_stacks"] = [{"amt": 20, "skip_next_tick": true}]
	strike_enemy["shield"] = 20
	var strike_before: int = int(strike_enemy["current_hp"])
	strike_manager.resolve_round({str(strike_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var absorbed: bool = int(strike_enemy["current_hp"]) == strike_before and int(strike_enemy["shield"]) == 11
	var decloaked: bool = not bool(strike_hero.get("cloaked", false))
	if absorbed and decloaked:
		_record_pass("Regression / attack from cloak decloaks without pierce", "cloak")
	else:
		_record_failure("Regression / attack from cloak decloaks without pierce", "cloak", "shield absorbs 9 (20 -> 11), no HP damage; attacker decloaked", "hp_delta=%d shield=%d cloaked=%s" % [strike_before - int(strike_enemy["current_hp"]), int(strike_enemy["shield"]), str(strike_hero.get("cloaked", false))])


# Cleanse (Build I): purges the target's unit-level negatives (burn, negative
# roll stacks, jam, lure), KEEPS positive roll buffs, leaves die states (a
# frozen die stays frozen). A cast with nothing to remove is a legal no-op.
func _run_cleanse_regressions() -> void:
	var manager: CombatManager = CombatManager.new()
	manager.setup_battle(
		[_make_unit("audit_medic", "Audit Medic", "Audit Infusion", {"heal": 10, "healTgt": true, "cleanse": true}),
		 _make_unit("audit_ally", "Audit Ally", "Noop", {})],
		[_make_enemy("audit_enemy", "Audit Enemy")])
	var medic: Dictionary = manager.get_hero_states()[0]
	var ally: Dictionary = manager.get_hero_states()[1]
	ally["burn_stacks"] = [{"amt": 3, "turns_left": 2}]
	ally["roll_buff_stacks"] = [{"amt": -2, "turns_left": 2}, {"amt": 2, "turns_left": 2}]
	ally["jam_cap"] = 6
	ally["lured_by_id"] = "audit_enemy#1"
	ally["die_freeze_turns"] = 1
	medic["selected_target_id"] = str(ally["id"])
	manager.resolve_round({str(medic["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var purged: bool = (
		(ally["burn_stacks"] as Array).is_empty()
		and (ally["roll_buff_stacks"] as Array).size() == 1
		and int((ally["roll_buff_stacks"] as Array)[0]["amt"]) == 2
		and int(ally.get("jam_cap", 0)) == 0
		and str(ally.get("lured_by_id", "")) == ""
		and int(ally.get("die_freeze_turns", 0)) == 1
	)
	_expect_and_record("Regression / cleanse purges negatives keeps buffs and dice", "cleanse", "true", str(purged))
	# No-op legality: cleansing a clean target changes nothing and cannot crash.
	# (Buff stacks cleared first — natural expiry between rounds would otherwise
	# masquerade as a cleanse effect.)
	ally["roll_buff_stacks"] = []
	manager.resolve_round({str(medic["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var noop_ok: bool = (ally["burn_stacks"] as Array).is_empty() \
		and int(ally.get("jam_cap", 0)) == 0 and str(ally.get("lured_by_id", "")) == ""
	_expect_and_record("Regression / cleanse no-op is legal", "cleanse", "true", str(noop_ok))


func _run_ward_regressions() -> void:
	# Ward blocks the next single-target hit entirely, then breaks; the follow-up
	# hit lands normally.
	var targeted_context: Dictionary = _build_context({"dmg": 9}, "Ward Targeted Regression")
	var targeted_manager: CombatManager = targeted_context["manager"]
	var targeted_actor: Dictionary = targeted_context["actor"]
	var targeted_enemy: Dictionary = targeted_context["enemy_a"]
	targeted_actor["selected_target_id"] = str(targeted_enemy["id"])
	targeted_enemy["warded"] = true
	var enemy_hp_before: int = int(targeted_enemy["current_hp"])
	targeted_manager.resolve_round({str(targeted_actor["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var blocked: bool = int(targeted_enemy["current_hp"]) == enemy_hp_before
	var ward_broken: bool = not bool(targeted_enemy.get("warded", false))
	targeted_actor["selected_target_id"] = str(targeted_enemy["id"])
	targeted_manager.resolve_round({str(targeted_actor["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var second_landed: bool = int(targeted_enemy["current_hp"]) == enemy_hp_before - 9
	if blocked and ward_broken and second_landed:
		_record_pass("Regression / ward blocks one targeted hit", "ward")
	else:
		_record_failure("Regression / ward blocks one targeted hit", "ward", "first hit blocked, ward gone, second hit lands", "blocked=%s broken=%s second=%s hp=%d" % [str(blocked), str(ward_broken), str(second_landed), int(targeted_enemy["current_hp"])])

	# An AoE that includes a warded unit is blocked for that unit only.
	var blast_context: Dictionary = _build_context({"dmg": 9, "blastAll": true}, "Ward Blast Regression")
	var blast_manager: CombatManager = blast_context["manager"]
	var blast_actor: Dictionary = blast_context["actor"]
	var blast_enemy_a: Dictionary = blast_context["enemy_a"]
	var blast_enemy_b: Dictionary = blast_context["enemy_b"]
	blast_enemy_a["warded"] = true
	var blast_actor_hp_before: int = int(blast_actor["current_hp"])
	var blast_enemy_a_hp_before: int = int(blast_enemy_a["current_hp"])
	var blast_enemy_b_hp_before: int = int(blast_enemy_b["current_hp"])
	blast_manager.resolve_round({str(blast_actor["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var blast_ok: bool = (
		int(blast_actor["current_hp"]) == blast_actor_hp_before
		and int(blast_enemy_a["current_hp"]) == blast_enemy_a_hp_before
		and int(blast_enemy_b["current_hp"]) == blast_enemy_b_hp_before - 9
		and not bool(blast_enemy_a.get("warded", false))
	)
	if blast_ok:
		_record_pass("Regression / ward blocks AoE for that unit only", "ward")
	else:
		_record_failure("Regression / ward blocks AoE for that unit only", "ward", "warded unit takes 0 from AoE (ward breaks); other unit takes full damage", "enemy_a_delta=%d enemy_b_delta=%d warded=%s" % [blast_enemy_a_hp_before - int(blast_enemy_a["current_hp"]), blast_enemy_b_hp_before - int(blast_enemy_b["current_hp"]), str(blast_enemy_a.get("warded", false))])


func _run_chain_regression() -> void:
	# Chain: primary takes full damage; the lowest-HP OTHER enemy takes 50%
	# (round down); chain 2 jumps to the next lowest-HP unhit enemy.
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Arc Whip", {"dmg": 10, "chain": 1})
	var enemy_a: EnemyData = _make_enemy("audit_enemy_a", "Audit Enemy A")
	var enemy_b: EnemyData = _make_enemy("audit_enemy_b", "Audit Enemy B")
	var enemy_c: EnemyData = _make_enemy("audit_enemy_c", "Audit Enemy C")
	manager.setup_battle([hero_unit], [enemy_a, enemy_b, enemy_c])
	var states: Array = manager.get_enemy_states()
	var a: Dictionary = states[0]
	var b: Dictionary = states[1]
	var c: Dictionary = states[2]
	var hero: Dictionary = manager.get_hero_states()[0]
	hero["selected_target_id"] = str(a["id"])
	b["current_hp"] = 60
	c["current_hp"] = 90
	var a_before: int = int(a["current_hp"])
	manager.resolve_round({str(hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var single_ok: bool = int(a["current_hp"]) == a_before - 10 and int(b["current_hp"]) == 55 and int(c["current_hp"]) == 90
	if single_ok:
		_record_pass("Regression / chain jumps to lowest other enemy at 50%", "chain")
	else:
		_record_failure("Regression / chain jumps to lowest other enemy at 50%", "chain", "primary -10, lowest other -5, third untouched", "a=%d b=%d c=%d" % [int(a["current_hp"]), int(b["current_hp"]), int(c["current_hp"])])

	var double_manager: CombatManager = CombatManager.new()
	var double_hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Cascade", {"dmg": 10, "chain": 2})
	double_manager.setup_battle([double_hero_unit], [_make_enemy("audit_enemy_a", "Audit Enemy A"), _make_enemy("audit_enemy_b", "Audit Enemy B"), _make_enemy("audit_enemy_c", "Audit Enemy C")])
	var d_states: Array = double_manager.get_enemy_states()
	var da: Dictionary = d_states[0]
	var db: Dictionary = d_states[1]
	var dc: Dictionary = d_states[2]
	var double_hero: Dictionary = double_manager.get_hero_states()[0]
	double_hero["selected_target_id"] = str(da["id"])
	db["current_hp"] = 60
	dc["current_hp"] = 90
	var da_before: int = int(da["current_hp"])
	double_manager.resolve_round({str(double_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var double_ok: bool = int(da["current_hp"]) == da_before - 10 and int(db["current_hp"]) == 55 and int(dc["current_hp"]) == 85
	if double_ok:
		_record_pass("Regression / chain x2 adds a second jump", "chain")
	else:
		_record_failure("Regression / chain x2 adds a second jump", "chain", "primary -10, two other enemies -5 each", "a=%d b=%d c=%d" % [int(da["current_hp"]), int(db["current_hp"]), int(dc["current_hp"])])


func _run_detonate_regression() -> void:
	# Detonate consumes the target's Burn for burn x remaining-turns damage.
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Backdraft", {"dmg": 5, "detonate": true})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy")
	manager.setup_battle([hero_unit], [enemy_unit])
	var hero: Dictionary = manager.get_hero_states()[0]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	hero["selected_target_id"] = str(enemy["id"])
	manager.apply_item_burn(enemy, 3, 2)
	var before_hp: int = int(enemy["current_hp"])
	manager.resolve_round({str(hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	# 5 base + (3 burn x 2 turns) = 11; the finite burn is consumed so no tick fires
	var ok: bool = int(enemy["current_hp"]) == before_hp - 11 and int(enemy["burn"]) == 0 and int(enemy["burn_turns"]) == 0
	if ok:
		_record_pass("Regression / detonate consumes finite burn for burst", "detonate")
	else:
		_record_failure("Regression / detonate consumes finite burn for burst", "detonate", "5 dmg + 6 burst, burn cleared", "hp_delta=%d burn=%d turns=%d" % [before_hp - int(enemy["current_hp"]), int(enemy["burn"]), int(enemy["burn_turns"])])

	# No Burn on the target: detonate fizzles, base damage still lands.
	var fizzle_manager: CombatManager = CombatManager.new()
	fizzle_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Backdraft", {"dmg": 5, "detonate": true})], [_make_enemy("audit_enemy", "Audit Enemy")])
	var f_hero: Dictionary = fizzle_manager.get_hero_states()[0]
	var f_enemy: Dictionary = fizzle_manager.get_enemy_states()[0]
	f_hero["selected_target_id"] = str(f_enemy["id"])
	var f_before: int = int(f_enemy["current_hp"])
	fizzle_manager.resolve_round({str(f_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	if int(f_enemy["current_hp"]) == f_before - 5:
		_record_pass("Regression / detonate fizzles without burn", "detonate")
	else:
		_record_failure("Regression / detonate fizzles without burn", "detonate", "only base 5 damage", "hp_delta=%d" % (f_before - int(f_enemy["current_hp"])))

	# Permanent-burn Detonate (per Kev 2026-07-06, resolves old DECISION #4):
	# a permanent burn (plagueProtocol) adds exactly ONE tick's damage (its
	# amount) and is NOT consumed — it keeps ticking afterwards.
	var perm_manager: CombatManager = CombatManager.new()
	perm_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Backdraft", {"dmg": 5, "detonate": true})], [_make_enemy("audit_perm", "Audit Perm", "Noop", {})])
	var p_hero: Dictionary = perm_manager.get_hero_states()[0]
	var p_enemy: Dictionary = perm_manager.get_enemy_states()[0]
	p_enemy["max_hp"] = 100000
	p_enemy["current_hp"] = 100000
	p_hero["selected_target_id"] = str(p_enemy["id"])
	perm_manager.apply_item_burn(p_enemy, 3, CombatManager.PERMANENT_BURN_TURNS)
	var p_before: int = int(p_enemy["current_hp"])
	perm_manager.resolve_round({str(p_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	# 5 base + one tick (3) = 8; the permanent burn survives (still 3).
	var perm_ok: bool = int(p_enemy["current_hp"]) == p_before - 8 and int(p_enemy["burn"]) == 3
	if perm_ok:
		_record_pass("Regression / permanent-burn detonate = one tick, not consumed", "detonate")
	else:
		_record_failure("Regression / permanent-burn detonate = one tick, not consumed", "detonate", "5 base + 3 (one tick), burn stays 3", "hp_delta=%d burn=%d" % [p_before - int(p_enemy["current_hp"]), int(p_enemy["burn"])])

	# Mixed stacks: finite 4x2t + permanent 3 → burst = 8 + 3 = 11; only the
	# finite stack is consumed, the permanent one keeps ticking.
	var mix_manager: CombatManager = CombatManager.new()
	mix_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Backdraft", {"dmg": 5, "detonate": true})], [_make_enemy("audit_mix", "Audit Mix", "Noop", {})])
	var m_hero: Dictionary = mix_manager.get_hero_states()[0]
	var m_enemy: Dictionary = mix_manager.get_enemy_states()[0]
	m_enemy["max_hp"] = 100000
	m_enemy["current_hp"] = 100000
	m_hero["selected_target_id"] = str(m_enemy["id"])
	mix_manager.apply_item_burn(m_enemy, 4, 2)
	mix_manager.apply_item_burn(m_enemy, 3, CombatManager.PERMANENT_BURN_TURNS)
	var m_before: int = int(m_enemy["current_hp"])
	mix_manager.resolve_round({str(m_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var mix_ok: bool = int(m_enemy["current_hp"]) == m_before - 16 and int(m_enemy["burn"]) == 3
	if mix_ok:
		_record_pass("Regression / detonate mixed finite+permanent stacks", "detonate")
	else:
		_record_failure("Regression / detonate mixed finite+permanent stacks", "detonate", "5 base + 8 finite + 3 perm tick = 16, perm burn stays 3", "hp_delta=%d burn=%d" % [m_before - int(m_enemy["current_hp"]), int(m_enemy["burn"])])


func _run_execute_regression() -> void:
	# Execute: +8 bonus only when the target is below 25% max HP after base damage.
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Terminal Velocity", {"dmg": 10, "execute": true})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy")
	manager.setup_battle([hero_unit], [enemy_unit])
	var hero: Dictionary = manager.get_hero_states()[0]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	hero["selected_target_id"] = str(enemy["id"])
	enemy["max_hp"] = 100
	enemy["current_hp"] = 30  # 30 - 10 = 20 < 25% of 100 -> execute fires
	manager.resolve_round({str(hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	if int(enemy["current_hp"]) == 12:
		_record_pass("Regression / execute bonus below threshold", "execute")
	else:
		_record_failure("Regression / execute bonus below threshold", "execute", "30 - 10 base - 8 bonus = 12", "hp=%d" % int(enemy["current_hp"]))

	var high_manager: CombatManager = CombatManager.new()
	high_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Terminal Velocity", {"dmg": 10, "execute": true})], [_make_enemy("audit_enemy", "Audit Enemy")])
	var h_hero: Dictionary = high_manager.get_hero_states()[0]
	var h_enemy: Dictionary = high_manager.get_enemy_states()[0]
	h_hero["selected_target_id"] = str(h_enemy["id"])
	h_enemy["max_hp"] = 100
	h_enemy["current_hp"] = 80  # 80 - 10 = 70, above 25% -> no bonus
	high_manager.resolve_round({str(h_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	if int(h_enemy["current_hp"]) == 70:
		_record_pass("Regression / execute inert above threshold", "execute")
	else:
		_record_failure("Regression / execute inert above threshold", "execute", "80 - 10 = 70, no bonus", "hp=%d" % int(h_enemy["current_hp"]))


func _run_breach_regression() -> void:
	# Breach destroys the target's shields before the hit, so full damage lands.
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Breach Slam", {"dmg": 9, "breach": true})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy")
	manager.setup_battle([hero_unit], [enemy_unit])
	var hero: Dictionary = manager.get_hero_states()[0]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	hero["selected_target_id"] = str(enemy["id"])
	enemy["shield_stacks"] = [{"amt": 15, "skip_next_tick": true}]
	enemy["shield"] = 15
	var before_hp: int = int(enemy["current_hp"])
	manager.resolve_round({str(hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var ok: bool = int(enemy["current_hp"]) == before_hp - 9 and int(enemy["shield"]) == 0
	if ok:
		_record_pass("Regression / breach strips shields before damage", "breach")
	else:
		_record_failure("Regression / breach strips shields before damage", "breach", "15 shield destroyed, full 9 damage to HP", "hp_delta=%d shield=%d" % [before_hp - int(enemy["current_hp"]), int(enemy["shield"])])

	# breach all strips every enemy before an AoE hit.
	var all_manager: CombatManager = CombatManager.new()
	all_manager.setup_battle(
		[_make_unit("audit_hero", "Audit Hero", "Total Suppression", {"dmg": 11, "blastAll": true, "breachAll": true})],
		[_make_enemy("audit_enemy_a", "Audit Enemy A"), _make_enemy("audit_enemy_b", "Audit Enemy B")]
	)
	var a_hero: Dictionary = all_manager.get_hero_states()[0]
	var ea: Dictionary = all_manager.get_enemy_states()[0]
	var eb: Dictionary = all_manager.get_enemy_states()[1]
	for es in [ea, eb]:
		es["shield_stacks"] = [{"amt": 10, "skip_next_tick": true}]
		es["shield"] = 10
	var ea_before: int = int(ea["current_hp"])
	var eb_before: int = int(eb["current_hp"])
	all_manager.resolve_round({str(a_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var all_ok: bool = (
		int(ea["current_hp"]) == ea_before - 11 and int(eb["current_hp"]) == eb_before - 11
		and int(ea["shield"]) == 0 and int(eb["shield"]) == 0
	)
	if all_ok:
		_record_pass("Regression / breach all strips every enemy", "breachAll")
	else:
		_record_failure("Regression / breach all strips every enemy", "breachAll", "both shields destroyed, full 11 damage each", "a_delta=%d b_delta=%d a_sh=%d b_sh=%d" % [ea_before - int(ea["current_hp"]), eb_before - int(eb["current_hp"]), int(ea["shield"]), int(eb["shield"])])


func _run_leech_regression() -> void:
	# Leech heals the attacker for 50% of HP damage dealt (after shields).
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Rend", {"dmg": 10, "leech": true})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy")
	manager.setup_battle([hero_unit], [enemy_unit])
	var hero: Dictionary = manager.get_hero_states()[0]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	hero["selected_target_id"] = str(enemy["id"])
	hero["current_hp"] = 30
	manager.resolve_round({str(hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	if int(hero["current_hp"]) == 35:
		_record_pass("Regression / leech heals 50% of HP damage", "leech")
	else:
		_record_failure("Regression / leech heals 50% of HP damage", "leech", "30 + floor(10*0.5) = 35", "hero_hp=%d" % int(hero["current_hp"]))

	# Shields eat the hit -> nothing to leech.
	var shielded_manager: CombatManager = CombatManager.new()
	shielded_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Rend", {"dmg": 10, "leech": true})], [_make_enemy("audit_enemy", "Audit Enemy")])
	var s_hero: Dictionary = shielded_manager.get_hero_states()[0]
	var s_enemy: Dictionary = shielded_manager.get_enemy_states()[0]
	s_hero["selected_target_id"] = str(s_enemy["id"])
	s_hero["current_hp"] = 30
	s_enemy["shield_stacks"] = [{"amt": 20, "skip_next_tick": true}]
	s_enemy["shield"] = 20
	shielded_manager.resolve_round({str(s_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	if int(s_hero["current_hp"]) == 30:
		_record_pass("Regression / leech gets nothing through shields", "leech")
	else:
		_record_failure("Regression / leech gets nothing through shields", "leech", "fully absorbed hit heals 0", "hero_hp=%d" % int(s_hero["current_hp"]))


func _run_mark_regression() -> void:
	# Mark: applied after the marking hit; the NEXT hit deals +50% (round up)
	# and consumes it; the hit after that is normal again.
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Target Lock", {"dmg": 3, "mark": true})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy")
	manager.setup_battle([hero_unit], [enemy_unit])
	var hero: Dictionary = manager.get_hero_states()[0]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	hero["selected_target_id"] = str(enemy["id"])
	var before: int = int(enemy["current_hp"])
	manager.resolve_round({str(hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var after_first: int = int(enemy["current_hp"])
	var marked_after_first: bool = bool(enemy.get("marked", false))
	hero["selected_target_id"] = str(enemy["id"])
	manager.resolve_round({str(hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var after_second: int = int(enemy["current_hp"])
	var marked_after_second: bool = bool(enemy.get("marked", false))
	# hit 1: 3 dmg (mark applies after) -> hit 2: ceil(3*1.5)=5 consumed, mark re-applied
	var ok: bool = (
		after_first == before - 3
		and marked_after_first
		and after_second == after_first - 5
		and marked_after_second
	)
	if ok:
		_record_pass("Regression / mark boosts next hit +50% then re-applies", "mark")
	else:
		_record_failure("Regression / mark boosts next hit +50% then re-applies", "mark", "3 then 5 damage; mark active after each marking hit", "d1=%d d2=%d m1=%s m2=%s" % [before - after_first, after_first - after_second, str(marked_after_first), str(marked_after_second)])


func _run_spike_regression() -> void:
	# Spike: an enemy that damages the spiked hero takes N back this round;
	# spike is gone by the following round.
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Counter Stance", {"spike": 6})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy", "Claw", {"dmg": 5})
	manager.setup_battle([hero_unit], [enemy_unit])
	var hero: Dictionary = manager.get_hero_states()[0]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	enemy["selected_target_id"] = str(hero["id"])
	var enemy_before: int = int(enemy["current_hp"])
	manager.resolve_round({str(hero["id"]): AUDIT_ROLL}, {str(enemy["id"]): AUDIT_ROLL}, DiceManager.new())
	var spiked: bool = int(enemy["current_hp"]) == enemy_before - 6
	var cleared: bool = int(hero.get("spike", 0)) == 0
	if spiked and cleared:
		_record_pass("Regression / spike retaliates then expires", "spike")
	else:
		_record_failure("Regression / spike retaliates then expires", "spike", "attacker takes 6; spike 0 after round end", "enemy_delta=%d spike=%d" % [enemy_before - int(enemy["current_hp"]), int(hero.get("spike", 0))])


func _run_jam_regression() -> void:
	# Jam caps the target's NEXT roll at 10, then clears at that round's tick.
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "EMP Pulse", {"dmg": 7, "jam": true})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy")
	manager.setup_battle([hero_unit], [enemy_unit])
	var hero: Dictionary = manager.get_hero_states()[0]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	hero["selected_target_id"] = str(enemy["id"])
	manager.resolve_round({str(hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var capped_roll: int = manager.get_effective_roll(enemy, 18)
	var jam_active: bool = int(enemy.get("jam_cap", 0)) == 10
	manager.resolve_round({}, {}, DiceManager.new())
	var cleared_roll: int = manager.get_effective_roll(enemy, 18)
	if jam_active and capped_roll == 10 and cleared_roll == 18:
		_record_pass("Regression / jam caps next roll then clears", "jam")
	else:
		_record_failure("Regression / jam caps next roll then clears", "jam", "18 capped to 10 for one round, 18 after", "cap=%d capped=%d cleared=%d" % [int(enemy.get("jam_cap", 0)), capped_roll, cleared_roll])


func _run_rewrite_regression() -> void:
	# Rewrite forces the target's NEXT roll to 3, then clears.
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Spectral Sever", {"dmg": 4, "rewrite": true})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy")
	manager.setup_battle([hero_unit], [enemy_unit])
	var hero: Dictionary = manager.get_hero_states()[0]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	hero["selected_target_id"] = str(enemy["id"])
	manager.resolve_round({str(hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var rewritten_roll: int = manager.get_effective_roll(enemy, 19)
	var pending: bool = bool(enemy.get("rewrite_pending", false))
	manager.resolve_round({}, {}, DiceManager.new())
	var cleared_roll: int = manager.get_effective_roll(enemy, 19)
	if pending and rewritten_roll == 3 and cleared_roll == 19:
		_record_pass("Regression / rewrite sets next roll to 3 then clears", "rewrite")
	else:
		_record_failure("Regression / rewrite sets next roll to 3 then clears", "rewrite", "19 becomes 3 for one round, 19 after", "pending=%s rewritten=%d cleared=%d" % [str(pending), rewritten_roll, cleared_roll])


func _run_hijack_regression() -> void:
	# Hijack: the enemy's next roll copies the heroes' current highest die.
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Noop", {})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy", "Forked Echo", {"hijack": true})
	manager.setup_battle([hero_unit], [enemy_unit])
	var hero: Dictionary = manager.get_hero_states()[0]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	enemy["selected_target_id"] = str(hero["id"])
	manager.resolve_round({str(hero["id"]): AUDIT_ROLL}, {str(enemy["id"]): AUDIT_ROLL}, DiceManager.new())
	var primed: bool = bool(enemy.get("hijack_pending", false)) and bool(enemy.get("hijack_skip_next_tick", false)) == false

	# Consumption path on a noop enemy (the test carrier above re-primes every
	# round via its only ability, so clear semantics are checked separately).
	var copy_manager: CombatManager = CombatManager.new()
	copy_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [_make_enemy("audit_noop_enemy", "Audit Noop Enemy")])
	var c_hero: Dictionary = copy_manager.get_hero_states()[0]
	var c_enemy: Dictionary = copy_manager.get_enemy_states()[0]
	c_enemy["hijack_pending"] = true
	c_enemy["hijack_skip_next_tick"] = false
	var next_enemy_rolls: Dictionary = {str(c_enemy["id"]): 4}
	copy_manager.resolve_round({str(c_hero["id"]): 17}, next_enemy_rolls, DiceManager.new())
	var copied: bool = int(next_enemy_rolls.get(str(c_enemy["id"]), 0)) == 17
	var cleared: bool = not bool(c_enemy.get("hijack_pending", false))
	if primed and copied and cleared:
		_record_pass("Regression / hijack copies highest hero die once", "hijack")
	else:
		_record_failure("Regression / hijack copies highest hero die once", "hijack", "primed after apply; next roll copied 17; cleared after", "primed=%s roll=%d cleared=%s" % [str(primed), int(next_enemy_rolls.get(str(c_enemy["id"]), 0)), str(cleared)])


func _run_siphon_regression() -> void:
	# Siphon: on hit, the enemy queues a Protocol drain for battle_scene.
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Noop", {})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy", "Data Drain", {"dmg": 6, "siphon": 2})
	manager.setup_battle([hero_unit], [enemy_unit])
	var hero: Dictionary = manager.get_hero_states()[0]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	enemy["selected_target_id"] = str(hero["id"])
	manager.resolve_round({}, {str(enemy["id"]): AUDIT_ROLL}, DiceManager.new())
	var drained: int = manager.take_pending_protocol_drain()
	var drained_again: int = manager.take_pending_protocol_drain()
	if drained == 2 and drained_again == 0:
		_record_pass("Regression / siphon drains protocol on hit", "siphon")
	else:
		_record_failure("Regression / siphon drains protocol on hit", "siphon", "2 drained once, then 0", "first=%d second=%d" % [drained, drained_again])


func _run_new_gear_regressions() -> void:
	# Band Compressor / Wide Aperture: runtime band overrides in DiceManager.
	var dm: DiceManager = DiceManager.new()
	var pulse: UnitData = DataManager.get_unit("pulse") as UnitData
	if pulse != null:
		var saved_gear: Dictionary = GameState.gear_by_unit
		GameState.gear_by_unit = {"pulse": ["band_compressor"]}
		var zone_19: String = str(dm.get_ability_for_roll(pulse, 19).get("zone", ""))
		GameState.gear_by_unit = {"pulse": ["wide_aperture"]}
		var zone_8: String = str(dm.get_ability_for_roll(pulse, 8).get("zone", ""))
		GameState.gear_by_unit = {}
		var zone_19_plain: String = str(dm.get_ability_for_roll(pulse, 19).get("zone", ""))
		var zone_8_plain: String = str(dm.get_ability_for_roll(pulse, 8).get("zone", ""))
		GameState.gear_by_unit = saved_gear
		_expect_and_record("Regression / gear bandCompressor 19 -> overload", "overloadBandCompress", "overload/crit", "%s/%s" % [zone_19, zone_19_plain])
		_expect_and_record("Regression / gear wideAperture 8 -> surge", "surgeBandExtend", "surge/strike", "%s/%s" % [zone_8, zone_8_plain])

	# Mirror Plate: enemy jam on the holder grants Protocol.
	var mirror_manager: CombatManager = CombatManager.new()
	mirror_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [_make_enemy("audit_enemy", "Audit Enemy", "ECM Ping", {"jam": true})])
	var mirror_hero: Dictionary = mirror_manager.get_hero_states()[0]
	var mirror_enemy: Dictionary = mirror_manager.get_enemy_states()[0]
	mirror_hero["gear_mirror_plate"] = 2
	mirror_enemy["selected_target_id"] = str(mirror_hero["id"])
	mirror_manager.resolve_round({}, {str(mirror_enemy["id"]): AUDIT_ROLL}, DiceManager.new())
	_expect_and_record("Regression / gear mirrorPlate on jam", "protocolOnDieTamper", "2", str(mirror_manager.take_pending_protocol_grants()))

	# Killswitch Relay: the holder's death detonates for 12 to all enemies.
	var relay_manager: CombatManager = CombatManager.new()
	relay_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [_make_enemy("audit_enemy", "Audit Enemy", "Crush", {"dmg": 200})])
	var relay_hero: Dictionary = relay_manager.get_hero_states()[0]
	var relay_enemy: Dictionary = relay_manager.get_enemy_states()[0]
	relay_hero["gear_death_damage_all"] = 12
	relay_enemy["selected_target_id"] = str(relay_hero["id"])
	var relay_enemy_before: int = int(relay_enemy["current_hp"])
	relay_manager.resolve_round({}, {str(relay_enemy["id"]): AUDIT_ROLL}, DiceManager.new())
	var relay_ok: bool = bool(relay_hero["dead"]) and int(relay_enemy["current_hp"]) == relay_enemy_before - 12
	_expect_and_record("Regression / gear killswitchRelay", "deathDamageAll", "true", str(relay_ok))

	# Anchor Frame: holder above 50% HP soaks single-target attacks aimed elsewhere.
	var anchor_manager: CombatManager = CombatManager.new()
	anchor_manager.setup_battle([_make_unit("audit_hero_a", "Audit Hero A", "Noop", {}), _make_unit("audit_hero_b", "Audit Hero B", "Noop", {})], [_make_enemy("audit_enemy", "Audit Enemy", "Claw", {"dmg": 6})])
	var anchor_a: Dictionary = anchor_manager.get_hero_states()[0]
	var anchor_b: Dictionary = anchor_manager.get_hero_states()[1]
	var anchor_enemy: Dictionary = anchor_manager.get_enemy_states()[0]
	anchor_b["gear_anchor_taunt"] = true
	anchor_enemy["selected_target_id"] = str(anchor_a["id"])
	var a_before: int = int(anchor_a["current_hp"])
	var b_before: int = int(anchor_b["current_hp"])
	anchor_manager.resolve_round({}, {str(anchor_enemy["id"]): AUDIT_ROLL}, DiceManager.new())
	var anchor_ok: bool = int(anchor_a["current_hp"]) == a_before and int(anchor_b["current_hp"]) == b_before - 6
	_expect_and_record("Regression / gear anchorFrame taunts above 50%", "tauntAbove50", "true", str(anchor_ok))

	# Ignition Coil: hero-applied Burn ticks once immediately.
	var coil_manager: CombatManager = CombatManager.new()
	coil_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Arc Burst", {"dmg": 0, "burn": 3, "burnT": 2})], [_make_enemy("audit_enemy", "Audit Enemy")])
	var coil_hero: Dictionary = coil_manager.get_hero_states()[0]
	var coil_enemy: Dictionary = coil_manager.get_enemy_states()[0]
	coil_hero["gear_burn_immediate"] = true
	coil_hero["selected_target_id"] = str(coil_enemy["id"])
	var coil_before: int = int(coil_enemy["current_hp"])
	coil_manager.resolve_round({str(coil_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var coil_ok: bool = int(coil_enemy["current_hp"]) == coil_before - 3 and int(coil_enemy["burn"]) == 3 and int(coil_enemy["burn_turns"]) == 2
	_expect_and_record("Regression / gear ignitionCoil instant tick", "burnImmediateTick", "true", str(coil_ok))

	# Payload Fuse: Detonate bursts deal +50% (ceil).
	var fuse_manager: CombatManager = CombatManager.new()
	fuse_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Backdraft", {"dmg": 5, "detonate": true})], [_make_enemy("audit_enemy", "Audit Enemy")])
	var fuse_hero: Dictionary = fuse_manager.get_hero_states()[0]
	var fuse_enemy: Dictionary = fuse_manager.get_enemy_states()[0]
	fuse_hero["gear_detonate_bonus"] = true
	fuse_hero["selected_target_id"] = str(fuse_enemy["id"])
	fuse_manager.apply_item_burn(fuse_enemy, 3, 2)
	var fuse_before: int = int(fuse_enemy["current_hp"])
	fuse_manager.resolve_round({str(fuse_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	# 5 base + ceil(6 * 1.5) = 5 + 9 = 14
	_expect_and_record("Regression / gear payloadFuse detonate +50%", "detonateBonus", "14", str(fuse_before - int(fuse_enemy["current_hp"])))

	# Targeting Optic: battles start with the first enemy Marked.
	var optic_manager: CombatManager = CombatManager.new()
	optic_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [_make_enemy("audit_enemy", "Audit Enemy")])
	var saved_gear_optic: Dictionary = GameState.gear_by_unit
	GameState.gear_by_unit = {"audit_hero": ["targeting_optic"]}
	optic_manager.apply_battle_start_gear_effects()
	GameState.gear_by_unit = saved_gear_optic
	_expect_and_record("Regression / gear targetingOptic marks first enemy", "battleStartMark", "true", str(bool(optic_manager.get_enemy_states()[0].get("marked", false))))


func _run_new_relic_regressions() -> void:
	# Static Field: enemy dice jammed (cap 10) on turn 1.
	var static_manager: CombatManager = CombatManager.new()
	static_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [_make_enemy("audit_enemy", "Audit Enemy")])
	static_manager.setup_relics(["staticField"])
	static_manager.apply_battle_start_relic_effects(0)
	var static_enemy: Dictionary = static_manager.get_enemy_states()[0]
	_expect_and_record("Regression / relic staticField turn-1 jam", "battleStartJamEnemies", "10", str(static_manager.get_effective_roll(static_enemy, 18)))

	# Mantle Core: hero shields persist flag set at battle start.
	var mantle_manager: CombatManager = CombatManager.new()
	mantle_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [_make_enemy("audit_enemy", "Audit Enemy")])
	mantle_manager.setup_relics(["mantleCore"])
	mantle_manager.apply_battle_start_relic_effects(0)
	_expect_and_record("Regression / relic mantleCore persist flag", "shieldsPersist", "true", str(bool(mantle_manager.get_hero_states()[0].get("shields_persist", false))))

	# Cold Logic: +4 damage against an enemy with a frozen die.
	var cold_manager: CombatManager = CombatManager.new()
	cold_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Strike", {"dmg": 10})], [_make_enemy("audit_enemy", "Audit Enemy")])
	cold_manager.setup_relics(["coldLogic"])
	var cold_hero: Dictionary = cold_manager.get_hero_states()[0]
	var cold_enemy: Dictionary = cold_manager.get_enemy_states()[0]
	cold_enemy["die_freeze_turns"] = 1
	cold_enemy["frozen_die_value"] = 5
	cold_hero["selected_target_id"] = str(cold_enemy["id"])
	var cold_before: int = int(cold_enemy["current_hp"])
	cold_manager.resolve_round({str(cold_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	_expect_and_record("Regression / relic coldLogic +4 vs frozen", "frozenBonusDamage", "14", str(cold_before - int(cold_enemy["current_hp"])))

	# Salvage Rig: +1 Protocol when an enemy shield fully breaks.
	var rig_manager: CombatManager = CombatManager.new()
	rig_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Strike", {"dmg": 10})], [_make_enemy("audit_enemy", "Audit Enemy")])
	rig_manager.setup_relics(["salvageRig"])
	var rig_hero: Dictionary = rig_manager.get_hero_states()[0]
	var rig_enemy: Dictionary = rig_manager.get_enemy_states()[0]
	rig_enemy["shield_stacks"] = [{"amt": 4, "skip_next_tick": true}]
	rig_enemy["shield"] = 4
	rig_hero["selected_target_id"] = str(rig_enemy["id"])
	rig_manager.resolve_round({str(rig_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	_expect_and_record("Regression / relic salvageRig shield break", "protocolOnShieldBreak", "1", str(rig_manager.take_pending_protocol_grants()))

	# Chitin Graft: the killer heals 3 on its kill.
	var graft_manager: CombatManager = CombatManager.new()
	graft_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Strike", {"dmg": 100})], [_make_enemy("audit_enemy", "Audit Enemy")])
	graft_manager.setup_relics(["chitinGraft"])
	var graft_hero: Dictionary = graft_manager.get_hero_states()[0]
	var graft_enemy: Dictionary = graft_manager.get_enemy_states()[0]
	graft_hero["current_hp"] = 30
	graft_hero["selected_target_id"] = str(graft_enemy["id"])
	graft_manager.resolve_round({str(graft_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	_expect_and_record("Regression / relic chitinGraft heal on kill", "heroHealOnOwnKill", "33", str(int(graft_hero["current_hp"])))

	# Salvage Directive: killing a Marked enemy refunds 2 Protocol.
	var directive_manager: CombatManager = CombatManager.new()
	directive_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Strike", {"dmg": 100})], [_make_enemy("audit_enemy", "Audit Enemy")])
	directive_manager.setup_relics(["salvageDirective"])
	var directive_hero: Dictionary = directive_manager.get_hero_states()[0]
	var directive_enemy: Dictionary = directive_manager.get_enemy_states()[0]
	directive_enemy["marked"] = true
	directive_hero["selected_target_id"] = str(directive_enemy["id"])
	directive_manager.resolve_round({str(directive_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	_expect_and_record("Regression / relic salvageDirective marked kill", "protocolOnMarkedKill", "2", str(directive_manager.take_pending_protocol_grants()))

	# Chain Doctrine: Chains jump one extra time.
	var doctrine_manager: CombatManager = CombatManager.new()
	doctrine_manager.setup_battle(
		[_make_unit("audit_hero", "Audit Hero", "Arc Whip", {"dmg": 10, "chain": 1})],
		[_make_enemy("audit_enemy_a", "Audit Enemy A"), _make_enemy("audit_enemy_b", "Audit Enemy B"), _make_enemy("audit_enemy_c", "Audit Enemy C")]
	)
	doctrine_manager.setup_relics(["chainDoctrine"])
	var doctrine_states: Array = doctrine_manager.get_enemy_states()
	var doc_a: Dictionary = doctrine_states[0]
	var doc_b: Dictionary = doctrine_states[1]
	var doc_c: Dictionary = doctrine_states[2]
	var doctrine_hero: Dictionary = doctrine_manager.get_hero_states()[0]
	doctrine_hero["selected_target_id"] = str(doc_a["id"])
	doc_b["current_hp"] = 60
	doc_c["current_hp"] = 90
	doctrine_manager.resolve_round({str(doctrine_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var doctrine_ok: bool = int(doc_b["current_hp"]) == 55 and int(doc_c["current_hp"]) == 85
	_expect_and_record("Regression / relic chainDoctrine extra jump", "chainExtraJump", "true", str(doctrine_ok))

	# Dead Man's Hand: the first squad wipe survives at 1 HP with forced 20s.
	var hand_manager: CombatManager = CombatManager.new()
	hand_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [_make_enemy("audit_enemy", "Audit Enemy", "Crush", {"dmg": 500})])
	hand_manager.setup_relics(["deadMansHand"])
	var hand_hero: Dictionary = hand_manager.get_hero_states()[0]
	var hand_enemy: Dictionary = hand_manager.get_enemy_states()[0]
	hand_enemy["selected_target_id"] = str(hand_hero["id"])
	var saved_hand_flag: bool = GameState.dead_mans_hand_used
	GameState.dead_mans_hand_used = false
	hand_manager.resolve_round({}, {str(hand_enemy["id"]): AUDIT_ROLL}, DiceManager.new())
	var hand_ok: bool = not bool(hand_hero["dead"]) and int(hand_hero["current_hp"]) == 1 and bool(hand_hero.get("forced_20_pending", false)) and GameState.dead_mans_hand_used
	GameState.dead_mans_hand_used = saved_hand_flag
	_expect_and_record("Regression / relic deadMansHand survives wipe", "squadWipeSurvive", "true", str(hand_ok))

	# Scavenger Manifest: the first kill each battle drops a consumable.
	var manifest_manager: CombatManager = CombatManager.new()
	manifest_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Strike", {"dmg": 100})], [_make_enemy("audit_enemy", "Audit Enemy")])
	manifest_manager.setup_relics(["scavengerManifest"])
	var manifest_hero: Dictionary = manifest_manager.get_hero_states()[0]
	manifest_hero["selected_target_id"] = str(manifest_manager.get_enemy_states()[0]["id"])
	var saved_consumables: Array = GameState.consumables.duplicate()
	GameState.consumables.clear()
	manifest_manager.resolve_round({str(manifest_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var manifest_count: int = GameState.consumables.size()
	GameState.consumables = saved_consumables
	_expect_and_record("Regression / relic scavengerManifest first-kill drop", "firstKillDropsConsumable", "1", str(manifest_count))

	# Standing Order: crit bands extend 1 down (via the DiceManager overrides).
	var order_dm: DiceManager = DiceManager.new()
	var order_pulse: UnitData = DataManager.get_unit("pulse") as UnitData
	if order_pulse != null:
		var saved_relics: Array = GameState.relics.duplicate()
		GameState.relics = ["standingOrder"]
		var order_zone: String = str(order_dm.get_ability_for_roll(order_pulse, 15).get("zone", ""))
		GameState.relics = saved_relics
		_expect_and_record("Regression / relic standingOrder crit extends down", "critBandExtend", "crit", order_zone)

	# Root Access: the first Set each battle costs 0 (battle_scene cost path).
	var root_scene: Control = BATTLE_SCENE_SCRIPT.new() as Control
	if root_scene != null:
		root_scene.combat_manager.setup_relics(["rootAccess"])
		# Cost path lives in ProtocolActions (extraction, 2026-07-06); a bare
		# scene never runs _ready, so build the module by hand.
		var root_pa = PROTOCOL_ACTIONS_SCRIPT.new()
		root_pa.setup(root_scene)
		var root_cost: int = int(root_pa.call("_get_set_cost"))
		root_pa.free()
		root_scene.free()
		_expect_and_record("Regression / relic rootAccess free set", "setCostZeroOncePerBattle", "0", str(root_cost))

	# Twin Fates: the copy core clones the source die and clears pending mods.
	var twin_scene: Control = BATTLE_SCENE_SCRIPT.new() as Control
	if twin_scene != null:
		twin_scene.hero_rolls = {"hero_a": 17, "hero_b": 4}
		twin_scene.hero_roll_nudges = {"hero_b": 1}
		twin_scene.hero_roll_sets = {"hero_b": 12}
		var twin_pa = PROTOCOL_ACTIONS_SCRIPT.new()
		twin_pa.setup(twin_scene)
		var twin_copied: bool = bool(twin_pa.call("_twin_fates_copy_roll", "hero_a", "hero_b"))
		twin_pa.free()
		var twin_ok: bool = (
			twin_copied
			and int(twin_scene.hero_rolls.get("hero_b", 0)) == 17
			and not twin_scene.hero_roll_nudges.has("hero_b")
			and not twin_scene.hero_roll_sets.has("hero_b")
			and bool(twin_scene.get("_twin_fates_used"))
		)
		twin_scene.free()
		_expect_and_record("Regression / relic twinFates copy", "twinFates", "true", str(twin_ok))

	# Overflow Vent: protocol past the cap deals 2 damage per point to an enemy.
	var vent_scene: Control = BATTLE_SCENE_SCRIPT.new() as Control
	if vent_scene != null:
		var vent_mgr: CombatManager = vent_scene.combat_manager
		vent_mgr.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [_make_enemy("audit_enemy", "Audit Enemy")])
		vent_mgr.setup_relics(["overflowVent"])
		vent_scene.protocol_points = int(vent_scene.get("MAX_PROTOCOL"))
		vent_scene.call("_gain_protocol", 2)
		var vent_hp: int = int(vent_mgr.get_enemy_states()[0]["current_hp"])
		vent_scene.free()
		_expect_and_record("Regression / relic overflowVent overflow damage", "protocolOverflowDamage", "96", str(vent_hp))

	# Resonant Chorus: turn-1 dice below 8 are lifted to 8.
	var chorus_scene: Control = BATTLE_SCENE_SCRIPT.new() as Control
	if chorus_scene != null:
		var chorus_mgr: CombatManager = chorus_scene.combat_manager
		chorus_mgr.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [_make_enemy("audit_enemy", "Audit Enemy")])
		chorus_mgr.setup_relics(["resonantChorus"])
		var chorus_id: String = str(chorus_mgr.get_hero_states()[0]["id"])
		chorus_scene.hero_rolls = {chorus_id: 3}
		chorus_scene.call("_apply_roll_relic_overrides")
		var chorus_roll: int = int(chorus_scene.hero_rolls.get(chorus_id, 0))
		chorus_scene.free()
		_expect_and_record("Regression / relic resonantChorus turn-1 floor", "turn1RollFloor", "8", str(chorus_roll))


func _run_boss_standing_rule_regressions() -> void:
	# SCRAPMASTER — Assembly Line: every other round, rebuilds one destroyed
	# Scrap Drone at 50% HP.
	var line_manager: CombatManager = CombatManager.new()
	line_manager.setup_battle(
		[_make_unit("audit_hero", "Audit Hero", "Noop", {})],
		[_make_enemy("scrapmaster", "SCRAPMASTER"), _make_enemy("scrap_drone", "Scrap Drone")]
	)
	var line_drone: Dictionary = line_manager.get_enemy_states()[1]
	line_drone["dead"] = true
	line_drone["current_hp"] = 0
	line_manager.resolve_round({}, {}, DiceManager.new())
	var still_down: bool = bool(line_drone["dead"])
	line_manager.resolve_round({}, {}, DiceManager.new())
	var rebuilt: bool = not bool(line_drone["dead"]) and int(line_drone["current_hp"]) == 50
	# Round 3 (phase 3 from activation): no rebuild; round 4: rebuild again.
	line_drone["dead"] = true
	line_drone["current_hp"] = 0
	line_manager.resolve_round({}, {}, DiceManager.new())
	var down_phase3: bool = bool(line_drone["dead"])
	line_manager.resolve_round({}, {}, DiceManager.new())
	var rebuilt_phase4: bool = not bool(line_drone["dead"])
	_expect_and_record("Regression / boss SCRAPMASTER assembly line cadence", "bossStandingRule",
		"true/true/true/true", "%s/%s/%s/%s" % [str(still_down), str(rebuilt), str(down_phase3), str(rebuilt_phase4)])

	# Cadence counts from FIRST ACTIVATION, not global even rounds (DECISIONS
	# #5): with activation stamped at round 3, rebuilds land on rounds 4 and 6.
	var offset_manager: CombatManager = CombatManager.new()
	offset_manager.setup_battle(
		[_make_unit("audit_hero", "Audit Hero", "Noop", {})],
		[_make_enemy("scrapmaster", "SCRAPMASTER"), _make_enemy("scrap_drone", "Scrap Drone")]
	)
	var offset_boss: Dictionary = offset_manager.get_enemy_states()[0]
	var offset_drone: Dictionary = offset_manager.get_enemy_states()[1]
	offset_boss["assembly_line_first_round"] = 3
	offset_drone["dead"] = true
	offset_drone["current_hp"] = 0
	offset_manager.resolve_round({}, {}, DiceManager.new())  # round 1
	offset_manager.resolve_round({}, {}, DiceManager.new())  # round 2 (even — old model would fire)
	var offset_down_r2: bool = bool(offset_drone["dead"])
	offset_manager.resolve_round({}, {}, DiceManager.new())  # round 3 (phase 1)
	var offset_down_r3: bool = bool(offset_drone["dead"])
	offset_manager.resolve_round({}, {}, DiceManager.new())  # round 4 (phase 2 — fires)
	var offset_rebuilt_r4: bool = not bool(offset_drone["dead"])
	_expect_and_record("Regression / assembly line counts from first activation", "bossStandingRule",
		"true/true/true", "%s/%s/%s" % [str(offset_down_r2), str(offset_down_r3), str(offset_rebuilt_r4)])

	# Hive Matriarch — The Brood: a Bloodmite summon event every 3 rounds.
	var brood_manager: CombatManager = CombatManager.new()
	brood_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [_make_enemy("matriarch", "Hive Matriarch")])
	var early_summons: int = 0
	for _round in 2:
		var early_result: Dictionary = brood_manager.resolve_round({}, {}, DiceManager.new())
		for event_variant in early_result.get("events", []):
			if str((event_variant as Dictionary).get("type", "")) == "summon":
				early_summons += 1
	var third_result: Dictionary = brood_manager.resolve_round({}, {}, DiceManager.new())
	var brood_spawn: bool = false
	for event_variant in third_result.get("events", []):
		var event: Dictionary = event_variant
		if str(event.get("type", "")) == "summon" and str(event.get("summon_name", "")) == "Bloodmite":
			brood_spawn = true
	_expect_and_record("Regression / boss Matriarch brood cadence", "bossStandingRule", "true", str(early_summons == 0 and brood_spawn))

	# CONCLAVE OVERSEER — The Court: warded at round start while an ally lives;
	# no ward once it stands alone.
	var court_manager: CombatManager = CombatManager.new()
	court_manager.setup_battle(
		[_make_unit("audit_hero", "Audit Hero", "Noop", {})],
		[_make_enemy("overseer", "CONCLAVE OVERSEER"), _make_enemy("anchor", "Aegis Anchor")]
	)
	var court_boss: Dictionary = court_manager.get_enemy_states()[0]
	court_manager.resolve_round({}, {}, DiceManager.new())
	var court_warded: bool = bool(court_boss.get("warded", false))
	var alone_manager: CombatManager = CombatManager.new()
	alone_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [_make_enemy("overseer", "CONCLAVE OVERSEER")])
	var alone_boss: Dictionary = alone_manager.get_enemy_states()[0]
	alone_manager.resolve_round({}, {}, DiceManager.new())
	var alone_unwarded: bool = not bool(alone_boss.get("warded", false))
	_expect_and_record("Regression / boss Overseer court ward", "bossStandingRule", "true", str(court_warded and alone_unwarded))

	# ROOT HIEROPHANT — Root Access: the squad's highest die is Rewritten to 3.
	var root_manager: CombatManager = CombatManager.new()
	root_manager.setup_battle(
		[_make_unit("audit_low", "Audit Low", "Noop", {}), _make_unit("audit_high", "Audit High", "Noop", {})],
		[_make_enemy("hierophant", "ROOT HIEROPHANT")]
	)
	var low_hero: Dictionary = root_manager.get_hero_states()[0]
	var high_hero: Dictionary = root_manager.get_hero_states()[1]
	root_manager.resolve_round({str(low_hero["id"]): 5, str(high_hero["id"]): 15}, {}, DiceManager.new())
	var high_rewritten: bool = root_manager.get_effective_roll(high_hero, 18) == 3
	var low_untouched: bool = root_manager.get_effective_roll(low_hero, 18) == 18
	_expect_and_record("Regression / boss Hierophant root access", "bossStandingRule", "true", str(high_rewritten and low_untouched))

	# MANTLE TYRANT — Accretion (Cycle-4 ruling): +6 shield every 2ND round
	# start; persists and stacks. Rounds 1-2 hold one plate (6); round 3 lays
	# the second (12).
	var mantle_manager: CombatManager = CombatManager.new()
	mantle_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [_make_enemy("tyrant", "MANTLE TYRANT")])
	var tyrant: Dictionary = mantle_manager.get_enemy_states()[0]
	mantle_manager.resolve_round({}, {}, DiceManager.new())
	var first_plate: int = int(tyrant.get("shield", 0))
	mantle_manager.resolve_round({}, {}, DiceManager.new())
	var second_plate: int = int(tyrant.get("shield", 0))
	mantle_manager.resolve_round({}, {}, DiceManager.new())
	var third_plate: int = int(tyrant.get("shield", 0))
	_expect_and_record("Regression / boss Tyrant accretion stacks", "bossStandingRule", "6/6/12", "%d/%d/%d" % [first_plate, second_plate, third_plate])

	# Standing rules surface in the inspect popup payload.
	var inspect_unit: EnemyData = _make_enemy("tyrant", "MANTLE TYRANT")
	var inspect_payload: Dictionary = InspectResolver.resolve_unit(inspect_unit)
	var has_rule_text: bool = str(inspect_payload.get("description", "")) != ""
	_expect_and_record("Regression / boss inspect shows standing rule", "bossStandingRule", "true", str(has_rule_text))


# Data-driven boss-fight checks: build each operation's battle-10 comp from
# real data and verify the pinned escorts plus each boss's standing rule
# firing with the real unit defs (catches name/handler drift the synthetic
# regressions can't).
const PINNED_BOSS_COMPS := {
	"facility": ["Scrap Drone", "SCRAPMASTER", "Scrap Drone"],
	"hive": ["Spine Stalker", "Hive Matriarch"],
	"veil": ["CONCLAVE OVERSEER", "Aegis Anchor"],
	"voidCirclet": ["ROOT HIEROPHANT", "Checksum Scribe"],
	"stellarMenagerie": ["MANTLE TYRANT", "Geode Panther"],
}


func _run_boss_fight_data_regressions() -> void:
	for op_id in PINNED_BOSS_COMPS.keys():
		var op = DataManager.get_operation(str(op_id))
		if op == null or op.battles.is_empty():
			_record_failure("Boss fight / %s" % op_id, "bossFight", "operation with battles", "missing")
			continue
		var final_names: Array = (op.battles[op.battles.size() - 1] as Dictionary).get("enemy_names", [])
		_expect_and_record("Boss fight / %s pinned escorts" % op_id, "bossFight", str(PINNED_BOSS_COMPS[op_id]), str(final_names))

		var enemy_units: Array = []
		for enemy_name in final_names:
			var enemy_unit: EnemyData = DataManager.get_enemy_by_display_name(str(enemy_name)) as EnemyData
			if enemy_unit == null:
				_record_failure("Boss fight / %s unit '%s'" % [op_id, enemy_name], "bossFight", "enemy def exists", "missing")
			else:
				enemy_units.append(enemy_unit)
		if enemy_units.size() != final_names.size():
			continue

		var manager: CombatManager = CombatManager.new()
		manager.setup_battle(
			[_make_unit("audit_a", "Audit A", "Noop", {}), _make_unit("audit_b", "Audit B", "Noop", {})],
			enemy_units
		)
		var states: Array = manager.get_enemy_states()
		var boss_state: Dictionary = {}
		for state_variant in states:
			if CombatManager.get_boss_standing_rule(str((state_variant as Dictionary)["unit"].display_name)) != "":
				boss_state = state_variant
				break
		if boss_state.is_empty():
			_record_failure("Boss fight / %s standing rule" % op_id, "bossFight", "boss with standing rule in comp", "none found")
			continue

		var hero_a: Dictionary = manager.get_hero_states()[0]
		var hero_b: Dictionary = manager.get_hero_states()[1]
		match str(op_id):
			"facility":
				for state_variant in states:
					if str((state_variant as Dictionary)["unit"].display_name) == "Scrap Drone":
						state_variant["dead"] = true
						state_variant["current_hp"] = 0
						break
				manager.resolve_round({}, {}, DiceManager.new())
				manager.resolve_round({}, {}, DiceManager.new())
				var any_rebuilt: bool = false
				for state_variant in states:
					if str((state_variant as Dictionary)["unit"].display_name) == "Scrap Drone" and not bool(state_variant["dead"]) and int(state_variant["current_hp"]) < int(state_variant["max_hp"]):
						any_rebuilt = true
				_expect_and_record("Boss fight / facility assembly line", "bossFight", "true", str(any_rebuilt))
			"hive":
				manager.resolve_round({}, {}, DiceManager.new())
				manager.resolve_round({}, {}, DiceManager.new())
				var round3: Dictionary = manager.resolve_round({}, {}, DiceManager.new())
				var spawned: bool = false
				for event_variant in round3.get("events", []):
					if str((event_variant as Dictionary).get("summon_name", "")) == "Bloodmite":
						spawned = true
				_expect_and_record("Boss fight / hive brood spawn", "bossFight", "true", str(spawned))
			"veil":
				manager.resolve_round({}, {}, DiceManager.new())
				_expect_and_record("Boss fight / veil court ward", "bossFight", "true", str(bool(boss_state.get("warded", false))))
			"voidCirclet":
				manager.resolve_round({str(hero_a["id"]): 6, str(hero_b["id"]): 14}, {}, DiceManager.new())
				_expect_and_record("Boss fight / synod root access", "bossFight", "3", str(manager.get_effective_roll(hero_b, 18)))
			"stellarMenagerie":
				# Cycle-4 cadence: plate on rounds 1 and 3; round 2 holds.
				manager.resolve_round({}, {}, DiceManager.new())
				var plate_one: int = int(boss_state.get("shield", 0))
				manager.resolve_round({}, {}, DiceManager.new())
				var plate_hold: int = int(boss_state.get("shield", 0))
				manager.resolve_round({}, {}, DiceManager.new())
				var plate_two: int = int(boss_state.get("shield", 0))
				var stacking: bool = plate_one >= 6 and plate_hold == plate_one and plate_two == plate_one * 2
				_expect_and_record("Boss fight / accretion mantle stacks", "bossFight", "true", str(stacking))


func _run_save_manager_regressions() -> void:
	var saved_data: Dictionary = SaveManager.data.duplicate(true)
	SaveManager.data = SaveManager.default_data()

	# Default shape: version 1 with the pinned structure.
	var d: Dictionary = SaveManager.data
	var shape_ok: bool = (
		int(d.get("save_version", 0)) == 1
		and d.has("tutorial_done") and d.has("stats") and d.has("unlocks") and d.has("settings")
		and (d["unlocks"] as Dictionary).has("boss_relics")
	)
	_expect_and_record("Regression / save default shape v1", "saveManager", "true", str(shape_ok))

	# Run stats: start + finish (victory) increment and unlock the op's boss relic.
	SaveManager.record_run_started()
	SaveManager.record_run_finished("victory", "facility", 10)
	var stats: Dictionary = SaveManager.get_stats()
	var wins: Dictionary = stats.get("runs_won_by_op", {})
	var run_ok: bool = (
		int(stats.get("runs_started", 0)) == 1
		and int(wins.get("facility", 0)) == 1
		and int(stats.get("best_clear", 0)) == 10
		and SaveManager.get_unlocked_boss_relics() == ["salvageRig"]
	)
	_expect_and_record("Regression / save run victory + unlock", "saveManager", "true", str(run_ok))

	# Defeat: best_clear ratchets but never regresses; no unlock.
	SaveManager.record_run_finished("defeat", "hive", 4)
	var defeat_ok: bool = (
		int(SaveManager.get_stats().get("best_clear", 0)) == 10
		and SaveManager.get_unlocked_boss_relics() == ["salvageRig"]
	)
	_expect_and_record("Regression / save defeat ratchet", "saveManager", "true", str(defeat_ok))

	# Counters + tutorial flag.
	SaveManager.record_nat20()
	SaveManager.record_nat20()
	SaveManager.record_hero_death()
	SaveManager.mark_tutorial_done()
	var counters_ok: bool = (
		int(SaveManager.get_stats().get("nat20s", 0)) == 2
		and int(SaveManager.get_stats().get("deaths", 0)) == 1
		and SaveManager.is_tutorial_done()
	)
	_expect_and_record("Regression / save counters + tutorial", "saveManager", "true", str(counters_ok))

	# Older/partial saves heal onto defaults.
	SaveManager.data = SaveManager.default_data()
	SaveManager._merge_loaded({"tutorial_done": true, "stats": {"nat20s": 7}})
	var healed: Dictionary = SaveManager.data
	var heal_ok: bool = (
		bool(healed.get("tutorial_done", false))
		and int((healed["stats"] as Dictionary).get("nat20s", 0)) == 7
		and int((healed["stats"] as Dictionary).get("runs_started", -1)) == 0
		and (healed["unlocks"] as Dictionary).get("boss_relics", null) is Array
	)
	_expect_and_record("Regression / save partial-load heal", "saveManager", "true", str(heal_ok))

	# Every operation maps to a boss relic that exists in data.
	var mapping_ok: bool = true
	for op_id in DataManager.get_operation_order():
		var relic_id: String = str(SaveManager.BOSS_RELIC_BY_OP.get(str(op_id), ""))
		if relic_id == "" or DataManager.get_item(relic_id) == null:
			mapping_ok = false
	_expect_and_record("Regression / save boss-relic op mapping", "saveManager", "true", str(mapping_ok))

	# Progression: best_clear_by_op records; a facility clear awards ONE ladder rung
	# (engineer) and unlocks the next op (hive); rung 2 (shield) defers to a later run.
	# Asserts against the raw unlock lists — is_*_unlocked() is force-true when headless.
	# Build F: the boss relic joins the run-end delta (3 entries: relic, hero, op).
	SaveManager.data = SaveManager.default_data()
	SaveManager.record_run_started()
	SaveManager.record_run_finished("victory", "facility", 8)
	var prog_heroes: Array = SaveManager.data["unlocks"]["heroes"]
	var prog_ops: Array = SaveManager.data["unlocks"]["operations"]
	var prog_unlock_types: Array = []
	for prog_entry in SaveManager.check_new_unlocks():
		prog_unlock_types.append(str(prog_entry.get("type", "")))
	var prog_ok: bool = (
		int((SaveManager.data["stats"]["best_clear_by_op"] as Dictionary).get("facility", 0)) == 8
		and prog_heroes.has("engineer")
		and SaveManager.get_hero_ladder_rung() == 1
		and prog_ops.has("hive")
		and not prog_heroes.has("shield")
		and prog_unlock_types == ["boss_relic", "operation", "hero"]
	)
	_expect_and_record("Regression / progression ladder + op chain", "saveManager", "true", str(prog_ok))

	# Grandfather: migrating a played save that predates the unlock schema opens everything.
	SaveManager.data = SaveManager.default_data()
	SaveManager._merge_loaded({"tutorial_done": true, "stats": {"runs_started": 5}})
	var gf_heroes: Array = SaveManager.data["unlocks"]["heroes"]
	var gf_ops: Array = SaveManager.data["unlocks"]["operations"]
	var gf_ok: bool = (
		gf_heroes.has("breaker")
		and gf_ops.has("stellarMenagerie")
		and int(SaveManager.get_hero_ladder_rung()) == int(SaveManager.MAX_HERO_LADDER_RUNG)
	)
	_expect_and_record("Regression / progression grandfather clause", "saveManager", "true", str(gf_ok))

	SaveManager.data = saved_data


func _run_starting_directive_regressions() -> void:
	var saved_save: Dictionary = SaveManager.data.duplicate(true)
	SaveManager.data = SaveManager.default_data()
	SaveManager.data["unlocks"]["boss_relics"] = ["rootAccess"]

	GameState.start_run(["pulse", "combat", "ghost"], "facility")

	# A locked relic can't be taken as a directive.
	GameState.set_starting_directive("mantleCore")
	var locked_refused: bool = GameState.relics.is_empty()

	# An unlocked one opens the run with it.
	GameState.set_starting_directive("rootAccess")
	var directive_taken: bool = GameState.relics == ["rootAccess"]

	# The battle-5 draft still happens: a directive run may claim one drafted
	# relic (ending with two), but never a second draft.
	GameState.pending_reward_item_ids = ["ironCurtain"]
	var first_draft: bool = GameState.claim_reward("ironCurtain")
	GameState.pending_reward_item_ids = ["overcharge"]
	var second_draft_blocked: bool = not GameState.claim_reward("overcharge")
	var two_relics: bool = GameState.relics == ["rootAccess", "ironCurtain"]
	_expect_and_record(
		"Regression / starting directive run",
		"startingDirective",
		"true",
		str(locked_refused and directive_taken and first_draft and second_draft_blocked and two_relics)
	)

	# Boss relics never surface in the normal relic draft.
	var draft_clean: bool = true
	for _i in 10:
		for relic_id in GameState._roll_relic_choice_ids(2):
			var relic_item: ItemData = DataManager.get_item(str(relic_id)) as ItemData
			if relic_item != null and relic_item.boss_relic:
				draft_clean = false
	_expect_and_record("Regression / boss relics excluded from draft", "startingDirective", "true", str(draft_clean))

	GameState.reset_run()
	SaveManager.data = saved_save


func _run_directive_progression_regressions() -> void:
	var saved: Dictionary = {
		"selected_units": GameState.selected_units.duplicate(),
		"unit_xp": GameState.unit_xp.duplicate(true),
		"unit_levels": GameState.unit_levels.duplicate(true),
		"unit_evolutions": GameState.unit_evolutions.duplicate(true),
		"unit_directives": GameState.unit_directives.duplicate(true),
		"pending": GameState.pending_evolution_unit_id,
		"deferred": GameState.deferred_evolution_unit_ids.duplicate(),
	}

	GameState.selected_units = ["pulse"]
	GameState.unit_evolutions = {"pulse": "Arc Specialist"}
	GameState.unit_directives = {}
	GameState.unit_xp = {"pulse": 260}
	GameState.pending_evolution_unit_id = ""
	GameState.deferred_evolution_unit_ids = []

	# An evolved unit past 250 XP queues a Directive stop.
	GameState._queue_evolution_after_win([])
	var stage_ok: bool = GameState.pending_evolution_unit_id == "pulse" and GameState.is_pending_directive_stage()

	# The offer is the evolution path's 1-of-2 pair; picking one applies it.
	var choice_names: Array = []
	for choice_variant in GameState.get_pending_directive_choices():
		choice_names.append(str((choice_variant as Dictionary).get("name", "")))
	var bogus_refused: bool = not GameState.apply_pending_directive("Slow Roast")
	var applied: bool = GameState.apply_pending_directive("Conductor")
	var run_unit: UnitData = GameState.get_run_unit_data("pulse")
	var effect_type: String = str(((run_unit.directive if run_unit != null else {}) as Dictionary).get("effect", {}).get("type", ""))
	_expect_and_record(
		"Regression / directive stage at 250 XP",
		"directiveProgression",
		"true",
		str(stage_ok and choice_names == ["Conductor", "Amplifier"] and bogus_refused and applied and effect_type == "chainExtraJump")
	)

	# An unevolved unit past 100 XP still gets an evolution stop, not a directive.
	GameState.selected_units = ["combat"]
	GameState.unit_evolutions = {}
	GameState.unit_directives = {}
	GameState.unit_xp = {"combat": 260}
	GameState.pending_evolution_unit_id = ""
	GameState.deferred_evolution_unit_ids = []
	GameState._queue_evolution_after_win([])
	var evo_stage: bool = GameState.pending_evolution_unit_id == "combat" and not GameState.is_pending_directive_stage()
	_expect_and_record("Regression / evolution stage before directive", "directiveProgression", "true", str(evo_stage))

	GameState.selected_units = saved["selected_units"]
	GameState.unit_xp = saved["unit_xp"]
	GameState.unit_levels = saved["unit_levels"]
	GameState.unit_evolutions = saved["unit_evolutions"]
	GameState.unit_directives = saved["unit_directives"]
	GameState.pending_evolution_unit_id = saved["pending"]
	GameState.deferred_evolution_unit_ids = saved["deferred"]


func _make_directive_unit(id: String, display_name: String, ability_name: String, raw: Dictionary, effect: Dictionary) -> UnitData:
	var unit: UnitData = _make_unit(id, display_name, ability_name, raw)
	unit.directive = {"name": "Audit Directive", "desc": "", "effect": effect}
	return unit


func _run_directive_combat_regressions() -> void:
	# Slow Roast: burns last +1 turn (3 base ticks -> 4 with the bonus turn).
	var roast_manager: CombatManager = CombatManager.new()
	roast_manager.setup_battle(
		[_make_directive_unit("audit_hero", "Audit Hero", "Ember", {"burn": 2, "burnT": 2}, {"type": "burnDurationBonus", "amount": 1})],
		[_make_enemy("audit_enemy", "Audit Enemy")]
	)
	var roast_hero: Dictionary = roast_manager.get_hero_states()[0]
	var roast_enemy: Dictionary = roast_manager.get_enemy_states()[0]
	roast_hero["selected_target_id"] = str(roast_enemy["id"])
	roast_manager.resolve_round({str(roast_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	_expect_and_record("Regression / directive slowRoast burn turns", "burnDurationBonus", "3", str(int(roast_enemy.get("burn_turns", 0))))

	# Momentum: a kill banks +4 for the next ability's damage.
	var momentum_manager: CombatManager = CombatManager.new()
	momentum_manager.setup_battle(
		[_make_directive_unit("audit_hero", "Audit Hero", "Strike", {"dmg": 100}, {"type": "killNextAbilityDamage", "amount": 4})],
		[_make_enemy("audit_enemy_a", "Audit Enemy A"), _make_enemy("audit_enemy_b", "Audit Enemy B")]
	)
	var momentum_hero: Dictionary = momentum_manager.get_hero_states()[0]
	var momentum_a: Dictionary = momentum_manager.get_enemy_states()[0]
	var momentum_b: Dictionary = momentum_manager.get_enemy_states()[1]
	momentum_hero["selected_target_id"] = str(momentum_a["id"])
	momentum_manager.resolve_round({str(momentum_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var banked: int = int(momentum_hero.get("momentum_bonus", 0))
	momentum_hero["selected_target_id"] = str(momentum_b["id"])
	momentum_b["current_hp"] = 200
	momentum_b["max_hp"] = 200
	momentum_manager.resolve_round({str(momentum_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	_expect_and_record("Regression / directive momentum kill bonus", "killNextAbilityDamage", "4/96", "%d/%d" % [banked, int(momentum_b["current_hp"])])

	# Amplifier: chain hits carry full base damage.
	var amp_manager: CombatManager = CombatManager.new()
	amp_manager.setup_battle(
		[_make_directive_unit("audit_hero", "Audit Hero", "Arc Whip", {"dmg": 10, "chain": 1}, {"type": "chainFullDamage"})],
		[_make_enemy("audit_enemy_a", "Audit Enemy A"), _make_enemy("audit_enemy_b", "Audit Enemy B")]
	)
	var amp_hero: Dictionary = amp_manager.get_hero_states()[0]
	var amp_a: Dictionary = amp_manager.get_enemy_states()[0]
	var amp_b: Dictionary = amp_manager.get_enemy_states()[1]
	amp_hero["selected_target_id"] = str(amp_a["id"])
	amp_b["current_hp"] = 60
	amp_manager.resolve_round({str(amp_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	_expect_and_record("Regression / directive amplifier full chain", "chainFullDamage", "50", str(int(amp_b["current_hp"])))

	# Rampart + Bunker Doctrine shape: bigger granted shields; ally holders spike.
	var rampart_manager: CombatManager = CombatManager.new()
	rampart_manager.setup_battle(
		[
			_make_directive_unit("audit_granter", "Audit Granter", "Aegis", {"shield": 6, "shieldAll": true}, {"type": "ownShieldBonus", "amount": 2}),
			_make_unit("audit_holder", "Audit Holder", "Noop", {}),
		],
		[_make_enemy("audit_enemy", "Audit Enemy")]
	)
	var rampart_granter: Dictionary = rampart_manager.get_hero_states()[0]
	var rampart_holder: Dictionary = rampart_manager.get_hero_states()[1]
	# Apply the ability directly — round-granted shields expire at the tick.
	rampart_manager._apply_hero_ability(rampart_granter, rampart_granter["unit"].dice_ranges[0])
	_expect_and_record("Regression / directive rampart shield bonus", "ownShieldBonus", "8", str(int(rampart_holder.get("shield", 0))))

	var bunker_manager: CombatManager = CombatManager.new()
	bunker_manager.setup_battle(
		[
			_make_directive_unit("audit_granter", "Audit Granter", "Aegis", {"shield": 6, "shieldAll": true}, {"type": "shieldGrantsSpike", "amount": 3}),
			_make_unit("audit_holder", "Audit Holder", "Noop", {}),
		],
		[_make_enemy("audit_enemy", "Audit Enemy", "Claw", {"dmg": 5})]
	)
	var bunker_granter: Dictionary = bunker_manager.get_hero_states()[0]
	var bunker_holder: Dictionary = bunker_manager.get_hero_states()[1]
	bunker_manager._apply_hero_ability(bunker_granter, bunker_granter["unit"].dice_ranges[0])
	_expect_and_record("Regression / directive bunker doctrine spike", "shieldGrantsSpike", "3/0", "%d/%d" % [int(bunker_holder.get("spike", -1)), int(bunker_granter.get("spike", 0))])

	# Field Triage: heals also plate the target.
	var triage_manager: CombatManager = CombatManager.new()
	triage_manager.setup_battle(
		[
			_make_directive_unit("audit_medic", "Audit Medic", "Mend", {"heal": 6, "healTgt": true}, {"type": "healGrantsShield", "amount": 3}),
			_make_unit("audit_patient", "Audit Patient", "Noop", {}),
		],
		[_make_enemy("audit_enemy", "Audit Enemy")]
	)
	var triage_medic: Dictionary = triage_manager.get_hero_states()[0]
	var triage_patient: Dictionary = triage_manager.get_hero_states()[1]
	triage_patient["current_hp"] = 50
	triage_medic["selected_target_id"] = str(triage_patient["id"])
	triage_manager._apply_hero_ability(triage_medic, triage_medic["unit"].dice_ranges[0])
	_expect_and_record("Regression / directive field triage", "healGrantsShield", "56/3", "%d/%d" % [int(triage_patient["current_hp"]), int(triage_patient.get("shield", 0))])

	# Reaper: the execute threshold rises to the directive pct.
	var reaper_manager: CombatManager = CombatManager.new()
	reaper_manager.setup_battle(
		[_make_directive_unit("audit_hero", "Audit Hero", "Cull", {"dmg": 10, "execute": true}, {"type": "executeThresholdPct", "pct": 35})],
		[_make_enemy("audit_enemy", "Audit Enemy")]
	)
	var reaper_hero: Dictionary = reaper_manager.get_hero_states()[0]
	var reaper_enemy: Dictionary = reaper_manager.get_enemy_states()[0]
	reaper_enemy["current_hp"] = 42  # 42-10=32 -> below 35% of 100, above the stock 25%
	reaper_hero["selected_target_id"] = str(reaper_enemy["id"])
	reaper_manager.resolve_round({str(reaper_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	_expect_and_record("Regression / directive reaper threshold", "executeThresholdPct", "24", str(int(reaper_enemy["current_hp"])))

	# Ambush Wiring + Ghostblade: cloak strike hits harder and Executes.
	var ambush_manager: CombatManager = CombatManager.new()
	ambush_manager.setup_battle(
		[_make_directive_unit("audit_hero", "Audit Hero", "Shadow Cut", {"dmg": 10}, {"type": "cloakAttackBonus", "amount": 5})],
		[_make_enemy("audit_enemy", "Audit Enemy")]
	)
	var ambush_hero: Dictionary = ambush_manager.get_hero_states()[0]
	var ambush_enemy: Dictionary = ambush_manager.get_enemy_states()[0]
	ambush_hero["cloaked"] = true
	ambush_hero["selected_target_id"] = str(ambush_enemy["id"])
	ambush_manager.resolve_round({str(ambush_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	_expect_and_record("Regression / directive ambush wiring", "cloakAttackBonus", "85", str(int(ambush_enemy["current_hp"])))

	var ghost_manager: CombatManager = CombatManager.new()
	ghost_manager.setup_battle(
		[_make_directive_unit("audit_hero", "Audit Hero", "Shadow Cut", {"dmg": 10}, {"type": "decloakExecute"})],
		[_make_enemy("audit_enemy", "Audit Enemy")]
	)
	var ghost_hero: Dictionary = ghost_manager.get_hero_states()[0]
	var ghost_enemy: Dictionary = ghost_manager.get_enemy_states()[0]
	ghost_hero["cloaked"] = true
	ghost_enemy["current_hp"] = 30  # 30-10=20 -> below 25% -> execute +8
	ghost_hero["selected_target_id"] = str(ghost_enemy["id"])
	ghost_manager.resolve_round({str(ghost_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	_expect_and_record("Regression / directive ghostblade execute", "decloakExecute", "12", str(int(ghost_enemy["current_hp"])))

	# Signal Theft + Hard Lock: single-target roll-downs jam and feed the pool.
	var theft_manager: CombatManager = CombatManager.new()
	theft_manager.setup_battle(
		[_make_directive_unit("audit_hero", "Audit Hero", "Static Lash", {"rfe": 2, "rfT": 2}, {"type": "rfeGrantsProtocol", "amount": 1})],
		[_make_enemy("audit_enemy", "Audit Enemy")]
	)
	var theft_hero: Dictionary = theft_manager.get_hero_states()[0]
	theft_hero["selected_target_id"] = str(theft_manager.get_enemy_states()[0]["id"])
	theft_manager.resolve_round({str(theft_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	_expect_and_record("Regression / directive signal theft", "rfeGrantsProtocol", "1", str(theft_manager.take_pending_protocol_grants()))

	var lock_manager: CombatManager = CombatManager.new()
	lock_manager.setup_battle(
		[_make_directive_unit("audit_hero", "Audit Hero", "Static Lash", {"rfe": 2, "rfT": 2}, {"type": "rfeAlsoJam"})],
		[_make_enemy("audit_enemy", "Audit Enemy")]
	)
	var lock_hero: Dictionary = lock_manager.get_hero_states()[0]
	var lock_enemy: Dictionary = lock_manager.get_enemy_states()[0]
	lock_hero["selected_target_id"] = str(lock_enemy["id"])
	lock_manager.resolve_round({str(lock_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	_expect_and_record("Regression / directive hard lock jam", "rfeAlsoJam", "10", str(int(lock_enemy.get("jam_cap", 0))))

	# Feedback: enemies under an active roll-down take chip damage each round.
	var feedback_manager: CombatManager = CombatManager.new()
	feedback_manager.setup_battle(
		[_make_directive_unit("audit_hero", "Audit Hero", "Static Lash", {"rfe": 2, "rfT": 2}, {"type": "rfeDamagePerRound", "amount": 2})],
		[_make_enemy("audit_enemy", "Audit Enemy")]
	)
	var feedback_hero: Dictionary = feedback_manager.get_hero_states()[0]
	var feedback_enemy: Dictionary = feedback_manager.get_enemy_states()[0]
	feedback_hero["selected_target_id"] = str(feedback_enemy["id"])
	feedback_manager.resolve_round({str(feedback_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	_expect_and_record("Regression / directive feedback chip", "rfeDamagePerRound", "98", str(int(feedback_enemy["current_hp"])))

	# Vanish: dropping below half HP cloaks the hero once per battle.
	var vanish_manager: CombatManager = CombatManager.new()
	vanish_manager.setup_battle(
		[_make_directive_unit("audit_hero", "Audit Hero", "Noop", {}, {"type": "lowHpCloakOnce", "pct": 50})],
		[_make_enemy("audit_enemy", "Audit Enemy", "Crush", {"dmg": 60})]
	)
	var vanish_hero: Dictionary = vanish_manager.get_hero_states()[0]
	var vanish_enemy: Dictionary = vanish_manager.get_enemy_states()[0]
	vanish_enemy["selected_target_id"] = str(vanish_hero["id"])
	vanish_manager.resolve_round({}, {str(vanish_enemy["id"]): AUDIT_ROLL}, DiceManager.new())
	_expect_and_record("Regression / directive vanish", "lowHpCloakOnce", "true/true", "%s/%s" % [str(bool(vanish_hero.get("cloaked", false))), str(bool(vanish_hero.get("vanish_used", false)))])


const SIGNATURE_FIGHTS := {
	"facility": {"index": 4, "names": ["Guard Elite", "Guard Elite"]},
	"hive": {"index": 6, "names": ["Broodwarden"]},
	"veil": {"index": 6, "names": ["Aegis Anchor", "Aegis Anchor"]},
	"voidCirclet": {"index": 3, "names": ["Axiom Binder"]},
	"stellarMenagerie": {"index": 3, "names": ["Geode Panther"]},
}


func _run_battle_slot_regressions() -> void:
	# Role pools: every faction fields fodder/elite/heavy; support falls back
	# to elite where the faction has none (The Accretion).
	var pools_ok: bool = true
	for op_id in DataManager.get_operation_order():
		for role in ["fodder", "elite", "heavy", "support"]:
			if DataManager.get_role_pool(str(op_id), str(role)).is_empty():
				pools_ok = false
	_expect_and_record("Regression / slot role pools populated", "battleSlots", "true", str(pools_ok))

	# Run-start resolution: anchors stay authored, signatures pinned, slot
	# battles roll real faction units at the pattern's size.
	var all_ok: bool = true
	var detail: String = ""
	for op_id_variant in DataManager.get_operation_order():
		var op_id: String = str(op_id_variant)
		GameState.start_run(["pulse", "combat", "ghost"], op_id)
		var op = DataManager.get_operation(op_id)
		var comps: Array = GameState.resolved_battle_comps
		if comps.size() != op.battles.size():
			all_ok = false
			detail = "%s comp count %d" % [op_id, comps.size()]
			break
		var faction_pool: Array = []
		for role in ["fodder", "elite", "heavy", "support"]:
			faction_pool.append_array(DataManager.get_role_pool(op_id, str(role)))
		for i in comps.size():
			var names: Array = (comps[i] as Dictionary).get("names", [])
			var battle: Dictionary = op.battles[i]
			var authored: Array = battle.get("enemy_names", [])
			if not authored.is_empty():
				if names != authored:
					all_ok = false
					detail = "%s b%d fixed comp drifted" % [op_id, i + 1]
			else:
				var slots: Array = battle.get("slots", [])
				var min_size: int = slots.size()
				var max_size: int = slots.size()
				if slots.has("heavyOrElites"):
					max_size += 1
				if names.is_empty() or names.size() < min_size or names.size() > max_size:
					all_ok = false
					detail = "%s b%d rolled %d names for %s" % [op_id, i + 1, names.size(), str(slots)]
				for name_variant in names:
					if not faction_pool.has(str(name_variant)):
						all_ok = false
						detail = "%s b%d rolled outsider %s" % [op_id, i + 1, str(name_variant)]
		var signature: Dictionary = SIGNATURE_FIGHTS[op_id]
		var sig_names: Array = (comps[int(signature["index"])] as Dictionary).get("names", [])
		if sig_names != signature["names"]:
			all_ok = false
			detail = "%s signature comp %s" % [op_id, str(sig_names)]
	_expect_and_record("Regression / slot comps resolved at run start", "battleSlots", "true", "%s%s" % [str(all_ok), "" if all_ok else " (" + detail + ")"])

	# The Accretion signature panther spawns cloaked.
	GameState.start_run(["pulse", "combat", "ghost"], "stellarMenagerie")
	var panther_comp: Dictionary = GameState.resolved_battle_comps[3]
	_expect_and_record("Regression / signature panther cloaked", "battleSlots", str(["Geode Panther"]), str(panther_comp.get("cloaked", [])))

	GameState.reset_run()


# Battle-5 "INTERCEPT: RELIC CACHE" soft lock (fixed 2026-07-06): a run that
# opens with a pkg5 Starting Directive boss relic must STILL get its battle-5
# relic draft — the old relics.is_empty() guards rolled ZERO options and dead-
# ended the run. Pins the reproducing config (seed 424242 + salvageRig) through
# the fixed flow, plus the draft invariants and the beat-gap exclusion.
func _run_relic_cache_regression() -> void:
	var gs: Node = GameState
	var sm: Node = SaveManager
	sm.call("unlock_boss_relic_for_op", "facility")

	gs.call("start_run", ["combat", "avalanche", "medic"], "facility", 424242)
	gs.call("set_starting_directive", "salvageRig")
	gs.set("current_battle", 5)
	gs.call("prepare_battle_rewards")
	var options: Array = gs.call("get_pending_reward_items")
	var count_ok: bool = options.size() == int(gs.get("RELIC_CHOICE_COUNT"))
	var all_relics: bool = true
	var no_boss: bool = true
	var no_owned_dup: bool = true
	for option_variant in options:
		var option: ItemData = option_variant as ItemData
		if option == null or option.item_type != "relic":
			all_relics = false
		elif option.boss_relic:
			no_boss = false
		elif option.id == "salvageRig":
			no_owned_dup = false
	_expect_and_record(
		"Regression / relic cache drafts with a Starting Directive relic", "relicCache",
		"count/relics/noboss/nodup = true/true/true/true",
		"count/relics/noboss/nodup = %s/%s/%s/%s" % [str(count_ok), str(all_relics), str(no_boss), str(no_owned_dup)]
	)

	# Claiming one relic closes the draft: a re-entry rolls empty on purpose.
	if not options.is_empty():
		gs.call("claim_reward", str((options[0] as ItemData).id), "")
	var claimed_ok: bool = int(gs.call("drafted_relic_count")) == 1 and (gs.get("relics") as Array).size() == 2
	gs.call("prepare_battle_rewards")
	var reentry_empty: bool = (gs.call("get_pending_reward_items") as Array).is_empty()
	_expect_and_record(
		"Regression / relic cache claim closes the draft", "relicCache",
		"claimed/reentry_empty = true/true",
		"claimed/reentry_empty = %s/%s" % [str(claimed_ok), str(reentry_empty)]
	)

	# Beat scheduler exclusion: no seed may place an event beat after battle 5
	# (the relic slot) — the gap list simply doesn't contain it; keep it that way.
	var beat5_hits: int = 0
	for seed_value in range(200):
		gs.call("start_run", ["combat", "avalanche", "medic"], "facility", 800000 + seed_value)
		if not (gs.call("get_beat_after_battle", 5) as Dictionary).is_empty():
			beat5_hits += 1
	_expect_and_record("Regression / no event beat on the relic battle (200-seed sweep)", "relicCache", "0", str(beat5_hits))


func _run_beat_regressions() -> void:
	# Beats: exactly 3, in distinct allowed gaps, >=1 Fork and >=1 Intercept,
	# minor before b6 / major from b6 — across repeated rolls.
	var all_ok: bool = true
	var detail: String = ""
	for _attempt in 12:
		GameState.start_run(["pulse", "combat", "ghost"], "facility")
		var beats: Dictionary = GameState.run_beats
		if beats.size() != 3:
			all_ok = false
			detail = "beat count %d" % beats.size()
			break
		var fork_seen: bool = false
		var intercept_seen: bool = false
		for gap_variant in beats.keys():
			var gap: int = int(gap_variant)
			if not GameState.BEAT_GAPS.has(gap):
				all_ok = false
				detail = "illegal gap %d" % gap
			var beat: Dictionary = beats[gap_variant]
			var beat_type: String = str(beat.get("type", ""))
			fork_seen = fork_seen or beat_type == "fork"
			intercept_seen = intercept_seen or beat_type == "intercept"
			var expected_tier: String = "major" if gap >= GameState.MAJOR_BEAT_FROM else "minor"
			if str(beat.get("tier", "")) != expected_tier:
				all_ok = false
				detail = "gap %d tier %s" % [gap, str(beat.get("tier", ""))]
		if not fork_seen or not intercept_seen:
			all_ok = false
			detail = "missing type (fork=%s intercept=%s)" % [str(fork_seen), str(intercept_seen)]
		if not all_ok:
			break
	GameState.reset_run()
	_expect_and_record("Regression / run beats placement", "runBeats", "true", "%s%s" % [str(all_ok), "" if all_ok else " (" + detail + ")"])


func _run_route_modifier_regressions() -> void:
	# Roll rules: no repeats per run; preconditioned modifiers redraw away.
	GameState.start_run(["pulse", "combat", "ghost"], "facility")
	GameState.current_battle = 2
	var no_repeat_ok: bool = true
	var precondition_ok: bool = true
	for modifier_id in GameState.BATTLE_MODIFIERS.keys():
		if str(modifier_id) != "warded":
			GameState.used_battle_modifiers.append(str(modifier_id))
	# Only "warded" remains — a comp without a support unit must fail its
	# precondition and yield no modifier.
	GameState.resolved_battle_comps[2] = {"names": ["Scrap Drone", "Rust Drone"], "cloaked": []}
	if GameState.roll_route_modifier() != "":
		precondition_ok = false
	# With a support in the comp, warded becomes rollable.
	GameState.resolved_battle_comps[2] = {"names": ["Guard Elite", "Rust Drone"], "cloaked": []}
	if GameState.roll_route_modifier() != "warded":
		precondition_ok = false
	GameState.used_battle_modifiers.clear()
	for _i in 5:
		var rolled: String = GameState.roll_route_modifier()
		if GameState.used_battle_modifiers.has(rolled):
			no_repeat_ok = false
		GameState.used_battle_modifiers.append(rolled)
	_expect_and_record("Regression / route modifier roll rules", "routeModifiers", "true", str(no_repeat_ok and precondition_ok))

	# Flagged acceptance: comp-shaping modifiers reshape the next comp and the
	# supply grade arms.
	GameState.used_battle_modifiers.clear()
	GameState.resolved_battle_comps[2] = {"names": ["Guard Elite", "Rust Drone"], "cloaked": []}
	GameState.accept_flagged_route("overrun")
	var overrun_comp: Array = (GameState.resolved_battle_comps[2] as Dictionary).get("names", [])
	var fodder_pool: Array = DataManager.get_role_pool("facility", "fodder")
	var overrun_ok: bool = overrun_comp.size() == 3 and fodder_pool.has(str(overrun_comp[2]))
	var armed_ok: bool = GameState.next_battle_modifier == "overrun" and GameState.next_battle_supply_grade == 2

	GameState.resolved_battle_comps[2] = {"names": ["Guard Elite", "Rust Drone"], "cloaked": []}
	GameState.accept_flagged_route("warded")
	var warded_list: Array = (GameState.resolved_battle_comps[2] as Dictionary).get("warded", [])
	var warded_ok: bool = warded_list == ["Guard Elite"]
	_expect_and_record("Regression / flagged route acceptance", "routeModifiers", "true", str(overrun_ok and armed_ok and warded_ok))

	# fix-1.5: no-op offers are forbidden — every preconditioned modifier is
	# checked against an edge comp where it would produce no observable delta
	# (must redraw to nothing) and a comp where it does (must be offered).
	var elite_pool: Array = DataManager.get_role_pool("facility", "elite")
	var support_pool: Array = (DataManager.enemy_role_pools.get("facility", {}) as Dictionary).get("support", [])
	var no_noop_ok: bool = true
	if elite_pool.is_empty() or support_pool.is_empty():
		no_noop_ok = false
	else:
		var edge_cases: Array = [
			["elitePresence", [str(elite_pool[0]), str(elite_pool[0]), str(elite_pool[0])], [str(elite_pool[0]), "Scrap Drone"]],
			["overrun", ["Scrap Drone", "Scrap Drone", "Scrap Drone"], ["Scrap Drone", "Scrap Drone"]],
			["warded", ["Scrap Drone", "Rust Drone"], [str(support_pool[0]), "Scrap Drone"]],
		]
		for case_variant in edge_cases:
			var edge_case: Array = case_variant
			GameState.used_battle_modifiers.clear()
			for modifier_id in GameState.BATTLE_MODIFIERS.keys():
				if str(modifier_id) != str(edge_case[0]):
					GameState.used_battle_modifiers.append(str(modifier_id))
			GameState.resolved_battle_comps[2] = {"names": (edge_case[1] as Array).duplicate(), "cloaked": []}
			if GameState.roll_route_modifier() != "":
				no_noop_ok = false
			GameState.resolved_battle_comps[2] = {"names": (edge_case[2] as Array).duplicate(), "cloaked": []}
			if GameState.roll_route_modifier() != str(edge_case[0]):
				no_noop_ok = false
	_expect_and_record("Regression / no no-op modifier offers", "routeModifiers", "true", str(no_noop_ok))

	# fix-1.5: preview == fight. Rolling a comp-shaping modifier stashes the
	# shaped comp without touching the resolved (standard) comp; acceptance
	# commits the exact stashed names.
	GameState.used_battle_modifiers.clear()
	for modifier_id in GameState.BATTLE_MODIFIERS.keys():
		if str(modifier_id) != "elitePresence":
			GameState.used_battle_modifiers.append(str(modifier_id))
	GameState.resolved_battle_comps[2] = {"names": ["Scrap Drone", "Rust Drone"], "cloaked": []}
	var preview_roll: String = GameState.roll_route_modifier()
	var standard_names: Array = (GameState.resolved_battle_comps[2] as Dictionary).get("names", [])
	var preview_names: Array = (GameState.pending_flagged_comp as Dictionary).get("names", [])
	var standard_untouched: bool = standard_names == ["Scrap Drone", "Rust Drone"]
	var preview_differs: bool = preview_names != standard_names and preview_names.size() == 2
	GameState.accept_flagged_route(preview_roll)
	var committed_names: Array = (GameState.resolved_battle_comps[2] as Dictionary).get("names", [])
	_expect_and_record(
		"Regression / flagged preview matches committed comp", "routeModifiers",
		"true", str(preview_roll == "elitePresence" and standard_untouched and preview_differs and committed_names == preview_names)
	)
	GameState.reset_run()

	# Combat-side modifiers.
	var ferocity_manager: CombatManager = CombatManager.new()
	ferocity_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [_make_enemy("audit_enemy", "Audit Enemy", "Claw", {"dmg": 5})])
	ferocity_manager.setup_battle_modifier("ferocity")
	var ferocity_hero: Dictionary = ferocity_manager.get_hero_states()[0]
	var ferocity_enemy: Dictionary = ferocity_manager.get_enemy_states()[0]
	ferocity_enemy["selected_target_id"] = str(ferocity_hero["id"])
	ferocity_manager.resolve_round({}, {str(ferocity_enemy["id"]): AUDIT_ROLL}, DiceManager.new())
	_expect_and_record("Regression / modifier ferocity", "routeModifiers", "93", str(int(ferocity_hero["current_hp"])))

	var hardened_manager: CombatManager = CombatManager.new()
	hardened_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [_make_enemy("audit_enemy", "Audit Enemy")])
	hardened_manager.setup_battle_modifier("hardened")
	_expect_and_record("Regression / modifier hardened", "routeModifiers", "8", str(int(hardened_manager.get_enemy_states()[0].get("shield", 0))))

	var jam_field_manager: CombatManager = CombatManager.new()
	jam_field_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [_make_enemy("audit_enemy", "Audit Enemy")])
	jam_field_manager.setup_battle_modifier("jammingField")
	_expect_and_record("Regression / modifier jamming field", "routeModifiers", "10", str(jam_field_manager.get_effective_roll(jam_field_manager.get_hero_states()[0], 18)))

	var charge_manager: CombatManager = CombatManager.new()
	charge_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Strike", {"dmg": 200})], [_make_enemy("audit_enemy", "Audit Enemy")])
	charge_manager.setup_battle_modifier("deadMansCharge")
	var charge_hero: Dictionary = charge_manager.get_hero_states()[0]
	charge_hero["selected_target_id"] = str(charge_manager.get_enemy_states()[0]["id"])
	charge_manager.resolve_round({str(charge_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	_expect_and_record("Regression / modifier dead man's charge", "routeModifiers", "96", str(int(charge_hero["current_hp"])))

	var regen_manager: CombatManager = CombatManager.new()
	regen_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Strike", {"dmg": 10})], [_make_enemy("audit_enemy", "Audit Enemy")])
	regen_manager.setup_battle_modifier("regenerative")
	var regen_hero: Dictionary = regen_manager.get_hero_states()[0]
	var regen_enemy: Dictionary = regen_manager.get_enemy_states()[0]
	regen_hero["selected_target_id"] = str(regen_enemy["id"])
	regen_manager.resolve_round({str(regen_hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	_expect_and_record("Regression / modifier regenerative", "routeModifiers", "93", str(int(regen_enemy["current_hp"])))

	# Sealed Supplies raises the item cost (battle_scene cost path).
	var sealed_scene: Control = BATTLE_SCENE_SCRIPT.new() as Control
	if sealed_scene != null:
		sealed_scene.combat_manager.setup_battle([], [])
		sealed_scene.combat_manager.setup_battle_modifier("sealedSupplies")
		var sealed_pa = PROTOCOL_ACTIONS_SCRIPT.new()
		sealed_pa.setup(sealed_scene)
		var sealed_cost: int = int(sealed_pa.call("_get_item_protocol_cost", null))
		sealed_pa.free()
		sealed_scene.free()
		_expect_and_record("Regression / modifier sealed supplies", "routeModifiers", "2", str(sealed_cost))


func _run_intercept_regressions() -> void:
	GameState.start_run(["pulse", "combat", "ghost"], "facility")

	# Decks: 11 cards per tier, drawn without replacement; Memorial Protocol
	# redraws away while nobody died recently.
	var deck_ok: bool = GameState.intercept_minor_deck.size() == 11 and GameState.intercept_major_deck.size() == 11
	var drawn: Array = []
	for _i in 11:
		var card_id: String = GameState.draw_intercept_card("major")
		if card_id != "":
			drawn.append(card_id)
	var memorial_held: bool = not drawn.has("memorialProtocol") and drawn.size() == 10
	GameState.record_battle_hero_deaths(["pulse"])
	var memorial_after_death: bool = GameState.draw_intercept_card("major") == "memorialProtocol"
	_expect_and_record("Regression / intercept deck rules", "interceptDeck", "true", str(deck_ok and memorial_held and memorial_after_death))

	# Effects: hero mods, next-battle flags, run-wide protocol, follow-up arm.
	GameState.apply_intercept_effects([{"type": "heroRollBonus", "amount": 1}, {"type": "heroMaxHp", "amount": -8}], "pulse")
	var pulse_mods: Dictionary = GameState.hero_run_mods.get("pulse", {})
	var mods_ok: bool = int(pulse_mods.get("roll_bonus", 0)) == 1 and int(pulse_mods.get("max_hp_delta", 0)) == -8
	GameState.apply_intercept_effects([{"type": "protocolNextBattle", "amount": 2}, {"type": "nextBattleFlag", "flag": "decoy"}, {"type": "incomeDebt", "amount": 5}])
	var flags_ok: bool = (
		int(GameState.next_battle_effects.get("protocol", 0)) == 2
		and bool(GameState.next_battle_effects.get("decoy", false))
		and int(GameState.next_battle_effects.get("income_debt", 0)) == 5
	)
	GameState.apply_intercept_effects([{"type": "runProtocolPerBattle", "amount": 1, "cap": 8}])
	var engineer_ok: bool = GameState.run_protocol_per_battle == 1 and GameState.run_protocol_cap_override == 8
	GameState.apply_intercept_effects([{"type": "followupModifier", "id": "elitePresence"}])
	GameState.promote_followup_effects()
	var followup_ok: bool = GameState.next_battle_modifier == "elitePresence" and GameState.followup_battle_effects.is_empty()
	_expect_and_record("Regression / intercept effects", "interceptEffects", "true", str(mods_ok and flags_ok and engineer_ok and followup_ok))

	# The Foundry: sacrificed gear returns one rarity higher.
	GameState.gear_by_unit["pulse"] = ["bounty_chip"]
	var bounty: ItemData = DataManager.get_item("bounty_chip") as ItemData
	var foundry_info: String = GameState.apply_intercept_effects([{"type": "foundryUpgrade"}], "pulse", {"hero_id": "pulse", "gear_id": "bounty_chip"})
	var new_gear: Array = GameState.gear_by_unit.get("pulse", [])
	var foundry_ok: bool = false
	if new_gear.size() == 1 and bounty != null:
		var forged: ItemData = DataManager.get_item(str(new_gear[0])) as ItemData
		var old_tier: int = GameState.RARITY_LADDER.find(bounty.rarity)
		foundry_ok = forged != null and GameState.RARITY_LADDER.find(forged.rarity) == mini(old_tier + 1, 3) and foundry_info != ""
	_expect_and_record("Regression / intercept foundry upgrade", "interceptEffects", "true", str(foundry_ok))

	# Splice Deal bands: overload 19-20, recharge widened by 2.
	GameState.hero_run_mods["pulse"] = {"splice_bands": true}
	var splice_dm: DiceManager = DiceManager.new()
	var pulse_unit: UnitData = DataManager.get_unit("pulse") as UnitData
	var splice_ok: bool = (
		str(splice_dm.get_ability_for_roll(pulse_unit, 19).get("zone", "")) == "overload"
		and str(splice_dm.get_ability_for_roll(pulse_unit, 5).get("zone", "")) == "recharge"
	)
	_expect_and_record("Regression / intercept splice bands", "interceptEffects", "true", str(splice_ok))
	GameState.reset_run()

	# Decoy: enemies waste turn 1, act normally on turn 2.
	var decoy_manager: CombatManager = CombatManager.new()
	decoy_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [_make_enemy("audit_enemy", "Audit Enemy", "Claw", {"dmg": 5})])
	decoy_manager.set_decoy_round_one()
	var decoy_hero: Dictionary = decoy_manager.get_hero_states()[0]
	var decoy_enemy: Dictionary = decoy_manager.get_enemy_states()[0]
	decoy_manager.resolve_round({}, {str(decoy_enemy["id"]): AUDIT_ROLL}, DiceManager.new())
	var round_one_hp: int = int(decoy_hero["current_hp"])
	decoy_manager.resolve_round({}, {str(decoy_enemy["id"]): AUDIT_ROLL}, DiceManager.new())
	_expect_and_record("Regression / intercept decoy", "interceptEffects", "100/95", "%d/%d" % [round_one_hp, int(decoy_hero["current_hp"])])

	# Overload Rites: this hero's natural 20s resolve twice.
	var rites_manager: CombatManager = CombatManager.new()
	rites_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Strike", {"dmg": 10})], [_make_enemy("audit_enemy", "Audit Enemy")])
	var rites_hero: Dictionary = rites_manager.get_hero_states()[0]
	var rites_enemy: Dictionary = rites_manager.get_enemy_states()[0]
	rites_hero["nat20_twice"] = true
	rites_hero["selected_target_id"] = str(rites_enemy["id"])
	rites_manager.resolve_round({str(rites_hero["id"]): 20}, {}, DiceManager.new(), {}, {str(rites_hero["id"]): 20})
	_expect_and_record("Regression / intercept overload rites", "interceptEffects", "80", str(int(rites_enemy["current_hp"])))


func _run_evolution_kit_regression() -> void:
	# An evolved unit must run its evolution's FULL 5-zone kit, not just the
	# first zone (regression for the single-ability grouping bug).
	var saved_evolutions: Dictionary = GameState.unit_evolutions.duplicate(true)
	GameState.unit_evolutions["pulse"] = "Arc Specialist"
	var evolved: UnitData = GameState.get_run_unit_data("pulse")
	GameState.unit_evolutions = saved_evolutions
	if evolved == null:
		_record_failure("Regression / evolved kit full swap", "evolutionKit", "evolved unit", "null")
		return
	var dm: DiceManager = DiceManager.new()
	var names: Array = []
	for roll in [2, 8, 12, 18, 20]:
		names.append(str(dm.get_ability_for_roll(evolved, roll).get("ability_name", "")))
	_expect_and_record(
		"Regression / evolved kit full swap",
		"evolutionKit",
		str(["Static Coil", "Arc Whip", "Fork Lightning", "Cascade", "Grid Collapse"]),
		str(names)
	)


func _run_shield_lowest_regression() -> void:
	# shieldLowest auto-targets the lowest-HP living ally — no manual pick.
	var context: Dictionary = _build_context({"shield": 7, "shieldLowest": true}, "Shield Lowest Regression")
	var manager: CombatManager = context["manager"]
	var actor: Dictionary = context["actor"]
	var ally_a: Dictionary = context["ally_a"]
	var ally_b: Dictionary = context["ally_b"]
	ally_a["current_hp"] = 25
	ally_b["current_hp"] = 80
	var result: Dictionary = manager.resolve_round({str(actor["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var events: Array = result.get("events", [])
	if _has_target_event(events, "shield", 7, "hero", "audit_ally_a"):
		_record_pass("Regression / shieldLowest targets lowest ally", "shieldLowest")
	else:
		_record_failure("Regression / shieldLowest targets lowest ally", "shieldLowest", "shield event on lowest HP ally", "events=%s" % str(events))


func _run_rampage_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Noop", {})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy", "Rampage Hit", {"dmg": 6})
	manager.setup_battle([hero_unit], [enemy_unit])
	var hero: Dictionary = manager.get_hero_states()[0]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	enemy["selected_target_id"] = str(hero["id"])
	enemy["rampage_charges"] = 1
	var before_hp: int = int(hero["current_hp"])
	manager.resolve_round({}, {str(enemy["id"]): AUDIT_ROLL}, DiceManager.new())
	var ok: bool = int(hero["current_hp"]) == before_hp - 12 and int(enemy["rampage_charges"]) == 0
	if ok:
		_record_pass("Regression / rampage consumes charge", "rampage")
	else:
		_record_failure("Regression / rampage consumes charge", "rampage", "one charge doubles next damage and is consumed", "hero_delta=%d charges=%d" % [before_hp - int(hero["current_hp"]), int(enemy["rampage_charges"])])


func _run_freeze_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Noop", {})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy")
	manager.setup_battle([hero_unit], [enemy_unit])
	var enemy: Dictionary = manager.get_enemy_states()[0]
	enemy["last_die_value"] = 12
	manager.call("_freeze_die_state", enemy, 1)
	manager.call("_freeze_die_state", enemy, 1)
	var ok: bool = int(enemy.get("die_freeze_turns", 0)) == 2 and int(enemy.get("frozen_die_value", 0)) == 12
	if ok:
		_record_pass("Regression / re-freeze adds repeats", "freeze")
	else:
		_record_failure("Regression / re-freeze adds repeats", "freeze", "freeze repeats add and the frozen face is preserved", "turns=%d value=%d" % [int(enemy.get("die_freeze_turns", 0)), int(enemy.get("frozen_die_value", 0))])


# Freeze = repeat (per Kev 2026-07-06): immunity, chaining, and deterministic
# enemy-AI targeting cases.
func _run_freeze_repeat_regressions() -> void:
	# 1) Frozen HERO die is immune to enemy Jam and Rewrite.
	var m1: CombatManager = CombatManager.new()
	m1.setup_battle(
		[_make_unit("audit_hero", "Audit Hero", "Noop", {})],
		[_make_enemy("audit_jammer", "Audit Jammer", "Scramble", {"jam": true, "rewrite": true})]
	)
	var h1: Dictionary = m1.get_hero_states()[0]
	var e1: Dictionary = m1.get_enemy_states()[0]
	e1["selected_target_id"] = str(h1["id"])
	h1["last_die_value"] = 14
	m1.call("_freeze_die_state", h1, 1)
	m1.resolve_round({}, {str(e1["id"]): AUDIT_ROLL}, DiceManager.new())
	var hero_immune: bool = int(h1.get("jam_cap", 0)) == 0 and not bool(h1.get("rewrite_pending", false))
	_expect_and_record("Regression / frozen hero die immune to Jam+Rewrite", "freeze", "true", str(hero_immune))

	# 2) Frozen ENEMY die is immune to hero Jam and Rewrite (other direction).
	var m2: CombatManager = CombatManager.new()
	m2.setup_battle(
		[_make_unit("audit_hero", "Audit Hero", "Scramble", {"jam": true, "rewrite": true})],
		[_make_enemy("audit_enemy", "Audit Enemy")]
	)
	var h2: Dictionary = m2.get_hero_states()[0]
	var e2: Dictionary = m2.get_enemy_states()[0]
	h2["selected_target_id"] = str(e2["id"])
	e2["last_die_value"] = 14
	m2.call("_freeze_die_state", e2, 1)
	m2.resolve_round({str(h2["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var enemy_immune: bool = int(e2.get("jam_cap", 0)) == 0 and not bool(e2.get("rewrite_pending", false))
	_expect_and_record("Regression / frozen enemy die immune to Jam+Rewrite", "freeze", "true", str(enemy_immune))

	# 3) Frozen die is immune to Hijack: a frozen hijacker keeps its crusted
	# face instead of copying the squad's highest die.
	var m3: CombatManager = CombatManager.new()
	m3.setup_battle(
		[_make_unit("audit_hero", "Audit Hero", "Noop", {})],
		[_make_enemy("audit_hijacker", "Audit Hijacker", "Claw", {"dmg": 9})]
	)
	var h3: Dictionary = m3.get_hero_states()[0]
	var e3: Dictionary = m3.get_enemy_states()[0]
	e3["selected_target_id"] = str(h3["id"])
	e3["hijack_pending"] = true
	e3["last_die_value"] = 5
	m3.call("_freeze_die_state", e3, 1)
	e3["die_freeze_repeat_this_round"] = true
	var hijack_rolls: Dictionary = {str(e3["id"]): 5}
	m3.resolve_round({str(h3["id"]): 20}, hijack_rolls, DiceManager.new())
	var hijack_blocked: bool = int(hijack_rolls.get(str(e3["id"]), 0)) == 5
	_expect_and_record("Regression / frozen die immune to Hijack", "freeze", "true", str(hijack_blocked))

	# 4) Chained freeze: an ability that applies freeze can itself be repeated
	# by a freeze. The frozen freezer repeats its cast (target re-frozen), its
	# own repeat is spent, and every clock decrements — no infinite loop.
	var m4: CombatManager = CombatManager.new()
	m4.setup_battle(
		[_make_unit("audit_freezer", "Audit Freezer", "Flash Freeze", {"freezeEnemyDice": 1})],
		[_make_enemy("audit_enemy", "Audit Enemy")]
	)
	var h4: Dictionary = m4.get_hero_states()[0]
	var e4: Dictionary = m4.get_enemy_states()[0]
	h4["selected_target_id"] = str(e4["id"])
	h4["last_die_value"] = 10
	e4["last_die_value"] = 7
	m4.call("_freeze_die_state", h4, 1)
	h4["die_freeze_repeat_this_round"] = true
	m4.resolve_round({str(h4["id"]): 10}, {}, DiceManager.new())
	var chain_round1: bool = int(e4.get("die_freeze_turns", 0)) == 1 and int(h4.get("die_freeze_turns", 0)) == 0
	e4["die_freeze_repeat_this_round"] = true
	m4.resolve_round({}, {str(e4["id"]): 7}, DiceManager.new())
	var chain_round2: bool = int(e4.get("die_freeze_turns", 0)) == 0
	_expect_and_record(
		"Regression / chained freeze repeats then unwinds", "freeze",
		"true/true", "%s/%s" % [str(chain_round1), str(chain_round2)]
	)

	# 5) Enemy AI freeze targets the hero with the LOWEST revealed die —
	# deterministic, independent of the damage target.
	var m5: CombatManager = CombatManager.new()
	m5.setup_battle(
		[
			_make_unit("audit_hero_a", "Audit Hero A", "Noop", {}),
			_make_unit("audit_hero_b", "Audit Hero B", "Noop", {}),
		],
		[_make_enemy("audit_freezer_enemy", "Audit Freezer Enemy", "Cold Snap", {"freezeEnemyDice": 1})]
	)
	var ha: Dictionary = m5.get_hero_states()[0]
	var hb: Dictionary = m5.get_hero_states()[1]
	var e5: Dictionary = m5.get_enemy_states()[0]
	e5["selected_target_id"] = str(ha["id"])
	m5.resolve_round(
		{str(ha["id"]): 15, str(hb["id"]): 3},
		{str(e5["id"]): AUDIT_ROLL},
		DiceManager.new(),
		{},
		{str(ha["id"]): 15, str(hb["id"]): 3}
	)
	var lowest_frozen: bool = int(hb.get("die_freeze_turns", 0)) == 1 and int(ha.get("die_freeze_turns", 0)) == 0
	_expect_and_record("Regression / enemy freeze picks lowest revealed hero die", "freezeEnemyDice", "true", str(lowest_frozen))

	# 6) freezeAnyDice on an ALLY: the ally's die crusts at its face and the
	# ally acts again on that result next round (freezing a good roll on
	# purpose is the point of the any-target rule).
	var m6: CombatManager = CombatManager.new()
	m6.setup_battle(
		[
			_make_unit("audit_cryo", "Audit Cryo", "Cryo Lock", {"freezeAnyDice": 1}),
			_make_unit("audit_striker", "Audit Striker", "Strike", {"dmg": 5}),
		],
		[_make_enemy("audit_enemy", "Audit Enemy")]
	)
	var cryo: Dictionary = m6.get_hero_states()[0]
	var ally: Dictionary = m6.get_hero_states()[1]
	var e6: Dictionary = m6.get_enemy_states()[0]
	cryo["selected_target_id"] = str(ally["id"])
	ally["selected_target_id"] = str(e6["id"])
	ally["last_die_value"] = 12
	var e6_hp0: int = int(e6["current_hp"])
	m6.resolve_round({str(cryo["id"]): AUDIT_ROLL, str(ally["id"]): 12}, {}, DiceManager.new())
	var ally_frozen: bool = int(ally.get("die_freeze_turns", 0)) == 1 and int(ally.get("frozen_die_value", 0)) == 12
	var hit_once: bool = int(e6["current_hp"]) == e6_hp0 - 5
	ally["selected_target_id"] = str(e6["id"])
	ally["die_freeze_repeat_this_round"] = true
	m6.resolve_round({str(ally["id"]): 12}, {}, DiceManager.new())
	var repeated: bool = int(e6["current_hp"]) == e6_hp0 - 10 and int(ally.get("die_freeze_turns", 0)) == 0
	_expect_and_record(
		"Regression / freezeAnyDice freezes an ally who repeats the result", "freezeAnyDice",
		"true/true/true", "%s/%s/%s" % [str(ally_frozen), str(hit_once), str(repeated)]
	)


# Instance timers (per Kev 2026-07-06): buff/DoT applications are independent
# instances — summed value, own clocks, no refresh-to-max.
func _run_instance_timer_regressions() -> void:
	# REQUIRED case from the ruling: +3 for 2 turns cast turn 1, +5 for 2 turns
	# cast turn 2 → turn 2 total +8, turn 3 total +5, turn 4 zero.
	var m: CombatManager = CombatManager.new()
	m.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [_make_enemy("audit_enemy", "Audit Enemy")])
	var h: Dictionary = m.get_hero_states()[0]
	m.apply_item_roll_buff(h, 3, 2)
	var t1_total: int = int(m.get_roll_modifier_totals(h)["roll_buff"])
	m.resolve_round({}, {}, DiceManager.new())
	m.apply_item_roll_buff(h, 5, 2)
	var t2_total: int = int(m.get_roll_modifier_totals(h)["roll_buff"])
	m.resolve_round({}, {}, DiceManager.new())
	var t3_total: int = int(m.get_roll_modifier_totals(h)["roll_buff"])
	m.resolve_round({}, {}, DiceManager.new())
	var t4_total: int = int(m.get_roll_modifier_totals(h)["roll_buff"])
	_expect_and_record(
		"Regression / roll buff instances (required: 3, 8, 5, 0)", "rollBuffInstances",
		"3/8/5/0", "%d/%d/%d/%d" % [t1_total, t2_total, t3_total, t4_total]
	)

	# Burn instances: 4-burn/3t and 2-burn/1t applied the same round tick as
	# 6 together, then the short one expires while the long one keeps ticking
	# 4s on its own clock.
	var bm: CombatManager = CombatManager.new()
	bm.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [_make_enemy("audit_burn", "Audit Burn", "Noop", {})])
	var be: Dictionary = bm.get_enemy_states()[0]
	be["max_hp"] = 1000
	be["current_hp"] = 1000
	bm.apply_item_burn(be, 4, 3)
	bm.apply_item_burn(be, 2, 1)
	var ticks: Array[int] = []
	var prev_hp: int = int(be["current_hp"])
	for _round in range(5):
		bm.resolve_round({}, {}, DiceManager.new())
		ticks.append(prev_hp - int(be["current_hp"]))
		prev_hp = int(be["current_hp"])
	_expect_and_record(
		"Regression / burn instances tick on independent clocks", "burnInstances",
		"[0, 6, 4, 4, 0]", str(ticks)
	)


func _run_down_cleanup_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Noop", {})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy")
	manager.setup_battle([hero_unit], [enemy_unit])
	var hero: Dictionary = manager.get_hero_states()[0]
	hero["shield"] = 5
	hero["shield_stacks"] = [{"amt": 5, "skip_next_tick": false}]
	hero["burn"] = 3
	hero["burn_turns"] = 2
	hero["rfe_stacks"] = [{"amt": 2, "turns_left": 1, "skip_next_tick": false}]
	hero["roll_buff"] = 2
	hero["roll_buff_turns"] = 1
	hero["cloaked"] = true
	hero["die_freeze_turns"] = 1
	hero["rampage_charges"] = 1
	hero["warded"] = true
	hero["taunting"] = true
	manager.call("_clear_active_statuses_for_down_state", hero)
	var ok: bool = (
		int(hero["shield"]) == 0
		and int(hero["burn"]) == 0
		and int(hero["roll_buff"]) == 0
		and not bool(hero["cloaked"])
		and int(hero["die_freeze_turns"]) == 0
		and int(hero["rampage_charges"]) == 0
		and not bool(hero["warded"])
		and not bool(hero["taunting"])
	)
	if ok:
		_record_pass("Regression / down clears active statuses", "cleanup")
	else:
		_record_failure("Regression / down clears active statuses", "cleanup", "all active statuses cleared", "state=%s" % str(_snapshot_state(hero)))


func _run_summon_slot_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var squad: Array = []
	for i in range(3):
		squad.append(_make_enemy("audit_enemy_%d" % i, "Audit Enemy %d" % i))
	manager.setup_battle([], squad)
	var states: Array = manager.get_enemy_states()
	states[1]["dead"] = true
	states[1]["current_hp"] = 0

	var summon_unit: EnemyData = _make_enemy("audit_summon", "Audit Summon")
	var inject_result: Dictionary = manager.inject_enemy(summon_unit)
	var replaced_ok: bool = (
		not inject_result.is_empty()
		and int(inject_result.get("slot_index", -1)) == 1
		and manager.get_enemy_states().size() == 3
		and not bool(manager.get_enemy_states()[1].get("dead", false))
	)
	if replaced_ok:
		_record_pass("Regression / summon replaces dead slot", "summon")
	else:
		_record_failure(
			"Regression / summon replaces dead slot",
			"summon",
			"inject at dead index 1 without growing array",
			"slot=%s size=%d dead=%s" % [str(inject_result.get("slot_index", -1)), manager.get_enemy_states().size(), str(manager.get_enemy_states()[1].get("dead", true))]
		)

	var full_manager: CombatManager = CombatManager.new()
	full_manager.setup_battle([], squad)
	if full_manager.inject_enemy(summon_unit).is_empty():
		_record_pass("Regression / summon blocked at living cap", "summon")
	else:
		_record_failure("Regression / summon blocked at living cap", "summon", "blocked with 3 living", "inject succeeded")


# fix-1.1: execute a real-data summon end to end — a smart summoner's overload
# on a natural 20 must emit a summon event whose name resolves to an existing
# dumb unit def, and injecting that unit must add it to the field. This is the
# full battle_scene._process_summon_events contract minus the card rebuild.
func _run_summon_end_to_end_regression() -> void:
	var scribe: EnemyData = DataManager.get_enemy_by_display_name("Checksum Scribe") as EnemyData
	if scribe == null:
		_record_failure("Regression / summon end-to-end", "summon", "Checksum Scribe def exists", "missing")
		return
	if scribe.ai_type != "smart" or not scribe.can_summon_elite:
		_record_failure("Regression / summon end-to-end", "summon", "Scribe smart + summonElite", "ai=%s summonElite=%s" % [scribe.ai_type, str(scribe.can_summon_elite)])
		return
	var manager: CombatManager = CombatManager.new()
	manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [scribe])
	var scribe_state: Dictionary = manager.get_enemy_states()[0]
	var scribe_id: String = str(scribe_state["id"])
	var hero_state: Dictionary = manager.get_hero_states()[0]
	seed(20260705)
	var summon_event: Dictionary = {}
	for _attempt in range(200):
		var result: Dictionary = manager.resolve_round({}, {scribe_id: 20}, DiceManager.new(), {scribe_id: 20})
		for event_variant in result.get("events", []):
			if str((event_variant as Dictionary).get("type", "")) == "summon":
				summon_event = event_variant
				break
		if not summon_event.is_empty():
			break
		# The forced overloads would otherwise end the fight; keep both sides up.
		hero_state["dead"] = false
		hero_state["current_hp"] = int(hero_state["max_hp"])
		scribe_state["dead"] = false
		scribe_state["current_hp"] = int(scribe_state["max_hp"])
	if summon_event.is_empty():
		_record_failure("Regression / summon end-to-end", "summon", "summon event within 200 forced nat-20 overloads", "none emitted")
		return
	var summon_name: String = str(summon_event.get("summon_name", ""))
	var base_enemy: EnemyData = DataManager.get_enemy_by_display_name(summon_name) as EnemyData
	if base_enemy == null:
		_record_failure("Regression / summon end-to-end", "summon", "'%s' resolves to a unit def" % summon_name, "not found")
		return
	if base_enemy.ai_type != "dumb":
		_record_failure("Regression / summon end-to-end", "summon", "'%s' is a dumb unit" % summon_name, "ai=%s" % base_enemy.ai_type)
		return
	var living_before: int = 0
	for state_variant in manager.get_enemy_states():
		if not bool((state_variant as Dictionary).get("dead", false)):
			living_before += 1
	var inject_result: Dictionary = manager.inject_enemy(base_enemy.duplicate(true) as EnemyData)
	var living_after: int = 0
	for state_variant in manager.get_enemy_states():
		if not bool((state_variant as Dictionary).get("dead", false)):
			living_after += 1
	if inject_result.is_empty() or living_after != living_before + 1:
		_record_failure("Regression / summon end-to-end", "summon", "injected unit added to field", "inject=%s living %d->%d" % [str(not inject_result.is_empty()), living_before, living_after])
		return
	_record_pass("Regression / summon end-to-end (%s -> %s)" % [scribe.display_name, summon_name], "summon")

	# Code-constant spawn names must resolve too (the Brood spawn goes through
	# the same display-name lookup as data-driven summons).
	var brood: EnemyData = DataManager.get_enemy_by_display_name(CombatManager.BROOD_SPAWN_NAME) as EnemyData
	if brood != null and brood.ai_type == "dumb":
		_record_pass("Regression / brood spawn name resolves", "summon")
	else:
		_record_failure("Regression / brood spawn name resolves", "summon", "dumb unit def for '%s'" % CombatManager.BROOD_SPAWN_NAME, "null or non-dumb")


# Instance timers (per Kev 2026-07-06, supersedes fix-1.2's refresh-to-max):
# every erb cast is its own instance with its own clock; the effective value is
# the SUM of live instances; each loses a turn at every round-end tick. A 2t
# erb cast in round 1 covers round 2's reveal and is gone after round 2's tick.
func _run_enemy_roll_buff_expiry_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var buffer_unit: EnemyData = _make_enemy("audit_buffer", "Audit Buffer", "Rally", {"erb": 2, "erbT": 1})
	manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [buffer_unit])
	var buffer_state: Dictionary = manager.get_enemy_states()[0]
	var buffer_id: String = str(buffer_state["id"])

	# Round 1: enemy casts the 1t (effective) buff — it skips the cast-round tick.
	manager.resolve_round({}, {buffer_id: 10}, DiceManager.new())
	var active_after_cast: bool = int(buffer_state.get("roll_buff", 0)) == 2
	# Round 2: no re-cast; the instance covers this round and expires at its tick.
	manager.resolve_round({}, {}, DiceManager.new())
	var gone_after: bool = int(buffer_state.get("roll_buff", 0)) == 0 and (buffer_state.get("roll_buff_stacks", []) as Array).is_empty()
	_expect_and_record(
		"Regression / enemy 2t roll buff expires on its own clock", "rollBuffExpiry",
		"cast/expired = true/true",
		"cast/expired = %s/%s" % [str(active_after_cast), str(gone_after)]
	)

	# Independent instances, no refresh-to-max: re-casting does NOT extend the
	# first instance's clock. Cast r1 + re-cast r2: after r2's tick only the
	# second instance survives (+2 at 1t); after r3's tick it too is gone —
	# under the old refresh model the buff would still read +2 after r3.
	var stack_manager: CombatManager = CombatManager.new()
	stack_manager.setup_battle([_make_unit("audit_hero", "Audit Hero", "Noop", {})], [buffer_unit])
	var stack_state: Dictionary = stack_manager.get_enemy_states()[0]
	var stack_id: String = str(stack_state["id"])
	stack_manager.resolve_round({}, {stack_id: 10}, DiceManager.new())
	stack_manager.resolve_round({}, {stack_id: 10}, DiceManager.new())
	var after_recast_round: int = int(stack_state.get("roll_buff", 0))
	stack_manager.resolve_round({}, {}, DiceManager.new())
	var after_next_round: int = int(stack_state.get("roll_buff", 0))
	_expect_and_record(
		"Regression / enemy roll buff re-cast keeps independent clocks", "rollBuffExpiry",
		"2 then 0", "%d then %d" % [after_recast_round, after_next_round]
	)


# fix-1.3: structural band + pip coverage. For every unit (hero, evolution,
# enemy): every roll 1-20 must map to exactly one ability, and every ability's
# raw must parse to at least one pip through the same renderer battle uses.
func _run_band_coverage_audit() -> void:
	var problems: Array[String] = []
	for unit_id in DataManager.units.keys():
		var unit: UnitData = DataManager.get_unit(unit_id) as UnitData
		if unit == null:
			continue
		_collect_band_coverage_problems("hero %s" % unit_id, unit.dice_ranges, "hero", problems)
		for path_variant in unit.evolution_paths:
			var path: Dictionary = path_variant
			_collect_band_coverage_problems(
				"evo %s/%s" % [unit_id, str(path.get("name", "?"))],
				path.get("abilities", []), "hero", problems
			)
	for enemy_id in DataManager.enemies.keys():
		var enemy: EnemyData = DataManager.get_enemy(enemy_id) as EnemyData
		if enemy == null:
			continue
		_collect_band_coverage_problems("enemy %s" % enemy_id, enemy.dice_ranges, "enemy", problems)

	if problems.is_empty():
		_record_pass("Structural / band + pip coverage (all units, rolls 1-20)", "bandCoverage")
	else:
		for problem in problems:
			_record_failure("Structural / band + pip coverage", "bandCoverage", "1 ability and >=1 pip per roll", problem)


func _collect_band_coverage_problems(owner: String, ranges: Array, side: String, problems: Array[String]) -> void:
	if ranges.is_empty():
		problems.append("%s: no ability ranges" % owner)
		return
	for roll in range(1, 21):
		var hits: int = 0
		for range_variant in ranges:
			var entry: Dictionary = range_variant
			if roll >= int(entry.get("min", 0)) and roll <= int(entry.get("max", 0)):
				hits += 1
		if hits != 1:
			problems.append("%s: roll %d maps to %d abilities" % [owner, roll, hits])
	for range_variant in ranges:
		var entry: Dictionary = range_variant
		var pips: Array = EffectPip.effects_from_ability_raw(entry.get("raw", {}), side)
		if pips.is_empty():
			problems.append("%s: '%s' (%s) parses to zero pips [eff=%s]" % [
				owner, str(entry.get("ability_name", "?")), str(entry.get("zone", "?")),
				str(entry.get("description", ""))
			])


func _run_gear_lifesteal_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Strike", {"dmg": 20})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy")
	manager.setup_battle([hero_unit], [enemy_unit])
	manager.setup_gear({"audit_hero": ["siphon_loop"]})
	var hero: Dictionary = manager.get_hero_states()[0]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	enemy["current_hp"] = 20
	enemy["max_hp"] = 20
	hero["current_hp"] = 90
	hero["selected_target_id"] = str(enemy["id"])
	var hero_hp_before: int = int(hero["current_hp"])
	manager.resolve_round({"audit_hero": AUDIT_ROLL}, {}, DiceManager.new())
	var expected_heal: int = 4
	var ok: bool = int(hero["current_hp"]) == hero_hp_before + expected_heal and bool(enemy["dead"])
	if ok:
		_record_pass("Regression / gear lifesteal", "lifesteal")
	else:
		_record_failure(
			"Regression / gear lifesteal",
			"lifesteal",
			"20 damage kill leeches 20%% (4 HP) via Siphon Loop",
			"hero_hp=%d enemy_dead=%s" % [int(hero["current_hp"]), str(enemy["dead"])]
		)


func _run_gear_shield_pierce_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Strike", {"dmg": 10})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy")
	manager.setup_battle([hero_unit], [enemy_unit])
	manager.setup_gear({"audit_hero": ["breach_tip"]})
	var hero: Dictionary = manager.get_hero_states()[0]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	enemy["shield_stacks"] = [{"amt": 8, "skip_next_tick": false}]
	enemy["shield"] = 8
	hero["selected_target_id"] = str(enemy["id"])
	manager.resolve_round({"audit_hero": AUDIT_ROLL}, {}, DiceManager.new())
	# 10 dmg vs 8 shield with pierce 5: 5 pierced, 3 absorbed, 7 HP lost → 93 HP
	var ok: bool = int(enemy["current_hp"]) == 93 and int(enemy["shield"]) == 0
	if ok:
		_record_pass("Regression / gear shieldPierce", "shieldPierce")
	else:
		_record_failure(
			"Regression / gear shieldPierce",
			"shieldPierce",
			"10 dmg pierces 5 of 8 shield and deals 7 HP (93 remaining)",
			"enemy_hp=%d shield=%d" % [int(enemy["current_hp"]), int(enemy["shield"])]
		)


func _run_relic_ally_death_heal_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var hero_a: UnitData = _make_unit("audit_hero_a", "Audit Hero A", "Noop", {})
	var hero_b: UnitData = _make_unit("audit_hero_b", "Audit Hero B", "Noop", {})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy", "Strike", {"dmg": 100})
	manager.setup_battle([hero_a, hero_b], [enemy_unit])
	manager.setup_relics(["martyrdomProtocol"])
	var victim: Dictionary = manager.get_hero_states()[0]
	var survivor: Dictionary = manager.get_hero_states()[1]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	survivor["current_hp"] = 90
	enemy["selected_target_id"] = str(victim["id"])
	manager.resolve_round({}, {"audit_enemy#1": AUDIT_ROLL}, DiceManager.new(), {"audit_enemy#1": AUDIT_ROLL})
	# Vengeance Protocol: the survivor's next roll is a forced 20.
	var ok: bool = bool(victim["dead"]) and bool(survivor.get("forced_20_pending", false))
	if ok:
		_record_pass("Regression / relic vengeanceProtocol", "vengeanceProtocol")
	else:
		_record_failure(
			"Regression / relic vengeanceProtocol",
			"vengeanceProtocol",
			"survivor primed for a forced 20 when an ally dies",
			"victim_dead=%s primed=%s" % [str(victim["dead"]), str(survivor.get("forced_20_pending", false))]
		)


# Battle-start relics that write per-unit state the compact pips + roll math read:
# signalJam (perm_rfe), coordinatedStrike (perm_roll_buff), plagueProtocol (burn),
# entropyLeak (max-HP escalation).
func _run_relic_battle_start_state_regression() -> void:
	var mgr: CombatManager = CombatManager.new()
	var hero: UnitData = _make_unit("audit_hero", "Audit Hero", "Noop", {})
	var enemy: EnemyData = _make_enemy("audit_enemy", "Audit Enemy", "Noop", {})
	mgr.setup_battle([hero], [enemy])
	var h: Dictionary = mgr.get_hero_states()[0]
	var e: Dictionary = mgr.get_enemy_states()[0]
	mgr.setup_relics(["signalJam", "coordinatedStrike", "plagueProtocol", "entropyLeak"])
	mgr.apply_battle_start_relic_effects(6)  # battle_index 6 = battle 7 -> entropyLeak: spawn at 85% HP

	_expect_and_record("Regression / relic signalJam perm_rfe", "enemyStartRfe", "2", str(int(e.get("perm_rfe", 0))))
	_expect_and_record("Regression / relic coordinatedStrike perm_roll_buff", "heroStartRollBuff", "2", str(int(h.get("perm_roll_buff", 0))))
	# Those permanent modifiers must flow into the authoritative roll totals that the compact
	# roll pip mirrors (the bug this guards: pip ignored perm_rfe / perm_roll_buff).
	var enemy_totals: Dictionary = mgr.get_roll_modifier_totals(e)
	var hero_totals: Dictionary = mgr.get_roll_modifier_totals(h)
	_expect_and_record("Regression / relic signalJam roll total", "enemyStartRfe", "2", str(int(enemy_totals.get("roll_rfe", 0))))
	_expect_and_record("Regression / relic coordinatedStrike roll total", "heroStartRollBuff", "2", str(int(hero_totals.get("roll_buff", 0))))
	_expect_and_record("Regression / relic plagueProtocol burn", "enemyBurnPermanent", "3", str(int(e.get("burn", 0))))
	_expect_and_record("Regression / relic entropyLeak spawn hp", "enemyHpEscalation", str(int(e["max_hp"]) * 85 / 100), str(int(e["current_hp"])))


# Per-enemy-turn aura relics: bulwarkAura (hero shield), naniteField (hero heal),
# gravityWell (enemy damage).
func _run_relic_per_turn_aura_regression() -> void:
	var mgr: CombatManager = CombatManager.new()
	var hero: UnitData = _make_unit("audit_hero", "Audit Hero", "Noop", {})
	var enemy: EnemyData = _make_enemy("audit_enemy", "Audit Enemy", "Noop", {})
	mgr.setup_battle([hero], [enemy])
	var h: Dictionary = mgr.get_hero_states()[0]
	var e: Dictionary = mgr.get_enemy_states()[0]
	h["current_hp"] = int(h["max_hp"]) - 10  # leave headroom for the naniteField heal
	var hero_hp_before: int = int(h["current_hp"])
	var enemy_hp_before: int = int(e["current_hp"])
	mgr.setup_relics(["bulwarkAura", "naniteField", "gravityWell"])
	mgr.apply_enemy_turn_start_relic_effects()

	_expect_and_record("Regression / relic bulwarkAura shield", "heroShieldPerTurn", "3", str(int(h.get("shield", 0))))
	_expect_and_record("Regression / relic naniteField heal", "heroHealPerTurn", str(hero_hp_before + 3), str(int(h["current_hp"])))
	_expect_and_record("Regression / relic gravityWell dmg", "auraEnemyDmg", str(enemy_hp_before - 2), str(int(e["current_hp"])))


# Tutorial rig must stay unlosable AND land the win exactly on turn 2: the 28-HP Scrap Drone
# survives turn 1's rigged assignments and dies on turn 2 (nudged Pulse=12 → Plasma Lance).
func _run_tutorial_kill_math_regression() -> void:
	var pulse: UnitData = DataManager.get_unit("pulse") as UnitData
	var combat: UnitData = DataManager.get_unit("combat") as UnitData
	var ghost: UnitData = DataManager.get_unit("ghost") as UnitData
	var scrap: EnemyData = DataManager.get_enemy_by_display_name("Scrap Drone") as EnemyData
	if pulse == null or combat == null or ghost == null or scrap == null:
		_record_failure("Tutorial / kill math", "tutorial", "real data present", "missing data")
		return
	var enemy_unit: EnemyData = scrap.duplicate(true)
	enemy_unit.max_hp = 28
	var mgr: CombatManager = CombatManager.new()
	mgr.setup_battle([pulse, combat, ghost], [enemy_unit])
	var enemy: Dictionary = mgr.get_enemy_states()[0]
	var enemy_id: String = str(enemy["id"])
	_tutorial_resolve_turn(mgr, enemy_id, {"pulse": 5, "combat": 1, "ghost": 3})
	var hp_after_t1: int = int(enemy["current_hp"])
	var dead_t1: bool = bool(enemy["dead"])
	if not dead_t1:
		_tutorial_resolve_turn(mgr, enemy_id, {"pulse": 12, "combat": 1, "ghost": 3})
	var dead_t2: bool = bool(enemy["dead"])
	if (not dead_t1) and hp_after_t1 > 0 and dead_t2:
		_record_pass("Tutorial / kill math", "tutorial")
	else:
		_record_failure("Tutorial / kill math", "tutorial", "survive T1 (>0), die T2",
			"t1_hp=%d dead_t1=%s dead_t2=%s" % [hp_after_t1, str(dead_t1), str(dead_t2)])


func _tutorial_resolve_turn(mgr: CombatManager, enemy_id: String, rolls_by_unit: Dictionary) -> void:
	var hero_rolls: Dictionary = {}
	for hero_state in mgr.get_hero_states():
		var unit: Object = hero_state.get("unit") as Object
		var uid: String = str(unit.id) if unit != null else ""
		hero_state["selected_target_id"] = enemy_id
		if rolls_by_unit.has(uid):
			hero_rolls[str(hero_state["id"])] = int(rolls_by_unit[uid])
	mgr.resolve_round(hero_rolls, {enemy_id: 6}, DiceManager.new())


func _run_revive_pct_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var actor_unit: UnitData = _make_unit("audit_actor", "Audit Actor", "Surge Revive", {
		"revive": true,
		"healTgt": true,
		"revivePct": 70,
	})
	var ally_unit: UnitData = _make_unit("audit_ally_a", "Audit Ally A", "Noop", {})
	manager.setup_battle([actor_unit, ally_unit], [])
	var actor: Dictionary = manager.get_hero_states()[0]
	var ally: Dictionary = manager.get_hero_states()[1]
	ally["dead"] = true
	ally["current_hp"] = 0
	actor["selected_target_id"] = str(ally["id"])
	manager.resolve_round({str(actor["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var expected_hp: int = int(ally["max_hp"]) * 70 / 100
	var ok: bool = not bool(ally["dead"]) and int(ally["current_hp"]) == expected_hp
	if ok:
		_record_pass("Regression / revivePct", "revivePct")
	else:
		_record_failure(
			"Regression / revivePct",
			"revivePct",
			"selected fallen ally revived at 70%% HP",
			"dead=%s hp=%d expected=%d" % [str(ally["dead"]), int(ally["current_hp"]), expected_hp]
		)


func _run_revive_all_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var actor_unit: UnitData = _make_unit("audit_actor", "Audit Actor", "Mass Revival", {
		"reviveAll": true,
		"revivePct": 30,
	})
	var ally_a_unit: UnitData = _make_unit("audit_ally_a", "Audit Ally A", "Noop", {})
	var ally_b_unit: UnitData = _make_unit("audit_ally_b", "Audit Ally B", "Noop", {})
	manager.setup_battle([actor_unit, ally_a_unit, ally_b_unit], [])
	var ally_a: Dictionary = manager.get_hero_states()[1]
	var ally_b: Dictionary = manager.get_hero_states()[2]
	ally_a["dead"] = true
	ally_a["current_hp"] = 0
	ally_b["dead"] = true
	ally_b["current_hp"] = 0
	manager.resolve_round({"audit_actor": AUDIT_ROLL}, {}, DiceManager.new())
	var expected_hp: int = int(ally_a["max_hp"]) * 30 / 100
	var ok: bool = (
		not bool(ally_a["dead"])
		and not bool(ally_b["dead"])
		and int(ally_a["current_hp"]) == expected_hp
		and int(ally_b["current_hp"]) == expected_hp
	)
	if ok:
		_record_pass("Regression / reviveAll", "reviveAll")
	else:
		_record_failure(
			"Regression / reviveAll",
			"reviveAll",
			"all fallen allies revived at 30%% HP",
			"ally_a dead=%s hp=%d ally_b dead=%s hp=%d expected=%d" % [
				str(ally_a["dead"]), int(ally_a["current_hp"]),
				str(ally_b["dead"]), int(ally_b["current_hp"]),
				expected_hp,
			]
		)


func _run_gear_first_ability_echo_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Strike", {"dmg": 12})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy")
	manager.setup_battle([hero_unit], [enemy_unit])
	manager.setup_gear({"audit_hero": ["echo_matrix"]})
	var hero: Dictionary = manager.get_hero_states()[0]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	hero["selected_target_id"] = str(enemy["id"])
	var enemy_hp_before: int = int(enemy["current_hp"])
	manager.resolve_round({"audit_hero": AUDIT_ROLL}, {}, DiceManager.new())
	var ok: bool = int(enemy["current_hp"]) == enemy_hp_before - 24 and bool(hero.get("gear_first_ability_echo_used", false))
	if ok:
		_record_pass("Regression / gear firstAbilityEcho", "firstAbilityEcho")
	else:
		_record_failure(
			"Regression / gear firstAbilityEcho",
			"firstAbilityEcho",
			"12 dmg ability echoes once for 24 total HP loss",
			"enemy_hp=%d echo_used=%s" % [int(enemy["current_hp"]), str(hero.get("gear_first_ability_echo_used", false))]
		)


func _run_gear_heal_shield_bonus_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var healer_unit: UnitData = _make_unit("audit_healer", "Audit Healer", "Ally Heal", {"heal": 6, "healTgt": true})
	var ally_unit: UnitData = _make_unit("audit_ally", "Audit Ally", "Noop", {})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy")
	manager.setup_battle([healer_unit, ally_unit], [enemy_unit])
	manager.setup_gear({"audit_healer": ["triage_gel"]})
	var healer: Dictionary = manager.get_hero_states()[0]
	var ally: Dictionary = manager.get_hero_states()[1]
	ally["current_hp"] = 40
	healer["selected_target_id"] = str(ally["id"])
	var result: Dictionary = manager.resolve_round({"audit_healer": AUDIT_ROLL}, {}, DiceManager.new())
	# One-round shields: the bonus shield is granted mid-round (covering this
	# round's enemy phase) and expires at the round-end tick — assert the grant
	# event rather than post-round state.
	var events: Array = result.get("events", [])
	var ok: bool = int(ally["current_hp"]) == 46 and _has_event(events, "shield", 3, "hero")
	if ok:
		_record_pass("Regression / gear healShieldBonus", "healShieldBonus")
	else:
		_record_failure(
			"Regression / gear healShieldBonus",
			"healShieldBonus",
			"ally-targeted heal also grants a 3-shield event this round",
			"ally_hp=%d events=%s" % [int(ally["current_hp"]), str(events)]
		)


func _run_gear_protocol_on_kill_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Strike", {"dmg": 100})
	var basic_enemy: EnemyData = _make_enemy("audit_basic", "Audit Basic")
	basic_enemy.enemy_type = "drone"
	var boss_enemy: EnemyData = _make_enemy("audit_boss", "Audit Boss")
	boss_enemy.enemy_type = "boss"
	manager.setup_battle([hero_unit], [basic_enemy])
	manager.setup_gear({"audit_hero": ["bounty_chip"]})
	var hero: Dictionary = manager.get_hero_states()[0]
	var basic: Dictionary = manager.get_enemy_states()[0]
	hero["selected_target_id"] = str(basic["id"])
	manager.resolve_round({"audit_hero": AUDIT_ROLL}, {}, DiceManager.new())
	var basic_grant: int = manager.take_pending_protocol_grants()

	manager = CombatManager.new()
	manager.setup_battle([hero_unit], [boss_enemy])
	manager.setup_gear({"audit_hero": ["bounty_chip"]})
	hero = manager.get_hero_states()[0]
	var boss: Dictionary = manager.get_enemy_states()[0]
	hero["selected_target_id"] = str(boss["id"])
	manager.resolve_round({"audit_hero": AUDIT_ROLL}, {}, DiceManager.new())
	var boss_grant: int = manager.take_pending_protocol_grants()

	var ok: bool = basic_grant == 1 and boss_grant == 0
	if ok:
		_record_pass("Regression / gear protocolOnKill", "protocolOnKill")
	else:
		_record_failure(
			"Regression / gear protocolOnKill",
			"protocolOnKill",
			"+1 Protocol on basic kill only",
			"basic_grant=%d boss_grant=%d" % [basic_grant, boss_grant]
		)


func _run_gear_protocol_on_kill_any_regression() -> void:
	# The protocolOnKillAny handler survives (no pkg3.4 gear uses it); exercise
	# it via the state flag directly since Apex Collector was removed.
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Strike", {"dmg": 100})
	var boss_enemy: EnemyData = _make_enemy("audit_boss", "Audit Boss")
	boss_enemy.enemy_type = "boss"
	manager.setup_battle([hero_unit], [boss_enemy])
	var hero: Dictionary = manager.get_hero_states()[0]
	hero["gear_protocol_on_kill_any"] = 1
	var boss: Dictionary = manager.get_enemy_states()[0]
	hero["selected_target_id"] = str(boss["id"])
	manager.resolve_round({"audit_hero": AUDIT_ROLL}, {}, DiceManager.new())
	var grant: int = manager.take_pending_protocol_grants()
	var ok: bool = grant == 1 and bool(boss["dead"])
	if ok:
		_record_pass("Regression / gear protocolOnKillAny", "protocolOnKillAny")
	else:
		_record_failure(
			"Regression / gear protocolOnKillAny",
			"protocolOnKillAny",
			"+1 Protocol when killing a boss",
			"grant=%d boss_dead=%s" % [grant, str(boss["dead"])]
		)


func _run_relic_crit_resolve_twice_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Overload Strike", {"dmg": 9})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy")
	manager.setup_battle([hero_unit], [enemy_unit])
	manager.setup_relics(["overloadLoop"])
	var hero: Dictionary = manager.get_hero_states()[0]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	hero["selected_target_id"] = str(enemy["id"])
	var enemy_hp_before: int = int(enemy["current_hp"])
	manager.resolve_round({"audit_hero": 20}, {}, DiceManager.new(), {}, {"audit_hero": 20})
	var ok: bool = int(enemy["current_hp"]) == enemy_hp_before - 18
	if ok:
		_record_pass("Regression / relic critResolveTwice", "critResolveTwice")
	else:
		_record_failure(
			"Regression / relic critResolveTwice",
			"critResolveTwice",
			"natural 20 resolves 9 dmg ability twice (18 total)",
			"enemy_hp=%d delta=%d" % [int(enemy["current_hp"]), enemy_hp_before - int(enemy["current_hp"])]
		)


func _run_relic_rewards_no_common_regression() -> void:
	var snapshot: Dictionary = _snapshot_game_state()
	GameState.relics = ["curatedCache"]
	var found_common: bool = false
	for _attempt in range(40):
		var item_id: String = str(GameState.call("_pick_random_item_id", "consumable", []))
		if item_id == "":
			continue
		var item: ItemData = DataManager.get_item(item_id) as ItemData
		if item != null and str(item.rarity) == "common":
			found_common = true
			break
	_restore_game_state_snapshot(snapshot)
	if not found_common:
		_record_pass("Regression / relic rewardsNoCommon", "rewardsNoCommon")
	else:
		_record_failure(
			"Regression / relic rewardsNoCommon",
			"rewardsNoCommon",
			"reward picks exclude common consumables",
			"found common item in 40 rolls"
		)


func _run_relic_protocol_carryover_regression() -> void:
	var snapshot: Dictionary = _snapshot_game_state()
	GameState.save_protocol_carryover(7, 50)
	var carried: int = GameState.take_carried_protocol()
	_restore_game_state_snapshot(snapshot)
	var ok: bool = carried == 3
	if ok:
		_record_pass("Regression / relic protocolCarryover", "protocolCarryover")
	else:
		_record_failure(
			"Regression / relic protocolCarryover",
			"protocolCarryover",
			"50%% of 7 unspent Protocol carries over (3)",
			"carried=%d" % carried
		)


func _run_relic_battle_start_consumable_regression() -> void:
	var snapshot: Dictionary = _snapshot_game_state()
	GameState.consumables.clear()
	GameState.grant_battle_start_consumables(1)
	var granted: int = GameState.consumables.size()
	_restore_game_state_snapshot(snapshot)
	if granted == 1:
		_record_pass("Regression / relic battleStartConsumable", "battleStartConsumable")
	else:
		_record_failure(
			"Regression / relic battleStartConsumable",
			"battleStartConsumable",
			"grant_battle_start_consumables adds one consumable",
			"consumables=%d" % granted
		)


func _run_relic_revive_no_penalty_regression() -> void:
	var snapshot: Dictionary = _snapshot_game_state()
	GameState.relics = ["mercyProtocol"]
	var pct: int = GameState.get_revive_hp_pct(50)
	_restore_game_state_snapshot(snapshot)
	_expect_and_record("Regression / relic reviveNoPenalty", "reviveNoPenalty", "100", str(pct))


func _run_relic_low_hp_squad_roll_buff_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var hero_a_unit: UnitData = _make_unit("audit_hero_a", "Audit Hero A", "Noop", {})
	var hero_b_unit: UnitData = _make_unit("audit_hero_b", "Audit Hero B", "Noop", {})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy")
	manager.setup_battle([hero_a_unit, hero_b_unit], [enemy_unit])
	manager.setup_relics(["emergencySignal"])
	var hero_a: Dictionary = manager.get_hero_states()[0]
	var hero_b: Dictionary = manager.get_hero_states()[1]
	manager.call("_damage_state", hero_a, 51)
	var a_stacks: Array = hero_a.get("roll_buff_stacks", [])
	# Emergency Signal is future-shaping: stored `turns:1` = one effective turn
	# (skips the cast tick, shapes the next roll). Was `2` under the old off-by-one
	# encoding; decremented to 1 on 2026-07-13, behavior unchanged.
	var ok: bool = (
		int(hero_a.get("roll_buff", 0)) == 2
		and int(hero_b.get("roll_buff", 0)) == 2
		and a_stacks.size() == 1
		and int((a_stacks[0] as Dictionary).get("turns_left", 0)) == 1
	)
	if ok:
		_record_pass("Regression / relic lowHpSquadRollBuff", "lowHpSquadRollBuff")
	else:
		_record_failure(
			"Regression / relic lowHpSquadRollBuff",
			"lowHpSquadRollBuff",
			"first ally below 50%% HP grants a +2 roll instance to the squad",
			"hero_a buff=%d stacks=%s hero_b buff=%d" % [
				int(hero_a.get("roll_buff", 0)),
				str(a_stacks),
				int(hero_b.get("roll_buff", 0)),
			]
		)


func _run_relic_heal_grants_shield_all_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var hero_a_unit: UnitData = _make_unit("audit_hero_a", "Audit Hero A", "Self Heal", {"heal": 5})
	var hero_b_unit: UnitData = _make_unit("audit_hero_b", "Audit Hero B", "Noop", {})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy")
	manager.setup_battle([hero_a_unit, hero_b_unit], [enemy_unit])
	manager.setup_relics(["aegisField"])
	var hero_a: Dictionary = manager.get_hero_states()[0]
	var hero_b: Dictionary = manager.get_hero_states()[1]
	hero_a["current_hp"] = 50
	var result: Dictionary = manager.resolve_round({"audit_hero_a": AUDIT_ROLL}, {}, DiceManager.new())
	# One-round shields: assert the squad-wide grant events; the shields
	# themselves expire at the same round's end tick.
	var events: Array = result.get("events", [])
	var ok: bool = _count_events(events, "shield", "hero") >= 2
	if ok:
		_record_pass("Regression / relic healGrantsShieldAll", "healGrantsShieldAll")
	else:
		_record_failure(
			"Regression / relic healGrantsShieldAll",
			"healGrantsShieldAll",
			"any heal grants shield events to all living allies this round",
			"events=%s" % str(events)
		)


func _run_relic_protocol_on_item_use_regression() -> void:
	var battle_scene: Control = BATTLE_SCENE_SCRIPT.new() as Control
	if battle_scene == null:
		_record_failure("Regression / relic protocolOnItemUse", "protocolOnItemUse", "BattleScene script instantiates", "new() returned null")
		return
	battle_scene.combat_manager.setup_relics(["protocolOverride"])
	var override_pa = PROTOCOL_ACTIONS_SCRIPT.new()
	override_pa.setup(battle_scene)
	var cost: int = int(override_pa.call("_get_item_protocol_cost", null))
	override_pa.free()
	battle_scene.free()
	_expect_and_record("Regression / relic protocolOnItemUse", "protocolOnItemUse", "0", str(cost))


func _snapshot_game_state() -> Dictionary:
	return {
		"relics": GameState.relics.duplicate(),
		"consumables": GameState.consumables.duplicate(),
		"carried_protocol": GameState.carried_protocol,
	}


func _restore_game_state_snapshot(snapshot: Dictionary) -> void:
	GameState.relics = (snapshot.get("relics", []) as Array).duplicate()
	GameState.consumables = (snapshot.get("consumables", []) as Array).duplicate()
	GameState.carried_protocol = int(snapshot.get("carried_protocol", 0))


func _run_text_alignment_audits() -> void:
	var stale_patterns: Array[String] = [
		"Untargetable by enemies this turn",
		"Unit becomes untargetable",
		"Reflects a portion of damage taken",
	]
	var text_paths: Array[String] = [
		"res://scripts/battle/battle_scene.gd",
		"res://scripts/ui/ability_readout.gd",
		"res://scripts/ui/compact_unit_card.gd",
		"res://data/raw/heroes.data.json",
		"res://data/raw/enemies.data.json",
	]
	for path in text_paths:
		var text: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		for pattern in stale_patterns:
			if text.contains(pattern):
				_record_failure("Text alignment / stale phrase", path, "no stale phrase: %s" % pattern, "found")
			else:
				_record_pass("Text alignment / %s" % path.get_file(), "no stale %s" % pattern)

	# Status descriptions live in InspectResolver now (the long-press InspectPopup replaced the
	# old hover tooltips that used to carry this text in compact_unit_card). Canonical short
	# forms per the 2026-07-10 status-text trim (Kev: one short line per active effect).
	var status_text: String = FileAccess.get_file_as_string("res://scripts/ui/inspect_resolver.gd")
	_expect_and_record("Text alignment / inspect cloak text", "text", "contains cloak untargetable text", "contains cloak untargetable text" if status_text.contains("Can't be targeted; breaks on dealing damage.") else "missing")
	_expect_and_record("Text alignment / inspect ward text", "text", "contains ward block text", "contains ward block text" if status_text.contains("Blocks the next ability, then breaks.") else "missing")


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


func _make_enemy(id: String, display_name: String, ability_name: String = "Noop", raw: Dictionary = {}) -> EnemyData:
	var enemy: EnemyData = EnemyData.new()
	enemy.id = id
	enemy.display_name = display_name
	enemy.max_hp = 100
	enemy.dice_ranges = [_make_ability_entry(ability_name, raw)]
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
		"shield":
			actor["shield_stacks"] = []
			actor["shield"] = 0
		"shTgt":
			ally_a["shield_stacks"] = []
			ally_a["shield"] = 0
		"shieldLowest":
			ally_a["current_hp"] = 25
			ally_b["current_hp"] = 80
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
			# survive the round-end tick so the post-round assert can prove the
			# pierce didn't consume the shield
			enemy_a["shield_stacks"] = [{"amt": 25, "skip_next_tick": true}]
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
		"burn": int(state.get("burn", 0)),
		"burn_turns": int(state.get("burn_turns", 0)),
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
	var burn_amount: int = int(raw.get("burn", 0))
	var burn_turns: int = int(raw.get("burnT", 0))
	var rfe_amount: int = int(raw.get("rfe", 0))
	var rfe_turns: int = int(raw.get("rfT", 1))
	var roll_buff_amount: int = int(raw.get("rfm", 0))
	var roll_buff_turns: int = int(raw.get("rfmT", 1))
	var heal_amount: int = int(raw.get("heal", 0))
	var shield_amount: int = int(raw.get("shield", 0))

	match effect_field:
		"dmg", "dMin", "dMax":
			return _expect_int_delta(effect_field, damage_amount, before.enemy_a.hp - after.enemy_a.hp, "enemy HP loss")
		"burn":
			return _expect_int_delta(effect_field, burn_amount, after.enemy_a.burn, "enemy burn amount")
		"burnT":
			return _expect_int_delta(effect_field, burn_turns, after.enemy_a.burn_turns, "enemy burn turns")
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
		"shTgt":
			return _expect_bool(effect_field, _has_target_event(events, "shield", shield_amount, "hero", "audit_ally_a"), "shield on selected ally", "events=%s" % str(events))
		"shieldLowest":
			return _expect_bool(effect_field, _has_target_event(events, "shield", shield_amount, "hero", "audit_ally_a"), "shield on lowest HP ally", "events=%s" % str(events))
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
			# Freeze = repeat: the target's die crusts at its current face and
			# repeats on its next roll(s). Assert the freeze event carrying the
			# locked face (the repeat itself is covered by targeted regressions).
			return _expect_bool(effect_field, _has_event(events, "freeze", 9, "enemy"), "freeze event on selected enemy die (value 9)", "events=%s" % str(events))
		"freezeAllEnemyDice":
			return _expect_bool(effect_field, _count_events(events, "freeze", "enemy") >= 2, "freeze events on all enemy dice", "events=%s" % str(events))
		"taunt":
			# Single-target taunt (Build G ruling G-4): the taunt event lands on
			# the TAUNTED ENEMY (the lured unit carries the state and the chip),
			# no longer on the casting hero. Clears at the round-end tick
			# (NK-08), so the harness's post-round snapshot asserts the EVENT.
			return _expect_bool(effect_field, _has_event(events, "taunt", 0, "enemy"), "taunt event emitted on the taunted enemy", "events=%s" % str(events))
		"revive":
			var revive_pct: int = int(raw.get("revivePct", 50))
			var expected_hp: int = maxi(1, int(after.ally_a.max_hp) * revive_pct / 100)
			return _expect_bool(effect_field, not after.ally_a.dead and after.ally_a.hp == expected_hp, "selected fallen ally revived at %d%% HP" % revive_pct, "dead=%s hp=%d" % [str(after.ally_a.dead), after.ally_a.hp])

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


func _expect_and_record(ability_name: String, effect_field: String, expected: String, actual: String) -> void:
	if actual == expected:
		_record_pass(ability_name, effect_field)
	else:
		_record_failure(ability_name, effect_field, expected, actual)


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
