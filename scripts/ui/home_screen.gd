# Deploy / picker screen: encounter carousel + 4x2 squad grid + DEPLOY.
#
# Direction-05 "Dithered Terminal" styling, authored against the 1080x2400 logical
# viewport (project base); on-screen px values are ~×2.4 in logical units. Fonts use
# m5x7 at clean multiples via _make_pixel_label (bypasses PixelUI.scale_font_size so
# small labels stay pixel-crisp). Colors pull from PixelUI DT_* tokens.
#
# Squad-select redesign (2026-07-10, Kev-approved mockup):
# - Encounter = ONE compact banner row: [◀] name + threat [boss thumb] [▶], dots
#   under. The flavor blurb is NOT on screen — long-press the banner opens the
#   InspectPopup (InspectResolver.resolve_encounter) with the verbatim copy.
#   The boss thumb is a SQUARE cell at the same size as the hero portrait cells,
#   letterboxed KEEP_ASPECT_CENTERED (never cover-cropped like hero busts).
# - Squad: the portrait IS the button (no name-button row); hero name is a label
#   UNDER each portrait. Tap toggles selection (slot badge + cyan border); the
#   detail panel follows the last-tapped hero. No role legend — role reads from
#   the portrait corner pip + the named role tag in the detail panel.
# - Locked heroes: no full-size cells — one slim "lock: N LOCKED" strip under the grid.
# - Detail panel is anchored ABOVE the deploy button.
# - DEPLOY shows its own gate: "DEPLOY SQUAD (N MORE)" ghosted until full.
#   Threat level derives from encounter order (no data field); boss thumb = the
#   operation's highest-HP enemy with art.
extends Control

const MAX_SELECTED_UNITS := 3

# Layout (logical units).
const ROOT_MARGIN_X := 40   # 60→40 (composition pass): buys the grid its exact-fit width
const ROOT_MARGIN_TOP := 60
const ROOT_MARGIN_BOTTOM := 48
const SECTION_GAP := 30
const HEADER_GAP := 16

# Fonts (logical units) — matched to the battle screen's scale (card names 72,
# protocol/summary labels 70-112) so the picker reads at the same weight.
const HEADER_FONT := 72
const COUNTER_FONT := 64
const ENC_NAME_FONT := 80          # biggest text in the banner by design; long names
                                   # (STELLAR MENAGERIE) wrap to two lines instead of clipping
const ENC_META_FONT := 56          # THREAT / LV — sized up from 48
const TILE_NAME_FONT := 60         # sized to the widest callsign (AVALANCHE) at cell width 238
const DETAIL_NAME_FONT := 76
const DETAIL_DESC_FONT := 56       # kit blurb — sized up from 52 (redesign sizing rule)
const FOCUS_CHIP_FONT := 40
const DEPLOY_FONT := 84
const DEPLOY_GATE_FONT := 64       # the ghosted "(N MORE)" gate reads smaller than DEPLOY
# Fixed DEPLOY button height so the locked→armed font swap never resizes it (measured
# armed height at DEPLOY_FONT). Both states pin to this; the cluster never shifts.
const DEPLOY_BUTTON_HEIGHT := 145

# 4px (not 2) so borders survive the canvas_items downscale to the preview window —
# at 2px they render sub-pixel and drop edges, worst on bright accent borders.
const PANEL_BORDER := 4
const PANEL_RADIUS := 0

