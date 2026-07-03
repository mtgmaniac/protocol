# Drives the rigged onboarding encounter: dims the screen, cuts a spotlight hole around one
# real UI element at a time, attaches a coachmark, and gates each beat on the player's actual
# action (via battle_scene's tutorial_event signal) or a tap. A persistent Skip ends it. Built
# in code over its own high CanvasLayer; the spotlight hole leaves the highlighted element
# fully interactive so gated steps work on the real control.
class_name TutorialController
extends CanvasLayer

# Above the battle scene + header (8) but BELOW InspectPopup (130) / HelpMenu (135), so a
# long-press inspect shows above the coachmarks instead of being dimmed under them.
const LAYER := 110
const DIM := Color(0.01, 0.015, 0.02, 0.82)
const PAD := 14.0
const FULLSCREEN_INSET := 12.0  # "highlight the whole screen" frame: ring this far in from the edges
const DIE_HALF_PX := 84.0       # half-size of a rendered die, for spotlighting a single unit's die
const COACH_FONT := 32
const HINT_FONT := 24
const SKIP_FONT := 26
const TITLE_FONT := 38
const SCREEN_MARGIN := 40.0
const ACCENT := Color("6fe0ef")  # PixelUI.DT_CYAN_BRIGHT

var _scene: Node = null
var _step: int = 0
var _steps: Array = []

var _dim_canvas: _DimCanvas = null  # one custom-drawn layer: dims everything but the hole(s) + rings
var _tap_catcher: Control = null    # full-screen invisible tap target on tap steps (advance anywhere)
var _coach: PanelContainer = null
var _coach_label: Label = null
var _hint_label: Label = null
var _ring_tween: Tween = null


