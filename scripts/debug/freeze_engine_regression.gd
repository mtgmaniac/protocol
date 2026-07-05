# Freeze regression guard (rules/engine layer). Drives combat via BattleEngine's
# real round pipeline (roll build -> apply_frozen_roll_overrides ->
# record_roll_values_for_states -> resolve_step) — the exact glue the sim
# extraction re-pointed and the live screen uses, which the ability audit's
# direct resolve_round calls bypass.
#
# Asserts the INTENDED freeze semantics (reverted from pkg1.3's imminent-cancel):
# a hero freeze locks the enemy's NEXT reveal. Round 1: Avalanche (roll 3 ->
# Glacial Lattice) freezes an enemy that STILL lands its hit this round and is
# left frozen. Round 2: the frozen enemy skips its reveal (crust would persist)
# and the charge then clears.
# Exit 0 = pass, 2 = freeze semantics wrong.
# Run: godot --headless --path . res://scenes/debug/freeze_engine_regression.tscn
extends Node


func _ready() -> void:
	var dm: Node = get_node("/root/DataManager")
	var avalanche: UnitData = dm.call("get_unit", "avalanche") as UnitData
	var enemy: EnemyData = dm.call("get_enemy_by_display_name", "Scrap Drone") as EnemyData
	if avalanche == null or enemy == null:
		printerr("[FREEZE] could not load units (avalanche=%s enemy=%s)" % [avalanche, enemy])
		get_tree().quit(1)
		return

	var dmgr := DiceManager.new()
	var cm := CombatManager.new()
	cm.setup_battle([avalanche], [enemy.duplicate(true)])
	var hero: Dictionary = cm.get_hero_states()[0]
	var en: Dictionary = cm.get_enemy_states()[0]
	hero["selected_target_id"] = str(en["id"])
	en["selected_target_id"] = str(hero["id"])

	var enemy_roll: int = _find_damage_roll(dmgr, enemy)  # a roll that deals damage
	var engine := BattleEngine.new(cm, null, dmgr)
	var bs := BattleState.new()

	# ── Round 1: Avalanche freezes; the enemy STILL hits this round. ──────────
	var hp_start: int = int(hero["current_hp"])
	bs.hero_rolls = {str(hero["id"]): 3}          # Glacial Lattice (freeze)
	bs.enemy_rolls = {str(en["id"]): enemy_roll}
	engine.apply_frozen_roll_overrides(cm.get_hero_states(), bs.hero_rolls)
	engine.apply_frozen_roll_overrides(cm.get_enemy_states(), bs.enemy_rolls)
	engine.record_roll_values_for_states(cm.get_hero_states(), bs.hero_rolls)
	engine.record_roll_values_for_states(cm.get_enemy_states(), bs.enemy_rolls)
	var step1: Dictionary = engine.resolve_step(bs)
	var freeze_emitted: bool = _has_freeze_event((step1["result"] as Dictionary).get("events", []))
	var hp_after_r1: int = int(hero["current_hp"])
	var enemy_acted_r1: bool = hp_after_r1 < hp_start
	var frozen_after_r1: bool = int(en.get("die_freeze_turns", 0)) == 1 and not bool(en.get("die_freeze_consumed_this_round", false))

	# ── Round 2: the frozen enemy skips its reveal (Avalanche sits out so it
	# can't re-freeze). record_roll_values sets the consumed flag from the
	# carried die_freeze_turns, exactly as the live roll flow does. ───────────
	bs.hero_rolls = {}
	bs.enemy_rolls = {str(en["id"]): enemy_roll}
	engine.apply_frozen_roll_overrides(cm.get_enemy_states(), bs.enemy_rolls)
	engine.record_roll_values_for_states(cm.get_hero_states(), bs.hero_rolls)
	engine.record_roll_values_for_states(cm.get_enemy_states(), bs.enemy_rolls)
	engine.resolve_step(bs)
	var enemy_skipped_r2: bool = int(hero["current_hp"]) == hp_after_r1
	var charge_cleared: bool = int(en.get("die_freeze_turns", 0)) == 0

	print("[FREEZE] R1: freeze_emitted=%s enemy_acted=%s (hp %d->%d) frozen=%s | R2: enemy_skipped=%s charge_cleared=%s" % [
		str(freeze_emitted), str(enemy_acted_r1), hp_start, hp_after_r1, str(frozen_after_r1),
		str(enemy_skipped_r2), str(charge_cleared)])

	if freeze_emitted and enemy_acted_r1 and frozen_after_r1 and enemy_skipped_r2 and charge_cleared:
		print("[FREEZE] RESULT: freeze locks the enemy's NEXT reveal — PASS")
		get_tree().quit(0)
	else:
		print("[FREEZE] RESULT: freeze semantics WRONG (expected act-this-round then skip-next)")
		get_tree().quit(2)


func _has_freeze_event(events: Array) -> bool:
	for ev in events:
		if str((ev as Dictionary).get("type", "")) == "freeze":
			return true
	return false


func _find_damage_roll(dmgr: DiceManager, enemy: EnemyData) -> int:
	for roll in range(1, 21):
		var ability: Dictionary = dmgr.get_ability_for_roll(enemy, roll)
		if int((ability.get("raw", {}) as Dictionary).get("dmg", 0)) > 0:
			return roll
	return 20
