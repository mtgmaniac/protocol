extends Control
## Flat pixel A/B (default): a flat, top-down scene. A dark low-contrast pixel
## texture behind the whole board, the tray as one flat floor texture with a
## neutral rim just outside the tray and the reticle decal at low opacity. The
## tray is shared ground: floor tint, rim and decal come from CHROME
## (PixelUI.tray_palette), never the encounter; the floor PATTERN comes from the
## scene data. No walls, windows, vignette or streak.
##
## Battle depth prototype v3 (debug F9): the full-screen battle scene behind the board. A
## back wall behind the enemy cards, slab side walls down both edges, and one
## floor that widens from the back wall past the tray toward the hero cards,
## carried through the same projection the dice are drawn with (battle_depth.gd),
## so the dice meet the floor's edges where they bounce. Painted only: the dice
## never read it.
##
## It draws in a SubViewport one quarter of the screen's size (BattleLayout
## builds it), so every edge lands on the 4 design px art grid. Inputs are in
## design px; textures are 1 texel per art pixel. Per-operation textures and
## accents come from data/raw/battle-tray-scenes.json (PLACEHOLDER art).

const DEPTH := preload("res://scripts/ui/battle_depth.gd")
const RETICLE_PATH := "res://assets/battle_tray/placeholder_reactor_reticle_decal.png"
## Design px per art pixel.
const ART_PX := 4.0
const FLOOR_ROWS := 24
const FLOOR_COLUMNS := 12
## Back to front, the floor steps up to full brightness in flat bands.
const FLOOR_SHADE_STEPS := 6
const FLOOR_SHADE_BACK := 0.58
## The reticle's footprint on the flat floor, as shares of the tray.
const DECAL_FLAT_SIZE := Vector2(0.50, 0.34)
const EDGE_WIDTH := 8.0
## Hazard dashes per unit of floor depth, and the lit share of each.
const HAZARD_DASHES := 7.0
const HAZARD_DUTY := 0.42
## Shares of the tray height where the die tag rows sit: the enemy row on the
## back wall's foot, the hero row on the floor's front edge.
const ENEMY_TAG_ROW := Vector2(0.06, 0.175)
const HERO_TAG_ROW := Vector2(0.855, 1.0)
const VIGNETTE_STEP := 28.0
## Side-wall window slots near the top: design px from the screen top, and size.
const WINDOW_TOPS: Array[float] = [196.0, 332.0]
const WINDOW_SIZE := Vector2(12.0, 52.0)
## Flat scene: the backdrop texture behind the cards, and the rim's two art-px
## bands (a dark seam outside, the accent inside) just outside the tray.
const FLAT_BACKDROP_PATH := "res://assets/battle_tray/flat_backdrop_tile.png"
const FLAT_RIM_BANDS := 2

var operation_id: String = "":
	set(value):
		operation_id = value
		_load_scene()
		queue_redraw()
## Everything below is in design px, relative to the scene's top-left.
var screen := Vector2(1080, 2400)
var tray := Rect2()
var enemy_cards := Rect2()
var hero_cards := Rect2()

var _wall: Texture2D
var _floor: Texture2D
var _reticle: Texture2D
var _accent := Color.TRANSPARENT
var _edge := Color.TRANSPARENT
var _streak := Color.TRANSPARENT
var _flat_floor: Texture2D
var _flat_backdrop: Texture2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_load_scene()


func set_geometry(screen_size: Vector2, tray_rect: Rect2, enemy_rect: Rect2, hero_rect: Rect2) -> void:
	screen = screen_size
	tray = tray_rect
	enemy_cards = enemy_rect
	hero_cards = hero_rect
	queue_redraw()


func _load_scene() -> void:
	var entry: Dictionary = DEPTH.scene_for(operation_id)
	_wall = _texture(str(entry.get("wall_texture", "")))
	_floor = _texture(str(entry.get("floor_texture", "")))
	_reticle = _texture(RETICLE_PATH)
	_accent = DEPTH.token(str(entry.get("accent", "")))
	_edge = DEPTH.token(str(entry.get("edge_accent", "")))
	_streak = DEPTH.token(str(entry.get("streak", "")))
	_flat_floor = _texture(str(entry.get("flat_floor_texture", "")))
	_flat_backdrop = _texture(FLAT_BACKDROP_PATH)


