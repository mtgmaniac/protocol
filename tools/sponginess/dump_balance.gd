# Combat-sponginess benchmark (2026-09) — MEASUREMENT ONLY, not a gate.
# Dumps the combat model exactly as DataManager loaded it at runtime (the
# authority over the raw JSON / docs) so the offline model and the report read
# live values: hero kits (base + evolutions), every enemy of the requested
# faction with its role and zone kit, the op's battle templates and role pools,
# and the boss standing rules.
#
#   godot --headless --path . -s res://tools/sponginess/dump_balance.gd -- \
#       --out <abs path>.json [--op facility]
extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _arg(name: String, fallback: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size() - 1):
		if args[i] == name:
			return args[i + 1]
	return fallback


func _ranges(dice_ranges: Array) -> Array:
	var out: Array = []
	for entry_variant in dice_ranges:
		var entry: Dictionary = entry_variant
		out.append({
			"zone": str(entry.get("zone", "")),
			"min": int(entry.get("min", entry.get("range_min", 0))),
			"max": int(entry.get("max", entry.get("range_max", 0))),
			"name": str(entry.get("ability_name", "")),
			"raw": entry.get("raw", {}),
			"all": entry,
		})
	return out


func _run() -> void:
	await process_frame
	var dm: Node = root.get_node("DataManager")
	# Loaded at runtime: combat_manager.gd references the DataManager autoload,
	# which a -s script cannot resolve at its own compile time.
	var cm_script: GDScript = load("res://scripts/battle/combat_manager.gd")
	var op_id: String = _arg("--op", "facility")
	var out_path: String = _arg("--out", "")
	var heroes: Dictionary = {}
	for unit_id in (dm.get("units") as Dictionary).keys():
		var unit: UnitData = dm.call("get_unit", str(unit_id)) as UnitData
		var evos: Array = []
		for path_variant in unit.evolution_paths:
			var path: Dictionary = path_variant
			evos.append({
				"name": str(path.get("name", "")),
				"hp": int(path.get("hp", path.get("max_hp", 0))),
				"abilities": _ranges(path.get("abilities", [])),
			})
		heroes[str(unit_id)] = {"name": unit.display_name, "hp": unit.max_hp, "base": _ranges(unit.dice_ranges), "evolutions": evos}
	var enemies: Dictionary = {}
	for enemy_variant in (dm.get("enemies") as Dictionary).values():
		var enemy: EnemyData = enemy_variant as EnemyData
		if enemy == null or enemy.faction != op_id:
			continue
		var rule: String = str(cm_script.call("get_boss_standing_rule", enemy.display_name))
		enemies[enemy.display_name] = {
			"hp": enemy.max_hp,
			"ai": enemy.ai_type,
			"type": enemy.enemy_type,
			"targeting": enemy.targeting,
			"role": "boss" if rule != "" else str(dm.call("_classify_enemy_role", enemy)),
			"standing_rule": rule,
			"traits": enemy.traits,
			"zones": _ranges(enemy.dice_ranges),
		}
	var op: Resource = dm.call("get_operation", op_id)
	var pools: Dictionary = (dm.get("enemy_role_pools") as Dictionary).get(op_id, {})
	var payload: Dictionary = {
		"op": op_id,
		"heroes": heroes,
		"enemies": enemies,
		"role_pools": pools,
		"operation": inst_to_dict(op) if op != null else {},
	}
	var text: String = JSON.stringify(payload, "  ")
	if out_path != "":
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		file.store_string(text)
		file.close()
		print("[DUMP] wrote %s (%d heroes, %d enemies)" % [out_path, heroes.size(), enemies.size()])
	else:
		print(text)
	quit(0)
