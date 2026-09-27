class_name DiceTray3D
extends Control
signal recording_impact(key: String, speed: float)

signal roll_finished

const DIE_RADIUS := 1.00
const DIE_COLLISION_LAYER := 1
const DIE_COLLISION_MASK := 1
# Result-row layout extents (visual placement of settled dice). The *physical*
# tray walls are rebuilt from the live camera/viewport so they sit exactly at
# the visible combat-zone edges — see _update_world_bounds().
const TRAY_HALF_WIDTH := 3.25
const TRAY_HALF_DEPTH := 5.5
const COLLISION_WALL_HEIGHT := 7.0
const COLLISION_WALL_THICKNESS := 0.5
# A die is 1.0 world-units in radius (~50-90x a real d20), so plain gravity looks
# like slow motion. Scaling gravity up restores believable fall/bounce pacing
# while staying readable.
const DIE_GRAVITY_SCALE := 7.0
const THROW_SPEED_MIN := 10.5
const THROW_SPEED_MAX := 13.5
const THROW_TUMBLE_MIN := 9.0
const THROW_TUMBLE_MAX := 15.0
const THROW_WOBBLE_MAX := 4.0
const THROW_YAW_JITTER := 0.10
# Low, flat toss: dice leave the hand barely above the felt, so they engage the
# floor within a fraction of the tray and *roll* across it. This is what makes
# frozen dice read as solid — a high launch sails over an obstacle die, which
# from the top-down camera is indistinguishable from clipping through it.
const THROW_HAND_HEIGHT_MIN := 1.35
const THROW_HAND_HEIGHT_MAX := 1.75
# Per-die offsets within one hand toss: (lateral, up, along-throw). Spread wide
# enough that no two dice spawn overlapping (centres >= 2 radii apart).
const THROW_CLUSTER_OFFSETS: Array[Vector3] = [
	Vector3(0.0, 0.0, 0.0),
	Vector3(2.1, 0.25, 0.0),
	Vector3(-2.1, 0.5, 0.0),
	Vector3(1.05, 0.75, -2.0),
	Vector3(-1.05, 1.0, -2.0),
]
# Walls lean inward like a real dice tray's sloped rim, so a die can never come
# to rest tilted against a wall or wedged upright in a corner — gravity always
# rolls it back onto the floor field.
const WALL_LEAN_RADIANS := 0.14
# After this long the felt "grabs" the dice: damping ramps in so stragglers
# spiralling on a vertex wind down instead of spinning forever.
const LATE_SETTLE_DAMP_START := 3.0
const LATE_SETTLE_DAMP_RAMP := 2.0
const SETTLE_LINEAR_SPEED := 0.018
const SETTLE_ANGULAR_SPEED := 0.026
const SETTLE_REQUIRED_TIME := 0.16
const FACE_RESOLVE_MIN_TIME := 0.75
const FACE_RESOLVE_LINEAR_SPEED := 0.16
const FACE_RESOLVE_ANGULAR_SPEED := 0.24
const MAX_ROLL_TIME := 6.0
const RESULT_SNAP_DELAY := 0.20
const RESULT_PRESENTATION_TIME := 0.42
const RESULT_SCALE := 0.95
const RESULT_FACE_NORMAL := Vector3(0.0, 1.0, 0.0)
const RESULT_FACE_TEXT_UP := Vector3(0.0, 0.0, -1.0)
const RESULT_MIN_SEPARATION := DIE_RADIUS * 2.22
const RESULT_LAYOUT_ITERATIONS := 24
const RESULT_SLOT_X_GAP := DIE_RADIUS * 2.85
const RESULT_ENEMY_ROW_Z := 2.51
const RESULT_HERO_ROW_Z := 3.78
const RESULT_OUTER_MARGIN := DIE_RADIUS * 0.12
const RESULT_TOP_CLEARANCE := DIE_RADIUS * 0.42
const RESULT_SIDE_OVERFLOW := DIE_RADIUS * 1.65
const RESULT_HERO_BOTTOM_OVERFLOW := DIE_RADIUS * 1.25
const RESULT_ENEMY_BOTTOM_OVERFLOW := DIE_RADIUS * 0.45
const RESULT_HERO_SIDE_NUDGE := 0.0
const RESULT_ENEMY_SIDE_NUDGE := 0.0
const RESULT_HERO_DOWN_NUDGE := 0.0
const RESULT_ENEMY_DOWN_NUDGE := 0.0

var _viewport: SubViewport
var _viewport_container: SubViewportContainer
var _world_root: Node3D
var _dice_root: Node3D
var _camera: Camera3D
var _die_by_key: Dictionary = {}
var _face_normals: Array[Vector3] = []
var _face_centers: Array[Vector3] = []
var _face_text_bases: Array[Basis] = []
var _face_values: Array[int] = []
var _is_rolling: bool = false
# G-33 (UI batch 2026-09-27, B10): during a single-die re-throw every other die
# resting in the tray is a solid, immovable obstacle. Settled dice normally have
# collision off (they are presentation); for the length of a re-throw they are
# frozen STATIC bodies on the dice layer, so the thrown die bounces off them,
# and the slide into its slot is routed around them. They never move or change
# face. Restored to their previous collision state afterwards.
var _rethrow_obstacles: Array = []
var _rethrow_saved: Dictionary = {}  # die instance id -> [layer, mask, freeze_mode, shape]
# A resting die's collider during a re-throw: its d20 hull enlarged past the
# drawn die (drawn at RESULT_SCALE) so even a fast contact, which the solver
# lets sink in by a few hundredths, stops before the visible die.
const RETHROW_OBSTACLE_SCALE := 1.06
var _rethrow_obstacle_shape: ConvexPolygonShape3D = null
# Centre-to-centre clearance for the post-landing slide: the moving die's reach
# (DIE_RADIUS, it is still full size) plus a resting die's (DIE_RADIUS at
# RESULT_SCALE), plus a hair. Sphere-based, so it is conservative for a d20.
const RETHROW_SLIDE_CLEARANCE := DIE_RADIUS * (1.0 + RESULT_SCALE) + 0.02
const RETHROW_LANE_SAMPLES := 48
var _dice_number_font: Font
var _is_exiting_tree: bool = false
var _bounds_half_width: float = TRAY_HALF_WIDTH
var _bounds_min_z: float = -TRAY_HALF_DEPTH
var _bounds_max_z: float = TRAY_HALF_DEPTH
var _tray_bodies: Dictionary = {}
## Optional placement provider. Invalid for the unchanged portrait path.
var result_anchor_provider: Callable
# ONE source of truth for every die value (P0 dice-face audit): the scene's
# `_die_value(side, unit_id) -> int`, which is the value the unit will act on
# (BattleEngine effective roll, hijack included). The tray keeps NO copy of the
# effective-roll rule. Returns <= 0 when the unit has no value yet; the tray
# then falls back to the physics face (debug harnesses without a scene).
var value_provider: Callable
# While true the tray follows value_provider every frame, so a change made
# after landing (Nudge, Set, items, Sync Antenna, a live hijack copy) reaches
# the die without any call site having to remember to push it. The scene turns
# it off when the round resolves: the acted-on values are snapshotted there.
var _values_live: bool = false
# G-27 / G-25: the faces a die prints for its CURRENT state, from the scene's
# `_die_faces_now(side, unit_id) -> {"faces": [20 ints], "plain": bool}` (the
# engine's current_face_values). Used only to reprint a die when a deliberate
# change needs a value no printed face shows (or on a Set: plain 1–20).
var print_provider: Callable
# A deliberate change tips the die over onto a face showing the new value.
const TIP_OVER_TIME := 0.30
var _landscape_projection := false
var _last_landscape_size := Vector2.ZERO


func configure_landscape_projection() -> void:
	if _camera == null:
		return
	_landscape_projection = true
	# Three vertical slots plus their existing result tags; physical die radius,
	# materials, toss, outcomes and animation timing remain shared.
	_camera.size = preload("res://scripts/battle/landscape_battle_style.gd").VALUES.dice_camera_size
	_update_world_bounds()
	if not size.is_equal_approx(_last_landscape_size):
		_last_landscape_size = size
		call_deferred("_refresh_landscape_result_positions")


func _refresh_landscape_result_positions() -> void:
	if _is_rolling or _dice_root == null or not _landscape_projection:
		return
	var entries: Array = _get_result_entries_for_dice(_dice_root.get_children())
	var origins: Dictionary = _get_non_overlapping_result_origins(entries)
	for result in entries:
		var die: RigidBody3D = result.die
		var origin: Vector3 = origins.get(die.get_instance_id(), die.position)
		origin.y = die.position.y
		die.position = origin
		die.set_meta("assigned_result_origin", origin)

# ── Shared material bank ──────────────────────────────────────────────────────
# Every dice material comes from this STATIC cache, keyed by role + colour/zone.
# Static on purpose (web Issue 1): besides deduplicating per-die copies, the
# bank holds a permanent reference to each material feature-set, so the engine's
# internal per-feature-set shader is never freed when a battle's dice are torn
# down. Without it the compiled GL programs die with the last die of a battle
# and WebGL relinks them synchronously (~2s) at the next battle's first draw.
static var _material_bank: Dictionary = {}
# One-shot per session: web pipeline warm-up has already run.
static var _web_warmup_done: bool = false


static func _bank_material(key: String, builder: Callable) -> StandardMaterial3D:
	var cached: Variant = _material_bank.get(key, null)
	if cached is StandardMaterial3D:
		return cached
	var made: StandardMaterial3D = builder.call()
	_material_bank[key] = made
	return made


func _ready() -> void:
	_is_exiting_tree = false
	_build_ui()
	_build_world()
	_build_d20_face_data()
	_sync_viewport_size()
	reset()


# WebGL compiles+links every GL program synchronously at first draw, which used
# to land on the first roll of the battle (~2s freeze before dice appeared).
# Instead, MainMenu spawns a tiny hidden DiceTray3D at menu load and calls this
# (web only, once per session): it renders every dice material variant (both
# side colours, status filters, highlight/dim faces, billboard + face labels)
# in BATCHES with frames awaited between them, so the compile cost lands as a
# few short hitches while the player reads the menu instead of one long freeze
# at battle entry. The static material bank keeps the programs alive afterwards.
# The done-gate is set at START on purpose: if the player enters a battle before
# this finishes (the menu instance is freed mid-run), it never re-runs — the
# battle's first roll just eats whatever compilation remains (worst case equals
# the old behaviour; no deadlock, no double run).
func warm_up_web_pipelines() -> void:
	if not OS.has_feature("web") or _web_warmup_done:
		return
	if _is_rolling or _is_exiting_tree or not is_inside_tree():
		return
	_web_warmup_done = true
	var start_ms: int = Time.get_ticks_msec()
	_throw_context = {}
	var hero_die: RigidBody3D = _spawn_die({"side": "hero", "id": "__warmup_hero"}, 0, 2)
	var enemy_die: RigidBody3D = _spawn_die({"side": "enemy", "id": "__warmup_enemy"}, 1, 2)
	for die in [hero_die, enemy_die]:
		die.freeze = true
		die.linear_velocity = Vector3.ZERO
		die.angular_velocity = Vector3.ZERO
	hero_die.position = Vector3(-1.5, DIE_RADIUS, 0.6)
	enemy_die.position = Vector3(1.5, DIE_RADIUS, 0.6)
	var setup_ms: int = Time.get_ticks_msec() - start_ms
	# Draw offscreen: alpha-zero modulate keeps the SubViewport rendering (its
	# update mode gates on visibility, not modulate) while nothing reaches the
	# player's screen.
	var prev_modulate: Color = modulate
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	visible = true
	# Batch 1: base die (body, inner shell, face panels, bevels, edges, numerals).
	if not await _warm_render_frames(2):
		return
	# Batch 2: freeze/petrify shells + their billboard overlay labels.
	if is_instance_valid(hero_die):
		_set_die_frozen_visual(hero_die, true)
	if is_instance_valid(enemy_die):
		_set_die_frozen_visual(enemy_die, true, "petrify")
	if not await _warm_render_frames(2):
		return
	# Batch 3: jam shell + cap marker + pending (rewrite/hijack) marker.
	if is_instance_valid(enemy_die):
		_set_die_jam_visual(enemy_die, 5)
		_set_die_pending_marker(enemy_die, true, false)
	if not await _warm_render_frames(2):
		return
	# Batch 4: result highlight + dimmed faces + bevel outline (both sides).
	if is_instance_valid(hero_die):
		_highlight_top_face(hero_die, 20, "hero")
	if is_instance_valid(enemy_die):
		_highlight_top_face(enemy_die, 1, "enemy")
	if not await _warm_render_frames(2):
		return
	if _is_rolling:
		modulate = prev_modulate
		return
	visible = false
	modulate = prev_modulate
	_clear_dice()
	var total_ms: int = Time.get_ticks_msec() - start_ms
	print("[DiceTray3D] web pipeline warm-up: setup %d ms, render %d ms (total %d ms)" % [setup_ms, total_ms - setup_ms, total_ms])


# Awaits `count` process frames while the tray stays alive. Returns false if
# the tray is being freed (scene change) — callers abort the warm-up.
func _warm_render_frames(count: int) -> bool:
	for _i in range(count):
		var tree: SceneTree = get_tree()
		if _is_exiting_tree or tree == null:
			return false
		await tree.process_frame
		if _is_exiting_tree or not is_inside_tree():
			return false
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_viewport_size()
	elif what == NOTIFICATION_EXIT_TREE:
		_is_exiting_tree = true
		_is_rolling = false


func _sync_viewport_size() -> void:
	if _viewport == null:
		return
	var viewport_size := Vector2i(maxi(int(size.x), 2), maxi(int(size.y), 2))
	_viewport.size = viewport_size
	_update_world_bounds()


# The camera is orthographic with KEEP_HEIGHT, so the visible world region is a
# fixed-height rect whose width follows the combat-zone aspect. Rebuild the
# physical floor/walls so their inner faces sit exactly at the screen edges —
# every bounce the player sees comes from a real collider, never a teleport.
func _update_world_bounds() -> void:
	if _camera == null or _viewport == null:
		return
	var vp: Vector2 = Vector2(_viewport.size)
	if vp.x <= 2.0 or vp.y <= 2.0:
		return
	var half_h: float = _camera.size * 0.5
	var half_w: float = half_h * (vp.x / vp.y)
	_bounds_half_width = maxf(half_w, DIE_RADIUS * 1.6)
	_bounds_min_z = _camera.position.z - half_h
	_bounds_max_z = _camera.position.z + half_h
	_layout_tray_bodies()


# A settled die is snapped face-up, so its screen height is a fixed multiple of
# the tray's world scale. MEASURED off get_die_screen_bounds at the shipped
# 1080x2400 layout (209.8px tall in a 938px tray whose camera spans 8.345
# units => 104.9px => 0.933 units) rather than derived, because the silhouette
# of a d20 at RESULT_SCALE is not 2 x DIE_RADIUS in any axis. Held in WORLD
# units so it tracks the tray through every resize; the clearance gate
# (roll_button_clearance_test) is what keeps it honest.
const SETTLED_DIE_HALF_HEIGHT_UNITS := 0.933


# Half the height one settled die occupies ON SCREEN, in the same pixel space as
# get_die_screen_bounds. The layout reserves space around the Roll button from
# this: it used to reserve a hardcoded 80px for a die that really measures
# ~105px, so the 54px button/dice gap it thought it was leaving was actually 29.
# 0.0 before the camera exists — callers keep their own fallback.
func settled_die_half_height_px() -> float:
	if _camera == null or not is_instance_valid(_camera) or _camera.size <= 0.0:
		return 0.0
	if size.y <= 2.0:
		return 0.0
	return SETTLED_DIE_HALF_HEIGHT_UNITS * (size.y / _camera.size)


