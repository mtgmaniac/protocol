# Cloak ambush gate (G-52, Kev 2026-10-08).
#
#   godot --headless --path . -s scripts/debug/cloak_ambush_test.gd [-- --cloak-ambush-break=no_bonus]
#
# Cloak used to break on attack and give nothing for it, so it almost never
# lasted and cloak items were wasted on attackers. Now the attack that breaks a
# cloak is an ambush (+50% damage), on both sides, and a single-target attack
# with every target cloaked hits one of them at random instead of fizzling.
# Pinned here:
#   A. combat   the ambush pays exactly once per cloak and only out of cloak
#               (hero, enemy, area attack, an attack that re-cloaks, a cloak
#               torn off by an area hit); the attack breaks the cloak; an
#               ability that does not attack keeps it; every target cloaked ->
#               one of them is hit, picked from the seeded stream (both are
#               reachable, the same seed repeats), its cloak stays up and the
#               attack's riders land on the same unit; a visible target is
#               always preferred; an ability that does not attack still finds
#               no target.
#   B. copy     the inspect line, the keyword definition and the primer name
#               the bonus the engine pays.
#   C. live     a real round: the cloak chip carries the bonus on both sides,
#               the enemy phase's HP preview counts the enemy's ambush, the
#               battle log names it, and the chip is gone once the cloak is.
# scripts/checks/break_gate.py reruns it with each CombatManager
# CLOAK_BREAK_ARG mode (no_bonus, always, keep_cloak, fizzle, first, no_chip)
# and requires a FAIL.
extends SceneTree

const COMBAT_SOURCE := "res://scripts/battle/combat_manager.gd"
const DICE_SOURCE := "res://scripts/battle/dice_manager.gd"
const SEEDED_SOURCE := "res://scripts/sim/seeded_roll_provider.gd"
const INSPECT_SOURCE := "res://scripts/ui/inspect_resolver.gd"
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const KEYWORDS_PATH := "res://data/raw/keywords.data.json"
const PRIMERS_PATH := "res://data/raw/primers.data.json"
const SPEED := 8
const SEEDS := 24

var _errors: PackedStringArray = []
var _dice: Object


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
	_dice = load(DICE_SOURCE).new()
	_check_combat()
	_check_all_cloaked()
	_check_copy()
	await _check_live()
	for error in _errors:
		print("[CLOAK_AMBUSH] FAIL - %s" % error)
	print("[CLOAK_AMBUSH] %s" % ("PASS" if _errors.is_empty() else "FAIL - %d check(s)" % _errors.size()))
	sm().clear_run_save()
	if current_scene != null:
		unload_current_scene()
	await create_timer(0.3).timeout
	quit(0 if _errors.is_empty() else 1)


# ── Fixtures ──────────────────────────────────────────────────────────────────
func _band(ability_name: String, raw: Dictionary) -> Dictionary:
	return {"min": 1, "max": 20, "zone": "audit", "ability_name": ability_name, "description": "", "raw": raw.duplicate(true)}


func _hero(id: String, raw: Dictionary) -> UnitData:
	var unit: UnitData = UnitData.new()
	unit.id = id
	unit.display_name = "Hero %s" % id
	unit.max_hp = 100
	unit.dice_ranges = [_band("Test Move", raw)]
	return unit


func _enemy(id: String, raw: Dictionary = {}) -> EnemyData:
	var enemy: EnemyData = EnemyData.new()
	enemy.id = id
	enemy.display_name = "Enemy %s" % id
	enemy.max_hp = 100
	enemy.dice_ranges = [_band("Test Move", raw)]
	return enemy


func _battle(heroes: Array, enemies: Array, stream_seed: int = 1) -> Object:
	var cm: Object = load(COMBAT_SOURCE).new()
	cm.roll_provider = load(SEEDED_SOURCE).new(stream_seed)
	cm.setup_battle(heroes, enemies)
	return cm


# One round in which every living unit acts on its one ability.
func _round(cm: Object, heroes_act: bool = true, enemies_act: bool = true) -> Array:
	var hero_rolls: Dictionary = {}
	var enemy_rolls: Dictionary = {}
	if heroes_act:
		for state in cm.get_hero_states():
			hero_rolls[str(state["id"])] = 10
	if enemies_act:
		for state in cm.get_enemy_states():
			enemy_rolls[str(state["id"])] = 10
	return cm.resolve_round(hero_rolls, enemy_rolls, _dice)["log"]


func _mult() -> float:
	return float(load(COMBAT_SOURCE).new().ambush_mult())


func _bonus_text() -> String:
	return str(load(COMBAT_SOURCE).ambush_bonus_text())


