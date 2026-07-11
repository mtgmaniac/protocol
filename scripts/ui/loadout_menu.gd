# The themed LOADOUT menu opened from the battle item button. Shows the player's consumable
# slots (3) and relic (1) in the shared Dithered-Terminal / inspect styling. Each row is a
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
const ITEM_SLOTS := 3
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


static func dismiss() -> void:
	if _active != null and is_instance_valid(_active):
		_active.queue_free()
	_active = null


static func is_open() -> bool:
	return _active != null and is_instance_valid(_active)


# `items` = Array[ItemData] consumables; `relic` = ItemData or null; `on_use` is called with
# the tapped ItemData. `anchor_rect` = the item button's global rect (menu floats above it);
# empty Rect2 centers.
static func open(host: Node, items: Array, relic: Resource, on_use: Callable, anchor_rect: Rect2 = Rect2()) -> void:
	if host == null or not host.is_inside_tree():
		return
	dismiss()
	var menu := LoadoutMenu.new()
	host.get_tree().root.add_child(menu)
	menu._on_use = on_use
	menu._build(items, relic, anchor_rect)
	_active = menu


func _build(items: Array, relic: Resource, anchor_rect: Rect2) -> void:
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
	var style: StyleBoxFlat = PixelUI.make_hard_style(PixelUI.INSPECT_BG, PixelUI.INSPECT_BORDER, PANEL_BORDER)
	style.set_content_margin_all(0.0)
	_panel.add_theme_stylebox_override("panel", style)
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
	for i in ITEM_SLOTS:
		var item: ItemData = items[i] as ItemData if i < items.size() else null
		item_rows.add_child(_make_slot_row(item, true))

	content.add_child(_divider(SECTION_DIVIDER, PixelUI.INSPECT_DIVIDER))
	content.add_child(_make_label("RELIC", SECTION_FONT, PixelUI.INSPECT_TEXT_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	content.add_child(_make_slot_row(relic as ItemData, false))

	call_deferred("_relayout", anchor_rect)


# A single loadout row: LARGE bare icon beside the name + a pip preview of the
# item's effect (long-press for the full description). Filled item slots are
# tappable (invoke the use-callback); empty slots and the relic row are
# display-only.
func _make_slot_row(item: ItemData, usable: bool) -> Control:
	var filled: bool = item != null
	var accent: Color = _slot_accent(item, usable)

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ICON_SIZE + 8.0)
	var row_style: StyleBoxFlat = PixelUI.make_hard_style(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0)
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

	var name_text: String = item.display_name if filled else "—"
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

	if filled:
		# Long-press inspects any filled item/relic (same InspectPopup as the battle cards);
		# a quick tap on a usable item still uses it. LongPressInput disambiguates the two.
		var long_press := LongPressInput.new()
		row.add_child(long_press)
		long_press.long_pressed.connect(_on_row_long_pressed.bind(item, row))
		if usable:
			row.name = "LoadoutItemRow"
			long_press.tapped.connect(_on_item_row_tapped.bind(row, item))
		else:
			row.name = "LoadoutRelicRow"
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
