# Captures the run-end screen (victory / defeat) to disk, mirroring
# choice_screen_capture.gd. Non-headless only (needs a real renderer).
#   <godot> --path . --script res://scripts/debug/run_end_capture.gd \
#     --capture-result=victory|defeat [--capture-output=...] [--capture-delay-ms=...]
extends SceneTree

const DEFAULT_OUTPUT := "res://debug_artifacts/run_end/latest.png"
const DEFAULT_DELAY_MS := 1500
const SCENE := "res://scenes/ui/RunEndScreen.tscn"


func _initialize() -> void:
	call_deferred("_run_capture")


func _run_capture() -> void:
	var config: Dictionary = _parse_args()
	await process_frame
	var gs: Node = root.get_node("/root/GameState")
	var save_manager: Node = root.get_node("/root/SaveManager")
	if bool(config.get("unlock", false)):
		# Deterministic in-memory run-end award for validating the centered
		# UNLOCKED composition. Mark the operation origin seen so its required
		# acknowledgement overlay does not cover the panel in this capture.
		save_manager.call("dev_reset_profile")
	gs.call("start_run", ["combat", "avalanche", "medic"], "facility")
	var result: String = str(config.get("result", "victory"))
	gs.set("last_run_result", result)
	if bool(config.get("unlock", false)):
		save_manager.call("record_run_finished", result, "facility", 10)
		save_manager.call("acknowledge_operation_origin", "hive")
	change_scene_to_file(SCENE)
	await create_timer(float(config.get("delay_ms", DEFAULT_DELAY_MS)) / 1000.0).timeout
	var absolute_output: String = ProjectSettings.globalize_path(str(config.get("output", DEFAULT_OUTPUT)))
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		push_error("Run-end capture failed: null viewport image (run without --headless)")
		quit(1)
		return
	var save_result: Error = image.save_png(absolute_output)
	if save_result != OK:
		push_error("Run-end capture failed: %s" % error_string(save_result))
		quit(1)
		return
	print("[RUN_END_CAPTURE] Saved: %s" % absolute_output)
	quit(0)


func _parse_args() -> Dictionary:
	var config := {"output": DEFAULT_OUTPUT, "delay_ms": DEFAULT_DELAY_MS}
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--capture-output="):
			config["output"] = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-delay-ms="):
			config["delay_ms"] = maxi(int(arg.get_slice("=", 1)), 100)
		elif arg.begins_with("--capture-result="):
			config["result"] = arg.get_slice("=", 1)
		elif arg == "--capture-unlock":
			config["unlock"] = true
	return config
