# "Auto-select sole valid target" regression (G-49, Kev 2026-10-06).
#
#   godot --headless --path . -s scripts/debug/auto_pick_test.gd [-- --auto-pick-break=<mode>]
#
# A live battle, one roll, then every armed action with the setting OFF and ON:
#   OFF  the action arms and waits, nothing is applied, nothing is spent
#   ON   with exactly ONE valid target the pick is made at once and a note names
#        it; with two valid targets the action still waits; never in the tutorial
# Covers Nudge, Reroll, Set (the die is picked, the number is still the
# player's), an item and a hero ability facing one legal enemy (DEMO v0.51:
# OFF it stays pending until tapped, ON it is assigned with the note), plus
# the Settings row (off by default, stored).
# scripts/checks/break_gate.py reruns it with each deliberate break
# (AutoPick.BREAK_ARG: off, any_count, no_cue, hero_always) and requires a FAIL.
extends SceneTree

const AutoPick := preload("res://scripts/battle/auto_pick.gd")
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const SQUAD := ["combat", "engineer", "medic"]
const ITEM_ID := "shock_charge"
const SAVE_FILE := "user://auto_pick_test.json"

var _errors: PackedStringArray = []
var _scene: Node = null
var _protocol: Node = null


func _initialize() -> void:
	call_deferred("_run")


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_errors.append(what)


func sm() -> Node:
	return root.get_node("/root/SaveManager")


func gs() -> Node:
	return root.get_node("/root/GameState")


func _set_on(on: bool) -> void:
	sm().set_setting(AutoPick.SETTING, on)


func _phase() -> int:
	return int(_scene.turn_phase)


func _heroes() -> Array:
	return _scene.combat_manager.get_hero_states()


func _enemies() -> Array:
	return _scene.combat_manager.get_enemy_states()


func _name_of(state: Dictionary) -> String:
	return str(state["unit"].display_name)


func _note() -> String:
	return str(_scene._relics.pick_note_text())


## Freezes every hero die but `keep` dice, so exactly that many can be altered.
func _leave_alterable(keep: int) -> Array:
	var open: Array = []
	for state in _heroes():
		if bool(state.get("dead", false)) or not _scene.hero_rolls.has(str(state["id"])):
			continue
		if open.size() < keep:
			state["die_freeze_turns"] = 0
			open.append(state)
		else:
			state["die_freeze_turns"] = 1
	return open


## Back to the resting phase with nothing armed, whatever a case left behind.
func _disarm() -> void:
	_protocol._close_set_value_popup()
	_protocol.set("_pending_set_hero_id", "")
	if bool(_protocol.in_roll_modifier_pick()):
		_protocol.cancel_roll_modifier_pick()
	if bool(_protocol.in_item_phase()):
		_protocol._cancel_item_targeting("")
	_scene._relics.clear_pick_note()


func _wait_reroll() -> void:
	for i in 900:
		if not bool(_protocol.get("_reroll_busy")):
			return
		await process_frame


func _run() -> void:
	root.size = Vector2i(1080, 2400)
	root.get_node("/root/AudioManager").set_suppressed(true)
	_expect(not bool(sm().get_setting(AutoPick.SETTING, false)), "the setting is off by default")

	var op_id: String = str(root.get_node("/root/DataManager").get_operation_order()[0])
	gs().start_run(SQUAD, op_id, 61007)
	gs().advance_to_next_battle()
	gs().current_battle = 2
	gs().consumables = [ITEM_ID, ITEM_ID, ITEM_ID]
	change_scene_to_file(BATTLE_SCENE)
	for i in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == BATTLE_SCENE:
			break
	await create_timer(0.8).timeout
	_scene = current_scene
	if _scene == null or _scene.scene_file_path != BATTLE_SCENE:
		_errors.append("battle scene did not load")
		_finish()
		return
	_protocol = _scene.get("_protocol")

	await _check_settings_row()

	# One roll, every hero target assigned: the resting phase the buttons arm from.
	await _scene._begin_targeting_phase()
	if _phase() == int(_scene.PHASE_TARGETING):
		await _scene._auto_assign_pending_targets(false)
	_expect(_phase() == int(_scene.PHASE_READY_TO_END), "fixture: the round is ready to end after the roll")
	_expect(_heroes().size() == 3 and _enemies().size() >= 2, "fixture: three heroes and at least two enemies")
	_scene.protocol_points = 10
	_scene._update_protocol_bar()
	_protocol._update_item_panel()

	await _check_nudge()
	await _check_reroll()
	_check_set()
	_check_item()
	_check_hero_ability()
	_check_tutorial()

	_set_on(false)
	for state in _heroes():
		state["die_freeze_turns"] = 0
	_finish()


