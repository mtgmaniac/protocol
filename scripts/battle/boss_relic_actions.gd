# BossRelicActions — the live battle screen's half of the boss relics that
# touch the dice (boss relic rework, Kev 2026-09-27; DECISIONS_RESOLVED
# G-34..G-38). The RULES live in BattleEngine / CombatManager, shared with the
# headless sim; this module owns only their presentation and input: the
# Scrap Converter grant after a landing, the Tectonic Charge hold, the
# Firewall Hack pick on an enemy die, and the Heretic Signal confirm and
# re-throw. Kept out of battle_scene.gd (over its line limit) on purpose.
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
#   relic_menu_state() -> Dictionary       - usable relic ids + row notes for the loadout
#   use_relic(item) -> bool                - a tapped relic row (Heretic Signal)
extends Node

const HOLD_BANNER_FONT := 48
const HOLD_DETAIL_FONT := PixelUI.FONT_INFO_MIN
const CONFIRM_LAYER := 125

var _scene: Node = null
var _hold_banner: PanelContainer = null
var _confirm_layer: CanvasLayer = null
var _rethrowing: bool = false


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
		_scene._append_log("TECTONIC CHARGE - your heroes hold this round. %s" % hold_detail_text())
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


# The hold's second line: the round-1 shield (when the relic grants one) and
# the roll bonus from round 2. Shared by the banner (one line each) and the log.
func hold_detail_text(separator: String = " ") -> String:
	var cm: CombatManager = _scene.combat_manager
	var shield: int = int(cm.get_relic_value("heroesHoldRoundOne", "shield", 0))
	var charge: int = int(cm.get_relic_value("heroesHoldRoundOne", "amount", 3))
	var parts: Array = []
	if shield > 0:
		parts.append("Each hero gains %d shield." % shield)
	parts.append("+%d to every hero roll from round 2." % charge)
	return separator.join(parts)


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
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	margin.add_child(column)
	column.add_child(label)
	var detail := Label.new()
	detail.name = "HoldDetail"
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.text = hold_detail_text("\n")
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.style_label(detail, HOLD_DETAIL_FONT, PixelUI.TEXT_PRIMARY, 2)
	column.add_child(detail)
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


# While Nudge is armed, an enemy card answers taps whenever the relic is held
# and the enemy has a die (playtest 2026-10-01): a blocked pick (used, frozen,
# hijacked, no Protocol) then says why instead of silently cancelling the Nudge.
func can_pick_for_hack(enemy_state: Dictionary) -> bool:
	return not (_engine().firewall_hack_block(_bs(), enemy_state) in ["no_relic", "no_die"])


# The armed Nudge's prompt names every die it can take.
func nudge_prompt() -> String:
	if not can_hack_any():
		return "Tap a hero die to nudge (+3, once per die)."
	for hero_state in _scene.combat_manager.get_hero_states():
		if _scene._protocol.can_nudge_hero(hero_state):
			return "Tap a die: hero +3, enemy -3."
	return "Tap an enemy die: -3."


# Amber rings around the enemy dice the armed Nudge can take; rebuilt on every
# phase change, so they are gone the moment the pick closes.
const HACK_RING_MARGIN := 10.0
const HACK_RING_WIDTH := 6.0
var _hack_rings: Array = []


func sync_hack_rings(armed: bool) -> void:
	for ring in _hack_rings:
		if is_instance_valid(ring):
			ring.queue_free()
	_hack_rings.clear()
	clear_pick_note()
	var tray: Variant = _scene.dice_tray_3d
	if not armed or tray == null or _scene.float_layer == null:
		return
	for enemy_state in _scene.combat_manager.get_enemy_states():
		if _engine().firewall_hack_block(_bs(), enemy_state) != "":
			continue
		var bounds: Rect2 = tray.get_die_screen_bounds("enemy", str(enemy_state["id"]))
		if bounds.size.x <= 0.0 or is_inf(bounds.position.x):
			continue
		var at: Vector2 = bounds.get_center()
		var side: float = maxf(bounds.size.x, bounds.size.y) + 2.0 * HACK_RING_MARGIN
		var ring := Control.new()
		ring.name = "FirewallHackRing_%s" % str(enemy_state["id"])
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.size = Vector2(PixelUI.even_px(side), PixelUI.even_px(side))
		ring.z_index = 89
		ring.set_as_top_level(true)
		ring.draw.connect(func() -> void:
			ring.draw_rect(Rect2(Vector2.ZERO, ring.size), PixelUI.DT_AMBER, false, HACK_RING_WIDTH))
		_scene.float_layer.add_child(ring)
		var corner: Vector2 = at - ring.size * 0.5
		ring.global_position = Vector2(PixelUI.even_px(corner.x), PixelUI.even_px(corner.y))
		_hack_rings.append(ring)
	if not _hack_rings.is_empty():
		show_pick_note(nudge_prompt())


