# Phase 6 reward screen that rolls three item choices and applies the selected reward into GameState.
extends Control

const CARD_WIDTH_FRACTION := 0.75
const CARD_MIN_WIDTH := 310.0
const CARD_MAX_WIDTH := 390.0
const CARD_TOP_SPACER_HEIGHT := 40.0
const CARD_IMAGE_HEIGHT := 104.0
const EFFECT_ICON_SIZE := 62
const EFFECT_VALUE_SIZE := 52
const EFFECT_TAG_SIZE := 34
const BODY_FONT_SIZE := 30
const SMALL_FONT_SIZE := 22
const GEAR_TARGET_BUTTON_FONT_SIZE := 26
const GEAR_TARGET_BUTTON_HEIGHT := 58
const CARD_BG := Color(0.024, 0.040, 0.060, 0.78)
const CARD_BG_HOVER := Color(0.036, 0.060, 0.086, 0.88)
const RARITY_COLORS := {
	"common": Color(0.62, 0.68, 0.74, 1.0),
	"uncommon": Color(0.34, 0.82, 0.50, 1.0),
	"rare": Color(0.34, 0.66, 1.0, 1.0),
	"epic": Color(0.72, 0.34, 0.95, 1.0),
	"legendary": Color(0.96, 0.76, 0.24, 1.0),
}

@onready var background: ColorRect = $Background
@onready var content_vbox: VBoxContainer = $Content/VBox
@onready var battle_summary_label: Label = $Content/VBox/HeaderRow/SummaryLabel
@onready var header_help_button: Button = $Content/VBox/HeaderRow/ButtonRow/ToggleLogButton
@onready var header_auto_button: Button = $Content/VBox/HeaderRow/ButtonRow/AutoTurnButton
@onready var header_back_button: Button = $Content/VBox/HeaderRow/ButtonRow/ReturnToMenuButton
@onready var title_label: Label = $Content/VBox/Title
@onready var summary_label: Label = %SummaryLabel
@onready var inventory_label: Label = %InventoryLabel
@onready var reward_scroll: ScrollContainer = $Content/VBox/RewardScroll
@onready var reward_list_margin: MarginContainer = %RewardListMargin
@onready var reward_content: VBoxContainer = %RewardContent
@onready var reward_top_spacer: Control = %RewardTopSpacer
@onready var reward_title_label: Label = %RewardTitle
@onready var reward_cards: VBoxContainer = %RewardCards
@onready var footer_label: Label = %FooterLabel

var _help_overlay: Control = null


func _ready() -> void:
	_apply_visual_theme()
	resized.connect(_update_reward_layout)
	header_help_button.pressed.connect(_on_help_button_pressed)
	header_back_button.pressed.connect(_on_return_to_menu_button_pressed)
	if GameState.pending_reward_item_ids.is_empty():
		GameState.prepare_battle_rewards()
	_update_battle_header()
	_refresh_inventory_summary()
	_refresh_summary("")
	_build_reward_cards()


func _on_return_to_menu_button_pressed() -> void:
	GameState.reset_run()
	SceneManager.go_to_unit_select()


func _on_help_button_pressed() -> void:
	if _help_overlay == null or not is_instance_valid(_help_overlay):
		_build_help_overlay()
	_help_overlay.visible = true
	_help_overlay.move_to_front()


func _hide_help_overlay() -> void:
	if _help_overlay != null and is_instance_valid(_help_overlay):
		_help_overlay.visible = false


