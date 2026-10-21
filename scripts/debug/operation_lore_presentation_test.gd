# Regression for the operation lore presentation: accepted flavor metadata,
# runtime boss mechanics, persistence defaults/migration, and reusable overlays.
# Run as a scene (loads autoloads): res://scenes/debug/OperationLorePresentationRunner.tscn
extends Node

const OPERATION_BRIEFING_OVERLAY := preload("res://scripts/ui/operation_briefing_overlay.gd")
const OPERATION_IDS := ["facility", "hive", "veil", "voidCirclet", "stellarMenagerie"]
const BOSS_NAMES := ["Scrapmaster", "Hive Matriarch", "Veil Overseer", "Signal Hierarch", "Mantle Tyrant"]

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
		if enemy != null:
			var inspect_payload: Dictionary = InspectResolver.resolve_unit(enemy)
			_expect(str(inspect_payload.get("description", "")).contains(runtime_rule), "%s long-press inspection exposes its literal standing rule" % boss_name)
	# A run saved before a rename still holds the old enemy name (resolved
	# encounters and battle checkpoints store names): it must resolve to the
	# same unit, under its unchanged id.
	for old_name in DataManager.ENEMY_LEGACY_NAMES.keys():
		var renamed: Resource = data_manager.call("get_enemy_by_display_name", str(old_name)) as Resource
		var current_name: String = str(DataManager.ENEMY_LEGACY_NAMES[old_name])
		_expect(renamed != null and str(renamed.get("display_name")) == current_name, "a save's old enemy name %s resolves to %s" % [old_name, current_name])
	var hierarch: Resource = data_manager.call("get_enemy_by_display_name", "Signal Hierophant") as Resource
	_expect(hierarch != null and str(hierarch.get("id")) == "root_hierophant" and str(hierarch.get("callsign")) == "HIERARCH",
		"Signal Hierophant (the old name) resolves to Signal Hierarch with its id root_hierophant unchanged")


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
	# present_unlock is RETIRED (Build G): the operation announcement lives in
	# the UnlockScreen NEW OPERATION section (name + origin at body tier); this
	# test keeps the surviving overlay modes (deployment / boss alert) honest.
	for operation_id in OPERATION_IDS:
		var operation_deployment := OPERATION_BRIEFING_OVERLAY.new()
		get_tree().root.add_child(operation_deployment)
		operation_deployment.present_deployment(operation_id)
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		_expect(_has_action(operation_deployment, "ENGAGE"), "%s deployment requires ENGAGE" % operation_id)
		_test_deployment_grid(operation_id, operation_deployment)
		operation_deployment.queue_free()

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

func _has_action(overlay: Control, text: String) -> bool:
	var action := overlay.get_node_or_null("BriefingOuter/BriefingCenter/BriefingPanel/BriefingPadding/BriefingContent/BriefingAction") as Button
	return action != null and action.text == text


# The deployment briefing shows only the objective (Kev 2026-10-20): OBJECTIVE
# centred, then the objective centred under it, both m5x7 at 80; it wraps at
# words onto at most two lines inside the slate, every word fitting. SITE and
# SITUATION are not shown.
func _test_deployment_grid(operation_id: String, overlay: Control) -> void:
	var grid := overlay.get_node_or_null("BriefingOuter/BriefingCenter/BriefingPanel/BriefingPadding/BriefingContent/DeploymentInfoGrid") as Control
	_expect(grid != null, "%s deployment builds one objective block" % operation_id)
	if grid == null:
		return
	var label := grid.get_node_or_null("ObjectiveLabel") as Label
	var value := grid.get_node_or_null("ObjectiveValue") as Label
	_expect(label != null and value != null, "%s shows the OBJECTIVE label and the objective" % operation_id)
	if label == null or value == null:
		return
	_expect(grid.get_child_count() == 2, "%s shows only the objective (no SITE / SITUATION rows: %d children)" % [operation_id, grid.get_child_count()])
	var copy: Dictionary = OPERATION_BRIEFING_OVERLAY.operation_copy(operation_id)
	_expect(label.text == "OBJECTIVE" and value.text == str(copy.get("directive", "")), "%s objective text is the operation's directive" % operation_id)
	for l in [label, value]:
		_expect((l as Label).horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "%s %s is centred" % [operation_id, (l as Label).name])
		var font: Font = (l as Label).get_theme_font("font")
		_expect(str(font.resource_path).ends_with("m5x7.ttf") and (l as Label).get_theme_font_size("font_size") == 80, "%s %s is m5x7 at 80" % [operation_id, (l as Label).name])
	_expect(value.get_global_rect().position.y >= label.get_global_rect().end.y - 1.0, "%s objective sits under its label" % operation_id)
	_expect(value.autowrap_mode == TextServer.AUTOWRAP_WORD, "%s objective wraps at words" % operation_id)
	_expect(value.get_line_count() <= 2, "%s objective takes at most two lines (%d)" % [operation_id, value.get_line_count()])
	var panel := overlay.get_node_or_null("BriefingOuter/BriefingCenter/BriefingPanel") as Control
	_expect(panel != null and panel.get_global_rect().encloses(value.get_global_rect()), "%s objective stays inside the slate" % operation_id)
	var value_font: Font = value.get_theme_font("font")
	for word in value.text.split(" ", false):
		_expect(value_font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, value.get_theme_font_size("font_size")).x <= value.size.x + 1.0, "%s objective word '%s' fits" % [operation_id, word])


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_errors.append(label)
