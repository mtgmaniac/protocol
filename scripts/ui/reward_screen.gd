# Phase 6 reward / item picker. Rolls three reward choices and lets the player SINGLE-
# select one, then commit with a single confirm button at the bottom of the screen.
#
# Polish Build B (Kev ruling, supersedes the old perfect-square card): ORDINARY
# rewards are WIDE HORIZONTAL ROWS on the Reward component — large item art on
# the LEFT (integer-scaled, PixelUI.make_integer_icon), name + rarity/type +
# effect info on the RIGHT with room to breathe (fewer forced line breaks). The
# full row is the tap target; tapping SELECTS (Selected component + brackets),
# the bottom CONFIRM commits. RELIC offers stay ceremonial: two large
# Major-event cards (gold), deliberately a tier above ordinary rows.
#
# All colors/borders come from PixelUI components/tokens; layout sizes are named
# consts (this codebase's centralization convention). No hardcoded scene values.
extends Control

const ChoiceScreenGuardScript := preload("res://scripts/ui/choice_screen_guard.gd")


# Ordinary reward ROW geometry (logical px). Art left, info right; the whole
# row is the tap target. ROW_MIN_HEIGHT reserves 2x standard art, generous
# padding, and stable text slots without relying on description length.
const ROW_MIN_HEIGHT := 304.0
const ROW_ICON_BOX := 256.0    # standard 128px item art renders at 2x
const ROW_PADDING := 24
const ROW_HGAP := 28
const ROW_NAME_FONT := 48
const ROW_NAME_SLOT_HEIGHT := 62.0
const ROW_META_SLOT_HEIGHT := 42.0
const ROW_EFFECT_SLOT_HEIGHT := 112.0
const ROW_META_FONT := 32      # "UNCOMMON GEAR" — metadata tier, ALL CAPS

# Relic ceremonial card geometry (Major-event tier — deliberately larger).
const CARD_WIDTH_FRACTION := 0.94
const CARD_MIN_WIDTH := 480.0
const CARD_MAX_WIDTH := 1000.0
const CARD_TOP_SPACER_HEIGHT := 24.0
const CARD_PADDING := 18
const CARD_SEP := 9
const RELIC_ICON_BOX := 256.0  # standard 128px relic art renders at 2x
const RELIC_DESC_MIN_HEIGHT := 112.0

# Corner-bracket selection indicator (L per corner = horizontal arm + vertical arm).
const BRACKET_LEN := 46.0
const BRACKET_THICK := 8.0
const BRACKET_INSET := 8.0

# Fonts.
const NAME_FONT_SIZE := 46
const LABEL_FONT_SIZE := PixelUI.FONT_INFO_MIN  # rarity+type line — a pick signal (UI review S-1)
const BODY_FONT_SIZE := 36
# "UNCOMMON GEAR" line — a header, the way the unit card's name reads (Batch 3).
const TYPE_HEADER_FONT := 42
# Footer read-back ("EQUIP TO: AVALANCHE") — the commit cue, sized well above
# the INFO floor (Batch 3: was 28, under the S-1 floor and easy to miss).
const FOOTER_FONT := 44
const FOOTER_RESERVED_HEIGHT := 64

# Gear "equip to" chooser — sized large for mobile tap targets.
const GEAR_TARGET_TITLE_FONT := 50
const GEAR_TARGET_BUTTON_FONT_SIZE := 48
const GEAR_TARGET_BUTTON_HEIGHT := 132
const GEAR_TARGET_WIDTH_FRACTION := 0.92
const GEAR_TARGET_MIN_WIDTH := 480.0
const GEAR_TARGET_MAX_WIDTH := 760.0

# Effect pips — a notch larger than the shared PROFILE_CARD (icon 40 / value 48) so the
# stat row reads at the same weight as the bigger card, without going full readout size.
const PIP_PROFILE := {
	"icon_size": 54,
	"value_font": 64,
	"duration_ratio": 0.6,
	"icon_value_gap": 5,
	"group_min_width": 100,
	"outline": 2,
	"duration_outline": 2,
}

# Confirm button — exact clone of the squad screen's DEPLOY button (home_screen.gd).
const CONFIRM_FONT := 84
const CONFIRM_HEIGHT := 130
const CONFIRM_IDLE_BG := Color(0.040, 0.050, 0.060, 1.0)
const CONFIRM_IDLE_BORDER := Color(0.13, 0.15, 0.17, 1.0)
const CONFIRM_IDLE_TEXT := Color(0.34, 0.38, 0.42, 1.0)

@onready var background: ColorRect = $Background
@onready var content_vbox: VBoxContainer = $Content/VBox
@onready var title_label: Label = $Content/VBox/Title
@onready var summary_label: Label = %SummaryLabel
@onready var inventory_label: Label = %InventoryLabel
@onready var reward_scroll: ScrollContainer = $Content/VBox/RewardScroll
@onready var reward_list_margin: MarginContainer = %RewardListMargin
@onready var reward_content: VBoxContainer = %RewardContent
@onready var reward_top_spacer: Control = %RewardTopSpacer
@onready var reward_title_label: Label = %RewardTitle
@onready var reward_group_top_spacer: Control = %RewardGroupTopSpacer
@onready var reward_cards: VBoxContainer = %RewardCards
@onready var reward_group_bottom_spacer: Control = %RewardGroupBottomSpacer
@onready var footer_label: Label = %FooterLabel