func set_combat_zone_rect(rect: Rect2) -> void:
	if rect.size.x <= 2.0 or rect.size.y <= 2.0:
		return
	set_as_top_level(true)
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	global_position = rect.position
	size = rect.size
	custom_minimum_size = Vector2.ZERO
	_sync_viewport_size()


func reset() -> void:
	_is_rolling = false
	_values_live = false
	_die_by_key.clear()
	_clear_dice()
	# Hide when not rolling so the Roll button underneath is visible
	visible = false


# Scales only the cosmetic container — never the RigidBody3D itself, because
# body scale also scales the collision shape (frozen dice must keep blocking at
# their true size, and Jolt dislikes scaled bodies).
func _set_die_result_scale(die: RigidBody3D, animate: bool) -> void:
	if die == null or not is_instance_valid(die):
		return
	var visuals: Node3D = _die_visuals(die)
	if visuals == null:
		return
	var target_scale := Vector3.ONE * RESULT_SCALE
	if not animate or PixelUI.reduced_motion_enabled():
		visuals.scale = target_scale
		return
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(visuals, "scale", target_scale, RESULT_PRESENTATION_TIME)


func _die_visuals(die: RigidBody3D) -> Node3D:
	return die.get_node_or_null("Visuals") as Node3D


# Cosmetic child nodes (face panels, numerals, overlays) live under "Visuals".
func _die_part(die: RigidBody3D, part_name: String) -> Node:
	var visuals: Node3D = _die_visuals(die)
	if visuals != null:
		return visuals.get_node_or_null(part_name)
	return die.get_node_or_null(part_name)


func get_die_screen_position(side: String, unit_id: String) -> Vector2:
	var die: RigidBody3D = _die_by_key.get(_entry_key(side, unit_id), null) as RigidBody3D
	if die == null or not is_instance_valid(die):
		return Vector2.INF
	if _camera == null or not is_instance_valid(_camera):
		return Vector2.INF
	if _viewport_container == null or not is_instance_valid(_viewport_container):
		return Vector2.INF
	var die_origin: Vector3 = die.global_transform.origin
	if _camera.is_position_behind(die_origin):
		return Vector2.INF
	return _viewport_container.get_global_rect().position + _camera.unproject_position(die_origin)


# The die's diameter projected to screen pixels (same coordinate space as
# get_die_screen_position). Orthographic camera → identical for every die, so result
# tags can share one uniform width. 0.0 if the die/camera aren't ready.
func get_die_projected_diameter(side: String, unit_id: String) -> float:
	var die: RigidBody3D = _die_by_key.get(_entry_key(side, unit_id), null) as RigidBody3D
	if die == null or not is_instance_valid(die):
		return 0.0
	if _camera == null or not is_instance_valid(_camera) or _viewport_container == null or not is_instance_valid(_viewport_container):
		return 0.0
	var origin: Vector3 = die.global_transform.origin
	if _camera.is_position_behind(origin):
		return 0.0
	var right: Vector3 = _camera.global_transform.basis.x.normalized()
	var base: Vector2 = _viewport_container.get_global_rect().position
	var left_edge: Vector2 = base + _camera.unproject_position(origin - right * DIE_RADIUS)
	var right_edge: Vector2 = base + _camera.unproject_position(origin + right * DIE_RADIUS)
	return absf(right_edge.x - left_edge.x)


# The die's exact screen-space bounding rect (projects its 12 vertices at the live
# orientation + settle scale), so result tags can dock flush to the real silhouette
# instead of a uniform circle. Rect2(Vector2.INF, ZERO) if not projectable.
func get_die_screen_bounds(side: String, unit_id: String) -> Rect2:
	var die: RigidBody3D = _die_by_key.get(_entry_key(side, unit_id), null) as RigidBody3D
	if die == null or not is_instance_valid(die):
		return Rect2(Vector2.INF, Vector2.ZERO)
	if _camera == null or not is_instance_valid(_camera) or _viewport_container == null or not is_instance_valid(_viewport_container):
		return Rect2(Vector2.INF, Vector2.ZERO)
	var vis_scale: float = 1.0
	var visuals: Node3D = die.get_node_or_null("Visuals") as Node3D
	if visuals != null:
		vis_scale = visuals.scale.x
	var xform: Transform3D = die.global_transform
	var base: Vector2 = _viewport_container.get_global_rect().position
	var min_p: Vector2 = Vector2(INF, INF)
	var max_p: Vector2 = Vector2(-INF, -INF)
	var found: bool = false
	for vertex in _get_raw_d20_vertices():
		var world_point: Vector3 = xform * (vertex * vis_scale)
		if _camera.is_position_behind(world_point):
			continue
		var screen_point: Vector2 = base + _camera.unproject_position(world_point)
		min_p.x = minf(min_p.x, screen_point.x)
		min_p.y = minf(min_p.y, screen_point.y)
		max_p.x = maxf(max_p.x, screen_point.x)
		max_p.y = maxf(max_p.y, screen_point.y)
		found = true
	if not found:
		return Rect2(Vector2.INF, Vector2.ZERO)
	return Rect2(min_p, max_p - min_p)


func show_result_actions(action_entries: Array) -> void:
	for entry_variant in action_entries:
		var entry: Dictionary = entry_variant
		var key: String = _entry_key(str(entry.get("side", "")), str(entry.get("id", "")))
		var die: RigidBody3D = _die_by_key.get(key, null) as RigidBody3D
		if die == null or not is_instance_valid(die):
			continue
		die.set_meta("zone", str(entry.get("zone", "")))
		# G-32: a moving die shows no value-dependent highlight; the change that
		# moves it re-highlights with this zone once it settles.
		if is_die_moving(str(entry.get("side", "")), str(entry.get("id", ""))):
			continue
		_highlight_top_face(die, int(die.get_meta("shown_value", int(entry.get("roll", 0)))), str(entry.get("side", "")), str(entry.get("zone", "")))


# The value the unit will act on, from the ONE source (value_provider). Falls
# back to the physics face only when no provider is wired (debug harnesses).
func _value_for_die(die: RigidBody3D) -> int:
	var entry: Dictionary = die.get_meta("entry", {})
	if value_provider.is_valid():
		var v: int = int(value_provider.call(str(entry.get("side", "")), str(entry.get("id", ""))))
		if v > 0:
			return clampi(v, 1, 20)
	return int(die.get_meta("raw_result", _get_most_visible_face_value(die)))


# G-24: the natural each die LANDED on is its raw roll, including tutorials.
# battle_scene reads these after roll_finished
# and computes the effective values from them. Frozen dice report their
# crusted value.
func get_hero_rolls() -> Dictionary:
	return _landed_rolls("hero")


func get_enemy_rolls() -> Dictionary:
	return _landed_rolls("enemy")


func _landed_rolls(side: String) -> Dictionary:
	var out: Dictionary = {}
	for key in _die_by_key:
		var die: RigidBody3D = _die_by_key[key] as RigidBody3D
		if die == null or not is_instance_valid(die):
			continue
		var entry: Dictionary = die.get_meta("entry", {})
		if str(entry.get("side", "")) != side:
			continue
		out[str(entry.get("id", ""))] = int(die.get_meta("raw_result", 0))
	return out


# Scripted dice (G-26, one-shot per play_rolls): "side:unit_id" -> scripted raw
# result, set BEFORE play_rolls. A scripted die replays a recorded live throw
# with its mesh oriented before launch, followed by the normal same-face snap.
# The tutorial uses it; so do tests that
# need identical landings across processes.
var _rigged_results: Dictionary = {}


func set_rigged_results(rigged: Dictionary) -> void:
	_rigged_results = rigged.duplicate()


func set_values_live(live: bool) -> void:
	_values_live = live
	if live:
		_poll_values()


# G-32: true from the moment a die starts to move (thrown, rethrown, recorded
# playback, a deliberate tip-over) until it has settled upright in its slot.
# Anything that shows the die's value or ability hides while this is true.
func is_die_moving(side: String, unit_id: String) -> bool:
	var die: RigidBody3D = _get_die_for_entry(side, unit_id)
	return die != null and (bool(die.get_meta("in_motion", false)) or bool(die.get_meta("busy", false)))


# G-32 (TRUTH "Dice rules"): anything showing a die's value or ability — its
# pip tag, its inspect hit-area — is hidden while the die moves and until the
# face it rests on is the value the unit acts on (a rethrown die before its raw
# is committed). The scene checks this every frame before drawing them.
func value_displays_hidden(side: String, unit_id: String) -> bool:
	if is_die_moving(side, unit_id):
		return true
	if not value_provider.is_valid():
		return false
	var shown: int = die_shown_value(side, unit_id)
	var acting: int = int(value_provider.call(side, unit_id))
	return shown > 0 and acting > 0 and shown != acting


# The value the die's up face reads at rest (0 when there is no die).
func die_shown_value(side: String, unit_id: String) -> int:
	var die: RigidBody3D = _get_die_for_entry(side, unit_id)
	return 0 if die == null else int(die.get_meta("shown_value", 0))


# Test/gate surface. A die is LOCKED when it is at rest on its value (not
# tumbling, not mid-change, not mid-reroll).
func is_die_locked(side: String, unit_id: String) -> bool:
	var die: RigidBody3D = _get_die_for_entry(side, unit_id)
	return die != null and not _is_rolling and not bool(die.get_meta("busy", false))


# The numeral a player reads: the text of the face label pointing most nearly
# straight up in the world. Independent of the face tables on purpose — it
# checks what the mesh actually shows. -1 when there is no die.
func up_face_numeral(side: String, unit_id: String) -> int:
	var die: RigidBody3D = _get_die_for_entry(side, unit_id)
	if die == null:
		return -1
	var best: float = -2.0
	var text: String = ""
	for face_value in _face_values:
		var label: Label3D = _die_part(die, "FaceNumber%d" % int(face_value)) as Label3D
		if label == null:
			continue
		var d: float = label.global_transform.basis.z.normalized().dot(Vector3.UP)
		if d > best:
			best = d
			text = label.text
	return int(text) if text.is_valid_int() else -1


func _process(_delta: float) -> void:
	_poll_values()


# Follow game logic: a die whose shown value no longer matches the one source
# moves to a face showing the new value. Also called synchronously by the
# scene right after it changes a value, so the die never reads stale.
func sync_values_now() -> void:
	_poll_values()


func _poll_values() -> void:
	if not _values_live or _is_rolling or not value_provider.is_valid():
		return
	for key in _die_by_key:
		var die: RigidBody3D = _die_by_key[key] as RigidBody3D
		if die == null or not is_instance_valid(die) or bool(die.get_meta("busy", false)):
			continue
		var entry: Dictionary = die.get_meta("entry", {})
		var v: int = int(value_provider.call(str(entry.get("side", "")), str(entry.get("id", ""))))
		# Between rounds the engine deliberately has no revealed value. Falling
		# back to raw_result here could move a modified/frozen die during setup.
		if v <= 0:
			continue
		var plain_reprint: bool = false
		if print_provider.is_valid():
			var plan: Dictionary = print_provider.call(str(entry.get("side", "")), str(entry.get("id", "")))
			plain_reprint = bool(plan.get("plain", false)) and plan.get("faces", []) != die.get_meta("printed_values", [])
		# Set must clear the printed modifiers even when its number is unchanged.
		if v != int(die.get_meta("shown_value", v)) or plain_reprint:
			_show_value_in_place(die, v)


# DELIBERATE change after landing (Nudge, Set, items, Sync Antenna, a live
# hijack copy, a freeze pinning the die): the die tips over onto a face showing
# the new value and settles upright (G-24). When no printed face shows it — or
# on a Set, which makes it a plain 1–20 die (G-25) — the die is reprinted for its
# new state in the same frame the tip starts (G-27); labels are static from then.
func _show_value_in_place(die: RigidBody3D, target: int) -> void:
	die.set_meta("busy", true)
	die.set_meta("in_motion", true)
	var face_index: int = _face_for_change(die, target)
	if face_index < 0:
		push_warning("[DiceTray3D] no face can show %d after a reprint" % target)
		die.set_meta("in_motion", false)
		die.set_meta("busy", false)
		return
	_reset_face_highlights(die)
	await _tip_over(die, face_index)
	if not is_instance_valid(die):
		return
	die.set_meta("shown_value", target)
	die.set_meta("face_up", int(_face_values[face_index]))
	var entry: Dictionary = die.get_meta("entry", {})
	_highlight_top_face(die, target, str(entry.get("side", "")), str(die.get_meta("zone", "")))
	die.set_meta("in_motion", false)
	die.set_meta("busy", false)


# The face a change lands on, reprinting the die first when needed.
func _face_for_change(die: RigidBody3D, target: int) -> int:
	var plan: Dictionary = {}
	if print_provider.is_valid():
		var entry: Dictionary = die.get_meta("entry", {})
		plan = print_provider.call(str(entry.get("side", "")), str(entry.get("id", "")))
	var desired: Array = plan.get("faces", [])
	var must_reprint: bool = bool(plan.get("plain", false)) and desired != (die.get_meta("printed_values", []) as Array)
	var face_index: int = -1 if must_reprint else _face_index_showing(die, target)
	if face_index < 0 and desired.size() == 20:
		die.set_meta("printed_values", desired.duplicate())
		_reset_face_labels(die)
		face_index = _face_index_showing(die, target)
	return face_index


# A short tip-over onto `face_index`, ending flat and upright at the die's slot.
# The shortest rotation (quaternion slerp) with a small lift — a die rocking
# over onto a neighbouring face, not a re-throw.
func _tip_over(die: RigidBody3D, face_index: int) -> void:
	var origin_variant: Variant = die.get_meta("assigned_result_origin", die.global_transform.origin)
	var origin: Vector3 = origin_variant if origin_variant is Vector3 else die.global_transform.origin
	origin.y = die.global_transform.origin.y
	var from_q: Quaternion = die.global_transform.basis.orthonormalized().get_rotation_quaternion()
	var to_basis: Basis = _get_face_forward_result_basis(face_index, die)
	var to_q: Quaternion = to_basis.get_rotation_quaternion()
	var from_origin: Vector3 = die.global_transform.origin
	var elapsed: float = 0.0
	while elapsed < TIP_OVER_TIME:
		var tree: SceneTree = get_tree()
		if _is_exiting_tree or tree == null:
			return
		await tree.process_frame
		if _is_exiting_tree or not is_inside_tree() or not is_instance_valid(die):
			return
		elapsed += get_process_delta_time()
		var t: float = clampf(elapsed / TIP_OVER_TIME, 0.0, 1.0)
		var w: float = _ease_out_cubic(t)
		var lift: float = sin(t * PI) * DIE_RADIUS * 0.45
		die.global_transform = Transform3D(Basis(from_q.slerp(to_q, w)), from_origin.lerp(origin, w) + Vector3.UP * lift)
	if is_instance_valid(die):
		die.global_transform = Transform3D(to_basis, origin)


