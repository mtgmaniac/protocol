# Action motion gate (playtest 2026-10-08).
#
#   godot --headless --path . -s scripts/debug/action_motion_test.gd [-- --action-motion-break=no_wiggle]
#
# A unit that buffs, debuffs, shields or heals without attacking used to stand
# still while attackers lunged. It now shakes in place. Pinned here:
#   A. data    every ability of every hero, evolution and enemy gets a motion
#              class: it attacks -> lunge, anything else -> wiggle, never none;
#              one named ability per class, mixed attack + buff included.
#   B. live    a real round on a BattleScene: each acting unit's card plays the
#              class of the ability it rolled, heroes and enemies, both classes
#              on both sides.
#   C. motion  the wiggle moves sideways to the lunge and returns to rest; it is
#              smaller than the lunge; Reduced Motion plays a smaller wiggle
#              and a smaller lunge, scaled alike (5 of 12); No animations
#              plays neither. (The landscape axis is pinned in
#              battle_layout_test, on a real landscape scene.)
# scripts/checks/break_gate.py reruns it with each ActionMotion.BREAK_ARG mode
# (no_wiggle, all_lunge, reduced_full, no_anim_ignored) and requires a FAIL.
# `-- --action-motion-list` prints every ability with its class for the report.
extends SceneTree

const ActionMotion := preload("res://scripts/battle/action_motion.gd")
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SPEED := 8
const LUNGE_DIST := 26.0

# One named ability per class. The test's own table: a rule change that moves
# any of these has to be made here on purpose.
const NAMED := {
	"Skull Drive": "lunge",          # attack only
	"Titan Gouge": "lunge",          # attack + lifesteal + roll penalty
	"Cover Fire": "lunge",           # attack + shield (mixed: attack wins)
	"Recovery Salvo": "lunge",       # attack + heal (mixed)
	"Fortress Lash": "lunge",        # attack + ally shield + roll buff + firewall (mixed)
	"Salvage Shell": "wiggle",       # shield
	"Triage": "wiggle",              # heal
	"Capacitor Hum": "wiggle",       # buff
	"Wideband Hiss": "wiggle",       # debuff, all enemies
	"Static Hiss": "wiggle",         # debuff, one hero
	"Seal Sigil": "wiggle",          # firewall
	"Active Camouflage": "wiggle",   # cloak
	"Lattice Guard": "wiggle",       # taunt
	"Target Lock": "wiggle",         # mark
	"Cryo Lattice": "wiggle",        # freeze
	"Mimic Gland": "wiggle",         # hijack
	"Resuscitate": "wiggle",         # revive
	"Tyrant Mantle": "wiggle",       # shield + rampage
}

var _errors: PackedStringArray = []
var _played: Dictionary = {}  # actor id -> kind, from BattleFeedback.action_motion


func _initialize() -> void:
	call_deferred("_run")


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_errors.append(what)


func sm() -> Node:
	return root.get_node("/root/SaveManager")


func _run() -> void:
	await process_frame
	root.get_node("/root/AudioManager").set_suppressed(true)
	sm().set_setting("ability_primers_enabled", false)
	sm().set_setting("reduced_motion", false)
	sm().set_setting("no_animations", false)
	_check_data()
	await _check_live()
	sm().set_setting("reduced_motion", false)
	sm().set_setting("no_animations", false)
	for error in _errors:
		print("[ACTION_MOTION] FAIL - %s" % error)
	print("[ACTION_MOTION] %s" % ("PASS" if _errors.is_empty() else "FAIL - %d check(s)" % _errors.size()))
	sm().clear_run_save()
	if current_scene != null:
		unload_current_scene()
	await create_timer(0.3).timeout
	quit(0 if _errors.is_empty() else 1)


# ── A. Every ability in the data ──────────────────────────────────────────────
func _all_abilities() -> Array:
	var dm: Node = root.get_node("/root/DataManager")
	var rows: Array = []
	for unit_id in dm.units:
		var unit: Resource = dm.units[unit_id]
		for entry in unit.dice_ranges:
			rows.append(["hero", str(unit.display_name), entry])
		for path in unit.evolution_paths:
			for entry in (path as Dictionary).get("abilities", []):
				rows.append(["hero", str((path as Dictionary).get("name", "")), entry])
	for enemy_id in dm.enemies:
		var enemy: Resource = dm.enemies[enemy_id]
		for entry in enemy.dice_ranges:
			rows.append(["enemy", str(enemy.display_name), entry])
	return rows


