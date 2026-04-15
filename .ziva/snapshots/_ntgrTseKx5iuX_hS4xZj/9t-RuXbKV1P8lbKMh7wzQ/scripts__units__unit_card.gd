@tool
class_name UnitCard
extends PanelContainer

const LOW_HP_THRESHOLD := 0.3
const CHIP_DAMAGE_BG := Color(0.53, 0.20, 0.18, 0.98)
const CHIP_SHIELD_BG := Color(0.15, 0.32, 0.50, 0.98)
const CHIP_HEAL_BG := Color(0.12, 0.38, 0.23, 0.98)
const CHIP_DOT_BG := Color(0.43, 0.19, 0.22, 0.98)
const CHIP_DICE_BG := Color(0.46, 0.34, 0.14, 0.98)
const ICON_DAMAGE := "\u26A1"
const ICON_HEAL := "\u271A"
const ICON_DOT := "\u2620"
const ICON_MAP = {
	"damage": preload("res://assets/generated/icon_damage_frame_0_1776027930.png"),
	"shield": preload("res://assets/generated/icon_shield_frame_0_1776027929.png"),
	"heal": preload("res://assets/generated/icon_heal_heart_frame_0_1776027943.png"),
	"dot": preload("res://assets/generated/icon_dot_frame_0_1776027932.png"),
	"dice": preload("res://assets/generated/icon_dice_d6_frame_0_1776027927.png"),
	"frost": preload("res://assets/generated/icon_frost_snowflake_frame_0_1776027966.png"),
}


signal card_pressed

var _tooltip_text: String = ""
var _hold_triggered: bool = false
var _icon_texture_cache: Dictionary = {}


func _ready() -> void:
	_wire_card_frame_input()
	if Engine.is_editor_hint():
		_apply_editor_preview_theme()


func setup_card(display_name: String, current_hp: int, max_hp: int, dice_result: String, ability_text: String, target_text: String, status_list: Array, _gear_list: Array, xp_ratio: float, is_dead: bool, accent_color: Color, portrait_texture: Texture2D = null, tooltip_text: String = "", ability_chart_rows: Array = [], active_zone: String = "") -> void:
	var portrait: TextureRect = get_node("%Portrait")
	var portrait_frame: Control = get_node("%PortraitFrame")
	var portrait_aspect: AspectRatioContainer = get_node("%PortraitAspect")
	var name_label: Label = get_node("%NameLabel")
	var hp_bar: ProgressBar = _resolve_hp_bar()
	var hp_label: Label = _resolve_hp_label(hp_bar)
	var target_label: Label = get_node("%TargetLabel")
	var status_title: Label = get_node("%StatusTitle")
	var gear_title: Label = get_node("%GearTitle")
	var status_effects: Container = get_node("%StatusEffects")
	var gear_slots: Container = get_node("%GearSlots")
	var xp_bar: ProgressBar = get_node("%XPBar")
	var card_frame: Panel = get_node("%CardFrame")
	var dice_chart_panel: PanelContainer = get_node_or_null("%DiceChartPanel")
	if dice_chart_panel == null:
		dice_chart_panel = get_node("CardFrame/Margin/VBox/DiceChartPanel")
	var tooltip_label: Label = get_node("%TooltipLabel")
	var dice_chart: VBoxContainer = get_node("%DiceChart")

	name_label.text = display_name
	_fit_name_label(name_label, display_name)
	if hp_bar != null and hp_label != null:
		_place_hp_label_in_bar(hp_label, hp_bar)
		PixelUI.style_label(hp_label, 28, Color(0.02, 0.04, 0.04, 1.0), 5)
		hp_label.add_theme_color_override("font_outline_color", Color(0.86, 1.0, 0.88, 0.96))
	PixelUI.style_label(target_label, 26, PixelUI.TEXT_MUTED, 3)
	PixelUI.style_label(status_title, 26, PixelUI.TEXT_MUTED, 3)
	PixelUI.apply_pixel_font(tooltip_label)
	if hp_bar != null:
		hp_bar.max_value = max(max_hp, 1)
		hp_bar.value = clamp(current_hp, 0, max_hp)
	if hp_label != null:
		hp_label.text = "%d/%d" % [current_hp, max_hp]
	target_label.text = "Target: %s" % target_text
	xp_bar.value = clampf(xp_ratio, 0.0, 1.0) * 100.0
	
	portrait.texture = portrait_texture
	if portrait_texture != null:
		portrait_aspect.ratio = float(portrait_texture.get_width()) / float(portrait_texture.get_height())
	
	_tooltip_text = tooltip_text
	tooltip_label.text = tooltip_text

	_populate_dice_chart(dice_chart, ability_chart_rows, active_zone)
	status_effects.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_badges(status_effects, status_list, "STATUS")
	gear_title.visible = false
	gear_slots.visible = false
	_apply_ability_sheet_style(dice_chart_panel)
	_apply_visual_state(card_frame, portrait_frame, portrait, hp_bar, current_hp, max_hp, is_dead, accent_color, active_zone)
	_hide_tooltip()


