class_name BattleLayout
extends Node

const DICE_SNAP_HORIZONTAL_MARGIN_PX := 88.0
const DICE_VISUAL_HALF_HEIGHT_PX := 80.0
const DICE_BUTTON_GAP_PX := 54.0
const DICE_LANE_HEIGHT_PX := 168.0
const COMPACT_DICE_ANCHOR_HEIGHT_PX := 56.0
const COMPACT_READOUT_HEIGHT_PX := 148.0
const COMPACT_CARD_WIDTH_PX := 344.0
const COMPACT_CARD_HEIGHT_PX := 570.0
# V2 band geometry (portrait). Header/footer are a fixed 144 each (touch targets,
# owned by the .tscn anchors). Center is fixed; the two rails are the FLEX bands:
# they share all leftover height equally via EXPAND, which is what lets the same
# code adapt across phone aspect ratios (stretch aspect = expand).
# CARD_ZONE_HEIGHT is only a floor — actual rail height grows to fill the device.
# NOTE: center is 540, not the spec's 432 — 432 shrinks the 3D dice tray enough
# to clip the readout pips into the dice. 540 is the readable value.
const CARD_ZONE_HEIGHT := 768.0
const CENTER_ZONE_HEIGHT := 540.0
const RAIL_ROW_GAP_PX := 1.0
const RAIL_SLOT_GAP_PX := 2.0

var _scene: Control

var _combat_zone_frame: PanelContainer = null
var _combat_zone_enemy_lane: HBoxContainer = null
var _combat_zone_hero_lane: HBoxContainer = null
var _combat_zone_enemy_slots: Array = []
var _combat_zone_hero_slots: Array = []


func setup(scene: Control) -> void:
	_scene = scene
	_scene.resized.connect(queue_board_layout_refresh)


func get_dice_anchor_point(side: String, state_id: String) -> Vector2:
	if _scene.dice_tray_3d == null:
		return Vector2.INF
	var views: Array = _scene.hero_card_views if side == "hero" else _scene.enemy_card_views
	var combat_zone: Rect2 = get_combat_zone_rect()
	if combat_zone.size.x <= 2.0 or combat_zone.size.y <= 2.0:
		return Vector2.INF
	var lane: HBoxContainer = _combat_zone_hero_lane if side == "hero" else _combat_zone_enemy_lane
	if lane == null or not is_instance_valid(lane) or not lane.is_inside_tree():
		return Vector2.INF
	var lane_rect: Rect2 = lane.get_global_rect()
	if lane_rect.size.x <= 2.0 or lane_rect.size.y <= 2.0:
		return Vector2.INF
	for index in range(views.size()):
		var view: Dictionary = views[index]
		var state: Dictionary = view.get("state", {})
		if str(state.get("id", "")) != state_id:
			continue
		var card: Control = view.get("card", null) as Control
		if card == null or not is_instance_valid(card) or not card.is_inside_tree():
			return Vector2.INF
		var card_rect: Rect2 = card.get_global_rect()
		var x: float = clampf(card_rect.get_center().x, combat_zone.position.x + DICE_SNAP_HORIZONTAL_MARGIN_PX, combat_zone.end.x - DICE_SNAP_HORIZONTAL_MARGIN_PX)
		var y: float = lane_rect.get_center().y
		return Vector2(x, y) - combat_zone.position
	return Vector2.INF


func get_dice_anchor_side_offset(_side: String, _state_id: String) -> float:
	return 0.0


func get_enemy_result_row_rect() -> Rect2:
	return get_result_row_rect(_scene.enemy_card_views)


func get_friendly_result_row_rect() -> Rect2:
	return get_result_row_rect(_scene.hero_card_views)


func get_result_row_rect(views: Array) -> Rect2:
	var rect := Rect2()
	var has_rect := false
	for view_variant in views:
		var view: Dictionary = view_variant
		var readout: Control = view.get("readout", null) as Control
		if readout == null or not is_instance_valid(readout) or not readout.is_inside_tree():
			continue
		var readout_rect: Rect2 = readout.get_global_rect()
		if readout_rect.size.x <= 2.0 or readout_rect.size.y <= 2.0:
			continue
		if has_rect:
			rect = rect.merge(readout_rect)
		else:
			rect = readout_rect
			has_rect = true
	return rect if has_rect else Rect2()


