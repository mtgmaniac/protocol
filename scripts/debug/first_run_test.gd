# First run gate (G-72, Kev 2026-10-10).
#
#   godot --headless --path . -s scripts/debug/first_run_test.gd [-- --first-run-break=traits_on]
#
# Elites and Mantle Hunt beasts have no trait until the player's first run
# ends, win or lose. A profile flag tracks it. Hero traits are not affected.
# Pinned here:
#   A. flag     a new profile has not finished a run; a harness reads as past
#               the first run unless a test turns the real rule on.
#   B. units    on a first run, the copy a battle fields of every enemy that
#               has a trait carries none (the data itself is untouched); after
#               the first run it carries its trait.
#   C. combat   on a first run no enemy trait triggers (Volatile deals nothing
#               when the unit dies, Barbed nothing when it is hit); after it,
#               both do. A hero's trait works on a first run.
#   D. shown    on a first run an enemy's inspect has no trait line, in a
#               battle and in the Help reference; a hero's still has one.
#   E. run end  a defeat sets the flag, a victory sets the flag, an abandoned
#               run and the tutorial do not; the flag is set at run end, so the
#               run in progress is not changed.
#   F. profile  a profile that had already finished a run before the flag
#               existed loads with it set; one that had not, with it unset.
#   G. one rule every battle builds its enemies through
#               DataManager.enemy_for_battle: the live lineup and its summons,
#               a restored checkpoint, the sim.
#   H. live     a real battle against a Mantle Hunt beast: on a first run its
#               card has no title line and its state no trait; after the first
#               run the card reads FERAL.
# scripts/checks/break_gate.py reruns it with each SaveManager FIRST_RUN_BREAK_ARG
# mode (traits_on, no_flag) and requires a FAIL.
extends SceneTree

const COMBAT_SOURCE := "res://scripts/battle/combat_manager.gd"
const DICE_SOURCE := "res://scripts/battle/dice_manager.gd"
const SEEDED_SOURCE := "res://scripts/sim/seeded_roll_provider.gd"
const TRAITS_SOURCE := "res://scripts/battle/unit_traits.gd"
const INSPECT_SOURCE := "res://scripts/ui/inspect_resolver.gd"
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
# Where a battle's enemies are built. Each asks DataManager for the copy.
const ENEMY_BUILDERS := ["res://scripts/battle/battle_scene.gd", "res://scripts/battle/battle_checkpoint.gd", "res://scripts/sim/sim_runner.gd"]
const SQUAD := ["combat", "engineer", "medic"]

var _errors: PackedStringArray = []
var _traits: Object
var _dice: Object


func _initialize() -> void:
	call_deferred("_run")


func _expect(ok: bool, what: String) -> void:
	if not ok and _errors.size() < 40:
		_errors.append(what)


func sm() -> Node:
	return root.get_node("/root/SaveManager")


func dm() -> Node:
	return root.get_node("/root/DataManager")


func gs() -> Node:
	return root.get_node("/root/GameState")


func _run() -> void:
	await process_frame
	root.get_node("/root/AudioManager").set_suppressed(true)
	_traits = load(TRAITS_SOURCE)
	_dice = load(DICE_SOURCE).new()
	sm().set_setting("ability_primers_enabled", false)

	# A. A harness is past the first run; the gate turns the real rule on.
	sm().data = sm().default_data()
	_expect(not bool(sm().data["onboarding"]["first_run_finished"]), "flag: a new profile has not finished a run")
	_expect(sm().enemy_traits_enabled(), "flag: a harness reads as past the first run, so the sim and the other gates keep enemy traits")
	sm().force_first_run_gating_for_test()
	_expect(not sm().enemy_traits_enabled(), "flag: with the real rule on, a new profile has no enemy traits")

	_check_units(false)
	_check_combat(false)
	_check_shown(false)
	await _check_live(false)
	_check_run_end()
	_expect(sm().enemy_traits_enabled(), "run end: enemy traits are on once the first run has ended")
	_check_units(true)
	_check_combat(true)
	_check_shown(true)
	await _check_live(true)
	_check_profiles()
	_check_one_rule()

	for error in _errors:
		print("[FIRST_RUN] FAIL - %s" % error)
	print("[FIRST_RUN] %s" % ("PASS" if _errors.is_empty() else "FAIL - %d check(s)" % _errors.size()))
	sm().clear_run_save()
	if current_scene != null:
		unload_current_scene()
	await create_timer(0.3).timeout
	quit(0 if _errors.is_empty() else 1)


