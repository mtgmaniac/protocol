# G-47 reroll hop gate (Kev, 2026-10-05): a reroll is a real hop in the die's
# own slot. On a six-die tray (place_rolls: every die at rest in its slot) the
# script rerolls the dice in turn, many times, judged on every physics step:
#   uniform   the landed faces are uniform over 1-20 (chi-square, 19 df), AND
#             uniform for dice that start on 1-5, 6-10, 11-15 and 16-20 each,
#             AND a die lands back on its starting face about 1 time in 20
#             (the die must forget where it started)
#   contact   the hopping die never touches another die (no contact reported
#             by the physics server, no touching or overlapping drawn hulls),
#             and no other die moves
#   slot      the hopping die never leaves its slot (horizontal travel)
#   snap      the face that lands up is the face that ends up: the top face
#             never changes from the moment the die settles, through the
#             upright snap, and it is the raw roll
#   godot --headless --path . -s scripts/debug/reroll_hop_gate.gd -- --n=1000
#   -- --break=uniform|start|contact|slot|snap injects a real violation; exit 1.
# scripts/checks/reroll_hop_gate.py shards the hops over several processes
# (--seed, --pairs-out, --physics-only) and pools them through --analyze=<files>,
# which runs the uniformity tests alone, with no physics, on the pooled pairs.
extends SceneTree

const SPEED := 16
# 19 df, p 0.0001: the gate runs six uniformity tests per run and must pass ten
# runs in ten, so each is held to a false-failure rate far below 1 in 1,000.
const CHI2_CRITICAL := 50.80
# Two-sided z for "lands on its starting face 1 time in 20", p 0.00001.
const Z_CRITICAL := 4.42
# Per-starting-face groups: a die that starts on 1-5 must land uniformly too.
const START_GROUPS := [[1, 5], [6, 10], [11, 15], [16, 20]]
# Fewer hops than this in a group and its chi-square is meaningless (cells < 5).
const MIN_PER_GROUP := 100
const SLOT_TOLERANCE := 0.02
const HEROES := ["h0", "h1", "h2"]
const ENEMIES := ["e0", "e1", "e2"]

var _n: int = 1000
var _break: String = ""
var _seed: int = 20261005
var _pairs_out: String = ""
var _physics_only: bool = false
var _min_group: int = MIN_PER_GROUP
var _analyze: Array = []
var _rest_basis := Basis.IDENTITY
var _tray: Node
var _hull: Array = []
var _norms: Array = []
var _edges: Array = []
var _fails: Dictionary = {"uniform": [], "contact": [], "slot": [], "snap": []}
# The hop being judged.
var _die: RigidBody3D = null
var _slot := Vector3.ZERO
var _others: Dictionary = {}      # other die -> its transform before the hop
var _airborne: bool = false
var _settled_top: String = ""
var _injected: bool = false
var _max_travel: float = 0.0
var _contacts: int = 0
var _steps: int = 0
# Diagnostics (the landed face against the starting face, turns and bounces).
var _start_face: int = 0
var _turns: float = 0.0
var _bounces: int = 0
var _prev_vy: float = 0.0
var _pairs: Array = []       # [start face, landed face] per hop
var _turn_log: Array = []
var _bounce_log: Array = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--n="):
			_n = int(arg.trim_prefix("--n="))
		elif arg.begins_with("--break="):
			_break = arg.trim_prefix("--break=")
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--pairs-out="):
			_pairs_out = arg.trim_prefix("--pairs-out=")
		elif arg == "--physics-only":
			_physics_only = true
		elif arg.begins_with("--min-group="):
			_min_group = int(arg.trim_prefix("--min-group="))
		elif arg.begins_with("--analyze="):
			_analyze = Array(arg.trim_prefix("--analyze=").split(","))
	call_deferred("_run")


