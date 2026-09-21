# Persistent player profile: user://save.json, save_version 1.
# Holds cross-run state only (tutorial flag, lifetime stats, boss-relic
# unlocks, reserved settings). Run state stays in GameState.
# PROFILE ISOLATION (Kev 2026-07-12, see DevContext): in any dev context —
# headless (audits, smokes, CI) OR a windowed `-s` rig (captures, diagnostics)
# — the profile resolves to DEV_SAVE_PATH, never the real save. Headless
# additionally stays memory-only (belt AND braces). The old headless-only
# guard let a windowed capture rig wipe and repopulate the real primer ledger.
extends Node

const SaveIO = preload("res://scripts/autoloads/save_io.gd")

signal setting_changed(key: String, value: Variant)

const SAVE_PATH := "user://save.json"
const DEV_SAVE_PATH := "user://dev_profile_save.json"  # rigs/tests land here, never the real profile
const SAVE_VERSION := 1

# ── Active-run save (separate file, separate lifecycle) ──────────────────────
# save.json persists forever; run.json holds ONE run and is destroyed at
# victory, defeat and abandon. Two files because they fail differently: a
# schema bump that discards an in-progress run must never cost a player their
# unlocks, and that is only structurally true if they are not the same file.
# Profile isolation applies identically — a rig writes dev_run.json.
const BattleCheckpoint := preload("res://scripts/battle/battle_checkpoint.gd")
const RUN_SAVE_PATH := "user://run.json"
const DEV_RUN_SAVE_PATH := "user://dev_run.json"
## Bump ONLY when a run save from the previous build can no longer be trusted.
## A mismatch discards run.json (and says so on the menu); save.json migrates.
## v2 (2026-09-21) added the optional `battle_checkpoint` block. v1 is a strict
## subset (no block = no checkpoint), so it is READ FORWARD rather than
## discarded: see RUN_SAVE_VERSIONS_READABLE.
const RUN_SAVE_VERSION := 2
## Older run-save versions this build loads as-is. Only a version whose payload
## is a strict subset of the current one belongs here; anything else discards.
const RUN_SAVE_VERSIONS_READABLE := [1, 2]
## Hash of the run save's SHAPE — every key name and value type, recursively,
## never the values (SaveIO.structure_fingerprint). The save_schema gate
## recomputes this from a live checkpoint and fails when it moves, so changing
## what to_save_dict() produces without bumping RUN_SAVE_VERSION cannot ship.
## These two constants move TOGETHER: a version bump needs a new fingerprint,
## and a new fingerprint needs a version bump plus a migration decision.
const RUN_SAVE_SCHEMA_FINGERPRINT := "133195c344ed7b29"

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
const STARTING_HEROES := ["combat", "engineer", "medic", "pulse"]
# Operations available from the first launch (the rest unlock down the chain).
const STARTING_OPERATIONS := ["facility"]
# Every hero id in the game (used by the grandfather clause + the dev unlock-all).
const ALL_HEROES := ["combat", "avalanche", "medic", "engineer", "shield", "pulse", "ghost", "breaker"]
# Clearing an operation's boss unlocks the next link (uncapped, separate from the
# hero ladder). Ends at stellarMenagerie.
const OPERATION_CHAIN := ["facility", "hive", "veil", "voidCirclet", "stellarMenagerie"]
# Hero ladder: ordered rungs, at most ONE awarded per run end. HERO_LADDER[i] is the
# hero granted for rung (i + 1); its unlock condition lives in _hero_rung_satisfied().
const HERO_LADDER := ["avalanche", "shield", "ghost", "breaker"]
const MAX_HERO_LADDER_RUNG := 4
# One-line unlock hints (all-caps, UI-facing), keyed by hero id and tied to each
# ladder rung's condition.
var data: Dictionary = {}
var _disk_enabled: bool = true
var _save_path: String = SAVE_PATH
var _run_save_path: String = RUN_SAVE_PATH
## Set at boot when a run.json was found but could not be used, so the menu can
## say so once. Shape: "" (nothing to report) or a player-facing sentence.
var _run_save_notice: String = ""
## Harness-supplied block from the last resume_run(); always {} in live play.
var _resume_extra: Dictionary = {}
## The battle-ENTRY run block of the battle in progress (GameState.to_save_dict
## at checkpoint_run("battle"), before the battle's one-shot consumptions).
## Every end-of-round checkpoint is written beside THIS run block rather than
## the live one, so a checkpoint that later fails validation still restarts
## the battle from a correct, pre-consumption state. {} outside a battle.
var _battle_entry_run: Dictionary = {}
## A validated battle checkpoint waiting for battle_scene to restore it
## (set by resume_run, taken once by take_pending_battle_restore).
var _pending_battle_restore: Dictionary = {}
# Entries awarded by the most recent record_run_finished(), consumed by the
# run-end UI via check_new_unlocks(). Shape: [{type, id, display_name}].
var _run_end_unlocks: Array = []


