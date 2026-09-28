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
	_scrap_converter()
	_blood_frenzy()
	_firewall_hack()
	_heretic_signal()
	_tectonic_charge()
	_save_migration()
	await _live_scrap_converter()
	await _live_tectonic_charge()
	await _live_firewall_hack()
	await _live_heretic_signal()
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


# ── Scrap Converter (G-34) ────────────────────────────────────────────────────

func _scrap_converter() -> void:
	_section = "Scrap Converter"
	var cm: Object = _mgr(["scrapConverter"], [_hero("h1"), _hero("h2"), _hero("h3")], [_enemy("e1")])
	var eng: Object = _engine(cm)
	var bs: Object = BS.new()
	var h: Array = cm.get_hero_states()
	var ids: Array = h.map(func(s): return _id(s))
	bs.hero_rolls = {ids[0]: 1, ids[1]: 2, ids[2]: 3}
	_check(eng.landing_protocol(bs, ids) == 2, "landings showing 1 and 2 pay 1 each, 3 pays nothing")
	h[0]["perm_roll_buff"] = 2
	bs.hero_rolls = {ids[0]: 1}
	_check(eng.landing_protocol(bs, [ids[0]]) == 0, "a +2 die landing on natural 1 shows 3: no Protocol")
	h[0]["perm_roll_buff"] = 0
	h[0]["perm_rfe"] = 2
	bs.hero_rolls = {ids[0]: 4}
	_check(eng.landing_protocol(bs, [ids[0]]) == 1, "a -2 die landing on natural 4 shows 2: pays")
	h[0]["perm_rfe"] = 0
	h[0]["rewrite_pending"] = true
	bs.hero_rolls = {ids[0]: 1}
	_check(eng.landing_protocol(bs, [ids[0]]) == 0, "a rewritten die prints 3 on every face: no Protocol")
	h[0]["rewrite_pending"] = false
	h[1]["die_freeze_turns"] = 1
	h[1]["frozen_die_value"] = 1
	bs.hero_rolls = {ids[0]: 9, ids[1]: 1, ids[2]: 9}
	_check(not eng.thrown_hero_ids(bs).has(ids[1]), "a frozen repeat is not a landing")
	_check(eng.landing_protocol(bs, ids) == 0, "a frozen die repeating 1 pays nothing")
	h[1]["die_freeze_turns"] = 0
	h[1]["frozen_die_value"] = 0
	h[2]["dead"] = true
	bs.hero_rolls = {ids[2]: 1}
	_check(eng.landing_protocol(bs, [ids[2]]) == 0, "a dead hero's die pays nothing")
	h[2]["dead"] = false
	var plain: Object = _mgr([], [_hero("h1")], [_enemy("e1")])
	var plain_bs: Object = BS.new()
	plain_bs.hero_rolls = {_id(plain.get_hero_states()[0]): 1}
	_check(_engine(plain).landing_protocol(plain_bs, [_id(plain.get_hero_states()[0])]) == 0, "no relic, no Protocol")
	# Set and Nudge never land a die: they don't call the landing check, and the
	# engine's own spend paths change only the cost.
	bs.hero_rolls = {ids[0]: 9, ids[1]: 9, ids[2]: 9}
	bs.protocol_points = 10
	eng.apply_set(bs, ids[0], 1)
	eng.apply_nudge(bs, ids[1], false, false)
	_check(bs.protocol_points == 5, "Set 4 + Nudge 1 cost exactly 5 (no landing Protocol)")
	# A Reroll is a physical landing; so is the Heretic Signal re-throw.
	var raw: int = eng.apply_reroll(bs, ids[2], 2)
	_check(raw == 2 and eng.landing_protocol(bs, [ids[2]]) == 1, "a Reroll landing on 2 pays")


# ── Blood Frenzy (G-35) ───────────────────────────────────────────────────────

