# sim_runner — headless balance-sim entry point (Package A.3; telemetry B.1).
#
# Runs a full run with ZERO scene-tree UI by driving GameState (run flow) and
# BattleEngine + CombatManager (battles) directly — the same rules engine the
# live game uses, never a reimplementation. Runs as a SCENE so the autoloads
# (GameState / DataManager / SceneManager) are registered:
#
#   godot --headless --path . res://scenes/sim/sim_main.tscn -- \
#     --seed 12345 --squad pulse,combat,shield --op facility --policy L1 \
#     --out results/run_12345.jsonl [--battles-only 3]
#
# Determinism: two seeded streams — GameState._reward_rng (drafts/beats/comps,
# seeded via start_run) and the SeededRollProvider (d20s). Same seed + same
# config => byte-identical JSONL. Nothing here calls randomize()/Time.
#
# Telemetry (B.1): one JSONL line per event; schema + determinism contract in
# scripts/sim/telemetry_schema.md; replay with scripts/sim/replay.py (B.4).
#
# A.3 scope: stub policy (no protocol spends; hero abilities auto-target the
# first living enemy via combat_manager's fallback; drafts/evolutions/directives
# take option 0). Beats are consumed without applying their effects.
# SIM-TODO(kev): real policy layer lands in Package B.2/B.3; beat effects
# (fork modifiers / intercept cards) and the fuller battle-start setup
# (route modifiers, intercept battle effects, battle-start consumables) land
# with the policy work.
extends Node

# Preloaded (not class_name-resolved) so a fresh checkout's headless run works
# before the editor has rebuilt the global class cache.
const SimTelemetryScript = preload("res://scripts/sim/telemetry.gd")
const PlayerPolicyScript = preload("res://scripts/sim/policies/player_policy.gd")
const PolicyL0Script = preload("res://scripts/sim/policies/policy_l0_random.gd")
const PolicyL1Script = preload("res://scripts/sim/policies/policy_l1_greedy.gd")

const SIM_VERSION := "0.3.0"
const ROUND_SAFETY_CAP := 500
# Third seeded stream (after reward-rng and the d20 provider): policy choices.
const POLICY_SEED_OFFSET := 0x51F15EED

var _tel = SimTelemetryScript.new()
var _seed: int = 0


func _make_policy(policy_name: String, policy_seed: int):
	match policy_name.to_lower():
		"l0", "random":
			return PolicyL0Script.new(policy_seed)
		"l1", "greedy":
			return PolicyL1Script.new(policy_seed)
		_:
			return PlayerPolicyScript.new(policy_seed)


func _ready() -> void:
	var args: Dictionary = _parse_args()
	var code: int = _run(args)
	_tel.close_file()
	get_tree().quit(code)


# ── Arg parsing (OS.get_cmdline_user_args → after the `--`) ───────────────────
func _parse_args() -> Dictionary:
	var out: Dictionary = {}
	var raw: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < raw.size():
		var token: String = str(raw[i])
		if token.begins_with("--"):
			var key: String = token.substr(2)
			if key.contains("="):
				var parts: PackedStringArray = key.split("=", true, 1)
				out[str(parts[0])] = str(parts[1])
			elif i + 1 < raw.size() and not str(raw[i + 1]).begins_with("--"):
				out[key] = str(raw[i + 1])
				i += 1
			else:
				out[key] = "true"
		i += 1
	return out


