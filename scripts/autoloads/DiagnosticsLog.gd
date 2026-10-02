# DiagnosticsLog — keeps the most recent engine errors, warnings and log lines
# in memory so a state code (StateCode) can carry them off a player's device.
#
# Registered FIRST in the autoload list, so it sees errors raised while the
# other autoloads boot. Uses Godot 4.5+'s Logger API (OS.add_logger), which
# receives push_error / push_warning / script errors / print in every build,
# release included. Nothing is written to disk and nothing is shown to the
# player: the buffers are only read when a dev exports a state code.
extends Node

var _logger: _RingLogger = null


func _init() -> void:
	# _init, not _ready: the logger is attached before any later autoload's
	# _ready can raise an error.
	_logger = _RingLogger.new()
	OS.add_logger(_logger)


func _exit_tree() -> void:
	if _logger != null:
		OS.remove_logger(_logger)


## Oldest first. Each entry: {t (ms since boot), kind, text, where}.
func recent_errors() -> Array:
	return _logger.snapshot(true)


## Oldest first. Each entry: {t (ms since boot), text}.
func recent_messages() -> Array:
	return _logger.snapshot(false)


## Logger callbacks can arrive on any thread, so both rings sit behind a mutex.
## Nothing in here may print: a print would re-enter _log_message.
class _RingLogger extends Logger:
	const MAX_ERRORS := 200
	const MAX_MESSAGES := 80
	const KINDS := ["error", "warning", "script", "shader"]
	var _mutex := Mutex.new()
	var _errors: Array = []
	var _messages: Array = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
		var text: String = rationale if rationale != "" else code
		var entry := {
			"t": Time.get_ticks_msec(),
			"kind": KINDS[error_type] if error_type >= 0 and error_type < KINDS.size() else str(error_type),
			"text": text,
			"where": "%s:%d %s" % [file, line, function],
		}
		_mutex.lock()
		_errors.append(entry)
		if _errors.size() > MAX_ERRORS:
			_errors.pop_front()
		_mutex.unlock()

	func _log_message(message: String, _error: bool) -> void:
		_mutex.lock()
		_messages.append({"t": Time.get_ticks_msec(), "text": message.strip_edges(false, true)})
		if _messages.size() > MAX_MESSAGES:
			_messages.pop_front()
		_mutex.unlock()

	func snapshot(errors: bool) -> Array:
		_mutex.lock()
		var copy: Array = (_errors if errors else _messages).duplicate(true)
		_mutex.unlock()
		return copy
