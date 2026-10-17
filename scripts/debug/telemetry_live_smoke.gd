# Manual, synthetic, local-web production probe. Never run by verify_gate.
# Export Web release, then give the loader args documented in TELEMETRY.md.
extends Node

var accepted_count := 0
var label: Label
var client: Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not OS.has_feature("web") or not OS.get_cmdline_user_args().has("--send-telemetry-smoke"):
		get_tree().quit(1)
		return
	var host := str(JavaScriptBridge.eval("location.hostname"))
	if host not in ["localhost", "127.0.0.1"]:
		get_tree().quit(1)
		return
	client = get_tree().root.get_node("Telemetry")
	# The explicit probe flag selects the disposable dev profile, never a player save.
	client._clear()
	client._install_id = client.new_id()
	client._enabled = true
	client._start_transport()
	client._retry_at = 1e15 # Mark the complete fixture before any deferred flush.
	client.delivery_finished.connect(_finished)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 32)
	add_child(label)
	_report("Sending")
	var gs = get_node("/root/GameState")
	var dm = get_node("/root/DataManager")
	gs.start_run(["combat", "engineer", "medic"], "facility", 424242)
	gs.advance_to_next_battle()
	var heroes: Array = []
	for id: String in gs.selected_units:
		heroes.append({"unit": dm.get_unit(id), "dead": false})
	client.battle_finished("victory", 3, heroes)
	gs.prepare_battle_rewards()
	gs.claim_reward(gs.pending_reward_item_ids[0], "combat")
	gs.reset_run()
	gs.start_tutorial_run()
	client.tutorial("completed")
	client.tutorial("skipped")
	for event: Dictionary in client._queue:
		event.payload["source"] = "v04_local_web_smoke"
	client._retry_at = 0.0
	client.flush()

func _finished(_name: String, accepted: bool, status: int) -> void:
	if accepted:
		accepted_count += 1
	_report("PASS" if accepted_count == 7 else ("Sending" if accepted else "Retrying HTTP %d" % status))
	if accepted_count == 7:
		client._enabled = false
		client._clear()

func _report(status: String) -> void:
	var message := "WEB TELEMETRY %s | accepted %d/7 | install %s" % [status, accepted_count, client._install_id]
	label.text = message
	JavaScriptBridge.eval("document.title = " + JSON.stringify(message))
	JavaScriptBridge.eval("document.getElementById('telemetry-result')?.remove(); var p=document.createElement('p'); p.id='telemetry-result'; p.textContent=" + JSON.stringify(message) + "; p.style='position:fixed;top:0;left:0;z-index:9999;background:white;color:black;padding:12px'; document.body.appendChild(p);")
