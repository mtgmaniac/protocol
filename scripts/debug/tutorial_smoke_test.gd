# Scripted end-to-end tutorial playthroughs (v2.1, playtest fix pass: mark
# payoff on Engineer, no leech anywhere, badge beat and Skip button deleted,
# two-stage assign spotlights). Drives the same battle-scene entry points the
# real UI calls and asserts every TutorialController step advances, every
# spotlighted step resolves holes, every assigned-gated step RETARGETS its
# spotlight onto the legal targets when targeting starts, and the HONEST-RIG
# math lands exactly where the coach copy claims (35 -> 18 -> dead; shield
# soaks 3; protocol 1).
#
# Scenario A — the happy path: all 24 steps in the taught order.
# Scenario B — stall-proofing: the mark is resequenced to fire UNSPENT in
#   turn 1 (drone 24), a double-Nudge is attempted on an empty pool, and the
#   cost-0 Shock Charge plus the late-paying mark still win. The drill must
#   be UNABLE to dead-end.
#
# Run:
#   godot --headless --path . -s res://scripts/debug/tutorial_smoke_test.gd
extends SceneTree

const STEP_TIMEOUT_SECS := 20.0
const STEP_COUNT := 24

var _errors: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _run_happy_path()
	if _errors.is_empty():
		await _run_stall_proof_path()

	if _errors.is_empty():
		print("[TUTORIAL_SMOKE] PASS — all %d steps advanced (happy + stall-proof), spotlights resolved + retargeted, rig math exact, no leech" % STEP_COUNT)
		quit(0)
	else:
		for e in _errors:
			push_error("[TUTORIAL_SMOKE] " + e)
		print("[TUTORIAL_SMOKE] FAIL — %d error(s)" % _errors.size())
		quit(1)


# ── Scenario A: the happy path ───────────────────────────────────────────────

