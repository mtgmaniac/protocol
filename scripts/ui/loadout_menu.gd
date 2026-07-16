# The themed LOADOUT menu opened from the battle item button. Shows the player's consumable
# slots (GameState.MAX_CONSUMABLES) and relics (up to 2) in the shared Dithered-Terminal /
# inspect styling. Each row is a
# LARGE bare icon (the shape silhouettes were cut 2026-07-10) beside the name and a pip
# preview of what the item does — long-press for the full description. Tapping a filled
# item invokes the supplied use-callback and closes; tapping outside dismisses.
#
# All colors via PixelUI tokens (INSPECT_* / rarity_color); blocky corners, m5x7 font, no
# gradients/glows/shadows.
class_name LoadoutMenu
extends CanvasLayer

const HEADER_BAND_HEIGHT := 144.0

const MENU_LAYER := 128
const SCREEN_MARGIN := 18.0
# Kev 2026-07-10: drastically bigger menu + icons.
const PANEL_WIDTH := 900.0
const CONTENT_PAD := 26
const SECTION_SEP := 14
const ROW_SEP := 12
# Consumable slot count is NOT a local constant — it derives from the single source
# of truth (GameState.MAX_CONSUMABLES) so the loadout and the cap can never drift.
const ICON_SIZE := 150.0
const ICON_TEXTURE := 136.0
const PANEL_BORDER := 3
const HEADER_DIVIDER := 6
const SECTION_DIVIDER := 2

const HEADER_FONT := 56
const SECTION_FONT := 36
const NAME_FONT := 44
const ROW_PIP_PROFILE := {
	"icon_size": 44,
	"value_font": 52,
	"duration_ratio": 0.6,
	"icon_value_gap": 4,
	"group_min_width": 72,
	"outline": 2,
	"duration_outline": 2,
}

static var _active: LoadoutMenu = null

var _on_use: Callable = Callable()
var _catcher: Control = null
var _panel: PanelContainer = null

# Discard-picker mode (LOADOUT FULL - DISCARD ONE). Same component, second layout:
# the incoming item pinned distinct at top, the held items as select-then-confirm rows.
var _discard_mode: bool = false
var _on_resolve: Callable = Callable()
var _incoming: ItemData = null
var _held_items: Array = []
var _resolved: bool = false
var _selected_discard_id: String = ""
var _discard_rows: Dictionary = {}   # item_id -> PanelContainer
var _confirm_discard_button: Button = null

const DISCARD_HEADER_FONT := 48
const DISCARD_STRIP_FONT := 30
const DISCARD_BUTTON_FONT := 40
const DISCARD_BUTTON_HEIGHT := 104.0


static func dismiss() -> void:
	if _active != null and is_instance_valid(_active):
		_active.queue_free()
	_active = null


static func is_open() -> bool:
	return _active != null and is_instance_valid(_active)


# `items` = Array[ItemData] consumables; `relics` = Array[ItemData] (0-2, "two relics by
# design" — GameState); `on_use` is called with the tapped ItemData. `anchor_rect` = the item
# button's global rect (menu floats above it); empty Rect2 centers.
static func open(host: Node, items: Array, relics: Array, on_use: Callable, anchor_rect: Rect2 = Rect2()) -> void:
	if host == null or not host.is_inside_tree():
		return
	dismiss()
	var menu := LoadoutMenu.new()
	host.get_tree().root.add_child(menu)
	menu._on_use = on_use
	menu._build(items, relics, anchor_rect)
	_active = menu


