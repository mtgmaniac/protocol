extends RefCounted

## Placement and dimensions only; the battle still creates/binds every component.
var _scene: Control
const STYLE := preload("res://scripts/battle/landscape_battle_style.gd").VALUES


func setup(scene: Control) -> void:
	_scene = scene
	var header: Node = scene.get_node("/root/PersistentHeader")
	header.set_battle_landscape(true)
	scene.tree_exiting.connect(func() -> void: header.set_battle_landscape(false))
	_scene.board.vertical = false
	_scene.board.add_theme_constant_override("separation", STYLE.column_gap)
	_scene.hero_cards.vertical = true
	_scene.enemy_cards.vertical = true
	for row in [_scene.hero_readouts, _scene.enemy_readouts, _scene.hero_dice_row, _scene.enemy_dice_row]:
		# The alpha-zero AbilityReadout remains the shared result data holder.
		row.hide()
	for row in [_scene.hero_cards, _scene.enemy_cards]:
		row.custom_minimum_size = Vector2.ZERO
		row.add_theme_constant_override("separation", STYLE.card_gap)
	for panel in [_scene.hero_panel, _scene.enemy_panel]:
		panel.size_flags_horizontal = Control.SIZE_FILL
		panel.custom_minimum_size = Vector2.ZERO
	_scene.center_panel.custom_minimum_size = Vector2.ZERO
	_scene.center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scene.center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scene.dice_tray_3d.result_anchor_provider = _scene._layout.get_dice_anchor_point


func refresh() -> void:
	var content: Control = _scene.get_node("Content")
	content.offset_top = _scene.get_node("/root/PersistentHeader").band_height() + STYLE.content_top_gap
	content.offset_bottom = -(STYLE.footer_height + float(PixelUI.safe_bottom))
	var height: float = maxf(_scene.board.size.y - STYLE.board_height_padding, 1.0)
	var count: int = maxi(3, maxi(_scene.hero_card_views.size(), _scene.enemy_card_views.size()))
	# Ratio-derived dimensions are whole physical pixels, including web stretch.
	var pixel_scale: Vector2 = PixelUI.physical_transform(_scene.board).get_scale()
	var card_h: float = floorf((height - STYLE.card_gap * float(count - 1)) / float(count) * pixel_scale.y) / pixel_scale.y
	var card_w: float = floorf(minf(card_h * STYLE.card_aspect, _scene.board.size.x * STYLE.card_width_fraction) * pixel_scale.x) / pixel_scale.x
	var card_size := Vector2(card_w, card_h)
	for panel in [_scene.hero_panel, _scene.enemy_panel]:
		panel.custom_minimum_size = Vector2(card_w + STYLE.column_padding, 0.0)
	for view in _scene.hero_card_views + _scene.enemy_card_views:
		var card: CompactUnitCard = view.card
		card.apply_battle_presentation(STYLE.card_text_scale)
		card.apply_battle_layout(card_size)
		card.apply_horizontal_battle_plate()
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	var footer_top: float = _scene.size.y - STYLE.footer_height - float(PixelUI.safe_bottom)
	_scene.protocol_panel.offset_top = footer_top - _scene.size.y
	var divider: Control = _scene.get_node_or_null("FooterDivider")
	if divider != null:
		divider.offset_top = footer_top - STYLE.footer_divider_height
		divider.offset_bottom = footer_top
	# The shared Roll/End Turn button has its own footer band: an uneven
	# 3v2 encounter leaves no common vertical gap between enlarged dice.
	var action_wrap: Control = _scene.roll_button.get_parent()
	action_wrap.set_as_top_level(true)
	action_wrap.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	action_wrap.global_position = Vector2(0.0, footer_top)
	action_wrap.size = Vector2(_scene.size.x, STYLE.action_band_height)
	refresh_chrome()


