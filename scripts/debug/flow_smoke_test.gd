# Walks the post-refactor scene flow and fails if any transition throws or stalls.
# Run: godot --path <project> --script res://scripts/debug/flow_smoke_test.gd
extends SceneTree

const HOME_SCENE := "res://scenes/ui/UnitSelect.tscn"
const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const REWARD_SCENE := "res://scenes/ui/RewardScreen.tscn"
const EVOLUTION_SCENE := "res://scenes/ui/EvolutionScreen.tscn"
const RUN_END_SCENE := "res://scenes/ui/RunEndScreen.tscn"
const ROUTE_FORK_SCENE := "res://scenes/ui/RouteForkScreen.tscn"
const INTERCEPT_SCENE := "res://scenes/ui/InterceptScreen.tscn"
const DEFAULT_SQUAD := ["pulse", "combat", "shield"]
const STEP_TIMEOUT_SECS := 120.0

var _errors: Array[String] = []
var _step: int = 0


func _initialize() -> void:
	call_deferred("_run_flow")


func _run_flow() -> void:
	print("[FLOW_SMOKE] Starting full scene-flow smoke test")
	await _step_home_boot()
	await _step_home_begin_run()
	await _step_battle_auto_win_to_reward()
	await _step_reward_back_to_home()
	await _step_home_begin_run_again()
	await _step_battle_auto_win_to_reward()
	await _step_reward_claim_and_continue()
	await _step_evolution_back_to_home()
	await _step_directive_choice()
	await _step_route_fork()
	await _step_intercept()
	await _step_main_menu_to_home()
	await _step_run_end_new_run_button()

	if _errors.is_empty():
		print("[FLOW_SMOKE] PASS — all transitions completed with no logged errors")
		quit(0)
	else:
		for err in _errors:
			push_error("[FLOW_SMOKE] " + err)
		print("[FLOW_SMOKE] FAIL — %d error(s)" % _errors.size())
		quit(1)


func _step_home_boot() -> void:
	_step += 1
	print("[FLOW_SMOKE] Step %d: boot home screen" % _step)
	await _goto(HOME_SCENE)
	await _wait_frames(3)
	var scene := _current()
	if scene == null:
		_errors.append("Home scene failed to load")
		return
	if scene.get_script() == null or not str(scene.get_script().resource_path).ends_with("home_screen.gd"):
		_errors.append("UnitSelect.tscn root script is not home_screen.gd (got %s)" % scene.get_script())
	await _select_home_squad(scene)


func _step_home_begin_run() -> void:
	_step += 1
	print("[FLOW_SMOKE] Step %d: home -> battle" % _step)
	var scene := _current()
	if scene != null and scene.has_method("_on_begin_run_pressed"):
		scene.call("_on_begin_run_pressed")
	else:
		_start_run_and_go_battle()
	await _wait_for_scene(BATTLE_SCENE)


func _step_battle_auto_win_to_reward() -> void:
	_step += 1
	print("[FLOW_SMOKE] Step %d: battle auto-win -> reward" % _step)
	var battle := _current()
	if battle == null:
		_errors.append("Battle scene missing before auto-win")
		return
	if battle.has_method("_on_auto_battle_button_pressed"):
		battle.call("_on_auto_battle_button_pressed")
	else:
		_errors.append("Battle scene lacks _on_auto_battle_button_pressed")
		return
	var landed := await _wait_for_any_scene([REWARD_SCENE, RUN_END_SCENE], STEP_TIMEOUT_SECS)
	if landed == "":
		_errors.append("Battle did not route to reward or run-end within timeout")


func _step_reward_back_to_home() -> void:
	_step += 1
	print("[FLOW_SMOKE] Step %d: reward -> home (back button)" % _step)
	if _scene_path() != REWARD_SCENE:
		print("[FLOW_SMOKE] Skipping reward back — current scene is %s" % _scene_path())
		return
	var reward := _current()
	if reward.has_method("_on_return_to_menu_button_pressed"):
		reward.call("_on_return_to_menu_button_pressed")
	else:
		_game_state().call("reset_run")
		_scene_manager().call("go_to_unit_select")
	await _wait_for_scene(HOME_SCENE)
	await _wait_frames(2)


func _step_home_begin_run_again() -> void:
	_step += 1
	print("[FLOW_SMOKE] Step %d: home -> battle (second run)" % _step)
	await _select_home_squad(_current())
	var scene := _current()
	if scene != null and scene.has_method("_on_begin_run_pressed"):
		scene.call("_on_begin_run_pressed")
	await _wait_for_scene(BATTLE_SCENE)