# One full-screen visual layer that dims everything EXCEPT a set of hole rects, and draws a pulsing
# accent border around each hole. Supports any number of holes (e.g. Nudge + Pulse as two separate
# zones). Purely visual — MOUSE_FILTER_IGNORE — so input is handled by the catcher / real controls.
class _DimCanvas extends Control:
	var holes: Array = []          # Array[Rect2] in this control's local (== screen) space
	var dim_color: Color = Color(0.01, 0.015, 0.02, 0.82)
	var ring_color: Color = Color("6fe0ef")
	var ring_thickness: float = 6.0
	var ring_alpha: float = 1.0: set = _set_ring_alpha

	func _set_ring_alpha(v: float) -> void:
		ring_alpha = v
		queue_redraw()

	func set_holes(new_holes: Array) -> void:
		holes = new_holes
		queue_redraw()

	func _draw() -> void:
		var s: Vector2 = size
		if holes.is_empty():
			draw_rect(Rect2(Vector2.ZERO, s), dim_color)
			return
		# Tile the dimmed region (screen minus the holes) with rectangles, band by band: split on
		# every hole top/bottom edge, then within each horizontal band fill the x-gaps left by the
		# holes that span it. Exact for any number of (possibly disjoint) holes.
		var ys: Array = [0.0, s.y]
		for h in holes:
			ys.append(clampf(h.position.y, 0.0, s.y))
			ys.append(clampf(h.end.y, 0.0, s.y))
		ys.sort()
		for i in range(ys.size() - 1):
			var y0: float = ys[i]
			var y1: float = ys[i + 1]
			if y1 - y0 <= 0.5:
				continue
			var mid: float = (y0 + y1) * 0.5
			var spans: Array = []
			for h in holes:
				if h.position.y <= mid and h.end.y >= mid:
					spans.append([maxf(h.position.x, 0.0), minf(h.end.x, s.x)])
			spans.sort_custom(func(a, b): return a[0] < b[0])
			var x: float = 0.0
			for span in spans:
				if span[0] > x:
					draw_rect(Rect2(x, y0, span[0] - x, y1 - y0), dim_color)
				x = maxf(x, span[1])
			if x < s.x:
				draw_rect(Rect2(x, y0, s.x - x, y1 - y0), dim_color)
		# Pulsing accent border around each hole.
		var col: Color = ring_color
		col.a *= ring_alpha
		var t: float = ring_thickness
		for h in holes:
			draw_rect(Rect2(h.position, Vector2(h.size.x, t)), col)
			draw_rect(Rect2(Vector2(h.position.x, h.end.y - t), Vector2(h.size.x, t)), col)
			draw_rect(Rect2(h.position, Vector2(t, h.size.y)), col)
			draw_rect(Rect2(Vector2(h.end.x - t, h.position.y), Vector2(t, h.size.y)), col)


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
		# Phase 0 — orientation (tap). Inspect is taught later on the player's own unit, so no
		# separate enemy long-press beat here.
		{"targets": [], "title": "WELCOME", "text": "Welcome to Overload Protocol. I'll show you around the screen, then walk you through your first two turns."},
		{"targets": ["header"], "text": "This bar stays with you all run — squad progress and the Help menu live here. Help holds the full encyclopedia."},
		{"targets": ["hero_cards"], "text": "Your three specialists. Each has its own HP and abilities."},
		{"targets": ["enemy_cards"], "text": "Your target."},
		# Phase 1 — turn 1: the core loop
		{"targets": ["roll_button"], "text": "Tap Roll to set your dice.", "advance": "roll_pressed"},
		{"targets": ["center"], "text": "Each die slots into a band. Higher rolls fire stronger abilities."},
		{"targets": ["hero_cards"], "text": "Every unit's bands differ — long-press a card to see its ranges. Give it a try.", "advance": "inspected"},
		# Pick a die first (heroes + pips + dice highlighted); once targeting starts we spotlight the
		# enemy to tap, then open up the whole screen to assign the rest.
		{"targets": ["heroes"], "text": "Tap a die (or its hero card) to pick who fires.", "advance": "targeting_started"},
		{"targets": ["enemy_cards"], "text": "Now tap the enemy to fire it.", "advance": "assigned"},
		{"targets": [], "fullscreen": true, "text": "Assign your remaining dice.", "advance": "phase", "phase": "ready_to_end"},
		{"targets": ["enemy_readouts"], "text": "Here's what the enemy will do this turn. Control matters."},
		{"targets": ["roll_button"], "text": "Lock it in — ending the turn fires every die you assigned, all at once, then the enemy takes its action.", "advance": "turn_resolved"},
		{"targets": ["protocol_bar"], "text": "You earned 1 Protocol. It builds +1 every turn, caps at 10. Watch what it does next."},
		# Phase 2 — turn 2: Protocol & Nudge. "Roll again" waits for the dice to settle (advance
		# "rolled") before moving on.
		{"targets": ["roll_button"], "text": "Roll again.", "advance": "rolled"},
		{"targets": ["protocol_value"], "text": "You have 1 Protocol. Time to spend it."},
		{"targets": ["nudge", "pulse"], "separate": true, "text": "Nudge costs 1 Protocol — tap it, then Pulse Tech's die to add +3 and push it over the line.", "advance": "nudged"},
		{"targets": ["pulse"], "text": "It jumped into a stronger band — Plasma Lance."},
		{"targets": ["reroll", "set"], "separate": true, "text": "Reroll (2) and Set (3) cost more — they unlock as you bank Protocol."},
		{"targets": [], "fullscreen": true, "text": "Tap Pulse Tech's die, then the enemy to fire it.", "advance": "assigned"},
		{"targets": [], "fullscreen": true, "text": "Clear them out — assign the rest and end the turn.", "advance": "won"},
		{"targets": [], "text": "That's the loop. The Help menu has the full encyclopedia whenever you need it.", "title": "DRILL COMPLETE", "advance": "tap_finish"},
	]


func _current() -> Dictionary:
	return _steps[_step] if _step >= 0 and _step < _steps.size() else {}


func _advance_mode() -> String:
	return str(_current().get("advance", "tap"))


# ── Event / tap gating ──────────────────────────────────────────────────────────
func _on_tutorial_event(event: StringName, payload: Dictionary) -> void:
	var mode: String = _advance_mode()
	# A press that starts an animation (roll, end turn) but isn't our gate: reveal the whole board
	# (no dim, just the edge frame) so the spotlight doesn't linger on the now-gone/changing
	# control and the player can watch the roll / turn resolution play out.
	if (event == &"roll_pressed" or event == &"end_turn_pressed") and String(event) != mode:
		_reveal_whole_screen()
	if mode == "tap" or mode == "tap_finish":
		return
	if String(event) != mode:
		return
	# Optional payload predicate (e.g. phase == ready_to_end).
	if _current().has("phase") and str(payload.get("phase", "")) != str(_current()["phase"]):
		return
	_next()


# Drop the dim to the whole-screen frame (no dimming, just the edge border), keeping the coachmark —
# used while a roll / turn resolution animates so the player can watch the board play out.
func _reveal_whole_screen() -> void:
	if _dim_canvas != null:
		_dim_canvas.set_holes([_fullscreen_hole()])


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
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager != null:
		save_manager.call("mark_tutorial_done")
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
	_apply_interactivity()
	var holes: Array = _compute_holes(step)
	if _dim_canvas != null:
		_dim_canvas.set_holes(holes)
	_apply_coach(step, _bounds_of(holes))


