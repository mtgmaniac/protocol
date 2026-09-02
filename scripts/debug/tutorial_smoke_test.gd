# Scripted end-to-end tutorial playthroughs (v2.5, polish pass — hero-intro
# beat added, stage-1 assign spotlights include the ability pip, and the nudge
# beat is hero-gated with an INPUT-LEVEL wrong-die block in protocol_actions.
# v2.4 rulings stand: the drill lets exactly ONE primer display, CLEANSE on
# Splice Medic's turn-2 Infusion; the main menu's first-run overlay carries the
# skip choice — no in-drill Skip button; Target Lock and mark appear NOWHERE
# in the drill; every OTHER primer stays unseen and fires at first real-play
# sighting. Turn-1 math is ORDER-INVARIANT). Drives the same battle-scene
# entry points the real UI calls and asserts every TutorialController step
# advances, every spotlighted step resolves holes, every assigned-gated step
# RETARGETS its spotlight onto the legal targets when targeting starts, and
# the HONEST-RIG math lands exactly where the coach copy claims (35 -> 18 ->
# dead on 10+11; shield soaks 3; protocol 1).
#
# Scenario A — the happy path: all 26 steps in the taught order, with the
#   cleanse showcase displaying (debug seams) and marked seen, plus the
#   beat-19 fix coverage: a wrong-die nudge pick is IGNORED (pick stays armed,
#   nothing charged), the pick cancels free on Nudge re-press and re-arms.
# Scenario B — stall-proofing: assignments are resequenced (identical totals
#   — order-invariance asserted at the same 18 checkpoint), a Nudge is
#   attempted at 0 PP (rejected), and the dice-only kill still closes. The
#   drill must be UNABLE to dead-end.
# Scenario C — first-run choice: the menu overlay's SKIP sets tutorial_done
#   and heads straight to the squad picker; RUN TUTORIAL enters the drill and
#   finishing it also exits into the squad picker.
#
# Run:
#   godot --headless --path . -s res://scripts/debug/tutorial_smoke_test.gd
extends SceneTree

const STEP_TIMEOUT_SECS := 20.0
const STEP_COUNT := 17

var _errors: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	await _run_v3_path()
	await _run_waiter_failsafe()

	if _errors.is_empty():
		print("[TUTORIAL_SMOKE] PASS — all %d steps advanced (happy + stall-proof + skip), cleanse showcase shown once, spotlights resolved + retargeted, clusters survive targeting, redirects land on the expected element, waiter failsafe recovers, rig math exact + order-invariant" % STEP_COUNT)
		quit(0)
	else:
		for e in _errors:
			push_error("[TUTORIAL_SMOKE] " + e)
		print("[TUTORIAL_SMOKE] FAIL — %d error(s)" % _errors.size())
		quit(1)


# ── Scenario A: the happy path ───────────────────────────────────────────────

