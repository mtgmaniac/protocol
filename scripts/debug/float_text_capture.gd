# Float-text redesign verification: launches a battle, drives the BattleFeedback
# float channel directly (presentation only — combat state untouched except the
# burn-tick replay), and screenshots each scenario mid-flight at 540x1200.
#
# Run:
#   godot --headless --path . --script res://scripts/debug/float_text_capture.gd
# Scenarios (all by default): single_hit big_hit heal shield negate stack
#   roll_buff_single roll_buff_squad aoe burn_tick
extends SceneTree

const OUTPUT_DIR := "res://debug_artifacts/float_text"
const SQUAD := ["shield", "avalanche", "pulse"]
const CAPTURE_SIZE := Vector2i(540, 1200)
# Capture 0.28s after spawn: punch-in settled, rise underway, alpha still high.
const MID_FLIGHT_DELAY := 0.28
const SCENARIO_COOLDOWN := 1.1

var _scenarios: PackedStringArray = []


func _initialize() -> void:
	root.size = CAPTURE_SIZE
	# User args land after `--` on the command line — get_cmdline_args() alone
	# misses them.
	for arg in Array(OS.get_cmdline_args()) + Array(OS.get_cmdline_user_args()):
		if str(arg).begins_with("--float-scenario="):
			_scenarios = str(arg).get_slice("=", 1).split(",", false)
	if _scenarios.is_empty():
		_scenarios = PackedStringArray(["single_hit", "big_hit", "heal", "shield", "negate",
			"stack", "roll_buff_single", "roll_buff_squad", "aoe", "burn_tick"])
	call_deferred("_run")


func _run() -> void:
	root.get_node("/root/GameState").start_run(SQUAD, "facility")
	root.get_node("/root/GameState").advance_to_next_battle()
	change_scene_to_file("res://scenes/battle/BattleScene.tscn")
	var retries := 120
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/battle/BattleScene.tscn":
			break
	await create_timer(1.2).timeout
	# Roll so dice have settled positions (roll_buff floats anchor to dice).
	await _roll_dice()
	for scenario in _scenarios:
		await _play_scenario(scenario)
		await create_timer(SCENARIO_COOLDOWN).timeout
	quit(0)


func _roll_dice() -> void:
	var roll_button: Button = current_scene.get_node_or_null("%RollButton") as Button
	if roll_button == null or roll_button.disabled or not roll_button.visible:
		return
	var dice_tray: Node = current_scene.get_node_or_null("%DiceTray3D")
	roll_button.emit_signal("pressed")
	if dice_tray != null and dice_tray.has_signal("roll_finished"):
		await dice_tray.roll_finished
	else:
		await create_timer(2.0).timeout
	await create_timer(0.4).timeout


func _feedback() -> Node:
	return current_scene.get("_feedback")


func _card(side: String, index: int) -> Control:
	var views: Array = current_scene.get("hero_card_views" if side == "hero" else "enemy_card_views")
	if views == null or index >= views.size():
		return null
	return (views[index] as Dictionary).get("card") as Control


func _state_id(side: String, index: int) -> String:
	var views: Array = current_scene.get("hero_card_views" if side == "hero" else "enemy_card_views")
	if views == null or index >= views.size():
		return ""
	return str(((views[index] as Dictionary).get("state") as Dictionary).get("id", ""))


func _play_scenario(scenario: String) -> void:
	var fb: Node = _feedback()
	match scenario:
		"single_hit":
			fb.call("_spawn_floating_text", _card("enemy", 0), "damage", 6)
		"big_hit":
			fb.call("_spawn_floating_text", _card("enemy", 0), "damage", 40)
		"heal":
			fb.call("_spawn_floating_text", _card("hero", 0), "heal", 8)
		"shield":
			fb.call("_spawn_floating_text", _card("hero", 0), "shield", 8)
		"negate":
			var card: Control = _card("hero", 1)
			fb.call("_spawn_floating_text", card, "block", 0)
			fb.call("_hex_flash", card, Color(0.55, 0.82, 1.0, 0.95))
		"stack":
			# Two numeric floats on ONE card in the same resolution — the
			# stacking rule keeps them separated.
			var target: Control = _card("enemy", 1)
			fb.call("_spawn_floating_text", target, "damage", 12)
			fb.call("_spawn_floating_text", target, "spike", 4)
		"roll_buff_single":
			fb.call("_spawn_roll_buff_float",
				{"side": "hero", "target_id": _state_id("hero", 0), "amount": 2}, false, {})
		"roll_buff_squad":
			fb.call("_spawn_roll_buff_float",
				{"side": "hero", "target_id": _state_id("hero", 0), "amount": 1}, true, {})
		"aoe":
			# Enemy AoE into the squad — battle 1 only fields 2 enemies, the hero
			# rail always has 3 cards.
			for i in 3:
				var hero_card: Control = _card("hero", i)
				if hero_card != null:
					fb.call("_spawn_floating_text", hero_card, "damage", 5)
		"burn_tick":
			# Real end-of-round pacing: three per-unit tick groups through the
			# actual sequencer — verifies ticks sweep, not blob. Fire-and-forget,
			# screenshot mid-sequence.
			var events: Array = []
			for i in 3:
				var hero_card: Control = _card("hero", i)
				if hero_card == null:
					continue
				var views: Array = current_scene.get("hero_card_views")
				var state: Dictionary = (views[i] as Dictionary).get("state")
				events.append({"type": "action_start", "amount": 0, "side": "hero",
					"actor_id": str(state["id"]), "actor_name": "Burn", "ability": "Burn", "zone": "tick"})
				events.append({"type": "damage", "amount": 3, "side": "hero",
					"target_id": str(state["id"]), "target_name": str(state["unit"].display_name),
					"hp_after": int(state.get("current_hp", 10)), "hp_max": int(state.get("max_hp", 10))})
			fb.call("play_round_feedback", events)
			# First tick float is airborne now; second lands ~0.5s later. Capture
			# twice to show the sweep.
			await create_timer(0.30).timeout
			await _capture("burn_tick_a")
			await create_timer(0.55).timeout
			await _capture("burn_tick_b")
			return
		_:
			print("[FLOAT_CAPTURE] unknown scenario: %s" % scenario)
			return
	await create_timer(MID_FLIGHT_DELAY).timeout
	_dump_float_labels(scenario)
	await _capture(scenario)


func _dump_float_labels(tag: String) -> void:
	var layer: Control = current_scene.get("float_layer")
	if layer == null:
		return
	for child in layer.get_children():
		if child is Label:
			var l: Label = child
			print("[FLOAT_DEBUG] %s text='%s' font=%d size=%s scale=%s modulate=%s pos=%s" % [
				tag, l.text, l.get_theme_font_size("font_size"), l.size, l.scale, l.modulate, l.position])


func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var absolute_dir: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var image: Image = root.get_texture().get_image()
	if image == null:
		push_error("[FLOAT_CAPTURE] no viewport image for %s" % name)
		return
	var path: String = "%s/%s.png" % [absolute_dir, name]
	image.save_png(path)
	print("[FLOAT_CAPTURE] saved %s" % path)
