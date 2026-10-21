# Scrap feed gate (G-98, Kev 2026-10-20).
#
#   godot --headless --path . -s scripts/debug/scrap_feed_test.gd [-- --scrap-feed-break=no_chip]
#
# The Scrapmaster's ASSEMBLY LINE no longer rebuilds drones. At the start of
# every round it heals 8 HP for each living Scrap Drone, capped at max HP, and
# it shows the way Accrete does. Pinned here:
#   A. combat   2 living drones heal 16, 1 heals 8, none heals nothing, dead
#               drones are never rebuilt; the heal stops at max HP and at full
#               HP nothing is shown; the heal has its own beat, a `heal` event
#               with the HP healed and the ASSEMBLY LINE chip text, and one log
#               line with the same number.
#   B. preview  the dry run behind the HP preview ends the round on the HP the
#               real round ends on, heal included.
#   C. live     a real round of the Facility boss fight: the boss card's HP
#               preview equals the HP it ends the round on, the ASSEMBLY LINE
#               chip on the boss reads the HP healed, and the battle log has
#               the line.
# scripts/checks/break_gate.py reruns it with each CombatManager
# SCRAP_FEED_BREAK_ARG mode (no_chip, no_line, preview_blind, uncapped) and
# requires a FAIL.
extends SceneTree

const COMBAT_SOURCE := "res://scripts/battle/combat_manager.gd"
const DICE_SOURCE := "res://scripts/battle/dice_manager.gd"
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SPEED := 8
const BOSS := "Scrapmaster"
const DRONE := "Scrap Drone"

var _errors: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_errors.append(what)


func sm() -> Node:
	return root.get_node("/root/SaveManager")


func dm() -> Node:
	return root.get_node("/root/DataManager")


func _run() -> void:
	await process_frame
	root.get_node("/root/AudioManager").set_suppressed(true)
	sm().set_setting("ability_primers_enabled", false)
	sm().set_setting("reduced_motion", false)
	sm().set_setting("no_animations", false)
	_check_combat()
	_check_preview()
	await _check_live()
	for error in _errors:
		print("[SCRAP_FEED] FAIL - %s" % error)
	print("[SCRAP_FEED] %s" % ("PASS" if _errors.is_empty() else "FAIL - %d check(s)" % _errors.size()))
	sm().clear_run_save()
	if current_scene != null:
		unload_current_scene()
	await create_timer(0.3).timeout
	quit(0 if _errors.is_empty() else 1)


# CombatManager's constant, read at run time: a -s harness is parsed before
# the autoloads exist, so it cannot name the class.
func _per_drone() -> int:
	return int(load(COMBAT_SOURCE).new().SCRAPMASTER_HEAL_PER_DRONE)


# Drone, boss, drone: the battle 10 lineup.
func _battle() -> Object:
	var cm: Object = load(COMBAT_SOURCE).new()
	var hero: UnitData = dm().get_unit("combat") as UnitData
	var drone: EnemyData = dm().get_enemy_by_display_name(DRONE) as EnemyData
	var boss: EnemyData = dm().get_enemy_by_display_name(BOSS) as EnemyData
	cm.setup_battle([hero], [drone.duplicate(true), boss.duplicate(true), drone.duplicate(true)])
	return cm


func _events(cm: Object, type: String) -> Array:
	var out: Array = []
	for event in cm._round_events:
		if str(event.get("type", "")) == type:
			out.append(event)
	return out


# One round start: returns the HP the boss gained and checks what is shown.
func _feed_once(cm: Object, label: String, drones: int) -> int:
	var boss: Dictionary = cm.get_enemy_states()[1]
	cm._round_events.clear()
	cm._round_log.clear()
	var before: int = int(boss["current_hp"])
	cm._apply_boss_round_start_rules()
	var healed: int = int(boss["current_hp"]) - before
	_expect(int(boss["current_hp"]) <= int(boss["max_hp"]), "%s: the boss is not healed past max HP (%d / %d)" % [label, int(boss["current_hp"]), int(boss["max_hp"])])
	var heals: Array = _events(cm, "heal")
	if healed > 0:
		_expect(heals.size() == 1, "%s: one heal event (%d)" % [label, heals.size()])
		if heals.size() == 1:
			var event: Dictionary = heals[0]
			_expect(int(event["amount"]) == healed, "%s: the event shows %d, the HP healed is %d" % [label, int(event["amount"]), healed])
			_expect(int(event.get("hp_after", -1)) == int(boss["current_hp"]), "%s: the event carries the HP after it" % label)
			_expect(str(event.get("rule_chip", "")) == "ASSEMBLY LINE +%d" % healed, "%s: the chip reads \"ASSEMBLY LINE +%d\" (\"%s\")" % [label, healed, str(event.get("rule_chip", ""))])
			_expect(bool(event.get("standing_rule", false)), "%s: the event is marked as the standing rule" % label)
		var line: String = "ASSEMBLY LINE - %s the Scrapmaster scrap. It heals %d HP." % [
			"1 Scrap Drone feeds" if drones == 1 else "%d Scrap Drones feed" % drones, healed]
		_expect(cm._round_log.has(line), "%s: the log reads \"%s\" (%s)" % [label, line, str(cm._round_log)])
		var beats: Array = _events(cm, "action_start")
		_expect(beats.size() == 1 and str(beats[0].get("ability", "")) == "Assembly Line" and str(beats[0].get("zone", "")) == "tick", "%s: the heal has a beat of its own" % label)
	else:
		_expect(cm._round_events.is_empty() and cm._round_log.is_empty(), "%s: nothing healed, nothing shown (%s / %s)" % [label, str(cm._round_events), str(cm._round_log)])
	return healed


