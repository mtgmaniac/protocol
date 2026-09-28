# Boss relic rework gate (Kev 2026-09-27; DECISIONS_RESOLVED G-34..G-41).
#
#   godot --headless --path . -s scripts/debug/boss_relic_test.gd
#
# Pins every rule and edge case of the new relics as they land (one section
# per relic), the save migration from the retired boss relics, and the live
# battle-screen paths (a real BattleScene with rigged real throws).
extends SceneTree

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SQUAD := ["combat", "medic", "engineer"]
const OP := "facility"
const SEED := 34034
const SPEED := 8
# The boss relics that shipped before the rework, per operation. Pinned here on
# purpose: each must migrate to the SAME operation's new relic.
const OLD_BOSS_RELIC_BY_OP := {
	"facility": "salvageRig", "hive": "chitinGraft", "veil": "resonantChorus",
	"voidCirclet": "rootAccess", "stellarMenagerie": "mantleCore",
}

var CM: GDScript
var BE: GDScript
var BS: GDScript
var DMS: GDScript
var PROV: GDScript
var UNIT: GDScript
var ENEMY: GDScript
var CHECKPOINT: GDScript
var _fails: PackedStringArray = []
var _passes: int = 0
var _section: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	Engine.physics_ticks_per_second = 120 * SPEED
	Engine.time_scale = SPEED
	Engine.max_physics_steps_per_frame = 64
	CM = load("res://scripts/battle/combat_manager.gd")
	BE = load("res://scripts/battle/battle_engine.gd")
	BS = load("res://scripts/battle/battle_state.gd")
	DMS = load("res://scripts/battle/dice_manager.gd")
	PROV = load("res://scripts/sim/seeded_roll_provider.gd")
	UNIT = load("res://scripts/resources/unit_data.gd")
	ENEMY = load("res://scripts/resources/enemy_data.gd")
	CHECKPOINT = load("res://scripts/battle/battle_checkpoint.gd")
	_data_counts()
	_save_migration()
	await _teardown()
	_finish()


# ── helpers ───────────────────────────────────────────────────────────────────

func _check(ok: bool, what: String) -> void:
	if ok:
		_passes += 1
	else:
		_fails.append("[%s] %s" % [_section, what])
		print("[BOSS_RELICS] FAIL [%s] %s" % [_section, what])


func _entry(lo: int, hi: int, ability_name: String, raw: Dictionary) -> Dictionary:
	return {"min": lo, "max": hi, "zone": "z%d" % lo, "ability_name": ability_name,
		"description": "", "raw": raw}


func _hero(id: String, raw: Dictionary = {}) -> Resource:
	var u: Resource = UNIT.new()
	u.id = id
	u.display_name = id
	u.max_hp = 100
	u.dice_ranges.assign([_entry(1, 20, "Act", raw)])
	return u


# Enemy with two bands: 1-10 "Low" (1 damage) and 11-20 "High" (9 damage).
func _enemy(id: String, hp: int = 100) -> Resource:
	var e: Resource = ENEMY.new()
	e.id = id
	e.display_name = id
	e.max_hp = hp
	e.dice_ranges.assign([_entry(1, 10, "Low", {"dmg": 1}), _entry(11, 20, "High", {"dmg": 9})])
	return e


func _mgr(relics: Array, heroes: Array, enemies: Array) -> Object:
	var cm: Object = CM.new()
	cm.setup_battle(heroes, enemies)
	cm.setup_relics(relics)
	return cm


func _engine(cm: Object, provider_seed: int = 7) -> Object:
	return BE.new(cm, PROV.new(provider_seed), DMS.new())


func _id(state: Dictionary) -> String:
	return str(state["id"])


# ── data ──────────────────────────────────────────────────────────────────────