func refresh_chrome() -> void:
	_scene.protocol_label.add_theme_font_size_override("font_size", STYLE.protocol_font)
	var stack: Control = _scene.protocol_label.get_parent()
	if stack.name == "ProtocolStack":
		stack.custom_minimum_size.y = STYLE.protocol_stack_height
		_scene.protocol_label.offset_left = 0.0
		_scene.protocol_label.offset_right = 0.0
		_scene.protocol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_scene.protocol_label.offset_top = STYLE.protocol_label_top
		_scene.protocol_label.offset_bottom = STYLE.protocol_label_bottom
		_scene.protocol_bar.offset_top = -STYLE.protocol_bar_height
		var row: HBoxContainer = stack.get_parent()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.size_flags_vertical = Control.SIZE_SHRINK_END
		var spacer: Control = row.get_node_or_null("ProtocolFooterSpacer")
		if spacer != null:
			spacer.hide()
		# Two actions on either side keep the bar itself centered, not only
		# the combined group. Reuse the existing buttons and signal bindings.
		var actions: Array = []
		for child in row.get_children():
			if child is Button:
				actions.append(child)
		if actions.size() == 4:
			row.move_child(actions[0], 0)
			row.move_child(actions[1], 1)
			row.move_child(stack, 2)
		row.add_theme_constant_override("separation", STYLE.protocol_group_gap)
		stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var buttons_w: float = 0.0
		for child in row.get_children():
			if child is Button and child.visible:
				buttons_w += child.custom_minimum_size.x + STYLE.protocol_group_gap
		var tray_w: float = _scene._layout.get_combat_zone_rect().size.x
		stack.custom_minimum_size.x = PixelUI.snap_to_physical_px(stack, minf(STYLE.protocol_bar_max_width, minf(tray_w, _scene.size.x * STYLE.protocol_group_fraction - buttons_w)))


func dice_anchor(side: String, state_id: String, zone: Rect2) -> Vector2:
	var views: Array = _scene.hero_card_views if side == "hero" else _scene.enemy_card_views
	for view in views:
		if str(view.state.id) == state_id:
			var card: Control = view.card
			# Match the owning card's vertical center and bring both dice lanes
			# inward. Roll/End Turn occupies the separate footer band.
			var lane_offset: float = _scene.dice_tray_3d.settled_die_half_height_px() + STYLE.dice_center_gap * 0.5
			var x: float = zone.size.x * 0.5 + lane_offset * (-1.0 if side == "hero" else 1.0)
			var y: float = card.get_global_rect().get_center().y - zone.position.y
			return Vector2(PixelUI.snap_to_physical_px(_scene.dice_tray_3d, x), PixelUI.snap_to_physical_px(_scene.dice_tray_3d, y, 1))
	return Vector2.INF


func refresh_hit_areas() -> void:
	# Keep the existing LongPressInput and callbacks; only their geometry moves.
	for overlay in _scene._die_tooltip_overlays:
		if not is_instance_valid(overlay):
			continue
		var identity: Array = overlay.get_meta("layout_die", [])
		if identity.size() != 2:
			continue
		var rect: Rect2 = _scene.dice_tray_3d.get_die_screen_bounds(identity[0], identity[1])
		if rect.position == Vector2.INF:
			continue
		var tag: Control = _scene.get_die_tag_plate(identity[0], identity[1])
		if tag != null:
			rect = rect.merge(tag.get_global_rect())
		overlay.custom_minimum_size = Vector2.ZERO
		overlay.global_position = rect.position
		overlay.size = rect.size


func position_tag(plate: Control, side: String, bounds: Rect2) -> void:
	var at := Vector2(bounds.position.x - STYLE.tag_side_gap - plate.size.x if side == "hero" else bounds.end.x + STYLE.tag_side_gap, bounds.get_center().y - plate.size.y * 0.5)
	plate.global_position = Vector2(PixelUI.snap_to_physical_px(_scene, at.x), PixelUI.snap_to_physical_px(_scene, at.y, 1))
