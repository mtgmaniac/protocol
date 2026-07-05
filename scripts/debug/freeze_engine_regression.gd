# Freeze regression guard (rules/engine layer). Drives combat via BattleEngine's
# real round pipeline (roll build -> apply_frozen_roll_overrides ->
# record_roll_values_for_states -> resolve_step) — the exact glue the sim
# extraction re-pointed and the live screen uses, which the ability audit's
# direct resolve_round calls bypass.
#
# Asserts the fix-1.4 universal freeze rule: a hero freeze lands BEFORE the
# enemy's reveal, so the imminent action is SKIPPED and its face is banked;
# the thaw reveals the banked face (freeze = delay, not deny+reroll).
# Round 1: Avalanche (roll 3 -> Glacial Lattice) freezes the enemy — the
# enemy does NOT hit, and after the round-end tick the face is banked.
# Round 2: the enemy's fresh roll is overridden by the banked face and the
# delayed hit lands.
# (Supersedes the 67d95b6 "next-turn lockout" reading — DESIGN-TODO(kev) in
# combat_manager's freeze block.)
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
	var banked_dmg: int = int((dmgr.get_ability_for_roll(enemy, enemy_roll).get("raw", {}) as Dictionary).get("dmg", 0))
	var idle_roll: int = _find_no_damage_roll(dmgr, enemy)
	var engine := BattleEngine.new(cm, null, dmgr)
	var bs := BattleState.new()

	# ── Round 1: Avalanche freezes — the enemy's imminent hit is SKIPPED. ─────
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
	var enemy_skipped_r1: bool = hp_after_r1 == hp_start
	var thaw_banked: bool = int(en.get("thaw_reveal_value", 0)) == enemy_roll and int(en.get("die_freeze_turns", 0)) == 0

	# ── Round 2: the thawed die reveals the banked face — the delayed hit
	# lands even though the fresh roll is a no-damage band. ───────────────────
	bs.hero_rolls = {}
	bs.enemy_rolls = {str(en["id"]): idle_roll}
	engine.apply_frozen_roll_overrides(cm.get_enemy_states(), bs.enemy_rolls)
	engine.record_roll_values_for_states(cm.get_hero_states(), bs.hero_rolls)
	engine.record_roll_values_for_states(cm.get_enemy_states(), bs.enemy_rolls)
	engine.resolve_step(bs)
	var delayed_hit: bool = int(hero["current_hp"]) == hp_after_r1 - banked_dmg

	print("[FREEZE] R1: freeze_emitted=%s enemy_skipped=%s (hp %d->%d) banked=%s | R2: delayed_hit=%s (hp %d, expected -%d)" % [
		str(freeze_emitted), str(enemy_skipped_r1), hp_start, hp_after_r1, str(thaw_banked),
		str(delayed_hit), int(hero["current_hp"]), banked_dmg])

	if freeze_emitted and enemy_skipped_r1 and thaw_banked and delayed_hit:
		print("[FREEZE] RESULT: freeze skips the imminent reveal and thaws to the banked face — PASS")
		get_tree().quit(0)
	else:
		print("[FREEZE] RESULT: freeze semantics WRONG (expected skip-this-round, thaw replays banked face)")
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


func _find_no_damage_roll(dmgr: DiceManager, enemy: EnemyData) -> int:
	for roll in range(1, 21):
		var ability: Dictionary = dmgr.get_ability_for_roll(enemy, roll)
		if int((ability.get("raw", {}) as Dictionary).get("dmg", 0)) <= 0:
			return roll
	return 1
