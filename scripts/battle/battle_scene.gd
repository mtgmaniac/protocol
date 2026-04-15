# Phase 5 battle scene shell that renders cards, rolls dice, and resolves a basic combat loop.
extends Control

@onready var summary_label: Label = %SummaryLabel
@onready var board: VBoxContainer = %Board
@onready var background: ColorRect = $Background
@onready var hero_panel: PanelContainer = %HeroPanel
@onready var hero_scroll: MarginContainer = %HeroScroll
@onready var hero_cards: GridContainer = %HeroCards
@onready var center_panel: PanelContainer = %CenterPanel
@onready var enemy_panel: PanelContainer = %EnemyPanel
@onready var enemy_scroll: MarginContainer = %EnemyScroll
@onready var enemy_cards: GridContainer = %EnemyCards
@onready var protocol_bar: ProgressBar = %ProtocolBar
@onready var protocol_label: Label = %ProtocolLabel
@onready var protocol_value_label: Label = %ProtocolValueLabel
@onready var battle_log_label: RichTextLabel = %BattleLogLabel
@onready var battle_log_panel: PanelContainer = %BattleLogPanel
@onready var protocol_panel: PanelContainer = $Content/VBox/ProtocolPanel
@onready var roll_button: Button = %RollButton
@onready var protocol_spend_button: Button = $Content/VBox/ProtocolPanel/ProtocolMargin/ProtocolRow/ProtocolSpendButton
@onready var return_to_menu_button: Button = $Content/VBox/HeaderRow/ButtonRow/ReturnToMenuButton
@onready var auto_turn_button: Button = %AutoTurnButton
@onready var toggle_log_button: Button = %ToggleLogButton
@onready var float_layer: Control = %FloatLayer
@onready var dice_tray_3d: DiceTray3D = %DiceTray3D

const UNIT_CARD_SCENE := preload("res://scenes/shared/UnitCard.tscn")
const HERO_ACCENT := Color(0.38, 0.64, 0.92, 1.0)
const ENEMY_ACCENT := Color(0.42, 0.54, 0.68, 1.0)
const PHASE_AWAIT_ROLL := "await_roll"
const PHASE_TARGETING := "targeting"
const PHASE_READY_TO_END := "ready_to_end"
const PHASE_REROLL_PICK := "reroll_pick"
const PHASE_NUDGE_PICK := "nudge_pick"
const PHASE_ITEM_PICK_ALLY := "item_pick_ally"
const PHASE_ITEM_PICK_DEAD := "item_pick_dead"
const PHASE_ITEM_PICK_ENEMY := "item_pick_enemy"
const ACTION_FEEDBACK_PAUSE := 0.34
const ACTION_EFFECT_LEAD_TIME := 0.10
const AUTO_TURN_TARGET_PAUSE := 0.16

var dice_manager: DiceManager = DiceManager.new()
var combat_manager: CombatManager = CombatManager.new()
var protocol_points: int = 3
var hero_card_views: Array = []
var enemy_card_views: Array = []
var hero_rolls: Dictionary = {}
var enemy_rolls: Dictionary = {}
var hero_units: Array = []
var enemy_units: Array = []
var turn_phase: String = PHASE_AWAIT_ROLL
var active_targeting_hero_id: String = ""
var legal_target_ids: Array = []
var legal_target_side: String = ""
var pending_manual_target_ids: Array = []
var battle_over: bool = false
var hero_roll_nudges: Dictionary = {}
var _battle_consumables: Array = []
var _item_panel: HBoxContainer = null
var _relic_slot: Control = null
var _hud_tooltip_panel: PanelContainer = null
var _hud_tooltip_label: Label = null
var _hud_tooltip_node: Control = null
var _pending_item: ItemData = null
var _was_in_ready_phase: bool = false
var _phase_before_item: String = ""
var _round_complete_modal: Control = null
var _round_complete_next_button: Button = null
var _auto_turn_running: bool = false


func _game_state() -> Variant:
	return get_node("/root/GameState")


func _data_manager() -> Variant:
	return get_node("/root/DataManager")


func _scene_manager() -> Variant:
	return get_node("/root/SceneManager")


func _ready() -> void:
	resized.connect(_queue_board_layout_refresh)
	_apply_battle_theme()
	_build_round_complete_modal()
	_update_battle_header()
	_build_runtime_units()
	combat_manager.setup_battle(hero_units, enemy_units)
	combat_manager.setup_relics(_game_state().relics)
	combat_manager.setup_gear(_game_state().gear_by_unit)
	var battle_index: int = maxi(_game_state().current_battle - 1, 0)
	combat_manager.apply_battle_start_relic_effects(battle_index)
	combat_manager.apply_battle_start_gear_effects()
	# Protocol Tap gear: sum gear_protocol_on_start from hero states
	for _hs in combat_manager.get_hero_states():
		protocol_points += int(_hs.get("gear_protocol_on_start", 0))
	protocol_points = mini(protocol_points, 10)
	_update_protocol_bar()
	_populate_hero_cards()
	_populate_enemy_cards()
	dice_tray_3d.reset()
	_set_battle_log_visible(false)
	_append_log("Battle initialized.")
	_set_turn_phase(PHASE_AWAIT_ROLL)
	_queue_board_layout_refresh()
	# Wire protocol_spend_button as Reroll and add a Nudge button alongside it
	protocol_spend_button.text = "↺"
	_build_hud_tooltip()
	PixelUI.style_button(auto_turn_button, Color(0.16, 0.08, 0.035, 1.0), Color(0.96, 0.48, 0.16, 1.0), 22)
	_set_hud_tooltip(auto_turn_button, "Debug: automatically play out this turn.")
	_set_hud_tooltip(protocol_spend_button, "Reroll\nSpend 2 Protocol to reroll a hero's die.")
	protocol_spend_button.pressed.connect(_on_reroll_button_pressed)
	_add_nudge_button()
	_build_item_panel()
	_build_relic_slot()
	# Portrait mode: order is Enemy (top) → Center → Hero (bottom)
	board.move_child(enemy_panel, 0)
	board.move_child(center_panel, 1)
	board.move_child(hero_panel, 2)


func _on_open_reward_button_pressed() -> void:
	if not battle_over:
		_refresh_summary("Win the battle before claiming rewards.")
		return
	if _game_state().is_final_battle():
		_refresh_summary("Final battle complete. Opening run summary.")
		_game_state().finish_run("victory")
		_scene_manager().go_to_run_end()
		return
	_game_state().prepare_battle_rewards()
	_scene_manager().go_to_reward_screen()


func _on_return_to_menu_button_pressed() -> void:
	_game_state().reset_run()
	_scene_manager().go_to_unit_select()


func _on_toggle_log_button_pressed() -> void:
	_set_battle_log_visible(not battle_log_panel.visible)


func _on_auto_turn_button_pressed() -> void:
	if _auto_turn_running or battle_over:
		return
	if turn_phase == PHASE_REROLL_PICK or turn_phase == PHASE_NUDGE_PICK or turn_phase.begins_with("item_pick"):
		_refresh_summary("Finish the current picker before auto-completing the turn.")
		return
	_auto_turn_running = true
	auto_turn_button.disabled = true
	_append_log("AUTO: completing the current turn.")
	if turn_phase == PHASE_AWAIT_ROLL:
		await _begin_targeting_phase()
	if turn_phase == PHASE_TARGETING:
		await _auto_assign_pending_targets()
	if turn_phase == PHASE_READY_TO_END:
		await _resolve_current_turn()
	_auto_turn_running = false
	if is_instance_valid(auto_turn_button):
		auto_turn_button.disabled = false


func _populate_hero_cards() -> void:
	_clear_container(hero_cards)
	hero_card_views.clear()
	var hero_states: Array = combat_manager.get_hero_states()
	for hero_state in hero_states:
		var unit: UnitData = hero_state["unit"] as UnitData
		if unit == null:
			continue

		var card: UnitCard = UNIT_CARD_SCENE.instantiate() as UnitCard
		var slot: Control = _build_card_slot()
		hero_cards.add_child(slot)
		slot.add_child(card)
		_prepare_battle_card_layout(card)
		hero_card_views.append({"card": card, "state": hero_state})
		card.card_pressed.connect(_on_hero_card_pressed.bind(hero_state["id"]))
		_update_card_view(card, hero_state, hero_rolls.get(str(hero_state["id"]), null), HERO_ACCENT)
	_queue_board_layout_refresh()


func _populate_enemy_cards() -> void:
	_clear_container(enemy_cards)
	enemy_card_views.clear()
	var enemy_states: Array = combat_manager.get_enemy_states()
	for enemy_state in enemy_states:
		var enemy: EnemyData = enemy_state["unit"] as EnemyData
		if enemy == null:
			continue

		var card: UnitCard = UNIT_CARD_SCENE.instantiate() as UnitCard
		var slot: Control = _build_card_slot()
		enemy_cards.add_child(slot)
		slot.add_child(card)
		_prepare_battle_card_layout(card)
		enemy_card_views.append({"card": card, "state": enemy_state})
		card.card_pressed.connect(_on_enemy_card_pressed.bind(enemy_state["id"]))
		_update_card_view(card, enemy_state, enemy_rolls.get(str(enemy_state["id"]), null), ENEMY_ACCENT)
	_queue_board_layout_refresh()


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()


func _prepare_battle_card_layout(card: UnitCard) -> void:
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 0)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card_frame: Panel = card.get_node("CardFrame")
	card_frame.custom_minimum_size = Vector2(0, 0)


func _build_card_slot() -> Control:
	var slot: Control = Control.new()
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return slot


func _update_card_view(card: UnitCard, state: Dictionary, roll_value: Variant, accent_color: Color) -> void:
	var unit: Resource = state["unit"]
	var default_entry: Dictionary = unit.dice_ranges[0] if unit.dice_ranges.size() > 0 else {}
	var chosen_entry: Dictionary = default_entry
	var dice_text: String = "D20: --"
	var status_list: Array = []
	var target_text: String = _get_target_text(state)
	var active_zone: String = ""

	if roll_value != null:
		var raw_roll: int = int(roll_value)
		var uid: String = str(state["id"])
		var eff_roll: int
		if accent_color == HERO_ACCENT:
			eff_roll = _get_effective_roll_for_state(state, uid)
		else:
			eff_roll = _get_effective_enemy_roll(state, uid)

		var resolved_entry: Dictionary = dice_manager.get_ability_for_roll(unit, eff_roll)
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

	if bool(state["dead"]):
		status_list.append("DOWN")

	card.setup_card(
		unit.display_name,
		int(state["current_hp"]),
		int(state["max_hp"]),
		dice_text,
		str(chosen_entry.get("ability_name", "No ability data")),
		target_text,
		_get_target_display_side(state),
		status_list,
		_get_gear_detail_rows(str(unit.id)),
		_game_state().get_unit_xp_ratio(str(unit.id)),
		bool(state["dead"]),
		accent_color,
		unit.portrait,
		_build_ability_tooltip(unit),
		_build_ability_chart_rows(unit),
		active_zone
	)
	var state_id: String = str(state["id"])
	var is_selected: bool = state_id == active_targeting_hero_id
	var is_targetable: bool = _is_target_highlight_phase() and legal_target_ids.has(state_id)
	card.set_selected(is_selected)
	card.set_targetable(is_targetable)
	card.set_interaction_enabled(_is_card_clickable(state, accent_color))

	# Combat preview: show incoming/outgoing effect overlays on HP bars.
	var is_hero_unit: bool = (accent_color == HERO_ACCENT)
	var preview: Dictionary = _compute_preview_for_unit(state, is_hero_unit)
	if preview.is_empty():
		card.clear_combat_preview()
	else:
		card.show_combat_preview(preview)