func _run(args: Dictionary) -> int:
	var gs: Node = get_node("/root/GameState")
	var dm: Node = get_node("/root/DataManager")

	if args.has("bench"):
		return _bench(gs, dm, args)

	_seed = int(args.get("seed", "0"))
	var policy_name: String = str(args.get("policy", "stub"))
	var op: String = str(args.get("op", ""))
	if op == "":
		op = str(dm.call("get_operation_order")[0])
	var squad: Array = _squad_from_args(args)
	var out_path: String = str(args.get("out", "results/run_%d.jsonl" % _seed))
	_tel.run_id = "run_%d" % _seed
	_tel.run_seed = _seed

	if not _tel.open_file(out_path):
		push_error("[SIM] could not open output: %s" % out_path)
		return 1

	# Seed the run: GameState._reward_rng deterministic, then start.
	gs.call("start_run", squad, op, _seed)
	gs.call("advance_to_next_battle")  # current_battle 0 -> 1

	# Seeded streams two and three (offset from the reward-rng seed so all
	# streams are independent but reproducible): d20s and policy choices.
	var provider := SeededRollProvider.new(_seed ^ 0x9E3779B9)
	var policy = _make_policy(policy_name, _seed ^ POLICY_SEED_OFFSET)

	_tel.emit({
		"type": "run_header", "policy": policy.describe(), "squad": squad, "op": op,
		"sim_version": SIM_VERSION, "schema_version": SimTelemetryScript.SCHEMA_VERSION,
		"roll_source": provider.describe(),
	})

	var battle_limit: int = int(args.get("battles-only", str(int(gs.get("total_battles")))))
	var summary: Dictionary = _play_run(gs, dm, provider, policy, battle_limit)

	_tel.emit({
		"type": "run_end", "result": summary["result"],
		"battles_cleared": summary["battles_cleared"],
	})
	print("[SIM] %s: %s, battles_cleared=%d → %s" % [_tel.run_id, summary["result"], summary["battles_cleared"], out_path])
	return 0


# Plays one full run from the CURRENT GameState (already started + advanced to
# battle 1). Returns { result, battles_cleared, battles_played }. Shared by the
# normal run and the benchmark; telemetry lines emit only when an output file
# is open (bench opens none, so it does no I/O or JSON work).
func _play_run(gs: Node, dm: Node, provider: RollProvider, policy, battle_limit: int) -> Dictionary:
	var total_battles: int = int(gs.get("total_battles"))
	var battles_cleared: int = 0
	var battles_played: int = 0
	var final_result: String = "incomplete"
	while int(gs.get("current_battle")) <= total_battles:
		var battle_index: int = int(gs.get("current_battle"))
		var outcome: Dictionary = _play_battle(gs, dm, provider, policy, battle_index)
		battles_played += 1
		if outcome["result"] == "victory":
			battles_cleared += 1
		if outcome["result"] == "defeat":
			gs.call("finish_run", "defeat")
			final_result = "defeat"
			break
		if bool(gs.call("is_final_battle")):
			gs.call("finish_run", "victory")
			final_result = "victory"
			break
		_claim_reward(gs, policy, battle_index)
		gs.call("award_battle_xp")
		_resolve_progression_stop(gs, policy)
		if battle_index >= battle_limit:
			final_result = "battles_limit"
			break
		_advance(gs, dm, policy)
	return {"result": final_result, "battles_cleared": battles_cleared, "battles_played": battles_played}


# --bench N: play back-to-back full runs until N battles resolve, report
# battles/minute (single worker). No JSONL is written, so this measures pure
# resolution throughput. Uses Time only for the wall clock — never for output.
func _bench(gs: Node, dm: Node, args: Dictionary) -> int:
	var target: int = int(args.get("bench", "200"))
	var op: String = str(args.get("op", ""))
	if op == "":
		op = str(dm.call("get_operation_order")[0])
	var squad: Array = _squad_from_args(args)
	var base_seed: int = int(args.get("seed", "1"))
	var battles: int = 0
	var run_index: int = 0
	var t0: int = Time.get_ticks_usec()
	var bench_policy_name: String = str(args.get("policy", "stub"))
	while battles < target:
		var run_seed: int = base_seed + run_index
		gs.call("start_run", squad, op, run_seed)
		gs.call("advance_to_next_battle")
		var provider := SeededRollProvider.new(run_seed ^ 0x9E3779B9)
		var bench_policy = _make_policy(bench_policy_name, run_seed ^ POLICY_SEED_OFFSET)
		var summary: Dictionary = _play_run(gs, dm, provider, bench_policy, int(gs.get("total_battles")))
		battles += int(summary["battles_played"])
		run_index += 1
	var elapsed_s: float = float(Time.get_ticks_usec() - t0) / 1_000_000.0
	var per_min: float = (float(battles) / elapsed_s) * 60.0 if elapsed_s > 0.0 else 0.0
	print("[SIM] bench: %d battles across %d runs in %.3fs = %.0f battles/min" % [battles, run_index, elapsed_s, per_min])
	return 0


