# Deploy / picker screen: encounter carousel + 4x2 squad grid + DEPLOY.
#
# Direction-05 "Dithered Terminal" styling, authored against the 1080x2400 logical
# viewport (project base); on-screen px values are ~×2.4 in logical units. Fonts use
# m5x7 at clean multiples via _make_pixel_label (bypasses PixelUI.scale_font_size so
# small labels stay pixel-crisp). Colors pull from PixelUI DT_* tokens.
#
# - Encounter carousel: one encounter at a time (name + threat pips/level + blurb +
#   final-boss portrait), cycled by ◀ ▶ arrows; dots show position. Threat level is
#   derived from encounter order (no data field). Boss portrait = the last battle's
#   last enemy's portrait.
# - Squad: 4x2 wall of portrait tiles with a role-color corner badge; selecting a unit
#   adds a slot-number badge (1/2/3) + cyan highlight. A detail bar shows the
#   last-tapped unit's name / focus / blurb.
# - DEPLOY uses the battle Roll button's green commit style; inert ("SELECT N MORE")
#   until 3 are picked. The global PersistentHeader stays as-is (blank label here).
extends Control

const MAX_SELECTED_UNITS := 3

# Layout (logical units).
const ROOT_MARGIN_X := 60
const ROOT_MARGIN_TOP := 60
const ROOT_MARGIN_BOTTOM := 48
const SECTION_GAP := 30
const HEADER_GAP := 16

# Fonts (logical units) — matched to the battle screen's scale (card names 72,
# protocol/summary labels 70-112) so the picker reads at the same weight.
const HEADER_FONT := 72
const COUNTER_FONT := 64
const ENC_NAME_FONT := 96
const ENC_META_FONT := 48
const ENC_DESC_FONT := 52
const TILE_NAME_FONT := 56
const DETAIL_NAME_FONT := 76
const DETAIL_DESC_FONT := 52
const FOCUS_CHIP_FONT := 40
const DEPLOY_FONT := 84
const TILE_NAME_STRIP_H := 76      # one line (callsigns are single words) + a little padding

# 4px (not 2) so borders survive the canvas_items downscale to the preview window —
# at 2px they render sub-pixel and drop edges, worst on bright accent borders.
const PANEL_BORDER := 4
const PANEL_RADIUS := 0

const ENC_PANEL_HEIGHT := 320
const ENC_NAME_H := 196            # reserve 2 rows for the title — short names don't shrink the panel
const ENC_DESC_H := 168            # reserve a fixed block for the blurb so the panel never resizes
const ENC_PORTRAIT := 232          # boss portrait, square — about a hero tile's size
const NAV_BUTTON_W := 96
const NAV_BUTTON_H := 220           # ~half the panel height (was full-height)
const THREAT_PIP_COUNT := 5
const THREAT_PIP_SIZE := Vector2(42, 30)

const TILE_PORTRAIT_H := 248
const TILE_GAP := 18
const GRID_COLUMNS := 4             # 4 per row; each COLUMN is a same-type pair (stacked)
const ROLE_BADGE_SIZE := 34
const SLOT_BADGE_SIZE := 60
const CHECK_INSET := 8

const DETAIL_BAR_HEIGHT := 340      # fixed so swapping units never reflows the page

const DOT_SIZE := 18
const DOT_GAP := 18

const DIVIDER_THICK := 2

# Threat pips / level color
const THREAT_FILL := Color("c25d3f")           # DT rust
const THREAT_EMPTY := Color(0.10, 0.11, 0.07, 1.0)

# Deploy button states
const DEPLOY_IDLE_BG := Color(0.040, 0.050, 0.060, 1.0)
const DEPLOY_IDLE_BORDER := Color(0.13, 0.15, 0.17, 1.0)
const DEPLOY_IDLE_TEXT := Color(0.34, 0.38, 0.42, 1.0)


# ─── State ────────────────────────────────────────────────────────────────────
var _operation_ids: Array[String] = []
var _operation_index: int = 0
var _selected_operation_id: String = ""
var _unit_ids: Array[String] = []
var _selected_unit_ids: Array[String] = []
var _focused_unit_id: String = ""

