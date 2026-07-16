# Captures the Build F unlock screen to disk (mirrors run_end_capture.gd).
# Non-headless only (needs a real renderer). DevContext isolation covers the
# -s launch, so the real profile is untouchable.
#   <godot> --path . --script res://scripts/debug/unlock_screen_capture.gd \
#     --capture-scenario=single|fat|boss [--capture-output=...] [--capture-delay-ms=...]
#
# Scenarios (the Build F deliverable set):
#   single — a loss that crossed ONE gate (a few NEW ITEMS, no scroll)
#   fat    — a facility clear after many banked battles: BOSS RELIC + NEW UNIT
#            + NEW OPERATION + NEW RELICS + NEW ITEMS, scrolling
#   boss   — a boss-relic-only run end (everything else already owned)
extends SceneTree

const DEFAULT_OUTPUT := "res://debug_artifacts/unlock_screen/latest.png"
const DEFAULT_DELAY_MS := 1500
const SCENE := "res://scenes/ui/UnlockScreen.tscn"


func _initialize() -> void:
	call_deferred("_run_capture")


func _run_capture() -> void:
	var config: Dictionary = _parse_args()
	await process_frame
	var save_manager: Node = root.get_node("/root/SaveManager")
	var data_manager: Node = root.get_node("/root/DataManager")
	save_manager.call("dev_reset_profile")
	var profile: Dictionary = save_manager.get("data")
	match str(config.get("scenario", "single")):
		"single":
			(profile["stats"] as Dictionary)["battles_fought"] = 3
			save_manager.call("record_run_finished", "defeat", "facility", 3)
		"fat":
			(profile["stats"] as Dictionary)["battles_fought"] = 45
			save_manager.call("record_run_finished", "victory", "facility", 10)
		"boss":
			# Everything but the boss relic already owned — the delta is ONE
			# gold card.
			(profile["unlocks"] as Dictionary)["item_gates_awarded"] = int(data_manager.call("unlock_gate_count"))
			(profile["unlocks"] as Dictionary)["hero_ladder_rung"] = int(save_manager.get("MAX_HERO_LADDER_RUNG"))
			(profile["unlocks"] as Dictionary)["heroes"] = (save_manager.get("ALL_HEROES") as Array).duplicate()
			(profile["unlocks"] as Dictionary)["operations"] = (save_manager.get("OPERATION_CHAIN") as Array).duplicate()
			save_manager.call("record_run_finished", "victory", "facility", 10)
		_:
			push_error("Unknown --capture-scenario (single|fat|boss)")
			quit(1)
			return
	if (save_manager.call("check_new_unlocks") as Array).is_empty():
		push_error("Capture scenario produced an empty delta - the screen would be skipped")
		quit(1)
		return
	change_scene_to_file(SCENE)
	await create_timer(float(config.get("delay_ms", DEFAULT_DELAY_MS)) / 1000.0).timeout
	if bool(config.get("scroll_end", false)) and current_scene != null:
		var scroll: ScrollContainer = current_scene.get_node_or_null("%Scroll")
		if scroll != null:
			scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
			await process_frame
			await process_frame
	var absolute_output: String = ProjectSettings.globalize_path(str(config.get("output", DEFAULT_OUTPUT)))
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		push_error("Unlock capture failed: null viewport image (run without --headless)")
		quit(1)
		return
	var save_result: Error = image.save_png(absolute_output)
	if save_result != OK:
		push_error("Unlock capture failed: %s" % error_string(save_result))
		quit(1)
		return
	print("[UNLOCK_CAPTURE] Saved: %s" % absolute_output)
	quit(0)


func _parse_args() -> Dictionary:
	var config := {"output": DEFAULT_OUTPUT, "delay_ms": DEFAULT_DELAY_MS}
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--capture-output="):
			config["output"] = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-delay-ms="):
			config["delay_ms"] = maxi(int(arg.get_slice("=", 1)), 100)
		elif arg.begins_with("--capture-scenario="):
			config["scenario"] = arg.get_slice("=", 1)
		elif arg == "--capture-scroll-end":
			config["scroll_end"] = true
	return config
