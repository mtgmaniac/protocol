# Squad selector (DECISIONS_RESOLVED G-93). The backdrop and shared header span
# the viewport; MISSION, SQUAD, optional UNIT INFO and DEPLOY occupy a centered
# content column. The four-column roster is the only selection interface.
# Unit info starts collapsed and its expanded panel paints into a permanently
# reserved area, so Deploy stays in place. A new game starts at zero picks;
# only a run returning in the same process restores the last deployed squad.
# Switching missions and toggling heroes never changes the block geometry.
extends Control

const OPERATION_BRIEFING_OVERLAY := preload("res://scripts/ui/operation_briefing_overlay.gd")
const MENU_SPACE_BACKGROUND := preload("res://scripts/ui/menu_space_background.gd")

const MAX_SELECTED_UNITS := 3

# Layout (design px).
const ROOT_MARGIN_X := 40   # buys the grid its exact-fit width (1000 px content)
const ROOT_MARGIN_BOTTOM := 48
const GAP := PixelUI.GAP
## The five gaps' floors, top to bottom (G-86): header -> mission block,
## mission -> separator, separator -> squad, squad -> info bar, info bar ->
## DEPLOY.
const GAP_FLOORS: Array[int] = [2 * GAP, GAP, GAP, GAP, 2 * GAP]
## The squad block -> info bar gap stays at its floor, one GAP (G-88): the info
## bar reads as attached to the units.
const INFO_GAP_INDEX := 3
## The two section gaps around the divider (mission -> separator, separator ->
## squad) stay at their floor, one GAP (crisp text step 3b, Kev 2026-10-20: the
## MISSION card sat 160 px above the SQUAD header). The leftover height goes to
## the two buffers (gap_sizes).
const SECTION_GAP_INDICES: Array[int] = [1, 2]
## Subheaders (MISSION, SQUAD and its n / 3): one clean step above LABEL's 64,
## m5x7 laid out at 96 and drawn pixel-exact (PixelUI.bind_m5x7_snap), as the
## run-end report's rows: 2 screen px per font pixel on the phones, 3 at the
## 540 preview.
const SUBHEADER_FONT_PX := Vector2(5.0, 6.0)
## Design px per art pixel: glyphs, pips and the band bar sit on this grid.
const ART_PX := 4

const TILE_NAME_FONT := 64         # design px (text_px), drawn at 80; names may overhang the cell
# Kit blurb in the Directive picker: the body-copy tier through the ONE body token.
static var DETAIL_DESC_FONT: int = PixelUI.scale_font_size(PixelUI.FONT_BODY_MIN)
const DETAIL_NAME_FONT := 80       # design px (text_px)
const FOCUS_CHIP_FONT := 40
const DEPLOY_FONT := 84
const DEPLOY_GATE_FONT := 64       # the disabled "PICK N MORE" gate reads smaller than DEPLOY
# Fixed DEPLOY button height so the gate -> armed font swap never resizes it.
const DEPLOY_BUTTON_HEIGHT := 145

# 4px (not 2) so borders survive the canvas_items downscale to the preview window.
const PANEL_BORDER := 4

# Grid portrait cell width. Pixel-snapped: content width 1080 - 2x40 margins =
# 1000; 4 columns with 3x16 gaps -> (1000 - 48) / 4 = 238 exactly.
const PORTRAIT_CELL := 238
# Portrait art windows, as WIDTHS only: PixelUI.make_portrait_frame owns the
# height (the one portrait window) and adds the frame border outside it. The
# boss portrait takes the tile's width, so it is the tiles' height too.
const TILE_PORTRAIT_W := PORTRAIT_CELL - 2 * PANEL_BORDER
const DIRECTIVE_ICON_BOX := 128.0  # Starting Directive relic art at 1x (integer law)
const TILE_GAP := 16
const GRID_COLUMNS := 4
const ROLE_BADGE_SIZE := 34
const SLOT_BADGE_SIZE := 60
const CHECK_INSET := 8

# Mission card. "A 3 px frame": 8 design px (2 art px), 2.7 screen px at 360
# and 2.9 at 390 (the battle card shell's width).
const MISSION_FRAME := 8
const MISSION_PAD := 16
const MISSION_TINT := 0.10         # the accent's share of the card's fill
const MISSION_COLUMN_GAP := 24
const NAV_BUTTON_SIZE := Vector2(72, 144)
const NAV_ICON_SIZE := 48
const NAV_ARROW_ICON := preload("res://assets/ui/icons/icon_back.png")
const THREAT_PIP_COUNT := 5
const LEVEL_PIP_SIZE := Vector2(32, 24)   # 8 x 6 art px
const LEVEL_PIP_GAP := 4
const LEVEL_ROW_GAP := 12
const DOT_SIZE := 16
const DOT_GAP := 16
const THREAT_EMPTY := PixelUI.BATTLE_PROTO_EMPTY
const DEPTH := preload("res://scripts/ui/battle_depth.gd")

# Unit info bar.
const INFO_PAD := 16
const INFO_ROW_GAP := 8
## The unit description wraps onto at most this many lines (Kev 2026-10-20).
const INFO_BLURB_LINES := 2
const BAND_BAR_H := 32             # 8 art px
const BAND_ICON_GAP := 8
## The icon under each segment: the in-game effect / status pip
## (PixelUI.pip_texture_for_key) in its own colours, 12 art px square, so it
## fits the narrowest band (a single roll, 1/20 of the bar).
const BAND_ICON := 48
## The info bar's band icons retain their color and draw without a gray ring.
const BAND_ICON_ALPHA_FLOOR := 0.06   # texels with less coverage drop out
const BAND_ICON_VALUE_FLOOR := 0.45
const HINT_TEXT := "HOLD ANY UNIT FOR FULL INTEL"
const SQUAD_FULL_TEXT := "SQUAD FULL: TAP A PICK TO REMOVE"
## A UTILITY band's icon: the first of these the ability carries, as its
## in-game status pip key ([raw ability key, pip key]). Ordered by what the
## ability is for: a taunt beacon that also grants spike shows taunt.
const UTILITY_ICON_KEYS: Array = [
	["taunt", "taunt"], ["cloak", "cloak"], ["mark", "mark"],
	["freezeAnyDice", "freeze"], ["freezeEnemyDice", "freeze"], ["freezeAllEnemyDice", "freeze"],
	["jam", "jam"], ["rewrite", "rewrite"], ["hijack", "hijack"],
	["rfe", "roll_down"], ["rfm", "roll_up"], ["burn", "burn"], ["spike", "spike"],
	["gainProtocol", "protocol"], ["cleanse", "cleanse"], ["firewall", "firewall"],
	["revive", "revive"], ["summon", "summon"],
]
## Fallback for a UTILITY ability with no in-game status icon: a 4-point spark,
## 5 x 5 art px, in CHROME ("#" = ink).
const BAND_SPARK: Array[String] = ["..#..", "..#..", "#####", "..#..", "..#.."]
## The ability keys that are not an effect of their own (labels, scopes, the
## dice range): an ability with nothing past these and no amount does nothing.
const BAND_INERT_KEYS: Array[String] = ["name", "eff", "range", "zone", "desc", "dMin", "dMax", "burnT", "rfT", "shTgt", "healTgt", "healAll", "blastAll", "rfeAll", "breachAll"]

const ROSTER_ORDER := ["combat", "engineer", "medic", "pulse", "avalanche", "shield", "ghost", "breaker"]
const CONTENT_MAX_WIDTH := 1400.0
const INFO_TOGGLE_HEIGHT := 88.0