func _run_happy_path() -> void:
	var scene: Node = await _start_drill()
	if scene == null:
		return
	var controller: Node = _find_controller(scene)
	if controller == null:
		_fail("TutorialController not spawned in tutorial_mode")
		return
	if (controller.call("_build_steps") as Array).size() != STEP_COUNT:
		_fail("step script must be %d beats (badge beat deleted), got %d" % [STEP_COUNT, (controller.call("_build_steps") as Array).size()])

	# Playtest item 4: leech must appear NOWHERE in the drill — no rigged hero
	# band on either turn carries it (and none reaches the nat-20 overload).
	_assert_no_leech_in_rig(scene)

	# Steps 0-2: orientation taps (WELCOME / header / the drone).
	await _expect_step(controller, 0)
	for _i in range(3):
		_check_holes(controller)
		controller.call("_next")
		await _wait_frames(3)

	# Step 3: ROLL -> step 4 waiter -> step 5.
	await _expect_step(controller, 3)
	_check_holes(controller)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 5)
	await _wait_for_phase(scene, "targeting")

	# Honest rig: real 35-HP drone aiming its Stab at Strike Unit.
	var drone: Dictionary = _enemy_state(scene)
	if int(drone.get("max_hp", 0)) != 35 or int(drone.get("current_hp", 0)) != 35:
		_fail("drone must fight at its REAL statline (35 HP), got %d/%d" % [int(drone.get("current_hp", 0)), int(drone.get("max_hp", 0))])
	if str(drone.get("selected_target_id", "")) != _state_id_for_unit(scene, "combat"):
		_fail("drone must aim at Strike Unit, got '%s'" % str(drone.get("selected_target_id", "")))

	# Step 5: bands beat (tap). Step 6: long-press gate.
	_check_holes(controller)
	controller.call("_next")
	await _expect_step(controller, 6)
	_check_holes(controller)
	scene.emit_signal("tutorial_event", &"inspected", {"side": "hero"})
	await _expect_step(controller, 7)

	# Step 7: mark first (assigned, hero=combat). The hero predicate must
	# ignore an off-script hero, and the spotlight must RETARGET to the legal
	# targets when the gated hero starts targeting (two-stage assign).
	_check_holes(controller)
	await _pick_and_assign(scene, _state_id_for_unit(scene, "medic"))
	if int(controller.get("_step")) != 7:
		_fail("hero predicate leaked: medic's assigned advanced the combat-gated step 7")
	await _pick_and_assign(scene, _state_id_for_unit(scene, "combat"), controller)
	await _expect_step(controller, 8)

	# Step 8: spend it (assigned, hero=engineer) — hostile pick, retarget to drone.
	_check_holes(controller)
	await _pick_and_assign(scene, _state_id_for_unit(scene, "engineer"), controller)
	await _expect_step(controller, 9)

	# Step 9: telegraph beat (tap) — drone card + pip + die holes.
	_check_holes(controller)
	controller.call("_next")
	await _wait_frames(3)

	# Step 10: shield beat (assigned, hero=medic) — medic was assigned
	# off-script earlier; re-tap pulls it back and re-assigning fires the gate
	# (friendly pick, retarget to the ally cards).
	await _expect_step(controller, 10)
	_check_holes(controller)
	scene.call("_unassign_hero_cast", _state_id_for_unit(scene, "medic"))
	await _wait_frames(2)
	_assert_spotlight_on_legal(scene, controller)
	_assign_active_to_legal(scene)
	await _expect_step(controller, 11)

	# Step 11: END TURN (gated turn_resolved).
	_check_holes(controller)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 12)

	# Turn-1 math, exactly as the coach copy claims: mark spent 11 -> 17
	# (drone 35 -> 18, mark consumed); Stab 7 soaked 3 by Diagnostic Pulse's
	# shield (Strike 55 -> 51); protocol = income only = 1.
	drone = _enemy_state(scene)
	if int(drone.get("current_hp", 0)) != 18:
		_fail("turn-1 drone HP: expected 18 (35 - marked 17), got %d" % int(drone.get("current_hp", 0)))
	if bool(drone.get("marked", false)):
		_fail("turn-1 mark must be CONSUMED by Overdrive")
	var strike: Dictionary = _hero_state(scene, "combat")
	if int(strike.get("current_hp", 0)) != 51:
		_fail("turn-1 Strike HP: expected 51 (Stab 7, shield soaked 3), got %d" % int(strike.get("current_hp", 0)))
	if int(scene.get("protocol_points")) != 1:
		_fail("turn-2 protocol: expected 1 (income only), got %d" % int(scene.get("protocol_points")))

	# Step 12: recap (tap). Step 13: roll again -> step 14 waiter -> 15.
	_check_holes(controller)
	controller.call("_next")
	await _expect_step(controller, 13)
	_check_holes(controller)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 15)
	await _wait_for_phase(scene, "targeting")

	# Step 15: protocol beat (tap). Step 16: Nudge button (phase nudge_pick).
	_check_holes(controller)
	controller.call("_next")
	await _expect_step(controller, 16)
	_check_holes(controller)
	var protocol: Node = scene.get("_protocol")
	protocol.call("_on_nudge_button_pressed")
	await _expect_step(controller, 17)

	# Step 17: nudge Strike's die (8 -> 11, the band jump).
	_check_holes(controller)
	var combat_id: String = _state_id_for_unit(scene, "combat")
	protocol.call("_apply_nudge", combat_id)
	await _expect_step(controller, 18)

	# Step 18: band-jump recap (tap, die + pip holes). Step 19: heal beat.
	_check_holes(controller)
	controller.call("_next")
	await _expect_step(controller, 19)
	_check_holes(controller)
	await _pick_and_assign(scene, _state_id_for_unit(scene, "medic"), controller)
	await _expect_step(controller, 20)

	# Step 20: assign the rest (Rail Strike at the drone, Barrier Deploy on
	# an ally) -> ready_to_end.
	_check_holes(controller)
	for hero_id in [combat_id, _state_id_for_unit(scene, "engineer")]:
		await _pick_and_assign(scene, str(hero_id))
	await _expect_step(controller, 21)

	# Step 21: Shock Charge (gated item_used) — 18 HP, dice deal 10, the item
	# stays mathematically necessary.
	_check_holes(controller)
	await _use_shock_charge(scene)
	await _expect_step(controller, 22)
	drone = _enemy_state(scene)
	if int(drone.get("current_hp", 0)) != 8:
		_fail("Shock Charge: expected drone at 8 (18 - 10), got %d" % int(drone.get("current_hp", 0)))

	# Step 22: END TURN (gated won) — Rail Strike 10 into 8.
	_check_holes(controller)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 23)
	if not bool(_enemy_state(scene).get("dead", false)):
		_fail("drone must be dead at the DRILL COMPLETE beat")

	# Step 23: DRILL COMPLETE (tap_finish) -> main menu; done-flag persisted;
	# primers never marked seen (they fire in the first real battle).
	_check_holes(controller)
	controller.call("_next")
	await _wait_frames(10)
	var gs: Node = root.get_node("/root/GameState")
	if bool(gs.get("tutorial_mode")):
		_errors.append("tutorial_mode still true after finish")
	var sm: Node = root.get_node("/root/SaveManager")
	if not bool(sm.call("is_tutorial_done")):
		_errors.append("tutorial_done flag not persisted (main-menu checkmark would not render)")
	for primer_id in ["primer_mark", "primer_icon_protocol"]:
		if bool(sm.call("is_primer_seen", primer_id)):
			_errors.append("%s marked seen during the tutorial — it must still fire in the first real battle" % primer_id)


