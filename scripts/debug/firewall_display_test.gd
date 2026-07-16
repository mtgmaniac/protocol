# Firewall visibility regression (Build G item 11, ruled): an armed firewall
# reads at the PORTRAIT tier — the compact card docks a FirewallBadge to the
# portrait corner whenever state.warded is true, independent of the 3-chip
# priority contest that buried the chip in the +N overflow. Break/expiry
# clears it on the standard refresh (the ward/block events rebuild the card).
#
#   • warded unit shows the badge (hero and enemy side alike).
#   • clearing warded on a refresh hides it (expiry regression).
#   • a dead unit never shows it.
#   • combat authority: _apply_ward sets warded, _ward_blocks_hostile consumes
#     it (block-then-break, one ability).
# Run: godot --headless --path . -s scripts/debug/firewall_display_test.gd
extends SceneTree

var _errors: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_errors.append(label)


func _initialize() -> void:
	await process_frame
	var CardScript: GDScript = load("res://scripts/ui/compact_unit_card.gd")
	var card: Control = CardScript.new()
	root.add_child(card)
	await process_frame

	var base: Dictionary = {"side": "hero", "name": "TEST", "current_hp": 10, "max_hp": 10}
	card.call("configure", base.merged({"warded": true}, true))
	var badge: Node = card.find_child("FirewallBadge", true, false)
	_check(badge != null, "card builds the FirewallBadge node")
	_check(badge != null and (badge as CanvasItem).visible, "warded unit shows the firewall badge")

	card.call("configure", base.merged({"warded": false}, true))
	_check(badge != null and not (badge as CanvasItem).visible, "expiry clears the firewall badge")

	card.call("configure", base.merged({"warded": true, "dead": true}, true))
	_check(badge != null and not (badge as CanvasItem).visible, "a dead unit never shows the badge")

	card.queue_free()

	# Combat authority: ward arms on _apply_ward and is consumed by the next
	# hostile ability (state side of the same display contract).
	var dm: Node = root.get_node("/root/DataManager")
	var hero: UnitData = dm.call("get_unit", "combat") as UnitData
	var enemy: EnemyData = dm.call("get_enemy_by_display_name", "Scrap Drone") as EnemyData
	if hero == null or enemy == null:
		push_error("[FIREWALL_DISPLAY] could not load units")
		print("[FIREWALL_DISPLAY] FAIL - unit load")
		quit(1)
		return
	var CombatManagerScript: GDScript = load("res://scripts/battle/combat_manager.gd")
	var cm: Object = CombatManagerScript.new()
	cm.call("setup_battle", [hero], [enemy.duplicate(true)])
	var st: Dictionary = cm.call("get_hero_states")[0]
	cm.call("_apply_ward", st)
	_check(bool(st.get("warded", false)), "_apply_ward arms the warded state")
	_check(bool(cm.call("_ward_blocks_hostile", st)), "the next hostile ability is blocked")
	_check(not bool(st.get("warded", false)), "the firewall breaks after blocking (expiry)")
	# CombatManager is RefCounted — no free; it drops with the last reference.

	if _errors.is_empty():
		print("[FIREWALL_DISPLAY] PASS")
		quit(0)
	else:
		for e in _errors:
			push_error("[FIREWALL_DISPLAY] " + e)
		print("[FIREWALL_DISPLAY] FAIL - %d check(s)" % _errors.size())
		quit(1)
