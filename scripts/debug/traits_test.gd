# Unit traits gate (G-62, Kev 2026-10-09).
#
#   godot --headless --path . -s scripts/debug/traits_test.gd [-- --trait-break=off]
#
# Some units carry one always-on trait: every hero evolution, every elite, and
# in Mantle Hunt every unit but the boss (G-66). Pinned here:
#   A. who      the roster from the rulings, unit by unit: 16 evolutions, each
#               with the two traits it chooses between at 250 XP (G-71), 9
#               elites, 7 Mantle Hunt units with Feral (Basalt Ape and Magma
#               Drake keep Accrete too; the Mantle Tyrant has Accrete and no
#               trait); base heroes, the other regular units, the other
#               operations' tanks and supports, and bosses have none; every
#               trait defined is used.
#   B. rules    every one of the 42 traits does what its line says, by the
#               number in its data, and does nothing without the trait.
#   B3. pick    an evolved hero has no trait until 250 XP; it then picks one
#               of its branch's two; the trait is its title on the battle
#               card; the 250 XP screen says trait, never Directive; the
#               100 XP picker previews both traits; a run saved with a
#               Directive loads with the matching trait.
#   C. dice     Static and Zealous move the die's one value (the path a
#               deliberate change takes), pass over frozen and hijacked dice,
#               never lift a jammed die past its cap, and fire Static first.
#   D. shown    each trigger writes a log line that names the trait and one
#               `trait` event per ability; the inspect leads with the trait
#               line above the roll breakdown; the evolution picker and the
#               Help reference print it; the battle card carries the marker
#               (Volt Enforcer's in the warning colour) and never in a
#               portrait corner.
#   E. copy     no leftover {key}, no em dash, no band word, short lines; every
#               name is one title word (G-63), no retired name is left in the
#               data or typed into a log line in code; every trait and
#               callsign fits its line of the battle card.
#   F. live     a real battle: Static tips an enemy die and the tray shows the
#               value the unit acts on; the chip and the log line appear; with
#               No animations the chip still appears.
# scripts/checks/break_gate.py reruns it with each CombatManager TRAIT_BREAK_ARG
# mode (off, no_chip, frozen_dice, litany_first, boss_trait) and requires a FAIL.
extends SceneTree

const COMBAT_SOURCE := "res://scripts/battle/combat_manager.gd"
const ENGINE_SOURCE := "res://scripts/battle/battle_engine.gd"
const STATE_SOURCE := "res://scripts/battle/battle_state.gd"
const DICE_SOURCE := "res://scripts/battle/dice_manager.gd"
const SEEDED_SOURCE := "res://scripts/sim/seeded_roll_provider.gd"
const TRAITS_SOURCE := "res://scripts/battle/unit_traits.gd"
const INSPECT_SOURCE := "res://scripts/ui/inspect_resolver.gd"
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SPEED := 8

# The ruling's roster (G-62). Hero evolutions by "hero/evolution" id.
const EVOLUTION_TRAITS := {
	"pulse/pyro": "Smoldering", "pulse/arc": "Charged",
	"combat/blade": "Ruthless", "combat/ravager": "Bloodlust",
	"shield/bulwark": "Anchored", "shield/sentinel": "Vengeful",
	"avalanche/glacier": "Glacial", "avalanche/trench": "Entrenched",
	"medic/medic": "Watchful", "medic/synth": "Overflowing",
	"engineer/overclocked": "Redline", "engineer/phantom": "Spectral",
	"ghost/shadow": "Silent", "ghost/wraith": "Relentless",
	"breaker/noise": "Static", "breaker/nullwire": "Zero-Day",
}
const ENEMY_TRAITS := {
	"Patrol Enforcer": "Vigilant", "Volt Enforcer": "Volatile", "Spine Stalker": "Barbed",
	"Caustic Spewer": "Corrosive", "Phaseblade": "Flickering", "Circuit Acolyte": "Zealous",
	"False Image": "Illusory", "Ash Channeler": "Fervent", "Oath Binder": "Commanding",
	"Pumice Climber": "Feral", "Obsidian Hound": "Feral", "Slag Hound": "Feral",
	"Geode Panther": "Feral", "Cinder Raptor": "Feral",
	"Basalt Ape": "Feral", "Magma Drake": "Feral",
}
# The 250 XP pick (G-71): each branch chooses between its signature trait
# (EVOLUTION_TRAITS above) and one that was a Directive. [first, second].
const PRESTIGE_TRAITS := {
	"pulse/pyro": ["Smoldering", "Searing"], "pulse/arc": ["Charged", "Forking"],
	"combat/blade": ["Ruthless", "Serrated"], "combat/ravager": ["Bloodlust", "Scalding"],
	"shield/bulwark": ["Anchored", "Fortified"], "shield/sentinel": ["Vengeful", "Bristling"],
	"avalanche/glacier": ["Glacial", "Shattering"], "avalanche/trench": ["Entrenched", "Sheltering"],
	"medic/medic": ["Watchful", "Reviving"], "medic/synth": ["Overflowing", "Reinforcing"],
	"engineer/overclocked": ["Redline", "Capacitive"], "engineer/phantom": ["Spectral", "Shrouded"],
	"ghost/shadow": ["Silent", "Vanishing"], "ghost/wraith": ["Relentless", "Reaping"],
	"breaker/noise": ["Static", "Shrieking"], "breaker/nullwire": ["Zero-Day", "Siphoning"],
}
# Every Directive a run saved before G-71 may hold, by branch, and the trait
# its hero has after loading: the trait it became, or the branch's first trait.
const LEGACY_DIRECTIVES := {
	"pulse/pyro": {"Flashpoint": "Searing", "Sustained Ignition": "Smoldering"},
	"pulse/arc": {"Conductor": "Forking", "Amplifier": "Charged"},
	"combat/blade": {"Serrated": "Serrated", "Momentum": "Ruthless"},
	"combat/ravager": {"Thermal Trauma": "Scalding", "Flash Cautery": "Bloodlust"},
	"shield/bulwark": {"Rampart": "Fortified", "Bunker Doctrine": "Anchored"},
	"shield/sentinel": {"Ironclad": "Vengeful", "Counterweight": "Bristling"},
	"avalanche/glacier": {"Deep Freeze": "Glacial", "Shatterpoint": "Shattering"},
	"avalanche/trench": {"Field Triage": "Sheltering", "Entrench": "Entrenched"},
	"medic/medic": {"Combat Sense": "Watchful", "Field Surgeon": "Reviving"},
	"medic/synth": {"Reinforced Mesh": "Reinforcing", "Resuscitation Loop": "Overflowing"},
	"engineer/overclocked": {"Deep Cells": "Capacitive", "Power Wiring": "Redline"},
	"engineer/phantom": {"Silent Running": "Shrouded", "Ambush Wiring": "Spectral"},
	"ghost/shadow": {"Ghostblade": "Silent", "Vanish": "Vanishing"},
	"ghost/wraith": {"Marked for Death": "Relentless", "Reaper": "Reaping"},
	"breaker/noise": {"Wall of Static": "Static", "Feedback": "Shrieking"},
	"breaker/nullwire": {"Hard Lock": "Zero-Day", "Signal Theft": "Siphoning"},
}
# Mantle Hunt (G-66): every unit of the faction but its boss has Feral.
const MANTLE_BOSS := "Mantle Tyrant"
const MANTLE_ACCRETE_AND_FERAL := ["Basalt Ape", "Magma Drake"]
# The names G-63 retired. None may come back in the data or in a log line.
const RETIRED_NAMES := ["Afterburn", "Live Wire", "Exposed", "Anchor", "Retaliate", "Glacial Armor", "Dug In",
	"Triage", "Overflow", "Ghost Signal", "Silent Kill", "Clean Kill", "Zero Day", "Backup", "Discharge", "Blink",
	"Litany", "Decoy", "Kindle", "Compel", "Pack Rage"]
# Where a trait's log line, chip or marker is written. A trait's name is read
# from the data there, never typed.
const NAME_SOURCES := [COMBAT_SOURCE, ENGINE_SOURCE, "res://scripts/battle/battle_feedback.gd", "res://scripts/battle/battle_scene.gd",
	"res://scripts/battle/boss_relic_actions.gd", "res://scripts/battle/battle_card_view.gd", "res://scripts/ui/compact_unit_card.gd",
	"res://scripts/ui/evolution_screen.gd", "res://scripts/ui/help_menu.gd", INSPECT_SOURCE]
const BAND_WORDS := ["recharge", "strike", "surge", "crit", "overload"]
const MAX_TRAIT_LINE := 80

var _errors: PackedStringArray = []
var _dice: Object
var _traits: Object


func _initialize() -> void:
	call_deferred("_run")


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_errors.append(what)


func sm() -> Node:
	return root.get_node("/root/SaveManager")


func dm() -> Node:
	return root.get_node("/root/DataManager")


func _run() -> void:
	await process_frame
	root.get_node("/root/AudioManager").set_suppressed(true)
	sm().set_setting("ability_primers_enabled", false)
	sm().set_setting("reduced_motion", false)
	sm().set_setting("no_animations", false)
	_dice = load(DICE_SOURCE).new()
	_traits = load(TRAITS_SOURCE)
	_check_roster()
	_check_hero_rules()
	_check_prestige_rules()
	await _check_prestige_pick()
	_check_enemy_rules()
	_check_round_start()
	_check_shown()
	_check_copy()
	await _check_live()
	for error in _errors:
		print("[TRAITS] FAIL - %s" % error)
	print("[TRAITS] %s" % ("PASS" if _errors.is_empty() else "FAIL - %d check(s)" % _errors.size()))
	sm().set_setting("no_animations", false)
	sm().clear_run_save()
	if current_scene != null:
		unload_current_scene()
	await create_timer(0.3).timeout
	quit(0 if _errors.is_empty() else 1)


# ── Fixtures ──────────────────────────────────────────────────────────────────
func _band(lo: int, hi: int, ability_name: String, raw: Dictionary) -> Dictionary:
	return {"min": lo, "max": hi, "zone": "band%d" % lo, "ability_name": ability_name, "description": "", "raw": raw.duplicate(true)}


# A two-ability kit: `low` on 1-10, `high` on 11-20 (one ability when `high` is empty).
func _kit(low: Dictionary, high: Dictionary = {}) -> Array[Dictionary]:
	var bands: Array[Dictionary] = []
	if high.is_empty():
		bands.append(_band(1, 20, "Test Move", low))
	else:
		bands.append(_band(1, 10, "Low Move", low))
		bands.append(_band(11, 20, "High Move", high))
	return bands


func _hero(id: String, low: Dictionary = {}, high: Dictionary = {}, trait_id: String = "") -> UnitData:
	var unit: UnitData = UnitData.new()
	unit.id = id
	unit.display_name = "Hero %s" % id
	unit.max_hp = 100
	unit.dice_ranges = _kit(low, high)
	unit.unit_trait = _traits.build(trait_id, unit.dice_ranges)
	return unit


func _enemy(id: String, low: Dictionary = {}, high: Dictionary = {}, trait_id: String = "") -> EnemyData:
	var enemy: EnemyData = EnemyData.new()
	enemy.id = id
	enemy.display_name = "Enemy %s" % id
	enemy.enemy_type = id
	enemy.max_hp = 100
	enemy.dice_ranges = _kit(low, high)
	enemy.unit_trait = _traits.build(trait_id, enemy.dice_ranges)
	return enemy


func _battle(heroes: Array, enemies: Array) -> Object:
	var cm: Object = load(COMBAT_SOURCE).new()
	cm.roll_provider = load(SEEDED_SOURCE).new(1)
	cm.setup_battle(heroes, enemies)
	return cm


