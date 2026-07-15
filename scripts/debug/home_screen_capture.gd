# Captures the new home screen to disk. Mirrors battle_ui_capture.gd's pattern.
extends SceneTree

const DEFAULT_OUTPUT := "res://debug_artifacts/home_ui/latest.png"
const DEFAULT_DELAY_MS := 800


func _initialize() -> void:
	call_deferred("_run_capture")


func _run_capture() -> void:
	var config: Dictionary = _parse_args()
	if bool(config.get("native", false)):
		DisplayServer.window_set_size(Vector2i(1080, 2400))
	# Roster-state overrides mutate SaveManager.data in memory. NOTE: do NOT set
	# _disk_enabled=false here — that flips _fully_unlocked_override() and forces
	# everything unlocked regardless of the arrays. Callers who care about the
	# on-disk profile back up user://save.json around the invocation instead.
	if bool(config.get("unlock_all_mem", false)):
		var sm: Variant = root.get_node_or_null("/root/SaveManager")
		if sm != null:
			sm.data["unlocks"]["heroes"] = (sm.ALL_HEROES as Array).duplicate()
			sm.data["unlocks"]["heroes_new"] = []
			sm.data["unlocks"]["operations"] = (sm.OPERATION_CHAIN as Array).duplicate()
			print("[HOME_UI_CAPTURE] in-memory unlock-all")
	var lock_n: int = int(config.get("lock_base_mem", 0))
	if lock_n > 0:
		var sm2: Variant = root.get_node_or_null("/root/SaveManager")
		if sm2 != null:
			var subset: Array = (sm2.ALL_HEROES as Array).slice(0, lock_n)
			sm2.data["unlocks"]["heroes"] = subset
			sm2.data["unlocks"]["heroes_new"] = []
			print("[HOME_UI_CAPTURE] in-memory lock-to-first-%d" % lock_n)
	change_scene_to_file("res://scenes/ui/UnitSelect.tscn")
	await _wait_for_scene(config)
	var output_path: String = str(config.get("output", DEFAULT_OUTPUT))
	var absolute_output: String = _resolve_output_path(output_path)
	var save_result: Error = _capture_viewport_to_file(absolute_output)
	if save_result != OK:
		push_error("Home capture failed: %s" % error_string(save_result))
		quit(1)
		return
	print("[HOME_UI_CAPTURE] Saved: %s" % absolute_output)
	quit(0)