func _compute_preview_for_unit(target_state: Dictionary, is_hero: bool) -> Dictionary:
	# Only meaningful during targeting phases when rolls and targets are assigned.
	if turn_phase != PHASE_TARGETING and turn_phase != PHASE_READY_TO_END:
		return {}

	var target_id: String = str(target_state["id"])
	var total_dmg: int    = 0
	var total_heal: int   = 0
	var total_shield: int = 0
	var found: bool = false

	# ── Hero abilities ────────────────────────────────────────────────────────
	for hero_state in combat_manager.get_hero_states():
		if bool(hero_state.get("dead", false)):
			continue
		var hero_id: String = str(hero_state["id"])
		if not hero_rolls.has(hero_id):
			continue
		var eff: int = _get_effective_roll_for_state(hero_state, hero_id)
		var entry: Dictionary = dice_manager.get_ability_for_roll(hero_state["unit"], eff)
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
	for enemy_state in combat_manager.get_enemy_states():
		if bool(enemy_state.get("dead", false)):
			continue
		var enemy_id: String = str(enemy_state["id"])
		if not enemy_rolls.has(enemy_id):
			continue
		var eff: int = _get_effective_enemy_roll(enemy_state, enemy_id)
		var entry: Dictionary = dice_manager.get_ability_for_roll(enemy_state["unit"], eff)
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
			var self_heal: int   = int(raw.get("heal", 0))
			var self_shield: int = int(raw.get("shield", 0)) + int(raw.get("shieldAlly", 0))
			if self_heal > 0 or self_shield > 0:
				found = true
				total_heal   += self_heal
				total_shield += self_shield

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
	# Enemies cannot use their shield to block player damage — player attacks
	# resolve first. Pass current_shield = 0 for enemies so the bar shows full
	# red rather than falsely implying their shield will protect them.
	# For hero cards, include current shield + any incoming shield this turn.
	var effective_shield: int = int(target_state.get("shield", 0)) if is_hero else 0

	# ── Lethal check (enemy units only) ──────────────────────────────────────
	# If total player damage is enough to kill the enemy, flag it so the card
	# can render the entire HP fill as red.
	var lethal: bool = false
	if not is_hero:
		lethal = total_dmg >= int(target_state.get("current_hp", 0))

	return {
		"damage":          total_dmg,
		"heal":            total_heal,
		"shield":          total_shield,
		"dot":             active_dot,
		"current_shield":  effective_shield,
		"lethal":          lethal,
	}


func _on_roll_button_pressed() -> void:
	if battle_over:
		_on_open_reward_button_pressed()
		return
	if turn_phase == PHASE_AWAIT_ROLL:
		_begin_targeting_phase()
		return
	if turn_phase == PHASE_READY_TO_END:
		_resolve_current_turn()


func _begin_targeting_phase() -> void:
	roll_button.visible = false
	roll_button.disabled = true
	roll_button.text = ""
	hero_rolls.clear()
	enemy_rolls.clear()
	hero_roll_nudges.clear()
	active_targeting_hero_id = ""
	legal_target_ids.clear()
	legal_target_side = ""
	pending_manual_target_ids.clear()
	_clear_target_assignments()

	if dice_tray_3d != null:
		dice_tray_3d.play_rolls(
			_build_dice_tray_entries(combat_manager.get_hero_states()),
			_build_dice_tray_entries(combat_manager.get_enemy_states())
		)
		await dice_tray_3d.roll_finished
		hero_rolls = dice_tray_3d.get_hero_rolls()
		enemy_rolls = dice_tray_3d.get_enemy_rolls()
	else:
		hero_rolls = _roll_for_states(combat_manager.get_hero_states())
		enemy_rolls = _roll_for_states(combat_manager.get_enemy_states())
		_apply_frozen_roll_overrides(combat_manager.get_hero_states(), hero_rolls)
		_apply_frozen_roll_overrides(combat_manager.get_enemy_states(), enemy_rolls)
	_record_roll_values_for_states(combat_manager.get_hero_states(), hero_rolls)
	_record_roll_values_for_states(combat_manager.get_enemy_states(), enemy_rolls)

	for hero_state in combat_manager.get_hero_states():
		if bool(hero_state.get("cursed", false)):
			hero_state["cursed"] = false

	_assign_enemy_targets()
	_prepare_hero_targets()
	if dice_tray_3d != null:
		dice_tray_3d.show_result_actions(_build_dice_action_entries(combat_manager.get_hero_states(), hero_rolls, true))
		dice_tray_3d.show_result_actions(_build_dice_action_entries(combat_manager.get_enemy_states(), enemy_rolls, false))
	_set_turn_phase(PHASE_TARGETING)
	_append_log("Dice rolled for all units.")

	if pending_manual_target_ids.is_empty():
		_set_turn_phase(PHASE_READY_TO_END)
		return


func _auto_assign_pending_targets() -> void:
	while turn_phase == PHASE_TARGETING and not pending_manual_target_ids.is_empty():
		var hero_id: String = str(pending_manual_target_ids[0])
		_select_targeting_hero(hero_id)
		await get_tree().create_timer(AUTO_TURN_TARGET_PAUSE).timeout
		if active_targeting_hero_id == "":
			continue
		var target_id: String = _get_auto_debug_target_id(legal_target_side, legal_target_ids)
		if target_id == "":
			pending_manual_target_ids.erase(hero_id)
			active_targeting_hero_id = ""
			legal_target_ids.clear()
			legal_target_side = ""
			continue
		_assign_target_to_active_hero(target_id, _get_auto_debug_target_side(target_id))
		await get_tree().create_timer(AUTO_TURN_TARGET_PAUSE).timeout
	if turn_phase == PHASE_TARGETING and pending_manual_target_ids.is_empty():
		_set_turn_phase(PHASE_READY_TO_END)


func _roll_for_states(states: Array) -> Dictionary:
	var rolls: Dictionary = {}
	for state_variant in states:
		var state: Dictionary = state_variant
		rolls[str(state["id"])] = dice_manager.roll_d20()
	return rolls


func _get_auto_debug_target_id(target_side: String, target_ids: Array) -> String:
	if target_ids.is_empty():
		return ""
	if target_side == "enemy" or target_side == "any":
		for target_id_variant in target_ids:
			var target_id: String = str(target_id_variant)
			if not _find_state_by_id(combat_manager.get_enemy_states(), target_id).is_empty():
				return target_id
	if target_side == "hero" or target_side == "any":
		for target_id_variant in target_ids:
			var target_id: String = str(target_id_variant)
			if not _find_state_by_id(combat_manager.get_hero_states(), target_id).is_empty():
				return target_id
	return str(target_ids[0])


func _get_auto_debug_target_side(target_id: String) -> String:
	if not _find_state_by_id(combat_manager.get_enemy_states(), target_id).is_empty():
		return "enemy"
	if not _find_state_by_id(combat_manager.get_hero_states(), target_id).is_empty():
		return "hero"
	return legal_target_side


func _build_dice_tray_entries(states: Array) -> Array:
	var entries: Array = []
	for state_variant in states:
		var state: Dictionary = state_variant
		if bool(state["dead"]):
			continue
		var unit: Resource = state["unit"]
		var is_frozen: bool = int(state.get("die_freeze_turns", 0)) > 0 and int(state.get("frozen_die_value", 0)) > 0
		var entry: Dictionary = {
			"id": str(state["id"]),
			"name": str(unit.display_name),
		}
		if is_frozen:
			entry["frozen"] = true
			entry["frozen_roll"] = int(state.get("frozen_die_value", 0))
		entries.append(entry)
	return entries


func _apply_frozen_roll_overrides(states: Array, rolls: Dictionary) -> void:
	for state_variant in states:
		var state: Dictionary = state_variant
		if bool(state["dead"]):
			continue
		if int(state.get("die_freeze_turns", 0)) <= 0:
			continue
		var frozen_value: int = int(state.get("frozen_die_value", 0))
		if frozen_value <= 0:
			continue
		rolls[str(state["id"])] = frozen_value


func _record_roll_values_for_states(states: Array, rolls: Dictionary) -> void:
	for state_variant in states:
		var state: Dictionary = state_variant
		if bool(state["dead"]):
			continue
		var roll_value: int = _get_roll_value_for_state(rolls, state)
		if roll_value <= 0:
			continue
		state["last_die_value"] = roll_value
		if int(state.get("die_freeze_turns", 0)) > 0:
			state["die_freeze_consumed_this_round"] = true


func _consume_revealed_frozen_dice() -> void:
	for state_variant in combat_manager.get_hero_states() + combat_manager.get_enemy_states():
		var state: Dictionary = state_variant
		if not bool(state.get("die_freeze_consumed_this_round", false)):
			continue
		state["die_freeze_consumed_this_round"] = false
		state["die_freeze_turns"] = maxi(0, int(state.get("die_freeze_turns", 0)) - 1)
		if int(state.get("die_freeze_turns", 0)) <= 0:
			state["frozen_die_value"] = 0


func _get_roll_value_for_state(rolls: Dictionary, state: Dictionary) -> int:
	var state_id: String = str(state.get("id", ""))
	if rolls.has(state_id):
		return int(rolls[state_id])
	var unit: Object = state.get("unit") as Object
	if unit == null:
		return 0
	var unit_id = unit.get("id")
	if unit_id != null and rolls.has(unit_id):
		return int(rolls[unit_id])
	return 0


func _build_dice_action_entries(states: Array, rolls: Dictionary, is_hero: bool) -> Array:
	var entries: Array = []
	for state_variant in states:
		var state: Dictionary = state_variant
		if bool(state["dead"]):
			continue
		var roll_value: int = _get_roll_value_for_state(rolls, state)
		if roll_value <= 0:
			continue
		var unit: Resource = state["unit"]
		var effective_roll: int = _get_effective_roll_for_state(state, str(state["id"])) if is_hero else _get_effective_enemy_roll(state, str(state["id"]))
		var ability_entry: Dictionary = dice_manager.get_ability_for_roll(unit, effective_roll)
		entries.append({
			"side": "hero" if is_hero else "enemy",
			"id": str(state["id"]),
			"name": str(unit.display_name),
			"ability": str(ability_entry.get("ability_name", "")),
			"roll": effective_roll,
		})
	return entries


func _resolve_current_turn() -> void:
	if battle_over:
		return
	if hero_rolls.is_empty() or enemy_rolls.is_empty():
		_refresh_summary("Roll dice to begin.")
		return

	# Build effective roll dicts so RFE/buff/nudge are reflected in combat resolution
	var eff_hero_rolls: Dictionary = _build_effective_rolls(hero_rolls, combat_manager.get_hero_states(), true)
	var eff_enemy_rolls: Dictionary = _build_effective_rolls(enemy_rolls, combat_manager.get_enemy_states(), false)

	var result: Dictionary = combat_manager.resolve_round(eff_hero_rolls, eff_enemy_rolls, dice_manager)
	hero_rolls.clear()
	enemy_rolls.clear()
	hero_roll_nudges.clear()
	active_targeting_hero_id = ""
	legal_target_ids.clear()
	legal_target_side = ""
	pending_manual_target_ids.clear()
	_clear_target_assignments()
	roll_button.disabled = true
	_append_round_log(result.get("log", []))
	await _play_round_feedback(result.get("events", []))
	_process_summon_events(result.get("events", []))
	_consume_revealed_frozen_dice()
	_refresh_all_cards()

	var outcome: String = str(result.get("result", "ongoing"))
	if outcome == "victory":
		battle_over = true
		roll_button.disabled = true
		if _game_state().is_final_battle():
			_refresh_summary("Boss defeated. Run complete.")
			_game_state().finish_run("victory")
			_scene_manager().go_to_run_end()
		else:
			_refresh_summary("Victory. Routing to rewards.")
			_game_state().prepare_battle_rewards()
			_scene_manager().go_to_reward_screen()
	elif outcome == "defeat":
		battle_over = true
		roll_button.disabled = true
		_refresh_summary("Defeat. Squad wiped.")
		_game_state().finish_run("defeat")
		_scene_manager().go_to_run_end()
	else:
		if _try_finish_battle_from_current_state():
			return
		# Gain +1 PP at end of each resolved round (ongoing only)
		protocol_points = mini(protocol_points + 1, 10)
		_update_protocol_bar()
		_append_log("Protocol +1 → %d" % protocol_points)
		_set_turn_phase(PHASE_AWAIT_ROLL)


# --- Protocol / Reroll / Nudge ---

func _try_finish_battle_from_current_state() -> bool:
	if battle_over:
		return true
	if _are_all_combatants_down(combat_manager.get_enemy_states()):
		_append_log("All enemies are down.")
		_finish_battle_victory()
		return true
	if _are_all_combatants_down(combat_manager.get_hero_states()):
		_append_log("The squad has been wiped out.")
		_finish_battle_defeat()
		return true
	return false


func _are_all_combatants_down(states: Array) -> bool:
	if states.is_empty():
		return false
	for state_variant in states:
		var state: Dictionary = state_variant
		if not bool(state.get("dead", false)):
			return false
	return true


func _finish_battle_victory() -> void:
	battle_over = true
	_disable_combat_actions()
	if _game_state().is_final_battle():
		_refresh_summary("Boss defeated. Run complete.")
		_game_state().finish_run("victory")
		_scene_manager().go_to_run_end()
	else:
		_show_round_complete_modal()


func _finish_battle_defeat() -> void:
	battle_over = true
	_disable_combat_actions()
	_refresh_summary("Defeat. Squad wiped.")
	_game_state().finish_run("defeat")
	_scene_manager().go_to_run_end()