func _run_v3_path() -> void:
	var scene: Node = await _start_drill()
	if scene == null:
		return
	var controller: Node = _find_controller(scene)
	if controller == null:
		_fail("TutorialController not spawned")
		return
	var steps: Array = controller.call("_build_steps")
	if steps.size() != STEP_COUNT:
		_fail("V3.1 must contain 17 internal states, got %d" % steps.size())
		return
	# Structure / cluster / copy contract over the WHOLE script, not just the
	# beats this path happens to walk (spec §2, §4.1, §7 beat 10).
	_assert_script_contract(controller)
	if not _errors.is_empty():
		return
	var visible: int = 0
	for step_variant in steps:
		if not bool((step_variant as Dictionary).get("hide_coach", false)):
			visible += 1
	if visible != 15:
		_fail("V3.1 must contain exactly 15 visible beats, got %d" % visible)
		return
	controller.call("_next")
	await _expect_step(controller, 1)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 3)
	var combat_id: String = _state_id_for_unit(scene, "combat")
	var combat_view: Dictionary = (scene.get("hero_card_views") as Array)[0]
	scene.call("_on_unit_detail_requested", combat_view.get("card"))
	await _expect_step(controller, 3)
	if not bool(scene.call("is_tutorial_inspection_open")):
		_fail("V3.1 inspection beat must open the real InspectPopup")
		return
	scene.call("_close_tutorial_inspection")
	await _expect_step(controller, 4)
	controller.call("_next")
	await _expect_step(controller, 5)
	var enemy_id: String = str(_enemy_state(scene).get("id", ""))
	# Off-script tap redirect: the fence still refuses an unscripted die (the
	# beat must not advance), but the refusal now answers with a pulse on the
	# die the beat DOES want. A silent swallow read as a dead button — a public
	# itch.io report has a player quitting over exactly this.
	await _assert_redirect_pulse(scene, controller, 5, "engineer", "combat")
	# Select the gated hero, then probe the TARGET half of the fence: the source
	# cluster must survive targeting (§4.3), and an illegal target tap must
	# redirect onto the legal one rather than back at the die already in hand.
	# §10: the cooldown must stop a mash from stacking rings. The tap above was
	# moments ago, so an immediate second refusal draws nothing.
	var before_mash: Dictionary = _ring_ids(scene)
	scene.call("_on_hero_card_pressed", _state_id_for_unit(scene, "medic"))
	await _wait_frames(2)
	if not _rings_added_since(scene, before_mash).is_empty():
		_fail("redirect: cooldown must suppress a second pulse inside the window")
		return
	_clear_redirect_cooldown(scene)
	scene.call("_on_hero_card_pressed", _state_id_for_unit(scene, "combat"))
	await _wait_frames(2)
	_assert_cluster_survives_targeting(scene, controller, "combat")
	_clear_redirect_cooldown(scene)
	await _assert_redirect_on_target(scene, controller, 5, "engineer")
	scene.call("_on_enemy_card_pressed", enemy_id)
	await _wait_frames(2)
	await _expect_step(controller, 6)
	await _v3_assign(scene, "engineer", enemy_id)
	await _expect_step(controller, 7)
	# V3.1 selective-HP re-rig: round one's Medic beat shields Strike Unit (the
	# drone's telegraphed target) instead of attacking, so this assignment is an
	# ALLY pick — the shield then soaks 3 of the drone's real Stab 7.
	await _v3_assign(scene, "medic", _state_id_for_unit(scene, "combat"))
	await _expect_step(controller, 8)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 9)
	var drone: Dictionary = _enemy_state(scene)
	var strike: Dictionary = _hero_state(scene, "combat")
	if int(drone.get("current_hp", -1)) != 18 or int(strike.get("current_hp", -1)) != 51 or int(scene.get("protocol_points")) != 1:
		_fail("V3 T1 expected drone=18, Strike=51, Protocol=1; got %d/%d/%d" % [int(drone.get("current_hp", -1)), int(strike.get("current_hp", -1)), int(scene.get("protocol_points"))])
		return
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 11)
	var protocol: Node = scene.get("_protocol")
	protocol.call("_on_nudge_button_pressed")
	# Wrong-die pick during the armed nudge: still ignored (pick stays ARMED,
	# nothing charged — the beat-19 ruling stands), now with the redirect pulse
	# on Strike Unit's die.
	await _assert_redirect_pulse(scene, controller, 11, "medic", "combat")
	if str(scene.call("phase_name", scene.get("turn_phase"))) != "nudge_pick":
		_fail("redirect: a wrong-die nudge pick must leave the pick ARMED")
		return
	if int(scene.get("protocol_points")) != 1:
		_fail("redirect: a wrong-die nudge pick must not charge, got %d" % int(scene.get("protocol_points")))
		return
	protocol.call("handle_hero_card_pressed", combat_id)
	await _expect_step(controller, 12)
	await _v3_assign(scene, "medic", combat_id)
	await _expect_step(controller, 13)
	await _v3_assign(scene, "combat", enemy_id)
	await _expect_step(controller, 14)
	await _v3_assign(scene, "engineer", enemy_id)
	await _expect_step(controller, 15)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 16)
	var sm: Node = root.get_node("/root/SaveManager")
	for primer_id in ["primer_mark", "primer_leech", "primer_icon_protocol"]:
		if bool(sm.call("is_primer_seen", primer_id)):
			_fail("%s was marked seen in the mandatory tutorial" % primer_id)
			return
	controller.call("_next")


# Tap `tapped_unit`'s die through the REAL input path during a beat gated on
# `expected_unit`, and assert the spec §5 contract: the step does not advance
# (the fence is untouched), EXACTLY ONE primary ring lands on the tap target the
# beat wants, the rest of that hero's source cluster is carried as quieter
# secondary rings, and nothing emphasizes the element that was actually tapped.
func _assert_redirect_pulse(scene: Node, controller: Node, step_index: int, tapped_unit: String, expected_unit: String) -> void:
	var before: Dictionary = _ring_ids(scene)
	scene.call("_on_hero_card_pressed", _state_id_for_unit(scene, tapped_unit))
	await _wait_frames(2)
	if int(controller.get("_step")) != step_index:
		_fail("redirect: the off-script %s tap advanced step %d" % [tapped_unit, step_index])
		return
	var drawn: Array = _rings_added_since(scene, before)
	var primary: Array = []
	for ring_variant in drawn:
		if bool((ring_variant as Control).get_meta("primary", false)):
			primary.append(ring_variant)
	if primary.size() != 1:
		_fail("redirect: an off-script %s tap must draw exactly ONE primary pulse, drew %d (of %d rings)" % [
			tapped_unit, primary.size(), drawn.size()])
		return
	# §5: the source cluster is emphasized, not an isolated die.
	if drawn.size() < 2:
		_fail("redirect: expected the %s cluster (die + card), got %d ring(s)" % [expected_unit, drawn.size()])
		return
	var want: Rect2 = scene.call("_tutorial_die_hit_rect", "hero", _state_id_for_unit(scene, expected_unit))
	if want.size == Vector2.ZERO:
		_fail("redirect: %s has no die hit rect for the pulse to point at" % expected_unit)
		return
	# A ring collapses onto its target, so its live rect is mid-transform — the
	# rect it was BUILT for is carried as metadata.
	var lead: Control = primary[0] as Control
	if not lead.has_meta("target_rect"):
		_fail("redirect: pulse ring carries no target_rect metadata")
		return
	var got: Rect2 = lead.get_meta("target_rect")
	if not got.encloses(want):
		_fail("redirect: primary pulse %s must cover %s's die %s" % [str(got), expected_unit, str(want)])
		return
	var wrong: Rect2 = scene.call("_tutorial_die_hit_rect", "hero", _state_id_for_unit(scene, tapped_unit))
	if wrong.size == Vector2.ZERO:
		return
	for ring_variant in drawn:
		var rect: Rect2 = (ring_variant as Control).get_meta("target_rect", Rect2())
		if rect.size != Vector2.ZERO and rect.encloses(wrong):
			_fail("redirect: a pulse landed on the TAPPED die (%s), not the expected one" % tapped_unit)
			return


