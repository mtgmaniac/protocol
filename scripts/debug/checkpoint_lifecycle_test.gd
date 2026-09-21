# Battle-checkpoint LIFECYCLE regression (save system, 2026-09-21).
#
#   godot --headless --path . -s scripts/debug/checkpoint_lifecycle_test.gd
#
# A round-level battle checkpoint must never outlive its battle. For every
# permanent way out of a battle, this plants a real checkpoint (through the
# same SaveManager calls battle_scene makes) and asserts that afterwards
# nothing can restore it: not the file, not the in-memory pending restore, not
# the cached battle-entry run a stale scene could write beside.
#   victory (mid-run)   -> clear_battle_checkpoint: entry snapshot, no checkpoint
#   victory (final)     -> finish_run: run.json gone
#   defeat              -> finish_run: run.json gone
#   abandon / quit      -> reset_run: run.json gone
#   rewards transition  -> checkpoint_run("reward"): no checkpoint, and a late
#                          round checkpoint from the finished scene is a no-op
#   new run             -> the new battle's entry carries no checkpoint
#   tutorial            -> never writes one; finishing it leaves none
#   CONTINUE            -> the pending restore is handed out exactly once
# (Closing the browser before the first round's checkpoint restarts the battle
# from its entry — covered by the `battle checkpoint` gate.)
extends SceneTree

const BattleCheckpoint := preload("res://scripts/battle/battle_checkpoint.gd")
const SQUAD := ["combat", "medic", "breaker"]
const OP := "facility"
const SEED := 55001

var _failures: PackedStringArray = []


func gs() -> Node:
	return root.get_node("/root/GameState")


func sm() -> Node:
	return root.get_node("/root/SaveManager")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# victory mid-run
	_plant("victory mid-run")
	sm().clear_battle_checkpoint()
	var saved: Dictionary = sm().peek_run_save()
	_expect(not saved.is_empty() and str(saved.get("screen")) == "battle", "victory mid-run: the run save survives")
	_expect((saved.get("battle_checkpoint", {}) as Dictionary).is_empty(), "victory mid-run: checkpoint cleared")
	_expect(int((saved.get("run", {}) as Dictionary).get("current_battle", 0)) == 1, "victory mid-run: the entry snapshot remains")
	_expect(sm().take_pending_battle_restore().is_empty(), "victory mid-run: nothing pending")

	# rewards transition (the normal post-battle path)
	_plant("rewards")
	gs().prepare_battle_rewards()
	sm().checkpoint_run("reward")
	saved = sm().peek_run_save()
	_expect(str(saved.get("screen")) == "reward", "rewards: the run save moved to the reward node")
	_expect((saved.get("battle_checkpoint", {}) as Dictionary).is_empty(), "rewards: no checkpoint on the reward node")
	sm().checkpoint_battle_round(_fake_checkpoint())
	_expect((sm().peek_run_save().get("battle_checkpoint", {}) as Dictionary).is_empty(),
		"rewards: a late round checkpoint from the finished battle is a no-op")

	# final-battle victory, defeat, abandon
	for exit in ["final victory", "defeat", "abandon"]:
		_plant(exit)
		match exit:
			"final victory": gs().finish_run("victory")
			"defeat": gs().finish_run("defeat")
			"abandon": gs().reset_run()
		_expect(sm().peek_run_save().is_empty() and not sm().has_run_save(), "%s: no run save / no CONTINUE" % exit)
		_expect(sm().take_pending_battle_restore().is_empty(), "%s: nothing pending" % exit)
		sm().checkpoint_battle_round(_fake_checkpoint())
		_expect(sm().peek_run_save().is_empty(), "%s: a late round checkpoint cannot resurrect the run" % exit)

	# new run after a checkpointed one
	_plant("new run")
	gs().reset_run()
	gs().start_run(SQUAD, OP, SEED + 1)
	gs().advance_to_next_battle()
	sm().checkpoint_run("battle")
	_expect((sm().peek_run_save().get("battle_checkpoint", {}) as Dictionary).is_empty(), "new run: its battle entry carries no checkpoint")

	# tutorial: never checkpoints, and finishing it leaves nothing
	sm().clear_run_save()
	gs().reset_run()
	gs().start_run(["combat", "engineer", "medic"], OP, -1, true)
	gs().advance_to_next_battle()
	sm().checkpoint_run("battle")
	sm().checkpoint_battle_round(_fake_checkpoint())
	_expect(sm().peek_run_save().is_empty(), "tutorial: no run save or checkpoint is ever written")
	gs().reset_run()   # what training_flow.finish / the header back button do
	_expect(sm().peek_run_save().is_empty(), "tutorial: leaving it leaves no save")

	# CONTINUE hands the validated checkpoint to the battle exactly once
	_plant("continue")
	_expect(sm().resume_run() == "battle", "continue: lands on the battle")
	_expect(not sm().take_pending_battle_restore().is_empty(), "continue: the checkpoint is pending for the battle scene")
	_expect(sm().take_pending_battle_restore().is_empty(), "continue: ...and only once")
	gs().reset_run()

	sm().clear_run_save()
	if _failures.is_empty():
		print("[CHECKPOINT_LIFECYCLE] PASS")
		quit(0)
		return
	for f in _failures:
		print("[CHECKPOINT_LIFECYCLE] FAIL - %s" % f)
	quit(1)


# A live run at battle 1 with a round checkpoint on disk, written through the
# same calls battle_scene makes (entry checkpoint, then the round checkpoint).
func _plant(label: String) -> void:
	sm().clear_run_save()
	gs().reset_run()
	gs().start_run(SQUAD, OP, SEED)
	gs().advance_to_next_battle()
	gs().derive_battle_rng_seed()
	gs().battle_entry_counted = true
	sm().checkpoint_run("battle")
	sm().checkpoint_battle_round(_fake_checkpoint())
	var cp: Dictionary = sm().peek_run_save().get("battle_checkpoint", {}) as Dictionary
	if cp.is_empty():
		_failures.append("%s: fixture - the round checkpoint was not written" % label)


# A structurally valid checkpoint (it passes BattleCheckpoint.decode) for the
# current run; the lifecycle only cares whether it survives, not its combat.
func _fake_checkpoint() -> Dictionary:
	var state := {
		"combat": {
			"hero_states": [{"id": SQUAD[0], "unit": {"kind": "hero", "id": SQUAD[0]}}],
			"enemy_states": [{"id": "scrap_drone#1", "unit": {"kind": "enemy", "name": "Scrap Drone", "starts_cloaked": false}}],
		},
		"streams": {"d20": 1, "pick": 2}, "protocol_points": 1, "income_debt": 0,
		"free_nudge_used": {}, "root_access_used": false, "round_number": 2,
		"battle_effects": {}, "xp": {"effective_rolls": {}, "end_alive": {}},
	}
	return {"format": BattleCheckpoint.FORMAT, "battle": int(gs().current_battle), "round": 2,
		"run": gs().to_save_dict(), "state": var_to_str(state)}


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)
