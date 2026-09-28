# End-of-round battle checkpoint regression (save system, 2026-09-21).
#
#   godot --headless --path . -s scripts/debug/battle_checkpoint_test.gd -- \
#       --leg full|save|resume --battle N --out <file.json>
#
# One leg of scripts/checks/battle_checkpoint_gate.py, which runs each leg in a
# SEPARATE Godot process (a real reload: fresh autoloads, fresh scene, state
# only from disk) and compares them:
#   full   : play the battle straight through and record everything
#   save   : play to the round-3 checkpoint (with temporary combat state
#            layered on), record it, then ROLL round 4 and quit once the dice
#            settle - the "saw bad dice, refreshed" case
#   resume : CONTINUE from the save leg's run.json: the round-4 dice must come
#            back PLACED (the checkpoint's pending roll, G-24), not thrown;
#            record them and the state, finish the battle, record the outcome
#   save_phys / resume_phys : the same refresh with an UNRIGGED physics roll
#   save_heretic / resume_heretic : Heretic Signal re-throws every unfrozen
#            round-4 die, then the refresh: the re-thrown dice and the
#            once-per-battle flag come back (boss relic rework, G-37)
#
# The rounds go through the real live path: Roll throws the physics tray (the
# full/save legs pin the landed values through the tray's rig from a seeded test
# RNG, so two separate processes land the same dice), a real revive consumable
# is used mid-round, targets are auto-assigned, feedback plays. The checkpoint
# state is deliberately rich: a dead hero, a revived hero, a spent consumable,
# enemy burn / shield / mark / roll-buff stacks, a jammed and a frozen hero die,
# Protocol, income debt and the per-battle spend flags.
extends SceneTree

const BattleCheckpoint := preload("res://scripts/battle/battle_checkpoint.gd")
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SQUAD := ["combat", "medic", "breaker"]
const OP := "facility"
const SEED := 77031
const CHECKPOINT_ROUND := 3   # rounds completed before the checkpoint under test

var _leg: String = ""
var _battle: int = 5
var _out_path: String = ""
var _shot_path: String = ""   # --shot <png>: capture the resume banner (windowed runs only)
var _record: Dictionary = {}
var _errors: PackedStringArray = []
var _dice_rng := RandomNumberGenerator.new()


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--leg": _leg = args[i + 1]
			"--battle": _battle = int(args[i + 1])
			"--out": _out_path = args[i + 1]
			"--shot": _shot_path = args[i + 1]
	call_deferred("_run")


func gs() -> Node:
	return root.get_node("/root/GameState")


func sm() -> Node:
	return root.get_node("/root/SaveManager")


func _run() -> void:
	print("[BATTLE_CHECKPOINT] leg=%s battle=%d" % [_leg, _battle])
	_record = {"leg": _leg, "battle": _battle}
	_dice_rng.seed = SEED + _battle
	match _leg:
		"full", "save", "save_phys", "save_reroll", "save_heretic":
			await _play_leg()
		"resume", "resume_phys", "resume_reroll", "resume_heretic":
			await _resume_leg()
		"resume_old":
			_old_save_leg()
		"resume_bad":
			await _fallback_leg()
		_:
			_errors.append("unknown --leg '%s'" % _leg)
	_finish()


