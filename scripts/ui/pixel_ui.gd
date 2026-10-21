class_name PixelUI
extends RefCounted

const PORTRAIT_WIDTH := 1080.0


static func cap_portrait_width(content: Control, enabled: bool = true, max_width: float = PORTRAIT_WIDTH) -> void:
	var cap := load("res://scripts/ui/portrait_column.gd").new() as Node
	cap.name = "PortraitWidthCap"
	cap.set("enabled", enabled)
	cap.set("max_width", max_width)
	content.add_child(cap)


const BG_PANEL := Color(0.050, 0.055, 0.078, 1.0)
const BG_PANEL_ALT := Color(0.075, 0.085, 0.120, 1.0)
const LINE_DIM := Color(0.18, 0.23, 0.34, 1.0)
const LINE_BRIGHT := Color(0.36, 0.55, 0.78, 1.0)
const TEXT_PRIMARY := Color(0.88, 0.91, 0.88, 1.0)
const TEXT_MUTED := Color(0.52, 0.60, 0.70, 1.0)
const HERO_ACCENT := Color(0.20, 0.66, 0.50, 1.0)
const ENEMY_ACCENT := Color(0.74, 0.28, 0.23, 1.0)
const GOLD_ACCENT := Color(0.82, 0.58, 0.24, 1.0)
# Cleanse pip tint (Build I, Kev ruling): the heal glyph tinted GOLDEN. This is
# a PIP-level color ONLY — the amber-gold CHROME reserve (reward/ceremonial
# borders) is NOT implicated. Do not "correct" this token into a chrome role.
const COLOR_CLEANSE_PIP := Color(0.92, 0.76, 0.32, 1.0)
const BLACK_EDGE := Color(0.005, 0.006, 0.010, 1.0)
# Restrained battle palette; other screens retain their existing DT colors.
const BATTLE_FIELD := Color("0c1012")
const BATTLE_PANEL := Color("10161a")
const BATTLE_BORDER := Color("35424a")
const BATTLE_HERO_LINE := Color("405563")
const BATTLE_ENEMY_LINE := Color("694334")
const BATTLE_HERO_TEXT := Color("a5c7d9")
const BATTLE_ENEMY_TEXT := Color("cd9274")
const BATTLE_TEXT := Color("eceee5")
const BATTLE_HP_TRACK := Color("101714")
const BATTLE_HP_FILL := Color("4a783f")
const BATTLE_HP_INK := Color("ffffff")
const BATTLE_PROTO_EMPTY := Color("181e21")
const BATTLE_PANEL_FILL := Color("11191e")
const BATTLE_INNER_EDGE := Color("06090b")
const BATTLE_TRAY_FILL := Color("11171b")
# Battle depth prototype v3: the full-screen battle scene, warm charcoal and kept
# dark so cards and dice carry the contrast (docs/BATTLE_DEPTH_PROTOTYPE.md).
# Per-operation textures and accent tokens come from data/raw/battle-tray-scenes.json.
const BATTLE_BAY_VOID := Color("0a0a0b")
const BATTLE_BAY_FLOOR := Color("201f1d")
const BATTLE_BAY_WALL := Color("141415")
const BATTLE_BAY_WALL_BACK := Color("171718")
const BATTLE_BAY_SEAM := Color("0e0e0f")
const BATTLE_BAY_LEDGE := Color("252524")
const BATTLE_BAY_AMBER := Color("685035")
const BATTLE_BAY_AMBER_LIT := Color("9a7038")
const BATTLE_BAY_WINDOW_FRAME := Color("221a14")
const BATTLE_BAY_RUST := Color("4e2817")
const BATTLE_BAY_RUST_LIT := Color("7a3d1f")
const BATTLE_HEADER_RULE := Color("3a454c")
const BATTLE_BAY_SHADOW_ALPHA := 0.85
# Flat pixel A: the hard pixel drop shadow under each die (dice_tray_3d.gd).
const BATTLE_FLAT_SHADOW := Color("040506")
# The vignette: hard-edged steps of black, darkest first (no smooth ramp).
const BATTLE_VIGNETTE_STEPS: Array[float] = [0.42, 0.26, 0.12]
# Die tags: transparent over the scene (2026-07-09 ruling); F8 brings the v2
# plate back for A/B. Icons get a hard dark pixel outline instead.
const BATTLE_TAG_PLATE := Color("06090b")
const BATTLE_TAG_OUTLINE := Color("050506")
const BATTLE_TAG_OUTLINE_PX := 4
# The draw-time projection (scripts/ui/battle_depth.gd reads these). Die scale at
# the tray's back and front edge; the floor's width at the back edge as a share
# of the front; how far the back edge is pushed down; where the back wall ends.
# The last two are shares of the tray height.
const BATTLE_DEPTH_BACK := 0.75
const BATTLE_DEPTH_FRONT := 1.12
const BATTLE_DEPTH_TAPER := 0.80
const BATTLE_DEPTH_PUSH := 0.03
const BATTLE_DEPTH_WALL := 0.155
const BATTLE_PORTRAIT_FIELD := Color("080b0e")
const BATTLE_HERO_HEADER := Color("172127")
const BATTLE_ENEMY_HEADER := Color("211713")
const BATTLE_SHELL_WIDTH := 8
const BATTLE_INSET_WIDTH := 4
static var _battle_panel_textures: Dictionary = {}
static var _battle_pixel_font: Font = null
const BATTLE_SKIN_PATH := "res://assets/ui/battle_skin/"
const COLOR_DAMAGE := Color(0.96, 0.22, 0.18, 1.0)
const COLOR_HEAL := Color(0.28, 0.90, 0.46, 1.0)
const COLOR_SHIELD := Color(0.34, 0.66, 1.0, 1.0)
const COLOR_DEBUFF := Color(0.72, 0.34, 0.95, 1.0)
# Burn is FIRE now (Kev 2026-07-10) — ember orange, not the old poison purple.
const COLOR_BURN := Color(0.95, 0.58, 0.22, 1.0)
const COLOR_ROLL := Color(0.96, 0.76, 0.24, 1.0)

# ── Font-size floors (UI review S-1, Kev-approved 2026-07-10) ──
# Nominal m5x7 sizes in the 1080×2400 design space. INFO = text a player needs to
# read to play correctly (legends, costs, rarity lines, ability effect rows,
# stats, help body). ACCENT = decorative/eyebrow labels that may stay smaller.
# New screens should not hand-roll label sizes below these.
const FONT_INFO_MIN := 36
const FONT_ACCENT_MIN := 28

# ── Rendered text floor (text legibility Step 1, audit F3 / O2) ──
# No pixel-font text RENDERS below 48 design px, whatever path built it: the
# nominal floors above are pre-scale_font_size values, while this is the size
# that actually reaches the font. 48 keeps one m5x7 pixel (native em 16) ≥ one
# screen pixel down to a stretch scale of 1/3 — every desktop web case the audit
# measured. scale_font_size floors here; raw-px factories (home picker, battle
# card, pips, readouts, run end, unlock) route their size through text_px().
# The ONE deliberate exception is the pip duration superscript (EffectPip) —
# its smaller size IS its meaning. theme_overload.tres `default_font_size`
# MIRRORS this value (unstyled Label.new() nodes); the regression gates the copy.
# Regression: scripts/debug/text_legibility_test.gd.
const TEXT_MIN_PX := 48


static func text_px(font_size: int) -> int:
	return lattice_px(maxi(font_size, TEXT_MIN_PX))


# ── Crisp text sizes (crisp text steps 1-2, Kev 2026-10-19: PREVIEW) ──
# The itch embed is always 640x960, a stretch scale of 0.4. m5x7 and Battle
# Block both draw one font pixel as size / 16 design px, so only 40, 80 and 120
# put a font pixel on a whole number of screen px there (1, 2, 3). Every size
# that reaches a font is one of them. The sizing code above still computes the
# old sizes (so boxes measured from them keep their size); one hook maps the
# size each text node is given (apply_text_filter -> _crisp_apply) and Battle
# Block maps in bind_block_snap. Old 48 / 64 / 80 -> 80, 96 -> 120; any other
# size goes to the nearest of the three, a tie going up. Text marked with
# mark_small_text (version stamp, Protocol cost badges, the effect-pip duration
# superscript) draws at 40.
const CRISP_SIZES := [40, 80, 120]
const CRISP_MAP := {48: 80, 64: 80, 80: 80, 96: 120}
const CRISP_SMALL := 40
## Preview: m5x7 is never drawn by the per-label exact-pixel snap
## (bind_m5x7_snap); G-78 / G-86's rule is superseded.
const M5X7_EXACT_SNAP := false


## The crisp size for an old text size (design px).
static func crisp_px(px: int) -> int:
	if CRISP_MAP.has(px):
		return int(CRISP_MAP[px])
	var best: int = CRISP_SIZES[0]
	for size: int in CRISP_SIZES:
		if absi(size - px) <= absi(best - px):
			best = size
	return best


## m5x7's raster scale (FontFile.oversampling), see get_pixel_font.
const CRISP_FONT_OVERSAMPLING := 2.0


## The few texts that stay small (40): call once the label exists.
static func mark_small_text(control: Control) -> void:
	control.set_meta("crisp_small", true)
	_crisp_apply(control)


const _CRISP_SIZE_NAMES := ["font_size", "normal_font_size", "bold_font_size",
	"italics_font_size", "bold_italics_font_size", "mono_font_size"]


static func _crisp_bind(control: Control) -> void:
	if not control.has_meta("crisp_bound"):
		control.set_meta("crisp_bound", true)
		control.theme_changed.connect(_crisp_apply.bind(control))
	_crisp_apply(control)


## Maps the node's font size overrides. The hook remembers the size it was
## given and the size it wrote: its own write (which fires theme_changed
## again) maps from the remembered size, so a later mark_small_text still
## sees the old size. Battle Block labels map in bind_block_snap instead.
static func _crisp_apply(control: Control) -> void:
	# A label that was Battle Block and is m5x7 again (the shared header off
	# the battle screen) keeps its block_px meta: only the font says which.
	if control.has_meta("block_px") and control.get_theme_font("font") == get_battle_font():
		return
	for size_name: String in _CRISP_SIZE_NAMES:
		if not control.has_theme_font_size_override(size_name):
			continue
		var px: int = control.get_theme_font_size(size_name)
		var wrote: int = int(control.get_meta("crisp_to_" + size_name, -1))
		var old: int = int(control.get_meta("crisp_from_" + size_name, px)) if px == wrote else px
		var crisp: int = CRISP_SMALL if control.has_meta("crisp_small") else crisp_px(old)
		control.set_meta("crisp_from_" + size_name, old)
		control.set_meta("crisp_to_" + size_name, crisp)
		if crisp != px:
			control.add_theme_font_size_override(size_name, crisp)


# ── Type system (ui-unify, docs/UI_UNIFY.md + docs/UI_STYLE.md) ──
# Two families. m5x7 (native em 16, full ASCII) carries every reading role;
# Battle Block (bitmap, native 32, capitals and digits only) is the DISPLAY face
# and, from ui-cleanup, the CARD face (battle card names and HP numbers).
# Pixel fonts render only at whole multiples of their native size: m5x7 at
# 48 / 64 / 80 / 96 (x3..x6). Battle Block (DISPLAY, CARD) is drawn pixel-exact
# per device instead (BLOCK_FONT_PX, bind_block_snap). No extra letter spacing on any role
# (the fonts' own advance); capitals only on DISPLAY and LABEL (and, by the
# 2026-07-14 capitalization law, on SMALL metadata copy that is already caps).
const FONT_NATIVE_M5X7 := 16
const FONT_NATIVE_BLOCK := 32
const TYPE_DISPLAY := "display"   # screen titles, the battle header
const TYPE_LABEL := "label"       # buttons, tabs, section headers, unit names
const TYPE_BODY := "body"         # descriptions, help text, the battle log
const TYPE_SMALL := "small"       # rarity labels, version tag, cost labels
## Crisp text step 3b (Kev, 2026-10-20): compact secondary text, m3x6 at 80
## (Daniel Linssen, m5x7's designer: the same 16 px grid and vertical metrics,
## so a line is as tall as m5x7's at 80; capitals 6 font px, advance 4 against
## m5x7's 7 and 6). Only for the secondary lines Kev named: squad select's
## mission CLEARED / threats / unlock-condition line, unit description and
## HOLD ANY UNIT hint, item and relic names in the unlock panel, the reward
## rarity line, the battle card trait title and the evolution card's MAX HP
## line. m3x6 is for tight in-game UI; reading screens (Help, the operation
## briefing) use m5x7 (Kev 2026-10-20). Drawn with one font pixel of letter
## spacing (COMPACT_SPACING) and, as plain secondary text, in COMPACT_INK.
## Request it with apply_compact, never a per-node font override.
const TYPE_COMPACT := "compact"
const TYPE_NUMERAL := "numeral"   # HP, intent and pip numbers
## ui-cleanup: battle card HP numbers, Battle Block. ui-fix: 64 is its least
## size; it is laid out at x3 (a three-digit HP is 324 px in the card's 332 px
## label) and drawn pixel-exact (BLOCK_FONT_PX).
const TYPE_CARD := "card"
## ui-fix (Kev, 2026-10-17): the battle card's unit callsign, split from CARD and
## one rung up, x3 (96): AVALANCHE is 324 px in the 332 px label.
const TYPE_CARD_NAME := "card_name"
## ui-fix (Kev, 2026-10-17): the shared header's operation name and battle count,
## one rung above DISPLAY, x4 (128).
const TYPE_HEADER := "header"
const TYPE_ROLES := {
	TYPE_DISPLAY: {"family": "block", "size": 96},
	TYPE_LABEL: {"family": "m5x7", "size": 64},   # primary buttons step up the lattice
	TYPE_BODY: {"family": "m5x7", "size": 64},
	TYPE_SMALL: {"family": "m5x7", "size": 48},
	TYPE_COMPACT: {"family": "m3x6", "size": 80},
	TYPE_NUMERAL: {"family": "m5x7", "size": 64},
	TYPE_CARD: {"family": "block", "size": 64},
	TYPE_CARD_NAME: {"family": "block", "size": 96},
	TYPE_HEADER: {"family": "block", "size": 128},
}


## A font size snapped to the nearest whole multiple of the family's native
## size, never below `floor_px` (m5x7: TEXT_MIN_PX; Battle Block: x2).
static func lattice_px(size: int, family: String = "m5x7", floor_px: int = -1) -> int:
	var native: int = FONT_NATIVE_BLOCK if family == "block" else FONT_NATIVE_M5X7
	var least: int = floor_px if floor_px > 0 else (native * 2 if family == "block" else TEXT_MIN_PX)
	return maxi(least, roundi(float(size) / float(native)) * native)


static func type_font(role: String) -> Font:
	match str(TYPE_ROLES[role]["family"]):
		"block":
			return get_battle_font()
		"m3x6":
			return get_compact_font()
	return get_pixel_font()


## The role's size in design px, times `scale` (landscape presentation), kept
## on the family's lattice.
static func type_px(role: String, scale: float = 1.0) -> int:
	var spec: Dictionary = TYPE_ROLES[role]
	return lattice_px(int(round(float(spec["size"]) * scale)), str(spec["family"]))


## Applies a type role: family, size and (optionally) ink. DISPLAY also gets the
## Battle Block treatment (no shadow, dark edge).
static func apply_type(control: Control, role: String, ink: Variant = null, scale: float = 1.0) -> void:
	control.add_theme_font_override("font", type_font(role))
	# The compact face has one size (80) whatever the caller's scale.
	control.add_theme_font_size_override("font_size", COMPACT_PX if role == TYPE_COMPACT else type_px(role, scale))
	# DISPLAY, LABEL and CARD are capitals (a display transform; the copy is
	# unchanged, and Battle Block has no lowercase glyphs).
	if control is Label and role in [TYPE_DISPLAY, TYPE_LABEL, TYPE_CARD, TYPE_CARD_NAME, TYPE_HEADER]:
		(control as Label).uppercase = true
	if ink is Color:
		control.add_theme_color_override("font_color", ink)
	if str(TYPE_ROLES[role]["family"]) == "block":
		control.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		control.add_theme_color_override("font_outline_color", BLACK_EDGE)
		var px: Vector2 = BLOCK_FONT_PX[role]
		bind_block_snap(control, px.x * scale, px.y * scale)


# ── Pixel-exact Battle Block (ui-fix, 2026-10-16) ──
# A bitmap font draws every stroke the same width only when one font pixel
# covers a WHOLE number of screen pixels. The stretch scale is per device
# (360 px wide: 1/3, 390 px: 0.361, the 540 preview: 1/2), so no fixed font
# size does it everywhere: at the old fixed 64 one font pixel was 1.33 screen
# px at 360 and 1.44 at 390, and nearest sampling drew strokes 1 and 2 px wide
# in the same numeral (HP looked thin along the bottom). So a Battle Block label
# is laid out at its role's LARGEST size and drawn with a scale (<= 1) that puts
# one font pixel on exactly k screen px: the smallest k at or above the role's
# size, or, when that passes the cap, the largest k under it. Battle Block's
# font pixel is font size / 16 design px. Min / max per role:
#   CARD      4..6 (64..96):   360 -> 96 (k 2), 390 -> 88.6 (k 2), 540 -> 64 (k 2)
#   CARD_NAME 6..6 (96):       360 -> 96 (k 2), 390 -> 88.6 (k 2), 540 -> 96 (k 3)
#   DISPLAY   6..6 (96):       360 -> 96 (k 2), 390 -> 88.6 (k 2), 540 -> 96 (k 3)
#   HEADER    8..9 (128..144): 360 -> 144 (k 3), 390 -> 133 (k 3), 540 -> 128 (k 4)
# CARD_NAME cannot reach k 3 on a phone: AVALANCHE would be 162 screen px on a
# 115 px card at 360. HEADER's cap is 9, not 8, so the phones reach k 3 at all.
## Crisp text (PREVIEW): one fixed size per role, drawn at that size on every
## canvas: the size each drew on itch under the old snap (was CARD 4..6,
## CARD_NAME 6..6, DISPLAY 6..6, HEADER 8..9).
const BLOCK_FONT_PX := {
	TYPE_CARD: Vector2(5.0, 5.0),        # 80 (was 64; 80 on itch)
	TYPE_CARD_NAME: Vector2(5.0, 5.0),   # 80 (was 96; 80 on itch)
	TYPE_DISPLAY: Vector2(5.0, 5.0),     # 80 (was 96; 80 on itch)
	TYPE_HEADER: Vector2(7.5, 7.5),      # 120 (was 128..144; 120 on itch)
}


## The Battle Block font pixel, in design px, for a role's [min_px, max_px] at a
## screen scale (screen px per design px): a whole number of screen px.
static func block_pixel_px(min_px: float, max_px: float, screen_scale: float) -> float:
	# Crisp text step 1: a role with one size draws at that size on every
	# canvas (no per-device snap).
	if screen_scale <= 0.0 or is_equal_approx(min_px, max_px):
		return max_px
	var k: int = maxi(1, ceili(min_px * screen_scale - 0.001))
	if float(k) / screen_scale > max_px + 0.001:
		k = floori(max_px * screen_scale + 0.001)
		# Under one screen px per font pixel at the cap (a tiny or headless
		# window): no whole k fits, so draw at the cap, never above it.
		if k < 1:
			return max_px
	return float(k) / screen_scale


## Lays a Battle Block label out at max_px (font size max_px x 16) and keeps its
## draw scale pixel-exact across resizes, container sorts and window changes.
static func bind_block_snap(label: Control, min_px: float, max_px: float) -> void:
	# Crisp text step 1: one size from 40 / 80 / 120 (BLOCK_FONT_PX already is).
	max_px = float(crisp_px(roundi(max_px * 16.0))) / 16.0
	min_px = max_px
	# The meta first: the crisp hook skips Battle Block labels.
	label.set_meta("block_px", Vector2(min_px, max_px))
	label.add_theme_font_size_override("font_size", roundi(max_px * float(FONT_NATIVE_BLOCK) * 0.5))
	if not label.has_meta("block_snap_bound"):
		label.set_meta("block_snap_bound", true)
		label.resized.connect(_queue_block_snap.bind(label))
		label.tree_entered.connect(_hook_block_snap.bind(label))
		if label.is_inside_tree():
			_hook_block_snap(label)
	_queue_block_snap(label)


static func _hook_block_snap(label: Control) -> void:
	# One lambda per label: a signal treats two binds of the same method as one
	# callable, so a second label in the same container could not connect.
	if not label.has_meta("block_snap_redo"):
		var redo := func() -> void: _queue_block_snap(label)
		label.set_meta("block_snap_redo", redo)
		label.tree_exiting.connect(_unhook_block_snap.bind(label))
	var redo: Callable = label.get_meta("block_snap_redo")
	var viewport: Viewport = label.get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(redo):
		viewport.size_changed.connect(redo)
	# A Container resets its children's scale when it sorts them.
	var parent := label.get_parent() as Container
	if parent != null and not parent.sort_children.is_connected(redo):
		parent.sort_children.connect(redo)
	_queue_block_snap(label)


## Drops the label's hooks on the long-lived viewport and its container.
static func _unhook_block_snap(label: Control) -> void:
	var redo: Callable = label.get_meta("block_snap_redo", Callable())
	if not redo.is_valid():
		return
	var viewport: Viewport = label.get_viewport()
	if viewport != null and viewport.size_changed.is_connected(redo):
		viewport.size_changed.disconnect(redo)
	var parent := label.get_parent() as Container
	if parent != null and parent.sort_children.is_connected(redo):
		parent.sort_children.disconnect(redo)