func set_selected(is_selected: bool) -> void:
	_apply_highlight_state(is_selected, false)


func set_targetable(is_targetable: bool) -> void:
	_apply_highlight_state(false, is_targetable)


func set_interaction_enabled(is_enabled: bool) -> void:
	var click_button: Button = get_node("ClickButton")
	click_button.disabled = not is_enabled
	click_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_enabled else Control.CURSOR_ARROW
	var card_frame: Panel = get_node("CardFrame")
	card_frame.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_enabled else Control.CURSOR_ARROW


func _apply_highlight_state(is_selected: bool, is_targetable: bool) -> void:
	var card_frame: Panel = get_node("CardFrame")
	var existing_style: StyleBoxFlat = card_frame.get_theme_stylebox("panel") as StyleBoxFlat
	if existing_style == null:
		return
	var style: StyleBoxFlat = existing_style.duplicate() as StyleBoxFlat
	style.shadow_size = 0
	if is_selected:
		style.border_color = PixelUI.GOLD_ACCENT
		style.shadow_color = PixelUI.BLACK_EDGE
		style.shadow_size = 0
	elif is_targetable:
		style.border_color = Color(0.48, 0.68, 0.88, 1.0)
		style.shadow_color = PixelUI.BLACK_EDGE
		style.shadow_size = 0
	card_frame.add_theme_stylebox_override("panel", style)


func _populate_dice_chart(container: VBoxContainer, rows: Array, active_zone: String) -> void:
	for child in container.get_children():
		child.queue_free()

	container.add_theme_constant_override("separation", 5)
	var active_row: Dictionary = {}

	var range_strip: HBoxContainer = HBoxContainer.new()
	range_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	range_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	range_strip.add_theme_constant_override("separation", 3)
	container.add_child(range_strip)

	for row_variant in rows:
		var row_data: Dictionary = row_variant
		var is_active_row: bool = str(row_data.get("zone", "")) == active_zone
		if is_active_row:
			active_row = row_data

		var range_tab: Label = _make_range_tab(row_data, is_active_row)
		range_strip.add_child(range_tab)

	var detail_panel: PanelContainer = PanelContainer.new()
	detail_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	detail_panel.custom_minimum_size = Vector2(0, 52)
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", _make_detail_panel_style(not active_row.is_empty()))
	container.add_child(detail_panel)

	var detail_margin: MarginContainer = MarginContainer.new()
	detail_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	detail_margin.add_theme_constant_override("margin_left", 8)
	detail_margin.add_theme_constant_override("margin_top", 7)
	detail_margin.add_theme_constant_override("margin_right", 8)
	detail_margin.add_theme_constant_override("margin_bottom", 1)
	detail_panel.add_child(detail_margin)

	if active_row.is_empty():
		return

	var detail_row: HBoxContainer = HBoxContainer.new()
	detail_row.mouse_filter = Control.MOUSE_FILTER_PASS
	detail_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_row.add_theme_constant_override("separation", 8)
	detail_row.alignment = BoxContainer.ALIGNMENT_CENTER
	detail_margin.add_child(detail_row)

	var name_label: Label = Label.new()
	name_label.text = str(active_row.get("ability_name", "Ability"))
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size = Vector2(112, 0)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	PixelUI.style_label(name_label, 26, PixelUI.TEXT_PRIMARY, 3)
	detail_row.add_child(name_label)

	var chip_flow: HFlowContainer = HFlowContainer.new()
	chip_flow.mouse_filter = Control.MOUSE_FILTER_PASS
	chip_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip_flow.set("alignment", 2)
	chip_flow.add_theme_constant_override("h_separation", 5)
	chip_flow.add_theme_constant_override("v_separation", 4)
	detail_row.add_child(chip_flow)

	_add_effect_chips_to_flow(chip_flow, active_row.get("chips", []), Vector2(0, 34), Vector2(24, 24), 26)


func _make_range_tab(row_data: Dictionary, is_active_row: bool) -> Label:
	var range_label: Label = Label.new()
	range_label.text = str(row_data.get("range_text", ""))
	range_label.tooltip_text = _get_ability_row_tooltip(row_data)
	range_label.mouse_filter = Control.MOUSE_FILTER_PASS
	range_label.custom_minimum_size = Vector2(0, 30)
	range_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	range_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	range_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUI.apply_pixel_font(range_label)
	range_label.add_theme_font_size_override("font_size", 22)
	range_label.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0, 1.0) if is_active_row else PixelUI.TEXT_MUTED)
	range_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	range_label.add_theme_constant_override("outline_size", 3)
	range_label.add_theme_stylebox_override("normal", _make_range_tab_style(is_active_row))
	return range_label


