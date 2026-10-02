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
	bs.enemy_roll_nudges.clear()
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
func apply_battle_start_external_effects(effects: Dictionary, hero_run_mods: Dictionary, run_protocol_per_battle: int, fallen_hero_ids: Array = []) -> Dictionary:
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
		var roll_bonus: int = int(mods.get("roll_bonus", 0))
		if roll_bonus != 0:
			hero_state["perm_roll_buff"] = int(hero_state.get("perm_roll_buff", 0)) + roll_bonus
		var hp_delta: int = int(mods.get("max_hp_delta", 0))
		if hp_delta != 0:
			hero_state["max_hp"] = maxi(int(hero_state["max_hp"]) + hp_delta, 1)
			hero_state["current_hp"] = clampi(int(hero_state["current_hp"]) + hp_delta, 1, int(hero_state["max_hp"]))
		var start_damage: int = int(mods.get("start_hp_damage", 0))
		if fallen_hero_ids.has(unit_id):
			hero_state["current_hp"] = maxi(1, int(hero_state["max_hp"]) * 75 / 100)
			logs.append("%s returns at 75%% HP." % str(unit.display_name))
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
# A frozen die can't be altered (NK-03, G-23): the ONE check every Reroll /
# Nudge / Set path uses — the engine functions below refuse on their own, and
# the UI and the sim policies ask this instead of reading the freeze fields.
func can_alter_die(state: Dictionary) -> bool:
	return not state.is_empty() and int(state.get("die_freeze_turns", 0)) <= 0 \
		and not bool(state.get("die_freeze_repeat_this_round", false))


func _hero_state_by_id(hero_id: String) -> Dictionary:
	for hero_state in combat_manager.get_hero_states():
		if str(hero_state.get("id", "")) == hero_id:
			return hero_state
	return {}


# Returns the new raw roll, or 0 (nothing spent) when the die is frozen.
func apply_reroll(bs: BattleState, hero_id: String, landed_raw: int = 0) -> int:
	if not can_alter_die(_hero_state_by_id(hero_id)):
		return 0
	bs.protocol_points -= 2
	var new_roll: int = landed_raw if landed_raw > 0 else roll_provider.roll_d20()
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
	if not can_alter_die(_hero_state_by_id(hero_id)):
		return {"kind": "frozen"}
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


# Set costs SET_DIE_COST. (Kept as a function: the UI and the sim policies
# price Set through it.)
func set_cost(_bs: BattleState) -> int:
	return SET_DIE_COST


# Set-a-die to an absolute effective value; an explicit Set overrides any prior
# Nudge. Mutates bs; returns the cost paid, or -1 (nothing spent, nothing set)
# when the die is frozen.
func apply_set(bs: BattleState, hero_id: String, value: int) -> int:
	if not can_alter_die(_hero_state_by_id(hero_id)):
		return -1
	var cost: int = set_cost(bs)
	bs.protocol_points -= cost
	bs.hero_roll_sets[hero_id] = value
	bs.hero_roll_nudges.erase(hero_id)
	return cost


# ── Boss relics (rework, Kev 2026-09-27; DECISIONS_RESOLVED G-34..G-38) ──────
# The dice rules of the boss relics live here so the live screen and the
# headless sim share them. Blood Frenzy is a kill hook in combat_manager, and
# Tectonic Charge's +3 is granted there when round 1 ends.

# Scrap Converter (G-34): Protocol for each hero die in `hero_ids` whose
# physical landing SHOWS 1 or 2 (the printed face, modifiers included). The
# caller passes only dice that were just thrown or re-thrown, never a Set,
# Nudge or frozen repeat, and applies the amount through its own gain wrapper
# (the cap and Overflow Vent live there).
func landing_protocol(bs: BattleState, hero_ids: Array) -> int:
	if not combat_manager.has_relic("protocolOnLowLanding"):
		return 0
	var max_face: int = int(combat_manager.get_relic_value("protocolOnLowLanding", "maxFace", 2))
	var per_die: int = int(combat_manager.get_relic_value("protocolOnLowLanding", "amount", 1))
	var total: int = 0
	for id_variant in hero_ids:
		var hero_id: String = str(id_variant)
		var state: Dictionary = _hero_state_by_id(hero_id)
		if state.is_empty() or bool(state.get("dead", false)) or not can_alter_die(state):
			continue
		var raw: int = int(bs.hero_rolls.get(hero_id, 0))
		if raw <= 0:
			continue
		# The printed face: the landed natural through the same value rule the
		# faces were printed with (a fresh landing has no Nudge or Set).
		if combat_manager.get_effective_roll(state, raw) <= max_face:
			total += per_die
	return total


