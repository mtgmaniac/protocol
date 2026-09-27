extends SceneTree

# Dev-only recorder. Calls the live tray's play_rolls with NO rig and samples
# body transforms at physics-frame boundaries, ending before upright snapping.
const OUT := "res://data/tutorial_throws"
const VARIANTS := 4
var measurements: Array = []
var impacts: Dictionary = {}
var launch_frame: int = 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var gs = root.get_node("GameState")
	gs.start_run(["combat", "engineer", "medic"], "facility", 27092026)
	change_scene_to_file("res://scenes/battle/BattleScene.tscn")
	await create_timer(0.8).timeout
	var scene: Node = current_scene
	var tray: Node = scene.dice_tray_3d
	tray.recording_impact.connect(func(key: String, speed: float):
		if not impacts.has(key):
			impacts[key] = []
		impacts[key].append([Engine.get_physics_frames() - launch_frame, snappedf(speed, 0.001)]))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for enemy_count in [1, 2, 4]:
		var heroes: Array = []
		var enemies: Array = []
		for index in 3:
			heroes.append({"id": "h%d" % index})
		for index in enemy_count:
			enemies.append({"id": "e%d" % index})
		for variant in VARIANTS * 2:
			impacts.clear()
			launch_frame = Engine.get_physics_frames()
			tray.set_rigged_results({})
			tray.play_rolls(heroes, enemies)
			var tracks: Dictionary = {}
			while bool(tray._is_rolling):
				for key in tray._die_by_key:
					var die: RigidBody3D = tray._die_by_key[key]
					if not tracks.has(key):
						tracks[key] = {"frames": [], "finished": false, "distance": 0.0}
					var track: Dictionary = tracks[key]
					if bool(track.finished):
						continue
					var t: Transform3D = die.global_transform
					var q: Quaternion = t.basis.orthonormalized().get_rotation_quaternion()
					var f: Array = [t.origin.x, t.origin.y, t.origin.z, q.x, q.y, q.z, q.w]
					if not track.frames.is_empty():
						var prev: Array = track.frames.back()
						track.distance += t.origin.distance_to(Vector3(prev[0], prev[1], prev[2]))
					track.frames.append(f.map(func(v): return snappedf(float(v), 0.000001)))
					if die.freeze:
						track.finished = true
						track["landed_raw"] = tray._get_most_visible_face_value(die)
				await physics_frame
			for key in tracks:
				var track: Dictionary = tracks[key]
				var seconds: float = (track.frames.size() - 1) / float(Engine.physics_ticks_per_second)
				measurements.append({"enemy_count": enemy_count, "slot": key, "distance": track.distance, "seconds": seconds})
				if variant >= VARIANTS:
					continue
				var record: Dictionary = {"version": 1, "physics_hz": Engine.physics_ticks_per_second,
					"bounds": [tray._bounds_half_width, tray._bounds_min_z, tray._bounds_max_z],
					"landed_raw": track.landed_raw, "distance": track.distance,
					"seconds": seconds, "frames": track.frames}
				record["impacts"] = impacts.get(key, [])
				var path: String = "%s/%d_%d_%s.json" % [OUT, enemy_count, variant, str(key).replace(":", "_")]
				var file := FileAccess.open(path, FileAccess.WRITE)
				file.store_string(JSON.stringify(record) + "\n")
			print("[THROW_RECORDER] enemies=%d variant=%d bounds=%s" % [enemy_count, variant, str([tray._bounds_half_width, tray._bounds_min_z, tray._bounds_max_z])])
	var metrics := FileAccess.open(OUT + "/live_measurements.json", FileAccess.WRITE)
	metrics.store_string(JSON.stringify(measurements, "\t") + "\n")
	print("[THROW_RECORDER] PASS: 24 real launches, 64 saved die tracks, 128 measured die tracks")
	quit()
