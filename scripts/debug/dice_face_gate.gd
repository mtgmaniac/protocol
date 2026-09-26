# Dice face gate (P0, docs/audits/DICE_FACE_AUDIT.md; Option C, Kev 2026-09-26).
# HARD gate. Watches every die on every frame and FAILS if:
#   (a) a die whose digits are LOCKED shows an up-face numeral (the Label3D that
#       actually points up; no face table trusted) different from the value the
#       unit will act on. The oracle is rebuilt here the way resolve_step and
#       resolve_round build it (effective rolls, then hijack copies the heroes'
#       highest), not read back from the tray or from _die_value.
#   (b) a die with a pre-roll modifier LANDS on a value outside the range that
#       modifier allows (the range is computed here from the setup, e.g. 4-20
#       under +3), independent of the engine.
#   (c) a die rotates after it settles: its body pose moves, or its face rig
#       turns while the digits are locked (a turn is only legal mid-scramble,
#       where it cannot be seen). Reroll is a deliberate re-throw and exempt.
#   (d) a FROZEN die's number changes or scrambles while it is frozen (G-23:
#       freeze locks the number on the face), including when a modifier is
#       added or removed after the freeze, in the same or a later round.
#
# Part A: the tray alone, 7 slots (3 hero + 4 enemy) x all 20 values.
# Part B: a live BattleScene, scripted naturals (a stub roll provider) so every
#   modifier path meets all 20 naturals: +roll buff, roll penalty, jam, enemy
#   rewrite, forced 20, Resonant Chorus, frozen 20s both sides.
# Part C: after-landing changes on the live scene: Nudge, Set, Reroll, items
#   (roll buff, penalty, enemy reroll, freeze, Deep Freeze Charge), Sync
#   Antenna, and a live hijack following the heroes' highest die.
# Part D: freeze locks the shown number — a +3 hero frozen on a buffed 20 by an
#   item, and a buffed enemy frozen by the resolution path; modifiers added and
#   removed afterwards, across two more rolls.
#
# Physics runs 8x (ticks and time scale raised together, so each step is still
# 1/120 s: the same simulation, just less wall time).
# Run: godot --headless --path . -s scripts/debug/dice_face_gate.gd
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
var _settled: Dictionary = {}     # die instance id -> Basis at settle
var _rig_prev: Dictionary = {}    # die instance id -> [Basis, locked]
var _reroll_exempt: Dictionary = {}
var _fails: Dictionary = {"a": [], "b": [], "c": [], "d": []}
var _checks: Dictionary = {"a": 0, "b": 0, "c": 0, "d": 0}
var _frozen_lock: Dictionary = {}  # "side:id" -> the number the frozen die must keep
var _landed_pairs: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.physics_ticks_per_second = 120 * SPEED
	Engine.time_scale = SPEED
	Engine.max_physics_steps_per_frame = 64
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