# The gate's own statement of the rule, kept apart from ActionMotion.attacks.
func _expected(raw: Dictionary) -> String:
	for key in ["dmg", "burn"]:
		if int(raw.get(key, 0)) > 0:
			return "lunge"
	return "lunge" if bool(raw.get("detonate", false)) else "wiggle"


func _check_data() -> void:
	var rows: Array = _all_abilities()
	_expect(rows.size() >= 300, "fixture: every hero, evolution and enemy ability is read (%d)" % rows.size())
	var seen: Dictionary = {}
	var counts := {"lunge": 0, "wiggle": 0}
	var listing: bool = OS.get_cmdline_user_args().has("--action-motion-list")
	for row in rows:
		var entry: Dictionary = row[2]
		var raw: Dictionary = entry.get("raw", {})
		var ability: String = str(entry.get("ability_name", ""))
		if ability == "" or raw.is_empty():
			continue
		var kind: String = ActionMotion.for_ability(raw)
		var want: String = _expected(raw)
		_expect(kind == want, "%s / %s (%s): %s, expected %s" % [row[1], ability, str(entry.get("description", "")), kind, want])
		counts[kind] = int(counts.get(kind, 0)) + 1
		if NAMED.has(ability):
			seen[ability] = true
			_expect(kind == str(NAMED[ability]), "named ability %s: %s, expected %s" % [ability, kind, str(NAMED[ability])])
		if listing:
			print("[ACTION_MOTION_LIST] %s\t%s\t%s\t%s\t%s" % [kind, row[0], row[1], ability, str(entry.get("description", ""))])
	for ability in NAMED:
		_expect(seen.has(ability), "fixture: named ability %s exists in the data" % ability)
	_expect(int(counts["lunge"]) > 0 and int(counts["wiggle"]) > 0, "both classes exist in the data (%s)" % str(counts))
	print("[ACTION_MOTION] data: %d lunge, %d wiggle" % [int(counts["lunge"]), int(counts["wiggle"])])


# ── B and C. A real battle ────────────────────────────────────────────────────
func _check_live() -> void:
	Engine.physics_ticks_per_second = 120 * SPEED
	Engine.time_scale = SPEED
	Engine.max_physics_steps_per_frame = 64
	var gs: Node = root.get_node("/root/GameState")
	sm().clear_run_save()
	gs.reset_run()
	gs.start_run(["combat", "engineer", "medic"], "facility", 81008)
	gs.advance_to_next_battle()
	gs.current_battle = 2
	change_scene_to_file(BATTLE_SCENE)
	for _i in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE and current_scene.is_node_ready():
			break
	await create_timer(0.8).timeout
	var scene: Node = current_scene
	if scene == null or scene.scene_file_path != BATTLE_SCENE:
		_errors.append("battle scene did not load")
		return
	var heroes: Array = scene.combat_manager.get_hero_states()
	var enemies: Array = scene.combat_manager.get_enemy_states()
	_expect(heroes.size() == 3 and enemies.size() >= 2, "fixture: three heroes, two or more enemies")
	if heroes.size() != 3 or enemies.size() < 2:
		return
	# Strike attacks; Engineer and Medic roll their low, non-attacking bands.
	# The first enemy rolls its low band (a shield), the rest attack.
	var rig: Dictionary = {}
	var hero_vals := [9, 2, 2]
	for i in heroes.size():
		rig["hero:%s" % heroes[i]["id"]] = hero_vals[i]
	for i in enemies.size():
		rig["enemy:%s" % enemies[i]["id"]] = 1 if i == 0 else 12
	scene.dice_tray_3d.set_rigged_results(rig)
	await scene._begin_targeting_phase()
	await _settle(scene)
	if int(scene.turn_phase) == int(scene.PHASE_TARGETING):
		await scene._auto_assign_pending_targets(false)

	# What each unit is about to use, and the class the gate expects for it.
	var want: Dictionary = {}
	for state in heroes:
		var entry: Dictionary = scene.dice_manager.get_ability_for_roll(state["unit"], int(scene.hero_rolls.get(state["id"], 0)))
		want[str(state["id"])] = _expected(entry.get("raw", {}))
	for state in enemies:
		var entry: Dictionary = scene.dice_manager.get_ability_for_roll(state["unit"], int(scene.enemy_rolls.get(state["id"], 0)))
		want[str(state["id"])] = _expected(entry.get("raw", {}))
	var hero_kinds: Dictionary = {}
	var enemy_kinds: Dictionary = {}
	for state in heroes:
		hero_kinds[want[str(state["id"])]] = true
	for state in enemies:
		enemy_kinds[want[str(state["id"])]] = true
	_expect(hero_kinds.size() == 2, "fixture: the heroes roll one attack and one non-attack (%s)" % str(hero_kinds.keys()))
	_expect(enemy_kinds.size() == 2, "fixture: the enemies roll one attack and one non-attack (%s)" % str(enemy_kinds.keys()))

	scene._feedback.action_motion.connect(func(actor_id: String, kind: String) -> void: _played[actor_id] = kind)
	await scene._resolve_current_turn(false)
	await create_timer(0.5).timeout
	for state in heroes + enemies:
		var id: String = str(state["id"])
		if not _played.has(id):
			# A unit killed before its turn never acts.
			_expect(bool(state["dead"]), "%s acted but its card played no motion" % id)
			continue
		_expect(str(_played[id]) == str(want[id]), "%s: card played %s, its ability is %s" % [id, str(_played[id]), str(want[id])])
	_expect(_played.size() >= 4, "the round played a motion for the units that acted (%d)" % _played.size())

	await _check_motion(scene)


