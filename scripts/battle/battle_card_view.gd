class_name BattleCardView
extends Node

var _scene: Control


func _game_state() -> Variant:
	return _scene.get_node("/root/GameState")


func _data_manager() -> Variant:
	return _scene.get_node("/root/DataManager")


func setup(scene: Control) -> void:
	_scene = scene


# ── Public API ────────────────────────────────────────────────────────────────

func update_card_view(card: Control, state: Dictionary, roll_value: Variant, accent_color: Color, readout: Control = null, hp_override: int = -1) -> void:
	var unit: Resource = state["unit"]
	# During feedback the combat state already holds the fully-resolved HP/dead flags,
	# so a per-event refresh passes hp_override to step the bar one hit at a time.
	var in_feedback_step: bool = hp_override >= 0
	var shown_hp: int = hp_override if in_feedback_step else int(state["current_hp"])
	var forecast_hp: int = shown_hp if in_feedback_step else int(state["current_hp"])
	var show_dead: bool = (hp_override <= 0) if in_feedback_step else bool(state["dead"])
	var default_entry: Dictionary = unit.dice_ranges[0] if unit.dice_ranges.size() > 0 else {}
	var chosen_entry: Dictionary = default_entry
	var dice_text: String = "D20: --"
	var status_list: Array = []
	var target_text: String = _scene._get_target_text(state)
	var active_zone: String = ""

	# A dead enemy's die is no longer intent. Enemies roll at turn start but act
	# AFTER the heroes, so a kill during the hero phase used to leave the rolled
	# face in the tray and the ability it would have cast on the card — the board
	# reading as though a corpse were still about to swing. Drop both on the same
	# beat the HP bar empties (this runs per feedback event via hp_override), so
	# the card falls back to DOWN with no pips. Hero dice are untouched: the
	# player's own tray is still the surface they are resolving.
	if accent_color == _scene.ENEMY_ACCENT and show_dead:
		roll_value = null
		if _scene.dice_tray_3d != null and is_instance_valid(_scene.dice_tray_3d):
			_scene.dice_tray_3d.clear_die("enemy", str(state["id"]))
		# The die's invisible long-press hit rect goes with it — otherwise a
		# long-press over the now-empty tray keeps opening the corpse's ability.
		_scene.clear_die_tooltip_overlay("enemy", str(state["id"]))

	if roll_value != null:
		var raw_roll: int = int(roll_value)
		var uid: String = str(state["id"])
		var eff_roll: int
		if accent_color == _scene.HERO_ACCENT:
			eff_roll = _scene._get_effective_roll_for_state(state, uid)
		else:
			eff_roll = _scene._get_effective_enemy_roll(state, uid)

		var resolved_entry: Dictionary = _scene.dice_manager.get_ability_for_roll(unit, eff_roll)
		if not resolved_entry.is_empty():
			chosen_entry = resolved_entry
			active_zone = str(chosen_entry.get("zone", ""))
		if eff_roll != raw_roll:
			dice_text = "D20: %d (eff: %d)" % [raw_roll, eff_roll]
		else:
			dice_text = "D20: %d" % eff_roll

	# Shield display (uses running sum kept in state["shield"])
	var total_shield: int = int(state.get("shield", 0))
	if total_shield > 0:
		status_list.append("SH %d" % total_shield)

	if int(state["burn"]) > 0 and int(state.get("burn_turns", 0)) > 0:
		status_list.append("BRN %d ×%dt" % [int(state["burn"]), int(state["burn_turns"])])

	# RFE display
	var total_rfe: int = 0
	for stack in state.get("rfe_stacks", []):
		total_rfe += int(stack["amt"])
	if total_rfe > 0:
		status_list.append("RFE -%d" % total_rfe)

	# Roll buff display
	var roll_buff: int = int(state.get("roll_buff", 0))
	if roll_buff > 0:
		status_list.append("+%d ROLL" % roll_buff)

	if bool(state.get("cloaked", false)):
		status_list.append("CLOAK")
	if int(state.get("die_freeze_turns", 0)) > 0:
		status_list.append("FROZEN %d" % int(state["die_freeze_turns"]))
	if bool(state.get("taunting", false)) or str(state.get("lured_by_id", "")) != "":
		status_list.append("TAUNT")
	if bool(state.get("warded", false)):
		status_list.append("FIREWALL")
	if bool(state.get("marked", false)):
		status_list.append("MARK")

	# No DOWN token (Kev 2026-07-10) — the grayed portrait reads dead on its own.
	var state_id: String = str(state["id"])
	var is_selected: bool = state_id == _scene.active_targeting_hero_id
	var is_targetable: bool = _scene._is_target_highlight_phase() and _scene.legal_target_ids.has(state_id)
	var is_target_locked: bool = false
	var needs_manual_target: bool = false
	var cast_rank: int = 0
	if accent_color == _scene.HERO_ACCENT and not show_dead and roll_value != null:
		if _scene.turn_phase == _scene.PHASE_TARGETING or _scene.turn_phase == _scene.PHASE_READY_TO_END:
			needs_manual_target = _scene.pending_manual_target_ids.has(state_id)
			if state_id != _scene.active_targeting_hero_id:
				is_target_locked = not needs_manual_target
			# Cast-order badge: this hero's 1-based firing rank among committed
			# heroes (0 = uncommitted, no badge).
			cast_rank = _scene.hero_cast_rank(state_id)
	if card is CompactUnitCard:
		var compact_card: CompactUnitCard = card as CompactUnitCard
		var has_revealed_roll: bool = roll_value != null
		var action_label: String = "DOWN" if show_dead else "AWAIT ROLL"
		var action_pips: Variant = []
		if has_revealed_roll:
			action_label = str(chosen_entry.get("ability_name", "NO ACTION"))
			var readout_raw: Dictionary = chosen_entry.get("raw", chosen_entry) as Dictionary
			if accent_color == _scene.HERO_ACCENT:
				# Board-aware revive family (Kev 2026-09-25): show what this roll
				# does NOW — the fallback heal when nobody is down, else the
				# revive at its resolved (directive/relic) percentage.
				readout_raw = ReviveResolution.display_raw(readout_raw, state,
					str(chosen_entry.get("ability_name", "")), _scene.combat_manager.get_hero_states())
			action_pips = EffectPip.ability_readout_payload(
				readout_raw,
				"hero" if accent_color == _scene.HERO_ACCENT else "enemy"
			)
			# pkg8.2: the Detonate pip shows the live computed burst once the
			# target is known (burn × remaining turns, Payload Fuse +50%).
			if accent_color == _scene.HERO_ACCENT and action_pips is Dictionary:
				_patch_live_detonate_value(action_pips, state, chosen_entry)
		if readout != null and readout.has_method("configure"):
			readout.configure(action_pips, "hero" if accent_color == _scene.HERO_ACCENT else "enemy")
		var card_pips: Array = []
		if readout == null and action_pips is Dictionary:
			card_pips = action_pips.get("effects", [])
		compact_card.configure({
			"side": "hero" if accent_color == _scene.HERO_ACCENT else "enemy",
			"name": unit.battle_name(),
			"boss": accent_color == _scene.ENEMY_ACCENT and CombatManager.BOSS_STANDING_RULES.has(str(unit.display_name)),
			"trait": CombatManager.UnitTraits.marker_text(CombatManager.UnitTraits.of_unit(unit)),
			"trait_warning": CombatManager.UnitTraits.is_warning(CombatManager.UnitTraits.of_unit(unit)),
			"current_hp": shown_hp,
			"forecast_hp": forecast_hp,
			"max_hp": int(state["max_hp"]),
			"action": action_label,
			"pips": card_pips,
			"portrait": unit.portrait,
			"statuses": _composed_status_tokens(state),
			"selected": is_selected,
			"targetable": is_targetable,
			"interaction_enabled": _scene._is_card_clickable(state, accent_color),
			"dead": show_dead,
			"cloaked": bool(state.get("cloaked", false)),
			"target_locked": is_target_locked,
			"needs_manual_target": needs_manual_target,
			"cast_rank": cast_rank,
			"show_action_pips": readout == null,
			"unit_data": unit,
			"gear_rows": get_gear_detail_rows(str(unit.id)) if unit is UnitData else [],
		})
		var compact_preview: Dictionary = compute_preview_for_unit(state, accent_color == _scene.HERO_ACCENT)
		if compact_preview.is_empty():
			compact_card.clear_combat_preview()
		else:
			compact_card.show_combat_preview(compact_preview)


