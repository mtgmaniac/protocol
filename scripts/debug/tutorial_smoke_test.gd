# Scripted end-to-end tutorial playthrough. Drives the same battle-scene entry
# points the real UI calls (roll, select die, assign target, nudge, end turn)
# and asserts that every TutorialController step advances and that every step
# which declares a spotlight actually resolves at least one hole rect.
# Run:
#   godot --headless --path . --script res://scripts/debug/tutorial_smoke_test.gd
extends SceneTree

const STEP_TIMEOUT_SECS := 20.0

var _errors: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gs: Node = root.get_node("/root/GameState")
	var sm: Node = root.get_node("/root/SceneManager")
	gs.call("start_tutorial_run")
	sm.call("go_to_battle")
	await _wait_frames(10)

	var scene: Node = current_scene
	if scene == null or scene.get("hero_card_views") == null:
		_fail("Battle scene failed to load for tutorial")
		return
	var controller: Node = _find_controller(scene)
	if controller == null:
		_fail("TutorialController not spawned in tutorial_mode")
		return

	# ── Walk the script ──────────────────────────────────────────────────────
	await _expect_step(controller, 0)

	# Steps 0-3: orientation taps.
	for _i in range(4):
		_check_holes(controller)
		controller.call("_next")
		await _wait_frames(3)

	# Step 4: Roll (gated on roll_pressed).
	await _expect_step(controller, 4)
	_check_holes(controller)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 5)

	# Steps 5-6: tray tour (tap), then inspect gate. The real gate is a
	# long-press InspectPopup; emit the same event the popup handler fires.
	_check_holes(controller)
	controller.call("_next")
	await _expect_step(controller, 6)
	_check_holes(controller)
	scene.emit_signal("tutorial_event", &"inspected", {"side": "hero"})
	await _expect_step(controller, 7)

	# Dice are still animating; targeting only opens in PHASE_TARGETING.
	await _wait_for_phase(scene, "targeting")
	_check_holes(controller)

	# Step 7: pick a hero die (gated on targeting_started).
	var hero_ids: Array = _living_ids(scene, true)
	var enemy_ids: Array = _living_ids(scene, false)
	if hero_ids.is_empty() or enemy_ids.is_empty():
		_fail("Tutorial battle has no hero/enemy states")
		return
	scene.call("_select_targeting_hero", hero_ids[0])
	await _expect_step(controller, 8)

	# Step 8: assign the enemy (gated on assigned).
	_check_holes(controller)
	scene.call("_assign_target_to_active_hero", enemy_ids[0], "enemy")
	await _expect_step(controller, 9)

	# Step 9: assign remaining dice until ready_to_end.
	_check_holes(controller)
	for hero_id in hero_ids.slice(1):
		scene.call("_select_targeting_hero", hero_id)
		await _wait_frames(2)
		scene.call("_assign_target_to_active_hero", enemy_ids[0], "enemy")
		await _wait_frames(2)
	await _expect_step(controller, 10)

	# Step 10: enemy readout tour (tap).
	_check_holes(controller)
	controller.call("_next")
	await _expect_step(controller, 11)

	# Step 11: End Turn (gated on turn_resolved — waits out feedback).
	_check_holes(controller)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 12)

	# Step 12: protocol tour (tap).
	_check_holes(controller)
	controller.call("_next")
	await _expect_step(controller, 13)

	# Step 13: roll again (gated on rolled — fires after dice settle).
	_check_holes(controller)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 14)

	# Step 14: protocol value (tap).
	_check_holes(controller)
	controller.call("_next")
	await _expect_step(controller, 15)

	# Step 15: Nudge Pulse (gated on nudged).
	await _wait_for_phase(scene, "targeting")
	_check_holes(controller)
	var pulse_id: String = _state_id_for_unit(scene, "pulse")
	if pulse_id == "":
		_fail("Pulse Tech state not found for nudge step")
		return
	scene.call("_on_nudge_button_pressed")
	await _wait_frames(2)
	scene.call("_apply_nudge", pulse_id)
	await _expect_step(controller, 16)

	# Steps 16-17: taps (band jump + reroll/set costs).
	for _i in range(2):
		_check_holes(controller)
		controller.call("_next")
		await _wait_frames(3)
	await _expect_step(controller, 18)

	# Step 18: fire Pulse (gated on assigned).
	_check_holes(controller)
	scene.call("_select_targeting_hero", pulse_id)
	await _wait_frames(2)
	scene.call("_assign_target_to_active_hero", enemy_ids[0], "enemy")
	await _expect_step(controller, 19)

	# Step 19: assign the rest + end turn (gated on won).
	_check_holes(controller)
	for hero_id in hero_ids:
		if hero_id == pulse_id:
			continue
		scene.call("_select_targeting_hero", hero_id)
		await _wait_frames(2)
		scene.call("_assign_target_to_active_hero", enemy_ids[0], "enemy")
		await _wait_frames(2)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 20)

	# Step 20: DRILL COMPLETE (tap_finish) → back to the main menu.
	_check_holes(controller)
	controller.call("_next")
	await _wait_frames(10)
	var gs2: Node = root.get_node("/root/GameState")
	if bool(gs2.get("tutorial_mode")):
		_errors.append("tutorial_mode still true after finish")

	if _errors.is_empty():
		print("[TUTORIAL_SMOKE] PASS — all 21 steps advanced, all spotlights resolved")
		quit(0)
	else:
		for e in _errors:
			push_error("[TUTORIAL_SMOKE] " + e)
		print("[TUTORIAL_SMOKE] FAIL — %d error(s)" % _errors.size())
		quit(1)


