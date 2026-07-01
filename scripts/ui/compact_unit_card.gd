class_name CompactUnitCard
extends PanelContainer

signal card_pressed
signal unit_detail_requested(card)

const CARD_SIZE := Vector2(260, 0)
const PORTRAIT_HP_GAP_PX := 10.0
const NAME_ROW_HEIGHT := 80.0
const HP_BAR_HEIGHT := 86.0
const HP_FILL_HEIGHT := 86.0
const ACTION_PANEL_HEIGHT := 88.0
# Card line/fill colors pull from the canonical PixelUI DT palette. Declared as
# static var (not const) because PixelUI's DT_* tokens are themselves static var
# and a const can't be initialized from a non-const value.
static var HERO_LINE := PixelUI.DT_HERO_BORDER
static var ENEMY_LINE := PixelUI.DT_ENEMY_BORDER
static var SELECT_LINE := PixelUI.GOLD_ACCENT
static var HP_FILL := PixelUI.DT_HP_GREEN
static var HP_CHIP := PixelUI.COLOR_DAMAGE  # "doomed HP" forecast overlay — pending damage, drains per hit
static var HP_BACK := PixelUI.DT_FIELD_BG
const CARD_NAME_FONT_SIZE := 72
const CARD_HP_FONT_SIZE := 72
const STATUS_MAX_VISIBLE := 3
const STATUS_ICON_FONT_SIZE := 48
const STATUS_VALUE_FONT_SIZE := 48
const STATUS_NAME_FONT_SIZE := 48
const STATUS_ICON_TEXTURE_SIZE := 48.0
const STATUS_ICON_MIN_WIDTH := 48.0
const STATUS_VALUE_MIN_WIDTH := 32.0
const STATUS_NUMERIC_MIN_WIDTH := 96.0
const STATUS_CHIP_HEIGHT := 56.0
const CARD_BORDER_WIDTH := 6
var side: String = "hero"
var unit_name: String = "SYSTEMS MED"
var current_hp: int = 45
var max_hp: int = 45
var forecast_hp: int = 45  # where HP settles this round (drives the pending-damage red zone)
var action_text: String = "READY"
var action_pips: Array = []
var portrait: Texture2D = null
var status_tokens: Array = ["POI", "CL"]
var selected: bool = false
var targetable: bool = false
var interaction_enabled: bool = true
var dead: bool = false
var target_locked: bool = false
var needs_manual_target: bool = false
var show_action_pips: bool = true
var unit_data: Resource = null
var gear_detail_rows: Array = []