# Direction-05: a small gutter on every side so the dice tray never touches the
# card rows. Applied to EVERY return path (some are degenerate-case fallbacks that
# previously returned full width, which reset the gap).
const TRAY_GUTTER_H := 12.0
const TRAY_GUTTER_V := 14.0


func _inset_tray_rect(r: Rect2) -> Rect2:
	if r.size.x <= 2.0 or r.size.y <= 2.0:
		return r
	return Rect2(
		r.position + Vector2(TRAY_GUTTER_H, TRAY_GUTTER_V),
		Vector2(maxf(r.size.x - TRAY_GUTTER_H * 2.0, 2.0), maxf(r.size.y - TRAY_GUTTER_V * 2.0, 2.0))
	)


func get_combat_zone_rect() -> Rect2:
	if _scene.dice_tray_3d == null:
		return Rect2()
	var enemy_readout_rect: Rect2 = get_enemy_result_row_rect()
	var enemy_card_rect: Rect2 = get_card_group_rect(_scene.enemy_card_views)
	var friendly_readout_rect: Rect2 = get_friendly_result_row_rect()
	var friendly_card_rect: Rect2 = get_card_group_rect(_scene.hero_card_views)
	if enemy_readout_rect.size == Vector2.ZERO or friendly_readout_rect.size == Vector2.ZERO:
		return _inset_tray_rect(_scene.center_panel.get_global_rect())

	var board_rect: Rect2 = _scene.board.get_global_rect()
	var center_rect: Rect2 = _scene.center_panel.get_global_rect()
	var enemy_bottom_y: float = enemy_card_rect.end.y if enemy_card_rect.size != Vector2.ZERO else enemy_readout_rect.end.y
	var friendly_top_y: float = friendly_card_rect.position.y if friendly_card_rect.size != Vector2.ZERO else friendly_readout_rect.position.y
	var top_y: float = enemy_readout_rect.position.y if enemy_readout_rect.size != Vector2.ZERO else enemy_bottom_y
	var bottom_y: float = friendly_readout_rect.end.y if friendly_readout_rect.size != Vector2.ZERO else friendly_top_y
	if bottom_y <= top_y + 120.0:
		return _inset_tray_rect(center_rect)

	var x: float = center_rect.position.x
	var width: float = center_rect.size.x
	if width <= 2.0:
		x = board_rect.position.x
		width = board_rect.size.x
	return _inset_tray_rect(Rect2(Vector2(x, top_y), Vector2(width, bottom_y - top_y)))


func layout_dice_from_combat_zone() -> void:
	if _scene.dice_tray_3d == null:
		return
	var combat_zone: Rect2 = get_combat_zone_rect()
	sync_combat_zone_frame(combat_zone)
	if combat_zone.size.x <= 2.0 or combat_zone.size.y <= 2.0:
		return
	_scene.dice_tray_3d.set_combat_zone_rect(combat_zone)


func get_card_group_rect(views: Array) -> Rect2:
	var rect := Rect2()
	var has_rect := false
	for view_variant in views:
		var view: Dictionary = view_variant
		var card: Control = view.get("card", null) as Control
		if card == null or not is_instance_valid(card) or not card.is_inside_tree():
			continue
		var card_rect: Rect2 = card.get_global_rect()
		if card_rect.size.x <= 2.0 or card_rect.size.y <= 2.0:
			continue
		if has_rect:
			rect = rect.merge(card_rect)
		else:
			rect = card_rect
			has_rect = true
	return rect if has_rect else Rect2()


func queue_board_layout_refresh() -> void:
	call_deferred("refresh_board_layout")
	call_deferred("layout_dice_from_combat_zone")


