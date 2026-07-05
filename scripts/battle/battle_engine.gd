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

const MAX_PROTOCOL := 10
const SET_DIE_COST := 3

var combat_manager: CombatManager
var roll_provider: RollProvider


func _init(cm: CombatManager, provider: RollProvider = null) -> void:
	combat_manager = cm
	roll_provider = provider


# ── Protocol economy (extracted from battle_scene) ────────────────────────────
# The pool value itself stays with the caller (battle_scene owns protocol_points
# for its bar; the sim owns its own int). These methods own the RULES: the cap
# (base 10, run override, Deep Cells directive) and gain-with-overflow (Overflow
# Vent relic damage, routed through the RollProvider so it is deterministic).

# cap_override: the caller passes GameState.run_protocol_cap_override (Rogue
# Engineer) or 0 when there is none / it is running outside the tree.
func max_protocol(cap_override: int) -> int:
	var cap: int = MAX_PROTOCOL
	if cap_override > 0:
		cap = cap_override
	if combat_manager == null:
		return cap
	# Deep Cells directive: the cap rises while a living carrier stands.
	for hero_state_variant in combat_manager.get_hero_states():
		var hero_state: Dictionary = hero_state_variant
		if not bool(hero_state.get("dead", false)) and str(hero_state.get("directive_type", "")) == "protocolCapBonus":
			cap += int((hero_state.get("directive_effect", {}) as Dictionary).get("amount", 2))
			break
	return cap


# Mutates bs.protocol_points in place and returns the Overflow Vent hits
# ([{target, amount}, …]) so the caller can update its bar/log without
# re-deriving. The vent DAMAGE is already applied here (via combat_manager).
func gain_protocol(bs: BattleState, amount: int, cap: int) -> Array:
	if amount <= 0:
		return []
	var overflow: int = maxi(0, bs.protocol_points + amount - cap)
	bs.protocol_points = mini(bs.protocol_points + amount, cap)
	var vent_hits: Array = []
	if overflow > 0 and combat_manager.has_relic("protocolOverflowDamage"):
		var per_point: int = 2
		for _i in overflow:
			var living: Array = combat_manager.get_enemy_states().filter(func(s): return not bool(s["dead"]))
			if living.is_empty():
				break
			var vent_target: Dictionary = living[roll_provider.rand_index(living.size())]
			combat_manager.apply_item_damage(vent_target, per_point)
			vent_hits.append({"target": vent_target, "amount": per_point})
	return vent_hits


# ── Protocol spends (extracted from battle_scene) ─────────────────────────────
# Rule cores only; the UI (dice-tray in-place update, retarget, logs, tutorial
# emit) stays in battle_scene. Gear-effect lookups (Priming Charge / Reverse
# Gimbal) are passed in as booleans so the engine stays free of GameState reads
# and safe on bare instances.
# SIM-TODO(kev): the sim computes the same gear booleans from its own GameState
# read; a shared gear-lookup util would remove that small duplication.

# Reroll: spend 2, redraw the die via the provider, clear this hero's Nudge/Set
# (their roll is fresh). Mutates bs; returns the new raw roll.
func apply_reroll(bs: BattleState, hero_id: String) -> int:
	bs.protocol_points -= 2
	var new_roll: int = roll_provider.roll_d20()
	bs.hero_rolls[hero_id] = new_roll
	bs.hero_roll_nudges.erase(hero_id)
	bs.hero_roll_sets.erase(hero_id)
	return new_roll


# Priming Charge: the first Nudge each battle is free (per holder).
func nudge_cost(bs: BattleState, hero_id: String, first_nudge_free_gear: bool) -> int:
	if first_nudge_free_gear and not bs.free_nudge_used.has(hero_id):
		return 0
	return 1


# Nudge. Returns { "kind": "flip"|"already"|"applied", ... } so the caller can
# drive UI/logs. Mutates bs.
#  - already nudged + Reverse Gimbal gear -> flip the pending nudge's sign (free)
#  - already nudged, no gear -> "already" (caller shows the "already nudged" note)
#  - otherwise -> deduct cost (0 if Priming Charge), set +3
func apply_nudge(bs: BattleState, hero_id: String, first_nudge_free_gear: bool, nudge_may_subtract_gear: bool) -> Dictionary:
	if bs.hero_roll_nudges.has(hero_id):
		if nudge_may_subtract_gear:
			bs.hero_roll_nudges[hero_id] = -int(bs.hero_roll_nudges.get(hero_id, 3))
			return {"kind": "flip", "value": int(bs.hero_roll_nudges[hero_id])}
		return {"kind": "already"}
	var cost: int = nudge_cost(bs, hero_id, first_nudge_free_gear)
	if cost == 0:
		bs.free_nudge_used[hero_id] = true
	bs.protocol_points -= cost
	bs.hero_roll_nudges[hero_id] = 3
	return {"kind": "applied", "cost": cost}