# ── Helpers ─────────────────────────────────────────────────────────────────

func _find_controller(scene: Node) -> Node:
	for child in scene.get_children():
		if child is TutorialController:
			return child
	return null


func _expect_step(controller: Node, index: int) -> void:
	var frames: int = int(STEP_TIMEOUT_SECS * 60.0)
	while frames > 0:
		frames -= 1
		await process_frame
		if int(controller.get("_step")) >= index:
			await _wait_frames(2)
			return
	_fail("Timed out waiting for tutorial step %d (at %d)" % [index, int(controller.get("_step"))])


func _wait_for_phase(scene: Node, phase: String) -> void:
	var frames: int = int(STEP_TIMEOUT_SECS * 60.0)
	while frames > 0:
		frames -= 1
		await process_frame
		if str(scene.get("turn_phase")) == phase:
			return
	_errors.append("Timed out waiting for phase %s" % phase)


# Every step that declares targets/fullscreen must produce at least one hole.
func _check_holes(controller: Node) -> void:
	var step: Dictionary = controller.call("_current")
	var wants_spotlight: bool = bool(step.get("fullscreen", false)) or not (step.get("targets", []) as Array).is_empty()
	if not wants_spotlight:
		return
	var holes: Array = controller.call("_compute_holes", step)
	if holes.is_empty():
		_errors.append("Step %d ('%s…') resolved NO spotlight holes" % [int(controller.get("_step")), str(step.get("text", "")).left(32)])


func _living_ids(scene: Node, heroes: bool) -> Array:
	var cm: Object = scene.get("combat_manager")
	var states: Array = cm.call("get_hero_states") if heroes else cm.call("get_enemy_states")
	var ids: Array = []
	for state_variant in states:
		var state: Dictionary = state_variant
		if not bool(state.get("dead", false)):
			ids.append(str(state.get("id", "")))
	return ids


func _state_id_for_unit(scene: Node, unit_id: String) -> String:
	var cm: Object = scene.get("combat_manager")
	for state_variant in cm.call("get_hero_states"):
		var state: Dictionary = state_variant
		var unit: Object = state.get("unit", null) as Object
		if unit != null and str(unit.get("id")) == unit_id:
			return str(state.get("id", ""))
	return ""


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _fail(message: String) -> void:
	_errors.append(message)
	push_error("[TUTORIAL_SMOKE] " + message)
	print("[TUTORIAL_SMOKE] FAIL — %d error(s)" % _errors.size())
	quit(1)