# ── Settings row ──────────────────────────────────────────────────────────────
func _check_settings_row() -> void:
	# Real serialization into a disposable file, never a player profile.
	sm().set("_save_path", SAVE_FILE)
	sm().set("_disk_enabled", true)
	var help: GDScript = load("res://scripts/ui/help_menu.gd")
	help.open(_scene)
	for i in 8:
		await process_frame
	help._active._select_tab("settings")
	for i in 8:
		await process_frame
	var row: Node = help._active.find_child("AutoSelectToggleRow", true, false)
	_expect(row != null, "Settings has an Auto-select sole valid target row")
	if row != null:
		var toggle: Button = null
		for child in row.get_children():
			if child is Button:
				toggle = child
		_expect(toggle != null and not toggle.button_pressed, "the row starts off")
		if toggle != null:
			toggle.button_pressed = true
			_expect(bool(sm().get_setting(AutoPick.SETTING, false)), "turning the row on stores the setting")
			sm().load_save()
			_expect(bool(sm().get_setting(AutoPick.SETTING, false)), "the setting survives a save reload")
			toggle.button_pressed = false
			_expect(not bool(sm().get_setting(AutoPick.SETTING, false)), "turning the row off stores the setting")
	help._active.dismiss()
	for i in 4:
		await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_FILE + ".bak"))
	sm().set("_disk_enabled", false)


# ── Nudge ─────────────────────────────────────────────────────────────────────
func _check_nudge() -> void:
	var nudge_pick: int = int(_scene.PHASE_NUDGE_PICK)
	var sole: Dictionary = _leave_alterable(1)[0]
	var sole_id: String = str(sole["id"])
	var pp: int = int(_scene.protocol_points)

	_set_on(false)
	_protocol._on_nudge_button_pressed()
	_expect(_phase() == nudge_pick, "OFF: Nudge arms and waits for a tap")
	_expect(not _scene.hero_roll_nudges.has(sole_id) and int(_scene.protocol_points) == pp, "OFF: nothing is nudged or spent")
	_disarm()

	_set_on(true)
	_leave_alterable(2)
	_protocol._on_nudge_button_pressed()
	_expect(_phase() == nudge_pick and _scene.hero_roll_nudges.is_empty(), "ON, two valid dice: Nudge still waits for a tap")
	_expect(int(_scene.protocol_points) == pp, "ON, two valid dice: nothing is spent")
	_disarm()

	_leave_alterable(1)
	_protocol._on_nudge_button_pressed()
	_expect(_phase() != nudge_pick, "ON, one valid die: the Nudge is not left waiting")
	_expect(_scene.hero_roll_nudges.has(sole_id), "ON, one valid die: that die is nudged")
	_expect(int(_scene.protocol_points) == pp - 1, "ON, one valid die: 1 Protocol is spent")
	_expect(_note() == "Only target: %s." % _name_of(sole), "ON: a note names the die that was picked (got '%s')" % _note())
	_disarm()
	await process_frame


# ── Reroll ────────────────────────────────────────────────────────────────────
func _check_reroll() -> void:
	var reroll_pick: int = int(_scene.PHASE_REROLL_PICK)
	var sole: Dictionary = _leave_alterable(1)[0]
	var pp: int = int(_scene.protocol_points)

	_set_on(false)
	_protocol._on_reroll_button_pressed()
	_expect(_phase() == reroll_pick and not bool(_protocol.get("_reroll_busy")), "OFF: Reroll arms and waits for a tap")
	_expect(int(_scene.protocol_points) == pp, "OFF: nothing is spent")
	_disarm()

	_set_on(true)
	_protocol._on_reroll_button_pressed()
	_expect(bool(_protocol.get("_reroll_busy")), "ON, one valid die: the reroll starts at once")
	_expect(_note() == "Only target: %s." % _name_of(sole), "ON: a note names the rerolled die (got '%s')" % _note())
	await _wait_reroll()
	_expect(int(_scene.protocol_points) == pp - 2, "ON, one valid die: 2 Protocol is spent on the reroll")
	_expect(_phase() != reroll_pick, "ON: the reroll finished and nothing is left armed")
	_disarm()
	await process_frame