func _ready() -> void:
	_disk_enabled = DisplayServer.get_name() != "headless"
	if DevContext.is_isolated():
		_save_path = DEV_SAVE_PATH
		_run_save_path = DEV_RUN_SAVE_PATH
		print("[SaveManager] dev context - profile isolated to %s (real save untouchable)" % _save_path)
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
			# Completed run-ends, win AND loss (unlike runs_started this only
			# advances at record_run_finished). Retained after retiring feedback nudges.
			"runs_finished": 0,
			# Unlock metric (Build F fence): every encounter ENTERED counts once,
			# win, lose, or retreat — never rounds (farmable).
			"battles_fought": 0,
		},
		"unlocks": {
			"boss_relics": [],
			"heroes": STARTING_HEROES.duplicate(),
			"operations": STARTING_OPERATIONS.duplicate(),
			"hero_ladder_rung": 0,
			# Heroes unlocked but not yet added to a squad — drive the "NEW" badge.
			"heroes_new": [],
			# Item-gate progression (Build F): how many battle-count gates have been
			# AWARDED (buckets 0..N open). Earning accrues in battles_fought; gates
			# are evaluated at run end only, so pools never change mid-run.
			"item_gates_awarded": 0,
		},
		# Keyword primers (one-shot micro-tutorials, docs/PRIMERS.md): ids that
		# have successfully displayed and been dismissed.
		"onboarding": {
			"primers_seen": [],
			# One-time operation-origin acknowledgement lives beside primers so save
			# migration has one onboarding surface.
			"operation_origins_seen": [],
		},
		"settings": {},
	}


func load_save() -> void:
	data = default_data()
	if not _disk_enabled:
		return
	# SaveIO picks the best surviving copy across primary / .bak / the web
	# mirror, and returns {} when every one of them is missing or corrupt.
	var loaded: Dictionary = SaveIO.read_dict(_save_path, true)
	if loaded.is_empty():
		return
	_migrate_profile(loaded)


