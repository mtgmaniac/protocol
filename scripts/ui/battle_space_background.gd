@tool
class_name BattleSpaceBackground
extends Control

const TOP_COLOR := Color("0f1b2b")
const MID_COLOR := Color("0a1320")
const BOTTOM_COLOR := Color("05080d")
const VIGNETTE_COLOR := Color(0.0, 0.0, 0.0, 0.16)
const STAR_DIM := Color(0.62, 0.72, 0.82, 0.14)
const STAR_SOFT := Color(0.76, 0.84, 0.92, 0.18)
const STAR_BRIGHT := Color(0.88, 0.92, 0.98, 0.24)

const STARS := [
	{"x": 0.08, "y": 0.12, "s": 1, "c": 0},
	{"x": 0.17, "y": 0.18, "s": 1, "c": 1},
	{"x": 0.29, "y": 0.07, "s": 1, "c": 0},
	{"x": 0.36, "y": 0.22, "s": 1, "c": 0},
	{"x": 0.48, "y": 0.15, "s": 1, "c": 1},
	{"x": 0.61, "y": 0.09, "s": 1, "c": 0},
	{"x": 0.73, "y": 0.19, "s": 1, "c": 0},
	{"x": 0.84, "y": 0.11, "s": 2, "c": 2},
	{"x": 0.92, "y": 0.24, "s": 1, "c": 0},
	{"x": 0.11, "y": 0.33, "s": 1, "c": 0},
	{"x": 0.22, "y": 0.41, "s": 1, "c": 1},
	{"x": 0.34, "y": 0.29, "s": 1, "c": 0},
	{"x": 0.43, "y": 0.38, "s": 1, "c": 0},
	{"x": 0.57, "y": 0.31, "s": 2, "c": 1},
	{"x": 0.68, "y": 0.43, "s": 1, "c": 0},
	{"x": 0.79, "y": 0.36, "s": 1, "c": 1},
	{"x": 0.90, "y": 0.47, "s": 1, "c": 0},
	{"x": 0.06, "y": 0.57, "s": 1, "c": 0},
	{"x": 0.19, "y": 0.63, "s": 1, "c": 0},
	{"x": 0.27, "y": 0.52, "s": 2, "c": 1},
	{"x": 0.39, "y": 0.61, "s": 1, "c": 0},
	{"x": 0.51, "y": 0.55, "s": 1, "c": 0},
	{"x": 0.63, "y": 0.66, "s": 1, "c": 1},
	{"x": 0.74, "y": 0.58, "s": 1, "c": 0},
	{"x": 0.86, "y": 0.62, "s": 2, "c": 2},
	{"x": 0.94, "y": 0.54, "s": 1, "c": 0},
	{"x": 0.09, "y": 0.79, "s": 1, "c": 0},
	{"x": 0.21, "y": 0.72, "s": 1, "c": 1},
	{"x": 0.33, "y": 0.86, "s": 1, "c": 0},
	{"x": 0.46, "y": 0.74, "s": 1, "c": 0},
	{"x": 0.58, "y": 0.83, "s": 1, "c": 1},
	{"x": 0.71, "y": 0.76, "s": 1, "c": 0},
	{"x": 0.82, "y": 0.88, "s": 1, "c": 0},
	{"x": 0.93, "y": 0.81, "s": 1, "c": 1}
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	_draw_gradient()
	_draw_stars()
	_draw_vignette()


func _draw_gradient() -> void:
	var h: int = maxi(1, int(size.y))
	for y in range(h):
		var t: float = float(y) / float(maxi(1, h - 1))
		var color: Color = TOP_COLOR.lerp(MID_COLOR, t / 0.5) if t < 0.5 else MID_COLOR.lerp(BOTTOM_COLOR, (t - 0.5) / 0.5)
		draw_line(Vector2(0.0, y), Vector2(size.x, y), color, 1.0)


func _draw_stars() -> void:
	for star_variant in STARS:
		var star: Dictionary = star_variant
		var x: float = float(star.get("x", 0.0)) * size.x
		var y: float = float(star.get("y", 0.0)) * size.y
		var star_size: int = int(star.get("s", 1))
		var color_index: int = int(star.get("c", 0))
		var color: Color = STAR_DIM
		if color_index == 1:
			color = STAR_SOFT
		elif color_index == 2:
			color = STAR_BRIGHT
		draw_rect(Rect2(Vector2(floor(x), floor(y)), Vector2(star_size, star_size)), color, true)


func _draw_vignette() -> void:
	var bands := [
		{"pad": 0.0, "alpha": 0.02},
		{"pad": 10.0, "alpha": 0.03},
		{"pad": 22.0, "alpha": 0.04},
		{"pad": 38.0, "alpha": 0.05}
	]
	for band_variant in bands:
		var band: Dictionary = band_variant
		var pad: float = float(band.get("pad", 0.0))
		var alpha: float = float(band.get("alpha", 0.0))
		var rect := Rect2(Vector2(pad, pad), Vector2(size.x - pad * 2.0, size.y - pad * 2.0))
		if rect.size.x > 0.0 and rect.size.y > 0.0:
			draw_rect(rect, Color(VIGNETTE_COLOR.r, VIGNETTE_COLOR.g, VIGNETTE_COLOR.b, alpha), false, 1.0)
