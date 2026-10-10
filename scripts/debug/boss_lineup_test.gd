# Boss lineup gate (G-70, Kev 2026-10-10).
#
#   godot --headless --path . -s scripts/debug/boss_lineup_test.gd [-- --lineup-break=elite_boss]
#
# No lineup modifier may replace or remove a boss. Three things change who a
# battle fields: OVERRUN (adds a unit), ELITE PRESENCE (replaces one; armed by
# a flagged fork or by Prisoner Exchange's follow-up) and Prisoner Exchange's
# "one fewer enemy". Pinned here:
#   A. data     every operation ends on a battle that fields exactly one boss,
#               and no boss is in a role pool a modifier draws from.
#   B. shaper   every modifier, on every battle of every operation over five
#               seeds, and on made-up lineups with the boss in each slot: the
#               bosses that went in come out.
#   C. elite    ELITE PRESENCE upgrades the first unit that is neither an
#               elite nor a boss; with no such unit it is not offered and does
#               not arm.
#   D. exchange Prisoner Exchange taken before battle 9 (the report's case):
#               battle 9 fields one fewer unit, battle 10 still fields its
#               boss, on every operation.
#   E. minus    "one fewer enemy" never drops a boss, drops exactly one unit
#               otherwise, and leaves a lone unit alone.
#   F. one rule the live battle and the sim both ask GameState for the lineup;
#               neither trims it itself.
# scripts/checks/break_gate.py reruns it with each GameState LINEUP_BREAK_ARG
# mode (elite_boss, minus_boss) and requires a FAIL.
extends SceneTree

const SEEDS := [7, 1001, 40404, 987654, 2026]
const SQUAD := ["combat", "engineer", "medic"]
const LINEUP_READERS := ["res://scripts/battle/battle_scene.gd", "res://scripts/sim/sim_runner.gd"]

var _errors: PackedStringArray = []
var _gs: Node
var _dm: Node


func _initialize() -> void:
	call_deferred("_run")


func _expect(ok: bool, what: String) -> void:
	if not ok and _errors.size() < 40:
		_errors.append(what)


func _run() -> void:
	await process_frame
	_gs = root.get_node("/root/GameState")
	_dm = root.get_node("/root/DataManager")
	var boss_by_op: Dictionary = _check_data()
	_check_shaper(boss_by_op)
	_check_elite_presence(boss_by_op)
	_check_prisoner_exchange(boss_by_op)
	_check_minus_one(boss_by_op)
	_check_one_rule()
	for error in _errors:
		print("[BOSS_LINEUP] FAIL - %s" % error)
	print("[BOSS_LINEUP] %s" % ("PASS" if _errors.is_empty() else "FAIL - %d check(s)" % _errors.size()))
	root.get_node("/root/SaveManager").clear_run_save()
	quit(0 if _errors.is_empty() else 1)


func _bosses(names: Array) -> Array:
	return _gs.call("boss_names_in", names)


func _start(op_id: String, seed_value: int) -> Array:
	_gs.call("start_run", SQUAD, op_id, seed_value)
	return _gs.get("resolved_battle_comps")


# A. Every operation's last battle fields one boss; no pool holds a boss.
func _check_data() -> Dictionary:
	var boss_by_op: Dictionary = {}
	for op_variant in _dm.call("get_operation_order"):
		var op_id: String = str(op_variant)
		var comps: Array = _start(op_id, SEEDS[0])
		var last: Array = (comps.back() as Dictionary).get("names", []) if not comps.is_empty() else []
		var bosses: Array = _bosses(last)
		_expect(bosses.size() == 1, "%s: the last battle fields exactly one boss (got %s)" % [op_id, str(last)])
		if bosses.size() == 1:
			boss_by_op[op_id] = str(bosses[0])
		for role in ["fodder", "elite", "support", "heavy"]:
			_expect(_bosses(_dm.call("get_role_pool", op_id, role)).is_empty(), "%s: no boss in the %s pool" % [op_id, role])
	_expect(boss_by_op.size() == 5, "five operations, five bosses (got %d)" % boss_by_op.size())
	return boss_by_op