## Schema dispatch for the PROFILE. Unlike run.json, a version mismatch here may
## never discard anything: these are the player's unlocks, and a future schema
## bump that wipes them is the worst bug this system could have. Every version
## must therefore land on a path that ends in _merge_loaded(), which already
## heals missing keys against defaults and carries the grandfather clauses.
##
## v1 is the only version that has ever shipped, so the migration ladder is a
## no-op today — it exists so the NEXT bump has an obvious place to go and
## cannot be implemented as "discard and start fresh".
func _migrate_profile(loaded: Dictionary) -> void:
	var version: int = int(loaded.get("save_version", 0))
	match version:
		0, SAVE_VERSION:
			# 0 = pre-versioning; _merge_loaded's grandfather clauses handle it.
			pass
		_:
			# A save from a NEWER build than this one. Merging is still the right
			# move — unknown keys are ignored, known keys are kept — and it beats
			# the alternative of deleting a player's progress because they opened
			# an older build once.
			push_warning("[SaveManager] profile save_version %d is newer than %d - merging what is recognized." % [version, SAVE_VERSION])
	_merge_loaded(loaded)


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
		if str(relic_id) != "twinFates":
			boss_relics.append(str(relic_id))
	data["unlocks"]["boss_relics"] = boss_relics
	# New unlock keys heal to their defaults when absent (older saves).
	var had_new_schema: bool = loaded_unlocks.has("heroes")
	data["unlocks"]["heroes"] = _string_array(loaded_unlocks.get("heroes", STARTING_HEROES))
	# Pulse Tech joined the starting roster after profiles already existed. Add the
	# starter without removing or reordering anything the player already owns.
	if not (data["unlocks"]["heroes"] as Array).has("pulse"):
		(data["unlocks"]["heroes"] as Array).append("pulse")
	data["unlocks"]["operations"] = _string_array(loaded_unlocks.get("operations", STARTING_OPERATIONS))
	data["unlocks"]["hero_ladder_rung"] = int(loaded_unlocks.get("hero_ladder_rung", 0))
	data["unlocks"]["heroes_new"] = _string_array(loaded_unlocks.get("heroes_new", []))
	data["unlocks"]["item_gates_awarded"] = int(loaded_unlocks.get("item_gates_awarded", 0))
	if loaded.get("settings") is Dictionary:
		data["settings"] = loaded["settings"].duplicate(true)
		data["settings"].erase("dev_mode")
	# Onboarding block heals to defaults when absent (older saves).
	var had_onboarding: bool = loaded.get("onboarding") is Dictionary
	if had_onboarding:
		var loaded_onboarding: Dictionary = loaded["onboarding"] as Dictionary
		data["onboarding"]["primers_seen"] = _string_array(loaded_onboarding.get("primers_seen", []))
		data["onboarding"]["operation_origins_seen"] = _string_array(loaded_onboarding.get("operation_origins_seen", []))
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
	# Item-gate grandfather (Build F, same clause shape): a profile that has
	# played but predates the item-gate schema keeps full pools — every gate
	# awarded, so no current player loses reward variety they already had.
	if is_existing_profile and not loaded_unlocks.has("item_gates_awarded"):
		data["unlocks"]["item_gates_awarded"] = DataManager.unlock_gate_count()
	# Primer grandfather (same clause shape): a veteran profile that predates the
	# primer system starts with every CURRENT primer marked seen — they've met
	# the mechanics; primers are for genuinely first sightings.
	if is_existing_profile and not had_onboarding:
		data["onboarding"]["primers_seen"] = _all_primer_ids()
	# Lore presentation migration: existing operations were unlocked before this
	# feature existed, so never replay their unlock-origin event.
	var saved_onboarding: Dictionary = loaded.get("onboarding", {}) as Dictionary
	if not saved_onboarding.has("operation_origins_seen"):
		data["onboarding"]["operation_origins_seen"] = (data["unlocks"].get("operations", []) as Array).duplicate()
	# The old rung 3 meant Pulse. Rungs now mean the ordered heroes above, so a
	# stored number cannot be carried forward safely. Derive it from actual owned
	# ladder heroes instead; ownership itself is always preserved.
	data["unlocks"]["hero_ladder_rung"] = _normalized_hero_ladder_rung(data["unlocks"]["heroes"] as Array)


func _string_array(value: Variant) -> Array:
	var out: Array = []
	if value is Array:
		for entry in value:
			out.append(str(entry))
	return out


# Counts only the contiguous prefix: a malformed/dev-edited profile that owns a
# later ladder hero still receives any earlier missing rung in the proper order.
func _normalized_hero_ladder_rung(heroes: Array) -> int:
	var rung := 0
	for hero_id in HERO_LADDER:
		if not heroes.has(hero_id):
			break
		rung += 1
	return rung


func save() -> void:
	if not _disk_enabled:
		return
	SaveIO.write_dict(_save_path, data)


# ── Active-run save ──────────────────────────────────────────────────────────
# Checkpoints land at NODE BOUNDARIES: after a screen has generated its content
# and before the player acts on it. Inside a battle there is ONE more kind: the
# end-of-round checkpoint (checkpoint_battle_round), taken only at the stable
# ready-to-roll boundary after a round fully resolves. Nothing mid-round is ever
# serialized; a reload before the first round completes restarts the battle
# from its opening state, as before.

