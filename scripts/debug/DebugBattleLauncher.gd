extends Node
## Debug autoload — screenshot harness.
##   -- --debug-battle            → start a battle, roll, screenshot the battle screen.
##   -- --debug-screen <id>       → boot a single menu screen and screenshot it.
##                                  ids: reward, evolution, run-end, home
## Saves to res://debug_artifacts/ and quits.

const SCREENSHOT_PATH := "res://debug_artifacts/debug_screenshot.png"
const SCREENSHOT_DELAY_SECS := 3.5
const SCREEN_SETTLE_SECS := 2.5


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--debug-battle" in args:
		await get_tree().process_frame
		await get_tree().process_frame
		_launch()
		return
	if "--debug-web-timing" in args:
		await get_tree().process_frame
		await get_tree().process_frame
		_web_timing()
		return
	var screen_id: String = _arg_value(args, "--debug-screen")
	if screen_id != "":
		await get_tree().process_frame
		await get_tree().process_frame
		_launch_screen(screen_id)


# Returns the token following `flag` in the user args, or "" if absent.
func _arg_value(args: PackedStringArray, flag: String) -> String:
	for i in range(args.size()):
		if args[i] == flag and i + 1 < args.size():
			return args[i + 1]
		# also accept --debug-screen=reward
		if args[i].begins_with(flag + "="):
			return args[i].substr((flag + "=").length())
	return ""


# Battle-entry timing probe (web warm-up relocation, 2026-07-23): drives the
# TUTORIAL and DEPLOY battle entries in ONE session and prints press->scene
# time plus the post-entry frame stalls (where the WebGL pipeline warm-up
# lands). Also proves the once-per-session warm-up gate: the [DiceTray3D]
# warm-up log must appear at most once across both entries.
func _web_timing() -> void:
	print("[WEBTIME] session start")
	# Menu dwell: models the player reading the menu — long enough for the
	# menu-load warm-up to finish (the speedrun-BEGIN case is covered by the
	# warm-up's start-set gate, not by this probe).
	await get_tree().create_timer(5.0).timeout
	await _time_battle_entry("tutorial", func() -> void:
		GameState.start_tutorial_run()
		SceneManager.go_to_battle())
	SceneManager.go_to_main_menu()
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await tree.create_timer(2.0).timeout
	var unit_ids: Array = DataManager.units.keys().slice(0, 3)
	var ops: Array = DataManager.get_operation_order()
	var op_id: String = ops[0] if not ops.is_empty() else ""
	await _time_battle_entry("deploy", func() -> void:
		GameState.start_run(unit_ids, op_id)
		SceneManager.go_to_battle())
	print("[WEBTIME] done")
	get_tree().quit()


func _time_battle_entry(tag: String, launch: Callable) -> void:
	var t0: int = Time.get_ticks_msec()
	launch.call()
	var deadline: int = t0 + 15000
	while Time.get_ticks_msec() < deadline:
		var scene: Node = get_tree().get_current_scene()
		if scene != null and scene.name == "BattleScene":
			break
		await get_tree().process_frame
	var t_scene: int = Time.get_ticks_msec()
	var frame_total: int = 0
	var frame_max: int = 0
	for _i in range(15):
		var f0: int = Time.get_ticks_msec()
		await get_tree().process_frame
		var fd: int = Time.get_ticks_msec() - f0
		frame_total += fd
		frame_max = maxi(frame_max, fd)
	print("[WEBTIME] %s: press->scene %d ms | next 15 frames %d ms (max frame %d ms)" % [tag, t_scene - t0, frame_total, frame_max])


func _launch() -> void:
	var unit_ids: Array = DataManager.units.keys().slice(0, 3)
	if unit_ids.is_empty():
		push_error("[DebugBattle] DataManager has no units — data load may have failed")
		get_tree().quit(1)
		return

	var ops: Array = DataManager.get_operation_order()
	var op_id: String = ops[0] if not ops.is_empty() else ""
	# Optional: --debug-op <operation_id> to smoke-test a specific operation.
	var op_arg: String = _arg_value(OS.get_cmdline_user_args(), "--debug-op")
	if op_arg != "" and ops.has(op_arg):
		op_id = op_arg

	print("[DebugBattle] units=%s  op=%s" % [unit_ids, op_id])
	GameState.start_run(unit_ids, op_id)
	SceneManager.go_to_battle()

	# Wait for scene transition + BattleScene layout passes to finish
	await get_tree().create_timer(SCREENSHOT_DELAY_SECS).timeout

	# Trigger a roll so dice are visible in the screenshot
	var scene = get_tree().get_current_scene()
	if scene != null:
		var roll_btn = scene.get_node_or_null("%RollButton")
		if roll_btn != null and roll_btn.is_inside_tree() and not roll_btn.disabled:
			roll_btn.pressed.emit()
			print("[DebugBattle] Roll triggered")
			# Wait for dice physics + settle + targeting phase
			await get_tree().create_timer(9.0).timeout
		else:
			print("[DebugBattle] Roll button not ready, skipping roll")

	_capture(SCREENSHOT_PATH)