# One round. `hero_rolls` / `enemy_rolls`: {index: roll}; a side left out does not act.
func _round(cm: Object, hero_rolls: Dictionary = {}, enemy_rolls: Dictionary = {}) -> Dictionary:
	var h: Dictionary = {}
	for index in hero_rolls:
		h[str(cm.get_hero_states()[int(index)]["id"])] = int(hero_rolls[index])
	var e: Dictionary = {}
	for index in enemy_rolls:
		e[str(cm.get_enemy_states()[int(index)]["id"])] = int(enemy_rolls[index])
	return cm.resolve_round(h, e, _dice)


func _h(cm: Object, index: int = 0) -> Dictionary:
	return cm.get_hero_states()[index]


func _e(cm: Object, index: int = 0) -> Dictionary:
	return cm.get_enemy_states()[index]


func _lost(state: Dictionary) -> int:
	return int(state["max_hp"]) - int(state["current_hp"])


func _aim(cm: Object, hero_index: int, enemy_index: int) -> void:
	_h(cm, hero_index)["selected_target_id"] = str(_e(cm, enemy_index)["id"])


func _num(trait_id: String, key: String) -> int:
	return int(((_traits.data()["traits"] as Dictionary)[trait_id] as Dictionary).get(key, 0))


func _trait_events(result: Dictionary, trait_name: String) -> int:
	var total: int = 0
	for event in result.get("events", []):
		if str((event as Dictionary).get("type", "")) == "trait" and str((event as Dictionary).get("trait_name", "")) == trait_name:
			total += 1
	return total


func _logged(result: Dictionary, prefix: String) -> bool:
	for line in result.get("log", []):
		if str(line).begins_with(prefix):
			return true
	return false


# The same round with and without the trait must differ exactly as stated, and
# the trait round must log "<Name>: ..." and emit one `trait` event.
func _expect_shown(result: Dictionary, trait_name: String, what: String) -> void:
	_expect(_logged(result, "%s: " % trait_name), "%s: the log names the trait (%s)" % [what, str(result.get("log", []))])
	_expect(_trait_events(result, trait_name) >= 1, "%s: a `trait` event carries the name for the chip" % what)


# ── A. Who has a trait ────────────────────────────────────────────────────────
func _check_roster() -> void:
	var used: Dictionary = {}
	for unit in dm().units.values():
		_expect(_traits.of_unit(unit).is_empty(), "roster: base hero %s has no trait" % unit.display_name)
		for path in unit.evolution_paths:
			var key: String = "%s/%s" % [unit.id, str(path["id"])]
			var options: Array = path.get("traits", [])
			var option_names: Array = options.map(func(option: Variant) -> String: return str((option as Dictionary).get("name", "")))
			_expect(EVOLUTION_TRAITS.has(key), "roster: evolution %s is in the ruling's list" % key)
			_expect(option_names == PRESTIGE_TRAITS.get(key, []), "roster: %s chooses between %s (%s)" % [key, str(PRESTIGE_TRAITS.get(key, [])), str(option_names)])
			_expect(str(option_names.front()) == str(EVOLUTION_TRAITS.get(key, "?")), "roster: %s's first option is its signature trait %s" % [key, str(EVOLUTION_TRAITS.get(key, "?"))])
			for option in options:
				used[str((option as Dictionary).get("id", ""))] = true
	var evolutions: int = 0
	for unit in dm().units.values():
		evolutions += unit.evolution_paths.size()
	_expect(evolutions == EVOLUTION_TRAITS.size(), "roster: all %d evolutions are covered (%d)" % [EVOLUTION_TRAITS.size(), evolutions])
	for enemy in dm().enemies.values():
		var enemy_name: String = str(enemy.display_name)
		var carried: Dictionary = _traits.of_unit(enemy)
		_expect(str(carried.get("name", "")) == str(ENEMY_TRAITS.get(enemy_name, "")), "roster: %s has %s (%s)" % [enemy_name, str(ENEMY_TRAITS.get(enemy_name, "no trait")), str(carried.get("name", "no trait"))])
		used[str(carried.get("id", ""))] = true
		if load(COMBAT_SOURCE).get_boss_standing_rule(enemy_name) != "":
			_expect(carried.is_empty(), "roster: boss %s has no trait" % enemy_name)
	for enemy_name in ENEMY_TRAITS:
		_expect(dm().get_enemy_by_display_name(enemy_name) != null, "roster: %s exists" % enemy_name)
	# Mantle Hunt (G-66): every unit but the boss has Feral, whatever its role.
	# The two that also Accrete keep it; the boss keeps Accrete and has no trait.
	var combat: Object = load(COMBAT_SOURCE)
	var tyrant: Resource = dm().get_enemy_by_display_name(MANTLE_BOSS)
	var beasts: int = 0
	for enemy in dm().enemies.values():
		if tyrant == null or str(enemy.faction) != str(tyrant.faction) or str(enemy.display_name) == MANTLE_BOSS:
			continue
		beasts += 1
		_expect(str(_traits.of_unit(enemy).get("id", "")) == "packRage", "Mantle Hunt: %s has Feral (%s)" % [str(enemy.display_name), str(_traits.of_unit(enemy).get("name", "no trait"))])
	_expect(beasts == 7, "Mantle Hunt: seven units besides the boss (%d)" % beasts)
	for enemy_name in MANTLE_ACCRETE_AND_FERAL:
		var both: Resource = dm().get_enemy_by_display_name(enemy_name)
		_expect(both != null and int(both.accrete) > 0 and not (combat.accrete_rule(both) as Dictionary).is_empty(), "Mantle Hunt: %s keeps its Accrete keyword beside Feral" % enemy_name)
	_expect(tyrant != null and _traits.of_unit(tyrant).is_empty() and not (combat.accrete_rule(tyrant) as Dictionary).is_empty(), "Mantle Hunt: the Mantle Tyrant keeps Accrete and has no trait")
	# In the other four operations nothing changed: only elites have a trait.
	for enemy in dm().enemies.values():
		if tyrant != null and str(enemy.faction) == str(tyrant.faction):
			continue
		if not _traits.of_unit(enemy).is_empty():
			_expect(str(_traits.of_unit(enemy).get("id", "")) != "packRage", "roster: %s is not a Mantle Hunt unit and does not have Feral" % str(enemy.display_name))
	for trait_id in (_traits.data()["traits"] as Dictionary):
		_expect(used.has(trait_id), "roster: trait %s is carried by a unit" % trait_id)

	# A hero takes the trait it picked at 250 XP into the run (G-71); the base
	# hero has none, and neither has an evolved hero before its pick.
	var gs: Node = root.get_node("/root/GameState")
	gs.reset_run()
	gs.start_run(["pulse", "combat", "medic"], "facility", 5)
	_expect(_traits.of_unit(gs.get_run_unit_data("pulse")).is_empty(), "run: an unevolved hero has no trait")
	gs.unit_evolutions["pulse"] = "Pyro Specialist"
	var evolved: Resource = gs.get_run_unit_data("pulse")
	_expect(_traits.of_unit(evolved).is_empty(), "run: Pyro Specialist has no trait before 250 XP (%s)" % str(_traits.of_unit(evolved)))
	_expect(str(_h(_battle([evolved], [_enemy("x")]))["trait"]) == "", "run: and its battle state carries none")
	gs.unit_directives["pulse"] = "afterburn"
	evolved = gs.get_run_unit_data("pulse")
	_expect(str(_traits.of_unit(evolved).get("name", "")) == "Smoldering", "run: with Smoldering picked, Pyro Specialist carries it (%s)" % str(_traits.of_unit(evolved)))
	var cm: Object = _battle([evolved], [_enemy("x")])
	_expect(str(_h(cm)["trait"]) == "afterburn", "run: its battle state carries the trait id (%s)" % str(_h(cm)["trait"]))
	gs.reset_run()


