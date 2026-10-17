# Captures squad select's unit info bar for every base hero (G-87 roll band
# bar check): one PNG crop per hero plus a JSON of each band's ability, effect
# type and icon, for scripts/checks/band_table.py to lay out as one table.
# Windowed only (needs a rendered viewport).
#   <godot> --path . --script res://scripts/debug/band_table_capture.gd \
#     [--capture-dir=res://debug_artifacts/art_polish/band_table] [--capture-window=WxH]
extends SceneTree

const SCENE := "res://scenes/ui/UnitSelect.tscn"
const HEROES := ["combat", "engineer", "medic", "pulse", "avalanche", "shield", "ghost", "breaker"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var out_dir := "res://debug_artifacts/art_polish/band_table"
	var window := Vector2i(540, 1200)
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--capture-dir="):
			out_dir = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-window="):
			var parts: PackedStringArray = arg.get_slice("=", 1).split("x")
			window = Vector2i(int(parts[0]), int(parts[1]))
	load("res://scripts/debug/capture_window.gd").apply(root, window)
	await process_frame
	var save_manager: Node = root.get_node("/root/SaveManager")
	save_manager.data["unlocks"]["heroes"] = (save_manager.ALL_HEROES as Array).duplicate()
	save_manager.data["unlocks"]["heroes_new"] = []
	change_scene_to_file(SCENE)
	await create_timer(1.0).timeout
	var scene: Node = current_scene
	var dir: String = ProjectSettings.globalize_path(out_dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var table: Array = []
	for hero_id: String in HEROES:
		scene.set("_focus_unit_id", hero_id)
		scene.call("_refresh_info")
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		var bar: Control = scene.get("_info_bar")
		var xf: Transform2D = root.get_final_transform() * bar.get_global_transform_with_canvas()
		var rect := Rect2i(Vector2i((xf * Vector2.ZERO).round()), Vector2i((xf.get_scale() * bar.size).round()))
		var image: Image = root.get_viewport().get_texture().get_image()
		if image == null:
			push_error("band table capture: null viewport image (run without --headless)")
			quit(1)
			return
		image.get_region(rect).save_png(dir.path_join("%s.png" % hero_id))
		var unit: Resource = root.get_node("/root/DataManager").call("get_unit", hero_id)
		var bands: Array = scene.get_script().call("band_layout", unit, 240)
		var rows: Array = []
		for band: Dictionary in bands:
			rows.append({"range": "%d-%d" % [band["min"], band["max"]] if band["min"] != band["max"] else str(band["min"]),
				"ability": band["ability"], "effect": band["effect"], "icon": band["icon"]})
		table.append({"id": hero_id, "callsign": str(unit.call("battle_name")).to_upper(), "bands": rows})
	var file := FileAccess.open(dir.path_join("bands.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(table, "  "))
	file.close()
	print("[BAND_TABLE_CAPTURE] Saved: %s" % dir)
	quit(0)
