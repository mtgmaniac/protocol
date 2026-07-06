# L1 — greedy-heuristic policy (Package B.3). A deterministic proxy for a
# competent-but-uncalculating player: focus fire, spend protocol when it
# visibly upgrades a die, draft by rarity. Every heuristic is documented at
# its site; none of them read balance numbers beyond what the player sees on
# screen. L1 is the sanity baseline: it must beat L0 on clear rate, and
# balance conclusions in Package E are drawn from L1 runs.
#
# The seeded rng is kept (interface contract) but L1 is deterministic — it
# never draws from it.
class_name PolicyL1Greedy
# Path-extends so a fresh checkout's headless run parses before the editor
# rebuilds the global class cache.
extends "res://scripts/sim/policies/player_policy.gd"

const RARITY_RANK := {"legendary": 4, "epic": 3, "rare": 3, "uncommon": 2, "common": 1, "": 2}

# Archetype draft bias (Package D). A drafter prefers content whose effect
# matches its build tag; ties and no-match fall back to L1's rarity pick. This
# is what makes "is X OP in the build that WANTS it" answerable. Matched on
# item effect.type substrings (data-driven, no hand-tagging). "value" = the
# default L1 rarity picker (no bias). Layered on any play policy (L2 inherits).
const ARCHETYPE_AFFINITY := {
	"burn": ["burn", "detonate", "ignit"],
	"control": ["freeze", "rfe", "reroll", "jam", "rewrite", "cloak"],
	"protocol": ["protocol"],
	"value": [],
}

var archetype: String = ""  # "" or "value" = unbiased rarity pick


func describe() -> String:
	return "l1" if archetype == "" or archetype == "value" else "l1_%s" % archetype