# ── B. The hero traits ────────────────────────────────────────────────────────
func _check_hero_rules() -> void:
	var cm: Object
	var result: Dictionary

	# Smoldering: detonating leaves a burn.
	for with in [true, false]:
		cm = _battle([_hero("a", {"dmg": 5, "detonate": true}, {}, "afterburn" if with else "")], [_enemy("x")])
		cm._apply_burn(_e(cm), 3, 2)
		_aim(cm, 0, 0)
		result = _round(cm, {0: 5})
		var left: Array = _e(cm)["burn_stacks"]
		if with:
			_expect(left.size() == 1 and int(left[0]["amt"]) == _num("afterburn", "burn") and int(left[0]["turns_left"]) == _num("afterburn", "turns"), "Smoldering: the detonation leaves %d burn for %d turns (%s)" % [_num("afterburn", "burn"), _num("afterburn", "turns"), str(left)])
			_expect_shown(result, "Smoldering", "Smoldering")
		else:
			_expect(left.is_empty(), "no trait: a detonation leaves no burn (%s)" % str(left))
	cm = _battle([_hero("a", {"dmg": 5, "detonate": true}, {}, "afterburn")], [_enemy("x")])
	_aim(cm, 0, 0)
	_round(cm, {0: 5})
	_expect((_e(cm)["burn_stacks"] as Array).is_empty(), "Smoldering: a detonate with no burn to detonate leaves nothing")

	# Charged: each chain jump deals more.
	for with in [true, false]:
		cm = _battle([_hero("a", {"dmg": 10, "chain": 1}, {}, "liveWire" if with else "")], [_enemy("x"), _enemy("y")])
		_aim(cm, 0, 0)
		result = _round(cm, {0: 5})
		_expect(_lost(_e(cm, 1)) == 5 + (_num("liveWire", "amount") if with else 0), "Charged %s: the chain jump deals %d (%d)" % ["on" if with else "off", 5 + (_num("liveWire", "amount") if with else 0), _lost(_e(cm, 1))])
		_expect(_lost(_e(cm, 0)) == 10, "Charged: the first hit is unchanged (%d)" % _lost(_e(cm, 0)))
		if with:
			_expect_shown(result, "Charged", "Charged")

	# Ruthless: area attacks hit marked enemies harder.
	for with in [true, false]:
		cm = _battle([_hero("a", {"dmg": 6, "blastAll": true}, {}, "exposed" if with else "")], [_enemy("x"), _enemy("y")])
		_e(cm, 0)["marked"] = true
		result = _round(cm, {0: 5})
		var bonus: int = _num("exposed", "amount") if with else 0
		_expect(_lost(_e(cm, 0)) == int(ceil((6 + bonus) * 1.5)), "Ruthless %s: the marked enemy takes %d (%d)" % ["on" if with else "off", int(ceil((6 + bonus) * 1.5)), _lost(_e(cm, 0))])
		_expect(_lost(_e(cm, 1)) == 6, "Ruthless: an unmarked enemy takes the plain 6 (%d)" % _lost(_e(cm, 1)))
		if with:
			_expect_shown(result, "Ruthless", "Ruthless")
	cm = _battle([_hero("a", {"dmg": 6}, {}, "exposed")], [_enemy("x")])
	_e(cm)["marked"] = true
	_aim(cm, 0, 0)
	_round(cm, {0: 5})
	_expect(_lost(_e(cm)) == 9, "Ruthless: a single-target attack gets nothing from it (%d)" % _lost(_e(cm)))

	# Bloodlust: the first band arms the next leech.
	for with in [true, false]:
		cm = _battle([_hero("a", {"dmg": 4}, {"dmg": 20, "leech": true}, "bloodlust" if with else "")], [_enemy("x")])
		_h(cm)["current_hp"] = 40
		_aim(cm, 0, 0)
		result = _round(cm, {0: 5})
		_expect(bool(_h(cm).get("bloodlust_ready", false)) == with, "Bloodlust %s: rolling the first band arms it" % ("on" if with else "off"))
		if with:
			_expect_shown(result, "Bloodlust", "Bloodlust (armed)")
		_aim(cm, 0, 0)
		var before: int = int(_h(cm)["current_hp"])
		_round(cm, {0: 15})
		var want: int = int(floor(20 * 0.5 * (1.0 + _num("bloodlust", "pct") / 100.0))) if with else 10
		_expect(int(_h(cm)["current_hp"]) - before == want, "Bloodlust %s: the next leech heals %d (%d)" % ["on" if with else "off", want, int(_h(cm)["current_hp"]) - before])
		_aim(cm, 0, 0)
		before = int(_h(cm)["current_hp"])
		_round(cm, {0: 15})
		_expect(int(_h(cm)["current_hp"]) - before == 10, "Bloodlust: the leech after that is the plain 10 (%d)" % (int(_h(cm)["current_hp"]) - before))

	# Anchored: less damage while taunting.
	for case in [["anchor", true], ["anchor", false], ["", true]]:
		cm = _battle([_hero("a", {"taunt": true} if case[1] else {"shield": 0}, {}, str(case[0]))], [_enemy("x", {"dmg": 10})])
		_aim(cm, 0, 0)
		_e(cm)["selected_target_id"] = "a"
		result = _round(cm, {0: 5}, {0: 5})
		var cut: int = _num("anchor", "amount") if (case[0] == "anchor" and case[1]) else 0
		_expect(_lost(_h(cm)) == 10 - cut, "Anchored (trait %s, taunting %s): takes %d (%d)" % [str(case[0] != ""), str(case[1]), 10 - cut, _lost(_h(cm))])
		if cut > 0:
			_expect_shown(result, "Anchored", "Anchored")

	# Vengeful: hit while taunting, the attacker takes spike damage.
	for case in [["retaliate", {"taunt": true}, 0], ["retaliate", {"shield": 0}, 0], ["", {"taunt": true}, 0], ["retaliate", {"taunt": true, "spike": 3}, 3]]:
		cm = _battle([_hero("a", case[1], {}, str(case[0]))], [_enemy("x", {"dmg": 10})])
		_aim(cm, 0, 0)
		_e(cm)["selected_target_id"] = "a"
		result = _round(cm, {0: 5}, {0: 5})
		var taunting: bool = (case[1] as Dictionary).has("taunt")
		var back: int = int(case[2]) + (_num("retaliate", "amount") if (case[0] == "retaliate" and taunting) else 0)
		_expect(_lost(_e(cm)) == back, "Vengeful (trait %s, taunting %s, spike %d): the attacker takes %d (%d)" % [str(case[0] != ""), str(taunting), int(case[2]), back, _lost(_e(cm))])
		if case[0] == "retaliate" and taunting:
			_expect_shown(result, "Vengeful", "Vengeful")

	# Watchful: more healing on the lowest-HP ally.
	for with in [true, false]:
		cm = _battle([_hero("a", {"heal": 6, "healTgt": true}, {}, "triage" if with else ""), _hero("b"), _hero("c")], [_enemy("x")])
		_h(cm, 1)["current_hp"] = 30
		_h(cm, 2)["current_hp"] = 60
		_h(cm, 0)["selected_target_id"] = "b"
		result = _round(cm, {0: 5})
		_expect(int(_h(cm, 1)["current_hp"]) == 36 + (_num("triage", "amount") if with else 0), "Watchful %s: the lowest-HP ally is healed %d (%d)" % ["on" if with else "off", 6 + (_num("triage", "amount") if with else 0), int(_h(cm, 1)["current_hp"]) - 30])
		if with:
			_expect_shown(result, "Watchful", "Watchful")
		_h(cm, 0)["selected_target_id"] = "c"
		_round(cm, {0: 5})
		_expect(int(_h(cm, 2)["current_hp"]) == 66, "Watchful: an ally that is not the lowest gets the plain 6 (%d)" % (int(_h(cm, 2)["current_hp"]) - 60))
	cm = _battle([_hero("a", {"heal": 6, "healAll": true}, {}, "triage"), _hero("b"), _hero("c")], [_enemy("x")])
	_h(cm, 0)["current_hp"] = 50
	_h(cm, 1)["current_hp"] = 30
	_h(cm, 2)["current_hp"] = 60
	_round(cm, {0: 5})
	_expect(int(_h(cm, 1)["current_hp"]) == 36 + _num("triage", "amount") and int(_h(cm, 0)["current_hp"]) == 56 and int(_h(cm, 2)["current_hp"]) == 66, "Watchful: a heal on everyone adds its bonus on the lowest only")

	# Overflowing: healing past full HP becomes shield.
	for with in [true, false]:
		cm = _battle([_hero("a", {"heal": 10, "healTgt": true}, {}, "overflow" if with else ""), _hero("b")], [_enemy("x")])
		_h(cm, 1)["current_hp"] = 96
		_h(cm, 0)["selected_target_id"] = "b"
		result = _round(cm, {0: 5})
		_expect(int(_h(cm, 1)["current_hp"]) == 100, "Overflowing: the heal still fills the HP")
		# The shield is an ordinary one-round shield, gone at the round-end tick:
		# read what it was from the round's events.
		var gained: int = 0
		for event in result["events"]:
			if str(event["type"]) == "shield" and str(event["target_id"]) == "b":
				gained += int(event["amount"])
		_expect(gained == (6 if with else 0), "Overflowing %s: 6 healing past full becomes %d shield (%d)" % ["on" if with else "off", 6 if with else 0, gained])
		if with:
			_expect_shown(result, "Overflowing", "Overflowing")

	# Redline: a flat bonus while the player holds enough Protocol.
	for case in [["redline", _num("redline", "protocol")], ["redline", _num("redline", "protocol") - 1], ["", 10]]:
		cm = _battle([_hero("a", {"dmg": 10}, {}, str(case[0]))], [_enemy("x")])
		cm.protocol_pool = int(case[1])
		_aim(cm, 0, 0)
		result = _round(cm, {0: 5})
		var redline: int = _num("redline", "amount") if (case[0] == "redline" and int(case[1]) >= _num("redline", "protocol")) else 0
		_expect(_lost(_e(cm)) == 10 + redline, "Redline (trait %s, %d Protocol): the attack deals %d (%d)" % [str(case[0] != ""), int(case[1]), 10 + redline, _lost(_e(cm))])
		if redline > 0:
			_expect_shown(result, "Redline", "Redline")

	# Spectral: a jam applied from cloak holds one more roll.
	for case in [["ghostSignal", true], ["ghostSignal", false], ["", true]]:
		cm = _battle([_hero("a", {"dmg": 5, "jam": true}, {}, str(case[0]))], [_enemy("x")])
		_h(cm)["cloaked"] = bool(case[1])
		_aim(cm, 0, 0)
		result = _round(cm, {0: 5})
		var extra: bool = case[0] == "ghostSignal" and bool(case[1])
		_expect(int(_e(cm)["jam_cap"]) > 0, "Spectral: the jam is on after the round it was applied")
		_round(cm)
		_expect((int(_e(cm)["jam_cap"]) > 0) == extra, "Spectral (trait %s, from cloak %s): the jam %s a second roll" % [str(case[0] != ""), str(case[1]), "holds" if extra else "does not hold"])
		_round(cm)
		_expect(int(_e(cm)["jam_cap"]) == 0, "Spectral: the jam is gone after its extra roll")
		if extra:
			_expect_shown(result, "Spectral", "Spectral")

	# Silent: an ambush that kills keeps the cloak.
	for case in [["silentKill", 10], ["silentKill", 100], ["", 10]]:
		cm = _battle([_hero("a", {"dmg": 20}, {}, str(case[0]))], [_enemy("x"), _enemy("y")])
		_e(cm, 0)["current_hp"] = int(case[1])
		_h(cm)["cloaked"] = true
		_aim(cm, 0, 0)
		result = _round(cm, {0: 5})
		var kept: bool = case[0] == "silentKill" and int(case[1]) <= 30
		_expect(bool(_h(cm)["cloaked"]) == kept, "Silent (trait %s, kill %s): the cloak is %s" % [str(case[0] != ""), str(bool(_e(cm, 0)["dead"])), "kept" if kept else "broken"])
		var decloaks: int = 0
		for event in result["events"]:
			if str(event["type"]) == "decloak":
				decloaks += 1
		_expect(decloaks == (0 if kept else 1), "Silent: the cloak chip %s (%d decloak beats)" % ["never leaves" if kept else "leaves", decloaks])
		if kept:
			_expect_shown(result, "Silent", "Silent")

	# Relentless: a kill marks the lowest-HP enemy left.
	for with in [true, false]:
		cm = _battle([_hero("a", {"dmg": 50}, {}, "cleanKill" if with else "")], [_enemy("x"), _enemy("y"), _enemy("z")])
		_e(cm, 0)["current_hp"] = 10
		_e(cm, 2)["current_hp"] = 50
		_aim(cm, 0, 0)
		result = _round(cm, {0: 5})
		_expect(bool(_e(cm, 2).get("marked", false)) == with and not bool(_e(cm, 1).get("marked", false)), "Relentless %s: the lowest-HP enemy left is %s" % ["on" if with else "off", "marked" if with else "not marked"])
		if with:
			_expect_shown(result, "Relentless", "Relentless")

	# Zero-Day: an enemy it rewrote takes more until the rewrite ends.
	for with in [true, false]:
		cm = _battle([_hero("a", {"dmg": 5, "rewrite": true}, {"shield": 0}, "zeroDay" if with else ""), _hero("b", {"dmg": 10})], [_enemy("x")])
		_aim(cm, 0, 0)
		_aim(cm, 1, 0)
		result = _round(cm, {0: 5, 1: 5})
		var zero: int = _num("zeroDay", "amount") if with else 0
		_expect(_lost(_e(cm)) == 15 + zero, "Zero-Day %s: the next hero's hit on the rewritten enemy deals %d (total %d)" % ["on" if with else "off", 10 + zero, _lost(_e(cm))])
		if with:
			_expect_shown(result, "Zero-Day", "Zero-Day")
		# The round the die is rewritten: still on.
		_aim(cm, 1, 0)
		_round(cm, {0: 15, 1: 5})
		_expect(_lost(_e(cm)) == 25 + zero * 2, "Zero-Day %s: it holds through the round the die is rewritten (total %d)" % ["on" if with else "off", _lost(_e(cm))])
		_expect(not bool(_e(cm)["rewrite_pending"]) and int(_e(cm).get("zero_day", 0)) == 0, "Zero-Day: it ends with the rewrite")
		_aim(cm, 1, 0)
		_round(cm, {0: 15, 1: 5})
		_expect(_lost(_e(cm)) == 35 + zero * 2, "Zero-Day: the round after, the hit is the plain 10 (total %d)" % _lost(_e(cm)))


