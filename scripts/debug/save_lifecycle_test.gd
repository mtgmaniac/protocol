# Save-system lifecycle gate (G8, G9 + the exactly-once unlock metric).
#
#   godot --headless --path . -s scripts/debug/save_lifecycle_test.gd
#
# G8 LIFECYCLE   — run.json is GONE after victory, defeat and abandon, and
#                  save.json (with its unlocks) survives all three. The two
#                  files have separate lifecycles or the demo can cost a player
#                  their unlocks for finishing a run.
# G9 META        — the tutorial flag and unlocks survive a simulated restart,
#                  and a completed tutorial does not replay.
# EXACTLY ONCE   — battles_fought advances once per encounter ENTERED even
#                  across a resume. INVARIANTS #18 calls this metric farm-proof
#                  by construction; a resumed battle that re-counts its entry
#                  would make reloading an unlock farm.
# TUTORIAL       — no run save is ever written while tutorial_mode is true
#                  (Kev, Q4): the drill is not resumable, so offering CONTINUE
#                  into it would dead-end.
extends SceneTree

const SaveIO = preload("res://scripts/autoloads/save_io.gd")
const SQUAD := ["pulse", "combat", "shield"]
const OP := "facility"
const SEED := 7717

var _failures: Array[String] = []


func gs() -> Node:
	return root.get_node("/root/GameState")


func sm() -> Node:
	return root.get_node("/root/SaveManager")


func run_path() -> String:
	return sm()._run_save_path


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# The profile is deliberately MEMORY-ONLY under --headless (SaveManager's
	# belt-and-braces half of profile isolation), which would make "survives a
	# restart" untestable — load_save() would always return defaults and every
	# check here would pass or fail for the wrong reason. Turn the disk on for
	# this rig only: DevContext already resolved _save_path to
	# dev_profile_save.json at boot, so the REAL user profile stays untouchable
	# (and verify_gate's isolation fingerprint proves it after the suite).
	var disk_was: bool = sm()._disk_enabled
	sm()._disk_enabled = true
	sm().dev_reset_profile()

	# Each ending runs TWICE: once files-only, once with the localStorage mirror
	# live. Without the second pass the mirror-delete branch is unreachable off
	# web, so "the run save is gone" was only ever asserted about the files —
	# and a finished run whose mirror survived would come back with CONTINUE on
	# the menu, on the exact platform this whole system exists for.
	for mirrored in [false, true]:
		_use_mirror(mirrored)
		_test_run_save_cleared_on("victory", mirrored)
		_test_run_save_cleared_on("defeat", mirrored)
		_test_run_save_cleared_on_abandon(mirrored)
	_use_mirror(false)
	_test_meta_survives_restart()
	_test_tutorial_not_replayed()
	_test_tutorial_writes_no_run_save()
	_test_battles_fought_exactly_once()
	sm().clear_run_save()
	sm()._disk_enabled = disk_was

	if _failures.is_empty():
		print("[SAVE_LIFECYCLE] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[SAVE_LIFECYCLE] " + failure)
		print("[SAVE_LIFECYCLE] FAIL - %s" % failure)
	print("[SAVE_LIFECYCLE] FAIL - %d check(s)" % _failures.size())
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _mode(mirrored: bool) -> String:
	return " (web mirror)" if mirrored else " (files only)"


## Mirrors battle_scene._init_live_battle's entry block exactly. Kept as one
## helper so the gate exercises the real rule rather than a paraphrase of it.
func _enter_battle_like_battle_scene() -> void:
	if not gs().battle_entry_counted:
		if not gs().tutorial_mode:
			sm().record_battle_entered()
		gs().derive_battle_rng_seed()
		gs().battle_entry_counted = true


## A live-ish run parked mid-way, with a checkpoint on disk.
func _start_checkpointed_run() -> void:
	sm().clear_run_save()
	gs().reset_run()
	gs().start_run(SQUAD, OP, SEED)
	gs().advance_to_next_battle()
	gs().derive_battle_rng_seed()
	sm().checkpoint_run("battle")
	_check(sm().has_run_save(), "fixture: the checkpoint did not land on disk")


## Every trace of the run save, not just the primary — a .bak or a mirror copy
## left behind would resurrect an abandoned run on the next load. The mirror is
## checked BY KEY as well as through has_run_save(), so a copy that survives but
## happens not to win the seq comparison is still a failure: it would win later,
## once the files were gone.
func _any_run_save_remains() -> bool:
	if sm().has_run_save():
		return true
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(run_path() + suffix):
			return true
	if SaveIO.web_store_override != null:
		var key: String = SaveIO.WEB_KEY_PREFIX + run_path().get_file()
		if (SaveIO.web_store_override as Dictionary).has(key):
			return true
	return false


