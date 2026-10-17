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
const SUMMARY_FONT_SIZE := 96   # ui-unify: the DISPLAY role (Battle Block x3); the in-run header is HEADER (_header_block_px)
const BUTTON_SIZE := Vector2(112, 112)
const LANDSCAPE_STYLE := preload("res://scripts/battle/landscape_battle_style.gd").VALUES
const DEPTH := preload("res://scripts/ui/battle_depth.gd")
var _battle_landscape := false
var _battle_visuals := false
var _battle_style: Dictionary = {}


## Scoped to the active battle; its layout restores this when the scene exits.
func set_battle_landscape(enabled: bool) -> void:
	if _battle_landscape == enabled:
		return
	_battle_landscape = enabled
	_battle_style = LANDSCAPE_STYLE if enabled else {}
	var cap := $HeaderBand.get_node_or_null("PortraitWidthCap")
	if cap != null:
		cap.set("enabled", not enabled)
		cap.call("_fit")
	_style()
	_apply_safe_area()

## Fired after safe-area insets are re-measured on a root size change (device
## rotation / fold, window resize). Live screens with edge-flush content
## re-apply their insets on this (BattleScene does); regular screens just read
## PixelUI.safe_* at build time since every screen rebuilds on entry.
signal safe_area_changed
## Fired once, when seven quick taps unlock the session's dev tools (the title
## screen adds its dev-only controls on it).
signal dev_tools_unlocked_now
## Flat pixel A: fired after F10 (debug builds) switches the system color. A
## screen that restyles in place connects to it (the battle screen, through
## BattleLayout); with no listener the current screen is reloaded instead.
signal chrome_changed(id: String)

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
# Battle depth prototype v3: the battle count in the operation's accent, and a
# thin rule under the title. Off (transparent) unless the battle scene sets it.
var _count_tint := Color.TRANSPARENT
var _count_label: Label = null
var _progress: Array = []


func _ready() -> void:
	# Sharp (NEAREST) sampling for every pixel-font node, game-wide. This
	# always-alive autoload is the one installer; PixelUI owns the rule.
	PixelUI.install_text_filter(get_tree())
	_apply_chrome_arg()
	_fit_desktop_window()
	_apply_capture_window_arg()
	PixelUI.cap_portrait_width($HeaderBand)
	# Draw above scene content; the band itself only occupies the top HEADER_HEIGHT.
	layer = 8
	_background.draw.connect(_draw_battle_frame)
	_count_label = Label.new()
	_count_label.name = "CountLabel"
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_count_label.visible = false
	_summary_label.add_sibling(_count_label)
	(_bar as Container).sort_children.connect(_background.queue_redraw)
	_style()
	# The "?" opens the shared HelpMenu on every screen (battle, squad picker, …). The help
	# content is screen-agnostic, so it no longer needs a per-screen binding.
	_help_button.pressed.connect(_on_help_pressed)
	_debug_button.pressed.connect(func() -> void: _dispatch(_debug_action, false))
	_debug2_button.pressed.connect(func() -> void: _dispatch(_debug2_action, false))
	if not OS.is_debug_build():
		strip_debug_buttons()
	_back_button.pressed.connect(func() -> void: _dispatch(_back_action, true))
	set_run_active(false)
	set_dev_mode(false)
	_summary_label.mouse_filter = Control.MOUSE_FILTER_STOP
	var gesture := LongPressInput.new()
	gesture.tapped.connect(_register_dev_tap)
	_summary_label.add_child(gesture)
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
	return float(_battle_style.get("header_height", HEADER_HEIGHT)) + float(PixelUI.safe_top)


# Critical layout intent: HeaderBand GROWS by the top inset and Background stays
# anchored to the full band — the header chrome must paint underneath the camera
# cutout, so the camera sits on solid header instead of on game art. Only the
# Bar contents shift down (and in, for notched side edges). Do NOT add a top
# offset to HeaderBand itself — that would expose game art behind the cutout.
func _apply_safe_area() -> void:
	if _band == null or _bar == null:
		return
	_band.offset_bottom = band_height()
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
	AudioManager.play_click()
	HelpMenu.toggle(self)


func _dispatch(action: Callable, play_click: bool = true) -> void:
	if not action.is_valid():
		return
	if play_click:
		AudioManager.play_click()
	action.call()


