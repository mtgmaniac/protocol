# Persistent player profile: user://save.json, save_version 1.
# Holds cross-run state only (tutorial flag, lifetime stats, boss-relic
# unlocks, reserved settings). Run state stays in GameState.
# PROFILE ISOLATION (Kev 2026-07-12, see DevContext): in any dev context —
# headless (audits, smokes, CI) OR a windowed `-s` rig (captures, diagnostics)
# — the profile resolves to DEV_SAVE_PATH, never the real save. Headless
# additionally stays memory-only (belt AND braces). The old headless-only
# guard let a windowed capture rig wipe and repopulate the real primer ledger.
extends Node

const SAVE_PATH := "user://save.json"
const DEV_SAVE_PATH := "user://dev_profile_save.json"  # rigs/tests land here, never the real profile
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

# --- Progression / unlocks ---
# Heroes the profile owns from the very first launch.
const STARTING_HEROES := ["combat", "engineer", "medic"]
# Operations available from the first launch (the rest unlock down the chain).
const STARTING_OPERATIONS := ["facility"]
# Every hero id in the game (used by the grandfather clause + the dev unlock-all).
const ALL_HEROES := ["combat", "avalanche", "medic", "engineer", "shield", "pulse", "ghost", "breaker"]
# Clearing an operation's boss unlocks the next link (uncapped, separate from the
# hero ladder). Ends at stellarMenagerie.
const OPERATION_CHAIN := ["facility", "hive", "veil", "voidCirclet", "stellarMenagerie"]
# Hero ladder: ordered rungs, at most ONE awarded per run end. HERO_LADDER[i] is the
# hero granted for rung (i + 1); its unlock condition lives in _hero_rung_satisfied().
const HERO_LADDER := ["avalanche", "shield", "pulse", "ghost", "breaker"]
const MAX_HERO_LADDER_RUNG := 5
# One-line unlock hints (all-caps, UI-facing), keyed by hero id and tied to each
# ladder rung's condition.
var data: Dictionary = {}
var _disk_enabled: bool = true
var _save_path: String = SAVE_PATH
# Entries awarded by the most recent record_run_finished(), consumed by the
# run-end UI via check_new_unlocks(). Shape: [{type, id, display_name}].
var _run_end_unlocks: Array = []


func _ready() -> void:
	_disk_enabled = DisplayServer.get_name() != "headless"
	if DevContext.is_isolated():
		_save_path = DEV_SAVE_PATH
		print("[SaveManager] dev context — profile isolated to %s (real save untouchable)" % _save_path)
	load_save()


func default_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"tutorial_done": false,
		"stats": {
			"runs_started": 0,
			"runs_won_by_op": {},
			"best_clear": 0,
			"best_clear_by_op": {},
			"nat20s": 0,
			"deaths": 0,
		},
		"unlocks": {
			"boss_relics": [],
			"heroes": STARTING_HEROES.duplicate(),
			"operations": STARTING_OPERATIONS.duplicate(),
			"hero_ladder_rung": 0,
			# Heroes unlocked but not yet added to a squad — drive the "NEW" badge.
			"heroes_new": [],
		},
		# Keyword primers (one-shot micro-tutorials, docs/PRIMERS.md): ids that
		# have successfully displayed and been dismissed.
		"onboarding": {
			"primers_seen": [],
		},
		"settings": {},
	}


func load_save() -> void:
	data = default_data()
	if not _disk_enabled or not FileAccess.file_exists(_save_path):
		return
	var file: FileAccess = FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		push_warning("[SaveManager] Could not open %s for reading." % _save_path)
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
	if not (stats.get("best_clear_by_op") is Dictionary):
		stats["best_clear_by_op"] = {}
	var loaded_unlocks: Dictionary = loaded.get("unlocks", {})
	var boss_relics: Array = []
	for relic_id in loaded_unlocks.get("boss_relics", []):
		boss_relics.append(str(relic_id))
	data["unlocks"]["boss_relics"] = boss_relics
	# New unlock keys heal to their defaults when absent (older saves).
	var had_new_schema: bool = loaded_unlocks.has("heroes")
	data["unlocks"]["heroes"] = _string_array(loaded_unlocks.get("heroes", STARTING_HEROES))
	data["unlocks"]["operations"] = _string_array(loaded_unlocks.get("operations", STARTING_OPERATIONS))
	data["unlocks"]["hero_ladder_rung"] = int(loaded_unlocks.get("hero_ladder_rung", 0))
	data["unlocks"]["heroes_new"] = _string_array(loaded_unlocks.get("heroes_new", []))
	if loaded.get("settings") is Dictionary:
		data["settings"] = loaded["settings"]
	# Onboarding block heals to defaults when absent (older saves).
	var had_onboarding: bool = loaded.get("onboarding") is Dictionary
	if had_onboarding:
		data["onboarding"]["primers_seen"] = _string_array((loaded["onboarding"] as Dictionary).get("primers_seen", []))
	# Grandfather clause: a pre-existing profile (played a run, or finished the
	# tutorial) that predates the unlock system keeps full access — every hero and
	# operation, ladder maxed — so no current player loses what they already had.
	# Only fires when migrating a save that lacked the new unlock schema.
	var is_existing_profile: bool = int(stats.get("runs_started", 0)) > 0 or bool(data["tutorial_done"])
	if is_existing_profile and not had_new_schema:
		data["unlocks"]["heroes"] = ALL_HEROES.duplicate()
		data["unlocks"]["operations"] = OPERATION_CHAIN.duplicate()
		data["unlocks"]["hero_ladder_rung"] = MAX_HERO_LADDER_RUNG
		data["unlocks"]["heroes_new"] = []
	# Primer grandfather (same clause shape): a veteran profile that predates the
	# primer system starts with every CURRENT primer marked seen — they've met
	# the mechanics; primers are for genuinely first sightings.
	if is_existing_profile and not had_onboarding:
		data["onboarding"]["primers_seen"] = _all_primer_ids()