# ── G8: lifecycle ─────────────────────────────────────────────────────────────

## Swaps a dictionary in for window.localStorage so the mirror branches run on
## a platform that has no localStorage. null restores the real (absent) store.
func _use_mirror(enabled: bool) -> void:
	SaveIO.web_store_override = {} if enabled else null
	SaveIO.web_store_fails = false


func _test_run_save_cleared_on(result: String, mirrored: bool = false) -> void:
	_start_checkpointed_run()
	# Unlocks that must outlive the run end.
	sm().data["unlocks"]["heroes_new"] = ["ghost"]
	var boss_relics_before: Array = (sm().get_unlocked_boss_relics() as Array).duplicate()
	var gates_before: int = sm().get_item_gates_awarded()
	var battles_before: int = sm().get_battles_fought()

	gs().finish_run(result)

	_check(not _any_run_save_remains(),
		"G8/%s%s: a run save survived the run end (CONTINUE would resume a finished run)" % [result, _mode(mirrored)])
	# The profile must be intact AND still on disk.
	_check(sm().get_battles_fought() == battles_before,
		"G8/%s%s: battles_fought changed at run end" % [result, _mode(mirrored)])
	_check(sm().get_item_gates_awarded() >= gates_before,
		"G8/%s%s: awarded item gates went BACKWARDS at run end" % [result, _mode(mirrored)])
	for relic_id in boss_relics_before:
		_check((sm().get_unlocked_boss_relics() as Array).has(relic_id),
			"G8/%s%s: boss relic %s was lost at run end" % [result, _mode(mirrored), str(relic_id)])
	_check(FileAccess.file_exists(sm()._save_path),
		"G8/%s%s: the profile file was removed along with the run save" % [result, _mode(mirrored)])


func _test_run_save_cleared_on_abandon(mirrored: bool = false) -> void:
	_start_checkpointed_run()
	sm().data["unlocks"]["heroes"] = ["combat", "engineer", "medic", "pulse", "avalanche"]
	sm().save()
	var heroes_before: Array = (sm().data["unlocks"]["heroes"] as Array).duplicate()
	var tutorial_before: bool = sm().is_tutorial_done()

	# What ABANDON RUN does. reset_run() is the single choke point.
	gs().reset_run()

	_check(not _any_run_save_remains(), "G8/abandon%s: a run save survived ABANDON RUN" % _mode(mirrored))
	_check(gs().selected_operation_id == "", "G8/abandon: the live run was not cleared")
	# The four fields reset_run() used to miss.
	_check(not gs().dead_mans_hand_used, "G8/abandon: dead_mans_hand_used leaked past reset_run")
	_check((gs().pending_flagged_comp as Dictionary).is_empty(),
		"G8/abandon: pending_flagged_comp leaked past reset_run")
	_check(gs().pending_flagged_modifier_id == "",
		"G8/abandon: pending_flagged_modifier_id leaked past reset_run")
	_check((gs().battle_review_state as Dictionary).is_empty(),
		"G8/abandon: battle_review_state leaked past reset_run")

	sm().load_save()
	_check(str(sm().data["unlocks"]["heroes"]) == str(heroes_before),
		"G8/abandon: unlocked heroes did not survive ABANDON RUN")
	_check(sm().is_tutorial_done() == tutorial_before,
		"G8/abandon: the tutorial flag did not survive ABANDON RUN")


# ── G9: meta persistence across a restart ─────────────────────────────────────

## Reloading the profile from disk is what a relaunch does to SaveManager: the
## autoload is reconstructed and load_save() runs against whatever is on disk.
func _test_meta_survives_restart() -> void:
	sm().dev_reset_profile()
	sm().mark_tutorial_done()
	sm().unlock_boss_relic_for_op("facility")
	sm().data["unlocks"]["heroes"] = ["combat", "engineer", "medic", "pulse", "avalanche", "shield"]
	sm().data["unlocks"]["operations"] = ["facility", "hive"]
	sm().data["unlocks"]["item_gates_awarded"] = 2
	sm().data["onboarding"]["primers_seen"] = ["burn", "mark"]
	sm().data["stats"]["battles_fought"] = 17
	sm().save()

	sm().load_save()

	_check(sm().is_tutorial_done(), "G9: tutorial_done did not survive a restart")
	_check((sm().get_unlocked_boss_relics() as Array).has("salvageRig"),
		"G9: a boss relic did not survive a restart")
	_check((sm().data["unlocks"]["heroes"] as Array).has("shield"),
		"G9: an unlocked hero did not survive a restart")
	_check((sm().data["unlocks"]["operations"] as Array).has("hive"),
		"G9: an unlocked operation did not survive a restart")
	_check(sm().get_item_gates_awarded() == 2,
		"G9: awarded item gates did not survive a restart (got %d)" % sm().get_item_gates_awarded())
	_check(sm().is_primer_seen("burn"), "G9: a seen primer did not survive a restart")
	_check(sm().get_battles_fought() == 17,
		"G9: battles_fought did not survive a restart (got %d)" % sm().get_battles_fought())