# Roll values are decided before the dice are thrown (P0 dice-face audit), so
# they exist while the dice still tumble. Cards, readouts and forecasts must not
# reveal a result the dice have not shown yet: until they land, no rolls.
func _revealed_rolls(side: String) -> Dictionary:
	if not _scene.dice_landed():
		return {}
	return _scene.hero_rolls if side == "hero" else _scene.enemy_rolls


func refresh_all_cards() -> void:
	for hero_view in _scene.hero_card_views:
		var hero_state: Dictionary = hero_view["state"]
		var readout: Control = hero_view.get("readout", null) as Control
		update_card_view(hero_view["card"], hero_state, _revealed_rolls("hero").get(str(hero_state["id"]), null), _scene.HERO_ACCENT, readout)

	for enemy_view in _scene.enemy_card_views:
		var enemy_state: Dictionary = enemy_view["state"]
		var readout: Control = enemy_view.get("readout", null) as Control
		update_card_view(enemy_view["card"], enemy_state, _revealed_rolls("enemy").get(str(enemy_state["id"]), null), _scene.ENEMY_ACCENT, readout)


func show_all_ability_readouts() -> void:
	for view_variant in _scene.hero_card_views + _scene.enemy_card_views:
		var view: Dictionary = view_variant
		var readout: Control = view.get("readout", null) as Control
		if readout != null and is_instance_valid(readout) and readout.has_method("show_pips"):
			readout.call("show_pips")


