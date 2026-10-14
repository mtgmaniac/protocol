extends Control
## UI restyle A: the title screen's PLACEHOLDER backdrop, a dark ruined industrial
## street. Tall building slabs on both sides, a rust panel with faint stencil
## marks on the right, rubble and broken girders along the bottom, a few dim
## amber windows. Drawn on the shared pixel grid (PixelUI.make_art_grid_view): one
## art pixel is 4 design px, hard edges, a handful of tones, no gradients. Kept
## dark so the menu reads first. Positions are shares of the screen so the street
## holds its shape on any phone aspect.

const ART_PX := float(PixelUI.UI_ART_PX)
const VOID := Color("0c0d0f")
const SLAB_FAR := Color("111214")
const SLAB := Color("16171a")
const SLAB_LIT := Color("1d1e21")
const SEAM := Color("0a0a0b")
const RUBBLE := Color("141517")
const RUBBLE_LIT := Color("1f2023")
const GIRDER := Color("1b1c1f")
const GIRDER_LIT := Color("292a2e")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var screen: Vector2 = size * ART_PX
	if screen.x < 4.0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE / ART_PX)
	draw_rect(Rect2(Vector2.ZERO, screen), VOID)
	_draw_left_block(screen)
	_draw_right_block(screen)
	_draw_rubble(screen)
	draw_set_transform(Vector2.ZERO)


func _px(v: float) -> float:
	return roundf(v / ART_PX) * ART_PX


func _rect(x: float, y: float, w: float, h: float, colour: Color) -> void:
	draw_rect(Rect2(_px(x), _px(y), _px(w), _px(h)), colour)


# A slab with vertical panel seams, a lit inner edge and floor ledges.
func _slab(x: float, top: float, w: float, bottom: float, body: Color, lit_left: bool) -> void:
	_rect(x, top, w, bottom - top, body)
	_rect(x + (0.0 if lit_left else w - ART_PX), top, ART_PX, bottom - top, SLAB_LIT)
	for i in range(1, int(w / 56.0) + 1):
		_rect(x + i * 56.0, top, ART_PX, bottom - top, SEAM)
	var ledge: float = top + 180.0
	while ledge < bottom:
		_rect(x, ledge, w, ART_PX * 2.0, SEAM)
		ledge += 220.0


func _window(x: float, y: float) -> void:
	_rect(x - ART_PX, y - ART_PX, 24.0 + ART_PX * 2.0, 40.0 + ART_PX * 2.0, SEAM)
	_rect(x, y, 24.0, 40.0, PixelUI.UI_ACCENT.darkened(0.62))
	_rect(x, y, 24.0, ART_PX * 2.0, PixelUI.UI_ACCENT.darkened(0.45))


func _draw_left_block(screen: Vector2) -> void:
	var w: float = screen.x
	var h: float = screen.y
	_slab(w * 0.10, h * 0.04, w * 0.12, h * 0.80, SLAB_FAR, false)
	_slab(0.0, 0.0, w * 0.12, h * 0.92, SLAB, false)
	# A hanging sign frame and a scaffold run on the near slab.
	_rect(w * 0.085, h * 0.10, w * 0.035, h * 0.06, SEAM)
	_rect(w * 0.090, h * 0.105, w * 0.025, h * 0.05, SLAB_LIT)
	for y_share: float in [0.30, 0.31, 0.32]:
		_rect(w * 0.105, h * y_share, w * 0.03, ART_PX, PixelUI.UI_ACCENT.darkened(0.7))
	_window(w * 0.14, h * 0.62)
	_window(w * 0.04, h * 0.79)


func _draw_right_block(screen: Vector2) -> void:
	var w: float = screen.x
	var h: float = screen.y
	_slab(w * 0.74, 0.0, w * 0.12, h * 0.86, SLAB_FAR, true)
	_slab(w * 0.88, 0.0, w * 0.12, h * 0.95, SLAB, true)
	# The rust panel: flat rust, a lit edge, ragged weathering and faint stencils.
	var panel := Rect2(w * 0.76, 0.0, w * 0.13, h * 0.33)
	var rust: Color = PixelUI.BATTLE_BAY_RUST.darkened(0.3)
	_rect(panel.position.x, panel.position.y, panel.size.x, panel.size.y, rust)
	_rect(panel.position.x, 0.0, ART_PX, panel.size.y, PixelUI.BATTLE_BAY_RUST)
	var lengths: Array[int] = [3, 7, 2, 9, 5, 1, 6, 4, 8, 2, 5, 3]
	for i in range(lengths.size()):
		# Weathered bottom edge: columns end at uneven heights.
		_rect(panel.position.x + i * panel.size.x / lengths.size(), panel.end.y, panel.size.x / lengths.size(), lengths[i] * ART_PX, rust)
	var stencil: Color = rust.darkened(0.3)
	var sx: float = panel.position.x + panel.size.x * 0.28
	# A big stenciled "4" and a run of down-chevrons, both faint.
	_rect(sx, h * 0.15, ART_PX * 3.0, h * 0.045, stencil)
	_rect(sx, h * 0.19, panel.size.x * 0.42, ART_PX * 3.0, stencil)
	_rect(sx + panel.size.x * 0.26, h * 0.14, ART_PX * 3.0, h * 0.09, stencil)
	for i in range(3):
		var cy: float = h * 0.25 + i * ART_PX * 6.0
		for step in range(4):
			_rect(sx + step * ART_PX, cy + step * ART_PX, ART_PX * 2.0, ART_PX, stencil)
			_rect(sx + (7 - step) * ART_PX, cy + step * ART_PX, ART_PX * 2.0, ART_PX, stencil)
	_window(w * 0.92, h * 0.55)
	_window(w * 0.80, h * 0.72)


# Rubble and broken girders along the bottom.
func _draw_rubble(screen: Vector2) -> void:
	var w: float = screen.x
	var h: float = screen.y
	var ground := PackedVector2Array([
		Vector2(0, h * 0.80), Vector2(w * 0.08, h * 0.78), Vector2(w * 0.18, h * 0.84),
		Vector2(w * 0.30, h * 0.86), Vector2(w * 0.44, h * 0.90), Vector2(w * 0.62, h * 0.88),
		Vector2(w * 0.78, h * 0.86), Vector2(w * 0.90, h * 0.82), Vector2(w, h * 0.84),
		Vector2(w, h), Vector2(0, h)])
	draw_colored_polygon(ground, RUBBLE)
	for chunk: Rect2 in [Rect2(0.04, 0.84, 0.10, 0.03), Rect2(0.22, 0.88, 0.08, 0.02), Rect2(0.70, 0.90, 0.12, 0.03), Rect2(0.86, 0.86, 0.09, 0.04)]:
		_rect(w * chunk.position.x, h * chunk.position.y, w * chunk.size.x, h * chunk.size.y, RUBBLE_LIT)
	# Girders: thick diagonals with a lit top edge.
	for beam: Array in [[Vector2(0.0, 0.79), Vector2(0.30, 0.89)], [Vector2(0.24, 0.95), Vector2(0.40, 0.86)],
			[Vector2(0.64, 0.87), Vector2(0.98, 0.80)], [Vector2(0.82, 0.97), Vector2(0.94, 0.89)]]:
		var a := Vector2(w, h) * (beam[0] as Vector2)
		var b := Vector2(w, h) * (beam[1] as Vector2)
		draw_line(a, b, GIRDER, ART_PX * 6.0)
		draw_line(a - Vector2(0, ART_PX * 2.0), b - Vector2(0, ART_PX * 2.0), GIRDER_LIT, ART_PX)