var _help_overlay: Control = null
var _gear_target_overlay: Control = null
var _consumable_swap_overlay: Control = null

# View-Battlescreen button: a secondary read-only return to the finished battle.
const VIEW_BATTLE_FONT := 34
const VIEW_BATTLE_HEIGHT := 96

var _selected_item_id: String = ""
var _selected_gear_unit_id: String = ""   # unit chosen in the equip chooser (gear only)
var _selected_swap_consumable_id: String = ""  # held consumable to discard when full (consumable only)
var _cards: Dictionary = {}   # item_id -> { panel, brackets: Array[ColorRect], accent: Color }
var _confirm_button: Button = null
var _choice_request: Dictionary = {}


func _ready() -> void:
	_choice_request = GameState.pending_choice_request.duplicate(true)
	# Safe area (device cutout / gesture bar): drop below the grown header band
	# and lift the footer clear. Both insets are 0 on desktop (no-op); the
	# authored .tscn offsets (156 / −12) stay the base.
	var content: MarginContainer = $Content
	content.offset_top += float(PixelUI.safe_top)
	content.offset_bottom -= float(PixelUI.safe_bottom)
	# Rows span the full width, so they consume the side insets too (Build B).
	content.offset_left += float(PixelUI.safe_left)
	content.offset_right -= float(PixelUI.safe_right)
	_apply_visual_theme()
	resized.connect(_update_reward_layout)
	# Header bar lives in the PersistentHeader autoload; bind this screen's handlers.
	PersistentHeader.bind_battle_actions(
		_on_help_button_pressed,
		_on_header_unavailable_pressed.bind("Auto turn is unavailable while choosing a reward."),
		_on_header_unavailable_pressed.bind("Auto battle is unavailable while choosing a reward."),
		_on_return_to_menu_button_pressed,
	)
	if _choice_request.is_empty() and GameState.pending_reward_item_ids.is_empty():
		GameState.prepare_battle_rewards()
	_update_battle_header()
	_refresh_inventory_summary()
	_build_reward_cards()
	_build_view_battle_button()
	_build_confirm_button()
	call_deferred("_restore_picker_ui_state")


func _exit_tree() -> void:
	if is_instance_valid(PersistentHeader):
		PersistentHeader.clear_battle_actions()


func _on_return_to_menu_button_pressed() -> void:
	AudioManager.play_select()
	GameState.reset_run()
	SceneManager.go_to_unit_select()


func _on_help_button_pressed() -> void:
	AudioManager.play_select()
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

	_help_overlay.add_child(PixelUI.make_modal_scrim())

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
	# Component: Modal (the legacy sci-fi ninepatch frame was a second frame
	# language; the scrim above already carries elevation).
	PixelUI.style_component(panel, PixelUI.COMPONENT_MODAL)
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

	var title := _make_label("REWARD HELP", 42, PixelUI.TEXT_PRIMARY, 3)
	content.add_child(title)
	for line in [
		"Tap a reward to select it; tap another to switch.",
		"The selected reward lights up cyan.",
		"Border color = rarity; the boxed word = type.",
		"Press CONFIRM to take the selected reward.",
	]:
		content.add_child(_make_label(line, BODY_FONT_SIZE, PixelUI.TEXT_MUTED, 1))


# ─── Reward cards ───────────────────────────────────────────────────────────────
func _build_reward_cards() -> void:
	for child in reward_cards.get_children():
		child.queue_free()
	_cards.clear()
	_selected_item_id = ""

	_update_reward_layout()
	var offers: Array = _choice_request.get("offers", []) if not _choice_request.is_empty() else []
	if offers.is_empty() and _choice_request.is_empty():
		for item_variant in GameState.get_pending_reward_items():
			var item: ItemData = item_variant as ItemData
			if item != null:
				offers.append({"selection_id": item.id, "item_id": item.id})
	for offer_variant in offers:
		var offer: Dictionary = offer_variant as Dictionary
		var selection_id: String = str(offer.get("selection_id", ""))
		var item: ItemData = DataManager.get_item(str(offer.get("item_id", ""))) as ItemData
		if item == null:
			continue
		# Two tiers on purpose (Build B): relic offers are ceremonial Major-event
		# cards; everything ordinary is a wide Reward-component row.
		if item.item_type == "relic":
			reward_cards.add_child(_create_relic_card(item, selection_id))
		else:
			reward_cards.add_child(_create_reward_row(item, selection_id, str(offer.get("hero_id", ""))))
	# Zero-options guard (permanent fixture, TRUTH §Run structure): an empty
	# offer must never strand the run on a dead picker.
	if not ChoiceScreenGuardScript.ensure_options("reward", reward_cards.get_child_count(), _auto_resolve_empty_offer):
		return
	_refresh_selection()
	call_deferred("_update_reward_layout")


