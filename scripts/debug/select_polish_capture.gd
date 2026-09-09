extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	root.get_node("SaveManager").dev_reset_profile()
	change_scene_to_file("res://scenes/ui/UnitSelect.tscn")
	for _i in 12:
		await process_frame
	var home = current_scene
	home.get("_selected_unit_ids").clear()
	home.set("_focused_unit_id", "")
	home.set("_operation_index", 1)
	home.set("_selected_operation_id", "hive")
	home.call("_refresh_encounter")
	home.call("_refresh_detail")
	home.call("_refresh_unit_tiles")
	home.call("_refresh_squad_counter")
	await capture("locked-empty")
	home.call("_on_tile_tapped", "combat")
	await capture("locked-selected")
	home.set("_operation_index", 0)
	home.set("_selected_operation_id", "facility")
	home.call("_refresh_encounter")
	home.call("_refresh_detail")
	await capture("facility")
	var overlay = load("res://scripts/ui/operation_briefing_overlay.gd").new()
	home.add_child(overlay)
	overlay.present_deployment("facility")
	await capture("briefing")
	print("[SELECT_CAPTURE] PASS")
	quit()

func capture(label: String) -> void:
	for _i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var folder = "res://debug_artifacts/select-polish/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder + label + ".png"))