# ─── State ────────────────────────────────────────────────────────────────────
var _operation_ids: Array[String] = []
var _operation_index: int = 0
var _selected_operation_id: String = ""
var _unit_ids: Array[String] = []
var _selected_unit_ids: Array[String] = []
## The unit the info bar shows.
var _focus_unit_id: String = ""
var _squad_full_hint: bool = false

# Built nodes
var _current_op_locked: bool = false
var _enc_card: PanelContainer
var _enc_portrait: TextureRect
var _enc_thumb_frame: PanelContainer
var _enc_portrait_placeholder: Label
var _enc_lock_overlay: Control
var _enc_name_label: Label
var _enc_level_row: HBoxContainer
var _enc_level_label: Label
var _enc_status_label: Label
var _enc_tags_slot: Control
var _enc_threats_label: Label
var _enc_unlock_label: Label
var _threat_pips: Array[ColorRect] = []
var _dot_row: HBoxContainer
var _dot_nodes: Array[ColorRect] = []
var _unit_tiles: Dictionary = {}    # unit_id -> { frame, name, slot_badge, slot_label, locked, new_badge }
var _counter_label: Label
var _info_bar: PanelContainer
var _info_region: Control
var _info_toggle: Button
var _info_name: Label
var _info_hp: Label
var _info_status: Label
var _info_blurb: Label
var _info_top: HBoxContainer
var _info_strip: Control
var _info_hint: Label
var _deploy_panel: PanelContainer
var _deploy_button: Button
var _layout_margin: MarginContainer
var _column: VBoxContainer
## The five gap slots (GAP_FLOORS order) and the blocks between them.
var _gaps: Array[Control] = []
var _blocks: Array[Control] = []


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
	_restore_last_deploy()
	_focus_unit_id = _selected_unit_ids[0] if not _selected_unit_ids.is_empty() else (_unit_ids[0] if not _unit_ids.is_empty() else "")
	_build_layout()
	_refresh_encounter()
	_refresh_unit_tiles()
	_refresh_squad_counter()
	_refresh_info()
	_refresh_deploy()


func _apply_background() -> void:
	var bg: Control = MENU_SPACE_BACKGROUND.new()
	bg.name = "MenuSpaceBackground"
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

	# The whole roster is always present in this stable, player-facing order. It
	# starts with the default squad, then follows the hero progression order.
	_unit_ids.clear()
	for unit_id in ROSTER_ORDER:
		if DataManager.get_unit(unit_id) != null:
			_unit_ids.append(unit_id)


# Only a run completed in this app session can seed the next selection. A
# profile's old last_deploy is intentionally ignored on browser reload.
func _restore_last_deploy() -> void:
	var last: Dictionary = GameState.session_deploy
	var op_id: String = str(last.get("operation", ""))
	var op_index: int = _operation_ids.find(op_id)
	if op_index >= 0 and SaveManager.is_operation_unlocked(op_id):
		_operation_index = op_index
		_selected_operation_id = op_id
	_selected_unit_ids.clear()
	for unit_id_variant in last.get("squad", []):
		var unit_id: String = str(unit_id_variant)
		if _unit_ids.has(unit_id) and SaveManager.is_hero_unlocked(unit_id) and not _selected_unit_ids.has(unit_id):
			_selected_unit_ids.append(unit_id)
	if _selected_unit_ids.size() != MAX_SELECTED_UNITS:
		_selected_unit_ids.clear()


# ─── Layout ───────────────────────────────────────────────────────────────────
func _build_layout() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", ROOT_MARGIN_X + PixelUI.safe_left)
	margin.add_theme_constant_override("margin_right", ROOT_MARGIN_X + PixelUI.safe_right)
	# Reserve room for the always-on PersistentHeader band (its real height on a
	# cutout device) plus one GAP; DEPLOY clears the gesture bar.
	margin.add_theme_constant_override("margin_top", int(PersistentHeader.band_height()))
	margin.add_theme_constant_override("margin_bottom", ROOT_MARGIN_BOTTOM + PixelUI.safe_bottom)
	add_child(margin)
	PixelUI.cap_portrait_width(margin, true, CONTENT_MAX_WIDTH)
	_layout_margin = margin

	# No container separation: every space between blocks is a gap slot, sized
	# by _distribute_gaps.
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 0)
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_column)

	var mission := VBoxContainer.new()
	mission.add_theme_constant_override("separation", GAP)
	mission.add_child(_make_subheader_row("MISSION"))
	mission.add_child(_build_mission_row())
	mission.add_child(_build_dots())
	var squad := VBoxContainer.new()
	squad.add_theme_constant_override("separation", GAP)
	squad.add_child(_build_squad_header())
	squad.add_child(_build_roster())
	_info_region = _build_info_region()
	_blocks = [mission, _build_divider(), squad, _info_region, _build_deploy_button()]
	_gaps.clear()
	for i in _blocks.size():
		if i < GAP_FLOORS.size():
			var gap := Control.new()
			gap.name = "Gap%d" % i
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gap.custom_minimum_size.y = GAP_FLOORS[i]
			_column.add_child(gap)
			_gaps.append(gap)
		_column.add_child(_blocks[i])
	margin.resized.connect(_distribute_gaps)
	_distribute_gaps.call_deferred()


# Sizes the five gap slots from the height the blocks leave (gap_sizes).
func _distribute_gaps() -> void:
	if _layout_margin == null or _gaps.is_empty():
		return
	var available: float = _layout_margin.size.y - float(_layout_margin.get_theme_constant("margin_top")) - float(_layout_margin.get_theme_constant("margin_bottom"))
	var content := 0.0
	for block: Control in _blocks:
		content += block.get_combined_minimum_size().y
	var sizes: Array[int] = gap_sizes(available - content)
	for i in _gaps.size():
		_gaps[i].custom_minimum_size.y = float(sizes[i])


## The five gaps for `free` design px left by the blocks (G-86). Each starts at
## its floor (GAP_FLOORS). The section gaps (SECTION_GAP_INDICES) and the info
## bar gap (INFO_GAP_INDEX) stay there; the rest is shared by the two buffers
## (header -> mission, info bar -> DEPLOY) in whole GAPs, an odd GAP to the one
## above DEPLOY; under one GAP of it stays below DEPLOY (the bottom margin).
## Short of the floors, the two buffers shrink first (to 0), then the section
## gaps, on the 4 px art grid.
static func gap_sizes(free: float) -> Array[int]:
	var sizes: Array[int] = GAP_FLOORS.duplicate()
	var floors := 0
	for floor_px: int in GAP_FLOORS:
		floors += floor_px
	if free >= float(floors):
		var units: int = int(floorf((free - float(floors)) / float(GAP)))
		sizes[0] += (units / 2) * GAP
		sizes[4] += (units - units / 2) * GAP
		return sizes
	var inner: float = float(floors - GAP_FLOORS[0] - GAP_FLOORS[4])
	var buffers: float = maxf(free - inner, 0.0)
	var buffer: int = int(floorf(buffers * 0.5 / ART_PX)) * ART_PX
	sizes[0] = mini(buffer, GAP_FLOORS[0])
	sizes[4] = mini(buffer, GAP_FLOORS[4])
	if free < inner:
		var section: int = int(floorf(maxf(free, 0.0) / 3.0 / ART_PX)) * ART_PX
		for i in [1, 2, 3]:
			sizes[i] = mini(section, GAP_FLOORS[i])
	return sizes


# A subheader line in a plain holder (the pixel-exact snap needs a plain
# Control parent): MISSION, or SQUAD with its counter.
func _make_subheader_row(text: String) -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.custom_minimum_size.y = ceilf(PixelUI.get_pixel_font().get_height(roundi(SUBHEADER_FONT_PX.y * 16.0)))
	_add_subheader(holder, _make_subheader(text, PixelUI.CHROME_DIM))
	return holder