# Built nodes
var _enc_portrait: TextureRect
var _enc_portrait_crop: Control
var _enc_portrait_placeholder: Label
var _enc_name_label: Label
var _enc_desc_label: Label
var _enc_level_label: Label
var _threat_pips: Array[ColorRect] = []
var _dot_row: HBoxContainer
var _dot_nodes: Array[ColorRect] = []
var _unit_tiles: Dictionary = {}    # unit_id -> { frame, role_badge, slot_panel, slot_label, name }
var _counter_label: Label
var _detail_panel: PanelContainer
var _detail_name: Label
var _detail_focus: Label
var _detail_focus_chip: PanelContainer
var _detail_desc: Label
var _deploy_panel: PanelContainer
var _deploy_button: Button


# ─── Lifecycle ────────────────────────────────────────────────────────────────
func _ready() -> void:
	# No run is active on the deploy screen — blank the persistent header's run
	# label and leave its buttons inert (this screen binds none of them).
	PersistentHeader.set_run_active(false)
	PersistentHeader.clear_battle_actions()
	_apply_background()
	_gather_data()
	_build_layout()
	_refresh_encounter()
	_refresh_unit_tiles()
	_refresh_squad_counter()
	_refresh_detail()
	_refresh_deploy()


func _apply_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.055, 0.070, 0.095, 1.0)   # flat DT field, matches the battle screen
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)


func _gather_data() -> void:
	_operation_ids.clear()
	for id_variant in DataManager.get_operation_order():
		_operation_ids.append(str(id_variant))
	if not _operation_ids.is_empty():
		_operation_index = 0
		_selected_operation_id = _operation_ids[0]

	# Order units so each grid COLUMN is a same-type pair, stacked top/bottom: with a
	# 4-wide grid, row 1 holds the first unit of each type and row 2 the second.
	_unit_ids.clear()
	var groups: Dictionary = {}   # type rank -> [unit_id], name-sorted
	for k in DataManager.units.keys():
		var unit := DataManager.get_unit(str(k)) as UnitData
		var rank: int = _type_rank(unit)
		if not groups.has(rank):
			groups[rank] = []
		groups[rank].append(str(k))
	var ranks: Array = groups.keys()
	ranks.sort()
	for rank in ranks:
		(groups[rank] as Array).sort_custom(func(a: String, b: String) -> bool:
			return str((DataManager.get_unit(a) as UnitData).display_name) < str((DataManager.get_unit(b) as UnitData).display_name)
		)
	# First pass: one per type (top row). Second pass: the rest (bottom row[s]).
	var max_in_group: int = 0
	for rank in ranks:
		max_in_group = maxi(max_in_group, (groups[rank] as Array).size())
	for slot in range(max_in_group):
		for rank in ranks:
			var g: Array = groups[rank]
			if slot < g.size():
				_unit_ids.append(str(g[slot]))


# ─── Layout ───────────────────────────────────────────────────────────────────
func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", ROOT_MARGIN_X)
	margin.add_theme_constant_override("margin_right", ROOT_MARGIN_X)
	# Reserve room for the always-on PersistentHeader band (overlays the top 144px).
	margin.add_theme_constant_override("margin_top", ROOT_MARGIN_TOP + int(PersistentHeader.HEADER_HEIGHT))
	margin.add_theme_constant_override("margin_bottom", ROOT_MARGIN_BOTTOM)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", SECTION_GAP)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(column)

	column.add_child(_build_encounter_section())
	column.add_child(_build_divider())
	column.add_child(_build_squad_section())
	# Spacer pushes DEPLOY to the bottom.
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	column.add_child(_build_deploy_button())