# Root Access boss relic: the first Set each battle costs 0.
func set_cost(bs: BattleState) -> int:
	if combat_manager.has_relic("setCostZeroOncePerBattle") and not bs.root_access_used:
		return 0
	return SET_DIE_COST


# Set-a-die to an absolute effective value; an explicit Set overrides any prior
# Nudge. Mutates bs; returns the cost paid (0 signals the Root Access freebie).
func apply_set(bs: BattleState, hero_id: String, value: int) -> int:
	var cost: int = set_cost(bs)
	if cost == 0:
		bs.root_access_used = true
	bs.protocol_points -= cost
	bs.hero_roll_sets[hero_id] = value
	bs.hero_roll_nudges.erase(hero_id)
	return cost


# Twin Fates relic: copy the source hero's raw die onto the target (free, once
# per battle). Mutates bs; returns false if the source has no roll yet.
func twin_fates_copy(bs: BattleState, source_id: String, target_id: String) -> bool:
	var source_roll: int = int(bs.hero_rolls.get(source_id, 0))
	if source_roll <= 0:
		return false
	bs.twin_fates_used = true
	bs.hero_rolls[target_id] = source_roll
	bs.hero_roll_nudges.erase(target_id)
	bs.hero_roll_sets.erase(target_id)
	return true


# ── Effective-roll pipeline (extracted from battle_scene) ─────────────────────
# The value fed to combat_manager.resolve_round() after Set / freeze / Nudge /
# roll-buffs. Set forces an absolute effective roll (overrides everything);
# a frozen-consumed die returns its raw value; otherwise combat_manager's
# effective roll (buffs/rfe/jam/rewrite) plus the player's Nudge.

func effective_hero_roll(state: Dictionary, unit_id: String, bs: BattleState) -> int:
	var raw_roll: int = int(bs.hero_rolls.get(unit_id, bs.hero_rolls.get(str(unit_id), 0)))
	if raw_roll == 0:
		return 1
	# Set action forces an absolute effective roll, overriding freeze/nudge/buffs.
	if bs.hero_roll_sets.has(unit_id) or bs.hero_roll_sets.has(str(unit_id)):
		return clampi(int(bs.hero_roll_sets.get(unit_id, bs.hero_roll_sets.get(str(unit_id), raw_roll))), 1, 20)
	if bool(state.get("die_freeze_consumed_this_round", false)):
		return clampi(raw_roll, 1, 20)
	var nudge: int = int(bs.hero_roll_nudges.get(unit_id, bs.hero_roll_nudges.get(str(unit_id), 0)))
	var base_eff: int = combat_manager.get_effective_roll(state, raw_roll)
	return clampi(base_eff + nudge, 1, 20)


func effective_enemy_roll(state: Dictionary, unit_id: String, bs: BattleState) -> int:
	var raw_roll: int = int(bs.enemy_rolls.get(unit_id, bs.enemy_rolls.get(str(unit_id), 0)))
	if raw_roll == 0:
		return 1
	if bool(state.get("die_freeze_consumed_this_round", false)):
		return clampi(raw_roll, 1, 20)
	return combat_manager.get_effective_roll(state, raw_roll)


# Builds a dict of effective rolls for all living units in the given states
# array, for combat_manager.resolve_round(). Mirrors the original exactly: the
# enemy branch uses combat_manager.get_effective_roll directly (no frozen guard).
func build_effective_rolls(raw_rolls: Dictionary, states: Array, is_hero: bool, bs: BattleState) -> Dictionary:
	var eff: Dictionary = {}
	for state in states:
		if bool(state["dead"]):
			continue
		var uid: String = str(state["id"])
		var raw: int = int(raw_rolls.get(uid, 0))
		if raw == 0:
			continue
		if is_hero:
			eff[uid] = effective_hero_roll(state, uid, bs)
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