func _string_array(value: Variant) -> Array:
	var out: Array = []
	if value is Array:
		for entry in value:
			out.append(str(entry))
	return out


func save() -> void:
	if not _disk_enabled:
		return
	var file: FileAccess = FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		push_warning("[SaveManager] Could not open %s for writing." % _save_path)
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()


# --- Settings (the free-form "settings" dict; persisted with the profile) ---

func get_setting(key: String, default: Variant = null) -> Variant:
	return (data.get("settings", {}) as Dictionary).get(key, default)


func set_setting(key: String, value: Variant) -> void:
	if not (data.get("settings") is Dictionary):
		data["settings"] = {}
	(data["settings"] as Dictionary)[key] = value
	save()


# --- Keyword primers (onboarding) ---

# Reads primer ids straight from the data file — SaveManager loads during
# autoload init, before DataManager is guaranteed ready, so no cross-autoload
# dependency here.
func _all_primer_ids() -> Array:
	var ids: Array = []
	var file: FileAccess = FileAccess.open("res://data/raw/primers.data.json", FileAccess.READ)
	if file == null:
		return ids
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		for entry in (parsed as Dictionary).get("primers", []):
			ids.append(str((entry as Dictionary).get("id", "")))
	return ids


func is_primer_seen(primer_id: String) -> bool:
	var onboarding: Dictionary = data.get("onboarding", {})
	return (onboarding.get("primers_seen", []) as Array).has(primer_id)


# Called ONLY after a primer successfully displayed and was dismissed.
func mark_primer_seen(primer_id: String) -> void:
	if not (data.get("onboarding") is Dictionary):
		data["onboarding"] = {"primers_seen": []}
	var seen: Array = data["onboarding"].get("primers_seen", [])
	if not seen.has(primer_id):
		seen.append(primer_id)
		data["onboarding"]["primers_seen"] = seen
		save()


# Dev tool: clear only primers_seen (RESET PRIMERS (DEV) in settings).
func dev_reset_primers() -> void:
	data["onboarding"] = {"primers_seen": []}
	save()


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
# reached in any run. Also evaluates the hero ladder + operation chain and
# records any newly-awarded unlocks for the run-end UI (check_new_unlocks).
func record_run_finished(result: String, op_id: String, battle_reached: int) -> void:
	var stats: Dictionary = data["stats"]
	stats["best_clear"] = maxi(int(stats.get("best_clear", 0)), battle_reached)
	var best_by_op: Dictionary = stats.get("best_clear_by_op", {})
	best_by_op[op_id] = maxi(int(best_by_op.get(op_id, 0)), battle_reached)
	stats["best_clear_by_op"] = best_by_op
	if result == "victory":
		var wins: Dictionary = stats.get("runs_won_by_op", {})
		wins[op_id] = int(wins.get(op_id, 0)) + 1
		stats["runs_won_by_op"] = wins
		unlock_boss_relic_for_op(op_id)
	_evaluate_run_end_unlocks(result, op_id)
	save()


# --- Progression evaluation (run end) ---

# Runs once per run end. Advances the operation chain (on a boss clear) and at most
# ONE hero-ladder rung, accumulating awards in _run_end_unlocks for the UI.
func _evaluate_run_end_unlocks(result: String, op_id: String) -> void:
	_run_end_unlocks.clear()
	# Operation chain: clearing this op's boss unlocks the next link. Guard on the raw
	# unlock list via _award_operation (NOT is_operation_unlocked, which is force-true
	# when headless) so the stored progression advances correctly in every context.
	if result == "victory":
		var next_op: String = _next_operation(op_id)
		if next_op != "":
			_award_operation(next_op)
	# Hero ladder: only the next rung is considered, so overshoot defers to later runs
	# (mirrors the evolution "one progression stop per win" rule).
	var rung: int = int(data["unlocks"].get("hero_ladder_rung", 0))
	if rung < MAX_HERO_LADDER_RUNG and _hero_rung_satisfied(rung):
		data["unlocks"]["hero_ladder_rung"] = rung + 1
		_award_hero(HERO_LADDER[rung])