func hide_all_ability_readouts() -> void:
	for view_variant in _scene.hero_card_views + _scene.enemy_card_views:
		var view: Dictionary = view_variant
		var readout: Control = view.get("readout", null) as Control
		if readout != null and is_instance_valid(readout) and readout.has_method("hide_pips"):
			readout.call("hide_pips")


func refresh_card_for_event(event: Dictionary) -> void:
	var side: String = str(event.get("side", ""))
	var target_id: String = str(event.get("target_id", ""))
	if side == "" or target_id == "":
		return
	var views: Array = _scene.hero_card_views if side == "hero" else _scene.enemy_card_views
	var accent: Color = _scene.HERO_ACCENT if side == "hero" else _scene.ENEMY_ACCENT
	var rolls: Dictionary = _revealed_rolls("hero") if side == "hero" else _revealed_rolls("enemy")
	for view_variant in views:
		var view: Dictionary = view_variant
		var state: Dictionary = view["state"]
		if str(state.get("id", "")) != target_id:
			continue
		var readout: Control = view.get("readout", null) as Control
		update_card_view(view["card"], state, rolls.get(target_id, null), accent, readout, int(event.get("hp_after", -1)))
		return


# ── Round forecast (2026-09-02, "the preview lies"; exact since B1 and G-65) ──
# Heroes resolve BEFORE the enemy phase, so an honest preview walks the round in
# order: the hero phase, the enemy phase, the end-of-round tick. Until
# 2026-09-27 the hero phase was a hand-written lightweight model that left out
# detonate, execute, chain, mark, breach, spike and the relic multipliers (UI
# batch B1). Until G-65 the enemy phase was one too: each enemy's printed
# damage, summed, so no trait (Anchored, Feral's rampage, Volatile on a late
# death), no Rampage and no pack bonus reached a hero's bar. It now runs the
# REAL round through CombatManager.forecast_round on copies of the unit states,
# the same code resolve_round runs, so every rule is in the preview by
# construction. It never touches live combat state.
#
# A hero whose ability takes a manual pick (battle_scene._get_manual_target_side)
# and has no target yet does not act in the dry run: the preview shows nothing
# for an ability whose target the player has not chosen. Its die still counts
# for what reads the dice (a hijack, the enemy intents).
#
# Returns:
#   dead_enemy_ids  {enemy_id: true}    enemies the hero phase kills
#   lured           {enemy_id: hero_id} taunt lures standing after the hero phase
#   taunter_id      the Anchor Frame aura taunter (redirects EVERY enemy), or ""
#   leech_by_hero   {hero_id: int}      self-heal each leeching hero gets
#   after           {state_id: state}   every unit's state copy after the hero phase
#   events          the hero phase's combat events
#   detonate_by_hero {hero_id: int}     Detonate burst each hero lands
#   enemy_events / tick_events          the enemy phase's and the tick's events
#   pre_tick        {state_id: state}   every unit's state copy after the enemy phase
#   end             {state_id: state}   every unit's state copy after the tick
func _forecast_hero_phase() -> Dictionary:
	var forecast: Dictionary = {
		"dead_enemy_ids": {},
		"lured": {},
		"taunter_id": "",
		"leech_by_hero": {},
		"after": {},
		"events": [],
		"detonate_by_hero": {},
		"enemy_events": [],
		"tick_events": [],
		"pre_tick": {},
		"end": {},
	}
	var cm: CombatManager = _scene.combat_manager
	var hero_rolls: Dictionary = {}
	var raw_hero_rolls: Dictionary = {}
	var waiting: Dictionary = {}
	var revealed_heroes: Dictionary = _revealed_rolls("hero")
	for hero_variant in cm.get_hero_states():
		var hero_state: Dictionary = hero_variant
		var hero_id: String = str(hero_state["id"])
		if bool(hero_state.get("dead", false)) or not revealed_heroes.has(hero_id):
			continue
		var eff: int = _scene._get_effective_roll_for_state(hero_state, hero_id)
		var entry: Dictionary = _scene.dice_manager.get_ability_for_roll(hero_state["unit"], eff)
		if str(hero_state.get("selected_target_id", "")) == "" and _scene._get_manual_target_side(entry) != "":
			waiting[hero_id] = true
		hero_rolls[hero_id] = eff
		raw_hero_rolls[hero_id] = int(revealed_heroes[hero_id])
	var enemy_rolls: Dictionary = {}
	var revealed_enemies: Dictionary = _revealed_rolls("enemy")
	for enemy_variant in cm.get_enemy_states():
		var enemy_state: Dictionary = enemy_variant
		var enemy_id: String = str(enemy_state["id"])
		if bool(enemy_state.get("dead", false)) or not revealed_enemies.has(enemy_id):
			continue
		enemy_rolls[enemy_id] = _scene._get_effective_enemy_roll(enemy_state, enemy_id)
	if hero_rolls.is_empty() and enemy_rolls.is_empty():
		for state_variant in cm.get_hero_states() + cm.get_enemy_states():
			var live: Dictionary = state_variant
			forecast["after"][str(live["id"])] = live
		forecast["pre_tick"] = forecast["after"]
		forecast["end"] = forecast["after"]
	else:
		cm.protocol_pool = _scene.protocol_points  # Redline reads it, in the forecast as in the round
		var run: Dictionary = cm.forecast_round(hero_rolls, enemy_rolls, _scene.dice_manager, raw_hero_rolls, waiting)
		for state_variant in (run["hero_states"] as Array) + (run["enemy_states"] as Array):
			var after_state: Dictionary = state_variant
			forecast["after"][str(after_state["id"])] = after_state
		for key in ["events", "detonate_by_hero", "enemy_events", "tick_events", "pre_tick", "end"]:
			forecast[key] = run[key]

	var dead_map: Dictionary = forecast["dead_enemy_ids"]
	var lure_map: Dictionary = forecast["lured"]
	for enemy_variant in cm.get_enemy_states():
		var enemy_id: String = str((enemy_variant as Dictionary)["id"])
		var after_enemy: Dictionary = forecast["after"].get(enemy_id, {})
		if after_enemy.is_empty():
			continue
		if bool(after_enemy.get("dead", false)) and not bool((enemy_variant as Dictionary).get("dead", false)):
			dead_map[enemy_id] = true
		var lured_by: String = str(after_enemy.get("lured_by_id", ""))
		if lured_by != "":
			lure_map[enemy_id] = lured_by
	var leech_map: Dictionary = forecast["leech_by_hero"]
	for event_variant in forecast["events"]:
		var event: Dictionary = event_variant
		if str(event.get("type", "")) == "leech":
			var leecher: String = str(event.get("target_id", ""))
			leech_map[leecher] = int(leech_map.get(leecher, 0)) + int(event.get("amount", 0))

	# Anchor Frame gear: a standing aura, not a cast — already live on the board,
	# redirecting EVERY enemy's single-target pick while its holder is above half
	# HP (combat_manager._get_taunting_hero_state). Read after the hero phase.
	for hero_variant in cm.get_hero_states():
		var aura_state: Dictionary = forecast["after"].get(str((hero_variant as Dictionary)["id"]), hero_variant)
		if bool(aura_state.get("dead", false)) or not bool(aura_state.get("gear_anchor_taunt", false)):
			continue
		if int(aura_state.get("current_hp", 0)) * 2 > int(aura_state.get("max_hp", 1)):
			forecast["taunter_id"] = str(aura_state["id"])
			break
	return forecast


