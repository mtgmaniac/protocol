# Home / title screen: operation carousel + squad picker + BEGIN RUN.
#
# Design notes:
# - Authored against the 1080x2400 logical viewport (project base). All on-screen
#   pixel values from the spec are multiplied by DESIGN_SCALE = 2.4 to land in
#   logical units. Window is previewed at 450x1000 (0.4167x); Godot's
#   "canvas_items" stretch scales everything down uniformly.
# - Fonts use m5x7 at clean pixel-perfect multiples: 16 / 32 / 48 logical only.
#   We bypass PixelUI.style_label because its scale_font_size multiplies by 1.35
#   and snaps to a ladder that never hits 16, which would make small labels fuzzy.
# - Colors come from the Theme singleton where possible; on-spec colors not in
#   Theme (chip backgrounds/borders, button states) are inlined here so the
#   global palette isn't polluted by single-screen variants.
extends Control

# Godot's built-in `Theme` class shadows our `Theme` autoload at parse time, so
# we preload the singleton's script under a different name to access its color
# constants. Same workaround used by compact_unit_card.gd.
const UiTheme = preload("res://scripts/autoloads/Theme.gd")


# ─── Sizing constants (all in LOGICAL units, on-screen px × 2.4) ──────────────
const DESIGN_SCALE := 2.4

const ROOT_MARGIN_X := 60                 # ≈ 25 on-screen
const ROOT_MARGIN_TOP := 60
const ROOT_MARGIN_BOTTOM := 60
const SECTION_GAP := 32                   # ≈ 13 on-screen

const LOGO_MIN_HEIGHT := 220              # ≈ 92; aspect ratio of source decides actual
const LOGO_MAX_HEIGHT := 320              # ceiling so logo doesn't crowd the rest

const HEADER_FONT_SIZE := 24              # "CHOOSE OPERATION", "SELECT SQUAD"
const COUNTER_FONT_SIZE := 24             # "X / 3"
const HEADER_TO_CONTENT_GAP := 18

const CARD_WIDTH := 672                   # 280 px
const CARD_MIN_HEIGHT := 432              # 180 px
const CARD_GAP := 24                      # 10 px
const CARD_PADDING_X := 38                # 16 px
const CARD_PADDING_Y := 34                # 14 px
const CARD_BORDER := 2                    # 1 px
const CARD_RADIUS := 4                    # 2 px (max per spec)
const CARD_ICON_SIZE := 96                # 40 px
const CARD_NAME_FONT := 32                # 14 px → snap up to 32 logical (2x m5x7)
const CARD_TAG_FONT := 24                 # difficulty chip text
const CARD_DESC_FONT := 24                # operation description
const CARD_META_FONT := 24                # "N encounters · Tier X"
const CARD_LOCKED_ALPHA := 0.3

const DOT_SIZE := 14                      # 6 px
const DOT_GAP := 14
const DOT_RADIUS := 2                     # ≈ 1 px logical

const DIVIDER_THICK := 2                  # 1 px

const UNIT_THUMB_WIDTH := 173
const UNIT_THUMB_FRAME_H := 192
const UNIT_THUMB_GAP := 24                # 10 px
const UNIT_NAME_FONT := 24                # unit name below thumbnail
const UNIT_ROLE_FONT := 16                # unit role below name
const UNIT_NAME_TO_ROLE_GAP := 4
const UNIT_FRAME_TO_NAME_GAP := 16
const CHECK_SIZE := 29                    # selection check badge
const CHECK_INSET := 8                    # offset from top-right

const DETAIL_PADDING_X := 29              # detail panel horizontal padding
const DETAIL_PADDING_Y := 24              # detail panel vertical padding
const DETAIL_PORTRAIT_W := 106
const DETAIL_PORTRAIT_H := 125
const DETAIL_NAME_FONT := 32              # 13 px → snap to 32
const DETAIL_ROLE_FONT := 24              # detail panel role
const DETAIL_STAT_FONT := 24              # detail panel HP stat

const BEGIN_PAD_X := 29                   # BEGIN RUN button horizontal padding
const BEGIN_PAD_Y := 29                   # BEGIN RUN button vertical padding
const BEGIN_FONT := 32                    # 13 px → 32 logical
const BEGIN_BORDER := 2                   # 1 px

const MAX_SELECTED_UNITS := 3