# The face whose printed label reads `value`, nearest to the face now up (a
# die can print one value on several faces). -1 when no face prints it.
func _face_index_showing(die: RigidBody3D, value: int) -> int:
	var up_normal: Vector3 = die.global_transform.basis.orthonormalized().inverse() * Vector3.UP
	var best: int = -1
	var best_dot: float = -2.0
	for i in range(_face_values.size()):
		var label: Label3D = _die_part(die, "FaceNumber%d" % int(_face_values[i])) as Label3D
		var printed: int = int(label.text) if label != null and label.text.is_valid_int() else int(_face_values[i])
		if printed != value:
			continue
		var d: float = _face_normals[i].dot(up_normal)
		if d > best_dot:
			best_dot = d
			best = i
	return best


func set_die_frozen_visual(side: String, unit_id: String, is_frozen: bool, flavor: String = "ice") -> void:
	var die: RigidBody3D = _get_die_for_entry(side, unit_id)
	if die == null:
		return
	_set_die_frozen_visual(die, is_frozen, flavor)


# pkg8.1 die-status surface: freeze/petrify crust + tint, jam tint + cap
# marker, rewrite/hijack pending markers — all on the die itself, no chips.
func set_die_status(side: String, unit_id: String, status: Dictionary) -> void:
	var die: RigidBody3D = _get_die_for_entry(side, unit_id)
	if die == null:
		return
	_set_die_frozen_visual(die, bool(status.get("frozen", false)), str(status.get("flavor", "ice")))
	_set_die_jam_visual(die, int(status.get("jam_cap", 0)))
	_set_die_pending_marker(die, bool(status.get("rewrite", false)), bool(status.get("hijack", false)))


# Remove ONE unit's die from the tray. Enemies roll at turn start but act AFTER
# the heroes, so a kill during the hero phase leaves a die sitting in the tray
# announcing an action that will never be taken — that face is no longer intent,
# it is stale. The stored RESULT is deliberately left alone: battle_scene's
# hero_rolls / enemy_rolls stay the authority for what was rolled this turn, and
# nothing in the determinism fence reads the tray. No-op when the die is already
# gone.
func clear_die(side: String, unit_id: String) -> void:
	var key: String = _entry_key(side, unit_id)
	var die: RigidBody3D = _die_by_key.get(key, null) as RigidBody3D
	_die_by_key.erase(key)
	if die != null and is_instance_valid(die):
		die.queue_free()


# G-24 reroll: launch one replacement body through the normal physics path.
# The caller clears deliberate modifiers BEFORE this call and commits the
# returned raw value only AFTER it settles. Other dice keep their exact poses.
func reroll_die_to_result(side: String, unit_id: String) -> int:
	var old: RigidBody3D = _get_die_for_entry(side, unit_id)
	if old == null or _is_rolling or bool(old.get_meta("frozen", false)):
		return 0
	_is_rolling = true
	var was_live: bool = _values_live
	_values_live = false
	var entry: Dictionary = (old.get_meta("entry", {}) as Dictionary).duplicate(true)
	entry["frozen"] = false
	if print_provider.is_valid():
		entry["face_values"] = (print_provider.call(side, unit_id) as Dictionary).get("faces", [])
	var origin: Vector3 = old.get_meta("assigned_result_origin", old.position)
	old.free()
	_throw_context = _make_throw_context(side)
	var die: RigidBody3D = _spawn_die(entry, int(entry.get("slot_index", 0)), 1)
	_print_faces(die, entry)
	_make_resting_dice_solid(die)
	_launch_die(die)
	var dice_audio: Variant = get_node_or_null("/root/DiceAudio")
	if dice_audio != null:
		dice_audio.on_roll_started(1)
	await _wait_for_dice_to_settle([die], {die.get_instance_id(): origin})
	if not is_instance_valid(die) or _is_exiting_tree:
		_release_resting_dice()
		return 0
	var raw: int = int(die.get_meta("raw_result", 0))
	await _finish_roll([die])
	_release_resting_dice()
	_values_live = was_live
	return raw


# G-33: every die resting in the tray becomes a frozen STATIC collider on the
# dice layer for the length of a re-throw (see _rethrow_obstacles).
func _make_resting_dice_solid(moving: RigidBody3D) -> void:
	_release_resting_dice()
	for key in _die_by_key:
		var die: RigidBody3D = _die_by_key[key] as RigidBody3D
		if die == null or die == moving or not is_instance_valid(die) or not die.is_inside_tree():
			continue
		var collider: CollisionShape3D = _die_collider(die)
		_rethrow_saved[die.get_instance_id()] = [die.collision_layer, die.collision_mask, die.freeze_mode, collider.shape if collider != null else null]
		if collider != null:
			collider.shape = _rethrow_obstacle_hull()
		die.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		die.freeze = true
		die.linear_velocity = Vector3.ZERO
		die.angular_velocity = Vector3.ZERO
		_set_die_collision_enabled(die, true)
		_rethrow_obstacles.append(die)


func _release_resting_dice() -> void:
	for die_variant in _rethrow_obstacles:
		var die: RigidBody3D = die_variant as RigidBody3D
		if die == null or not is_instance_valid(die):
			continue
		var saved: Array = _rethrow_saved.get(die.get_instance_id(), [])
		if saved.size() == 4:
			die.collision_layer = int(saved[0])
			die.collision_mask = int(saved[1])
			die.freeze_mode = saved[2]
			var collider: CollisionShape3D = _die_collider(die)
			if collider != null and saved[3] != null:
				collider.shape = saved[3]
	_rethrow_obstacles.clear()
	_rethrow_saved.clear()


func _die_collider(die: RigidBody3D) -> CollisionShape3D:
	for child in die.get_children():
		if child is CollisionShape3D:
			return child
	return null


func _rethrow_obstacle_hull() -> ConvexPolygonShape3D:
	if _rethrow_obstacle_shape == null:
		_rethrow_obstacle_shape = ConvexPolygonShape3D.new()
		var points := PackedVector3Array()
		for p in _get_d20_convex_points():
			points.push_back(p * RETHROW_OBSTACLE_SCALE)
		_rethrow_obstacle_shape.points = points
	return _rethrow_obstacle_shape


# G-33: the slide from where a re-thrown die landed to its slot, routed around
# the dice resting in the tray. A die that came to rest against (or between)
# resting dice first steps straight out, without turning, along the shortest
# direction that never brings it closer to any of them, until it is clear by
# RETHROW_SLIDE_CLEARANCE (a sphere bound: once clear, no turn can make two
# d20s touch). From there it slides straight to its slot when that is clear,
# otherwise across the shortest clear horizontal lane (up/down to the lane,
# along it, down/up into the slot), and when no lane is clear it is lifted
# over the row in its way. Returns {"path": waypoints (from first, to
# last), "turn_from": index of the waypoint where the upright turn may start}.
func _plan_rethrow_slide(from: Vector3, to: Vector3) -> Dictionary:
	var centres: Array = []
	for die_variant in _rethrow_obstacles:
		var die: RigidBody3D = die_variant as RigidBody3D
		if die != null and is_instance_valid(die):
			centres.append(die.global_transform.origin)
	var path: Array = [from]
	if centres.is_empty():
		path.append(to)
		return {"path": path, "turn_from": 0}
	var start: Vector3 = _rethrow_escape_point(from, centres)
	var turn_from: int = 0
	if start != from:
		path.append(start)
		turn_from = 1
	var y: float = to.y
	if _segment_clear(start, to, centres):
		path.append(to)
		return {"path": path, "turn_from": turn_from}
	var best: Array = []
	var best_len: float = INF
	var lo: float = _bounds_min_z + DIE_RADIUS
	var hi: float = _bounds_max_z - DIE_RADIUS
	for i in range(RETHROW_LANE_SAMPLES + 1):
		var z: float = lerpf(lo, hi, float(i) / float(RETHROW_LANE_SAMPLES))
		var lane_a := Vector3(start.x, y, z)
		var lane_b := Vector3(to.x, y, z)
		if not (_segment_clear(start, lane_a, centres) and _segment_clear(lane_a, lane_b, centres) and _segment_clear(lane_b, to, centres)):
			continue
		var length: float = start.distance_to(lane_a) + lane_a.distance_to(lane_b) + lane_b.distance_to(to)
		if length < best_len:
			best_len = length
			best = [lane_a, lane_b]
	if best.is_empty():
		# No clear route along the tray floor: a die that landed beyond a full row
		# (the row's gaps are narrower than a die) is lifted clear of the row,
		# carried across above it and set down in its slot. At that height every
		# resting die is at least the clearance below it.
		var lift: float = RETHROW_SLIDE_CLEARANCE
		best = [Vector3(start.x, y + lift, start.z), Vector3(to.x, y + lift, to.z)]
	path.append_array(best)
	path.append(to)
	return {"path": path, "turn_from": turn_from}


# The nearest point, straight out from `start` in the tray plane, clear of every
# resting die by RETHROW_SLIDE_CLEARANCE, reached without ever getting closer to
# any of them and without leaving the tray. `start` itself when already clear.
func _rethrow_escape_point(start: Vector3, centres: Array) -> Vector3:
	var start_d: Array = []
	var clear: bool = true
	for c in centres:
		var d: float = _plane_distance(start, c)
		start_d.append(d)
		if d < RETHROW_SLIDE_CLEARANCE:
			clear = false
	if clear:
		return start
	var edge: float = DIE_RADIUS
	var best: Vector3 = start
	var best_t: float = INF
	for i in range(72):
		var angle: float = TAU * float(i) / 72.0
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var t: float = 0.0
		var ok: bool = true
		var reached: bool = false
		while t < 4.0 and ok and not reached:
			t += 0.02
			var p: Vector3 = start + dir * t
			if absf(p.x) > _bounds_half_width - edge or p.z < _bounds_min_z + edge or p.z > _bounds_max_z - edge:
				ok = false
				break
			reached = true
			for j in range(centres.size()):
				var d: float = _plane_distance(p, centres[j])
				if d < minf(float(start_d[j]), RETHROW_SLIDE_CLEARANCE) - 0.0005:
					ok = false
					break
				if d < RETHROW_SLIDE_CLEARANCE:
					reached = false
		if ok and reached and t < best_t:
			best_t = t
			best = start + dir * t
	return best