func _texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## A point of the floor plane, in design px: flat tray x, depth 0 (back wall) up.
func _floor_at(flat_x: float, depth: float) -> Vector2:
	return tray.position + DEPTH.floor_at(flat_x, depth, tray.size)


func _draw() -> void:
	if tray.size.x < 2.0 or tray.size.y < 2.0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE / ART_PX)
	if not DEPTH.perspective_on:
		_draw_flat()
		draw_set_transform(Vector2.ZERO)
		return
	var back_left: Vector2 = _floor_at(0.0, 0.0)
	var back_right: Vector2 = _floor_at(tray.size.x, 0.0)
	var front_depth: float = DEPTH.depth_for_floor_y(screen.y - tray.position.y, tray.size)
	# Side walls fill the screen; the back wall and the floor are laid over them.
	draw_rect(Rect2(Vector2.ZERO, screen), PixelUI.BATTLE_BAY_WALL)
	_tile(Rect2(Vector2.ZERO, screen), _wall, Color.WHITE)
	_draw_wall_seams(back_left, back_right)
	_draw_back_wall(Rect2(back_left.x, 0.0, back_right.x - back_left.x, back_left.y))
	_draw_floor(front_depth)
	_draw_decal()
	_draw_edges(front_depth)
	_draw_vignette()
	# Lit window slots sit over the vignette: they are the light.
	_draw_windows(back_left.x)
	draw_set_transform(Vector2.ZERO)


# The flat scene. Every rect is snapped to the 4 design px art grid.
func _draw_flat() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), PixelUI.BATTLE_FLAT_BACKDROP)
	_tile(Rect2(Vector2.ZERO, screen), _flat_backdrop, PixelUI.BATTLE_FLAT_BACKDROP_TINT)
	var floor_rect := Rect2(_snap(tray.position), _snap(tray.end) - _snap(tray.position))
	var tray_colors: Dictionary = PixelUI.tray_palette()
	draw_rect(floor_rect.grow(ART_PX * FLAT_RIM_BANDS), PixelUI.BATTLE_BAY_SEAM)
	draw_rect(floor_rect.grow(ART_PX), tray_colors["rim"])
	var tint: Color = tray_colors["floor"]
	draw_rect(floor_rect, tint)
	_tile(floor_rect, _flat_floor, tint)
	_draw_flat_decal(floor_rect)


# The reticle flat on the floor at the tray's centre, one texel per art pixel
# where it fits (scaled down by whole steps where it does not), neutral.
func _draw_flat_decal(floor_rect: Rect2) -> void:
	if _reticle == null or not DEPTH.decal_on:
		return
	var tint: Color = PixelUI.tray_palette()["decal"]
	var side: float = _reticle.get_size().x * ART_PX
	while side > floor_rect.size.y * 0.8 and side > ART_PX * 8.0:
		side *= 0.5
	var origin: Vector2 = _snap(floor_rect.get_center() - Vector2(side, side) * 0.5)
	draw_texture_rect(_reticle, Rect2(origin, Vector2(side, side)), false, tint)


func _snap(point: Vector2) -> Vector2:
	return (point / ART_PX).round() * ART_PX


## One texel per art pixel, repeated across `area`.
func _tile(area: Rect2, texture: Texture2D, tint: Color) -> void:
	if texture != null:
		draw_texture_rect_region(texture, area, Rect2(area.position / ART_PX, area.size / ART_PX), tint)


# Horizontal plate seams on the side walls run toward the floor's vanishing point.
func _draw_wall_seams(back_left: Vector2, back_right: Vector2) -> void:
	var front_left: Vector2 = _floor_at(0.0, 1.0)
	# The floor edge runs from back_left to front_left; its extension meets the
	# centre line at the vanishing point.
	var mid: float = tray.position.x + tray.size.x * 0.5
	var slope: float = (front_left.y - back_left.y) / minf(front_left.x - back_left.x, -1.0)
	var vanish_y: float = back_left.y + (mid - back_left.x) * slope
	for share: float in [0.25, 0.5, 0.75]:
		var near := Vector2(back_left.x, back_left.y * share)
		var far_y: float = near.y + (0.0 - near.x) * (near.y - vanish_y) / (near.x - mid)
		draw_line(near, Vector2(0.0, far_y), PixelUI.BATTLE_BAY_SEAM, EDGE_WIDTH)
		draw_line(Vector2(back_right.x, near.y), Vector2(screen.x, far_y), PixelUI.BATTLE_BAY_SEAM, EDGE_WIDTH)


