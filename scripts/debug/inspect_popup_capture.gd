# Stage-1 isolation harness for the unified InspectPopup. Builds a payload via
# InspectResolver from real DataManager data and renders the popup over a blank DT field,
# then screenshots and quits. Lets us verify the component before wiring it into surfaces.
#
#   godot --path . --script res://scripts/debug/inspect_popup_capture.gd \
#         --capture-kind=unit --capture-id=pulse --capture-output=res://debug_artifacts/inspect/unit.png
#
# --capture-kind = unit | enemy | item | ability | status | protocol
extends SceneTree

const DEFAULT_OUTPUT := "res://debug_artifacts/inspect/latest.png"
const DEFAULT_DELAY_MS := 600


func _initialize() -> void:
	call_deferred("_run_capture")


func _run_capture() -> void:
	var config: Dictionary = _parse_args()
	DisplayServer.window_set_size(Vector2i(1080, 2400))
	var host := _build_host()
	current_scene = host
	root.add_child(host)
	await process_frame
	await process_frame

	var payload: Dictionary = _build_payload(config)
	if payload.is_empty():
		push_error("Inspect capture: empty payload for kind=%s id=%s" % [config.get("kind"), config.get("id")])
		quit(1)
		return
	InspectPopup.open(host, payload)
	await create_timer(float(config.get("delay_ms", DEFAULT_DELAY_MS)) / 1000.0).timeout
	await process_frame
	await RenderingServer.frame_post_draw

	var absolute_output: String = _resolve_output_path(str(config.get("output", DEFAULT_OUTPUT)))
	var save_result: Error = _capture_viewport_to_file(absolute_output)
	if save_result != OK:
		push_error("Inspect capture failed: %s" % error_string(save_result))
		quit(1)
		return
	print("[INSPECT_CAPTURE] Saved: %s" % absolute_output)
	quit(0)


func _parse_args() -> Dictionary:
	var config := {"kind": "unit", "id": "", "output": DEFAULT_OUTPUT, "delay_ms": DEFAULT_DELAY_MS}
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--capture-kind="):
			config["kind"] = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-id="):
			config["id"] = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-output="):
			config["output"] = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-delay-ms="):
			config["delay_ms"] = maxi(int(arg.get_slice("=", 1)), 100)
	return config


func _build_host() -> Control:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.070, 0.095, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	return host


func _build_payload(config: Dictionary) -> Dictionary:
	var data_manager: Node = root.get_node_or_null("/root/DataManager")
	var kind: String = str(config.get("kind", "unit"))
	var item_id: String = str(config.get("id", ""))
	match kind:
		"unit":
			var unit: Resource = data_manager.call("get_unit", item_id if item_id != "" else "pulse")
			return InspectResolver.resolve_unit(unit)
		"enemy":
			var enemy: Resource = data_manager.call("get_enemy", item_id) if item_id != "" else _first_enemy(data_manager)
			return InspectResolver.resolve_unit(enemy)
		"item":
			var item: Resource = data_manager.call("get_item", item_id if item_id != "" else "ironCurtain")
			return InspectResolver.resolve_item(item as ItemData)
		"ability":
			var ability_unit: Resource = data_manager.call("get_unit", item_id if item_id != "" else "pulse")
			var ranges: Array = ability_unit.get("dice_ranges")
			for entry_variant in ranges:
				var entry: Dictionary = entry_variant
				if str(entry.get("zone", "")) == "strike":
					return InspectResolver.resolve_ability(entry.get("raw", {}), "hero", "STRIKE")
			return {}
		"status":
			return InspectResolver.resolve_status({"type": "poison", "value": "6", "duration": 2})
		"protocol":
			return InspectResolver.resolve_protocol_action(item_id if item_id != "" else "nudge")
	return {}


func _first_enemy(data_manager: Node) -> Resource:
	var enemies: Variant = data_manager.get("enemies")
	if enemies is Dictionary and not (enemies as Dictionary).is_empty():
		var first_key: Variant = (enemies as Dictionary).keys()[0]
		return data_manager.call("get_enemy", str(first_key))
	return null


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
