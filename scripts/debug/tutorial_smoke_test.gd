# Scripted end-to-end tutorial playthroughs (v2 script: honest rig, cast order,
# shield, item). Drives the same battle-scene entry points the real UI calls
# (roll, select die, assign target, nudge, item, end turn) and asserts that
# every TutorialController step advances, every spotlighted step resolves at
# least one hole rect, and the HONEST-RIG math lands exactly where the coach
# copy claims (drone 35 -> 23 -> dead; shield soaks 4; protocol 2).
#
# Scenario A — the happy path: all 25 steps in the taught order.
# Scenario B — stall-proofing: the mark is resequenced to fire UNSPENT in turn
#   1 (combat re-tapped to the end of the cast order), a double-Nudge no-op is
#   attempted, and a stray Nudge drains the pool to 0 — the cost-0 tutorial
#   Shock Charge must still fire and the drill must still be won. The drill
#   must be UNABLE to dead-end.
#
# Run:
#   godot --headless --path . -s res://scripts/debug/tutorial_smoke_test.gd
extends SceneTree

const STEP_TIMEOUT_SECS := 20.0

var _errors: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _run_happy_path()
	if _errors.is_empty():
		await _run_stall_proof_path()

	if _errors.is_empty():
		print("[TUTORIAL_SMOKE] PASS — all 25 steps advanced (happy + stall-proof), spotlights resolved, rig math exact")
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

	# Steps 0-2: orientation taps (WELCOME / header / squad-vs-drone).
	await _expect_step(controller, 0)
	for _i in range(3):
		_check_holes(controller)
		controller.call("_next")
		await _wait_frames(3)

	# Step 3: ROLL (gated roll_pressed) -> step 4 waiter (rolled) -> step 5.
	await _expect_step(controller, 3)
	_check_holes(controller)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 5)
	await _wait_for_phase(scene, "targeting")

	# The honest rig: real 35-HP drone, scripted faces only.
	var drone: Dictionary = _enemy_state(scene)
	if int(drone.get("max_hp", 0)) != 35 or int(drone.get("current_hp", 0)) != 35:
		_fail("drone must fight at its REAL statline (35 HP), got %d/%d" % [int(drone.get("current_hp", 0)), int(drone.get("max_hp", 0))])
	# The drone aims at Strike Unit (SYSTEMATIC slot 0) with its Stab (roll 6).
	if str(drone.get("selected_target_id", "")) != _state_id_for_unit(scene, "combat"):
		_fail("drone must aim at Strike Unit, got '%s'" % str(drone.get("selected_target_id", "")))

	# Step 5: bands beat (tap). Step 6: long-press gate.
	_check_holes(controller)
	controller.call("_next")
	await _expect_step(controller, 6)
	_check_holes(controller)
	scene.emit_signal("tutorial_event", &"inspected", {"side": "hero"})
	await _expect_step(controller, 7)

	# Step 7: mark first (assigned, hero=combat). Off-script heroes must NOT
	# advance the hero-gated step: engineer's assigned event is ignored.
	_check_holes(controller)
	await _pick_and_assign(scene, _state_id_for_unit(scene, "engineer"))
	if int(controller.get("_step")) != 7:
		_fail("hero predicate leaked: engineer's assigned advanced the combat-gated step 7")
	await _pick_and_assign(scene, _state_id_for_unit(scene, "combat"))
	await _expect_step(controller, 8)

	# Step 8: spend it (assigned, hero=medic).
	_check_holes(controller)
	await _pick_and_assign(scene, _state_id_for_unit(scene, "medic"))
	await _expect_step(controller, 9)

	# Steps 9-10: order badges + enemy telegraph (taps).
	for _i in range(2):
		_check_holes(controller)
		controller.call("_next")
		await _wait_frames(3)

	# Step 11: shield beat (assigned, hero=engineer) — engineer was assigned
	# off-script earlier; re-tap pulls it back (unassign) and re-assigning it
	# fires the gate with a fresh end-of-order stamp.
	await _expect_step(controller, 11)
	_check_holes(controller)
	scene.call("_unassign_hero_cast", _state_id_for_unit(scene, "engineer"))
	await _wait_frames(2)
	_assign_active_to_legal(scene)
	await _expect_step(controller, 12)

	# Step 12: END TURN (gated turn_resolved).
	_check_holes(controller)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 13)

	# Turn-1 math, exactly as the coach copy claims: mark spent 8 -> 12
	# (drone 35 -> 23, mark consumed); Stab 7 soaked 4 by Field Patch's
	# shield (Strike 55 -> 52); protocol = income 1 + Field Patch 1 = 2.
	drone = _enemy_state(scene)
	if int(drone.get("current_hp", 0)) != 23:
		_fail("turn-1 drone HP: expected 23 (35 - marked 12), got %d" % int(drone.get("current_hp", 0)))
	if bool(drone.get("marked", false)):
		_fail("turn-1 mark must be CONSUMED by Neural Override")
	var strike: Dictionary = _hero_state(scene, "combat")
	if int(strike.get("current_hp", 0)) != 52:
		_fail("turn-1 Strike HP: expected 52 (Stab 7, shield soaked 4), got %d" % int(strike.get("current_hp", 0)))
	if int(scene.get("protocol_points")) != 2:
		_fail("turn-2 protocol: expected 2 (income 1 + Field Patch 1), got %d" % int(scene.get("protocol_points")))

	# Step 13: recap (tap). Step 14: roll again -> step 15 waiter -> 16.
	_check_holes(controller)
	controller.call("_next")
	await _expect_step(controller, 14)
	_check_holes(controller)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 16)
	await _wait_for_phase(scene, "targeting")

	# Step 16: protocol beat (tap). Step 17: Nudge button (phase nudge_pick).
	_check_holes(controller)
	controller.call("_next")
	await _expect_step(controller, 17)
	_check_holes(controller)
	var protocol: Node = scene.get("_protocol")
	protocol.call("_on_nudge_button_pressed")
	await _expect_step(controller, 18)

	# Step 18: nudge Strike's die (8 -> 11, the band jump).
	_check_holes(controller)
	var combat_id: String = _state_id_for_unit(scene, "combat")
	protocol.call("_apply_nudge", combat_id)
	await _expect_step(controller, 19)

	# Step 19: band-jump recap (tap). Step 20: targeted heal (assigned medic).
	_check_holes(controller)
	controller.call("_next")
	await _expect_step(controller, 20)
	_check_holes(controller)
	await _pick_and_assign(scene, _state_id_for_unit(scene, "medic"))
	await _expect_step(controller, 21)

	# Step 21: assign the rest (phase ready_to_end).
	_check_holes(controller)
	for hero_id in [combat_id, _state_id_for_unit(scene, "engineer")]:
		await _pick_and_assign(scene, str(hero_id))
	await _expect_step(controller, 22)

	# Step 22: Shock Charge (gated item_used) — 23 HP, dice deal 21, the item
	# closes the gap. Enemy-targeted pick: item button -> tap the drone.
	_check_holes(controller)
	await _use_shock_charge(scene)
	await _expect_step(controller, 23)
	drone = _enemy_state(scene)
	if int(drone.get("current_hp", 0)) != 13:
		_fail("Shock Charge: expected drone at 13 (23 - 10), got %d" % int(drone.get("current_hp", 0)))

	# Step 23: END TURN (gated won) — 21 dice damage into 13.
	_check_holes(controller)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 24)
	if not bool(_enemy_state(scene).get("dead", false)):
		_fail("drone must be dead at the DRILL COMPLETE beat")

	# Step 24: DRILL COMPLETE (tap_finish) -> main menu; done-flag persisted;
	# primers must NOT have been marked seen (they fire in the first real
	# battle — the drill sights mark/leech/protocol icons but suppression
	# never writes primers_seen).
	_check_holes(controller)
	controller.call("_next")
	await _wait_frames(10)
	var gs: Node = root.get_node("/root/GameState")
	if bool(gs.get("tutorial_mode")):
		_errors.append("tutorial_mode still true after finish")
	var sm: Node = root.get_node("/root/SaveManager")
	if not bool(sm.call("is_tutorial_done")):
		_errors.append("tutorial_done flag not persisted (main-menu checkmark would not render)")
	for primer_id in ["primer_mark", "primer_leech", "primer_icon_protocol"]:
		if bool(sm.call("is_primer_seen", primer_id)):
			_errors.append("%s marked seen during the tutorial — it must still fire in the first real battle" % primer_id)


