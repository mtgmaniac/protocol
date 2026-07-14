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
const SET_DIE_COST := 4

var combat_manager: CombatManager
var roll_provider: RollProvider
var dice_manager: DiceManager


func _init(cm: CombatManager, provider: RollProvider = null, dm: DiceManager = null) -> void:
	combat_manager = cm
	roll_provider = provider
	dice_manager = dm
	# Share the seam so combat_manager's non-d20 random picks (Opening Salvo,
	# Dead Man's Charge, elite-summon) are seeded too (INVARIANTS #1).
	cm.roll_provider = provider


# ── Per-round resolution (extracted from battle_scene._resolve_current_turn) ──
# The one round-resolution path both the live screen and the sim run: build
# effective rolls, resolve_round through combat_manager, clear the spent roll
# state, and drain the pending protocol counters. Returns the combat result,
# the effective hero rolls (for XP recording), and the pending protocol grant /
# drain amounts for the caller to apply (grant via gain_protocol so cap/overflow
# live in one place; drain is a floor-0 subtract). UI (feedback, logging, scene
# handoff, income) stays in the caller.
func resolve_step(bs: BattleState) -> Dictionary:
	var hero_states: Array = combat_manager.get_hero_states()
	var enemy_states: Array = combat_manager.get_enemy_states()
	var eff_hero_rolls: Dictionary = build_effective_rolls(bs.hero_rolls, hero_states, true, bs)
	var eff_enemy_rolls: Dictionary = build_effective_rolls(bs.enemy_rolls, enemy_states, false, bs)
	var raw_enemy_rolls: Dictionary = bs.enemy_rolls.duplicate()
	var raw_hero_rolls: Dictionary = bs.hero_rolls.duplicate()
	var result: Dictionary = combat_manager.resolve_round(
		eff_hero_rolls,
		eff_enemy_rolls,
		dice_manager,
		raw_enemy_rolls,
		raw_hero_rolls
	)
	bs.hero_rolls.clear()
	bs.enemy_rolls.clear()
	bs.hero_roll_nudges.clear()
	bs.hero_roll_sets.clear()
	return {
		"result": result,
		"eff_hero_rolls": eff_hero_rolls,
		"eff_enemy_rolls": eff_enemy_rolls,
		"protocol_grant": combat_manager.take_pending_protocol_grants(),
		"protocol_drain": combat_manager.take_pending_protocol_drain(),
	}


# ── Battle-start / income rules (extracted from battle_scene, sim-B.2) ───────

# End-of-round income rule: +1 Protocol, except Blackout (no income before
# round 3) and Deep Cache income debt (each owed turn swallows the +1). Pure
# decision — the caller applies the gain through its own gain-protocol
# wrapper. reason: "blackout" | "debt" | "income".
func end_of_round_income(round_number: int, income_debt: int) -> Dictionary:
	if combat_manager != null and combat_manager.has_battle_modifier("blackout") and round_number < 3:
		return {"gain": 0, "debt_left": income_debt, "reason": "blackout"}
	if income_debt > 0:
		return {"gain": 0, "debt_left": income_debt - 1, "reason": "debt"}
	return {"gain": 1, "debt_left": 0, "reason": "income"}


# Protocol Tap gear: summed battle-start protocol from hero gear.
func gear_start_protocol() -> int:
	var total: int = 0
	for hero_state_variant in combat_manager.get_hero_states():
		total += int((hero_state_variant as Dictionary).get("gear_protocol_on_start", 0))
	return total