# ─── Encounter carousel ─────────────────────────────────────────────────────---
func _build_encounter_section() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", HEADER_GAP)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	section.add_child(_make_header_label("SELECT ENCOUNTER", PixelUI.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT))

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, ENC_PANEL_HEIGHT)
	panel.add_theme_stylebox_override("panel", _make_panel_style(PixelUI.DT_HERO_BG, PixelUI.DT_HERO_BORDER))
	section.add_child(panel)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 20)
	pad.add_theme_constant_override("margin_top", 20)
	pad.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	pad.add_child(row)

	row.add_child(_make_nav_button("◀", -1))   # ◀

	# Boss portrait — fixed square, ~a hero tile's size, vertically centered.
	var portrait_box: Dictionary = _make_portrait_box(PixelUI.DT_ENEMY_BG, PixelUI.DT_ENEMY_BORDER)
	var portrait_frame: PanelContainer = portrait_box["frame"]
	portrait_frame.custom_minimum_size = Vector2(ENC_PORTRAIT, ENC_PORTRAIT)
	portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_enc_portrait = portrait_box["tex"]
	_enc_portrait_crop = portrait_box["crop"]
	# Placeholder glyph shown when an encounter has no boss art yet.
	_enc_portrait_placeholder = _make_pixel_label("?", 128, PixelUI.DT_ENEMY_BORDER)
	_enc_portrait_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enc_portrait_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_enc_portrait_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	(portrait_box["crop"] as Control).add_child(_enc_portrait_placeholder)
	# NOTE: portrait is added to the row AFTER the info column (boss image on the right).

	# Info column: name / threat / description.
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 16)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(info)

	# Fixed 2-row title block so a long name never grows the panel; short names just
	# leave the second row empty (top-aligned).
	_enc_name_label = _make_pixel_label("", ENC_NAME_FONT, PixelUI.TEXT_PRIMARY)
	_enc_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_enc_name_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_enc_name_label.clip_text = true
	_enc_name_label.custom_minimum_size = Vector2(0, ENC_NAME_H)
	info.add_child(_enc_name_label)

	info.add_child(_build_threat_row())

	# Fixed blurb block (clipped) so a long description doesn't resize the panel either.
	_enc_desc_label = _make_pixel_label("", ENC_DESC_FONT, PixelUI.TEXT_MUTED)
	_enc_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_enc_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_enc_desc_label.clip_text = true
	_enc_desc_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_enc_desc_label.custom_minimum_size = Vector2(0, ENC_DESC_H)
	info.add_child(_enc_desc_label)

	# Boss image sits to the RIGHT of the data.
	row.add_child(portrait_frame)
	row.add_child(_make_nav_button("▶", 1))    # ▶

	# Dots.
	_dot_row = HBoxContainer.new()
	_dot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dot_row.add_theme_constant_override("separation", DOT_GAP)
	_dot_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(_dot_row)
	for i in _operation_ids.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dot_row.add_child(dot)
		_dot_nodes.append(dot)

	return section


func _build_threat_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	row.add_child(_make_pixel_label("THREAT", ENC_META_FONT, PixelUI.TEXT_MUTED))

	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 6)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pips)
	_threat_pips.clear()
	for i in THREAT_PIP_COUNT:
		var pip := ColorRect.new()
		pip.custom_minimum_size = THREAT_PIP_SIZE
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
		_threat_pips.append(pip)

	_enc_level_label = _make_pixel_label("", ENC_META_FONT, PixelUI.DT_AMBER)
	row.add_child(_enc_level_label)
	return row


func _make_nav_button(glyph: String, direction: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(NAV_BUTTON_W, NAV_BUTTON_H)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.text = glyph
	_apply_button_font(button, 44, PixelUI.DT_RUST)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, PixelUI.make_hard_style(PixelUI.DT_ENEMY_BG, PixelUI.DT_ENEMY_BORDER, PANEL_BORDER))
	button.add_theme_stylebox_override("hover", PixelUI.make_hard_style(PixelUI.DT_ENEMY_BG, PixelUI.DT_RUST, PANEL_BORDER))
	button.pressed.connect(_on_nav_pressed.bind(direction))
	return button


func _on_nav_pressed(direction: int) -> void:
	if _operation_ids.is_empty():
		return
	AudioManager.play_select()
	_operation_index = wrapi(_operation_index + direction, 0, _operation_ids.size())
	_selected_operation_id = _operation_ids[_operation_index]
	_refresh_encounter()
	_refresh_deploy()