func _place_hp_label_in_bar(hp_label: Label, hp_bar: ProgressBar) -> void:
	if hp_label == null or hp_bar == null:
		return
	if hp_label.get_parent() != hp_bar:
		var old_parent: Node = hp_label.get_parent()
		if old_parent != null:
			old_parent.remove_child(hp_label)
		hp_bar.add_child(hp_label)
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_label.offset_left = 8.0
	hp_label.offset_right = -6.0
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_label.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _place_hp_row_above_target(hp_bar: ProgressBar, target_label: Label) -> void:
	if hp_bar == null or target_label == null:
		return
	var hp_row: Control = hp_bar.get_parent() as Control
	var vbox: VBoxContainer = get_node_or_null("CardFrame/Margin/VBox") as VBoxContainer
	if hp_row == null or vbox == null:
		return
	if hp_row.get_parent() != vbox:
		var old_parent: Node = hp_row.get_parent()
		if old_parent != null:
			old_parent.remove_child(hp_row)
		vbox.add_child(hp_row)
	elif hp_row.get_index() < target_label.get_index():
		hp_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return
	vbox.move_child(hp_row, target_label.get_index())
	hp_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _resolve_hp_bar() -> ProgressBar:
	var hp_bar: ProgressBar = get_node_or_null("%HPBar") as ProgressBar
	if hp_bar != null:
		return hp_bar
	hp_bar = find_child("HPBar", true, false) as ProgressBar
	if hp_bar != null:
		return hp_bar
	return get_node_or_null("CardFrame/Margin/VBox/HPRow/HPBar") as ProgressBar


func _resolve_hp_label(hp_bar: ProgressBar) -> Label:
	var hp_label: Label = get_node_or_null("%HPLabel") as Label
	if hp_label != null:
		return hp_label
	hp_label = find_child("HPLabel", true, false) as Label
	if hp_label != null:
		return hp_label
	hp_label = get_node_or_null("CardFrame/Margin/VBox/HPLabel") as Label
	if hp_label != null:
		return hp_label
	if hp_bar != null:
		hp_label = hp_bar.get_node_or_null("HPLabel") as Label
		if hp_label != null:
			return hp_label
		hp_label = Label.new()
		hp_label.name = "HPLabel"
		hp_label.unique_name_in_owner = true
		hp_bar.add_child(hp_label)
	return hp_label


func _wire_card_frame_input() -> void:
	var click_button: Button = get_node_or_null("ClickButton") as Button
	if click_button != null:
		click_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var card_frame: Panel = get_node_or_null("CardFrame") as Panel
	if card_frame == null:
		return
	card_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	if not card_frame.gui_input.is_connected(_on_card_frame_gui_input):
		card_frame.gui_input.connect(_on_card_frame_gui_input)
	_make_descendants_pass_mouse(card_frame)


func _make_descendants_pass_mouse(node: Node) -> void:
	for child in node.get_children():
		var control: Control = child as Control
		if control != null:
			control.mouse_filter = Control.MOUSE_FILTER_PASS
		_make_descendants_pass_mouse(child)


func _on_card_frame_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_on_click_button_down()
		else:
			_on_click_button_up()
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event
		if touch_event.pressed:
			_on_click_button_down()
		else:
			_on_click_button_up()


func _make_range_tab_style(is_active_row: bool) -> StyleBoxFlat:
	var range_style: StyleBoxFlat = StyleBoxFlat.new()
	range_style.bg_color = Color(0.08, 0.13, 0.18, 0.46)
	range_style.border_color = Color(0.18, 0.34, 0.50, 0.72)
	range_style.set_border_width_all(2)
	range_style.corner_radius_top_left = 0
	range_style.corner_radius_top_right = 0
	range_style.corner_radius_bottom_left = 0
	range_style.corner_radius_bottom_right = 0
	if is_active_row:
		range_style.bg_color = Color(0.13, 0.23, 0.34, 0.62)
		range_style.border_color = Color(0.46, 0.68, 0.88, 0.86)
		range_style.set_border_width_all(2)
	return range_style


func _make_detail_panel_style(has_active_row: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.090, 0.130, 0.54) if has_active_row else Color(0.030, 0.050, 0.075, 0.32)
	style.border_color = Color(0.42, 0.62, 0.78, 0.76) if has_active_row else Color(0.16, 0.28, 0.42, 0.55)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.set_content_margin(SIDE_LEFT, 0.0)
	style.set_content_margin(SIDE_TOP, 0.0)
	style.set_content_margin(SIDE_RIGHT, 0.0)
	style.set_content_margin(SIDE_BOTTOM, 0.0)
	return style


