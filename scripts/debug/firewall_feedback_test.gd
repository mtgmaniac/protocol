# Firewall feedback gate (playtest 2026-10-08).
#
#   godot --headless --path . -s scripts/debug/firewall_feedback_test.gd [-- --firewall-feedback-break=silent_taunt]
#
# A Firewall cancelled a taunt and nothing said so. Treated as a class: every
# effect a Firewall can cancel must say it was blocked.
#   A. class    CombatManager asks the Firewall at CALL_SITES places. Each case
#               below drives one of them with a small ability twice: with no
#               Firewall the effect lands; with one it does not, the Firewall
#               breaks, one block event names the effect(s) and one log line
#               reads "Firewall blocked <effects> on <unit>.". Every effect name
#               FirewallFeedback defines is covered, and a call site added
#               without a case here fails the count.
#   B. live     a real round: a hero taunts a Firewalled enemy; the BLOCKED
#               chip appears on that enemy's card and the battle log says what
#               was blocked.
#   C. chip     the chip appears under every setting: it pops in normally,
#               appears at once under Reduced Motion, and under No animations
#               neither moves nor fades; it is removed after its hold.
# scripts/checks/break_gate.py reruns it with each FirewallFeedback.BREAK_ARG
# mode (silent_taunt, old_log, no_chip, animated_chip) and requires a FAIL.
extends SceneTree

const FirewallFeedback := preload("res://scripts/battle/firewall_feedback.gd")
const COMBAT_SOURCE := "res://scripts/battle/combat_manager.gd"
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SPEED := 8
# The places CombatManager consults a Firewall. Adding one means adding its
# case to CASES and raising this.
const CALL_SITES := 25