## Writes the current run. `screen` is where CONTINUE should land the player.
## There is no per-call "has this battle been counted" argument: that lives in
## GameState.battle_entry_counted as saved run state, so every checkpoint from
## every call site carries it and none of them can forget to.
func checkpoint_run(screen: String, extra: Dictionary = {}) -> void:
	# NOTE: unlike the profile, the run save is NOT disabled headless. The
	# memory-only headless rule exists to make the real PLAYER PROFILE
	# untouchable; run.json in any dev context already resolves to dev_run.json
	# through DevContext, and the isolation gate fingerprints the real run.json
	# alongside save.json. Disabling it here instead would make every headless
	# save gate structurally unable to run, which is a worse trade.
	# The tutorial is a scripted exhibition, not a run (Kev, Q4). Writing it
	# would offer CONTINUE into a drill that has no resume path, and would put
	# tutorial_mode into a file that outlives the session.
	if bool(GameState.tutorial_mode):
		return
	if GameState.selected_operation_id == "" or GameState.current_battle <= 0:
		return
	# Every node checkpoint supersedes any battle checkpoint: a battle entry
	# starts a fresh one, and any other screen means the battle is behind us.
	_pending_battle_restore = {}
	_battle_entry_run = GameState.to_save_dict() if screen == "battle" else {}
	SaveIO.write_dict(_run_save_path, build_run_payload(screen, extra))


## End-of-round battle checkpoint (BattleCheckpoint.capture). Written beside the
## battle-ENTRY run block, never the live one: see _battle_entry_run. No-op in
## the tutorial and outside a battle checkpointed at entry.
func checkpoint_battle_round(checkpoint: Dictionary) -> void:
	if bool(GameState.tutorial_mode) or _battle_entry_run.is_empty() or checkpoint.is_empty():
		return
	SaveIO.write_dict(_run_save_path, build_run_payload("battle", {}, checkpoint, _battle_entry_run))


## The battle ended normally: drop its checkpoint so a finished encounter can
## never be restored. The run save goes back to the battle-entry snapshot (the
## pre-checkpoint behavior) until the next node checkpoint (reward screen) or
## the run end (run.json deleted) takes over.
func clear_battle_checkpoint() -> void:
	_pending_battle_restore = {}
	if bool(GameState.tutorial_mode) or _battle_entry_run.is_empty():
		return
	SaveIO.write_dict(_run_save_path, build_run_payload("battle", {}, {}, _battle_entry_run))


## Fallback for a checkpoint that validated but could not be rebuilt: put
## GameState back on the battle-ENTRY run so the battle restarts correctly.
func reload_battle_entry_run() -> void:
	if not _battle_entry_run.is_empty():
		GameState.load_from_dict(_battle_entry_run)


## The validated checkpoint resume_run found for this battle, once; {} if none.
func take_pending_battle_restore() -> Dictionary:
	var pending: Dictionary = _pending_battle_restore
	_pending_battle_restore = {}
	return pending


## The run save's payload, in MEMORY types. Extracted so the schema-fingerprint
## gate hashes the same structure this writes, rather than a second copy of the
## envelope maintained beside it — and so the fingerprint sees int vs float,
## which the on-disk JSON collapses (every JSON number parses as a double).
## `run_block` overrides the live GameState run (end-of-round checkpoints keep
## the battle-entry snapshot there).
func build_run_payload(screen: String, extra: Dictionary = {}, battle_checkpoint: Dictionary = {},
		run_block: Dictionary = {}) -> Dictionary:
	return {
		"schema_version": RUN_SAVE_VERSION,
		"build_id": str(ProjectSettings.get_setting("application/config/version", "")),
		"saved_at": Time.get_datetime_string_from_system(true, true),
		"screen": screen,
		"run": run_block if not run_block.is_empty() else GameState.to_save_dict(),
		# Opaque to SaveManager. The balance harness parks its OWN seeded stream
		# states here (the d20 provider and the policy RNG) — state the live game
		# keeps elsewhere (its battle streams ride in battle_checkpoint) or does
		# not have (there is no policy). Keeping it in the envelope rather than in
		# the run block preserves "GameState owns the run's save shape".
		"extra": extra,
		# The battle in progress at its last completed round, or {} (between
		# battles, before a battle's first round completes, or after it ends).
		# Shape and rules: BattleCheckpoint.
		"battle_checkpoint": battle_checkpoint,
	}


