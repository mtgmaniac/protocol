@tool
class_name AbilityAudit
extends RefCounted

const HEROES_DATA_PATH := "res://data/raw/heroes.data.json"
const ENEMIES_DATA_PATH := "res://data/raw/enemies.data.json"
const BATTLE_SCENE_SCRIPT := preload("res://scripts/battle/battle_scene.gd")
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
	"dmgP2",
	"heal",
	"shield",
	"shieldP2",
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
	"curseDice",
	"enemySelfTaunt",
	"summonChance",
	"summonName",
]

# Data-driven effect audit coverage: every field here must appear on at least
# one hero ability in data. rfm/rfmT/rfmTgt and freezeAnyDice left the hero
# kits in pkg3 (roll buffs are item/gear-only now; freeze targets enemies) —
# their handlers stay covered by targeted regressions instead.
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
	_run_ward_regressions()
	_run_shield_lowest_regression()
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
	_run_down_cleanup_regression()
	_run_summon_slot_regression()
	_run_phase_two_revive_regression()
	_run_phase_two_end_of_turn_regression()
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
	# Enemy freeze (former cower): the hero's die locks after the enemy phase
	# and the hero skips its next reveal.
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
	var frozen_after_apply: bool = int(hero.get("die_freeze_turns", 0)) == 1 and not bool(hero.get("die_freeze_consumed_this_round", false))

	# Next round: the frozen die is revealed (consumed flag set at roll time by
	# battle_scene; mimic that here) — the hero must skip its action.
	hero["selected_target_id"] = str(enemy["id"])
	hero["die_freeze_consumed_this_round"] = true
	var enemy_hp_before: int = int(enemy["current_hp"])
	manager.resolve_round({str(hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var hero_skipped: bool = int(enemy["current_hp"]) == enemy_hp_before
	var freeze_cleared: bool = int(hero.get("die_freeze_turns", 0)) == 0 and not bool(hero.get("die_freeze_consumed_this_round", false))

	if frozen_after_apply and hero_skipped and freeze_cleared:
		_record_pass("Regression / enemy freeze skips hero reveal", "freezeEnemyDice")
	else:
		_record_failure(
			"Regression / enemy freeze skips hero reveal",
			"freezeEnemyDice",
			"hero frozen after enemy phase, skips next reveal, freeze then clears",
			"frozen=%s skipped=%s cleared=%s turns=%d" % [str(frozen_after_apply), str(hero_skipped), str(freeze_cleared), int(hero.get("die_freeze_turns", 0))]
		)

	# Hero-side freeze cancels the target enemy's imminent action this round.
	var cancel_manager: CombatManager = CombatManager.new()
	var freezer_unit: UnitData = _make_unit("audit_freezer", "Audit Freezer", "Flash Freeze", {"freezeEnemyDice": 1})
	var striker_enemy: EnemyData = _make_enemy("audit_striker", "Audit Striker", "Claw", {"dmg": 9})
	cancel_manager.setup_battle([freezer_unit], [striker_enemy])
	var freezer: Dictionary = cancel_manager.get_hero_states()[0]
	var striker: Dictionary = cancel_manager.get_enemy_states()[0]
	freezer["selected_target_id"] = str(striker["id"])
	striker["selected_target_id"] = str(freezer["id"])
	striker["last_die_value"] = 15
	var hero_hp_before: int = int(freezer["current_hp"])
	cancel_manager.resolve_round({str(freezer["id"]): AUDIT_ROLL}, {str(striker["id"]): AUDIT_ROLL}, DiceManager.new())
	var canceled: bool = int(freezer["current_hp"]) == hero_hp_before
	var charge_spent: bool = int(striker.get("die_freeze_turns", 0)) == 0
	if canceled and charge_spent:
		_record_pass("Regression / hero freeze cancels enemy action", "freezeEnemyDice")
	else:
		_record_failure(
			"Regression / hero freeze cancels enemy action",
			"freezeEnemyDice",
			"frozen enemy's imminent hit never lands; charge consumed at round end",
			"hero_hp_delta=%d striker_turns=%d" % [hero_hp_before - int(freezer["current_hp"]), int(striker.get("die_freeze_turns", 0))]
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

	# The first attack made from Cloak gains Pierce and breaks the cloak.
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
	var pierced: bool = int(strike_enemy["current_hp"]) == strike_before - 9 and int(strike_enemy["shield"]) == 20
	var decloaked: bool = not bool(strike_hero.get("cloaked", false))
	if pierced and decloaked:
		_record_pass("Regression / attack from cloak pierces and decloaks", "cloak")
	else:
		_record_failure("Regression / attack from cloak pierces and decloaks", "cloak", "9 HP damage past 20 shield; attacker decloaked", "hp_delta=%d shield=%d cloaked=%s" % [strike_before - int(strike_enemy["current_hp"]), int(strike_enemy["shield"]), str(strike_hero.get("cloaked", false))])


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
	# Chain: primary takes full damage; the lowest-HP OTHER enemy takes 60%
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
	var single_ok: bool = int(a["current_hp"]) == a_before - 10 and int(b["current_hp"]) == 54 and int(c["current_hp"]) == 90
	if single_ok:
		_record_pass("Regression / chain jumps to lowest other enemy at 60%", "chain")
	else:
		_record_failure("Regression / chain jumps to lowest other enemy at 60%", "chain", "primary -10, lowest other -6, third untouched", "a=%d b=%d c=%d" % [int(a["current_hp"]), int(b["current_hp"]), int(c["current_hp"])])

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
	var double_ok: bool = int(da["current_hp"]) == da_before - 10 and int(db["current_hp"]) == 54 and int(dc["current_hp"]) == 84
	if double_ok:
		_record_pass("Regression / chain x2 adds a second jump", "chain")
	else:
		_record_failure("Regression / chain x2 adds a second jump", "chain", "primary -10, two other enemies -6 each", "a=%d b=%d c=%d" % [int(da["current_hp"]), int(db["current_hp"]), int(dc["current_hp"])])


func _run_detonate_regression() -> void:
	# Detonate consumes the target's Burn for burn x remaining-turns damage.
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Backdraft", {"dmg": 5, "detonate": true})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy")
	manager.setup_battle([hero_unit], [enemy_unit])
	var hero: Dictionary = manager.get_hero_states()[0]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	hero["selected_target_id"] = str(enemy["id"])
	enemy["burn"] = 3
	enemy["burn_turns"] = 2
	enemy["burn_skip_next_tick"] = true
	var before_hp: int = int(enemy["current_hp"])
	manager.resolve_round({str(hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	# 5 base + (3 burn x 2 turns) = 11; burn cleared so no tick fires
	var ok: bool = int(enemy["current_hp"]) == before_hp - 11 and int(enemy["burn"]) == 0 and int(enemy["burn_turns"]) == 0
	if ok:
		_record_pass("Regression / detonate consumes burn for burst", "detonate")
	else:
		_record_failure("Regression / detonate consumes burn for burst", "detonate", "5 dmg + 6 burst, burn cleared", "hp_delta=%d burn=%d turns=%d" % [before_hp - int(enemy["current_hp"]), int(enemy["burn"]), int(enemy["burn_turns"])])

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
	# Jam caps the target's NEXT roll at 12, then clears at that round's tick.
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "EMP Pulse", {"dmg": 7, "jam": true})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy")
	manager.setup_battle([hero_unit], [enemy_unit])
	var hero: Dictionary = manager.get_hero_states()[0]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	hero["selected_target_id"] = str(enemy["id"])
	manager.resolve_round({str(hero["id"]): AUDIT_ROLL}, {}, DiceManager.new())
	var capped_roll: int = manager.get_effective_roll(enemy, 18)
	var jam_active: bool = int(enemy.get("jam_cap", 0)) == 12
	manager.resolve_round({}, {}, DiceManager.new())
	var cleared_roll: int = manager.get_effective_roll(enemy, 18)
	if jam_active and capped_roll == 12 and cleared_roll == 18:
		_record_pass("Regression / jam caps next roll then clears", "jam")
	else:
		_record_failure("Regression / jam caps next roll then clears", "jam", "18 capped to 12 for one round, 18 after", "cap=%d capped=%d cleared=%d" % [int(enemy.get("jam_cap", 0)), capped_roll, cleared_roll])


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
		_record_pass("Regression / freeze stacks reveal skips", "freeze")
	else:
		_record_failure("Regression / freeze stacks reveal skips", "freeze", "freeze turns add and frozen value is preserved", "turns=%d value=%d" % [int(enemy.get("die_freeze_turns", 0)), int(enemy.get("frozen_die_value", 0))])


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
	hero["cursed"] = true
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
		and not bool(hero["cursed"])
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


func _run_phase_two_revive_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var scrap_unit: EnemyData = _make_enemy("scrap_drone", "Scrap Drone")
	scrap_unit.max_hp = 35
	var boss_unit: EnemyData = _make_enemy("scrapmaster", "SCRAPMASTER")
	boss_unit.max_hp = 180
	boss_unit.phase_two_threshold = 86
	boss_unit.phase_two_revive_names = ["Scrap Drone"]
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Noop", {})
	manager.setup_battle([hero_unit], [scrap_unit, boss_unit, scrap_unit])
	var states: Array = manager.get_enemy_states()
	states[0]["dead"] = true
	states[0]["current_hp"] = 0
	states[2]["current_hp"] = 12
	states[1]["current_hp"] = 70

	manager.resolve_round({}, {}, DiceManager.new())

	var left_revived: bool = not bool(states[0].get("dead", true)) and int(states[0].get("current_hp", 0)) == 35
	var right_healed: bool = not bool(states[2].get("dead", true)) and int(states[2].get("current_hp", 0)) == 35
	var boss_p2: bool = bool(states[1].get("in_phase_two", false))
	if left_revived and right_healed and boss_p2:
		_record_pass("Regression / phase 2 restores scrap drones", "phase2")
	else:
		_record_failure(
			"Regression / phase 2 restores scrap drones",
			"phase2",
			"dead scrap revived and damaged living scrap at full HP",
			"left=%s/%d right=%s/%d boss_p2=%s" % [
				str(not bool(states[0].get("dead", true))),
				int(states[0].get("current_hp", 0)),
				str(not bool(states[2].get("dead", true))),
				int(states[2].get("current_hp", 0)),
				str(boss_p2),
			]
		)


func _run_phase_two_end_of_turn_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Strike", {"dmg": 30})
	var boss_unit: EnemyData = _make_enemy("scrapmaster", "SCRAPMASTER", "Boss Strike", {"dmg": 19, "dmgP2": 26})
	boss_unit.max_hp = 180
	boss_unit.phase_two_threshold = 86
	manager.setup_battle([hero_unit], [boss_unit])
	var hero: Dictionary = manager.get_hero_states()[0]
	var boss: Dictionary = manager.get_enemy_states()[0]
	hero["current_hp"] = 100
	boss["current_hp"] = 100

	manager.resolve_round({"audit_hero": AUDIT_ROLL}, {"scrapmaster#1": AUDIT_ROLL}, DiceManager.new())

	var hero_hp: int = int(hero.get("current_hp", 0))
	var boss_p2: bool = bool(boss.get("in_phase_two", false))
	var boss_hp: int = int(boss.get("current_hp", 0))
	# Hero dealt 30 (boss 70 HP, below threshold) but boss still used phase-1 19 dmg this turn.
	if hero_hp == 81 and boss_hp == 70 and boss_p2:
		_record_pass("Regression / phase 2 waits until end of turn", "phase2")
	else:
		_record_failure(
			"Regression / phase 2 waits until end of turn",
			"phase2",
			"hero takes 19 not 26; boss enters P2 after round",
			"hero_hp=%d boss_hp=%d boss_p2=%s" % [hero_hp, boss_hp, str(boss_p2)],
		)


func _run_gear_lifesteal_regression() -> void:
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Strike", {"dmg": 20})
	var enemy_unit: EnemyData = _make_enemy("audit_enemy", "Audit Enemy")
	manager.setup_battle([hero_unit], [enemy_unit])
	manager.setup_gear({"audit_hero": ["blood_siphon"]})
	var hero: Dictionary = manager.get_hero_states()[0]
	var enemy: Dictionary = manager.get_enemy_states()[0]
	enemy["current_hp"] = 20
	enemy["max_hp"] = 20
	hero["current_hp"] = 90
	hero["selected_target_id"] = str(enemy["id"])
	var hero_hp_before: int = int(hero["current_hp"])
	manager.resolve_round({"audit_hero": AUDIT_ROLL}, {}, DiceManager.new())
	var expected_heal: int = 5
	var ok: bool = int(hero["current_hp"]) == hero_hp_before + expected_heal and bool(enemy["dead"])
	if ok:
		_record_pass("Regression / gear lifesteal", "lifesteal")
	else:
		_record_failure(
			"Regression / gear lifesteal",
			"lifesteal",
			"20 damage kill heals 25%% (5 HP)",
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
	var survivor_hp_before: int = int(survivor["current_hp"])
	manager.resolve_round({}, {"audit_enemy#1": AUDIT_ROLL}, DiceManager.new(), {"audit_enemy#1": AUDIT_ROLL})
	var ok: bool = bool(victim["dead"]) and int(survivor["current_hp"]) == survivor_hp_before + 5
	if ok:
		_record_pass("Regression / relic allyDeathHealAll", "allyDeathHealAll")
	else:
		_record_failure(
			"Regression / relic allyDeathHealAll",
			"allyDeathHealAll",
			"survivor heals 5 when ally dies",
			"victim_dead=%s survivor_hp=%d" % [str(victim["dead"]), int(survivor["current_hp"])]
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
	var enemy_max_before: int = int(e["max_hp"])
	mgr.setup_relics(["signalJam", "coordinatedStrike", "plagueProtocol", "entropyLeak"])
	mgr.apply_battle_start_relic_effects(2)  # battle_index 2 -> entropyLeak removes 10 max HP

	_expect_and_record("Regression / relic signalJam perm_rfe", "enemyStartRfe", "2", str(int(e.get("perm_rfe", 0))))
	_expect_and_record("Regression / relic coordinatedStrike perm_roll_buff", "heroStartRollBuff", "2", str(int(h.get("perm_roll_buff", 0))))
	# Those permanent modifiers must flow into the authoritative roll totals that the compact
	# roll pip mirrors (the bug this guards: pip ignored perm_rfe / perm_roll_buff).
	var enemy_totals: Dictionary = mgr.get_roll_modifier_totals(e)
	var hero_totals: Dictionary = mgr.get_roll_modifier_totals(h)
	_expect_and_record("Regression / relic signalJam roll total", "enemyStartRfe", "2", str(int(enemy_totals.get("roll_rfe", 0))))
	_expect_and_record("Regression / relic coordinatedStrike roll total", "heroStartRollBuff", "2", str(int(hero_totals.get("roll_buff", 0))))
	_expect_and_record("Regression / relic plagueProtocol burn", "enemyBurnPermanent", "3", str(int(e.get("burn", 0))))
	_expect_and_record("Regression / relic entropyLeak maxhp", "enemyHpEscalation", str(enemy_max_before - 10), str(int(e["max_hp"])))


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
	var manager: CombatManager = CombatManager.new()
	var hero_unit: UnitData = _make_unit("audit_hero", "Audit Hero", "Strike", {"dmg": 100})
	var boss_enemy: EnemyData = _make_enemy("audit_boss", "Audit Boss")
	boss_enemy.enemy_type = "boss"
	manager.setup_battle([hero_unit], [boss_enemy])
	manager.setup_gear({"audit_hero": ["apex_collector"]})
	var hero: Dictionary = manager.get_hero_states()[0]
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
	var ok: bool = (
		int(hero_a.get("roll_buff", 0)) == 2
		and int(hero_b.get("roll_buff", 0)) == 2
		and int(hero_a.get("roll_buff_turns", 0)) == 1
	)
	if ok:
		_record_pass("Regression / relic lowHpSquadRollBuff", "lowHpSquadRollBuff")
	else:
		_record_failure(
			"Regression / relic lowHpSquadRollBuff",
			"lowHpSquadRollBuff",
			"first ally below 50%% HP grants +2 roll to squad",
			"hero_a buff=%d turns=%d hero_b buff=%d" % [
				int(hero_a.get("roll_buff", 0)),
				int(hero_a.get("roll_buff_turns", 0)),
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
	var cost: int = int(battle_scene.call("_get_item_protocol_cost", null))
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
	# old hover tooltips that used to carry this text in compact_unit_card).
	var status_text: String = FileAccess.get_file_as_string("res://scripts/ui/inspect_resolver.gd")
	_expect_and_record("Text alignment / inspect cloak text", "text", "contains cloak untargetable text", "contains cloak untargetable text" if status_text.contains("Untargetable by single-target abilities.") else "missing")
	_expect_and_record("Text alignment / inspect ward text", "text", "contains ward block text", "contains ward block text" if status_text.contains("Blocks the next ability that targets this unit") else "missing")


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
			# Hero freezes cancel the target's imminent action; the (single)
			# charge is consumed by the same round's end tick, so assert the
			# freeze event rather than lingering post-round turns.
			return _expect_bool(effect_field, _has_event(events, "freeze", 9, "enemy"), "freeze event on selected enemy die (value 9)", "events=%s" % str(events))
		"freezeAllEnemyDice":
			return _expect_bool(effect_field, _count_events(events, "freeze", "enemy") >= 2, "freeze events on all enemy dice", "events=%s" % str(events))
		"taunt":
			return _expect_bool(effect_field, after.actor.taunting, "actor taunting after hero taunt ability", "taunting=%s" % str(after.actor.taunting))
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
