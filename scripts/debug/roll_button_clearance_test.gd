# Headless regression: the ROLL / END TURN button must never sit on top of a
# settled die. The button is centred in the combat zone at z_index 10 and the
# dice settle into two fixed rows inside the same zone, so when the zone is
# short the button's 168px band overlaps the enemy row and a die renders
# partly behind it (reported 2026-09-02 at 1080x2400).
# Run: godot --headless --path . -s scripts/debug/roll_button_clearance_test.gd
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SQUAD := ["combat", "engineer", "medic"]
# The gap the layout is authored to leave (BattleLayout.DICE_BUTTON_GAP_PX is
# 54) minus the slack the clamp is allowed to eat when the combat zone is too
# short to honour it in full. Measured 47px at 1080x2400 after the projected
# die height was corrected; it was 29px before, which is where "a die renders
# partly behind the button" came from. A floor, not a target: LOWERING it
# loosens the check.
const MIN_CLEARANCE_PX := 40.0

var _errors: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[ROLL_CLEARANCE] Starting ROLL-button / dice overlap regression")
	# Pin the design space to the shipped portrait viewport. The project stretch
	# aspect is "expand", so a headless window of any other shape widens the
	# design space and the measurement stops being about 1080x2400.
	get_root().size = Vector2i(1080, 2400)
	get_root().content_scale_size = Vector2i(1080, 2400)
	var gs: Node = root.get_node("/root/GameState")
	var dmgr: Node = root.get_node("/root/DataManager")
	gs.call("start_run", SQUAD, str(dmgr.call("get_operation_order")[0]))
	gs.call("advance_to_next_battle")
	change_scene_to_file(BATTLE_SCENE)
	var retries := 180
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE:
			break
	await create_timer(1.0).timeout

	var roll_button: Button = current_scene.get_node_or_null("%RollButton") as Button
	if roll_button == null:
		_errors.append("no RollButton in the battle scene")
		_finish()
		return
	var tray: Node = current_scene.get_node_or_null("%DiceTray3D")
	if roll_button.visible and not roll_button.disabled:
		roll_button.emit_signal("pressed")
		if tray != null and tray.has_signal("roll_finished"):
			await tray.roll_finished
		else:
			await create_timer(2.0).timeout
	# Put the board in the state the overlap was reported in: dice settled and
	# the button back over the tray ("End Turn", PHASE_READY_TO_END). Set
	# directly rather than driving a full targeting pass — the geometry is what
	# is under test, and the button's rect is produced by its CenterContainer
	# either way.
	roll_button.visible = true
	roll_button.disabled = false
	roll_button.text = "End Turn"
	var layout: Object = current_scene.get("_layout")
	if layout != null:
		layout.call("layout_dice_from_combat_zone")
	await process_frame
	await create_timer(0.6).timeout

	var tray3d: Node = current_scene.get("dice_tray_3d")
	if tray3d == null:
		_errors.append("no dice tray")
		_finish()
		return
	var button_rect: Rect2 = roll_button.get_global_rect()
	print("[ROLL_CLEARANCE] button rect: %s (visible=%s)" % [str(button_rect), str(roll_button.visible)])

	var checked: int = 0
	for side in ["hero", "enemy"]:
		var rolls: Dictionary = current_scene.get("hero_rolls") if side == "hero" else current_scene.get("enemy_rolls")
		for unit_id_variant in rolls.keys():
			var unit_id: String = str(unit_id_variant)
			var die_rect: Rect2 = tray3d.call("get_die_screen_bounds", side, unit_id)
			if die_rect.size.x <= 0.0 or is_inf(die_rect.position.x):
				continue
			checked += 1
			var overlap: Rect2 = button_rect.intersection(die_rect)
			# Only dice that share the button's x-band can be hidden by it; for
			# those the vertical gap is the clearance.
			var shares_column: bool = die_rect.end.x > button_rect.position.x and die_rect.position.x < button_rect.end.x
			var gap: float = button_rect.position.y - die_rect.end.y if die_rect.get_center().y < button_rect.get_center().y else die_rect.position.y - button_rect.end.y
			print("[ROLL_CLEARANCE]   %s/%s die=%s overlap=%.1fx%.1f column=%s gap=%.1f"
				% [side, unit_id, str(die_rect), overlap.size.x, overlap.size.y, str(shares_column), gap])
			if overlap.size.x > 1.0 and overlap.size.y > 1.0:
				_errors.append("%s die '%s' is obscured by the ROLL button (overlap %.0fx%.0f px)"
					% [side, unit_id, overlap.size.x, overlap.size.y])
			elif shares_column and gap < MIN_CLEARANCE_PX:
				_errors.append("%s die '%s' clears the ROLL button by only %.0fpx (floor %.0f)"
					% [side, unit_id, gap, MIN_CLEARANCE_PX])
	if checked == 0:
		_errors.append("no settled dice were projectable - the test measured nothing")
	_finish()


func _finish() -> void:
	if _errors.is_empty():
		print("[ROLL_CLEARANCE] PASS")
	else:
		for e in _errors:
			print("[ROLL_CLEARANCE] FAIL: " + e)
	quit(0 if _errors.is_empty() else 1)
