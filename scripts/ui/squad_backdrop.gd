extends Control
## Quiet full-viewport field behind squad selection. It is drawn independently
## of the portrait content column and has no bitmap-sized layout constraint.

const GRID := float(PixelUI.UI_ART_PX)
const STAR_COUNT := 36


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PixelUI.UI_BG)
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# Fixed sequence: stable between frames and across window resize. Each star
	# lands on the art grid and remains intentionally faint.
	var star_ink := PixelUI.CHROME_DIM
	star_ink.a = 0.24
	for i in STAR_COUNT:
		var x := floorf(fmod(float(i * 137 + 31), 997.0) / 997.0 * size.x / GRID) * GRID
		var y := floorf(fmod(float(i * 271 + 89), 991.0) / 991.0 * size.y * 0.78 / GRID) * GRID
		draw_rect(Rect2(x, y, GRID, GRID), star_ink)
	# A low-contrast dark planet remains at the bottom on narrow and wide
	# portrait canvases alike. The viewport clips its outer circle naturally.
	var radius: float = maxf(size.x * 0.85, size.y * 0.32)
	var center := Vector2(size.x * 0.52, size.y + radius * 0.78)
	draw_circle(center, radius, PixelUI.UI_PANEL)
	draw_circle(center + Vector2(0.0, GRID * 9.0), radius, PixelUI.UI_BG.darkened(0.12))
