# Touch scrolling gate (playtest 2026-10-01: the evolution screen was hard to
# scroll on a phone).
#
#   godot --headless --path . -s scripts/debug/touch_scroll_test.gd
#
# Godot 4.6's ScrollContainer only drag-scrolls when the press reaches it; a
# MOUSE_FILTER_STOP child (card panels, buttons) swallowed it. Every scrolling
# screen now runs PixelUI.enable_touch_scroll. For each one this drives REAL
# input into the root viewport, starting ON a button inside the list:
#   - phone:  a touch drag scrolls the list and does not press the button;
#             a touch tap presses it;
#   - touch-capable laptop: a mouse drag scrolls and does not press;
#             a mouse click presses.
# Input.emulate_touch_from_mouse makes the machine report a touchscreen, the
# condition ScrollContainer's drag-scrolling depends on. A list that does not
# overflow at 1080x2400 gets its content stretched so there is room to scroll;
# the controls under the finger are the screen's real ones.
# FAIL-ON-OLD: without enable_touch_scroll every drag case scrolls 0.
extends SceneTree

const DRAG_PX := 360.0

var _errors: Array[String] = []
var _presses: int = 0
var _screens_checked: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, label: String) -> void:
	if not cond:
		_errors.append(label)
		print("[TOUCH_SCROLL] FAIL %s" % label)


func _run() -> void:
	Input.emulate_touch_from_mouse = true
	# A phone-sized window. Headless defaults to 64x64, where the long-press
	# drag tolerance (26 device px) is ~975 design px and no drag cancels.
	root.size = Vector2i(540, 1200)
	await _frames(2)
	print("[TOUCH_SCROLL] window %s, final scale %.3f" % [str(root.size), root.get_final_transform().get_scale().x])
	var gs: Node = root.get_node("/root/GameState")
	var sm: Node = root.get_node("/root/SaveManager")

	# Evolution (the reported screen).
	gs.reset_run()
	gs.start_run(["shield", "medic", "engineer"], "facility", 777)
	gs.pending_evolution_unit_id = "shield"
	await _open_scene("res://scenes/ui/EvolutionScreen.tscn")
	await _exercise("evolution")

	# Reward.
	gs.reset_run()
	gs.start_run(["combat", "engineer", "medic"], "facility")
	gs.advance_to_next_battle()
	gs.set("pending_reward_item_ids", ["patch_kit", "scrap_plate", "momentum_core"])
	gs.set("claimed_reward_item_id", "")
	await _open_scene("res://scenes/ui/RewardScreen.tscn")
	await _exercise("reward")

	# Unlock (a fat run end: every section).
	sm.call("dev_reset_profile")
	((sm.get("data") as Dictionary)["stats"] as Dictionary)["battles_fought"] = 45
	sm.call("record_run_finished", "victory", "facility", 10)
	await _open_scene("res://scenes/ui/UnlockScreen.tscn")
	await _exercise("unlock")

	# Route Fork and Intercept beats.
	for beat in [["fork", "res://scenes/ui/RouteForkScreen.tscn"], ["intercept", "res://scenes/ui/InterceptScreen.tscn"]]:
		gs.reset_run()
		gs.start_run(["combat", "engineer", "medic"], "facility")
		gs.set("current_battle", 2)
		gs.get("run_beats").clear()
		gs.get("run_beats")[2] = {"type": beat[0], "tier": "minor"}
		gs.get("consumed_beats").clear()
		root.get_node("/root/SceneManager").call("go_to_next_battle_or_beat")
		await _wait_for_scene(str(beat[1]))
		await _exercise(str(beat[0]))

	# Help (Units tab) and the inspect popup, over the squad screen.
	gs.reset_run()
	await _open_scene("res://scenes/ui/UnitSelect.tscn")
	var help_script: GDScript = load("res://scripts/ui/help_menu.gd")
	help_script.call("open", current_scene)
	await _frames(4)
	var menu: Variant = help_script.get("_active")
	if menu != null:
		menu.call("_select_tab", "units")
	await _frames(6)
	await _exercise("help", menu as Node)
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
	await _frames(3)
	var inspect_script: GDScript = load("res://scripts/ui/inspect_popup.gd")
	var resolver: GDScript = load("res://scripts/ui/inspect_resolver.gd")
	inspect_script.call("open", current_scene, resolver.call("resolve_unit", root.get_node("/root/DataManager").call("get_unit", "shield")))
	await _frames(6)
	await _exercise("inspect", root)
	# Tap-to-close: a lone release (the finger that long-pressed to open it
	# lifting) keeps it open; a tap on it closes it.
	var popup_scroll: ScrollContainer = _find_scroll(root)
	_check(popup_scroll != null, "inspect: still open after the drags")
	if popup_scroll != null:
		var at: Vector2 = root.get_final_transform() * popup_scroll.get_global_rect().get_center()
		var lift := InputEventMouseButton.new()
		lift.button_index = MOUSE_BUTTON_LEFT
		lift.pressed = false
		lift.position = at
		lift.global_position = at
		root.push_input(lift)
		await _frames(4)
		_check(is_instance_valid(popup_scroll), "inspect: the opening finger's release does not close it")
		await _gesture("phone", popup_scroll.get_global_rect().get_center(), 0.0)
		_check(not is_instance_valid(popup_scroll), "inspect: a tap closes it")

	_check(_screens_checked.size() == 7, "all seven scroll screens exercised (%s)" % str(_screens_checked))
	sm.call("dev_reset_profile")
	gs.reset_run()
	if _errors.is_empty():
		print("[TOUCH_SCROLL] PASS (%s)" % ", ".join(_screens_checked))
		quit(0)
	else:
		print("[TOUCH_SCROLL] FAIL (%d)" % _errors.size())
		quit(1)


