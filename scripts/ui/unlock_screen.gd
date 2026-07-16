# Unlock screen (Build F) — the ONE run-end unlock announcement, victory or
# failure: battle result -> run summary -> THIS (only if something unlocked)
# -> home. Boss relics (event-gated) and item-gate buckets (battle-count,
# evaluated at run end only) land here together with hero/operation awards.
# Transmission-window chrome; sections biggest news first; items/relics render
# as a 4-across icon grid (reveal, not a decision — no reward-row anatomy);
# the screen SCROLLS on fat runs (icons never shrink); one CONTINUE.
# Skipped entirely when nothing unlocked — never an empty ceremony.
extends Control

const TITLE_FONT := 108
const SECTION_HEAD_FONT := 48
const NAME_FONT := 56
const GRID_NAME_FONT := 40
const BUTTON_FONT := 56
const BUTTON_SIZE := Vector2(360, 120)
const GRID_COLUMNS := 4
const GRID_ICON_BOX := 128.0
const BOSS_RELIC_ICON_BOX := 256.0

# Section order is the ruling: biggest news first.
const SECTION_ORDER := ["boss_relic", "hero", "operation", "relic", "item"]
const SECTION_LABELS := {
	"boss_relic": "BOSS RELIC",
	"hero": "NEW UNIT",
	"operation": "NEW OPERATION",
	"relic": "NEW RELICS",
	"item": "NEW ITEMS",
}

@onready var background: ColorRect = $Background
@onready var title_label: Label = %TitleLabel
@onready var window_panel: PanelContainer = %WindowPanel
@onready var sections: VBoxContainer = %Sections
@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	# Safe area (device cutout / gesture bar): drop below the grown header band
	# and lift the bottom button clear. Both insets are 0 on desktop.
	var content: MarginContainer = $Content
	content.offset_top += float(PixelUI.safe_top)
	content.offset_bottom -= float(PixelUI.safe_bottom)
	PersistentHeader.set_run_active(false)
	PersistentHeader.clear_battle_actions()

	var unlocks: Array = SaveManager.check_new_unlocks()
	if unlocks.is_empty():
		# Never an empty ceremony (run_end already routes around us; this is the
		# structural guard for a direct entry).
		call_deferred("_go_home")
		return

	_apply_visual_theme()
	_build_sections(unlocks)


func _apply_visual_theme() -> void:
	background.color = PixelUI.DT_FIELD_BG
	PixelUI.add_terminal_backdrop(self)
	move_child($Content, get_child_count() - 1)
	# Unlock accent is AMBER (visual identity: amber = unlock accents; gold is
	# reserved for the major-event tier below).
	_style_label(title_label, TITLE_FONT, PixelUI.DT_AMBER)
	# Transmission window: full-screen event chrome (the documented
	# none-of-the-six exception, same as intercept / route fork / run-end).
	PixelUI.style_transmission_panel(window_panel)
	continue_button.custom_minimum_size = BUTTON_SIZE
	PixelUI.style_primary_button(continue_button, BUTTON_FONT)


# ── Sections ──────────────────────────────────────────────────────────────────

func _build_sections(unlocks: Array) -> void:
	var grouped: Dictionary = {}
	for entry_variant in unlocks:
		var entry: Dictionary = entry_variant as Dictionary
		var kind: String = _section_kind(str(entry.get("type", "")))
		if kind == "":
			continue
		if not grouped.has(kind):
			grouped[kind] = []
		(grouped[kind] as Array).append(entry)

	for kind in SECTION_ORDER:
		if not grouped.has(kind):
			continue
		# Filled header strip (Build A component vocabulary, INVARIANTS #7) —
		# section titles rank as headers, not body text; no new frame styles.
		var head_strip := PanelContainer.new()
		head_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var strip_style: StyleBoxFlat = PixelUI.component_header_style(PixelUI.COMPONENT_REWARD)
		strip_style.set_content_margin(SIDE_TOP, 8.0)
		strip_style.set_content_margin(SIDE_BOTTOM, 8.0)
		head_strip.add_theme_stylebox_override("panel", strip_style)
		var head := Label.new()
		head.text = str(SECTION_LABELS[kind])
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.set_meta("unlock_section", kind)
		_style_label(head, SECTION_HEAD_FONT, PixelUI.DT_AMBER)
		head_strip.add_child(head)
		sections.add_child(head_strip)
		match kind:
			"boss_relic":
				for entry in grouped[kind]:
					sections.add_child(_make_boss_relic_card(entry))
			"hero":
				for entry in grouped[kind]:
					sections.add_child(_make_hero_row(entry))
			"operation":
				for entry in grouped[kind]:
					sections.add_child(_make_operation_row(entry))
			_:
				sections.add_child(_make_icon_grid(grouped[kind]))