func _build(items: Array, relics: Array, anchor_rect: Rect2) -> void:
	layer = MENU_LAYER

	_catcher = Control.new()
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.gui_input.connect(_on_catcher_input)
	add_child(_catcher)

	# Shared modal scrim so the header/battle behind the chooser is dimmed, not live.
	_catcher.add_child(PixelUI.make_modal_scrim())

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Component: Modal (scrim added above).
	_panel.add_theme_stylebox_override("panel", PixelUI.component_style(PixelUI.COMPONENT_MODAL))
	# Transparent (not `visible = false`) until _relayout positions it, so it never flashes at
	# the top-left first frame. modulate keeps the subtree laid out while _relayout measures it
	# (a hidden PanelContainer skips child-sorting, which corrupts the height measurement).
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CONTENT_PAD)
	margin.add_theme_constant_override("margin_top", CONTENT_PAD)
	margin.add_theme_constant_override("margin_right", CONTENT_PAD)
	margin.add_theme_constant_override("margin_bottom", CONTENT_PAD)
	_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", SECTION_SEP)
	margin.add_child(content)

	content.add_child(_make_label("LOADOUT", HEADER_FONT, PixelUI.INSPECT_TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	content.add_child(_divider(HEADER_DIVIDER, PixelUI.INSPECT_BORDER))

	content.add_child(_make_label("ITEMS", SECTION_FONT, PixelUI.INSPECT_TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var item_rows := VBoxContainer.new()
	item_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_rows.add_theme_constant_override("separation", ROW_SEP)
	content.add_child(item_rows)
	for i in GameState.MAX_CONSUMABLES:
		var item: ItemData = items[i] as ItemData if i < items.size() else null
		# force_readable_name so colliding slots stay "LoadoutItemRow"/"...2" (Godot's
		# default assigns a fast "@Class@N" name on collision, losing the row tag).
		item_rows.add_child(_make_slot_row(item, true), true)

	# Relics live ONLY here (ruling: never on battle chrome). One row per held
	# relic, up to two; the whole section is hidden at zero — no placeholder slot.
	var relic_items: Array = []
	for relic_variant in relics:
		var relic_item: ItemData = relic_variant as ItemData
		if relic_item != null:
			relic_items.append(relic_item)
	if not relic_items.is_empty():
		content.add_child(_divider(SECTION_DIVIDER, PixelUI.INSPECT_DIVIDER))
		content.add_child(_make_label("RELICS", SECTION_FONT, PixelUI.INSPECT_TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT))
		for relic_item in relic_items:
			content.add_child(_make_slot_row(relic_item, false), true)

	call_deferred("_relayout", anchor_rect)


# ── Discard picker (LOADOUT FULL - DISCARD ONE) ────────────────────────────────
# Opens OVER the reward/intercept screen when a consumable is claimed at cap.
# `on_resolve` is called exactly once: with the HELD item id to discard (CONFIRM
# DISCARD), or "" to ABANDON the incoming pickup. Nothing is destroyed on dismiss.
static func open_discard(host: Node, held_items: Array, incoming: Resource, on_resolve: Callable) -> void:
	if host == null or not host.is_inside_tree():
		return
	dismiss()
	var menu := LoadoutMenu.new()
	host.get_tree().root.add_child(menu)
	menu._discard_mode = true
	menu._on_resolve = on_resolve
	menu._incoming = incoming as ItemData
	menu._held_items = held_items.duplicate()
	menu._build_discard()
	_active = menu


func _build_discard() -> void:
	layer = MENU_LAYER

	_catcher = Control.new()
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.gui_input.connect(_on_catcher_input)
	add_child(_catcher)
	_catcher.add_child(PixelUI.make_modal_scrim())

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", PixelUI.component_style(PixelUI.COMPONENT_MODAL))
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, CONTENT_PAD)
	_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", SECTION_SEP)
	margin.add_child(content)

	# Alert-tier header (caps law).
	content.add_child(_make_label("LOADOUT FULL - DISCARD ONE", DISCARD_HEADER_FONT, PixelUI.DT_AMBER, HORIZONTAL_ALIGNMENT_LEFT))
	content.add_child(_divider(HEADER_DIVIDER, PixelUI.INSPECT_BORDER))

	# INCOMING — pinned, visually distinct (Reward-accent panel + amber strip). It is
	# the item being made room for, never a discard option.
	content.add_child(_make_incoming_block(_incoming))

	content.add_child(_make_label("HELD - TAP TO DISCARD", SECTION_FONT, PixelUI.INSPECT_TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	var held_rows := VBoxContainer.new()
	held_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	held_rows.add_theme_constant_override("separation", ROW_SEP)
	content.add_child(held_rows)
	for held_variant in _held_items:
		var held_item: ItemData = held_variant as ItemData
		if held_item != null:
			held_rows.add_child(_make_discard_held_row(held_item))

	# Buttons: CONFIRM DISCARD (disabled until a held item is selected) + ABANDON.
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 16)
	button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(button_row)

	_confirm_discard_button = Button.new()
	_confirm_discard_button.name = "ConfirmDiscardButton"
	_confirm_discard_button.text = "CONFIRM DISCARD"
	_confirm_discard_button.focus_mode = Control.FOCUS_NONE
	_confirm_discard_button.custom_minimum_size = Vector2(0, DISCARD_BUTTON_HEIGHT)
	_confirm_discard_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_discard_button.disabled = true
	PixelUI.style_button(_confirm_discard_button, PixelUI.DT_HERO_BG, PixelUI.DT_CYAN, DISCARD_BUTTON_FONT)
	_confirm_discard_button.pressed.connect(_resolve_discard)
	button_row.add_child(_confirm_discard_button)

	var abandon_button := Button.new()
	abandon_button.name = "AbandonButton"
	abandon_button.text = "ABANDON"
	abandon_button.focus_mode = Control.FOCUS_NONE
	abandon_button.custom_minimum_size = Vector2(0, DISCARD_BUTTON_HEIGHT)
	abandon_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelUI.style_button(abandon_button, PixelUI.DT_HERO_BG, PixelUI.DT_ENEMY_BORDER, DISCARD_BUTTON_FONT)
	abandon_button.pressed.connect(_resolve_abandon)
	button_row.add_child(abandon_button)

	call_deferred("_relayout", Rect2())


# INCOMING block: reward-accent panel + amber "INCOMING" strip so it reads as the
# thing being made room for, not a discard candidate. Long-press inspects it.
func _make_incoming_block(item: ItemData) -> Control:
	var panel := PanelContainer.new()
	panel.name = "LoadoutIncoming"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", PixelUI.component_style(PixelUI.COMPONENT_REWARD, PixelUI.DT_AMBER))
	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		pad.add_theme_constant_override(side, 12)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pad)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	pad.add_child(col)
	col.add_child(_make_label("INCOMING", DISCARD_STRIP_FONT, PixelUI.DT_AMBER, HORIZONTAL_ALIGNMENT_LEFT))
	col.add_child(_make_item_line(item))
	if item != null:
		var long_press := LongPressInput.new()
		panel.add_child(long_press)
		long_press.long_pressed.connect(_on_row_long_pressed.bind(item, panel))
	return panel


# Icon + name + pip preview line, shared by the incoming block and the held rows.
func _make_item_line(item: ItemData) -> Control:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_make_icon(item))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 6)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(info)
	var accent: Color = _slot_accent(item, true)
	info.add_child(_make_label(item.display_name if item != null else "-", NAME_FONT, accent, HORIZONTAL_ALIGNMENT_LEFT))
	if item != null:
		var pips: Array = EffectPip.effects_from_passive(item.effect, item.target_kind)
		if not pips.is_empty():
			var pip_row := HBoxContainer.new()
			pip_row.add_theme_constant_override("separation", 10)
			pip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for pip_variant in pips:
				pip_row.add_child(EffectPip.build_group(pip_variant, ROW_PIP_PROFILE))
			info.add_child(pip_row)
	return hbox


# A selectable HELD row: tap = select for discard (Selected component), long-press =
# inspect (never commits). The mandatory select-then-confirm protects against mis-taps.
func _make_discard_held_row(item: ItemData) -> Control:
	var panel := PanelContainer.new()
	panel.name = "LoadoutDiscardRow"
	panel.custom_minimum_size = Vector2(0, ICON_SIZE + 8.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_meta("item_id", item.id)
	panel.add_theme_stylebox_override("panel", PixelUI.component_style(PixelUI.COMPONENT_NORMAL))
	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right"]:
		pad.add_theme_constant_override(side, 12)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(pad)
	pad.add_child(_make_item_line(item))
	var long_press := LongPressInput.new()
	panel.add_child(long_press)
	long_press.tapped.connect(_on_discard_row_tapped.bind(item))
	long_press.long_pressed.connect(_on_row_long_pressed.bind(item, panel))
	_discard_rows[item.id] = panel
	return panel


func _on_discard_row_tapped(item: ItemData) -> void:
	AudioManager.play_select()
	_selected_discard_id = str(item.id)
	_refresh_discard_selection()
	if _confirm_discard_button != null:
		_confirm_discard_button.disabled = false


func _refresh_discard_selection() -> void:
	for item_id_variant in _discard_rows:
		var panel: PanelContainer = _discard_rows[item_id_variant] as PanelContainer
		if panel == null:
			continue
		var kind: String = PixelUI.COMPONENT_SELECTED if str(item_id_variant) == _selected_discard_id else PixelUI.COMPONENT_NORMAL
		panel.add_theme_stylebox_override("panel", PixelUI.component_style(kind))


func _resolve_discard() -> void:
	if _resolved or _selected_discard_id == "":
		return
	_resolved = true
	AudioManager.play_select()
	var cb: Callable = _on_resolve
	var discard_id: String = _selected_discard_id
	LoadoutMenu.dismiss()
	if cb.is_valid():
		cb.call(discard_id)


func _resolve_abandon() -> void:
	if _resolved:
		return
	_resolved = true
	var cb: Callable = _on_resolve
	LoadoutMenu.dismiss()
	if cb.is_valid():
		cb.call("")


# A single loadout row: LARGE bare icon beside the name + a pip preview of the
# item's effect (long-press for the full description). Filled item slots are
# tappable (invoke the use-callback); empty slots and the relic row are
# display-only.
func _make_slot_row(item: ItemData, usable: bool) -> Control:
	var filled: bool = item != null
	var accent: Color = _slot_accent(item, usable)

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ICON_SIZE + 8.0)
	var row_style: StyleBoxFlat = PixelUI.make_hard_style(Color.TRANSPARENT, Color.TRANSPARENT, 0)
	row_style.set_content_margin_all(2.0)
	row.add_theme_stylebox_override("panel", row_style)
	# Any filled row is STOP so it can receive the long-press gesture; empty slots stay IGNORE.
	row.mouse_filter = Control.MOUSE_FILTER_STOP if filled else Control.MOUSE_FILTER_IGNORE

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hbox)

	hbox.add_child(_make_icon(item))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 6)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(info)

	var name_text: String = item.display_name if filled else "-"
	var name_color: Color = (accent if filled else PixelUI.INSPECT_TEXT_DIM)
	var name_label := _make_label(name_text, NAME_FONT, name_color, HORIZONTAL_ALIGNMENT_LEFT)
	info.add_child(name_label)

	# Effect-pip preview — the "what does it do" hint without the long text.
	if filled:
		var pips: Array = EffectPip.effects_from_passive(item.effect, item.target_kind)
		if not pips.is_empty():
			var pip_row := HBoxContainer.new()
			pip_row.add_theme_constant_override("separation", 10)
			pip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for pip_variant in pips:
				pip_row.add_child(EffectPip.build_group(pip_variant, ROW_PIP_PROFILE))
			info.add_child(pip_row)

	# Name every item slot (filled or empty) so the slot count is inspectable; relic
	# rows are only built when a relic is present.
	row.name = "LoadoutItemRow" if usable else "LoadoutRelicRow"
	if filled:
		# Long-press inspects any filled item/relic (same InspectPopup as the battle cards);
		# a quick tap on a usable item still uses it. LongPressInput disambiguates the two.
		var long_press := LongPressInput.new()
		row.add_child(long_press)
		long_press.long_pressed.connect(_on_row_long_pressed.bind(item, row))
		if usable:
			long_press.tapped.connect(_on_item_row_tapped.bind(row, item))
	return row


