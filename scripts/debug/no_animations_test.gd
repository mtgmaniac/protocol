# "No animations" regression (G-49, Kev 2026-10-06).
#
#   godot --headless --path . -s scripts/debug/no_animations_test.gd [-- --no-animations-break=ignored]
#
# Every site the setting covers, checked with it OFF (the animation runs) and ON
# (the result appears at once, readable, and nothing moves or fades):
#   Settings row (off by default, stored, does not flip the Reduced motion row)
#   battle numbers, card flash, hit pause, slow-motion beat, drifting label,
#   ability name on a 20, HP bar, ability pips, item confirm ring, jam flicker
#   (live battle); tutorial spotlight ring; title buttons and logo exit; scene
#   transition
# and what it must NOT touch: the dice still roll for real with it ON.
# scripts/checks/break_gate.py reruns it with --no-animations-break=ignored
# (the setting does nothing) and requires a FAIL.
extends SceneTree

class FloatHost extends Control:
	var float_layer: Control

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const SAVE_FILE := "user://no_animations_test.json"
const KEY := "no_animations"

var _errors: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_errors.append(what)


func sm() -> Node:
	return root.get_node("/root/SaveManager")


func _set_on(on: bool) -> void:
	sm().set_setting(KEY, on)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _newest(layer: Node) -> Node:
	return layer.get_child(layer.get_child_count() - 1) if layer.get_child_count() > 0 else null


func _run() -> void:
	await process_frame
	root.size = Vector2i(540, 1200)
	root.content_scale_size = Vector2i(1080, 2400)
	root.get_node("/root/AudioManager").set_suppressed(true)
	# Real serialization into a disposable file, never a player profile.
	sm().set("_save_path", SAVE_FILE)
	sm().set("_disk_enabled", true)
	_expect(not PixelUI.no_animations_enabled() and not PixelUI.reduced_motion_enabled(), "No animations and Reduced Motion default off")

	await _check_settings_rows()
	await _check_feedback()
	await _check_spotlight()
	await _check_battle()
	await _check_menu_and_transition()

	_set_on(false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE + ".bak"))
	sm().set("_disk_enabled", false)
	for error in _errors:
		print("[NO_ANIMATIONS] FAIL - %s" % error)
	print("[NO_ANIMATIONS] %s" % ("PASS" if _errors.is_empty() else "FAIL - %d check(s)" % _errors.size()))
	sm().clear_run_save()
	if current_scene != null:
		current_scene.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)


# ── Settings rows ─────────────────────────────────────────────────────────────
func _toggle_of(help: GDScript, row_name: String) -> Button:
	var row: Node = help._active.find_child(row_name, true, false)
	if row == null:
		return null
	for child in row.get_children():
		if child is Button:
			return child
	return null


func _check_settings_rows() -> void:
	var host := Control.new()
	root.add_child(host)
	var help: GDScript = load("res://scripts/ui/help_menu.gd")
	help.open(host)
	await _frames(8)
	help._active._select_tab("settings")
	await _frames(8)
	var toggle: Button = _toggle_of(help, "NoAnimationsToggleRow")
	_expect(toggle != null and not toggle.button_pressed, "Settings has a No animations row, off")
	if toggle != null:
		toggle.button_pressed = true
		_expect(bool(sm().get_setting(KEY, false)), "turning the row on stores the setting")
		sm().load_save()
		_expect(bool(sm().get_setting(KEY, false)), "the setting survives a save reload")
		_expect(not bool(sm().get_setting("reduced_motion", false)), "it does not turn the Reduced Motion setting on")
		_expect(PixelUI.no_animations_enabled() and PixelUI.reduced_motion_enabled(), "No animations also applies everything Reduced Motion does")
		# The Reduced motion row keeps showing its own setting.
		help._active._select_tab("basics")
		await _frames(4)
		help._active._select_tab("settings")
		await _frames(8)
		var reduced_row: Button = null
		for node in help._active.find_children("*", "Button", true, false):
			var parent: Node = (node as Button).get_parent()
			if (node as Button).toggle_mode and parent != null and parent.get_child_count() > 0 \
					and parent.get_child(0) is Label and (parent.get_child(0) as Label).text == "Reduced motion":
				reduced_row = node
		_expect(reduced_row != null and not reduced_row.button_pressed, "the Reduced motion row still reads off")
		var again: Button = _toggle_of(help, "NoAnimationsToggleRow")
		_expect(again != null and again.button_pressed, "the No animations row reads on after a rebuild")
		if again != null:
			again.button_pressed = false
		_expect(not bool(sm().get_setting(KEY, false)), "turning the row off stores the setting")
	help._active.dismiss()
	await _frames(4)
	host.queue_free()
	await process_frame


