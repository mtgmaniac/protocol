class_name AbilityReadout
extends PanelContainer

const READOUT_SIZE := Vector2(0, 120)
const ROW_HEIGHT := 52.0
const ROW_GAP := 6.0
const OUTER_PAD_X := 4.0
const ICON_FONT_SIZE := 48
const VALUE_FONT_SIZE := 46
const DURATION_FONT_SIZE := 34
const TARGET_FONT_SIZE := 38
const EMPTY_ALPHA := 0.18
const ICONS := {
	"dmg": "⚡",
	"damage": "⚡",
	"blast": "⚡",
	"pierce": "⚡",
	"roll": "🎲",
	"rfe": "🎲",
	"rfm": "🎲",
	"shield": "🛡",
	"taunt": "🛡",
	"heal": "➕",
	"revive": "➕",
	"dot": "☠",
	"poison": "☠",
}

var action_result: Dictionary = {}
var side: String = "hero"
var _row_layer: Control = null
var _upper_row: HBoxContainer = null
var _lower_row: HBoxContainer = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	custom_minimum_size = READOUT_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_build()
	_refresh()


func configure(result_data: Variant, side_hint: String = "") -> void:
	if side_hint != "":
		side = side_hint
	action_result = _normalize_result(result_data)
	_refresh()


func clear() -> void:
	action_result.clear()
	_refresh()


func _build() -> void:
	add_theme_stylebox_override("panel", _style(Color(0.006, 0.012, 0.020, 0.22), Color.TRANSPARENT, 0, 0))

	_row_layer = Control.new()
	_row_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row_layer.custom_minimum_size = Vector2.ZERO
	_row_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_row_layer)

	_upper_row = _make_row()
	_lower_row = _make_row()
	_row_layer.add_child(_upper_row)
	_row_layer.add_child(_lower_row)
	_layout_rows()


func _make_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 7)
	return row


func _refresh() -> void:
	if _upper_row == null or _lower_row == null:
		return
	_layout_rows()
	_clear_row(_upper_row)
	_clear_row(_lower_row)

	var effects: Array = action_result.get("effects", [])
	if effects.is_empty():
		_add_empty_state(_closest_row())
		return

	var target: String = str(action_result.get("target", "")).to_upper()
	var split_index: int = _find_split_index(effects, target)
	if split_index >= effects.size():
		_add_parts_to_row(_closest_row(), effects, target)
		return

	var first_row_effects: Array = effects.slice(0, split_index)
	var overflow_effects: Array = effects.slice(split_index)
	_add_parts_to_row(_closest_row(), first_row_effects, "")
	_add_parts_to_row(_overflow_row(), overflow_effects, target)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_rows()
		call_deferred("_refresh")


func _layout_rows() -> void:
	if _upper_row == null or _lower_row == null:
		return
	var total_height: float = (ROW_HEIGHT * 2.0) + ROW_GAP
	var start_y: float = floor((size.y - total_height) * 0.5)
	var row_size := Vector2(size.x, ROW_HEIGHT)
	_upper_row.position = Vector2(0.0, start_y)
	_upper_row.size = row_size
	_lower_row.position = Vector2(0.0, start_y + ROW_HEIGHT + ROW_GAP)
	_lower_row.size = row_size


func _closest_row() -> HBoxContainer:
	return _upper_row if side == "enemy" else _lower_row


func _overflow_row() -> HBoxContainer:
	return _lower_row if side == "enemy" else _upper_row


func _clear_row(row: HBoxContainer) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()


func _add_empty_state(row: HBoxContainer) -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "—"
	label.modulate = Color(0.70, 0.80, 0.90, EMPTY_ALPHA)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_pixel_label(label, 34, PixelUI.TEXT_MUTED, 2)
	row.add_child(label)


func _add_parts_to_row(row: HBoxContainer, effects: Array, target: String) -> void:
	for i in range(effects.size()):
		if i > 0:
			row.add_child(_make_separator())
		row.add_child(_make_effect_group(effects[i]))
	if target != "":
		row.add_child(_make_target_label(target))


