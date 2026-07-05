# L2 — exact round solver (Package D). Once dice are rolled a round is a
# deterministic, perfect-information puzzle: all enemy dice/targets/abilities
# are visible and resolution order is fixed, so the round can be exactly
# searched. L2 enumerates (hero action order × hero target assignment ×
# protocol spend plan), resolves each candidate on the REAL combat_manager via
# snapshot → resolve → score → restore, and applies the best line. Draft / fork
# / intercept heuristics are inherited from L1; L2 is about in-round play.
#
# The L1↔L2 clear-rate gap per config is itself balance data: a build that's
# fine at L1 but dominant at L2 is a solved-game generator (skill-band report).
#
# Determinism: the global RNG (combat_manager's summon/vent/charge randi) is
# reseeded to a per-decision value before every candidate AND the final real
# resolve, so all candidates score under one RNG and the run reproduces. Only
# L2 reseeds; L0/L1 are untouched. The seeded d20 PROVIDER is separate (its own
# RNG instance) and never touched here.
class_name PolicyL2Solver
extends "res://scripts/sim/policies/policy_l1_greedy.gd"

# Bound the search: if order×target×spend candidates exceed this, drop the
# order permutation search (identity order only) to stay fast.
const CANDIDATE_CAP := 1200
const RESEED_SALT := 0x2545F491

# One-round evaluation weights (solver-internal scoring, NOT game data).
const W_ENEMY_HP := 3.0
const W_KILL := 50.0
const W_HERO_HP := 2.0
const W_HERO_DEATH := 120.0
const W_RESULT := 10000.0
const W_PROTOCOL := 1.0

var _decision_index: int = 0


func describe() -> String:
	return "l2"


func decide_round(engine, bs, cm, _gs) -> Array:
	_decision_index += 1
	var reseed: int = (rng.seed ^ (_decision_index * RESEED_SALT)) & 0x7FFFFFFF

	var living_heroes: Array = []
	for hs in cm.get_hero_states():
		if not bool((hs as Dictionary).get("dead", false)) and bs.hero_rolls.has(str((hs as Dictionary)["id"])):
			living_heroes.append(str((hs as Dictionary)["id"]))
	var living_enemies: Array = []
	for es in cm.get_enemy_states():
		if not bool((es as Dictionary).get("dead", false)):
			living_enemies.append(str((es as Dictionary)["id"]))
	if living_heroes.is_empty() or living_enemies.is_empty():
		return []

	# Candidate axes.
	var orders: Array = _permutations(living_heroes)
	var target_combos: Array = _target_assignments(living_heroes, living_enemies)
	var spend_plans: Array = _spend_plans(engine, bs)
	if orders.size() * target_combos.size() * spend_plans.size() > CANDIDATE_CAP:
		orders = [living_heroes]  # drop order search when it blows the budget

	var snapshot: Dictionary = cm.snapshot_state()
	var best_score: float = -1e30
	var best: Dictionary = {"order": living_heroes, "targets": {}, "spend": []}
	for order in orders:
		for targets in target_combos:
			for plan in spend_plans:
				var score: float = _score_candidate(engine, bs, cm, snapshot, reseed, order, targets, plan)
				if score > best_score:
					best_score = score
					best = {"order": order, "targets": targets, "spend": plan}

	# Apply the winning line to the REAL state so resolve_step resolves it.
	cm.restore_state(snapshot)
	cm.set_hero_order(best["order"])
	_assign_targets(cm, best["targets"])
	var spends: Array = _apply_spend_plan(engine, bs, best["spend"])
	seed(reseed)  # the real resolve must match the scored candidate
	return spends


# Resolve one candidate on a restored clone and score the resulting state.
func _score_candidate(engine, bs, cm, snapshot: Dictionary, reseed: int,
					  order: Array, targets: Dictionary, plan: Array) -> float:
	cm.restore_state(snapshot)
	cm.set_hero_order(order)
	_assign_targets(cm, targets)
	var bs_try = bs.duplicate_for_search()
	_apply_spend_plan(engine, bs_try, plan)
	var eff_hero: Dictionary = engine.build_effective_rolls(bs_try.hero_rolls, cm.get_hero_states(), true, bs_try)
	var eff_enemy: Dictionary = engine.build_effective_rolls(bs_try.enemy_rolls, cm.get_enemy_states(), false, bs_try)
	var pre: Dictionary = _measure(cm)
	seed(reseed)
	var result: Dictionary = cm.resolve_round(eff_hero, eff_enemy, engine.dice_manager,
		bs_try.enemy_rolls.duplicate(), bs_try.hero_rolls.duplicate())
	var post: Dictionary = _measure(cm)
	var res: String = str(result.get("result", "ongoing"))
	var score: float = 0.0
	score += W_ENEMY_HP * float(pre["enemy_hp"] - post["enemy_hp"])
	score += W_KILL * float(post["enemy_dead"] - pre["enemy_dead"])
	score -= W_HERO_HP * float(pre["hero_hp"] - post["hero_hp"])
	score -= W_HERO_DEATH * float(post["hero_dead"] - pre["hero_dead"])
	score -= W_PROTOCOL * float(plan.size())  # prefer cheaper lines when tied
	if res == "victory":
		score += W_RESULT
	elif res == "defeat":
		score -= W_RESULT
	return score