func _update_reward_layout() -> void:
	if reward_cards == null:
		return
	var card_width: float = _get_card_width()
	reward_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reward_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reward_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	reward_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The inner column fills the scroll viewport. Paired flexible spacers place
	# the choice group in the usable well below the heading; when content exceeds
	# that well they collapse and the existing scroll path takes over.
	reward_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reward_content.alignment = BoxContainer.ALIGNMENT_BEGIN
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
	for spacer in [reward_group_top_spacer, reward_group_bottom_spacer]:
		if spacer != null:
			spacer.custom_minimum_size = Vector2.ZERO
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for child in reward_cards.get_children():
		var panel: PanelContainer = child as PanelContainer
		if panel == null:
			continue
		if str(panel.get_meta("reward_kind", "row")) == "relic":
			# Ceremonial tier: large centered card, natural content height.
			panel.custom_minimum_size = Vector2(card_width, 0)
			panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		else:
			# Ordinary tier: full-width row; the whole width is the tap target.
			panel.custom_minimum_size = Vector2(0, ROW_MIN_HEIGHT)
			panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _get_card_width() -> float:
	var available_width: float = reward_scroll.size.x if reward_scroll != null else size.x
	if available_width <= 1.0:
		available_width = get_viewport().get_visible_rect().size.x
	available_width = maxf(available_width - 24.0, 1.0)
	return clampf(available_width * CARD_WIDTH_FRACTION, CARD_MIN_WIDTH, CARD_MAX_WIDTH)


# Ordinary reward ROW (Build B): art LEFT at 128 integer scale, name + meta +
# effect info RIGHT. Full width = the tap target; tap selects, CONFIRM commits.
func _create_reward_row(item: ItemData, selection_id: String = "", owner_id: String = "") -> PanelContainer:
	if selection_id == "":
		selection_id = item.id
	var accent: Color = _get_item_accent(item)

	var panel := PanelContainer.new()
	panel.name = "RewardRow"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(0, ROW_MIN_HEIGHT)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.set_meta("item_id", selection_id)
	panel.set_meta("reward_kind", "row")
	_style_card_panel(panel, accent, false)
	panel.gui_input.connect(_on_card_input.bind(selection_id))
	_attach_item_inspect(panel, item)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side_key in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side_key, ROW_PADDING)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", ROW_HGAP)
	margin.add_child(hbox)

	# LEFT: item art at integer scale (the icon is the identity carrier).
	var icon_holder: Control = PixelUI.make_integer_icon(item.icon, ROW_ICON_BOX, accent)
	icon_holder.name = "RewardArtwork"
	icon_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if item.icon == null:
		var glyph := _make_label(_get_item_icon_char(item.icon_key), 64, accent, 2)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_holder.add_child(glyph)
	hbox.add_child(icon_holder)

	# RIGHT: name / metadata / effect line, left-aligned with reading room.
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 6)
	hbox.add_child(info)

	var name_label := _make_fixed_slot_label(item.display_name, ROW_NAME_FONT, accent, ROW_NAME_SLOT_HEIGHT, 2)
	name_label.name = "RewardNameSlot"
	info.add_child(name_label)

	var meta_text: String = _format_item_type_label(item)
	if item.item_type != "relic":
		meta_text = "%s %s" % [_rarity_name(item).to_upper(), meta_text]
	if owner_id != "":
		meta_text += "  |  EQUIPPED: %s" % _run_unit_label(owner_id)
	var meta_label := _make_fixed_slot_label(meta_text, ROW_META_FONT, PixelUI.TEXT_MUTED, ROW_META_SLOT_HEIGHT, 1)
	meta_label.name = "RewardMetaSlot"
	info.add_child(meta_label)

	var effect_row := HBoxContainer.new()
	effect_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effect_row.custom_minimum_size = Vector2(0, ROW_EFFECT_SLOT_HEIGHT)
	effect_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	effect_row.add_theme_constant_override("separation", 18)
	var pip_col: Control = _make_pip_col(item)
	if pip_col != null:
		effect_row.add_child(pip_col)
	var description := _create_description_label(item.description, ROW_EFFECT_SLOT_HEIGHT, 2)
	description.name = "RewardDescriptionSlot"
	effect_row.add_child(description)
	info.add_child(effect_row)

	_add_selection_brackets(panel, selection_id, accent, "row")
	return panel


# Relic ceremonial card (Build B): Major-event tier — gold chrome, large art,
# deliberately a rank above ordinary rows. Same select-then-CONFIRM model.
func _create_relic_card(item: ItemData, selection_id: String = "") -> PanelContainer:
	if selection_id == "":
		selection_id = item.id
	var accent: Color = _get_item_accent(item)

	var panel := PanelContainer.new()
	panel.name = "RelicCard"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.set_meta("item_id", selection_id)
	panel.set_meta("reward_kind", "relic")
	_style_relic_panel(panel, false)
	panel.gui_input.connect(_on_card_input.bind(selection_id))
	_attach_item_inspect(panel, item)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side_key in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side_key, CARD_PADDING)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", CARD_SEP)
	margin.add_child(vbox)

	# Name in a filled header strip; gold is the ceremonial voice here.
	var name_strip := PanelContainer.new()
	name_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var strip_style: StyleBoxFlat = PixelUI.component_header_style(PixelUI.COMPONENT_MAJOR)
	strip_style.set_content_margin(SIDE_TOP, 8.0)
	strip_style.set_content_margin(SIDE_BOTTOM, 8.0)
	name_strip.add_theme_stylebox_override("panel", strip_style)
	name_strip.add_child(_make_centered_label(item.display_name, NAME_FONT_SIZE, PixelUI.GOLD_ACCENT, 3))
	vbox.add_child(name_strip)

	# Large relic art at integer scale (128 native -> 2x; the low-res
	# gravityWell sits at exactly 4x on its Reward-chrome emblem plate).
	var icon_holder: Control = PixelUI.make_integer_icon(item.icon, RELIC_ICON_BOX, accent)
	icon_holder.name = "RelicArtwork"
	icon_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(icon_holder)

	vbox.add_child(_make_centered_label("RELIC", TYPE_HEADER_FONT, PixelUI.GOLD_ACCENT, 2))

	var pip_row := HBoxContainer.new()
	pip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pip_row.add_theme_constant_override("separation", 12)
	var parts: Array = EffectPip.effects_from_passive(item.effect, item.target_kind)
	for part_variant in parts:
		pip_row.add_child(EffectPip.build_group(part_variant, PIP_PROFILE))
	if not parts.is_empty():
		vbox.add_child(pip_row)

	var description := _create_description_label(item.description, RELIC_DESC_MIN_HEIGHT)
	description.name = "RelicDescription"
	vbox.add_child(description)

	_add_selection_brackets(panel, selection_id, accent, "relic")
	return panel