func refresh_board_layout() -> void:
	if not _scene.is_inside_tree():
		return
	if _scene.hero_scroll == null or _scene.enemy_scroll == null:
		return
	_scene.center_panel.custom_minimum_size = Vector2(0, CENTER_ZONE_HEIGHT)
	_scene.hero_panel.custom_minimum_size = Vector2(0, CARD_ZONE_HEIGHT)
	_scene.enemy_panel.custom_minimum_size = Vector2(0, CARD_ZONE_HEIGHT)
	_scene.hero_scroll.add_theme_constant_override("separation", RAIL_ROW_GAP_PX)
	_scene.enemy_scroll.add_theme_constant_override("separation", RAIL_ROW_GAP_PX)
	_scene.hero_cards.add_theme_constant_override("separation", RAIL_SLOT_GAP_PX)
	_scene.hero_readouts.add_theme_constant_override("separation", RAIL_SLOT_GAP_PX)
	_scene.hero_dice_row.add_theme_constant_override("separation", RAIL_SLOT_GAP_PX)
	_scene.enemy_cards.add_theme_constant_override("separation", RAIL_SLOT_GAP_PX)
	_scene.enemy_readouts.add_theme_constant_override("separation", RAIL_SLOT_GAP_PX)
	_scene.enemy_dice_row.add_theme_constant_override("separation", RAIL_SLOT_GAP_PX)

	apply_rail_layout(_scene.hero_card_views, _scene.hero_cards, _scene.hero_readouts, _scene.hero_dice_row)
	apply_rail_layout(_scene.enemy_card_views, _scene.enemy_cards, _scene.enemy_readouts, _scene.enemy_dice_row)
	apply_dice_anchor_height(COMPACT_DICE_ANCHOR_HEIGHT_PX)
	call_deferred("layout_dice_from_combat_zone")


func apply_rail_layout(views: Array, cards_row: HBoxContainer, readouts_row: HBoxContainer, dice_row: HBoxContainer) -> void:
	var slot_width: float = get_logical_slot_width(cards_row)
	var card_size := Vector2(minf(slot_width, COMPACT_CARD_WIDTH_PX), COMPACT_CARD_HEIGHT_PX)
	for view_variant in views:
		var view: Dictionary = view_variant
		var card: Control = view.get("card", null) as Control
		var readout: Control = view.get("readout", null) as Control
		var anchor: Control = view.get("dice_anchor", null) as Control
		if card != null:
			card.custom_minimum_size = card_size
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			if card is CompactUnitCard:
				(card as CompactUnitCard).apply_battle_layout(card_size)
		if readout != null:
			readout.custom_minimum_size = Vector2(slot_width, COMPACT_READOUT_HEIGHT_PX)
			readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			readout.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		if anchor != null:
			anchor.custom_minimum_size = Vector2(slot_width, COMPACT_DICE_ANCHOR_HEIGHT_PX)
			anchor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			anchor.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func get_logical_slot_width(row: HBoxContainer) -> float:
	var gap: float = float(row.get_theme_constant("separation"))
	var available_width: float = maxf(row.size.x, 320.0)
	var slot_count: int = maxi(row.get_child_count(), 1)
	return clampf(
		floor((available_width - (gap * float(slot_count - 1))) / float(slot_count)),
		96.0,
		COMPACT_CARD_WIDTH_PX
	)


func apply_dice_anchor_height(anchor_height: float) -> void:
	for view_variant in _scene.hero_card_views + _scene.enemy_card_views:
		var view: Dictionary = view_variant
		var anchor: Control = view.get("dice_anchor", null) as Control
		if anchor == null or not is_instance_valid(anchor):
			continue
		anchor.custom_minimum_size = Vector2(0, anchor_height)


func stabilize_board_layout() -> void:
	for i in range(4):
		if not _scene.is_inside_tree():
			return
		refresh_board_layout()
		layout_dice_from_combat_zone()
		await get_tree().process_frame
	_scene._card_view.refresh_all_cards()