func _blood_frenzy() -> void:
	_section = "Blood Frenzy"
	var dm: Object = DMS.new()
	# Single kill: the killer's die freezes on the value it acted on.
	var cm: Object = _mgr(["bloodFrenzy"], [_hero("h1", {"dmg": 100}), _hero("h2")], [_enemy("e1"), _enemy("e2")])
	var h1: Dictionary = cm.get_hero_states()[0]
	var h2: Dictionary = cm.get_hero_states()[1]
	h1["selected_target_id"] = _id(cm.get_enemy_states()[0])
	cm.resolve_round({_id(h1): 17, _id(h2): 5}, {}, dm)
	_check(bool(cm.get_enemy_states()[0]["dead"]), "fixture: the hit killed e1")
	_check(int(h1.get("die_freeze_turns", 0)) == 1 and int(h1.get("frozen_die_value", 0)) == 17,
		"the killer's die freezes for one repeat on the value it acted on (17)")
	_check(int(h2.get("die_freeze_turns", 0)) == 0, "a hero that didn't kill stays unfrozen")
	# Next round: the die repeats 17 and can't be altered.
	var eng: Object = BE.new(cm, PROV.new(3), dm)
	var bs: Object = BS.new()
	bs.hero_rolls = {_id(h1): 4, _id(h2): 6}
	eng.apply_frozen_roll_overrides(cm.get_hero_states(), bs.hero_rolls)
	eng.record_roll_values_for_states(cm.get_hero_states(), bs.hero_rolls)
	_check(int(bs.hero_rolls[_id(h1)]) == 17, "next round the frozen die repeats 17")
	bs.protocol_points = 10
	_check(str(eng.apply_nudge(bs, _id(h1), false, false).get("kind", "")) == "frozen" \
		and eng.apply_set(bs, _id(h1), 20) == -1 and eng.apply_reroll(bs, _id(h1), 5) == 0 and bs.protocol_points == 10,
		"the frozen die refuses Nudge, Set and Reroll at no cost")
	# Killing again on the repeat round extends the freeze by one more repeat.
	var fresh: Dictionary = cm.inject_enemy(_enemy("e3")).get("state", {})
	h1["selected_target_id"] = _id(fresh)
	cm.resolve_round(eng.build_effective_rolls(bs.hero_rolls, cm.get_hero_states(), true, bs), {}, dm)
	_check(bool(fresh.get("dead", false)), "fixture: the repeat killed a summoned enemy")
	_check(int(h1.get("die_freeze_turns", 0)) == 1 and int(h1.get("frozen_die_value", 0)) == 17,
		"a kill on the repeat round re-freezes (repeats again next round, still 17)")
	# AoE double kill: one freeze, not one per kill.
	var aoe: Object = _mgr(["bloodFrenzy"], [_hero("h1", {"dmg": 100, "blastAll": true})], [_enemy("e1"), _enemy("e2"), _enemy("e3", 500)])
	var ah: Dictionary = aoe.get_hero_states()[0]
	aoe.resolve_round({_id(ah): 12}, {}, dm)
	_check(bool(aoe.get_enemy_states()[0]["dead"]) and bool(aoe.get_enemy_states()[1]["dead"]), "fixture: the blast killed two")
	_check(int(ah.get("die_freeze_turns", 0)) == 1, "two kills in one round freeze once (1 repeat, got %d)" % int(ah.get("die_freeze_turns", 0)))
	# No hero killer: an environmental death freezes nobody; a dead killer can't freeze.
	var env: Object = _mgr(["bloodFrenzy"], [_hero("h1")], [_enemy("e1"), _enemy("e2")])
	env._damage_state(env.get_enemy_states()[0], 500)
	_check(int(env.get_hero_states()[0].get("die_freeze_turns", 0)) == 0, "a death with no hero killer freezes nothing")
	var dead_killer: Dictionary = env.get_hero_states()[0]
	dead_killer["dead"] = true
	env._process_unit_killed(env.get_enemy_states()[1], dead_killer, true)
	_check(int(dead_killer.get("die_freeze_turns", 0)) == 0, "a dead killer's die doesn't freeze")
	# An enemy killing a hero is not a hero kill.
	var foe: Object = _mgr(["bloodFrenzy"], [_hero("h1"), _hero("h2")], [_enemy("e1")])
	foe._damage_state(foe.get_hero_states()[0], 500, false, foe.get_enemy_states()[0])
	_check(int(foe.get_enemy_states()[0].get("die_freeze_turns", 0)) == 0, "an enemy's kill never freezes the enemy")


# ── Firewall Hack (G-36) ──────────────────────────────────────────────────────