var _name_label: Label = null
var _name_strip: PanelContainer = null
var _portrait_frame: Control = null
var _portrait_crop: Control = null
var _portrait_rect: TextureRect = null
var _portrait_dither: TextureRect = null
var _hp_back: Panel = null
var _hp_label: Label = null
var _hp_fill: ColorRect = null
var _hp_chip: ColorRect = null
var _hp_ratio_shown: float = -1.0
var _hp_drain_tween: Tween = null
var _action_panel: PanelContainer = null
var _action_grid: HFlowContainer = null
var _status_slot: Control = null
var _status_row: HBoxContainer = null
var _status_tint: ColorRect = null
var _status_divider: ColorRect = null
var _preview_effects: Dictionary = {}
var _preview_rect_red: ColorRect = null
var _preview_rect_blue: ColorRect = null
var _preview_rect_purple: ColorRect = null
var _preview_rect_heal: ColorRect = null
var _locked_layout_size: Vector2 = Vector2.ZERO
var _locked_portrait_width: float = 0.0
var _locked_portrait_size: Vector2 = Vector2.ZERO
var _portrait_long_press: LongPressInput = null
var _pip_icon_atlas: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = CARD_SIZE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build()
	_set_descendants_mouse_filter(self, Control.MOUSE_FILTER_IGNORE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_wire_portrait_detail_input()
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if _locked_portrait_size == Vector2.ZERO:
			_update_portrait_size()
		call_deferred("_update_portrait_rect_transform")
		call_deferred("_layout_preview_overlays")


func configure(data: Dictionary) -> void:
	side = str(data.get("side", side))
	unit_name = str(data.get("name", unit_name))
	current_hp = int(data.get("current_hp", current_hp))
	max_hp = int(data.get("max_hp", max_hp))
	forecast_hp = int(data.get("forecast_hp", current_hp))
	action_text = str(data.get("action", action_text))
	action_pips = data.get("pips", action_pips)
	portrait = data.get("portrait", portrait) as Texture2D
	status_tokens = data.get("statuses", status_tokens)
	selected = bool(data.get("selected", selected))
	targetable = bool(data.get("targetable", targetable))
	interaction_enabled = bool(data.get("interaction_enabled", interaction_enabled))
	dead = bool(data.get("dead", dead))
	target_locked = bool(data.get("target_locked", target_locked))
	needs_manual_target = bool(data.get("needs_manual_target", needs_manual_target))
	show_action_pips = bool(data.get("show_action_pips", show_action_pips))
	unit_data = data.get("unit_data", unit_data) as Resource
	gear_detail_rows = data.get("gear_rows", gear_detail_rows)
	_refresh()


func apply_battle_layout(layout_size: Vector2) -> void:
	if layout_size.x <= 2.0:
		return
	var safe_layout_size := Vector2(maxf(layout_size.x, 1.0), maxf(layout_size.y, 1.0))
	var layout_changed: bool = not safe_layout_size.is_equal_approx(_locked_layout_size)
	_locked_layout_size = safe_layout_size
	_locked_portrait_width = maxf(safe_layout_size.x - 24.0, 1.0)
	custom_minimum_size = safe_layout_size
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	if layout_changed or _locked_portrait_size == Vector2.ZERO:
		_update_portrait_size()
	call_deferred("_layout_preview_overlays")


func show_combat_preview(effects: Dictionary) -> void:
	_preview_effects = effects.duplicate(true)
	_ensure_preview_rects()
	_wire_hp_passthrough()
	call_deferred("_layout_preview_overlays")


func clear_combat_preview() -> void:
	_preview_effects.clear()
	_hide_preview_rects()
	_wire_hp_passthrough()


func _gui_input(event: InputEvent) -> void:
	if not interaction_enabled:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			card_pressed.emit()
			accept_event()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			card_pressed.emit()
			accept_event()


func _build() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_top", 1)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_bottom", 1)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 0)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	_name_strip = PanelContainer.new()
	_name_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_strip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(_name_strip)

	_name_label = Label.new()
	_name_label.custom_minimum_size = Vector2(0, NAME_ROW_HEIGHT)
	_name_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_label(_name_label, CARD_NAME_FONT_SIZE, PixelUI.DT_CYAN, 0)
	_name_strip.add_child(_name_label)

	# Plain Control (NOT a Container) so the crop + status overlay can be positioned
	# by anchors; a PanelContainer would force-lay-out both children.
	_portrait_frame = Control.new()
	_portrait_frame.custom_minimum_size = Vector2.ZERO
	# Frame does NOT clip (so status badges overlaid at the bottom aren't cut off);
	# the inner _portrait_crop still clips the portrait image itself.
	_portrait_frame.clip_contents = false
	_portrait_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portrait_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_portrait_frame)

	_portrait_crop = Control.new()
	_portrait_crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_crop.clip_contents = true
	_portrait_crop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_frame.add_child(_portrait_crop)

	_portrait_rect = TextureRect.new()
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_SCALE
	# Position and size are set manually by _update_portrait_rect_transform
	_portrait_crop.add_child(_portrait_rect)

	# Direction-05 signature: 2x2 dither over the portrait (approximates the
	# multiply darken overlay from the design). Alpha set per side in _refresh.
	_portrait_dither = PixelUI.make_dither_overlay(Color.BLACK, 0.17)
	_portrait_crop.add_child(_portrait_dither)

	# Uniform thin gap between portrait and HP bar so the card panel color
	# shows through as a subtle separator on every card.
	var portrait_hp_spacer: Control = Control.new()
	portrait_hp_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_hp_spacer.custom_minimum_size = Vector2(0, PORTRAIT_HP_GAP_PX)
	portrait_hp_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_hp_spacer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(portrait_hp_spacer)

	_hp_back = Panel.new()
	_hp_back.custom_minimum_size = Vector2(0, HP_BAR_HEIGHT)
	_hp_back.clip_contents = true
	_hp_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_back.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_hp_back.add_theme_stylebox_override("panel", _style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	root.add_child(_hp_back)

	_hp_fill = ColorRect.new()
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_fill.color = HP_FILL
	_hp_fill.anchor_left = 0.0
	_hp_fill.anchor_top = 0.0
	_hp_fill.anchor_right = 1.0
	_hp_fill.anchor_bottom = 0.0
	_hp_fill.offset_left = 0.0
	_hp_fill.offset_top = 0.0
	_hp_fill.offset_right = 0.0
	_hp_fill.offset_bottom = HP_FILL_HEIGHT
	_hp_fill.z_index = 1
	_hp_back.add_child(_hp_fill)

	# "Doomed HP" overlay — drawn ON TOP of the green, spanning [final, displayed].
	# Its left edge pins at the forecast final HP while the right edge chips down
	# one hit at a time, so multi-attack damage reads as "here's where it ends up,
	# now watch it get there."
	_hp_chip = ColorRect.new()
	_hp_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_chip.color = HP_CHIP
	_hp_chip.anchor_left = 1.0
	_hp_chip.anchor_top = 0.0
	_hp_chip.anchor_right = 1.0
	_hp_chip.anchor_bottom = 0.0
	_hp_chip.offset_left = 0.0
	_hp_chip.offset_top = 0.0
	_hp_chip.offset_right = 0.0
	_hp_chip.offset_bottom = HP_FILL_HEIGHT
	_hp_chip.z_index = 2
	_hp_back.add_child(_hp_chip)

	_hp_label = Label.new()
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_label.z_index = 3
	_hp_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_label(_hp_label, CARD_HP_FONT_SIZE, Color(0.98, 0.99, 1.0, 1.0), 2)
	_hp_back.add_child(_hp_label)

	_action_panel = PanelContainer.new()
	_action_panel.custom_minimum_size = Vector2(0, ACTION_PANEL_HEIGHT)
	_action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_action_panel)

	var action_margin: MarginContainer = MarginContainer.new()
	action_margin.add_theme_constant_override("margin_left", 4)
	action_margin.add_theme_constant_override("margin_top", 6)
	action_margin.add_theme_constant_override("margin_right", 4)
	action_margin.add_theme_constant_override("margin_bottom", 2)
	_action_panel.add_child(action_margin)

	_action_grid = HFlowContainer.new()
	_action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_action_grid.alignment = FlowContainer.ALIGNMENT_CENTER
	_action_grid.add_theme_constant_override("h_separation", 6)
	_action_grid.add_theme_constant_override("v_separation", 6)
	action_margin.add_child(_action_grid)

	_status_slot = Control.new()
	_status_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_slot.clip_contents = false
	# Direction-05: status badges overlay the bottom edge of the portrait (a row of
	# pixel "stickers"). Parented to the non-clipping frame so borders/shadows show.
	_portrait_frame.add_child(_status_slot)
	_status_slot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status_slot.offset_left = 8
	_status_slot.offset_right = -8
	_status_slot.offset_top = -76
	_status_slot.offset_bottom = -8

	_status_tint = ColorRect.new()
	_status_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_tint.color = Color.TRANSPARENT
	_status_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_status_slot.add_child(_status_tint)

	_status_divider = ColorRect.new()
	_status_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_divider.color = Color.TRANSPARENT
	_status_divider.anchor_right = 1.0
	_status_divider.anchor_bottom = 0.0
	_status_divider.offset_left = 0.0
	_status_divider.offset_top = 0.0
	_status_divider.offset_right = 0.0
	_status_divider.offset_bottom = 1.0
	_status_slot.add_child(_status_divider)

	var status_margin := MarginContainer.new()
	status_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status_margin.add_theme_constant_override("margin_left", 2)
	status_margin.add_theme_constant_override("margin_top", 0)
	status_margin.add_theme_constant_override("margin_right", 2)
	status_margin.add_theme_constant_override("margin_bottom", 0)
	_status_slot.add_child(status_margin)

	_status_row = HBoxContainer.new()
	_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_status_row.custom_minimum_size = Vector2.ZERO
	_status_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_status_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_status_row.clip_contents = true
	_status_row.add_theme_constant_override("separation", 2)
	status_margin.add_child(_status_row)