# ── B. The elite traits and Feral ─────────────────────────────────────────
func _check_enemy_rules() -> void:
	var cm: Object
	var result: Dictionary

	# Vigilant: gains shield when an ally is hit.
	for with in [true, false]:
		cm = _battle([_hero("a", {"dmg": 5}, {"dmg": 5, "blastAll": true})], [_enemy("p", {}, {}, "backup" if with else ""), _enemy("q")])
		_aim(cm, 0, 1)
		result = _round(cm, {0: 5})
		var gained: int = 0
		for event in result["events"]:
			if str(event["type"]) == "shield" and str(event["target_id"]) == str(_e(cm, 0)["id"]):
				gained += int(event["amount"])
		_expect(gained == (_num("backup", "amount") if with else 0), "Vigilant %s: an ally hit gives it %d shield (%d)" % ["on" if with else "off", _num("backup", "amount") if with else 0, gained])
		if with:
			_expect_shown(result, "Vigilant", "Vigilant")
			# An area attack hits it and one ally: one gain, for the ally.
			result = _round(cm, {0: 15})
			gained = 0
			for event in result["events"]:
				if str(event["type"]) == "shield" and str(event["target_id"]) == str(_e(cm, 0)["id"]):
					gained += int(event["amount"])
			_expect(gained == _num("backup", "amount"), "Vigilant: being hit itself does not count, one ally hit is one gain (%d)" % gained)

	# Volatile: dying, it hits every hero.
	for with in [true, false]:
		cm = _battle([_hero("a", {"dmg": 50}), _hero("b"), _hero("c")], [_enemy("v", {}, {}, "discharge" if with else ""), _enemy("w")])
		_e(cm, 0)["current_hp"] = 10
		_aim(cm, 0, 0)
		result = _round(cm, {0: 5})
		for index in 3:
			_expect(_lost(_h(cm, index)) == (_num("discharge", "amount") if with else 0), "Volatile %s: hero %d takes %d (%d)" % ["on" if with else "off", index, _num("discharge", "amount") if with else 0, _lost(_h(cm, index))])
		if with:
			_expect_shown(result, "Volatile", "Volatile")

	# Barbed: a hero that hits it takes damage.
	for with in [true, false]:
		cm = _battle([_hero("a", {"dmg": 5})], [_enemy("s", {}, {}, "barbed" if with else "")])
		_aim(cm, 0, 0)
		result = _round(cm, {0: 5})
		_expect(_lost(_h(cm)) == (_num("barbed", "amount") if with else 0), "Barbed %s: the hero that hit it takes %d (%d)" % ["on" if with else "off", _num("barbed", "amount") if with else 0, _lost(_h(cm))])
		if with:
			_expect_shown(result, "Barbed", "Barbed")

	# Corrosive: its burns tick through shields.
	for with in [true, false]:
		cm = _battle([_hero("a")], [_enemy("c", {"dmg": 1, "burn": 3, "burnT": 2}, {}, "corrosive" if with else "")])
		_e(cm)["selected_target_id"] = "a"
		result = _round(cm, {}, {0: 5})
		if with:
			_expect_shown(result, "Corrosive", "Corrosive")
		var hp: int = int(_h(cm)["current_hp"])
		cm._add_shield_stack(_h(cm), 10, true)
		_round(cm)
		_expect(hp - int(_h(cm)["current_hp"]) == (3 if with else 0), "Corrosive %s: a 3 burn tick on a shielded hero costs %d HP (%d)" % ["on" if with else "off", 3 if with else 0, hp - int(_h(cm)["current_hp"])])

	# Flickering: the first band cloaks it.
	for case in [["blink", 5], ["blink", 15], ["", 5]]:
		cm = _battle([_hero("a")], [_enemy("b", {"shield": 1}, {"shield": 2}, str(case[0]))])
		result = _round(cm, {}, {0: int(case[1])})
		var blinked: bool = case[0] == "blink" and int(case[1]) <= 10
		_expect(bool(_e(cm)["cloaked"]) == blinked, "Flickering (trait %s, roll %d): it %s" % [str(case[0] != ""), int(case[1]), "cloaks" if blinked else "does not cloak"])
		if blinked:
			_expect_shown(result, "Flickering", "Flickering")

	# Illusory: the first hit of the battle is negated.
	for with in [true, false]:
		cm = _battle([_hero("a", {"dmg": 10})], [_enemy("f", {}, {}, "decoy" if with else "")])
		_aim(cm, 0, 0)
		result = _round(cm, {0: 5})
		_expect(_lost(_e(cm)) == (0 if with else 10), "Illusory %s: the first hit deals %d (%d)" % ["on" if with else "off", 0 if with else 10, _lost(_e(cm))])
		if with:
			_expect_shown(result, "Illusory", "Illusory")
		_aim(cm, 0, 0)
		_round(cm, {0: 5})
		_expect(_lost(_e(cm)) == (10 if with else 20), "Illusory: the second hit lands (%d)" % _lost(_e(cm)))
	cm = _battle([_hero("a")], [_enemy("f", {}, {}, "decoy")])
	cm._apply_burn(_e(cm), 4, 2)
	_round(cm)
	_round(cm)
	_expect(_lost(_e(cm)) == 4 and not bool(_e(cm).get("decoy_spent", false)), "Illusory: a burn tick is not a hit; it lands and the decoy is still up")

	# Fervent: heals when any burn ticks.
	for with in [true, false]:
		cm = _battle([_hero("a")], [_enemy("k", {}, {}, "kindle" if with else "")])
		_e(cm)["current_hp"] = 50
		cm._apply_burn(_h(cm), 2, 3)
		_round(cm)
		_expect(int(_e(cm)["current_hp"]) == 50, "Fervent: nothing ticks the round a burn is applied")
		result = _round(cm)
		_expect(int(_e(cm)["current_hp"]) == 50 + (_num("kindle", "amount") if with else 0), "Fervent %s: a burn tick on a hero heals it %d (%d)" % ["on" if with else "off", _num("kindle", "amount") if with else 0, int(_e(cm)["current_hp"]) - 50])
		if with:
			_expect_shown(result, "Fervent", "Fervent")

	# Commanding: its roll penalties last longer.
	for with in [true, false]:
		cm = _battle([_hero("a")], [_enemy("o", {"rfm": 1, "rfmT": 2}, {}, "compel" if with else "")])
		_e(cm)["selected_target_id"] = "a"
		result = _round(cm, {}, {0: 5})
		var stacks: Array = _h(cm)["rfe_stacks"]
		_expect(stacks.size() == 1 and int(stacks[0]["turns_left"]) == 2 + (_num("compel", "rounds") if with else 0), "Commanding %s: a 2-turn roll penalty lasts %d (%s)" % ["on" if with else "off", 2 + (_num("compel", "rounds") if with else 0), str(stacks)])
		if with:
			_expect_shown(result, "Commanding", "Commanding")

	# Feral: an ally's death gives it rampage.
	for with in [true, false]:
		cm = _battle([_hero("a", {"dmg": 50})], [_enemy("m", {"dmg": 6}, {}, "packRage" if with else ""), _enemy("n")])
		_e(cm, 1)["current_hp"] = 10
		_aim(cm, 0, 1)
		_e(cm, 0)["selected_target_id"] = "a"
		result = _round(cm, {0: 5})
		_expect(int(_e(cm, 0)["rampage_charges"]) == (1 if with else 0), "Feral %s: an ally's death gives it rampage (%d)" % ["on" if with else "off", int(_e(cm, 0)["rampage_charges"])])
		if with:
			_expect_shown(result, "Feral", "Feral")
			# Its next turn deals double, and a second death while rampaging adds nothing.
			var hp: int = int(_h(cm)["current_hp"])
			_round(cm, {}, {0: 5})
			_expect(hp - int(_h(cm)["current_hp"]) == 12 and int(_e(cm, 0)["rampage_charges"]) == 0, "Feral: the rampage doubles its next turn (6 -> %d) and ends" % (hp - int(_h(cm)["current_hp"])))


	# Feral beside Accrete (G-66): a Basalt Ape whose ally dies gains rampage and
	# still accretes on its turn that round.
	var ape: Resource = dm().get_enemy_by_display_name("Basalt Ape")
	if ape == null:
		_errors.append("Feral and Accrete: Basalt Ape exists")
	else:
		cm = _battle([_hero("a", {"dmg": 50})], [ape, _enemy("n")])
		_e(cm, 1)["current_hp"] = 10
		_aim(cm, 0, 1)
		result = _round(cm, {0: 5})
		_expect(int(_e(cm, 0)["rampage_charges"]) == 1, "Feral and Accrete: Basalt Ape gains rampage when its ally dies (%d)" % int(_e(cm, 0)["rampage_charges"]))
		_expect(int(_e(cm, 0)["shield"]) == int(ape.accrete) and int(ape.accrete) > 0, "Feral and Accrete: it still accretes %d that round (%d)" % [int(ape.accrete), int(_e(cm, 0)["shield"])])
		_expect_shown(result, "Feral", "Feral on Basalt Ape")


# ── B2. The sixteen traits that were Directives (G-71) ───────────────────────
# Each is the second option of its branch. Same effect as the Directive it
# replaces, by the number in its data; nothing without the trait.
func _shield_events(result: Dictionary, target_id: String) -> int:
	var total: int = 0
	for event in result.get("events", []):
		if str(event["type"]) == "shield" and str(event["target_id"]) == target_id:
			total += int(event["amount"])
	return total


func _give_shield(state: Dictionary, amount: int) -> void:
	state["shield_stacks"] = [{"amt": amount, "skip_next_tick": true}]
	state["shield"] = amount


