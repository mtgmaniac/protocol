# G-24..G-30 dice contract: observe actual Label3D text and world transforms.
# (a) settled numeral = acted value; (b) static labels except at deliberate
# tumble start; (c) same top face, tilt <90 degrees, upright at rest;
# (d) pre-roll modifier ranges; (e) placed pending rolls restore the same dice;
# (f) frozen value/pose and pending hijack; (g) Set ignores modifiers and prints
# plain 1..20; (h) engine Nudge/Set/Reroll refuse frozen dice without spending.
# Real cross-process checkpoint coverage also lives in battle_checkpoint_gate.py.
# -- --break=a (through h) injects a real bad observation/state; must exit 1.
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SQUAD := ["combat", "engineer", "medic"]
const SPEED := 8
const ROTATION_EPS_DEG := 0.05
const MAX_REPORTED := 12

class ScriptedRolls extends "res://scripts/sim/roll_provider.gd":
	var queue: Array = []
	var fallback := RandomNumberGenerator.new()

	func roll_d20() -> int:
		if not queue.is_empty():
			return int(queue.pop_front())
		return fallback.randi_range(1, 20)

	func rand_index(size: int) -> int:
		return fallback.randi_range(0, maxi(size - 1, 0))

	func describe() -> String:
		return "dice-face-gate scripted"


var _tray: Node
var _scene: Node
var _synthetic: Dictionary = {}  # Part A oracle: "side:id" -> value
var _use_scene_oracle: bool = false
var _monitor_on: bool = false
var _ranges: Dictionary = {}      # "side:id" -> Array[int] allowed at landing
var _settled: Dictionary = {}     # die instance id -> physical top label at settle
var _yaw_prev: Dictionary = {}
var _yaw_travel: Dictionary = {}
var _fails: Dictionary = {"a": [], "b": [], "c": [], "d": [], "e": [], "f": [], "g": [], "h": []}
var _checks: Dictionary = {"a": 0, "b": 0, "c": 0, "d": 0, "e": 0, "f": 0, "g": 0, "h": 0}
var _frozen_lock: Dictionary = {}  # "side:id" -> the number the frozen die must keep
var _landed_pairs: Dictionary = {}
var _labels_prev: Dictionary = {}
var _busy_prev: Dictionary = {}
var _frozen_pose: Dictionary = {}
var _break_kind := ""
var _break_done := false
var _stub: ScriptedRolls



func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.physics_ticks_per_second = 120 * SPEED
	Engine.time_scale = SPEED
	Engine.max_physics_steps_per_frame = 64
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--break="):
			_break_kind = arg.trim_prefix("--break=")
	seed(20260926)
	await _part_a()
	await _part_b_and_c()
	# Let the last item SFX finish: a stream still playing at quit is reported
	# as a leaked resource (an ERROR line the gate runner rejects).
	Engine.time_scale = 1.0
	current_scene.queue_free()
	await create_timer(1.5).timeout
	_finish()


# ── monitor ──────────────────────────────────────────────────────────────────

func _process(_delta: float) -> bool:
	if _monitor_on and _tray != null and is_instance_valid(_tray):
		_sample()
	return false


func _labels(die: RigidBody3D) -> Array:
	var result: Array = []
	for value in range(1, 21):
		result.append((die.get_node("Visuals/FaceNumber%d" % value) as Label3D).text)
	return result


func _top(die: RigidBody3D) -> Label3D:
	var best: Label3D
	var dot := -2.0
	for value in range(1, 21):
		var label := die.get_node("Visuals/FaceNumber%d" % value) as Label3D
		var d := label.global_basis.z.normalized().dot(Vector3.UP)
		if d > dot:
			dot = d
			best = label
	return best


func _check(kind: String, ok: bool, message: String) -> void:
	_checks[kind] += 1
	if not ok:
		_fail(kind, message)


func _inject(kind: String) -> bool:
	if _break_kind == kind and not _break_done:
		_break_done = true
		print("[DICE_FACE_GATE] injected violation (" + kind + ")")
		return true
	return false