## The font size a bound Battle Block label is drawn at, in design px (its cap
## when it is not in the tree yet).
static func block_draw_size(label: Control) -> float:
	if not label.has_meta("block_px"):
		return float(label.get_theme_font_size("font_size"))
	var px: Vector2 = label.get_meta("block_px")
	var parent := label.get_parent() as CanvasItem
	var at_scale: float = screen_scale_at(parent) if parent != null else 0.0
	return block_pixel_px(px.x, px.y, at_scale) * 16.0


## Draws a bound label one whole screen px per font pixel per `step`
## larger than its role's snap (HP numeral option B), where the text still fits
## its parent's width and 8 font pixels of its height; otherwise at the snap.
static func set_block_step(label: Control, step: int) -> void:
	label.set_meta("block_k_step", step)
	_queue_block_snap(label)


## Re-applies a bound label's draw scale (after its alignment changes).
static func refresh_block_snap(label: Control) -> void:
	if label.has_meta("block_px"):
		_queue_block_snap(label)


static func _queue_block_snap(label: Variant) -> void:
	_apply_block_snap.call_deferred(label)


## The screen px per design px at a node (stretch, canvas layer, parents).
static func screen_scale_at(node: CanvasItem) -> float:
	if node == null or not node.is_inside_tree():
		return 0.0
	var xf: Transform2D = node.get_viewport().get_final_transform() * node.get_global_transform_with_canvas()
	return xf.get_scale().x


static func _apply_block_snap(label_ref: Variant) -> void:
	# Deferred: the label may have been freed in between.
	if not is_instance_valid(label_ref) or not (label_ref is Control):
		return
	var label := label_ref as Control
	if not label.is_inside_tree() or not label.has_meta("block_px"):
		return
	var px: Vector2 = label.get_meta("block_px")
	var parent := label.get_parent() as CanvasItem
	var at_scale: float = screen_scale_at(parent) if parent != null else 0.0
	var f: float = block_pixel_px(px.x, px.y, at_scale) / px.y
	var step: int = int(label.get_meta("block_k_step", 0))
	var host := label.get_parent() as Control
	if step != 0 and at_scale > 0.0 and host != null:
		var stepped: float = (roundf(f * px.y * at_scale) + float(step)) / at_scale
		if label.get_minimum_size().x * stepped / px.y <= host.size.x and stepped * 8.0 <= host.size.y:
			f = stepped / px.y
	# Scale about the text's anchor so alignment holds: left, centre or right.
	var pivot := Vector2(label.size.x * 0.5, label.size.y * 0.5)
	if label is Label:
		match (label as Label).horizontal_alignment:
			HORIZONTAL_ALIGNMENT_LEFT:
				pivot.x = 0.0
			HORIZONTAL_ALIGNMENT_RIGHT:
				pivot.x = label.size.x
		match (label as Label).vertical_alignment:
			VERTICAL_ALIGNMENT_TOP:
				pivot.y = 0.0
			VERTICAL_ALIGNMENT_BOTTOM:
				pivot.y = label.size.y
	label.pivot_offset = pivot
	label.scale = Vector2(f, f)
	if label.get_meta("block_ink_snap", false) and label is Label and label.get_parent() is not Container:
		_snap_block_ink(label as Label)


## m5x7 drawn pixel-exact (G-78, the run-end report). m5x7 is a dynamic
## TrueType font, which Godot rasterizes at the viewport's scale while ignoring
## a label's own scale: the scale bind_block_snap uses for Battle Block (a bitmap
## font) would resample the glyphs (strokes 1 and 3 px wide at 390 px), and a
## whole font size cannot land on the window either (390: 88.6). So these labels
## use a copy of m5x7 rasterized at its layout size (oversampling 1, like a
## bitmap), then take Battle Block's own snap: a font pixel (size / 16 design
## px) between min_px and max_px on a whole number of screen px, and the text
## origin on a whole screen px (the label must sit in a plain Control).
static var _pixel_font_exact: Font = null
static func bind_m5x7_snap(label: Label, min_px: float, max_px: float) -> void:
	# Crisp text (PREVIEW): the exact-pixel rule (G-78 run-end rows, G-86 squad
	# select subheaders) is superseded. The label is plain m5x7 at its least
	# size, what it drew on itch (5 -> 80; 3 -> 48, which the hook maps to 80).
	if not M5X7_EXACT_SNAP:
		label.add_theme_font_override("font", get_pixel_font())
		label.add_theme_font_size_override("font_size", roundi(min_px * float(FONT_NATIVE_M5X7)))
		return
	if _pixel_font_exact == null:
		var base: Font = get_pixel_font()
		if base is FontFile:
			var exact: FontFile = (base as FontFile).duplicate() as FontFile
			exact.oversampling = 1.0
			_pixel_font_exact = exact
		else:
			_pixel_font_exact = base
	label.add_theme_font_override("font", _pixel_font_exact)
	bind_block_snap(label, min_px, max_px)
	set_block_ink_snap(label)


## Opt-in (the battle card callsign, ui-fix 2026-10-17): keep the label's text
## origin on a whole screen px. A whole k per font pixel is not enough alone:
## when the text starts on a HALF screen px every texel edge sits on a pixel
## centre and nearest sampling draws strokes 2 and 3 px wide in one glyph (the
## callsign at the 540 preview: the card's 5 px margin and its ink shift are odd
## design px, so half screen px there). Only for labels in a plain Control.
static func set_block_ink_snap(label: Label) -> void:
	label.set_meta("block_ink_snap", true)
	_queue_block_snap(label)


static func _snap_block_ink(label: Label) -> void:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var origin := Vector2.ZERO
	var text_w: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			origin.x = (label.size.x - text_w) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			origin.x = label.size.x - text_w
	var line_h: float = font.get_height(font_size)
	match label.vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER:
			origin.y = (label.size.y - line_h) * 0.5
		VERTICAL_ALIGNMENT_BOTTOM:
			origin.y = label.size.y - line_h
	var xf: Transform2D = physical_transform(label)
	var at: Vector2 = xf * origin
	var per_px: Vector2 = physical_transform(label.get_parent() as CanvasItem).get_scale()
	if per_px.x <= 0.0 or per_px.y <= 0.0:
		return
	var nudge := Vector2((roundf(at.x) - at.x) / per_px.x, (roundf(at.y) - at.y) / per_px.y)
	if nudge.length() > 0.001:
		label.position += nudge


## Snap a layout length or coordinate to a whole, EVEN design px (text
## legibility Step 1, audit F5). The 540×1200 preview is exactly 0.5×, so an
## even design px is a whole screen px — ratio-derived sizes (vw × 0.92 =
## 993.6) and centering ((a − b) × 0.5) otherwise land on half screen px and
## everything inside inherits the offset. Use for any text-bearing container
## sized as a fraction of the screen or centered by arithmetic. (Engine
## containers — CenterContainer, box alignment — floor to whole design px and
## are not covered; NEAREST text sampling keeps those crisp.)
static func even_px(value: float) -> float:
	return roundf(value * 0.5) * 2.0


# ── Measuring text (crisp text step 3b, 2026-10-20) ──
## The size a text node draws at: its override mapped by the crisp hook, which
## runs only once the node is in the tree (a label measured before it is added
## still holds the old size).
static func drawn_font_px(control: Control, size_name: String = "font_size") -> int:
	if control.has_meta("crisp_small"):
		return CRISP_SMALL
	if control.has_meta("block_px"):
		return control.get_theme_font_size(size_name)
	return crisp_px(control.get_theme_font_size(size_name))


## How many lines `text` takes in `font` at `size` when word-wrapped to `width`
## design px, breaking only between words, as a Label with AUTOWRAP_WORD does.
## Measure at the container's real width (never through a hidden node's
## minimum size, which is laid out at whatever width it last had).
static func wrapped_line_count(text: String, font: Font, size: int, width: float) -> int:
	if text == "":
		return 0
	var para := TextParagraph.new()
	para.add_string(text, font, size)
	para.width = width
	para.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND
	return para.get_line_count()


## A label's wrapped text height at `width` (lines x line height + spacing).
static func wrapped_text_height(label: Label, text: String, width: float) -> float:
	var font: Font = label.get_theme_font("font")
	var size: int = drawn_font_px(label)
	var lines: int = maxi(1, wrapped_line_count(text.to_upper() if label.uppercase else text, font, size, width))
	var spacing := float(label.get_theme_constant("line_spacing"))
	return ceilf(lines * (font.get_height(size) + spacing) - spacing)


# ── Roll ranges (crisp text step 3b, Kev 2026-10-20) ──
# Every list of roll bands writes a range without spaces ("1-4", one number for
# a one-face band) in a fixed-width column as wide as the widest range, so each
# ability name and description starts at the same x.
const ROLL_RANGE_WIDEST := "15-19"


## "1-4", or "20" for a band of one face.
static func roll_range_text(low: int, high: int) -> String:
	return str(low) if low == high else "%d-%d" % [low, high]


## The roll column's width for a label: the widest range at the size it draws.
static func roll_column_width(label: Control) -> float:
	var font: Font = label.get_theme_font("font")
	return even_px(ceilf(font.get_string_size(ROLL_RANGE_WIDEST, HORIZONTAL_ALIGNMENT_LEFT, -1, drawn_font_px(label)).x) + 1.0)


## Gives a range label the fixed roll column (call once its font is set).
static func set_roll_column(label: Control) -> void:
	label.custom_minimum_size.x = roll_column_width(label)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

# ── Long-form body copy (Polish Build A, Task 3) ──
# Help/reference panels, ability descriptions, lore, and intel-popup prose use
# a size one ladder step above FONT_INFO_MIN (42 design → 64 rendered via
# scale_font_size) plus the game's first line-spacing token. Titles, buttons,
# names, and numbers keep their own sizes — this token is ONLY for paragraphs
# a player reads, not labels a player scans. Raw-px screens (home kit blurb,
# run-end summary) author against scale_font_size(FONT_BODY_MIN) so there is
# one source. BODY_LINE_SPACING is rendered px between wrapped lines (whole px,
# pixel-snap safe).
const FONT_BODY_MIN := 42
const BODY_LINE_SPACING := 10

# ── Color roles (flat pixel A 2026-10-16, ownership in flat pixel B) ──
# docs/FLAT_PIXEL_PROTOTYPE.md. The player owns the bottom, the enemy owns the
# top, the tray is shared ground. The world changes per operation; the player
# never does. Every color a screen uses comes from one of these roles or from
# the unchanged meaning tokens (hero / enemy dice, HP, heal and effect icons,
# rarity, warning).
#
# CHROME: neutral text, panels, borders, secondary and disabled buttons, the
# header ? and back icons. Carries no meaning. CHROME is its bright tone (bone by
# default), CHROME_DIM the darker one, CHROME_INK dark text on a CHROME fill.
# Vars: the debug key F10 cycles the candidates (set_chrome). Flat pixel A
# scored the candidates and picked bone (FLAT_PIXEL_PROTOTYPE.md, Phase 2).
const CHROME_CANDIDATES := [
	{"id": "bone", "accent": Color("e6dec8"), "dim": Color("837d6e"), "ink": Color("15130e")},
	{"id": "phosphor", "accent": Color("8fd16a"), "dim": Color("4c7338"), "ink": Color("0c1409")},
	{"id": "cyan", "accent": Color("3fd0e2"), "dim": Color("1f6f7a"), "ink": Color("061217")},
	{"id": "amber", "accent": Color("edb03e"), "dim": Color("8a6526"), "ink": Color("17120a")},
]
const CHROME_DEFAULT := 0
static var chrome_index: int = CHROME_DEFAULT
static var CHROME: Color = CHROME_CANDIDATES[CHROME_DEFAULT]["accent"]
static var CHROME_DIM: Color = CHROME_CANDIDATES[CHROME_DEFAULT]["dim"]
static var CHROME_INK: Color = CHROME_CANDIDATES[CHROME_DEFAULT]["ink"]


## Switches CHROME to candidate `index` (wraps). Styles built before the call
## keep the old color: the caller rebuilds them (PersistentHeader's F10 reloads
## the screen). Returns the candidate's id.
static func set_chrome(index: int) -> String:
	chrome_index = posmod(index, CHROME_CANDIDATES.size())
	var candidate: Dictionary = CHROME_CANDIDATES[chrome_index]
	CHROME = candidate["accent"]
	CHROME_DIM = candidate["dim"]
	CHROME_INK = candidate["ink"]
	_refresh_logo_materials()
	return str(candidate["id"])


## The candidate index for an id ("bone", "phosphor", "cyan", "amber"); -1 if none.
static func chrome_index_of(id: String) -> int:
	for i in range(CHROME_CANDIDATES.size()):
		if str(CHROME_CANDIDATES[i]["id"]) == id:
			return i
	return -1
#
# PLAYER: a cobalt matched to the hero dice (their base is 1f6be0, the lit edge
# about 2070f0), never the old cyan. Friendly card frames and name headers, squad
# picks and pick badges, the footer action buttons and their numbers, the
# Protocol meter, END TURN and every primary button, every selected or active
# state (tabs, toggles ON, slider fills, the selected reward card), the logo
# reactor core. PLAYER_ACCENT_LIGHT is for text and icons on dark fields,
# PLAYER_ACCENT_DIM for resting frames, PLAYER_ACCENT_INK dark text on a fill.
const PLAYER_ACCENT := Color("2a6ae6")
const PLAYER_ACCENT_LIGHT := Color("9cbcff")
const PLAYER_ACCENT_DIM := Color("1c3f82")
const PLAYER_ACCENT_INK := Color("060d1c")
#
# ENCOUNTER: one per operation, named by token in data/raw/battle-tray-scenes.json
# (`accent`), read through battle_depth.gd `encounter_accent`. It marks the enemy
# side everywhere (header count and rule, enemy cards, the mission card, Help's
# bestiary pages, enemy pop-ups, the result screen's operation and boss lines);
# one value per operation, no second tone. Enemies are warm, the player is cool
# (Kev, 2026-10-17, DECISIONS_RESOLVED G-83). ENCOUNTER_ACCENT is the current
# battle's (BattleLayout / PersistentHeader.show_operation set it).
const ENCOUNTER_FACILITY := Color("ce6256")   # red
const ENCOUNTER_HIVE := Color("d6b234")       # yellow
const ENCOUNTER_VEIL := Color("9172d8")       # violet
const ENCOUNTER_SIGNAL := Color("ca599e")     # magenta
const ENCOUNTER_MANTLE := Color("b07751")     # brown
static var ENCOUNTER_ACCENT: Color = ENCOUNTER_FACILITY
## ui-cleanup: enemy UI with no operation to borrow a color from (an enemy whose
## faction has no operation): the enemy rust, used the way ENCOUNTER_ACCENT is.
const ENEMY_DEFAULT := Color("c9755a")


## A unit card's palette: rest / targetable / selected frame, title fill, name.
## Friendly cards are PLAYER; enemy cards the ENCOUNTER accent. Selecting is the
## player's act, so a selected card of either side is PLAYER_ACCENT_LIGHT.
static func unit_card_palette(hero: bool) -> Dictionary:
	if hero:
		return {"rest": PLAYER_ACCENT_DIM, "target": PLAYER_ACCENT, "selected": PLAYER_ACCENT_LIGHT,
			"header": PLAYER_ACCENT_DIM.darkened(0.55), "name": PLAYER_ACCENT_LIGHT}
	var accent: Color = ENCOUNTER_ACCENT
	return {"rest": accent.darkened(0.45), "target": accent, "selected": PLAYER_ACCENT_LIGHT,
		"header": accent.darkened(0.78), "name": accent.lightened(0.35)}
#
# NEUTRAL chrome: steel and blue-gray for panels, borders, secondary and disabled
# buttons. The UI_* charcoal family below (UI_BG, UI_PANEL, UI_PANEL_EDGE, UI_ROW,
# UI_BUTTON, UI_LINE, UI_CARD_LINE, UI_RULE, UI_TRACK, UI_TEXT*) belongs to it.
const NEUTRAL_STEEL := Color("7d8a96")
const NEUTRAL_BLUEGRAY := Color("4c5a66")
#
# PROTOCOL (ui-unify; ui-cleanup tuned it): an electric cyan-blue, the light
# centre of the logo's reactor core. Clear of bone CHROME, cobalt PLAYER and the
# shield blue (COLOR_SHIELD) by hue; was near-white c4dcff, which read as CHROME
# at 10/10. The Protocol meter's filled cells, the Protocol cost numbers, the
# Protocol keyword in text.
const PROTOCOL_ACCENT := Color("66e0ff")
# The full meter's pulse: brightness steps (flat tones, no smooth ramp) and the
# cycle time; and the opacity an unaffordable footer action is drawn at.
const PROTOCOL_PULSE_STEPS: Array[float] = [0.0, 0.12, 0.24, 0.12]
const PROTOCOL_PULSE_PERIOD := 1.6
const UNAFFORDABLE_ALPHA := 0.45
#
# WARNING (ui-unify): amber, for warning text and the DESTRUCTIVE button (amber
# border and text; ui-fix removed its hazard stripes; never the notch). UI_WARN
# is this token.
const WARNING := Color("e8a33a")
const WARNING_INK := Color("1a1206")
#
# Keyword colors in descriptions, help and the battle log (inline color only
# where the text system already supports it; copy is unchanged).
const KW_DAMAGE := Color("f2584c")
const KW_HEAL := Color("5fd17a")
const KW_SHIELD := Color("a9bccb")      # shield steel
const KW_PROTOCOL := PROTOCOL_ACCENT
## Squad select's roll band bar (Kev, 2026-10-17, G-87): a UTILITY band (mark,
## burn, freeze, jam, taunt, cloak, Protocol gain, roll changes ...), a lit steel
## gray, clearly lit, never as dark as the empty track (UI_ROW).
const UTILITY_SEGMENT := Color("6e7682")
#
# Shared inks: the dark edge on text over art, and the scrim behind modals.
const INK_OUTLINE := Color(0.02, 0.03, 0.05, 0.98)
const SCRIM := Color(0.005, 0.007, 0.012, 0.78)
#
# Battle feedback (float text, card flashes, particles). Values unchanged from
# their old literals; they are tokens now.
const FX_DAMAGE := Color(1.0, 0.42, 0.42)
const FX_DAMAGE_FLASH := Color(1.0, 0.45, 0.45)
const FX_EXECUTE := Color(1.0, 0.30, 0.30)
const FX_HEAL := Color(0.5, 1.0, 0.62)
const FX_HEAL_FLASH := Color(0.45, 1.0, 0.65)
const FX_SHIELD := Color(0.55, 0.82, 1.0)
const FX_GOLD := Color(1.0, 0.82, 0.20)
const FX_EMBER := Color(0.95, 0.55, 0.20)
const FX_RUST := Color(0.86, 0.42, 0.28)
const FX_HIJACK := Color(0.95, 0.45, 0.30)
const FX_ASH := Color(0.42, 0.44, 0.50)
const FX_CARD_PULSE := Color(1.35, 1.35, 1.4)   # overbright modulate: the act pulse
const FX_ROW_REJECT := Color(1.0, 0.30, 0.30)
#
# Portrait and card states (modulate tints).
const PORTRAIT_LIVE := Color(1.12, 1.12, 1.12)
const PORTRAIT_DEAD := Color(0.48, 0.50, 0.58, 0.55)
const PORTRAIT_CLOAKED := Color(0.70, 0.80, 0.95, 0.42)
const CARD_DEAD := Color(0.55, 0.56, 0.62, 0.72)
const SILHOUETTE := Color(0.035, 0.045, 0.065)  # a locked hero / operation portrait
const PLATE_DARK := Color(0.006, 0.012, 0.020, 0.80)
const PLATE_SHADOW := Color(0.0, 0.0, 0.0, 0.55)
const SHIELD_PREVIEW := Color(0.22, 0.55, 0.95, 0.80)
const READOUT_INK := Color(0.84, 0.90, 0.96, 0.78)
const READOUT_INK_STRONG := Color(0.82, 0.90, 0.96, 0.88)
# Pip borders on battle cards, by effect kind.
const PIP_BORDERS := {
	"damage": Color(0.86, 0.32, 0.28, 0.92), "heal": Color(0.38, 0.82, 0.55, 0.92),
	"shield": Color(0.42, 0.66, 0.88, 0.92), "burn": Color(0.82, 0.40, 0.58, 0.92),
	"roll": Color(0.86, 0.66, 0.26, 0.92), "freeze": Color(0.48, 0.78, 0.88, 0.92),
	"default": Color(0.34, 0.52, 0.70, 0.86),
}
const BATTLE_TICK := Color("2a333a")
# The faint grid behind some screens (pattern_background.gd), neutral steel.
const PATTERN_GRID := Color(0.49, 0.54, 0.59, 0.08)
const PATTERN_GRID_MAJOR := Color(0.49, 0.54, 0.59, 0.12)
const PATTERN_SCANLINE := Color(0.02, 0.03, 0.05, 0.22)

# ── UI restyle A tokens (2026-10-14, docs/UI_RESTYLE.md) ──
# The charcoal family the mocks share (NEUTRAL role). Strokes are MIN_STROKE
# (4 design px). The restyle's one amber, UI_ACCENT, became CHROME.
const UI_BG := Color("0e1216")              # screen field
const UI_PANEL := Color("161c1f")           # section panel / card fill
const UI_PANEL_EDGE := Color("22292d")      # section panel frame
const UI_ROW := Color("202427")             # row plate inside a section
const UI_BUTTON := Color("1a1c20")          # button fill
const UI_LINE := Color("4a5057")            # gray border (secondary, tabs, toggles off)
const UI_CARD_LINE := Color("34424d")       # selectable card border at rest
const UI_RULE := Color("53595d")            # thin rule under a section header
const UI_BAR := NEUTRAL_STEEL              # secondary button's left bar
const UI_TRACK := Color("3c4247")           # slider empty track
const UI_TEXT := Color("e8e6df")
const UI_TEXT_DIM := Color("8a8f94")
const UI_TEXT_OFF := Color("4f5458")
const UI_STEEL := Color("7f9cb8")           # uncommon rarity
# Warnings (save discarded, resume problems, destructive confirms) are rust
# orange-red: a different hue from every CHROME candidate, never on a
# button frame.
const UI_WARN := WARNING   # ui-unify: amber (was rust e06a3c)