func _firewall_hack() -> void:
	_section = "Firewall Hack"
	var cm: Object = _mgr(["firewallHack"], [_hero("h1")], [_enemy("e1"), _enemy("e2"), _enemy("e3"), _enemy("e4")])
	var eng: Object = _engine(cm)
	var bs: Object = BS.new()
	var e: Array = cm.get_enemy_states()
	var dm: Object = DMS.new()
	bs.hero_rolls = {_id(cm.get_hero_states()[0]): 10}
	bs.enemy_rolls = {_id(e[0]): 12, _id(e[1]): 5, _id(e[2]): 2, _id(e[3]): 15}
	bs.protocol_points = 3
	_check(eng.firewall_hack_block(bs, e[0]) == "", "an unfrozen enemy die can be hacked")
	_check(eng.apply_firewall_hack(bs, e[0]), "the hack lands")
	_check(eng.effective_enemy_roll(e[0], _id(e[0]), bs) == 9, "the die drops by 3 (12 -> 9)")
	_check(bs.protocol_points == 2, "it costs the normal Nudge price of 1")
	_check(str(dm.get_ability_for_roll(e[0]["unit"], eng.effective_enemy_roll(e[0], _id(e[0]), bs)).get("ability_name", "")) == "Low",
		"the enemy's ability follows the new value (High -> Low)")
	_check(int(eng.build_effective_rolls(bs.enemy_rolls, e, false, bs).get(_id(e[0]), 0)) == 9, "the round resolves on the hacked value")
	_check(eng.firewall_hack_block(bs, e[1]) == "used" and not eng.apply_firewall_hack(bs, e[1]) and bs.protocol_points == 2,
		"only once per turn (a second hack is refused, nothing spent)")
	bs.firewall_hack_used = false   # the next turn
	_check(eng.apply_firewall_hack(bs, e[2]) and eng.effective_enemy_roll(e[2], _id(e[2]), bs) == 1, "it can't go below 1 (2 -> 1)")
	bs.firewall_hack_used = false
	e[1]["die_freeze_turns"] = 1
	e[1]["frozen_die_value"] = 5
	_check(eng.firewall_hack_block(bs, e[1]) == "frozen", "a frozen die can't be hacked")
	e[1]["die_freeze_turns"] = 0
	e[1]["frozen_die_value"] = 0
	e[3]["hijack_pending"] = true
	_check(eng.firewall_hack_block(bs, e[3]) == "hijacked", "a hijacked die can't be hacked")
	e[3]["hijack_pending"] = false
	bs.protocol_points = 0
	_check(eng.firewall_hack_block(bs, e[3]) == "protocol", "no Protocol, no hack")
	bs.protocol_points = 5
	e[3]["dead"] = true
	_check(eng.firewall_hack_block(bs, e[3]) == "no_die", "a dead enemy's die can't be hacked")
	e[3]["dead"] = false
	var plain: Object = _mgr([], [_hero("h1")], [_enemy("e1")])
	_check(_engine(plain).firewall_hack_block(bs, plain.get_enemy_states()[0]) == "no_relic", "no relic, no hack")
	# The hack lasts for this round only.
	eng.resolve_step(bs)
	_check(bs.enemy_roll_nudges.is_empty(), "resolving the round clears the hack")


# ── Heretic Signal (G-37) ─────────────────────────────────────────────────────

