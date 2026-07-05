# SimTelemetry — JSONL event emitter for the balance sim (Package B.1).
# Schema: scripts/sim/telemetry_schema.md. Every line carries run_id / seed /
# t (monotonic per run). Deterministic by construction: field order is
# insertion order and every value derives from the seeded run — never emit
# wall-clock time or unseeded randomness through this.
class_name SimTelemetry
extends RefCounted

const SCHEMA_VERSION := 1

var run_id: String = ""
var run_seed: int = 0

var _out: FileAccess = null
var _t: int = 0


func open_file(path: String) -> bool:
	var dir: String = path.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_out = FileAccess.open(path, FileAccess.WRITE)
	_t = 0
	return _out != null


func is_open() -> bool:
	return _out != null


func emit(obj: Dictionary) -> void:
	if _out == null:
		return
	obj["run_id"] = run_id
	obj["seed"] = run_seed
	obj["t"] = _t
	_t += 1
	_out.store_line(JSON.stringify(obj))


func close_file() -> void:
	if _out != null:
		_out.flush()
		_out.close()
		_out = null