func _sample() -> void:
	for key in _tray.get("_die_by_key"):
		var die: RigidBody3D = _tray.get("_die_by_key")[key]
		if not is_instance_valid(die) or not die.is_inside_tree():
			continue
		var entry: Dictionary = die.get_meta("entry", {})
		var side: String = str(entry.get("side", ""))
		var uid: String = str(entry.get("id", ""))
		var iid: int = die.get_instance_id()
		var busy: bool = bool(die.get_meta("busy", false))
		var locked: bool = bool(_tray.call("is_die_locked", side, uid))
		if _labels_prev.has(iid) and busy and bool(_busy_prev.get(iid, false)) and _inject("b"):
			_top(die).text = "99"
		var labels := _labels(die)
		if _labels_prev.has(iid):
			# Only the first frame of a deliberate change may replace the print.
			var reprint_start: bool = busy and not bool(_busy_prev.get(iid, false)) and not bool(_tray.get("_is_rolling"))
			_check("b", labels == _labels_prev[iid] or reprint_start, "%s changed labels outside tumble start" % key)
		_labels_prev[iid] = labels
		_busy_prev[iid] = busy
		if busy:
			_settled.erase(iid)
			_yaw_prev.erase(iid)
			_yaw_travel.erase(iid)
		elif die.freeze:
			var top := _top(die)
			var heading := Vector3(top.global_basis.y.x, 0, top.global_basis.y.z).normalized()
			if _yaw_prev.has(iid):
				_yaw_travel[iid] = float(_yaw_travel.get(iid, 0.0)) + absf(rad_to_deg((_yaw_prev[iid] as Vector3).signed_angle_to(heading, Vector3.UP)))
			_yaw_prev[iid] = heading
			if not _settled.has(iid):
				_settled[iid] = top.name
				var tilt := rad_to_deg(acos(clampf(top.global_basis.z.normalized().dot(Vector3.UP), -1.0, 1.0)))
				_check("c", tilt < 90.0, "%s flattening tilt %.2f >=90" % [key, tilt])
			if locked and _inject("c"):
				die.global_basis = die.global_basis.rotated(Vector3.RIGHT, PI)
			_check("c", _top(die).name == _settled[iid], "%s changed top face after settling" % key)
			if locked:
				_check("c", float(_yaw_travel.get(iid, 0.0)) <= 180.05, "%s upright yaw exceeded 180 degrees" % key)
				_check("c", _top(die).global_basis.z.normalized().dot(Vector3.UP) > 0.999, "%s not flat" % key)
				_check("c", _top(die).global_basis.y.normalized().dot(Vector3.FORWARD) > 0.999, "%s numeral not upright" % key)
		_check_frozen(key, side, uid, die, locked)
		if not locked:
			continue
		if _inject("a"):
			_top(die).text = "99"
		var shown: int = int(_top(die).text)
		var want: int = _oracle(side, uid)
		if want > 0:
			_check("a", shown == want, "%s shows %d but acts on %d" % [key, shown, want])
		if _ranges.has(key):
			var allowed: Array = _ranges[key]
			if _inject("d"):
				_top(die).text = "1" if not allowed.has(1) else "99"
				shown = int(_top(die).text)
			_check("d", allowed.has(shown), "%s landed %d outside %s" % [key, shown, _range_text(allowed)])
			_ranges.erase(key)


func _check_frozen(key: String, side: String, uid: String, die: RigidBody3D, locked: bool) -> void:
	if not _use_scene_oracle:
		return
	var st := _state_for(side, uid)
	if st.is_empty() or (int(st.get("die_freeze_turns", 0)) <= 0 and not bool(st.get("die_freeze_repeat_this_round", false))):
		_frozen_lock.erase(key)
		_frozen_pose.erase(key)
		return
	# The freeze action itself may tumble to 1 (Deep Freeze); capture when done.
	if not _frozen_pose.has(key):
		if locked:
			_frozen_lock[key] = int(_top(die).text)
			_frozen_pose[key] = die.global_transform
		return
	if _inject("f"):
		die.position.x += 0.2
	_check("f", die.global_transform.is_equal_approx(_frozen_pose[key]), "%s moved while frozen" % key)
	_check("f", int(_top(die).text) == int(_frozen_lock[key]), "%s changed frozen numeral" % key)
	_check("f", not bool(die.get_meta("busy", false)), "%s tumbled while frozen" % key)


func _state_for(side: String, uid: String) -> Dictionary:
	var cm: Object = _scene.get("combat_manager")
	for st in cm.call("get_hero_states" if side == "hero" else "get_enemy_states"):
		if str(st["id"]) == uid:
			return st
	return {}