func _refresh_encounter() -> void:
	if _operation_ids.is_empty():
		return
	var op: OperationData = DataManager.get_operation(_selected_operation_id) as OperationData
	if op == null:
		return
	_enc_name_label.text = op.display_name.to_upper()
	_enc_desc_label.text = op.blurb
	var boss_tex: Texture2D = _get_boss_portrait(op)
	_enc_portrait.texture = boss_tex
	_cover_fit_portrait(_enc_portrait_crop, _enc_portrait)
	_enc_portrait_placeholder.visible = boss_tex == null

	var level: int = _threat_level(_operation_index)
	_enc_level_label.text = "LV %d" % level
	for i in _threat_pips.size():
		_threat_pips[i].color = THREAT_FILL if i < level else THREAT_EMPTY

	for i in _dot_nodes.size():
		_dot_nodes[i].color = PixelUI.DT_CYAN if i == _operation_index else PixelUI.DT_PROTO_EMPTY_BORDER


# Threat level (1..THREAT_PIP_COUNT) derived from encounter order.
func _threat_level(index: int) -> int:
	return clampi(index + 1, 1, THREAT_PIP_COUNT)


# Boss = the highest-HP enemy in the operation (bosses are 140-180 HP vs ~35-74 for
# minions). Picks that enemy's portrait; if the boss itself has no art, falls back to
# the next-highest enemy that does, so the box is never blank when any art exists.
func _get_boss_portrait(op: OperationData) -> Texture2D:
	if op == null:
		return null
	var boss_tex: Texture2D = null
	var best_hp: int = -1
	for battle_variant in op.battles:
		var battle: Dictionary = battle_variant
		for name_variant in battle.get("enemy_names", []):
			var enemy: EnemyData = DataManager.get_enemy_by_display_name(str(name_variant)) as EnemyData
			if enemy == null or enemy.portrait == null:
				continue
			if enemy.max_hp > best_hp:
				best_hp = enemy.max_hp
				boss_tex = enemy.portrait
	return boss_tex


# ─── Divider ──────────────────────────────────────────────────────────────────
func _build_divider() -> Control:
	var divider := ColorRect.new()
	divider.color = PixelUI.DT_LINE
	divider.custom_minimum_size = Vector2(0, DIVIDER_THICK)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider


# ─── Squad grid ───────────────────────────────────────────────────────────────
func _build_squad_section() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", HEADER_GAP)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := _make_pixel_label("SELECT SQUAD", HEADER_FONT, PixelUI.DT_CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_counter_label = _make_pixel_label("0 / %d" % MAX_SELECTED_UNITS, COUNTER_FONT, PixelUI.DT_CYAN)
	header.add_child(_counter_label)
	section.add_child(header)

	_detail_panel = _build_detail_bar()
	section.add_child(_detail_panel)

	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", TILE_GAP)
	grid.add_theme_constant_override("v_separation", TILE_GAP)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(grid)
	for unit_id in _unit_ids:
		var unit: UnitData = DataManager.get_unit(unit_id) as UnitData
		if unit == null:
			continue
		grid.add_child(_build_unit_tile(unit_id, unit))

	return section


func _build_detail_bar() -> PanelContainer:
	var panel := PanelContainer.new()
	# Fixed height + clip so swapping units never reflows the grid below it.
	panel.custom_minimum_size = Vector2(0, DETAIL_BAR_HEIGHT)
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.clip_contents = true
	panel.add_theme_stylebox_override("panel", _make_panel_style(PixelUI.DT_TRAY_BG, PixelUI.DT_HERO_BORDER))

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 24)
	pad.add_theme_constant_override("margin_right", 24)
	pad.add_theme_constant_override("margin_top", 18)
	pad.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(pad)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	pad.add_child(col)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 16)
	col.add_child(name_row)

	_detail_name = _make_pixel_label("SELECT A UNIT", DETAIL_NAME_FONT, PixelUI.TEXT_PRIMARY)
	# Name takes the row; the focus tag is pushed to the top-right of the box.
	_detail_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(_detail_name)

	_detail_focus_chip = PanelContainer.new()
	_detail_focus_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_detail_focus_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_detail_focus_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_pad := MarginContainer.new()
	chip_pad.add_theme_constant_override("margin_left", 12)
	chip_pad.add_theme_constant_override("margin_right", 12)
	chip_pad.add_theme_constant_override("margin_top", 3)
	chip_pad.add_theme_constant_override("margin_bottom", 3)
	chip_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_focus_chip.add_child(chip_pad)
	_detail_focus = _make_pixel_label("", FOCUS_CHIP_FONT, PixelUI.TEXT_PRIMARY)
	chip_pad.add_child(_detail_focus)
	_detail_focus_chip.visible = false   # shown once a unit is tapped
	name_row.add_child(_detail_focus_chip)

	_detail_desc = _make_pixel_label("Tap a specialist to inspect their focus and kit.", DETAIL_DESC_FONT, PixelUI.TEXT_MUTED)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_detail_desc)

	return panel


