# Accrete display gate (playtest 2026-10-08).
#
#   godot --headless --path . -s scripts/debug/accrete_display_test.gd [-- --accrete-display-break=asked]
#
# The Mantle Tyrant "gained a seemingly random amount of shield, with nothing
# explaining it". Its shield comes from the ACCRETION rule (+6 every 2nd round)
# and from its own 20-shield ability; the round's first +6 showed as a bare
# number while the shield chip stayed on its old value until the boss acted.
# Pinned here: the value shown for an Accrete is the shield applied.
#   A. combat   one path for the unit keyword and the boss rule; the accrete
#               event's amount and the log line's number are the shield actually
#               gained, also when the max-HP cap trims it; at the cap nothing is
#               shown; the rule fires on rounds 1 and 3 of 4; a rampage grant
#               has an event.
#   B. inspect  the Accrete line names the amount and the cadence combat uses.
#   C. live     a real round against the Mantle Tyrant: the ACCRETE chip on the
#               boss reads the amount gained, the shield chip shows that shield
#               on that beat, the rampage chip is not up before the boss grants
#               it, and the battle log line carries the same number.
# scripts/checks/break_gate.py reruns it with each
# CombatManager ACCRETE_BREAK_ARG mode (asked, no_chip, stale_chip, no_line)
# and requires a FAIL.
extends SceneTree

const COMBAT_SOURCE := "res://scripts/battle/combat_manager.gd"
const INSPECT_SOURCE := "res://scripts/ui/inspect_resolver.gd"
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SPEED := 8
const BOSS := "Mantle Tyrant"
const KEYWORD_UNIT := "Magma Drake"

var _errors: PackedStringArray = []


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
	_check_combat()
	_check_inspect()
	await _check_live()
	for error in _errors:
		print("[ACCRETE_DISPLAY] FAIL - %s" % error)
	print("[ACCRETE_DISPLAY] %s" % ("PASS" if _errors.is_empty() else "FAIL - %d check(s)" % _errors.size()))
	sm().clear_run_save()
	if current_scene != null:
		unload_current_scene()
	await create_timer(0.3).timeout
	quit(0 if _errors.is_empty() else 1)


# ── A. Combat ─────────────────────────────────────────────────────────────────
func _battle(enemy_name: String) -> Object:
	var cm: Object = load(COMBAT_SOURCE).new()
	var hero: UnitData = dm().get_unit("combat") as UnitData
	var enemy: EnemyData = dm().get_enemy_by_display_name(enemy_name) as EnemyData
	cm.setup_battle([hero], [enemy.duplicate(true)])
	return cm


# CombatManager's constants, read at run time: a -s harness is parsed before
# the autoloads exist, so it cannot name the class.
func _rule_amount() -> int:
	return int(load(COMBAT_SOURCE).new().MANTLE_ROUND_SHIELD)


func _rule_cadence() -> int:
	return int(load(COMBAT_SOURCE).new().MANTLE_SHIELD_CADENCE)


func _events(cm: Object, type: String) -> Array:
	var out: Array = []
	for event in cm._round_events:
		if str(event.get("type", "")) == type:
			out.append(event)
	return out


# One accrete on `state`: the shown numbers against the shield really gained.
func _accrete_once(cm: Object, state: Dictionary, amount: int, label: String) -> int:
	cm._round_events.clear()
	cm._round_log.clear()
	var before: int = int(state.get("shield", 0))
	cm._apply_accrete(state, amount, true)
	var gained: int = int(state.get("shield", 0)) - before
	var shown: Array = _events(cm, "accrete")
	var unit_name: String = str(state["unit"].display_name)
	if gained > 0:
		_expect(shown.size() == 1, "%s: one accrete event (%d)" % [label, shown.size()])
		if shown.size() == 1:
			_expect(int(shown[0]["amount"]) == gained, "%s: the event shows %d, the shield gained is %d" % [label, int(shown[0]["amount"]), gained])
			_expect(int(shown[0].get("shield_after", -1)) == int(state["shield"]), "%s: the event carries the shield after it (%s vs %d)" % [label, str(shown[0].get("shield_after")), int(state["shield"])])
		_expect(cm._round_log.has("%s accretes %d shield." % [unit_name, gained]), "%s: the log reads \"%s accretes %d shield.\" (%s)" % [label, unit_name, gained, str(cm._round_log)])
		var beats: Array = _events(cm, "action_start")
		_expect(beats.size() == 1 and str(beats[0].get("ability", "")) == "Accrete" and str(beats[0].get("zone", "")) == "tick", "%s: the accrete has a beat of its own" % label)
		_expect(_events(cm, "shield").is_empty(), "%s: no second, generic shield number" % label)
	else:
		_expect(shown.is_empty() and _events(cm, "action_start").is_empty(), "%s: nothing gained, nothing shown" % label)
		_expect(cm._round_log.has("%s's shield is at its limit. Accrete adds nothing." % unit_name), "%s: the log says the shield is at its limit (%s)" % [label, str(cm._round_log)])
	return gained