# Bare, large icon — no outline, no shape frame (Kev 2026-07-10).
func _make_icon(item: ItemData) -> Control:
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	center.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item != null and item.icon != null:
		var tex := TextureRect.new()
		tex.custom_minimum_size = Vector2(ICON_TEXTURE, ICON_TEXTURE)
		tex.texture = item.icon
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(tex)
	return center


func _slot_accent(item: ItemData, usable: bool) -> Color:
	if item == null:
		return PixelUI.INSPECT_TEXT_DIM
	if not usable:
		return PixelUI.rarity_color("legendary")
	return PixelUI.rarity_color(item.rarity if item.rarity != "" else "common")


# ── Layout / position ─────────────────────────────────────────────────────────
func _relayout(anchor_rect: Rect2) -> void:
	if _panel == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var top_limit: float = SCREEN_MARGIN
	var header_node := get_node_or_null("/root/PersistentHeader")
	if header_node != null:
		# band_height() = HEADER_HEIGHT + the top safe-area inset (camera
		# cutout), so the panel clamp also clears the grown band on device.
		if header_node.has_method("band_height"):
			top_limit = float(header_node.call("band_height")) + SCREEN_MARGIN
		else:
			var value: Variant = header_node.get("HEADER_HEIGHT")
			top_limit = (float(value) if value != null else HEADER_BAND_HEIGHT) + SCREEN_MARGIN

	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.size = Vector2(PANEL_WIDTH, 0)
	await get_tree().process_frame
	await get_tree().process_frame

	var height: float = minf(_panel.get_combined_minimum_size().y, viewport_size.y - top_limit - SCREEN_MARGIN)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, height)
	_panel.size = Vector2(PANEL_WIDTH, height)

	var pos: Vector2
	if anchor_rect.size == Vector2.ZERO:
		pos = (viewport_size - Vector2(PANEL_WIDTH, height)) * 0.5
	else:
		# Float above the item button, right-aligned to it.
		pos = Vector2(anchor_rect.end.x - PANEL_WIDTH, anchor_rect.position.y - height - SCREEN_MARGIN)
	pos.x = clampf(pos.x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, viewport_size.x - PANEL_WIDTH - SCREEN_MARGIN))
	pos.y = clampf(pos.y, top_limit, maxf(top_limit, viewport_size.y - height - SCREEN_MARGIN))
	_panel.position = pos
	_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)


