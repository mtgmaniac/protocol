extends SceneTree

class FloatHost extends Control:
	var float_layer: Control

var failures: Array[String] = []
var booted := false
var flared := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func run() -> void:
	await process_frame
	root.size = Vector2i(540, 1200)
	root.content_scale_size = Vector2i(1080, 2400)
	var settings: Node = root.get_node("SaveManager")
	var gs: Node = root.get_node("GameState")
	root.get_node("AudioManager").set_suppressed(true)
	check(not PixelUI.reduced_motion_enabled(), "Reduced Motion defaults off")
	# Exercise real serialization using a disposable test file, never a player profile.
	settings.set("_save_path", "user://visual_choice_motion_test.json")
	settings.set("_disk_enabled", true)
	settings.set_setting("reduced_motion", true)
	settings.load_save()
	check(PixelUI.reduced_motion_enabled(), "Reduced Motion survives a save reload")
	var logo: Control = load("res://scenes/ui/TitleLogo.tscn").instantiate()
	root.add_child(logo)
	logo.boot_finished.connect(func() -> void: booted = true)
	logo.flare_finished.connect(func() -> void: flared = true)
	logo.boot_in()
	await create_timer(0.2).timeout
	check(booted, "Reduced logo boot releases menu navigation")
	check(logo.get_node("Stack").scale == Vector2.ONE, "Reduced logo has no zoom")
	settings.set_setting("reduced_motion", false)
	await process_frame
	check(logo.get("_core_pulse_tween").is_running(), "Normal motion can resume without restarting")
	settings.set_setting("reduced_motion", true)
	var x: float = logo.get_node("Stack").position.x
	logo.call("_fire_glitch")
	await create_timer(0.15).timeout
	check(logo.get_node("Stack").position.x == x, "Reduced mode suppresses live logo glitches")
	logo.flare_out()
	await create_timer(0.3).timeout
	check(flared, "Reduced logo exit releases Begin")
	logo.queue_free()
	await process_frame
	var host := FloatHost.new()
	root.add_child(host)
	host.float_layer = Control.new()
	host.add_child(host.float_layer)
	var card := Control.new()
	card.position = Vector2(40, 300)
	card.size = Vector2(300, 500)
	host.add_child(card)
	var feedback: Node = load("res://scripts/battle/battle_feedback.gd").new()
	host.add_child(feedback)
	feedback.setup(host)
	feedback._spawn_floating_text(card, "damage", 12)
	feedback._shake(card, 10.0, 0.3)
	var result: Label = host.float_layer.get_child(0)
	var initial_position := result.position
	var initial_scale := result.scale
	await create_timer(0.25).timeout
	check(result.text == "-12" and result.modulate.a > 0.9, "Reduced Motion keeps damage results readable")
	check(result.position == initial_position and result.scale == initial_scale, "Reduced numbers do not rise or punch")
	check(card.position == Vector2(40, 300), "Reduced hits do not shake the card")
	host.queue_free()
	await process_frame

	# Select, change the selection, expand a kit, then commit through the real button.
	gs.start_run(["combat", "avalanche", "medic"], "facility")
	gs.current_battle = 3
	gs.run_beats[3] = {"type": "fork"}
	gs.unit_xp["avalanche"] = 100
	gs.pending_evolution_unit_id = "avalanche"
	change_scene_to_file("res://scenes/ui/EvolutionScreen.tscn")
	await process_frame
	await process_frame
	var screen: Control = current_scene
	var paths: Array = gs.get_pending_evolution_paths()
	var full: Control = screen.find_child("FullAbilities", true, false)
	check(not full.visible and full.get_child_count() == 5, "Evolution starts compact but retains the whole kit")
	screen.find_child("ExpandAbilities", true, false).pressed.emit()
	check(full.visible, "Full kit is accessible before committing")
	var buttons: Dictionary = screen.get("_path_buttons")
	buttons[str(paths[0].name)].pressed.emit()
	check(not gs.unit_evolutions.has("avalanche"), "Selecting does not apply a permanent evolution")
	buttons[str(paths[1].name)].pressed.emit()
	check(not gs.unit_evolutions.has("avalanche"), "Changing selection does not apply a permanent evolution")
	screen.find_child("ConfirmEvolution", true, false).pressed.emit()
	check(str(gs.unit_evolutions.get("avalanche", "")) == str(paths[1].name), "Confirm applies the selected branch")
	await create_timer(0.3).timeout
	check(current_scene.scene_file_path.ends_with("RouteForkScreen.tscn"), "Confirmed evolution continues to its scheduled route choice")
	check(not root.get_node("TransitionManager").get("_running"), "Reduced navigation leaves no input-blocking overlay")
	settings.set_setting("reduced_motion", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://visual_choice_motion_test.json"))
	settings.set("_disk_enabled", false)
	for failure in failures:
		push_error(failure)
	print("[VISUAL_CHOICE_MOTION] " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
