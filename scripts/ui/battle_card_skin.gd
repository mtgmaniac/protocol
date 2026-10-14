extends Node2D
## Paint-only composite skin. Existing card controls own geometry, input and HP.
## A background instance fills the regions; a foreground instance joins their
## edges over portraits and animated HP layers. Neither participates in layout.

var host: Control
var title: Control
var health: Control
var foreground := false
var border := PixelUI.BATTLE_HERO_LINE
var title_fill := PixelUI.BATTLE_HERO_HEADER


func setup(card: Control, title_region: Control, health_region: Control, front: bool) -> void:
	host = card
	title = title_region
	health = health_region
	foreground = front
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for region: Control in [host, title, health]:
		region.item_rect_changed.connect(queue_redraw)
	host.get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()


func set_palette(edge: Color, heading: Color) -> void:
	border = edge
	title_fill = heading
	queue_redraw()


func _local_region(region: Control) -> Rect2:
	var relative := host.get_global_transform().affine_inverse() * region.get_global_transform()
	return relative * Rect2(Vector2.ZERO, region.size)


func _draw() -> void:
	if host == null or not is_instance_valid(title) or not is_instance_valid(health):
		return
	var bounds := Rect2(Vector2.ZERO, host.size)
	var heading := _local_region(title)
	var hp := _local_region(health)
	var title_bottom := PixelUI.snap_to_physical_px(self, heading.end.y, 1)
	var hp_top := PixelUI.snap_to_physical_px(self, hp.position.y, 1)
	var edge := float(PixelUI.BATTLE_SHELL_WIDTH)
	var stacked := heading.size.x > host.size.x * 0.8
	if not foreground:
		draw_rect(bounds, PixelUI.BATTLE_PORTRAIT_FIELD)
		draw_rect(Rect2(0, 0, host.size.x, title_bottom) if stacked else heading, title_fill)
		draw_rect(Rect2(0, hp_top, host.size.x, hp.size.y) if stacked else hp, PixelUI.BATTLE_HP_TRACK)
		return
	# Title and HP are divisions of ONE shell, not boxes nested in a card.
	draw_style_box(PixelUI.battle_panel_style(Color.TRANSPARENT, border), bounds)
	if stacked:
		draw_rect(Rect2(edge, title_bottom - edge, host.size.x - edge * 2, edge), border)
		draw_rect(Rect2(edge, hp_top, host.size.x - edge * 2, PixelUI.BATTLE_INSET_WIDTH), PixelUI.BATTLE_INNER_EDGE)