func _check_motion(scene: Node) -> void:
	Engine.time_scale = 1.0
	var feedback: Node = scene._feedback
	var card: Control = scene.hero_card_views[0].card
	var rest: Vector2 = card.position

	var lunge: Vector2 = await _peak(card, func() -> void: feedback._lunge(card, "hero"))
	_expect(lunge.y > LUNGE_DIST * 0.6 and lunge.x < 0.5, "the lunge steps toward the enemy rail (peak %s)" % str(lunge))

	var wiggle: Vector2 = await _peak(card, func() -> void: feedback._wiggle(card))
	_expect(wiggle.x >= 6.0 and wiggle.y < 0.5, "the wiggle shakes sideways, in place (peak %s)" % str(wiggle))
	_expect(wiggle.x < LUNGE_DIST * 0.6, "the wiggle is smaller than the lunge (%s vs %s)" % [str(wiggle.x), str(lunge.y)])
	_expect(card.position.is_equal_approx(rest), "the wiggle returns the card to rest")

	sm().set_setting("reduced_motion", true)
	var reduced: Vector2 = await _peak(card, func() -> void: feedback._wiggle(card))
	_expect(reduced.x > 1.0 and reduced.x < wiggle.x * 0.6 and reduced.y < 0.5, "Reduced Motion: a smaller wiggle (peak %s, full %s)" % [str(reduced), str(wiggle)])
	# The lunge shrinks by the same ratio as the wiggle: 5 of 12, so 26 -> 11.
	var small_lunge: Vector2 = await _peak(card, func() -> void: feedback._lunge(card, "hero"))
	var want: float = roundf(LUNGE_DIST * 5.0 / 12.0)
	_expect(small_lunge.x < 0.5 and small_lunge.y > want * 0.6 and small_lunge.y <= want + 0.5, "Reduced Motion: a small lunge of about %d px (peak %s, full %s)" % [int(want), str(small_lunge), str(lunge)])
	_expect(card.position.is_equal_approx(rest), "Reduced Motion: the small lunge returns the card to rest")
	sm().set_setting("reduced_motion", false)

	sm().set_setting("no_animations", true)
	var still: Vector2 = await _peak(card, func() -> void: feedback._wiggle(card))
	_expect(still.is_zero_approx(), "No animations: no wiggle (peak %s)" % str(still))
	var no_lunge: Vector2 = await _peak(card, func() -> void: feedback._lunge(card, "hero"))
	_expect(no_lunge.is_zero_approx(), "No animations: no lunge (peak %s)" % str(no_lunge))
	sm().set_setting("no_animations", false)

	_expect(card.position.is_equal_approx(rest), "the card ends at rest")


# Peak distance from rest on each axis while the motion plays.
func _peak(card: Control, start: Callable) -> Vector2:
	var rest: Vector2 = card.position
	var peak := Vector2.ZERO
	start.call()
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < 550:
		await process_frame
		peak.x = maxf(peak.x, absf(card.position.x - rest.x))
		peak.y = maxf(peak.y, absf(card.position.y - rest.y))
	return peak


func _settle(scene: Node) -> void:
	for _i in 900:
		var tray: Object = scene.dice_tray_3d
		var busy: bool = bool(tray.get("_is_rolling"))
		if not busy:
			for key in tray._die_by_key:
				var parts: PackedStringArray = str(key).split(":", true, 1)
				if tray.is_die_moving(parts[0], parts[1]):
					busy = true
					break
		if not busy:
			return
		await process_frame
