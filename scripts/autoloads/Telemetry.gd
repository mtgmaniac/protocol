# Anonymous, consent-gated gameplay events. The Vercel handler owns DB access.
extends Node

signal delivery_finished(event_name: String, accepted: bool, http_status: int)

const ENDPOINT := "https://overload-telemetry.vercel.app/api/telemetry"
const SETTING := "telemetry_enabled"
const STATE_SETTING := "telemetry_state"
const MAX_PENDING := 128
const MAX_EVENT_BYTES := 8192
const BATCH_SIZE := 8
const REQUEST_TIMEOUT := 5.0
const RETRY_SECONDS := 60.0

var _allowed := false
var _enabled := false
var _install_id := ""
var _queue: Array = []
var _context: Dictionary = {}
var _run_open := false
var _ended_battle := -1
var _request: HTTPRequest
var _busy := false
var _remaining := 0
var _retry_at := 0.0
var _persist_queued := false
var _endpoint := ENDPOINT
var _focused := true
## Developer mode was turned on this session: nothing is sent until relaunch.
var _dev_silenced := false
## The events this session enqueued (the same Dictionaries the queue holds).
var _session_events: Array = []


func _ready() -> void:
	# Even a normal editor play session is excluded. The opt-in flag is explicit.
	_allowed = ProjectSettings.get_setting("overload/telemetry/enabled", true) and (not OS.is_debug_build() or "--telemetry-debug" in OS.get_cmdline_user_args())
	var save := get_node("/root/SaveManager")
	save.setting_changed.connect(_on_setting_changed)
	if not bool(save.get_setting(SETTING, true)):
		_clear()
	if Engine.is_editor_hint() or not _allowed:
		return
	_connect_lifecycle()
	var timer := Timer.new()
	timer.wait_time = 30.0
	timer.autostart = true
	timer.timeout.connect(_checkpoint)
	add_child(timer)
	_enabled = bool(save.get_setting(SETTING, true))
	if _enabled:
		_load_state()
		_start_transport()
		flush.call_deferred()


func _connect_lifecycle() -> void:
	var gs := get_node("/root/GameState")
	gs.run_started.connect(_on_run_started)
	gs.run_finished.connect(_on_run_finished)
	gs.run_resetting.connect(_on_run_resetting)
	gs.reward_picked.connect(reward_picked)
	get_node("/root/SaveManager").run_resumed.connect(_on_run_resumed)


func _process(delta: float) -> void:
	if _enabled and _run_open and _focused and not get_node("/root/GameState").selected_units.is_empty():
		_context["time_played"] = float(_context.get("time_played", 0.0)) + delta


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true


func _checkpoint() -> void:
	if _enabled:
		_defer_persist()
		flush()


static func new_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]


static func valid_id(value: String) -> bool:
	var parts := value.split("-")
	return parts.size() == 5 and parts[0].length() == 8 and parts[1].length() == 4 and parts[2].length() == 4 and parts[3].length() == 4 and parts[4].length() == 12 and value.replace("-", "").is_valid_hex_number()


func _load_state() -> void:
	var save := get_node("/root/SaveManager")
	_install_id = str(save.get_setting("telemetry_install_id", ""))
	if not valid_id(_install_id):
		_install_id = new_id()
		save.set_setting("telemetry_install_id", _install_id)
	_queue.clear()
	_context.clear()
	var state: Variant = save.get_setting(STATE_SETTING, {})
	if state is Dictionary:
		if state.get("context") is Dictionary:
			_context = state.context.duplicate(true)
		_run_open = bool(state.get("run_open", false))
		_ended_battle = int(state.get("ended_battle", -1))
		var saved_queue: Array = state.queue if state.get("queue") is Array else []
		for event: Variant in saved_queue:
			if event is Dictionary and str(event.get("player_id", "")) == _install_id and JSON.stringify(event).to_utf8_buffer().size() <= MAX_EVENT_BYTES:
				_queue.append(event.duplicate(true))
			if _queue.size() == MAX_PENDING:
				break


