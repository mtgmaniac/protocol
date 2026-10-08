# Taunt planning chip gate (playtest 2026-10-01).
#
#   godot --headless --path . -s scripts/debug/taunt_planning_chip_test.gd
#
# Sentinel's taunt "didn't work": the mechanic did (single-target, G-4), but
# nothing showed it before End Turn. The TAUNT chip now shows on the picked
# enemy during planning, read off the hero-phase dry run. Pinned here on a live
# BattleScene with rigged real throws:
#   - no chip before the pick; the chip on the picked enemy only, once picked;
#   - unassigning the taunter clears it;
#   - a Firewalled enemy that will eat the taunt shows no chip (preview honesty);
#   - resolving the round: the taunted enemy hits the taunter.
# FAIL-ON-OLD: before the change no enemy shows a chip during planning.
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SPEED := 8

var _errors: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, label: String) -> void:
	if not cond:
		_errors.append(label)
		print("[TAUNT_CHIP] FAIL %s" % label)


func _run() -> void:
	Engine.physics_ticks_per_second = 120 * SPEED
	Engine.time_scale = SPEED
	Engine.max_physics_steps_per_frame = 64
	var sm: Node = root.get_node("/root/SaveManager")
	var gs: Node = root.get_node("/root/GameState")
	sm.clear_run_save()
	gs.reset_run()
	# Sentinel in the LAST slot: the facility enemies' SYSTEMATIC personality
	# aims at slot 1, so only a working taunt moves a hit onto Sentinel.
	gs.start_run(["medic", "engineer", "shield"], "facility", 4242)
	gs.unit_evolutions["shield"] = "Sentinel"
	gs.advance_to_next_battle()
	gs.current_battle = 2
	change_scene_to_file(BATTLE_SCENE)
	for _i in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE and current_scene.is_node_ready():
			break
	await create_timer(0.8).timeout
	var scene: Node = current_scene
	var heroes: Array = scene.combat_manager.get_hero_states()
	var enemies: Array = scene.combat_manager.get_enemy_states()
	_check(enemies.size() >= 2, "fixture: two enemies")
	if enemies.size() < 2:
		_finish()
		return
	var rig: Dictionary = {}
	# The face comes from the data: the lowest one in Sentinel's taunt band.
	var taunt_roll: int = 0
	for band in heroes[2]["unit"].dice_ranges:
		if bool(((band as Dictionary).get("raw", {}) as Dictionary).get("taunt", false)):
			taunt_roll = int((band as Dictionary).get("min", 0))
	_check(taunt_roll > 0, "fixture: Sentinel has a taunt band")
	var hero_vals := [2, 9, taunt_roll]   # Sentinel rolls Challenge (4 shield, taunt)
	for i in heroes.size():
		rig["hero:%s" % heroes[i]["id"]] = hero_vals[i]
	for e in enemies:
		rig["enemy:%s" % e["id"]] = 12
	scene.dice_tray_3d.set_rigged_results(rig)
	await scene._begin_targeting_phase()
	await _settle(scene)
	var sentinel: Dictionary = heroes[2]
	var sid: String = str(sentinel["id"])
	var e0: Dictionary = enemies[0]
	var e1: Dictionary = enemies[1]
	_check(not _has_taunt_chip(scene, e0) and not _has_taunt_chip(scene, e1), "no TAUNT chip before the pick")
	_pick(scene, sid, str(e0["id"]))
	_check(str(sentinel.get("selected_target_id", "")) == str(e0["id"]), "fixture: Sentinel's taunt picks enemy 1")
	_check(_has_taunt_chip(scene, e0), "the picked enemy shows TAUNT during planning")
	_check(not _has_taunt_chip(scene, e1), "the other enemy does not (taunt is single-target, G-4)")
	# Unassign the taunter: the chip goes with the pick.
	if scene._can_unassign_hero(sid):
		scene._unassign_hero_cast(sid)
	_check(str(sentinel.get("selected_target_id", "")) == "" or not _has_taunt_chip(scene, e0), "unassigning the taunter clears the chip")
	# A Firewall eats the taunt, so the preview must not promise it.
	e1["warded"] = true
	_pick(scene, sid, str(e1["id"]))
	_check(not _has_taunt_chip(scene, e1), "a Firewalled enemy shows no TAUNT chip (the wall eats the taunt)")
	e1["warded"] = false
	_pick(scene, sid, str(e0["id"]))
	_check(_has_taunt_chip(scene, e0), "re-picked enemy shows TAUNT again")
	await scene._auto_assign_pending_targets()
	var sentinel_before: int = int(sentinel["current_hp"]) + int(sentinel.get("shield", 0))
	await scene._resolve_current_turn(true)
	await create_timer(0.5).timeout
	_check(str(scene.battle_log_label.get_parsed_text()).contains("taunts %s" % str(e0["unit"].display_name)), "the log records the taunt")
	_check(int(sentinel["current_hp"]) + int(sentinel.get("shield", 0)) < sentinel_before + 4, "the taunted enemy hit Sentinel")
	_finish()


# Select the taunter and tap the enemy, through the scene's own handlers.
func _pick(scene: Node, hero_id: String, enemy_id: String) -> void:
	if scene._can_unassign_hero(hero_id) and str(scene.active_targeting_hero_id) != hero_id:
		scene._unassign_hero_cast(hero_id)
	if str(scene.active_targeting_hero_id) != hero_id:
		scene._on_hero_card_pressed(hero_id)
	scene._on_enemy_card_pressed(enemy_id)


func _has_taunt_chip(scene: Node, enemy_state: Dictionary) -> bool:
	for token in scene._card_view._composed_status_tokens(enemy_state):
		if str((token as Dictionary).get("type", "")) == "taunt":
			return true
	return false


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


func _finish() -> void:
	var sm: Node = root.get_node("/root/SaveManager")
	sm.clear_run_save()
	if current_scene != null:
		unload_current_scene()
	await create_timer(0.5).timeout
	if _errors.is_empty():
		print("[TAUNT_CHIP] PASS")
		quit(0)
	else:
		print("[TAUNT_CHIP] FAIL (%d)" % _errors.size())
		quit(1)