# ── Set ───────────────────────────────────────────────────────────────────────
func _check_set() -> void:
	var set_pick: int = int(_scene.PHASE_SET_PICK)
	var sole: Dictionary = _leave_alterable(1)[0]
	var pp: int = int(_scene.protocol_points)

	_set_on(false)
	_protocol._on_set_button_pressed()
	_expect(_phase() == set_pick and str(_protocol.get("_pending_set_hero_id")) == "", "OFF: Set arms and waits for a die")
	_disarm()

	_set_on(true)
	_protocol._on_set_button_pressed()
	_expect(str(_protocol.get("_pending_set_hero_id")) == str(sole["id"]), "ON, one valid die: Set opens its number picker for that die")
	var overlay: Node = _protocol.get("_set_value_overlay")
	var note: Label = overlay.find_child("AutoPickNote", true, false) as Label if overlay != null else null
	_expect(note != null and note.text == "Only target: %s." % _name_of(sole), "ON: the picker names the die that was picked")
	_expect(int(_scene.protocol_points) == pp, "ON: Set spends nothing until the number is confirmed")
	_disarm()


# ── Item ──────────────────────────────────────────────────────────────────────
func _check_item() -> void:
	var item: Resource = root.get_node("/root/DataManager").get_item(ITEM_ID)
	var enemy_pick: int = int(_scene.PHASE_ITEM_PICK_ENEMY)
	var held: int = gs().consumables.size()
	var pp: int = int(_scene.protocol_points)

	_set_on(true)
	_protocol._on_item_button_pressed(item)
	_expect(_phase() == enemy_pick and gs().consumables.size() == held, "ON, several enemies: the item still waits for a target")
	_disarm()

	# Leave one enemy standing.
	var sole: Dictionary = {}
	for state in _enemies():
		if sole.is_empty() and not bool(state.get("dead", false)):
			sole = state
		else:
			state["dead"] = true
	var hp_before: int = int(sole["current_hp"])

	_set_on(false)
	_protocol._on_item_button_pressed(item)
	_expect(_phase() == enemy_pick and gs().consumables.size() == held, "OFF, one enemy: the item arms and waits")
	_expect(_protocol.get("_item_targeting_card") != null, "OFF: the item's targeting card is up")
	_disarm()

	_set_on(true)
	_protocol._on_item_button_pressed(item)
	_expect(gs().consumables.size() == held - 1, "ON, one enemy: the item is used at once")
	_expect(int(sole["current_hp"]) < hp_before, "ON, one enemy: its effect lands on that enemy")
	_expect(int(_scene.protocol_points) == pp - 1, "ON, one enemy: the item's Protocol is spent")
	_expect(not bool(_protocol.in_item_phase()) and _protocol.get("_item_targeting_card") == null, "ON: no targeting card is left up")
	_expect(_note() == "Only target: %s." % _name_of(sole), "ON: a note names the enemy that was picked (got '%s')" % _note())
	_disarm()


# ── Hero ability (Kev, DEMO v0.51) ────────────────────────────────────────────
## A roll whose ability attacks one enemy for this hero (after any nudge), or 0.
func _enemy_attack_roll(state: Dictionary) -> int:
	var hero_id: String = str(state["id"])
	for roll in range(1, 21):
		_scene.hero_rolls[hero_id] = roll
		var eff: int = int(_scene._get_effective_roll_for_state(state, hero_id))
		var ability: Dictionary = _scene.dice_manager.get_ability_for_roll(state["unit"], eff)
		var raw: Dictionary = ability.get("raw", {})
		if _scene._get_manual_target_side(ability) == "enemy" and int(raw.get("dmg", 0)) > 0:
			return roll
	return 0


## A fresh targeting phase on the current rolls, as the roll starts one.
func _start_targeting() -> void:
	_scene._relics.clear_pick_note()
	_scene.pending_manual_target_ids.clear()
	_scene.active_targeting_hero_id = ""
	_scene.transition(_scene.PHASE_TARGETING)
	_scene._prepare_hero_targets()
	if _scene.pending_manual_target_ids.is_empty():
		_scene.transition(_scene.PHASE_READY_TO_END)


