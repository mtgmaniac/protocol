extends SceneTree

# Dev-only recorder (G-26 / G-31). Calls the live tray's play_rolls with NO rig
# and samples body transforms at physics-frame boundaries, ending before upright
# snapping. Runs the REAL battle scene at the shipped 1080x2400 layout: a
# headless window is 64x64, which the "expand" stretch turns into a 2400-wide
# tray whose walls sit far outside a phone's view (the bug this replaced).
# Frames are stored normalised to the tray (RecordedThrows.normalize_origin);
# a throw in which any die leaves the tray is discarded and thrown again.
#   godot --headless --path . -s scripts/debug/record_tutorial_throws.gd
const RecordedThrows := preload("res://scripts/battle/recorded_throw_library.gd")
const OUT := "res://data/tutorial_throws"
const VARIANTS := RecordedThrows.VARIANTS
const WINDOW := Vector2i(1080, 2400)
const MAX_ATTEMPTS_PER_GROUP := 60
var measurements: Array = []
var impacts: Dictionary = {}
var launch_frame: int = 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	root.size = WINDOW
	var gs = root.get_node("GameState")
	gs.start_run(["combat", "engineer", "medic"], "facility", 27092026)
	change_scene_to_file("res://scenes/battle/BattleScene.tscn")
	await create_timer(0.8).timeout
	var scene: Node = current_scene
	var tray: Node = scene.dice_tray_3d
	var visible_rect: Vector2 = root.get_visible_rect().size
	if visible_rect != Vector2(WINDOW):
		print("[THROW_RECORDER] FAIL: visible rect %s, expected %s" % [visible_rect, WINDOW])
		quit(1)
		return
	var bounds: Array = [tray._bounds_half_width, tray._bounds_min_z, tray._bounds_max_z]
	print("[THROW_RECORDER] tray %s px, walls %s" % [tray.size, bounds])
	var vertices: Array = tray._get_raw_d20_vertices()
	tray.recording_impact.connect(func(key: String, speed: float):
		if not impacts.has(key):
			impacts[key] = []
		impacts[key].append([Engine.get_physics_frames() - launch_frame, snappedf(speed, 0.001)]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var kept_total: int = 0
	var discarded_total: int = 0
	for enemy_count in [1, 2, 4]:
		var heroes: Array = []
		var enemies: Array = []
		for index in 3:
			heroes.append({"id": "h%d" % index})
		for index in enemy_count:
			enemies.append({"id": "e%d" % index})
		var kept: int = 0
		var attempts: int = 0
		while kept < VARIANTS * 2 and attempts < MAX_ATTEMPTS_PER_GROUP:
			attempts += 1
			impacts.clear()
			launch_frame = Engine.get_physics_frames()
			tray.set_rigged_results({})
			tray.play_rolls(heroes, enemies)
			var tracks: Dictionary = {}
			var contained: bool = true
			while bool(tray._is_rolling):
				for key in tray._die_by_key:
					var die: RigidBody3D = tray._die_by_key[key]
					if not tracks.has(key):
						tracks[key] = {"frames": [], "finished": false, "distance": 0.0}
					var track: Dictionary = tracks[key]
					if bool(track.finished):
						continue
					var t: Transform3D = die.global_transform
					for vertex in vertices:
						var p: Vector3 = t * (vertex as Vector3)
						if absf(p.x) > float(bounds[0]) + RecordedThrows.CONTAIN_EPS or p.z < float(bounds[1]) - RecordedThrows.CONTAIN_EPS or p.z > float(bounds[2]) + RecordedThrows.CONTAIN_EPS:
							contained = false
					var n: Vector3 = RecordedThrows.normalize_origin(t.origin, bounds)
					var q: Quaternion = t.basis.orthonormalized().get_rotation_quaternion()
					var f: Array = [n.x, n.y, n.z, q.x, q.y, q.z, q.w]
					if not track.frames.is_empty():
						track.distance += t.origin.distance_to(track.previous)
					track["previous"] = t.origin
					track.frames.append(f.map(func(v): return snappedf(float(v), 0.000001)))
					if die.freeze:
						track.finished = true
						track["landed_raw"] = tray._get_most_visible_face_value(die)
				await physics_frame
			if not contained:
				discarded_total += 1
				print("[THROW_RECORDER] enemies=%d attempt=%d DISCARDED: a die left the tray" % [enemy_count, attempts])
				continue
			for key in tracks:
				var track: Dictionary = tracks[key]
				var seconds: float = (track.frames.size() - 1) / float(Engine.physics_ticks_per_second)
				measurements.append({"enemy_count": enemy_count, "slot": key, "distance": track.distance, "seconds": seconds})
				if kept >= VARIANTS:
					continue
				var record: Dictionary = {"version": RecordedThrows.FORMAT_VERSION, "physics_hz": Engine.physics_ticks_per_second,
					"space": "tray_normalized", "inner_margin": RecordedThrows.INNER_MARGIN,
					"recorded_tray": {"window": [WINDOW.x, WINDOW.y], "tray_px": [tray.size.x, tray.size.y], "bounds": bounds},
					"landed_raw": track.landed_raw, "distance": track.distance,
					"seconds": seconds, "frames": track.frames}
				record["impacts"] = impacts.get(key, [])
				var path: String = "%s/%d_%d_%s.json" % [OUT, enemy_count, kept, str(key).replace(":", "_")]
				var file := FileAccess.open(path, FileAccess.WRITE)
				file.store_string(JSON.stringify(record) + "\n")
			kept += 1
			kept_total += 1
			print("[THROW_RECORDER] enemies=%d kept=%d (attempt %d)" % [enemy_count, kept, attempts])
		if kept < VARIANTS * 2:
			print("[THROW_RECORDER] FAIL: only %d contained throws for %d enemies" % [kept, enemy_count])
			quit(1)
			return
	var metrics := FileAccess.open(OUT + "/live_measurements.json", FileAccess.WRITE)
	metrics.store_string(JSON.stringify(measurements, "\t") + "\n")
	print("[THROW_RECORDER] PASS: %d contained live throws kept, %d discarded; %d saved die tracks, %d measured" % [kept_total, discarded_total, VARIANTS * (3 + 1 + 3 + 2 + 3 + 4), measurements.size()])
	quit()