func _heretic_signal() -> void:
	_section = "Heretic Signal"
	var cm: Object = _mgr(["hereticSignal", "firewallHack"], [_hero("h1"), _hero("h2"), _hero("h3")], [_enemy("e1"), _enemy("e2")])
	var eng: Object = _engine(cm)
	var bs: Object = BS.new()
	var h: Array = cm.get_hero_states().map(func(s): return _id(s))
	var e: Array = cm.get_enemy_states().map(func(s): return _id(s))
	cm.get_hero_states()[2]["die_freeze_turns"] = 1
	cm.get_hero_states()[2]["frozen_die_value"] = 17
	bs.hero_rolls = {h[0]: 4, h[1]: 6, h[2]: 17}
	bs.enemy_rolls = {e[0]: 18, e[1]: 11}
	bs.hero_roll_nudges = {h[0]: 3}
	bs.hero_roll_sets = {h[1]: 20}
	bs.enemy_roll_nudges = {e[0]: -3}
	_check(eng.heretic_signal_available(bs), "available once the dice are on the board")
	var thrown: Dictionary = eng.apply_heretic_signal(bs, {"hero": {h[0]: 15, h[1]: 11, h[2]: 2}, "enemy": {e[0]: 3, e[1]: 20}})
	_check((thrown.get("hero", []) as Array) == [h[0], h[1]] and (thrown.get("enemy", []) as Array) == [e[0], e[1]],
		"every unfrozen die is re-thrown, heroes and enemies (%s)" % [thrown])
	_check(int(bs.hero_rolls[h[2]]) == 17, "a frozen die is skipped and keeps its value")
	_check(int(bs.hero_rolls[h[0]]) == 15 and int(bs.enemy_rolls[e[0]]) == 3, "the landed faces become the raws")
	_check(bs.hero_roll_nudges.is_empty() and bs.hero_roll_sets.is_empty() and bs.enemy_roll_nudges.is_empty(),
		"a re-thrown die is a fresh roll: its Nudge, Set and Firewall Hack are cleared")
	_check(bs.heretic_signal_used and not eng.heretic_signal_available(bs), "used once, it is gone for the battle")
	_check(eng.apply_heretic_signal(bs, {"hero": {h[0]: 1}}).is_empty() and int(bs.hero_rolls[h[0]]) == 15, "a second use does nothing")
	var empty_bs: Object = BS.new()
	var fresh_cm: Object = _mgr(["hereticSignal"], [_hero("h1")], [_enemy("e1")])
	_check(not _engine(fresh_cm).heretic_signal_available(empty_bs), "not before the dice are rolled")
	# Sim path: the seeded stream, deterministic.
	var draws: Array = []
	for _i in 2:
		var scm: Object = _mgr(["hereticSignal"], [_hero("h1"), _hero("h2")], [_enemy("e1")])
		var seng: Object = _engine(scm, 99)
		var sbs: Object = BS.new()
		sbs.hero_rolls = {_id(scm.get_hero_states()[0]): 1, _id(scm.get_hero_states()[1]): 1}
		sbs.enemy_rolls = {_id(scm.get_enemy_states()[0]): 20}
		seng.apply_heretic_signal(sbs)
		draws.append([sbs.hero_rolls.values(), sbs.enemy_rolls.values()])
	_check(draws[0] == draws[1], "the headless re-throw is seeded (identical from the same seed)")
	# Scrap Converter pays on a re-throw landing.
	var both: Object = _mgr(["hereticSignal", "scrapConverter"], [_hero("h1")], [_enemy("e1")])
	var beng: Object = _engine(both)
	var bbs: Object = BS.new()
	var bh: String = _id(both.get_hero_states()[0])
	bbs.hero_rolls = {bh: 12}
	bbs.enemy_rolls = {_id(both.get_enemy_states()[0]): 12}
	var bthrown: Dictionary = beng.apply_heretic_signal(bbs, {"hero": {bh: 2}, "enemy": {_id(both.get_enemy_states()[0]): 9}})
	_check(beng.landing_protocol(bbs, bthrown.get("hero", [])) == 1, "Scrap Converter pays on a re-thrown 2")


# ── Tectonic Charge (G-38) ────────────────────────────────────────────────────