# ── full / save ───────────────────────────────────────────────────────────────
func _play_leg() -> void:
	sm().clear_run_save()
	gs().reset_run()
	gs().start_run(SQUAD, OP, SEED)
	gs().advance_to_next_battle()
	gs().current_battle = _battle
	gs().consumables.append("defib_spark")
	if _leg == "save_heretic":
		gs().relics.append("hereticSignal")
	if not await _enter_battle():
		return
	var scene: Node = current_scene
	var heroes: Array = scene.combat_manager.get_hero_states()
	_record["battles_fought_before"] = int(sm().get_battles_fought())
	_record["entry_streams"] = _stream_text(scene)
	_expect(scene._feedback.resume_callout == null, "no resume banner on a fresh battle entry")

	# Round 1: a plain live round (Roll -> tray -> auto targets -> resolve).
	await _live_round(scene)
	_expect(not _read_run_checkpoint().is_empty(), "round 1 wrote a checkpoint")
	# Down a hero, then revive it mid-round 2 with a REAL consumable.
	_kill(heroes[2])
	await _live_round(scene, heroes[2])
	_expect(not bool(heroes[2]["dead"]), "the defib revived hero 3 during round 2")
	_expect(not gs().consumables.has("defib_spark"), "the revive consumable was consumed")
	# Round 3 ends in the checkpoint under test.
	await _live_round(scene)
	if bool(scene.battle_over):
		_errors.append("battle ended before the round-%d checkpoint - pick a sturdier config" % CHECKPOINT_ROUND)
		return
	_expect(int(scene._round_number) == CHECKPOINT_ROUND + 1, "at the ready-to-roll boundary of round %d" % (CHECKPOINT_ROUND + 1))
	_layer_temporary_state(scene)
	# Re-take the checkpoint over the enriched boundary state, exactly as the
	# end-of-round hook does.
	sm().checkpoint_battle_round(BattleCheckpoint.capture(scene, gs()))
	var cp: Dictionary = _read_run_checkpoint()
	_expect(not cp.is_empty(), "the checkpoint is in run.json")
	_expect(int(cp.get("round", 0)) == CHECKPOINT_ROUND + 1, "checkpoint round = %d" % (CHECKPOINT_ROUND + 1))
	_record["checkpoint_state"] = _live_state_text(scene)
	_record["checkpoint_run"] = _normalized_run()
	_record["summoned_in_checkpoint"] = _count_summoned(scene)

	# Round 4's dice. The save legs then quit as soon as they settle: a refresh
	# after seeing these dice must restore them, not reroll them (G-24).
	if _leg == "save_phys":
		await scene._begin_targeting_phase()   # unrigged: whatever physics lands
	else:
		await _roll(scene)
	if _leg == "save_reroll":
		var launched: int = int(scene.dice_tray_3d.thrown_dice_total)
		await scene._protocol._apply_reroll(str(heroes[0].id))
		_expect(int(scene.dice_tray_3d.thrown_dice_total) == launched + 1, "hero reroll uses one live throw")
		gs().consumables.append("phase_scrambler")
		var item: Object = root.get_node("DataManager").get_item("phase_scrambler")
		var target: Dictionary = scene.combat_manager.get_enemy_states()[0]
		scene._protocol._phase_before_item = scene.turn_phase
		await scene._protocol._apply_item_effect(item, target)
		_expect(int(scene.dice_tray_3d.thrown_dice_total) == launched + 2, "enemy item uses one live throw")
		_expect(not gs().consumables.has("phase_scrambler"), "reroll item consumed before checkpoint")
	if _leg == "save_heretic":
		var before_rolls: Dictionary = scene.hero_rolls.duplicate()
		var frozen_id: String = str(heroes[2].id)
		_expect(scene._engine.heretic_signal_available(scene._state), "Heretic Signal is available after the roll")
		var expected: int = 0
		for st in scene.combat_manager.get_hero_states() + scene.combat_manager.get_enemy_states():
			if not bool(st["dead"]) and scene._engine.can_alter_die(st) and (scene.hero_rolls.has(str(st.id)) or scene.enemy_rolls.has(str(st.id))):
				expected += 1
		var launched: int = int(scene.dice_tray_3d.thrown_dice_total)
		await scene._relics.rethrow_all()
		_expect(int(scene.dice_tray_3d.thrown_dice_total) - launched == expected,
			"one live throw per unfrozen die (%d, expected %d)" % [int(scene.dice_tray_3d.thrown_dice_total) - launched, expected])
		_expect(bool(scene._state.heretic_signal_used), "Heretic Signal is used")
		_expect(int(scene.hero_rolls.get(frozen_id, 0)) == int(before_rolls.get(frozen_id, -1)), "the frozen hero die was not re-thrown")
		_record["heretic_before_rolls"] = before_rolls
	_record["round4_hero_rolls"] = scene.hero_rolls.duplicate()
	_record["round4_enemy_rolls"] = scene.enemy_rolls.duplicate()
	_record["post_roll_state"] = _live_state_text(scene)
	_record["post_roll_run"] = _normalized_run()
	var cp_after: Dictionary = _read_run_checkpoint()
	_expect(int(cp_after.get("round", 0)) == CHECKPOINT_ROUND + 1, "rolling did not move the checkpoint's round")
	var pending: Dictionary = BattleCheckpoint.pending_roll_of(str_to_var(str(cp_after.get("state", ""))) if cp_after.has("state") else {})
	_expect(not pending.is_empty(), "the settled dice were written into the checkpoint as a pending roll")
	_expect(_same_rolls(pending.get("hero", {}), scene.hero_rolls) and _same_rolls(pending.get("enemy", {}), scene.enemy_rolls),
		"the pending roll holds exactly the landed dice")
	if _leg != "full":
		return
	await _finish_battle(scene)