func _ambushed(amount: int) -> int:
	return int(ceil(float(amount) * _mult()))


# ── A. The ambush ─────────────────────────────────────────────────────────────
func _check_combat() -> void:
	_expect(_mult() > 1.0, "the ambush is a bonus (multiplier %s)" % str(_mult()))

	# A hero: exactly once, and the attack breaks the cloak.
	var cm: Object = _battle([_hero("a", {"dmg": 8})], [_enemy("x")])
	var hero: Dictionary = cm.get_hero_states()[0]
	var foe: Dictionary = cm.get_enemy_states()[0]
	hero["cloaked"] = true
	hero["selected_target_id"] = str(foe["id"])
	_expect(int(cm.ambush_damage(hero, 8)) == _ambushed(8), "ambush_damage: a cloaked attacker's 8 is %d (%d)" % [_ambushed(8), int(cm.ambush_damage(hero, 8))])
	var log: Array = _round(cm, true, false)
	_expect(100 - int(foe["current_hp"]) == _ambushed(8), "hero: the attack from cloak deals %d (%d)" % [_ambushed(8), 100 - int(foe["current_hp"])])
	_expect(not bool(hero["cloaked"]), "hero: attacking breaks the cloak")
	_expect(log.has("Hero a ambushes from cloak for %s." % _bonus_text()), "hero: the log names the ambush (%s)" % str(log))
	var after_first: int = int(foe["current_hp"])
	hero["selected_target_id"] = str(foe["id"])
	_round(cm, true, false)
	_expect(after_first - int(foe["current_hp"]) == 8, "hero: the next attack is a plain 8, the bonus is paid once (%d)" % (after_first - int(foe["current_hp"])))
	_expect(int(cm.ambush_damage(hero, 8)) == 8, "ambush_damage: an uncloaked attacker's 8 stays 8")

	# Never cloaked: no bonus.
	cm = _battle([_hero("a", {"dmg": 8})], [_enemy("x")])
	hero = cm.get_hero_states()[0]
	foe = cm.get_enemy_states()[0]
	hero["selected_target_id"] = str(foe["id"])
	_round(cm, true, false)
	_expect(100 - int(foe["current_hp"]) == 8, "an attack that is not from cloak deals its plain 8 (%d)" % (100 - int(foe["current_hp"])))

	# A cloak torn off by an area hit pays nothing.
	cm = _battle([_hero("a", {"dmg": 8})], [_enemy("x", {"dmg": 3, "blastAll": true})])
	hero = cm.get_hero_states()[0]
	foe = cm.get_enemy_states()[0]
	hero["cloaked"] = true
	_round(cm, false, true)
	_expect(not bool(hero["cloaked"]), "an area hit breaks the cloak")
	hero["selected_target_id"] = str(foe["id"])
	_round(cm, true, false)
	_expect(100 - int(foe["current_hp"]) == 8, "a cloak torn off by an area hit pays no ambush (%d)" % (100 - int(foe["current_hp"])))

	# An enemy: the same rule.
	cm = _battle([_hero("a", {})], [_enemy("x", {"dmg": 7})])
	hero = cm.get_hero_states()[0]
	foe = cm.get_enemy_states()[0]
	foe["cloaked"] = true
	log = _round(cm, false, true)
	_expect(100 - int(hero["current_hp"]) == _ambushed(7), "enemy: the attack from cloak deals %d (%d)" % [_ambushed(7), 100 - int(hero["current_hp"])])
	_expect(not bool(foe["cloaked"]), "enemy: attacking breaks the cloak")
	_expect(log.has("Enemy x ambushes from cloak for %s." % _bonus_text()), "enemy: the log names the ambush (%s)" % str(log))
	var hero_after_first: int = int(hero["current_hp"])
	_round(cm, false, true)
	_expect(hero_after_first - int(hero["current_hp"]) == 7, "enemy: the next attack is a plain 7 (%d)" % (hero_after_first - int(hero["current_hp"])))

	# An ability that does not attack keeps the cloak and the bonus.
	cm = _battle([_hero("a", {})], [_enemy("x", {"shield": 5})])
	hero = cm.get_hero_states()[0]
	foe = cm.get_enemy_states()[0]
	foe["cloaked"] = true
	_round(cm, false, true)
	_expect(bool(foe["cloaked"]), "an ability that does not attack keeps the cloak")
	cm._apply_enemy_ability(foe, _band("Bite", {"dmg": 7}))
	_expect(100 - int(hero["current_hp"]) == _ambushed(7) and not bool(foe["cloaked"]), "the kept cloak still pays its ambush on the first attack (%d)" % (100 - int(hero["current_hp"])))

	# An area attack from cloak: every target takes the ambush.
	cm = _battle([_hero("a", {"dmg": 6, "blastAll": true})], [_enemy("x"), _enemy("y")])
	hero = cm.get_hero_states()[0]
	hero["cloaked"] = true
	_round(cm, true, false)
	for state in cm.get_enemy_states():
		_expect(100 - int(state["current_hp"]) == _ambushed(6), "area attack from cloak: %s takes %d (%d)" % [state["unit"].display_name, _ambushed(6), 100 - int(state["current_hp"])])

	# An attack that cloaks again: each cloak pays once.
	cm = _battle([_hero("a", {"dmg": 5, "cloak": true})], [_enemy("x")])
	hero = cm.get_hero_states()[0]
	foe = cm.get_enemy_states()[0]
	hero["selected_target_id"] = str(foe["id"])
	_round(cm, true, false)
	_expect(100 - int(foe["current_hp"]) == 5 and bool(hero["cloaked"]), "attack + cloak, uncloaked: a plain 5, then cloaked (%d)" % (100 - int(foe["current_hp"])))
	var hp_then: int = int(foe["current_hp"])
	hero["selected_target_id"] = str(foe["id"])
	_round(cm, true, false)
	_expect(hp_then - int(foe["current_hp"]) == _ambushed(5) and bool(hero["cloaked"]), "attack + cloak, cloaked: the ambush's %d, then cloaked again (%d)" % [_ambushed(5), hp_then - int(foe["current_hp"])])


