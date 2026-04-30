# Evolution branch picker shown when a unit reaches a run-long upgrade.
extends Control

const CARD_WIDTH_FRACTION := 0.78
const CARD_MIN_WIDTH := 620.0
const CARD_MAX_WIDTH := 920.0
const CARD_TOP_SPACER_HEIGHT := 24.0
const CARD_BG := Color(0.024, 0.040, 0.060, 0.82)
const CARD_BG_HOVER := Color(0.036, 0.060, 0.086, 0.92)
const PORTRAIT_SIZE := Vector2(170, 210)
const TITLE_FONT_SIZE := 58
const SUMMARY_FONT_SIZE := 36
const CARD_TITLE_FONT_SIZE := 44
const BODY_FONT_SIZE := 36
const SMALL_FONT_SIZE := 30
const ABILITY_NAME_FONT_SIZE := 34
const ABILITY_DESC_FONT_SIZE := 30
const BUTTON_FONT_SIZE := 36

@onready var background: ColorRect = $Background
@onready var content_vbox: VBoxContainer = $Content/VBox
@onready var battle_summary_label: Label = $HeaderRow/InfoStack/SummaryLabel
@onready var battle_counter_label: Label = $HeaderRow/InfoStack/CounterLabel
@onready var header_help_button: Button = $HeaderRow/ButtonRow/ToggleLogButton
@onready var header_auto_button: Button = $HeaderRow/ButtonRow/AutoTurnButton
@onready var header_auto_battle_button: Button = $HeaderRow/ButtonRow/AutoBattleButton
@onready var header_back_button: Button = $HeaderRow/ButtonRow/ReturnToMenuButton
@onready var title_label: Label = $Content/VBox/Title
@onready var summary_label: Label = %SummaryLabel
@onready var choice_area: MarginContainer = $Content/VBox/ChoiceArea
@onready var choice_content: VBoxContainer = %ChoiceContent
@onready var top_spacer: Control = %TopSpacer
@onready var choice_cards: VBoxContainer = %ChoiceCards
@onready var footer_label: Label = %FooterLabel

var _help_overlay: Control = null


func _ready() -> void:
	_apply_visual_theme()
	resized.connect(_update_choice_layout)
	header_help_button.pressed.connect(_on_help_button_pressed)
	header_auto_button.pressed.connect(_on_header_unavailable_pressed.bind("Auto turn is unavailable while choosing an evolution."))
	header_auto_battle_button.pressed.connect(_on_header_unavailable_pressed.bind("Auto battle is unavailable while choosing an evolution."))
	header_back_button.pressed.connect(_on_return_to_menu_button_pressed)
	_update_battle_header()
	_refresh_summary()
	_build_choice_cards()


func _on_return_to_menu_button_pressed() -> void:
	GameState.reset_run()
	SceneManager.go_to_unit_select()


func _on_help_button_pressed() -> void:
	if _help_overlay == null or not is_instance_valid(_help_overlay):
		_build_help_overlay()
	_help_overlay.visible = true
	_help_overlay.move_to_front()


func _on_header_unavailable_pressed(message: String) -> void:
	footer_label.text = message
	footer_label.visible = true


func _hide_help_overlay() -> void:
	if _help_overlay != null and is_instance_valid(_help_overlay):
		_help_overlay.visible = false


func _build_help_overlay() -> void:
	_help_overlay = Control.new()
	_help_overlay.name = "EvolutionHelpOverlay"
	_help_overlay.visible = false
	_help_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.z_as_relative = false
	_help_overlay.z_index = 200
	_help_overlay.gui_input.connect(_on_help_overlay_input)
	add_child(_help_overlay)

	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.005, 0.007, 0.012, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(820, 0)
	PixelUI.style_ninepatch_panel(panel, PixelUI.FRAME_BOTTOM_BAR_SCIFI)
	center.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	content.add_child(_make_label("EVOLUTION HELP", 40, PixelUI.TEXT_PRIMARY, 3))
	for line in [
		"Choose one evolution branch for this unit.",
		"Each card shows the full ability table after the upgrade.",
		"Portraits currently reuse the base unit art. Unique evolved art can drop into the same card later.",
	]:
		var label: Label = _make_label(line, BODY_FONT_SIZE, PixelUI.TEXT_MUTED, 1)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(label)


func _on_help_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed:
			_hide_help_overlay()
	elif event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_hide_help_overlay()


func _build_choice_cards() -> void:
	for child in choice_cards.get_children():
		child.queue_free()

	var unit_id: String = GameState.get_pending_evolution_unit_id()
	var unit: UnitData = DataManager.get_unit(unit_id) as UnitData
	var paths: Array = GameState.get_pending_evolution_paths()
	for path_variant in paths:
		var path: Dictionary = path_variant
		choice_cards.add_child(_create_evolution_card(path, unit))
	call_deferred("_update_choice_layout")