func _disable_combat_actions() -> void:
	hero_rolls.clear()
	enemy_rolls.clear()
	hero_roll_nudges.clear()
	active_targeting_hero_id = ""
	legal_target_ids.clear()
	legal_target_side = ""
	pending_manual_target_ids.clear()
	_pending_item = null
	_was_in_ready_phase = false
	_phase_before_item = ""
	_clear_target_assignments()
	roll_button.visible = false
	roll_button.disabled = true
	roll_button.text = ""
	_refresh_all_cards()


func _build_round_complete_modal() -> void:
	if _round_complete_modal != null:
		return
	_round_complete_modal = Control.new()
	_round_complete_modal.name = "RoundCompleteModal"
	_round_complete_modal.visible = false
	_round_complete_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_round_complete_modal.z_as_relative = false
	_round_complete_modal.z_index = 120
	_round_complete_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_round_complete_modal)

	var scrim: ColorRect = ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(0.004, 0.006, 0.012, 0.58)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_round_complete_modal.add_child(scrim)

	var center: CenterContainer = CenterContainer.new()
	center.name = "ModalCenter"
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_round_complete_modal.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "ModalPanel"
	panel.custom_minimum_size = Vector2(420, 210)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUI.style_panel(panel, Color(0.026, 0.044, 0.066, 0.98), Color(0.98, 0.78, 0.22, 1.0), 4, 0)
	center.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Round Complete"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUI.style_label(title, 38, PixelUI.TEXT_PRIMARY, 4)
	vbox.add_child(title)

	var detail: Label = Label.new()
	detail.text = "Collect rewards and prepare for the next fight."
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail.custom_minimum_size = Vector2(320, 0)
	PixelUI.style_label(detail, 24, PixelUI.TEXT_MUTED, 3)
	vbox.add_child(detail)

	_round_complete_next_button = Button.new()
	_round_complete_next_button.text = "Next"
	_round_complete_next_button.custom_minimum_size = Vector2(170, 58)
	PixelUI.style_button(_round_complete_next_button, Color(0.34, 0.250, 0.070, 1.0), Color(0.98, 0.78, 0.22, 1.0), 28)
	_round_complete_next_button.pressed.connect(_on_round_complete_next_pressed)
	vbox.add_child(_round_complete_next_button)


func _show_round_complete_modal() -> void:
	_build_round_complete_modal()
	_refresh_summary("Round complete.")
	_round_complete_modal.visible = true
	_round_complete_modal.move_to_front()
	if _round_complete_next_button != null:
		_round_complete_next_button.grab_focus()


func _on_round_complete_next_pressed() -> void:
	if not battle_over:
		return
	_game_state().prepare_battle_rewards()
	_scene_manager().go_to_reward_screen()


func _on_protocol_spend_button_pressed() -> void:
	# Kept as a no-op stub; actual handler is _on_reroll_button_pressed wired in _ready()
	pass


func _on_reroll_button_pressed() -> void:
	if turn_phase != PHASE_READY_TO_END and turn_phase != PHASE_TARGETING:
		if hero_rolls.is_empty():
			_refresh_summary("Roll dice before using Reroll.")
		return
	if protocol_points < 2:
		_refresh_summary("Need 2 Protocol to Reroll.")
		return
	_set_turn_phase(PHASE_REROLL_PICK)


func _on_nudge_button_pressed() -> void:
	if turn_phase != PHASE_READY_TO_END and turn_phase != PHASE_TARGETING:
		if hero_rolls.is_empty():
			_refresh_summary("Roll dice before using Nudge.")
		return
	if protocol_points < 1:
		_refresh_summary("Need 1 Protocol to Nudge.")
		return
	_set_turn_phase(PHASE_NUDGE_PICK)


func _add_nudge_button() -> void:
	var btn: Button = Button.new()
	btn.text = "▲"
	btn.custom_minimum_size = Vector2(82, 72)
	_set_hud_tooltip(btn, "Nudge\nSpend 1 Protocol to add +5 to a hero's effective roll.")
	btn.pressed.connect(_on_nudge_button_pressed)
	PixelUI.style_button(btn, PixelUI.BG_PANEL_ALT, PixelUI.HERO_ACCENT, 38)
	protocol_spend_button.get_parent().add_child(btn)
	protocol_spend_button.get_parent().move_child(btn, protocol_spend_button.get_index() + 1)


func _apply_reroll(hero_id: String) -> void:
	protocol_points -= 2
	var new_roll: int = dice_manager.roll_d20()
	hero_rolls[hero_id] = new_roll
	# Clear nudge for this hero since their roll is fresh
	hero_roll_nudges.erase(hero_id)
	_update_protocol_bar()
	_append_log("Reroll: %s draws %d." % [hero_id, new_roll])
	if dice_tray_3d != null:
		await dice_tray_3d.reroll_die_to_result("hero", hero_id, new_roll)
	_re_assign_hero_target(hero_id)
	_refresh_dice_result_actions()
	_finish_roll_modifier_pick()


func _apply_nudge(hero_id: String) -> void:
	protocol_points -= 1
	hero_roll_nudges[hero_id] = int(hero_roll_nudges.get(hero_id, 0)) + 5
	_update_protocol_bar()
	_append_log("Nudge: %s +5 to effective roll." % hero_id)
	var hero_state: Dictionary = _find_state_by_id(combat_manager.get_hero_states(), hero_id)
	if dice_tray_3d != null and not hero_state.is_empty():
		dice_tray_3d.update_die_result_in_place("hero", hero_id, _get_effective_roll_for_state(hero_state, hero_id))
	_re_assign_hero_target(hero_id)
	_refresh_dice_result_actions()
	_finish_roll_modifier_pick()


func _re_assign_hero_target(hero_id: String) -> void:
	var hero_state: Dictionary = _find_state_by_id(combat_manager.get_hero_states(), hero_id)
	if hero_state.is_empty():
		return
	var eff_roll: int = _get_effective_roll_for_state(hero_state, hero_id)
	var ability_entry: Dictionary = dice_manager.get_ability_for_roll(hero_state["unit"], eff_roll)
	var manual_side: String = _get_manual_target_side(ability_entry)
	pending_manual_target_ids.erase(hero_id)
	if manual_side == "":
		_auto_assign_hero_target(hero_state, ability_entry)
	else:
		_queue_or_auto_assign_manual_target(hero_state, manual_side)


func _refresh_dice_result_actions() -> void:
	if dice_tray_3d == null:
		return
	dice_tray_3d.show_result_actions(_build_dice_action_entries(combat_manager.get_hero_states(), hero_rolls, true))
	dice_tray_3d.show_result_actions(_build_dice_action_entries(combat_manager.get_enemy_states(), enemy_rolls, false))


func _finish_roll_modifier_pick() -> void:
	active_targeting_hero_id = ""
	legal_target_ids.clear()
	legal_target_side = ""
	if pending_manual_target_ids.is_empty():
		_set_turn_phase(PHASE_READY_TO_END)
	else:
		_set_turn_phase(PHASE_TARGETING)
		_refresh_summary("Select hero targets.")


# --- Effective roll helpers ---

func _get_effective_roll_for_state(state: Dictionary, unit_id: String) -> int:
	var raw_roll: int = int(hero_rolls.get(unit_id, hero_rolls.get(str(unit_id), 0)))
	if raw_roll == 0:
		return 1
	if bool(state.get("die_freeze_consumed_this_round", false)):
		return clampi(raw_roll, 1, 20)
	var nudge: int = int(hero_roll_nudges.get(unit_id, hero_roll_nudges.get(str(unit_id), 0)))
	var base_eff: int = combat_manager.get_effective_roll(state, raw_roll)
	return clampi(base_eff + nudge, 1, 20)


func _get_effective_enemy_roll(state: Dictionary, unit_id: String) -> int:
	var raw_roll: int = int(enemy_rolls.get(unit_id, enemy_rolls.get(str(unit_id), 0)))
	if raw_roll == 0:
		return 1
	if bool(state.get("die_freeze_consumed_this_round", false)):
		return clampi(raw_roll, 1, 20)
	return combat_manager.get_effective_roll(state, raw_roll)


# Builds a dict of effective rolls for all living units in the given states array.
# Used to pass fully-resolved roll values into combat_manager.resolve_round().
func _build_effective_rolls(raw_rolls: Dictionary, states: Array, is_hero: bool) -> Dictionary:
	var eff: Dictionary = {}
	for state in states:
		if bool(state["dead"]):
			continue
		var uid: String = str(state["id"])
		var raw: int = int(raw_rolls.get(uid, 0))
		if raw == 0:
			continue
		if is_hero:
			eff[uid] = _get_effective_roll_for_state(state, uid)
		else:
			eff[uid] = combat_manager.get_effective_roll(state, raw)
	return eff


func _update_protocol_bar() -> void:
	protocol_bar.max_value = 10
	protocol_bar.value = protocol_points
	protocol_value_label.text = "%d / 10" % protocol_points


func _refresh_all_cards() -> void:
	for hero_view in hero_card_views:
		var hero_state: Dictionary = hero_view["state"]
		_update_card_view(hero_view["card"], hero_state, hero_rolls.get(str(hero_state["id"]), null), HERO_ACCENT)

	for enemy_view in enemy_card_views:
		var enemy_state: Dictionary = enemy_view["state"]
		_update_card_view(enemy_view["card"], enemy_state, enemy_rolls.get(str(enemy_state["id"]), null), ENEMY_ACCENT)


func _build_runtime_units() -> void:
	hero_units.clear()
	enemy_units.clear()

	for unit_id in _game_state().selected_units:
		var unit: UnitData = _game_state().get_run_unit_data(str(unit_id))
		if unit != null:
			hero_units.append(unit)

	var operation: OperationData = _data_manager().get_operation(_game_state().selected_operation_id) as OperationData
	if operation == null:
		return

	var battle_index: int = maxi(_game_state().current_battle - 1, 0)
	if battle_index >= operation.battles.size():
		return

	var battle_entry: Dictionary = operation.battles[battle_index]
	var enemy_names: Array = battle_entry.get("enemy_names", [])
	for enemy_name in enemy_names:
		var enemy: EnemyData = _data_manager().get_enemy_by_display_name(str(enemy_name)) as EnemyData
		if enemy != null:
			enemy_units.append(_build_scaled_enemy(enemy, battle_index, operation.track_hp_scale))


func _refresh_summary(_extra_text: String) -> void:
	_update_battle_header()


func _update_battle_header() -> void:
	var operation: OperationData = _data_manager().get_operation(_game_state().selected_operation_id) as OperationData
	var series_name: String = operation.display_name if operation != null and operation.display_name != "" else "Operation"
	var battle_text: String = _game_state().get_battle_progress_text()
	summary_label.text = "%s  %s" % [series_name, battle_text]


func _set_turn_phase(next_phase: String) -> void:
	turn_phase = next_phase
	_update_phase_target_sets()
	match turn_phase:
		PHASE_AWAIT_ROLL:
			roll_button.visible = true
			roll_button.disabled = false
			roll_button.text = "Roll All"
			_refresh_summary("")
		PHASE_TARGETING:
			roll_button.visible = false
			roll_button.disabled = true
			roll_button.text = ""
		PHASE_READY_TO_END:
			roll_button.visible = true
			roll_button.disabled = false
			roll_button.text = "End Turn"
			_refresh_summary("All hero targets locked.")
		PHASE_REROLL_PICK:
			roll_button.visible = false
			roll_button.disabled = true
			roll_button.text = ""
			_refresh_summary("")
		PHASE_NUDGE_PICK:
			roll_button.visible = false
			roll_button.disabled = true
			roll_button.text = ""
			_refresh_summary("")
		PHASE_ITEM_PICK_ALLY:
			roll_button.visible = true
			roll_button.disabled = true
			roll_button.text = "Pick ally for item"
			var item_name_ally: String = _pending_item.display_name if _pending_item != null else "item"
			_refresh_summary("Select a living ally to use %s." % item_name_ally)
		PHASE_ITEM_PICK_DEAD:
			roll_button.visible = true
			roll_button.disabled = true
			roll_button.text = "Pick fallen ally"
			var item_name_dead: String = _pending_item.display_name if _pending_item != null else "item"
			_refresh_summary("Select a fallen ally for %s." % item_name_dead)
		PHASE_ITEM_PICK_ENEMY:
			roll_button.visible = true
			roll_button.disabled = true
			roll_button.text = "Pick enemy for item"
			var item_name_enemy: String = _pending_item.display_name if _pending_item != null else "item"
			_refresh_summary("Select an enemy for %s." % item_name_enemy)
	_style_roll_button_for_phase()
	_refresh_all_cards()


