# Resume guard regression (G-48, Kev 2026-10-06).
#
#   godot --headless --path . -s scripts/debug/resume_guard_test.gd -- \
#       --leg <leg> --out <dir> [--restore] [--resume-guard-break=<mode>]
#
# One leg each of scripts/checks/resume_guard_gate.py, which runs them as
# SEPARATE Godot processes: "the next launch" is only honest in a fresh process.
# Every leg that presses CONTINUE presses the REAL menu button, because the bug
# this gate also pins (a mid-battle CONTINUE that never restored its round) hid
# in the menu's routing, which the older gates bypassed.
#
#   unit        in-process rules: the progress rule, a marker from another run,
#               no earlier save, a battle restored from its entry, the web heal
#               keeping the previous screen
#   seed        plays a run to "rewards after battle 1" -> battle 2 (through the
#               real routing) -> one round, so the run save holds a round
#               checkpoint and run.json.prev the rewards; snapshots the files
#   normal      menu (no option) -> CONTINUE -> the battle is rebuilt AT its
#               round -> the marker is set while loading and clear once loaded
#   progress    menu (still no option) -> CONTINUE with an error raised during
#               the load -> the marker stays -> a round resolves -> it clears
#   hang        menu -> CONTINUE -> the process dies as the screen loads
#   after_hang  menu: CONTINUE, RESUME EARLIER POINT and its line, ABANDON RUN,
#               the state code still exports; RESUME EARLIER POINT puts the
#               rewards back and says so; CONTINUE resumes them; the battle the
#               profile already counted is not counted twice
#   auto_blocked  web display recovery, the launch after `hang`: the page
#               reloaded itself, but the last resume never finished loading, so
#               the menu does NOT resume by itself and still offers its options
#   auto        web display recovery from a healthy save: the menu resumes with
#               no tap, through CONTINUE's own path (round restored, marker set
#               while loading and clear once loaded, flag used up)
# --restore copies the seed leg's snapshot back first. Each leg writes
# <dir>/<leg>.json: {"errors": [...], ...}. The menu legs (normal, hang,
# after_hang) also run windowed from a headless seed's snapshot; with --shots,
# after_hang saves <dir>/menu_option.png and menu_restored.png. seed and
# progress play a round and are headless only (a windowed round stops at the
# first keyword primer).
extends SceneTree

const ResumeGuard := preload("res://scripts/autoloads/resume_guard.gd")
const MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const REWARD_SCENE := "res://scenes/ui/RewardScreen.tscn"
const SQUAD := ["combat", "medic", "engineer"]
const OP := "facility"
const SEED := 61006
const SUFFIXES := ["", ".bak", ".tmp", ".prev"]

var _leg: String = ""
var _out_dir: String = ""
var _restore: bool = false
var _shots: bool = false
var _record: Dictionary = {}
var _errors: PackedStringArray = []
var _dice_rng := RandomNumberGenerator.new()


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--leg": _leg = args[i + 1]
			"--out": _out_dir = args[i + 1]
			"--restore": _restore = true
			"--shots": _shots = true
	call_deferred("_run")


func gs() -> Node:
	return root.get_node("/root/GameState")


func sm() -> Node:
	return root.get_node("/root/SaveManager")


func run_path() -> String:
	return str(sm().get("_run_save_path"))


func guard_path() -> String:
	return str(sm().get("_resume_guard_path"))


func _run() -> void:
	root.size = Vector2i(1080, 2400)
	root.get_node("/root/AudioManager").set_suppressed(true)
	(sm().get("data") as Dictionary)["tutorial_done"] = true
	_dice_rng.seed = SEED
	_record = {"leg": _leg}
	if _restore:
		_copy_saves(_out_dir.path_join("snapshot"), "")
	match _leg:
		"unit": _unit_leg()
		"seed": await _seed_leg()
		"normal": await _normal_leg()
		"progress": await _progress_leg()
		"hang": await _hang_leg()
		"after_hang": await _after_hang_leg()
		"auto_blocked": await _auto_blocked_leg()
		"auto": await _auto_leg()
		_: _errors.append("unknown --leg '%s'" % _leg)
	_record["errors"] = Array(_errors)
	var file := FileAccess.open(_out_dir.path_join("%s.json" % _leg), FileAccess.WRITE)
	file.store_string(JSON.stringify(_record, "  "))
	file.close()
	print("[RESUME_GUARD] leg=%s %s" % [_leg, "clean" if _errors.is_empty() else "ERRORS: " + "; ".join(_errors)])
	if current_scene != null:
		current_scene.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_errors.append(what)