# Effect-pip column for a row; null when the item has no pip-visible effects.
func _make_pip_col(item: ItemData) -> Control:
	var parts: Array = EffectPip.effects_from_passive(item.effect, item.target_kind)
	if parts.is_empty():
		return null
	var pip_col := VBoxContainer.new()
	pip_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip_col.alignment = BoxContainer.ALIGNMENT_CENTER
	pip_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pip_col.add_theme_constant_override("separation", 8)
	for part_variant in parts:
		var group: Control = EffectPip.build_group(part_variant, PIP_PROFILE)
		group.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		pip_col.add_child(group)
	return pip_col


func _attach_item_inspect(panel: PanelContainer, item: ItemData) -> void:
	var long_press := LongPressInput.new()
	panel.add_child(long_press)
	long_press.long_pressed.connect(func(_global_position: Vector2) -> void:
		AudioManager.play_select()
		InspectPopup.open(self, InspectResolver.resolve_item(item), panel.get_global_rect(), panel.get_instance_id())
	)


# Corner-bracket selection indicator + _cards registration, shared by both tiers.
# Hosted on a non-container overlay so the brackets honor their corner anchors.
func _add_selection_brackets(panel: PanelContainer, selection_id: String, accent: Color, kind: String) -> void:
	var overlay := Control.new()
	overlay.name = "BracketOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(overlay)
	# Selection brackets are cyan — one selection language with the border.
	var brackets: Array = _make_corner_brackets(overlay, PixelUI.DT_CYAN)
	_cards[selection_id] = {"panel": panel, "brackets": brackets, "accent": accent, "kind": kind}


func _style_card_panel(panel: PanelContainer, accent: Color, selected: bool) -> void:
	# Components: Reward (rarity accent) at rest, Selected (strong cyan) on pick —
	# selection is the ONE cyan-border state, same read as squad tiles and battle
	# cards. The rarity identity stays on the name/type text and icon.
	var style: StyleBoxFlat
	if selected:
		style = PixelUI.component_style(PixelUI.COMPONENT_SELECTED)
		style.bg_color = PixelUI.DT_PANEL_BG.lightened(0.05)
	else:
		style = PixelUI.component_style(PixelUI.COMPONENT_REWARD, accent)
	panel.add_theme_stylebox_override("panel", style)


func _style_relic_panel(panel: PanelContainer, selected: bool) -> void:
	# Components: Major-event (ceremonial gold) at rest, Selected on pick —
	# the selection language stays cyan even on the ceremonial tier.
	var style: StyleBoxFlat
	if selected:
		style = PixelUI.component_style(PixelUI.COMPONENT_SELECTED)
		style.bg_color = PixelUI.DT_PANEL_BG.lightened(0.05)
	else:
		style = PixelUI.component_style(PixelUI.COMPONENT_MAJOR)
	panel.add_theme_stylebox_override("panel", style)


func _create_description_label(text: String, min_height: float = 0.0, max_lines: int = 0) -> Label:
	# Full sentence, left-aligned, wraps freely — the wide row gives it reading
	# room (fewer forced line breaks is an explicit Build B goal). Body tier.
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.custom_minimum_size = Vector2(0, min_height)
	if max_lines > 0:
		label.max_lines_visible = max_lines
		label.clip_text = true
	PixelUI.style_body_label(label, PixelUI.FONT_BODY_MIN, PixelUI.TEXT_MUTED)
	return label


# Fixed single-line slots keep the row anatomy stable. Content remains centered
# vertically so short metadata does not cling to the top of its reserved band.
func _make_fixed_slot_label(text: String, font_size: int, color: Color, slot_height: float, outline: int) -> Label:
	var label := _make_label(text, font_size, color, outline)
	label.custom_minimum_size = Vector2(0, slot_height)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	return label


func _make_centered_label(text: String, font_size: int, color: Color, outline: int = 1) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelUI.style_label(label, font_size, color, outline)
	return label


# ─── Corner-bracket selection indicator ─────────────────────────────────────────
func _make_corner_brackets(host: Control, color: Color) -> Array:
	var rects: Array = []
	for corner in [
		Control.PRESET_TOP_LEFT, Control.PRESET_TOP_RIGHT,
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT,
	]:
		for arm in ["h", "v"]:
			var rect := ColorRect.new()
			rect.color = color
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rect.visible = false
			host.add_child(rect)
			_place_bracket_arm(rect, corner, arm)
			rects.append(rect)
	return rects


