# Language-free TYPE cue for reward / item cards: the silhouette framing the large item
# icon encodes its use — triangle = consumable, circle = gear, hexagon = relic. Drawn as
# a single flat 1-tone outline (no fill / gradient / glow) in the card's rarity color, so
# type is carried by SHAPE while rarity is carried by COLOR. NEAREST filter + integer
# line width keep it crisp and on-grid with the locked battle-screen aesthetic.
class_name ItemTypeFrame
extends Control

var shape: String = "circle"
var line_color: Color = Color.WHITE
var line_width: float = 4.0


func configure(item_type: String, color: Color, width: float = 4.0) -> void:
	shape = _shape_for_type(item_type)
	line_color = color
	line_width = width
	queue_redraw()


func _shape_for_type(item_type: String) -> String:
	match item_type:
		"consumable":
			return "circle"
		"gear":
			return "square"
		"relic":
			return "hexagon"
	return "square"


func _draw() -> void:
	var radius: float = minf(size.x, size.y) * 0.5 - line_width
	if radius <= 1.0:
		return
	var center: Vector2 = size * 0.5
	match shape:
		"circle":
			draw_arc(center, radius, 0.0, TAU, 48, line_color, line_width, false)
		"square":
			var top_left: Vector2 = center - Vector2(radius, radius)
			draw_rect(Rect2(top_left, Vector2(radius * 2.0, radius * 2.0)), line_color, false, line_width)
		"triangle":
			# Point up, flat bottom.
			_draw_outline(_regular_points(center, radius, 3, -PI / 2.0))
		"hexagon":
			# Flat top / bottom, vertices left + right.
			_draw_outline(_regular_points(center, radius, 6, 0.0))


func _regular_points(center: Vector2, radius: float, count: int, start_angle: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		var angle: float = start_angle + TAU * float(i) / float(count)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _draw_outline(points: PackedVector2Array) -> void:
	if points.size() < 2:
		return
	var loop := PackedVector2Array(points)
	loop.append(points[0])
	draw_polyline(loop, line_color, line_width, false)