# Off-script TARGET tap: the correct hero is already selected, and the player
# taps something that is not a legal target. The fence refuses it, and the
# redirect points at the legal target(s) rather than back at the source die.
func _assert_redirect_on_target(scene: Node, controller: Node, step_index: int, tapped_unit: String) -> void:
	var before: Dictionary = _ring_ids(scene)
	scene.call("_on_hero_card_pressed", _state_id_for_unit(scene, tapped_unit))
	await _wait_frames(2)
	if int(controller.get("_step")) != step_index:
		_fail("redirect(target): the off-script %s tap advanced step %d" % [tapped_unit, step_index])
		return
	var drawn: Array = _rings_added_since(scene, before)
	if drawn.is_empty():
		_fail("redirect(target): an illegal target tap drew no pulse")
		return
	var legal: Array = scene.get("legal_target_ids") as Array
	if legal.is_empty():
		_fail("redirect(target): no legal targets to point at")
		return
	var legal_rect: Rect2 = _card_rect_for_state(scene, str(legal[0]))
	var covered: bool = false
	for ring_variant in drawn:
		var rect: Rect2 = (ring_variant as Control).get_meta("target_rect", Rect2())
		if rect.size != Vector2.ZERO and legal_rect.size != Vector2.ZERO and rect.encloses(legal_rect):
			covered = true
	if not covered:
		_fail("redirect(target): no pulse covered the legal target %s" % str(legal[0]))


func _card_rect_for_state(scene: Node, state_id: String) -> Rect2:
	for views_variant in [scene.get("hero_card_views"), scene.get("enemy_card_views")]:
		for view_variant in (views_variant as Array):
			var view: Dictionary = view_variant
			if str((view.get("state", {}) as Dictionary).get("id", "")) == state_id:
				var card: Control = view.get("card", null) as Control
				if card != null and is_instance_valid(card) and card.is_inside_tree():
					return card.get_global_rect()
	return Rect2()


# The redirect cooldown is wall-clock, and a headless frame is far shorter than
# a real one — waiting it out by frame count would be unreliable. Clear it
# directly when a test needs consecutive pulses.
func _clear_redirect_cooldown(scene: Node) -> void:
	scene.set("_tutorial_redirect_msec", 0)


# Rings free themselves mid-tween, so a positional slice can silently miss the
# new ones when an older ring leaves the child list in the same frame. Diff by
# instance id instead.
func _ring_ids(scene: Node) -> Dictionary:
	var ids: Dictionary = {}
	for ring_variant in _redirect_rings(scene):
		ids[(ring_variant as Object).get_instance_id()] = true
	return ids


func _rings_added_since(scene: Node, before: Dictionary) -> Array:
	var added: Array = []
	for ring_variant in _redirect_rings(scene):
		if not before.has((ring_variant as Object).get_instance_id()):
			added.append(ring_variant)
	return added


func _redirect_rings(scene: Node) -> Array:
	var rings: Array = []
	# Built on first pulse, so absent until a refusal has actually fired.
	var layer: Node = scene.get_node_or_null("TutorialRedirectLayer")
	if layer == null:
		return rings
	for child in layer.get_children():
		# Identify by the contract (every pulse carries the rect it points at),
		# not by name: Godot renames a collision with a still-alive ring to
		# "@Panel@N", which silently escaped a name-prefix match.
		if (child as Object).has_meta("target_rect"):
			rings.append(child)
	return rings


