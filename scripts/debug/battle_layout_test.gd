## Stage A policy, real scene geometry, shared input and spawn regression.
## godot --headless --path . -s scripts/debug/battle_layout_test.gd
extends SceneTree
const POLICY := preload("res://scripts/battle/battle_layout_policy.gd")
const BATTLE := "res://scenes/battle/BattleScene.tscn"
var failures: Array[String] = []
var checks := 0
var _inspect: Variant


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("[BATTLE_LAYOUT] " + label)


func frames(count: int = 8) -> void:
	for i in count:
		await process_frame


func start(mode: int, operation: String = "facility", number: int = 6, tutorial: bool = false) -> void:
	POLICY.dev_override = mode
	var gs: Node = root.get_node("GameState")
	if tutorial:
		gs.start_tutorial_run()
	else:
		gs.start_run(["combat", "engineer", "medic"], operation, 20260921)
		for i in number:
			gs.advance_to_next_battle()
	change_scene_to_file(BATTLE)
	await frames(16)
	current_scene._briefing_active = false
	for child in current_scene.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/ui/operation_briefing_overlay.gd":
			child.queue_free()
	await frames()


func geometry(landscape: bool) -> void:
	var s: Node = current_scene
	var visible_rect := root.get_visible_rect()
	var footer: Rect2 = s.protocol_panel.get_global_rect()
	check(s._layout.is_landscape == landscape, "selected mode")
	for views in [s.hero_card_views, s.enemy_card_views]:
		var last := Rect2()
		for view in views:
			var card: Control = view.card
			var rect := card.get_global_rect()
			check(visible_rect.encloses(rect), "card inside viewport: " + str(view.state.id))
			check(rect.end.y <= footer.position.y, "card clears Protocol")
			check(not last.intersects(rect), "cards do not overlap")
			if landscape:
				check(rect.size.x > 344 and rect.size.y > 570, "larger landscape card")
				check(rect.end.x < visible_rect.size.x * 0.5 if views == s.hero_card_views else rect.position.x > visible_rect.size.x * 0.5, "correct side")
			last = rect