# side: who casts. aim: "warded" = the ability is aimed at the Firewalled unit,
# "other" = at the second unit (the Firewalled one is caught by an area, a
# chain or a spill). effects: what the block must name, in order. probes: what
# must land without a Firewall and must not land with one.
const CASES := [
	# Hero abilities against a Firewalled enemy.
	{"name": "hero attack", "side": "hero", "aim": "warded", "raw": {"dmg": 5}, "effects": ["damage"], "probes": ["hp"]},
	{"name": "hero attack + burn", "side": "hero", "aim": "warded", "raw": {"dmg": 5, "burn": 2, "burnT": 2}, "effects": ["damage", "burn"], "probes": ["hp", "burn"]},
	{"name": "hero attack + mark", "side": "hero", "aim": "warded", "raw": {"dmg": 5, "mark": true}, "effects": ["damage", "mark"], "probes": ["hp", "mark"]},
	{"name": "hero attack + breach", "side": "hero", "aim": "warded", "shield": 6, "raw": {"dmg": 2, "breach": true}, "effects": ["damage", "breach"], "probes": ["shield"]},
	{"name": "hero area attack + burn", "side": "hero", "aim": "other", "raw": {"dmg": 5, "blastAll": true, "burn": 2, "burnT": 2}, "effects": ["damage", "burn"], "probes": ["hp", "burn"]},
	{"name": "hero breach all", "side": "hero", "aim": "other", "shield": 6, "raw": {"dmg": 2, "breachAll": true}, "effects": ["breach"], "probes": ["shield"]},
	{"name": "hero burn", "side": "hero", "aim": "warded", "raw": {"burn": 2, "burnT": 2}, "effects": ["burn"], "probes": ["burn"]},
	{"name": "hero mark", "side": "hero", "aim": "warded", "raw": {"mark": true}, "effects": ["mark"], "probes": ["mark"]},
	{"name": "hero roll penalty", "side": "hero", "aim": "warded", "raw": {"rfe": 2, "rfT": 2}, "effects": ["roll penalty"], "probes": ["rfe"]},
	{"name": "hero roll penalty, all", "side": "hero", "aim": "other", "raw": {"rfe": 2, "rfT": 2, "rfeAll": true}, "effects": ["roll penalty"], "probes": ["rfe"]},
	{"name": "hero taunt", "side": "hero", "aim": "warded", "raw": {"shield": 4, "taunt": true}, "effects": ["taunt"], "probes": ["taunt"]},
	{"name": "hero freeze", "side": "hero", "aim": "warded", "raw": {"freezeEnemyDice": 1}, "effects": ["freeze"], "probes": ["freeze"]},
	{"name": "hero freeze, all", "side": "hero", "aim": "other", "raw": {"freezeAllEnemyDice": 1}, "effects": ["freeze"], "probes": ["freeze"]},
	{"name": "hero jam", "side": "hero", "aim": "warded", "raw": {"jam": true}, "effects": ["jam"], "probes": ["jam"]},
	{"name": "hero jam, all", "side": "hero", "aim": "other", "raw": {"jamAll": true}, "effects": ["jam"], "probes": ["jam"]},
	{"name": "hero rewrite", "side": "hero", "aim": "warded", "raw": {"rewrite": true}, "effects": ["rewrite"], "probes": ["rewrite"]},
	{"name": "hero chain", "side": "hero", "aim": "other", "raw": {"dmg": 6, "chain": 1}, "effects": ["chain damage"], "probes": ["hp"]},
	{"name": "hero Spillover Charge", "side": "hero", "aim": "other", "spill": true, "raw": {"dmg": 12}, "effects": ["Spillover Charge"], "probes": ["hp"]},
	{"name": "hero attack with riders", "side": "hero", "aim": "warded", "raw": {"dmg": 5, "burn": 2, "burnT": 2, "jam": true, "rewrite": true}, "effects": ["damage", "burn", "jam", "rewrite"], "probes": ["hp", "burn", "jam", "rewrite"]},
	# Enemy abilities against a Firewalled hero.
	{"name": "enemy attack", "side": "enemy", "aim": "warded", "raw": {"dmg": 5}, "effects": ["damage"], "probes": ["hp"]},
	{"name": "enemy attack + burn + siphon", "side": "enemy", "aim": "warded", "raw": {"dmg": 5, "burn": 2, "burnT": 2, "siphon": 1}, "effects": ["damage", "burn", "siphon"], "probes": ["hp", "burn", "siphon"]},
	{"name": "enemy area attack", "side": "enemy", "aim": "warded", "raw": {"dmg": 5, "blastAll": true}, "effects": ["damage"], "probes": ["hp"]},
	{"name": "enemy burn", "side": "enemy", "aim": "warded", "raw": {"burn": 2, "burnT": 2}, "effects": ["burn"], "probes": ["burn"]},
	{"name": "enemy roll penalty", "side": "enemy", "aim": "warded", "raw": {"rfm": 2, "rfmT": 2}, "effects": ["roll penalty"], "probes": ["rfe"]},
	{"name": "enemy freeze", "side": "enemy", "aim": "warded", "raw": {"freezeEnemyDice": 1}, "effects": ["freeze"], "probes": ["freeze"]},
	{"name": "enemy freeze, all", "side": "enemy", "aim": "warded", "raw": {"freezeAllEnemyDice": 1}, "effects": ["freeze"], "probes": ["freeze"]},
	{"name": "enemy jam", "side": "enemy", "aim": "warded", "raw": {"jam": true}, "effects": ["jam"], "probes": ["jam"]},
	{"name": "enemy jam, all", "side": "enemy", "aim": "warded", "raw": {"jamAll": true}, "effects": ["jam"], "probes": ["jam"]},
	{"name": "enemy rewrite", "side": "enemy", "aim": "warded", "raw": {"rewrite": true}, "effects": ["rewrite"], "probes": ["rewrite"]},
	{"name": "enemy taunt", "side": "enemy", "aim": "warded", "raw": {"taunt": true}, "effects": ["taunt"], "probes": ["taunt"]},
]

var _errors: PackedStringArray = []


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
	_check_class()
	await _check_live()
	sm().set_setting("reduced_motion", false)
	sm().set_setting("no_animations", false)
	for error in _errors:
		print("[FIREWALL_FEEDBACK] FAIL - %s" % error)
	print("[FIREWALL_FEEDBACK] %s" % ("PASS" if _errors.is_empty() else "FAIL - %d check(s)" % _errors.size()))
	sm().clear_run_save()
	if current_scene != null:
		unload_current_scene()
	await create_timer(0.3).timeout
	quit(0 if _errors.is_empty() else 1)