# Grid portrait cell width. Pixel-snapped: content width 1080 − 2×40 margins =
# 1000; 4 columns with 3×16 gaps → (1000 − 48) / 4 = 238 exactly (even → crisp
# halves at 540 preview). Width is DERIVED from the usable width, not a target.
const PORTRAIT_CELL := 238
# Battle-scene portrait framing: tiles reuse the ONE portrait region
# (PixelUI.HERO_PORTRAIT_REGION, 328×380 — measured live from the battle card)
# + the same cover-fit function (PixelUI.cover_fit_portrait), scaled to cell
# width — the hero you pick is framed identically to the hero in battle,
# smaller. The old local 320×486 constant was STALE (a pre-redesign card
# anatomy) and gave squad select a different window than battle — the
# 2026-07-12 portrait-framing bug. Never define a second portrait aspect.
const BATTLE_PORTRAIT_REGION := PixelUI.HERO_PORTRAIT_REGION
# Banner boss thumb: the SAME portrait region aspect, so the boss is framed
# identically to its battle card, smaller. 224 × round(224·380/328) = 260
# (kept even for the pixel-snap law; derivation must track HERO_PORTRAIT_REGION).
const ENC_THUMB_W := 224
const ENC_THUMB_H := 260
const TILE_GAP := 16
const GRID_COLUMNS := 4
const ROLE_BADGE_SIZE := 34
const SLOT_BADGE_SIZE := 60
const CHECK_INSET := 8

const BANNER_PAD := 16
const NAV_BUTTON_W := 96
const THREAT_PIP_COUNT := 5
const THREAT_PIP_SIZE := Vector2(48, 36)   # sized up from (42,30) — near-illegible strip

const LOCKED_STRIP_H := 72
const LOCKED_ICON := 48

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
var _current_op_locked: bool = false
var _enc_banner: PanelContainer
var _enc_portrait: TextureRect
var _enc_thumb_holder: Control
var _enc_portrait_placeholder: Label
var _enc_lock_overlay: Control
var _enc_name_label: Label
var _enc_level_label: Label
var _locked_strip_label: Label
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
	# Same track as the title — a strict no-op arriving from it (never restarts).
	MusicManager.play_track(&"sci_fi_loop_1")
	MusicManager.set_combat(false)
	# No run is active on the deploy screen — blank the persistent header's run
	# label and leave its buttons inert (this screen binds none of them).
	PersistentHeader.set_run_active(false)
	PersistentHeader.clear_battle_actions()
	# Back from the deploy screen returns to the title screen (Kev 2026-07-10).
	PersistentHeader.bind_battle_actions(Callable(), Callable(), Callable(), _on_back_to_title)
	_apply_background()
	_gather_data()
	_build_layout()
	# Kev 2026-07-10: the detail panel stays HIDDEN until the player taps a
	# unit — no default dossier on entry.
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

	# Surface the 3 original starting heroes as the top slots; the locked ladder heroes
	# fill in behind them.
	var ordered: Array[String] = []
	for starter in SaveManager.STARTING_HEROES:
		if _unit_ids.has(starter) and not ordered.has(str(starter)):
			ordered.append(str(starter))
	for uid in _unit_ids:
		if not ordered.has(uid):
			ordered.append(str(uid))
	_unit_ids = ordered


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

	# Final pass §1 — centered cluster: the top bar (PersistentHeader) and DEPLOY
	# are the stationary chrome; everything between (banner → divider → squad
	# grid → locked strip → detail panel) moves as ONE block with fixed internal
	# rhythm, vertically centered by the two equal spacers. At 8 heroes the
	# cluster nearly fills the space; at 3–4 the whole block (banner included —
	# it's interactive: swipe + long-press) sits lower and thumb-reachable, with
	# symmetric space above and below.
	var spacer_top := Control.new()
	spacer_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer_top)
	column.add_child(_build_encounter_section())
	column.add_child(_build_divider())
	column.add_child(_build_squad_section())
	var spacer_bottom := Control.new()
	spacer_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer_bottom)
	column.add_child(_build_deploy_button())


