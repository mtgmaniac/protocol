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
const HOME_SCENE := "res://scenes/ui/UnitSelect.tscn"
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
	await _test_first_profile_progression_and_presentation()
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
	_check(boss_ids == ["scrapConverter"], "boss kill announces its relic (BOSS RELIC section feed)")
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
func _test_first_profile_progression_and_presentation() -> void:
	var sm := _save_manager()
	var original_disk_enabled: bool = bool(sm.get("_disk_enabled"))
	# Headless normally force-unlocks for broad audit coverage. This presentation
	# regression deliberately uses the raw first-profile state instead.
	sm.set("_disk_enabled", true)

	var expected_starters := ["combat", "engineer", "medic", "pulse"]
	var expected_ladder := ["avalanche", "shield", "ghost", "breaker"]
	sm.set("data", sm.call("default_data"))
	_check((sm.get("data")["unlocks"] as Dictionary).get("heroes", []) == expected_starters, "fresh profile owns exactly the four intended starters")
	_check((sm.get("HERO_LADDER") as Array) == expected_ladder and not (sm.get("HERO_LADDER") as Array).has("pulse"), "Pulse is absent from the four-rung hero ladder")

	# The old numeric rung 3 represented Pulse. Preserve every owned hero, add
	# Pulse if needed, then derive the new rung from owned ladder heroes.
	var legacy_heroes := ["combat", "engineer", "medic", "avalanche", "shield", "pulse"]
	sm.call("_merge_loaded", {
		"stats": {"best_clear_by_op": {"facility": 10}, "runs_won_by_op": {"facility": 1}},
		"unlocks": {"heroes": legacy_heroes, "operations": ["facility"], "hero_ladder_rung": 3, "heroes_new": []},
		"onboarding": {"primers_seen": []},
	})
	var migrated_heroes: Array = (sm.get("data")["unlocks"] as Dictionary).get("heroes", [])
	var kept_all := true
	for hero_id in legacy_heroes:
		kept_all = kept_all and migrated_heroes.has(hero_id)
	_check(kept_all and migrated_heroes.has("pulse") and int(sm.call("get_hero_ladder_rung")) == 2, "existing-profile migration preserves ownership and normalizes the changed rung")

	# Each rung retains its stated condition and awards exactly the intended hero.
	sm.set("data", sm.call("default_data"))
	sm.call("record_run_finished", "defeat", "facility", 6)
	_check((sm.get("data")["unlocks"] as Dictionary).get("heroes", []).has("avalanche"), "Facility depth or pity awards Avalanche")
	sm.call("record_run_finished", "victory", "facility", 10)
	_check((sm.get("data")["unlocks"] as Dictionary).get("heroes", []).has("shield"), "Facility clear awards Spike Guard")
	sm.call("record_run_finished", "victory", "hive", 10)
	_check((sm.get("data")["unlocks"] as Dictionary).get("heroes", []).has("ghost"), "Hive clear awards Ghost Operative")
	sm.call("record_run_finished", "defeat", "veil", 6)
	_check((sm.get("data")["unlocks"] as Dictionary).get("heroes", []).has("breaker") and int(sm.call("get_hero_ladder_rung")) == 4, "Veil depth awards Signal Breaker and completes the ladder")
	_check((sm.get("data")["unlocks"] as Dictionary).get("operations", []) == ["facility", "hive", "veil"], "operation unlock chain remains boss-clear only")

	# Fresh-profile screen: all hero and operation cards are rendered, while locked
	# content cannot change the squad or begin a run.
	sm.call("dev_reset_profile")
	change_scene_to_file(HOME_SCENE)
	await _wait_for_scene(HOME_SCENE)
	await process_frame
	var home := current_scene
	var tiles: Dictionary = home.get("_unit_tiles") as Dictionary
	var roster: Array = home.get("_unit_ids") as Array
	_check(roster == ["combat", "engineer", "medic", "pulse", "avalanche", "shield", "ghost", "breaker"] and tiles.size() == 8, "all eight hero roster cards render in stable order")
	_check((home.get("_selected_unit_ids") as Array).is_empty(), "fresh selection starts at zero heroes")
	for hero_id in roster:
		var tile: Dictionary = tiles.get(hero_id, {}) as Dictionary
		var expected_locked: bool = not expected_starters.has(hero_id)
		var title: Label = tile.get("name") as Label
		_check(bool(tile.get("locked", false)) == expected_locked, "%s card reports its lock state" % hero_id)
		if expected_locked:
			_check(title != null and title.text.is_empty(), "%s locked card hides its name" % hero_id)
			# The name sits in a holder in the cell (9e5b03f); LOCKED is in the cell.
			_check(title != null and title.get_parent().get_parent().find_child("LockedLabel", true, false) != null, "%s locked card displays LOCKED" % hero_id)
	var before_locked_tap: Array = (home.get("_selected_unit_ids") as Array).duplicate()
	home.call("_on_tile_tapped", "avalanche")
	_check(home.get("_selected_unit_ids") == before_locked_tap, "locked hero cards remain unselectable")
	home.call("_on_tile_tapped", "combat")
	home.call("_on_tile_tapped", "pulse")
	_check((home.get("_selected_unit_ids") as Array).has("pulse"), "Pulse Tech is selectable on a fresh profile")

	var op_order: Array = sm.get("OPERATION_CHAIN") as Array
	_check(home.get("_operation_ids") == op_order, "all five operations render in canonical order")
	for index in range(op_order.size()):
		var op_id := str(op_order[index])
		home.set("_operation_index", index)
		home.set("_selected_operation_id", op_id)
		home.call("_refresh_encounter")
		if index == 0:
			_check(not bool(home.get("_current_op_locked")), "Facility remains unlocked on a fresh profile")
			_check(home.call("_operation_progress_text", "facility") == "", "Unplayed Facility has no clearance disclaimer")
			continue
		var op: OperationData = _data_manager().call("get_operation", op_id) as OperationData
		var name_label: Label = home.get("_enc_name_label") as Label
		var lock_label: Label = home.get("_enc_status_label") as Label
		var deploy: Button = home.get("_deploy_button") as Button
		_check(bool(home.get("_current_op_locked")) and name_label.text == op.display_name.to_upper() and lock_label.text == "LOCKED", "%s remains visibly locked with its real name" % op_id)
		_check(deploy.disabled, "%s locked card cannot deploy" % op_id)

	# UI batch 2026-09-27, B3 (supersedes G-16's transparent locked dossier):
	# fixed slots. Switching between ANY encounters, locked or not, moves
	# nothing; a locked encounter shows its unlock condition in the subtitle
	# slot, keeps LOCKED, and its detail box shows the lock info and
	# "THREATS: ???". Unit info is long-press only; a tap only toggles.
	await _check_encounter_slots(home, op_order, tiles)
	# G-93: run-end selection is volatile, while a persisted legacy last_deploy
	# cannot repopulate a fresh launch. The reserved info region keeps Deploy put.
	var gs := _game_state()
	gs.set("tutorial_mode", false)
	gs.set("selected_units", ["combat", "engineer", "medic"])
	gs.set("selected_operation_id", "facility")
	gs.call("finish_run", "defeat")
	_check((gs.get("session_deploy") as Dictionary).get("squad", []) == ["combat", "engineer", "medic"], "run finish remembers the squad for this session")
	change_scene_to_file(HOME_SCENE)
	await _wait_for_scene(HOME_SCENE)
	var returning_home := current_scene
	_check((returning_home.get("_selected_unit_ids") as Array) == ["combat", "engineer", "medic"], "same-session run return restores its squad")
	var returning_deploy: Button = returning_home.get("_deploy_button") as Button
	_check(not returning_deploy.disabled, "three selected heroes enable Deploy")
	var info: PanelContainer = returning_home.get("_info_bar") as PanelContainer
	_check(not info.visible, "unit info starts collapsed after run return")
	var deploy_y: float = returning_deploy.global_position.y
	returning_home.call("_toggle_info")
	for _frame in 3:
		await process_frame
	_check(info.visible and is_equal_approx(returning_deploy.global_position.y, deploy_y), "expanded info leaves Deploy at the exact same y")
	returning_home.call("_toggle_info")
	for _frame in 3:
		await process_frame
	_check(not info.visible and is_equal_approx(returning_deploy.global_position.y, deploy_y), "collapsed info leaves Deploy at the exact same y")
	gs.set("session_deploy", {})
	(sm.get("data") as Dictionary)["last_deploy"] = {"operation": "facility", "squad": ["combat", "engineer", "medic"]}
	change_scene_to_file(HOME_SCENE)
	await _wait_for_scene(HOME_SCENE)
	var fresh_home := current_scene
	var fresh_deploy: Button = fresh_home.get("_deploy_button") as Button
	_check((fresh_home.get("_selected_unit_ids") as Array).is_empty() and fresh_deploy.disabled, "fresh selection ignores legacy profile squad")
	for hero_id in ["combat", "engineer"]:
		fresh_home.call("_on_tile_tapped", hero_id)
		_check(fresh_deploy.disabled, "Deploy stays disabled after selecting %s" % hero_id)
	fresh_home.call("_on_tile_tapped", "medic")
	_check(not fresh_deploy.disabled and not (fresh_home.get("_info_bar") as PanelContainer).visible, "third hero enables Deploy without opening info")
	_test_renamed_enemy_abilities()
	_test_band_copy()
	sm.set("_disk_enabled", original_disk_enabled)


