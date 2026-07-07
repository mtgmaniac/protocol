# Headless probe: evolution portrait resolution (portrait wiring pass 2026-07-07).
# Run: <godot> --headless --path . -s scripts/debug/evolution_portrait_probe.gd
# Positive: every hero/evo pair resolves to its file. Negative: an unknown evo
# id returns null (silent base fallback). Evolved run unit carries the swap.
extends SceneTree


func _initialize() -> void:
	# Autoloads only join the tree after the first frame (the documented -s
	# gotcha — see the other smoke tests).
	await process_frame
	var failures: Array = []
	var dm: Node = root.get_node("/root/DataManager")
	var gs: Node = root.get_node("/root/GameState")

	var pair_count: int = 0
	for unit_id_variant in ["pulse", "combat", "shield", "avalanche", "medic", "engineer", "ghost", "breaker"]:
		var unit_id: String = str(unit_id_variant)
		var unit = dm.call("get_unit", unit_id)
		for path_variant in unit.get("evolution_paths"):
			var path: Dictionary = path_variant
			var evo_id: String = str(path.get("id", ""))
			if evo_id == "":
				failures.append("%s path '%s' has no id" % [unit_id, str(path.get("name", ""))])
				continue
			pair_count += 1
			if dm.call("get_evolution_portrait", unit_id, evo_id) == null:
				failures.append("%s/%s did not resolve" % [unit_id, evo_id])
	if pair_count != 16:
		failures.append("expected 16 hero/evo pairs, saw %d" % pair_count)

	if dm.call("get_evolution_portrait", "pulse", "no_such_evo") != null:
		failures.append("unknown evo id should return null")
	if dm.call("get_evolution_portrait", "pulse", "") != null:
		failures.append("empty evo id should return null")

	# Evolved run unit swaps its portrait; unevolved keeps the base texture.
	gs.call("start_run", ["combat", "avalanche", "medic"], "facility")
	var base_portrait = gs.call("get_run_unit_data", "combat").get("portrait")
	gs.get("unit_evolutions")["combat"] = "Bladecore"
	var evolved_portrait = gs.call("get_run_unit_data", "combat").get("portrait")
	if evolved_portrait == null or evolved_portrait == base_portrait:
		failures.append("evolved run unit did not swap to the Bladecore portrait")

	if failures.is_empty():
		print("[EVO_PORTRAIT] PASS — 16/16 resolve, fallback silent, run-unit swap live")
	else:
		for failure_variant in failures:
			print("[EVO_PORTRAIT] FAIL — %s" % str(failure_variant))
	quit(0 if failures.is_empty() else 1)