# ── A. Combat ─────────────────────────────────────────────────────────────────
func _check_combat() -> void:
	var per: int = _per_drone()
	_expect(per == 8, "the rule heals 8 HP per drone (%d)" % per)
	var cm: Object = _battle()
	var boss: Dictionary = cm.get_enemy_states()[1]
	var max_hp: int = int(boss["max_hp"])
	boss["current_hp"] = max_hp - 50
	_expect(_feed_once(cm, "two drones", 2) == 2 * per, "two living drones heal %d" % (2 * per))
	cm.get_enemy_states()[0]["dead"] = true
	cm.get_enemy_states()[0]["current_hp"] = 0
	_expect(_feed_once(cm, "one drone", 1) == per, "one living drone heals %d" % per)
	boss["current_hp"] = max_hp - 5
	_expect(_feed_once(cm, "capped", 1) == 5, "the heal stops at max HP")
	_expect(_feed_once(cm, "full HP", 1) == 0, "at full HP nothing heals")
	cm.get_enemy_states()[2]["dead"] = true
	cm.get_enemy_states()[2]["current_hp"] = 0
	boss["current_hp"] = max_hp - 50
	_expect(_feed_once(cm, "no drones", 0) == 0, "with no living drone nothing heals")

	# Through real rounds: the dead drones never come back.
	var dice: Object = load(DICE_SOURCE).new()
	for _round in 4:
		cm.resolve_round({}, {}, dice)
	_expect(bool(cm.get_enemy_states()[0]["dead"]) and bool(cm.get_enemy_states()[2]["dead"]), "dead drones are never rebuilt")
	_expect(int(boss["current_hp"]) == max_hp - 50, "no drone, no heal over four rounds (%d)" % int(boss["current_hp"]))

	# The rule text says what combat does.
	var rule: String = str(load(COMBAT_SOURCE).get_boss_standing_rule(BOSS))
	_expect(rule.begins_with("ASSEMBLY LINE - ") and rule.contains("heals %d HP for each living Scrap Drone" % per), "the standing rule names the heal (%s)" % rule)
	_expect(not rule.to_lower().contains("rebuild") and not rule.contains("—"), "the standing rule no longer rebuilds, and has no em dash")


# ── B. Preview ────────────────────────────────────────────────────────────────
func _check_preview() -> void:
	var cm: Object = _battle()
	var boss: Dictionary = cm.get_enemy_states()[1]
	boss["current_hp"] = int(boss["max_hp"]) - 40
	var dice: Object = load(DICE_SOURCE).new()
	var forecast: Dictionary = cm.forecast_round({}, {}, dice)
	var predicted: int = int((forecast["end"] as Dictionary)[str(boss["id"])]["current_hp"])
	_expect(int(boss["current_hp"]) == int(boss["max_hp"]) - 40, "the dry run leaves the live boss alone")
	cm.resolve_round({}, {}, dice)
	_expect(predicted == int(boss["current_hp"]), "the dry run ends the round on the boss's real HP, heal included (predicted %d, real %d)" % [predicted, int(boss["current_hp"])])
	_expect(int(boss["current_hp"]) == int(boss["max_hp"]) - 40 + 2 * _per_drone(), "the round healed the boss %d" % (2 * _per_drone()))


