# The single themed long-press INSPECT popup. Data-blind: it renders a structured payload
# (see InspectResolver for the schema) and knows only about layout + PixelUI tokens. One
# instance visible at a time; lives on its own high CanvasLayer so it floats above the
# battle HUD. Dismiss on any press outside, or via a second long-press on the same source.
#
# Direction-05 aesthetic: flat INSPECT_BG surface, 2px hard border in the payload accent,
# blocky corners, m5x7 font via PixelUI. No gradients / glows / shadows. Scrolls when the
# content (tall unit breakouts) exceeds the available height, clamped below the persistent
# header and fully on-screen in the 1080x2400 portrait viewport.
class_name InspectPopup
extends CanvasLayer

const POPUP_LAYER := 130
const SCREEN_MARGIN := 18.0
const PANEL_WIDTH_FRACTION := 0.86
const PANEL_MIN_WIDTH := 360.0
const PANEL_MAX_WIDTH := 780.0
const PANEL_BORDER := 3
const CONTENT_PAD := 22
const SECTION_SEP := 12
const ROW_SEP := 5
const SECTION_DIVIDER := 2
const HEADER_DIVIDER := 6   # thicker rule under the name/descriptor

# Mirrors PersistentHeader.HEADER_HEIGHT. Read dynamically (below) rather than via the
# autoload global symbol so this script also compiles when pulled in by a --script tool
# harness, where autoload globals aren't registered yet.
const HEADER_BAND_HEIGHT := 144.0

const TITLE_FONT := 50
const SUBTITLE_FONT := 32
const SECTION_LABEL_FONT := 26
const ABILITY_NAME_FONT := 38
const META_FONT := 26
const ROLL_FONT := 34
const BODY_FONT := 36
const HINT_FONT := 26
const HEADER_ICON_SIZE := 84.0

static var _active: InspectPopup = null
static var _active_source: int = 0

var _catcher: Control = null
var _panel: PanelContainer = null
var _scroll: ScrollContainer = null
var _content: VBoxContainer = null
var _accent: Color = PixelUI.INSPECT_BORDER


# ── Static lifecycle (one popup at a time) ──────────────────────────────────────
static func dismiss() -> void:
	if _active != null and is_instance_valid(_active):
		_active.queue_free()
	_active = null
	_active_source = 0


static func is_open() -> bool:
	return _active != null and is_instance_valid(_active)


# `host` supplies the scene tree. `anchor_rect` is the pressed element's global rect; pass
# an empty Rect2() to center. `source_id` (a control's instance id) enables toggle: a
# second long-press on the same source closes the popup instead of reopening it.
static func open(host: Node, payload: Dictionary, anchor_rect: Rect2 = Rect2(), source_id: int = 0) -> void:
	if host == null or not host.is_inside_tree() or payload.is_empty():
		return
	if is_open() and source_id != 0 and _active_source == source_id:
		dismiss()
		return
	dismiss()
	var popup := InspectPopup.new()
	host.get_tree().root.add_child(popup)
	popup._build(payload, anchor_rect)
	_active = popup
	_active_source = source_id


# ── Build ───────────────────────────────────────────────────────────────────────
func _build(payload: Dictionary, anchor_rect: Rect2) -> void:
	layer = POPUP_LAYER
	_accent = payload.get("accent", PixelUI.INSPECT_BORDER)

	_catcher = Control.new()
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_catcher.gui_input.connect(_on_dismiss_input)
	add_child(_catcher)

	# The panel itself is a tap-to-close target too (not only the catcher behind it).
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_panel.gui_input.connect(_on_dismiss_input)
	# Transparent until _relayout has positioned it, so it never flashes at the top-left
	# corner for the frame before layout resolves. We use modulate (not `visible`) because a
	# hidden PanelContainer won't sort its subtree, so the width never reaches the autowrap
	# labels during _relayout's measurement — they'd report their unwrapped (huge) height and
	# the panel would size to the whole screen. modulate keeps layout live but invisible.
	_panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CONTENT_PAD)
	margin.add_theme_constant_override("margin_top", CONTENT_PAD)
	margin.add_theme_constant_override("margin_right", CONTENT_PAD)
	margin.add_theme_constant_override("margin_bottom", CONTENT_PAD)
	_panel.add_child(margin)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	margin.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", SECTION_SEP)
	_scroll.add_child(_content)

	_build_sections(_content, payload)
	# Mouse-ignore everything inside the panel so a press anywhere on the popup falls
	# through to the panel (or the catcher, when outside) and dismisses it.
	_set_descendants_ignore(_panel)

	# Size + position once layout has resolved.
	call_deferred("_relayout", anchor_rect)


