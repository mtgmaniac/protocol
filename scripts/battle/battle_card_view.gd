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
	if int(state.get("rampage_charges", 0)) > 0:
		status_list.append("RAGE ×%d" % int(state["rampage_charges"]))
	if bool(state.get("cursed", false)):
		status_list.append("CURSED")
	if bool(state.get("taunting", false)) or str(state.get("lured_by_id", "")) != "":
		status_list.append("TAUNT")
	if bool(state.get("warded", false)):
		status_list.append("FIREWALL")
	if bool(state.get("marked", false)):
		status_list.append("MARK")

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
			"cloaked": bool(state.get("cloaked", false)),
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
		var is_aoe: bool        = blast_all or heal_all or shield_all

		# AoE abilities need no committed targeting context — they hit every unit
		# on their side regardless of selection, so preview them the moment the
		# roll is committed. Single-target previews still require that context
		# (we're past targeting, or the player has assigned at least one target),
		# which is gated here and reinforced by the hero_target == target_id check.
		if not is_aoe and not include_hero_ability_previews:
			continue

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

	# ── burn: exactly what _tick_state will deal this round (0 when the tick
	# won't fire — expired, skip-flagged, or no burn), including the enemy-side
	# relic amplification. Single-sourced from combat_manager.
	var active_burn: int = _scene.combat_manager.get_expected_burn_tick(target_state)
	if active_burn > 0:
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
		"burn":             active_burn,
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


# ── Internal helpers ──────────────────────────────────────────────────────────

# pkg8.2: Detonate pip live value — burn × remaining turns on the currently
# selected target (Payload Fuse gear +50%, matching _detonate_burn).
func _patch_live_detonate_value(action_pips: Dictionary, hero_state: Dictionary, chosen_entry: Dictionary) -> void:
	var raw: Dictionary = chosen_entry.get("raw", {})
	if not bool(raw.get("detonate", false)):
		return
	var target_id: String = str(hero_state.get("selected_target_id", ""))
	if target_id == "":
		return
	for enemy_variant in _scene.combat_manager.get_enemy_states():
		var enemy_state: Dictionary = enemy_variant
		if str(enemy_state.get("id", "")) != target_id:
			continue
		var burst: int = int(enemy_state.get("burn", 0)) * int(enemy_state.get("burn_turns", 0))
		if burst > 0 and bool(hero_state.get("gear_detonate_bonus", false)):
			burst = int(ceil(float(burst) * 1.5))
		for effect_variant in action_pips.get("effects", []):
			var effect: Dictionary = effect_variant
			if str(effect.get("kind", "")) == "detonate":
				var dt_code: String = EffectPip.keyword_code("detonate", "DT")
				effect["value"] = "%s %d" % [dt_code, burst] if burst > 0 else dt_code
		return


func _build_compact_status_tokens(state: Dictionary) -> Array:
	var statuses: Array = []
	if bool(state.get("dead", false)):
		statuses.append(_make_compact_named_status("DOWN", "", 99))
		return statuses

	# Chip doctrine (pkg8.1, amended by the taunt unify): the card chip row
	# renders ONLY Burn, Mark, ±Roll, Firewall, and Taunt (on the taunted
	# hero — their targeting is restricted to the taunter, so it must be
	# visible). Everything else surfaces on its own display channel —
	# shields on the HP preview + inspect, cloak as the ghosted portrait,
	# freeze/jam/rewrite/hijack on the die, spike in the readout.
	# DESIGN-TODO(kev): active shield total now reads via HP preview/inspect
	# only — confirm that's enough at 450x1000.
	if int(state.get("burn", 0)) > 0 and int(state.get("burn_turns", 0)) > 0:
		statuses.append({
			"type": "burn",
			"mode": "numeric",
			"icon": "☠",
			"value": int(state.get("burn", 0)),
			"priority": 0,
		})

	if bool(state.get("marked", false)):
		statuses.append(_make_compact_named_status("MARK", "", 1))

	# Mirror combat_manager.get_roll_modifier_totals: temporary rfe_stacks/roll_buff PLUS the
	# permanent relic/gear modifiers (perm_rfe from signalJam, perm_roll_buff from
	# coordinatedStrike / battleStartCloakRoll), so those show as a roll pip like everything else.
	var total_rfe: int = int(state.get("perm_rfe", 0))
	for stack_variant in state.get("rfe_stacks", []):
		var stack: Dictionary = stack_variant
		total_rfe += int(stack.get("amt", 0))
	var roll_buff: int = int(state.get("roll_buff", 0)) + int(state.get("perm_roll_buff", 0))
	var roll_delta: int = roll_buff - total_rfe
	if roll_delta != 0:
		statuses.append({
			"type": "roll",
			"mode": "numeric",
			"icon": "🎲",
			"value": "%+d" % roll_delta,
			"priority": 2,
		})

	if bool(state.get("warded", false)):
		statuses.append(_make_compact_named_status("FIREWALL", "", 3))

	# Taunted hero (enemy-side Taunt, internal lured_by state): targeting is
	# restricted to the taunter — the chip makes the restriction legible.
	if str(state.get("lured_by_id", "")) != "":
		statuses.append(_make_compact_named_status("TAUNT", "", 3))

	return statuses


func _make_compact_named_status(display_name: String, value: String = "", priority: int = 3) -> Dictionary:
	return {
		"type": "named",
		"mode": "named",
		"name": display_name,
		"value": value,
		"priority": priority,
	}


func _revive_hp_pct_from_raw(raw: Dictionary) -> int:
	return int(raw.get("revivePct", 50))