func _build_help_overlay() -> void:
	_help_overlay = Control.new()
	_help_overlay.name = "RewardHelpOverlay"
	_help_overlay.visible = false
	_help_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.z_as_relative = false
	_help_overlay.z_index = 200
	_help_overlay.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_hide_help_overlay()
		elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
			_hide_help_overlay()
	)
	add_child(_help_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.005, 0.007, 0.012, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_help_overlay.add_child(dim)

	var outer := MarginContainer.new()
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 28)
	outer.add_theme_constant_override("margin_top", 120)
	outer.add_theme_constant_override("margin_right", 28)
	outer.add_theme_constant_override("margin_bottom", 120)
	_help_overlay.add_child(outer)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUI.style_panel(panel, Color(0.018, 0.026, 0.044, 0.98), Color(0.36, 0.55, 0.78, 0.95), 4, 0)
	outer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	var title := _make_label("REWARD HELP", 32, PixelUI.TEXT_PRIMARY, 3)
	content.add_child(title)
	for line in [
		"Choose one reward to continue the run.",
		"Gear attaches to the selected unit permanently.",
		"EQUIPPED shows current gear totals.",
		"AFTER shows totals if you take this gear.",
		"GAIN shows only what this reward adds.",
	]:
		content.add_child(_make_label(line, BODY_FONT_SIZE, PixelUI.TEXT_MUTED, 1))


func _build_reward_cards() -> void:
	for child in reward_cards.get_children():
		child.queue_free()

	_update_reward_layout()
	var reward_items: Array = GameState.get_pending_reward_items()
	for item_variant in reward_items:
		var item: ItemData = item_variant as ItemData
		if item == null:
			continue
		var card: PanelContainer = _create_reward_card(item)
		reward_cards.add_child(card)
	call_deferred("_update_reward_layout")


func _update_reward_layout() -> void:
	if reward_cards == null:
		return
	var card_width: float = _get_card_width()
	reward_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	reward_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_cards.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	reward_content.add_theme_constant_override("separation", 18)
	reward_cards.add_theme_constant_override("separation", 18)
	reward_list_margin.add_theme_constant_override("margin_left", 0)
	reward_list_margin.add_theme_constant_override("margin_right", 0)
	reward_list_margin.add_theme_constant_override("margin_top", 0)
	reward_list_margin.add_theme_constant_override("margin_bottom", 24)
	if reward_top_spacer != null:
		reward_top_spacer.custom_minimum_size = Vector2(0, CARD_TOP_SPACER_HEIGHT)
	for child in reward_cards.get_children():
		var panel: PanelContainer = child as PanelContainer
		if panel != null:
			panel.custom_minimum_size = Vector2(card_width, 0)
			panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _get_card_width() -> float:
	var available_width: float = reward_scroll.size.x if reward_scroll != null else size.x
	if available_width <= 1.0:
		available_width = get_viewport().get_visible_rect().size.x
	available_width = maxf(available_width - 24.0, 1.0)
	return clampf(available_width * CARD_WIDTH_FRACTION, CARD_MIN_WIDTH, CARD_MAX_WIDTH)


func _create_reward_card(item: ItemData) -> PanelContainer:
	var card_width: float = _get_card_width()
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(card_width, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.clip_contents = false
	_style_reward_panel(panel, item, false)
	panel.mouse_entered.connect(_style_reward_panel.bind(panel, item, true))
	panel.mouse_exited.connect(_style_reward_panel.bind(panel, item, false))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	vbox.add_child(_create_item_image_area(item))
	vbox.add_child(_create_card_header(item))
	vbox.add_child(_create_type_rarity_row(item))
	vbox.add_child(_create_effect_row(_build_effect_parts_for_item(item), true))
	vbox.add_child(_create_description_label(item.description))
	if item.item_type == "gear":
		_add_gear_selector(vbox, item)

	var action_button := Button.new()
	action_button.custom_minimum_size = Vector2(0, 72)
	action_button.text = _build_claim_button_text(item)
	PixelUI.style_button(action_button, Color(0.022, 0.034, 0.050, 0.95), _get_item_accent(item), 26)
	action_button.pressed.connect(_on_claim_reward_pressed.bind(item.id, vbox))
	vbox.add_child(action_button)

	return panel


func _style_reward_panel(panel: PanelContainer, item: ItemData, hovered: bool) -> void:
	var bg: Color = CARD_BG_HOVER if hovered else CARD_BG
	var border: Color = _get_item_accent(item).lightened(0.12 if hovered else 0.0)
	PixelUI.style_panel(panel, bg, border, 4 if hovered else 3, 0)


func _create_card_header(item: ItemData) -> HBoxContainer:
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 8)

	var title := _make_label(item.display_name, 38, _get_item_accent(item), 3)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	return header