# ── A. Every target cloaked ───────────────────────────────────────────────────
# Runs one all-cloaked hero attack per seed; returns the ids hit, in seed order.
func _hero_picks(raw: Dictionary) -> Array:
	var picks: Array = []
	for stream_seed in range(1, SEEDS + 1):
		var cm: Object = _battle([_hero("a", raw)], [_enemy("x"), _enemy("y")], stream_seed)
		var hit: Array = []
		for state in cm.get_enemy_states():
			state["cloaked"] = true
		var log: Array = _round(cm, true, false)
		for state in cm.get_enemy_states():
			if int(state["current_hp"]) < 100:
				hit.append(str(state["id"]))
				_expect(100 - int(state["current_hp"]) == int(raw["dmg"]), "all cloaked: the hit is the attack's plain %d (%d)" % [int(raw["dmg"]), 100 - int(state["current_hp"])])
				_expect(bool(state["cloaked"]), "all cloaked: the unit that is hit keeps its cloak")
				_expect(log.has("Every target is cloaked. Hero a hits %s at random." % state["unit"].display_name), "all cloaked: the log says who was hit at random (%s)" % str(log))
				if bool(raw.get("jam", false)):
					_expect(int(state.get("jam_cap", 0)) > 0, "all cloaked: the attack's jam lands on the unit it hit")
			elif bool(raw.get("jam", false)):
				_expect(int(state.get("jam_cap", 0)) == 0, "all cloaked: the attack's jam does not land on the other unit")
		_expect(hit.size() == 1, "all cloaked (seed %d): exactly one unit is hit, not zero (%s)" % [stream_seed, str(hit)])
		picks.append(hit[0] if hit.size() == 1 else "")
	return picks


