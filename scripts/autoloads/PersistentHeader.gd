extends CanvasLayer

## Always-living global header bar (registered as the `PersistentHeader` autoload).
##
## It is identical on every screen and is NEVER rebuilt on scene transitions — the
## node survives all scene loads. No individual scene contains its own header bar.
##
## The header's buttons act on the battle screen when one is active: `BattleScene`
## binds Callables on `_ready` (and clears them on `_exit_tree`). On every other
## screen no Callables are bound, so the buttons are present but inert (no-op).
##
## Visual language pulls entirely from PixelUI (the single source of truth) — see
## scripts/ui/pixel_ui.gd. The fixed bottom divider here REPLACES the battle scene's
## old dynamic HeaderDivider.

## The header's CONTENT height in design px. The band NODE can be taller on a
## device with a display cutout (band_height() = this + PixelUI.safe_top) — the
## band chrome paints underneath the camera so the punch-hole sits on solid
## header instead of on game art, and only the Bar contents shift down.
## This constant is the single source for 144: _apply_safe_area() writes it
## into the .tscn's HeaderBand.offset_bottom on ready, and the popup/overlay
## consumers (help / inspect / loadout) read it (or band_height()) dynamically.
const HEADER_HEIGHT := 144.0
## Bar's horizontal breathing room (mirrors the authored .tscn offsets ±16) —
## _apply_safe_area() re-derives the offsets, so the pad must be named here or
## the safe-area pass would silently erase it.
const BAR_PAD_X := 16.0
const SUMMARY_FONT_SIZE := 112
const BUTTON_SIZE := Vector2(112, 112)

## Fired after safe-area insets are re-measured on a root size change (device
## rotation / fold, window resize). Live screens with edge-flush content
## re-apply their insets on this (BattleScene does); regular screens just read
## PixelUI.safe_* at build time since every screen rebuilds on entry.
signal safe_area_changed

@onready var _band: Control = $HeaderBand
@onready var _bar: Control = $HeaderBand/Bar
@onready var _background: ColorRect = %Background
var _bezel_bottom: ColorRect = null
@onready var _summary_label: Label = %SummaryLabel
@onready var _help_button: Button = %HelpButton
@onready var _debug_button: Button = %DebugButton
@onready var _debug2_button: Button = %Debug2Button
@onready var _back_button: Button = %BackButton
@onready var _divider: ColorRect = %Divider

# Bound by the active battle screen; empty (inert) on every other screen.
var _help_action := Callable()
var _debug_action := Callable()
var _debug2_action := Callable()
var _back_action := Callable()


func _ready() -> void:
	_fit_desktop_window()
	# Draw above scene content; the band itself only occupies the top HEADER_HEIGHT.
	layer = 8
	_style()
	# The "?" opens the shared HelpMenu on every screen (battle, squad picker, …). The help
	# content is screen-agnostic, so it no longer needs a per-screen binding.
	_help_button.pressed.connect(_on_help_pressed)
	_debug_button.pressed.connect(func() -> void: _dispatch(_debug_action, false))
	_debug2_button.pressed.connect(func() -> void: _dispatch(_debug2_action, false))
	_back_button.pressed.connect(func() -> void: _dispatch(_back_action, true))
	set_run_active(false)
	# Debug buttons ship hidden; the SETTINGS > DEV "Developer mode" toggle shows them
	# (persisted in the save profile). SaveManager autoloads before this scene, but stay
	# defensive for headless harnesses that strip autoloads.
	var sm: Variant = get_node_or_null("/root/SaveManager")
	set_dev_mode(sm != null and bool(sm.get_setting("dev_mode", false)))
	# Safe area: this always-alive autoload owns the refresh cadence for the
	# whole game (PixelUI.safe_* is the single source of truth for the values).
	PixelUI.refresh_safe_insets(get_viewport())
	get_tree().root.size_changed.connect(_on_root_resized)
	_apply_safe_area()


## Desktop scaling scheme (ruling Kev 2026-07-23): the window is FIXED at
## 540×1200 (exact 0.5× of the 1080×2400 design space — linear sampling there
## is a uniform 2×2 box filter, which is the canonical desktop rendering) and
## free resize is disabled in project.godot. The art is authored at 1:1 design
## pixels (1-px dithers/hairlines), so nearest/integer schemes are wrong here —
## do not "fix" this to nearest filtering.
## Fallback: if the display can't fit 1200 tall (short laptops), shrink to fit
## the usable screen height at the same 0.45 aspect — a fractional scale with
## linear filtering, mildly softer but never distorted. Still non-resizable.
const _WINDOW_DECORATION_SLACK := 80  # title bar + taskbar allowance, px


func _fit_desktop_window() -> void:
	if not OS.has_feature("pc"):
		return
	var screen: Rect2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	var fit_h: int = screen.size.y - _WINDOW_DECORATION_SLACK
	if fit_h >= 1200:
		return
	var w: int = int(round(float(fit_h) * (540.0 / 1200.0)))
	DisplayServer.window_set_size(Vector2i(w, fit_h))
	DisplayServer.window_set_position(screen.position + (screen.size - Vector2i(w, fit_h)) / 2)


func _on_root_resized() -> void:
	PixelUI.refresh_safe_insets(get_viewport())
	_apply_safe_area()
	safe_area_changed.emit()