# ─── Encounter carousel ─────────────────────────────────────────────────────---
func _build_encounter_section() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", HEADER_GAP)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	section.add_child(_make_header_label("SELECT ENCOUNTER", PixelUI.TEXT_MUTED, HORIZONTAL_ALIGNMENT_LEFT))

	# Compact single-row banner: [◀] [name + threat] [boss thumb] [▶].
	# Long-press anywhere on it opens the encounter InspectPopup (the flavor blurb
	# lives there now, not on the screen). No taught hint — long-press is the
	# game-wide inspect convention.
	_enc_banner = PanelContainer.new()
	_enc_banner.mouse_filter = Control.MOUSE_FILTER_STOP
	_enc_banner.add_theme_stylebox_override("panel", _make_panel_style(PixelUI.DT_HERO_BG, PixelUI.DT_HERO_BORDER))
	section.add_child(_enc_banner)
	var banner_press := LongPressInput.new()
	_enc_banner.add_child(banner_press)
	banner_press.long_pressed.connect(_on_banner_long_pressed)

	var pad := MarginContainer.new()
	for side_key in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side_key, BANNER_PAD)
	_enc_banner.add_child(pad)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(row)

	row.add_child(_make_nav_button("◀", -1))   # ◀

	# Name + threat, stacked, centered in the leftover width.
	var text_col := VBoxContainer.new()
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.add_theme_constant_override("separation", 14)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_col)

	_enc_name_label = _make_pixel_label("", ENC_NAME_FONT, PixelUI.TEXT_PRIMARY)
	_enc_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enc_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_enc_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_child(_enc_name_label)
	text_col.add_child(_build_threat_row())

	# Boss thumb — rectangular at the dominant art aspect (ENC_THUMB_W/H ≈ the
	# 592×880 portrait art), letterboxed KEEP_ASPECT_CENTERED so nothing ever
	# stretches; dominant-aspect art sits flush, outliers letterbox.
	var thumb_frame := PanelContainer.new()
	thumb_frame.clip_contents = true
	thumb_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_frame.custom_minimum_size = Vector2(ENC_THUMB_W, ENC_THUMB_H)
	thumb_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var thumb_style: StyleBoxFlat = _make_panel_style(PixelUI.DT_ENEMY_BG, PixelUI.DT_ENEMY_BORDER)
	thumb_style.set_content_margin_all(float(PANEL_BORDER))
	thumb_frame.add_theme_stylebox_override("panel", thumb_style)
	var thumb_holder := Control.new()
	thumb_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Cover-crop like the battle cards (Kev 2026-07-10: heads to the top of the
	# box, no letterboxing) — PixelUI.cover_fit_portrait is the framing rule.
	thumb_holder.clip_contents = true
	thumb_frame.add_child(thumb_holder)
	_enc_thumb_holder = thumb_holder
	_enc_portrait = TextureRect.new()
	_enc_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_enc_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_enc_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb_holder.add_child(_enc_portrait)
	thumb_holder.resized.connect(func() -> void:
		PixelUI.cover_fit_portrait(_enc_portrait, _enc_thumb_holder.size))
	_enc_portrait_placeholder = _make_pixel_label("?", 128, PixelUI.DT_ENEMY_BORDER)
	_enc_portrait_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enc_portrait_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_enc_portrait_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	thumb_holder.add_child(_enc_portrait_placeholder)
	# Padlock overlay for locked operations — sibling of the (black-modulated)
	# portrait so it isn't tinted out. Toggled in _refresh_encounter.
	_enc_lock_overlay = _make_lock_overlay()
	_enc_lock_overlay.visible = false
	thumb_holder.add_child(_enc_lock_overlay)
	row.add_child(thumb_frame)

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
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# No "THREAT" word — the pips + LV label carry it (the word's fixed width was
	# the straw that pushed the banner's minimum past the 960px content column,
	# inflating every sibling section and bleeding the grid past the right margin).
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
	# Full banner height (= the boss thumb) so the swipe targets are easy thumbs.
	button.custom_minimum_size = Vector2(NAV_BUTTON_W, ENC_THUMB_H)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.text = glyph
	# Flippers match the panel OUTLINE (hero border / cyan), not the red enemy frame.
	_apply_button_font(button, 44, PixelUI.DT_CYAN)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, PixelUI.make_hard_style(PixelUI.DT_HERO_BG, PixelUI.DT_HERO_BORDER, PANEL_BORDER))
	button.add_theme_stylebox_override("hover", PixelUI.make_hard_style(PixelUI.DT_HERO_BG, PixelUI.DT_CYAN, PANEL_BORDER))
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
	var boss_tex: Texture2D = _get_boss_portrait(op)
	_enc_portrait.texture = boss_tex
	if _enc_thumb_holder != null and is_instance_valid(_enc_thumb_holder):
		PixelUI.cover_fit_portrait(_enc_portrait, _enc_thumb_holder.size)
	_enc_portrait_placeholder.visible = boss_tex == null

	var level: int = _threat_level(_operation_index)
	_enc_level_label.text = "LV %d" % level
	for i in _threat_pips.size():
		_threat_pips[i].color = THREAT_FILL if i < level else THREAT_EMPTY

	for i in _dot_nodes.size():
		_dot_nodes[i].color = PixelUI.DT_CYAN if i == _operation_index else PixelUI.DT_PROTO_EMPTY_BORDER

	# Locked operations stay browsable but hidden: the boss renders as a black silhouette,
	# the name reads "[ LOCKED ]" (no unlock hint — part of the surprise), and DEPLOY is
	# disabled. The portrait node is reused on scroll, so reset its tint for unlocked ops.
	_current_op_locked = not SaveManager.is_operation_unlocked(_selected_operation_id)
	_enc_portrait.modulate = Color(0.0, 0.0, 0.0, 1.0) if _current_op_locked else Color(1.0, 1.0, 1.0, 1.0)
	if _enc_lock_overlay != null:
		_enc_lock_overlay.visible = _current_op_locked
	if _current_op_locked:
		_enc_name_label.text = "[ LOCKED ]"
	_refresh_deploy()


