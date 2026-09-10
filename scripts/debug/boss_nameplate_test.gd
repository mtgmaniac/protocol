extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func settle() -> void:
	for _i in 6:
		await process_frame

func _run() -> void:
	await process_frame
	root.size = Vector2i(390, 844)
	root.content_scale_size = Vector2i(1080, 2400)
	root.get_node("AudioManager").set_suppressed(true)
	var gs = root.get_node("GameState")
	var combat = load("res://scripts/battle/combat_manager.gd")
	for operation in ["facility", "hive", "veil", "voidCirclet", "stellarMenagerie"]:
		gs.start_run(["combat", "engineer", "medic"], operation)
		for _i in 10:
			gs.advance_to_next_battle()
		change_scene_to_file("res://scenes/battle/BattleScene.tscn")
		await settle()
		var bosses := 0
		for view in current_scene.get("enemy_card_views"):
			var card = view.card
			var expected: bool = combat.BOSS_STANDING_RULES.has(str(view.state.unit.display_name))
			check(card.is_boss == expected, "%s: rank matches registry" % operation)
			check(card.get("_boss_label").visible == expected, "%s: label matches rank" % operation)
			if not expected:
				continue
			bosses += 1
			var portrait_rect: Rect2 = card.get("_portrait_frame").get_global_rect()
			var hp_rect: Rect2 = card.get("_hp_back").get_global_rect()
			var strip_rect: Rect2 = card.get("_name_strip").get_global_rect()
			card.configure({"boss": false})
			await settle()
			check(card.get("_portrait_frame").get_global_rect() == portrait_rect, "Rank does not move portrait")
			check(card.get("_hp_back").get_global_rect() == hp_rect, "Rank does not move HP")
			check(card.get("_name_strip").get_global_rect() == strip_rect, "Rank does not resize strip")
			card.configure({"boss": true, "selected": true})
			check(card.get_theme_stylebox("panel").border_color == PixelUI.DT_CYAN, "Selection retains cyan border")
			check(card.get("_name_strip").get_theme_stylebox("panel").bg_color == PixelUI.DT_BOSS_HEADER, "Selected boss retains rank fill")
			card.configure({"selected": false, "dead": true})
			check(card.get("_boss_label").visible, "Dead boss retains identity")
			check(card.get("_name_strip").get_theme_stylebox("panel").bg_color != PixelUI.DT_BOSS_HEADER, "Dead boss fill dims")
			card.configure({"dead": false})
		check(bosses == 1, "%s: exactly one boss" % operation)
		for view in current_scene.get("hero_card_views"):
			check(not view.card.is_boss and not view.card.get("_boss_label").visible, "Hero has no boss label")
		await settle()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var folder := ProjectSettings.globalize_path("res://debug_artifacts/boss-review/")
			DirAccess.make_dir_recursive_absolute(folder)
			root.get_texture().get_image().save_png(folder + operation + "-final.png")
	for failure in failures:
		push_error(failure)
	print("[BOSS_NAMEPLATE] %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