# Battle-start one-shots (intercept/route effects armed on GameState), applied
# through combat_manager so the sim and the live screen share one rule set.
# `effects` = the consumed next_battle_effects dict; `hero_run_mods` =
# GameState.hero_run_mods. Returns {"logs", "income_debt", "items_free",
# "start_protocol"} — the caller applies start_protocol through its own
# gain-protocol wrapper (cap/overflow rules apply there) and keeps the debt.
func apply_battle_start_external_effects(effects: Dictionary, hero_run_mods: Dictionary, run_protocol_per_battle: int) -> Dictionary:
	var logs: Array[String] = []
	if bool(effects.get("decoy", false)):
		combat_manager.set_decoy_round_one()
		logs.append("DECOY BEACON - enemies will waste turn 1.")
	var income_debt: int = int(effects.get("income_debt", 0))
	if income_debt > 0:
		logs.append("DEEP CACHE - %d turns of Protocol income are owed." % income_debt)
	var items_free: bool = bool(effects.get("items_free", false))
	if items_free:
		logs.append("SUPPLY DRONE - items cost 0 this battle.")

	var hp_pct: int = int(effects.get("enemy_hp_pct", 100))
	if hp_pct < 100:
		for enemy_state_variant in combat_manager.get_enemy_states():
			var enemy_state: Dictionary = enemy_state_variant
			enemy_state["current_hp"] = maxi(int(enemy_state["max_hp"]) * hp_pct / 100, 1)
		logs.append("UNSTABLE REACTOR - enemies spawn at %d%% HP." % hp_pct)

	if bool(effects.get("marked_highest", false)):
		var mark_target: Dictionary = {}
		for enemy_state_variant in combat_manager.get_enemy_states():
			var candidate: Dictionary = enemy_state_variant
			if mark_target.is_empty() or int(candidate["max_hp"]) > int(mark_target["max_hp"]):
				mark_target = candidate
		if not mark_target.is_empty():
			mark_target["current_hp"] = maxi(int(mark_target["max_hp"]) * 90 / 100, 1)
			combat_manager.apply_item_mark(mark_target)
			logs.append("FIRING SOLUTION - %s starts Marked at 90%% HP." % mark_target["unit"].display_name)

	# Rogue Engineer + intercept protocol grants (applied by the caller).
	var start_protocol: int = int(effects.get("protocol", 0)) + run_protocol_per_battle

	# Per-run hero mods from intercept outcomes.
	for hero_state_variant in combat_manager.get_hero_states():
		var hero_state: Dictionary = hero_state_variant
		var unit: Variant = hero_state.get("unit")
		var unit_id: String = str((unit as UnitData).id) if unit is UnitData else str(hero_state.get("id", ""))
		var mods: Dictionary = hero_run_mods.get(unit_id, {})
		if mods.is_empty():
			continue
		var roll_bonus: int = int(mods.get("roll_bonus", 0))
		if roll_bonus != 0:
			hero_state["perm_roll_buff"] = int(hero_state.get("perm_roll_buff", 0)) + roll_bonus
		var hp_delta: int = int(mods.get("max_hp_delta", 0))
		if hp_delta != 0:
			hero_state["max_hp"] = maxi(int(hero_state["max_hp"]) + hp_delta, 1)
			hero_state["current_hp"] = clampi(int(hero_state["current_hp"]) + hp_delta, 1, int(hero_state["max_hp"]))
		var start_damage: int = int(mods.get("start_hp_damage", 0))
		if start_damage > 0:
			hero_state["current_hp"] = maxi(int(hero_state["current_hp"]) - start_damage, 1)
			mods["start_hp_damage"] = 0
		if bool(mods.get("start_cloaked", false)):
			hero_state["cloaked"] = true
		if bool(mods.get("start_warded", false)):
			hero_state["warded"] = true
		if bool(mods.get("nat20_twice", false)):
			hero_state["nat20_twice"] = true

	return {"logs": logs, "income_debt": income_debt, "items_free": items_free, "start_protocol": start_protocol}


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


# ── Item effects not on combat_manager (extracted from battle_scene) ──────────
# The item-effect dispatch + logging stay in battle_scene; these own the effect
# mutations that used to be inline there. Most item types already delegate to
# combat_manager.apply_item_* (heal/shield/ward/rollBuff/revive/rfe/dmg/burn) —
# those need nothing here. These are the ones combat_manager can't own: enemy
# reroll needs the RollProvider; enemy freeze needs the roll dicts in
# BattleState; cloak is a hero-state flag.

# Flat cost 1; Protocol Override / Supply Drone make items free; Sealed Supplies
# adds +1. items_free = battle_scene's _battle_effects "items_free" (Supply Drone).
func item_protocol_cost(items_free: bool) -> int:
	if combat_manager.has_relic("protocolOnItemUse"):
		return 0
	if items_free:
		return 0
	if combat_manager.has_battle_modifier("sealedSupplies"):
		return 2
	return 1


func item_cloak(target_state: Dictionary) -> void:
	target_state["cloaked"] = true


func item_cloak_all() -> void:
	for hero_state in combat_manager.get_hero_states():
		if not bool(hero_state.get("dead", true)):
			hero_state["cloaked"] = true


# Rerolls an enemy die via the provider; returns the new roll. A frozen die
# is crusted static — its face is locked, so the reroll fizzles (returns 0).
func item_enemy_reroll(bs: BattleState, target_state: Dictionary) -> int:
	if target_state.is_empty():
		return 0
	if int(target_state.get("die_freeze_turns", 0)) > 0:
		return 0
	var new_roll: int = roll_provider.roll_d20()
	bs.enemy_rolls[str(target_state["id"])] = new_roll
	return new_roll


