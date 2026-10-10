# Resolves a minimal first-pass combat loop using the rolled ability metadata.
class_name CombatManager
extends RefCounted

const FirewallFeedback := preload("res://scripts/battle/firewall_feedback.gd")
const UnitTraits := preload("res://scripts/battle/unit_traits.gd")

var _hero_states: Array = []
var _enemy_states: Array = []
var _round_log: Array = []
var _round_events: Array = []

var _active_relic_effects: Array = []  # Array of effect Dictionaries from DataManager
# Guard: true while a kill is being processed. Deaths triggered by an on-kill
# effect (Chain Reaction / Killswitch Relay / Dead Man's Charge) are enqueued on
# _kill_queue and drained iteratively so their own on-kill hooks still fire —
# they are no longer silently dropped (audit A-002). Snapshotted for the L2
# solver as "chain_reaction_active"; always false at snapshot time.
var _chain_reaction_active: bool = false
var _kill_queue: Array = []  # pending [dead_state, killer_state] pairs
# True only while Echo Matrix replays an ability's damage. During the echo, Mark
# is neither consumed nor applied, so the echo can't eat the Mark its own first
# pass just applied (audit A-074).
var _echo_pass_active: bool = false
# True only inside forecast_round: the preview dry-runs the real round on
# copies of the unit states. Writes that leave this manager (lifetime stats,
# run flags, consumable grants) are skipped; everything else runs unchanged.
var _forecast_only: bool = false
# Heroes a forecast holds back: their ability needs a target the player has not
# chosen yet. Their dice still count (hijack, enemy intents); they do not act.
var _forecast_waiting_hero_ids: Dictionary = {}
# Test seam (the `trait preview` gate): a dry run with every trait off, to
# prove a case's previewed number really depends on its trait. Never set by
# the game.
var forecast_blind_to_traits: bool = false
# Detonate bursts per attacker id, recorded during a forecast only, so the hero
# readout's Detonate number is the burst that will actually land.
var _forecast_detonates: Dictionary = {}
var _pending_protocol_grants: int = 0
var _low_hp_squad_buff_used: bool = false


# Vengeance Protocol relic: once per battle.
var _vengeance_used: bool = false
# Scavenger Manifest relic: the first kill each battle drops a consumable.
var _scavenger_drop_done: bool = false


func setup_battle(hero_units: Array, enemy_units: Array) -> void:
	_hero_states.clear()
	_enemy_states.clear()
	_pending_protocol_grants = 0
	_low_hp_squad_buff_used = false
	_vengeance_used = false
	_scavenger_drop_done = false
	_pending_protocol_drain = 0
	_battle_round = 0

	for hero in hero_units:
		_hero_states.append(_create_runtime_state(hero))

	for enemy in enemy_units:
		_enemy_states.append(_create_runtime_state(enemy, _next_enemy_instance_id(enemy)))

	# MANTLE TYRANT standing rule: its shields persist until broken and stack.
	for enemy_state in _enemy_states:
		if str(enemy_state["unit"].display_name) == BOSS_MANTLE:
			enemy_state["shields_persist"] = true
	_battle_modifier = ""
	_decoy_round_one = false


# --- Route Fork battle modifiers (pkg7.3) ---
# One flagged-route modifier can be armed per battle. Spawn-time effects fire
# here; per-hit / per-round effects read _battle_modifier at their hook.
var _battle_modifier: String = ""


func setup_battle_modifier(modifier_id: String, warded_names: Array = []) -> void:
	_battle_modifier = modifier_id
	_decoy_round_one = false
	match modifier_id:
		"hardened":
			for enemy_state in _enemy_states:
				if not bool(enemy_state["dead"]):
					_add_shield_stack(enemy_state, 8)
		"jammingField":
			for hero_state in _hero_states:
				if not bool(hero_state["dead"]):
					apply_battle_start_jam(hero_state, JAM_CAP)
		"warded":
			for enemy_state in _enemy_states:
				if not bool(enemy_state["dead"]) and warded_names.has(str(enemy_state["unit"].display_name)):
					_apply_ward(enemy_state)


func has_battle_modifier(modifier_id: String) -> bool:
	return _battle_modifier == modifier_id


# Decoy Beacon intercept (pkg7.4): enemies waste turn 1 on a decoy.
var _decoy_round_one: bool = false


func set_decoy_round_one() -> void:
	_decoy_round_one = true


# --- Boss standing rules (pkg4) ---
# Every boss has one rule active from turn 1, keyed by unit display name.
# The text below is the single source for the inspect popup and the
# battle-start line (battle_scene reads it via get_boss_standing_rule).

const BOSS_SCRAPMASTER := "Scrapmaster"
const BOSS_MATRIARCH := "Hive Matriarch"
const BOSS_OVERSEER := "Veil Overseer"
const BOSS_HIEROPHANT := "Signal Hierarch"
const BOSS_MANTLE := "Mantle Tyrant"
const SCRAP_DRONE_NAME := "Scrap Drone"
const BROOD_SPAWN_NAME := "Bloodmite"
# Burns at or past this turn count are PERMANENT (plagueProtocol): they tick
# forever and Detonate treats them as one tick's worth without consuming them
# (per Kev 2026-07-06 — resolves the old DETONATE_MAX_TURNS placeholder cap).
const PERMANENT_BURN_TURNS := 9999

# Every rule names its own SUBJECT and, where one exists, the unit that RECEIVES
# the effect. A bare "gains a firewall" read as though the allies were the ones
# being buffed; the short boss titles used here are the same ones the live combat
# log already uses ("the Overseer raises a firewall", "the Tyrant accretes its
# mantle"), so the two never disagree.
#
# READABILITY REWRITE (2026-09-03, copy only — no mechanic, number, condition or
# timing moved): each rule now leads with WHAT THE PLAYER WILL SEE HAPPEN and
# puts the cadence second. The player reads this once, in a modal, before their
# first boss fight, with no way to re-read it mid-battle, so the first clause has
# to be the observable event rather than the engine's phrasing of it.
# The "TITLE - mechanic" shape is load-bearing: OperationBriefingOverlay
# .split_runtime_rule splits on the first " - " and renders the left half as
# "<TITLE> ACTIVE" above the right half as body.
const BOSS_STANDING_RULES := {
	BOSS_SCRAPMASTER: "ASSEMBLY LINE - a Scrap Drone you already destroyed stands back up at 50% HP. The Scrapmaster rebuilds one every 2nd enemy phase, counting from its first.",
	BOSS_MATRIARCH: "THE BROOD - a new Bloodmite joins the fight. The Matriarch births one every 3 rounds.",
	BOSS_OVERSEER: "THE COURT - an ability you aim at the Overseer is negated outright. It raises that firewall on itself every round, before your heroes act, for as long as any ally lives.",
	BOSS_HIEROPHANT: "ROOT ACCESS - your squad's highest die is seized and rewritten to 3. The Hierarch does this every round.",
	BOSS_MANTLE: "ACCRETION - the Tyrant plates itself with 6 more shield and keeps every layer. It accretes every 2nd round, before your heroes act; its shields persist and stack.",
}

# BALANCE-TODO: rebuild HP 50% and brood cadence 3 are provisional. Mantle
# shield 6 every 2nd round is RULED (Cycle 4, Kev): cadence softened the wall
# more efficiently than value, and the off-round burst windows are the skill
# texture; value 6 keeps the stack identity.
const SCRAPMASTER_REBUILD_PCT := 50
const MANTLE_ROUND_SHIELD := 6
const MANTLE_SHIELD_CADENCE := 2
const BROOD_CADENCE := 3

# ── Balance-workbench tuning seam (scripts/sim/sweep.py — MEASUREMENT ONLY) ──
# Empty in every real game and in every un-swept sim run: each getter returns
# the shipped constant unless a sweep injected an override via set_tuning().
# The registry of sweepable keys + ranges lives in scripts/sim/knobs.json;
# ci_smoke proves the empty-dict path is byte-identical to the pre-seam engine.
# Do NOT use this to ship balance changes — tuned values that win a sweep get
# committed as the real constants/data, then the baseline ceremony applies.
var tuning: Dictionary = {}

## Debug-build seam for the `accrete display` gate's deliberate breaks (never
## set by the game): `asked` makes a shield grant report the amount asked for
## instead of the shield applied (the pre-2026-10-08 behaviour); `no_chip`
## drops the ACCRETE chip; `stale_chip` leaves the shield chip on its old
## number through the round; `no_line` drops the inspect line.
const ACCRETE_BREAK_ARG := "--accrete-display-break="
static var _accrete_break: String = "?"


static func accrete_display_break() -> String:
	if _accrete_break == "?":
		_accrete_break = ""
		if OS.is_debug_build():
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with(ACCRETE_BREAK_ARG):
					_accrete_break = arg.trim_prefix(ACCRETE_BREAK_ARG)
	return _accrete_break


## Debug-build seam for the `cloak ambush` gate's deliberate breaks (never set
## by the game): `no_bonus` drops the ambush multiplier; `always` pays it on
## every attack, cloaked or not; `keep_cloak` leaves the cloak up after the
## attack; `fizzle` restores the old all-cloaked fizzle; `first` always hits
## the first cloaked unit; `no_chip` drops the bonus from the cloak chip.
const CLOAK_BREAK_ARG := "--cloak-ambush-break="
static var _cloak_break: String = "?"


static func cloak_ambush_break() -> String:
	if _cloak_break == "?":
		_cloak_break = ""
		if OS.is_debug_build():
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with(CLOAK_BREAK_ARG):
					_cloak_break = arg.trim_prefix(CLOAK_BREAK_ARG)
	return _cloak_break


func set_tuning(overrides: Dictionary) -> void:
	tuning = overrides.duplicate(true)


func _tuned_int(key: String, default_value: int) -> int:
	return int(tuning.get(key, default_value)) if not tuning.is_empty() else default_value


func _tuned_float(key: String, default_value: float) -> float:
	return float(tuning.get(key, default_value)) if not tuning.is_empty() else default_value


# The seeded roll seam (set by BattleEngine._init). Every non-d20 random combat
# pick — Opening Salvo, Dead Man's Charge, the elite-summon chance — routes
# through this so the headless sim reproduces them byte-identically from a seed
# (INVARIANTS #1, determinism fence). Null only in provider-less audit unit
# tests, which fall back to the global RNG.
var roll_provider: RollProvider = null


# Uniform index in [0, size-1] from the seeded stream (see roll_provider).
func _rand_index(size: int) -> int:
	if size <= 1:
		return 0
	if roll_provider != null:
		return roll_provider.rand_index(size)
	return randi() % size


# Uniform integer in [1, 100] from the seeded stream (percentage rolls).
func _rand_pct() -> int:
	return _rand_index(100) + 1


# 1-based round counter driving the turn-cadence rules.
var _battle_round: int = 0

# This round's raw hero die faces (stashed by resolve_round) — the enemy
# freeze pick reads them to find the LOWEST revealed hero die.
var _current_raw_hero_rolls: Dictionary = {}

# The value each unit acts on this round, per side (state id -> value): the
# effective rolls resolve_round is handed, hijack copies included — exactly
# what the dice show during resolution. Freeze captures from here (G-23: freeze
# locks the number on the face, not the raw face under it).
var _acted_hero_values: Dictionary = {}
var _acted_enemy_values: Dictionary = {}

# Targeting personalities (Task 9): {enemy_id: hero_id} intent assignments for
# the current round, written in SLOT ORDER (PACK reads insertion order).
var _enemy_assignments: Dictionary = {}


# THE shared enemy-targeting entry point. Iterates enemies in slot order and,
# for every living enemy whose rolled ability carries a single-hero hostile
# component, resolves its target through TargetingPersonality (taunt override,
# cloak skip, personality + stated fallback). An already-set legal pick (the
# UI's earlier call with the same inputs) is kept and recorded, so calling
# this again at resolve time never overwrites a displayed intent.
# battle_scene calls this for the intent display; resolve_round calls it so
# the headless sim/audit shares the exact same implementation. No randi().
# `hero_values`: the value each hero die shows now (id -> value). An attack that
# freezes the lowest die picks from these; without them it falls back to the
# values stamped at the last resolve.
func assign_enemy_intents(enemy_rolls: Dictionary, dice_manager: DiceManager, hero_values: Dictionary = {}) -> void:
	_enemy_assignments.clear()
	for enemy_state in _enemy_states:
		if bool(enemy_state["dead"]):
			continue
		var roll_value: Variant = enemy_rolls.get(enemy_state["id"], null)
		if roll_value == null:
			continue
		var ability_entry: Dictionary = dice_manager.get_ability_for_roll(enemy_state["unit"], int(roll_value))
		if not _ability_targets_single_hero(ability_entry.get("raw", {})):
			continue
		if attack_freezes_lowest_die(ability_entry.get("raw", {})):
			# Never a kept pick: the lowest die can change while the player plans.
			var lowest: Dictionary = _freeze_pick_hero_lowest_die(enemy_state, {} if geode_break() == "stale" else hero_values)
			if not lowest.is_empty():
				enemy_state["selected_target_id"] = str(lowest["id"])
				enemy_state["target_display"] = str(lowest["unit"].battle_name())
				_enemy_assignments[str(enemy_state["id"])] = str(lowest["id"])
				continue
			enemy_state["selected_target_id"] = ""
		var current: Dictionary = _find_target_by_id(_hero_states, str(enemy_state.get("selected_target_id", "")))
		if not current.is_empty() and not bool(current.get("cloaked", false)):
			_enemy_assignments[str(enemy_state["id"])] = str(current["id"])
			continue
		var pick: Dictionary = TargetingPersonality.personality_pick_target(enemy_state, _hero_states, _enemy_assignments)
		if pick.is_empty():
			enemy_state["selected_target_id"] = ""
			# Every hero cloaked: a single-target attack hits one at random at
			# resolve time (G-52), and the inspect says so.
			enemy_state["target_display"] = "Random" if _attack_will_hit_at_random(ability_entry.get("raw", {}), _hero_states) else "--"
			continue
		enemy_state["selected_target_id"] = str(pick["id"])
		# Display string only — battle_name() (the callsign) so every surface
		# (cards, inspect TARGETING line) labels the hero the same way.
		enemy_state["target_display"] = str(pick["unit"].battle_name())
		_enemy_assignments[str(enemy_state["id"])] = str(pick["id"])


# Keys that carry no effect of their own: pure targeting hints, the revive
# knobs themselves, and the damage-range metadata. Anything else with a live
# value means the ability still DOES something when the revive finds no body.
const REVIVE_INERT_KEYS := {
	"revive": true, "reviveAll": true, "revivePct": true,
	"healTgt": true, "shTgt": true, "wardTgt": true,
	"dMin": true, "dMax": true, "range": true, "zone": true,
	"name": true, "eff": true, "desc": true, "band": true,
}


# True when EVERY effect this ability carries is gated on a target that does
# not exist, so resolving it changes nothing at all: a PURE revive (revive or
# reviveAll and zero of anything else) with no downed hero. Resuscitate and
# Mass Revival carry an `else` fallback heal (fallbackHeal, a live key), so
# they always act and never fizzle. Deliberately fail-safe — an unrecognized
# live key means "still does something", so a new ability announces (today's
# behavior) until it is understood, rather than going silently missing.
func _ability_fizzles_for_lack_of_target(ability_entry: Dictionary) -> bool:
	var raw: Dictionary = ability_entry.get("raw", {})
	if not (bool(raw.get("revive", false)) or bool(raw.get("reviveAll", false))):
		return false
	for key in raw.keys():
		if REVIVE_INERT_KEYS.has(str(key)):
			continue
		var value: Variant = raw[key]
		if value is bool and bool(value):
			return false
		if (value is int or value is float) and float(value) != 0.0:
			return false
		if value is String and str(value) != "":
			return false
	# reviveAll needs any downed ally; a single-target revive with no pick
	# falls back to the first dead hero, so "no dead hero at all" is the exact
	# legality test for both.
	for state_variant in _hero_states:
		if bool((state_variant as Dictionary).get("dead", false)):
			return false
	return true


# A single-target attack that also freezes one die (Geode Panther's Calcifying
# Bite and Stonefang Pounce). It attacks the hero it freezes: the one with the
# lowest die (G-61, Kev 2026-10-09). Before, the freeze went to the lowest die
# and the hit went wherever the unit's targeting personality sent it.
static func attack_freezes_lowest_die(raw: Dictionary) -> bool:
	if geode_break() == "split":
		return false
	return ability_is_single_target_attack(raw) and int(raw.get("freezeEnemyDice", 0)) > 0


# Deliberate breaks for the `geode targeting` gate (never set by the game):
#   split  the hit follows the targeting personality again, apart from the freeze
#   stale  the planning pick reads last round's dice
const GEODE_BREAK_ARG := "--geode-break="
static var _geode_break: String = "?"


static func geode_break() -> String:
	if _geode_break == "?":
		_geode_break = ""
		if OS.is_debug_build():
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with(GEODE_BREAK_ARG):
					_geode_break = arg.trim_prefix(GEODE_BREAK_ARG)
	return _geode_break


# A single-target attack: it deals damage to one unit. The all-cloaked fallback
# (G-52) applies to these and to nothing else.
static func ability_is_single_target_attack(raw: Dictionary) -> bool:
	return int(raw.get("dmg", 0)) > 0 and not bool(raw.get("blastAll", false))


# True when a single-target attack has only cloaked units to hit, so the
# all-cloaked fallback will pick one at random.
func _attack_will_hit_at_random(raw: Dictionary, states: Array) -> bool:
	if not ability_is_single_target_attack(raw) or cloak_ambush_break() == "fizzle":
		return false
	var any_living: bool = false
	for state_variant in states:
		var state: Dictionary = state_variant
		if bool(state.get("dead", false)):
			continue
		if not bool(state.get("cloaked", false)):
			return false
		any_living = true
	return any_living


# True when the ability needs a single hero pick (AoE and support don't).
func _ability_targets_single_hero(raw: Dictionary) -> bool:
	if int(raw.get("dmg", 0)) > 0 and not bool(raw.get("blastAll", false)):
		return true
	return (
		int(raw.get("burn", 0)) > 0
		or int(raw.get("rfm", 0)) > 0
		or int(raw.get("freezeEnemyDice", 0)) > 0
		or bool(raw.get("jam", false))
		or bool(raw.get("rewrite", false))
		or bool(raw.get("taunt", false))
	)


# Resolve-time target for every hostile component of one enemy ability.
# Taunt overrides everything (even an assigned pick — a hero may start
# taunting after intents were assigned); a still-legal assigned pick is
# honored; a dead/cloaked pick falls through to the personality's stated
# fallback via the same choke-point.
func _resolve_enemy_hero_target(enemy_state: Dictionary) -> Dictionary:
	# Single-target taunt (G-4): only the LURED enemy redirects to its taunter.
	var lurer: Dictionary = _lurer_for_enemy(enemy_state)
	if not lurer.is_empty():
		return lurer
	var taunter: Dictionary = _get_taunting_hero_state()
	if not taunter.is_empty():
		return taunter
	var picked: Dictionary = _find_target_by_id(_hero_states, str(enemy_state.get("selected_target_id", "")))
	if not picked.is_empty() and not bool(picked.get("cloaked", false)):
		return picked
	return TargetingPersonality.personality_pick_target(enemy_state, _hero_states, _enemy_assignments)


static func get_boss_standing_rule(display_name: String) -> String:
	return str(BOSS_STANDING_RULES.get(display_name, ""))


# Round-start rules (before the hero phase, so they matter this round):
# Overseer's Firewall and the Mantle Tyrant's accreted plate.
func _apply_boss_round_start_rules() -> void:
	for enemy_state in _enemy_states:
		if bool(enemy_state["dead"]):
			continue
		match str(enemy_state["unit"].display_name):
			BOSS_OVERSEER:
				var court_stands: bool = false
				for ally_state in _enemy_states:
					if ally_state != enemy_state and not bool(ally_state["dead"]):
						court_stands = true
						break
				if court_stands and not bool(enemy_state.get("warded", false)):
					_log("The Court stands - the Overseer raises a firewall.")
					_apply_ward(enemy_state)
			BOSS_MANTLE:
				# ACCRETION (Cycle-4 ruling): fires every MANTLE_SHIELD_CADENCE-th
				# round from the first. Both knobs stay sweepable through the
				# tuning seam (defaults = the shipped rule).
				var mantle_cadence: int = _tuned_int("mantle_shield_cadence", MANTLE_SHIELD_CADENCE)
				var mantle_fires: bool = true
				if mantle_cadence > 1:
					var mantle_rounds: int = int(enemy_state.get("mantle_rounds", 0)) + 1
					enemy_state["mantle_rounds"] = mantle_rounds
					mantle_fires = (mantle_rounds - 1) % mantle_cadence == 0
				if mantle_fires:
					if _apply_accrete(enemy_state, _tuned_int("mantle_round_shield", MANTLE_ROUND_SHIELD), true) > 0:
						# The keyword primer says "each of its turns"; this rule's
						# cadence differs, so it does not teach that line.
						(_round_events.back() as Dictionary)["standing_rule"] = true


# Enemy-phase rules (turn-cadence actions): Assembly Line rebuild, Brood
# spawn, and the Hierarch's Root Access rewrite of the squad's highest die.
func _apply_boss_enemy_phase_rules(hero_rolls: Dictionary) -> void:
	for enemy_state in _enemy_states:
		if bool(enemy_state["dead"]):
			continue
		match str(enemy_state["unit"].display_name):
			BOSS_SCRAPMASTER:
				# ASSEMBLY LINE fires every 2nd enemy phase COUNTED FROM FIRST
				# ACTIVATION (per Kev 2026-07-06, DECISIONS_RESOLVED #5 —
				# supersedes the even-numbered-rounds reading). The boss's first
				# live enemy phase is phase 1; rebuilds land on phases 2, 4, 6…
				if not enemy_state.has("assembly_line_first_round"):
					enemy_state["assembly_line_first_round"] = _battle_round
				if (_battle_round - int(enemy_state["assembly_line_first_round"])) % 2 == 1:
					for drone_state in _enemy_states:
						if str(drone_state["unit"].display_name) == SCRAP_DRONE_NAME and bool(drone_state["dead"]):
							_log("ASSEMBLY LINE - the Scrapmaster rebuilds a Scrap Drone!")
							_revive_state(drone_state, _tuned_int("scrapmaster_rebuild_pct", SCRAPMASTER_REBUILD_PCT))
							drone_state["summoned"] = true  # Rebuilt reinforcement; normal kill rewards apply.
							break
			BOSS_MATRIARCH:
				if _battle_round % maxi(_tuned_int("brood_cadence", BROOD_CADENCE), 1) == 0 and _count_living_enemies() < GameState.SQUAD_UNIT_LIMIT:
					_log("THE BROOD - the Matriarch births a Bloodmite!")
					_round_events.append({
						"type": "summon",
						"amount": 0,
						"side": "enemy",
						"target_name": str(enemy_state["unit"].display_name),
						"summon_name": BROOD_SPAWN_NAME,
					})
			BOSS_HIEROPHANT:
				var highest_roll: int = 0
				var highest_hero: Dictionary = {}
				for hero_state in _hero_states:
					if bool(hero_state["dead"]):
						continue
					var hero_roll: int = int(hero_rolls.get(hero_state["id"], 0))
					if hero_roll > highest_roll:
						highest_roll = hero_roll
						highest_hero = hero_state
				if not highest_hero.is_empty():
					_log("ROOT ACCESS - the Hierarch seizes the squad's highest die.")
					apply_rewrite_to_state(highest_hero, true)


func get_hero_states() -> Array:
	return _hero_states


func get_enemy_states() -> Array:
	return _enemy_states


# --- Relic setup and helpers ---

func setup_relics(relic_ids: Array) -> void:
	_active_relic_effects.clear()
	for relic_id in relic_ids:
		var item: ItemData = DataManager.get_item(str(relic_id)) as ItemData
		if item != null and item.effect != null:
			_active_relic_effects.append(item.effect.duplicate())


func has_relic(effect_type: String) -> bool:
	for eff in _active_relic_effects:
		if str(eff.get("type", "")) == effect_type:
			return true
	return false


func _get_relic_value(effect_type: String, key: String, default_val) -> Variant:
	for eff in _active_relic_effects:
		if str(eff.get("type", "")) == effect_type:
			return eff.get(key, default_val)
	return default_val


func get_relic_value(effect_type: String, key: String, default_val) -> Variant:
	return _get_relic_value(effect_type, key, default_val)


# --- Gear setup ---

func setup_gear(gear_by_unit: Dictionary) -> void:
	# gear_by_unit: { unit_id: Array[item_id_string] }
	for hero_state in _hero_states:
		var unit_id: String = str(hero_state["id"])
		var gear_ids: Array = gear_by_unit.get(unit_id, [])
		for gear_id in gear_ids:
			var item: ItemData = DataManager.get_item(str(gear_id)) as ItemData
			if item == null or item.effect == null:
				continue
			_apply_gear_passive(hero_state, item.effect)