func _style_roll_button_for_phase() -> void:
	match turn_phase:
		PHASE_AWAIT_ROLL:
			PixelUI.style_button(roll_button, Color(0.045, 0.160, 0.105, 1.0), Color(0.20, 0.66, 0.50, 1.0), 34)
		PHASE_READY_TO_END:
			PixelUI.style_button(roll_button, Color(0.34, 0.250, 0.070, 1.0), Color(0.98, 0.78, 0.22, 1.0), 34)
		_:
			PixelUI.style_button(roll_button, PixelUI.BG_PANEL_ALT, PixelUI.LINE_BRIGHT, 34)


func _update_phase_target_sets() -> void:
	if not turn_phase.begins_with("item_pick"):
		if turn_phase != PHASE_TARGETING:
			legal_target_ids.clear()
			legal_target_side = ""
		return

	match turn_phase:
		PHASE_ITEM_PICK_ALLY:
			legal_target_side = "hero"
			legal_target_ids = _get_legal_target_ids("hero")
		PHASE_ITEM_PICK_DEAD:
			legal_target_side = "hero"
			legal_target_ids = []
		PHASE_ITEM_PICK_ENEMY:
			legal_target_side = "enemy"
			legal_target_ids = _get_legal_target_ids("enemy")


func _is_target_highlight_phase() -> bool:
	if turn_phase.begins_with("item_pick"):
		return true
	return turn_phase == PHASE_TARGETING and active_targeting_hero_id != ""


func _clear_target_assignments() -> void:
	for hero_view_variant in hero_card_views:
		var hero_view: Dictionary = hero_view_variant
		var hero_state: Dictionary = hero_view["state"]
		hero_state["selected_target_id"] = ""
		hero_state["target_display"] = "--"

	for enemy_view_variant in enemy_card_views:
		var enemy_view: Dictionary = enemy_view_variant
		var enemy_state: Dictionary = enemy_view["state"]
		enemy_state["selected_target_id"] = ""
		enemy_state["target_display"] = "--"


func _assign_enemy_targets() -> void:
	for enemy_view_variant in enemy_card_views:
		var enemy_view: Dictionary = enemy_view_variant
		var enemy_state: Dictionary = enemy_view["state"]
		if bool(enemy_state["dead"]):
			continue
		var enemy_roll: Variant = enemy_rolls.get(enemy_state["id"], null)
		if enemy_roll == null:
			continue
		# Use effective roll for target assignment
		var eff_roll: int = _get_effective_enemy_roll(enemy_state, str(enemy_state["id"]))
		var ability_entry: Dictionary = dice_manager.get_ability_for_roll(enemy_state["unit"], eff_roll)
		_auto_assign_enemy_target(enemy_state, ability_entry)


func _prepare_hero_targets() -> void:
	# Taunt: if any enemy is taunting, force all living heroes to target it
	var taunt_id: String = _get_taunt_enemy_id()
	if taunt_id != "":
		for hero_view_variant in hero_card_views:
			var hero_view: Dictionary = hero_view_variant
			var hero_state: Dictionary = hero_view["state"]
			if bool(hero_state["dead"]):
				continue
			var taunt_state: Dictionary = _find_state_by_id(combat_manager.get_enemy_states(), taunt_id)
			var taunt_name: String = str(taunt_state["unit"].display_name) if not taunt_state.is_empty() else "Taunter"
			_set_state_target(hero_state, taunt_id, taunt_name)
		return

	for hero_view_variant in hero_card_views:
		var hero_view: Dictionary = hero_view_variant
		var hero_state: Dictionary = hero_view["state"]
		if bool(hero_state["dead"]):
			continue
		var hero_roll: Variant = hero_rolls.get(hero_state["id"], null)
		if hero_roll == null:
			continue
		# Use effective roll for targeting and ability lookup
		var eff_roll: int = _get_effective_roll_for_state(hero_state, str(hero_state["id"]))
		var ability_entry: Dictionary = dice_manager.get_ability_for_roll(hero_state["unit"], eff_roll)
		var manual_side: String = _get_manual_target_side(ability_entry)
		if manual_side == "":
			_auto_assign_hero_target(hero_state, ability_entry)
			continue
		_queue_or_auto_assign_manual_target(hero_state, manual_side)


func _get_manual_target_side(ability_entry: Dictionary) -> String:
	var raw: Dictionary = ability_entry.get("raw", {})
	if bool(raw.get("freezeAnyDice", false)):
		return "any"
	if int(raw.get("freezeEnemyDice", 0)) > 0:
		return "enemy"
	if bool(raw.get("healTgt", false)) or bool(raw.get("shTgt", false)):
		return "hero"
	if bool(raw.get("rfmTgt", false)):
		return "hero"
	if bool(raw.get("blastAll", false)) or bool(raw.get("healAll", false)) or bool(raw.get("shieldAll", false)):
		return ""
	if int(raw.get("dmg", 0)) > 0:
		return "enemy"
	if int(raw.get("dot", 0)) > 0:
		return "enemy"
	if int(raw.get("rfe", 0)) > 0 or bool(raw.get("rfeOnly", false)):
		return "enemy"
	return ""


func _queue_or_auto_assign_manual_target(hero_state: Dictionary, manual_side: String) -> void:
	var hero_id: String = str(hero_state["id"])
	var target_ids: Array = _get_legal_target_ids(manual_side)
	pending_manual_target_ids.erase(hero_id)
	if _try_auto_assign_single_manual_target(hero_state, manual_side, target_ids):
		return
	if not pending_manual_target_ids.has(hero_id):
		pending_manual_target_ids.append(hero_id)
	hero_state["target_display"] = "--"


func _try_auto_assign_single_manual_target(hero_state: Dictionary, target_side: String, target_ids: Array) -> bool:
	if target_ids.size() != 1:
		return false
	var target_id: String = str(target_ids[0])
	var target_state: Dictionary = _find_manual_target_state(target_side, target_id)
	if target_state.is_empty():
		return false
	_set_state_target(hero_state, target_id, str(target_state["unit"].display_name))
	pending_manual_target_ids.erase(str(hero_state["id"]))
	if active_targeting_hero_id == str(hero_state["id"]):
		active_targeting_hero_id = ""
		legal_target_ids.clear()
		legal_target_side = ""
		_refresh_all_cards()
		if pending_manual_target_ids.is_empty():
			_set_turn_phase(PHASE_READY_TO_END)
		else:
			_refresh_summary("Select the next hero to target.")
	return true


func _auto_assign_hero_target(hero_state: Dictionary, ability_entry: Dictionary) -> void:
	var raw: Dictionary = ability_entry.get("raw", {})
	if bool(raw.get("healAll", false)):
		_set_state_target(hero_state, "", "All Squad")
		return
	if bool(raw.get("shieldAll", false)):
		_set_state_target(hero_state, "", "All Squad")
		return
	if bool(raw.get("blastAll", false)):
		_set_state_target(hero_state, "", "All Hostiles")
		return
	if bool(raw.get("healLowest", false)):
		var lowest_ally: Dictionary = _lowest_living_hero_state()
		if lowest_ally.is_empty():
			_set_state_target(hero_state, "", "--")
			return
		_set_state_target(hero_state, str(lowest_ally["id"]), str(lowest_ally["unit"].display_name))
		return
	if int(raw.get("shield", 0)) > 0 or int(raw.get("heal", 0)) > 0:
		_set_state_target(hero_state, str(hero_state["id"]), "Self")
		return
	_set_state_target(hero_state, "", "--")


func _auto_assign_enemy_target(enemy_state: Dictionary, ability_entry: Dictionary) -> void:
	var raw: Dictionary = ability_entry.get("raw", {})
	var unit: EnemyData = enemy_state["unit"] as EnemyData
	var ai_type: String = str(unit.ai_type) if unit != null else "dumb"

	# Self-targeted: shield or heal self
	if int(raw.get("shield", 0)) > 0 or int(raw.get("heal", 0)) > 0:
		_set_state_target(enemy_state, str(enemy_state["id"]), "Self")
		return

	# Ally-targeted: shield a living ally
	if int(raw.get("shieldAlly", 0)) > 0:
		var ally_target: Dictionary = _first_living_enemy_state()
		if ally_target.is_empty():
			_set_state_target(enemy_state, "", "--")
			return
		_set_state_target(enemy_state, str(ally_target["id"]), str(ally_target["unit"].display_name))
		return

	# Hero-targeted: damage, DoT, or roll debuff
	var targets_hero: bool = int(raw.get("dmg", 0)) > 0 or int(raw.get("dot", 0)) > 0 or int(raw.get("rfm", 0)) > 0
	if targets_hero:
		var hero_target: Dictionary = {}
		if ai_type == "smart":
			# Pure debuff (rfm only): target highest HP to disrupt strongest attacker
			# Damage/DoT: target lowest HP to maximize kill threat
			var is_pure_debuff: bool = int(raw.get("dmg", 0)) == 0 and int(raw.get("dot", 0)) == 0
			hero_target = _smart_target_hero(is_pure_debuff)
		else:
			hero_target = _first_living_hero_state()
		if hero_target.is_empty():
			_set_state_target(enemy_state, "", "--")
			return
		_set_state_target(enemy_state, str(hero_target["id"]), str(hero_target["unit"].display_name))
		return

	_set_state_target(enemy_state, "", "--")


func _select_targeting_hero(hero_id: String) -> void:
	active_targeting_hero_id = hero_id
	legal_target_ids.clear()
	var hero_state: Dictionary = _find_state_by_id(combat_manager.get_hero_states(), hero_id)
	if hero_state.is_empty():
		return
	var hero_roll: Variant = hero_rolls.get(hero_state["id"], null)
	if hero_roll == null:
		return
	var eff_roll: int = _get_effective_roll_for_state(hero_state, str(hero_state["id"]))
	var ability_entry: Dictionary = dice_manager.get_ability_for_roll(hero_state["unit"], eff_roll)
	legal_target_side = _get_manual_target_side(ability_entry)
	legal_target_ids = _get_legal_target_ids(legal_target_side)
	if _try_auto_assign_single_manual_target(hero_state, legal_target_side, legal_target_ids):
		return
	_refresh_all_cards()
	_refresh_summary("Choose a target for %s." % str(hero_state["unit"].display_name))


func _assign_target_to_active_hero(target_id: String, target_side: String) -> void:
	var hero_state: Dictionary = _find_state_by_id(combat_manager.get_hero_states(), active_targeting_hero_id)
	if hero_state.is_empty():
		return
	var target_state: Dictionary = _find_manual_target_state(target_side, target_id)
	if target_state.is_empty():
		return
	_set_state_target(hero_state, target_id, str(target_state["unit"].display_name))
	pending_manual_target_ids.erase(active_targeting_hero_id)
	active_targeting_hero_id = ""
	legal_target_ids.clear()
	legal_target_side = ""
	_refresh_all_cards()
	if pending_manual_target_ids.is_empty():
		_set_turn_phase(PHASE_READY_TO_END)
	else:
		_refresh_summary("Select the next hero to target.")


func _get_legal_target_ids(target_side: String) -> Array:
	var ids: Array = []
	var states: Array = []
	if target_side == "any":
		states.append_array(combat_manager.get_hero_states())
		states.append_array(combat_manager.get_enemy_states())
	else:
		states = combat_manager.get_hero_states() if target_side == "hero" else combat_manager.get_enemy_states()
	for state_variant in states:
		var state: Dictionary = state_variant
		if bool(state["dead"]):
			continue
		ids.append(str(state["id"]))
	return ids


func _find_manual_target_state(target_side: String, target_id: String) -> Dictionary:
	if target_side == "hero":
		return _find_state_by_id(combat_manager.get_hero_states(), target_id)
	if target_side == "enemy":
		return _find_state_by_id(combat_manager.get_enemy_states(), target_id)
	var hero_state: Dictionary = _find_state_by_id(combat_manager.get_hero_states(), target_id)
	if not hero_state.is_empty():
		return hero_state
	return _find_state_by_id(combat_manager.get_enemy_states(), target_id)


func _get_dead_target_ids(target_side: String) -> Array:
	var ids: Array = []
	var states: Array = combat_manager.get_hero_states() if target_side == "hero" else combat_manager.get_enemy_states()
	for state_variant in states:
		var state: Dictionary = state_variant
		if bool(state["dead"]):
			ids.append(str(state["id"]))
	return ids


func _find_state_by_id(states: Array, target_id: String) -> Dictionary:
	for state_variant in states:
		var state: Dictionary = state_variant
		if str(state["id"]) == target_id:
			return state
	return {}


func _get_taunt_enemy_id() -> String:
	for enemy_state in combat_manager.get_enemy_states():
		if not bool(enemy_state["dead"]) and bool(enemy_state.get("taunting", false)):
			return str(enemy_state["id"])
	return ""