# ── resume ────────────────────────────────────────────────────────────────────
func _resume_leg() -> void:
	var stats_before: int = int(sm().get_battles_fought())
	var screen: String = sm().resume_run()
	_expect(screen == "battle", "CONTINUE lands on the battle (got '%s')" % screen)
	if not await _enter_battle():
		return
	var scene: Node = current_scene
	_expect(bool(scene._resumed_from_checkpoint), "the battle was rebuilt from the checkpoint")
	_expect(int(sm().get_battles_fought()) == stats_before, "resume did not count the encounter again")
	# The pending roll comes back PLACED: the dice appear showing the values
	# that had landed, and no die is thrown.
	for i in 300:
		if bool(scene.dice_landed()) and int(scene.turn_phase) != int(scene.PHASE_AWAIT_ROLL):
			break
		await process_frame
	_expect(bool(scene.dice_landed()), "the pending roll's dice are on the table after CONTINUE")
	_expect(int(scene.dice_tray_3d.thrown_dice_total) == 0, "no die was thrown on CONTINUE (placed, not rolled)")
	_record["round4_hero_rolls"] = scene.hero_rolls.duplicate()
	_record["round4_enemy_rolls"] = scene.enemy_rolls.duplicate()
	_record["post_roll_state"] = _live_state_text(scene)
	_record["post_roll_run"] = _normalized_run()
	var shown: Dictionary = {}
	for key in scene.dice_tray_3d._die_by_key:
		var parts: PackedStringArray = str(key).split(":", true, 1)
		shown[str(key)] = int(scene.dice_tray_3d.up_face_numeral(parts[0], parts[1]))
	_record["round4_shown"] = shown
	for key in shown:
		var parts: PackedStringArray = str(key).split(":", true, 1)
		_expect(int(shown[key]) == int(scene._die_value(parts[0], parts[1])), "restored die %s shows the value it acts on" % key)
	if _leg == "resume_heretic":
		_record["heretic_used_after_resume"] = bool(scene._state.heretic_signal_used)
		_record["heretic_available_after_resume"] = bool(scene._engine.heretic_signal_available(scene._state))
		_record["heretic_menu_note"] = str(scene._relics.relic_menu_state()["notes"].get("hereticSignal", ""))
	if _leg in ["resume_phys", "resume_reroll", "resume_heretic"]:
		return
	# The resume banner: shown after a successful restore, real round, non-blocking.
	var callout: Variant = scene._feedback.resume_callout
	_expect(callout != null and is_instance_valid(callout), "the BATTLE RESUMED banner is shown")
	if callout != null and is_instance_valid(callout):
		var text: String = str((callout.find_children("*", "Label", true, false)[0] as Label).text)
		_record["resume_banner"] = text
		_expect(text == "BATTLE RESUMED - ROUND %d" % (CHECKPOINT_ROUND + 1), "banner names the restored round (got '%s')" % text)
		_expect(int(callout.mouse_filter) == int(Control.MOUSE_FILTER_IGNORE), "the banner never blocks input")
		if _shot_path != "":
			await create_timer(0.3).timeout
			root.get_viewport().get_texture().get_image().save_png(_shot_path)
		var zone: Rect2 = scene.center_panel.get_global_rect()
		_expect(zone.encloses(callout.get_global_rect()), "the banner sits inside the combat zone (clear of the unit cards)")
		if scene.roll_button.visible:
			_expect(not callout.get_global_rect().intersects(scene.roll_button.get_global_rect()), "the banner does not cover the Roll button")
	await create_timer(3.0).timeout
	_expect(not is_instance_valid(callout), "the banner clears itself with no dismissal")
	_record["summoned_in_checkpoint"] = _count_summoned(scene)
	await _finish_battle(scene)


# ── resume_old / resume_bad ───────────────────────────────────────────────────
# resume_old: the save leg's file stamped as an older run-save version. Old run
#             saves are DISCARDED cleanly (no migration, Kev 2026-09-21): no
#             CONTINUE, the one-line "older build" notice, the file gone.
# resume_bad: the checkpoint is present but unusable (unknown FORMAT). The run
#             must survive and the battle restart from the battle-ENTRY
#             snapshot, not from the mid-battle run the checkpoint carried —
#             with the SAME RNG stream as the original entry.
func _old_save_leg() -> void:
	var save_io: GDScript = load("res://scripts/autoloads/save_io.gd")
	var path: String = str(sm()._run_save_path)
	var saved: Dictionary = save_io.read_dict(path)
	if saved.is_empty():
		_errors.append("no run save to age (run the save leg first)")
		return
	saved["schema_version"] = int(sm().RUN_SAVE_VERSION) - 1
	save_io.write_dict(path, saved)
	_expect(not sm().has_run_save(), "an older run save offers no CONTINUE")
	_expect(sm().resume_run() == "", "an older run save does not resume")
	_expect(str(sm().take_run_save_notice()) != "", "the player is told the old run could not be restored")
	_expect(save_io.read_dict(path).is_empty(), "the older run save is deleted")