func _build_unit_tile(unit_id: String, unit: UnitData) -> Control:
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 10)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.gui_input.connect(_on_tile_input.bind(unit_id))

	# Name strip on top of the tile (battle-card style), above the portrait.
	var tile_name: String = unit.callsign if unit.callsign != "" else unit.display_name
	var name_strip := PanelContainer.new()
	name_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_strip.custom_minimum_size = Vector2(0, TILE_NAME_STRIP_H)
	name_strip.add_theme_stylebox_override("panel", _make_panel_style(PixelUI.DT_HERO_HEADER, PixelUI.DT_HERO_BORDER))
	var name_pad := MarginContainer.new()
	name_pad.add_theme_constant_override("margin_left", 6)
	name_pad.add_theme_constant_override("margin_right", 6)
	name_pad.add_theme_constant_override("margin_top", 4)
	name_pad.add_theme_constant_override("margin_bottom", 4)
	name_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_strip.add_child(name_pad)
	var name_label := _make_pixel_label(tile_name.to_upper(), TILE_NAME_FONT, PixelUI.DT_HERO_NAME)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_pad.add_child(name_label)
	cell.add_child(name_strip)

	var portrait_box: Dictionary = _make_portrait_box(PixelUI.DT_HERO_BG, PixelUI.DT_HERO_BORDER)
	var frame: PanelContainer = portrait_box["frame"]
	var crop: Control = portrait_box["crop"]
	frame.custom_minimum_size = Vector2(0, TILE_PORTRAIT_H)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_child(frame)
	(portrait_box["tex"] as TextureRect).texture = unit.portrait
	call_deferred("_cover_fit_portrait", portrait_box["crop"], portrait_box["tex"])

	# Role-color corner badge (top-right), always shown.
	var role_badge := ColorRect.new()
	role_badge.color = _role_color(unit)
	role_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	role_badge.offset_left = -ROLE_BADGE_SIZE - CHECK_INSET
	role_badge.offset_top = CHECK_INSET
	role_badge.offset_right = -CHECK_INSET
	role_badge.offset_bottom = CHECK_INSET + ROLE_BADGE_SIZE
	role_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crop.add_child(role_badge)

	# No slot-number badge — the cyan highlight border is enough to show selection.

	_unit_tiles[unit_id] = {
		"frame": frame,
		"role_badge": role_badge,
		"name": name_label,
	}
	return cell


func _on_tile_input(event: InputEvent, unit_id: String) -> void:
	var clicked := false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		clicked = mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	elif event is InputEventScreenTouch:
		clicked = (event as InputEventScreenTouch).pressed
	if not clicked:
		return
	accept_event()
	_focused_unit_id = unit_id
	_toggle_unit_selection(unit_id)
	_refresh_unit_tiles()
	_refresh_squad_counter()
	_refresh_detail()
	_refresh_deploy()


func _toggle_unit_selection(unit_id: String) -> void:
	if _selected_unit_ids.has(unit_id):
		AudioManager.play_select()
		_selected_unit_ids.erase(unit_id)
		return
	if _selected_unit_ids.size() >= MAX_SELECTED_UNITS:
		# 4th pick is a no-op; the detail bar still updates to show the tapped unit.
		return
	AudioManager.play_select()
	_selected_unit_ids.append(unit_id)