# ── Round: focus fire + band-aware spends ─────────────────────────────────────
func decide_round(engine: BattleEngine, bs: BattleState, cm: CombatManager, _gs: Node) -> Array:
	var spends: Array = []
	# Focus fire: every hero aims at the lowest-HP living, uncloaked enemy —
	# finishing kills removes enemy actions from the board fastest.
	# Exception (freeze = repeat, per Kev 2026-07-06): a hero whose current
	# band applies freeze aims at the enemy showing the LOWEST die instead —
	# pinning the weakest enemy result is the play; never freeze allied dice.
	var focus: Dictionary = _lowest_hp_enemy(cm)
	if not focus.is_empty():
		for hero_state_variant in cm.get_hero_states():
			var hero_state: Dictionary = hero_state_variant
			if bool(hero_state.get("dead", false)):
				continue
			hero_state["selected_target_id"] = str(focus["id"])
			var unit_id: String = str(hero_state["id"])
			if not bs.hero_rolls.has(unit_id) or engine.dice_manager == null:
				continue
			var eff: int = engine.effective_hero_roll(hero_state, unit_id, bs)
			var band_raw: Dictionary = engine.dice_manager.get_ability_for_roll(hero_state.get("unit"), eff).get("raw", {})
			var applies_freeze: bool = int(band_raw.get("freezeAnyDice", 0)) > 0 or int(band_raw.get("freezeEnemyDice", 0)) > 0
			if applies_freeze:
				var freeze_pick: Dictionary = _lowest_die_unfrozen_enemy(bs, cm)
				if not freeze_pick.is_empty():
					hero_state["selected_target_id"] = str(freeze_pick["id"])

	# Spends, in priority order, one pass over the squad. Keep a 1-point buffer
	# so Siphon/next-round income swings don't zero us out.
	# 1) Reroll dice <= 4 (a bottom-band die is nearly a wasted turn).
	for hero_state_variant in cm.get_hero_states():
		var hero_state: Dictionary = hero_state_variant
		if bool(hero_state.get("dead", false)):
			continue
		var unit_id: String = str(hero_state["id"])
		if not bs.hero_rolls.has(unit_id):
			continue
		if bs.protocol_points >= 3 and int(bs.hero_rolls[unit_id]) <= 4 \
				and not bool(hero_state.get("die_freeze_repeat_this_round", false)) \
				and int(hero_state.get("die_freeze_turns", 0)) <= 0:
			var new_roll: int = engine.apply_reroll(bs, unit_id)
			spends.append({"kind": "reroll", "unit": unit_id, "cost": 2, "detail": "-> %d" % new_roll})
	# 2) Nudge when +3 lifts the hero's EFFECTIVE roll into a stronger band.
	for hero_state_variant in cm.get_hero_states():
		var hero_state: Dictionary = hero_state_variant
		if bool(hero_state.get("dead", false)):
			continue
		var unit_id: String = str(hero_state["id"])
		if not bs.hero_rolls.has(unit_id) or bs.hero_roll_nudges.has(unit_id) or bs.hero_roll_sets.has(unit_id):
			continue
		if bs.protocol_points < 2 or bool(hero_state.get("die_freeze_repeat_this_round", false)):
			continue
		var eff: int = engine.effective_hero_roll(hero_state, unit_id, bs)
		if _band_improves(engine, hero_state, eff, mini(eff + 3, 20)):
			var nudged: Dictionary = engine.apply_nudge(bs, unit_id, false, false)
			if str(nudged.get("kind", "")) == "applied":
				spends.append({"kind": "nudge", "unit": unit_id, "cost": int(nudged.get("cost", 1)), "detail": "+3"})
	# 3) Set-a-die 20 when flush (cost + 3 buffer) and a die is still mid-band —
	#    banked protocol is worthless in a lost run; convert it to an overload.
	for hero_state_variant in cm.get_hero_states():
		var hero_state: Dictionary = hero_state_variant
		if bool(hero_state.get("dead", false)):
			continue
		var unit_id: String = str(hero_state["id"])
		if not bs.hero_rolls.has(unit_id) or bs.hero_roll_sets.has(unit_id):
			continue
		if bool(hero_state.get("die_freeze_repeat_this_round", false)):
			continue
		if bs.protocol_points >= engine.set_cost(bs) + 3 and engine.effective_hero_roll(hero_state, unit_id, bs) < 11:
			var paid: int = engine.apply_set(bs, unit_id, 20)
			spends.append({"kind": "set", "unit": unit_id, "cost": paid, "detail": "= 20"})
			break  # at most one Set per round
	return spends


# ── Consumable use (sim-D): one item per round, triage-first. ─────────────────
# Effect-type → intent. Heals/shields when a hero is hurt; offensive items on
# the focus enemy; Protocol top-up when the pool is low. Deterministic (no rng).
func decide_items(bs: BattleState, cm: CombatManager, gs: Node) -> Array:
	var consumables: Array = gs.get("consumables")
	if consumables.is_empty():
		return []
	# Index held consumables by effect type.
	var by_type: Dictionary = {}
	for cid in consumables:
		var item: ItemData = DataManager.get_item(str(cid)) as ItemData
		if item != null:
			by_type[str(item.effect.get("type", ""))] = str(cid)

	# 1) Emergency heal/shield if a hero is below 45% HP.
	var hurt: Dictionary = {}
	for hs in cm.get_hero_states():
		var s: Dictionary = hs
		if bool(s.get("dead", false)):
			continue
		if float(s.get("current_hp", 0)) < 0.45 * float(s.get("max_hp", 1)):
			if hurt.is_empty() or int(s["current_hp"]) < int(hurt["current_hp"]):
				hurt = s
	if not hurt.is_empty():
		for t in ["healAll", "heal", "shieldAll", "shield"]:
			if by_type.has(t):
				return [{"item_id": by_type[t], "target_id": str(hurt["id"]), "side": "hero"}]

	# 2) Freeze the ENEMY die showing the lowest face (freeze = repeat: pin the
	#    enemy to its weakest result). Never freeze allied dice — repeating an
	#    ally is a judgment call the greedy policy doesn't make.
	if by_type.has("anyDieFreeze"):
		var freeze_target: Dictionary = _lowest_die_unfrozen_enemy(bs, cm)
		if not freeze_target.is_empty():
			return [{"item_id": by_type["anyDieFreeze"], "target_id": str(freeze_target["id"]), "side": "enemy"}]

	# 3) Offensive item on the focus (lowest-HP) enemy.
	var focus: Dictionary = _lowest_hp_enemy(cm)
	if not focus.is_empty():
		for t in ["enemyDmg", "enemyBurn", "enemyRfe"]:
			if by_type.has(t):
				return [{"item_id": by_type[t], "target_id": str(focus["id"]), "side": "enemy"}]

	# 4) Protocol top-up when nearly empty and a source is held.
	if bs.protocol_points <= 1 and by_type.has("gainProtocol"):
		return [{"item_id": by_type["gainProtocol"], "target_id": "", "side": ""}]
	return []


