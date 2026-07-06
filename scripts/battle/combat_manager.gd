# Resolves a minimal first-pass combat loop using the rolled ability metadata.
class_name CombatManager
extends RefCounted

var _hero_states: Array = []
var _enemy_states: Array = []
var _round_log: Array = []
var _round_events: Array = []

var _active_relic_effects: Array = []  # Array of effect Dictionaries from DataManager
var _chain_reaction_active: bool = false
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

const BOSS_SCRAPMASTER := "SCRAPMASTER"
const BOSS_MATRIARCH := "Hive Matriarch"
const BOSS_OVERSEER := "CONCLAVE OVERSEER"
const BOSS_HIEROPHANT := "ROOT HIEROPHANT"
const BOSS_MANTLE := "MANTLE TYRANT"
const SCRAP_DRONE_NAME := "Scrap Drone"
const BROOD_SPAWN_NAME := "Bloodmite"
# Burns at or past this turn count are PERMANENT (plagueProtocol): they tick
# forever and Detonate treats them as one tick's worth without consuming them
# (per Kev 2026-07-06 — resolves the old DETONATE_MAX_TURNS placeholder cap).
const PERMANENT_BURN_TURNS := 9999

const BOSS_STANDING_RULES := {
	BOSS_SCRAPMASTER: "ASSEMBLY LINE — every other round, rebuilds one destroyed Scrap Drone at 50% HP.",
	BOSS_MATRIARCH: "THE BROOD — spawns a Bloodmite every 3 rounds.",
	BOSS_OVERSEER: "THE COURT — while any ally lives, gains a Firewall at the start of each round.",
	BOSS_HIEROPHANT: "ROOT ACCESS — every round, Rewrites the squad's highest die to 3.",
	BOSS_MANTLE: "ACCRETION — gains 6 shield at the start of every round; its shields persist and stack.",
}

# BALANCE-TODO: rebuild HP 50%, brood cadence 3, mantle shield 6 are provisional.
const SCRAPMASTER_REBUILD_PCT := 50
const MANTLE_ROUND_SHIELD := 6

# 1-based round counter driving the turn-cadence rules.
var _battle_round: int = 0

# This round's raw hero die faces (stashed by resolve_round) — the enemy
# freeze pick reads them to find the LOWEST revealed hero die.
var _current_raw_hero_rolls: Dictionary = {}

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
func assign_enemy_intents(enemy_rolls: Dictionary, dice_manager: DiceManager) -> void:
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
		var current: Dictionary = _find_target_by_id(_hero_states, str(enemy_state.get("selected_target_id", "")))
		if not current.is_empty() and not bool(current.get("cloaked", false)):
			_enemy_assignments[str(enemy_state["id"])] = str(current["id"])
			continue
		var pick: Dictionary = TargetingPersonality.personality_pick_target(enemy_state, _hero_states, _enemy_assignments)
		if pick.is_empty():
			enemy_state["selected_target_id"] = ""
			enemy_state["target_display"] = "--"
			continue
		enemy_state["selected_target_id"] = str(pick["id"])
		enemy_state["target_display"] = str(pick["unit"].display_name)
		_enemy_assignments[str(enemy_state["id"])] = str(pick["id"])


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
		or bool(raw.get("curseDice", false))
	)


# Resolve-time target for every hostile component of one enemy ability.
# Taunt overrides everything (even an assigned pick — a hero may start
# taunting after intents were assigned); a still-legal assigned pick is
# honored; a dead/cloaked pick falls through to the personality's stated
# fallback via the same choke-point.
func _resolve_enemy_hero_target(enemy_state: Dictionary) -> Dictionary:
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
					_log("The Court stands — the Overseer raises a Firewall.")
					_apply_ward(enemy_state)
			BOSS_MANTLE:
				_log("The Tyrant accretes its mantle.")
				_add_shield_stack(enemy_state, MANTLE_ROUND_SHIELD, true)


# Enemy-phase rules (turn-cadence actions): Assembly Line rebuild, Brood
# spawn, and the Hierophant's Root Access rewrite of the squad's highest die.
func _apply_boss_enemy_phase_rules(hero_rolls: Dictionary) -> void:
	for enemy_state in _enemy_states:
		if bool(enemy_state["dead"]):
			continue
		match str(enemy_state["unit"].display_name):
			BOSS_SCRAPMASTER:
				# DESIGN-TODO(kev): "every other turn" read as even-numbered rounds.
				if _battle_round % 2 == 0:
					for drone_state in _enemy_states:
						if str(drone_state["unit"].display_name) == SCRAP_DRONE_NAME and bool(drone_state["dead"]):
							_log("ASSEMBLY LINE — the SCRAPMASTER rebuilds a Scrap Drone!")
							_revive_state(drone_state, SCRAPMASTER_REBUILD_PCT)
							break
			BOSS_MATRIARCH:
				if _battle_round % 3 == 0 and _count_living_enemies() < GameState.SQUAD_UNIT_LIMIT:
					_log("THE BROOD — the Matriarch births a Bloodmite!")
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
					_log("ROOT ACCESS — the Hierophant seizes the squad's highest die.")
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


# --- Battle-start relic effects ---

func apply_battle_start_relic_effects(battle_index: int) -> void:
	# Opening Salvo: a random enemy loses 50% max HP; a random hero loses 20%.
	if has_relic("battleStartHalfHp"):
		var living_enemies = _enemy_states.filter(func(e): return not e["dead"])
		var living_heroes = _hero_states.filter(func(h): return not h["dead"])
		if not living_enemies.is_empty():
			var target_enemy = living_enemies[randi() % living_enemies.size()]
			var dmg = int(target_enemy["max_hp"]) / 2
			_damage_state(target_enemy, dmg)
			_log("Opening Salvo: %s takes %d damage!" % [target_enemy["unit"].display_name, dmg])
		if not living_heroes.is_empty():
			var target_hero = living_heroes[randi() % living_heroes.size()]
			var dmg = int(target_hero["max_hp"]) / 5
			_damage_state(target_hero, dmg)
			_log("Opening Salvo: %s takes %d damage!" % [target_hero["unit"].display_name, dmg])

	# Static Field: enemy dice are Jammed (cap 10) on turn 1 of every battle.
	if has_relic("battleStartJamEnemies"):
		for jam_state in _enemy_states:
			if not jam_state["dead"]:
				apply_battle_start_jam(jam_state)

	# Mantle Core: your shields persist until broken.
	if has_relic("shieldsPersist"):
		for persist_state in _hero_states:
			persist_state["shields_persist"] = true

	# Resonant Chorus is applied in battle_scene at roll time (turn-1 floor 8).

	# shieldsPersist (Mantle Core): hero shields persist until broken instead of
	# expiring at round end.
	if has_relic("shieldsPersist"):
		for hero_state in _hero_states:
			hero_state["shields_persist"] = true
		_log("Mantle Core: hero shields persist until broken.")

	# plagueProtocol: all enemies start with 3 burn
	if has_relic("enemyBurnPermanent"):
		var burn_amt = int(_get_relic_value("enemyBurnPermanent", "amount", 3))
		for enemy_state in _enemy_states:
			if not enemy_state["dead"]:
				_apply_burn(enemy_state, burn_amt, PERMANENT_BURN_TURNS)
				_log("Plague Protocol: %s starts with %d burn." % [enemy_state["unit"].display_name, burn_amt])

	# signalJam: all enemies start with permanent -2 RFE
	if has_relic("enemyStartRfe"):
		var rfe_amt = int(_get_relic_value("enemyStartRfe", "amount", 2))
		for enemy_state in _enemy_states:
			if not enemy_state["dead"]:
				enemy_state["perm_rfe"] = int(enemy_state.get("perm_rfe", 0)) + rfe_amt
				_log("Signal Jam: %s permanently at -%d roll." % [enemy_state["unit"].display_name, rfe_amt])

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
				_log("Entropy Leak: %s spawns at %d%% HP." % [enemy_state["unit"].display_name, hp_pct])


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
func get_effective_roll(state: Dictionary, raw_roll: int) -> int:
	# Rewrite: the next roll is SET to 3 — trumps every other modifier.
	if bool(state.get("rewrite_pending", false)):
		return REWRITE_VALUE
	var mods: Dictionary = get_roll_modifier_totals(state)
	var effective: int = clampi(raw_roll + int(mods["roll_buff"]) - int(mods["roll_rfe"]), 1, 20)
	# Jam: the unit's next roll is capped (default 10); cleared at that
	# round's end tick.
	var jam_cap: int = int(state.get("jam_cap", 0))
	if jam_cap > 0:
		effective = mini(effective, jam_cap)
	return effective