func _apply_gear_passive(hero_state: Dictionary, effect: Dictionary) -> void:
	var effect_type: String = str(effect.get("type", ""))
	match effect_type:
		"rollBonus":
			hero_state["perm_roll_buff"] = int(hero_state.get("perm_roll_buff", 0)) + int(effect.get("amount", 0))
		"burnDmgBonus":
			hero_state["gear_burn_bonus"] = int(hero_state.get("gear_burn_bonus", 0)) + int(effect.get("amount", 0))
		"dmgReduction":
			hero_state["gear_dmg_reduction"] = int(hero_state.get("gear_dmg_reduction", 0)) + int(effect.get("amount", 0))
		"surviveOnce":
			hero_state["gear_survive_once"] = true
			hero_state["gear_survive_once_used"] = false
		"firstAbilityDmgBonus":
			hero_state["gear_first_dmg_bonus"] = int(hero_state.get("gear_first_dmg_bonus", 0)) + int(effect.get("amount", 0))
			hero_state["gear_first_dmg_fired"] = false
		"healOnKill":
			hero_state["gear_heal_on_kill"] = int(hero_state.get("gear_heal_on_kill", 0)) + int(effect.get("amount", 0))
		"protocolOnBattleStart":
			hero_state["gear_protocol_on_start"] = int(hero_state.get("gear_protocol_on_start", 0)) + int(effect.get("amount", 0))
		"lifesteal":
			hero_state["gear_lifesteal_pct"] = int(hero_state.get("gear_lifesteal_pct", 0)) + int(effect.get("amount", 0))
		"firstAbilityEcho":
			hero_state["gear_first_ability_echo"] = true
			hero_state["gear_first_ability_echo_used"] = false
		"shieldPierce":
			hero_state["gear_shield_pierce"] = int(hero_state.get("gear_shield_pierce", 0)) + int(effect.get("amount", 0))
		"healShieldBonus":
			hero_state["gear_heal_shield_bonus"] = int(hero_state.get("gear_heal_shield_bonus", 0)) + int(effect.get("amount", 0))
		"protocolOnKill":
			hero_state["gear_protocol_on_kill"] = int(hero_state.get("gear_protocol_on_kill", 0)) + int(effect.get("amount", 0))
		"protocolOnKillAny":
			hero_state["gear_protocol_on_kill_any"] = int(hero_state.get("gear_protocol_on_kill_any", 0)) + int(effect.get("amount", 0))
		"detonateBonus":
			hero_state["gear_detonate_bonus"] = true
		"burnImmediateTick":
			hero_state["gear_burn_immediate"] = true
		"protocolOnDieTamper":
			hero_state["gear_mirror_plate"] = int(hero_state.get("gear_mirror_plate", 0)) + int(effect.get("amount", 2))
		"tauntAbove50":
			hero_state["gear_anchor_taunt"] = true
		"deathDamageAll":
			hero_state["gear_death_damage_all"] = int(hero_state.get("gear_death_damage_all", 0)) + int(effect.get("amount", 12))
		"protocolOnNat20":
			# Overload Capacitor: +N Protocol when this hero resolves a 20 (any way
			# the die reached 20 — ruling NK-02). Amount read from data (fixes the
			# old hardcoded +2, audit A-016).
			hero_state["gear_protocol_on_20"] = int(hero_state.get("gear_protocol_on_20", 0)) + int(effect.get("amount", 2))
		"rollBonusNat20Protocol":
			# Cycle-3 Predator Lens candidate (Kev reprice list): flat roll bonus
			# PLUS Protocol on a resolved 20 — differentiates the legendary from
			# Neural Splice by rider, not a fourth flat point. Ships inert until
			# the Stage-2-approved bake points predator_lens at it.
			hero_state["perm_roll_buff"] = int(hero_state.get("perm_roll_buff", 0)) + int(effect.get("amount", 0))
			hero_state["gear_protocol_on_20"] = int(hero_state.get("gear_protocol_on_20", 0)) + int(effect.get("protocol", 1))


# --- Battle-start relic effects ---

func apply_battle_start_relic_effects(battle_index: int) -> void:
	# Opening Salvo: a random enemy loses 50% max HP; a random hero loses 20%.
	if has_relic("battleStartHalfHp"):
		var living_enemies = _enemy_states.filter(func(e): return not e["dead"])
		var living_heroes = _hero_states.filter(func(h): return not h["dead"])
		if not living_enemies.is_empty():
			var target_enemy = living_enemies[_rand_index(living_enemies.size())]
			var dmg = int(target_enemy["max_hp"]) / 2
			_damage_state(target_enemy, dmg)
			_log("Opening Salvo: %s takes %d damage!" % [target_enemy["unit"].display_name, dmg])
		if not living_heroes.is_empty():
			var target_hero = living_heroes[_rand_index(living_heroes.size())]
			var dmg = int(target_hero["max_hp"]) / 5
			_damage_state(target_hero, dmg)
			_log("Opening Salvo: %s takes %d damage!" % [target_hero["unit"].display_name, dmg])

	# Static Field: enemy dice are Jammed (cap 10) on turn 1 of every battle.
	if has_relic("battleStartJamEnemies"):
		for jam_state in _enemy_states:
			if not jam_state["dead"]:
				apply_battle_start_jam(jam_state)

	# plagueProtocol: all enemies start with 3 burn
	if has_relic("enemyBurnPermanent"):
		var burn_amt = int(_get_relic_value("enemyBurnPermanent", "amount", 3))
		for enemy_state in _enemy_states:
			if not enemy_state["dead"]:
				_apply_burn(enemy_state, burn_amt, PERMANENT_BURN_TURNS)
				_log("Caustic Disperser: %s starts with %d burn." % [enemy_state["unit"].display_name, burn_amt])

	# signalJam: all enemies start with permanent -2 RFE
	if has_relic("enemyStartRfe"):
		var rfe_amt = int(_get_relic_value("enemyStartRfe", "amount", 2))
		for enemy_state in _enemy_states:
			if not enemy_state["dead"]:
				enemy_state["perm_rfe"] = int(enemy_state.get("perm_rfe", 0)) + rfe_amt
				_log("Signal Interference: %s permanently at -%d roll." % [enemy_state["unit"].display_name, rfe_amt])

	# coordinatedStrike: all heroes start with permanent +2 roll buff
	if has_relic("heroStartRollBuff"):
		var buff_amt = int(_get_relic_value("heroStartRollBuff", "amount", 2))
		for hero_state in _hero_states:
			if not hero_state["dead"]:
				hero_state["perm_roll_buff"] = int(hero_state.get("perm_roll_buff", 0)) + buff_amt
				_log("Coordinated Strike: %s permanently at +%d roll." % [hero_state["unit"].display_name, buff_amt])

	# entropyLeak: battles 6+, enemies spawn at 85% HP.
	if has_relic("enemyHpEscalation"):
		var from_battle: int = int(_get_relic_value("enemyHpEscalation", "fromBattle", 6))
		var hp_pct: int = int(_get_relic_value("enemyHpEscalation", "hpPct", 85))
		if battle_index + 1 >= from_battle:
			for enemy_state in _enemy_states:
				var spawn_hp: int = maxi(1, int(enemy_state["max_hp"]) * hp_pct / 100)
				enemy_state["current_hp"] = mini(int(enemy_state["current_hp"]), spawn_hp)
				_log("Attrition Field: %s spawns at %d%% HP." % [enemy_state["unit"].display_name, hp_pct])


# --- Battle-start gear effects ---

func apply_battle_start_gear_effects() -> void:
	for hero_state in _hero_states:
		if hero_state["dead"]:
			continue
		# Entrench directive: open every battle dug in behind shields.
		if _has_directive(hero_state, "battleStartShieldSelf"):
			_add_shield_stack(hero_state, _directive_value(hero_state, "amount", 10))
			_log("Entrench: %s starts dug in." % hero_state["unit"].display_name)
		var gear_ids: Array = GameState.gear_by_unit.get(str(hero_state["id"]), [])
		for gear_id in gear_ids:
			var item: ItemData = DataManager.get_item(str(gear_id)) as ItemData
			if item == null or item.effect == null:
				continue
			var effect_type: String = str(item.effect.get("type", ""))
			match effect_type:
				"battleStartShield":
					_add_shield_stack(hero_state, int(item.effect.get("amount", 0)))
					_log("%s: Combat Plating grants %d shield." % [hero_state["unit"].display_name, int(item.effect.get("amount", 0))])
				"battleStartCloak":
					hero_state["cloaked"] = true
					_log("%s starts battle cloaked." % hero_state["unit"].display_name)
				"battleStartCloakRoll":
					hero_state["cloaked"] = true
					var cloak_roll: int = int(item.effect.get("rollAmount", 0))
					if cloak_roll > 0:
						hero_state["perm_roll_buff"] = int(hero_state.get("perm_roll_buff", 0)) + cloak_roll
					_log("%s starts battle cloaked with +%d roll." % [hero_state["unit"].display_name, cloak_roll])
				"maxHpBonus":
					var bonus: int = int(item.effect.get("amount", 0))
					hero_state["max_hp"] = int(hero_state["max_hp"]) + bonus
					hero_state["current_hp"] = int(hero_state["current_hp"]) + bonus
					_log("%s: Stim Injector +%d max HP." % [hero_state["unit"].display_name, bonus])
				"battleStartMark":
					# Targeting Optic: battles start with this unit's first
					# target Marked — mark the first living enemy.
					var optic_target: Dictionary = _first_living_state(_enemy_states)
					if not optic_target.is_empty():
						_apply_mark(optic_target)
						_log("%s: Targeting Optic paints %s." % [hero_state["unit"].display_name, optic_target["unit"].display_name])


# --- Per-enemy-turn relic effects ---

func apply_enemy_turn_start_relic_effects() -> void:
	# bulwarkAura: all heroes gain 3 shield
	if has_relic("heroShieldPerTurn"):
		var amt = int(_get_relic_value("heroShieldPerTurn", "amount", 3))
		for hero_state in _hero_states:
			if not hero_state["dead"]:
				_add_shield_stack(hero_state, amt)

	# naniteField: all heroes heal 3 HP
	if has_relic("heroHealPerTurn"):
		var amt = int(_get_relic_value("heroHealPerTurn", "amount", 3))
		for hero_state in _hero_states:
			if not hero_state["dead"]:
				_heal_state(hero_state, amt)

	# gravityWell: all living enemies take 2 damage
	if has_relic("auraEnemyDmg"):
		var amt = int(_get_relic_value("auraEnemyDmg", "amount", 2))
		for enemy_state in _enemy_states:
			if not enemy_state["dead"]:
				_damage_state(enemy_state, amt)


# --- Damage multiplier helpers ---

func _get_hero_dmg_mult() -> float:
	return float(_get_relic_value("heroDmgMult", "mult", 1.0))


func _get_enemy_dmg_mult() -> float:
	return float(_get_relic_value("enemyDmgMult", "mult", 1.0))


# --- burn bonus helper ---

func _get_total_burn_bonus() -> int:
	var max_bonus: int = 0
	for h in _hero_states:
		if not h["dead"]:
			max_bonus = maxi(max_bonus, int(h.get("gear_burn_bonus", 0)))
	return max_bonus


# PUBLIC: Returns the effective roll for a state factoring in RFE stacks and roll buff.
# battle_scene passes nudge on top of this, so nudge is NOT included here.
func get_effective_roll(state: Dictionary, raw_roll: int, include_rewrite: bool = true) -> int:
	# Rewrite: the next roll is SET to 3 — trumps every other modifier.
	# include_rewrite false = the faces a die PRINTS before its throw: Rewrite is
	# applied after landing (G-43), so the die rolls naturally and then tips to 3.
	if include_rewrite and bool(state.get("rewrite_pending", false)):
		return REWRITE_VALUE
	var mods: Dictionary = get_roll_modifier_totals(state)
	var effective: int = clampi(raw_roll + int(mods["roll_buff"]) - int(mods["roll_rfe"]), 1, 20)
	# Jam: the unit's next roll is capped (default 10); cleared at that
	# round's end tick.
	var jam_cap: int = int(state.get("jam_cap", 0))
	if jam_cap > 0:
		effective = mini(effective, jam_cap)
	return effective


# PUBLIC: net roll-modifier totals — THE sum get_effective_roll applies.
func get_roll_modifier_totals(state: Dictionary) -> Dictionary:
	return roll_modifier_totals_of(state)


# Static so pure display code (the card's ±Roll chip) reads the same sum
# without a manager instance — one source, no hand-kept mirror.
static func roll_modifier_totals_of(state: Dictionary) -> Dictionary:
	var rfe: int = int(state.get("perm_rfe", 0))
	for stack in state.get("rfe_stacks", []):
		rfe += int(stack["amt"])
	var buff: int = int(state.get("perm_roll_buff", 0))
	for stack in state.get("roll_buff_stacks", []):
		buff += int(stack["amt"])
	return {"roll_rfe": rfe, "roll_buff": buff}


func take_pending_protocol_grants() -> int:
	var granted: int = _pending_protocol_grants
	_pending_protocol_grants = 0
	return granted


# Siphon (enemy-only): drained Protocol accumulated during the enemy phase;
# battle_scene applies it to the pool (floor 0) after resolution.
var _pending_protocol_drain: int = 0


# ── L2 speculative lookahead (balance-sim Package D) ──────────────────────────
# The combat half of the state that BattleState.duplicate_for_search() doesn't
# cover (unit dicts + per-round bookkeeping). The L2 solver snapshots before a
# round, resolves candidate lines on the live manager, scores, restores, and
# applies the best. Dictionary/Array.duplicate(true) deep-copies nested
# dicts/arrays but keeps the shared "unit" Resource ref — exactly what we want.
func snapshot_state() -> Dictionary:
	return {
		"hero_states": _hero_states.map(func(s): return (s as Dictionary).duplicate(true)),
		"enemy_states": _enemy_states.map(func(s): return (s as Dictionary).duplicate(true)),
		"battle_round": _battle_round,
		"pending_protocol_grants": _pending_protocol_grants,
		"pending_protocol_drain": _pending_protocol_drain,
		"chain_reaction_active": _chain_reaction_active,
		"low_hp_squad_buff_used": _low_hp_squad_buff_used,
		"vengeance_used": _vengeance_used,
		"scavenger_drop_done": _scavenger_drop_done,
		"decoy_round_one": _decoy_round_one,
		"ward_blocked_ids": _ability_ward_blocked_ids.duplicate(true),
		"rider_target_ids": _ability_rider_target_ids.duplicate(true),
		"spike_carrier_ids": _ability_spike_carrier_ids.duplicate(true),
	}


func restore_state(snap: Dictionary) -> void:
	_hero_states = (snap["hero_states"] as Array).map(func(s): return (s as Dictionary).duplicate(true))
	_enemy_states = (snap["enemy_states"] as Array).map(func(s): return (s as Dictionary).duplicate(true))
	_battle_round = int(snap["battle_round"])
	_pending_protocol_grants = int(snap["pending_protocol_grants"])
	_pending_protocol_drain = int(snap["pending_protocol_drain"])
	_chain_reaction_active = bool(snap["chain_reaction_active"])
	_low_hp_squad_buff_used = bool(snap["low_hp_squad_buff_used"])
	_vengeance_used = bool(snap["vengeance_used"])
	_scavenger_drop_done = bool(snap["scavenger_drop_done"])
	_decoy_round_one = bool(snap["decoy_round_one"])
	_ability_ward_blocked_ids = (snap["ward_blocked_ids"] as Dictionary).duplicate(true)
	_ability_ward_block_notes.clear()
	_ability_rider_target_ids = (snap.get("rider_target_ids", {}) as Dictionary).duplicate(true)
	_ability_spike_carrier_ids = (snap.get("spike_carrier_ids", {}) as Dictionary).duplicate(true)
	_round_log.clear()
	_round_events.clear()


# ── End-of-round battle checkpoint (save system, 2026-09-21) ──────────────────
# The L2 snapshot plus the one battle-long field it leaves out: the route-fork
# modifier, whose spawn-time effects already live in the unit states and whose
# per-hit/per-round hooks read _battle_modifier. Restoring sets it WITHOUT
# re-running setup_battle_modifier (that would re-apply its spawn effects).
# "unit" Resource refs are the caller's to serialize (BattleCheckpoint).
func export_checkpoint() -> Dictionary:
	var snap: Dictionary = snapshot_state()
	snap["battle_modifier"] = _battle_modifier
	return snap


func import_checkpoint(snap: Dictionary) -> void:
	restore_state(snap)
	_battle_modifier = str(snap.get("battle_modifier", ""))
	_kill_queue.clear()


# Set the hero firing order by CAST STAMPS (player-chosen cast order; also the
# L2 order-search entry point). `ordered_ids` gets stamps 1..N; ids not listed
# are cleared to unstamped and resolve after the stamped ones in squad order.
# This REPLACED the old array reorder: _hero_states must stay in squad order —
# reordering it leaked the firing order into enemy SYSTEMATIC (slot-order)
# targeting and every other squad-order iteration (battle-start effects,
# income, XP), which the live scene never did.
func set_hero_order(ordered_ids: Array) -> void:
	var listed: Dictionary = {}
	var stamp: int = 0
	for id in ordered_ids:
		stamp += 1
		listed[str(id)] = stamp
	for state_variant in _hero_states:
		var state: Dictionary = state_variant
		state["cast_stamp"] = int(listed.get(str(state["id"]), 0))


# Hero states in firing order: stamped heroes ascending, then unstamped in
# squad order. A LIVING, ROLLED hero left unstamped while others are stamped is
# the defensive case (rule: it appends in squad order and warns) — a fully
# unstamped squad is the legacy/auto path and resolves in squad order silently.
func _hero_states_in_cast_order(hero_rolls: Dictionary) -> Array:
	var stamped: Array = []
	var unstamped: Array = []
	for state_variant in _hero_states:
		var state: Dictionary = state_variant
		if int(state.get("cast_stamp", 0)) > 0:
			stamped.append(state)
		else:
			unstamped.append(state)
	if stamped.is_empty():
		return _hero_states
	stamped.sort_custom(func(a, b): return int(a["cast_stamp"]) < int(b["cast_stamp"]))
	for state_variant in unstamped:
		var state: Dictionary = state_variant
		# A hero a forecast holds back has no stamp by design: it has no target yet.
		if not bool(state.get("dead", false)) and hero_rolls.has(str(state["id"])) 				and not _forecast_waiting_hero_ids.has(str(state["id"])):
			push_warning("[CAST_ORDER] %s reached resolution unstamped - appending in squad order." % str(state["unit"].display_name))
	return stamped + unstamped


# The order heroes actually fired in last round (living, rolled ids only) —
# telemetry + battle-log source.
var _last_cast_order: Array = []


func get_last_cast_order() -> Array:
	return _last_cast_order.duplicate()


func take_pending_protocol_drain() -> int:
	var drained: int = _pending_protocol_drain
	_pending_protocol_drain = 0
	return drained


# Tectonic Charge (G-38): true while round 1 of a battle is being planned - the
# heroes hold (no hero dice are thrown, no hero acts). Read before the round
# resolves (_battle_round counts resolved rounds).
func heroes_hold_this_round() -> bool:
	return has_relic("heroesHoldRoundOne") and _battle_round == 0


func resolve_round(
	hero_rolls: Dictionary,
	enemy_rolls: Dictionary,
	dice_manager: DiceManager,
	raw_enemy_rolls: Dictionary = {},
	raw_hero_rolls: Dictionary = {}
) -> Dictionary:
	_round_log.clear()
	_round_events.clear()
	var heroes_held: bool = _open_round()

	_resolve_hero_phase(hero_rolls, enemy_rolls, dice_manager, raw_hero_rolls)

	if _all_states_dead(_enemy_states):
		_log("All enemies are down.")
		return {"result": "victory", "log": _round_log.duplicate(), "events": _round_events.duplicate(true)}

	_resolve_enemy_phase(hero_rolls, enemy_rolls, dice_manager, raw_enemy_rolls)

	_tick_end_of_round_states()

	# Tectonic Charge (G-38): the hold ends with round 1; every hero (a fallen
	# one too, for when it is revived) rolls with +N for the rest of the battle.
	# A permanent roll buff, so the faces print it and the roll chip shows it.
	if heroes_held:
		var charge: int = int(_get_relic_value("heroesHoldRoundOne", "amount", 3))
		for charged_state in _hero_states:
			charged_state["perm_roll_buff"] = int(charged_state.get("perm_roll_buff", 0)) + charge
		_log("TECTONIC CHARGE - the squad is charged: +%d to every hero roll." % charge)

	if _all_states_dead(_enemy_states):
		_log("All enemies are down.")
		return {"result": "victory", "log": _round_log.duplicate(), "events": _round_events.duplicate(true)}

	if _all_states_dead(_hero_states):
		_log("The squad has been wiped out.")
		return {"result": "defeat", "log": _round_log.duplicate(), "events": _round_events.duplicate(true)}

	return {"result": "ongoing", "log": _round_log.duplicate(), "events": _round_events.duplicate(true)}


# The round opens: the counter moves and a Tectonic Charge hold shields the
# squad. True when the heroes hold this round. Shared by resolve_round and
# forecast_round.
func _open_round() -> bool:
	var heroes_held: bool = heroes_hold_this_round()
	_battle_round += 1
	if heroes_held:
		_log("TECTONIC CHARGE - your heroes hold this round.")
		# While they hold, every living hero is shielded for this round's enemy
		# phase (an ordinary one-round shield, gone at the round-end tick).
		var hold_shield: int = int(_get_relic_value("heroesHoldRoundOne", "shield", 0))
		if hold_shield > 0:
			for held_state in _hero_states:
				if not bool(held_state["dead"]):
					_add_shield_stack(held_state, hold_shield)
			_log("TECTONIC CHARGE - every hero gains %d shield while holding." % hold_shield)
	return heroes_held


# The enemy phase: turn-start relics, Accrete, the boss cadence rules, then
# every living enemy in reverse slot order. Shared by resolve_round and
# forecast_round, so the preview runs the same code.
func _resolve_enemy_phase(
	hero_rolls: Dictionary,
	enemy_rolls: Dictionary,
	dice_manager: DiceManager,
	raw_enemy_rolls: Dictionary
) -> void:
	# Apply per-enemy-turn relic effects before enemies act
	apply_enemy_turn_start_relic_effects()

	# Accretion: units with accrete gain N shield at the start of their turn;
	# the shield survives the imminent tick to cover the next hero phase.
	var accrete_beat_open: bool = false
	for accrete_state in _enemy_states:
		if not accrete_state["dead"] and int(accrete_state.get("accrete", 0)) > 0:
			if _apply_accrete(accrete_state, int(accrete_state["accrete"]), not accrete_beat_open) > 0:
				accrete_beat_open = true

	# Boss turn-cadence standing rules (rebuild / brood / root access).
	_apply_boss_enemy_phase_rules(hero_rolls)

	# Regenerative route modifier: enemies heal each round.
	if _battle_modifier == "regenerative":
		for regen_state in _enemy_states:
			if not regen_state["dead"]:
				_heal_state(regen_state, 3)

	var ordered_enemy_states: Array = _enemy_states.duplicate()
	ordered_enemy_states.reverse()
	for enemy_state in ordered_enemy_states:
		if enemy_state["dead"]:
			continue
		# Decoy Beacon: the whole enemy line wastes turn 1 on the decoy.
		if _decoy_round_one and _battle_round == 1:
			_log("%s wastes its turn on the decoy." % enemy_state["unit"].display_name)
			if _take_rampage(enemy_state):
				_expire_rampage(enemy_state)
			continue
		var enemy_roll_value: Variant = enemy_rolls.get(enemy_state["id"], null)
		if enemy_roll_value == null:
			continue
		# Freeze = repeat: the crusted die kept its face; the enemy acts again
		# on the same result (its target re-picked by personality this round).
		if bool(enemy_state.get("die_freeze_repeat_this_round", false)):
			_log("%s's frozen die repeats its %d." % [enemy_state["unit"].display_name, int(enemy_roll_value)])
		var enemy_ability_entry: Dictionary = dice_manager.get_ability_for_roll(enemy_state["unit"], int(enemy_roll_value))
		_log("%s uses %s." % [enemy_state["unit"].display_name, str(enemy_ability_entry.get("ability_name", "Unknown"))])
		_emit_action_event(enemy_state, "enemy", str(enemy_ability_entry.get("ability_name", "Unknown")), str(enemy_ability_entry.get("zone", "")))
		var enemy_raw_roll: int = int(raw_enemy_rolls.get(enemy_state["id"], enemy_roll_value))
		_apply_enemy_ability(enemy_state, enemy_ability_entry, enemy_raw_roll)