# Styling mirrors the old battle header exactly (was in battle_scene._apply_battle_theme)
# so the bar looks identical now that it lives here.
func _style() -> void:
	_background.color = PixelUI.DT_PANEL_BG
	_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if _battle_visuals else CanvasItem.TEXTURE_FILTER_PARENT_NODE
	_divider.color = PixelUI.DT_LINE
	if _battle_visuals:
		_background.color = PixelUI.BATTLE_PANEL
		_divider.color = PixelUI.BATTLE_BORDER
	PixelUI.apply_pixel_font(_summary_label)
	_summary_label.add_theme_font_size_override("font_size", _battle_style.get("header_font", SUMMARY_FONT_SIZE))
	_summary_label.add_theme_color_override("font_color", PixelUI.TEXT_PRIMARY.darkened(0.15))
	_summary_label.add_theme_color_override("font_outline_color", PixelUI.INK_OUTLINE)
	_summary_label.add_theme_constant_override("outline_size", 2)
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_summary_label.clip_text = false
	_summary_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var block_px: Vector2 = _header_block_px()
	if _battle_visuals:
		PixelUI.style_battle_text(_summary_label)
		PixelUI.bind_block_snap(_summary_label, block_px.x, block_px.y)
	else:
		_summary_label.remove_theme_color_override("font_shadow_color")
	if _count_label != null:
		PixelUI.apply_pixel_font(_count_label)
		_count_label.add_theme_font_size_override("font_size", _battle_style.get("header_font", SUMMARY_FONT_SIZE))
		PixelUI.style_battle_text(_count_label, _count_tint)
		PixelUI.bind_block_snap(_count_label, block_px.x, block_px.y)
	_refresh_summary()
	_background.queue_redraw()
	PixelUI.style_dt_icon_button(_help_button, PixelUI.ICON_HELP, PixelUI.DT_BTN_BORDER, Color.WHITE, _battle_visuals, PixelUI.CHROME)
	if is_instance_valid(_debug_button):
		PixelUI.style_dt_icon_button(_debug_button, PixelUI.ICON_DEBUG, PixelUI.DT_BTN_BORDER, Color.WHITE, _battle_visuals, PixelUI.CHROME)
	if is_instance_valid(_debug2_button):
		PixelUI.style_dt_icon_button(_debug2_button, PixelUI.ICON_DEBUG2, PixelUI.DT_BTN_BORDER, Color.WHITE, _battle_visuals, PixelUI.CHROME)
	PixelUI.style_dt_icon_button(_back_button, PixelUI.ICON_BACK, PixelUI.DT_BTN_BORDER, Color.WHITE, _battle_visuals, PixelUI.CHROME)
	for b: Button in [_help_button, _debug_button, _debug2_button, _back_button]:
		if is_instance_valid(b):
			b.custom_minimum_size = _battle_style.get("header_button_size", BUTTON_SIZE)


## The operation name and count's Battle Block font pixel (min, max design px).
## ui-fix (Kev, 2026-10-17): the HEADER role, x4, one rung above DISPLAY. Its
## glyphs sit 36 to 99 design px down the 144 bar at 360 (k 3), clear of GAP at
## the top and of the encounter rule at 120, so the bars keep 144. "FACILITY 10/10"
## is 768 px of the 816 the two-button row leaves; the dev-mode row (four
## buttons) leaves 584, so with it up the header drops back to DISPLAY.
## The parked landscape layout keeps its own header font.
func _header_block_px() -> Vector2:
	if _battle_style.has("header_font"):
		var px: float = float(PixelUI.lattice_px(int(_battle_style["header_font"]), "block")) / 16.0
		return Vector2(px, px)
	var dev_row: bool = dev_mode_enabled and has_debug_buttons()
	return PixelUI.BLOCK_FONT_PX[PixelUI.TYPE_DISPLAY if dev_row else PixelUI.TYPE_HEADER]


# Held for the node's life: a style made inside the draw callback is freed when
# it returns, taking its texture along, and the queued draw then paints plain
# white (the white header band on the reward screen, where nothing else holds
# the strip texture; same bug class as ProtocolPips, aaed29a).
var _battle_frame: StyleBox = null


func _draw_battle_frame() -> void:
	if _battle_visuals:
		if _battle_frame == null:
			_battle_frame = PixelUI.battle_strip_style()
		_background.draw_style_box(_battle_frame, Rect2(Vector2.ZERO, _background.size))
		if _count_tint.a > 0.0:
			# The thin rule under the title, from the bar's edge to the buttons.
			var right: float = _bar.position.x + (_bar.get_node("ButtonRow") as Control).position.x - BAR_PAD_X
			# Flat pixel A: the rule is in the operation's ENCOUNTER accent, like the count.
			_background.draw_rect(Rect2(_bar.position.x, HEADER_HEIGHT - HEADER_RULE_INSET, right - _bar.position.x, HEADER_RULE_PX), _count_tint)


const HEADER_RULE_PX := 4.0
const HEADER_RULE_INSET := 24.0