func _create_item_image_area(item: ItemData) -> PanelContainer:
	var image_area := PanelContainer.new()
	image_area.custom_minimum_size = Vector2(0, CARD_IMAGE_HEIGHT)
	image_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	image_area.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	image_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUI.style_panel(image_area, Color(0.012, 0.020, 0.034, 0.70), _get_item_accent(item).darkened(0.20), 1, 0)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image_area.add_child(center)

	if item.icon != null:
		var texture_rect := TextureRect.new()
		texture_rect.custom_minimum_size = Vector2(70, 70)
		texture_rect.texture = item.icon
		texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(texture_rect)
	else:
		var icon_label := _make_label(_get_item_icon_char(item.icon_key), 52, _get_item_accent(item), 2)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		center.add_child(icon_label)
	return image_area


func _create_type_rarity_row(item: ItemData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	row.add_child(_create_type_badge(item))

	var rarity := _make_label(item.rarity.to_upper(), SMALL_FONT_SIZE, _get_item_accent(item), 1)
	rarity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rarity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(rarity)
	return row


func _create_type_badge(item: ItemData) -> PanelContainer:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(180, 38)
	PixelUI.style_panel(badge, _get_item_type_color(item).darkened(0.45), _get_item_type_color(item), 2, 0)

	var label := _make_label(_format_item_type_label(item), SMALL_FONT_SIZE, PixelUI.TEXT_PRIMARY, 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(label)
	return badge


func _add_gear_selector(vbox: VBoxContainer, item: ItemData) -> void:
	var picker := VBoxContainer.new()
	picker.name = "GearTargetPicker"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_theme_constant_override("separation", 8)
	vbox.add_child(picker)

	var label := _make_label("EQUIP TO", SMALL_FONT_SIZE, PixelUI.TEXT_MUTED, 1)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_child(label)

	var button_group := ButtonGroup.new()
	var selected_unit_id := ""
	for unit_id_variant in GameState.selected_units:
		var unit_id: String = str(unit_id_variant)
		var unit: UnitData = DataManager.get_unit(unit_id) as UnitData
		if unit == null:
			continue
		if selected_unit_id == "":
			selected_unit_id = unit_id
		var target_button := Button.new()
		target_button.name = "GearTargetButton"
		target_button.text = unit.display_name
		target_button.toggle_mode = true
		target_button.button_group = button_group
		target_button.custom_minimum_size = Vector2(0, GEAR_TARGET_BUTTON_HEIGHT)
		target_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		target_button.set_meta("unit_id", unit_id)
		var captured_unit_id := unit_id
		target_button.pressed.connect(func() -> void:
			_set_gear_target_selection(picker, captured_unit_id)
		)
		picker.add_child(target_button)

	if selected_unit_id != "":
		_set_gear_target_selection(picker, selected_unit_id)


func _set_gear_target_selection(picker: VBoxContainer, unit_id: String) -> void:
	picker.set_meta("selected_unit_id", unit_id)
	for child in picker.get_children():
		var button := child as Button
		if button == null:
			continue
		var is_selected: bool = str(button.get_meta("unit_id", "")) == unit_id
		button.button_pressed = is_selected
		_style_gear_target_button(button, is_selected)


func _style_gear_target_button(button: Button, selected: bool) -> void:
	if selected:
		PixelUI.style_button(button, Color(0.045, 0.150, 0.100, 0.96), PixelUI.HERO_ACCENT, GEAR_TARGET_BUTTON_FONT_SIZE)
	else:
		PixelUI.style_button(button, Color(0.018, 0.028, 0.044, 0.95), PixelUI.LINE_DIM, GEAR_TARGET_BUTTON_FONT_SIZE)


func _create_effect_row(parts: Array, primary: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 7 if primary else 5)
	if parts.is_empty():
		row.add_child(_make_label("None", BODY_FONT_SIZE, PixelUI.TEXT_MUTED, 1))
		return row
	for part_variant in parts:
		var part: Dictionary = part_variant
		row.add_child(_create_effect_group(part, primary))
	return row


func _create_effect_group(part: Dictionary, primary: bool) -> HBoxContainer:
	var kind: String = str(part.get("kind", ""))
	var icon: String = str(part.get("icon", _icon_for_kind(kind)))
	var text: String = str(part.get("text", ""))
	var duration: int = int(part.get("duration", 0))
	var color: Color = _color_for_kind(kind)

	var group := HBoxContainer.new()
	group.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.add_theme_constant_override("separation", 3)

	if icon != "":
		var icon_label := Label.new()
		icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_label.text = icon
		icon_label.add_theme_font_size_override("font_size", EFFECT_ICON_SIZE if primary else EFFECT_TAG_SIZE)
		icon_label.add_theme_color_override("font_color", color)
		icon_label.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.025, 0.98))
		icon_label.add_theme_constant_override("outline_size", 2)
		group.add_child(icon_label)

	var value_label := _make_label(text, EFFECT_VALUE_SIZE if primary else EFFECT_TAG_SIZE, color.lerp(PixelUI.TEXT_PRIMARY, 0.25), 2)
	group.add_child(value_label)

	if duration > 1:
		var duration_label := _make_label("(%dT)" % duration, EFFECT_TAG_SIZE, PixelUI.TEXT_MUTED, 1)
		group.add_child(duration_label)
	return group


