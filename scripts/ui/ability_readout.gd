class_name AbilityReadout
extends PanelContainer

const READOUT_SIZE := Vector2(0, 88)
const PIP_ICON_MAP := {
	"dmg": preload("res://assets/generated/icon_damage_1776027930.png"),
	"blast": preload("res://assets/generated/icon_damage_1776027930.png"),
	"pierce": preload("res://assets/generated/icon_damage_v2_1776040040.png"),
	"heal": preload("res://assets/generated/icon_heal_heart_1776027943.png"),
	"revive": preload("res://assets/generated/icon_heal_heart_1776027943.png"),
	"shield": preload("res://assets/generated/icon_shield_1776027929.png"),
	"taunt": preload("res://assets/generated/icon_shield_1776027929.png"),
	"dot": preload("res://assets/generated/icon_dot_1776027932.png"),
	"roll": preload("res://assets/generated/icon_dice_d6_1776027927.png"),
	"freeze": preload("res://assets/generated/icon_frost_snowflake_frame_0_1776027966.png"),
	"cloak": preload("res://assets/generated/icon_dice_v2_1776040041.png"),
}

var action_pips: Array = []
var _pip_row: HFlowContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = READOUT_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_build()
	_refresh()


func configure(pips: Array) -> void:
	action_pips = pips.duplicate(true)
	_refresh()


func clear() -> void:
	action_pips.clear()
	_refresh()


func _build() -> void:
	add_theme_stylebox_override("panel", _style(Color(0.006, 0.012, 0.020, 0.42), Color.TRANSPARENT, 0, 0))

	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)

	_pip_row = HFlowContainer.new()
	_pip_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pip_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pip_row.alignment = FlowContainer.ALIGNMENT_CENTER
	_pip_row.add_theme_constant_override("h_separation", 8)
	_pip_row.add_theme_constant_override("v_separation", 8)
	margin.add_child(_pip_row)


func _refresh() -> void:
	if _pip_row == null:
		return
	for child in _pip_row.get_children():
		child.queue_free()

	if action_pips.is_empty():
		_pip_row.add_child(_make_placeholder())
		return

	var max_visible: int = mini(action_pips.size(), 5)
	for i in range(max_visible):
		var pip: Dictionary = action_pips[i]
		_pip_row.add_child(_make_action_pip(str(pip.get("kind", "")), str(pip.get("text", ""))))
	if action_pips.size() > max_visible:
		_pip_row.add_child(_make_action_pip("more", "+%d" % (action_pips.size() - max_visible)))


func _make_placeholder() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(164, 60)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for i in range(3):
		var block: ColorRect = ColorRect.new()
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.custom_minimum_size = Vector2(40, 10)
		block.color = Color(0.16, 0.23, 0.31, 0.36)
		row.add_child(block)
	return row


func _make_action_pip(kind: String, text: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(96, 60)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _style(Color(0.006, 0.012, 0.020, 0.72), _pip_border(kind), 3, 5))

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)

	var icon: TextureRect = TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(46, 46)
	icon.texture = PIP_ICON_MAP.get(kind)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = _format_pip_text(kind, text)
	label.custom_minimum_size = Vector2(36, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_label(label, 40, PixelUI.TEXT_PRIMARY, 3)
	row.add_child(label)
	return panel


func _pip_border(kind: String) -> Color:
	match kind:
		"dmg", "blast", "pierce":
			return Color(0.86, 0.32, 0.28, 0.92)
		"heal", "revive":
			return Color(0.38, 0.82, 0.55, 0.92)
		"shield", "taunt":
			return Color(0.42, 0.66, 0.88, 0.92)
		"dot":
			return Color(0.82, 0.40, 0.58, 0.92)
		"roll":
			return Color(0.86, 0.66, 0.26, 0.92)
		"freeze", "cloak":
			return Color(0.48, 0.78, 0.88, 0.92)
	return Color(0.34, 0.52, 0.70, 0.86)


func _format_pip_text(kind: String, text: String) -> String:
	var value: String = text.strip_edges().to_upper()
	if value == "" and kind == "pierce":
		return "P"
	if value == "" and kind == "cloak":
		return "CL"
	if value == "" and kind == "taunt":
		return "TA"
	return value


func _apply_label(label: Label, font_size: int, color: Color, outline: int = 1) -> void:
	PixelUI.apply_pixel_font(label)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.025, 0.98))
	label.add_theme_constant_override("outline_size", outline)


func _style(bg: Color, border: Color, border_width: int, margin: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.set_content_margin(SIDE_LEFT, margin)
	style.set_content_margin(SIDE_TOP, margin)
	style.set_content_margin(SIDE_RIGHT, margin)
	style.set_content_margin(SIDE_BOTTOM, margin)
	return style
