# Phase 5 battle scene shell that renders cards, rolls dice, and resolves a basic combat loop.
extends Control

@onready var board: VBoxContainer = %Board
@onready var background: TextureRect = $Background
@onready var hero_panel: PanelContainer = %HeroPanel
@onready var hero_scroll: VBoxContainer = %HeroScroll
@onready var hero_dice_row: HBoxContainer = %HeroDiceRow
@onready var hero_readouts: HBoxContainer = %HeroReadouts
@onready var hero_cards: HBoxContainer = %HeroCards
@onready var center_panel: PanelContainer = %CenterPanel
@onready var enemy_panel: PanelContainer = %EnemyPanel
@onready var enemy_scroll: VBoxContainer = %EnemyScroll
@onready var enemy_cards: HBoxContainer = %EnemyCards
@onready var enemy_readouts: HBoxContainer = %EnemyReadouts
@onready var enemy_dice_row: HBoxContainer = %EnemyDiceRow
@onready var protocol_bar: ProgressBar = %ProtocolBar
@onready var protocol_label: Label = %ProtocolLabel
@onready var protocol_value_label: Label = %ProtocolValueLabel
@onready var battle_log_label: RichTextLabel = %BattleLogLabel
@onready var battle_log_panel: PanelContainer = %BattleLogPanel
@onready var protocol_panel: PanelContainer = %ProtocolPanel
@onready var roll_button: Button = %RollButton
@onready var protocol_spend_button: Button = %ProtocolSpendButton
@onready var float_layer: Control = %FloatLayer
@onready var dice_tray_3d: DiceTray3D = %DiceTray3D

const ABILITY_READOUT_SCENE := preload("res://scenes/shared/AbilityReadout.tscn")
const HERO_ACCENT := Color(0.38, 0.64, 0.92, 1.0)
const ENEMY_ACCENT := Color(0.42, 0.54, 0.68, 1.0)
const PHASE_AWAIT_ROLL := "await_roll"
const PHASE_TARGETING := "targeting"
const PHASE_READY_TO_END := "ready_to_end"
const PHASE_REROLL_PICK := "reroll_pick"
const PHASE_NUDGE_PICK := "nudge_pick"
const PHASE_SET_PICK := "set_pick"
const SET_DIE_COST := 3
const PHASE_ITEM_PICK_ALLY := "item_pick_ally"
const PHASE_ITEM_PICK_DEAD := "item_pick_dead"
const PHASE_ITEM_PICK_ENEMY := "item_pick_enemy"
# No-target items: show the card centered and wait for a confirm tap (tap card = activate,
# tap off = cancel) instead of applying immediately.
const PHASE_ITEM_CONFIRM := "item_confirm"
const ACTION_FEEDBACK_PAUSE := 0.34
const ACTION_EFFECT_LEAD_TIME := 0.10
const AUTO_TURN_TARGET_PAUSE := 0.16
const DICE_THREE_UNIT_SIDE_OFFSET_PX := 0.0
const DICE_ENEMY_SNAP_TOP_PX := 220.0
const DICE_HERO_SNAP_BOTTOM_PX := 56.0
const DICE_BUTTON_CLEARANCE_PX := 132.0
const MAX_PROTOCOL := 10
const PROTOCOL_FOOTER_BAR_TEXTURE := "res://assets/ui/protocol_footer_bar_scifi.png"
const PROTOCOL_FOOTER_SOURCE_SIZE := Vector2(1330, 265)
const PROTOCOL_LIGHT_RECTS := [
	Rect2(126, 125, 61, 61),
	Rect2(239, 125, 61, 61),
	Rect2(352, 125, 61, 61),
	Rect2(465, 125, 61, 61),
	Rect2(578, 125, 61, 61),
	Rect2(691, 125, 61, 61),
	Rect2(804, 125, 61, 61),
	Rect2(917, 125, 61, 61),
	Rect2(1030, 125, 61, 61),
	Rect2(1143, 125, 61, 61),
]
const DICE_CARD_CLEARANCE_PX := 96.0
const COMBAT_ZONE_READOUT_GAP_PX := 18.0
const COMPACT_PORTRAIT_EXTRA_HEIGHT_PX := 52.0
const COMPACT_RAIL_CHROME_PX := 24.0
const HEADER_BUTTON_SIZE := Vector2(112, 112)
const BOTTOM_BAR_BUTTON_SIZE := Vector2(112, 112)
const ITEM_SLOT_SIZE := Vector2(112, 112)
const ITEM_ICON_SIZE := Vector2(76, 76)
const CENTER_ACTION_BUTTON_SIZE := Vector2(640, 136)
const CENTER_ACTION_BUTTON_FONT_SIZE := 48
const CENTER_PROMPT_FONT_SIZE := 32
const HEADER_SUMMARY_FONT_SIZE := 112
const HEADER_COUNTER_FONT_SIZE := 36
const PROTOCOL_LABEL_FONT_SIZE := 70
const PROTOCOL_VALUE_FONT_SIZE := 48

var dice_manager: DiceManager = DiceManager.new()
var combat_manager: CombatManager = CombatManager.new()
var protocol_points: int = 0  # battles start at 0; +1 income at end of each turn
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
var has_player_target_assignment: bool = false
var battle_over: bool = false
var hero_roll_nudges: Dictionary = {}
var hero_roll_sets: Dictionary = {}  # hero_id -> absolute effective roll set via the Set action
var _battle_consumables: Array = []
var _item_button: Button = null
var _nudge_button: Button = null
var _set_button: Button = null
var _suppress_protocol_press: bool = false
var _set_value_menu: PopupMenu = null
var _pending_set_hero_id: String = ""
var _item_menu: PopupMenu = null
var _item_menu_items: Array = []
var _relic_slot: Control = null
var _protocol_footer_display: Control = null
var _protocol_footer_lights: Array = []
var _protocol_footer_spacer: Control = null
var _header_frame: PanelContainer = null
var _footer_frame: PanelContainer = null
var _die_tooltip_overlays: Array = []
var _layout: BattleLayout = null
var _card_view: BattleCardView = null
var _feedback: BattleFeedback = null
var _pending_item: ItemData = null
var _item_targeting_card: Node = null
var _item_targeting_armed: bool = false
var _was_in_ready_phase: bool = false
var _phase_before_item: String = ""
var _round_complete_modal: Control = null
var _round_complete_next_button: Button = null
var _auto_turn_running: bool = false
var _auto_battle_running: bool = false

var _is_resolving_turn: bool = false


func _game_state() -> Variant:
	return get_node("/root/GameState")


func _data_manager() -> Variant:
	return get_node("/root/DataManager")


func _scene_manager() -> Variant:
	return get_node("/root/SceneManager")


func _ready() -> void:
	_layout = BattleLayout.new()
	add_child(_layout)
	_layout.setup(self)
	_card_view = BattleCardView.new()
	add_child(_card_view)
	_card_view.setup(self)
	_feedback = BattleFeedback.new()
	add_child(_feedback)
	_feedback.setup(self)
	_apply_battle_theme()
	_build_round_complete_modal()
	_update_battle_header()
	_build_runtime_units()
	combat_manager.setup_battle(hero_units, enemy_units)
	_game_state().begin_battle_xp_tracking()
	combat_manager.setup_relics(_game_state().relics)
	combat_manager.setup_gear(_game_state().gear_by_unit)
	protocol_points = _game_state().take_carried_protocol()
	if combat_manager.has_relic("battleStartConsumable"):
		var consumable_count: int = int(combat_manager.get_relic_value("battleStartConsumable", "amount", 1))
		_game_state().grant_battle_start_consumables(consumable_count)
	var battle_index: int = maxi(_game_state().current_battle - 1, 0)
	combat_manager.apply_battle_start_relic_effects(battle_index)
	combat_manager.apply_battle_start_gear_effects()
	# Protocol Tap gear: sum gear_protocol_on_start from hero states
	for _hs in combat_manager.get_hero_states():
		protocol_points += int(_hs.get("gear_protocol_on_start", 0))
	protocol_points = mini(protocol_points, MAX_PROTOCOL)
	_update_protocol_bar()
	_populate_hero_cards()
	_populate_enemy_cards()
	dice_tray_3d.reset()
	_set_battle_log_visible(false)
	_append_log("Battle initialized.")
	_set_turn_phase(PHASE_AWAIT_ROLL)
	_layout.queue_board_layout_refresh()
	# Wire protocol_spend_button as Reroll and add a Nudge button alongside it
	protocol_spend_button.text = "↺"
	# The header bar lives in the PersistentHeader autoload now — bind its buttons to
	# this battle's handlers. They go inert again when this scene exits the tree.
	# Help ("?") is handled globally by PersistentHeader → HelpMenu, so no help binding here.
	PersistentHeader.bind_battle_actions(
		Callable(),
		_on_auto_turn_button_pressed,
		_on_auto_battle_button_pressed,
		_on_return_to_menu_button_pressed,
	)
	protocol_spend_button.pressed.connect(_on_reroll_button_pressed)
	_attach_protocol_inspect(protocol_spend_button, "reroll")
	_add_nudge_button()
	_add_set_button()
	_build_item_panel()
	# Portrait mode: order is Enemy (top) → Center → Hero (bottom)
	board.move_child(enemy_panel, 0)
	board.move_child(center_panel, 1)
	board.move_child(hero_panel, 2)
	Callable(_layout, "stabilize_board_layout").call_deferred()


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
	AudioManager.play_select()
	_game_state().reset_run()
	_scene_manager().go_to_unit_select()


func _on_auto_turn_button_pressed() -> void:
	if _auto_turn_running or _auto_battle_running or battle_over:
		return
	if turn_phase == PHASE_REROLL_PICK or turn_phase == PHASE_NUDGE_PICK or turn_phase == PHASE_SET_PICK or turn_phase.begins_with("item_pick"):
		_refresh_summary("Finish the current picker before auto-completing the turn.")
		return
	_auto_turn_running = true
	AudioManager.set_suppressed(true)
	PersistentHeader.set_debug_enabled(false)
	_append_log("AUTO: completing the current turn.")
	if turn_phase == PHASE_AWAIT_ROLL:
		await _begin_targeting_phase()
	if turn_phase == PHASE_TARGETING:
		await _auto_assign_pending_targets()
	if turn_phase == PHASE_READY_TO_END:
		await _resolve_current_turn()
	_auto_turn_running = false
	AudioManager.set_suppressed(false)
	PersistentHeader.set_debug_enabled(true)