# ── Fixtures ──────────────────────────────────────────────────────────────────

## Copies the run save and the marker (every copy of each) between user:// and
## a snapshot folder. An empty `from_dir` / `to_dir` means user://.
func _copy_saves(from_dir: String, to_dir: String) -> void:
	if to_dir != "":
		DirAccess.make_dir_recursive_absolute(to_dir)
	for base in [run_path(), guard_path()]:
		for suffix in SUFFIXES:
			var name: String = str(base).get_file() + str(suffix)
			var live: String = ProjectSettings.globalize_path(str(base) + str(suffix))
			var src: String = live if from_dir == "" else from_dir.path_join(name)
			var dst: String = live if to_dir == "" else to_dir.path_join(name)
			if FileAccess.file_exists(dst):
				DirAccess.remove_absolute(dst)
			if FileAccess.file_exists(src):
				DirAccess.copy_absolute(src, dst)


func _shot(name: String) -> void:
	if not _shots or DisplayServer.get_name() == "headless":
		return
	await create_timer(0.6).timeout
	root.get_texture().get_image().save_png(_out_dir.path_join(name + ".png"))


func _guard_on_disk() -> Dictionary:
	return SaveIO.read_dict(guard_path())


func _marker_set() -> bool:
	return bool(_guard_on_disk().get("active", false))


func _point(payload: Dictionary) -> String:
	var point: Dictionary = ResumeGuard.point_of(payload)
	return "%s/%d/%d" % [point["screen"], point["battle"], point["round"]]


func _find_button(text: String) -> Button:
	if current_scene == null:
		return null
	for node in current_scene.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node
	return null


func _has_label(text: String) -> bool:
	if current_scene == null:
		return false
	for node in current_scene.find_children("*", "Label", true, false):
		if (node as Label).text == text:
			return true
	return false


## Boots the menu the way a launch does and waits out the logo, so the buttons
## are live.
func _open_menu() -> void:
	change_scene_to_file(MENU_SCENE)
	for i in 600:
		await process_frame
		var begin: Button = _find_button("BEGIN")
		if current_scene != null and current_scene.scene_file_path == MENU_SCENE and begin != null and not begin.disabled:
			return
	_errors.append("the menu never became usable")


func _wait_scene(path: String, frames: int = 900) -> bool:
	for i in frames:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == path and current_scene.is_node_ready():
			return true
	return false


func _press_continue() -> bool:
	var button: Button = _find_button("CONTINUE")
	if button == null or button.disabled:
		_errors.append("no usable CONTINUE on the menu")
		return false
	button.pressed.emit()
	return true


## One live round: rigged landings, auto targets, resolve.
func _play_round(scene: Node) -> void:
	var rig: Dictionary = {}
	for side in ["hero", "enemy"]:
		var states: Array = scene.combat_manager.get_hero_states() if side == "hero" else scene.combat_manager.get_enemy_states()
		for st in states:
			rig["%s:%s" % [side, str(st["id"])]] = _dice_rng.randi_range(3, 9)
	scene.dice_tray_3d.set_rigged_results(rig)
	await scene._begin_targeting_phase()
	if int(scene.turn_phase) == int(scene.PHASE_TARGETING):
		await scene._auto_assign_pending_targets(false)
	if int(scene.turn_phase) == int(scene.PHASE_READY_TO_END):
		await scene._resolve_current_turn()


func _expected() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_out_dir.path_join("seed.json")))
	if parsed is Dictionary:
		return parsed
	_errors.append("no seed record to compare against")
	return {}


