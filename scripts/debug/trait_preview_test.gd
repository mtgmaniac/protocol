# Trait preview gate (G-65, Kev 2026-10-09).
#
#   godot --headless --path . -s scripts/debug/trait_preview_test.gd [-- --preview-break=trait_blind]
#
# The HP bar on a battle card previews where the unit ends the round. Until
# G-65 a hero's bar ran the real hero phase and then summed each enemy's
# printed damage, so no trait that acts in the enemy phase or at the tick was
# in it (Anchored's cut, Feral's rampage, Volatile on a late death, Vengeful's
# spike on the attacker's own bar). The preview now dry-runs the whole round
# with the real combat code (CombatManager.forecast_round).
#
# Pinned here, one case per trait that can move a previewed number, each on a
# real battle screen with fixture kits:
#   exact      every card's previewed end-of-round HP equals its HP after the
#              round really resolves, and the bar the card draws ends there.
#   sensitive  the same preview made blind to traits gets the case's watched
#              unit WRONG. A case that passes blind proves nothing, so it fails.
#   untouched  the dry run leaves the live battle exactly as it was.
# The traits that move no number this round (they change a cloak or how long
# something lasts) are listed with the reason, and checked the other way: the
# blind preview must agree.
# Rampage and the pack bonus are not traits; the old preview missed them for
# the same reason, so each has a case.
# scripts/checks/break_gate.py reruns it with each CombatManager
# PREVIEW_BREAK_ARG mode (trait_blind, hero_phase_only) and requires a FAIL.
extends SceneTree

const COMBAT_SOURCE := "res://scripts/battle/combat_manager.gd"
const TRAITS_SOURCE := "res://scripts/battle/unit_traits.gd"
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SQUAD := ["combat", "engineer", "medic"]
const ENEMIES := ["Scrap Drone", "Scrap Drone", "Scrap Drone"]
const QUIET := {"shield": 0}

var _errors: PackedStringArray = []
var _traits: Object
var _scene: Node
var _cm: Object
var _bs: Object
var _base: Dictionary
var _cases_run: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_errors.append(what)


func _run() -> void:
	await process_frame
	root.get_node("/root/AudioManager").set_suppressed(true)
	var sm: Node = root.get_node("/root/SaveManager")
	sm.set_setting("ability_primers_enabled", false)
	_traits = load(TRAITS_SOURCE)
	var gs: Node = root.get_node("/root/GameState")
	sm.clear_run_save()
	gs.reset_run()
	gs.start_run(SQUAD, "facility", 41)
	gs.advance_to_next_battle()
	gs.resolved_battle_comps[0] = {"names": ENEMIES, "cloaked": []}
	change_scene_to_file(BATTLE_SCENE)
	for _i in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE and current_scene.is_node_ready():
			break
	await create_timer(0.8).timeout
	_scene = current_scene
	if _scene == null or _scene.scene_file_path != BATTLE_SCENE:
		_errors.append("the battle scene did not load")
		_finish()
		return
	var roll_button: Button = _scene.get_node_or_null("%RollButton") as Button
	if roll_button != null and roll_button.visible and not roll_button.disabled:
		roll_button.emit_signal("pressed")
		await _scene.dice_tray_3d.roll_finished
	await create_timer(0.4).timeout
	_cm = _scene.combat_manager
	_bs = _scene._state
	_scene.turn_phase = _scene.PHASE_TARGETING
	_scene.pending_manual_target_ids.clear()
	if _cm.get_hero_states().size() != 3 or _cm.get_enemy_states().size() != 3:
		_errors.append("fixture: 3 heroes and 3 enemies (%d, %d)" % [_cm.get_hero_states().size(), _cm.get_enemy_states().size()])
		_finish()
		return
	_base = _cm.snapshot_state()

	_check_moving_traits()
	_check_prestige_traits()
	_check_round_start_traits()
	_check_still_traits()
	_check_rampage_and_pack()
	await _check_card_draws()
	_expect(_cases_run >= 40, "every case ran to its checks (%d)" % _cases_run)
	_finish()