## The stored run, or {} when there is none / it cannot be used. Sets the menu
## notice as a side effect when a save was found but rejected.
func peek_run_save() -> Dictionary:
	var loaded: Dictionary = SaveIO.read_dict(_run_save_path, true)
	if loaded.is_empty():
		return {}
	var version: int = int(loaded.get("schema_version", 0))
	if not RUN_SAVE_VERSIONS_READABLE.has(version):
		# Ruled behavior: discard, say so once, never attempt a partial load.
		# A run save spans the whole rules engine; migrating one across a schema
		# bump is a far bigger promise than losing a single run in progress.
		push_warning("[SaveManager] run save schema %d != %d - discarding." % [version, RUN_SAVE_VERSION])
		clear_run_save()
		_run_save_notice = "Your previous run was from an older build and couldn't be restored."
		return {}
	if not (loaded.get("run") is Dictionary):
		push_warning("[SaveManager] run save has no run block - discarding.")
		clear_run_save()
		_run_save_notice = "Your previous run couldn't be restored."
		return {}
	return loaded


func has_run_save() -> bool:
	return not peek_run_save().is_empty()


## Restores the run into GameState. Returns the screen to resume on, or "" when
## there was nothing to restore.
func resume_run() -> String:
	var loaded: Dictionary = peek_run_save()
	if loaded.is_empty():
		return ""
	var screen: String = str(loaded.get("screen", ""))
	var run_block: Dictionary = loaded.get("run", {}) as Dictionary
	_pending_battle_restore = {}
	_battle_entry_run = GameState._restore_json_ints(run_block) if screen == "battle" else {}
	# A battle checkpoint wins only if it fully validates against this run;
	# otherwise the battle restarts from its entry exactly as it did before
	# checkpoints existed. Validated BEFORE loading, because the two candidates
	# are different run blocks (entry snapshot vs. mid-battle).
	var checkpoint: Variant = loaded.get("battle_checkpoint", {})
	if screen == "battle" and checkpoint is Dictionary and not (checkpoint as Dictionary).is_empty():
		var decoded: Dictionary = BattleCheckpoint.decode(checkpoint, int(run_block.get("current_battle", 0)))
		if not decoded.is_empty():
			GameState.load_from_dict((checkpoint as Dictionary)["run"] as Dictionary)
			_pending_battle_restore = {"state": decoded, "round": int((checkpoint as Dictionary).get("round", 0))}
		else:
			push_warning("[SaveManager] battle checkpoint unusable - the battle restarts from its entry.")
	if _pending_battle_restore.is_empty():
		GameState.load_from_dict(run_block)
	_resume_extra = (loaded.get("extra", {}) as Dictionary).duplicate(true)
	return screen


## The `extra` block from the most recent resume_run() ({} in live play).
func get_resume_extra() -> Dictionary:
	return _resume_extra.duplicate(true)


func clear_run_save() -> void:
	_battle_entry_run = {}
	_pending_battle_restore = {}
	SaveIO.erase(_run_save_path)


## One-shot: the menu asks once and the notice is consumed.
func take_run_save_notice() -> String:
	var notice: String = _run_save_notice
	_run_save_notice = ""
	return notice


# --- Settings (the free-form "settings" dict; persisted with the profile) ---

func get_setting(key: String, default: Variant = null) -> Variant:
	return (data.get("settings", {}) as Dictionary).get(key, default)


func set_setting(key: String, value: Variant) -> void:
	if not (data.get("settings") is Dictionary):
		data["settings"] = {}
	(data["settings"] as Dictionary)[key] = value
	save()
	setting_changed.emit(key, value)


# Retired feedback_nudge_* settings may remain in older profiles; they are inert.

# --- Operation lore onboarding ---

func has_seen_operation_origin(operation_id: String) -> bool:
	return (data["onboarding"].get("operation_origins_seen", []) as Array).has(operation_id)


func acknowledge_operation_origin(operation_id: String) -> void:
	var seen: Array = data["onboarding"].get("operation_origins_seen", [])
	if seen.has(operation_id):
		return
	seen.append(operation_id)
	data["onboarding"]["operation_origins_seen"] = seen
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


# Build F: the unlock metric. Called exactly once per encounter ENTERED
# (battle_scene._init_live_battle, live entries only — review re-entries and
# the tutorial never reach it). Farm-proof by construction: nothing
# round-based touches this counter.
func record_battle_entered() -> void:
	data["stats"]["battles_fought"] = int(data["stats"].get("battles_fought", 0)) + 1
	save()


