extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func settle() -> void:
	for _i in 16:
		await process_frame

func button_with_text(host: Node, text: String) -> Button:
	for node in host.find_children("*", "Button", true, false):
		if node.text == text:
			return node
	return null

func menu() -> void:
	change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	await create_timer(0.5).timeout

func run() -> void:
	await process_frame
	root.size = Vector2i(390, 844)
	root.content_scale_size = Vector2i(1080, 2400)
	root.get_node("AudioManager").set_suppressed(true)
	var sm = root.get_node("SaveManager")
	var gs = root.get_node("GameState")
	sm.set("data", sm.default_data())
	sm.set_setting("reduced_motion", true)
	# Old cadence settings must not resurrect the removed nudge.
	sm.data.stats.runs_finished = 4
	sm.data.settings.feedback_nudge_shown_at = 1
	sm.data.settings.feedback_nudge_dismissed = false
	await menu()
	check(button_with_text(current_scene, "TUTORIAL") == null, "No duplicate title Tutorial button")
	check(button_with_text(current_scene, "Tell me what to fix >") == null, "No duplicate feedback nudge")
	var feedback := button_with_text(current_scene, "FEEDBACK")
	check(feedback != null and not feedback.disabled, "Feedback remains enabled")
	check(feedback.pressed.is_connected(Callable(current_scene, "_on_feedback_pressed")), "Feedback keeps its gesture handler")
	await capture("title")
	button_with_text(current_scene, "BEGIN").pressed.emit()
	await create_timer(0.4).timeout
	var tutorial := button_with_text(current_scene, "RUN TUTORIAL")
	check(tutorial != null, "First Begin still offers training")
	check(button_with_text(current_scene, "SKIP TUTORIAL") != null, "First Begin still offers skip")
	await capture("first-run")
	if tutorial != null:
		tutorial.pressed.emit()
		await settle()
		check(current_scene.scene_file_path == "res://scenes/battle/BattleScene.tscn", "First-run tutorial enters battle")
	gs.reset_run()
	sm.mark_tutorial_done()
	await menu()
	button_with_text(current_scene, "BEGIN").pressed.emit()
	await create_timer(0.4).timeout
	check(current_scene.scene_file_path == "res://scenes/ui/UnitSelect.tscn", "Returning player Begin goes to selection")
	var help_script = load("res://scripts/ui/help_menu.gd")
	help_script.open(current_scene)
	await settle()
	var replay := button_with_text(help_script._active, "REPLAY TUTORIAL")
	check(replay != null, "Help retains tutorial replay")
	if replay != null:
		replay.pressed.emit()
		await settle()
		check(current_scene.scene_file_path == "res://scenes/battle/BattleScene.tscn", "Help replay enters training")
	gs.reset_run()
	var dm = root.get_node("DataManager")
	for scenario in ["single", "fat", "boss"]:
		sm.set("data", sm.default_data())
		if scenario == "single":
			sm.data.stats.battles_fought = 3
			sm.record_run_finished("defeat", "facility", 3)
		elif scenario == "fat":
			sm.data.stats.battles_fought = 45
			sm.record_run_finished("victory", "facility", 10)
		else:
			sm.data.unlocks.item_gates_awarded = dm.unlock_gate_count()
			sm.data.unlocks.hero_ladder_rung = sm.MAX_HERO_LADDER_RUNG
			sm.data.unlocks.heroes = sm.ALL_HEROES.duplicate()
			sm.data.unlocks.operations = sm.OPERATION_CHAIN.duplicate()
			sm.record_run_finished("victory", "facility", 10)
		change_scene_to_file("res://scenes/ui/UnlockScreen.tscn")
		await settle()
		var scene = current_scene
		check(scene.get("_compact_awards") == (scenario != "fat"), "%s: correct compact/scrolling layout" % scenario)
		var scroll: ScrollContainer = scene.get_node("%Scroll")
		var content: VBoxContainer = scene.get_node("%Sections")
		var action: Button = scene.get_node("%ContinueButton")
		check(action.get_global_rect().end.y <= scene.size.y, "%s: Continue remains on screen" % scenario)
		check(action.global_position.y > scene.size.y * 0.85, "%s: Continue stays near bottom" % scenario)
		check(content.size.x <= scroll.size.x + 1, "%s: no horizontal content overflow" % scenario)
		await capture("unlock-" + scenario)
		if scenario == "fat":
			check(scroll.size.y > scene.size.y * 0.5, "Large list retains a useful full-height viewport")
			check(content.size.y > scroll.size.y, "Large awards remain scrollable")
			scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
			await settle()
			check(scroll.scroll_vertical > 0, "Large awards can reach later entries")
			await capture("unlock-fat-bottom")
		else:
			var panel: Control = scene.get_node("%WindowPanel")
			check(panel.size.y < scene.size.y * 0.65, "Small awards avoid full-height frame")
			check(scroll.get_v_scroll_bar().max_value <= scroll.size.y + 1, "Compact awards do not need scrolling")
			# Reflow on a shorter viewport, then restore the reviewed phone layout.
			root.content_scale_size = Vector2i(1080, 1200)
			scene.call("_queue_award_fit")
			await settle()
			check(action.get_global_rect().end.y <= scene.size.y + 1, "Resized awards keep Continue on screen")
			root.content_scale_size = Vector2i(1080, 2400)
			scene.call("_queue_award_fit")
			await settle()
			check(scene.get("_compact_awards"), "Compact layout returns after resize")
	for failure in failures:
		push_error(failure)
	print("[TITLE_UNLOCK] %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://debug_artifacts/v11-review/")
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_png(folder + label + "-final.png")