func _run() -> void:
	if not _analyze.is_empty():
		_run_analysis()
		return
	root.size = Vector2i(1080, 2400)
	Engine.physics_ticks_per_second = 120 * SPEED
	Engine.time_scale = SPEED
	Engine.max_physics_steps_per_frame = 64
	seed(_seed)
	var host := Control.new()
	host.size = Vector2(1056, 1100)
	root.add_child(host)
	_tray = load("res://scenes/battle/DiceTray3D.tscn").instantiate()
	_tray.custom_minimum_size = host.size
	host.add_child(_tray)
	_tray.call("set_combat_zone_rect", Rect2(Vector2.ZERO, host.size))
	await process_frame
	_build_hull()
	var raws := {"hero": {}, "enemy": {}}
	for uid in HEROES:
		raws["hero"][uid] = 10
	for uid in ENEMIES:
		raws["enemy"][uid] = 10
	_tray.call("place_rolls", HEROES.map(func(u): return {"id": u, "name": u}), ENEMIES.map(func(u): return {"id": u, "name": u}), raws)
	await _idle()
	if _break == "contact":
		# A neighbour parked inside the hop's reach.
		var a: RigidBody3D = _tray.call("_get_die_for_entry", "hero", "h0")
		var b: RigidBody3D = _tray.call("_get_die_for_entry", "hero", "h1")
		b.global_position = a.global_position + Vector3(1.3, 0.0, 0.0)
		print("[REROLL_HOP] injected violation (contact)")
	var keys: Array = []
	for uid in HEROES:
		keys.append(["hero", uid])
	for uid in ENEMIES:
		keys.append(["enemy", uid])
	for i in range(_n):
		var key: Array = keys[0] if _break == "contact" else keys[i % keys.size()]
		_begin_hop(_tray.call("_get_die_for_entry", key[0], key[1]))
		var raw: int = await _tray.call("reroll_die_to_result", key[0], key[1])
		await _idle()
		_end_hop(raw)
	_report()


func _idle() -> void:
	for _i in range(20000):
		await process_frame
		if not bool(_tray.get("_is_rolling")):
			return


func _begin_hop(die: RigidBody3D) -> void:
	_die = die
	_slot = die.global_position
	_others.clear()
	for d in (_tray.get("_die_by_key") as Dictionary).values():
		if is_instance_valid(d) and d != die:
			_others[d] = (d as Node3D).global_transform
	_airborne = false
	_settled_top = ""
	_injected = false
	_start_face = int(_top(die).name.trim_prefix("FaceNumber"))
	_rest_basis = die.global_basis
	_turns = 0.0
	_bounces = 0
	_prev_vy = 0.0


func _end_hop(raw: int) -> void:
	if _die == null or not is_instance_valid(_die):
		_fail("snap", "the hopping die was freed")
		return
	_pairs.append([_start_face, raw])
	_turn_log.append(_turns)
	_bounce_log.append(_bounces)
	var top: String = _top(_die).name
	_expect("snap", top == _settled_top, "%s settled showing %s, ended showing %s" % [_name(_die), _settled_top, top])
	_expect("snap", top == "FaceNumber%d" % raw, "%s acts on %d but shows %s" % [_name(_die), raw, top])
	var travel := Vector2(_die.global_position.x - _slot.x, _die.global_position.z - _slot.z).length()
	_expect("slot", travel <= SLOT_TOLERANCE, "%s ended %.3f from its slot" % [_name(_die), travel])
	for d in _others:
		if is_instance_valid(d):
			_expect("contact", (_others[d] as Transform3D).is_equal_approx((d as Node3D).global_transform), "%s moved while %s hopped" % [_name(d), _name(_die)])
	_die = null


# Judged before every physics step.
func _physics_process(_delta: float) -> bool:
	if _die == null or not is_instance_valid(_die):
		return false
	_steps += 1
	var moving: bool = not _die.freeze
	if moving:
		_turns += _die.angular_velocity.length() * _delta / TAU
		if _airborne and _prev_vy < 0.0 and _die.linear_velocity.y > 0.0:
			_bounces += 1
		_prev_vy = _die.linear_velocity.y
		if not _airborne:
			_airborne = true
			if _break == "uniform":
				# Every hop starts from the same pose with no spin: one face only.
				_die.global_transform = Transform3D(Basis.IDENTITY, _die.global_position)
				_die.angular_velocity = Vector3.ZERO
				if not _injected:
					print("[REROLL_HOP] injected violation (uniform)")
				_injected = true
			elif _break == "start":
				# The launch randomization removed: the die leaves in the pose it rested in.
				_die.global_basis = _rest_basis
				if not _injected:
					print("[REROLL_HOP] injected violation (start)")
				_injected = true
		elif _break == "slot" and not _injected and _die.linear_velocity.y < 0.0:
			_die.axis_lock_linear_x = false
			_die.linear_velocity = Vector3(8.0, _die.linear_velocity.y, 0.0)
			_injected = true
			print("[REROLL_HOP] injected violation (slot)")
		for body in _die.get_colliding_bodies():
			if body is RigidBody3D and body != _die:
				_contacts += 1
				_fail("contact", "%s touched %s mid-hop (physics contact)" % [_name(_die), _name(body)])
	elif _airborne and _settled_top == "":
		_settled_top = _top(_die).name
	elif _settled_top != "" and _break == "snap" and not _injected and bool(_die.get_meta("in_motion", false)):
		_die.global_basis = _die.global_basis.rotated(Vector3.RIGHT, PI)
		_injected = true
		print("[REROLL_HOP] injected violation (snap)")
	if _airborne and _settled_top != "" and bool(_die.get_meta("in_motion", false)):
		_expect("snap", _top(_die).name == _settled_top, "%s changed its top face during the snap (%s -> %s)" % [_name(_die), _settled_top, _top(_die).name])
	var travel := Vector2(_die.global_position.x - _slot.x, _die.global_position.z - _slot.z).length()
	_max_travel = maxf(_max_travel, travel)
	_expect("slot", travel <= SLOT_TOLERANCE, "%s left its slot by %.3f mid-hop" % [_name(_die), travel])
	for d in _others:
		if is_instance_valid(d):
			_expect("contact", not _touching(_die, d), "%s touched %s mid-hop (hulls)" % [_name(_die), _name(d)])
	return false