func get_battles_fought() -> int:
	return int(data["stats"].get("battles_fought", 0))


# Gates already AWARDED (buckets 0..N open). Only _evaluate_item_gates — run
# end — ever advances this, so pool composition is frozen for a whole run.
func get_item_gates_awarded() -> int:
	return int(data["unlocks"].get("item_gates_awarded", 0))


# Called once at run end. Victory on the final battle counts as an op win
# and unlocks that op's boss relic; best_clear tracks the furthest battle
# reached in any run. Also evaluates the hero ladder + operation chain and
# records any newly-awarded unlocks for the run-end UI (check_new_unlocks).
func record_run_finished(result: String, op_id: String, battle_reached: int) -> void:
	# One delta per run end: boss relic (event-gated), item gates (battle-count),
	# hero ladder + operation chain — everything lands together on the unlock screen.
	_run_end_unlocks.clear()
	var stats: Dictionary = data["stats"]
	stats["runs_finished"] = int(stats.get("runs_finished", 0)) + 1
	stats["best_clear"] = maxi(int(stats.get("best_clear", 0)), battle_reached)
	var best_by_op: Dictionary = stats.get("best_clear_by_op", {})
	best_by_op[op_id] = maxi(int(best_by_op.get(op_id, 0)), battle_reached)
	stats["best_clear_by_op"] = best_by_op
	if result == "victory":
		var wins: Dictionary = stats.get("runs_won_by_op", {})
		wins[op_id] = int(wins.get(op_id, 0)) + 1
		stats["runs_won_by_op"] = wins
		unlock_boss_relic_for_op(op_id)
	_evaluate_item_gates()
	_evaluate_run_end_unlocks(result, op_id)
	save()


# --- Progression evaluation (run end) ---

# Runs once per run end. Advances the operation chain (on a boss clear) and at most
# ONE hero-ladder rung, accumulating awards in _run_end_unlocks for the UI.
func _evaluate_run_end_unlocks(result: String, op_id: String) -> void:
	# (record_run_finished cleared _run_end_unlocks; boss-relic and item-gate
	# awards may already sit in it.)
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


# Build F: item gates. Earning (battles_fought) accrues during play; awarding
# happens HERE, at run end only — pools never change composition mid-run.
# Every gate whose threshold the counter has crossed since the last award
# lands together: a retreat-abandoned run has no run end, so its crossings
# catch up on the next completed run's screen (nothing is dropped).
func _evaluate_item_gates() -> void:
	var fought: int = int(data["stats"].get("battles_fought", 0))
	var awarded: int = int(data["unlocks"].get("item_gates_awarded", 0))
	var schedule: Array = DataManager.unlock_schedule()
	var target: int = awarded
	while target < schedule.size() and fought >= int(schedule[target]):
		target += 1
	if target == awarded:
		return
	for gate in range(awarded, target):
		for item_id in DataManager.bucket_items(gate + 1):
			var item: Resource = DataManager.get_item(str(item_id))
			if item == null:
				continue
			_run_end_unlocks.append({
				"type": str(item.get("item_type")),
				"id": str(item_id),
				"display_name": str(item.get("display_name")),
			})
	data["unlocks"]["item_gates_awarded"] = target


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
		2:  # ghost — beat Hive
			return wins.has("hive")
		3:  # breaker — reach deep into Veil
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

# Unlock everything: every hero, operation, boss relic, and item gate; ladder maxed.
func dev_unlock_all() -> void:
	data["unlocks"]["heroes"] = ALL_HEROES.duplicate()
	data["unlocks"]["operations"] = OPERATION_CHAIN.duplicate()
	data["unlocks"]["hero_ladder_rung"] = MAX_HERO_LADDER_RUNG
	data["unlocks"]["heroes_new"] = []
	data["unlocks"]["item_gates_awarded"] = DataManager.unlock_gate_count()
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
		# Build F: boss relics join the unified unlock screen when earned — they
		# used to unlock silently and just appear in the next Starting Directive
		# picker, so a player could earn one and never notice.
		var relic: Resource = DataManager.get_item(relic_id)
		_run_end_unlocks.append({
			"type": "boss_relic",
			"id": relic_id,
			"display_name": str(relic.get("display_name")) if relic != null else relic_id,
		})
		save()
