# Drives the drill through the REAL input path — synthesized mouse events
# pushed at on-screen coordinates — instead of calling scene handlers directly.
#
# WHY a second tutorial test: training_flow_test drives the drill with
# `scene.call("_on_roll_button_pressed")` and friends. That proves the step
# logic and is blind by construction to whether a player could ever reach the
# scripted control, and equally blind to a beat that receives no valid input at
# all. Both of those shipped: a desktop player met a gated beat with no timeout
# (only the header back arrow) and abandoned the drill.
#
# Covers:
#   1. the scripted target is HITTABLE at the authored size, a small canvas
#      (342x760), a wider-than-authored portrait (560x960) and a landscape
#      desktop window (1366x768), by clicking its real on-screen rect — the Web
#      build takes whatever size the browser/iframe gives it (canvas_items +
#      expand, no page-side width cap), so no aspect may strand a target;
#   2. a gated beat that receives only INVALID input offers the assist and does
#      NOT advance on its own;
#   3. taking the offer PERFORMS the beat's action (the dice really roll) rather
#      than skipping it;
#   4. the beat counts, so a lesson edit has to update this number on purpose;
#   5. the long-press cancel tolerance is a device-pixel distance.
extends SceneTree

const LESSONS := preload("res://scripts/ui/training_lessons.gd")
const ASSIST_BUDGET_SECS := 1.0  # test seam; the shipped budget is 20s
const LONG_PRESS_DEVICE_PX := 26.0

var errors: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)
	print("[TUTORIAL_REACH]   %s %s" % ["ok " if ok else "FAIL", message])


func pause(count: int = 3) -> void:
	for _i in count:
		await process_frame


func seconds(secs: float) -> void:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(secs * 1000.0):
		await process_frame


