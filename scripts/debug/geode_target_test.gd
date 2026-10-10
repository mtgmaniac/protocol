# Geode targeting gate (G-61, Kev 2026-10-09).
#
#   godot --headless --path . -s scripts/debug/geode_target_test.gd [-- --geode-break=split]
#
# Geode Panther's Calcifying Bite and Stonefang Pounce froze the hero with the
# lowest die but hit whoever its targeting personality chose. Now one unit takes
# both: the hero with the lowest die.
# Pinned here:
#   A. combat   the hit and the freeze land on the lowest die, whatever target
#               the enemy was holding; the pick follows the dice; a taunt
#               redirects both; a cloaked or fallen hero is passed over; with
#               every hero cloaked one is hit at random and the freeze lands on
#               that same unit; an attack that freezes ALL dice still aims by
#               personality.
#   B. planning the intent shown before the round is the lowest die as the dice
#               show now, and it moves when they change.
#   C. data     both of the Panther's freeze-one abilities attack, and their
#               text names the lowest hero die as the target.
#   D. live     a real round with the Panther's kit: the intent names the
#               lowest die, follows a Set, and the round hits and freezes that
#               hero.
# scripts/checks/break_gate.py reruns it with each CombatManager GEODE_BREAK_ARG
# mode (split, stale) and requires a FAIL.
extends SceneTree

const COMBAT_SOURCE := "res://scripts/battle/combat_manager.gd"
const DICE_SOURCE := "res://scripts/battle/dice_manager.gd"
const SEEDED_SOURCE := "res://scripts/sim/seeded_roll_provider.gd"
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const PANTHER := "Geode Panther"
const BITE := {"dmg": 10, "freezeEnemyDice": 1, "freeze_flavor": "petrify"}
const SPEED := 8

var _errors: PackedStringArray = []
var _dice: Object


func _initialize() -> void:
	call_deferred("_run")


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_errors.append(what)


func sm() -> Node:
	return root.get_node("/root/SaveManager")


func _run() -> void:
	await process_frame
	root.get_node("/root/AudioManager").set_suppressed(true)
	sm().set_setting("ability_primers_enabled", false)
	_dice = load(DICE_SOURCE).new()
	_check_combat()
	_check_planning()
	_check_data()
	await _check_live()
	for error in _errors:
		print("[GEODE_TARGET] FAIL - %s" % error)
	print("[GEODE_TARGET] %s" % ("PASS" if _errors.is_empty() else "FAIL - %d check(s)" % _errors.size()))
	sm().clear_run_save()
	if current_scene != null:
		unload_current_scene()
	await create_timer(0.3).timeout
	quit(0 if _errors.is_empty() else 1)


# ── Fixtures ──────────────────────────────────────────────────────────────────
func _band(ability_name: String, raw: Dictionary) -> Dictionary:
	return {"min": 1, "max": 20, "zone": "audit", "ability_name": ability_name, "description": "", "raw": raw.duplicate(true)}


func _hero(id: String) -> UnitData:
	var unit: UnitData = UnitData.new()
	unit.id = id
	unit.display_name = "Hero %s" % id
	unit.max_hp = 100
	unit.dice_ranges = [_band("Wait", {})]
	return unit


func _enemy(id: String, raw: Dictionary) -> EnemyData:
	var enemy: EnemyData = EnemyData.new()
	enemy.id = id
	enemy.display_name = "Enemy %s" % id
	enemy.max_hp = 100
	enemy.dice_ranges = [_band("Test Bite", raw)]
	return enemy


# Three heroes a, b, c and one enemy with `raw`.
func _battle(raw: Dictionary, stream_seed: int = 1) -> Object:
	var cm: Object = load(COMBAT_SOURCE).new()
	cm.roll_provider = load(SEEDED_SOURCE).new(stream_seed)
	cm.setup_battle([_hero("a"), _hero("b"), _hero("c")], [_enemy("x", raw)])
	return cm


