# Launches a predictable battle, captures the rendered viewport to disk, and exits.
extends SceneTree

const DEFAULT_OUTPUT := "res://debug_artifacts/battle_ui/latest.png"
const DEFAULT_OPERATION_ID := "facility"
const DEFAULT_BATTLE_NUMBER := 1
const DEFAULT_CAPTURE_DELAY_MS := 1200
const DEFAULT_SQUAD := ["shield", "avalanche", "pulse"]
const DEFAULT_CAPTURE_ROLLED := false


func _initialize() -> void:
	call_deferred("_run_capture")


func _run_capture() -> void:
	var config: Dictionary = _parse_args()
	_prepare_run(config)
	change_scene_to_file("res://scenes/battle/BattleScene.tscn")
	await _wait_for_battle_scene(config)
	var output_path: String = str(config.get("output", DEFAULT_OUTPUT))
	var absolute_output: String = _resolve_output_path(output_path)
	var save_result: Error = _capture_viewport_to_file(absolute_output)
	if save_result != OK:
		push_error("Battle UI capture failed: %s" % error_string(save_result))
		quit(1)
		return
	print("[BATTLE_UI_CAPTURE] Saved screenshot to: %s" % absolute_output)
	quit(0)


func _parse_args() -> Dictionary:
	var config := {
		"output": DEFAULT_OUTPUT,
		"operation_id": DEFAULT_OPERATION_ID,
		"battle_number": DEFAULT_BATTLE_NUMBER,
		"delay_ms": DEFAULT_CAPTURE_DELAY_MS,
		"rolled": DEFAULT_CAPTURE_ROLLED,
	}
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--capture-output="):
			config["output"] = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-operation="):
			config["operation_id"] = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-battle="):
			config["battle_number"] = maxi(int(arg.get_slice("=", 1)), 1)
		elif arg.begins_with("--capture-delay-ms="):
			config["delay_ms"] = maxi(int(arg.get_slice("=", 1)), 100)
		elif arg == "--capture-rolled":
			config["rolled"] = true
	return config


func _prepare_run(config: Dictionary) -> void:
	var operation_id: String = str(config.get("operation_id", DEFAULT_OPERATION_ID))
	_game_state().start_run(DEFAULT_SQUAD, operation_id)
	var battle_number: int = int(config.get("battle_number", DEFAULT_BATTLE_NUMBER))
	for _i in range(battle_number):
		_game_state().advance_to_next_battle()


func _wait_for_battle_scene(config: Dictionary) -> void:
	var delay_ms: int = int(config.get("delay_ms", DEFAULT_CAPTURE_DELAY_MS))
	var retries := 120
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/battle/BattleScene.tscn":
			break
	await create_timer(float(delay_ms) / 1000.0).timeout
	if bool(config.get("rolled", DEFAULT_CAPTURE_ROLLED)):
		await _capture_after_roll()
	await process_frame
	await RenderingServer.frame_post_draw


func _capture_after_roll() -> void:
	if current_scene == null:
		return
	var roll_button: Button = current_scene.get_node_or_null("%RollButton") as Button
	if roll_button == null or roll_button.disabled or not roll_button.visible:
		return
	var dice_tray: Node = current_scene.get_node_or_null("%DiceTray3D")
	roll_button.emit_signal("pressed")
	if dice_tray != null and dice_tray.has_signal("roll_finished"):
		await dice_tray.roll_finished
	else:
		await create_timer(2.0).timeout
	await create_timer(0.4).timeout


func _resolve_output_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path


func _capture_viewport_to_file(absolute_output: String) -> Error:
	var directory: String = absolute_output.get_base_dir()
	var make_dir_result: Error = DirAccess.make_dir_recursive_absolute(directory)
	if make_dir_result != OK:
		return make_dir_result
	var image: Image = root.get_texture().get_image()
	if image == null:
		return ERR_CANT_ACQUIRE_RESOURCE
	return image.save_png(absolute_output)


func _game_state() -> Node:
	return root.get_node("/root/GameState")