func _check_prestige_rules() -> void:
	var cm: Object
	var result: Dictionary
	var lost: Dictionary = {}

	# Searing: a burn it applies ticks once as it lands.
	for with in [true, false]:
		cm = _battle([_hero("a", {"dmg": 5, "burn": 3, "burnT": 2}, {}, "flashpoint" if with else "")], [_enemy("x")])
		_aim(cm, 0, 0)
		result = _round(cm, {0: 5})
		lost[with] = _lost(_e(cm))
		if with:
			_expect_shown(result, "Searing", "Searing")
	_expect(int(lost[true]) - int(lost[false]) == 3, "Searing: the 3 burn ticks once more, as it lands (%d with, %d without)" % [int(lost[true]), int(lost[false])])

	# Forking: its chains jump to one more enemy.
	for with in [true, false]:
		cm = _battle([_hero("a", {"dmg": 10, "chain": 1}, {}, "conductor" if with else "")], [_enemy("x"), _enemy("y"), _enemy("z")])
		_aim(cm, 0, 0)
		result = _round(cm, {0: 5})
		var jumped: int = (1 if _lost(_e(cm, 1)) > 0 else 0) + (1 if _lost(_e(cm, 2)) > 0 else 0)
		_expect(jumped == 1 + (_num("conductor", "jumps") if with else 0), "Forking %s: the chain reaches %d more enemies (%d)" % ["on" if with else "off", 1 + (_num("conductor", "jumps") if with else 0), jumped])
		_expect(_lost(_e(cm, 1)) + _lost(_e(cm, 2)) == 5 * jumped, "Forking: every jump deals the chain's 5 (%d over %d jumps)" % [_lost(_e(cm, 1)) + _lost(_e(cm, 2)), jumped])
		if with:
			_expect_shown(result, "Forking", "Forking")

	# Serrated: its pierce attacks also breach.
	for with in [true, false]:
		cm = _battle([_hero("a", {"dmg": 10, "ignSh": true}, {}, "serrated" if with else "")], [_enemy("x")])
		_give_shield(_e(cm), 8)
		_aim(cm, 0, 0)
		result = _round(cm, {0: 5})
		_expect(int(_e(cm)["shield"]) == (0 if with else 8), "Serrated %s: a pierce attack leaves %d of the 8 shield (%d)" % ["on" if with else "off", 0 if with else 8, int(_e(cm)["shield"])])
		_expect(_lost(_e(cm)) == 10, "Serrated: the pierce attack still deals its 10 (%d)" % _lost(_e(cm)))
		if with:
			_expect_shown(result, "Serrated", "Serrated")
	cm = _battle([_hero("a", {"dmg": 4}, {}, "serrated")], [_enemy("x")])
	_give_shield(_e(cm), 8)
	_aim(cm, 0, 0)
	_round(cm, {0: 5})
	_expect(int(_e(cm)["shield"]) == 4 and _lost(_e(cm)) == 0, "Serrated: an attack without pierce does not breach (%d shield left)" % int(_e(cm)["shield"]))

	# Scalding: more damage to a burning enemy.
	for case in [["thermalTrauma", true], ["", true], ["thermalTrauma", false]]:
		cm = _battle([_hero("a", {"dmg": 10}, {}, str(case[0]))], [_enemy("x")])
		if case[1]:
			cm._apply_burn(_e(cm), 2, 3)
		_aim(cm, 0, 0)
		result = _round(cm, {0: 5})
		lost[str(case)] = _lost(_e(cm))
		if case[0] != "" and case[1]:
			_expect_shown(result, "Scalding", "Scalding")
	_expect(int(lost[str(["thermalTrauma", true])]) - int(lost[str(["", true])]) == _num("thermalTrauma", "amount"), "Scalding: +%d to a burning enemy (%d with, %d without)" % [_num("thermalTrauma", "amount"), int(lost[str(["thermalTrauma", true])]), int(lost[str(["", true])])])
	_expect(int(lost[str(["thermalTrauma", false])]) == 10, "Scalding: an enemy that is not burning takes the plain 10 (%d)" % int(lost[str(["thermalTrauma", false])]))

	# Fortified: its shield abilities grant more.
	for with in [true, false]:
		cm = _battle([_hero("a", {"shield": 6, "shieldAll": true}, {}, "rampart" if with else ""), _hero("b")], [_enemy("x")])
		result = _round(cm, {0: 5})
		var want_shield: int = 6 + (_num("rampart", "amount") if with else 0)
		_expect(_shield_events(result, "b") == want_shield, "Fortified %s: an ally gains %d shield (%d)" % ["on" if with else "off", want_shield, _shield_events(result, "b")])
		if with:
			_expect_shown(result, "Fortified", "Fortified")

	# Bristling: its spike abilities grant more spike.
	for with in [true, false]:
		cm = _battle([_hero("a", {"spike": 5}, {}, "counterweight" if with else "")], [_enemy("x", {"dmg": 10})])
		_e(cm)["selected_target_id"] = "a"
		result = _round(cm, {0: 5}, {0: 5})
		var want_spike: int = 5 + (_num("counterweight", "amount") if with else 0)
		_expect(_lost(_e(cm)) == want_spike, "Bristling %s: the attacker takes %d spike damage (%d)" % ["on" if with else "off", want_spike, _lost(_e(cm))])
		if with:
			_expect_shown(result, "Bristling", "Bristling")

	# Shattering: more damage to an enemy whose die is frozen.
	for case in [["shatterpoint", 1], ["", 1], ["shatterpoint", 0]]:
		cm = _battle([_hero("a", {"dmg": 10}, {}, str(case[0]))], [_enemy("x")])
		_e(cm)["die_freeze_turns"] = int(case[1])
		_aim(cm, 0, 0)
		result = _round(cm, {0: 5})
		var shatter: int = _num("shatterpoint", "amount") if (case[0] != "" and int(case[1]) > 0) else 0
		_expect(_lost(_e(cm)) == 10 + shatter, "Shattering (trait %s, frozen %s): the attack deals %d (%d)" % [str(case[0] != ""), str(int(case[1]) > 0), 10 + shatter, _lost(_e(cm))])
		if shatter > 0:
			_expect_shown(result, "Shattering", "Shattering")

	# Sheltering: its heals also shield whoever they heal.
	for with in [true, false]:
		cm = _battle([_hero("a", {"heal": 6, "healTgt": true}, {}, "fieldTriage" if with else ""), _hero("b")], [_enemy("x")])
		_h(cm, 1)["current_hp"] = 50
		_h(cm, 0)["selected_target_id"] = "b"
		result = _round(cm, {0: 5})
		_expect(int(_h(cm, 1)["current_hp"]) == 56, "Sheltering: the heal is still 6 (%d)" % (int(_h(cm, 1)["current_hp"]) - 50))
		_expect(_shield_events(result, "b") == (_num("fieldTriage", "amount") if with else 0), "Sheltering %s: the healed hero gains %d shield (%d)" % ["on" if with else "off", _num("fieldTriage", "amount") if with else 0, _shield_events(result, "b")])
		if with:
			_expect_shown(result, "Sheltering", "Sheltering")

	# Reviving: its revive brings a hero back at more HP.
	for with in [true, false]:
		cm = _battle([_hero("a", {"revive": true, "healTgt": true, "revivePct": 50, "fallbackHeal": 20}, {}, "fieldSurgeon" if with else ""), _hero("b")], [_enemy("x")])
		_h(cm, 1)["dead"] = true
		_h(cm, 1)["current_hp"] = 0
		_h(cm, 0)["selected_target_id"] = "b"
		result = _round(cm, {0: 5})
		var want_hp: int = _num("fieldSurgeon", "pct") if with else 50
		_expect(not bool(_h(cm, 1)["dead"]) and int(_h(cm, 1)["current_hp"]) == want_hp, "Reviving %s: the hero returns at %d HP of 100 (%d)" % ["on" if with else "off", want_hp, int(_h(cm, 1)["current_hp"])])
		if with:
			_expect_shown(result, "Reviving", "Reviving")
	cm = _battle([_hero("a", {"revive": true, "healTgt": true, "revivePct": 50, "fallbackHeal": 20}, {}, "fieldSurgeon"), _hero("b")], [_enemy("x")])
	_h(cm, 1)["current_hp"] = 60
	_h(cm, 0)["selected_target_id"] = "b"
	_round(cm, {0: 5})
	_expect(int(_h(cm, 1)["current_hp"]) == 80, "Reviving: with nobody down the heal is the plain 20 (%d)" % (int(_h(cm, 1)["current_hp"]) - 60))
	cm = _battle([_hero("a", {"reviveAll": true, "revivePct": 30}, {}, "fieldSurgeon"), _hero("b")], [_enemy("x")])
	_h(cm, 1)["dead"] = true
	_h(cm, 1)["current_hp"] = 0
	_round(cm, {0: 5})
	_expect(int(_h(cm, 1)["current_hp"]) == 30, "Reviving: a revive of the whole squad keeps its own 30%% (%d)" % int(_h(cm, 1)["current_hp"]))

	# Reinforcing: while it lives, every shield the squad gains is larger.
	for case in [["reinforcedMesh", false], ["", false], ["reinforcedMesh", true]]:
		cm = _battle([_hero("a", {"shield": 0}, {}, str(case[0])), _hero("b", {"shield": 6})], [_enemy("x")])
		if case[1]:
			_h(cm, 0)["dead"] = true
			_h(cm, 0)["current_hp"] = 0
		result = _round(cm, {1: 5})
		var mesh: int = _num("reinforcedMesh", "amount") if (case[0] != "" and not case[1]) else 0
		_expect(_shield_events(result, "b") == 6 + mesh, "Reinforcing (trait %s, alive %s): a squadmate's shield is %d (%d)" % [str(case[0] != ""), str(not case[1]), 6 + mesh, _shield_events(result, "b")])
		if mesh > 0:
			_expect_shown(result, "Reinforcing", "Reinforcing")

	# Capacitive: while it lives, the Protocol cap is higher.
	for case in [["deepCells", false], ["", false], ["deepCells", true]]:
		cm = _battle([_hero("a", {"dmg": 1}, {}, str(case[0]))], [_enemy("x")])
		if case[1]:
			_h(cm)["dead"] = true
		var cap: int = int(_engine_for(cm).max_protocol(0))
		var raised: int = _num("deepCells", "amount") if (case[0] != "" and not case[1]) else 0
		_expect(cap == 10 + raised, "Capacitive (trait %s, alive %s): the Protocol cap is %d (%d)" % [str(case[0] != ""), str(not case[1]), 10 + raised, cap])

	# Shrouded: an ability that deals no damage cloaks the caster.
	for case in [["silentRunning", 5], ["", 5], ["silentRunning", 15]]:
		cm = _battle([_hero("a", {"shield": 4}, {"dmg": 5}, str(case[0]))], [_enemy("x")])
		_aim(cm, 0, 0)
		result = _round(cm, {0: int(case[1])})
		var shrouds: bool = case[0] != "" and int(case[1]) <= 10
		_expect(bool(_h(cm)["cloaked"]) == shrouds, "Shrouded (trait %s, %s ability): the hero is %s" % [str(case[0] != ""), "a no-damage" if int(case[1]) <= 10 else "an attack", "cloaked" if shrouds else "not cloaked"])
		if shrouds:
			_expect_shown(result, "Shrouded", "Shrouded")

	# Vanishing: once per battle, cloaks when damage leaves it below the line.
	for with in [true, false]:
		cm = _battle([_hero("a", {"shield": 0}, {}, "vanish" if with else "")], [_enemy("x", {"dmg": 30})])
		_e(cm)["selected_target_id"] = "a"
		_round(cm, {}, {0: 5})
		_expect(not bool(_h(cm)["cloaked"]), "Vanishing: at 70 HP of 100 nothing happens")
		_e(cm)["selected_target_id"] = "a"
		result = _round(cm, {}, {0: 5})
		_expect(int(_h(cm)["current_hp"]) == 40 and bool(_h(cm)["cloaked"]) == with, "Vanishing %s: at 40 HP of 100 the hero is %s" % ["on" if with else "off", "cloaked" if with else "not cloaked"])
		if with:
			_expect_shown(result, "Vanishing", "Vanishing")
		_h(cm)["cloaked"] = false
		_e(cm)["selected_target_id"] = "a"
		_round(cm, {}, {0: 5})
		_expect(int(_h(cm)["current_hp"]) == 10 and not bool(_h(cm)["cloaked"]), "Vanishing: it happens once a battle (%d HP, cloaked %s)" % [int(_h(cm)["current_hp"]), str(bool(_h(cm)["cloaked"]))])

	# Reaping: its execute triggers below a higher line.
	for case in [["reaper", 42], ["", 42], ["reaper", 60], ["", 30]]:
		cm = _battle([_hero("a", {"dmg": 10, "execute": true}, {}, str(case[0]))], [_enemy("x")])
		_e(cm)["current_hp"] = int(case[1])
		_aim(cm, 0, 0)
		result = _round(cm, {0: 5})
		var after_hit: int = int(case[1]) - 10
		var line: int = _num("reaper", "pct") if case[0] != "" else 25
		var want_left: int = after_hit - 8 if after_hit < line else after_hit
		_expect(int(_e(cm)["current_hp"]) == want_left, "Reaping (trait %s, enemy at %d of 100 after the hit): %d HP left (%d)" % [str(case[0] != ""), after_hit, want_left, int(_e(cm)["current_hp"])])
		if case[0] != "" and after_hit < line and after_hit >= 25:
			_expect_shown(result, "Reaping", "Reaping")

	# Shrieking: an enemy under its roll penalty takes damage each round.
	for with in [true, false]:
		cm = _battle([_hero("a", {"rfe": 2, "rfT": 2}, {}, "feedback" if with else "")], [_enemy("x")])
		_aim(cm, 0, 0)
		result = _round(cm, {0: 5})
		_expect(_lost(_e(cm)) == (_num("feedback", "amount") if with else 0), "Shrieking %s: the enemy under the roll penalty takes %d this round (%d)" % ["on" if with else "off", _num("feedback", "amount") if with else 0, _lost(_e(cm))])
		if with:
			_expect_shown(result, "Shrieking", "Shrieking")
			_expect(_logged(result, "Shrieking: Enemy x takes"), "Shrieking: the tick names the trait too (%s)" % str(result.get("log", [])))
		for _i in 4:
			_round(cm)
		var settled: int = _lost(_e(cm))
		_round(cm)
		_expect(_lost(_e(cm)) == settled, "Shrieking: it stops when the roll penalty ends (%d then %d)" % [settled, _lost(_e(cm))])

	# Siphoning: Protocol for each enemy its roll penalty lands on.
	for with in [true, false]:
		cm = _battle([_hero("a", {"rfe": 1, "rfT": 2, "rfeAll": true}, {}, "signalTheft" if with else "")], [_enemy("x"), _enemy("y")])
		result = _round(cm, {0: 5})
		var siphoned: int = int(cm.take_pending_protocol_grants())
		_expect(siphoned == (2 * _num("signalTheft", "amount") if with else 0), "Siphoning %s: %d Protocol for two enemies (%d)" % ["on" if with else "off", 2 * _num("signalTheft", "amount") if with else 0, siphoned])
		if with:
			_expect_shown(result, "Siphoning", "Siphoning")