func _get_ability_row_tooltip(row_data: Dictionary) -> String:
	var parts: Array = [str(row_data.get("range_text", "")), str(row_data.get("ability_name", ""))]
	var chip_texts: Array = []
	for chip_variant in row_data.get("chips", []):
		var chip: Dictionary = chip_variant
		var icon_kind: String = _get_chip_icon_kind(chip)
		var label: String = _get_chip_value_text(chip)
		if icon_kind != "":
			chip_texts.append("%s %s" % [icon_kind.capitalize(), label])
		elif label != "":
			chip_texts.append(label)
	if not chip_texts.is_empty():
		parts.append("  ".join(chip_texts))
	return " | ".join(parts)


func _add_effect_chips_to_flow(chip_flow: HFlowContainer, chips: Array, chip_size: Vector2, icon_size: Vector2, font_size: int) -> void:
	if chips.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "-"
		empty_label.mouse_filter = Control.MOUSE_FILTER_PASS
		empty_label.modulate = Color(0.44, 0.50, 0.60, 0.9)
		chip_flow.add_child(empty_label)
		return

	for chip_variant in chips:
		var chip: Dictionary = chip_variant
		var chip_style: StyleBoxFlat = StyleBoxFlat.new()
		var chip_base_color: Color = chip.get("color", Color(0.24, 0.28, 0.36, 0.98))
		chip_style.bg_color = _flatten_chip_color(chip_base_color)
		chip_style.border_color = PixelUI.BLACK_EDGE
		chip_style.set_border_width_all(2)
		chip_style.corner_radius_top_left = 0
		chip_style.corner_radius_top_right = 0
		chip_style.corner_radius_bottom_left = 0
		chip_style.corner_radius_bottom_right = 0
		chip_style.set_content_margin(SIDE_LEFT, 6.0)
		chip_style.set_content_margin(SIDE_TOP, 3.0)
		chip_style.set_content_margin(SIDE_RIGHT, 6.0)
		chip_style.set_content_margin(SIDE_BOTTOM, 3.0)

		var chip_panel: PanelContainer = PanelContainer.new()
		chip_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		chip_panel.custom_minimum_size = Vector2(0, chip_size.y)
		chip_panel.add_theme_stylebox_override("panel", chip_style)
		chip_flow.add_child(chip_panel)

		var chip_row: HBoxContainer = HBoxContainer.new()
		chip_row.mouse_filter = Control.MOUSE_FILTER_PASS
		chip_row.alignment = BoxContainer.ALIGNMENT_CENTER
		chip_row.add_theme_constant_override("separation", 4)
		chip_panel.add_child(chip_row)

		var icon_kind: String = _get_chip_icon_kind(chip)
		if icon_kind != "":
			var icon_rect: TextureRect = TextureRect.new()
			icon_rect.mouse_filter = Control.MOUSE_FILTER_PASS
			icon_rect.custom_minimum_size = icon_size
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon_rect.texture = _get_icon_texture(icon_kind, _get_chip_icon_color(chip))
			chip_row.add_child(icon_rect)

		var value_label: Label = Label.new()
		value_label.text = _get_chip_value_text(chip)
		value_label.mouse_filter = Control.MOUSE_FILTER_PASS
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		PixelUI.apply_pixel_font(value_label)
		value_label.add_theme_font_size_override("font_size", font_size)
		value_label.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0, 1.0))
		value_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
		value_label.add_theme_constant_override("outline_size", 3)
		chip_row.add_child(value_label)


func _populate_badges(container: Container, values: Array, empty_text: String) -> void:
	for child in container.get_children():
		child.queue_free()
	container.set("alignment", 2)

	if values.is_empty():
		return

	for value in values:
		var value_text: String = str(value)
		var badge: PanelContainer = PanelContainer.new()
		badge.custom_minimum_size = Vector2(84, 32)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.corner_radius_top_left = 0
		style.corner_radius_top_right = 0
		style.corner_radius_bottom_left = 0
		style.corner_radius_bottom_right = 0
		style.set_border_width_all(2)
		style.border_color = PixelUI.BLACK_EDGE
		style.bg_color = _get_badge_color(value_text, empty_text)
		badge.add_theme_stylebox_override("panel", style)

		var row: HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 4)
		badge.add_child(row)

		var icon_kind: String = _get_status_icon_kind(value_text, empty_text)
		if icon_kind != "":
			var icon_rect: TextureRect = TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(18, 18)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon_rect.texture = _get_icon_texture(icon_kind, _get_badge_font_color(value_text, empty_text))
			row.add_child(icon_rect)

		var text_label: Label = Label.new()
		text_label.text = _format_badge_text(value_text, empty_text)
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		PixelUI.apply_pixel_font(text_label)
		text_label.add_theme_font_size_override("font_size", 22)
		text_label.add_theme_color_override("font_color", _get_badge_font_color(value_text, empty_text))
		text_label.add_theme_constant_override("outline_size", 3)
		text_label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.07, 0.95))
		row.add_child(text_label)
		container.add_child(badge)