func _plane_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# True when no centre is closer than the clearance to the segment a-b (tray plane).
func _segment_clear(a: Vector3, b: Vector3, centres: Array) -> bool:
	var a2 := Vector2(a.x, a.z)
	var b2 := Vector2(b.x, b.z)
	for c_variant in centres:
		var c: Vector3 = c_variant
		var c2 := Vector2(c.x, c.z)
		var ab: Vector2 = b2 - a2
		var t: float = 0.0 if ab.length_squared() < 0.000001 else clampf((c2 - a2).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if (a2 + ab * t).distance_to(c2) < RETHROW_SLIDE_CLEARANCE:
			return false
	return true


# CONTINUE with a pending roll (G-24): the dice appear at rest showing the
# raw values that had landed before the refresh — no throw, so nothing can be
# rerolled. `raws` = {"hero": {id: raw}, "enemy": {id: raw}}. Emits
# roll_finished like a thrown roll.
func place_rolls(hero_entries: Array, enemy_entries: Array, raws: Dictionary) -> void:
	if _is_rolling:
		return
	_is_rolling = true
	visible = true
	_values_live = false
	var all_entries: Array = _collect_roll_entries(hero_entries, enemy_entries)
	var frozen_keys: Array[String] = []
	for entry_variant in all_entries:
		var entry: Dictionary = entry_variant
		if bool(entry.get("frozen", false)) and int(entry.get("frozen_roll", 0)) > 0:
			frozen_keys.append(_entry_key(str(entry.get("side", "")), str(entry.get("id", ""))))
	_clear_dice_except(frozen_keys)
	var dice: Array = []
	for i in range(all_entries.size()):
		var entry: Dictionary = all_entries[i]
		var side: String = str(entry.get("side", ""))
		var die: RigidBody3D
		if bool(entry.get("frozen", false)) and int(entry.get("frozen_roll", 0)) > 0:
			die = _prepare_frozen_die(entry, int(entry.get("slot_index", i)), all_entries.size())
		else:
			die = _spawn_die(entry, int(entry.get("slot_index", i)), all_entries.size())
			_print_faces(die, entry)
			var raw: int = clampi(int((raws.get(side, {}) as Dictionary).get(str(entry.get("id", "")), 1)), 1, 20)
			die.freeze = true
			die.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
			_set_die_collision_enabled(die, false)
			var face_index: int = _get_face_index_for_result(raw)
			die.global_transform = Transform3D(_get_face_forward_result_basis(face_index, die), Vector3(die.position.x, DIE_RADIUS * 0.76, die.position.z))
			die.set_meta("raw_result", raw)
			die.set_meta("face_up", raw)
			var printed_up: Label3D = _die_part(die, "FaceNumber%d" % raw) as Label3D
			die.set_meta("shown_value", int(printed_up.text) if printed_up != null and printed_up.text.is_valid_int() else raw)
		dice.append(die)
	var target_origins: Dictionary = _get_non_overlapping_result_origins(_get_result_entries_for_dice(dice))
	for die_variant in dice:
		var die: RigidBody3D = die_variant as RigidBody3D
		var origin: Vector3 = target_origins.get(die.get_instance_id(), die.global_transform.origin)
		origin.y = die.global_transform.origin.y
		die.global_transform = Transform3D(die.global_transform.basis, origin)
		die.set_meta("assigned_result_origin", origin)
	var tree: SceneTree = get_tree()
	if tree != null:
		await tree.process_frame
	if _is_exiting_tree or not is_inside_tree():
		_is_rolling = false
		return
	await _finish_roll(dice)


func _collect_roll_entries(hero_entries: Array, enemy_entries: Array) -> Array:
	var all_entries: Array = []
	for entry_variant in enemy_entries:
		var entry: Dictionary = entry_variant
		entry["side"] = "enemy"
		entry["slot_index"] = all_entries.size()
		entry["side_count"] = enemy_entries.size()
		all_entries.append(entry)
	for entry_variant in hero_entries:
		var entry: Dictionary = entry_variant
		entry["side"] = "hero"
		entry["slot_index"] = all_entries.size() - enemy_entries.size()
		entry["side_count"] = hero_entries.size()
		all_entries.append(entry)
	return all_entries


func play_rolls(hero_entries: Array, enemy_entries: Array) -> void:
	if _is_rolling:
		return
	_is_rolling = true
	visible = true
	_values_live = false

	var dice: Array = []
	var rolling_dice: Array = []
	var scripted_dice: Array = []
	var all_entries: Array = _collect_roll_entries(hero_entries, enemy_entries)

	var frozen_keys: Array[String] = []
	for entry_variant in all_entries:
		var entry: Dictionary = entry_variant
		if bool(entry.get("frozen", false)) and int(entry.get("frozen_roll", 0)) > 0:
			frozen_keys.append(_entry_key(str(entry.get("side", "")), str(entry.get("id", ""))))
	_clear_dice_except(frozen_keys)

	if all_entries.is_empty():
		await _finish_roll(dice)
		return

	var throw_contexts: Dictionary = {
		"enemy": _make_throw_context("enemy"),
		"hero": _make_throw_context("hero"),
	}
	for i in range(all_entries.size()):
		var entry: Dictionary = all_entries[i]
		var side_slot: int = int(entry.get("slot_index", i))
		_throw_context = throw_contexts.get(str(entry.get("side", "")), {})
		var die: RigidBody3D
		var rig_key: String = _entry_key(str(entry.get("side", "")), str(entry.get("id", "")))
		if bool(entry.get("frozen", false)) and int(entry.get("frozen_roll", 0)) > 0:
			die = _prepare_frozen_die(entry, side_slot, all_entries.size())
		elif _rigged_results.has(rig_key):
			die = _spawn_die(entry, side_slot, all_entries.size())
			_print_faces(die, entry)
			die.freeze = true
			_set_die_collision_enabled(die, false)
			die.set_meta("scripted_request", clampi(int(_rigged_results[rig_key]), 1, 20))
			scripted_dice.append(die)
		else:
			die = _spawn_die(entry, side_slot, all_entries.size())
			_print_faces(die, entry)
			_launch_die(die)
			rolling_dice.append(die)
		dice.append(die)

	if not dice.is_empty():
		var dice_audio: Variant = get_node_or_null("/root/DiceAudio")
		if dice_audio != null:
			dice_audio.on_roll_started(dice.size())

	var target_origins: Dictionary = _get_non_overlapping_result_origins(_get_result_entries_for_dice(dice))
	_assign_frozen_die_origins(dice, target_origins)
	var recording_variant: int = _pick_recording_variant(scripted_dice, enemy_entries.size())
	if recording_variant < 0:
		# G-31: no recorded variant stays inside THIS tray once mapped. Never
		# play one that leaves the view; throw these dice for real instead.
		push_warning("[DiceTray3D] no recorded throw fits a %.2f x %.2f tray; throwing live" % [_bounds_half_width * 2.0, _bounds_max_z - _bounds_min_z])
		for scripted_variant in scripted_dice:
			var scripted: RigidBody3D = scripted_variant as RigidBody3D
			scripted.remove_meta("scripted_request")
			scripted.freeze = false
			_set_die_collision_enabled(scripted, true)
			_throw_context = throw_contexts.get(str((scripted.get_meta("entry", {}) as Dictionary).get("side", "")), {})
			_launch_die(scripted)
			rolling_dice.append(scripted)
		scripted_dice.clear()
	for scripted_variant in scripted_dice:
		var scripted: RigidBody3D = scripted_variant as RigidBody3D
		_play_recorded_throw(scripted, target_origins.get(scripted.get_instance_id(), scripted.global_transform.origin), enemy_entries.size(), recording_variant)
	await _wait_for_dice_to_settle(rolling_dice, target_origins)
	# Recorded throws run for their measured live duration.
	for scripted_variant in scripted_dice:
		var scripted: RigidBody3D = scripted_variant as RigidBody3D
		while is_instance_valid(scripted) and bool(scripted.get_meta("busy", false)):
			var tree: SceneTree = get_tree()
			if _is_exiting_tree or tree == null:
				return
			await tree.process_frame
	if _is_exiting_tree or not is_inside_tree():
		_is_rolling = false
		return
	await _finish_roll(dice)


func _finish_roll(dice: Array) -> void:
	var result_entries: Array = []
	for die_variant in dice:
		var die: RigidBody3D = die_variant as RigidBody3D
		if die == null or not is_instance_valid(die):
			continue
		var display: int = int(die.get_meta("shown_value", _get_most_visible_face_value(die)))
		var entry: Dictionary = die.get_meta("entry", {})
		var side: String = str(entry.get("side", ""))
		_set_die_frozen_visual(die, bool(entry.get("frozen", false)))
		die.freeze = true
		die.linear_velocity = Vector3.ZERO
		die.angular_velocity = Vector3.ZERO
		_set_die_collision_enabled(die, false)
		_set_die_result_scale(die, true)
		result_entries.append({
			"die": die,
			"result": display,
			"side": side,
			"entry": entry,
		})

	for result_entry_variant in result_entries:
		var result_entry: Dictionary = result_entry_variant
		var die: RigidBody3D = result_entry.get("die", null) as RigidBody3D
		if die == null or not is_instance_valid(die):
			continue
		_highlight_top_face(die, int(result_entry.get("result", 1)), str(result_entry.get("side", "")))

	var tree: SceneTree = get_tree()
	if _is_exiting_tree or tree == null:
		_is_rolling = false
		return
	await tree.create_timer(RESULT_PRESENTATION_TIME).timeout
	if _is_exiting_tree or not is_inside_tree():
		_is_rolling = false
		return
	_enforce_assigned_result_origins(result_entries)
	for result_entry_variant in result_entries:
		var settled: RigidBody3D = (result_entry_variant as Dictionary).get("die", null) as RigidBody3D
		if settled != null and is_instance_valid(settled):
			settled.set_meta("in_motion", false)

	_is_rolling = false
	_rigged_results.clear()
	var dice_audio: Variant = get_node_or_null("/root/DiceAudio")
	if _landscape_projection:
		_refresh_landscape_result_positions()
	if dice_audio != null:
		dice_audio.on_roll_finished()
	# Stay visible so the player can read the results; reset() hides later
	roll_finished.emit()


# G-24 upright snap: the settled die turns the least it must to lay its landed
# face flat with the numeral reading upright, while it slides to its slot
# under its unit. It keeps the same top face — this never rolls it over.
func _start_upright_snap(die: RigidBody3D, face_index: int, target_origin: Vector3, slide: Dictionary = {}) -> void:
	if _is_exiting_tree or not is_inside_tree() or face_index < 0:
		return
	var from_transform: Transform3D = die.global_transform
	var to_transform: Transform3D = Transform3D(_get_face_forward_result_basis(face_index, die), target_origin)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	var path: Array = slide.get("path", [])
	if path.size() > 2:
		# G-33 routed slide: the origin follows the path; the turn to upright
		# waits until the die has stepped clear of the dice it rested against.
		var turn_start: float = _path_fraction(path, int(slide.get("turn_from", 0)))
		tween.tween_method(
			func(weight: float) -> void:
				if is_instance_valid(die):
					var turn_w: float = 0.0 if weight <= turn_start else (weight - turn_start) / maxf(1.0 - turn_start, 0.0001)
					var turned: Transform3D = from_transform.interpolate_with(to_transform, turn_w)
					die.global_transform = Transform3D(turned.basis, _point_along(path, weight))
		, 0.0, 1.0, RESULT_PRESENTATION_TIME)
		return
	tween.tween_method(
		func(weight: float) -> void:
			if is_instance_valid(die):
				die.global_transform = from_transform.interpolate_with(to_transform, weight)
	, 0.0, 1.0, RESULT_PRESENTATION_TIME)


# How far along the polyline (0..1, by length) waypoint `index` sits.
func _path_fraction(path: Array, index: int) -> float:
	var total: float = 0.0
	var upto: float = 0.0
	for i in range(1, path.size()):
		var leg: float = (path[i - 1] as Vector3).distance_to(path[i] as Vector3)
		total += leg
		if i <= index:
			upto += leg
	return 0.0 if total <= 0.0 else upto / total


# The point `weight` (0..1) of the way along a polyline, by length.
func _point_along(path: Array, weight: float) -> Vector3:
	var total: float = 0.0
	for i in range(1, path.size()):
		total += (path[i - 1] as Vector3).distance_to(path[i] as Vector3)
	if total <= 0.0:
		return path[path.size() - 1]
	var remaining: float = clampf(weight, 0.0, 1.0) * total
	for i in range(1, path.size()):
		var a: Vector3 = path[i - 1]
		var b: Vector3 = path[i]
		var leg: float = a.distance_to(b)
		if remaining <= leg:
			return a.lerp(b, 0.0 if leg <= 0.0 else remaining / leg)
		remaining -= leg
	return path[path.size() - 1]


func _enforce_assigned_result_origins(result_entries: Array) -> void:
	for result_entry_variant in result_entries:
		var result_entry: Dictionary = result_entry_variant
		var die: RigidBody3D = result_entry.get("die", null) as RigidBody3D
		if die == null or not is_instance_valid(die):
			continue
		var assigned_origin_variant: Variant = die.get_meta("assigned_result_origin", null)
		if assigned_origin_variant == null or not (assigned_origin_variant is Vector3):
			continue
		var assigned_origin: Vector3 = assigned_origin_variant
		assigned_origin.y = die.global_transform.origin.y
		die.global_transform = Transform3D(die.global_transform.basis, assigned_origin)


func _assign_frozen_die_origins(dice: Array, target_origins: Dictionary) -> void:
	for die_variant in dice:
		var die: RigidBody3D = die_variant as RigidBody3D
		if die == null or not is_instance_valid(die):
			continue
		var entry: Dictionary = die.get_meta("entry", {})
		if not bool(entry.get("frozen", false)):
			continue
		var target_origin: Vector3 = target_origins.get(die.get_instance_id(), die.global_transform.origin)
		target_origin.y = die.global_transform.origin.y
		die.set_meta("assigned_result_origin", target_origin)


func _get_non_overlapping_result_origins(result_entries: Array) -> Dictionary:
	var origins: Dictionary = {}
	var valid_entries: Array = []
	for result_entry_variant in result_entries:
		var result_entry: Dictionary = result_entry_variant
		var die: RigidBody3D = result_entry.get("die", null) as RigidBody3D
		if die == null or not is_instance_valid(die):
			continue
		valid_entries.append(result_entry)
		var side: String = _get_result_entry_side(result_entry)
		origins[die.get_instance_id()] = _clamp_result_origin(_get_unit_slot_origin(result_entry, die.global_transform.origin), side)

	for _iteration in range(RESULT_LAYOUT_ITERATIONS):
		for i in range(valid_entries.size()):
			var result_entry_a: Dictionary = valid_entries[i] as Dictionary
			var die_a: RigidBody3D = result_entry_a.get("die", null) as RigidBody3D
			if die_a == null or not is_instance_valid(die_a):
				continue
			var id_a: int = die_a.get_instance_id()
			for j in range(i + 1, valid_entries.size()):
				var result_entry_b: Dictionary = valid_entries[j] as Dictionary
				var die_b: RigidBody3D = result_entry_b.get("die", null) as RigidBody3D
				if die_b == null or not is_instance_valid(die_b):
					continue
				var id_b: int = die_b.get_instance_id()
				var origin_a: Vector3 = origins[id_a]
				var origin_b: Vector3 = origins[id_b]
				var delta: Vector3 = Vector3(origin_b.x - origin_a.x, 0.0, origin_b.z - origin_a.z)
				var distance: float = delta.length()
				if distance >= RESULT_MIN_SEPARATION:
					continue
				var direction: Vector3
				if distance < 0.001:
					var angle: float = (TAU / float(maxi(valid_entries.size(), 1))) * float(j)
					direction = Vector3(cos(angle), 0.0, sin(angle)).normalized()
				else:
					direction = delta / distance
				var push: Vector3 = direction * ((RESULT_MIN_SEPARATION - distance) * 0.5)
				origins[id_a] = _clamp_result_origin(origin_a - push, _get_result_entry_side(result_entry_a))
				origins[id_b] = _clamp_result_origin(origin_b + push, _get_result_entry_side(result_entry_b))
	return origins


func _clamp_result_origin(origin: Vector3, side: String = "") -> Vector3:
	if _landscape_projection:
		origin.x = clampf(origin.x, -_bounds_half_width + DIE_RADIUS, _bounds_half_width - DIE_RADIUS)
		origin.z = clampf(origin.z, _bounds_min_z + DIE_RADIUS, _bounds_max_z - DIE_RADIUS)
		return origin
	var outer_min_x: float = -TRAY_HALF_WIDTH + RESULT_OUTER_MARGIN - RESULT_SIDE_OVERFLOW
	var outer_max_x: float = TRAY_HALF_WIDTH - RESULT_OUTER_MARGIN + RESULT_SIDE_OVERFLOW
	var front_overflow: float = RESULT_HERO_BOTTOM_OVERFLOW if side == "hero" else RESULT_ENEMY_BOTTOM_OVERFLOW
	origin.x = clampf(origin.x, outer_min_x, outer_max_x)
	origin.z = clampf(origin.z, -TRAY_HALF_DEPTH + RESULT_TOP_CLEARANCE, TRAY_HALF_DEPTH - RESULT_OUTER_MARGIN + front_overflow)
	# G-31: a settled die never rests partly outside the visible tray, whatever
	# the tray's live size (the constants above describe the shipped layout).
	var settled_radius: float = DIE_RADIUS * RESULT_SCALE
	origin.x = clampf(origin.x, -_bounds_half_width + settled_radius, _bounds_half_width - settled_radius)
	origin.z = clampf(origin.z, _bounds_min_z + settled_radius, _bounds_max_z - settled_radius)
	return origin


func _get_unit_slot_origin(result_entry: Dictionary, fallback_origin: Vector3) -> Vector3:
	var entry: Dictionary = result_entry.get("entry", {}) as Dictionary
	var side: String = _get_result_entry_side(result_entry)
	if result_anchor_provider.is_valid():
		var live_anchor: Vector2 = result_anchor_provider.call(side, str(entry.get("id", "")))
		if live_anchor != Vector2.INF:
			return _clamp_result_origin(_anchor_to_world_origin(live_anchor, fallback_origin), side)
	if entry.has("result_anchor"):
		var anchor_variant: Variant = entry.get("result_anchor")
		if anchor_variant is Vector2:
			var anchor_point: Vector2 = anchor_variant
			var origin: Vector3 = _anchor_to_world_origin(anchor_point, fallback_origin)
			var side_offset_px: float = float(entry.get("result_anchor_side_offset_px", 0.0))
			if not is_zero_approx(side_offset_px):
				var offset_origin: Vector3 = _anchor_to_world_origin(anchor_point + Vector2(side_offset_px, 0.0), fallback_origin)
				origin.x += offset_origin.x - origin.x
			return _clamp_result_origin(origin, side)
	var slot_index: int = int(entry.get("slot_index", 0))
	var side_count: int = maxi(int(entry.get("side_count", 1)), 1)
	var usable_width: float = (TRAY_HALF_WIDTH - RESULT_OUTER_MARGIN) * 2.0
	var x_gap: float = 0.0
	if side_count > 1:
		x_gap = minf(RESULT_SLOT_X_GAP, usable_width / float(side_count - 1))
	var col_offset: float = (float(slot_index) - (float(side_count) - 1.0) * 0.5) * x_gap
	var side_nudge: float = -RESULT_HERO_SIDE_NUDGE if side == "hero" else RESULT_ENEMY_SIDE_NUDGE
	var row_z: float = RESULT_HERO_ROW_Z + RESULT_HERO_DOWN_NUDGE if side == "hero" else -RESULT_ENEMY_ROW_Z - RESULT_ENEMY_DOWN_NUDGE
	return _clamp_result_origin(Vector3(col_offset + side_nudge, fallback_origin.y, row_z), side)


func _anchor_to_world_origin(anchor_point: Vector2, fallback_origin: Vector3) -> Vector3:
	if _camera == null or not is_instance_valid(_camera):
		return fallback_origin
	var ray_origin: Vector3 = _camera.project_ray_origin(anchor_point)
	var ray_dir: Vector3 = _camera.project_ray_normal(anchor_point)
	if absf(ray_dir.y) < 0.0001:
		return fallback_origin
	var t: float = (0.0 - ray_origin.y) / ray_dir.y
	var world_point: Vector3 = ray_origin + ray_dir * t
	return Vector3(world_point.x, fallback_origin.y, world_point.z)


func _get_result_entry_side(result_entry: Dictionary) -> String:
	var entry: Dictionary = result_entry.get("entry", {}) as Dictionary
	return str(entry.get("side", result_entry.get("side", "")))


func _get_result_entries_for_dice(dice: Array) -> Array:
	var result_entries: Array = []
	for die_variant in dice:
		var die: RigidBody3D = die_variant as RigidBody3D
		if die == null or not is_instance_valid(die):
			continue
		var entry: Dictionary = die.get_meta("entry", {})
		var side: String = str(entry.get("side", ""))
		result_entries.append({
			"die": die,
			"result": int(die.get_meta("shown_value", 1)),
			"side": side,
			"entry": entry,
		})
	return result_entries


func _get_face_index_for_result(result: int) -> int:
	for i in range(_face_values.size()):
		if int(_face_values[i]) == result:
			return i
	return -1


func _get_face_forward_result_basis(face_index: int, die: Node3D = null) -> Basis:
	var local_face_basis: Basis = _face_text_bases[face_index] if face_index < _face_text_bases.size() else _basis_for_face_surface(_face_normals[face_index])
	var target_normal: Vector3 = RESULT_FACE_NORMAL.normalized()
	var target_text_up: Vector3 = RESULT_FACE_TEXT_UP - target_normal * RESULT_FACE_TEXT_UP.dot(target_normal)
	if target_text_up.length_squared() < 0.00001:
		target_text_up = Vector3.FORWARD - target_normal * Vector3.FORWARD.dot(target_normal)
	target_text_up = target_text_up.normalized()
	var target_text_right: Vector3 = target_text_up.cross(target_normal).normalized()
	var target_face_basis: Basis = Basis(target_text_right, target_text_up, target_normal).orthonormalized()
	var aligned: Basis = (target_face_basis * local_face_basis.inverse()).orthonormalized()
	if die != null:
		aligned = aligned * (die.get_node("Visuals") as Node3D).basis.orthonormalized().inverse()
	return aligned


# `result` is the value the die shows (drives the 20 styling); the panel lit is
# the physical face that is up (`face_up`), since several faces can print one
# value once modifiers are printed on the die.
func _highlight_top_face(die: RigidBody3D, result: int, side: String, zone: String = "") -> void:
	var face: int = int(die.get_meta("face_up", result))
	var panel: MeshInstance3D = _die_part(die, "FacePanel%d" % face) as MeshInstance3D
	if panel == null:
		return
	var zone_key: String = zone.strip_edges().to_lower()
	var is_crit: bool = zone_key == "" and side == "hero" and result == 20
	var hl_key: String = "hl:%s:%s:%s" % [zone_key, side, "crit" if is_crit else "std"]
	panel.material_override = _bank_material(hl_key, func() -> StandardMaterial3D:
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		mat.render_priority = 1
		if zone_key != "":
			var zone_style: Dictionary = _get_zone_face_style(zone_key)
			mat.albedo_color = zone_style["face"]
			mat.emission = zone_style["emission"]
			mat.emission_energy_multiplier = float(zone_style["energy"])
		elif is_crit:
			mat.albedo_color = Color(0.46, 0.26, 0.03, 1.0)
			mat.emission = Color(1.0, 0.58, 0.10, 1.0)
			mat.emission_energy_multiplier = 1.2
		elif side == "hero":
			mat.albedo_color = Color(0.06, 0.14, 0.32, 1.0)
			mat.emission = Color(0.04, 0.10, 0.25, 1.0)
			mat.emission_energy_multiplier = 0.8
		else:
			mat.albedo_color = Color(0.30, 0.06, 0.05, 1.0)
			mat.emission = Color(0.20, 0.04, 0.03, 1.0)
			mat.emission_energy_multiplier = 0.8
		mat.emission_enabled = true
		mat.roughness = 0.80
		return mat)
	# Result face gets a thin light outline: recolor its bevel rim bright (instead of
	# hiding it) so a crisp light ring frames the winning face.
	var result_bevel: MeshInstance3D = _die_part(die, "FaceBevel%d" % face) as MeshInstance3D
	if result_bevel != null:
		result_bevel.material_override = _bank_material("outline:%s" % side, func() -> StandardMaterial3D:
			var outline_color: Color = (PixelUI.DT_HERO_DITHER if side == "hero" else PixelUI.DT_ENEMY_DITHER).lightened(0.45)
			var outline_mat: StandardMaterial3D = StandardMaterial3D.new()
			outline_mat.albedo_color = outline_color
			outline_mat.emission_enabled = true
			outline_mat.emission = outline_color
			outline_mat.emission_energy_multiplier = 1.5
			outline_mat.render_priority = 2
			return outline_mat)
		result_bevel.visible = true
	# Dim every non-result face (panel + bevel) to ~40% brightness so only the result reads bright.
	var base_color: Color = _die_base_color(die)
	var dim_face: Color = _face_color_for(base_color).darkened(0.6)
	var dim_mat: StandardMaterial3D = _bank_material("dim:%s" % base_color.to_html(false), func() -> StandardMaterial3D:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = dim_face
		m.emission_enabled = true
		m.emission = dim_face.darkened(0.5)
		m.emission_energy_multiplier = 0.15
		return m)
	for face_value in _face_values:
		var fv: int = int(face_value)
		if fv == face:
			continue
		for part_prefix in ["FacePanel", "FaceBevel"]:
			var mesh: MeshInstance3D = _die_part(die, "%s%d" % [part_prefix, fv]) as MeshInstance3D
			if mesh == null:
				continue
			mesh.material_override = dim_mat
	# Fade the non-result numerals; keep each engrave colour, only adjust alpha (all layers).
	for face_value2 in _face_values:
		var fv2: int = int(face_value2)
		var alpha: float = 1.0 if fv2 == face else 0.4
		for prefix in ["FaceNumber", "FaceNumberShadow", "FaceNumberHighlight", "FaceNumberWell"]:
			var label: Label3D = _die_part(die, "%s%d" % [prefix, fv2]) as Label3D
			if label == null:
				continue
			var c: Color = label.modulate
			c.a = alpha
			label.modulate = c


func _get_zone_face_style(zone_key: String) -> Dictionary:
	match zone_key:
		"recharge":
			return {
				"face": Color(0.06, 0.06, 0.08, 1.0),
				"emission": Color(0.03, 0.03, 0.04, 1.0),
				"energy": 0.3,
			}
		"strike":
			return {
				"face": Color(0.15, 0.15, 0.18, 1.0),
				"emission": Color(0.08, 0.08, 0.10, 1.0),
				"energy": 0.5,
			}
		"surge":
			return {
				"face": Color(0.25, 0.18, 0.04, 1.0),
				"emission": Color(0.6, 0.4, 0.05, 1.0),
				"energy": 0.8,
			}
		"crit", "critical":
			return {
				"face": Color(0.3, 0.12, 0.02, 1.0),
				"emission": Color(0.8, 0.35, 0.05, 1.0),
				"energy": 1.2,
			}
		"overload":
			return {
				"face": Color(0.15, 0.3, 0.35, 1.0),
				"emission": Color(0.1, 0.8, 0.9, 1.0),
				"energy": 2.0,
			}
	return {
		"face": Color(0.06, 0.14, 0.32, 1.0),
		"emission": Color(0.04, 0.10, 0.25, 1.0),
		"energy": 0.8,
	}


func _reset_face_highlights(die: RigidBody3D) -> void:
	var face_mat: StandardMaterial3D = _face_panel_material_for(die)
	for face_value in _face_values:
		var panel: MeshInstance3D = _die_part(die, "FacePanel%d" % int(face_value)) as MeshInstance3D
		if panel != null:
			panel.material_override = face_mat
		var bevel: MeshInstance3D = _die_part(die, "FaceBevel%d" % int(face_value)) as MeshInstance3D
		if bevel != null:
			bevel.visible = true


# Restores each face's PRINTED number (G-24: the value printed before the throw;
# its natural number when nothing was printed).
func _reset_face_labels(die: RigidBody3D) -> void:
	var base: Color = _die_base_color(die)
	var printed: Array = die.get_meta("printed_values", [])
	for face_value in _face_values:
		var fv: int = int(face_value)
		var shown: int = int(printed[fv - 1]) if printed.size() == 20 else fv
		_apply_face_number(die, fv, shown, base)


# G-24: print the entry's face values on a fresh die, once, before it is thrown
# or placed. They never change afterwards.
func _print_faces(die: RigidBody3D, entry: Dictionary) -> void:
	var printed: Variant = entry.get("face_values", [])
	if not (printed is Array) or (printed as Array).size() != 20:
		return
	die.set_meta("printed_values", (printed as Array).duplicate())
	_reset_face_labels(die)


# Set the engraved numeral (all four stacked labels) on one face, restoring their engrave colours.
func _apply_face_number(die: RigidBody3D, face_value: int, display_value: int, base: Color) -> void:
	var value_text: String = "%d" % clampi(display_value, 1, 20)
	var font_size: int = 128 if value_text.length() == 1 else 108
	_set_label(die, "FaceNumberWell%d" % face_value, value_text, font_size + 14, _number_well_color_for(base))
	_set_label(die, "FaceNumberShadow%d" % face_value, value_text, font_size, _number_shadow_color_for(base))
	_set_label(die, "FaceNumberHighlight%d" % face_value, value_text, font_size, _number_highlight_color_for(base))
	_set_label(die, "FaceNumber%d" % face_value, value_text, font_size, _number_main_color_for(base))


func _set_label(die: RigidBody3D, node_name: String, value_text: String, font_size: int, color: Color) -> void:
	var label: Label3D = _die_part(die, node_name) as Label3D
	if label == null:
		return
	label.text = value_text
	label.font_size = font_size
	label.modulate = color


func _get_die_for_entry(side: String, unit_id: String) -> RigidBody3D:
	var die: RigidBody3D = _die_by_key.get(_entry_key(side, unit_id), null) as RigidBody3D
	if die == null or not is_instance_valid(die):
		return null
	return die


func _ease_out_cubic(t: float) -> float:
	var inv: float = 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - inv * inv * inv


func _wait_for_dice_to_settle(dice: Array, target_origins: Dictionary) -> void:
	var elapsed: float = 0.0
	var settled_times: Dictionary = {}
	var all_ready: bool = false
	while elapsed < MAX_ROLL_TIME:
		var tree: SceneTree = get_tree()
		if _is_exiting_tree or tree == null:
			return
		await tree.physics_frame
		if _is_exiting_tree or not is_inside_tree():
			return
		var delta: float = get_physics_process_delta_time()
		elapsed += delta
		for die_variant in dice:
			var active_die: RigidBody3D = die_variant as RigidBody3D
			if active_die == null or not is_instance_valid(active_die):
				continue
			if bool(active_die.freeze):
				continue
			_apply_late_settle_damping(active_die, elapsed)
		all_ready = true
		for die_variant in dice:
			var die: RigidBody3D = die_variant as RigidBody3D
			if die == null or not is_instance_valid(die):
				continue
			if elapsed < FACE_RESOLVE_MIN_TIME:
				all_ready = false
				continue
			var die_id: int = die.get_instance_id()
			var prev_settled: float = float(settled_times.get(die_id, 0.0))
			if die.sleeping:
				settled_times[die_id] = SETTLE_REQUIRED_TIME
			elif _is_die_ready_for_face_resolve(die):
				settled_times[die_id] = prev_settled + delta
			else:
				settled_times[die_id] = 0.0
			var now_settled: float = float(settled_times.get(die_id, 0.0))
			# Settle tick fires on the upward crossing — once per come-to-rest.
			# A die that gets bumped resets to 0 and ticks again when it re-lands,
			# which is the physical read.
			if prev_settled < SETTLE_REQUIRED_TIME and now_settled >= SETTLE_REQUIRED_TIME:
				var dice_audio: Variant = get_node_or_null("/root/DiceAudio")
				if dice_audio != null:
					dice_audio.on_die_settled(die_id)
			if now_settled < SETTLE_REQUIRED_TIME:
				all_ready = false
		if all_ready:
			break

	for die_variant in dice:
		var die: RigidBody3D = die_variant as RigidBody3D
		if die == null or not is_instance_valid(die):
			continue
		die.sleeping = true
		die.freeze = true
		die.linear_velocity = Vector3.ZERO
		die.angular_velocity = Vector3.ZERO

	var settle_tree: SceneTree = get_tree()
	if _is_exiting_tree or settle_tree == null:
		return
	await settle_tree.create_timer(RESULT_SNAP_DELAY).timeout
	if _is_exiting_tree or not is_inside_tree():
		return
	for die_variant in dice:
		var die: RigidBody3D = die_variant as RigidBody3D
		if die == null or not is_instance_valid(die):
			continue
		_resolve_landed_die_face(die, target_origins.get(die.get_instance_id(), die.global_transform.origin))


func _is_die_ready_for_face_resolve(die: RigidBody3D) -> bool:
	return die.linear_velocity.length() <= FACE_RESOLVE_LINEAR_SPEED and die.angular_velocity.length() <= FACE_RESOLVE_ANGULAR_SPEED


func _resolve_landed_die_face(die: RigidBody3D, target_origin: Vector3) -> void:
	die.freeze = true
	die.linear_velocity = Vector3.ZERO
	die.angular_velocity = Vector3.ZERO
	_set_die_collision_enabled(die, false)
	# G-24: the landed face is the raw roll, and it is the face that turns up.
	var face_up: int = _get_most_visible_face_value(die)
	die.set_meta("raw_result", face_up)
	die.set_meta("face_up", face_up)
	var printed: Label3D = _die_part(die, "FaceNumber%d" % face_up) as Label3D
	die.set_meta("shown_value", int(printed.text) if printed != null and printed.text.is_valid_int() else face_up)
	target_origin.y = die.global_transform.origin.y
	var slide: Dictionary = {}
	if not _rethrow_obstacles.is_empty():
		# A re-thrown die rests at the same height as the dice already in the
		# tray (it may have come to rest leaning on one), and slides around them.
		var rest: RigidBody3D = _rethrow_obstacles[0] as RigidBody3D
		if rest != null and is_instance_valid(rest):
			target_origin.y = rest.global_transform.origin.y
		slide = _plan_rethrow_slide(die.global_transform.origin, target_origin)
	die.set_meta("assigned_result_origin", target_origin)
	_start_upright_snap(die, _get_face_index_for_result(face_up), target_origin, slide)


# Late in the roll the "felt" grabs: damping ramps up so a die spiralling on a
# vertex winds down naturally instead of spinning until the timeout freeze.
func _apply_late_settle_damping(die: RigidBody3D, elapsed: float) -> void:
	if elapsed <= LATE_SETTLE_DAMP_START:
		return
	var t: float = clampf((elapsed - LATE_SETTLE_DAMP_START) / LATE_SETTLE_DAMP_RAMP, 0.0, 1.0)
	die.linear_damp = t * 1.6
	die.angular_damp = 0.12 + t * 2.2


# ── UI CONSTRUCTION ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_viewport_container = SubViewportContainer.new()
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport_container.stretch = false
	_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_viewport_container)

	_viewport = SubViewport.new()
	# Transparent so the game UI shows through around/behind the dice
	_viewport.transparent_bg = true
	# Only render while the tray is actually on screen — reset() hides the tray
	# between rolls, and UPDATE_ALWAYS would keep paying a full 3D pass anyway.
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	_viewport.gui_disable_input = true
	_viewport.world_3d = World3D.new()
	_viewport_container.add_child(_viewport)