func _finish() -> void:
	for error in _errors:
		print("[TRAIT_PREVIEW] FAIL - %s" % error)
	print("[TRAIT_PREVIEW] %s" % ("PASS (%d cases)" % _cases_run if _errors.is_empty() else "FAIL - %d check(s)" % _errors.size()))
	root.get_node("/root/SaveManager").clear_run_save()
	quit(0 if _errors.is_empty() else 1)


# ── Fixtures ──────────────────────────────────────────────────────────────────
func _band(lo: int, hi: int, ability_name: String, raw: Dictionary) -> Dictionary:
	return {"min": lo, "max": hi, "zone": "band%d" % lo, "ability_name": ability_name, "description": "", "raw": raw.duplicate(true)}


# One ability on every roll.
func _kit(raw: Dictionary) -> Array[Dictionary]:
	var bands: Array[Dictionary] = []
	bands.append(_band(1, 20, "Test Move", raw))
	return bands


# Two abilities: `low` on 1-10, `high` on 11-20.
func _split_kit(low: Dictionary, high: Dictionary) -> Array[Dictionary]:
	var bands: Array[Dictionary] = []
	bands.append(_band(1, 10, "Low Move", low))
	bands.append(_band(11, 20, "High Move", high))
	return bands


func _h(index: int) -> Dictionary:
	return _cm.get_hero_states()[index]


func _e(index: int) -> Dictionary:
	return _cm.get_enemy_states()[index]


# A clean board: every unit at 100 of 100 HP on a kit that does nothing, no
# trait, no status, no roll, no target.
func _reset() -> void:
	_cm.restore_state(_base)
	_cm.forecast_blind_to_traits = false
	_bs.hero_rolls.clear()
	_bs.enemy_rolls.clear()
	_bs.hero_roll_nudges.clear()
	_bs.hero_roll_sets.clear()
	_bs.enemy_roll_nudges.clear()
	_bs.enemy_roll_shifts.clear()
	_bs.protocol_points = 0
	for index in 3:
		_hero(index, QUIET)
		_enemy(index, QUIET)


func _wipe(state: Dictionary) -> void:
	state["max_hp"] = 100
	state["current_hp"] = 100
	state["dead"] = false
	state["selected_target_id"] = ""
	state["lured_by_id"] = ""
	state["shield"] = 0
	state["shield_stacks"] = []
	state["burn"] = 0
	state["burn_turns"] = 0
	state["burn_stacks"] = []
	state["cast_stamp"] = 0


# Hero `index` gets a kit (one ability on every roll), a trait and a roll.
func _hero(index: int, raw: Dictionary, trait_id: String = "", target: Dictionary = {}) -> Dictionary:
	var state: Dictionary = _h(index)
	var unit: UnitData = UnitData.new()
	unit.id = str(state["id"])
	unit.display_name = "Hero %d" % index
	unit.max_hp = 100
	unit.dice_ranges = _kit(raw)
	unit.unit_trait = _traits.build(trait_id, unit.dice_ranges)
	_wipe(state)
	state["unit"] = unit
	state["trait"] = trait_id
	_bs.hero_rolls[str(state["id"])] = 5
	if not target.is_empty():
		state["selected_target_id"] = str(target["id"])
	return state


# Enemy `index` likewise. `kind` is its type: two of one kind are a pack.
func _enemy(index: int, raw: Dictionary, trait_id: String = "", target: Dictionary = {}, kind: String = "") -> Dictionary:
	var state: Dictionary = _e(index)
	var unit: EnemyData = EnemyData.new()
	unit.id = "fixture%d" % index
	unit.display_name = "Enemy %d" % index
	unit.enemy_type = kind if kind != "" else "fixture%d" % index
	unit.max_hp = 100
	unit.dice_ranges = _kit(raw)
	unit.unit_trait = _traits.build(trait_id, unit.dice_ranges)
	_wipe(state)
	state["unit"] = unit
	state["trait"] = trait_id
	state["accrete"] = 0
	state["rampage_charges"] = 0
	_bs.enemy_rolls[str(state["id"])] = 5
	if not target.is_empty():
		state["selected_target_id"] = str(target["id"])
	return state


