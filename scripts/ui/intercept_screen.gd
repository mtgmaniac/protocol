# Intercept event (pkg7.4): one card per intercept beat, drawn without
# replacement from the tier deck. Choices are fully deterministic; picks
# (hero / gear / consumable) and drafts run as follow-up stages.
extends Control

const TYPE_FONT := 28
const TITLE_FONT := 62
const CARD_TITLE_FONT := 50
const BODY_FONT := 36
const BUTTON_FONT := 36

var _card_id: String = ""
var _card: Dictionary = {}
var _choice: Dictionary = {}
var _picked_hero_id: String = ""
var _gear_context: Dictionary = {}
var _stage_box: VBoxContainer
var _button_box: VBoxContainer


func _ready() -> void:
	PersistentHeader.set_run_active(true)
	PersistentHeader.clear_battle_actions()
	var operation: OperationData = DataManager.get_operation(GameState.selected_operation_id) as OperationData
	if operation != null:
		PersistentHeader.update_progress(GameState.current_battle, GameState.total_battles, operation.battle_name())

	var beat: Dictionary = GameState.get_beat_after_battle(GameState.current_battle)
	_card_id = GameState.draw_intercept_card(str(beat.get("tier", "minor")))
	if _card_id == "":
		_continue_to_battle()
		return
	_card = GameState.INTERCEPT_CARDS.get(_card_id, {})

	var bg := ColorRect.new()
	bg.color = PixelUI.DT_FIELD_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	PixelUI.add_terminal_backdrop(self)

	# ~90%-wide transmission window, vertically centered in the free space.
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var side: int = PixelUI.screen_frame_side_margin()
	margin.add_theme_constant_override("margin_left", side)
	margin.add_theme_constant_override("margin_right", side)
	margin.add_theme_constant_override("margin_top", 150)
	margin.add_theme_constant_override("margin_bottom", 80)
	add_child(margin)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(col)

	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	PixelUI.style_transmission_panel(frame)
	col.add_child(frame)

	var pad := MarginContainer.new()
	for pad_side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(pad_side, 36)
	frame.add_child(pad)

	_stage_box = VBoxContainer.new()
	_stage_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_box.add_theme_constant_override("separation", 16)
	pad.add_child(_stage_box)

	_show_card_stage()


func _clear_stage() -> void:
	for child in _stage_box.get_children():
		child.queue_free()
	_button_box = null


func _add_gap(height: int) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_box.add_child(gap)


func _add_label(text: String, font_size: int, color: Color, outline: int = 1) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelUI.style_label(label, font_size, color, outline)
	_stage_box.add_child(label)
	return label


func _add_choice_button(text: String, callback: Callable, enabled: bool = true) -> void:
	# Choice buttons live in their own box: 24px padding above the group, 12px between.
	if _button_box == null:
		_add_gap(24)
		_button_box = VBoxContainer.new()
		_button_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button_box.add_theme_constant_override("separation", 12)
		_stage_box.add_child(_button_box)
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 104)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.disabled = not enabled
	PixelUI.style_button(button, Color(0.022, 0.034, 0.050, 0.95), PixelUI.DT_AMBER if enabled else PixelUI.LINE_DIM, BUTTON_FONT)
	button.pressed.connect(callback)
	_button_box.add_child(button)


func _show_card_stage() -> void:
	_clear_stage()
	# Rhythm: small amber event-type label · large title · blank line · body.
	_add_label("INTERCEPT", TYPE_FONT, PixelUI.DT_AMBER, 2)
	_add_label(str(_card.get("name", "")), TITLE_FONT, PixelUI.TEXT_PRIMARY, 3)
	_add_gap(8)
	_add_label(str(_card.get("desc", "")), BODY_FONT, PixelUI.TEXT_PRIMARY, 1)
	for choice_variant in _card.get("choices", []):
		var choice: Dictionary = choice_variant
		var enabled: bool = true
		if str(choice.get("pick", "")) == "consumable" and GameState.consumables.is_empty():
			enabled = false
		if str(choice.get("pick", "")) == "gear" and _all_equipped_gear().is_empty():
			enabled = false
		_add_choice_button(str(choice.get("label", "")), _on_choice_pressed.bind(choice), enabled)


func _on_choice_pressed(choice: Dictionary) -> void:
	AudioManager.play_select()
	_choice = choice
	_picked_hero_id = ""
	_gear_context = {}
	match str(choice.get("pick", "")):
		"hero":
			_show_hero_pick_stage()
		"gear":
			_show_gear_pick_stage()
		"consumable":
			_spend_highest_rarity_consumable()
			_after_picks()
		_:
			_after_picks()


func _show_hero_pick_stage() -> void:
	_clear_stage()
	_add_label(str(_card.get("name", "")), CARD_TITLE_FONT, PixelUI.DT_AMBER, 3)
	_add_label("Choose a hero.", BODY_FONT, PixelUI.TEXT_PRIMARY, 1)
	for unit_id_variant in GameState.selected_units:
		var unit_id: String = str(unit_id_variant)
		var unit: UnitData = DataManager.get_unit(unit_id) as UnitData
		var display: String = unit.display_name if unit != null else unit_id
		_add_choice_button(display.to_upper(), _on_hero_picked.bind(unit_id))