func _check_combat() -> void:
	# The unit keyword.
	var cm: Object = _battle(KEYWORD_UNIT)
	var drake: Dictionary = cm.get_enemy_states()[0]
	var own: int = int(drake.get("accrete", 0))
	_expect(own > 0, "fixture: %s has the Accrete keyword" % KEYWORD_UNIT)
	_expect(_accrete_once(cm, drake, own, "keyword") == own, "keyword: a free accrete gains the keyword's amount")

	# The max-HP cap trims the gain: the shown value follows the shield applied.
	var cap: int = int(drake["max_hp"])
	drake["shield_stacks"] = [{"amt": cap - 1, "skip_next_tick": true}]
	drake["shield"] = cap - 1
	_expect(_accrete_once(cm, drake, own, "capped") == 1, "capped: only 1 shield fits under the cap")
	_expect(_accrete_once(cm, drake, own, "at the cap") == 0, "at the cap: nothing fits")

	# The same holds for an ordinary shield grant near the cap.
	drake["shield_stacks"] = [{"amt": cap - 2, "skip_next_tick": true}]
	drake["shield"] = cap - 2
	cm._round_events.clear()
	cm._round_log.clear()
	cm._add_shield_stack(drake, 9, true)
	var grants: Array = _events(cm, "shield")
	_expect(grants.size() == 1 and int(grants[0]["amount"]) == 2, "an ordinary grant near the cap shows the 2 applied, not the 9 asked for (%s)" % str(grants))

	# Through a real round: the keyword fires in the enemy phase, after the
	# heroes, with the amount the inspect names.
	cm = _battle(KEYWORD_UNIT)
	drake = cm.get_enemy_states()[0]
	var hero_state: Dictionary = cm.get_hero_states()[0]
	hero_state["selected_target_id"] = str(drake["id"])
	var dice: Object = load("res://scripts/battle/dice_manager.gd").new()
	var result: Dictionary = cm.resolve_round({str(hero_state["id"]): 9}, {str(drake["id"]): 12}, dice)
	var order: Array = []
	for event in result["events"]:
		if str(event.get("type", "")) in ["action_start", "accrete"]:
			order.append("%s:%s" % [str(event.get("type", "")), str(event.get("ability", event.get("amount", "")))])
	var accrete_at: int = order.find("accrete:%d" % own)
	_expect(accrete_at >= 2 and order[accrete_at - 1] == "action_start:Accrete", "round: the keyword accretes %d on its own beat after the hero phase (%s)" % [own, str(order)])

	# The boss rule: rounds 1 and 3 of 4, 6 each, through the same path.
	cm = _battle(BOSS)
	var tyrant: Dictionary = cm.get_enemy_states()[0]
	var fired: Array = []
	for round_number in range(1, 5):
		cm._round_events.clear()
		cm._round_log.clear()
		var before: int = int(tyrant.get("shield", 0))
		cm._apply_boss_round_start_rules()
		var gained: int = int(tyrant.get("shield", 0)) - before
		var shown: Array = _events(cm, "accrete")
		if gained > 0:
			fired.append(round_number)
			_expect(shown.size() == 1 and int(shown[0]["amount"]) == gained, "boss round %d: the event shows the %d gained (%s)" % [round_number, gained, str(shown)])
			_expect(bool(shown[0].get("standing_rule", false)) if shown.size() == 1 else false, "boss round %d: the event is marked as the standing rule (no keyword primer)" % round_number)
			_expect(cm._round_log.has("%s accretes %d shield." % [BOSS, gained]), "boss round %d: the log reads \"%s accretes %d shield.\"" % [round_number, BOSS, gained])
		else:
			_expect(shown.is_empty(), "boss round %d: no accrete, nothing shown" % round_number)
	_expect(fired == [1, 3], "the boss accretes on rounds 1 and 3 of 4 (%s)" % str(fired))
	_expect(int(tyrant.get("shield", 0)) == 2 * _rule_amount(), "the boss keeps both layers (%d)" % int(tyrant.get("shield", 0)))

	# A rampage grant has an event, so its chip can land on the granting beat.
	cm._round_events.clear()
	cm._apply_enemy_ability(tyrant, {"ability_name": "Gate Probe", "zone": "recharge", "raw": {"grantRampage": 1}})
	_expect(_events(cm, "rampage_up").size() == 1, "a rampage grant emits rampage_up")


