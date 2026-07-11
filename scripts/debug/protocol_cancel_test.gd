# Headless regression for §1 (Batch 4): a Protocol action ARMS but does not
# commit, and any off-target click cancels the armed pick — passing through —
# while spending ZERO Protocol.
# Run: godot --headless --path . -s scripts/debug/protocol_cancel_test.gd
# Repro (manual): roll → tap Set → tap Nudge = Set cancels, Nudge arms; tap Set
# again = toggles off; tap item box = Set cancels + box opens; tap empty/enemy =
# Set cancels. No Protocol is spent on any of these.
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SQUAD := ["combat", "engineer", "medic"]

var _errors: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[PROTOCOL_CANCEL] Starting protocol-cancellation regression")
	var gs: Node = root.get_node("/root/GameState")
	var dm: Node = root.get_node("/root/DataManager")
	var op_id: String = str(dm.call("get_operation_order")[0])
	gs.call("start_run", SQUAD, op_id)
	gs.call("advance_to_next_battle")
	change_scene_to_file(BATTLE_SCENE)

	var retries := 180
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE:
			break
	await create_timer(1.0).timeout

	# Roll the dice so a pick can be armed.
	var roll_button: Button = current_scene.get_node_or_null("%RollButton") as Button
	if roll_button != null and roll_button.visible and not roll_button.disabled:
		var tray: Node = current_scene.get_node_or_null("%DiceTray3D")
		roll_button.emit_signal("pressed")
		if tray != null and tray.has_signal("roll_finished"):
			await tray.roll_finished
		else:
			await create_timer(2.0).timeout
	await create_timer(0.4).timeout

	var protocol: Node = current_scene.get("_protocol")
	if protocol == null:
		_errors.append("no _protocol module on battle scene")
		_finish()
		return

	# Fund the pool so every action can arm; record the baseline.
	current_scene.set("protocol_points", 10)
	current_scene.call("_update_protocol_bar")
	var pp0: int = int(current_scene.get("protocol_points"))

	var set_pick: int = int(current_scene.get("PHASE_SET_PICK"))
	var nudge_pick: int = int(current_scene.get("PHASE_NUDGE_PICK"))

	# CASE 1 — Set → Nudge: Set cancels, Nudge arms, no Protocol spent.
	protocol.call("_on_set_button_pressed")
	_expect(_phase() == set_pick, "case1: Set arms SET_PICK (got %s)" % _phase_name())
	protocol.call("_on_nudge_button_pressed")
	_expect(_phase() == nudge_pick, "case1: Nudge arms after cancelling Set (got %s)" % _phase_name())
	_expect(int(current_scene.get("protocol_points")) == pp0, "case1: no Protocol spent")

	# CASE 2 — same button toggles off (Nudge → Nudge = nothing armed).
	protocol.call("_on_nudge_button_pressed")
	_expect(not bool(protocol.call("in_roll_modifier_pick")), "case2: re-press toggles off (got %s)" % _phase_name())
	_expect(int(current_scene.get("protocol_points")) == pp0, "case2: no Protocol spent")

	# CASE 3 — Set → same Set again: cancelled, nothing armed.
	protocol.call("_on_set_button_pressed")
	_expect(_phase() == set_pick, "case3: Set arms")
	protocol.call("_on_set_button_pressed")
	_expect(not bool(protocol.call("in_roll_modifier_pick")), "case3: same Set toggles off")
	_expect(int(current_scene.get("protocol_points")) == pp0, "case3: no Protocol spent")

	# CASE 4 — Set → empty space (unhandled press): cancels the pick.
	protocol.call("_on_set_button_pressed")
	_expect(_phase() == set_pick, "case4: Set arms")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	var consumed: bool = bool(protocol.call("handle_unhandled_input", ev))
	_expect(consumed, "case4: empty-space press consumed as cancel")
	_expect(not bool(protocol.call("in_roll_modifier_pick")), "case4: pick cancelled by empty space")
	_expect(int(current_scene.get("protocol_points")) == pp0, "case4: no Protocol spent")

	# CASE 5 — Set → enemy card: cancels (enemy is never a valid pick target).
	protocol.call("_on_set_button_pressed")
	_expect(_phase() == set_pick, "case5: Set arms")
	var enemy_states: Array = current_scene.get("combat_manager").call("get_enemy_states")
	if not enemy_states.is_empty():
		var enemy_id: String = str((enemy_states[0] as Dictionary).get("id", ""))
		current_scene.call("_on_enemy_card_pressed", enemy_id)
		_expect(not bool(protocol.call("in_roll_modifier_pick")), "case5: enemy tap cancels the pick")
		_expect(int(current_scene.get("protocol_points")) == pp0, "case5: no Protocol spent")

	# CASE 6 — Set → item box: cancels the pick (box then opens).
	protocol.call("_on_set_button_pressed")
	_expect(_phase() == set_pick, "case6: Set arms")
	protocol.call("_on_item_button_pressed_menu")
	_expect(not bool(protocol.call("in_roll_modifier_pick")), "case6: item box cancels the pick")
	_expect(int(current_scene.get("protocol_points")) == pp0, "case6: no Protocol spent")

	# CASE 7 — Set → valid die: NOT cancelled (existing behaviour preserved).
	# Re-arm Set and confirm a valid hero die opens the value pick (still SET_PICK).
	protocol.call("_on_set_button_pressed")
	if _phase() == set_pick:
		var hero_id: String = _first_valid_hero_id()
		if hero_id != "":
			var handled: bool = bool(protocol.call("handle_hero_card_pressed", hero_id))
			_expect(handled, "case7: valid die tap consumed")
			_expect(_phase() == set_pick, "case7: valid die keeps SET_PICK (opens value pick)")
			_expect(str(protocol.get("_pending_set_hero_id")) == hero_id, "case7: pending set hero recorded")

	_finish()


func _phase() -> int:
	return int(current_scene.get("turn_phase"))


func _phase_name() -> String:
	return str(_phase())


func _first_valid_hero_id() -> String:
	var hero_rolls: Dictionary = current_scene.get("hero_rolls")
	for hs_variant in current_scene.get("combat_manager").call("get_hero_states"):
		var hs: Dictionary = hs_variant
		if bool(hs.get("dead", false)):
			continue
		if int(hs.get("die_freeze_turns", 0)) > 0:
			continue
		if hero_rolls.has(str(hs.get("id", ""))):
			return str(hs.get("id", ""))
	return ""


func _expect(cond: bool, label: String) -> void:
	if not cond:
		_errors.append(label)


func _finish() -> void:
	if _errors.is_empty():
		print("[PROTOCOL_CANCEL] PASS — arm/cancel edges correct, zero Protocol spent on cancels")
	else:
		for e in _errors:
			print("[PROTOCOL_CANCEL] FAIL: " + e)
	quit(0 if _errors.is_empty() else 1)