# B. Every modifier keeps every boss, on real and made-up lineups.
func _check_shaper(boss_by_op: Dictionary) -> void:
	var modifier_ids: Array = (_gs.BATTLE_MODIFIERS as Dictionary).keys()
	var shaped_boss_comps: int = 0
	for op_variant in boss_by_op:
		var op_id: String = str(op_variant)
		var boss: String = str(boss_by_op[op_id])
		var fodder: Array = _dm.call("get_role_pool", op_id, "fodder")
		var elites: Array = _dm.call("get_role_pool", op_id, "elite")
		var filler: String = str(fodder[0]) if not fodder.is_empty() else ""
		var elite: String = str(elites[0]) if not elites.is_empty() else ""
		for seed_value in SEEDS:
			var lineups: Array = []
			for comp_variant in _start(op_id, seed_value):
				lineups.append(((comp_variant as Dictionary).get("names", []) as Array).duplicate())
			# The boss in each slot, beside a regular unit, an elite, and alone.
			lineups.append_array([[boss], [boss, filler], [filler, boss], [elite, boss], [boss, elite],
				[filler, boss, filler], [elite, elite, boss], [boss, filler, elite]])
			for names_variant in lineups:
				var names: Array = names_variant
				for modifier_variant in modifier_ids:
					var modifier_id: String = str(modifier_variant)
					var shaped: Dictionary = _gs.call("_shape_comp_for_modifier", modifier_id, {"names": names.duplicate(), "cloaked": []})
					var after: Array = shaped.get("names", [])
					if not _bosses(names).is_empty():
						shaped_boss_comps += 1
					_expect(_bosses(after) == _bosses(names),
						"%s on %s %s keeps its boss (became %s)" % [modifier_id, op_id, str(names), str(after)])
					_expect(after.size() >= names.size(), "%s on %s %s removes no unit (became %s)" % [modifier_id, op_id, str(names), str(after)])
	_expect(shaped_boss_comps > 0, "the shaper was asked about a boss lineup at least once")


# C. ELITE PRESENCE: first unit that is neither an elite nor a boss.
func _check_elite_presence(boss_by_op: Dictionary) -> void:
	for op_variant in boss_by_op:
		var op_id: String = str(op_variant)
		var boss: String = str(boss_by_op[op_id])
		_start(op_id, SEEDS[0])
		var elites: Array = _dm.call("get_role_pool", op_id, "elite")
		var fodder: Array = _dm.call("get_role_pool", op_id, "fodder")
		if elites.is_empty() or fodder.is_empty():
			continue
		var elite: String = str(elites[0])
		var filler: String = str(fodder[0])
		# Boss first, then a regular unit: the regular unit is the one upgraded.
		var shaped: Array = (_gs.call("_shape_comp_for_modifier", "elitePresence", {"names": [boss, filler], "cloaked": []}) as Dictionary).get("names", [])
		_expect(shaped.size() == 2 and str(shaped[0]) == boss and elites.has(str(shaped[1])),
			"%s: ELITE PRESENCE on [boss, regular] upgrades the regular unit (got %s)" % [op_id, str(shaped)])
		# Nothing left to upgrade: not offered, and the lineup is untouched.
		_expect(not bool(_gs.call("_modifier_precondition_ok", "elitePresence", [elite, boss])),
			"%s: ELITE PRESENCE is not offered on [elite, boss]" % op_id)
		_expect(not bool(_gs.call("_modifier_precondition_ok", "elitePresence", [boss])),
			"%s: ELITE PRESENCE is not offered on a lone boss" % op_id)
		var untouched: Array = (_gs.call("_shape_comp_for_modifier", "elitePresence", {"names": [elite, boss], "cloaked": []}) as Dictionary).get("names", [])
		_expect(untouched == [elite, boss], "%s: ELITE PRESENCE leaves [elite, boss] alone (got %s)" % [op_id, str(untouched)])
		# Still offered where it has a slot.
		_expect(bool(_gs.call("_modifier_precondition_ok", "elitePresence", [boss, filler])),
			"%s: ELITE PRESENCE is still offered on [boss, regular]" % op_id)


