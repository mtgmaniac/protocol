# Launches a predictable battle, captures the rendered viewport to disk, and exits.
extends SceneTree

const DEFAULT_OUTPUT := "res://debug_artifacts/battle_ui/latest.png"
const DEFAULT_OPERATION_ID := "facility"
const DEFAULT_BATTLE_NUMBER := 1
const DEFAULT_CAPTURE_DELAY_MS := 1200
const DEFAULT_SQUAD := ["shield", "avalanche", "pulse"]
const DEFAULT_CAPTURE_ROLLED := false
const DEFAULT_CAPTURE_LOCK_TARGETS := 0


func _initialize() -> void:
	call_deferred("_run_capture")


func _run_capture() -> void:
	var config: Dictionary = _parse_args()
	_prepare_run(config)
	change_scene_to_file("res://scenes/battle/BattleScene.tscn")
	await _wait_for_battle_scene(config)
	var output_path: String = str(config.get("output", DEFAULT_OUTPUT))
	var absolute_output: String = _resolve_output_path(output_path)
	var save_result: Error = _capture_viewport_to_file(absolute_output)
	if save_result != OK:
		push_error("Battle UI capture failed: %s" % error_string(save_result))
		quit(1)
		return
	print("[BATTLE_UI_CAPTURE] Saved screenshot to: %s" % absolute_output)
	quit(0)


func _parse_args() -> Dictionary:
	var config := {
		"output": DEFAULT_OUTPUT,
		"operation_id": DEFAULT_OPERATION_ID,
		"battle_number": DEFAULT_BATTLE_NUMBER,
		"delay_ms": DEFAULT_CAPTURE_DELAY_MS,
		"rolled": DEFAULT_CAPTURE_ROLLED,
		"lock_targets": DEFAULT_CAPTURE_LOCK_TARGETS,
	}
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--capture-output="):
			config["output"] = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-operation="):
			config["operation_id"] = arg.get_slice("=", 1)
		elif arg.begins_with("--capture-battle="):
			config["battle_number"] = maxi(int(arg.get_slice("=", 1)), 1)
		elif arg.begins_with("--capture-delay-ms="):
			config["delay_ms"] = maxi(int(arg.get_slice("=", 1)), 100)
		elif arg == "--capture-rolled":
			config["rolled"] = true
		elif arg.begins_with("--capture-lock-targets="):
			config["lock_targets"] = maxi(int(arg.get_slice("=", 1)), 0)
			config["rolled"] = true
		elif arg == "--capture-force-auto":
			config["force_auto"] = true
			config["rolled"] = true
		elif arg == "--capture-debug-log":
			config["debug_log"] = true
		elif arg == "--capture-enemy-shield":
			# After rolling, give the first enemy an active shield stack and
			# force the first pending hero to target that enemy. Used to
			# visually verify shield preview behaviour.
			config["enemy_shield"] = true
			config["rolled"] = true
		elif arg == "--capture-enemy-rolls-shield":
			# After rolling, force the first enemy's roll value down to 1
			# (which maps to their shield-self recharge ability), reapply
			# enemy targeting, and have the first pending hero target them.
			# Used to verify planning-shield does NOT show blue.
			config["enemy_rolls_shield"] = true
			config["rolled"] = true
		elif arg.begins_with("--capture-pick-mode="):
			# After targets are locked, simulate pressing the reroll, nudge,
			# or item button so the scene enters the matching *_pick sub-phase.
			# Used to verify that damage preview persists across these picks.
			config["pick_mode"] = arg.get_slice("=", 1)
		elif arg == "--capture-inspect-hero":
			config["inspect"] = "hero"
		elif arg == "--capture-inspect-enemy":
			config["inspect"] = "enemy"
	return config


func _prepare_run(config: Dictionary) -> void:
	var operation_id: String = str(config.get("operation_id", DEFAULT_OPERATION_ID))
	_game_state().start_run(DEFAULT_SQUAD, operation_id)
	var battle_number: int = int(config.get("battle_number", DEFAULT_BATTLE_NUMBER))
	for _i in range(battle_number):
		_game_state().advance_to_next_battle()


