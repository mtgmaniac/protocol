# Captures the splash / main menu to disk. Run WINDOWED (not --headless) so it renders.
extends SceneTree


func _initialize() -> void:
	call_deferred("_run_capture")


func _run_capture() -> void:
	var output := "res://debug_artifacts/splash/latest.png"
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--capture-output="):
			output = arg.get_slice("=", 1)
	change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	var retries := 120
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/ui/MainMenu.tscn":
			break
	await create_timer(0.6).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	var absolute: String = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var image: Image = root.get_texture().get_image()
	if image != null:
		image.save_png(absolute)
		print("[SPLASH_CAPTURE] Saved: %s" % absolute)
	quit(0)
