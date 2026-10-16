@tool
class_name PatternBackground
extends Control

@export var grid_step: int = 8
@export var major_grid_step: int = 32
@export var scanline_step: int = 3
# ui-unify: neutral CHROME-family defaults from tokens (were a blue grid).
@export var grid_color: Color = PixelUI.PATTERN_GRID
@export var major_grid_color: Color = PixelUI.PATTERN_GRID_MAJOR
@export var scanline_color: Color = PixelUI.PATTERN_SCANLINE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var draw_size: Vector2 = size
	if draw_size.x <= 0.0 or draw_size.y <= 0.0:
		return

	for y in range(0, int(draw_size.y) + scanline_step, scanline_step):
		draw_line(Vector2(0, y), Vector2(draw_size.x, y), scanline_color, 1.0)

	for x in range(0, int(draw_size.x) + grid_step, grid_step):
		var color: Color = major_grid_color if x % major_grid_step == 0 else grid_color
		draw_line(Vector2(x, 0), Vector2(x, draw_size.y), color, 1.0)

	for y in range(0, int(draw_size.y) + grid_step, grid_step):
		var color: Color = major_grid_color if y % major_grid_step == 0 else grid_color
		draw_line(Vector2(0, y), Vector2(draw_size.x, y), color, 1.0)
