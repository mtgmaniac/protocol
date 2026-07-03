# Plays one FULL run headless (pkg7 gate): auto-battles through all 10
# battles of the first operation, claiming rewards, resolving evolutions,
# directives, route forks, and intercepts as they surface.
# Run: godot --headless --path <project> --script res://scripts/debug/run_smoke_test.gd
extends SceneTree

const HOME_SCENE := "res://scenes/ui/UnitSelect.tscn"
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const REWARD_SCENE := "res://scenes/ui/RewardScreen.tscn"
const EVOLUTION_SCENE := "res://scenes/ui/EvolutionScreen.tscn"
const RUN_END_SCENE := "res://scenes/ui/RunEndScreen.tscn"
const ROUTE_FORK_SCENE := "res://scenes/ui/RouteForkScreen.tscn"
const INTERCEPT_SCENE := "res://scenes/ui/InterceptScreen.tscn"
const DEFAULT_SQUAD := ["pulse", "combat", "shield"]
const STEP_TIMEOUT_SECS := 180.0
const MAX_TRANSITIONS := 80

var _errors: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[RUN_SMOKE] Playing one full run of the first operation")
	var gs := _game_state()
	var op_id: String = str(_data_manager().call("get_operation_order")[0])
	gs.call("start_run", DEFAULT_SQUAD, op_id)
	gs.call("advance_to_next_battle")
	_scene_manager().call("go_to_battle")
	await _wait_for_scene(BATTLE_SCENE)

	var transitions: int = 0
	while transitions < MAX_TRANSITIONS and _errors.is_empty():
		transitions += 1
		match _scene_path():
			BATTLE_SCENE:
				await _play_battle()
			REWARD_SCENE:
				await _claim_reward_and_continue()
			EVOLUTION_SCENE:
				await _resolve_progression_stop()
			ROUTE_FORK_SCENE:
				await _resolve_fork()
			INTERCEPT_SCENE:
				await _resolve_intercept()
			RUN_END_SCENE:
				break
			_:
				_errors.append("Unexpected scene: %s" % _scene_path())

	if _errors.is_empty() and _scene_path() == RUN_END_SCENE and str(_game_state().get("last_run_result")) == "victory":
		print("[RUN_SMOKE] PASS — full run completed in victory (battle %d/%d, %d transitions)" % [
			int(_game_state().get("current_battle")), int(_game_state().get("total_battles")), transitions])
		quit(0)
		return
	if _errors.is_empty():
		_errors.append("Run ended at %s with result '%s'" % [_scene_path(), str(_game_state().get("last_run_result"))])
	for error in _errors:
		printerr("[RUN_SMOKE] FAIL — %s" % error)
	quit(1)


func _play_battle() -> void:
	print("[RUN_SMOKE] Battle %d/%d" % [int(_game_state().get("current_battle")), int(_game_state().get("total_battles"))])
	var battle := _current()
	if battle == null or not battle.has_method("_on_auto_battle_button_pressed"):
		_errors.append("Battle scene lacks auto battle")
		return
	battle.call("_on_auto_battle_button_pressed")
	if await _wait_for_any_scene([REWARD_SCENE, RUN_END_SCENE]) == "":
		_errors.append("Battle did not resolve within timeout")


func _claim_reward_and_continue() -> void:
	var gs := _game_state()
	var items: Array = gs.call("get_pending_reward_items")
	if not items.is_empty():
		var item: ItemData = _pick_claimable_item(items)
		if item != null:
			var target_unit_id := ""
			if item.item_type == "gear":
				target_unit_id = str(gs.get("selected_units")[0])
			gs.call("claim_reward", item.id, target_unit_id)
	gs.call("award_battle_xp")
	if bool(gs.call("has_pending_evolution")):
		_scene_manager().call("go_to_evolution")
		await _wait_for_scene(EVOLUTION_SCENE)
		return
	_scene_manager().call("go_to_next_battle_or_beat")
	if await _wait_for_any_scene([BATTLE_SCENE, ROUTE_FORK_SCENE, INTERCEPT_SCENE]) == "":
		_errors.append("Post-reward routing stalled")


