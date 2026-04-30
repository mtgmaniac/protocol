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
const COLOR_DAMAGE := Color(0.96, 0.22, 0.18, 1.0)
const COLOR_HEAL := Color(0.28, 0.90, 0.46, 1.0)
const COLOR_SHIELD := Color(0.34, 0.66, 1.0, 1.0)
const COLOR_DEBUFF := Color(0.72, 0.34, 0.95, 1.0)
const COLOR_ROLL := Color(0.96, 0.76, 0.24, 1.0)
const UI_FONT_PATH := "res://assets/fonts/m5x7.ttf"
const UI_FONT_SCALE := 1.35
const UI_FONT_MIN_SIZE := 20
const UI_FONT_STEPS := [20, 24, 28, 32, 36, 42, 48, 56, 64, 72]
const FRAME_SIMPLE := "res://assets/ui/frame_simple.png"
const FRAME_GLOW := "res://assets/ui/frame_glow.png"
const FRAME_CORNER_DOTS := "res://assets/ui/frame_corner_dots.png"
const FRAME_CROSSHATCH := "res://assets/ui/frame_crosshatch.png"
const FRAME_SCANLINE := "res://assets/ui/frame_scanline.png"
const FRAME_SMALL_LANDSCAPE := "res://assets/ui/frame_small_landscape.png"
const FRAME_PORTRAIT_SCIFI := "res://assets/ui/frame_portrait_scifi.png"
const FRAME_DICE_TRAY_SCIFI := "res://assets/ui/frame_dice_tray_scifi.png"
const FRAME_ITEM_SCIFI := "res://assets/ui/frame_item_scifi.png"
const FRAME_BOTTOM_BAR_SCIFI := "res://assets/ui/frame_bottom_bar_scifi.png"
const FRAME_BOTTOM_BAR_2_SCIFI := "res://assets/ui/frame_bottom_bar_2_scifi.png"
const FRAME_SIMPLE_BAR_SCIFI := "res://assets/ui/frame_simple_bar_scifi.png"
const FRAME_BAR_HORIZONTAL_SCIFI := "res://assets/ui/frame_bar_horizontal_scifi.png"
const FRAME_BAR_SHALLOW_SCIFI := "res://assets/ui/frame_bar_shallow_scifi.png"
const BUTTON_EMPTY := "res://assets/ui/btn_empty.png"
const BUTTON_QUESTION := "res://assets/ui/btn_question.png"
const BUTTON_UP_ARROW := "res://assets/ui/btn_up_arrow.png"
const BUTTON_GRID_123 := "res://assets/ui/btn_grid_123.png"
const BUTTON_BACK_ARROW := "res://assets/ui/btn_back_arrow.png"
const BUTTON_DICE := "res://assets/ui/btn_dice.png"
const BUTTON_HELP_SCIFI := "res://assets/ui/btn_help_scifi.png"
const BUTTON_BACK_SCIFI := "res://assets/ui/btn_back_scifi.png"
const BUTTON_REROLL_SCIFI := "res://assets/ui/btn_reroll_scifi.png"
const BUTTON_INCREASE_SCIFI := "res://assets/ui/btn_increase_scifi.png"
const BUTTON_ITEM_SCIFI := "res://assets/ui/btn_item_scifi.png"
const BUTTON_DEBUG_SCIFI := "res://assets/ui/btn_debug_scifi.png"
const BUTTON_DEBUG2_SCIFI := "res://assets/ui/btn_debug2_scifi.png"
const BUTTON_LARGE_GRAY_SCIFI := "res://assets/ui/btn_large_gray_scifi.png"
const BUTTON_LARGE_GREEN_SCIFI := "res://assets/ui/btn_large_green_scifi.png"
const BUTTON_LARGE_YELLOW_SCIFI := "res://assets/ui/btn_large_yellow_scifi.png"
const PIP_DAMAGE_SCIFI := "res://assets/ui/pip_damage_scifi.png"
const PIP_HEAL_SCIFI := "res://assets/ui/pip_heal_scifi.png"
const PIP_SHIELD_SCIFI := "res://assets/ui/pip_shield_scifi.png"
const PIP_FREEZE_SCIFI := "res://assets/ui/pip_freeze_scifi.png"
const PIP_POISON_SCIFI := "res://assets/ui/pip_poison_scifi.png"
const PIP_ROLL_DOWN_SCIFI := "res://assets/ui/pip_roll_down_scifi.png"
const PIP_ROLL_UP_SCIFI := "res://assets/ui/pip_roll_up_scifi.png"