func _test_renamed_enemy_abilities() -> void:
	var file := FileAccess.open("res://data/raw/enemies.data.json", FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(file.get_as_text()) as Dictionary
	file.close()
	var abilities: Dictionary = parsed.get("enemyAbilities", {}) as Dictionary
	var cases := [
		{"enemy": "scrap", "band": "overload", "name": "Incendiary Charge", "mechanics": {"eff": "20 damage, 3 burn 1 turn", "dmg": 20, "burn": 3, "burnT": 1, "heal": 0, "rfe": 0, "shield": 0}},
		{"enemy": "rust", "band": "crit", "name": "Voltage Drop", "mechanics": {"eff": "10 damage, -2 roll 1 turn", "dmg": 10, "burn": 0, "burnT": 0, "heal": 0, "rfe": 0, "shield": 0, "rfm": 2, "rfmT": 1}},
		{"enemy": "rust", "band": "overload", "name": "Signal Crush", "mechanics": {"eff": "12 damage, -3 roll 1 turn", "dmg": 12, "burn": 0, "burnT": 0, "heal": 0, "rfe": 0, "shield": 0, "rfm": 3, "rfmT": 1}},
	]
	for case_entry in cases:
		var source: Dictionary = (abilities.get(str(case_entry["enemy"]), {}) as Dictionary).get(str(case_entry["band"]), {}) as Dictionary
		var mechanics: Dictionary = case_entry["mechanics"] as Dictionary
		# Beside its mechanics an ability carries its name and its roll window
		# (`range`, per kit since the 2026-10-08 roll windows): neither is a mechanic.
		var mechanics_match := source.size() == mechanics.size() + 2 and source.has("range")
		for key in mechanics:
			mechanics_match = mechanics_match and source.has(key) and source[key] == mechanics[key]
		_check(str(source.get("name", "")) == str(case_entry["name"]) and mechanics_match, "%s rename preserves byte-equivalent mechanics" % str(case_entry["name"]))


func _test_band_copy() -> void:
	var tutorial_file := FileAccess.open("res://scripts/ui/training_lessons.gd", FileAccess.READ)
	var tutorial_text := tutorial_file.get_as_text()
	tutorial_file.close()
	var keywords_file := FileAccess.open("res://data/raw/keywords.data.json", FileAccess.READ)
	var keywords_text := keywords_file.get_as_text()
	keywords_file.close()
	var truth_file := FileAccess.open("res://docs/TRUTH.md", FileAccess.READ)
	var truth_text := truth_file.get_as_text()
	truth_file.close()
	_check(not tutorial_text.to_lower().contains("higher rolls, stronger abilities") and not tutorial_text.to_lower().contains("higher is always better"), "tutorial no longer claims higher rolls are universally stronger")
	_check(keywords_text.contains("higher-numbered ability band") and keywords_text.contains("lower-numbered ability band") and not keywords_text.contains("stronger band") and not keywords_text.contains("weaker band"), "Roll Up and Roll Down glossary copy is band-neutral")
	_check(not truth_text.contains("→ **pulse**") and not truth_text.contains("hive best_clear ≥ 6 → **pulse**"), "documentation no longer identifies Pulse as a locked ladder hero")


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


func _encounter_rects(home: Node, tiles: Dictionary) -> Dictionary:
	var rects: Dictionary = {}
	for key in ["_enc_card", "_enc_thumb_frame", "_enc_name_label", "_enc_level_row", "_dot_row", "_info_bar", "_info_strip", "_deploy_button"]:
		var node: Control = home.get(key) as Control
		rects[key] = [node.get_global_rect(), node.is_visible_in_tree()]
	for hero_id in tiles.keys():
		rects["tile:" + str(hero_id)] = [((tiles[hero_id] as Dictionary)["frame"] as Control).get_global_rect(), true]
	return rects


# Squad select "A5" (UI batch A5, Kev 2026-10-17, G-81; supersedes B3's site
# line and detail box): fixed slots. Switching between ANY operations, locked
# or not, moves nothing; a locked one shows LOCKED and its unlock condition in
# the tags slot. A tap shows the unit in the info bar AND toggles it; neither
# moves anything.
func _check_encounter_slots(home: Node, op_order: Array, tiles: Dictionary) -> void:
	# The phone window: headless alone is 64x64, which the expand stretch lays
	# out 2400 wide, and every "fits" check would pass on the wide column.
	var saved_size: Vector2i = root.size
	root.size = Vector2i(1080, 2400)
	for _frame in 4:
		await process_frame
	# DEMO v0.51 (Kev): the portrait and its text column are one group centred
	# in the card; the column is as wide as the widest operation name (every
	# operation, locked or not), and the names stay left-aligned in it.
	var text_col: Control = home.get("_enc_text_col") as Control
	var group: Control = text_col.get_parent() as Control
	var name_ref: Label = home.get("_enc_name_label") as Label
	var widest_name := 0.0
	for op_variant in op_order:
		var op_data: OperationData = _data_manager().call("get_operation", str(op_variant)) as OperationData
		widest_name = maxf(widest_name, name_ref.get_theme_font("font").get_string_size(op_data.display_name.to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, -1, name_ref.get_theme_font_size("font_size")).x)
	# The level row with CLEARED can be wider than every name; then it sets the
	# width, or showing CLEARED would move the group.
	var widest_row: float = (home.get("_enc_level_row") as Control).get_combined_minimum_size().x
	for status_text in ["CLEARED", "LOCKED"]:
		var status_ref: Label = home.get("_enc_status_label") as Label
		var kept: String = status_ref.text
		status_ref.text = status_text
		widest_row = maxf(widest_row, (home.get("_enc_level_row") as Control).get_combined_minimum_size().x)
		status_ref.text = kept
	var room: float = float(home.call("mission_text_room"))
	var want_col: float = minf(ceilf(maxf(widest_name, widest_row) / 2.0) * 2.0, room)
	_check(is_equal_approx(text_col.size.x, want_col) and text_col.size.x >= widest_name,
		"the mission text column is fixed at its widest content, capped at the phone room (%.0f px; widest name %.0f, widest level row %.0f, room %.0f)" % [text_col.size.x, widest_name, widest_row, room])
	print("[unlock] mission column %.0f px: widest name %.0f, widest level row %.0f, room %.0f" % [text_col.size.x, widest_name, widest_row, room])
	# The widest level row stays inside the card's frame (it may reach into the pad).
	var row_end: float = (home.get("_enc_level_row") as Control).global_position.x + widest_row
	var card_inner_end: float = (home.get("_enc_card") as Control).get_global_rect().end.x - float(home.get("MISSION_FRAME"))
	_check(row_end <= card_inner_end, "the widest level row stays inside the mission card (%.0f <= %.0f)" % [row_end, card_inner_end])
	# The mission row fits the screen's content column (the arrows stay put).
	var mission_row: Control = (home.get("_enc_card") as Control).get_parent() as Control
	_check(mission_row.size.x <= (mission_row.get_parent() as Control).size.x + 0.5,
		"the mission row fits its column (%.0f <= %.0f)" % [mission_row.size.x, (mission_row.get_parent() as Control).size.x])
	var card_rect: Rect2 = (home.get("_enc_card") as Control).get_global_rect()
	var group_rect: Rect2 = group.get_global_rect()
	_check(absf(card_rect.get_center().x - group_rect.get_center().x) <= 1.0,
		"the portrait + text group is centred in the mission card (group centre %.1f, card centre %.1f)" % [group_rect.get_center().x, card_rect.get_center().x])
	_check(name_ref.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "the operation name stays left-aligned in its column")
	# One more step between the level pips and "LVL": GAP (was LEVEL_ROW_GAP).
	var level_row: HBoxContainer = home.get("_enc_level_row") as HBoxContainer
	var pips_box: Control = level_row.get_child(0) as Control
	var level_box: Control = level_row.get_child(1) as Control
	var pip_gap: float = level_box.position.x - pips_box.position.x - pips_box.size.x
	_check(is_equal_approx(pip_gap, float(home.get("GAP"))) and float(home.get("GAP")) > float(home.get("LEVEL_ROW_GAP")),
		"the level pips sit one GAP from LVL (%.0f px)" % pip_gap)
	# G-97: no threats line and no reserved slot on the card.
	for gone: String in ["_enc_tags_slot", "_enc_threats_label", "_enc_unlock_label"]:
		_check(home.get(gone) == null, "the mission card has no %s any more (G-97)" % gone)
	_check(((home.get("_enc_thumb_frame") as Control).size).is_equal_approx(((tiles["combat"] as Dictionary)["frame"] as Control).size),
		"the boss portrait is the roster tiles' size")
	var reference: Dictionary = {}
	for pass_index in 2:
		for index in range(op_order.size()):
			var op_id := str(op_order[index])
			home.set("_operation_index", index)
			home.set("_selected_operation_id", op_id)
			home.call("_refresh_encounter")
			for _frame in 3:
				await process_frame
			var rects: Dictionary = _encounter_rects(home, tiles)
			if reference.is_empty():
				reference = rects
			else:
				var moved: Array = []
				for key in reference.keys():
					var want: Array = reference[key]
					var got: Array = rects[key]
					if not (want[0] as Rect2).is_equal_approx(got[0] as Rect2) or bool(want[1]) != bool(got[1]):
						moved.append("%s %s -> %s" % [key, str(want[0]), str(got[0])])
				_check(moved.is_empty(), "switching to %s moves nothing (%s)" % [op_id, ", ".join(moved)])
			if pass_index > 0:
				continue
			var locked: bool = bool(home.get("_current_op_locked"))
			_check((home.get("_enc_level_label") as Label).text.begins_with("LVL "), "%s level reads LVL n (saw '%s')" % [op_id, (home.get("_enc_level_label") as Label).text])
			var name_label: Label = home.get("_enc_name_label") as Label
			var name_font: Font = name_label.get_theme_font("font")
			var name_w: float = name_font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_label.get_theme_font_size("font_size")).x
			_check(name_w <= text_col.size.x, "%s name fits the card on one line (%.0f <= %.0f px)" % [op_id, name_w, text_col.size.x])
			# The long-press pop-up (G-97): a locked mission shows its name and
			# unlock condition only; an open one its objective, site, situation
			# and threats.
			var payload: Dictionary = home.call("mission_payload", op_id, locked)
			var op_name: String = (_data_manager().call("get_operation", op_id) as OperationData).display_name.to_upper()
			_check(str((payload.get("header", {}) as Dictionary).get("title", "")) == op_name, "%s pop-up is titled with the operation name" % op_id)
			if locked:
				var prev_id: String = str(root.get_node("/root/SaveManager").call("operation_unlocked_by", op_id))
				var prev_op: OperationData = _data_manager().call("get_operation", prev_id) as OperationData
				var want_condition: String = "Clear %s to unlock" % prev_op.display_name
				_check(str(payload.get("description", "")) == want_condition, "%s locked pop-up shows the unlock condition (saw '%s')" % [op_id, str(payload.get("description", ""))])
				_check(not payload.has("stats"), "%s locked pop-up shows nothing else" % op_id)
				_check((home.get("_enc_status_label") as Label).text == "LOCKED", "%s shows LOCKED" % op_id)
			else:
				var labels: Array = []
				var threats_value := ""
				for row: Dictionary in payload.get("stats", []):
					labels.append(str(row.get("label", "")))
					if str(row.get("label", "")) == "THREATS":
						threats_value = str(row.get("value", ""))
				_check(labels == ["OBJECTIVE", "SITE", "SITUATION", "THREATS"], "%s pop-up rows are objective, site, situation, threats (saw %s)" % [op_id, str(labels)])
				var want_threats: String = str(home.get("THREAT_SEPARATOR")).join(home.call("threat_tags", op_id))
				_check(threats_value == want_threats and threats_value != "", "%s pop-up lists its threats (saw '%s')" % [op_id, threats_value])
	# A tap shows the unit in the info bar and toggles it; nothing moves.
	home.set("_operation_index", 0)
	home.set("_selected_operation_id", str(op_order[0]))
	home.call("_refresh_encounter")
	var before_rects: Dictionary = _encounter_rects(home, tiles)
	var before_squad: Array = (home.get("_selected_unit_ids") as Array).duplicate()
	home.call("_on_tile_tapped", "engineer")
	for _frame in 3:
		await process_frame
	_check((home.get("_selected_unit_ids") as Array) != before_squad, "a tap toggles the hero in the squad")
	_check(str(home.get("_focus_unit_id")) == "engineer" and (home.get("_info_name") as Label).text == "ENGINEER", "a tap shows the hero in the info bar")
	_check((home.get("_info_status") as Label).text == "IN SQUAD", "the info bar says the newly selected hero is in the squad")
	home.call("_on_tile_tapped", "avalanche")
	for _frame in 3:
		await process_frame
	_check((home.get("_info_status") as Label).text == "LOCKED" and (home.get("_info_blurb") as Label).text == str(_save_manager().call("hero_unlock_condition", "avalanche")),
		"a locked hero shows its unlock condition (saw '%s')" % (home.get("_info_blurb") as Label).text)
	var bench_id: String = ""
	for hero_id in ["combat", "engineer", "medic", "pulse"]:
		if not (home.get("_selected_unit_ids") as Array).has(hero_id):
			bench_id = hero_id
	home.call("_on_tile_tapped", bench_id)
	for _frame in 3:
		await process_frame
	_check((home.get("_selected_unit_ids") as Array).size() == 3 and not (home.get("_selected_unit_ids") as Array).has(bench_id) and (home.get("_info_hint") as Label).text == "SQUAD FULL: TAP A PICK TO REMOVE",
		"a bench tap with the squad full only shows the unit and the hint")
	var after_rects: Dictionary = _encounter_rects(home, tiles)
	var shifted: Array = []
	for key in before_rects.keys():
		if not ((before_rects[key] as Array)[0] as Rect2).is_equal_approx((after_rects[key] as Array)[0] as Rect2):
			shifted.append(str(key))
	_check(shifted.is_empty(), "tapping heroes moves nothing (%s)" % ", ".join(shifted))
	# Long-press carries the unit's kit.
	var unit: UnitData = _data_manager().call("get_unit", "engineer") as UnitData
	var payload: Dictionary = home.call("unit_inspect_payload", unit)
	_check(str((payload.get("header", {}) as Dictionary).get("title", "")) == unit.display_name and str(payload.get("description", "")) == unit.picker_blurb.strip_edges(),
		"long-press on a unit shows its name and blurb")
	root.size = saved_size
