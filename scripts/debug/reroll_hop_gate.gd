# G-47 reroll hop gate (Kev, 2026-10-05): a reroll is a real hop in the die's
# own slot. On a six-die tray (place_rolls: every die at rest in its slot) the
# script rerolls the dice in turn, many times, judged on every physics step:
#   uniform   the landed faces are uniform over 1-20 (chi-square, 19 df,
#             fails above 43.82 = p 0.001)
#   contact   the hopping die never touches another die (no contact reported
#             by the physics server, no touching or overlapping drawn hulls),
#             and no other die moves
#   slot      the hopping die never leaves its slot (horizontal travel)
#   snap      the face that lands up is the face that ends up: the top face
#             never changes from the moment the die settles, through the
#             upright snap, and it is the raw roll
#   godot --headless --path . -s scripts/debug/reroll_hop_gate.gd -- --n=1000
#   -- --break=uniform|contact|slot|snap injects a real violation; must exit 1.
extends SceneTree

const SPEED := 16
const CHI2_CRITICAL := 43.82
const SLOT_TOLERANCE := 0.02
const HEROES := ["h0", "h1", "h2"]
const ENEMIES := ["e0", "e1", "e2"]

var _n: int = 1000
var _break: String = ""
var _tray: Node
var _hull: Array = []
var _norms: Array = []
var _edges: Array = []
var _fails: Dictionary = {"uniform": [], "contact": [], "slot": [], "snap": []}
var _faces: Dictionary = {}
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


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--n="):
			_n = int(arg.trim_prefix("--n="))
		elif arg.begins_with("--break="):
			_break = arg.trim_prefix("--break=")
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1080, 2400)
	Engine.physics_ticks_per_second = 120 * SPEED
	Engine.time_scale = SPEED
	Engine.max_physics_steps_per_frame = 64
	seed(20261005)
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


func _end_hop(raw: int) -> void:
	if _die == null or not is_instance_valid(_die):
		_fail("snap", "the hopping die was freed")
		return
	_faces[raw] = int(_faces.get(raw, 0)) + 1
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
		if not _airborne:
			_airborne = true
			if _break == "uniform":
				# Every hop starts from the same pose with no spin: one face only.
				_die.global_transform = Transform3D(Basis.IDENTITY, _die.global_position)
				_die.angular_velocity = Vector3.ZERO
				if not _injected:
					print("[REROLL_HOP] injected violation (uniform)")
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
	var total: int = 0
	for v in range(1, 21):
		total += int(_faces.get(v, 0))
	var chi := 0.0
	var expected: float = float(total) / 20.0
	for v in range(1, 21):
		chi += pow(float(_faces.get(v, 0)) - expected, 2) / maxf(expected, 0.0001)
	_expect("uniform", total == _n, "%d hops landed, %d expected" % [total, _n])
	_expect("uniform", chi < CHI2_CRITICAL, "landed faces not uniform: chi-square %.1f >= %.2f over %d hops %s" % [chi, CHI2_CRITICAL, total, str(_faces)])
	print("[REROLL_HOP] hops=%d chi2=%.1f (critical %.2f) faces=%s" % [total, chi, CHI2_CRITICAL, str(_faces)])
	print("[REROLL_HOP] physics steps judged=%d max slot travel=%.4f physics contacts=%d" % [_steps, _max_travel, _contacts])
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