func _build_world() -> void:
	_world_root = Node3D.new()
	_viewport.add_child(_world_root)

	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.345
	camera.position = Vector3(0, 6.8, 0.635)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	camera.near = 0.05
	camera.far = 20.0
	_world_root.add_child(camera)
	_camera = camera
	_viewport.world_3d.environment = _build_environment()

	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-52, 38, 0)
	key_light.light_energy = 3.0
	_world_root.add_child(key_light)

	var fill_light: OmniLight3D = OmniLight3D.new()
	fill_light.position = Vector3(-2.5, 3.5, 2.0)
	fill_light.light_color = Color(0.45, 0.72, 1.0, 1.0)
	fill_light.light_energy = 2.0
	fill_light.omni_range = 12.0
	_world_root.add_child(fill_light)

	_build_tray_body()
	_dice_root = Node3D.new()
	_world_root.add_child(_dice_root)


func _build_environment() -> Environment:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	# Transparent background — only the floor plane and dice are visible
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.20, 0.34, 0.52, 1.0)
	environment.ambient_light_energy = 1.0
	return environment


func _build_tray_body() -> void:
	for wall_name in ["Floor", "BackWall", "FrontWall", "LeftWall", "RightWall", "Ceiling"]:
		_tray_bodies[wall_name] = _add_static_box(wall_name)
	_layout_tray_bodies()


