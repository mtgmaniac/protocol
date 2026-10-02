# StateCode — the dev "copy state code" tool (playtest 2026-10-02, Kev).
#
# When the game breaks on a phone, a dev exports ONE line of text that carries
# everything needed to reproduce it on a desktop:
#   OPSTATE1:<base64 of gzip(JSON payload)>:<first 8 hex of sha256(base64)>
# The payload holds the build, the platform, the RAW run save exactly as stored
# (read without loading it, so a run that freezes on CONTINUE can still be
# exported), the profile, the current scene and live battle state, the RNG
# positions and the last errors / warnings DiagnosticsLog kept in memory.
#
# Import is debug-builds only and launch-argument only:
#   godot --path . -- --load-state=<file holding the code>
# SaveManager calls import_from_launch_args() before it loads anything. The
# argument also flips DevContext isolation, so the code lands in the dev_*
# files and can never overwrite the real profile; CONTINUE then resumes it
# through the normal path.
#
# This tool reads and writes the existing save files as they are. It adds
# nothing to the run save format (no RUN_SAVE_VERSION change).
#
# Decode outside Godot: python scripts/debug/state_code_decode.py <file>.
# Gate: `state code` (scripts/checks/state_code_gate.py).
#
# Autoloads are reached through the tree, never by bare identifier, because the
# gate's -s test preloads this file (TRUTH "Autoload convention for -s tests").
class_name StateCode
extends RefCounted

const PREFIX := "OPSTATE1"
const FORMAT := 1
const LOAD_ARG := "--load-state="
## Debug-build seam for the gate's deliberate breaks (never set by the game):
## drop_run, no_checksum, import_noop.
const BREAK_ARG := "--state-code-break="
const MAX_PAYLOAD_BYTES := 32 * 1024 * 1024


static func _root() -> Window:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root if tree != null else null


static func _node(name: String) -> Node:
	var root: Window = _root()
	return root.get_node_or_null(name) if root != null else null


static func _break_mode() -> String:
	if not OS.is_debug_build():
		return ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(BREAK_ARG):
			return arg.trim_prefix(BREAK_ARG)
	return ""


# ── Export ────────────────────────────────────────────────────────────────────

## Everything the code carries, as a JSON-safe Dictionary.
static func build_payload() -> Dictionary:
	var sm: Node = _node("SaveManager")
	var run_path: String = str(sm.get("_run_save_path")) if sm != null else ""
	var payload: Dictionary = {
		"format": FORMAT,
		"build_id": str(ProjectSettings.get_setting("application/config/version", "")),
		"engine": str(Engine.get_version_info().get("string", "")),
		"debug_build": OS.is_debug_build(),
		"created_at": Time.get_datetime_string_from_system(true, true),
		"platform": OS.get_name(),
		"web": OS.has_feature("web"),
		"user_agent": _user_agent(),
		"scene": _scene_path(),
		# The run save exactly as stored: read only, never loaded, never healed.
		"run_save": SaveIO.read_dict(run_path) if run_path != "" else {},
		"run_save_sources": SaveIO.describe_sources(run_path) if run_path != "" else {},
		"profile": _json_safe((sm.get("data") as Dictionary).duplicate(true)) if sm != null else {},
		"live": _live_state(),
		"errors": [],
		"log": [],
	}
	var root: Window = _root()
	if root != null:
		payload["window"] = [root.size.x, root.size.y]
		var visible: Vector2 = root.get_visible_rect().size
		payload["visible_rect"] = [visible.x, visible.y]
	var diag: Node = _node("DiagnosticsLog")
	if diag != null:
		payload["errors"] = diag.call("recent_errors")
		payload["log"] = diag.call("recent_messages")
	if _break_mode() == "drop_run":
		payload.erase("run_save")
	return payload


static func export_code() -> String:
	return encode(build_payload())


static func encode(payload: Dictionary) -> String:
	var raw: PackedByteArray = JSON.stringify(payload).to_utf8_buffer()
	var b64: String = Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP))
	return "%s:%s:%s" % [PREFIX, b64, _checksum(b64)]


static func _checksum(b64: String) -> String:
	return b64.sha256_text().substr(0, 8)


static func _scene_path() -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return ""
	return tree.current_scene.scene_file_path


## In-memory state the run save does not hold: where the player is right now.
static func _live_state() -> Dictionary:
	var live: Dictionary = {}
	var gs: Node = _node("GameState")
	if gs != null:
		live["run"] = {
			"operation": str(gs.get("selected_operation_id")),
			"battle": int(gs.get("current_battle")),
			"pending_evolution_unit_id": str(gs.get("pending_evolution_unit_id")),
			"tutorial_mode": bool(gs.get("tutorial_mode")),
			"entering_battle_review": bool(gs.get("entering_battle_review")),
			"run_seed": SaveIO.encode_i64(int(gs.get("run_seed"))),
			"battle_rng_seed": SaveIO.encode_i64(int(gs.get("battle_rng_seed"))),
			"reward_rng_state": SaveIO.encode_i64(int(gs.call("get_reward_rng_state"))),
		}
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var scene: Node = tree.current_scene if tree != null else null
	if scene != null and scene.get("combat_manager") != null:
		var battle: Dictionary = {
			"round": scene.get("_round_number"),
			"phase": scene.get("turn_phase"),
			"protocol": scene.get("protocol_points"),
			"battle_over": scene.get("battle_over"),
			"hero_rolls": scene.get("hero_rolls"),
			"enemy_rolls": scene.get("enemy_rolls"),
		}
		var provider: Object = scene.get("_roll_provider") as Object
		if provider != null and provider.has_method("get_stream_states"):
			battle["streams"] = provider.call("get_stream_states")
		live["battle"] = _json_safe(battle)
	return live


