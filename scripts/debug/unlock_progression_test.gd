# Build F unlock progression regressions — counter integrity, run-end-only
# gate evaluation, delta correctness, boss-relic announcement, sim pin.
# Run: godot --headless --path . -s scripts/debug/unlock_progression_test.gd
#
# Pre-change failures (why each test exists):
#   - counter integrity FAILED (no battles_fought counter existed);
#   - boss-relic announcement FAILED (boss relics unlocked silently);
#   - run-end-only / delta FAIL if gate evaluation ever moves earlier;
#   - sim pin FAILS if harness pools ever depend on the profile.
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const REWARD_SCENE := "res://scenes/ui/RewardScreen.tscn"
const RUN_END_SCENE := "res://scenes/ui/RunEndScreen.tscn"
const DEFAULT_SQUAD := ["pulse", "combat", "shield"]
const STEP_TIMEOUT_SECS := 120.0

var _failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS [unlock] %s" % msg)
	else:
		_failed += 1
		push_error("FAIL [unlock] %s" % msg)


func _run() -> void:
	await _test_counter_integrity()
	_test_gating_and_delta()
	_test_sim_pin()  # LAST — the pin is sticky for the process
	if _failed == 0:
		print("[UNLOCK_PROGRESSION] PASS")
		quit(0)
	else:
		print("[UNLOCK_PROGRESSION] FAIL - %d check(s)" % _failed)
		quit(1)


# ── Counter integrity: one increment per encounter ENTERED; a multi-round
# battle increments once ─────────────────────────────────────────────────────
func _test_counter_integrity() -> void:
	var sm := _save_manager()
	var gs := _game_state()
	sm.set("data", sm.call("default_data"))
	gs.call("start_run", DEFAULT_SQUAD, "facility", 777)
	_check(int(sm.call("get_battles_fought")) == 0, "counter starts at 0")
	gs.call("advance_to_next_battle")
	change_scene_to_file(BATTLE_SCENE)
	await _wait_for_scene(BATTLE_SCENE)
	_check(int(sm.call("get_battles_fought")) == 1, "entering an encounter counts exactly once")
	# Multi-round: auto-complete the whole battle (win or lose) — rounds never touch it.
	var battle := current_scene
	if battle != null and battle.has_method("_on_auto_battle_button_pressed"):
		battle.call("_on_auto_battle_button_pressed")
		var landed: String = await _wait_for_any_scene([REWARD_SCENE, RUN_END_SCENE], STEP_TIMEOUT_SECS)
		_check(landed != "", "auto battle resolved")
		_check(int(sm.call("get_battles_fought")) == 1, "a multi-round battle increments once")
	else:
		_check(false, "battle scene lacks auto battle")
	# A fresh encounter (new run) counts once more; lifetime counter persists across runs.
	gs.call("start_run", DEFAULT_SQUAD, "facility", 778)
	gs.call("advance_to_next_battle")
	change_scene_to_file(BATTLE_SCENE)
	await _wait_for_scene(BATTLE_SCENE)
	_check(int(sm.call("get_battles_fought")) == 2, "the next encounter counts once more")
	# Leave the live battle so the pure-data tests run on a quiet tree.
	change_scene_to_file(RUN_END_SCENE)
	await _wait_for_scene(RUN_END_SCENE)