func _first_living_hero_state() -> Dictionary:
	return _first_living_from_states(combat_manager.get_hero_states())


func _first_living_enemy_state() -> Dictionary:
	return _first_living_from_states(combat_manager.get_enemy_states())


func _first_living_from_states(states: Array) -> Dictionary:
	for state_variant in states:
		var state: Dictionary = state_variant
		if not bool(state["dead"]):
			return state
	return {}


func _lowest_living_hero_state() -> Dictionary:
	var best_state: Dictionary = {}
	var best_ratio: float = 2.0
	for state_variant in combat_manager.get_hero_states():
		var state: Dictionary = state_variant
		if bool(state["dead"]):
			continue
		var max_hp: int = maxi(int(state["max_hp"]), 1)
		var hp_ratio: float = float(state["current_hp"]) / float(max_hp)
		if hp_ratio < best_ratio:
			best_ratio = hp_ratio
			best_state = state
	return best_state


func _smart_target_hero(prefer_high_hp: bool = false) -> Dictionary:
	var living: Array = []
	for view in hero_card_views:
		var state: Dictionary = view["state"]
		if not bool(state["dead"]):
			living.append(state)
	if living.is_empty():
		return {}
	# Deprioritize cloaked heroes — 80% dodge makes them inefficient targets
	var uncloaked: Array = living.filter(func(s): return not bool(s.get("cloaked", false)))
	var pool: Array = uncloaked if not uncloaked.is_empty() else living
	var best: Dictionary = pool[0]
	for s in pool:
		if prefer_high_hp:
			if int(s["current_hp"]) > int(best["current_hp"]):
				best = s
		else:
			if int(s["current_hp"]) < int(best["current_hp"]):
				best = s
	return best


func _set_state_target(state: Dictionary, target_id: String, target_display: String) -> void:
	state["selected_target_id"] = target_id
	state["target_display"] = target_display


func _get_target_text(state: Dictionary) -> String:
	return str(state.get("target_display", "--"))


func _get_target_display_side(state: Dictionary) -> String:
	var target_id: String = str(state.get("selected_target_id", ""))
	var target_display: String = str(state.get("target_display", ""))
	if target_display == "Self" or target_display == "All Squad":
		return "hero"
	if target_display == "All Hostiles":
		return "enemy"
	if target_id != "":
		if not _find_state_by_id(combat_manager.get_hero_states(), target_id).is_empty():
			return "hero"
		if not _find_state_by_id(combat_manager.get_enemy_states(), target_id).is_empty():
			return "enemy"
	return ""


func _is_card_clickable(state: Dictionary, accent_color: Color) -> bool:
	if battle_over:
		return false

	# Reroll/Nudge pick phases: only living hero cards that have rolled
	if turn_phase == PHASE_REROLL_PICK or turn_phase == PHASE_NUDGE_PICK:
		return accent_color == HERO_ACCENT and not bool(state["dead"]) and _has_roll_for_state(hero_rolls, state)

	# Item pick phases
	if turn_phase == PHASE_ITEM_PICK_ALLY:
		return accent_color == HERO_ACCENT and not bool(state["dead"])
	if turn_phase == PHASE_ITEM_PICK_DEAD:
		return false
	if turn_phase == PHASE_ITEM_PICK_ENEMY:
		return accent_color == ENEMY_ACCENT and not bool(state["dead"])

	if turn_phase != PHASE_TARGETING:
		return false

	var state_id: String = str(state["id"])
	if active_targeting_hero_id == "":
		if accent_color != HERO_ACCENT:
			return false
		return pending_manual_target_ids.has(state_id)

	if legal_target_side == "enemy" and accent_color == ENEMY_ACCENT:
		return legal_target_ids.has(state_id)
	if legal_target_side == "hero" and accent_color == HERO_ACCENT:
		return legal_target_ids.has(state_id)
	if legal_target_side == "any" and (accent_color == HERO_ACCENT or accent_color == ENEMY_ACCENT):
		return legal_target_ids.has(state_id)
	return false


func _has_roll_for_state(rolls: Dictionary, state: Dictionary) -> bool:
	var state_id: String = str(state.get("id", ""))
	if rolls.has(state_id):
		return true
	var unit: Object = state.get("unit") as Object
	if unit == null:
		return false
	var unit_id = unit.get("id")
	return unit_id != null and rolls.has(unit_id)


func _on_enemy_card_pressed(target_id: String) -> void:
	if battle_over:
		return
	if turn_phase == PHASE_ITEM_PICK_ENEMY:
		if not legal_target_ids.has(target_id):
			return
		if _pending_item != null:
			var target_state: Dictionary = _find_state_by_id(combat_manager.get_enemy_states(), target_id)
			if not target_state.is_empty():
				_apply_item_effect(_pending_item, target_state)
		return
	if turn_phase != PHASE_TARGETING:
		return
	if active_targeting_hero_id == "" or (legal_target_side != "enemy" and legal_target_side != "any"):
		return
	if not legal_target_ids.has(target_id):
		return
	_assign_target_to_active_hero(target_id, "enemy")


func _on_hero_card_pressed(target_id: String) -> void:
	if battle_over:
		return

	# Handle reroll/nudge pick phases first
	if turn_phase == PHASE_REROLL_PICK:
		var reroll_state: Dictionary = _find_state_by_id(combat_manager.get_hero_states(), target_id)
		if reroll_state.is_empty() or bool(reroll_state["dead"]) or not _has_roll_for_state(hero_rolls, reroll_state):
			return
		await _apply_reroll(target_id)
		return
	if turn_phase == PHASE_NUDGE_PICK:
		var nudge_state: Dictionary = _find_state_by_id(combat_manager.get_hero_states(), target_id)
		if nudge_state.is_empty() or bool(nudge_state["dead"]) or not _has_roll_for_state(hero_rolls, nudge_state):
			return
		_apply_nudge(target_id)
		return

	if turn_phase == PHASE_ITEM_PICK_ALLY or turn_phase == PHASE_ITEM_PICK_DEAD:
		if not legal_target_ids.has(target_id):
			return
		if _pending_item != null:
			var target_state: Dictionary = _find_state_by_id(combat_manager.get_hero_states(), target_id)
			if not target_state.is_empty():
				_apply_item_effect(_pending_item, target_state)
		return

	if turn_phase != PHASE_TARGETING:
		return
	if active_targeting_hero_id == "":
		if pending_manual_target_ids.has(target_id):
			_select_targeting_hero(target_id)
		return
	if legal_target_side == "hero" and legal_target_ids.has(target_id):
		_assign_target_to_active_hero(target_id, "hero")
	elif legal_target_side == "any" and legal_target_ids.has(target_id):
		_assign_target_to_active_hero(target_id, "hero")


func _append_round_log(entries: Array) -> void:
	for entry in entries:
		_append_log(str(entry))


func _append_log(message: String) -> void:
	if battle_log_label.text == "":
		battle_log_label.text = message
	else:
		battle_log_label.text = "%s\n%s" % [message, battle_log_label.text]


func _set_battle_log_visible(is_visible: bool) -> void:
	battle_log_panel.visible = is_visible
	toggle_log_button.text = "?"


func _build_hud_tooltip() -> void:
	if _hud_tooltip_panel != null:
		return
	_hud_tooltip_panel = PanelContainer.new()
	_hud_tooltip_panel.visible = false
	_hud_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_tooltip_panel.z_as_relative = false
	_hud_tooltip_panel.z_index = 100
	_hud_tooltip_panel.custom_minimum_size = Vector2(360, 48)
	var tooltip_style: StyleBoxFlat = StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.018, 0.026, 0.044, 0.96)
	tooltip_style.border_color = Color(0.36, 0.55, 0.78, 0.92)
	tooltip_style.set_border_width_all(3)
	tooltip_style.corner_radius_top_left = 0
	tooltip_style.corner_radius_top_right = 0
	tooltip_style.corner_radius_bottom_left = 0
	tooltip_style.corner_radius_bottom_right = 0
	_hud_tooltip_panel.add_theme_stylebox_override("panel", tooltip_style)
	float_layer.add_child(_hud_tooltip_panel)

	var tooltip_margin: MarginContainer = MarginContainer.new()
	tooltip_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_margin.add_theme_constant_override("margin_left", 16)
	tooltip_margin.add_theme_constant_override("margin_top", 12)
	tooltip_margin.add_theme_constant_override("margin_right", 16)
	tooltip_margin.add_theme_constant_override("margin_bottom", 12)
	_hud_tooltip_panel.add_child(tooltip_margin)

	_hud_tooltip_label = Label.new()
	_hud_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hud_tooltip_label.custom_minimum_size.x = 320
	_hud_tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	PixelUI.apply_pixel_font(_hud_tooltip_label)
	_hud_tooltip_label.add_theme_font_size_override("font_size", PixelUI.scale_font_size(24))
	_hud_tooltip_label.add_theme_color_override("font_color", PixelUI.TEXT_PRIMARY)
	_hud_tooltip_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	_hud_tooltip_label.add_theme_constant_override("outline_size", 3)
	tooltip_margin.add_child(_hud_tooltip_label)


func _set_hud_tooltip(node: Control, text: String) -> void:
	if node == null:
		return
	_build_hud_tooltip()
	node.tooltip_text = ""
	node.set_meta("hud_tooltip", text)
	if bool(node.get_meta("hud_tooltip_connected", false)):
		return
	node.set_meta("hud_tooltip_connected", true)
	if not node.mouse_entered.is_connected(_on_hud_tooltip_entered):
		node.mouse_entered.connect(_on_hud_tooltip_entered.bind(node))
	if not node.mouse_exited.is_connected(_on_hud_tooltip_exited):
		node.mouse_exited.connect(_on_hud_tooltip_exited)


func _on_hud_tooltip_entered(node: Control) -> void:
	if node == null or _hud_tooltip_panel == null or _hud_tooltip_label == null:
		return
	var text: String = str(node.get_meta("hud_tooltip", "")).strip_edges()
	if text == "":
		_hide_hud_tooltip()
		return
	_hud_tooltip_node = node
	_hud_tooltip_label.text = text
	_hud_tooltip_panel.reset_size()
	_update_hud_tooltip_position()
	_hud_tooltip_panel.visible = true


func _on_hud_tooltip_exited() -> void:
	_hide_hud_tooltip()


func _hide_hud_tooltip() -> void:
	_hud_tooltip_node = null
	if _hud_tooltip_panel != null:
		_hud_tooltip_panel.visible = false


func _update_hud_tooltip_position() -> void:
	if _hud_tooltip_panel == null:
		return
	var tooltip_size: Vector2 = _hud_tooltip_panel.get_combined_minimum_size()
	var target_pos: Vector2 = get_global_mouse_position() + Vector2(15, 15)
	if _hud_tooltip_node != null and _hud_tooltip_node.is_inside_tree():
		var node_rect: Rect2 = _hud_tooltip_node.get_global_rect()
		target_pos = Vector2(
			node_rect.position.x + (node_rect.size.x - tooltip_size.x) / 2.0,
			node_rect.position.y - tooltip_size.y - 12.0
		)
	var screen_rect: Rect2 = get_viewport_rect()
	target_pos.x = clampf(target_pos.x, 12.0, screen_rect.size.x - tooltip_size.x - 12.0)
	if target_pos.y < 12.0 and _hud_tooltip_node != null and _hud_tooltip_node.is_inside_tree():
		target_pos.y = _hud_tooltip_node.get_global_rect().end.y + 12.0
	target_pos.y = clampf(target_pos.y, 12.0, screen_rect.size.y - tooltip_size.y - 12.0)
	_hud_tooltip_panel.global_position = target_pos


func _play_round_feedback(events: Array) -> void:
	var action_groups: Array = _build_action_feedback_groups(events)
	for group_variant in action_groups:
		var group: Dictionary = group_variant
		await _play_action_feedback_group(group)


func _build_action_feedback_groups(events: Array) -> Array:
	var groups: Array = []
	var current_group: Dictionary = {}
	for event_variant in events:
		var event: Dictionary = event_variant
		if str(event.get("type", "")) == "action_start":
			if not current_group.is_empty():
				groups.append(current_group)
			current_group = {
				"action": event,
				"effects": [],
			}
		else:
			if current_group.is_empty():
				current_group = {
					"action": {},
					"effects": [],
				}
			current_group["effects"].append(event)
	if not current_group.is_empty():
		groups.append(current_group)
	return groups