func _build_sections(content: VBoxContainer, payload: Dictionary) -> void:
	var header: Dictionary = payload.get("header", {})
	var has_header: bool = not header.is_empty()
	if has_header:
		content.add_child(_build_header(header))

	# The first divider after the header is the thick rule; everything else is the thin
	# section divider.
	var prev_exists: bool = has_header
	var first_content: bool = true

	# Active statuses sit directly under the header (where the role subtitle used to be):
	# each is a pip beside its description.
	var statuses: Array = payload.get("statuses", [])
	if not statuses.is_empty():
		_add_section(content, prev_exists, first_content and has_header, _build_statuses(statuses), "ACTIVE EFFECTS")
		prev_exists = true
		first_content = false

	var roll_table: Array = payload.get("roll_table", [])
	if not roll_table.is_empty():
		_add_section(content, prev_exists, first_content and has_header, _build_roll_table(roll_table), "ROLL RANGE")
		prev_exists = true
		first_content = false

	var abilities: Array = payload.get("abilities", [])
	if not abilities.is_empty():
		var block := VBoxContainer.new()
		block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		block.add_theme_constant_override("separation", ROW_SEP + 6)
		for i in abilities.size():
			if i > 0:
				block.add_child(_divider())
			block.add_child(_build_ability(abilities[i]))
		_add_section(content, prev_exists, first_content and has_header, block, "")
		prev_exists = true
		first_content = false

	var stats: Array = payload.get("stats", [])
	if not stats.is_empty():
		_add_section(content, prev_exists, first_content and has_header, _build_stats(stats), "")
		prev_exists = true
		first_content = false

	var description: String = str(payload.get("description", "")).strip_edges()
	if description != "":
		_add_section(content, prev_exists, first_content and has_header, _make_label(description, BODY_FONT, PixelUI.INSPECT_TEXT_MUTED, true), "")
		prev_exists = true
		first_content = false

	content.add_child(_divider())
	var hint := _make_label("Tap anywhere to close", HINT_FONT, PixelUI.INSPECT_TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)


func _add_section(content: VBoxContainer, prepend_divider: bool, thick: bool, node: Control, label: String) -> void:
	if prepend_divider:
		if thick:
			content.add_child(_divider(HEADER_DIVIDER, PixelUI.INSPECT_BORDER))
		else:
			content.add_child(_divider())
	if label != "":
		content.add_child(_make_label(label, SECTION_LABEL_FONT, PixelUI.INSPECT_TEXT_DIM))
	content.add_child(node)


func _build_header(header: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)

	var icon: Texture2D = header.get("icon") as Texture2D
	var icon_char: String = str(header.get("icon_char", ""))
	if icon != null:
		var frame := PanelContainer.new()
		frame.custom_minimum_size = Vector2(HEADER_ICON_SIZE, HEADER_ICON_SIZE)
		frame.clip_contents = true
		frame.add_theme_stylebox_override("panel", PixelUI.make_hard_style(PixelUI.INSPECT_BG, _accent, 2))
		var tex := TextureRect.new()
		tex.texture = icon
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		frame.add_child(tex)
		row.add_child(frame)
	elif icon_char != "":
		row.add_child(_make_label(icon_char, 48, _accent, false))

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_box.add_theme_constant_override("separation", 2)
	row.add_child(title_box)

	title_box.add_child(_make_label(str(header.get("title", "")), TITLE_FONT, _accent, false, 3))
	var subtitle: String = str(header.get("subtitle", ""))
	if subtitle != "":
		title_box.add_child(_make_label(subtitle.to_upper(), SUBTITLE_FONT, PixelUI.INSPECT_TEXT_MUTED))
	return row


func _build_roll_table(rows: Array) -> Control:
	var table := VBoxContainer.new()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_theme_constant_override("separation", ROW_SEP)
	for row_variant in rows:
		var entry: Dictionary = row_variant
		var line := HBoxContainer.new()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_theme_constant_override("separation", 12)
		var range_label := _make_label(str(entry.get("range", "")), BODY_FONT, _accent)
		range_label.custom_minimum_size = Vector2(120, 0)
		line.add_child(range_label)
		var zone_label := _make_label(str(entry.get("zone", "")), META_FONT, PixelUI.INSPECT_TEXT_DIM)
		zone_label.custom_minimum_size = Vector2(180, 0)
		line.add_child(zone_label)
		var name_label := _make_label(str(entry.get("name", "")), BODY_FONT, PixelUI.INSPECT_TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.add_child(name_label)
		table.add_child(line)
	return table


func _build_ability(ability: Dictionary) -> Control:
	# Row 1: "Roll: a - b" + ability name (accent). Row 2: effect pip(s) + effect text.
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", ROW_SEP)

	var roll_text: String = str(ability.get("roll", ""))
	var name_text: String = str(ability.get("name", ""))
	if roll_text != "" or name_text != "":
		var row1 := HBoxContainer.new()
		row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row1.add_theme_constant_override("separation", 12)
		if roll_text != "":
			var roll_label := _make_label("Roll: %s" % roll_text, ROLL_FONT, PixelUI.INSPECT_TEXT_MUTED)
			roll_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			roll_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row1.add_child(roll_label)
		if name_text != "":
			var name_label := _make_label(name_text, ABILITY_NAME_FONT, _accent)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row1.add_child(name_label)
		box.add_child(row1)

	var effects: Array = ability.get("effects", [])
	var text: String = str(ability.get("text", "")).strip_edges()
	if not effects.is_empty() or text != "":
		var row2 := HBoxContainer.new()
		row2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_theme_constant_override("separation", 10)
		for effect_variant in effects:
			# Top-align the pip so it sits on the first line of wrapping text.
			var group: Control = EffectPip.build_group(effect_variant, EffectPip.PROFILE_CARD)
			group.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row2.add_child(group)
		if text != "":
			var text_label := _make_label(text, BODY_FONT, PixelUI.INSPECT_TEXT_MUTED, true)
			text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row2.add_child(text_label)
		box.add_child(row2)
	return box


# Active-status rows: each is the status pip(s) followed by its text description, the same
# pip-beside-text layout abilities use.
func _build_statuses(entries: Array) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", ROW_SEP)
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 10)
		for effect_variant in entry.get("effects", []):
			var group: Control = EffectPip.build_group(effect_variant, EffectPip.PROFILE_CARD)
			group.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(group)
		var text: String = str(entry.get("text", "")).strip_edges()
		if text != "":
			var text_label := _make_label(text, BODY_FONT, PixelUI.INSPECT_TEXT_MUTED, true)
			text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(text_label)
		box.add_child(row)
	return box


