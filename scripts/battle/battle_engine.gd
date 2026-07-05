# BattleEngine — the UI-free home for the battle rules that used to live in
# battle_scene.gd (the god object). Both the live battle screen and the headless
# balance sim call these methods, so a rule is written ONCE. (Package A.1 of the
# balance-sim project; see scripts/sim/DECOUPLING_NOTES.md.)
#
# Design contract: rules live here; each caller owns its own battle STATE
# (the roll / nudge / set dictionaries, the protocol pool) and passes it in.
# battle_scene keeps owning its dicts for its UI; the sim owns parallel dicts.
# Neither reimplements a rule — they both delegate here.
#
# combat_manager remains the authority for ability/keyword resolution; this
# engine only owns the roll-shaping + protocol-economy rules that sat in
# battle_scene, and drives combat_manager.resolve_round().
class_name BattleEngine
extends RefCounted

var combat_manager: CombatManager
var roll_provider: RollProvider


func _init(cm: CombatManager, provider: RollProvider = null) -> void:
	combat_manager = cm
	roll_provider = provider


# ── Effective-roll pipeline (extracted from battle_scene) ─────────────────────
# The value fed to combat_manager.resolve_round() after Set / freeze / Nudge /
# roll-buffs. Set forces an absolute effective roll (overrides everything);
# a frozen-consumed die returns its raw value; otherwise combat_manager's
# effective roll (buffs/rfe/jam/rewrite) plus the player's Nudge.

func effective_hero_roll(state: Dictionary, unit_id: String, hero_rolls: Dictionary, hero_roll_nudges: Dictionary, hero_roll_sets: Dictionary) -> int:
	var raw_roll: int = int(hero_rolls.get(unit_id, hero_rolls.get(str(unit_id), 0)))
	if raw_roll == 0:
		return 1
	# Set action forces an absolute effective roll, overriding freeze/nudge/buffs.
	if hero_roll_sets.has(unit_id) or hero_roll_sets.has(str(unit_id)):
		return clampi(int(hero_roll_sets.get(unit_id, hero_roll_sets.get(str(unit_id), raw_roll))), 1, 20)
	if bool(state.get("die_freeze_consumed_this_round", false)):
		return clampi(raw_roll, 1, 20)
	var nudge: int = int(hero_roll_nudges.get(unit_id, hero_roll_nudges.get(str(unit_id), 0)))
	var base_eff: int = combat_manager.get_effective_roll(state, raw_roll)
	return clampi(base_eff + nudge, 1, 20)


func effective_enemy_roll(state: Dictionary, unit_id: String, enemy_rolls: Dictionary) -> int:
	var raw_roll: int = int(enemy_rolls.get(unit_id, enemy_rolls.get(str(unit_id), 0)))
	if raw_roll == 0:
		return 1
	if bool(state.get("die_freeze_consumed_this_round", false)):
		return clampi(raw_roll, 1, 20)
	return combat_manager.get_effective_roll(state, raw_roll)


# Builds a dict of effective rolls for all living units in the given states
# array, for combat_manager.resolve_round(). Mirrors the original exactly: the
# enemy branch uses combat_manager.get_effective_roll directly (no frozen guard).
func build_effective_rolls(raw_rolls: Dictionary, states: Array, is_hero: bool, hero_rolls: Dictionary, hero_roll_nudges: Dictionary, hero_roll_sets: Dictionary) -> Dictionary:
	var eff: Dictionary = {}
	for state in states:
		if bool(state["dead"]):
			continue
		var uid: String = str(state["id"])
		var raw: int = int(raw_rolls.get(uid, 0))
		if raw == 0:
			continue
		if is_hero:
			eff[uid] = effective_hero_roll(state, uid, hero_rolls, hero_roll_nudges, hero_roll_sets)
		else:
			eff[uid] = combat_manager.get_effective_roll(state, raw)
	return eff


# ── Roll sourcing (extracted from battle_scene) ───────────────────────────────
# In the live game the roll VALUE comes from the physics tray; roll_states is
# the headless/fallback source. Both flow through the RollProvider seam, so the
# game uses PhysicsRollProvider (wraps DiceManager) and the sim uses
# SeededRollProvider — identical logic, different value stream.

func roll_states(states: Array) -> Dictionary:
	var rolls: Dictionary = {}
	for state_variant in states:
		var state: Dictionary = state_variant
		rolls[str(state["id"])] = roll_provider.roll_d20()
	return rolls


# Frozen dice ignore the fresh roll and reuse their locked value.
func apply_frozen_roll_overrides(states: Array, rolls: Dictionary) -> void:
	for state_variant in states:
		var state: Dictionary = state_variant
		if bool(state["dead"]):
			continue
		if int(state.get("die_freeze_turns", 0)) <= 0:
			continue
		var frozen_value: int = int(state.get("frozen_die_value", 0))
		if frozen_value <= 0:
			continue
		rolls[str(state["id"])] = frozen_value


# Stamps last_die_value (used by freeze items to capture the current face) and
# marks a frozen die as consumed this round (so its reveal is skipped).
func record_roll_values_for_states(states: Array, rolls: Dictionary) -> void:
	for state_variant in states:
		var state: Dictionary = state_variant
		if bool(state["dead"]):
			continue
		var roll_value: int = roll_value_for_state(rolls, state)
		if roll_value <= 0:
			continue
		state["last_die_value"] = roll_value
		if int(state.get("die_freeze_turns", 0)) > 0:
			state["die_freeze_consumed_this_round"] = true


func roll_value_for_state(rolls: Dictionary, state: Dictionary) -> int:
	var state_id: String = str(state.get("id", ""))
	if rolls.has(state_id):
		return int(rolls[state_id])
	var unit: Object = state.get("unit") as Object
	if unit == null:
		return 0
	var unit_id = unit.get("id")
	if unit_id != null and rolls.has(unit_id):
		return int(rolls[unit_id])
	return 0