# The living, uncloaked, not-yet-frozen enemy whose die shows the lowest face
# this round. Deterministic: strict less-than keeps slot order on ties.
func _lowest_die_unfrozen_enemy(bs: BattleState, cm: CombatManager) -> Dictionary:
	var best: Dictionary = {}
	var best_face: int = 21
	for enemy_state_variant in cm.get_enemy_states():
		var enemy_state: Dictionary = enemy_state_variant
		if bool(enemy_state.get("dead", false)) or bool(enemy_state.get("cloaked", false)):
			continue
		if int(enemy_state.get("die_freeze_turns", 0)) > 0:
			continue
		var face: int = int(bs.enemy_rolls.get(str(enemy_state["id"]), 0))
		if face <= 0:
			continue
		if face < best_face:
			best_face = face
			best = enemy_state
	return best


func _lowest_hp_enemy(cm: CombatManager) -> Dictionary:
	var best: Dictionary = {}
	for enemy_state_variant in cm.get_enemy_states():
		var enemy_state: Dictionary = enemy_state_variant
		if bool(enemy_state.get("dead", false)) or bool(enemy_state.get("cloaked", false)):
			continue
		if best.is_empty() or int(enemy_state["current_hp"]) < int(best["current_hp"]):
			best = enemy_state
	return best


func _band_improves(engine: BattleEngine, hero_state: Dictionary, eff_now: int, eff_then: int) -> bool:
	if eff_then <= eff_now or engine.dice_manager == null:
		return false
	var unit: Resource = hero_state.get("unit")
	var band_now: String = str(engine.dice_manager.get_ability_for_roll(unit, eff_now).get("zone", ""))
	var band_then: String = str(engine.dice_manager.get_ability_for_roll(unit, eff_then).get("zone", ""))
	return band_now != band_then


# ── Draft: archetype affinity first (if set), then rarity; gear to the
# least-geared hero. Score = (affinity, rarity) lexicographically. ────────────
func choose_draft(items: Array, gs: Node) -> Dictionary:
	var best: ItemData = null
	var best_key: Array = [-1, -1]
	for item_variant in items:
		var item: ItemData = item_variant as ItemData
		if item == null:
			continue
		if item.item_type == "consumable" and (gs.get("consumables") as Array).size() >= int(gs.get("MAX_CONSUMABLES")):
			continue
		var key: Array = [_affinity(item), int(RARITY_RANK.get(str(item.rarity).to_lower(), 2))]
		if key[0] > best_key[0] or (key[0] == best_key[0] and key[1] > best_key[1]):
			best_key = key
			best = item
	if best == null:
		return {"id": "", "target_unit": ""}
	var target_unit: String = ""
	if best.item_type == "gear":
		target_unit = _least_geared_unit(gs)
	return {"id": best.id, "target_unit": target_unit}