func _build_stats(stats: Array) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", ROW_SEP)
	for stat_variant in stats:
		var stat: Dictionary = stat_variant
		var line := HBoxContainer.new()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_theme_constant_override("separation", 12)
		var label := _make_label(str(stat.get("label", "")), BODY_FONT, PixelUI.INSPECT_TEXT_MUTED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(label)
		line.add_child(_make_label(str(stat.get("value", "")), BODY_FONT, PixelUI.INSPECT_TEXT))
		box.add_child(line)
	return box


# ── Layout / positioning ────────────────────────────────────────────────────────
func _relayout(anchor_rect: Rect2) -> void:
	if _panel == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var top_limit: float = SCREEN_MARGIN
	# Clamp below the persistent header band (a CanvasLayer autoload) so the popup never
	# renders under it.
	var header_node := get_node_or_null("/root/PersistentHeader")
	if header_node != null:
		top_limit = _header_band_height(header_node) + SCREEN_MARGIN

	var width: float = clampf(viewport_size.x * PANEL_WIDTH_FRACTION, PANEL_MIN_WIDTH, PANEL_MAX_WIDTH)
	var max_height: float = viewport_size.y - top_limit - SCREEN_MARGIN
	# Pin the width first so the inner content gets a width to wrap against, then measure
	# the wrapped content height (a ScrollContainer's own min height is ~0, so we drive its
	# height from the content and only let it scroll past max_height).
	_panel.custom_minimum_size = Vector2(width, 0)
	_panel.size = Vector2(width, 0)
	await get_tree().process_frame
	await get_tree().process_frame

	var content_height: float = _content.get_combined_minimum_size().y
	var scroll_height: float = clampf(content_height, 0.0, max_height - CONTENT_PAD * 2.0)
	_scroll.custom_minimum_size = Vector2(0, scroll_height)
	await get_tree().process_frame

	var height: float = minf(_panel.get_combined_minimum_size().y, max_height)
	_panel.custom_minimum_size = Vector2(width, height)
	_panel.size = Vector2(width, height)

	var pos: Vector2
	if anchor_rect.size == Vector2.ZERO:
		pos = (viewport_size - Vector2(width, height)) * 0.5
	else:
		var x: float = anchor_rect.position.x + anchor_rect.size.x * 0.5 - width * 0.5
		var y: float = anchor_rect.position.y + anchor_rect.size.y + SCREEN_MARGIN
		if y + height > viewport_size.y - SCREEN_MARGIN:
			y = anchor_rect.position.y - height - SCREEN_MARGIN
		pos = Vector2(x, y)
	pos.x = clampf(pos.x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, viewport_size.x - width - SCREEN_MARGIN))
	pos.y = clampf(pos.y, top_limit, maxf(top_limit, viewport_size.y - height - SCREEN_MARGIN))
	_panel.position = pos
	_panel.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _header_band_height(header: Node) -> float:
	var value: Variant = header.get("HEADER_HEIGHT")
	return float(value) if value != null else HEADER_BAND_HEIGHT


# ── Dismiss ───────────────────────────────────────────────────────────────────
func _on_dismiss_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed:
		InspectPopup.dismiss()


func _set_descendants_ignore(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_set_descendants_ignore(child)


# ── Style helpers ───────────────────────────────────────────────────────────────
func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = PixelUI.make_hard_style(PixelUI.INSPECT_BG, _accent, PANEL_BORDER)
	style.set_content_margin_all(0.0)
	return style


func _divider(thickness: int = SECTION_DIVIDER, color: Color = PixelUI.INSPECT_DIVIDER) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(0, thickness)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line


func _make_label(text: String, font_size: int, color: Color, wrap: bool = false, outline: int = 2) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelUI.style_label(label, font_size, color, outline)
	return label