func _refresh_unit_tiles() -> void:
	for unit_id_variant in _unit_tiles.keys():
		var unit_id := str(unit_id_variant)
		var tile: Dictionary = _unit_tiles[unit_id]
		var frame: PanelContainer = tile["frame"]
		var name_label: Label = tile["name"]
		var is_selected := _selected_unit_ids.has(unit_id)
		var border: Color = PixelUI.DT_CYAN if is_selected else PixelUI.DT_HERO_BORDER
		# Keep the border-width content margin so the portrait stays INSIDE the frame
		# (matches _make_portrait_box; otherwise the portrait would cover the border).
		var frame_style: StyleBoxFlat = _make_panel_style(PixelUI.DT_HERO_BG, border)
		frame_style.set_content_margin_all(float(PANEL_BORDER))
		frame.add_theme_stylebox_override("panel", frame_style)
		name_label.add_theme_color_override("font_color", PixelUI.DT_CYAN_BRIGHT if is_selected else PixelUI.DT_HERO_NAME)


func _refresh_squad_counter() -> void:
	if _counter_label != null:
		_counter_label.text = "%d / %d" % [_selected_unit_ids.size(), MAX_SELECTED_UNITS]


# Compatibility aliases for the established screen contract (flow smoke test etc.).
func _refresh_unit_thumbs() -> void:
	_refresh_unit_tiles()


func _refresh_begin_button() -> void:
	_refresh_deploy()


func _refresh_detail() -> void:
	if _focused_unit_id == "":
		return
	var unit: UnitData = DataManager.get_unit(_focused_unit_id) as UnitData
	if unit == null:
		return
	_detail_name.text = unit.display_name.to_upper()
	_detail_focus_chip.visible = true
	var focus_text: String = unit.picker_category if unit.picker_category != "" else (unit.role if unit.role != "" else unit.class_name_text)
	_detail_focus.text = focus_text.to_upper()
	var accent: Color = _role_color(unit)
	_detail_focus.add_theme_color_override("font_color", accent)
	_detail_focus_chip.add_theme_stylebox_override("panel", PixelUI.make_hard_style(accent.darkened(0.74), accent, 2))
	var blurb: String = unit.picker_blurb if unit.picker_blurb != "" else "No dossier available."
	_detail_desc.text = blurb


# Type ordering for the squad grid; matches the badge color buckets so each row
# pairs same-type units.
func _type_rank(unit: UnitData) -> int:
	if unit == null:
		return 99
	var c: Color = _role_color(unit)
	if c == PixelUI.DT_RUST:
		return 0
	if c == PixelUI.DT_CYAN:
		return 1
	if c == Color("9a6ad0"):
		return 2
	if c == PixelUI.DT_AMBER:
		return 3
	return 4


# Maps a unit's focus to a DT accent color for its badge + detail chip. Driven by
# the clean pickerCategory values (damage / defense / support / control).
func _role_color(unit: UnitData) -> Color:
	match unit.picker_category.to_lower():
		"damage", "offense", "offence":
			return PixelUI.DT_RUST
		"defense", "defence":
			return PixelUI.DT_CYAN
		"support":
			return Color("9a6ad0")     # violet
		"control":
			return PixelUI.DT_AMBER
	return PixelUI.TEXT_MUTED


# ─── DEPLOY ───────────────────────────────────────────────────────────────────
func _build_deploy_button() -> Control:
	_deploy_panel = PanelContainer.new()
	_deploy_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_deploy_button = Button.new()
	_deploy_button.focus_mode = Control.FOCUS_NONE
	_deploy_button.custom_minimum_size = Vector2(0, 130)
	_deploy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deploy_button.text = "SELECT %d MORE" % MAX_SELECTED_UNITS
	_deploy_button.pressed.connect(_on_begin_run_pressed)
	_deploy_panel.add_child(_deploy_button)
	return _deploy_panel


func _refresh_deploy() -> void:
	var ready := _selected_unit_ids.size() == MAX_SELECTED_UNITS and _selected_operation_id != ""
	if ready:
		# Same green commit look as the battle Roll button.
		PixelUI.style_button(_deploy_button, PixelUI.DT_ROLL_BG, PixelUI.DT_ROLL_LIGHT, DEPLOY_FONT)
		_set_button_text_color(_deploy_button, PixelUI.DT_ROLL_TEXT)
		_deploy_button.text = "DEPLOY"
		_deploy_button.disabled = false
		_deploy_button.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		PixelUI.style_button(_deploy_button, DEPLOY_IDLE_BG, DEPLOY_IDLE_BORDER, DEPLOY_FONT)
		_set_button_text_color(_deploy_button, DEPLOY_IDLE_TEXT)
		var remaining: int = MAX_SELECTED_UNITS - _selected_unit_ids.size()
		_deploy_button.text = "SELECT %d MORE" % maxi(remaining, 0)
		_deploy_button.disabled = true
		_deploy_button.mouse_filter = Control.MOUSE_FILTER_IGNORE