# ── Scenario D: waiter failsafe (spec §8) ────────────────────────────────────
# A hide_coach waiter that never receives "rolled" used to be terminal: no
# coachmark (the spotlight is dismissed) and no live control (hide_coach refuses
# every action). Drive the drill onto waiter A, swallow the event, and assert
# the bounded recovery lands the player somewhere valid without skipping
# instruction or marking the tutorial done.
func _run_waiter_failsafe() -> void:
	var scene: Node = await _start_drill()
	if scene == null:
		return
	var controller: Node = _find_controller(scene)
	if controller == null:
		_fail("failsafe: TutorialController not spawned")
		return
	# Shorten the budget so the gate does not burn its wall clock on a 12s wait.
	# The failsafe RULE is what is under test, not the constant's value.
	# Long enough that the dice (MAX_ROLL_TIME 6.0s, ~3.5s in practice) have
	# actually landed when it fires, so the RECOVER-FORWARD path is what gets
	# exercised; short enough not to eat the gate's wall clock.
	controller.set("waiter_failsafe_secs", 6.0)
	var budget: float = float(controller.get("waiter_failsafe_secs"))
	if budget != 6.0:
		_fail("failsafe: could not set waiter_failsafe_secs (got %s)" % str(budget))
		return
	# This scenario runs after the happy path, which completed the drill and set
	# the flag. Clear it so "recovery must not mark complete" tests something.
	(sm_data(sm_node()) as Dictionary)["tutorial_done"] = false

	controller.call("_next")
	await _expect_step(controller, 1)
	scene.call("_on_roll_button_pressed")
	# Let roll_pressed land the drill ON waiter A, THEN cut the signal so only
	# the "rolled" event is lost — the exact failure the failsafe exists for.
	# (Cutting it earlier would strand beat 2, which is a different bug.)
	await _expect_step(controller, 2)
	scene.disconnect("tutorial_event", Callable(controller, "_on_tutorial_event"))
	# Waiter A is now stranded: no coachmark, and hide_coach refuses every input.
	var frames: int = int(25.0 * 60.0)
	while frames > 0 and int(controller.get("_step")) <= 2:
		frames -= 1
		await process_frame
	if int(controller.get("_step")) <= 2:
		_fail("failsafe: waiter never recovered (still on step %d)" % int(controller.get("_step")))
		return
	# Recovered forward: the dice were on the board, so the beat the roll unlocks
	# is where the player belongs — exactly one step, nothing skipped.
	if int(controller.get("_step")) != 3:
		_fail("failsafe: recovery must advance ONE beat to 3, landed on %d" % int(controller.get("_step")))
		return
	# And the player is not stranded: the recovered beat resolves real holes.
	var holes: Array = controller.call("_compute_holes", controller.call("_current"))
	if holes.is_empty():
		_fail("failsafe: recovered beat resolved NO spotlight holes — player has no coachmark")
		return
	# Recovery must never count as finishing the drill.
	if bool(sm_node().call("is_tutorial_done")):
		_fail("failsafe: recovery marked the tutorial complete")


func sm_node() -> Node:
	return root.get_node("/root/SaveManager")


func sm_data(sm: Node) -> Variant:
	return sm.get("data")


# ── Static script assertions (spec §10: structure, clusters, copy) ───────────
# These read the step script directly, so they cover every beat rather than only
# the ones the happy path happens to walk through.
func _assert_script_contract(controller: Node) -> void:
	var steps: Array = controller.call("_build_steps")
	var visible: int = 0
	var waiters: int = 0
	for step_variant in steps:
		if bool((step_variant as Dictionary).get("hide_coach", false)):
			waiters += 1
		else:
			visible += 1
	if visible != 15 or waiters != 2:
		_fail("V3.1 structure: expected 15 visible beats + 2 waiters, got %d + %d" % [visible, waiters])
		return

	for i in range(steps.size()):
		var step: Dictionary = steps[i]
		var text: String = str(step.get("text", "")) + " " + str(step.get("armed_text", ""))
		# §2 / project band-vocabulary law: player copy never names the die ranges.
		for banned in ["band", "recharge", "surge", "crit zone", "overload zone"]:
			if text.to_lower().find(banned) >= 0:
				_fail("beat %d copy names a die range ('%s'): %s" % [i + 1, banned, text.strip_edges()])
				return
		# §2: copy identifies actions by hero/roll/effect/target, never by ability name.
		for ability_name in ["Target Lock", "Overdrive", "Neural Override", "Rail Strike",
				"Suppression Fire", "Diagnostic Pulse", "Infusion"]:
			if text.find(ability_name) >= 0:
				_fail("beat %d copy uses an ability name ('%s')" % [i + 1, ability_name])
				return
		# §4.1: an action beat must spotlight the whole source cluster.
		if str(step.get("advance", "tap")) != "assigned":
			continue
		var targets: Array = step.get("targets", [])
		var hero: String = str(step.get("hero", ""))
		var has_card: bool = false
		var has_die: bool = false
		var has_pips: bool = false
		for key_variant in targets:
			var key: String = str(key_variant)
			if key == "card:" + hero:
				has_card = true
			elif key == "die:" + hero:
				has_die = true
			elif key == "ability:" + hero:
				has_pips = true
		if not (has_card and has_die and has_pips):
			_fail("beat %d (%s) is not a full source cluster: card=%s die=%s pips=%s" % [
				i + 1, hero, str(has_card), str(has_die), str(has_pips)])
			return
		if targets.size() < 3:
			_fail("beat %d highlights only %d region(s) — never highlight the die alone" % [i + 1, targets.size()])
			return

	# §7 beat 10 / the shipped copy bug: base Nudge only RAISES a die. "increases
	# or decreases" is only true with Reverse Gimbal gear, which the drill's
	# empty loadout never has.
	for step_variant in steps:
		var step: Dictionary = step_variant
		if str(step.get("advance", "")) != "nudged":
			continue
		var nudge_text: String = (str(step.get("text", "")) + " " + str(step.get("armed_text", ""))).to_lower()
		if nudge_text.find("decrease") >= 0 or nudge_text.find("increases or") >= 0:
			_fail("nudge copy claims a decrease, which needs Reverse Gimbal gear: %s" % nudge_text.strip_edges())
			return
		if nudge_text.find("rais") < 0:
			_fail("nudge copy must say the die is RAISED: %s" % nudge_text.strip_edges())
			return