func _exercise(screen: String, base: Node = null) -> void:
	var scroll: ScrollContainer = _find_scroll(base if base != null else current_scene)
	_check(scroll != null, "%s: a touch-scroll list exists" % screen)
	if scroll == null:
		return
	_screens_checked.append(screen)
	await _ensure_overflow(scroll)
	for mode in ["phone", "laptop"]:
		_check(is_instance_valid(scroll), "%s: the list survives the %s drag" % [screen, "phone" if mode == "laptop" else "setup"])
		if not is_instance_valid(scroll):
			return
		var target: Dictionary = _target(scroll)
		_check(not target.is_empty(), "%s: a control inside the list to start on" % screen)
		if target.is_empty():
			return
		scroll.scroll_vertical = 0
		await _frames(2)
		_presses = 0
		var counter := func() -> void: _presses += 1
		var sig: Signal = target["signal"]
		if not sig.is_null():
			sig.connect(counter)
		await _gesture(mode, (target["control"] as Control).get_global_rect().get_center(), -DRAG_PX)
		_check(is_instance_valid(scroll), "%s %s: a drag on the list does not close it" % [screen, mode])
		if not is_instance_valid(scroll):
			return
		_check(scroll.scroll_vertical > 0, "%s %s: a drag that starts on %s scrolls the list (scrolled %d)" % [screen, mode, target["what"], scroll.scroll_vertical])
		_check(_presses == 0, "%s %s: the drag does not activate %s" % [screen, mode, target["what"]])
		if not sig.is_null() and sig.is_connected(counter):
			sig.disconnect(counter)
	# Taps last: activating a control may change the screen.
	for mode in ["phone", "laptop"]:
		if not is_instance_valid(scroll):
			# The phone tap navigated away (e.g. an intercept choice); the
			# laptop click is covered on the screens that stay.
			print("[TOUCH_SCROLL] %s: %s tap skipped (the list was replaced)" % [screen, mode])
			return
		var tap_target: Dictionary = _target(scroll)
		if tap_target.is_empty() or (tap_target["signal"] as Signal).is_null():
			print("[TOUCH_SCROLL] %s: no tappable control in the list (drag cases only)" % screen)
			return
		scroll.scroll_vertical = 0
		await _frames(2)
		_presses = 0
		var tap_counter := func() -> void: _presses += 1
		var tap_sig: Signal = tap_target["signal"]
		tap_sig.connect(tap_counter)
		await _gesture(mode, (tap_target["control"] as Control).get_global_rect().get_center(), 0.0)
		_check(_presses == 1, "%s %s: a tap still activates %s (fired %d)" % [screen, mode, tap_target["what"], _presses])
		if tap_sig.is_connected(tap_counter):
			tap_sig.disconnect(tap_counter)
		print("[TOUCH_SCROLL] %s %s: drag scrolled, tap on %s fired once" % [screen, mode, tap_target["what"]])
		if mode == "phone":
			# The tap may have rebuilt the list; let it settle before the click.
			await _frames(4)