# PUBLIC: RFE/buff totals for dice-tray display (raw roll stored separately for crit rules).
func get_roll_modifier_totals(state: Dictionary) -> Dictionary:
	return {
		"roll_rfe": _get_total_rfe(state) + int(state.get("perm_rfe", 0)),
		"roll_buff": _get_total_roll_buff(state) + int(state.get("perm_roll_buff", 0)),
	}


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
	_round_log.clear()
	_round_events.clear()


# Reorder the hero action order for L2 order-search. `ordered_ids` is a
# permutation of the current living-hero ids; unknown/dead ids keep their
# relative position at the end.
func set_hero_order(ordered_ids: Array) -> void:
	var by_id: Dictionary = {}
	for state in _hero_states:
		by_id[str((state as Dictionary)["id"])] = state
	var reordered: Array = []
	for id in ordered_ids:
		if by_id.has(str(id)):
			reordered.append(by_id[str(id)])
			by_id.erase(str(id))
	for leftover in by_id.values():
		reordered.append(leftover)
	_hero_states = reordered


func take_pending_protocol_drain() -> int:
	var drained: int = _pending_protocol_drain
	_pending_protocol_drain = 0
	return drained


func resolve_round(
	hero_rolls: Dictionary,
	enemy_rolls: Dictionary,
	dice_manager: DiceManager,
	raw_enemy_rolls: Dictionary = {},
	raw_hero_rolls: Dictionary = {}
) -> Dictionary:
	_round_log.clear()
	_round_events.clear()
	_battle_round += 1

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
					_log("%s's die is frozen solid — the Hijack can't take hold." % enemy_state["unit"].display_name)
					continue
				enemy_rolls[str(enemy_state["id"])] = highest_hero_roll
				_log("%s HIJACKS the squad's highest die (%d)!" % [enemy_state["unit"].display_name, highest_hero_roll])
				_emit_event(enemy_state, "hijack", highest_hero_roll, "enemy")

	# Targeting personalities: fill enemy intents (slot order) before the hero
	# phase. In UI play battle_scene already assigned them with the same
	# choke-point, so this pass just re-records the picks; headless sim/audit
	# runs get their assignment here.
	assign_enemy_intents(enemy_rolls, dice_manager)

	for hero_state in _hero_states:
		if hero_state["dead"]:
			continue
		var roll_value: Variant = hero_rolls.get(hero_state["id"], null)
		if roll_value == null:
			continue
		# Freeze = repeat: a frozen die kept its face, so the unit acts again on
		# the same result. Targeting was re-picked fresh this round.
		if bool(hero_state.get("die_freeze_repeat_this_round", false)):
			_log("%s's frozen die repeats its %d." % [hero_state["unit"].display_name, int(roll_value)])
		var ability_entry: Dictionary = dice_manager.get_ability_for_roll(hero_state["unit"], int(roll_value))
		_log("%s uses %s." % [hero_state["unit"].display_name, str(ability_entry.get("ability_name", "Unknown"))])
		_emit_action_event(hero_state, "hero", str(ability_entry.get("ability_name", "Unknown")), str(ability_entry.get("zone", "")))
		_apply_hero_ability(hero_state, ability_entry)
		var raw_roll: int = int(raw_hero_rolls.get(hero_state["id"], roll_value))
		# Overload Loop relic / Overload Rites intercept: nat 20s resolve twice.
		if raw_roll == 20 and (has_relic("critResolveTwice") or bool(hero_state.get("nat20_twice", false))):
			_log("Natural 20 echoes for %s!" % hero_state["unit"].display_name)
			_apply_hero_ability(hero_state, ability_entry)

	if _all_states_dead(_enemy_states):
		_log("All enemies are down.")
		return {"result": "victory", "log": _round_log.duplicate(), "events": _round_events.duplicate(true)}

	# Apply per-enemy-turn relic effects before enemies act
	apply_enemy_turn_start_relic_effects()

	# Accretion: units with accrete gain N shield at the start of their turn;
	# the shield survives the imminent tick to cover the next hero phase.
	for accrete_state in _enemy_states:
		if not accrete_state["dead"] and int(accrete_state.get("accrete", 0)) > 0:
			_log("%s accretes armor." % accrete_state["unit"].display_name)
			_add_shield_stack(accrete_state, int(accrete_state["accrete"]), true)

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

	_tick_end_of_round_states()

	if _all_states_dead(_enemy_states):
		_log("All enemies are down.")
		return {"result": "victory", "log": _round_log.duplicate(), "events": _round_events.duplicate(true)}

	if _all_states_dead(_hero_states):
		_log("The squad has been wiped out.")
		return {"result": "defeat", "log": _round_log.duplicate(), "events": _round_events.duplicate(true)}

	return {"result": "ongoing", "log": _round_log.duplicate(), "events": _round_events.duplicate(true)}


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
		"cursed": false,
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
# before they could ever absorb. shields_persist (Mantle Core relic / MANTLE
# TYRANT boss rule) exempts a state from expiry entirely.
# DESIGN-TODO(kev): "one round" is applied per-side as "one opposing action
# phase" so enemy shields remain meaningful; confirm this reading.
func _add_shield_stack(state: Dictionary, amount: int, survives_current_tick: bool = false) -> void:
	# Overcharge Mesh directive: shields gained by any squad member +2 while
	# a living carrier stands.
	if _is_hero_state(state):
		for mesh_state in _hero_states:
			if not bool(mesh_state["dead"]) and _has_directive(mesh_state, "squadShieldBonus"):
				amount += _directive_value(mesh_state, "amount", 2)
				break
	state["shield_stacks"].append({"amt": amount, "skip_next_tick": survives_current_tick})
	state["shield"] = _get_total_shield(state)
	_log("%s gains %d shield." % [state["unit"].display_name, amount])
	_emit_event(state, "shield", amount, _resolve_side_for_state(state))


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