# ── B3. The 250 XP pick (G-71) ───────────────────────────────────────────────
func _labels_of(node: Node, label_name: String) -> Array:
	var out: Array = []
	for label in node.find_children(label_name, "Label", true, false):
		out.append(str((label as Label).text))
	return out


func _frames(count: int) -> void:
	for _i in count:
		await process_frame


func _check_prestige_pick() -> void:
	var gs: Node = root.get_node("/root/GameState")
	_expect(int(gs.XP_TO_PRESTIGE) == 250 and int(_traits.PRESTIGE_XP) == 250, "pick: the trait is chosen at 250 XP")

	# Before the pick an evolved hero has no trait; the card shows the callsign only.
	gs.reset_run()
	gs.start_run(["pulse", "combat", "medic"], "facility", 5)
	gs.unit_evolutions["pulse"] = "Pyro Specialist"
	gs.unit_xp["pulse"] = 250
	gs.pending_evolution_unit_id = "pulse"
	_expect(gs.is_pending_trait_stage(), "pick: an evolved hero at 250 XP is at the trait stage")
	var names: Array = []
	for choice in gs.get_pending_trait_choices():
		names.append(str(choice["name"]))
	_expect(names == ["Smoldering", "Searing"], "pick: Pyro chooses between Smoldering and Searing (%s)" % str(names))
	_expect(_traits.marker_text(_traits.of_unit(gs.get_run_unit_data("pulse"))) == "", "pick: before it, the battle card has no title")
	_expect(not gs.apply_pending_trait("liveWire"), "pick: a trait of another branch is refused")
	_expect(not gs.apply_pending_trait("Flashpoint"), "pick: a Directive name is refused")

	# The 250 XP screen: two cards, trait copy, no Directive anywhere.
	var screen: Node = load("res://scenes/ui/EvolutionScreen.tscn").instantiate()
	root.add_child(screen)
	await _frames(3)
	_expect(_labels_of(screen, "TraitName") == ["SMOLDERING", "SEARING"], "250 XP screen: one card per trait (%s)" % str(_labels_of(screen, "TraitName")))
	_expect(_labels_of(screen, "TraitText") == [_traits.build("afterburn")["text"], _traits.build("flashpoint")["text"]], "250 XP screen: each card prints its trait's line (%s)" % str(_labels_of(screen, "TraitText")))
	_expect(_labels_of(screen, "TraitBecomes") == ["BATTLE CARD: SMOLDERING PYRO", "BATTLE CARD: SEARING PYRO"], "250 XP screen: each card shows the name the hero will carry (%s)" % str(_labels_of(screen, "TraitBecomes")))
	_expect(str(screen.summary_label.text) == "Pyro Specialist reached 250 XP. Choose a trait.", "250 XP screen: the summary says trait (%s)" % str(screen.summary_label.text))
	var buttons: Array = []
	for button in screen.find_children("ChooseTrait", "Button", true, false):
		buttons.append(str((button as Button).text))
	_expect(buttons == ["CHOOSE SMOLDERING", "CHOOSE SEARING"], "250 XP screen: the buttons name the trait (%s)" % str(buttons))
	for node in screen.find_children("*", "Control", true, false):
		var shown: String = str(node.get("text")) if (node is Label or node is Button) else ""
		_expect(not shown.to_lower().contains("directive") and not shown.contains("—"), "250 XP screen: no Directive and no em dash in '%s'" % shown)
	screen.queue_free()
	await _frames(3)

	_expect(gs.apply_pending_trait("flashpoint"), "pick: the second option is accepted")
	var picked: Resource = gs.get_run_unit_data("pulse")
	_expect(str(_traits.of_unit(picked).get("name", "")) == "Searing" and _traits.marker_text(_traits.of_unit(picked)) == "SEARING", "pick: Pyro now carries Searing as its title (%s)" % str(_traits.of_unit(picked)))
	_expect(str(_h(_battle([picked], [_enemy("x")]))["trait"]) == "flashpoint", "pick: its battle state carries the trait id")
	_expect(gs.pending_evolution_unit_id == "" and not gs._is_evolution_eligible("pulse"), "pick: a hero with its trait has no further stop")
	# The card: no title line without a trait, the trait above the callsign with one.
	for case in [["", false], ["SEARING", true]]:
		var card: Control = load("res://scripts/ui/compact_unit_card.gd").new()
		root.add_child(card)
		card.configure({"side": "hero", "name": "PYRO", "trait": case[0]})
		_expect((card.find_child("TraitMarker", true, false) as Label).visible == bool(case[1]), "card: the title line is %s for trait '%s'" % ["shown" if case[1] else "hidden", str(case[0])])
		card.free()

	# The 100 XP picker: each branch previews the two traits it can earn; what
	# each does is in the expanded view.
	gs.reset_run()
	gs.start_run(["pulse", "combat", "medic"], "facility", 5)
	gs.pending_evolution_unit_id = "pulse"
	screen = load("res://scenes/ui/EvolutionScreen.tscn").instantiate()
	root.add_child(screen)
	await _frames(3)
	_expect(_labels_of(screen, "TraitLine") == ["AT 250 XP: SMOLDERING or SEARING", "AT 250 XP: CHARGED or FORKING"], "100 XP picker: each branch previews its two traits (%s)" % str(_labels_of(screen, "TraitLine")))
	var effects: Array = _labels_of(screen, "TraitEffect_*")
	_expect(effects.size() == 4 and effects.has(_traits.line(_traits.build("afterburn"))) and effects.has(_traits.line(_traits.build("flashpoint"))) and effects.has(_traits.line(_traits.build("conductor"))), "100 XP picker: the expanded view prints each trait's effect (%s)" % str(effects))
	for label in screen.find_children("TraitEffect_*", "Label", true, false):
		_expect(not (label as Label).is_visible_in_tree(), "100 XP picker: the effects are in the expanded view, not the minimized card")
	screen.queue_free()
	await _frames(3)
	gs.reset_run()

	# Saved runs. A hero that had a Directive keeps its 250 XP pick: the trait
	# the Directive became, or the branch's signature trait when it was not
	# converted. A hero that evolved and had no Directive has no trait.
	var all_ok: bool = true
	for hero in dm().units.values():
		for path in hero.evolution_paths:
			var key: String = "%s/%s" % [hero.id, str(path["id"])]
			for directive_name in LEGACY_DIRECTIVES.get(key, []):
				gs.reset_run()
				gs.start_run([hero.id, "combat" if hero.id != "combat" else "pulse", "medic" if hero.id != "medic" else "pulse"], "facility", 5)
				gs.unit_evolutions[hero.id] = str(path["name"])
				gs.unit_directives[hero.id] = directive_name
				var saved: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
				gs.reset_run()
				gs.load_from_dict(saved)
				var now: String = str(_traits.of_unit(gs.get_run_unit_data(hero.id)).get("name", ""))
				var want: String = str(LEGACY_DIRECTIVES[key][directive_name])
				if now != want:
					all_ok = false
					_errors.append("saved run: %s with the Directive %s now has %s (%s)" % [str(path["name"]), directive_name, want, now])
				# Saving and loading again changes nothing.
				var again: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
				gs.load_from_dict(again)
				_expect(str(_traits.of_unit(gs.get_run_unit_data(hero.id)).get("name", "")) == want, "saved run: %s keeps %s on the next load" % [str(path["name"]), want])
	_expect(all_ok and LEGACY_DIRECTIVES.size() == 16, "saved run: all 32 Directives were checked")
	var converted: int = 0
	for key in LEGACY_DIRECTIVES:
		for directive_name in LEGACY_DIRECTIVES[key]:
			if _traits.legacy_directive_trait(directive_name) != "":
				converted += 1
				_expect(str(LEGACY_DIRECTIVES[key][directive_name]) == str(PRESTIGE_TRAITS[key][1]), "saved run: %s became its branch's second trait" % directive_name)
			else:
				_expect(str(LEGACY_DIRECTIVES[key][directive_name]) == str(PRESTIGE_TRAITS[key][0]), "saved run: %s was not converted, so the branch's first trait stands in" % directive_name)
	_expect(converted == 16, "saved run: sixteen Directives became traits (%d)" % converted)
	gs.reset_run()
	gs.start_run(["pulse", "combat", "medic"], "facility", 5)
	gs.unit_evolutions["pulse"] = "Pyro Specialist"
	var no_pick: Dictionary = JSON.parse_string(JSON.stringify(gs.to_save_dict()))
	gs.reset_run()
	gs.load_from_dict(no_pick)
	_expect(_traits.of_unit(gs.get_run_unit_data("pulse")).is_empty() and str(gs.get_run_unit_data("pulse").display_name) == "Pyro Specialist", "saved run: a hero that evolved and had not reached 250 XP has no trait, and is still evolved")
	gs.reset_run()


# ── C. The round-start traits and the dice ────────────────────────────────────
func _engine_for(cm: Object) -> Object:
	return load(ENGINE_SOURCE).new(cm, cm.roll_provider, _dice)


# A battle state whose enemy dice read `dice` (slot order).
func _dice_state(cm: Object, dice: Array) -> Object:
	var bs: Object = load(STATE_SOURCE).new()
	for index in dice.size():
		bs.enemy_rolls[str(_e(cm, index)["id"])] = int(dice[index])
	for hero_state in cm.get_hero_states():
		bs.hero_rolls[str(hero_state["id"])] = 10
	return bs


func _values(engine: Object, cm: Object, bs: Object) -> Array:
	var out: Array = []
	for enemy_state in cm.get_enemy_states():
		out.append(int(engine.effective_enemy_roll(enemy_state, str(enemy_state["id"]), bs)))
	return out


