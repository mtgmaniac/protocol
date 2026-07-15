# Regression for the operation lore presentation: accepted flavor metadata,
# runtime boss mechanics, persistence defaults/migration, and reusable overlays.
# Run as a scene (loads autoloads): res://scenes/debug/OperationLorePresentationRunner.tscn
extends Node

const OPERATION_BRIEFING_OVERLAY := preload("res://scripts/ui/operation_briefing_overlay.gd")
const OPERATION_IDS := ["facility", "hive", "veil", "voidCirclet", "stellarMenagerie"]
const BOSS_NAMES := ["SCRAPMASTER", "Hive Matriarch", "CONCLAVE OVERSEER", "ROOT HIEROPHANT", "MANTLE TYRANT"]

var _errors: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[OPERATION_LORE] Starting presentation regression")
	_test_runtime_metadata()
	_test_save_defaults_and_migration()
	await _test_overlay_modes()
	if _errors.is_empty():
		print("[OPERATION_LORE] PASS — all five operations, all five bosses, persistence, and overlay modes")
		get_tree().quit(0)
		return
	for error_text in _errors:
		push_error("[OPERATION_LORE] " + error_text)
	get_tree().quit(1)


func _test_runtime_metadata() -> void:
	var data_manager: Node = get_tree().root.get_node("/root/DataManager")
	for operation_id in OPERATION_IDS:
		var operation: Resource = data_manager.call("get_operation", operation_id) as Resource
		var copy: Dictionary = OPERATION_BRIEFING_OVERLAY.operation_copy(operation_id)
		_expect(operation != null, "%s exists in runtime operation data" % operation_id)
		_expect(not copy.is_empty(), "%s has accepted presentation copy" % operation_id)
		if operation != null:
			_expect(str(operation.get("display_name")).to_upper() == str(copy.get("name", "")), "%s accepted name matches runtime operation data" % operation_id)
		_expect(str(copy.get("number", "")) != "", "%s has an operation number" % operation_id)
		_expect(str(copy.get("name", "")) != "", "%s has an accepted name" % operation_id)
		_expect(str(copy.get("origin", "")) != "", "%s has an unlock origin" % operation_id)
		_expect(str(copy.get("site", "")) != "" and str(copy.get("failure", "")) != "" and str(copy.get("directive", "")) != "", "%s has a complete deployment slate" % operation_id)
		_expect(str(copy.get("threats", "")) != "", "%s has a compact encounter threat summary" % operation_id)
	for boss_name in BOSS_NAMES:
		var enemy: Resource = data_manager.call("get_enemy_by_display_name", boss_name) as Resource
		var runtime_rule: String = CombatManager.get_boss_standing_rule(boss_name)
		var rule_parts: Dictionary = OPERATION_BRIEFING_OVERLAY.split_runtime_rule(runtime_rule)
		_expect(enemy != null, "%s exists in runtime enemy data" % boss_name)
		_expect(OPERATION_BRIEFING_OVERLAY.boss_flavor(boss_name) != "", "%s has accepted flavor copy" % boss_name)
		_expect(str(rule_parts.get("name", "")) != "" and str(rule_parts.get("mechanic", "")) != "", "%s exposes a literal runtime standing rule" % boss_name)


func _test_save_defaults_and_migration() -> void:
	var save_manager: Node = get_tree().root.get_node("/root/SaveManager")
	save_manager.call("dev_reset_profile")
	for operation_id in OPERATION_IDS:
		_expect(not bool(save_manager.call("has_seen_operation_origin", operation_id)), "%s origin begins unseen on a fresh profile" % operation_id)
	save_manager.call("acknowledge_operation_origin", "hive")
	save_manager.call("acknowledge_operation_origin", "hive")
	_expect(bool(save_manager.call("has_seen_operation_origin", "hive")), "origin acknowledgement persists idempotently")

	var legacy_payload := {
		"tutorial_done": false,
		"stats": {"runs_started": 2, "best_clear_by_op": {"facility": 4}},
		"unlocks": {"heroes": ["combat", "engineer", "medic"], "operations": ["facility", "hive"]},
		"onboarding": {"primers_seen": []},
	}
	save_manager.call("_merge_loaded", legacy_payload)
	_expect(bool(save_manager.call("has_seen_operation_origin", "facility")), "legacy unlocked facility does not replay its origin")
	_expect(bool(save_manager.call("has_seen_operation_origin", "hive")), "legacy unlocked hive does not replay its origin")
	save_manager.call("dev_reset_profile")