# The round up to the end of the hero phase: round-start boss rules, hijack,
# acted-value stamps, enemy intents, then every hero in cast order. Shared by
# resolve_round and forecast_round, so the preview runs the same code.
func _resolve_hero_phase(
	hero_rolls: Dictionary,
	enemy_rolls: Dictionary,
	dice_manager: DiceManager,
	raw_hero_rolls: Dictionary
) -> void:
	# Raw hero faces for this round — the enemy freeze pick (lowest revealed
	# die, deterministic) reads these; falls back to last_die_value.
	_current_raw_hero_rolls = raw_hero_rolls.duplicate()

	# Boss standing rules that must be live before the hero phase.
	_apply_boss_round_start_rules()

	# Hijack: enemies with a pending hijack copy the heroes' current highest
	# die for this round's action (effective roll override; raw kept). A frozen
	# die is immune to Hijack — its crusted face repeats instead.
	var highest_hero_roll: int = 0
	for roll_variant in hero_rolls.values():
		highest_hero_roll = maxi(highest_hero_roll, int(roll_variant))
	if highest_hero_roll > 0:
		for enemy_state in _enemy_states:
			if not enemy_state["dead"] and bool(enemy_state.get("hijack_pending", false)):
				if int(enemy_state.get("die_freeze_turns", 0)) > 0:
					_log("%s's die is frozen solid - the hijack waits for the thaw." % enemy_state["unit"].display_name)
					continue
				enemy_rolls[str(enemy_state["id"])] = highest_hero_roll
				_log("%s HIJACKS the squad's highest die (%d)!" % [enemy_state["unit"].display_name, highest_hero_roll])
				_emit_event(enemy_state, "hijack", highest_hero_roll, "enemy")

	stamp_acted_values(hero_rolls, enemy_rolls)

	# Targeting personalities: fill enemy intents (slot order) before the hero
	# phase. In UI play battle_scene already assigned them with the same
	# choke-point, so this pass just re-records the picks; headless sim/audit
	# runs get their assignment here.
	assign_enemy_intents(enemy_rolls, dice_manager, hero_rolls)

	# Player-chosen cast order: stamped heroes fire in ascending stamp order,
	# unstamped append in squad order. The array itself stays in squad order.
	var cast_ordered: Array = _hero_states_in_cast_order(hero_rolls)
	_last_cast_order = []
	for hero_state_variant in cast_ordered:
		var hero_state: Dictionary = hero_state_variant
		if not bool(hero_state.get("dead", false)) and hero_rolls.has(str(hero_state["id"])) \
				and not _forecast_waiting_hero_ids.has(str(hero_state["id"])):
			_last_cast_order.append(str(hero_state["id"]))
	if _last_cast_order.size() > 1:
		var order_names: Array = []
		for hid in _last_cast_order:
			var ordered_state: Dictionary = _find_target_by_id(_hero_states, str(hid))
			if not ordered_state.is_empty():
				order_names.append(str(ordered_state["unit"].display_name))
		_log("Cast order: %s." % " -> ".join(order_names))
	for hero_state in cast_ordered:
		if hero_state["dead"]:
			continue
		var roll_value: Variant = hero_rolls.get(hero_state["id"], null)
		if roll_value == null or _forecast_waiting_hero_ids.has(str(hero_state["id"])):
			continue
		# Freeze = repeat: a frozen die kept its face, so the unit acts again on
		# the same result. Targeting was re-picked fresh this round.
		if bool(hero_state.get("die_freeze_repeat_this_round", false)):
			_log("%s's frozen die repeats its %d." % [hero_state["unit"].display_name, int(roll_value)])
		var ability_entry: Dictionary = dice_manager.get_ability_for_roll(hero_state["unit"], int(roll_value))
		# No legal target => no announcement (2026-09-02). The action event is
		# what drives the banner, the ability-name slam and the overload
		# celebration, so firing it for an ability that provably does NOTHING
		# is the game claiming something happened when nothing did. Only the
		# ANNOUNCE is suppressed: the ability still resolves (a no-op) and the
		# 20-face riders below still pay out, because the die really did land
		# on 20 and Overload Capacitor / the lifetime-20s stat are owed either
		# way. Suppressing the whole beat there would be a balance change.
		var fizzles: bool = _ability_fizzles_for_lack_of_target(ability_entry)
		if fizzles:
			_log("%s holds %s - there is no one to revive." % [hero_state["unit"].display_name, str(ability_entry.get("ability_name", "Unknown"))])
		else:
			_log("%s uses %s." % [hero_state["unit"].display_name, str(ability_entry.get("ability_name", "Unknown"))])
			_emit_action_event(hero_state, "hero", str(ability_entry.get("ability_name", "Unknown")), str(ability_entry.get("zone", "")))
		_apply_hero_ability(hero_state, ability_entry)
		# Overload Loop relic / Overload Rites intercept: a 20 resolves twice.
		# Keys on the die's FINAL face (ruling NK-02 — no natural-20 check, a die
		# Set/Nudged/buffed to 20 counts the same), including frozen turns (G-8).
		if int(roll_value) == 20 \
				and (has_relic("critResolveTwice") or bool(hero_state.get("nat20_twice", false))):
			_log("Overload Loop echoes the 20 for %s!" % hero_state["unit"].display_name)
			_apply_hero_ability(hero_state, ability_entry)
		# 20-face riders (Overload Capacitor Protocol + the lifetime 20s stat).
		# Key on the die's FINAL face so a die Set/Nudged/buffed to 20 counts the
		# same as a rolled 20 (NK-02). Once per resolving turn, including frozen
		# turns; the Loop/Rites echo does not double these payouts (G-8).
		if int(roll_value) == 20:
			if not _forecast_only:
				SaveManager.record_nat20()
			var cap_gain: int = int(hero_state.get("gear_protocol_on_20", 0))
			if cap_gain > 0:
				_pending_protocol_grants += cap_gain
				_log("Overload Capacitor: a 20 grants +%d Protocol." % cap_gain)

	# Cast stamps are one-round state: cleared here (hero phase done) so the
	# next targeting phase starts unstamped on every exit path.
	for cleared_state_variant in _hero_states:
		(cleared_state_variant as Dictionary)["cast_stamp"] = 0


# ── Preview dry run (UI batch 2026-09-27, B1; whole round since G-65) ─────────
# The damage preview used to re-model the round by hand: first the hero phase
# (it left out detonate, execute, chain, mark, breach, spike and the relic
# multipliers), then, until G-65, the enemy phase (it summed each enemy's
# printed damage, so no trait, no Rampage and no pack bonus was in it). This
# runs the REAL round, the three steps resolve_round takes, on deep copies of
# the unit states and hands back the copies as they stand after each step. The
# live states, every per-round field, the seeded streams and everything outside
# this manager are left exactly as they were.
#
# `hero_rolls` holds every revealed hero die, so a hijack, the enemy intents
# and the boss rules read the dice the round will. `waiting_hero_ids` are the
# heroes whose ability still needs a target from the player: their dice count,
# but they do not act.
# Returns:
#   hero_states / enemy_states  the copies after the hero phase (squad order)
#   events                      the hero phase's combat events
#   detonate_by_hero            {hero_id: burst} each Detonate lands
#   enemy_events                the enemy phase's combat events
#   tick_events                 the end-of-round tick's combat events
#   pre_tick                    {state_id: copy} after the enemy phase
#   end                         {state_id: copy} after the end-of-round tick
# When the hero phase kills every enemy the round ends there, as in
# resolve_round: `pre_tick` and `end` are the states after the hero phase.
func forecast_round(
	hero_rolls: Dictionary,
	enemy_rolls: Dictionary,
	dice_manager: DiceManager,
	raw_hero_rolls: Dictionary = {},
	waiting_hero_ids: Dictionary = {}
) -> Dictionary:
	var live_heroes: Array = _hero_states
	var live_enemies: Array = _enemy_states
	var snap: Dictionary = snapshot_state()
	var saved_log: Array = _round_log.duplicate()
	var saved_events: Array = _round_events.duplicate(true)
	var saved_kill_queue: Array = _kill_queue.duplicate()
	var saved_raw_rolls: Dictionary = _current_raw_hero_rolls.duplicate()
	var saved_acted_heroes: Dictionary = _acted_hero_values.duplicate(true)
	var saved_acted_enemies: Dictionary = _acted_enemy_values.duplicate(true)
	var saved_assignments: Dictionary = _enemy_assignments.duplicate(true)
	var saved_cast_order: Array = _last_cast_order.duplicate()
	var saved_echo: bool = _echo_pass_active
	var saved_streams: Variant = _roll_provider_streams()

	_hero_states = snap["hero_states"]
	_enemy_states = snap["enemy_states"]
	_round_log = []
	_round_events = []
	_kill_queue = []
	_forecast_detonates = {}
	_forecast_only = true
	_forecast_waiting_hero_ids = waiting_hero_ids
	var rolls: Dictionary = hero_rolls.duplicate()
	var enemy_values: Dictionary = enemy_rolls.duplicate()
	_open_round()
	_resolve_hero_phase(rolls, enemy_values, dice_manager, raw_hero_rolls.duplicate())
	_forecast_waiting_hero_ids = {}
	var result: Dictionary = {
		"hero_states": _hero_states.map(func(st): return (st as Dictionary).duplicate(true)),
		"enemy_states": _enemy_states.map(func(st): return (st as Dictionary).duplicate(true)),
		# Copies: restore_state clears the live log/event arrays in place.
		"events": _round_events.duplicate(true),
		"detonate_by_hero": _forecast_detonates,
		"enemy_events": [],
		"tick_events": [],
	}
	var hero_phase_events: int = _round_events.size()
	var enemy_phase_events: int = hero_phase_events
	result["pre_tick"] = _states_by_id(true)
	if not _all_states_dead(_enemy_states) and preview_break() != "hero_phase_only":
		_resolve_enemy_phase(rolls, enemy_values, dice_manager, {})
		enemy_phase_events = _round_events.size()
		result["enemy_events"] = _round_events.slice(hero_phase_events, enemy_phase_events).duplicate(true)
		result["pre_tick"] = _states_by_id(true)
		_tick_end_of_round_states()
		result["tick_events"] = _round_events.slice(enemy_phase_events).duplicate(true)
	result["end"] = _states_by_id(false)
	_forecast_only = false
	_forecast_detonates = {}

	restore_state(snap)
	_hero_states = live_heroes
	_enemy_states = live_enemies
	_round_log = saved_log
	_round_events = saved_events
	_kill_queue = saved_kill_queue
	_current_raw_hero_rolls = saved_raw_rolls
	_acted_hero_values = saved_acted_heroes
	_acted_enemy_values = saved_acted_enemies
	_enemy_assignments = saved_assignments
	_last_cast_order = saved_cast_order
	_echo_pass_active = saved_echo
	_restore_roll_provider_streams(saved_streams)
	return result


# Every unit state by its id; deep copies when `copy`.
func _states_by_id(copy: bool) -> Dictionary:
	var by_id: Dictionary = {}
	for state_variant in _hero_states + _enemy_states:
		var state: Dictionary = state_variant
		by_id[str(state["id"])] = state.duplicate(true) if copy else state
	return by_id


# Deliberate breaks for the `trait preview` gate (scripts/debug/
# trait_preview_test.gd; never set by the game):
#   trait_blind      the dry run resolves the round with every trait off
#   hero_phase_only  the dry run stops after the hero phase (the old preview)
const PREVIEW_BREAK_ARG := "--preview-break="
static var _preview_break: String = "?"


static func preview_break() -> String:
	if _preview_break == "?":
		_preview_break = ""
		if OS.is_debug_build():
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with(PREVIEW_BREAK_ARG):
					_preview_break = arg.trim_prefix(PREVIEW_BREAK_ARG)
	return _preview_break


func _roll_provider_streams() -> Variant:
	if roll_provider == null:
		return null
	if roll_provider.has_method("get_stream_states"):
		return roll_provider.call("get_stream_states")
	if roll_provider.has_method("get_state"):
		return roll_provider.call("get_state")
	return null


func _restore_roll_provider_streams(saved: Variant) -> void:
	if roll_provider == null or saved == null:
		return
	if roll_provider.has_method("set_stream_states"):
		roll_provider.call("set_stream_states", saved)
	elif roll_provider.has_method("set_state"):
		roll_provider.call("set_state", saved)


func _next_enemy_instance_id(enemy: Resource) -> String:
	var base_id: String = str(enemy.id)
	var next_index: int = 1
	for state_variant in _enemy_states:
		var state: Dictionary = state_variant
		var state_unit: Object = state.get("unit") as Object
		if state_unit != null and str(state_unit.get("id")) == base_id:
			next_index += 1
	return "%s#%d" % [base_id, next_index]


func _create_runtime_state(unit: Resource, runtime_id: String = "") -> Dictionary:
	var state_id: String = runtime_id if runtime_id != "" else str(unit.id)
	var state: Dictionary = {
		"id": state_id,
		"unit": unit,
		"current_hp": unit.max_hp,
		"max_hp": unit.max_hp,
		"shield": 0,
		"shield_stacks": [],
		"shields_persist": false,
		"dead": false,
		# Burn / roll-buff instances (per Kev 2026-07-06): each application is
		# its own stack with its own remaining duration; effective value is the
		# sum of live stacks. "burn"/"burn_turns"/"roll_buff" are derived caches
		# for display (summed value, longest remaining clock).
		"burn": 0,
		"burn_turns": 0,
		"burn_stacks": [],
		"rfe_stacks": [],
		"roll_buff": 0,
		"roll_buff_stacks": [],
		"dmg_scale": 1.0,
		"selected_target_id": "",
		"target_display": "--",
		# Player-chosen cast order: the round's firing rank, stamped during the
		# targeting phase (auto-assigns in squad order at phase start, manual
		# picks at assignment). 0 = unstamped. Heroes resolve in ascending stamp
		# order; cleared by resolve_round after the hero phase. Enemy states
		# carry the field inert.
		"cast_stamp": 0,
		"cloaked": false,
		"die_freeze_turns": 0,
		"freeze_flavor": "",
		"rampage_charges": 0,
		"warded": false,
		"marked": false,
		"spike": 0,
		"jam_cap": 0,
		"rewrite_pending": false,
		"hijack_pending": false,
		"taunting": false,
		"frozen_die_value": 0,
		"die_freeze_repeat_this_round": false,
		"perm_roll_buff": 0,
		"perm_rfe": 0,
		"gear_burn_bonus": 0,
		"gear_dmg_reduction": 0,
		"gear_survive_once": false,
		"gear_survive_once_used": false,
		"gear_first_dmg_bonus": 0,
		"gear_first_dmg_fired": false,
		"gear_heal_on_kill": 0,
		"gear_protocol_on_start": 0,
		"gear_lifesteal_pct": 0,
		"gear_first_ability_echo": false,
		"gear_first_ability_echo_used": false,
		"gear_shield_pierce": 0,
		"gear_heal_shield_bonus": 0,
		"gear_protocol_on_kill": 0,
		"gear_protocol_on_kill_any": 0,
		"lured_by_id": "",
		"last_attacker_id": "",
		"accrete": 0,
		"directive_type": "",
		"directive_effect": {},
		"momentum_bonus": 0,
		"vanish_used": false,
		# The unit's trait id (G-62); "" for none. Its numbers stay on the unit.
		"trait": str(UnitTraits.of_unit(unit).get("id", "")),
	}
	if unit is EnemyData:
		if bool(unit.starts_cloaked):
			state["cloaked"] = true
		state["accrete"] = int(unit.accrete)
	# Tier-3 Directive (pkg6): a data-driven passive attached by
	# GameState.get_run_unit_data once picked.
	if unit is UnitData and not (unit as UnitData).directive.is_empty():
		var directive_effect: Dictionary = ((unit as UnitData).directive as Dictionary).get("effect", {})
		state["directive_type"] = str(directive_effect.get("type", ""))
		state["directive_effect"] = (directive_effect as Dictionary).duplicate(true)
		# Reaper: raise the execute threshold via the per-state hook.
		if str(state["directive_type"]) == "executeThresholdPct":
			state["execute_threshold_pct"] = int(directive_effect.get("pct", 25))
	return state


# --- Directive helpers (pkg6 tier-3 passives) ---

func _has_directive(state: Dictionary, effect_type: String) -> bool:
	return str(state.get("directive_type", "")) == effect_type


func _directive_value(state: Dictionary, key: String, default_val: int) -> int:
	return int((state.get("directive_effect", {}) as Dictionary).get(key, default_val))


func _directive_ability(state: Dictionary) -> String:
	return str((state.get("directive_effect", {}) as Dictionary).get("ability", ""))


# --- Shield stack helpers ---

func _get_total_shield(state: Dictionary) -> int:
	var total: int = 0
	for stack in state.get("shield_stacks", []):
		total += int(stack["amt"])
	return total


# Shields last one round: granted this round, absorb through this round's
# opposing phase, gone at the round-end tick. Enemy abilities resolve AFTER the
# hero phase, so shields they grant pass survives_current_tick=true — they live
# through the imminent tick and cover exactly one hero phase instead of dying
# before they could ever absorb. shields_persist (the MANTLE TYRANT boss rule)
# exempts a state from expiry entirely.
# CONFIRMED (per Kev 2026-07-06, DECISIONS_RESOLVED #2): "one round" IS the
# per-side "one opposing action phase" reading; shields_persist (MANTLE TYRANT)
# is the single named exception (the Mantle Core relic that shared it was
# removed in the boss relic rework, G-41). Data audited 2026-07-07: no
# multi-phase shield exists anywhere in data/raw.
# Returns the shield actually gained (the max-HP cap can trim it, to 0 when the
# unit is already at the cap). The log line and the event carry that number,
# never the amount asked for. `announce` false: the caller reports the gain
# itself (Accrete).
func _add_shield_stack(state: Dictionary, amount: int, survives_current_tick: bool = false, announce: bool = true) -> int:
	var shield_before: int = _get_total_shield(state)
	# Overcharge Mesh directive: shields gained by any squad member +2 while
	# a living carrier stands.
	if _is_hero_state(state):
		for mesh_state in _hero_states:
			if not bool(mesh_state["dead"]) and _has_directive(mesh_state, "squadShieldBonus"):
				amount += _directive_value(mesh_state, "amount", 2)
				break
	state["shield_stacks"].append({"amt": amount, "skip_next_tick": survives_current_tick})
	# Cap the total shield at max HP so persistent shields (MANTLE TYRANT)
	# can't accumulate without bound from per-round drips like
	# Bulwark Aura and Aegis Field (audit A-034). The one-round expiry that
	# bounds ordinary shields does not apply under shields_persist, so this cap
	# is the bound in that case.
	_cap_shield_at_max_hp(state)
	state["shield"] = _get_total_shield(state)
	var gained: int = int(state["shield"]) - shield_before
	if accrete_display_break() == "asked":
		gained = amount
	if announce:
		if gained > 0:
			_log("%s gains %d shield." % [state["unit"].display_name, gained])
			_emit_event(state, "shield", gained, _resolve_side_for_state(state))
		else:
			_log("%s's shield is at its limit." % state["unit"].display_name)
	return gained


# Accrete: a unit plates itself with shield, from its own keyword (Basalt Ape,
# Magma Drake: every enemy turn) or the Mantle Tyrant's ACCRETION rule (every
# 2nd round). One path for both, so both read the same: its own beat
# (`open_beat`; units accreting together share one), one `accrete` event whose
# amount is the shield actually gained, and one log line with that number.
# Returns the shield gained.
func _apply_accrete(state: Dictionary, amount: int, open_beat: bool) -> int:
	if amount <= 0 or bool(state.get("dead", false)):
		return 0
	var beat_index: int = _round_events.size()
	if open_beat:
		_emit_action_event(state, "enemy", "Accrete", "tick")
	var gained: int = _add_shield_stack(state, amount, true, false)
	if gained <= 0:
		if open_beat:
			_round_events.remove_at(beat_index)
		_log("%s's shield is at its limit. Accrete adds nothing." % state["unit"].display_name)
		return 0
	_log("%s accretes %d shield." % [state["unit"].display_name, gained])
	_emit_event(state, "accrete", gained, "enemy")
	return gained


# What the inspect says about a unit's Accrete: {} when it has none, else
# {"amount": N, "every_rounds": 0 for "each of its turns" or the round cadence}.
# The numbers the two rules above apply, read from the same sources.
static func accrete_rule(unit: Resource) -> Dictionary:
	if unit == null:
		return {}
	if str(unit.get("display_name")) == BOSS_MANTLE:
		return {"amount": MANTLE_ROUND_SHIELD, "every_rounds": MANTLE_SHIELD_CADENCE}
	var own: int = int(unit.get("accrete")) if unit is EnemyData else 0
	return {"amount": own, "every_rounds": 0} if own > 0 else {}


# Trims shield stacks (newest first) so their total never exceeds the unit's
# max HP. No-op when already within the cap.
func _cap_shield_at_max_hp(state: Dictionary) -> void:
	var max_shield: int = int(state.get("max_hp", 0))
	if max_shield <= 0:
		return
	var stacks: Array = state["shield_stacks"]
	var over: int = _get_total_shield(state) - max_shield
	if over <= 0:
		return
	for i in range(stacks.size() - 1, -1, -1):
		if over <= 0:
			break
		var amt: int = int(stacks[i]["amt"])
		var cut: int = mini(amt, over)
		stacks[i]["amt"] = amt - cut
		over -= cut
	var kept: Array = []
	for stack in stacks:
		if int(stack["amt"]) > 0:
			kept.append(stack)
	state["shield_stacks"] = kept


# --- RFE stack helpers ---

func _get_total_rfe(state: Dictionary) -> int:
	var total: int = 0
	for stack in state.get("rfe_stacks", []):
		total += int(stack["amt"])
	return total


func _add_rfe_stack(state: Dictionary, amount: int, turns: int) -> void:
	state["rfe_stacks"].append({"amt": amount, "turns_left": turns, "skip_next_tick": true})
	_log("%s gets -%d to rolls (%dt)." % [state["unit"].display_name, amount, turns])


# Roll buffs are independent instances, identical both sides (per Kev
# 2026-07-06, resolves the old erb refresh-to-max DESIGN-TODO): each cast is
# its own stack with its own clock, the effective value is the sum of live
# stacks, and every stack loses a turn at every end-of-round tick — an Nt
# instance cast on turn T is live turns T..T+N-1 and gone on turn T+N.
func _get_total_roll_buff(state: Dictionary) -> int:
	var total: int = 0
	for stack in state.get("roll_buff_stacks", []):
		total += int(stack["amt"])
	return total


func _refresh_roll_buff_total(state: Dictionary) -> void:
	state["roll_buff"] = _get_total_roll_buff(state)


# `turns` is EFFECTIVE turns — the number of rolls this buff shapes (docs/TRUTH.md
# duration convention). `shapes_current_roll` says whether the CAST round's roll
# counts toward that number, which decides the tick timing:
#  • true  — the buff is fed into get_effective_roll BEFORE the beneficiary
#    commits, so it shapes the cast-round roll (items). The cast round counts;
#    the stack ticks at that round's end like any other (no skip).
#  • false — the buff is applied AFTER the beneficiary's roll is spent (enemy
#    self-buffs cast during resolution; reactive relics like Emergency Signal),
#    so it CANNOT shape the cast round. That round doesn't count, so the stack
#    skips the cast-round tick and its `turns` future rolls all land.
# Same meaning of N either way — see TRUTH.md. Passing the wrong value here is a
# timing bug that used to be hidden by shrinking the number instead.
func _add_roll_buff(state: Dictionary, amount: int, turns: int, shapes_current_roll: bool) -> void:
	if state.is_empty() or bool(state.get("dead", false)) or amount <= 0 or turns <= 0:
		return
	var stack: Dictionary = {"amt": amount, "turns_left": turns}
	if not shapes_current_roll:
		stack["skip_next_tick"] = true
	state["roll_buff_stacks"].append(stack)
	_refresh_roll_buff_total(state)
	_log("%s gains +%d roll buff (%dt)." % [state["unit"].display_name, amount, turns])
	_emit_event(state, "roll_buff", amount, _resolve_side_for_state(state))


