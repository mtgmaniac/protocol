extends SceneTree

const Plan := preload("res://scripts/battle/tutorial_roll_plan.gd")
var failures: Array[String] = []
var break_kind := ""
var injected := false
var measured: Array = []

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--break="):
			break_kind = arg.trim_prefix("--break=")
	call_deferred("run")

func check(ok: bool, why: String) -> void:
	if not ok and failures.size() < 20:
		failures.append(why)

func labels(die: Node) -> Array:
	var out: Array = []
	for value in range(1, 21):
		out.append(die.get_node("Visuals/FaceNumber%d" % value).text)
	return out

func run() -> void:
	var live: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorial_throws/live_measurements.json"))
	var gs = root.get_node("GameState")
	for battle in [1, 2]:
		gs.start_run(["combat", "engineer" if battle == 1 else "pulse", "medic"], "facility", 27092026, true)
		gs.current_battle = battle
		change_scene_to_file("res://scenes/battle/BattleScene.tscn")
		await create_timer(0.8).timeout
		var scene: Node = current_scene
		var tray: Node = scene.dice_tray_3d
		for round_number in ([1, 2] if battle == 1 else [1]):
			scene._tutorial_turn = round_number - 1
			scene._begin_targeting_phase()
			while not bool(tray._is_rolling):
				await process_frame
			var watches: Dictionary = {}
			while bool(tray._is_rolling):
				for key in tray._die_by_key:
					var die: RigidBody3D = tray._die_by_key[key]
					var entry: Dictionary = die.get_meta("entry")
					var track: Dictionary = die.get_meta("recorded_track", {})
					check(not track.is_empty(), "scripted throw has a recording")
					if track.is_empty():
						continue
					if not watches.has(key):
						watches[key] = {"labels": labels(die), "previous": die.position, "distance": 0.0, "ticks": 0, "done": false}
						var bounds: Array = track.bounds
						check(absf(float(bounds[0]) - float(tray._bounds_half_width)) < 0.01 and absf(float(bounds[1]) - float(tray._bounds_min_z)) < 0.01 and absf(float(bounds[2]) - float(tray._bounds_max_z)) < 0.01, "recorded tray bounds match the live tutorial")
					var watch: Dictionary = watches[key]
					if bool(watch.done):
						continue
					if break_kind == "labels" and not injected and int(watch.ticks) > 2:
						die.get_node("Visuals/FaceNumber1").text = "99"
						injected = true
					check(labels(die) == watch.labels, "labels changed during recorded playback")
					watch.distance += die.position.distance_to(watch.previous)
					watch.previous = die.position
					watch.ticks += 1
					if not bool(die.get_meta("busy", false)):
						watch.done = true
						var slot: String = "%s:%s%d" % [entry.side, "h" if entry.side == "hero" else "e", int(entry.slot_index)]
						var samples: Array = live.filter(func(m): return int(m.enemy_count) == battle and str(m.slot) == slot)
						var distances: Array = samples.map(func(m): return float(m.distance))
						var times: Array = samples.map(func(m): return float(m.seconds))
						var seconds: float = (int(watch.ticks) - 1) / float(Engine.physics_ticks_per_second)
						check(float(watch.distance) >= float(distances.min()) - 0.02 and float(watch.distance) <= float(distances.max()) + 0.02, "playback travel outside measured live range: " + slot)
						check(seconds >= float(times.min()) - 0.05 and seconds <= float(times.max()) + 0.05, "playback settle time outside measured live range: " + slot)
						measured.append({"battle": battle, "round": round_number, "slot": slot, "seconds": seconds, "distance": watch.distance})
				await physics_frame
			await process_frame
			var requests: Dictionary = Plan.heroes(battle, round_number)
			for side in ["hero", "enemy"]:
				var states: Array = scene.combat_manager.get_hero_states() if side == "hero" else scene.combat_manager.get_enemy_states()
				for state in states:
					var want: int = int(requests[str(state.unit.id)]) if side == "hero" else 6
					var die: RigidBody3D = tray._get_die_for_entry(side, str(state.id))
					if break_kind == "top" and not injected:
						die.get_node("Visuals/FaceNumber%d" % want).text = "99"
						injected = true
					check(tray.up_face_numeral(side, str(state.id)) == want, "scripted top face differs from requested value")
					var rolls: Dictionary = scene.hero_rolls if side == "hero" else scene.enemy_rolls
					check(int(rolls[str(state.id)]) == want, "landed value did not reach combat")
		# Free round must use real launch and preserve the actual raw landing.
		scene._tutorial_turn = 2 if battle == 1 else 1
		var launched: int = tray.thrown_dice_total
		await scene._begin_targeting_phase()
		check(int(tray.thrown_dice_total) == launched + 3 + battle, "free tutorial round launches every die")
		for side in ["hero", "enemy"]:
			var rolls: Dictionary = scene.hero_rolls if side == "hero" else scene.enemy_rolls
			for uid in rolls:
				check(int(rolls[uid]) == int(tray._get_most_visible_face_value(tray._get_die_for_entry(side, uid))), "free landing overwritten")
		# The conditional reminder must follow actual living/burning state.
		var controller: Node = null
		for child in scene.get_children():
			if child.has_method("_has_living_burned_enemy"):
				controller = child
		if controller != null:
			var enemy: Dictionary = scene.combat_manager.get_enemy_states()[0]
			enemy.burn_stacks = [{"amount": 2, "turns_left": 1}]
			check(controller._has_living_burned_enemy(), "living Burn reminder")
			enemy.dead = true
			check(not controller._has_living_burned_enemy(), "dead enemy omits Burn reminder")
			enemy.dead = false
			enemy.burn_stacks = []
			check(not controller._has_living_burned_enemy(), "cleared Burn omits reminder")
	for problem in failures:
		print("[TUTORIAL_THROWS] FAIL: ", problem)
	var file := FileAccess.open("res://debug_artifacts/tutorial_playback_measurements.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(measured, "\t") + "\n")
	check(break_kind == "" or injected, "requested mutation was injected")
	print("[TUTORIAL_THROWS] ", "PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
