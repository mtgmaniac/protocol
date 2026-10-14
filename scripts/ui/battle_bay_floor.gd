extends Control
## Battle depth prototype v2: the dice tray's scene. A back wall with one art
## slot, two side walls and a floor that narrows toward the wall. Painted only:
## the dice never read it. Geometry comes from battle_depth.gd, the same
## projection the tray draws the dice through. The art and the edge accent come
## from data/raw/battle-tray-scenes.json, one entry per operation.

const DEPTH := preload("res://scripts/ui/battle_depth.gd")
const SCENES_PATH := "res://data/raw/battle-tray-scenes.json"
const REACTOR_DECAL_PATH := "res://assets/battle_tray/reactor_emblem_decal.png"
## One art pixel is this many design px, close to the portraits' pixel size and
## a whole number of screen pixels at the 540 preview.
const ART_PX := 4.0
const FLOOR_ROWS := 18
const FLOOR_COLUMNS := 12
## Back to front, the floor steps up to full brightness in this many flat bands.
const FLOOR_SHADE_STEPS := 6
const FLOOR_SHADE_BACK := 0.62
## The reactor decal's footprint on the flat floor, as shares of the tray.
const DECAL_FLAT_SIZE := Vector2(0.44, 0.27)
const EDGE_WIDTH := 4.0
## Lit stretches of the floor edging, as depth ranges.
const EDGE_LIGHTS: Array[Vector2] = [Vector2(0.10, 0.16), Vector2(0.42, 0.50), Vector2(0.80, 0.90)]

var operation_id: String = "":
	set(value):
		operation_id = value
		_load_scene()
		queue_redraw()

var _wall_art: Texture2D
var _floor_texture: Texture2D
var _decal: Texture2D
var _accent := Color.TRANSPARENT
var _accent_lit := Color.TRANSPARENT


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	resized.connect(queue_redraw)
	get_viewport().size_changed.connect(queue_redraw)
	_load_scene()


func _load_scene() -> void:
	_wall_art = null
	_floor_texture = null
	_accent = Color.TRANSPARENT
	_accent_lit = Color.TRANSPARENT
	_decal = _texture(REACTOR_DECAL_PATH)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCENES_PATH))
	if not (parsed is Dictionary):
		push_error("battle tray scenes: %s did not parse" % SCENES_PATH)
		return
	var scenes: Dictionary = parsed.get("scenes", {})
	var entry: Dictionary = scenes.get(operation_id, scenes.get(str(parsed.get("fallback", "")), {}))
	_wall_art = _texture(str(entry.get("wall_art", "")))
	_floor_texture = _texture(str(entry.get("floor_texture", "")))
	var token: String = str(entry.get("edge_accent", ""))
	var palette: Dictionary = (load("res://scripts/ui/pixel_ui.gd") as Script).get_script_constant_map()
	if palette.get(token) is Color:
		_accent = palette[token]
		_accent_lit = palette.get(token + "_LIT", _accent)
	elif token != "":
		push_error("battle tray scenes: '%s' is not a PixelUI colour" % token)