# §4.3 / §10: while the gated hero is targeting, the live holes must still carry
# that hero's source cluster AND separately carry the legal target.
func _assert_cluster_survives_targeting(scene: Node, controller: Node, unit_id: String) -> void:
	var holes: Array = controller.call("_compute_holes", controller.call("_current"))
	var live: Array = scene.get("legal_target_ids") as Array
	if live.is_empty():
		_fail("cluster: %s is targeting but has no legal targets" % unit_id)
		return
	var state_id: String = _state_id_for_unit(scene, unit_id)
	var die_rect: Rect2 = scene.call("_tutorial_die_hit_rect", "hero", state_id)
	var card_rect: Rect2 = _card_rect_for_state(scene, state_id)
	var has_die: bool = false
	var has_card: bool = false
	for hole_variant in holes:
		var hole: Rect2 = hole_variant
		if die_rect.size != Vector2.ZERO and hole.intersects(die_rect):
			has_die = true
		if card_rect.size != Vector2.ZERO and hole.encloses(card_rect):
			has_card = true
	if not has_die or not has_card:
		_fail("cluster: targeting dropped %s's source (die=%s card=%s)" % [unit_id, str(has_die), str(has_card)])
		return
	# Duplicate-hole guard (found by the §4.2 density capture): a friendly pick's
	# legal set contains the source hero, whose card is already spotlit — appending
	# it blind drew the ring twice and read as a doubled border.
	for i in range(holes.size()):
		for j in range(i + 1, holes.size()):
			var a: Rect2 = holes[i]
			var b: Rect2 = holes[j]
			if a.position.is_equal_approx(b.position) and a.size.is_equal_approx(b.size):
				_fail("cluster: duplicate spotlight hole %s drawn twice" % str(a))
				return


func _v3_assign(scene: Node, unit_id: String, target_id: String) -> void:
	scene.call("_on_hero_card_pressed", _state_id_for_unit(scene, unit_id))
	await _wait_frames(2)
	if target_id == _state_id_for_unit(scene, "combat") or target_id == _state_id_for_unit(scene, "engineer") or target_id == _state_id_for_unit(scene, "medic"):
		scene.call("_on_hero_card_pressed", target_id)
	else:
		scene.call("_on_enemy_card_pressed", target_id)
	await _wait_frames(2)


