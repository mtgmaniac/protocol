extends RefCounted
## Battle depth prototype (v2, v3): the ONE draw-time projection of the dice tray.
##
## The dice simulate in the flat, top-down tray rectangle. Nothing here is read by
## physics, tray bounds, result slots or combat: it only says where a point of
## that rectangle is DRAWN. `flat` is a tray-local point of the rectangle (what
## the tray camera unprojects); `depth` is its y as 0 (back wall) .. 1 (front).
## Preloaded by path (no class_name) so `-s` test scripts never resolve it early.

## Debug A/B switches (battle scene, debug builds): F6 the scene, F8 the v2
## plates behind the die tags, F9 the v3 perspective. (F7, the floor decal, went
## with the decal: the tray floor image carries its own reticle, G-76 / G-79.)
static var backdrop_on := true
static var plates_on := false
## Flat pixel A: the tray is drawn top-down and flat (every die the same size, no
## depth scaling, the dice drawn exactly where they simulate, hard pixel drop
## shadows, the flat floor scene). F9 brings back the v3 perspective path (the
## projection below, soft contact shadows, the walled scene) to compare.
static var perspective_on := false

const SCENES_PATH := "res://data/raw/battle-tray-scenes.json"
static var _scenes: Dictionary = {}


## One operation's scene entry (data/raw/battle-tray-scenes.json); operations
## without an entry get the fallback.
static func scene_for(operation_id: String) -> Dictionary:
	if _scenes.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCENES_PATH))
		if not (parsed is Dictionary):
			push_error("battle tray scenes: %s did not parse" % SCENES_PATH)
			return {}
		_scenes = parsed
	var scenes: Dictionary = _scenes.get("scenes", {})
	return scenes.get(operation_id, scenes.get(str(_scenes.get("fallback", "")), {}))


## The operation's ENCOUNTER accent (flat pixel A color roles): the PixelUI token
## its scene entry names as `accent`. Operations without one get the fallback's,
## and an empty name is transparent.
static func encounter_accent(operation_id: String) -> Color:
	return token(str(scene_for(operation_id).get("accent", "")))


## The dice tray's floor (Kev, 2026-10-17, G-84): one floor image per
## operation, a data entry in `tray_floors`. A scene entry names its own
## `tray_floor`; the root `tray_floor` (Facility's) is every other scene's.
static func tray_floor_for(operation_id: String) -> Dictionary:
	var entry: Dictionary = scene_for(operation_id)
	var floor_id: String = str(entry.get("tray_floor", _scenes.get("tray_floor", "")))
	return (_scenes.get("tray_floors", {}) as Dictionary).get(floor_id, {})


## A PixelUI colour named in the scene data. Empty name: transparent.
static func token(name: String) -> Color:
	if name == "":
		return Color.TRANSPARENT
	var value: Variant = (load("res://scripts/ui/pixel_ui.gd") as Script).get(name)
	if value is Color:
		return value
	push_error("battle tray scenes: '%s' is not a PixelUI colour" % name)
	return Color.TRANSPARENT


static func depth_at(flat_y: float, tray: Vector2) -> float:
	return clampf(flat_y / maxf(tray.y, 1.0), 0.0, 1.0)


## How large a die is drawn at this depth (1.0 = its physical size). Flat: 1.0.
static func die_scale(depth: float) -> float:
	if not perspective_on:
		return 1.0
	return lerpf(PixelUI.BATTLE_DEPTH_BACK, PixelUI.BATTLE_DEPTH_FRONT, depth)


## Where a die resting at `flat` is drawn: pulled toward the centre line at the
## back and nudged down the screen, both linear in depth, so a straight roll
## stays straight.
static func die_center(flat: Vector2, tray: Vector2) -> Vector2:
	if not perspective_on:
		return flat
	var depth: float = depth_at(flat.y, tray)
	var mid: float = tray.x * 0.5
	var push: float = tray.y * PixelUI.BATTLE_DEPTH_PUSH
	return Vector2(
		mid + (flat.x - mid) * lerpf(PixelUI.BATTLE_DEPTH_TAPER, 1.0, depth),
		push + flat.y * (1.0 - PixelUI.BATTLE_DEPTH_PUSH))


## Where the back wall meets the floor, in tray-local y.
static func wall_base(tray: Vector2) -> float:
	return tray.y * PixelUI.BATTLE_DEPTH_WALL if perspective_on else 0.0


## The floor plane, for everything painted ON it (texture, decal). A true
## one-point perspective of the same trapezoid: rows crowd toward the back wall.
## `depth` past 1 continues the same plane in front of the tray (the full-screen
## scene runs the floor on under the hero cards).
static func floor_point(flat: Vector2, tray: Vector2) -> Vector2:
	return floor_at(flat.x, depth_at(flat.y, tray), tray)


static func floor_at(flat_x: float, depth: float, tray: Vector2) -> Vector2:
	if not perspective_on:
		return Vector2(flat_x, depth * tray.y)
	var flat := Vector2(flat_x, 0.0)
	var back: float = PixelUI.BATTLE_DEPTH_TAPER
	var width: float = 1.0 / lerpf(1.0 / back, 1.0, depth)
	var base: float = wall_base(tray)
	var mid: float = tray.x * 0.5
	return Vector2(
		mid + (flat.x - mid) * width,
		base + (tray.y - base) * (width - back) / (1.0 - back))


## The floor depth drawn at tray-local y (the inverse of floor_at's y); can be
## past 1 below the tray.
static func depth_for_floor_y(y: float, tray: Vector2) -> float:
	if not perspective_on:
		return y / maxf(tray.y, 1.0)
	var back: float = PixelUI.BATTLE_DEPTH_TAPER
	var base: float = wall_base(tray)
	var width: float = back + (y - base) / maxf(tray.y - base, 1.0) * (1.0 - back)
	return (1.0 / width - 1.0 / back) / (1.0 - 1.0 / back)
