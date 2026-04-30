class_name AbilityReadout
extends PanelContainer

const READOUT_SIZE := Vector2(0, 84)
const ROW_HEIGHT := 64.0
const ROW_GAP := 2.0
const OUTER_PAD_X := 10.0
const HERO_TOP_PAD := 4.0
const READOUT_CENTER_PULL_PX := 18.0
const EFFECT_GROUP_MIN_WIDTH := 72.0
const ICON_FONT_SIZE := 64
const VALUE_FONT_SIZE := 64
const DURATION_FONT_SIZE := 40
const TARGET_FONT_SIZE := 40
const EMPTY_ALPHA := 0.18
const PIP_REVEAL_TIME := 0.12
const ICONS := {
	"dmg": "âš¡",
	"damage": "âš¡",
	"blast": "âš¡",
	"pierce": "",
	"roll": "ðŸŽ²",
	"rfe": "ðŸŽ²",
	"rfm": "ðŸŽ²",
	"freeze": "â„",
	"shield": "ðŸ›¡",
	"taunt": "ðŸ›¡",
	"heal": "âž•",
	"revive": "",
	"dot": "â˜ ",
	"poison": "â˜ ",
}
const PIP_ICON_ATLAS_PATH := "res://assets/ui/icons/pip_icons.png"
const PIP_ICON_CELL_SIZE := Vector2(256, 256)
const PIP_ICON_COLUMNS := {
	"dmg": 0,
	"damage": 0,
	"blast": 0,
	"shield": 1,
	"taunt": 1,
	"heal": 2,
	"dot": 3,
	"poison": 3,
	"roll": 4,
	"rfe": 4,
	"rfm": 4,
	"freeze": 5,
}

var action_result: Dictionary = {}
var side: String = "hero"
var _row_layer: Control = null
var _upper_frame: Control = null
var _lower_frame: Control = null
var _upper_underline: ColorRect = null
var _lower_underline: ColorRect = null
var _upper_row: HBoxContainer = null
var _lower_row: HBoxContainer = null
var _tooltip_callback: Callable = Callable()
var _pip_icon_atlas: Texture2D = null
var _pips_revealed: bool = false
var _pips_tween: Tween = null


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


func set_tooltip_callback(callback: Callable) -> void:
	_tooltip_callback = callback
	if _upper_row != null:
		_refresh()


func clear() -> void:
	action_result.clear()
	_refresh()


func _build() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	_row_layer = Control.new()
	_row_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row_layer.custom_minimum_size = Vector2.ZERO
	_row_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_row_layer.visible = false
	_row_layer.modulate = Color(1, 1, 1, 0)
	add_child(_row_layer)

	_upper_frame = _make_row_frame()
	_lower_frame = _make_row_frame()
	_upper_row = _make_row()
	_lower_row = _make_row()
	_upper_frame.add_child(_upper_row)
	_lower_frame.add_child(_lower_row)
	_upper_underline = _make_row_underline()
	_lower_underline = _make_row_underline()
	_row_layer.add_child(_upper_frame)
	_row_layer.add_child(_lower_frame)
	_row_layer.add_child(_upper_underline)
	_row_layer.add_child(_lower_underline)
	_layout_rows()
	_sync_pip_visibility()


func _make_row_frame() -> Control:
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	return frame


func _make_row_underline() -> ColorRect:
	var underline := ColorRect.new()
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	underline.visible = false
	underline.color = Color(0, 0, 0, 0)
	return underline


func _make_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.add_theme_constant_override("margin_left", 8)
	row.add_theme_constant_override("margin_top", 4)
	row.add_theme_constant_override("margin_right", 8)
	row.add_theme_constant_override("margin_bottom", 4)
	return row


func _refresh() -> void:
	if _upper_row == null or _lower_row == null:
		return
	_layout_rows()
	_clear_row(_upper_row)
	_clear_row(_lower_row)
	_set_row_frame_visible(_upper_row, false)
	_set_row_frame_visible(_lower_row, false)

	var effects: Array = action_result.get("effects", [])
	if effects.is_empty():
		_add_empty_state(_closest_row())
		_sync_pip_visibility()
		return

	var target: String = str(action_result.get("target", "")).to_upper()
	var split_index: int = _find_split_index(effects, target)
	if split_index >= effects.size():
		_add_parts_to_row(_closest_row(), effects, target)
		_sync_pip_visibility()
		return

	var first_row_effects: Array = effects.slice(0, split_index)
	var overflow_effects: Array = effects.slice(split_index)
	_add_parts_to_row(_closest_row(), first_row_effects, "")
	_add_parts_to_row(_overflow_row(), overflow_effects, target)
	call_deferred("_update_all_underlines")
	_sync_pip_visibility()


func show_pips() -> void:
	_pips_revealed = true
	if _row_layer == null:
		return
	if _pips_tween != null and is_instance_valid(_pips_tween):
		_pips_tween.kill()
	_pips_tween = null
	if _upper_underline != null and _upper_frame != null:
		_upper_underline.visible = _upper_frame.visible
	if _lower_underline != null and _lower_frame != null:
		_lower_underline.visible = _lower_frame.visible
	_row_layer.visible = true
	_row_layer.modulate = Color(1, 1, 1, 0)
	_pips_tween = create_tween()
	_pips_tween.tween_property(_row_layer, "modulate", Color(1, 1, 1, 1), PIP_REVEAL_TIME)