func _add_roll_buff(state: Dictionary, amount: int, turns: int) -> void:
	if state.is_empty() or bool(state.get("dead", false)) or amount <= 0 or turns <= 0:
		return
	state["roll_buff_stacks"].append({"amt": amount, "turns_left": turns})
	_refresh_roll_buff_total(state)
	_log("%s gains +%d roll buff (%dt)." % [state["unit"].display_name, amount, turns])
	_emit_event(state, "roll_buff", amount, _resolve_side_for_state(state))


func _apply_hero_ability(hero_state: Dictionary, ability_entry: Dictionary) -> void:
	_ability_ward_blocked_ids.clear()
	var raw: Dictionary = ability_entry.get("raw", {})
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

	# Dealing damage breaks the cloak (no pierce — the decloak strike is a
	# plain attack; Ambush Wiring / Ghostblade add their own effects).
	if damage > 0 and bool(hero_state.get("cloaked", false)):
		hero_state["cloaked"] = false
		# Ambush Wiring directive: attacks from Cloak hit harder.
		if _has_directive(hero_state, "cloakAttackBonus"):
			damage += _directive_value(hero_state, "amount", 5)
		# Ghostblade directive: the decloak strike also Executes (consumed in
		# the damage pass).
		if _has_directive(hero_state, "decloakExecute"):
			hero_state["decloak_execute_pending"] = true
		_log("%s strikes from the shadows!" % hero_state["unit"].display_name)
		_emit_event(hero_state, "decloak", 0, "hero")

	if damage > 0:
		_apply_hero_ability_damage(hero_state, ability_entry, damage, hits_all, ignores_shield, burn_amount, burn_turns)

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
		if heal_all:
			for ally_state in _hero_states:
				_heal_state(ally_state, heal, hero_state)
		elif heal_lowest or heal_targeted:
			var heal_target: Dictionary = _find_target_by_id(_hero_states, str(hero_state.get("selected_target_id", "")))
			if heal_target.is_empty():
				heal_target = _lowest_hp_state(_hero_states)
			if not heal_target.is_empty():
				_heal_state(heal_target, heal, hero_state)
		else:
			_heal_state(hero_state, heal, hero_state)

	if roll_buff_amount > 0:
		if roll_buff_targeted:
			var roll_buff_target: Dictionary = _find_target_by_id(_hero_states, str(hero_state.get("selected_target_id", "")))
			if roll_buff_target.is_empty():
				roll_buff_target = hero_state
			_add_roll_buff(roll_buff_target, roll_buff_amount, roll_buff_turns)
		else:
			for ally_state in _hero_states:
				if not ally_state["dead"]:
					_add_roll_buff(ally_state, roll_buff_amount, roll_buff_turns)

	var gain_protocol: int = int(raw.get("gainProtocol", 0))
	# Surge Wiring directive: the named ability generates extra Protocol.
	if gain_protocol > 0 and _has_directive(hero_state, "abilityProtocolBonus") and _directive_ability(hero_state) == str(ability_entry.get("ability_name", "")):
		gain_protocol += _directive_value(hero_state, "amount", 2)
	if gain_protocol > 0:
		_pending_protocol_grants += gain_protocol
		_log("%s generates %d Protocol." % [hero_state["unit"].display_name, gain_protocol])

	if damage <= 0 and burn_amount > 0:
		var burn_target: Dictionary = _hostile_single_target(_enemy_states, str(hero_state.get("selected_target_id", "")), hero_state)
		if not burn_target.is_empty() and not _ward_blocks_hostile(burn_target):
			_apply_burn_from_hero(hero_state, burn_target, burn_amount, burn_turns)

	# RFE application (roll debuff on enemies)
	var rfe_amount: int = int(raw.get("rfe", 0))
	var rfe_turns: int = int(raw.get("rfT", 1))
	var rfe_all: bool = bool(raw.get("rfeAll", false))
	if rfe_amount > 0:
		if rfe_all:
			for enemy_state in _enemy_states:
				if not enemy_state["dead"] and not _ward_blocks_hostile(enemy_state):
					_add_rfe_stack(enemy_state, rfe_amount, rfe_turns)
					_apply_roll_down_directives(hero_state, enemy_state, true)
		else:
			var rfe_target: Dictionary = _hostile_single_target(_enemy_states, str(hero_state.get("selected_target_id", "")), hero_state)
			if not rfe_target.is_empty() and not _ward_blocks_hostile(rfe_target):
				_add_rfe_stack(rfe_target, rfe_amount, rfe_turns)
				_apply_roll_down_directives(hero_state, rfe_target, false)

	if bool(raw.get("taunt", false)):
		for ally_state in _hero_states:
			if ally_state != hero_state:
				ally_state["taunting"] = false
		hero_state["taunting"] = true
		_log("%s is taunting — enemies will target them!" % hero_state["unit"].display_name)
		_emit_event(hero_state, "taunt", 0, "hero")

	if bool(raw.get("reviveAll", false)):
		var revive_all_pct: int = _directive_revive_pct(hero_state, ability_entry, _resolve_revive_hp_pct(raw))
		for ally_state in _hero_states:
			if bool(ally_state.get("dead", false)):
				_revive_state(ally_state, revive_all_pct)
	elif bool(raw.get("revive", false)):
		var revive_pct: int = _directive_revive_pct(hero_state, ability_entry, _resolve_revive_hp_pct(raw))
		var revive_target: Dictionary = _find_target_by_id_including_dead(_hero_states, str(hero_state.get("selected_target_id", "")))
		if revive_target.is_empty():
			revive_target = _first_dead_state(_hero_states)
		if not revive_target.is_empty():
			_revive_state(revive_target, revive_pct)

	# Spike: this round, any enemy that damages this unit takes N back.
	var spike_amount: int = int(raw.get("spike", 0))
	# Counterweight directive: this hero's Spike hits harder.
	if spike_amount > 0 and _has_directive(hero_state, "spikeBonus"):
		spike_amount += _directive_value(hero_state, "amount", 4)
	if spike_amount > 0:
		hero_state["spike"] = maxi(int(hero_state.get("spike", 0)), spike_amount)
		_log("%s bristles with Spike %d — attackers take damage this round." % [hero_state["unit"].display_name, spike_amount])
		_emit_event(hero_state, "spike_up", spike_amount, "hero")

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
				if not es["dead"] and not _ward_blocks_hostile(es):
					_freeze_die_state(es, freeze_amount, freeze_flavor)
		else:
			var freeze_target: Dictionary = {}
			if freeze_any > 0:
				# freezeAnyDice: one manual pick, either side (freezing an ally
				# repeats their good result; a ward only blocks hostile picks).
				freeze_target = _find_target_by_id(_hero_states, str(hero_state.get("selected_target_id", "")))
			if not freeze_target.is_empty():
				_freeze_die_state(freeze_target, freeze_amount, freeze_flavor)
			else:
				freeze_target = _hostile_single_target(_enemy_states, str(hero_state.get("selected_target_id", "")), hero_state)
				if not freeze_target.is_empty() and not _ward_blocks_hostile(freeze_target):
					_freeze_die_state(freeze_target, freeze_amount, freeze_flavor)

	# Jam: cap the target's next roll at 10 (die status, telegraphed for the
	# next reveal). jamAll caps every living enemy die.
	if bool(raw.get("jamAll", false)):
		for es in _enemy_states:
			if not es["dead"] and not _ward_blocks_hostile(es):
				_apply_jam(es, JAM_CAP, true)
	elif bool(raw.get("jam", false)):
		var jam_target: Dictionary = _hostile_single_target(_enemy_states, str(hero_state.get("selected_target_id", "")), hero_state)
		if not jam_target.is_empty() and not _ward_blocks_hostile(jam_target):
			_apply_jam(jam_target, JAM_CAP, true)

	# Rewrite: force the target's next roll to 3.
	if bool(raw.get("rewrite", false)):
		var rewrite_target: Dictionary = _hostile_single_target(_enemy_states, str(hero_state.get("selected_target_id", "")), hero_state)
		if not rewrite_target.is_empty() and not _ward_blocks_hostile(rewrite_target):
			_apply_rewrite(rewrite_target, true)

	if damage > 0 and bool(hero_state.get("gear_first_ability_echo", false)) and not bool(hero_state.get("gear_first_ability_echo_used", false)):
		hero_state["gear_first_ability_echo_used"] = true
		_apply_hero_ability_damage(hero_state, ability_entry, damage, hits_all, ignores_shield, 0, 0)

	# Silent Running directive: non-damage abilities re-Cloak the caster.
	if damage <= 0 and _has_directive(hero_state, "nonDamageRecloak") and not bool(hero_state.get("cloaked", false)) and not bool(hero_state.get("dead", false)):
		hero_state["cloaked"] = true
		_log("%s slips back into Cloak (Silent Running)." % hero_state["unit"].display_name)
		_emit_event(hero_state, "cloak", 0, "hero")