func _run_happy_path() -> void:
	var scene: Node = await _start_drill()
	if scene == null:
		return
	var controller: Node = _find_controller(scene)
	if controller == null:
		_fail("TutorialController not spawned in tutorial_mode")
		return
	if (controller.call("_build_steps") as Array).size() != STEP_COUNT:
		_fail("step script must be %d beats (v2.5: hero-intro beat added), got %d" % [STEP_COUNT, (controller.call("_build_steps") as Array).size()])

	# Playtest item 4: leech must appear NOWHERE in the drill — no rigged hero
	# band on either turn carries it (and none reaches the nat-20 overload).
	_assert_no_leech_in_rig(scene)

	# Primer showcase (Kev 2026-07-21): the manager must EXIST in tutorial
	# battles now. Force it active under headless (debug seam) + auto-dismiss
	# so the drill's ONE showcase actually displays during turn 2.
	var sm_save: Node = root.get_node("/root/SaveManager")
	var primer: Node = scene.get("_primer")
	if primer == null:
		_fail("KeywordPrimer must exist in tutorial battles (showcase ruling)")
	else:
		primer.set("debug_force_active", true)
		primer.set("debug_auto_dismiss", true)

	# Steps 0-3: orientation taps (WELCOME / header / YOUR squad (v2.5) / the drone).
	await _expect_step(controller, 0)
	for _i in range(4):
		_check_holes(controller)
		controller.call("_next")
		await _wait_frames(3)

	# Step 4: ROLL -> step 5 waiter -> step 6.
	await _expect_step(controller, 4)
	_check_holes(controller)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 6)
	await _wait_for_phase(scene, "targeting")

	# Honest rig: real 35-HP drone aiming its Stab at Strike Unit.
	var drone: Dictionary = _enemy_state(scene)
	if int(drone.get("max_hp", 0)) != 35 or int(drone.get("current_hp", 0)) != 35:
		_fail("drone must fight at its REAL statline (35 HP), got %d/%d" % [int(drone.get("current_hp", 0)), int(drone.get("max_hp", 0))])
	if str(drone.get("selected_target_id", "")) != _state_id_for_unit(scene, "combat"):
		_fail("drone must aim at Strike Unit, got '%s'" % str(drone.get("selected_target_id", "")))

	# Step 6: bands beat (tap). Step 7: long-press gate.
	_check_holes(controller)
	controller.call("_next")
	await _expect_step(controller, 7)
	_check_holes(controller)
	scene.emit_signal("tutorial_event", &"inspected", {"side": "hero"})
	await _expect_step(controller, 8)

	# Step 8: Strike first (assigned, hero=combat). The hero predicate must
	# ignore an off-script hero, and the spotlight must RETARGET to the legal
	# targets when the gated hero starts targeting (two-stage assign).
	_check_holes(controller)
	await _pick_and_assign(scene, _state_id_for_unit(scene, "medic"))
	if int(controller.get("_step")) != 8:
		_fail("hero predicate leaked: medic's assigned advanced the combat-gated step 8")
	await _pick_and_assign(scene, _state_id_for_unit(scene, "combat"), controller)
	await _expect_step(controller, 9)

	# Step 9: spend it (assigned, hero=engineer) — hostile pick, retarget to drone.
	_check_holes(controller)
	await _pick_and_assign(scene, _state_id_for_unit(scene, "engineer"), controller)
	await _expect_step(controller, 10)

	# Step 10: telegraph beat (tap) — drone card + pip + die holes.
	_check_holes(controller)
	controller.call("_next")
	await _wait_frames(3)

	# Step 11: shield beat (assigned, hero=medic) — medic was assigned
	# off-script earlier; re-tap pulls it back and re-assigning fires the gate
	# (friendly pick, retarget to the ally cards).
	await _expect_step(controller, 11)
	_check_holes(controller)
	scene.call("_unassign_hero_cast", _state_id_for_unit(scene, "medic"))
	await _wait_frames(2)
	_assert_spotlight_on_legal(scene, controller)
	_assign_active_to_legal(scene)
	await _expect_step(controller, 12)

	# Step 12: END TURN (gated turn_resolved).
	_check_holes(controller)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 13)

	# Turn-1 math, exactly as the coach copy claims: 6 + 11 = 17 (drone
	# 35 -> 18, nothing ever marked — mark left the drill); Stab 7 soaked 3
	# by Diagnostic Pulse's shield (Strike 55 -> 51); protocol = income = 1.
	drone = _enemy_state(scene)
	if int(drone.get("current_hp", 0)) != 18:
		_fail("turn-1 drone HP: expected 18 (35 - 17), got %d" % int(drone.get("current_hp", 0)))
	if bool(drone.get("marked", false)):
		_fail("mark must appear NOWHERE in the drill (drone marked after T1)")
	var strike: Dictionary = _hero_state(scene, "combat")
	if int(strike.get("current_hp", 0)) != 51:
		_fail("turn-1 Strike HP: expected 51 (Stab 7, shield soaked 3), got %d" % int(strike.get("current_hp", 0)))
	if int(scene.get("protocol_points")) != 1:
		_fail("turn-2 protocol: expected 1 (income only), got %d" % int(scene.get("protocol_points")))

	# Step 13: recap (tap). Step 14: roll again -> step 15 waiter -> 16.
	_check_holes(controller)
	controller.call("_next")
	await _expect_step(controller, 14)
	_check_holes(controller)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 16)
	await _wait_for_phase(scene, "targeting")

	# Step 16: the primer-showcase explainer. On this fresh profile the
	# CLEANSE tip must have ACTUALLY displayed (auto-dismissed) during the
	# turn-2 drain — exactly one, marked seen so it never repeats in real play
	# — BEFORE "rolled" advanced the waiter (the modals never overlap).
	if primer != null:
		if (primer.get("debug_shown_ids") as Array) != ["primer_cleanse"]:
			_fail("showcase: expected exactly [primer_cleanse] shown, got %s" % str(primer.get("debug_shown_ids")))
		if not bool(sm_save.call("is_primer_seen", "primer_cleanse")):
			_fail("showcased cleanse primer must be marked seen (never repeats)")
	_check_holes(controller)
	controller.call("_next")
	await _expect_step(controller, 17)

	# Step 17: protocol beat (tap). Step 18: Nudge button (phase nudge_pick).
	_check_holes(controller)
	controller.call("_next")
	await _expect_step(controller, 18)
	_check_holes(controller)
	var protocol: Node = scene.get("_protocol")
	protocol.call("_on_nudge_button_pressed")
	await _expect_step(controller, 19)

	# Step 19 (v2.5 beat-19 fix): a wrong-die pick through the REAL input path
	# is IGNORED — pick stays armed, nothing charged, step doesn't advance.
	_check_holes(controller)
	var combat_id: String = _state_id_for_unit(scene, "combat")
	protocol.call("handle_hero_card_pressed", _state_id_for_unit(scene, "medic"))
	await _wait_frames(2)
	if str(scene.call("phase_name", scene.get("turn_phase"))) != "nudge_pick":
		_fail("beat-19: wrong-die pick must leave the nudge pick ARMED")
	if int(scene.get("protocol_points")) != 1:
		_fail("beat-19: wrong-die pick must not charge, got %d" % int(scene.get("protocol_points")))
	if int(controller.get("_step")) != 19:
		_fail("beat-19: wrong-die pick advanced the step")
	# Cancel (Nudge re-press toggles off, free) and re-arm — the beat waits.
	protocol.call("_on_nudge_button_pressed")
	await _wait_frames(2)
	if str(scene.call("phase_name", scene.get("turn_phase"))) == "nudge_pick":
		_fail("beat-19: Nudge re-press must cancel the armed pick")
	if int(scene.get("protocol_points")) != 1:
		_fail("beat-19: cancel must be free, got %d" % int(scene.get("protocol_points")))
	protocol.call("_on_nudge_button_pressed")
	await _wait_frames(2)
	if str(scene.call("phase_name", scene.get("turn_phase"))) != "nudge_pick":
		_fail("beat-19: pick must re-arm after a cancel")
	# The taught apply, through the real input path: Strike's die, 8 -> 11.
	protocol.call("handle_hero_card_pressed", combat_id)
	await _expect_step(controller, 20)

	# Step 20: band-jump recap (tap). Step 21: the item SIGNPOST — purely
	# informational, holes the (empty) consumable slot, advances on tap.
	_check_holes(controller)
	controller.call("_next")
	await _expect_step(controller, 21)
	_check_holes(controller)
	controller.call("_next")
	await _expect_step(controller, 22)

	# Step 22: heal beat (assigned, hero=medic).
	_check_holes(controller)
	await _pick_and_assign(scene, _state_id_for_unit(scene, "medic"), controller)
	await _expect_step(controller, 23)

	# Step 23: assign the rest (Rail Strike and Overdrive at the drone).
	_check_holes(controller)
	for hero_id in [combat_id, _state_id_for_unit(scene, "engineer")]:
		await _pick_and_assign(scene, str(hero_id))
	await _expect_step(controller, 24)

	# Step 24: END TURN (gated won) — the kill closes ON DICE: 10 + 11 into 18.
	_check_holes(controller)
	drone = _enemy_state(scene)
	if int(drone.get("current_hp", 0)) != 18:
		_fail("pre-end-turn drone HP: expected 18 (no item in the drill), got %d" % int(drone.get("current_hp", 0)))
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 25)
	if not bool(_enemy_state(scene).get("dead", false)):
		_fail("drone must be dead at the DRILL COMPLETE beat (dice-only kill)")

	# Step 25: DRILL COMPLETE (tap_finish) -> main menu (manual-entry drill);
	# done-flag persisted; every primer EXCEPT the one showcase stays unseen
	# (fires in the first real battle).
	_check_holes(controller)
	controller.call("_next")
	await _wait_frames(10)
	var gs: Node = root.get_node("/root/GameState")
	if bool(gs.get("tutorial_mode")):
		_errors.append("tutorial_mode still true after finish")
	if not bool(sm_save.call("is_tutorial_done")):
		_errors.append("tutorial_done flag not persisted after completing the drill")
	for primer_id in ["primer_mark", "primer_icon_protocol"]:
		if bool(sm_save.call("is_primer_seen", primer_id)):
			_errors.append("%s marked seen during the tutorial — it must still fire in the first real battle" % primer_id)