# Whether the (0-based) ladder rung's condition is met by lifetime stats.
func _hero_rung_satisfied(rung_index: int) -> bool:
	var stats: Dictionary = data["stats"]
	var best_by_op: Dictionary = stats.get("best_clear_by_op", {})
	var wins: Dictionary = stats.get("runs_won_by_op", {})
	match rung_index:
		0:  # avalanche — first foothold, with a pity fallback
			return int(best_by_op.get("facility", 0)) >= 6 or int(stats.get("runs_started", 0)) >= 3
		1:  # shield — beat Facility
			return wins.has("facility")
		2:  # pulse — reach deep into Hive
			return int(best_by_op.get("hive", 0)) >= 6
		3:  # ghost — beat Hive
			return wins.has("hive")
		4:  # breaker — reach deep into Veil
			return int(best_by_op.get("veil", 0)) >= 6
	return false


func _next_operation(op_id: String) -> String:
	var idx: int = OPERATION_CHAIN.find(op_id)
	if idx >= 0 and idx + 1 < OPERATION_CHAIN.size():
		return OPERATION_CHAIN[idx + 1]
	return ""


func _award_hero(hero_id: String) -> void:
	var heroes: Array = data["unlocks"]["heroes"]
	if heroes.has(hero_id):
		return
	heroes.append(hero_id)
	var new_flags: Array = data["unlocks"].get("heroes_new", [])
	if not new_flags.has(hero_id):
		new_flags.append(hero_id)
	data["unlocks"]["heroes_new"] = new_flags
	_run_end_unlocks.append({"type": "hero", "id": hero_id, "display_name": _hero_display_name(hero_id)})


func _award_operation(op_id: String) -> void:
	var ops: Array = data["unlocks"]["operations"]
	if ops.has(op_id):
		return
	ops.append(op_id)
	_run_end_unlocks.append({"type": "operation", "id": op_id, "display_name": _operation_display_name(op_id)})


# --- Progression queries (UI) ---

# Headless (sim / audit / CI) always reads as fully unlocked so those paths can
# exercise every hero and operation regardless of the on-disk profile.
func _fully_unlocked_override() -> bool:
	return not _disk_enabled


func is_hero_unlocked(hero_id: String) -> bool:
	if _fully_unlocked_override():
		return true
	return (data["unlocks"].get("heroes", []) as Array).has(hero_id)


func is_operation_unlocked(op_id: String) -> bool:
	if _fully_unlocked_override():
		return true
	return (data["unlocks"].get("operations", []) as Array).has(op_id)


func is_hero_new(hero_id: String) -> bool:
	return (data["unlocks"].get("heroes_new", []) as Array).has(hero_id)


func get_hero_ladder_rung() -> int:
	return int(data["unlocks"].get("hero_ladder_rung", 0))


# The (0-based) ladder index a still-locked hero occupies, or -1 if not a ladder hero.
func hero_ladder_index(hero_id: String) -> int:
	return HERO_LADDER.find(hero_id)


# Clears a hero's NEW flag once it's been added to a squad.
func acknowledge_hero(hero_id: String) -> void:
	var new_flags: Array = data["unlocks"].get("heroes_new", [])
	if new_flags.has(hero_id):
		new_flags.erase(hero_id)
		data["unlocks"]["heroes_new"] = new_flags
		save()


# Entries awarded by the most recent run end, for the run-end UNLOCKED section.
func check_new_unlocks() -> Array:
	return _run_end_unlocks.duplicate(true)


func _hero_display_name(hero_id: String) -> String:
	var unit: Resource = DataManager.get_unit(hero_id)
	if unit != null and str(unit.get("display_name")) != "":
		return str(unit.get("display_name"))
	return hero_id.capitalize()


func _operation_display_name(op_id: String) -> String:
	var op: Resource = DataManager.get_operation(op_id)
	if op != null and str(op.get("display_name")) != "":
		return str(op.get("display_name"))
	return op_id.capitalize()


# --- Dev tools ---

# Unlock everything: every hero, operation, and boss relic; ladder maxed.
func dev_unlock_all() -> void:
	data["unlocks"]["heroes"] = ALL_HEROES.duplicate()
	data["unlocks"]["operations"] = OPERATION_CHAIN.duplicate()
	data["unlocks"]["hero_ladder_rung"] = MAX_HERO_LADDER_RUNG
	data["unlocks"]["heroes_new"] = []
	var boss_relics: Array = []
	for op_id in BOSS_RELIC_BY_OP.keys():
		boss_relics.append(str(BOSS_RELIC_BY_OP[op_id]))
	data["unlocks"]["boss_relics"] = boss_relics
	save()


# Wipe the profile back to a first-launch default (stats included).
func dev_reset_profile() -> void:
	data = default_data()
	_run_end_unlocks.clear()
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