# ── B. Inspect ────────────────────────────────────────────────────────────────
func _check_inspect() -> void:
	var resolver: GDScript = load(INSPECT_SOURCE)
	for case in [
		[KEYWORD_UNIT, int((dm().get_enemy_by_display_name(KEYWORD_UNIT) as EnemyData).accrete), "ACCRETE: always gains %d shield at the start of each of its turns."],
		[BOSS, _rule_amount(), "ACCRETE: always gains %d shield every 2nd round, before your heroes act."],
	]:
		var unit: Resource = dm().get_enemy_by_display_name(str(case[0]))
		var payload: Dictionary = resolver.resolve_unit(unit, {})
		var statuses: Array = payload.get("statuses", [])
		# A unit with a trait as well (Feral, G-66) leads with the trait's
		# line; the Accrete line is the first one after it.
		var has_trait: bool = not statuses.is_empty() and bool((statuses[0] as Dictionary).get("trait", false))
		_expect(has_trait == (not (unit.unit_trait as Dictionary).is_empty()), "inspect %s: a trait line leads only when the unit has a trait" % case[0])
		var entry: Dictionary = statuses[1 if has_trait else 0] if statuses.size() > (1 if has_trait else 0) else {}
		var pips: Array = entry.get("effects", [])
		var pip: Dictionary = pips[0] if not pips.is_empty() else {}
		_expect(str(pip.get("kind", "")) == "accrete" and str(pip.get("value", "")) == str(case[1]), "inspect %s: the Accrete pip shows %d (%s)" % [case[0], case[1], str(pip)])
		_expect(str(entry.get("text", "")) == str(case[2]) % int(case[1]), "inspect %s: the line reads \"%s\" (\"%s\")" % [case[0], str(case[2]) % int(case[1]), str(entry.get("text", ""))])
	_expect(_rule_cadence() == 2, "the inspect's \"every 2nd round\" is the cadence combat uses")
	var plain: Dictionary = resolver.resolve_unit(dm().get_enemy_by_display_name("Scrap Drone"), {})
	_expect((plain.get("statuses", []) as Array).is_empty(), "a unit with no Accrete gets no line")