func hide_pips() -> void:
	_pips_revealed = false
	if _pips_tween != null and is_instance_valid(_pips_tween):
		_pips_tween.kill()
	_pips_tween = null
	if _row_layer == null:
		return
	_row_layer.modulate = Color(1, 1, 1, 0)
	_row_layer.visible = false
	if _upper_underline != null:
		_upper_underline.visible = false
		_upper_underline.size = Vector2.ZERO
	if _lower_underline != null:
		_lower_underline.visible = false
		_lower_underline.size = Vector2.ZERO


func _sync_pip_visibility() -> void:
	if _row_layer == null:
		return
	if _pips_revealed:
		if _upper_underline != null and _upper_frame != null:
			_upper_underline.visible = _upper_frame.visible
		if _lower_underline != null and _lower_frame != null:
			_lower_underline.visible = _lower_frame.visible
		_row_layer.visible = true
		_row_layer.modulate = Color(1, 1, 1, 1)
	else:
		_row_layer.visible = false
		_row_layer.modulate = Color(1, 1, 1, 0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_rows()
		call_deferred("_refresh")


func _layout_rows() -> void:
	if _upper_row == null or _lower_row == null or _upper_frame == null or _lower_frame == null:
		return
	var total_rows_height: float = (ROW_HEIGHT * 2.0) + ROW_GAP
	var start_y: float = 0.0
	if side == "enemy":
		start_y = size.y - total_rows_height + READOUT_CENTER_PULL_PX
	else:
		start_y = -READOUT_CENTER_PULL_PX
	var row_size := Vector2(size.x, ROW_HEIGHT)
	_upper_frame.position = Vector2(0.0, start_y)
	_upper_frame.size = row_size
	_upper_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lower_frame.position = Vector2(0.0, start_y + ROW_HEIGHT + ROW_GAP)
	_lower_frame.size = row_size
	_lower_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_update_row_underline(_upper_row)
	_update_row_underline(_lower_row)


func _closest_row() -> HBoxContainer:
	return _lower_row if side == "enemy" else _upper_row


func _overflow_row() -> HBoxContainer:
	return _upper_row if side == "enemy" else _lower_row


func _clear_row(row: HBoxContainer) -> void:
	for child in row.get_children():
		row.remove_child(child)
		child.queue_free()


func _add_empty_state(row: HBoxContainer) -> void:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "â€”"
	label.modulate = Color(0.70, 0.80, 0.90, EMPTY_ALPHA)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_pixel_label(label, 34, PixelUI.TEXT_MUTED, 2)
	row.add_child(label)
	_set_row_frame_visible(row, true)
	call_deferred("_update_all_underlines")


func _add_parts_to_row(row: HBoxContainer, effects: Array, target: String) -> void:
	for i in range(effects.size()):
		if i > 0:
			row.add_child(_make_separator())
		row.add_child(_make_effect_group(effects[i]))
	if target != "":
		row.add_child(_make_target_label(target))
	_set_row_frame_visible(row, true)
	call_deferred("_update_all_underlines")


func _get_pip_icon_texture(kind: String) -> Texture2D:
	return PixelUI.pip_texture_for_key(kind)


func _get_pip_icon_atlas() -> Texture2D:
	return null


func _make_effect_group(effect: Dictionary) -> Control:
	var effect_kind: String = str(effect.get("kind", ""))
	var display_value: String = _display_value_for_effect(effect)
	var pip_key: String = _pip_key_for_effect(effect)
	var color_key: String = pip_key if pip_key != "" else effect_kind
	var value_color: Color = PixelUI.effect_value_color(color_key)

	var group := HBoxContainer.new()
	group.mouse_filter = Control.MOUSE_FILTER_STOP
	group.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	group.custom_minimum_size = Vector2(EFFECT_GROUP_MIN_WIDTH, 0)
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.add_theme_constant_override("separation", 1)
	group.gui_input.connect(_on_effect_group_gui_input.bind(group))

	if effect_kind in ["cloak", "revive", "pierce", "counter", "rampage"]:
		var plain_label := Label.new()
		plain_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plain_label.text = effect_kind.to_upper()
		plain_label.custom_minimum_size = Vector2(0, 0)
		plain_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plain_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_apply_pixel_label(plain_label, VALUE_FONT_SIZE, PixelUI.effect_color(effect_kind), 3)
		group.add_child(plain_label)
		if _tooltip_callback.is_valid():
			_tooltip_callback.call(group, _build_effect_tooltip(effect))
		return group

	var icon_texture := _get_pip_icon_texture(pip_key)
	if icon_texture != null:
		var icon_rect := TextureRect.new()
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.custom_minimum_size = Vector2(44, 44)
		icon_rect.texture = icon_texture
		icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		group.add_child(icon_rect)

	if effect_kind != "freeze":
		var value_label := Label.new()
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value_label.text = display_value
		value_label.custom_minimum_size = Vector2(0, 0)
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

	if _tooltip_callback.is_valid():
		_tooltip_callback.call(group, _build_effect_tooltip(effect))

	return group


func _on_effect_group_gui_input(event: InputEvent, group: Control) -> void:
	var parent_control: Control = group.get_parent() as Control
	if parent_control != null:
		parent_control.gui_input.emit(event)


func _set_row_frame_visible(row: HBoxContainer, visible: bool) -> void:
	if row == _upper_row and _upper_frame != null:
		_upper_frame.visible = visible
		if _upper_underline != null:
			_upper_underline.visible = visible and _pips_revealed
		_update_row_underline(_upper_row)
	elif row == _lower_row and _lower_frame != null:
		_lower_frame.visible = visible
		if _lower_underline != null:
			_lower_underline.visible = visible and _pips_revealed
		_update_row_underline(_lower_row)


func _update_row_underline(row: HBoxContainer) -> void:
	var underline: ColorRect = null
	var frame: Control = null
	if row == _upper_row:
		underline = _upper_underline
		frame = _upper_frame
	elif row == _lower_row:
		underline = _lower_underline
		frame = _lower_frame
	if underline == null or frame == null or row == null:
		return
	if not _pips_revealed:
		underline.visible = false
		underline.size = Vector2.ZERO
		return
	if not underline.visible:
		return
	var content_width: float = clampf(row.get_combined_minimum_size().x, 0.0, frame.size.x - (OUTER_PAD_X * 2.0))
	if content_width <= 0.0:
		underline.size = Vector2.ZERO
		return
	underline.position = Vector2(floor(frame.position.x + (frame.size.x - content_width) * 0.5), frame.position.y + ROW_HEIGHT - 2.0)
	underline.size = Vector2(content_width, 2.0)


func _update_all_underlines() -> void:
	_update_row_underline(_upper_row)
	_update_row_underline(_lower_row)


func _build_effect_tooltip(effect: Dictionary) -> String:
	var kind: String = str(effect.get("kind", "")).to_lower()
	var value: String = str(effect.get("value", "")).to_upper()
	var duration: int = int(effect.get("duration", 0))
	if kind == "shield" and value == "CL":
		return "CLOAK\n80% chance to evade the next incoming damage attempt."
	if kind == "cloak":
		return "CLOAK\n80% chance to evade the next incoming damage attempt."
	if kind == "revive":
		return "REVIVE\nRevive a fallen ally with a percentage of their max HP."
	if kind == "shield" and value == "TA":
		return "TAUNT\nApply taunt to target."
	if kind == "freeze" and value == "FR":
		return "FROZEN\nApply frozen to target."
	match kind:
		"dmg", "damage":
			return "DEAL DAMAGE\nDeal %s damage to the target." % value
		"dot", "poison":
			var turns_text: String = "for %d turns" % duration if duration > 0 else "each turn"
			return "DAMAGE OVER TIME\nDeal %s damage per turn %s." % [value, turns_text]
		"shield":
			return "GAIN SHIELD\nBlock %s incoming damage." % value
		"heal":
			return "HEAL\nRestore %s HP." % value
		"roll":
			return _build_roll_shift_tooltip(value, duration)
		"rfe":
			return _build_roll_shift_tooltip(value, duration)
		"rfm":
			return _build_roll_shift_tooltip(value, duration)
		"pierce":
			return "PIERCE\nIgnores enemy shield. Damage hits HP directly."
		"blast":
			return "BLAST\nDeal damage to all enemies."
		_:
			return "%s\n%s: %s" % [kind.to_upper(), kind, value]


func _build_roll_shift_tooltip(value: String, duration: int) -> String:
	var amount: int = PixelUI.parse_signed_amount(value)
	var amount_text: String = str(abs(amount))
	var verb: String = "Reduce die roll by %s" % amount_text if amount < 0 else "Increase die roll by %s" % amount_text
	if duration > 1:
		return "%s for %d turns." % [verb, duration]
	return "%s." % verb


func _make_separator() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = ""
	label.custom_minimum_size = Vector2(10, 0)
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
			width += 16.0
		var effect: Dictionary = effects[i]
		var effect_width := 48.0
		effect_width += maxf(28.0, float(_display_value_for_effect(effect).length()) * 24.0)
		var duration: int = int(effect.get("duration", 0))
		if duration > 1:
			effect_width += 12.0 + float(("(%dT)" % duration).length()) * 20.0
		width += maxf(EFFECT_GROUP_MIN_WIDTH, effect_width)
	if target != "":
		width += 2.0 + float(target.length()) * 24.0
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


func _pip_key_for_effect(effect: Dictionary) -> String:
	return PixelUI.pip_key_for_effect(str(effect.get("kind", "")), str(effect.get("value", "")))


func _display_value_for_effect(effect: Dictionary) -> String:
	var kind: String = str(effect.get("kind", ""))
	var raw_value: String = str(effect.get("value", "")).strip_edges().to_upper()
	if kind.to_lower() in ["roll", "rfe", "rfm"]:
		return PixelUI.format_amount_no_sign(raw_value)
	return raw_value


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