func _data_counts() -> void:
	_section = "data"
	var dm: Node = root.get_node("/root/DataManager")
	var sm: Node = root.get_node("/root/SaveManager")
	var boss: Array = []
	var draftable: int = 0
	for item in dm.items.values():
		if item.item_type != "relic":
			continue
		if item.boss_relic:
			boss.append(item.id)
		else:
			draftable += 1
	boss.sort()
	var expected: Array = sm.BOSS_RELIC_BY_OP.values()
	expected.sort()
	_check(boss == expected, "the boss relics are exactly the five new ones (%s)" % [boss])
	_check(draftable == 29, "29 draftable relics (got %d)" % draftable)
	for relic_id in expected:
		_check(dm.get_item(relic_id).icon != null, "%s has placeholder art" % relic_id)
	for old_id in OLD_BOSS_RELIC_BY_OP.values():
		_check(dm.get_item(old_id) == null, "retired %s is gone from data" % old_id)


# ── Save migration (G-41) ─────────────────────────────────────────────────────

func _save_migration() -> void:
	_section = "save migration"
	var sm: Node = root.get_node("/root/SaveManager")
	var gs: Node = root.get_node("/root/GameState")
	var dm: Node = root.get_node("/root/DataManager")
	var saved: Dictionary = sm.data.duplicate(true)
	for op_id in OLD_BOSS_RELIC_BY_OP:
		var old_id: String = OLD_BOSS_RELIC_BY_OP[op_id]
		var new_id: String = str(sm.BOSS_RELIC_BY_OP.get(op_id, ""))
		_check(sm.current_relic_id(old_id) == new_id, "%s (%s) becomes %s" % [old_id, op_id, new_id])
		_check(dm.get_item(new_id) != null and dm.get_item(new_id).boss_relic, "%s is a boss relic in data" % new_id)
	for op_id in dm.get_operation_order():
		_check(sm.BOSS_RELIC_BY_OP.has(str(op_id)), "operation %s has a boss relic" % op_id)
	_check(sm.current_relic_id("ironCurtain") == "ironCurtain", "other relic ids pass through")
	# The profile: every old unlock becomes its new relic; nothing is lost.
	var old_profile: Dictionary = sm.default_data()
	old_profile["unlocks"]["boss_relics"] = ["salvageRig", "chitinGraft", "resonantChorus", "rootAccess", "mantleCore", "twinFates", "scrapConverter"]
	old_profile["stats"]["runs_started"] = 9
	sm.data = sm.default_data()
	sm._merge_loaded(old_profile)
	_check(sm.get_unlocked_boss_relics() == ["scrapConverter", "bloodFrenzy", "firewallHack", "hereticSignal", "tectonicCharge"],
		"all five old unlocks migrate, duplicates collapse, Twin Fates stays pruned (%s)" % [sm.get_unlocked_boss_relics()])
	var partial: Dictionary = sm.default_data()
	partial["unlocks"]["boss_relics"] = ["rootAccess"]
	sm.data = sm.default_data()
	sm._merge_loaded(partial)
	_check(sm.get_unlocked_boss_relics() == ["hereticSignal"], "one old unlock gives exactly its new relic")
	# Through the real file (the isolated dev profile; headless keeps the
	# profile in memory, so disk is switched on for this leg only): write an
	# old profile, load it, save it again.
	var save_io: GDScript = load("res://scripts/autoloads/save_io.gd")
	var disk_was: bool = bool(sm._disk_enabled)
	sm._disk_enabled = true
	sm.data = sm.default_data()
	sm.save()
	var on_disk: Dictionary = save_io.read_dict(str(sm._save_path))
	on_disk["unlocks"]["boss_relics"] = ["mantleCore", "salvageRig"]
	save_io.write_dict(str(sm._save_path), on_disk)
	sm.load_save()
	_check(sm.get_unlocked_boss_relics() == ["tectonicCharge", "scrapConverter"], "an old save.json loads with the new relics")
	sm.save()
	var rewritten: Dictionary = save_io.read_dict(str(sm._save_path))
	_check((rewritten.get("unlocks", {}) as Dictionary).get("boss_relics", []) == ["tectonicCharge", "scrapConverter"], "and saves them back under the new ids")
	# The unlocked new relic is a legal Starting Directive.
	gs.start_run(SQUAD, OP, SEED)
	gs.set_starting_directive("scrapConverter")
	_check(gs.relics == ["scrapConverter"], "a migrated unlock can be taken as a Starting Directive")
	# A run saved mid-run holding an old boss relic keeps it as the new one.
	var run: Dictionary = gs.to_save_dict()
	run["relics"] = ["rootAccess", "ironCurtain"]
	run["starting_directive_relic_id"] = "rootAccess"
	gs.load_from_dict(run)
	_check(gs.relics == ["hereticSignal", "ironCurtain"] and gs.starting_directive_relic_id == "hereticSignal",
		"a run holding an old boss relic resumes with the new one (%s)" % [gs.relics])
	_check(int(gs.drafted_relic_count()) == 1, "the migrated directive still doesn't use the battle-5 draft")
	_check(not gs._grant_relic("mantleCore"), "a retired id can't be granted")
	gs.reset_run()
	sm.data = saved
	sm.save()
	sm._disk_enabled = disk_was


