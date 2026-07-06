# Freeze regression guard (rules/engine layer). Drives combat via BattleEngine's
# real round pipeline (roll build -> apply_frozen_roll_overrides ->
# record_roll_values_for_states -> resolve_step) — the exact glue the sim
# extraction re-pointed and the live screen uses, which the ability audit's
# direct resolve_round calls bypass.
#
# Asserts FREEZE = REPEAT (per Kev 2026-07-06, final — supersedes both the
# next-turn static lockout and the fix-1.4 bank/thaw model):
# Round 1: Avalanche (roll 3 -> Glacial Lattice, freezeAnyDice) freezes an
# enemy that STILL lands its hit this round and is left frozen at its face.
# Round 2: the crusted die keeps that face and the enemy ACTS AGAIN on the
# same result (same damage lands), then the repeat is spent.
# Round 3: the die has thawed — it rerolls and the frozen value is cleared.
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
	bs.hero_rolls = {str(hero["id"]): 3}          # Glacial Lattice (freeze any)
	bs.enemy_rolls = {str(en["id"]): enemy_roll}
	engine.apply_frozen_roll_overrides(cm.get_hero_states(), bs.hero_rolls)
	engine.apply_frozen_roll_overrides(cm.get_enemy_states(), bs.enemy_rolls)
	engine.record_roll_values_for_states(cm.get_hero_states(), bs.hero_rolls)
	engine.record_roll_values_for_states(cm.get_enemy_states(), bs.enemy_rolls)
	var step1: Dictionary = engine.resolve_step(bs)
	var freeze_emitted: bool = _has_freeze_event((step1["result"] as Dictionary).get("events", []))
	var hp_after_r1: int = int(hero["current_hp"])
	var r1_damage: int = hp_start - hp_after_r1
	var enemy_acted_r1: bool = r1_damage > 0
	var frozen_after_r1: bool = int(en.get("die_freeze_turns", 0)) == 1 \
		and int(en.get("frozen_die_value", 0)) == enemy_roll \
		and not bool(en.get("die_freeze_repeat_this_round", false))

	# ── Round 2: the crusted die keeps its face — the enemy ACTS AGAIN on the
	# same result (Avalanche sits out so it can't re-freeze). The fresh roll is
	# ignored by the frozen override, exactly as the live roll flow does. ─────
	bs.hero_rolls = {}
	bs.enemy_rolls = {str(en["id"]): _different_roll(enemy_roll)}
	engine.apply_frozen_roll_overrides(cm.get_enemy_states(), bs.enemy_rolls)
	var override_held: bool = int(bs.enemy_rolls[str(en["id"])]) == enemy_roll
	engine.record_roll_values_for_states(cm.get_hero_states(), bs.hero_rolls)
	engine.record_roll_values_for_states(cm.get_enemy_states(), bs.enemy_rolls)
	engine.resolve_step(bs)
	var r2_damage: int = hp_after_r1 - int(hero["current_hp"])
	var enemy_repeated_r2: bool = r2_damage == r1_damage
	var repeat_spent: bool = int(en.get("die_freeze_turns", 0)) == 0

	# ── Round 3: thawed — a fresh roll is NOT overridden. ─────────────────────
	bs.hero_rolls = {}
	bs.enemy_rolls = {str(en["id"]): _different_roll(enemy_roll)}
	engine.apply_frozen_roll_overrides(cm.get_enemy_states(), bs.enemy_rolls)
	var thawed_rerolls: bool = int(bs.enemy_rolls[str(en["id"])]) != enemy_roll \
		and int(en.get("frozen_die_value", 0)) == 0

	print("[FREEZE] R1: freeze_emitted=%s enemy_acted=%s (hp %d->%d) frozen=%s | R2: override_held=%s repeated=%s (dmg %d==%d) spent=%s | R3: thawed=%s" % [
		str(freeze_emitted), str(enemy_acted_r1), hp_start, hp_after_r1, str(frozen_after_r1),
		str(override_held), str(enemy_repeated_r2), r2_damage, r1_damage, str(repeat_spent), str(thawed_rerolls)])

	if freeze_emitted and enemy_acted_r1 and frozen_after_r1 and override_held and enemy_repeated_r2 and repeat_spent and thawed_rerolls:
		print("[FREEZE] RESULT: freeze = repeat (act again on the crusted face, then thaw) — PASS")
		get_tree().quit(0)
	else:
		print("[FREEZE] RESULT: freeze semantics WRONG (expected act-this-round, repeat-next-round, then thaw)")
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


# A roll different from `taken`, so an unwanted reroll is detectable.
func _different_roll(taken: int) -> int:
	return taken - 1 if taken > 1 else taken + 1
