# Phase 6 reward screen that rolls three item choices and applies the selected reward into GameState.
extends Control

@onready var background: ColorRect = $Background
@onready var title_label: Label = $Content/VBox/Title
@onready var summary_label: Label = %SummaryLabel
@onready var inventory_label: Label = %InventoryLabel
@onready var reward_cards: GridContainer = %RewardCards
@onready var footer_label: Label = %FooterLabel
@onready var return_to_menu_button: Button = $Content/VBox/ButtonRow/ReturnToMenuButton


func _ready() -> void:
	_apply_visual_theme()
	if GameState.pending_reward_item_ids.is_empty():
		GameState.prepare_battle_rewards()
	_refresh_inventory_summary()
	_refresh_summary("Choose one reward from this battle.")
	_build_reward_cards()


func _on_return_to_menu_button_pressed() -> void:
	GameState.reset_run()
	SceneManager.go_to_unit_select()


func _build_reward_cards() -> void:
	for child in reward_cards.get_children():
		child.queue_free()

	var reward_items: Array = GameState.get_pending_reward_items()
	for item_variant in reward_items:
		var item: ItemData = item_variant as ItemData
		if item == null:
			continue
		var card: PanelContainer = _create_reward_card(item)
		reward_cards.add_child(card)


func _create_reward_card(item: ItemData) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(285, 330)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelUI.style_panel(panel, Color(0.028, 0.050, 0.074, 0.92), _get_item_accent(item), 3, 0)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title_label: Label = Label.new()
	title_label.text = item.display_name
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelUI.style_label(title_label, 28, PixelUI.TEXT_PRIMARY, 2)
	vbox.add_child(title_label)

	var type_label: Label = Label.new()
	type_label.text = "%s  |  %s" % [item.item_type.capitalize(), item.rarity.capitalize()]
	PixelUI.style_label(type_label, 18, _get_item_accent(item), 2)
	vbox.add_child(type_label)

	var description_label: Label = Label.new()
	description_label.text = item.description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	PixelUI.style_label(description_label, 18, PixelUI.TEXT_MUTED, 1)
	vbox.add_child(description_label)

	var target_selector: OptionButton = OptionButton.new()
	target_selector.visible = item.item_type == "gear"
	target_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if item.item_type == "gear":
		for unit_id_variant in GameState.selected_units:
			var unit_id: String = str(unit_id_variant)
			var unit: UnitData = DataManager.get_unit(unit_id) as UnitData
			if unit == null:
				continue
			target_selector.add_item(unit.display_name)
			var item_index: int = target_selector.item_count - 1
			target_selector.set_item_metadata(item_index, unit_id)
		vbox.add_child(target_selector)
		PixelUI.style_option_button(target_selector, PixelUI.BG_PANEL_ALT, PixelUI.LINE_DIM, 18)

	var action_button: Button = Button.new()
	action_button.custom_minimum_size = Vector2(0, 54)
	action_button.text = _build_claim_button_text(item)
	PixelUI.style_button(action_button, PixelUI.BG_PANEL_ALT, _get_item_accent(item), 20)
	action_button.pressed.connect(_on_claim_reward_pressed.bind(item.id, target_selector))
	vbox.add_child(action_button)

	return panel


func _build_claim_button_text(item: ItemData) -> String:
	if item.item_type == "gear":
		return "Equip And Continue"
	if item.item_type == "relic":
		return "Claim Relic"
	return "Take And Continue"


func _on_claim_reward_pressed(item_id: String, target_selector: OptionButton) -> void:
	var item: ItemData = DataManager.get_item(item_id) as ItemData
	if item == null:
		return

	var target_unit_id: String = ""
	if item.item_type == "gear":
		if target_selector == null or target_selector.item_count == 0:
			footer_label.text = "No valid unit target available for this gear."
			return
		var selected_index: int = target_selector.selected
		target_unit_id = str(target_selector.get_item_metadata(selected_index))

	var claimed: bool = GameState.claim_reward(item_id, target_unit_id)
	if not claimed:
		footer_label.text = "That reward could not be claimed. Try again."
		return

	_refresh_inventory_summary()
	footer_label.text = _build_reward_result_text(item, target_unit_id)
	GameState.award_battle_xp()
	if GameState.has_pending_evolution():
		SceneManager.go_to_evolution()
		return
	GameState.advance_to_next_battle()
	SceneManager.go_to_battle()


func _refresh_summary(extra_text: String) -> void:
	summary_label.text = "%s complete\nOperation: %s\n%s" % [
		GameState.get_battle_progress_text(),
		GameState.selected_operation_id,
		extra_text,
	]


func _refresh_inventory_summary() -> void:
	inventory_label.text = GameState.get_inventory_summary()


func _build_reward_result_text(item: ItemData, target_unit_id: String) -> String:
	if item.item_type != "gear":
		return "%s added to the run." % item.display_name

	var unit: UnitData = DataManager.get_unit(target_unit_id) as UnitData
	if unit == null:
		return "%s equipped." % item.display_name
	return "%s equipped to %s." % [item.display_name, unit.display_name]


func _apply_visual_theme() -> void:
	background.color = PixelUI.BG_DARK
	PixelUI.style_label(title_label, 44, PixelUI.GOLD_ACCENT, 2)
	PixelUI.style_label(summary_label, 26, PixelUI.TEXT_PRIMARY, 2)
	PixelUI.style_label(inventory_label, 20, PixelUI.TEXT_MUTED, 1)
	PixelUI.style_label(footer_label, 20, PixelUI.TEXT_MUTED, 1)
	PixelUI.style_button(return_to_menu_button, PixelUI.BG_PANEL_ALT, PixelUI.LINE_DIM, 20)


func _get_item_accent(item: ItemData) -> Color:
	match item.item_type:
		"relic":
			return PixelUI.GOLD_ACCENT
		"gear":
			return PixelUI.LINE_BRIGHT
		_:
			return PixelUI.HERO_ACCENT
