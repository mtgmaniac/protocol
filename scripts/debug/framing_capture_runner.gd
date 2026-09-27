# Framing capture runner (scene-based, so autoload identifiers compile — the
# SceneTree-script inspect harness cannot compile InspectResolver any more).
#
#   <godot> --path . res://scenes/debug/FramingCaptureRunner.tscn \
#       --capture-mode=popup --capture-kind=item --capture-id=naniteField \
#       --capture-output=<abs path.png>
#
# --capture-kind = item | unit | enemy. A unit popup equips --capture-gear
# (comma ids) so the gear rows show item art. Run WINDOWED (captures under
# --headless are blank).
extends Node

const DEFAULT_OUTPUT := "res://debug_artifacts/framing/latest.png"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var config: Dictionary = _parse_args()
	DisplayServer.window_set_size(Vector2i(1080, 2400))
	if str(config["mode"]) == "directive":
		await _directive(config)
		return
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.070, 0.095, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	add_child(host)
	await get_tree().process_frame
	await get_tree().process_frame
	var payload: Dictionary = _payload(config)
	if payload.is_empty():
		push_error("[FRAMING_CAPTURE] empty payload")
		get_tree().quit(1)
		return
	InspectPopup.open(host, payload)
	await _save(config)


# The Starting Directive picker on the squad screen, offering --capture-id
# (comma relic ids).
func _directive(config: Dictionary) -> void:
	# Instanced under this runner (a scene change would free the coroutine).
	var screen: Node = (load("res://scenes/ui/UnitSelect.tscn") as PackedScene).instantiate()
	add_child(screen)
	await get_tree().create_timer(0.6).timeout
	screen.call("_open_directive_picker", Array(str(config["id"]).split(",", false)))
	await _save(config)


func _save(config: Dictionary) -> void:
	await get_tree().create_timer(0.8).timeout
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var out: String = str(config["output"])
	if out.begins_with("res://") or out.begins_with("user://"):
		out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var err: Error = image.save_png(out)
	print("[FRAMING_CAPTURE] Saved: %s (%s)" % [out, error_string(err)])
	get_tree().quit(0 if err == OK else 1)


func _payload(config: Dictionary) -> Dictionary:
	var id: String = str(config["id"])
	match str(config["kind"]):
		"item":
			return InspectResolver.resolve_item(DataManager.get_item(id) as ItemData)
		"enemy":
			return InspectResolver.resolve_unit(DataManager.get_enemy(id))
		"unit":
			GameState.gear_by_unit[id] = config["gear"]
			return InspectResolver.resolve_unit(DataManager.get_unit(id))
	return {}


func _parse_args() -> Dictionary:
	var config := {"mode": "popup", "kind": "item", "id": "naniteField", "gear": [], "output": DEFAULT_OUTPUT}
	for arg in OS.get_cmdline_args():
		for key in ["mode", "kind", "id", "output"]:
			if arg.begins_with("--capture-%s=" % key):
				config[key] = arg.get_slice("=", 1)
		if arg.begins_with("--capture-gear="):
			config["gear"] = Array(arg.get_slice("=", 1).split(",", false))
	return config