# Long-press on the banner → encounter InspectPopup (name, threat, and the full
# flavor blurb — relocated off the visible screen by the squad-select redesign).
# Locked operations reveal nothing.
func _on_banner_long_pressed(_global_position: Vector2) -> void:
	if _current_op_locked or _operation_ids.is_empty():
		return
	var op: OperationData = DataManager.get_operation(_selected_operation_id) as OperationData
	if op == null:
		return
	AudioManager.play_select()
	var payload: Dictionary = InspectResolver.resolve_encounter(op, _threat_level(_operation_index), THREAT_PIP_COUNT)
	InspectPopup.open(self, payload, _enc_banner.get_global_rect(), _enc_banner.get_instance_id())


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

	# No role legend (redesign): role reads from the portrait corner pip + the named
	# tag in the detail panel — nothing else teaches the color code.

	# Grid holds UNLOCKED heroes only; locked heroes collapse into one slim strip
	# below. Rows are hand-chunked HBoxes (not a GridContainer) so a PARTIAL last
	# row centers its cells instead of left-aligning against a dead column (final
	# pass §2). Cells are fixed-width, so a full row spans the content width
	# exactly (4×238 + 3×16 = 1000) and partial rows keep identical cell sizes.
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", TILE_GAP)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(rows)
	var locked_count: int = 0
	var row: HBoxContainer = null
	var row_count: int = 0
	for unit_id in _unit_ids:
		var unit: UnitData = DataManager.get_unit(unit_id) as UnitData
		if unit == null:
			continue
		if not SaveManager.is_hero_unlocked(unit_id):
			locked_count += 1
			continue
		if row == null or row_count == GRID_COLUMNS:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", TILE_GAP)
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rows.add_child(row)
			row_count = 0
		row.add_child(_build_unit_tile(unit_id, unit))
		row_count += 1

	section.add_child(_build_locked_strip(locked_count))

	# Detail panel lives directly under the locked strip (composition pass §2) —
	# part of the content flow, not pinned at the bottom.
	_detail_panel = _build_detail_bar()
	section.add_child(_detail_panel)
	return section


# One slim strip standing in for every locked roster slot: lock glyph + "N LOCKED".
# Reads the same roster/unlock source the old full-size locked cells did
# (SaveManager.is_hero_unlocked over _unit_ids), so it stays true as heroes unlock.
func _build_locked_strip(locked_count: int) -> Control:
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 14)
	strip.custom_minimum_size = Vector2(0, LOCKED_STRIP_H)
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.visible = locked_count > 0
	var icon := TextureRect.new()
	icon.texture = load(PixelUI.ICON_LOCK) as Texture2D
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(LOCKED_ICON, LOCKED_ICON)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = PixelUI.TEXT_MUTED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(icon)
	_locked_strip_label = _make_pixel_label("%d LOCKED" % locked_count, PixelUI.FONT_INFO_MIN, PixelUI.TEXT_MUTED)
	_locked_strip_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	strip.add_child(_locked_strip_label)
	return strip