# Snap-to-card debounce after a scroll event.
const CAROUSEL_SNAP_DEBOUNCE_S := 0.18
const CAROUSEL_SNAP_TWEEN_S := 0.18

# Difficulty palette (per spec, not in Theme singleton).
const DIFF_STANDARD := {
	"label": "STANDARD",
	"text": Color("#00ff88"),
	"bg": Color("#0a1a0a"),
	"border": Color("#1a3a1a"),
}
const DIFF_ADVANCED := {
	"label": "ADVANCED",
	"text": Color("#e8c040"),
	"bg": Color("#1a1a0a"),
	"border": Color("#3a3a1a"),
}
const DIFF_ELITE := {
	"label": "ELITE",
	"text": Color("#ff5040"),
	"bg": Color("#1a0a0a"),
	"border": Color("#3a1010"),
}

# Begin-run states
const BEGIN_NOT_READY_BG := Color("#0a0a0a")
const BEGIN_NOT_READY_BORDER := Color("#1a1a1a")
const BEGIN_NOT_READY_TEXT := Color("#2a2a2a")
const BEGIN_READY_BG := Color("#0a2a0a")
const BEGIN_READY_BORDER := Color("#00ff88")
const BEGIN_READY_TEXT := Color("#00ff88")

# Divider color (Theme has no exact match)
const DIVIDER_COLOR := Color("#0f1e2e")

# Inactive carousel dot
const DOT_INACTIVE := Color("#0f2030")


# ─── State ────────────────────────────────────────────────────────────────────
var _operation_ids: Array[String] = []
var _selected_operation_id: String = ""
var _selected_unit_ids: Array[String] = []
# The unit whose detail panel is currently displayed. Doesn't have to be
# selected — the spec says tapping a unit shows its details.
var _focused_unit_id: String = ""

# Built nodes
var _operation_carousel: ScrollContainer
var _operation_row: HBoxContainer
var _operation_cards: Dictionary = {}   # operation_id -> Dictionary { card, border_stylebox }
var _dot_row: HBoxContainer
var _dot_nodes: Array[ColorRect] = []
var _unit_thumb_row: HBoxContainer
var _unit_thumbs: Dictionary = {}        # unit_id -> Dictionary { card, name, role, check }
var _detail_panel: PanelContainer
var _detail_portrait: TextureRect
var _detail_name: Label
var _detail_role: Label
var _detail_hp: RichTextLabel
var _begin_button: Button
var _begin_panel: PanelContainer
var _begin_normal_style: StyleBoxFlat

var _snap_timer: Timer


# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	_apply_background()
	_build_layout()
	_populate_operations()
	_populate_units()
	_refresh_begin_button()


func _apply_background() -> void:
	var bg := ColorRect.new()
	bg.color = UiTheme.VOID
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)


func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", ROOT_MARGIN_X)
	margin.add_theme_constant_override("margin_right", ROOT_MARGIN_X)
	margin.add_theme_constant_override("margin_top", ROOT_MARGIN_TOP)
	margin.add_theme_constant_override("margin_bottom", ROOT_MARGIN_BOTTOM)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SECTION_GAP)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(column)

	column.add_child(_build_logo())
	column.add_child(_build_operation_section())
	column.add_child(_build_divider())
	column.add_child(_build_squad_section())
	column.add_child(_build_begin_button())


# ─── Logo ─────────────────────────────────────────────────────────────────────
func _build_logo() -> Control:
	var wrapper := CenterContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var logo := TextureRect.new()
	logo.texture = DataManager.get_logo_texture()
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	logo.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Lock to a visually sensible height window so the logo doesn't dominate.
	logo.custom_minimum_size = Vector2(0, LOGO_MIN_HEIGHT)
	wrapper.add_child(logo)
	return wrapper


