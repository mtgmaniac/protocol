# Captures the run-start STARTING DIRECTIVE picker with all boss relics.
# Run windowed: <godot> --path . --script res://scripts/debug/directive_picker_capture.gd
extends SceneTree

const OUTPUT := "res://debug_artifacts/battle_ui/directive_picker.png"


func _initialize() -> void:
	var window := Vector2i(540, 1200)
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--capture-window="):
			var parts: PackedStringArray = arg.get_slice("=", 1).split("x", false)
			window = Vector2i(int(parts[0]), int(parts[1]))
	load("res://scripts/debug/capture_window.gd").apply(root, window)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	change_scene_to_file("res://scenes/ui/UnitSelect.tscn")
	await create_timer(1.2).timeout
	if current_scene != null and current_scene.has_method("_open_directive_picker"):
		current_scene.call("_open_directive_picker", ["scrapConverter", "bloodFrenzy", "firewallHack", "hereticSignal", "tectonicCharge"])
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var out: String = OUTPUT
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--capture-output="):
			out = arg.get_slice("=", 1)
	var path: String = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var image: Image = root.get_texture().get_image()
	if image != null:
		image.save_png(path)
		print("[DIRECTIVE_CAPTURE] saved %s" % path)
	quit(0)