# One round: the heroes show `dice` (a, b, c) and do nothing, the enemy acts.
func _round(cm: Object, dice: Array) -> void:
	var hero_rolls: Dictionary = {}
	var heroes: Array = cm.get_hero_states()
	for i in heroes.size():
		if not bool(heroes[i]["dead"]) and int(dice[i]) > 0:
			hero_rolls[str(heroes[i]["id"])] = int(dice[i])
	cm.resolve_round(hero_rolls, {str(cm.get_enemy_states()[0]["id"]): 10}, _dice)


# "a", "b" or "c" for each hero that lost HP / has a frozen die; joined.
func _hit(cm: Object) -> String:
	var out: String = ""
	for state in cm.get_hero_states():
		if int(state["current_hp"]) < int(state["max_hp"]):
			out += str(state["id"])
	return out


func _frozen(cm: Object) -> String:
	var out: String = ""
	for state in cm.get_hero_states():
		if int(state.get("die_freeze_turns", 0)) > 0:
			out += str(state["id"])
	return out


# ── A. One unit takes the hit and the freeze ──────────────────────────────────
func _check_combat() -> void:
	# The enemy is holding a pick on "a"; the lowest die is "c".
	var cm: Object = _battle(BITE)
	cm.get_enemy_states()[0]["selected_target_id"] = "a"
	_round(cm, [14, 9, 3])
	_expect(_hit(cm) == "c" and _frozen(cm) == "c", "the lowest die takes the hit and the freeze (hit %s, frozen %s)" % [_hit(cm), _frozen(cm)])

	# It follows the dice.
	cm = _battle(BITE)
	_round(cm, [2, 9, 13])
	_expect(_hit(cm) == "a" and _frozen(cm) == "a", "another roll, another lowest die (hit %s, frozen %s)" % [_hit(cm), _frozen(cm)])

	# A tie goes to the first in squad order.
	cm = _battle(BITE)
	_round(cm, [12, 5, 5])
	_expect(_hit(cm) == "b" and _frozen(cm) == "b", "a tie goes to the first in squad order (hit %s, frozen %s)" % [_hit(cm), _frozen(cm)])

	# A taunt redirects both.
	cm = _battle(BITE)
	cm.get_enemy_states()[0]["lured_by_id"] = "b"
	_round(cm, [14, 9, 3])
	_expect(_hit(cm) == "b" and _frozen(cm) == "b", "a taunt takes the hit and the freeze (hit %s, frozen %s)" % [_hit(cm), _frozen(cm)])

	# A cloaked hero is passed over.
	cm = _battle(BITE)
	cm.get_hero_states()[2]["cloaked"] = true
	_round(cm, [14, 9, 3])
	_expect(_hit(cm) == "b" and _frozen(cm) == "b", "a cloaked lowest die is passed over (hit %s, frozen %s)" % [_hit(cm), _frozen(cm)])

	# So is a fallen one.
	cm = _battle(BITE)
	cm.get_hero_states()[2]["dead"] = true
	cm.get_hero_states()[2]["current_hp"] = 0
	_round(cm, [14, 9, 3])
	_expect(_hit(cm).replace("c", "") == "b" and _frozen(cm) == "b", "a fallen hero is passed over (hit %s, frozen %s)" % [_hit(cm), _frozen(cm)])

	# Every hero cloaked: one is hit at random, and the freeze lands on it too.
	var picked: Dictionary = {}
	for stream_seed in 12:
		cm = _battle(BITE, stream_seed + 1)
		for state in cm.get_hero_states():
			state["cloaked"] = true
		_round(cm, [14, 9, 3])
		_expect(_hit(cm).length() == 1 and _hit(cm) == _frozen(cm), "all cloaked, seed %d: one hero takes both (hit %s, frozen %s)" % [stream_seed + 1, _hit(cm), _frozen(cm)])
		picked[_hit(cm)] = true
	_expect(picked.size() >= 2, "all cloaked: the hero is picked at random (%s)" % str(picked.keys()))

	# Freezing every die is a different ability: it still aims by its pick.
	cm = _battle({"dmg": 10, "freezeAllEnemyDice": 1})
	cm.get_enemy_states()[0]["selected_target_id"] = "a"
	_round(cm, [14, 9, 3])
	_expect(_hit(cm) == "a" and _frozen(cm) == "abc", "an attack that freezes all dice keeps its own target (hit %s, frozen %s)" % [_hit(cm), _frozen(cm)])


