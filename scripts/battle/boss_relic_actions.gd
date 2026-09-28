# BossRelicActions — the live battle screen's half of the boss relics that
# touch the dice (boss relic rework, Kev 2026-09-27; DECISIONS_RESOLVED
# G-34..G-38). The RULES live in BattleEngine / CombatManager, shared with the
# headless sim; this module owns only their presentation and input: the
# Scrap Converter grant after a landing, the Tectonic Charge hold and the
# Firewall Hack pick on an enemy die. Kept out of battle_scene.gd (over its line limit) on purpose.
#
# NARROW INTERFACE (battle_scene and ProtocolActions only):
#   setup(scene)
#   on_roll_started()                      - per-roll resets (Firewall Hack)
#   hero_roll_states() -> Array            - heroes that throw this roll ([] while holding)
#   restore_pending_actions(actions)       - a settled re-throw's enemy Nudges after a refresh
#   on_dice_landed(restoring)              - Scrap Converter + the hold banner
#   grant_landing_protocol(hero_ids)       - Scrap Converter after a hero Reroll
#   on_round_resolved()                    - drops the hold banner
#   can_hack_any() / try_firewall_hack(id) - Firewall Hack from the Nudge pick
extends Node

const HOLD_BANNER_FONT := 48

var _scene: Node = null
var _hold_banner: PanelContainer = null


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


# Tectonic Charge (G-38): no hero die is thrown while the heroes hold.
func hero_roll_states() -> Array:
	if _engine().heroes_hold_this_round():
		return []
	return _scene.combat_manager.get_hero_states()


# A refresh after a settled re-throw puts back this round's Firewall Hack too.
func restore_pending_actions(actions: Dictionary) -> void:
	_bs().enemy_roll_nudges.assign(actions.get("enemy_nudges", {}))
	_bs().firewall_hack_used = bool(actions.get("firewall_hack_used", false))


# After a roll's dice settle. `restoring` = CONTINUE into a settled re-throw,
# whose grants are already in the restored Protocol (never pay twice).
func on_dice_landed(restoring: bool) -> void:
	if not restoring:
		grant_landing_protocol(_engine().thrown_hero_ids(_bs()))
	if _engine().heroes_hold_this_round():
		_scene._append_log("TECTONIC CHARGE - your heroes hold this round. +%d to every hero roll from round 2." % int(_scene.combat_manager.get_relic_value("heroesHoldRoundOne", "amount", 2)))
		_show_hold_banner()


func on_round_resolved() -> void:
	if _hold_banner != null and is_instance_valid(_hold_banner):
		_hold_banner.queue_free()
	_hold_banner = null


# Scrap Converter (G-34): +1 Protocol per listed hero die that landed on 1 or 2.
func grant_landing_protocol(hero_ids: Array) -> void:
	var grant: int = _engine().landing_protocol(_bs(), hero_ids)
	if grant <= 0:
		return
	_scene._gain_protocol(grant)
	_scene._append_log("Scrap Converter: +%d Protocol -> %d" % [grant, _scene.protocol_points])


# A plate where the hero dice's readouts would be: the heroes hold this round.
func _show_hold_banner() -> void:
	on_round_resolved()
	if _scene.float_layer == null or not is_instance_valid(_scene.float_layer):
		return
	var panel := PanelContainer.new()
	panel.name = "HeroesHoldBanner"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	PixelUI.style_component(panel, PixelUI.COMPONENT_NORMAL, Color.TRANSPARENT, true)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "YOUR HEROES HOLD THIS ROUND"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.style_label(label, HOLD_BANNER_FONT, PixelUI.DT_CYAN_BRIGHT, 3)
	margin.add_child(label)
	panel.z_as_relative = false
	panel.z_index = 105
	_scene.float_layer.add_child(panel)
	panel.reset_size()
	panel.size = panel.get_combined_minimum_size()
	var anchor: Rect2 = _scene.hero_readouts.get_global_rect()
	if anchor.size.x <= 0.0:
		anchor = _scene.center_panel.get_global_rect()
	var pos := Vector2(anchor.get_center().x - panel.size.x * 0.5, anchor.get_center().y - panel.size.y * 0.5)
	pos -= _scene.float_layer.get_global_position()
	panel.position = Vector2(PixelUI.even_px(pos.x), PixelUI.even_px(pos.y))
	_hold_banner = panel


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