func _place_bracket_arm(rect: ColorRect, corner: int, arm: String) -> void:
	var horizontal := arm == "h"
	var w: float = BRACKET_LEN if horizontal else BRACKET_THICK
	var h: float = BRACKET_THICK if horizontal else BRACKET_LEN
	match corner:
		Control.PRESET_TOP_LEFT:
			rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
			rect.offset_left = BRACKET_INSET
			rect.offset_top = BRACKET_INSET
			rect.offset_right = BRACKET_INSET + w
			rect.offset_bottom = BRACKET_INSET + h
		Control.PRESET_TOP_RIGHT:
			rect.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			rect.offset_right = -BRACKET_INSET
			rect.offset_left = -BRACKET_INSET - w
			rect.offset_top = BRACKET_INSET
			rect.offset_bottom = BRACKET_INSET + h
		Control.PRESET_BOTTOM_LEFT:
			rect.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
			rect.offset_left = BRACKET_INSET
			rect.offset_right = BRACKET_INSET + w
			rect.offset_bottom = -BRACKET_INSET
			rect.offset_top = -BRACKET_INSET - h
		Control.PRESET_BOTTOM_RIGHT:
			rect.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			rect.offset_right = -BRACKET_INSET
			rect.offset_left = -BRACKET_INSET - w
			rect.offset_bottom = -BRACKET_INSET
			rect.offset_top = -BRACKET_INSET - h


# ─── Selection ──────────────────────────────────────────────────────────────────
func _on_card_input(event: InputEvent, item_id: String) -> void:
	var clicked := false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		clicked = mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	elif event is InputEventScreenTouch:
		clicked = (event as InputEventScreenTouch).pressed
	if not clicked:
		return
	accept_event()
	if _selected_item_id == item_id:
		return
	AudioManager.play_select()
	_select_item(item_id)


func _select_item(item_id: String) -> void:
	_selected_item_id = item_id
	_selected_gear_unit_id = ""
	_selected_swap_consumable_id = ""
	footer_label.text = ""
	_refresh_selection()
	# Gear is assigned to a unit at selection time: pop the chooser now, then the player
	# confirms with the bottom button (which finalizes the equip).
	var item: ItemData = _item_for_selection(item_id)
	if item == null:
		return
	if item.item_type == "gear" and str(_choice_request.get("kind", "")) != "owned_gear":
		_show_gear_target_overlay(item)
	# Consumables are capped: if the bag is already full, choose which one to discard now,
	# mirroring the gear chooser. Under the cap, no prompt — it just gets picked up.
	elif item.item_type == "consumable" and GameState.is_consumables_full():
		_show_consumable_swap_overlay(item)


func _refresh_selection() -> void:
	for item_id_variant in _cards.keys():
		var item_id := str(item_id_variant)
		var entry: Dictionary = _cards[item_id]
		var is_selected: bool = item_id == _selected_item_id
		if str(entry.get("kind", "row")) == "relic":
			_style_relic_panel(entry["panel"], is_selected)
		else:
			_style_card_panel(entry["panel"], entry["accent"], is_selected)
		for rect_variant in entry["brackets"]:
			(rect_variant as ColorRect).visible = is_selected
	_refresh_confirm()


# ─── View Battlescreen (Batch 5): read-only peek at the finished battle ─────────
# A secondary button pinned above CONFIRM. Only shown when battle_scene captured a
# snapshot (skipped headless / auto-battle / no-battle paths). Picker state is retained
# before the real BattleScene opens read-only, then restored when it returns here.
func _build_view_battle_button() -> void:
	if GameState.battle_review_state.is_empty():
		return
	var button := Button.new()
	button.name = "ViewBattleButton"
	button.text = "VIEW BATTLEFIELD"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, VIEW_BATTLE_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelUI.style_button(button, Color(0.04, 0.09, 0.12, 0.96), PixelUI.DT_HERO_BORDER, VIEW_BATTLE_FONT)
	button.add_theme_color_override("font_color", PixelUI.DT_HERO_NAME)
	button.pressed.connect(_on_view_battle_pressed)
	content_vbox.add_child(button)


# "View Battlescreen" re-enters the real BattleScene read-only: the review board
# is live, so long-press inspect works on units, abilities, statuses, and pips.
# The offer and UI state are retained; BattleScene consumes the one-shot flag then
# routes its only control back to this picker.
func _on_view_battle_pressed() -> void:
	if GameState.battle_review_state.is_empty():
		return
	AudioManager.play_select()
	GameState.reward_picker_ui_state = {
		"selected_item_id": _selected_item_id,
		"selected_gear_unit_id": _selected_gear_unit_id,
		"selected_swap_consumable_id": _selected_swap_consumable_id,
		"scroll_vertical": reward_scroll.scroll_vertical,
	}
	GameState.battle_review_return_target = "reward"
	GameState.entering_battle_review = true
	SceneManager.go_to_battle()


# ─── Confirm button (cloned from squad-screen DEPLOY) ───────────────────────────
func _build_confirm_button() -> void:
	_confirm_button = Button.new()
	_confirm_button.focus_mode = Control.FOCUS_NONE
	_confirm_button.custom_minimum_size = Vector2(0, CONFIRM_HEIGHT)
	_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_button.pressed.connect(_on_confirm_pressed)
	content_vbox.add_child(_confirm_button)
	_refresh_confirm()