# The pick note: a plate in the middle of the combat zone, styled like the resume
# callout. battle_scene._refresh_summary has never drawn its text, so the armed
# Nudge's prompt, a blocked hack's reason and "Nudge cancelled." need their own
# surface. hold 0 = stays until the next note or phase change; > 0 = fades,
# then the prompt returns if the Nudge is still armed.
const PICK_NOTE_FONT := 48
const PICK_NOTE_HOLD := 1.6
var _pick_note: PanelContainer = null


func show_pick_note(text: String, hold: float = 0.0) -> void:
	clear_pick_note()
	if _scene.float_layer == null or not is_instance_valid(_scene.float_layer):
		return
	var panel := PanelContainer.new()
	panel.name = "PickNote"
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
	label.name = "PickNoteText"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.style_label(label, PICK_NOTE_FONT, PixelUI.DT_AMBER, 3)
	margin.add_child(label)
	panel.z_as_relative = false
	panel.z_index = 110
	_scene.float_layer.add_child(panel)
	panel.reset_size()
	panel.size = panel.get_combined_minimum_size()
	var zone: Rect2 = _scene.center_panel.get_global_rect()
	# Centred in the gap between the enemy and hero dice rows.
	var pos: Vector2 = zone.get_center() - panel.size * 0.5
	pos -= _scene.float_layer.get_global_position()
	panel.position = Vector2(PixelUI.even_px(pos.x), PixelUI.even_px(pos.y))
	_pick_note = panel
	if hold > 0.0:
		var tween := panel.create_tween()
		tween.tween_interval(hold)
		tween.tween_callback(func() -> void:
			if _pick_note != panel:
				return
			if _scene.turn_phase == _scene.PHASE_NUDGE_PICK and can_hack_any():
				show_pick_note(nudge_prompt())
			else:
				clear_pick_note())


func clear_pick_note() -> void:
	if _pick_note != null and is_instance_valid(_pick_note):
		_pick_note.queue_free()
	_pick_note = null


func pick_note_text() -> String:
	if _pick_note == null or not is_instance_valid(_pick_note):
		return ""
	var label: Label = _pick_note.find_child("PickNoteText", true, false) as Label
	return label.text if label != null else ""


func hack_ring_ids() -> Array:
	return _hack_rings.filter(func(r): return is_instance_valid(r)).map(func(r): return str(r.name).trim_prefix("FirewallHackRing_"))


# The Nudge pick landed on an enemy die. True when this module handled the tap.
func try_firewall_hack(enemy_id: String) -> bool:
	if not _scene.combat_manager.has_relic("enemyNudgeOncePerTurn"):
		return false
	var enemy_state: Dictionary = _scene._find_state_by_id(_scene.combat_manager.get_enemy_states(), enemy_id)
	match _engine().firewall_hack_block(_bs(), enemy_state):
		"":
			pass
		"used":
			show_pick_note("Firewall Hack is used up this turn.", PICK_NOTE_HOLD)
			return true
		"frozen":
			show_pick_note("That die is frozen solid - it can't be nudged.", PICK_NOTE_HOLD)
			return true
		"hijacked":
			show_pick_note("A hijacked die can't be nudged.", PICK_NOTE_HOLD)
			return true
		"protocol":
			show_pick_note("Need 1 Protocol to Nudge.", PICK_NOTE_HOLD)
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


# ── Heretic Signal (G-37) ─────────────────────────────────────────────────────

# Planning phase only: every die has landed and nothing is moving or resolving.
func _planning_now() -> bool:
	var tray: Variant = _scene.dice_tray_3d
	if _rethrowing or _scene.battle_over or bool(_scene._is_resolving_turn):
		return false
	if tray != null and bool(tray.get("_is_rolling")):
		return false
	if _scene.enemy_rolls.is_empty():
		return false
	return _scene.turn_phase == _scene.PHASE_TARGETING or _scene.turn_phase == _scene.PHASE_READY_TO_END


# {"usable": [relic ids a tap uses now], "notes": {relic id: row note}}.
func relic_menu_state() -> Dictionary:
	var usable: Array = []
	var notes: Dictionary = {}
	for relic_id in _scene._game_state().relics:
		var item: ItemData = _scene._data_manager().get_item(str(relic_id)) as ItemData
		if item == null or str(item.effect.get("type", "")) != "rethrowAllOncePerBattle":
			continue
		if _bs().heretic_signal_used:
			notes[item.id] = "USED THIS BATTLE"
		elif _planning_now() and _engine().heretic_signal_available(_bs()):
			notes[item.id] = "TAP TO USE"
			usable.append(item.id)
		elif _planning_now():
			notes[item.id] = "NEEDS %d PROTOCOL" % _engine().heretic_signal_cost()
		else:
			notes[item.id] = "USE AFTER THE ROLL"
	return {"usable": usable, "notes": notes}


# A tapped relic row. True = accepted (the loadout closes).
func use_relic(item: ItemData) -> bool:
	if item == null or str(item.effect.get("type", "")) != "rethrowAllOncePerBattle":
		return false
	if not _planning_now() or not _engine().heretic_signal_available(_bs()):
		return false
	_open_confirm(item)
	return true