func _step_reward_claim_and_continue() -> void:
	_step += 1
	print("[FLOW_SMOKE] Step %d: battle win -> reward claim -> next screen" % _step)
	if _scene_path() == BATTLE_SCENE:
		var battle := _current()
		if battle != null and battle.has_method("_on_auto_battle_button_pressed"):
			battle.call("_on_auto_battle_button_pressed")
		var landed := await _wait_for_any_scene([REWARD_SCENE, RUN_END_SCENE], STEP_TIMEOUT_SECS)
		if landed == "":
			_errors.append("Second battle did not route to reward within timeout")
			return
	if _scene_path() != REWARD_SCENE:
		print("[FLOW_SMOKE] Not on reward after second battle — at %s" % _scene_path())
		return
	var gs := _game_state()
	var items: Array = gs.call("get_pending_reward_items")
	if items.is_empty():
		gs.call("prepare_battle_rewards")
		items = gs.call("get_pending_reward_items")
	if items.is_empty():
		_errors.append("No pending reward items to claim")
		return
	var item: ItemData = _pick_claimable_item(items)
	if item == null:
		_errors.append("No claimable reward item found")
		return
	var target_unit_id := ""
	if item.item_type == "gear":
		target_unit_id = str(gs.get("selected_units")[0])
	if not bool(gs.call("claim_reward", item.id, target_unit_id)):
		_errors.append("Failed to claim reward item %s" % item.id)
		return
	gs.call("award_battle_xp")
	if bool(gs.call("has_pending_evolution")):
		_scene_manager().call("go_to_evolution")
		await _wait_for_scene(EVOLUTION_SCENE)
		var evolution := _current()
		if evolution != null and evolution.has_method("_on_return_to_menu_button_pressed"):
			evolution.call("_on_return_to_menu_button_pressed")
		await _wait_for_scene(HOME_SCENE)
		return
	gs.call("advance_to_next_battle")
	_scene_manager().call("go_to_battle")
	await _wait_for_scene(BATTLE_SCENE)


# Route Fork beat (pkg7.3): a forced fork after battle 2 shows the two route
# cards; taking the flagged route arms the modifier and deploys to battle.
func _step_route_fork() -> void:
	_step += 1
	print("[FLOW_SMOKE] Step %d: forced fork beat -> flagged route -> battle" % _step)
	var gs := _game_state()
	var op_id: String = str(_data_manager().call("get_operation_order")[0])
	gs.call("start_run", DEFAULT_SQUAD, op_id)
	gs.set("current_battle", 2)
	gs.get("run_beats").clear()
	gs.get("run_beats")[2] = {"type": "fork", "tier": "minor"}
	gs.get("consumed_beats").clear()
	_scene_manager().call("go_to_next_battle_or_beat")
	await _wait_for_scene(ROUTE_FORK_SCENE)
	var fork := _current()
	if fork == null or not fork.has_method("_on_route_chosen"):
		_errors.append("Route fork screen failed to load")
		return
	fork.call("_on_route_chosen", true)
	await _wait_for_scene(BATTLE_SCENE)
	if (gs.get("used_battle_modifiers") as Array).is_empty():
		_errors.append("Flagged route did not consume a modifier")
		return
	if int(gs.get("current_battle")) != 3:
		_errors.append("Fork did not advance to battle 3")
		return
	await _wait_frames(2)