# ── Direction 05 "Dithered Terminal" palette (battle HUD redesign) ──
# Green is reserved for HP + the ROLL commit only; heroes read cyan, enemies rust.
static var DT_FIELD_BG := Color("07090b")
static var DT_FIELD_BORDER := Color("232a2e")
static var DT_PANEL_BG := Color("090c0e")
static var DT_TRAY_BG := Color("06080a")
static var DT_LINE := Color("1b2226")
static var DT_HP_GREEN := Color("57854b")   # muted, desaturated military green (terminal palette)
static var DT_HP_TEXT := Color("eafce9")
static var DT_AMBER := Color("cf9a36")
static var DT_AMBER_TEXT := Color("b08a3a")
static var DT_PROTO_EMPTY := Color("1a1c12")
static var DT_PROTO_EMPTY_BORDER := Color("2a2c1c")
# Flat icon buttons (header/footer): dark square, 2px border; active uses DT_CYAN.
static var DT_BTN_BG := Color("11161a")
static var DT_BTN_BORDER := Color("28323a")
# Translucent grouping plate over live game art (battle log). Grouping is a
# FILLED plate, never a stroked outline (INVARIANTS #7).
static var DT_PLATE_TRANSLUCENT := Color(0.015, 0.022, 0.035, 0.82)
# Enemy (rust) card tokens
static var DT_ENEMY_BG := Color("130c0a")
static var DT_ENEMY_BORDER := Color("5e3022")
static var DT_ENEMY_HEADER := Color("1e110c")
static var DT_ENEMY_NAME := Color("c9755a")
static var DT_ENEMY_TRACK := Color("0e0908")
static var DT_ENEMY_DITHER := Color("dc785a")
# G-18: boss rank is a filled nameplate, separate from target/selection borders.
static var DT_BOSS_HEADER := Color("d18a4a")
static var DT_BOSS_INK := Color("160f0b")
# Hero (navy/cyan) card tokens
static var DT_HERO_BG := Color("0a141c")
static var DT_HERO_BORDER := PLAYER_ACCENT_DIM   # ui-unify: the player owns cobalt (was cyan 235461)
static var DT_HERO_HEADER := Color("0d2029")
static var DT_HERO_NAME := PLAYER_ACCENT_LIGHT   # ui-unify (was cyan 56c7d9)
static var DT_HERO_TRACK := Color("0a1218")
static var DT_HERO_DITHER := Color("5ac8dc")
# ui-unify: the legacy "player / primary" cyan now IS the player cobalt, so the
# screens that still read these names follow the direction (was 3fd0e2 / 6fe0ef).
# DT_HERO_DITHER / DT_ENEMY_DITHER stay: the dice renderer reads them.
static var DT_CYAN := PLAYER_ACCENT
static var DT_CYAN_BRIGHT := PLAYER_ACCENT_LIGHT
static var DT_RUST := Color("c25d3f")
static var DT_RUST_BRIGHT := Color("f0a585")
# Commit (ROLL) green bevel — DEPRECATED for buttons. Green is reserved for HP bars
# now; primary buttons use the teal BTN_* tokens below. Kept only so any lingering
# reference still resolves.
static var DT_ROLL_BASE := Color("3f8a47")
static var DT_ROLL_LIGHT := Color("5fc266")
static var DT_ROLL_DARK := Color("235c2a")
static var DT_ROLL_BG := Color("1c5a26")
static var DT_ROLL_TEXT := Color("e3ffe4")
# ── Primary action button (teal "terminal command" look) ──
# The single primary-button language for the whole UI. Navy fill matches panel
# backgrounds; 2px teal border + all-caps teal text; hover brightens with a soft
# outer glow; pressed inverts (teal fill, dark ink); disabled drops its border and
# fades to 40%. One amber variant flags risk / confirm actions. Green is HP-only.
static var BTN_PRIMARY_BG := Color("0a141c")        # dark navy (matches DT_HERO_BG panels)
static var BTN_PRIMARY_BG_HOVER := Color("0f1f2a")
static var BTN_PRIMARY_INK := Color("07090b")       # near-black inverted (pressed) text
static var BTN_TEAL_BORDER := PLAYER_ACCENT          # = DT_CYAN (ui-unify: cobalt)
static var BTN_TEAL_TEXT := PLAYER_ACCENT_LIGHT
static var BTN_TEAL_TEXT_BRIGHT := PLAYER_ACCENT_LIGHT.lightened(0.25)
static var BTN_AMBER_BORDER := Color("cf9a36")      # = DT_AMBER
static var BTN_AMBER_TEXT := Color("e6bd68")
static var BTN_AMBER_TEXT_BRIGHT := Color("f7dc9a")
static var BTN_DISABLED_TEXT := Color(0.62, 0.68, 0.74, 0.40)  # inert, 40% opacity
# Status badge tokens {border, fill, text}
static var DT_STATUS := {
	"shield": {"border": Color("3fd0e2"), "fill": Color("0a1620"), "text": Color("bff7ff")},
	"burn": {"border": Color("d98a3e"), "fill": Color("1f140a"), "text": Color("f4cd9a")},
}
# ── Reward rarity border tokens ──
# The card's outer border color = its rarity. These are intentionally OFFSET from the
# semantic gameplay palette so a rarity border never reads as a gameplay signal
# (rare-indigo must not look like player cyan DT_CYAN; legendary-orange must not look
# like commit gold GOLD_ACCENT / enemy red). Relics carry no rarity and reuse the
# legendary token (see reward_screen._rarity_name). Tunable starting values.
# Rarity ladder (Kev ruling 2026-07-10, UI review S-2): green exits the rarity
# palette entirely — green stays reserved for HP/heals (INVARIANTS #7).
# gray -> blue -> purple -> orange. "epic" is unused in data (kept aligned).
# UI restyle A (2026-10-14): legendary is the UI accent, uncommon steel blue,
# common gray (supersedes the 2026-07-10 orange legendary; docs/UI_RESTYLE.md).
# ui-fix (Kev, 2026-10-16; supersedes the 2026-07-10 "green exits" ruling for
# rarity only): common muted gray, uncommon GREEN, rare violet, legendary gold.
# The uncommon green is a yellow-leaning leaf green (hue ~88), clearly apart from
# the heal greens (COLOR_HEAL / KW_HEAL, hue ~136-141) and the dark HP fill.
static var RARITY_COMMON := UI_TEXT_DIM
static var RARITY_UNCOMMON := Color("84b84a")
static var RARITY_RARE := Color("9d52d8")
static var RARITY_EPIC := Color("9d52d8")
static var RARITY_LEGENDARY := Color("edb03e")   # legendary gold (restyle A value)

# ── Inspect popup tokens (the unified long-press reveal) ──
# Neutral Dithered-Terminal surface; side/rarity accents are layered on by the caller
# (DT_HERO_BORDER / DT_ENEMY_BORDER / rarity_color). Border/divider use the DT line tones.
static var INSPECT_BG := Color("0b0f13")
static var INSPECT_BORDER := Color("2a3540")
static var INSPECT_DIVIDER := Color("1b2226")
static var INSPECT_TEXT := Color("dfe9ec")
static var INSPECT_TEXT_MUTED := Color("8a99a6")
# Tertiary text (hints, popup section heads, version stamp). Raised from
# #57646e (2.97–3.28:1, text legibility Step 1 / audit F6) to clear 4.5:1 on
# every panel surface in this palette — worst BG_PANEL_ALT 4.55, INSPECT_BG
# 4.85, DT_FIELD_BG 5.03 — while staying a step below INSPECT_TEXT_MUTED.
# web/shell.html mirrors it (web loader palette gate).
static var INSPECT_TEXT_DIM := Color("71828f")
# Single shared long-press hold duration (seconds), tuned for Android touch. Defined once
# here so no surface re-declares it.
const INSPECT_HOLD_SEC := 0.42

const DITHER_TILE := "res://assets/ui/dither_2x2.png"

const UI_FONT_PATH := "res://assets/fonts/m5x7.ttf"
const UI_FONT_SCALE := 1.35
const UI_FONT_MIN_SIZE := TEXT_MIN_PX
# Rendered-size ladder (text legibility Step 1): floor 48, every rung on the m5x7
# native-16 lattice. 72 → 80 and (wrap-up, 2026-09-26) 56 → 64; the coach hint
# that overflowed at 64 now wraps to two lines (spotlight_layer).
const UI_FONT_STEPS := [48, 64, 80]
const FRAME_SIMPLE := "res://assets/ui/frame_simple.png"
const FRAME_GLOW := "res://assets/ui/frame_glow.png"
const FRAME_CORNER_DOTS := "res://assets/ui/frame_corner_dots.png"
const FRAME_CROSSHATCH := "res://assets/ui/frame_crosshatch.png"
const FRAME_SCANLINE := "res://assets/ui/frame_scanline.png"
const FRAME_SMALL_LANDSCAPE := "res://assets/ui/frame_small_landscape.png"
const FRAME_PORTRAIT_SCIFI := "res://assets/ui/frame_portrait_scifi.png"
const FRAME_DICE_TRAY_SCIFI := "res://assets/ui/frame_dice_tray_scifi.png"
const FRAME_ITEM_SCIFI := "res://assets/ui/frame_item_scifi.png"
const FRAME_BOTTOM_BAR_SCIFI := "res://assets/ui/frame_bottom_bar_scifi.png"
const FRAME_BOTTOM_BAR_2_SCIFI := "res://assets/ui/frame_bottom_bar_2_scifi.png"
const FRAME_SIMPLE_BAR_SCIFI := "res://assets/ui/frame_simple_bar_scifi.png"
const FRAME_BAR_HORIZONTAL_SCIFI := "res://assets/ui/frame_bar_horizontal_scifi.png"
const FRAME_BAR_SHALLOW_SCIFI := "res://assets/ui/frame_bar_shallow_scifi.png"
const BUTTON_LARGE_GRAY_SCIFI := "res://assets/ui/btn_large_gray_scifi.png"
const BUTTON_LARGE_YELLOW_SCIFI := "res://assets/ui/btn_large_yellow_scifi.png"
const ICON_HELP := "res://assets/ui/icons/icon_help.png"
const ICON_BACK := "res://assets/ui/icons/icon_back.png"
const ICON_REROLL := "res://assets/ui/icons/icon_reroll.png"
const ICON_INCREASE := "res://assets/ui/icons/icon_increase.png"
const ICON_ITEM := "res://assets/ui/icons/icon_item.png"
const ICON_DEBUG := "res://assets/ui/icons/icon_debug.png"
const ICON_DEBUG2 := "res://assets/ui/icons/icon_debug2.png"
# System/UI glyph set (batch 181-189), muted teal.
const ICON_SWAP := "res://assets/ui/icons/icon_swap.png"
const ICON_EVOLVE := "res://assets/ui/icons/icon_evolve.png"
const ICON_FLEE := "res://assets/ui/icons/icon_flee.png"
const ICON_SETTINGS := "res://assets/ui/icons/icon_settings.png"
const ICON_LOCK := "res://assets/ui/icons/icon_lock.png"
const ICON_NEW := "res://assets/ui/icons/icon_new.png"
# The battle "Set" protocol button — the roll d20 recolored to the UI teal.
const ICON_SET := "res://assets/ui/icons/icon_set.png"
# Pip icons moved to per-key files under assets/ui/pips/ (batch 155-179); see
# PIP_ICON_BY_KEY + pip_texture_for_key below. The old pip_*_scifi.png are orphaned.

const FRAME_MARGIN_BY_PATH := {
	FRAME_SIMPLE: 18,
	FRAME_GLOW: 20,
	FRAME_CORNER_DOTS: 18,
	FRAME_CROSSHATCH: 18,
	FRAME_SCANLINE: 18,
	FRAME_SMALL_LANDSCAPE: 18,
	FRAME_PORTRAIT_SCIFI: 24,
	FRAME_DICE_TRAY_SCIFI: 28,
	FRAME_ITEM_SCIFI: 18,
	FRAME_BOTTOM_BAR_SCIFI: 20,
	FRAME_BOTTOM_BAR_2_SCIFI: 20,
	FRAME_SIMPLE_BAR_SCIFI: 28,
	FRAME_BAR_HORIZONTAL_SCIFI: 16,
	FRAME_BAR_SHALLOW_SCIFI: 48,
}

static var _pixel_font: Font = null
static var _pip_texture_cache: Dictionary = {}


# ── Minimum stroke law (INVARIANTS #14 corollary) ────────────────────────────
# StyleBoxFlat borders can't be snapped per-instance, so their design-space
# width must guarantee ≥1 window px on EVERY edge at every supported window
# scale. A border of design width N spans N*scale window px; any span ≥ 1
# always covers a pixel center, but a span < 1 can fall entirely between two
# pixel centers and rasterize to ZERO rows — the game-wide "clipped border"
# defect (a 2px stroke is 0.83 window px at a ~450x1000 window; which edge
# vanished depended only on where the control's rect landed). Odd widths are
# 1.5 window px at the exact-half 540x1200 preview and shimmer, so strokes
# must also be even. 4 design px is the smallest even width whose span stays
# ≥ 1 window px down to scale 0.25. Width ≤ 0 means "no border" and passes
# through. Every StyleBoxFlat border in the game must flow through this (via
# make_panel_style / make_hard_style or directly).
const MIN_STROKE := 4
## ui-fix layout rhythm (2026-10-16): the ONE gap, in design px (a multiple of
## 4), between a bar (header, footer) and the cards, and between stacked blocks
## on every screen that shares the header. The header and footer bars are the
## same height (PersistentHeader.HEADER_HEIGHT), each with a MIN_STROKE divider.
const GAP := 16

static func min_stroke(width: int) -> int:
	if width <= 0:
		return width
	return maxi(width + (width & 1), MIN_STROKE)


## ui-unify: one corner treatment, square. `corner` is kept for callers and
## ignored; every panel is square-cornered.
static func make_panel_style(bg: Color = BG_PANEL, border: Color = LINE_DIM, border_width: int = 2, _corner: int = 0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(min_stroke(border_width))
	style.shadow_color = BLACK_EDGE
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO
	style.set_content_margin(SIDE_LEFT, 4.0)
	style.set_content_margin(SIDE_TOP, 4.0)
	style.set_content_margin(SIDE_RIGHT, 4.0)
	style.set_content_margin(SIDE_BOTTOM, 4.0)
	return style


## Hard-cornered, single-tone bordered plate (Direction-05 pixel-frame language).
static func make_hard_style(bg: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.anti_aliasing = false
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(min_stroke(width))
	s.corner_radius_top_left = 0
	s.corner_radius_top_right = 0
	s.corner_radius_bottom_left = 0
	s.corner_radius_bottom_right = 0
	s.set_content_margin_all(0.0)
	return s


## Battle skin resources. All shells have a solid rim and ONE dark inset step;
## title plates join the card sides instead of nesting another outlined box.
## Each resource has explicit content margins, independent of its painted rim.
## Callers must sample NEAREST: these are authored pixel bands, not bevels.
static func battle_panel_style(fill: Color, border: Color, margin: float = 0.0) -> StyleBoxTexture:
	var key := fill.to_html() + border.to_html()
	var inset := BATTLE_SHELL_WIDTH + BATTLE_INSET_WIDTH
	if not _battle_panel_textures.has(key):
		var pixels := Image.create(36, 36, false, Image.FORMAT_RGBA8)
		pixels.fill(border)
		pixels.fill_rect(Rect2i(8, 8, 20, 20), BATTLE_INNER_EDGE)
		pixels.fill_rect(Rect2i(12, 12, 12, 12), fill)
		_battle_panel_textures[key] = ImageTexture.create_from_image(pixels)
	var style := StyleBoxTexture.new()
	style.texture = _battle_panel_textures[key]
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, inset)
		style.set_content_margin(side, margin)
	return style


## Authored pixel surfaces, nine-sliced without changing control content margins.
static func battle_surface_style(surface: String, margin: float = 0.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = _load_texture(BATTLE_SKIN_PATH + surface + ".svg")
	var slice := 4.0 if surface.begins_with("cell") else 12.0
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, slice)
		style.set_content_margin(side, margin)
	return style


static func battle_layout_style(margin: float = 0.0) -> StyleBoxEmpty:
	var style := StyleBoxEmpty.new()
	style.set_content_margin_all(margin)
	return style


## The solid plate under a die tag's pips (battle depth prototype v2): a filled
## field with no outline, padded just past the content.
static func battle_tag_plate_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BATTLE_TAG_PLATE
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style


## The container a die tag's pip rows go in. `plated` puts the v2 solid plate
## behind them; `outlined` (the transparent v3 tag, 2026-07-09 ruling) gives
## every icon and digit a hard dark pixel outline instead. Landscape: neither.
static func make_battle_tag_field(plated: bool, outlined: bool = false) -> PanelContainer:
	var field := PanelContainer.new()
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_theme_stylebox_override("panel", battle_tag_plate_style() if plated else battle_layout_style())
	if outlined:
		# The pips are added after the field is built; outline them once they are in.
		field.ready.connect(_outline_tag.bind(field), CONNECT_ONE_SHOT)
	return field


const _TAG_OUTLINE_DIRECTIONS: Array[Vector2] = [
	Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0),
	Vector2(1, 0), Vector2(-1, 1), Vector2(0, 1), Vector2(1, 1)]


static func _outline_tag(node: Node) -> void:
	for child in node.get_children():
		_outline_tag(child)
	if node is Label:
		node.add_theme_color_override("font_outline_color", BATTLE_TAG_OUTLINE)
		node.add_theme_constant_override("outline_size", BATTLE_TAG_OUTLINE_PX * 2)
	elif node is TextureRect:
		var icon := node as TextureRect
		# Eight black copies one outline step out, drawn behind the icon. The
		# icon's tint multiplies into them and stays black.
		for direction: Vector2 in _TAG_OUTLINE_DIRECTIONS:
			var copy := TextureRect.new()
			copy.texture = icon.texture
			copy.expand_mode = icon.expand_mode
			copy.stretch_mode = icon.stretch_mode
			copy.texture_filter = icon.texture_filter
			copy.self_modulate = BATTLE_TAG_OUTLINE
			copy.show_behind_parent = true
			copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.add_child(copy)
			var shift: Vector2 = direction * BATTLE_TAG_OUTLINE_PX
			copy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			copy.offset_left = shift.x
			copy.offset_right = shift.x
			copy.offset_top = shift.y
			copy.offset_bottom = shift.y


static func battle_tray_style(frame_only: bool = false) -> StyleBoxTexture:
	var style := battle_surface_style("tray")
	style.draw_center = not frame_only
	return style


static func battle_strip_style(margin: float = 0.0) -> StyleBoxTexture:
	return battle_surface_style("strip", margin)


static func battle_button_style(border: Color, pressed: bool) -> StyleBoxTexture:
	var style := battle_surface_style("button", 14.0)
	style.modulate_color = Color(border.r / BATTLE_BORDER.r, border.g / BATTLE_BORDER.g,
		border.b / BATTLE_BORDER.b, 1.0)
	if pressed:
		style.modulate_color = style.modulate_color.darkened(0.25)
	return style


## A tiling 2x2 dither overlay (the signature of Direction 05). tint+alpha via modulate.
## Anchored full-rect, ignores mouse. Parent must clip if needed.
static func make_dither_overlay(tint: Color, alpha: float) -> TextureRect:
	var tr: TextureRect = TextureRect.new()
	tr.name = "Dither"
	tr.texture = _load_texture(DITHER_TILE)
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.modulate = Color(tint.r, tint.g, tint.b, alpha)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	return tr


static func get_pixel_font() -> Font:
	if _pixel_font == null:
		# ResourceLoader, NOT FontFile.load_dynamic_font(raw path): an export
		# packs only the IMPORTED artifact + the .import remap — the raw .ttf is
		# not in the APK (verified against Build #1's shipped APK file list), so
		# the old dynamic load failed on device and the silent SystemFont
		# fallback rendered every label in Roboto (the Android Build #1 "font
		# mush" bug). load() follows the remap to the imported FontFile, which
		# carries the six Phase-0-verified import params. Desktop resolves the
		# same imported resource — pixel-identical.
		var font: Font = load(UI_FONT_PATH) as Font
		if font == null:
			# Loud failure (Build #2 rule: never substitute silently). The
			# SystemFont keeps the game readable; the error names the bug.
			push_error("[PixelUI] m5x7 failed to load from '%s' - falling back to a SYSTEM font. Text is rendering in the wrong typeface; fix the font resource, do not ship this." % UI_FONT_PATH)
			var fallback_font: SystemFont = SystemFont.new()
			fallback_font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New", "monospace"])
			_pixel_font = fallback_font
			return _pixel_font
		# Crisp text step 2 (PREVIEW): rasterize m5x7 at 2x its size whatever
		# the window's scale. Godot rounds font oversampling DOWN to 1/64ths, so
		# at the itch scale (0.4) the glyphs were rasterized at 0.390625: 80 drew
		# from a 31.25 px raster stretched 2.4% on screen, and columns and rows
		# came out 1 and 3 px wide. At 2x, a font pixel is 5 / 10 / 15 texels at
		# 40 / 80 / 120, a whole multiple of the 5 texels one screen px samples
		# at 0.4, so every stroke is 1 / 2 / 3 px wherever the text sits.
		if font is FontFile:
			(font as FontFile).oversampling = CRISP_FONT_OVERSAMPLING
		_pixel_font = font
	return _pixel_font