func _layout_tray_bodies() -> void:
	if _tray_bodies.is_empty():
		return
	var center_z: float = (_bounds_min_z + _bounds_max_z) * 0.5
	var depth: float = _bounds_max_z - _bounds_min_z
	var width: float = _bounds_half_width * 2.0
	var t: float = COLLISION_WALL_THICKNESS
	# Floor and ceiling overhang the walls so nothing escapes through corners.
	_place_static_box("Floor", Vector3(0, -t * 0.5, center_z), Vector3(width + t * 4.0, t, depth + t * 4.0))
	_place_static_box("Ceiling", Vector3(0, COLLISION_WALL_HEIGHT + t * 0.5, center_z), Vector3(width + t * 4.0, t, depth + t * 4.0))
	# Each wall's bottom-inner edge sits exactly on the visible bound, with the
	# top leaning inward (sloped tray rim) so dice can't rest tilted against it.
	_place_leaning_wall("BackWall", Vector3(0, 0, _bounds_min_z), Vector3(0, 0, 1), Vector3(width + t * 4.0, COLLISION_WALL_HEIGHT, t))
	_place_leaning_wall("FrontWall", Vector3(0, 0, _bounds_max_z), Vector3(0, 0, -1), Vector3(width + t * 4.0, COLLISION_WALL_HEIGHT, t))
	_place_leaning_wall("LeftWall", Vector3(-_bounds_half_width, 0, center_z), Vector3(1, 0, 0), Vector3(t, COLLISION_WALL_HEIGHT, depth + t * 4.0))
	_place_leaning_wall("RightWall", Vector3(_bounds_half_width, 0, center_z), Vector3(-1, 0, 0), Vector3(t, COLLISION_WALL_HEIGHT, depth + t * 4.0))


func _place_static_box(node_name: String, pos: Vector3, box_size: Vector3) -> void:
	var body: StaticBody3D = _tray_bodies.get(node_name, null) as StaticBody3D
	if body == null or not is_instance_valid(body):
		return
	body.transform = Transform3D(Basis.IDENTITY, pos)
	var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
	if shape != null and shape.shape is BoxShape3D:
		(shape.shape as BoxShape3D).size = box_size


# `pivot` is the wall's bottom-inner edge on the floor; `inner_normal` points
# into the tray. The wall is rotated about that edge by WALL_LEAN_RADIANS so
# its top edge overhangs the play field slightly.
func _place_leaning_wall(node_name: String, pivot: Vector3, inner_normal: Vector3, box_size: Vector3) -> void:
	var body: StaticBody3D = _tray_bodies.get(node_name, null) as StaticBody3D
	if body == null or not is_instance_valid(body):
		return
	var axis: Vector3 = inner_normal.cross(Vector3.UP).normalized()
	var lean_basis: Basis = Basis(axis, -WALL_LEAN_RADIANS)
	var local_center: Vector3 = Vector3.UP * (box_size.y * 0.5) - inner_normal * (COLLISION_WALL_THICKNESS * 0.5)
	body.transform = Transform3D(lean_basis, pivot + lean_basis * local_center)
	var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
	if shape != null and shape.shape is BoxShape3D:
		(shape.shape as BoxShape3D).size = box_size


func _add_static_box(node_name: String) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.collision_layer = DIE_COLLISION_LAYER
	body.collision_mask = DIE_COLLISION_MASK
	body.physics_material_override = _make_tray_physics_material()
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	body.add_child(shape)
	_world_root.add_child(body)
	return body


# ── DICE SPAWNING & PHYSICS ──────────────────────────────────────────────────

func _spawn_die(entry: Dictionary, index: int, _total_count: int) -> RigidBody3D:
	var die: RigidBody3D = RigidBody3D.new()
	die.set_meta("entry", entry)
	_die_by_key[_entry_key(str(entry.get("side", "")), str(entry.get("id", "")))] = die
	# Real dice lose energy to bounces and table friction, not to air drag, so
	# damping stays at ~zero while rolling (a felt-grab ramp kicks in late — see
	# _wait_for_dice_to_settle). Moderate friction lets dice skid and tumble.
	die.mass = 4.0
	die.gravity_scale = DIE_GRAVITY_SCALE
	die.linear_damp = 0.0
	die.angular_damp = 0.12
	die.can_sleep = true
	die.continuous_cd = true
	die.collision_layer = DIE_COLLISION_LAYER
	die.collision_mask = DIE_COLLISION_MASK
	die.physics_material_override = _make_die_physics_material()
	die.position = _get_cluster_spawn_position(index)
	die.rotation_degrees = Vector3(randf_range(0, 360), randf_range(0, 360), randf_range(0, 360))

	var collision: CollisionShape3D = CollisionShape3D.new()
	var convex: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	convex.points = _get_d20_convex_points()
	collision.shape = convex
	die.add_child(collision)

	# All cosmetics live under one container so result presentation can scale
	# the visuals without touching the RigidBody3D (scaling a physics body also
	# scales its collision shape, which breaks frozen-die blocking).
	var visual_root: Node3D = Node3D.new()
	visual_root.name = "Visuals"
	die.add_child(visual_root)

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = _build_d20_mesh()
	# Every accent on this die — face panels, bevel rim, edges, engraved numbers — is derived
	# deterministically from this one base colour so the look is consistent per die.
	var base_color: Color = Color(0.12, 0.42, 0.88, 1.0) if str(entry.get("side", "")) == "hero" else Color(0.72, 0.20, 0.18, 1.0)
	die.set_meta("base_color", base_color)
	mesh_instance.material_override = _bank_material("body:%s" % base_color.to_html(false), func() -> StandardMaterial3D: return _make_body_material(base_color))
	visual_root.add_child(mesh_instance)

	# Inner shell — solid blocker so no back-face geometry shows through
	var inner_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	inner_mesh_instance.mesh = _build_inner_shell_mesh()
	inner_mesh_instance.material_override = _bank_material("inner:%s" % base_color.to_html(false), func() -> StandardMaterial3D: return _make_inner_shell_material(base_color))
	visual_root.add_child(inner_mesh_instance)

	_add_face_panels(die)
	_add_edge_lines(die)
	_add_face_labels(die)

	_dice_root.add_child(die)
	return die


# ── THROW SYSTEM ─────────────────────────────────────────────────────────────
# One "hand" per side per roll: all of a side's dice leave the same off-corner
# origin with a shared throw direction plus per-die jitter, tumbling end-over-end
# around the axis perpendicular to travel — the way a real handful of dice
# crosses a tray. Hero throws from the bottom edge, enemy from the top, each
# sweeping diagonally across its own half so the dice play the side walls.
var _throw_context: Dictionary = {}


func _make_throw_context(side: String) -> Dictionary:
	var z_sign: float = 1.0 if side == "hero" else -1.0
	var near_edge_z: float = _bounds_max_z if side == "hero" else _bounds_min_z
	var hand_x_sign: float = 1.0 if randf() < 0.5 else -1.0
	var hand: Vector3 = Vector3(
		hand_x_sign * maxf(_bounds_half_width - 2.4, 0.0),
		randf_range(THROW_HAND_HEIGHT_MIN, THROW_HAND_HEIGHT_MAX),
		near_edge_z - z_sign * 1.35
	)
	var target_z_near: float = z_sign * 0.8
	var target_z_far: float = near_edge_z - z_sign * 2.0
	var target: Vector3 = Vector3(
		-hand_x_sign * _bounds_half_width * randf_range(0.30, 0.60),
		0.0,
		lerpf(target_z_near, target_z_far, randf())
	)
	var dir: Vector3 = Vector3(target.x - hand.x, 0.0, target.z - hand.z)
	if dir.length_squared() < 0.001:
		dir = Vector3(-hand_x_sign, 0.0, 0.0)
	return {
		"hand": hand,
		"dir": dir.normalized(),
	}


func _get_cluster_spawn_position(index: int) -> Vector3:
	var ctx: Dictionary = _throw_context
	var hand: Vector3 = ctx.get("hand", Vector3(0.0, 3.0, 0.0))
	var dir: Vector3 = ctx.get("dir", Vector3.FORWARD)
	var lateral: Vector3 = dir.cross(Vector3.UP).normalized()
	var offset: Vector3 = THROW_CLUSTER_OFFSETS[index % THROW_CLUSTER_OFFSETS.size()]
	var extra_lift: float = floorf(float(index) / float(THROW_CLUSTER_OFFSETS.size())) * 2.2
	var pos: Vector3 = hand + lateral * offset.x + Vector3.UP * (offset.y + extra_lift) + dir * offset.z
	var margin: float = DIE_RADIUS * 1.05
	pos.x = clampf(pos.x, -_bounds_half_width + margin, _bounds_half_width - margin)
	pos.z = clampf(pos.z, _bounds_min_z + margin, _bounds_max_z - margin)
	return _adjust_spawn_for_occupants(pos, lateral, dir)


# Never materialise a die inside (or directly above) a die already on the tray —
# typically a frozen die parked in a result row near the hand. Sidestep
# laterally first; only if the row is fully crowded, drop in from above.
func _adjust_spawn_for_occupants(pos: Vector3, lateral: Vector3, dir: Vector3) -> Vector3:
	var margin: float = DIE_RADIUS * 1.05
	for _attempt in range(5):
		var blocker: RigidBody3D = _find_die_near_spawn(pos)
		if blocker == null:
			return pos
		var away: Vector3 = pos - blocker.global_transform.origin
		away.y = 0.0
		var side_sign: float = signf(away.dot(lateral))
		if side_sign == 0.0:
			side_sign = 1.0
		pos += lateral * side_sign * 1.35 - dir * 0.4
		pos.x = clampf(pos.x, -_bounds_half_width + margin, _bounds_half_width - margin)
		pos.z = clampf(pos.z, _bounds_min_z + margin, _bounds_max_z - margin)
	pos.y = maxf(pos.y, DIE_RADIUS * 2.6)
	return pos


func _find_die_near_spawn(pos: Vector3) -> RigidBody3D:
	for die_variant in _die_by_key.values():
		var die: RigidBody3D = die_variant as RigidBody3D
		if die == null or not is_instance_valid(die) or not die.is_inside_tree():
			continue
		var o: Vector3 = die.global_transform.origin
		if absf(o.y - pos.y) > DIE_RADIUS * 2.0:
			continue
		if Vector2(o.x - pos.x, o.z - pos.z).length() < DIE_RADIUS * 2.25:
			return die
	return null


const RecordedThrows := preload("res://scripts/battle/recorded_throw_library.gd")
var _variant_fit_cache: Dictionary = {}


# G-31: a recorded variant is playable only if, mapped onto the LIVE tray,
# every die of the throw stays inside the walls for every frame (landing
# included). Picks at random among the variants that fit; -1 when none do.
func _pick_recording_variant(scripted: Array, enemy_count: int) -> int:
	if scripted.is_empty():
		return 0
	var bounds: Array = [_bounds_half_width, _bounds_min_z, _bounds_max_z]
	var fitting: Array[int] = []
	for variant in RecordedThrows.VARIANTS:
		var keys: PackedStringArray = PackedStringArray()
		var tracks: Array = []
		for die_variant in scripted:
			var entry: Dictionary = (die_variant as RigidBody3D).get_meta("entry", {})
			keys.append(RecordedThrows.track_key(enemy_count, variant, str(entry.get("side", "")), int(entry.get("slot_index", 0))))
			tracks.append(RecordedThrows.get_track(enemy_count, variant, str(entry.get("side", "")), int(entry.get("slot_index", 0))))
		var cache_key: String = "%s@%.4f,%.4f,%.4f" % [",".join(keys), bounds[0], bounds[1], bounds[2]]
		if not _variant_fit_cache.has(cache_key):
			_variant_fit_cache[cache_key] = RecordedThrows.group_fits(tracks, bounds, _get_raw_d20_vertices())
		if bool(_variant_fit_cache[cache_key]):
			fitting.append(variant)
	return -1 if fitting.is_empty() else fitting[randi_range(0, fitting.size() - 1)]


# G-26: replay immutable real physics transforms. Rotate all die cosmetics
# before frame zero so the requested numbered face occupies the recorded top.
# A group shares its variant, preserving recorded inter-die collision paths.
func _play_recorded_throw(die: RigidBody3D, target_origin: Vector3, enemy_count: int, variant: int) -> void:
	die.set_meta("busy", true)
	die.set_meta("in_motion", true)
	var entry: Dictionary = die.get_meta("entry", {})
	var track: Dictionary = RecordedThrows.get_track(enemy_count, variant, str(entry.side), int(entry.slot_index))
	if track.is_empty():
		die.set_meta("busy", false)
		return
	var requested: int = int(die.get_meta("scripted_request", 1))
	var recorded_index: int = _get_face_index_for_result(int(track.landed_raw))
	var requested_index: int = _get_face_index_for_result(requested)
	var visuals: Node3D = die.get_node("Visuals")
	visuals.basis = _get_face_forward_result_basis(recorded_index).inverse() * _get_face_forward_result_basis(requested_index)
	var frames: Array = track.frames
	var impacts: Array = track.get("impacts", [])
	var impact_index: int = 0
	var hz: float = float(track.physics_hz)
	var elapsed: float = 0.0
	var dice_audio: Variant = get_node_or_null("/root/DiceAudio")
	# Frames are tray-normalised; map them onto the tray as laid out now.
	var bounds: Array = [_bounds_half_width, _bounds_min_z, _bounds_max_z]
	die.set_meta("recorded_track", track)
	die.global_transform = RecordedThrows.frame_transform(frames[0], bounds)
	while elapsed < float(track.seconds):
		await get_tree().physics_frame
		if not is_instance_valid(die) or _is_exiting_tree:
			return
		elapsed = minf(elapsed + get_physics_process_delta_time(), float(track.seconds))
		var position_in_track: float = elapsed * hz
		var index: int = mini(int(position_in_track), frames.size() - 1)
		var next: int = mini(index + 1, frames.size() - 1)
		die.global_transform = RecordedThrows.frame_transform(frames[index], bounds).interpolate_with(RecordedThrows.frame_transform(frames[next], bounds), position_in_track - index)
		while impact_index < impacts.size() and float(impacts[impact_index][0]) <= position_in_track:
			if dice_audio != null:
				dice_audio.on_die_impact(die.get_instance_id(), float(impacts[impact_index][1]))
			impact_index += 1
	die.global_transform = RecordedThrows.frame_transform(frames.back(), bounds)
	if dice_audio != null:
		dice_audio.on_die_settled(die.get_instance_id())
	# The value comes from the oriented physical top, never from the request.
	die.set_meta("busy", false)
	_resolve_landed_die_face(die, target_origin)


