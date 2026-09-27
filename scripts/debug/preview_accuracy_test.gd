# Headless regression: the damage preview must not LIE about the coming round.
# Heroes resolve before the enemy phase, so an honest forecast has to walk the
# hero phase first. Three lies are pinned here (all reported 2026-09-02):
#   1. LETHAL — an enemy the assignment will kill still telegraphed its damage
#      onto a hero bar, though it never gets to act.
#   2. TAUNT  — a taunt redirects the enemy's attack at resolve time; the
#      preview kept showing the original target.
#   3. LEECH  — leech healing never reached the projection, so the net HP
#      change was wrong even when the damage figure was right.
#   4. EXACT (UI batch 2026-09-27, B1): the enemy preview must equal the damage
#      that RESOLVES. Detonate (finite, permanent, lethal), a burn tick,
#      execute, chain, mark, breach, pierce, spike retaliation, a relic
#      multiplier and an Overload Loop echo each get a case: every card's
#      projected HP is compared with its HP after a real resolve_step, and the
#      hero readout's Detonate number with the burst that actually lands.
# Run: godot --headless --path . -s scripts/debug/preview_accuracy_test.gd
# FAIL-ON-OLD: pre-forecast battle_card_view fails cases 1, 2 and 3; the
# hand-modelled forecast before B1 fails the EXACT cases.
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SQUAD := ["combat", "engineer", "medic"]
# EXACT cases (B1): Pulse (chain, burn, detonate), Strike (pierce, execute),
# Ghost (breach, pierce).
const EXACT_SQUAD := ["pulse", "combat", "ghost"]

var _errors: PackedStringArray = []
var _dm: Object
var _cm: Object
var _card_view: Object
var _hero_rolls: Dictionary
var _enemy_rolls: Dictionary
var _exact_checked: int = 0


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
		# Wounded, so the heal is not capped at max HP: since B1 the preview
		# shows the heal that lands, and a full-HP leecher really heals 0.
		leecher["current_hp"] = maxi(int(leecher["max_hp"]) - 30, 1)
		var leech_dmg: int = int(_ability_raw(leecher, leech_roll).get("dmg", 0))
		var want_heal: int = int(floor(float(leech_dmg) * 0.5))
		var healed: int = int(_preview(leecher, true).get("heal", 0))
		_expect(want_heal > 0 and healed >= want_heal,
			"leech: the attacker's self-heal shows on its own bar (heal=%d, want>=%d from %d dmg)" % [healed, want_heal, leech_dmg])

	await _run_exact_cases()
	_finish()


