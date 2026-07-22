# Boots the main menu, captures the rendered viewport at a given delay, and exits.
# Mirrors battle_ui_capture.gd. Used to verify the TitleLogo animation states:
#   --capture-delay-ms=300    mid-boot (buttons still dark)
#   --capture-delay-ms=1800   idle (glows pulsing, buttons live)
#   --capture-flare           press-BEGIN flare, captured mid-blowout
#   --capture-first-run       the first-run choice overlay (RUN TUTORIAL / SKIP)
extends SceneTree

const MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const DEFAULT_OUTPUT := "res://debug_artifacts/menu_ui/latest.png"
const DEFAULT_DELAY_MS := 1800


func _initialize() -> void:
	call_deferred("_run_capture")


func _run_capture() -> void:
	var output := DEFAULT_OUTPUT
	var delay_ms := DEFAULT_DELAY_MS
	var flare := false
	var first_run := false
	# User args arrive after "--" (get_cmdline_user_args), engine-style without.
	for arg in Array(OS.get_cmdline_args()) + Array(OS.get_cmdline_user_args()):
		if arg.begins_with("--capture-output="):
			output = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-delay-ms="):
			delay_ms = maxi(int(arg.get_slice("=", 1)), 50)
		elif arg == "--capture-flare":
			flare = true
		elif arg == "--capture-first-run":
			first_run = true
	change_scene_to_file(MENU_SCENE)
	var retries := 120
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == MENU_SCENE:
			break
	await create_timer(float(delay_ms) / 1000.0).timeout
	_print_button_state()
	if flare and current_scene != null:
		var logo: Node = current_scene.get("_logo")
		if logo != null:
			logo.call("flare_out")
			# Catch the frame near peak core flare (0.12s ramp).
			await create_timer(0.10).timeout
	if first_run and current_scene != null and current_scene.has_method("_show_first_run_prompt"):
		current_scene.call("_show_first_run_prompt")
		await create_timer(0.15).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	var absolute_output := ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(absolute_output.get_base_dir())
	var image: Image = root.get_texture().get_image()
	if image == null:
		push_error("Menu UI capture failed: no viewport image")
		quit(1)
		return
	var save_result: Error = image.save_png(absolute_output)
	if save_result != OK:
		push_error("Menu UI capture failed: %s" % error_string(save_result))
		quit(1)
		return
	print("[MENU_UI_CAPTURE] Saved screenshot to: %s" % absolute_output)
	quit(0)


func _print_button_state() -> void:
	if current_scene == null:
		return
	var begin: Button = current_scene.get("_begin_button") as Button
	var tutorial: Button = current_scene.get("_tutorial_button") as Button
	if begin != null and tutorial != null:
		print("[MENU_UI_CAPTURE] begin disabled=%s alpha=%.2f | tutorial disabled=%s alpha=%.2f" % [
			begin.disabled, begin.modulate.a, tutorial.disabled, tutorial.modulate.a])
