# The shared spotlight component (Phase 1 of the keyword-primer system):
# dims everything except a set of hole rects, draws a pulsing accent ring
# around each hole, and shows a coachmark panel anchored near the holes.
# Extracted from TutorialController so the tutorial and the keyword primers
# share ONE visual machine; this layer is purely visual + tap reporting —
# step logic, gating, and target resolution stay with the caller.
#
# API:
#   spotlight(target_rects, text, anchor, opts) — show holes + coachmark.
#       opts: "title": String — [ TITLE ] line above the text
#             "hint": String — right-aligned hint line ("" hides it)
#             "interactive": bool — true: coach + full-screen catcher consume
#               taps and emit `tapped` (tap anywhere to continue); false: both
#               IGNORE so the real controls underneath stay live (gated steps).
#   set_holes(holes) — retarget the dim/ring without touching the coachmark.
#   fullscreen_hole() — the "whole board visible" frame rect.
#   dismiss() — hide everything (reusable; spotlight() shows it again).
#   add_overlay_control(c) — persistent extras on this layer (tutorial Skip).
class_name SpotlightLayer
extends CanvasLayer

signal tapped

enum CoachAnchor { AUTO, BOTTOM, CENTER }

const DIM := Color(0.01, 0.015, 0.02, 0.82)
const ACCENT := Color("6fe0ef")  # PixelUI.DT_CYAN_BRIGHT
const COACH_FONT := 32
const HINT_FONT := 36  # Kev 2026-07-10: "tap to continue" was too small at 24
const SCREEN_MARGIN := 40.0
const FULLSCREEN_INSET := 12.0  # "highlight the whole screen" frame inset

var _dim_canvas: _DimCanvas = null
var _tap_catcher: Control = null
var _coach: PanelContainer = null
var _coach_label: Label = null
var _coach_glyph: TextureRect = null
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


func _init(layer_index: int = 110) -> void:
	layer = layer_index


func _ready() -> void:
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
	_coach.gui_input.connect(_on_tap_input)
	var coach_style: StyleBoxFlat = PixelUI.make_hard_style(Color("0b1117"), ACCENT, 4)
	coach_style.set_content_margin_all(22.0)
	_coach.add_theme_stylebox_override("panel", coach_style)
	add_child(_coach)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_coach.add_child(col)

	# Body row: optional leading glyph (the ACTUAL icon a primer teaches —
	# opts["glyph"], Kev 2026-07-12) + the text. The glyph is hidden when no
	# texture is passed, so callers that never set it (the tutorial) render
	# pixel-identically to the pre-glyph layout.
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	col.add_child(body)

	_coach_glyph = TextureRect.new()
	_coach_glyph.visible = false
	_coach_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coach_glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_coach_glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_coach_glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_coach_glyph.custom_minimum_size = Vector2(56, 56)
	_coach_glyph.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(_coach_glyph)

	_coach_label = Label.new()
	_coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_coach_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coach_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelUI.style_label(_coach_label, COACH_FONT, PixelUI.TEXT_PRIMARY, 2)
	body.add_child(_coach_label)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUI.style_label(_hint_label, HINT_FONT, ACCENT, 1)
	col.add_child(_hint_label)

	# Full-screen invisible tap target, above the spotlight. When interactive it
	# makes "tap anywhere to continue" work even over the bright spotlight hole;
	# otherwise it's IGNORE so the real controls underneath stay live.
	_tap_catcher = Control.new()
	_tap_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tap_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tap_catcher.gui_input.connect(_on_tap_input)
	add_child(_tap_catcher)


# ── Public API ────────────────────────────────────────────────────────────────

func spotlight(target_rects: Array, text: String, anchor: CoachAnchor = CoachAnchor.AUTO, opts: Dictionary = {}) -> void:
	visible = true
	_dim_canvas.set_holes(target_rects)
	set_interactive(bool(opts.get("interactive", true)))
	var title: String = str(opts.get("title", ""))
	_coach_label.text = ("[ %s ]\n%s" % [title, text]) if title != "" else text
	var glyph: Texture2D = opts.get("glyph", null) as Texture2D
	_coach_glyph.texture = glyph
	_coach_glyph.visible = glyph != null
	var hint: String = str(opts.get("hint", ""))
	_hint_label.visible = hint != ""
	_hint_label.text = hint
	_coach.visible = true
	await _place_coach(_bounds_of(target_rects), anchor)


func set_holes(holes: Array) -> void:
	if _dim_canvas != null:
		_dim_canvas.set_holes(holes)


func fullscreen_hole() -> Rect2:
	var s: Vector2 = get_viewport().get_visible_rect().size
	return Rect2(FULLSCREEN_INSET, FULLSCREEN_INSET, s.x - FULLSCREEN_INSET * 2.0, s.y - FULLSCREEN_INSET * 2.0)


func dismiss() -> void:
	visible = false
	if _dim_canvas != null:
		_dim_canvas.set_holes([])


# Interactive: the coach + catcher consume taps and emit `tapped`. Not
# interactive: both pass input through so the spotlit real controls stay live.
func set_interactive(interactive: bool) -> void:
	var mf: int = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	if _coach != null:
		_coach.mouse_filter = mf
	if _tap_catcher != null:
		_tap_catcher.mouse_filter = mf


# Persistent extras that live on this layer (e.g. the tutorial's Skip button).
func add_overlay_control(control: Control) -> void:
	add_child(control)


# ── Internals ─────────────────────────────────────────────────────────────────

func _on_tap_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		pressed = mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed:
		tapped.emit()


func _bounds_of(holes: Array) -> Rect2:
	var bounds: Rect2 = Rect2()
	var has_any := false
	for h in holes:
		bounds = h if not has_any else bounds.merge(h)
		has_any = true
	return bounds if has_any else Rect2()


func _place_coach(hole: Rect2, anchor: CoachAnchor) -> void:
	var s: Vector2 = get_viewport().get_visible_rect().size
	var width: float = s.x - SCREEN_MARGIN * 2.0
	_coach.custom_minimum_size = Vector2(width, 0)
	_coach.size = Vector2(width, 0)
	await get_tree().process_frame
	var ch: float = _coach.get_combined_minimum_size().y
	var y: float
	if anchor == CoachAnchor.BOTTOM:
		# Pinned to the bottom so it never covers the centre action button.
		y = s.y - ch - SCREEN_MARGIN
	elif anchor == CoachAnchor.CENTER or hole.size == Vector2.ZERO:
		# Upper-middle, not dead center (Kev 2026-07-10): the End Turn button
		# lives mid-screen and a centered coach was blocking it.
		y = s.y * 0.34 - ch * 0.5
	elif hole.get_center().y < s.y * 0.5:
		y = minf(hole.end.y + 28.0, s.y - ch - SCREEN_MARGIN)  # hole in top half → coach below
	else:
		y = maxf(hole.position.y - ch - 28.0, SCREEN_MARGIN)    # hole in bottom half → coach above
	_coach.position = Vector2(SCREEN_MARGIN, y)
	_coach.size = Vector2(width, ch)