func _oracle(side: String, uid: String) -> int:
	if not _use_scene_oracle:
		return int(_synthetic.get("%s:%s" % [side, uid], 0))
	var engine: Object = _scene.get("_engine")
	var bs: Object = _scene.get("_state")
	var cm: Object = _scene.get("combat_manager")
	var heroes: Array = cm.call("get_hero_states")
	var enemies: Array = cm.call("get_enemy_states")
	var eff_h: Dictionary = engine.call("build_effective_rolls", bs.get("hero_rolls"), heroes, true, bs)
	if side == "hero":
		return int(eff_h.get(uid, 0))
	var eff_e: Dictionary = engine.call("build_effective_rolls", bs.get("enemy_rolls"), enemies, false, bs)
	# resolve_round (combat_manager.gd, "Hijack"): a pending, unfrozen hijack
	# copies the heroes' highest effective die.
	for es in enemies:
		if str(es["id"]) == uid and bool(es.get("hijack_pending", false)) and int(es.get("die_freeze_turns", 0)) == 0:
			var hi: int = 0
			for v in eff_h.values():
				hi = maxi(hi, int(v))
			if hi > 0:
				return hi
	return int(eff_e.get(uid, 0))


func _fail(kind: String, msg: String) -> void:
	var arr: Array = _fails[kind]
	if arr.size() < 200:
		arr.append(msg)


func _range_text(arr: Array) -> String:
	if arr.size() == 1:
		return str(arr[0])
	return "%d-%d" % [arr.min(), arr.max()]


func _span(lo: int, hi: int) -> Array:
	var out: Array = []
	for v in range(lo, hi + 1):
		out.append(v)
	return out


func _await_all_locked() -> void:
	for _i in range(4000):
		await process_frame
		if bool(_tray.get("_is_rolling")):
			continue
		var all_locked: bool = true
		for key in _tray.get("_die_by_key"):
			var parts: PackedStringArray = str(key).split(":", true, 1)
			if not bool(_tray.call("is_die_locked", parts[0], parts[1])):
				all_locked = false
				break
		if all_locked:
			# a few extra frames so the monitor samples the locked state
			for _j in range(3):
				await process_frame
			return
	_fail("a", "timed out waiting for the dice to lock")


# ── Part A: tray only, every slot x every value ──────────────────────────────

func _part_a() -> void:
	var host: Control = Control.new()
	host.size = Vector2(1056, 1100)
	root.add_child(host)
	_tray = load("res://scenes/battle/DiceTray3D.tscn").instantiate()
	_tray.custom_minimum_size = host.size
	host.add_child(_tray)
	_tray.call("set_combat_zone_rect", Rect2(Vector2.ZERO, host.size))
	_tray.set("value_provider", func(side: String, uid: String) -> int: return int(_synthetic.get("%s:%s" % [side, uid], 0)))
	await process_frame
	_use_scene_oracle = false
	_monitor_on = true
	var heroes: Array = ["h0", "h1", "h2"]
	var enemies: Array = ["e0", "e1", "e2", "e3"]
	for roll in range(20):
		_synthetic.clear()
		var hero_entries: Array = []
		var enemy_entries: Array = []
		var slot: int = 0
		for uid in enemies + heroes:
			var side: String = "hero" if heroes.has(uid) else "enemy"
			var v: int = ((roll + slot * 7) % 20) + 1
			_synthetic["%s:%s" % [side, uid]] = v
			_landed_pairs["A %s:%s=%d" % [side, uid, v]] = true
			(hero_entries if side == "hero" else enemy_entries).append({"id": uid, "name": uid})
			slot += 1
		_tray.call("set_rigged_results", _synthetic)
		_tray.call("play_rolls", hero_entries, enemy_entries)
		await _await_all_locked()
	# Refresh placement preserves the physical raw face and every label.
	var raws := {"hero": _tray.call("get_hero_rolls"), "enemy": _tray.call("get_enemy_rolls")}
	var before: Dictionary = {}
	for key in _tray.get("_die_by_key"):
		var die: RigidBody3D = _tray.get("_die_by_key")[key]
		before[key] = [_top(die).name, _labels(die)]
	var thrown: int = _tray.get("thrown_dice_total")
	_tray.call("place_rolls", heroes.map(func(uid): return {"id": uid, "name": uid}), enemies.map(func(uid): return {"id": uid, "name": uid}), raws)
	await _await_all_locked()
	for key in before:
		var die: RigidBody3D = _tray.get("_die_by_key")[key]
		if _inject("e"):
			_top(die).text = "99"
		_check("e", before[key] == [_top(die).name, _labels(die)], "%s changed on refresh" % key)
	_check("e", int(_tray.get("thrown_dice_total")) == thrown, "refresh threw dice")
	# Real, unrigged physical throws: landed face decides, same face during snap.
	_synthetic.clear()
	for trial in range(4):
		_tray.call("play_rolls", heroes.map(func(uid): return {"id": uid}), enemies.map(func(uid): return {"id": uid}))
		await _await_all_locked()
		for key in _tray.get("_die_by_key"):
			var die: RigidBody3D = _tray.get("_die_by_key")[key]
			_check("a", int(_top(die).text) == int(die.get_meta("raw_result")), "%s live raw differs from landed numeral" % key)
			_synthetic[key] = int(_top(die).text)
		_synthetic.clear()
	for key in _tray.get("_die_by_key"):
		_synthetic[key] = int(_top(_tray.get("_die_by_key")[key]).text)
	# A live deliberate tip-over on the bare tray.
	_tray.call("set_values_live", true)
	_synthetic["hero:h0"] = (int(_synthetic["hero:h0"]) % 20) + 1
	_synthetic["enemy:e2"] = (int(_synthetic["enemy:e2"]) + 6) % 20 + 1
	await _await_all_locked()
	_monitor_on = false
	host.queue_free()
	await process_frame
	print("[DICE_FACE_GATE] part A: 7 slots x 20 values, %d slot-value pairs landed" % _landed_pairs.size())


