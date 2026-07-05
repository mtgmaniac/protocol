# Route Fork (pkg7.3): a fork beat before the next battle — two route cards
# in the reward-screen chrome. STANDARD runs the fight as rolled; FLAGGED runs
# the same comp with one modifier chip and "SUPPLY GRADE +2" (the reward
# rarity ladder rolls two rows deeper, capped at row 10).
extends Control

const TITLE_FONT := 62
const CARD_TITLE_FONT := 46
const BODY_FONT := 36
const CHIP_FONT := 30
const BUTTON_FONT := 38

var _modifier_id: String = ""


func _ready() -> void:
	PersistentHeader.set_run_active(true)
	PersistentHeader.clear_battle_actions()
	var operation: OperationData = DataManager.get_operation(GameState.selected_operation_id) as OperationData
	if operation != null:
		PersistentHeader.update_progress(GameState.current_battle, GameState.total_battles, operation.battle_name())

	_modifier_id = GameState.roll_route_modifier()

	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.070, 0.095, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 70)
	margin.add_theme_constant_override("margin_top", 170)
	margin.add_theme_constant_override("margin_bottom", 90)
	add_child(margin)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 34)
	margin.add_child(column)

	var title := Label.new()
	title.text = "ROUTE FORK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.style_label(title, TITLE_FONT, PixelUI.GOLD_ACCENT, 3)
	column.add_child(title)

	var blurb := Label.new()
	blurb.text = "Two paths reach the same fight. One is flagged."
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelUI.style_label(blurb, BODY_FONT, PixelUI.TEXT_MUTED, 1)
	column.add_child(blurb)

	# The NEXT battle's comp (we haven't advanced yet): 0-based index equals
	# the 1-based current battle number.
	var comp_names: Array = []
	var next_index: int = GameState.current_battle
	if next_index >= 0 and next_index < GameState.resolved_battle_comps.size():
		comp_names = (GameState.resolved_battle_comps[next_index] as Dictionary).get("names", [])

	# Standard card previews the comp as rolled; the flagged card previews the
	# comp shaped at roll time (fix-1.5) so what you see is what you fight.
	column.add_child(_build_route_card(false, comp_names))
	if _modifier_id != "":
		var flagged_names: Array = (GameState.pending_flagged_comp as Dictionary).get("names", comp_names)
		column.add_child(_build_route_card(true, flagged_names))


func _build_route_card(flagged: bool, comp_names: Array) -> PanelContainer:
	var panel := PanelContainer.new()
	var accent: Color = PixelUI.DT_RUST if flagged else PixelUI.DT_CYAN
	panel.add_theme_stylebox_override("panel", PixelUI.make_hard_style(Color(0.024, 0.040, 0.060, 0.92), accent, 4))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var card_title := Label.new()
	card_title.text = "FLAGGED ROUTE" if flagged else "STANDARD ROUTE"
	PixelUI.style_label(card_title, CARD_TITLE_FONT, accent, 3)
	vbox.add_child(card_title)

	var comp := Label.new()
	comp.text = "Hostiles: %s" % (", ".join(PackedStringArray(comp_names)) if not comp_names.is_empty() else "unknown")
	comp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelUI.style_label(comp, BODY_FONT, PixelUI.TEXT_PRIMARY, 1)
	vbox.add_child(comp)

	if flagged:
		var modifier_info: Dictionary = GameState.BATTLE_MODIFIERS.get(_modifier_id, {})
		var mod_chip := Label.new()
		mod_chip.text = "⚠ %s — %s" % [str(modifier_info.get("name", _modifier_id)), str(modifier_info.get("desc", ""))]
		mod_chip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		PixelUI.style_label(mod_chip, CHIP_FONT, PixelUI.DT_RUST, 1)
		vbox.add_child(mod_chip)
		var reward_chip := Label.new()
		reward_chip.text = "◆ SUPPLY GRADE +2"
		PixelUI.style_label(reward_chip, CHIP_FONT, PixelUI.GOLD_ACCENT, 1)
		vbox.add_child(reward_chip)
	else:
		var plain_chip := Label.new()
		plain_chip.text = "No modifier. Standard supply."
		PixelUI.style_label(plain_chip, CHIP_FONT, PixelUI.TEXT_MUTED, 1)
		vbox.add_child(plain_chip)

	var choose := Button.new()
	choose.focus_mode = Control.FOCUS_NONE
	choose.custom_minimum_size = Vector2(0, 96)
	choose.text = "TAKE THE FLAGGED ROUTE" if flagged else "TAKE THE STANDARD ROUTE"
	PixelUI.style_button(choose, Color(0.022, 0.034, 0.050, 0.95), accent, BUTTON_FONT)
	choose.pressed.connect(_on_route_chosen.bind(flagged))
	vbox.add_child(choose)
	return panel


func _on_route_chosen(flagged: bool) -> void:
	AudioManager.play_select()
	if flagged:
		GameState.accept_flagged_route(_modifier_id)
	GameState.advance_to_next_battle()
	SceneManager.go_to_battle()