# ── live battle screen ────────────────────────────────────────────────────────

func _enter(relics: Array, battle: int = 2) -> Node:
	var sm: Node = root.get_node("/root/SaveManager")
	var gs: Node = root.get_node("/root/GameState")
	# One battle per test: unload the previous one and give its coroutines time
	# to finish BEFORE the run save is cleared, so nothing it still writes can
	# land on top of the next battle's checkpoints.
	if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE:
		await _settle(current_scene)
		unload_current_scene()
		await create_timer(1.0).timeout
	sm.clear_run_save()
	gs.reset_run()
	gs.start_run(SQUAD, OP, SEED)
	gs.advance_to_next_battle()
	gs.current_battle = battle
	gs.relics = relics.duplicate()
	change_scene_to_file(BATTLE_SCENE)
	for _i in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE and current_scene.is_node_ready():
			break
	await create_timer(0.8).timeout
	return current_scene


func _roll(scene: Node, hero_vals: Array, enemy_vals: Array) -> void:
	var rig: Dictionary = {}
	var hi: int = 0
	for st in scene.combat_manager.get_hero_states():
		if bool(st.get("dead", false)):
			continue
		rig["hero:%s" % str(st["id"])] = int(hero_vals[hi % hero_vals.size()])
		hi += 1
	var ei: int = 0
	for st in scene.combat_manager.get_enemy_states():
		if bool(st.get("dead", false)):
			continue
		rig["enemy:%s" % str(st["id"])] = int(enemy_vals[ei % enemy_vals.size()])
		ei += 1
	scene.dice_tray_3d.set_rigged_results(rig)
	await scene._begin_targeting_phase()
	await _settle(scene)


# Until every die is at rest (not rolling, no tip-over or slide in flight).
func _settle(scene: Node) -> void:
	for _i in 900:
		var tray: Object = scene.dice_tray_3d
		var busy: bool = bool(tray.get("_is_rolling")) or scene._relics.get("_rethrowing") == true
		if not busy:
			for key in tray._die_by_key:
				var parts: PackedStringArray = str(key).split(":", true, 1)
				if tray.is_die_moving(parts[0], parts[1]):
					busy = true
					break
		if not busy:
			return
		await process_frame


func _hero_ids(scene: Node) -> Array:
	return scene.combat_manager.get_hero_states().filter(func(s): return not bool(s["dead"])).map(func(s): return str(s["id"]))


func _enemy_ids(scene: Node) -> Array:
	return scene.combat_manager.get_enemy_states().filter(func(s): return not bool(s["dead"])).map(func(s): return str(s["id"]))


func _log_has(scene: Node, text: String) -> bool:
	return str(scene.battle_log_label.get_parsed_text()).contains(text)


func _teardown() -> void:
	if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE:
		await _settle(current_scene)
	root.get_node("/root/SaveManager").clear_run_save()
	root.get_node("/root/GameState").reset_run()
	Engine.time_scale = 1.0
	if current_scene != null:
		current_scene.queue_free()
	await create_timer(1.0).timeout


func _finish() -> void:
	print("[BOSS_RELICS] checks passed: %d, failed: %d" % [_passes, _fails.size()])
	if _fails.is_empty():
		print("[BOSS_RELICS] PASS")
		quit(0)
	else:
		for f in _fails:
			print("[BOSS_RELICS]   %s" % f)
		print("[BOSS_RELICS] FAIL")
		quit(1)