func _on_auto_battle_button_pressed() -> void:
	if _auto_turn_running or _auto_battle_running:
		return
	if battle_over:
		_on_open_reward_button_pressed()
		return
	if turn_phase == PHASE_REROLL_PICK or turn_phase == PHASE_NUDGE_PICK or turn_phase == PHASE_SET_PICK or turn_phase.begins_with("item_pick"):
		_refresh_summary("Finish the current picker before auto-completing the battle.")
		return

	_auto_battle_running = true
	AudioManager.set_suppressed(true)
	PersistentHeader.set_debug2_enabled(false)
	PersistentHeader.set_debug_enabled(false)
	_append_log("AUTO: completing the current battle.")

	var safety_rounds := 60
	while is_inside_tree() and not battle_over and safety_rounds > 0:
		safety_rounds -= 1
		if turn_phase == PHASE_AWAIT_ROLL:
			await _begin_targeting_phase(true)
		if not is_inside_tree() or battle_over:
			break
		if turn_phase == PHASE_TARGETING:
			await _auto_assign_pending_targets(false)
		if not is_inside_tree() or battle_over:
			break
		if turn_phase == PHASE_READY_TO_END:
			await _resolve_current_turn(true)
		else:
			break
		if not is_inside_tree() or get_tree() == null:
			break
		await get_tree().process_frame

	if not is_inside_tree():
		return

	if safety_rounds <= 0 and is_inside_tree() and not battle_over:
		_append_log("AUTO: battle completion stopped after safety limit.")
		_refresh_summary("Auto battle stopped after safety limit.")

	_auto_battle_running = false
	AudioManager.set_suppressed(false)
	PersistentHeader.set_debug2_enabled(true)
	PersistentHeader.set_debug_enabled(true)


func _exit_tree() -> void:
	AudioManager.set_suppressed(false)
	# Header survives scene changes; release this battle's button bindings so its
	# buttons go inert on the screens that follow (reward / evolution / home).
	if is_instance_valid(PersistentHeader):
		PersistentHeader.clear_battle_actions()
		PersistentHeader.set_debug_enabled(true)
		PersistentHeader.set_debug2_enabled(true)


func _populate_hero_cards() -> void:
	_clear_container(hero_cards)
	_clear_container(hero_readouts)
	_clear_container(hero_dice_row)
	hero_card_views.clear()
	var hero_states: Array = combat_manager.get_hero_states()
	var card_slots: Array = _layout.build_row_slots(hero_cards, hero_states.size())
	var readout_slots: Array = _layout.build_row_slots(hero_readouts, hero_states.size())
	var dice_slots: Array = _layout.build_row_slots(hero_dice_row, hero_states.size())
	for i in range(hero_states.size()):
		var hero_state: Dictionary = hero_states[i]
		var unit: UnitData = hero_state["unit"] as UnitData
		if unit == null:
			continue

		var card: Control = _create_battle_card()
		var readout: Control = ABILITY_READOUT_SCENE.instantiate() as Control
		var dice_anchor: Control = _layout.build_dice_anchor()
		var slot_index: int = i
		(card_slots[slot_index] as Control).add_child(card)
		(readout_slots[slot_index] as Control).add_child(readout)
		(dice_slots[slot_index] as Control).add_child(dice_anchor)
		_layout.prepare_battle_card_layout(card)
		_layout.prepare_ability_readout_layout(readout)
		hero_card_views.append({
			"card": card,
			"readout": readout,
			"dice_anchor": dice_anchor,
			"state": hero_state,
			"slot_index": slot_index,
		})
		card.card_pressed.connect(_on_hero_card_pressed.bind(hero_state["id"]))
		if card.has_signal("unit_detail_requested"):
			card.connect("unit_detail_requested", Callable(self, "_on_unit_detail_requested"))
		_card_view.update_card_view(card, hero_state, hero_rolls.get(str(hero_state["id"]), null), HERO_ACCENT, readout)
	_layout.queue_board_layout_refresh()


func _populate_enemy_cards() -> void:
	_clear_container(enemy_cards)
	_clear_container(enemy_readouts)
	_clear_container(enemy_dice_row)
	enemy_card_views.clear()
	var enemy_states: Array = combat_manager.get_enemy_states()
	var card_slots: Array = _layout.build_row_slots(enemy_cards, enemy_states.size())
	var readout_slots: Array = _layout.build_row_slots(enemy_readouts, enemy_states.size())
	var dice_slots: Array = _layout.build_row_slots(enemy_dice_row, enemy_states.size())
	for i in range(enemy_states.size()):
		var enemy_state: Dictionary = enemy_states[i]
		var enemy: EnemyData = enemy_state["unit"] as EnemyData
		if enemy == null:
			continue

		var card: Control = _create_battle_card()
		var readout: Control = ABILITY_READOUT_SCENE.instantiate() as Control
		var dice_anchor: Control = _layout.build_dice_anchor()
		var slot_index: int = i
		(card_slots[slot_index] as Control).add_child(card)
		(readout_slots[slot_index] as Control).add_child(readout)
		(dice_slots[slot_index] as Control).add_child(dice_anchor)
		_layout.prepare_battle_card_layout(card)
		_layout.prepare_ability_readout_layout(readout)
		enemy_card_views.append({
			"card": card,
			"readout": readout,
			"dice_anchor": dice_anchor,
			"state": enemy_state,
			"slot_index": slot_index,
		})
		card.card_pressed.connect(_on_enemy_card_pressed.bind(enemy_state["id"]))
		if card.has_signal("unit_detail_requested"):
			card.connect("unit_detail_requested", Callable(self, "_on_unit_detail_requested"))
		_card_view.update_card_view(card, enemy_state, enemy_rolls.get(str(enemy_state["id"]), null), ENEMY_ACCENT, readout)
	_layout.queue_board_layout_refresh()


func _clear_container(container: Container) -> void:
	for child in container.get_children():
		child.queue_free()


func _create_battle_card() -> Control:
	return CompactUnitCard.new()


func _on_unit_detail_requested(card: Control) -> void:
	if _is_resolving_turn:
		return
	var compact_card: CompactUnitCard = card as CompactUnitCard
	if compact_card == null or compact_card.unit_data == null:
		return
	AudioManager.play_select()
	# Unified long-press inspect (replaces the old UnitDetailPanel popup). The popup
	# self-dismisses on outside press, so no close-on-event handling is needed here. Pass the
	# unit's live battle state so its active statuses show as pip + description rows.
	InspectPopup.open(
		self,
		InspectResolver.resolve_unit(compact_card.unit_data, _find_state_for_card(compact_card)),
		compact_card.get_global_rect(),
		compact_card.get_instance_id(),
	)


# The live battle-state dict backing a unit card (empty if not found).
func _find_state_for_card(card: Control) -> Dictionary:
	for view_variant in hero_card_views + enemy_card_views:
		var view: Dictionary = view_variant
		if view.get("card") == card:
			return view.get("state", {})
	return {}


func _on_roll_button_pressed() -> void:
	if battle_over:
		AudioManager.play_select()
		_on_open_reward_button_pressed()
		return
	AudioManager.play_select()
	if turn_phase == PHASE_AWAIT_ROLL:
		_begin_targeting_phase()
		return
	if turn_phase == PHASE_READY_TO_END:
		_resolve_current_turn()


func _begin_targeting_phase(skip_dice_visuals: bool = false) -> void:
	roll_button.visible = false
	roll_button.disabled = true
	roll_button.text = ""
	hero_rolls.clear()
	enemy_rolls.clear()
	hero_roll_nudges.clear()
	hero_roll_sets.clear()
	_clear_die_tooltip_overlays()
	_card_view.hide_all_ability_readouts()
	active_targeting_hero_id = ""
	legal_target_ids.clear()
	legal_target_side = ""
	pending_manual_target_ids.clear()
	has_player_target_assignment = false
	_clear_target_assignments()

	if dice_tray_3d != null and not skip_dice_visuals:
		_layout.refresh_board_layout()
		await get_tree().process_frame
		_layout.layout_dice_from_combat_zone()
		await get_tree().process_frame
		dice_tray_3d.play_rolls(
			_build_dice_tray_entries(combat_manager.get_hero_states(), "hero"),
			_build_dice_tray_entries(combat_manager.get_enemy_states(), "enemy")
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
	_card_view.refresh_all_cards()
	_card_view.show_all_ability_readouts()
	if dice_tray_3d != null and not skip_dice_visuals:
		dice_tray_3d.show_result_actions(_build_dice_action_entries(combat_manager.get_hero_states(), hero_rolls, true))
		dice_tray_3d.show_result_actions(_build_dice_action_entries(combat_manager.get_enemy_states(), enemy_rolls, false))
		_build_die_tooltip_overlays()
	_set_turn_phase(PHASE_TARGETING)
	_append_log("Dice rolled for all units.")
	if skip_dice_visuals and is_inside_tree() and get_tree() != null:
		await get_tree().process_frame

	if pending_manual_target_ids.is_empty():
		_set_turn_phase(PHASE_READY_TO_END)
		return


func _auto_assign_pending_targets(use_pauses: bool = true) -> void:
	while turn_phase == PHASE_TARGETING and not pending_manual_target_ids.is_empty():
		var hero_id: String = str(pending_manual_target_ids[0])
		_select_targeting_hero(hero_id)
		if use_pauses:
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
		if use_pauses:
			await get_tree().create_timer(AUTO_TURN_TARGET_PAUSE).timeout
	if turn_phase == PHASE_TARGETING and pending_manual_target_ids.is_empty():
		_set_turn_phase(PHASE_READY_TO_END)
	if not use_pauses and is_inside_tree() and get_tree() != null:
		await get_tree().process_frame


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


func _build_dice_tray_entries(states: Array, side: String = "") -> Array:
	var entries: Array = []
	for state_variant in states:
		var state: Dictionary = state_variant
		if bool(state["dead"]):
			continue
		var unit: Resource = state["unit"]
		var is_frozen: bool = int(state.get("die_freeze_turns", 0)) > 0 and int(state.get("frozen_die_value", 0)) > 0
		var entry: Dictionary = {
			"id": str(state["id"]),
			"name": str(unit.battle_name()),
		}
		var anchor_point: Vector2 = _layout.get_dice_anchor_point(side, str(state["id"]))
		if anchor_point != Vector2.INF:
			entry["result_anchor"] = anchor_point
		var side_offset: float = _layout.get_dice_anchor_side_offset(side, str(state["id"]))
		if not is_zero_approx(side_offset):
			entry["result_anchor_side_offset_px"] = side_offset
		if is_frozen:
			entry["frozen"] = true
			entry["frozen_roll"] = int(state.get("frozen_die_value", 0))
		var roll_mods: Dictionary = combat_manager.get_roll_modifier_totals(state)
		entry["roll_rfe"] = int(roll_mods["roll_rfe"])
		entry["roll_buff"] = int(roll_mods["roll_buff"])
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
			"name": str(unit.battle_name()),
			"ability": str(ability_entry.get("ability_name", "")),
			"roll": effective_roll,
			"zone": str(ability_entry.get("zone", "")),
		})
	return entries