# Bunker Doctrine directive: allies holding this hero's shields Spike.
func _apply_bunker_doctrine_spike(granter_state: Dictionary, holder_state: Dictionary) -> void:
	if holder_state == granter_state or not _has_directive(granter_state, "shieldGrantsSpike"):
		return
	var spike_value: int = _directive_value(granter_state, "amount", 3)
	holder_state["spike"] = maxi(int(holder_state.get("spike", 0)), spike_value)
	_log("Bunker Doctrine: %s gains Spike %d." % [holder_state["unit"].display_name, spike_value])


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
func _directive_revive_pct(hero_state: Dictionary, ability_entry: Dictionary, base_pct: int) -> int:
	if _has_directive(hero_state, "abilityRevivePctOverride") and _directive_ability(hero_state) == str(ability_entry.get("ability_name", "")):
		return _directive_value(hero_state, "pct", base_pct)
	return base_pct


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
	var shield_pierce: int = int(hero_state.get("gear_shield_pierce", 0))

	var breach: bool = bool(raw.get("breach", false))
	# Serrated directive: this hero's Pierce attacks also Breach.
	if ignores_shield and _has_directive(hero_state, "pierceAlsoBreach"):
		breach = true
	var breach_all: bool = bool(raw.get("breachAll", false))
	var leech: bool = bool(raw.get("leech", false))
	var leech_hp_dealt: int = 0

	if hits_all:
		for enemy_state in _enemy_states:
			if enemy_state["dead"]:
				continue
			if _ward_blocks_hostile(enemy_state):
				continue
			_break_cloak_on_aoe(enemy_state)
			if breach_all or breach:
				_breach_shields(hero_state, enemy_state)
			leech_hp_dealt += _damage_state(enemy_state, final_dmg, ignores_shield, hero_state, shield_pierce)
			# AoE burn (Supernova: "3 burn all").
			if burn_amount > 0 and burn_turns > 0 and not enemy_state["dead"]:
				_apply_burn_from_hero(hero_state, enemy_state, burn_amount, burn_turns)
	else:
		var target_enemy: Dictionary = _hostile_single_target(_enemy_states, str(hero_state.get("selected_target_id", "")), hero_state)
		if target_enemy.is_empty():
			_log("%s finds no visible target — the attack fizzles." % hero_state["unit"].display_name)
		# breach all on a single-target ability still strips every enemy's
		# shields before the hit lands.
		if breach_all:
			for enemy_state in _enemy_states:
				if not enemy_state["dead"] and not _ward_blocks_hostile(enemy_state):
					_breach_shields(hero_state, enemy_state)
		if not target_enemy.is_empty():
			if not _ward_blocks_hostile(target_enemy):
				if breach and not breach_all:
					_breach_shields(hero_state, target_enemy)
				# vsFrozenBonus rider (Shatter Lance): bonus damage against a
				# target whose die is frozen. A rider, not a keyword.
				var single_target_dmg: int = final_dmg
				var frozen_bonus: int = int(raw.get("vsFrozenBonus", 0))
				if frozen_bonus > 0 and int(target_enemy.get("die_freeze_turns", 0)) > 0:
					single_target_dmg += frozen_bonus
					_log("%s shatters the frozen die — +%d damage!" % [hero_state["unit"].display_name, frozen_bonus])
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
				# DESIGN-TODO(kev): directive Marks stay single-target — AoE
				# marking everything read as too strong.
				if bool(raw.get("mark", false)) or _has_directive(hero_state, "damageAppliesMark"):
					_apply_mark(target_enemy)
			# Chain jumps continue even when the primary hit was ward-blocked —
			# the ward only negates the ability for its own carrier.
			_apply_chain_jumps(hero_state, ability_entry, target_enemy, final_dmg, ignores_shield, shield_pierce)

	# Leech: the attacker heals 50% of the HP damage dealt (after shields).
	if leech and leech_hp_dealt > 0:
		var leech_heal: int = int(floor(float(leech_hp_dealt) * 0.5))
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
		_log("%s's die is frozen solid — the Rewrite can't take hold." % state["unit"].display_name)
		return
	state["rewrite_pending"] = true
	state["rewrite_skip_next_tick"] = survives_current_tick
	_log("%s's die is being REWRITTEN — next roll becomes %d." % [state["unit"].display_name, REWRITE_VALUE])
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


# Public hook for the ROOT HIEROPHANT boss rule (rewrite the heroes' highest die).
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
		_log("%s's die is frozen solid — the Jam can't take hold." % state["unit"].display_name)
		return
	var existing: int = int(state.get("jam_cap", 0))
	state["jam_cap"] = cap if existing <= 0 else mini(existing, cap)
	state["jam_skip_next_tick"] = survives_current_tick
	_log("%s's die is JAMMED — next roll capped at %d." % [state["unit"].display_name, int(state["jam_cap"])])
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
		_log("The Burn ignites instantly for %d!" % amount)
		_damage_state(target_state, amount)


# Mark: persistent status chip — the next hit on this target deals +50%
# (round up), then the Mark is consumed (see _damage_state).
func _apply_mark(target_state: Dictionary) -> void:
	if target_state.is_empty() or bool(target_state.get("dead", false)):
		return
	target_state["marked"] = true
	_log("%s is MARKED — the next hit deals +50%%." % target_state["unit"].display_name)
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
	var bonus: int = 8
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
		_log("%s's Detonate fizzles — no Burn on %s." % [attacker_state["unit"].display_name, target_state["unit"].display_name])
		return
	# Finite stacks are consumed; permanent stacks stay and keep ticking.
	var remaining_stacks: Array = []
	for stack_variant in target_state.get("burn_stacks", []):
		if bool((stack_variant as Dictionary).get("perm", false)):
			remaining_stacks.append(stack_variant)
	target_state["burn_stacks"] = remaining_stacks
	_refresh_burn_totals(target_state)
	_log("%s DETONATES the Burn on %s for %d!" % [attacker_state["unit"].display_name, target_state["unit"].display_name, burst])
	_emit_event(target_state, "detonate", burst, _resolve_side_for_state(target_state))
	_damage_state(target_state, burst, false, attacker_state)


