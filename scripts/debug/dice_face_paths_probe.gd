# P0 dice face audit, Phase 1 step 3: every path that sets or changes a die on
# a LIVE BattleScene. For each scenario it compares, per living unit:
#   face   — the numeral the 3D die shows up (tray)
#   eff    — the value the scene's readout/preview uses (effective roll)
#   res    — the value combat_manager.resolve_round will act on (hijack
#            applies inside resolve_round, so it is modelled here)
# and, for in-place updates, the rotation the update applies (deg).
# Diagnostic only (prints; exits 0). Run:
#   godot --headless --path . -s scripts/debug/dice_face_paths_probe.gd
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SQUAD := ["combat", "engineer", "medic"]

var _scene: Node
var _tray: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	seed(20260926)
	var gs: Node = root.get_node("/root/GameState")
	var dm: Node = root.get_node("/root/DataManager")
	gs.call("start_run", SQUAD, str(dm.call("get_operation_order")[0]))
	gs.call("advance_to_next_battle")
	change_scene_to_file(BATTLE_SCENE)
	for i in range(180):
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE:
			break
	await create_timer(1.0).timeout
	_scene = current_scene
	_tray = _scene.get("dice_tray_3d")
	var cm: Object = _scene.get("combat_manager")
	var heroes: Array = cm.call("get_hero_states")
	var enemies: Array = cm.call("get_enemy_states")
	var h0: Dictionary = heroes[0]
	var h1: Dictionary = heroes[1]
	var h2: Dictionary = heroes[2]
	var e0: Dictionary = enemies[0]

	cm.get("_active_relic_effects").append({"type": "turn1RollFloor"})
	await _roll("round-1 roll with Resonant Chorus")
	_report("chorus (no die below 8 on heroes)")
	cm.get("_active_relic_effects").clear()
	# Post-roll +roll buff (Sync Antenna's code path: a 1-turn roll-buff stack
	# applied after the dice settle) on the lowest hero die.
	var low: Dictionary = h0
	for hs in heroes:
		if int(_scene.call("_get_effective_roll_for_state", hs, str(hs["id"]))) < int(_scene.call("_get_effective_roll_for_state", low, str(low["id"]))):
			low = hs
	cm.call("apply_item_roll_buff", low, 3, 1)
	_scene.call("_on_die_values_changed")
	await _settle()
	_report("post-roll +3 buff (Sync Antenna path)")

	# Telegraphed statuses that ride into the NEXT reveal.
	h0["rewrite_pending"] = true
	h0["rewrite_skip_next_tick"] = false
	h1["forced_20_pending"] = true
	h2["jam_cap"] = 10
	e0["hijack_pending"] = true
	await _roll("rewrite(h0) forced20(h1) jam10(h2) hijack(e0)")
	_report("rewrite/forced20/jam/hijack")
	h0["rewrite_pending"] = false
	h2["jam_cap"] = 0
	e0["hijack_pending"] = false

	_scene.set("protocol_points", 30)
	var pa: Object = _scene.get("_protocol")
	var hid: String = str(h0["id"])
	var before: Basis = _die(str("hero"), hid).global_transform.basis
	pa.call("_apply_nudge", hid)
	await _settle()
	_report_one("nudge h0", "hero", h0, before)
	before = _die("hero", str(h2["id"])).global_transform.basis
	pa.call("_apply_set", str(h2["id"]), 17)
	await _settle()
	_report_one("set h2=17", "hero", h2, before)
	before = _die("hero", str(h1["id"])).global_transform.basis
	await pa.call("_apply_reroll", str(h1["id"]))
	_report_one("reroll h1", "hero", h1, before)

	# Enemy reroll item path.
	var eng: Object = _scene.get("_engine")
	before = _die("enemy", str(e0["id"])).global_transform.basis
	eng.call("item_enemy_reroll", _scene.get("_state"), e0)
	_scene.call("_on_die_values_changed")
	await _settle()
	_report_one("enemy reroll item e0", "enemy", e0, before)

	# Freeze = repeat, including frozen 20s, both sides.
	h0["die_freeze_turns"] = 1
	h0["frozen_die_value"] = 20
	e0["die_freeze_turns"] = 1
	e0["frozen_die_value"] = 20
	await _roll("frozen 20 (h0, e0)")
	_report("frozen 20 h0/e0")
	print("[DICE_PATHS] DONE")
	quit(0)