func _squad_from_args(args: Dictionary) -> Array:
	var squad: Array = []
	for s in str(args.get("squad", "pulse,combat,shield")).split(","):
		if str(s).strip_edges() != "":
			squad.append(str(s).strip_edges())
	return squad


# ── One battle, fully headless via CombatManager + BattleEngine ───────────────
func _play_battle(gs: Node, dm: Node, provider: RollProvider, policy, battle_index: int) -> Dictionary:
	var hero_units: Array = _build_hero_units(gs)
	# Built BEFORE the effects dict is consumed (minus_one_enemy reads it).
	var enemy_units: Array = _build_enemy_units(gs, dm)

	var cm := CombatManager.new()
	cm.setup_battle(hero_units, enemy_units)
	gs.call("begin_battle_xp_tracking")
	cm.setup_relics(gs.get("relics"))
	cm.setup_gear(gs.get("gear_by_unit"))
	if cm.has_relic("battleStartConsumable"):
		gs.call("grant_battle_start_consumables", int(cm.get_relic_value("battleStartConsumable", "amount", 1)))
	cm.apply_battle_start_relic_effects(maxi(battle_index - 1, 0))
	cm.apply_battle_start_gear_effects()

	var engine := BattleEngine.new(cm, provider, DiceManager.new())
	var bs := BattleState.new()
	bs.protocol_points = int(gs.call("take_carried_protocol"))
	var cap_override: int = int(gs.get("run_protocol_cap_override"))

	# Route Fork modifier (one-shot, consumed into this battle) — same order as
	# battle_scene._ready.
	var route_modifier: String = str(gs.get("next_battle_modifier"))
	gs.set("next_battle_modifier", "")
	if route_modifier != "":
		var comp_warded: Array = (gs.call("get_current_battle_comp") as Dictionary).get("warded", [])
		cm.setup_battle_modifier(route_modifier, comp_warded)

	# Intercept/route battle-start one-shots — the same engine rule the live
	# screen delegates to (sim-B.2).
	var battle_effects: Dictionary = (gs.get("next_battle_effects") as Dictionary).duplicate(true)
	(gs.get("next_battle_effects") as Dictionary).clear()
	gs.call("promote_followup_effects")
	var applied: Dictionary = engine.apply_battle_start_external_effects(
		battle_effects, gs.get("hero_run_mods"), int(gs.get("run_protocol_per_battle"))
	)
	var income_debt: int = int(applied["income_debt"])
	if int(applied["start_protocol"]) > 0:
		engine.gain_protocol(bs, int(applied["start_protocol"]), engine.max_protocol(cap_override))
	# Protocol Tap gear (engine rule; mini like the live screen — no overflow).
	bs.protocol_points = mini(bs.protocol_points + engine.gear_start_protocol(), engine.max_protocol(cap_override))

	var comp_names: Array = []
	for es in cm.get_enemy_states():
		comp_names.append(str((es["unit"] as Object).get("display_name")))
	_tel.emit({
		"type": "battle_start", "index": battle_index, "comp": comp_names,
		"modifier": route_modifier, "battle_effects": battle_effects,
		"squad_hp": _hp_snapshot(cm.get_hero_states()), "protocol": bs.protocol_points,
	})

	var rounds: int = 0
	var result: String = "ongoing"
	while rounds < ROUND_SAFETY_CAP:
		rounds += 1
		# Roll (SeededRollProvider) → frozen overrides → record.
		bs.hero_rolls = engine.roll_states(cm.get_hero_states())
		bs.enemy_rolls = engine.roll_states(cm.get_enemy_states())
		engine.apply_frozen_roll_overrides(cm.get_hero_states(), bs.hero_rolls)
		engine.apply_frozen_roll_overrides(cm.get_enemy_states(), bs.enemy_rolls)
		engine.record_roll_values_for_states(cm.get_hero_states(), bs.hero_rolls)
		engine.record_roll_values_for_states(cm.get_enemy_states(), bs.enemy_rolls)
		# Policy: hero targets + protocol spends before the round resolves.
		var spends: Array = policy.decide_round(engine, bs, cm, gs)
		var raw_hero_rolls: Dictionary = bs.hero_rolls.duplicate()
		var raw_enemy_rolls: Dictionary = bs.enemy_rolls.duplicate()
		var step: Dictionary = engine.resolve_step(bs)
		for uid in (step["eff_hero_rolls"] as Dictionary).keys():
			gs.call("record_hero_effective_roll", str(uid), int((step["eff_hero_rolls"] as Dictionary)[uid]))
		if int(step["protocol_grant"]) > 0:
			engine.gain_protocol(bs, int(step["protocol_grant"]), engine.max_protocol(cap_override))
		if int(step["protocol_drain"]) > 0:
			bs.protocol_points = maxi(0, bs.protocol_points - int(step["protocol_drain"]))

		result = str((step["result"] as Dictionary).get("result", "ongoing"))
		if result != "victory" and result != "defeat":
			_process_summons(cm, dm, (step["result"] as Dictionary).get("events", []))
			# End-of-turn income — engine rule (blackout / income debt honored).
			var income: Dictionary = engine.end_of_round_income(rounds, income_debt)
			income_debt = int(income["debt_left"])
			if int(income["gain"]) > 0:
				engine.gain_protocol(bs, 1, engine.max_protocol(cap_override))

		_tel.emit({
			"type": "round", "index": battle_index, "round": rounds,
			"hero_rolls": raw_hero_rolls, "eff_hero_rolls": step["eff_hero_rolls"],
			"enemy_rolls": raw_enemy_rolls, "eff_enemy_rolls": step["eff_enemy_rolls"],
			"spends": spends,
			"events": (step["result"] as Dictionary).get("events", []),
			"squad_hp": _hp_snapshot(cm.get_hero_states()),
			"enemy_hp": _hp_snapshot(cm.get_enemy_states()),
			"protocol": bs.protocol_points,
		})
		if result == "victory" or result == "defeat":
			break

	gs.call("capture_battle_end_survival", cm.get_hero_states())
	_tel.emit({
		"type": "battle_end", "index": battle_index, "result": result,
		"rounds": rounds, "squad_hp": _hp_snapshot(cm.get_hero_states()),
		"protocol_left": bs.protocol_points, "deaths": _dead_hero_ids(cm.get_hero_states()),
	})
	return {"result": result, "rounds": rounds}