# ── Parts B + C: the live battle scene ───────────────────────────────────────

func _part_b_and_c() -> void:
	var gs: Node = root.get_node("/root/GameState")
	var dm: Node = root.get_node("/root/DataManager")
	gs.call("start_run", SQUAD, str(dm.call("get_operation_order")[0]))
	gs.call("advance_to_next_battle")
	change_scene_to_file(BATTLE_SCENE)
	for _i in range(240):
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE:
			break
	await create_timer(1.0).timeout
	_scene = current_scene
	_tray = _scene.get("dice_tray_3d")
	var stub := ScriptedRolls.new()
	_stub = stub
	stub.fallback.seed = 20260926
	(_scene.get("_engine") as Object).set("roll_provider", stub)
	var cm: Object = _scene.get("combat_manager")
	var heroes: Array = cm.call("get_hero_states")
	var enemies: Array = cm.call("get_enemy_states")
	var h: Array = heroes.map(func(s): return str(s["id"]))
	var e: Array = enemies.map(func(s): return str(s["id"]))
	_use_scene_oracle = true
	_monitor_on = true

	# B1: pre-roll modifiers x all 20 naturals.
	for roll in range(20):
		_clear_statuses(heroes + enemies)
		_buff(heroes[0], 3)                                     # +3 -> 4-20
		heroes[1]["rfe_stacks"] = [{"amt": 2, "turns_left": 9}] # -2 -> 1-18
		heroes[2]["jam_cap"] = 10                               # jam -> 1-10
		heroes[2]["jam_skip_next_tick"] = true
		enemies[1]["rewrite_pending"] = true                    # rewrite -> 3
		enemies[1]["rewrite_skip_next_tick"] = true
		await _roll(stub, roll, heroes.size() + enemies.size(), {
			"hero:%s" % h[0]: _span(4, 20), "hero:%s" % h[1]: _span(1, 18),
			"hero:%s" % h[2]: _span(1, 10), "enemy:%s" % e[1]: [3],
		})
	print("[DICE_FACE_GATE] part B1: +3 / -2 / jam 10 / rewrite x 20 naturals")

	# B2: forced 20 + Resonant Chorus (round 1) x all 20 naturals.
	cm.get("_active_relic_effects").append({"type": "turn1RollFloor"})
	for roll in range(20):
		_clear_statuses(heroes + enemies)
		heroes[0]["forced_20_pending"] = true
		await _roll(stub, roll, heroes.size() + enemies.size(),
			{"hero:%s" % h[0]: [20], "hero:%s" % h[1]: _span(8, 20), "hero:%s" % h[2]: _span(8, 20)})
	cm.get("_active_relic_effects").clear()
	print("[DICE_FACE_GATE] part B2: forced 20 + Resonant Chorus x 20 naturals")

	# B3: frozen 20s, hero and enemy (a frozen die repeats; nothing alters it).
	_clear_statuses(heroes + enemies)
	stub.queue = [20, 5, 9, 20, 4]
	await _begin_roll()
	await _await_all_locked()
	for st in [heroes[0], enemies[0]]:
		_scene.get("_engine").item_freeze_die(_scene.get("_state"), st, 2)
	await _roll(stub, 3, heroes.size() + enemies.size(), {"hero:%s" % h[0]: [20], "enemy:%s" % e[0]: [20]})
	# ...and it stays frozen into the next roll (carried-over die).
	await _roll(stub, 9, heroes.size() + enemies.size())
	_clear_statuses(heroes + enemies)
	print("[DICE_FACE_GATE] part B3: frozen 20s both sides")

	# C1: live hijack follows the heroes' highest die.
	var pa: Object = _scene.get("_protocol")
	_scene.set("protocol_points", 60)
	enemies[0]["hijack_pending"] = true
	enemies[0]["hijack_skip_next_tick"] = true
	stub.queue = [5, 9, 12, 2, 7]
	await _begin_roll()
	await _await_all_locked()
	_expect_value("enemy", e[0], 12, "hijack copies the highest hero die at landing")
	pa.call("_apply_nudge", h[2])           # 12 -> 15
	await _await_all_locked()
	_expect_value("enemy", e[0], 15, "hijack follows a Nudge on the highest die")
	pa.call("_apply_set", h[1], 19)          # 9 -> 19
	await _await_all_locked()
	_expect_value("enemy", e[0], 19, "hijack follows a Set")
	stub.queue = [4]
	await _reroll(pa, h[1])                  # physical result
	await _await_all_locked()
	_expect_value("enemy", e[0], maxi(15, _scene._die_value("hero", h[1])), "hijack follows a Reroll")
	await _use_item(pa, "momentum_core", heroes[2])  # +2 -> 17
	await _await_all_locked()
	_expect_value("enemy", e[0], maxi(17, _scene._die_value("hero", h[1])), "hijack follows a roll-buff item")
	enemies[0]["hijack_pending"] = false
	print("[DICE_FACE_GATE] part C1: live hijack")

	# C2: every other after-landing change.
	_clear_statuses(heroes + enemies)
	gs.get("gear_by_unit")[h[0]] = ["sync_antenna"]
	stub.queue = [10, 10, 6, 14, 11]
	await _begin_roll()
	await _await_all_locked()
	_expect_value("hero", h[0], 13, "Sync Antenna: matched 10s become 13 after landing")
	_expect_value("hero", h[1], 13, "Sync Antenna: both dice of the pair")
	gs.get("gear_by_unit").erase(h[0])
	pa.call("_apply_nudge", h[2])
	await _await_all_locked()
	pa.call("_apply_set", h[2], 1)
	await _await_all_locked()
	stub.queue = [18]
	await _reroll(pa, h[0])
	await _await_all_locked()
	await _use_item(pa, "harmonic_injector", heroes[1])
	await _await_all_locked()
	await _use_item(pa, "entropy_seed", enemies[1])
	await _await_all_locked()
	stub.queue = [20]
	await _use_item(pa, "phase_scrambler", enemies[1])
	await _await_all_locked()
	stub.queue = [3, 17]
	await _use_item(pa, "cascade_jammer", {})
	await _await_all_locked()
	await _use_item(pa, "cryo_gel", heroes[2])
	await _await_all_locked()
	await _use_item(pa, "deep_zero_pin", {})
	await _await_all_locked()
	_expect_value("enemy", e[0], 1, "Deep Freeze Charge pins an enemy die to 1")
	print("[DICE_FACE_GATE] part C2: Nudge, Set, Reroll, items, Sync Antenna")

	# D: freeze locks the number on the face (G-23).
	_clear_statuses(heroes + enemies)
	_frozen_lock.clear()
	_frozen_pose.clear()
	_buff(heroes[0], 3)                               # h0: natural 17 +3 -> 20
	enemies[1]["roll_buff_stacks"] = [{"amt": 2, "turns_left": 9}]  # e1: 9 +2 -> 11
	enemies[1]["roll_buff"] = 2
	stub.queue = [17, 5, 12, 4, 9]
	await _begin_roll()
	await _await_all_locked()
	_expect_value("hero", h[0], 20, "the +3 hero shows its buffed 20 before the freeze")
	_frozen_lock["hero:%s" % h[0]] = int(_tray.call("up_face_numeral", "hero", h[0]))
	await _use_item(pa, "cryo_gel", heroes[0])        # item freeze: locks 20
	await _await_all_locked()
	_expect_value("hero", h[0], 20, "an item freeze locks the shown 20, not the raw 17")
	heroes[0]["rfe_stacks"] = [{"amt": 2, "turns_left": 9}]  # modifier added after the freeze
	_scene.call("_on_die_values_changed")
	await _await_all_locked()
	_expect_value("hero", h[0], 20, "a penalty added after the freeze can't move it")
	# Resolution-path freeze (an enemy ability / hero freeze rider): capture from
	# the values this round acts on, exactly as resolve_round stamps them.
	var eng: Object = _scene.get("_engine")
	var bs: Object = _scene.get("_state")
	cm.call("stamp_acted_values",
		eng.call("build_effective_rolls", bs.get("hero_rolls"), heroes, true, bs),
		eng.call("build_effective_rolls", bs.get("enemy_rolls"), enemies, false, bs))
	_frozen_lock["enemy:%s" % e[1]] = int(_tray.call("up_face_numeral", "enemy", e[1]))
	cm.call("_freeze_die_state", enemies[1], 2)
	_scene.call("_on_die_values_changed")
	await _await_all_locked()
	_expect_value("enemy", e[1], 11, "a resolution-path freeze locks the buffed 11, not the raw 9")
	# Later rounds: the +3 and +2 expire, the penalty stays; both dice keep their number.
	heroes[0]["roll_buff_stacks"] = []
	heroes[0]["roll_buff"] = 0
	enemies[1]["roll_buff_stacks"] = []
	enemies[1]["roll_buff"] = 0
	enemies[1]["rfe_stacks"] = [{"amt": 3, "turns_left": 9}]
	for roll in range(2):
		stub.queue = [3, 3, 3, 3, 3]
		await _begin_roll()
		await _await_all_locked()
		_expect_value("hero", h[0], 20, "the frozen 20 holds on a later roll with its buff gone")
		_expect_value("enemy", e[1], 11, "the frozen 11 holds on a later roll with a new penalty")
	print("[DICE_FACE_GATE] part D: freeze locks the shown number")
	await _extra_contracts(heroes, enemies, pa, stub)

	_monitor_on = false