func _tectonic_charge() -> void:
	_section = "Tectonic Charge"
	var dm: Object = DMS.new()
	var cm: Object = _mgr(["tectonicCharge"], [_hero("h1", {"dmg": 7}), _hero("h2", {"dmg": 7})], [_enemy("e1")])
	var eng: Object = _engine(cm)
	var e1: Dictionary = cm.get_enemy_states()[0]
	_check(eng.heroes_hold_this_round(), "the heroes hold in round 1")
	cm.get_hero_states()[1]["dead"] = true   # a fallen hero is charged too, for its revive
	cm.resolve_round({}, {_id(e1): 5}, dm)
	_check(int(e1["current_hp"]) == 100, "no hero acted in round 1")
	_check(not eng.heroes_hold_this_round(), "from round 2 the heroes roll again")
	for hs in cm.get_hero_states():
		_check(int(hs.get("perm_roll_buff", 0)) == 2, "%s rolls +2 from round 2 (dead or alive)" % _id(hs))
	var faces: Array = []
	for n in range(1, 21):
		faces.append(eng.pre_roll_face_value(cm.get_hero_states()[0], true, n))
	var expected: Array = []
	for n in range(1, 21):
		expected.append(mini(n + 2, 20))
	_check(faces == expected, "the +2 is printed on every face (%s)" % [faces])
	_check(int(CM.roll_modifier_totals_of(cm.get_hero_states()[0])["roll_buff"]) == 2, "the roll chip shows +2")
	# Round 3: still +2 (not +4).
	cm.resolve_round({_id(cm.get_hero_states()[0]): 5}, {_id(e1): 5}, dm)
	_check(int(cm.get_hero_states()[0]["perm_roll_buff"]) == 2, "the charge is granted once, not every round")
	# Every battle: a new battle holds again.
	cm.setup_battle([_hero("h1")], [_enemy("e1")])
	_check(cm.heroes_hold_this_round() and int(cm.get_hero_states()[0].get("perm_roll_buff", 0)) == 0, "each battle starts with the hold again")
	var plain: Object = _mgr([], [_hero("h1")], [_enemy("e1")])
	_check(not plain.heroes_hold_this_round(), "no relic, no hold")
	# A refresh in round 1 restores the enemy-only roll.
	_check(not CHECKPOINT.pending_roll_of({"pending_roll": {"hero": {}, "enemy": {"e#1": 5}}}).is_empty(), "a pending roll of enemy dice only is kept")
	_check(CHECKPOINT.pending_roll_of({"pending_roll": {"hero": {}, "enemy": {}}}).is_empty(), "an empty pending roll is still rejected")


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
	for st in scene._relics.hero_roll_states():
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


func _live_scrap_converter() -> void:
	_section = "live Scrap Converter"
	var scene: Node = await _enter(["scrapConverter"])
	scene.protocol_points = 0
	await _roll(scene, [1, 2, 9], [10])
	_check(int(scene.protocol_points) == 2, "landing 1 and 2 pays +2 as the dice settle (got %d)" % int(scene.protocol_points))
	_check(_log_has(scene, "Scrap Converter: +2 Protocol"), "the log names the grant")
	var h: Array = _hero_ids(scene)
	scene.protocol_points = 10
	scene._protocol._apply_set(h[2], 1)
	_check(int(scene.protocol_points) == 6, "a Set to 1 is not a landing (cost only)")
	scene._protocol._apply_nudge(h[0])
	_check(int(scene.protocol_points) == 5, "a Nudge is not a landing (cost only)")
	await _settle(scene)
	# Rerolls are physical landings: each one pays exactly when it shows 1 or 2.
	# The first four with a -18 penalty (every face prints 1 or 2, so every
	# landing must pay), then plain dice (pay only on a 1 or 2).
	var low_seen: int = 0
	var penalized: Dictionary = scene.combat_manager.get_hero_states()[1]
	for i in 10:
		penalized["perm_rfe"] = 18 if i < 4 else 0
		scene.protocol_points = 10
		var before: int = int(scene.protocol_points)
		await scene._protocol._apply_reroll(h[1])
		await _settle(scene)
		var shown: int = int(scene._die_value("hero", h[1]))
		var want: int = before - 2 + (1 if shown <= 2 else 0)
		if shown <= 2:
			low_seen += 1
		_check(int(scene.protocol_points) == want, "a Reroll landing on %d pays %d" % [shown, 1 if shown <= 2 else 0])
	_check(low_seen >= 4, "the penalized rerolls all landed showing 1 or 2 (%d of 10 low)" % low_seen)
	penalized["perm_rfe"] = 0
	# CONTINUE into a settled re-throw never pays twice.
	var pp: int = int(scene.protocol_points)
	scene._relics.on_dice_landed(true)
	_check(int(scene.protocol_points) == pp, "a restored landing is not paid again")