func _report() -> void:
	if _pairs_out != "":
		var lines := PackedStringArray()
		for pr in _pairs:
			lines.append("%d,%d" % [pr[0], pr[1]])
		var f := FileAccess.open(_pairs_out, FileAccess.WRITE)
		f.store_string("
".join(lines) + "
")
		f.close()
	if not _physics_only:
		_judge_uniform(_pairs)
	var tsum := 0.0
	var tmin := INF
	var tmax := 0.0
	for t in _turn_log:
		tsum += t
		tmin = minf(tmin, t)
		tmax = maxf(tmax, t)
	var bsum := 0
	var bmax := 0
	for b in _bounce_log:
		bsum += b
		bmax = maxi(bmax, b)
	var h: float = maxf(float(_turn_log.size()), 1.0)
	print("[REROLL_HOP] turns per hop mean %.2f (min %.2f max %.2f); bounces before rest mean %.2f max %d" % [tsum / h, tmin, tmax, bsum / h, bmax])
	print("[REROLL_HOP] physics steps judged=%d max slot travel=%.4f physics contacts=%d" % [_steps, _max_travel, _contacts])
	_finish()


# No physics: the uniformity tests alone, on the hops pooled from the shards.
func _run_analysis() -> void:
	var pairs: Array = []
	for path in _analyze:
		var f := FileAccess.open(str(path), FileAccess.READ)
		if f == null:
			_fail("uniform", "cannot read pairs file %s" % path)
			continue
		for line in f.get_as_text().split("
", false):
			var parts: PackedStringArray = line.split(",")
			if parts.size() == 2:
				pairs.append([int(parts[0]), int(parts[1])])
	_n = pairs.size()
	_judge_uniform(pairs)
	_finish()


func _finish() -> void:
	var ok := true
	for kind in _fails:
		var list: Array = _fails[kind]
		print("[REROLL_HOP] (%s) failures=%d" % [kind, list.size()])
		for msg in list.slice(0, 6):
			print("[REROLL_HOP]   (%s) %s" % [kind, msg])
		if not list.is_empty():
			ok = false
	print("[REROLL_HOP] %s" % ("PASS" if ok else "FAIL"))
	Engine.time_scale = 1.0
	await create_timer(0.5).timeout
	quit(0 if ok else 1)


# The landed faces over every hop, then split by the face the die started on. The
# die must forget where it started: every start group (1-5, 6-10, 11-15, 16-20)
# lands uniformly, and it lands back on its own starting face about 1 time in 20.
func _judge_uniform(pairs: Array) -> void:
	var faces: Dictionary = {}
	var same: int = 0
	for pr in pairs:
		faces[int(pr[1])] = int(faces.get(int(pr[1]), 0)) + 1
		if int(pr[0]) == int(pr[1]):
			same += 1
	var chi: float = _chi2(faces, pairs.size())
	_expect("uniform", pairs.size() == _n, "%d hops landed, %d expected" % [pairs.size(), _n])
	_expect("uniform", chi < CHI2_CRITICAL, "landed faces not uniform: chi-square %.1f >= %.2f over %d hops %s" % [chi, CHI2_CRITICAL, pairs.size(), str(faces)])
	print("[REROLL_HOP] hops=%d chi2=%.1f (critical %.2f) faces=%s" % [pairs.size(), chi, CHI2_CRITICAL, str(faces)])
	var p_same: float = float(same) / maxf(float(pairs.size()), 1.0)
	var z: float = (float(same) - 0.05 * pairs.size()) / sqrt(maxf(pairs.size() * 0.05 * 0.95, 0.0001))
	print("[REROLL_HOP] landed on its own starting face %.4f of hops (fair d20 0.0500, z=%.2f)" % [p_same, z])
	_expect("uniform", absf(z) < Z_CRITICAL, "landed on its starting face %.4f of the time (fair 0.05, z=%.2f)" % [p_same, z])
	for g in START_GROUPS:
		var counts: Dictionary = {}
		var n: int = 0
		for pr in pairs:
			if int(pr[0]) >= int(g[0]) and int(pr[0]) <= int(g[1]):
				counts[int(pr[1])] = int(counts.get(int(pr[1]), 0)) + 1
				n += 1
		var c2: float = _chi2(counts, n)
		print("[REROLL_HOP] starts on %d-%d: hops=%d chi2=%.1f" % [g[0], g[1], n, c2])
		_expect("uniform", n >= _min_group, "only %d hops started on %d-%d (need %d)" % [n, g[0], g[1], _min_group])
		_expect("uniform", c2 < CHI2_CRITICAL, "hops starting on %d-%d not uniform: chi-square %.1f >= %.2f over %d hops %s" % [g[0], g[1], c2, CHI2_CRITICAL, n, str(counts)])


func _chi2(counts: Dictionary, n: int) -> float:
	var expected: float = float(n) / 20.0
	var c2 := 0.0
	for v in range(1, 21):
		c2 += pow(float(counts.get(v, 0)) - expected, 2) / maxf(expected, 0.0001)
	return c2


func _expect(kind: String, ok: bool, msg: String) -> void:
	if not ok:
		_fail(kind, msg)


func _fail(kind: String, msg: String) -> void:
	_fails[kind].append(msg)


func _name(d: Object) -> String:
	var entry: Dictionary = (d as Node).get_meta("entry", {}) if d is Node else {}
	return "%s:%s" % [entry.get("side", "?"), entry.get("id", "?")]


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


func _build_hull() -> void:
	_hull = Array(_tray.call("_get_d20_convex_points"))
	for f in _tray.call("_get_d20_faces"):
		var a: Vector3 = _hull[f[0]]
		var b: Vector3 = _hull[f[1]]
		var c: Vector3 = _hull[f[2]]
		_add_axis(_norms, (b - a).cross(c - a).normalized())
		for pr in [[a, b], [b, c], [c, a]]:
			_add_axis(_edges, ((pr[1] as Vector3) - (pr[0] as Vector3)).normalized())


func _add_axis(axes: Array, v: Vector3) -> void:
	for x in axes:
		if absf((x as Vector3).dot(v)) > 0.9999:
			return
	axes.append(v)


# Drawn hulls touching or overlapping (separating-axis test with no slack).
func _touching(a: RigidBody3D, b: RigidBody3D) -> bool:
	if a.global_position.distance_to(b.global_position) > 2.05:
		return false
	var ka: float = (a.get_node("Visuals") as Node3D).scale.x
	var kb: float = (b.get_node("Visuals") as Node3D).scale.x
	var xa: Transform3D = a.global_transform
	var xb: Transform3D = b.global_transform
	var pa: Array = _hull.map(func(p): return xa * ((p as Vector3) * ka))
	var pb: Array = _hull.map(func(p): return xb * ((p as Vector3) * kb))
	var ba: Basis = xa.basis.orthonormalized()
	var bb: Basis = xb.basis.orthonormalized()
	var axes: Array = []
	for n in _norms:
		axes.append(ba * (n as Vector3))
		axes.append(bb * (n as Vector3))
	for ea in _edges:
		for eb in _edges:
			var ax: Vector3 = (ba * (ea as Vector3)).cross(bb * (eb as Vector3))
			if ax.length_squared() > 0.000001:
				axes.append(ax.normalized())
	for ax_variant in axes:
		var ax: Vector3 = ax_variant
		var min_a := INF
		var max_a := -INF
		for p in pa:
			min_a = minf(min_a, ax.dot(p))
			max_a = maxf(max_a, ax.dot(p))
		var min_b := INF
		var max_b := -INF
		for p in pb:
			min_b = minf(min_b, ax.dot(p))
			max_b = maxf(max_b, ax.dot(p))
		if max_a < min_b or max_b < min_a:
			return false
	return true