# Dice actually thrown by this tray (test surface: a restored pending roll must
# place its dice without throwing any).
var thrown_dice_total: int = 0


func _launch_die(die: RigidBody3D) -> void:
	thrown_dice_total += 1
	die.set_meta("in_motion", true)
	# Impact audio hooks — only on launched (rolling) dice; frozen and warm-up
	# dice never get contact monitoring.
	var dice_audio: Variant = get_node_or_null("/root/DiceAudio")
	if dice_audio != null:
		die.contact_monitor = true
		die.max_contacts_reported = 4
		die.body_entered.connect(_on_die_contact.bind(die))
	var ctx: Dictionary = _throw_context
	var dir: Vector3 = (ctx.get("dir", Vector3.FORWARD) as Vector3).rotated(Vector3.UP, randf_range(-THROW_YAW_JITTER, THROW_YAW_JITTER))
	var speed: float = randf_range(THROW_SPEED_MIN, THROW_SPEED_MAX)
	die.linear_velocity = dir * speed + Vector3.DOWN * randf_range(0.5, 2.5)
	# End-over-end tumble in the direction of travel (rolling forward), with a
	# little off-axis wobble so no two dice spin identically.
	var tumble_axis: Vector3 = Vector3.UP.cross(dir).normalized()
	var wobble: Vector3 = Vector3(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
	) * randf_range(0.0, THROW_WOBBLE_MAX)
	die.angular_velocity = tumble_axis * randf_range(THROW_TUMBLE_MIN, THROW_TUMBLE_MAX) + wobble


# One reported contact (other die, wall, or floor — the tray's static bodies
# share the dice collision layer, so tray hits count). Post-collision speed is
# the energy proxy; DiceAudio owns debounce/shaping.
func _on_die_contact(_other: Node, die: RigidBody3D) -> void:
	if die == null or not is_instance_valid(die) or die.freeze:
		return
	var entry: Dictionary = die.get_meta("entry", {})
	recording_impact.emit(_entry_key(str(entry.get("side", "")), str(entry.get("id", ""))), die.linear_velocity.length())
	var dice_audio: Variant = get_node_or_null("/root/DiceAudio")
	if dice_audio != null:
		dice_audio.on_die_impact(die.get_instance_id(), die.linear_velocity.length())


func _prepare_frozen_die(entry: Dictionary, index: int, total_count: int) -> RigidBody3D:
	var side: String = str(entry.get("side", ""))
	var unit_id: String = str(entry.get("id", ""))
	var die: RigidBody3D = _get_die_for_entry(side, unit_id)
	var fresh: bool = die == null
	if die == null:
		die = _spawn_die(entry, index, total_count)
		# Fresh frozen die (no carry-over from last roll): rest it on the floor
		# instead of leaving it at throw height.
		die.position.y = DIE_RADIUS * 0.76
	else:
		die.set_meta("entry", entry)
		_die_by_key[_entry_key(side, unit_id)] = die
	die.freeze = true
	die.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	die.linear_velocity = Vector3.ZERO
	die.angular_velocity = Vector3.ZERO
	_set_die_collision_enabled(die, true)
	# A frozen die repeats its crusted face: the one source returns it.
	var display: int = clampi(int(entry.get("frozen_roll", 1)), 1, 20)
	die.set_meta("raw_result", display)
	if value_provider.is_valid() and int(value_provider.call(side, unit_id)) > 0:
		display = clampi(int(value_provider.call(side, unit_id)), 1, 20)
	if fresh:
		# Never seen before (e.g. a restored checkpoint): placed, not rolled.
		var face_index: int = _get_face_index_for_result(display)
		if face_index >= 0:
			die.global_transform = Transform3D(_get_face_forward_result_basis(face_index, die), die.global_transform.origin)
		die.set_meta("face_up", display)
		die.set_meta("shown_value", display)
		_set_die_result_scale(die, false)
	_set_die_frozen_visual(die, true)
	# A carried-over frozen die keeps its pose AND its number: freeze locks the
	# value the die showed (G-23), so it never moves while frozen.
	if not bool(die.get_meta("busy", false)):
		_reset_face_highlights(die)
		_highlight_top_face(die, int(die.get_meta("shown_value", display)), side)
	return die


func _build_inner_shell_mesh() -> ArrayMesh:
	var inner_radius: float = DIE_RADIUS * 0.92
	var phi: float = (1.0 + sqrt(5.0)) * 0.5
	var base_verts: Array[Vector3] = [
		Vector3(-1, phi, 0), Vector3(1, phi, 0), Vector3(-1, -phi, 0), Vector3(1, -phi, 0),
		Vector3(0, -1, phi), Vector3(0, 1, phi), Vector3(0, -1, -phi), Vector3(0, 1, -phi),
		Vector3(phi, 0, -1), Vector3(phi, 0, 1), Vector3(-phi, 0, -1), Vector3(-phi, 0, 1),
	]
	for i in range(base_verts.size()):
		base_verts[i] = base_verts[i].normalized() * inner_radius
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals_arr: PackedVector3Array = PackedVector3Array()
	for face in _get_d20_faces():
		var a: Vector3 = base_verts[int(face[0])]
		var b: Vector3 = base_verts[int(face[1])]
		var c: Vector3 = base_verts[int(face[2])]
		var center: Vector3 = (a + b + c) / 3.0
		var normal: Vector3 = (b - a).cross(c - a).normalized()
		if normal.dot(center) < 0:
			normal = -normal
			vertices.push_back(a)
			vertices.push_back(c)
			vertices.push_back(b)
		else:
			vertices.push_back(a)
			vertices.push_back(b)
			vertices.push_back(c)
		normals_arr.push_back(normal)
		normals_arr.push_back(normal)
		normals_arr.push_back(normal)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals_arr
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_die_physics_material() -> PhysicsMaterial:
	var material: PhysicsMaterial = PhysicsMaterial.new()
	# Hard plastic: lively rebound off walls and other dice, moderate friction
	# so faces skid a touch before they grip (real dice tumble, they don't glue).
	material.bounce = 0.38
	material.friction = 0.42
	return material


func _make_tray_physics_material() -> PhysicsMaterial:
	var material: PhysicsMaterial = PhysicsMaterial.new()
	# Felt-lined tray: a bit grippier than the dice, with enough restitution
	# that wall hits visibly kick back instead of dying on contact.
	material.bounce = 0.42
	material.friction = 0.58
	return material


func _set_die_collision_enabled(die: RigidBody3D, enabled: bool) -> void:
	if die == null or not is_instance_valid(die):
		return
	if enabled:
		die.collision_layer = DIE_COLLISION_LAYER
		die.collision_mask = DIE_COLLISION_MASK
	else:
		die.collision_layer = 0
		die.collision_mask = 0


# ── FACE DATA ─────────────────────────────────────────────────────────────────

func _build_d20_face_data() -> void:
	_face_normals.clear()
	_face_centers.clear()
	_face_text_bases.clear()
	_face_values.clear()
	var raw_vertices: Array[Vector3] = _get_raw_d20_vertices()
	var faces: Array = _get_d20_faces()
	for i in range(faces.size()):
		var face: Array = faces[i]
		var a: Vector3 = raw_vertices[int(face[0])]
		var b: Vector3 = raw_vertices[int(face[1])]
		var c: Vector3 = raw_vertices[int(face[2])]
		var center: Vector3 = (a + b + c) / 3.0
		var normal: Vector3 = (b - a).cross(c - a).normalized()
		if normal.dot(center) < 0:
			normal = -normal
		_face_normals.append(normal)
		_face_centers.append(center)
		_face_text_bases.append(_basis_for_triangle_face(a, b, c, normal))
		_face_values.append(i + 1)


func _get_most_visible_face_value(die: RigidBody3D) -> int:
	var view_normal: Vector3 = RESULT_FACE_NORMAL.normalized()
	var best_dot: float = -999.0
	var best_value: int = 1
	for i in range(_face_normals.size()):
		var world_normal: Vector3 = (die.get_node("Visuals") as Node3D).global_basis * _face_normals[i]
		var dot: float = world_normal.normalized().dot(view_normal)
		if dot > best_dot:
			best_dot = dot
			best_value = int(_face_values[i])
	return best_value


# ── MESH CONSTRUCTION ─────────────────────────────────────────────────────────

func _build_d20_mesh() -> ArrayMesh:
	var raw_vertices: Array[Vector3] = _get_raw_d20_vertices()
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals_arr: PackedVector3Array = PackedVector3Array()
	for face in _get_d20_faces():
		var a: Vector3 = raw_vertices[int(face[0])]
		var b: Vector3 = raw_vertices[int(face[1])]
		var c: Vector3 = raw_vertices[int(face[2])]
		var center: Vector3 = (a + b + c) / 3.0
		var normal: Vector3 = (b - a).cross(c - a).normalized()
		if normal.dot(center) < 0:
			normal = -normal
			vertices.push_back(a)
			vertices.push_back(c)
			vertices.push_back(b)
		else:
			vertices.push_back(a)
			vertices.push_back(b)
			vertices.push_back(c)
		normals_arr.push_back(normal)
		normals_arr.push_back(normal)
		normals_arr.push_back(normal)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals_arr
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _get_d20_convex_points() -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	for vertex in _get_raw_d20_vertices():
		points.push_back(vertex)
	return points


func _get_raw_d20_vertices() -> Array[Vector3]:
	var phi: float = (1.0 + sqrt(5.0)) * 0.5
	var vertices: Array[Vector3] = [
		Vector3(-1, phi, 0), Vector3(1, phi, 0), Vector3(-1, -phi, 0), Vector3(1, -phi, 0),
		Vector3(0, -1, phi), Vector3(0, 1, phi), Vector3(0, -1, -phi), Vector3(0, 1, -phi),
		Vector3(phi, 0, -1), Vector3(phi, 0, 1), Vector3(-phi, 0, -1), Vector3(-phi, 0, 1),
	]
	for i in range(vertices.size()):
		vertices[i] = vertices[i].normalized() * DIE_RADIUS
	return vertices


func _get_d20_faces() -> Array:
	return [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]


# ── FACE VISUALS ──────────────────────────────────────────────────────────────

func _add_face_panels(die: RigidBody3D) -> void:
	var raw_vertices: Array[Vector3] = _get_raw_d20_vertices()
	var faces: Array = _get_d20_faces()
	for face_index in range(faces.size()):
		var face: Array = faces[face_index]
		var a: Vector3 = raw_vertices[int(face[0])]
		var b: Vector3 = raw_vertices[int(face[1])]
		var c: Vector3 = raw_vertices[int(face[2])]
		var center: Vector3 = (a + b + c) / 3.0
		var normal: Vector3 = (b - a).cross(c - a).normalized()
		if normal.dot(center) < 0:
			normal = -normal
		# Main coloured face, then a smaller, slightly-proud darker triangle inside it: the inner
		# rim reads as a recessed bevel where the faces meet (#2). FacePanel%d stays the highlight
		# target; FaceBevel%d is purely cosmetic.
		var panel_inst: MeshInstance3D = _build_face_triangle(center, a, b, c, normal, 0.96, 0.014)
		panel_inst.name = "FacePanel%d" % (face_index + 1)
		panel_inst.material_override = _face_panel_material_for(die)
		_die_visuals(die).add_child(panel_inst)
		var bevel_inst: MeshInstance3D = _build_face_triangle(center, a, b, c, normal, 0.80, 0.016)
		bevel_inst.name = "FaceBevel%d" % (face_index + 1)
		bevel_inst.material_override = _bevel_material_for(_die_base_color(die))
		_die_visuals(die).add_child(bevel_inst)


# A flat triangle inset toward its face centre by `inset` and pushed `offset` along the normal.
func _build_face_triangle(center: Vector3, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, inset: float, offset: float) -> MeshInstance3D:
	var va: Vector3 = center + (a - center) * inset + normal * offset
	var vb: Vector3 = center + (b - center) * inset + normal * offset
	var vc: Vector3 = center + (c - center) * inset + normal * offset
	var panel_normal: Vector3 = (vb - va).cross(vc - va).normalized()
	var verts: PackedVector3Array
	if panel_normal.dot(normal) < 0:
		verts = PackedVector3Array([va, vc, vb])
	else:
		verts = PackedVector3Array([va, vb, vc])
	var face_normals: PackedVector3Array = PackedVector3Array([normal, normal, normal])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = face_normals
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = mesh
	return inst


func _add_edge_lines(die: RigidBody3D) -> void:
	var raw_vertices: Array[Vector3] = _get_raw_d20_vertices()
	var edge_keys: Dictionary = {}
	# One shared unshaded material per die → every edge is the exact same fixed dark tone (#1).
	var edge_mat: StandardMaterial3D = _edge_material_for(_die_base_color(die))
	for face_variant in _get_d20_faces():
		var face: Array = face_variant
		_add_edge_line_if_needed(die, raw_vertices, int(face[0]), int(face[1]), edge_keys, edge_mat)
		_add_edge_line_if_needed(die, raw_vertices, int(face[1]), int(face[2]), edge_keys, edge_mat)
		_add_edge_line_if_needed(die, raw_vertices, int(face[2]), int(face[0]), edge_keys, edge_mat)


func _add_edge_line_if_needed(die: RigidBody3D, raw_vertices: Array[Vector3], a_idx: int, b_idx: int, edge_keys: Dictionary, edge_mat: StandardMaterial3D) -> void:
	var min_idx: int = mini(a_idx, b_idx)
	var max_idx: int = maxi(a_idx, b_idx)
	var key: String = "%d:%d" % [min_idx, max_idx]
	if edge_keys.has(key):
		return
	edge_keys[key] = true
	var a: Vector3 = raw_vertices[a_idx]
	var b: Vector3 = raw_vertices[b_idx]
	var direction: Vector3 = b - a
	var edge_length: float = direction.length()
	if edge_length <= 0.001:
		return
	var edge_mesh: BoxMesh = BoxMesh.new()
	edge_mesh.size = Vector3(0.04, edge_length, 0.04)
	var edge: MeshInstance3D = MeshInstance3D.new()
	edge.mesh = edge_mesh
	edge.material_override = edge_mat
	edge.position = (a + b) * 0.5
	edge.basis = _basis_for_edge(direction.normalized())
	_die_visuals(die).add_child(edge)


func _basis_for_edge(y_axis: Vector3) -> Basis:
	var x_axis: Vector3 = Vector3.UP.cross(y_axis)
	if x_axis.length() < 0.01:
		x_axis = Vector3.RIGHT.cross(y_axis)
	x_axis = x_axis.normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


# ── Deterministic per-die palette ───────────────────────────────────────────────
# Every accent on a die is a fixed darkened/lightened version of its base colour, so the look
# never drifts with lighting or randomness.
func _die_base_color(die: RigidBody3D) -> Color:
	if die.has_meta("base_color"):
		var c: Variant = die.get_meta("base_color")
		if c is Color:
			return c
	return Color(0.12, 0.42, 0.88, 1.0)

func _face_color_for(base: Color) -> Color:
	return base.darkened(0.38)                  # the lit face surface — clearly coloured

func _bevel_color_for(base: Color) -> Color:
	return _face_color_for(base).darkened(0.13)  # ~13% darker inset rim → subtle depth

func _edge_color_for(base: Color) -> Color:
	return base.darkened(0.72)                   # deep, fixed edge tone