func _section_kind(entry_type: String) -> String:
	match entry_type:
		"boss_relic", "hero", "operation":
			return entry_type
		"relic":
			return "relic"
		"consumable", "gear":
			return "item"
	return ""


# BOSS RELIC: the Major-event (gold) card with the FULL description — the
# ceremonial tier, gold here and only here. This announcement is the point of
# the section: boss relics used to unlock silently.
func _make_boss_relic_card(entry: Dictionary) -> Control:
	var item: ItemData = DataManager.get_item(str(entry.get("id", ""))) as ItemData
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size = Vector2(880, 0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", PixelUI.component_style(PixelUI.COMPONENT_MAJOR))
	var pad := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		pad.add_theme_constant_override(side, 24)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(pad)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(row)
	if item != null and item.icon != null:
		var icon := PixelUI.make_integer_icon(item.icon, BOSS_RELIC_ICON_BOX, PixelUI.GOLD_ACCENT)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 10)
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = str(entry.get("display_name", ""))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(name_label, NAME_FONT, PixelUI.GOLD_ACCENT)
	info.add_child(name_label)
	var tag := Label.new()
	tag.text = "STARTING DIRECTIVE EARNED"
	_style_label(tag, PixelUI.FONT_INFO_MIN, PixelUI.TEXT_MUTED)
	info.add_child(tag)
	if item != null and item.description != "":
		var desc := Label.new()
		desc.text = item.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PixelUI.style_body_label(desc)
		info.add_child(desc)
	# Long-press inspect — every element on this screen opens its description
	# (Build G item 4), same interaction as everywhere else.
	if item != null:
		var long_press := LongPressInput.new()
		card.add_child(long_press)
		long_press.long_pressed.connect(_on_cell_long_pressed.bind(item, card))
	return card


# NEW UNIT: portrait through the ONE portrait window (HERO_PORTRAIT_REGION
# aspect via cover_fit_portrait — same rule as the battle card and squad tiles).
func _make_hero_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var unit := DataManager.get_unit(str(entry.get("id", ""))) as UnitData
	if unit != null and unit.portrait != null:
		var frame := PanelContainer.new()
		var token_w := 144.0
		frame.custom_minimum_size = Vector2(token_w, roundf(token_w * PixelUI.HERO_PORTRAIT_REGION.y / PixelUI.HERO_PORTRAIT_REGION.x))
		frame.clip_contents = true
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_theme_stylebox_override("panel", PixelUI.make_hard_style(PixelUI.DT_HERO_BG, PixelUI.DT_HERO_BORDER, 2))
		var crop := Control.new()
		crop.clip_contents = true
		crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(crop)
		var tex := TextureRect.new()
		tex.texture = unit.portrait
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_SCALE
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crop.add_child(tex)
		crop.resized.connect(func() -> void: PixelUI.cover_fit_portrait(tex, crop.size))
		row.add_child(frame)
	var name_label := Label.new()
	name_label.text = str(entry.get("display_name", ""))
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(name_label, NAME_FONT, PixelUI.DT_AMBER)
	row.add_child(name_label)
	if unit != null:
		var long_press := LongPressInput.new()
		row.add_child(long_press)
		long_press.long_pressed.connect(_on_unit_long_pressed.bind(unit, row))
	return row