func _hp_snapshot(states: Array) -> Array:
	var snapshot: Array = []
	for state_variant in states:
		var state: Dictionary = state_variant
		snapshot.append(0 if bool(state.get("dead", false)) else int(state.get("current_hp", 0)))
	return snapshot


func _dead_hero_ids(hero_states: Array) -> Array:
	var dead: Array = []
	for state_variant in hero_states:
		var state: Dictionary = state_variant
		if bool(state.get("dead", false)):
			var unit: Variant = state.get("unit")
			dead.append(str((unit as UnitData).id) if unit is UnitData else str(state.get("id", "")))
	return dead


# ── Unit construction (mirrors battle_scene._build_runtime_units, UI-free) ────
func _build_hero_units(gs: Node) -> Array:
	gs.call("enforce_squad_limit")
	var units: Array = []
	for uid in gs.get("selected_units"):
		if units.size() >= GameState.SQUAD_UNIT_LIMIT:
			break
		var unit: UnitData = gs.call("get_run_unit_data", str(uid))
		if unit != null:
			units.append(unit)
	return units


func _build_enemy_units(gs: Node, dm: Node) -> Array:
	var operation: OperationData = dm.call("get_operation", str(gs.get("selected_operation_id"))) as OperationData
	if operation == null:
		return []
	var battle_index: int = maxi(int(gs.get("current_battle")) - 1, 0)
	if battle_index >= operation.battles.size():
		return []
	var battle_entry: Dictionary = operation.battles[battle_index]
	var comp: Dictionary = gs.call("get_current_battle_comp")
	var enemy_names: Array = comp.get("names", [])
	var cloaked_names: Array = comp.get("cloaked", [])
	if enemy_names.is_empty():
		enemy_names = battle_entry.get("enemy_names", [])
		cloaked_names = battle_entry.get("cloaked_names", [])
	if bool((gs.get("next_battle_effects") as Dictionary).get("minus_one_enemy", false)) and enemy_names.size() > 1:
		enemy_names = enemy_names.duplicate()
		enemy_names.remove_at(enemy_names.size() - 1)
	var units: Array = []
	for enemy_name in enemy_names:
		if units.size() >= GameState.SQUAD_UNIT_LIMIT:
			break
		var enemy: EnemyData = dm.call("get_enemy_by_display_name", str(enemy_name)) as EnemyData
		if enemy != null:
			var copy: EnemyData = enemy.duplicate(true) as EnemyData
			if cloaked_names.has(str(enemy_name)):
				copy.starts_cloaked = true
			units.append(copy)
	return units