# Fills the holder, sized on each resize. (Full-rect anchors set while the
# holder is still 0 wide keep the text's width as an offset, so the label grew
# past the holder's right edge and the right-aligned counter drew off screen.)
func _add_subheader(holder: Control, label: Label) -> void:
	holder.add_child(label)
	holder.resized.connect(func() -> void:
		label.position = Vector2.ZERO
		label.size = holder.size)


# A section subheader: one clean step above LABEL (MISSION, SQUAD, n / 3).
func _make_subheader(text: String, ink: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUI.apply_type(label, PixelUI.TYPE_LABEL, ink)
	PixelUI.bind_m5x7_snap(label, SUBHEADER_FONT_PX.x, SUBHEADER_FONT_PX.y)
	return label


func _make_type_label(text: String, role: String, ink: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUI.apply_type(label, role, ink)
	return label


# One SMALL text row's laid-out height (the threats slot reserves it, so a
# locked operation's unlock condition and an open one's threats take the same
# room).
func _small_row_height() -> float:
	return ceilf(PixelUI.get_pixel_font().get_height(PixelUI.type_px(PixelUI.TYPE_SMALL)))


# ─── Mission card ─────────────────────────────────────────────────────────────
func _build_mission_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GAP)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_make_nav_button(-1))

	# Long-press anywhere on the card opens the encounter InspectPopup (the
	# flavor paragraph lives there and in Help, not on the screen).
	_enc_card = PanelContainer.new()
	_enc_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_enc_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_enc_card)
	var card_press := LongPressInput.new()
	_enc_card.add_child(card_press)
	card_press.long_pressed.connect(_on_banner_long_pressed)

	var pad := MarginContainer.new()
	for side_key in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side_key, MISSION_PAD)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enc_card.add_child(pad)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", MISSION_COLUMN_GAP)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(body)

	# Boss portrait: the shared portrait frame at the roster tile's width, so the
	# boss and the heroes share a height and the battle card's window.
	var thumb_style: StyleBoxFlat = PixelUI.component_style(PixelUI.COMPONENT_ENEMY)
	thumb_style.set_content_margin_all(float(PANEL_BORDER))
	var thumb: Dictionary = PixelUI.make_portrait_frame(null, TILE_PORTRAIT_W, thumb_style)
	_enc_thumb_frame = thumb["frame"]
	_enc_thumb_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var thumb_holder: Control = thumb["crop"]
	_enc_portrait = thumb["tex"]
	_enc_portrait_placeholder = _make_type_label("?", PixelUI.TYPE_LABEL, PixelUI.CHROME_DIM)
	_enc_portrait_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enc_portrait_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_enc_portrait_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	thumb_holder.add_child(_enc_portrait_placeholder)
	# Padlock overlay for locked operations — sibling of the (black-modulated)
	# portrait so it isn't tinted out. Toggled in _refresh_encounter.
	_enc_lock_overlay = _make_lock_overlay()
	_enc_lock_overlay.visible = false
	thumb_holder.add_child(_enc_lock_overlay)
	body.add_child(_enc_thumb_frame)

	var text_col := VBoxContainer.new()
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.add_theme_constant_override("separation", GAP)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(text_col)

	# The name sits in a plain holder so its text origin can snap to a whole
	# screen px (PixelUI.set_block_ink_snap skips container children): a
	# CARD_NAME k of 2 at 390 drew some strokes 1 and 3 px wide from a half-px
	# origin.
	var name_holder := Control.new()
	name_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_holder.custom_minimum_size.y = float(PixelUI.type_px(PixelUI.TYPE_CARD_NAME))
	name_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_child(name_holder)
	_enc_name_label = _make_type_label("", PixelUI.TYPE_CARD_NAME, PixelUI.CHROME)
	_enc_name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_holder.add_child(_enc_name_label)
	PixelUI.set_block_ink_snap(_enc_name_label)

	_enc_level_row = HBoxContainer.new()
	_enc_level_row.add_theme_constant_override("separation", LEVEL_ROW_GAP)
	_enc_level_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enc_level_row.custom_minimum_size.y = _small_row_height()
	text_col.add_child(_enc_level_row)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", LEVEL_PIP_GAP)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enc_level_row.add_child(pips)
	_threat_pips.clear()
	for i in THREAT_PIP_COUNT:
		var pip := ColorRect.new()
		pip.custom_minimum_size = LEVEL_PIP_SIZE
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
		_threat_pips.append(pip)
	_enc_level_label = _make_type_label("", PixelUI.TYPE_LABEL, PixelUI.CHROME)
	_enc_level_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_enc_level_row.add_child(_enc_level_label)
	# CLEARED / LOCKED: plain text after the level, no outline, compact
	# secondary text (m3x6).
	_enc_status_label = _make_type_label("", PixelUI.TYPE_COMPACT, PixelUI.CHROME_DIM)
	_enc_status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_enc_level_row.add_child(_enc_status_label)

	# The threats slot: the THREATS (compact secondary text, m3x6), or a locked
	# operation's unlock condition, in one fixed-height slot. Both wrap at
	# words; the slot reserves the most lines any operation needs at its real
	# width (_reserve_tags_slot), so switching missions moves nothing.
	_enc_tags_slot = Control.new()
	_enc_tags_slot.custom_minimum_size.y = _small_row_height()
	_enc_tags_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enc_tags_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(_enc_tags_slot)
	_enc_threats_label = _make_type_label("", PixelUI.TYPE_COMPACT, PixelUI.CHROME)
	_enc_threats_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_enc_threats_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_enc_threats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_enc_tags_slot.add_child(_enc_threats_label)
	_enc_unlock_label = _make_type_label("", PixelUI.TYPE_SMALL, PixelUI.CHROME_DIM)
	_enc_unlock_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_enc_unlock_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_enc_unlock_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_enc_tags_slot.add_child(_enc_unlock_label)
	_enc_tags_slot.resized.connect(_reserve_tags_slot)

	row.add_child(_make_nav_button(1))
	return row


func _make_nav_button(direction: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = NAV_BUTTON_SIZE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	# The selector uses the project arrow artwork, never a font-dependent < or >
	# glyph. The same left-chevron asset mirrors for the right control.
	button.text = ""
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, PixelUI.make_hard_style(PixelUI.DT_PANEL_BG, PixelUI.DT_FIELD_BORDER, PANEL_BORDER))
	var icon := TextureRect.new()
	icon.texture = PixelUI.tinted_icon(NAV_ARROW_ICON.resource_path, PixelUI.CHROME)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.flip_h = direction > 0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -NAV_ICON_SIZE * 0.5
	icon.offset_top = -NAV_ICON_SIZE * 0.5
	icon.offset_right = NAV_ICON_SIZE * 0.5
	icon.offset_bottom = NAV_ICON_SIZE * 0.5
	button.add_child(icon)
	button.pressed.connect(_on_nav_pressed.bind(direction))
	return button


func _build_dots() -> Control:
	_dot_row = HBoxContainer.new()
	_dot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_dot_row.add_theme_constant_override("separation", DOT_GAP)
	_dot_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in _operation_ids.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dot_row.add_child(dot)
		_dot_nodes.append(dot)
	return _dot_row