func _live_tectonic_charge() -> void:
	_section = "live Tectonic Charge"
	var scene: Node = await _enter(["tectonicCharge"])
	var gs: Node = root.get_node("/root/GameState")
	await _roll(scene, [10], [6])
	var hero_dice: int = 0
	for key in scene.dice_tray_3d._die_by_key:
		if str(key).begins_with("hero:"):
			hero_dice += 1
	_check(hero_dice == 0 and scene.hero_rolls.is_empty(), "round 1: no hero die is thrown")
	_check(not scene.enemy_rolls.is_empty(), "round 1: the enemy dice are thrown")
	var banner: Variant = scene._relics.get("_hold_banner")
	_check(banner != null and is_instance_valid(banner), "the screen shows the heroes are holding")
	if banner != null and is_instance_valid(banner):
		var text: String = str((banner.find_children("*", "Label", true, false)[0] as Label).text)
		_check(text == "YOUR HEROES HOLD THIS ROUND", "banner text (got '%s')" % text)
		_check(int(banner.mouse_filter) == int(Control.MOUSE_FILTER_IGNORE), "the banner never blocks input")
	_check(int(scene.turn_phase) == int(scene.PHASE_READY_TO_END), "round 1 goes straight to End Turn")
	# Items stay usable while the heroes hold.
	var hero_state: Dictionary = scene.combat_manager.get_hero_states()[0]
	hero_state["current_hp"] = 10
	gs.consumables.append("patch_kit")
	scene.protocol_points = 3
	scene._protocol._phase_before_item = int(scene.turn_phase)
	await scene._protocol._apply_item_effect(root.get_node("/root/DataManager").get_item("patch_kit"), hero_state)
	_check(int(hero_state["current_hp"]) > 10, "an item works in round 1")
	# Dice spends have no hero die to work on.
	scene._protocol._on_nudge_button_pressed()
	_check(int(scene.turn_phase) != int(scene.PHASE_NUDGE_PICK), "Nudge doesn't arm while the heroes hold")
	scene._protocol._on_reroll_button_pressed()
	_check(int(scene.turn_phase) != int(scene.PHASE_REROLL_PICK), "Reroll doesn't arm while the heroes hold")
	# A refresh now keeps the landed enemy dice.
	var cp: Dictionary = root.get_node("/root/SaveManager").peek_run_save().get("battle_checkpoint", {})
	var pending: Dictionary = CHECKPOINT.pending_roll_of(str_to_var(str(cp.get("state", ""))) if cp.has("state") else {})
	_check(not pending.is_empty() and (pending.get("hero", {}) as Dictionary).is_empty(),
		"round 1's enemy-only roll is saved as the pending roll (checkpoint %s, pending %s)" % ["present" if not cp.is_empty() else "missing", pending])
	var hp_before: Array = scene.combat_manager.get_enemy_states().map(func(s): return int(s["current_hp"]))
	await scene._resolve_current_turn(true)
	_check(scene.combat_manager.get_last_cast_order().is_empty(), "no hero acted in round 1")
	_check(scene.combat_manager.get_enemy_states().map(func(s): return int(s["current_hp"])) == hp_before, "the enemies took no hero damage")
	_check(scene._relics.get("_hold_banner") == null, "the banner goes when round 1 ends")
	# Round 2: every hero die is thrown with +2 printed on its faces. (Clear
	# what the enemies did to the heroes in round 1 - a jam or a penalty would
	# also move the faces.)
	for hs in scene.combat_manager.get_hero_states():
		hs["jam_cap"] = 0
		hs["rfe_stacks"] = []
		hs["perm_rfe"] = 0
		hs["rewrite_pending"] = false
		hs["roll_buff_stacks"] = []
		_check(int(hs.get("perm_roll_buff", 0)) == 2, "%s is charged +2 after round 1" % str(hs["id"]))
	await _roll(scene, [5, 9, 13], [6])
	var ids: Array = _hero_ids(scene)
	_check(scene.hero_rolls.size() == ids.size(), "round 2: the heroes roll")
	for hid in ids:
		var faces: Array = scene._die_faces_now("hero", hid).get("faces", [])
		_check(faces.size() == 20 and int(faces[0]) == 3 and int(faces[19]) == 20, "%s prints +2 on its faces" % hid)
		_check(int(scene._die_value("hero", hid)) == int(scene.hero_rolls[hid]) + 2, "%s acts on raw + 2" % hid)
		_check(int(scene.dice_tray_3d.up_face_numeral("hero", hid)) == int(scene._die_value("hero", hid)), "%s shows the value it acts on" % hid)


