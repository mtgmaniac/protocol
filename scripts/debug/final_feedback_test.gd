extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func run() -> void:
	await process_frame
	root.size = Vector2i(390, 844)
	root.content_scale_size = Vector2i(1080, 2400)
	root.get_node("AudioManager").set_suppressed(true)
	var gs = root.get_node("GameState")
	var sm = root.get_node("SaveManager")
	sm.set("data", sm.default_data())
	sm.set_setting("ability_primers_enabled", false)
	gs.start_run(["combat", "engineer", "medic"], "facility")
	gs.record_battle_hero_deaths(["combat"])
	gs.advance_to_next_battle()
	gs.hero_run_mods["combat"] = {"max_hp_delta": 7, "start_hp_damage": 2}
	change_scene_to_file("res://scenes/battle/BattleScene.tscn")
	await create_timer(0.5).timeout
	var scene = current_scene
	var states: Array = scene.combat_manager.get_hero_states()
	check(int(states[0].current_hp) == maxi(1, int(states[0].max_hp) * 75 / 100) - 2, "Casualty uses updated max HP, then explicit start damage")
	check(int(states[1].current_hp) == int(states[1].max_hp), "Survivor starts full")
	check(not states[0].dead, "Returning casualty is alive")
	# The next surviving battle clears the penalty, and a new run clears history.
	gs.record_battle_hero_deaths([])
	check(gs.deaths_last_battle.is_empty(), "No stale casualty penalty")
	check(gs.get_revive_hp_pct(50) == 50, "Authored in-battle revival percentage unchanged")
	states[0].dead = true
	scene.combat_manager.apply_item_revive(states[0], 50)
	check(int(states[0].current_hp) == int(states[0].max_hp) / 2, "Actual item revival still uses 50 percent")
	var engine = scene.get("_engine")
	states[0].max_hp = 1
	engine.apply_battle_start_external_effects({}, {}, 0, ["combat"])
	check(int(states[0].current_hp) == 1, "Recovery without run mods respects minimum 1 HP")
	states[0].max_hp = 62
	engine.apply_battle_start_external_effects({}, {}, 0, ["combat"])
	check(int(states[0].current_hp) == 46, "Recovery without run mods floors fractional HP")
	var feedback = scene.get("_feedback")
	check(feedback._build_floating_text("burn", 3) == "", "Applying Burn does not pretend to deal damage")
	check(feedback._build_floating_text("damage", 3) == "-3", "Real damage retains its number")
	var card = scene.hero_card_views[0].card
	for kind in ["mark", "burn", "burn_tick", "revive", "summon"]:
		sm.set_setting("reduced_motion", false)
		var count: int = scene.float_layer.get_child_count()
		feedback._local_status_cue(card, kind)
		check(scene.float_layer.get_child_count() == count + 1, "%s creates local cue" % kind)
		await create_timer(0.12).timeout
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var folder := ProjectSettings.globalize_path("res://debug_artifacts/final-feedback/")
			DirAccess.make_dir_recursive_absolute(folder)
			root.get_texture().get_image().save_png(folder + kind + ".png")
		await create_timer(0.5).timeout
		check(scene.float_layer.get_child_count() == count, "%s cleans up" % kind)
		sm.set_setting("reduced_motion", true)
		feedback._local_status_cue(card, kind)
		check(scene.float_layer.get_child_count() == count, "%s respects Reduced Motion" % kind)
	sm.set_setting("reduced_motion", false)
	var enemies_before: int = scene.combat_manager.get_enemy_states().size()
	var cues_before: int = scene.float_layer.get_child_count()
	scene._process_summon_events([{"type": "summon", "summon_name": "Scrap Drone"}])
	await create_timer(0.08).timeout
	check(scene.combat_manager.get_enemy_states().size() == enemies_before + 1, "Real summon injects a new enemy")
	check(scene.float_layer.get_child_count() == cues_before + 1, "Real summon arrival plays after card layout")
	await create_timer(0.5).timeout
	check(scene.float_layer.get_child_count() == cues_before, "Real summon arrival cleans up")
	gs.start_run(["combat", "engineer", "medic"], "facility")
	check(gs.deaths_last_battle.is_empty(), "New run clears casualty history")
	for failure in failures:
		push_error(failure)
	print("[FINAL_FEEDBACK] %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
