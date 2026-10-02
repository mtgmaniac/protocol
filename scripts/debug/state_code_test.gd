# State code round-trip regression (dev tool, 2026-10-02).
#
#   godot --headless --path . -s scripts/debug/state_code_test.gd -- \
#       --leg export --out <dir>
#   godot --headless --path . -s scripts/debug/state_code_test.gd -- \
#       --leg import --out <dir> --load-state=<dir>/code.txt
#
# One leg each of scripts/checks/state_code_gate.py, which runs them as
# SEPARATE Godot processes, so the import sees only the code:
#   export : a live battle plays one round (an end-of-round checkpoint is in the
#            run save), the profile carries marked values, an error and a
#            warning are raised, then the code is exported. Also, in process:
#            the code decodes back to the same run save; a changed character, a
#            cut-short code and a wrong prefix are refused; a code wrapped over
#            many lines still decodes. Finally the run save is erased, so the
#            import leg can only get it from the code.
#   import : launched with --load-state, so SaveManager imported the code at
#            boot. The run save on disk and the profile must equal the export
#            leg's, CONTINUE must resume the battle at the same round, and the
#            payload must carry the raised error.
# Each leg writes <dir>/<leg>.json: {"errors": [...], ...}.
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SQUAD := ["combat", "medic", "engineer"]
const OP := "facility"
const SEED := 52021
const ERROR_MARKER := "STATE_CODE_TEST_ERROR"
const WARNING_MARKER := "STATE_CODE_TEST_WARNING"
const NAT20_MARK := 4242

var _leg: String = ""
var _out_dir: String = ""
var _record: Dictionary = {}
var _errors: PackedStringArray = []
var _dice_rng := RandomNumberGenerator.new()


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--leg": _leg = args[i + 1]
			"--out": _out_dir = args[i + 1]
	call_deferred("_run")


func gs() -> Node:
	return root.get_node("/root/GameState")


func sm() -> Node:
	return root.get_node("/root/SaveManager")


func _run() -> void:
	root.size = Vector2i(1080, 2400)
	_dice_rng.seed = SEED
	_record = {"leg": _leg}
	match _leg:
		"export":
			await _export_leg()
		"import":
			await _import_leg()
		_:
			_errors.append("unknown --leg '%s'" % _leg)
	_record["errors"] = Array(_errors)
	var file := FileAccess.open(_out_dir.path_join("%s.json" % _leg), FileAccess.WRITE)
	file.store_string(JSON.stringify(_record, "  "))
	file.close()
	print("[STATE_CODE] leg=%s %s" % [_leg, "clean" if _errors.is_empty() else "ERRORS: " + "; ".join(_errors)])
	if current_scene != null:
		current_scene.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_errors.append(what)


func _json_norm(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))


func _run_save_on_disk() -> Dictionary:
	return SaveIO.read_dict(str(sm().get("_run_save_path")))


