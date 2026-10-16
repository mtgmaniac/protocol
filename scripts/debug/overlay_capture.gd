# UI unification: captures one overlay over the squad-select screen. Windowed only.
#   <godot> --path . --script res://scripts/debug/overlay_capture.gd \
#     --capture-overlay=briefing|boss_alert|discard|state_code \
#     --capture-output=<png> [--capture-window=WxH]
# Scripts are loaded at run time (after the autoloads exist): a preload of an
# overlay that names an autoload fails to compile under --script, which is why
# operation_briefing_capture.gd no longer runs.
extends SceneTree

var _overlay := "briefing"
var _output := "res://debug_artifacts/ui_unify/overlay.png"


func _initialize() -> void:
	for arg: String in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--capture-overlay="):
			_overlay = arg.trim_prefix("--capture-overlay=")
		elif arg.begins_with("--capture-output="):
			_output = arg.trim_prefix("--capture-output=")
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("/root/GameState")
	game_state.call("start_run", ["combat", "engineer", "medic"], "facility")
	change_scene_to_file("res://scenes/ui/UnitSelect.tscn")
	for _i in range(30):
		await process_frame
	var host: Node = current_scene
	match _overlay:
		"briefing", "boss_alert":
			var overlay: Control = (load("res://scripts/ui/operation_briefing_overlay.gd") as Script).new()
			root.add_child(overlay)
			if _overlay == "briefing":
				overlay.call("present_deployment", "facility")
			else:
				overlay.call("present_boss_alert", "Scrapmaster", "Rebuilds a fallen drone once per round. It returns at half HP.")
		"discard":
			var data: Node = root.get_node("/root/DataManager")
			var held: Array = []
			for id: String in ["patch_kit", "calibration_chip", "scrap_plate", "grounding_clip"]:
				held.append(data.call("get_item", id))
			var incoming: Resource = data.call("get_item", "archive_cascade")
			var menu_script: Script = load("res://scripts/ui/loadout_menu.gd")
			menu_script.call("open_discard", host, held, incoming, func(_choice: Variant) -> void: pass)
			# ui-fix: pick the first held item so CONFIRM DISCARD shows its live (destructive) state.
			var menu: Object = menu_script.get("_active")
			if menu != null:
				menu.call("_on_discard_row_tapped", held[0])
		"state_code":
			(load("res://scripts/ui/state_code_panel.gd") as Script).call("open", host)
	for _i in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path(_output) if _output.begins_with("res://") else _output
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	root.get_texture().get_image().save_png(path)
	print("[OVERLAY_CAPTURE] Saved: %s" % path)
	quit(0)