func _build_die_tooltip_overlays() -> void:
	_clear_die_tooltip_overlays()
	if dice_tray_3d == null or float_layer == null:
		return
	_build_die_tooltip_overlays_for_states(combat_manager.get_hero_states(), hero_rolls, "hero", false)
	_build_die_tooltip_overlays_for_states(combat_manager.get_enemy_states(), enemy_rolls, "enemy", true)


func _build_die_tooltip_overlays_for_states(states: Array, rolls: Dictionary, side: String, is_enemy: bool) -> void:
	for state_variant in states:
		var state: Dictionary = state_variant
		if bool(state.get("dead", false)):
			continue
		if not _has_roll_for_state(rolls, state):
			continue
		var unit_id: String = str(state.get("id", ""))
		if unit_id == "":
			continue
		var raw_roll: int = _get_roll_value_for_state(rolls, state)
		if raw_roll <= 0:
			continue
		var result: int = _get_effective_enemy_roll(state, unit_id) if is_enemy else _get_effective_roll_for_state(state, unit_id)
		var unit: Resource = state.get("unit") as Resource
		var ability_entry: Dictionary = dice_manager.get_ability_for_roll(unit, result)
		var screen_position: Vector2 = dice_tray_3d.get_die_screen_position(side, unit_id)
		if is_inf(screen_position.x) or is_inf(screen_position.y):
			continue
		# Hit-area = the die merged with this unit's effect-pip readout (pips sit above the
		# die for enemies, below for heroes), so a long-press anywhere across the die + its
		# pip line opens the inspect — one rectangle, no tiny per-pip targets.
		var die_rect := Rect2(screen_position - Vector2(90.0, 90.0) * 0.5, Vector2(90.0, 90.0))
		var readout_rect: Rect2 = _get_unit_readout_rect(side, unit_id)
		var overlay_rect: Rect2 = die_rect.merge(readout_rect) if readout_rect.size != Vector2.ZERO else die_rect
		var overlay := ColorRect.new()
		overlay.name = "DieTooltip_%s_%s" % [side, unit_id]
		overlay.color = Color(1.0, 1.0, 1.0, 0.0)
		overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		overlay.custom_minimum_size = overlay_rect.size
		overlay.size = overlay_rect.size
		overlay.z_index = 90
		overlay.set_as_top_level(true)
		float_layer.add_child(overlay)
		overlay.global_position = overlay_rect.position
		_attach_die_inspect(overlay, side, unit_id, ability_entry, result)
		_die_tooltip_overlays.append(overlay)


# The screen rect of a unit's effect-pip readout (the AbilityReadout owned by its view),
# used to size the die hit-area so it spans the pips. Empty Rect2 if not ready.
func _get_unit_readout_rect(side: String, unit_id: String) -> Rect2:
	var views: Array = hero_card_views if side == "hero" else enemy_card_views
	for view_variant in views:
		var view: Dictionary = view_variant
		if str((view.get("state", {}) as Dictionary).get("id", "")) != unit_id:
			continue
		var readout: Control = view.get("readout", null) as Control
		if readout != null and is_instance_valid(readout) and readout.is_inside_tree():
			var rect: Rect2 = readout.get_global_rect()
			if rect.size.x > 2.0 and rect.size.y > 2.0:
				return rect
		return Rect2()
	return Rect2()


# Die overlay: quick tap selects/targets the unit (existing behavior); long-press opens
# the unified inspect popup for that die's ability.
func _attach_die_inspect(overlay: Control, side: String, unit_id: String, ability_entry: Dictionary, result: int) -> void:
	var long_press := LongPressInput.new()
	overlay.add_child(long_press)
	long_press.tapped.connect(func() -> void:
		if side == "hero":
			_on_hero_card_pressed(unit_id)
		elif side == "enemy":
			_on_enemy_card_pressed(unit_id)
	)
	long_press.long_pressed.connect(func(_global_position: Vector2) -> void:
		var meta: String = "Roll: %d - %d" % [int(ability_entry.get("min", result)), int(ability_entry.get("max", result))]
		var payload: Dictionary = InspectResolver.resolve_ability(ability_entry.get("raw", {}), side, meta)
		InspectPopup.open(self, payload, overlay.get_global_rect(), overlay.get_instance_id())
	)


func _clear_die_tooltip_overlays() -> void:
	for overlay_variant in _die_tooltip_overlays:
		var overlay: Control = overlay_variant as Control
		if overlay != null and is_instance_valid(overlay):
			overlay.queue_free()
	_die_tooltip_overlays.clear()


func _resolve_current_turn(skip_feedback: bool = false) -> void:
	if battle_over:
		return
	if hero_rolls.is_empty() or enemy_rolls.is_empty():
		_refresh_summary("Roll dice to begin.")
		return

	_is_resolving_turn = true
	InspectPopup.dismiss()

	# Build effective roll dicts so RFE/buff/nudge are reflected in combat resolution
	var eff_hero_rolls: Dictionary = _build_effective_rolls(hero_rolls, combat_manager.get_hero_states(), true)
	var eff_enemy_rolls: Dictionary = _build_effective_rolls(enemy_rolls, combat_manager.get_enemy_states(), false)
	for unit_id_variant in eff_hero_rolls.keys():
		_game_state().record_hero_effective_roll(str(unit_id_variant), int(eff_hero_rolls[unit_id_variant]))

	var raw_enemy_rolls: Dictionary = enemy_rolls.duplicate()
	var raw_hero_rolls: Dictionary = hero_rolls.duplicate()
	var result: Dictionary = combat_manager.resolve_round(
		eff_hero_rolls,
		eff_enemy_rolls,
		dice_manager,
		raw_enemy_rolls,
		raw_hero_rolls
	)
	hero_rolls.clear()
	enemy_rolls.clear()
	hero_roll_nudges.clear()
	hero_roll_sets.clear()
	_clear_die_tooltip_overlays()
	active_targeting_hero_id = ""
	legal_target_ids.clear()
	legal_target_side = ""
	pending_manual_target_ids.clear()
	has_player_target_assignment = false
	_clear_target_assignments()
	roll_button.disabled = true
	_append_round_log(result.get("log", []))
	var protocol_grant: int = combat_manager.take_pending_protocol_grants()
	if protocol_grant > 0:
		protocol_points = mini(protocol_points + protocol_grant, MAX_PROTOCOL)
		_update_protocol_bar()
		_append_log("Protocol +%d from kill → %d" % [protocol_grant, protocol_points])
	if skip_feedback:
		_feedback.reset_death_sfx_tracking()
		for event_variant in result.get("events", []):
			var event: Dictionary = event_variant
			_feedback.play_death_sfx_for_event(event)
			_feedback.apply_live_event_visual_state(event)
			_card_view.refresh_card_for_event(event)
	else:
		await _feedback.play_round_feedback(result.get("events", []))
	_process_summon_events(result.get("events", []))
	_consume_revealed_frozen_dice()
	_card_view.refresh_all_cards()
	if skip_feedback and is_inside_tree() and get_tree() != null:
		await get_tree().process_frame
	_is_resolving_turn = false

	var outcome: String = str(result.get("result", "ongoing"))
	if outcome == "victory":
		battle_over = true
		roll_button.disabled = true
		_persist_protocol_carryover()
		_capture_battle_victory_for_xp()
		if _auto_battle_running:
			_debug_advance_after_auto_battle_victory()
		elif _game_state().is_final_battle():
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
		protocol_points = mini(protocol_points + 1, MAX_PROTOCOL)
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


func _persist_protocol_carryover() -> void:
	if not combat_manager.has_relic("protocolCarryover"):
		return
	var carry_pct: int = int(combat_manager.get_relic_value("protocolCarryover", "amount", 50))
	_game_state().save_protocol_carryover(protocol_points, carry_pct)


func _capture_battle_victory_for_xp() -> void:
	_game_state().capture_battle_end_survival(combat_manager.get_hero_states())


func _finish_battle_victory() -> void:
	battle_over = true
	_disable_combat_actions()
	_persist_protocol_carryover()
	_capture_battle_victory_for_xp()
	if _auto_battle_running:
		_debug_advance_after_auto_battle_victory()
	elif _game_state().is_final_battle():
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
	hero_roll_sets.clear()
	_clear_die_tooltip_overlays()
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
	_card_view.refresh_all_cards()


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
	PixelUI.style_labeled_texture_button(_round_complete_next_button, PixelUI.BUTTON_LARGE_YELLOW_SCIFI, 28)
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
	AudioManager.play_select()
	_game_state().prepare_battle_rewards()
	_scene_manager().go_to_reward_screen()


func _debug_advance_after_auto_battle_victory() -> void:
	if _game_state().is_final_battle():
		_refresh_summary("Boss defeated. Run complete.")
		_game_state().finish_run("victory")
		_scene_manager().go_to_run_end()
		return

	_refresh_summary("Victory. Routing to rewards.")
	_game_state().prepare_battle_rewards()
	_scene_manager().go_to_reward_screen()


func _on_protocol_spend_button_pressed() -> void:
	# Kept as a no-op stub; actual handler is _on_reroll_button_pressed wired in _ready()
	pass


