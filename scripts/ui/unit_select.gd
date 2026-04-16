# Launch roster picker that lets the player choose a three-unit squad.
extends Control

const DEFAULT_OPERATION_ID := "facility"
const MAX_SELECTED_UNITS := 3

@onready var summary_label: Label = %SummaryLabel
@onready var hero_list: VBoxContainer = %HeroList
@onready var continue_button: Button = %ContinueButton
@onready var background: ColorRect = $Background
@onready var title_label: Label = $Content/VBox/Title
@onready var operation_panel: PanelContainer = $Content/VBox/OperationPanel
@onready var operation_select: OptionButton = %OperationSelect
@onready var operation_blurb_label: Label = %OperationBlurbLabel
@onready var random_button: Button = %RandomButton

var selected_unit_ids: Array = []
var selection_controls: Dictionary = {}
var operation_ids: Array = []


func _ready() -> void:
	_apply_visual_theme()
	_populate_operation_select()
	_build_hero_list()
	_refresh_summary()


func _build_hero_list() -> void:
	for child in hero_list.get_children():
		child.queue_free()
	selection_controls.clear()

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


func _refresh_summary() -> void:
	continue_button.disabled = selected_unit_ids.size() != MAX_SELECTED_UNITS
	summary_label.text = "Pick %d heroes. Selected: %d/%d" % [
		MAX_SELECTED_UNITS,
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
		if button != null:
			button.set_pressed_no_signal(false)
		if card != null:
			_apply_selection_state(card, button, false)

	var picks: int = mini(MAX_SELECTED_UNITS, available_ids.size())
	for index in range(picks):
		var unit_id: String = str(available_ids[index])
		selected_unit_ids.append(unit_id)
		var controls: Dictionary = selection_controls.get(unit_id, {})
		var button: Button = controls.get("button") as Button
		var card: PanelContainer = controls.get("card") as PanelContainer
		if button != null:
			button.set_pressed_no_signal(true)
		if card != null:
			_apply_selection_state(card, button, true)

	_refresh_summary()
	if selected_unit_ids.size() == MAX_SELECTED_UNITS:
		_start_selected_run()
		GameState.advance_to_next_battle()
		SceneManager.go_to_battle()


func _populate_operation_select() -> void:
	operation_select.clear()
	operation_ids = DataManager.get_operation_order()
	if operation_ids.is_empty():
		operation_ids.append(DEFAULT_OPERATION_ID)
	for operation_id_variant in operation_ids:
		var operation_id: String = str(operation_id_variant)
		var operation: OperationData = DataManager.get_operation(operation_id) as OperationData
		var label: String = operation.display_name if operation != null and operation.display_name != "" else operation_id
		operation_select.add_item(label)
		operation_select.set_item_metadata(operation_select.item_count - 1, operation_id)
	var default_index: int = maxi(operation_ids.find(DEFAULT_OPERATION_ID), 0)
	if default_index < operation_select.item_count:
		operation_select.select(default_index)
	_on_operation_selected(operation_select.selected)


func _on_operation_selected(index: int) -> void:
	var operation_id: String = DEFAULT_OPERATION_ID
	if index >= 0 and index < operation_select.item_count:
		operation_id = str(operation_select.get_item_metadata(index))
	var operation: OperationData = DataManager.get_operation(operation_id) as OperationData
	if operation == null:
		operation_blurb_label.text = "Select an operation track."
		return
	operation_blurb_label.text = "%s\n%d battles // %s" % [
		operation.blurb,
		operation.battles.size(),
		_build_operation_enemy_preview(operation),
	]


func _start_selected_run() -> void:
	GameState.start_run(selected_unit_ids, _get_selected_operation_id())


func _get_selected_operation_id() -> String:
	var index: int = operation_select.selected
	if index >= 0 and index < operation_select.item_count:
		return str(operation_select.get_item_metadata(index))
	return DEFAULT_OPERATION_ID


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
	card.custom_minimum_size = Vector2(0, 190)
	PixelUI.style_panel(card, Color(0.028, 0.050, 0.074, 0.88), PixelUI.LINE_DIM, 3, 0)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	margin.add_child(row)

	var portrait_frame: PanelContainer = PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(132, 132)
	PixelUI.style_panel(portrait_frame, Color(0.11, 0.15, 0.22, 0.98), PixelUI.LINE_BRIGHT, 2, 2)
	row.add_child(portrait_frame)

	var portrait: TextureRect = TextureRect.new()
	portrait.texture = unit.portrait
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_frame.add_child(portrait)

	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 7)
	row.add_child(info)

	var name_label: Label = Label.new()
	name_label.text = unit.display_name
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelUI.style_label(name_label, 28, PixelUI.TEXT_PRIMARY, 2)
	info.add_child(name_label)

	var meta_label: Label = Label.new()
	meta_label.text = "%s  //  %d HP" % [unit.role, unit.max_hp]
	meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelUI.style_label(meta_label, 18, PixelUI.HERO_ACCENT, 2)
	info.add_child(meta_label)

	var blurb_label: Label = Label.new()
	blurb_label.text = unit.picker_blurb if unit.picker_blurb != "" else unit.class_name_text
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	PixelUI.style_label(blurb_label, 17, PixelUI.TEXT_MUTED, 1)
	info.add_child(blurb_label)

	var select_button: Button = Button.new()
	select_button.toggle_mode = true
	select_button.custom_minimum_size = Vector2(0, 50)
	select_button.text = "Select Unit"
	PixelUI.style_button(select_button, PixelUI.BG_PANEL_ALT, PixelUI.HERO_ACCENT, 20)
	select_button.toggled.connect(_on_hero_toggled.bind(unit.id, select_button, card))
	info.add_child(select_button)
	selection_controls[unit.id] = {"button": select_button, "card": card}

	return card


func _apply_selection_state(card: PanelContainer, button: Button, is_selected: bool) -> void:
	if is_selected:
		PixelUI.style_panel(card, Color(0.040, 0.105, 0.105, 0.96), PixelUI.HERO_ACCENT, 4, 0)
		button.text = "Selected"
		PixelUI.style_button(button, Color(0.10, 0.24, 0.19, 0.98), PixelUI.HERO_ACCENT, 20)
		return
	PixelUI.style_panel(card, Color(0.028, 0.050, 0.074, 0.88), PixelUI.LINE_DIM, 3, 0)
	button.text = "Select Unit"
	PixelUI.style_button(button, PixelUI.BG_PANEL_ALT, PixelUI.HERO_ACCENT, 20)


func _apply_visual_theme() -> void:
	background.color = PixelUI.BG_DARK
	PixelUI.style_label(title_label, 44, PixelUI.HERO_ACCENT, 2)
	PixelUI.style_label(summary_label, 26, PixelUI.TEXT_PRIMARY, 2)
	PixelUI.style_panel(operation_panel, Color(0.028, 0.050, 0.074, 0.72), PixelUI.LINE_BRIGHT, 3, 0)
	PixelUI.style_option_button(operation_select, PixelUI.BG_PANEL_ALT, PixelUI.LINE_BRIGHT, 22)
	PixelUI.style_label(operation_blurb_label, 18, PixelUI.TEXT_MUTED, 1)
	PixelUI.style_button(random_button, PixelUI.BG_PANEL_ALT, PixelUI.GOLD_ACCENT, 22)
	PixelUI.style_button(continue_button, PixelUI.BG_PANEL_ALT, PixelUI.LINE_BRIGHT, 22)