func _roll(label: String) -> void:
	print("[DICE_PATHS] --- rolling: %s" % label)
	_scene.set("turn_phase", _scene.get("PHASE_AWAIT_ROLL"))
	_scene.call("_begin_targeting_phase")
	await _tray.roll_finished
	# Resumes BEFORE battle_scene's own await (registered later), so this is
	# the tray's end-of-roll pose, before any roll-time relic override.
	var pre: Dictionary = {}
	for key in _tray.get("_die_by_key"):
		var d: RigidBody3D = _tray.get("_die_by_key")[key]
		pre[key] = [_face(d), d.global_transform.basis]
	print("[DICE_PATHS] at roll_finished: faces=%s scene hero_rolls=%s" % [str(pre.keys().map(func(k): return "%s=%d" % [k, pre[k][0]])), str(_scene.get("hero_rolls"))])
	for i in range(6):
		await process_frame
	for key in pre:
		var d: RigidBody3D = _tray.get("_die_by_key").get(key, null)
		if d == null or _face(d) == int(pre[key][0]):
			continue
		var deg: float = rad_to_deg((d.global_transform.basis * (pre[key][1] as Basis).inverse()).orthonormalized().get_rotation_quaternion().get_angle())
		print("[DICE_PATHS] post-roll override %-12s face %2d -> %2d in ONE frame, rot=%.1f" % [key, int(pre[key][0]), _face(d), minf(deg, 360.0 - deg)])


func _settle() -> void:
	for i in range(60):
		await process_frame
	_report("  (all dice after change)")


func _die(side: String, id: String) -> RigidBody3D:
	return (_tray.get("_die_by_key") as Dictionary).get("%s:%s" % [side, id], null) as RigidBody3D


func _face(die: RigidBody3D) -> int:
	if die == null:
		return -1
	var entry: Dictionary = die.get_meta("entry", {})
	return int(_tray.call("up_face_numeral", str(entry.get("side", "")), str(entry.get("id", ""))))


func _resolve_value(side: String, state: Dictionary) -> int:
	var id: String = str(state["id"])
	if side == "hero":
		return int(_scene.call("_get_effective_roll_for_state", state, id))
	var eff: int = int(_scene.call("_get_effective_enemy_roll", state, id))
	if bool(state.get("hijack_pending", false)) and int(state.get("die_freeze_turns", 0)) == 0:
		var hi: int = 0
		for hs in _scene.get("combat_manager").call("get_hero_states"):
			if not bool(hs["dead"]):
				hi = maxi(hi, int(_scene.call("_get_effective_roll_for_state", hs, str(hs["id"]))))
		return hi
	return eff


func _report(label: String) -> void:
	var cm: Object = _scene.get("combat_manager")
	for pair in [["hero", cm.call("get_hero_states")], ["enemy", cm.call("get_enemy_states")]]:
		for st in pair[1]:
			if bool(st["dead"]):
				continue
			_line(label, str(pair[0]), st, -1.0)


func _report_one(label: String, side: String, state: Dictionary, before: Basis) -> void:
	var die: RigidBody3D = _die(side, str(state["id"]))
	var deg: float = rad_to_deg((die.global_transform.basis * before.inverse()).orthonormalized().get_rotation_quaternion().get_angle())
	_line(label, side, state, minf(deg, 360.0 - deg))


func _line(label: String, side: String, state: Dictionary, rot_deg: float) -> void:
	var id: String = str(state["id"])
	var face: int = _face(_die(side, id))
	var eff: int = int(_scene.call("_get_effective_roll_for_state", state, id)) if side == "hero" else int(_scene.call("_get_effective_enemy_roll", state, id))
	var res: int = _resolve_value(side, state)
	var raw_rolls: Dictionary = _scene.get("hero_rolls") if side == "hero" else _scene.get("enemy_rolls")
	label += " raw=%d" % int(raw_rolls.get(id, -1))
	var flag: String = "OK" if face == eff and eff == res else "MISMATCH"
	var rot: String = "" if rot_deg < 0.0 else " rot=%.1f" % rot_deg
	print("[DICE_PATHS] %-44s %-5s %-12s face=%2d eff=%2d res=%2d%s %s" % [label, side, id, face, eff, res, rot, flag])