# Sums one unit's events of the given types from a forecast. `phases` names the
# event lists to read: "events" is the hero phase, "enemy_events" the enemy
# phase, "tick_events" the end-of-round tick.
func _forecast_event_total(forecast: Dictionary, unit_id: String, types: Array, phases: Array = ["events"]) -> int:
	var total: int = 0
	for phase in phases:
		for event_variant in forecast.get(phase, []):
			var event: Dictionary = event_variant
			if str(event.get("target_id", "")) == unit_id and types.has(str(event.get("type", ""))):
				total += int(event.get("amount", 0))
	return total


# Where the dry run leaves a unit when the round is over, for the card's bar:
#   final_hp     its HP after the hero phase, the enemy phase and the tick (0 dead)
#   pre_tick_hp  its HP after the enemy phase, before the tick (0 dead)
#   lethal       it is alive now and the round kills it
#   pre_tick     its state copy as the tick will find it
# Read off the real round, so the bar ends where the round will end it.
func _forecast_round_end(target_state: Dictionary, forecast: Dictionary) -> Dictionary:
	var target_id: String = str(target_state["id"])
	var pre_tick: Dictionary = forecast["pre_tick"].get(target_id, target_state)
	var end: Dictionary = forecast["end"].get(target_id, target_state)
	var end_dead: bool = bool(end.get("dead", false))
	var pre_tick_hp: int = 0 if bool(pre_tick.get("dead", false)) else int(pre_tick.get("current_hp", 0))
	var final_hp: int = 0 if end_dead else int(end.get("current_hp", 0))
	return {
		"final_hp": final_hp,
		"pre_tick_hp": pre_tick_hp,
		"lethal": end_dead and not bool(target_state.get("dead", false)),
		"pre_tick": pre_tick,
	}