# ── Scenario B: stall-proofing ───────────────────────────────────────────────
# The player fights the script: the mark is resequenced to fire AFTER Neural
# Override (unspent in turn 1), a second Nudge on the same die is attempted
# (no-op), and a stray Nudge on Field Engineer drains the pool to 0. The
# cost-0 tutorial item must still fire and the drone must still die.

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

	# Steps 7/8 in the taught order (combat then medic)...
	await _pick_and_assign(scene, _state_id_for_unit(scene, "combat"))
	await _expect_step(controller, 8)
	await _pick_and_assign(scene, _state_id_for_unit(scene, "medic"))
	await _expect_step(controller, 9)
	controller.call("_next")
	await _wait_frames(3)
	controller.call("_next")
	await _wait_frames(3)
	await _expect_step(controller, 11)

	# ...then RESEQUENCE: re-tap Strike Unit — its stamp clears and the
	# recommit appends at the END of the order, so Neural Override now fires
	# BEFORE the mark. The unspent mark must persist into turn 2.
	var combat_id: String = _state_id_for_unit(scene, "combat")
	scene.call("_unassign_hero_cast", combat_id)
	await _wait_frames(2)
	_assign_active_to_legal(scene)
	await _wait_frames(2)
	await _pick_and_assign(scene, _state_id_for_unit(scene, "engineer"))
	await _expect_step(controller, 12)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 13)

	var drone: Dictionary = _enemy_state(scene)
	if int(drone.get("current_hp", 0)) != 27:
		_fail("stall-proof turn 1: expected 27 (unmarked 8), got %d" % int(drone.get("current_hp", 0)))
	if not bool(drone.get("marked", false)):
		_fail("stall-proof turn 1: the unspent mark must PERSIST on the drone")

	controller.call("_next")
	await _expect_step(controller, 14)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 16)
	await _wait_for_phase(scene, "targeting")
	controller.call("_next")
	await _expect_step(controller, 17)
	var protocol: Node = scene.get("_protocol")
	protocol.call("_on_nudge_button_pressed")
	await _expect_step(controller, 18)
	protocol.call("_apply_nudge", combat_id)
	await _expect_step(controller, 19)

	# Double-Nudge on the same die: a no-op (engine "already"), pool unchanged;
	# 11 + 3 would be 14, still Rail Strike's 11-15 band anyway.
	var pool_before: int = int(scene.get("protocol_points"))
	protocol.call("_on_nudge_button_pressed")
	protocol.call("_apply_nudge", combat_id)
	if int((scene.get("hero_roll_nudges") as Dictionary).get(combat_id, 0)) != 3:
		_fail("double-Nudge must be a no-op on the same die (nudge stays +3)")
	if int(scene.get("protocol_points")) != pool_before:
		_fail("double-Nudge must not charge twice")
	# Stray Nudge on Field Engineer (12 -> 15, still Overdrive) drains the
	# pool to 0 — the tutorial item is cost-0, so no dead end.
	protocol.call("_on_nudge_button_pressed")
	protocol.call("_apply_nudge", _state_id_for_unit(scene, "engineer"))

	controller.call("_next")
	await _expect_step(controller, 20)
	await _pick_and_assign(scene, _state_id_for_unit(scene, "medic"))
	await _expect_step(controller, 21)
	for hero_id in [combat_id, _state_id_for_unit(scene, "engineer")]:
		await _pick_and_assign(scene, str(hero_id))
	await _expect_step(controller, 22)

	if int(scene.get("protocol_points")) != 0:
		_fail("stall-proof: pool should be drained to 0 by the stray Nudge, got %d" % int(scene.get("protocol_points")))
	await _use_shock_charge(scene)
	await _expect_step(controller, 23)
	if int(_enemy_state(scene).get("current_hp", 0)) != 17:
		_fail("stall-proof: expected drone at 17 (27 - 10), got %d" % int(_enemy_state(scene).get("current_hp", 0)))

	# END TURN: the persisted mark pays out in turn 2 (Rail Strike 10 -> 15 or
	# Overdrive 11 -> 17, order-dependent) — 17 HP dies either way.
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 24)
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
	# The v2 loadout: exactly one Shock Charge.
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


