class_name CompactUnitCard
extends PanelContainer

signal card_pressed
signal unit_detail_requested(card)

const CARD_SIZE := Vector2(260, 0)
const PORTRAIT_HEIGHT_RATIO := 1.20
const PORTRAIT_MIN_HEIGHT := 100.0
const NAME_ROW_HEIGHT := 104.0
const HP_BAR_HEIGHT := 116.0
const STATUS_ROW_HEIGHT := 84.0
const ACTION_PANEL_HEIGHT := 64.0
const PORTRAIT_ASPECT_FALLBACK := 2.0
const PORTRAIT_X_OFFSET := -10.0
const PORTRAIT_Y_OFFSET := -10.0
const MENAGERIE_PORTRAIT_Y_OFFSET_DELTA := -8.0
const HERO_LINE := Color(0.18, 0.90, 0.64, 1.0)
const ENEMY_LINE := Color(0.82, 0.36, 0.34, 1.0)
const SELECT_LINE := Color(0.95, 0.66, 0.22, 1.0)
const TARGET_LINE := Color(0.42, 0.70, 0.95, 1.0)
const HP_FILL := Color(0.10, 0.46, 0.32, 1.0)
const STATUS_MAX_VISIBLE := 3
const STATUS_ICON_FONT_SIZE := 24
const STATUS_VALUE_FONT_SIZE := 26
const STATUS_NAME_FONT_SIZE := 22
const STATUS_ICON_MIN_WIDTH := 30.0
const STATUS_VALUE_MIN_WIDTH := 36.0
const STATUS_NUMERIC_MIN_WIDTH := 72.0
const STATUS_CHIP_HEIGHT := 30.0
const STATUS_DESCRIPTIONS := {
	"shield": "Absorbs {value} incoming damage.",
	"poison": "Takes {value} damage at the start of next turn.",
	"frozen": "Die result is locked and cannot be changed this turn.",
	"cloak": "80% chance to evade the next incoming damage attempt.",
	"cower": "Cannot deal damage this turn.",
	"taunt": "Enemies must target this unit.",
	"rampage": "Deals double damage this turn.",
	"counter": "{value}% chance to reflect the next targeted hero attack.",
	"cursed": "Abilities trigger at reduced effectiveness.",
	"down": "Knocked out. Cannot act until revived.",
	"roll": "Shift die roll by {value}.",
	"rfe": "Shift die roll by {value}.",
	"rfm": "Shift die roll by {value}.",
}
const PIP_ICON_MAP := {
	"dmg": preload("res://assets/generated/icon_damage_1776027930.png"),
	"blast": preload("res://assets/generated/icon_damage_1776027930.png"),
	"heal": preload("res://assets/generated/icon_heal_heart_1776027943.png"),
	"shield": preload("res://assets/generated/icon_shield_1776027929.png"),
	"taunt": preload("res://assets/generated/icon_shield_1776027929.png"),
	"dot": preload("res://assets/generated/icon_dot_1776027932.png"),
	"roll": preload("res://assets/generated/icon_dice_d6_1776027927.png"),
	"rfe": preload("res://assets/generated/icon_dice_d6_1776027927.png"),
	"rfm": preload("res://assets/generated/icon_dice_d6_1776027927.png"),
	"freeze": preload("res://assets/generated/icon_frost_snowflake_frame_0_1776027966.png"),
	"cloak": preload("res://assets/generated/icon_dice_v2_1776040041.png"),
}
const PIP_ICON_ATLAS_PATH := "res://assets/ui/icons/pip_icons.png"
const PIP_ICON_CELL_SIZE := Vector2(256, 256)
const PIP_ICON_COLUMNS := {
	"dmg": 0,
	"damage": 0,
	"blast": 0,
	"shield": 1,
	"taunt": 1,
	"heal": 2,
	"dot": 3,
	"poison": 3,
	"roll": 4,
	"rfe": 4,
	"rfm": 4,
	"freeze": 5,
}