# D. Prisoner Exchange taken at the last beat that offers it (after battle 8).
func _check_prisoner_exchange(boss_by_op: Dictionary) -> void:
	var card: Dictionary = (_gs.INTERCEPT_CARDS as Dictionary).get("prisonerExchange", {})
	var release: Array = ((card.get("choices", []) as Array)[0] as Dictionary).get("effects", []) if not card.is_empty() else []
	_expect(release.size() == 2, "Prisoner Exchange's release choice has its two effects")
	for op_variant in boss_by_op:
		var op_id: String = str(op_variant)
		var boss: String = str(boss_by_op[op_id])
		for seed_value in SEEDS:
			var comps: Array = _start(op_id, seed_value)
			var battle_nine: Array = ((comps[8] as Dictionary).get("names", []) as Array).duplicate()
			_gs.set("current_battle", 8)
			_gs.call("apply_intercept_effects", release)
			# Battle 9 starts: it fields one fewer unit, then the follow-up arms.
			_gs.set("current_battle", 9)
			var fielded_nine: Array = _gs.call("lineup_for_battle", battle_nine)
			_expect(fielded_nine.size() == maxi(battle_nine.size() - 1, 1) and _bosses(fielded_nine) == _bosses(battle_nine),
				"%s seed %d: battle 9 fields one fewer unit and no boss is lost (%s -> %s)" % [op_id, seed_value, str(battle_nine), str(fielded_nine)])
			(_gs.get("next_battle_effects") as Dictionary).clear()
			_gs.call("promote_followup_effects")
			# Battle 10: whatever ELITE PRESENCE did, the boss is there.
			_gs.set("next_battle_modifier", "")
			_gs.set("current_battle", 10)
			var fielded_ten: Array = _gs.call("lineup_for_battle", (_gs.call("get_current_battle_comp") as Dictionary).get("names", []))
			_expect(fielded_ten.has(boss), "%s seed %d: the boss fight after Prisoner Exchange still fields %s (got %s)" % [op_id, seed_value, boss, str(fielded_ten)])


# E. "One fewer enemy" never takes a boss.
func _check_minus_one(boss_by_op: Dictionary) -> void:
	for op_variant in boss_by_op:
		var op_id: String = str(op_variant)
		var boss: String = str(boss_by_op[op_id])
		var fodder: Array = _dm.call("get_role_pool", op_id, "fodder")
		var filler: String = str(fodder[0]) if not fodder.is_empty() else "Scrap Drone"
		var cases: Array = [
			[[filler, boss], [boss]], [[boss, filler], [boss]], [[filler, boss, filler], [filler, boss]],
			[[filler, filler, boss], [filler, boss]], [[boss], [boss]], [[filler], [filler]],
			[[filler, filler], [filler]],
		]
		for case_variant in cases:
			var before: Array = (case_variant as Array)[0]
			var want: Array = (case_variant as Array)[1]
			var got: Array = _gs.call("lineup_minus_one", before)
			_expect(got == want, "%s: one fewer enemy on %s is %s (got %s)" % [op_id, str(before), str(want), str(got)])
		# The real boss fight, as rolled.
		var last: Array = (_start(op_id, SEEDS[1]).back() as Dictionary).get("names", [])
		_expect((_gs.call("lineup_minus_one", last) as Array).has(boss), "%s: one fewer enemy keeps the boss of %s" % [op_id, str(last)])
	# Armed or not: lineup_for_battle only trims while the effect is armed.
	_start("facility", SEEDS[0])
	_expect((_gs.call("lineup_for_battle", ["Scrap Drone", "Rust Drone"]) as Array).size() == 2, "an unarmed battle fields its whole lineup")
	(_gs.get("next_battle_effects") as Dictionary)["minus_one_enemy"] = true
	_expect((_gs.call("lineup_for_battle", ["Scrap Drone", "Rust Drone"]) as Array) == ["Scrap Drone"], "an armed battle fields one fewer")
	(_gs.get("next_battle_effects") as Dictionary).clear()


# F. Nobody but GameState trims a lineup.
func _check_one_rule() -> void:
	for path in LINEUP_READERS:
		var source: String = FileAccess.get_file_as_string(path)
		_expect(source.contains("lineup_for_battle"), "%s asks GameState for the battle's lineup" % path)
		_expect(not source.contains("minus_one_enemy\", false)"), "%s does not read minus_one_enemy itself" % path)
		_expect(not source.contains("enemy_names.remove_at("), "%s does not drop a unit itself" % path)
