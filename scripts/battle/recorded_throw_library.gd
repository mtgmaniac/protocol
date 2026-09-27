extends RefCounted

const ROOT := "res://data/tutorial_throws"
const VARIANTS := 4
static var _cache: Dictionary = {}

static func get_track(enemy_count: int, variant: int, side: String, slot: int) -> Dictionary:
	var group: int = enemy_count if enemy_count in [1, 2] else 4
	var key: String = "%d_%d_%s_%s%d" % [group, variant, side, "h" if side == "hero" else "e", slot]
	if not _cache.has(key):
		var file := FileAccess.open(ROOT + "/" + key + ".json", FileAccess.READ)
		if file == null:
			push_error("Missing recorded throw: " + key)
			return {}
		_cache[key] = JSON.parse_string(file.get_as_text())
	return _cache[key]

static func frame_transform(frame: Array) -> Transform3D:
	return Transform3D(Basis(Quaternion(frame[3], frame[4], frame[5], frame[6]).normalized()), Vector3(frame[0], frame[1], frame[2]))