## Battle depth prototype v3: tints the battle count and shows the rule under the
## title. Color.TRANSPARENT turns both off.
func set_count_tint(tint: Color) -> void:
	_count_tint = tint
	_style()


func _refresh_summary() -> void:
	if _summary_label == null or _count_label == null:
		return
	var split: bool = _battle_visuals and _count_tint.a > 0.0 and not _progress.is_empty()
	_count_label.visible = split
	_summary_label.size_flags_horizontal = Control.SIZE_FILL if split else Control.SIZE_EXPAND_FILL
	# A trimming label asks for no width, so unsplit it would vanish beside the count.
	_summary_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING if split else TextServer.OVERRUN_TRIM_ELLIPSIS
	if _progress.is_empty():
		return
	var count: String = "%d/%d" % [_progress[0], _progress[1]]
	_summary_label.text = "%s " % _progress[2] if split else "%s  %s" % [_progress[2], count]
	_count_label.text = count


# ─────────────────────────── Public API ───────────────────────────

## Sets the left run-progress label ("OP  N / total"). GameState/BattleScene call
## this whenever the battle number or run changes.
func update_progress(battle_number: int, total_battles: int, operation_name: String) -> void:
	if _summary_label == null:
		return
	_progress = [battle_number, total_battles, operation_name]
	_summary_label.text = "%s  %d/%d" % [operation_name, battle_number, total_battles]
	_refresh_summary()


## ui-cleanup: the in-operation header, the same on every screen shown inside a
## run (route fork, intercept, reward, evolution, unlock, run end, the Starting
## Directive picker): the battle frame, the operation name, the battle count in
## the operation's ENCOUNTER accent and the rule under it in that accent. The
## battle screen reaches the same state through update_progress and BattleLayout.
## Also sets PixelUI.ENCOUNTER_ACCENT, so a screen built after this call reads
## its operation's color. An unknown operation blanks the label instead.
func show_operation(operation_id: String, battle_number: int, total_battles: int) -> void:
	var operation: OperationData = DataManager.get_operation(operation_id) as OperationData
	if operation == null:
		set_run_active(false)
		return
	var accent: Color = DEPTH.encounter_accent(operation_id)
	PixelUI.ENCOUNTER_ACCENT = accent if accent.a > 0.0 else PixelUI.BATTLE_ENEMY_LINE
	_battle_visuals = true
	_count_tint = PixelUI.ENCOUNTER_ACCENT
	_progress = [battle_number, total_battles, operation.battle_name()]
	_style()


## A bare run label with no battle count (the tutorial reads just "TUTORIAL").
func set_run_label(text: String) -> void:
	if _summary_label == null:
		return
	_progress = []
	_refresh_summary()
	_summary_label.text = text


## Blanks the run label when no run is active (e.g. on the main menu / home screen).
func set_run_active(active: bool) -> void:
	if _summary_label == null:
		return
	if not active:
		_progress = []
		# No run, no operation: the encounter count and rule go with the label.
		if _count_tint.a > 0.0:
			_count_tint = Color.TRANSPARENT
			_background.queue_redraw()
		_refresh_summary()
		_summary_label.text = ""


## The active battle screen binds its button handlers here. Re-binding replaces any
## previous binding, so re-entering battle never stacks duplicate handlers.
func bind_battle_actions(help: Callable, debug: Callable, debug2: Callable, back: Callable) -> void:
	_battle_visuals = true
	_style()
	_help_action = help
	_debug_action = debug
	_debug2_action = debug2
	_back_action = back


## Called by BattleScene._exit_tree so the buttons go inert off-battle.
func clear_battle_actions() -> void:
	_battle_visuals = false
	_count_tint = Color.TRANSPARENT
	_style()
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


## Release builds (Kev, 2026-10-16): the ^ auto-turn and ^^ auto-battle buttons
## do not exist. _ready frees both nodes, so no unlock, setting or binding can
## show them; the seven-tap unlock (G-10) still opens the SETTINGS dev tools.
## Public so the dev unlock gate can prove the release path in a debug run.
func strip_debug_buttons() -> void:
	for b: Button in [_debug_button, _debug2_button]:
		if is_instance_valid(b):
			b.get_parent().remove_child(b)
			b.free()
	_debug_button = null
	_debug2_button = null


func has_debug_buttons() -> bool:
	return is_instance_valid(_debug_button) and is_instance_valid(_debug2_button)


## Developer mode (SETTINGS > DEV toggle): the debug buttons are entirely absent
## from the header unless it is on. Orthogonal to set_debug_enabled — visibility
## gates whether the buttons exist to the player; disabled gates whether the
## current screen bound them.
func set_dev_mode(enabled: bool) -> void:
	dev_mode_enabled = enabled and dev_tools_unlocked
	enabled = dev_mode_enabled
	if is_instance_valid(_debug_button):
		_debug_button.visible = enabled
	if is_instance_valid(_debug2_button):
		_debug2_button.visible = enabled
	if _summary_label != null:
		_style()   # the header type steps down while the dev row is up