func _on_reroll_button_pressed() -> void:
	if _consume_protocol_long_press():
		return
	if turn_phase != PHASE_READY_TO_END and turn_phase != PHASE_TARGETING:
		if hero_rolls.is_empty():
			_refresh_summary("Roll dice before using Reroll.")
		return
	if protocol_points < 2:
		_refresh_summary("Need 2 Protocol to Reroll.")
		return
	AudioManager.play_select()
	_set_turn_phase(PHASE_REROLL_PICK)


func _on_nudge_button_pressed() -> void:
	if _consume_protocol_long_press():
		return
	if turn_phase != PHASE_READY_TO_END and turn_phase != PHASE_TARGETING:
		if hero_rolls.is_empty():
			_refresh_summary("Roll dice before using Nudge.")
		return
	if protocol_points < 1:
		_refresh_summary("Need 1 Protocol to Nudge.")
		return
	if not _has_nudgeable_hero():
		_refresh_summary("Every die was already nudged this turn.")
		return
	AudioManager.play_select()
	_set_turn_phase(PHASE_NUDGE_PICK)


func _add_nudge_button() -> void:
	var btn: Button = Button.new()
	btn.custom_minimum_size = BOTTOM_BAR_BUTTON_SIZE
	btn.pressed.connect(_on_nudge_button_pressed)
	_attach_protocol_inspect(btn, "nudge")
	_style_frame_icon_action_button(btn, PixelUI.ICON_INCREASE, BOTTOM_BAR_BUTTON_SIZE)
	_nudge_button = btn
	protocol_spend_button.get_parent().add_child(btn)
	protocol_spend_button.get_parent().move_child(btn, protocol_spend_button.get_index() + 1)

func _apply_reroll(hero_id: String) -> void:
	protocol_points -= 2
	var new_roll: int = dice_manager.roll_d20()
	hero_rolls[hero_id] = new_roll
	# Clear nudge/set for this hero since their roll is fresh
	hero_roll_nudges.erase(hero_id)
	hero_roll_sets.erase(hero_id)
	_update_protocol_bar()
	_append_log("Reroll: %s draws %d." % [hero_id, new_roll])
	if dice_tray_3d != null:
		await dice_tray_3d.reroll_die_to_result("hero", hero_id, new_roll)
	_re_assign_hero_target(hero_id)
	_refresh_dice_result_actions()
	_finish_roll_modifier_pick()


func _apply_nudge(hero_id: String) -> void:
	if _was_hero_nudged_this_turn(hero_id):
		_refresh_summary("That die was already nudged this turn.")
		return
	protocol_points -= 1
	hero_roll_nudges[hero_id] = 3
	_update_protocol_bar()
	_append_log("Nudge: %s +3 to effective roll." % hero_id)
	var hero_state: Dictionary = _find_state_by_id(combat_manager.get_hero_states(), hero_id)
	if dice_tray_3d != null and not hero_state.is_empty():
		dice_tray_3d.update_die_result_in_place("hero", hero_id, _get_effective_roll_for_state(hero_state, hero_id))
	_re_assign_hero_target(hero_id)
	_refresh_dice_result_actions()
	_finish_roll_modifier_pick()


func _was_hero_nudged_this_turn(hero_id: String) -> bool:
	return hero_roll_nudges.has(hero_id)


func _can_nudge_hero(state: Dictionary) -> bool:
	if bool(state.get("dead", false)):
		return false
	if not _has_roll_for_state(hero_rolls, state):
		return false
	return not _was_hero_nudged_this_turn(str(state["id"]))


func _has_nudgeable_hero() -> bool:
	for hero_state_variant in combat_manager.get_hero_states():
		if _can_nudge_hero(hero_state_variant):
			return true
	return false


func _on_set_button_pressed() -> void:
	if turn_phase != PHASE_READY_TO_END and turn_phase != PHASE_TARGETING:
		if hero_rolls.is_empty():
			_refresh_summary("Roll dice before using Set.")
		return
	if protocol_points < SET_DIE_COST:
		_refresh_summary("Need %d Protocol to Set." % SET_DIE_COST)
		return
	AudioManager.play_select()
	_set_turn_phase(PHASE_SET_PICK)


func _attach_protocol_inspect(button: Button, action_key: String) -> void:
	if button == null:
		return
	# A Button doesn't surface gui_input to a child LongPressInput, so detect the hold via
	# the button's own button_down/button_up signals + a timer. A quick tap still fires the
	# button action; a held press opens the inspect and sets _suppress_protocol_press so the
	# release doesn't also run the action.
	var hold_timer := Timer.new()
	hold_timer.one_shot = true
	hold_timer.wait_time = PixelUI.INSPECT_HOLD_SEC
	button.add_child(hold_timer)
	hold_timer.timeout.connect(func() -> void:
		_suppress_protocol_press = true
		InspectPopup.open(self, InspectResolver.resolve_protocol_action(action_key), button.get_global_rect(), button.get_instance_id())
	)
	button.button_down.connect(func() -> void: hold_timer.start())
	button.button_up.connect(func() -> void: hold_timer.stop())


func _consume_protocol_long_press() -> bool:
	if _suppress_protocol_press:
		_suppress_protocol_press = false
		return true
	return false


func _add_set_button() -> void:
	var btn: Button = Button.new()
	btn.custom_minimum_size = BOTTOM_BAR_BUTTON_SIZE
	btn.pressed.connect(_on_set_button_pressed)
	_attach_protocol_inspect(btn, "set")
	_style_frame_icon_action_button(btn, PixelUI.ICON_DEBUG2, BOTTOM_BAR_BUTTON_SIZE)
	_set_button = btn
	protocol_spend_button.get_parent().add_child(btn)
	protocol_spend_button.get_parent().move_child(btn, _nudge_button.get_index() + 1)


# Set-pick: the player tapped a hero die; pop a 1-20 value menu for it.
func _begin_set_value_pick(hero_id: String) -> void:
	_pending_set_hero_id = hero_id
	_ensure_set_value_menu()
	_set_value_menu.reset_size()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var menu_size: Vector2 = _set_value_menu.size
	var pos: Vector2 = get_viewport().get_mouse_position()
	pos.x = clampf(pos.x, 8.0, maxf(8.0, vp.x - menu_size.x - 8.0))
	pos.y = clampf(pos.y, 8.0, maxf(8.0, vp.y - menu_size.y - 8.0))
	_set_value_menu.position = Vector2i(pos)
	_set_value_menu.popup()


func _ensure_set_value_menu() -> void:
	if _set_value_menu != null and is_instance_valid(_set_value_menu):
		return
	_set_value_menu = PopupMenu.new()
	for value in range(1, 21):
		_set_value_menu.add_item(str(value), value)  # id == the value
	_set_value_menu.id_pressed.connect(_on_set_value_picked)
	add_child(_set_value_menu)


func _on_set_value_picked(value: int) -> void:
	if _pending_set_hero_id == "":
		return
	AudioManager.play_select()
	var hero_id: String = _pending_set_hero_id
	_pending_set_hero_id = ""
	_apply_set(hero_id, clampi(value, 1, 20))


func _apply_set(hero_id: String, value: int) -> void:
	protocol_points -= SET_DIE_COST
	hero_roll_sets[hero_id] = value
	hero_roll_nudges.erase(hero_id)  # an explicit set overrides any prior nudge
	_update_protocol_bar()
	_append_log("Set: %s die set to %d." % [hero_id, value])
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
	_build_die_tooltip_overlays()


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
	# Set action forces an absolute effective roll, overriding freeze/nudge/buffs.
	if hero_roll_sets.has(unit_id) or hero_roll_sets.has(str(unit_id)):
		return clampi(int(hero_roll_sets.get(unit_id, hero_roll_sets.get(str(unit_id), raw_roll))), 1, 20)
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


var _protocol_segments: Array = []
# Horizontal inset matching the dice-tray edge (Content margin + tray gutter), so the
# header/footer content lines up with the tray instead of running to the screen edge.
const TRAY_EDGE_INSET := 16


# A fixed 3px divider line at the header (top) or footer (bottom) boundary, inset to
# match the tray edges. Placed on the root so layout/reordering can't move it.
func _ensure_zone_divider(node_name: String, at_footer: bool) -> void:
	if get_node_or_null(node_name) != null:
		return
	var divider: ColorRect = ColorRect.new()
	divider.name = node_name
	# Match the PersistentHeader's bottom divider exactly: DT_LINE, full-width, 3px.
	divider.color = PixelUI.DT_LINE
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Full-width, top-relative anchors; exact Y is set each layout pass by
	# BattleLayout._position_zone_dividers so the gap to the cards stays consistent.
	divider.anchor_left = 0.0
	divider.anchor_right = 1.0
	divider.anchor_top = 0.0
	divider.anchor_bottom = 0.0
	divider.offset_left = 0.0
	divider.offset_right = 0.0
	divider.offset_top = (960.0 if at_footer else 144.0)
	divider.offset_bottom = divider.offset_top + 3.0
	add_child(divider)


# Stack "PROTOCOL" above a short segment bar (more readable, frees horizontal room).
func _ensure_protocol_stack_layout() -> void:
	var row := protocol_bar.get_parent() as HBoxContainer
	if row == null or row.get_node_or_null("ProtocolStack") != null:
		return
	# Let the stack expand across the whole row up to the action buttons.
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var stack := VBoxContainer.new()
	stack.name = "ProtocolStack"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stack.add_theme_constant_override("separation", 2)
	row.remove_child(protocol_label)
	row.remove_child(protocol_bar)
	stack.add_child(protocol_label)
	stack.add_child(protocol_bar)
	row.add_child(stack)
	row.move_child(stack, 0)
	# Buttons take only their fixed size; the stack absorbs ALL remaining width.
	for sibling in row.get_children():
		if sibling is Button:
			(sibling as Button).size_flags_horizontal = Control.SIZE_SHRINK_END
	# Neutralize the old-layout expanding spacer (it was splitting the width 50/50).
	var spacer: Control = row.get_node_or_null("ProtocolFooterSpacer") as Control
	if spacer != null:
		spacer.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		spacer.custom_minimum_size = Vector2.ZERO
	# Wide segment bar (fills the stack); "Protocol" centered above all the blips.
	protocol_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	protocol_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	protocol_bar.custom_minimum_size = Vector2(0, 36)
	protocol_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	protocol_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	protocol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _ensure_protocol_segments() -> void:
	if not _protocol_segments.is_empty():
		return
	if protocol_bar == null or not is_instance_valid(protocol_bar):
		return
	# Direction-05: 10 discrete segments. Hide the native ProgressBar fill and draw
	# our own segmented row over it (filled amber / empty dark).
	protocol_bar.show_percentage = false
	protocol_bar.add_theme_stylebox_override("background", PixelUI.make_hard_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	protocol_bar.add_theme_stylebox_override("fill", PixelUI.make_hard_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0))
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "ProtocolSegments"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 3)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	protocol_bar.add_child(row)
	for _i in range(MAX_PROTOCOL):
		var seg: Panel = Panel.new()
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_child(seg)
		_protocol_segments.append(seg)