# ── Scenario B: stall-proofing ───────────────────────────────────────────────
# The player fights the script: the mark is resequenced to fire AFTER
# Overdrive (unspent in turn 1, drone 24), a double-Nudge is attempted on an
# empty pool (no-op), and the cost-0 tutorial item + the late-paying mark on
# Rail Strike still kill on turn 2.

func _run_stall_proof_path() -> void:
	var scene: Node = await _start_drill()
	if scene == null:
		return
	var controller: Node = _find_controller(scene)
	if controller == null:
		_fail("stall-proof: TutorialController not spawned")
		return

	await _expect_step(controller, 0)
	for _i in range(3):
		controller.call("_next")
		await _wait_frames(3)
	await _expect_step(controller, 3)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 5)
	await _wait_for_phase(scene, "targeting")
	controller.call("_next")
	await _expect_step(controller, 6)
	scene.emit_signal("tutorial_event", &"inspected", {"side": "hero"})
	await _expect_step(controller, 7)

	# Steps 7/8 in the taught order (combat then engineer)...
	await _pick_and_assign(scene, _state_id_for_unit(scene, "combat"))
	await _expect_step(controller, 8)
	await _pick_and_assign(scene, _state_id_for_unit(scene, "engineer"))
	await _expect_step(controller, 9)
	controller.call("_next")
	await _wait_frames(3)
	await _expect_step(controller, 10)

	# ...then RESEQUENCE: re-tap Strike Unit — its stamp clears and the
	# recommit appends at the END of the order, so Overdrive now fires BEFORE
	# the mark. The unspent mark must persist into turn 2.
	var combat_id: String = _state_id_for_unit(scene, "combat")
	scene.call("_unassign_hero_cast", combat_id)
	await _wait_frames(2)
	_assign_active_to_legal(scene)
	await _wait_frames(2)
	await _pick_and_assign(scene, _state_id_for_unit(scene, "medic"))
	await _expect_step(controller, 11)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 12)

	var drone: Dictionary = _enemy_state(scene)
	if int(drone.get("current_hp", 0)) != 24:
		_fail("stall-proof turn 1: expected 24 (unmarked 11), got %d" % int(drone.get("current_hp", 0)))
	if not bool(drone.get("marked", false)):
		_fail("stall-proof turn 1: the unspent mark must PERSIST on the drone")

	controller.call("_next")
	await _expect_step(controller, 13)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 15)
	await _wait_for_phase(scene, "targeting")
	controller.call("_next")
	await _expect_step(controller, 16)
	var protocol: Node = scene.get("_protocol")
	protocol.call("_on_nudge_button_pressed")
	await _expect_step(controller, 17)
	protocol.call("_apply_nudge", combat_id)
	await _expect_step(controller, 18)

	# Double-Nudge attempt on the emptied pool (1 income - 1 spent = 0): the
	# button press can't arm, the nudge stays +3, the pool stays 0. (14 would
	# still be Rail Strike's 11-15 band — audit-pinned.)
	protocol.call("_on_nudge_button_pressed")
	protocol.call("_apply_nudge", combat_id)
	if int((scene.get("hero_roll_nudges") as Dictionary).get(combat_id, 0)) != 3:
		_fail("double-Nudge must be a no-op (nudge stays +3)")
	if int(scene.get("protocol_points")) != 0:
		_fail("double-Nudge must not charge on an empty pool, got %d" % int(scene.get("protocol_points")))

	controller.call("_next")
	await _expect_step(controller, 19)
	await _pick_and_assign(scene, _state_id_for_unit(scene, "medic"))
	await _expect_step(controller, 20)
	for hero_id in [combat_id, _state_id_for_unit(scene, "engineer")]:
		await _pick_and_assign(scene, str(hero_id))
	await _expect_step(controller, 21)

	# The cost-0 tutorial item must fire on a 0 pool — no dead end.
	await _use_shock_charge(scene)
	await _expect_step(controller, 22)
	if int(_enemy_state(scene).get("current_hp", 0)) != 14:
		_fail("stall-proof: expected drone at 14 (24 - 10), got %d" % int(_enemy_state(scene).get("current_hp", 0)))

	# END TURN: the persisted mark pays late on Rail Strike (10 -> 15) — 14 dies.
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 23)
	if not bool(_enemy_state(scene).get("dead", false)):
		_fail("stall-proof: the drill dead-ended — drone alive after turn 2 + item")
	controller.call("_next")
	await _wait_frames(10)