# Chain: after the primary hit, the attack jumps to the lowest-HP other living
# enemy at 60% of the base damage (round down); "chain": 2 adds a second jump
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
	# BALANCE-TODO: chain jump damage is 60% of base, round down.
	# Amplifier directive: chain hits carry the full base damage.
	var chain_damage: int = base_damage if _has_directive(hero_state, "chainFullDamage") else int(floor(float(base_damage) * 0.6))
	if chain_damage <= 0:
		return
	var hit_ids: Dictionary = {str(primary_target.get("id", "")): true}
	for _i in range(jumps):
		var next_target: Dictionary = _lowest_hp_state_excluding(_enemy_states, hit_ids)
		if next_target.is_empty():
			return
		hit_ids[str(next_target["id"])] = true
		_log("%s's attack chains to %s for %d." % [hero_state["unit"].display_name, next_target["unit"].display_name, chain_damage])
		_emit_event(next_target, "chain", chain_damage, "enemy")
		if _ward_blocks_hostile(next_target):
			continue
		_damage_state(next_target, chain_damage, ignores_shield, hero_state, shield_pierce)


func _apply_enemy_ability(enemy_state: Dictionary, ability_entry: Dictionary, raw_roll: int = -1) -> void:
	_ability_ward_blocked_ids.clear()
	var raw: Dictionary = ability_entry.get("raw", {})
	# One shared hero target for every hostile single-target component of this
	# ability (taunt override / assigned intent / personality fallback).
	var hostile_hero_target: Dictionary = {}
	if _ability_targets_single_hero(raw):
		hostile_hero_target = _resolve_enemy_hero_target(enemy_state)
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
	elif shield > 0:
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

	# Dealing damage breaks the cloak (no pierce — Geode Panther's
	# decloak-strike is a plain attack).
	if damage > 0 and bool(enemy_state.get("cloaked", false)):
		enemy_state["cloaked"] = false
		_log("%s strikes from the shadows!" % enemy_state["unit"].display_name)
		_emit_event(enemy_state, "decloak", 0, "enemy")

	if damage > 0:
		var hits_all_heroes: bool = bool(raw.get("blastAll", false))
		var should_wipe_shields: bool = bool(raw.get("wipeShields", false))
		var scaled_damage: int = int(round(float(damage) * float(enemy_state.get("dmg_scale", 1.0))))
		var final_damage: int = scaled_damage
		if final_damage > 0 and int(enemy_state.get("rampage_charges", 0)) > 0:
			final_damage = scaled_damage * 2
			enemy_state["rampage_charges"] = int(enemy_state["rampage_charges"]) - 1
			_log("%s triggers Rampage! (2× damage)" % enemy_state["unit"].display_name)
		if bool(raw.get("packBonus", false)) and final_damage > 0:
			var pack_count: int = 0
			for es in _enemy_states:
				if es == enemy_state:
					continue
				if not es["dead"] and str(es["id"]) == str(enemy_state["id"]):
					pack_count += 1
			if pack_count > 0:
				final_damage += pack_count
				_log("%s pack bonus +%d (pack size: %d)." % [enemy_state["unit"].display_name, pack_count, pack_count])
		final_damage = int(floor(float(final_damage) * _get_enemy_dmg_mult()))
		if should_wipe_shields:
			_wipe_all_hero_shields(enemy_state)
		var attack_connected: bool = false
		if hits_all_heroes:
			for hero_state in _hero_states:
				if bool(hero_state["dead"]):
					continue
				if _ward_blocks_hostile(hero_state):
					continue
				attack_connected = true
				_break_cloak_on_aoe(hero_state)
				_damage_state(hero_state, final_damage, false, enemy_state)
				_apply_burn(hero_state, burn_amount, burn_turns)
			var lifesteal_pct: int = int(raw.get("lifestealPct", 0))
			if lifesteal_pct > 0 and final_damage > 0:
				var heal_amount: int = int(floor(float(final_damage) * float(lifesteal_pct) / 100.0))
				if heal_amount > 0:
					_heal_state(enemy_state, heal_amount)
					_log("%s lifesteals %d HP." % [enemy_state["unit"].display_name, heal_amount])
		else:
			var target_hero: Dictionary = hostile_hero_target
			if target_hero.is_empty():
				_log("%s finds no visible target — the attack fizzles." % enemy_state["unit"].display_name)
			if not target_hero.is_empty() and not _ward_blocks_hostile(target_hero):
				attack_connected = true
				_damage_state(target_hero, final_damage, false, enemy_state)
				_apply_burn(target_hero, burn_amount, burn_turns)
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
		if not hostile_hero_target.is_empty() and not _ward_blocks_hostile(hostile_hero_target):
			_apply_burn(hostile_hero_target, burn_amount, burn_turns)

	# RFE on heroes (roll debuff from enemies using rfm/rfmT keys)
	var rfm_amount: int = int(raw.get("rfm", 0))
	var rfm_turns: int = int(raw.get("rfmT", 1))
	if rfm_amount > 0:
		if not hostile_hero_target.is_empty() and not _ward_blocks_hostile(hostile_hero_target):
			_add_rfe_stack(hostile_hero_target, rfm_amount, rfm_turns)

	# ERB: enemy roll buff
	var erb_amount: int = int(raw.get("erb", 0))
	var erb_turns: int = int(raw.get("erbT", 1))
	var erb_all: bool = bool(raw.get("erbAll", false))
	if erb_amount > 0:
		if erb_all:
			for es in _enemy_states:
				if not es["dead"]:
					_add_roll_buff(es, erb_amount, erb_turns)
		else:
			_add_roll_buff(enemy_state, erb_amount, erb_turns)

	# Freeze hero dice (freeze = repeat, per Kev 2026-07-06): the crusted die
	# repeats its face on the hero's next N rolls. Enemy AI freeze always
	# targets the hero's LOWEST revealed die — deterministic, no randi — so the
	# squad's weakest result is the one that repeats (taunt still overrides).
	var enemy_freeze_one: int = int(raw.get("freezeEnemyDice", 0))
	var enemy_freeze_all: int = int(raw.get("freezeAllEnemyDice", 0))
	var enemy_freeze_flavor: String = str(raw.get("freeze_flavor", "ice"))
	if enemy_freeze_all > 0:
		for hero_state in _hero_states:
			if not hero_state["dead"] and not _ward_blocks_hostile(hero_state):
				_freeze_die_state(hero_state, enemy_freeze_all, enemy_freeze_flavor)
	elif enemy_freeze_one > 0:
		var freeze_rider_target: Dictionary = _freeze_pick_hero_lowest_die()
		if not freeze_rider_target.is_empty() and not _ward_blocks_hostile(freeze_rider_target):
			_freeze_die_state(freeze_rider_target, enemy_freeze_one, enemy_freeze_flavor)

	# Rampage grants (self or all enemies)
	var grant_rampage: int = int(raw.get("grantRampage", 0))
	var grant_rampage_all: bool = bool(raw.get("grantRampageAll", false))
	if grant_rampage > 0 or grant_rampage_all:
		var charges: int = maxi(grant_rampage, 1)
		if grant_rampage_all:
			for es in _enemy_states:
				if not es["dead"]:
					es["rampage_charges"] = int(es.get("rampage_charges", 0)) + charges
					_log("%s gains %d rampage charge(s)." % [es["unit"].display_name, charges])
		else:
			enemy_state["rampage_charges"] = int(enemy_state.get("rampage_charges", 0)) + charges
			_log("%s gains %d rampage charge(s)." % [enemy_state["unit"].display_name, charges])

	# Ward: block the next ability that targets this enemy, then break.
	if bool(raw.get("ward", false)):
		_apply_ward(enemy_state)

	# Jam hero dice: cap the targeted hero's (or every hero's) next roll at 10.
	if bool(raw.get("jamAll", false)):
		for hero_state in _hero_states:
			if not hero_state["dead"] and not _ward_blocks_hostile(hero_state):
				_apply_jam(hero_state, JAM_CAP, true)
	elif bool(raw.get("jam", false)):
		if not hostile_hero_target.is_empty() and not _ward_blocks_hostile(hostile_hero_target):
			_apply_jam(hostile_hero_target, JAM_CAP, true)

	# Rewrite hero dice (Synod): force the targeted hero's next roll to 3.
	if bool(raw.get("rewrite", false)):
		if not hostile_hero_target.is_empty() and not _ward_blocks_hostile(hostile_hero_target):
			_apply_rewrite(hostile_hero_target, true)

	# Hijack (enemy-only): this enemy's next roll copies the heroes' current
	# highest die.
	if bool(raw.get("hijack", false)):
		enemy_state["hijack_pending"] = true
		enemy_state["hijack_skip_next_tick"] = true
		_log("%s locks onto the squad's dice — its next roll will HIJACK the highest." % enemy_state["unit"].display_name)
		_emit_event(enemy_state, "hijack_primed", 0, "enemy")

	# Cloak (self): Geode Panther re-cloaks on recharge; Forked Double reforks.
	if bool(raw.get("cloak", false)):
		enemy_state["cloaked"] = true
		_log("%s fades from view (cloaked)." % enemy_state["unit"].display_name)
		_emit_event(enemy_state, "cloak", 0, "enemy")

	# Enemy-side Taunt (formerly Lure, Accretion): the targeted hero can only
	# target this enemy next turn. Internal state keeps the lured_by split.
	if bool(raw.get("taunt", false)):
		if not hostile_hero_target.is_empty() and not _ward_blocks_hostile(hostile_hero_target):
			hostile_hero_target["lured_by_id"] = str(enemy_state["id"])
			hostile_hero_target["lure_skip_next_tick"] = true
			_log("%s TAUNTS %s — next turn they can only strike back!" % [enemy_state["unit"].display_name, hostile_hero_target["unit"].display_name])
			_emit_event(hostile_hero_target, "taunt", 0, "hero")

	# Spike: heroes that damage this enemy next hero phase take N back. Granted
	# during the enemy phase, so it survives the imminent round-end tick to
	# cover exactly one hero phase (same asymmetry as shields).
	var enemy_spike: int = int(raw.get("spike", 0))
	if enemy_spike > 0:
		enemy_state["spike"] = maxi(int(enemy_state.get("spike", 0)), enemy_spike)
		enemy_state["spike_skip_next_tick"] = true
		_log("%s bristles with Spike %d." % [enemy_state["unit"].display_name, enemy_spike])
		_emit_event(enemy_state, "spike_up", enemy_spike, "enemy")

	# Curse dice: targeted hero rolls twice and keeps lower next round
	if bool(raw.get("curseDice", false)):
		if not hostile_hero_target.is_empty():
			hostile_hero_target["cursed"] = true
			_log("%s is CURSED — next roll will be the lower of two dice." % hostile_hero_target["unit"].display_name)
			_emit_event(hostile_hero_target, "curse", 0, "hero")

	# Taunt: force all heroes to target this enemy next player phase
	if bool(raw.get("enemySelfTaunt", false)):
		for es in _enemy_states:
			es["taunting"] = false
		enemy_state["taunting"] = true
		_log("%s is taunting — all heroes must target it!" % enemy_state["unit"].display_name)

	# Summon: Veil Concord overload natural 20 only (matches reference rules)
	var summon_chance: int = int(raw.get("summonChance", 0))
	var summon_name: String = str(raw.get("summonName", ""))
	if summon_chance > 0 and summon_name != "":
		_try_emit_enemy_summon(enemy_state, ability_entry, raw_roll, summon_chance, summon_name)


