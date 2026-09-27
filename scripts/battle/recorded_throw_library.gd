extends RefCounted

# G-26 / G-31 recorded tutorial throws. Tracks are stored RELATIVE TO THE TRAY:
# each frame's centre is normalised to the tray's inner extent (the walls less
# one die radius), so a throw recorded at 1080x2400 maps onto whatever tray the
# live screen lays out. Rotation and height are stored as-is. Playback maps
# every frame onto the live bounds and discards a variant whose mapped dice
# would leave the visible tray (see `group_fits`).
const ROOT := "res://data/tutorial_throws"
const VARIANTS := 4
const FORMAT_VERSION := 2
# Centre travel is normalised against the tray less this margin (DIE_RADIUS).
const INNER_MARGIN := 1.0
# World-unit slack for the containment test (~2 px at the shipped tray scale):
# a die resting flat against a wall may press the collider by a hair.
const CONTAIN_EPS := 0.02
static var _cache: Dictionary = {}


static func track_key(enemy_count: int, variant: int, side: String, slot: int) -> String:
	var group: int = enemy_count if enemy_count in [1, 2] else 4
	return "%d_%d_%s_%s%d" % [group, variant, side, "h" if side == "hero" else "e", slot]


static func get_track(enemy_count: int, variant: int, side: String, slot: int) -> Dictionary:
	var key: String = track_key(enemy_count, variant, side, slot)
	if not _cache.has(key):
		var file := FileAccess.open(ROOT + "/" + key + ".json", FileAccess.READ)
		if file == null:
			push_error("Missing recorded throw: " + key)
			return {}
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not (parsed is Dictionary) or int((parsed as Dictionary).get("version", 0)) != FORMAT_VERSION:
			push_error("Recorded throw %s is not tray-normalised (version %d)" % [key, FORMAT_VERSION])
			return {}
		_cache[key] = parsed
	return _cache[key]


# `bounds` = [half_width, min_z, max_z] of a tray's walls (DiceTray3D._bounds_*).
static func normalize_origin(origin: Vector3, bounds: Array) -> Vector3:
	var half_w: float = maxf(float(bounds[0]) - INNER_MARGIN, 0.001)
	var center_z: float = (float(bounds[1]) + float(bounds[2])) * 0.5
	var half_d: float = maxf((float(bounds[2]) - float(bounds[1])) * 0.5 - INNER_MARGIN, 0.001)
	return Vector3(origin.x / half_w, origin.y, (origin.z - center_z) / half_d)


static func denormalize_origin(n: Vector3, bounds: Array) -> Vector3:
	var half_w: float = maxf(float(bounds[0]) - INNER_MARGIN, 0.001)
	var center_z: float = (float(bounds[1]) + float(bounds[2])) * 0.5
	var half_d: float = maxf((float(bounds[2]) - float(bounds[1])) * 0.5 - INNER_MARGIN, 0.001)
	return Vector3(n.x * half_w, n.y, center_z + n.z * half_d)


# One stored frame mapped onto a live tray.
static func frame_transform(frame: Array, bounds: Array) -> Transform3D:
	var rotation := Basis(Quaternion(frame[3], frame[4], frame[5], frame[6]).normalized())
	return Transform3D(rotation, denormalize_origin(Vector3(frame[0], frame[1], frame[2]), bounds))


# True when every vertex of the die stays over the tray floor (inside the walls,
# i.e. inside the straight-down camera's view) on every mapped frame.
static func track_fits(track: Dictionary, bounds: Array, vertices: Array) -> bool:
	var half_w: float = float(bounds[0]) + CONTAIN_EPS
	var min_z: float = float(bounds[1]) - CONTAIN_EPS
	var max_z: float = float(bounds[2]) + CONTAIN_EPS
	for frame in track.get("frames", []):
		var xform: Transform3D = frame_transform(frame, bounds)
		for vertex in vertices:
			var p: Vector3 = xform * (vertex as Vector3)
			if absf(p.x) > half_w or p.z < min_z or p.z > max_z:
				return false
	return true


# A throw's variant is kept or discarded as a whole: its dice share recorded
# collisions, so dropping one die's track would break the others' paths.
static func group_fits(tracks: Array, bounds: Array, vertices: Array) -> bool:
	for track in tracks:
		if (track as Dictionary).is_empty() or not track_fits(track, bounds, vertices):
			return false
	return true
