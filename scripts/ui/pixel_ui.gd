class_name PixelUI
extends RefCounted

const BG_PANEL := Color(0.050, 0.055, 0.078, 1.0)
const BG_PANEL_ALT := Color(0.075, 0.085, 0.120, 1.0)
const LINE_DIM := Color(0.18, 0.23, 0.34, 1.0)
const LINE_BRIGHT := Color(0.36, 0.55, 0.78, 1.0)
const TEXT_PRIMARY := Color(0.88, 0.91, 0.88, 1.0)
const TEXT_MUTED := Color(0.52, 0.60, 0.70, 1.0)
const HERO_ACCENT := Color(0.20, 0.66, 0.50, 1.0)
const ENEMY_ACCENT := Color(0.74, 0.28, 0.23, 1.0)
const GOLD_ACCENT := Color(0.82, 0.58, 0.24, 1.0)
const BLACK_EDGE := Color(0.005, 0.006, 0.010, 1.0)
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
# Hero (navy/cyan) card tokens
static var DT_HERO_BG := Color("0a141c")
static var DT_HERO_BORDER := Color("235461")
static var DT_HERO_HEADER := Color("0d2029")
static var DT_HERO_NAME := Color("56c7d9")
static var DT_HERO_TRACK := Color("0a1218")
static var DT_HERO_DITHER := Color("5ac8dc")
static var DT_CYAN := Color("3fd0e2")
static var DT_CYAN_BRIGHT := Color("6fe0ef")
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
static var BTN_TEAL_BORDER := Color("3fd0e2")       # = DT_CYAN
static var BTN_TEAL_TEXT := Color("5fd8ea")
static var BTN_TEAL_TEXT_BRIGHT := Color("9df0fb")
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
static var RARITY_COMMON := Color("7a8290")
static var RARITY_UNCOMMON := Color("5b7fe8")
static var RARITY_RARE := Color("9d52d8")
static var RARITY_EPIC := Color("9d52d8")
static var RARITY_LEGENDARY := Color("ff8230")

# ── Inspect popup tokens (the unified long-press reveal) ──
# Neutral Dithered-Terminal surface; side/rarity accents are layered on by the caller
# (DT_HERO_BORDER / DT_ENEMY_BORDER / rarity_color). Border/divider use the DT line tones.
static var INSPECT_BG := Color("0b0f13")
static var INSPECT_BORDER := Color("2a3540")
static var INSPECT_DIVIDER := Color("1b2226")
static var INSPECT_TEXT := Color("dfe9ec")
static var INSPECT_TEXT_MUTED := Color("8a99a6")
static var INSPECT_TEXT_DIM := Color("57646e")
# Single shared long-press hold duration (seconds), tuned for Android touch. Defined once
# here so no surface re-declares it.
const INSPECT_HOLD_SEC := 0.42

const DITHER_TILE := "res://assets/ui/dither_2x2.png"

const UI_FONT_PATH := "res://assets/fonts/m5x7.ttf"
const UI_FONT_SCALE := 1.35
const UI_FONT_MIN_SIZE := 20
const UI_FONT_STEPS := [20, 24, 28, 32, 36, 42, 48, 56, 64, 72]
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

static func min_stroke(width: int) -> int:
	if width <= 0:
		return width
	return maxi(width + (width & 1), MIN_STROKE)


static func make_panel_style(bg: Color = BG_PANEL, border: Color = LINE_DIM, border_width: int = 2, corner: int = 4) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(min_stroke(border_width))
	style.corner_radius_top_left = corner
	style.corner_radius_top_right = corner
	style.corner_radius_bottom_left = corner
	style.corner_radius_bottom_right = corner
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
		_pixel_font = font
	return _pixel_font


