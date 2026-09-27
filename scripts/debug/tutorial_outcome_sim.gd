extends SceneTree

# Real engine, uniform seeded free rolls; no HP changes or forced outcomes.
# Optional rewards remain unused, so the safety claim does not rely on an item.
const Plan := preload("res://scripts/battle/tutorial_roll_plan.gd")
const RUNS := 1000
const ROUND_CAP := 200
const SEED_BASE := 27092026
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var report: Dictionary = {"runs_per_case": RUNS, "seed_base": SEED_BASE,
		"round_cap": ROUND_CAP, "rounds_include_guided_opening": true,
		"items": "held, unused", "cases": [], "validation_errors": []}
	for policy_name in ["basic", "l1"]:
		for battle in [1, 2]:
			var victories: Array[int] = []
			var losses: Array[int] = []
			var stuck: Array[int] = []
			for index in RUNS:
				var seed_value: int = SEED_BASE + battle * 100000 + index
				var result: Dictionary = play(battle, seed_value, policy_name)
				match str(result.outcome):
					"victory": victories.append(int(result.rounds))
					"defeat": losses.append(seed_value)
					_: stuck.append(seed_value)
			victories.sort()
			var median: float = 0.0
			if not victories.is_empty():
				median = (float(victories[(victories.size() - 1) / 2]) + float(victories[victories.size() / 2])) / 2.0
			var row: Dictionary = {"battle": battle, "policy": policy_name,
				"wins": victories.size(), "losses": losses.size(), "loss_pct": losses.size() * 100.0 / RUNS,
				"soft_locks": stuck.size(), "median_victory_rounds": median,
				"max_victory_rounds": victories.back() if not victories.is_empty() else 0,
				"loss_seeds": losses, "soft_lock_seeds": stuck}
			report.cases.append(row)
			print("[TUTORIAL_OUTCOMES] ", JSON.stringify(row))
	report.validation_errors = failures
	var out := FileAccess.open("res://debug_artifacts/tutorial_outcomes.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(report, "\t") + "\n")
	out.close()
	quit(0 if failures.is_empty() else 1)

func play(battle: int, seed_value: int, policy_name: String) -> Dictionary:
	var dm: Node = root.get_node("DataManager")
	var cm = load("res://scripts/battle/combat_manager.gd").new()
	var squad: Array = [dm.get_unit("combat"), dm.get_unit("engineer" if battle == 1 else "pulse"), dm.get_unit("medic")]
	var enemies: Array = []
	for _index in battle:
		enemies.append(dm.get_enemy_by_display_name("Scrap Drone").duplicate(true))
	cm.setup_battle(squad, enemies)
	var provider := SeededRollProvider.new(seed_value)
	var dice = load("res://scripts/battle/dice_manager.gd").new()
	var engine = load("res://scripts/battle/battle_engine.gd").new(cm, provider, dice)
	var state = load("res://scripts/battle/battle_state.gd").new()
	var policy = load("res://scripts/sim/policies/policy_l1_greedy.gd").new(seed_value)
	for round_number in range(1, ROUND_CAP + 1):
		var scripted: Dictionary = Plan.heroes(battle, round_number)
		for hero in cm.get_hero_states():
			hero.selected_target_id = ""
			if not bool(hero.dead):
				state.hero_rolls[str(hero.id)] = int(scripted[str(hero.unit.id)]) if not scripted.is_empty() else provider.roll_d20()
		for enemy in cm.get_enemy_states():
			enemy.selected_target_id = ""
			if not bool(enemy.dead):
				state.enemy_rolls[str(enemy.id)] = 6 if not scripted.is_empty() else provider.roll_d20()
		engine.apply_frozen_roll_overrides(cm.get_hero_states(), state.hero_rolls)
		engine.apply_frozen_roll_overrides(cm.get_enemy_states(), state.enemy_rolls)
		engine.record_roll_values_for_states(cm.get_hero_states(), state.hero_rolls)
		engine.record_roll_values_for_states(cm.get_enemy_states(), state.enemy_rolls)
		cm.assign_enemy_intents(engine.build_effective_rolls(state.enemy_rolls, cm.get_enemy_states(), false, state), dice)
		if battle == 1 and round_number == 2:
			engine.apply_nudge(state, str(cm.get_hero_states()[0].id), false, false)
		elif scripted.is_empty() and policy_name == "l1":
			policy.decide_round(engine, state, cm, root.get_node("GameState"))
		# Plain visible choices: squad order, focus lowest enemy, heal/shield the
		# most injured living hero. Guided support goes to Strike as instructed.
		var order: Array = []
		for hero in cm.get_hero_states():
			if bool(hero.dead):
				continue
			order.append(str(hero.id))
			var ability: Dictionary = dice.get_ability_for_roll(hero.unit, engine.effective_hero_roll(hero, str(hero.id), state)).get("raw", {})
			var friendly: bool = bool(ability.get("healTgt", false)) or bool(ability.get("shTgt", false))
			var target: Dictionary = lowest(cm.get_hero_states() if friendly else cm.get_enemy_states())
			if friendly and not scripted.is_empty():
				target = cm.get_hero_states()[0]
			if target.is_empty():
				return {"outcome": "soft_lock_missing_target", "rounds": round_number}
			hero.selected_target_id = str(target.id)
		cm.set_hero_order(order)
		var step: Dictionary = engine.resolve_step(state)
		engine.gain_protocol(state, int(step.protocol_grant), engine.max_protocol(0))
		state.protocol_points = maxi(0, state.protocol_points - int(step.protocol_drain))
		var outcome: String = str(step.result.get("result", "ongoing"))
		if not scripted.is_empty():
			var expected: int = (19 if round_number == 1 else 9) if battle == 1 else 26
			if int(cm.get_enemy_states()[0].current_hp) != expected or outcome != "ongoing":
				if failures.size() < 10:
					failures.append("Guided opening mismatch battle %d round %d seed %d" % [battle, round_number, seed_value])
		if outcome in ["victory", "defeat"]:
			return {"outcome": outcome, "rounds": round_number}
		engine.gain_protocol(state, int(engine.end_of_round_income(round_number, 0).gain), engine.max_protocol(0))
	return {"outcome": "soft_lock_round_cap", "rounds": ROUND_CAP}

func lowest(states: Array) -> Dictionary:
	var pick: Dictionary = {}
	for state in states:
		if not bool(state.dead) and (pick.is_empty() or int(state.current_hp) < int(pick.current_hp)):
			pick = state
	return pick