# ── B. The intent shown while planning ────────────────────────────────────────
func _check_planning() -> void:
	var cm: Object = _battle(BITE)
	var foe: Dictionary = cm.get_enemy_states()[0]
	var rolls: Dictionary = {str(foe["id"]): 10}
	cm.assign_enemy_intents(rolls, _dice, {"a": 14, "b": 9, "c": 3})
	_expect(str(foe["selected_target_id"]) == "c", "planning: the intent is the lowest die (%s)" % str(foe["selected_target_id"]))
	_expect(str(foe["target_display"]) == "Hero c", "planning: the intent is labelled with that hero (%s)" % str(foe["target_display"]))
	# The player raises c's die: the intent moves to the new lowest.
	cm.assign_enemy_intents(rolls, _dice, {"a": 14, "b": 9, "c": 20})
	_expect(str(foe["selected_target_id"]) == "b", "planning: the intent follows the dice when they change (%s)" % str(foe["selected_target_id"]))
	# A round was resolved on other dice: planning still reads the dice showing now.
	_round(cm, [3, 9, 14])
	cm.assign_enemy_intents(rolls, _dice, {"a": 14, "b": 9, "c": 3})
	_expect(str(foe["selected_target_id"]) != "a", "planning: last round's dice are not used (%s)" % str(foe["selected_target_id"]))


# ── C. The Panther's own kit ──────────────────────────────────────────────────
func _check_data() -> void:
	var panther: Resource = root.get_node("/root/DataManager").get_enemy_by_display_name(PANTHER)
	_expect(panther != null, "data: %s exists" % PANTHER)
	if panther == null:
		return
	var freeze_one: int = 0
	for band in panther.dice_ranges:
		var raw: Dictionary = (band as Dictionary).get("raw", {})
		if int(raw.get("freezeEnemyDice", 0)) <= 0:
			continue
		freeze_one += 1
		var text: String = str(raw.get("eff", (band as Dictionary).get("description", "")))
		_expect(load(COMBAT_SOURCE).attack_freezes_lowest_die(raw), "data: %s attacks the die it freezes" % str(band["ability_name"]))
		_expect(text.contains("(lowest hero die)"), "data: %s names the lowest hero die as its target (%s)" % [str(band["ability_name"]), text])
		_expect(not text.contains("freeze lowest hero die"), "data: %s no longer reads as a freeze aimed apart from the hit (%s)" % [str(band["ability_name"]), text])
	_expect(freeze_one == 2, "data: %s has two freeze-one attacks (%d)" % [PANTHER, freeze_one])


# ── D. A live round ───────────────────────────────────────────────────────────
func _settle(scene: Node) -> void:
	for _i in 900:
		var tray: Object = scene.dice_tray_3d
		var busy: bool = bool(tray.get("_is_rolling"))
		if not busy:
			for key in tray._die_by_key:
				var parts: PackedStringArray = str(key).split(":", true, 1)
				if tray.is_die_moving(parts[0], parts[1]):
					busy = true
					break
		if not busy:
			return
		await process_frame