# ── Gate evaluation: run end ONLY; delta correctness; boss-relic announcement;
# no empty ceremony ──────────────────────────────────────────────────────────
func _test_gating_and_delta() -> void:
	var dm := _data_manager()
	var sm := _save_manager()
	dm.call("force_pool_gating_for_test")

	# Fresh profile: pools are exactly bucket 0, per type (the floor the
	# pool-floor gate approves).
	sm.set("data", sm.call("default_data"))
	var b0_consumable: int = _bucket_type_count(0, "consumable")
	var b0_gear: int = _bucket_type_count(0, "gear")
	var b0_relic: int = _bucket_type_count(0, "relic")
	_check((dm.call("pool_ids", "consumable") as Array).size() == b0_consumable, "fresh profile: consumable pool == bucket 0")
	_check((dm.call("pool_ids", "gear") as Array).size() == b0_gear, "fresh profile: gear pool == bucket 0")
	_check((dm.call("pool_ids", "relic") as Array).size() == b0_relic, "fresh profile: relic pool == bucket 0")

	# RUN-END-ONLY: crossing thresholds mid-run changes NO pool composition.
	(sm.get("data")["stats"] as Dictionary)["battles_fought"] = 7  # crosses gates 1 (3) and 2 (6)
	var mid_run_unchanged: bool = (
		(dm.call("pool_ids", "consumable") as Array).size() == b0_consumable
		and (dm.call("pool_ids", "gear") as Array).size() == b0_gear
		and (dm.call("pool_ids", "relic") as Array).size() == b0_relic
	)
	_check(mid_run_unchanged, "crossing gate thresholds mid-run changes NO pool composition")

	# Award at run end: exactly buckets 1+2 join the pools, together.
	sm.call("record_run_finished", "defeat", "facility", 3)
	_check(int(sm.call("get_item_gates_awarded")) == 2, "run end awards every crossed gate at once")
	var expected_ids: Dictionary = {}
	for bucket_index in range(0, 3):
		for item_id in dm.call("bucket_items", bucket_index):
			expected_ids[str(item_id)] = true
	var pool_after: Array = (dm.call("pool_ids", "consumable") as Array) \
		+ (dm.call("pool_ids", "gear") as Array) + (dm.call("pool_ids", "relic") as Array)
	var pool_matches: bool = pool_after.size() == expected_ids.size()
	for item_id in pool_after:
		if not expected_ids.has(str(item_id)):
			pool_matches = false
	_check(pool_matches, "post-award pools are exactly buckets 0..2")
	# A losing run progressed unlocks, and the delta announces exactly buckets 1+2.
	var defeat_delta: Array = sm.call("check_new_unlocks")
	var bucket12_count: int = (dm.call("bucket_items", 1) as Array).size() + (dm.call("bucket_items", 2) as Array).size()
	_check(defeat_delta.size() == bucket12_count, "losing run: delta is exactly the crossed buckets")

	# DELTA CORRECTNESS: two gates + a boss kill yields exactly those buckets +
	# that relic (+ the operation/hero the victory legitimately awards).
	sm.set("data", sm.call("default_data"))
	(sm.get("data")["stats"] as Dictionary)["battles_fought"] = 6
	sm.call("record_run_finished", "victory", "facility", 10)
	var delta: Array = sm.call("check_new_unlocks")
	var boss_ids: Array = []
	var item_ids: Dictionary = {}
	var op_ids: Array = []
	var hero_ids: Array = []
	for entry_variant in delta:
		var entry: Dictionary = entry_variant as Dictionary
		match str(entry.get("type", "")):
			"boss_relic":
				boss_ids.append(str(entry.get("id", "")))
			"operation":
				op_ids.append(str(entry.get("id", "")))
			"hero":
				hero_ids.append(str(entry.get("id", "")))
			_:
				item_ids[str(entry.get("id", ""))] = true
	_check(boss_ids == ["salvageRig"], "boss kill announces its relic (BOSS RELIC section feed)")
	_check(str((delta[0] as Dictionary).get("type", "")) == "boss_relic", "boss relic leads the delta (biggest news first)")
	var expected_items: Dictionary = {}
	for bucket_index in range(1, 3):
		for item_id in dm.call("bucket_items", bucket_index):
			expected_items[str(item_id)] = true
	_check(item_ids == expected_items, "delta items are exactly the two crossed buckets")
	_check(op_ids == ["hive"] and hero_ids == ["avalanche"], "victory rides the existing op/hero awards")

	# NO EMPTY CEREMONY: a run crossing nothing yields no screen.
	sm.set("data", sm.call("default_data"))
	(sm.get("data")["stats"] as Dictionary)["battles_fought"] = 2
	sm.call("record_run_finished", "defeat", "facility", 2)
	_check((sm.call("check_new_unlocks") as Array).is_empty(), "a run crossing nothing yields no unlock screen")


# ── Sim pin: harness pool query returns FULL pools regardless of profile ─────
func _test_sim_pin() -> void:
	var dm := _data_manager()
	var sm := _save_manager()
	sm.set("data", sm.call("default_data"))  # most-locked possible profile
	var full_consumable: int = _all_bucket_type_count("consumable")
	var full_gear: int = _all_bucket_type_count("gear")
	var full_relic: int = _all_bucket_type_count("relic")
	_check((dm.call("pool_ids", "consumable") as Array).size() < full_consumable, "gated profile reads a partial pool (pin has something to beat)")
	dm.call("pin_pools_fully_unlocked")
	var pinned_full: bool = (
		(dm.call("pool_ids", "consumable") as Array).size() == full_consumable
		and (dm.call("pool_ids", "gear") as Array).size() == full_gear
		and (dm.call("pool_ids", "relic") as Array).size() == full_relic
	)
	_check(pinned_full, "pinned harness pools are FULL regardless of profile")


func _bucket_type_count(bucket_index: int, item_type: String) -> int:
	var dm := _data_manager()
	var count: int = 0
	for item_id in dm.call("bucket_items", bucket_index):
		var item: ItemData = dm.call("get_item", str(item_id)) as ItemData
		if item != null and item.item_type == item_type:
			count += 1
	return count


# Fully-unlocked expectation derived from the buckets themselves (the floor
# gate proves every non-boss item sits in exactly one bucket).
func _all_bucket_type_count(item_type: String) -> int:
	var dm := _data_manager()
	var total: int = 0
	var bucket_count: int = int(dm.call("unlock_gate_count")) + 1
	for bucket_index in range(bucket_count):
		total += _bucket_type_count(bucket_index, item_type)
	return total


func _wait_for_scene(path: String, timeout_secs: float = STEP_TIMEOUT_SECS) -> bool:
	var frames_left := int(timeout_secs * 60.0)
	while frames_left > 0:
		frames_left -= 1
		await process_frame
		if _scene_path() == path:
			await process_frame
			await process_frame
			return true
	_check(false, "timed out waiting for %s (last=%s)" % [path, _scene_path()])
	return false


func _wait_for_any_scene(paths: Array, timeout_secs: float) -> String:
	var frames_left := int(timeout_secs * 60.0)
	while frames_left > 0:
		frames_left -= 1
		await process_frame
		for path_variant in paths:
			if _scene_path() == str(path_variant):
				await process_frame
				return str(path_variant)
	return ""


func _scene_path() -> String:
	if current_scene == null:
		return "<null>"
	return str(current_scene.scene_file_path)


func _game_state() -> Node:
	return root.get_node("/root/GameState")


func _data_manager() -> Node:
	return root.get_node("/root/DataManager")


func _save_manager() -> Node:
	return root.get_node("/root/SaveManager")
