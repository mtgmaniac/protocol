extends SceneTree

var out := "res://debug_artifacts/visual_motion/"
var records: Array = []

func _initialize() -> void:
	root.size = Vector2i(540, 1200)
	root.content_scale_size = Vector2i(1080, 2400)
	call_deferred("run")

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(out + label + ".png"))

func series(label: String, count: int, interval: float) -> void:
	var start := Time.get_ticks_msec()
	for i in count:
		await shot("%s_%02d" % [label, i])
		records.append({"series": label, "frame": i, "elapsed_ms": Time.get_ticks_msec()-start})
		await create_timer(interval).timeout

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	await process_frame
	change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	await process_frame
	await series("logo", 18, 0.09)
	var logo: Node = current_scene.get("_logo")
	logo.call("flare_out")
	await series("flare", 6, 0.045)
	var gs: Node = root.get_node("GameState")
	root.get_node("SaveManager").call("set_setting", "ability_primers_enabled", false)
	gs.call("start_run", ["shield", "avalanche", "pulse"], "facility")
	gs.call("advance_to_next_battle")
	change_scene_to_file("res://scenes/battle/BattleScene.tscn")
	await create_timer(1.0).timeout
	var battle: Node = current_scene
	var tray: Node = battle.get_node("%DiceTray3D")
	battle.get_node("%RollButton").emit_signal("pressed")
	await series("dice", 36, 0.08)
	await create_timer(1.0).timeout
	var fb: Node = battle.get("_feedback")
	var hero: Dictionary = (battle.get("hero_card_views") as Array)[0]
	var enemy: Dictionary = (battle.get("enemy_card_views") as Array)[0]
	var hc: Control = hero["card"]
	var ec: Control = enemy["card"]
	var hid: String = str((hero["state"] as Dictionary)["id"])
	for kind in ["damage", "heal", "shield", "detonate", "breach", "death", "20", "jam", "rewrite", "freeze"]:
		match kind:
			"damage":
				fb.call("_spawn_floating_text", ec, "damage", 18)
				fb.call("_shake", ec, 5.0, 0.22)
			"heal": fb.call("_spawn_floating_text", hc, "heal", 8)
			"shield": fb.call("_spawn_floating_text", hc, "shield", 8)
			"detonate", "breach": fb.call("_play_keyword_feedback", kind, {}, hc, ec)
			"death": fb.call("_death_scatter", ec, "enemy")
			"20": fb.call("_celebrate_overload")
			"jam": tray.call("play_jam_flicker", "hero", hid, 10)
			"rewrite": tray.call("play_rewrite_scramble", "hero", hid)
			"freeze": tray.call("set_die_frozen_visual", "hero", hid, true)
		await series(kind, 12, 0.07)
		await create_timer(1.0).timeout
	root.get_node("TransitionManager").call("change_scene", "res://scenes/ui/RewardScreen.tscn", "dither_dissolve")
	await series("dissolve", 8, 0.035)
	await create_timer(0.5).timeout
	root.get_node("TransitionManager").call("change_scene", "res://scenes/ui/MainMenu.tscn", "power_down")
	await series("power_down", 15, 0.045)
	FileAccess.open(ProjectSettings.globalize_path(out + "timing.json"), FileAccess.WRITE).store_string(JSON.stringify(records))
	quit()