func _apply_ability_sheet_style(panel: PanelContainer) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.020, 0.038, 0.060, 0.46)
	style.border_color = Color(0.12, 0.24, 0.36, 0.58)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.set_content_margin(SIDE_LEFT, 0.0)
	style.set_content_margin(SIDE_TOP, 3.0)
	style.set_content_margin(SIDE_RIGHT, 0.0)
	style.set_content_margin(SIDE_BOTTOM, 3.0)
	panel.add_theme_stylebox_override("panel", style)


func _apply_visual_state(card_frame: Panel, portrait_frame: PanelContainer, portrait: TextureRect, hp_bar: ProgressBar, current_hp: int, max_hp: int, is_dead: bool, accent_color: Color, active_zone: String) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.026, 0.044, 0.066, 0.68)
	style.border_color = accent_color.lightened(0.12)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.shadow_color = PixelUI.BLACK_EDGE
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	card_frame.add_theme_stylebox_override("panel", style)

	var portrait_style: StyleBoxFlat = StyleBoxFlat.new()
	portrait_style.bg_color = Color(0.018, 0.030, 0.050, 0.62)
	portrait_style.border_color = accent_color.lightened(0.12)
	portrait_style.set_border_width_all(2)
	portrait_style.corner_radius_top_left = 0
	portrait_style.corner_radius_top_right = 0
	portrait_style.corner_radius_bottom_left = 0
	portrait_style.corner_radius_bottom_right = 0
	portrait_frame.add_theme_stylebox_override("panel", portrait_style)

	portrait.modulate = Color(1, 1, 1, 1) if portrait.texture != null else accent_color.darkened(0.18)
	modulate = Color(1, 1, 1, 1)
	var hp_fill: Color = Color(0.20, 0.62, 0.40, 1)
	var xp_bar: ProgressBar = get_node("%XPBar")
	PixelUI.style_progress_bar(xp_bar, Color(0.35, 0.68, 1.0, 1), Color(0.015, 0.020, 0.035, 1.0), Color(0.18, 0.28, 0.42, 1.0))

	if max_hp > 0 and float(current_hp) / float(max_hp) <= LOW_HP_THRESHOLD:
		hp_fill = Color(0.90, 0.30, 0.28, 1)

	if is_dead:
		modulate = Color(0.48, 0.48, 0.54, 0.92)
		portrait.modulate = Color(0.40, 0.40, 0.44, 0.95)
		hp_fill = Color(0.36, 0.38, 0.44, 1)
	PixelUI.style_progress_bar(hp_bar, hp_fill, Color(0.015, 0.020, 0.035, 1.0), Color(0.18, 0.28, 0.42, 1.0))


func _on_click_button_down() -> void:
	_hold_triggered = false
	var hold_timer: Timer = get_node("HoldTimer")
	hold_timer.start()


func _on_click_button_up() -> void:
	var hold_timer: Timer = get_node("HoldTimer")
	hold_timer.stop()
	if _hold_triggered:
		_hide_tooltip()
		return
	card_pressed.emit()


func _on_click_button_mouse_exited() -> void:
	var hold_timer: Timer = get_node("HoldTimer")
	hold_timer.stop()
	if _hold_triggered:
		_hide_tooltip()


func _on_hold_timer_timeout() -> void:
	if _tooltip_text == "":
		return
	_hold_triggered = true
	_show_tooltip()