func _check_live() -> void:
	Engine.physics_ticks_per_second = 120 * SPEED
	Engine.time_scale = SPEED
	Engine.max_physics_steps_per_frame = 64
	var gs: Node = root.get_node("/root/GameState")
	sm().clear_run_save()
	gs.reset_run()
	gs.start_run(["combat", "engineer", "medic"], "facility", 77)
	gs.advance_to_next_battle()
	change_scene_to_file(BATTLE_SCENE)
	for _i in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE and current_scene.is_node_ready():
			break
	await create_timer(0.8).timeout
	var scene: Node = current_scene
	if scene == null or scene.scene_file_path != BATTLE_SCENE:
		_errors.append("battle scene did not load")
		return
	var cm: Object = scene.combat_manager
	var heroes: Array = cm.get_hero_states()
	var enemies: Array = cm.get_enemy_states()
	var panther: Resource = root.get_node("/root/DataManager").get_enemy_by_display_name(PANTHER)
	if panther == null or heroes.size() < 3 or enemies.is_empty():
		_errors.append("live: fixture (three heroes, an enemy, the Panther's kit)")
		return
	# The first enemy fights with the Panther's kit for this round.
	var hunter: Dictionary = enemies[0]
	hunter["unit"] = panther
	hunter["cloaked"] = false
	# It has to live through the hero phase to take its turn.
	hunter["max_hp"] = 900
	hunter["current_hp"] = 900
	var bite_roll: int = 0
	for roll in range(1, 21):
		if load(COMBAT_SOURCE).attack_freezes_lowest_die(scene.dice_manager.get_ability_for_roll(panther, roll).get("raw", {})):
			bite_roll = roll
			break
	_expect(bite_roll > 0, "live: the Panther's kit has a freeze-one attack")
	var dice: Array = [15, 12, 4]
	var rig: Dictionary = {}
	for i in heroes.size():
		rig["hero:%s" % heroes[i]["id"]] = dice[i]
	for enemy_state in enemies:
		rig["enemy:%s" % enemy_state["id"]] = bite_roll if enemy_state == hunter else 1
	scene.dice_tray_3d.set_rigged_results(rig)
	await scene._begin_targeting_phase()
	await _settle(scene)
	var shown: Array = []
	for hero_state in heroes:
		shown.append(int(scene._get_effective_roll_for_state(hero_state, str(hero_state["id"]))))
	var lowest: int = 0
	for i in shown.size():
		if int(shown[i]) < int(shown[lowest]):
			lowest = i
	_expect(str(hunter["selected_target_id"]) == str(heroes[lowest]["id"]), "live: the intent is the hero with the lowest die (dice %s, intent %s)" % [str(shown), str(hunter["selected_target_id"])])

	# Set that die to 20: another hero now has the lowest die.
	scene._engine.apply_set(scene._state, str(heroes[lowest]["id"]), 20)
	scene._on_die_values_changed()
	await _settle(scene)
	shown[lowest] = 20
	var next_lowest: int = 0
	for i in shown.size():
		if int(shown[i]) < int(shown[next_lowest]):
			next_lowest = i
	var prey: Dictionary = heroes[next_lowest]
	_expect(next_lowest != lowest and str(hunter["selected_target_id"]) == str(prey["id"]), "live: the intent follows a Set to the new lowest die (dice %s, intent %s)" % [str(shown), str(hunter["selected_target_id"])])

	if int(scene.turn_phase) == int(scene.PHASE_TARGETING):
		await scene._auto_assign_pending_targets(false)
	await scene._resolve_current_turn(false)
	await create_timer(0.5).timeout
	_expect(not bool(hunter["dead"]), "live: fixture, the hunter lived to take its turn")
	_expect(int(prey.get("die_freeze_turns", 0)) > 0, "live: the hero with the lowest die is frozen")
	for hero_state in heroes:
		if hero_state != prey:
			_expect(int(hero_state.get("die_freeze_turns", 0)) == 0, "live: no other die is frozen (%s)" % str(hero_state["unit"].display_name))
	var log_text: String = str(scene.battle_log_label.get_parsed_text())
	_expect(log_text.contains("%s's die is frozen" % str(prey["unit"].display_name)), "live: the log names the frozen hero")
