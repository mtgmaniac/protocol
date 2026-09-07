extends "res://debug_artifacts/visual_motion.gd"

func run() -> void:
	await process_frame
	root.get_node("SaveManager").call("set_setting", "ability_primers_enabled", false)
	var gs: Node = root.get_node("GameState")
	gs.call("start_run", ["shield", "avalanche", "pulse"], "facility")
	gs.call("advance_to_next_battle")
	change_scene_to_file("res://scenes/battle/BattleScene.tscn")
	await create_timer(1.0).timeout
	var battle: Node = current_scene
	var tray: Node = battle.get_node("%DiceTray3D")
	var rigged: Dictionary = {}
	for side in ["hero", "enemy"]:
		var views: Array = battle.get(side + "_card_views")
		for i in views.size():
			var id: String = str((views[i]["state"] as Dictionary)["id"])
			rigged[side+":"+id] = [18, 9, 20][i] if side == "hero" else 7
	tray.call("set_rigged_results", rigged)
	battle.get_node("%RollButton").emit_signal("pressed")
	await tray.roll_finished
	await create_timer(0.6).timeout
	for i in 3:
		var pending: Array = battle.get("pending_manual_target_ids")
		if pending.is_empty(): break
		battle.call("_select_targeting_hero", str(pending[0]))
		await process_frame
		var ids: Array = battle.get("legal_target_ids")
		if ids.is_empty(): break
		battle.call("_assign_target_to_active_hero", str(ids[0]), str(battle.get("legal_target_side")))
		await process_frame
	await create_timer(0.2).timeout
	await shot("round_ready")
	battle.get_node("%RollButton").emit_signal("pressed")
	await series("round", 100, 0.07)
	var previous: Array = JSON.parse_string(FileAccess.get_file_as_string(out + "timing.json"))
	previous.append_array(records)
	FileAccess.open(out + "timing.json", FileAccess.WRITE).store_string(JSON.stringify(previous))
	quit()