# ─── Operation section ────────────────────────────────────────────────────────
func _build_operation_section() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", HEADER_TO_CONTENT_GAP)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	section.add_child(_make_header_label("CHOOSE OPERATION", UiTheme.GOLD))

	_operation_carousel = ScrollContainer.new()
	_operation_carousel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_operation_carousel.custom_minimum_size = Vector2(0, CARD_MIN_HEIGHT)
	_operation_carousel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_operation_carousel.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Hide the scrollbar — we provide dot indicators instead.
	var h_scroll := _operation_carousel.get_h_scroll_bar()
	if h_scroll != null:
		h_scroll.modulate = Color(1, 1, 1, 0)
		h_scroll.custom_minimum_size = Vector2(0, 0)
	section.add_child(_operation_carousel)

	_operation_row = HBoxContainer.new()
	_operation_row.add_theme_constant_override("separation", CARD_GAP)
	_operation_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_operation_carousel.add_child(_operation_row)

	_dot_row = HBoxContainer.new()
	_dot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dot_row.add_theme_constant_override("separation", DOT_GAP)
	_dot_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(_dot_row)

	_snap_timer = Timer.new()
	_snap_timer.one_shot = true
	_snap_timer.wait_time = CAROUSEL_SNAP_DEBOUNCE_S
	_snap_timer.timeout.connect(_snap_carousel_to_center)
	add_child(_snap_timer)
	if h_scroll != null:
		h_scroll.value_changed.connect(_on_carousel_scrolled)

	return section


# ─── Divider ──────────────────────────────────────────────────────────────────
func _build_divider() -> Control:
	var divider := ColorRect.new()
	divider.color = DIVIDER_COLOR
	divider.custom_minimum_size = Vector2(0, DIVIDER_THICK)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider


# ─── Squad section ────────────────────────────────────────────────────────────
func _build_squad_section() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", HEADER_TO_CONTENT_GAP)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	section.add_child(_make_header_label("SELECT SQUAD", UiTheme.CYAN))

	var counter := _make_pixel_label("0 / %d" % MAX_SELECTED_UNITS, COUNTER_FONT_SIZE, UiTheme.MUTED)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.name = "SquadCounter"
	section.add_child(counter)

	var thumb_scroll := ScrollContainer.new()
	thumb_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thumb_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	thumb_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var thumb_h_scroll := thumb_scroll.get_h_scroll_bar()
	if thumb_h_scroll != null:
		thumb_h_scroll.modulate = Color(1, 1, 1, 0)
		thumb_h_scroll.custom_minimum_size = Vector2(0, 0)
	thumb_scroll.custom_minimum_size = Vector2(
		0,
		UNIT_THUMB_FRAME_H + UNIT_FRAME_TO_NAME_GAP + UNIT_NAME_FONT + UNIT_NAME_TO_ROLE_GAP + UNIT_ROLE_FONT + 8
	)
	# All 8 specialists exist in the row, but at spec sizes (173 logical wide
	# + 24 gap) the row totals ~1552 logical, which overflows the ~960 logical
	# viewport — only 5 thumbs fit at once. The scrollbar is intentionally
	# invisible per spec, so plain vertical-wheel scroll is redirected to
	# horizontal here to make the off-screen units (Splice Medic, Pulse Tech,
	# Spite Guard) reachable without needing Shift+Wheel.
	thumb_scroll.gui_input.connect(_redirect_wheel_to_horizontal.bind(thumb_scroll))
	section.add_child(thumb_scroll)

	_unit_thumb_row = HBoxContainer.new()
	_unit_thumb_row.add_theme_constant_override("separation", UNIT_THUMB_GAP)
	thumb_scroll.add_child(_unit_thumb_row)

	_detail_panel = _build_detail_panel()
	_detail_panel.visible = false
	section.add_child(_detail_panel)

	return section


func _build_detail_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(UiTheme.RAISED, UiTheme.BORDER_PLAYER))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", DETAIL_PADDING_X)
	margin.add_theme_constant_override("margin_right", DETAIL_PADDING_X)
	margin.add_theme_constant_override("margin_top", DETAIL_PADDING_Y)
	margin.add_theme_constant_override("margin_bottom", DETAIL_PADDING_Y)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DETAIL_PADDING_X)
	margin.add_child(row)

	_detail_portrait = TextureRect.new()
	_detail_portrait.custom_minimum_size = Vector2(DETAIL_PORTRAIT_W, DETAIL_PORTRAIT_H)
	_detail_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_detail_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_detail_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_detail_portrait)

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 6)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text_col)

	_detail_name = _make_pixel_label("", DETAIL_NAME_FONT, UiTheme.CYAN)
	text_col.add_child(_detail_name)

	_detail_role = _make_pixel_label("", DETAIL_ROLE_FONT, UiTheme.MUTED)
	text_col.add_child(_detail_role)

	_detail_hp = RichTextLabel.new()
	_detail_hp.bbcode_enabled = true
	_detail_hp.fit_content = true
	_detail_hp.autowrap_mode = TextServer.AUTOWRAP_OFF
	_detail_hp.scroll_active = false
	_detail_hp.add_theme_font_override("normal_font", PixelUI.get_pixel_font())
	_detail_hp.add_theme_font_size_override("normal_font_size", DETAIL_STAT_FONT)
	_detail_hp.add_theme_color_override("default_color", UiTheme.MUTED)
	_detail_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(_detail_hp)

	return panel


