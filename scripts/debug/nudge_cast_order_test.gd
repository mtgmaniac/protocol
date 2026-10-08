# Nudge cast-order regression (Kev, 2026-10-08).
#
#   godot --headless --path . -s scripts/debug/nudge_cast_order_test.gd [-- --nudge-cast-order-break=stale_target]
#
# A Nudge that changes a hero's ability sends that hero back to the pick queue.
# It used to keep its OLD target while it waited, so the damage forecast still
# ran that hero's new ability at the stale target with no cast stamp, and every
# forecast logged "[CAST_ORDER] ... reached resolution unstamped" (about twelve
# per Nudge). The state code keeps only the last 200 errors and warnings, so a
# few Nudges pushed the real ones out.
#
# Checked, through the real Nudge button and the real die/card tap handler:
#   the nudged hero's ability changes and it waits for a new target
#   it holds NO target while it waits (nothing stale for the forecast to use)
#   no warning or error of any kind is logged by the Nudge, by the card and
#   forecast refreshes after it, by the new pick, or by the round resolving
#   the state code's error list is unchanged
# scripts/checks/break_gate.py reruns it with --nudge-cast-order-break=stale_target
# (this test puts the old target back, as the old code left it) and requires a
# FAIL.
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SQUAD := ["combat", "medic", "engineer"]
const BREAK_ARG := "--nudge-cast-order-break="
const NUDGE := 3

var _errors: PackedStringArray = []
var _scene: Node
var _protocol: Node
var _break: String = ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(BREAK_ARG):
			_break = arg.trim_prefix(BREAK_ARG)
	call_deferred("_run")


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_errors.append(what)


func gs() -> Node:
	return root.get_node("/root/GameState")


func diag() -> Node:
	return root.get_node("/root/DiagnosticsLog")


func _heroes() -> Array:
	return _scene.combat_manager.get_hero_states()


func _ability(state: Dictionary, roll: int) -> Dictionary:
	return _scene.dice_manager.get_ability_for_roll(state["unit"], roll)


## The first hero with a roll whose ability takes an enemy pick both before and
## after +3, and is a different ability after it. Returns {id, roll} or {}.
func _find_case() -> Dictionary:
	for state in _heroes():
		for roll in range(2, 18 - NUDGE):
			var before: Dictionary = _ability(state, roll)
			var after: Dictionary = _ability(state, roll + NUDGE)
			if str(before.get("ability_name", "")) == str(after.get("ability_name", "")):
				continue
			if _scene._get_manual_target_side(before) == "enemy" and _scene._get_manual_target_side(after) == "enemy":
				return {"id": str(state["id"]), "roll": roll}
	return {}


## Log entries (errors and warnings) added since `from`, as text.
func _new_entries(from: int) -> PackedStringArray:
	var out: PackedStringArray = []
	var entries: Array = diag().recent_errors()
	for i in range(from, entries.size()):
		out.append(str((entries[i] as Dictionary).get("text", "")))
	return out


func _state_code_errors() -> int:
	var code: GDScript = load("res://scripts/autoloads/state_code.gd")
	return ((code.build_payload() as Dictionary).get("errors", []) as Array).size()


