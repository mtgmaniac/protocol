extends SceneTree

var errors: Array[String] = []
var frames: int = 0
var observed_core_rounds: int = 0
var item_used: bool = false
var burn_ticked: bool = false
var reroll_notices: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		errors.append(message)
		push_error(message)

func pause(count: int = 3) -> void:
	for _i in count:
		await process_frame

func run() -> void:
	await pause()
	var gs = root.get_node("GameState")
	var sm = root.get_node("SceneManager")
	gs.start_tutorial_run(true)
	sm.go_to_battle()
	await pause(12)
	var first_tut: Node = controller(current_scene)
	# Lost-roll recovery returns to the roll instruction; free play must not
	# inherit the hidden-waiter's input lock or its timeout. Beat 4 is the
	# hide_coach waiter and beat 3 the Roll instruction before it — both moved
	# up one when the THE OPERATION framing beat was added
	# (2026-09-20; it sits second, after WELCOME). Pinned, not derived: if a lesson edit moves them again this
	# should fail and be re-read, not silently follow.
	first_tut.call("_recover_stalled_waiter", 4)
	check(first_tut.get("_step") == 3, "Missing-roll recovery restores the roll instruction")
	first_tut.call("_show_step", 0)
	await drive_battle(false)
	check(observed_core_rounds >= 3, "Core battle must reach independent round three")
	await pause(12)
	check(current_scene.has_method("_claim_reward"), "Core victory routes to the real reward picker")
	if not current_scene.has_method("_claim_reward"):
		finish_test()
		return
	check(gs.pending_reward_item_ids.size() == 3, "Three real consumables offered")
	current_scene.call("_claim_reward", root.get_node("DataManager").get_item("scrap_plate"), "")
	await pause()
	check(gs.consumables.has("scrap_plate"), "Chosen reward enters inventory")
	var prompt: Node = find_prompt(current_scene)
	check(prompt != null, "Reward offers optional continuation")
	if prompt == null:
		finish_test()
		return
	prompt.emit_signal("chosen", 0)
	await pause(15)
	check(gs.current_battle == 2 and gs.selected_units.has("pulse") and gs.selected_units.has("combat") and not gs.selected_units.has("engineer"), "Practice uses Pulse and advances encounter")
	check(current_scene.get("enemy_units").size() == 2, "Practice has two real enemies")
	await drive_battle(true)
	await pause(15)
	check(not gs.tutorial_mode and gs.consumables.is_empty(), "Finish clears training state and rewards")
	check(item_used, "Practice can use the chosen real item")
	check(reroll_notices == 1, "Affordable reroll explained exactly once")
	check(burn_ticked, "Practice shows a real delayed Burn damage event")
	check(root.get_node("SaveManager").is_tutorial_done(), "Completion persists")
	# The same choice can exit without loading encounter two.
	gs.start_tutorial_run(true)
	sm.go_to_reward_screen()
	await pause(12)
	preload("res://scripts/ui/training_flow.gd").reward_claimed(current_scene)
	await pause()
	prompt = find_prompt(current_scene)
	if prompt != null:
		prompt.emit_signal("chosen", 1)
	await pause(12)
	check(not gs.tutorial_mode, "Start your run exits optional training")
	var save = root.get_node("SaveManager")
	save.dev_reset_primers()
	preload("res://scripts/ui/training_flow.gd").explain_first_item(current_scene)
	await pause()
	prompt = find_prompt(current_scene)
	check(prompt != null and not save.is_primer_seen("item_acquired"), "First real item explanation waits for acknowledgement")
	if prompt != null:
		prompt.emit_signal("chosen", 0)
	await pause()
	check(save.is_primer_seen("item_acquired"), "Acknowledged item lesson persists")
	preload("res://scripts/ui/training_flow.gd").explain_first_item(current_scene)
	await pause()
	check(find_prompt(current_scene) == null, "Item explanation does not repeat")
	finish_test()

func finish_test() -> void:
	print("[TUTORIAL_SMOKE] %s — guided turns, free third round, rewards, optional practice, item use and exit" % ("PASS" if errors.is_empty() else "FAIL"))
	quit(0 if errors.is_empty() else 1)

func find_prompt(scene: Node) -> Node:
	for child in scene.get_children():
		if child.has_signal("chosen"):
			return child
	return null

func controller(scene: Node) -> Node:
	for child in scene.get_children():
		if child is TutorialController:
			return child
	return null

func state_id(scene: Node, unit_id: String) -> String:
	for state in scene.combat_manager.get_hero_states():
		if str(state.unit.id) == unit_id:
			return str(state.id)
	return ""

func assign(scene: Node, uid: String, friendly: String = "") -> void:
	scene.call("_on_hero_card_pressed", state_id(scene, uid))
	await pause()
	var legal: Array = scene.get("legal_target_ids")
	if legal.is_empty():
		return
	var side: String = scene.get("legal_target_side")
	var target: String = state_id(scene, friendly) if friendly != "" else str(legal[-1])
	if not legal.has(target):
		target = str(legal[0])
	scene.call("_on_enemy_card_pressed" if side == "enemy" else "_on_hero_card_pressed", target)
	await pause()