func _on_nav_pressed(direction: int) -> void:
	if _operation_ids.is_empty():
		return
	AudioManager.play_click()
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
	_current_op_locked = not SaveManager.is_operation_unlocked(_selected_operation_id)
	var accent: Color = _encounter_accent()

	var card_style: StyleBoxFlat = PixelUI.make_hard_style(PixelUI.UI_BG.lerp(accent, MISSION_TINT), accent, MISSION_FRAME)
	card_style.set_content_margin_all(float(MISSION_FRAME))
	_enc_card.add_theme_stylebox_override("panel", card_style)
	var frame_style: StyleBoxFlat = PixelUI.make_hard_style(PixelUI.DT_ENEMY_BG, accent, PANEL_BORDER)
	frame_style.set_content_margin_all(float(PANEL_BORDER))
	_enc_thumb_frame.add_theme_stylebox_override("panel", frame_style)

	_enc_name_label.text = op.display_name.to_upper()
	_enc_name_label.add_theme_color_override("font_color", accent)
	var boss_tex: Texture2D = _get_boss_portrait(op)
	PixelUI.set_portrait(_enc_portrait, boss_tex)
	_enc_portrait_placeholder.visible = boss_tex == null
	# Locked operations stay browsable: their own boss art is a dark silhouette
	# and the real operation name remains visible; the threats and DEPLOY wait.
	_enc_portrait.modulate = PixelUI.SILHOUETTE if _current_op_locked else Color.WHITE
	_enc_lock_overlay.visible = _current_op_locked

	var level: int = _threat_level(_operation_index)
	_enc_level_label.text = "LV %d" % level
	for i in _threat_pips.size():
		_threat_pips[i].color = accent if i < level else THREAT_EMPTY
	var status: String = "LOCKED" if _current_op_locked else _operation_progress_text(_selected_operation_id)
	_enc_status_label.text = status if status == "CLEARED" or status == "LOCKED" else ""
	_enc_status_label.add_theme_color_override("font_color", PixelUI.PLAYER_ACCENT_LIGHT if status == "CLEARED" else PixelUI.CHROME_DIM)

	_enc_unlock_label.visible = _current_op_locked
	_enc_threats_label.visible = not _current_op_locked
	_enc_unlock_label.text = unlock_condition_text(_selected_operation_id) if _current_op_locked else ""
	_enc_threats_label.text = "" if _current_op_locked else " · ".join(threat_tags(_selected_operation_id))

	for i in _dot_nodes.size():
		_dot_nodes[i].color = accent if i == _operation_index else PixelUI.DT_PROTO_EMPTY_BORDER
	_refresh_deploy()


## The operation's THREATS (existing briefing data, "SHIELDS · JAM · REBUILD"),
## one entry each.
static func threat_tags(op_id: String) -> Array[String]:
	var tags: Array[String] = []
	var threats: String = str(OPERATION_BRIEFING_OVERLAY.operation_copy(op_id).get("threats", ""))
	for part in threats.split("·", false):
		if part.strip_edges() != "":
			tags.append(part.strip_edges())
	return tags


# "Clear Hive Incursion to unlock": the operation chain opens each encounter
# with a boss clear of the one before it (SaveManager.OPERATION_CHAIN).
static func unlock_condition_text(op_id: String) -> String:
	var previous: String = SaveManager.operation_unlocked_by(op_id)
	var prev_op: OperationData = DataManager.get_operation(previous) as OperationData
	if prev_op == null:
		return ""
	return "Clear %s to unlock" % prev_op.display_name


# CLEARED / furthest battle reached / never entered, from the profile stats. The
# card shows CLEARED only (the mission card has no BEST line).
func _operation_progress_text(op_id: String) -> String:
	var stats: Dictionary = SaveManager.get_stats()
	var wins: Dictionary = stats.get("runs_won_by_op", {}) as Dictionary
	if int(wins.get(op_id, 0)) > 0:
		return "CLEARED"
	var best_by_op: Dictionary = stats.get("best_clear_by_op", {}) as Dictionary
	var best: int = int(best_by_op.get(op_id, 0))
	if best > 0:
		return "BEST: BATTLE %d" % best
	return ""


# Long-press on the card -> encounter InspectPopup (name, threat, and the full
# flavor paragraph). Locked operations reveal nothing.
func _on_banner_long_pressed(_global_position: Vector2) -> void:
	if _current_op_locked or _operation_ids.is_empty():
		return
	var op: OperationData = DataManager.get_operation(_selected_operation_id) as OperationData
	if op == null:
		return
	AudioManager.play_click()
	var payload: Dictionary = InspectResolver.resolve_encounter(op, _threat_level(_operation_index), THREAT_PIP_COUNT)
	InspectPopup.open(self, payload, _enc_card.get_global_rect(), _enc_card.get_instance_id())


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
	divider.color = PixelUI.UI_LINE
	divider.custom_minimum_size = Vector2(0, PixelUI.MIN_STROKE)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return divider


# ─── Squad grid ───────────────────────────────────────────────────────────────
func _build_squad_header() -> Control:
	var header: Control = _make_subheader_row("SQUAD")
	_counter_label = _make_subheader("0 / %d" % MAX_SELECTED_UNITS, PixelUI.CHROME)
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_add_subheader(header, _counter_label)
	return header


func _build_roster() -> Control:
	# Every base hero gets the same fixed-size cell. Locked cards keep their real
	# portrait silhouette.
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", TILE_GAP)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row: HBoxContainer = null
	var row_count: int = 0
	for unit_id in _unit_ids:
		var unit: UnitData = DataManager.get_unit(unit_id) as UnitData
		if unit == null:
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
	return rows