func _check_all_cloaked() -> void:
	var picks: Array = _hero_picks({"dmg": 8})
	var first_id: String = str(_battle([_hero("a", {})], [_enemy("x"), _enemy("y")]).get_enemy_states()[0]["id"])
	var second_id: String = str(_battle([_hero("a", {})], [_enemy("x"), _enemy("y")]).get_enemy_states()[1]["id"])
	_expect(picks.has(first_id) and picks.has(second_id), "all cloaked: over %d seeds both cloaked units are hit, so the pick is random (%s)" % [SEEDS, str(picks)])
	_expect(_hero_picks({"dmg": 8}) == picks, "all cloaked: the same seeds repeat the same picks (seeded stream)")
	_hero_picks({"dmg": 8, "jam": true})

	# A visible target is always preferred: the cloaked pick retargets to it.
	var cm: Object = _battle([_hero("a", {"dmg": 8})], [_enemy("x"), _enemy("y")])
	var hidden: Dictionary = cm.get_enemy_states()[0]
	var visible: Dictionary = cm.get_enemy_states()[1]
	hidden["cloaked"] = true
	cm.get_hero_states()[0]["selected_target_id"] = str(hidden["id"])
	_round(cm, true, false)
	_expect(int(hidden["current_hp"]) == 100 and int(visible["current_hp"]) == 92, "one visible target: it takes the hit, the cloaked unit is untouched (%d / %d)" % [int(hidden["current_hp"]), int(visible["current_hp"])])

	# An ability that does not attack still finds no target.
	cm = _battle([_hero("a", {"mark": true})], [_enemy("x"), _enemy("y")])
	for state in cm.get_enemy_states():
		state["cloaked"] = true
	_round(cm, true, false)
	for state in cm.get_enemy_states():
		_expect(not bool(state.get("marked", false)), "all cloaked: an ability that does not attack marks nobody")

	# The enemy side: every hero cloaked.
	var hero_picks: Array = []
	for stream_seed in range(1, SEEDS + 1):
		cm = _battle([_hero("a", {}), _hero("b", {})], [_enemy("x", {"dmg": 7})], stream_seed)
		for state in cm.get_hero_states():
			state["cloaked"] = true
		_round(cm, false, true)
		var hit: Array = []
		for state in cm.get_hero_states():
			if int(state["current_hp"]) < 100:
				hit.append(str(state["id"]))
				_expect(100 - int(state["current_hp"]) == 7 and bool(state["cloaked"]), "all heroes cloaked: one takes the plain 7 and keeps its cloak (%d)" % (100 - int(state["current_hp"])))
		_expect(hit.size() == 1, "all heroes cloaked (seed %d): exactly one hero is hit (%s)" % [stream_seed, str(hit)])
		hero_picks.append(hit[0] if hit.size() == 1 else "")
	_expect(hero_picks.has("a") and hero_picks.has("b"), "all heroes cloaked: over %d seeds both heroes are hit (%s)" % [SEEDS, str(hero_picks)])


# ── B. Copy ───────────────────────────────────────────────────────────────────
func _check_copy() -> void:
	var bonus: String = _bonus_text()
	var resolver: GDScript = load(INSPECT_SOURCE)
	var unit: Resource = root.get_node("/root/DataManager").get_unit("ghost")
	var payload: Dictionary = resolver.resolve_unit(unit, {"cloaked": true, "current_hp": 10, "max_hp": 45})
	var line: String = ""
	for entry in payload.get("statuses", []):
		for pip in entry.get("effects", []):
			if str(pip.get("kind", "")) == "cloak":
				line = str(entry.get("text", ""))
	_expect(line == "Can't be targeted. Next attack deals %s." % bonus, "inspect: the cloak line reads \"Can't be targeted. Next attack deals %s.\" (\"%s\")" % [bonus, line])

	var keywords: Variant = JSON.parse_string(FileAccess.get_file_as_string(KEYWORDS_PATH))
	var definition: String = ""
	for entry in (keywords as Dictionary).get("keywords", []):
		if str(entry.get("id", "")) == "cloak":
			definition = str(entry.get("def", ""))
	_expect(definition.contains("next attack deals %s" % bonus), "keyword: the Cloak definition names the bonus, \"%s\" (\"%s\")" % [bonus, definition])
	_expect(definition.contains("breaks the cloak"), "keyword: the Cloak definition says the attack breaks it")
	_expect(definition.contains("at random"), "keyword: the Cloak definition covers every target being cloaked")
	_expect(definition.contains("allies still can"), "keyword: the Cloak definition keeps friendly picks legal (DECISIONS #12)")

	var primers: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRIMERS_PATH))
	var primer: String = ""
	for entry in (primers as Dictionary).get("primers", []):
		if str(entry.get("id", "")) == "primer_cloak":
			primer = str(entry.get("text", ""))
	_expect(primer.contains("next attack deals %s" % bonus), "primer: the Cloak primer names the bonus, \"%s\" (\"%s\")" % [bonus, primer])
	for text in [line, definition, primer]:
		_expect(not str(text).contains("—"), "copy: no em dash (\"%s\")" % str(text))


# ── C. A real round ───────────────────────────────────────────────────────────
func _cloak_chip(scene: Node, state: Dictionary) -> Dictionary:
	for token in scene._card_view._composed_status_tokens(state):
		if str(token.get("type", "")) == "cloak":
			return token
	return {}


func _card_shows(card: Control, text: String) -> bool:
	if card == null:
		return false
	for label in card.find_children("*", "Label", true, false):
		if str((label as Label).text) == text and (label as Label).is_visible_in_tree():
			return true
	return false