func _update_protocol_bar() -> void:
	protocol_bar.max_value = MAX_PROTOCOL
	protocol_bar.value = protocol_points
	_ensure_protocol_segments()
	for i in range(_protocol_segments.size()):
		var seg: Panel = _protocol_segments[i]
		if i < protocol_points:
			seg.add_theme_stylebox_override("panel", PixelUI.make_hard_style(PixelUI.DT_AMBER, PixelUI.DT_AMBER, 0))
		else:
			seg.add_theme_stylebox_override("panel", PixelUI.make_hard_style(PixelUI.DT_PROTO_EMPTY, PixelUI.DT_PROTO_EMPTY_BORDER, 1))
	protocol_value_label.text = "%d / %d" % [protocol_points, MAX_PROTOCOL]
	_update_protocol_footer_display()


func _ensure_protocol_footer_display() -> void:
	if protocol_bar == null:
		return
	var protocol_row := protocol_panel.get_node_or_null("ProtocolMargin/ProtocolRow") as HBoxContainer
	if protocol_row != null:
		protocol_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		if _protocol_footer_spacer == null or not is_instance_valid(_protocol_footer_spacer):
			_protocol_footer_spacer = Control.new()
			_protocol_footer_spacer.name = "ProtocolFooterSpacer"
			_protocol_footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_protocol_footer_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			protocol_row.add_child(_protocol_footer_spacer)
		if is_instance_valid(protocol_spend_button):
			protocol_row.move_child(_protocol_footer_spacer, protocol_spend_button.get_index())
	protocol_bar.visible = true
	protocol_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	protocol_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# Scaled down to make footer room for the third protocol action (Set) button.
	# Width/height scale together so the art aspect holds and the lights stay aligned.
	# (Provisional — the upcoming UI refactor will redo the footer layout properly.)
	var protocol_height: float = BOTTOM_BAR_BUTTON_SIZE.y * 0.74
	var protocol_width: float = roundf((PROTOCOL_FOOTER_SOURCE_SIZE.x / PROTOCOL_FOOTER_SOURCE_SIZE.y) * protocol_height)
	protocol_bar.custom_minimum_size = Vector2(protocol_width, protocol_height)
	if _protocol_footer_display == null or not is_instance_valid(_protocol_footer_display):
		_protocol_footer_display = Control.new()
		_protocol_footer_display.name = "ProtocolFooterDisplay"
		_protocol_footer_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_protocol_footer_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		protocol_bar.add_child(_protocol_footer_display)
		protocol_bar.move_child(_protocol_footer_display, 0)

		var texture: TextureRect = TextureRect.new()
		texture.name = "ProtocolFooterTexture"
		texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		texture.texture = load(PROTOCOL_FOOTER_BAR_TEXTURE) as Texture2D
		_protocol_footer_display.add_child(texture)
		_protocol_footer_display.move_child(texture, 0)
		_protocol_footer_display.resized.connect(_layout_protocol_footer_lights)

		_protocol_footer_lights.clear()
		for light_rect in PROTOCOL_LIGHT_RECTS:
			var light: Panel = Panel.new()
			light.name = "ProtocolLight%d" % _protocol_footer_lights.size()
			light.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.bg_color = Color(0.20, 0.58, 0.98, 0.92)
			style.border_color = Color(0.74, 0.94, 1.0, 0.78)
			style.set_border_width_all(1)
			style.corner_radius_top_left = 2
			style.corner_radius_top_right = 2
			style.corner_radius_bottom_right = 2
			style.corner_radius_bottom_left = 2
			light.add_theme_stylebox_override("panel", style)
			light.visible = false
			_protocol_footer_display.add_child(light)
			_protocol_footer_lights.append(light)
	_layout_protocol_footer_lights()
	_update_protocol_footer_display()


func _layout_protocol_footer_lights() -> void:
	if _protocol_footer_display == null or not is_instance_valid(_protocol_footer_display):
		return
	if _protocol_footer_lights.is_empty():
		return
	var scale_x: float = 1.0
	var scale_y: float = 1.0
	if PROTOCOL_FOOTER_SOURCE_SIZE.x > 0.0:
		scale_x = _protocol_footer_display.size.x / PROTOCOL_FOOTER_SOURCE_SIZE.x
	if PROTOCOL_FOOTER_SOURCE_SIZE.y > 0.0:
		scale_y = _protocol_footer_display.size.y / PROTOCOL_FOOTER_SOURCE_SIZE.y
	for i in range(mini(_protocol_footer_lights.size(), PROTOCOL_LIGHT_RECTS.size())):
		var light: Panel = _protocol_footer_lights[i] as Panel
		if light == null or not is_instance_valid(light):
			continue
		var source_rect: Rect2 = PROTOCOL_LIGHT_RECTS[i]
		light.position = Vector2(source_rect.position.x * scale_x, source_rect.position.y * scale_y)
		light.size = Vector2(source_rect.size.x * scale_x, source_rect.size.y * scale_y)


func _update_protocol_footer_display() -> void:
	if _protocol_footer_lights.is_empty():
		return
	var active_count: int = clampi(protocol_points, 0, MAX_PROTOCOL)
	for i in range(_protocol_footer_lights.size()):
		var light: Panel = _protocol_footer_lights[i] as Panel
		if light == null or not is_instance_valid(light):
			continue
		light.visible = i < active_count


func _build_runtime_units() -> void:
	hero_units.clear()
	enemy_units.clear()
	_game_state().enforce_squad_limit()

	for unit_id in _game_state().selected_units:
		if hero_units.size() >= GameState.SQUAD_UNIT_LIMIT:
			break
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
		if enemy_units.size() >= GameState.SQUAD_UNIT_LIMIT:
			break
		var enemy: EnemyData = _data_manager().get_enemy_by_display_name(str(enemy_name)) as EnemyData
		if enemy != null:
			enemy_units.append(_duplicate_enemy(enemy))


func _refresh_summary(_extra_text: String) -> void:
	_update_battle_header()


func _update_battle_header() -> void:
	var operation: OperationData = _data_manager().get_operation(_game_state().selected_operation_id) as OperationData
	var op_name: String = operation.battle_name() if operation != null else "OP"
	PersistentHeader.set_run_active(true)
	PersistentHeader.update_progress(_game_state().current_battle, _game_state().total_battles, op_name)


func _set_turn_phase(next_phase: String) -> void:
	turn_phase = next_phase
	_update_phase_target_sets()
	match turn_phase:
		PHASE_AWAIT_ROLL:
			_card_view.hide_all_ability_readouts()
			roll_button.visible = true
			roll_button.disabled = false
			roll_button.text = "Roll"
			_refresh_summary("")
		PHASE_TARGETING:
			roll_button.visible = false
			roll_button.disabled = true
			roll_button.text = ""
			_refresh_summary("")
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
			_refresh_summary("Tap a hero die to nudge (+3, once per die).")
		PHASE_SET_PICK:
			roll_button.visible = false
			roll_button.disabled = true
			roll_button.text = ""
			_refresh_summary("Tap a hero die to set its value.")
		PHASE_ITEM_PICK_ALLY:
			roll_button.visible = false
			roll_button.disabled = true
			roll_button.text = ""
			_refresh_summary("")
		PHASE_ITEM_PICK_DEAD:
			roll_button.visible = false
			roll_button.disabled = true
			roll_button.text = ""
			_refresh_summary("")
		PHASE_ITEM_PICK_ENEMY:
			roll_button.visible = false
			roll_button.disabled = true
			roll_button.text = ""
			_refresh_summary("")
		PHASE_ITEM_CONFIRM:
			roll_button.visible = false
			roll_button.disabled = true
			roll_button.text = ""
			_refresh_summary("")
	_style_roll_button_for_phase()
	_card_view.refresh_all_cards()


func _style_roll_button_for_phase() -> void:
	match turn_phase:
		PHASE_AWAIT_ROLL:
			# Active primary action: ready to roll — Direction-05 green commit button.
			_style_minimal_action_button(
				roll_button, roll_button.text,
				CENTER_ACTION_BUTTON_SIZE, CENTER_ACTION_BUTTON_FONT_SIZE,
				PixelUI.DT_ROLL_BG, PixelUI.DT_ROLL_LIGHT
			)
			roll_button.add_theme_color_override("font_color", PixelUI.DT_ROLL_TEXT)
		PHASE_TARGETING:
			# Hidden: targetable cards use team border color (see CompactUnitCard).
			pass
		PHASE_READY_TO_END:
			# Active primary action: close out the turn
			_style_minimal_action_button(
				roll_button, roll_button.text,
				CENTER_ACTION_BUTTON_SIZE, CENTER_ACTION_BUTTON_FONT_SIZE,
				Color(0.20, 0.14, 0.04, 0.96), PixelUI.GOLD_ACCENT
			)
		_:
			# Item-pick / fallback states are also hidden; the affordance
			# is the highlighted card the player must tap.
			pass


func _style_minimal_action_button(button: Button, label: String, min_size: Vector2, font_size: int, fill: Color = Color(0.014, 0.020, 0.032, 0.92), border: Color = PixelUI.LINE_DIM) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.icon = null
	button.expand_icon = false
	button.flat = false
	button.text = label
	button.custom_minimum_size = min_size
	PixelUI.style_button(button, fill, border, font_size)


# Wrap PixelUI.style_frame_icon_button while preserving the min-size we want
# for the row layouts. Used for both the header and bottom-bar icon buttons.
func _style_frame_icon_action_button(
	button: BaseButton,
	icon_path: String,
	min_size: Vector2,
	frame_modulate: Color = Color.WHITE,
	icon_modulate: Color = Color.WHITE,
) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.custom_minimum_size = min_size
	# Direction-05 flat dark square. frame_modulate carries the border accent (e.g.
	# gold for the protocol spend button); default uses the neutral DT button border.
	var border_color: Color = PixelUI.DT_BTN_BORDER if frame_modulate == Color.WHITE else frame_modulate
	PixelUI.style_dt_icon_button(button, icon_path, border_color, icon_modulate)


