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
