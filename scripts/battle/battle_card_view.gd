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

	if int(state["poison"]) > 0 and int(state.get("poison_turns", 0)) > 0:
		status_list.append("POI %d ×%dt" % [int(state["poison"]), int(state["poison_turns"])])

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
	if int(state.get("cower_turns", 0)) > 0:
		status_list.append("COWER %d" % int(state["cower_turns"]))
	if int(state.get("die_freeze_turns", 0)) > 0:
		status_list.append("FROZEN %d" % int(state["die_freeze_turns"]))
	if int(state.get("rampage_charges", 0)) > 0:
		status_list.append("RAGE ×%d" % int(state["rampage_charges"]))
	if bool(state.get("cursed", false)):
		status_list.append("CURSED")
	if bool(state.get("taunting", false)):
		status_list.append("TAUNT")
	if int(state.get("counter_pct", 0)) > 0:
		status_list.append("CNTR %d%%" % int(state["counter_pct"]))
	if bool(state.get("in_phase_two", false)):
		status_list.append("PHASE 2")

	if bool(show_dead):
		status_list.append("DOWN")

	var state_id: String = str(state["id"])
	var is_selected: bool = state_id == _scene.active_targeting_hero_id
	var is_targetable: bool = _scene._is_target_highlight_phase() and _scene.legal_target_ids.has(state_id)
	var is_target_locked: bool = false
	var needs_manual_target: bool = false
	if accent_color == _scene.HERO_ACCENT and not show_dead and roll_value != null:
		if _scene.turn_phase == _scene.PHASE_TARGETING or _scene.turn_phase == _scene.PHASE_READY_TO_END:
			needs_manual_target = _scene.pending_manual_target_ids.has(state_id)
			if state_id != _scene.active_targeting_hero_id:
				is_target_locked = not needs_manual_target
	if card is CompactUnitCard:
		var compact_card: CompactUnitCard = card as CompactUnitCard
		var has_revealed_roll: bool = roll_value != null
		var action_label: String = "DOWN" if show_dead else "AWAIT ROLL"
		var action_pips: Variant = []
		if has_revealed_roll:
			action_label = str(chosen_entry.get("ability_name", "NO ACTION"))
			action_pips = EffectPip.ability_readout_payload(
				chosen_entry.get("raw", chosen_entry) as Dictionary,
				"hero" if accent_color == _scene.HERO_ACCENT else "enemy"
			)
		if readout != null and readout.has_method("configure"):
			readout.configure(action_pips, "hero" if accent_color == _scene.HERO_ACCENT else "enemy")
		var card_pips: Array = []
		if readout == null and action_pips is Dictionary:
			card_pips = action_pips.get("effects", [])
		compact_card.configure({
			"side": "hero" if accent_color == _scene.HERO_ACCENT else "enemy",
			"name": unit.battle_name(),
			"current_hp": shown_hp,
			"forecast_hp": forecast_hp,
			"max_hp": int(state["max_hp"]),
			"action": action_label,
			"pips": card_pips,
			"portrait": unit.portrait,
			"statuses": _build_compact_status_tokens(state),
			"selected": is_selected,
			"targetable": is_targetable,
			"interaction_enabled": _scene._is_card_clickable(state, accent_color),
			"dead": show_dead,
			"target_locked": is_target_locked,
			"needs_manual_target": needs_manual_target,
			"show_action_pips": readout == null,
			"unit_data": unit,
			"gear_rows": get_gear_detail_rows(str(unit.id)) if unit is UnitData else [],
		})
		var compact_preview: Dictionary = compute_preview_for_unit(state, accent_color == _scene.HERO_ACCENT)
		if compact_preview.is_empty():
			compact_card.clear_combat_preview()
		else:
			compact_card.show_combat_preview(compact_preview)