# Boots a single menu screen with enough GameState context to render, then shoots it.
func _launch_screen(screen_id: String) -> void:
	var unit_ids: Array = DataManager.units.keys().slice(0, 3)
	if screen_id == "boss-audit":
		_audit_bosses()
		get_tree().quit()
		return
	if screen_id == "portrait-audit":
		for uid in DataManager.units.keys():
			var u = DataManager.get_unit(uid)
			if u == null or u.portrait == null:
				continue
			var img = u.portrait.get_image()
			if img == null:
				print("  %s: get_image() NULL" % uid)
				continue
			print("  %s: tex=%s used_rect=%s" % [uid, img.get_size(), img.get_used_rect()])
		get_tree().quit()
		return

	var ops: Array = DataManager.get_operation_order()
	var op_id: String = ops[0] if not ops.is_empty() else ""
	# Optional: --debug-op <operation_id> to smoke-test a specific operation.
	var op_arg: String = _arg_value(OS.get_cmdline_user_args(), "--debug-op")
	if op_arg != "" and ops.has(op_arg):
		op_id = op_arg
	GameState.start_run(unit_ids, op_id)
	print("[DebugScreen] screen=%s units=%s op=%s" % [screen_id, unit_ids, op_id])

	match screen_id:
		"reward":
			GameState.prepare_battle_rewards()
			SceneManager.go_to_reward_screen()
		"evolution":
			if not unit_ids.is_empty():
				GameState.pending_evolution_unit_id = str(unit_ids[0])
			SceneManager.go_to_evolution()
		"run-end", "run_end", "victory":
			GameState.current_battle = GameState.total_battles
			GameState.last_run_result = "victory"
			SceneManager.go_to_run_end()
		"run-end-defeat", "defeat", "run_end_defeat":
			GameState.current_battle = maxi(GameState.total_battles / 2, 1)
			GameState.last_run_result = "defeat"
			SceneManager.go_to_run_end()
		"home", "unit-select", "unit_select":
			SceneManager.go_to_unit_select()
		"route-fork", "fork":
			GameState.current_battle = 2
			SceneManager.go_to(SceneManager.ROUTE_FORK_SCENE)
		"intercept":
			GameState.current_battle = 2
			GameState.run_beats[2] = {"type": "intercept", "tier": "minor"}
			SceneManager.go_to(SceneManager.INTERCEPT_SCENE)
		_:
			push_error("[DebugScreen] unknown screen id: " + screen_id)
			get_tree().quit(1)
			return

	await get_tree().create_timer(SCREEN_SETTLE_SECS).timeout
	_capture("res://debug_artifacts/debug_screen_%s.png" % screen_id)


func _audit_bosses() -> void:
	print("[BOSS-AUDIT] chosen boss portrait per operation (highest-HP enemy w/ art):")
	for op_id in DataManager.get_operation_order():
		var op = DataManager.get_operation(op_id)
		if op == null or op.battles.is_empty():
			print("  ", op_id, " — NO BATTLES")
			continue
		var boss_name := ""
		var best_hp := -1
		for b in op.battles:
			for n in b.get("enemy_names", []):
				var e = DataManager.get_enemy_by_display_name(n)
				if e == null or e.portrait == null:
					continue
				if e.max_hp > best_hp:
					best_hp = e.max_hp
					boss_name = n
		print("  OP %-16s -> %s" % [op_id, ("'%s' (hp %d)" % [boss_name, best_hp]) if boss_name != "" else "*** NO ART FOR ANY ENEMY ***"])


func _capture(path: String) -> void:
	var image: Image = get_tree().get_root().get_texture().get_image()
	if image == null or image.is_empty():
		# Fallback: try the active viewport directly
		image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("[DebugScreen] Could not read viewport image")
		get_tree().quit(1)
		return

	print("[DebugScreen] image size: %s  viewport rect: %s" % [image.get_size(), get_viewport().get_visible_rect()])
	var err: int = image.save_png(path)
	if err == OK:
		print("[DebugScreen] Screenshot saved: " + path)
	else:
		var user_path := "user://debug_screenshot.png"
		err = image.save_png(user_path)
		var resolved := OS.get_user_data_dir().path_join("debug_screenshot.png")
		if err == OK:
			print("[DebugScreen] Screenshot saved (user://): " + resolved)
		else:
			push_error("[DebugScreen] Screenshot failed, error: %d" % err)

	get_tree().quit()
