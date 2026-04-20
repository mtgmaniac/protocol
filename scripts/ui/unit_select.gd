# Launch roster picker that lets the player choose a three-unit squad.
extends Control

const DEFAULT_OPERATION_ID := "facility"
const MAX_SELECTED_UNITS := 3
const LOGO_WIDTH_RATIO := 0.72
const LOGO_ASPECT := 425.0 / 711.0
const UNIT_CARD_HEIGHT := 196
const UNIT_PORTRAIT_SIZE := Vector2(132, 160)
const HOLD_TO_DETAILS_SECONDS := 0.5
const SUMMARY_FONT_SIZE := 34
const OPERATION_TITLE_FONT_SIZE := 52
const OPERATION_SECTION_FONT_SIZE := 30
const OPERATION_BUTTON_FONT_SIZE := 32
const OPERATION_BLURB_FONT_SIZE := 30
const UNIT_NAME_FONT_SIZE := 34
const UNIT_META_FONT_SIZE := 25
const UNIT_BLURB_FONT_SIZE := 24
const UNIT_PICK_FONT_SIZE := 22
const FOOTER_BUTTON_FONT_SIZE := 38

@onready var summary_label: Label = %SummaryLabel
@onready var hero_list: GridContainer = %HeroList
@onready var continue_button: Button = %ContinueButton
@onready var background: ColorRect = $Background
@onready var logo_panel: PanelContainer = $Content/VBox/LogoPanel
@onready var logo_image: TextureRect = %LogoImage
@onready var title_label: Label = $Content/VBox/Title
@onready var operation_panel: PanelContainer = $Content/VBox/OperationPanel
@onready var operation_title: Label = %OperationTitle
@onready var operation_section_label: Label = %OperationSectionLabel
@onready var operation_buttons: GridContainer = %OperationButtons
@onready var operation_blurb_label: Label = %OperationBlurbLabel
@onready var random_button: Button = %RandomButton

var selected_unit_ids: Array = []
var selection_controls: Dictionary = {}
var operation_button_by_id: Dictionary = {}
var operation_ids: Array = []
var selected_operation_id: String = DEFAULT_OPERATION_ID
var _unit_detail_overlay: Control = null
var _unit_detail_title: Label = null
var _unit_detail_role: Label = null
var _unit_detail_blurb: Label = null
var _unit_detail_portrait: TextureRect = null
var _unit_detail_abilities: VBoxContainer = null
var _portrait_hold_timers: Dictionary = {}
var _portrait_hold_pressed: Dictionary = {}
var _portrait_hold_triggered: Dictionary = {}


func _ready() -> void:
	_apply_visual_theme()
	_populate_operation_buttons()
	_build_hero_list()
	_refresh_summary()
	resized.connect(_update_logo_size)
	call_deferred("_update_logo_size")


func _build_unit_detail_overlay() -> void:
	if _unit_detail_overlay != null:
		return
	_unit_detail_overlay = Control.new()
	_unit_detail_overlay.name = "UnitDetailOverlay"
	_unit_detail_overlay.visible = false
	_unit_detail_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_unit_detail_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_unit_detail_overlay.z_as_relative = false
	_unit_detail_overlay.z_index = 120
	_unit_detail_overlay.gui_input.connect(_on_unit_detail_overlay_input)
	add_child(_unit_detail_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.004, 0.006, 0.012, 0.76)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_unit_detail_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_unit_detail_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.custom_minimum_size = Vector2(960, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	PixelUI.style_panel(panel, Color(0.020, 0.034, 0.052, 0.98), PixelUI.LINE_BRIGHT, 3, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	content.add_child(header)

	_unit_detail_portrait = TextureRect.new()
	_unit_detail_portrait.custom_minimum_size = Vector2(132, 160)
	_unit_detail_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_unit_detail_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_unit_detail_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_unit_detail_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_unit_detail_portrait)

	var header_text := VBoxContainer.new()
	header_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_text)

	_unit_detail_title = _make_detail_label("", 42, PixelUI.TEXT_PRIMARY)
	header_text.add_child(_unit_detail_title)
	_unit_detail_role = _make_detail_label("", 28, PixelUI.HERO_ACCENT)
	header_text.add_child(_unit_detail_role)
	_unit_detail_blurb = _make_detail_label("", 24, PixelUI.TEXT_MUTED)
	_unit_detail_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_unit_detail_blurb.max_lines_visible = 3
	header_text.add_child(_unit_detail_blurb)

	var divider := ColorRect.new()
	divider.color = PixelUI.LINE_DIM
	divider.custom_minimum_size = Vector2(0, 2)
	content.add_child(divider)

	_unit_detail_abilities = VBoxContainer.new()
	_unit_detail_abilities.add_theme_constant_override("separation", 10)
	content.add_child(_unit_detail_abilities)

	var hint := _make_detail_label("Tap anywhere to close", 24, PixelUI.TEXT_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)