func _refresh() -> void:
	if _name_label == null:
		return

	var is_hero: bool = side == "hero"
	var line_color: Color = _line_color()
	var panel_bg: Color = PixelUI.DT_HERO_BG if is_hero else PixelUI.DT_ENEMY_BG
	# margin == border width so the card's children (portrait included) sit INSIDE the
	# border instead of drawing over it — the frame always stays on top of the portrait.
	add_theme_stylebox_override("panel", _style(panel_bg, line_color, CARD_BORDER_WIDTH, CARD_BORDER_WIDTH))
	_portrait_frame.add_theme_stylebox_override("panel", _style(Color(0.0, 0.0, 0.0, 0.0), Color.TRANSPARENT, 0, 0))
	_action_panel.add_theme_stylebox_override("panel", _style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	_action_panel.visible = show_action_pips
	# Direction-05 card: header strip + HP track use darker team tints, divided by a
	# 2px hard border in the card's line color (no rounded corners).
	if _name_strip != null:
		var header_bg: Color = PixelUI.DT_HERO_HEADER if is_hero else PixelUI.DT_ENEMY_HEADER
		var header_style: StyleBoxFlat = _style(header_bg, line_color, 0, 0)
		header_style.border_width_bottom = 2
		_name_strip.add_theme_stylebox_override("panel", header_style)
	var track_bg: Color = PixelUI.DT_HERO_TRACK if is_hero else PixelUI.DT_ENEMY_TRACK
	var track_style: StyleBoxFlat = _style(track_bg, line_color, 0, 0)
	track_style.border_width_top = 2
	_hp_back.add_theme_stylebox_override("panel", track_style)
	if _portrait_dither != null:
		_portrait_dither.modulate = Color(0.0, 0.0, 0.0, 0.10 if is_hero else 0.12)
	if _locked_portrait_size == Vector2.ZERO:
		_update_portrait_size()

	_name_label.text = unit_name.to_upper()
	_name_label.add_theme_color_override("font_color", _name_font_color(is_hero))
	_hp_label.text = "%d / %d" % [maxi(current_hp, 0), maxi(max_hp, 1)]
	_portrait_rect.texture = portrait
	call_deferred("_update_portrait_rect_transform")

	_set_hp_display(
		clampf(float(current_hp) / float(maxi(max_hp, 1)), 0.0, 1.0),
		clampf(float(forecast_hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	)

	_portrait_rect.modulate = Color(0.48, 0.50, 0.58, 0.55) if dead else Color(1.12, 1.12, 1.12, 1.0)
	if dead:
		modulate = Color(0.55, 0.56, 0.62, 0.72)
	else:
		modulate = Color.WHITE
	if show_action_pips:
		_populate_action_pips()
	_populate_statuses()
	_layout_preview_overlays()


# Animated HP bar. `displayed` is the HP shown right now (steps down one hit at a
# time during feedback); `forecast` is where HP will finally settle this round.
# Green fills [0, displayed]; the red overlay fills [forecast, displayed] = the
# damage still pending, with its LEFT edge pinned at the final HP. Each hit chips
# the right edge of both down to the new displayed value, so a multi-unit gang-up
# reads as "this is where it ends up — now watch the green get chipped to it."
# First paint / no-change snaps without animating (and never stomps an in-flight
# animation, since a no-op refresh fires right after the feedback loop).
func _set_hp_display(displayed: float, forecast: float) -> void:
	if _hp_fill == null:
		return
	displayed = clampf(displayed, 0.0, 1.0)
	forecast = clampf(forecast, 0.0, 1.0)
	_hp_fill.color = HP_FILL
	var old_displayed: float = _hp_ratio_shown
	var animating: bool = _hp_drain_tween != null and _hp_drain_tween.is_valid()
	if old_displayed < 0.0 or is_equal_approx(old_displayed, displayed):
		if not animating:
			_set_bar_right(_hp_fill, displayed)
			_set_chip_span(forecast, displayed)
		_hp_ratio_shown = displayed
		return
	if animating:
		_hp_drain_tween.kill()
	_hp_drain_tween = create_tween()
	_hp_drain_tween.set_parallel(true)
	if displayed < old_displayed:
		# Damage: pin the red zone's left edge at the forecast and start its right
		# edge at the previous displayed value, so the full pending slice flashes
		# before the green + red right edges chip down together to the new value.
		_hp_chip.anchor_left = minf(forecast, displayed)
		_hp_chip.offset_left = 0.0
		_hp_chip.anchor_right = old_displayed
		_hp_chip.offset_right = 0.0
		_hp_drain_tween.tween_property(_hp_chip, "anchor_right", displayed, 0.30) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_hp_drain_tween.tween_property(_hp_fill, "anchor_right", displayed, 0.30) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		# Heal/grow: no pending-damage red — just grow the green up.
		_set_chip_span(displayed, displayed)
		_hp_drain_tween.tween_property(_hp_fill, "anchor_right", displayed, 0.26) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hp_ratio_shown = displayed


func _set_bar_right(bar: ColorRect, ratio: float) -> void:
	if bar == null:
		return
	bar.anchor_right = ratio
	bar.offset_right = 0.0


# Red overlay spans [forecast, displayed]; collapses to nothing when no damage is
# pending (forecast >= displayed).
func _set_chip_span(forecast: float, displayed: float) -> void:
	if _hp_chip == null:
		return
	var left: float = minf(forecast, displayed)
	_hp_chip.anchor_left = left
	_hp_chip.offset_left = 0.0
	_hp_chip.anchor_right = displayed
	_hp_chip.offset_right = 0.0


func _update_portrait_size() -> void:
	if _portrait_frame == null:
		return
	var target_width: float = _locked_portrait_width
	if target_width <= 2.0:
		target_width = _portrait_frame.size.x
	if target_width <= 2.0:
		target_width = maxf(size.x - 24.0, CARD_SIZE.x - 24.0)
	var reserved := 84.0
	var layout_h := _locked_layout_size.y if _locked_layout_size.y > 0.0 else size.y
	var actual_h := size.y if size.y > 10.0 else layout_h
	var target_height := maxf(0.0, actual_h - reserved)
	_locked_portrait_size = Vector2(target_width, target_height)
	_portrait_frame.custom_minimum_size = Vector2.ZERO
	call_deferred("_update_portrait_rect_transform")


func _update_portrait_rect_transform() -> void:
	if _portrait_rect == null or _portrait_crop == null:
		return
	var fw: float = _portrait_crop.size.x
	var fh: float = _portrait_crop.size.y
	if fw < 2.0 or fh < 2.0:
		return
	PixelUI.cover_fit_portrait(_portrait_rect, Vector2(fw, fh))


func _populate_action_pips() -> void:
	for child in _action_grid.get_children():
		child.queue_free()

	if action_pips.is_empty():
		_action_grid.add_child(_make_action_fallback(action_text))
		return

	var max_visible: int = mini(action_pips.size(), 5)
	for i in range(max_visible):
		var pip: Dictionary = _normalize_action_pip(action_pips[i])
		_action_grid.add_child(_make_action_pip(pip))
	if action_pips.size() > max_visible:
		_action_grid.add_child(_make_action_pip({"kind": "tag", "value": "+%d" % (action_pips.size() - max_visible)}))


func _make_action_fallback(text: String) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text.to_upper()
	label.custom_minimum_size = Vector2(0, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.max_lines_visible = 2
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
	_apply_label(label, 16, PixelUI.TEXT_PRIMARY, 2)
	return label


func _get_pip_icon_texture(kind: String) -> Texture2D:
	return PixelUI.pip_texture_for_key(kind)


func _normalize_action_pip(pip: Dictionary) -> Dictionary:
	if pip.has("value"):
		return pip
	return {
		"kind": str(pip.get("kind", "")),
		"value": str(pip.get("value", pip.get("text", ""))),
		"duration": int(pip.get("duration", 0)),
		"scope": str(pip.get("scope", "")),
	}


func _make_action_pip(effect: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(96, 74)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pip_key: String = EffectPip.pip_key_for_effect(effect, side)
	panel.add_theme_stylebox_override("panel", _style(Color(0.006, 0.012, 0.020, 0.72), _pip_border(pip_key if pip_key != "" else str(effect.get("kind", ""))), 3, 5))

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", int(EffectPip.PROFILE_CARD.get("icon_value_gap", 4)))
	panel.add_child(row)
	row.add_child(EffectPip.build_group(effect, EffectPip.PROFILE_CARD, side))
	return panel


func _populate_statuses() -> void:
	for child in _status_row.get_children():
		child.queue_free()

	var statuses: Array = get_display_statuses(status_tokens)
	var max_visible: int = mini(statuses.size(), STATUS_MAX_VISIBLE)
	for i in range(max_visible):
		_status_row.add_child(build_status_chip(statuses[i]))
	if statuses.size() > max_visible:
		_status_row.add_child(_make_status_overflow(statuses.size() - max_visible))


func get_display_statuses(raw_statuses: Array) -> Array:
	var statuses: Array = []
	for raw_status in raw_statuses:
		var status: Dictionary = _normalize_status(raw_status)
		if not status.is_empty():
			statuses.append(status)
	statuses.sort_custom(Callable(self, "_sort_statuses_by_priority"))
	return statuses


# Direction-05 status "sticker": type-color border, dark dithered fill, hard offset
# drop shadow, pip icon + stack number inside. Type = color (shield cyan / poison
# violet / burn amber), with our prepared pip icons embedded.
func _status_badge_palette(status: Dictionary) -> Dictionary:
	var kind: String = _status_effect_kind(status).to_lower()
	# Border, number font, and icon ALL share the infliction's color.
	var border: Color
	if kind in ["shield", "taunt", "block", "barrier"]:
		border = PixelUI.DT_STATUS["shield"]["border"]
	elif kind in ["poison", "venom"]:
		border = PixelUI.DT_STATUS["poison"]["border"]
	elif kind in ["burn", "dot", "fire", "bleed"]:
		border = PixelUI.DT_STATUS["burn"]["border"]
	elif kind in ["roll", "rfe", "rfm", "roll_down", "roll_up", "buff", "debuff"]:
		if kind == "roll_up":
			border = PixelUI.COLOR_HEAL
		elif kind == "roll_down":
			border = PixelUI.COLOR_ROLL
		else:
			border = PixelUI.COLOR_ROLL
	else:
		border = _status_color(kind)
	return {"border": border, "fill": Color(0.02, 0.03, 0.05, 0.92), "text": border}


# Tint every label (font) and icon (modulate) inside a status badge to the status
# color, so border + number + icon all read as one color.
func _tint_status_content(node: Node, color: Color) -> void:
	for child in node.get_children():
		if child is Label:
			(child as Label).add_theme_color_override("font_color", color)
		elif child is TextureRect:
			(child as TextureRect).modulate = color
		if child.get_child_count() > 0:
			_tint_status_content(child, color)


func build_status_chip(status: Dictionary) -> Control:
	var pal: Dictionary = _status_badge_palette(status)
	var badge: PanelContainer = PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_STOP
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBoxFlat = PixelUI.make_hard_style(pal["fill"], pal["border"], 2)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	style.shadow_size = 3
	style.shadow_offset = Vector2(5, 5)
	style.set_content_margin_all(3.0)
	badge.add_theme_stylebox_override("panel", style)
	_connect_passthrough_input(badge)

	var chip: HBoxContainer = HBoxContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_theme_constant_override("separation", 1)
	badge.add_child(chip)

	if _is_frozen_status(status):
		chip.custom_minimum_size = Vector2(STATUS_ICON_MIN_WIDTH, STATUS_CHIP_HEIGHT)
		chip.add_child(_make_status_icon_control(status))
	elif str(status.get("mode", "named")) == "numeric":
		chip.custom_minimum_size = Vector2(STATUS_NUMERIC_MIN_WIDTH, STATUS_CHIP_HEIGHT)
		chip.add_child(_make_status_icon_control(status))
		chip.add_child(_make_status_value_label(status))
	else:
		chip.custom_minimum_size = Vector2(0, STATUS_CHIP_HEIGHT)
		chip.add_child(_make_status_name_label(status))
		if str(status.get("value", "")) != "":
			chip.add_child(_make_status_value_label(status))
	_tint_status_content(chip, pal["border"])
	return badge


func _make_status_icon_control(status: Dictionary) -> Control:
	var icon_kind: String = _status_effect_kind(status)
	var icon_texture: Texture2D = _get_pip_icon_texture(icon_kind) if icon_kind != "" else null
	if icon_texture != null:
		var wrap := CenterContainer.new()
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.custom_minimum_size = Vector2(STATUS_ICON_MIN_WIDTH, STATUS_CHIP_HEIGHT)
		wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var icon := TextureRect.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.custom_minimum_size = Vector2(STATUS_ICON_TEXTURE_SIZE, STATUS_ICON_TEXTURE_SIZE)
		icon.texture = icon_texture
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		wrap.add_child(icon)
		return wrap

	return _make_status_icon_label(status)


func _make_status_icon_label(status: Dictionary) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _is_frozen_status(status):
		label.text = "â„"
	else:
		label.text = str(status.get("icon", _status_icon_for_type(str(status.get("type", "")))))
	label.custom_minimum_size = Vector2(STATUS_ICON_MIN_WIDTH, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", STATUS_ICON_FONT_SIZE)
	label.add_theme_color_override("font_color", PixelUI.GOLD_ACCENT)
	label.add_theme_color_override("font_outline_color", Color.TRANSPARENT)
	label.add_theme_constant_override("outline_size", 0)
	return label


func _is_frozen_status(status: Dictionary) -> bool:
	var status_type: String = str(status.get("type", "")).to_lower()
	return status_type == "frozen" or status_type == "freeze" or status_type == "die_freeze"


func _status_effect_kind(status: Dictionary) -> String:
	var status_type: String = str(status.get("type", "")).to_lower()
	match status_type:
		"poison", "dot":
			return "poison"
		"shield":
			return "shield"
		"roll", "rfe", "rfm":
			return PixelUI.pip_key_for_effect(status_type, str(status.get("value", "")))
		"frozen", "freeze", "die_freeze":
			return "freeze"
	return ""


func _make_status_value_label(status: Dictionary) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = _display_status_value(status)
	label.custom_minimum_size = Vector2(STATUS_VALUE_MIN_WIDTH, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = false
	_apply_label(label, STATUS_VALUE_FONT_SIZE, PixelUI.GOLD_ACCENT, 0)
	return label


func _make_status_name_label(status: Dictionary) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = str(status.get("name", "")).to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_label(label, STATUS_NAME_FONT_SIZE, PixelUI.GOLD_ACCENT, 0)
	return label


func _make_status_overflow(hidden_count: int) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "+%d" % hidden_count
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_label(label, STATUS_NAME_FONT_SIZE, PixelUI.GOLD_ACCENT, 0)
	return label


func _normalize_status(raw_status: Variant) -> Dictionary:
	if raw_status is Dictionary:
		var status: Dictionary = (raw_status as Dictionary).duplicate(true)
		if not status.has("mode"):
			status["mode"] = "named" if status.has("name") else "numeric"
		if not status.has("priority"):
			status["priority"] = _status_priority(str(status.get("type", "")))
		return status
	return _normalize_legacy_status(str(raw_status))


func _normalize_legacy_status(token: String) -> Dictionary:
	var upper: String = token.strip_edges().to_upper()
	if upper == "":
		return {}
	var parts: PackedStringArray = upper.split(" ", false)
	var first: String = parts[0] if parts.size() > 0 else upper
	var value: String = parts[1] if parts.size() > 1 else ""

	if first.begins_with("POI") or first.begins_with("POT") or first == "DOT":
		return {"type": "poison", "mode": "numeric", "icon": "â˜ ", "value": value, "priority": 0}
	if first.begins_with("SH"):
		return {"type": "shield", "mode": "numeric", "icon": "ðŸ›¡", "value": value, "priority": 1}
	if first == "FROZEN" or first == "FREEZE" or first == "FR" or first == "DIE_FREEZE":
		return {"type": "frozen", "mode": "icon", "icon": "â„", "priority": 2}
	if first.begins_with("+") or first.begins_with("-") or first == "RFE" or first == "RFM":
		var roll_value: String = first if first != "RFE" and first != "RFM" else value
		return {"type": "roll", "mode": "numeric", "icon": "", "value": roll_value, "priority": 2}
	if first == "CL" or first == "CLOAK":
		return {"type": "named", "mode": "named", "name": "CLOAK", "priority": 3}
	if first == "COW" or first == "COWER":
		return {"type": "named", "mode": "named", "name": "COWER", "priority": 3}
	if first == "RMP" or first == "RAGE" or first == "RAMPAGE":
		return {"type": "named", "mode": "named", "name": "RAMPAGE", "value": value, "priority": 3}
	return {"type": "named", "mode": "named", "name": first, "priority": 9}


func _sort_statuses_by_priority(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("priority", 99)) < int(b.get("priority", 99))


func _status_priority(status_type: String) -> int:
	match status_type.to_lower():
		"poison", "dot":
			return 0
		"shield":
			return 1
		"roll", "rfe", "rfm":
			return 2
		"named":
			return 3
	return 9


func _status_icon_for_type(status_type: String) -> String:
	match status_type.to_lower():
		"poison", "dot":
			return "â˜ "
		"shield":
			return "ðŸ›¡"
		"roll", "rfe", "rfm":
			return "ðŸŽ²"
		"frozen", "freeze", "die_freeze":
			return "â„"
	return ""


func _team_border_color() -> Color:
	return HERO_LINE if side == "hero" else ENEMY_LINE


func _line_color() -> Color:
	if selected:
		return SELECT_LINE
	if targetable:
		if side == "enemy":
			return PixelUI.DT_ENEMY_DITHER
		return PixelUI.DT_HERO_DITHER
	return _team_border_color()


func _name_font_color(is_hero: bool) -> Color:
	var base: Color = PixelUI.DT_HERO_NAME if is_hero else PixelUI.DT_ENEMY_NAME
	if dead:
		return base.darkened(0.4).lerp(PixelUI.TEXT_MUTED, 0.55)
	if needs_manual_target and not selected and is_hero:
		return PixelUI.DT_CYAN_BRIGHT.lerp(Color.WHITE, 0.38)
	return base


func _status_color(token: String) -> Color:
	return PixelUI.status_color(token)


func _pip_border(kind: String) -> Color:
	match kind:
		"dmg", "blast", "pierce":
			return Color(0.86, 0.32, 0.28, 0.92)
		"heal", "revive":
			return Color(0.38, 0.82, 0.55, 0.92)
		"shield", "taunt":
			return Color(0.42, 0.66, 0.88, 0.92)
		"dot", "poison":
			return Color(0.82, 0.40, 0.58, 0.92)
		"roll", "rfe", "rfm", "roll_down":
			return Color(0.86, 0.66, 0.26, 0.92)
		"roll_up":
			return Color(0.38, 0.82, 0.55, 0.92)
		"frozen", "freeze", "die_freeze", "cloak":
			return Color(0.48, 0.78, 0.88, 0.92)
	return Color(0.34, 0.52, 0.70, 0.86)


func _display_status_value(status: Dictionary) -> String:
	var status_type: String = str(status.get("type", "")).to_lower()
	var raw_value: String = str(status.get("value", "")).strip_edges().to_upper()
	if status_type in ["roll", "rfe", "rfm"]:
		return PixelUI.format_amount_no_sign(raw_value)
	return raw_value


func _ensure_preview_rects() -> void:
	if _hp_back == null:
		return
	if _preview_rect_red == null or not is_instance_valid(_preview_rect_red):
		_preview_rect_red = _make_preview_rect("PreviewRed")
	if _preview_rect_blue == null or not is_instance_valid(_preview_rect_blue):
		_preview_rect_blue = _make_preview_rect("PreviewBlue")
	if _preview_rect_purple == null or not is_instance_valid(_preview_rect_purple):
		_preview_rect_purple = _make_preview_rect("PreviewPurple")
	if _preview_rect_heal == null or not is_instance_valid(_preview_rect_heal):
		_preview_rect_heal = _make_preview_rect("PreviewHeal")
	if _hp_label != null:
		_hp_label.z_index = 3


func _make_preview_rect(rect_name: String) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.name = rect_name
	rect.z_index = 2
	rect.visible = false
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.anchor_left = 0.0
	rect.anchor_top = 0.0
	rect.anchor_right = 0.0
	rect.anchor_bottom = 0.0
	_hp_back.add_child(rect)
	return rect


func _hide_preview_rects() -> void:
	for rect_variant in [_preview_rect_red, _preview_rect_blue, _preview_rect_purple, _preview_rect_heal]:
		var rect: ColorRect = rect_variant
		if rect != null and is_instance_valid(rect):
			rect.visible = false
			rect.position = Vector2.ZERO
			rect.size = Vector2.ZERO


func _place_preview_rect(rect: ColorRect, x_hp: float, width_hp: float, hp_max: float, bar_w: float, bar_h: float, color: Color) -> void:
	if rect == null or not is_instance_valid(rect):
		return
	if width_hp <= 0.0:
		rect.visible = false
		rect.position = Vector2.ZERO
		rect.size = Vector2.ZERO
		return
	rect.visible = true
	rect.color = color
	rect.position = Vector2((x_hp / hp_max) * bar_w, 0.0)
	rect.size = Vector2((width_hp / hp_max) * bar_w, bar_h)


# ── HP preview: net-outcome projection ───────────────────────────────────────
# The bar answers the one question the player is actually asking during
# targeting — "if I lock this in, where does my HP end up?" — by projecting the
# round in real resolution order (hero heals/shields land first, then enemy
# damage, then the poison tick; damage and poison both drain shields before
# HP). Zones painted on the bar:
#   red    [final, current]              net HP loss (attributed damage-first)
#   purple leftmost slice of that loss = the poison tick's unshielded share
#   mint   [current, final]              net HP gain
#   blue   [no-shield final, final]      loss the shield prevented (counterfactual)
# Intermediate states are deliberately NOT shown: the resolution order is
# fixed, so mid-round numbers carry no decision the endpoint doesn't, and the
# old sequential slabs painted contradictory futures (damage measured from
# pre-heal HP next to a detached heal strip). Per-source composition stays
# readable in the ability readout pips.
func _layout_preview_overlays() -> void:
	if _hp_back == null or _preview_effects.is_empty():
		_hide_preview_rects()
		_update_hp_label_preview(-1)
		if _hp_chip != null:
			_hp_chip.visible = true
		return

	_ensure_preview_rects()
	# The resolution-feedback chip animates forecast-vs-displayed HP; while a
	# preview is active it must not fight the projection overlays.
	if _hp_chip != null:
		_hp_chip.visible = false
	var bar_w: float = _hp_back.size.x
	var bar_h: float = _hp_back.size.y
	if bar_w <= 2.0 or bar_h <= 2.0:
		return

	var hp_max: float = maxf(float(max_hp), 1.0)
	var cur_hp: float = clampf(float(current_hp), 0.0, hp_max)
	var cur_shield: float = float(int(_preview_effects.get("current_shield", 0)))
	var inc_dmg: float = float(int(_preview_effects.get("damage", 0)))
	var inc_heal: float = float(int(_preview_effects.get("heal", 0)))
	var inc_shield: float = float(int(_preview_effects.get("shield", 0)))
	var dot_tick: float = float(int(_preview_effects.get("dot", 0)))
	var lethal: bool = bool(_preview_effects.get("lethal", false))

	# Project the round in resolution order.
	var post_heal: float = minf(cur_hp + inc_heal, hp_max)
	var total_shield: float = cur_shield + inc_shield
	var absorbed: float = minf(inc_dmg, total_shield)
	var hp_dmg: float = inc_dmg - absorbed
	var shield_after: float = total_shield - absorbed
	var hp_dot: float = dot_tick - minf(dot_tick, shield_after)
	var final_hp: float = clampf(post_heal - hp_dmg - hp_dot, 0.0, hp_max)
	var no_shield_final: float = clampf(post_heal - inc_dmg - dot_tick, 0.0, hp_max)

	_hide_preview_rects()
	if lethal or (final_hp <= 0.0 and cur_hp > 0.0):
		_place_preview_rect(_preview_rect_red, 0.0, cur_hp, hp_max, bar_w, HP_FILL_HEIGHT, PixelUI.COLOR_DAMAGE)
		_update_hp_label_preview(0)
		return

	if final_hp < cur_hp:
		var loss: float = cur_hp - final_hp
		var dot_slice: float = minf(hp_dot, loss)
		_place_preview_rect(_preview_rect_purple, final_hp, dot_slice, hp_max, bar_w, HP_FILL_HEIGHT, Color(0.62, 0.18, 0.82, 0.85))
		_place_preview_rect(_preview_rect_red, final_hp + dot_slice, loss - dot_slice, hp_max, bar_w, HP_FILL_HEIGHT, PixelUI.COLOR_DAMAGE)
	elif final_hp > cur_hp:
		_place_preview_rect(_preview_rect_heal, cur_hp, final_hp - cur_hp, hp_max, bar_w, HP_FILL_HEIGHT, PixelUI.DT_HP_GREEN)

	# The slice the shield eats, shown below the real endpoint: "without your
	# shield you would end HERE."
	var protected_to: float = minf(final_hp, cur_hp)
	if no_shield_final < protected_to:
		_place_preview_rect(_preview_rect_blue, no_shield_final, protected_to - no_shield_final, hp_max, bar_w, HP_FILL_HEIGHT, Color(0.22, 0.55, 0.95, 0.80))

	_update_hp_label_preview(int(roundf(final_hp)))


# "45 → 37 / 55" while a net-changing preview is active; plain "45 / 55" otherwise.
func _update_hp_label_preview(final_hp_preview: int) -> void:
	if _hp_label == null:
		return
	if final_hp_preview < 0 or final_hp_preview == current_hp:
		_hp_label.text = "%d / %d" % [maxi(current_hp, 0), maxi(max_hp, 1)]
	else:
		_hp_label.text = "%d → %d / %d" % [maxi(current_hp, 0), final_hp_preview, maxi(max_hp, 1)]


func _wire_hp_passthrough() -> void:
	if _hp_back == null:
		return
	_hp_back.mouse_filter = Control.MOUSE_FILTER_STOP
	_connect_passthrough_input(_hp_back)


func _connect_passthrough_input(control: Control) -> void:
	if control == null or bool(control.get_meta("compact_passthrough_connected", false)):
		return
	control.set_meta("compact_passthrough_connected", true)
	control.gui_input.connect(_on_passthrough_gui_input)


# Forwards presses on the STOP'd HP-bar region to the card's own gui_input so a tap/long-press
# there still selects/inspects the unit instead of being swallowed.
func _on_passthrough_gui_input(event: InputEvent) -> void:
	_gui_input(event)


func _wire_portrait_detail_input() -> void:
	if _portrait_rect == null:
		return
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if _portrait_long_press != null and is_instance_valid(_portrait_long_press):
		return
	# The ONE shared long-press handler (duration = PixelUI.INSPECT_HOLD_SEC). Quick tap
	# selects the unit; long-press opens the unified inspect breakout.
	_portrait_long_press = LongPressInput.new()
	_portrait_rect.add_child(_portrait_long_press)
	_portrait_long_press.tapped.connect(_on_portrait_tapped)
	_portrait_long_press.long_pressed.connect(_on_portrait_long_pressed)


func _on_portrait_tapped() -> void:
	if interaction_enabled:
		card_pressed.emit()


func _on_portrait_long_pressed(_global_position: Vector2) -> void:
	unit_detail_requested.emit(self)


func _set_descendants_mouse_filter(node: Node, filter: Control.MouseFilter) -> void:
	for child in node.get_children():
		if child is Control:
			var control: Control = child as Control
			control.mouse_filter = filter
		_set_descendants_mouse_filter(child, filter)


func _apply_label(label: Label, font_size: int, color: Color, outline: int = 1) -> void:
	PixelUI.apply_pixel_font(label)
	label.add_theme_font_size_override("font_size", maxi(1, font_size))
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.TRANSPARENT if outline <= 0 else Color(0.01, 0.015, 0.025, 0.98))
	label.add_theme_constant_override("outline_size", outline)


func _style(bg: Color, border: Color, border_width: int, margin: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.anti_aliasing = false
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.set_content_margin(SIDE_LEFT, margin)
	style.set_content_margin(SIDE_TOP, margin)
	style.set_content_margin(SIDE_RIGHT, margin)
	style.set_content_margin(SIDE_BOTTOM, margin)
	return style