func _clear_statuses(states: Array) -> void:
	for st in states:
		st["roll_buff_stacks"] = []
		st["roll_buff"] = 0
		st["rfe_stacks"] = []
		st["jam_cap"] = 0
		st["rewrite_pending"] = false
		st["hijack_pending"] = false
		st["forced_20_pending"] = false
		st["die_freeze_turns"] = 0
		st["frozen_die_value"] = 0
		st["die_freeze_repeat_this_round"] = false


func _buff(st: Dictionary, amount: int) -> void:
	st["roll_buff_stacks"] = [{"amt": amount, "turns_left": 9}]
	st["roll_buff"] = amount


# Queue this roll's naturals: every unit meets every natural across 20 rolls.
func _roll(stub: Object, roll: int, count: int, ranges: Dictionary = {}) -> void:
	var q: Array = []
	for slot in range(count):
		q.append(((roll + slot * 7) % 20) + 1)
	stub.set("queue", q)
	await _begin_roll(ranges)
	await _await_all_locked()
	for key in ranges:
		if _ranges.has(key):
			_fail("d", "%s never locked a landing value to check" % key)
	_ranges.clear()


# Ranges arm once the NEW throw has started (no die reads as locked while the
# tray rolls), so the previous roll's locked dice are never judged by them.
func _begin_roll(ranges: Dictionary = {}) -> void:
	_ranges.clear()
	var rig: Dictionary = {}
	for side in ["hero", "enemy"]:
		for st in _scene.get("combat_manager").call("get_hero_states" if side == "hero" else "get_enemy_states"):
			rig["%s:%s" % [side, str(st["id"])]] = _stub.roll_d20()
	_tray.call("set_rigged_results", rig)
	_scene.set("turn_phase", _scene.get("PHASE_AWAIT_ROLL"))
	_scene.call("_begin_targeting_phase")
	for _i in range(600):
		if bool(_tray.get("_is_rolling")):
			break
		await process_frame
	_ranges = ranges.duplicate()
	await _tray.roll_finished


