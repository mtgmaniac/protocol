extends Control
## A shallow maintenance bay: perspective is painted, never a physics surface.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	get_viewport().size_changed.connect(queue_redraw)


func _point(x: float, y: float) -> Vector2:
	return Vector2(PixelUI.snap_to_physical_px(self, size.x * x), PixelUI.snap_to_physical_px(self, size.y * y, 1))


func _quad(points: Array, color: Color) -> void:
	var polygon := PackedVector2Array()
	for p: Vector2 in points:
		polygon.append(_point(p.x, p.y))
	draw_colored_polygon(polygon, color)


func _draw() -> void:
	# Broad, quiet surfaces. A narrower back edge and splayed side walls sell depth.
	draw_rect(Rect2(Vector2.ZERO, size), PixelUI.BATTLE_BAY_WALL)
	_quad([Vector2(.075, .065), Vector2(.925, .065), Vector2(.975, .96), Vector2(.025, .96)], PixelUI.BATTLE_BAY_FLOOR)
	_quad([Vector2(.012, .012), Vector2(.988, .012), Vector2(.925, .065), Vector2(.075, .065)], PixelUI.BATTLE_BAY_LIP)
	_quad([Vector2(.075, .065), Vector2(.925, .065), Vector2(.928, .11), Vector2(.072, .11)], PixelUI.BATTLE_INNER_EDGE)
	_quad([Vector2(.012, .025), Vector2(.064, .072), Vector2(.014, .96), Vector2(.0, .99)], PixelUI.BATTLE_BORDER)
	_quad([Vector2(.988, .025), Vector2(.936, .072), Vector2(.986, .96), Vector2(1, .99)], PixelUI.BATTLE_BORDER)
	_quad([Vector2(.025, .96), Vector2(.975, .96), Vector2(.99, .98), Vector2(.01, .98)], PixelUI.BATTLE_BAY_LIP)
	# Two floor joints converge toward the rear; no grids or ornament fields.
	for x: float in [.32, .68]:
		var front_x: float = .5 + (x - .5) * 1.18
		_quad([Vector2(x, .11), Vector2(x + .004, .11), Vector2(front_x + .004, .96), Vector2(front_x, .96)], PixelUI.BATTLE_BAY_SEAM)
	# Low-contrast inset seam at the front and two small amber wear plates at rear.
	_quad([Vector2(.036, .79), Vector2(.964, .79), Vector2(.964, .797), Vector2(.036, .797)], PixelUI.BATTLE_BAY_SEAM)
	for x: float in [.16, .80]:
		_quad([Vector2(x, .027), Vector2(x + .04, .027), Vector2(x + .037, .041), Vector2(x - .003, .041)], PixelUI.BATTLE_BAY_AMBER)