func _build_detail_bar() -> PanelContainer:
	var panel := PanelContainer.new()
	# Snug to content (refinement pass §3): header row + exactly two blurb lines
	# + padding. The desc label reserves a fixed 2-line block (no picker blurb
	# exceeds 2 lines at this width — verified against data), so swapping between
	# 1- and 2-line heroes never reflows the layout.
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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

	# No placeholder state — _ready() focuses the first unlocked hero, so the
	# panel is populated from the first frame (composition pass §3).
	_detail_name = _make_pixel_label("", DETAIL_NAME_FONT, PixelUI.TEXT_PRIMARY)
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

	_detail_desc = _make_pixel_label("", DETAIL_DESC_FONT, PixelUI.TEXT_MUTED)
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Reserve exactly two blurb lines INCLUDING the inter-line spacing so the
	# panel height is constant. Reserving 2×font_height alone under-measured by
	# the Label's line_spacing (3px): the first populate grew the panel and the
	# whole centered cluster shifted up 1px (Batch 3 — the screen must never move).
	var desc_font: Font = PixelUI.get_pixel_font()
	var desc_line_spacing: int = _detail_desc.get_theme_constant("line_spacing")
	_detail_desc.custom_minimum_size = Vector2(0, ceilf(desc_font.get_height(DETAIL_DESC_FONT) * 2.0 + float(desc_line_spacing)))
	_detail_desc.max_lines_visible = 2
	col.add_child(_detail_desc)

	return panel


# Tile = square portrait (the ONLY tap target) + name label UNDER it. Quick tap
# toggles selection; long-press opens the unit inspect popup. Only unlocked heroes
# get tiles — locked heroes collapse into the strip.
func _build_unit_tile(unit_id: String, unit: UnitData) -> Control:
	# Fixed-width cell (final pass §2): identical in full and partial rows; the
	# row container centers partial rows, so cells must not stretch.
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 8)
	cell.custom_minimum_size = Vector2(PORTRAIT_CELL, 0)
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var long_press := LongPressInput.new()
	cell.add_child(long_press)
	long_press.tapped.connect(_on_tile_tapped.bind(unit_id))
	long_press.long_pressed.connect(_on_tile_long_pressed.bind(unit_id, cell))

	var portrait_box: Dictionary = _make_portrait_box(PixelUI.DT_HERO_BG, PixelUI.DT_HERO_BORDER)
	var frame: PanelContainer = portrait_box["frame"]
	var crop: Control = portrait_box["crop"]
	# Crop region carries the battle card's exact portrait aspect
	# (PixelUI.HERO_PORTRAIT_REGION, 328:380); frame height = region height +
	# the border insets on both edges.
	var inner_w: float = float(PORTRAIT_CELL - 2 * PANEL_BORDER)
	var inner_h: float = roundf(inner_w * BATTLE_PORTRAIT_REGION.y / BATTLE_PORTRAIT_REGION.x)
	frame.custom_minimum_size = Vector2(PORTRAIT_CELL, inner_h + 2.0 * float(PANEL_BORDER))
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

	# Slot badge (top-left): filled cyan plate with the pick order (1/2/3) — the
	# selection indicator on the portrait itself, alongside the bright border.
	var slot_badge := PanelContainer.new()
	slot_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	slot_badge.offset_left = CHECK_INSET
	slot_badge.offset_top = CHECK_INSET
	slot_badge.custom_minimum_size = Vector2(SLOT_BADGE_SIZE, SLOT_BADGE_SIZE)
	slot_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_badge.add_theme_stylebox_override("panel", PixelUI.make_hard_style(PixelUI.DT_CYAN, PixelUI.DT_CYAN, 0))
	var slot_label := _make_pixel_label("", TILE_NAME_FONT, PixelUI.BTN_PRIMARY_INK)
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot_badge.add_child(slot_label)
	slot_badge.visible = false
	crop.add_child(slot_badge)

	# Newly-unlocked heroes: a NEW badge until first added to a squad.
	var new_badge: Control = null
	if SaveManager.is_hero_new(unit_id):
		new_badge = _make_new_badge()
		crop.add_child(new_badge)

	# Name label UNDER the portrait — a label, not a button.
	var tile_name: String = unit.callsign if unit.callsign != "" else unit.display_name
	var name_label := _make_pixel_label(tile_name.to_upper(), TILE_NAME_FONT, PixelUI.DT_HERO_NAME)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_child(name_label)

	_unit_tiles[unit_id] = {
		"frame": frame,
		"role_badge": role_badge,
		"name": name_label,
		"slot_badge": slot_badge,
		"slot_label": slot_label,
		"locked": false,
		"new_badge": new_badge,
	}
	return cell