# ── EXACT (B1): preview == resolved damage ─────────────────────────────────────
func _run_exact_cases() -> void:
	var gs: Node = root.get_node("/root/GameState")
	var dmgr: Node = root.get_node("/root/DataManager")
	var old_scene: Node = current_scene
	gs.call("start_run", EXACT_SQUAD, str(dmgr.call("get_operation_order")[0]))
	gs.call("advance_to_next_battle")
	change_scene_to_file(BATTLE_SCENE)
	var retries := 240
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene != old_scene and current_scene.scene_file_path == BATTLE_SCENE:
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
	current_scene.set("turn_phase", int(current_scene.get("PHASE_TARGETING")))
	(current_scene.get("pending_manual_target_ids") as Array).clear()

	var heroes: Array = _living(_cm.call("get_hero_states"))
	var enemies: Array = _living(_cm.call("get_enemy_states"))
	if heroes.size() < 3 or enemies.size() < 2:
		_errors.append("exact: need Pulse, Strike and Ghost and 2 living enemies (got %d heroes, %d enemies)" % [heroes.size(), enemies.size()])
		return
	var base: Dictionary = _cm.call("snapshot_state")

	# [name, hero unit id ("" = nobody attacks), roll, board setup, relic effects]
	var cases: Array = [
		["detonate, finite burn is consumed", "pulse", 16, _setup_burn.bind(3, 3, false, 0), []],
		["detonate, permanent burn keeps ticking", "pulse", 16, _setup_burn.bind(3, 9999, true, 0), []],
		["detonate is lethal where the base hit is not", "pulse", 16, _setup_burn.bind(4, 3, false, 20), []],
		["burn tick with no hit", "", 0, _setup_burn.bind(5, 2, false, 0), []],
		["execute", "combat", 20, _setup_execute, []],
		["chain", "pulse", 1, _setup_none, []],
		["mark", "ghost", 14, _setup_mark, []],
		["breach", "ghost", 9, _setup_shield, []],
		["pierce", "combat", 16, _setup_shield, []],
		["spike retaliation", "ghost", 14, _setup_spike, []],
		["relic multiplier", "ghost", 14, _setup_none, [{"type": "heroDmgMult", "mult": 1.1}]],
		["Overload Loop echo", "pulse", 20, _setup_none, [{"type": "critResolveTwice"}]],
	]
	for case_variant in cases:
		var case: Array = case_variant
		_cm.call("restore_state", base)
		var live_enemies: Array = _living(_cm.call("get_enemy_states"))
		for state_variant in _cm.call("get_hero_states") + _cm.call("get_enemy_states"):
			var st: Dictionary = state_variant
			if not bool(st.get("dead", false)):
				st["max_hp"] = maxi(int(st["max_hp"]), 60)
				st["current_hp"] = int(st["max_hp"])
			st["selected_target_id"] = ""
			st["lured_by_id"] = ""
		(case[3] as Callable).call(live_enemies[0])
		_cm.set("_active_relic_effects", (case[4] as Array).duplicate(true))
		var hero_rolls: Dictionary = current_scene.get("hero_rolls")
		var enemy_rolls: Dictionary = current_scene.get("enemy_rolls")
		hero_rolls.clear()
		enemy_rolls.clear()
		var bs: Object = current_scene.get("_state")
		(bs.get("hero_roll_nudges") as Dictionary).clear()
		(bs.get("hero_roll_sets") as Dictionary).clear()
		var actor_id: String = ""
		if str(case[1]) != "":
			var actor: Dictionary = _find_by_unit(_cm.call("get_hero_states"), str(case[1]))
			actor_id = str(actor["id"])
			hero_rolls[actor_id] = int(case[2])
			actor["selected_target_id"] = str(live_enemies[0]["id"])
		else:
			# A hero must have a revealed roll for the preview to run at all;
			# park one on an ability that touches nobody.
			var idle: Dictionary = _find_by_unit(_cm.call("get_hero_states"), "combat")
			hero_rolls[str(idle["id"])] = _find_roll(idle, "nondmg")
		_check_exact(str(case[0]), actor_id)
		_exact_checked += 1
	# A script error inside a case aborts it without failing any _expect, so
	# the count is the proof every case actually ran to its checks.
	_expect(_exact_checked == cases.size(),
		"exact: all %d cases ran to their checks (ran %d)" % [cases.size(), _exact_checked])
	_cm.call("restore_state", base)
	_cm.set("_active_relic_effects", [])


func _setup_none(_e0: Dictionary) -> void:
	pass


func _setup_burn(e0: Dictionary, amt: int, turns: int, perm: bool, hp: int) -> void:
	e0["burn_stacks"] = [{"amt": amt, "turns_left": turns, "perm": perm}]
	e0["burn"] = amt
	e0["burn_turns"] = turns
	if hp > 0:
		e0["current_hp"] = hp


func _setup_execute(e0: Dictionary) -> void:
	e0["max_hp"] = 100
	e0["current_hp"] = 40


func _setup_mark(e0: Dictionary) -> void:
	e0["marked"] = true


func _setup_shield(e0: Dictionary) -> void:
	e0["shield_stacks"] = [{"amt": 10, "skip_next_tick": false}]
	e0["shield"] = 10


func _setup_spike(e0: Dictionary) -> void:
	e0["spike"] = 4


