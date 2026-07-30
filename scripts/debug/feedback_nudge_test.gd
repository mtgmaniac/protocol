# Feedback-nudge cadence + persistence regression (headless).
#   <godot> --headless --path . --script res://scripts/debug/feedback_nudge_test.gd
# Pins the SaveManager cadence contract: shows after the 1st completed run,
# then every 3rd run-end, an explicit dismissal skips the next scheduled show,
# never re-shows on a menu revisit inside the same run-end epoch, and the
# state survives a save/load round trip.
extends SceneTree

const TEST_SAVE_PATH := "user://feedback_nudge_test_save.json"

var _failures: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var sm: Node = root.get_node("/root/SaveManager")

	# Fresh in-memory profile (headless runs never touch the real save).
	sm.set("data", sm.call("default_data"))

	_check(not bool(sm.call("should_show_feedback_nudge")), "no nudge before any completed run")

	_finish_run(sm)  # runs_finished = 1
	_check(bool(sm.call("should_show_feedback_nudge")), "nudge shows after the 1st completed run")
	sm.call("mark_feedback_nudge_shown")
	_check(not bool(sm.call("should_show_feedback_nudge")), "no re-show on a menu revisit in the same epoch")

	_finish_run(sm)  # 2
	_check(not bool(sm.call("should_show_feedback_nudge")), "run-end 2: capped")
	_finish_run(sm)  # 3
	_check(not bool(sm.call("should_show_feedback_nudge")), "run-end 3: capped")
	_finish_run(sm)  # 4
	_check(bool(sm.call("should_show_feedback_nudge")), "run-end 4: every 3rd run-end shows")

	# Explicit dismissal at the run-end-4 show: the next scheduled show
	# (run-end 7) is skipped; cadence resumes at run-end 10.
	sm.call("mark_feedback_nudge_shown")
	sm.call("mark_feedback_nudge_dismissed")
	for i in range(3):
		_finish_run(sm)  # 5, 6, 7
	_check(not bool(sm.call("should_show_feedback_nudge")), "explicit dismissal skips the next scheduled show")
	for i in range(3):
		_finish_run(sm)  # 8, 9, 10
	_check(bool(sm.call("should_show_feedback_nudge")), "cadence resumes one interval after the skipped show")

	# Persistence: the cadence state survives a save/load round trip.
	sm.set("_save_path", TEST_SAVE_PATH)
	sm.set("_disk_enabled", true)
	sm.call("save")
	sm.set("data", sm.call("default_data"))
	sm.call("load_save")
	_check(int((sm.get("data")["stats"] as Dictionary).get("runs_finished", 0)) == 10,
		"runs_finished survives reload")
	_check(int(sm.call("get_setting", "feedback_nudge_shown_at", 0)) == 4,
		"feedback_nudge_shown_at survives reload")
	_check(bool(sm.call("get_setting", "feedback_nudge_dismissed", false)),
		"feedback_nudge_dismissed survives reload")
	_check(bool(sm.call("should_show_feedback_nudge")), "reloaded state keeps the due nudge due")

	sm.set("_disk_enabled", false)
	var absolute_path: String = ProjectSettings.globalize_path(TEST_SAVE_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)

	if _failures.is_empty():
		print("[FEEDBACK_NUDGE_TEST] PASS (12 assertions)")
		quit(0)
	else:
		for failure in _failures:
			push_error("[FEEDBACK_NUDGE_TEST] FAIL: %s" % failure)
		quit(1)


func _finish_run(sm: Node) -> void:
	sm.call("record_run_finished", "defeat", "facility", 2)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