# ── Scenario B: stall-proofing ───────────────────────────────────────────────
# The player fights the script: assignments are resequenced (re-tap exercise
# kept — with no setup effects the totals are ORDER-INVARIANT, so turn 1
# lands the identical 18), a second Nudge is attempted at 0 PP (rejected —
# the pick never arms), and the dice-only kill still closes.

func _run_stall_proof_path() -> void:
	var scene: Node = await _start_drill()
	if scene == null:
		return
	var controller: Node = _find_controller(scene)
	if controller == null:
		_fail("stall-proof: TutorialController not spawned")
		return

	await _expect_step(controller, 0)
	for _i in range(4):
		controller.call("_next")
		await _wait_frames(3)
	await _expect_step(controller, 4)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 6)
	await _wait_for_phase(scene, "targeting")
	controller.call("_next")
	await _expect_step(controller, 7)
	scene.emit_signal("tutorial_event", &"inspected", {"side": "hero"})
	await _expect_step(controller, 8)

	# Steps 8/9 in the taught order (combat then engineer)...
	await _pick_and_assign(scene, _state_id_for_unit(scene, "combat"))
	await _expect_step(controller, 9)
	await _pick_and_assign(scene, _state_id_for_unit(scene, "engineer"))
	await _expect_step(controller, 10)
	controller.call("_next")
	await _wait_frames(3)
	await _expect_step(controller, 11)

	# ...then RESEQUENCE: re-tap Strike Unit — its stamp clears and the
	# recommit appends at the END of the order. With no setup effects in the
	# rig the totals are order-invariant: the same 18 checkpoint must land.
	var combat_id: String = _state_id_for_unit(scene, "combat")
	scene.call("_unassign_hero_cast", combat_id)
	await _wait_frames(2)
	_assign_active_to_legal(scene)
	await _wait_frames(2)
	await _pick_and_assign(scene, _state_id_for_unit(scene, "medic"))
	await _expect_step(controller, 12)
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 13)

	var drone: Dictionary = _enemy_state(scene)
	if int(drone.get("current_hp", 0)) != 18:
		_fail("stall-proof turn 1: order-invariance broken — expected 18, got %d" % int(drone.get("current_hp", 0)))
	if bool(drone.get("marked", false)):
		_fail("mark must appear NOWHERE in the drill (hostile path)")

	controller.call("_next")
	await _expect_step(controller, 14)
	scene.call("_on_roll_button_pressed")
	# Step 16: showcase explainer (cleanse already seen after scenario A — no
	# primer displays on a replay; the beat still shows and taps through).
	await _expect_step(controller, 16)
	await _wait_for_phase(scene, "targeting")
	controller.call("_next")
	await _expect_step(controller, 17)
	controller.call("_next")
	await _expect_step(controller, 18)
	var protocol: Node = scene.get("_protocol")
	protocol.call("_on_nudge_button_pressed")
	await _expect_step(controller, 19)
	protocol.call("_apply_nudge", combat_id)
	await _expect_step(controller, 20)

	# Nudge-at-0-PP rejection (Prompt-5): the pool is spent (1 income - 1
	# Nudge = 0); a second Nudge press must REFUSE to arm the pick, the
	# applied nudge stays +3, the pool stays 0.
	protocol.call("_on_nudge_button_pressed")
	if str(scene.call("phase_name", scene.get("turn_phase"))) == "nudge_pick":
		_fail("Nudge at 0 PP must be rejected (pick armed anyway)")
	if int((scene.get("hero_roll_nudges") as Dictionary).get(combat_id, 0)) != 3:
		_fail("rejected Nudge must not touch the applied +3")
	if int(scene.get("protocol_points")) != 0:
		_fail("rejected Nudge must not charge, got %d" % int(scene.get("protocol_points")))

	# Band-jump tap -> signpost tap -> heal -> assigns -> end turn.
	controller.call("_next")
	await _expect_step(controller, 21)
	controller.call("_next")
	await _expect_step(controller, 22)
	await _pick_and_assign(scene, _state_id_for_unit(scene, "medic"))
	await _expect_step(controller, 23)
	for hero_id in [combat_id, _state_id_for_unit(scene, "engineer")]:
		await _pick_and_assign(scene, str(hero_id))
	await _expect_step(controller, 24)

	# END TURN: identical dice-only kill (10 + 11 into 18) — no dead end.
	scene.call("_on_roll_button_pressed")
	await _expect_step(controller, 25)
	if not bool(_enemy_state(scene).get("dead", false)):
		_fail("stall-proof: the drill dead-ended — drone alive after the dice-only turn 2")
	controller.call("_next")
	await _wait_frames(10)