func _wait_for_battle_scene(config: Dictionary) -> void:
	var delay_ms: int = int(config.get("delay_ms", DEFAULT_CAPTURE_DELAY_MS))
	var retries := 120
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/battle/BattleScene.tscn":
			break
	await create_timer(float(delay_ms) / 1000.0).timeout
	var debug_log_enabled: bool = bool(config.get("debug_log", false))
	if bool(config.get("rolled", DEFAULT_CAPTURE_ROLLED)):
		await _capture_after_roll(debug_log_enabled)
	var lock_count: int = int(config.get("lock_targets", DEFAULT_CAPTURE_LOCK_TARGETS))
	if lock_count > 0:
		await _lock_n_targets(lock_count)
	if bool(config.get("force_auto", false)):
		await _force_auto_target_first_hero()
	if bool(config.get("enemy_shield", false)):
		await _force_enemy_shield_scenario()
	if bool(config.get("enemy_rolls_shield", false)):
		await _force_enemy_rolls_shield_scenario()
	var pick_mode: String = str(config.get("pick_mode", ""))
	if pick_mode != "":
		await _force_pick_mode(pick_mode)
	var inspect_side: String = str(config.get("inspect", ""))
	if inspect_side != "":
		_open_inspect(inspect_side)
		await process_frame
		await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	if debug_log_enabled:
		_print_target_state("final")


# Opens the unified InspectPopup on the first hero/enemy card, exercising the live
# _on_unit_detail_requested path (Stage-2 migration verification).
func _open_inspect(side: String) -> void:
	if current_scene == null:
		return
	var key: String = "hero_card_views" if side == "hero" else "enemy_card_views"
	var views: Variant = current_scene.get(key)
	if not (views is Array) or (views as Array).is_empty():
		return
	var card: Node = ((views as Array)[0] as Dictionary).get("card")
	if card != null and current_scene.has_method("_on_unit_detail_requested"):
		current_scene.call("_on_unit_detail_requested", card)


func _force_pick_mode(mode: String) -> void:
	if current_scene == null:
		return
	var battle: Node = current_scene
	# Grant a generous protocol pool so the gating in _on_*_button_pressed
	# doesn't bail out early.
	if "protocol_points" in battle:
		battle.set("protocol_points", 10)
	var method_name := ""
	match mode:
		"reroll":
			method_name = "_on_reroll_button_pressed"
		"nudge":
			method_name = "_on_nudge_button_pressed"
		"item":
			# Items need a real ItemData; just set the phase directly to
			# PHASE_ITEM_PICK_ENEMY to mimic an enemy-target item being chosen.
			if battle.has_method("_set_turn_phase"):
				battle.call("_set_turn_phase", "item_pick_enemy")
			await process_frame
			return
	if method_name != "" and battle.has_method(method_name):
		battle.call(method_name)
		await process_frame


func _capture_after_roll(debug_log_enabled: bool = false) -> void:
	if current_scene == null:
		return
	var roll_button: Button = current_scene.get_node_or_null("%RollButton") as Button
	if roll_button == null or roll_button.disabled or not roll_button.visible:
		return
	var dice_tray: Node = current_scene.get_node_or_null("%DiceTray3D")
	roll_button.emit_signal("pressed")
	if dice_tray != null and dice_tray.has_signal("roll_finished"):
		await dice_tray.roll_finished
	else:
		await create_timer(2.0).timeout
	await create_timer(0.4).timeout
	if debug_log_enabled:
		_print_target_state("post-roll")