## The compact secondary face (TYPE_COMPACT): m3x6 at 80, rasterized at the
## same 2x oversampling as m5x7 (crisp text step 2's fix) so its strokes are
## whole screen px on the itch canvas, through a FontVariation that adds
## COMPACT_SPACING between glyphs. A missing font fails loudly and falls back
## to m5x7 (never a system font).
const COMPACT_FONT_PATH := "res://assets/fonts/m3x6.ttf"
const COMPACT_PX := 80
## Letter spacing, design px: one m3x6 font pixel at 80 (5), 2 screen px on
## the itch canvas (0.4). Crisp text step 3c (Kev 2026-10-20) asked for half a
## font pixel (1 screen px); FontVariation spacing is whole design px, so that
## needs a derived copy of m3x6 with wider advances, and the font's terms
## ("free to use with attribution") do not say a modified copy is allowed, so
## the fallback Kev named is used: a whole font pixel.
const COMPACT_SPACING := 5
## The compact face's ink for plain secondary text (unit descriptions,
## threats, unlock conditions, the HOLD ANY UNIT hint, the MAX HP line): the
## muted gray Help uses for its descriptions. Status and rarity
## text keeps its own colour.
const COMPACT_INK := UI_TEXT_DIM
static var _compact_font: Font = null
static func get_compact_font() -> Font:
	if _compact_font == null:
		var font: Font = load(COMPACT_FONT_PATH) as Font
		if font == null:
			push_error("[PixelUI] m3x6 failed to load from '%s' - falling back to m5x7." % COMPACT_FONT_PATH)
			return get_pixel_font()
		if font is FontFile:
			(font as FontFile).oversampling = CRISP_FONT_OVERSAMPLING
		var spaced := FontVariation.new()
		spaced.base_font = font
		spaced.spacing_glyph = COMPACT_SPACING
		_compact_font = spaced
	return _compact_font


## The m3x6 file under the compact face (its oversampling and glyphs).
static func compact_font_file() -> Font:
	var font: Font = get_compact_font()
	return (font as FontVariation).base_font if font is FontVariation else font


## Whether a font is the compact face (the spaced m3x6 or the file itself).
static func is_compact_font(font: Font) -> bool:
	return font != null and (font == get_compact_font() or str(font.resource_path).ends_with("m3x6.ttf")
		or (font is FontVariation and str((font as FontVariation).base_font.resource_path).ends_with("m3x6.ttf")))


## Sets a label (or button) in the compact secondary face, m3x6 at 80.
## `ink` null keeps the caller's colour; plain secondary text passes
## COMPACT_INK.
static func apply_compact(control: Control, ink: Variant = null) -> void:
	apply_type(control, TYPE_COMPACT, ink)


static func apply_pixel_font(control: Control) -> void:
	control.add_theme_font_override("font", get_pixel_font())


# ── Sharp text filtering (text legibility Step 1, audit F2) ──
# The project default canvas filter stays LINEAR (downscaled portraits/art need
# it), but LINEAR smears m5x7 glyphs into half-tones whenever they land off the
# physical pixel grid — which is almost always below scale 1.0. Every node that
# draws the pixel font samples it NEAREST instead. ONE owner, installed once by
# the always-alive PersistentHeader: a sweep of the live tree plus a
# SceneTree.node_added hook, so every text node — whichever factory built it,
# including ones that never touch PixelUI — is covered the moment it enters the
# tree. An explicit per-node filter is respected (only PARENT_NODE is set).
# Regression: scripts/debug/text_legibility_test.gd.
static var _text_filter_installed := false


static func is_text_node(node: Node) -> bool:
	return node is Label or node is RichTextLabel or node is LineEdit or node is TextEdit \
		or node is Button or node is LinkButton or node is ItemList or node is Tree \
		or node is TabBar or node is TabContainer or node is ProgressBar


static func apply_text_filter(node: Node) -> void:
	if is_text_node(node):
		var item := node as CanvasItem
		if item.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Crisp text step 1: the same always-on hook maps every text size.
		if node is Control:
			_crisp_bind(node as Control)


static func install_text_filter(tree: SceneTree) -> void:
	if _text_filter_installed or tree == null:
		return
	_text_filter_installed = true
	tree.node_added.connect(apply_text_filter)
	_apply_text_filter_recursive(tree.root)


static func _apply_text_filter_recursive(node: Node) -> void:
	apply_text_filter(node)
	for child in node.get_children():
		_apply_text_filter_recursive(child)


static func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func parse_signed_amount(value: Variant) -> int:
	var text: String = str(value).strip_edges()
	if text == "":
		return 0
	var sign: int = -1 if text.begins_with("-") else 1
	var digits := ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits == "":
		return 0
	return sign * int(digits)


static func format_amount_no_sign(value: Variant) -> String:
	var text: String = str(value).strip_edges().to_upper()
	if text == "":
		return ""
	var parsed: int = parse_signed_amount(text)
	if parsed != 0:
		return str(abs(parsed))
	return text.trim_prefix("+").trim_prefix("-")


# Every keyword now has its own pip icon (batch 155-179). Roll is the single gold
# d20 asset resolved as roll_up/roll_down so the caller can tint +roll green.
# Only `tag` remains iconless (return "" → rendered as text); rampage has had
# its own icon since the 2026-07-10 icon batch.
static func pip_key_for_effect(kind: String, value: Variant = "") -> String:
	match kind.to_lower():
		"dmg", "damage", "blast":
			return "damage"
		"pierce":
			return "pierce"
		"heal":
			return "heal"
		"revive":
			return "revive"
		"shield":
			return "shield"
		"taunt":
			return "taunt"
		"burn":
			return "burn"
		"freeze", "frozen", "die_freeze":
			return "freeze"
		"protocol":
			return "protocol"
		"cloak":
			return "cloak"
		"ward", "firewall":
			return "firewall"
		"mark":
			return "mark"
		"cleanse":
			return "cleanse"
		"leech":
			return "leech"
		"spike":
			return "spike"
		"jam":
			return "jam"
		"rewrite":
			return "rewrite"
		"hijack":
			return "hijack"
		"siphon":
			return "siphon"
		"chain":
			return "chain"
		"detonate":
			return "detonate"
		"execute":
			return "execute"
		"breach":
			return "breach"
		"accrete":
			return "accrete"
		"rampage":
			return "rampage"
		"pack_bonus":
			return "pack_bonus"
		"summon":
			return "summon"
		"rfe":
			return "roll_down"
		"rfm":
			return "roll_up" if parse_signed_amount(value) > 0 else "roll_down"
		"roll":
			return "roll_down" if parse_signed_amount(value) < 0 else "roll_up"
	return ""


# ── Portrait region (single source of truth) ────────────────────────────────
# The hero portrait window is 328×380 (aspect ≈0.863) — measured live from the
# battle card (2026-07-12, stable pre/post-roll). EVERY screen that displays a
# portrait uses this aspect; a screen needing a different physical size scales
# this aspect through make_portrait_frame — it never defines its own. A frame
# of any other aspect is a defect: a TALLER one cover-fits by height, which
# zooms the art in and trims its sides (the 2026-10-10 evolution-screen bug); a
# SHORTER one trims the bottom and destroys the framing — the 320×486 bug:
# squad select and the battle card showed different windows onto the same art,
# and every framing pass authored against the wrong one. Do not define a
# portrait window anywhere else, and do not hardcode a second aspect.
const HERO_PORTRAIT_REGION := Vector2(328.0, 380.0)

# ── Hero portrait display zoom (display-time only; the PNGs stay pristine) ──
# HERO_PORTRAIT_ZOOM: uniform extra scale applied inside cover_fit_portrait to
# HERO art only (>1.0 = tighter). Enemies are the framing reference and are
# NEVER zoomed. 1.2 picked by Kev 2026-07-12 against the RUST reference card.
# HERO_PORTRAIT_ANCHOR_Y: vertical bias as a FRACTION of the frame height —
# positive shifts the art UP in the frame (0.03 ≈ 11 px in the 380-tall
# region); scales with the frame like PORTRAIT_TOP_PAD.
# Per-asset offsets are DATA, not code: the pre-anchor per-portrait hooks
# (pulse_pyro's 0.94 zoom, the breaker family's anchor-Y 0.105/0.166/0.237,
# Scrap/Rust Drone's 5 px seat) live in assets/portraits/portrait_anchors.json
# as legacy_zoom / legacy_anchor_y / legacy_down_px, next to the hand-declared
# head anchors they were derived from. Antenna/crown crop-off is ruled
# acceptable (TRUTH.md): the head is what must frame consistently.
const HERO_PORTRAIT_ZOOM := 1.2
const HERO_PORTRAIT_ANCHOR_Y := 0.0
# Every hero portrait sits this many final-display px LOWER than the shared
# cover fit (UI consistency 2026-09-20/21: the old eight-pixel upward bias
# exposed Engineer's source mat below its torso). It was two copies — the
# battle card and the Squad Selector each added it locally — and is now one
# class rule applied on every screen (framing editor task, 2026-09-27).
const HERO_PORTRAIT_SEAT_DOWN_PX := 6.0


# Cover-fit a portrait TextureRect inside its crop frame. Composition-aware:
# full-bleed scenic art (tagged by DataManager) centres both axes; cutout art
# anchors to the top edge so heads are never cropped off. Single framing rule
# for every screen — no per-unit offsets.
#
# PORTRAIT_TOP_PAD (Batch 3): downward shift so the subject's head never
# kisses/clips the frame's top edge. Cutout art gets the full pad (the strip
# above it shows the card background — reads as headroom). Full-bleed art only
# shifts as far as it can while still covering the frame top (never reveals a
# background gap above opaque art). One constant, applied by the shared rule —
# no per-unit hand-tuning. The pad is authored in HERO_PORTRAIT_REGION units
# and SCALES with the frame (fix/portrait-region): an absolute pad gave smaller
# frames proportionally more headroom, so squad tiles framed subtly differently
# than the battle card even at the right aspect.
const PORTRAIT_TOP_PAD := 12.0
# Portrait art is shifted by this many final-display pixels after the shared
# cover fit. Keeping this in physical pixels makes the crop correction exactly
# the same on the 540px capture, native phones, and smaller supported windows.
const PORTRAIT_CONTENT_UP_PHYSICAL_PX := 8.0
# Solid backdrop behind every framed portrait (Kev, 2026-09-27). Where framing
# zooms out or shifts the art so it no longer covers its frame (the pad strip,
# anchor framing, legacy_* offsets), the gap is black on every screen instead of
# whatever the host frame paints (the brown strip above the Hive boss on the
# encounter panel). All live portrait art is opaque, so the backdrop only ever
# shows where the art does not reach.
const PORTRAIT_BACKDROP_COLOR := Color("000000")

# The small role-color square is retained as a component affordance for later
# roster work, but is intentionally suppressed during the beta. Screens which
# host it must consult this single flag rather than carrying local exceptions.
const SHOW_BETA_UNIT_BADGES := false

## Debug-build seam for the `portrait frame` gate's deliberate breaks (never set
## by the game). Each one hits the FIRST portrait built: `stretch` makes its
## frame half again as tall (the 2026-10-10 evolution-screen bug, where a row
## stretched the frame), `squash` draws its art off-aspect, `bypass` shows it
## without the helper's tag.
const PORTRAIT_FRAME_BREAK_ARG := "--portrait-frame-break="
static var _portrait_frame_break: String = "?"
static var _portrait_break_target: int = 0


static func portrait_frame_break() -> String:
	if _portrait_frame_break == "?":
		_portrait_frame_break = ""
		if OS.is_debug_build():
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with(PORTRAIT_FRAME_BREAK_ARG):
					_portrait_frame_break = arg.trim_prefix(PORTRAIT_FRAME_BREAK_ARG)
	return _portrait_frame_break


static func _is_portrait_break_target(node: Object) -> bool:
	if _portrait_break_target == 0:
		_portrait_break_target = node.get_instance_id()
	return _portrait_break_target == node.get_instance_id()


# The portrait window at a given width: HERO_PORTRAIT_REGION's aspect, height
# on whole even design px (INVARIANTS #14). The ONLY place the aspect becomes a
# size — a screen never repeats this arithmetic.
static func portrait_window(width: float) -> Vector2:
	return Vector2(width, even_px(width * HERO_PORTRAIT_REGION.y / HERO_PORTRAIT_REGION.x))


# ── Portrait frame: the ONE portrait component ──────────────────────────────
# Every portrait outside the battle card is built here: a frame whose art
# window is portrait_window(window_w), a clipping crop and the art, fitted by
# cover_fit_portrait on every resize. `style` is the screen's chrome (border and
# fill); its content margins sit OUTSIDE the window, so a bordered frame is the
# window plus its border. The frame never stretches — it shrinks to its own
# size in any container, because a frame a row may stretch stops being the
# portrait window (the evolution choice portraits, 2026-10-10: right minimum
# size, wrong laid-out size, and no gate measured the laid-out size). A screen
# may pick where the frame sits (SIZE_SHRINK_BEGIN / _CENTER / _END), never
# SIZE_FILL or SIZE_EXPAND. The battle card is the window's reference and
# builds its own; the `portrait frame` gate measures both on the live screens.
# Returns {frame, crop, tex}; swap the art later with set_portrait.
static func make_portrait_frame(texture: Texture2D, window_w: float, style: StyleBox) -> Dictionary:
	var window: Vector2 = portrait_window(window_w)
	var frame := PanelContainer.new()
	frame.name = "PortraitFrame"
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", style)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if portrait_frame_break() == "stretch" and _is_portrait_break_target(frame):
		window.y = even_px(window.y * 1.5)
	frame.custom_minimum_size = window + style.get_minimum_size()
	var crop := Control.new()
	crop.name = "PortraitCrop"
	crop.clip_contents = true
	crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(crop)
	var tex := TextureRect.new()
	tex.name = "Portrait"
	tex.texture = texture
	tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_SCALE  # position and size come from cover_fit_portrait
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crop.add_child(tex)
	crop.resized.connect(func() -> void: cover_fit_portrait(tex, crop.size))
	return {"frame": frame, "crop": crop, "tex": tex}


# Swap the art in a make_portrait_frame portrait and refit it to its window.
static func set_portrait(tex_rect: TextureRect, texture: Texture2D) -> void:
	if tex_rect == null:
		return
	tex_rect.texture = texture
	var crop: Control = tex_rect.get_parent() as Control
	if crop != null:
		cover_fit_portrait(tex_rect, crop.size)


static func cover_fit_portrait(tex_rect: TextureRect, frame_size: Vector2) -> void:
	if tex_rect == null:
		return
	var break_mode: String = portrait_frame_break()
	if break_mode == "bypass" and _is_portrait_break_target(tex_rect):
		tex_rect.position = Vector2.ZERO
		tex_rect.size = frame_size
		return
	tex_rect.set_meta("framing_helper", "portrait")
	var fw: float = frame_size.x
	var fh: float = frame_size.y
	if fw < 2.0 or fh < 2.0:
		return
	var tex: Texture2D = tex_rect.texture
	if tex == null or tex.get_width() < 1 or tex.get_height() < 1:
		tex_rect.position = Vector2.ZERO
		tex_rect.size = frame_size
		_sync_portrait_backdrop(tex_rect, frame_size, false)
		return
	_place_portrait(tex_rect, tex, fw, fh)
	if break_mode == "squash" and _is_portrait_break_target(tex_rect):
		tex_rect.size.y *= 0.8
	_sync_portrait_backdrop(tex_rect, frame_size, true)


# The black frame-sized backdrop, drawn behind the art (show_behind_parent) as
# an internal child of the portrait itself, so every screen gets it from the
# helper with no node of its own. Offset by the art's placement so it covers
# the frame exactly; refitting moves it with the art.
static func _sync_portrait_backdrop(tex_rect: TextureRect, frame_size: Vector2, show: bool) -> void:
	var backdrop: ColorRect = null
	if tex_rect.has_meta("portrait_backdrop"):
		backdrop = tex_rect.get_meta("portrait_backdrop") as ColorRect
	if backdrop == null or not is_instance_valid(backdrop):
		if not show:
			return
		backdrop = ColorRect.new()
		backdrop.name = "PortraitBackdrop"
		backdrop.color = PORTRAIT_BACKDROP_COLOR
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		backdrop.show_behind_parent = true
		tex_rect.add_child(backdrop, false, Node.INTERNAL_MODE_FRONT)
		tex_rect.set_meta("portrait_backdrop", backdrop)
	backdrop.visible = show
	backdrop.position = -tex_rect.position
	backdrop.size = frame_size


static func _place_portrait(tex_rect: TextureRect, tex: Texture2D, fw: float, fh: float) -> void:
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	var entry: Dictionary = framing_entry_for(tex)
	if bool(entry.get("use_anchors", false)) and entry.has("head_top") and entry.has("chin"):
		_anchor_fit_portrait(tex_rect, tex, entry, fw, fh)
		return
	var cover_scale: float = maxf(fw / tw, fh / th)
	# HERO art: uniform display zoom and vertical anchor bias (fraction of frame
	# height). Enemies: zoom 1.0, anchor 0. Per-asset legacy_* offsets come from
	# the framing data (portrait_anchors.json), never from screen code.
	var anchor_shift: float = 0.0
	var is_hero: bool = bool(tex.get_meta("hero_portrait", false))
	if is_hero:
		cover_scale *= HERO_PORTRAIT_ZOOM * float(entry.get("legacy_zoom", 1.0))
		anchor_shift = (HERO_PORTRAIT_ANCHOR_Y + float(entry.get("legacy_anchor_y", 0.0))) * fh
	else:
		if entry.has("legacy_zoom"):
			cover_scale *= float(entry["legacy_zoom"])
		if entry.has("legacy_anchor_y"):
			anchor_shift = float(entry["legacy_anchor_y"]) * fh
	var nw: float = tw * cover_scale
	var nh: float = th * cover_scale
	var full_bleed: bool = bool(tex.get_meta("full_bleed", false))
	var pad: float = PORTRAIT_TOP_PAD * (fh / HERO_PORTRAIT_REGION.y)
	var top_y: float
	if full_bleed:
		top_y = minf((fh - nh) * 0.5 + pad, 0.0)
	else:
		top_y = pad
	top_y -= anchor_shift  # positive ANCHOR_Y = art shifts UP in the frame
	# One shared visual correction for every unit surface using this helper.
	# Convert the requested final-display movement back into local coordinates
	# so it remains an exact eight physical pixels under canvas scaling.
	var physical_scale_y: float = physical_transform(tex_rect).get_scale().y
	if physical_scale_y > 0.0:
		top_y -= PORTRAIT_CONTENT_UP_PHYSICAL_PX / physical_scale_y
	else:
		top_y -= PORTRAIT_CONTENT_UP_PHYSICAL_PX
	tex_rect.position = Vector2((fw - nw) * 0.5, top_y)
	tex_rect.size = Vector2(nw, nh)
	# Seat-down offsets in final-display px, applied AFTER placement — the exact
	# arithmetic the battle card and Squad Selector used when each carried these
	# locally, so their captures stay pixel-identical.
	var down_px: float = HERO_PORTRAIT_SEAT_DOWN_PX if is_hero else 0.0
	down_px += float(entry.get("legacy_down_px", 0.0))
	if down_px != 0.0 and physical_scale_y > 0.0:
		tex_rect.position.y += down_px / physical_scale_y


# Anchor framing (use_anchors): pure arithmetic from Kev's hand-declared
# head_top / chin / center_x. The head is scaled to _targets[section]
# .head_height of the frame height, its top seated at .head_top of the frame
# height, its centre on the frame's horizontal centre. Everything is a
# fraction of the frame, so a 96 px help thumb frames exactly like the 380 px
# battle card. No pads, zooms or pixel nudges: the anchors ARE the framing.
static func _anchor_fit_portrait(tex_rect: TextureRect, tex: Texture2D, entry: Dictionary, fw: float, fh: float) -> void:
	var target: Dictionary = framing_target(str(tex.get_meta("framing_section", "")))
	var region: Rect2 = framing_region(tex)
	var source_size: Vector2 = tex.get_meta("framing_source_size", region.size)
	var head_top: float = float(entry["head_top"])
	var chin: float = float(entry["chin"])
	var cx: float = float(entry.get("center_x", source_size.x * 0.5))
	if bool(tex.get_meta("framing_mirrored", false)):
		cx = source_size.x - cx
	var s: float = float(target.get("head_height", 0.42)) * fh / maxf(chin - head_top, 1.0)
	tex_rect.size = Vector2(float(tex.get_width()), float(tex.get_height())) * s
	tex_rect.position = Vector2(
		fw * 0.5 - (cx - region.position.x) * s,
		float(target.get("head_top", 0.12)) * fh - (head_top - region.position.y) * s)


# ── Framing data: ONE entry per asset, used on every screen ────────────────
# assets/portraits/portrait_anchors.json (schema 2; fields in its _doc block
# and docs/TRUTH.md). DataManager tags every portrait / item / relic texture
# with its section + key when it loads the art; the two helpers
# (cover_fit_portrait, fit_item_art) look the entry up from those tags. No
# entry → the asset renders exactly as it did before framing data existed.
const FRAMING_DATA_PATH := "res://assets/portraits/portrait_anchors.json"
const FRAMING_PORTRAIT_SECTIONS: Array[String] = ["heroes", "enemies", "bosses"]
const FRAMING_ART_SECTIONS: Array[String] = ["items", "relics"]
static var _framing: Dictionary = {}
static var _framing_loaded := false


static func framing_data() -> Dictionary:
	if not _framing_loaded:
		_framing_loaded = true
		_framing = {}
		if FileAccess.file_exists(FRAMING_DATA_PATH):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FRAMING_DATA_PATH))
			if parsed is Dictionary:
				_framing = parsed
	return _framing