# Tile = portrait (the tap target) + name label UNDER it. A tap shows the unit in
# the info bar and toggles it in the squad; a long-press opens its inspect popup.
func _build_unit_tile(unit_id: String, unit: UnitData) -> Control:
	# Fixed-width cell: identical in full and partial rows; the row container
	# centers partial rows, so cells must not stretch.
	var cell := VBoxContainer.new()
	cell.add_theme_constant_override("separation", 8)
	cell.custom_minimum_size = Vector2(PORTRAIT_CELL, 0)
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	var long_press := LongPressInput.new()
	cell.add_child(long_press)
	long_press.tapped.connect(_on_tile_tapped.bind(unit_id))
	long_press.long_pressed.connect(_on_tile_long_pressed.bind(unit_id, cell))

	# The shared portrait frame: the battle card's window at tile width, with the
	# border inset outside it so the art sits INSIDE the frame, never over it.
	var frame_style: StyleBoxFlat = PixelUI.player_tile_style(false)
	frame_style.set_content_margin_all(float(PANEL_BORDER))
	var portrait_box: Dictionary = PixelUI.make_portrait_frame(unit.portrait, TILE_PORTRAIT_W, frame_style)
	var frame: PanelContainer = portrait_box["frame"]
	var crop: Control = portrait_box["crop"]
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.add_child(frame)
	var is_locked := not SaveManager.is_hero_unlocked(unit_id)
	var portrait: TextureRect = portrait_box["tex"] as TextureRect
	# Keep the hero's own composition, but reduce it to an unmistakably dark
	# silhouette until the profile owns that hero.
	portrait.modulate = PixelUI.SILHOUETTE if is_locked else Color.WHITE

	# Role-color corner badge (top-right) remains implemented for later roster
	# work, but beta presentation keeps it hidden through PixelUI's shared rule.
	var role_badge := ColorRect.new()
	role_badge.color = _role_color(unit)
	role_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	role_badge.offset_left = -ROLE_BADGE_SIZE - CHECK_INSET
	role_badge.offset_top = CHECK_INSET
	role_badge.offset_right = -CHECK_INSET
	role_badge.offset_bottom = CHECK_INSET + ROLE_BADGE_SIZE
	role_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	role_badge.visible = PixelUI.SHOW_BETA_UNIT_BADGES
	crop.add_child(role_badge)

	# Slot badge (top-left): filled player-color plate with the pick order (1/2/3).
	var slot_badge := PanelContainer.new()
	slot_badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
	slot_badge.offset_left = CHECK_INSET
	slot_badge.offset_top = CHECK_INSET
	slot_badge.custom_minimum_size = Vector2(SLOT_BADGE_SIZE, SLOT_BADGE_SIZE)
	slot_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_badge.add_theme_stylebox_override("panel", PixelUI.selection_badge_style())
	var slot_label := _make_pixel_label("", TILE_NAME_FONT, PixelUI.PLAYER_ACCENT_INK)
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot_badge.add_child(slot_label)
	slot_badge.visible = false
	crop.add_child(slot_badge)

	# Newly-unlocked heroes: a NEW badge until first added to a squad.
	var new_badge: Control = null
	if not is_locked and SaveManager.is_hero_new(unit_id):
		new_badge = _make_new_badge()
		crop.add_child(new_badge)
	if is_locked:
		crop.add_child(_make_lock_overlay())

	# Locked names remain blank, with their label height reserved.
	var tile_name: String = "" if is_locked else (unit.callsign if unit.callsign != "" else unit.display_name)
	var tile_font: int = PixelUI.FONT_INFO_MIN if is_locked else TILE_NAME_FONT
	# The name is not clipped: at 80 AVALANCHE (270 design px) is wider than the
	# 238 px cell. It sits in a holder the cell's width and grows out of it
	# evenly on both sides, into the tile gap / gutter, so the cell never widens.
	var name_holder := Control.new()
	name_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_holder.custom_minimum_size.y = ceilf(PixelUI.get_pixel_font().get_height(PixelUI.crisp_px(PixelUI.text_px(tile_font))))
	name_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_child(name_holder)
	var name_label := _make_pixel_label(tile_name.to_upper(), tile_font, PixelUI.UI_TEXT_DIM)
	name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_holder.add_child(name_label)

	_unit_tiles[unit_id] = {
		"frame": frame,
		"role_badge": role_badge,
		"name": name_label,
		"slot_badge": slot_badge,
		"slot_label": slot_label,
		"locked": is_locked,
		"new_badge": new_badge,
	}
	return cell


# The padlock glyph and explicit state centered over a locked silhouette.
func _make_lock_overlay() -> Control:
	var wrap := CenterContainer.new()
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 4)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(stack)
	var icon := TextureRect.new()
	icon.texture = PixelUI.tinted_icon(PixelUI.ICON_LOCK, PixelUI.CHROME_DIM)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(56, 56)
	icon.modulate = PixelUI.TEXT_MUTED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(icon)
	var label := _make_pixel_label("LOCKED", PixelUI.FONT_INFO_MIN, PixelUI.TEXT_MUTED)
	label.name = "LockedLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(label)
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


# A tap shows the unit in the info bar AND toggles it in or out of the squad.
# Locked units only show (their unlock condition). With the squad full, a bench
# tap only shows the unit and says how to make room.
func _on_tile_tapped(unit_id: String) -> void:
	_focus_unit_id = unit_id
	_squad_full_hint = false
	if not SaveManager.is_hero_unlocked(unit_id):
		AudioManager.play_click()
	elif not _selected_unit_ids.has(unit_id) and _selected_unit_ids.size() >= MAX_SELECTED_UNITS:
		AudioManager.play_click()
		_squad_full_hint = true
	else:
		_toggle_unit_selection(unit_id)
	_refresh_unit_tiles()
	_refresh_squad_counter()
	_refresh_info()
	_refresh_deploy()


func _on_tile_long_pressed(_global_position: Vector2, unit_id: String, anchor: Control) -> void:
	# Locked units reveal nothing beyond the info bar's unlock condition.
	if not SaveManager.is_hero_unlocked(unit_id):
		return
	var unit := DataManager.get_unit(unit_id) as UnitData
	if unit == null:
		return
	AudioManager.play_click()
	var anchor_rect: Rect2 = anchor.get_global_rect() if is_instance_valid(anchor) else Rect2()
	InspectPopup.open(self, unit_inspect_payload(unit), anchor_rect, anchor.get_instance_id())


# The unit's inspect popup on squad select: its kit plus the picker blurb.
static func unit_inspect_payload(unit: UnitData) -> Dictionary:
	var payload: Dictionary = InspectResolver.resolve_unit(unit)
	if unit.picker_blurb.strip_edges() != "":
		payload["description"] = unit.picker_blurb.strip_edges()
	return payload


func _toggle_unit_selection(unit_id: String) -> void:
	if _selected_unit_ids.has(unit_id):
		AudioManager.play_select()
		_selected_unit_ids.erase(unit_id)
		return
	if _selected_unit_ids.size() >= MAX_SELECTED_UNITS:
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
		# Keep the border-width content margin so the portrait stays INSIDE the frame.
		# The info bar's unit: its own border in bone (over a pick's cobalt; the
		# 1-3 badge and the name still mark the pick).
		var frame_style: StyleBoxFlat = PixelUI.player_tile_style(is_selected, unit_id == _focus_unit_id)
		frame_style.set_content_margin_all(float(PANEL_BORDER))
		frame.add_theme_stylebox_override("panel", frame_style)
		name_label.add_theme_color_override("font_color", PixelUI.PLAYER_ACCENT_LIGHT if is_selected else PixelUI.UI_TEXT_DIM)
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
		# Right-aligned: its text origin moves with the text, so re-snap it.
		PixelUI.set_block_ink_snap(_counter_label)


# Compatibility aliases for the established screen contract (flow smoke test,
# captures).
func _refresh_unit_thumbs() -> void:
	_refresh_unit_tiles()


func _refresh_begin_button() -> void:
	_refresh_deploy()


func _refresh_detail() -> void:
	_refresh_info()


func _show_unit_detail(unit_id: String) -> void:
	_focus_unit_id = unit_id
	_refresh_unit_tiles()
	_refresh_info()


func _on_back_to_title() -> void:
	AudioManager.play_click()
	SceneManager.go_to_main_menu()


# The selected operation's ENCOUNTER accent (data), for the enemy-side preview.
func _encounter_accent() -> Color:
	var accent: Color = DEPTH.encounter_accent(_selected_operation_id)
	return accent if accent.a > 0.0 else PixelUI.DT_ENEMY_BORDER


# Maps a unit's focus to a DT accent color for its (hidden) badge.
func _role_color(unit: UnitData) -> Color:
	match unit.picker_category.to_lower():
		"damage", "offense", "offence":
			return PixelUI.DT_RUST
		"defense", "defence":
			return PixelUI.DT_CYAN
		"support":
			return PixelUI.RARITY_RARE   # violet
		"control":
			return PixelUI.DT_AMBER
	return PixelUI.TEXT_MUTED


# ─── Unit info bar ────────────────────────────────────────────────────────────
func _build_info_region() -> Control:
	var region := Control.new()
	region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_toggle = Button.new()
	_info_toggle.text = "SHOW UNIT INFO  +"
	_info_toggle.focus_mode = Control.FOCUS_NONE
	_info_toggle.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_info_toggle.offset_bottom = INFO_TOGGLE_HEIGHT
	PixelUI.style_ui_secondary_button(_info_toggle, PixelUI.type_px(PixelUI.TYPE_LABEL))
	_info_toggle.pressed.connect(_toggle_info)
	region.add_child(_info_toggle)
	_info_bar = _build_info_bar()
	_info_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_info_bar.offset_top = INFO_TOGGLE_HEIGHT + GAP
	_info_bar.offset_bottom = _info_bar.offset_top + _info_bar.get_combined_minimum_size().y
	_info_bar.visible = false
	region.add_child(_info_bar)
	# The reservation is permanent. Expanding only paints into it, so the VBox
	# distributing the screen cannot move Deploy or any later block. It is
	# measured at the region's real width (_reserve_info_region): the bar is
	# hidden until toggled, and a hidden container never lays its children out.
	region.custom_minimum_size.y = _info_bar.offset_bottom
	region.resized.connect(_reserve_info_region)
	return region