func _num(trait_id: String, key: String) -> int:
	return int(((_traits.data()["traits"] as Dictionary)[trait_id] as Dictionary).get(key, 0))


func _name(trait_id: String) -> String:
	return str(_traits.name_of(trait_id))


func _shield(state: Dictionary, amount: int) -> void:
	state["shield_stacks"] = [{"amt": amount, "skip_next_tick": false}]
	state["shield"] = amount


# A burn already ticking (an applied burn sits out the round it lands in).
func _burn(state: Dictionary, amount: int, pierce: bool = false) -> void:
	state["burn_stacks"] = [{"amt": amount, "turns_left": 3, "perm": false, "pierce": pierce}]
	state["burn"] = amount
	state["burn_turns"] = 3


# ── The comparison ────────────────────────────────────────────────────────────
# Where each living unit's card says it ends the round: {state_id: hp}.
func _previewed() -> Dictionary:
	var out: Dictionary = {}
	for state in _cm.get_hero_states() + _cm.get_enemy_states():
		if bool(state["dead"]):
			continue
		var preview: Dictionary = _scene._card_view.compute_preview_for_unit(state, _cm.get_hero_states().has(state))
		out[str(state["id"])] = int(preview.get("final_hp", int(state["current_hp"])))
	return out


func _fingerprint() -> String:
	return str(_cm.get_hero_states()) + str(_cm.get_enemy_states()) + str(_cm.roll_provider.get_stream_states() if _cm.roll_provider != null and _cm.roll_provider.has_method("get_stream_states") else "")


# One case: the board is set; `watch` is the unit whose previewed HP the trait
# moves and `want` the HP it must end on. `moves` false: a trait that changes
# no number this round, so the blind preview must agree.
func _case(label: String, watch: Dictionary, want: int, moves: bool = true) -> void:
	var watch_id: String = str(watch["id"])
	var before: String = _fingerprint()
	var seen: Dictionary = _previewed()
	_cm.forecast_blind_to_traits = true
	var blind: Dictionary = _previewed()
	_cm.forecast_blind_to_traits = false
	_expect(_fingerprint() == before, "%s: the dry run leaves the live battle untouched" % label)

	_scene._engine.resolve_step(_bs)
	var wrong: PackedStringArray = []
	for state in _cm.get_hero_states() + _cm.get_enemy_states():
		var state_id: String = str(state["id"])
		if not seen.has(state_id):
			continue
		var actual: int = 0 if bool(state["dead"]) else int(state["current_hp"])
		if actual != int(seen[state_id]):
			wrong.append("%s previewed %d, ended on %d" % [str(state["unit"].display_name), int(seen[state_id]), actual])
	_expect(wrong.is_empty(), "%s: every card's previewed HP is the HP the round leaves (%s)" % [label, ", ".join(wrong)])
	var landed: int = 0 if bool(watch["dead"]) else int(watch["current_hp"])
	_expect(landed == want, "%s: %s ends the round on %d (%d)" % [label, str(watch["unit"].display_name), want, landed])
	if moves:
		_expect(int(blind.get(watch_id, -1)) != landed, "%s: a preview blind to traits gets %s wrong, so the case depends on the trait (blind %d, real %d)" % [label, str(watch["unit"].display_name), int(blind.get(watch_id, -1)), landed])
	else:
		_expect(int(blind.get(watch_id, -1)) == landed, "%s: this trait moves no HP this round, so a blind preview agrees (blind %d, real %d)" % [label, int(blind.get(watch_id, -1)), landed])
	_cases_run += 1


