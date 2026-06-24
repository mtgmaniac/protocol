# Drives the rigged onboarding encounter: dims the screen, cuts a spotlight hole around one
# real UI element at a time, attaches a coachmark, and gates each beat on the player's actual
# action (via battle_scene's tutorial_event signal) or a tap. A persistent Skip ends it. Built
# in code over its own high CanvasLayer; the spotlight hole leaves the highlighted element
# fully interactive so gated steps work on the real control.
class_name TutorialController
extends CanvasLayer

const LAYER := 140
const DIM := Color(0.01, 0.015, 0.02, 0.82)
const PAD := 14.0
const COACH_FONT := 32
const HINT_FONT := 24
const SKIP_FONT := 26
const TITLE_FONT := 38
const SCREEN_MARGIN := 40.0
const ACCENT := Color("6fe0ef")  # PixelUI.DT_CYAN_BRIGHT

var _scene: Node = null
var _step: int = 0
var _steps: Array = []

var _dim_top: ColorRect = null
var _dim_bottom: ColorRect = null
var _dim_left: ColorRect = null
var _dim_right: ColorRect = null
var _ring: Panel = null
var _coach: PanelContainer = null
var _coach_label: Label = null
var _hint_label: Label = null
var _ring_tween: Tween = null


func start(scene: Node) -> void:
	_scene = scene
	_steps = _build_steps()
	_build_ui()
	if _scene.has_signal("tutorial_event"):
		_scene.tutorial_event.connect(_on_tutorial_event)
	_show_step(0)


# ── Step script ─────────────────────────────────────────────────────────────────
# Each step: { targets:[keys], text, advance:"tap"|event, phase:"" (optional event predicate),
# title:"" (optional) }. Keys resolve to battle nodes in _target_rect().
func _build_steps() -> Array:
	return [
		# Phase 0 — orientation (tap)
		{"targets": ["header"], "text": "This bar stays with you all run — squad progress and the Help menu live here. Help holds the full encyclopedia."},
		{"targets": ["hero_cards"], "text": "Your three specialists. Each has its own HP and abilities."},
		{"targets": ["enemy_cards"], "text": "Your target. Enemies telegraph their hit — you can see what's coming before it lands."},
		{"targets": [], "text": "Long-press anything — a unit, a die, an item — to inspect it.", "title": "INSPECT"},
		# Phase 1 — turn 1: the core loop
		{"targets": ["roll_button"], "text": "Tap Roll to set your dice.", "advance": "rolled"},
		{"targets": ["hero_dice"], "text": "Each die slots into a band. Higher rolls fire stronger abilities."},
		{"targets": ["hero_cards"], "text": "Every unit's bands differ — long-press a card to see its ranges."},
		{"targets": ["enemy_cards"], "text": "Tap a die, then tap a target to fire it.", "advance": "assigned"},
		{"targets": ["enemy_cards"], "text": "Assign your remaining dice.", "advance": "phase", "phase": "ready_to_end"},
		{"targets": ["enemy_readouts"], "text": "Here's what the enemy will do next turn. Control matters."},
		{"targets": ["roll_button"], "text": "Lock it in — end the turn and let the enemy act.", "advance": "turn_resolved"},
		{"targets": ["battle_log"], "text": "Everything that happens is logged here."},
		{"targets": ["protocol_bar"], "text": "You earned 1 Protocol. It builds +1 every turn, caps at 10. Watch what it does next."},
		# Phase 2 — turn 2: Protocol & Nudge
		{"targets": ["roll_button"], "text": "Roll again.", "advance": "rolled"},
		{"targets": ["hero_dice"], "text": "Pulse Tech's die landed just short of a stronger ability."},
		{"targets": ["protocol_value"], "text": "You have 1 Protocol. Time to spend it."},
		{"targets": ["nudge"], "text": "Nudge costs 1: +3 to a die. Use it to push that die over the line.", "advance": "nudged"},
		{"targets": ["enemy_cards"], "text": "It jumped into a stronger band — Plasma Lance. Now assign it.", "advance": "assigned"},
		{"targets": ["reroll", "nudge"], "text": "Reroll (2) and Set (3) cost more — they unlock as you bank Protocol."},
		{"targets": ["roll_button"], "text": "Clear them out — assign the rest and end the turn.", "advance": "won"},
		{"targets": [], "text": "That's the loop. The Help menu has the full encyclopedia whenever you need it.", "title": "DRILL COMPLETE", "advance": "tap_finish"},
	]


func _current() -> Dictionary:
	return _steps[_step] if _step >= 0 and _step < _steps.size() else {}


func _advance_mode() -> String:
	return str(_current().get("advance", "tap"))