func _check_round_start() -> void:
	# Glacial: shield for each frozen enemy.
	var cm: Object = _battle([_hero("a", {}, {}, "glacialArmor")], [_enemy("x"), _enemy("y"), _enemy("z")])
	_e(cm, 0)["die_freeze_turns"] = 1
	_e(cm, 2)["die_freeze_turns"] = 2
	var engine: Object = _engine_for(cm)
	var fired: Array = engine.apply_round_start_traits(_dice_state(cm, [5, 5, 5]))
	_expect(int(_h(cm)["shield"]) == 2 * _num("glacialArmor", "amount"), "Glacial: two frozen enemies give %d shield (%d)" % [2 * _num("glacialArmor", "amount"), int(_h(cm)["shield"])])
	_expect(fired.size() == 1 and str(fired[0]["name"]) == "Glacial" and str(fired[0]["text"]).begins_with("Glacial: "), "Glacial: it reports itself for the chip and the log (%s)" % str(fired))
	cm = _battle([_hero("a", {}, {}, "glacialArmor")], [_enemy("x")])
	fired = _engine_for(cm).apply_round_start_traits(_dice_state(cm, [5]))
	_expect(int(_h(cm)["shield"]) == 0 and fired.is_empty(), "Glacial: no frozen enemy, no shield and no chip")

	# Entrenched: shield while below half HP.
	for hp in [40, 50, 60]:
		cm = _battle([_hero("a", {}, {}, "dugIn")], [_enemy("x")])
		_h(cm)["current_hp"] = hp
		fired = _engine_for(cm).apply_round_start_traits(_dice_state(cm, [5]))
		_expect(int(_h(cm)["shield"]) == (_num("dugIn", "amount") if hp < 50 else 0), "Entrenched at %d of 100 HP: %d shield (%d)" % [hp, _num("dugIn", "amount") if hp < 50 else 0, int(_h(cm)["shield"])])
		_expect(fired.size() == (1 if hp < 50 else 0), "Entrenched at %d HP: %s" % [hp, "reported" if hp < 50 else "silent"])

	# Static: the highest enemy die drops.
	cm = _battle([_hero("a", {}, {}, "static")], [_enemy("x"), _enemy("y"), _enemy("z")])
	engine = _engine_for(cm)
	var bs: Object = _dice_state(cm, [7, 12, 9])
	fired = engine.apply_round_start_traits(bs)
	_expect(_values(engine, cm, bs) == [7, 12 - _num("static", "amount"), 9], "Static: the highest die drops by %d (%s)" % [_num("static", "amount"), str(_values(engine, cm, bs))])
	_expect(bs.enemy_rolls[str(_e(cm, 1)["id"])] == 12, "Static: the landed number is kept; the change is a shift on the die's one value")
	_expect(fired.size() == 1 and str(fired[0]["name"]) == "Static", "Static: it reports itself (%s)" % str(fired))
	# The faces the die prints still hold its new value (the tray tips onto it).
	var faces: Array = engine.current_face_values(_e(cm, 1), str(_e(cm, 1)["id"]), false, bs)["faces"]
	_expect(faces.has(11), "Static: the die has a face showing its new value")

	# A frozen die keeps its number: Static takes the next highest.
	cm = _battle([_hero("a", {}, {}, "static")], [_enemy("x"), _enemy("y"), _enemy("z")])
	engine = _engine_for(cm)
	_e(cm, 1)["die_freeze_turns"] = 1
	_e(cm, 1)["frozen_die_value"] = 12
	_e(cm, 1)["die_freeze_repeat_this_round"] = true
	bs = _dice_state(cm, [7, 12, 9])
	engine.apply_round_start_traits(bs)
	_expect(_values(engine, cm, bs) == [7, 12, 8], "Static: a frozen die is passed over and the next highest drops (%s)" % str(_values(engine, cm, bs)))

	# A hijacked die is passed over too.
	cm = _battle([_hero("a", {}, {}, "static")], [_enemy("x"), _enemy("y")])
	engine = _engine_for(cm)
	_e(cm, 1)["hijack_pending"] = true
	bs = _dice_state(cm, [7, 12])
	engine.apply_round_start_traits(bs)
	_expect(int(bs.enemy_roll_shifts.get(str(_e(cm, 1)["id"]), 0)) == 0 and int(bs.enemy_roll_shifts.get(str(_e(cm, 0)["id"]), 0)) == -1, "Static: a hijacked die is passed over (%s)" % str(bs.enemy_roll_shifts))

	# A die on 1 cannot drop: nothing happens and nothing is reported.
	cm = _battle([_hero("a", {}, {}, "static")], [_enemy("x")])
	engine = _engine_for(cm)
	bs = _dice_state(cm, [1])
	fired = engine.apply_round_start_traits(bs)
	_expect(_values(engine, cm, bs) == [1] and fired.is_empty() and int(bs.enemy_roll_shifts.get(str(_e(cm)["id"]), 0)) == 0, "Static: a die on 1 stays on 1, silently")

	# Zealous: the lowest enemy die rises.
	cm = _battle([_hero("a")], [_enemy("x", {}, {}, "litany"), _enemy("y"), _enemy("z")])
	engine = _engine_for(cm)
	bs = _dice_state(cm, [12, 7, 9])
	fired = engine.apply_round_start_traits(bs)
	_expect(_values(engine, cm, bs) == [12, 7 + _num("litany", "amount"), 9], "Zealous: the lowest die rises by %d (%s)" % [_num("litany", "amount"), str(_values(engine, cm, bs))])
	_expect(fired.size() == 1 and str(fired[0]["name"]) == "Zealous", "Zealous: it reports itself (%s)" % str(fired))

	# Zealous and a frozen lowest die: the next lowest rises.
	cm = _battle([_hero("a")], [_enemy("x", {}, {}, "litany"), _enemy("y"), _enemy("z")])
	engine = _engine_for(cm)
	_e(cm, 1)["die_freeze_turns"] = 1
	_e(cm, 1)["frozen_die_value"] = 3
	_e(cm, 1)["die_freeze_repeat_this_round"] = true
	bs = _dice_state(cm, [12, 3, 9])
	engine.apply_round_start_traits(bs)
	_expect(_values(engine, cm, bs) == [12, 3, 11], "Zealous: a frozen die is passed over and the next lowest rises (%s)" % str(_values(engine, cm, bs)))

	# A jammed die is never lifted past its cap.
	cm = _battle([_hero("a")], [_enemy("x", {}, {}, "litany"), _enemy("y")])
	engine = _engine_for(cm)
	_e(cm, 1)["jam_cap"] = 10
	bs = _dice_state(cm, [15, 9])
	engine.apply_round_start_traits(bs)
	_expect(_values(engine, cm, bs) == [15, 10], "Zealous: a jammed die rises to its cap and no further (%s)" % str(_values(engine, cm, bs)))

	# Both in one round: Static first, then Zealous on what is lowest after it.
	cm = _battle([_hero("a", {}, {}, "static")], [_enemy("x", {}, {}, "litany"), _enemy("y")])
	engine = _engine_for(cm)
	bs = _dice_state(cm, [8, 7])
	fired = engine.apply_round_start_traits(bs)
	_expect(_values(engine, cm, bs) == [9, 7], "Static then Zealous on 8 and 7: 8 drops to 7, then the first 7 rises to 9 (%s)" % str(_values(engine, cm, bs)))
	_expect(fired.size() == 2 and str(fired[0]["name"]) == "Static" and str(fired[1]["name"]) == "Zealous", "both: Static reports first, then Zealous")

	# The round resolves on the shifted value, and the shift is spent with the round.
	cm = _battle([_hero("a", {}, {}, "static")], [_enemy("x", {"dmg": 3}, {"dmg": 30})])
	engine = _engine_for(cm)
	bs = _dice_state(cm, [11])
	engine.apply_round_start_traits(bs)
	_e(cm)["selected_target_id"] = "a"
	engine.resolve_step(bs)
	_expect(_lost(_h(cm)) == 3, "Static: an 11 dropped to 10 resolves as the lower ability (3 damage, got %d)" % _lost(_h(cm)))
	_expect(bs.enemy_roll_shifts.is_empty(), "Static: the shift is cleared when the round resolves")


# ── D. Where a trait is shown ─────────────────────────────────────────────────
func _check_shown() -> void:
	var inspect: Object = load(INSPECT_SOURCE)
	var volt: Resource = dm().get_enemy_by_display_name("Volt Enforcer")
	var drone: Resource = dm().get_enemy_by_display_name("Scrap Drone")
	if volt == null or drone == null:
		_errors.append("shown: fixture units")
		return
	# Long-press: the trait leads the unit's inspect, above the roll breakdown.
	var entry: Dictionary = inspect.trait_entry(volt)
	_expect(str(entry.get("text", "")) == _traits.line(_traits.of_unit(volt)), "inspect: the trait entry is the trait's line (%s)" % str(entry))
	_expect(inspect.trait_entry(drone).is_empty(), "inspect: a unit without a trait has no entry")
	var resolved: Dictionary = inspect.resolve_unit(volt, {})
	var statuses: Array = resolved.get("statuses", [])
	_expect(not statuses.is_empty() and str((statuses[0] as Dictionary).get("text", "")).begins_with("VOLATILE: "), "inspect: Volt Enforcer's inspect leads with VOLATILE (%s)" % str(statuses))
	_expect(str((statuses[0] as Dictionary).get("text", "")).contains("4 damage to each hero"), "inspect: and says what it does")
	# The battle card's marker; Volt Enforcer's is a warning that says the cost.
	_expect(_traits.marker_text(_traits.of_unit(volt)) == "VOLATILE" and _traits.is_warning(_traits.of_unit(volt)), "card: Volt Enforcer's marker is VOLATILE, flagged as a warning (%s)" % _traits.marker_text(_traits.of_unit(volt)))
	var stalker: Resource = dm().get_enemy_by_display_name("Spine Stalker")
	_expect(_traits.marker_text(_traits.of_unit(stalker)) == "BARBED" and not _traits.is_warning(_traits.of_unit(stalker)), "card: any other trait's marker is its name")
	_expect(_traits.marker_text(_traits.of_unit(drone)) == "", "card: a unit without a trait has no marker")
	# The warning marker is a different colour from every other trait's amber,
	# and from the enemy name under it. Never green (INVARIANTS #7).
	var colours: Array = []
	for unit in [volt, stalker]:
		var card: Control = load("res://scripts/ui/compact_unit_card.gd").new()
		root.add_child(card)
		card.configure({"side": "enemy", "name": unit.battle_name(), "trait": _traits.marker_text(_traits.of_unit(unit)), "trait_warning": _traits.is_warning(_traits.of_unit(unit))})
		colours.append([(card.find_child("TraitMarker", true, false) as Label).get_theme_color("font_color"), (card._name_label as Label).get_theme_color("font_color")])
		card.free()
	var warn_colour: Color = colours[0][0]
	_expect((colours[1][0] as Color).is_equal_approx(PixelUI.DT_AMBER), "card: a trait marker is amber (%s)" % str(colours[1][0]))
	_expect(_colour_gap(warn_colour, PixelUI.DT_AMBER) >= 0.5, "card: VOLATILE is drawn in a colour apart from the amber of the other traits (%s vs %s)" % [warn_colour.to_html(false), PixelUI.DT_AMBER.to_html(false)])
	_expect(_colour_gap(warn_colour, colours[0][1]) >= 0.5, "card: VOLATILE is drawn in a colour apart from the name under it (%s vs %s)" % [warn_colour.to_html(false), (colours[0][1] as Color).to_html(false)])
	_expect(warn_colour.r > warn_colour.g * 2.0, "card: the warning colour is a red, never a green (%s)" % warn_colour.to_html(false))
	# Help: an evolution's breakdown is built from its group, trait included.
	var help: Node = load("res://scripts/ui/help_menu.gd").new()
	var pyro: Dictionary = {}
	for group in help._codex_evolution_groups(dm().get_unit("pulse")):
		if str(group.get("id", "")) == "pyro":
			pyro = group
	var help_payload: Dictionary = help._evolution_breakdown_payload("PYRO", int(pyro.get("hp", 0)), pyro.get("abilities", []), pyro.get("traits", []))
	var help_statuses: Array = help_payload.get("statuses", [])
	_expect(help_statuses.size() >= 3 and str((help_statuses[0] as Dictionary).get("text", "")) == "AT 250 XP: SMOLDERING or SEARING", "help: Pyro's breakdown leads with the 250 XP choice (%s)" % str(help_statuses))
	_expect(help_statuses.size() >= 3 and str((help_statuses[1] as Dictionary).get("text", "")).begins_with("SMOLDERING: ") and str((help_statuses[2] as Dictionary).get("text", "")).begins_with("SEARING: "), "help: then each trait's own line (%s)" % str(help_statuses))
	_expect(str((help._enemy_breakdown_payload(volt).get("statuses", [{}]) as Array)[0].get("text", "")).begins_with("VOLATILE: "), "help: Volt Enforcer's breakdown leads with VOLATILE")
	help.free()