# ── Traits that move a previewed number ───────────────────────────────────────
func _check_moving_traits() -> void:
	var a: Dictionary
	var b: Dictionary
	var x: Dictionary
	var y: Dictionary

	# Anchored: the taunter takes less from the hit it pulls. (Hero card.)
	_reset()
	x = _enemy(0, {"dmg": 10}, "", _h(1))
	a = _hero(0, {"taunt": true}, "anchor", x)
	_case(_name("anchor"), a, 100 - (10 - _num("anchor", "amount")))

	# Vengeful: the enemy that hits the taunter takes spike damage. (Enemy card.)
	_reset()
	x = _enemy(0, {"dmg": 10}, "", _h(1))
	a = _hero(0, {"taunt": true}, "retaliate", x)
	_case(_name("retaliate"), x, 100 - _num("retaliate", "amount"))

	# Barbed: the hero that hits it takes damage. (Hero card, hero phase.)
	_reset()
	x = _enemy(0, QUIET, "barbed")
	a = _hero(0, {"dmg": 5}, "", x)
	_case(_name("barbed"), a, 100 - _num("barbed", "amount"))

	# Volatile, killed by a hero: every hero takes the death damage.
	_reset()
	x = _enemy(0, QUIET, "discharge")
	x["current_hp"] = 10
	a = _hero(0, {"dmg": 50}, "", x)
	_case("%s, killed in the hero phase" % _name("discharge"), _h(2), 100 - _num("discharge", "amount"))

	# Volatile, killed in the enemy phase by the spike it runs into.
	_reset()
	x = _enemy(0, {"dmg": 6}, "discharge", _h(0))
	x["current_hp"] = 5
	_h(0)["spike"] = 20
	_case("%s, killed by a spike in the enemy phase" % _name("discharge"), _h(2), 100 - _num("discharge", "amount"))

	# Volatile, killed by the end-of-round burn tick.
	_reset()
	x = _enemy(0, QUIET, "discharge")
	x["current_hp"] = 3
	_burn(x, 5)
	_case("%s, killed by the burn tick" % _name("discharge"), _h(2), 100 - _num("discharge", "amount"))

	# Feral: a packmate dies in the hero phase, so its attack this round is doubled.
	_reset()
	x = _enemy(0, {"dmg": 6}, "packRage", _h(1))
	y = _enemy(1, QUIET)
	y["current_hp"] = 10
	a = _hero(0, {"dmg": 50}, "", y)
	_case(_name("packRage"), _h(1), 100 - 12)

	# Illusory: the first hit on it is negated. (Enemy card.)
	_reset()
	x = _enemy(0, QUIET, "decoy")
	a = _hero(0, {"dmg": 10}, "", x)
	_case(_name("decoy"), x, 100)

	# Redline: a flat bonus while enough Protocol is held. (Enemy card.)
	_reset()
	x = _enemy(0, QUIET)
	a = _hero(0, {"dmg": 10}, "redline", x)
	_bs.protocol_points = _num("redline", "protocol")
	_case(_name("redline"), x, 100 - 10 - _num("redline", "amount"))

	# Ruthless: its area attacks hit a marked enemy harder. (Enemy card.)
	_reset()
	x = _enemy(0, QUIET)
	x["marked"] = true
	a = _hero(0, {"dmg": 6, "blastAll": true}, "exposed")
	_case(_name("exposed"), x, 100 - int(ceil((6 + _num("exposed", "amount")) * 1.5)))

	# Charged: each chain jump deals more. (Enemy card.)
	_reset()
	x = _enemy(0, QUIET)
	y = _enemy(1, QUIET)
	a = _hero(0, {"dmg": 10, "chain": 1}, "liveWire", x)
	_case(_name("liveWire"), y, 100 - 5 - _num("liveWire", "amount"))

	# Zero-Day: an enemy it rewrites takes more from the next hero's hit.
	_reset()
	x = _enemy(0, QUIET)
	a = _hero(0, {"dmg": 5, "rewrite": true}, "zeroDay", x)
	b = _hero(1, {"dmg": 10}, "", x)
	_case(_name("zeroDay"), x, 100 - 15 - _num("zeroDay", "amount"))

	# Bloodlust: the armed leech heals more. (Hero card.)
	_reset()
	x = _enemy(0, QUIET)
	a = _hero(0, {"dmg": 20, "leech": true}, "bloodlust", x)
	a["current_hp"] = 40
	a["bloodlust_ready"] = true
	_case(_name("bloodlust"), a, 40 + int(floor(20 * 0.5 * (1.0 + _num("bloodlust", "pct") / 100.0))))

	# Watchful: its heal restores more on the lowest-HP ally. (Hero card.)
	_reset()
	b = _h(1)
	b["current_hp"] = 30
	a = _hero(0, {"heal": 6, "healTgt": true}, "triage", b)
	_case(_name("triage"), b, 30 + 6 + _num("triage", "amount"))

	# Overflowing: healing past full HP becomes shield, which eats the hit that follows.
	_reset()
	b = _h(1)
	b["current_hp"] = 96
	a = _hero(0, {"heal": 10, "healTgt": true}, "overflow", b)
	x = _enemy(0, {"dmg": 10}, "", b)
	_case(_name("overflow"), b, 100 - (10 - 6))

	# Relentless: its kill marks the lowest-HP enemy left, and the next hero's hit lands +50%.
	_reset()
	x = _enemy(0, QUIET)
	x["current_hp"] = 10
	y = _enemy(1, QUIET)
	y["current_hp"] = 50
	a = _hero(0, {"dmg": 50}, "cleanKill", x)
	b = _hero(1, {"dmg": 10}, "", y)
	_case(_name("cleanKill"), y, 50 - 15)

	# Vigilant: it gains shield when an ally is hit, and that shield eats the next hit on it.
	_reset()
	x = _enemy(0, QUIET, "backup")
	y = _enemy(1, QUIET)
	a = _hero(0, {"dmg": 5}, "", y)
	b = _hero(1, {"dmg": 10}, "", x)
	_case(_name("backup"), x, 100 - (10 - _num("backup", "amount")))

	# Corrosive: its burn ticks through a shield. (Hero card, the tick.)
	_reset()
	a = _h(0)
	_shield(a, 10)
	_burn(a, 3, true)
	_case(_name("corrosive"), a, 100 - 3)

	# Fervent: it heals when any burn ticks. (Enemy card, the tick.)
	_reset()
	x = _enemy(0, QUIET, "kindle")
	x["current_hp"] = 50
	_burn(_h(0), 2)
	_case(_name("kindle"), x, 50 + _num("kindle", "amount"))

	# Smoldering: the burn a detonation leaves does not tick the round it lands.
	_reset()
	x = _enemy(0, QUIET)
	_burn(x, 3)
	a = _hero(0, {"dmg": 5, "detonate": true}, "afterburn", x)
	var detonated: int = int(_cm.get_expected_detonate_burst(a, x))
	_case(_name("afterburn"), x, 100 - 5 - detonated, false)