# ── Input ─────────────────────────────────────────────────────────────────────
func _on_item_row_tapped(row: Control, item: ItemData) -> void:
	if not _on_use.is_valid():
		LoadoutMenu.dismiss()
		return
	# Call the use-callback while the menu is still open. It returns true if the item was
	# accepted (close the menu) or false if it was rejected for insufficient Protocol (keep
	# the menu open and flash the tapped row red).
	var accepted: bool = bool(_on_use.call(item))
	if accepted:
		LoadoutMenu.dismiss()
	else:
		_flash_row_rejected(row)


# Long-press on any filled row (item or relic) opens the unified inspect popup, which floats
# above the loadout (POPUP_LAYER 130 > MENU_LAYER 128) and self-dismisses on outside press.
func _on_row_long_pressed(_global_position: Vector2, item: ItemData, row: Control) -> void:
	if item == null:
		return
	AudioManager.play_select()
	var anchor: Rect2 = row.get_global_rect() if is_instance_valid(row) else Rect2()
	InspectPopup.open(self, InspectResolver.resolve_item(item), anchor, row.get_instance_id())


# Pulse the row red to signal "can't use this" (insufficient Protocol) without closing the menu.
func _flash_row_rejected(row: Control) -> void:
	if row == null or not is_instance_valid(row):
		return
	row.modulate = Color(1.0, 0.30, 0.30, 1.0)
	var tween := create_tween()
	tween.tween_property(row, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.35) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_catcher_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed:
		# Tap-outside = ABANDON in discard mode (same no-destroy semantics), plain
		# dismiss otherwise.
		if _discard_mode:
			_resolve_abandon()
		else:
			LoadoutMenu.dismiss()


# ── Style helpers ─────────────────────────────────────────────────────────────
func _make_label(text: String, font_size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = align
	PixelUI.style_label(label, font_size, color, 2)
	return label


func _divider(thickness: int, color: Color) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(0, thickness)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line