func _reroll(pa: Object, hero_id: String) -> void:
	var die: RigidBody3D = (_tray.get("_die_by_key") as Dictionary).get("hero:%s" % hero_id, null)
	var iid: int = die.get_instance_id() if die != null else 0
	_settled.erase(iid)
	var launched: int = int(_tray.thrown_dice_total)
	await pa.call("_apply_reroll", hero_id)
	_check("a", int(_tray.thrown_dice_total) == launched + 1, "Reroll physically throws exactly one die")
	var landed: RigidBody3D = _tray._get_die_for_entry("hero", hero_id)
	_check("a", int(_scene.hero_rolls[hero_id]) == int(_tray._get_most_visible_face_value(landed)), "Reroll raw equals physical landed face")
	if die != null and is_instance_valid(die):
		_settled[iid] = _top(die).name


func _use_item(pa: Object, item_id: String, target: Dictionary) -> void:
	var item: Resource = root.get_node("/root/DataManager").call("get_item", item_id)
	if item == null:
		_fail("a", "missing item %s" % item_id)
		return
	pa.call("_apply_item_effect", item, target)
	await process_frame


func _expect_value(side: String, uid: String, want: int, label: String) -> void:
	var shown: int = int(_tray.call("up_face_numeral", side, uid))
	_checks["a"] += 1
	if shown != want or _oracle(side, uid) != want:
		_fail("a", "%s: %s:%s shows %d, acts on %d, expected %d" % [label, side, uid, shown, _oracle(side, uid), want])