func _create_evolution_card(path: Dictionary, base_unit: UnitData) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(_get_card_width(), 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_style_evolution_panel(panel, false)
	panel.mouse_entered.connect(_style_evolution_panel.bind(panel, true))
	panel.mouse_exited.connect(_style_evolution_panel.bind(panel, false))

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	vbox.add_child(_create_path_header(path, base_unit))
	vbox.add_child(_create_divider())

	var abilities: VBoxContainer = VBoxContainer.new()
	abilities.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	abilities.add_theme_constant_override("separation", 10)
	for entry_variant in _build_merged_ranges(path, base_unit):
		var entry: Dictionary = entry_variant
		abilities.add_child(_create_ability_row(entry))
	vbox.add_child(abilities)

	var choose_button: Button = Button.new()
	choose_button.custom_minimum_size = Vector2(0, 78)
	choose_button.text = "CHOOSE %s" % str(path.get("name", "EVOLUTION")).to_upper()
	PixelUI.style_button(choose_button, Color(0.022, 0.034, 0.050, 0.95), PixelUI.HERO_ACCENT, BUTTON_FONT_SIZE)
	choose_button.pressed.connect(_on_choose_path_pressed.bind(str(path.get("name", ""))))
	vbox.add_child(choose_button)
	return panel


func _create_path_header(path: Dictionary, base_unit: UnitData) -> HBoxContainer:
	var header: HBoxContainer = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 18)

	var portrait_frame: PanelContainer = PanelContainer.new()
	portrait_frame.custom_minimum_size = PORTRAIT_SIZE
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUI.style_ninepatch_panel(portrait_frame, PixelUI.FRAME_PORTRAIT_SCIFI)
	header.add_child(portrait_frame)

	var portrait: TextureRect = TextureRect.new()
	portrait.texture = _get_path_portrait(path, base_unit)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_frame.add_child(portrait)

	var text_stack: VBoxContainer = VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.add_theme_constant_override("separation", 6)
	header.add_child(text_stack)

	var path_name: Label = _make_label(str(path.get("name", "Evolution")), CARD_TITLE_FONT_SIZE, PixelUI.HERO_ACCENT, 3)
	path_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_stack.add_child(path_name)

	var focus_text: String = str(path.get("focus", ""))
	if focus_text != "":
		var focus: Label = _make_label(focus_text, BODY_FONT_SIZE, PixelUI.TEXT_PRIMARY, 2)
		focus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_stack.add_child(focus)

	var hp_value: int = int(path.get("hp", 0))
	var hp_label_text: String = "MAX HP UNCHANGED"
	if hp_value > 0:
		hp_label_text = "MAX HP %d" % hp_value
	text_stack.add_child(_make_label(hp_label_text, SMALL_FONT_SIZE, PixelUI.GOLD_ACCENT, 1))

	if base_unit != null:
		text_stack.add_child(_make_label("FROM %s" % base_unit.display_name.to_upper(), SMALL_FONT_SIZE, PixelUI.TEXT_MUTED, 1))
	return header


func _create_ability_row(entry: Dictionary) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)

	var range_label: Label = _make_label("%d-%d" % [int(entry.get("min", 0)), int(entry.get("max", 0))], SMALL_FONT_SIZE, PixelUI.TEXT_MUTED, 1)
	range_label.custom_minimum_size = Vector2(110, 0)
	range_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	row.add_child(range_label)

	var text_stack: VBoxContainer = VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.add_theme_constant_override("separation", 3)
	row.add_child(text_stack)

	var ability_name: Label = _make_label(str(entry.get("ability_name", "Ability")), ABILITY_NAME_FONT_SIZE, PixelUI.TEXT_PRIMARY, 2)
	ability_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_stack.add_child(ability_name)

	var description_text: String = str(entry.get("description", "")).strip_edges()
	if description_text != "":
		var description: Label = _make_label(description_text, ABILITY_DESC_FONT_SIZE, PixelUI.TEXT_MUTED, 1)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_stack.add_child(description)
	return row


func _create_divider() -> ColorRect:
	var divider: ColorRect = ColorRect.new()
	divider.color = PixelUI.LINE_DIM
	divider.custom_minimum_size = Vector2(0, 2)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider


func _style_evolution_panel(panel: PanelContainer, hovered: bool) -> void:
	var tint: Color = PixelUI.HERO_ACCENT.lightened(0.06 if hovered else 0.0).lerp(Color.WHITE, 0.28)
	PixelUI.style_ninepatch_panel(panel, PixelUI.FRAME_PORTRAIT_SCIFI, 24, tint)


func _build_merged_ranges(path: Dictionary, base_unit: UnitData) -> Array:
	var ability_map: Dictionary = path.get("abilities_by_zone", {})
	var ranges: Array = []
	if base_unit == null:
		for zone_name in ["recharge", "strike", "surge", "crit", "overload"]:
			if ability_map.has(zone_name):
				ranges.append((ability_map[zone_name] as Dictionary).duplicate(true))
		ranges.sort_custom(_sort_range_min)
		return ranges

	for base_range_variant in base_unit.dice_ranges:
		var base_range: Dictionary = base_range_variant
		var zone: String = str(base_range.get("zone", ""))
		if ability_map.has(zone):
			ranges.append((ability_map[zone] as Dictionary).duplicate(true))
		else:
			ranges.append(base_range.duplicate(true))
	ranges.sort_custom(_sort_range_min)
	return ranges