func _draw_windows(wall_width: float) -> void:
	if _edge.a <= 0.0:
		return
	var inset: float = roundf(wall_width * 0.32 / ART_PX) * ART_PX
	for top: float in WINDOW_TOPS:
		for x: float in [inset, screen.x - inset - WINDOW_SIZE.x]:
			draw_rect(Rect2(x - ART_PX, top - ART_PX, WINDOW_SIZE.x + ART_PX * 2.0, WINDOW_SIZE.y + ART_PX * 2.0), PixelUI.BATTLE_BAY_WINDOW_FRAME)
			draw_rect(Rect2(x, top, WINDOW_SIZE.x, WINDOW_SIZE.y), _edge.darkened(0.35))
			draw_rect(Rect2(x, top, WINDOW_SIZE.x, ART_PX * 3.0), _edge)


func _draw_back_wall(slot: Rect2) -> void:
	draw_rect(slot, PixelUI.BATTLE_BAY_WALL_BACK)
	_tile(slot, _wall, Color(0.85, 0.85, 0.85))
	# A ledge where the wall meets the floor.
	draw_rect(Rect2(slot.position.x, slot.end.y - ART_PX * 5.0, slot.size.x, ART_PX * 2.0), PixelUI.BATTLE_BAY_LEDGE)
	draw_rect(Rect2(slot.position.x, slot.end.y - ART_PX * 3.0, slot.size.x, ART_PX * 3.0), PixelUI.BATTLE_BAY_SEAM)
	if _streak.a > 0.0:
		_draw_streak(Vector2(roundf((slot.get_center().x + tray.size.x * 0.05) / ART_PX) * ART_PX, 144.0))


# A rust run down the back wall: ragged columns, a lit core, no gradient.
func _draw_streak(top: Vector2) -> void:
	var lengths: Array[int] = [14, 26, 38, 52, 46, 33, 21, 12, 6]
	for i in range(lengths.size()):
		var x: float = top.x + (i - lengths.size() * 0.5) * ART_PX
		var colour: Color = PixelUI.BATTLE_BAY_RUST_LIT if i in [2, 3, 4] else _streak
		draw_rect(Rect2(x, top.y, ART_PX, lengths[i] * ART_PX), colour)
		# Drips: a gap, then one more pixel.
		draw_rect(Rect2(x, top.y + (lengths[i] + 2 + i % 3) * ART_PX, ART_PX, ART_PX), _streak)


# The floor material, tiled on the flat floor and carried through the
# perspective. Each band of rows is one flat tone.
func _draw_floor(front_depth: float) -> void:
	var outline := PackedVector2Array([_floor_at(0.0, 0.0), _floor_at(tray.size.x, 0.0), _floor_at(tray.size.x, front_depth), _floor_at(0.0, front_depth)])
	draw_colored_polygon(outline, PixelUI.BATTLE_BAY_FLOOR)
	if _floor == null:
		return
	var tile: Vector2 = _floor.get_size() * ART_PX
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in range(FLOOR_ROWS):
		var band: float = floorf(float(row) * FLOOR_SHADE_STEPS / FLOOR_ROWS) / float(FLOOR_SHADE_STEPS - 1)
		var shade: float = lerpf(FLOOR_SHADE_BACK, 1.0, minf(band, 1.0))
		for column in range(FLOOR_COLUMNS):
			var first: int = points.size()
			for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var flat_x: float = (column + corner.x) / FLOOR_COLUMNS * tray.size.x
				var depth: float = (row + corner.y) / FLOOR_ROWS * front_depth
				points.append(_floor_at(flat_x, depth) / ART_PX)
				colors.append(Color(shade, shade, shade))
				# Panels are counted out from the centre line so they sit symmetric.
				uvs.append(Vector2((flat_x - tray.size.x * 0.5) / tile.x, depth * tray.size.y / tile.y))
			indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
	_add_triangles(indices, points, colors, uvs, _floor)