# The living hero dice that were thrown this roll (Scrap Converter's candidates
# after a full throw). A frozen die repeats; it did not land.
func thrown_hero_ids(bs: BattleState) -> Array:
	var ids: Array = []
	for state in combat_manager.get_hero_states():
		var hero_id: String = str(state["id"])
		if bool(state.get("dead", false)) or not bs.hero_rolls.has(hero_id) or not can_alter_die(state):
			continue
		ids.append(hero_id)
	return ids


# Firewall Hack (G-36): once per turn, Nudge one enemy die DOWN by the relic's
# amount for the normal Nudge cost. Never below 1 (the effective-roll clamp).
# A frozen die can't be altered (Dice rules 8) and a hijacked die copies the
# heroes' dice, so neither can be picked.
const FIREWALL_HACK_COST := 1


func firewall_hack_amount() -> int:
	return int(combat_manager.get_relic_value("enemyNudgeOncePerTurn", "amount", 3))


# "" when this die can be hacked now, else why not:
# "no_relic" | "used" | "no_die" | "frozen" | "hijacked" | "protocol".
func firewall_hack_block(bs: BattleState, enemy_state: Dictionary) -> String:
	if not combat_manager.has_relic("enemyNudgeOncePerTurn"):
		return "no_relic"
	if bs.firewall_hack_used:
		return "used"
	if enemy_state.is_empty() or bool(enemy_state.get("dead", false)) \
			or int(bs.enemy_rolls.get(str(enemy_state.get("id", "")), 0)) <= 0:
		return "no_die"
	if not can_alter_die(enemy_state):
		return "frozen"
	if bool(enemy_state.get("hijack_pending", false)):
		return "hijacked"
	if bs.protocol_points < FIREWALL_HACK_COST:
		return "protocol"
	return ""


# Applies the hack. True when it landed (cost paid, die lowered).
func apply_firewall_hack(bs: BattleState, enemy_state: Dictionary) -> bool:
	if firewall_hack_block(bs, enemy_state) != "":
		return false
	bs.protocol_points -= FIREWALL_HACK_COST
	bs.firewall_hack_used = true
	bs.enemy_roll_nudges[str(enemy_state["id"])] = -firewall_hack_amount()
	return true


# Heretic Signal (G-37): once per battle, for the relic's Protocol cost (3),
# every die on the board that isn't frozen is thrown again. Each re-thrown die is a fresh roll, like a Reroll:
# its Nudge / Set / Firewall Hack is cleared (not refunded). Frozen dice keep
# their value.
func heretic_signal_cost() -> int:
	return int(combat_manager.get_relic_value("rethrowAllOncePerBattle", "cost", 0))


func heretic_signal_available(bs: BattleState) -> bool:
	return combat_manager.has_relic("rethrowAllOncePerBattle") and not bs.heretic_signal_used \
		and not (bs.hero_rolls.is_empty() and bs.enemy_rolls.is_empty()) \
		and bs.protocol_points >= heretic_signal_cost()


# `landed` = {"hero": {id: raw}, "enemy": {id: raw}} from the live tray; empty =
# draw the seeded stream (sim / skip-visuals). Returns the re-thrown ids per
# side ({"hero": [...], "enemy": [...]}), or {} when it can't be used now.
func apply_heretic_signal(bs: BattleState, landed: Dictionary = {}) -> Dictionary:
	if not heretic_signal_available(bs):
		return {}
	bs.heretic_signal_used = true
	bs.protocol_points -= heretic_signal_cost()
	var thrown: Dictionary = {"hero": [], "enemy": []}
	for side in ["hero", "enemy"]:
		var states: Array = combat_manager.get_hero_states() if side == "hero" else combat_manager.get_enemy_states()
		var rolls: Dictionary = bs.hero_rolls if side == "hero" else bs.enemy_rolls
		var landed_side: Dictionary = landed.get(side, {})
		for state in states:
			var uid: String = str(state["id"])
			if bool(state.get("dead", false)) or not rolls.has(uid) or not can_alter_die(state):
				continue
			var raw: int = int(landed_side.get(uid, 0)) if not landed.is_empty() else roll_provider.roll_d20()
			if raw <= 0:
				continue
			rolls[uid] = raw
			if side == "hero":
				bs.hero_roll_nudges.erase(uid)
				bs.hero_roll_sets.erase(uid)
			else:
				bs.enemy_roll_nudges.erase(uid)
			(thrown[side] as Array).append(uid)
	return thrown