func _print_target_state(tag: String) -> void:
	if current_scene == null:
		return
	var battle: Node = current_scene
	var phase: String = str(battle.get("turn_phase"))
	var lines: PackedStringArray = []
	var pending_ids: Array = battle.get("pending_manual_target_ids")
	lines.append("[CAPTURE_DEBUG][%s] turn_phase=%s pending=%s" % [tag, phase, str(pending_ids)])
	var hero_views: Array = battle.get("hero_card_views")
	if hero_views != null:
		for view_variant in hero_views:
			var view: Dictionary = view_variant
			var state: Dictionary = view.get("state", {})
			var unit_name: String = ""
			var unit_resource: Resource = state.get("unit", null) as Resource
			if unit_resource != null and unit_resource.has_method("battle_name"):
				unit_name = str(unit_resource.call("battle_name"))
			var card: Node = view.get("card", null)
			var card_mod: Color = Color.WHITE
			var card_target_locked: bool = false
			if card != null:
				card_mod = card.modulate
				card_target_locked = bool(card.get("target_locked"))
			lines.append("  hero=%s id=%s display=%s sel_id=%s card.target_locked=%s card.modulate=%s" % [
				unit_name,
				str(state.get("id", "?")),
				str(state.get("target_display", "?")),
				str(state.get("selected_target_id", "?")),
				str(card_target_locked),
				str(card_mod),
			])
	var log_path: String = ProjectSettings.globalize_path("res://debug_artifacts/battle_ui/capture_debug.log")
	var f: FileAccess = FileAccess.open(log_path, FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE)
	if f == null:
		f = FileAccess.open(log_path, FileAccess.WRITE)
	if f != null:
		f.seek_end()
		for line in lines:
			f.store_line(line)
		f.close()


func _force_enemy_rolls_shield_scenario() -> void:
	if current_scene == null:
		return
	var battle: Node = current_scene
	var enemy_views: Array = battle.get("enemy_card_views")
	if enemy_views == null or enemy_views.is_empty():
		return
	var first_enemy_view: Dictionary = enemy_views[0]
	var enemy_state: Dictionary = first_enemy_view.get("state", {})
	if enemy_state.is_empty():
		return
	var enemy_id: String = str(enemy_state.get("id", ""))
	# Force roll to 1 — scrap_drone's recharge (shield 8, 2t) sits in the low
	# roll band per data inspection.
	var enemy_rolls: Dictionary = battle.get("enemy_rolls")
	if enemy_rolls != null:
		enemy_rolls[enemy_id] = 1
	_force_log("enemy_rolls_shield: forced enemy %s roll to 1" % enemy_id)
	# Have first pending hero target this enemy so damage preview triggers.
	var pending: Array = battle.get("pending_manual_target_ids")
	if pending != null and not pending.is_empty():
		for hero_id_variant in pending.duplicate():
			var hero_id: String = str(hero_id_variant)
			if not battle.has_method("_select_targeting_hero"):
				break
			battle.call("_select_targeting_hero", hero_id)
			await process_frame
			var legal_ids: Array = battle.get("legal_target_ids")
			var legal_side: String = str(battle.get("legal_target_side"))
			if legal_side == "enemy" and legal_ids != null and legal_ids.has(enemy_id):
				battle.call("_assign_target_to_active_hero", enemy_id, "enemy")
				await process_frame
				_force_log("enemy_rolls_shield: assigned %s -> %s" % [hero_id, enemy_id])
				break
	if battle.has_method("_refresh_all_cards"):
		battle.call("_refresh_all_cards")
	await process_frame