func _check_live() -> void:
	Engine.physics_ticks_per_second = 120 * SPEED
	Engine.time_scale = SPEED
	Engine.max_physics_steps_per_frame = 64
	var gs: Node = root.get_node("/root/GameState")
	sm().clear_run_save()
	gs.reset_run()
	gs.start_run(["combat", "engineer", "medic"], "facility", 77)
	gs.advance_to_next_battle()
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
	var cm: Object = scene.combat_manager
	var heroes: Array = cm.get_hero_states()
	var enemies: Array = cm.get_enemy_states()
	_expect(enemies.size() >= 2, "fixture: the first Facility battle has two enemies")
	if enemies.size() < 2:
		return
	var striker: Dictionary = heroes[0]
	var lurker: Dictionary = enemies[1]
	striker["cloaked"] = true
	lurker["cloaked"] = true
	var rig: Dictionary = {}
	for hero_state in heroes:
		rig["hero:%s" % hero_state["id"]] = 9
	for enemy_state in enemies:
		rig["enemy:%s" % enemy_state["id"]] = 12
	scene.dice_tray_3d.set_rigged_results(rig)
	await scene._begin_targeting_phase()
	await _settle(scene)
	if int(scene.turn_phase) == int(scene.PHASE_TARGETING):
		await scene._auto_assign_pending_targets(false)
	scene._card_view.refresh_all_cards()
	await process_frame

	var chip_text: String = str(load(COMBAT_SOURCE).ambush_chip_text(float(cm.ambush_mult())))
	for pair in [["hero", striker], ["enemy", lurker]]:
		var state: Dictionary = pair[1]
		var who: String = str(state["unit"].display_name)
		var chip: Dictionary = _cloak_chip(scene, state)
		_expect(str(chip.get("value", "")) == chip_text, "live: %s's cloak chip carries the bonus \"%s\" (%s)" % [who, chip_text, str(chip)])
		var card: Control = scene._feedback._find_card_by_state_id(str(pair[0]), str(state["id"]))
		_expect(_card_shows(card, chip_text.to_upper()), "live: %s's card shows \"%s\" beside the cloak icon" % [who, chip_text.to_upper()])
	_expect(_cloak_chip(scene, heroes[1]).is_empty(), "live: a unit that is not cloaked has no cloak chip")

	# The enemy phase's HP preview counts the cloaked enemy's ambush.
	var lurk_raw: Dictionary = scene.dice_manager.get_ability_for_roll(lurker["unit"], int(scene._get_effective_enemy_roll(lurker, str(lurker["id"])))).get("raw", {})
	var lurk_dmg: int = int(lurk_raw.get("dmg", 0))
	var prey: Dictionary = {}
	for hero_state in heroes:
		if str(hero_state["id"]) == str(lurker.get("selected_target_id", "")):
			prey = hero_state
	_expect(lurk_dmg > 0 and not bool(lurk_raw.get("blastAll", false)) and not prey.is_empty(), "fixture: the cloaked enemy rolled a single-target attack on a hero (%s)" % str(lurk_raw.get("name", "")))
	if lurk_dmg > 0 and not prey.is_empty():
		var with_cloak: int = int(scene._card_view.compute_preview_for_unit(prey, true).get("damage", 0))
		lurker["cloaked"] = false
		var without: int = int(scene._card_view.compute_preview_for_unit(prey, true).get("damage", 0))
		lurker["cloaked"] = true
		_expect(with_cloak - without == _ambushed(lurk_dmg) - lurk_dmg, "live: the HP preview on %s counts the ambush (+%d with the cloak up, got +%d)" % [prey["unit"].display_name, _ambushed(lurk_dmg) - lurk_dmg, with_cloak - without])

	var prey_hp: int = int(prey.get("current_hp", 0)) if not prey.is_empty() else 0
	var prey_shield: int = int(prey.get("shield", 0)) if not prey.is_empty() else 0
	await scene._resolve_current_turn(false)
	await create_timer(0.5).timeout
	var log_text: String = str(scene.battle_log_label.get_parsed_text())
	var bonus: String = _bonus_text()
	for state in [striker, lurker]:
		var who: String = str(state["unit"].display_name)
		_expect(log_text.contains("%s ambushes from cloak for %s." % [who, bonus]), "live: the battle log reads \"%s ambushes from cloak for %s.\"" % [who, bonus])
		_expect(not bool(state.get("cloaked", false)), "live: %s's cloak is gone after its attack" % who)
		_expect(_cloak_chip(scene, state).is_empty(), "live: %s's cloak chip is gone with the cloak" % who)
	if not prey.is_empty() and prey_shield == 0 and lurk_dmg > 0:
		_expect(prey_hp - int(prey["current_hp"]) >= _ambushed(lurk_dmg), "live: %s lost at least the ambush's %d (%d)" % [prey["unit"].display_name, _ambushed(lurk_dmg), prey_hp - int(prey["current_hp"])])


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