func _refresh_confirm() -> void:
	if _confirm_button == null:
		return
	var armed := _selected_item_id != ""
	if armed:
		# Requirement met → actionable teal primary button.
		_confirm_button.text = "CONFIRM"
		PixelUI.style_primary_button(_confirm_button, CONFIRM_FONT)
		_confirm_button.disabled = false
		_confirm_button.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		# Requirement unmet → explicit progress-locked button (no border, dim text).
		_confirm_button.text = "SELECT AN ITEM"
		PixelUI.style_locked_button(_confirm_button, CONFIRM_FONT)
		_confirm_button.disabled = true
		_confirm_button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_confirm_pressed() -> void:
	if _selected_item_id == "":
		return
	var item: ItemData = _item_for_selection(_selected_item_id)
	if item == null:
		return
	AudioManager.play_select()
	if not _choice_request.is_empty():
		var event_kind: String = str(_choice_request.get("kind", ""))
		if event_kind != "owned_gear" and item.item_type == "gear" and _selected_gear_unit_id == "":
			_show_gear_target_overlay(item)
			return
		if event_kind != "owned_gear" and item.item_type == "consumable" and GameState.is_consumables_full() and _selected_swap_consumable_id == "":
			_show_consumable_swap_overlay(item)
			return
		_commit_intercept_choice(item, _selected_gear_unit_id, _selected_swap_consumable_id)
		return
	# Gear is equipped to the unit chosen in the chooser. If none was picked (the player
	# dismissed it), re-open the chooser instead of claiming.
	if item.item_type == "gear":
		if _selected_gear_unit_id == "":
			_show_gear_target_overlay(item)
			return
		_claim_reward(item, _selected_gear_unit_id)
		return
	# A full consumable bag needs a discard target chosen. If none was picked (the player
	# dismissed the chooser), re-open it instead of claiming.
	if item.item_type == "consumable" and GameState.is_consumables_full():
		if _selected_swap_consumable_id == "":
			_show_consumable_swap_overlay(item)
			return
		_claim_reward(item, "", _selected_swap_consumable_id)
		return
	_claim_reward(item, "")


func _set_button_text_color(button: Button, color: Color) -> void:
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_focus_color", color)
	button.add_theme_color_override("font_disabled_color", color)


# ─── Gear equip-target overlay ──────────────────────────────────────────────────
func _show_gear_target_overlay(item: ItemData) -> void:
	if _gear_target_overlay != null and is_instance_valid(_gear_target_overlay):
		_gear_target_overlay.queue_free()

	_gear_target_overlay = Control.new()
	_gear_target_overlay.name = "GearTargetOverlay"
	_gear_target_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_gear_target_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gear_target_overlay.z_as_relative = false
	_gear_target_overlay.z_index = 220
	add_child(_gear_target_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.005, 0.007, 0.012, 0.76)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_hide_gear_target_overlay()
		elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
			_hide_gear_target_overlay()
	)
	_gear_target_overlay.add_child(dim)

	var outer := CenterContainer.new()
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_gear_target_overlay.add_child(outer)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_width: float = clampf(
		get_viewport().get_visible_rect().size.x * GEAR_TARGET_WIDTH_FRACTION,
		GEAR_TARGET_MIN_WIDTH,
		GEAR_TARGET_MAX_WIDTH,
	)
	panel.custom_minimum_size = Vector2(panel_width, 0)
	_style_card_panel(panel, _get_item_accent(item), false)
	outer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	margin.add_child(vbox)

	var title := _make_label("EQUIP %s TO" % item.display_name.to_upper(), GEAR_TARGET_TITLE_FONT, _get_item_accent(item), 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)

	for unit_id_variant in GameState.selected_units:
		var unit_id: String = str(unit_id_variant)
		if GameState.get_run_unit_data(unit_id) == null:
			continue
		var target_button := Button.new()
		target_button.text = _run_unit_label(unit_id)
		target_button.focus_mode = Control.FOCUS_NONE
		target_button.custom_minimum_size = Vector2(0, GEAR_TARGET_BUTTON_HEIGHT)
		target_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PixelUI.style_button(target_button, Color(0.022, 0.034, 0.050, 0.95), _get_item_accent(item), GEAR_TARGET_BUTTON_FONT_SIZE)
		var captured_unit_id := unit_id
		target_button.pressed.connect(func() -> void:
			AudioManager.play_select()
			_selected_gear_unit_id = captured_unit_id
			_hide_gear_target_overlay()
			footer_label.text = "EQUIP TO: %s" % _run_unit_label(captured_unit_id)
			footer_label.visible = true
			_refresh_confirm()
		)
		vbox.add_child(target_button)


func _hide_gear_target_overlay() -> void:
	if _gear_target_overlay != null and is_instance_valid(_gear_target_overlay):
		_gear_target_overlay.queue_free()
	_gear_target_overlay = null