# Tectonic Charge (G-38): in round 1 of each battle the heroes hold - their
# dice are not thrown and they don't act. (The round-1 shield and the +3 from round 2 is a permanent
# roll buff combat_manager grants when round 1 ends.)
func heroes_hold_this_round() -> bool:
	return combat_manager.heroes_hold_this_round()


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
func item_enemy_reroll(bs: BattleState, target_state: Dictionary, landed_raw: int = 0) -> int:
	if target_state.is_empty():
		return 0
	if not can_alter_die(target_state):
		return 0
	var new_roll: int = landed_raw if landed_raw > 0 else roll_provider.roll_d20()
	bs.enemy_rolls[str(target_state["id"])] = new_roll
	return new_roll


func item_enemy_reroll_all(bs: BattleState) -> void:
	for enemy_state in combat_manager.get_enemy_states():
		if bool(enemy_state.get("dead", true)):
			continue
		if not can_alter_die(enemy_state):
			continue
		bs.enemy_rolls[str(enemy_state["id"])] = roll_provider.roll_d20()


# Freezes a die (either side — freeze = repeat, per Kev 2026-07-06): adds
# repeat turns and captures the value the die shows as the locked value
# (G-23; falling back to last_die_value / an existing frozen value). The unit acts again on that
# face for each repeat, then the die thaws.
func item_freeze_die(bs: BattleState, target_state: Dictionary, repeats: int) -> void:
	if target_state.is_empty():
		return
	var is_hero: bool = _is_hero_side_state(target_state)
	var rolls: Dictionary = bs.hero_rolls if is_hero else bs.enemy_rolls
	# G-23 (Kev 2026-09-26): freeze locks the number the die SHOWS — its
	# effective value (Nudge/Set/buffs/penalties/jam/rewrite/hijack included),
	# captured before the freeze lands. An already-frozen die returns its locked
	# value here, so a re-freeze keeps it.
	var frozen_value: int = 0
	var target_id: String = str(target_state.get("id", ""))
	if roll_value_for_state(rolls, target_state) > 0:
		frozen_value = effective_hero_roll(target_state, target_id, bs) if is_hero else effective_enemy_roll(target_state, target_id, bs)
	target_state["die_freeze_turns"] = int(target_state.get("die_freeze_turns", 0)) + repeats
	if frozen_value <= 0:
		frozen_value = int(target_state.get("last_die_value", target_state.get("frozen_die_value", 0)))
	if frozen_value > 0:
		target_state["frozen_die_value"] = frozen_value


func item_enemy_freeze_all(bs: BattleState, repeats: int) -> void:
	# Deep Freeze Charge sets unfrozen enemy dice to 1 and freezes them.
	# Already-frozen faces are immutable; only their duration extends (G-9).
	for enemy_state in combat_manager.get_enemy_states():
		if bool(enemy_state.get("dead", true)):
			continue
		if int(enemy_state.get("die_freeze_turns", 0)) > 0:
			enemy_state["die_freeze_turns"] = int(enemy_state["die_freeze_turns"]) + repeats
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
	return _hero_value_for_raw(state, unit_id, bs, raw_roll)


# The hero's value if its raw roll were `raw_roll`, in its CURRENT state
# (freeze lock, Set, Nudge, buffs/penalties/jam/rewrite). effective_hero_roll
# and the printed faces (current_face_values) share it.
func _hero_value_for_raw(state: Dictionary, unit_id: String, bs: BattleState, raw_roll: int) -> int:
	if _is_locked_by_freeze(state):
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
	return _enemy_value_for_raw(state, bs, raw_roll)


