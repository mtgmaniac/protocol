# Captures the main menu to disk, optionally with the post-run feedback nudge
# armed (mirrors run_end_capture.gd). Non-headless only (needs a real renderer).
#   <godot> --path . --script res://scripts/debug/main_menu_capture.gd \
#     [--capture-nudge] [--capture-output=...] [--capture-delay-ms=...]
extends SceneTree

const DEFAULT_OUTPUT := "res://debug_artifacts/main_menu/latest.png"
# The logo boot-in runs before the buttons (and the nudge) arrive — wait it out.
const DEFAULT_DELAY_MS := 4500
const SCENE := "res://scenes/ui/MainMenu.tscn"


func _initialize() -> void:
	call_deferred("_run_capture")


func _run_capture() -> void:
	var config: Dictionary = _parse_args()
	await process_frame
	var save_manager: Node = root.get_node("/root/SaveManager")
	save_manager.set("data", save_manager.call("default_data"))
	save_manager.get("data")["tutorial_done"] = true
	if bool(config.get("nudge", false)):
		# One completed run, never nudged: the first-run cadence slot is due.
		(save_manager.get("data")["stats"] as Dictionary)["runs_finished"] = 1
	change_scene_to_file(SCENE)
	await create_timer(float(config.get("delay_ms", DEFAULT_DELAY_MS)) / 1000.0).timeout
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
		elif arg == "--capture-nudge":
			config["nudge"] = true
	return config