var side: String = "hero"
var unit_name: String = "SYSTEMS MED"
var current_hp: int = 45
var max_hp: int = 45
var action_text: String = "READY"
var action_pips: Array = []
var portrait: Texture2D = null
var status_tokens: Array = ["POI", "CL"]
var selected: bool = false
var targetable: bool = false
var interaction_enabled: bool = true
var dead: bool = false
var show_action_pips: bool = true
var unit_data: Resource = null
var gear_detail_rows: Array = []

var _name_label: Label = null
var _portrait_frame: PanelContainer = null
var _portrait_crop: Control = null
var _portrait_rect: TextureRect = null
var _hp_back: Panel = null
var _hp_label: Label = null
var _hp_fill: ColorRect = null
var _action_panel: PanelContainer = null
var _action_grid: HFlowContainer = null
var _status_slot: Control = null
var _status_row: HBoxContainer = null
var _preview_effects: Dictionary = {}
var _preview_rect_red: ColorRect = null
var _preview_rect_blue: ColorRect = null
var _preview_rect_purple: ColorRect = null
var _preview_rect_teal: ColorRect = null
var _preview_rect_heal: ColorRect = null
var _locked_layout_size: Vector2 = Vector2.ZERO
var _locked_portrait_width: float = 0.0
var _locked_portrait_size: Vector2 = Vector2.ZERO
var _tooltip_cb: Callable = Callable()
var _hp_tooltip_text: String = "HEALTH PREVIEW\nNo incoming effects this turn."
var _portrait_hold_timer: Timer = null
var _portrait_hold_pressed: bool = false
var _portrait_hold_triggered: bool = false
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
		call_deferred("_layout_preview_overlays")


func configure(data: Dictionary) -> void:
	side = str(data.get("side", side))
	unit_name = str(data.get("name", unit_name))
	current_hp = int(data.get("current_hp", current_hp))
	max_hp = int(data.get("max_hp", max_hp))
	action_text = str(data.get("action", action_text))
	action_pips = data.get("pips", action_pips)
	portrait = data.get("portrait", portrait) as Texture2D
	status_tokens = data.get("statuses", status_tokens)
	selected = bool(data.get("selected", selected))
	targetable = bool(data.get("targetable", targetable))
	interaction_enabled = bool(data.get("interaction_enabled", interaction_enabled))
	dead = bool(data.get("dead", dead))
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


func set_selected(value: bool) -> void:
	selected = value
	_refresh()


func set_targetable(value: bool) -> void:
	targetable = value
	_refresh()


func set_interaction_enabled(value: bool) -> void:
	interaction_enabled = value
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW


func set_tooltip_callback(callback: Callable) -> void:
	_tooltip_cb = callback
	_wire_hp_tooltip()


func show_combat_preview(effects: Dictionary) -> void:
	_preview_effects = effects.duplicate(true)
	_ensure_preview_rects()
	_hp_tooltip_text = _build_preview_tooltip(_preview_effects)
	_wire_hp_tooltip()
	call_deferred("_layout_preview_overlays")


func clear_combat_preview() -> void:
	_preview_effects.clear()
	_hide_preview_rects()
	_hp_tooltip_text = "HEALTH PREVIEW\nNo incoming effects this turn."
	_wire_hp_tooltip()


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
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_bottom", 2)
	add_child(margin)

	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(root)

	_name_label = Label.new()
	_name_label.custom_minimum_size = Vector2(0, NAME_ROW_HEIGHT)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_label(_name_label, 36, PixelUI.TEXT_PRIMARY, 2)
	root.add_child(_name_label)

	_portrait_frame = PanelContainer.new()
	_portrait_frame.custom_minimum_size = Vector2(0, PORTRAIT_MIN_HEIGHT)
	_portrait_frame.clip_contents = true
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
	_portrait_rect.clip_contents = true
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portrait_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_portrait_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_crop.add_child(_portrait_rect)

	_hp_back = Panel.new()
	_hp_back.custom_minimum_size = Vector2(0, HP_BAR_HEIGHT)
	_hp_back.clip_contents = true
	_hp_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_back.add_theme_stylebox_override("panel", _style(Color(0.006, 0.012, 0.020, 1.0), Color.TRANSPARENT, 0, 0))
	root.add_child(_hp_back)

	_hp_fill = ColorRect.new()
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_fill.color = HP_FILL
	_hp_fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_fill.z_index = 0
	_hp_back.add_child(_hp_fill)

	_hp_label = Label.new()
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_label.z_index = 3
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_label(_hp_label, 36, PixelUI.TEXT_PRIMARY, 2)
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
	_status_slot.custom_minimum_size = Vector2(0, STATUS_ROW_HEIGHT)
	_status_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_status_slot.clip_contents = true
	root.add_child(_status_slot)

	_status_row = HBoxContainer.new()
	_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_status_row.custom_minimum_size = Vector2.ZERO
	_status_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_status_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_status_row.clip_contents = true
	_status_row.add_theme_constant_override("separation", 6)
	_status_slot.add_child(_status_row)


