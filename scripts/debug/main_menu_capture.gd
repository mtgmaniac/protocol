# Captures the main menu to disk. Non-headless only (needs a real renderer).
#   <godot> --path . --script res://scripts/debug/main_menu_capture.gd \
#     [--capture-output=...] [--capture-delay-ms=...] [--capture-window=WxH]
#     [--capture-run-save]   (write a run save first, so CONTINUE shows)
#     [--capture-new-game-confirm]   (press NEW GAME first: with a run save, its confirm)
extends SceneTree

const DEFAULT_OUTPUT := "res://debug_artifacts/main_menu/latest.png"
# The logo boot-in runs before the buttons arrive — wait it out.
const DEFAULT_DELAY_MS := 4500
const SCENE := "res://scenes/ui/MainMenu.tscn"


func _initialize() -> void:
	call_deferred("_run_capture")


func _run_capture() -> void:
	var config: Dictionary = _parse_args()
	if config.has("window"):
		load("res://scripts/debug/capture_window.gd").apply(root, config["window"])
	await process_frame
	var save_manager: Node = root.get_node("/root/SaveManager")
	save_manager.set("data", save_manager.call("default_data"))
	save_manager.get("data")["tutorial_done"] = true
	if bool(config.get("run_save", false)):
		var game_state: Node = root.get_node("/root/GameState")
		game_state.call("start_run", ["combat", "engineer", "medic"], "facility")
		game_state.set("current_battle", 1)
		save_manager.call("checkpoint_run", "battle")
	change_scene_to_file(SCENE)
	await create_timer(float(config.get("delay_ms", DEFAULT_DELAY_MS)) / 1000.0).timeout
	if bool(config.get("new_game_confirm", false)):
		(current_scene.get("_new_game_button") as Button).pressed.emit()
		await create_timer(0.3).timeout
	var absolute_output: String = ProjectSettings.globalize_path(str(config.get("output", DEFAULT_OUTPUT)))
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		push_error("Main-menu capture failed: null viewport image (run without --headless)")
		quit(1)
		return
	var save_result: Error = image.save_png(absolute_output)
	if save_result != OK:
		push_error("Main-menu capture failed: %s" % error_string(save_result))
		quit(1)
		return
	print("[MAIN_MENU_CAPTURE] Saved: %s" % absolute_output)
	quit(0)


func _parse_args() -> Dictionary:
	var config := {"output": DEFAULT_OUTPUT, "delay_ms": DEFAULT_DELAY_MS}
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--capture-output="):
			config["output"] = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-delay-ms="):
			config["delay_ms"] = maxi(int(arg.get_slice("=", 1)), 100)
		elif arg.begins_with("--capture-window="):
			var parts: PackedStringArray = arg.get_slice("=", 1).split("x", false)
			if parts.size() >= 2:
				config["window"] = Vector2i(int(parts[0]), int(parts[1]))
		elif arg == "--capture-run-save":
			config["run_save"] = true
		elif arg == "--capture-new-game-confirm":
			config["new_game_confirm"] = true
	return config