# ── A. Every effect a Firewall can cancel ─────────────────────────────────────
# The gate's own wording of the line, kept apart from FirewallFeedback.log_line.
func _line(effects: Array, unit_name: String) -> String:
	var what: String = str(effects[0])
	if effects.size() == 2:
		what = "%s and %s" % [effects[0], effects[1]]
	elif effects.size() > 2:
		var head: PackedStringArray = []
		for i in effects.size() - 1:
			head.append(str(effects[i]))
		what = "%s and %s" % [", ".join(head), effects[effects.size() - 1]]
	return "Firewall blocked %s on %s." % [what, unit_name]


func _probe(kind: String, cm: Object, state: Dictionary, before: Dictionary) -> bool:
	match kind:
		"hp":
			return int(state["current_hp"]) < int(before["current_hp"])
		"shield":
			return int(state.get("shield", 0)) < int(before.get("shield", 0))
		"burn":
			return int(state.get("burn", 0)) > 0
		"mark":
			return bool(state.get("marked", false))
		"rfe":
			return not (state.get("rfe_stacks", []) as Array).is_empty()
		"taunt":
			return str(state.get("lured_by_id", "")) != ""
		"freeze":
			return int(state.get("die_freeze_turns", 0)) > 0
		"jam":
			return int(state.get("jam_cap", 0)) > 0
		"rewrite":
			return bool(state.get("rewrite_pending", false))
		"siphon":
			return int(cm.get("_pending_protocol_drain")) > 0
	return false


# One case, with or without the Firewall. Returns {applied: {probe: bool},
# blocks: [block events on the unit], log: [lines], warded: bool, name: String}.
func _drive(case: Dictionary, with_firewall: bool) -> Dictionary:
	var dm: Node = root.get_node("/root/DataManager")
	var hero: UnitData = dm.get_unit("combat") as UnitData
	var enemy: EnemyData = dm.get_enemy_by_display_name("Scrap Drone") as EnemyData
	var cm: Object = load(COMBAT_SOURCE).new()
	var hero_side: bool = str(case["side"]) == "hero"
	# The Firewalled side has two units, so an area, a chain or a spill has a
	# second body to start from; the caster stands alone.
	if hero_side:
		cm.setup_battle([hero], [enemy.duplicate(true), enemy.duplicate(true)])
	else:
		cm.setup_battle([hero], [enemy.duplicate(true)])
	var caster: Dictionary = cm.get_hero_states()[0] if hero_side else cm.get_enemy_states()[0]
	var targets: Array = cm.get_enemy_states() if hero_side else cm.get_hero_states()
	var unit: Dictionary = targets[0]
	var aimed: Dictionary = unit if str(case["aim"]) == "warded" else targets[targets.size() - 1]
	caster["selected_target_id"] = str(aimed["id"])
	if int(case.get("shield", 0)) > 0:
		cm._add_shield_stack(unit, int(case["shield"]))
	if bool(case.get("spill", false)):
		cm.set("_active_relic_effects", [{"type": "overkillSpillover"}])
		aimed["current_hp"] = 2
	if with_firewall:
		unit["warded"] = true
	cm._round_events.clear()
	cm._round_log.clear()
	var before: Dictionary = unit.duplicate(true)
	var entry: Dictionary = {"ability_name": "Gate Probe", "zone": "strike", "raw": case["raw"]}
	if hero_side:
		cm._apply_hero_ability(caster, entry)
	else:
		cm._apply_enemy_ability(caster, entry)
	var applied: Dictionary = {}
	for kind in case["probes"]:
		applied[kind] = _probe(str(kind), cm, unit, before)
	var blocks: Array = []
	for event in cm._round_events:
		if str(event.get("type", "")) == "block" and int(event.get("amount", 0)) <= 0 and str(event.get("target_id", "")) == str(unit["id"]):
			blocks.append(event)
	return {"applied": applied, "blocks": blocks, "log": cm._round_log.duplicate(), "warded": bool(unit.get("warded", false)), "name": str(unit["unit"].display_name)}