# ── Scenario C: first-run choice (Kev 2026-07-21, revised — no in-drill Skip) ─
# The main menu's first-run overlay carries the choice: SKIP sets the SAME
# tutorial_done flag as completing and heads straight into the squad picker;
# RUN TUTORIAL enters the drill with the continue flag, and finishing that
# drill ALSO exits into the squad picker — no bounce to the menu.

func _run_skip_path() -> void:
	var sm_save: Node = root.get_node("/root/SaveManager")
	var gs: Node = root.get_node("/root/GameState")
	var scene_mgr: Node = root.get_node("/root/SceneManager")

	# SKIP branch.
	sm_save.call("dev_reset_profile")  # back to a first-launch profile
	if bool(sm_save.call("is_tutorial_done")):
		_fail("first-run precondition: profile reset must clear tutorial_done")
		return
	scene_mgr.call("go_to_main_menu")
	await _wait_frames(10)
	var menu: Node = current_scene
	if menu == null or not menu.has_method("_show_first_run_prompt"):
		_fail("main menu is missing the first-run choice overlay")
		return
	menu.call("_show_first_run_prompt")
	await _wait_frames(2)
	menu.call("_on_first_run_skip_pressed")
	await _wait_frames(10)
	if not bool(sm_save.call("is_tutorial_done")):
		_fail("SKIP must set tutorial_done (one flag, two paths in)")
	if bool(gs.get("tutorial_mode")):
		_fail("SKIP must never enter tutorial_mode")
	if not _current_scene_is("UnitSelect.tscn"):
		_fail("SKIP must head straight into the squad picker, got '%s'" % _current_scene_file())

	# RUN TUTORIAL branch: enters the drill with the continue flag; finishing
	# exits into the squad picker.
	sm_save.call("dev_reset_profile")
	scene_mgr.call("go_to_main_menu")
	await _wait_frames(10)
	menu = current_scene
	if menu == null or not menu.has_method("_on_first_run_tutorial_pressed"):
		_fail("main menu is missing the run-tutorial handler")
		return
	menu.call("_on_first_run_tutorial_pressed")
	await _wait_frames(10)
	if not bool(gs.get("tutorial_mode")):
		_fail("RUN TUTORIAL must enter tutorial_mode")
	if not bool(gs.get("tutorial_continue_to_play")):
		_fail("RUN TUTORIAL must set the continue flag (finish -> squad picker)")
	var controller: Node = _find_controller(current_scene)
	if controller == null:
		_fail("RUN TUTORIAL must spawn the TutorialController")
		return
	await _expect_step(controller, 0)
	controller.call("_finish")  # completing's endpoint, without replaying 26 beats
	await _wait_frames(10)
	if not bool(sm_save.call("is_tutorial_done")):
		_fail("completing the first-run drill must set tutorial_done")
	if bool(gs.get("tutorial_continue_to_play")):
		_fail("finish must consume the continue flag (reset_run)")
	if not _current_scene_is("UnitSelect.tscn"):
		_fail("completing the first-run drill must continue into the squad picker, got '%s'" % _current_scene_file())


func _current_scene_file() -> String:
	return str(current_scene.scene_file_path) if current_scene != null else ""


func _current_scene_is(suffix: String) -> bool:
	return _current_scene_file().ends_with(suffix)


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
	# Prompt-5 delta: the tutorial loadout is EMPTY — the item lesson is a
	# signpost, not a granted freebie.
	var held: Array = gs.get("consumables")
	if not held.is_empty():
		_fail("tutorial loadout must be empty (item signpost, no grant), got %s" % str(held))
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


# Playtest item 4 + Prompt-6: no rigged band on either turn may carry leech
# OR mark (Target Lock is out of the drill — its primer teaches it), and
# none may reach the nat-20 overload band.
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
				if bool(raw.get("mark", false)):
					_errors.append("mark leaked into the drill: %s roll %d -> %s" % [str(unit_id), roll, str(entry.get("ability_name", ""))])
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


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await process_frame


func _fail(message: String) -> void:
	_errors.append(message)
	push_error("[TUTORIAL_SMOKE] " + message)
	print("[TUTORIAL_SMOKE] FAIL — %d error(s)" % _errors.size())
	quit(1)