# ── Battle feedback primitives (stub host, as visual_choice_motion_test) ──────
func _check_feedback() -> void:
	var host := FloatHost.new()
	host.size = Vector2(1080, 2400)
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

	for on in [false, true]:
		_set_on(on)
		var tag: String = "ON" if on else "OFF"

		# Battle numbers.
		feedback._spawn_floating_text(card, "damage", 12)
		var number: Label = _newest(host.float_layer) as Label
		var spawn_pos: Vector2 = number.position
		var spawn_scale: Vector2 = number.scale
		await create_timer(1.0).timeout
		if on:
			_expect(number.text == "-12" and is_equal_approx(number.modulate.a, 1.0), "ON: a battle number stays at full strength")
			_expect(number.position == spawn_pos and number.scale == spawn_scale, "ON: a battle number does not rise or change size")
			await create_timer(0.8).timeout
			_expect(not is_instance_valid(number), "ON: a battle number is removed after its time, not left on screen")
		else:
			_expect(number.modulate.a < 0.95 and number.position.y < spawn_pos.y, "OFF: a battle number rises and fades")
			await create_timer(0.8).timeout

		# Card flash.
		card.modulate = Color.WHITE
		feedback._flash_card(card, "damage")
		_expect((card.modulate == Color.WHITE) == on, "%s: the card flash on a hit is %s" % [tag, "off" if on else "on"])
		await create_timer(0.3).timeout
		card.modulate = Color.WHITE

		# Hit pause and the slow-motion beat (time effects).
		feedback._hit_pause(20)
		_expect(is_equal_approx(Engine.time_scale, 1.0) == on, "%s: the hit pause %s" % [tag, "is skipped" if on else "stops time briefly"])
		await create_timer(0.2, true, false, true).timeout
		feedback._slow_mo()
		_expect(is_equal_approx(Engine.time_scale, 1.0) == on, "%s: the slow-motion beat %s" % [tag, "is skipped" if on else "slows time briefly"])
		await create_timer(0.3, true, false, true).timeout
		_expect(is_equal_approx(Engine.time_scale, 1.0), "%s: time runs normally afterwards" % tag)

		# Drifting label (Siphon / Hijack).
		var target: Vector2 = card.get_global_rect().get_center() - host.float_layer.get_global_position()
		feedback._drift_pip(Vector2(900, 2000), card, Color.WHITE, "-2")
		var pip: Label = _newest(host.float_layer) as Label
		_expect((pip.position == target) == on, "%s: the drain label %s" % [tag, "appears on its target" if on else "starts away from its target and drifts"])
		await create_timer(0.3).timeout
		if on:
			_expect(pip.position == target and is_equal_approx(pip.modulate.a, 1.0), "ON: the drain label does not move or fade")
		await create_timer(0.5).timeout
		_expect(not is_instance_valid(pip), "%s: the drain label is removed" % tag)

		# Ability name on a 20.
		feedback._slam_ability_name(card, "Test Name")
		var name_label: Label = _newest(host.float_layer) as Label
		await create_timer(0.05).timeout
		if on:
			_expect(name_label.scale == Vector2.ONE and is_equal_approx(name_label.modulate.a, 1.0), "ON: the ability name appears at once, full size")
		else:
			_expect(name_label.scale != Vector2.ONE, "OFF: the ability name punches in")
		await create_timer(0.85).timeout
		_expect(not is_instance_valid(name_label), "%s: the ability name is removed" % tag)

	_set_on(false)
	host.queue_free()
	await process_frame


# ── Tutorial spotlight ring ───────────────────────────────────────────────────
func _check_spotlight() -> void:
	for on in [false, true]:
		_set_on(on)
		var layer: Node = load("res://scripts/ui/spotlight_layer.gd").new()
		root.add_child(layer)
		await _frames(2)
		var pulse: Tween = layer.get("_ring_tween")
		var pulsing: bool = pulse != null and pulse.is_valid() and pulse.is_running()
		_expect(pulsing != on, "%s: the tutorial ring %s" % ["ON" if on else "OFF", "is steady" if on else "pulses"])
		layer.queue_free()
		await process_frame
	_set_on(false)