func _start_transport() -> void:
	if _request != null:
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	_request = HTTPRequest.new()
	_request.timeout = REQUEST_TIMEOUT
	_request.body_size_limit = MAX_EVENT_BYTES
	_request.max_redirects = 0
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)


func _on_setting_changed(key: String, value: Variant) -> void:
	if key != SETTING:
		return
	_enabled = bool(value) and _allowed and not _dev_silenced
	if not _enabled:
		_clear()
	else:
		_load_state()
		_start_transport()
		# Enabling mid-run observes future events; it never invents a run_start.
		if not get_node("/root/GameState").selected_units.is_empty():
			_snapshot()
			_run_open = true


## Developer mode turned on (PersistentHeader.set_dev_mode, Kev DEMO v0.51):
## analytics stop for the rest of this session. An in-flight request is
## cancelled, every event this session queued is dropped, and nothing more is
## queued or sent until relaunch. Events left over from earlier sessions stay
## saved for a later session; the opt-out setting is not touched.
func silence_for_dev_session() -> void:
	if _dev_silenced:
		return
	_dev_silenced = true
	var was_enabled := _enabled
	_enabled = false
	if _request != null:
		_request.cancel_request()
	_busy = false
	_remaining = 0
	_queue = _queue.filter(func(event: Variant) -> bool:
		return not _session_events.any(func(own: Variant) -> bool: return is_same(own, event)))
	_session_events.clear()
	if was_enabled:
		get_node("/root/SaveManager").set_setting(STATE_SETTING, {"queue": _queue.duplicate(true),
			"context": _context.duplicate(true), "run_open": _run_open, "ended_battle": _ended_battle})


func is_dev_silenced() -> bool:
	return _dev_silenced


func _clear() -> void:
	if _request != null:
		_request.cancel_request()
	_busy = false
	_remaining = 0
	_queue.clear()
	_context.clear()
	_run_open = false
	_ended_battle = -1
	get_node("/root/SaveManager").set_setting(STATE_SETTING, {})


func _snapshot() -> void:
	var gs := get_node("/root/GameState")
	if gs.selected_units.is_empty():
		return # Title abandonment uses the last saved context, even after relaunch.
	var run_id := ("%s:%s:%s:%s" % [_install_id, gs.run_seed, gs.run_start_unix, gs.selected_operation_id]).sha256_text()
	var played := float(_context.get("time_played", 0.0)) if _context.get("run_id") == run_id else 0.0
	_context = {
		"run_id": run_id, "time_played": played,
		"operation": str(gs.selected_operation_id), "battle": int(gs.current_battle),
		"start_unix": int(gs.run_start_unix), "relics": gs.relics.duplicate(),
		"tutorial": bool(gs.tutorial_mode),
	}


func _on_run_started() -> void:
	if not _enabled:
		return
	_snapshot()
	_run_open = true
	_ended_battle = -1
	var gs := get_node("/root/GameState")
	if not gs.tutorial_mode:
		_enqueue("run_start", {"squad": gs.selected_units.duplicate(), "levels": gs.unit_levels.duplicate()})
	_defer_persist()


func _on_run_resumed(_screen: String) -> void:
	if _enabled:
		_snapshot()
		_run_open = true
		_defer_persist()


func _on_run_finished(result: String) -> void:
	if not _enabled or not _run_open:
		return
	_snapshot()
	if not bool(_context.get("tutorial", false)):
		_enqueue("run_end", {"result": {"victory": "cleared", "defeat": "wiped"}.get(result, result),
			"battle_reached": _context.get("battle", 0), "relics": _context.get("relics", []).duplicate(),
			"time_played": int(_context.get("time_played", 0.0))})
	_run_open = false
	_defer_persist()
	flush.call_deferred()


func _on_run_resetting() -> void:
	_on_run_finished("abandoned")