func _make_effect_group(effect: Dictionary) -> HBoxContainer:
	var effect_kind: String = str(effect.get("kind", ""))
	var icon_color: Color = PixelUI.effect_color(effect_kind)
	var value_color: Color = PixelUI.effect_value_color(effect_kind)

	var group := HBoxContainer.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.add_theme_constant_override("separation", 3)

	var icon_label := Label.new()
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_label.text = str(ICONS.get(str(effect.get("kind", "")), "⚡"))
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", ICON_FONT_SIZE)
	icon_label.add_theme_color_override("font_color", icon_color)
	icon_label.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.025, 0.98))
	icon_label.add_theme_constant_override("outline_size", 2)
	group.add_child(icon_label)

	var value_label := Label.new()
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value_label.text = str(effect.get("value", "")).to_upper()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.clip_text = false
	_apply_pixel_label(value_label, VALUE_FONT_SIZE, value_color, 3)
	group.add_child(value_label)

	var duration: int = int(effect.get("duration", 0))
	if duration > 1:
		var duration_label := Label.new()
		duration_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		duration_label.text = "(%dT)" % duration
		duration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		duration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		duration_label.modulate = Color(0.78, 0.86, 0.92, 0.82)
		_apply_pixel_label(duration_label, DURATION_FONT_SIZE, PixelUI.TEXT_MUTED, 2)
		group.add_child(duration_label)

	return group


func _make_separator() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = ""
	label.custom_minimum_size = Vector2(12, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate = Color(0.84, 0.90, 0.96, 0.78)
	_apply_pixel_label(label, 34, PixelUI.TEXT_MUTED, 2)
	return label


func _make_target_label(target: String) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = target
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate = Color(0.82, 0.90, 0.96, 0.88)
	_apply_pixel_label(label, TARGET_FONT_SIZE, PixelUI.TEXT_MUTED, 2)
	return label


func _find_split_index(effects: Array, target: String) -> int:
	var available_width: float = maxf(size.x - (OUTER_PAD_X * 2.0), 1.0)
	var full_width: float = _estimate_row_width(effects, target)
	if full_width <= available_width:
		return effects.size()
	if effects.size() <= 1:
		return effects.size()

	var primary_count: int = 1
	for count in range(effects.size(), 0, -1):
		var primary_width: float = _estimate_row_width(effects.slice(0, count), "")
		if primary_width <= available_width:
			primary_count = count
			break
	return clampi(primary_count, 1, effects.size() - 1)


func _estimate_row_width(effects: Array, target: String) -> float:
	var width := 0.0
	for i in range(effects.size()):
		if i > 0:
			width += 28.0
		var effect: Dictionary = effects[i]
		width += 34.0
		width += maxf(18.0, float(str(effect.get("value", "")).length()) * 18.0)
		var duration: int = int(effect.get("duration", 0))
		if duration > 1:
			width += 12.0 + float(("(%dT)" % duration).length()) * 12.0
	if target != "":
		width += 10.0 + float(target.length()) * 16.0
	return width


func _normalize_result(result_data: Variant) -> Dictionary:
	if result_data is Dictionary:
		var result := (result_data as Dictionary).duplicate(true)
		var effects: Array = result.get("effects", [])
		result["effects"] = effects.slice(0, 3)
		return result
	if result_data is Array:
		var converted_effects: Array = []
		for pip_variant in result_data:
			if converted_effects.size() >= 3:
				break
			var pip: Dictionary = pip_variant
			converted_effects.append({
				"kind": str(pip.get("kind", "")),
				"value": str(pip.get("value", pip.get("text", ""))),
				"duration": int(pip.get("duration", 0)),
			})
		return {"effects": converted_effects, "target": ""}
	return {"effects": [], "target": ""}


func _apply_pixel_label(label: Label, font_size: int, color: Color, outline: int = 1) -> void:
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
