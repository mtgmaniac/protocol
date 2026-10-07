# AutoPick — the "Auto-select sole valid target" setting (G-49, Kev 2026-10-06).
#
# Off by default. With it on, an armed action (Reroll, Nudge, Set, or an item
# that needs a target) whose pick has exactly ONE valid target makes that pick
# for the player, and a short note names what was picked. With two or more
# valid targets, or none, nothing changes: the player picks as before.
#
# Never in the tutorial (the drill teaches the tap). Hero abilities are not
# part of this: a hero ability with one legal target has always been assigned
# on its own (battle_scene._try_auto_assign_single_manual_target).
#
# Rules only. ProtocolActions arms the action, asks sole_target(), and makes the
# pick through the same handler a tap reaches. Preloaded by path, not a
# class_name: -s gates parse before the editor rebuilds the global class cache.
extends RefCounted

const SETTING := "auto_select_sole_target"
## Debug-build seam for the gate's deliberate breaks (never set by the game):
##   off        the setting is ignored, nothing is ever picked
##   any_count  picks the first valid target even when there are several
##   no_cue     picks without naming the pick
const BREAK_ARG := "--auto-pick-break="


static func break_mode() -> String:
	if not OS.is_debug_build():
		return ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(BREAK_ARG):
			return arg.trim_prefix(BREAK_ARG)
	return ""


static func enabled(scene: Node) -> bool:
	if break_mode() == "off" or bool(scene._game_state().tutorial_mode):
		return false
	var settings: Node = scene.get_node_or_null("/root/SaveManager")
	return settings != null and bool(settings.get_setting(SETTING, false))


## Every target the action armed right now could take: [{side, id, name}].
## "Valid" means the pick would go through: a die that can be altered and that
## the pool can pay for, or a unit the pending item may legally target.
static func valid_targets(actions: Node) -> Array:
	var scene: Node = actions._scene
	var phase: int = int(scene.turn_phase)
	var heroes: Array = scene.combat_manager.get_hero_states()
	var enemies: Array = scene.combat_manager.get_enemy_states()
	var out: Array = []
	if phase == int(scene.PHASE_REROLL_PICK) or phase == int(scene.PHASE_SET_PICK):
		for state in heroes:
			if not bool(state.get("dead", false)) and scene._has_roll_for_state(scene.hero_rolls, state) \
					and scene._engine.can_alter_die(state):
				out.append(_entry("hero", state))
	elif phase == int(scene.PHASE_NUDGE_PICK):
		for state in heroes:
			var hero_id: String = str(state.get("id", ""))
			# A die already nudged is only valid as a free Reverse Gimbal flip.
			if actions.can_nudge_hero(state) and (actions._was_hero_nudged_this_turn(hero_id)
					or int(scene.protocol_points) >= int(actions._get_nudge_cost(hero_id))):
				out.append(_entry("hero", state))
		# Firewall Hack: the Nudge can also take one enemy die.
		for state in enemies:
			if str(scene._engine.firewall_hack_block(scene._state, state)) == "":
				out.append(_entry("enemy", state))
	elif scene.is_item_pick_phase(phase):
		for id_variant in scene.legal_target_ids:
			var hero: Dictionary = scene._find_state_by_id(heroes, str(id_variant))
			if not hero.is_empty():
				out.append(_entry("hero", hero))
				continue
			var enemy: Dictionary = scene._find_state_by_id(enemies, str(id_variant))
			if not enemy.is_empty():
				out.append(_entry("enemy", enemy))
	return out


## The one valid target of the armed action, or {} when the setting is off or
## there is not exactly one.
static func sole_target(actions: Node) -> Dictionary:
	if not enabled(actions._scene):
		return {}
	var targets: Array = valid_targets(actions)
	if targets.size() == 1 or (break_mode() == "any_count" and not targets.is_empty()):
		return targets[0]
	return {}


## The note shown for a pick made by sole_target().
static func cue_text(pick: Dictionary) -> String:
	if break_mode() == "no_cue":
		return ""
	return "Only target: %s." % str(pick.get("name", ""))


static func _entry(side: String, state: Dictionary) -> Dictionary:
	var unit: Object = state.get("unit") as Object
	return {
		"side": side,
		"id": str(state.get("id", "")),
		"name": str(unit.get("display_name")) if unit != null else str(state.get("id", "")),
	}