func _build_effect_parts_for_item(item: ItemData) -> Array:
	return _build_effect_parts_from_effect(item.effect, item.target_kind)


func _build_effect_parts_from_effect(effect: Dictionary, target_kind: String = "") -> Array:
	var effect_type: String = str(effect.get("type", ""))
	match effect_type:
		"heal":
			return [_part("heal", "+%d HP" % int(effect.get("amount", 0)))]
		"shield":
			return [_part("shield", "%d" % int(effect.get("amount", 0)), int(effect.get("shT", 0)))]
		"rollBuff":
			return [_part("roll", "+%d" % int(effect.get("amount", 0)), int(effect.get("turns", 0)))]
		"revive":
			return [_part("revive", "REVIVE %d%%" % int(effect.get("pct", 0)), 0, "")]
		"cloak":
			return [_part("cloak", "CLOAK", 0, "")]
		"cloakAll":
			return [_part("cloak", "CLOAK ALL", 0, "")]
		"enemyRfe":
			return [_part("rfm", "-%d" % int(effect.get("amount", 0)), int(effect.get("rfT", 0)))]
		"enemyDmg":
			return [_part("dmg", "%d" % int(effect.get("amount", 0)))]
		"enemyDot":
			return [_part("dot", "%d" % int(effect.get("amount", 0)), int(effect.get("dT", 0)))]
		"xpBoost":
			return [_part("xp", "+%d XP" % int(effect.get("amount", 0)), 0, "★")]
		"enemyRerollDie":
			return [_part("roll", "REROLL", 0)]
		"enemyRerollAll":
			return [_part("roll", "REROLL ALL", 0)]
		"enemyDieFreeze":
			return [_part("freeze", "FREEZE", int(effect.get("skips", 0)), "❄")]
		"rollBonus":
			return [_part("roll", "+%d" % int(effect.get("amount", 0)))]
		"battleStartShield":
			return [_part("shield", "%d" % int(effect.get("amount", 0)))]
		"maxHpBonus":
			return [_part("heal", "+%d MAX HP" % int(effect.get("amount", 0)))]
		"dotDmgBonus":
			return [_part("dot", "+%d DOT" % int(effect.get("amount", 0)))]
		"battleStartCloak":
			return [_part("cloak", "CLOAK START", 0, "")]
		"healOnKill":
			return [_part("heal", "+%d KILL" % int(effect.get("amount", 0)))]
		"protocolOnBattleStart":
			return [_part("protocol", "+%d START" % int(effect.get("amount", 0)), 0, "⚡")]
		"surviveOnce":
			return [_part("survive", "SURVIVE", 0, "")]
		"firstAbilityDmgBonus":
			return [_part("dmg", "+%d FIRST" % int(effect.get("amount", 0)))]
		"dmgReduction":
			return [_part("shield", "-%d DMG" % int(effect.get("amount", 0)))]
		"enemyDmgMult":
			return [_part("shield", "ENEMY %d%%" % int(round(float(effect.get("mult", 1.0)) * 100.0)))]
		"battleStartHalfHp":
			return [_part("dmg", "50% START")]
		"heroShieldPerTurn":
			return [_part("shield", "+%d TURN" % int(effect.get("amount", 0)))]
		"heroHealPerTurn":
			return [_part("heal", "+%d TURN" % int(effect.get("amount", 0)))]
		"enemyDotPermanent":
			return [_part("dot", "%d START" % int(effect.get("amount", 0)))]
		"heroDmgMult":
			return [_part("dmg", "%d%%" % int(round(float(effect.get("mult", 1.0)) * 100.0)))]
		"enemyStartRfe":
			return [_part("rfm", "-%d START" % int(effect.get("amount", 0)))]
		"heroStartRollBuff":
			return [_part("roll", "+%d START" % int(effect.get("amount", 0)))]
		"dotAmplified":
			return [_part("dot", "+%d DOT" % int(effect.get("bonus", 0)))]
		"auraEnemyDmg":
			return [_part("dmg", "%d TURN" % int(effect.get("amount", 0)))]
		"protocolFree":
			return [_part("protocol", "0 COST", 0, "⚡")]
		"enemyHpEscalation":
			return [_part("dot", "-%d MAX" % int(effect.get("reductionPerBattle", 0)))]
		"chainReaction":
			return [_part("dmg", "%d CHAIN" % int(effect.get("amount", 0)))]
	if target_kind != "":
		return [_part("tag", target_kind.to_upper(), 0, "")]
	return []