func ensure_combat_zone_frame() -> void:
	if _scene.float_layer == null:
		return
	if _combat_zone_frame == null or not is_instance_valid(_combat_zone_frame):
		_combat_zone_frame = PanelContainer.new()
		_combat_zone_frame.name = "CombatZoneFrame"
		_combat_zone_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_combat_zone_frame.set_as_top_level(true)
		_combat_zone_frame.z_as_relative = false
		_combat_zone_frame.z_index = 4
		_scene.float_layer.add_child(_combat_zone_frame)
	if _combat_zone_enemy_lane == null or not is_instance_valid(_combat_zone_enemy_lane):
		_combat_zone_enemy_lane = _build_combat_zone_lane("EnemyDiceLane")
		_combat_zone_frame.add_child(_combat_zone_enemy_lane)
		_combat_zone_enemy_slots = _build_combat_zone_lane_slots(_combat_zone_enemy_lane)
	if _combat_zone_hero_lane == null or not is_instance_valid(_combat_zone_hero_lane):
		_combat_zone_hero_lane = _build_combat_zone_lane("HeroDiceLane")
		_combat_zone_frame.add_child(_combat_zone_hero_lane)
		_combat_zone_hero_slots = _build_combat_zone_lane_slots(_combat_zone_hero_lane)
	# Direction-05 tray: the frame is an OVERLAY above the dice viewport, so its fill
	# must be fully transparent (any tint darkens the dice). Border + corner ticks only.
	PixelUI.style_panel(_combat_zone_frame, Color(0, 0, 0, 0), PixelUI.LINE_DIM, 3, 0)
	_ensure_tray_corner_ticks()


# Direction-05 tray detail: four L-shaped corner ticks (hard, no blur) pinned to
# the combat-zone frame corners.
func _ensure_tray_corner_ticks() -> void:
	if _combat_zone_frame == null or not is_instance_valid(_combat_zone_frame):
		return
	if _combat_zone_frame.get_node_or_null("CornerTicks") != null:
		return
	var ticks: Control = Control.new()
	ticks.name = "CornerTicks"
	ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ticks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_combat_zone_frame.add_child(ticks)
	var tick_color: Color = Color("2a333a")
	var arm: float = 20.0
	var thick: float = 4.0
	var inset: float = 6.0
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var cx: float = corner.x
		var cy: float = corner.y
		# horizontal arm
		var h: ColorRect = ColorRect.new()
		h.color = tick_color
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.anchor_left = cx
		h.anchor_right = cx
		h.anchor_top = cy
		h.anchor_bottom = cy
		h.offset_left = inset if cx == 0 else -(inset + arm)
		h.offset_right = (inset + arm) if cx == 0 else -inset
		h.offset_top = inset if cy == 0 else -(inset + thick)
		h.offset_bottom = (inset + thick) if cy == 0 else -inset
		ticks.add_child(h)
		# vertical arm
		var v: ColorRect = ColorRect.new()
		v.color = tick_color
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.anchor_left = cx
		v.anchor_right = cx
		v.anchor_top = cy
		v.anchor_bottom = cy
		v.offset_left = inset if cx == 0 else -(inset + thick)
		v.offset_right = (inset + thick) if cx == 0 else -inset
		v.offset_top = inset if cy == 0 else -(inset + arm)
		v.offset_bottom = (inset + arm) if cy == 0 else -inset
		ticks.add_child(v)


func _build_combat_zone_lane(lane_name: String) -> HBoxContainer:
	var lane := HBoxContainer.new()
	lane.name = lane_name
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lane.alignment = BoxContainer.ALIGNMENT_CENTER
	lane.add_theme_constant_override("separation", RAIL_SLOT_GAP_PX)
	return lane


func _build_combat_zone_lane_slots(lane: HBoxContainer) -> Array:
	var slots: Array = []
	for index in range(3):
		var slot := CenterContainer.new()
		slot.name = "LaneSlot%d" % index
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lane.add_child(slot)
		slots.append(slot)
	return slots