# ─── Consumable swap chooser (shown when the bag is full) ───────────────────────
func _show_consumable_swap_overlay(item: ItemData) -> void:
	if _consumable_swap_overlay != null and is_instance_valid(_consumable_swap_overlay):
		_consumable_swap_overlay.queue_free()

	_consumable_swap_overlay = Control.new()
	_consumable_swap_overlay.name = "ConsumableSwapOverlay"
	_consumable_swap_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_consumable_swap_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_consumable_swap_overlay.z_as_relative = false
	_consumable_swap_overlay.z_index = 220
	add_child(_consumable_swap_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.005, 0.007, 0.012, 0.76)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			_hide_consumable_swap_overlay()
		elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
			_hide_consumable_swap_overlay()
	)
	_consumable_swap_overlay.add_child(dim)

	var outer := CenterContainer.new()
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_consumable_swap_overlay.add_child(outer)

	var accent: Color = _get_item_accent(item)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_width: float = clampf(
		get_viewport().get_visible_rect().size.x * GEAR_TARGET_WIDTH_FRACTION,
		GEAR_TARGET_MIN_WIDTH,
		GEAR_TARGET_MAX_WIDTH,
	)
	panel.custom_minimum_size = Vector2(panel_width, 0)
	_style_card_panel(panel, accent, false)
	outer.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	margin.add_child(vbox)

	var title := _make_label("BAG FULL - DISCARD ONE FOR %s" % item.display_name.to_upper(), GEAR_TARGET_TITLE_FONT, accent, 2)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)

	for held_id_variant in GameState.consumables:
		var held_id: String = str(held_id_variant)
		var held: ItemData = DataManager.get_item(held_id) as ItemData
		if held == null:
			continue
		var swap_button := Button.new()
		swap_button.text = held.display_name
		swap_button.focus_mode = Control.FOCUS_NONE
		swap_button.custom_minimum_size = Vector2(0, GEAR_TARGET_BUTTON_HEIGHT)
		swap_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PixelUI.style_button(swap_button, Color(0.022, 0.034, 0.050, 0.95), accent, GEAR_TARGET_BUTTON_FONT_SIZE)
		var captured_id := held_id
		var captured_name := held.display_name
		swap_button.pressed.connect(func() -> void:
			AudioManager.play_select()
			_selected_swap_consumable_id = captured_id
			_hide_consumable_swap_overlay()
			footer_label.text = "DISCARD: %s" % captured_name
			footer_label.visible = true
			_refresh_confirm()
		)
		vbox.add_child(swap_button)


func _hide_consumable_swap_overlay() -> void:
	if _consumable_swap_overlay != null and is_instance_valid(_consumable_swap_overlay):
		_consumable_swap_overlay.queue_free()
	_consumable_swap_overlay = null


# ─── Claim / advance ────────────────────────────────────────────────────────────
func _item_for_selection(selection_id: String) -> ItemData:
	if not _choice_request.is_empty():
		return GameState.get_choice_item(selection_id)
	return DataManager.get_item(selection_id) as ItemData


func _restore_picker_ui_state() -> void:
	var state: Dictionary = GameState.reward_picker_ui_state
	if state.is_empty():
		return
	var restored_id: String = str(state.get("selected_item_id", ""))
	if _cards.has(restored_id):
		_selected_item_id = restored_id
		_selected_gear_unit_id = str(state.get("selected_gear_unit_id", ""))
		_selected_swap_consumable_id = str(state.get("selected_swap_consumable_id", ""))
		if _selected_gear_unit_id != "":
			footer_label.text = "EQUIP TO: %s" % _run_unit_label(_selected_gear_unit_id)
			footer_label.visible = true
		elif _selected_swap_consumable_id != "":
			var swapped: ItemData = DataManager.get_item(_selected_swap_consumable_id) as ItemData
			footer_label.text = "DISCARD: %s" % (swapped.display_name if swapped != null else _selected_swap_consumable_id)
			footer_label.visible = true
		_refresh_selection()
	reward_scroll.scroll_vertical = int(state.get("scroll_vertical", 0))
	GameState.reward_picker_ui_state.clear()


func _commit_intercept_choice(item: ItemData, target_unit_id: String, swap_consumable_id: String = "") -> void:
	if not GameState.complete_intercept_item_choice(_selected_item_id, target_unit_id, swap_consumable_id):
		footer_label.text = "That choice could not be applied. Try again."
		footer_label.visible = true
		return
	_choice_request.clear()
	SceneManager.go_to_intercept()


func _claim_reward(item: ItemData, target_unit_id: String, swap_consumable_id: String = "") -> void:
	# Resolve the discarded item's name before the claim erases it (for the result text).
	var swapped_out_name: String = ""
	if swap_consumable_id != "":
		var swapped_out: ItemData = DataManager.get_item(swap_consumable_id) as ItemData
		if swapped_out != null:
			swapped_out_name = swapped_out.display_name

	var claimed: bool = GameState.claim_reward(item.id, target_unit_id, swap_consumable_id)
	if not claimed:
		footer_label.text = "That reward could not be claimed. Try again."
		footer_label.visible = true
		return

	_refresh_inventory_summary()
	footer_label.text = _build_reward_result_text(item, target_unit_id)
	if swapped_out_name != "":
		footer_label.text = "%s replaced %s." % [item.display_name, swapped_out_name]
	GameState.award_battle_xp()
	if GameState.has_pending_evolution():
		SceneManager.go_to_evolution()
		return
	SceneManager.go_to_next_battle_or_beat()