func _live_firewall_hack() -> void:
	_section = "live Firewall Hack"
	var scene: Node = await _enter(["firewallHack"])
	await _roll(scene, [10], [12])
	var e: Array = _enemy_ids(scene)
	scene.protocol_points = 5
	scene._protocol._on_nudge_button_pressed()
	_check(int(scene.turn_phase) == int(scene.PHASE_NUDGE_PICK), "Nudge arms")
	scene._on_enemy_card_pressed(e[0])
	await _settle(scene)
	_check(int(scene._die_value("enemy", e[0])) == 9, "tapping an enemy die lowers it by 3 (12 -> 9)")
	_check(int(scene.protocol_points) == 4, "for 1 Protocol")
	_check(int(scene.dice_tray_3d.up_face_numeral("enemy", e[0])) == 9, "the die moved to a face showing 9")
	_check(int(scene.turn_phase) != int(scene.PHASE_NUDGE_PICK), "the pick closes")
	var die: RigidBody3D = scene.dice_tray_3d._get_die_for_entry("enemy", e[0])
	var zone9: String = str(scene.dice_manager.get_ability_for_roll(scene.combat_manager.get_enemy_states()[0]["unit"], 9).get("zone", ""))
	_check(die != null and str(die.get_meta("zone", "")) == zone9, "the die's ability highlight follows the new value")
	_check(_log_has(scene, "Firewall Hack:"), "the log names the hack")
	var second: String = e[1] if e.size() > 1 else e[0]
	var value_before: int = int(scene._die_value("enemy", second))
	scene._protocol._on_nudge_button_pressed()
	scene._on_enemy_card_pressed(second)
	_check(int(scene.protocol_points) == 4 and int(scene._die_value("enemy", second)) == value_before, "only once per turn")
	if scene._protocol.in_roll_modifier_pick():
		scene._protocol.cancel_roll_modifier_pick()
	await scene._resolve_current_turn(true)
	if bool(scene.battle_over):
		_check(false, "fixture: the battle ended in round 1")
		return
	await _roll(scene, [10], [15])
	scene.protocol_points = 5
	e = _enemy_ids(scene)
	scene._protocol._on_nudge_button_pressed()
	scene._on_enemy_card_pressed(e[0])
	await _settle(scene)
	_check(int(scene._die_value("enemy", e[0])) == 12, "a new turn allows a new hack (15 -> 12)")


