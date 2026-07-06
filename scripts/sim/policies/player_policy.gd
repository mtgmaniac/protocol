# PlayerPolicy — the decision seam between the sim runner and the game
# (Package B.2). The runner asks the policy for every choice a human makes by
# tapping: per-round hero targets + protocol spends, post-win drafts, fork
# routes, intercept cards, and evolution / directive picks.
#
# The BASE class IS the deterministic "stub" policy Package A.3 shipped: no
# spends, combat_manager's first-living-enemy target fallback, first viable
# draft option, standard fork route, effect-free intercept choice, first
# evolution/directive. L0/L1 override the hooks.
#
# Determinism: policies may only draw randomness from `rng`, which the runner
# seeds from the master seed (third stream). Never the global RNG.
#
# SIM-TODO(kev): consumable USE during battle is not modeled yet (the spend
# hook covers nudge/reroll/set) — the item-dispatch port is Package C scope.
class_name PlayerPolicy
extends RefCounted

var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(policy_seed: int = 0) -> void:
	rng.seed = policy_seed


func describe() -> String:
	return "stub"


# ── Round: hero targets + protocol spends (before resolve_step) ───────────────
# Mutates bs (via engine spend methods) and hero states (selected_target_id).
# Returns spend telemetry entries: {kind, unit, cost, detail}.
func decide_round(_engine: BattleEngine, _bs: BattleState, _cm: CombatManager, _gs: Node) -> Array:
	return []


# ── Consumable use in battle (sim-D). Returns a list of item actions to fire
# this round: {item_id, target_id, side}. side "hero"/"enemy"/"" (none). The
# runner resolves cost + effect through the engine and removes the item from
# GameState.consumables. Base policy uses nothing.
func decide_items(_bs: BattleState, _cm: CombatManager, _gs: Node) -> Array:
	return []


# ── Post-win draft. items: Array[ItemData]. -> {"id": "" to skip, "target_unit"}
func choose_draft(items: Array, gs: Node) -> Dictionary:
	for item_variant in items:
		var item: ItemData = item_variant as ItemData
		if item == null:
			continue
		if item.item_type == "consumable" and (gs.get("consumables") as Array).size() >= int(gs.get("MAX_CONSUMABLES")):
			continue
		var target_unit: String = ""
		if item.item_type == "gear":
			target_unit = str((gs.get("selected_units") as Array)[0])
		return {"id": item.id, "target_unit": target_unit}
	return {"id": "", "target_unit": ""}


# ── Fork beat: true = take the flagged route (modifier + supply grade). ───────
func choose_fork(_modifier_id: String, _gs: Node) -> bool:
	return false


# ── Intercept beat: pick a choice for the drawn card. ─────────────────────────
# -> {"choice": int, "hero_id": String, "gear": {hero_id, gear_id} or {}}.
# The runner stages picks/drafts around this exactly as the intercept screen
# does. The base policy takes the first choice with NO pick requirement and NO
# draft (the refuse/leave option when one exists), so it never needs
# follow-up stages.
func choose_intercept(_card_id: String, card: Dictionary, gs: Node) -> Dictionary:
	var choices: Array = card.get("choices", [])
	for i in choices.size():
		var choice: Dictionary = choices[i]
		if str(choice.get("pick", "")) == "" and (choice.get("draft", {}) as Dictionary).is_empty():
			return {"choice": i, "hero_id": _first_unit(gs), "gear": {}}
	return {"choice": 0, "hero_id": _first_unit(gs), "gear": {}}


# Draft stage inside an intercept card: pick one of the rolled item ids.
func choose_intercept_draft(options: Array, _gs: Node) -> String:
	return str(options[0]) if not options.is_empty() else ""


# ── Progression stops. ────────────────────────────────────────────────────────
func choose_evolution(paths: Array, _gs: Node) -> String:
	return str((paths[0] as Dictionary).get("name", "")) if not paths.is_empty() else ""


func choose_directive(choices: Array, _gs: Node) -> String:
	return str((choices[0] as Dictionary).get("name", "")) if not choices.is_empty() else ""


func _first_unit(gs: Node) -> String:
	var units: Array = gs.get("selected_units")
	return str(units[0]) if not units.is_empty() else ""