# Holes to spotlight this step, in screen space:
#   • "fullscreen" → one frame just inside the edges (whole board visible/interactive).
#   • "separate"   → each target key is its OWN hole (e.g. Nudge + Pulse as two distinct zones).
#   • otherwise    → all target keys merged into a single hole.
func _compute_holes(step: Dictionary) -> Array:
	if bool(step.get("fullscreen", false)):
		return [_fullscreen_hole()]
	var keys: Array = step.get("targets", [])
	if bool(step.get("separate", false)):
		var holes: Array = []
		for key in keys:
			var r: Rect2 = _target_rect(str(key))
			if r.size != Vector2.ZERO:
				holes.append(r.grow(PAD))
		return holes
	var merged: Rect2 = _targets_rect(keys)
	return [merged] if merged.size != Vector2.ZERO else []


func _fullscreen_hole() -> Rect2:
	var s: Vector2 = get_viewport().get_visible_rect().size
	return Rect2(FULLSCREEN_INSET, FULLSCREEN_INSET, s.x - FULLSCREEN_INSET * 2.0, s.y - FULLSCREEN_INSET * 2.0)


func _bounds_of(holes: Array) -> Rect2:
	var bounds: Rect2 = Rect2()
	var has_any := false
	for h in holes:
		bounds = h if not has_any else bounds.merge(h)
		has_any = true
	return bounds if has_any else Rect2()


# Tap-advance steps catch input on a full-screen catcher (tap anywhere — including the spotlit
# element — to continue). Gated steps must let the player drive the real controls (roll, select a
# hero die, target, nudge), so the catcher + coachmark pass input straight through — fixes both
# "the overlay won't let me click the dice/cards" and "I can only advance by tapping the box".
# (The dim canvas is always IGNORE — purely visual.)
func _apply_interactivity() -> void:
	var mode: String = _advance_mode()
	var gated: bool = not (mode == "tap" or mode == "tap_finish")
	var mf: int = Control.MOUSE_FILTER_IGNORE if gated else Control.MOUSE_FILTER_STOP
	if _coach != null:
		_coach.mouse_filter = mf
	if _tap_catcher != null:
		_tap_catcher.mouse_filter = mf


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
		"hero_area":
			# The hero cards + their dice/readout row — where you tap a die to fire it.
			return _merge_nonempty(_node_rect(_scene.get("hero_cards")), _node_rect(_scene.get("hero_dice_row")))
		"heroes":
			# All three units: cards + ability pips (readouts) + their rolled dice (the dice render
			# up in the tray, not next to the cards — see _hero_unit_rect).
			var heroes_rect: Rect2 = Rect2()
			var views: Variant = _scene.get("hero_card_views")
			if views is Array:
				for v in views:
					var st: Dictionary = (v as Dictionary).get("state", {})
					var u: Object = st.get("unit", null) as Object
					if u != null:
						heroes_rect = _merge_nonempty(heroes_rect, _hero_unit_rect(str(u.id)))
			return heroes_rect
		"center":
			# The whole dice tray — the actual combat-zone rect the 3D dice roll inside, not the
			# thin layout containers (which sit empty beside the cards).
			return _dice_tray_rect()
		"pulse":
			# Just the Pulse Tech unit: its card, its ability pips (readout) and its die.
			return _hero_unit_rect("pulse")
		"enemy_cards":
			return _merge_nonempty(_node_rect(_scene.get("enemy_cards")), _node_rect(_scene.get("enemy_dice_row")))
		"enemy_readouts":
			return _merge_nonempty(_node_rect(_scene.get("enemy_readouts")), _node_rect(_scene.get("enemy_dice_row")))
		"protocol_bar":
			return _merge_nonempty(_node_rect(_scene.get("protocol_bar")), _node_rect(_scene.get("protocol_panel")))
		"protocol_value":
			# The numeric label is hidden since the footer redesign (the 10 bar
			# segments convey the count) — spotlight the bar itself, and merge the
			# label back in automatically if it ever returns.
			return _merge_nonempty(_node_rect(_scene.get("protocol_value_label")), _target_rect("protocol_bar"))
		"nudge":
			return _node_rect(_scene.get("_nudge_button"))
		"set":
			return _node_rect(_scene.get("_set_button"))
		"reroll":
			return _node_rect(_scene.get("protocol_spend_button"))
		"battle_log":
			return _node_rect(_scene.get("battle_log_panel"))
	return Rect2()