func refresh_all_cards() -> void:
	for hero_view in _scene.hero_card_views:
		var hero_state: Dictionary = hero_view["state"]
		var readout: Control = hero_view.get("readout", null) as Control
		update_card_view(hero_view["card"], hero_state, _scene.hero_rolls.get(str(hero_state["id"]), null), _scene.HERO_ACCENT, readout)

	for enemy_view in _scene.enemy_card_views:
		var enemy_state: Dictionary = enemy_view["state"]
		var readout: Control = enemy_view.get("readout", null) as Control
		update_card_view(enemy_view["card"], enemy_state, _scene.enemy_rolls.get(str(enemy_state["id"]), null), _scene.ENEMY_ACCENT, readout)


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
	var rolls: Dictionary = _scene.hero_rolls if side == "hero" else _scene.enemy_rolls
	for view_variant in views:
		var view: Dictionary = view_variant
		var state: Dictionary = view["state"]
		if str(state.get("id", "")) != target_id:
			continue
		var readout: Control = view.get("readout", null) as Control
		update_card_view(view["card"], state, rolls.get(target_id, null), accent, readout, int(event.get("hp_after", -1)))
		return


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
		_scene.PHASE_ITEM_PICK_ALLY, _scene.PHASE_ITEM_PICK_DEAD, _scene.PHASE_ITEM_PICK_ENEMY:
			pass
		_:
			return {}
	# Hero ability previews require *some* committed targeting context: either
	# we're past targeting (READY_TO_END), or the player has assigned at least
	# one target this turn. Pick sub-modes inherit that context from the phase
	# they were opened from, so this check still works without a special case.
	var include_hero_ability_previews: bool = \
		_scene.turn_phase == _scene.PHASE_READY_TO_END \
		or _scene.has_player_target_assignment

	var target_id: String = str(target_state["id"])
	var total_dmg: int    = 0
	var total_heal: int   = 0
	var total_shield: int = 0
	var found: bool = false

	# ── Hero abilities ────────────────────────────────────────────────────────
	for hero_state in _scene.combat_manager.get_hero_states():
		if not include_hero_ability_previews:
			continue
		if bool(hero_state.get("dead", false)):
			continue
		var hero_id: String = str(hero_state["id"])
		if not _scene.hero_rolls.has(hero_id):
			continue
		var eff: int = _scene._get_effective_roll_for_state(hero_state, hero_id)
		var entry: Dictionary = _scene.dice_manager.get_ability_for_roll(hero_state["unit"], eff)
		if entry.is_empty():
			continue
		var raw: Dictionary     = entry.get("raw", {})
		var hero_target: String = str(hero_state.get("selected_target_id", ""))
		var blast_all: bool     = bool(raw.get("blastAll", false))
		var heal_all: bool      = bool(raw.get("healAll", false))
		var shield_all: bool    = bool(raw.get("shieldAll", false))

		var hits_this: bool = false
		if not is_hero:
			if blast_all:
				hits_this = true
			elif hero_target == target_id and int(raw.get("dmg", 0)) > 0:
				hits_this = true
		if is_hero:
			if heal_all or shield_all:
				hits_this = true
			elif hero_target == target_id and (int(raw.get("heal", 0)) > 0 or int(raw.get("shield", 0)) > 0):
				hits_this = true

		if not hits_this:
			continue
		found = true
		if not is_hero:
			total_dmg += int(raw.get("dmg", 0))
		if is_hero:
			total_heal   += int(raw.get("heal", 0))
			total_shield += int(raw.get("shield", 0))

	# ── Enemy abilities ───────────────────────────────────────────────────────
	for enemy_state in _scene.combat_manager.get_enemy_states():
		if bool(enemy_state.get("dead", false)):
			continue
		var enemy_id: String = str(enemy_state["id"])
		if not _scene.enemy_rolls.has(enemy_id):
			continue
		var eff: int = _scene._get_effective_enemy_roll(enemy_state, enemy_id)
		var entry: Dictionary = _scene.dice_manager.get_ability_for_roll(enemy_state["unit"], eff)
		if entry.is_empty():
			continue
		var raw: Dictionary   = entry.get("raw", {})
		var e_target: String  = str(enemy_state.get("selected_target_id", ""))
		var e_blast: bool     = bool(raw.get("blastAll", false))

		if is_hero:
			var hits_hero: bool = e_blast or e_target == target_id
			if hits_hero and int(raw.get("dmg", 0)) > 0:
				found = true
				total_dmg += int(raw.get("dmg", 0))

		if not is_hero and e_target == target_id:
			# Heal previews fine (informational about end-of-turn HP). Shield
			# previews are intentionally omitted: enemies act AFTER heroes,
			# so a shield the enemy is about to cast cannot absorb hero damage
			# this turn — it only becomes an active status next turn.
			var self_heal: int = int(raw.get("heal", 0))
			if self_heal > 0:
				found = true
				total_heal += self_heal

	# ── DoT: show only when BOTH poison > 0 AND poison_turns > 0 ─────────────
	# This mirrors combat_manager._tick_state exactly — both must be nonzero
	# for the tick to fire this round.
	var active_dot: int = 0
	if int(target_state.get("poison", 0)) > 0 and int(target_state.get("poison_turns", 0)) > 0:
		active_dot = int(target_state.get("poison", 0))
		found = true

	if not found:
		return {}

	# ── Shield availability ───────────────────────────────────────────────────
	# Both heroes and enemies have their existing shield stacks applied BEFORE
	# damage resolves (combat_manager._damage_state absorbs from shield_stacks).
	# For enemies the catch is that any shield they're about to cast THIS turn
	# is not yet active when heroes attack, so we only count pre-existing stacks
	# (their current shield total). Heroes likewise use their current shield
	# plus any incoming shield from this turn's hero rolls (already aggregated
	# above into total_shield), so the existing-shield contribution comes from
	# state["shield"] for both sides.
	var effective_shield: int = int(target_state.get("shield", 0))

	# ── Lethal check (enemy units only) ──────────────────────────────────────
	# If total player damage is enough to kill the enemy, flag it so the card
	# can render the entire HP fill as red. Account for the enemy's existing
	# shield stacks since those absorb damage before HP is reduced.
	var lethal: bool = false
	if not is_hero:
		lethal = total_dmg >= int(target_state.get("current_hp", 0)) + effective_shield

	return {
		"damage":          total_dmg,
		"heal":            total_heal,
		"shield":          total_shield,
		"dot":             active_dot,
		"current_shield":  effective_shield,
		"lethal":          lethal,
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


func build_ability_chart_rows(unit: Resource) -> Array:
	var is_hero_unit: bool = unit is UnitData
	var zone_ranges: Dictionary = {}
	if is_hero_unit:
		var hero_unit: UnitData = unit as UnitData
		zone_ranges = _data_manager().get_hero_zone_ranges(hero_unit.source_key)
	var overload_entry: Dictionary = {}
	for entry_variant in unit.dice_ranges:
		var entry: Dictionary = entry_variant
		if str(entry.get("zone", "")) == "overload":
			overload_entry = entry
			break
	var rows: Array = []
	for entry_variant in unit.dice_ranges:
		var entry: Dictionary = entry_variant
		var zone: String = str(entry.get("zone", ""))
		if is_hero_unit and zone == "overload":
			continue
		var min_roll: int = int(entry.get("min", 0))
		var max_roll: int = int(entry.get("max", 0))
		if is_hero_unit and zone_ranges.has(zone):
			var zone_range: Vector2i = zone_ranges[zone]
			min_roll = zone_range.x
			max_roll = zone_range.y
		if is_hero_unit and zone == "crit" and not overload_entry.is_empty():
			var overload_max: int = int(overload_entry.get("max", max_roll))
			if zone_ranges.has("overload"):
				overload_max = int((zone_ranges["overload"] as Vector2i).y)
			max_roll = maxi(max_roll, overload_max)
		var range_text: String = str(min_roll) if min_roll == max_roll else "%d-%d" % [min_roll, max_roll]
		var raw: Dictionary = entry.get("raw", {})
		var row: Dictionary = {
			"zone": zone,
			"range_text": range_text,
			"ability_name": str(entry.get("ability_name", "")),
			"description": _build_ability_row_description(entry),
			"chips": build_effect_chips(raw),
		}
		if is_hero_unit and zone == "crit" and not overload_entry.is_empty():
			row["has_overload_marker"] = true
			row["overload_ability_name"] = str(overload_entry.get("ability_name", ""))
			row["overload_description"] = _build_ability_row_description(overload_entry)
			row["overload_chips"] = build_effect_chips(overload_entry.get("raw", {}))
		rows.append(row)
	return rows


func build_effect_chips(raw: Dictionary) -> Array:
	var chips: Array = []
	var damage: int = int(raw.get("dmg", 0))
	var shield: int = int(raw.get("shield", 0))
	var shield_ally: int = int(raw.get("shieldAlly", 0))
	var heal: int = int(raw.get("heal", 0))
	var lifesteal_pct: int = int(raw.get("lifestealPct", 0))
	var dot: int = int(raw.get("dot", 0))
	var roll_mod: int = int(raw.get("rfe", 0))
	var freeze_turns: int = maxi(maxi(int(raw.get("freezeEnemyDice", 0)), int(raw.get("freezeAllEnemyDice", 0))), int(raw.get("freezeAnyDice", 0)))
	var shield_turns: int = int(raw.get("shT", 1))
	var ally_shield_turns: int = int(raw.get("shAllyT", shield_turns))
	var dot_turns: int = int(raw.get("dT", 0))
	var roll_mod_turns: int = int(raw.get("rfT", 1))

	if damage > 0:
		chips.append(_make_effect_chip("✦", "%d" % damage, Color(0.53, 0.20, 0.18, 0.98), Color(1.0, 0.50, 0.42, 0.95), "deals %d damage" % damage))
	if shield > 0 and not bool(raw.get("shieldAllyAll", false)):
		chips.append(_make_effect_chip("⬢", "%d" % shield, Color(0.15, 0.32, 0.50, 0.98), Color(0.58, 0.82, 1.0, 0.95), "grants %d shield for %d turn%s" % [shield, shield_turns, "" if shield_turns == 1 else "s"], shield_turns))
	if roll_mod > 0:
		chips.append(_make_effect_chip("◫", "-%d" % roll_mod, Color(0.46, 0.34, 0.14, 0.98), Color(0.96, 0.78, 0.42, 0.95), "Shift die roll by -%d." % roll_mod, roll_mod_turns))
	var rfm: int = int(raw.get("rfm", 0))
	if rfm != 0:
		var rfm_text: String = "+%d" % rfm if rfm > 0 else "%d" % rfm
		var rfm_bg: Color = Color(0.12, 0.38, 0.23, 0.98) if rfm > 0 else Color(0.46, 0.34, 0.14, 0.98)
		var rfm_border: Color = Color(0.52, 1.0, 0.68, 0.95) if rfm > 0 else Color(0.96, 0.78, 0.42, 0.95)
		var rfm_tip: String = "Increase die roll by %d." % rfm if rfm > 0 else "Shift die roll by %d." % rfm
		chips.append(_make_effect_chip("◫", rfm_text, rfm_bg, rfm_border, rfm_tip, int(raw.get("rfmT", 1))))
	if bool(raw.get("shieldAllyAll", false)) and shield_ally > 0:
		chips.append(_make_effect_chip("⬢", "%d" % shield_ally, Color(0.15, 0.32, 0.50, 0.98), Color(0.58, 0.82, 1.0, 0.95), "grants %d shield to all allies for %d turn%s" % [shield_ally, ally_shield_turns, "" if ally_shield_turns == 1 else "s"], ally_shield_turns))
	elif shield_ally > 0:
		chips.append(_make_effect_chip("⬢", "%d" % shield_ally, Color(0.15, 0.32, 0.50, 0.98), Color(0.58, 0.82, 1.0, 0.95), "grants %d shield to an ally for %d turn%s" % [shield_ally, ally_shield_turns, "" if ally_shield_turns == 1 else "s"], ally_shield_turns))
	if heal > 0:
		chips.append(_make_effect_chip("✚", "%d" % heal, Color(0.12, 0.38, 0.23, 0.98), Color(0.52, 1.0, 0.68, 0.95), "restores %d health" % heal))
	if lifesteal_pct > 0:
		chips.append(_make_effect_chip("✚", "%d%%" % lifesteal_pct, Color(0.10, 0.32, 0.22, 0.98), Color(0.44, 1.0, 0.62, 0.95), "lifesteals %d%% of damage dealt — heals this unit for a portion of damage inflicted this turn" % lifesteal_pct))
	if dot > 0:
		chips.append(_make_effect_chip("◌", "%d" % dot, Color(0.43, 0.19, 0.22, 0.98), Color(1.0, 0.60, 0.64, 0.95), "inflicts %d poison for %d turn%s" % [dot, dot_turns, "" if dot_turns == 1 else "s"], dot_turns))
	if freeze_turns > 0:
		chips.append(_make_effect_chip("*", "%d" % freeze_turns, Color(0.12, 0.34, 0.48, 0.98), Color(0.62, 0.92, 1.0, 0.95), "freezes a die for %d reveal%s" % [freeze_turns, "" if freeze_turns == 1 else "s"], freeze_turns))
	if bool(raw.get("reviveAll", false)):
		var revive_all_pct: int = _revive_hp_pct_from_raw(raw)
		chips.append(_make_effect_chip("✚", "%d%%" % revive_all_pct, Color(0.10, 0.34, 0.24, 0.98), Color(0.58, 1.0, 0.72, 0.95), _revive_tooltip(raw, true)))
	elif bool(raw.get("revive", false)):
		var revive_pct: int = _revive_hp_pct_from_raw(raw)
		chips.append(_make_effect_chip("✚", "%d%%" % revive_pct, Color(0.10, 0.34, 0.24, 0.98), Color(0.58, 1.0, 0.72, 0.95), _revive_tooltip(raw, false)))
	return chips


# ── Internal helpers ──────────────────────────────────────────────────────────

func _build_compact_status_tokens(state: Dictionary) -> Array:
	var statuses: Array = []
	if bool(state.get("dead", false)):
		statuses.append(_make_compact_named_status("DOWN", "", 99))
		return statuses

	if int(state.get("poison", 0)) > 0 and int(state.get("poison_turns", 0)) > 0:
		statuses.append({
			"type": "poison",
			"mode": "numeric",
			"icon": "☠",
			"value": int(state.get("poison", 0)),
			"priority": 0,
		})

	var total_shield: int = int(state.get("shield", 0))
	if total_shield > 0:
		statuses.append({
			"type": "shield",
			"mode": "numeric",
			"icon": "🛡",
			"value": total_shield,
			"priority": 1,
		})

	var total_rfe: int = 0
	for stack_variant in state.get("rfe_stacks", []):
		var stack: Dictionary = stack_variant
		total_rfe += int(stack.get("amt", 0))
	var roll_buff: int = int(state.get("roll_buff", 0))
	var roll_delta: int = roll_buff - total_rfe
	if roll_delta != 0:
		statuses.append({
			"type": "roll",
			"mode": "numeric",
			"icon": "🎲",
			"value": "%+d" % roll_delta,
			"priority": 2,
		})

	if bool(state.get("cloaked", false)):
		statuses.append(_make_compact_named_status("CLOAK", "", 3))
	if int(state.get("cower_turns", 0)) > 0:
		statuses.append(_make_compact_named_status("COWER", "", 3))
	if int(state.get("rampage_charges", 0)) > 0:
		statuses.append(_make_compact_named_status("RAMPAGE", "%d" % int(state.get("rampage_charges", 0)), 3))

	return statuses


func _make_compact_named_status(display_name: String, value: String = "", priority: int = 3) -> Dictionary:
	return {
		"type": "named",
		"mode": "named",
		"name": display_name,
		"value": value,
		"priority": priority,
	}


func resolve_ability_target_scope(raw: Dictionary) -> String:
	if bool(raw.get("healAll", false)):
		return "ALL"
	if bool(raw.get("shieldAll", false)):
		return "ALL"
	if bool(raw.get("shieldAllyAll", false)):
		return "ALL"
	if bool(raw.get("erbAll", false)):
		return "ALL"
	if bool(raw.get("reviveAll", false)):
		return "ALL"
	if bool(raw.get("rfeAll", false)):
		return "ALL"
	if bool(raw.get("cloakAll", false)):
		return "ALL"
	var rfm: int = int(raw.get("rfm", 0))
	if rfm > 0 and not bool(raw.get("rfmTgt", false)):
		return "ALL"

	if bool(raw.get("taunt", false)):
		return "SELF"
	if bool(raw.get("cloak", false)) and not bool(raw.get("cloakAll", false)):
		return "SELF"
	var shield: int = int(raw.get("shield", 0))
	if shield > 0 and not bool(raw.get("shTgt", false)) and not bool(raw.get("shieldAll", false)) and not bool(raw.get("shieldAllyAll", false)):
		return "SELF"
	var heal: int = int(raw.get("heal", 0))
	if heal > 0 and not bool(raw.get("healTgt", false)) and not bool(raw.get("healAll", false)) and not bool(raw.get("healLowest", false)):
		return "SELF"

	# Ally-targeted heals/shields/revives need no badge — positive squad effects are assumed ally-targeted.
	if bool(raw.get("blastAll", false)) and int(raw.get("dmg", 0)) > 0:
		return "ALL"

	return ""


func _revive_hp_pct_from_raw(raw: Dictionary) -> int:
	return int(raw.get("revivePct", 50))


func _revive_tooltip(raw: Dictionary, all_allies: bool) -> String:
	var pct: int = _revive_hp_pct_from_raw(raw)
	if all_allies:
		return "revives all fallen allies at %d%% health" % pct
	return "revives a fallen ally at %d%% health" % pct


func _revive_description(raw: Dictionary) -> String:
	if bool(raw.get("reviveAll", false)):
		return "Revives all fallen allies at %d%% health." % _revive_hp_pct_from_raw(raw)
	if bool(raw.get("revive", false)):
		return "Revives a fallen ally at %d%% health." % _revive_hp_pct_from_raw(raw)
	return ""


func _build_ability_row_description(entry: Dictionary) -> String:
	var raw: Dictionary = entry.get("raw", {})
	var revive_desc: String = _revive_description(raw)
	if revive_desc != "":
		return revive_desc
	return str(entry.get("description", ""))


func _make_effect_chip(icon: String, text: String, bg: Color, border: Color, tooltip: String = "", duration: int = 0) -> Dictionary:
	return {
		"icon": icon,
		"text": text,
		"color": bg,
		"border": border,
		"tooltip": tooltip,
		"duration": duration,
	}