func _when(after: bool) -> String:
	return "after the first run" if after else "first run"


# Every enemy that has a trait in the data.
func _trait_enemies() -> Array:
	var out: Array = []
	for enemy in dm().enemies.values():
		if not _traits.of_unit(enemy).is_empty():
			out.append(enemy)
	return out


# B. The copy a battle fields.
func _check_units(after: bool) -> void:
	var carriers: Array = _trait_enemies()
	_expect(carriers.size() == 16, "units: sixteen enemies have a trait in the data (%d)" % carriers.size())
	for enemy in carriers:
		var fielded: Resource = dm().enemy_for_battle(enemy)
		var carried: String = str(_traits.of_unit(fielded).get("name", ""))
		var want: String = str(_traits.of_unit(enemy).get("name", "")) if after else ""
		_expect(carried == want, "units (%s): %s is fielded with %s (%s)" % [_when(after), str(enemy.display_name), "its trait " + want if after else "no trait", carried if carried != "" else "none"])
		_expect(fielded != enemy and not _traits.of_unit(enemy).is_empty(), "units (%s): the data for %s is untouched" % [_when(after), str(enemy.display_name)])
	var plain: Resource = dm().get_enemy_by_display_name("Scrap Drone")
	_expect(_traits.of_unit(dm().enemy_for_battle(plain)).is_empty(), "units (%s): an enemy without a trait still has none" % _when(after))


func _battle(heroes: Array, enemies: Array) -> Object:
	var cm: Object = load(COMBAT_SOURCE).new()
	cm.roll_provider = load(SEEDED_SOURCE).new(1)
	cm.setup_battle(heroes, enemies)
	return cm


func _band(ability_name: String, raw: Dictionary) -> Dictionary:
	return {"min": 1, "max": 20, "zone": "band1", "ability_name": ability_name, "description": "", "raw": raw.duplicate(true)}


func _hero(id: String, raw: Dictionary, trait_id: String = "") -> UnitData:
	var unit: UnitData = UnitData.new()
	unit.id = id
	unit.display_name = "Hero %s" % id
	unit.max_hp = 100
	var kit: Array[Dictionary] = [_band("Test Move", raw)]
	unit.dice_ranges = kit
	unit.unit_trait = _traits.build(trait_id, unit.dice_ranges)
	return unit


func _lost(state: Dictionary) -> int:
	return int(state["max_hp"]) - int(state["current_hp"])


func _trait_events(result: Dictionary) -> int:
	var total: int = 0
	for event in result.get("events", []):
		if str((event as Dictionary).get("type", "")) == "trait":
			total += 1
	return total