func _test_tutorial_not_replayed() -> void:
	# main_menu gates the first-run prompt on exactly this call, so a flag that
	# survives the restart is the whole of "the tutorial does not replay".
	sm().load_save()
	_check(sm().is_tutorial_done(),
		"G9: is_tutorial_done() read false after a restart - the drill would replay")


# ── Tutorial writes no run save ───────────────────────────────────────────────

func _test_tutorial_writes_no_run_save() -> void:
	sm().clear_run_save()
	gs().reset_run()
	gs().start_tutorial_run(false)
	_check(gs().tutorial_mode, "fixture: start_tutorial_run did not set tutorial_mode")
	# Every checkpoint site, including the one battle_scene fires on entry.
	sm().checkpoint_run("battle")
	sm().checkpoint_run("reward")
	_check(not _any_run_save_remains(),
		"TUTORIAL: a run save was written during the drill - CONTINUE would resume an unresumable run")
	gs().reset_run()


# ── The unlock metric, exactly once across a resume ───────────────────────────

func _test_battles_fought_exactly_once() -> void:
	sm().clear_run_save()
	gs().reset_run()
	gs().start_run(SQUAD, OP, SEED)
	gs().advance_to_next_battle()
	var before: int = sm().get_battles_fought()

	# First entry: exactly what battle_scene._init_live_battle does.
	_enter_battle_like_battle_scene()
	sm().checkpoint_run("battle")
	_check(sm().get_battles_fought() == before + 1,
		"fixture: the first battle entry did not count")

	# The tab dies and the player hits CONTINUE, twice over. Each resume also
	# writes the routing checkpoint SceneManager.go_to_battle() writes, so the
	# flag has to survive being re-saved by a call site that knows nothing
	# about it — which is the point of it being run state and not an argument.
	for attempt in 2:
		# The flag must come back from the FILE. Asserted two ways, because
		# reading it off the live GameState alone proves nothing: this process
		# never restarted, so a save that dropped the field entirely would still
		# leave the right value sitting in memory and the check would pass.
		var stored: Dictionary = sm().peek_run_save().get("run", {}) as Dictionary
		_check(stored.has("battle_entry_counted"),
			"EXACTLY ONCE: resume %d - battle_entry_counted is not in the saved run at all" % attempt)
		_check(bool(stored.get("battle_entry_counted", false)),
			"EXACTLY ONCE: resume %d - the saved run says this entry was never counted" % attempt)
		# A fresh process starts at defaults; wipe the in-memory value so the
		# restore below is doing the work.
		gs().battle_entry_counted = false
		var screen: String = sm().resume_run()
		_check(screen == "battle", "resume %d returned screen '%s', expected battle" % [attempt, screen])
		_check(gs().battle_entry_counted,
			"EXACTLY ONCE: resume %d did not restore battle_entry_counted" % attempt)
		sm().checkpoint_run("battle")  # the routing checkpoint
		_enter_battle_like_battle_scene()

	_check(sm().get_battles_fought() == before + 1,
		"EXACTLY ONCE: battles_fought is %d after two resumes, expected %d - reloading farms unlock gates"
		% [sm().get_battles_fought(), before + 1])

	# And the NEXT genuine battle still counts: advance_to_next_battle clears
	# the flag, so the same entry code counts again.
	gs().advance_to_next_battle()
	_check(not gs().battle_entry_counted,
		"EXACTLY ONCE: advance_to_next_battle left the previous battle's entry flag set")
	_enter_battle_like_battle_scene()
	_check(sm().get_battles_fought() == before + 2,
		"EXACTLY ONCE: the next real encounter failed to count (%d, expected %d)"
		% [sm().get_battles_fought(), before + 2])
	sm().clear_run_save()