func _open_confirm(item: ItemData) -> void:
	_close_confirm()
	_confirm_layer = CanvasLayer.new()
	_confirm_layer.name = "HereticSignalConfirm"
	_confirm_layer.layer = CONFIRM_LAYER
	_scene.add_child(_confirm_layer)
	var catcher := Control.new()
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catcher.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
				or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
			_close_confirm())
	_confirm_layer.add_child(catcher)
	catcher.add_child(PixelUI.make_modal_scrim(0.72))
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_layer.add_child(center)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(760, 0)
	PixelUI.style_component(panel, PixelUI.COMPONENT_MODAL)
	center.add_child(panel)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 40)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_%s" % side, 36)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_theme_constant_override("separation", 24)
	margin.add_child(column)
	var title := Label.new()
	title.text = item.display_name.to_upper()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.style_label(title, 56, PixelUI.TEXT_PRIMARY, 3)
	column.add_child(title)
	var body := Label.new()
	body.text = "Spend %d Protocol to re-throw every die? This can't be undone." % _engine().heretic_signal_cost()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	PixelUI.style_body_label(body, PixelUI.FONT_BODY_MIN, PixelUI.TEXT_MUTED)
	column.add_child(body)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	column.add_child(row)
	# CANCEL first: the irreversible action is never where a thumb lands by reflex.
	var cancel := Button.new()
	cancel.name = "HereticCancel"
	cancel.text = "CANCEL"
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.custom_minimum_size = Vector2(320, 112)
	PixelUI.style_primary_button(cancel, 36)
	cancel.pressed.connect(func() -> void:
		AudioManager.play_click()
		_close_confirm())
	row.add_child(cancel)
	var go := Button.new()
	go.name = "HereticConfirm"
	go.text = "RE-THROW"
	go.focus_mode = Control.FOCUS_NONE
	go.custom_minimum_size = Vector2(320, 112)
	PixelUI.style_button(go, PixelUI.BG_PANEL_ALT, PixelUI.DT_AMBER, 36)
	go.add_theme_color_override("font_color", PixelUI.DT_AMBER)
	go.pressed.connect(func() -> void:
		_close_confirm()
		rethrow_all())
	row.add_child(go)


func _close_confirm() -> void:
	if _confirm_layer != null and is_instance_valid(_confirm_layer):
		_confirm_layer.queue_free()
	_confirm_layer = null


# Every unfrozen die on the board is thrown again through the tray's normal
# full throw (frozen dice stay put as crusted blockers, Dice rules 3-8). The
# landed faces become the new raws; the battle checkpoint then records them
# with the used flag, so a refresh restores these dice (Dice rules 9).
func rethrow_all() -> void:
	if not _planning_now() or not _engine().heretic_signal_available(_bs()):
		return
	_rethrowing = true
	AudioManager.play_select()
	if _scene._protocol.in_roll_modifier_pick():
		_scene._protocol.cancel_roll_modifier_pick()
	_scene._clear_die_tooltip_overlays()
	_scene._card_view.hide_all_ability_readouts()
	_scene._clear_target_assignments()
	var landed: Dictionary = {}
	var tray: Variant = _scene.dice_tray_3d
	if tray != null:
		tray.play_rolls(
			_scene._build_dice_tray_entries(hero_roll_states(), "hero"),
			_scene._build_dice_tray_entries(_scene.combat_manager.get_enemy_states(), "enemy"))
		await tray.roll_finished
		landed = {"hero": tray.get_hero_rolls(), "enemy": tray.get_enemy_rolls()}
	var thrown: Dictionary = _engine().apply_heretic_signal(_bs(), landed)
	_scene._update_protocol_bar()
	var cm: CombatManager = _scene.combat_manager
	for side in ["hero", "enemy"]:
		var states: Array = cm.get_hero_states() if side == "hero" else cm.get_enemy_states()
		var moved: Array = states.filter(func(s): return (thrown.get(side, []) as Array).has(str(s["id"])))
		_engine().record_roll_values_for_states(moved, _scene.hero_rolls if side == "hero" else _scene.enemy_rolls)
		for state in moved:
			_scene._set_state_target(state, "", "--")
	_scene._append_log("Heretic Signal: spent %d Protocol. Every unfrozen die is re-thrown." % _engine().heretic_signal_cost())
	grant_landing_protocol(thrown.get("hero", []))
	if tray != null:
		tray.set_values_live(true)
	_scene.active_targeting_hero_id = ""
	_scene.legal_target_ids.clear()
	_scene.legal_target_side = ""
	_scene.pending_manual_target_ids.clear()
	_scene.has_player_target_assignment = false
	_scene._assign_enemy_targets()
	_scene._prepare_hero_targets()
	_scene._card_view.refresh_all_cards()
	_scene._card_view.show_all_ability_readouts()
	_scene._refresh_dice_result_actions()
	_scene._sync_die_status_visuals()
	_scene.transition(_scene.PHASE_READY_TO_END if _scene.pending_manual_target_ids.is_empty() else _scene.PHASE_TARGETING)
	_rethrowing = false
	_scene._protocol._checkpoint_reroll()