# The title logo's reactor emblem as a reticle on the floor at the tray's centre,
# tinted with the operation accent.
func _draw_decal() -> void:
	if _reticle == null or not DEPTH.decal_on:
		return
	var tint: Color = _accent if _accent.a > 0.0 else Color.WHITE
	tint.a = PixelUI.BATTLE_BAY_DECAL_ALPHA
	var extent: Vector2 = tray.size * DECAL_FLAT_SIZE
	var origin: Vector2 = (tray.size - extent) * 0.5
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	const CELLS := 8
	for row in range(CELLS):
		for column in range(CELLS):
			var first: int = points.size()
			for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var uv := Vector2(column + corner.x, row + corner.y) / float(CELLS)
				var flat: Vector2 = origin + extent * uv
				points.append((tray.position + DEPTH.floor_point(flat, tray.size)) / ART_PX)
				colors.append(tint)
				uvs.append(uv)
			indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
	_add_triangles(indices, points, colors, uvs, _reticle)


# Warped meshes go straight to the canvas item, in art px (the draw transform
# is set back to identity around them).
func _add_triangles(indices: PackedInt32Array, points: PackedVector2Array, colors: PackedColorArray, uvs: PackedVector2Array, texture: Texture2D) -> void:
	draw_set_transform(Vector2.ZERO)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colors, uvs, PackedInt32Array(), PackedFloat32Array(), texture.get_rid())
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE / ART_PX)


# Both slanted floor edges: a dark seam, then short hazard dashes in the accent.
func _draw_edges(front_depth: float) -> void:
	for flat_x: float in [0.0, tray.size.x]:
		draw_line(_floor_at(flat_x, 0.0), _floor_at(flat_x, front_depth), PixelUI.BATTLE_BAY_SEAM, EDGE_WIDTH * 2.0)
		if _edge.a <= 0.0:
			continue
		var steps: int = int(ceilf(front_depth * HAZARD_DASHES))
		for i in range(steps):
			var start: float = float(i) / HAZARD_DASHES
			draw_line(_floor_at(flat_x, start), _floor_at(flat_x, minf(start + HAZARD_DUTY / HAZARD_DASHES, front_depth)), _edge, EDGE_WIDTH)


# Hard-edged steps of black: toward the screen edges, around both card rows and
# under both die tag rows, so portraits and dice carry the contrast.
func _draw_vignette() -> void:
	var steps: Array[float] = PixelUI.BATTLE_VIGNETTE_STEPS
	var count: int = steps.size()
	var bands: Array[Rect2] = [
		Rect2(0.0, tray.position.y + tray.size.y * ENEMY_TAG_ROW.x, screen.x, tray.size.y * (ENEMY_TAG_ROW.y - ENEMY_TAG_ROW.x)),
		Rect2(0.0, tray.position.y + tray.size.y * HERO_TAG_ROW.x, screen.x, tray.size.y * (HERO_TAG_ROW.y - HERO_TAG_ROW.x)),
	]
	if enemy_cards.size.y > 0.0:
		bands.append(Rect2(0.0, 0.0, screen.x, enemy_cards.end.y))
	if hero_cards.size.y > 0.0:
		bands.append(Rect2(0.0, hero_cards.position.y, screen.x, screen.y - hero_cards.position.y))
	for i in range(count):
		# The widest, lightest step first; each narrower step adds its own black.
		var step: float = steps[count - 1 - i]
		var grow: float = VIGNETTE_STEP * float(count - 1 - i)
		for band: Rect2 in bands:
			# Card rows get a lighter hand than the tag rows: the walls still read.
			var weight: float = 1.0 if band.size.y < tray.size.y * 0.5 else 0.6
			draw_rect(band.grow_individual(0.0, grow, 0.0, grow), Color(0.0, 0.0, 0.0, step * weight))
		var edge: float = VIGNETTE_STEP * float(count - i)
		draw_rect(Rect2(0.0, 0.0, edge, screen.y), Color(0.0, 0.0, 0.0, step * 0.45))
		draw_rect(Rect2(screen.x - edge, 0.0, edge, screen.y), Color(0.0, 0.0, 0.0, step * 0.45))
