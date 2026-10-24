# Developer unlock gate (G-10; header buttons in every build, Kev DEMO v0.51).
#
#   godot --headless --path . -s scripts/debug/dev_unlock_test.gd [-- --dev-unlock-break=<mode>]
#
# The seven-tap unlock, then the release path: the ^ / ^^ header buttons exist
# in every build but stay hidden until BOTH the unlock and Help > PREFS > DEV >
# Developer mode (off by default, session only); Help's DEBUG section stays
# absent in a release build. Turning Developer mode on shows the buttons and
# stops analytics for the session: this session's queued events are dropped,
# nothing new is queued, and re-enabling the setting does not restart it.
# A headless run is a debug build, so the release path is driven through the
# Help seam (debug_build_override) and the header, which no longer branches on
# the build. scripts/checks/break_gate.py reruns it with each deliberate break
# (PersistentHeader.DEV_UNLOCK_BREAK_ARG: stripped, shown_on_unlock,
# telemetry_on) and requires a FAIL.
extends SceneTree

const HELP_MENU := "res://scripts/ui/help_menu.gd"

var failed := false


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		print("[DEV_UNLOCK] FAIL - " + message)


func frames(count: int) -> void:
	for i in count:
		await process_frame


func buttons_shown(header: Node) -> bool:
	if not bool(header.call("has_debug_buttons")):
		return false
	return (header.get("_debug_button") as Control).visible and (header.get("_debug2_button") as Control).visible


func run() -> void:
	await process_frame
	var header: Node = root.get_node("PersistentHeader")
	var sm: Node = root.get_node("SaveManager")
	var tel: Node = root.get_node("Telemetry")
	var saved: Dictionary = sm.get("data").duplicate(true)
	sm.set("_disk_enabled", false)   # nothing in this test touches a profile on disk

	check(not header.get("dev_tools_unlocked"), "New sessions must start locked")
	# Every build keeps both header buttons (Kev, DEMO v0.51), hidden.
	check(header.call("has_debug_buttons"), "The header keeps both debug buttons in every build")
	check(header.find_child("DebugButton", true, false) != null and header.find_child("Debug2Button", true, false) != null,
		"The header holds its DebugButton and Debug2Button nodes")
	check(not buttons_shown(header), "The buttons start hidden")

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
	check(header.get("dev_tools_unlocked"), "Seven taps must unlock the dev tools")
	check(not header.get("dev_mode_enabled") and not buttons_shown(header),
		"The unlock alone must not show the buttons (Developer mode starts off)")

	# Analytics as a live release session has them: one event left over from an
	# earlier session, one queued now.
	tel.set("_allowed", true)
	tel.set("_enabled", true)
	tel.set("_install_id", tel.call("new_id"))
	var earlier: Dictionary = {"event_name": "battle_end", "player_id": tel.get("_install_id"), "payload": {}}
	tel.set("_queue", [earlier])
	tel.call("_enqueue", "reward_pick", {"kind": "item"})
	check((tel.get("_queue") as Array).size() == 2, "fixture: analytics queue an event this session")

	# Help > PREFS > DEV on the release path.
	var help: GDScript = load(HELP_MENU)
	help.set("debug_build_override", false)
	help.open(header)
	await frames(8)
	var menu: Node = help.get("_active")
	menu.call("_select_tab", "settings")
	await frames(8)
	var row: Node = menu.find_child("DevModeToggleRow", true, false)
	check(row != null, "Release PREFS > DEV shows the Developer mode row once unlocked")
	check(menu.find_child("DebugOverlayToggleRow", true, false) == null, "Release Help has no DEBUG (Build #3) section")
	var toggle: Button = null
	if row != null:
		for child in row.get_children():
			if child is Button:
				toggle = child
	check(toggle != null and not toggle.button_pressed, "Developer mode starts off")
	check(not buttons_shown(header), "The buttons stay hidden until Developer mode is on")
	if toggle != null:
		toggle.button_pressed = true
		await frames(2)
	check(header.get("dev_mode_enabled") and buttons_shown(header), "Developer mode on shows ^ and ^^")
	check(bool(tel.call("is_dev_silenced")) and not bool(tel.get("_enabled")), "Developer mode on stops analytics")
	var queue: Array = tel.get("_queue")
	check(queue.size() == 1 and is_same(queue[0], earlier), "Developer mode drops this session's queued events and keeps the earlier session's")
	tel.call("_enqueue", "battle_end", {"turns": 2})
	check((tel.get("_queue") as Array).size() == 1, "Nothing more is queued after Developer mode")
	sm.call("set_setting", "telemetry_enabled", true)
	check(not bool(tel.get("_enabled")), "Re-enabling analytics in the same session does not restart them")
	if toggle != null:
		toggle.button_pressed = false
		await frames(2)
	check(not buttons_shown(header) and bool(tel.call("is_dev_silenced")), "Developer mode off hides the buttons; analytics stay off for the session")
	menu.call("dismiss")
	help.set("debug_build_override", null)
	await frames(2)
	check(header.get("dev_tools_unlocked") and not header.get("dev_mode_enabled"), "Hiding arrows must preserve session access")

	var old_profile: Dictionary = saved.duplicate(true)
	old_profile["unlocks"]["boss_relics"] = ["twinFates", "hereticSignal"]
	old_profile["unlocks"]["item_gates_awarded"] = 14
	old_profile["settings"]["dev_mode"] = true
	sm.call("_merge_loaded", old_profile)
	var migrated: Dictionary = sm.get("data")
	check(migrated["unlocks"]["boss_relics"] == ["hereticSignal"], "Removed relic must be pruned without losing other unlocks")
	check(migrated["unlocks"]["item_gates_awarded"] == 14, "Unlock progression must survive migration")
	check(not migrated["settings"].has("dev_mode"), "Old persisted developer mode must be discarded")
	sm.set("data", saved)
	print("[DEV_UNLOCK] " + ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)