func _part(kind: String, text: String, duration: int = 0, icon: String = "") -> Dictionary:
	var part_icon: String = icon if icon != "" else _icon_for_kind(kind)
	return {
		"kind": kind,
		"text": text,
		"duration": duration,
		"icon": part_icon,
	}


func _icon_for_kind(kind: String) -> String:
	match kind.to_lower():
		"dmg", "damage", "blast", "protocol":
			return "⚡"
		"shield":
			return "🛡"
		"heal":
			return "✚"
		"dot", "poison":
			return "☠"
		"roll", "rfe", "rfm":
			return "🎲"
		"freeze":
			return "❄"
	return ""


func _color_for_kind(kind: String) -> Color:
	match kind.to_lower():
		"protocol", "xp":
			return PixelUI.GOLD_ACCENT
		"survive", "tag":
			return PixelUI.TEXT_PRIMARY
	return PixelUI.effect_color(kind)


func _create_description_label(text: String) -> Label:
	var label := _make_label(text, BODY_FONT_SIZE, PixelUI.TEXT_MUTED, 1)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return label


func _make_label(text: String, font_size: int, color: Color, outline: int = 1) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUI.style_label(label, font_size, color, outline)
	return label


func _get_item_icon_char(icon_key: String) -> String:
	match icon_key:
		"heart":
			return "♥"
		"shield":
			return "⬡"
		"die":
			return "⚄"
		"bolt":
			return "⚡"
		"skull":
			return "☠"
		"cloak":
			return "◉"
		"star":
			return "★"
	return "●"


