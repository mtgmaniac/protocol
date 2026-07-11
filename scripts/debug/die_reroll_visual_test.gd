# Headless regression for §2 (Batch 4): after an enemy die is rerolled (Phase
# Scrambler / Cascade Jammer), the 3D die's numeral must match the new roll — not
# only the card pips.
# Run: godot --headless --path . -s scripts/debug/die_reroll_visual_test.gd
# Repro (manual): roll → use Phase Scrambler on an enemy → the enemy's die number
# and its ability pips both show the new roll (before this fix the number stayed
# on the pre-reroll value).
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SQUAD := ["combat", "engineer", "medic"]

var _errors: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[DIE_REROLL] Starting enemy-reroll die-numeral regression")
	var gs: Node = root.get_node("/root/GameState")
	var dm: Node = root.get_node("/root/DataManager")
	gs.call("start_run", SQUAD, str(dm.call("get_operation_order")[0]))
	gs.call("advance_to_next_battle")
	change_scene_to_file(BATTLE_SCENE)
	var retries := 180
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE:
			break
	await create_timer(1.0).timeout

	var roll_button: Button = current_scene.get_node_or_null("%RollButton") as Button
	if roll_button != null and roll_button.visible and not roll_button.disabled:
		var tray: Node = current_scene.get_node_or_null("%DiceTray3D")
		roll_button.emit_signal("pressed")
		if tray != null and tray.has_signal("roll_finished"):
			await tray.roll_finished
		else:
			await create_timer(2.0).timeout
	await create_timer(0.4).timeout

	var tray3d: Node = current_scene.get("dice_tray_3d")
	var enemy_states: Array = current_scene.get("combat_manager").call("get_enemy_states")
	var picked: Dictionary = {}
	for es_v in enemy_states:
		var es: Dictionary = es_v
		if not bool(es.get("dead", false)) and int(es.get("die_freeze_turns", 0)) == 0:
			var id: String = str(es.get("id", ""))
			if (current_scene.get("enemy_rolls") as Dictionary).has(id):
				picked = es
				break
	if picked.is_empty():
		_errors.append("no living enemy with a die to test")
		_finish()
		return

	var eid: String = str(picked.get("id", ""))
	var die: Object = tray3d.call("_get_die_for_entry", "enemy", eid)
	if die == null:
		_errors.append("no 3D die node for enemy " + eid)
		_finish()
		return

	var enemy_rolls: Dictionary = current_scene.get("enemy_rolls")
	var raw0: int = int(enemy_rolls[eid])
	var numeral_before: int = int(die.get_meta("display_face_value", -1))

	# Simulate the reroll landing on a guaranteed-different face, WITHOUT syncing.
	var new_raw: int = (raw0 % 20) + 1
	enemy_rolls[eid] = new_raw
	var stale_numeral: int = int(die.get_meta("display_face_value", -1))
	_expect(stale_numeral == numeral_before, "numeral is stale until synced (the bug): %d" % stale_numeral)

	# Now run the fix.
	current_scene.call("sync_enemy_dice_after_item_reroll", "enemyRerollDie", picked)
	var numeral_after: int = int(die.get_meta("display_face_value", -1))
	var expected: int = int(current_scene.call("_get_effective_enemy_roll", picked, eid))
	_expect(numeral_after == expected, "numeral matches new effective roll after sync (got %d, want %d)" % [numeral_after, expected])
	_expect(numeral_after != stale_numeral or new_raw == raw0, "numeral changed to the new roll (was %d, now %d)" % [stale_numeral, numeral_after])

	_finish()


func _expect(cond: bool, label: String) -> void:
	if not cond:
		_errors.append(label)


func _finish() -> void:
	if _errors.is_empty():
		print("[DIE_REROLL] PASS — enemy die numeral tracks the reroll")
	else:
		for e in _errors:
			print("[DIE_REROLL] FAIL: " + e)
	quit(0 if _errors.is_empty() else 1)