func _apply_hero_ability(hero_state: Dictionary, ability_entry: Dictionary) -> void:
	_ability_ward_blocked_ids.clear()
	_ability_ward_block_notes.clear()
	_ability_rider_target_ids.clear()
	_ability_spike_carrier_ids.clear()
	_ability_trait_chips.clear()
	_ability_backup_ids.clear()
	_ability_cloaked_pick_id = ""
	var raw: Dictionary = ability_entry.get("raw", {})
	# Cloaked as the ability starts: Spectral and Silent ask this after
	# the ambush has already taken the cloak down.
	var cast_from_cloak: bool = bool(hero_state.get("cloaked", false))
	var events_at_cast: int = _round_events.size()
	var damage: int = int(raw.get("dmg", 0))
	var heal: int = int(raw.get("heal", 0))
	var shield: int = int(raw.get("shield", 0))
	var hits_all: bool = bool(raw.get("blastAll", false))
	var heal_all: bool = bool(raw.get("healAll", false))
	var shield_all: bool = bool(raw.get("shieldAll", false))
	var heal_lowest: bool = bool(raw.get("healLowest", false))
	var shield_targeted: bool = bool(raw.get("shTgt", false))
	var heal_targeted: bool = bool(raw.get("healTgt", false))
	var burn_amount: int = int(raw.get("burn", 0))
	var burn_turns: int = int(raw.get("burnT", 0))
	var roll_buff_amount: int = int(raw.get("rfm", 0))
	var roll_buff_turns: int = int(raw.get("rfmT", 1))
	var roll_buff_targeted: bool = bool(raw.get("rfmTgt", false)) or shield_targeted or heal_targeted
	var ignores_shield: bool = bool(raw.get("ignSh", false))

	# Dealing damage breaks the cloak, and that attack is an ambush (G-52): the
	# ability's damage is multiplied. No pierce. Ambush Wiring adds its flat
	# bonus on top of the ambush, and Ghostblade adds its execute.
	if damage > 0 and ambush_ready(hero_state):
		damage = _ambush_from_cloak(hero_state, damage)
		# Ambush Wiring directive: attacks from Cloak hit harder.
		if _has_directive(hero_state, "cloakAttackBonus"):
			damage += _directive_value(hero_state, "amount", 5)
		# Ghostblade directive: the decloak strike also Executes (consumed in
		# the damage pass).
		if _has_directive(hero_state, "decloakExecute"):
			hero_state["decloak_execute_pending"] = true

	# Every enemy cloaked: a single-target attack hits one of them at random.
	if damage > 0 and not hits_all and _hostile_single_target(_enemy_states, str(hero_state.get("selected_target_id", "")), hero_state).is_empty():
		_ability_cloaked_pick_id = str(_random_cloaked_target(_enemy_states, hero_state).get("id", ""))

	if damage > 0:
		var kill_target: Dictionary = {} if hits_all else _hostile_single_target(_enemy_states, str(hero_state.get("selected_target_id", "")), hero_state)
		_apply_hero_ability_damage(hero_state, ability_entry, damage, hits_all, ignores_shield, burn_amount, burn_turns)
		# Silent: an ambush that kills its target does not break the cloak.
		if cast_from_cloak and _has_trait(hero_state, "silentKill") and not kill_target.is_empty() \
				and bool(kill_target.get("dead", false)) and not bool(hero_state.get("dead", false)):
			_keep_cloak_after_kill(hero_state, kill_target, events_at_cast)

	if shield > 0:
		# Rampart directive: shields this hero grants are bigger.
		var shield_grant: int = shield
		if _has_directive(hero_state, "ownShieldBonus"):
			shield_grant += _directive_value(hero_state, "amount", 2)
		if shield_all:
			for ally_state in _hero_states:
				if not ally_state["dead"]:
					_add_shield_stack(ally_state, shield_grant)
					_apply_bunker_doctrine_spike(hero_state, ally_state)
		elif bool(raw.get("shieldLowest", false)):
			var lowest_shield_target: Dictionary = _lowest_hp_state(_hero_states)
			if not lowest_shield_target.is_empty():
				_add_shield_stack(lowest_shield_target, shield_grant)
				_apply_bunker_doctrine_spike(hero_state, lowest_shield_target)
		elif shield_targeted:
			var shield_target: Dictionary = _find_target_by_id(_hero_states, str(hero_state.get("selected_target_id", "")))
			if shield_target.is_empty():
				shield_target = _lowest_hp_state(_hero_states)
			if not shield_target.is_empty():
				_add_shield_stack(shield_target, shield_grant)
				_apply_bunker_doctrine_spike(hero_state, shield_target)
		else:
			_add_shield_stack(hero_state, shield_grant)

	if heal > 0:
		# Watchful: this ability's heal restores more on the lowest-HP ally.
		var triage_target: Dictionary = _lowest_hp_state(_hero_states) if _has_trait(hero_state, "triage") else {}
		if heal_all:
			for ally_state in _hero_states:
				_heal_state(ally_state, _triage_heal(hero_state, ally_state, triage_target, heal), hero_state)
		elif heal_lowest or heal_targeted:
			var heal_target: Dictionary = _find_target_by_id(_hero_states, str(hero_state.get("selected_target_id", "")))
			if heal_target.is_empty():
				heal_target = _lowest_hp_state(_hero_states)
			if not heal_target.is_empty():
				_heal_state(heal_target, _triage_heal(hero_state, heal_target, triage_target, heal), hero_state)
		else:
			_heal_state(hero_state, _triage_heal(hero_state, hero_state, triage_target, heal), hero_state)

	# Cleanse (Build I, instant keyword — fires and done, no persistent chip):
	# purge the target's unit-level negative statuses. Follows the heal target
	# (Infusion heals-and-cleanses one ally); a cast with nothing to remove is
	# a legal no-op. Die-attached states (frozen/repeat dice, rewrite/hijack
	# pending) are NOT cleansed by ruling — the die is the crust's object, and
	# freeze-as-repeat can be a banked benefit the player chose.
	if bool(raw.get("cleanse", false)):
		var cleanse_target: Dictionary = _find_target_by_id(_hero_states, str(hero_state.get("selected_target_id", "")))
		if cleanse_target.is_empty():
			cleanse_target = hero_state
		_apply_cleanse(cleanse_target)

	if roll_buff_amount > 0:
		# Cast during hero resolution — the beneficiaries' abilities for this turn
		# were already selected from their rolls, so this shapes FUTURE rolls only
		# (shapes_current_roll=false). No hero ability carries rfm today, but the
		# path must be timing-correct if one is authored.
		if roll_buff_targeted:
			var roll_buff_target: Dictionary = _find_target_by_id(_hero_states, str(hero_state.get("selected_target_id", "")))
			if roll_buff_target.is_empty():
				roll_buff_target = hero_state
			_add_roll_buff(roll_buff_target, roll_buff_amount, roll_buff_turns, false)
		else:
			for ally_state in _hero_states:
				if not ally_state["dead"]:
					_add_roll_buff(ally_state, roll_buff_amount, roll_buff_turns, false)

	var gain_protocol: int = int(raw.get("gainProtocol", 0))
	# Surge Wiring directive: the named ability generates extra Protocol.
	if gain_protocol > 0 and _has_directive(hero_state, "abilityProtocolBonus") and _directive_ability(hero_state) == str(ability_entry.get("ability_name", "")):
		gain_protocol += _directive_value(hero_state, "amount", 2)
	if gain_protocol > 0:
		_pending_protocol_grants += gain_protocol
		_log("%s generates %d Protocol." % [hero_state["unit"].display_name, gain_protocol])

	if damage <= 0 and burn_amount > 0:
		var burn_target: Dictionary = _hostile_single_target(_enemy_states, str(hero_state.get("selected_target_id", "")), hero_state)
		if not burn_target.is_empty() and not _ward_blocks_hostile(burn_target, [FirewallFeedback.BURN]):
			_apply_burn_from_hero(hero_state, burn_target, burn_amount, burn_turns)

	# Mark without damage (Build I — Target Lock is now a 0-dmg setup band):
	# the mark path historically lived inside the damage pass, so a pure-mark
	# ability never marked. Same hostile-single-target idiom as the
	# burn-without-damage case above; a firewall blocks it like any hostile.
	if damage <= 0 and bool(raw.get("mark", false)):
		var mark_target: Dictionary = _hostile_single_target(_enemy_states, str(hero_state.get("selected_target_id", "")), hero_state)
		if not mark_target.is_empty() and not _ward_blocks_hostile(mark_target, [FirewallFeedback.MARK]):
			_apply_mark(mark_target)

	# RFE application (roll debuff on enemies)
	var rfe_amount: int = int(raw.get("rfe", 0))
	var rfe_turns: int = int(raw.get("rfT", 1))
	var rfe_all: bool = bool(raw.get("rfeAll", false))
	if rfe_amount > 0:
		if rfe_all:
			for enemy_state in _enemy_states:
				if not enemy_state["dead"] and not _ward_blocks_hostile(enemy_state, [FirewallFeedback.ROLL_PENALTY]):
					_add_rfe_stack(enemy_state, rfe_amount, rfe_turns)
					_apply_roll_down_directives(hero_state, enemy_state, true)
		else:
			var rfe_target: Dictionary = _hostile_single_target(_enemy_states, str(hero_state.get("selected_target_id", "")), hero_state)
			if not rfe_target.is_empty() and not _ward_blocks_hostile(rfe_target, [FirewallFeedback.ROLL_PENALTY]):
				_add_rfe_stack(rfe_target, rfe_amount, rfe_turns)
				_apply_roll_down_directives(hero_state, rfe_target, false)

	if bool(raw.get("taunt", false)):
		# Build G ruling G-4: taunt marks ONE enemy — the taunted unit can only
		# target the taunter until round end (the keyword def always said so;
		# the old code was an all-enemy stance). Manual pick like any hostile
		# single-target; _hostile_single_target supplies the deterministic
		# fallback for sim/auto and honors an active lure on the caster. A
		# firewall blocks (and is consumed by) the taunt, symmetric with the
		# enemy-side lure. The hero flag stays for Ironclad + the readout;
		# multiple heroes may taunt different enemies in one round.
		hero_state["taunting"] = true
		var taunt_target: Dictionary = _hostile_single_target(_enemy_states, str(hero_state.get("selected_target_id", "")), hero_state)
		if not taunt_target.is_empty() and not _ward_blocks_hostile(taunt_target, [FirewallFeedback.TAUNT]):
			taunt_target["lured_by_id"] = str(hero_state["id"])
			_log("%s taunts %s - it can only strike back this round!" % [hero_state["unit"].display_name, taunt_target["unit"].display_name])
			_emit_event(taunt_target, "taunt", 0, "enemy")

	if ReviveResolution.is_revive_family(raw):
		_resolve_revive_family(hero_state, ability_entry, raw)

	# Spike: this round, any enemy that damages this unit takes N back.
	var spike_amount: int = int(raw.get("spike", 0))
	# Counterweight directive: this hero's Spike hits harder.
	if spike_amount > 0 and _has_directive(hero_state, "spikeBonus"):
		spike_amount += _directive_value(hero_state, "amount", 4)
	if spike_amount > 0:
		# Build I (Enforce rider): when the band ALSO carries a targeted shield
		# (shTgt), the spike rides the SHIELDED target — the guard hardens
		# whoever he covers. Same target-resolution chain as the shield grant,
		# so the spike lands exactly where the shield landed. Self-spike bands
		# (Spike Stance, enemy carriers) are unchanged.
		var spike_holder: Dictionary = hero_state
		if bool(raw.get("shTgt", false)):
			var spike_shield_target: Dictionary = _find_target_by_id(_hero_states, str(hero_state.get("selected_target_id", "")))
			if spike_shield_target.is_empty():
				spike_shield_target = _lowest_hp_state(_hero_states)
			if not spike_shield_target.is_empty():
				spike_holder = spike_shield_target
		spike_holder["spike"] = maxi(int(spike_holder.get("spike", 0)), spike_amount)
		_log("%s bristles with spike %d - attackers take damage this round." % [spike_holder["unit"].display_name, spike_amount])
		_emit_event(spike_holder, "spike_up", spike_amount, "hero")

	# Ward application: self by default, targeted ally with wardTgt.
	if bool(raw.get("ward", false)):
		if bool(raw.get("wardTgt", false)):
			var ward_target: Dictionary = _find_target_by_id(_hero_states, str(hero_state.get("selected_target_id", "")))
			if ward_target.is_empty():
				ward_target = hero_state
			_apply_ward(ward_target)
		else:
			_apply_ward(hero_state)

	# Cloak application
	if bool(raw.get("cloak", false)):
		hero_state["cloaked"] = true
		_log("%s is now cloaked." % hero_state["unit"].display_name)
		_emit_event(hero_state, "cloak", 0, "hero")
	if bool(raw.get("cloakAll", false)):
		for ally_state in _hero_states:
			if not ally_state["dead"]:
				ally_state["cloaked"] = true
				_log("%s is now cloaked." % ally_state["unit"].display_name)
				_emit_event(ally_state, "cloak", 0, "hero")

	# Freeze die application — FREEZE = REPEAT (per Kev 2026-07-06, final;
	# supersedes both the next-turn static lockout and the fix-1.4 bank/thaw
	# banked-face model — see docs/DECISIONS_RESOLVED.md #1). The frozen die
	# crusts static in the tray and does NOT reroll: on each of its next N
	# rolls it keeps the same face and its unit ACTS AGAIN on that result —
	# same zone, same ability, targeting re-picked fresh each repeat. Only the
	# die result is locked. After N repeats it thaws and rolls normally.
	# Identical both sides; freezing an ally repeats their result on purpose.
	var freeze_enemy: int = int(raw.get("freezeEnemyDice", 0))
	var freeze_all_enemy: int = int(raw.get("freezeAllEnemyDice", 0))
	var freeze_any: int = int(raw.get("freezeAnyDice", 0))
	var freeze_amount: int = maxi(maxi(freeze_enemy, freeze_all_enemy), freeze_any)
	var freeze_flavor: String = str(raw.get("freeze_flavor", "ice"))
	# Deep Freeze directive: this hero's freezes repeat more results.
	if freeze_amount > 0 and _has_directive(hero_state, "freezeDurationBonus"):
		freeze_amount += _directive_value(hero_state, "amount", 1)
	if freeze_amount > 0:
		if freeze_all_enemy > 0:
			for es in _enemy_states:
				if not es["dead"] and not _ward_blocks_hostile(es, [FirewallFeedback.FREEZE]):
					_freeze_die_state(es, freeze_amount, freeze_flavor)
		else:
			var freeze_target: Dictionary = {}
			if freeze_any > 0:
				# freezeAnyDice: one manual pick, either side (freezing an ally
				# repeats their good result; a ward only blocks hostile picks).
				freeze_target = _find_target_by_id(_hero_states, str(hero_state.get("selected_target_id", "")))
			if not freeze_target.is_empty():
				# Friendly freeze of an ally's die — not an enemy tamper (A-062).
				_freeze_die_state(freeze_target, freeze_amount, freeze_flavor, false)
			else:
				freeze_target = _hostile_single_target(_enemy_states, str(hero_state.get("selected_target_id", "")), hero_state)
				if not freeze_target.is_empty() and not _ward_blocks_hostile(freeze_target, [FirewallFeedback.FREEZE]):
					_freeze_die_state(freeze_target, freeze_amount, freeze_flavor)

	# Jam: cap the target's next roll at 10 (die status, telegraphed for the
	# next reveal). jamAll caps every living enemy die.
	# Spectral: a jam this hero applies from cloak lasts extra rounds.
	var jam_extra: int = _trait_num(hero_state, "rounds", 1) if cast_from_cloak and _has_trait(hero_state, "ghostSignal") else 0
	if bool(raw.get("jamAll", false)):
		for es in _enemy_states:
			if not es["dead"] and not _ward_blocks_hostile(es, [FirewallFeedback.JAM]):
				_apply_jam(es, JAM_CAP, true)
				_extend_jam(hero_state, es, jam_extra)
	elif bool(raw.get("jam", false)):
		var jam_target: Dictionary = _hostile_single_target(_enemy_states, str(hero_state.get("selected_target_id", "")), hero_state)
		if not jam_target.is_empty() and not _ward_blocks_hostile(jam_target, [FirewallFeedback.JAM]):
			_apply_jam(jam_target, JAM_CAP, true)
			_extend_jam(hero_state, jam_target, jam_extra)

	# Rewrite: force the target's next roll to 3.
	if bool(raw.get("rewrite", false)):
		var rewrite_target: Dictionary = _hostile_single_target(_enemy_states, str(hero_state.get("selected_target_id", "")), hero_state)
		if not rewrite_target.is_empty() and not _ward_blocks_hostile(rewrite_target, [FirewallFeedback.REWRITE]):
			_apply_rewrite(rewrite_target, true)
			# Zero-Day: an enemy this hero rewrites takes more from attacks
			# until the rewrite ends.
			if _has_trait(hero_state, "zeroDay") and bool(rewrite_target.get("rewrite_pending", false)):
				rewrite_target["zero_day"] = _trait_num(hero_state, "amount", 2)
				_trait_fired(hero_state, "%s takes +%d damage until the rewrite ends." % [rewrite_target["unit"].display_name, int(rewrite_target["zero_day"])])

	if damage > 0 and bool(hero_state.get("gear_first_ability_echo", false)) and not bool(hero_state.get("gear_first_ability_echo_used", false)):
		hero_state["gear_first_ability_echo_used"] = true
		# Echo the DAMAGE only — Mark is suppressed for the echo pass so it can't
		# consume the Mark the first pass just applied (audit A-074).
		_echo_pass_active = true
		_apply_hero_ability_damage(hero_state, ability_entry, damage, hits_all, ignores_shield, 0, 0)
		_echo_pass_active = false

	# Bloodlust: rolling the unit's first band arms its next leech.
	if _has_trait(hero_state, "bloodlust") and _is_first_band(hero_state, ability_entry) \
			and not bool(hero_state.get("bloodlust_ready", false)) and not bool(hero_state.get("dead", false)):
		hero_state["bloodlust_ready"] = true
		_trait_fired(hero_state, "%s's next leech heals %d%% more." % [hero_state["unit"].display_name, _trait_num(hero_state, "pct", 50)])

	# Silent Running directive: non-damage abilities re-Cloak the caster.
	if damage <= 0 and _has_directive(hero_state, "nonDamageRecloak") and not bool(hero_state.get("cloaked", false)) and not bool(hero_state.get("dead", false)):
		hero_state["cloaked"] = true
		_log("%s slips back into cloak (Silent Running)." % hero_state["unit"].display_name)
		_emit_event(hero_state, "cloak", 0, "hero")


# Bunker Doctrine directive: allies holding this hero's shields Spike.
func _apply_bunker_doctrine_spike(granter_state: Dictionary, holder_state: Dictionary) -> void:
	if holder_state == granter_state or not _has_directive(granter_state, "shieldGrantsSpike"):
		return
	var spike_value: int = _directive_value(granter_state, "amount", 3)
	holder_state["spike"] = maxi(int(holder_state.get("spike", 0)), spike_value)
	_log("Bunker Doctrine: %s gains spike %d." % [holder_state["unit"].display_name, spike_value])


# Roll-down riders (Noise Floor / Nullwire directives): fired per enemy that
# takes one of this hero's rfe applications.
func _apply_roll_down_directives(hero_state: Dictionary, target_state: Dictionary, is_tray_wide: bool) -> void:
	# Wall of Static: tray-wide roll-downs also Jam (higher cap).
	if is_tray_wide and _has_directive(hero_state, "rfeAllAlsoJam"):
		_apply_jam(target_state, _directive_value(hero_state, "cap", 15), true)
	# Hard Lock: single-target roll-downs also Jam.
	if not is_tray_wide and _has_directive(hero_state, "rfeAlsoJam"):
		_apply_jam(target_state, JAM_CAP, true)
	# Feedback: enemies under this hero's roll-downs burn Protocol-out — take
	# damage each round while a roll-down is active.
	if _has_directive(hero_state, "rfeDamagePerRound"):
		target_state["feedback_per_round"] = maxi(int(target_state.get("feedback_per_round", 0)), _directive_value(hero_state, "amount", 2))
	# Signal Theft: every roll-down applied feeds the pool.
	if _has_directive(hero_state, "rfeGrantsProtocol"):
		var theft: int = _directive_value(hero_state, "amount", 1)
		_pending_protocol_grants += theft
		_log("Signal Theft: +%d Protocol." % theft)


# Field Surgeon / Lazarus Loop: the named ability revives at a fixed percent.
# Revive family, decided at FIRE time (NK-17 `else`, Kev 2026-09-25): anyone down
# -> revive (the picked hero if still down, else the first fallen; reviveAll takes
# every fallen hero); nobody down -> the fallback heal (picked living hero, else
# lowest HP; fallbackHealAll heals the squad). Percentage comes from
# ReviveResolution so the readout shows exactly what fires here.
func _resolve_revive_family(hero_state: Dictionary, ability_entry: Dictionary, raw: Dictionary) -> void:
	var fallback: int = ReviveResolution.fallback_heal(raw)
	if not ReviveResolution.any_hero_down(_hero_states):
		if fallback <= 0:
			return
		if bool(raw.get("fallbackHealAll", false)):
			for ally_state in _hero_states:
				_heal_state(ally_state, fallback, hero_state)
			return
		var heal_target: Dictionary = _find_target_by_id(_hero_states, str(hero_state.get("selected_target_id", "")))
		if heal_target.is_empty():
			heal_target = _lowest_hp_state(_hero_states)
		_heal_state(heal_target, fallback, hero_state)
		return
	var revive_pct: int = ReviveResolution.resolved_pct(raw, hero_state, str(ability_entry.get("ability_name", "")))
	if bool(raw.get("reviveAll", false)):
		for ally_state in _hero_states:
			if bool(ally_state.get("dead", false)):
				_revive_state(ally_state, revive_pct)
		return
	var revive_target: Dictionary = _find_target_by_id_including_dead(_hero_states, str(hero_state.get("selected_target_id", "")))
	if revive_target.is_empty() or not bool(revive_target.get("dead", false)):
		revive_target = _first_dead_state(_hero_states)
	_revive_state(revive_target, revive_pct)


func _apply_hero_ability_damage(
	hero_state: Dictionary,
	ability_entry: Dictionary,
	damage: int,
	hits_all: bool,
	ignores_shield: bool,
	burn_amount: int,
	burn_turns: int
) -> void:
	var raw: Dictionary = ability_entry.get("raw", {})
	var first_bonus: int = 0
	if not bool(hero_state.get("gear_first_dmg_fired", false)) and int(hero_state.get("gear_first_dmg_bonus", 0)) > 0:
		first_bonus = int(hero_state["gear_first_dmg_bonus"])
		hero_state["gear_first_dmg_fired"] = true
	var final_dmg: int = int(ceil(float(damage + first_bonus) * _get_hero_dmg_mult()))
	# Momentum directive: a banked kill bonus lands on the next ability's damage.
	var momentum: int = int(hero_state.get("momentum_bonus", 0))
	if momentum > 0:
		final_dmg += momentum
		hero_state["momentum_bonus"] = 0
		_log("Momentum: +%d damage." % momentum)
	# Redline: a flat bonus on every attack while the player holds enough Protocol.
	if _has_trait(hero_state, "redline") and protocol_pool >= _trait_num(hero_state, "protocol", 5):
		var redline: int = _trait_num(hero_state, "amount", 2)
		final_dmg += redline
		_trait_fired(hero_state, "+%d damage with %d Protocol held." % [redline, protocol_pool], redline)
	var shield_pierce: int = int(hero_state.get("gear_shield_pierce", 0))

	var breach: bool = bool(raw.get("breach", false))
	# Serrated directive: this hero's Pierce attacks also Breach.
	if ignores_shield and _has_directive(hero_state, "pierceAlsoBreach"):
		breach = true
	var breach_all: bool = bool(raw.get("breachAll", false))
	var leech: bool = bool(raw.get("leech", false))
	var leech_hp_dealt: int = 0
	# What a Firewall on the target cancels from this attack (the log names it).
	var attack_effects: Array = [FirewallFeedback.DAMAGE]
	if burn_amount > 0 and burn_turns > 0:
		attack_effects.append(FirewallFeedback.BURN)

	if hits_all:
		for enemy_state in _enemy_states:
			if enemy_state["dead"]:
				continue
			if _ward_blocks_hostile(enemy_state, attack_effects):
				continue
			_break_cloak_on_aoe(enemy_state)
			if breach_all or breach:
				_breach_shields(hero_state, enemy_state)
			# Ruthless: this hero's area attacks hit marked enemies harder.
			var area_dmg: int = final_dmg
			if _has_trait(hero_state, "exposed") and bool(enemy_state.get("marked", false)):
				area_dmg += _trait_num(hero_state, "amount", 2)
				_trait_fired(hero_state, "+%d damage to marked %s." % [_trait_num(hero_state, "amount", 2), enemy_state["unit"].display_name])
			leech_hp_dealt += _damage_state(enemy_state, area_dmg, ignores_shield, hero_state, shield_pierce)
			# AoE burn (Supernova: "3 burn all").
			if burn_amount > 0 and burn_turns > 0 and not enemy_state["dead"]:
				_apply_burn_from_hero(hero_state, enemy_state, burn_amount, burn_turns)
	else:
		var target_enemy: Dictionary = _hostile_single_target(_enemy_states, str(hero_state.get("selected_target_id", "")), hero_state)
		if target_enemy.is_empty():
			_log("%s finds no visible target - the attack fizzles." % hero_state["unit"].display_name)
		# breach all on a single-target ability still strips every enemy's
		# shields before the hit lands.
		if breach_all:
			for enemy_state in _enemy_states:
				if not enemy_state["dead"] and not _ward_blocks_hostile(enemy_state, [FirewallFeedback.BREACH]):
					_breach_shields(hero_state, enemy_state)
		if not target_enemy.is_empty():
			if breach and not breach_all:
				attack_effects.append(FirewallFeedback.BREACH)
			if bool(raw.get("mark", false)) and not _echo_pass_active:
				attack_effects.append(FirewallFeedback.MARK)
			if not _ward_blocks_hostile(target_enemy, attack_effects):
				if breach and not breach_all:
					_breach_shields(hero_state, target_enemy)
				# vsFrozenBonus rider (Shatter Lance): bonus damage against a
				# target whose die is frozen. A rider, not a keyword.
				var single_target_dmg: int = final_dmg
				var frozen_bonus: int = int(raw.get("vsFrozenBonus", 0))
				if frozen_bonus > 0 and int(target_enemy.get("die_freeze_turns", 0)) > 0:
					single_target_dmg += frozen_bonus
					_log("%s shatters the frozen die - +%d damage!" % [hero_state["unit"].display_name, frozen_bonus])
				leech_hp_dealt += _damage_state(target_enemy, single_target_dmg, ignores_shield, hero_state, shield_pierce)
				if bool(raw.get("detonate", false)):
					_detonate_burn(hero_state, target_enemy)
				# Open Veins directive: the overload zone Detonates after its damage.
				elif str(ability_entry.get("zone", "")) == "overload" and _has_directive(hero_state, "overloadDetonateAfter"):
					_detonate_burn(hero_state, target_enemy)
				if bool(raw.get("execute", false)):
					_apply_execute_bonus(hero_state, target_enemy)
				# Ghostblade directive: the decloak strike also Executes.
				if bool(hero_state.get("decloak_execute_pending", false)):
					hero_state["decloak_execute_pending"] = false
					_apply_execute_bonus(hero_state, target_enemy)
				if burn_amount > 0 and burn_turns > 0:
					_apply_burn_from_hero(hero_state, target_enemy, burn_amount, burn_turns)
				# Mark applies AFTER this hit — the NEXT hit gets the +50%.
				# Combat Sense / Marked for Death directives Mark on any
				# damaging single-target hit.
				# CONFIRMED, never AoE Mark (per Kev 2026-07-06,
				# DECISIONS_RESOLVED #14): directive Marks land on the primary
				# target of single-target hits only.
				if (bool(raw.get("mark", false)) or _has_directive(hero_state, "damageAppliesMark")) and not _echo_pass_active:
					_apply_mark(target_enemy)
			# Chain jumps continue even when the primary hit was ward-blocked —
			# the ward only negates the ability for its own carrier.
			_apply_chain_jumps(hero_state, ability_entry, target_enemy, final_dmg, ignores_shield, shield_pierce)

	# Leech: the attacker heals 50% of the HP damage dealt (after shields).
	if leech and leech_hp_dealt > 0:
		var leech_share: float = 0.5
		# Bloodlust: the armed leech heals more, once.
		if _has_trait(hero_state, "bloodlust") and bool(hero_state.get("bloodlust_ready", false)):
			hero_state["bloodlust_ready"] = false
			leech_share *= 1.0 + float(_trait_num(hero_state, "pct", 50)) / 100.0
			_trait_fired(hero_state, "%s leeches %d%% more." % [hero_state["unit"].display_name, _trait_num(hero_state, "pct", 50)])
		var leech_heal: int = int(floor(float(leech_hp_dealt) * leech_share))
		if leech_heal > 0:
			_log("%s leeches %d HP." % [hero_state["unit"].display_name, leech_heal])
			# fix-2.7: paired leech event — carries the drained enemy so feedback
			# can draw the target->attacker return tracer (the heal event that
			# follows carries the green number).
			_round_events.append({
				"type": "leech",
				"amount": leech_heal,
				"side": "hero",
				"target_id": str(hero_state["id"]),
				"target_name": str(hero_state["unit"].display_name),
				"hp_after": int(hero_state.get("current_hp", 0)),
				"hp_max": int(hero_state.get("max_hp", 1)),
				"source_side": "enemy",
				"source_id": str(hero_state.get("selected_target_id", "")),
			})
			_heal_state(hero_state, leech_heal, hero_state)