func _build_hero_list() -> void:
	for child in hero_list.get_children():
		child.queue_free()
	selection_controls.clear()
	_portrait_hold_timers.clear()
	_portrait_hold_pressed.clear()
	_portrait_hold_triggered.clear()

	var sorted_ids: Array = DataManager.units.keys()
	sorted_ids.sort()

	for unit_id in sorted_ids:
		var unit: UnitData = DataManager.get_unit(unit_id) as UnitData
		if unit == null:
			continue

		hero_list.add_child(_create_unit_card(unit))


func _on_hero_toggled(toggled_on: bool, unit_id: String, button: Button, card: PanelContainer) -> void:
	if toggled_on:
		if selected_unit_ids.size() >= MAX_SELECTED_UNITS:
			button.set_pressed_no_signal(false)
			return
		selected_unit_ids.append(unit_id)
	else:
		selected_unit_ids.erase(unit_id)

	_apply_selection_state(card, button, toggled_on)
	_refresh_summary()


func _toggle_unit_selection(unit_id: String) -> void:
	var controls: Dictionary = selection_controls.get(unit_id, {})
	var card: PanelContainer = controls.get("card") as PanelContainer
	var pick_label: Label = controls.get("pick_label") as Label
	var is_selected := selected_unit_ids.has(unit_id)
	if is_selected:
		selected_unit_ids.erase(unit_id)
		_apply_selection_state(card, null, false, pick_label)
		_refresh_summary()
		return
	if selected_unit_ids.size() >= MAX_SELECTED_UNITS:
		return
	selected_unit_ids.append(unit_id)
	_apply_selection_state(card, null, true, pick_label)
	_refresh_summary()


func _refresh_summary() -> void:
	continue_button.disabled = selected_unit_ids.size() != MAX_SELECTED_UNITS
	summary_label.text = "SQUAD %d/%d" % [
		selected_unit_ids.size(),
		MAX_SELECTED_UNITS,
	]


func _on_continue_button_pressed() -> void:
	_start_selected_run()
	GameState.advance_to_next_battle()
	SceneManager.go_to_battle()


func _on_random_button_pressed() -> void:
	var available_ids: Array = DataManager.units.keys()
	available_ids.sort()
	available_ids.shuffle()

	selected_unit_ids.clear()
	for unit_id in selection_controls.keys():
		var controls: Dictionary = selection_controls[unit_id]
		var button: Button = controls.get("button") as Button
		var card: PanelContainer = controls.get("card") as PanelContainer
		var pick_label: Label = controls.get("pick_label") as Label
		if button != null:
			button.set_pressed_no_signal(false)
		if card != null:
			_apply_selection_state(card, button, false, pick_label)

	var picks: int = mini(MAX_SELECTED_UNITS, available_ids.size())
	for index in range(picks):
		var unit_id: String = str(available_ids[index])
		selected_unit_ids.append(unit_id)
		var controls: Dictionary = selection_controls.get(unit_id, {})
		var button: Button = controls.get("button") as Button
		var card: PanelContainer = controls.get("card") as PanelContainer
		var pick_label: Label = controls.get("pick_label") as Label
		if button != null:
			button.set_pressed_no_signal(true)
		if card != null:
			_apply_selection_state(card, button, true, pick_label)

	_refresh_summary()


func _populate_operation_buttons() -> void:
	for child in operation_buttons.get_children():
		child.queue_free()
	operation_button_by_id.clear()
	operation_ids = DataManager.get_operation_order()
	if operation_ids.is_empty():
		operation_ids.append(DEFAULT_OPERATION_ID)
	for operation_id_variant in operation_ids:
		var operation_id: String = str(operation_id_variant)
		var operation: OperationData = DataManager.get_operation(operation_id) as OperationData
		var label: String = operation.display_name if operation != null and operation.display_name != "" else operation_id
		var button := Button.new()
		button.text = _compact_operation_label(label)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(0, 90)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_operation_button_pressed.bind(operation_id))
		operation_buttons.add_child(button)
		operation_button_by_id[operation_id] = button
	selected_operation_id = DEFAULT_OPERATION_ID if operation_ids.has(DEFAULT_OPERATION_ID) else str(operation_ids[0])
	_select_operation(selected_operation_id)


