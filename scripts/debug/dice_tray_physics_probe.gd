# Headless physics probe for the 3D dice tray. Rolls repeatedly, with and
# without a frozen die on the tray, and reports:
#   - penetration: rolling die overlapping the frozen die volume (collision bug)
#   - flyover: rolling die crossing the frozen die's XZ footprint while airborne
#   - frozen die displacement (should stay immovable)
#   - corner/tilt rest: dice that finish leaning instead of face-flat
# Run:
#   godot --headless --path . res://scenes/debug/DiceTrayPhysicsProbe.tscn
extends Control

const ROLL_COUNT := 8
const FROZEN_HERO_ID := "hero_a"

var _tray: DiceTray3D
var _report_lines: Array[String] = []


func _ready() -> void:
	size = Vector2(1056, 1100)
	_tray = load("res://scenes/battle/DiceTray3D.tscn").instantiate() as DiceTray3D
	_tray.custom_minimum_size = size
	add_child(_tray)
	_tray.set_combat_zone_rect(Rect2(Vector2.ZERO, size))
	await get_tree().process_frame
	_run()


func _run() -> void:
	var penetration_events := 0
	var flyover_events := 0
	var max_frozen_drift := 0.0
	var tilted_rests := 0
	var corner_rests := 0
	var settle_times: Array[float] = []

	for roll_index in range(ROLL_COUNT):
		var with_frozen: bool = roll_index >= 1
		var hero_entries: Array = [
			{"id": "hero_a", "name": "A"},
			{"id": "hero_b", "name": "B"},
			{"id": "hero_c", "name": "C"},
		]
		var enemy_entries: Array = [
			{"id": "enemy_a", "name": "X"},
			{"id": "enemy_b", "name": "Y"},
		]
		if with_frozen:
			hero_entries[0]["frozen"] = true
			hero_entries[0]["frozen_roll"] = 12

		_tray.play_rolls(hero_entries, enemy_entries)

		var frozen_die: RigidBody3D = null
		var frozen_origin := Vector3.INF
		var elapsed := 0.0
		while _tray._is_rolling:
			await get_tree().physics_frame
			elapsed += get_physics_process_delta_time()
			if not with_frozen:
				continue
			if frozen_die == null:
				frozen_die = _tray._die_by_key.get("hero:%s" % FROZEN_HERO_ID, null) as RigidBody3D
				if frozen_die != null:
					frozen_origin = frozen_die.global_transform.origin
			if frozen_die == null or not is_instance_valid(frozen_die):
				continue
			var fo: Vector3 = frozen_die.global_transform.origin
			max_frozen_drift = maxf(max_frozen_drift, (fo - frozen_origin).length())
			for key in _tray._die_by_key:
				if str(key) == "hero:%s" % FROZEN_HERO_ID:
					continue
				var die: RigidBody3D = _tray._die_by_key[key] as RigidBody3D
				if die == null or not is_instance_valid(die) or die.freeze:
					continue
				var o: Vector3 = die.global_transform.origin
				var center_dist: float = (o - fo).length()
				var xz_dist: float = Vector2(o.x - fo.x, o.z - fo.z).length()
				if center_dist < 1.40:
					penetration_events += 1
				elif xz_dist < 1.4 and (o.y - fo.y) > 1.2:
					flyover_events += 1
		settle_times.append(elapsed)

		# Rest-pose audit: how flat did each die land before result presentation?
		for key in _tray._die_by_key:
			var die: RigidBody3D = _tray._die_by_key[key] as RigidBody3D
			if die == null or not is_instance_valid(die):
				continue
			var landed_flat: bool = _top_face_alignment(die) > 0.97
			if not landed_flat:
				tilted_rests += 1
				if _is_near_corner(die.global_transform.origin):
					corner_rests += 1
		await get_tree().create_timer(0.1).timeout

	var total_settle := 0.0
	for t in settle_times:
		total_settle += t
	print("[PROBE] rolls=%d penetration_events=%d flyover_events=%d" % [ROLL_COUNT, penetration_events, flyover_events])
	print("[PROBE] frozen_max_drift=%.4f" % max_frozen_drift)
	print("[PROBE] tilted_rests=%d (of ~%d dice) corner_tilted=%d" % [tilted_rests, ROLL_COUNT * 5, corner_rests])
	print("[PROBE] avg_settle=%.2fs max=%.2fs" % [total_settle / settle_times.size(), settle_times.max()])
	get_tree().quit(0)


# 1.0 when some face points straight up (die at rest on a face).
func _top_face_alignment(die: RigidBody3D) -> float:
	var best := -1.0
	for i in range(_tray._face_normals.size()):
		var world_normal: Vector3 = (die.global_transform.basis * _tray._face_normals[i]).normalized()
		best = maxf(best, world_normal.dot(Vector3.UP))
	return best


func _is_near_corner(origin: Vector3) -> bool:
	var margin := DIE_MARGIN
	var near_x: bool = absf(origin.x) > _tray._bounds_half_width - margin
	var near_z: bool = origin.z < _tray._bounds_min_z + margin or origin.z > _tray._bounds_max_z - margin
	return near_x and near_z


const DIE_MARGIN := 1.6