func sync_combat_zone_frame(combat_zone: Rect2) -> void:
	if _combat_zone_frame == null or not is_instance_valid(_combat_zone_frame):
		return
	if combat_zone.size.x <= 2.0 or combat_zone.size.y <= 2.0:
		_combat_zone_frame.visible = false
		return
	_combat_zone_frame.visible = true
	_combat_zone_frame.global_position = combat_zone.position
	_combat_zone_frame.size = combat_zone.size
	var enemy_readout_rect: Rect2 = get_enemy_result_row_rect()
	var hero_readout_rect: Rect2 = get_friendly_result_row_rect()
	var button_rect: Rect2 = _scene.roll_button.get_global_rect() if _scene.roll_button != null and is_instance_valid(_scene.roll_button) else Rect2()
	var lane_gap: float = 10.0
	var button_center_local: float = button_rect.get_center().y - combat_zone.position.y if button_rect.size.y > 2.0 else combat_zone.size.y * 0.5
	var enemy_readout_bottom: float = enemy_readout_rect.end.y - combat_zone.position.y if enemy_readout_rect.size.y > 2.0 else 0.0
	var hero_readout_top: float = hero_readout_rect.position.y - combat_zone.position.y if hero_readout_rect.size.y > 2.0 else combat_zone.size.y
	var top_bound: float = enemy_readout_bottom + lane_gap
	var bottom_bound: float = hero_readout_top - lane_gap
	var lane_height: float = DICE_LANE_HEIGHT_PX
	var max_symmetric_offset: float = maxf(0.0, minf(button_center_local - top_bound - DICE_VISUAL_HALF_HEIGHT_PX, bottom_bound - button_center_local - DICE_VISUAL_HALF_HEIGHT_PX))
	# Button reservation shifts dice outward when the Roll/End Turn button is visible;
	# when the button is hidden (targeting phase, item picks) dice compress to center.
	var button_reservation: float = button_rect.size.y * 0.5 if button_rect.size.y > 2.0 else 0.0
	var required_center_offset: float = button_reservation + DICE_VISUAL_HALF_HEIGHT_PX + DICE_BUTTON_GAP_PX
	var center_offset: float = minf(required_center_offset, max_symmetric_offset)
	var enemy_lane_y: float = button_center_local - center_offset - lane_height * 0.5
	var hero_lane_y: float = button_center_local + center_offset - lane_height * 0.5
	var enemy_lane_height: float = lane_height if max_symmetric_offset > 0.0 else 0.0
	var hero_lane_height: float = lane_height if max_symmetric_offset > 0.0 else 0.0
	if _combat_zone_enemy_lane != null and is_instance_valid(_combat_zone_enemy_lane):
		_combat_zone_enemy_lane.position = Vector2.ZERO if enemy_lane_height <= 0.0 else Vector2(0.0, enemy_lane_y)
		_combat_zone_enemy_lane.size = Vector2(combat_zone.size.x, enemy_lane_height)
		_combat_zone_enemy_lane.visible = enemy_lane_height > 0.0
	if _combat_zone_hero_lane != null and is_instance_valid(_combat_zone_hero_lane):
		_combat_zone_hero_lane.position = Vector2.ZERO if hero_lane_height <= 0.0 else Vector2(0.0, hero_lane_y)
		_combat_zone_hero_lane.size = Vector2(combat_zone.size.x, hero_lane_height)
		_combat_zone_hero_lane.visible = hero_lane_height > 0.0


func build_row_slots(row: HBoxContainer, count: int) -> Array:
	var slots: Array = []
	row.add_theme_constant_override("separation", RAIL_SLOT_GAP_PX)
	var slot_count: int = maxi(count, 1)
	for index in range(slot_count):
		var slot := CenterContainer.new()
		slot.name = "Slot%d" % index
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_child(slot)
		slots.append(slot)
	return slots


func build_dice_anchor() -> Control:
	var anchor: Control = Control.new()
	anchor.name = "DiceAnchor"
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.custom_minimum_size = Vector2(0, COMPACT_DICE_ANCHOR_HEIGHT_PX)
	anchor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	anchor.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return anchor


func prepare_battle_card_layout(card: Control) -> void:
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.custom_minimum_size = Vector2(0, 0)


func prepare_ability_readout_layout(readout: Control) -> void:
	readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	readout.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	readout.custom_minimum_size = Vector2(0, COMPACT_READOUT_HEIGHT_PX)