func _sort_range_min(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("min", 0)) < int(b.get("min", 0))


func _get_path_portrait(path: Dictionary, base_unit: UnitData) -> Texture2D:
	# Future evolved portraits can be added to the path data without changing this screen.
	var portrait_variant: Variant = path.get("portrait", null)
	var portrait: Texture2D = portrait_variant as Texture2D
	if portrait != null:
		return portrait
	if base_unit != null:
		return base_unit.portrait
	return null


func _refresh_summary() -> void:
	var unit_id: String = GameState.get_pending_evolution_unit_id()
	var unit: UnitData = DataManager.get_unit(unit_id) as UnitData
	if unit == null:
		summary_label.text = "No evolution is ready."
		return
	summary_label.text = "%s reached level %d. Choose a permanent branch." % [
		unit.display_name,
		GameState.get_unit_level(unit_id),
	]


func _on_choose_path_pressed(path_name: String) -> void:
	var pending_unit_id: String = GameState.get_pending_evolution_unit_id()
	if not GameState.apply_pending_evolution(path_name):
		footer_label.text = "That evolution could not be applied."
		return
	var unit: UnitData = DataManager.get_unit(pending_unit_id) as UnitData
	var unit_name: String = pending_unit_id
	if unit != null:
		unit_name = unit.display_name
	footer_label.text = "%s evolved into %s." % [unit_name, path_name]
	GameState.advance_to_next_battle()
	SceneManager.go_to_battle()


func _update_battle_header() -> void:
	var operation: OperationData = DataManager.get_operation(GameState.selected_operation_id) as OperationData
	var op_name: String = operation.battle_name() if operation != null else "OP"
	var battle_text: String = GameState.get_battle_progress_text()
	if battle_text.begins_with("Battle "):
		battle_text = battle_text.trim_prefix("Battle ")
	battle_summary_label.text = "%s  %s" % [op_name, battle_text]
	battle_counter_label.text = ""


func _update_choice_layout() -> void:
	if choice_cards == null:
		return
	var card_width: float = _get_card_width()
	choice_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choice_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	choice_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_cards.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	choice_content.add_theme_constant_override("separation", 18)
	choice_cards.add_theme_constant_override("separation", 18)
	top_spacer.custom_minimum_size = Vector2(0, CARD_TOP_SPACER_HEIGHT)
	for child in choice_cards.get_children():
		var panel: PanelContainer = child as PanelContainer
		if panel != null:
			panel.custom_minimum_size = Vector2(card_width, 0)
			panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _get_card_width() -> float:
	var available_width: float = choice_area.size.x if choice_area != null else size.x
	if available_width <= 1.0:
		available_width = get_viewport().get_visible_rect().size.x
	available_width = maxf(available_width - 24.0, 1.0)
	return clampf(available_width * CARD_WIDTH_FRACTION, CARD_MIN_WIDTH, CARD_MAX_WIDTH)


func _apply_visual_theme() -> void:
	background.color = PixelUI.BG_DARK
	content_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	content_vbox.add_theme_constant_override("separation", 8)
	footer_label.visible = false
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.apply_pixel_font(battle_summary_label)
	battle_summary_label.add_theme_font_size_override("font_size", 112)
	battle_summary_label.add_theme_color_override("font_color", PixelUI.TEXT_PRIMARY.darkened(0.15))
	battle_summary_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.98))
	battle_summary_label.add_theme_constant_override("outline_size", 2)
	battle_summary_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	battle_summary_label.clip_text = false
	battle_summary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	PixelUI.apply_pixel_font(battle_counter_label)
	battle_counter_label.add_theme_font_size_override("font_size", 112)
	battle_counter_label.add_theme_color_override("font_color", PixelUI.TEXT_PRIMARY)
	battle_counter_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.98))
	battle_counter_label.add_theme_constant_override("outline_size", 3)
	battle_counter_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	battle_counter_label.clip_text = false
	battle_counter_label.visible = false
	var header_row: Control = $HeaderRow
	header_row.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	PixelUI.style_texture_button(header_help_button, PixelUI.BUTTON_HELP_SCIFI)
	PixelUI.style_texture_button(header_auto_button, PixelUI.BUTTON_DEBUG_SCIFI)
	PixelUI.style_texture_button(header_auto_battle_button, PixelUI.BUTTON_DEBUG2_SCIFI)
	PixelUI.style_texture_button(header_back_button, PixelUI.BUTTON_BACK_SCIFI)
	PixelUI.style_label(title_label, TITLE_FONT_SIZE, PixelUI.GOLD_ACCENT, 3)
	PixelUI.style_label(summary_label, SUMMARY_FONT_SIZE, PixelUI.TEXT_PRIMARY, 2)
	PixelUI.style_label(footer_label, 30, PixelUI.TEXT_MUTED, 1)
	_update_choice_layout()


func _make_label(text: String, font_size: int, color: Color, outline: int = 1) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUI.style_label(label, font_size, color, outline)
	return label