func _refresh() -> void:
	if _name_label == null:
		return

	var line_color: Color = _line_color()
	PixelUI.style_ninepatch_panel(self, PixelUI.FRAME_GLOW, 10, line_color.lerp(Color.WHITE, 0.35))
	_portrait_frame.add_theme_stylebox_override("panel", _style(Color(0.006, 0.012, 0.020, 0.78), Color.TRANSPARENT, 0, 0))
	_action_panel.add_theme_stylebox_override("panel", _style(Color(0.010, 0.020, 0.032, 0.58), Color.TRANSPARENT, 0, 0))
	_action_panel.visible = show_action_pips
	if _locked_portrait_size == Vector2.ZERO:
		_update_portrait_size()

	_name_label.text = unit_name.to_upper()
	_hp_label.text = "%d / %d" % [maxi(current_hp, 0), maxi(max_hp, 1)]
	_portrait_rect.texture = portrait

	var hp_ratio: float = clampf(float(current_hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	_hp_fill.anchor_right = hp_ratio
	_hp_fill.offset_right = 0
	_hp_fill.color = HP_FILL

	_portrait_rect.modulate = Color(0.48, 0.50, 0.58, 0.55) if dead else Color.WHITE
	modulate = Color(0.55, 0.56, 0.62, 0.72) if dead else Color.WHITE
	if show_action_pips:
		_populate_action_pips()
	_populate_statuses()
	_layout_preview_overlays()


func _update_portrait_size() -> void:
	if _portrait_frame == null:
		return
	var target_width: float = _locked_portrait_width
	if target_width <= 2.0:
		target_width = _portrait_frame.size.x
	if target_width <= 2.0:
		target_width = maxf(size.x - 24.0, CARD_SIZE.x - 24.0)
	var max_portrait_height: float = INF
	if _locked_layout_size.y > 2.0:
		var action_height: float = 0.0 if not show_action_pips else ACTION_PANEL_HEIGHT
		var reserved_height := NAME_ROW_HEIGHT + HP_BAR_HEIGHT + STATUS_ROW_HEIGHT + action_height + 24.0
		max_portrait_height = maxf(PORTRAIT_MIN_HEIGHT, _locked_layout_size.y - reserved_height)
	var target_height: float = clampf(floor(target_width * PORTRAIT_HEIGHT_RATIO), PORTRAIT_MIN_HEIGHT, max_portrait_height)
	_locked_portrait_size = Vector2(target_width, target_height)
	_portrait_frame.custom_minimum_size = Vector2(0, target_height)


func _populate_action_pips() -> void:
	for child in _action_grid.get_children():
		child.queue_free()

	if action_pips.is_empty():
		_action_grid.add_child(_make_action_fallback(action_text))
		return

	var max_visible: int = mini(action_pips.size(), 5)
	for i in range(max_visible):
		var pip: Dictionary = action_pips[i]
		_action_grid.add_child(_make_action_pip(str(pip.get("kind", "")), str(pip.get("text", ""))))
	if action_pips.size() > max_visible:
		_action_grid.add_child(_make_action_pip("more", "+%d" % (action_pips.size() - max_visible)))


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
	if PIP_ICON_COLUMNS.has(kind):
		var atlas := _get_pip_icon_atlas()
		if atlas == null:
			return null
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = Rect2(Vector2(float(int(PIP_ICON_COLUMNS[kind])) * PIP_ICON_CELL_SIZE.x, 0.0), PIP_ICON_CELL_SIZE)
		return texture
	return PIP_ICON_MAP.get(kind)


func _get_pip_icon_atlas() -> Texture2D:
	if _pip_icon_atlas != null:
		return _pip_icon_atlas
	var image: Image = Image.load_from_file(PIP_ICON_ATLAS_PATH)
	if image == null or image.is_empty():
		return null
	_pip_icon_atlas = ImageTexture.create_from_image(image)
	return _pip_icon_atlas


func _make_action_pip(kind: String, text: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(84, 54)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _style(Color(0.006, 0.012, 0.020, 0.72), _pip_border(kind), 3, 5))

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	panel.add_child(row)

	var icon: TextureRect = TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(34, 34)
	icon.texture = _get_pip_icon_texture(kind)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = _format_pip_text(kind, text)
	label.custom_minimum_size = Vector2(32, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_label(label, 28, PixelUI.TEXT_PRIMARY, 2)
	row.add_child(label)
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


func build_status_chip(status: Dictionary) -> Control:
	var chip: HBoxContainer = HBoxContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.alignment = BoxContainer.ALIGNMENT_CENTER
	chip.add_theme_constant_override("separation", 3)
	_connect_passthrough_input(chip)

	if _is_frozen_status(status):
		chip.custom_minimum_size = Vector2(46, STATUS_CHIP_HEIGHT)
		chip.add_child(_make_status_icon_label(status))
	elif str(status.get("mode", "named")) == "numeric":
		chip.custom_minimum_size = Vector2(STATUS_NUMERIC_MIN_WIDTH, STATUS_CHIP_HEIGHT)
		chip.add_child(_make_status_icon_label(status))
		chip.add_child(_make_status_value_label(status))
	else:
		chip.custom_minimum_size = Vector2(0, STATUS_CHIP_HEIGHT)
		chip.add_child(_make_status_name_label(status))
		if str(status.get("value", "")) != "":
			chip.add_child(_make_status_value_label(status))
	if _tooltip_cb.is_valid():
		_tooltip_cb.call(chip, _build_status_tooltip(status))
	return chip


func _make_status_icon_label(status: Dictionary) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _is_frozen_status(status):
		label.text = "❄"
	else:
		label.text = str(status.get("icon", _status_icon_for_type(str(status.get("type", "")))))
	label.custom_minimum_size = Vector2(STATUS_ICON_MIN_WIDTH, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12 if _is_frozen_status(status) else STATUS_ICON_FONT_SIZE)
	label.add_theme_color_override("font_color", Color("#88ccff") if _is_frozen_status(status) else _status_content_color(status, true))
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.025, 0.98))
	label.add_theme_constant_override("outline_size", 2)
	return label


func _is_frozen_status(status: Dictionary) -> bool:
	var status_type: String = str(status.get("type", "")).to_lower()
	return status_type == "frozen" or status_type == "freeze" or status_type == "die_freeze"


func _make_status_value_label(status: Dictionary) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = str(status.get("value", "")).to_upper()
	label.custom_minimum_size = Vector2(STATUS_VALUE_MIN_WIDTH, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = false
	_apply_label(label, STATUS_VALUE_FONT_SIZE, _status_content_color(status, false), 2)
	return label


func _make_status_name_label(status: Dictionary) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = str(status.get("name", "")).to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_label(label, STATUS_NAME_FONT_SIZE, PixelUI.TEXT_MUTED, 2)
	return label


func _make_status_overflow(hidden_count: int) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "+%d" % hidden_count
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_label(label, STATUS_NAME_FONT_SIZE, PixelUI.TEXT_MUTED, 2)
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
		return {"type": "poison", "mode": "numeric", "icon": "☠", "value": value, "priority": 0}
	if first.begins_with("SH"):
		return {"type": "shield", "mode": "numeric", "icon": "🛡", "value": value, "priority": 1}
	if first == "FROZEN" or first == "FREEZE" or first == "FR" or first == "DIE_FREEZE":
		return {"type": "frozen", "mode": "icon", "icon": "❄", "priority": 2}
	if first.begins_with("+") or first.begins_with("-") or first == "RFE":
		var roll_value: String = first if first != "RFE" else value
		return {"type": "roll", "mode": "numeric", "icon": "🎲", "value": roll_value, "priority": 2}
	if first == "CL" or first == "CLOAK":
		return {"type": "named", "mode": "named", "name": "CLOAK", "priority": 3}
	if first == "COW" or first == "COWER":
		return {"type": "named", "mode": "named", "name": "COWER", "priority": 3}
	if first == "RMP" or first == "RAGE" or first == "RAMPAGE":
		return {"type": "named", "mode": "named", "name": "RAMPAGE", "value": value, "priority": 3}
	return {"type": "named", "mode": "named", "name": first, "priority": 9}


func _build_status_tooltip(status: Dictionary) -> String:
	var key: String = _get_status_description_key(status)
	var title: String = _get_status_title(status)
	if key == "roll" or key == "rfe" or key == "rfm":
		var value: String = str(status.get("value", "")).strip_edges()
		if value != "":
			return "%s\nShift die roll by %s." % [title, value]
	if key == "shield" or key == "poison" or key == "counter":
		var status_value: String = str(status.get("value", "0")).strip_edges()
		if status_value == "":
			status_value = "0"
		var valued_description: String = str(STATUS_DESCRIPTIONS.get(key, "")).replace("{value}", status_value)
		return "%s\n%s" % [title, valued_description]
	var description: String = str(STATUS_DESCRIPTIONS.get(key, "Status effect: %s" % title.to_lower()))
	return "%s\n%s" % [title, description]


func _get_status_description_key(status: Dictionary) -> String:
	var status_type: String = str(status.get("type", "")).to_lower()
	if status_type == "named":
		return str(status.get("name", "")).to_lower().replace(" ", "_")
	if status_type == "dot":
		return "poison"
	if status_type == "phase2":
		return "phase_two"
	return status_type


func _get_status_title(status: Dictionary) -> String:
	if str(status.get("mode", "named")) == "named":
		return str(status.get("name", status.get("type", "status"))).to_upper()
	return str(status.get("type", "status")).replace("_", " ").to_upper()


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
			return "☠"
		"shield":
			return "🛡"
		"roll", "rfe", "rfm":
			return "🎲"
		"frozen", "freeze", "die_freeze":
			return "❄"
	return ""


func _status_content_color(status: Dictionary, strong: bool) -> Color:
	var status_type: String = str(status.get("type", "")).to_lower()
	var effect_kind: String = ""
	match status_type:
		"poison", "dot":
			effect_kind = "dot"
		"shield":
			effect_kind = "shield"
		"roll", "rfe", "rfm":
			effect_kind = "roll"
		"frozen", "freeze", "die_freeze":
			effect_kind = "freeze"
		_:
			return PixelUI.TEXT_MUTED
	if strong:
		return PixelUI.effect_color(effect_kind)
	return PixelUI.effect_value_color(effect_kind)


func _line_color() -> Color:
	if selected:
		return SELECT_LINE
	if targetable:
		return TARGET_LINE
	if side == "enemy":
		return ENEMY_LINE
	return HERO_LINE


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
		"dot":
			return Color(0.82, 0.40, 0.58, 0.92)
		"roll", "rfe", "rfm":
			return Color(0.86, 0.66, 0.26, 0.92)
		"frozen", "freeze", "die_freeze", "cloak":
			return Color(0.48, 0.78, 0.88, 0.92)
	return Color(0.34, 0.52, 0.70, 0.86)


func _format_pip_text(kind: String, text: String) -> String:
	var value: String = text.strip_edges().to_upper()
	if value == "" and kind == "pierce":
		return "P"
	if value == "" and kind == "cloak":
		return "CL"
	if value == "" and kind == "taunt":
		return "TA"
	return value


func _ensure_preview_rects() -> void:
	if _hp_back == null:
		return
	if _preview_rect_red == null or not is_instance_valid(_preview_rect_red):
		_preview_rect_red = _make_preview_rect("PreviewRed")
	if _preview_rect_blue == null or not is_instance_valid(_preview_rect_blue):
		_preview_rect_blue = _make_preview_rect("PreviewBlue")
	if _preview_rect_purple == null or not is_instance_valid(_preview_rect_purple):
		_preview_rect_purple = _make_preview_rect("PreviewPurple")
	if _preview_rect_teal == null or not is_instance_valid(_preview_rect_teal):
		_preview_rect_teal = _make_preview_rect("PreviewTeal")
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
	for rect_variant in [_preview_rect_red, _preview_rect_blue, _preview_rect_purple, _preview_rect_teal, _preview_rect_heal]:
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


func _layout_preview_overlays() -> void:
	if _hp_back == null or _preview_effects.is_empty():
		_hide_preview_rects()
		return

	_ensure_preview_rects()
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

	if lethal:
		_place_preview_rect(_preview_rect_red, 0.0, cur_hp, hp_max, bar_w, bar_h, Color(0.88, 0.18, 0.14, 0.92))
		for rect_variant in [_preview_rect_blue, _preview_rect_purple, _preview_rect_teal, _preview_rect_heal]:
			var rect: ColorRect = rect_variant
			if rect != null and is_instance_valid(rect):
				rect.visible = false
		return

	var total_shield: float = cur_shield + inc_shield
	var blue_w: float = minf(total_shield, inc_dmg)
	var red_w: float = maxf(0.0, inc_dmg - blue_w)
	var shield_left: float = total_shield - blue_w
	var teal_w: float = minf(shield_left, dot_tick)
	var purple_w: float = maxf(0.0, dot_tick - teal_w)

	var red_x: float = maxf(0.0, cur_hp - red_w)
	var blue_x: float = maxf(0.0, red_x - blue_w)
	var purple_x: float = maxf(0.0, blue_x - purple_w)
	var teal_x: float = maxf(0.0, purple_x - teal_w)

	_place_preview_rect(_preview_rect_red, red_x, red_w, hp_max, bar_w, bar_h, Color(0.88, 0.18, 0.14, 0.88))
	_place_preview_rect(_preview_rect_blue, blue_x, blue_w, hp_max, bar_w, bar_h, Color(0.22, 0.55, 0.95, 0.80))
	_place_preview_rect(_preview_rect_purple, purple_x, purple_w, hp_max, bar_w, bar_h, Color(0.62, 0.18, 0.82, 0.85))
	_place_preview_rect(_preview_rect_teal, teal_x, teal_w, hp_max, bar_w, bar_h, Color(0.18, 0.72, 0.68, 0.75))

	var heal_eff: float = minf(inc_heal, hp_max - cur_hp)
	_place_preview_rect(_preview_rect_heal, cur_hp, heal_eff, hp_max, bar_w, bar_h, Color(0.28, 0.94, 0.50, 0.85))


func _wire_hp_tooltip() -> void:
	if _hp_back == null:
		return
	_hp_back.mouse_filter = Control.MOUSE_FILTER_STOP
	_connect_passthrough_input(_hp_back)
	if _tooltip_cb.is_valid():
		_tooltip_cb.call(_hp_back, _hp_tooltip_text)


func _build_preview_tooltip(effects: Dictionary) -> String:
	var lines: Array = ["HEALTH PREVIEW"]
	var inc_dmg: int = int(effects.get("damage", 0))
	var inc_heal: int = int(effects.get("heal", 0))
	var inc_shield: int = int(effects.get("shield", 0))
	var dot_tick: int = int(effects.get("dot", 0))
	var cur_shield: int = int(effects.get("current_shield", 0))
	var lethal: bool = bool(effects.get("lethal", false))

	if lethal:
		lines.append("Lethal: this unit will not survive the turn.")
		return "\n".join(lines)

	var total_shield: int = cur_shield + inc_shield
	if inc_dmg > 0:
		var absorbed: int = mini(total_shield, inc_dmg)
		var hp_lost: int = inc_dmg - absorbed
		if absorbed > 0 and hp_lost > 0:
			lines.append("%d damage: %d blocked by shield, %d to HP." % [inc_dmg, absorbed, hp_lost])
		elif absorbed > 0:
			lines.append("%d damage: fully blocked by shield." % inc_dmg)
		else:
			lines.append("%d damage to HP." % inc_dmg)

	if inc_shield > 0:
		if cur_shield > 0:
			lines.append("+%d shield, stacking with existing %d." % [inc_shield, cur_shield])
		else:
			lines.append("+%d incoming shield." % inc_shield)

	if dot_tick > 0:
		var shield_after_dmg: int = maxi(0, total_shield - mini(total_shield, inc_dmg))
		var dot_absorbed: int = mini(shield_after_dmg, dot_tick)
		var dot_hp_lost: int = dot_tick - dot_absorbed
		if dot_absorbed > 0 and dot_hp_lost > 0:
			lines.append("Poison tick: %d (%d blocked, %d to HP)." % [dot_tick, dot_absorbed, dot_hp_lost])
		elif dot_absorbed > 0:
			lines.append("Poison tick: %d, fully blocked by shield." % dot_tick)
		else:
			lines.append("Poison tick: %d to HP." % dot_tick)

	if inc_heal > 0:
		lines.append("+%d healing." % inc_heal)

	if lines.size() == 1:
		lines.append("No incoming effects this turn.")
	return "\n".join(lines)


func _connect_passthrough_input(control: Control) -> void:
	if control == null or bool(control.get_meta("compact_passthrough_connected", false)):
		return
	control.set_meta("compact_passthrough_connected", true)
	control.gui_input.connect(_on_tooltip_target_gui_input)


func _on_tooltip_target_gui_input(event: InputEvent) -> void:
	_gui_input(event)


func _wire_portrait_detail_input() -> void:
	if _portrait_rect == null:
		return
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	if _portrait_hold_timer == null:
		_portrait_hold_timer = Timer.new()
		_portrait_hold_timer.one_shot = true
		_portrait_hold_timer.wait_time = 0.5
		add_child(_portrait_hold_timer)
		_portrait_hold_timer.timeout.connect(_on_portrait_hold_timeout)
	if bool(_portrait_rect.get_meta("portrait_detail_input_connected", false)):
		return
	_portrait_rect.set_meta("portrait_detail_input_connected", true)
	_portrait_rect.gui_input.connect(_on_portrait_gui_input)
	_portrait_rect.mouse_exited.connect(_on_portrait_mouse_exited)


func _on_portrait_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_event.pressed:
			_start_portrait_hold()
		else:
			_finish_portrait_press()
		accept_event()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			_start_portrait_hold()
		else:
			_finish_portrait_press()
		accept_event()


func _start_portrait_hold() -> void:
	_portrait_hold_pressed = true
	_portrait_hold_triggered = false
	if _portrait_hold_timer != null:
		_portrait_hold_timer.start()


func _finish_portrait_press() -> void:
	if not _portrait_hold_pressed:
		return
	_portrait_hold_pressed = false
	if _portrait_hold_timer != null:
		_portrait_hold_timer.stop()
	if _portrait_hold_triggered:
		_portrait_hold_triggered = false
		return
	if interaction_enabled:
		card_pressed.emit()


func _on_portrait_mouse_exited() -> void:
	if not _portrait_hold_pressed:
		return
	_portrait_hold_pressed = false
	if _portrait_hold_timer != null:
		_portrait_hold_timer.stop()
	_portrait_hold_triggered = false


func _on_portrait_hold_timeout() -> void:
	if not _portrait_hold_pressed:
		return
	_portrait_hold_triggered = true
	unit_detail_requested.emit(self)


func _set_descendants_mouse_filter(node: Node, filter: Control.MouseFilter) -> void:
	for child in node.get_children():
		if child is Control:
			var control: Control = child as Control
			control.mouse_filter = filter
		_set_descendants_mouse_filter(child, filter)


func _apply_label(label: Label, font_size: int, color: Color, outline: int = 1) -> void:
	PixelUI.apply_pixel_font(label)
	var scaled: int = maxi(20, PixelUI.scale_font_size(font_size))
	label.add_theme_font_size_override("font_size", scaled)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.025, 0.98))
	label.add_theme_constant_override("outline_size", outline)


func _style(bg: Color, border: Color, border_width: int, margin: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.set_content_margin(SIDE_LEFT, margin)
	style.set_content_margin(SIDE_TOP, margin)
	style.set_content_margin(SIDE_RIGHT, margin)
	style.set_content_margin(SIDE_BOTTOM, margin)
	return style
