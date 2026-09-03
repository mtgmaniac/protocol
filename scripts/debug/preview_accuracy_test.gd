# Headless regression: the damage preview must not LIE about the coming round.
# Heroes resolve before the enemy phase, so an honest forecast has to walk the
# hero phase first. Three lies are pinned here (all reported 2026-09-02):
#   1. LETHAL — an enemy the assignment will kill still telegraphed its damage
#      onto a hero bar, though it never gets to act.
#   2. TAUNT  — a taunt redirects the enemy's attack at resolve time; the
#      preview kept showing the original target.
#   3. LEECH  — leech healing never reached the projection, so the net HP
#      change was wrong even when the damage figure was right.
# Run: godot --headless --path . -s scripts/debug/preview_accuracy_test.gd
# FAIL-ON-OLD: pre-forecast battle_card_view fails cases 1, 2 and 3.
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SQUAD := ["combat", "engineer", "medic"]

var _errors: PackedStringArray = []
var _dm: Object
var _cm: Object
var _card_view: Object
var _hero_rolls: Dictionary
var _enemy_rolls: Dictionary


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[PREVIEW_ACCURACY] Starting preview-honesty regression")
	var gs: Node = root.get_node("/root/GameState")
	var dmgr: Node = root.get_node("/root/DataManager")
	gs.call("start_run", SQUAD, str(dmgr.call("get_operation_order")[0]))
	gs.call("advance_to_next_battle")
	change_scene_to_file(BATTLE_SCENE)
	var retries := 180
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE:
			break
	await create_timer(1.0).timeout

	var roll_button: Button = current_scene.get_node_or_null("%RollButton") as Button
	if roll_button != null and roll_button.visible and not roll_button.disabled:
		var tray: Node = current_scene.get_node_or_null("%DiceTray3D")
		roll_button.emit_signal("pressed")
		if tray != null and tray.has_signal("roll_finished"):
			await tray.roll_finished
		else:
			await create_timer(2.0).timeout
	await create_timer(0.4).timeout

	_cm = current_scene.get("combat_manager")
	_dm = current_scene.get("dice_manager")
	_card_view = current_scene.get("_card_view")
	_hero_rolls = current_scene.get("hero_rolls")
	_enemy_rolls = current_scene.get("enemy_rolls")
	current_scene.set("turn_phase", int(current_scene.get("PHASE_TARGETING")))
	current_scene.set("has_player_target_assignment", false)

	var heroes: Array = _living(_cm.call("get_hero_states"))
	var enemies: Array = _living(_cm.call("get_enemy_states"))
	if heroes.size() < 2 or enemies.is_empty():
		_errors.append("need 2 living heroes and 1 living enemy to run the cases")
		_finish()
		return

	# Quiet board: no hero does anything, no enemy does anything. Each case then
	# switches on exactly the one thing it is measuring.
	for hero_variant in heroes:
		var hero_state: Dictionary = hero_variant
		_silence_hero(hero_state)
	for enemy_variant in enemies:
		var enemy_state: Dictionary = enemy_variant
		_silence_enemy(enemy_state)

	var attacker: Dictionary = {}
	var attacker_dmg: int = 0
	for enemy_variant in enemies:
		var enemy_state: Dictionary = enemy_variant
		var roll: int = _find_roll(enemy_state, "single")
		if roll > 0:
			attacker = enemy_state
			attacker_dmg = int(_ability_raw(enemy_state, roll).get("dmg", 0))
			_enemy_rolls[str(enemy_state["id"])] = roll
			break
	if attacker.is_empty():
		_errors.append("no enemy has a single-target damage ability to telegraph")
		_finish()
		return

	var victim: Dictionary = heroes[0]
	var bystander: Dictionary = heroes[1]
	attacker["selected_target_id"] = str(victim["id"])

	# ── CASE 1: baseline — a living enemy's telegraph DOES show. ─────────────
	var base_dmg: int = int(_preview(victim, true).get("damage", 0))
	_expect(base_dmg >= attacker_dmg,
		"baseline: a living enemy's telegraph shows on its target (dmg=%d, want>=%d)" % [base_dmg, attacker_dmg])

	# ── CASE 2: LETHAL — the same enemy, about to die, must not telegraph. ───
	var killer: Dictionary = {}
	var killer_roll: int = 0
	for hero_variant in heroes:
		var hero_state: Dictionary = hero_variant
		var roll: int = _find_roll(hero_state, "single")
		if roll > 0:
			killer = hero_state
			killer_roll = roll
			break
	if killer.is_empty():
		_errors.append("no hero has a single-target damage ability to land the kill")
	else:
		var kill_dmg: int = int(_ability_raw(killer, killer_roll).get("dmg", 0))
		var saved_hp: int = int(attacker["current_hp"])
		var saved_shield: int = int(attacker.get("shield", 0))
		attacker["current_hp"] = 1
		attacker["shield"] = 0
		_hero_rolls[str(killer["id"])] = killer_roll
		killer["selected_target_id"] = str(attacker["id"])

		var enemy_preview: Dictionary = _preview(attacker, false)
		_expect(bool(enemy_preview.get("lethal", false)),
			"lethal: the doomed enemy's own card reads lethal (dmg=%d vs 1 HP, ability=%d)" % [int(enemy_preview.get("damage", 0)), kill_dmg])

		var after_dmg: int = int(_preview(victim, true).get("damage", 0))
		_expect(after_dmg == base_dmg - attacker_dmg,
			"lethal: a doomed enemy's telegraph is REMOVED from its target's bar (dmg=%d, want=%d)" % [after_dmg, base_dmg - attacker_dmg])

		# Restore for the next cases.
		attacker["current_hp"] = saved_hp
		attacker["shield"] = saved_shield
		_silence_hero(killer)

	# ── CASE 3: TAUNT — the redirect moves the telegraph to the taunter. ─────
	# Anchor Frame is the standing aura form (combat_manager._get_taunting_hero_state);
	# it redirects EVERY enemy's single-target pick while its holder is above
	# half HP, and the preview ignored it completely.
	bystander["gear_anchor_taunt"] = true
	bystander["current_hp"] = int(bystander["max_hp"])
	var taunted_victim: int = int(_preview(victim, true).get("damage", 0))
	var taunted_bystander: int = int(_preview(bystander, true).get("damage", 0))
	_expect(taunted_victim == base_dmg - attacker_dmg,
		"taunt: the original target no longer shows the redirected hit (dmg=%d, want=%d)" % [taunted_victim, base_dmg - attacker_dmg])
	_expect(taunted_bystander >= attacker_dmg,
		"taunt: the taunter shows the hit it pulled (dmg=%d, want>=%d)" % [taunted_bystander, attacker_dmg])
	bystander["gear_anchor_taunt"] = false

	# The cast form (ruling G-4, per-enemy lured_by_id) goes through the same
	# choke point — assert the resolver honours a lure recorded for this round.
	var forecast: Dictionary = {
		"dead_enemy_ids": {},
		"lured": {str(attacker["id"]): str(bystander["id"])},
		"taunter_id": "",
		"leech_by_hero": {},
	}
	var lured_to: String = str(_card_view.call("_forecast_enemy_target", attacker, forecast))
	_expect(lured_to == str(bystander["id"]),
		"taunt: a taunt cast THIS round redirects the enemy in the forecast (got '%s', want '%s')" % [lured_to, str(bystander["id"])])

	# ── CASE 4: LEECH — the attacker's self-heal reaches the projection. ─────
	var leecher: Dictionary = {}
	var leech_roll: int = 0
	for hero_variant in heroes:
		var hero_state: Dictionary = hero_variant
		var roll: int = _find_roll(hero_state, "leech")
		if roll > 0:
			leecher = hero_state
			leech_roll = roll
			break
	if leecher.is_empty():
		_errors.append("no hero in the squad has a leech ability (expected: Strike Unit / Splice Medic)")
	else:
		var target: Dictionary = enemies[0]
		target["shield"] = 0
		target["current_hp"] = maxi(int(target["current_hp"]), 60)
		_hero_rolls[str(leecher["id"])] = leech_roll
		leecher["selected_target_id"] = str(target["id"])
		var leech_dmg: int = int(_ability_raw(leecher, leech_roll).get("dmg", 0))
		var want_heal: int = int(floor(float(leech_dmg) * 0.5))
		var healed: int = int(_preview(leecher, true).get("heal", 0))
		_expect(want_heal > 0 and healed >= want_heal,
			"leech: the attacker's self-heal shows on its own bar (heal=%d, want>=%d from %d dmg)" % [healed, want_heal, leech_dmg])

	_finish()