# ── C. A real round of the boss fight ─────────────────────────────────────────
func _check_live() -> void:
	Engine.physics_ticks_per_second = 120 * SPEED
	Engine.time_scale = SPEED
	Engine.max_physics_steps_per_frame = 64
	var gs: Node = root.get_node("/root/GameState")
	sm().clear_run_save()
	gs.reset_run()
	gs.start_run(["combat", "engineer", "medic"], "facility", 77)
	gs.advance_to_next_battle()
	gs.current_battle = 10
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
	var heroes: Array = scene.combat_manager.get_hero_states()
	var enemies: Array = scene.combat_manager.get_enemy_states()
	var boss: Dictionary = {}
	var drones: int = 0
	for enemy_state in enemies:
		if str(enemy_state["unit"].display_name) == BOSS:
			boss = enemy_state
		elif str(enemy_state["unit"].display_name) == DRONE:
			drones += 1
	_expect(not boss.is_empty() and drones == 2, "fixture: the Scrapmaster and two Scrap Drones are on the field")
	if boss.is_empty():
		return
	# Every die lands on a band with no damage, so the heal is the round's
	# only change to the boss's HP and the preview has one thing to show.
	var rig: Dictionary = {}
	for hero_state in heroes:
		rig["hero:%s" % hero_state["id"]] = _quiet_roll(scene, hero_state)
	for enemy_state in enemies:
		rig["enemy:%s" % enemy_state["id"]] = _quiet_roll(scene, enemy_state)
	scene.dice_tray_3d.set_rigged_results(rig)
	await scene._begin_targeting_phase()
	await _settle(scene)
	if int(scene.turn_phase) == int(scene.PHASE_TARGETING):
		await scene._auto_assign_pending_targets(false)
	boss["current_hp"] = int(boss["max_hp"]) - 60
	var preview: Dictionary = scene._card_view.compute_preview_for_unit(boss, false)
	var projected: int = int(preview.get("final_hp", int(boss["current_hp"]) + int(preview.get("heal", 0))))

	var card: Control = scene._feedback._find_card_by_state_id("enemy", str(boss["id"]))
	var seen: Array = []
	var on_child := func(node: Node) -> void:
		if node.name.begins_with("RuleChip"):
			seen.append(node)
	scene.float_layer.child_entered_tree.connect(on_child)
	var chip_text: Array = [""]
	var chip_rect: Array = [Rect2()]
	var watch := func() -> void:
		for node in seen:
			if is_instance_valid(node) and chip_text[0] == "":
				var labels: Array = (node as Node).find_children("*", "Label", true, false)
				if not labels.is_empty() and (node as Control).size.x > 0.0:
					chip_text[0] = str((labels[0] as Label).text)
					chip_rect[0] = (node as Control).get_global_rect()
	process_frame.connect(watch)
	await scene._resolve_current_turn(false)
	process_frame.disconnect(watch)
	scene.float_layer.child_entered_tree.disconnect(on_child)
	await create_timer(0.5).timeout

	var healed: int = 2 * _per_drone()
	_expect(projected == int(boss["current_hp"]), "live: the boss's HP preview (%d) is the HP it ends the round on (%d)" % [projected, int(boss["current_hp"])])
	_expect(int(boss["current_hp"]) == int(boss["max_hp"]) - 60 + healed, "live: the boss healed %d (%d / %d)" % [healed, int(boss["current_hp"]), int(boss["max_hp"])])
	_expect(seen.size() == 1, "live: one ASSEMBLY LINE chip (%d)" % seen.size())
	_expect(chip_text[0] == "ASSEMBLY LINE +%d" % healed, "live: the chip reads \"ASSEMBLY LINE +%d\" (\"%s\")" % [healed, chip_text[0]])
	if card != null and (chip_rect[0] as Rect2).has_area():
		var view: Rect2 = Rect2(Vector2.ZERO, scene.get_viewport_rect().size)
		_expect(view.encloses(chip_rect[0]), "live: the chip is on screen")
	var log_text: String = str(scene.battle_log_label.get_parsed_text())
	var line: String = "ASSEMBLY LINE - 2 Scrap Drones feed the Scrapmaster scrap. It heals %d HP." % healed
	_expect(log_text.contains(line), "live: the battle log reads \"%s\"" % line)
	Engine.time_scale = 1.0


# A face whose ability deals no damage and heals nothing, so the boss's HP
# moves only by the rule.
func _quiet_roll(scene: Node, state: Dictionary) -> int:
	for roll in range(1, 21):
		var raw: Dictionary = scene.dice_manager.get_ability_for_roll(state["unit"], roll).get("raw", {})
		if int(raw.get("dmg", 0)) == 0 and int(raw.get("heal", 0)) == 0 and not bool(raw.get("blastAll", false)) \
				and int(raw.get("burn", 0)) == 0 and int(raw.get("summonChance", 0)) == 0:
			return roll
	return 1


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