# Dev framing editor only: swap in the live (unsaved) data it is editing.
static func set_framing_data(data: Dictionary) -> void:
	_framing = data
	_framing_loaded = true


static func framing_entry(section: String, key: String) -> Dictionary:
	var sec: Variant = framing_data().get(section, {})
	if sec is Dictionary:
		var entry: Variant = (sec as Dictionary).get(key, {})
		if entry is Dictionary:
			return entry
	return {}


static func framing_entry_for(tex: Texture2D) -> Dictionary:
	if tex == null or not tex.has_meta("framing_section"):
		return {}
	return framing_entry(str(tex.get_meta("framing_section")), str(tex.get_meta("framing_key", "")))


static func framing_target(section: String) -> Dictionary:
	var targets: Variant = framing_data().get("_targets", {})
	if targets is Dictionary:
		var t: Variant = (targets as Dictionary).get(section, {})
		if t is Dictionary:
			return t
	return {}


# The source-pixel rect left after the entry's per-edge crop insets, in the
# DISPLAY orientation (a mirrored enemy's on-disk left inset trims its right).
static func framing_inset_rect(entry: Dictionary, source_size: Vector2i, mirrored: bool = false) -> Rect2i:
	var insets: Dictionary = {}
	if entry.get("insets", {}) is Dictionary:
		insets = entry.get("insets", {})
	var left: int = maxi(int(insets.get("left", 0)), 0)
	var right: int = maxi(int(insets.get("right", 0)), 0)
	if mirrored:
		var swap: int = left
		left = right
		right = swap
	var top: int = maxi(int(insets.get("top", 0)), 0)
	var bottom: int = maxi(int(insets.get("bottom", 0)), 0)
	return Rect2i(left, top, maxi(source_size.x - left - right, 1), maxi(source_size.y - top - bottom, 1))


static func framing_has_insets(entry: Dictionary) -> bool:
	var probe := Vector2i(4096, 4096)
	var r: Rect2i = framing_inset_rect(entry, probe)
	return r.position != Vector2i.ZERO or r.size != probe


static func tag_framing(tex: Texture2D, section: String, key: String, source_size: Vector2i, mirrored: bool = false) -> void:
	if tex == null:
		return
	tex.set_meta("framing_section", section)
	tex.set_meta("framing_key", key)
	tex.set_meta("framing_source_size", Vector2(source_size))
	tex.set_meta("framing_mirrored", mirrored)


# Region of the display-orientation source image this texture draws.
static func framing_region(tex: Texture2D) -> Rect2:
	if tex is AtlasTexture and (tex as AtlasTexture).atlas != null:
		return (tex as AtlasTexture).region
	return Rect2(0.0, 0.0, float(tex.get_width()), float(tex.get_height()))


# Item / relic art for one id. No framing entry → the shared imported texture,
# untouched (identical to the pre-framing build). With an entry → a per-id
# AtlasTexture (two ids share one PNG, so the tag cannot live on the shared
# resource) whose region drops the crop insets.
static func framed_art_texture(base: Texture2D, section: String, key: String) -> Texture2D:
	if base == null:
		return null
	var entry: Dictionary = framing_entry(section, key)
	if entry.is_empty():
		return base
	var source_size := Vector2i(base.get_width(), base.get_height())
	var atlas := AtlasTexture.new()
	atlas.atlas = base
	atlas.region = Rect2(framing_inset_rect(entry, source_size))
	atlas.filter_clip = true
	tag_framing(atlas, section, key, source_size)
	return atlas


# ── Item / relic art helper (the item-side twin of cover_fit_portrait) ──────
# Every item and relic display site builds its art through make_item_art (or
# make_integer_icon, its integer-law form) so ONE framing entry — visual
# centre, scale, crop insets — applies on every screen. Modes are each
# screen's SIZE policy, not framing: "integer" (the pixel-art integer law —
# reward / unlock / item-card surfaces), "contain" (whole art inside the box)
# and "cover" (fill the box; square art in a square box equals contain).
const ITEM_FIT_INTEGER := "integer"
const ITEM_FIT_CONTAIN := "contain"
const ITEM_FIT_COVER := "cover"


static func fit_item_art(rect: TextureRect, frame_size: Vector2, mode: String = ITEM_FIT_CONTAIN) -> void:
	if rect == null:
		return
	rect.set_meta("framing_helper", "item")
	var tex: Texture2D = rect.texture
	if tex == null or frame_size.x < 1.0 or frame_size.y < 1.0:
		return
	var entry: Dictionary = framing_entry_for(tex)
	if entry.is_empty() and mode != ITEM_FIT_INTEGER:
		# No framing data: TextureRect's own keep-aspect draw, exactly as these
		# screens drew before the helper existed (its region sampling differs
		# from a scaled draw by a pixel column at some sizes).
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if mode == ITEM_FIT_COVER else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.position = Vector2.ZERO
		rect.size = frame_size
		return
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	var native := Vector2(maxf(float(tex.get_width()), 1.0), maxf(float(tex.get_height()), 1.0))
	var k: float
	match mode:
		ITEM_FIT_INTEGER:
			k = frame_size.x / native.x
		ITEM_FIT_COVER:
			k = maxf(frame_size.x / native.x, frame_size.y / native.y)
		_:
			k = minf(frame_size.x / native.x, frame_size.y / native.y)
	var art_scale: float = float(entry.get("scale", 1.0))
	if art_scale != 1.0:
		k = maxf(1.0, roundf(k * art_scale)) if mode == ITEM_FIT_INTEGER else k * art_scale
	var center: Vector2 = native * 0.5
	if entry.has("center_x") or entry.has("center_y"):
		var region: Rect2 = framing_region(tex)
		var source_size: Vector2 = tex.get_meta("framing_source_size", region.size)
		center = Vector2(float(entry.get("center_x", source_size.x * 0.5)),
			float(entry.get("center_y", source_size.y * 0.5))) - region.position
	rect.size = native * k
	rect.position = (frame_size * 0.5 - center * k).round()


## Item / relic art in a `box`-sized frame, positioned by fit_item_art.
static func make_item_art(tex: Texture2D, box: Vector2, mode: String = ITEM_FIT_CONTAIN) -> Control:
	var frame := Control.new()
	frame.name = "ItemArt"
	frame.custom_minimum_size = box
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.clip_contents = mode == ITEM_FIT_COVER
	if tex == null:
		return frame
	var rect := TextureRect.new()
	rect.texture = tex
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(rect)
	# Fit on every resize, and once on ready: a frame that is already at its
	# final size when parented never emits `resized`. Idempotent — the same
	# frame size always gives the same placement.
	var fit := func() -> void: fit_item_art(rect, frame.size, mode)
	frame.resized.connect(fit)
	frame.ready.connect(fit)
	return frame


# ── Pixel snap law (INVARIANTS #14) ──────────────────────────────────────────
# Ratio-derived UI coordinates must land on whole PHYSICAL pixels: the game
# renders 1080x2400 scaled into the window, so a whole LOCAL pixel is a
# fraction of a screen pixel and "1px" lines smear across two. Fold the
# canvas transform's scale + origin in, round in physical space, map back.

# Local -> window-pixel transform. The stretch mode is canvas_items: the
# 1080x2400 design space scales to the window via the viewport's FINAL
# transform, which get_global_transform_with_canvas() does NOT include —
# canvas-space rounding alone leaves a "1px" line covering a fraction of a
# window pixel (kept or dropped by the scaler per position: the notch defect).
static func physical_transform(item: CanvasItem) -> Transform2D:
	var xform: Transform2D = item.get_global_transform_with_canvas()
	var viewport: Viewport = item.get_viewport()
	if viewport != null:
		xform = viewport.get_final_transform() * xform
	return xform


# Snap a local x/y coordinate so it lands on a whole window pixel.
static func snap_to_physical_px(item: CanvasItem, local_coord: float, axis: int = 0) -> float:
	var xform: Transform2D = physical_transform(item)
	var scale: float = xform.get_scale().x if axis == 0 else xform.get_scale().y
	if scale <= 0.0:
		return roundf(local_coord)
	var origin: float = xform.get_origin().x if axis == 0 else xform.get_origin().y
	return (roundf(origin + local_coord * scale) - origin) / scale


# The local-space length of N whole window pixels (min 1 window px).
static func physical_px_width(item: CanvasItem, physical_px: float = 1.0) -> float:
	var scale: float = physical_transform(item).get_scale().x
	if scale <= 0.0:
		return physical_px
	return maxf(physical_px, 1.0) / scale


# Keyword pip icons (batch 155-179) live one-per-key under assets/ui/pips/.
# roll_up / roll_down both resolve to the single gold d20 (roll.png); the +roll
# green tint is applied by the caller (EffectPip.build_group).
const PIP_ICON_DIR := "res://assets/ui/pips/"
const PIP_ICON_BY_KEY := {
	"damage": "damage", "heal": "heal", "shield": "shield", "protocol": "protocol",
	"roll": "roll", "roll_up": "roll", "roll_down": "roll", "freeze": "freeze",
	"aoe": "aoe", "burn": "burn", "leech": "leech", "mark": "mark", "taunt": "taunt",
	"cloak": "cloak", "firewall": "firewall", "spike": "spike", "jam": "jam",
	"rewrite": "rewrite", "hijack": "hijack", "siphon": "siphon", "chain": "chain",
	"detonate": "detonate", "execute": "execute", "breach": "breach",
	"pierce": "pierce", "revive": "revive", "accrete": "accrete",
	# Kev 2026-07-10 icon batch (newicons.png): self marker, summon, rampage,
	# pack bonus.
	"self": "self", "summon": "summon", "rampage": "rampage", "pack_bonus": "pack_bonus",
	# Cleanse (Build I): REUSES the heal glyph — the golden tint is applied by
	# the caller (EffectPip.build_group), same pattern as roll_up's green.
	"cleanse": "heal",
	# Batch 5 icon swap (newicons.png / newicons2.png): target_lowest is new (reticle
	# + down arrow, the lowest-HP-ally scope marker); aoe, taunt, leech, summon were
	# re-cut from the sheets (aoe now the cardinal-arrow burst — distinct from freeze).
	"target_lowest": "target_lowest",
}

static func pip_texture_for_key(key: String) -> Texture2D:
	if key == "":
		return null
	if _pip_texture_cache.has(key):
		return _pip_texture_cache.get(key)
	var texture: Texture2D = _load_texture(PIP_ICON_DIR + str(PIP_ICON_BY_KEY.get(key, "")) + ".png")
	if texture != null:
		texture = _content_cropped(texture)
		_pip_texture_cache[key] = texture
	return texture


# The modulate a pip glyph carries wherever it renders (readout pips AND primer
# coachmarks — single source, so the shared-glyph keys can't drift): roll_up
# tints the gold d20 green; cleanse tints the shared heal glyph golden (Build I
# ruling — COLOR_CLEANSE_PIP). Everything else renders untinted.
static func pip_tint_for_key(key: String) -> Color:
	match key:
		"roll_up":
			return COLOR_HEAL
		"cleanse":
			return COLOR_CLEANSE_PIP
	return Color.WHITE


# Trim an icon's transparent margins (AtlasTexture over the source, computed
# once per key via the cache above). The glyphs carry uneven baked padding —
# the damage bolt is only 84/128 px wide, so its value floated ~10px further
# from the visible glyph than every other pip's (Batch 3). Cropping lets
# layout hug the glyph; the drawn pixels are unchanged.
static func _content_cropped(texture: Texture2D) -> Texture2D:
	var img: Image = texture.get_image()
	if img == null:
		return texture
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return texture
	if used.position == Vector2i.ZERO and used.size == Vector2i(img.get_width(), img.get_height()):
		return texture
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(used)
	return atlas


static func _frame_margin_for(texture_path: String, fallback_margin: int) -> int:
	return int(FRAME_MARGIN_BY_PATH.get(texture_path, fallback_margin))


static func make_ninepatch_stylebox(texture_path: String, margin_px: int = 18, modulate_color: Color = Color.WHITE) -> StyleBoxTexture:
	var texture: Texture2D = _load_texture(texture_path)
	var stylebox := StyleBoxTexture.new()
	stylebox.texture = texture
	stylebox.modulate_color = modulate_color
	var margin_value: int = _frame_margin_for(texture_path, margin_px)
	stylebox.texture_margin_left = margin_value
	stylebox.texture_margin_right = margin_value
	stylebox.texture_margin_top = margin_value
	stylebox.texture_margin_bottom = margin_value
	stylebox.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	stylebox.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	stylebox.draw_center = true
	return stylebox


static func style_ninepatch_panel(panel: Control, texture_path: String, margin_px: int = 18, modulate_color: Color = Color.WHITE) -> void:
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.add_theme_stylebox_override("panel", make_ninepatch_stylebox(texture_path, margin_px, modulate_color))


static func _make_full_texture_stylebox(texture_path: String, modulate_color: Color = Color.WHITE) -> StyleBoxTexture:
	var texture: Texture2D = _load_texture(texture_path)
	var stylebox := StyleBoxTexture.new()
	stylebox.texture = texture
	stylebox.modulate_color = modulate_color
	stylebox.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	stylebox.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	stylebox.draw_center = true
	return stylebox


## Renders `button` as a frameless icon glyph centered on a 9-patch sci-fi frame.
##
## - `frame_path`: 9-patchable frame texture (e.g. PixelUI.FRAME_SIMPLE).
## - `icon_path`:  frameless glyph PNG (e.g. PixelUI.ICON_HELP). Drawn at native
##                 pixel size by default so pixel-art lines stay crisp; pass
##                 `expand_icon = true` only if you have a larger source glyph.
## - `frame_margin`: 9-patch margin override; -1 uses FRAME_MARGIN_BY_PATH.
## - `frame_modulate`: tints the frame texture (useful for emphasis on the
##                     reroll/spend button — pass PixelUI.GOLD_ACCENT etc.).
## - `icon_modulate`: tints the glyph independently of the frame.
## - `icon_padding`:  inner content margin on each side, in pixels. Defaults
##                    to the frame's own margin so the glyph never overlaps
##                    the frame edge.
static func style_frame_icon_button(
	button: BaseButton,
	frame_path: String,
	icon_path: String,
	frame_margin: int = -1,
	frame_modulate: Color = Color.WHITE,
	icon_modulate: Color = Color.WHITE,
	icon_padding: int = -1,
	expand_icon: bool = false,
) -> void:
	if button == null:
		return
	var frame_margin_value: int = _frame_margin_for(frame_path, 18) if frame_margin < 0 else frame_margin
	var padding_value: int = frame_margin_value if icon_padding < 0 else icon_padding
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# Build the four frame styleboxes with content margins large enough to
	# keep the glyph inside the inner panel.
	var styles := {
		"normal":   make_ninepatch_stylebox(frame_path, frame_margin_value, frame_modulate),
		"hover":    make_ninepatch_stylebox(frame_path, frame_margin_value, frame_modulate.lightened(0.08)),
		"pressed":  make_ninepatch_stylebox(frame_path, frame_margin_value, frame_modulate.darkened(0.18)),
		"disabled": make_ninepatch_stylebox(frame_path, frame_margin_value, Color(0.58, 0.58, 0.62, 0.78)),
		"focus":    make_ninepatch_stylebox(frame_path, frame_margin_value, frame_modulate.lightened(0.04)),
	}
	for stylebox_variant in styles.values():
		var stylebox: StyleBoxTexture = stylebox_variant
		stylebox.set_content_margin(SIDE_LEFT, padding_value)
		stylebox.set_content_margin(SIDE_RIGHT, padding_value)
		stylebox.set_content_margin(SIDE_TOP, padding_value)
		stylebox.set_content_margin(SIDE_BOTTOM, padding_value)

	if button is TextureButton:
		var tb := button as TextureButton
		tb.ignore_texture_size = true
		tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		var icon_texture: Texture2D = _load_texture(icon_path)
		tb.texture_normal = icon_texture
		tb.texture_hover = icon_texture
		tb.texture_pressed = icon_texture
		tb.texture_focused = icon_texture
		tb.texture_disabled = icon_texture
		tb.modulate = icon_modulate
		return

	if button is Button:
		var b := button as Button
		b.text = ""
		b.flat = false
		b.icon = _load_texture(icon_path)
		b.expand_icon = expand_icon
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		# Drop any inherited text-button theme overrides so the icon owns the cell.
		b.remove_theme_font_override("font")
		b.remove_theme_font_size_override("font_size")
		b.remove_theme_color_override("font_color")
		b.remove_theme_color_override("font_hover_color")
		b.remove_theme_color_override("font_pressed_color")
		b.remove_theme_color_override("font_focus_color")
		b.remove_theme_color_override("font_outline_color")
		b.remove_theme_constant_override("outline_size")
		b.add_theme_color_override("icon_normal_color", icon_modulate)
		b.add_theme_color_override("icon_hover_color", icon_modulate)
		b.add_theme_color_override("icon_pressed_color", icon_modulate.darkened(0.10))
		b.add_theme_color_override("icon_focus_color", icon_modulate)
		b.add_theme_color_override("icon_disabled_color", Color(icon_modulate.r, icon_modulate.g, icon_modulate.b, 0.55))
		for state_name in styles.keys():
			b.add_theme_stylebox_override(state_name, styles[state_name])


## Direction-05 flat icon button: dark square (DT_BTN_BG) + 2px hard border, our
## pixel icon centered & expanded. Pass border_color = DT_CYAN for the active state.
## `icon_tint` (flat pixel A/B): a color draws the icon recolored (tinted_icon);
## TRANSPARENT keeps the art as authored.
static func style_dt_icon_button(button: BaseButton, icon_path: String, border_color: Color = DT_BTN_BORDER, icon_modulate: Color = Color.WHITE, battle: bool = false, icon_tint: Color = Color.TRANSPARENT) -> void:
	if button == null or not (button is Button):
		return
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 4px border (not 2) so every edge stays visible through the canvas_items preview
	# downscale — at 2px the buttons dropped edges, same as the panels.
	var styles := {
		"normal": make_hard_style(DT_BTN_BG, border_color, 4),
		"hover": make_hard_style(DT_BTN_BG.lightened(0.05), border_color.lightened(0.10), 4),
		"pressed": make_hard_style(DT_BTN_BG.darkened(0.12), border_color, 4),
		"disabled": make_hard_style(DT_BTN_BG, Color(0.35, 0.38, 0.42, 0.6), 4),
		"focus": make_hard_style(DT_BTN_BG, border_color, 4),
	}
	for stylebox_variant in styles.values():
		(stylebox_variant as StyleBoxFlat).set_content_margin_all(14.0)
	if battle:
		for state in styles:
			var style: StyleBoxFlat = styles[state]
			style.bg_color = BATTLE_PANEL
			if border_color == DT_BTN_BORDER:
				style.border_color = BATTLE_BORDER.lightened(0.12) if state == "hover" else BATTLE_BORDER
			if state == "pressed":
				style.bg_color = BATTLE_BORDER
			elif state == "disabled":
				style.border_color = BATTLE_BORDER.darkened(0.25)
			styles[state] = battle_button_style(style.border_color, state == "pressed")
	var b := button as Button
	b.text = ""
	b.flat = false
	# No focus ring — keeps every button visually identical (a focused button was
	# rendering with a different edge/outline).
	b.focus_mode = Control.FOCUS_NONE
	b.icon = tinted_icon(icon_path, icon_tint) if icon_tint.a > 0.0 else _load_texture(icon_path)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.remove_theme_font_override("font")
	b.add_theme_color_override("icon_normal_color", icon_modulate)
	b.add_theme_color_override("icon_hover_color", icon_modulate)
	b.add_theme_color_override("icon_pressed_color", icon_modulate.darkened(0.10))
	b.add_theme_color_override("icon_focus_color", icon_modulate)
	b.add_theme_color_override("icon_disabled_color", Color(icon_modulate.r, icon_modulate.g, icon_modulate.b, 0.55))
	for state_name in styles.keys():
		b.add_theme_stylebox_override(state_name, styles[state_name])


static func style_labeled_texture_button(button: Button, texture_path: String, font_size: int, font_color: Color = TEXT_PRIMARY) -> void:
	if button == null:
		return
	apply_pixel_font(button)
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.flat = false
	button.icon = null
	button.expand_icon = false
	button.add_theme_font_size_override("font_size", scale_font_size(font_size))
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_focus_color", font_color)
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.98))
	button.add_theme_stylebox_override("normal", _make_full_texture_stylebox(texture_path))
	button.add_theme_stylebox_override("hover", _make_full_texture_stylebox(texture_path, Color(1.06, 1.06, 1.06, 1.0)))
	button.add_theme_stylebox_override("pressed", _make_full_texture_stylebox(texture_path, Color(0.90, 0.90, 0.90, 1.0)))
	button.add_theme_stylebox_override("disabled", _make_full_texture_stylebox(BUTTON_LARGE_GRAY_SCIFI, Color(0.72, 0.72, 0.76, 1.0)))


static func scale_font_size(font_size: int) -> int:
	var scaled_size: int = maxi(UI_FONT_MIN_SIZE, int(round(float(font_size) * UI_FONT_SCALE)))
	for stepped_size in UI_FONT_STEPS:
		if scaled_size <= int(stepped_size):
			return int(stepped_size)
	# ui-unify: above the ladder, still a whole multiple of m5x7's native 16.
	return lattice_px(scaled_size)


static func effect_color(kind: String) -> Color:
	match kind.to_lower():
		"dmg", "damage", "blast", "pierce":
			return COLOR_DAMAGE
		"heal", "revive":
			return COLOR_HEAL
		"shield", "taunt":
			return COLOR_SHIELD
		"burn":
			return COLOR_BURN
		"debuff":
			return COLOR_DEBUFF
		"roll", "rfe", "rfm", "freeze":
			return COLOR_ROLL
		"roll_down":
			return COLOR_ROLL
		"roll_up":
			return COLOR_HEAL
	return TEXT_PRIMARY


