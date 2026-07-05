# Freeze regression guard (rules/engine layer). Drives combat via BattleEngine's
# real round pipeline (apply_frozen_roll_overrides -> record_roll_values_for_states
# -> resolve_step) with CONTROLLED rolls, so it exercises exactly the glue the
# sim extraction touched — unlike the ability audit, which calls resolve_round
# directly. Scenario: Avalanche rolls into the freeze band (Glacial Lattice,
# roll 3) and freezes an enemy that would otherwise hit the hero; asserts the
# freeze event fires, the enemy's imminent hit is cancelled, and the charge is
# consumed. Added while diagnosing "freeze appears broken on the live screen" —
# it proves the RULES/ENGINE layer is healthy, isolating that bug to
# battle_scene display/wiring. Exit 0 = pass, 2 = rules-layer freeze broken.
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

	# Pick an enemy roll that maps to a damage ability, so "enemy skipped" is
	# observable as "hero took no damage".
	var enemy_roll: int = _find_damage_roll(dmgr, enemy)
	var avalanche_roll: int = 3  # recharge band -> Glacial Lattice (pure freeze)

	hero["selected_target_id"] = str(en["id"])
	en["selected_target_id"] = str(hero["id"])

	var ability: Dictionary = dmgr.get_ability_for_roll(avalanche, avalanche_roll)
	var enemy_ability: Dictionary = dmgr.get_ability_for_roll(enemy, enemy_roll)
	print("[FREEZE] avalanche roll %d -> %s (freezeEnemyDice=%s)" % [
		avalanche_roll, str(ability.get("ability_name", "?")),
		str((ability.get("raw", {}) as Dictionary).get("freezeEnemyDice", 0))])
	print("[FREEZE] enemy roll %d -> %s (dmg=%s)" % [
		enemy_roll, str(enemy_ability.get("ability_name", "?")),
		str((enemy_ability.get("raw", {}) as Dictionary).get("dmg", 0))])

	# Engine round pipeline with controlled rolls (bypass roll_states only).
	var engine := BattleEngine.new(cm, null, dmgr)
	var bs := BattleState.new()
	bs.hero_rolls = {str(hero["id"]): avalanche_roll}
	bs.enemy_rolls = {str(en["id"]): enemy_roll}
	engine.apply_frozen_roll_overrides(cm.get_hero_states(), bs.hero_rolls)
	engine.apply_frozen_roll_overrides(cm.get_enemy_states(), bs.enemy_rolls)
	engine.record_roll_values_for_states(cm.get_hero_states(), bs.hero_rolls)
	engine.record_roll_values_for_states(cm.get_enemy_states(), bs.enemy_rolls)

	var hero_hp_before: int = int(hero["current_hp"])
	var step: Dictionary = engine.resolve_step(bs)
	var result: Dictionary = step["result"]

	print("[FREEZE] --- round log ---")
	for line in result.get("log", []):
		print("   ", str(line))
	print("[FREEZE] --- events ---")
	var freeze_emitted: bool = false
	for ev_variant in result.get("events", []):
		var ev: Dictionary = ev_variant
		print("   ", str(ev))
		if str(ev.get("type", "")) == "freeze":
			freeze_emitted = true

	var hero_hp_after: int = int(hero["current_hp"])
	var enemy_skipped: bool = hero_hp_after == hero_hp_before
	var charge_consumed: bool = int(en.get("die_freeze_turns", 0)) == 0

	print("[FREEZE] freeze_emitted=%s  enemy_skipped=%s (hp %d->%d)  charge_consumed=%s (die_freeze_turns=%d)" % [
		str(freeze_emitted), str(enemy_skipped), hero_hp_before, hero_hp_after,
		str(charge_consumed), int(en.get("die_freeze_turns", 0))])

	if freeze_emitted and enemy_skipped and charge_consumed:
		print("[FREEZE] RESULT: rules/engine layer FREEZE WORKS")
		get_tree().quit(0)
	else:
		print("[FREEZE] RESULT: rules/engine layer FREEZE BROKEN")
		get_tree().quit(2)


func _find_damage_roll(dmgr: DiceManager, enemy: EnemyData) -> int:
	for roll in range(1, 21):
		var ability: Dictionary = dmgr.get_ability_for_roll(enemy, roll)
		if int((ability.get("raw", {}) as Dictionary).get("dmg", 0)) > 0:
			return roll
	return 20