func _style_prompt_button(button: Button, label: String, min_size: Vector2, font_size: int, border: Color = PixelUI.LINE_DIM) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.icon = null
	button.expand_icon = false
	button.flat = false
	button.text = label
	button.custom_minimum_size = min_size
	# Mostly transparent fill so this reads as a status hint, not an
	# action waiting to be unlocked.
	PixelUI.style_button(button, Color(0.05, 0.07, 0.10, 0.45), border, font_size)


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
	has_player_target_assignment = false
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
	if bool(raw.get("reviveAll", false)):
		return ""
	if bool(raw.get("revive", false)):
		return "dead_hero"
	if bool(raw.get("healTgt", false)) or bool(raw.get("shTgt", false)):
		return "hero"
	if bool(raw.get("rfmTgt", false)):
		return "hero"
	var has_single_enemy_effect: bool = (
		(int(raw.get("dmg", 0)) > 0 and not bool(raw.get("blastAll", false)))
		or int(raw.get("dot", 0)) > 0
		or (int(raw.get("rfe", 0)) > 0 and not bool(raw.get("rfeAll", false)))
		or bool(raw.get("rfeOnly", false))
	)
	if has_single_enemy_effect:
		return "enemy"
	if bool(raw.get("blastAll", false)) or bool(raw.get("healAll", false)) or bool(raw.get("shieldAll", false)):
		return ""
	return ""


func _queue_or_auto_assign_manual_target(hero_state: Dictionary, manual_side: String) -> void:
	var hero_id: String = str(hero_state["id"])
	var target_ids: Array = _get_legal_target_ids(manual_side)
	pending_manual_target_ids.erase(hero_id)
	if target_ids.is_empty():
		_set_state_target(hero_state, "", _get_no_legal_target_display(manual_side))
		return
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
		_card_view.refresh_all_cards()
		if pending_manual_target_ids.is_empty():
			_set_turn_phase(PHASE_READY_TO_END)
		else:
			_refresh_summary("Select the next hero to target.")
	return true


func _get_no_legal_target_display(target_side: String) -> String:
	if target_side == "dead_hero":
		return "No Fallen"
	return "--"


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
	if (int(raw.get("shield", 0)) > 0 or int(raw.get("heal", 0)) > 0) and int(raw.get("shieldAlly", 0)) <= 0:
		_set_state_target(enemy_state, str(enemy_state["id"]), "Self")
		return

	# Ally-targeted: shield a living ally
	if int(raw.get("shieldAlly", 0)) > 0:
		var ally_target: Dictionary = _first_living_enemy_ally_state(enemy_state)
		if ally_target.is_empty():
			ally_target = enemy_state
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
	_card_view.refresh_all_cards()
	_refresh_summary("Choose a target for %s." % str(hero_state["unit"].display_name))


func _can_retarget_hero(hero_id: String) -> bool:
	if _get_taunt_enemy_id() != "":
		return false
	var hero_state: Dictionary = _find_state_by_id(combat_manager.get_hero_states(), hero_id)
	if hero_state.is_empty() or bool(hero_state.get("dead", false)):
		return false
	if not _has_roll_for_state(hero_rolls, hero_state):
		return false
	var eff_roll: int = _get_effective_roll_for_state(hero_state, hero_id)
	var ability_entry: Dictionary = dice_manager.get_ability_for_roll(hero_state["unit"], eff_roll)
	if ability_entry.is_empty():
		return false
	var manual_side: String = _get_manual_target_side(ability_entry)
	return manual_side != "" and not _get_legal_target_ids(manual_side).is_empty()


func _assign_target_to_active_hero(target_id: String, target_side: String) -> void:
	var hero_state: Dictionary = _find_state_by_id(combat_manager.get_hero_states(), active_targeting_hero_id)
	if hero_state.is_empty():
		return
	var target_state: Dictionary = _find_manual_target_state(target_side, target_id)
	if target_state.is_empty():
		return
	_set_state_target(hero_state, target_id, str(target_state["unit"].display_name))
	has_player_target_assignment = true
	pending_manual_target_ids.erase(active_targeting_hero_id)
	active_targeting_hero_id = ""
	legal_target_ids.clear()
	legal_target_side = ""
	_card_view.refresh_all_cards()
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
	elif target_side == "dead_hero":
		states = combat_manager.get_hero_states()
	else:
		states = combat_manager.get_hero_states() if target_side == "hero" else combat_manager.get_enemy_states()
	for state_variant in states:
		var state: Dictionary = state_variant
		if target_side == "dead_hero":
			if bool(state["dead"]):
				ids.append(str(state["id"]))
			continue
		if bool(state["dead"]):
			continue
		ids.append(str(state["id"]))
	return ids


func _find_manual_target_state(target_side: String, target_id: String) -> Dictionary:
	if target_side == "hero" or target_side == "dead_hero":
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


func _first_living_enemy_ally_state(enemy_state: Dictionary) -> Dictionary:
	for state_variant in combat_manager.get_enemy_states():
		var state: Dictionary = state_variant
		if state == enemy_state:
			continue
		if not bool(state["dead"]):
			return state
	return {}


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

	# Reroll/Set pick phases: only living hero cards that have rolled
	if turn_phase == PHASE_REROLL_PICK or turn_phase == PHASE_SET_PICK:
		return accent_color == HERO_ACCENT and not bool(state["dead"]) and _has_roll_for_state(hero_rolls, state)
	if turn_phase == PHASE_NUDGE_PICK:
		return accent_color == HERO_ACCENT and _can_nudge_hero(state)

	# Item pick phases
	if turn_phase == PHASE_ITEM_PICK_ALLY:
		return accent_color == HERO_ACCENT and not bool(state["dead"])
	if turn_phase == PHASE_ITEM_PICK_DEAD:
		return false
	if turn_phase == PHASE_ITEM_PICK_ENEMY:
		return accent_color == ENEMY_ACCENT and not bool(state["dead"])

	if turn_phase != PHASE_TARGETING and turn_phase != PHASE_READY_TO_END:
		return false

	var state_id: String = str(state["id"])
	if turn_phase == PHASE_READY_TO_END:
		return accent_color == HERO_ACCENT and _can_retarget_hero(state_id)

	if active_targeting_hero_id == "":
		if accent_color != HERO_ACCENT:
			return false
		return pending_manual_target_ids.has(state_id) or _can_retarget_hero(state_id)

	if legal_target_side == "enemy" and accent_color == ENEMY_ACCENT:
		return legal_target_ids.has(state_id)
	if legal_target_side == "hero" and accent_color == HERO_ACCENT:
		return legal_target_ids.has(state_id)
	if legal_target_side == "dead_hero" and accent_color == HERO_ACCENT:
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


# True while an item is mid-use (choosing a target, or confirming a no-target item).
func _in_item_phase() -> bool:
	return turn_phase.begins_with("item_pick") or turn_phase == PHASE_ITEM_CONFIRM


func _on_enemy_card_pressed(target_id: String) -> void:
	if battle_over:
		return
	if _in_item_phase():
		# Tapping a legal enemy target applies the item; tapping any other unit/die cancels
		# it back to the loadout (same as tapping the item card again).
		if turn_phase == PHASE_ITEM_PICK_ENEMY and legal_target_ids.has(target_id) and _pending_item != null:
			var target_state: Dictionary = _find_state_by_id(combat_manager.get_enemy_states(), target_id)
			if not target_state.is_empty():
				AudioManager.play_select()
				_apply_item_effect(_pending_item, target_state)
				return
		_cancel_item_to_loadout()
		return
	if turn_phase != PHASE_TARGETING:
		return
	if active_targeting_hero_id == "" or (legal_target_side != "enemy" and legal_target_side != "any"):
		return
	if not legal_target_ids.has(target_id):
		return
	AudioManager.play_select()
	_assign_target_to_active_hero(target_id, "enemy")


func _on_hero_card_pressed(target_id: String) -> void:
	if battle_over:
		return

	# Handle reroll/nudge pick phases first
	if turn_phase == PHASE_REROLL_PICK:
		var reroll_state: Dictionary = _find_state_by_id(combat_manager.get_hero_states(), target_id)
		if reroll_state.is_empty() or bool(reroll_state["dead"]) or not _has_roll_for_state(hero_rolls, reroll_state):
			return
		AudioManager.play_select()
		await _apply_reroll(target_id)
		return
	if turn_phase == PHASE_NUDGE_PICK:
		var nudge_state: Dictionary = _find_state_by_id(combat_manager.get_hero_states(), target_id)
		if not _can_nudge_hero(nudge_state):
			return
		AudioManager.play_select()
		_apply_nudge(target_id)
		return
	if turn_phase == PHASE_SET_PICK:
		var set_state: Dictionary = _find_state_by_id(combat_manager.get_hero_states(), target_id)
		if set_state.is_empty() or bool(set_state["dead"]) or not _has_roll_for_state(hero_rolls, set_state):
			return
		AudioManager.play_select()
		_begin_set_value_pick(target_id)
		return

	if _in_item_phase():
		# Tapping a legal ally target applies the item; tapping any other unit/die cancels it
		# back to the loadout (same as tapping the item card again).
		if turn_phase == PHASE_ITEM_PICK_ALLY and legal_target_ids.has(target_id) and _pending_item != null:
			var target_state: Dictionary = _find_state_by_id(combat_manager.get_hero_states(), target_id)
			if not target_state.is_empty():
				AudioManager.play_select()
				_apply_item_effect(_pending_item, target_state)
				return
		_cancel_item_to_loadout()
		return

	if turn_phase == PHASE_READY_TO_END:
		if _can_retarget_hero(target_id):
			AudioManager.play_select()
			_set_turn_phase(PHASE_TARGETING)
			_select_targeting_hero(target_id)
		return

	if turn_phase != PHASE_TARGETING:
		return
	if active_targeting_hero_id == "":
		if pending_manual_target_ids.has(target_id) or _can_retarget_hero(target_id):
			AudioManager.play_select()
			_select_targeting_hero(target_id)
		return
	if legal_target_side == "hero" and legal_target_ids.has(target_id):
		AudioManager.play_select()
		_assign_target_to_active_hero(target_id, "hero")
	elif legal_target_side == "dead_hero" and legal_target_ids.has(target_id):
		AudioManager.play_select()
		_assign_target_to_active_hero(target_id, "dead_hero")
	elif legal_target_side == "any" and legal_target_ids.has(target_id):
		AudioManager.play_select()
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