func _check_hero_ability() -> void:
	var targeting: int = int(_scene.PHASE_TARGETING)
	var sole: Dictionary = {}
	for state in _enemies():
		if not bool(state.get("dead", false)):
			sole = state
	var sole_id: String = str(sole.get("id", ""))
	# Two heroes roll an attack on the one enemy left; the third is set aside so
	# only those two can be pending.
	var attackers: Array = []
	var benched: Array = []
	for state in _heroes():
		state["die_freeze_turns"] = 0
		if attackers.size() < 2 and _enemy_attack_roll(state) > 0:
			attackers.append(state)
		elif not bool(state.get("dead", false)):
			state["dead"] = true
			benched.append(state)
	_expect(not sole.is_empty() and attackers.size() == 2, "fixture: two heroes roll an attack on the one enemy left")
	_expect(_scene._get_taunt_enemy_id() == "", "fixture: no taunt forces the pick")
	if sole.is_empty() or attackers.size() != 2:
		return
	var first_id: String = str(attackers[0]["id"])
	var second_id: String = str(attackers[1]["id"])

	_set_on(false)
	_start_targeting()
	for state in attackers:
		_expect(_scene.pending_manual_target_ids.has(str(state["id"])), "OFF, one legal enemy: %s waits for a tap" % _name_of(state))
		_expect(str(state.get("selected_target_id", "")) == "", "OFF, one legal enemy: %s holds no target" % _name_of(state))
	_expect(_phase() == targeting, "OFF, one legal enemy: the turn is not ready")
	_expect(_note() == "", "OFF: no note (got '%s')" % _note())
	# The player taps the first hero: its lone target is the legal one.
	_scene._on_hero_card_pressed(first_id)
	_expect(str(_scene.active_targeting_hero_id) == first_id and _scene.legal_target_ids == [sole_id],
		"OFF: tapping the hero arms it with the one enemy as its legal target")
	_expect(str(attackers[0].get("selected_target_id", "")) == "", "OFF: arming the hero does not pick for it")
	_scene._on_enemy_card_pressed(sole_id)
	_expect(str(attackers[0].get("selected_target_id", "")) == sole_id, "OFF: tapping the enemy assigns it")
	_expect(_phase() == targeting, "OFF: not ready while the second hero is still pending")
	_scene._on_hero_card_pressed(second_id)
	_scene._on_enemy_card_pressed(sole_id)
	_expect(str(attackers[1].get("selected_target_id", "")) == sole_id, "OFF: the second tap assigns the second hero")
	_expect(_phase() == int(_scene.PHASE_READY_TO_END), "OFF: ready once every pending hero is assigned")

	_set_on(true)
	_start_targeting()
	for state in attackers:
		_expect(not _scene.pending_manual_target_ids.has(str(state["id"])), "ON, one legal enemy: %s is not left pending" % _name_of(state))
		_expect(str(state.get("selected_target_id", "")) == sole_id, "ON, one legal enemy: %s is assigned to it" % _name_of(state))
	_expect(_phase() == int(_scene.PHASE_READY_TO_END), "ON: the turn is ready with nothing to tap")
	_expect(_note() == "Only target: %s." % _name_of(sole), "ON: a note names the enemy that was picked (got '%s')" % _note())
	_set_on(false)
	for state in benched:
		state["dead"] = false
	_scene._relics.clear_pick_note()


# ── Tutorial ──────────────────────────────────────────────────────────────────
func _check_tutorial() -> void:
	_set_on(true)
	_expect(AutoPick.enabled(_scene) or AutoPick.break_mode() == "off", "fixture: the setting reads on outside the tutorial")
	gs().tutorial_mode = true
	_expect(not AutoPick.enabled(_scene), "the tutorial never auto-picks, even with the setting on")
	gs().tutorial_mode = false


func _finish() -> void:
	for error in _errors:
		print("[AUTO_PICK] FAIL - %s" % error)
	print("[AUTO_PICK] %s" % ("PASS" if _errors.is_empty() else "FAIL - %d check(s)" % _errors.size()))
	root.get_node("/root/SaveManager").clear_run_save()
	if current_scene != null:
		current_scene.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)
