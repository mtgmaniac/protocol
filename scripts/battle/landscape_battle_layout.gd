extends RefCounted

## Placement and dimensions only; the battle still creates/binds every component.
var _scene: Control
const COLUMN_GAP := 36
const CARD_GAP := 32
const FOOTER_HEIGHT := 208.0


func setup(scene: Control) -> void:
	_scene = scene
	var header: Node = scene.get_node("/root/PersistentHeader")
	header.set_battle_landscape(true)
	scene.tree_exiting.connect(func() -> void: header.set_battle_landscape(false))
	_scene.board.vertical = false
	_scene.board.add_theme_constant_override("separation", COLUMN_GAP)
	_scene.hero_cards.vertical = true
	_scene.enemy_cards.vertical = true
	for row in [_scene.hero_readouts, _scene.enemy_readouts, _scene.hero_dice_row, _scene.enemy_dice_row]:
		# The alpha-zero AbilityReadout remains the shared result data holder.
		row.hide()
	for row in [_scene.hero_cards, _scene.enemy_cards]:
		row.custom_minimum_size = Vector2.ZERO
		row.add_theme_constant_override("separation", CARD_GAP)
	for panel in [_scene.hero_panel, _scene.enemy_panel]:
		panel.size_flags_horizontal = Control.SIZE_FILL
		panel.custom_minimum_size = Vector2.ZERO
	_scene.center_panel.custom_minimum_size = Vector2.ZERO
	_scene.center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scene.center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scene.dice_tray_3d.result_anchor_provider = _scene._layout.get_dice_anchor_point


func refresh() -> void:
	var content: Control = _scene.get_node("Content")
	content.offset_top = _scene.get_node("/root/PersistentHeader").band_height() + 26.0
	content.offset_bottom = -(FOOTER_HEIGHT + float(PixelUI.safe_bottom))
	var height: float = maxf(_scene.board.size.y - 16.0, 1.0)
	var count: int = maxi(3, maxi(_scene.hero_card_views.size(), _scene.enemy_card_views.size()))
	# Ratio-derived dimensions are whole physical pixels, including web stretch.
	var pixel_scale: Vector2 = PixelUI.physical_transform(_scene.board).get_scale()
	var card_h: float = floorf((height - CARD_GAP * float(count - 1)) / float(count) * pixel_scale.y) / pixel_scale.y
	var card_w: float = floorf(minf(card_h * 0.86, _scene.board.size.x * 0.19) * pixel_scale.x) / pixel_scale.x
	var card_size := Vector2(card_w, card_h)
	for panel in [_scene.hero_panel, _scene.enemy_panel]:
		panel.custom_minimum_size = Vector2(card_w + 32.0, 0.0)
	for view in _scene.hero_card_views + _scene.enemy_card_views:
		var card: CompactUnitCard = view.card
		card.apply_battle_presentation(1.5)
		card.apply_battle_layout(card_size)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	var footer_top: float = _scene.size.y - FOOTER_HEIGHT - float(PixelUI.safe_bottom)
	_scene.protocol_panel.offset_top = footer_top - _scene.size.y
	var divider: Control = _scene.get_node_or_null("FooterDivider")
	if divider != null:
		divider.offset_top = footer_top - 3.0
		divider.offset_bottom = footer_top
	refresh_chrome()


func refresh_chrome() -> void:
	_scene.protocol_label.add_theme_font_size_override("font_size", 100)
	var stack: Control = _scene.protocol_label.get_parent()
	if stack.name == "ProtocolStack":
		stack.custom_minimum_size.y = 160.0
		_scene.protocol_label.offset_top = -164.0
		_scene.protocol_label.offset_bottom = -42.0
		_scene.protocol_bar.offset_top = -52.0


func dice_anchor(side: String, state_id: String, zone: Rect2) -> Vector2:
	var views: Array = _scene.hero_card_views if side == "hero" else _scene.enemy_card_views
	for view in views:
		if str(view.state.id) == state_id:
			var card: Control = view.card
			# Match the owning card's vertical center. Leave the middle clear for
			# the existing Roll/End Turn control, including while dice are visible.
			var x: float = zone.size.x * (0.24 if side == "hero" else 0.76)
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