# The padlock glyph (batch 188) centered over a locked hero's black silhouette.
func _make_lock_overlay() -> Control:
	var wrap := CenterContainer.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = load(PixelUI.ICON_LOCK) as Texture2D
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(72, 72)
	icon.modulate = PixelUI.TEXT_MUTED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(icon)
	return wrap


# A small amber NEW badge (the icon_new "!" glyph, batch 189) pinned to the
# portrait's top-left corner.
func _make_new_badge() -> Control:
	var badge := PanelContainer.new()
	badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	badge.offset_left = CHECK_INSET
	badge.offset_top = CHECK_INSET
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = PixelUI.make_hard_style(PixelUI.DT_AMBER, PixelUI.DT_AMBER, 0)
	style.set_content_margin(SIDE_LEFT, 6.0)
	style.set_content_margin(SIDE_RIGHT, 6.0)
	style.set_content_margin(SIDE_TOP, 4.0)
	style.set_content_margin(SIDE_BOTTOM, 4.0)
	badge.add_theme_stylebox_override("panel", style)
	var icon := TextureRect.new()
	icon.texture = load(PixelUI.ICON_NEW) as Texture2D
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(28, 40)
	icon.modulate = PixelUI.BTN_PRIMARY_INK  # dark "!" on the amber tag
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(icon)
	return badge


func _on_tile_tapped(unit_id: String) -> void:
	_focused_unit_id = unit_id
	# Locked heroes are not selectable; still focus so the detail bar shows the hint.
	if not SaveManager.is_hero_unlocked(unit_id):
		_refresh_detail()
		return
	_toggle_unit_selection(unit_id)
	_refresh_unit_tiles()
	_refresh_squad_counter()
	_refresh_detail()
	_refresh_deploy()


func _on_tile_long_pressed(_global_position: Vector2, unit_id: String, anchor: Control) -> void:
	# Locked units reveal nothing — no inspect popup.
	if not SaveManager.is_hero_unlocked(unit_id):
		return
	var unit := DataManager.get_unit(unit_id) as UnitData
	if unit == null:
		return
	AudioManager.play_select()
	var anchor_rect: Rect2 = anchor.get_global_rect() if is_instance_valid(anchor) else Rect2()
	InspectPopup.open(self, InspectResolver.resolve_unit(unit), anchor_rect, anchor.get_instance_id())


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
	# First squad add clears the hero's NEW badge.
	SaveManager.acknowledge_hero(unit_id)


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
		# Slot badge = the on-portrait selection indicator (1/2/3 pick order).
		var slot_badge: Variant = tile.get("slot_badge")
		var slot_label: Variant = tile.get("slot_label")
		if slot_badge != null and is_instance_valid(slot_badge):
			(slot_badge as Control).visible = is_selected
			if is_selected and slot_label != null and is_instance_valid(slot_label):
				(slot_label as Label).text = str(_selected_unit_ids.find(unit_id) + 1)
		var new_badge: Variant = tile.get("new_badge")
		if new_badge != null and is_instance_valid(new_badge):
			(new_badge as Control).visible = SaveManager.is_hero_new(unit_id)


