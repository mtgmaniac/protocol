# P0 dice face audit probe (docs/audits/DICE_FACE_AUDIT.md, Phase 1).
# Instruments the REAL DiceTray3D roll path with a decided value per die (the
# battle decides every value before the throw; the tray reads it through
# value_provider) and logs, per die per roll:
#   logic   — the rigged value the game will resolve from (display face)
#   landed  — the face physically up when motion settles (before any snap)
#   final   — the face up after the end-of-roll presentation
#   label   — the numeral whose Label3D actually faces up (mesh check,
#             independent of the _face_normals table)
#   snap    — total rotation the presentation applies (deg), split into the
#             tilt that changes the face vs the yaw that only squares it up
# Run: godot --headless --path . -s scripts/debug/dice_face_audit_probe.gd
extends SceneTree

const ROLLS := 40
const HERO_IDS := ["h0", "h1", "h2"]
const ENEMY_IDS := ["e0", "e1", "e2", "e3"]
const PROBE_SEED := 20260926

var _tray: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# 8x physics with the same 1/120 s step (ticks and time scale together).
	Engine.physics_ticks_per_second = 960
	Engine.time_scale = 8
	Engine.max_physics_steps_per_frame = 64
	seed(PROBE_SEED)
	var host: Control = Control.new()
	host.size = Vector2(1056, 1100)
	root.add_child(host)
	_tray = load("res://scenes/battle/DiceTray3D.tscn").instantiate()
	_tray.custom_minimum_size = host.size
	host.add_child(_tray)
	_tray.call("set_combat_zone_rect", Rect2(Vector2.ZERO, host.size))
	await process_frame

	var total := 0
	var mismatched := 0
	var label_mismatch := 0
	var final_wrong := 0
	var tilts: Array[float] = []
	var yaws: Array[float] = []
	var mismatch_tilts: Array[float] = []
	var seen: Dictionary = {}
	for roll in range(ROLLS):
		var hero_entries: Array = []
		var enemy_entries: Array = []
		var rig: Dictionary = {}
		var slot := 0
		for id in ENEMY_IDS + HERO_IDS:
			var side: String = "hero" if HERO_IDS.has(id) else "enemy"
			var v: int = ((roll + slot * 7) % 20) + 1
			rig["%s:%s" % [side, id]] = v
			(hero_entries if side == "hero" else enemy_entries).append({"id": id, "name": id})
			slot += 1
		_tray.set("value_provider", func(side: String, uid: String) -> int: return int(rig.get("%s:%s" % [side, uid], 0)))
		_tray.call("play_rolls", hero_entries, enemy_entries)
		var landed: Dictionary = {}
		while bool(_tray.get("_is_rolling")):
			await physics_frame
			for key in rig:
				if landed.has(key):
					continue
				var die: RigidBody3D = (_tray.get("_die_by_key") as Dictionary).get(key, null) as RigidBody3D
				if die != null and is_instance_valid(die) and die.freeze:
					landed[key] = {"face": int(_tray.call("_get_most_visible_face_value", die)), "basis": die.global_transform.basis}
		for key in rig:
			var die: RigidBody3D = (_tray.get("_die_by_key") as Dictionary).get(key, null) as RigidBody3D
			var logic: int = int(rig[key])
			var land: Dictionary = landed.get(key, {})
			var final_face: int = int(_tray.call("_get_most_visible_face_value", die))
			var label_face: int = int(_tray.call("up_face_numeral", str(key).get_slice(":", 0), str(key).get_slice(":", 1)))
			var lb: Basis = land.get("basis", die.global_transform.basis)
			var fb: Basis = die.global_transform.basis
			var total_deg: float = rad_to_deg((fb * lb.inverse()).orthonormalized().get_rotation_quaternion().get_angle())
			total_deg = minf(total_deg, 360.0 - total_deg)
			# Tilt: how far the LOGIC face's normal was from straight up at landing.
			var face_idx: int = int(_tray.call("_get_face_index_for_result", logic))
			var n_local: Vector3 = (_tray.get("_face_normals") as Array)[face_idx]
			var tilt_deg: float = rad_to_deg((lb * n_local).normalized().angle_to(Vector3.UP))
			var yaw_deg: float = maxf(total_deg - tilt_deg, 0.0)
			total += 1
			seen["%s=%d" % [key, logic]] = true
			if int(land.get("face", -1)) != logic:
				mismatched += 1
				mismatch_tilts.append(tilt_deg)
			if label_face != final_face:
				label_mismatch += 1
			if final_face != logic:
				final_wrong += 1
			tilts.append(tilt_deg)
			yaws.append(yaw_deg)
			print("[DICE_AUDIT] roll=%02d %-8s logic=%2d landed=%2d final=%2d label=%2d snap=%6.1f tilt=%6.1f yaw~%6.1f" % [
				roll, key, logic, int(land.get("face", -1)), final_face, label_face, total_deg, tilt_deg, yaw_deg])
		await create_timer(0.05).timeout

	tilts.sort()
	mismatch_tilts.sort()
	print("[DICE_AUDIT] SUMMARY dice=%d slot_value_pairs=%d landed!=logic=%d (%.1f%%) final!=logic=%d label!=final=%d" % [
		total, seen.size(), mismatched, 100.0 * mismatched / maxf(total, 1), final_wrong, label_mismatch])
	print("[DICE_AUDIT] tilt(deg) all: median=%.1f p90=%.1f max=%.1f" % [_pct(tilts, 0.5), _pct(tilts, 0.9), tilts.back()])
	if not mismatch_tilts.is_empty():
		print("[DICE_AUDIT] tilt(deg) on mismatched dice: median=%.1f min=%.1f max=%.1f" % [_pct(mismatch_tilts, 0.5), mismatch_tilts[0], mismatch_tilts.back()])
	quit(0)


func _pct(arr: Array[float], p: float) -> float:
	if arr.is_empty():
		return 0.0
	return arr[clampi(int(p * (arr.size() - 1)), 0, arr.size() - 1)]