static func _user_agent() -> String:
	if not OS.has_feature("web"):
		return ""
	var ua: Variant = JavaScriptBridge.eval("navigator.userAgent", true)
	return str(ua) if ua != null else ""


## JSON keeps only doubles: 64-bit ints past 2^53 become strings (the save
## system's rule), objects become their text.
static func _json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_INT:
			return SaveIO.encode_i64(value) if absi(value) > 9007199254740992 else value
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key in value:
				out[str(key)] = _json_safe(value[key])
			return out
		TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var arr: Array = []
			for item in value:
				arr.append(_json_safe(item))
			return arr
		TYPE_OBJECT, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_COLOR, TYPE_STRING_NAME, TYPE_NODE_PATH:
			return str(value)
	return value


# ── Decode / import ───────────────────────────────────────────────────────────

## {"ok": bool, "error": String, "payload": Dictionary}. Whitespace anywhere in
## the code is ignored (chat apps wrap long lines).
static func decode(code: String) -> Dictionary:
	var compact: String = ""
	for part in code.split("\n"):
		compact += part.strip_edges().replace(" ", "").replace("\t", "").replace("\r", "")
	var parts: PackedStringArray = compact.split(":")
	if parts.size() != 3 or parts[0] != PREFIX:
		return _fail("not a %s state code" % PREFIX)
	if _break_mode() != "no_checksum" and _checksum(parts[1]) != parts[2].to_lower():
		return _fail("checksum mismatch - the code was changed or cut short")
	var packed: PackedByteArray = Marshalls.base64_to_raw(parts[1])
	if packed.is_empty():
		return _fail("the code holds no data")
	var raw: PackedByteArray = packed.decompress_dynamic(MAX_PAYLOAD_BYTES, FileAccess.COMPRESSION_GZIP)
	if raw.is_empty():
		return _fail("the code does not decompress")
	var parsed: Variant = JSON.parse_string(raw.get_string_from_utf8())
	if not (parsed is Dictionary):
		return _fail("the code is not a state payload")
	if int((parsed as Dictionary).get("format", 0)) != FORMAT:
		return _fail("unknown state code format %s" % str((parsed as Dictionary).get("format")))
	return {"ok": true, "error": "", "payload": parsed}


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "error": reason, "payload": {}}


## Writes a decoded payload's run save and profile to `run_path` / `profile_path`,
## replacing every copy that was there. Returns "" or the reason it refused.
static func import_payload(payload: Dictionary, run_path: String, profile_path: String) -> String:
	if _break_mode() == "import_noop":
		return ""
	SaveIO.erase(run_path)
	SaveIO.erase(profile_path)
	var run_save: Variant = payload.get("run_save", {})
	if run_save is Dictionary and not (run_save as Dictionary).is_empty():
		if not SaveIO.write_exact(run_path, run_save):
			return "could not write %s" % run_path
	var profile: Variant = payload.get("profile", {})
	if profile is Dictionary and not (profile as Dictionary).is_empty():
		if not SaveIO.write_exact(profile_path, profile):
			return "could not write %s" % profile_path
	return ""


## Called by SaveManager._ready before it loads anything. Debug builds only, and
## only into the dev_* paths. Returns the imported payload, or {} when there was
## no --load-state argument (or it failed, loudly).
static func import_from_launch_args(run_path: String, profile_path: String, dev_paths: bool) -> Dictionary:
	var source: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(LOAD_ARG):
			source = arg.trim_prefix(LOAD_ARG)
	if source == "":
		return {}
	if not OS.is_debug_build():
		push_error("[StateCode] --load-state is ignored outside debug builds.")
		return {}
	if not dev_paths:
		push_error("[StateCode] refusing to import: the save paths are not the dev_* files.")
		return {}
	var file: FileAccess = FileAccess.open(source, FileAccess.READ)
	if file == null:
		push_error("[StateCode] cannot read %s" % source)
		return {}
	var result: Dictionary = decode(file.get_as_text())
	file.close()
	if not bool(result["ok"]):
		push_error("[StateCode] %s: %s" % [source, result["error"]])
		return {}
	var payload: Dictionary = result["payload"]
	var refused: String = import_payload(payload, run_path, profile_path)
	if refused != "":
		push_error("[StateCode] import failed: %s" % refused)
		return {}
	print("[StateCode] imported %s (build %s, %s, scene %s, run screen '%s')" % [source,
		str(payload.get("build_id", "?")), str(payload.get("platform", "?")), str(payload.get("scene", "")),
		str((payload.get("run_save", {}) as Dictionary).get("screen", ""))])
	return payload