const JAM_CAP := 10
const REWRITE_VALUE := 3


# Rewrite: die status — the target's next roll is SET to 3. Telegraphed:
# applied this turn, it fires at the next roll. Frozen dice are immune (per
# Kev 2026-07-06): the crusted face repeats and cannot be rewritten.
func _apply_rewrite(state: Dictionary, survives_current_tick: bool = true) -> void:
	if state.is_empty() or bool(state.get("dead", false)):
		return
	if int(state.get("die_freeze_turns", 0)) > 0:
		_log("%s's die is frozen solid - the rewrite can't take hold." % state["unit"].display_name)
		return
	state["rewrite_pending"] = true
	state["rewrite_skip_next_tick"] = survives_current_tick
	_log("%s's die is being REWRITTEN - next roll becomes %d." % [state["unit"].display_name, REWRITE_VALUE])
	_emit_event(state, "rewrite", REWRITE_VALUE, _resolve_side_for_state(state))
	_grant_mirror_plate_protocol(state)


# Mirror Plate gear: when an enemy Jams/Rewrites/Freezes this unit's die,
# gain Protocol (delivered through the pending-grant pipeline).
func _grant_mirror_plate_protocol(state: Dictionary) -> void:
	if not _is_hero_state(state):
		return
	var amount: int = int(state.get("gear_mirror_plate", 0))
	if amount > 0:
		_pending_protocol_grants += amount
		_log("Mirror Plate: +%d Protocol." % amount)


# Public hook for the Signal Hierarch boss rule (rewrite the heroes' highest die).
func apply_rewrite_to_state(state: Dictionary, survives_current_tick: bool = true) -> void:
	_apply_rewrite(state, survives_current_tick)


# Jam: die status — the target's next roll is capped (default 10). Applied
# mid-round it survives the imminent tick and caps the NEXT reveal;
# battle-start applications (Static Field relic) cap the first roll directly.
# Frozen dice are immune (per Kev 2026-07-06): the crusted face repeats as-is.
func _apply_jam(state: Dictionary, cap: int = JAM_CAP, survives_current_tick: bool = true) -> void:
	if state.is_empty() or bool(state.get("dead", false)):
		return
	if int(state.get("die_freeze_turns", 0)) > 0:
		_log("%s's die is frozen solid - the jam can't take hold." % state["unit"].display_name)
		return
	var existing: int = int(state.get("jam_cap", 0))
	state["jam_cap"] = cap if existing <= 0 else mini(existing, cap)
	state["jam_skip_next_tick"] = survives_current_tick
	_log("%s's die is JAMMED - next roll capped at %d." % [state["unit"].display_name, int(state["jam_cap"])])
	_emit_event(state, "jam", int(state["jam_cap"]), _resolve_side_for_state(state))
	_grant_mirror_plate_protocol(state)


func apply_battle_start_jam(state: Dictionary, cap: int = JAM_CAP) -> void:
	_apply_jam(state, cap, false)


# Hero-applied Burn: routes through the Ignition Coil gear hook — the Burn
# also ticks once immediately on apply (extra tick, turns untouched).
func _apply_burn_from_hero(hero_state: Dictionary, target_state: Dictionary, amount: int, turns: int) -> void:
	# Slow Roast directive: this hero's Burns last longer.
	var total_turns: int = turns
	if _has_directive(hero_state, "burnDurationBonus"):
		total_turns += _directive_value(hero_state, "amount", 1)
	_apply_burn(target_state, amount, total_turns)
	# Ignition Coil gear / Flashpoint directive: the Burn ticks once on apply.
	var ignites: bool = bool(hero_state.get("gear_burn_immediate", false)) or _has_directive(hero_state, "burnImmediateTick")
	if ignites and amount > 0 and not bool(target_state.get("dead", false)):
		_log("The burn ignites instantly for %d!" % amount)
		_damage_state(target_state, amount)


# Mark: persistent status chip — the next hit on this target deals +50%
# (round up), then the Mark is consumed (see _damage_state).
func _apply_mark(target_state: Dictionary) -> void:
	if target_state.is_empty() or bool(target_state.get("dead", false)):
		return
	target_state["marked"] = true
	_log("%s is MARKED - the next hit deals +50%%." % target_state["unit"].display_name)
	_emit_event(target_state, "mark", 0, _resolve_side_for_state(target_state))


func apply_item_mark(target_state: Dictionary) -> void:
	_apply_mark(target_state)


# Breach: destroy ALL shield on the target before the damage applies.
func _breach_shields(attacker_state: Dictionary, target_state: Dictionary) -> void:
	if target_state.is_empty() or bool(target_state.get("dead", false)):
		return
	var destroyed: int = int(target_state.get("shield", 0))
	if destroyed <= 0:
		return
	target_state["shield_stacks"] = []
	target_state["shield"] = 0
	_log("%s BREACHES %s's shields (%d destroyed)!" % [attacker_state["unit"].display_name, target_state["unit"].display_name, destroyed])
	_emit_event(target_state, "breach", destroyed, _resolve_side_for_state(target_state))


# Execute: if the target sits below the execute threshold of its max HP AFTER
# the base damage, deal bonus damage. Reaper directive raises the threshold via
# the per-state execute_threshold_pct hook.
func _apply_execute_bonus(attacker_state: Dictionary, target_state: Dictionary) -> void:
	if target_state.is_empty() or bool(target_state.get("dead", false)):
		return
	var threshold_pct: int = int(attacker_state.get("execute_threshold_pct", 25))
	var max_hp: int = maxi(int(target_state.get("max_hp", 1)), 1)
	if int(target_state.get("current_hp", 0)) * 100 >= max_hp * threshold_pct:
		return
	# BALANCE-TODO: execute bonus damage is a flat +8
	var bonus: int = _tuned_int("execute_bonus", 8)
	_log("%s EXECUTES %s for +%d!" % [attacker_state["unit"].display_name, target_state["unit"].display_name, bonus])
	_emit_event(target_state, "execute", bonus, _resolve_side_for_state(target_state))
	_damage_state(target_state, bonus, false, attacker_state)


# Detonate (per Kev 2026-07-06): finite Burn stacks burst for amount ×
# remaining turns and are consumed; a PERMANENT Burn adds exactly ONE tick's
# damage (its amount) and is NOT consumed — it keeps ticking. Payload Fuse
# (gear hook gear_detonate_bonus) makes the whole burst deal +50%.
# The old DETONATE_MAX_TURNS cap is removed with the sentinel multiply.

# PUBLIC single source for the burst math — the live Detonate pip preview
# (battle_card_view) reads this so the projection can't drift from combat.
func get_expected_detonate_burst(attacker_state: Dictionary, target_state: Dictionary) -> int:
	var burst: int = 0
	for stack_variant in target_state.get("burn_stacks", []):
		var stack: Dictionary = stack_variant
		if bool(stack.get("perm", false)):
			burst += int(stack["amt"])
		else:
			burst += int(stack["amt"]) * int(stack["turns_left"])
	if burst > 0 and bool(attacker_state.get("gear_detonate_bonus", false)):
		burst = int(ceil(float(burst) * 1.5))
	return burst


func _detonate_burn(attacker_state: Dictionary, target_state: Dictionary) -> void:
	if target_state.is_empty() or bool(target_state.get("dead", false)):
		return
	var burst: int = get_expected_detonate_burst(attacker_state, target_state)
	if burst <= 0:
		_log("%s's detonate fizzles - no burn on %s." % [attacker_state["unit"].display_name, target_state["unit"].display_name])
		return
	# Finite stacks are consumed; permanent stacks stay and keep ticking.
	var remaining_stacks: Array = []
	for stack_variant in target_state.get("burn_stacks", []):
		if bool((stack_variant as Dictionary).get("perm", false)):
			remaining_stacks.append(stack_variant)
	target_state["burn_stacks"] = remaining_stacks
	_refresh_burn_totals(target_state)
	if _forecast_only:
		var attacker_id: String = str(attacker_state.get("id", ""))
		_forecast_detonates[attacker_id] = int(_forecast_detonates.get(attacker_id, 0)) + burst
	_log("%s detonates the burn on %s for %d!" % [attacker_state["unit"].display_name, target_state["unit"].display_name, burst])
	_emit_event(target_state, "detonate", burst, _resolve_side_for_state(target_state))
	_damage_state(target_state, burst, false, attacker_state)
	# Smoldering: a detonation leaves a small burn behind on what it hit.
	if _has_trait(attacker_state, "afterburn") and not bool(target_state.get("dead", false)):
		_trait_fired(attacker_state, "the detonation leaves %d burn on %s." % [_trait_num(attacker_state, "burn", 1), target_state["unit"].display_name])
		_apply_burn(target_state, _trait_num(attacker_state, "burn", 1), _trait_num(attacker_state, "turns", 2))


# Chain: after the primary hit, the attack jumps to the lowest-HP other living
# enemy at 50% of the base damage (round down); "chain": 2 adds a second jump
# to the next lowest-HP enemy not yet hit. Chain Doctrine (relic hook
# chainExtraJump) adds one extra jump.
func _apply_chain_jumps(
	hero_state: Dictionary,
	ability_entry: Dictionary,
	primary_target: Dictionary,
	base_damage: int,
	ignores_shield: bool,
	shield_pierce: int
) -> void:
	var raw: Dictionary = ability_entry.get("raw", {})
	var jumps: int = int(raw.get("chain", 0))
	if jumps <= 0 or base_damage <= 0:
		return
	if has_relic("chainExtraJump"):
		jumps += 1
	# Conductor directive: this hero's Chains jump one extra target.
	if _has_directive(hero_state, "chainExtraJump"):
		jumps += 1
	# chain jump damage is 50% of base, round down (chain_ratio; set 0.6→0.5 in
	# Batch-1, Kev 2026-07-11 — see DECISIONS_RESOLVED #10).
	# Amplifier directive: chain hits carry the full base damage.
	var chain_damage: int = base_damage if _has_directive(hero_state, "chainFullDamage") else int(floor(float(base_damage) * _tuned_float("chain_ratio", 0.5)))
	# Charged: every jump of this hero's chains hits a little harder.
	var live_wire: int = _trait_num(hero_state, "amount", 1) if _has_trait(hero_state, "liveWire") else 0
	chain_damage += live_wire
	if chain_damage <= 0:
		return
	var hit_ids: Dictionary = {str(primary_target.get("id", "")): true}
	for _i in range(jumps):
		var next_target: Dictionary = _lowest_hp_state_excluding(_enemy_states, hit_ids)
		if next_target.is_empty():
			return
		hit_ids[str(next_target["id"])] = true
		if live_wire > 0:
			_trait_fired(hero_state, "the chain jump deals +%d." % live_wire, live_wire)
		_log("%s's attack chains to %s for %d." % [hero_state["unit"].display_name, next_target["unit"].display_name, chain_damage])
		_emit_event(next_target, "chain", chain_damage, "enemy")
		if _ward_blocks_hostile(next_target, [FirewallFeedback.CHAIN]):
			continue
		_damage_state(next_target, chain_damage, ignores_shield, hero_state, shield_pierce)


func _apply_enemy_ability(enemy_state: Dictionary, ability_entry: Dictionary, raw_roll: int = -1) -> void:
	_ability_ward_blocked_ids.clear()
	_ability_ward_block_notes.clear()
	_ability_rider_target_ids.clear()
	_ability_spike_carrier_ids.clear()
	_ability_trait_chips.clear()
	_ability_backup_ids.clear()
	_ability_cloaked_pick_id = ""
	var raw: Dictionary = ability_entry.get("raw", {})
	# One shared hero target for every hostile single-target component of this
	# ability (taunt override / assigned intent / personality fallback).
	var hostile_hero_target: Dictionary = {}
	if _ability_targets_single_hero(raw):
		# An attack that freezes one die (Geode Panther) goes for the hero with
		# the lowest die: the hit and the freeze land on the same unit (G-61).
		hostile_hero_target = _freeze_pick_hero_lowest_die(enemy_state) if attack_freezes_lowest_die(raw) else _resolve_enemy_hero_target(enemy_state)
		# Every hero cloaked: a single-target attack hits one at random (G-52).
		if hostile_hero_target.is_empty() and ability_is_single_target_attack(raw):
			hostile_hero_target = _random_cloaked_target(_hero_states, enemy_state)
	var damage: int = int(raw.get("dmg", 0))
	# Ferocity route modifier: enemy hits deal +2.
	if damage > 0 and _battle_modifier == "ferocity":
		damage += 2
	var heal: int = int(raw.get("heal", 0))
	var shield: int = int(raw.get("shield", 0))
	var shield_ally: int = int(raw.get("shieldAlly", 0))
	var burn_amount: int = int(raw.get("burn", 0))
	var burn_turns: int = int(raw.get("burnT", 0))

	if bool(raw.get("shieldAllyAll", false)) and shield_ally > 0:
		for es in _enemy_states:
			if not bool(es["dead"]):
				_add_shield_stack(es, shield_ally, true)
	else:
		if shield > 0:
			_add_shield_stack(enemy_state, shield, true)
		if shield_ally > 0:
			var enemy_ally: Dictionary = _find_living_enemy_ally_by_id(enemy_state, str(enemy_state.get("selected_target_id", "")))
			if enemy_ally.is_empty():
				enemy_ally = _first_living_enemy_ally(enemy_state)
			if enemy_ally.is_empty():
				enemy_ally = enemy_state
			if not enemy_ally.is_empty():
				_add_shield_stack(enemy_ally, shield_ally, true)

	if heal > 0:
		_heal_state(enemy_state, heal)

	# Dealing damage breaks the cloak, and that attack is an ambush (G-52): the
	# same rule the heroes get. No pierce.
	if damage > 0 and ambush_ready(enemy_state):
		damage = _ambush_from_cloak(enemy_state, damage)

	# Rampage lasts until the unit's next turn (G-60): this turn spends it,
	# whether or not it attacks. A grant later in this same ability is a new
	# rampage for the turn after.
	var rampaging: bool = _take_rampage(enemy_state)
	var rampage_used: bool = false

	if damage > 0:
		var hits_all_heroes: bool = bool(raw.get("blastAll", false))
		var should_wipe_shields: bool = bool(raw.get("wipeShields", false))
		var scaled_damage: int = int(round(float(damage) * float(enemy_state.get("dmg_scale", 1.0))))
		var final_damage: int = scaled_damage
		if final_damage > 0 and rampaging:
			final_damage = scaled_damage * 2
			rampage_used = true
			_log("%s triggers Rampage! (2× damage)" % enemy_state["unit"].display_name)
			# Presentation-only marker (primer first-sighting + feedback hook);
			# floats/sfx ignore unknown types, no state or RNG touched.
			_emit_event(enemy_state, "rampage", final_damage, "enemy")
		if bool(raw.get("packBonus", false)) and final_damage > 0:
			# Pack Bonus: +PACK_BONUS_PER_MEMBER per OTHER living pack member of the SAME KIND. "Kind"
			# is the enemy_type (kit) — Obsidian and Slag hounds both count as
			# beastWolf pack. Compare enemy_type, not the per-instance id: instance
			# ids are unique (`beastWolf#1` vs `beastWolf#2`) so the old id compare
			# was never true and the bonus never fired (fix 2026-07-08).
			var pack_kind: String = str(enemy_state["unit"].enemy_type)
			var pack_count: int = 0
			for es in _enemy_states:
				if es == enemy_state:
					continue
				if not es["dead"] and str(es["unit"].enemy_type) == pack_kind:
					pack_count += 1
			if pack_count > 0:
				var pack_gain: int = pack_count * pack_bonus_per_member()
				final_damage += pack_gain
				_log("%s pack bonus +%d (%d fellow pack member(s))." % [enemy_state["unit"].display_name, pack_gain, pack_count])
				# Presentation-only marker (primer first-sighting); floats/sfx
				# ignore unknown types, no state or RNG touched.
				_emit_event(enemy_state, "pack_bonus", pack_gain, "enemy")
		final_damage = int(floor(float(final_damage) * _get_enemy_dmg_mult()))
		if should_wipe_shields:
			_wipe_all_hero_shields(enemy_state)
		var attack_connected: bool = false
		# What a Firewall on the target cancels from this attack (the log names it).
		var attack_effects: Array = [FirewallFeedback.DAMAGE]
		if burn_amount > 0 and burn_turns > 0:
			attack_effects.append(FirewallFeedback.BURN)
		if hits_all_heroes:
			for hero_state in _hero_states:
				if bool(hero_state["dead"]):
					continue
				if _ward_blocks_hostile(hero_state, attack_effects):
					continue
				attack_connected = true
				_break_cloak_on_aoe(hero_state)
				_damage_state(hero_state, final_damage, false, enemy_state)
				_apply_burn_from_enemy(enemy_state, hero_state, burn_amount, burn_turns)
			var lifesteal_pct: int = int(raw.get("lifestealPct", 0))
			if lifesteal_pct > 0 and final_damage > 0:
				var heal_amount: int = int(floor(float(final_damage) * float(lifesteal_pct) / 100.0))
				if heal_amount > 0:
					_heal_state(enemy_state, heal_amount)
					_log("%s lifesteals %d HP." % [enemy_state["unit"].display_name, heal_amount])
		else:
			var target_hero: Dictionary = hostile_hero_target
			if target_hero.is_empty():
				_log("%s finds no visible target - the attack fizzles." % enemy_state["unit"].display_name)
			# A blocked single-target hit never connects, so its siphon is lost too.
			if int(raw.get("siphon", 0)) > 0:
				attack_effects.append(FirewallFeedback.SIPHON)
			if not target_hero.is_empty() and not _ward_blocks_hostile(target_hero, attack_effects):
				attack_connected = true
				_damage_state(target_hero, final_damage, false, enemy_state)
				_apply_burn_from_enemy(enemy_state, target_hero, burn_amount, burn_turns)
				var lifesteal_pct: int = int(raw.get("lifestealPct", 0))
				if lifesteal_pct > 0 and final_damage > 0:
					var heal_amount: int = int(floor(float(final_damage) * float(lifesteal_pct) / 100.0))
					if heal_amount > 0:
						_heal_state(enemy_state, heal_amount)
						_log("%s lifesteals %d HP." % [enemy_state["unit"].display_name, heal_amount])

		# Siphon (enemy-only): on hit, drain N Protocol from the pool (floor 0
		# applied by battle_scene when the drain lands).
		var siphon_amount: int = int(raw.get("siphon", 0))
		if siphon_amount > 0 and attack_connected:
			_pending_protocol_drain += siphon_amount
			_log("%s SIPHONS %d Protocol!" % [enemy_state["unit"].display_name, siphon_amount])
			_emit_event(enemy_state, "siphon", siphon_amount, "enemy")

	if damage <= 0 and bool(raw.get("wipeShields", false)):
		_wipe_all_hero_shields(enemy_state)

	if damage <= 0 and burn_amount > 0:
		if not hostile_hero_target.is_empty() and not _ward_blocks_hostile(hostile_hero_target, [FirewallFeedback.BURN]):
			_apply_burn_from_enemy(enemy_state, hostile_hero_target, burn_amount, burn_turns)

	# RFE on heroes (roll debuff from enemies using rfm/rfmT keys)
	var rfm_amount: int = int(raw.get("rfm", 0))
	var rfm_turns: int = int(raw.get("rfmT", 1))
	if rfm_amount > 0:
		if not hostile_hero_target.is_empty() and not _ward_blocks_hostile(hostile_hero_target, [FirewallFeedback.ROLL_PENALTY]):
			# Commanding: this unit's roll penalties last longer.
			if _has_trait(enemy_state, "compel"):
				rfm_turns += _trait_num(enemy_state, "rounds", 1)
				_trait_fired(enemy_state, "the roll penalty on %s lasts %d extra round." % [hostile_hero_target["unit"].display_name, _trait_num(enemy_state, "rounds", 1)])
			_add_rfe_stack(hostile_hero_target, rfm_amount, rfm_turns)

	# ERB: enemy roll buff
	var erb_amount: int = int(raw.get("erb", 0))
	var erb_turns: int = int(raw.get("erbT", 1))
	var erb_all: bool = bool(raw.get("erbAll", false))
	if erb_amount > 0:
		# Enemy self-buff cast during the enemy's own resolution — its roll this
		# round is already spent, so this shapes FUTURE rolls only (false).
		if erb_all:
			for es in _enemy_states:
				if not es["dead"]:
					_add_roll_buff(es, erb_amount, erb_turns, false)
		else:
			_add_roll_buff(enemy_state, erb_amount, erb_turns, false)

	# Freeze hero dice (freeze = repeat, per Kev 2026-07-06): the crusted die
	# repeats its face on the hero's next N rolls. Enemy AI freeze always
	# targets the hero's LOWEST revealed die — deterministic, no randi — so the
	# squad's weakest result is the one that repeats (taunt still overrides).
	var enemy_freeze_one: int = int(raw.get("freezeEnemyDice", 0))
	var enemy_freeze_all: int = int(raw.get("freezeAllEnemyDice", 0))
	var enemy_freeze_flavor: String = str(raw.get("freeze_flavor", "ice"))
	if enemy_freeze_all > 0:
		for hero_state in _hero_states:
			if not hero_state["dead"] and not _ward_blocks_hostile(hero_state, [FirewallFeedback.FREEZE]):
				_freeze_die_state(hero_state, enemy_freeze_all, enemy_freeze_flavor)
	elif enemy_freeze_one > 0:
		# With an attack, the freeze rides the unit that was hit (G-61).
		var freeze_rider_target: Dictionary = hostile_hero_target if attack_freezes_lowest_die(raw) else _freeze_pick_hero_lowest_die(enemy_state)
		if not freeze_rider_target.is_empty() and not _ward_blocks_hostile(freeze_rider_target, [FirewallFeedback.FREEZE]):
			_freeze_die_state(freeze_rider_target, enemy_freeze_one, enemy_freeze_flavor)

	# Rampage grants (self or all enemies). On or off: a unit that is already
	# rampaging gains nothing more (G-60).
	var grant_rampage: int = int(raw.get("grantRampage", 0))
	var grant_rampage_all: bool = bool(raw.get("grantRampageAll", false))
	var regrants_self: bool = grant_rampage > 0 or grant_rampage_all
	if rampaging and not rampage_used and not regrants_self:
		_expire_rampage(enemy_state)
	if grant_rampage_all:
		for es in _enemy_states:
			_grant_rampage(es)
	elif grant_rampage > 0:
		_grant_rampage(enemy_state)

	# Ward: block the next ability that targets this enemy, then break.
	if bool(raw.get("ward", false)):
		_apply_ward(enemy_state)

	# Jam hero dice: cap the targeted hero's (or every hero's) next roll at 10.
	if bool(raw.get("jamAll", false)):
		for hero_state in _hero_states:
			if not hero_state["dead"] and not _ward_blocks_hostile(hero_state, [FirewallFeedback.JAM]):
				_apply_jam(hero_state, JAM_CAP, true)
	elif bool(raw.get("jam", false)):
		if not hostile_hero_target.is_empty() and not _ward_blocks_hostile(hostile_hero_target, [FirewallFeedback.JAM]):
			_apply_jam(hostile_hero_target, JAM_CAP, true)

	# Rewrite hero dice (Synod): force the targeted hero's next roll to 3.
	if bool(raw.get("rewrite", false)):
		if not hostile_hero_target.is_empty() and not _ward_blocks_hostile(hostile_hero_target, [FirewallFeedback.REWRITE]):
			_apply_rewrite(hostile_hero_target, true)

	# Hijack (enemy-only): this enemy's next roll copies the heroes' current
	# highest die.
	if bool(raw.get("hijack", false)):
		enemy_state["hijack_pending"] = true
		enemy_state["hijack_skip_next_tick"] = true
		_log("%s locks onto the squad's dice - its next roll will HIJACK the highest." % enemy_state["unit"].display_name)
		_emit_event(enemy_state, "hijack_primed", 0, "enemy")

	# Cloak (self): Geode Panther re-cloaks on recharge; Forked Double reforks.
	if bool(raw.get("cloak", false)):
		enemy_state["cloaked"] = true
		_log("%s fades from view (cloaked)." % enemy_state["unit"].display_name)
		_emit_event(enemy_state, "cloak", 0, "enemy")

	# Flickering: rolling the unit's first band cloaks it.
	if _has_trait(enemy_state, "blink") and _is_first_band(enemy_state, ability_entry) \
			and not bool(enemy_state.get("cloaked", false)) and not bool(enemy_state.get("dead", false)):
		enemy_state["cloaked"] = true
		_trait_fired(enemy_state, "%s fades from view (cloaked)." % enemy_state["unit"].display_name)
		_emit_event(enemy_state, "cloak", 0, "enemy")

	# Enemy-side Taunt (formerly Lure, Accretion): the targeted hero can only
	# target this enemy next turn. Internal state keeps the lured_by split.
	if bool(raw.get("taunt", false)):
		if not hostile_hero_target.is_empty() and not _ward_blocks_hostile(hostile_hero_target, [FirewallFeedback.TAUNT]):
			hostile_hero_target["lured_by_id"] = str(enemy_state["id"])
			hostile_hero_target["lure_skip_next_tick"] = true
			_log("%s TAUNTS %s - next turn they can only strike back!" % [enemy_state["unit"].display_name, hostile_hero_target["unit"].display_name])
			_emit_event(hostile_hero_target, "taunt", 0, "hero")

	# Spike: heroes that damage this enemy next hero phase take N back. Granted
	# during the enemy phase, so it survives the imminent round-end tick to
	# cover exactly one hero phase (same asymmetry as shields).
	var enemy_spike: int = int(raw.get("spike", 0))
	if enemy_spike > 0:
		enemy_state["spike"] = maxi(int(enemy_state.get("spike", 0)), enemy_spike)
		enemy_state["spike_skip_next_tick"] = true
		_log("%s bristles with spike %d." % [enemy_state["unit"].display_name, enemy_spike])
		_emit_event(enemy_state, "spike_up", enemy_spike, "enemy")

	# Taunt: force all heroes to target this enemy next player phase
	if bool(raw.get("enemySelfTaunt", false)):
		for es in _enemy_states:
			es["taunting"] = false
		enemy_state["taunting"] = true
		_log("%s is taunting - all heroes must target it!" % enemy_state["unit"].display_name)

	# Summon: fires when an eligible enemy's overload ability resolves (final die
	# face 20; no natural-20 check — ruling NK-02). Synod and Accretion summon too.
	var summon_chance: int = int(raw.get("summonChance", 0))
	var summon_name: String = str(raw.get("summonName", ""))
	if summon_chance > 0 and summon_name != "":
		_try_emit_enemy_summon(enemy_state, ability_entry, raw_roll, summon_chance, summon_name)


