# sim_runner — headless balance-sim entry point (Package A.3).
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
# A.3 scope: stub policy (no protocol spends; hero abilities auto-target the
# first living enemy via combat_manager's fallback; drafts/evolutions/directives
# take option 0). Beats are consumed without applying their effects.
# SIM-TODO(kev): real policy layer + telemetry schema land in Package B; beat
# effects (fork modifiers / intercept cards) and the fuller battle-start setup
# (route modifiers, intercept battle effects, battle-start consumables) land
# with the policy work.
extends Node

const SIM_VERSION := "0.1.0"
const ROUND_SAFETY_CAP := 500

var _out: FileAccess = null
var _t: int = 0
var _run_id: String = ""
var _seed: int = 0


func _ready() -> void:
	var args: Dictionary = _parse_args()
	var code: int = _run(args)
	if _out != null:
		_out.flush()
		_out.close()
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
	# A.3 always runs the stub policy regardless of this value; L0/L1/L2 land in
	# Packages B/D. The string is recorded in the header for later runs.
	var policy: String = str(args.get("policy", "stub"))
	var op: String = str(args.get("op", ""))
	if op == "":
		op = str(dm.call("get_operation_order")[0])
	var squad_arg: String = str(args.get("squad", "pulse,combat,shield"))
	var squad: Array = []
	for s in squad_arg.split(","):
		if str(s).strip_edges() != "":
			squad.append(str(s).strip_edges())
	var out_path: String = str(args.get("out", "results/run_%d.jsonl" % _seed))
	_run_id = "run_%d" % _seed

	if not _open_out(out_path):
		push_error("[SIM] could not open output: %s" % out_path)
		return 1

	# Seed the run: GameState._reward_rng deterministic, then start.
	gs.call("start_run", squad, op, _seed)
	gs.call("advance_to_next_battle")  # current_battle 0 -> 1

	# One seeded d20 stream for the whole run (offset from the reward-rng seed so
	# the two streams are independent but reproducible).
	var provider := SeededRollProvider.new(_seed ^ 0x9E3779B9)

	_emit({
		"type": "run_header", "policy": policy, "squad": squad, "op": op,
		"sim_version": SIM_VERSION, "roll_source": provider.describe(),
	})

	var battle_limit: int = int(args.get("battles-only", str(int(gs.get("total_battles")))))
	var summary: Dictionary = _play_run(gs, dm, provider, battle_limit)

	_emit({
		"type": "run_end", "result": summary["result"],
		"battles_cleared": summary["battles_cleared"],
	})
	print("[SIM] %s: %s, battles_cleared=%d → %s" % [_run_id, summary["result"], summary["battles_cleared"], out_path])
	return 0