func _test_overlay_modes() -> void:
	for operation_id in OPERATION_IDS:
		var operation_unlock := OPERATION_BRIEFING_OVERLAY.new()
		get_tree().root.add_child(operation_unlock)
		operation_unlock.present_unlock(operation_id)
		await get_tree().process_frame
		_expect(_has_action(operation_unlock, "ACKNOWLEDGE"), "%s unlock overlay requires acknowledgement" % operation_id)
		operation_unlock.queue_free()
		var operation_deployment := OPERATION_BRIEFING_OVERLAY.new()
		get_tree().root.add_child(operation_deployment)
		operation_deployment.present_deployment(operation_id)
		await get_tree().process_frame
		_expect(_has_action(operation_deployment, "ENGAGE"), "%s deployment requires ENGAGE" % operation_id)
		operation_deployment.queue_free()

	var unlock := OPERATION_BRIEFING_OVERLAY.new()
	get_tree().root.add_child(unlock)
	unlock.present_unlock("hive")
	await get_tree().process_frame
	_expect(_has_action(unlock, "ACKNOWLEDGE"), "unlock overlay requires ACKNOWLEDGE")
	unlock.queue_free()

	var deployments: Array[Dictionary] = []
	for operation_id in OPERATION_IDS:
		var deployment := OPERATION_BRIEFING_OVERLAY.new()
		var state := {"dismissals": 0}
		get_tree().root.add_child(deployment)
		deployment.dismissed.connect(func(_mode: String) -> void: state["dismissals"] = int(state["dismissals"]) + 1)
		deployment.present_deployment(operation_id)
		deployments.append({"operation_id": operation_id, "overlay": deployment, "state": state})
	await get_tree().process_frame
	# All five slates stay in place beyond the former repeat-run timeout.
	await get_tree().create_timer(2.65).timeout
	for deployment_entry in deployments:
		var overlay: Control = deployment_entry["overlay"] as Control
		var state: Dictionary = deployment_entry["state"] as Dictionary
		var operation_id: String = str(deployment_entry["operation_id"])
		_expect(is_instance_valid(overlay) and int(state["dismissals"]) == 0, "%s deployment remains until ENGAGE" % operation_id)
		var action := overlay.get_node_or_null("BriefingOuter/BriefingCenter/BriefingPanel/BriefingPadding/BriefingContent/BriefingAction") as Button
		if action != null:
			action.emit_signal("pressed")
			action.emit_signal("pressed")
		_expect(int(state["dismissals"]) == 1, "%s ENGAGE dismisses exactly once" % operation_id)
	await get_tree().process_frame

	var next_run_deployment := OPERATION_BRIEFING_OVERLAY.new()
	get_tree().root.add_child(next_run_deployment)
	next_run_deployment.present_deployment("facility")
	await get_tree().process_frame
	_expect(_has_action(next_run_deployment, "ENGAGE"), "a later run presents deployment again")
	next_run_deployment.queue_free()

	for boss_name in BOSS_NAMES:
		var boss_alert := OPERATION_BRIEFING_OVERLAY.new()
		get_tree().root.add_child(boss_alert)
		boss_alert.present_boss_alert(boss_name, CombatManager.get_boss_standing_rule(boss_name))
		await get_tree().process_frame
		_expect(_has_action(boss_alert, "ENGAGE"), "%s boss alert requires ENGAGE" % boss_name)
		boss_alert.queue_free()

	var reminder := OPERATION_BRIEFING_OVERLAY.new()
	get_tree().root.add_child(reminder)
	reminder.present_boss_reminder("MANTLE TYRANT", CombatManager.get_boss_standing_rule("MANTLE TYRANT"))
	await get_tree().process_frame
	_expect(_has_action(reminder, "CLOSE"), "boss reminder is dismissible")
	reminder.queue_free()
	await get_tree().process_frame


func _has_action(overlay: Control, text: String) -> bool:
	var action := overlay.get_node_or_null("BriefingOuter/BriefingCenter/BriefingPanel/BriefingPadding/BriefingContent/BriefingAction") as Button
	return action != null and action.text == text


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_errors.append(label)