const FRAME_MARGIN_BY_PATH := {
	FRAME_SIMPLE: 18,
	FRAME_GLOW: 20,
	FRAME_CORNER_DOTS: 18,
	FRAME_CROSSHATCH: 18,
	FRAME_SCANLINE: 18,
	FRAME_SMALL_LANDSCAPE: 18,
	FRAME_PORTRAIT_SCIFI: 24,
	FRAME_DICE_TRAY_SCIFI: 28,
	FRAME_ITEM_SCIFI: 18,
	FRAME_BOTTOM_BAR_SCIFI: 20,
	FRAME_BOTTOM_BAR_2_SCIFI: 20,
	FRAME_SIMPLE_BAR_SCIFI: 28,
	FRAME_BAR_HORIZONTAL_SCIFI: 16,
	FRAME_BAR_SHALLOW_SCIFI: 48,
}

static var _pixel_font: Font = null
static var _pip_texture_cache: Dictionary = {}


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


static func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func parse_signed_amount(value: Variant) -> int:
	var text: String = str(value).strip_edges()
	if text == "":
		return 0
	var sign: int = -1 if text.begins_with("-") else 1
	var digits := ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits == "":
		return 0
	return sign * int(digits)


static func format_amount_no_sign(value: Variant) -> String:
	var text: String = str(value).strip_edges().to_upper()
	if text == "":
		return ""
	var parsed: int = parse_signed_amount(text)
	if parsed != 0:
		return str(abs(parsed))
	return text.trim_prefix("+").trim_prefix("-")


static func pip_key_for_effect(kind: String, value: Variant = "") -> String:
	var normalized_kind: String = kind.to_lower()
	match normalized_kind:
		"dmg", "damage", "blast", "pierce":
			return "damage"
		"heal", "revive":
			return "heal"
		"shield", "taunt":
			return "shield"
		"dot", "poison":
			return "poison"
		"freeze", "frozen", "die_freeze":
			return "freeze"
		"rfe":
			return "roll_down"
		"rfm":
			return "roll_down"
		"roll":
			return "roll_down" if parse_signed_amount(value) < 0 else "roll_up"
	return ""


static func pip_texture_for_key(key: String) -> Texture2D:
	if key == "":
		return null
	if _pip_texture_cache.has(key):
		return _pip_texture_cache.get(key)
	var texture_path := ""
	match key:
		"damage":
			texture_path = PIP_DAMAGE_SCIFI
		"heal":
			texture_path = PIP_HEAL_SCIFI
		"shield":
			texture_path = PIP_SHIELD_SCIFI
		"freeze":
			texture_path = PIP_FREEZE_SCIFI
		"poison":
			texture_path = PIP_POISON_SCIFI
		"roll_down":
			texture_path = PIP_ROLL_DOWN_SCIFI
		"roll_up":
			texture_path = PIP_ROLL_UP_SCIFI
	var texture: Texture2D = _load_texture(texture_path)
	if texture != null:
		_pip_texture_cache[key] = texture
	return texture


static func _frame_margin_for(texture_path: String, fallback_margin: int) -> int:
	return int(FRAME_MARGIN_BY_PATH.get(texture_path, fallback_margin))


static func make_ninepatch_stylebox(texture_path: String, margin_px: int = 18, modulate_color: Color = Color.WHITE) -> StyleBoxTexture:
	var texture: Texture2D = _load_texture(texture_path)
	var stylebox := StyleBoxTexture.new()
	stylebox.texture = texture
	stylebox.modulate_color = modulate_color
	var margin_value: int = _frame_margin_for(texture_path, margin_px)
	stylebox.texture_margin_left = margin_value
	stylebox.texture_margin_right = margin_value
	stylebox.texture_margin_top = margin_value
	stylebox.texture_margin_bottom = margin_value
	stylebox.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	stylebox.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	stylebox.draw_center = true
	return stylebox


static func style_ninepatch_panel(panel: Control, texture_path: String, margin_px: int = 18, modulate_color: Color = Color.WHITE) -> void:
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_theme_stylebox_override("panel", make_ninepatch_stylebox(texture_path, margin_px, modulate_color))


static func style_ninepatch_frame(panel: Control, texture_path: String, margin_px: int = 18, modulate_color: Color = Color.WHITE) -> void:
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var stylebox := make_ninepatch_stylebox(texture_path, margin_px, modulate_color)
	stylebox.draw_center = false
	panel.add_theme_stylebox_override("panel", stylebox)


static func style_icon_button(button: BaseButton, texture_path: String, pressed_texture_path: String = BUTTON_EMPTY) -> void:
	if button == null:
		return
	var normal_texture: Texture2D = _load_texture(texture_path)
	var pressed_texture: Texture2D = _load_texture(pressed_texture_path)
	if button is TextureButton:
		var texture_button := button as TextureButton
		texture_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_button.ignore_texture_size = true
		texture_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		texture_button.texture_normal = normal_texture
		texture_button.texture_pressed = pressed_texture
		texture_button.texture_hover = normal_texture
		texture_button.texture_disabled = pressed_texture
		texture_button.texture_focused = normal_texture
	elif button is Button:
		var text_button := button as Button
		text_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		text_button.icon = normal_texture
		text_button.flat = true
		text_button.text = ""
		text_button.expand_icon = true
		text_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER


