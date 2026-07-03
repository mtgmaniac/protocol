# Persistent player profile: user://save.json, save_version 1.
# Holds cross-run state only (tutorial flag, lifetime stats, boss-relic
# unlocks, reserved settings). Run state stays in GameState.
# Headless runs (audits, smoke tests, CI) keep the profile in memory and
# never touch disk, so gates can't pollute a developer's save.
extends Node

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

# First clear of an operation unlocks its boss's relic (drafted as a
# Starting Directive at run start; excluded from normal relic drafts).
const BOSS_RELIC_BY_OP := {
	"facility": "salvageRig",
	"hive": "chitinGraft",
	"veil": "resonantChorus",
	"voidCirclet": "rootAccess",
	"stellarMenagerie": "mantleCore",
}

var data: Dictionary = {}
var _disk_enabled: bool = true


func _ready() -> void:
	_disk_enabled = DisplayServer.get_name() != "headless"
	load_save()


func default_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"tutorial_done": false,
		"stats": {
			"runs_started": 0,
			"runs_won_by_op": {},
			"best_clear": 0,
			"nat20s": 0,
			"deaths": 0,
		},
		"unlocks": {
			"boss_relics": [],
		},
		"settings": {},
	}


func load_save() -> void:
	data = default_data()
	if not _disk_enabled or not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("[SaveManager] Could not open %s for reading." % SAVE_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		push_warning("[SaveManager] Malformed save file — starting fresh.")
		return
	_merge_loaded(parsed as Dictionary)


# Merge a loaded payload onto defaults so missing keys (older saves) heal.
func _merge_loaded(loaded: Dictionary) -> void:
	data["save_version"] = SAVE_VERSION
	data["tutorial_done"] = bool(loaded.get("tutorial_done", false))
	var loaded_stats: Dictionary = loaded.get("stats", {})
	var stats: Dictionary = data["stats"]
	for stat_key in stats.keys():
		if loaded_stats.has(stat_key):
			stats[stat_key] = loaded_stats[stat_key]
	var loaded_unlocks: Dictionary = loaded.get("unlocks", {})
	var boss_relics: Array = []
	for relic_id in loaded_unlocks.get("boss_relics", []):
		boss_relics.append(str(relic_id))
	data["unlocks"]["boss_relics"] = boss_relics
	if loaded.get("settings") is Dictionary:
		data["settings"] = loaded["settings"]


func save() -> void:
	if not _disk_enabled:
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[SaveManager] Could not open %s for writing." % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()


# --- Tutorial ---

func is_tutorial_done() -> bool:
	return bool(data.get("tutorial_done", false))


func mark_tutorial_done() -> void:
	data["tutorial_done"] = true
	save()


# --- Stats ---

func get_stats() -> Dictionary:
	return data.get("stats", {})


func record_run_started() -> void:
	data["stats"]["runs_started"] = int(data["stats"].get("runs_started", 0)) + 1
	save()


# Called once at run end. Victory on the final battle counts as an op win
# and unlocks that op's boss relic; best_clear tracks the furthest battle
# reached in any run.
func record_run_finished(result: String, op_id: String, battle_reached: int) -> void:
	var stats: Dictionary = data["stats"]
	stats["best_clear"] = maxi(int(stats.get("best_clear", 0)), battle_reached)
	if result == "victory":
		var wins: Dictionary = stats.get("runs_won_by_op", {})
		wins[op_id] = int(wins.get(op_id, 0)) + 1
		stats["runs_won_by_op"] = wins
		unlock_boss_relic_for_op(op_id)
	save()


func record_nat20() -> void:
	data["stats"]["nat20s"] = int(data["stats"].get("nat20s", 0)) + 1
	save()


func record_hero_death() -> void:
	data["stats"]["deaths"] = int(data["stats"].get("deaths", 0)) + 1
	save()


# --- Boss-relic unlocks ---

func get_unlocked_boss_relics() -> Array:
	return (data["unlocks"].get("boss_relics", []) as Array).duplicate()


func unlock_boss_relic_for_op(op_id: String) -> void:
	var relic_id: String = str(BOSS_RELIC_BY_OP.get(op_id, ""))
	if relic_id == "":
		return
	var unlocked: Array = data["unlocks"].get("boss_relics", [])
	if not unlocked.has(relic_id):
		unlocked.append(relic_id)
		data["unlocks"]["boss_relics"] = unlocked
		save()