## The band's REAL height: content + the top cutout inset. Overlays that clear
## the header (help menu, inspect popup, loadout) should use this, not the raw
## HEADER_HEIGHT constant.
func band_height() -> float:
	return HEADER_HEIGHT + float(PixelUI.safe_top)


# Critical layout intent: HeaderBand GROWS by the top inset and Background stays
# anchored to the full band — the header chrome must paint underneath the camera
# cutout, so the camera sits on solid header instead of on game art. Only the
# Bar contents shift down (and in, for notched side edges). Do NOT add a top
# offset to HeaderBand itself — that would expose game art behind the cutout.
func _apply_safe_area() -> void:
	if _band == null or _bar == null:
		return
	_band.offset_bottom = HEADER_HEIGHT + float(PixelUI.safe_top)
	_bar.offset_top = float(PixelUI.safe_top)
	_bar.offset_left = BAR_PAD_X + float(PixelUI.safe_left)
	_bar.offset_right = -(BAR_PAD_X + float(PixelUI.safe_right))
	_apply_bottom_bezel()


# Build J Item 2: the bottom gesture-reserve strip renders PURE bezel black
# (DT_BEZEL_BLACK) so it reads as hardware, not as UI. The TOP inset stays
# header chrome BY DESIGN (see the layout-intent note above) — only the area
# outside chrome gets the bezel treatment. This always-alive layer paints it
# globally; inert on desktop (zero inset -> hidden).
func _apply_bottom_bezel() -> void:
	if _bezel_bottom == null:
		_bezel_bottom = ColorRect.new()
		_bezel_bottom.name = "BezelBottom"
		_bezel_bottom.color = PixelUI.DT_BEZEL_BLACK
		_bezel_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bezel_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		add_child(_bezel_bottom)
	_bezel_bottom.visible = PixelUI.safe_bottom > 0
	_bezel_bottom.offset_top = -float(PixelUI.safe_bottom)
	_bezel_bottom.offset_bottom = 0.0


func _on_help_pressed() -> void:
	AudioManager.play_select()
	HelpMenu.toggle(self)


func _dispatch(action: Callable, play_click: bool = true) -> void:
	if not action.is_valid():
		return
	if play_click:
		AudioManager.play_select()
	action.call()


# Styling mirrors the old battle header exactly (was in battle_scene._apply_battle_theme)
# so the bar looks identical now that it lives here.
func _style() -> void:
	_background.color = PixelUI.DT_PANEL_BG
	_divider.color = PixelUI.DT_LINE
	PixelUI.apply_pixel_font(_summary_label)
	_summary_label.add_theme_font_size_override("font_size", SUMMARY_FONT_SIZE)
	_summary_label.add_theme_color_override("font_color", PixelUI.TEXT_PRIMARY.darkened(0.15))
	_summary_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.98))
	_summary_label.add_theme_constant_override("outline_size", 2)
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_summary_label.clip_text = false
	_summary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	PixelUI.style_dt_icon_button(_help_button, PixelUI.ICON_HELP)
	PixelUI.style_dt_icon_button(_debug_button, PixelUI.ICON_DEBUG)
	PixelUI.style_dt_icon_button(_debug2_button, PixelUI.ICON_DEBUG2)
	PixelUI.style_dt_icon_button(_back_button, PixelUI.ICON_BACK)
	for b: Button in [_help_button, _debug_button, _debug2_button, _back_button]:
		b.custom_minimum_size = BUTTON_SIZE


# ─────────────────────────── Public API ───────────────────────────

## Sets the left run-progress label ("OP  N / total"). GameState/BattleScene call
## this whenever the battle number or run changes.
func update_progress(battle_number: int, total_battles: int, operation_name: String) -> void:
	if _summary_label == null:
		return
	_summary_label.text = "%s  %d/%d" % [operation_name, battle_number, total_battles]


## Blanks the run label when no run is active (e.g. on the main menu / home screen).
func set_run_active(active: bool) -> void:
	if _summary_label == null:
		return
	if not active:
		_summary_label.text = ""


## The active battle screen binds its button handlers here. Re-binding replaces any
## previous binding, so re-entering battle never stacks duplicate handlers.
func bind_battle_actions(help: Callable, debug: Callable, debug2: Callable, back: Callable) -> void:
	_help_action = help
	_debug_action = debug
	_debug2_action = debug2
	_back_action = back


## Called by BattleScene._exit_tree so the buttons go inert off-battle.
func clear_battle_actions() -> void:
	_help_action = Callable()
	_debug_action = Callable()
	_debug2_action = Callable()
	_back_action = Callable()


func set_debug_enabled(enabled: bool) -> void:
	if is_instance_valid(_debug_button):
		_debug_button.disabled = not enabled


func set_debug2_enabled(enabled: bool) -> void:
	if is_instance_valid(_debug2_button):
		_debug2_button.disabled = not enabled


## Developer mode (SETTINGS > DEV toggle): the debug buttons are entirely absent
## from the header unless it is on. Orthogonal to set_debug_enabled — visibility
## gates whether the buttons exist to the player; disabled gates whether the
## current screen bound them.
func set_dev_mode(enabled: bool) -> void:
	if is_instance_valid(_debug_button):
		_debug_button.visible = enabled
	if is_instance_valid(_debug2_button):
		_debug2_button.visible = enabled