func _force_enemy_shield_scenario() -> void:
	if current_scene == null:
		return
	var battle: Node = current_scene
	var enemy_views: Array = battle.get("enemy_card_views")
	if enemy_views == null or enemy_views.is_empty():
		return
	var first_enemy_view: Dictionary = enemy_views[0]
	var enemy_state: Dictionary = first_enemy_view.get("state", {})
	if enemy_state.is_empty():
		return
	var stacks: Array = enemy_state.get("shield_stacks", [])
	stacks.append({"amt": 12, "turns_left": 2, "skip_next_tick": false})
	enemy_state["shield_stacks"] = stacks
	enemy_state["shield"] = 12
	var enemy_id: String = str(enemy_state.get("id", ""))
	_force_log("enemy_shield: granted 12 shield to enemy id=%s" % enemy_id)
	var pending: Array = battle.get("pending_manual_target_ids")
	if pending == null or pending.is_empty():
		_force_log("enemy_shield: no pending heroes to target")
		if battle.has_method("_refresh_all_cards"):
			battle.call("_refresh_all_cards")
		await process_frame
		return
	# Find a pending hero whose ability targets enemies.
	var assigned: bool = false
	for hero_id_variant in pending.duplicate():
		var hero_id: String = str(hero_id_variant)
		if not battle.has_method("_select_targeting_hero"):
			break
		battle.call("_select_targeting_hero", hero_id)
		await process_frame
		var legal_ids: Array = battle.get("legal_target_ids")
		var legal_side: String = str(battle.get("legal_target_side"))
		_force_log("enemy_shield: hero=%s legal_side=%s legal_ids=%s" % [hero_id, legal_side, str(legal_ids)])
		if legal_side == "enemy" and legal_ids != null and legal_ids.has(enemy_id):
			battle.call("_assign_target_to_active_hero", enemy_id, "enemy")
			await process_frame
			assigned = true
			_force_log("enemy_shield: assigned %s -> %s" % [hero_id, enemy_id])
			break
	if not assigned:
		_force_log("enemy_shield: no hero could target enemy %s" % enemy_id)
	if battle.has_method("_refresh_all_cards"):
		battle.call("_refresh_all_cards")
	await process_frame


func _force_log(message: String) -> void:
	var log_path: String = ProjectSettings.globalize_path("res://debug_artifacts/battle_ui/capture_debug.log")
	var f: FileAccess = FileAccess.open(log_path, FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE)
	if f == null:
		f = FileAccess.open(log_path, FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_line(message)
		f.close()


func _force_auto_target_first_hero() -> void:
	if current_scene == null:
		return
	var battle: Node = current_scene
	var hero_views: Array = battle.get("hero_card_views")
	if hero_views == null or hero_views.is_empty():
		return
	var first_view: Dictionary = hero_views[0]
	var state: Dictionary = first_view.get("state", {})
	if state.is_empty():
		return
	state["selected_target_id"] = ""
	state["target_display"] = "All Squad"
	var pending: Array = battle.get("pending_manual_target_ids")
	if pending != null:
		pending.erase(str(state.get("id", "")))
	if battle.has_method("_refresh_all_cards"):
		battle.call("_refresh_all_cards")
	await process_frame


func _lock_n_targets(count: int) -> void:
	if current_scene == null:
		return
	var battle: Node = current_scene
	if not battle.has_method("_select_targeting_hero") or not battle.has_method("_assign_target_to_active_hero"):
		return
	for _i in range(count):
		var pending: Array = battle.get("pending_manual_target_ids")
		if pending == null or pending.is_empty():
			break
		var hero_id: String = str(pending[0])
		battle.call("_select_targeting_hero", hero_id)
		await process_frame
		var active: String = str(battle.get("active_targeting_hero_id"))
		if active == "":
			break
		var legal_ids: Array = battle.get("legal_target_ids")
		var legal_side: String = str(battle.get("legal_target_side"))
		if legal_ids == null or legal_ids.is_empty():
			break
		var target_id: String = str(legal_ids[0])
		battle.call("_assign_target_to_active_hero", target_id, legal_side)
		await process_frame
	await create_timer(0.2).timeout


func _resolve_output_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path


func _capture_viewport_to_file(absolute_output: String) -> Error:
	var directory: String = absolute_output.get_base_dir()
	var make_dir_result: Error = DirAccess.make_dir_recursive_absolute(directory)
	if make_dir_result != OK:
		return make_dir_result
	var image: Image = root.get_texture().get_image()
	if image == null:
		return ERR_CANT_ACQUIRE_RESOURCE
	return image.save_png(absolute_output)


func _game_state() -> Node:
	return root.get_node("/root/GameState")