# Intercept beat (pkg7.4): a forced intercept after battle 2 draws a card;
# taking the second (skip/alternative) choice resolves and deploys to battle.
func _step_intercept() -> void:
	_step += 1
	print("[FLOW_SMOKE] Step %d: forced intercept beat -> resolve -> battle" % _step)
	var gs := _game_state()
	var op_id: String = str(_data_manager().call("get_operation_order")[0])
	gs.call("start_run", DEFAULT_SQUAD, op_id)
	gs.set("current_battle", 2)
	gs.get("run_beats").clear()
	gs.get("run_beats")[2] = {"type": "intercept", "tier": "minor"}
	gs.get("consumed_beats").clear()
	var deck_before: int = (gs.get("intercept_minor_deck") as Array).size()
	_scene_manager().call("go_to_next_battle_or_beat")
	await _wait_for_scene(INTERCEPT_SCENE)
	var intercept := _current()
	if intercept == null or not intercept.has_method("_on_choice_pressed"):
		_errors.append("Intercept screen failed to load")
		return
	if (gs.get("intercept_minor_deck") as Array).size() != deck_before - 1:
		_errors.append("Intercept card was not drawn without replacement")
		return
	# Resolve via the card's second (skip/alternative) choice, then continue.
	var card: Dictionary = (gs.get("INTERCEPT_CARDS") as Dictionary).get(intercept.get("_card_id"), {})
	var choices: Array = card.get("choices", [])
	if choices.size() < 2:
		_errors.append("Intercept card has no skip choice")
		return
	var skip_choice: Dictionary = choices[1]
	if str(skip_choice.get("pick", "")) != "" or not (skip_choice.get("draft", {}) as Dictionary).is_empty():
		skip_choice = choices[0] if str((choices[0] as Dictionary).get("pick", "")) == "" else {"label": "skip", "effects": []}
	intercept.call("_on_choice_pressed", skip_choice)
	await _wait_frames(2)
	if intercept.has_method("_continue_to_battle"):
		intercept.call("_continue_to_battle")
	await _wait_for_scene(BATTLE_SCENE)
	if int(gs.get("current_battle")) != 3:
		_errors.append("Intercept did not advance to battle 3")
		return
	await _wait_frames(2)


# Forced 250-XP path (pkg6): an evolved unit at the directive threshold gets
# the 1-of-2 Directive screen; picking one applies it and deploys to battle.
func _step_directive_choice() -> void:
	_step += 1
	print("[FLOW_SMOKE] Step %d: forced 250-XP directive pick -> battle" % _step)
	var gs := _game_state()
	var op_id: String = str(_data_manager().call("get_operation_order")[0])
	gs.call("start_run", DEFAULT_SQUAD, op_id)
	gs.call("advance_to_next_battle")
	var unit_id: String = DEFAULT_SQUAD[0]
	var unit = _data_manager().call("get_unit", unit_id)
	var evolution_name: String = str((unit.get("evolution_paths")[0] as Dictionary).get("name", ""))
	gs.get("unit_evolutions")[unit_id] = evolution_name
	gs.get("unit_xp")[unit_id] = 250
	gs.set("pending_evolution_unit_id", unit_id)
	if not bool(gs.call("is_pending_directive_stage")):
		_errors.append("Directive stage not detected for evolved unit at 250 XP")
		return
	_scene_manager().call("go_to_evolution")
	await _wait_for_scene(EVOLUTION_SCENE)
	var screen := _current()
	if screen == null or not screen.has_method("_on_choose_directive_pressed"):
		_errors.append("Evolution screen missing the directive choose handler")
		return
	var choices: Array = gs.call("get_pending_directive_choices")
	if choices.size() != 2:
		_errors.append("Expected 2 directive choices, got %d" % choices.size())
		return
	var pick_name: String = str((choices[0] as Dictionary).get("name", ""))
	screen.call("_on_choose_directive_pressed", pick_name)
	await _wait_for_scene(BATTLE_SCENE)
	if str(gs.get("unit_directives").get(unit_id, "")) != pick_name:
		_errors.append("Directive '%s' was not applied to %s" % [pick_name, unit_id])
		return
	await _wait_frames(2)


func _step_evolution_back_to_home() -> void:
	_step += 1
	print("[FLOW_SMOKE] Step %d: evolution -> home (back button)" % _step)
	var gs := _game_state()
	var op_id: String = str(_data_manager().call("get_operation_order")[0])
	gs.call("start_run", DEFAULT_SQUAD, op_id)
	gs.call("advance_to_next_battle")
	gs.get("unit_xp")[DEFAULT_SQUAD[0]] = 100
	gs.set("pending_evolution_unit_id", DEFAULT_SQUAD[0])
	_scene_manager().call("go_to_evolution")
	await _wait_for_scene(EVOLUTION_SCENE)
	var evolution := _current()
	if evolution == null:
		_errors.append("Evolution scene failed to load")
		return
	if evolution.has_method("_on_return_to_menu_button_pressed"):
		evolution.call("_on_return_to_menu_button_pressed")
	else:
		_errors.append("Evolution screen missing _on_return_to_menu_button_pressed")
		return
	await _wait_for_scene(HOME_SCENE)
	await _wait_frames(2)