func compute_preview_for_unit(target_state: Dictionary, is_hero: bool) -> Dictionary:
	# Preview only makes sense once rolls/targets exist. Targeting and the
	# pre-end-turn ready state are the obvious cases; the *_pick phases
	# (reroll/nudge/item) are sub-modes layered on top of those, where the
	# underlying rolls and target assignments are unchanged — opening the
	# picker shouldn't visually erase damage red. The preview will naturally
	# recompute once a pick actually mutates state (new roll, nudged tier,
	# item-applied HP/shield).
	match _scene.turn_phase:
		_scene.PHASE_TARGETING, _scene.PHASE_READY_TO_END, \
		_scene.PHASE_REROLL_PICK, _scene.PHASE_NUDGE_PICK, _scene.PHASE_SET_PICK, \
		_scene.PHASE_ITEM_PICK_ALLY, _scene.PHASE_ITEM_PICK_DEAD, _scene.PHASE_ITEM_PICK_ENEMY, \
		_scene.PHASE_ITEM_PICK_ANY:
			pass
		_:
			return {}
	# §3 (Batch 4): preview at ability-resolution time. An ability contributes to a
	# unit's preview as soon as its target is DETERMINED — AoE (hits its whole
	# side) or a single-target whose selected_target_id is set, whether the player
	# picked it or it auto-resolved (the only legal target). There is deliberately
	# NO dependency on the player having committed a manual pick; the
	# hero_target == target_id check below is the only gate single-target needs
	# (an un-targeted ability has selected_target_id == "" and matches nothing).
	var target_id: String = str(target_state["id"])
	# Walk the hero phase first: heroes resolve BEFORE enemies, so which enemies
	# are still standing to act, and who they are still allowed to hit, both
	# depend on the assignment the player is looking at right now.
	var forecast: Dictionary = _forecast_hero_phase()
	if is_hero:
		return _hero_preview(target_state, forecast)
	return _enemy_preview(target_state, forecast)