func _apply_battle_theme() -> void:
	# The header bar (FACILITY label + buttons) and its divider now live in the
	# PersistentHeader autoload, not this scene. Only the footer divider stays here.
	_ensure_zone_divider("FooterDivider", true)
	PixelUI.style_panel(hero_panel, Color(0.0, 0.0, 0.0, 0.0), Color.TRANSPARENT, 0, 0)
	PixelUI.style_panel(enemy_panel, Color(0.0, 0.0, 0.0, 0.0), Color.TRANSPARENT, 0, 0)
	PixelUI.style_panel(center_panel, Color(0.0, 0.0, 0.0, 0.0), Color.TRANSPARENT, 0, 0)
	PixelUI.style_panel(battle_log_panel, Color(0.015, 0.022, 0.035, 0.82), PixelUI.LINE_DIM, 2, 2)
	# Direction-05: flat dark field instead of the starfield texture.
	if background != null:
		background.texture = null
		if background.get_node_or_null("FieldFill") == null:
			var field_fill: ColorRect = ColorRect.new()
			field_fill.name = "FieldFill"
			# Slightly lifted off pure-black so the whole screen reads less dull than
			# the raw design token (which felt too dark in-engine).
			field_fill.color = Color(0.055, 0.070, 0.095, 1.0)
			field_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			field_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
			background.add_child(field_fill)
	_ensure_panel_background(hero_panel)
	_ensure_panel_background(enemy_panel)
	_ensure_panel_background(center_panel)
	_layout.ensure_combat_zone_frame()
	PixelUI.apply_pixel_font(protocol_label)
	protocol_label.add_theme_font_size_override("font_size", PROTOCOL_LABEL_FONT_SIZE)
	protocol_label.add_theme_color_override("font_color", PixelUI.TEXT_PRIMARY)
	protocol_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.98))
	protocol_label.add_theme_constant_override("outline_size", 2)
	PixelUI.apply_pixel_font(protocol_value_label)
	protocol_value_label.add_theme_font_size_override("font_size", PROTOCOL_VALUE_FONT_SIZE)
	protocol_value_label.add_theme_color_override("font_color", PixelUI.TEXT_PRIMARY)
	protocol_value_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.98))
	protocol_value_label.add_theme_constant_override("outline_size", 2)
	# Header buttons are styled by the PersistentHeader autoload itself.
	_style_roll_button_for_phase()
	_style_frame_icon_action_button(protocol_spend_button, PixelUI.ICON_REROLL, BOTTOM_BAR_BUTTON_SIZE)
	if _nudge_button != null and is_instance_valid(_nudge_button):
		_style_frame_icon_action_button(_nudge_button, PixelUI.ICON_INCREASE, BOTTOM_BAR_BUTTON_SIZE)
	if _set_button != null and is_instance_valid(_set_button):
		_style_frame_icon_action_button(_set_button, PixelUI.ICON_DEBUG2, BOTTOM_BAR_BUTTON_SIZE)
	if _item_button != null and is_instance_valid(_item_button):
		_style_frame_icon_action_button(_item_button, PixelUI.ICON_ITEM, BOTTOM_BAR_BUTTON_SIZE)
	_ensure_protocol_footer_display()
	protocol_label.visible = true
	# The numeric value is redundant with the 10 segments and kept landing in awkward
	# spots (over the bar / among buttons) — hide it; the segments convey the count.
	protocol_value_label.visible = false
	if protocol_panel != null:
		# Footer plate (no top border — the FooterDivider ColorRect is the divider line).
		var footer_style: StyleBoxFlat = PixelUI.make_hard_style(PixelUI.DT_PANEL_BG, PixelUI.DT_PANEL_BG, 0)
		footer_style.set_content_margin_all(4.0)
		protocol_panel.add_theme_stylebox_override("panel", footer_style)
		# Align footer content with the dice-tray edges (room before the screen edge).
		var pm := protocol_panel.get_node_or_null("ProtocolMargin") as MarginContainer
		if pm != null:
			pm.add_theme_constant_override("margin_left", TRAY_EDGE_INSET)
			pm.add_theme_constant_override("margin_right", TRAY_EDGE_INSET)
	_ensure_protocol_stack_layout()
	PixelUI.style_progress_bar(protocol_bar, PixelUI.GOLD_ACCENT, Color(0.010, 0.014, 0.022, 0.95), PixelUI.LINE_DIM)
	if _protocol_footer_display != null and is_instance_valid(_protocol_footer_display):
		_protocol_footer_display.visible = false
	_update_protocol_bar()
	if _header_frame != null and is_instance_valid(_header_frame):
		_header_frame.queue_free()
		_header_frame = null
	if _footer_frame != null and is_instance_valid(_footer_frame):
		_footer_frame.queue_free()
		_footer_frame = null


func _ensure_panel_background(panel: PanelContainer) -> void:
	if panel == null:
		return
	var background_fill := panel.get_node_or_null("OpaqueBackground") as ColorRect
	if background_fill != null:
		background_fill.queue_free()


## Per-battle instance copy — stats always match `enemyUnitDefs` (no fight-index scaling).
func _duplicate_enemy(base_enemy: EnemyData) -> EnemyData:
	var copy: EnemyData = base_enemy.duplicate(true) as EnemyData
	return copy if copy != null else base_enemy


# --- Item System (Phase 3) ---

func _get_item_protocol_cost(_item: ItemData) -> int:
	# Flat cost 1 for all rarities (replaces the old common0/unc1/rare2/leg3 scale).
	# Protocol Override (protocolOnItemUse) makes items free; it also grants +1 on
	# use — see _apply_item_effect for the grant.
	if combat_manager.has_relic("protocolOnItemUse"):
		return 0
	return 1


func _build_item_panel() -> void:
	var protocol_row: HBoxContainer = protocol_panel.get_node("ProtocolMargin/ProtocolRow") as HBoxContainer
	_item_button = Button.new()
	_item_button.custom_minimum_size = BOTTOM_BAR_BUTTON_SIZE
	_item_button.pressed.connect(_on_item_button_pressed_menu)
	_style_frame_icon_action_button(_item_button, PixelUI.ICON_ITEM, BOTTOM_BAR_BUTTON_SIZE)
	protocol_row.add_child(_item_button)
	_item_menu = PopupMenu.new()
	_item_menu.name = "ItemMenu"
	_item_menu.id_pressed.connect(_on_item_menu_id_pressed)
	float_layer.add_child(_item_menu)
	_update_item_panel()


func _build_relic_slot() -> void:
	var protocol_row: HBoxContainer = protocol_panel.get_node("ProtocolMargin/ProtocolRow") as HBoxContainer
	var slot: PanelContainer = PanelContainer.new()
	_relic_slot = slot
	slot.custom_minimum_size = ITEM_SLOT_SIZE
	PixelUI.style_panel(slot, Color(0.012, 0.018, 0.028, 0.35), PixelUI.LINE_DIM, 1, 2)

	var icon_center: CenterContainer = CenterContainer.new()
	icon_center.name = "RelicIconCenter"
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(icon_center)

	var icon: TextureRect = TextureRect.new()
	icon.name = "RelicIcon"
	icon.custom_minimum_size = ITEM_ICON_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	icon_center.add_child(icon)

	var label: Label = Label.new()
	label.name = "RelicLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", PixelUI.GOLD_ACCENT)
	slot.add_child(label)

	protocol_row.add_child(slot)
	_update_relic_slot()


func _update_relic_slot() -> void:
	if _relic_slot == null:
		return
	var label: Label = _relic_slot.get_node_or_null("RelicLabel") as Label
	var icon: TextureRect = _relic_slot.find_child("RelicIcon", true, false) as TextureRect
	var relic_ids: Array = _game_state().relics
	if relic_ids.is_empty():
		if icon != null:
			icon.texture = null
			icon.visible = false
		if label != null:
			label.text = "◇"
			label.visible = true
		return

	var relic: ItemData = _data_manager().get_item(str(relic_ids[0])) as ItemData
	if relic == null:
		if icon != null:
			icon.texture = null
			icon.visible = false
		if label != null:
			label.text = "?"
			label.visible = true
		return

	if icon != null:
		icon.texture = relic.icon
		icon.visible = relic.icon != null
	if label != null:
		label.text = _get_item_icon_char(relic.icon_key)
		label.visible = relic.icon == null


func _update_item_panel() -> void:
	if _item_button == null:
		return
	_item_menu_items.clear()
	var item_ids: Array = _game_state().consumables
	for item_id_variant in item_ids:
		var item: ItemData = _data_manager().get_item(str(item_id_variant)) as ItemData
		if item != null:
			_item_menu_items.append(item)
	# The item button always opens the themed LOADOUT menu (consumables + relic), so it
	# stays enabled even with no consumables — the relic is still viewable.
	_item_button.disabled = false


func _on_item_button_pressed_menu() -> void:
	if _item_button == null:
		return
	AudioManager.play_select()
	var relic_item: ItemData = null
	var relic_ids: Array = _game_state().relics
	if not relic_ids.is_empty():
		relic_item = _data_manager().get_item(str(relic_ids[0])) as ItemData
	LoadoutMenu.open(self, _item_menu_items, relic_item, _on_item_button_pressed, _item_button.get_global_rect())


func _on_item_menu_id_pressed(id: int) -> void:
	if id < 0 or id >= _item_menu_items.size():
		return
	AudioManager.play_select()
	var item: ItemData = _item_menu_items[id] as ItemData
	if item == null:
		return
	_on_item_button_pressed(item)


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


