# Captures the run-end screen (victory / defeat) to disk, mirroring
# choice_screen_capture.gd. Non-headless only (needs a real renderer).
#   <godot> --path . --script res://scripts/debug/run_end_capture.gd \
#     --capture-result=victory|defeat [--capture-operation=facility]
#     [--capture-output=...] [--capture-delay-ms=...] [--capture-window=WxH]
extends SceneTree

const DEFAULT_OUTPUT := "res://debug_artifacts/run_end/latest.png"
const DEFAULT_DELAY_MS := 1500
const SCENE := "res://scenes/ui/RunEndScreen.tscn"


func _initialize() -> void:
	call_deferred("_run_capture")


func _run_capture() -> void:
	var config: Dictionary = _parse_args()
	if config.has("window"):
		load("res://scripts/debug/capture_window.gd").apply(root, config["window"])
	await process_frame
	var gs: Node = root.get_node("/root/GameState")
	var save_manager: Node = root.get_node("/root/SaveManager")
	if bool(config.get("unlock", false)):
		# Deterministic in-memory run-end award for validating the centered
		# UNLOCKED composition. Mark the operation origin seen so its required
		# acknowledgement overlay does not cover the panel in this capture.
		save_manager.call("dev_reset_profile")
	var operation_id: String = str(config.get("operation", "facility"))
	gs.call("start_run", ["combat", "avalanche", "medic"], operation_id)
	var result: String = str(config.get("result", "victory"))
	gs.set("last_run_result", result)
	# The battle the run ended on (the in-operation header shows it).
	gs.set("current_battle", 10 if result == "victory" else 6)
	# Representative run-report rows (duration / turns / fallen): a defeat is a
	# full wipe, a victory here shows one casualty so the Fallen line renders
	# both populated and "none" across the two capture results.
	gs.set("run_total_turns", 34)
	gs.set("run_start_unix", int(Time.get_unix_time_from_system()) - 1520)
	if result == "defeat":
		gs.set("run_hero_deaths", ["combat", "avalanche", "medic"])
	else:
		gs.set("run_hero_deaths", ["medic"])
		# Victory: one hero down at the boss's end (G-76).
		gs.set("deaths_last_battle", ["medic"])
	# The report rows (G-76, G-78): some run XP and one relic on either result.
	gs.set("unit_xp", {"combat": 240, "avalanche": 210, "medic": 185} if result == "victory" else {"combat": 120, "avalanche": 95, "medic": 80})
	gs.set("relics", ["scrapConverter"])
	if bool(config.get("unlock", false)):
		save_manager.call("record_run_finished", result, operation_id, 10)
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
		elif arg.begins_with("--capture-operation="):
			config["operation"] = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-window="):
			var parts: PackedStringArray = arg.get_slice("=", 1).split("x")
			config["window"] = Vector2i(int(parts[0]), int(parts[1]))
		elif arg == "--capture-unlock":
			config["unlock"] = true
	return config
