# Loopback-only transport, consent, persistence and real lifecycle regression.
extends SceneTree
var failures: Array[String] = []
var deliveries: Array = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func run() -> void:
	var c = root.get_node("Telemetry")
	var gs = root.get_node("GameState")
	var sm = root.get_node("SaveManager")
	var dm = root.get_node("DataManager")
	check(not c._enabled and c._request == null and c._install_id == "", "debug builds are inert without flag")
	check(not sm.data.settings.has("telemetry_install_id"), "debug does not create install ID")
	seed(98765)
	var expected := randi()
	seed(98765)
	var id: String = c.new_id()
	check(randi() == expected and c.valid_id(id) and id[14] == "4", "UUID v4 does not consume gameplay RNG")
	check(not c.valid_id("name@example.com"), "identity rejects personal text")
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].begins_with("http://127.0.0.1:"):
		quit(1)
		return
	c._endpoint = args[0]
	c._allowed = true
	c._enabled = true
	c._load_state()
	c._start_transport()
	c._connect_lifecycle()
	c._retry_at = 1e15 # Keep lifecycle fixtures offline until the transport cases.
	gs.start_run(["combat", "engineer", "medic"], "facility", 13579)
	gs.advance_to_next_battle()
	var first: Dictionary = c._queue.front().duplicate(true)
	check(first.event_name == "run_start" and first.operation == "facility", "run start captures operation")
	check(first.payload.squad == ["combat", "engineer", "medic"], "run start captures squad")
	check(first.payload.install_id == c._install_id and first.payload.timestamp.ends_with("Z"), "install ID and UTC timestamp")
	var project_version := str(ProjectSettings.get_setting("application/config/version", ""))
	check(project_version != "" and first.game_version == project_version, "demo version included")
	gs.battle_entry_counted = true
	sm.checkpoint_run("battle")
	check(sm.resume_run() == "battle", "real saved run resumes")
	check(c._context.run_id == first.run_id, "run ID survives resume")
	var alive := [{"unit": dm.get_unit("combat"), "dead": false}, {"unit": dm.get_unit("medic"), "dead": true}]
	c.battle_finished("victory", 3, alive)
	c.battle_finished("victory", 3, alive)
	check(c._queue.size() == 2 and c._queue.back().payload.heroes_alive == ["combat"], "one battle event, correct survivors")
	gs.prepare_battle_rewards()
	var offered: Array = gs.pending_reward_item_ids.duplicate()
	check(gs.claim_reward(offered[0], "combat"), "real reward accepted")
	check(c._queue.back().event_name == "reward_pick" and c._queue.back().payload.offered_ids == offered, "reward snapshots offers before clear")
	gs.pending_evolution_unit_id = "combat"
	var paths: Array = gs.get_pending_evolution_paths()
	gs.apply_pending_evolution(paths[0].name)
	check(c._queue.back().payload.kind == "evolution" and c._queue.back().payload.picked_id == paths[0].id, "evolution reports IDs")
	gs.pending_evolution_unit_id = "combat"
	var traits: Array = gs.get_pending_trait_choices()
	gs.apply_pending_trait(traits[0].id)
	check(c._queue.back().payload.kind == "trait" and c._queue.back().payload.offered_ids.size() == 2, "trait choice captured")
	var before: Dictionary = gs.to_save_dict()
	c._persist()
	var queued: Array = c._queue.duplicate(true)
	c._queue.clear()
	c._context.clear()
	c._load_state()
	check(c._queue == queued and c._context.run_id == first.run_id, "profile queue and context reload")
	check(gs.to_save_dict() == before, "telemetry leaves gameplay state unchanged")
	c._process(5.0)
	var played: float = c._context.time_played
	c._focused = false
	c._process(100.0)
	check(c._context.time_played == played, "background time excluded")
	c._focused = true
	gs.finish_run("victory")
	gs.reset_run()
	check(c._queue.back().payload.result == "cleared", "clear is not also abandonment")
	check(c._queue.back().payload.time_played >= 5 and c._queue.back().payload.time_played < 100, "active playtime survives snapshot")
	gs.start_run(["combat", "engineer", "medic"], "hive", 24680)
	gs.reset_run()
	check(c._queue.back().payload.result == "abandoned", "explicit reset records abandoned")
	gs.start_tutorial_run()
	check(c._queue.back().event_name == "tutorial" and c._queue.back().payload.action == "started", "tutorial started")
	c.tutorial("completed")
	gs.reset_run()
	c.tutorial("skipped")
	check(c._queue.back().payload.action == "skipped", "tutorial skipped")
	var help_script = load("res://scripts/ui/help_menu.gd")
	help_script.open(root)
	var menu = help_script._active
	var row = menu.find_child("TelemetryToggleRow", true, false)
	var toggle: Button = row.find_children("*", "Button", true, false)[0]
	check(toggle.button_pressed, "Settings sharing toggle defaults ON")
	toggle.button_pressed = false
	check(c._queue.is_empty() and sm.get_setting("telemetry_state").is_empty() and not c._busy, "opt-out clears persistent and memory queues")
	c._enqueue("disabled", {})
	check(c._queue.is_empty(), "nothing queues while opted out")
	toggle.button_pressed = true
	help_script.dismiss()
	check(c._install_id == first.payload.install_id, "opt-in retains one install ID")
	c._retry_at = 1e15
	for i in 140: c._enqueue("bounded", {})
	check(c._queue.size() == c.MAX_PENDING, "offline queue bounded")
	c._queue.clear()
	c._enqueue("oversize", {"text": "x".repeat(9000)})
	check(c._queue.is_empty(), "event payload bounded")
	c._request.timeout = 1.0
	c.delivery_finished.connect(func(name, accepted, status): deliveries.append([name, accepted, status]))
	for kind in ["server_error", "bad_json", "timeout"]:
		c._enqueue(kind, {})
		c._retry_at = 0.0
		var count := deliveries.size()
		c.flush()
		while deliveries.size() == count: await process_frame
		check(not deliveries.back()[1] and c._queue.size() == 1, kind + " kept for retry")
		c._persist()
		c._queue.clear()
		c._load_state()
		c._retry_at = 0.0
		count = deliveries.size()
		c.flush()
		while deliveries.size() == count: await process_frame
		check(deliveries.back()[1] and c._queue.is_empty(), kind + " retry succeeds after profile reload")
	c._retry_at = 0.0
	c._enqueue("cancelled", {})
	c.flush()
	sm.set_setting("telemetry_enabled", false)
	await create_timer(0.1).timeout
	check(c._queue.is_empty() and not c._busy and sm.get_setting("telemetry_state").is_empty(), "opt-out cancels in-flight delivery")
	sm.clear_run_save()
	for failure in failures: print("[TELEMETRY] FAIL ", failure)
	print("[TELEMETRY] PASS" if failures.is_empty() else "[TELEMETRY] FAILED")
	quit(0 if failures.is_empty() else 1)