func _living(states: Array) -> Array:
	var out: Array = []
	for state_variant in states:
		if not bool((state_variant as Dictionary).get("dead", false)):
			out.append(state_variant)
	return out


# Parks a unit on a roll that does nothing, with no target, so it contributes
# zero to every preview until a case deliberately arms it.
func _silence_hero(hero_state: Dictionary) -> void:
	var quiet: int = _find_roll(hero_state, "nondmg")
	if quiet > 0:
		_hero_rolls[str(hero_state["id"])] = quiet
	hero_state["selected_target_id"] = ""
	hero_state["target_display"] = "--"
	hero_state["gear_anchor_taunt"] = false


func _silence_enemy(enemy_state: Dictionary) -> void:
	var quiet: int = _find_roll(enemy_state, "nondmg")
	if quiet > 0:
		_enemy_rolls[str(enemy_state["id"])] = quiet
	enemy_state["selected_target_id"] = ""
	enemy_state["lured_by_id"] = ""


func _preview(state: Dictionary, is_hero: bool) -> Dictionary:
	return _card_view.call("compute_preview_for_unit", state, is_hero)


func _find_roll(state: Dictionary, kind: String) -> int:
	for r in range(1, 21):
		var raw: Dictionary = _ability_raw(state, r)
		if raw.is_empty():
			continue
		var dmg: int = int(raw.get("dmg", 0))
		var blast: bool = bool(raw.get("blastAll", false))
		match kind:
			"single":
				if dmg > 0 and not blast:
					return r
			"leech":
				if dmg > 0 and not blast and bool(raw.get("leech", false)):
					return r
			"nondmg":
				if dmg == 0 and not blast and int(raw.get("burn", 0)) == 0 \
						and int(raw.get("heal", 0)) == 0 and not bool(raw.get("healAll", false)) \
						and not bool(raw.get("shieldAll", false)) and not bool(raw.get("taunt", false)):
					return r
	return 0


func _ability_raw(state: Dictionary, roll: int) -> Dictionary:
	var entry: Dictionary = _dm.call("get_ability_for_roll", state.get("unit"), roll)
	return entry.get("raw", {})


func _expect(cond: bool, label: String) -> void:
	if cond:
		print("PASS [preview-accuracy] %s" % label)
	else:
		_errors.append(label)


func _finish() -> void:
	if _errors.is_empty():
		print("[PREVIEW_ACCURACY] PASS")
	else:
		for e in _errors:
			print("[PREVIEW_ACCURACY] FAIL: " + e)
	quit(0 if _errors.is_empty() else 1)
