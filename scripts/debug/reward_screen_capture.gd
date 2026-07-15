# Boots a run, routes to the reward / item picker, captures the rendered viewport to
# disk, and exits. Mirrors battle_ui_capture.gd / home_screen_capture.gd.
#
# Run (windowed so the viewport actually renders — NOT --headless, which uses the dummy
# renderer and would save a blank image):
#   godot --path . --script res://scripts/debug/reward_screen_capture.gd \
#         --capture-select=0 --capture-output=res://debug_artifacts/reward_ui/latest.png
#
# Options:
#   --capture-output=<res://…|abs path>   where to save the PNG
#   --capture-operation=<id>              operation to start (default "facility")
#   --capture-delay-ms=<n>                settle time before grabbing the frame
#   --capture-select=<index>              select the Nth card (lights its brackets +
#                                         arms the confirm button); omit for none selected
#   --capture-force-items=<id,id,id>      override the reward roll with explicit item ids
#                                         (any mix of consumable/gear/relic, by id)
#   --capture-intercept-kind=draft         render the same forced offers through the
#                                         shared Intercept reward handoff
#   --capture-native                      force the 1080x2400 logical window size
extends SceneTree

const DEFAULT_OUTPUT := "res://debug_artifacts/reward_ui/latest.png"
const DEFAULT_OPERATION_ID := "facility"
const DEFAULT_SQUAD := ["shield", "avalanche", "pulse"]
const DEFAULT_DELAY_MS := 900


func _initialize() -> void:
	call_deferred("_run_capture")


func _run_capture() -> void:
	var config: Dictionary = _parse_args()
	if bool(config.get("native", false)):
		DisplayServer.window_set_size(Vector2i(1080, 2400))
	_prepare_run(config)
	change_scene_to_file("res://scenes/ui/RewardScreen.tscn")
	await _wait_for_scene(config)
	var absolute_output: String = _resolve_output_path(str(config.get("output", DEFAULT_OUTPUT)))
	var save_result: Error = _capture_viewport_to_file(absolute_output)
	if save_result != OK:
		push_error("Reward capture failed: %s" % error_string(save_result))
		quit(1)
		return
	print("[REWARD_UI_CAPTURE] Saved: %s" % absolute_output)
	quit(0)


func _parse_args() -> Dictionary:
	var config := {
		"output": DEFAULT_OUTPUT,
		"operation_id": DEFAULT_OPERATION_ID,
		"delay_ms": DEFAULT_DELAY_MS,
		"select": -1,
	}
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--capture-output="):
			config["output"] = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-operation="):
			config["operation_id"] = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-delay-ms="):
			config["delay_ms"] = maxi(int(arg.get_slice("=", 1)), 100)
		elif arg.begins_with("--capture-select="):
			config["select"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("--capture-force-items="):
			config["force_items"] = arg.get_slice("=", 1).split(",", false)
		elif arg.begins_with("--capture-intercept-kind="):
			config["intercept_kind"] = arg.get_slice("=", 1)
		elif arg == "--capture-native":
			config["native"] = true
	return config


func _prepare_run(config: Dictionary) -> void:
	var game_state: Node = _game_state()
	game_state.start_run(DEFAULT_SQUAD, str(config.get("operation_id", DEFAULT_OPERATION_ID)))
	game_state.advance_to_next_battle()
	var forced: Variant = config.get("force_items", null)
	if (forced is Array and not (forced as Array).is_empty()) or (forced is PackedStringArray and not (forced as PackedStringArray).is_empty()):
		# Override the roll with explicit ids (reward_screen skips its own roll when
		# pending_reward_item_ids is already populated).
		var ids: Array = []
		for id_variant in forced:
			ids.append(str(id_variant).strip_edges())
		var intercept_kind: String = str(config.get("intercept_kind", ""))
		if intercept_kind == "draft":
			game_state.call("begin_intercept_state", "abandonedArmory")
			game_state.call("set_intercept_choice", {"draft": {"kind": "any", "count": ids.size()}, "effects": []})
			game_state.call("begin_intercept_item_request", "draft", "CHOOSE INTERCEPT REWARD", ids)
			return
		if intercept_kind == "owned_gear":
			var entries: Array = []
			for item_id in ids:
				entries.append({"hero_id": "shield", "gear_id": item_id})
			game_state.set("gear_by_unit", {"shield": ids.duplicate()})
			game_state.set("equipped_gear", {"shield": ids.duplicate()})
			game_state.call("begin_intercept_state", "blackMarketNode")
			game_state.call("set_intercept_choice", {"pick": "gear", "effects": []})
			game_state.call("begin_intercept_item_request", "owned_gear", "SELECT EQUIPPED GEAR", [], entries)
			return
		game_state.set("pending_reward_item_ids", ids)
		return
	# Seed the reward roll before the scene builds (reward_screen also guards this).
	if game_state.has_method("prepare_battle_rewards"):
		game_state.call("prepare_battle_rewards")


func _wait_for_scene(config: Dictionary) -> void:
	var retries := 120
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/ui/RewardScreen.tscn":
			break
	await create_timer(float(config.get("delay_ms", DEFAULT_DELAY_MS)) / 1000.0).timeout
	var select_index: int = int(config.get("select", -1))
	if select_index >= 0:
		_select_card(select_index)
		# Let the gui_input handler + restyle + redraw flush before the grab.
		await process_frame
		await process_frame
		await process_frame
	await process_frame
	await RenderingServer.frame_post_draw


# Selects the Nth reward card. Fires a real synthetic click through the Viewport so the
# card's gui_input / mouse_filter chain is actually exercised (same path as a player tap),
# then falls back to driving the selection state directly if the hit-test missed.
func _select_card(index: int) -> void:
	if current_scene == null:
		return
	var cards_variant: Variant = current_scene.get("_cards")
	if not (cards_variant is Dictionary):
		return
	var cards: Dictionary = cards_variant
	var keys: Array = cards.keys()
	if index < 0 or index >= keys.size():
		return
	var item_id: String = str(keys[index])
	var entry: Dictionary = cards[item_id]
	var panel: Control = entry.get("panel") as Control
	if panel != null and is_instance_valid(panel):
		var screen_pos: Vector2 = panel.global_position + panel.size * 0.5
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
		print("[REWARD_UI_CAPTURE] clicked card %d (%s) at viewport=%s" % [index, item_id, screen_pos])
	# Fallback: if the hit-test missed, drive selection state directly.
	if str(current_scene.get("_selected_item_id")) != item_id:
		current_scene.set("_selected_item_id", item_id)
		if current_scene.has_method("_refresh_selection"):
			current_scene.call("_refresh_selection")
	if current_scene.has_method("_item_for_selection"):
		var selected_item: ItemData = current_scene.call("_item_for_selection", item_id) as ItemData
		if selected_item != null and selected_item.item_type == "gear" and current_scene.get("_gear_target_overlay") == null:
			current_scene.call("_select_item", item_id)


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


func _game_state() -> Node:
	return root.get_node("/root/GameState")