# ─── BEGIN RUN button ─────────────────────────────────────────────────────────
func _build_begin_button() -> Control:
	# Wrap in PanelContainer for the bordered "card" look; Button itself just
	# handles input and label rendering.
	_begin_panel = PanelContainer.new()
	_begin_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_begin_normal_style = _make_panel_style(BEGIN_NOT_READY_BG, BEGIN_NOT_READY_BORDER)
	_begin_panel.add_theme_stylebox_override("panel", _begin_normal_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", BEGIN_PAD_X)
	margin.add_theme_constant_override("margin_right", BEGIN_PAD_X)
	margin.add_theme_constant_override("margin_top", BEGIN_PAD_Y)
	margin.add_theme_constant_override("margin_bottom", BEGIN_PAD_Y)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_begin_panel.add_child(margin)

	_begin_button = Button.new()
	_begin_button.flat = true
	_begin_button.focus_mode = Control.FOCUS_NONE
	_begin_button.text = "BEGIN RUN"
	_begin_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_font(_begin_button, BEGIN_FONT, BEGIN_NOT_READY_TEXT)
	_begin_button.pressed.connect(_on_begin_run_pressed)
	margin.add_child(_begin_button)

	return _begin_panel


# ─── Operations: data + cards ─────────────────────────────────────────────────
func _populate_operations() -> void:
	_operation_ids.clear()
	for id_variant in DataManager.get_operation_order():
		_operation_ids.append(str(id_variant))
	if _operation_ids.is_empty():
		return

	# Default selection is the first unlocked operation.
	for op_id in _operation_ids:
		if not _is_operation_locked(op_id):
			_selected_operation_id = op_id
			break
	if _selected_operation_id == "":
		_selected_operation_id = _operation_ids[0]

	# Leading & trailing spacers so the first / last card can sit centered.
	_operation_row.add_child(_make_carousel_spacer())

	for op_id in _operation_ids:
		var op: OperationData = DataManager.get_operation(op_id) as OperationData
		if op == null:
			continue
		var card := _create_operation_card(op_id, op)
		_operation_row.add_child(card)
		_operation_cards[op_id] = card.get_meta("card_info")

	_operation_row.add_child(_make_carousel_spacer())
	_build_dot_indicators()
	_refresh_operation_selection()
	# Center the initial selection once the layout has computed sizes.
	call_deferred("_scroll_to_operation", _selected_operation_id, false)


# Spacer width = (visible_width - card_width) / 2, but the carousel size isn't
# known until layout. We approximate using the design viewport minus margins;
# the math doesn't need to be exact — being a touch generous still lets the
# end cards sit close to centered.
func _make_carousel_spacer() -> Control:
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Approximate (1080 - 2*60 - 672) / 2 = 144 logical.
	spacer.custom_minimum_size = Vector2(144, 0)
	return spacer


func _create_operation_card(op_id: String, op: OperationData) -> Control:
	# The card surface is a PanelContainer (gets the border + bg + radius);
	# its content is a VBox with icon-row, description, metadata.
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_MIN_HEIGHT)
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var border_style := _make_panel_style(UiTheme.PANEL, UiTheme.BORDER_PLAYER)
	card.add_theme_stylebox_override("panel", border_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CARD_PADDING_X)
	margin.add_theme_constant_override("margin_right", CARD_PADDING_X)
	margin.add_theme_constant_override("margin_top", CARD_PADDING_Y)
	margin.add_theme_constant_override("margin_bottom", CARD_PADDING_Y)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)

	# Header row: icon | name + difficulty chip.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(header)

	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(CARD_ICON_SIZE, CARD_ICON_SIZE)
	icon_frame.add_theme_stylebox_override("panel", _make_panel_style(Color("#0a1828"), Color("#0a1828"), 0))
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(icon_frame)
	var icon_glyph := _make_pixel_label("◆", CARD_NAME_FONT, UiTheme.MUTED)
	icon_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_glyph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_glyph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(icon_glyph)

	var name_col := VBoxContainer.new()
	name_col.add_theme_constant_override("separation", 8)
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(name_col)

	var name_label := _make_pixel_label(op.display_name, CARD_NAME_FONT, Color("#e0eaf8"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.max_lines_visible = 1
	name_col.add_child(name_label)

	var difficulty := _operation_difficulty(op_id)
	name_col.add_child(_make_difficulty_chip(difficulty))

	# Description.
	var desc_label := _make_pixel_label(op.blurb, CARD_DESC_FONT, UiTheme.MUTED)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(desc_label)

	# Metadata row: "N encounters  ·  Tier X enemies".
	var meta_text := "%d encounters · %s" % [op.battles.size(), _operation_tier_label(op_id)]
	var meta_label := _make_pixel_label(meta_text, CARD_META_FONT, UiTheme.MUTED)
	col.add_child(meta_label)

	# Click handling — locked cards ignore input.
	var locked := _is_operation_locked(op_id)
	if locked:
		card.modulate.a = CARD_LOCKED_ALPHA
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		card.gui_input.connect(_on_operation_card_gui_input.bind(op_id))

	card.set_meta("card_info", {
		"card": card,
		"locked": locked,
		"border_style": border_style,
	})
	return card


func _build_dot_indicators() -> void:
	for child in _dot_row.get_children():
		child.queue_free()
	_dot_nodes.clear()
	for op_id in _operation_ids:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.color = DOT_INACTIVE
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dot_row.add_child(dot)
		_dot_nodes.append(dot)


func _refresh_operation_selection() -> void:
	for op_id in _operation_cards.keys():
		var info: Dictionary = _operation_cards[op_id]
		var card: PanelContainer = info["card"]
		var locked: bool = info["locked"]
		if locked:
			continue
		var is_selected := str(op_id) == _selected_operation_id
		var bg: Color = UiTheme.RAISED if is_selected else UiTheme.PANEL
		var border: Color = UiTheme.CYAN if is_selected else UiTheme.BORDER_PLAYER
		card.add_theme_stylebox_override("panel", _make_panel_style(bg, border))
	for i in _dot_nodes.size():
		var op_id: String = _operation_ids[i]
		_dot_nodes[i].color = UiTheme.CYAN if op_id == _selected_operation_id else DOT_INACTIVE


func _on_operation_card_gui_input(event: InputEvent, op_id: String) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_select_operation(op_id)
			accept_event()
	elif event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event
		if te.pressed:
			_select_operation(op_id)
			accept_event()


func _select_operation(op_id: String) -> void:
	if _is_operation_locked(op_id):
		return
	_selected_operation_id = op_id
	_refresh_operation_selection()
	_refresh_begin_button()
	_scroll_to_operation(op_id, true)


# ─── Carousel scroll-snap ─────────────────────────────────────────────────────
func _on_carousel_scrolled(_value: float) -> void:
	# Live-update the dot indicator while the user is mid-drag, then snap when
	# the scroll settles.
	var nearest_id := _nearest_operation_id_to_center()
	if nearest_id != "" and nearest_id != _selected_operation_id and not _is_operation_locked(nearest_id):
		_selected_operation_id = nearest_id
		_refresh_operation_selection()
		_refresh_begin_button()
	_snap_timer.start()


func _snap_carousel_to_center() -> void:
	if _selected_operation_id == "":
		return
	_scroll_to_operation(_selected_operation_id, true)


# Returns the operation id whose card center is closest to the carousel's
# horizontal visible center. Spacers are skipped because they have no metadata.
func _nearest_operation_id_to_center() -> String:
	if _operation_carousel == null:
		return ""
	var center_x: float = _operation_carousel.scroll_horizontal + _operation_carousel.size.x * 0.5
	var best_id := ""
	var best_dist := INF
	for op_id in _operation_cards.keys():
		var info: Dictionary = _operation_cards[op_id]
		var card: Control = info["card"]
		var card_center: float = card.position.x + card.size.x * 0.5
		var dist: float = abs(card_center - center_x)
		if dist < best_dist:
			best_dist = dist
			best_id = str(op_id)
	return best_id


func _scroll_to_operation(op_id: String, animate: bool) -> void:
	if _operation_carousel == null:
		return
	if not _operation_cards.has(op_id):
		return
	var info: Dictionary = _operation_cards[op_id]
	var card: Control = info["card"]
	# Allow one frame for the HBox to compute card positions on first call.
	if card.size.x <= 0.0:
		await get_tree().process_frame
	var target := int(round(card.position.x + card.size.x * 0.5 - _operation_carousel.size.x * 0.5))
	target = max(0, target)
	if animate:
		var tween := create_tween()
		tween.tween_property(_operation_carousel, "scroll_horizontal", target, CAROUSEL_SNAP_TWEEN_S)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_operation_carousel.scroll_horizontal = target


# ─── Operations: difficulty / lock / tier helpers ─────────────────────────────
# Derived from order index because the data layer doesn't carry difficulty.
func _operation_difficulty(op_id: String) -> Dictionary:
	var index: int = _operation_ids.find(op_id)
	if index <= 0:
		return DIFF_STANDARD
	elif index <= 2:
		return DIFF_ADVANCED
	return DIFF_ELITE


func _operation_tier_label(op_id: String) -> String:
	var diff: Dictionary = _operation_difficulty(op_id)
	match str(diff.get("label", "")):
		"ADVANCED":
			return "Tier 2 enemies"
		"ELITE":
			return "Tier 3 enemies"
	return "Tier 1 enemies"


# Currently nothing locks operations — placeholder so a future progression
# system can plug in here without touching the carousel layout code.
func _is_operation_locked(_op_id: String) -> bool:
	# TODO: read GameState.unlocked_operation_ids (when added) and gate here.
	return false


# ─── Units: data + thumbs ─────────────────────────────────────────────────────
func _populate_units() -> void:
	# DataManager.units is keyed by hero id ("avalanche", "breaker", …); we sort
	# alphabetically so the row order is deterministic regardless of JSON order.
	# Each thumb is bound to its OWN unit_id/unit_data pair (no positional /
	# index-based lookup), so portrait textures travel with the unit they
	# belong to even if the row order ever changes.
	var unit_ids: Array = DataManager.units.keys()
	unit_ids.sort()
	for unit_id_variant in unit_ids:
		var unit_id := str(unit_id_variant)
		var unit: UnitData = DataManager.get_unit(unit_id) as UnitData
		if unit == null:
			continue
		var thumb := _create_unit_thumb(unit_id, unit)
		_unit_thumb_row.add_child(thumb)


func _create_unit_thumb(unit_id: String, unit: UnitData) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", UNIT_FRAME_TO_NAME_GAP)
	col.custom_minimum_size = Vector2(UNIT_THUMB_WIDTH, 0)
	col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	col.mouse_filter = Control.MOUSE_FILTER_STOP
	col.gui_input.connect(_on_unit_thumb_gui_input.bind(unit_id))

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(UNIT_THUMB_WIDTH, UNIT_THUMB_FRAME_H)
	frame.add_theme_stylebox_override("panel", _make_panel_style(UiTheme.PANEL, UiTheme.BORDER_PLAYER))
	frame.clip_contents = true
	# PanelContainer defaults to MOUSE_FILTER_STOP, which silently consumes
	# clicks on the portrait area and blocks the parent VBox from ever seeing
	# them — symptom: tapping the unit portrait did nothing. IGNORE makes the
	# frame transparent to hit-testing so the click resolves directly to `col`
	# (the VBox that owns the gui_input handler). PASS is theoretically
	# equivalent here, but Godot 4's PASS semantics differ subtly between
	# containers vs. plain Controls — IGNORE is the unambiguous fix.
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(frame)

	var portrait_wrap := Control.new()
	portrait_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(portrait_wrap)

	if unit.portrait != null:
		var portrait := TextureRect.new()
		portrait.texture = unit.portrait
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_wrap.add_child(portrait)
	else:
		var placeholder := _make_pixel_label("◆", CARD_NAME_FONT, UiTheme.MUTED)
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait_wrap.add_child(placeholder)

	# Selection check indicator, hidden by default. Nested inside the
	# absolutely-positioned `portrait_wrap` Control (not the PanelContainer
	# directly) so it can be a fixed-size badge in the top-right corner instead
	# of being stretched to fill by container layout.
	var check := ColorRect.new()
	check.color = UiTheme.CYAN
	check.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	check.offset_left = -CHECK_SIZE - CHECK_INSET
	check.offset_top = CHECK_INSET
	check.offset_right = -CHECK_INSET
	check.offset_bottom = CHECK_INSET + CHECK_SIZE
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	check.visible = false
	portrait_wrap.add_child(check)

	var name_label := _make_pixel_label(unit.display_name.to_upper(), UNIT_NAME_FONT, UiTheme.MUTED)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_label)

	var role_text := unit.role if unit.role != "" else unit.class_name_text
	var role_label := _make_pixel_label(role_text, UNIT_ROLE_FONT, Color("#2a4a5a"))
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(role_label)

	_unit_thumbs[unit_id] = {
		"card": col,
		"frame": frame,
		"name": name_label,
		"role": role_label,
		"check": check,
	}
	return col


func _on_unit_thumb_gui_input(event: InputEvent, unit_id: String) -> void:
	# Bug 1 verification log — confirms the mouse_filter chain is letting
	# events through to this handler. Safe to remove once verified.
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		var dbg := FileAccess.open("user://home_click_debug.log", FileAccess.READ_WRITE)
		if dbg == null:
			dbg = FileAccess.open("user://home_click_debug.log", FileAccess.WRITE)
		if dbg != null:
			dbg.seek_end()
			dbg.store_line("event=%s unit=%s" % [event.as_text(), unit_id])
			dbg.close()
	var clicked := false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		clicked = mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	elif event is InputEventScreenTouch:
		var te: InputEventScreenTouch = event
		clicked = te.pressed
	if not clicked:
		return
	accept_event()
	_focused_unit_id = unit_id
	_toggle_unit_selection(unit_id)
	_show_unit_detail(unit_id)
	_refresh_unit_thumbs()
	_refresh_squad_counter()
	_refresh_begin_button()


# Treat a plain mouse-wheel as horizontal scroll for the thumb row, since the
# row has its vertical scroll disabled and the user otherwise has to know the
# Shift+Wheel shortcut to reach the off-viewport thumbs.
func _redirect_wheel_to_horizontal(event: InputEvent, sc: ScrollContainer) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if not mb.pressed:
		return
	var step: int = int(round(UNIT_THUMB_WIDTH * 0.5))
	var delta: int = 0
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
			delta = step
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
			delta = -step
	if delta != 0:
		sc.scroll_horizontal += delta
		sc.accept_event()


func _toggle_unit_selection(unit_id: String) -> void:
	if _selected_unit_ids.has(unit_id):
		_selected_unit_ids.erase(unit_id)
		return
	if _selected_unit_ids.size() >= MAX_SELECTED_UNITS:
		# Strict rejection: a 4th tap is a no-op (per spec "Maximum 3").
		# The detail panel still updates to show what the user tapped, so the
		# action is "view-without-select" rather than silent failure.
		return
	_selected_unit_ids.append(unit_id)


func _refresh_unit_thumbs() -> void:
	for unit_id_variant in _unit_thumbs.keys():
		var unit_id := str(unit_id_variant)
		var thumb: Dictionary = _unit_thumbs[unit_id]
		var frame: PanelContainer = thumb["frame"]
		var name_label: Label = thumb["name"]
		var check: ColorRect = thumb["check"]
		var is_selected := _selected_unit_ids.has(unit_id)
		var bg: Color = UiTheme.RAISED if is_selected else UiTheme.PANEL
		var border: Color = UiTheme.CYAN if is_selected else UiTheme.BORDER_PLAYER
		frame.add_theme_stylebox_override("panel", _make_panel_style(bg, border))
		name_label.add_theme_color_override("font_color", UiTheme.CYAN if is_selected else UiTheme.MUTED)
		check.visible = is_selected


func _refresh_squad_counter() -> void:
	var counter: Label = get_node_or_null("MarginContainer/VBoxContainer/SquadCounter")
	# The counter label was added inside the squad VBox; resolve by name search
	# because the path includes anonymous containers built in code.
	if counter == null:
		counter = find_child("SquadCounter", true, false) as Label
	if counter != null:
		counter.text = "%d / %d" % [_selected_unit_ids.size(), MAX_SELECTED_UNITS]


func _show_unit_detail(unit_id: String) -> void:
	# Per spec: panel is only visible while at least one unit is selected.
	# The body always shows the most recently tapped unit's info (even if the
	# tap deselected them) — the visibility gate is the squad-size check.
	if _selected_unit_ids.is_empty():
		_detail_panel.visible = false
		return
	var unit: UnitData = DataManager.get_unit(unit_id) as UnitData
	if unit == null:
		_detail_panel.visible = false
		return
	_detail_panel.visible = true
	_detail_portrait.texture = unit.portrait
	_detail_name.text = unit.display_name.to_upper()
	var role_text := unit.role if unit.role != "" else unit.class_name_text
	_detail_role.text = role_text
	_detail_hp.text = "HP [color=#e0eaf8]%d[/color]" % unit.max_hp


# ─── BEGIN RUN ────────────────────────────────────────────────────────────────
func _refresh_begin_button() -> void:
	var ready := _selected_unit_ids.size() == MAX_SELECTED_UNITS and _selected_operation_id != ""
	var bg := BEGIN_READY_BG if ready else BEGIN_NOT_READY_BG
	var border := BEGIN_READY_BORDER if ready else BEGIN_NOT_READY_BORDER
	var text_color := BEGIN_READY_TEXT if ready else BEGIN_NOT_READY_TEXT
	_begin_panel.add_theme_stylebox_override("panel", _make_panel_style(bg, border))
	_begin_button.add_theme_color_override("font_color", text_color)
	_begin_button.add_theme_color_override("font_hover_color", text_color)
	_begin_button.add_theme_color_override("font_pressed_color", text_color)
	_begin_button.add_theme_color_override("font_focus_color", text_color)
	_begin_button.disabled = not ready
	_begin_button.mouse_filter = Control.MOUSE_FILTER_STOP if ready else Control.MOUSE_FILTER_IGNORE


func _on_begin_run_pressed() -> void:
	if _selected_unit_ids.size() != MAX_SELECTED_UNITS:
		return
	if _selected_operation_id == "":
		return
	GameState.start_run(_selected_unit_ids, _selected_operation_id)
	GameState.advance_to_next_battle()
	SceneManager.go_to_battle()


# ─── Helpers: labels, styles, chips ───────────────────────────────────────────
func _make_pixel_label(text: String, size_logical: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", PixelUI.get_pixel_font())
	label.add_theme_font_size_override("font_size", size_logical)
	label.add_theme_color_override("font_color", color)
	# Outlines are off — they fuzz the m5x7 grid at clean pixel sizes.
	label.add_theme_constant_override("outline_size", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_header_label(text: String, color: Color) -> Label:
	var label := _make_pixel_label(text, HEADER_FONT_SIZE, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _apply_button_font(button: Button, size_logical: int, color: Color) -> void:
	button.add_theme_font_override("font", PixelUI.get_pixel_font())
	button.add_theme_font_size_override("font_size", size_logical)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_focus_color", color)
	button.add_theme_color_override("font_disabled_color", color)
	button.add_theme_constant_override("outline_size", 0)


func _make_panel_style(bg: Color, border: Color, border_width: int = CARD_BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = CARD_RADIUS
	style.corner_radius_top_right = CARD_RADIUS
	style.corner_radius_bottom_left = CARD_RADIUS
	style.corner_radius_bottom_right = CARD_RADIUS
	style.shadow_size = 0
	# Inset content margins so the border doesn't visually clip child content.
	style.set_content_margin(SIDE_LEFT, 0)
	style.set_content_margin(SIDE_RIGHT, 0)
	style.set_content_margin(SIDE_TOP, 0)
	style.set_content_margin(SIDE_BOTTOM, 0)
	return style


func _make_difficulty_chip(difficulty: Dictionary) -> Control:
	# Sized to text + inner padding so chips track the label width.
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip.add_theme_stylebox_override("panel", _make_chip_style(difficulty["bg"], difficulty["border"]))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(margin)
	var label := _make_pixel_label(str(difficulty["label"]), CARD_TAG_FONT, difficulty["text"])
	margin.add_child(label)
	return chip


func _make_chip_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(CARD_BORDER)
	style.corner_radius_top_left = CARD_RADIUS
	style.corner_radius_top_right = CARD_RADIUS
	style.corner_radius_bottom_left = CARD_RADIUS
	style.corner_radius_bottom_right = CARD_RADIUS
	style.shadow_size = 0
	return style