func _live_heretic_signal() -> void:
	_section = "live Heretic Signal"
	var scene: Node = await _enter(["hereticSignal", "scrapConverter"])
	var dm: Node = root.get_node("/root/DataManager")
	var item: Resource = dm.get_item("hereticSignal")
	var state0: Dictionary = scene._relics.relic_menu_state()
	_check(not (state0["usable"] as Array).has("hereticSignal") and str(state0["notes"].get("hereticSignal", "")) == "USE AFTER THE ROLL",
		"before the roll it can't be used (planning phase only)")
	_check(not bool(scene._relics.use_relic(item)), "a tap before the roll does nothing")
	var frozen_hero: Dictionary = scene.combat_manager.get_hero_states()[2]
	frozen_hero["die_freeze_turns"] = 1
	frozen_hero["frozen_die_value"] = 17
	await _roll(scene, [9, 12, 5], [14])
	var h: Array = _hero_ids(scene)
	var frozen_id: String = str(frozen_hero["id"])
	var frozen_die: RigidBody3D = scene.dice_tray_3d._get_die_for_entry("hero", frozen_id)
	scene.protocol_points = 6
	scene._protocol._apply_nudge(h[0])
	await _settle(scene)
	var state1: Dictionary = scene._relics.relic_menu_state()
	_check((state1["usable"] as Array).has("hereticSignal") and str(state1["notes"].get("hereticSignal", "")) == "TAP TO USE", "after the roll it can be used")
	_check(bool(scene._relics.use_relic(item)), "tapping the relic opens the confirm")
	var layer: Variant = scene._relics.get("_confirm_layer")
	_check(layer != null and is_instance_valid(layer), "the confirm is shown")
	if layer == null or not is_instance_valid(layer):
		return
	var texts: Array = (layer.find_children("*", "Label", true, false) as Array).map(func(l): return str(l.text))
	_check(texts.has("Re-throw every die? This can't be undone."), "confirm copy (got %s)" % [texts])
	(layer.find_child("HereticCancel", true, false) as Button).emit_signal("pressed")
	await process_frame
	_check(not bool(scene._state.heretic_signal_used) and scene._relics.get("_confirm_layer") == null, "CANCEL keeps the relic unused")
	var before_rolls: Dictionary = scene.hero_rolls.duplicate()
	var old_die: RigidBody3D = scene.dice_tray_3d._get_die_for_entry("hero", h[0])
	scene._relics.use_relic(item)
	layer = scene._relics.get("_confirm_layer")
	var rig: Dictionary = {"hero:%s" % h[0]: 1, "hero:%s" % h[1]: 11}
	for eid in _enemy_ids(scene):
		rig["enemy:%s" % eid] = 4
	scene.dice_tray_3d.set_rigged_results(rig)
	scene.protocol_points = 3
	(layer.find_child("HereticConfirm", true, false) as Button).emit_signal("pressed")
	for _i in 30:
		await process_frame
	await _settle(scene)
	_check(bool(scene._state.heretic_signal_used), "confirmed: the relic is used")
	_check(int(scene.hero_rolls[h[0]]) == 1 and int(scene.hero_rolls[h[1]]) == 11, "the heroes' dice were re-thrown (%s -> %s)" % [before_rolls, scene.hero_rolls])
	_check(scene.dice_tray_3d._get_die_for_entry("hero", h[0]) != old_die, "a re-thrown die is a new throw")
	for eid in _enemy_ids(scene):
		_check(int(scene.enemy_rolls[eid]) == 4, "enemy %s re-thrown" % eid)
	_check(int(scene.hero_rolls[frozen_id]) == 17 and int(scene._die_value("hero", frozen_id)) == 17, "the frozen die keeps 17")
	_check(scene.dice_tray_3d._get_die_for_entry("hero", frozen_id) == frozen_die, "the frozen die never moved (same die)")
	_check(scene.hero_roll_nudges.is_empty(), "the old Nudge is cleared by the re-throw")
	_check(int(scene.protocol_points) == 4, "Scrap Converter paid for the re-thrown 1 (3 -> 4, got %d)" % int(scene.protocol_points))
	for key in scene.dice_tray_3d._die_by_key:
		var parts: PackedStringArray = str(key).split(":", true, 1)
		_check(int(scene.dice_tray_3d.up_face_numeral(parts[0], parts[1])) == int(scene._die_value(parts[0], parts[1])), "%s shows the value it acts on" % key)
	_check(int(scene.turn_phase) == int(scene.PHASE_TARGETING) or int(scene.turn_phase) == int(scene.PHASE_READY_TO_END), "back to planning")
	var state2: Dictionary = scene._relics.relic_menu_state()
	_check(str(state2["notes"].get("hereticSignal", "")) == "USED THIS BATTLE" and not (state2["usable"] as Array).has("hereticSignal"), "used for the battle")
	_check(not bool(scene._relics.use_relic(item)), "a second tap does nothing")
	# The checkpoint now holds the new dice and the used flag (a refresh restores them).
	var cp: Dictionary = root.get_node("/root/SaveManager").peek_run_save().get("battle_checkpoint", {})
	var st: Variant = str_to_var(str(cp.get("state", "")))
	_check(st is Dictionary and bool((st as Dictionary).get("heretic_signal_used", false)), "the checkpoint records the use")
	var pending: Dictionary = CHECKPOINT.pending_roll_of(st if st is Dictionary else {})
	var same: bool = not pending.is_empty()
	for hid in scene.hero_rolls:
		same = same and int((pending.get("hero", {}) as Dictionary).get(str(hid), -1)) == int(scene.hero_rolls[hid])
	for eid in scene.enemy_rolls:
		same = same and int((pending.get("enemy", {}) as Dictionary).get(str(eid), -1)) == int(scene.enemy_rolls[eid])
	_check(same, "the checkpoint's pending roll is the re-thrown dice")


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