func run() -> void:
	_check_beat_counts()
	await pause()
	await _check_reachability_and_assist()
	await _check_assisted_drill()
	await _check_waiter_resize()
	await _check_missing_target_restart()
	await _leave_battle()
	print("[TUTORIAL_REACH] %s — real-input reachability, stuck-beat assist, beat counts" % (
		"PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)


func _leave_battle() -> void:
	# Never tear down a tray with its roll/settle coroutine still running.
	if current_scene != null and current_scene.get("hero_rolls") != null:
		var tray: Object = current_scene.get("dice_tray_3d")
		if tray != null and bool(tray.get("_is_rolling")):
			await _await_rolls(current_scene, 10.0)
		# hero_rolls is populated before the targeting coroutine's final frames.
		await pause(12)
	root.get_node("SceneManager").go_to_main_menu()
	await pause(15)


func _check_assisted_drill() -> void:
	await _leave_battle()
	_resize(Vector2i(342, 760))
	root.get_node("GameState").start_tutorial_run(true)
	root.get_node("SceneManager").go_to_battle()
	await pause(15)
	var scene: Node = current_scene
	var tut: Node = _controller(scene)
	tut.set("gated_assist_secs", 0.15)
	var modes: Dictionary = {}
	var deadline: int = Time.get_ticks_msec() + 65000
	while Time.get_ticks_msec() < deadline:
		var step: Dictionary = tut.call("_current")
		var mode: String = tut.call("_advance_mode")
		if bool(step.get("free", false)):
			check(not bool(tut.call("is_assist_offered")), "free play has no stale assist")
			break
		if mode == "tap":
			await _click(_coach(tut).get_global_rect().get_center())
		elif bool(tut.call("is_assist_offered")):
			check(not bool(tut.get("_assist_restart_offered")), "valid %s assist never needs a restart" % mode)
			modes[mode] = true
			var before: int = int(tut.get("_step"))
			# Resize while the offer is visible; it must remain actionable.
			_resize(Vector2i(560, 960) if before % 2 == 0 else Vector2i(342, 760))
			await pause(8)
			check(root.get_visible_rect().encloses(_coach(tut).get_global_rect()), "assist coach fits after resize (%s)" % mode)
			await _click(_coach(tut).get_global_rect().get_center())
			if mode == "inspected":
				check(bool(scene.call("is_tutorial_inspection_open")), "inspect assist leaves the real popup open")
				await seconds(0.4)
				check(int(tut.get("_step")) == before and not bool(tut.call("is_assist_offered")), "reading inspection pauses assistance and advancement")
				scene.call("_close_tutorial_inspection")
				await pause(5)
			elif mode == "nudged":
				var id: String = str(tut.call("_assist_state_id", "combat"))
				var state: Dictionary = scene.call("_find_state_by_id", scene.combat_manager.get_hero_states(), id)
				check(int(scene.call("_get_effective_roll_for_state", state, id)) == 11, "nudge assist really changes Strike's roll to 11")
		await pause(5)
	check(bool(tut.call("_current").get("free", false)), "all assisted guided turns reach free play")
	for mode in ["roll_pressed", "inspected", "assigned", "nudged", "turn_resolved"]:
		check(modes.has(mode), "exercised %s assistance through coach clicks" % mode)


func _check_missing_target_restart() -> void:
	await _leave_battle()
	var gs: Node = root.get_node("GameState")
	gs.start_tutorial_run(true)
	root.get_node("SceneManager").go_to_battle()
	await pause(15)
	var scene: Node = current_scene
	var tut: Node = _controller(scene)
	var steps: Array = tut.get("_steps")
	var index: int = _beat_with_advance(tut, "inspected")
	steps[index]["inspect_hero"] = "missing_hero"
	tut.call("_show_step", index)
	await pause(8)
	check(bool(tut.call("is_assist_offered")), "missing required target offers help immediately")
	await _click(_coach(tut).get_global_rect().get_center())
	await pause(5)
	check(bool(tut.get("_assist_restart_offered")), "impossible action offers an explicit restart")
	check(int(tut.get("_step")) == index, "impossible action never marks its lesson complete")
	await _click(_coach(tut).get_global_rect().get_center())
	await pause(18)
	check(current_scene != scene and int(_controller(current_scene).get("_step")) == 0, "restart returns to the first instruction")
	check(bool(gs.tutorial_continue_to_play), "restart preserves the first-run exit destination")


func _check_waiter_resize() -> void:
	await _leave_battle()
	root.get_node("GameState").start_tutorial_run(true)
	root.get_node("SceneManager").go_to_battle()
	await pause(15)
	var tut: Node = _controller(current_scene)
	var waiter: int = _beat_with_advance(tut, "rolled")
	tut.set("waiter_failsafe_secs", 0.25)
	tut.call("_show_step", waiter)
	await pause(4)
	var deadline: int = Time.get_ticks_msec() + 800
	while int(tut.get("_step")) == waiter and Time.get_ticks_msec() < deadline:
		_resize(Vector2i(342, 760))
		await pause(3)
		_resize(Vector2i(405, 900))
		await pause(3)
	check(int(tut.get("_step")) == waiter - 1, "continuous resize cannot postpone lost-roll recovery")


# ── 4. Beat counts ────────────────────────────────────────────────────────────
# Pinned deliberately: adding or removing a lesson must update these numbers,
# not discover the change in a playtest. "Visible" = the player sees a coach
# card; hide_coach beats are the board-plays-out waiters.
func _check_beat_counts() -> void:
	var core: Array = LESSONS.core()
	var practice: Array = LESSONS.practice()
	check(core.size() == 21, "core drill is 21 beats (got %d)" % core.size())
	check(_visible(core) == 18, "core drill shows 18 coach beats (got %d)" % _visible(core))
	check(practice.size() == 12, "practice drill is 12 beats (got %d)" % practice.size())
	check(_visible(practice) == 9, "practice drill shows 9 coach beats (got %d)" % _visible(practice))
	check(str((core[0] as Dictionary).get("title", "")) == "WELCOME", "the drill opens on WELCOME")
	var framing: Dictionary = core[1]
	check(str(framing.get("title", "")) == "THE OPERATION", "the framing beat is second, right after WELCOME")
	check(not framing.has("targets") and not framing.has("fullscreen"),
		"framing beat dims the whole screen with no spotlight hole")
	check(not framing.has("advance"), "framing beat advances on a tap, gates nothing")


func _visible(steps: Array) -> int:
	var count: int = 0
	for step_variant in steps:
		if not bool((step_variant as Dictionary).get("hide_coach", false)):
			count += 1
	return count


# ── 1-3, 5. Live drill through synthesized input ──────────────────────────────
func _check_reachability_and_assist() -> void:
	var gs = root.get_node("GameState")
	gs.start_tutorial_run(true)
	root.get_node("SceneManager").go_to_battle()
	await pause(12)
	var scene: Node = current_scene
	var tut: Node = _controller(scene)
	check(tut != null, "tutorial controller exists")
	if tut == null:
		return
	tut.set("gated_assist_secs", ASSIST_BUDGET_SECS)
	var roll_beat: int = _beat_with_advance(tut, "roll_pressed")
	check(roll_beat >= 0, "drill has a gated Roll beat")
	if roll_beat < 0:
		return

	# 5. Long-press tolerance is a DEVICE-pixel distance at any window scale.
	await _check_long_press(scene)

	# 2. A gated beat that receives only invalid input: offer, never advance.
	tut.call("_show_step", roll_beat)
	await pause(6)
	check(int(tut.get("_step")) == roll_beat, "parked on the gated Roll beat")
	check(not bool(tut.call("is_assist_offered")), "no assist offered while the budget runs")
	# Clicks on empty board space — the real input path, aimed at nothing.
	for _i in range(2):
		await _click(_empty_board_point(scene))
	await seconds(ASSIST_BUDGET_SECS + 0.6)
	check(bool(tut.call("is_assist_offered")), "stalled gated beat offers the assist")
	check(int(tut.get("_step")) == roll_beat, "the offer does NOT advance the beat by itself")
	check(not _has_rolls(scene), "nothing was performed while the offer sat unanswered")

	# 3. Taking the offer performs the beat's own action.
	var coach: Control = _coach(tut)
	check(coach != null and coach.visible, "the offer is on the visible coach card")
	if coach != null:
		await _click(coach.get_global_rect().get_center())
	await pause(10)
	check(int(tut.get("_step")) > roll_beat, "taking the offer advances past the gated beat")
	# The dice are physics and land a beat later, on their own event — so real
	# dice are the proof that the assist PERFORMED the beat instead of skipping
	# it. A skip would advance the step with the board untouched.
	check(await _await_rolls(scene, 10.0),
		"the assist performed the roll rather than skipping the beat")

	# 1. The scripted control is hittable by a real click — at the authored size,
	# a small canvas, and windows wider than the authored aspect (expand grows
	# the design width, so these are the layouts the Web build now gets).
	for size in [Vector2i(1080, 2400), Vector2i(342, 760), Vector2i(560, 960), Vector2i(1366, 768)]:
		await _check_roll_hittable(size)


func _check_long_press(scene: Node) -> void:
	var views: Variant = scene.get("hero_card_views")
	if not (views is Array) or (views as Array).is_empty():
		check(false, "hero cards exist for the long-press check")
		return
	var card: Object = ((views as Array)[0] as Dictionary).get("card", null)
	var long_press: Object = card.get("_portrait_long_press") if card != null else null
	if long_press == null:
		check(false, "the hero portrait carries a LongPressInput")
		return
	for size in [Vector2i(1080, 2400), Vector2i(342, 760), Vector2i(1366, 768)]:
		_resize(size)
		await pause(4)
		var view_scale: float = root.get_final_transform().get_scale().x
		var design_px: float = float(long_press.call("move_cancel_distance"))
		var device_px: float = design_px * view_scale
		check(absf(device_px - LONG_PRESS_DEVICE_PX) < 0.75,
			"long-press tolerance is %.0f device px at %dx%d (design %.1f px, scale %.4f)" % [
				LONG_PRESS_DEVICE_PX, size.x, size.y, design_px, view_scale])
	_resize(Vector2i(1080, 2400))
	await pause(4)


# A FRESH drill per size: the Roll button only exists in the await_roll phase,
# and the assist above already spent this battle's roll. Booting again also
# proves the layout is hittable from a cold start at that window size, which is
# what a player actually gets.
func _check_roll_hittable(size: Vector2i) -> void:
	# Let the previous check's roll LAND before tearing its battle down: the
	# dice settle on a deferred callback that reaches back into the scene, and
	# leaving mid-flight makes it fire against a detached node (see the
	# battle_scene._emit_tutorial note in the session report).
	if current_scene != null and current_scene.has_method("phase_name"):
		await _await_rolls(current_scene, 10.0)
		await pause(8)
	# Resize with NO battle scene alive. Resizing one and swapping it out in the
	# same breath leaves the outgoing scene's cards doing deferred relayout work
	# against a scene that is already gone.
	root.get_node("SceneManager").go_to_main_menu()
	await pause(10)
	_resize(size)
	await pause(6)
	root.get_node("GameState").start_tutorial_run(true)
	root.get_node("SceneManager").go_to_battle()
	await pause(14)
	var scene: Node = current_scene
	var tut: Node = _controller(scene)
	if tut == null:
		check(false, "tutorial controller exists at %dx%d" % [size.x, size.y])
		return
	tut.set("gated_assist_secs", 9999.0)  # the assist must not rescue this check
	var roll_beat: int = _beat_with_advance(tut, "roll_pressed")
	tut.call("_show_step", roll_beat)
	await pause(8)
	if int(tut.get("_step")) != roll_beat:
		check(false, "could not park on the Roll beat at %dx%d" % [size.x, size.y])
		return
	var button: Control = scene.get("roll_button") as Control
	if button == null or not button.is_visible_in_tree():
		check(false, "the Roll button is on screen at %dx%d" % [size.x, size.y])
		return
	var rect: Rect2 = button.get_global_rect()
	check(root.get_visible_rect().encloses(rect),
		"the Roll button is inside the visible viewport at %dx%d" % [size.x, size.y])
	await _click(rect.get_center())
	await pause(8)
	check(int(tut.get("_step")) != roll_beat,
		"a real click on the Roll button advances the beat at %dx%d" % [size.x, size.y])


# ── Input / helpers ───────────────────────────────────────────────────────────
# Positions are viewport (design) coordinates; push_input with in_local_coords
# keeps them in that space instead of re-applying the window transform, so the
# same call works at any content scale.
func _click(design_pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = design_pos
	press.global_position = design_pos
	root.push_input(press, true)
	await pause(2)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = design_pos
	release.global_position = design_pos
	root.push_input(release, true)
	await pause(2)


func _resize(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	root.size = size


# A point inside the dice tray band that carries no control — where a confused
# player's taps land.
func _empty_board_point(scene: Node) -> Vector2:
	var layout: Object = scene.get("_layout")
	if layout != null:
		var zone: Rect2 = layout.call("get_combat_zone_rect")
		if zone.size.x > 2.0 and zone.size.y > 2.0:
			return Vector2(zone.position.x + 24.0, zone.position.y + 24.0)
	return Vector2(40.0, root.get_visible_rect().size.y * 0.42)


func _controller(scene: Node) -> Node:
	for child in scene.get_children():
		if child is TutorialController:
			return child
	return null


func _coach(tut: Node) -> Control:
	var spot: Object = tut.get("_spot")
	return spot.get("_coach") as Control if spot != null else null


func _beat_with_advance(tut: Node, advance: String) -> int:
	var steps: Array = tut.get("_steps")
	for index in range(steps.size()):
		if str((steps[index] as Dictionary).get("advance", "tap")) == advance:
			return index
	return -1


func _has_rolls(scene: Node) -> bool:
	var rolls: Variant = scene.get("hero_rolls")
	return rolls is Dictionary and not (rolls as Dictionary).is_empty()


func _await_rolls(scene: Node, budget_secs: float) -> bool:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(budget_secs * 1000.0):
		if _has_rolls(scene):
			return true
		await process_frame
	return false
