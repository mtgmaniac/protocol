extends Control
## The title screen's space backdrop (Kev, 2026-10-17, DECISIONS_RESOLVED G-76):
## assets/ui/title/title_backdrop.png, the 270 x 600 art px core in a 338 x 660
## bleed canvas (docs/ART_SPEC.md "Title screen backdrop"). Drawn on the shared
## pixel grid (PixelUI.make_art_grid_view): one texel per art pixel, 4 design px,
## centred on the screen, like battle_bay_floor.gd's flat scene. The bleed shows
## only on phones that are not 20:9. Built by tools/build_backdrops.py.
## A missing file draws the plain dark screen colour.
##
## The run-end screen (run_end_screen.gd) reuses this painter for the operation's
## image, the same canvas and placement, through `image_path`; a defeat sets
## `darken` and `desaturate`.

const ART_PX := float(PixelUI.UI_ART_PX)
const BACKDROP_PATH := "res://assets/ui/title/title_backdrop.png"

## The image to draw; set before the node enters the tree. "" draws the plain
## dark screen colour.
var image_path: String = BACKDROP_PATH
## Shares of brightness taken off and of saturation taken out (0 = as drawn).
var darken: float = 0.0
var desaturate: float = 0.0
## Whole art px the image moves from centre, negative = up (G-85: the run-end
## screens' per-operation focal offset). Clamped to the bleed the screen leaves,
## so an edge of the image never shows; a screen as tall as the canvas (22:9)
## draws it centred.
var offset_y: int = 0
var _image: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if image_path != "" and ResourceLoader.exists(image_path):
		_image = load(image_path) as Texture2D
	if _image != null and (darken > 0.0 or desaturate > 0.0):
		var adjusted: Image = _image.get_image()
		if adjusted.is_compressed():
			adjusted.decompress()
		adjusted.adjust_bcs(1.0 - darken, 1.0, 1.0 - desaturate)
		_image = ImageTexture.create_from_image(adjusted)
	resized.connect(queue_redraw)


func _draw() -> void:
	var screen: Vector2 = size * ART_PX
	if screen.x < 4.0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE / ART_PX)
	draw_rect(Rect2(Vector2.ZERO, screen), PixelUI.UI_BG)
	if _image != null:
		var drawn: Vector2 = _image.get_size() * ART_PX
		var origin: Vector2 = (((screen - drawn) * 0.5) / ART_PX).round() * ART_PX
		origin.y += shift_for(screen.y, drawn.y, origin.y, offset_y)
		draw_texture_rect(_image, Rect2(origin, drawn), false)
	draw_set_transform(Vector2.ZERO)


## The design px the image actually moves for `offset` art px: as far as the
## image still covers the screen top and bottom (no move when it is shorter).
static func shift_for(screen_h: float, drawn_h: float, origin_y: float, offset: int) -> float:
	var shift: float = float(offset) * ART_PX
	if drawn_h < screen_h:
		return 0.0
	return clampf(shift, screen_h - drawn_h - origin_y, -origin_y)