# ── export ────────────────────────────────────────────────────────────────────
func _export_leg() -> void:
	sm().clear_run_save()
	gs().reset_run()
	gs().start_run(SQUAD, OP, SEED)
	gs().advance_to_next_battle()
	gs().current_battle = 2
	var profile: Dictionary = sm().get("data")
	(profile["stats"] as Dictionary)["nat20s"] = NAT20_MARK
	profile["tutorial_done"] = true
	change_scene_to_file(BATTLE_SCENE)
	for i in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE:
			break
	await create_timer(0.8).timeout
	var scene: Node = current_scene
	if scene == null or scene.scene_file_path != BATTLE_SCENE:
		_errors.append("battle scene did not load")
		return
	# One live round: rigged landings, auto targets, resolve -> end-of-round checkpoint.
	var rig: Dictionary = {}
	for side in ["hero", "enemy"]:
		var states: Array = scene.combat_manager.get_hero_states() if side == "hero" else scene.combat_manager.get_enemy_states()
		for st in states:
			rig["%s:%s" % [side, str(st["id"])]] = _dice_rng.randi_range(3, 18)
	scene.dice_tray_3d.set_rigged_results(rig)
	await scene._begin_targeting_phase()
	if int(scene.turn_phase) == int(scene.PHASE_TARGETING):
		await scene._auto_assign_pending_targets(false)
	if int(scene.turn_phase) == int(scene.PHASE_READY_TO_END):
		await scene._resolve_current_turn()
	_expect(not bool(scene.battle_over), "fixture: the battle is still going after round 1")
	var run_save: Dictionary = _run_save_on_disk()
	var checkpoint: Variant = run_save.get("battle_checkpoint", {})
	_expect(checkpoint is Dictionary and not (checkpoint as Dictionary).is_empty(), "the run save holds an end-of-round checkpoint")
	_record["round"] = int(scene._round_number)
	_record["run_save"] = _json_norm(run_save)
	_record["profile"] = _json_norm(sm().get("data"))

	push_error(ERROR_MARKER)
	push_warning(WARNING_MARKER)
	var code: String = StateCode.export_code()
	_record["code_length"] = code.length()
	var file := FileAccess.open(_out_dir.path_join("code.txt"), FileAccess.WRITE)
	file.store_string(code)
	file.close()

	# In-process: the code decodes back to what was exported.
	var decoded: Dictionary = StateCode.decode(code)
	_expect(bool(decoded["ok"]), "the exported code decodes (%s)" % str(decoded["error"]))
	if bool(decoded["ok"]):
		var payload: Dictionary = decoded["payload"]
		_expect(_json_norm(payload.get("run_save")) == _record["run_save"], "decoded run save == the run save on disk")
		_expect(str(payload.get("scene", "")) == BATTLE_SCENE, "the payload names the current scene")
		var live: Dictionary = payload.get("live", {})
		_expect(int((live.get("battle", {}) as Dictionary).get("round", 0)) == int(_record["round"]), "the payload carries the live battle round")
		_expect(str((live.get("run", {}) as Dictionary).get("reward_rng_state", "")) == SaveIO.encode_i64(int(gs().get_reward_rng_state())), "the payload carries the exact reward RNG state")
		_expect(not ((live.get("battle", {}) as Dictionary).get("streams", {}) as Dictionary).is_empty(), "the payload carries the battle RNG streams")
		_expect(str(payload.get("build_id", "")) == str(ProjectSettings.get_setting("application/config/version", "")), "the payload carries the build id")
		var texts: String = JSON.stringify(payload.get("errors", []))
		_expect(texts.contains(ERROR_MARKER) and texts.contains(WARNING_MARKER), "the payload carries the raised error and warning")
	# Damaged codes are refused, never half-imported.
	var parts: PackedStringArray = code.split(":")
	var mid: int = parts[1].length() / 2
	var swapped: String = "A" if parts[1][mid] != "A" else "B"
	var changed: String = "%s:%s%s%s:%s" % [parts[0], parts[1].substr(0, mid), swapped, parts[1].substr(mid + 1), parts[2]]
	_expect(not bool(StateCode.decode(changed)["ok"]), "a code with one character changed is refused")
	# The data itself still decodes here; only the checksum can catch it.
	var bad_sum: String = "%s:%s:%s" % [parts[0], parts[1], "00000000" if parts[2] != "00000000" else "11111111"]
	_expect(not bool(StateCode.decode(bad_sum)["ok"]), "a code whose checksum does not match is refused")
	_expect(not bool(StateCode.decode(code.substr(0, code.length() - 40))["ok"]), "a code cut short is refused")
	_expect(not bool(StateCode.decode("XPSTATE1" + code.substr(8))["ok"]), "a code with the wrong prefix is refused")
	var wrapped: String = ""
	for i in range(0, code.length(), 76):
		wrapped += code.substr(i, 76) + "\n  "
	_expect(bool(StateCode.decode(wrapped)["ok"]), "a code wrapped over many lines still decodes")

	# Leave nothing behind: the import leg must get the run from the code alone.
	scene.queue_free()
	await process_frame
	sm().clear_run_save()
	_expect(_run_save_on_disk().is_empty(), "fixture: the run save is erased before the import leg")


# ── import ────────────────────────────────────────────────────────────────────
func _import_leg() -> void:
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(_out_dir.path_join("export.json")))
	if not (expected is Dictionary):
		_errors.append("no export record to compare against")
		return
	var want: Dictionary = expected
	_expect(_json_norm(_run_save_on_disk()) == want["run_save"], "the imported run save on disk == the exported one")
	_expect(_json_norm(sm().get("data")) == want["profile"], "the imported profile == the exported one")
	_expect(int(((sm().get("data") as Dictionary)["stats"] as Dictionary).get("nat20s", 0)) == NAT20_MARK, "the profile's marked stat came through")
	# CONTINUE: the same resume path the menu runs.
	var screen: String = sm().resume_run()
	_expect(screen == "battle", "CONTINUE resumes on the battle (got '%s')" % screen)
	change_scene_to_file(BATTLE_SCENE)
	for i in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE:
			break
	await create_timer(0.8).timeout
	var scene: Node = current_scene
	if scene == null or scene.scene_file_path != BATTLE_SCENE:
		_errors.append("battle scene did not load after the import")
		return
	_expect(bool(scene.get("_resumed_from_checkpoint")), "the battle was rebuilt from the imported checkpoint")
	_expect(int(scene._round_number) == int(want["round"]), "resumed at round %d (got %d)" % [int(want["round"]), int(scene._round_number)])
	var payload: Dictionary = StateCode.decode(FileAccess.get_file_as_string(_out_dir.path_join("code.txt"))).get("payload", {})
	_expect(JSON.stringify(payload.get("errors", [])).contains(ERROR_MARKER), "the imported payload carries the export leg's error")