func battle_finished(result: String, turns: int, hero_states: Array = []) -> void:
	if not _enabled or not _run_open:
		return
	_snapshot()
	var battle := int(_context.get("battle", 0))
	if _ended_battle == battle:
		return
	_ended_battle = battle
	var alive: Array = []
	for state: Dictionary in hero_states:
		if not bool(state.get("dead", false)):
			alive.append(str(state["unit"].id))
	_enqueue("battle_end", {"result": "win" if result == "victory" else "loss", "turns": turns, "heroes_alive": alive})
	flush.call_deferred()


func reward_picked(kind: String, offered: Array, picked: String) -> void:
	if not _enabled:
		return
	_snapshot()
	_enqueue("reward_pick", {"kind": kind, "offered_ids": offered.duplicate(), "picked_id": picked})


func tutorial(action: String) -> void:
	if not _enabled:
		return
	if action == "skipped" and not bool(_context.get("tutorial", false)):
		_context = {"run_id": new_id(), "tutorial": true}
	else:
		_snapshot()
	_enqueue("tutorial", {"action": action})
	if action != "started":
		_run_open = false
	flush.call_deferred()


func _enqueue(event_name: String, payload: Dictionary) -> void:
	if not _enabled:
		return
	var details := payload.duplicate(true)
	details["install_id"] = _install_id
	details["timestamp"] = Time.get_datetime_string_from_system(true) + "Z"
	details["tutorial"] = bool(_context.get("tutorial", false))
	details["schema_version"] = 2
	# Existing Vercel schema: player_id is the install UUID; session_id is the
	# same anonymous UUID (required legacy column, no extra tracked identity).
	var event := {"event_name": event_name, "player_id": _install_id, "session_id": _install_id,
		"game_version": str(ProjectSettings.get_setting("application/config/version")),
		"run_id": _context.get("run_id", null), "operation": _context.get("operation", null),
		"battle_index": _context.get("battle", null), "round_index": payload.get("turns", null), "payload": details}
	if JSON.stringify(event).to_utf8_buffer().size() > MAX_EVENT_BYTES:
		return
	if _queue.size() >= MAX_PENDING:
		_queue.remove_at(1 if _busy else 0) # Never evict the in-flight head.
	_queue.append(event)
	_session_events.append(event)
	if _session_events.size() > MAX_PENDING:
		# Forget the ones already sent or evicted: only queued events matter.
		_session_events = _session_events.filter(func(own: Variant) -> bool:
			return _queue.any(func(queued: Variant) -> bool: return is_same(queued, own)))
	_defer_persist()


func _defer_persist() -> void:
	if not _persist_queued:
		_persist_queued = true
		_persist.call_deferred()


func _persist() -> void:
	_persist_queued = false
	if not _enabled:
		return
	get_node("/root/SaveManager").set_setting(STATE_SETTING, {"queue": _queue.duplicate(true),
		"context": _context.duplicate(true), "run_open": _run_open, "ended_battle": _ended_battle})


func flush() -> void:
	if not _enabled or _busy or _queue.is_empty() or Time.get_ticks_msec() < _retry_at:
		return
	_remaining = BATCH_SIZE
	_drain()


func _drain() -> void:
	if not _enabled or _busy or _queue.is_empty() or _remaining <= 0:
		return
	_busy = true
	_remaining -= 1
	var error := _request.request(_endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(_queue.front()))
	if error != OK:
		_complete(false, 0)


func _on_request_completed(result: int, status: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var parser := JSON.new()
	var reply: Variant = parser.data if parser.parse(body.get_string_from_utf8()) == OK else null
	_complete(result == HTTPRequest.RESULT_SUCCESS and status == 200 and reply is Dictionary and reply.get("ok") == true, status)


func _complete(accepted: bool, status: int) -> void:
	_busy = false
	if not _enabled or _queue.is_empty():
		return
	var event_name: String = str(_queue.front().get("event_name", ""))
	if accepted:
		_queue.pop_front()
		_retry_at = 0.0
		_defer_persist()
		_drain.call_deferred()
	else:
		_remaining = 0
		_retry_at = Time.get_ticks_msec() + RETRY_SECONDS * 1000.0
	delivery_finished.emit(event_name, accepted, status)