# The Burn lesson's proof. Pulse's round-one burn ticks at the END of the next
# round, and only if the burned enemy is still alive and nobody detonated the
# burn first. Free-round dice are live physics, so that used to be luck: the
# check failed about one run in eight after the 2026-10-08 roll windows. Until
# the tick has been seen, each hero's die is set to its kit's gentlest roll
# (least damage, never a detonate), read from the kit and not a fixed face.
# Enemy dice stay live, and so does every round after the tick. The request
# survives because a free tutorial round has no plan of its own to set
# (battle_scene._tutorial_rig_values is empty there).
func _hold_fire(scene: Node) -> void:
	var rig: Dictionary = {}
	for state in scene.get("combat_manager").get_hero_states():
		if bool(state.get("dead", false)):
			continue
		var gentlest: int = 0
		var least: int = 1 << 30
		for roll in range(1, 21):
			var raw: Dictionary = scene.get("dice_manager").get_ability_for_roll(state["unit"], roll).get("raw", {})
			if bool(raw.get("detonate", false)):
				continue
			var dmg: int = int(raw.get("dmg", 0)) * (2 if bool(raw.get("blastAll", false)) else 1)
			if dmg < least:
				least = dmg
				gentlest = roll
		if gentlest > 0:
			rig["hero:%s" % str(state["id"])] = gentlest
	scene.get("dice_tray_3d").set_rigged_results(rig)


func drive_battle(practice: bool) -> void:
	var scene: Node = current_scene
	if practice:
		scene.tutorial_event.connect(func(event: StringName, payload: Dictionary):
			if event == &"turn_resolved":
				for entry in payload.get("events", []):
					if str(entry.get("ability", "")) == "Burn":
						burn_ticked = true
		)
	var tut: Node = controller(scene)
	check(tut != null, "Tutorial controller exists")
	if tut == null:
		return
	var deadline: int = Time.get_ticks_msec() + 70000
	while is_instance_valid(scene) and current_scene == scene and Time.get_ticks_msec() < deadline:
		var step: Dictionary = tut.call("_current")
		var mode: String = tut.call("_advance_mode")
		var phase: String = scene.call("phase_name", scene.get("turn_phase"))
		if not practice:
			observed_core_rounds = maxi(observed_core_rounds, int(scene.get("_tutorial_turn")))
		if mode == "tap" or mode == "tap_finish":
			if step.get("title", "") == "REROLL":
				reroll_notices += 1
				check(int(scene.get("protocol_points")) >= 2, "Reroll hint waits for affordability")
			if step.get("title", "") == "USE AN ITEM":
				check(step.get("targets") == ["item"], "Inventory lesson highlights only its button")
			tut.call("_next")
		elif bool(step.get("free", false)):
			check(tut.call("allows_action", "nudge_pick", {"hero": "engineer"}), "Free play permits Engineer Nudge")
			if phase == "await_roll" and not scene.get("roll_button").disabled:
				if practice and not burn_ticked and bool(tut.call("_has_living_burned_enemy")):
					_hold_fire(scene)
				scene.call("_on_roll_button_pressed")
			elif (phase == "targeting" or phase == "ready_to_end") and not bool(scene.get("_is_resolving_turn")):
				if practice and reroll_notices > 0 and not item_used and int(scene.get("protocol_points")) >= 1:
					var protocol = scene.get("_protocol")
					protocol.call("_on_item_button_pressed", root.get_node("DataManager").get_item("scrap_plate"))
					protocol.call("handle_hero_card_pressed", state_id(scene, "medic"))
					item_used = not root.get_node("GameState").consumables.has("scrap_plate")
					await pause()
					continue
				# Exercise a different order from the guided combat→engineer→medic.
				var pending: Array = scene.get("pending_manual_target_ids")
				if not pending.is_empty():
					for uid in (["combat", "medic", "pulse"] if practice else ["engineer", "medic", "combat"]):
						if pending.has(state_id(scene, uid)):
							await assign(scene, uid, "combat" if uid == "medic" else "")
							break
				elif phase == "ready_to_end" and not scene.get("roll_button").disabled:
					scene.call("_on_roll_button_pressed")
		elif mode == "roll_pressed":
			scene.call("_on_roll_button_pressed")
		elif mode == "inspected":
			# Wrong-unit input must redirect to the visible die and portrait.
			var expected: Dictionary = tut.call("_expected_target")
			var rects: Array = scene.call("_tutorial_redirect_rects", expected)
			check(rects.size() == 2, "Inspect redirect has a die and portrait")
			if rects.size() == 2:
				check(rects[0].rect == tut.call("_hero_die_rect_for_unit", "combat"), "Inspect redirect excludes the pip hit area")
				check(rects[1].rect == tut.call("_hero_card_rect_for_unit", "combat") and rects[1].primary, "Inspect redirect emphasizes the portrait")
			scene.set("_tutorial_redirect_msec", 0)
			scene.call("_on_hero_card_pressed", state_id(scene, "engineer"))
			check(tut.call("_advance_mode") == "inspected", "Wrong unit does not skip inspection")
			var layer = scene.get("_tutorial_redirect_layer")
			check(layer != null and layer.get_child_count() >= 2, "Wrong input emits visible redirect pulses")
			var views: Array = scene.get("hero_card_views")
			scene.call("_on_unit_detail_requested", views[0].card)
			await pause()
			scene.call("_close_tutorial_inspection")
		elif mode == "assigned":
			await assign(scene, str(step.hero), str(step.get("target_hero", "")))
		elif mode == "nudged":
			var protocol = scene.get("_protocol")
			protocol.call("_on_nudge_button_pressed")
			protocol.call("handle_hero_card_pressed", state_id(scene, "combat"))
		elif mode == "turn_resolved" and phase == "ready_to_end":
			scene.call("_on_roll_button_pressed")
		await pause()
	check(current_scene != scene, "Encounter completed without a stalled lesson")