func _get_badge_color(value_text: String, empty_text: String) -> Color:
	if empty_text == "GEAR":
		return Color(0.20, 0.23, 0.36, 0.98)
	# Shield
	if value_text.begins_with("SH"):
		return Color(0.16, 0.34, 0.50, 0.98)
	# Poison / DoT
	if value_text.begins_with("POI"):
		return Color(0.36, 0.14, 0.36, 0.98)
	# Roll debuff (RFE)
	if value_text.begins_with("RFE"):
		return Color(0.44, 0.28, 0.08, 0.98)
	# Roll buff ("+N ROLL")
	if value_text.begins_with("+"):
		return Color(0.12, 0.36, 0.20, 0.98)
	# Cloak / evasion
	if value_text == "CLOAK":
		return Color(0.10, 0.26, 0.38, 0.98)
	# Cower (stunned / can't act)
	if value_text.begins_with("COWER"):
		return Color(0.30, 0.24, 0.14, 0.98)
	# Frozen die
	if value_text.begins_with("FROZEN"):
		return Color(0.12, 0.30, 0.46, 0.98)
	# Rampage charges
	if value_text.begins_with("RAGE"):
		return Color(0.44, 0.10, 0.10, 0.98)
	# Cursed (rolls twice, keeps lower)
	if value_text == "CURSED":
		return Color(0.26, 0.12, 0.36, 0.98)
	# Taunt (forces hero targeting)
	if value_text == "TAUNT":
		return Color(0.44, 0.22, 0.06, 0.98)
	# Counter chance
	if value_text.begins_with("CNTR"):
		return Color(0.18, 0.34, 0.14, 0.98)
	# Boss phase 2
	if value_text == "PHASE 2":
		return Color(0.44, 0.16, 0.04, 0.98)
	# Down / eliminated
	if value_text == "DOWN":
		return Color(0.34, 0.24, 0.24, 0.98)
	return Color(0.22, 0.28, 0.34, 0.98)


func _get_badge_font_color(value_text: String, empty_text: String) -> Color:
	if empty_text == "GEAR":
		return Color(0.95, 0.97, 1.0, 1.0)
	if value_text.begins_with("SH"):
		return Color(0.88, 0.96, 1.0, 1.0)
	if value_text.begins_with("POI"):
		return Color(1.0, 0.82, 1.0, 1.0)
	if value_text.begins_with("RFE"):
		return Color(1.0, 0.88, 0.62, 1.0)
	if value_text.begins_with("+"):
		return Color(0.80, 1.0, 0.82, 1.0)
	if value_text == "CLOAK":
		return Color(0.72, 0.96, 1.0, 1.0)
	if value_text.begins_with("COWER"):
		return Color(1.0, 0.94, 0.72, 1.0)
	if value_text.begins_with("FROZEN"):
		return Color(0.84, 0.96, 1.0, 1.0)
	if value_text.begins_with("RAGE"):
		return Color(1.0, 0.78, 0.78, 1.0)
	if value_text == "CURSED":
		return Color(0.90, 0.72, 1.0, 1.0)
	if value_text == "TAUNT":
		return Color(1.0, 0.86, 0.68, 1.0)
	if value_text.begins_with("CNTR"):
		return Color(0.84, 1.0, 0.76, 1.0)
	if value_text == "PHASE 2":
		return Color(1.0, 0.80, 0.60, 1.0)
	if value_text == "DOWN":
		return Color(1.0, 0.90, 0.90, 1.0)
	return Color(0.92, 0.95, 1.0, 1.0)


func _get_badge_border_color(value_text: String, empty_text: String) -> Color:
	if empty_text == "GEAR":
		return Color(0.60, 0.72, 0.94, 0.95)
	if value_text.begins_with("SH"):
		return Color(0.58, 0.84, 1.0, 0.95)
	if value_text.begins_with("POI"):
		return Color(0.90, 0.52, 0.90, 0.95)
	if value_text.begins_with("RFE"):
		return Color(1.0, 0.72, 0.28, 0.95)
	if value_text.begins_with("+"):
		return Color(0.52, 1.0, 0.64, 0.95)
	if value_text == "CLOAK":
		return Color(0.44, 0.92, 1.0, 0.95)
	if value_text.begins_with("COWER"):
		return Color(0.86, 0.76, 0.48, 0.95)
	if value_text.begins_with("FROZEN"):
		return Color(0.64, 0.92, 1.0, 0.95)
	if value_text.begins_with("RAGE"):
		return Color(1.0, 0.44, 0.44, 0.95)
	if value_text == "CURSED":
		return Color(0.76, 0.44, 1.0, 0.95)
	if value_text == "TAUNT":
		return Color(1.0, 0.60, 0.26, 0.95)
	if value_text.begins_with("CNTR"):
		return Color(0.56, 1.0, 0.48, 0.95)
	if value_text == "PHASE 2":
		return Color(1.0, 0.52, 0.22, 0.95)
	if value_text == "DOWN":
		return Color(0.92, 0.64, 0.64, 0.95)
	return Color(0.76, 0.84, 0.94, 0.95)


func _format_badge_text(value_text: String, empty_text: String) -> String:
	if empty_text == "GEAR":
		return _shorten_gear_name(value_text)
	if value_text.begins_with("SH"):
		return value_text.substr(2).strip_edges()
	if value_text.begins_with("POI"):
		return value_text.substr(3).strip_edges()
	if value_text.begins_with("RFE"):
		return value_text.substr(3).strip_edges()
	if value_text.begins_with("+") and value_text.contains("ROLL"):
		return value_text.replace("ROLL", "").strip_edges()
	if value_text.begins_with("FROZEN"):
		return value_text.substr(6).strip_edges()
	return value_text


