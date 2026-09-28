# BossRelicActions — the live battle screen's half of the boss relics that
# touch the dice (boss relic rework, Kev 2026-09-27; DECISIONS_RESOLVED
# G-34..G-38). The RULES live in BattleEngine / CombatManager, shared with the
# headless sim; this module owns only their presentation and input: the
# Scrap Converter grant after a landing, the Firewall Hack pick on an enemy die. Kept out of battle_scene.gd (over its line limit) on purpose.
#
# NARROW INTERFACE (battle_scene and ProtocolActions only):
#   setup(scene)
#   on_roll_started()                      - per-roll resets (Firewall Hack)
#   restore_pending_actions(actions)       - a settled re-throw's enemy Nudges after a refresh
#   on_dice_landed(restoring)              - Scrap Converter
#   grant_landing_protocol(hero_ids)       - Scrap Converter after a hero Reroll
#   can_hack_any() / try_firewall_hack(id) - Firewall Hack from the Nudge pick
extends Node


var _scene: Node = null


func setup(scene: Node) -> void:
	_scene = scene


func _engine() -> BattleEngine:
	return _scene._engine


func _bs() -> BattleState:
	return _scene._state


# ── Per roll ──────────────────────────────────────────────────────────────────

func on_roll_started() -> void:
	_bs().firewall_hack_used = false
	_bs().enemy_roll_nudges.clear()


# A refresh after a settled re-throw puts back this round's Firewall Hack too.
func restore_pending_actions(actions: Dictionary) -> void:
	_bs().enemy_roll_nudges.assign(actions.get("enemy_nudges", {}))
	_bs().firewall_hack_used = bool(actions.get("firewall_hack_used", false))


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


# ── Firewall Hack (G-36) ──────────────────────────────────────────────────────

func can_hack_any() -> bool:
	for enemy_state in _scene.combat_manager.get_enemy_states():
		if _engine().firewall_hack_block(_bs(), enemy_state) == "":
			return true
	return false


# The Nudge pick landed on an enemy die. True when this module handled the tap.
func try_firewall_hack(enemy_id: String) -> bool:
	if not _scene.combat_manager.has_relic("enemyNudgeOncePerTurn"):
		return false
	var enemy_state: Dictionary = _scene._find_state_by_id(_scene.combat_manager.get_enemy_states(), enemy_id)
	match _engine().firewall_hack_block(_bs(), enemy_state):
		"":
			pass
		"used":
			_scene._refresh_summary("Firewall Hack is used up this turn.")
			return true
		"frozen":
			_scene._refresh_summary("That die is frozen solid - it can't be nudged.")
			return true
		"hijacked":
			_scene._refresh_summary("A hijacked die can't be nudged.")
			return true
		"protocol":
			_scene._refresh_summary("Need 1 Protocol to Nudge.")
			return true
		_:
			return true
	var before: int = _scene._get_effective_enemy_roll(enemy_state, enemy_id)
	AudioManager.play_select()
	_engine().apply_firewall_hack(_bs(), enemy_state)
	var after: int = _scene._get_effective_enemy_roll(enemy_state, enemy_id)
	_scene._update_protocol_bar()
	_scene._append_log("Firewall Hack: %s %d -> %d." % [str(enemy_state["unit"].display_name), before, after])
	# The die tips over onto its new face (live values); the enemy's intent and
	# readout rebuild from the new value.
	_scene._on_die_values_changed()
	_scene._finish_roll_modifier_pick()
	return true
