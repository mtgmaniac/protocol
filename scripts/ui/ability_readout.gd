class_name AbilityReadout
extends PanelContainer

const READOUT_SIZE := Vector2(0, 104)
const ROW_HEIGHT := 80.0
const ROW_GAP := 2.0
# Distance between the two pip rows' top edges. Less than ROW_HEIGHT so the 2nd row
# sits closer to the 1st (the row boxes overlap, but the centered pips don't), which
# keeps a two-row ability from spilling past the dice-tray edge.
const ROW_PITCH := 64.0
const OUTER_PAD_X := 10.0
const HERO_TOP_PAD := 4.0
# Pull both rows toward the dice (center of the tray) so the closest row hugs the dice.
const READOUT_CENTER_PULL_PX := 30.0
const TARGET_FONT_SIZE := 48
const EMPTY_ALPHA := 0.18
const PIP_REVEAL_TIME := 0.12

var action_result: Dictionary = {}
var side: String = "hero"
var _row_layer: Control = null
var _upper_frame: Control = null
var _lower_frame: Control = null
var _upper_underline: ColorRect = null
var _lower_underline: ColorRect = null
var _upper_row: HBoxContainer = null
var _lower_row: HBoxContainer = null
var _pips_revealed: bool = false
var _pips_tween: Tween = null
var _has_content: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	custom_minimum_size = READOUT_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# The readout renders nothing now — the visible result tag is a die-docked overlay
	# drawn by battle_scene. This node only reserves its combat-zone row + holds the data.
	modulate = Color(1, 1, 1, 0)
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
	# A die's result tag only exists when it actually resolves an effect.
	_has_content = not effects.is_empty()
	_apply_tag_plate()
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
	_apply_tag_plate()
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
	_apply_tag_plate()
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


# The result tag is now drawn by battle_scene as a die-docked overlay plate (it needs the
# die's live screen position for the overlap). This readout stays in the rail purely to
# reserve the combat-zone row and to hold the resolved effect data; it renders nothing
# itself (see _ready, modulate alpha 0). Kept as a no-op so callers still resolve.
func _apply_tag_plate() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())


# True once the die has resolved an effect and its readout is revealed — battle_scene
# reads this to decide whether to show the die-docked result tag.
func is_showing() -> bool:
	return _pips_revealed and _has_content


# The resolved effect list (empty until a roll resolves), consumed by the die tag.
func tag_effects() -> Array:
	return action_result.get("effects", [])


func tag_target() -> String:
	return str(action_result.get("target", ""))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_rows()
		call_deferred("_refresh")


func _layout_rows() -> void:
	if _upper_row == null or _lower_row == null or _upper_frame == null or _lower_frame == null:
		return
	var total_rows_height: float = ROW_PITCH + ROW_HEIGHT
	var start_y: float = 0.0
	if side == "enemy":
		start_y = size.y - total_rows_height + READOUT_CENTER_PULL_PX
	else:
		start_y = -READOUT_CENTER_PULL_PX
	var row_size := Vector2(size.x, ROW_HEIGHT)
	_upper_frame.position = Vector2(0.0, start_y)
	_upper_frame.size = row_size
	_upper_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lower_frame.position = Vector2(0.0, start_y + ROW_PITCH)
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


func _make_effect_group(effect: Dictionary) -> Control:
	var group: Control = EffectPip.build_group(effect, EffectPip.PROFILE_READOUT, side)
	if group is HBoxContainer:
		group.gui_input.connect(_on_effect_group_gui_input.bind(group))
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
		var effect_width := EffectPip.estimate_display_width(effect, EffectPip.PROFILE_READOUT)
		width += effect_width
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
				"scope": str(pip.get("scope", "")),
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