# ── The sixteen traits that were Directives (G-71) ───────────────────────────
# Twelve move a previewed number in the round they act; each must go wrong
# when the dry run is blind to traits. Capacitive and Siphoning move Protocol,
# not HP, and Vanishing's cloak changes nothing until the next round. Reviving
# moves the HP a fallen hero returns with.
func _check_prestige_traits() -> void:
	var a: Dictionary
	var b: Dictionary
	var x: Dictionary
	var y: Dictionary
	var z: Dictionary

	# Searing: the burn it applies ticks once as it lands. (Enemy card.)
	_reset()
	x = _enemy(0, QUIET)
	a = _hero(0, {"dmg": 5, "burn": 3, "burnT": 2}, "flashpoint", x)
	_case(_name("flashpoint"), x, 100 - 5 - 3)

	# Forking: the chain reaches one more enemy. (That enemy's card.)
	_reset()
	x = _enemy(0, QUIET)
	y = _enemy(1, QUIET)
	z = _enemy(2, QUIET)
	a = _hero(0, {"dmg": 10, "chain": 1}, "conductor", x)
	_case(_name("conductor"), z, 100 - 5)

	# Serrated: its pierce attack breaches, so the next hero's hit meets no shield.
	_reset()
	x = _enemy(0, QUIET)
	_shield(x, 8)
	a = _hero(0, {"dmg": 10, "ignSh": true}, "serrated", x)
	b = _hero(1, {"dmg": 6}, "", x)
	_case(_name("serrated"), x, 100 - 10 - 6)

	# Scalding: more damage to a burning enemy. (The burn's own tick is 2.)
	_reset()
	x = _enemy(0, QUIET)
	_burn(x, 2)
	a = _hero(0, {"dmg": 10}, "thermalTrauma", x)
	_case(_name("thermalTrauma"), x, 100 - 10 - _num("thermalTrauma", "amount") - 2)

	# Fortified: the larger shield it grants eats more of the hit. (Hero card.)
	_reset()
	x = _enemy(0, {"dmg": 10}, "", _h(1))
	a = _hero(0, {"shield": 6, "shieldAll": true}, "rampart")
	_case(_name("rampart"), _h(1), 100 - (10 - 6 - _num("rampart", "amount")))

	# Bristling: the larger spike hurts the enemy that hits it. (Enemy card.)
	_reset()
	x = _enemy(0, {"dmg": 10}, "", _h(0))
	a = _hero(0, {"spike": 5}, "counterweight")
	_case(_name("counterweight"), x, 100 - 5 - _num("counterweight", "amount"))

	# Shattering: more damage to an enemy whose die is frozen.
	_reset()
	x = _enemy(0, QUIET)
	x["die_freeze_turns"] = 1
	a = _hero(0, {"dmg": 10}, "shatterpoint", x)
	_case(_name("shatterpoint"), x, 100 - 10 - _num("shatterpoint", "amount"))

	# Sheltering: the heal's shield eats part of the hit that follows. (Hero card.)
	_reset()
	x = _enemy(0, {"dmg": 10}, "", _h(1))
	_h(1)["current_hp"] = 50
	a = _hero(0, {"heal": 6, "healTgt": true}, "fieldTriage", _h(1))
	_case(_name("fieldTriage"), _h(1), 50 + 6 - (10 - _num("fieldTriage", "amount")))

	# Reinforcing: a squadmate's own shield is larger while this hero lives.
	_reset()
	x = _enemy(0, {"dmg": 10}, "", _h(1))
	a = _hero(0, QUIET, "reinforcedMesh")
	b = _hero(1, {"shield": 6})
	_case(_name("reinforcedMesh"), b, 100 - (10 - 6 - _num("reinforcedMesh", "amount")))

	# Shrouded: it cloaks in the hero phase, so the enemy aiming at it hits
	# someone else. (Its own card, and the card of whoever is hit instead.)
	_reset()
	x = _enemy(0, {"dmg": 10}, "", _h(0))
	a = _hero(0, {"shield": 4}, "silentRunning")
	_case(_name("silentRunning"), a, 100)

	# Vanishing cloaks it when a hit leaves it below half. Enemy targets are
	# set before the enemy phase, so a second enemy already aiming at it still
	# hits this round: the cloak moves no HP until the next one.
	_reset()
	x = _enemy(0, {"dmg": 60}, "", _h(0))
	y = _enemy(1, {"dmg": 10}, "", _h(0))
	a = _hero(0, QUIET, "vanish")
	_case(_name("vanish"), a, 100 - 60 - 10, false)

	# Reaping: the execute triggers at 32 of 100 HP, above the plain 25%.
	_reset()
	x = _enemy(0, QUIET)
	x["current_hp"] = 42
	a = _hero(0, {"dmg": 10, "execute": true}, "reaper", x)
	_case(_name("reaper"), x, 42 - 10 - int(_cm._tuned_int("execute_bonus", 8)))

	# Shrieking: the enemy under its roll penalty takes damage at the tick.
	_reset()
	x = _enemy(0, QUIET)
	a = _hero(0, {"rfe": 2, "rfT": 2}, "feedback", x)
	_case(_name("feedback"), x, 100 - _num("feedback", "amount"))

	# Capacitive raises the Protocol cap. Its hit is the same either way.
	_reset()
	x = _enemy(0, QUIET)
	a = _hero(0, {"dmg": 5}, "deepCells", x)
	_case(_name("deepCells"), x, 100 - 5, false)

	# Siphoning gains Protocol. Its hit is the same either way.
	_reset()
	x = _enemy(0, QUIET)
	a = _hero(0, {"dmg": 5, "rfe": 1, "rfT": 2}, "signalTheft", x)
	_case(_name("signalTheft"), x, 100 - 5, false)

	# Reviving: the fallen hero returns at the trait's percentage. A card
	# previews a living unit, so this one is read off the dry run itself: the
	# forecast the cards are drawn from must hold the HP the hero returns with,
	# and a forecast blind to traits must hold the plain 50.
	_reset()
	b = _h(1)
	b["dead"] = true
	b["current_hp"] = 0
	a = _hero(0, {"revive": true, "healTgt": true, "revivePct": 50, "fallbackHeal": 20}, "fieldSurgeon", b)
	var before: String = _fingerprint()
	var seen_hp: int = _forecast_hp(b)
	_cm.forecast_blind_to_traits = true
	var blind_hp: int = _forecast_hp(b)
	_cm.forecast_blind_to_traits = false
	_expect(_fingerprint() == before, "%s: the dry run leaves the live battle untouched" % _name("fieldSurgeon"))
	_scene._engine.resolve_step(_bs)
	_expect(not bool(b["dead"]) and int(b["current_hp"]) == _num("fieldSurgeon", "pct"), "%s: the hero returns at %d of 100 HP (%d)" % [_name("fieldSurgeon"), _num("fieldSurgeon", "pct"), int(b["current_hp"])])
	_expect(seen_hp == int(b["current_hp"]), "%s: the dry run holds the HP the hero returns with (forecast %d, real %d)" % [_name("fieldSurgeon"), seen_hp, int(b["current_hp"])])
	_expect(blind_hp == 50, "%s: a dry run blind to traits holds the plain 50, so the case depends on the trait (%d)" % [_name("fieldSurgeon"), blind_hp])
	_cases_run += 1