func _check_exact(label: String, actor_id: String) -> void:
	var hero_ids: Dictionary = {}
	for state_variant in _cm.call("get_hero_states"):
		hero_ids[str((state_variant as Dictionary)["id"])] = true
	var before: Dictionary = {}
	var predicted: Dictionary = {}
	for state_variant in _cm.call("get_hero_states") + _cm.call("get_enemy_states"):
		var st: Dictionary = state_variant
		if bool(st.get("dead", false)):
			continue
		before[str(st["id"])] = int(st["current_hp"])
		predicted[str(st["id"])] = _projected_hp(st, _preview(st, hero_ids.has(str(st["id"]))))
	# The hero readout's Detonate pip, through the same patch the card uses.
	var readout_burst: int = -1
	if actor_id != "":
		var actor: Dictionary = {}
		for state_variant in _cm.call("get_hero_states"):
			if str((state_variant as Dictionary)["id"]) == actor_id:
				actor = state_variant
		var entry: Dictionary = _dm.call("get_ability_for_roll", actor["unit"],
			int(current_scene.call("_get_effective_roll_for_state", actor, actor_id)))
		var pips: Dictionary = {"effects": [{"kind": "detonate", "value": "DT"}]}
		_card_view.call("_patch_live_detonate_value", pips, actor, entry)
		var shown: PackedStringArray = str((pips["effects"][0] as Dictionary)["value"]).split(" ")
		readout_burst = int(shown[1]) if shown.size() > 1 else 0

	var engine: Object = current_scene.get("_engine")
	var step: Dictionary = engine.call("resolve_step", current_scene.get("_state"))
	var events: Array = (step["result"] as Dictionary).get("events", [])
	var actual_burst: int = 0
	for event_variant in events:
		if str((event_variant as Dictionary).get("type", "")) == "detonate":
			actual_burst += int((event_variant as Dictionary).get("amount", 0))
	var mismatches: PackedStringArray = []
	for state_variant in _cm.call("get_hero_states") + _cm.call("get_enemy_states"):
		var st: Dictionary = state_variant
		var sid: String = str(st["id"])
		if not predicted.has(sid):
			continue
		var actual: int = 0 if bool(st.get("dead", false)) else int(st["current_hp"])
		if actual != int(predicted[sid]):
			mismatches.append("%s %d->%d, predicted %d" % [sid, int(before[sid]), actual, int(predicted[sid])])
	_expect(mismatches.is_empty(),
		"exact [%s]: every card's projected HP equals the resolved HP (%s)" % [label, "all equal" if mismatches.is_empty() else ", ".join(mismatches)])
	if label.begins_with("detonate"):
		_expect(readout_burst == actual_burst and actual_burst > 0,
			"exact [%s]: the readout's Detonate number equals the burst that lands (readout %d, landed %d)" % [label, readout_burst, actual_burst])


# The card's HP projection (compact_unit_card._layout_preview_overlays) as its
# endpoint: heal, then the hit (the exact HP loss when the preview carries it),
# then the burn tick through whatever shield is left. Lethal reads as 0.
func _projected_hp(state: Dictionary, preview: Dictionary) -> int:
	var cur_hp: int = int(state["current_hp"])
	if preview.is_empty():
		return cur_hp
	if bool(preview.get("lethal", false)):
		return 0
	var hp_max: int = int(state["max_hp"])
	var post_heal: int = mini(cur_hp + int(preview.get("heal", 0)), hp_max)
	var total_shield: int = int(preview.get("current_shield", 0)) + int(preview.get("shield", 0))
	var inc_dmg: int = int(preview.get("damage", 0))
	var absorbed: int = mini(inc_dmg, total_shield)
	var hp_dmg: int = inc_dmg - absorbed
	var shield_after: int = total_shield - absorbed
	if preview.has("hp_loss"):
		hp_dmg = int(preview["hp_loss"])
		shield_after = int(preview.get("shield_after", 0)) + int(preview.get("shield", 0))
	var burn: int = int(preview.get("burn", 0))
	var hp_burn: int = burn - mini(burn, shield_after)
	return clampi(post_heal - hp_dmg - hp_burn, 0, hp_max)


func _find_by_unit(states: Array, unit_id: String) -> Dictionary:
	for state_variant in states:
		if str((state_variant as Dictionary)["unit"].id) == unit_id:
			return state_variant
	return {}


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