func _find_selected_gear_target_id(root: Node) -> String:
	var picker := root.find_child("GearTargetPicker", true, false)
	if picker == null:
		return ""
	return str(picker.get_meta("selected_unit_id", ""))


func _build_claim_button_text(item: ItemData) -> String:
	if item.item_type == "gear":
		return "Equip Gear"
	if item.item_type == "relic":
		return "Claim Relic"
	return "Take Item"


func _on_claim_reward_pressed(item_id: String, target_root: Node) -> void:
	var item: ItemData = DataManager.get_item(item_id) as ItemData
	if item == null:
		return

	var target_unit_id := ""
	if item.item_type == "gear":
		if target_root == null:
			footer_label.text = "No valid unit target available for this gear."
			return
		target_unit_id = _find_selected_gear_target_id(target_root)
		if target_unit_id == "":
			footer_label.text = "Choose a unit for this gear."
			return

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


func _refresh_summary(_extra_text: String) -> void:
	summary_label.text = ""


func _update_battle_header() -> void:
	var operation: OperationData = DataManager.get_operation(GameState.selected_operation_id) as OperationData
	var series_name: String = operation.display_name if operation != null and operation.display_name != "" else "Operation"
	battle_summary_label.text = "%s  %s" % [series_name, GameState.get_battle_progress_text()]


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
	content_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	content_vbox.add_theme_constant_override("separation", 8)
	reward_list_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	reward_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_cards.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if reward_top_spacer != null:
		reward_top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reward_top_spacer.custom_minimum_size = Vector2(0, CARD_TOP_SPACER_HEIGHT)
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_auto_button.visible = false
	PixelUI.style_label(battle_summary_label, 56, PixelUI.TEXT_PRIMARY, 2)
	battle_summary_label.custom_minimum_size.y = 78
	PixelUI.style_button(header_help_button, PixelUI.BG_PANEL_ALT, PixelUI.LINE_DIM, 28)
	PixelUI.style_button(header_back_button, PixelUI.BG_PANEL_ALT, PixelUI.LINE_DIM, 28)
	title_label.text = "Choose Reward"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.visible = false
	reward_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_title_label.custom_minimum_size = Vector2(0, 82)
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.visible = false
	inventory_label.visible = false
	footer_label.visible = false
	PixelUI.style_label(title_label, 44, PixelUI.GOLD_ACCENT, 2)
	PixelUI.style_label(reward_title_label, 62, PixelUI.GOLD_ACCENT, 3)
	PixelUI.style_label(summary_label, 24, PixelUI.TEXT_PRIMARY, 2)
	PixelUI.style_label(inventory_label, 20, PixelUI.TEXT_MUTED, 1)
	PixelUI.style_label(footer_label, 20, PixelUI.TEXT_MUTED, 1)
	reward_content.add_theme_constant_override("separation", 18)
	reward_cards.add_theme_constant_override("separation", 18)


func _get_item_accent(item: ItemData) -> Color:
	if item.item_type == "relic":
		return PixelUI.GOLD_ACCENT
	return RARITY_COLORS.get(item.rarity.to_lower(), RARITY_COLORS["common"])


func _get_item_type_color(item: ItemData) -> Color:
	match item.item_type:
		"gear":
			return PixelUI.LINE_BRIGHT
		"consumable":
			return PixelUI.HERO_ACCENT
		"relic":
			return PixelUI.GOLD_ACCENT
	return PixelUI.TEXT_MUTED


func _format_item_type_label(item: ItemData) -> String:
	match item.item_type:
		"gear":
			return "GEAR"
		"consumable":
			return "CONSUMABLE"
		"relic":
			return "RELIC"
	return item.item_type.to_upper()