# 1 if the item's effect matches the active archetype, else 0 (always 0 for
# "value"/unset — the default rarity picker).
func _affinity(item: ItemData) -> int:
	var tags: Array = ARCHETYPE_AFFINITY.get(archetype, [])
	if tags.is_empty():
		return 0
	var etype: String = str((item.effect as Dictionary).get("type", "")).to_lower()
	for tag in tags:
		if etype.contains(str(tag)):
			return 1
	return 0


func _least_geared_unit(gs: Node) -> String:
	var gear_by_unit: Dictionary = gs.get("gear_by_unit")
	var best_unit: String = ""
	var best_count: int = 1000000000
	for unit_id in gs.get("selected_units"):
		var count: int = (gear_by_unit.get(str(unit_id), []) as Array).size()
		if count < best_count:
			best_count = count
			best_unit = str(unit_id)
	return best_unit


# ── Fork: always take the flagged route — supply grade +2 compounds across the
# run, and heroes reset to full HP each battle, so the modifier's cost is one
# battle deep while the reward is permanent. (Heuristic, documented.)
func choose_fork(_modifier_id: String, _gs: Node) -> bool:
	return true


# ── Intercept: score choices — rewards up, permanent costs down. ─────────────
func choose_intercept(_card_id: String, card: Dictionary, gs: Node) -> Dictionary:
	var choices: Array = card.get("choices", [])
	var best_index: int = 0
	var best_score: int = -1000000000
	for i in choices.size():
		var choice: Dictionary = choices[i]
		# Illegal picks are unselectable, same as the screen greys them out.
		match str(choice.get("pick", "")):
			"consumable":
				if (gs.get("consumables") as Array).is_empty():
					continue
			"gear":
				if _all_equipped_gear_l1(gs).is_empty():
					continue
		var score: int = 0
		if not (choice.get("draft", {}) as Dictionary).is_empty():
			score += 2
		for effect_variant in choice.get("effects", []):
			var effect: Dictionary = effect_variant
			match str(effect.get("type", "")):
				"consumable", "protocolNextBattle", "heroXp", "squadXp", "runProtocolPerBattle", "heroRollBonus":
					score += 1
				"heroMaxHp":
					score += 1 if int(effect.get("amount", 0)) > 0 else -1
				"incomeDebt", "destroyPickedGear", "randomHeroDamage", "nextBattleFlag", "followupModifier":
					score -= 1
		if score > best_score:
			best_score = score
			best_index = i
	var choice: Dictionary = choices[best_index] if not choices.is_empty() else {}
	var hero_id: String = _first_unit(gs)
	var gear_context: Dictionary = {}
	if str(choice.get("pick", "")) == "gear":
		var gear_entries: Array = _all_equipped_gear_l1(gs)
		if not gear_entries.is_empty():
			gear_context = gear_entries[0]
			hero_id = str(gear_context.get("hero_id", hero_id))
	return {"choice": best_index, "hero_id": hero_id, "gear": gear_context}


# In-card draft: archetype affinity first, then rarity.
func choose_intercept_draft(options: Array, _gs: Node) -> String:
	var best_id: String = ""
	var best_key: Array = [-1, -1]
	for option_variant in options:
		var item: ItemData = DataManager.get_item(str(option_variant)) as ItemData
		if item == null:
			continue
		var key: Array = [_affinity(item), int(RARITY_RANK.get(str(item.rarity).to_lower(), 2))]
		if key[0] > best_key[0] or (key[0] == best_key[0] and key[1] > best_key[1]):
			best_key = key
			best_id = str(option_variant)
	return best_id


func _all_equipped_gear_l1(gs: Node) -> Array:
	var entries: Array = []
	var gear_by_unit: Dictionary = gs.get("gear_by_unit")
	for hero_id in gear_by_unit.keys():
		for gear_id in gear_by_unit[hero_id]:
			entries.append({"hero_id": str(hero_id), "gear_id": str(gear_id)})
	return entries