func _fallback_leg() -> void:
	var save_io: GDScript = load("res://scripts/autoloads/save_io.gd")
	var path: String = str(sm()._run_save_path)
	var saved: Dictionary = save_io.read_dict(path)
	if saved.is_empty() or (saved.get("battle_checkpoint", {}) as Dictionary).is_empty():
		_errors.append("no checkpointed run save to degrade (run the save leg first)")
		return
	(saved["battle_checkpoint"] as Dictionary)["format"] = 999
	save_io.write_dict(path, saved)
	var screen: String = sm().resume_run()
	_expect(screen == "battle", "the degraded save still loads onto the battle (got '%s')" % screen)
	if not await _enter_battle():
		return
	var scene: Node = current_scene
	_record["entry_streams"] = _stream_text(scene)
	_expect(not bool(scene._resumed_from_checkpoint), "no checkpoint restore from a %s save" % _leg)
	await create_timer(0.6).timeout
	_expect(scene._feedback.resume_callout == null, "no resume banner when the checkpoint was rejected")
	_expect(int(scene._round_number) == 1, "the battle restarted at round 1 (got %d)" % int(scene._round_number))
	_expect(gs().consumables.has("defib_spark"), "restarted from the ENTRY snapshot (the round-2 revive item is unspent again)")
	_expect(int(scene.turn_phase) == int(scene.PHASE_AWAIT_ROLL), "restarted in the ready-to-roll state")
	var after: Dictionary = sm().peek_run_save()
	_expect(int(after.get("schema_version", 0)) == int(sm().RUN_SAVE_VERSION), "the battle entry re-saved at the current version")
	# Live opening dice are physics (G-24), so they are not compared; the entry
	# RNG streams are (the gate checks entry_streams).
	_expect((after.get("battle_checkpoint", {}) as Dictionary).is_empty(), "the re-saved entry carries no checkpoint")


# ── shared ────────────────────────────────────────────────────────────────────
func _enter_battle() -> bool:
	change_scene_to_file(BATTLE_SCENE)
	for i in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE:
			break
	await create_timer(0.8).timeout
	if current_scene == null or current_scene.scene_file_path != BATTLE_SCENE:
		_errors.append("battle scene did not load")
		return false
	return true


# A live roll whose landed values are pinned through the tray's rig from the
# seeded test RNG, so separate processes land identical dice (physics throws
# are not reproducible across processes).
func _roll(scene: Node) -> void:
	var rig: Dictionary = {}
	for side in ["hero", "enemy"]:
		var states: Array = scene.combat_manager.get_hero_states() if side == "hero" else scene.combat_manager.get_enemy_states()
		for st in states:
			rig["%s:%s" % [side, str(st["id"])]] = _dice_rng.randi_range(1, 20)
	scene.dice_tray_3d.set_rigged_results(rig)
	await scene._begin_targeting_phase()


func _same_rolls(a: Variant, b: Variant) -> bool:
	if not (a is Dictionary) or not (b is Dictionary) or (a as Dictionary).size() != (b as Dictionary).size():
		return false
	for k in a:
		if not (b as Dictionary).has(k) or int((a as Dictionary)[k]) != int((b as Dictionary)[k]):
			return false
	return true


# One live round: Roll (physics tray, landed values pinned), optionally a
# revive consumable on `revive_target`, auto-assign targets, resolve.
func _live_round(scene: Node, revive_target: Variant = null) -> void:
	await _roll(scene)
	if int(scene._round_number) == 1:
		_record["round1_hero_rolls"] = scene.hero_rolls.duplicate()
		_record["round1_enemy_rolls"] = scene.enemy_rolls.duplicate()
	if revive_target is Dictionary:
		var item: Object = root.get_node("/root/DataManager").get_item("defib_spark")
		# The same bookkeeping _on_item_button_pressed does before a pick, so the
		# item returns the board to the phase it was used from.
		scene._protocol._was_in_ready_phase = int(scene.turn_phase) == int(scene.PHASE_READY_TO_END)
		scene._protocol._phase_before_item = int(scene.turn_phase)
		scene._protocol._apply_item_effect(item, revive_target)
	if int(scene.turn_phase) == int(scene.PHASE_TARGETING):
		await scene._auto_assign_pending_targets(false)
	if int(scene.turn_phase) == int(scene.PHASE_READY_TO_END):
		await scene._resolve_current_turn()
	print("[BATTLE_CHECKPOINT] round done -> round_number=%d phase=%s over=%s" % [int(scene._round_number), scene.phase_name(int(scene.turn_phase)), str(scene.battle_over)])