func item_enemy_reroll_all(bs: BattleState) -> void:
	for enemy_state in combat_manager.get_enemy_states():
		if bool(enemy_state.get("dead", true)):
			continue
		if int(enemy_state.get("die_freeze_turns", 0)) > 0:
			continue
		bs.enemy_rolls[str(enemy_state["id"])] = roll_provider.roll_d20()


# Freezes a die (either side — freeze = repeat, per Kev 2026-07-06): adds
# repeat turns and captures the current face as the locked value (falling back
# to last_die_value / an existing frozen value). The unit acts again on that
# face for each repeat, then the die thaws.
func item_freeze_die(bs: BattleState, target_state: Dictionary, repeats: int) -> void:
	if target_state.is_empty():
		return
	var rolls: Dictionary = bs.hero_rolls if _is_hero_side_state(target_state) else bs.enemy_rolls
	target_state["die_freeze_turns"] = int(target_state.get("die_freeze_turns", 0)) + repeats
	var frozen_value: int = roll_value_for_state(rolls, target_state)
	if frozen_value <= 0:
		frozen_value = int(target_state.get("last_die_value", target_state.get("frozen_die_value", 0)))
	if frozen_value > 0:
		target_state["frozen_die_value"] = frozen_value


func item_enemy_freeze_all(bs: BattleState, repeats: int) -> void:
	# Deep Zero Pin (NK-14 redesign): pins every enemy die to its LOWEST face
	# (1 → recharge zone, each unit's weakest ability) and freezes it there, so
	# every enemy repeats its weakest result for `repeats` rounds. Under
	# freeze=repeat this is unambiguously strong; the old "keep whatever face
	# showed" could replay an enemy crit (audit A-066), making a rare item
	# situational. BASELINE-SENSITIVE — expected to move the sim baseline.
	for enemy_state in combat_manager.get_enemy_states():
		if bool(enemy_state.get("dead", true)):
			continue
		bs.enemy_rolls[str(enemy_state["id"])] = 1
		enemy_state["last_die_value"] = 1
		enemy_state["frozen_die_value"] = 1
		enemy_state["die_freeze_turns"] = int(enemy_state.get("die_freeze_turns", 0)) + repeats


func _is_hero_side_state(state: Dictionary) -> bool:
	for hero_state in combat_manager.get_hero_states():
		if hero_state == state:
			return true
	return false


# sim-D: the consumable effect DISPATCH, extracted from
# battle_scene._apply_item_effect so the live screen and the sim share one
# implementation. Applies the combat-state mutation and returns a log line;
# the pool half (item cost, gainProtocol, Overflow Vent) stays with the caller
# since it owns the Protocol pool + its logging. `revive_pct` is the resolved
# percentage (caller applies its own GameState revive modifier). Returns "" for
# gainProtocol (caller handles it) and unknown types.
func apply_consumable_effect(effect: Dictionary, target_state: Dictionary, bs: BattleState, revive_pct: int, item_name: String) -> String:
	var tname: String = _state_display_name(target_state)
	match str(effect.get("type", "")):
		"heal":
			var a: int = int(effect.get("amount", 0))
			combat_manager.apply_item_heal(target_state, a)
			return "Item: %s heals %s for %d." % [item_name, tname, a]
		"healAll":
			var a: int = int(effect.get("amount", 0))
			combat_manager.apply_item_heal_all(a)
			return "Item: %s heals all living allies for %d." % [item_name, a]
		"shield":
			var a: int = int(effect.get("amount", 0))
			combat_manager.apply_item_shield(target_state, a)
			return "Item: %s grants %d shield to %s." % [item_name, a, tname]
		"shieldAll":
			var a: int = int(effect.get("amount", 0))
			combat_manager.apply_item_shield_all(a)
			return "Item: %s grants all living allies %d shield." % [item_name, a]
		"ward":
			combat_manager.apply_item_ward(target_state)
			return "Item: %s raises a Firewall on %s." % [item_name, tname]
		"rollBuff":
			var a: int = int(effect.get("amount", 0))
			var t: int = int(effect.get("turns", 1))
			combat_manager.apply_item_roll_buff(target_state, a, t)
			return "Item: %s gives %s +%d roll for %d turns." % [item_name, tname, a, t]
		"revive":
			combat_manager.apply_item_revive(target_state, revive_pct)
			return "Item: %s revives %s at %d%% HP." % [item_name, tname, revive_pct]
		"cloak":
			item_cloak(target_state)
			return "Item: %s cloaks %s." % [item_name, tname]
		"cloakAll":
			item_cloak_all()
			return "Item: %s - all living allies cloaked." % item_name
		"enemyRfe":
			var a: int = int(effect.get("amount", 0))
			var t: int = int(effect.get("rfT", 1))
			combat_manager.apply_item_rfe(target_state, a, t)
			return "Item: %s applies -%d RFE to %s for %d turns." % [item_name, a, tname, t]
		"enemyDmg":
			var a: int = int(effect.get("amount", 0))
			combat_manager.apply_item_damage(target_state, a)
			return "Item: %s deals %d damage to %s." % [item_name, a, tname]
		"enemyBurn":
			var a: int = int(effect.get("amount", 0))
			var t: int = int(effect.get("burnT", 1))
			combat_manager.apply_item_burn(target_state, a, t)
			return "Item: %s applies %d burn to %s for %d turns." % [item_name, a, tname, t]
		"enemyRerollDie":
			if not target_state.is_empty():
				var r: int = item_enemy_reroll(bs, target_state)
				if r <= 0:
					return "Item: %s fizzles - %s's die is frozen solid." % [item_name, tname]
				return "Item: %s rerolls %s -> %d." % [item_name, tname, r]
		"enemyRerollAll":
			item_enemy_reroll_all(bs)
			return "Item: %s - all unfrozen enemy dice rerolled." % item_name
		"anyDieFreeze":
			if not target_state.is_empty():
				var s: int = int(effect.get("repeats", 1))
				item_freeze_die(bs, target_state, s)
				return "Item: %s freezes %s's die - it repeats its result %d more time(s)." % [item_name, tname, s]
		"enemyDieFreezeAll":
			var s: int = int(effect.get("repeats", 1))
			item_enemy_freeze_all(bs, s)
			return "Item: %s - all enemy dice frozen; each repeats its result." % item_name
	return ""