# Spotlight one hero by unit id: their card + ability-pip readout + their rolled die. The die isn't
# next to the card — it's rendered up in the tray — so we pull its real position from the layout.
func _hero_unit_rect(unit_id: String) -> Rect2:
	var views: Variant = _scene.get("hero_card_views")
	if not (views is Array):
		return Rect2()
	for view_variant in views:
		var view: Dictionary = view_variant
		var state: Dictionary = view.get("state", {})
		var unit: Object = state.get("unit", null) as Object
		if unit == null or str(unit.id) != unit_id:
			continue
		var rect: Rect2 = _node_rect(view.get("card", null))
		rect = _merge_nonempty(rect, _node_rect(view.get("readout", null)))
		rect = _merge_nonempty(rect, _hero_die_rect(str(state.get("id", ""))))
		return rect
	return Rect2()


func _layout_node() -> Object:
	return _scene.get("_layout")


# The dice tray = the combat-zone rect the dice physically roll inside (authoritative geometry).
func _dice_tray_rect() -> Rect2:
	var layout: Object = _layout_node()
	if layout == null:
		return Rect2()
	var r: Rect2 = layout.get_combat_zone_rect()
	return r if r.size.x > 2.0 and r.size.y > 2.0 else Rect2()


# Global rect of the rendered die for one hero state, around its tray anchor point.
func _hero_die_rect(state_id: String) -> Rect2:
	var layout: Object = _layout_node()
	if layout == null or state_id == "":
		return Rect2()
	var cz: Rect2 = layout.get_combat_zone_rect()
	if cz.size.x <= 2.0 or cz.size.y <= 2.0:
		return Rect2()
	var pt: Vector2 = layout.get_dice_anchor_point("hero", state_id)
	if pt == Vector2.INF:
		return Rect2()
	var g: Vector2 = pt + cz.position
	return Rect2(g - Vector2(DIE_HALF_PX, DIE_HALF_PX), Vector2(DIE_HALF_PX * 2.0, DIE_HALF_PX * 2.0))


func _merge_nonempty(a: Rect2, b: Rect2) -> Rect2:
	if a.size == Vector2.ZERO:
		return b
	if b.size == Vector2.ZERO:
		return a
	return a.merge(b)


func _node_rect(node: Variant) -> Rect2:
	var control: Control = node as Control
	if control == null or not is_instance_valid(control) or not control.is_inside_tree() or not control.visible:
		return Rect2()
	var r: Rect2 = control.get_global_rect()
	if r.size.x < 2.0 or r.size.y < 2.0:
		return Rect2()
	return r


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
	if bool(step.get("fullscreen", false)):
		# Whole-screen step: pin the coach to the bottom so it never covers the centre
		# Roll/End-Turn button (and leaves the enemy row visible up top for assign steps).
		y = s.y - ch - SCREEN_MARGIN
	elif hole.size == Vector2.ZERO:
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
	_dim_canvas = _DimCanvas.new()
	_dim_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim_canvas.dim_color = DIM
	_dim_canvas.ring_color = ACCENT
	_dim_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim_canvas)
	# Looping ring pulse — drives ring_alpha on the canvas (its setter triggers a redraw).
	_ring_tween = create_tween().set_loops()
	_ring_tween.tween_property(_dim_canvas, "ring_alpha", 0.35, 0.55).set_trans(Tween.TRANS_SINE)
	_ring_tween.tween_property(_dim_canvas, "ring_alpha", 1.0, 0.55).set_trans(Tween.TRANS_SINE)

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

	# Full-screen invisible tap target, above the spotlight but below Skip. On tap steps it makes
	# "tap anywhere to continue" work even over the bright spotlight hole; on gated steps it's set
	# to IGNORE so the real controls underneath stay live.
	_tap_catcher = Control.new()
	_tap_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tap_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tap_catcher.gui_input.connect(_on_dim_tapped)
	add_child(_tap_catcher)

	# Persistent Skip — always available. Sits at the very top-left, over the FACILITY header label.
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
	# Vertically centred within the header band, pinned to the left over the FACILITY label.
	var header_band: float = _target_rect("header").size.y
	var skip_h: float = 84.0
	var skip_top: float = maxf((header_band - skip_h) * 0.5, 12.0)
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	skip.offset_left = 20
	skip.offset_top = skip_top
	skip.offset_right = 380
	skip.offset_bottom = skip_top + skip_h
	skip_wrap.add_child(skip)
