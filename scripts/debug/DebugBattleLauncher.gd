extends Node
## Debug autoload — only active when launched with: -- --debug-battle
## Starts a battle with the first available units/operation, waits for layout
## to settle, saves a screenshot to the project root, then quits.

const SCREENSHOT_PATH := "C:/Users/Kev/Documents/protocol/debug_screenshot.png"
const SCREENSHOT_DELAY_SECS := 3.5


func _ready() -> void:
	if not "--debug-battle" in OS.get_cmdline_user_args():
		return
	# Two frames so all autoload _ready() calls complete before we touch their data
	await get_tree().process_frame
	await get_tree().process_frame
	_launch()


func _launch() -> void:
	var unit_ids: Array = DataManager.units.keys().slice(0, 3)
	if unit_ids.is_empty():
		push_error("[DebugBattle] DataManager has no units — data load may have failed")
		get_tree().quit(1)
		return

	var ops: Array = DataManager.get_operation_order()
	var op_id: String = ops[0] if not ops.is_empty() else ""

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

	_capture()


func _capture() -> void:
	var image: Image = get_tree().get_root().get_texture().get_image()
	if image == null or image.is_empty():
		# Fallback: try the active viewport directly
		image = get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("[DebugBattle] Could not read viewport image")
		get_tree().quit(1)
		return

	print("[DebugBattle] image size: %s  viewport rect: %s" % [image.get_size(), get_viewport().get_visible_rect()])
	var err: int = image.save_png(SCREENSHOT_PATH)
	if err == OK:
		print("[DebugBattle] Screenshot saved: " + SCREENSHOT_PATH)
	else:
		# Fallback to user:// if absolute path fails (permissions etc.)
		var user_path := "user://debug_screenshot.png"
		err = image.save_png(user_path)
		var resolved := OS.get_user_data_dir().path_join("debug_screenshot.png")
		if err == OK:
			print("[DebugBattle] Screenshot saved (user://): " + resolved)
		else:
			push_error("[DebugBattle] Screenshot failed, error: %d" % err)

	get_tree().quit()