static func effect_value_color(kind: String) -> Color:
	return effect_color(kind).lerp(TEXT_PRIMARY, 0.32)


static func rarity_color(rarity: String) -> Color:
	match rarity.to_lower():
		"common":
			return RARITY_COMMON
		"uncommon":
			return RARITY_UNCOMMON
		"rare":
			return RARITY_RARE
		"epic":
			return RARITY_EPIC
		"legendary":
			return RARITY_LEGENDARY
	return RARITY_COMMON


static func status_color(token: String) -> Color:
	var upper: String = token.to_upper()
	if upper.begins_with("BRN") or upper.begins_with("BURN"):
		return COLOR_BURN
	if upper == "DOWN" or upper == "P":
		return COLOR_DEBUFF
	if upper == "RMP":
		return COLOR_DAMAGE
	if upper.begins_with("+") or upper.begins_with("-") or upper == "FR":
		return COLOR_ROLL
	if upper.begins_with("SH") or upper == "TA" or upper == "CL":
		return COLOR_SHIELD
	if upper.begins_with("HP"):
		return COLOR_HEAL
	return TEXT_MUTED


static func style_panel(panel: Control, bg: Color = BG_PANEL, border: Color = LINE_DIM, border_width: int = 2, corner: int = 4) -> void:
	panel.add_theme_stylebox_override("panel", make_panel_style(bg, border, border_width, corner))


## Public corner-bracket helper: draws accent L-brackets at a Control's four corners
## (auto-tracks resize). Pass Color.TRANSPARENT to remove.
static func add_corner_brackets(target: Control, color: Color, arm: float = 16.0, thick: float = 3.0, inset: float = 4.0) -> void:
	_refresh_corner_brackets(target, color, arm, thick, inset)


## A framed scene-illustration banner sized to the image's OWN aspect ratio so the
## whole picture shows (no cover-crop / zoom). The frame is scaled to fit inside a
## max_w x max_h box and hugs the resulting size, so its height floats per-image
## within that range and it centers horizontally in its parent. Pixel art stays
## nearest-filtered. Returns the frame (already carries border + corner brackets).
static func make_scene_banner(tex: Texture2D, max_w: float, max_h: float, border: Color) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.clip_contents = true
	frame.add_theme_stylebox_override("panel", make_hard_style(DT_PANEL_BG, border, 2))
	# ui-cleanup: a whole multiple of the art's own pixels (was a fractional fit).
	frame.add_child(make_integer_art(tex, Vector2(max_w, max_h)))
	add_corner_brackets(frame, border, 24.0, 3.0, 8.0)
	return frame


## ui-cleanup (art scaling): pixel-art illustrations draw at a WHOLE multiple of
## their own pixels, NEAREST: the largest multiple that fits `max_size`, never
## below x1. Only when x1 itself is larger than the box does the box crop it,
## centred. The art sits on whole, even design px. Returns the clipping box;
## refit it with fit_integer_art when the space is known only after layout.
static func make_integer_art(tex: Texture2D, max_size: Vector2) -> Control:
	var box := Control.new()
	box.name = "IntegerArtBox"
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var art := TextureRect.new()
	art.name = "IntegerArt"
	art.texture = tex
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(art)
	fit_integer_art(box, max_size)
	return box


static func fit_integer_art(box: Control, max_size: Vector2) -> void:
	var art := box.get_node("IntegerArt") as TextureRect
	var native := Vector2(maxf(1.0, float(art.texture.get_width())), maxf(1.0, float(art.texture.get_height())))
	var room := Vector2(floorf(max_size.x), floorf(max_size.y))
	var k: int = maxi(1, int(floorf(minf(room.x / native.x, room.y / native.y))))
	var drawn: Vector2 = native * float(k)
	var shown := Vector2(minf(drawn.x, room.x), minf(drawn.y, room.y))
	box.custom_minimum_size = shown
	art.size = drawn
	art.position = Vector2(even_px((shown.x - drawn.x) * 0.5), even_px((shown.y - drawn.y) * 0.5))


## Frames a PanelContainer as a "transmission window": very dark fill, 2px teal border,
## teal corner brackets — the same language as the battle panels. Used by the event /
## route-fork / run-failed screens so loose text reads as a contained transmission.
static func style_transmission_panel(panel: PanelContainer, border: Color = UI_PANEL_EDGE) -> void:
	# ui-unify: a plain CHROME section panel (was teal 2f6b7a with cyan brackets).
	panel.add_theme_stylebox_override("panel", make_hard_style(UI_PANEL, border, MIN_STROKE))
	_refresh_corner_brackets(panel, DT_CYAN, 26.0, 3.0, 8.0)


## 5%-of-width side inset (in UI coords) that yields a ~90%-wide content frame.
static func screen_frame_side_margin() -> int:
	var w: float = float(ProjectSettings.get_setting("display/window/size/viewport_width", 1080))
	return int(round(w * 0.05))


## Full-screen radial vignette (transparent centre → dark edges). Mouse-transparent.
static func make_vignette(strength: float = 0.5) -> TextureRect:
	var grad: Gradient = Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, strength)])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	tex.width = 256
	tex.height = 256
	var tr: TextureRect = TextureRect.new()
	tr.name = "Vignette"
	tr.texture = tex
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return tr


## Faint tiling scanline overlay (one dark row every `period` px). Mouse-transparent.
static func make_scanlines(alpha: float = 0.05, period: int = 3) -> TextureRect:
	var img: Image = Image.create(1, period, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.set_pixel(0, 0, Color(0.0, 0.0, 0.0, alpha))
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	var tr: TextureRect = TextureRect.new()
	tr.name = "Scanlines"
	tr.texture = tex
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return tr


## Adds the shared non-battle backdrop to `root`: faint scanlines + edge vignette.
## Call right after the base background ColorRect so screen content renders on top.
static func add_terminal_backdrop(root: Control, vignette_strength: float = 0.5, scan_alpha: float = 0.05) -> void:
	root.add_child(make_scanlines(scan_alpha))
	root.add_child(make_vignette(vignette_strength))


# ── The six standard components (Polish Build A, Kev 2026-07-14) ─────────────
# Every panel FRAME in the game is exactly ONE of six components — frame
# strength is a RANK, not a decoration. Too many equally strong frames was the
# border-noise defect: everything shouted, nothing ranked. The law:
#
#   normal_card   — quiet frame + filled header strip. Player-side surfaces
#                   pass hero_tint=true for the navy/teal family; neutral
#                   panels leave it false.
#   selected_card — strong cyan border. The ONLY routine use of strong cyan.
#   enemy_card    — rust chrome (meaning-first color law: rust = enemy).
#   reward_card   — amber accent. Rarity borders pass their color as `accent`
#                   (the rarity ladder stays intentionally offset from the
#                   gameplay palette).
#   modal         — elevated neutral panel over a dim scrim (make_modal_scrim);
#                   a muted side/rarity accent may pass as `accent`.
#   major_event   — the ceremonial tier (relics, evolutions, bosses). Strong
#                   gold is permitted here and ONLY here.
#
# Secondary grouping inside a component uses SPACING and filled header strips
# (component_header_style), never additional frames — INVARIANTS #7: grouping
# is filled plates, not stroked outlines. Anything that genuinely fits none of
# the six is reported to Kev, never invented as a silent seventh.
#
# Single source of truth: screens call component_style / style_component (and
# the existing button/bar/chip helpers); the component gate
# (scripts/checks/component_contract.py) bans raw StyleBox construction and
# strong-accent borders outside this file.

const COMPONENT_NORMAL := "normal_card"
const COMPONENT_SELECTED := "selected_card"
const COMPONENT_ENEMY := "enemy_card"
const COMPONENT_REWARD := "reward_card"
const COMPONENT_MODAL := "modal"
const COMPONENT_MAJOR := "major_event"

# ONE frame width for all six components (pixel-snap law: even, ≥ MIN_STROKE).
# Rank is conveyed by BORDER COLOR strength, never width — a width change on a
# state flip (normal ↔ selected) would move content margins and make layouts
# jump on tap.
const COMPONENT_FRAME_WIDTH := 4


static func component_style(kind: String, accent: Color = Color.TRANSPARENT, hero_tint: bool = false) -> StyleBoxFlat:
	var has_accent: bool = accent.a > 0.0
	match kind:
		COMPONENT_NORMAL:
			if hero_tint:
				return make_hard_style(DT_HERO_BG, PLAYER_ACCENT_DIM, COMPONENT_FRAME_WIDTH)
			return make_hard_style(UI_PANEL, UI_PANEL_EDGE, COMPONENT_FRAME_WIDTH)
		COMPONENT_SELECTED:
			# ui-unify: selection is the player's: PLAYER_ACCENT. Accent overrides
			# are ignored on purpose: selection strength has one source.
			return make_hard_style(DT_HERO_BG, PLAYER_ACCENT, COMPONENT_FRAME_WIDTH)
		COMPONENT_ENEMY:
			# ui-unify: the enemy side is the current ENCOUNTER_ACCENT.
			return make_hard_style(DT_ENEMY_BG, ENCOUNTER_ACCENT.darkened(0.3), COMPONENT_FRAME_WIDTH)
		COMPONENT_REWARD:
			return make_hard_style(UI_PANEL, accent if has_accent else CHROME_DIM, COMPONENT_FRAME_WIDTH)
		COMPONENT_MODAL:
			return make_hard_style(INSPECT_BG, accent if has_accent else INSPECT_BORDER, COMPONENT_FRAME_WIDTH)
		COMPONENT_MAJOR:
			# Strong gold — ceremonial tier only. Accent overrides ignored.
			return make_hard_style(DT_PANEL_BG, GOLD_ACCENT, COMPONENT_FRAME_WIDTH)
	push_error("[PixelUI] unknown component kind '%s'" % kind)
	return make_hard_style(DT_PANEL_BG, DT_FIELD_BORDER, COMPONENT_FRAME_WIDTH)


static func style_component(panel: Control, kind: String, accent: Color = Color.TRANSPARENT, hero_tint: bool = false) -> void:
	panel.add_theme_stylebox_override("panel", component_style(kind, accent, hero_tint))


## The filled header strip that ranks a component's title row WITHOUT another
## frame (borderless plate; INVARIANTS #7). Same fill family as the component.
static func component_header_style(kind: String, hero_tint: bool = false) -> StyleBoxFlat:
	match kind:
		COMPONENT_ENEMY:
			return make_hard_style(DT_ENEMY_HEADER, Color.TRANSPARENT, 0)
		COMPONENT_NORMAL, COMPONENT_SELECTED:
			if hero_tint or kind == COMPONENT_SELECTED:
				return make_hard_style(DT_HERO_HEADER, Color.TRANSPARENT, 0)
			return make_hard_style(DT_PANEL_BG.lightened(0.05), Color.TRANSPARENT, 0)
	return make_hard_style(DT_PANEL_BG.lightened(0.05), Color.TRANSPARENT, 0)


## The component a panel's border COLOR comes from, for surfaces that draw
## their own internal dividers/strips in the card's line color (battle card
## header underline, HP-track top rule). Keeps card anatomy on-token without a
## second color system.
static func component_line_color(kind: String, hero_tint: bool = false) -> Color:
	match kind:
		COMPONENT_SELECTED:
			return PLAYER_ACCENT
		COMPONENT_ENEMY:
			return ENCOUNTER_ACCENT.darkened(0.3)
		COMPONENT_REWARD:
			return CHROME_DIM
		COMPONENT_MODAL:
			return INSPECT_BORDER
		COMPONENT_MAJOR:
			return GOLD_ACCENT
	return PLAYER_ACCENT_DIM if hero_tint else UI_PANEL_EDGE


## Filled cyan badge plate (pick-order number on a selected tile) — the
## Selected component's sub-badge. The only routine cyan FILL; lives here so
## screens never construct strong-cyan styleboxes themselves.
static func selection_badge_style() -> StyleBoxFlat:
	return make_hard_style(PLAYER_ACCENT, PLAYER_ACCENT, 0)


## A squad tile frame (flat pixel B): PLAYER_ACCENT when picked; at rest the
## neutral card line (an unpicked hero is not the squad yet, so picks stand out). Same fill, width and geometry as COMPONENT_SELECTED (which stays cyan
## for the screens not moved yet: evolution, discard picker).
## `viewing`: the unit squad select's info bar shows; its border is bone
## (CHROME), over a pick's cobalt.
static func player_tile_style(picked: bool, viewing: bool = false) -> StyleBoxFlat:
	var border: Color = CHROME if viewing else (PLAYER_ACCENT if picked else UI_CARD_LINE)
	return make_hard_style(DT_HERO_BG, border, COMPONENT_FRAME_WIDTH)


## A one-hue icon (the cyan header / footer art) recolored into `tint`. Each
## pixel keeps its alpha and its brightness relative to the brightest pixel of
## the icon. Cached per path and color.
static var _system_icons: Dictionary = {}
static func tinted_icon(path: String, tint: Color) -> Texture2D:
	var key := "%s:%s" % [path, tint.to_html()]
	if _system_icons.has(key):
		return _system_icons[key]
	var source: Texture2D = _load_texture(path)
	if source == null:
		return null
	var image: Image = source.get_image()
	if image == null:
		return source
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var top: float = 0.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var texel: Color = image.get_pixel(x, y)
			if texel.a > 0.5:
				top = maxf(top, texel.get_luminance())
	top = maxf(top, 0.001)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var texel: Color = image.get_pixel(x, y)
			var k: float = clampf(texel.get_luminance() / top, 0.0, 1.0)
			image.set_pixel(x, y, Color(tint.r * k, tint.g * k, tint.b * k, texel.a))
	_system_icons[key] = ImageTexture.create_from_image(image)
	return _system_icons[key]


# ── Integer icon law (Polish Build B) ────────────────────────────────────────
# Pixel-art item icons render ONLY at whole-integer multiples of their native
# size — fractional scaling smears pixel art (pixel-snap law, INVARIANTS #14).
# Standard item art is 128 native. Low-res legacy art (<= ICON_LOW_RES_MAX
# native, currently only gravityWell at 32) renders at EXACTLY
# ICON_LOW_RES_SCALE (4x -> 128 effective) centered on a framed emblem plate
# (Reward-component chrome) so the coarser pixel density reads deliberate.
# Regression: scripts/debug/reward_model_test.gd walks every `item_icon`-tagged
# TextureRect and asserts the integer law.
const ICON_LOW_RES_MAX := 48
const ICON_LOW_RES_SCALE := 4


## An item icon in a `box_px`-square holder, scaled to the LARGEST integer
## multiple of its native size that fits (min 1x). Low-res art gets the exact
## 4x + emblem-plate treatment. The TextureRect carries meta `item_icon` for
## the integer-scale gate. `force_plate` puts the emblem plate behind EVERY
## icon (Build G: the unlock grids plate uniformly so the one low-res plate
## can't read as a selection highlight); standard surfaces leave it false.
static func make_integer_icon(tex: Texture2D, box_px: float, accent: Color = Color.TRANSPARENT, force_plate: bool = false) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(box_px, box_px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex == null:
		return holder
	var native_w: float = maxf(float(tex.get_width()), 1.0)
	var native_h: float = maxf(float(tex.get_height()), 1.0)
	var low_res: bool = native_w <= float(ICON_LOW_RES_MAX)
	var k: int = ICON_LOW_RES_SCALE if low_res else maxi(int(floor(box_px / maxf(native_w, native_h))), 1)
	# The art frame is native × k; fit_item_art places the art inside it (the
	# framing entry's centre / scale / insets — none means exactly the frame).
	var rect: Control = make_item_art(tex, Vector2(native_w, native_h) * float(k), ITEM_FIT_INTEGER)
	(rect.get_child(0) as TextureRect).set_meta("item_icon", true)
	if low_res or force_plate:
		# Emblem plate: Reward chrome behind the 4x glyph — the frame declares
		# the density choice instead of letting it read as a mistake.
		var plate := PanelContainer.new()
		plate.name = "EmblemPlate"
		plate.custom_minimum_size = Vector2(box_px, box_px)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_theme_stylebox_override("panel", component_style(COMPONENT_REWARD, accent))
		var inner := CenterContainer.new()
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(rect)
		plate.add_child(inner)
		holder.add_child(plate)
	else:
		holder.add_child(rect)
	return holder


## Shared modal scrim: a full-screen 60%-black ColorRect that dims (and, when
## block_input is true, blocks) the layer below a popup. Add it as the FIRST child of
## the popup's full-rect root/catcher so the popup panel renders on top of it. Every
## popup/overlay (inspect, equip chooser, reward detail, settings, help) uses this so
## nothing beneath a popup shows through at full brightness.
# ── Touch scrolling (playtest 2026-10-01) ────────────────────────────────────
# Godot 4.6's ScrollContainer only drag-scrolls when the press reaches it, and a
# MOUSE_FILTER_STOP child (card panels, buttons — Button's default) swallows it:
# a drag that started on a card scrolled nothing, and on a button it could
# press it. Every STOP control inside the scroll becomes PASS: it still gets its
# own input (taps, long-press, button presses — Godot cancels a button press
# once a drag starts scrolling) and the scroll sees the gesture. Content added
# later is converted too (after its builder finished setting filters). Sliders,
# scrollbars, text fields and nested scrolls keep their own drags.
static func enable_touch_scroll(scroll: ScrollContainer) -> void:
	if scroll == null or scroll.has_meta("touch_scroll"):
		return
	scroll.set_meta("touch_scroll", true)
	_pass_scroll_input(scroll, scroll)
	var watch := func(node: Node) -> void:
		if is_instance_valid(scroll) and scroll.is_ancestor_of(node):
			_pass_scroll_input.call_deferred(scroll, node)
	scroll.tree_entered.connect(func() -> void:
		if not scroll.get_tree().node_added.is_connected(watch):
			scroll.get_tree().node_added.connect(watch))
	scroll.tree_exiting.connect(func() -> void:
		if scroll.get_tree().node_added.is_connected(watch):
			scroll.get_tree().node_added.disconnect(watch))
	if scroll.is_inside_tree():
		scroll.get_tree().node_added.connect(watch)


static func _pass_scroll_input(scroll: ScrollContainer, node: Node) -> void:
	if not is_instance_valid(scroll) or not is_instance_valid(node):
		return
	if node != scroll and (node is ScrollContainer or node is Range or node is LineEdit or node is TextEdit):
		return
	if node != scroll and node is Control and (node as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		_pass_scroll_input(scroll, child)


static func make_modal_scrim(alpha: float = 0.6, block_input: bool = false) -> ColorRect:
	var scrim: ColorRect = ColorRect.new()
	scrim.name = "ModalScrim"
	scrim.color = Color(0.0, 0.0, 0.0, alpha)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP if block_input else Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return scrim


# m5x7 vertical-metrics compensation (Batch 3): the font's em box carries dead
# space above the visible caps, so Button's ascent+descent centering seats the
# VISIBLE glyphs low. Raising the bottom content margin by 2×offset shifts the
# centered text back up by offset. Every text-button styler applies this.
#
# The lift is CAPPED (Batch 6): the dead space is roughly font-size-independent
# (measured ~7 internal px at font 48 on the intercept buttons AND ~7 px at the
# DEPLOY font 84 → px 113), so a size-PROPORTIONAL 0.15 lift overshot badly at
# large fonts — the armed DEPLOY label rode ~10 px high in its 145 px slot.
# min(proportional, DEAD_SPACE_LIFT_PX) keeps small fonts untouched and stops big
# fonts from over-lifting: the correction only ever moves high text back DOWN
# toward center, never up. Pixel-snap safe — content margins are whole px.
const DEAD_SPACE_LIFT_PX := 7.0

static func _recenter_button_text(style: StyleBoxFlat, font_px: int) -> void:
	var offset: float = minf(roundf(float(font_px) * 0.15), DEAD_SPACE_LIFT_PX)
	style.set_content_margin(SIDE_BOTTOM, style.get_content_margin(SIDE_TOP) + 2.0 * offset)


## The canonical PRIMARY action button (BEGIN / ROLL / DEPLOY / CONFIRM / …).
## navy fill · 2px accent border · all-caps accent text · hover glow · pressed-invert ·
## border-less faded disabled · auto-tracking corner brackets. Pass amber = true for
## the risk / confirm variant. Uppercases the button label to match the UI.
## Flat pixel B: every caller is PLAYER_ACCENT (the player owns primary
## actions); `amber` is kept only for route fork's flagged card (old screen).
static func style_primary_button(button: Button, font_size: int = 32, amber: bool = false, brackets: bool = true) -> void:
	if button == null:
		return
	apply_pixel_font(button)
	button.text = button.text.to_upper()
	var font_px: int = scale_font_size(font_size)
	button.add_theme_font_size_override("font_size", font_px)
	var border: Color = BTN_AMBER_BORDER if amber else BTN_TEAL_BORDER
	var text_col: Color = BTN_AMBER_TEXT if amber else BTN_TEAL_TEXT
	var text_bright: Color = BTN_AMBER_TEXT_BRIGHT if amber else BTN_TEAL_TEXT_BRIGHT
	if not amber:
		border = PLAYER_ACCENT
		text_col = PLAYER_ACCENT_LIGHT
		text_bright = PLAYER_ACCENT_LIGHT.lightened(0.25)
	button.add_theme_color_override("font_color", text_col)
	button.add_theme_color_override("font_hover_color", text_bright)
	button.add_theme_color_override("font_focus_color", text_bright)
	button.add_theme_color_override("font_pressed_color", BTN_PRIMARY_INK if amber else PLAYER_ACCENT_INK)
	button.add_theme_color_override("font_disabled_color", BTN_DISABLED_TEXT)
	button.add_theme_constant_override("outline_size", 0)
	var states := {
		"normal": _primary_btn_style(BTN_PRIMARY_BG, border, false),
		"hover": _primary_btn_style(BTN_PRIMARY_BG_HOVER, border.lightened(0.22), true),
		"focus": _primary_btn_style(BTN_PRIMARY_BG_HOVER, border.lightened(0.22), true),
		"pressed": _primary_btn_style(border, border, false),  # inverted: accent fill
		"disabled": _primary_btn_disabled_style(),
	}
	for state_name in states.keys():
		var style: StyleBoxFlat = states[state_name]
		_recenter_button_text(style, font_px)
		button.add_theme_stylebox_override(state_name, style)
	_refresh_corner_brackets(button, border if brackets else Color.TRANSPARENT)


## Progress-locked button: no border, dimmed all-caps text, clearly inert. Used while a
## requirement is unmet (e.g. "1/3 SELECTED"); flip to style_primary_button once met.
static func style_locked_button(button: Button, font_size: int = 32) -> void:
	if button == null:
		return
	apply_pixel_font(button)
	var font_px: int = scale_font_size(font_size)
	button.add_theme_font_size_override("font_size", font_px)
	button.add_theme_color_override("font_color", BTN_DISABLED_TEXT)
	button.add_theme_color_override("font_hover_color", BTN_DISABLED_TEXT)
	button.add_theme_color_override("font_pressed_color", BTN_DISABLED_TEXT)
	button.add_theme_color_override("font_focus_color", BTN_DISABLED_TEXT)
	button.add_theme_color_override("font_disabled_color", BTN_DISABLED_TEXT)
	button.add_theme_constant_override("outline_size", 0)
	var locked: StyleBoxFlat = make_hard_style(BTN_PRIMARY_BG.darkened(0.2), Color(0, 0, 0, 0), 0)
	locked.set_content_margin_all(10.0)
	_recenter_button_text(locked, font_px)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, locked)
	_refresh_corner_brackets(button, Color.TRANSPARENT)


static func _primary_btn_style(bg: Color, border: Color, glow: bool) -> StyleBoxFlat:
	# MIN_STROKE (4): a 2px stroke assumed the window is exactly 540x1200; any
	# resize/clamp gives a fractional scale where 0.83-window-px edges drop to
	# zero rows (the clipped-border defect). 4px stays ≥1 window px everywhere.
	var s: StyleBoxFlat = make_hard_style(bg, border, MIN_STROKE)
	s.set_content_margin_all(10.0)
	if glow:
		s.shadow_color = Color(border.r, border.g, border.b, 0.45)
		s.shadow_size = 6
		s.shadow_offset = Vector2.ZERO
	return s


static func _primary_btn_disabled_style() -> StyleBoxFlat:
	# No border, muted fill — reads as clearly inert.
	var s: StyleBoxFlat = make_hard_style(BTN_PRIMARY_BG.darkened(0.15), Color(0, 0, 0, 0), 0)
	s.set_content_margin_all(10.0)
	return s


## Draws (or refreshes) eight thin corner-bracket arms as children of `target`, anchored
## to its four corners so they track any resize — the same accent-bracket motif as the
## panels. Pass Color.TRANSPARENT to remove existing brackets.
## ui-unify: no four-corner notches or brackets anywhere (one corner treatment:
## square). Every call now only clears brackets a node already had.
const CORNER_BRACKETS_ENABLED := false
static func _refresh_corner_brackets(target: Control, color: Color, arm: float = 16.0, thick: float = 3.0, inset: float = 4.0) -> void:
	var existing: Node = target.get_node_or_null("CornerBrackets")
	if existing != null:
		existing.queue_free()
	if color.a <= 0.0 or not CORNER_BRACKETS_ENABLED:
		return
	var holder: CornerBracketLayer = CornerBracketLayer.new()
	holder.name = "CornerBrackets"
	holder.color = color
	holder.arm = arm
	holder.thick = thick
	holder.inset = inset
	target.add_child(holder)


# Corner brackets drawn on the window pixel grid (pixel snap law, INVARIANTS
# #14). The old ColorRect arms were positioned in design space: a 3px arm is
# 1.25 window px and a 4px inset is 1.67 window px, so per-corner rounding
# rendered arms 1px-or-2px and randomly fused a bracket into the adjacent
# border ("clipped" corners on the choice screens). Drawing in integer window
# coordinates keeps every arm and every inset identical at all four corners.
class CornerBracketLayer extends Control:
	var color: Color = Color.WHITE
	var arm: float = 16.0
	var thick: float = 3.0
	var inset: float = 4.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		set_notify_transform(true)
		resized.connect(queue_redraw)
		# Window resizes change the FINAL transform without resizing controls.
		get_viewport().size_changed.connect(queue_redraw)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_TRANSFORM_CHANGED:
			queue_redraw()

	func _draw() -> void:
		if size.x < 2.0 or size.y < 2.0:
			return
		var xform: Transform2D = PixelUI.physical_transform(self)
		var sx: float = maxf(xform.get_scale().x, 0.0001)
		var sy: float = maxf(xform.get_scale().y, 0.0001)
		var origin: Vector2 = xform.get_origin()
		# Whole-window-pixel geometry, identical for all four corners.
		var left: int = int(round(origin.x))
		var right: int = int(round(origin.x + size.x * sx))
		var top: int = int(round(origin.y))
		var bottom: int = int(round(origin.y + size.y * sy))
		var inset_px: int = maxi(int(round(inset * sx)), 1)
		var arm_px: int = maxi(int(round(arm * sx)), 2)
		var thick_px: int = maxi(int(round(thick * sx)), 1)
		for ax in [0, 1]:
			for ay in [0, 1]:
				var cx: int = (left + inset_px) if ax == 0 else (right - inset_px - thick_px)
				var cy: int = (top + inset_px) if ay == 0 else (bottom - inset_px - thick_px)
				var hx: int = (left + inset_px) if ax == 0 else (right - inset_px - arm_px)
				var vy: int = (top + inset_px) if ay == 0 else (bottom - inset_px - arm_px)
				_draw_win_rect(Rect2i(hx, cy, arm_px, thick_px), origin, sx, sy)  # horizontal arm
				_draw_win_rect(Rect2i(cx, vy, thick_px, arm_px), origin, sx, sy)  # vertical arm

	func _draw_win_rect(win_rect: Rect2i, origin: Vector2, sx: float, sy: float) -> void:
		draw_rect(Rect2(
			(float(win_rect.position.x) - origin.x) / sx,
			(float(win_rect.position.y) - origin.y) / sy,
			float(win_rect.size.x) / sx,
			float(win_rect.size.y) / sy
		), color, true)


## Player-facing version text ("DEMO v0.4"). The number itself lives ONLY in
## project.godot config/version (also written to run saves as build_id); this
## adds the public-demo prefix so every stamp reads the same.
const VERSION_LABEL_PREFIX := "DEMO v"


static func version_label() -> String:
	return VERSION_LABEL_PREFIX + str(ProjectSettings.get_setting("application/config/version", ""))


static func style_label(label: Label, font_size: int, color: Color = TEXT_PRIMARY, outline_size: int = 2) -> void:
	apply_pixel_font(label)
	label.add_theme_font_size_override("font_size", scale_font_size(font_size))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.98))
	label.add_theme_constant_override("outline_size", outline_size)