# Plays one full run from the CURRENT GameState (already started + advanced to
# battle 1). Returns { result, battles_cleared, battles_played }. Shared by the
# normal run and the benchmark; battle_end/battle_start lines emit only when an
# output file is open (bench opens none, so it does no I/O or JSON work).
func _play_run(gs: Node, dm: Node, provider: RollProvider, battle_limit: int) -> Dictionary:
	var total_battles: int = int(gs.get("total_battles"))
	var battles_cleared: int = 0
	var battles_played: int = 0
	var final_result: String = "incomplete"
	while int(gs.get("current_battle")) <= total_battles:
		var battle_index: int = int(gs.get("current_battle"))
		var outcome: Dictionary = _play_battle(gs, dm, provider, battle_index)
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
		_claim_first_reward(gs)
		gs.call("award_battle_xp")
		_resolve_progression_stop(gs)
		if battle_index >= battle_limit:
			final_result = "battles_limit"
			break
		_advance(gs)
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
	while battles < target:
		var run_seed: int = base_seed + run_index
		gs.call("start_run", squad, op, run_seed)
		gs.call("advance_to_next_battle")
		var provider := SeededRollProvider.new(run_seed ^ 0x9E3779B9)
		var summary: Dictionary = _play_run(gs, dm, provider, int(gs.get("total_battles")))
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
func _play_battle(gs: Node, dm: Node, provider: RollProvider, battle_index: int) -> Dictionary:
	var hero_units: Array = _build_hero_units(gs)
	var enemy_units: Array = _build_enemy_units(gs, dm)

	var cm := CombatManager.new()
	cm.setup_battle(hero_units, enemy_units)
	gs.call("begin_battle_xp_tracking")
	cm.setup_relics(gs.get("relics"))
	cm.setup_gear(gs.get("gear_by_unit"))
	cm.apply_battle_start_relic_effects(maxi(battle_index - 1, 0))
	cm.apply_battle_start_gear_effects()

	var engine := BattleEngine.new(cm, provider, DiceManager.new())
	var bs := BattleState.new()
	bs.protocol_points = int(gs.call("take_carried_protocol"))

	var comp_names: Array = []
	for es in cm.get_enemy_states():
		comp_names.append(str((es["unit"] as Object).get("display_name")))
	_emit({"type": "battle_start", "index": battle_index, "comp": comp_names})

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
		# Stub policy: no protocol spends; hero abilities auto-target the first
		# living enemy via combat_manager's selected_target_id fallback.
		var step: Dictionary = engine.resolve_step(bs)
		for uid in (step["eff_hero_rolls"] as Dictionary).keys():
			gs.call("record_hero_effective_roll", str(uid), int((step["eff_hero_rolls"] as Dictionary)[uid]))
		if int(step["protocol_grant"]) > 0:
			engine.gain_protocol(bs, int(step["protocol_grant"]), engine.max_protocol(0))
		if int(step["protocol_drain"]) > 0:
			bs.protocol_points = maxi(0, bs.protocol_points - int(step["protocol_drain"]))

		result = str((step["result"] as Dictionary).get("result", "ongoing"))
		if result == "victory" or result == "defeat":
			break
		_process_summons(cm, dm, (step["result"] as Dictionary).get("events", []))
		# End-of-turn income (+1). SIM-TODO: blackout / income-debt exceptions.
		engine.gain_protocol(bs, 1, engine.max_protocol(0))

	gs.call("capture_battle_end_survival", cm.get_hero_states())
	var squad_hp: Array = []
	for hs in cm.get_hero_states():
		squad_hp.append(int(hs["current_hp"]))
	_emit({
		"type": "battle_end", "index": battle_index, "result": result,
		"rounds": rounds, "squad_hp": squad_hp, "protocol_left": bs.protocol_points,
	})
	return {"result": result, "rounds": rounds}


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


# ── Between-battle (stub policy: option 0) ────────────────────────────────────
func _claim_first_reward(gs: Node) -> void:
	gs.call("prepare_battle_rewards")
	var items: Array = gs.call("get_pending_reward_items")
	for item_variant in items:
		var item: ItemData = item_variant as ItemData
		if item == null:
			continue
		if item.item_type == "consumable" and (gs.get("consumables") as Array).size() >= int(gs.get("MAX_CONSUMABLES")):
			continue
		var target_unit_id: String = ""
		if item.item_type == "gear":
			target_unit_id = str((gs.get("selected_units") as Array)[0])
		gs.call("claim_reward", item.id, target_unit_id)
		return


func _resolve_progression_stop(gs: Node) -> void:
	if bool(gs.call("is_pending_directive_stage")):
		var choices: Array = gs.call("get_pending_directive_choices")
		if not choices.is_empty():
			gs.call("apply_pending_directive", str((choices[0] as Dictionary).get("name", "")))
	elif bool(gs.call("has_pending_evolution")):
		var paths: Array = gs.call("get_pending_evolution_paths")
		if not paths.is_empty():
			gs.call("apply_pending_evolution", str((paths[0] as Dictionary).get("name", "")))


func _advance(gs: Node) -> void:
	# Mirror SceneManager.go_to_next_battle_or_beat's advance, minus the beat
	# detour screens. SIM-TODO(kev): apply beat effects via the policy layer.
	var beat: Dictionary = gs.call("get_beat_after_battle", int(gs.get("current_battle")))
	if not beat.is_empty() and not (gs.get("consumed_beats") as Array).has(int(gs.get("current_battle"))):
		(gs.get("consumed_beats") as Array).append(int(gs.get("current_battle")))
	gs.call("advance_to_next_battle")


# ── JSONL emit ────────────────────────────────────────────────────────────────
func _open_out(path: String) -> bool:
	var dir: String = path.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	_out = FileAccess.open(path, FileAccess.WRITE)
	return _out != null


func _emit(obj: Dictionary) -> void:
	if _out == null:
		return
	obj["run_id"] = _run_id
	obj["seed"] = _seed
	obj["t"] = _t
	_t += 1
	_out.store_line(JSON.stringify(obj))