static func apply_pixel_font(control: Control) -> void:
	control.add_theme_font_override("font", get_pixel_font())


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
# Only `rampage` and `tag` remain iconless (return "" → rendered as text).
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
# hero portrait uses this aspect; a screen needing a different physical size
# scales this aspect — it never defines its own. A TALLER display frame
# cover-fits by height and trims the sides (harmless); a SHORTER frame trims
# the bottom and destroys the framing — that was the 320×486 bug: squad select
# and the battle card showed different windows onto the same art, and every
# framing pass authored against the wrong one. Do not define a portrait window
# anywhere else, and do not hardcode a second aspect.
const HERO_PORTRAIT_REGION := Vector2(328.0, 380.0)

# ── Hero portrait display zoom (display-time only; the PNGs stay pristine) ──
# HERO_PORTRAIT_ZOOM: uniform extra scale applied inside cover_fit_portrait to
# HERO art only (>1.0 = tighter). Enemies are the framing reference and are
# NEVER zoomed. 1.2 picked by Kev 2026-07-12 against the RUST reference card.
# HERO_PORTRAIT_ANCHOR_Y (+ per-portrait HERO_PORTRAIT_ANCHOR_Y_OVERRIDES):
# vertical bias as a FRACTION of the frame height — positive shifts the art UP
# in the frame (0.03 ≈ 11 px in the 380-tall region), negative down; scales
# with the frame like PORTRAIT_TOP_PAD. Overrides add on top of the global.
# The breaker family's source art draws the body lower in the canvas to fit
# tall antennas/crown — the per-unit anchors re-seat their helmet DOMES at the
# roster height (derived from the hand-declared portrait_anchors.json head_top
# values, NOT from pixels). Antenna/crown crop-off is ruled acceptable
# (TRUTH.md): the head is what must frame consistently, never the headgear.
# HERO_PORTRAIT_ZOOM_OVERRIDES: per-portrait multiplier on top of the global
# zoom, keyed by portrait key ("combat", "medic_synth", …). Kept EMPTY by
# design — the global zoom does the work; add an entry only for a genuine
# outlier, never as a substitute for fixing the global value.
const HERO_PORTRAIT_ZOOM := 1.2
const HERO_PORTRAIT_ANCHOR_Y := 0.0
const HERO_PORTRAIT_ZOOM_OVERRIDES := {}
const HERO_PORTRAIT_ANCHOR_Y_OVERRIDES := {
	"breaker": 0.105,
	"breaker_noise": 0.166,
	"breaker_nullwire": 0.237,
}


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

# The small role-color square is retained as a component affordance for later
# roster work, but is intentionally suppressed during the beta. Screens which
# host it must consult this single flag rather than carrying local exceptions.
const SHOW_BETA_UNIT_BADGES := false

static func cover_fit_portrait(tex_rect: TextureRect, frame_size: Vector2) -> void:
	if tex_rect == null:
		return
	var fw: float = frame_size.x
	var fh: float = frame_size.y
	if fw < 2.0 or fh < 2.0:
		return
	var tex: Texture2D = tex_rect.texture
	if tex == null:
		tex_rect.position = Vector2.ZERO
		tex_rect.size = frame_size
		return
	var tw: float = float(tex.get_width())
	var th: float = float(tex.get_height())
	if tw < 1.0 or th < 1.0:
		tex_rect.position = Vector2.ZERO
		tex_rect.size = frame_size
		return
	var cover_scale: float = maxf(fw / tw, fh / th)
	# HERO art only: uniform display zoom (+ optional per-portrait override) and
	# vertical anchor bias (fraction of frame height, + per-portrait override).
	# Enemies stay untagged → zoom 1.0, anchor 0.
	var anchor_shift: float = 0.0
	if bool(tex.get_meta("hero_portrait", false)):
		var key: String = str(tex.get_meta("portrait_key", ""))
		cover_scale *= HERO_PORTRAIT_ZOOM * float(HERO_PORTRAIT_ZOOM_OVERRIDES.get(key, 1.0))
		anchor_shift = (HERO_PORTRAIT_ANCHOR_Y + float(HERO_PORTRAIT_ANCHOR_Y_OVERRIDES.get(key, 0.0))) * fh
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
static func style_dt_icon_button(button: BaseButton, icon_path: String, border_color: Color = DT_BTN_BORDER, icon_modulate: Color = Color.WHITE) -> void:
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
	var b := button as Button
	b.text = ""
	b.flat = false
	# No focus ring — keeps every button visually identical (a focused button was
	# rendering with a different edge/outline).
	b.focus_mode = Control.FOCUS_NONE
	b.icon = _load_texture(icon_path)
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
	return scaled_size


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
	var iw: float = maxf(1.0, float(tex.get_width()))
	var ih: float = maxf(1.0, float(tex.get_height()))
	var scale: float = minf(max_w / iw, max_h / ih)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(round(iw * scale), round(ih * scale))
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.clip_contents = true
	frame.add_theme_stylebox_override("panel", make_hard_style(DT_PANEL_BG, border, 2))
	var art := TextureRect.new()
	art.texture = tex
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED  # frame == image aspect, so no crop
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(art)
	add_corner_brackets(frame, border, 24.0, 3.0, 8.0)
	return frame