func _finish() -> void:
	Engine.time_scale = 1.0
	var failed: bool = not _break_kind.is_empty() and not _break_done
	for kind in _fails:
		var arr: Array = _fails[kind]
		print("[DICE_FACE_GATE] (%s) checks=%d failures=%d" % [kind, int(_checks[kind]), arr.size()])
		for i in range(mini(arr.size(), MAX_REPORTED)):
			print("[DICE_FACE_GATE]   (%s) %s" % [kind, arr[i]])
		if not arr.is_empty() or int(_checks[kind]) == 0:
			failed = true
	if failed:
		print("[DICE_FACE_GATE] FAIL")
		quit(1)
	else:
		print("[DICE_FACE_GATE] PASS")
		quit(0)


func _extra_contracts(heroes: Array, enemies: Array, pa: Object, stub: ScriptedRolls) -> void:
	var engine: Object = _scene.get("_engine")
	var bs: Object = _scene.get("_state")
	var cm: Object = _scene.get("combat_manager")
	var uid := str(heroes[0]["id"])
	var eid := str(enemies[0]["id"])
	# G-25: every chosen Set value, including a Set equal to the current value,
	# under buffs, penalties, jam, Rewrite and forced-20 printed dice.
	for mode in range(5):
		_clear_statuses(heroes + enemies)
		match mode:
			0: _buff(heroes[0], 3)
			1: heroes[0]["rfe_stacks"] = [{"amt": 3, "turns_left": 9}]
			2: heroes[0]["jam_cap"] = 10
			3: heroes[0]["rewrite_pending"] = true
			4: heroes[0]["forced_20_pending"] = true
		stub.queue = [9, 5, 7, 4, 8]
		await _begin_roll()
		await _await_all_locked()
		if mode == 3:
			_tray.call("play_rewrite_scramble", "hero", uid)
			var marker: Label3D = _tray.get("_die_by_key")["hero:" + uid].get_node("Visuals/PendingMarker")
			for frame in range(12):
				await process_frame
				_check("b", marker.text == "REWRITE->3", "Rewrite marker must remain static")
		var choices: Array = [_oracle("hero", uid)] + _span(1, 20)
		for chosen in choices:
			bs.set("protocol_points", 100)
			pa.call("_apply_set", uid, chosen)
			await _await_all_locked()
			var die: RigidBody3D = _tray.get("_die_by_key")["hero:" + uid]
			if _inject("g"):
				_top(die).text = "99"
			_check("g", int(_top(die).text) == chosen and _oracle("hero", uid) == chosen,
				"Set %d under mode %d must show and act on chosen value" % [chosen, mode])
			_check("g", _labels(die) == _span(1, 20).map(func(v): return str(v)), "Set must print plain 1..20, even when value unchanged (mode %d)" % mode)
	# G-27: Nudge beyond jam / all-3 print, subtract from all-20, and deep freeze
	# on a buffed die. These specifically need a reprint before the new tumble.
	for mode in range(3):
		_clear_statuses(heroes + enemies)
		if mode == 0:
			heroes[0]["jam_cap"] = 10
		elif mode == 1:
			heroes[0]["rewrite_pending"] = true
		else:
			heroes[0]["forced_20_pending"] = true
		stub.queue = [18, 5, 7, 4, 8]
		await _begin_roll()
		await _await_all_locked()
		bs.set("protocol_points", 100)
		engine.call("apply_nudge", bs, uid, false, true)
		if mode == 2:
			engine.call("apply_nudge", bs, uid, false, true)
		_scene.call("_on_die_values_changed")
		await _await_all_locked()
		_expect_value("hero", uid, [13, 6, 17][mode], "Nudge reprint case %d" % mode)
	_clear_statuses(heroes + enemies)
	_buff(enemies[0], 4)
	stub.queue = [5, 7, 9, 8, 6]
	await _begin_roll()
	await _await_all_locked()
	await _use_item(pa, "deep_zero_pin", {})
	await _await_all_locked()
	_expect_value("enemy", eid, 1, "buffed enemy Deep Freeze reprints to 1")
	# G-30: pending hijack survives every frozen tick and resumes after thaw.
	enemies[0]["hijack_pending"] = true
	enemies[0]["hijack_skip_next_tick"] = true
	cm.call("_tick_state", enemies[0])
	_check("f", bool(enemies[0]["hijack_pending"]), "frozen hijack must remain pending")
	_expect_value("enemy", eid, 1, "frozen hijack holds its number")
	enemies[0]["die_freeze_turns"] = 0
	enemies[0]["die_freeze_repeat_this_round"] = false
	_scene.call("_on_die_values_changed")
	await _await_all_locked()
	_expect_value("enemy", eid, 9, "hijack resumes copying after thaw")
	cm.call("_tick_state", enemies[0])
	_check("f", not bool(enemies[0]["hijack_pending"]), "hijack consumed after first unfrozen reveal")
	# Freeze the hero through the engine, then call engine functions directly.
	engine.call("item_freeze_die", bs, heroes[0], 2)
	_scene.call("_on_die_values_changed")
	await _await_all_locked()
	for repeat_only in [false, true]:
		heroes[0]["die_freeze_turns"] = 0 if repeat_only else 2
		heroes[0]["die_freeze_repeat_this_round"] = repeat_only
		for action in ["nudge", "set", "reroll"]:
			var before := _spend_snapshot(bs, stub)
			var result: Variant
			match action:
				"nudge": result = engine.call("apply_nudge", bs, uid, true, true)
				"set": result = engine.call("apply_set", bs, uid, 20)
				"reroll": result = engine.call("apply_reroll", bs, uid)
			if _inject("h"):
				bs.set("protocol_points", int(bs.get("protocol_points")) - 1)
			_check("h", before == _spend_snapshot(bs, stub), "frozen %s changed state, spend flags or RNG" % action)
			_check("h", result == {"kind": "frozen"} if action == "nudge" else result == (-1 if action == "set" else 0), "frozen %s must report refusal" % action)
	print("[DICE_FACE_GATE] G-25..G-30: Set, reprints, frozen guards and hijack/thaw")


func _spend_snapshot(bs: Object, stub: ScriptedRolls) -> String:
	return var_to_str([bs.get("hero_rolls"), bs.get("hero_roll_nudges"), bs.get("hero_roll_sets"),
		bs.get("protocol_points"), bs.get("free_nudge_used"), bs.get("root_access_used"),
		stub.queue, stub.fallback.state])