func _get_status_icon_kind(value_text: String, empty_text: String) -> String:
	if empty_text == "GEAR":
		return ""
	if value_text.begins_with("SH"):
		return "shield"
	if value_text.begins_with("POI") or value_text == "DOWN":
		return "dot"
	if value_text.begins_with("RFE") or (value_text.begins_with("+") and value_text.contains("ROLL")):
		return "dice"
	if value_text.begins_with("FROZEN"):
		return "frost"
	return ""


func _get_empty_row_text(empty_text: String) -> String:
	if empty_text == "GEAR":
		return "No gear"
	return "No status"


func _shorten_gear_name(gear_name: String) -> String:
	if gear_name.length() <= 12:
		return gear_name
	var words: PackedStringArray = gear_name.split(" ")
	if words.size() >= 2:
		return "%s %s" % [words[0], words[1].left(3)]
	return gear_name.left(12)


func _show_tooltip() -> void:
	var tooltip_panel: PanelContainer = get_node("TooltipPanel")
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.075, 0.98)
	style.border_color = PixelUI.BLACK_EDGE
	style.set_border_width_all(3)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	tooltip_panel.add_theme_stylebox_override("panel", style)
	tooltip_panel.visible = true
	tooltip_panel.move_to_front()


func _hide_tooltip() -> void:
	var tooltip_panel: PanelContainer = get_node("TooltipPanel")
	tooltip_panel.visible = false
	_hold_triggered = false


func _apply_editor_preview_theme() -> void:
	var portrait: TextureRect = get_node("%Portrait")
	var portrait_frame: Control = get_node("%PortraitFrame")
	var hp_bar: ProgressBar = _resolve_hp_bar()
	var card_frame: Panel = get_node("CardFrame")
	var dice_chart_panel: PanelContainer = get_node("CardFrame/Margin/VBox/DiceChartPanel")
	var dice_chart: VBoxContainer = get_node("%DiceChart")
	var status_effects: Container = get_node("%StatusEffects")
	var gear_slots: Container = get_node("%GearSlots")
	var gear_title: Label = get_node("%GearTitle")
	var tooltip_panel: PanelContainer = get_node("TooltipPanel")

	_apply_visual_state(card_frame, portrait_frame, portrait, hp_bar, 40, 40, false, Color(0.26, 0.78, 0.66, 1.0), "strike")
	_apply_ability_sheet_style(dice_chart_panel)
	_style_preview_dice_chart(dice_chart)
	_style_preview_badges(status_effects, "STATUS")
	gear_title.visible = false
	gear_slots.visible = false

	var tooltip_style: StyleBoxFlat = StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.035, 0.045, 0.075, 0.98)
	tooltip_style.border_color = PixelUI.BLACK_EDGE
	tooltip_style.set_border_width_all(3)
	tooltip_style.corner_radius_top_left = 0
	tooltip_style.corner_radius_top_right = 0
	tooltip_style.corner_radius_bottom_left = 0
	tooltip_style.corner_radius_bottom_right = 0
	tooltip_panel.add_theme_stylebox_override("panel", tooltip_style)
	tooltip_panel.visible = false


func _fit_name_label(name_label: Label, display_name: String) -> void:
	PixelUI.apply_pixel_font(name_label)
	var font_size: int = 30
	if display_name.length() >= 18:
		font_size = 24
	elif display_name.length() >= 14:
		font_size = 26
	name_label.add_theme_font_size_override("font_size", font_size)