func _run() -> void:
	root.size = Vector2i(1080, 2400)
	root.get_node("/root/AudioManager").set_suppressed(true)
	var op_id: String = str(root.get_node("/root/DataManager").get_operation_order()[0])
	gs().start_run(SQUAD, op_id, 61008)
	gs().advance_to_next_battle()
	gs().current_battle = 2
	change_scene_to_file(BATTLE_SCENE)
	for i in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE:
			break
	await create_timer(0.8).timeout
	_scene = current_scene
	if _scene == null or _scene.scene_file_path != BATTLE_SCENE:
		_errors.append("battle scene did not load")
		_finish()
		return
	_protocol = _scene.get("_protocol")

	var case: Dictionary = _find_case()
	if case.is_empty():
		_errors.append("fixture: no hero has two different enemy-pick abilities 3 apart")
		_finish()
		return
	var hero_id: String = str(case["id"])
	var rig: Dictionary = {}
	for state in _heroes():
		rig["hero:%s" % str(state["id"])] = int(case["roll"]) if str(state["id"]) == hero_id else 9
	for state in _scene.combat_manager.get_enemy_states():
		rig["enemy:%s" % str(state["id"])] = 7
	_scene.dice_tray_3d.set_rigged_results(rig)
	await _scene._begin_targeting_phase()
	if int(_scene.turn_phase) == int(_scene.PHASE_TARGETING):
		await _scene._auto_assign_pending_targets(false)
	_expect(int(_scene.turn_phase) == int(_scene.PHASE_READY_TO_END), "fixture: the round is ready to end after the roll")
	var hero: Dictionary = _scene._find_state_by_id(_heroes(), hero_id)
	var roll_before: int = int(_scene._get_effective_roll_for_state(hero, hero_id))
	var ability_before: String = str(_ability(hero, roll_before).get("ability_name", ""))
	var old_target: String = str(hero.get("selected_target_id", ""))
	_expect(roll_before == int(case["roll"]), "fixture: the hero acts on its rigged roll (got %d)" % roll_before)
	_expect(old_target != "" and int(hero.get("cast_stamp", 0)) > 0, "fixture: the hero has a target and a place in the order before the Nudge")
	_expect(_scene.combat_manager.get_enemy_states().size() >= 2, "fixture: at least two enemies, so the new pick is not made automatically")
	_scene.protocol_points = 10
	_scene._update_protocol_bar()
	for i in 6:
		await process_frame

	var log_mark: int = diag().recent_errors().size()
	var code_mark: int = _state_code_errors()

	# The real button, then the real tap handler on the hero.
	_protocol._on_nudge_button_pressed()
	_expect(int(_scene.turn_phase) == int(_scene.PHASE_NUDGE_PICK), "Nudge arms and waits for a tap")
	_protocol.handle_hero_card_pressed(hero_id)
	if _break == "stale_target":
		hero["selected_target_id"] = old_target
	# Everything that redraws after a Nudge, more than once.
	for i in 3:
		_scene._card_view.refresh_all_cards()
		_scene._on_die_values_changed()
		for j in 4:
			await process_frame

	var roll_after: int = int(_scene._get_effective_roll_for_state(hero, hero_id))
	var ability_after: String = str(_ability(hero, roll_after).get("ability_name", ""))
	_expect(roll_after == roll_before + NUDGE and ability_after != ability_before, "the Nudge changes the hero's ability (%s -> %s)" % [ability_before, ability_after])
	_expect((_scene.pending_manual_target_ids as Array).has(hero_id) and int(hero.get("cast_stamp", 0)) == 0, "the nudged hero waits for a new target, out of the order")
	_expect(str(hero.get("selected_target_id", "")) == "", "the nudged hero holds no target while it waits (got '%s')" % str(hero.get("selected_target_id", "")))
	var after_nudge: PackedStringArray = _new_entries(log_mark)
	_expect(after_nudge.is_empty(), "the Nudge logs no warning or error (%d logged, first: %s)" % [after_nudge.size(), after_nudge[0] if not after_nudge.is_empty() else ""])
	_expect(_state_code_errors() == code_mark, "the state code's error list is unchanged by the Nudge")

	# The new pick, then the round: still nothing logged.
	hero["selected_target_id"] = ""
	_scene._select_targeting_hero(hero_id)
	var legal: Array = _scene.legal_target_ids
	_expect(not legal.is_empty(), "the nudged hero's new ability has targets to pick")
	if not legal.is_empty():
		_scene._assign_target_to_active_hero(str(legal[0]), str(_scene.legal_target_side))
	if int(_scene.turn_phase) == int(_scene.PHASE_TARGETING):
		await _scene._auto_assign_pending_targets(false)
	_expect(int(hero.get("cast_stamp", 0)) > 0, "the new pick puts the hero back in the order")
	if int(_scene.turn_phase) == int(_scene.PHASE_READY_TO_END):
		await _scene._resolve_current_turn()
	var cast_order: PackedStringArray = []
	for text in _new_entries(log_mark):
		if text.contains("[CAST_ORDER]"):
			cast_order.append(text)
	_expect(cast_order.is_empty(), "no cast-order warning from the Nudge through the end of the round (%d logged)" % cast_order.size())
	_finish()


func _finish() -> void:
	for error in _errors:
		print("[NUDGE_CAST_ORDER] FAIL - %s" % error)
	print("[NUDGE_CAST_ORDER] %s" % ("PASS" if _errors.is_empty() else "FAIL - %d check(s)" % _errors.size()))
	root.get_node("/root/SaveManager").clear_run_save()
	if current_scene != null:
		current_scene.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)