# ── unit ──────────────────────────────────────────────────────────────────────
func _unit_leg() -> void:
	var marker := {"screen": "battle", "battle": 4, "round": 3}
	_expect(not ResumeGuard.moved_past(marker, {"screen": "battle", "battle": 4, "round": 3}), "the same point is not past the marker")
	_expect(not ResumeGuard.moved_past(marker, {"screen": "battle", "battle": 4, "round": 0}), "a battle restarted from its entry is not past the marker")
	_expect(ResumeGuard.moved_past(marker, {"screen": "battle", "battle": 4, "round": 4}), "a later checkpoint round is past the marker")
	_expect(ResumeGuard.moved_past(marker, {"screen": "battle", "battle": 5, "round": 0}), "a later battle is past the marker")
	_expect(ResumeGuard.moved_past(marker, {"screen": "reward", "battle": 4, "round": 0}), "a different screen is past the marker")

	# A run parked on battle 2, with the rewards after battle 1 as its earlier point.
	_unit_fixture()
	var current: Dictionary = SaveIO.read_dict(run_path())
	_expect(_point(SaveIO._read_file(ResumeGuard.prev_path(run_path()))) == "reward/1/0", "fixture: .prev holds the rewards after battle 1")
	_expect(_point(current) == "battle/2/0", "fixture: the run save is battle 2")

	# No marker: no option.
	_expect(sm().earlier_point_offer().is_empty(), "no marker, no option")
	# A marker from ANOTHER run is ignored and cleared.
	SaveIO.write_dict(guard_path(), {"active": true, "screen": "battle", "battle": 2, "round": 0, "run_seed": "not-this-run"})
	_expect(sm().earlier_point_offer().is_empty(), "a marker from another run offers nothing")
	_expect(not _marker_set(), "a marker from another run is cleared")
	# A marker the save has already moved past is ignored and cleared.
	SaveIO.write_dict(guard_path(), {"active": true, "screen": "reward", "battle": 1, "round": 0, "run_seed": ResumeGuard.run_seed_of(current)})
	_expect(sm().earlier_point_offer().is_empty(), "a marker the run has moved past offers nothing")
	_expect(not _marker_set(), "a marker the run has moved past is cleared")
	# The real case: this run, this point.
	SaveIO.write_dict(guard_path(), {"active": true, "screen": "battle", "battle": 2, "round": 0, "run_seed": ResumeGuard.run_seed_of(current)})
	_expect(str(sm().earlier_point_offer().get("label", "")) == "the rewards after battle 1", "a set marker offers the rewards after battle 1")
	# ...but not without an earlier save.
	ResumeGuard.drop_previous(run_path())
	_expect(sm().earlier_point_offer().is_empty(), "a set marker with no earlier save offers nothing")
	_expect(not sm().restore_earlier_point(), "nothing to restore without an earlier save")

	# A battle is restored from its ENTRY: a round checkpoint in the earlier save
	# (the web heal can keep one) never comes back.
	_unit_fixture()
	var staged: Dictionary = SaveIO.read_dict(run_path())
	staged["screen"] = "battle"
	(staged["run"] as Dictionary)["current_battle"] = 1
	staged["battle_checkpoint"] = {"format": 1, "battle": 1, "round": 5, "run": {"x": 1}, "state": "{}"}
	staged[SaveIO.SEQ_KEY] = 1
	SaveIO.write_exact(ResumeGuard.prev_path(run_path()), staged)
	SaveIO.write_dict(guard_path(), {"active": true, "screen": "battle", "battle": 2, "round": 0, "run_seed": ResumeGuard.run_seed_of(current)})
	_expect(sm().restore_earlier_point(), "an earlier battle save restores")
	var restored: Dictionary = SaveIO.read_dict(run_path())
	_expect(_point(restored) == "battle/1/0" and (restored.get("battle_checkpoint", {}) as Dictionary).is_empty(), "a restored battle starts from its entry (got %s)" % _point(restored))
	_expect(str(sm().take_run_save_notice()) == "Restored the start of battle 1.", "the notice names the restored battle")

	# Web: the page froze right after the battle 2 save, so only the mirror has
	# it and the file is still the rewards. Healing must keep the rewards.
	sm().clear_run_save()
	SaveIO.web_store_override = {}
	_unit_fixture()
	var rewards_text: String = FileAccess.get_file_as_string(ResumeGuard.prev_path(run_path()))
	var raw := FileAccess.open(run_path(), FileAccess.WRITE)
	raw.store_string(rewards_text)
	raw.close()
	ResumeGuard.drop_previous(run_path())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_path() + ".bak"))
	sm().set("_saved_screen_key", "")
	_expect(_point(sm().peek_run_save()) == "battle/2/0", "web: the mirror's newer save wins the load")
	_expect(_point(SaveIO._read_file(run_path())) == "battle/2/0", "web: the file is healed to the newer save")
	_expect(_point(SaveIO._read_file(ResumeGuard.prev_path(run_path()))) == "reward/1/0", "web: the heal keeps the previous screen as the earlier point")
	SaveIO.web_store_override = null
	sm().clear_run_save()
	_expect(not FileAccess.file_exists(ResumeGuard.prev_path(run_path())), "ending the run removes the earlier save")
	gs().reset_run()