func _find_scroll(base: Node) -> ScrollContainer:
	if base == null:
		return null
	for node in base.find_children("*", "ScrollContainer", true, false):
		if (node as Node).has_meta("touch_scroll") and (node as Control).is_visible_in_tree():
			return node as ScrollContainer
	return null


# What to start the gesture on, inside the scroll view: a button (its pressed
# signal), else a long-press row (its tapped signal), else any row that used to
# swallow input (drag only — e.g. the inspect popup's ability rows).
func _target(scroll: ScrollContainer) -> Dictionary:
	var view: Rect2 = scroll.get_global_rect()
	var inside := func(c: Control) -> bool:
		return c.is_visible_in_tree() and view.has_point(c.get_global_rect().get_center()) and c.get_global_rect().size.y >= 48.0
	for node in scroll.find_children("*", "BaseButton", true, false):
		var button: BaseButton = node as BaseButton
		if not button.disabled and inside.call(button):
			return {"control": button, "signal": button.pressed, "what": "a button"}
	for node in scroll.find_children("*", "Node", true, false):
		if node.get_class() == "Node" and node.has_signal("tapped") and node.get_parent() is Control and inside.call(node.get_parent()):
			return {"control": node.get_parent(), "signal": Signal(node, "tapped"), "what": "a long-press row"}
	for node in scroll.find_children("*", "Control", true, false):
		var c: Control = node as Control
		if c.mouse_filter == Control.MOUSE_FILTER_PASS and not (c is Container) and inside.call(c):
			return {"control": c, "signal": Signal(), "what": "a row"}
	for node in scroll.find_children("*", "PanelContainer", true, false):
		if (node as Control).mouse_filter == Control.MOUSE_FILTER_PASS and inside.call(node):
			return {"control": node, "signal": Signal(), "what": "a panel"}
	# Nothing under the finger takes input at all (the inspect popup's rows):
	# the list itself.
	return {"control": scroll, "signal": Signal(), "what": "the list"}


func _ensure_overflow(scroll: ScrollContainer) -> void:
	await _frames(2)
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	if bar.max_value - bar.page >= DRAG_PX:
		return
	var content: Control = scroll.get_child(0) as Control
	if content != null:
		content.custom_minimum_size.y = scroll.size.y + DRAG_PX * 2.0
	await _frames(4)


# phone: touch through Input (Godot also emulates the mouse, as on a device);
# laptop: mouse events only, straight into the viewport (a touch-capable laptop).
func _gesture(mode: String, at: Vector2, dy: float) -> void:
	var xf: Transform2D = root.get_final_transform()
	var steps := 8
	var start: Vector2 = xf * at
	var travel: Vector2 = xf.basis_xform(Vector2(0.0, dy))
	if mode == "phone":
		var touch := InputEventScreenTouch.new()
		touch.position = start
		touch.pressed = true
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		for k in steps:
			await process_frame
			if dy != 0.0:
				var drag := InputEventScreenDrag.new()
				drag.position = start + travel * float(k + 1) / steps
				drag.relative = travel / steps
				Input.parse_input_event(drag)
				Input.flush_buffered_events()
		await process_frame
		var lift := InputEventScreenTouch.new()
		lift.position = start + travel
		lift.pressed = false
		Input.parse_input_event(lift)
		Input.flush_buffered_events()
	else:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.button_mask = MOUSE_BUTTON_MASK_LEFT
		press.position = start
		press.global_position = start
		root.push_input(press)
		for k in steps:
			await process_frame
			if dy != 0.0:
				var motion := InputEventMouseMotion.new()
				motion.position = start + travel * float(k + 1) / steps
				motion.global_position = motion.position
				motion.relative = travel / steps
				motion.button_mask = MOUSE_BUTTON_MASK_LEFT
				root.push_input(motion)
		await process_frame
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		release.position = start + travel
		release.global_position = release.position
		root.push_input(release)
	await _frames(6)


func _open_scene(path: String) -> void:
	change_scene_to_file(path)
	await _wait_for_scene(path)


func _wait_for_scene(path: String) -> void:
	for _i in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path and current_scene.is_node_ready():
			break
	await _frames(8)


func _frames(n: int) -> void:
	for _i in n:
		await process_frame
