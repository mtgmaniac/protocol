# Jam die-numeral regression (Build G item 2): the 3D die face shows the
# JAMMED (capped) value, not the raw roll — the same cap get_effective_roll
# applies, fed through the dice-tray entry dict (`jam_cap`). This is the value
# feed only; the fenced dice materials / SubViewport pipeline is untouched.
#
#   • jammed die: raw 17 under cap 10 displays 10.
#   • under-cap roll: raw 8 under cap 10 stays 8 (cap is a ceiling, not a set).
#   • buff interaction: raw 9 with +3 buff under cap 10 displays 10 (buffed 12
#     capped), mods first, then cap.
#   • the tray has no private copy of the rule (the die reads the one source).
# Run: godot --headless --path . -s scripts/debug/jam_display_test.gd
extends SceneTree

var _errors: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_errors.append(label)


func _initialize() -> void:
	await process_frame
	# P0 dice-face audit: the tray no longer keeps its own copy of the
	# effective-roll rule (_display_face_for_entry is deleted). It reads the
	# die value from battle_scene._die_value -> BattleEngine effective roll ->
	# CombatManager.get_effective_roll. The cases below pin the jam cap at that
	# one source; dice_face_gate.gd pins the die numeral against it.
	var TrayScript: GDScript = load("res://scripts/battle/dice_tray_3d.gd")
	_check(TrayScript.source_code.find("func _display_face_for_entry") < 0 and TrayScript.source_code.find("roll_buff") < 0 and TrayScript.source_code.find("roll_rfe") < 0,
		"the tray keeps no copy of the effective-roll rule")

	# The one source: combat state -> get_effective_roll.
	var dm: Node = root.get_node("/root/DataManager")
	var hero: UnitData = dm.call("get_unit", "combat") as UnitData
	var CombatManagerScript: GDScript = load("res://scripts/battle/combat_manager.gd")
	var cm: Object = CombatManagerScript.new()
	var enemy: EnemyData = dm.call("get_enemy_by_display_name", "Scrap Drone") as EnemyData
	if hero == null or enemy == null:
		push_error("[JAM_DISPLAY] could not load units")
		print("[JAM_DISPLAY] FAIL - unit load")
		quit(1)
		return
	cm.call("setup_battle", [hero], [enemy.duplicate(true)])
	var st: Dictionary = cm.call("get_hero_states")[0]
	cm.call("_apply_jam", st)
	_check(int(st.get("jam_cap", 0)) == 10, "combat jam stores the cap on state")
	_check(int(cm.call("get_effective_roll", st, 17)) == 10,
		"jammed die displays the capped value (17 -> 10)")
	_check(int(cm.call("get_effective_roll", st, 8)) == 8,
		"a roll under the cap is unchanged (8 stays 8)")
	cm.call("apply_item_roll_buff", st, 3, 1)
	_check(int(cm.call("get_effective_roll", st, 9)) == 10,
		"buffs apply before the cap (9 +3 -> 12 -> 10)")
	# CombatManager is RefCounted — no free; it drops with the last reference.

	if _errors.is_empty():
		print("[JAM_DISPLAY] PASS")
		quit(0)
	else:
		for e in _errors:
			push_error("[JAM_DISPLAY] " + e)
		print("[JAM_DISPLAY] FAIL - %d check(s)" % _errors.size())
		quit(1)