## Rewards after battle 1, then the routing save into battle 2.
func _unit_fixture() -> void:
	sm().clear_run_save()
	gs().reset_run()
	gs().start_run(SQUAD, OP, SEED)
	gs().advance_to_next_battle()
	gs().derive_battle_rng_seed()
	gs().battle_entry_counted = true
	gs().prepare_battle_rewards()
	sm().checkpoint_run("reward")
	gs().advance_to_next_battle()
	sm().checkpoint_run("battle")
	sm().checkpoint_run("battle")


# ── seed ──────────────────────────────────────────────────────────────────────
func _seed_leg() -> void:
	sm().clear_run_save()
	SaveIO.erase(guard_path())
	gs().reset_run()
	gs().start_run(SQUAD, OP, SEED)
	gs().advance_to_next_battle()
	gs().derive_battle_rng_seed()
	gs().battle_entry_counted = true
	gs().prepare_battle_rewards()
	sm().checkpoint_run("reward")
	gs().advance_to_next_battle()
	# The real routing: its save, then the battle's own entry save.
	root.get_node("/root/SceneManager").go_to_battle()
	if not await _wait_scene(BATTLE_SCENE):
		_errors.append("battle scene did not load")
		return
	await create_timer(0.8).timeout
	var scene: Node = current_scene
	await _play_round(scene)
	_expect(not bool(scene.battle_over), "fixture: the battle is still going after round 1")
	var run_save: Dictionary = SaveIO.read_dict(run_path())
	var prev: Dictionary = SaveIO._read_file(ResumeGuard.prev_path(run_path()))
	_record["round"] = int(scene._round_number)
	_record["point"] = _point(run_save)
	_expect(_point(run_save) == "battle/2/%d" % int(scene._round_number), "the run save holds this round's checkpoint (got %s)" % _point(run_save))
	_expect(_point(prev) == "reward/1/0", "run.json.prev holds the previous screen, the rewards after battle 1 (got %s)" % _point(prev))
	_expect(not _marker_set(), "playing without CONTINUE writes no marker")
	scene.queue_free()
	await process_frame
	_copy_saves("", _out_dir.path_join("snapshot"))


# ── normal ────────────────────────────────────────────────────────────────────
func _normal_leg() -> void:
	var want: Dictionary = _expected()
	await _open_menu()
	_expect(_find_button("RESUME EARLIER POINT") == null, "no RESUME EARLIER POINT before any resume")
	if not _press_continue():
		return
	if not await _wait_scene(BATTLE_SCENE):
		_errors.append("CONTINUE did not reach the battle")
		return
	_expect(_marker_set(), "the marker is set while the resumed screen loads")
	var marker: Dictionary = _guard_on_disk()
	_expect(str(marker.get("screen", "")) == "battle" and int(marker.get("battle", 0)) == 2 and int(marker.get("round", 0)) == int(want.get("round", -1)),
		"the marker names the point resumed (got %s)" % JSON.stringify(marker))
	var scene: Node = current_scene
	_expect(bool(scene.get("_resumed_from_checkpoint")), "CONTINUE from the real menu rebuilt the battle from its round checkpoint")
	_expect(int(scene._round_number) == int(want.get("round", -1)), "resumed at round %d (got %d)" % [int(want.get("round", -1)), int(scene._round_number)])
	await create_timer(float(sm().RESUME_SETTLE_SECS) + 1.0).timeout
	_expect(not _marker_set(), "the marker clears once the screen has loaded cleanly")
	_expect(_point(SaveIO.read_dict(run_path())) == str(want.get("point", "")), "a clean resume leaves the run save where it was")