# ── Helpers ─────────────────────────────────────────────────────────────────

func _start_drill() -> Node:
	var gs: Node = root.get_node("/root/GameState")
	var sm: Node = root.get_node("/root/SceneManager")
	gs.call("start_tutorial_run")
	sm.call("go_to_battle")
	await _wait_frames(10)
	var scene: Node = current_scene
	if scene == null or scene.get("hero_card_views") == null:
		_fail("Battle scene failed to load for tutorial")
		return null
	var held: Array = gs.get("consumables")
	if held.size() != 1 or str(held[0]) != "shock_charge":
		_fail("tutorial loadout must be exactly one shock_charge, got %s" % str(held))
	return scene


func _find_controller(scene: Node) -> Node:
	for child in scene.get_children():
		if child is TutorialController:
			return child
	return null


func _expect_step(controller: Node, index: int) -> void:
	var frames: int = int(STEP_TIMEOUT_SECS * 60.0)
	while frames > 0:
		frames -= 1
		await process_frame
		if int(controller.get("_step")) >= index:
			await _wait_frames(2)
			return
	_fail("Timed out waiting for tutorial step %d (at %d)" % [index, int(controller.get("_step"))])


func _wait_for_phase(scene: Node, phase: String) -> void:
	var frames: int = int(STEP_TIMEOUT_SECS * 60.0)
	while frames > 0:
		frames -= 1
		await process_frame
		if str(scene.call("phase_name", scene.get("turn_phase"))) == phase:
			return
	_errors.append("Timed out waiting for phase %s" % phase)


# Every step that declares targets/fullscreen must produce at least one hole.
func _check_holes(controller: Node) -> void:
	var step: Dictionary = controller.call("_current")
	var wants_spotlight: bool = bool(step.get("fullscreen", false)) or not (step.get("targets", []) as Array).is_empty()
	if not wants_spotlight:
		return
	var holes: Array = controller.call("_compute_holes", step)
	if holes.is_empty():
		_errors.append("Step %d ('%s…') resolved NO spotlight holes" % [int(controller.get("_step")), str(step.get("text", "")).left(32)])


# Two-stage assign spotlight (playtest items 5/6): after the gated hero's
# targeting_started, the live holes must contain every legal target's card
# center — the player never taps into dimmed screen.
func _assert_spotlight_on_legal(scene: Node, controller: Node) -> void:
	var spot: Variant = controller.get("_spot")
	if spot == null:
		_errors.append("retarget assert: no spotlight layer")
		return
	var canvas: Variant = (spot as Object).get("_dim_canvas")
	if canvas == null:
		_errors.append("retarget assert: no dim canvas")
		return
	var holes: Array = (canvas as Object).get("holes")
	var side: String = str(scene.get("legal_target_side"))
	for id_variant in scene.get("legal_target_ids"):
		var target_id: String = str(id_variant)
		var rect: Rect2
		if side == "enemy" or side == "any":
			rect = controller.call("_enemy_card_rect", target_id)
		else:
			rect = controller.call("_hero_card_rect", target_id)
		if rect.size == Vector2.ZERO:
			continue
		var center: Vector2 = rect.get_center()
		var covered: bool = false
		for hole_variant in holes:
			if (hole_variant as Rect2).has_point(center):
				covered = true
				break
		if not covered:
			_errors.append("step %d spotlight did NOT retarget onto legal target '%s' (side %s)" % [int(controller.get("_step")), target_id, side])