# The tallest the threats slot needs: every operation's threats (m3x6) and
# unlock condition, wrapped at the slot's width.
func _reserve_tags_slot() -> void:
	var width: float = _enc_tags_slot.size.x
	if width < 1.0:
		return
	var height: float = _small_row_height()
	for op_id: String in _operation_ids:
		height = maxf(height, PixelUI.wrapped_text_height(_enc_threats_label, " · ".join(threat_tags(op_id)), width))
		height = maxf(height, PixelUI.wrapped_text_height(_enc_unlock_label, unlock_condition_text(op_id), width))
	if not is_equal_approx(_enc_tags_slot.custom_minimum_size.y, height):
		_enc_tags_slot.custom_minimum_size.y = height
		_distribute_gaps.call_deferred()


# The info bar's text width at the region's width.
func _info_text_width() -> float:
	return _info_region.size.x - 2.0 * float(PANEL_BORDER + INFO_PAD)


# A unit's description and its unlock condition: what the bar's description
# row can show for it.
func _info_blurb_texts(unit_id: String) -> Array[String]:
	var texts: Array[String] = [SaveManager.hero_unlock_condition(unit_id)]
	var unit: UnitData = DataManager.get_unit(unit_id) as UnitData
	if unit != null:
		texts.append(unit.blurb if unit.blurb != "" else unit.picker_blurb)
	return texts


# The region reserves the expanded bar's tallest form: every row at its fixed
# height plus the longest description wrapped at the real width. The bar itself
# stays as tall as what it shows (_fit_info_blurb).
func _reserve_info_region() -> void:
	var width: float = _info_text_width()
	if width < 1.0:
		return
	var blurb_h: float = 0.0
	for unit_id: String in _unit_ids:
		for text: String in _info_blurb_texts(unit_id):
			blurb_h = maxf(blurb_h, _info_blurb_height(text, width))
	var fixed: float = 2.0 * float(PANEL_BORDER + INFO_PAD) + 3.0 * float(INFO_ROW_GAP)
	for row: Control in [_info_top, _info_strip, _info_hint]:
		fixed += row.get_combined_minimum_size().y
	var bottom: float = _info_bar.offset_top + fixed + blurb_h
	if not is_equal_approx(_info_region.custom_minimum_size.y, bottom):
		_info_region.custom_minimum_size.y = bottom
		_distribute_gaps.call_deferred()
	_fit_info_blurb()


# One description's height in the bar, at most INFO_BLURB_LINES lines.
func _info_blurb_height(text: String, width: float) -> float:
	var font: Font = _info_blurb.get_theme_font("font")
	var size: int = PixelUI.drawn_font_px(_info_blurb)
	var lines: int = clampi(PixelUI.wrapped_line_count(text, font, size, width), 1, INFO_BLURB_LINES)
	var spacing := float(_info_blurb.get_theme_constant("line_spacing"))
	return ceilf(lines * (font.get_height(size) + spacing) - spacing)


# The shown description's row: as tall as its own lines at the real width; the
# bar (anchored at its top, no height of its own) follows its content.
func _fit_info_blurb() -> void:
	if _info_blurb == null or _info_region == null:
		return
	var width: float = _info_text_width()
	if width < 1.0:
		return
	_info_blurb.custom_minimum_size.y = _info_blurb_height(_info_blurb.text, width)
	_info_bar.offset_bottom = _info_bar.offset_top


func _toggle_info() -> void:
	_info_bar.visible = not _info_bar.visible
	_info_toggle.text = "HIDE UNIT INFO  -" if _info_bar.visible else "SHOW UNIT INFO  +"


func _build_info_bar() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = PixelUI.make_hard_style(PixelUI.UI_PANEL, PixelUI.PLAYER_ACCENT, PANEL_BORDER)
	style.set_content_margin_all(float(PANEL_BORDER + INFO_PAD))
	panel.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", INFO_ROW_GAP)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", GAP)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	_info_top = top
	_info_name = _make_type_label("", PixelUI.TYPE_LABEL, PixelUI.PLAYER_ACCENT_LIGHT)
	_info_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_name.clip_text = true
	top.add_child(_info_name)
	_info_hp = _make_type_label("", PixelUI.TYPE_SMALL, PixelUI.CHROME)
	_info_hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_info_hp)
	_info_status = _make_type_label("", PixelUI.TYPE_SMALL, PixelUI.CHROME_DIM)
	_info_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_info_status)

	# The description: compact secondary text (m3x6), wrapped at words onto
	# up to INFO_BLURB_LINES lines. Its row is sized by measure at the bar's
	# real width (_fit_info_blurb); clip_text keeps the Label's own minimum
	# (shaped at whatever width it last had) out of it.
	_info_blurb = _make_type_label("", PixelUI.TYPE_COMPACT, PixelUI.CHROME)
	_info_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
	_info_blurb.max_lines_visible = INFO_BLURB_LINES
	_info_blurb.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
	_info_blurb.clip_text = true
	_info_blurb.custom_minimum_size.y = ceilf(PixelUI.get_compact_font().get_height(PixelUI.COMPACT_PX))
	col.add_child(_info_blurb)

	# The roll band bar and its glyph row, drawn in one control on the art grid.
	_info_strip = Control.new()
	_info_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_strip.custom_minimum_size = Vector2(0, BAND_BAR_H + BAND_ICON_GAP + BAND_ICON)
	# The pip icons draw NEAREST, as on the battle cards.
	_info_strip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_info_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_strip.draw.connect(_draw_band_strip)
	col.add_child(_info_strip)

	_info_hint = _make_type_label(HINT_TEXT, PixelUI.TYPE_SMALL, PixelUI.CHROME_DIM)
	col.add_child(_info_hint)
	return panel


func _refresh_info() -> void:
	if _info_bar == null:
		return
	var unit: UnitData = DataManager.get_unit(_focus_unit_id) as UnitData
	var locked: bool = unit == null or not SaveManager.is_hero_unlocked(_focus_unit_id)
	if unit == null:
		_info_name.text = ""
		_info_hp.text = ""
		_info_status.text = ""
		_info_blurb.text = ""
	elif locked:
		# Locked heroes keep their names hidden (G-16); the unlock condition
		# stands in for the description, and there is no band bar.
		_info_name.text = "???"
		_info_name.add_theme_color_override("font_color", PixelUI.CHROME_DIM)
		_info_hp.text = ""
		_info_status.text = "LOCKED"
		_info_status.add_theme_color_override("font_color", PixelUI.CHROME_DIM)
		_info_blurb.text = SaveManager.hero_unlock_condition(_focus_unit_id)
		_info_blurb.add_theme_color_override("font_color", PixelUI.CHROME_DIM)
	else:
		var in_squad: bool = _selected_unit_ids.has(_focus_unit_id)
		_info_name.text = unit.battle_name().to_upper()
		_info_name.add_theme_color_override("font_color", PixelUI.PLAYER_ACCENT_LIGHT)
		_info_hp.text = "HP %d" % unit.max_hp
		_info_status.text = "IN SQUAD" if in_squad else "ON BENCH"
		_info_status.add_theme_color_override("font_color", PixelUI.PLAYER_ACCENT_LIGHT if in_squad else PixelUI.CHROME_DIM)
		_info_blurb.text = unit.blurb if unit.blurb != "" else unit.picker_blurb
		_info_blurb.add_theme_color_override("font_color", PixelUI.CHROME)
	_info_hint.text = SQUAD_FULL_TEXT if _squad_full_hint else HINT_TEXT
	_info_hint.add_theme_color_override("font_color", PixelUI.WARNING if _squad_full_hint else PixelUI.CHROME_DIM)
	_info_strip.queue_redraw()
	_fit_info_blurb()