# ── progress ──────────────────────────────────────────────────────────────────
func _progress_leg() -> void:
	var want: Dictionary = _expected()
	await _open_menu()
	_expect(_find_button("RESUME EARLIER POINT") == null, "a normal resume shows no RESUME EARLIER POINT on the next launch")
	_expect(not _has_label(ResumeGuard.LINE), "a normal resume shows no 'didn't get past loading' line")
	if not _press_continue():
		return
	# An error on the way in: the load is not clean, so only progress may clear.
	push_error("RESUME_GUARD_TEST: error raised while the resumed screen loads")
	if not await _wait_scene(BATTLE_SCENE):
		_errors.append("CONTINUE did not reach the battle")
		return
	await create_timer(float(sm().RESUME_SETTLE_SECS) + 1.0).timeout
	_expect(_marker_set(), "an error during the load keeps the marker set")
	var scene: Node = current_scene
	await _play_round(scene)
	_expect(not bool(scene.battle_over), "fixture: the battle is still going after the resumed round")
	_expect(int(scene._round_number) == int(want.get("round", -1)) + 1, "the resumed round resolved")
	_expect(not _marker_set(), "a save past the resumed round clears the marker")


# ── hang ──────────────────────────────────────────────────────────────────────
func _hang_leg() -> void:
	await _open_menu()
	if not _press_continue():
		return
	# The load "hangs": the process ends the moment the screen arrives, before
	# it can be counted as loaded. The marker must already be on disk.
	if not await _wait_scene(BATTLE_SCENE):
		_errors.append("CONTINUE did not reach the battle")
	_record["marker_set"] = _marker_set()


# ── web display recovery (the shell's reload flag, through its test seam) ─────
func _menu_script() -> GDScript:
	return load("res://scripts/ui/main_menu.gd")


func _auto_blocked_leg() -> void:
	var hung: Dictionary = SaveIO.read_dict(run_path())
	_expect(_marker_set(), "fixture: the marker is still set from the resume that hung")
	_menu_script().display_reload_flag_override = true
	await _open_menu()
	_expect(_menu_script().display_reload_flag_override == null, "the reload flag is used up even when nothing resumes")
	await create_timer(1.0).timeout
	_expect(current_scene != null and current_scene.scene_file_path == MENU_SCENE, "a reload after a resume that never finished loading stays on the menu")
	var resume: Button = _find_button("CONTINUE")
	_expect(resume != null and not resume.disabled, "CONTINUE is offered instead of resuming by itself")
	_expect(_find_button("RESUME EARLIER POINT") != null, "RESUME EARLIER POINT is still offered")
	_expect(_marker_set() and _point(SaveIO.read_dict(run_path())) == _point(hung), "nothing was resumed or saved")


func _auto_leg() -> void:
	var want: Dictionary = _expected()
	_menu_script().display_reload_flag_override = true
	change_scene_to_file(MENU_SCENE)
	if not await _wait_scene(BATTLE_SCENE):
		_errors.append("the menu did not resume by itself after a display reload")
		return
	_expect(_menu_script().display_reload_flag_override == null, "the reload flag is used up by the resume")
	_expect(_marker_set(), "the automatic resume sets the marker while its screen loads, like CONTINUE")
	var scene: Node = current_scene
	_expect(bool(scene.get("_resumed_from_checkpoint")), "the automatic resume rebuilt the battle from its round checkpoint")
	_expect(int(scene._round_number) == int(want.get("round", -1)), "resumed at round %d (got %d)" % [int(want.get("round", -1)), int(scene._round_number)])
	await create_timer(float(sm().RESUME_SETTLE_SECS) + 1.0).timeout
	_expect(not _marker_set(), "the marker clears once the screen has loaded cleanly")
	_expect(_point(SaveIO.read_dict(run_path())) == str(want.get("point", "")), "the automatic resume leaves the run save where it was")
	# The flag was one use: the next launch is an ordinary menu.
	await _open_menu()
	await create_timer(0.5).timeout
	_expect(current_scene != null and current_scene.scene_file_path == MENU_SCENE, "the launch after that is an ordinary menu")