func _on_operation_button_pressed(operation_id: String) -> void:
	_select_operation(operation_id)


func _select_operation(operation_id: String) -> void:
	selected_operation_id = operation_id
	for id_variant in operation_button_by_id.keys():
		var id := str(id_variant)
		var button: Button = operation_button_by_id[id] as Button
		if button == null:
			continue
		var is_selected := id == selected_operation_id
		button.set_pressed_no_signal(is_selected)
		_style_operation_button(button, is_selected)
	var operation: OperationData = DataManager.get_operation(operation_id) as OperationData
	if operation == null:
		operation_blurb_label.text = "Select an operation track."
		return
	operation_blurb_label.text = "%d battles // %s" % [
		operation.battles.size(),
		_build_operation_enemy_preview(operation),
	]


func _compact_operation_label(label: String) -> String:
	match label:
		"Facility sweep":
			return "Facility"
		"Hive incursion":
			return "Hive"
		"Stellar Menagerie":
			return "Menagerie"
	return label


func _style_operation_button(button: Button, selected: bool) -> void:
	if selected:
		PixelUI.style_button(button, Color(0.10, 0.18, 0.18, 0.98), PixelUI.HERO_ACCENT, OPERATION_BUTTON_FONT_SIZE)
	else:
		PixelUI.style_button(button, Color(0.018, 0.028, 0.044, 0.94), PixelUI.LINE_DIM, OPERATION_BUTTON_FONT_SIZE)


func _start_selected_run() -> void:
	GameState.start_run(selected_unit_ids, _get_selected_operation_id())


func _get_selected_operation_id() -> String:
	return selected_operation_id


func _build_operation_enemy_preview(operation: OperationData) -> String:
	var preview_names: Array = []
	for battle_variant in operation.battles:
		var battle: Dictionary = battle_variant
		var enemy_names: Array = battle.get("enemy_names", [])
		for enemy_name_variant in enemy_names:
			var enemy_name: String = str(enemy_name_variant)
			if not preview_names.has(enemy_name):
				preview_names.append(enemy_name)
			if preview_names.size() >= GameState.SQUAD_UNIT_LIMIT:
				return ", ".join(preview_names)
	return ", ".join(preview_names)


func _create_unit_card(unit: UnitData) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, UNIT_CARD_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUI.style_panel(card, Color(0.020, 0.034, 0.052, 0.90), PixelUI.LINE_DIM, 3, 0)
	card.gui_input.connect(_on_unit_card_gui_input.bind(unit.id))

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var portrait_frame: PanelContainer = PanelContainer.new()
	portrait_frame.custom_minimum_size = UNIT_PORTRAIT_SIZE
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait_frame.clip_contents = true
	PixelUI.style_panel(portrait_frame, Color(0.010, 0.018, 0.030, 0.96), PixelUI.LINE_BRIGHT, 2, 2)
	row.add_child(portrait_frame)

	var portrait: TextureRect = TextureRect.new()
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture = unit.portrait
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_frame.add_child(portrait)

	var info: VBoxContainer = VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)

	var name_label: Label = Label.new()
	name_label.text = unit.display_name
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	PixelUI.style_label(name_label, UNIT_NAME_FONT_SIZE, PixelUI.TEXT_PRIMARY, 2)
	info.add_child(name_label)

	var meta_label: Label = Label.new()
	meta_label.text = "%d HP // %s" % [unit.max_hp, unit.class_name_text]
	meta_label.clip_text = true
	meta_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	PixelUI.style_label(meta_label, UNIT_META_FONT_SIZE, PixelUI.HERO_ACCENT, 1)
	info.add_child(meta_label)

	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(spacer)

	var pick_label: Label = Label.new()
	pick_label.text = "TAP TO SELECT"
	pick_label.clip_text = true
	pick_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	PixelUI.style_label(pick_label, UNIT_PICK_FONT_SIZE, PixelUI.TEXT_MUTED, 1)
	info.add_child(pick_label)

	selection_controls[unit.id] = {"button": null, "card": card, "pick_label": pick_label}
	call_deferred("_wire_portrait_details_input", portrait_frame, unit)

	return card


