extends SceneTree

var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func run() -> void:
	await process_frame
	var header: Node = root.get_node("PersistentHeader")
	check(not header.get("dev_tools_unlocked"), "New sessions must start locked")
	header.call("update_progress", 1, 10, "FACILITY")
	for i in 6:
		header.call("_register_dev_tap", 1000 + i * 100)
	check(not header.get("dev_tools_unlocked"), "Six taps must not unlock")
	header.call("_register_dev_tap", 4000)
	check(header.get("_dev_tap_count") == 1, "A pause must break the sequence")
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	outside.position = Vector2(500, 1000)
	header.call("_input", outside)
	check(header.get("_dev_tap_count") == 0, "A tap elsewhere must break the sequence")
	for i in 7:
		header.call("_register_dev_tap", 5000 + i * 100)
	check(header.get("dev_tools_unlocked") and header.get("dev_mode_enabled"), "Seven taps must unlock and enable tools")
	header.call("set_dev_mode", false)
	check(header.get("dev_tools_unlocked") and not header.get("dev_mode_enabled"), "Hiding arrows must preserve session access")
	var sm: Node = root.get_node("SaveManager")
	var saved: Dictionary = sm.get("data").duplicate(true)
	var old_profile: Dictionary = saved.duplicate(true)
	old_profile["unlocks"]["boss_relics"] = ["twinFates", "rootAccess"]
	old_profile["unlocks"]["item_gates_awarded"] = 14
	old_profile["settings"]["dev_mode"] = true
	sm.call("_merge_loaded", old_profile)
	var migrated: Dictionary = sm.get("data")
	check(migrated["unlocks"]["boss_relics"] == ["rootAccess"], "Removed relic must be pruned without losing other unlocks")
	check(migrated["unlocks"]["item_gates_awarded"] == 14, "Unlock progression must survive migration")
	check(not migrated["settings"].has("dev_mode"), "Old persisted developer mode must be discarded")
	sm.set("data", saved)
	print("[DEV_UNLOCK] " + ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