# Named _on_begin_run_pressed (not _on_deploy_pressed) to keep the screen's
# established handler contract — the flow smoke test drives this method by name.
func _on_begin_run_pressed() -> void:
	if _selected_unit_ids.size() != MAX_SELECTED_UNITS or _selected_operation_id == "":
		return
	AudioManager.play_select()
	GameState.start_run(_selected_unit_ids, _selected_operation_id)
	GameState.advance_to_next_battle()
	SceneManager.go_to_battle()


# ─── Helpers ──────────────────────────────────────────────────────────────────
# A hard-square DT portrait frame whose texture COVER-fills the box (top-aligned, so
# the head stays and the bottom is cropped) — same technique as the battle cards.
# Returns the frame, the inner crop Control (for badges), and the texture.
func _make_portrait_box(bg: Color, border: Color) -> Dictionary:
	var frame := PanelContainer.new()
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Inset the content by the border width so the portrait sits INSIDE the frame
	# instead of covering it — the border always stays on top of the image.
	var frame_style: StyleBoxFlat = _make_panel_style(bg, border)
	frame_style.set_content_margin_all(float(PANEL_BORDER))
	frame.add_theme_stylebox_override("panel", frame_style)
	var crop := Control.new()
	crop.clip_contents = true
	crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(crop)
	var tex := TextureRect.new()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE   # position/size set manually by cover-fit
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crop.add_child(tex)
	# Re-fit whenever the box is (re)laid out.
	crop.resized.connect(_cover_fit_portrait.bind(crop, tex))
	return {"frame": frame, "crop": crop, "tex": tex}


# Cover-scale the texture to fill `crop`, centered horizontally and top-aligned so the
# subject's head stays visible while the box is fully filled (overflow clipped).
func _cover_fit_portrait(crop: Control, tex: TextureRect) -> void:
	if crop == null or tex == null:
		return
	var fw: float = crop.size.x
	var fh: float = crop.size.y
	if fw < 2.0 or fh < 2.0:
		return
	var t: Texture2D = tex.texture
	if t == null:
		tex.position = Vector2.ZERO
		tex.size = Vector2(fw, fh)
		return
	var tw: float = float(t.get_width())
	var th: float = float(t.get_height())
	if tw < 1.0 or th < 1.0:
		return
	var s: float = maxf(fw / tw, fh / th)
	var nw: float = tw * s
	var nh: float = th * s
	tex.position = Vector2((fw - nw) * 0.5, 0.0)
	tex.size = Vector2(nw, nh)


func _make_pixel_label(text: String, size_logical: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", PixelUI.get_pixel_font())
	label.add_theme_font_size_override("font_size", size_logical)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_header_label(text: String, color: Color, align: int = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := _make_pixel_label(text, HEADER_FONT, color)
	label.horizontal_alignment = align
	return label


func _apply_button_font(button: Button, size_logical: int, color: Color) -> void:
	button.add_theme_font_override("font", PixelUI.get_pixel_font())
	button.add_theme_font_size_override("font_size", size_logical)
	_set_button_text_color(button, color)
	button.add_theme_constant_override("outline_size", 0)


func _set_button_text_color(button: Button, color: Color) -> void:
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_focus_color", color)
	button.add_theme_color_override("font_disabled_color", color)


func _make_panel_style(bg: Color, border: Color, border_width: int = PANEL_BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = PANEL_RADIUS
	style.corner_radius_top_right = PANEL_RADIUS
	style.corner_radius_bottom_left = PANEL_RADIUS
	style.corner_radius_bottom_right = PANEL_RADIUS
	style.shadow_size = 0
	style.set_content_margin(SIDE_LEFT, 0)
	style.set_content_margin(SIDE_RIGHT, 0)
	style.set_content_margin(SIDE_TOP, 0)
	style.set_content_margin(SIDE_BOTTOM, 0)
	return style
