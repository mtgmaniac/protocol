class_name UnitDetailPanel
extends PanelContainer

const BG_COLOR := Color("#0d1117")
const BORDER_COLOR := Color("#2a3a52")
const TEXT_PRIMARY := Color("#f4f7fb")
const TEXT_MUTED := Color("#8fa0b8")
const TEXT_VERY_MUTED := Color("#59677a")
const HERO_ACCENT := Color("#6aa6ff")
const ENEMY_ACCENT := Color("#cc4444")
const PANEL_MAX_WIDTH := 438.0
const PANEL_MIN_WIDTH := 380.0
const PANEL_MARGIN := 6.0
const NAME_FONT_SIZE := 36
const ROLE_FONT_SIZE := 26
const GEAR_FONT_SIZE := 24
const TIER_FONT_SIZE := 30
const DESCRIPTION_FONT_SIZE := 24
const HINT_FONT_SIZE := 20
const DETAIL_PORTRAIT_SIZE := Vector2(70, 70)
const MENAGERIE_PORTRAIT_Y_OFFSET := -6.0

var _portrait_frame: Control = null
var _portrait_rect: TextureRect = null
var _name_label: Label = null
var _role_label: Label = null
var _gear_items: HBoxContainer = null
var _tiers_box: VBoxContainer = null
var _slide_tween: Tween = null
var _tooltip_cb: Callable = Callable()
var _current_data: Resource = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	z_index = 100
	clip_contents = true
	visible = false
	add_theme_stylebox_override("panel", _style(BG_COLOR, BORDER_COLOR, 2, 0))
	gui_input.connect(_on_gui_input)
	_build()


func show_for_unit(data: Resource, gear_rows: Array = []) -> void:
	if data == null:
		return
	_current_data = data
	_populate(data, gear_rows)
	if _slide_tween != null:
		_slide_tween.kill()
	visible = true
	await get_tree().process_frame
	_layout_portrait()
	var target_rect: Rect2 = _apply_panel_rect()
	position = Vector2(target_rect.position.x, target_rect.position.y + target_rect.size.y + PANEL_MARGIN)
	_slide_tween = create_tween()
	_slide_tween.set_ease(Tween.EASE_OUT)
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.tween_property(self, "position", target_rect.position, 0.12)


func set_tooltip_callback(cb: Callable) -> void:
	_tooltip_cb = cb


func hide_panel() -> void:
	if not visible:
		return
	if _slide_tween != null:
		_slide_tween.kill()
	var target_rect: Rect2 = _panel_target_rect()
	_slide_tween = create_tween()
	_slide_tween.set_ease(Tween.EASE_IN)
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.tween_property(self, "position", Vector2(position.x, target_rect.position.y + target_rect.size.y + PANEL_MARGIN), 0.10)
	_slide_tween.finished.connect(func() -> void:
		visible = false
	)


func _apply_panel_rect() -> Rect2:
	var target_rect: Rect2 = _panel_target_rect()
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = target_rect.size
	size = target_rect.size
	return target_rect


func _panel_target_rect() -> Rect2:
	var parent_size := Vector2(450.0, 260.0)
	var parent_control: Control = get_parent() as Control
	if parent_control != null:
		parent_size = parent_control.size
	var viewport_height: float = get_viewport().get_visible_rect().size.y
	var content_height: float = get_combined_minimum_size().y
	var panel_width: float = minf(PANEL_MAX_WIDTH, maxf(PANEL_MIN_WIDTH, parent_size.x - (PANEL_MARGIN * 2.0)))
	var panel_height: float = minf(viewport_height - (PANEL_MARGIN * 2.0), maxf(parent_size.y - (PANEL_MARGIN * 2.0), content_height))
	var panel_position := Vector2(
		maxf(PANEL_MARGIN, (parent_size.x - panel_width) * 0.5),
		PANEL_MARGIN
	)
	return Rect2(panel_position, Vector2(panel_width, panel_height))


func _build() -> void:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 10)
	root.add_child(header)

	_portrait_frame = Control.new()
	_portrait_frame.custom_minimum_size = DETAIL_PORTRAIT_SIZE
	_portrait_frame.clip_contents = true
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_portrait_frame)

	_portrait_rect = TextureRect.new()
	_portrait_rect.custom_minimum_size = DETAIL_PORTRAIT_SIZE
	_portrait_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_portrait_frame.add_child(_portrait_rect)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_box.add_theme_constant_override("separation", 3)
	header.add_child(title_box)

	_name_label = _make_label("", NAME_FONT_SIZE, TEXT_PRIMARY)
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.clip_text = true
	title_box.add_child(_name_label)

	_role_label = _make_label("", ROLE_FONT_SIZE, TEXT_MUTED)
	_role_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_role_label.clip_text = true
	title_box.add_child(_role_label)

	var gear_row := HBoxContainer.new()
	gear_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_row.add_theme_constant_override("separation", 6)
	root.add_child(gear_row)

	var gear_label := _make_label("GEAR", GEAR_FONT_SIZE, TEXT_MUTED)
	gear_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gear_row.add_child(gear_label)

	_gear_items = HBoxContainer.new()
	_gear_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gear_items.add_theme_constant_override("separation", 5)
	gear_row.add_child(_gear_items)

	root.add_child(_divider())

	_tiers_box = VBoxContainer.new()
	_tiers_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tiers_box.add_theme_constant_override("separation", 6)
	root.add_child(_tiers_box)

	var hint := _make_label("Tap anywhere to close", HINT_FONT_SIZE, TEXT_VERY_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hint)