func _sample() -> void:
	var dice: Dictionary = _tray.get("_die_by_key")
	for key in dice:
		var die: RigidBody3D = dice[key] as RigidBody3D
		if die == null or not is_instance_valid(die) or not die.is_inside_tree():
			continue
		var entry: Dictionary = die.get_meta("entry", {})
		var side: String = str(entry.get("side", ""))
		var uid: String = str(entry.get("id", ""))
		var iid: int = die.get_instance_id()
		var locked: bool = bool(_tray.call("is_die_locked", side, uid))
		# (c) body pose: record at the first frozen frame (the settle), then never move.
		if die.freeze and not _settled.has(iid) and not _reroll_exempt.has(iid):
			_settled[iid] = die.global_transform.basis
		if _settled.has(iid) and not _reroll_exempt.has(iid):
			_checks["c"] += 1
			var deg: float = _angle_deg(_settled[iid], die.global_transform.basis)
			if deg > ROTATION_EPS_DEG:
				_fail("c", "%s body rotated %.2f deg after settling" % [key, deg])
				_settled[iid] = die.global_transform.basis
		# (c) face rig: may only turn while the digits scramble.
		var rig: Node3D = die.get_node_or_null("Visuals/FaceRig") as Node3D
		if rig != null:
			var rb: Basis = rig.basis.orthonormalized()
			if _rig_prev.has(iid):
				var prev: Array = _rig_prev[iid]
				if bool(prev[1]) and locked and _angle_deg(prev[0], rb) > ROTATION_EPS_DEG:
					_fail("c", "%s face rig turned %.1f deg with its digits locked" % [key, _angle_deg(prev[0], rb)])
			_rig_prev[iid] = [rb, locked]
		_check_frozen(key, side, uid, die, locked)
		if not locked:
			continue
		var shown: int = int(_tray.call("up_face_numeral", side, uid))
		var want: int = _oracle(side, uid)
		if want > 0:
			_checks["a"] += 1
			if shown != want:
				_fail("a", "%s locked on %d but the unit acts on %d" % [key, shown, want])
		if _ranges.has(key):
			_checks["b"] += 1
			var allowed: Array = _ranges[key]
			if not allowed.has(shown):
				_fail("b", "%s landed on %d outside its modifier range %s" % [key, shown, _range_text(allowed)])
			_ranges.erase(key)  # (b) is about the landing value


# (d): while a unit's die is frozen, its number is fixed. The lock is taken
# from what the die showed just BEFORE the freeze (set by the scenario), or at
# its first locked sample for a die that was already frozen.
func _check_frozen(key: String, side: String, uid: String, die: RigidBody3D, locked: bool) -> void:
	if not _use_scene_oracle:
		return
	var st: Dictionary = _state_for(side, uid)
	if st.is_empty() or int(st.get("die_freeze_turns", 0)) <= 0:
		_frozen_lock.erase(key)
		return
	if not _frozen_lock.has(key):
		if locked:
			_frozen_lock[key] = int(_tray.call("up_face_numeral", side, uid))
		return
	_checks["d"] += 1
	if bool(die.get_meta("scrambling", false)):
		_fail("d", "%s scrambled while frozen (locked on %d)" % [key, int(_frozen_lock[key])])
	elif locked and int(_tray.call("up_face_numeral", side, uid)) != int(_frozen_lock[key]):
		_fail("d", "%s frozen on %d now shows %d" % [key, int(_frozen_lock[key]), int(_tray.call("up_face_numeral", side, uid))])


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


func _angle_deg(a: Basis, b: Basis) -> float:
	var q: Quaternion = (b.orthonormalized() * a.orthonormalized().inverse()).get_rotation_quaternion()
	var deg: float = rad_to_deg(q.get_angle())
	return minf(deg, 360.0 - deg)


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
		_tray.call("play_rolls", hero_entries, enemy_entries)
		await _await_all_locked()
	# A live value change on the bare tray (scramble-and-lock, no rotation).
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
	for st in [heroes[0], enemies[0]]:
		st["die_freeze_turns"] = 2
		st["frozen_die_value"] = 20
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
	await _reroll(pa, h[1])                  # 19 -> 4
	await _await_all_locked()
	_expect_value("enemy", e[0], 15, "hijack follows a Reroll")
	await _use_item(pa, "momentum_core", heroes[2])  # +2 -> 17
	await _await_all_locked()
	_expect_value("enemy", e[0], 17, "hijack follows a roll-buff item")
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
			_fail("b", "%s never locked a landing value to check" % key)
	_ranges.clear()


# Ranges arm once the NEW throw has started (no die reads as locked while the
# tray rolls), so the previous roll's locked dice are never judged by them.
func _begin_roll(ranges: Dictionary = {}) -> void:
	_ranges.clear()
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
	_reroll_exempt[iid] = true
	_settled.erase(iid)
	await pa.call("_apply_reroll", hero_id)
	_reroll_exempt.erase(iid)
	if die != null and is_instance_valid(die):
		_settled[iid] = die.global_transform.basis


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
	var failed: bool = false
	for kind in ["a", "b", "c", "d"]:
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