## Frames a PanelContainer as a "transmission window": very dark fill, 2px teal border,
## teal corner brackets — the same language as the battle panels. Used by the event /
## route-fork / run-failed screens so loose text reads as a contained transmission.
static func style_transmission_panel(panel: PanelContainer, border: Color = Color("2f6b7a")) -> void:
	panel.add_theme_stylebox_override("panel", make_hard_style(DT_PANEL_BG, border, 2))
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
				return make_hard_style(DT_HERO_BG, DT_HERO_BORDER, COMPONENT_FRAME_WIDTH)
			return make_hard_style(DT_PANEL_BG, DT_FIELD_BORDER, COMPONENT_FRAME_WIDTH)
		COMPONENT_SELECTED:
			# Strong cyan — selection only. Accent overrides are IGNORED here on
			# purpose: selection strength has one source.
			return make_hard_style(DT_HERO_BG, DT_CYAN, COMPONENT_FRAME_WIDTH)
		COMPONENT_ENEMY:
			return make_hard_style(DT_ENEMY_BG, DT_ENEMY_BORDER, COMPONENT_FRAME_WIDTH)
		COMPONENT_REWARD:
			return make_hard_style(DT_PANEL_BG, accent if has_accent else DT_AMBER, COMPONENT_FRAME_WIDTH)
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
			return DT_CYAN
		COMPONENT_ENEMY:
			return DT_ENEMY_BORDER
		COMPONENT_REWARD:
			return DT_AMBER
		COMPONENT_MODAL:
			return INSPECT_BORDER
		COMPONENT_MAJOR:
			return GOLD_ACCENT
	return DT_HERO_BORDER if hero_tint else DT_FIELD_BORDER


## Filled cyan badge plate (pick-order number on a selected tile) — the
## Selected component's sub-badge. The only routine cyan FILL; lives here so
## screens never construct strong-cyan styleboxes themselves.
static func selection_badge_style() -> StyleBoxFlat:
	return make_hard_style(DT_CYAN, DT_CYAN, 0)


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
## the integer-scale gate.
static func make_integer_icon(tex: Texture2D, box_px: float, accent: Color = Color.TRANSPARENT) -> Control:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(box_px, box_px)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex == null:
		return holder
	var native_w: float = maxf(float(tex.get_width()), 1.0)
	var native_h: float = maxf(float(tex.get_height()), 1.0)
	var low_res: bool = native_w <= float(ICON_LOW_RES_MAX)
	var k: int = ICON_LOW_RES_SCALE if low_res else maxi(int(floor(box_px / maxf(native_w, native_h))), 1)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.custom_minimum_size = Vector2(native_w, native_h) * float(k)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_meta("item_icon", true)
	if low_res:
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


