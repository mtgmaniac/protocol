# Jam die-numeral regression (Build G item 2): the 3D die face shows the
# JAMMED (capped) value, not the raw roll — the same cap get_effective_roll
# applies, fed through the dice-tray entry dict (`jam_cap`). This is the value
# feed only; the fenced dice materials / SubViewport pipeline is untouched.
#
#   • jammed die: raw 17 under cap 10 displays 10.
#   • under-cap roll: raw 8 under cap 10 stays 8 (cap is a ceiling, not a set).
#   • buff interaction: raw 9 with +3 buff under cap 10 displays 10 (buffed 12
#     capped), matching get_effective_roll's order (mods first, then cap).
#   • frozen die: keeps its raw face — freeze wins (a frozen die can't be
#     altered, NK-03; jam bounces off frozen in combat_manager).
#   • unjammed regression: no cap in the entry leaves the display unchanged.
#   • feed regression: battle-scene entries carry jam_cap from combat state.
# Run: godot --headless --path . -s scripts/debug/jam_display_test.gd
extends SceneTree

var _errors: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_errors.append(label)


func _initialize() -> void:
	await process_frame
	var TrayScript: GDScript = load("res://scripts/battle/dice_tray_3d.gd")
	var tray: Object = TrayScript.new()

	# _display_face_for_entry is the ONE reveal-numeral value feed.
	_check(int(tray.call("_display_face_for_entry", 17, {"jam_cap": 10})) == 10,
		"jammed die displays the capped value (17 -> 10)")
	_check(int(tray.call("_display_face_for_entry", 8, {"jam_cap": 10})) == 8,
		"a roll under the cap is unchanged (8 stays 8)")
	_check(int(tray.call("_display_face_for_entry", 9, {"roll_buff": 3, "jam_cap": 10})) == 10,
		"buffs apply before the cap (9 +3 -> 12 -> 10)")
	_check(int(tray.call("_display_face_for_entry", 17, {"frozen": true, "jam_cap": 10})) == 17,
		"a frozen die keeps its face - jam never alters it")
	_check(int(tray.call("_display_face_for_entry", 17, {})) == 17,
		"unjammed regression: no cap leaves the numeral raw")
	_check(int(tray.call("_display_face_for_entry", 17, {"jam_cap": 0})) == 17,
		"cap 0 means no jam (sentinel respected)")
	tray.call("free")

	# The battle scene feeds jam_cap from combat state into every entry.
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
		"effective roll caps at the jam value (combat authority)")
	# CombatManager is RefCounted — no free; it drops with the last reference.

	if _errors.is_empty():
		print("[JAM_DISPLAY] PASS")
		quit(0)
	else:
		for e in _errors:
			push_error("[JAM_DISPLAY] " + e)
		print("[JAM_DISPLAY] FAIL - %d check(s)" % _errors.size())
		quit(1)