# The HP the card of `state` previews for the end of the round (-1 for none).
func _forecast_hp(state: Dictionary) -> int:
	return int(_scene._card_view.compute_preview_for_unit(state, true).get("final_hp", -1))


# ── The round-start traits: already on the board when the preview is made ─────
func _check_round_start_traits() -> void:
	var a: Dictionary
	var x: Dictionary

	# Static: the die it dropped picks the lower ability, and the preview reads the dropped value.
	_reset()
	a = _hero(0, QUIET, "static")
	x = _enemy(0, QUIET, "", _h(1))
	x["unit"].dice_ranges = _split_kit({"dmg": 3}, {"dmg": 30})
	_bs.enemy_rolls[str(x["id"])] = 11
	var fired: Array = _scene._engine.apply_round_start_traits(_bs)
	_expect(fired.size() == 1, "%s: fixture, the trait fired at round start (%d)" % [_name("static"), fired.size()])
	_case(_name("static"), _h(1), 100 - 3, false)

	# Zealous: the die it raised picks the higher ability.
	_reset()
	x = _enemy(0, QUIET, "litany", _h(1))
	x["unit"].dice_ranges = _split_kit({"dmg": 3}, {"dmg": 30})
	_bs.enemy_rolls[str(x["id"])] = 9
	_bs.enemy_rolls[str(_e(1)["id"])] = 15
	_bs.enemy_rolls[str(_e(2)["id"])] = 15
	fired = _scene._engine.apply_round_start_traits(_bs)
	_expect(fired.size() == 1, "%s: fixture, the trait fired at round start (%d)" % [_name("litany"), fired.size()])
	_case(_name("litany"), _h(1), 100 - 30, false)

	# Entrenched: the shield it gained below half HP eats part of the hit.
	_reset()
	a = _hero(0, QUIET, "dugIn")
	a["current_hp"] = 40
	x = _enemy(0, {"dmg": 10}, "", a)
	_scene._engine.apply_round_start_traits(_bs)
	_case(_name("dugIn"), a, 40 - (10 - _num("dugIn", "amount")), false)

	# Glacial: the shield it gained for a frozen enemy eats part of the hit.
	_reset()
	a = _hero(0, QUIET, "glacialArmor")
	x = _enemy(0, {"dmg": 10}, "", a)
	_e(1)["die_freeze_turns"] = 1
	_scene._engine.apply_round_start_traits(_bs)
	_case(_name("glacialArmor"), a, 100 - (10 - _num("glacialArmor", "amount")), false)


