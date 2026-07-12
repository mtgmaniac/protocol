# Phase 6 reward / item picker. Rolls three reward choices and lets the player SINGLE-
# select one, then commit with a single confirm button at the bottom of the screen.
#
# Direction-05 "Dithered Terminal" card (matches the battle screen, the locked source of
# truth): perfect-square plate, hard blocky corners, flat 1-tone border whose color = the
# item's RARITY (PixelUI.rarity_color). Anatomy top→bottom: type-silhouette icon frame
# (triangle/circle/hexagon = consumable/gear/relic), item name, "RARITY TYPE" label line
# (plain text, rarity-colored), centered effect pips (reused battle-screen EffectPip
# assets), then the full description. Selection lights up corner brackets on the chosen
# card only; the confirm button clones the squad screen's DEPLOY button (green ROLL-commit
# style when armed, idle-gray + disabled until a card is picked).
#
# All colors/borders come from PixelUI tokens; layout sizes are named consts (this
# codebase's centralization convention — see home_screen.gd). No hardcoded scene values.
extends Control

const ChoiceScreenGuardScript := preload("res://scripts/ui/choice_screen_guard.gd")


# Card geometry (logical px). The card is a PERFECT SQUARE (width == height) with content
# vertically centered inside it.
const CARD_WIDTH_FRACTION := 0.86
const CARD_MIN_WIDTH := 360.0
const CARD_MAX_WIDTH := 460.0
const CARD_TOP_SPACER_HEIGHT := 24.0
const CARD_PADDING := 18
const CARD_SEP := 9
const CARD_BORDER := 5   # hard border, thick enough to survive the canvas_items downscale

# Bare large icon (Kev 2026-07-10: silhouette frames cut, icon is the star).
const ICON_AREA_SIZE := 200.0
const ICON_TEXTURE_SIZE := 180.0

# Corner-bracket selection indicator (L per corner = horizontal arm + vertical arm).
const BRACKET_LEN := 46.0
const BRACKET_THICK := 8.0
const BRACKET_INSET := 8.0

# Fonts.
const NAME_FONT_SIZE := 46
const LABEL_FONT_SIZE := PixelUI.FONT_INFO_MIN  # rarity+type line — a pick signal (UI review S-1)
const BODY_FONT_SIZE := 36

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
@onready var reward_cards: VBoxContainer = %RewardCards
@onready var footer_label: Label = %FooterLabel

var _help_overlay: Control = null
var _gear_target_overlay: Control = null
var _consumable_swap_overlay: Control = null
var _battle_review_overlay: Control = null   # read-only "View Battlescreen" viewer (Batch 5)

# View-Battlescreen button (Batch 5): a secondary peek back at the finished battle.
const VIEW_BATTLE_FONT := 34
const VIEW_BATTLE_HEIGHT := 96

var _selected_item_id: String = ""
var _selected_gear_unit_id: String = ""   # unit chosen in the equip chooser (gear only)
var _selected_swap_consumable_id: String = ""  # held consumable to discard when full (consumable only)
var _cards: Dictionary = {}   # item_id -> { panel, brackets: Array[ColorRect], accent: Color }
var _confirm_button: Button = null


func _ready() -> void:
	_apply_visual_theme()
	resized.connect(_update_reward_layout)
	# Header bar lives in the PersistentHeader autoload; bind this screen's handlers.
	PersistentHeader.bind_battle_actions(
		_on_help_button_pressed,
		_on_header_unavailable_pressed.bind("Auto turn is unavailable while choosing a reward."),
		_on_header_unavailable_pressed.bind("Auto battle is unavailable while choosing a reward."),
		_on_return_to_menu_button_pressed,
	)
	if GameState.pending_reward_item_ids.is_empty():
		GameState.prepare_battle_rewards()
	_update_battle_header()
	_refresh_inventory_summary()
	_build_reward_cards()
	_build_view_battle_button()
	_build_confirm_button()


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
	PixelUI.style_ninepatch_panel(panel, PixelUI.FRAME_BOTTOM_BAR_SCIFI)
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
		"Tap a card to select it; tap another to switch.",
		"The chosen card lights up its corner brackets.",
		"Border color = rarity; the icon shape = type.",
		"Triangle = consumable, circle = gear, hexagon = relic.",
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
	var reward_items: Array = GameState.get_pending_reward_items()
	for item_variant in reward_items:
		var item: ItemData = item_variant as ItemData
		if item == null:
			continue
		reward_cards.add_child(_create_reward_card(item))
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
			# Perfect square: width == height.
			panel.custom_minimum_size = Vector2(card_width, card_width)
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
	var accent: Color = _get_item_accent(item)

	var panel := PanelContainer.new()
	panel.name = "RewardCard"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(card_width, card_width)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.clip_contents = true
	panel.set_meta("item_id", item.id)
	_style_card_panel(panel, accent, false)
	panel.gui_input.connect(_on_card_input.bind(item.id))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CARD_PADDING)
	margin.add_theme_constant_override("margin_top", CARD_PADDING)
	margin.add_theme_constant_override("margin_right", CARD_PADDING)
	margin.add_theme_constant_override("margin_bottom", CARD_PADDING)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Center the content block vertically inside the square plate.
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", CARD_SEP)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	vbox.add_child(_create_icon_area(item, accent))
	vbox.add_child(_make_centered_label(item.display_name, NAME_FONT_SIZE, accent, 3))
	# Rarity word + the boxed TYPE chip (shared with ItemCard) — the type cue
	# that replaced the shape silhouettes (Kev 2026-07-10).
	var type_row := HBoxContainer.new()
	type_row.alignment = BoxContainer.ALIGNMENT_CENTER
	type_row.add_theme_constant_override("separation", 12)
	type_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	type_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if item.item_type != "relic":
		var rarity_label := _make_centered_label(_rarity_name(item).to_upper(), LABEL_FONT_SIZE, accent, 1)
		rarity_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		rarity_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		type_row.add_child(rarity_label)
	var chip := ItemCard.type_chip(item, accent)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	type_row.add_child(chip)
	vbox.add_child(type_row)
	vbox.add_child(_create_pip_row(item))
	vbox.add_child(_create_description_label(item.description))

	# Corner-bracket selection indicator. Hosted on a non-container overlay so the
	# brackets honor their corner anchors (a PanelContainer would stretch them to fill).
	var overlay := Control.new()
	overlay.name = "BracketOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(overlay)
	var brackets: Array = _make_corner_brackets(overlay, accent.lightened(0.30))

	_cards[item.id] = {"panel": panel, "brackets": brackets, "accent": accent}
	return panel


