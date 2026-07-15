# Intercept event (pkg7.4): one card per intercept beat, drawn without
# replacement from the tier deck. Choices are fully deterministic; picks
# (hero / gear / consumable) and drafts run as follow-up stages.
extends Control

const ChoiceScreenGuardScript := preload("res://scripts/ui/choice_screen_guard.gd")

var _enabled_choice_count: int = 0


const TYPE_FONT := 28
const TITLE_FONT := 62
const CARD_TITLE_FONT := 50
const BODY_FONT := PixelUI.FONT_BODY_MIN  # event flavor/lore prose — Polish Build A body tier
const BUTTON_FONT := 36

# Per-card scene art (banner above the title). File name == card id; a missing
# file just skips the banner so an un-arted card still renders cleanly. The banner
# shows the whole image at its own aspect, its height floating up to BANNER_MAX_H.
const EVENT_ART_DIR := "res://assets/ui/events/"
const BANNER_MAX_H := 660

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

	if GameState.pending_intercept_state.is_empty():
		var beat: Dictionary = GameState.get_beat_after_battle(GameState.current_battle)
		_card_id = GameState.draw_intercept_card(str(beat.get("tier", "minor")))
		if _card_id == "":
			_continue_to_battle()
			return
		GameState.begin_intercept_state(_card_id)
	else:
		_card_id = str(GameState.pending_intercept_state.get("card_id", ""))
	if _card_id == "":
		_continue_to_battle()
		return
	_card = GameState.INTERCEPT_CARDS.get(_card_id, {})
	_choice = GameState.pending_intercept_state.get("choice", {}) as Dictionary
	_picked_hero_id = str(GameState.pending_intercept_state.get("picked_hero_id", ""))
	_gear_context = GameState.pending_intercept_state.get("gear_context", {}) as Dictionary

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
	# Safe area: +insets so the window clears the grown header band and the
	# gesture bar on cutout devices (0 on desktop — no-op).
	margin.add_theme_constant_override("margin_top", 150 + PixelUI.safe_top)
	margin.add_theme_constant_override("margin_bottom", 80 + PixelUI.safe_bottom)
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

	if str(GameState.pending_intercept_state.get("stage", "card")) == "result_pending":
		_resolve_choice()
	else:
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


# Framed scene illustration for this intercept, keyed on the card id. Pixel-art
# is nearest-filtered and cover-cropped to a fixed banner height.
func _add_event_banner(card_id: String) -> void:
	var path: String = "%s%s.png" % [EVENT_ART_DIR, card_id]
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path) as Texture2D
	if tex == null:
		return
	# Fit the whole image inside the transmission panel's inner width x BANNER_MAX_H.
	var side: int = PixelUI.screen_frame_side_margin()
	var max_w: float = float(ProjectSettings.get_setting("display/window/size/viewport_width", 1080)) - 2.0 * side - 2.0 * 36.0
	var frame := PixelUI.make_scene_banner(tex, max_w, float(BANNER_MAX_H), PixelUI.DT_AMBER)
	_stage_box.add_child(frame)
	_add_gap(12)


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
	# Rhythm: scene art banner · small amber event-type label · large title · blank line · body.
	_add_event_banner(_card_id)
	_add_label("INTERCEPT", TYPE_FONT, PixelUI.DT_AMBER, 2)
	_add_label(str(_card.get("name", "")), TITLE_FONT, PixelUI.TEXT_PRIMARY, 3)
	_add_gap(8)
	_add_label(str(_card.get("desc", "")), BODY_FONT, PixelUI.TEXT_PRIMARY, 1)
	_enabled_choice_count = 0
	for choice_variant in _card.get("choices", []):
		var choice: Dictionary = choice_variant
		var enabled: bool = true
		if str(choice.get("pick", "")) == "consumable" and GameState.consumables.is_empty():
			enabled = false
		if str(choice.get("pick", "")) == "gear" and _all_equipped_gear().is_empty():
			enabled = false
		_add_choice_button(str(choice.get("label", "")), _on_choice_pressed.bind(choice), enabled)
		if enabled:
			_enabled_choice_count += 1
	# Zero-options guard (permanent fixture, TRUTH §Run structure): a card with
	# no usable choice (or a failed draw) routes straight to the battle. It MUST
	# advance first (via _continue_to_battle) — routing to go_to_battle directly
	# re-entered the just-won battle and paid its rewards/XP twice (audit A-075).
	if not ChoiceScreenGuardScript.ensure_options("intercept", _enabled_choice_count, _continue_to_battle):
		return
	_add_view_battle_button()