# Summon events (brood / assembly line): inject the named dumb enemy. Mirrors
# battle_scene._process_summon_events minus the card UI.
func _process_summons(cm: CombatManager, dm: Node, events: Array) -> void:
	for event in events:
		if str((event as Dictionary).get("type", "")) != "summon":
			continue
		var summon_name: String = str((event as Dictionary).get("summon_name", ""))
		if summon_name == "":
			continue
		var base_enemy: EnemyData = dm.call("get_enemy_by_display_name", summon_name) as EnemyData
		if base_enemy == null or base_enemy.ai_type != "dumb":
			continue
		cm.inject_enemy(base_enemy.duplicate(true) as EnemyData)


# ── Between-battle (policy-driven, sim-B.2) ───────────────────────────────────
func _claim_reward(gs: Node, policy, battle_index: int) -> void:
	gs.call("prepare_battle_rewards")
	var items: Array = gs.call("get_pending_reward_items")
	var options: Array = []
	for item_variant in items:
		var opt: ItemData = item_variant as ItemData
		if opt != null:
			options.append({"id": opt.id, "type": opt.item_type, "rarity": opt.rarity})
	var pick: Dictionary = policy.choose_draft(items, gs)
	var picked: String = str(pick.get("id", ""))
	var target_unit: String = str(pick.get("target_unit", ""))
	if picked != "":
		gs.call("claim_reward", picked, target_unit)
	_tel.emit({
		"type": "draft", "index": battle_index, "options": options,
		"picked": picked, "target_unit": target_unit,
	})


func _resolve_progression_stop(gs: Node, policy) -> void:
	if bool(gs.call("is_pending_directive_stage")):
		var choices: Array = gs.call("get_pending_directive_choices")
		if not choices.is_empty():
			var directive_names: Array = []
			for choice_variant in choices:
				directive_names.append(str((choice_variant as Dictionary).get("name", "")))
			var picked_directive: String = str(policy.choose_directive(choices, gs))
			gs.call("apply_pending_directive", picked_directive)
			_tel.emit({
				"type": "progression", "unit": str(gs.get("pending_evolution_unit_id")),
				"kind": "directive", "options": directive_names, "picked": picked_directive,
			})
	elif bool(gs.call("has_pending_evolution")):
		var unit_id: String = str(gs.get("pending_evolution_unit_id"))
		var paths: Array = gs.call("get_pending_evolution_paths")
		if not paths.is_empty():
			var path_names: Array = []
			for path_variant in paths:
				path_names.append(str((path_variant as Dictionary).get("name", "")))
			var picked_path: String = str(policy.choose_evolution(paths, gs))
			gs.call("apply_pending_evolution", picked_path)
			_tel.emit({
				"type": "progression", "unit": unit_id,
				"kind": "evolution", "options": path_names, "picked": picked_path,
			})