# Cloak: untargetable by hostile single-target abilities. Resolves the selected
# target, retargeting to the first living non-cloaked unit when the pick is
# invalid or cloaked; {} when every candidate is cloaked (the ability fizzles).
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
	return {}


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
		if reduction > 0:
			amount = maxi(0, amount - reduction)
			if amount == 0:
				return 0

	# Mark: the next hit on this target deals +50% (round up), then the Mark is
	# consumed. Only real attacks (attacker present) consume it — burn ticks and
	# aura chip damage leave the Mark standing.
	state["mark_consumed_this_hit"] = false
	if bool(state.get("marked", false)) and not attacker_state.is_empty():
		amount = int(ceil(float(amount) * 1.5))
		state["marked"] = false
		state["mark_consumed_this_hit"] = true
		_log("%s's Mark is consumed — the hit deals +50%% (%d)!" % [state["unit"].display_name, amount])
		_emit_event(state, "mark_consumed", amount, _resolve_side_for_state(state))

	# Cold Logic relic: enemies with frozen dice take +4 damage from attacks.
	if not _is_hero_state(state) and not attacker_state.is_empty() and int(state.get("die_freeze_turns", 0)) > 0 and has_relic("frozenBonusDamage"):
		var cold_bonus: int = int(_get_relic_value("frozenBonusDamage", "amount", 4))
		amount += cold_bonus
		_log("Cold Logic: +%d against the frozen die." % cold_bonus)

	# Attacker directives against enemy targets: Deep Cuts (vs Burning) and
	# Shatterpoint (vs frozen dice).
	if not _is_hero_state(state) and not attacker_state.is_empty() and _is_hero_state(attacker_state):
		if int(state.get("burn", 0)) > 0 and _has_directive(attacker_state, "bonusVsBurning"):
			var cuts_bonus: int = _directive_value(attacker_state, "amount", 3)
			amount += cuts_bonus
			_log("Deep Cuts: +%d against the Burning target." % cuts_bonus)
		if int(state.get("die_freeze_turns", 0)) > 0 and _has_directive(attacker_state, "bonusVsFrozen"):
			var shatter_bonus: int = _directive_value(attacker_state, "amount", 6)
			amount += shatter_bonus
			_log("Shatterpoint: +%d against the frozen die." % shatter_bonus)

	# Spike triggers on any damaging attempt that connects this round; read it
	# before the hit possibly downs this unit and clears its statuses.
	var spike_retaliation: int = int(state.get("spike", 0))

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
		var shield_before_hit: int = int(state.get("shield", 0))
		state["shield_stacks"] = surviving_stacks
		state["shield"] = _get_total_shield(state)
		# Salvage Rig (boss relic): +1 Protocol when an enemy shield fully breaks.
		if shield_before_hit > 0 and int(state["shield"]) == 0 and not _is_hero_state(state) and has_relic("protocolOnShieldBreak"):
			var rig_grant: int = int(_get_relic_value("protocolOnShieldBreak", "amount", 1))
			_pending_protocol_grants += rig_grant
			_log("Salvage Rig: +%d Protocol for shattering the shield." % rig_grant)

	if total_absorbed > 0:
		_log("%s absorbs %d damage with shields." % [state["unit"].display_name, total_absorbed])
		_emit_event(state, "block", total_absorbed, _resolve_side_for_state(state))

	# Spike: the attacker takes N for connecting with this unit this round —
	# even when shields ate the whole hit. Retaliation damage carries no
	# attacker, so two spiked units can't loop.
	if spike_retaliation > 0 and not attacker_state.is_empty() and not bool(attacker_state.get("dead", false)):
		_log("%s's Spike hits %s back for %d!" % [state["unit"].display_name, attacker_state["unit"].display_name, spike_retaliation])
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
			_log("%s VANISHES into Cloak!" % state["unit"].display_name)
			_emit_event(state, "cloak", 0, "hero")

	if int(state["current_hp"]) <= 0:
		# Gear: surviveOnce check
		if bool(state.get("gear_survive_once", false)) and not bool(state.get("gear_survive_once_used", false)):
			state["current_hp"] = 1
			state["gear_survive_once_used"] = true
			_log("%s survives on Dead Man's Chip at 1 HP!" % state["unit"].display_name)
			_emit_event(state, "survive", 1, _resolve_side_for_state(state))
		else:
			state["current_hp"] = 0
			state["dead"] = true
			_clear_active_statuses_for_down_state(state)
			_cancel_targets_involving_down_state(state)
			_log("%s is down." % state["unit"].display_name)
			_on_unit_killed(state, attacker_state)
			# Dead Man's Hand relic: the first squad wipe each run — everyone
			# survives at 1 HP and the next roll is all natural 20s.
			if _is_hero_state(state) and _all_states_dead(_hero_states) and has_relic("squadWipeSurvive") and not GameState.dead_mans_hand_used:
				GameState.dead_mans_hand_used = true
				_log("DEAD MAN'S HAND — the squad refuses to fall!")
				for hero_state in _hero_states:
					hero_state["dead"] = false
					hero_state["current_hp"] = 1
					hero_state["forced_nat20_pending"] = true
					_emit_event(hero_state, "survive", 1, "hero")

	return remaining_damage