## Long-form BODY copy (help/reference prose, ability descriptions, lore,
## intel-popup text): FONT_BODY_MIN + the line-spacing token, wrapped. The one
## styler for text a player READS in paragraphs — never use it for titles,
## buttons, names, or numbers (they keep their scan-tier sizes).
static func style_body_label(label: Label, font_size: int = FONT_BODY_MIN, color: Color = TEXT_PRIMARY) -> void:
	style_label(label, font_size, color)
	label.add_theme_constant_override("line_spacing", BODY_LINE_SPACING)


# ── HP number readout (the "n / m" printed over every HP bar) ──
# Bright white glyphs + a HARD BLACK outline so the number stays legible against
# whatever sits behind the bar — most importantly the red incoming-damage block
# (HP_CHIP), which otherwise washes the white text out. The single treatment for
# every HP number on every surface (battle card heroes + enemies, previews) —
# never restyle an HP label inline.
# HP_NUMBER_OUTLINE_PX is 2 DESIGN px on purpose: the game renders 1080-native
# scaled 0.5× into the 540 preview, so 2 design px = exactly ONE whole physical
# pixel there (an odd 1 would rasterize to a smeared half-pixel — pixel-snap law,
# INVARIANTS #14). font_size is applied verbatim (NOT scale_font_size'd): HP
# numbers are authored in card-local px like the rest of the card anatomy.
const HP_NUMBER_COLOR := Color(0.98, 0.99, 1.0, 1.0)
const HP_NUMBER_OUTLINE := Color(0.0, 0.0, 0.0, 1.0)
const HP_NUMBER_OUTLINE_PX := 2

static func style_hp_number(label: Label, font_size: int) -> void:
	apply_pixel_font(label)
	label.add_theme_font_size_override("font_size", text_px(font_size))
	label.add_theme_color_override("font_color", HP_NUMBER_COLOR)
	label.add_theme_color_override("font_outline_color", HP_NUMBER_OUTLINE)
	label.add_theme_constant_override("outline_size", HP_NUMBER_OUTLINE_PX)


## The Battle Block bitmap font (falls back to the pixel font, loudly).
static func get_battle_font() -> Font:
	if _battle_pixel_font == null:
		_battle_pixel_font = load("res://assets/fonts/battle_block.fnt") as Font
		if _battle_pixel_font == null:
			push_error("Battle Block bitmap font failed to load")
			_battle_pixel_font = get_pixel_font()
		else:
			_battle_pixel_font.fallbacks = [get_pixel_font()]
	return _battle_pixel_font


## Battle-only bitmap lettering. Other screens retain the original font.
## ui-unify: Battle Block is the DISPLAY face only; its size snaps to its own
## lattice (multiples of 32) so its bitmap pixels stay square.
static func style_battle_text(label: Control, ink: Color = BATTLE_TEXT, hp: bool = false) -> void:
	label.add_theme_font_override("font", get_battle_font())
	var block_px: float = float(lattice_px(label.get_theme_font_size("font_size"), "block")) / 16.0
	bind_block_snap(label, block_px, block_px)
	label.add_theme_color_override("font_color", ink)
	label.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
	label.add_theme_color_override("font_outline_color", BLACK_EDGE)
	label.add_theme_constant_override("outline_size", 2 if hp else 0)


static func style_progress_bar(bar: ProgressBar, fill: Color, bg: Color = Color(0.015, 0.020, 0.035, 1.0), border: Color = LINE_DIM) -> void:
	var bg_style: StyleBoxFlat = make_panel_style(bg, BLACK_EDGE, 2, 0)
	bg_style.shadow_size = 0
	bg_style.set_content_margin(SIDE_LEFT, 0.0)
	bg_style.set_content_margin(SIDE_TOP, 0.0)
	bg_style.set_content_margin(SIDE_RIGHT, 0.0)
	bg_style.set_content_margin(SIDE_BOTTOM, 0.0)
	var fill_style: StyleBoxFlat = make_panel_style(fill, fill, 0, 0)
	fill_style.shadow_size = 0
	fill_style.set_content_margin(SIDE_LEFT, 0.0)
	fill_style.set_content_margin(SIDE_TOP, 0.0)
	fill_style.set_content_margin(SIDE_RIGHT, 0.0)
	fill_style.set_content_margin(SIDE_BOTTOM, 0.0)
	bar.add_theme_stylebox_override("background", bg_style)
	bar.add_theme_stylebox_override("fill", fill_style)


# ── Safe area — single source of truth (INVARIANTS #14) ──────────────────────
# Insets in DESIGN-SPACE pixels (1080×2400 space), NOT physical pixels.
# All four read 0 on desktop and on any device without cutouts, so this is a
# no-op everywhere it isn't needed. PersistentHeader (always alive, autoload)
# drives refresh on ready + every root size change and emits safe_area_changed;
# screens read these at build time (every screen rebuilds on entry).
#
# Four named ints, deliberately — not a Vector4i. `Vector4i.w` meaning "left"
# is exactly the kind of thing that becomes a silent wrong-edge bug later.
static var safe_top := 0
static var safe_right := 0
static var safe_bottom := 0
static var safe_left := 0

# Android gesture-navigation reserve (Build #2, device-verified): on the
# Pixel 8, get_display_safe_area() reports the display CUTOUT only — bottom
# came back 0 while the gesture bar sits on the protocol row. Godot exposes no
# WindowInsets.Type.systemGestures(), so a fixed reserve is the ruling (option
# 1): crude but correct in practice, zero new machinery. Folded into
# safe_bottom itself inside refresh_safe_insets — every existing consumer
# inherits it; there is NO second inset path. 0 on every non-Android platform.
const SAFE_BOTTOM_RESERVE := 56
# Device-bezel blend color (Build J Item 2): the safe-area reserve bands render
# PURE BLACK so they read as hardware bezel, not as UI. Intentionally OUTSIDE
# the DT_* theme palette — do not "correct" it to a theme token.
const DT_BEZEL_BLACK := Color("000000")
# Conservative inset trims (design px, Build J Item 2): subtracted AFTER the
# ceil in refresh_safe_insets, clamped so no inset goes negative and the
# Android bottom never drops below BEZEL_BOTTOM_FLOOR. Deliberately SMALL —
# this ships to devices with different cutout geometry than the reference
# Pixel 8; 4px is reclaimable headroom, 20px is a regression on someone
# else's phone. These constants live HERE and nowhere else.
const SAFE_TOP_TRIM := 4
const SAFE_BOTTOM_TRIM := 4
const BEZEL_BOTTOM_FLOOR := 48

# Pure rule (headless-testable without being on Android): the effective bottom
# floor for a given OS. Only Android gets the gesture reserve.
static func bottom_reserve(os_name: String) -> int:
	return SAFE_BOTTOM_RESERVE if os_name == "Android" else 0


# ── Web-demo safe-area floors (Kev ruling 2026-07-24) ───────────────────────
# Browsers never surface the phone's safe area to Godot: on iPhone Safari and
# the itch.io embed, get_display_safe_area() returns the full canvas and
# get_display_cutouts() is empty, so all four insets evaluate 0 and the layout
# runs under the camera cutout (over the persistent header) and the screen's
# rounded corners (clipping corner buttons). True env(safe-area-inset-*)
# plumbing is out of scope for the demo; instead MOBILE-web builds get fixed
# minimum insets — generic-phone bezel protection, not any one device's
# geometry. Merged as max(reported, floor): if a browser ever starts
# reporting real insets, the larger value wins. Values in design px
# (1080×2400 space); tune against the SafeAreaDebug overlay (?safearea=1).
# Desktop web (incl. the 540×1200 itch preview) gets NO floors — they would
# visibly indent a bezel-less letterbox. Native/Android is untouched: the OS
# reports real insets there and floors would double-pad the playfield.
const WEB_SAFE_FLOOR_TOP := 72     # camera cutout / Dynamic Island band
const WEB_SAFE_FLOOR_BOTTOM := 48  # home-gesture area + corner radius
const WEB_SAFE_FLOOR_SIDE := 24    # rounded corners beside edge-flush buttons

# Mobile-web detection is USER-AGENT based (plus the iPadOS "Macintosh"-UA +
# maxTouchPoints tell), NOT touchscreen availability: touch-capable laptops
# report a touchscreen and would false-positive the floors onto desktop
# layouts. A mobile browser lying about its UA degrades to today's behaviour
# (no floors) — the benign failure direction.
static var _web_mobile_cached := -1  # -1 unknown, 0 no, 1 yes
static var _web_insets_logged := false


static func is_mobile_web() -> bool:
	if not OS.has_feature("web"):
		return false
	if _web_mobile_cached < 0:
		var mobile: Variant = JavaScriptBridge.eval(
			"/Android|iPhone|iPod/i.test(navigator.userAgent)"
			+ " || (/Macintosh|iPad/i.test(navigator.userAgent) && navigator.maxTouchPoints > 1)",
			true)
		_web_mobile_cached = 1 if bool(mobile) else 0
	return _web_mobile_cached == 1


# Single merge point: EVERY safe_* assignment routes through here, so all
# consumers (PersistentHeader band, screen edge margins, corner buttons,
# bottom gesture reserve) inherit the web floors with no per-screen changes.
static func _set_insets(top: int, right: int, bottom: int, left: int) -> void:
	var raw_top := top
	var raw_right := right
	var raw_bottom := bottom
	var raw_left := left
	if is_mobile_web():
		top = maxi(top, WEB_SAFE_FLOOR_TOP)
		right = maxi(right, WEB_SAFE_FLOOR_SIDE)
		bottom = maxi(bottom, WEB_SAFE_FLOOR_BOTTOM)
		left = maxi(left, WEB_SAFE_FLOOR_SIDE)
	safe_top = top
	safe_right = right
	safe_bottom = bottom
	safe_left = left
	if OS.has_feature("web") and not _web_insets_logged:
		_web_insets_logged = true
		print("[SafeArea] web insets: raw t/r/b/l %d/%d/%d/%d -> applied %d/%d/%d/%d (mobile_web=%s)" % [
			raw_top, raw_right, raw_bottom, raw_left, safe_top, safe_right, safe_bottom, safe_left, is_mobile_web()])


# Pure trim rule (Build J Item 2, headless-testable): applied AFTER the ceil.
# Top clamps at zero; bottom (already floored at the OS reserve by the caller)
# trims but never below BEZEL_BOTTOM_FLOOR on Android and never negative.
static func apply_inset_trims(top_design: int, bottom_design: int, os_name: String) -> Vector2i:
	var floor_bottom: int = BEZEL_BOTTOM_FLOOR if os_name == "Android" else 0
	return Vector2i(
		maxi(top_design - SAFE_TOP_TRIM, 0),
		maxi(bottom_design - SAFE_BOTTOM_TRIM, floor_bottom)
	)


# Debug-capture pin (Build J): when a capture harness simulates device insets
# on desktop, the real desktop refresh (root size_changed during window init)
# must not wipe them. Never set outside debug capture scripts.
static var sim_insets_pinned := false


static func refresh_safe_insets(vp: Viewport) -> void:
	if sim_insets_pinned:
		return
	# "No data" (zero window: headless/mid-init; zero safe rect: dummy driver)
	# means EVERYTHING IS SAFE — reset to the floor, never keep stale insets.
	# (The floor, not 0: an Android driver that reports nothing still has a
	# gesture bar.)
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		_set_insets(0, 0, bottom_reserve(OS.get_name()), 0)
		return

	# OS safe area, in PHYSICAL pixels, in SCREEN coordinates.
	var sa: Rect2i = DisplayServer.get_display_safe_area()
	if sa.size.x <= 0 or sa.size.y <= 0:
		_set_insets(0, 0, bottom_reserve(OS.get_name()), 0)
		return

	# Screen → window-relative. On mobile fullscreen the window origin is (0,0)
	# and this is a no-op; on a desktop WINDOW the safe area is the monitor's
	# usable rect in screen coords, and comparing it to the window size without
	# this correction yields garbage (negative/huge insets). A window fully
	# inside the usable area lands on 0 for all four after the max(0, …) below.
	var win_pos := Vector2(DisplayServer.window_get_position())
	var t: float = float(sa.position.y) - win_pos.y
	var l: float = float(sa.position.x) - win_pos.x
	var r: float = (win_pos.x + win.x) - float(sa.position.x + sa.size.x)
	var b: float = (win_pos.y + win.y) - float(sa.position.y + sa.size.y)

	# Belt-and-suspenders. In immersive/fullscreen, get_display_safe_area()
	# frequently returns the WHOLE screen even when a punch-hole exists.
	# Cutout rects are the ground truth. Only widen the edge each one touches.
	for c: Rect2 in DisplayServer.get_display_cutouts():
		var cp: Vector2 = c.position - win_pos
		if cp.y <= 1.0:
			t = maxf(t, cp.y + c.size.y)
		if cp.x <= 1.0:
			l = maxf(l, cp.x + c.size.x)
		if cp.x + c.size.x >= win.x - 1.0:
			r = maxf(r, win.x - cp.x)
		if cp.y + c.size.y >= win.y - 1.0:
			b = maxf(b, win.y - cp.y)

	t = maxf(t, 0.0)
	l = maxf(l, 0.0)
	r = maxf(r, 0.0)
	b = maxf(b, 0.0)

	# PHYSICAL → DESIGN. get_screen_transform() folds in BOTH the content scale
	# factor and the expand/letterbox offset. Do NOT hand-roll win/design — that
	# silently drops the offset and is wrong on any phone that isn't 1080 wide.
	# (This project ships stretch aspect "expand", so the offset is zero and the
	# inset LENGTHS convert by pure scale; the inverse transform keeps this
	# correct even if the aspect mode ever changes.)
	var inv: Transform2D = vp.get_screen_transform().affine_inverse()
	var sx: float = inv.x.x
	var sy: float = inv.y.y

	# Gesture-bar floor (Android): the reported bottom is cutouts-only and reads
	# 0 on a punch-hole phone; the reserve keeps the footer above the bar. The
	# conservative trims (Build J Item 2) reclaim the ceil's overshoot, clamped
	# by apply_inset_trims (never negative; Android bottom never < 48).
	var trimmed: Vector2i = apply_inset_trims(
		_to_design(t, sy),
		maxi(_to_design(b, sy), bottom_reserve(OS.get_name())),
		OS.get_name()
	)
	_set_insets(trimmed.x, _to_design(r, sx), trimmed.y, _to_design(l, sx))


# Always ceil. Rounding DOWN leaves content under the camera. Pure so the
# headless test can hit it without a live DisplayServer (pixel-snap law:
# insets are whole design pixels, always rounded up).
static func _to_design(physical_px: float, inv_scale: float) -> int:
	return int(ceil(physical_px * inv_scale))