# An enemy card: what the hero phase does to it is read straight off the dry
# run (HP lost, shield left, dead or not, every keyword and rider included).
# Where its bar ends is the dry run's end of the round, so its own heal, a
# spike it runs into, a Fervent heal and the burn tick are all in it.
func _enemy_preview(target_state: Dictionary, forecast: Dictionary) -> Dictionary:
	var target_id: String = str(target_state["id"])
	var after: Dictionary = forecast["after"].get(target_id, target_state)
	var round_end: Dictionary = _forecast_round_end(target_state, forecast)
	var cur_hp: int = int(target_state.get("current_hp", 0))
	var cur_shield: int = int(target_state.get("shield", 0))
	var hp_loss: int = maxi(cur_hp - int(after.get("current_hp", cur_hp)), 0)
	var shield_left: int = int(after.get("shield", cur_shield))
	var blocked: int = _forecast_event_total(forecast, target_id, ["block"])
	var dies: bool = bool(round_end["lethal"])
	# Heals from the enemy phase and the tick. Shield previews are intentionally
	# omitted: enemies act AFTER heroes, so a shield the enemy is about to cast
	# cannot absorb hero damage this turn; it only becomes an active status
	# next turn.
	var total_heal: int = _forecast_event_total(forecast, target_id, ["heal"], ["enemy_events", "tick_events"])
	# Burn: exactly what _tick_state will deal this round, read on the state
	# the tick will find (a Detonate consumes finite Burn, a new Burn may have
	# landed). Single-sourced from combat_manager.
	var pre_tick: Dictionary = round_end["pre_tick"]
	var active_burn: int = 0 if bool(pre_tick.get("dead", false)) else _scene.combat_manager.get_expected_burn_tick(pre_tick)
	if hp_loss <= 0 and blocked <= 0 and shield_left == cur_shield and not dies \
			and total_heal <= 0 and active_burn <= 0 and int(round_end["final_hp"]) == cur_hp:
		return {}
	return {
		"damage":          hp_loss + blocked,
		"hp_loss":         hp_loss,
		"shield_after":    shield_left,
		"blocked":         blocked,
		"heal":            total_heal,
		"shield":          0,
		"burn":            active_burn,
		"burn_pierce":     0 if bool(pre_tick.get("dead", false)) else _scene.combat_manager.get_expected_burn_tick_pierce(pre_tick),
		"current_shield":  cur_shield,
		"lethal":          dies,
		"final_hp":        int(round_end["final_hp"]),
		# The burn tick's share of the loss. Never more than the burn that
		# ticks: other HP lost at the tick (a Volatile death) is a hit.
		"burn_hp":         clampi(int(round_end["pre_tick_hp"]) - int(round_end["final_hp"]), 0, active_burn),
	}


# A hero card: everything the round does to this hero comes off the dry run.
# The hero phase's heals, leech, shields, spike retaliation and every other
# hit; the enemy phase's hits as they land (a taunt's redirect, an ambush, a
# rampage, a pack bonus, Anchored's cut); the end-of-round tick.
func _hero_preview(target_state: Dictionary, forecast: Dictionary) -> Dictionary:
	var target_id: String = str(target_state["id"])
	var round_end: Dictionary = _forecast_round_end(target_state, forecast)
	var total_heal: int = _forecast_event_total(forecast, target_id, ["heal"], ["events", "enemy_events", "tick_events"])
	var total_shield: int = _forecast_event_total(forecast, target_id, ["shield"])
	var total_dmg: int = _forecast_event_total(forecast, target_id, ["damage", "block"], ["events", "enemy_events"])
	var pre_tick: Dictionary = round_end["pre_tick"]
	var active_burn: int = 0 if bool(pre_tick.get("dead", false)) else _scene.combat_manager.get_expected_burn_tick(pre_tick)
	if total_heal <= 0 and total_shield <= 0 and total_dmg <= 0 and active_burn <= 0 \
			and int(round_end["final_hp"]) == int(target_state.get("current_hp", 0)):
		return {}
	return {
		"damage":          total_dmg,
		"heal":            total_heal,
		"shield":          total_shield,
		"burn":            active_burn,
		"burn_pierce":     0 if bool(pre_tick.get("dead", false)) else _scene.combat_manager.get_expected_burn_tick_pierce(pre_tick),
		"current_shield":  int(target_state.get("shield", 0)),
		"lethal":          bool(round_end["lethal"]),
		"final_hp":        int(round_end["final_hp"]),
		# The burn tick's share of the loss. Never more than the burn that
		# ticks: other HP lost at the tick (a Volatile death) is a hit.
		"burn_hp":         clampi(int(round_end["pre_tick_hp"]) - int(round_end["final_hp"]), 0, active_burn),
	}


func get_gear_detail_rows(unit_id: String) -> Array:
	var gear_rows: Array = []
	var gear_ids: Array = _game_state().gear_by_unit.get(unit_id, [])
	for gear_id_variant in gear_ids:
		var item: ItemData = _data_manager().get_item(str(gear_id_variant)) as ItemData
		if item == null:
			continue
		gear_rows.append({
			"name": item.display_name,
			"description": item.description,
		})
	return gear_rows


# ── Internal helpers ──────────────────────────────────────────────────────────