# Beats now APPLY their effects through the same GameState calls the fork /
# intercept screens make (sim-B.2 — SIM-TODO cleared).
func _advance(gs: Node, dm: Node, policy) -> void:
	var after_battle: int = int(gs.get("current_battle"))
	var beat: Dictionary = gs.call("get_beat_after_battle", after_battle)
	if not beat.is_empty() and not (gs.get("consumed_beats") as Array).has(after_battle):
		(gs.get("consumed_beats") as Array).append(after_battle)
		match str(beat.get("type", "")):
			"fork":
				_resolve_fork_beat(gs, policy, beat, after_battle)
			"intercept":
				_resolve_intercept_beat(gs, dm, policy, beat, after_battle)
			_:
				_tel.emit({
					"type": "beat", "after_battle": after_battle,
					"beat_type": str(beat.get("type", "")), "tier": str(beat.get("tier", "")),
				})
	gs.call("advance_to_next_battle")


func _resolve_fork_beat(gs: Node, policy, beat: Dictionary, after_battle: int) -> void:
	var modifier_id: String = str(gs.call("roll_route_modifier"))
	var took_flagged: bool = modifier_id != "" and bool(policy.choose_fork(modifier_id, gs))
	if took_flagged:
		gs.call("accept_flagged_route", modifier_id)
	_tel.emit({
		"type": "beat", "after_battle": after_battle, "beat_type": "fork",
		"tier": str(beat.get("tier", "")), "modifier": modifier_id,
		"took_flagged": took_flagged,
	})


# Mirrors intercept_screen's stages: draw → choice → picks → in-card draft →
# apply_intercept_effects. Same GameState API, no screen.
func _resolve_intercept_beat(gs: Node, dm: Node, policy, beat: Dictionary, after_battle: int) -> void:
	var tier: String = str(beat.get("tier", "minor"))
	var card_id: String = str(gs.call("draw_intercept_card", tier))
	if card_id == "":
		_tel.emit({
			"type": "beat", "after_battle": after_battle, "beat_type": "intercept",
			"tier": tier, "card": "", "choice": -1, "hero": "", "drafted": "",
		})
		return
	var card: Dictionary = (gs.get("INTERCEPT_CARDS") as Dictionary).get(card_id, {})
	var decision: Dictionary = policy.choose_intercept(card_id, card, gs)
	var choice_index: int = clampi(int(decision.get("choice", 0)), 0, maxi((card.get("choices", []) as Array).size() - 1, 0))
	var choice: Dictionary = (card.get("choices", []) as Array)[choice_index] if not (card.get("choices", []) as Array).is_empty() else {}
	var hero_id: String = str(decision.get("hero_id", ""))
	var gear_context: Dictionary = decision.get("gear", {})

	# In-card draft stage (Black Market Node / Deep Cache): roll, policy picks,
	# commit exactly as intercept_screen._on_draft_picked does.
	var drafted_id: String = ""
	var draft: Dictionary = choice.get("draft", {})
	if not draft.is_empty():
		var draft_options: Array = gs.call(
			"roll_intercept_draft", str(draft.get("kind", "consumable")),
			str(draft.get("min_rarity", "common")), int(draft.get("count", 3))
		)
		drafted_id = str(policy.choose_intercept_draft(draft_options, gs))
		if drafted_id != "":
			var drafted_item: ItemData = dm.call("get_item", drafted_id) as ItemData
			if drafted_item != null and drafted_item.item_type == "gear":
				var target_id: String = hero_id
				if target_id == "" and not (gs.get("selected_units") as Array).is_empty():
					target_id = str((gs.get("selected_units") as Array)[0])
				var unit_gear: Array = (gs.get("gear_by_unit") as Dictionary).get(target_id, []).duplicate()
				unit_gear.append(drafted_id)
				(gs.get("gear_by_unit") as Dictionary)[target_id] = unit_gear
				(gs.get("equipped_gear") as Dictionary)[target_id] = unit_gear.duplicate()
			elif drafted_item != null and (gs.get("consumables") as Array).size() < int(gs.get("MAX_CONSUMABLES")):
				(gs.get("consumables") as Array).append(drafted_id)

	gs.call("apply_intercept_effects", choice.get("effects", []), hero_id, gear_context)
	_tel.emit({
		"type": "beat", "after_battle": after_battle, "beat_type": "intercept",
		"tier": tier, "card": card_id, "choice": choice_index,
		"hero": hero_id, "drafted": drafted_id,
	})