func _measure(cm) -> Dictionary:
	var hero_hp: int = 0
	var hero_dead: int = 0
	for hs in cm.get_hero_states():
		var s: Dictionary = hs
		if bool(s.get("dead", false)):
			hero_dead += 1
		else:
			hero_hp += int(s.get("current_hp", 0))
	var enemy_hp: int = 0
	var enemy_dead: int = 0
	for es in cm.get_enemy_states():
		var s: Dictionary = es
		if bool(s.get("dead", false)):
			enemy_dead += 1
		else:
			enemy_hp += int(s.get("current_hp", 0))
	return {"hero_hp": hero_hp, "hero_dead": hero_dead, "enemy_hp": enemy_hp, "enemy_dead": enemy_dead}


func _assign_targets(cm, targets: Dictionary) -> void:
	for hs in cm.get_hero_states():
		var s: Dictionary = hs
		var hid: String = str(s["id"])
		if targets.has(hid):
			s["selected_target_id"] = str(targets[hid])


# Spend plans: no-spend, plus band-improving nudges, plus a Set-to-20 on the
# weakest die when affordable. Reroll is EXCLUDED — it draws the d20 provider
# and would change the roll mid-search (non-speculative). Each plan is a list
# of {kind, unit, value} steps applied to a BattleState.
func _spend_plans(engine, bs) -> Array:
	var plans: Array = [[]]  # always consider spending nothing
	# Nudge-all-affordable: nudge every hero whose +3 would help (cheap plan).
	var nudge_plan: Array = []
	var budget: int = bs.protocol_points
	for hid in bs.hero_rolls.keys():
		if budget >= 1 and int(bs.hero_rolls[hid]) < 18:
			nudge_plan.append({"kind": "nudge", "unit": str(hid)})
			budget -= 1
	if not nudge_plan.is_empty():
		plans.append(nudge_plan)
	# Set the single lowest die to 20 when flush.
	if bs.protocol_points >= engine.set_cost(bs):
		var low_id: String = ""
		var low_val: int = 21
		for hid in bs.hero_rolls.keys():
			if int(bs.hero_rolls[hid]) < low_val:
				low_val = int(bs.hero_rolls[hid])
				low_id = str(hid)
		if low_id != "":
			plans.append([{"kind": "set", "unit": low_id, "value": 20}])
	return plans


func _apply_spend_plan(engine, bs, plan: Array) -> Array:
	var spends: Array = []
	for step_variant in plan:
		var step: Dictionary = step_variant
		match str(step.get("kind", "")):
			"nudge":
				var n: Dictionary = engine.apply_nudge(bs, str(step["unit"]), false, false)
				if str(n.get("kind", "")) == "applied":
					spends.append({"kind": "nudge", "unit": str(step["unit"]), "cost": int(n.get("cost", 1)), "detail": "+3"})
			"set":
				var paid: int = engine.apply_set(bs, str(step["unit"]), int(step["value"]))
				spends.append({"kind": "set", "unit": str(step["unit"]), "cost": paid, "detail": "= %d" % int(step["value"])})
	return spends


# All target assignments (living heroes over living enemies). Focus-fire and
# spread are both in the set. Capped implicitly by _permutations budget check.
func _target_assignments(heroes: Array, enemies: Array) -> Array:
	var combos: Array = [{}]
	for hid in heroes:
		var next: Array = []
		for partial_variant in combos:
			var partial: Dictionary = partial_variant
			for eid in enemies:
				var extended: Dictionary = partial.duplicate()
				extended[str(hid)] = str(eid)
				next.append(extended)
		combos = next
	return combos


func _permutations(items: Array) -> Array:
	if items.size() <= 1:
		return [items.duplicate()]
	var out: Array = []
	for i in items.size():
		var rest: Array = items.duplicate()
		var head = rest[i]
		rest.remove_at(i)
		for perm in _permutations(rest):
			var p: Array = [head]
			p.append_array(perm)
			out.append(p)
	return out