func _update_battle_header() -> void:
	var operation: OperationData = DataManager.get_operation(GameState.selected_operation_id) as OperationData
	var op_name: String = operation.battle_name() if operation != null else "OP"
	PersistentHeader.set_run_active(true)
	PersistentHeader.update_progress(GameState.current_battle, GameState.total_battles, op_name)


func _refresh_inventory_summary() -> void:
	inventory_label.text = GameState.get_inventory_summary()


func _build_reward_result_text(item: ItemData, target_unit_id: String) -> String:
	if item.item_type != "gear":
		return "%s added to the run." % item.display_name

	var label: String = _run_unit_label(target_unit_id)
	if label == target_unit_id:
		return "%s equipped." % item.display_name
	return "%s equipped to %s." % [item.display_name, label]


func _run_unit_label(unit_id: String) -> String:
	var unit: UnitData = GameState.get_run_unit_data(unit_id) as UnitData
	if unit == null:
		return unit_id
	return unit.battle_name()


# ─── Theme / tokens ─────────────────────────────────────────────────────────────
func _apply_visual_theme() -> void:
	# Direction-05: flat dark DT field (matches the battle screen), no bright grid.
	background.color = Color(0.055, 0.070, 0.095, 1.0)
	var pattern: Control = get_node_or_null("BackgroundPattern")
	if pattern != null:
		pattern.visible = false
	content_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	content_vbox.add_theme_constant_override("separation", 8)
	reward_list_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	reward_content.alignment = BoxContainer.ALIGNMENT_BEGIN
	reward_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_cards.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if reward_top_spacer != null:
		reward_top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reward_top_spacer.custom_minimum_size = Vector2(0, CARD_TOP_SPACER_HEIGHT)
	for spacer in [reward_group_top_spacer, reward_group_bottom_spacer]:
		if spacer != null:
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Header bar (label + buttons) is owned + styled by the PersistentHeader autoload.
	title_label.text = "Choose Reward"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.visible = false
	reward_title_label.text = "CHOOSE REWARD"
	if not _choice_request.is_empty():
		reward_title_label.text = str(_choice_request.get("title", "CHOOSE REWARD"))
	# Fixed beat (pkg7.2): the battle-5 relic draft renders in event chrome.
	# Same drafted-relic accounting as the roll + claim paths (a Starting
	# Directive relic never counts against the draft slot).
	if GameState.current_battle == GameState.RELIC_ONLY_ROUND and GameState.drafted_relic_count() == 0:
		reward_title_label.text = "INTERCEPT: RELIC CACHE"
	reward_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_title_label.custom_minimum_size = Vector2(0, 82)
	summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary_label.visible = false
	inventory_label.visible = false
	# Reserve the status line even while it is empty so selecting a gear recipient
	# never changes the RewardScroll height or shifts the choice rows.
	footer_label.visible = true
	footer_label.text = ""
	footer_label.custom_minimum_size = Vector2(0, FOOTER_RESERVED_HEIGHT)
	PixelUI.style_label(title_label, 44, PixelUI.GOLD_ACCENT, 2)
	PixelUI.style_label(reward_title_label, 62, PixelUI.GOLD_ACCENT, 3)
	PixelUI.style_label(summary_label, 32, PixelUI.TEXT_PRIMARY, 2)
	PixelUI.style_label(inventory_label, 28, PixelUI.TEXT_MUTED, 1)
	PixelUI.style_label(footer_label, FOOTER_FONT, PixelUI.TEXT_PRIMARY, 2)
	reward_content.add_theme_constant_override("separation", 18)
	reward_cards.add_theme_constant_override("separation", 18)
	reward_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())


# Relics carry no rarity — they use the legendary token. Everything else uses its own
# rarity (falling back to common if unset).
func _rarity_name(item: ItemData) -> String:
	if item.item_type == "relic":
		return "legendary"
	return item.rarity if item.rarity != "" else "common"


func _get_item_accent(item: ItemData) -> Color:
	return PixelUI.rarity_color(_rarity_name(item))


func _format_item_type_label(item: ItemData) -> String:
	match item.item_type:
		"gear":
			return "GEAR"
		"consumable":
			return "CONSUMABLE"
		"relic":
			return "RELIC"
	return item.item_type.to_upper()


# ASCII-only fallback glyphs (Build #3): shown only when an item has no icon
# texture. m5x7 has no coverage for the old symbol set (♥⚡☠…) and
# allow_system_fallback=false means uncovered chars are tofu — the glyph sweep
# gate enforces coverage now.
func _get_item_icon_char(icon_key: String) -> String:
	match icon_key:
		"heart":
			return "+"
		"shield":
			return "S"
		"die":
			return "D"
		"bolt":
			return "B"
		"skull":
			return "X"
		"cloak":
			return "C"
		"star":
			return "*"
	return "?"


func _make_label(text: String, font_size: int, color: Color, outline: int = 1) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUI.style_label(label, font_size, color, outline)
	return label


# ChoiceScreenGuard fallback: no options were built — award the battle XP the
# claim path would have awarded and route on (evolution stop still honored).
func _auto_resolve_empty_offer() -> void:
	if not _choice_request.is_empty():
		GameState.pending_choice_request.clear()
		GameState.pending_intercept_state["stage"] = "result_pending"
		SceneManager.go_to_intercept()
		return
	GameState.award_battle_xp()
	if GameState.has_pending_evolution():
		SceneManager.go_to_evolution()
		return
	SceneManager.go_to_next_battle_or_beat()
