# ResumeGuard — the way out of a CONTINUE that hangs on load (G-48, Kev 2026-10-06).
#
# The run save names the screen CONTINUE resumes on, and it is written before
# that screen has ever loaded. If the screen then hangs, every CONTINUE hangs
# the same way and the only way out was ABANDON RUN. Two small files beside the
# run save fix that; the run save's own format is untouched:
#
#   resume_guard.json  the MARKER. CONTINUE writes it (which run save it resumed,
#                      and the screen / battle / round) before the screen loads.
#                      It clears when the screen finishes loading with no error,
#                      or when the run saves a point past it. A marker still set
#                      at the next launch means the last resume never got past
#                      loading.
#   run.json.prev      the last save from the PREVIOUS screen. run.json.bak
#                      cannot serve: it is the previous WRITE, and every screen
#                      saves twice on entry, so it holds the same point.
#
# With the marker set the menu offers RESUME EARLIER POINT, which makes the
# .prev save the run save again. Nothing switches automatically.
#
# Pure helpers and file access only: SaveManager owns when they are called.
# Preloaded by path (not a class_name) so -s gates parse it before the editor
# rebuilds the global class cache.
extends RefCounted

const SaveIO = preload("res://scripts/autoloads/save_io.gd")

const PREV_SUFFIX := ".prev"
## Debug-build seam for the gate's deliberate breaks (never set by the game):
## no_marker, never_clear, routing_save, no_prev.
const BREAK_ARG := "--resume-guard-break="
const LINE := "The last resume didn't get past loading."


static func break_mode() -> String:
	if not OS.is_debug_build():
		return ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(BREAK_ARG):
			return arg.trim_prefix(BREAK_ARG)
	return ""


# ── Points ────────────────────────────────────────────────────────────────────

## Where a run save resumes: {screen, battle, round}. `round` is the battle
## checkpoint's round, 0 when the save holds none.
static func point_of(payload: Dictionary) -> Dictionary:
	var run_block: Variant = payload.get("run", {})
	var point := {
		"screen": str(payload.get("screen", "")),
		"battle": int((run_block as Dictionary).get("current_battle", 0)) if run_block is Dictionary else 0,
		"round": 0,
	}
	var checkpoint: Variant = payload.get("battle_checkpoint", {})
	if point["screen"] == "battle" and checkpoint is Dictionary:
		point["round"] = int((checkpoint as Dictionary).get("round", 0))
	return point


## Screen + battle: saves sharing it are the same screen (a battle's rounds
## included). "" for a payload that is not a run save.
static func screen_key(payload: Dictionary) -> String:
	if not (payload.get("run") is Dictionary) or str(payload.get("screen", "")) == "":
		return ""
	var point: Dictionary = point_of(payload)
	return "%s|%d" % [point["screen"], point["battle"]]


static func run_seed_of(payload: Dictionary) -> String:
	var run_block: Variant = payload.get("run", {})
	return str((run_block as Dictionary).get("run_seed", "")) if run_block is Dictionary else ""


## The ruled progress rule: a different screen, a later battle, or a later
## checkpoint round than the marker's.
static func moved_past(marker: Dictionary, point: Dictionary) -> bool:
	if str(point.get("screen", "")) != str(marker.get("screen", "")):
		return true
	if int(point.get("battle", 0)) > int(marker.get("battle", 0)):
		return true
	return int(point.get("round", 0)) > int(marker.get("round", 0))


## Player-facing name of a restored point, for "Restored %s."
static func describe(point: Dictionary) -> String:
	var battle: int = int(point.get("battle", 0))
	match str(point.get("screen", "")):
		"reward":
			return "the rewards after battle %d" % battle
		"evolution":
			return "the upgrade after battle %d" % battle
		"fork":
			return "the route choice after battle %d" % battle
		"intercept":
			return "the intercept after battle %d" % battle
	return "the start of battle %d" % battle


# ── The previous screen's save ────────────────────────────────────────────────

static func prev_path(run_path: String) -> String:
	return run_path + PREV_SUFFIX


## Keeps the run save on file as the previous screen's save.
static func keep_previous(run_path: String) -> void:
	if break_mode() == "no_prev" or not FileAccess.file_exists(run_path):
		return
	var dir: DirAccess = DirAccess.open(run_path.get_base_dir())
	if dir != null:
		dir.copy(run_path, prev_path(run_path))


static func drop_previous(run_path: String) -> void:
	var path: String = prev_path(run_path)
	if not FileAccess.file_exists(path):
		return
	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if dir != null:
		dir.remove(path)


## The earlier point RESUME EARLIER POINT would restore, or {} when there is
## none worth offering: no .prev, not a save this build reads, another run's,
## the same screen as `current`, or not older than it.
static func earlier_point(run_path: String, current: Dictionary, schema_version: int) -> Dictionary:
	var earlier: Dictionary = SaveIO._read_file(prev_path(run_path))
	if earlier.is_empty() or current.is_empty():
		return {}
	if int(earlier.get("schema_version", 0)) != schema_version or screen_key(earlier) == "":
		return {}
	if run_seed_of(earlier) != run_seed_of(current) or screen_key(earlier) == screen_key(current):
		return {}
	if int(earlier.get(SaveIO.SEQ_KEY, 0)) >= int(current.get(SaveIO.SEQ_KEY, 0)):
		return {}
	return earlier