# ── Live battle: HP bar, pips, item ring, jam flicker, and the dice ───────────
func _check_battle() -> void:
	var gs: Node = root.get_node("/root/GameState")
	gs.start_run(["combat", "engineer", "medic"], "facility", 61008)
	gs.advance_to_next_battle()
	gs.current_battle = 2
	change_scene_to_file(BATTLE_SCENE)
	for i in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE:
			break
	await create_timer(0.8).timeout
	var scene: Node = current_scene
	if scene == null or scene.scene_file_path != BATTLE_SCENE:
		_errors.append("battle scene did not load")
		return

	# The dice are NOT part of the setting: with it ON a roll is still a real
	# throw that takes time and lands every die.
	_set_on(true)
	var tray: Node = scene.dice_tray_3d
	var started_ms: int = Time.get_ticks_msec()
	var rolling_seen: bool = false
	var roll: Signal = tray.roll_finished
	scene._begin_targeting_phase()
	for i in 12:
		await process_frame
		rolling_seen = rolling_seen or bool(tray.get("_is_rolling"))
	if bool(tray.get("_is_rolling")):
		await roll
	await _frames(4)
	_expect(rolling_seen and Time.get_ticks_msec() - started_ms >= 500, "ON: the dice still roll for real (took %d ms)" % (Time.get_ticks_msec() - started_ms))
	_expect(bool(scene.dice_landed()) and scene.hero_rolls.size() == 3, "ON: every die lands and shows its value")
	if int(scene.turn_phase) == int(scene.PHASE_TARGETING):
		await scene._auto_assign_pending_targets(false)

	var view: Dictionary = scene.hero_card_views[0]
	var card: Node = view["card"]
	var readout: Node = view["readout"]
	var hero_id: String = str((view["state"] as Dictionary)["id"])
	for on in [false, true]:
		_set_on(on)
		var tag: String = "ON" if on else "OFF"

		# HP bar.
		card._set_hp_display(1.0, 1.0)
		var settle: Tween = card.get("_hp_drain_tween")
		if settle != null and settle.is_valid():
			settle.kill()
		card.set("_hp_ratio_shown", 1.0)
		(card.get("_hp_fill") as ColorRect).anchor_right = 1.0
		card._set_hp_display(0.4, 0.4)
		var fill: ColorRect = card.get("_hp_fill")
		_expect(is_equal_approx(fill.anchor_right, 0.4) == on, "%s: the HP bar %s" % [tag, "lands on its new value at once" if on else "drains down"])
		await create_timer(0.45).timeout
		_expect(is_equal_approx(fill.anchor_right, 0.4), "%s: the HP bar ends on the right value" % tag)

		# Ability pips.
		readout.hide_pips()
		readout.show_pips()
		var row: Control = readout.get("_row_layer")
		if row != null:
			_expect(is_equal_approx(row.modulate.a, 1.0) == on, "%s: the ability pips %s" % [tag, "appear at once" if on else "fade in"])
		await create_timer(0.2).timeout

		# Item confirm ring.
		var panel := PanelContainer.new()
		scene.add_child(panel)
		scene._protocol._add_confirm_card_highlight(panel)
		var ring: Control = panel.get_node("ConfirmHighlight")
		await create_timer(0.3).timeout
		_expect(is_equal_approx(ring.modulate.a, 1.0) == on, "%s: the item confirm ring %s" % [tag, "is steady" if on else "pulses"])
		panel.queue_free()

		# Jam overlay flicker on the die.
		tray.play_jam_flicker("hero", hero_id, 10)
		var die: Node = tray._get_die_for_entry("hero", hero_id)
		var filter: Node3D = tray._die_part(die, "JamFilter") as Node3D
		var hidden_seen: bool = false
		var flicker_until: int = Time.get_ticks_msec() + 600
		while Time.get_ticks_msec() < flicker_until:
			await process_frame
			hidden_seen = hidden_seen or not filter.visible
		_expect(hidden_seen != on, "%s: the jam overlay %s" % [tag, "is steady" if on else "flickers"])
		_expect(filter.visible, "%s: the jam overlay ends on" % tag)
		tray._set_die_jam_visual(die, 0)
	_set_on(false)


# ── Title screen and scene transition ─────────────────────────────────────────
func _check_menu_and_transition() -> void:
	var transitions: Node = root.get_node("/root/TransitionManager")
	sm().clear_run_save()
	root.get_node("/root/GameState").reset_run()
	for on in [false, true]:
		_set_on(on)
		var tag: String = "ON" if on else "OFF"
		change_scene_to_file(MENU_SCENE)
		var begin: Button = null
		for i in 600:
			await process_frame
			if current_scene != null and current_scene.scene_file_path == MENU_SCENE:
				begin = null
				for node in current_scene.find_children("*", "Button", true, false):
					if (node as Button).text == "BEGIN":
						begin = node
				if begin != null and not begin.disabled:
					break
		if begin == null:
			_errors.append("%s: the menu never became usable" % tag)
			continue
		await _frames(2)
		_expect(is_equal_approx(begin.modulate.a, 1.0) == on, "%s: the title buttons %s" % [tag, "appear at once" if on else "fade in"])
		await create_timer(0.4).timeout
		_expect(is_equal_approx(begin.modulate.a, 1.0), "%s: the title buttons end fully visible" % tag)
		var logo: Node = current_scene.get("_logo")
		var pulse: Tween = logo.get("_core_pulse_tween")
		_expect((pulse != null and pulse.is_valid() and pulse.is_running()) != on, "%s: the title logo %s" % [tag, "is still" if on else "pulses"])
		var flared: Array = [false]
		logo.flare_finished.connect(func() -> void: flared[0] = true)
		logo.flare_out()
		await _frames(3)
		_expect(flared[0] == on, "%s: the logo exit %s" % [tag, "is immediate" if on else "plays"])
		await create_timer(0.5).timeout
		_expect(flared[0], "%s: the logo exit releases the menu" % tag)

		# Scene transition (the overlay path is forced on: headless has none).
		transitions.set("debug_force_active", true)
		transitions.change_scene(MENU_SCENE)
		_expect(not bool(transitions.get("_running")) or not on, "ON: a scene change is a straight cut, no overlay")
		transitions.set("debug_force_active", false)
		await create_timer(0.4).timeout
	_set_on(false)
