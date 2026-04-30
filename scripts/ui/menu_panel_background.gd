extends Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var panel_color_1 = Color("0c1a2a")
	var panel_color_2 = Color("0a1624")
	var line_color = Color("2a3f55")
	var highlight = Color("3a5a78")
	var shadow = Color("000000")

	var design_size := Vector2(450.0, 1000.0)
	var sx: float = size.x / design_size.x
	var sy: float = size.y / design_size.y
	var panels = [
		Rect2(0, 0, 200, 180),
		Rect2(200, 0, 250, 140),
		Rect2(0, 180, 180, 220),
		Rect2(180, 140, 300, 260),
		Rect2(0, 400, 260, 300),
		Rect2(260, 400, 190, 300),
		Rect2(0, 700, 200, 300),
		Rect2(200, 700, 250, 300)
	]

	for i in panels.size():
		var p: Rect2 = panels[i]
		p.position = Vector2(p.position.x * sx, p.position.y * sy)
		p.size = Vector2(p.size.x * sx, p.size.y * sy)
		var color = panel_color_1 if i % 2 == 0 else panel_color_2

		draw_rect(p, color)

		draw_rect(p, line_color, false, 2.0)

		draw_line(p.position, p.position + Vector2(p.size.x, 0), highlight, 1.0)

		draw_line(
			p.position + Vector2(0, p.size.y),
			p.position + Vector2(p.size.x, p.size.y),
			shadow,
			1.0
		)