static func style_button(button: Button, fill: Color = BG_PANEL_ALT, border: Color = LINE_BRIGHT, font_size: int = 20) -> void:
	apply_pixel_font(button)
	var font_px: int = scale_font_size(font_size)
	button.add_theme_font_size_override("font_size", font_px)
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_focus_color", TEXT_PRIMARY)
	button.add_theme_constant_override("outline_size", 3)
	button.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.98))
	var states := {
		"normal": make_panel_style(fill, border.darkened(0.10), 4, 0),
		"hover": make_panel_style(fill, border.lightened(0.05), 4, 0),
		"pressed": make_panel_style(fill.darkened(0.18), border.darkened(0.12), 4, 0),
		"disabled": make_panel_style(fill.darkened(0.25), border.darkened(0.45), 4, 0),
	}
	for state_name in states.keys():
		var style: StyleBoxFlat = states[state_name]
		_recenter_button_text(style, font_px)
		button.add_theme_stylebox_override(state_name, style)


## The canonical PRIMARY action button (BEGIN / ROLL / DEPLOY / CONFIRM / …).
## navy fill · 2px accent border · all-caps accent text · hover glow · pressed-invert ·
## border-less faded disabled · auto-tracking corner brackets. Pass amber = true for
## the risk / confirm variant. Uppercases the button label to match the UI.
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
	button.add_theme_color_override("font_color", text_col)
	button.add_theme_color_override("font_hover_color", text_bright)
	button.add_theme_color_override("font_focus_color", text_bright)
	button.add_theme_color_override("font_pressed_color", BTN_PRIMARY_INK)
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
static func _refresh_corner_brackets(target: Control, color: Color, arm: float = 16.0, thick: float = 3.0, inset: float = 4.0) -> void:
	var existing: Node = target.get_node_or_null("CornerBrackets")
	if existing != null:
		existing.queue_free()
	if color.a <= 0.0:
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
	label.add_theme_font_size_override("font_size", maxi(1, font_size))
	label.add_theme_color_override("font_color", HP_NUMBER_COLOR)
	label.add_theme_color_override("font_outline_color", HP_NUMBER_OUTLINE)
	label.add_theme_constant_override("outline_size", HP_NUMBER_OUTLINE_PX)


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

# Pure rule (headless-testable without being on Android): the effective bottom
# floor for a given OS. Only Android gets the gesture reserve.
static func bottom_reserve(os_name: String) -> int:
	return SAFE_BOTTOM_RESERVE if os_name == "Android" else 0


static func refresh_safe_insets(vp: Viewport) -> void:
	# "No data" (zero window: headless/mid-init; zero safe rect: dummy driver)
	# means EVERYTHING IS SAFE — reset to the floor, never keep stale insets.
	# (The floor, not 0: an Android driver that reports nothing still has a
	# gesture bar.)
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		safe_top = 0
		safe_right = 0
		safe_bottom = bottom_reserve(OS.get_name())
		safe_left = 0
		return

	# OS safe area, in PHYSICAL pixels, in SCREEN coordinates.
	var sa: Rect2i = DisplayServer.get_display_safe_area()
	if sa.size.x <= 0 or sa.size.y <= 0:
		safe_top = 0
		safe_right = 0
		safe_bottom = bottom_reserve(OS.get_name())
		safe_left = 0
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

	safe_top = _to_design(t, sy)
	safe_right = _to_design(r, sx)
	# Gesture-bar floor (Android): the reported bottom is cutouts-only and reads
	# 0 on a punch-hole phone; the reserve keeps the footer above the bar.
	safe_bottom = maxi(_to_design(b, sy), bottom_reserve(OS.get_name()))
	safe_left = _to_design(l, sx)


# Always ceil. Rounding DOWN leaves content under the camera. Pure so the
# headless test can hit it without a live DisplayServer (pixel-snap law:
# insets are whole design pixels, always rounded up).
static func _to_design(physical_px: float, inv_scale: float) -> int:
	return int(ceil(physical_px * inv_scale))