# ── C. A real round against the boss ──────────────────────────────────────────
func _check_live() -> void:
	Engine.physics_ticks_per_second = 120 * SPEED
	Engine.time_scale = SPEED
	Engine.max_physics_steps_per_frame = 64
	var gs: Node = root.get_node("/root/GameState")
	sm().clear_run_save()
	gs.reset_run()
	gs.start_run(["combat", "engineer", "medic"], "stellarMenagerie", 77)
	gs.advance_to_next_battle()
	gs.current_battle = 10
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
	var boss: Dictionary = {}
	for enemy_state in enemies:
		if str(enemy_state["unit"].display_name) == BOSS:
			boss = enemy_state
	_expect(not boss.is_empty(), "fixture: the Mantle Tyrant is on the field")
	if boss.is_empty():
		return
	# Round 1: the boss rolls its shield-and-rampage ability, so the round
	# changes its shield three times: accrete, a hero hit, its own grant. The
	# boss's face and the first hero's attack come from the kits; the other
	# dice only have to land.
	var boss_roll: int = 0
	for roll in range(20, 0, -1):
		var boss_raw: Dictionary = scene.dice_manager.get_ability_for_roll(boss["unit"], roll).get("raw", {})
		if int(boss_raw.get("grantRampage", 0)) > 0 and int(boss_raw.get("shield", 0)) > 0:
			boss_roll = roll
	_expect(boss_roll > 0, "fixture: the boss has a shield-and-rampage ability")
	var hitter_roll: int = 0
	for roll in [9] + range(1, 21):
		var hit_raw: Dictionary = scene.dice_manager.get_ability_for_roll(heroes[0]["unit"], roll).get("raw", {})
		if hitter_roll == 0 and int(hit_raw.get("dmg", 0)) > 0:
			hitter_roll = roll
	_expect(hitter_roll > 0, "fixture: the first hero has an attack")
	var rig: Dictionary = {}
	for hero_state in heroes:
		rig["hero:%s" % hero_state["id"]] = hitter_roll if hero_state == heroes[0] else 9
	for enemy_state in enemies:
		rig["enemy:%s" % enemy_state["id"]] = boss_roll if enemy_state == boss else 12
	scene.dice_tray_3d.set_rigged_results(rig)
	await scene._begin_targeting_phase()
	await _settle(scene)
	if int(scene.turn_phase) == int(scene.PHASE_TARGETING):
		await scene._auto_assign_pending_targets(false)
	_expect(int(boss.get("shield", 0)) == 0, "fixture: the boss starts round 1 with no shield")

	var card: Control = scene._feedback._find_card_by_state_id("enemy", str(boss["id"]))
	var seen: Array = []          # the chip nodes
	var at_chip: Array = []       # the boss's chip row as the ACCRETE chip arrives
	var on_child := func(node: Node) -> void:
		if node.name.begins_with("AccreteChip"):
			seen.append(node)
			at_chip.append(scene._card_view._composed_status_tokens(boss))
	scene.float_layer.child_entered_tree.connect(on_child)
	var chip_text: Array = [""]
	var chip_rect: Array = [Rect2()]
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

	var gained: int = _rule_amount()
	_expect(seen.size() == 1, "live: one ACCRETE chip on round 1 (%d)" % seen.size())
	_expect(chip_text[0] == "ACCRETE +%d" % gained, "live: the chip reads \"ACCRETE +%d\" (\"%s\")" % [gained, chip_text[0]])
	if card != null and (chip_rect[0] as Rect2).has_area():
		_expect(card.get_global_rect().grow(4.0).encloses(chip_rect[0]), "live: the chip sits on the boss's card")
	var shield_then: int = -1
	var rampage_then: bool = false
	if not at_chip.is_empty():
		shield_then = 0
		for token in at_chip[0]:
			if str(token.get("type", "")) == "shield":
				shield_then = int(token.get("value", 0))
			if str(token.get("type", "")) == "rampage":
				rampage_then = true
	_expect(shield_then == gained, "live: the shield chip reads %d on the accrete beat (%d)" % [gained, shield_then])
	_expect(not rampage_then, "live: the rampage chip is not up before the boss grants it")
	var log_text: String = str(scene.battle_log_label.get_parsed_text())
	_expect(log_text.contains("%s accretes %d shield." % [BOSS, gained]), "live: the battle log reads \"%s accretes %d shield.\"" % [BOSS, gained])
	# After the sequence the chip row is the live state again.
	var shield_now: int = 0
	var rampage_now: bool = false
	for token in scene._card_view._composed_status_tokens(boss):
		if str(token.get("type", "")) == "shield":
			shield_now = int(token.get("value", 0))
		if str(token.get("type", "")) == "rampage":
			rampage_now = true
	_expect(shield_now == int(boss.get("shield", 0)) and shield_now > gained, "live: after the round the chip is the boss's real shield (%d, state %d)" % [shield_now, int(boss.get("shield", 0))])
	_expect(rampage_now, "live: the rampage chip is up once the boss has granted it")

	# The chip is not an animation: it still appears under No animations.
	Engine.time_scale = 1.0
	sm().set_setting("no_animations", true)
	var before: int = scene.float_layer.get_child_count()
	scene._feedback._show_accrete_chip(card, gained)
	_expect(scene.float_layer.get_child_count() == before + 1, "No animations: the ACCRETE chip still appears")
	sm().set_setting("no_animations", false)


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