func _step_main_menu_to_home() -> void:
	_step += 1
	print("[FLOW_SMOKE] Step %d: main menu -> home" % _step)
	await _goto(MAIN_MENU_SCENE)
	await _wait_frames(2)
	var menu := _current()
	if menu == null:
		_errors.append("Main menu failed to load")
		return
	if menu.has_method("_on_start_run_pressed"):
		menu.call("_on_start_run_pressed")
	else:
		_scene_manager().call("go_to_unit_select")
	await _wait_for_scene(HOME_SCENE)
	await _wait_frames(2)


func _step_run_end_new_run_button() -> void:
	_step += 1
	print("[FLOW_SMOKE] Step %d: run-end (victory) -> home (new run button)" % _step)
	var gs := _game_state()
	var op_id: String = str(_data_manager().call("get_operation_order")[0])
	gs.call("start_run", DEFAULT_SQUAD, op_id)
	gs.set("current_battle", gs.get("total_battles"))
	gs.call("finish_run", "victory")
	_scene_manager().call("go_to_run_end")
	await _wait_for_scene(RUN_END_SCENE)
	await _wait_frames(2)
	var run_end := _current()
	if run_end == null:
		_errors.append("Run end scene failed to load")
		return
	if run_end.has_method("_on_new_run_button_pressed"):
		run_end.call("_on_new_run_button_pressed")
	else:
		_errors.append("Run end missing _on_new_run_button_pressed")
		return
	await _wait_for_scene(HOME_SCENE)
	await _wait_frames(2)

	_step += 1
	print("[FLOW_SMOKE] Step %d: run-end (defeat) -> home (new run button)" % _step)
	gs.call("start_run", DEFAULT_SQUAD, op_id)
	gs.call("finish_run", "defeat")
	_scene_manager().call("go_to_run_end")
	await _wait_for_scene(RUN_END_SCENE)
	await _wait_frames(2)
	run_end = _current()
	if run_end != null and run_end.has_method("_on_new_run_button_pressed"):
		run_end.call("_on_new_run_button_pressed")
	await _wait_for_scene(HOME_SCENE)


func _start_run_and_go_battle() -> void:
	var gs := _game_state()
	var op_id: String = str(_data_manager().call("get_operation_order")[0])
	gs.call("start_run", DEFAULT_SQUAD, op_id)
	gs.call("advance_to_next_battle")
	_scene_manager().call("go_to_battle")


func _pick_claimable_item(items: Array) -> ItemData:
	for item_variant in items:
		var item: ItemData = item_variant as ItemData
		if item == null:
			continue
		if item.item_type == "gear":
			continue
		return item
	for item_variant in items:
		var item: ItemData = item_variant as ItemData
		if item != null:
			return item
	return null


func _select_home_squad(scene: Node) -> void:
	if scene == null:
		return
	if scene.has_method("_toggle_unit_selection"):
		for unit_id in DEFAULT_SQUAD:
			scene.call("_toggle_unit_selection", unit_id)
	if scene.has_method("_refresh_unit_thumbs"):
		scene.call("_refresh_unit_thumbs")
	if scene.has_method("_refresh_squad_counter"):
		scene.call("_refresh_squad_counter")
	if scene.has_method("_refresh_begin_button"):
		scene.call("_refresh_begin_button")
	await _wait_frames(2)


func _goto(path: String) -> void:
	change_scene_to_file(path)
	await _wait_for_scene(path)


func _wait_for_scene(path: String, timeout_secs: float = STEP_TIMEOUT_SECS) -> bool:
	var frames_left := int(timeout_secs * 60.0)
	while frames_left > 0:
		frames_left -= 1
		await process_frame
		if _scene_path() == path:
			await _wait_frames(2)
			return true
	_errors.append("Timed out waiting for scene %s (last=%s)" % [path, _scene_path()])
	return false


func _wait_for_any_scene(paths: Array, timeout_secs: float) -> String:
	var frames_left := int(timeout_secs * 60.0)
	while frames_left > 0:
		frames_left -= 1
		await process_frame
		for path_variant in paths:
			var path: String = str(path_variant)
			if _scene_path() == path:
				await _wait_frames(2)
				return path
	return ""


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _current() -> Node:
	return current_scene


func _scene_path() -> String:
	var scene := _current()
	if scene == null:
		return "<null>"
	return str(scene.scene_file_path)


func _game_state() -> Node:
	return root.get_node("/root/GameState")


func _scene_manager() -> Node:
	return root.get_node("/root/SceneManager")


func _data_manager() -> Node:
	return root.get_node("/root/DataManager")