func _resolve_progression_stop() -> void:
	var gs := _game_state()
	var screen := _current()
	if bool(gs.call("is_pending_directive_stage")):
		var choices: Array = gs.call("get_pending_directive_choices")
		if choices.is_empty() or not screen.has_method("_on_choose_directive_pressed"):
			_errors.append("Directive stop offered no choices")
			return
		print("[RUN_SMOKE] Directive stop -> %s" % str((choices[0] as Dictionary).get("name", "")))
		screen.call("_on_choose_directive_pressed", str((choices[0] as Dictionary).get("name", "")))
	else:
		var paths: Array = gs.call("get_pending_evolution_paths")
		if paths.is_empty() or not screen.has_method("_on_choose_path_pressed"):
			_errors.append("Evolution stop offered no paths")
			return
		print("[RUN_SMOKE] Evolution stop -> %s" % str((paths[0] as Dictionary).get("name", "")))
		screen.call("_on_choose_path_pressed", str((paths[0] as Dictionary).get("name", "")))
	if await _wait_for_any_scene([BATTLE_SCENE, ROUTE_FORK_SCENE, INTERCEPT_SCENE]) == "":
		_errors.append("Progression stop routing stalled")


func _resolve_fork() -> void:
	print("[RUN_SMOKE] Route fork -> flagged route")
	var fork := _current()
	if fork == null or not fork.has_method("_on_route_chosen"):
		_errors.append("Fork screen missing handler")
		return
	fork.call("_on_route_chosen", true)
	if await _wait_for_scene(BATTLE_SCENE) == "":
		_errors.append("Fork routing stalled")


func _resolve_intercept() -> void:
	var intercept := _current()
	if intercept == null or not intercept.has_method("_on_choice_pressed"):
		_errors.append("Intercept screen missing handler")
		return
	var card: Dictionary = (_game_state().get("INTERCEPT_CARDS") as Dictionary).get(str(intercept.get("_card_id")), {})
	print("[RUN_SMOKE] Intercept -> %s (skip)" % str(card.get("name", "")))
	var choices: Array = card.get("choices", [])
	var pick: Dictionary = {"label": "skip", "effects": []}
	for choice_variant in choices:
		var choice: Dictionary = choice_variant
		if str(choice.get("pick", "")) == "" and (choice.get("draft", {}) as Dictionary).is_empty():
			pick = choice
			break
	intercept.call("_on_choice_pressed", pick)
	await _wait_frames(2)
	if intercept.has_method("_continue_to_battle"):
		intercept.call("_continue_to_battle")
	if await _wait_for_scene(BATTLE_SCENE) == "":
		_errors.append("Intercept routing stalled")


func _pick_claimable_item(items: Array) -> ItemData:
	var gs := _game_state()
	for item_variant in items:
		var item: ItemData = item_variant as ItemData
		if item == null:
			continue
		if item.item_type == "consumable" and (gs.get("consumables") as Array).size() >= int(gs.get("MAX_CONSUMABLES")):
			continue
		return item
	return null


# ── Helpers ──────────────────────────────────────────────────────────────────

func _game_state() -> Node:
	return root.get_node("/root/GameState")


func _data_manager() -> Node:
	return root.get_node("/root/DataManager")


func _scene_manager() -> Node:
	return root.get_node("/root/SceneManager")


func _current() -> Node:
	return current_scene


func _scene_path() -> String:
	return current_scene.scene_file_path if current_scene != null else ""


func _wait_frames(count: int) -> void:
	for _i in count:
		await process_frame


func _wait_for_scene(scene_path: String, timeout: float = STEP_TIMEOUT_SECS) -> String:
	return await _wait_for_any_scene([scene_path], timeout)


func _wait_for_any_scene(scene_paths: Array, timeout: float = STEP_TIMEOUT_SECS) -> String:
	var waited: float = 0.0
	while waited < timeout:
		if _scene_path() in scene_paths:
			await _wait_frames(2)
			return _scene_path()
		await create_timer(0.25).timeout
		waited += 0.25
	return ""