func _state_display_name(state: Dictionary) -> String:
	if state.is_empty():
		return "?"
	var u: Object = state.get("unit") as Object
	if u == null:
		return "?"
	var name_val = u.get("display_name")
	return str(name_val) if name_val != null else "?"


# ── Effective-roll pipeline (extracted from battle_scene) ─────────────────────
# The value fed to combat_manager.resolve_round() after Set / freeze / Nudge /
# roll-buffs. A repeating frozen die is fully locked — its crusted face IS the
# result (no Set/Nudge/buffs/jam/rewrite; freeze = repeat, per Kev 2026-07-06).
# Otherwise Set forces an absolute effective roll, else combat_manager's
# effective roll (buffs/rfe/jam/rewrite) plus the player's Nudge.

func effective_hero_roll(state: Dictionary, unit_id: String, bs: BattleState) -> int:
	var raw_roll: int = int(bs.hero_rolls.get(unit_id, bs.hero_rolls.get(str(unit_id), 0)))
	if raw_roll == 0:
		return 1
	if bool(state.get("die_freeze_repeat_this_round", false)):
		var frozen: int = int(state.get("frozen_die_value", raw_roll))
		return clampi(frozen if frozen > 0 else raw_roll, 1, 20)
	# Set action forces an absolute effective roll, overriding nudge/buffs.
	if bs.hero_roll_sets.has(unit_id) or bs.hero_roll_sets.has(str(unit_id)):
		return clampi(int(bs.hero_roll_sets.get(unit_id, bs.hero_roll_sets.get(str(unit_id), raw_roll))), 1, 20)
	var nudge: int = int(bs.hero_roll_nudges.get(unit_id, bs.hero_roll_nudges.get(str(unit_id), 0)))
	var base_eff: int = combat_manager.get_effective_roll(state, raw_roll)
	return clampi(base_eff + nudge, 1, 20)


func effective_enemy_roll(state: Dictionary, unit_id: String, bs: BattleState) -> int:
	var raw_roll: int = int(bs.enemy_rolls.get(unit_id, bs.enemy_rolls.get(str(unit_id), 0)))
	if raw_roll == 0:
		return 1
	if bool(state.get("die_freeze_repeat_this_round", false)):
		var frozen: int = int(state.get("frozen_die_value", raw_roll))
		return clampi(frozen if frozen > 0 else raw_roll, 1, 20)
	return combat_manager.get_effective_roll(state, raw_roll)


# Builds a dict of effective rolls for all living units in the given states
# array, for combat_manager.resolve_round(). Both sides route through the
# frozen-repeat guard — a repeating enemy die must act on its crusted face,
# not a buffed/jammed variant of it.
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
			eff[uid] = effective_enemy_roll(state, uid, bs)
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
# marks a frozen die as repeating this round (the unit acts again on the
# crusted face; the repeat is spent at the round-end tick).
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
			state["die_freeze_repeat_this_round"] = true


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
