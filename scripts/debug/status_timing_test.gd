# Build J Item 1 — presentation-order test (headless, signal-order style).
# Asserts the chip for an enemy-sourced status is SUPPRESSED at sequence start
# and releases exactly at its causing group's beat — never at resolve. Runs
# entirely on the suppression planner (no rendered frames, no render-dependent
# signals — the Build G jam-test lesson); the visual confirmation lives in the
# windowed capture harness.
# FAIL-ON-OLD: pre-Build-J BattleFeedback has no planner — this script fails.
# Run: godot --headless --path . -s scripts/debug/status_timing_test.gd
extends SceneTree

var _failed: int = 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS [status-timing] %s" % msg)
	else:
		_failed += 1
		push_error("FAIL [status-timing] %s" % msg)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var feedback = load("res://scripts/battle/battle_feedback.gd").new()
	# Round shape: hero A hits enemy E, then enemy E burns hero H and shields
	# itself (multi-status: both must land at E's beat, group index 1).
	var events: Array = [
		{"type": "action_start", "side": "hero", "actor_id": "A#1", "zone": "strike"},
		{"type": "damage", "side": "enemy", "target_id": "E#1", "amount": 7},
		{"type": "action_start", "side": "enemy", "actor_id": "E#1", "zone": "surge"},
		{"type": "burn", "side": "hero", "target_id": "H#1", "amount": 3},
		{"type": "shield", "side": "enemy", "target_id": "E#1", "amount": 6},
	]
	feedback.plan_status_suppression(events)
	# At resolve time (sequence start): the enemy-sourced chip must NOT be live.
	_check(feedback.suppressed_chip_types("H#1").has("burn"),
		"enemy-sourced burn chip is suppressed at resolve")
	_check(feedback.suppressed_chip_types("E#1").has("shield"),
		"enemy self-shield chip is suppressed at resolve (side-agnostic rule)")
	_check(int(feedback.suppressed_chip_types("H#1")["burn"]) == 1,
		"burn chip is owed to the ENEMY's group (index 1), not the hero's")
	# Hero group plays: nothing releases early.
	feedback.release_group_suppression(0)
	_check(feedback.suppressed_chip_types("H#1").has("burn"),
		"hero beat releases nothing of the enemy's")
	# Enemy group plays: BOTH its chips land together (edge b).
	feedback.release_group_suppression(1)
	_check(feedback.suppressed_chip_types("H#1").is_empty(),
		"burn chip lands at the enemy's beat")
	_check(feedback.suppressed_chip_types("E#1").is_empty(),
		"self-shield lands at the same beat (multi-status together)")
	# Edge e: the round-end clear leaves nothing pending.
	feedback.plan_status_suppression(events)
	feedback.clear_status_suppression()
	_check(feedback.suppressed_chip_types("H#1").is_empty()
		and feedback.snapshot_tokens_for("H#1").is_empty(),
		"round-complete clear strands nothing")
	feedback.free()
	if _failed == 0:
		print("[STATUS_TIMING] PASS")
		quit(0)
	else:
		print("[STATUS_TIMING] FAIL - %d check(s)" % _failed)
		quit(1)
