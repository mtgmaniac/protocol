# Phase 8 evolution screen that lets the player choose one of two run-long upgrade branches.
extends Control

@onready var background: ColorRect = $Background
@onready var title_label: Label = $Content/VBox/Title
@onready var summary_label: Label = %SummaryLabel
@onready var choice_cards: GridContainer = %ChoiceCards
@onready var footer_label: Label = %FooterLabel
@onready var return_to_menu_button: Button = $Content/VBox/ButtonRow/ReturnToMenuButton


func _ready() -> void:
	_apply_visual_theme()
	_refresh_summary()
	_build_choice_cards()


func _on_return_to_menu_button_pressed() -> void:
	GameState.reset_run()
	SceneManager.go_to_unit_select()


func _build_choice_cards() -> void:
	for child in choice_cards.get_children():
		child.queue_free()

	var paths: Array = GameState.get_pending_evolution_paths()
	for path_variant in paths:
		var path: Dictionary = path_variant
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(260, 280)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PixelUI.style_panel(card, PixelUI.BG_PANEL, PixelUI.HERO_ACCENT, 2, 3)

		var margin: MarginContainer = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 16)
		margin.add_theme_constant_override("margin_top", 16)
		margin.add_theme_constant_override("margin_right", 16)
		margin.add_theme_constant_override("margin_bottom", 16)
		card.add_child(margin)

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 10)
		margin.add_child(vbox)

		var title: Label = Label.new()
		title.text = str(path.get("name", "Evolution"))
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		PixelUI.style_label(title, 26, PixelUI.TEXT_PRIMARY, 2)
		vbox.add_child(title)

		var focus: Label = Label.new()
		focus.text = str(path.get("focus", ""))
		focus.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		PixelUI.style_label(focus, 16, PixelUI.TEXT_MUTED, 2)
		vbox.add_child(focus)

		var hp_text: Label = Label.new()
		var hp_value: int = int(path.get("hp", 0))
		hp_text.text = "Max HP: %d" % hp_value if hp_value > 0 else "Max HP unchanged"
		PixelUI.style_label(hp_text, 16, PixelUI.GOLD_ACCENT, 2)
		vbox.add_child(hp_text)

		var ability_preview: RichTextLabel = RichTextLabel.new()
		ability_preview.bbcode_enabled = false
		ability_preview.fit_content = true
		ability_preview.scroll_active = false
		ability_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ability_preview.text = _build_ability_preview(path)
		ability_preview.add_theme_font_size_override("normal_font_size", PixelUI.scale_font_size(16))
		ability_preview.add_theme_color_override("default_color", PixelUI.TEXT_MUTED)
		vbox.add_child(ability_preview)

		var choose_button: Button = Button.new()
		choose_button.custom_minimum_size = Vector2(0, 48)
		choose_button.text = "Choose %s" % str(path.get("name", "Path"))
		PixelUI.style_button(choose_button, PixelUI.BG_PANEL_ALT, PixelUI.HERO_ACCENT, 18)
		choose_button.pressed.connect(_on_choose_path_pressed.bind(str(path.get("name", ""))))
		vbox.add_child(choose_button)

		choice_cards.add_child(card)


func _build_ability_preview(path: Dictionary) -> String:
	var lines: Array = []
	var ability_map: Dictionary = path.get("abilities_by_zone", {})
	for zone_name in ["recharge", "strike", "surge", "crit", "overload"]:
		if not ability_map.has(zone_name):
			continue
		var entry: Dictionary = ability_map[zone_name]
		lines.append("%s: %s" % [zone_name.capitalize(), str(entry.get("ability_name", ""))])
	return "\n".join(lines)


func _refresh_summary() -> void:
	var unit_id: String = GameState.get_pending_evolution_unit_id()
	var unit: UnitData = DataManager.get_unit(unit_id) as UnitData
	if unit == null:
		summary_label.text = "No evolution is ready."
		return
	summary_label.text = "%s reached level %d.\nChoose an evolution path for the rest of this run." % [
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


func _apply_visual_theme() -> void:
	background.color = PixelUI.BG_DARK
	PixelUI.style_label(title_label, 42, PixelUI.HERO_ACCENT, 2)
	PixelUI.style_label(summary_label, 24, PixelUI.TEXT_PRIMARY, 2)
	PixelUI.style_label(footer_label, 18, PixelUI.TEXT_MUTED, 1)
	PixelUI.style_button(return_to_menu_button, PixelUI.BG_PANEL_ALT, PixelUI.LINE_DIM, 18)