func _play_action_feedback_group(group: Dictionary) -> void:
	var action: Dictionary = group.get("action", {}) as Dictionary
	var effects: Array = group.get("effects", []) as Array
	var action_kind: String = _get_action_feedback_kind(effects)
	var actor_card: UnitCard = null
	if not action.is_empty():
		actor_card = _find_card_by_state_id(str(action.get("side", "")), str(action.get("actor_id", "")))
	if actor_card != null:
		actor_card.play_action_feedback(action_kind)

	await get_tree().create_timer(ACTION_EFFECT_LEAD_TIME).timeout

	for event_variant in effects:
		var event: Dictionary = event_variant
		var event_type: String = str(event.get("type", ""))
		var target_card: UnitCard = _find_card_for_event(event)
		if target_card == null:
			continue
		target_card.play_impact_feedback(_get_impact_feedback_kind(event_type))
		_flash_card(target_card, event_type)
		_spawn_floating_text(target_card, event_type, int(event.get("amount", 0)))
		_apply_live_event_visual_state(event)
		_refresh_card_for_event(event)

	await get_tree().create_timer(ACTION_FEEDBACK_PAUSE).timeout


func _get_action_feedback_kind(effects: Array) -> String:
	for event_variant in effects:
		var event: Dictionary = event_variant
		var event_type: String = str(event.get("type", ""))
		if event_type == "damage" or event_type == "poison":
			return "attack"
	for event_variant in effects:
		var event: Dictionary = event_variant
		var event_type: String = str(event.get("type", ""))
		if event_type == "shield" or event_type == "heal" or event_type == "cloak" or event_type == "roll_buff" or event_type == "freeze":
			return "support"
	return "neutral"


func _get_impact_feedback_kind(event_type: String) -> String:
	match event_type:
		"shield", "block", "roll_buff", "freeze":
			return "shield"
		"heal", "cloak":
			return "heal"
		_:
			return "damage"


func _find_card_for_event(event: Dictionary) -> UnitCard:
	var side: String = str(event.get("side", ""))
	var target_id: String = str(event.get("target_id", ""))
	if target_id != "":
		return _find_card_by_state_id(side, target_id)
	var target_name: String = str(event.get("target_name", ""))
	var views: Array = hero_card_views if side == "hero" else enemy_card_views
	for view_variant in views:
		var view: Dictionary = view_variant
		var state: Dictionary = view["state"]
		var unit: Resource = state["unit"]
		if unit != null and str(unit.display_name) == target_name:
			return view["card"] as UnitCard
	return null


func _apply_live_event_visual_state(event: Dictionary) -> void:
	if dice_tray_3d == null:
		return
	if str(event.get("type", "")) == "freeze":
		dice_tray_3d.set_die_frozen_visual(str(event.get("side", "")), str(event.get("target_id", "")), true)


func _refresh_card_for_event(event: Dictionary) -> void:
	var side: String = str(event.get("side", ""))
	var target_id: String = str(event.get("target_id", ""))
	if side == "" or target_id == "":
		return
	var views: Array = hero_card_views if side == "hero" else enemy_card_views
	var accent: Color = HERO_ACCENT if side == "hero" else ENEMY_ACCENT
	var rolls: Dictionary = hero_rolls if side == "hero" else enemy_rolls
	for view_variant in views:
		var view: Dictionary = view_variant
		var state: Dictionary = view["state"]
		if str(state.get("id", "")) != target_id:
			continue
		_update_card_view(view["card"], state, rolls.get(target_id, null), accent)
		return


func _find_card_by_state_id(side: String, state_id: String) -> UnitCard:
	var views: Array = hero_card_views if side == "hero" else enemy_card_views
	for view_variant in views:
		var view: Dictionary = view_variant
		var state: Dictionary = view["state"]
		if str(state.get("id", "")) == state_id:
			return view["card"] as UnitCard
	return null


func _flash_card(card: UnitCard, event_type: String) -> void:
	var tween: Tween = create_tween()
	var base_modulate: Color = card.modulate
	var flash_color: Color = Color(1, 1, 1, 1)
	match event_type:
		"damage", "poison":
			flash_color = Color(1.0, 0.45, 0.45, 1.0)
		"heal":
			flash_color = Color(0.45, 1.0, 0.65, 1.0)
		"shield", "block", "roll_buff", "freeze":
			flash_color = Color(0.55, 0.82, 1.0, 1.0)
		"phase2":
			flash_color = Color(1.0, 0.45, 0.10, 1.0)
		"wipe_shields":
			flash_color = Color(1.0, 0.80, 0.20, 1.0)
	card.modulate = flash_color
	tween.tween_property(card, "modulate", base_modulate, 0.22)


func _spawn_floating_text(card: UnitCard, event_type: String, amount: int) -> void:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = _build_floating_text(event_type, amount)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", PixelUI.scale_font_size(20))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	label.add_theme_constant_override("outline_size", 4)
	label.z_as_relative = false
	label.z_index = 100
	label.position = _get_card_float_origin(card)
	label.modulate = _get_floating_color(event_type)
	float_layer.add_child(label)
	label.move_to_front()

	var tween: Tween = create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -52), 0.9)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tween.tween_callback(label.queue_free)


func _get_card_float_origin(card: UnitCard) -> Vector2:
	var card_rect: Rect2 = card.get_global_rect()
	var layer_origin: Vector2 = float_layer.get_global_position()
	return Vector2(
		card_rect.position.x - layer_origin.x + (card_rect.size.x * 0.5) - 40.0,
		card_rect.position.y - layer_origin.y + 18.0
	)


func _build_floating_text(event_type: String, amount: int) -> String:
	match event_type:
		"damage", "poison":
			return "-%d" % amount
		"heal":
			return "+%d" % amount
		"shield":
			return "SH +%d" % amount
		"roll_buff":
			return "+%d ROLL" % amount
		"freeze":
			return "FROZEN %d" % amount
		"block":
			return "BLOCK %d" % amount
		"phase2":
			return "⚡ PHASE 2"
		"wipe_shields":
			return "SHIELDS WIPED"
		_:
			return str(amount)


func _get_floating_color(event_type: String) -> Color:
	match event_type:
		"damage", "poison":
			return Color(1.0, 0.42, 0.42, 1.0)
		"heal":
			return Color(0.5, 1.0, 0.62, 1.0)
		"shield", "block", "roll_buff", "freeze":
			return Color(0.55, 0.82, 1.0, 1.0)
		"phase2":
			return Color(1.0, 0.45, 0.10, 1.0)
		"wipe_shields":
			return Color(1.0, 0.80, 0.20, 1.0)
		_:
			return Color(1, 1, 1, 1)


func _build_ability_tooltip(unit: Resource) -> String:
	var lines: Array = [str(unit.display_name)]
	for entry_variant in unit.dice_ranges:
		var entry: Dictionary = entry_variant
		lines.append("%d-%d  %s" % [
			int(entry.get("min", 0)),
			int(entry.get("max", 0)),
			str(entry.get("ability_name", "")),
		])
	return "\n".join(lines)


func _build_ability_chart_rows(unit: Resource) -> Array:
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
			"description": str(entry.get("description", "")),
			"chips": _build_effect_chips(raw),
		}
		if is_hero_unit and zone == "crit" and not overload_entry.is_empty():
			row["has_overload_marker"] = true
			row["overload_ability_name"] = str(overload_entry.get("ability_name", ""))
			row["overload_description"] = str(overload_entry.get("description", ""))
			row["overload_chips"] = _build_effect_chips(overload_entry.get("raw", {}))
		rows.append(row)
	return rows


func _get_gear_detail_rows(unit_id: String) -> Array:
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


func _refresh_roll_summaries() -> void:
	pass


func _reveal_roll_summaries_animated() -> void:
	pass


func _get_representative_roll() -> int:
	for state in combat_manager.get_hero_states():
		var uid: String = str(state["id"])
		var roll_value: int = int(hero_rolls.get(uid, 0))
		if roll_value > 0:
			return roll_value
	for state in combat_manager.get_enemy_states():
		var uid: String = str(state["id"])
		var roll_value: int = int(enemy_rolls.get(uid, 0))
		if roll_value > 0:
			return roll_value
	return 1


func _build_dice_section(container: VBoxContainer, states: Array, rolls: Dictionary,
		accent: Color, title: String) -> void:
	var header: Label = Label.new()
	header.text = title
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", PixelUI.scale_font_size(20))
	header.add_theme_color_override("font_color", accent.lightened(0.25))
	header.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.80))
	header.add_theme_constant_override("outline_size", 2)
	container.add_child(header)

	var flow: HFlowContainer = HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 5)
	container.add_child(flow)

	for state in states:
		var uid: String = str(state["id"])
		var final_val: int = int(rolls.get(uid, 0))
		if final_val == 0:
			continue
		var w: Dictionary = _make_die_widget(state, final_val, accent)
		flow.add_child(w["panel"])


func _build_dice_section_animated(container: VBoxContainer, states: Array, rolls: Dictionary,
		accent: Color, title: String, base_delay: float) -> void:
	var header: Label = Label.new()
	header.text = title
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", PixelUI.scale_font_size(20))
	header.add_theme_color_override("font_color", accent.lightened(0.25))
	header.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.80))
	header.add_theme_constant_override("outline_size", 2)
	container.add_child(header)

	var flow: HFlowContainer = HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 5)
	container.add_child(flow)

	var die_index: int = 0
	for state in states:
		var uid: String = str(state["id"])
		var final_val: int = int(rolls.get(uid, 0))
		if final_val == 0:
			continue
		# Start widget showing "?" with accent styling
		var w: Dictionary = _make_die_widget(state, 0, accent)
		flow.add_child(w["panel"])
		_animate_die(w["num_lbl"], w["panel"], final_val,
				base_delay + float(die_index) * 0.055)
		die_index += 1


func _make_die_widget(state: Dictionary, initial_val: int, accent: Color) -> Dictionary:
	var die_panel: PanelContainer = PanelContainer.new()
	die_panel.custom_minimum_size = Vector2(80, 88)
	die_panel.pivot_offset = Vector2(40, 44)
	die_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	die_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = accent.darkened(0.55)
	style.border_color = PixelUI.BLACK_EDGE
	style.set_border_width_all(4)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	die_panel.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 1)
	die_panel.add_child(vbox)

	var num_lbl: Label = Label.new()
	num_lbl.text = "?" if initial_val == 0 else str(initial_val)
	num_lbl.custom_minimum_size = Vector2(60, 52)
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	PixelUI.apply_pixel_font(num_lbl)
	num_lbl.add_theme_font_size_override("font_size", PixelUI.scale_font_size(34))
	num_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	num_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.90))
	num_lbl.add_theme_constant_override("outline_size", 3)
	if initial_val > 0:
		num_lbl.add_theme_color_override("font_color", _get_roll_num_color(initial_val))
	vbox.add_child(num_lbl)

	var unit_name: String = str(state["unit"].display_name)
	var name_lbl: Label = Label.new()
	name_lbl.text = unit_name.left(8)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.apply_pixel_font(name_lbl)
	name_lbl.add_theme_font_size_override("font_size", PixelUI.scale_font_size(16))
	name_lbl.add_theme_color_override("font_color", Color(0.72, 0.80, 0.90, 0.88))
	name_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.70))
	name_lbl.add_theme_constant_override("outline_size", 2)
	vbox.add_child(name_lbl)

	# Apply settled styling if initial value provided (static display)
	if initial_val > 0:
		var settled: StyleBoxFlat = StyleBoxFlat.new()
		settled.bg_color = _get_roll_bg_color(initial_val)
		settled.border_color = PixelUI.BLACK_EDGE
		settled.set_border_width_all(4)
		settled.corner_radius_top_left = 0
		settled.corner_radius_top_right = 0
		settled.corner_radius_bottom_left = 0
		settled.corner_radius_bottom_right = 0
		die_panel.add_theme_stylebox_override("panel", settled)

	return {"panel": die_panel, "num_lbl": num_lbl}