## One roll band's primary effect type (Kev, 2026-10-17, G-87), from its raw
## ability data: "attack" (damage), "shield" or "heal", the largest of its
## damage / shield / heal amounts (a tie goes to heal, then shield); otherwise
## "utility" when the ability does anything else (mark, burn, freeze, jam,
## taunt, cloak, Protocol gain, roll changes ...); "" only for no ability.
static func band_effect(raw: Dictionary) -> String:
	var amounts: Dictionary = {"heal": int(raw.get("heal", 0)), "shield": int(raw.get("shield", 0)), "attack": int(raw.get("dmg", 0))}
	var best: String = ""
	var best_amount: int = 0
	for key: String in ["heal", "shield", "attack"]:
		if int(amounts[key]) > best_amount:
			best = key
			best_amount = int(amounts[key])
	if best != "":
		return best
	for key: String in raw.keys():
		if key not in BAND_INERT_KEYS and key not in ["dmg", "heal", "shield"] and _raw_on(raw.get(key)):
			return "utility"
	return ""


## The pip key of a band's icon: damage / shield / heal for those types; for a
## UTILITY band the ability's own status icon (UTILITY_ICON_KEYS), or "spark"
## when it has none; "" for no ability.
static func band_icon(raw: Dictionary, effect: String) -> String:
	match effect:
		"attack":
			return "damage"
		"shield", "heal":
			return effect
		"utility":
			for pair: Array in UTILITY_ICON_KEYS:
				if _raw_on(raw.get(pair[0])):
					return str(pair[1])
			return "spark"
	return ""


# An ability field that does something: true, a positive number, a non-empty value.
static func _raw_on(value: Variant) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return float(value) > 0.0
	return value != null and str(value) != ""


## The band bar's segments for a unit across `width_art` art px: one per roll
## window, in roll order, sized by the window's share of 1-20 (whole art px,
## largest remainder), 1 art px apart. Each: {x, w (art px), min, max, effect,
## icon, ability}.
static func band_layout(unit: UnitData, width_art: int) -> Array[Dictionary]:
	var ranges: Array = unit.dice_ranges.duplicate()
	ranges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("min", 0)) < int(b.get("min", 0)))
	var out: Array[Dictionary] = []
	if ranges.is_empty():
		return out
	var free: int = width_art - (ranges.size() - 1)
	var total: int = 0
	for entry: Dictionary in ranges:
		total += int(entry.get("max", 0)) - int(entry.get("min", 0)) + 1
	var widths: Array[int] = []
	var remainders: Array[float] = []
	var used: int = 0
	for entry: Dictionary in ranges:
		var share: float = float(free) * float(int(entry.get("max", 0)) - int(entry.get("min", 0)) + 1) / float(maxi(total, 1))
		widths.append(int(floorf(share)))
		remainders.append(share - floorf(share))
		used += int(floorf(share))
	while used < free:
		var best: int = remainders.find(remainders.max())
		widths[best] += 1
		remainders[best] = -1.0
		used += 1
	var x: int = 0
	for i in ranges.size():
		var entry: Dictionary = ranges[i]
		var raw: Dictionary = entry.get("raw", {}) as Dictionary
		var effect: String = band_effect(raw)
		out.append({"x": x, "w": widths[i], "min": int(entry.get("min", 0)), "max": int(entry.get("max", 0)),
			"effect": effect, "icon": band_icon(raw, effect), "ability": str(entry.get("ability_name", ""))})
		x += widths[i] + 1
	return out


## A segment's fill (G-87, G-88): the damage red, the effect-pip shield blue
## (PIP_BORDERS shield, 6ba8e0: the battle cards' shield pip border; the status
## chip's 3fd0e2 sat too close to the Protocol cyan), the heal green, the lit
## utility gray; a band with no ability is the empty track.
static func band_color(effect: String) -> Color:
	match effect:
		"attack":
			return PixelUI.KW_DAMAGE
		"shield":
			return Color(PixelUI.PIP_BORDERS["shield"], 1.0)
		"heal":
			return PixelUI.KW_HEAL
		"utility":
			return PixelUI.UTILITY_SEGMENT
	return PixelUI.UI_ROW


func _draw_band_strip() -> void:
	var unit: UnitData = DataManager.get_unit(_focus_unit_id) as UnitData
	if unit == null or not SaveManager.is_hero_unlocked(_focus_unit_id):
		return
	var icon_top: float = BAND_BAR_H + BAND_ICON_GAP
	for band: Dictionary in band_layout(unit, int(_info_strip.size.x / ART_PX)):
		var x: float = float(band["x"]) * ART_PX
		var w: float = float(band["w"]) * ART_PX
		_info_strip.draw_rect(Rect2(x, 0.0, w, BAND_BAR_H), band_color(band["effect"]))
		var icon: String = band["icon"]
		if icon == "":
			continue
		# Centred under the segment, on the art grid.
		var icon_x: float = (float(band["x"]) + floorf((float(int(band["w"])) - float(BAND_ICON) / float(ART_PX)) * 0.5)) * ART_PX
		if icon == "spark":
			var spark_x: float = icon_x + float(BAND_ICON - BAND_SPARK.size() * ART_PX) * 0.5
			var spark_y: float = icon_top + float(BAND_ICON - BAND_SPARK.size() * ART_PX) * 0.5
			for gy in BAND_SPARK.size():
				for gx in BAND_SPARK[gy].length():
					if BAND_SPARK[gy][gx] == "#":
						_info_strip.draw_rect(Rect2(spark_x + gx * ART_PX, spark_y + gy * ART_PX, ART_PX, ART_PX), PixelUI.CHROME)
			continue
		var texture: Texture2D = PixelUI.pip_texture_for_key(icon)
		if texture == null:
			continue
		# The pip's own colours, as the battle readout draws it (roll_up and
		# cleanse carry their shared-glyph tint), in the info bar's lighter
		# variant on the art grid (G-88).
		var variant: Array = _band_icon_variant(icon, texture)
		if variant.is_empty():
			continue
		var fit: Vector2 = (variant[0] as Texture2D).get_size() * ART_PX
		var at := Vector2(icon_x, icon_top) + (((Vector2(BAND_ICON, BAND_ICON) - fit) * 0.5) / ART_PX).floor() * ART_PX
		_info_strip.draw_texture_rect(variant[0], Rect2(at, fit.round()), false, PixelUI.pip_tint_for_key(icon))


static var _band_icon_cache: Dictionary = {}