# Playtest item 4: no rigged band on either turn may carry leech (and none
# may reach the nat-20 overload band).
func _assert_no_leech_in_rig(scene: Node) -> void:
	var rigs: Variant = scene.get("TUTORIAL_HERO_ROLLS")
	if not (rigs is Array):
		_errors.append("TUTORIAL_HERO_ROLLS not readable")
		return
	var dm: Object = scene.get("dice_manager")
	for rig_variant in rigs:
		var rig: Dictionary = rig_variant
		for unit_id in rig.keys():
			var state: Dictionary = _hero_state(scene, str(unit_id))
			var unit: Object = state.get("unit", null) as Object
			if unit == null:
				continue
			# The nudged value can shift the band: check the rigged roll AND
			# rigged roll + 3 (the one taught Nudge).
			for roll in [int(rig[unit_id]), mini(int(rig[unit_id]) + 3, 20)]:
				var entry: Dictionary = dm.call("get_ability_for_roll", unit, roll)
				var raw: Dictionary = entry.get("raw", {})
				if bool(raw.get("leech", false)):
					_errors.append("leech leaked into the drill: %s roll %d -> %s" % [str(unit_id), roll, str(entry.get("ability_name", ""))])
				if roll >= 20:
					_errors.append("rig can reach the nat-20 overload band: %s" % str(unit_id))


func _enemy_state(scene: Node) -> Dictionary:
	var cm: Object = scene.get("combat_manager")
	var states: Array = cm.call("get_enemy_states")
	return states[0] if not states.is_empty() else {}


func _hero_state(scene: Node, unit_id: String) -> Dictionary:
	var cm: Object = scene.get("combat_manager")
	for state_variant in cm.call("get_hero_states"):
		var state: Dictionary = state_variant
		var unit: Object = state.get("unit", null) as Object
		if unit != null and str(unit.get("id")) == unit_id:
			return state
	return {}


func _state_id_for_unit(scene: Node, unit_id: String) -> String:
	var state: Dictionary = _hero_state(scene, unit_id)
	return str(state.get("id", ""))


func _assign_active_to_legal(scene: Node) -> void:
	var side: String = str(scene.get("legal_target_side"))
	var ids: Variant = scene.get("legal_target_ids")
	if ids is Array and not (ids as Array).is_empty():
		scene.call("_assign_target_to_active_hero", str((ids as Array)[0]), side)
	else:
		_errors.append("no legal target for the active hero (side='%s')" % side)


# Select then assign. When `controller` is passed, the step is an
# assigned-gated beat for THIS hero — assert the two-stage retarget landed on
# the legal targets between the select and the assign.
func _pick_and_assign(scene: Node, hero_id: String, controller: Node = null) -> void:
	scene.call("_select_targeting_hero", hero_id)
	await _wait_frames(2)
	if controller != null:
		_assert_spotlight_on_legal(scene, controller)
	_assign_active_to_legal(scene)
	await _wait_frames(2)


# Fire the Shock Charge through the real item flow.
func _use_shock_charge(scene: Node) -> void:
	var protocol: Node = scene.get("_protocol")
	var item: Resource = root.get_node("/root/DataManager").call("get_item", "shock_charge")
	if item == null:
		_fail("shock_charge missing from item data")
		return
	protocol.call("_on_item_button_pressed", item)
	await _wait_frames(2)
	if str(scene.call("phase_name", scene.get("turn_phase"))) != "item_pick_enemy":
		_fail("Shock Charge should open the enemy-target pick, phase is '%s'" % str(scene.call("phase_name", scene.get("turn_phase"))))
		return
	var drone_id: String = str(_enemy_state(scene).get("id", ""))
	protocol.call("handle_enemy_card_pressed", drone_id)
	await _wait_frames(2)


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _fail(message: String) -> void:
	_errors.append(message)
	push_error("[TUTORIAL_SMOKE] " + message)
	print("[TUTORIAL_SMOKE] FAIL — %d error(s)" % _errors.size())
	quit(1)