func _check_class() -> void:
	# Every call site in the source is counted, so a new one needs a case here.
	var source: String = FileAccess.get_file_as_string(COMBAT_SOURCE)
	var sites: int = source.count("_ward_blocks_hostile(") - 1  # minus the definition
	_expect(sites == CALL_SITES, "CombatManager asks the Firewall at %d places; this gate knows %d. Add the new site's case." % [sites, CALL_SITES])

	var named: Dictionary = {}
	for case in CASES:
		var label: String = str(case["name"])
		var free: Dictionary = _drive(case, false)
		for kind in case["probes"]:
			_expect(bool(free["applied"][kind]), "%s: fixture - with no Firewall the %s lands" % [label, kind])
		_expect((free["blocks"] as Array).is_empty(), "%s: no Firewall, no block" % label)

		var walled: Dictionary = _drive(case, true)
		for kind in case["probes"]:
			_expect(not bool(walled["applied"][kind]), "%s: the Firewall cancels the %s" % [label, kind])
		_expect(not bool(walled["warded"]), "%s: the Firewall breaks" % label)
		var blocks: Array = walled["blocks"]
		_expect(blocks.size() == 1, "%s: one block event (%d)" % [label, blocks.size()])
		var got: Array = (blocks[0] as Dictionary).get("effects", []) if blocks.size() == 1 else []
		_expect(got == case["effects"], "%s: the block names %s, got %s" % [label, str(case["effects"]), str(got)])
		var want_line: String = _line(case["effects"], str(walled["name"]))
		var lines: int = 0
		for line in walled["log"]:
			if str(line).begins_with("Firewall blocked") or str(line).contains("firewall blocks"):
				lines += 1
		_expect((walled["log"] as Array).has(want_line) and lines == 1, "%s: one log line \"%s\" (log: %s)" % [label, want_line, str(walled["log"])])
		for effect in case["effects"]:
			named[str(effect)] = true

	# Every name FirewallFeedback defines is exercised by a case.
	for effect in [FirewallFeedback.DAMAGE, FirewallFeedback.BURN, FirewallFeedback.MARK, FirewallFeedback.BREACH,
			FirewallFeedback.CHAIN, FirewallFeedback.ROLL_PENALTY, FirewallFeedback.TAUNT, FirewallFeedback.FREEZE,
			FirewallFeedback.JAM, FirewallFeedback.REWRITE, FirewallFeedback.SIPHON, FirewallFeedback.SPILLOVER]:
		_expect(named.has(effect), "a case covers the effect \"%s\"" % effect)
	print("[FIREWALL_FEEDBACK] class: %d cases, %d effects, %d call sites" % [CASES.size(), named.size(), sites])