func _texture(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _snap(point: Vector2) -> Vector2:
	return Vector2(PixelUI.snap_to_physical_px(self, point.x), PixelUI.snap_to_physical_px(self, point.y, 1))


func _floor(flat_x: float, depth: float) -> Vector2:
	return DEPTH.floor_point(Vector2(flat_x, depth * size.y), size)


func _draw() -> void:
	if size.x < 2.0 or size.y < 2.0:
		return
	if not DEPTH.backdrop_on:
		# A/B: the plain tray. The dice keep their depth; only the scene goes.
		draw_rect(Rect2(Vector2.ZERO, size), PixelUI.BATTLE_TRAY_FILL)
		_draw_decal()
		return
	var back_left: Vector2 = _snap(_floor(0.0, 0.0))
	var back_right: Vector2 = _snap(_floor(size.x, 0.0))
	var front_left := Vector2(0.0, size.y)
	var front_right := Vector2(size.x, size.y)
	# Side walls fill the frame; the back wall and the floor are laid over them.
	draw_rect(Rect2(Vector2.ZERO, size), PixelUI.BATTLE_BAY_WALL)
	# Wall plate seams run toward the same vanishing point as the floor's edges.
	var mid: float = size.x * 0.5
	var run: float = back_left.x / maxf(mid - back_left.x, 1.0)
	var vanish_y: float = back_left.y - (size.y - back_left.y) / maxf(run, 0.001)
	for share: float in [0.3, 0.65]:
		var near_y: float = back_left.y * share
		var far_y: float = near_y + (near_y - vanish_y) * run
		draw_line(Vector2(back_left.x, near_y), Vector2(0.0, far_y), PixelUI.BATTLE_BAY_SEAM, EDGE_WIDTH)
		draw_line(Vector2(back_right.x, near_y), Vector2(size.x, far_y), PixelUI.BATTLE_BAY_SEAM, EDGE_WIDTH)
	_draw_back_wall(Rect2(back_left.x, 0.0, back_right.x - back_left.x, back_left.y))
	draw_colored_polygon(PackedVector2Array([back_left, back_right, front_right, front_left]), PixelUI.BATTLE_BAY_FLOOR)
	_draw_floor_texture()
	_draw_decal()
	# The wall's contact line, then the operation's edging along the floor.
	draw_rect(Rect2(back_left.x, back_left.y, back_right.x - back_left.x, EDGE_WIDTH), PixelUI.BATTLE_INNER_EDGE)
	if _accent.a > 0.0:
		draw_line(back_left, front_left, _accent, EDGE_WIDTH)
		draw_line(back_right, front_right, _accent, EDGE_WIDTH)
		for span: Vector2 in EDGE_LIGHTS:
			draw_line(_floor(0.0, span.x), _floor(0.0, span.y), _accent_lit, EDGE_WIDTH)
			draw_line(_floor(size.x, span.x), _floor(size.x, span.y), _accent_lit, EDGE_WIDTH)


# The scene-art slot: the art keeps its pixel size, sits on the floor line and
# is cropped evenly at the sides; whatever it does not cover stays plain wall.
func _draw_back_wall(slot: Rect2) -> void:
	draw_rect(slot, PixelUI.BATTLE_BAY_WALL_BACK)
	if _wall_art == null:
		return
	var art: Vector2 = _wall_art.get_size()
	var shown := Vector2(minf(slot.size.x / ART_PX, art.x), minf(slot.size.y / ART_PX, art.y))
	var source := Rect2((art.x - shown.x) * 0.5, art.y - shown.y, shown.x, shown.y)
	var target := Rect2(slot.position.x + (slot.size.x - shown.x * ART_PX) * 0.5, slot.end.y - shown.y * ART_PX, shown.x * ART_PX, shown.y * ART_PX)
	draw_texture_rect_region(_wall_art, target, source)


# The floor material, tiled on the flat floor and carried through the same
# perspective as everything else. Each row is one flat tone: no smooth ramp.
func _draw_floor_texture() -> void:
	if _floor_texture == null:
		return
	var tile: Vector2 = _floor_texture.get_size() * ART_PX
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in range(FLOOR_ROWS):
		var shade: float = lerpf(FLOOR_SHADE_BACK, 1.0, floorf(float(row) * FLOOR_SHADE_STEPS / FLOOR_ROWS) / float(FLOOR_SHADE_STEPS - 1))
		for column in range(FLOOR_COLUMNS):
			var first: int = points.size()
			for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				var flat := Vector2((column + corner.x) / FLOOR_COLUMNS * size.x, (row + corner.y) / FLOOR_ROWS * size.y)
				points.append(DEPTH.floor_point(flat, size))
				colors.append(Color(shade, shade, shade))
				# Tiles are counted out from the centre line so the pattern is symmetric.
				uvs.append(Vector2((flat.x - size.x * 0.5) / tile.x, flat.y / tile.y))
			indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colors, uvs, PackedInt32Array(), PackedFloat32Array(), _floor_texture.get_rid())


# The title logo's reactor emblem, painted on the floor at the tray's centre.
func _draw_decal() -> void:
	if _decal == null or not DEPTH.decal_on:
		return
	var extent: Vector2 = size * DECAL_FLAT_SIZE
	var origin: Vector2 = (size - extent) * 0.5
	var ink := Color(1.0, 1.0, 1.0, PixelUI.BATTLE_BAY_DECAL_ALPHA)
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
				points.append(DEPTH.floor_point(flat, size) if DEPTH.backdrop_on else flat)
				colors.append(ink)
				uvs.append(uv)
			indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colors, uvs, PackedInt32Array(), PackedFloat32Array(), _decal.get_rid())