# ── Traits that move no HP this round ─────────────────────────────────────────
func _check_still_traits() -> void:
	var a: Dictionary
	var x: Dictionary

	# Silent keeps a cloak after a kill. The kill itself is the same either way.
	_reset()
	x = _enemy(0, QUIET)
	x["current_hp"] = 10
	a = _hero(0, {"dmg": 20}, "silentKill", x)
	a["cloaked"] = true
	_case(_name("silentKill"), x, 0, false)

	# Spectral makes a jam last longer. The hit is the same either way.
	_reset()
	x = _enemy(0, QUIET)
	a = _hero(0, {"dmg": 5, "jam": true}, "ghostSignal", x)
	a["cloaked"] = true
	_case(_name("ghostSignal"), x, 100 - int(_cm.ambush_damage(a, 5)), false)

	# Flickering cloaks the unit after its first-window ability. Its hit is the same.
	_reset()
	x = _enemy(0, {"dmg": 7}, "blink", _h(1))
	_case(_name("blink"), _h(1), 100 - 7, false)

	# Commanding makes a roll penalty last longer. Its hit is the same.
	_reset()
	x = _enemy(0, {"dmg": 7, "rfm": 1, "rfmT": 2}, "compel", _h(1))
	_case(_name("compel"), _h(1), 100 - 7, false)


