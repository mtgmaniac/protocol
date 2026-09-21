# BattleCheckpoint — the end-of-round battle checkpoint (save system, 2026-09-21).
#
# A battle in progress is saved ONCE per completed round, at the stable
# ready-to-roll boundary: every hero and enemy action, damage, death, status
# tick, summon/revive, the protocol income and the round counter have all
# resolved, and the next round's Roll is about to become available. Nothing
# mid-round is ever saved (no dice physics, no selection, no feedback).
#
# Shape (the run save's `battle_checkpoint` block; {} when there is none):
#   format : int        BattleCheckpoint.FORMAT — a mismatch drops the
#                        checkpoint (the battle restarts from its entry, which
#                        is the pre-checkpoint behavior), never the run
#   battle : int        GameState.current_battle it belongs to
#   round  : int        the round the player is about to roll
#   run    : Dictionary GameState.to_save_dict() AT the checkpoint. The
#                        envelope's own `run` block stays the battle-ENTRY
#                        snapshot (pre-consumption), so a rejected checkpoint
#                        still restarts the battle correctly
#   state  : String     var_to_str() of the combat + scene state below. Text,
#                        not JSON: JSON turns every int into a float and cannot
#                        hold 64-bit RNG states; var_to_str round-trips types
#
# `state` holds: combat (CombatManager.export_checkpoint with every "unit"
# Resource replaced by a reference), the owned RNG stream states (the next
# dice), the Protocol pool and per-battle spend flags, the round counter, the
# intercept battle effects, and GameState's per-battle XP accumulators.
# Preloaded by path (const BattleCheckpoint := preload(...)) at every use, not a
# class_name: headless gates and fresh clones parse before the editor rebuilds
# the global class cache (the sim policies' gotcha).
extends RefCounted

const FORMAT := 1


## Builds the checkpoint block from a live battle scene at the ready-to-roll
## boundary. Returns {} when the state cannot be represented (an unexpected
## Object somewhere in it) — a missing checkpoint is safe, a partial one is not.
static func capture(scene: Node, game_state: Node) -> Dictionary:
	var combat: Dictionary = scene.combat_manager.export_checkpoint()
	for key in ["hero_states", "enemy_states"]:
		var encoded: Array = []
		for state_variant in combat[key]:
			var state: Dictionary = (state_variant as Dictionary).duplicate(true)
			state["unit"] = _unit_ref(state.get("unit"))
			encoded.append(state)
		combat[key] = encoded
	var bs: BattleState = scene._state
	var state_block: Dictionary = {
		"combat": combat,
		"streams": scene._roll_provider.get_stream_states(),
		"protocol_points": bs.protocol_points,
		"income_debt": bs.income_debt,
		"free_nudge_used": bs.free_nudge_used.duplicate(true),
		"root_access_used": bs.root_access_used,
		"round_number": int(scene._round_number),
		"battle_effects": (scene._battle_effects as Dictionary).duplicate(true),
		"xp": game_state.export_battle_xp_tracking(),
	}
	var bad_path: String = _find_object(state_block, "state")
	if bad_path != "":
		push_warning("[BattleCheckpoint] not saved - %s holds an Object" % bad_path)
		return {}
	return {
		"format": FORMAT,
		"battle": int(game_state.current_battle),
		"round": int(scene._round_number),
		"run": game_state.to_save_dict(),
		"state": var_to_str(state_block),
	}


## The decoded `state` block, or {} when the checkpoint is unusable for the
## given run: wrong format, wrong battle, unparsable text, missing pieces, or a
## unit reference that cannot resolve. SaveManager calls this BEFORE deciding
## which run block to load, so a bad checkpoint falls back cleanly to the
## battle-entry snapshot.
static func decode(checkpoint: Dictionary, current_battle: int) -> Dictionary:
	if checkpoint.is_empty():
		return {}
	if int(checkpoint.get("format", -1)) != FORMAT:
		return {}
	if int(checkpoint.get("battle", -1)) != current_battle or current_battle <= 0:
		return {}
	var run_block: Variant = checkpoint.get("run")
	if not (run_block is Dictionary) or (run_block as Dictionary).is_empty():
		return {}
	var parsed: Variant = str_to_var(str(checkpoint.get("state", "")))
	if not (parsed is Dictionary):
		return {}
	var state_block: Dictionary = parsed
	if _find_object(state_block, "state") != "":
		return {}
	for key in ["combat", "streams", "protocol_points", "income_debt", "free_nudge_used",
			"root_access_used", "round_number", "battle_effects", "xp"]:
		if not state_block.has(key):
			return {}
	var combat: Dictionary = state_block["combat"]
	if not (combat.get("hero_states") is Array) or not (combat.get("enemy_states") is Array):
		return {}
	if (combat["hero_states"] as Array).is_empty() or (combat["enemy_states"] as Array).is_empty():
		return {}
	var squad: Array = (run_block as Dictionary).get("selected_units", [])
	for state_variant in combat["hero_states"]:
		var ref: Dictionary = (state_variant as Dictionary).get("unit", {})
		if str(ref.get("kind", "")) != "hero" or not squad.has(str(ref.get("id", ""))):
			return {}
	for state_variant in combat["enemy_states"]:
		var ref: Dictionary = (state_variant as Dictionary).get("unit", {})
		if str(ref.get("kind", "")) != "enemy" or _data_manager().get_enemy_by_display_name(str(ref.get("name", ""))) == null:
			return {}
	return state_block


## Replaces every unit reference in a decoded combat block with a live Resource:
## heroes from GameState.get_run_unit_data (the run's evolved/directed kit, the
## same source _build_runtime_units uses), enemies as fresh copies of their data
## definition. Returns false if any reference no longer resolves.
static func link_units(combat: Dictionary, game_state: Node) -> bool:
	for state_variant in combat["hero_states"]:
		var state: Dictionary = state_variant
		var unit: UnitData = game_state.get_run_unit_data(str((state["unit"] as Dictionary).get("id", "")))
		if unit == null:
			return false
		state["unit"] = unit
	for state_variant in combat["enemy_states"]:
		var state: Dictionary = state_variant
		var ref: Dictionary = state["unit"]
		var base: EnemyData = _data_manager().get_enemy_by_display_name(str(ref.get("name", ""))) as EnemyData
		if base == null:
			return false
		var copy: EnemyData = base.duplicate(true) as EnemyData
		if copy == null:
			copy = base
		copy.starts_cloaked = bool(ref.get("starts_cloaked", false))
		state["unit"] = copy
	return true


# The DataManager autoload, looked up at call time: this script is preloaded by
# `-s` gate scripts that compile before autoload singletons are registered, so
# the bare DataManager identifier would not resolve there.
static func _data_manager() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("DataManager")


static func _unit_ref(unit: Variant) -> Dictionary:
	if unit is EnemyData:
		return {"kind": "enemy", "name": str((unit as EnemyData).display_name),
			"starts_cloaked": bool((unit as EnemyData).starts_cloaked)}
	if unit is UnitData:
		return {"kind": "hero", "id": str((unit as UnitData).id)}
	return {"kind": "unknown"}


## Path to the first Object in a value, or "" when it is plain data.
static func _find_object(value: Variant, path: String) -> String:
	if value is Object:
		return path
	if value is Dictionary:
		for key in (value as Dictionary):
			var found: String = _find_object((value as Dictionary)[key], "%s.%s" % [path, str(key)])
			if found != "":
				return found
	elif value is Array:
		for i in (value as Array).size():
			var found: String = _find_object((value as Array)[i], "%s[%d]" % [path, i])
			if found != "":
				return found
	return ""
