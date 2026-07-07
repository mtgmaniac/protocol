# Captures the between-battle choice screens (Route Fork / Intercept) to disk.
# Mirrors home_screen_capture.gd's pattern.
#   <godot> --path . --script res://scripts/debug/choice_screen_capture.gd \
#     --capture-screen=fork|intercept [--capture-output=...] [--capture-delay-ms=...]
extends SceneTree

const DEFAULT_OUTPUT := "res://debug_artifacts/choice_ui/latest.png"
const DEFAULT_DELAY_MS := 900
const SCENES := {
	"fork": "res://scenes/ui/RouteForkScreen.tscn",
	"intercept": "res://scenes/ui/InterceptScreen.tscn",
}


func _initialize() -> void:
	call_deferred("_run_capture")


func _run_capture() -> void:
	var config: Dictionary = _parse_args()
	await process_frame
	# A live run so the screen has an operation / battle context to read.
	root.get_node("/root/GameState").call("start_run", ["combat", "avalanche", "medic"], "facility")
	root.get_node("/root/GameState").call("advance_to_next_battle")
	var screen: String = str(config.get("screen", "fork"))
	change_scene_to_file(str(SCENES.get(screen, SCENES["fork"])))
	await create_timer(float(config.get("delay_ms", DEFAULT_DELAY_MS)) / 1000.0).timeout
	var output_path: String = str(config.get("output", DEFAULT_OUTPUT))
	var absolute_output: String = ProjectSettings.globalize_path(output_path)
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var image: Image = root.get_viewport().get_texture().get_image()
	var save_result: Error = image.save_png(absolute_output)
	if save_result != OK:
		push_error("Choice capture failed: %s" % error_string(save_result))
		quit(1)
		return
	print("[CHOICE_UI_CAPTURE] Saved: %s" % absolute_output)
	quit(0)


func _parse_args() -> Dictionary:
	var config := {"output": DEFAULT_OUTPUT, "delay_ms": DEFAULT_DELAY_MS}
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--capture-output="):
			config["output"] = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-delay-ms="):
			config["delay_ms"] = maxi(int(arg.get_slice("=", 1)), 100)
		elif arg.begins_with("--capture-screen="):
			config["screen"] = arg.get_slice("=", 1)
	return config