func _on_choice_pressed(choice: Dictionary) -> void:
	AudioManager.play_select()
	_choice = choice
	_picked_hero_id = ""
	_gear_context = {}
	GameState.set_intercept_choice(choice)
	match str(choice.get("pick", "")):
		"hero":
			# Gear-draft cards used to ask for a hero before revealing the gear,
			# then auto-equipped it. Route them directly to the shared picker so
			# its existing recipient confirmation owns that same choice.
			var draft: Dictionary = choice.get("draft", {}) as Dictionary
			if str(draft.get("kind", "")) == "gear":
				_after_picks()
			else:
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
	_add_view_battle_button()


func _on_hero_picked(unit_id: String) -> void:
	AudioManager.play_select()
	_picked_hero_id = unit_id
	GameState.set_intercept_hero_pick(unit_id)
	_after_picks()


func _all_equipped_gear() -> Array:
	var entries: Array = []
	for unit_id_variant in GameState.selected_units:
		var unit_id: String = str(unit_id_variant)
		for gear_id in GameState.gear_by_unit.get(unit_id, []):
			entries.append({"hero_id": unit_id, "gear_id": str(gear_id)})
	return entries


func _show_gear_pick_stage() -> void:
	GameState.begin_intercept_item_request("owned_gear", "SELECT EQUIPPED GEAR", [], _all_equipped_gear())
	SceneManager.go_to_reward_screen()


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
	var options: Array = GameState.roll_intercept_draft(
		str(draft.get("kind", "consumable")),
		str(draft.get("min_rarity", "common")),
		int(draft.get("count", 3))
	)
	if options.is_empty():
		_resolve_choice()
		return
	GameState.begin_intercept_item_request("draft", "CHOOSE INTERCEPT REWARD", options)
	SceneManager.go_to_reward_screen()


func _resolve_choice(drafted_item: ItemData = null) -> void:
	if drafted_item == null:
		var drafted_id: String = str(GameState.pending_intercept_state.get("drafted_item_id", ""))
		if drafted_id != "":
			drafted_item = DataManager.get_item(drafted_id) as ItemData
	if bool(GameState.pending_intercept_state.get("resolved", false)):
		_show_result_stage(str(GameState.pending_intercept_state.get("result_info", "")), drafted_item)
		return
	var info: String = GameState.apply_intercept_effects(_choice.get("effects", []), _picked_hero_id, _gear_context)
	GameState.pending_intercept_state["resolved"] = true
	GameState.pending_intercept_state["result_info"] = info
	GameState.pending_intercept_state["stage"] = "result"
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
	_add_view_battle_button()


func _add_view_battle_button() -> void:
	if GameState.battle_review_state.is_empty():
		return
	_add_choice_button("VIEW BATTLEFIELD", _on_view_battle_pressed)


func _on_view_battle_pressed() -> void:
	AudioManager.play_select()
	GameState.battle_review_return_target = "intercept"
	GameState.entering_battle_review = true
	SceneManager.go_to_battle()


func _continue_to_battle() -> void:
	GameState.pending_choice_request.clear()
	GameState.pending_intercept_state.clear()
	GameState.advance_to_next_battle()
	SceneManager.go_to_battle()