# ── Event / tap gating ──────────────────────────────────────────────────────────
func _on_tutorial_event(event: StringName, payload: Dictionary) -> void:
	var mode: String = _advance_mode()
	if mode == "tap" or mode == "tap_finish":
		return
	if String(event) != mode:
		return
	# Optional payload predicate (e.g. phase == ready_to_end).
	if _current().has("phase") and str(payload.get("phase", "")) != str(_current()["phase"]):
		return
	_next()


func _on_dim_tapped(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		pressed = mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if not pressed:
		return
	var mode: String = _advance_mode()
	if mode == "tap":
		_next()
	elif mode == "tap_finish":
		_finish()


func _next() -> void:
	if _advance_mode() == "tap_finish":
		_finish()
		return
	_step += 1
	if _step >= _steps.size():
		_finish()
		return
	_show_step(_step)


func _finish() -> void:
	if _scene != null and _scene.has_signal("tutorial_event") and _scene.tutorial_event.is_connected(_on_tutorial_event):
		_scene.tutorial_event.disconnect(_on_tutorial_event)
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		gs.set("tutorial_mode", false)
	var sm: Node = get_node_or_null("/root/SceneManager")
	queue_free()
	if sm != null:
		sm.call("go_to_main_menu")


# ── Layout / spotlight ────────────────────────────────────────────────────────────
func _show_step(index: int) -> void:
	_step = index
	# Resolve next frame so freshly-built nodes (dice rows after a roll) have a real rect.
	call_deferred("_layout_step")


func _layout_step() -> void:
	var step: Dictionary = _current()
	if step.is_empty():
		return
	var hole: Rect2 = _targets_rect(step.get("targets", []))
	_apply_dim(hole)
	_apply_ring(hole)
	_apply_coach(step, hole)


func _targets_rect(keys: Array) -> Rect2:
	var rect: Rect2 = Rect2()
	var has_any := false
	for key in keys:
		var r: Rect2 = _target_rect(str(key))
		if r.size == Vector2.ZERO:
			continue
		rect = r if not has_any else rect.merge(r)
		has_any = true
	if not has_any:
		return Rect2()
	return rect.grow(PAD)


func _target_rect(key: String) -> Rect2:
	match key:
		"header":
			var h: Node = get_node_or_null("/root/PersistentHeader")
			var band: float = 144.0
			if h != null:
				var v: Variant = h.get("HEADER_HEIGHT")
				if v != null:
					band = float(v)
			return Rect2(0, 0, get_viewport().get_visible_rect().size.x, band)
		"roll_button":
			return _node_rect(_scene.get("roll_button"))
		"hero_cards":
			return _node_rect(_scene.get("hero_cards"))
		"enemy_cards":
			return _node_rect(_scene.get("enemy_cards")).merge(_node_rect(_scene.get("enemy_dice_row")))
		"enemy_readouts":
			return _node_rect(_scene.get("enemy_readouts")).merge(_node_rect(_scene.get("enemy_dice_row")))
		"hero_dice":
			return _node_rect(_scene.get("hero_dice_row")).merge(_node_rect(_scene.get("hero_readouts")))
		"protocol_bar":
			return _node_rect(_scene.get("protocol_bar")).merge(_node_rect(_scene.get("protocol_panel")))
		"protocol_value":
			return _node_rect(_scene.get("protocol_value_label"))
		"nudge":
			return _node_rect(_scene.get("_nudge_button"))
		"reroll":
			return _node_rect(_scene.get("protocol_spend_button"))
		"battle_log":
			return _node_rect(_scene.get("battle_log_panel"))
	return Rect2()


func _node_rect(node: Variant) -> Rect2:
	var control: Control = node as Control
	if control == null or not is_instance_valid(control) or not control.is_inside_tree() or not control.visible:
		return Rect2()
	var r: Rect2 = control.get_global_rect()
	if r.size.x < 2.0 or r.size.y < 2.0:
		return Rect2()
	return r


func _apply_dim(hole: Rect2) -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	if hole.size == Vector2.ZERO:
		# No spotlight — dim the whole screen.
		_set_rect(_dim_top, Rect2(0, 0, s.x, s.y))
		_set_rect(_dim_bottom, Rect2())
		_set_rect(_dim_left, Rect2())
		_set_rect(_dim_right, Rect2())
		return
	_set_rect(_dim_top, Rect2(0, 0, s.x, maxf(hole.position.y, 0)))
	_set_rect(_dim_bottom, Rect2(0, hole.end.y, s.x, maxf(s.y - hole.end.y, 0)))
	_set_rect(_dim_left, Rect2(0, hole.position.y, maxf(hole.position.x, 0), hole.size.y))
	_set_rect(_dim_right, Rect2(hole.end.x, hole.position.y, maxf(s.x - hole.end.x, 0), hole.size.y))


func _set_rect(rect_node: ColorRect, r: Rect2) -> void:
	if rect_node == null:
		return
	rect_node.visible = r.size.x > 0.5 and r.size.y > 0.5
	rect_node.position = r.position
	rect_node.size = r.size


func _apply_ring(hole: Rect2) -> void:
	if _ring == null:
		return
	if hole.size == Vector2.ZERO:
		_ring.visible = false
		return
	_ring.visible = true
	_ring.position = hole.position
	_ring.size = hole.size
	if _ring_tween != null and _ring_tween.is_valid():
		_ring_tween.kill()
	_ring.modulate.a = 1.0
	_ring_tween = create_tween().set_loops()
	_ring_tween.tween_property(_ring, "modulate:a", 0.35, 0.55).set_trans(Tween.TRANS_SINE)
	_ring_tween.tween_property(_ring, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)


func _apply_coach(step: Dictionary, hole: Rect2) -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	var title: String = str(step.get("title", ""))
	_coach_label.text = ("[ %s ]\n%s" % [title, str(step.get("text", ""))]) if title != "" else str(step.get("text", ""))
	var mode: String = _advance_mode()
	_hint_label.visible = (mode == "tap" or mode == "tap_finish")
	_hint_label.text = "tap to continue ▸"

	var width: float = s.x - SCREEN_MARGIN * 2.0
	_coach.custom_minimum_size = Vector2(width, 0)
	_coach.size = Vector2(width, 0)
	await get_tree().process_frame
	var ch: float = _coach.get_combined_minimum_size().y
	var y: float
	if hole.size == Vector2.ZERO:
		y = (s.y - ch) * 0.5
	elif hole.get_center().y < s.y * 0.5:
		y = minf(hole.end.y + 28.0, s.y - ch - SCREEN_MARGIN)  # hole in top half → coach below
	else:
		y = maxf(hole.position.y - ch - 28.0, SCREEN_MARGIN)    # hole in bottom half → coach above
	_coach.position = Vector2(SCREEN_MARGIN, y)
	_coach.size = Vector2(width, ch)


# ── Build the overlay UI ──────────────────────────────────────────────────────────
func _build_ui() -> void:
	layer = LAYER
	_dim_top = _make_dim()
	_dim_bottom = _make_dim()
	_dim_left = _make_dim()
	_dim_right = _make_dim()

	_ring = Panel.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_style := StyleBoxFlat.new()
	ring_style.bg_color = Color(0, 0, 0, 0)
	ring_style.set_border_width_all(6)
	ring_style.border_color = ACCENT
	ring_style.set_corner_radius_all(0)
	_ring.add_theme_stylebox_override("panel", ring_style)
	_ring.visible = false
	add_child(_ring)

	_coach = PanelContainer.new()
	_coach.mouse_filter = Control.MOUSE_FILTER_STOP
	_coach.gui_input.connect(_on_dim_tapped)
	var coach_style: StyleBoxFlat = PixelUI.make_hard_style(Color("0b1117"), ACCENT, 4)
	coach_style.set_content_margin_all(22.0)
	_coach.add_theme_stylebox_override("panel", coach_style)
	add_child(_coach)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_coach.add_child(col)

	_coach_label = Label.new()
	_coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_coach_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUI.style_label(_coach_label, COACH_FONT, PixelUI.TEXT_PRIMARY, 2)
	col.add_child(_coach_label)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUI.style_label(_hint_label, HINT_FONT, ACCENT, 1)
	col.add_child(_hint_label)

	# Persistent Skip — always available.
	var skip := Button.new()
	skip.text = "SKIP TUTORIAL"
	skip.custom_minimum_size = Vector2(360, 84)
	skip.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUI.style_button(skip, PixelUI.BG_PANEL_ALT, PixelUI.LINE_DIM, SKIP_FONT)
	skip.add_theme_color_override("font_color", PixelUI.TEXT_MUTED)
	skip.pressed.connect(_finish)
	var skip_wrap := Control.new()
	skip_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(skip_wrap)
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.offset_left = -380
	skip.offset_top = -104
	skip.offset_right = -20
	skip.offset_bottom = -20
	skip_wrap.add_child(skip)


func _make_dim() -> ColorRect:
	var rect := ColorRect.new()
	rect.color = DIM
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.gui_input.connect(_on_dim_tapped)
	rect.visible = false
	add_child(rect)
	return rect