# pkg8.2: Detonate pip live value once the target is known. Since B1 (UI batch
# 2026-09-27) it is the burst the hero phase dry run actually lands, so a Burn
# an earlier hero adds this round, a Payload Fuse bonus or an Overload Loop echo
# are all in the number, and the readout, the enemy's preview and the resolved
# damage agree.
func _patch_live_detonate_value(action_pips: Dictionary, hero_state: Dictionary, chosen_entry: Dictionary) -> void:
	var raw: Dictionary = chosen_entry.get("raw", {})
	if not bool(raw.get("detonate", false)):
		return
	if str(hero_state.get("selected_target_id", "")) == "":
		return
	var forecast: Dictionary = _forecast_hero_phase()
	var burst: int = int((forecast["detonate_by_hero"] as Dictionary).get(str(hero_state["id"]), 0))
	for effect_variant in action_pips.get("effects", []):
		var effect: Dictionary = effect_variant
		if str(effect.get("kind", "")) == "detonate":
			var dt_code: String = EffectPip.keyword_code("detonate", "DT")
			# "DT9", the SP3 / SI2 shape: code then number, no space (B2).
			effect["value"] = "%s%d" % [dt_code, burst] if burst > 0 else dt_code


# Build J Item 1 (presentation only): live chip tokens, with SNAPSHOT values
# substituted for chip types whose causing action hasn't played its beat yet
# (BattleFeedback owns the suppression plan; empty plan = plain live tokens,
# which is every skip/auto path and every idle refresh). Canonical chip order
# keeps the row deterministic across the substitution.
func _composed_status_tokens(state: Dictionary) -> Array:
	var live: Array = _build_compact_status_tokens(state)
	var feedback: Variant = _scene.get("_feedback")
	if feedback == null or not is_instance_valid(feedback):
		return live
	var suppressed: Dictionary = feedback.suppressed_chip_types(str(state.get("id", "")))
	# Transient chips (THE COURT, 2026-09-02): granted AND consumed inside one
	# resolve, so they are in neither `live` nor the snapshot. BattleFeedback
	# hands them over only for the beats they were actually up.
	var injected: Array = feedback.injected_chip_tokens(str(state.get("id", "")))
	# The shield at the current beat (BattleFeedback._beat_shield), once one of
	# this unit's events has played: it replaces the shield chip's value.
	var beat_shield: int = feedback.beat_shield_for(str(state.get("id", "")))
	if bool(state.get("dead", false)):
		beat_shield = -1
	if suppressed.is_empty() and injected.is_empty() and beat_shield < 0:
		return live
	var merged: Dictionary = {}
	for token_variant in live:
		var token: Dictionary = token_variant
		if not suppressed.has(str(token.get("type", ""))):
			merged[str(token.get("type", ""))] = token
	for token_variant in feedback.snapshot_tokens_for(str(state.get("id", ""))):
		var token: Dictionary = token_variant
		if suppressed.has(str(token.get("type", ""))):
			merged[str(token.get("type", ""))] = token
	# Injection FILLS GAPS ONLY — live and snapshot always win, so a ward that
	# outlives its round (the Aegis ally) is rendered from state as before and
	# this can never mask or duplicate real state.
	for token_variant in injected:
		var token: Dictionary = token_variant
		if not merged.has(str(token.get("type", ""))):
			merged[str(token.get("type", ""))] = token
	if beat_shield == 0:
		merged.erase("shield")
	elif beat_shield > 0:
		merged["shield"] = {"type": "shield", "mode": "numeric", "icon": "S", "value": beat_shield, "priority": 1}
	var out: Array = []
	for chip_type in feedback.CHIP_CANONICAL_ORDER:
		if merged.has(chip_type):
			out.append(merged[chip_type])
	# Anything outside the canonical list (named/future chips) rides at the end.
	for chip_type in merged.keys():
		if not feedback.CHIP_CANONICAL_ORDER.has(chip_type):
			out.append(merged[chip_type])
	return out


# A taunt picked this planning phase (playtest 2026-10-01: Sentinel's taunt
# "didn't work" because nothing showed it before End Turn). The TAUNT chip
# shows on the chosen enemy as soon as the pick lands. It is read off the
# hero-phase dry run, so a Firewall that will eat the taunt shows no chip.
func _planned_taunt_on(state: Dictionary) -> bool:
	if _scene.turn_phase != _scene.PHASE_TARGETING and _scene.turn_phase != _scene.PHASE_READY_TO_END:
		return false
	var enemy_id: String = str(state.get("id", ""))
	var picked: bool = false
	for hero_state in _scene.combat_manager.get_hero_states():
		if not bool(hero_state.get("dead", false)) and str(hero_state.get("selected_target_id", "")) == enemy_id:
			picked = true
			break
	if not picked:
		return false
	return str((_forecast_hero_phase()["lured"] as Dictionary).get(enemy_id, "")) != ""