func _style_preview_dice_chart(container: VBoxContainer) -> void:
	for row_variant in container.get_children():
		var row: HBoxContainer = row_variant as HBoxContainer
		if row == null:
			continue
		var range_label: Label = row.get_child(0) as Label
		if range_label != null:
			range_label.custom_minimum_size = Vector2(64, 22)
			PixelUI.apply_pixel_font(range_label)
			range_label.add_theme_color_override("font_color", Color(0.90, 0.94, 1.0, 1.0))
			range_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
			range_label.add_theme_constant_override("outline_size", 3)
			var range_style: StyleBoxFlat = StyleBoxFlat.new()
			range_style.bg_color = Color(0.10, 0.13, 0.18, 1.0)
			range_style.border_color = PixelUI.BLACK_EDGE
			range_style.set_border_width_all(2)
			range_style.corner_radius_top_left = 0
			range_style.corner_radius_top_right = 0
			range_style.corner_radius_bottom_left = 0
			range_style.corner_radius_bottom_right = 0
			range_label.add_theme_stylebox_override("normal", range_style)

		var chip_row: Container = row.get_child(1) as Container
		if chip_row == null:
			continue
		for chip_variant in chip_row.get_children():
			var chip_label: Label = chip_variant as Label
			if chip_label == null:
				continue
			chip_label.custom_minimum_size = Vector2(58, 24)
			PixelUI.apply_pixel_font(chip_label)
			chip_label.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0, 1.0))
			chip_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
			chip_label.add_theme_constant_override("outline_size", 3)
			var chip_style: StyleBoxFlat = StyleBoxFlat.new()
			if chip_label.text.contains(ICON_DAMAGE) or chip_label.text.begins_with("DMG"):
				chip_style.bg_color = _flatten_chip_color(CHIP_DAMAGE_BG)
			elif chip_label.text.begins_with("SH"):
				chip_style.bg_color = _flatten_chip_color(CHIP_SHIELD_BG)
			elif chip_label.text.contains(ICON_DOT) or chip_label.text.begins_with("DOT"):
				chip_style.bg_color = _flatten_chip_color(CHIP_DOT_BG)
			elif chip_label.text.contains(ICON_HEAL) or chip_label.text.begins_with("HEAL"):
				chip_style.bg_color = _flatten_chip_color(CHIP_HEAL_BG)
			else:
				chip_style.bg_color = _flatten_chip_color(CHIP_DICE_BG)
			chip_style.border_color = PixelUI.BLACK_EDGE
			chip_style.set_border_width_all(2)
			chip_style.corner_radius_top_left = 0
			chip_style.corner_radius_top_right = 0
			chip_style.corner_radius_bottom_left = 0
			chip_style.corner_radius_bottom_right = 0
			chip_label.add_theme_stylebox_override("normal", chip_style)


func _style_preview_badges(container: Container, badge_type: String) -> void:
	for child_variant in container.get_children():
		var badge: Label = child_variant as Label
		if badge == null:
			continue
		PixelUI.apply_pixel_font(badge)
		badge.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.07, 0.95))
		badge.add_theme_constant_override("outline_size", 3)
		badge.add_theme_color_override("font_color", _get_badge_font_color(badge.text, badge_type))
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.corner_radius_top_left = 0
		style.corner_radius_top_right = 0
		style.corner_radius_bottom_left = 0
		style.corner_radius_bottom_right = 0
		style.set_border_width_all(2)
		style.border_color = PixelUI.BLACK_EDGE
		style.bg_color = _get_badge_color(badge.text, badge_type)
		badge.add_theme_stylebox_override("normal", style)


func _get_chip_icon_kind(chip: Dictionary) -> String:
	var raw_text: String = str(chip.get("text", "")).strip_edges()
	var bg: Color = chip.get("color", Color(0.24, 0.28, 0.36, 0.98))
	if raw_text == "A" or raw_text == "ALL" or raw_text == "T":
		return ""
	if raw_text.begins_with("-"):
		return "dice"
	if bg.is_equal_approx(CHIP_HEAL_BG):
		return "heal"
	if bg.is_equal_approx(CHIP_SHIELD_BG):
		return "shield"
	if bg.is_equal_approx(CHIP_DOT_BG):
		return "dot"
	if bg.is_equal_approx(CHIP_DAMAGE_BG):
		return "damage"
	return ""


func _get_chip_value_text(chip: Dictionary) -> String:
	return str(chip.get("text", "")).strip_edges()


func _get_chip_icon_color(chip: Dictionary) -> Color:
	var raw_text: String = str(chip.get("text", "")).strip_edges()
	var bg: Color = chip.get("color", Color(0.24, 0.28, 0.36, 0.98))
	if raw_text.begins_with("-"):
		return Color(0.98, 0.90, 0.62, 1.0)
	if bg.is_equal_approx(CHIP_HEAL_BG):
		return Color(0.72, 1.0, 0.78, 1.0)
	if bg.is_equal_approx(CHIP_SHIELD_BG):
		return Color(0.82, 0.94, 1.0, 1.0)
	if bg.is_equal_approx(CHIP_DOT_BG):
		return Color(0.78, 0.56, 1.0, 1.0)
	if bg.is_equal_approx(CHIP_DAMAGE_BG):
		return Color(1.0, 0.44, 0.38, 1.0)
	return Color(0.97, 0.98, 1.0, 1.0)


func _flatten_chip_color(color: Color) -> Color:
	return Color(
		clampf(color.r * 0.72, 0.0, 1.0),
		clampf(color.g * 0.72, 0.0, 1.0),
		clampf(color.b * 0.72, 0.0, 1.0),
		1.0
	)


func _get_icon_texture(icon_kind: String, _tint: Color) -> Texture2D:
	return ICON_MAP.get(icon_kind)