func _on_unit_card_gui_input(event: InputEvent, unit_id: String) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_toggle_unit_selection(unit_id)
			accept_event()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_toggle_unit_selection(unit_id)
			accept_event()


func _apply_selection_state(card: PanelContainer, button: Button, is_selected: bool, pick_label: Label = null) -> void:
	if card == null:
		return
	if is_selected:
		PixelUI.style_panel(card, Color(0.040, 0.105, 0.105, 0.96), PixelUI.HERO_ACCENT, 4, 0)
		if button != null:
			button.text = "Selected"
			PixelUI.style_button(button, Color(0.10, 0.24, 0.19, 0.98), PixelUI.HERO_ACCENT, UNIT_PICK_FONT_SIZE)
		if pick_label != null:
			pick_label.text = "SELECTED"
			PixelUI.style_label(pick_label, UNIT_PICK_FONT_SIZE, PixelUI.HERO_ACCENT, 1)
		return
	PixelUI.style_panel(card, Color(0.020, 0.034, 0.052, 0.90), PixelUI.LINE_DIM, 3, 0)
	if button != null:
		button.text = "Select"
		PixelUI.style_button(button, PixelUI.BG_PANEL_ALT, PixelUI.HERO_ACCENT, UNIT_PICK_FONT_SIZE)
	if pick_label != null:
		pick_label.text = "TAP TO SELECT"
		PixelUI.style_label(pick_label, UNIT_PICK_FONT_SIZE, PixelUI.TEXT_MUTED, 1)


func _wire_portrait_details_input(portrait_frame: Control, unit: UnitData) -> void:
	var hold_timer := Timer.new()
	hold_timer.one_shot = true
	hold_timer.wait_time = HOLD_TO_DETAILS_SECONDS
	portrait_frame.add_child(hold_timer)
	var frame_id: int = portrait_frame.get_instance_id()
	_portrait_hold_timers[frame_id] = hold_timer
	_portrait_hold_pressed[frame_id] = false
	_portrait_hold_triggered[frame_id] = false
	hold_timer.timeout.connect(_on_portrait_hold_timeout.bind(portrait_frame, unit))
	portrait_frame.gui_input.connect(_on_portrait_gui_input.bind(portrait_frame, unit.id))
	portrait_frame.mouse_exited.connect(_on_portrait_mouse_exited.bind(portrait_frame))


func _on_portrait_gui_input(event: InputEvent, portrait_frame: Control, unit_id: String) -> void:
	var frame_id: int = portrait_frame.get_instance_id()
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_start_portrait_hold(frame_id)
		else:
			if not _finish_portrait_hold(frame_id):
				_toggle_unit_selection(unit_id)
		portrait_frame.accept_event()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_start_portrait_hold(frame_id)
		else:
			if not _finish_portrait_hold(frame_id):
				_toggle_unit_selection(unit_id)
		portrait_frame.accept_event()


func _start_portrait_hold(frame_id: int) -> void:
	_portrait_hold_pressed[frame_id] = true
	_portrait_hold_triggered[frame_id] = false
	var hold_timer: Timer = _portrait_hold_timers.get(frame_id) as Timer
	if hold_timer != null:
		hold_timer.start()


func _finish_portrait_hold(frame_id: int) -> bool:
	_portrait_hold_pressed[frame_id] = false
	var hold_timer: Timer = _portrait_hold_timers.get(frame_id) as Timer
	if hold_timer != null:
		hold_timer.stop()
	var triggered := bool(_portrait_hold_triggered.get(frame_id, false))
	if triggered:
		_portrait_hold_triggered[frame_id] = false
	return triggered


func _on_portrait_mouse_exited(portrait_frame: Control) -> void:
	var frame_id: int = portrait_frame.get_instance_id()
	_portrait_hold_pressed[frame_id] = false
	_portrait_hold_triggered[frame_id] = false
	var hold_timer: Timer = _portrait_hold_timers.get(frame_id) as Timer
	if hold_timer != null:
		hold_timer.stop()


func _on_portrait_hold_timeout(portrait_frame: Control, unit: UnitData) -> void:
	var frame_id: int = portrait_frame.get_instance_id()
	if not bool(_portrait_hold_pressed.get(frame_id, false)):
		return
	_portrait_hold_triggered[frame_id] = true
	_show_unit_details(unit)


