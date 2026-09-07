# Run with Godot -s (isolates the profile). Optional --kind=inspect|evolution|
# expanded|route|reward|settings and --width=390|537. Requires a real renderer.
extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	await process_frame
	var kind := "evolution"
	var width := 390
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--kind="):
			kind = arg.get_slice("=", 1)
		if arg.begins_with("--width="):
			width = int(arg.get_slice("=", 1))
	root.size = Vector2i(width, 1195 if width == 537 else 844)
	root.content_scale_size = Vector2i(1080, 2400)
	var settings: Node = root.get_node("SaveManager")
	settings.set_setting("reduced_motion", kind == "settings")
	settings.set_setting("ability_primers_enabled", false)
	var gs: Node = root.get_node("GameState")
	gs.start_run(["shield", "avalanche", "pulse"], "facility")
	gs.current_battle = 3
	var scene := "EvolutionScreen"
	match kind:
		"evolution", "expanded":
			gs.pending_evolution_unit_id = "avalanche"
			gs.unit_xp["avalanche"] = 100
			gs.unit_levels["avalanche"] = 3
		"route":
			scene = "RouteForkScreen"
		"reward":
			scene = "RewardScreen"
			gs.pending_reward_item_ids = ["predator_lens", "deep_zero_pin", "patch_kit"]
		"settings":
			scene = "UnitSelect"
		"inspect":
			scene = "BattleScene"
	var folder := "battle" if kind == "inspect" else "ui"
	change_scene_to_file("res://scenes/%s/%s.tscn" % [folder, scene])
	await create_timer(1.3).timeout
	match kind:
		"evolution", "expanded":
			current_scene._select_path("Glacier Rig")
			if kind == "expanded":
				current_scene.find_child("ExpandAbilities", true, false).pressed.emit()
		"reward":
			current_scene._select_item("deep_zero_pin")
		"inspect":
			current_scene._on_unit_detail_requested(current_scene.hero_card_views[0].card)
		"settings":
			var menu = load("res://scripts/ui/help_menu.gd")
			menu.open(current_scene)
			menu._active._select_tab("settings")
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var out := "res://docs/visuals/2026-09-07-implemented/%s-%d.png" % [kind, width]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
	root.get_texture().get_image().save_png(out)
	print("[APPROVED_CHOICES_CAPTURE] " + out)
	quit()