# ── Unit traits (G-62, Kev 2026-10-09) ───────────────────────────────────────
# One always-on rule per unit, the same code for heroes and enemies. The data
# is traits.data.json (scripts/battle/unit_traits.gd); a unit's state carries
# its trait id and the numbers are read from the unit. Each rule sits where the
# thing it changes is resolved and asks `_has_trait`. The four round-start
# traits need the dice, so they are in BattleEngine.apply_round_start_traits.

# The Protocol the player holds as this round resolves (Redline reads it).
# BattleEngine.resolve_step and the damage forecast set it; combat never
# changes it.
var protocol_pool: int = 0

# One chip per trait per unit per ability, however many times it applied.
var _ability_trait_chips: Dictionary = {}


func _has_trait(state: Dictionary, trait_id: String) -> bool:
	return not _traits_off() and not state.is_empty() and str(state.get("trait", "")) == trait_id


# True when no trait may do anything: the `traits` gate's `off` break, or a
# dry run that is blind to traits (the `trait preview` gate: its `trait_blind`
# break, and the check it makes that each of its cases depends on a trait).
func _traits_off() -> bool:
	return trait_break() == "off" or (_forecast_only and (forecast_blind_to_traits or preview_break() == "trait_blind"))


func _trait_num(state: Dictionary, key: String, default_value: int) -> int:
	return int(UnitTraits.of_unit(state.get("unit")).get(key, default_value))


func _trait_name(state: Dictionary) -> String:
	return str(UnitTraits.of_unit(state.get("unit")).get("name", ""))


# A trait just did something: one log line every time, and one `trait` event
# (the chip on the unit) per ability.
func _trait_fired(state: Dictionary, what: String, amount: int = 0) -> void:
	_log("%s: %s" % [_trait_name(state), what])
	var chip_key: String = "%s|%s" % [str(state.get("id", "")), str(state.get("trait", ""))]
	if _ability_trait_chips.has(chip_key) or trait_break() == "no_chip":
		return
	_ability_trait_chips[chip_key] = true
	_emit_event(state, "trait", amount, _resolve_side_for_state(state))
	(_round_events.back() as Dictionary)["trait_name"] = _trait_name(state)


# PUBLIC, for BattleEngine's round-start traits: the same test and the same
# numbers the rules above use.
func has_trait(state: Dictionary, trait_id: String) -> bool:
	return _has_trait(state, trait_id)


func trait_num(state: Dictionary, key: String, default_value: int) -> int:
	return _trait_num(state, key, default_value)


# PUBLIC: a round-start trait's shield. Returns the shield gained.
func apply_trait_shield(state: Dictionary, amount: int) -> int:
	if amount <= 0 or bool(state.get("dead", false)):
		return 0
	return _add_shield_stack(state, amount, false, false)


# Deliberate breaks for the `traits` gate (scripts/debug/traits_test.gd; never
# set by the game):
#   off          no trait does anything
#   no_chip      a trait applies but shows no chip
#   frozen_dice  Static and Zealous move frozen dice
#   litany_first Zealous fires before Static
#   boss_trait   every unit without a trait is given one when the data loads
const TRAIT_BREAK_ARG := "--trait-break="
static var _trait_break: String = "?"


static func trait_break() -> String:
	if _trait_break == "?":
		_trait_break = ""
		if OS.is_debug_build():
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with(TRAIT_BREAK_ARG):
					_trait_break = arg.trim_prefix(TRAIT_BREAK_ARG)
	return _trait_break


# True when `ability_entry` is the unit's first roll window (Bloodlust, Flickering).
func _is_first_band(state: Dictionary, ability_entry: Dictionary) -> bool:
	var ranges: Array = state["unit"].dice_ranges
	return not ranges.is_empty() and str((ranges[0] as Dictionary).get("zone", "")) == str(ability_entry.get("zone", "?")) \
		and str((ranges[0] as Dictionary).get("ability_name", "")) == str(ability_entry.get("ability_name", "?"))


# Watchful: `heal` on `target`, raised when it is the lowest-HP ally.
func _triage_heal(healer_state: Dictionary, target: Dictionary, lowest: Dictionary, heal: int) -> int:
	if lowest.is_empty() or target != lowest or bool(target.get("dead", false)):
		return heal
	var bonus: int = _trait_num(healer_state, "amount", 3)
	_trait_fired(healer_state, "+%d healing on %s, the lowest-HP ally." % [bonus, target["unit"].display_name], bonus)
	return heal + bonus


# Spectral: the jam just applied to `target` holds for `extra` more rolls.
func _extend_jam(hero_state: Dictionary, target: Dictionary, extra: int) -> void:
	if extra <= 0 or int(target.get("jam_cap", 0)) <= 0:
		return
	target["jam_extra_rounds"] = maxi(int(target.get("jam_extra_rounds", 0)), extra)
	_trait_fired(hero_state, "the jam on %s lasts %d extra round." % [target["unit"].display_name, extra])


# Silent: the ambush killed its target, so the cloak it broke is put back
# and the beat that showed it leaving is dropped.
func _keep_cloak_after_kill(hero_state: Dictionary, killed: Dictionary, events_from: int) -> void:
	if bool(hero_state.get("cloaked", false)):
		return
	hero_state["cloaked"] = true
	for index in range(_round_events.size() - 1, events_from - 1, -1):
		var event: Dictionary = _round_events[index]
		if str(event.get("type", "")) == "decloak" and str(event.get("target_id", "")) == str(hero_state["id"]):
			_round_events.remove_at(index)
			break
	_trait_fired(hero_state, "%s killed %s from cloak and stays cloaked." % [hero_state["unit"].display_name, killed["unit"].display_name])


# Corrosive: a burn this enemy applies ignores shields when it ticks.
func _apply_burn_from_enemy(enemy_state: Dictionary, target_state: Dictionary, amount: int, turns: int) -> void:
	var corrosive: bool = _has_trait(enemy_state, "corrosive") and amount > 0 and turns > 0 and not bool(target_state.get("dead", false))
	_apply_burn(target_state, amount, turns, corrosive)
	if corrosive:
		_trait_fired(enemy_state, "the burn on %s ignores shields." % target_state["unit"].display_name)


# Fervent: every living unit with it heals when a burn ticks on anyone.
func _apply_kindle_for_tick(ticked_state: Dictionary) -> void:
	for kindler in _hero_states + _enemy_states:
		if not _has_trait(kindler, "kindle") or bool(kindler.get("dead", false)):
			continue
		if int(kindler["current_hp"]) >= int(kindler["max_hp"]):
			continue
		_trait_fired(kindler, "%s heals %d as the burn on %s ticks." % [kindler["unit"].display_name, _trait_num(kindler, "amount", 3), ticked_state["unit"].display_name])
		_heal_state(kindler, _trait_num(kindler, "amount", 3))


# Vigilant: `hit_state` was just hit by an attack; each living ally of it with
# the trait gains shield. Once per ability for each unit hit.
var _ability_backup_ids: Dictionary = {}


func _apply_backup_for_hit(hit_state: Dictionary) -> void:
	var hit_id: String = str(hit_state.get("id", ""))
	if _ability_backup_ids.has(hit_id):
		return
	_ability_backup_ids[hit_id] = true
	var side: Array = _hero_states if _is_hero_state(hit_state) else _enemy_states
	for ally in side:
		if ally == hit_state or bool(ally.get("dead", false)) or not _has_trait(ally, "backup"):
			continue
		var gained: int = _add_shield_stack(ally, _trait_num(ally, "amount", 2), false, false)
		if gained > 0:
			_trait_fired(ally, "%s gains %d shield as %s is hit." % [ally["unit"].display_name, gained, hit_state["unit"].display_name], gained)
			_emit_event(ally, "shield", gained, _resolve_side_for_state(ally))


# The traits that answer a death: Relentless (the killer's), Volatile (the
# dead unit's) and Feral (its surviving allies').
func _apply_death_traits(dead_state: Dictionary, killer_state: Dictionary) -> void:
	var dead_is_hero: bool = _is_hero_state(dead_state)
	var allies: Array = _hero_states if dead_is_hero else _enemy_states
	var foes: Array = _enemy_states if dead_is_hero else _hero_states
	# Relentless: the lowest-HP unit left on the dead unit's side is marked.
	if _has_trait(killer_state, "cleanKill") and not bool(killer_state.get("dead", false)) and killer_state != dead_state:
		var next_mark: Dictionary = _lowest_hp_state(allies)
		if not next_mark.is_empty() and not bool(next_mark.get("marked", false)):
			_trait_fired(killer_state, "%s marks %s, the lowest-HP enemy." % [killer_state["unit"].display_name, next_mark["unit"].display_name])
			_apply_mark(next_mark)
	# Volatile: the dead unit hits every unit on the other side.
	if _has_trait(dead_state, "discharge"):
		var discharge: int = _trait_num(dead_state, "amount", 4)
		_trait_fired(dead_state, "%s dies and deals %d to each hero." % [dead_state["unit"].display_name, discharge], discharge)
		for foe in foes:
			if not bool(foe.get("dead", false)):
				_damage_state(foe, discharge)
	# Feral: every surviving ally with the trait gains rampage.
	for ally in allies:
		if ally == dead_state or bool(ally.get("dead", false)) or not _has_trait(ally, "packRage"):
			continue
		if _grant_rampage(ally):
			_trait_fired(ally, "%s gains rampage as %s falls." % [ally["unit"].display_name, dead_state["unit"].display_name])


# Pack bonus (G-60): a `packBonus` attack deals this much more for each OTHER
# living pack member of the same kind. Was 1 until 2026-10-09. The ability
# text, the keyword and the primer print this number; the `rampage` gate fails
# when they disagree with it.
const PACK_BONUS_PER_MEMBER := 3


func pack_bonus_per_member() -> int:
	if rampage_break() == "pack_one":
		return 1
	return _tuned_int("pack_bonus_per_member", PACK_BONUS_PER_MEMBER)


# ── Rampage (G-60, Kev 2026-10-09) ───────────────────────────────────────────
# Rampage is on or off (`rampage_charges` is 0 or 1; the name is kept for the
# chip and the saves). It lasts until the unit's next turn and that turn spends
# it: an attack deals double damage, anything else lets it go. It does not
# stack: a grant to a unit that is already rampaging changes nothing.

# Gives `state` rampage. False when it already had it (or is down).
func _grant_rampage(state: Dictionary) -> bool:
	if state.is_empty() or bool(state.get("dead", false)):
		return false
	if int(state.get("rampage_charges", 0)) > 0 and rampage_break() != "stack":
		_log("%s is already rampaging. Rampage does not stack." % state["unit"].display_name)
		return false
	state["rampage_charges"] = int(state.get("rampage_charges", 0)) + 1
	_log("%s gains rampage." % state["unit"].display_name)
	_emit_event(state, "rampage_up", 1, _resolve_side_for_state(state))
	return true


# The start of `state`'s turn: takes its rampage off and says whether it had it.
func _take_rampage(state: Dictionary) -> bool:
	var charges: int = int(state.get("rampage_charges", 0))
	if charges <= 0:
		return false
	state["rampage_charges"] = charges - 1 if rampage_break() == "stack" else 0
	return true


# A turn that did not attack: the rampage is gone and the chip leaves.
func _expire_rampage(state: Dictionary) -> void:
	if rampage_break() == "keep":
		state["rampage_charges"] = 1
		return
	_log("%s's rampage ends unused." % state["unit"].display_name)
	_emit_event(state, "rampage_end", 0, _resolve_side_for_state(state))


# Deliberate breaks for the `rampage` gate (scripts/debug/rampage_test.gd; never
# set by the game):
#   stack  grants add up and each attack spends one (the old rule)
#   keep   a turn that does not attack keeps the rampage (the old rule)
#   pack_one  the pack bonus is +1 per pack member again
const RAMPAGE_BREAK_ARG := "--rampage-break="
static var _rampage_break: String = "?"


static func rampage_break() -> String:
	if _rampage_break == "?":
		_rampage_break = ""
		if OS.is_debug_build():
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with(RAMPAGE_BREAK_ARG):
					_rampage_break = arg.trim_prefix(RAMPAGE_BREAK_ARG)
	return _rampage_break


# ── Cloak ambush (G-52, Kev 2026-10-08) ──────────────────────────────────────
# The attack that breaks a unit's cloak is an ambush: its damage is multiplied
# by AMBUSH_MULT (round up, like Mark). One rule, both sides. It is paid by the
# cloak itself, so it lands exactly once per cloak and never for a unit that is
# not cloaked when it attacks (a cloak torn off by an area hit pays nothing).
# 1.5 after the 2026-10-08 sweep: at 2.0 the Ghost line became the best hero by
# a wide margin and an enemy with Rampage could hit for 64.
const AMBUSH_MULT := 1.5


func ambush_mult() -> float:
	return _tuned_float("ambush_mult", AMBUSH_MULT)


# True while the unit's next attack would be an ambush. The card chip and the
# inspect line read this, so the screen and the engine cannot disagree.
static func ambush_ready(state: Dictionary) -> bool:
	if cloak_ambush_break() == "always":
		return not bool(state.get("dead", false))
	return bool(state.get("cloaked", false)) and not bool(state.get("dead", false))


# The bonus as the player reads it: "double damage" at 2, "+50% damage" at 1.5.
static func ambush_bonus_text(mult: float = AMBUSH_MULT) -> String:
	if is_equal_approx(mult, 2.0):
		return "double damage"
	return "+%d%% damage" % int(round((mult - 1.0) * 100.0))


# What the cloak chip shows beside the icon: "+50%" at 1.5, "x2" at 2.
static func ambush_chip_text(mult: float = AMBUSH_MULT) -> String:
	if is_equal_approx(mult, roundf(mult)):
		return "x%d" % int(roundf(mult))
	return "+%d%%" % int(round((mult - 1.0) * 100.0))


# What an attack of `damage` deals when `attacker_state` makes it: the ambush
# damage while its cloak is up, `damage` otherwise. The engine and the enemy
# phase's HP preview both read this.
func ambush_damage(attacker_state: Dictionary, damage: int) -> int:
	if damage <= 0 or not ambush_ready(attacker_state) or cloak_ambush_break() == "no_bonus":
		return damage
	return int(ceil(float(damage) * ambush_mult()))


# Breaks `attacker_state`'s cloak for an attack of `damage` and returns the
# ambush damage. Call only when the attack deals damage and the unit is cloaked.
func _ambush_from_cloak(attacker_state: Dictionary, damage: int) -> int:
	var boosted: int = ambush_damage(attacker_state, damage)
	if cloak_ambush_break() != "keep_cloak":
		attacker_state["cloaked"] = false
	_log("%s ambushes from cloak for %s." % [attacker_state["unit"].display_name, ambush_bonus_text(ambush_mult())])
	_emit_event(attacker_state, "decloak", 0, _resolve_side_for_state(attacker_state))
	return boosted


# All-cloaked fallback (G-52): the cloaked unit this ability's single-target
# ATTACK was sent to at random. Every hostile component of that attack shares
# it; cleared at the start of every ability.
var _ability_cloaked_pick_id: String = ""


# A single-target attack with every candidate cloaked hits one of them at
# random instead of fizzling (seeded pick, INVARIANTS #1). The cloak of the
# unit it hits stays up. Returns {} when a visible target exists or nobody is
# left to hit.
func _random_cloaked_target(states: Array, attacker_state: Dictionary) -> Dictionary:
	var cloaked: Array = []
	for state_variant in states:
		var state: Dictionary = state_variant
		if bool(state.get("dead", false)):
			continue
		if not bool(state.get("cloaked", false)):
			return {}
		cloaked.append(state)
	if cloaked.is_empty() or cloak_ambush_break() == "fizzle":
		return {}
	var pick: Dictionary = cloaked[0 if cloak_ambush_break() == "first" else _rand_index(cloaked.size())]
	_log("Every target is cloaked. %s hits %s at random." % [attacker_state["unit"].display_name, pick["unit"].display_name])
	return pick


# Cloak: untargetable by hostile single-target abilities. Resolves the selected
# target, retargeting to the first living non-cloaked unit when the pick is
# invalid or cloaked. When every candidate is cloaked: the unit this ability's
# attack was sent to at random (_ability_cloaked_pick_id), else {} (an ability
# that does not attack finds no target).
func _hostile_single_target(states: Array, selected_id: String, attacker_state: Dictionary = {}) -> Dictionary:
	# Enemy-side Taunt (internal lured_by state): a taunted hero must aim its
	# hostile picks at the taunter while it lives.
	if not attacker_state.is_empty():
		var lured_by: String = str(attacker_state.get("lured_by_id", ""))
		if lured_by != "":
			var lurer: Dictionary = _find_target_by_id(states, lured_by)
			if not lurer.is_empty() and not bool(lurer.get("cloaked", false)):
				return lurer
	var target: Dictionary = _find_target_by_id(states, selected_id)
	if not target.is_empty() and not bool(target.get("cloaked", false)):
		return target
	for state_variant in states:
		var state: Dictionary = state_variant
		if not state["dead"] and not bool(state.get("cloaked", false)):
			return state
	return _find_target_by_id(states, _ability_cloaked_pick_id)


# AoE contact: the hit lands normally and the cloak breaks.
func _break_cloak_on_aoe(state: Dictionary) -> void:
	if bool(state.get("cloaked", false)):
		state["cloaked"] = false
		_log("%s's cloak is torn away by the blast!" % state["unit"].display_name)
		_emit_event(state, "decloak", 0, _resolve_side_for_state(state))