func _refresh_squad_counter() -> void:
	if _counter_label != null:
		_counter_label.text = "%d / %d" % [_selected_unit_ids.size(), MAX_SELECTED_UNITS]


# Compatibility aliases for the established screen contract (flow smoke test etc.).
func _refresh_unit_thumbs() -> void:
	_refresh_unit_tiles()


func _refresh_begin_button() -> void:
	_refresh_deploy()


# Focus a unit in the detail panel (capture harness drives this by name).
func _show_unit_detail(unit_id: String) -> void:
	_focused_unit_id = unit_id
	_refresh_detail()


func _on_back_to_title() -> void:
	AudioManager.play_select()
	SceneManager.go_to_main_menu()


func _refresh_detail() -> void:
	# The box is ALWAYS there (Kev 2026-07-10 rev 2) — it just starts empty
	# until a unit is tapped, so the layout never jumps.
	if _focused_unit_id == "":
		if _detail_name != null:
			_detail_name.text = ""
		if _detail_focus_chip != null:
			_detail_focus_chip.visible = false
		if _detail_desc != null:
			_detail_desc.text = ""
		return
	var unit: UnitData = DataManager.get_unit(_focused_unit_id) as UnitData
	if unit == null:
		return
	# Locked unit: keep it a mystery — no name, focus, or dossier.
	if not SaveManager.is_hero_unlocked(_focused_unit_id):
		_detail_name.text = "[ LOCKED ]"
		_detail_focus_chip.visible = false
		_detail_desc.text = "Locked specialist."
		return
	_detail_name.text = unit.display_name.to_upper()
	# Unit category is hidden from the player (Batch 2) — visibility change only.
	# The picker_category field and _role_color (portrait badge + grid ordering)
	# still read it on the backend; only this text chip is suppressed.
	_detail_focus_chip.visible = false
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
	# Constant height (Batch 6): the armed DEPLOY (font 84 + corner brackets) is 145 px
	# tall while the locked gate (font 64) is only ~130 — so arming used to grow the
	# button 15 px and the two centering spacers rebalanced, shifting the whole cluster.
	# Pinning the minimum to the armed height makes both states render at 145: the button
	# never resizes, the screen never shifts.
	_deploy_button.custom_minimum_size = Vector2(0, DEPLOY_BUTTON_HEIGHT)
	_deploy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deploy_button.text = "DEPLOY SQUAD (%d MORE)" % MAX_SELECTED_UNITS
	_deploy_button.pressed.connect(_on_begin_run_pressed)
	_deploy_panel.add_child(_deploy_button)
	return _deploy_panel


func _refresh_deploy() -> void:
	if _deploy_button == null:
		return
	var op_unlocked := _selected_operation_id != "" and SaveManager.is_operation_unlocked(_selected_operation_id)
	var units_ready := _selected_unit_ids.size() == MAX_SELECTED_UNITS
	var ready := units_ready and op_unlocked
	if ready:
		# Requirement met → actionable teal primary button.
		_deploy_button.text = "DEPLOY SQUAD"
		PixelUI.style_primary_button(_deploy_button, DEPLOY_FONT)
		_deploy_button.disabled = false
		_deploy_button.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		# Requirement unmet → the button states its own gate (redesign §5): what it
		# is + what's missing. A locked operation blocks deploy even with a full squad.
		if units_ready and not op_unlocked:
			_deploy_button.text = "OPERATION LOCKED"
		else:
			var missing: int = MAX_SELECTED_UNITS - _selected_unit_ids.size()
			_deploy_button.text = "DEPLOY SQUAD (%d MORE)" % missing
		PixelUI.style_locked_button(_deploy_button, DEPLOY_GATE_FONT)
		_deploy_button.disabled = true
		_deploy_button.mouse_filter = Control.MOUSE_FILTER_IGNORE