func _show_unit_details(unit: UnitData) -> void:
	if unit == null:
		return
	if _unit_detail_overlay == null:
		_build_unit_detail_overlay()
	_unit_detail_portrait.texture = unit.portrait
	_unit_detail_title.text = unit.display_name
	_unit_detail_role.text = "%s / %s / %d HP" % [unit.role, unit.class_name_text, unit.max_hp]
	_unit_detail_blurb.text = unit.picker_blurb if unit.picker_blurb != "" else unit.role
	for child in _unit_detail_abilities.get_children():
		child.queue_free()
	var ranges: Array = unit.dice_ranges.duplicate(true)
	ranges.sort_custom(_sort_range_min)
	for range_variant in ranges:
		var entry: Dictionary = range_variant
		var ability_name := str(entry.get("ability_name", "Ability"))
		var roll_range := "%d-%d" % [int(entry.get("min", 0)), int(entry.get("max", 0))]
		var ability_label := _make_detail_label("%s  %s" % [roll_range, ability_name], 30, PixelUI.TEXT_PRIMARY)
		ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_unit_detail_abilities.add_child(ability_label)
		var description := str(entry.get("description", "")).strip_edges()
		if description != "":
			var desc_label := _make_detail_label(description, 24, PixelUI.TEXT_MUTED)
			desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_unit_detail_abilities.add_child(desc_label)
	_unit_detail_overlay.visible = true
	_unit_detail_overlay.move_to_front()


func _on_unit_detail_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_unit_detail_overlay.visible = false
			_unit_detail_overlay.accept_event()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_unit_detail_overlay.visible = false
			_unit_detail_overlay.accept_event()


func _make_detail_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUI.style_label(label, font_size, color, 2)
	return label


func _sort_range_min(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("min", 0)) < int(b.get("min", 0))


func _apply_visual_theme() -> void:
	background.color = PixelUI.BG_DARK
	logo_image.texture = DataManager.get_logo_texture()
	logo_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo_image.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo_image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	logo_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_image.stretch_mode = TextureRect.STRETCH_SCALE
	PixelUI.style_panel(logo_panel, Color(0.010, 0.018, 0.030, 0.60), Color.TRANSPARENT, 0, 0)
	title_label.visible = false
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hero_list.columns = 2
	hero_list.add_theme_constant_override("h_separation", 14)
	hero_list.add_theme_constant_override("v_separation", 12)
	operation_buttons.columns = 3
	operation_buttons.add_theme_constant_override("h_separation", 10)
	operation_buttons.add_theme_constant_override("v_separation", 10)
	random_button.custom_minimum_size = Vector2(0, 104)
	continue_button.custom_minimum_size = Vector2(0, 104)
	random_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelUI.style_label(summary_label, SUMMARY_FONT_SIZE, PixelUI.TEXT_PRIMARY, 2)
	PixelUI.style_panel(operation_panel, Color(0.020, 0.034, 0.052, 0.92), PixelUI.LINE_BRIGHT, 3, 0)
	PixelUI.style_label(operation_title, OPERATION_TITLE_FONT_SIZE, PixelUI.GOLD_ACCENT, 2)
	PixelUI.style_label(operation_section_label, OPERATION_SECTION_FONT_SIZE, PixelUI.TEXT_MUTED, 2)
	PixelUI.style_label(operation_blurb_label, OPERATION_BLURB_FONT_SIZE, PixelUI.TEXT_MUTED, 1)
	PixelUI.style_button(random_button, PixelUI.BG_PANEL_ALT, PixelUI.GOLD_ACCENT, FOOTER_BUTTON_FONT_SIZE)
	PixelUI.style_button(continue_button, PixelUI.BG_PANEL_ALT, PixelUI.LINE_BRIGHT, FOOTER_BUTTON_FONT_SIZE)
	_update_logo_size()


func _update_logo_size() -> void:
	if logo_image == null or logo_panel == null:
		return
	var viewport_width: float = get_viewport_rect().size.x
	var logo_width: float = maxf(300.0, floor(viewport_width * LOGO_WIDTH_RATIO))
	var logo_height: float = floor(logo_width * LOGO_ASPECT)
	logo_image.custom_minimum_size = Vector2(logo_width, logo_height)
	logo_panel.custom_minimum_size = Vector2(0, logo_height + 8.0)