func mouse(at: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_final_transform() * at
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = root.get_final_transform() * at
	event.global_position = event.position
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(event)


func run() -> void:
	_inspect = load("res://scripts/ui/inspect_popup.gd")
	root.size = Vector2i(1280, 720)
	PixelUI.sim_insets_pinned = true
	PixelUI.safe_top = 0
	PixelUI.safe_bottom = 0
	root.get_node("SaveManager").set_setting("ability_primers_enabled", false)
	# Independent policy expectations, including release ignoring forced values.
	for desktop in [true, false]:
		for tutorial in [true, false]:
			for dimensions in [Vector2(1920,1080), Vector2(1280,720), Vector2(960,600), Vector2(640,960), Vector2(900,600)]:
				check(not POLICY.resolve(false, false, 2, tutorial, desktop, dimensions), "release flag-off fence")
				check(not POLICY.resolve(false, true, 0, tutorial, desktop, dimensions), "AUTO flag-off fence")
				check(POLICY.resolve(false, true, 2, tutorial, desktop, dimensions), "explicit debug force")
				check(not POLICY.resolve(true, true, 1, tutorial, desktop, dimensions), "force portrait")
	check(POLICY.resolve(true, false, 0, false, true, Vector2(1280,720)), "enabled desktop")
	check(not POLICY.resolve(true, false, 0, true, true, Vector2(1280,720)), "tutorial fence")
	check(not POLICY.resolve(true, false, 0, false, false, Vector2(1920,1080)), "rotated mobile/tablet fence")
	check(not POLICY.resolve(true, false, 0, false, true, Vector2(960,960)), "aspect fence")
	check(not POLICY.resolve(true, false, 0, false, true, Vector2(900,600)), "width fence")
	for mode in [1, 2]:
		await start(mode)
		geometry(mode == 2)
		var s: Node = current_scene
		POLICY.dev_override = 0
		root.size = Vector2i(1920, 1080)
		await frames()
		check(s._layout.is_landscape == (mode == 2), "mode frozen through override/resize")
		s._on_roll_button_pressed()
		await s.dice_tray_3d.roll_finished
		await create_timer(0.5).timeout
		check(s.hero_rolls.size() == 3 and s.enemy_rolls.size() == 3, "six seeded rolls")
		check(s.hero_rolls == {"combat":12,"engineer":7,"medic":8}, "unchanged deterministic hero rolls")
		if mode == 2:
			var zone: Rect2 = s._layout.get_combat_zone_rect()
			for overlay in s._die_tooltip_overlays:
				check(zone.encloses(overlay.get_global_rect()), "die + tag hit area stays in center")
			var die_at: Vector2 = s.dice_tray_3d.get_die_screen_position("hero", "combat")
			mouse(die_at, true)
			await create_timer(0.55).timeout
			check(_inspect.is_open(), "actual pointer long press opens shared inspect")
			if _inspect.is_open():
				check(root.get_visible_rect().encloses(_inspect._active._panel.get_global_rect()), "inspect on screen")
			mouse(die_at, false)
			_inspect.dismiss()
			await frames()
			s.protocol_points = 10
			s._protocol._on_nudge_button_pressed()
			await frames()
			check(s.turn_phase == s.PHASE_NUDGE_PICK, "Nudge armed")
			var before: int = s.protocol_points
			mouse(die_at, true)
			mouse(die_at, false)
			await frames()
			# Reproduced in the untouched portrait source (external baseline probe).
			# Do not repair this pre-existing input cancellation in a layout task.
			check(s.protocol_points == before and s.turn_phase == s.PHASE_TARGETING, "existing die-press cancellation preserved")
			s._protocol._on_nudge_button_pressed()
			s._on_hero_card_pressed("combat")
			check(s.protocol_points == before - 1 and s.hero_roll_nudges.has("combat"), "shared card Nudge handler spends once")
			var card: Control = s.hero_card_views[0].card
			var rest := card.position
			s._feedback._lunge(card, "hero")
			await create_timer(0.05).timeout
			check(card.position.x > rest.x and is_equal_approx(card.position.y, rest.y), "hero lunge points right")
			await create_timer(0.3).timeout
			check(card.position.is_equal_approx(rest), "lunge restores rest position")
		# Rebuild via the real summon event consumer after an enemy death.
		s.combat_manager.get_enemy_states()[1].dead = true
		s._process_summon_events([{"type":"summon", "summon_name":"Scrap Drone"}])
		await create_timer(0.8).timeout
		check(s.enemy_card_views.size() == 3 and s.enemy_cards.get_child_count() == 3, "replacement leaves exactly three live UI slots")
		geometry(mode == 2)
		await start(mode, "hive", 10)
		s = current_scene
		check(s.enemy_card_views.size() == 2, "Matriarch starts with escort")
		s.combat_manager._battle_round = 3
		s.combat_manager._round_events.clear()
		s.combat_manager._apply_boss_enemy_phase_rules({})
		var events: Array = s.combat_manager._round_events.duplicate(true)
		check(events.any(func(event): return event.type == "summon"), "real third-phase Brood emits summon")
		s._process_summon_events(events)
		await create_timer(0.8).timeout
		check(s.enemy_card_views.size() == 3, "Brood adds visible third slot")
		geometry(mode == 2)
		s._process_summon_events(events)
		await frames()
		check(s.enemy_card_views.size() == 3, "fourth summon blocked by shared cap")
	await start(0, "facility", 1, true)
	check(not current_scene._layout.is_landscape, "real AUTO tutorial portrait")
	await start(2, "facility", 1, true)
	check(current_scene._layout.is_landscape, "real forced tutorial landscape")
	POLICY.dev_override = 0
	print("[BATTLE_LAYOUT] %s: %d checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