func _animate_die(num_lbl: Label, die_panel: PanelContainer, final_val: int,
		start_delay: float) -> void:
	var tween: Tween = create_tween()
	var cycles: int = 11
	var interval: float = 0.045
	die_panel.scale = Vector2(0.92, 0.92)
	die_panel.rotation_degrees = -10.0

	if start_delay > 0.0:
		tween.tween_interval(start_delay)

	tween.tween_property(die_panel, "scale", Vector2(1.12, 1.12), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Shuffle phase: rapid number changes plus a small 2D tumble.
	for _i in range(cycles):
		tween.tween_interval(interval)
		tween.tween_callback(func():
			if is_instance_valid(num_lbl) and is_instance_valid(die_panel):
				num_lbl.text = str(randi_range(1, 20))
				var lean_right: bool = randf() >= 0.5
				die_panel.rotation_degrees = 14.0 if lean_right else -14.0
				die_panel.scale = Vector2(1.10, 0.96) if lean_right else Vector2(0.96, 1.10)
		)

	# Final interval before settling
	tween.tween_interval(interval)

	# Settle: lock in final value and apply quality-based colors
	tween.tween_callback(func():
		if not is_instance_valid(num_lbl) or not is_instance_valid(die_panel):
			return
		num_lbl.text = str(final_val)
		num_lbl.add_theme_color_override("font_color", _get_roll_num_color(final_val))
		die_panel.rotation_degrees = 0.0
		die_panel.scale = Vector2(1.0, 1.0)
		var settled: StyleBoxFlat = StyleBoxFlat.new()
		settled.bg_color = _get_roll_bg_color(final_val)
		settled.border_color = PixelUI.BLACK_EDGE
		settled.set_border_width_all(4)
		settled.corner_radius_top_left = 0
		settled.corner_radius_top_right = 0
		settled.corner_radius_bottom_left = 0
		settled.corner_radius_bottom_right = 0
		die_panel.add_theme_stylebox_override("panel", settled)
	)

	# Settle flash: brief bright pulse then back to normal
	tween.tween_property(die_panel, "scale", Vector2(1.18, 1.18), 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(num_lbl, "modulate", Color(1.6, 1.5, 0.6, 1.0), 0.07)
	tween.tween_property(die_panel, "scale", Vector2(1.0, 1.0), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(num_lbl, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.16)


func _get_roll_bg_color(roll: int) -> Color:
	if roll == 20:
		return Color(0.38, 0.28, 0.04, 0.98)  # Deep gold — Overload
	if roll >= 16:
		return Color(0.10, 0.32, 0.18, 0.98)  # Dark green — Crit range
	if roll >= 10:
		return Color(0.12, 0.18, 0.30, 0.98)  # Dark blue — Normal
	if roll >= 5:
		return Color(0.32, 0.20, 0.08, 0.98)  # Dark orange — Suboptimal
	return Color(0.32, 0.10, 0.10, 0.98)      # Dark red — Low


func _get_roll_border_color(roll: int) -> Color:
	if roll == 20:
		return Color(1.0, 0.85, 0.20, 0.98)   # Gold
	if roll >= 16:
		return Color(0.42, 1.0, 0.60, 0.95)   # Bright green
	if roll >= 10:
		return Color(0.52, 0.74, 1.0, 0.95)   # Blue
	if roll >= 5:
		return Color(1.0, 0.66, 0.28, 0.95)   # Orange
	return Color(1.0, 0.38, 0.38, 0.95)       # Red


func _get_roll_num_color(roll: int) -> Color:
	if roll == 20:
		return Color(1.0, 0.92, 0.40, 1.0)    # Gold
	if roll >= 16:
		return Color(0.72, 1.0, 0.78, 1.0)    # Green
	if roll >= 10:
		return Color(0.88, 0.94, 1.0, 1.0)    # White-blue
	if roll >= 5:
		return Color(1.0, 0.82, 0.58, 1.0)    # Orange
	return Color(1.0, 0.66, 0.66, 1.0)        # Red


func _queue_board_layout_refresh() -> void:
	call_deferred("_refresh_board_layout")


func _refresh_board_layout() -> void:
	if not is_inside_tree():
		return
	if hero_scroll == null or enemy_scroll == null:
		return

	hero_cards.columns = 2
	enemy_cards.columns = 2
	hero_cards.add_theme_constant_override("h_separation", 4)
	hero_cards.add_theme_constant_override("v_separation", 4)
	enemy_cards.add_theme_constant_override("h_separation", 4)
	enemy_cards.add_theme_constant_override("v_separation", 4)
	hero_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_cards.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	enemy_cards.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var horizontal_gap: float = maxf(
		float(hero_cards.get_theme_constant("h_separation")),
		float(enemy_cards.get_theme_constant("h_separation"))
	)
	var vertical_gap: float = maxf(
		float(hero_cards.get_theme_constant("v_separation")),
		float(enemy_cards.get_theme_constant("v_separation"))
	)
	var panel_padding: float = 6.0
	var usable_width: float = maxf(minf(hero_scroll.size.x, enemy_scroll.size.x), 300.0)
	var card_width: float = clampf(floor((usable_width - horizontal_gap - panel_padding) / 2.0), 120.0, 720.0)
	var card_height: float = clampf(floor(card_width * 0.82), 116.0, 620.0)

	_apply_card_slots(hero_cards, Vector2(card_width, card_height))
	_apply_card_slots(enemy_cards, Vector2(card_width, card_height))

	var two_row_height: float = (card_height * 2.0) + vertical_gap + panel_padding
	hero_panel.custom_minimum_size = Vector2(0, two_row_height)
	enemy_panel.custom_minimum_size = Vector2(0, two_row_height)
	hero_panel.size_flags_stretch_ratio = 2.0
	enemy_panel.size_flags_stretch_ratio = 2.0
	center_panel.custom_minimum_size = Vector2(0, 420)
	center_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _apply_card_slots(container: GridContainer, slot_size: Vector2) -> void:
	for child_variant in container.get_children():
		var slot: Control = child_variant as Control
		if slot == null:
			continue
		slot.custom_minimum_size = Vector2(0, slot_size.y)
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


func _build_effect_chips(raw: Dictionary) -> Array:
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
	if shield > 0:
		chips.append(_make_effect_chip("⬢", "%d" % shield, Color(0.15, 0.32, 0.50, 0.98), Color(0.58, 0.82, 1.0, 0.95), "grants %d shield for %d turn%s" % [shield, shield_turns, "" if shield_turns == 1 else "s"], shield_turns))
	if shield_ally > 0:
		chips.append(_make_effect_chip("⬢", "%dA" % shield_ally, Color(0.15, 0.32, 0.50, 0.98), Color(0.58, 0.82, 1.0, 0.95), "grants %d shield to an ally for %d turn%s" % [shield_ally, ally_shield_turns, "" if ally_shield_turns == 1 else "s"], ally_shield_turns))
	if heal > 0:
		chips.append(_make_effect_chip("✚", "%d" % heal, Color(0.12, 0.38, 0.23, 0.98), Color(0.52, 1.0, 0.68, 0.95), "restores %d health" % heal))
	if lifesteal_pct > 0:
		chips.append(_make_effect_chip("✚", "%d%%" % lifesteal_pct, Color(0.10, 0.32, 0.22, 0.98), Color(0.44, 1.0, 0.62, 0.95), "lifesteals %d%% of damage dealt — heals this unit for a portion of damage inflicted this turn" % lifesteal_pct))
	if dot > 0:
		chips.append(_make_effect_chip("◌", "%d" % dot, Color(0.43, 0.19, 0.22, 0.98), Color(1.0, 0.60, 0.64, 0.95), "inflicts %d poison for %d turn%s" % [dot, dot_turns, "" if dot_turns == 1 else "s"], dot_turns))
	if roll_mod > 0:
		chips.append(_make_effect_chip("◫", "-%d" % roll_mod, Color(0.46, 0.34, 0.14, 0.98), Color(0.96, 0.78, 0.42, 0.95), "modifies roll by -%d for %d turn%s" % [roll_mod, roll_mod_turns, "" if roll_mod_turns == 1 else "s"], roll_mod_turns))
	if bool(raw.get("blastAll", false)):
		chips.append(_make_effect_chip("◎", "A", Color(0.52, 0.20, 0.18, 0.98), Color(1.0, 0.56, 0.44, 0.95), "affects all valid targets"))
	if bool(raw.get("healAll", false)):
		chips.append(_make_effect_chip("◎", "A", Color(0.12, 0.38, 0.23, 0.98), Color(0.52, 1.0, 0.68, 0.95), "affects all valid targets"))
	if freeze_turns > 0:
		chips.append(_make_effect_chip("*", "%d" % freeze_turns, Color(0.12, 0.34, 0.48, 0.98), Color(0.62, 0.92, 1.0, 0.95), "freezes a die for %d reveal%s" % [freeze_turns, "" if freeze_turns == 1 else "s"], freeze_turns))
	return chips


func _make_effect_chip(icon: String, text: String, bg: Color, border: Color, tooltip: String = "", duration: int = 0) -> Dictionary:
	return {
		"icon": icon,
		"text": text,
		"color": bg,
		"border": border,
		"tooltip": tooltip,
		"duration": duration,
	}


func _apply_battle_theme() -> void:
	background.color = Color(0.030, 0.050, 0.080, 1.0)
	PixelUI.style_label(summary_label, 30, PixelUI.TEXT_PRIMARY, 2)
	PixelUI.style_panel(hero_panel, Color(0.028, 0.050, 0.074, 0.46), Color(0.17, 0.54, 0.44, 0.70), 4, 0)
	PixelUI.style_panel(center_panel, Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0, 0)
	PixelUI.style_panel(enemy_panel, Color(0.028, 0.050, 0.074, 0.46), Color(0.58, 0.26, 0.26, 0.70), 4, 0)
	PixelUI.style_panel(protocol_panel, Color(0.028, 0.050, 0.074, 0.50), Color(0.18, 0.32, 0.48, 0.70), 4, 0)
	PixelUI.style_panel(battle_log_panel, Color(0.028, 0.050, 0.074, 0.58), Color(0.18, 0.32, 0.48, 0.76), 4, 0)
	PixelUI.style_button(toggle_log_button, PixelUI.BG_PANEL_ALT, PixelUI.LINE_DIM, 28)
	PixelUI.style_button(roll_button, PixelUI.BG_PANEL_ALT, PixelUI.LINE_BRIGHT, 34)
	PixelUI.style_button(protocol_spend_button, PixelUI.BG_PANEL_ALT, PixelUI.HERO_ACCENT, 38)
	PixelUI.style_button(return_to_menu_button, PixelUI.BG_PANEL_ALT, PixelUI.LINE_DIM, 28)
	PixelUI.style_progress_bar(protocol_bar, PixelUI.GOLD_ACCENT, Color(0.015, 0.020, 0.035, 1.0), PixelUI.LINE_DIM)


func _build_scaled_enemy(base_enemy: EnemyData, battle_index: int, track_scale: float) -> EnemyData:
	var scaled_enemy: EnemyData = base_enemy.duplicate(true) as EnemyData
	if scaled_enemy == null:
		return base_enemy

	var battle_number: int = battle_index + 1
	var multiplier: float = 1.0 + (float(maxi(battle_number - 1, 0)) * 0.10 * maxf(track_scale, 0.5))
	if battle_number >= _game_state().total_battles:
		multiplier += 0.2

	scaled_enemy.max_hp = maxi(1, int(round(float(base_enemy.max_hp) * multiplier)))
	scaled_enemy.damage_preview_min = maxi(0, int(round(float(base_enemy.damage_preview_min) * multiplier)))
	scaled_enemy.damage_preview_max = maxi(0, int(round(float(base_enemy.damage_preview_max) * multiplier)))
	scaled_enemy.phase_two_damage_preview_min = maxi(0, int(round(float(base_enemy.phase_two_damage_preview_min) * multiplier)))
	scaled_enemy.phase_two_damage_preview_max = maxi(0, int(round(float(base_enemy.phase_two_damage_preview_max) * multiplier)))
	# Scale phase 2 threshold proportionally so it stays at ~50% of scaled max HP
	if int(base_enemy.phase_two_threshold) > 0:
		scaled_enemy.phase_two_threshold = maxi(0, int(round(float(base_enemy.phase_two_threshold) * multiplier)))
	return scaled_enemy


# --- Item System (Phase 3) ---

func _get_item_protocol_cost(item: ItemData) -> int:
	if combat_manager.has_relic("protocolFree"):
		return 0
	match item.rarity:
		"common":
			return 0
		"uncommon":
			return 1
		"rare":
			return 2
		"legendary":
			return 3
	return 1


func _build_item_panel() -> void:
	_item_panel = HBoxContainer.new()
	_item_panel.add_theme_constant_override("separation", 10)
	_item_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_item_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var protocol_row: HBoxContainer = protocol_panel.get_node("ProtocolMargin/ProtocolRow") as HBoxContainer
	protocol_row.add_child(_item_panel)
	_update_item_panel()


func _build_relic_slot() -> void:
	var protocol_row: HBoxContainer = protocol_panel.get_node("ProtocolMargin/ProtocolRow") as HBoxContainer
	var slot: PanelContainer = PanelContainer.new()
	_relic_slot = slot
	slot.custom_minimum_size = Vector2(78, 72)
	_set_hud_tooltip(slot, "Relic\nNo relic equipped.")
	PixelUI.style_panel(slot, Color(0.06, 0.08, 0.13, 0.85), PixelUI.GOLD_ACCENT, 2, 0)

	var label: Label = Label.new()
	label.name = "RelicLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", PixelUI.scale_font_size(38))
	label.add_theme_color_override("font_color", PixelUI.GOLD_ACCENT)
	slot.add_child(label)

	protocol_row.add_child(slot)
	_update_relic_slot()


func _update_relic_slot() -> void:
	if _relic_slot == null:
		return
	var label: Label = _relic_slot.get_node_or_null("RelicLabel") as Label
	var relic_ids: Array = _game_state().relics
	if relic_ids.is_empty():
		_set_hud_tooltip(_relic_slot, "Relic\nNo relic equipped.")
		if label != null:
			label.text = "◇"
		return

	var relic: ItemData = _data_manager().get_item(str(relic_ids[0])) as ItemData
	if relic == null:
		_set_hud_tooltip(_relic_slot, "Relic\nUnknown relic.")
		if label != null:
			label.text = "?"
		return

	_set_hud_tooltip(_relic_slot, _build_relic_tooltip(relic))
	if label != null:
		label.text = _get_item_icon_char(relic.icon_key)


func _update_item_panel() -> void:
	if _item_panel == null:
		return
	for child in _item_panel.get_children():
		child.queue_free()

	var item_ids: Array = _game_state().consumables
	for slot_index in range(3):
		if slot_index < item_ids.size():
			var item: ItemData = _data_manager().get_item(str(item_ids[slot_index])) as ItemData
			if item != null:
				_add_item_slot_filled(item)
				continue
		_add_item_slot_empty()


func _add_item_slot_empty() -> void:
	var slot: PanelContainer = PanelContainer.new()
	slot.custom_minimum_size = Vector2(78, 72)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.13, 0.85)
	style.border_color = PixelUI.BLACK_EDGE
	style.set_border_width_all(2)
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	slot.add_theme_stylebox_override("panel", style)
	var lbl: Label = Label.new()
	lbl.text = "○"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", PixelUI.scale_font_size(38))
	lbl.add_theme_color_override("font_color", Color(0.28, 0.32, 0.42, 0.55))
	slot.add_child(lbl)
	_item_panel.add_child(slot)


func _add_item_slot_filled(item: ItemData) -> void:
	var rarity_color: Color = _get_item_rarity_color(item.rarity)
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(78, 72)
	btn.text = _get_item_icon_char(item.icon_key)
	_set_hud_tooltip(btn, _build_item_tooltip(item))
	PixelUI.style_button(btn, rarity_color.darkened(0.52), rarity_color, 38)
	btn.pressed.connect(_on_item_button_pressed.bind(item))
	_item_panel.add_child(btn)


func _build_item_tooltip(item: ItemData) -> String:
	var cost: int = _get_item_protocol_cost(item)
	var target_text: String = _format_item_target_kind(item.target_kind)
	return "%s\n%s\nTarget: %s\nProtocol cost: %d" % [
		item.display_name,
		item.description,
		target_text,
		cost,
	]


func _build_relic_tooltip(relic: ItemData) -> String:
	return "%s\n%s" % [relic.display_name, relic.description]


func _format_item_target_kind(target_kind: String) -> String:
	match target_kind:
		"ally":
			return "living ally"
		"allyDead":
			return "fallen ally"
		"enemy":
			return "living enemy"
		"none":
			return "none"
	return target_kind


func _get_item_icon_char(icon_key: String) -> String:
	match icon_key:
		"heart":  return "♥"
		"shield": return "⬡"
		"die":    return "⚄"
		"bolt":   return "⚡"
		"skull":  return "☠"
		"cloak":  return "◉"
		"star":   return "★"
	return "●"


func _get_item_rarity_color(rarity: String) -> Color:
	match rarity:
		"common":    return Color(0.55, 0.60, 0.66, 1.0)
		"uncommon":  return Color(0.35, 0.82, 0.48, 1.0)
		"rare":      return Color(0.38, 0.62, 1.00, 1.0)
		"legendary": return Color(1.00, 0.72, 0.20, 1.0)
	return Color(0.55, 0.60, 0.66, 1.0)


func _on_item_button_pressed(item: ItemData) -> void:
	if battle_over:
		return
	if not _can_use_item_in_current_phase():
		_refresh_summary("Items can only be used before rolling, during targeting, or before ending the turn.")
		return
	var cost: int = _get_item_protocol_cost(item)
	if protocol_points < cost:
		_refresh_summary("Need %d Protocol to use %s." % [cost, item.display_name])
		return

	_was_in_ready_phase = (turn_phase == PHASE_READY_TO_END)
	_phase_before_item = turn_phase
	_pending_item = item

	match item.target_kind:
		"ally":
			if _get_legal_target_ids("hero").is_empty():
				_cancel_item_targeting("No living ally can use %s." % item.display_name)
				return
			_set_turn_phase(PHASE_ITEM_PICK_ALLY)
		"allyDead":
			_cancel_item_targeting("Downed units cannot be targeted by %s." % item.display_name)
			return
		"enemy":
			if _get_legal_target_ids("enemy").is_empty():
				_cancel_item_targeting("No living enemy can be targeted by %s." % item.display_name)
				return
			_set_turn_phase(PHASE_ITEM_PICK_ENEMY)
		"none":
			# No target needed — apply immediately
			_apply_item_effect(item, {})
		_:
			_cancel_item_targeting("%s cannot find a valid target type." % item.display_name)


func _cancel_item_targeting(message: String) -> void:
	_pending_item = null
	legal_target_ids.clear()
	legal_target_side = ""
	_restore_phase_after_item()
	_refresh_summary(message)


func _can_use_item_in_current_phase() -> bool:
	return turn_phase == PHASE_AWAIT_ROLL or turn_phase == PHASE_TARGETING or turn_phase == PHASE_READY_TO_END


func _restore_phase_after_item() -> void:
	var restore_phase: String = _phase_before_item
	_phase_before_item = ""
	_was_in_ready_phase = false
	if restore_phase == PHASE_READY_TO_END:
		_set_turn_phase(PHASE_READY_TO_END)
	elif restore_phase == PHASE_TARGETING:
		_set_turn_phase(PHASE_TARGETING)
		if active_targeting_hero_id != "":
			_select_targeting_hero(active_targeting_hero_id)
	else:
		_set_turn_phase(PHASE_AWAIT_ROLL)


func _apply_item_effect(item: ItemData, target_state: Dictionary) -> void:
	if item == null:
		return
	var cost: int = _get_item_protocol_cost(item)
	protocol_points = maxi(protocol_points - cost, 0)

	var effect: Dictionary = item.effect
	var effect_type: String = str(effect.get("type", ""))
	var tname: String = _state_unit_name(target_state)

	match effect_type:
		"heal":
			var amount: int = int(effect.get("amount", 0))
			combat_manager.apply_item_heal(target_state, amount)
			_append_log("Item: %s heals %s for %d." % [item.display_name, tname, amount])
		"shield":
			var amount: int = int(effect.get("amount", 0))
			var turns: int = int(effect.get("shT", 1))
			combat_manager.apply_item_shield(target_state, amount, turns)
			_append_log("Item: %s grants %d shield (%d turns) to %s." % [item.display_name, amount, turns, tname])
		"rollBuff":
			var amount: int = int(effect.get("amount", 0))
			var turns: int = int(effect.get("turns", 1))
			combat_manager.apply_item_roll_buff(target_state, amount, turns)
			_append_log("Item: %s gives %s +%d roll for %d turns." % [item.display_name, tname, amount, turns])
		"revive":
			var pct: int = int(effect.get("pct", 50))
			combat_manager.apply_item_revive(target_state, pct)
			_append_log("Item: %s revives %s at %d%% HP." % [item.display_name, tname, pct])
		"cloak":
			target_state["cloaked"] = true
			_append_log("Item: %s cloaks %s." % [item.display_name, tname])
		"cloakAll":
			for hero_state in combat_manager.get_hero_states():
				if not bool(hero_state.get("dead", true)):
					hero_state["cloaked"] = true
			_append_log("Item: %s — all living allies cloaked." % item.display_name)
		"enemyRfe":
			var amount: int = int(effect.get("amount", 0))
			var turns: int = int(effect.get("rfT", 1))
			combat_manager.apply_item_rfe(target_state, amount, turns)
			_append_log("Item: %s applies -%d RFE to %s for %d turns." % [item.display_name, amount, tname, turns])
		"enemyDmg":
			var amount: int = int(effect.get("amount", 0))
			combat_manager.apply_item_damage(target_state, amount)
			_append_log("Item: %s deals %d damage to %s." % [item.display_name, amount, tname])
		"enemyDot":
			var amount: int = int(effect.get("amount", 0))
			var turns: int = int(effect.get("dT", 1))
			combat_manager.apply_item_dot(target_state, amount, turns)
			_append_log("Item: %s applies %d poison to %s for %d turns." % [item.display_name, amount, tname, turns])
		"xpBoost":
			# Phase 5 wires GameState.add_unit_xp; guarded so it won't crash before then
			var amount: int = int(effect.get("amount", 0))
			for hero_state in combat_manager.get_hero_states():
				if not bool(hero_state.get("dead", true)):
					var unit: UnitData = hero_state.get("unit") as UnitData
					if unit != null and _game_state().has_method("add_unit_xp"):
						_game_state().add_unit_xp(str(unit.id), amount)
			_append_log("Item: %s — all living allies +%d XP." % [item.display_name, amount])
		"enemyRerollDie":
			if not target_state.is_empty():
				var uid: String = str(target_state["id"])
				var new_roll: int = dice_manager.roll_d20()
				enemy_rolls[uid] = new_roll
				_append_log("Item: %s rerolls %s → %d." % [item.display_name, tname, new_roll])
		"enemyRerollAll":
			for enemy_state in combat_manager.get_enemy_states():
				if not bool(enemy_state.get("dead", true)):
					var uid: String = str(enemy_state["id"])
					var new_roll: int = dice_manager.roll_d20()
					enemy_rolls[uid] = new_roll
			_append_log("Item: %s — all enemies rerolled." % item.display_name)
		"enemyDieFreeze":
			if not target_state.is_empty():
				var skips: int = int(effect.get("skips", 1))
				target_state["die_freeze_turns"] = int(target_state.get("die_freeze_turns", 0)) + skips
				var frozen_value: int = _get_roll_value_for_state(enemy_rolls, target_state)
				if frozen_value <= 0:
					frozen_value = int(target_state.get("last_die_value", target_state.get("frozen_die_value", 0)))
				if frozen_value > 0:
					target_state["frozen_die_value"] = frozen_value
				_append_log("Item: %s freezes %s's die for %d turns." % [item.display_name, tname, skips])

	_consume_item(item.id)
	_pending_item = null
	legal_target_ids.clear()
	legal_target_side = ""
	_refresh_all_cards()
	_update_protocol_bar()
	if _try_finish_battle_from_current_state():
		return

	_restore_phase_after_item()


func _consume_item(item_id: String) -> void:
	var consumables: Array = _game_state().consumables
	for i in range(consumables.size()):
		if str(consumables[i]) == item_id:
			consumables.remove_at(i)
			break
	_update_item_panel()


func _state_unit_name(state: Dictionary) -> String:
	if state.is_empty():
		return "?"
	var u: Object = state.get("unit") as Object
	if u == null:
		return "?"
	var name_val = u.get("display_name")
	return str(name_val) if name_val != null else "?"


# --- Phase 4: Summon event processing ---

func _process_summon_events(events: Array) -> void:
	for event in events:
		if str(event.get("type", "")) != "summon":
			continue
		# Cap total enemies to prevent runaway summon chains
		if combat_manager.get_enemy_states().size() >= 6:
			_append_log("Enemy cap reached — summon blocked.")
			continue
		var summon_name: String = str(event.get("summon_name", ""))
		if summon_name == "":
			continue
		var base_enemy: EnemyData = _data_manager().get_enemy_by_display_name(summon_name) as EnemyData
		if base_enemy == null:
			_append_log("Summon failed: '%s' not found in data." % summon_name)
			continue
		var operation: OperationData = _data_manager().get_operation(_game_state().selected_operation_id) as OperationData
		var track_scale: float = operation.track_hp_scale if operation != null else 1.0
		var battle_index: int = maxi(_game_state().current_battle - 1, 0)
		var scaled: EnemyData = _build_scaled_enemy(base_enemy, battle_index, track_scale)
		# Inject runtime state into CombatManager and rebuild the enemy card list
		combat_manager.inject_enemy(scaled)
		enemy_units.append(scaled)
		_populate_enemy_cards()
		_append_log("%s joins the battle!" % scaled.display_name)