func _style_card_panel(panel: PanelContainer, accent: Color, selected: bool) -> void:
	var fill: Color = PixelUI.DT_PANEL_BG.lightened(0.05) if selected else PixelUI.DT_PANEL_BG
	var border: Color = accent.lightened(0.20) if selected else accent
	var style: StyleBoxFlat = PixelUI.make_hard_style(fill, border, CARD_BORDER)
	style.set_content_margin_all(0.0)
	panel.add_theme_stylebox_override("panel", style)


# Bare LARGE icon — no outline, no shape silhouette (Kev 2026-07-10: the icon
# is the star; the boxed type word below carries type).
func _create_icon_area(item: ItemData, accent: Color) -> Control:
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(0, ICON_AREA_SIZE)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item.icon != null:
		var texture_rect := TextureRect.new()
		texture_rect.custom_minimum_size = Vector2(ICON_TEXTURE_SIZE, ICON_TEXTURE_SIZE)
		texture_rect.texture = item.icon
		texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(texture_rect)
	else:
		var icon_label := _make_label(_get_item_icon_char(item.icon_key), 64, accent, 2)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		center.add_child(icon_label)
	return center


func _create_pip_row(item: ItemData) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts: Array = EffectPip.effects_from_passive(item.effect, item.target_kind)
	if parts.is_empty():
		row.add_child(_make_centered_label("—", BODY_FONT_SIZE, PixelUI.TEXT_MUTED, 1))
		return row
	for part_variant in parts:
		var part: Dictionary = part_variant
		row.add_child(EffectPip.build_group(part, PIP_PROFILE))
	return row


func _create_description_label(text: String) -> Label:
	# Full sentence, left-aligned, wraps freely (no max_lines clip). The square is sized
	# to budget a 2-line worst case.
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	PixelUI.style_label(label, BODY_FONT_SIZE, PixelUI.TEXT_MUTED, 1)
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
	footer_label.visible = false
	_refresh_selection()
	# Gear is assigned to a unit at selection time: pop the chooser now, then the player
	# confirms with the bottom button (which finalizes the equip).
	var item: ItemData = DataManager.get_item(item_id) as ItemData
	if item == null:
		return
	if item.item_type == "gear":
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
		_style_card_panel(entry["panel"], entry["accent"], is_selected)
		for rect_variant in entry["brackets"]:
			(rect_variant as ColorRect).visible = is_selected
	_refresh_confirm()


# ─── View Battlescreen (Batch 5): read-only peek at the finished battle ─────────
# A secondary button pinned above CONFIRM. Only shown when battle_scene captured a
# snapshot (skipped headless / auto-battle / no-battle paths). Opening it is a pure
# in-screen overlay — the reward screen instance never leaves the tree, so the offered
# rewards can't re-roll or change. Read-only: the overlay has one control, RETURN.
func _build_view_battle_button() -> void:
	if GameState.last_battle_snapshot == null:
		return
	var button := Button.new()
	button.name = "ViewBattleButton"
	button.text = "VIEW BATTLESCREEN"
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, VIEW_BATTLE_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelUI.style_button(button, Color(0.04, 0.09, 0.12, 0.96), PixelUI.DT_HERO_BORDER, VIEW_BATTLE_FONT)
	button.add_theme_color_override("font_color", PixelUI.DT_HERO_NAME)
	button.pressed.connect(_on_view_battle_pressed)
	content_vbox.add_child(button)


