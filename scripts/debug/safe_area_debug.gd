extends CanvasLayer
## TEMPORARY diagnostic — Android Build #1. DELETED IN BUILD #2.
##
## Two tap-toggled pages (one build, both views — a tap anywhere that no game
## control consumed flips between them):
##
## PAGE 0 — display info. Reports the device's real numbers (window size,
## content scale factor, stretch config, safe area, cutouts, computed insets)
## as on-screen text AND to stdout (recoverable via `adb logcat` if the overlay
## itself renders illegibly). The label deliberately uses m5x7 at size 36 — the
## same as PixelUI.FONT_INFO_MIN — so if the font is melting on device it melts
## inside the diagnostic, where the numbers explain why. Also outlines the
## reported safe-area rect (cyan) and every cutout rect (red) in design space —
## visual confirmation of whether get_display_safe_area() actually reports the
## punch-hole in our fullscreen mode, the one thing Phase 0 could not determine
## from source.
##
## PAGE 1 — font ladder. m5x7 is a 16px-native pixel font, so it should only be
## crisp at integer multiples of 16; the working theory is that every
## non-multiple size in the project produces broken glyph strokes and desktop's
## clean 0.5× scale has been hiding it. One sample line per in-use size, plain
## white on the dark panel bg — no modulation, no outline, no shadow, nothing
## that could mask a rendering artifact. Each line is prefixed with its size
## number at a fixed 32 (a 16-multiple, so the prefix itself is always legible).
##
## Gating: the `overload/debug/safe_area_overlay` project setting is the kill
## switch (flip false to disable without removing the autoload). Even when on,
## the overlay only arms on mobile builds or with SAFE_AREA_DEBUG=1 in the
## environment — desktop runs and the screenshot harness never see it.

const FLAG_SETTING := "overload/debug/safe_area_overlay"
const OUTLINE_W := 2.0
const LABEL_FONT_SIZE := 36  # = PixelUI.FONT_INFO_MIN, deliberately (see above)

# Every m5x7 size in use across the project (audit 2026-07-13), ascending.
# 16-multiples (16/32/48/64) are the expected-crisp control rows.
const LADDER_SIZES := [16, 20, 22, 24, 30, 32, 34, 36, 37, 40, 42, 48, 64]
const LADDER_SAMPLE := "ABCDEfgh 0123 WWmmii"
const LADDER_PREFIX_FONT := 32   # fixed 16-multiple so the prefix stays legible
const LADDER_PREFIX_W := 110.0   # fixed column so sample starts align

@onready var _label: Label = $Label

var _armed := false
var _page := 0
var _outline: OutlineLayer = null
var _ladder_root: Control = null


func _ready() -> void:
	layer = 100
	var flag_on: bool = bool(ProjectSettings.get_setting(FLAG_SETTING, true))
	_armed = flag_on and (OS.has_feature("mobile") or OS.has_environment("SAFE_AREA_DEBUG"))
	if DisplayServer.get_name() == "headless" or not _armed:
		visible = false
		_armed = false
		return

	PixelUI.apply_pixel_font(_label)
	_label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
	_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_label.add_theme_constant_override("outline_size", 2)

	_outline = OutlineLayer.new()
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_outline)

	_ladder_root = _build_ladder_page()
	add_child(_ladder_root)

	get_tree().root.size_changed.connect(_refresh)
	var header: Node = get_node_or_null("/root/PersistentHeader")
	if header != null and header.has_signal("safe_area_changed"):
		header.connect("safe_area_changed", _refresh)
	# Desktop-verification hook: start on the ladder page so the screenshot
	# harness can photograph it without simulating a tap.
	_show_page(1 if OS.has_environment("SAFE_AREA_DEBUG_LADDER") else 0)
	_refresh()


# Page flip: any tap/click NO game control consumed. Deliberately unhandled
# input, not a full-screen catcher — a catcher would steal every tap and make
# the build unplayable; this way game buttons keep working and any dead-space
# tap flips the diagnostic.
func _unhandled_input(event: InputEvent) -> void:
	if not _armed:
		return
	var pressed := false
	if event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	if pressed:
		_show_page(1 - _page)


func _show_page(page: int) -> void:
	_page = page
	_label.visible = page == 0
	if _outline != null:
		_outline.visible = page == 0  # keep the ladder free of overdrawn rects
	if _ladder_root != null:
		_ladder_root.visible = page == 1


