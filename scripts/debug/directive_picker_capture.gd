# Captures the run-start STARTING DIRECTIVE picker with all boss relics.
# Run windowed: <godot> --path . --script res://scripts/debug/directive_picker_capture.gd
extends SceneTree

const OUTPUT := "res://debug_artifacts/battle_ui/directive_picker.png"


func _initialize() -> void:
	root.size = Vector2i(540, 1200)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	change_scene_to_file("res://scenes/ui/UnitSelect.tscn")
	await create_timer(1.2).timeout
	if current_scene != null and current_scene.has_method("_open_directive_picker"):
		current_scene.call("_open_directive_picker", ["salvageRig", "chitinGraft", "resonantChorus", "rootAccess", "mantleCore"])
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var image: Image = root.get_texture().get_image()
	if image != null:
		image.save_png(path)
		print("[DIRECTIVE_CAPTURE] saved %s" % path)
	quit(0)