func _parse_args() -> Dictionary:
	var config := {"output": DEFAULT_OUTPUT, "delay_ms": DEFAULT_DELAY_MS}
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--capture-output="):
			config["output"] = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-delay-ms="):
			config["delay_ms"] = maxi(int(arg.get_slice("=", 1)), 100)
		elif arg.begins_with("--capture-select-units="):
			# Comma-separated unit ids; simulates the user having tapped them.
			config["units"] = arg.get_slice("=", 1).split(",", false)
		elif arg.begins_with("--capture-deselect-unit="):
			config["deselect_unit"] = arg.get_slice("=", 1).strip_edges()
		elif arg.begins_with("--capture-scroll-thumbs-end"):
			config["scroll_thumbs_end"] = true
		elif arg.begins_with("--capture-native"):
			config["native"] = true
		elif arg.begins_with("--capture-click-thumb="):
			# Simulates a real click on a unit thumbnail (via the parent VBox's
			# gui_input pipeline) to verify Bug 1's MOUSE_FILTER fix.
			config["click_thumb"] = arg.get_slice("=", 1).strip_edges()
		elif arg.begins_with("--capture-long-press-unit="):
			# Drives a unit tile's long-press handler directly (synthetic viewport input
			# won't reach LongPressInput's gui_input) to verify the inspect popup opens.
			config["long_press_unit"] = arg.get_slice("=", 1).strip_edges()
		elif arg == "--capture-help":
			# Opens the shared HelpMenu on the squad picker (verifies it works off-battle).
			config["help"] = true
		elif arg == "--capture-encounter-inspect":
			# Drives the banner's long-press handler (squad-select redesign: the
			# encounter blurb lives in the InspectPopup, not on the screen).
			config["encounter_inspect"] = true
		elif arg == "--capture-unlock-all-mem":
			# IN-MEMORY-ONLY full roster + operations unlock (wrap / paging tests):
			# disables the SaveManager disk path first, so nothing persists.
			config["unlock_all_mem"] = true
		elif arg.begins_with("--capture-encounter-page="):
			# Advance the encounter carousel N pages after load.
			config["encounter_page"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--capture-lock-base-mem"):
			# IN-MEMORY-ONLY roster reduction to the first N heroes (default 4) —
			# partial-row / locked-strip verification at sparse roster sizes.
			# Callers back up user://save.json around the invocation.
			var n: int = 4
			if "=" in arg:
				n = maxi(int(arg.get_slice("=", 1)), 1)
			config["lock_base_mem"] = n
	return config


func _wait_for_scene(config: Dictionary) -> void:
	var retries := 120
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/ui/UnitSelect.tscn":
			break
	await create_timer(float(config.get("delay_ms", DEFAULT_DELAY_MS)) / 1000.0).timeout
	var unit_ids: Variant = config.get("units", null)
	if unit_ids != null:
		_force_select_units(unit_ids)
	var deselect_unit: String = str(config.get("deselect_unit", ""))
	if deselect_unit != "" and current_scene != null and current_scene.has_method("_on_tile_tapped"):
		current_scene.call("_on_tile_tapped", deselect_unit)
		await process_frame
		await process_frame
	if bool(config.get("scroll_thumbs_end", false)):
		_scroll_thumbs_to_end()
	var click_thumb: Variant = config.get("click_thumb", null)
	if click_thumb != null and str(click_thumb) != "":
		_simulate_thumb_click(str(click_thumb))
		# Give Godot a couple of frames to flush the input + run the gui_input
		# handler + redraw the selected styling before we grab the framebuffer.
		await process_frame
		await process_frame
		await process_frame
	var long_press_unit: Variant = config.get("long_press_unit", null)
	if long_press_unit != null and str(long_press_unit) != "":
		_drive_tile_long_press(str(long_press_unit))
		await process_frame
		await process_frame
		await process_frame
	if bool(config.get("help", false)) and current_scene != null:
		HelpMenu.open(current_scene)
		await process_frame
		await process_frame
		await process_frame
	var pages: int = int(config.get("encounter_page", 0))
	if pages > 0 and current_scene != null and current_scene.has_method("_on_nav_pressed"):
		for i in pages:
			current_scene.call("_on_nav_pressed", 1)
		await process_frame
		await process_frame
	if bool(config.get("encounter_inspect", false)) and current_scene != null:
		if current_scene.has_method("_on_banner_long_pressed"):
			current_scene.call("_on_banner_long_pressed", Vector2.ZERO)
			print("[HOME_UI_CAPTURE] drove encounter banner long-press")
		await process_frame
		await process_frame
		await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


# Fires a synthetic InputEventMouseButton against the unit thumb's PanelContainer
# frame, exercising the same code path as a real player click. Bug 1's fix
# (PASS mouse_filter on the frame) is what lets this event reach the VBox.
func _simulate_thumb_click(unit_id: String) -> void:
	if current_scene == null:
		return
	var thumbs: Variant = current_scene.get("_unit_thumbs")
	if not (thumbs is Dictionary) or not (thumbs as Dictionary).has(unit_id):
		push_warning("simulate_thumb_click: unit_id not found: %s" % unit_id)
		return
	var info: Dictionary = (thumbs as Dictionary)[unit_id]
	var frame: Control = info.get("frame")
	if frame == null or not is_instance_valid(frame):
		return
	# Fire the click through the real Viewport hit-testing pipeline so we're
	# actually exercising the unit thumb's mouse_filter chain (Bug 1's fix).
	# Mouse coords are in viewport space (logical 1080x2400, since the project
	# uses canvas_items stretch); we hit the center of the thumb's frame.
	var screen_pos: Vector2 = frame.global_position + frame.size * 0.5
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = screen_pos
	press.global_position = screen_pos
	root.push_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = screen_pos
	release.global_position = screen_pos
	root.push_input(release)
	print("[HOME_UI_CAPTURE] dispatched click on %s at viewport=%s (frame=%s+%s)" % [
		unit_id, screen_pos, frame.global_position, frame.size
	])


func _drive_tile_long_press(unit_id: String) -> void:
	if current_scene == null:
		return
	var tiles: Variant = current_scene.get("_unit_tiles")
	if not (tiles is Dictionary) or not (tiles as Dictionary).has(unit_id):
		print("[HOME_UI_CAPTURE] long-press: unit tile not found: ", unit_id)
		return
	var info: Dictionary = (tiles as Dictionary)[unit_id]
	var anchor: Control = info.get("frame") as Control
	if anchor == null or not is_instance_valid(anchor):
		print("[HOME_UI_CAPTURE] long-press: no anchor frame for ", unit_id)
		return
	current_scene.call("_on_tile_long_pressed", Vector2.ZERO, unit_id, anchor)
	print("[HOME_UI_CAPTURE] drove long-press on ", unit_id)


func _scroll_thumbs_to_end() -> void:
	if current_scene == null:
		return
	var row: Node = current_scene.find_child("HBoxContainer", true, false)
	# More robust: find the ScrollContainer holding _unit_thumb_row by walking
	# the unit_thumbs dict's first entry up to its ScrollContainer ancestor.
	var thumbs: Variant = current_scene.get("_unit_thumbs")
	if thumbs is Dictionary and not (thumbs as Dictionary).is_empty():
		var first_key: Variant = (thumbs as Dictionary).keys()[0]
		var thumb_info: Variant = (thumbs as Dictionary).get(first_key)
		if thumb_info is Dictionary and (thumb_info as Dictionary).has("card"):
			var card: Control = (thumb_info as Dictionary).get("card")
			var p: Node = card
			while p != null and not (p is ScrollContainer):
				p = p.get_parent()
			if p is ScrollContainer:
				var sc: ScrollContainer = p
				sc.scroll_horizontal = 99999  # clamps to max


func _force_select_units(unit_ids: Variant) -> void:
	if current_scene == null:
		return
	var ids: Array = []
	for v in unit_ids:
		ids.append(str(v).strip_edges())
	if current_scene.has_method("_toggle_unit_selection"):
		for id in ids:
			current_scene.call("_toggle_unit_selection", id)
		if current_scene.has_method("_show_unit_detail") and not ids.is_empty():
			current_scene.call("_show_unit_detail", ids[-1])
		current_scene.call("_refresh_unit_thumbs")
		current_scene.call("_refresh_squad_counter")
		current_scene.call("_refresh_begin_button")


func _resolve_output_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path


func _capture_viewport_to_file(absolute_output: String) -> Error:
	var directory: String = absolute_output.get_base_dir()
	var make_dir_result: Error = DirAccess.make_dir_recursive_absolute(directory)
	if make_dir_result != OK:
		return make_dir_result
	var image: Image = root.get_texture().get_image()
	if image == null:
		return ERR_CANT_ACQUIRE_RESOURCE
	return image.save_png(absolute_output)