static func _make_full_texture_stylebox(texture_path: String, modulate_color: Color = Color.WHITE) -> StyleBoxTexture:
	var texture: Texture2D = _load_texture(texture_path)
	var stylebox := StyleBoxTexture.new()
	stylebox.texture = texture
	stylebox.modulate_color = modulate_color
	stylebox.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	stylebox.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	stylebox.draw_center = true
	return stylebox


static func style_texture_button(button: BaseButton, texture_path: String) -> void:
	if button == null:
		return
	if button is TextureButton:
		var texture_button := button as TextureButton
		var texture: Texture2D = _load_texture(texture_path)
		texture_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_button.ignore_texture_size = true
		texture_button.stretch_mode = TextureButton.STRETCH_SCALE
		texture_button.texture_normal = texture
		texture_button.texture_hover = texture
		texture_button.texture_pressed = texture
		texture_button.texture_focused = texture
		texture_button.texture_disabled = texture
	elif button is Button:
		var text_button := button as Button
		text_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		text_button.text = ""
		text_button.icon = null
		text_button.flat = false
		text_button.add_theme_stylebox_override("normal", _make_full_texture_stylebox(texture_path))
		text_button.add_theme_stylebox_override("hover", _make_full_texture_stylebox(texture_path, Color(1.06, 1.06, 1.06, 1.0)))
		text_button.add_theme_stylebox_override("pressed", _make_full_texture_stylebox(texture_path, Color(0.88, 0.88, 0.88, 1.0)))
		text_button.add_theme_stylebox_override("disabled", _make_full_texture_stylebox(texture_path, Color(0.58, 0.58, 0.62, 0.92)))


static func style_labeled_texture_button(button: Button, texture_path: String, font_size: int, font_color: Color = TEXT_PRIMARY) -> void:
	if button == null:
		return
	apply_pixel_font(button)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.flat = false
	button.icon = null
	button.expand_icon = false
	button.add_theme_font_size_override("font_size", scale_font_size(font_size))
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_focus_color", font_color)
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.98))
	button.add_theme_stylebox_override("normal", _make_full_texture_stylebox(texture_path))
	button.add_theme_stylebox_override("hover", _make_full_texture_stylebox(texture_path, Color(1.06, 1.06, 1.06, 1.0)))
	button.add_theme_stylebox_override("pressed", _make_full_texture_stylebox(texture_path, Color(0.90, 0.90, 0.90, 1.0)))
	button.add_theme_stylebox_override("disabled", _make_full_texture_stylebox(BUTTON_LARGE_GRAY_SCIFI, Color(0.72, 0.72, 0.76, 1.0)))


static func scale_font_size(font_size: int) -> int:
	var scaled_size: int = maxi(UI_FONT_MIN_SIZE, int(round(float(font_size) * UI_FONT_SCALE)))
	for stepped_size in UI_FONT_STEPS:
		if scaled_size <= int(stepped_size):
			return int(stepped_size)
	return scaled_size


static func effect_color(kind: String) -> Color:
	match kind.to_lower():
		"dmg", "damage", "blast", "pierce":
			return COLOR_DAMAGE
		"heal", "revive":
			return COLOR_HEAL
		"shield", "taunt":
			return COLOR_SHIELD
		"dot", "poison", "debuff":
			return COLOR_DEBUFF
		"roll", "rfe", "rfm", "freeze":
			return COLOR_ROLL
		"roll_down":
			return COLOR_ROLL
		"roll_up":
			return COLOR_HEAL
	return TEXT_PRIMARY


static func effect_value_color(kind: String) -> Color:
	return effect_color(kind).lerp(TEXT_PRIMARY, 0.32)


static func status_color(token: String) -> Color:
	var upper: String = token.to_upper()
	if upper.begins_with("POI") or upper.begins_with("POT") or upper == "DOT" or upper == "COW" or upper == "DOWN" or upper == "P":
		return COLOR_DEBUFF
	if upper == "RMP":
		return COLOR_DAMAGE
	if upper.begins_with("+") or upper.begins_with("-") or upper == "FR":
		return COLOR_ROLL
	if upper.begins_with("SH") or upper == "TA" or upper == "CL":
		return COLOR_SHIELD
	if upper.begins_with("HP"):
		return COLOR_HEAL
	return TEXT_MUTED


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