# Returns true if the item tap was accepted (the loadout menu should close), false if it was
# rejected for insufficient Protocol (the menu stays open and flashes the tapped row red).
func _on_item_button_pressed(item: ItemData) -> bool:
	if battle_over:
		return true
	if not _can_use_item_in_current_phase():
		_refresh_summary("Items can only be used before rolling, during targeting, or before ending the turn.")
		return true
	var cost: int = _get_item_protocol_cost(item)
	if protocol_points < cost:
		_refresh_summary("Need %d Protocol to use %s." % [cost, item.display_name])
		return false

	_was_in_ready_phase = (turn_phase == PHASE_READY_TO_END)
	_phase_before_item = turn_phase
	_pending_item = item

	match item.target_kind:
		"ally":
			if _get_legal_target_ids("hero").is_empty():
				_cancel_item_targeting("No living ally can use %s." % item.display_name)
				return true
			_set_turn_phase(PHASE_ITEM_PICK_ALLY)
		"allyDead":
			_cancel_item_targeting("Downed units cannot be targeted by %s." % item.display_name)
			return true
		"enemy":
			if _get_legal_target_ids("enemy").is_empty():
				_cancel_item_targeting("No living enemy can be targeted by %s." % item.display_name)
				return true
			_set_turn_phase(PHASE_ITEM_PICK_ENEMY)
		"none":
			# No target needed — show the card centered and wait for a confirm tap.
			_set_turn_phase(PHASE_ITEM_CONFIRM)
		_:
			_cancel_item_targeting("%s cannot find a valid target type." % item.display_name)

	if turn_phase.begins_with("item_pick"):
		_show_item_targeting_card(item)
	elif turn_phase == PHASE_ITEM_CONFIRM:
		_show_item_targeting_card(item, true)
	return true


func _cancel_item_targeting(message: String) -> void:
	_hide_item_targeting_card()
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


# ── Item-targeting overlay (the centered picker card shown while choosing a unit, or as a
# confirm prompt for no-target items) ──
# Lives on its own high CanvasLayer (on top of everything) and is centered explicitly so
# it never depends on another control's layout. Armed after a short delay so the same tap
# that opened it can't immediately resolve it. In confirm_mode, tapping the card activates
# the item; otherwise it cancels back to the loadout. Tapping off the card cancels in both.
func _show_item_targeting_card(item: ItemData, confirm_mode: bool = false) -> void:
	_hide_item_targeting_card()
	if item == null:
		return
	var layer := CanvasLayer.new()
	layer.name = "ItemTargetingCard"
	layer.layer = 120
	add_child(layer)

	# Viewport-sized root + CenterContainer so the card sits centered at its own 420² minimum
	# size, without depending on any other control's layout.
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.size = get_viewport().get_visible_rect().size
	layer.add_child(root)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var card: PanelContainer = ItemCard.build(item, 420.0)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	# Tapping the card activates (confirm_mode) or cancels back to the loadout. STOP marks the
	# press handled so it does not also reach _unhandled_input (which treats off-card taps as
	# cancel).
	card.gui_input.connect(func(event: InputEvent) -> void:
		var pressed := false
		if event is InputEventMouseButton:
			pressed = (event as InputEventMouseButton).pressed
		elif event is InputEventScreenTouch:
			pressed = (event as InputEventScreenTouch).pressed
		if pressed:
			if confirm_mode:
				_confirm_pending_item()
			else:
				_cancel_item_to_loadout()
	)
	center.add_child(card)
	# In confirm mode the card itself is the tap target, so highlight it with a pulsing
	# accent border — the same "this is tappable" cue legal unit targets get when targeting.
	if confirm_mode:
		_add_confirm_card_highlight(card)
	# Hide the entire layer for the first frame so the card is never drawn at the wrong
	# position before CenterContainer has had a chance to lay it out.
	layer.visible = false
	get_tree().create_timer(0.0).timeout.connect(func() -> void:
		if is_instance_valid(layer):
			layer.visible = true
	)
	_item_targeting_card = layer

	_item_targeting_armed = false
	get_tree().create_timer(0.18).timeout.connect(func() -> void: _item_targeting_armed = true)


func _hide_item_targeting_card() -> void:
	_item_targeting_armed = false
	if _item_targeting_card != null and is_instance_valid(_item_targeting_card):
		_item_targeting_card.queue_free()
	_item_targeting_card = null


func _cancel_item_to_loadout() -> void:
	# Ignore cancels until armed, so the tap that opened the card doesn't close it.
	if not _item_targeting_armed:
		return
	if _pending_item == null and _item_targeting_card == null:
		return
	_hide_item_targeting_card()
	_cancel_item_targeting("")
	# Tapping the card or empty space drops back to the loadout menu.
	call_deferred("_on_item_button_pressed_menu")


# Confirm tap on a no-target item's centered card: activate it.
func _confirm_pending_item() -> void:
	# Ignore until armed, so the tap that opened the card doesn't immediately activate it.
	if not _item_targeting_armed:
		return
	if _pending_item == null:
		return
	# _apply_item_effect hides the card, applies, consumes, and restores the prior phase.
	_apply_item_effect(_pending_item, {})


# Pulsing accent border over a confirm card, echoing the legal-target highlight on units.
func _add_confirm_card_highlight(card: PanelContainer) -> void:
	var ring := Panel.new()
	ring.name = "ConfirmHighlight"
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(7)
	style.border_color = PixelUI.DT_HERO_DITHER
	style.set_corner_radius_all(0)
	ring.add_theme_stylebox_override("panel", style)
	card.add_child(ring)
	# Bound to the card so the loop dies with it; pulses the ring's alpha as the "tap me" cue.
	var tween := card.create_tween().set_loops()
	tween.tween_property(ring, "modulate:a", 0.25, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ring, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# While choosing an item target (or confirming a no-target item), a press that no unit
# handled (empty space) cancels back to the loadout.
func _unhandled_input(event: InputEvent) -> void:
	if not turn_phase.begins_with("item_pick") and turn_phase != PHASE_ITEM_CONFIRM:
		return
	var pressed := false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		pressed = mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed:
		get_viewport().set_input_as_handled()
		_cancel_item_to_loadout()


func _apply_item_effect(item: ItemData, target_state: Dictionary) -> void:
	if item == null:
		return
	_hide_item_targeting_card()
	AudioManager.play_sfx("item")
	var cost: int = _get_item_protocol_cost(item)
	protocol_points = maxi(protocol_points - cost, 0)
	# Protocol Override: using an item refunds +1 Protocol (net +1, since cost is 0).
	if combat_manager.has_relic("protocolOnItemUse"):
		protocol_points = mini(protocol_points + 1, MAX_PROTOCOL)
		_append_log("Protocol Override: +1 Protocol → %d" % protocol_points)

	var effect: Dictionary = item.effect
	var effect_type: String = str(effect.get("type", ""))
	var tname: String = _state_unit_name(target_state)

	match effect_type:
		"heal":
			var amount: int = int(effect.get("amount", 0))
			combat_manager.apply_item_heal(target_state, amount)
			_append_log("Item: %s heals %s for %d." % [item.display_name, tname, amount])
		"healAll":
			var heal_all_amount: int = int(effect.get("amount", 0))
			combat_manager.apply_item_heal_all(heal_all_amount)
			_append_log("Item: %s heals all living allies for %d." % [item.display_name, heal_all_amount])
		"shield":
			var amount: int = int(effect.get("amount", 0))
			var turns: int = int(effect.get("shT", 1))
			combat_manager.apply_item_shield(target_state, amount, turns)
			_append_log("Item: %s grants %d shield (%d turns) to %s." % [item.display_name, amount, turns, tname])
		"shieldAll":
			var shield_all_amount: int = int(effect.get("amount", 0))
			var shield_all_turns: int = int(effect.get("shT", 1))
			combat_manager.apply_item_shield_all(shield_all_amount, shield_all_turns)
			_append_log("Item: %s grants all living allies %d shield (%d turns)." % [item.display_name, shield_all_amount, shield_all_turns])
		"rollBuff":
			var amount: int = int(effect.get("amount", 0))
			var turns: int = int(effect.get("turns", 1))
			combat_manager.apply_item_roll_buff(target_state, amount, turns)
			_append_log("Item: %s gives %s +%d roll for %d turns." % [item.display_name, tname, amount, turns])
		"revive":
			var pct: int = _game_state().get_revive_hp_pct(int(effect.get("pct", 50)))
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
		"gainProtocol":
			var protocol_grant: int = int(effect.get("amount", 0))
			protocol_points = mini(protocol_points + protocol_grant, MAX_PROTOCOL)
			_update_protocol_bar()
			_append_log("Item: %s grants +%d Protocol → %d." % [item.display_name, protocol_grant, protocol_points])
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
		"enemyDieFreezeAll":
			var freeze_skips: int = int(effect.get("skips", 1))
			for enemy_state in combat_manager.get_enemy_states():
				if bool(enemy_state.get("dead", true)):
					continue
				enemy_state["die_freeze_turns"] = int(enemy_state.get("die_freeze_turns", 0)) + freeze_skips
				var fv: int = _get_roll_value_for_state(enemy_rolls, enemy_state)
				if fv <= 0:
					fv = int(enemy_state.get("last_die_value", enemy_state.get("frozen_die_value", 0)))
				if fv > 0:
					enemy_state["frozen_die_value"] = fv
			_append_log("Item: %s — all enemy dice frozen for %d reveal(s)." % [item.display_name, freeze_skips])

	_consume_item(item.id)
	_pending_item = null
	legal_target_ids.clear()
	legal_target_side = ""
	_card_view.refresh_all_cards()
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
		var summon_name: String = str(event.get("summon_name", ""))
		if summon_name == "":
			continue
		var base_enemy: EnemyData = _data_manager().get_enemy_by_display_name(summon_name) as EnemyData
		if base_enemy == null:
			_append_log("Summon failed: '%s' not found in data." % summon_name)
			continue
		if base_enemy.ai_type != "dumb":
			_append_log("Summon blocked: '%s' must be a dumb unit." % summon_name)
			continue
		var summon_copy: EnemyData = _duplicate_enemy(base_enemy)
		var inject_result: Dictionary = combat_manager.inject_enemy(summon_copy)
		if inject_result.is_empty():
			continue
		var slot_index: int = int(inject_result.get("slot_index", -1))
		if slot_index >= 0 and slot_index < enemy_units.size():
			enemy_units[slot_index] = summon_copy
		else:
			enemy_units.append(summon_copy)
		_populate_enemy_cards()
		_append_log("%s joins the battle!" % summon_copy.display_name)
