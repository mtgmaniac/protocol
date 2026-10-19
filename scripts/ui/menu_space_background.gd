extends Control
## Shared, full-viewport title and squad-select image. The source is cropped to
## cover the control without changing its aspect ratio. Vertical crop comes from
## the starfield so the planet stays anchored to the bottom edge.

const BACKGROUND := preload("res://assets/ui/backgrounds/menu_space_background.png")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var image_size: Vector2 = BACKGROUND.get_size()
	var scale_factor: float = maxf(size.x / image_size.x, size.y / image_size.y)
	var source_size: Vector2 = size / scale_factor
	var source_origin := Vector2(
		(image_size.x - source_size.x) * 0.5,
		image_size.y - source_size.y
	)
	draw_texture_rect_region(BACKGROUND, Rect2(Vector2.ZERO, size), Rect2(source_origin, source_size))