func _on_hero_picked(unit_id: String) -> void:
	AudioManager.play_select()
	_picked_hero_id = unit_id
	_after_picks()


func _all_equipped_gear() -> Array:
	var entries: Array = []
	for unit_id_variant in GameState.selected_units:
		var unit_id: String = str(unit_id_variant)
		for gear_id in GameState.gear_by_unit.get(unit_id, []):
			entries.append({"hero_id": unit_id, "gear_id": str(gear_id)})
	return entries


func _show_gear_pick_stage() -> void:
	_clear_stage()
	_add_label(str(_card.get("name", "")), CARD_TITLE_FONT, PixelUI.DT_AMBER, 3)
	_add_label("Choose a piece of equipped gear.", BODY_FONT, PixelUI.TEXT_PRIMARY, 1)
	for entry_variant in _all_equipped_gear():
		var entry: Dictionary = entry_variant
		var item: ItemData = DataManager.get_item(str(entry["gear_id"])) as ItemData
		var unit: UnitData = DataManager.get_unit(str(entry["hero_id"])) as UnitData
		var label: String = "%s (%s)" % [item.display_name if item != null else str(entry["gear_id"]), unit.display_name if unit != null else str(entry["hero_id"])]
		_add_choice_button(label.to_upper(), _on_gear_picked.bind(entry))


func _on_gear_picked(entry: Dictionary) -> void:
	AudioManager.play_select()
	_gear_context = entry
	_picked_hero_id = str(entry.get("hero_id", ""))
	_after_picks()


func _spend_highest_rarity_consumable() -> void:
	var best_index: int = -1
	var best_tier: int = -1
	for i in GameState.consumables.size():
		var item: ItemData = DataManager.get_item(str(GameState.consumables[i])) as ItemData
		var tier: int = GameState.RARITY_LADDER.find(item.rarity) if item != null else 0
		if tier > best_tier:
			best_tier = tier
			best_index = i
	if best_index >= 0:
		GameState.consumables.remove_at(best_index)


func _after_picks() -> void:
	var draft: Dictionary = _choice.get("draft", {})
	if not draft.is_empty():
		_show_draft_stage(draft)
		return
	_resolve_choice()


func _show_draft_stage(draft: Dictionary) -> void:
	_clear_stage()
	_add_label(str(_card.get("name", "")), CARD_TITLE_FONT, PixelUI.DT_AMBER, 3)
	_add_label("Choose one.", BODY_FONT, PixelUI.TEXT_PRIMARY, 1)
	var options: Array = GameState.roll_intercept_draft(
		str(draft.get("kind", "consumable")),
		str(draft.get("min_rarity", "common")),
		int(draft.get("count", 3))
	)
	if options.is_empty():
		_resolve_choice()
		return
	for item_id_variant in options:
		var item: ItemData = DataManager.get_item(str(item_id_variant)) as ItemData
		var label: String = "%s — %s" % [item.display_name.to_upper(), item.description] if item != null else str(item_id_variant)
		_add_choice_button(label, _on_draft_picked.bind(str(item_id_variant)))


func _on_draft_picked(item_id: String) -> void:
	AudioManager.play_select()
	var item: ItemData = DataManager.get_item(item_id) as ItemData
	if item != null and item.item_type == "gear":
		# Drafted gear equips to the picked hero (or the first squad slot).
		var target_id: String = _picked_hero_id
		if target_id == "" and not GameState.selected_units.is_empty():
			target_id = str(GameState.selected_units[0])
		var unit_gear: Array = GameState.gear_by_unit.get(target_id, []).duplicate()
		unit_gear.append(item_id)
		GameState.gear_by_unit[target_id] = unit_gear
		GameState.equipped_gear[target_id] = unit_gear.duplicate()
	elif item != null and GameState.consumables.size() < GameState.MAX_CONSUMABLES:
		GameState.consumables.append(item_id)
	_resolve_choice(item)


func _resolve_choice(drafted_item: ItemData = null) -> void:
	var info: String = GameState.apply_intercept_effects(_choice.get("effects", []), _picked_hero_id, _gear_context)
	_show_result_stage(info, drafted_item)


func _show_result_stage(info: String, drafted_item: ItemData) -> void:
	_clear_stage()
	_add_label(str(_card.get("name", "")), CARD_TITLE_FONT, PixelUI.DT_AMBER, 3)
	var summary: String = str(_choice.get("label", ""))
	if drafted_item != null:
		summary += "\nAcquired: %s." % drafted_item.display_name
	_add_label(summary, BODY_FONT, PixelUI.TEXT_PRIMARY, 1)
	if info != "":
		_add_label(info, BODY_FONT - 4, PixelUI.TEXT_MUTED, 1)
	_add_choice_button("CONTINUE", _continue_to_battle)


func _continue_to_battle() -> void:
	GameState.advance_to_next_battle()
	SceneManager.go_to_battle()