func _populate(data: Resource, gear_rows: Array) -> void:
	_portrait_rect.texture = data.get("portrait") as Texture2D
	_name_label.text = _resource_text(data, "display_name", "UNKNOWN UNIT")
	_role_label.text = _role_text(data)
	_populate_gear(gear_rows)
	_populate_tiers(data)
	_layout_portrait()


func _layout_portrait() -> void:
	if _portrait_rect == null or _portrait_frame == null:
		return
	var frame_size: Vector2 = _portrait_frame.size
	if frame_size.x <= 0.0 or frame_size.y <= 0.0:
		frame_size = DETAIL_PORTRAIT_SIZE
	var aspect_ratio := 1.0
	if _portrait_rect.texture != null and _portrait_rect.texture.get_width() > 0:
		aspect_ratio = float(_portrait_rect.texture.get_height()) / float(_portrait_rect.texture.get_width())
	var display_height: float = maxf(frame_size.y, frame_size.x * aspect_ratio)
	_portrait_rect.position = Vector2(0.0, _portrait_y_offset())
	_portrait_rect.size = Vector2(frame_size.x, display_height)


func _portrait_y_offset() -> float:
	if _current_data is EnemyData and str((_current_data as EnemyData).faction) == "stellarMenagerie":
		return MENAGERIE_PORTRAIT_Y_OFFSET
	return 0.0


func _populate_gear(gear_rows: Array) -> void:
	_clear_children(_gear_items)
	if gear_rows.is_empty():
		_gear_items.add_child(_make_label("No gear equipped", GEAR_FONT_SIZE, TEXT_MUTED))
		return
	for row_variant in gear_rows:
		var row: Dictionary = row_variant
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_PASS
		chip.add_theme_stylebox_override("panel", _style(Color("#151b25"), Color("#31445f"), 1, 5))
		var label := _make_label(str(row.get("name", "Gear")), GEAR_FONT_SIZE, TEXT_PRIMARY)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(label)
		var tooltip_text := _gear_tooltip_text(row)
		if _tooltip_cb.is_valid() and not tooltip_text.is_empty():
			_tooltip_cb.call(chip, tooltip_text)
		_gear_items.add_child(chip)


func _populate_tiers(data: Resource) -> void:
	_clear_children(_tiers_box)
	var ranges: Array = []
	var source: Variant = data.get("dice_ranges")
	if source is Array:
		ranges = (source as Array).duplicate(true)
	ranges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("min", 0)) < int(b.get("min", 0))
	)
	for i in range(ranges.size()):
		var entry: Dictionary = ranges[i]
		_tiers_box.add_child(_tier_row(entry, data is EnemyData))
		if i < ranges.size() - 1:
			_tiers_box.add_child(_divider(Color("#1b2635")))


func _tier_row(entry: Dictionary, is_enemy: bool) -> Control:
	var row := VBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 5)

	var range_text := "%d-%d" % [int(entry.get("min", 0)), int(entry.get("max", 0))]
	var ability_text := "%s (%s)" % [str(entry.get("ability_name", "Ability")), range_text]
	var ability_label := _make_label(ability_text, TIER_FONT_SIZE, TEXT_PRIMARY)
	ability_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ability_label.clip_text = true
	ability_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(ability_label)

	var description := str(entry.get("description", "")).strip_edges()
	if not description.is_empty():
		var desc_label := _make_label(description, DESCRIPTION_FONT_SIZE, TEXT_MUTED, true)
		desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc_label)
	return row


func _role_text(data: Resource) -> String:
	if data is UnitData:
		var role := _resource_text(data, "role", "")
		var class_name_text := _resource_text(data, "class_name_text", "")
		if not role.is_empty() and not class_name_text.is_empty():
			return "%s / %s" % [role, class_name_text]
		if not class_name_text.is_empty():
			return class_name_text
		return role
	if data is EnemyData:
		var faction := _resource_text(data, "faction", "")
		var enemy_type := _resource_text(data, "enemy_type", "")
		if not faction.is_empty() and not enemy_type.is_empty():
			return "%s / %s" % [faction, enemy_type]
		if not enemy_type.is_empty():
			return enemy_type
		return faction
	return ""


func _resource_text(data: Resource, key: String, fallback: String) -> String:
	var value: Variant = data.get(key)
	if value == null:
		return fallback
	return str(value)


func _gear_tooltip_text(row: Dictionary) -> String:
	var name := str(row.get("name", "Gear")).strip_edges()
	var description := str(row.get("description", "")).strip_edges()
	if name.is_empty():
		return description
	if description.is_empty():
		return name
	return "%s\n%s" % [name, description]


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			hide_panel()
			accept_event()
	elif event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		if touch_event.pressed:
			hide_panel()
			accept_event()


func _clear_children(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _make_label(text: String, font_size: int, color: Color, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return label


func _divider(color: Color = Color("#2a3a52")) -> ColorRect:
	var line := ColorRect.new()
	line.color = color
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line


func _style(bg: Color, border: Color, border_width: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
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