# Session-only easter egg. Seven quick taps on the operation title; any other
# press breaks the sequence. LongPressInput filters holds/drags and touch echoes.
var dev_tools_unlocked := false
var dev_mode_enabled := false
var _dev_tap_count := 0
var _dev_last_tap_ms := -2000
var _dev_tap_sources: Array = []  # WeakRefs to extra tap targets

func _input(event: InputEvent) -> void:
	if _handle_chrome_key(event):
		return
	var press := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		press = event.pressed
		pos = event.position
	elif event is InputEventScreenTouch:
		press = event.pressed
		pos = event.position
	if press and not _summary_label.get_global_rect().has_point(pos) and not _on_extra_tap_source(pos):
		_dev_tap_count = 0


## Flat pixel A, debug builds: F10 cycles the CHROME candidates. The
## header restyles itself; a listener on chrome_changed (the battle
## screen) restyles in place; with none, the screen is reloaded so it rebuilds
## in the new color. Returns true when it used the key.
func _handle_chrome_key(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_F10 or not OS.is_debug_build():
		return false
	get_viewport().set_input_as_handled()
	var id: String = PixelUI.set_chrome(PixelUI.chrome_index + 1)
	print("[CHROME] %s" % id)
	_style()
	if chrome_changed.get_connections().is_empty():
		if get_tree().current_scene != null:
			get_tree().reload_current_scene()
	else:
		chrome_changed.emit(id)
	return true


## Debug builds: `--capture-window=WxH` sizes the window for screenshot tools,
## so every capture script can shoot at phone width (ui-unify) without its own
## window option. Same sizing as scripts/debug/capture_window.gd.
func _apply_capture_window_arg() -> void:
	if not OS.is_debug_build():
		return
	for arg: String in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--capture-window="):
			var parts: PackedStringArray = arg.trim_prefix("--capture-window=").split("x")
			if parts.size() == 2:
				load("res://scripts/debug/capture_window.gd").apply(get_tree().root, Vector2i(int(parts[0]), int(parts[1])))


## `--system-accent=<id>` (bone / phosphor / cyan / amber) starts on that
## candidate, for captures. Read from both the engine and the user arguments.
func _apply_chrome_arg() -> void:
	for arg: String in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--system-accent="):
			var index: int = PixelUI.chrome_index_of(arg.trim_prefix("--system-accent="))
			if index >= 0:
				PixelUI.set_chrome(index)


## Another control that counts toward the seven-tap unlock: the title screen's
## version stamp (dev state-code tool, 2026-10-02), so the tools are reachable
## with no run in progress. Same rule as the operation title: seven quick taps,
## a press anywhere else breaks the sequence.
func add_dev_tap_source(source: Control) -> void:
	source.mouse_filter = Control.MOUSE_FILTER_STOP
	var gesture := LongPressInput.new()
	gesture.tapped.connect(func() -> void: _register_dev_tap(-1, false))
	source.add_child(gesture)
	_dev_tap_sources.append(weakref(source))


func _on_extra_tap_source(pos: Vector2) -> bool:
	for ref in _dev_tap_sources:
		var source: Control = (ref as WeakRef).get_ref() as Control
		if source != null and source.is_visible_in_tree() and source.get_global_rect().has_point(pos):
			return true
	return false


func _register_dev_tap(now_ms: int = -1, from_run_title: bool = true) -> void:
	if dev_tools_unlocked or (from_run_title and _summary_label.text.is_empty()):
		return
	if now_ms < 0:
		now_ms = Time.get_ticks_msec()
	if now_ms - _dev_last_tap_ms > 1000:
		_dev_tap_count = 0
	_dev_last_tap_ms = now_ms
	_dev_tap_count += 1
	if _dev_tap_count < 7:
		return
	dev_tools_unlocked = true
	set_dev_mode(true)
	dev_tools_unlocked_now.emit()
	var notice := Label.new()
	notice.text = "DEV TOOLS UNLOCKED"
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUI.apply_pixel_font(notice)
	notice.add_theme_font_size_override("font_size", 48)
	notice.add_theme_color_override("font_color", PixelUI.CHROME)
	notice.add_theme_color_override("font_outline_color", PixelUI.DT_BTN_BG)
	notice.add_theme_constant_override("outline_size", 8)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_band.add_child(notice)
	notice.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	notice.position.y += 12
	get_tree().create_timer(2.5).timeout.connect(notice.queue_free)