# ── B and C. A real battle ────────────────────────────────────────────────────
func _check_live() -> void:
	Engine.physics_ticks_per_second = 120 * SPEED
	Engine.time_scale = SPEED
	Engine.max_physics_steps_per_frame = 64
	var gs: Node = root.get_node("/root/GameState")
	sm().clear_run_save()
	gs.reset_run()
	# Sentinel's low band is Challenge: 4 shield, taunt.
	gs.start_run(["medic", "engineer", "shield"], "facility", 4242)
	gs.unit_evolutions["shield"] = "Sentinel"
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
	_expect(heroes.size() == 3 and enemies.size() >= 2, "fixture: three heroes, two enemies")
	if heroes.size() != 3 or enemies.size() < 2:
		return
	var rig: Dictionary = {}
	# The face comes from the data: the lowest one in Sentinel's taunt band.
	var taunt_roll: int = 0
	for band in heroes[2]["unit"].dice_ranges:
		if bool(((band as Dictionary).get("raw", {}) as Dictionary).get("taunt", false)):
			taunt_roll = int((band as Dictionary).get("min", 0))
	_expect(taunt_roll > 0, "fixture: Sentinel has a taunt band")
	var hero_vals := [2, 2, taunt_roll]
	for i in heroes.size():
		rig["hero:%s" % heroes[i]["id"]] = hero_vals[i]
	for enemy_state in enemies:
		rig["enemy:%s" % enemy_state["id"]] = 12
	scene.dice_tray_3d.set_rigged_results(rig)
	await scene._begin_targeting_phase()
	await _settle(scene)
	var sentinel: Dictionary = heroes[2]
	var target: Dictionary = enemies[0]
	target["warded"] = true
	var sid: String = str(sentinel["id"])
	if scene._can_unassign_hero(sid) and str(scene.active_targeting_hero_id) != sid:
		scene._unassign_hero_cast(sid)
	if str(scene.active_targeting_hero_id) != sid:
		scene._on_hero_card_pressed(sid)
	scene._on_enemy_card_pressed(str(target["id"]))
	_expect(str(sentinel.get("selected_target_id", "")) == str(target["id"]), "fixture: Sentinel's taunt is aimed at the Firewalled enemy")
	await scene._auto_assign_pending_targets(false)

	# Watch the float layer for the chip while the round plays.
	var seen: Array = []
	var card: Control = scene._feedback._find_card_by_state_id("enemy", str(target["id"]))
	var on_child := func(node: Node) -> void:
		if node.name.begins_with("BlockedChip"):
			seen.append(node)
	scene.float_layer.child_entered_tree.connect(on_child)
	var chip_rect: Array = [Rect2()]
	var chip_text: Array = [""]
	var watch := func() -> void:
		for node in seen:
			if is_instance_valid(node) and chip_text[0] == "":
				var labels: Array = (node as Node).find_children("*", "Label", true, false)
				if not labels.is_empty() and (node as Control).size.x > 0.0:
					chip_text[0] = str((labels[0] as Label).text)
					chip_rect[0] = (node as Control).get_global_rect()
	process_frame.connect(watch)
	await scene._resolve_current_turn(false)
	process_frame.disconnect(watch)
	scene.float_layer.child_entered_tree.disconnect(on_child)
	await create_timer(0.5).timeout

	_expect(str(target.get("lured_by_id", "")) == "", "live: the Firewall ate the taunt")
	_expect(seen.size() == 1, "live: one BLOCKED chip appeared (%d)" % seen.size())
	_expect(chip_text[0] == "BLOCKED", "live: the chip reads BLOCKED (\"%s\")" % chip_text[0])
	if card != null and (chip_rect[0] as Rect2).has_area():
		var card_rect: Rect2 = card.get_global_rect()
		_expect(card_rect.grow(4.0).encloses(chip_rect[0]), "live: the chip sits on the blocked unit's card (%s in %s)" % [str(chip_rect[0]), str(card_rect)])
	var want: String = "Firewall blocked taunt on %s." % str(target["unit"].display_name)
	_expect(str(scene.battle_log_label.get_parsed_text()).contains(want), "live: the battle log reads \"%s\"" % want)

	await _check_chip(scene, card)


func _check_chip(scene: Node, card: Control) -> void:
	Engine.time_scale = 1.0
	var feedback: Node = scene._feedback
	for mode in ["normal", "Reduced Motion", "No animations"]:
		sm().set_setting("reduced_motion", mode == "Reduced Motion")
		sm().set_setting("no_animations", mode == "No animations")
		var before: int = scene.float_layer.get_child_count()
		feedback._show_blocked_chip(card)
		var chip: Control = scene.float_layer.get_child(scene.float_layer.get_child_count() - 1) as Control if scene.float_layer.get_child_count() > before else null
		_expect(chip != null and chip.name.begins_with("BlockedChip"), "%s: the chip appears" % mode)
		if chip == null:
			continue
		# First frame: only the normal mode pops in from small.
		_expect(is_equal_approx(chip.scale.x, 1.0) == (mode != "normal"), "%s: the chip %s (scale %s)" % [mode, "pops in" if mode == "normal" else "appears at once", str(chip.scale)])
		await create_timer(0.6).timeout
		_expect(is_instance_valid(chip) and is_equal_approx(chip.scale.x, 1.0) and is_equal_approx(chip.modulate.a, 1.0), "%s: the chip holds, readable" % mode)
		# Late in its life the chip is fading, except under No animations.
		await create_timer(FirewallFeedback.CHIP_HOLD - 0.6 - 0.08).timeout
		if mode == "No animations":
			_expect(is_instance_valid(chip) and is_equal_approx(chip.modulate.a, 1.0), "%s: the chip never fades" % mode)
		else:
			_expect(is_instance_valid(chip) and chip.modulate.a < 0.99, "%s: the chip fades out" % mode)
		await create_timer(0.4).timeout
		_expect(not is_instance_valid(chip), "%s: the chip is removed after its hold" % mode)


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
