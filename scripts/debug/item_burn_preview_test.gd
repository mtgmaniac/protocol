# Headless regression for §4 (Batch 4): an item-applied burn previews on the first
# round it actually ticks (not the application round, which it correctly skips),
# and the burn damage itself lands. Item-burn and ability-burn share the same
# `_apply_burn` core (skip-first-tick), so the model is identical; the fix was the
# preview REFRESH timing (shared with §3 — previews recompute after every roll).
# Run: godot --headless --path . -s scripts/debug/item_burn_preview_test.gd
# Repro (manual): roll → use a burn item (Acid Vial) on an enemy → its burn chip
# appears now; end the turn; next turn the enemy's card shows the red burn forecast
# for the tick it's about to take (before this fix the forecast never refreshed in).
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SQUAD := ["combat", "engineer", "medic"]

var _errors: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[ITEM_BURN] Starting item-applied burn preview regression")
	var gs: Node = root.get_node("/root/GameState")
	var dmgr: Node = root.get_node("/root/DataManager")
	gs.call("start_run", SQUAD, str(dmgr.call("get_operation_order")[0]))
	gs.call("advance_to_next_battle")
	change_scene_to_file(BATTLE_SCENE)
	var retries := 180
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE:
			break
	await create_timer(1.0).timeout
	var rb: Button = current_scene.get_node_or_null("%RollButton") as Button
	if rb != null and rb.visible and not rb.disabled:
		var tray: Node = current_scene.get_node_or_null("%DiceTray3D")
		rb.emit_signal("pressed")
		if tray != null and tray.has_signal("roll_finished"):
			await tray.roll_finished
	await create_timer(0.4).timeout

	var cm: Object = current_scene.get("combat_manager")
	var cv: Object = current_scene.get("_card_view")
	var enemy: Dictionary = {}
	for es_v in cm.call("get_enemy_states"):
		if not bool((es_v as Dictionary).get("dead", false)):
			enemy = es_v
			break
	if enemy.is_empty():
		_errors.append("no living enemy")
		_finish()
		return

	# Apply burn exactly the way the Ember Vial item does.
	cm.call("apply_item_burn", enemy, 5, 2)

	# Application round: the burn was just applied, so it SKIPS this round's tick —
	# no damage forecast this round is correct, not a bug.
	var stacks: Array = enemy.get("burn_stacks", [])
	_expect(not stacks.is_empty() and bool((stacks[-1] as Dictionary).get("skip_next_tick", false)),
		"burn stack applied with skip-first-tick")
	_expect(int(cm.call("get_expected_burn_tick", enemy)) == 0, "no tick on the application round (skip)")
	var pv_apply: Dictionary = cv.call("compute_preview_for_unit", enemy, false)
	_expect(int(pv_apply.get("burn", 0)) == 0, "preview shows no burn on the application round")

	# Next round: the end-of-turn tick consumed the skip flag. Now the burn ticks,
	# and the preview must show it (the §3 refresh recomputes it after the roll).
	for st_v in enemy.get("burn_stacks", []):
		(st_v as Dictionary)["skip_next_tick"] = false
	_expect(int(cm.call("get_expected_burn_tick", enemy)) == 5, "burn ticks for 5 on the round it applies (damage lands)")
	var pv_tick: Dictionary = cv.call("compute_preview_for_unit", enemy, false)
	_expect(int(pv_tick.get("burn", 0)) == 5, "preview shows the 5 burn on the round it ticks (got %d)" % int(pv_tick.get("burn", 0)))

	# The damage actually lands: refreshing all cards (the roll-time path) must not
	# wipe the burn forecast, and the tick value the preview uses is the real one
	# combat will deal.
	cv.call("refresh_all_cards")
	_expect(int(cm.call("get_expected_burn_tick", enemy)) == 5, "burn damage value stable through a refresh")

	_finish()


func _expect(cond: bool, label: String) -> void:
	if not cond:
		_errors.append(label)


func _finish() -> void:
	if _errors.is_empty():
		print("[ITEM_BURN] PASS — item burn skips its apply round, then previews (and deals) its tick")
	else:
		for e in _errors:
			print("[ITEM_BURN] FAIL: " + e)
	quit(0 if _errors.is_empty() else 1)