# Returns the HP damage actually dealt (after reduction / shields) so
# callers like Leech can react to it.
func _damage_state(
	state: Dictionary,
	amount: int,
	ignore_shield: bool = false,
	attacker_state: Dictionary = {},
	shield_pierce: int = 0
) -> int:
	if state.is_empty() or state["dead"] or amount <= 0:
		return 0

	# Illusory: the first hit against this unit each battle is negated. A hit is
	# an attack (it has an attacker); burn ticks and items are not.
	if _has_trait(state, "decoy") and not attacker_state.is_empty() and not bool(state.get("decoy_spent", false)):
		state["decoy_spent"] = true
		_trait_fired(state, "the first hit on %s is negated." % state["unit"].display_name)
		return 0

	# Pierce visibly resolving: shielded target, damage ignores the shield.
	# Feedback/primer marker only — no combat effect (float text is empty).
	if ignore_shield and _get_total_shield(state) > 0:
		_emit_event(state, "pierce", 0, _resolve_side_for_state(state))

	var hp_before: int = int(state["current_hp"])

	# SPITEFUL targeting: enemies remember the hero who most recently damaged
	# them (any connecting hero hit, even if fully shield-absorbed); cleared
	# when that hero dies (_on_unit_killed).
	if not _is_hero_state(state) and not attacker_state.is_empty() and _is_hero_state(attacker_state):
		state["last_attacker_id"] = str(attacker_state["id"])

	# Cloak no longer dodges here — cloaked units are untargetable by hostile
	# single-target abilities (call sites retarget) and AoE hits break the
	# cloak at the AoE loop before calling in.

	# Gear: dmgReduction for hero states
	if _is_hero_state(state):
		var reduction: int = int(state.get("gear_dmg_reduction", 0))
		# Ironclad directive: while taunting, incoming hits are blunted.
		if bool(state.get("taunting", false)) and _has_directive(state, "tauntDamageReduction"):
			reduction += _directive_value(state, "amount", 2)
		# Anchored: takes less damage while taunting.
		if bool(state.get("taunting", false)) and _has_trait(state, "anchor"):
			reduction += _trait_num(state, "amount", 2)
			_trait_fired(state, "%s takes %d less damage while taunting." % [state["unit"].display_name, _trait_num(state, "amount", 2)])
		if reduction > 0:
			amount = maxi(0, amount - reduction)
			if amount == 0:
				return 0

	# Mark: the next hit on this target deals +50% (round up), then the Mark is
	# consumed. Only real attacks (attacker present) consume it — burn ticks and
	# aura chip damage leave the Mark standing.
	state["mark_consumed_this_hit"] = false
	if bool(state.get("marked", false)) and not attacker_state.is_empty() and not _echo_pass_active:
		amount = int(ceil(float(amount) * 1.5))
		state["marked"] = false
		state["mark_consumed_this_hit"] = true
		_log("%s's mark is consumed - the hit deals +50%% (%d)!" % [state["unit"].display_name, amount])
		_emit_event(state, "mark_consumed", amount, _resolve_side_for_state(state))

	# Flat vs-state riders fire once per ABILITY per target (NK-06), so a
	# multi-packet ability (base + execute + detonate) can't stack them. Keyed by
	# target id; blastAll still rides each distinct target once.
	var rider_target_id: String = str(state.get("id", ""))
	if not _is_hero_state(state) and not attacker_state.is_empty() and not _ability_rider_target_ids.has(rider_target_id):
		# Cold Logic relic: enemies with frozen dice take +4 damage from attacks.
		if int(state.get("die_freeze_turns", 0)) > 0 and has_relic("frozenBonusDamage"):
			var cold_bonus: int = int(_get_relic_value("frozenBonusDamage", "amount", 4))
			amount += cold_bonus
			_log("Cold Logic: +%d against the frozen die." % cold_bonus)
		# Attacker directives: Deep Cuts (vs Burning) and Shatterpoint (vs frozen).
		if _is_hero_state(attacker_state):
			if int(state.get("burn", 0)) > 0 and _has_directive(attacker_state, "bonusVsBurning"):
				var cuts_bonus: int = _directive_value(attacker_state, "amount", 3)
				amount += cuts_bonus
				_log("Deep Cuts: +%d against the burning target." % cuts_bonus)
			if int(state.get("die_freeze_turns", 0)) > 0 and _has_directive(attacker_state, "bonusVsFrozen"):
				var shatter_bonus: int = _directive_value(attacker_state, "amount", 6)
				amount += shatter_bonus
				_log("Shatterpoint: +%d against the frozen die." % shatter_bonus)
		# Zero-Day: a die Nullwire rewrote makes its unit take more from
		# attacks until the rewrite ends.
		if int(state.get("zero_day", 0)) > 0 and not _traits_off():
			amount += int(state["zero_day"])
			_log("%s: +%d against the rewritten %s." % [UnitTraits.name_of("zeroDay"), int(state["zero_day"]), state["unit"].display_name])
		_ability_rider_target_ids[rider_target_id] = true

	# Spike triggers on any damaging attempt that connects this round; read it
	# before the hit possibly downs this unit and clears its statuses.
	var spike_retaliation: int = int(state.get("spike", 0))
	# Vengeful (while taunting) and Barbed (always, against heroes) hit an
	# attacker back even with no spike up; with one, they add to it.
	var trait_spike: int = 0
	if not attacker_state.is_empty():
		if _has_trait(state, "retaliate") and bool(state.get("taunting", false)):
			trait_spike = _trait_num(state, "amount", 2)
		elif _has_trait(state, "barbed") and _is_hero_state(attacker_state):
			trait_spike = _trait_num(state, "amount", 2)
	spike_retaliation += trait_spike

	# Vigilant: a unit with this trait gains shield when one of its allies is
	# hit by an attack. Once per ability for each ally hit.
	if not attacker_state.is_empty():
		_apply_backup_for_hit(state)

	var remaining_damage: int = amount
	var pierce_budget: int = shield_pierce

	var total_absorbed: int = 0
	if ignore_shield:
		if int(state.get("shield", 0)) > 0:
			_log("%s's shield is pierced." % state["unit"].display_name)
	elif int(state.get("shield", 0)) > 0 or not state.get("shield_stacks", []).is_empty():
		var stacks: Array = state.get("shield_stacks", [])
		var i: int = 0
		while i < stacks.size() and remaining_damage > 0:
			var stack: Dictionary = stacks[i]
			var available: int = int(stack["amt"])
			if pierce_budget > 0:
				var pierced: int = mini(available, pierce_budget)
				pierce_budget -= pierced
				available -= pierced
			var absorbed: int = mini(available, remaining_damage)
			stack["amt"] = available - absorbed
			remaining_damage -= absorbed
			total_absorbed += absorbed
			i += 1

		var surviving_stacks: Array = []
		for stack in stacks:
			if int(stack["amt"]) > 0:
				surviving_stacks.append(stack)
		state["shield_stacks"] = surviving_stacks
		state["shield"] = _get_total_shield(state)

	if total_absorbed > 0:
		_log("%s absorbs %d damage with shields." % [state["unit"].display_name, total_absorbed])
		_emit_event(state, "block", total_absorbed, _resolve_side_for_state(state))

	# Spike: the attacker takes N for connecting with this unit this round —
	# even when shields ate the whole hit. Retaliation damage carries no
	# attacker, so two spiked units can't loop. Fires once per ABILITY per
	# carrier (NK-06): a multi-packet ability doesn't reflect N per packet.
	var spike_carrier_id: String = str(state.get("id", ""))
	if spike_retaliation > 0 and not attacker_state.is_empty() and not bool(attacker_state.get("dead", false)) \
			and not _ability_spike_carrier_ids.has(spike_carrier_id):
		_ability_spike_carrier_ids[spike_carrier_id] = true
		if trait_spike > 0:
			_trait_fired(state, "%s takes %d for hitting %s." % [attacker_state["unit"].display_name, trait_spike, state["unit"].display_name], trait_spike)
		_log("%s's spike hits %s back for %d!" % [state["unit"].display_name, attacker_state["unit"].display_name, spike_retaliation])
		_emit_event(attacker_state, "spike", spike_retaliation, _resolve_side_for_state(attacker_state))
		_damage_state(attacker_state, spike_retaliation)

	if remaining_damage <= 0:
		return 0

	state["current_hp"] = maxi(0, int(state["current_hp"]) - remaining_damage)
	_log("%s takes %d damage." % [state["unit"].display_name, remaining_damage])
	_emit_event(state, "damage", remaining_damage, _resolve_side_for_state(state))

	if remaining_damage > 0 and not attacker_state.is_empty() and _is_hero_state(attacker_state):
		var lifesteal_pct: int = int(attacker_state.get("gear_lifesteal_pct", 0))
		if lifesteal_pct > 0:
			var heal_amount: int = int(floor(float(remaining_damage) * float(lifesteal_pct) / 100.0))
			if heal_amount > 0:
				_heal_state(attacker_state, heal_amount, attacker_state)
				_log("%s lifesteals %d HP." % [attacker_state["unit"].display_name, heal_amount])

	if _is_hero_state(state) and not _low_hp_squad_buff_used:
		var max_hp: int = int(state["max_hp"])
		if hp_before > max_hp / 2 and int(state["current_hp"]) <= max_hp / 2:
			_trigger_low_hp_squad_roll_buff()

	# Vanish directive: the first time this hero drops below the threshold,
	# they Cloak (once per battle).
	if _is_hero_state(state) and int(state["current_hp"]) > 0 and _has_directive(state, "lowHpCloakOnce") and not bool(state.get("vanish_used", false)):
		var vanish_pct: int = _directive_value(state, "pct", 50)
		if int(state["current_hp"]) * 100 < int(state["max_hp"]) * vanish_pct:
			state["vanish_used"] = true
			state["cloaked"] = true
			_log("%s vanishes into cloak!" % state["unit"].display_name)
			_emit_event(state, "cloak", 0, "hero")

	if int(state["current_hp"]) <= 0:
		# Gear: surviveOnce check
		if bool(state.get("gear_survive_once", false)) and not bool(state.get("gear_survive_once_used", false)):
			state["current_hp"] = 1
			state["gear_survive_once_used"] = true
			_log("%s survives on Survival Chip at 1 HP!" % state["unit"].display_name)
			_emit_event(state, "survive", 1, _resolve_side_for_state(state))
		else:
			state["current_hp"] = 0
			state["dead"] = true
			_clear_active_statuses_for_down_state(state)
			_cancel_targets_involving_down_state(state)
			_log("%s is down." % state["unit"].display_name)
			_on_unit_killed(state, attacker_state)
			# Spillover Charge (G-40): a hero attack's damage past the HP it
			# needed carries to the next enemy in slot order.
			if remaining_damage > hp_before and not _is_hero_state(state) \
					and not attacker_state.is_empty() and _is_hero_state(attacker_state) and has_relic("overkillSpillover"):
				_spill_overkill(state, remaining_damage - hp_before, attacker_state)
			# Dead Man's Hand relic: the first squad wipe each run — everyone
			# survives at 1 HP and the next roll is all 20s.
			if _is_hero_state(state) and _all_states_dead(_hero_states) and has_relic("squadWipeSurvive") and not GameState.dead_mans_hand_used:
				if not _forecast_only:
					GameState.dead_mans_hand_used = true
				_log("DEAD MAN'S HAND - the squad refuses to fall!")
				for hero_state in _hero_states:
					hero_state["dead"] = false
					hero_state["current_hp"] = 1
					hero_state["forced_20_pending"] = true
					_emit_event(hero_state, "survive", 1, "hero")

	return remaining_damage


# Spillover Charge (G-40): `amount` overkill from `attacker_state`'s hit that
# downed `dead_state` lands on the next living, uncloaked enemy after it in slot
# order (wrapping to the first slot). It is still the hero's hit: shields absorb
# it, a Mark amplifies it, a Firewall blocks it, and a kill it makes counts for
# the hero and can spill again.
func _spill_overkill(dead_state: Dictionary, amount: int, attacker_state: Dictionary) -> void:
	var start: int = _enemy_states.find(dead_state)
	if start < 0:
		return
	var count: int = _enemy_states.size()
	for step in range(1, count):
		var next_state: Dictionary = _enemy_states[(start + step) % count]
		if bool(next_state.get("dead", false)) or bool(next_state.get("cloaked", false)):
			continue
		_log("Spillover Charge: %d overkill carries to %s." % [amount, next_state["unit"].display_name])
		if _ward_blocks_hostile(next_state, [FirewallFeedback.SPILLOVER]):
			return
		_damage_state(next_state, amount, false, attacker_state)
		return


func _trigger_low_hp_squad_roll_buff() -> void:
	if _low_hp_squad_buff_used or not has_relic("lowHpSquadRollBuff"):
		return
	_low_hp_squad_buff_used = true
	var buff_amount: int = int(_get_relic_value("lowHpSquadRollBuff", "amount", 0))
	if buff_amount <= 0:
		return
	# Reactive squad buff fired mid-round after the low-HP squad has already
	# rolled — future-shaping (false). Default turns is now 1 EFFECTIVE turn
	# (was 2 under the old off-by-one encoding; the tick fix + skip flag mean 1
	# reads and behaves as one subsequent roll).
	var buff_turns: int = int(_get_relic_value("lowHpSquadRollBuff", "turns", 1))
	for hero_state in _hero_states:
		if not hero_state["dead"]:
			_add_roll_buff(hero_state, buff_amount, buff_turns, false)
	_log("Emergency signal: squad gains +%d roll (%dt)." % [buff_amount, buff_turns])


func _is_basic_enemy(enemy_state: Dictionary) -> bool:
	var unit: EnemyData = enemy_state.get("unit") as EnemyData
	if unit == null:
		return true
	var enemy_type: String = str(unit.enemy_type).to_lower()
	return not BOSS_STANDING_RULES.has(unit.display_name) and enemy_type != "boss" and not enemy_type.ends_with("boss")


func _wipe_all_hero_shields(source_state: Dictionary = {}) -> void:
	for hero_state in _hero_states:
		if bool(hero_state["dead"]):
			continue
		hero_state["shield_stacks"].clear()
		hero_state["shield"] = 0
	var source_name: String = str(source_state["unit"].display_name) if not source_state.is_empty() else "An ability"
	_log("%s wipes all hero shields!" % source_name)
	if not source_state.is_empty():
		_emit_event(source_state, "wipe_shields", 0, "enemy")


# --- Ward (displayed as "Firewall") ---
# Ward blocks the next ability that targets this unit, then breaks. It is not
# damage-based: an AoE that includes the unit is blocked for that unit only.
# Every hostile component of the SAME ability (damage, burn, debuff, freeze) is
# negated together via _ability_ward_blocked_ids, which resets per ability.
var _ability_ward_blocked_ids: Dictionary = {}
# The block each of those ids produced this ability: target id -> {"event":
# the block event, "log": its line's index, "line": the line}. A later
# component of the same ability adds its name to that one event and line, so a
# blocked "damage, burn, jam" reads as one block, not three. Transient like the
# memo above; never saved.
var _ability_ward_block_notes: Dictionary = {}
# NK-06: spike and flat vs-state riders (Cold Logic / Deep Cuts / Shatterpoint)
# fire once per ABILITY, not per damage packet. These per-ability memos (target
# id → true) reset at each hero/enemy ability start, so a multi-packet ability
# (base + execute + detonate + chain jumps) collects each rider / spike reflect
# at most once per target.
var _ability_rider_target_ids: Dictionary = {}
var _ability_spike_carrier_ids: Dictionary = {}


func _apply_ward(state: Dictionary) -> void:
	if state.is_empty() or bool(state.get("dead", false)):
		return
	state["warded"] = true
	_log("%s raises a firewall - the next ability that targets them is blocked." % state["unit"].display_name)
	_emit_event(state, "ward", 0, _resolve_side_for_state(state))


# `effects` names what the caller was about to apply (FirewallFeedback
# constants). Every call site passes it, so nothing a Firewall cancels goes
# unreported (gate `firewall feedback`).
func _ward_blocks_hostile(target_state: Dictionary, effects: Array) -> bool:
	if target_state.is_empty():
		return false
	var target_id: String = str(target_state.get("id", ""))
	if _ability_ward_blocked_ids.has(target_id):
		_note_ward_blocked(target_state, effects)
		return true
	if not bool(target_state.get("warded", false)):
		return false
	target_state["warded"] = false
	_ability_ward_blocked_ids[target_id] = true
	_emit_event(target_state, "block", 0, _resolve_side_for_state(target_state))
	var block_event: Dictionary = _round_events.back()
	block_event["effects"] = []
	var line: String = FirewallFeedback.log_line([], str(target_state["unit"].display_name))
	_log(line)
	_ability_ward_block_notes[target_id] = {"event": block_event, "log": _round_log.size() - 1, "line": line}
	_note_ward_blocked(target_state, effects)
	return true


# Add effect names to this ability's block on `target_state`: the event's
# "effects" list and its log line, rewritten in place.
func _note_ward_blocked(target_state: Dictionary, effects: Array) -> void:
	var note: Dictionary = _ability_ward_block_notes.get(str(target_state.get("id", "")), {})
	if note.is_empty():
		return
	var named: Array = (note["event"] as Dictionary)["effects"]
	var grew: bool = false
	for effect in FirewallFeedback.named(effects):
		if not named.has(effect):
			named.append(effect)
			grew = true
	var index: int = int(note["log"])
	if not grew or index >= _round_log.size() or str(_round_log[index]) != str(note["line"]):
		return
	note["line"] = FirewallFeedback.log_line(named, str(target_state["unit"].display_name))
	_round_log[index] = note["line"]


# Freeze = repeat (per Kev 2026-07-06): the die crusts static in the tray
# (physical blocker other dice bounce off) at its current face; on each of its
# next `die_freeze_turns` rolls the unit acts again on that face, then the die
# thaws and rerolls. Re-freezing an already-frozen die adds repeats. While
# frozen the die is immune to Jam, Rewrite, and Hijack. `flavor` is cosmetic
# only (ice / petrify tint).
func _freeze_die_state(state: Dictionary, freeze_amount: int, flavor: String = "ice", from_enemy: bool = true) -> void:
	var existing_turns: int = int(state.get("die_freeze_turns", 0))
	state["die_freeze_turns"] = existing_turns + freeze_amount
	state["freeze_flavor"] = flavor
	# G-23 (Kev 2026-09-26): freeze locks the number ON THE FACE — the value the
	# unit acts on this round, modifiers included — not the raw face. An
	# already-frozen die keeps its locked value (re-freeze only adds repeats).
	var frozen_value: int = int(state.get("frozen_die_value", 0))
	if frozen_value <= 0:
		var acted: Dictionary = _acted_hero_values if _is_hero_state(state) else _acted_enemy_values
		frozen_value = int(acted.get(str(state.get("id", "")), 0))
	if frozen_value <= 0:
		frozen_value = int(state.get("last_die_value", 0))
	if frozen_value > 0:
		state["frozen_die_value"] = frozen_value
	_log("%s's die is frozen at %d - it repeats that result %d more time(s)." % [state["unit"].display_name, int(state.get("frozen_die_value", 0)), int(state.get("die_freeze_turns", 0))])
	_emit_event(state, "freeze", int(state.get("frozen_die_value", 0)), _resolve_side_for_state(state))
	# Mirror Plate only pays out when an ENEMY tampered with the die. A friendly
	# freezeAnyDice on an ally (banking their good roll on purpose) must not print
	# Protocol for the holder (audit A-062).
	if from_enemy:
		_grant_mirror_plate_protocol(state)


# Record the values this round's units act on (resolve_round calls this with
# the effective rolls it was handed, after the hijack copy). Public so tests can
# drive a freeze capture without a full round.
func stamp_acted_values(hero_values: Dictionary, enemy_values: Dictionary) -> void:
	_acted_hero_values.clear()
	_acted_enemy_values.clear()
	for id_variant in hero_values:
		_acted_hero_values[str(id_variant)] = int(hero_values[id_variant])
	for id_variant in enemy_values:
		_acted_enemy_values[str(id_variant)] = int(enemy_values[id_variant])


# Enemy AI freeze pick: the living hero with the LOWEST revealed die face this
# round — deterministic (ties break to slot order, no randi). Taunt overrides
# everything; cloaked heroes can't be picked by hostile single-target effects.
func _freeze_pick_hero_lowest_die(enemy_state: Dictionary = {}, shown_values: Dictionary = {}) -> Dictionary:
	var values: Dictionary = shown_values if not shown_values.is_empty() else _acted_hero_values
	# Single-target taunt (G-4): a lured caster freezes its taunter's die.
	var lurer: Dictionary = _lurer_for_enemy(enemy_state)
	if not lurer.is_empty():
		return lurer
	var taunter: Dictionary = _get_taunting_hero_state()
	if not taunter.is_empty():
		return taunter
	var best: Dictionary = {}
	var best_value: int = 21
	for hero_state in _hero_states:
		if bool(hero_state["dead"]) or bool(hero_state.get("cloaked", false)):
			continue
		# The value the die SHOWS and the hero acts on this round (stamped at
		# resolve start), not its raw face — the player picks by what they see.
		var face: int = int(values.get(str(hero_state["id"]), 0))
		if face <= 0:
			face = int(hero_state.get("last_die_value", 0))
		if face <= 0:
			face = 21  # unrevealed die: only picked if nothing revealed exists
		if face < best_value:
			best_value = face
			best = hero_state
	if best.is_empty():
		# Everything cloaked/unrevealed — fall back to the first living hero so
		# the rider still resolves deterministically.
		for hero_state in _hero_states:
			if not bool(hero_state["dead"]) and not bool(hero_state.get("cloaked", false)):
				return hero_state
	return best


func _revive_state(state: Dictionary, hp_pct: int) -> void:
	if state.is_empty() or not bool(state.get("dead", false)):
		return
	state["dead"] = false
	state["current_hp"] = maxi(1, int(state["max_hp"]) * hp_pct / 100)
	state["burn"] = 0
	state["burn_turns"] = 0
	state["burn_stacks"] = []
	state["rfe_stacks"] = []
	state["roll_buff"] = 0
	state["roll_buff_stacks"] = []
	state["shield"] = 0
	state["shield_stacks"] = []
	state["die_freeze_turns"] = 0
	state["frozen_die_value"] = 0
	state["die_freeze_repeat_this_round"] = false
	state["freeze_flavor"] = ""
	_log("%s is revived at %d HP!" % [state["unit"].display_name, int(state["current_hp"])])
	# Revive marker for feedback/primers (the heal event carries the number).
	_emit_event(state, "revive", 0, _resolve_side_for_state(state))
	_emit_event(state, "heal", int(state["current_hp"]), _resolve_side_for_state(state))


func _on_unit_killed(dead_state: Dictionary, killer_state: Dictionary = {}) -> void:
	# Work-queue dispatcher (audit A-002): a death caused by an on-kill effect
	# is enqueued rather than dropped, so its own bookkeeping and payout hooks
	# still fire. The first death drained is "top-level"; deaths it causes are
	# nested (Chain Reaction does not re-cascade off them — preserved intent).
	_kill_queue.append([dead_state, killer_state])
	if _chain_reaction_active:
		return
	_chain_reaction_active = true
	var is_top_level: bool = true
	while not _kill_queue.is_empty():
		var entry: Array = _kill_queue.pop_front()
		_process_unit_killed(entry[0], entry[1], is_top_level)
		is_top_level = false
	_chain_reaction_active = false


func _process_unit_killed(dead_state: Dictionary, killer_state: Dictionary, is_top_level: bool) -> void:
	# All enemy deaths qualify, including summoned and rebuilt units (G-8).
	_apply_death_traits(dead_state, killer_state)

	# Vengeance Protocol: when an ally falls, the surviving squad's next roll
	# is forced to 20 (once per battle).
	if has_relic("vengeanceProtocol") and _is_hero_state(dead_state) and not _vengeance_used:
		_vengeance_used = true
		for hero_state in _hero_states:
			if hero_state != dead_state and not hero_state["dead"]:
				hero_state["forced_20_pending"] = true
		_log("VENGEANCE PROTOCOL - the squad's next roll is all 20s!")

	# Chain Reaction relic: other living enemies take damage when an enemy dies.
	# Top-level kills only, so it never cascades off the deaths it itself causes.
	if is_top_level and has_relic("chainReaction") and not _is_hero_state(dead_state):
		var chain_dmg = int(_get_relic_value("chainReaction", "amount", 4))
		for enemy_state in _enemy_states:
			if not enemy_state["dead"] and enemy_state != dead_state:
				_damage_state(enemy_state, chain_dmg)
		_log("Chain Reaction triggers!")

	# Dead Man's Charge route modifier: enemies deal 4 to a random hero on death.
	if not _is_hero_state(dead_state) and _battle_modifier == "deadMansCharge":
		var charge_targets: Array = _hero_states.filter(func(hs): return not bool(hs["dead"]))
		if not charge_targets.is_empty():
			var charge_target: Dictionary = charge_targets[_rand_index(charge_targets.size())]
			_log("DEAD MAN'S CHARGE - %s takes 4!" % charge_target["unit"].display_name)
			_damage_state(charge_target, 4)

	# Scavenger Manifest relic: the first kill each battle drops a consumable.
	if not _is_hero_state(dead_state) and has_relic("firstKillDropsConsumable") and not _scavenger_drop_done:
		_scavenger_drop_done = true
		if not _forecast_only:
			GameState.grant_battle_start_consumables(1)
		_log("Scavenger Manifest: a consumable drops from the wreck!")

	# Kill Switch (gear): heroes with healOnKill heal when any enemy dies
	if not _is_hero_state(dead_state):
		for hero_state in _hero_states:
			if not hero_state["dead"]:
				var heal_on_kill: int = int(hero_state.get("gear_heal_on_kill", 0))
				if heal_on_kill > 0:
					_heal_state(hero_state, heal_on_kill, hero_state)
					_log("%s heals %d HP on enemy death." % [hero_state["unit"].display_name, heal_on_kill])

		if not killer_state.is_empty() and _is_hero_state(killer_state):
			var protocol_basic: int = int(killer_state.get("gear_protocol_on_kill", 0))
			var protocol_any: int = int(killer_state.get("gear_protocol_on_kill_any", 0))
			if protocol_basic > 0 and _is_basic_enemy(dead_state):
				_pending_protocol_grants += protocol_basic
				_log("%s gains %d Protocol from the kill." % [killer_state["unit"].display_name, protocol_basic])
			if protocol_any > 0:
				_pending_protocol_grants += protocol_any
				_log("%s gains %d Protocol from the kill." % [killer_state["unit"].display_name, protocol_any])
			# Blood Frenzy (G-35): the killer's die freezes (freeze = repeat): it
			# keeps the value it acted on and repeats next round. Once per hero
			# per round - more kills in the same round don't add repeats.
			if has_relic("killFreezesKillerDie") and not bool(killer_state.get("dead", false)) \
					and int(killer_state.get("blood_frenzy_round", -1)) != _battle_round:
				killer_state["blood_frenzy_round"] = _battle_round
				_log("Blood Frenzy: %s's die freezes on the kill." % killer_state["unit"].display_name)
				_freeze_die_state(killer_state, int(_get_relic_value("killFreezesKillerDie", "repeats", 1)), "ice", false)
			# Salvage Directive: killing a Marked enemy refunds Protocol.
			if has_relic("protocolOnMarkedKill") and bool(dead_state.get("mark_consumed_this_hit", false)):
				var refund: int = int(_get_relic_value("protocolOnMarkedKill", "amount", 2))
				_pending_protocol_grants += refund
				_log("Salvage Directive: +%d Protocol for downing a marked target." % refund)
			# Momentum directive: each kill banks bonus damage for the next ability.
			if _has_directive(killer_state, "killNextAbilityDamage"):
				var momentum_gain: int = _directive_value(killer_state, "amount", 4)
				killer_state["momentum_bonus"] = int(killer_state.get("momentum_bonus", 0)) + momentum_gain
				_log("Momentum: %s banks +%d for the next strike." % [killer_state["unit"].display_name, momentum_gain])

	# Killswitch Relay gear + hero-death bookkeeping: always fires (heroes are
	# never "summoned"), now including deaths nested inside another kill.
	if _is_hero_state(dead_state):
		if not _forecast_only:
			SaveManager.record_hero_death()
		# SPITEFUL grudges die with the hero that earned them.
		var dead_hero_id: String = str(dead_state.get("id", ""))
		for enemy_state in _enemy_states:
			if str(enemy_state.get("last_attacker_id", "")) == dead_hero_id:
				enemy_state["last_attacker_id"] = ""
		var relay_damage: int = int(dead_state.get("gear_death_damage_all", 0))
		if relay_damage > 0:
			_log("%s's Deathburst Relay detonates for %d to all enemies!" % [dead_state["unit"].display_name, relay_damage])
			for enemy_state in _enemy_states:
				if not enemy_state["dead"]:
					_damage_state(enemy_state, relay_damage)


func _clear_active_statuses_for_down_state(state: Dictionary) -> void:
	state["shield"] = 0
	state["shield_stacks"] = []
	state["burn"] = 0
	state["burn_turns"] = 0
	state["burn_stacks"] = []
	state["rfe_stacks"] = []
	state["roll_buff"] = 0
	state["roll_buff_stacks"] = []
	state["dmg_scale"] = 1.0
	state["cloaked"] = false
	state["die_freeze_turns"] = 0
	state["freeze_flavor"] = ""
	state["rampage_charges"] = 0
	state["warded"] = false
	state["marked"] = false
	state["spike"] = 0
	state["jam_cap"] = 0
	state["jam_skip_next_tick"] = false
	state["jam_extra_rounds"] = 0
	state["zero_day"] = 0
	state["bloodlust_ready"] = false
	state["rewrite_pending"] = false
	state["rewrite_skip_next_tick"] = false
	state["hijack_pending"] = false
	state["hijack_skip_next_tick"] = false
	state["lured_by_id"] = ""
	state["lure_skip_next_tick"] = false
	state["last_attacker_id"] = ""
	state["taunting"] = false
	state["frozen_die_value"] = 0
	state["die_freeze_repeat_this_round"] = false
	state["perm_rfe"] = 0