func _on_view_battle_pressed() -> void:
	AudioManager.play_select()
	_show_battle_review_overlay()


func _show_battle_review_overlay() -> void:
	if GameState.last_battle_snapshot == null:
		return
	if _battle_review_overlay != null and is_instance_valid(_battle_review_overlay):
		_battle_review_overlay.queue_free()

	_battle_review_overlay = Control.new()
	_battle_review_overlay.name = "BattleReviewOverlay"
	_battle_review_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_battle_review_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle_review_overlay.z_as_relative = false
	_battle_review_overlay.z_index = 240
	add_child(_battle_review_overlay)

	# Opaque backdrop so nothing of the reward screen bleeds through the letterbox bars.
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.05, 1.0)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP  # swallow taps: read-only, no pass-through
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle_review_overlay.add_child(backdrop)

	# The captured battle frame, letterboxed to its own aspect (never stretched). It fills
	# the screen since it was captured at the same resolution.
	var snapshot := TextureRect.new()
	snapshot.texture = GameState.last_battle_snapshot
	snapshot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	snapshot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	snapshot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	snapshot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	snapshot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_battle_review_overlay.add_child(snapshot)

	# "REVIEW — READ ONLY" eyebrow so it's unmistakably a look-back, not a live board.
	var eyebrow := _make_label("BATTLE REVIEW — READ ONLY", LABEL_FONT_SIZE, PixelUI.DT_AMBER, 2)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	eyebrow.offset_top = int(PersistentHeader.HEADER_HEIGHT) + 12
	eyebrow.offset_left = 20
	eyebrow.offset_right = -20
	_battle_review_overlay.add_child(eyebrow)

	# The only interactive control — RETURN closes the overlay; the reward screen and its
	# offered rewards are exactly as they were.
	var return_button := Button.new()
	return_button.text = "RETURN TO REWARDS"
	return_button.focus_mode = Control.FOCUS_NONE
	return_button.custom_minimum_size = Vector2(0, CONFIRM_HEIGHT)
	return_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	return_button.offset_top = -CONFIRM_HEIGHT - 40
	return_button.offset_bottom = -40
	return_button.offset_left = 40
	return_button.offset_right = -40
	PixelUI.style_primary_button(return_button, CONFIRM_FONT)
	return_button.pressed.connect(_hide_battle_review_overlay)
	_battle_review_overlay.add_child(return_button)


func _hide_battle_review_overlay() -> void:
	AudioManager.play_select()
	if _battle_review_overlay != null and is_instance_valid(_battle_review_overlay):
		_battle_review_overlay.queue_free()
	_battle_review_overlay = null


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
	var item: ItemData = DataManager.get_item(_selected_item_id) as ItemData
	if item == null:
		return
	AudioManager.play_select()
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
			footer_label.text = "Equip to: %s  —  press CONFIRM" % _run_unit_label(captured_unit_id)
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

	var title := _make_label("BAG FULL — DISCARD ONE FOR %s" % item.display_name.to_upper(), GEAR_TARGET_TITLE_FONT, accent, 2)
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
			footer_label.text = "Discard %s  —  press CONFIRM" % captured_name
			footer_label.visible = true
			_refresh_confirm()
		)
		vbox.add_child(swap_button)


func _hide_consumable_swap_overlay() -> void:
	if _consumable_swap_overlay != null and is_instance_valid(_consumable_swap_overlay):
		_consumable_swap_overlay.queue_free()
	_consumable_swap_overlay = null


# ─── Claim / advance ────────────────────────────────────────────────────────────
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
	reward_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	reward_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_cards.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if reward_top_spacer != null:
		reward_top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reward_top_spacer.custom_minimum_size = Vector2(0, CARD_TOP_SPACER_HEIGHT)
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Header bar (label + buttons) is owned + styled by the PersistentHeader autoload.
	title_label.text = "Choose Reward"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.visible = false
	reward_title_label.text = "CHOOSE REWARD"
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
	footer_label.visible = false
	PixelUI.style_label(title_label, 44, PixelUI.GOLD_ACCENT, 2)
	PixelUI.style_label(reward_title_label, 62, PixelUI.GOLD_ACCENT, 3)
	PixelUI.style_label(summary_label, 32, PixelUI.TEXT_PRIMARY, 2)
	PixelUI.style_label(inventory_label, 28, PixelUI.TEXT_MUTED, 1)
	PixelUI.style_label(footer_label, 28, PixelUI.TEXT_MUTED, 1)
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


func _make_label(text: String, font_size: int, color: Color, outline: int = 1) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUI.style_label(label, font_size, color, outline)
	return label


# ChoiceScreenGuard fallback: no options were built — award the battle XP the
# claim path would have awarded and route on (evolution stop still honored).
func _auto_resolve_empty_offer() -> void:
	GameState.award_battle_xp()
	if GameState.has_pending_evolution():
		SceneManager.go_to_evolution()
		return
	SceneManager.go_to_next_battle_or_beat()