# C. No enemy trait triggers on a first run; hero traits do.
func _check_combat(after: bool) -> void:
	# Volatile: the unit dies; each hero takes 4 only once enemy traits are on.
	var volt: Resource = dm().enemy_for_battle(dm().get_enemy_by_display_name("Volt Enforcer"))
	var cm: Object = _battle([_hero("a", {"dmg": 500}), _hero("b", {})], [volt])
	_expect(str(cm.get_enemy_states()[0]["trait"]) == ("discharge" if after else ""), "combat (%s): Volt Enforcer's state carries %s" % [_when(after), "its trait" if after else "no trait"])
	cm.get_hero_states()[0]["selected_target_id"] = str(cm.get_enemy_states()[0]["id"])
	var result: Dictionary = cm.resolve_round({"a": 10}, {}, _dice)
	_expect(bool(cm.get_enemy_states()[0]["dead"]), "combat (%s): fixture, the Volt Enforcer dies" % _when(after))
	_expect(_lost(cm.get_hero_states()[1]) == (4 if after else 0), "combat (%s): its death deals %d to a hero (%d)" % [_when(after), 4 if after else 0, _lost(cm.get_hero_states()[1])])
	_expect((_trait_events(result) > 0) == after, "combat (%s): %s trait chip for it" % [_when(after), "a" if after else "no"])
	# Barbed: the hero that hits it takes 2 only once enemy traits are on.
	var stalker: Resource = dm().enemy_for_battle(dm().get_enemy_by_display_name("Spine Stalker"))
	cm = _battle([_hero("a", {"dmg": 5})], [stalker])
	cm.get_hero_states()[0]["selected_target_id"] = str(cm.get_enemy_states()[0]["id"])
	cm.resolve_round({"a": 10}, {}, _dice)
	_expect(_lost(cm.get_hero_states()[0]) == (2 if after else 0), "combat (%s): hitting a Spine Stalker costs the hero %d (%d)" % [_when(after), 2 if after else 0, _lost(cm.get_hero_states()[0])])
	# A hero's trait works either way: Redline's +2 with 5 Protocol held.
	cm = _battle([_hero("a", {"dmg": 10}, "redline")], [dm().enemy_for_battle(dm().get_enemy_by_display_name("Scrap Drone"))])
	cm.protocol_pool = 5
	cm.get_hero_states()[0]["selected_target_id"] = str(cm.get_enemy_states()[0]["id"])
	result = cm.resolve_round({"a": 10}, {}, _dice)
	_expect(_lost(cm.get_enemy_states()[0]) == 12 and _trait_events(result) == 1, "combat (%s): a hero's trait works (Redline: %d damage, %d chip)" % [_when(after), _lost(cm.get_enemy_states()[0]), _trait_events(result)])
	# And a hero that picked its trait in a run carries it into battle.
	gs().reset_run()
	gs().start_run(["pulse", "combat", "medic"], "facility", 5)
	gs().unit_evolutions["pulse"] = "Pyro Specialist"
	gs().unit_directives["pulse"] = "flashpoint"
	_expect(str(_traits.of_unit(gs().get_run_unit_data("pulse")).get("name", "")) == "Searing", "combat (%s): a hero's 250 XP trait is carried in a run" % _when(after))
	gs().reset_run()


# D. What an inspect prints.
func _check_shown(after: bool) -> void:
	var inspect: Object = load(INSPECT_SOURCE)
	var volt: Resource = dm().get_enemy_by_display_name("Volt Enforcer")
	_expect(inspect.trait_entry(volt).is_empty() != after, "shown (%s): an enemy's inspect %s a trait line outside a battle" % [_when(after), "has" if after else "has no"])
	_expect(inspect.trait_entry(dm().enemy_for_battle(volt)).is_empty() != after, "shown (%s): and %s in one" % [_when(after), "has it" if after else "has none"])
	var help: Node = load("res://scripts/ui/help_menu.gd").new()
	var statuses: Array = help._enemy_breakdown_payload(volt).get("statuses", [])
	var leads_with_trait: bool = not statuses.is_empty() and str((statuses[0] as Dictionary).get("text", "")).begins_with("VOLATILE: ")
	_expect(leads_with_trait == after, "shown (%s): Help's Volt Enforcer entry %s its trait (%s)" % [_when(after), "leads with" if after else "does not print", str(statuses)])
	help.free()
	_expect(not inspect.trait_entry(_hero("a", {"dmg": 1}, "redline")).is_empty(), "shown (%s): a hero's inspect has its trait line" % _when(after))


# E. What ends a first run.
func _check_run_end() -> void:
	# Abandoning a run does not end it.
	gs().start_run(SQUAD, "facility", 11)
	gs().advance_to_next_battle()
	gs().reset_run()
	_expect(not sm().enemy_traits_enabled(), "run end: an abandoned run does not turn enemy traits on")
	# The tutorial is not a run.
	gs().start_tutorial_run()
	gs().reset_run()
	_expect(not sm().enemy_traits_enabled(), "run end: the tutorial does not turn enemy traits on")
	# A defeat ends it. The flag moves at run end, not before.
	gs().start_run(SQUAD, "facility", 11)
	gs().advance_to_next_battle()
	_expect(not sm().enemy_traits_enabled(), "run end: enemy traits stay off for the whole first run")
	gs().finish_run("defeat")
	_expect(bool(sm().data["onboarding"]["first_run_finished"]), "run end: a defeat sets the profile flag")
	gs().reset_run()
	# A victory ends it too.
	sm().data = sm().default_data()
	_expect(not sm().enemy_traits_enabled(), "run end: fixture, a new profile again")
	gs().start_run(SQUAD, "facility", 12)
	gs().advance_to_next_battle()
	gs().finish_run("victory")
	_expect(bool(sm().data["onboarding"]["first_run_finished"]), "run end: a victory sets the profile flag")
	gs().reset_run()