func _number_main_color_for(base: Color) -> Color:
	# pkg8.5: near-white numeral fill so the number pops at 450x1000 — the
	# engraved read survives via the dark occlusion rim (toward the light),
	# the lit groove edge (away), and the dark carved-well backing.
	return base.lerp(Color(0.96, 0.97, 0.98, 1.0), 0.82)

func _number_outline_color_for(base: Color) -> Color:
	return base.darkened(0.84)                   # dark outline to crisp the numeral off the face

func _number_shadow_color_for(base: Color) -> Color:
	return base.darkened(0.88)                   # occluded groove rim (offset toward the light)

func _number_highlight_color_for(base: Color) -> Color:
	return base.lightened(0.60)                  # lit groove edge (offset away from the light)

func _number_well_color_for(base: Color) -> Color:
	return base.darkened(0.78)                   # soft oversize backing that reads as the carved well


func _make_body_material(base: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = -2
	m.albedo_color = base
	m.emission_enabled = true
	m.emission = base.darkened(0.50)
	m.emission_energy_multiplier = 0.5
	m.roughness = 0.35
	m.metallic = 0.10
	return m


func _make_inner_shell_material(base: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = -3
	m.albedo_color = base.darkened(0.3)
	m.roughness = 1.0
	return m


func _make_face_panel_material(base: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	m.cull_mode = BaseMaterial3D.CULL_BACK
	m.render_priority = 0
	m.albedo_color = _face_color_for(base)
	m.emission_enabled = true
	m.emission = _face_color_for(base).darkened(0.55)
	m.emission_energy_multiplier = 0.4
	m.roughness = 0.90
	return m


func _make_bevel_material(base: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	m.cull_mode = BaseMaterial3D.CULL_BACK
	m.render_priority = 0
	m.albedo_color = _bevel_color_for(base)
	m.emission_enabled = true
	m.emission = _bevel_color_for(base).darkened(0.55)
	m.emission_energy_multiplier = 0.35
	m.roughness = 0.95
	return m


func _face_panel_material_for(die: RigidBody3D) -> StandardMaterial3D:
	var base: Color = _die_base_color(die)
	return _bank_material("face:%s" % base.to_html(false), func() -> StandardMaterial3D: return _make_face_panel_material(base))


func _bevel_material_for(base: Color) -> StandardMaterial3D:
	return _bank_material("bevel:%s" % base.to_html(false), func() -> StandardMaterial3D: return _make_bevel_material(base))


func _edge_material_for(base: Color) -> StandardMaterial3D:
	return _bank_material("edge:%s" % base.to_html(false), func() -> StandardMaterial3D: return _make_edge_material(base))


# Unshaded so the edge reads its exact albedo from every angle — no grey-vs-black lighting drift.
func _make_edge_material(base: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	m.cull_mode = BaseMaterial3D.CULL_BACK
	m.render_priority = 0
	m.albedo_color = _edge_color_for(base)
	return m


# ── FACE NUMBERS ──────────────────────────────────────────────────────────────

func _get_face_inscribed_radius() -> float:
	var raw_vertices: Array[Vector3] = _get_raw_d20_vertices()
	var face: Array = _get_d20_faces()[0]
	var a: Vector3 = raw_vertices[int(face[0])]
	var b: Vector3 = raw_vertices[int(face[1])]
	var c: Vector3 = raw_vertices[int(face[2])]
	var ab: float = (b - a).length()
	var bc: float = (c - b).length()
	var ca: float = (a - c).length()
	var s: float = (ab + bc + ca) * 0.5
	var area: float = sqrt(s * (s - ab) * (s - bc) * (s - ca))
	return area / s


# Engraved number: four stacked Label3Ds per face. A slightly oversized dark
# "well" underlay suggests the carved recess; a dark rim offset up-left (toward
# the key light, where the groove edge occludes); a bright rim offset
# down-right (the lit groove floor edge); and the numeral itself in a darker
# tint of the face — recessed surfaces sit in shadow, printed ones don't.
# Stacked by render_priority so they layer without z-fighting.
const _ENGRAVE_OFFSET_PX := 2.4   # groove rim spread, in label pixels
# Sit the numerals just above the bevel (0.016) — nearly flush with the surface so they read as
# printed on the face instead of floating above it (the old 0.055 visibly parallaxed while rolling).
const _NUMBER_NORMAL_OFFSET := 0.019
const _NUMBER_OUTLINE_SIZE := 8   # thin dark outline on the main numeral for legibility

func _add_face_labels(die: RigidBody3D) -> void:
	var base: Color = _die_base_color(die)
	var inradius: float = _get_face_inscribed_radius()
	var raw_vertices: Array[Vector3] = _get_raw_d20_vertices()
	var faces: Array = _get_d20_faces()
	for i in range(_face_centers.size()):
		var value: int = int(_face_values[i])
		var face: Array = faces[i]
		var face_basis: Basis = _basis_for_triangle_face(
			raw_vertices[int(face[0])],
			raw_vertices[int(face[1])],
			raw_vertices[int(face[2])],
			_face_normals[i]
		)
		var center_pos: Vector3 = _face_centers[i] + face_basis.y * (inradius * 0.12) + _face_normals[i] * _NUMBER_NORMAL_OFFSET
		var spread: float = _ENGRAVE_OFFSET_PX * 0.0060
		var down_right: Vector3 = face_basis.x * spread - face_basis.y * spread
		var up_left: Vector3 = -face_basis.x * spread + face_basis.y * spread
		_make_face_label(die, "FaceNumberWell%d" % value, value, face_basis, center_pos, _number_well_color_for(base), 5, 0, base, 14)
		_make_face_label(die, "FaceNumberShadow%d" % value, value, face_basis, center_pos + up_left, _number_shadow_color_for(base), 6, 0, base)
		_make_face_label(die, "FaceNumberHighlight%d" % value, value, face_basis, center_pos + down_right, _number_highlight_color_for(base), 7, 0, base)
		# Main numeral carries a thin dark outline that keeps it legible against the face.
		_make_face_label(die, "FaceNumber%d" % value, value, face_basis, center_pos, _number_main_color_for(base), 8, _NUMBER_OUTLINE_SIZE, base)


func _make_face_label(die: RigidBody3D, node_name: String, value: int, face_basis: Basis, pos: Vector3, color: Color, priority: int, outline_size: int, base: Color, font_size_delta: int = 0) -> void:
	var value_text: String = "%d" % value
	var label: Label3D = Label3D.new()
	label.name = node_name
	label.text = value_text
	label.font = _get_dice_number_font()
	label.font_size = (128 if value_text.length() == 1 else 108) + font_size_delta
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate = color
	label.outline_size = outline_size
	if outline_size > 0:
		label.outline_modulate = _number_outline_color_for(base)
	label.pixel_size = 0.0060
	label.no_depth_test = false
	label.render_priority = priority
	label.position = pos
	label.basis = face_basis
	_die_visuals(die).add_child(label)


# ── ORIENTATION HELPERS ───────────────────────────────────────────────────────

func _get_dice_number_font() -> Font:
	# Delegates to the single font source (duplicated-loader rule): this used to
	# be a COPY of PixelUI's raw-path loader, and both copies failed identically
	# on device (the raw .ttf isn't in the APK — only the imported artifact),
	# which is why the die numerals rendered in the system font ("Bug 2": the
	# dice were never wrong, their labels were). PixelUI.get_pixel_font() loads
	# the imported resource via ResourceLoader and fails LOUDLY if it can't.
	if _dice_number_font == null:
		_dice_number_font = PixelUI.get_pixel_font()
	return _dice_number_font


func _basis_for_triangle_face(a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> Basis:
	var face_basis: Basis = _basis_for_face_surface(normal)
	var apex: Vector3 = a
	var base_a: Vector3 = b
	var base_b: Vector3 = c
	var best_height: float = a.dot(face_basis.y)
	if b.dot(face_basis.y) > best_height:
		apex = b
		base_a = a
		base_b = c
		best_height = b.dot(face_basis.y)
	if c.dot(face_basis.y) > best_height:
		apex = c
		base_a = a
		base_b = b
	var x_axis: Vector3 = (base_b - base_a).normalized()
	var y_axis: Vector3 = (apex - (base_a + base_b) * 0.5).normalized()
	var z_axis: Vector3 = normal.normalized()
	if x_axis.cross(y_axis).dot(z_axis) < 0.0:
		x_axis = -x_axis
	return Basis(x_axis, y_axis, z_axis).orthonormalized()


func _basis_for_face_surface(normal: Vector3) -> Basis:
	var z_axis: Vector3 = normal.normalized()
	var x_axis: Vector3 = Vector3.UP.cross(z_axis)
	if x_axis.length() < 0.01:
		x_axis = Vector3.RIGHT.cross(z_axis)
	x_axis = x_axis.normalized()
	var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func _set_die_frozen_visual(die: RigidBody3D, is_frozen: bool, flavor: String = "ice") -> void:
	var filter: MeshInstance3D = _die_part(die, "FrozenFilter") as MeshInstance3D
	if filter == null:
		filter = MeshInstance3D.new()
		filter.name = "FrozenFilter"
		filter.mesh = _build_d20_mesh()
		filter.scale = Vector3.ONE * 1.025
		_die_visuals(die).add_child(filter)
	# Petrify (Accretion) reads stone-gray; ice keeps the cyan crust.
	filter.material_override = _get_petrify_filter_material() if flavor == "petrify" else _get_frozen_filter_material()
	filter.visible = is_frozen

	var label: Label3D = _die_part(die, "FrozenOverlay") as Label3D
	if label == null:
		label = Label3D.new()
		label.name = "FrozenOverlay"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 56
		label.outline_size = 10
		label.outline_modulate = Color(0.02, 0.06, 0.10, 1.0)
		label.position = Vector3(0, DIE_RADIUS * 2.28, 0)
		label.scale = Vector3(0.030, 0.030, 0.030)
		_die_visuals(die).add_child(label)
	label.text = "PETRIFIED" if flavor == "petrify" else "FROZEN"
	label.modulate = Color(0.72, 0.70, 0.66, 0.94) if flavor == "petrify" else Color(0.70, 0.94, 1.0, 0.92)
	label.visible = is_frozen


# Jam (pkg8.1): amber tint shell + a cap marker under the die.
func _set_die_jam_visual(die: RigidBody3D, jam_cap: int) -> void:
	var jammed: bool = jam_cap > 0
	var filter: MeshInstance3D = _die_part(die, "JamFilter") as MeshInstance3D
	if filter == null:
		filter = MeshInstance3D.new()
		filter.name = "JamFilter"
		filter.mesh = _build_d20_mesh()
		filter.scale = Vector3.ONE * 1.02
		filter.material_override = _get_jam_filter_material()
		_die_visuals(die).add_child(filter)
	filter.visible = jammed

	var label: Label3D = _die_part(die, "JamCapMarker") as Label3D
	if label == null:
		label = Label3D.new()
		label.name = "JamCapMarker"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 50
		label.modulate = Color(0.95, 0.76, 0.28, 0.95)
		label.outline_size = 10
		label.outline_modulate = Color(0.06, 0.05, 0.02, 1.0)
		label.position = Vector3(0, DIE_RADIUS * 1.82, 0)
		label.scale = Vector3(0.028, 0.028, 0.028)
		_die_visuals(die).add_child(label)
	label.text = "JAM <=%d" % jam_cap
	label.visible = jammed


# pkg8.4: Jam feedback — the amber tint shell flickers like static before it
# settles on, and the cap marker stamps in.
func play_jam_flicker(side: String, unit_id: String, jam_cap: int) -> void:
	var die: RigidBody3D = _get_die_for_entry(side, unit_id)
	if die == null:
		return
	_set_die_jam_visual(die, jam_cap if jam_cap > 0 else JAM_FALLBACK_CAP)
	var filter: MeshInstance3D = _die_part(die, "JamFilter") as MeshInstance3D
	if filter == null:
		return
	var tween: Tween = create_tween()
	for _i in 3:
		tween.tween_callback(func(): filter.visible = false)
		tween.tween_interval(0.05)
		tween.tween_callback(func(): filter.visible = true)
		tween.tween_interval(0.06)


const JAM_FALLBACK_CAP := 10


# Rewrite feedback: the pending marker shows a static REWRITE->N tag (G-29 —
# no cycling digits anywhere on or over a die). The die keeps its face; the
# marker is the telegraph.
func play_rewrite_scramble(side: String, unit_id: String) -> void:
	var die: RigidBody3D = _get_die_for_entry(side, unit_id)
	if die == null:
		return
	_set_die_pending_marker(die, true, false)


# Rewrite / Hijack pending (pkg8.1): marker on the threatened die.
func _set_die_pending_marker(die: RigidBody3D, rewrite_pending: bool, hijack_pending: bool) -> void:
	var label: Label3D = _die_part(die, "PendingMarker") as Label3D
	if label == null:
		label = Label3D.new()
		label.name = "PendingMarker"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 50
		label.outline_size = 10
		label.outline_modulate = Color(0.04, 0.02, 0.06, 1.0)
		label.position = Vector3(0, DIE_RADIUS * 2.72, 0)
		label.scale = Vector3(0.028, 0.028, 0.028)
		_die_visuals(die).add_child(label)
	if rewrite_pending:
		label.text = "REWRITE->%d" % CombatManager.REWRITE_VALUE
		label.modulate = Color(0.82, 0.55, 1.0, 0.95)
	elif hijack_pending:
		label.text = "HIJACK"
		label.modulate = Color(0.95, 0.45, 0.30, 0.95)
	label.visible = rewrite_pending or hijack_pending


func _get_petrify_filter_material() -> StandardMaterial3D:
	# Transparent status shells must not write depth: doing so masks the engraved
	# face labels even though their render priorities are above the shell.
	return _bank_material("filter:petrify", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.render_priority = 4
		m.albedo_color = Color(0.55, 0.53, 0.49, 0.38)
		m.roughness = 0.85
		m.metallic = 0.0
		return m)


func _get_jam_filter_material() -> StandardMaterial3D:
	return _bank_material("filter:jam", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.render_priority = 3
		m.albedo_color = Color(0.92, 0.68, 0.20, 0.20)
		m.roughness = 0.5
		m.metallic = 0.0
		return m)


func _get_frozen_filter_material() -> StandardMaterial3D:
	return _bank_material("filter:frozen", func() -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.render_priority = 4
		m.albedo_color = Color(0.48, 0.86, 1.0, 0.26)
		m.emission_enabled = true
		m.emission = Color(0.28, 0.70, 1.0, 1.0)
		m.emission_energy_multiplier = 0.38
		m.roughness = 0.18
		m.metallic = 0.0
		return m)


func _clear_dice() -> void:
	if _dice_root == null:
		return
	for child in _dice_root.get_children():
		child.queue_free()
	_die_by_key.clear()


func _clear_dice_except(keep_keys: Array[String]) -> void:
	if _dice_root == null:
		return
	var keep_lookup: Dictionary = {}
	for key in keep_keys:
		keep_lookup[key] = true
	var next_die_by_key: Dictionary = {}
	for child_variant in _dice_root.get_children():
		var die: RigidBody3D = child_variant as RigidBody3D
		if die == null:
			child_variant.queue_free()
			continue
		var entry: Dictionary = die.get_meta("entry", {})
		var key: String = _entry_key(str(entry.get("side", "")), str(entry.get("id", "")))
		if keep_lookup.has(key):
			next_die_by_key[key] = die
			continue
		die.queue_free()
	_die_by_key = next_die_by_key


func _entry_key(side: String, unit_id: String) -> String:
	return "%s:%s" % [side, unit_id]