# NEW OPERATION (Build G, RULED): the one-time operation popup is retired —
# the operation announces HERE: name (Title Case label) with its one-sentence
# origin line beneath at body tier. Building the row acknowledges the origin
# so the one-time flag stays coherent for legacy surfaces.
func _make_operation_row(entry: Dictionary) -> Control:
	var operation_id: String = str(entry.get("id", ""))
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	column.mouse_filter = Control.MOUSE_FILTER_STOP
	var name_label := Label.new()
	name_label.text = str(entry.get("display_name", ""))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(name_label, NAME_FONT, PixelUI.DT_AMBER)
	column.add_child(name_label)
	var copy: Dictionary = OperationBriefingOverlay.operation_copy(operation_id)
	var origin: String = str(copy.get("origin", ""))
	if origin != "":
		var lore := Label.new()
		lore.text = origin
		lore.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lore.mouse_filter = Control.MOUSE_FILTER_IGNORE
		PixelUI.style_body_label(lore)
		column.add_child(lore)
	if operation_id != "" and not SaveManager.has_seen_operation_origin(operation_id):
		SaveManager.acknowledge_operation_origin(operation_id)
	var long_press := LongPressInput.new()
	column.add_child(long_press)
	long_press.long_pressed.connect(_on_operation_long_pressed.bind(operation_id, column))
	return column


# NEW RELICS / NEW ITEMS: 4-across icon grid, name beneath each, long-press
# for the description (same InspectPopup as everywhere). A reveal, not a
# decision — no reward-row anatomy, and icons NEVER shrink to fit (the screen
# scrolls instead).
func _make_icon_grid(entries: Array) -> Control:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	center.add_child(grid)
	for entry_variant in entries:
		var entry: Dictionary = entry_variant as Dictionary
		grid.add_child(_make_grid_cell(entry))
	return center


func _make_grid_cell(entry: Dictionary) -> Control:
	var item: ItemData = DataManager.get_item(str(entry.get("id", ""))) as ItemData
	var cell := VBoxContainer.new()
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.custom_minimum_size = Vector2(212, 0)
	cell.add_theme_constant_override("separation", 8)
	cell.set_meta("unlock_grid_cell", str(entry.get("id", "")))
	if item != null and item.icon != null:
		# Integer icon law: whole multiples of native only. force_plate: EVERY
		# grid icon rides the emblem plate uniformly (Build G item 5 — a lone
		# low-res plate read as a selection highlight).
		var icon := PixelUI.make_integer_icon(item.icon, GRID_ICON_BOX, PixelUI.DT_AMBER, true)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(icon)
	var name_label := Label.new()
	name_label.text = str(entry.get("display_name", ""))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size = Vector2(200, 0)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(name_label, GRID_NAME_FONT, PixelUI.DT_AMBER)
	cell.add_child(name_label)
	if item != null:
		var long_press := LongPressInput.new()
		cell.add_child(long_press)
		long_press.long_pressed.connect(_on_cell_long_pressed.bind(item, cell))
	return cell


func _on_cell_long_pressed(_global_position: Vector2, item: ItemData, cell: Control) -> void:
	AudioManager.play_select()
	var anchor: Rect2 = cell.get_global_rect() if is_instance_valid(cell) else Rect2()
	InspectPopup.open(self, InspectResolver.resolve_item(item), anchor, cell.get_instance_id())


func _on_unit_long_pressed(_global_position: Vector2, unit: UnitData, row: Control) -> void:
	AudioManager.play_select()
	var anchor: Rect2 = row.get_global_rect() if is_instance_valid(row) else Rect2()
	InspectPopup.open(self, InspectResolver.resolve_unit(unit), anchor, row.get_instance_id())


func _on_operation_long_pressed(_global_position: Vector2, operation_id: String, row: Control) -> void:
	AudioManager.play_select()
	var operation: OperationData = DataManager.get_operation(operation_id) as OperationData
	if operation == null:
		return
	var anchor: Rect2 = row.get_global_rect() if is_instance_valid(row) else Rect2()
	InspectPopup.open(self, InspectResolver.resolve_operation(operation), anchor, row.get_instance_id())


func _on_continue_button_pressed() -> void:
	AudioManager.play_select()
	_go_home()


func _go_home() -> void:
	GameState.reset_run()
	SceneManager.go_to_unit_select()


func _style_label(label: Label, font_size: int, color: Color) -> void:
	PixelUI.apply_pixel_font(label)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.98))
	label.add_theme_constant_override("outline_size", 2)