# ── Not traits, missed by the old preview for the same reason ─────────────────
func _check_rampage_and_pack() -> void:
	var x: Dictionary

	# A rampaging enemy's attack is doubled.
	_reset()
	x = _enemy(0, {"dmg": 6}, "", _h(1))
	x["rampage_charges"] = 1
	_case("rampage", _h(1), 100 - 12, false)

	# The pack bonus: one living packmate of the same kind.
	_reset()
	x = _enemy(0, {"dmg": 6, "packBonus": true}, "", _h(1), "pack")
	_enemy(1, QUIET, "", {}, "pack")
	_case("pack bonus", _h(1), 100 - 6 - int(_cm.pack_bonus_per_member()), false)


# ── The bar the card draws ends where the preview says ────────────────────────
# _reset puts fresh state copies in the manager; the cards must read those.
func _rebind_cards() -> void:
	for views in [[_scene.hero_card_views, _cm.get_hero_states()], [_scene.enemy_card_views, _cm.get_enemy_states()]]:
		for index in (views[0] as Array).size():
			(views[0] as Array)[index]["state"] = (views[1] as Array)[index]
	_scene._card_view.refresh_all_cards()


func _check_card_draws() -> void:
	_reset()
	var x: Dictionary = _enemy(0, {"dmg": 10}, "", _h(1))
	var a: Dictionary = _hero(0, {"taunt": true}, "anchor", x)
	var started: int = Time.get_ticks_usec()
	_rebind_cards()
	print("[TRAIT_PREVIEW] refreshing all six cards, each with its own dry run of the round: %d ms" % int((Time.get_ticks_usec() - started) / 1000.0))
	await process_frame
	await process_frame
	var want: int = 100 - (10 - _num("anchor", "amount"))
	var card: Control = _scene._feedback._find_card_by_state_id("hero", str(a["id"]))
	_expect(card != null and int(card.preview_end_hp) == want, "card: the bar on the taunter's card ends on %d (%s)" % [want, str(card.preview_end_hp) if card != null else "no card"])
	var foe: Control = _scene._feedback._find_card_by_state_id("enemy", str(x["id"]))
	_reset()
	x = _enemy(0, {"dmg": 10}, "", _h(1))
	a = _hero(0, {"taunt": true}, "retaliate", x)
	_rebind_cards()
	await process_frame
	await process_frame
	want = 100 - _num("retaliate", "amount")
	_expect(foe != null and int(foe.preview_end_hp) == want, "card: the bar on the attacker's card ends on %d (%s)" % [want, str(foe.preview_end_hp) if foe != null else "no card"])
	_cases_run += 1