## A pip icon's info bar variant, cached per key. Pixels under
## BAND_ICON_ALPHA_FLOOR drop out,
## the rest go opaque with their HSV value raised to BAND_ICON_VALUE_FLOOR. The
## variant is BAND_ICON / ART_PX texels on its long side, drawn one texel per
## art px.
static func _band_icon_variant(key: String, texture: Texture2D) -> Array:
	if _band_icon_cache.has(key):
		return _band_icon_cache[key]
	var img: Image = texture.get_image()
	if img == null:
		return []
	img = img.duplicate()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	# Averaged down to the icon's art px (12 on its long side) first, weighted
	# by alpha so the faint art keeps its shape and hue instead of
	# nearest-sampling to scattered texels.
	var src: Image = img.get_region(img.get_used_rect())
	var k: float = (float(BAND_ICON) / float(ART_PX)) / float(maxi(src.get_width(), src.get_height()))
	var tw: int = maxi(1, roundi(src.get_width() * k))
	var th: int = maxi(1, roundi(src.get_height() * k))
	img = Image.create(tw, th, false, Image.FORMAT_RGBA8)
	for ty in th:
		for tx in tw:
			var x0: int = floori(float(tx) * src.get_width() / tw)
			var x1: int = maxi(x0 + 1, floori(float(tx + 1) * src.get_width() / tw))
			var y0: int = floori(float(ty) * src.get_height() / th)
			var y1: int = maxi(y0 + 1, floori(float(ty + 1) * src.get_height() / th))
			var rgb := Vector3.ZERO
			var alpha := 0.0
			for y in range(y0, y1):
				for x in range(x0, x1):
					var c: Color = src.get_pixel(x, y)
					rgb += Vector3(c.r, c.g, c.b) * c.a
					alpha += c.a
			var coverage: float = alpha / float((x1 - x0) * (y1 - y0))
			if coverage < BAND_ICON_ALPHA_FLOOR or alpha <= 0.0:
				continue
			var avg: Vector3 = rgb / alpha
			var c2 := Color(avg.x, avg.y, avg.z)
			img.set_pixel(tx, ty, Color.from_hsv(c2.h, c2.s, maxf(c2.v, BAND_ICON_VALUE_FLOOR), 1.0))
	var out: Array = [ImageTexture.create_from_image(img)]
	_band_icon_cache[key] = out
	return out


# ─── DEPLOY ───────────────────────────────────────────────────────────────────
func _build_deploy_button() -> Control:
	_deploy_panel = PanelContainer.new()
	_deploy_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# A holder only (the theme's default Panel style drew a thin dark ring).
	_deploy_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	_deploy_button = Button.new()
	_deploy_button.focus_mode = Control.FOCUS_NONE
	# Constant height: both states render at DEPLOY_BUTTON_HEIGHT, so arming
	# never resizes the button or shifts the cluster.
	_deploy_button.custom_minimum_size = Vector2(0, DEPLOY_BUTTON_HEIGHT)
	_deploy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deploy_button.text = "PICK %d MORE" % MAX_SELECTED_UNITS
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
		_deploy_button.text = "DEPLOY SQUAD"
		PixelUI.style_ui_primary_button(_deploy_button, DEPLOY_FONT)
		_deploy_button.disabled = false
		_deploy_button.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		# The disabled button states its own gate: picks still missing, or a
		# locked operation (which blocks deploy even with a full squad).
		if units_ready and not op_unlocked:
			_deploy_button.text = "OPERATION LOCKED"
		else:
			_deploy_button.text = "PICK %d MORE" % (MAX_SELECTED_UNITS - _selected_unit_ids.size())
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
		GameState.reward_picked.emit("starting_relic", SaveManager.get_unlocked_boss_relics(), directive_relic_id)
	GameState.advance_to_next_battle()
	SceneManager.go_to_battle()


# ─── Starting Directive picker ───────────────────────────────────────────────
const DIRECTIVE_ROW_MIN_H := 232.0
const DIRECTIVE_ROW_PAD_Y := 48.0
var _directive_layer: Control


func _open_directive_picker(relic_ids: Array) -> void:
	if _directive_layer != null and is_instance_valid(_directive_layer):
		return
	_directive_layer = Control.new()
	_directive_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_directive_layer)
	# The picker opens the run (it has no cancel): the in-operation header for
	# the operation about to start, at its first battle (ui-cleanup).
	var operation: OperationData = DataManager.get_operation(_selected_operation_id) as OperationData
	if operation != null:
		PersistentHeader.show_operation(_selected_operation_id, 1, operation.battles.size())

	var dim := ColorRect.new()
	dim.color = PixelUI.SCRIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_directive_layer.add_child(dim)

	var panel := PanelContainer.new()
	# Component: Modal, CHROME (ui-unify; the rows are the choices).
	panel.add_theme_stylebox_override("panel", PixelUI.component_style(PixelUI.COMPONENT_MODAL))
	panel.custom_minimum_size = Vector2(920, 0)
	_directive_layer.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 36)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 32)
	margin.add_child(col)

	var picker_title := _make_pixel_label("STARTING DIRECTIVE", DETAIL_NAME_FONT, PixelUI.CHROME)
	PixelUI.apply_type(picker_title, PixelUI.TYPE_LABEL)
	col.add_child(picker_title)
	var blurb := _make_pixel_label("Open the run with a trophy from a fallen boss.", DETAIL_DESC_FONT, PixelUI.CHROME)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
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
		# Directive picks are deliberately closer to the ceremonial mid-run relic
		# cards: generous, equal-sized choices with readable art and rules.
		pick.custom_minimum_size = Vector2(0, DIRECTIVE_ROW_MIN_H)
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# ui-cleanup: the shared secondary button (equal choices; was the legacy
		# style_button shape). The icon and rule ride the row inside it.
		PixelUI.style_ui_secondary_button(pick, FOCUS_CHIP_FONT)
		pick.pressed.connect(_on_directive_picked.bind(relic_id))
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 28.0
		row.offset_right = -28.0
		row.add_theme_constant_override("separation", 28)
		pick.add_child(row)
		if relic.icon != null:
			var icon: Control = PixelUI.make_integer_icon(relic.icon, DIRECTIVE_ICON_BOX)
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(icon)
		var text_label := _make_pixel_label("%s - %s" % [relic.display_name.to_upper(), relic.description], DETAIL_DESC_FONT, PixelUI.UI_TEXT)
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		text_label.add_theme_constant_override("line_spacing", PixelUI.BODY_LINE_SPACING)
		text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(text_label)
		# ui-cleanup: a longer rule (Heretic Signal, Tectonic Charge) grows its
		# row instead of clipping; the row never changes the label's width.
		text_label.resized.connect(func() -> void:
			pick.custom_minimum_size.y = maxf(DIRECTIVE_ROW_MIN_H, text_label.size.y + DIRECTIVE_ROW_PAD_Y))
		col.add_child(pick)

	var skip := Button.new()
	skip.focus_mode = Control.FOCUS_NONE
	skip.custom_minimum_size = Vector2(0, 96)
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skip.text = "NO DIRECTIVE"
	PixelUI.style_ui_secondary_button(skip, FOCUS_CHIP_FONT)
	skip.pressed.connect(_on_directive_picked.bind(""))
	col.add_child(skip)

	# Center the panel once it has a size.
	await get_tree().process_frame
	if is_instance_valid(panel):
		panel.position = Vector2(PixelUI.even_px((size.x - panel.size.x) * 0.5), PixelUI.even_px((size.y - panel.size.y) * 0.5))


func _on_directive_picked(relic_id: String) -> void:
	AudioManager.play_select()
	if _directive_layer != null and is_instance_valid(_directive_layer):
		_directive_layer.queue_free()
		_directive_layer = null
	_launch_run(relic_id)


# ─── Helpers ──────────────────────────────────────────────────────────────────
func _make_pixel_label(text: String, size_logical: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", PixelUI.get_pixel_font())
	label.add_theme_font_size_override("font_size", PixelUI.text_px(size_logical))
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