func _trigger_low_hp_squad_roll_buff() -> void:
	if _low_hp_squad_buff_used or not has_relic("lowHpSquadRollBuff"):
		return
	_low_hp_squad_buff_used = true
	var buff_amount: int = int(_get_relic_value("lowHpSquadRollBuff", "amount", 0))
	if buff_amount <= 0:
		return
	for hero_state in _hero_states:
		if not hero_state["dead"]:
			_add_roll_buff(hero_state, buff_amount, 1)
	_log("Emergency signal: squad gains +%d roll this turn." % buff_amount)


func _is_basic_enemy(enemy_state: Dictionary) -> bool:
	var unit: EnemyData = enemy_state.get("unit") as EnemyData
	if unit == null:
		return true
	var enemy_type: String = str(unit.enemy_type).to_lower()
	return enemy_type != "boss" and not enemy_type.ends_with("boss")


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


func _apply_ward(state: Dictionary) -> void:
	if state.is_empty() or bool(state.get("dead", false)):
		return
	state["warded"] = true
	_log("%s raises a Firewall — the next ability that targets them is blocked." % state["unit"].display_name)
	_emit_event(state, "ward", 0, _resolve_side_for_state(state))


func _ward_blocks_hostile(target_state: Dictionary) -> bool:
	if target_state.is_empty():
		return false
	var target_id: String = str(target_state.get("id", ""))
	if _ability_ward_blocked_ids.has(target_id):
		return true
	if not bool(target_state.get("warded", false)):
		return false
	target_state["warded"] = false
	_ability_ward_blocked_ids[target_id] = true
	_log("%s's Firewall blocks the ability!" % target_state["unit"].display_name)
	_emit_event(target_state, "block", 0, _resolve_side_for_state(target_state))
	return true


# Freeze = repeat (per Kev 2026-07-06): the die crusts static in the tray
# (physical blocker other dice bounce off) at its current face; on each of its
# next `die_freeze_turns` rolls the unit acts again on that face, then the die
# thaws and rerolls. Re-freezing an already-frozen die adds repeats. While
# frozen the die is immune to Jam, Rewrite, and Hijack. `flavor` is cosmetic
# only (ice / petrify tint).
func _freeze_die_state(state: Dictionary, freeze_amount: int, flavor: String = "ice") -> void:
	var existing_turns: int = int(state.get("die_freeze_turns", 0))
	state["die_freeze_turns"] = existing_turns + freeze_amount
	state["freeze_flavor"] = flavor
	var frozen_value: int = int(state.get("frozen_die_value", 0))
	if frozen_value <= 0:
		frozen_value = int(state.get("last_die_value", 0))
	if frozen_value > 0:
		state["frozen_die_value"] = frozen_value
	_log("%s's die is frozen at %d — it repeats that result %d more time(s)." % [state["unit"].display_name, int(state.get("frozen_die_value", 0)), int(state.get("die_freeze_turns", 0))])
	_emit_event(state, "freeze", int(state.get("frozen_die_value", 0)), _resolve_side_for_state(state))
	_grant_mirror_plate_protocol(state)


# Enemy AI freeze pick: the living hero with the LOWEST revealed die face this
# round — deterministic (ties break to slot order, no randi). Taunt overrides
# everything; cloaked heroes can't be picked by hostile single-target effects.
func _freeze_pick_hero_lowest_die() -> Dictionary:
	var taunter: Dictionary = _get_taunting_hero_state()
	if not taunter.is_empty():
		return taunter
	var best: Dictionary = {}
	var best_value: int = 21
	for hero_state in _hero_states:
		if bool(hero_state["dead"]) or bool(hero_state.get("cloaked", false)):
			continue
		var face: int = int(_current_raw_hero_rolls.get(str(hero_state["id"]), 0))
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


func _resolve_revive_hp_pct(raw: Dictionary) -> int:
	var default_pct: int = int(raw.get("revivePct", 50))
	return GameState.get_revive_hp_pct(default_pct)


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
	_emit_event(state, "heal", int(state["current_hp"]), _resolve_side_for_state(state))