# ── Page 1: the font ladder ─────────────────────────────────────────────────
# Built once; the outer margin re-consumes the safe insets on every _refresh so
# the ladder stays clear of the cutout and the gesture bar.
func _build_ladder_page() -> Control:
	var margin := MarginContainer.new()
	margin.name = "LadderPage"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)

	# Dark panel behind the samples — plain fill, no border (a border stroke is
	# itself a rendering-artifact candidate; keep the field clean).
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # vertically centered
	var style := StyleBoxFlat.new()
	style.bg_color = PixelUI.DT_PANEL_BG
	style.set_content_margin_all(24.0)
	panel.add_theme_stylebox_override("panel", style)
	margin.add_child(panel)

	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 10)
	panel.add_child(rows)

	for size_variant in LADDER_SIZES:
		var px: int = int(size_variant)
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 16)
		rows.add_child(row)

		var prefix := _bare_label(str(px), LADDER_PREFIX_FONT)
		prefix.custom_minimum_size = Vector2(LADDER_PREFIX_W, 0)
		row.add_child(prefix)
		row.add_child(_bare_label(LADDER_SAMPLE, px))
	return margin


# Plain white m5x7 at exactly `px` — outline explicitly zeroed and modulate
# untouched so the project theme can't sneak any masking treatment in.
func _bare_label(text: String, px: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUI.apply_pixel_font(label)
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	label.add_theme_constant_override("outline_size", 0)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


func _refresh() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	# Both pages stay clear of the live insets.
	if _ladder_root != null:
		_ladder_root.add_theme_constant_override("margin_top", PixelUI.safe_top)
		_ladder_root.add_theme_constant_override("margin_bottom", PixelUI.safe_bottom)
	var inv: Transform2D = vp.get_screen_transform().affine_inverse()
	var scale_factor: float = (1.0 / inv.x.x) if inv.x.x != 0.0 else 0.0
	# Font identity (Build #2, Task 1a): get_font_name() returns the literal
	# family string — "m5x7" or "Roboto". Not inference; the answer. This is the
	# same Font object the label renders with (theme lookup honors the override).
	var f: Font = _label.get_theme_font("font")
	var lines := "\n".join([
		"win        %s" % DisplayServer.window_get_size(),
		"scale      %.5f" % scale_factor,
		"scale_mode %s" % ProjectSettings.get_setting(
			"display/window/stretch/scale_mode", "<unset>"),
		"stretch    %s / %s" % [
			ProjectSettings.get_setting("display/window/stretch/mode", "?"),
			ProjectSettings.get_setting("display/window/stretch/aspect", "?")],
		"safe_area  %s" % DisplayServer.get_display_safe_area(),
		"cutouts    %s" % str(DisplayServer.get_display_cutouts()),
		"insets     T%d R%d B%d L%d" % [PixelUI.safe_top, PixelUI.safe_right,
			PixelUI.safe_bottom, PixelUI.safe_left],
		"font_name  %s" % (f.get_font_name() if f != null else "NULL"),
		"font_path  %s" % (f.resource_path if f != null else "-"),
		"ttf_exists %s" % ResourceLoader.exists("res://assets/fonts/m5x7.ttf"),
	])
	_label.text = lines
	# stdout copy → adb logcat, in case the overlay text itself is the bug.
	print("[SAFE_AREA_DEBUG]\n%s" % lines)
	if _outline != null:
		_outline.queue_redraw()


# Draws the OS-reported rects converted physical→design through the SAME
# inverse-screen-transform path the inset math uses, so a wrong conversion is
# visible as a misplaced outline.
class OutlineLayer extends Control:
	func _draw() -> void:
		var vp := get_viewport()
		if vp == null:
			return
		var inv: Transform2D = vp.get_screen_transform().affine_inverse()
		var win_pos := Vector2(DisplayServer.window_get_position())

		var sa: Rect2i = DisplayServer.get_display_safe_area()
		if sa.size.x > 0 and sa.size.y > 0:
			var p0: Vector2 = inv * (Vector2(sa.position) - win_pos)
			var p1: Vector2 = inv * (Vector2(sa.position + sa.size) - win_pos)
			draw_rect(Rect2(p0, p1 - p0), Color(0.20, 0.90, 0.95, 1.0), false, OUTLINE_W)

		for c: Rect2 in DisplayServer.get_display_cutouts():
			var c0: Vector2 = inv * (c.position - win_pos)
			var c1: Vector2 = inv * (c.end - win_pos)
			draw_rect(Rect2(c0, c1 - c0), Color(0.95, 0.20, 0.18, 1.0), false, OUTLINE_W)