# F. Profiles from before the flag.
func _check_profiles() -> void:
	var kept: Dictionary = sm().data.duplicate(true)
	for case in [
		[{"runs_finished": 3}, {}, true, "a profile with finished runs and no flag"],
		[{"best_clear": 4}, {}, true, "a profile with a best clear and no flag"],
		[{"runs_started": 2}, {}, false, "a profile that started runs and finished none"],
		[{}, {"first_run_finished": true}, true, "a profile with the flag set"],
		[{}, {"first_run_finished": false}, false, "a profile with the flag unset"],
	]:
		var loaded: Dictionary = sm().default_data()
		(loaded["stats"] as Dictionary).merge(case[0], true)
		(loaded["onboarding"] as Dictionary).erase("first_run_finished")
		(loaded["onboarding"] as Dictionary).merge(case[1], true)
		sm().data = sm().default_data()
		sm()._migrate_profile(loaded)
		_expect(bool(sm().data["onboarding"]["first_run_finished"]) == bool(case[2]), "profile: %s loads with enemy traits %s" % [str(case[3]), "on" if case[2] else "off"])
		_expect(int(sm().data["stats"].get("runs_finished", 0)) == int((case[0] as Dictionary).get("runs_finished", 0)), "profile: %s keeps its stats" % str(case[3]))
	sm().data = kept


# G. Every battle builds its enemies through DataManager.enemy_for_battle.
func _check_one_rule() -> void:
	for path in ENEMY_BUILDERS:
		var source: String = FileAccess.get_file_as_string(path)
		_expect(source.contains("enemy_for_battle"), "one rule: %s builds its enemies through DataManager.enemy_for_battle" % path.get_file())
		_expect(not source.contains(".duplicate(true) as EnemyData"), "one rule: %s does not copy an enemy itself" % path.get_file())


# H. A real battle against a Mantle Hunt beast.
func _check_live(after: bool) -> void:
	sm().clear_run_save()
	gs().reset_run()
	gs().start_run(SQUAD, "stellarMenagerie", 31)
	gs().advance_to_next_battle()
	change_scene_to_file(BATTLE_SCENE)
	for _i in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE and current_scene.is_node_ready():
			break
	await create_timer(0.8).timeout
	var scene: Node = current_scene
	if scene == null or scene.scene_file_path != BATTLE_SCENE:
		_errors.append("live (%s): battle scene did not load" % _when(after))
		return
	var beast: Dictionary = scene.combat_manager.get_enemy_states()[0]
	_expect(str(beast["unit"].display_name) == "Pumice Climber", "live (%s): fixture, Mantle Hunt opens on a Pumice Climber (%s)" % [_when(after), str(beast["unit"].display_name)])
	_expect(str(beast.get("trait", "")) == ("packRage" if after else ""), "live (%s): the beast's state carries %s (%s)" % [_when(after), "Feral" if after else "no trait", str(beast.get("trait", ""))])
	var card: Control = scene._feedback._find_card_by_state_id("enemy", str(beast["id"]))
	var marker: Label = card.find_child("TraitMarker", true, false) as Label if card != null else null
	_expect(marker != null and marker.visible == after and (not after or marker.text == "FERAL"), "live (%s): the enemy card %s (%s)" % [_when(after), "reads FERAL" if after else "has no title line", (marker.text if marker.visible else "hidden") if marker != null else "no card"])
	var statuses: Array = load(INSPECT_SOURCE).resolve_unit(beast["unit"], beast).get("statuses", [])
	var has_line: bool = false
	for entry in statuses:
		if bool((entry as Dictionary).get("trait", false)):
			has_line = true
	_expect(has_line == after, "live (%s): the long-press %s a trait line" % [_when(after), "has" if after else "has no"])
	sm().clear_run_save()
	gs().reset_run()