func _enemy_value_for_raw(state: Dictionary, bs: BattleState, raw_roll: int) -> int:
	if _is_locked_by_freeze(state):
		var frozen: int = int(state.get("frozen_die_value", raw_roll))
		return clampi(frozen if frozen > 0 else raw_roll, 1, 20)
	var hijacked: int = hijack_value(state, bs)
	if hijacked > 0:
		return hijacked
	# Firewall Hack: the player's -N Nudge on this enemy die (never below 1).
	var nudge: int = int(bs.enemy_roll_nudges.get(str(state.get("id", "")), 0))
	return clampi(combat_manager.get_effective_roll(state, raw_roll) + nudge, 1, 20)


# ── Printed faces (G-24) ──────────────────────────────────────────────────────
# Modifiers known before the roll are printed on the die before it is thrown:
# each face shows the value the unit would act on if the die landed on it. The
# raw override is the one battle_scene applies after landing (a forced 20)
# and the value rule is get_effective_roll (buffs, penalties,
# jam, rewrite) — the same functions, so the landed face always reads the value
# the engine then computes. Hijack is not known before the roll (it copies the
# heroes' dice) and is not printed; Rewrite is known but applied AFTER landing
# (G-43, Kev 2026-10-01): the die lands naturally, then tips onto its 3.

# The raw roll a landed natural becomes under the pre-roll raw override.
func pre_roll_raw(state: Dictionary, is_hero: bool, natural: int) -> int:
	if is_hero and bool(state.get("forced_20_pending", false)):
		return 20
	return natural


# The value printed on the face with natural number `natural`.
func pre_roll_face_value(state: Dictionary, is_hero: bool, natural: int) -> int:
	return combat_manager.get_effective_roll(state, pre_roll_raw(state, is_hero, natural), false)


# G-27 / G-25: the faces a die prints for its CURRENT state — face n reads the
# value the unit would act on with a raw roll of n. Used when a deliberate change
# needs a value no printed face shows: the die is reprinted with these and
# tumbles onto one showing the new value. Under a Set the die is a plain 1–20
# die ("plain": true) and tumbles onto the chosen face (G-25).
func current_face_values(state: Dictionary, unit_id: String, is_hero: bool, bs: BattleState) -> Dictionary:
	# G-43: a Rewrite is a Set to 3 applied after landing, so a rewritten die is
	# a plain 1–20 die too, either side: it tips onto its 3 face, reprinted
	# first only when its printed faces carry no 3.
	var rewritten: bool = bool(state.get("rewrite_pending", false))
	var plain: bool = not _is_locked_by_freeze(state) and (rewritten 		or (is_hero and (bs.hero_roll_sets.has(unit_id) or bs.hero_roll_sets.has(str(unit_id)))))
	var faces: Array = []
	for natural in range(1, 21):
		if plain:
			faces.append(natural)
		elif is_hero:
			faces.append(_hero_value_for_raw(state, unit_id, bs, natural))
		else:
			faces.append(_enemy_value_for_raw(state, bs, natural))
	return {"faces": faces, "plain": plain}


# G-23 (Kev 2026-09-26): a frozen die is locked on its number from the moment
# it freezes — on its repeat rounds (the old test) AND in the round a freeze
# item lands, so a modifier added or removed afterwards can't move it.
func _is_locked_by_freeze(state: Dictionary) -> bool:
	if bool(state.get("die_freeze_repeat_this_round", false)):
		return true
	return int(state.get("die_freeze_turns", 0)) > 0 and int(state.get("frozen_die_value", 0)) > 0


# Hijack (enemy-only): the die copies the heroes' current highest EFFECTIVE die
# — exactly what combat_manager.resolve_round copies from the effective hero
# rolls it is handed. Folded in here so the die, its readout and the intent all
# show the copy LIVE (Kev 2026-09-26): a Nudge/Set/Reroll/buff that changes the
# heroes' highest die before resolution changes the hijacked value with it.
# A frozen die is immune (its crusted face repeats). 0 = no hijack in effect.
func hijack_value(state: Dictionary, bs: BattleState) -> int:
	if not bool(state.get("hijack_pending", false)) or int(state.get("die_freeze_turns", 0)) > 0:
		return 0
	var highest: int = 0
	for hero_state in combat_manager.get_hero_states():
		if bool(hero_state.get("dead", false)):
			continue
		var hid: String = str(hero_state["id"])
		if int(bs.hero_rolls.get(hid, 0)) == 0:
			continue
		highest = maxi(highest, effective_hero_roll(hero_state, hid, bs))
	return highest


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