func _colour_gap(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


# ── E. Copy ───────────────────────────────────────────────────────────────────
func _check_copy() -> void:
	# A name is one title word, read with the callsign: BARBED STALKER (G-63).
	var title: RegEx = RegEx.create_from_string("^[A-Z][A-Za-z-]*$")
	var names: Array = []
	for trait_id in (_traits.data()["traits"] as Dictionary):
		var trait_name: String = _traits.name_of(trait_id)
		names.append(trait_name)
		_expect(title.search(trait_name) != null, "copy: the trait name '%s' is one title word" % trait_name)
		_expect(not RETIRED_NAMES.has(trait_name), "copy: the retired name '%s' is not in the data" % trait_name)
	# No log line, chip or marker types a trait's name: it is read from the data.
	for path in NAME_SOURCES:
		var source: String = FileAccess.get_file_as_string(path)
		_expect(source != "", "copy: %s is readable" % path)
		for typed in names + RETIRED_NAMES:
			for form in ['"%s: ' % typed, '"%s"' % str(typed).to_upper(), '"%s: ' % str(typed).to_upper()]:
				_expect(not source.contains(form), "copy: %s does not type the trait name %s" % [path.get_file(), form])
	var units: Array = dm().enemies.values()
	for hero in dm().units.values():
		for path in hero.evolution_paths:
			for option in path.get("traits", []):
				var holder: UnitData = UnitData.new()
				holder.display_name = str(path["name"])
				holder.unit_trait = option
				units.append(holder)
	for unit in units:
		var carried: Dictionary = _traits.of_unit(unit)
		if carried.is_empty():
			continue
		var text: String = str(carried["text"])
		var who: String = "%s (%s)" % [str(carried["name"]), str(unit.display_name)]
		_expect(not text.contains("{") and not text.contains("}"), "copy: %s has no unfilled number (%s)" % [who, text])
		_expect(not text.contains("—") and not str(carried["name"]).contains("—"), "copy: %s has no em dash" % who)
		_expect(text.ends_with(".") and text.length() <= MAX_TRAIT_LINE, "copy: %s is one short sentence (%d chars: %s)" % [who, text.length(), text])
		for word in BAND_WORDS:
			_expect(not text.to_lower().contains(word), "copy: %s does not use the band word '%s'" % [who, word])
		for key in carried:
			if carried[key] is float or carried[key] is int:
				_expect(text.contains(str(int(carried[key]))) or key == "turns" and text.contains("%d turns" % int(carried[key])), "copy: %s prints its number %s = %d (%s)" % [who, key, int(carried[key]), text])
	# The two traits keyed to a roll window print that unit's own first window.
	var ravager: Dictionary = {}
	for path in dm().get_unit("combat").evolution_paths:
		if str(path["id"]) == "ravager":
			ravager = path
	var first: Dictionary = (ravager.get("abilities", [{}]) as Array)[0]
	var bloodlust_text: String = str(((ravager.get("traits", [{}]) as Array)[0] as Dictionary).get("text", ""))
	_expect(bloodlust_text.contains("After rolling %d-%d," % [int(first.get("min", 0)), int(first.get("max", 0))]), "copy: Bloodlust prints Ravager's first roll window (%s)" % bloodlust_text)
	var blade: Resource = dm().get_enemy_by_display_name("Phaseblade")
	var blade_first: Dictionary = blade.dice_ranges[0]
	_expect(str(_traits.of_unit(blade)["text"]).contains("After rolling %d-%d," % [int(blade_first["min"]), int(blade_first["max"])]), "copy: Flickering prints Phaseblade's first roll window (%s)" % str(_traits.of_unit(blade)["text"]))


# ── F. A live round ───────────────────────────────────────────────────────────
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


func _chip_texts(scene: Node) -> Array:
	var out: Array = []
	for child in scene.float_layer.get_children():
		if str(child.name).begins_with("TraitChip") and not child.is_queued_for_deletion():
			for label in child.find_children("*", "Label", true, false):
				out.append(str((label as Label).text))
	return out


# Every trait name and every callsign under one fits its line of the battle
# card as the battle lays it out at phone width (1080 design px, three cards
# across). The two lines read as the unit's full name: BARBED / STALKER.
func _check_card_fit(card: Control) -> void:
	if card == null:
		_errors.append("fit: no battle card to measure")
		return
	var marker: Label = card.find_child("TraitMarker", true, false) as Label
	var name_label: Label = card._name_label
	var pairs: Array = []
	for enemy in dm().enemies.values():
		if not _traits.of_unit(enemy).is_empty():
			pairs.append([_traits.marker_text(_traits.of_unit(enemy)), str(enemy.battle_name()).to_upper()])
	for hero in dm().units.values():
		for path in hero.evolution_paths:
			var callsign: String = str(path.get("callsign", ""))
			for option in path.get("traits", []):
				pairs.append([_traits.marker_text(option), (callsign if callsign != "" else str(path.get("name", ""))).to_upper()])
	_expect(pairs.size() >= 48, "fit: every unit with a trait is measured, both options of every branch (%d)" % pairs.size())
	var widest: Array = [0.0, "", 0.0, ""]
	for pair in pairs:
		var trait_w: float = marker.get_theme_font("font").get_string_size(str(pair[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, marker.get_theme_font_size("font_size")).x
		var name_w: float = name_label.get_theme_font("font").get_string_size(str(pair[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, name_label.get_theme_font_size("font_size")).x
		_expect(trait_w <= marker.size.x, "fit: %s %s: the trait is %d px wide on a %d px line" % [str(pair[0]), str(pair[1]), int(trait_w), int(marker.size.x)])
		_expect(name_w <= name_label.size.x, "fit: %s %s: the callsign is %d px wide on a %d px line" % [str(pair[0]), str(pair[1]), int(name_w), int(name_label.size.x)])
		if trait_w > float(widest[0]):
			widest[0] = trait_w
			widest[1] = str(pair[0])
		if name_w > float(widest[2]):
			widest[2] = name_w
			widest[3] = str(pair[1])
	print("[TRAITS] fit: %d pairs on a %d px line; widest trait %s %d px, widest callsign %s %d px" % [pairs.size(), int(marker.size.x), str(widest[1]), int(widest[0]), str(widest[3]), int(widest[2])])


func _check_live() -> void:
	Engine.physics_ticks_per_second = 120 * SPEED
	Engine.time_scale = SPEED
	Engine.max_physics_steps_per_frame = 64
	for no_animations in [false, true]:
		sm().set_setting("no_animations", no_animations)
		var gs: Node = root.get_node("/root/GameState")
		sm().clear_run_save()
		gs.reset_run()
		gs.start_run(["breaker", "combat", "medic"], "facility", 77)
		gs.unit_evolutions["breaker"] = "Noise Specialist"
		gs.unit_directives["breaker"] = "static"  # its 250 XP pick (G-71)
		gs.advance_to_next_battle()
		change_scene_to_file(BATTLE_SCENE)
		for _i in 300:
			await process_frame
			if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE and current_scene.is_node_ready():
				break
		await create_timer(0.8).timeout
		var scene: Node = current_scene
		var mode: String = "no animations" if no_animations else "animated"
		if scene == null or scene.scene_file_path != BATTLE_SCENE:
			_errors.append("live (%s): battle scene did not load" % mode)
			return
		var cm: Object = scene.combat_manager
		var enemies: Array = cm.get_enemy_states()
		var noise: Dictionary = cm.get_hero_states()[0]
		_expect(str(noise.get("trait", "")) == "static", "live (%s): the Noise Specialist carries Static (%s)" % [mode, str(noise.get("trait", ""))])
		_expect(enemies.size() >= 2, "live (%s): fixture, two enemies" % mode)
		if enemies.size() < 2:
			return
		if not no_animations:
			_check_card_fit(scene._feedback._find_card_by_state_id("hero", str(noise["id"])))
		# The card carries the trait marker, and not in a portrait corner.
		var card: Control = scene._feedback._find_card_by_state_id("hero", str(noise["id"]))
		var marker: Control = card.find_child("TraitMarker", true, false) as Control if card != null else null
		_expect(marker != null and marker.visible, "live (%s): the hero's card shows a trait marker" % mode)
		if marker != null and card.has_method("portrait_rect"):
			_expect(not (card.portrait_rect() as Rect2).intersects(marker.get_global_rect()), "live (%s): the marker is clear of the portrait" % mode)
		var plain_card: Control = scene._feedback._find_card_by_state_id("hero", str(cm.get_hero_states()[1]["id"]))
		var plain_marker: Control = plain_card.find_child("TraitMarker", true, false) as Control if plain_card != null else null
		_expect(plain_marker == null or not plain_marker.visible, "live (%s): a base hero's card has no marker" % mode)

		var rig: Dictionary = {}
		for hero_state in cm.get_hero_states():
			rig["hero:%s" % hero_state["id"]] = 9
		rig["enemy:%s" % enemies[0]["id"]] = 14
		for index in range(1, enemies.size()):
			rig["enemy:%s" % enemies[index]["id"]] = 6
		scene.dice_tray_3d.set_rigged_results(rig)
		await scene._begin_targeting_phase()
		# Right after the dice land: the chip is up, in either mode.
		_expect(_chip_texts(scene).has("STATIC"), "live (%s): a STATIC chip appears on the unit as the trait fires (%s)" % [mode, str(_chip_texts(scene))])
		await _settle(scene)
		var top_id: String = str(enemies[0]["id"])
		var landed: int = int(scene.enemy_rolls.get(top_id, 0))
		var acts_on: int = int(scene._get_effective_enemy_roll(enemies[0], top_id))
		var plain: int = int(cm.get_effective_roll(enemies[0], landed))
		_expect(acts_on == plain - _num("static", "amount"), "live (%s): the highest enemy die dropped by %d (landed %d, plain %d, acts on %d)" % [mode, _num("static", "amount"), landed, plain, acts_on])
		var die: Object = scene.dice_tray_3d._die_by_key.get("enemy:%s" % top_id)
		_expect(die != null and int(die.get_meta("shown_value", -1)) == acts_on, "live (%s): the die shows the value the unit acts on (%s vs %d)" % [mode, str(die.get_meta("shown_value", -1)) if die != null else "no die", acts_on])
		_expect(int(scene.dice_tray_3d.up_face_numeral("enemy", top_id)) == acts_on, "live (%s): the face on top prints that value (%d)" % [mode, int(scene.dice_tray_3d.up_face_numeral("enemy", top_id))])
		var log_text: String = str(scene.battle_log_label.get_parsed_text())
		_expect(log_text.contains("Static: "), "live (%s): the battle log names the trait" % mode)
		sm().clear_run_save()