func _on_unit_killed(dead_state: Dictionary, killer_state: Dictionary = {}) -> void:
	if _chain_reaction_active:
		return
	_chain_reaction_active = true

	# Vengeance Protocol: when an ally falls, the surviving squad's next roll
	# is all natural 20s (once per battle).
	if has_relic("vengeanceProtocol") and _is_hero_state(dead_state) and not _vengeance_used:
		_vengeance_used = true
		for hero_state in _hero_states:
			if hero_state != dead_state and not hero_state["dead"]:
				hero_state["forced_nat20_pending"] = true
		_log("VENGEANCE PROTOCOL — the squad's next roll is all natural 20s!")

	# Chain Reaction relic: other living enemies take damage when an enemy dies
	if has_relic("chainReaction") and not _is_hero_state(dead_state):
		var chain_dmg = int(_get_relic_value("chainReaction", "amount", 4))
		for enemy_state in _enemy_states:
			if not enemy_state["dead"] and enemy_state != dead_state:
				_damage_state(enemy_state, chain_dmg)
		_log("Chain Reaction triggers!")

	# Dead Man's Charge route modifier: enemies deal 4 to a random hero on death.
	if not _is_hero_state(dead_state) and _battle_modifier == "deadMansCharge":
		var charge_targets: Array = _hero_states.filter(func(hs): return not bool(hs["dead"]))
		if not charge_targets.is_empty():
			var charge_target: Dictionary = charge_targets[randi() % charge_targets.size()]
			_log("DEAD MAN'S CHARGE — %s takes 4!" % charge_target["unit"].display_name)
			_damage_state(charge_target, 4)

	# Scavenger Manifest relic: the first kill each battle drops a consumable.
	if not _is_hero_state(dead_state) and has_relic("firstKillDropsConsumable") and not _scavenger_drop_done:
		_scavenger_drop_done = true
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
			# Chitin Graft (boss relic): heroes heal 3 on their kills.
			if has_relic("heroHealOnOwnKill"):
				var graft_heal: int = int(_get_relic_value("heroHealOnOwnKill", "amount", 3))
				_heal_state(killer_state, graft_heal, killer_state)
				_log("Chitin Graft: %s heals %d on the kill." % [killer_state["unit"].display_name, graft_heal])
			# Salvage Directive: killing a Marked enemy refunds Protocol.
			if has_relic("protocolOnMarkedKill") and bool(dead_state.get("mark_consumed_this_hit", false)):
				var refund: int = int(_get_relic_value("protocolOnMarkedKill", "amount", 2))
				_pending_protocol_grants += refund
				_log("Salvage Directive: +%d Protocol for downing a Marked target." % refund)
			# Momentum directive: each kill banks bonus damage for the next ability.
			if _has_directive(killer_state, "killNextAbilityDamage"):
				var momentum_gain: int = _directive_value(killer_state, "amount", 4)
				killer_state["momentum_bonus"] = int(killer_state.get("momentum_bonus", 0)) + momentum_gain
				_log("Momentum: %s banks +%d for the next strike." % [killer_state["unit"].display_name, momentum_gain])

	# Killswitch Relay gear: when this hero dies, deal damage to all enemies.
	if _is_hero_state(dead_state):
		SaveManager.record_hero_death()
		# SPITEFUL grudges die with the hero that earned them.
		var dead_hero_id: String = str(dead_state.get("id", ""))
		for enemy_state in _enemy_states:
			if str(enemy_state.get("last_attacker_id", "")) == dead_hero_id:
				enemy_state["last_attacker_id"] = ""
		var relay_damage: int = int(dead_state.get("gear_death_damage_all", 0))
		if relay_damage > 0:
			_log("%s's Killswitch Relay detonates for %d to all enemies!" % [dead_state["unit"].display_name, relay_damage])
			for enemy_state in _enemy_states:
				if not enemy_state["dead"]:
					_damage_state(enemy_state, relay_damage)

	_chain_reaction_active = false


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
	state["rewrite_pending"] = false
	state["rewrite_skip_next_tick"] = false
	state["hijack_pending"] = false
	state["hijack_skip_next_tick"] = false
	state["lured_by_id"] = ""
	state["lure_skip_next_tick"] = false
	state["last_attacker_id"] = ""
	state["cursed"] = false
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
		if has_relic("healGrantsShieldAll"):
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
func _apply_burn(state: Dictionary, amount: int, turns: int) -> void:
	if state.is_empty() or state["dead"] or amount <= 0 or turns <= 0:
		return
	var permanent: bool = turns >= PERMANENT_BURN_TURNS
	state["burn_stacks"].append({
		"amt": amount,
		"turns_left": turns,
		"skip_next_tick": true,
		"perm": permanent,
	})
	_refresh_burn_totals(state)
	if permanent:
		_log("%s is burning for %d — permanently." % [state["unit"].display_name, amount])
	else:
		_log("%s is burning for %d over %d turns." % [state["unit"].display_name, amount, turns])
	_emit_event(state, "burn", amount, _resolve_side_for_state(state))


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
	for hero_state in _hero_states:
		if not bool(hero_state["dead"]) and bool(hero_state.get("taunting", false)):
			return hero_state
	# Anchor Frame gear: taunts while above 50% HP (explicit taunts win).
	for hero_state in _hero_states:
		if bool(hero_state["dead"]) or not bool(hero_state.get("gear_anchor_taunt", false)):
			continue
		if int(hero_state["current_hp"]) * 2 > int(hero_state["max_hp"]):
			return hero_state
	return {}


func _tick_end_of_round_states() -> void:
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

	# Clear taunt on all enemies at end of round (re-applied each round if enemy rolls it again)
	for enemy_state in _enemy_states:
		if not enemy_state["dead"]:
			enemy_state["taunting"] = false


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
			_damage_state(state, tick_dmg)
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
	# copies the heroes' highest die at the next reveal, then clears.
	if bool(state.get("hijack_pending", false)):
		if bool(state.get("hijack_skip_next_tick", false)):
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

	# Jam caps exactly one roll: applied mid-round (after the target already
	# rolled) it skips this tick and caps the NEXT reveal, then clears.
	if int(state.get("jam_cap", 0)) > 0:
		if bool(state.get("jam_skip_next_tick", false)):
			state["jam_skip_next_tick"] = false
		else:
			state["jam_cap"] = 0

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

	# Tick roll-buff stacks: every stack loses a turn at every round-end tick
	# (an Nt instance cast on turn T is live turns T..T+N-1 — the contract of
	# the instance-timer ruling, per Kev 2026-07-06).
	if not (state.get("roll_buff_stacks", []) as Array).is_empty():
		var live_buff_stacks: Array = []
		for stack_variant in state.get("roll_buff_stacks", []):
			var stack: Dictionary = stack_variant
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
	_add_roll_buff(target_state, amount, turns)


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


func _try_emit_enemy_summon(enemy_state: Dictionary, ability_entry: Dictionary, raw_roll: int, summon_chance: int, summon_name: String) -> void:
	if _count_living_enemies() >= GameState.SQUAD_UNIT_LIMIT:
		return
	var enemy_unit: EnemyData = enemy_state.get("unit") as EnemyData
	if enemy_unit == null:
		return
	if str(ability_entry.get("zone", "")) != "overload":
		return
	if enemy_unit.ai_type != "smart" or not enemy_unit.can_summon_elite:
		return
	if raw_roll != 20:
		return
	if randi_range(1, 100) > summon_chance:
		return
	_log("%s calls for reinforcements — %s incoming!" % [enemy_state["unit"].display_name, summon_name])
	_round_events.append({
		"type": "summon",
		"amount": 0,
		"side": "enemy",
		"target_name": str(enemy_state["unit"].display_name),
		"summon_name": summon_name,
	})


func inject_enemy(enemy_data: EnemyData) -> Dictionary:
	if _count_living_enemies() >= GameState.SQUAD_UNIT_LIMIT:
		_log("Summon blocked — enemy field is full.")
		return {}

	var new_state: Dictionary = _create_runtime_state(enemy_data, _next_enemy_instance_id(enemy_data))
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
		# and celebrates the same as a natural 20 (intended).
	})


func _resolve_side_for_state(state: Dictionary) -> String:
	for hero_state in _hero_states:
		if hero_state == state:
			return "hero"
	return "enemy"