func _kill(state: Dictionary) -> void:
	state["current_hp"] = 0
	state["dead"] = true


# Temporary state that must survive the reload, applied with the engine's own
# helpers. Enemy HP is lowered so both finishing legs WIN deterministically.
func _layer_temporary_state(scene: Node) -> void:
	var cm: Object = scene.combat_manager
	var heroes: Array = cm.get_hero_states()
	var enemies: Array = cm.get_enemy_states().filter(func(s): return not bool(s["dead"]))
	_kill(heroes[1])                                   # a dead hero at the checkpoint
	cm._apply_jam(heroes[0], 9)                        # jammed die
	heroes[0]["last_die_value"] = 17
	if bool(heroes[2]["dead"]):                        # only a LIVING hero's die can be frozen
		heroes[2]["dead"] = false
		heroes[2]["current_hp"] = 20
	cm._freeze_die_state(heroes[2], 1, "ice", true)    # frozen die (repeats 17 next roll)
	heroes[2]["frozen_die_value"] = 17
	for enemy in enemies:
		cm._apply_burn(enemy, 3, 2)
		cm._add_shield_stack(enemy, 5)
		cm._add_rfe_stack(enemy, 2, 2)
		enemy["current_hp"] = 1
	for hero in heroes:
		if not bool(hero["dead"]):
			hero["current_hp"] = int(hero["max_hp"])
	cm._apply_mark(enemies[0])
	cm._add_roll_buff(enemies[0], 2, 2, false)
	scene.protocol_points = 7
	scene._income_debt = 1
	scene._free_nudge_used = {str(heroes[0]["id"]): true}
	# The per-battle relic flag rides along (set here unless this leg is about
	# to use Heretic Signal for real).
	scene._state.heretic_signal_used = _leg != "save_heretic"


func _finish_battle(scene: Node) -> void:
	await scene._on_auto_battle_button_pressed()
	for i in 600:
		await process_frame
		if current_scene != scene:
			break
	await create_timer(0.5).timeout
	_record["after_scene"] = current_scene.scene_file_path if current_scene != null else ""
	_record["last_run_result"] = str(gs().last_run_result)
	var saved: Dictionary = root.get_node("/root/SaveManager").peek_run_save()
	_record["after_screen"] = str(saved.get("screen", "")) if not saved.is_empty() else "<no run.json>"
	_record["after_checkpoint_empty"] = saved.is_empty() or (saved.get("battle_checkpoint", {}) as Dictionary).is_empty()
	_record["after_run"] = _normalized_run()
	_record["battles_fought_after"] = int(sm().get_battles_fought())


# The live battle state in the checkpoint's own encoding (stream positions,
# combat with unit refs, protocol, flags, XP) - equal text = equal state.
func _live_state_text(scene: Node) -> String:
	var cp: Dictionary = BattleCheckpoint.capture(scene, gs())
	return str(cp.get("state", ""))


# Both owned stream positions as exact text (JSON would round the int64s).
func _stream_text(scene: Node) -> String:
	return var_to_str(scene._roll_provider.get_stream_states())


func _normalized_run() -> Dictionary:
	var run: Dictionary = JSON.parse_string(JSON.stringify(gs().to_save_dict()))
	run.erase("run_start_unix")   # wall clock of each process's start_run
	return run


func _count_summoned(scene: Node) -> int:
	return scene.combat_manager.get_enemy_states().filter(func(s): return bool(s.get("summoned", false))).size()


func _read_run_checkpoint() -> Dictionary:
	var saved: Dictionary = sm().peek_run_save()
	return saved.get("battle_checkpoint", {}) as Dictionary if not saved.is_empty() else {}


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_errors.append(what)


func _finish() -> void:
	_record["errors"] = Array(_errors)
	if _out_path != "":
		var f := FileAccess.open(_out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(_record, "  "))
		f.close()
	for e in _errors:
		print("[BATTLE_CHECKPOINT] FAIL - %s" % e)
	print("[BATTLE_CHECKPOINT] leg %s %s" % [_leg, "OK" if _errors.is_empty() else "FAILED"])
	quit(0 if _errors.is_empty() else 1)