# Named _on_begin_run_pressed (not _on_deploy_pressed) to keep the screen's
# established handler contract — the flow smoke test drives this method by name.
func _on_begin_run_pressed() -> void:
	if _selected_unit_ids.size() != MAX_SELECTED_UNITS or _selected_operation_id == "":
		return
	if not SaveManager.is_operation_unlocked(_selected_operation_id):
		return
	AudioManager.play_select()
	# Starting Directive (pkg5): with unlocked boss relics, offer one as the
	# run's opening relic before deploying. The battle-5 draft still happens.
	var unlocked_directives: Array = SaveManager.get_unlocked_boss_relics()
	if unlocked_directives.is_empty():
		_launch_run("")
		return
	_open_directive_picker(unlocked_directives)


func _launch_run(directive_relic_id: String) -> void:
	GameState.start_run(_selected_unit_ids, _selected_operation_id)
	# Encounter start: the ONE crossfade to the faction's track. It then plays
	# unbroken across every battle and between-battle screen until encounter end.
	MusicManager.play_for_faction(GameState.selected_operation_id)
	if directive_relic_id != "":
		GameState.set_starting_directive(directive_relic_id)
	GameState.advance_to_next_battle()
	SceneManager.go_to_battle()


# ─── Starting Directive picker ───────────────────────────────────────────────
var _directive_layer: Control


func _open_directive_picker(relic_ids: Array) -> void:
	if _directive_layer != null and is_instance_valid(_directive_layer):
		return
	_directive_layer = Control.new()
	_directive_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_directive_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_directive_layer.add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", PixelUI.make_hard_style(PixelUI.BG_PANEL_ALT, PixelUI.DT_AMBER, 4))
	panel.custom_minimum_size = Vector2(880, 0)
	_directive_layer.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 36)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 28)
	margin.add_child(col)

	col.add_child(_make_pixel_label("STARTING DIRECTIVE", DETAIL_NAME_FONT, PixelUI.DT_AMBER))
	var blurb := _make_pixel_label("Open the run with a trophy from a fallen boss.", DETAIL_DESC_FONT, PixelUI.TEXT_MUTED)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(blurb)

	for relic_id_variant in relic_ids:
		var relic_id: String = str(relic_id_variant)
		var relic: ItemData = DataManager.get_item(relic_id) as ItemData
		if relic == null:
			continue
		# Kev 2026-07-10: each pick shows the relic's ICON beside its name +
		# rule (the plain text rows read anonymous).
		var pick := Button.new()
		pick.focus_mode = Control.FOCUS_NONE
		pick.custom_minimum_size = Vector2(0, 148)
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PixelUI.style_button(pick, PixelUI.DT_HERO_BG, PixelUI.DT_CYAN, FOCUS_CHIP_FONT)
		pick.pressed.connect(_on_directive_picked.bind(relic_id))
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 18.0
		row.offset_right = -18.0
		row.add_theme_constant_override("separation", 20)
		pick.add_child(row)
		if relic.icon != null:
			var icon := TextureRect.new()
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.custom_minimum_size = Vector2(104, 104)
			icon.texture = relic.icon
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(icon)
		var text_label := _make_pixel_label("%s — %s" % [relic.display_name.to_upper(), relic.description], FOCUS_CHIP_FONT, PixelUI.DT_CYAN_BRIGHT)
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(text_label)
		col.add_child(pick)

	var skip := Button.new()
	skip.focus_mode = Control.FOCUS_NONE
	skip.custom_minimum_size = Vector2(0, 96)
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip.text = "NO DIRECTIVE"
	PixelUI.style_button(skip, DEPLOY_IDLE_BG, DEPLOY_IDLE_BORDER, FOCUS_CHIP_FONT)
	skip.pressed.connect(_on_directive_picked.bind(""))
	col.add_child(skip)

	# Center the panel once it has a size.
	await get_tree().process_frame
	if is_instance_valid(panel):
		panel.position = (size - panel.size) * 0.5


func _on_directive_picked(relic_id: String) -> void:
	AudioManager.play_select()
	if _directive_layer != null and is_instance_valid(_directive_layer):
		_directive_layer.queue_free()
		_directive_layer = null
	_launch_run(relic_id)


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
	PixelUI.cover_fit_portrait(tex, crop.size)


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
	style.set_border_width_all(PixelUI.min_stroke(border_width))
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
