# BossRelicActions — the live battle screen's half of the boss relics that
# touch the dice (boss relic rework, Kev 2026-09-27; DECISIONS_RESOLVED
# G-34..G-38). The RULES live in BattleEngine / CombatManager, shared with the
# headless sim; this module owns only their presentation and input: the
# Scrap Converter grant after a landing. Kept out of battle_scene.gd (over its line limit) on purpose.
#
# NARROW INTERFACE (battle_scene and ProtocolActions only):
#   setup(scene)
#   on_dice_landed(restoring)              - Scrap Converter
#   grant_landing_protocol(hero_ids)       - Scrap Converter after a hero Reroll
extends Node


var _scene: Node = null


func setup(scene: Node) -> void:
	_scene = scene


func _engine() -> BattleEngine:
	return _scene._engine


func _bs() -> BattleState:
	return _scene._state


# After a roll's dice settle. `restoring` = CONTINUE into a settled re-throw,
# whose grants are already in the restored Protocol (never pay twice).
func on_dice_landed(restoring: bool) -> void:
	if not restoring:
		grant_landing_protocol(_engine().thrown_hero_ids(_bs()))


# Scrap Converter (G-34): +1 Protocol per listed hero die that landed on 1 or 2.
func grant_landing_protocol(hero_ids: Array) -> void:
	var grant: int = _engine().landing_protocol(_bs(), hero_ids)
	if grant <= 0:
		return
	_scene._gain_protocol(grant)
	_scene._append_log("Scrap Converter: +%d Protocol -> %d" % [grant, _scene.protocol_points])