# ── after_hang ────────────────────────────────────────────────────────────────
func _after_hang_leg() -> void:
	var hung: Dictionary = SaveIO.read_dict(run_path())
	await _open_menu()
	var resume: Button = _find_button("CONTINUE")
	var earlier: Button = _find_button("RESUME EARLIER POINT")
	_expect(resume != null and not resume.disabled, "CONTINUE is still offered after a resume that hung")
	_expect(earlier != null and not earlier.disabled, "RESUME EARLIER POINT appears after a resume that hung")
	_expect(_has_label(ResumeGuard.LINE), "the option carries its line")
	_expect(_find_button("ABANDON RUN") != null, "ABANDON RUN is still offered")
	if resume == null or earlier == null:
		return
	_expect(resume.get_global_rect().position.y < earlier.get_global_rect().position.y, "CONTINUE sits above RESUME EARLIER POINT")
	_expect(resume.custom_minimum_size.y > earlier.custom_minimum_size.y, "CONTINUE stays the main button")
	_expect(_point(SaveIO.read_dict(run_path())) == _point(hung), "nothing switches until the player asks")
	await _shot("menu_option")

	# The state code keeps working with the marker set.
	var header: Node = root.get_node("/root/PersistentHeader")
	for i in 7:
		header._register_dev_tap(1000 + i, false)
	await process_frame
	_expect(current_scene.get_node_or_null("StateCodeButton") != null, "COPY STATE CODE is on the menu once dev tools unlock")
	var decoded: Dictionary = StateCode.decode(StateCode.export_code())
	_expect(bool(decoded["ok"]) and JSON.stringify((decoded["payload"] as Dictionary).get("run_save")) == JSON.stringify(JSON.parse_string(JSON.stringify(hung))),
		"the state code still exports the run save as stored")

	var counted_before: int = int(sm().get_battles_fought())
	var menu: Node = current_scene
	earlier.pressed.emit()
	for i in 900:
		await process_frame
		if current_scene != null and current_scene != menu and current_scene.scene_file_path == MENU_SCENE and _find_button("BEGIN") != null and not _find_button("BEGIN").disabled:
			break
	var restored: Dictionary = SaveIO.read_dict(run_path())
	_expect(_point(restored) == "reward/1/0", "RESUME EARLIER POINT put the rewards after battle 1 back (got %s)" % _point(restored))
	_expect(_has_label("Restored the rewards after battle 1."), "the menu says which point it restored")
	await _shot("menu_restored")
	_expect(_find_button("RESUME EARLIER POINT") == null, "the option is gone once used")
	_expect(not _marker_set(), "the marker is clear after the restore")
	_expect(not FileAccess.file_exists(ResumeGuard.prev_path(run_path())), "the earlier save is used up")
	if not _press_continue():
		return
	var on_rewards: bool = await _wait_scene(REWARD_SCENE)
	_expect(on_rewards, "CONTINUE resumes the restored rewards")

	# Battle 2 was entered (and counted) before the hang. Entering it again from
	# the restored rewards must not count twice; battle 3 counts as usual.
	_expect(int(gs().current_battle) == 1, "the restored run is back on battle 1")
	gs().advance_to_next_battle()
	root.get_node("/root/SceneManager").go_to_battle()
	var in_battle: bool = await _wait_scene(BATTLE_SCENE)
	_expect(in_battle, "the restored run reaches battle 2 again")
	_expect(int(sm().get_battles_fought()) == counted_before, "battle 2 is not counted a second time (INVARIANTS #18)")
	gs().advance_to_next_battle()
	sm().record_battle_entered()
	_expect(int(sm().get_battles_fought()) == counted_before + 1, "the next battle counts as usual")
	sm().clear_run_save()