func _cancel_targets_involving_down_state(down_state: Dictionary) -> void:
	var down_id: String = str(down_state.get("id", ""))
	for state_variant in _hero_states + _enemy_states:
		var state: Dictionary = state_variant
		if state == down_state or str(state.get("selected_target_id", "")) == down_id:
			state["selected_target_id"] = ""
			state["target_display"] = "--"


func _is_hero_state(state: Dictionary) -> bool:
	for h in _hero_states:
		if h == state:
			return true
	return false


func _heal_state(state: Dictionary, amount: int, healer_state: Dictionary = {}) -> void:
	if state.is_empty() or state["dead"] or amount <= 0:
		return
	var before_hp: int = int(state["current_hp"])
	state["current_hp"] = mini(int(state["max_hp"]), int(state["current_hp"]) + amount)
	var healed_amount: int = int(state["current_hp"]) - before_hp
	# Overheal Relay (G-39): healing a hero past max HP deals the excess as
	# damage to a random living enemy (seeded pick, INVARIANTS #1).
	var overheal: int = amount - healed_amount
	if overheal > 0 and _is_hero_state(state) and has_relic("overhealDamage"):
		var living: Array = _enemy_states.filter(func(e): return not bool(e["dead"]))
		if not living.is_empty():
			var relay_target: Dictionary = living[_rand_index(living.size())]
			_log("Overheal Relay: %d extra healing hits %s." % [overheal, relay_target["unit"].display_name])
			_damage_state(relay_target, overheal)
	# Overflowing: this healer's healing past full HP becomes shield on the target.
	if overheal > 0 and _has_trait(healer_state, "overflow") and _is_hero_state(state):
		var overflow_shield: int = _add_shield_stack(state, overheal, false, false)
		if overflow_shield > 0:
			_trait_fired(healer_state, "%d healing past full HP becomes shield on %s." % [overflow_shield, state["unit"].display_name], overflow_shield)
			_emit_event(state, "shield", overflow_shield, _resolve_side_for_state(state))
	if healed_amount > 0:
		_log("%s heals %d HP." % [state["unit"].display_name, healed_amount])
		_emit_event(state, "heal", healed_amount, _resolve_side_for_state(state))
		if not healer_state.is_empty() and _is_hero_state(healer_state) and state != healer_state:
			var shield_bonus: int = int(healer_state.get("gear_heal_shield_bonus", 0))
			if shield_bonus > 0:
				_add_shield_stack(state, shield_bonus)
				_log("%s grants %d shield from the heal." % [healer_state["unit"].display_name, shield_bonus])
		# Field Triage directive: this hero's heals also plate the target.
		if not healer_state.is_empty() and _has_directive(healer_state, "healGrantsShield") and not bool(state.get("dead", false)):
			var triage_shield: int = _directive_value(healer_state, "amount", 3)
			_add_shield_stack(state, triage_shield)
			_log("Field Triage: the heal grants %d shield." % triage_shield)
		# Aegis Field: a heal grants all allies shield — but only friendly heals
		# (the healed unit is a hero). Enemy heals (regenerative modifier, enemy
		# lifesteal) no longer arm the squad's defense (audit A-033).
		if has_relic("healGrantsShieldAll") and _is_hero_state(state):
			var squad_shield: int = int(_get_relic_value("healGrantsShieldAll", "amount", 0))
			if squad_shield > 0:
				for ally_state in _hero_states:
					if not ally_state["dead"]:
						_add_shield_stack(ally_state, squad_shield)
				_log("Aegis Field grants %d shield to all allies." % squad_shield)


# Burns are independent instances (per Kev 2026-07-06): each application has
# its own remaining duration and expires on its own clock; the tick damage is
# the sum of live stacks. Each stack skips the tick of its application round
# (unchanged timing: an Nt burn deals N ticks over the N following rounds).
# turns >= PERMANENT_BURN_TURNS marks a permanent stack (plagueProtocol).
func _apply_burn(state: Dictionary, amount: int, turns: int, pierce: bool = false) -> void:
	if state.is_empty() or state["dead"] or amount <= 0 or turns <= 0:
		return
	var permanent: bool = turns >= PERMANENT_BURN_TURNS
	state["burn_stacks"].append({
		"amt": amount,
		"turns_left": turns,
		"skip_next_tick": true,
		"perm": permanent,
		# Corrosive: this stack's ticks ignore shields.
		"pierce": pierce,
	})
	_refresh_burn_totals(state)
	if permanent:
		_log("%s is burning for %d - permanently." % [state["unit"].display_name, amount])
	else:
		_log("%s is burning for %d over %d turns." % [state["unit"].display_name, amount, turns])
	_emit_event(state, "burn", amount, _resolve_side_for_state(state))


# Cleanse (Build I): removes the unit-level negative statuses — burn stacks,
# NEGATIVE roll-buff stacks (positives survive), jam cap, lure, mark. Die
# states are untouched by ruling (see the firing site). Logs only when
# something was removed; the event always fires (the cast is real feedback).
func _apply_cleanse(state: Dictionary) -> void:
	var removed: bool = false
	if not (state.get("burn_stacks", []) as Array).is_empty():
		(state["burn_stacks"] as Array).clear()
		_refresh_burn_totals(state)
		removed = true
	var kept_buffs: Array = []
	for stack_variant in state.get("roll_buff_stacks", []):
		if int((stack_variant as Dictionary).get("amt", 0)) > 0:
			kept_buffs.append(stack_variant)
	if kept_buffs.size() != (state.get("roll_buff_stacks", []) as Array).size():
		state["roll_buff_stacks"] = kept_buffs
		_refresh_roll_buff_total(state)
		removed = true
	if int(state.get("jam_cap", 0)) > 0:
		state["jam_cap"] = 0
		removed = true
	if str(state.get("lured_by_id", "")) != "":
		state["lured_by_id"] = ""
		removed = true
	if bool(state.get("marked", false)):
		state["marked"] = false
		removed = true
	if removed:
		_log("%s is cleansed - negative effects removed." % state["unit"].display_name)
	_emit_event(state, "cleanse", 0, _resolve_side_for_state(state))


# Derived display caches: "burn" = summed live stack value, "burn_turns" =
# longest remaining clock (one aggregated chip).
func _refresh_burn_totals(state: Dictionary) -> void:
	var total: int = 0
	var longest: int = 0
	for stack_variant in state.get("burn_stacks", []):
		var stack: Dictionary = stack_variant
		total += int(stack["amt"])
		longest = maxi(longest, int(stack["turns_left"]))
	state["burn"] = total
	state["burn_turns"] = longest


func _first_living_state(states: Array) -> Dictionary:
	for state in states:
		if not state["dead"]:
			return state
	return {}


func _first_living_enemy_ally(enemy_state: Dictionary) -> Dictionary:
	for state in _enemy_states:
		if state == enemy_state:
			continue
		if not bool(state["dead"]):
			return state
	return {}


func _first_dead_state(states: Array) -> Dictionary:
	for state in states:
		if bool(state["dead"]):
			return state
	return {}


# Used by Chain jump selection — cloaked units can't be jumped to either.
func _lowest_hp_state_excluding(states: Array, exclude_ids: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_ratio: float = 2.0
	for state in states:
		if state["dead"] or exclude_ids.has(str(state.get("id", ""))):
			continue
		if bool(state.get("cloaked", false)):
			continue
		var max_hp: int = maxi(int(state["max_hp"]), 1)
		var ratio: float = float(state["current_hp"]) / float(max_hp)
		if ratio < best_ratio:
			best_ratio = ratio
			best = state
	return best


func _lowest_hp_state(states: Array) -> Dictionary:
	var best: Dictionary = {}
	var best_ratio: float = 2.0
	for state in states:
		if state["dead"]:
			continue
		var max_hp: int = maxi(int(state["max_hp"]), 1)
		var ratio: float = float(state["current_hp"]) / float(max_hp)
		if ratio < best_ratio:
			best_ratio = ratio
			best = state
	return best


func _all_states_dead(states: Array) -> bool:
	for state in states:
		if not state["dead"]:
			return false
	return true


func _find_target_by_id(states: Array, target_id: String) -> Dictionary:
	if target_id == "":
		return {}
	for state in states:
		if state["dead"]:
			continue
		if str(state["id"]) == target_id:
			return state
	return {}


func _find_living_enemy_ally_by_id(enemy_state: Dictionary, target_id: String) -> Dictionary:
	if target_id == "":
		return {}
	for state in _enemy_states:
		if state == enemy_state:
			continue
		if bool(state["dead"]):
			continue
		if str(state["id"]) == target_id:
			return state
	return {}


func _find_target_by_id_including_dead(states: Array, target_id: String) -> Dictionary:
	if target_id == "":
		return {}
	for state in states:
		if str(state["id"]) == target_id:
			return state
	return {}


func _get_taunting_hero_state() -> Dictionary:
	# G-4: the ability-cast taunt is single-target (per-enemy lured_by_id via
	# _lurer_for_enemy) and no longer feeds this stance aura. The ONE remaining
	# aura is Anchor Frame gear ("taunts while above 50% HP"), kept as-is
	# pending its own ruling (recorded in DECISIONS_RESOLVED G-4).
	for hero_state in _hero_states:
		if bool(hero_state["dead"]) or not bool(hero_state.get("gear_anchor_taunt", false)):
			continue
		if int(hero_state["current_hp"]) * 2 > int(hero_state["max_hp"]):
			return hero_state
	return {}


# The hero this enemy is lured to (single-target taunt, ruling G-4): {} when
# unlured or the taunter is gone. Taunt overrides cloak by doctrine — the
# lookup ignores the cloak flag on purpose.
func _lurer_for_enemy(enemy_state: Dictionary) -> Dictionary:
	if enemy_state.is_empty():
		return {}
	var lured_by: String = str(enemy_state.get("lured_by_id", ""))
	if lured_by == "":
		return {}
	return _find_target_by_id(_hero_states, lured_by)


func _tick_end_of_round_states() -> void:
	_ability_trait_chips.clear()
	for hero_state in _hero_states:
		_tick_state(hero_state)

	for enemy_state in _enemy_states:
		_tick_state(enemy_state)

	# Spend frozen-die repeats: any unit whose crusted die repeated its face
	# this round spends one repeat now. After the last repeat the die thaws and
	# rolls fresh next round. Single consumption point for tray and headless
	# flows (freeze = repeat, per Kev 2026-07-06).
	for state_variant in _hero_states + _enemy_states:
		var frozen_state: Dictionary = state_variant
		if bool(frozen_state["dead"]):
			continue
		if bool(frozen_state.get("die_freeze_repeat_this_round", false)):
			frozen_state["die_freeze_repeat_this_round"] = false
			frozen_state["die_freeze_turns"] = maxi(0, int(frozen_state.get("die_freeze_turns", 0)) - 1)
			if int(frozen_state.get("die_freeze_turns", 0)) <= 0:
				# Thawed — the die rolls fresh next round.
				frozen_state["frozen_die_value"] = 0
				frozen_state["freeze_flavor"] = ""

	# Clear taunt at end of round on BOTH sides (re-applied each round if rolled
	# again). Hero-side taunt now expires symmetrically with enemy self-taunt —
	# it is no longer a permanent stance (ruling NK-08).
	for enemy_state in _enemy_states:
		if not enemy_state["dead"]:
			enemy_state["taunting"] = false
	for hero_state in _hero_states:
		if not hero_state["dead"]:
			hero_state["taunting"] = false


# The burn damage this state takes at the end of the current round — 0 when
# the tick won't fire (no burn, expired turns, skip flag). Mirrors _tick_state
# and is the single source the HP preview uses so the projection can't drift
# from combat.
func get_expected_burn_tick(state: Dictionary) -> int:
	if bool(state.get("dead", false)):
		return 0
	# Sum the stacks that will actually tick this round (skip-flagged stacks
	# were applied this round and sit the tick out).
	var ticking: int = 0
	for stack_variant in state.get("burn_stacks", []):
		var stack: Dictionary = stack_variant
		if not bool(stack.get("skip_next_tick", false)):
			ticking += int(stack["amt"])
	if ticking <= 0:
		return 0
	var burn_bonus: int = 0
	if not _is_hero_state(state):
		burn_bonus = int(_get_relic_value("burnAmplified", "bonus", 0)) + _get_total_burn_bonus()
	return ticking + burn_bonus


# The part of this round's burn tick that ignores shields (Corrosive stacks).
# Never more than get_expected_burn_tick.
func get_expected_burn_tick_pierce(state: Dictionary) -> int:
	if bool(state.get("dead", false)) or _traits_off():
		return 0
	var piercing: int = 0
	for stack_variant in state.get("burn_stacks", []):
		var stack: Dictionary = stack_variant
		if bool(stack.get("pierce", false)) and not bool(stack.get("skip_next_tick", false)):
			piercing += int(stack["amt"])
	return mini(piercing, get_expected_burn_tick(state))


func _tick_state(state: Dictionary) -> void:
	if state["dead"]:
		return

	# Burn: one tick per round for the summed live stacks; each stack runs its
	# own clock (skip-flagged stacks were applied this round and start next
	# round; permanent stacks never expire).
	if not (state.get("burn_stacks", []) as Array).is_empty():
		var tick_dmg: int = get_expected_burn_tick(state)
		if tick_dmg > 0:
			_emit_action_event(state, _resolve_side_for_state(state), "Burn", "tick")
			_log("%s takes %d burn damage." % [state["unit"].display_name, tick_dmg])
			# Corrosive stacks tick past shields; the rest of the tick does not.
			var pierce_dmg: int = get_expected_burn_tick_pierce(state)
			if pierce_dmg > 0:
				_log("%s: %d of the burn on %s ignores shields." % [UnitTraits.name_of("corrosive"), pierce_dmg, state["unit"].display_name])
				_damage_state(state, pierce_dmg, true)
			_damage_state(state, tick_dmg - pierce_dmg)
			_apply_kindle_for_tick(state)
		var live_burn_stacks: Array = []
		for stack_variant in state.get("burn_stacks", []):
			var stack: Dictionary = stack_variant
			if bool(stack.get("skip_next_tick", false)):
				stack["skip_next_tick"] = false
				live_burn_stacks.append(stack)
				continue
			if bool(stack.get("perm", false)):
				live_burn_stacks.append(stack)
				continue
			var burn_tl: int = int(stack["turns_left"]) - 1
			if burn_tl > 0:
				stack["turns_left"] = burn_tl
				live_burn_stacks.append(stack)
		state["burn_stacks"] = live_burn_stacks
		_refresh_burn_totals(state)

	# Enemy-side Taunt (internal lured_by state) covers exactly one hero phase:
	# applied in the enemy phase, it skips this tick, restricts the next hero
	# phase, then clears.
	if str(state.get("lured_by_id", "")) != "":
		if bool(state.get("lure_skip_next_tick", false)):
			state["lure_skip_next_tick"] = false
		else:
			state["lured_by_id"] = ""

	# Hijack fires at exactly one roll: skips the tick of the applying round,
	# copies the heroes' highest die at the next reveal, then clears. G-30: while
	# the die is frozen the hijack WAITS — kept through the freeze, it copies at
	# the first reveal after the thaw (the skip is spent here so it then clears
	# after exactly that reveal).
	if bool(state.get("hijack_pending", false)):
		if int(state.get("die_freeze_turns", 0)) > 0:
			state["hijack_skip_next_tick"] = false
		elif bool(state.get("hijack_skip_next_tick", false)):
			state["hijack_skip_next_tick"] = false
		else:
			state["hijack_pending"] = false

	# Rewrite fires at exactly one roll (telegraphed): applied this turn, it
	# skips this tick, forces the NEXT reveal to 3, then clears.
	if bool(state.get("rewrite_pending", false)):
		if bool(state.get("rewrite_skip_next_tick", false)):
			state["rewrite_skip_next_tick"] = false
		else:
			state["rewrite_pending"] = false
	# Zero-Day lasts exactly as long as the rewrite it rode in on.
	if not bool(state.get("rewrite_pending", false)):
		state["zero_day"] = 0

	# Jam caps exactly one roll: applied mid-round (after the target already
	# rolled) it skips this tick and caps the NEXT reveal, then clears.
	if int(state.get("jam_cap", 0)) > 0:
		if bool(state.get("jam_skip_next_tick", false)):
			state["jam_skip_next_tick"] = false
		elif int(state.get("jam_extra_rounds", 0)) > 0:
			# Spectral: the jam holds for another roll.
			state["jam_extra_rounds"] = int(state["jam_extra_rounds"]) - 1
		else:
			state["jam_cap"] = 0
	else:
		state["jam_extra_rounds"] = 0

	# Spike never persists past the round; enemy-phase grants skip one tick so
	# they cover the next hero phase.
	if int(state.get("spike", 0)) > 0:
		if bool(state.get("spike_skip_next_tick", false)):
			state["spike_skip_next_tick"] = false
		else:
			state["spike"] = 0

	# Shields last one round: everything not flagged to survive this tick (or
	# owned by a shields_persist state) expires now.
	if not state["dead"] and not bool(state.get("shields_persist", false)):
		var new_shield_stacks: Array = []
		for stack in state.get("shield_stacks", []):
			if bool(stack.get("skip_next_tick", false)):
				stack["skip_next_tick"] = false
				new_shield_stacks.append(stack)
		state["shield_stacks"] = new_shield_stacks
		state["shield"] = _get_total_shield(state)

	# Feedback directive: enemies under an active roll-down take chip damage
	# each round (fires before the stacks decay so a 1-turn rfe still bites).
	if not state["dead"] and int(state.get("feedback_per_round", 0)) > 0 and _get_total_rfe(state) > 0:
		var feedback_dmg: int = int(state["feedback_per_round"])
		_log("Feedback: %s takes %d from the static." % [state["unit"].display_name, feedback_dmg])
		_damage_state(state, feedback_dmg)

	# Tick RFE stacks: decrement turns_left, remove expired
	if not state["dead"]:
		var new_rfe_stacks: Array = []
		for stack in state.get("rfe_stacks", []):
			if bool(stack.get("skip_next_tick", false)):
				stack["skip_next_tick"] = false
				new_rfe_stacks.append(stack)
				continue
			var tl: int = int(stack["turns_left"]) - 1
			if tl > 0:
				new_rfe_stacks.append({"amt": stack["amt"], "turns_left": tl})
		state["rfe_stacks"] = new_rfe_stacks
		if new_rfe_stacks.is_empty():
			state["feedback_per_round"] = 0

	# Tick roll-buff stacks. A future-shaping buff (skip_next_tick, set by
	# _add_roll_buff when shapes_current_roll=false) sits out the tick of its
	# cast round — the round it couldn't shape — then `turns_left` counts the
	# future rolls it does shape. Current-roll buffs (items) carry no skip flag,
	# so they tick immediately: `turns` = rolls including the cast round. Either
	# way the stored number equals effective turns (docs/TRUTH.md).
	if not (state.get("roll_buff_stacks", []) as Array).is_empty():
		var live_buff_stacks: Array = []
		for stack_variant in state.get("roll_buff_stacks", []):
			var stack: Dictionary = stack_variant
			if bool(stack.get("skip_next_tick", false)):
				stack["skip_next_tick"] = false
				live_buff_stacks.append(stack)
				continue
			var buff_tl: int = int(stack["turns_left"]) - 1
			if buff_tl > 0:
				stack["turns_left"] = buff_tl
				live_buff_stacks.append(stack)
		state["roll_buff_stacks"] = live_buff_stacks
		_refresh_roll_buff_total(state)


# --- Public item application methods ---

func apply_item_heal(target_state: Dictionary, amount: int) -> void:
	_heal_state(target_state, amount)


func apply_item_heal_all(amount: int) -> void:
	for hero_state in _hero_states:
		if not bool(hero_state.get("dead", true)):
			_heal_state(hero_state, amount)


func apply_item_shield(target_state: Dictionary, amount: int) -> void:
	_add_shield_stack(target_state, amount)


func apply_item_ward(target_state: Dictionary) -> void:
	_apply_ward(target_state)


func apply_item_shield_all(amount: int) -> void:
	for hero_state in _hero_states:
		if not bool(hero_state.get("dead", true)):
			_add_shield_stack(hero_state, amount)


func apply_item_roll_buff(target_state: Dictionary, amount: int, turns: int) -> void:
	# Items are used post-roll but pre-commit and feed get_effective_roll, so they
	# shape the CURRENT roll — shapes_current_roll=true (the cast round counts,
	# no cast-tick skip). A turns=1 item grants exactly one roll (the current);
	# adding a skip here would silently hand it a second (the item guard test).
	_add_roll_buff(target_state, amount, turns, true)


func apply_item_revive(target_state: Dictionary, hp_pct: int) -> void:
	_revive_state(target_state, hp_pct)


func apply_item_rfe(target_state: Dictionary, amount: int, turns: int) -> void:
	_add_rfe_stack(target_state, amount, turns)


func apply_item_damage(target_state: Dictionary, amount: int) -> void:
	_damage_state(target_state, amount)


func apply_item_burn(target_state: Dictionary, amount: int, turns: int) -> void:
	_apply_burn(target_state, amount, turns)


# --- Summon injection ---

func _count_living_enemies() -> int:
	var count: int = 0
	for state in _enemy_states:
		if not bool(state.get("dead", false)):
			count += 1
	return count


func _first_dead_enemy_index() -> int:
	for i in range(_enemy_states.size()):
		if bool(_enemy_states[i].get("dead", false)):
			return i
	return -1


func _try_emit_enemy_summon(enemy_state: Dictionary, ability_entry: Dictionary, _raw_roll: int, summon_chance: int, summon_name: String) -> void:
	if _count_living_enemies() >= GameState.SQUAD_UNIT_LIMIT:
		return
	var enemy_unit: EnemyData = enemy_state.get("unit") as EnemyData
	if enemy_unit == null:
		return
	# Summon fires when the die's final face lands in the overload zone (== 20).
	# No "natural 20" check — a die buffed/rewritten/hijacked to 20 counts the
	# same as a rolled 20 (ruling NK-02, nat-20 concept removed). The zone gate
	# below is the effective-face-20 test, since enemy abilities are selected
	# from the effective roll.
	if str(ability_entry.get("zone", "")) != "overload":
		return
	if enemy_unit.ai_type != "smart" or not enemy_unit.can_summon_elite:
		return
	# Frozen overloads roll their summon chance again (G-8).
	# Seeded so the sim reproduces the summon roll from a seed (NK-01 / INV #1).
	if _rand_pct() > summon_chance:
		return
	_log("%s calls for reinforcements - %s incoming!" % [enemy_state["unit"].display_name, summon_name])
	_round_events.append({
		"type": "summon",
		"amount": 0,
		"side": "enemy",
		"target_name": str(enemy_state["unit"].display_name),
		"summon_name": summon_name,
	})


func inject_enemy(enemy_data: EnemyData) -> Dictionary:
	if _count_living_enemies() >= GameState.SQUAD_UNIT_LIMIT:
		_log("Summon blocked - enemy field is full.")
		return {}

	var new_state: Dictionary = _create_runtime_state(enemy_data, _next_enemy_instance_id(enemy_data))
	new_state["summoned"] = true  # Reinforcement metadata; normal kill rewards apply.
	var slot_index: int = _first_dead_enemy_index()
	if slot_index >= 0:
		_enemy_states[slot_index] = new_state
		_log("%s has been summoned, replacing a fallen unit!" % enemy_data.display_name)
	else:
		slot_index = _enemy_states.size()
		_enemy_states.append(new_state)
		_log("%s has been summoned to the field!" % enemy_data.display_name)
	return {"state": new_state, "slot_index": slot_index}


# --- Log / event helpers ---

func _log(message: String) -> void:
	_round_log.append(message)


func _emit_event(state: Dictionary, event_type: String, amount: int, side: String) -> void:
	# hp_after captures the target's running HP at the moment this event fires, so
	# feedback can step the HP bar per-hit instead of jumping to the fully-resolved
	# total (combat resolves the whole round before feedback replays it).
	_round_events.append({
		"type": event_type,
		"amount": amount,
		"side": side,
		"target_id": str(state["id"]),
		"target_name": str(state["unit"].display_name),
		"hp_after": int(state.get("current_hp", 0)),
		"hp_max": int(state.get("max_hp", 1)),
		# Same idea for the shield chip: the target's shield as this event
		# fires, so the chip can step with the beats (accrete, absorb, grant).
		"shield_after": int(state.get("shield", 0)),
	})


func _emit_action_event(state: Dictionary, side: String, ability_name: String, zone: String = "") -> void:
	_round_events.append({
		"type": "action_start",
		"amount": 0,
		"side": side,
		"actor_id": str(state["id"]),
		"actor_name": str(state["unit"].display_name),
		"ability": ability_name,
		"zone": zone,  # "overload" drives the signature celebration. NOTE: zone comes
		# from the EFFECTIVE roll, so a die nudged/buffed up to 20 counts as overload
		# and celebrates the same on any die whose final face is 20 (NK-02).
	})


func _resolve_side_for_state(state: Dictionary) -> String:
	for hero_state in _hero_states:
		if hero_state == state:
			return "hero"
	return "enemy"