# Every step that declares targets/fullscreen must produce at least one hole
# (v2: includes the new die:<unit_id> and item keys against the CURRENT card
# chrome — cast-order badges included).
func _check_holes(controller: Node) -> void:
	var step: Dictionary = controller.call("_current")
	var wants_spotlight: bool = bool(step.get("fullscreen", false)) or not (step.get("targets", []) as Array).is_empty()
	if not wants_spotlight:
		return
	var holes: Array = controller.call("_compute_holes", step)
	if holes.is_empty():
		_errors.append("Step %d ('%s…') resolved NO spotlight holes" % [int(controller.get("_step")), str(step.get("text", "")).left(32)])


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


# Assign the currently-targeting hero to the first LEGAL target (whatever side
# its ability wants — enemy for an attack, ally for a heal/shield).
func _assign_active_to_legal(scene: Node) -> void:
	var side: String = str(scene.get("legal_target_side"))
	var ids: Variant = scene.get("legal_target_ids")
	if ids is Array and not (ids as Array).is_empty():
		scene.call("_assign_target_to_active_hero", str((ids as Array)[0]), side)
	else:
		_errors.append("no legal target for the active hero (side='%s')" % side)


func _pick_and_assign(scene: Node, hero_id: String) -> void:
	scene.call("_select_targeting_hero", hero_id)
	await _wait_frames(2)
	_assign_active_to_legal(scene)
	await _wait_frames(2)


# Fire the Shock Charge through the real item flow: item accept -> enemy-pick
# phase -> tap the drone (same handler the enemy card press uses).
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
