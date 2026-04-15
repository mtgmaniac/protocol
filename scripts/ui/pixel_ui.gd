class_name PixelUI
extends RefCounted

const BG_DARK := Color(0.030, 0.035, 0.050, 1.0)
const BG_PANEL := Color(0.050, 0.055, 0.078, 1.0)
const BG_PANEL_ALT := Color(0.075, 0.085, 0.120, 1.0)
const LINE_DIM := Color(0.18, 0.23, 0.34, 1.0)
const LINE_BRIGHT := Color(0.36, 0.55, 0.78, 1.0)
const TEXT_PRIMARY := Color(0.88, 0.91, 0.88, 1.0)
const TEXT_MUTED := Color(0.52, 0.60, 0.70, 1.0)
const HERO_ACCENT := Color(0.20, 0.66, 0.50, 1.0)
const ENEMY_ACCENT := Color(0.74, 0.28, 0.23, 1.0)
const GOLD_ACCENT := Color(0.82, 0.58, 0.24, 1.0)
const BLACK_EDGE := Color(0.005, 0.006, 0.010, 1.0)
const UI_FONT_PATH := "res://assets/fonts/m5x7.ttf"
const UI_FONT_SCALE := 1.35
const UI_FONT_MIN_SIZE := 20
const UI_FONT_STEPS := [20, 24, 28, 32, 36, 42, 48, 56, 64, 72]

static var _pixel_font: Font = null


static func make_panel_style(bg: Color = BG_PANEL, border: Color = LINE_DIM, border_width: int = 2, corner: int = 4) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = corner
	style.corner_radius_top_right = corner
	style.corner_radius_bottom_left = corner
	style.corner_radius_bottom_right = corner
	style.shadow_color = BLACK_EDGE
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	style.set_content_margin(SIDE_LEFT, 4.0)
	style.set_content_margin(SIDE_TOP, 4.0)
	style.set_content_margin(SIDE_RIGHT, 4.0)
	style.set_content_margin(SIDE_BOTTOM, 4.0)
	return style


static func get_pixel_font() -> Font:
	if _pixel_font == null:
		var font: FontFile = FontFile.new()
		var load_error: Error = font.load_dynamic_font(UI_FONT_PATH)
		if load_error != OK:
			var fallback_font: SystemFont = SystemFont.new()
			fallback_font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New", "monospace"])
			_pixel_font = fallback_font
			return _pixel_font
		_pixel_font = font
	return _pixel_font


static func apply_pixel_font(control: Control) -> void:
	control.add_theme_font_override("font", get_pixel_font())


static func scale_font_size(font_size: int) -> int:
	var scaled_size: int = maxi(UI_FONT_MIN_SIZE, int(round(float(font_size) * UI_FONT_SCALE)))
	for stepped_size in UI_FONT_STEPS:
		if scaled_size <= int(stepped_size):
			return int(stepped_size)
	return scaled_size


static func style_panel(panel: Control, bg: Color = BG_PANEL, border: Color = LINE_DIM, border_width: int = 2, corner: int = 4) -> void:
	panel.add_theme_stylebox_override("panel", make_panel_style(bg, border, border_width, corner))


static func style_button(button: Button, fill: Color = BG_PANEL_ALT, border: Color = LINE_BRIGHT, font_size: int = 20) -> void:
	apply_pixel_font(button)
	button.add_theme_font_size_override("font_size", scale_font_size(font_size))
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_focus_color", TEXT_PRIMARY)
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.98))
	button.add_theme_stylebox_override("normal", make_panel_style(fill, border.darkened(0.10), 4, 0))
	button.add_theme_stylebox_override("hover", make_panel_style(fill, border.lightened(0.05), 4, 0))
	button.add_theme_stylebox_override("pressed", make_panel_style(fill.darkened(0.18), border.darkened(0.12), 4, 0))
	button.add_theme_stylebox_override("disabled", make_panel_style(fill.darkened(0.25), border.darkened(0.45), 4, 0))


static func style_option_button(button: OptionButton, fill: Color = BG_PANEL_ALT, border: Color = LINE_DIM, font_size: int = 18) -> void:
	apply_pixel_font(button)
	button.add_theme_font_size_override("font_size", scale_font_size(font_size))
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.98))
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_stylebox_override("normal", make_panel_style(fill, border.darkened(0.10), 4, 0))
	button.add_theme_stylebox_override("hover", make_panel_style(fill, border.lightened(0.05), 4, 0))
	button.add_theme_stylebox_override("pressed", make_panel_style(fill.darkened(0.12), border.darkened(0.10), 4, 0))


static func style_label(label: Label, font_size: int, color: Color = TEXT_PRIMARY, outline_size: int = 2) -> void:
	apply_pixel_font(label)
	label.add_theme_font_size_override("font_size", scale_font_size(font_size))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.98))
	label.add_theme_constant_override("outline_size", outline_size)


static func style_progress_bar(bar: ProgressBar, fill: Color, bg: Color = Color(0.015, 0.020, 0.035, 1.0), border: Color = LINE_DIM) -> void:
	var bg_style: StyleBoxFlat = make_panel_style(bg, BLACK_EDGE, 2, 0)
	bg_style.shadow_size = 0
	bg_style.set_content_margin(SIDE_LEFT, 0.0)
	bg_style.set_content_margin(SIDE_TOP, 0.0)
	bg_style.set_content_margin(SIDE_RIGHT, 0.0)
	bg_style.set_content_margin(SIDE_BOTTOM, 0.0)
	var fill_style: StyleBoxFlat = make_panel_style(fill, fill, 0, 0)
	fill_style.shadow_size = 0
	fill_style.set_content_margin(SIDE_LEFT, 0.0)
	fill_style.set_content_margin(SIDE_TOP, 0.0)
	fill_style.set_content_margin(SIDE_RIGHT, 0.0)
	fill_style.set_content_margin(SIDE_BOTTOM, 0.0)
	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)