# Optional presentation preference; safe for class-name consumers in test rigs.
# "No animations" turns off everything Reduced Motion does and more, so it
# counts as reduced motion too.
static func reduced_motion_enabled() -> bool:
	return _setting_on("reduced_motion") or no_animations_enabled()


const NO_ANIMATIONS_SETTING := "no_animations"
## Debug-build seam for the `no animations` gate's deliberate breaks (never set
## by the game): `ignored` makes the setting do nothing; `silent_stinger` drops
## the 20's stinger sound whenever motion is reduced (the pre-2026-10-08 bug).
const NO_ANIMATIONS_BREAK_ARG := "--no-animations-break="
static var _no_animations_break: String = "?"


## "No animations" (G-49, off by default): the animation Reduced Motion still
## leaves is off too (fades, bar drains, pulses, flashes, hit pauses). Dice
## motion and the pause between actions are not part of it.
static func no_animations_enabled() -> bool:
	return no_animations_break() != "ignored" and _setting_on(NO_ANIMATIONS_SETTING)


static func no_animations_break() -> String:
	if _no_animations_break == "?":
		_no_animations_break = ""
		if OS.is_debug_build():
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with(NO_ANIMATIONS_BREAK_ARG):
					_no_animations_break = arg.trim_prefix(NO_ANIMATIONS_BREAK_ARG)
	return _no_animations_break


static func _setting_on(key: String) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var settings := tree.root.get_node_or_null("SaveManager")
	return settings != null and bool(settings.get_setting(key, false))


# ══ UI restyle A components (2026-10-14) ═════════════════════════════════════
# Reusable pieces for the restyled screens (title, help/settings, reward); see
# docs/UI_RESTYLE.md. Pixel font throughout; every stroke is MIN_STROKE.

const UI_TAB_H := 12          # primary button's top-left tab height
const UI_TAB_W := 152         # its flat length before the stair-step slant
const UI_PRIMARY_BAR := 12    # primary button's thick left edge
const UI_SECONDARY_BAR := 8   # secondary button's lighter left bar
static var _ui_patches: Dictionary = {}


# A nine-patch texture from filled rects, cached by key. Margins are drawn 1:1.
static func _ui_patch(key: String, size: Vector2i, rects: Array) -> ImageTexture:
	if not _ui_patches.has(key):
		var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for entry: Array in rects:
			image.fill_rect(entry[0], entry[1])
		_ui_patches[key] = ImageTexture.create_from_image(image)
	return _ui_patches[key]


static func _ui_patch_style(texture: Texture2D, margins: Array, content: Array) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	var sides := [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]
	for i in range(4):
		style.set_texture_margin(sides[i], margins[i])
		style.set_content_margin(sides[i], content[i])
	return style


## Primary: dark fill, amber border, a thick amber left edge and ONE notched tab
## on the top-left edge (no four-corner notches). `fill`/`edge` vary by state.
static func ui_primary_style(fill: Color, edge: Color) -> StyleBoxTexture:
	var w: int = UI_TAB_W + UI_TAB_H + 40
	var h: int = UI_TAB_H + 40
	var rects: Array = [
		[Rect2i(0, UI_TAB_H, w, h - UI_TAB_H), edge],
		[Rect2i(UI_PRIMARY_BAR, UI_TAB_H + MIN_STROKE, w - UI_PRIMARY_BAR - MIN_STROKE, h - UI_TAB_H - MIN_STROKE * 2), fill],
	]
	for row in range(UI_TAB_H):
		# The tab's right end steps out one pixel per row: a hard 45-degree notch.
		rects.append([Rect2i(0, row, UI_TAB_W + row, 1), edge])
	var texture := _ui_patch("primary:%s:%s" % [fill.to_html(), edge.to_html()], Vector2i(w, h), rects)
	return _ui_patch_style(texture,
		[UI_TAB_W + UI_TAB_H + 8, UI_TAB_H + MIN_STROKE, MIN_STROKE, MIN_STROKE],
		[UI_PRIMARY_BAR + 16, UI_TAB_H + 10, 20, 10])


## Secondary (and, dimmed, disabled): dark fill, gray border, a thin lighter bar
## on the left edge.
static func ui_secondary_style(fill: Color, border: Color, bar: Color) -> StyleBoxTexture:
	var size := Vector2i(40, 40)
	var rects: Array = [
		[Rect2i(0, 0, size.x, size.y), border],
		[Rect2i(UI_SECONDARY_BAR, MIN_STROKE, size.x - UI_SECONDARY_BAR - MIN_STROKE, size.y - MIN_STROKE * 2), fill],
		[Rect2i(0, 0, UI_SECONDARY_BAR, size.y), bar],
	]
	var texture := _ui_patch("secondary:%s:%s:%s" % [fill.to_html(), border.to_html(), bar.to_html()], size, rects)
	return _ui_patch_style(texture, [UI_SECONDARY_BAR, MIN_STROKE, MIN_STROKE, MIN_STROKE],
		[UI_SECONDARY_BAR + 16, 10, 20, 10])


static func _ui_button_fonts(button: Button, font_size: int, normal: Color, hover: Color, pressed: Color, disabled: Color) -> void:
	# Screens that add their own hover pass skip buttons carrying this mark.
	button.set_meta("ui_styled", true)
	# ui-unify: every restyled button and tab is the LABEL role (m5x7, caps). Its
	# size is the caller's step on the m5x7 lattice: 64 for ordinary buttons and
	# tabs, larger whole multiples for a full-width primary (DEPLOY, CONFIRM).
	apply_type(button, TYPE_LABEL)
	button.add_theme_font_size_override("font_size", maxi(type_px(TYPE_LABEL), lattice_px(scale_font_size(font_size))))
	button.add_theme_color_override("font_color", normal)
	button.add_theme_color_override("font_hover_color", hover)
	button.add_theme_color_override("font_focus_color", hover)
	button.add_theme_color_override("font_pressed_color", pressed)
	button.add_theme_color_override("font_hover_pressed_color", pressed)
	button.add_theme_color_override("font_disabled_color", disabled)
	button.add_theme_constant_override("outline_size", 0)
	_refresh_corner_brackets(button, Color.TRANSPARENT)


## Kev, 2026-10-17: dark fill, PLAYER border and thick left edge, LIGHT text, the
## notch (the 2026-10-16 solid fill is reverted).
## The NOTCH RULE (flat pixel B): this notched PLAYER button is used ONLY for a
## screen's one primary action: the title's CONTINUE (BEGIN with no saved run),
## reward CONFIRM, DEPLOY SQUAD, and the battle's centre action (END TURN, and
## ROLL, the same button's other phase). Every other button is secondary
## (CHROME) or disabled (dimmed CHROME). Keyboard focus is a PLAYER outline
## around the button (_ui_focus_style), never a moved notch.
static func style_ui_primary_button(button: Button, font_size: int = 48) -> void:
	if button == null:
		return
	button.text = button.text.to_upper()
	_ui_button_fonts(button, font_size, PLAYER_ACCENT_LIGHT, PLAYER_ACCENT_LIGHT.lightened(0.25), PLAYER_ACCENT_INK, UI_TEXT_OFF)
	button.add_theme_stylebox_override("normal", ui_primary_style(UI_BUTTON, PLAYER_ACCENT))
	button.add_theme_stylebox_override("hover", ui_primary_style(UI_BUTTON.lightened(0.05), PLAYER_ACCENT.lightened(0.15)))
	button.add_theme_stylebox_override("focus", _ui_focus_style())
	button.add_theme_stylebox_override("pressed", ui_primary_style(PLAYER_ACCENT, PLAYER_ACCENT))
	button.add_theme_stylebox_override("disabled", _ui_disabled_style())


static func style_ui_secondary_button(button: Button, font_size: int = 44) -> void:
	if button == null:
		return
	button.text = button.text.to_upper()
	_ui_button_fonts(button, font_size, UI_TEXT, UI_TEXT, CHROME_INK, UI_TEXT_OFF)
	button.add_theme_stylebox_override("normal", ui_secondary_style(UI_BUTTON, UI_LINE, UI_BAR))
	button.add_theme_stylebox_override("hover", ui_secondary_style(UI_BUTTON.lightened(0.05), UI_LINE.lightened(0.15), UI_BAR.lightened(0.15)))
	button.add_theme_stylebox_override("focus", _ui_focus_style())
	button.add_theme_stylebox_override("pressed", ui_secondary_style(UI_BAR, UI_BAR, UI_BAR))
	button.add_theme_stylebox_override("disabled", _ui_disabled_style())


## Keyboard focus: a PLAYER_ACCENT outline just outside the button, drawn over
## its normal style. The button's own shape (and a primary's notch) never moves.
static func _ui_focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = PLAYER_ACCENT
	style.set_border_width_all(MIN_STROKE)
	style.set_expand_margin_all(float(MIN_STROKE * 2))
	return style


## The run-end report panel, victory and defeat (G-76, G-78): a dark fill at
## RESULT_REPORT_ALPHA over the operation's art, with the thin neutral border.
const RESULT_REPORT_ALPHA := 0.88
## A defeat draws the operation's image darker and grayer than a victory (G-78):
## the share of brightness taken off and of saturation taken out. 0 turns
## either off.
const DEFEAT_BACKDROP_DARKEN := 0.30
const DEFEAT_BACKDROP_DESATURATE := 0.50
static func result_report_style() -> StyleBoxFlat:
	var fill: Color = UI_PANEL
	fill.a = RESULT_REPORT_ALPHA
	var style: StyleBoxFlat = make_hard_style(fill, UI_LINE, MIN_STROKE)
	style.set_content_margin_all(float(GAP * 2))
	return style


## DESTRUCTIVE (ui-unify; ui-fix): a WARNING border and WARNING text on the
## button fill. No hazard stripes, no notch: a destructive confirm is never styled
## as the screen's primary action.
static func ui_destructive_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = make_hard_style(fill, edge, MIN_STROKE)
	style.content_margin_left = UI_SECONDARY_BAR + 16
	style.content_margin_top = 10
	style.content_margin_right = 20
	style.content_margin_bottom = 10
	return style


static func style_ui_destructive_button(button: Button, font_size: int = 44) -> void:
	if button == null:
		return
	button.text = button.text.to_upper()
	_ui_button_fonts(button, font_size, WARNING, WARNING.lightened(0.2), WARNING_INK, UI_TEXT_OFF)
	button.add_theme_stylebox_override("normal", ui_destructive_style(UI_BUTTON, WARNING))
	button.add_theme_stylebox_override("hover", ui_destructive_style(UI_BUTTON.lightened(0.05), WARNING.lightened(0.15)))
	button.add_theme_stylebox_override("focus", _ui_focus_style())
	button.add_theme_stylebox_override("pressed", ui_destructive_style(WARNING, WARNING))
	button.add_theme_stylebox_override("disabled", _ui_disabled_style())


## Disabled = the secondary shape, its border, bar and text dimmed.
static func _ui_disabled_style() -> StyleBoxTexture:
	return ui_secondary_style(UI_BUTTON.darkened(0.2), UI_LINE.darkened(0.45), UI_BAR.darkened(0.55))


## Tabs: equal-width boxes; active is solid PLAYER_ACCENT with dark text,
## inactive dark with gray text.
static func style_ui_tab(button: Button, active: bool, font_size: int = 36) -> void:
	if button == null:
		return
	var fill: Color = PLAYER_ACCENT if active else UI_BUTTON
	var border: Color = PLAYER_ACCENT if active else UI_LINE
	var ink: Color = PLAYER_ACCENT_INK if active else UI_TEXT_DIM
	_ui_button_fonts(button, font_size, ink, PLAYER_ACCENT_INK if active else UI_TEXT, ink, UI_TEXT_OFF)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var hover: bool = state == "hover" and not active
		var style: StyleBoxFlat = make_hard_style(fill.lightened(0.05) if hover else fill, border.lightened(0.15) if hover else border, MIN_STROKE)
		style.set_content_margin_all(8.0)
		button.add_theme_stylebox_override(state, style)


## Toggle: ON is a PLAYER_ACCENT outline and light player text, OFF a gray
## outline and gray text. Also sets the ON / OFF label.
static func style_ui_toggle(button: Button, font_size: int = 36) -> void:
	if button == null:
		return
	var on: bool = button.button_pressed
	var ink: Color = PLAYER_ACCENT_LIGHT if on else UI_TEXT_DIM
	button.text = "ON" if on else "OFF"
	_ui_button_fonts(button, font_size, ink, ink.lightened(0.2), ink, UI_TEXT_OFF)
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		var style: StyleBoxFlat = make_hard_style(UI_PANEL, PLAYER_ACCENT if on else UI_LINE, MIN_STROKE)
		style.set_content_margin_all(8.0)
		button.add_theme_stylebox_override(state, style)


## Slider: PLAYER_ACCENT filled track, dark empty track, light player thumb.
static var _ui_thumb: ImageTexture = null
static func style_ui_slider(slider: HSlider, track_px: int = 16) -> void:
	var track: StyleBoxFlat = make_hard_style(UI_TRACK, UI_TRACK, 0)
	var fill: StyleBoxFlat = make_hard_style(PLAYER_ACCENT, PLAYER_ACCENT, 0)
	for style: StyleBoxFlat in [track, fill]:
		style.content_margin_top = track_px * 0.5
		style.content_margin_bottom = track_px * 0.5
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	if _ui_thumb == null:
		var thumb_image := Image.create(24, 56, false, Image.FORMAT_RGBA8)
		thumb_image.fill(PLAYER_ACCENT_LIGHT)
		_ui_thumb = ImageTexture.create_from_image(thumb_image)
	for icon in ["grabber", "grabber_highlight", "grabber_disabled"]:
		slider.add_theme_icon_override(icon, _ui_thumb)


## Section panel: a dark panel, its header in large pixel caps over a thin gray
## rule. Returns the body the caller fills with rows (make_ui_row).
static func make_ui_section(parent: Container, title: String, font_size: int = 56) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = make_hard_style(UI_PANEL, UI_PANEL_EDGE, MIN_STROKE)
	style.set_content_margin_all(24.0)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var header := Label.new()
	header.text = title.to_upper()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	style_label(header, font_size, UI_TEXT, 0)
	column.add_child(header)
	var rule := ColorRect.new()
	rule.color = UI_RULE
	rule.custom_minimum_size = Vector2(0, MIN_STROKE)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rule)
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	body.add_theme_constant_override("separation", 12)
	column.add_child(body)
	return body


## A row plate inside a section: a slightly lighter filled background.
static func make_ui_row() -> PanelContainer:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = make_hard_style(UI_ROW, UI_ROW, 0)
	style.content_margin_left = 20.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	row.add_theme_stylebox_override("panel", style)
	return row


## Selectable card: gray border at rest; selected is an amber border over a faint
## amber-tinted fill.
static func ui_card_style(selected: bool) -> StyleBoxFlat:
	if selected:
		return make_hard_style(UI_PANEL.lerp(PLAYER_ACCENT, 0.12), PLAYER_ACCENT, MIN_STROKE)
	return make_hard_style(UI_PANEL, UI_CARD_LINE, MIN_STROKE)


## The square frame around a piece of item art on a selectable card. The art
## inside is the shared item framing (make_integer_icon), unchanged.
static func ui_art_frame_style(selected: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = make_hard_style(UI_BG, PLAYER_ACCENT_DIM if selected else UI_CARD_LINE, MIN_STROKE)
	style.set_content_margin_all(8.0)
	return style


## A placeholder art backdrop on the shared pixel grid: `painter` draws in design
## px into a SubViewport a quarter of the screen's size, shown 4x with NEAREST,
## so every edge lands on the 4 design px grid the portraits use. The painter
## draws with draw_set_transform scale 1 / UI_ART_PX.
const UI_ART_PX := 4
static func make_art_grid_view(painter: Control, view_name: String) -> SubViewportContainer:
	var view := SubViewportContainer.new()
	view.name = view_name
	view.stretch = true
	view.stretch_shrink = UI_ART_PX
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	view.add_child(viewport)
	viewport.add_child(painter)
	painter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return view


## Recolors a layer of the title logo into CHROME. `glow` keeps the layer's
## additive blend (the core and PROTOCOL glows) and tints all of it; otherwise
## only the logo's saturated teal pixels (the core and the PROTOCOL letters) are
## keyed over, and its grays stay gray.
static var _accent_materials: Dictionary = {}


# After F10: re-tint the cached logo materials (the CHROME parts).
static func _refresh_logo_materials() -> void:
	for material: ShaderMaterial in _accent_materials.values():
		material.set_shader_parameter("accent", CHROME)
	if _logo_base_material != null:
		_logo_base_material.set_shader_parameter("accent", CHROME)


# ── Title logo (flat pixel B) ──
# The reactor core glows in PLAYER: a light core, a cobalt pixel ring, a dim
# rim, in hard steps (no blur); the PROTOCOL line stays CHROME. The base layer
# holds both the core and the PROTOCOL letters in the same teal, so the base
# shader splits them by height: everything above LOGO_CORE_SPLIT (the core sits
# in the top 330 of the art's 504 rows, PROTOCOL starts at row 382) is core.
const LOGO_CORE_SPLIT := 360.0 / 504.0
static var _logo_base_material: ShaderMaterial = null
static var _logo_core_material: ShaderMaterial = null


static func _logo_core_ramp(material: ShaderMaterial) -> void:
	material.set_shader_parameter("core_light", PROTOCOL_ACCENT)
	material.set_shader_parameter("core_mid", PLAYER_ACCENT)
	material.set_shader_parameter("core_dim", PLAYER_ACCENT_DIM)
	material.set_shader_parameter("core_deep", PLAYER_ACCENT_DIM.darkened(0.5))


## The logo's base layer: core teal in the PLAYER ramp, PROTOCOL teal in CHROME,
## grays untouched.
static func logo_base_material() -> ShaderMaterial:
	if _logo_base_material == null:
		var shader := Shader.new()
		shader.code = LOGO_BASE_SHADER
		_logo_base_material = ShaderMaterial.new()
		_logo_base_material.shader = shader
		_logo_base_material.set_shader_parameter("accent", CHROME)
		_logo_base_material.set_shader_parameter("core_split", LOGO_CORE_SPLIT)
		_logo_core_ramp(_logo_base_material)
	return _logo_base_material


## The core glow layer (additive): its light centre and its saturated ring in
## PLAYER steps; the faint gray speckle around it is dropped.
static func logo_core_material() -> ShaderMaterial:
	if _logo_core_material == null:
		var shader := Shader.new()
		shader.code = LOGO_CORE_SHADER
		_logo_core_material = ShaderMaterial.new()
		_logo_core_material.shader = shader
		_logo_core_ramp(_logo_core_material)
	return _logo_core_material


const LOGO_BASE_SHADER := """shader_type canvas_item;
uniform vec4 accent : source_color;
uniform vec4 core_light : source_color;
uniform vec4 core_mid : source_color;
uniform vec4 core_dim : source_color;
uniform vec4 core_deep : source_color;
uniform float core_split = 0.714;
varying vec4 tint_modulate;
void vertex() {
	tint_modulate = COLOR;
}
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	float lum = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
	float top = max(texel.r, max(texel.g, texel.b));
	float sat = top > 0.0 ? (top - min(texel.r, min(texel.g, texel.b))) / top : 0.0;
	bool teal = sat > 0.3 && texel.g > texel.r + 0.10 && abs(texel.g - texel.b) < 0.16;
	vec3 rgb = texel.rgb;
	if (teal) {
		if (UV.y < core_split) {
			rgb = lum < 0.17 ? core_deep.rgb : (lum < 0.28 ? core_dim.rgb : core_mid.rgb);
		} else {
			rgb = accent.rgb * clamp(lum * 2.6, 0.0, 1.25);
		}
	}
	COLOR = vec4(rgb, texel.a) * tint_modulate;
}
"""


const LOGO_CORE_SHADER := """shader_type canvas_item;
render_mode blend_add;
uniform vec4 core_light : source_color;
uniform vec4 core_mid : source_color;
uniform vec4 core_dim : source_color;
uniform vec4 core_deep : source_color;
varying vec4 tint_modulate;
void vertex() {
	tint_modulate = COLOR;
}
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	float lum = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
	float top = max(texel.r, max(texel.g, texel.b));
	float sat = top > 0.0 ? (top - min(texel.r, min(texel.g, texel.b))) / top : 0.0;
	if (sat < 0.35 && lum < 0.6) {
		discard;
	}
	vec3 rgb = lum >= 0.7 ? core_light.rgb : (lum >= 0.42 ? core_mid.rgb : core_dim.rgb);
	COLOR = vec4(rgb, texel.a) * tint_modulate;
}
"""


static func accent_tint_material(glow: bool) -> ShaderMaterial:
	if not _accent_materials.has(glow):
		var shader := Shader.new()
		shader.code = ACCENT_TINT_SHADER % ["blend_add" if glow else "blend_mix", "1.15" if glow else "2.6", "tinted" if glow else "teal ? tinted : texel.rgb"]
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("accent", CHROME)
		_accent_materials[glow] = material
	return _accent_materials[glow]


const ACCENT_TINT_SHADER := """shader_type canvas_item;
render_mode %s;
uniform vec4 accent : source_color;
varying vec4 tint_modulate;
void vertex() {
	tint_modulate = COLOR;
}
void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	float lum = dot(texel.rgb, vec3(0.299, 0.587, 0.114));
	float top = max(texel.r, max(texel.g, texel.b));
	float sat = top > 0.0 ? (top - min(texel.r, min(texel.g, texel.b))) / top : 0.0;
	bool teal = sat > 0.3 && texel.g > texel.r + 0.10 && abs(texel.g - texel.b) < 0.16;
	vec3 tinted = accent.rgb * clamp(lum * %s, 0.0, 1.25);
	COLOR = vec4(%s, texel.a) * tint_modulate;
}
"""