func _build_compact_status_tokens(state: Dictionary) -> Array:
	var statuses: Array = []
	if bool(state.get("dead", false)):
		# No DOWN chip (Kev 2026-07-10) — the grayed portrait carries it.
		return statuses

	# Chip doctrine (pkg8.1, amended): the card chip row renders Burn, SHIELD,
	# Mark, ±Roll, Firewall, and Taunt. The Shield chip is RESTORED per Kev
	# 2026-07-06 (DECISIONS_RESOLVED #16 — reverses the pkg8.1 cut): the active
	# shield total is a visible primary chip on BOTH sides, live on grant /
	# break / expiry (state-driven: event refreshes + the per-side expiry tick
	# mutate state["shield"], cards re-read it). Everything else keeps its own
	# display channel — cloak as the ghosted portrait, freeze/jam/rewrite/
	# hijack on the die, spike in the readout. HP preview behavior unchanged.
	if int(state.get("burn", 0)) > 0 and int(state.get("burn_turns", 0)) > 0:
		statuses.append({
			"type": "burn",
			"mode": "numeric",
			"icon": "B",
			"value": int(state.get("burn", 0)),
			"priority": 0,
		})

	if int(state.get("shield", 0)) > 0:
		statuses.append({
			"type": "shield",
			"mode": "numeric",
			"icon": "S",
			"value": int(state.get("shield", 0)),
			"priority": 1,
		})

	if bool(state.get("marked", false)):
		statuses.append(_make_compact_icon_status("mark", 1))

	# Net roll modifier from the ONE source (combat_manager.get_roll_modifier_totals:
	# temporary stacks plus the permanent relic/gear modifiers). This used to be a
	# hand-kept mirror of that sum — the same kind of copy that let the die show a
	# face the unit didn't act on (P0 dice-face audit).
	var roll_mods: Dictionary = CombatManager.roll_modifier_totals_of(state)
	var roll_delta: int = int(roll_mods["roll_buff"]) - int(roll_mods["roll_rfe"])
	if roll_delta != 0:
		statuses.append({
			"type": "roll",
			"mode": "numeric",
			"icon": "",
			"value": "%+d" % roll_delta,
			"priority": 2,
		})

	if bool(state.get("warded", false)):
		statuses.append(_make_compact_icon_status("firewall", 3))

	# Taunted unit (internal lured_by state, BOTH directions since G-4): its
	# targeting is restricted to the taunter — the chip makes the restriction
	# legible on the unit that carries it (a lured hero or a hero-taunted enemy).
	if str(state.get("lured_by_id", "")) != "" or _planned_taunt_on(state):
		statuses.append(_make_compact_icon_status("taunt", 3))

	# Kev 2026-07-10: the chip TYPE limit is lifted — every active status gets a
	# chip (the row still visually caps and overflows into the "+N" badge; the
	# full list lives in the unit long-press). Cloak / Jam / Rewrite / Spike:
	# A cloaked unit's next attack is an ambush (G-52): the chip carries the
	# bonus beside the cloak icon, for as long as the cloak is up.
	if CombatManager.ambush_ready(state) and CombatManager.cloak_ambush_break() != "no_chip":
		statuses.append({
			"type": "cloak",
			"mode": "numeric",
			"icon": "C",
			"value": CombatManager.ambush_chip_text(_scene.combat_manager.ambush_mult()),
			"priority": 3,
		})
	elif bool(state.get("cloaked", false)):
		statuses.append(_make_compact_icon_status("cloak", 3))
	# Rampage (a charged enemy's next hit doubles): icon only.
	if int(state.get("rampage_charges", 0)) > 0:
		statuses.append(_make_compact_icon_status("rampage", 3))
	if int(state.get("jam_cap", 0)) > 0:
		statuses.append(_make_compact_icon_status("jam", 3))
	if bool(state.get("rewrite_pending", false)):
		statuses.append(_make_compact_icon_status("rewrite", 3))
	var spike_value: int = int(state.get("spike", 0))
	if spike_value > 0:
		statuses.append({
			"type": "spike",
			"mode": "numeric",
			"icon": "SP",
			"value": spike_value,
			"priority": 3,
		})

	return statuses


func _make_compact_named_status(display_name: String, value: String = "", priority: int = 3) -> Dictionary:
	return {
		"type": "named",
		"mode": "named",
		"name": display_name,
		"value": value,
		"priority": priority,
	}


# Keyword status shown as its pip icon (batch 155-179): mark / firewall / taunt.
# mode "icon" → compact_unit_card.build_status_chip draws the icon only.
func _make_compact_icon_status(status_type: String, priority: int = 3) -> Dictionary:
	return {
		"type": status_type,
		"mode": "icon",
		"priority": priority,
	}
