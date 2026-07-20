# Phase 5 battle scene shell that renders cards, rolls dice, and resolves a basic combat loop.
extends Control

# Emitted only during the rigged tutorial (GameState.tutorial_mode) at each taught beat, so the
# TutorialController can gate coachmarks on the player's real actions.
signal tutorial_event(event: StringName, payload: Dictionary)

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
# Keyword primers (one-shot micro-tutorials; docs/PRIMERS.md). Preload, not the
# global class name, so fresh-checkout headless runs parse (class-cache gotcha).
const KEYWORD_PRIMER_SCRIPT := preload("res://scripts/ui/keyword_primer.gd")
const OPERATION_BRIEFING_OVERLAY := preload("res://scripts/ui/operation_briefing_overlay.gd")
# Protocol-spend subsystem (ARCHITECTURE_REVIEW_JUL2026 §1 rec 1) — preload,
# not the global class name, for fresh-checkout headless parses.
const PROTOCOL_ACTIONS_SCRIPT := preload("res://scripts/battle/protocol_actions.gd")
const HERO_ACCENT := Color(0.38, 0.64, 0.92, 1.0)
const ENEMY_ACCENT := Color(0.42, 0.54, 0.68, 1.0)
# Die-docked result tags: one uniform filled plate per die that resolved an effect. Every
# tag is the SAME size (width = the die's projected diameter, height = a fixed fraction of
# it), docked flush just outside the die's projected bounds (never overlapping the sprite):
# below hero dice, above enemy dice. Content is centered and shrinks a step to fit.
const DIE_TAG_GAP := 2.0            # flush dock: 0-2px gap, never over the die
const DIE_TAG_HEIGHT_RATIO := 0.52  # tag height as a fraction of the die diameter
const DIE_TAG_FONT_RATIO := 0.72    # value-font size as a fraction of the tag height
# Every die owns a FIXED pip slot this many diameters wide (adjacent dice sit
# ~1.9 diameters apart, so 1.8 never collides with a neighbor or the screen
# edge). Content presents in three tiers (Kev 2026-07-10): fits at full size →
# large font + large pips · overflows → one-step shrink, still one line · still
# overflows → the SAME shrunk size wrapped onto two lines. Content never
# escapes the slot sideways again.
const DIE_TAG_SLOT_WIDTH_RATIO := 1.8
const DIE_TAG_SHRINK_STEP := 0.72   # tier-2/3 font step (matches the chip law)
const DIE_TAG_DIAMETER_FALLBACK := 90.0
# The turn/phase machine (architecture review §1 rec 2): a real enum with ONE
# transition() choke point routing every phase change. The PHASE_* aliases keep
# every pre-enum call site (this file, ProtocolActions, BattleCardView, capture
# tools) compiling against typed values; PHASE_NAMES preserves the pre-enum
# strings verbatim for tutorial payloads/tests.
enum Phase {
	AWAIT_ROLL, TARGETING, READY_TO_END, REROLL_PICK, NUDGE_PICK, SET_PICK, TWIN_SOURCE_PICK, TWIN_TARGET_PICK, ITEM_PICK_ALLY, ITEM_PICK_DEAD, ITEM_PICK_ENEMY, ITEM_PICK_ANY, ITEM_CONFIRM,
}
const PHASE_NAMES := {
	Phase.AWAIT_ROLL: "await_roll",
	Phase.TARGETING: "targeting",
	Phase.READY_TO_END: "ready_to_end",
	Phase.REROLL_PICK: "reroll_pick",
	Phase.NUDGE_PICK: "nudge_pick",
	Phase.SET_PICK: "set_pick",
	Phase.TWIN_SOURCE_PICK: "twin_source_pick",
	Phase.TWIN_TARGET_PICK: "twin_target_pick",
	Phase.ITEM_PICK_ALLY: "item_pick_ally",
	Phase.ITEM_PICK_DEAD: "item_pick_dead",
	Phase.ITEM_PICK_ENEMY: "item_pick_enemy",
	Phase.ITEM_PICK_ANY: "item_pick_any",
	Phase.ITEM_CONFIRM: "item_confirm",
}
const PHASE_AWAIT_ROLL := Phase.AWAIT_ROLL
const PHASE_TARGETING := Phase.TARGETING
const PHASE_READY_TO_END := Phase.READY_TO_END
const PHASE_REROLL_PICK := Phase.REROLL_PICK
const PHASE_NUDGE_PICK := Phase.NUDGE_PICK
const PHASE_SET_PICK := Phase.SET_PICK
const PHASE_TWIN_SOURCE_PICK := Phase.TWIN_SOURCE_PICK
const PHASE_TWIN_TARGET_PICK := Phase.TWIN_TARGET_PICK
const SET_DIE_COST := 4
const PHASE_ITEM_PICK_ALLY := Phase.ITEM_PICK_ALLY
const PHASE_ITEM_PICK_DEAD := Phase.ITEM_PICK_DEAD
const PHASE_ITEM_PICK_ENEMY := Phase.ITEM_PICK_ENEMY
const PHASE_ITEM_PICK_ANY := Phase.ITEM_PICK_ANY
# No-target items: show the card centered and wait for a confirm tap (tap card = activate,
# tap off = cancel) instead of applying immediately.
const PHASE_ITEM_CONFIRM := Phase.ITEM_CONFIRM
const ACTION_FEEDBACK_PAUSE := 0.34
const ACTION_EFFECT_LEAD_TIME := 0.10
const AUTO_TURN_TARGET_PAUSE := 0.16
const MAX_PROTOCOL := 10
# Legacy sci-fi footer aspect — still sizes the bare protocol bar on the
# fallback path (no ProtocolStack). The texture + LED-lights display it came
# from was dead chrome (built, then unconditionally hidden by the theme pass)
# and was deleted in Polish Build A.
const PROTOCOL_FOOTER_SOURCE_SIZE := Vector2(1330, 265)
const BOTTOM_BAR_BUTTON_SIZE := Vector2(112, 112)
const CENTER_ACTION_BUTTON_SIZE := Vector2(640, 136)
const CENTER_ACTION_BUTTON_FONT_SIZE := 48
const PROTOCOL_LABEL_FONT_SIZE := 70
const PROTOCOL_VALUE_FONT_SIZE := 48
# Footer protocol stack (Kev 2026-07-10) — the label sits directly on top of
# the pip bar (bottom-anchored; the overlap eats m5x7's below-baseline pad).
# Batch 3: label sized up 52→60; it grows UPWARD into the footer's free band
# (bottom-anchored box raised to match) so the pips below never move.
const PROTOCOL_STACK_LABEL_FONT := 60
const PROTOCOL_LABEL_BOX_H := 96.0
const PROTOCOL_LABEL_PIP_OVERLAP := -2.0
const PROTOCOL_PIP_BAR_H := 52.0

var dice_manager: DiceManager = DiceManager.new()
var combat_manager: CombatManager = CombatManager.new()
# Shared UI-free rules engine (balance-sim A.1). Owns the roll-shaping /
# protocol-economy rules extracted from this god object so the headless sim and
# the live screen run one implementation. See scripts/sim/DECOUPLING_NOTES.md.
var _engine: BattleEngine = BattleEngine.new(combat_manager, PhysicsRollProvider.new(dice_manager), dice_manager)
# Caller-owned battle state (rolls / nudge-set maps / protocol pool / per-battle
# spend flags) lives in one container so Package D's L2 solver can snapshot it
# with a single duplicate_for_search(). The members below are property
# forwarders — field names and semantics unchanged, storage relocated here.
var _state: BattleState = BattleState.new()
# battles start at 0; +1 income at end of each turn
var protocol_points: int:
	get: return _state.protocol_points
	set(value): _state.protocol_points = value
var hero_card_views: Array = []
var enemy_card_views: Array = []
var hero_rolls: Dictionary:
	get: return _state.hero_rolls
	set(value): _state.hero_rolls = value
var enemy_rolls: Dictionary:
	get: return _state.enemy_rolls
	set(value): _state.enemy_rolls = value
var hero_units: Array = []
var enemy_units: Array = []

# ── Tutorial rig (only used when GameState.tutorial_mode) ──────────────────────────
# Starting trio — Strike Unit (combat), Field Engineer (engineer), Splice Medic (medic),
# Batch 5 — vs one weak Scrap Drone (10 HP) that telegraphs a weak Stab (enemy roll 6 =
# strike band). Rolls keyed by unit id:
#   turn 1: Strike 3 (Target Lock — MARK only since Build I, 0 dmg) + Engineer 7 (Barrier
#           Deploy, shields an ally) + Medic 6 (Infusion, heals an ally). Nothing damages
#           the drone (10 stays 10), and the Mark PERSISTS because nobody hits it — that's
#           the status-badge lesson, visible right into turn 2.
#   turn 2: Strike 8 →Nudge→ 11 (Suppression Fire → Rail Strike, 10 dmg; the Mark spends for
#           +50% → 15) kills the 10-HP drone. Engineer/Medic support again.
# Strike 8 sits one short of the Surge band (Rail Strike opens at 11); +3 Nudge → 11 flips
# the band — the taught payoff. The 10 HP is set so turn 2 kills WITH OR WITHOUT the Mark
# (Rail Strike 10 ≥ the 10 remaining), so the drill never stalls on a rounding edge.
const TUTORIAL_ENEMY_NAME := "Scrap Drone"
const TUTORIAL_ENEMY_HP := 10
const TUTORIAL_ENEMY_ROLL := 6
const TUTORIAL_HERO_ROLLS := [
	{"combat": 3, "engineer": 7, "medic": 6},
	{"combat": 8, "engineer": 5, "medic": 6},
]
var _tutorial_turn: int = 0


func _emit_tutorial(event: StringName, payload: Dictionary = {}) -> void:
	if _game_state().tutorial_mode:
		tutorial_event.emit(event, payload)
var turn_phase: int = Phase.AWAIT_ROLL
var active_targeting_hero_id: String = ""
var legal_target_ids: Array = []
var legal_target_side: String = ""
var pending_manual_target_ids: Array = []
var has_player_target_assignment: bool = false
# Player-chosen cast order: monotonic within the round; each committed
# assignment takes the next value as its hero's cast_stamp (auto-assigns in
# squad order at targeting start, manual picks at assignment, re-commits at
# the end of the current order). Reset when the targeting phase begins.
var _cast_stamp_counter: int = 0
var battle_over: bool = false
# Read-only battle review (2026-07-13): this BattleScene was entered from the
# reward screen's "View Battlescreen" to look back at the finished board —
# real cards + long-press inspect, no actions. The center button becomes
# "Return to Rewards" and every combat handler no-ops (they already gate on
# battle_over, which review also sets).
var _review_mode: bool = false
var hero_roll_nudges: Dictionary:
	get: return _state.hero_roll_nudges
	set(value): _state.hero_roll_nudges = value
# hero_id -> absolute effective roll set via the Set action
var hero_roll_sets: Dictionary:
	get: return _state.hero_roll_sets
	set(value): _state.hero_roll_sets = value
var _battle_consumables: Array = []
# Die-docked result tags, keyed "side:unit_id" -> {plate: Panel, sig: String}.
var _die_tag_layer: Control = null
var _die_tags: Dictionary = {}
var _die_tag_diameter: float = DIE_TAG_DIAMETER_FALLBACK   # projected die diameter (uniform)
var _protocol_footer_spacer: Control = null
var _header_frame: PanelContainer = null
var _footer_frame: PanelContainer = null
var _die_tooltip_overlays: Array = []
var _layout: BattleLayout = null
var _protocol = null  # ProtocolActions — the protocol-spend subsystem
var _card_view: BattleCardView = null
var _feedback: BattleFeedback = null
var _round_complete_modal: Control = null
var _round_complete_next_button: Button = null
var _auto_turn_running: bool = false
var _auto_battle_running: bool = false
var _primer = null  # KeywordPrimer — null in tutorial battles
var _briefing_active: bool = false

var _is_resolving_turn: bool = false


func _game_state() -> Variant:
	return get_node("/root/GameState")


func _data_manager() -> Variant:
	return get_node("/root/DataManager")


func _scene_manager() -> Variant:
	return get_node("/root/SceneManager")


func _ready() -> void:
	# The faction track keeps playing uninterrupted — battle only opens it up.
	MusicManager.set_combat(true)
	_layout = BattleLayout.new()
	add_child(_layout)
	_layout.setup(self)
	_card_view = BattleCardView.new()
	add_child(_card_view)
	_card_view.setup(self)
	_feedback = BattleFeedback.new()
	add_child(_feedback)
	_feedback.setup(self)
	_protocol = PROTOCOL_ACTIONS_SCRIPT.new()
	add_child(_protocol)
	_protocol.setup(self)
	_apply_battle_theme()
	_build_round_complete_modal()
	# Review re-entry (from the reward screen): rebuild the finished board
	# read-only instead of starting a fresh battle. This MUST branch before the
	# live setup below, which has run-state side effects (consumes carried
	# protocol + the route modifier, grants battle-start consumables, begins XP
	# tracking) — a review may not fire any of those.
	if _game_state().entering_battle_review and not _game_state().battle_review_state.is_empty():
		_game_state().entering_battle_review = false
		_review_mode = true
	if _review_mode:
		_restore_review_board()
	else:
		_init_live_battle()
	_layout.queue_board_layout_refresh()
	# Wire protocol_spend_button as Reroll and add a Nudge button alongside it.
	# No "↺" text — the swap icon is the whole button (else it double-draws an arrow).
	protocol_spend_button.text = ""
	# The header bar lives in the PersistentHeader autoload now — bind its buttons to
	# this battle's handlers. They go inert again when this scene exits the tree.
	# Help ("?") is handled globally by PersistentHeader → HelpMenu, so no help binding here.
	PersistentHeader.bind_battle_actions(
		Callable(),
		_on_auto_turn_button_pressed,
		_on_auto_battle_button_pressed,
		_on_return_to_menu_button_pressed,
	)
	# Bottom safe-area inset (gesture bar), live-updating on rotation/resize.
	# The connection dies with this scene, so no explicit disconnect needed.
	_apply_safe_area()
	PersistentHeader.safe_area_changed.connect(_apply_safe_area)
	_protocol.build_footer_buttons()
	# Portrait mode: order is Enemy (top) → Center → Hero (bottom)
	board.move_child(enemy_panel, 0)
	board.move_child(center_panel, 1)
	board.move_child(hero_panel, 2)
	Callable(_layout, "stabilize_board_layout").call_deferred()
	if _game_state().tutorial_mode:
		_spawn_tutorial_controller.call_deferred()
	elif not _review_mode:
		# Keyword primers observe every non-tutorial battle; their own
		# suppression covers headless + auto battle at fire time. (No primers in
		# a read-only review — nothing is being cast.)
		_primer = KEYWORD_PRIMER_SCRIPT.new()
		add_child(_primer)
		_primer.setup(self)
	if not _review_mode and not _game_state().tutorial_mode:
		# Deferred so the board has finished constructing before the slate darkens it.
		call_deferred("_show_battle_entry_briefing")
	if _review_mode:
		# After the shared tail built the footer, lock the board read-only and
		# turn the center button into the way back (deferred so it wins the race
		# with the footer build above).
		call_deferred("_finalize_review")


# ── Live battle init (extracted from _ready so review can branch around its
# run-state side effects) ─────────────────────────────────────────────────────
func _init_live_battle() -> void:
	# Unlock metric (Build F): one increment per encounter ENTERED — this runs
	# exactly once per live battle (review re-entries branch around it), so a
	# multi-round battle counts once and a retreat still counted its entry.
	# The tutorial is a scripted exhibition, not an encounter (DECISIONS #13).
	if not _game_state().tutorial_mode:
		SaveManager.record_battle_entered()
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
	# Route Fork modifier (pkg7.3): one-shot — consumed into this battle.
	var route_modifier: String = str(_game_state().next_battle_modifier)
	_game_state().next_battle_modifier = ""
	if route_modifier != "":
		var comp_warded: Array = _game_state().get_current_battle_comp().get("warded", [])
		combat_manager.setup_battle_modifier(route_modifier, comp_warded)
		var modifier_info: Dictionary = _game_state().BATTLE_MODIFIERS.get(route_modifier, {})
		_append_log("ROUTE FLAGGED - %s: %s" % [str(modifier_info.get("name", route_modifier)), str(modifier_info.get("desc", ""))])
	_apply_intercept_battle_effects()
	# Protocol Tap gear (engine rule, shared with the sim — sim-B.2).
	protocol_points = mini(protocol_points + _engine.gear_start_protocol(), _max_protocol())
	_update_protocol_bar()
	_populate_hero_cards()
	_populate_enemy_cards()
	dice_tray_3d.reset()
	_set_battle_log_visible(false)
	_append_log("Battle initialized.")
	# Boss standing rules are stated up front — active from turn 1.
	for enemy_state_variant in combat_manager.get_enemy_states():
		var rule_text: String = CombatManager.get_boss_standing_rule(str(enemy_state_variant["unit"].display_name))
		if rule_text != "":
			_append_log("%s: %s" % [str(enemy_state_variant["unit"].display_name), rule_text])
	transition(PHASE_AWAIT_ROLL)


# ── Read-only battle review ───────────────────────────────────────────────────
# Rebuild the finished board from the captured combat state (no setup_battle, so
# zero run-state side effects). Cards + statuses + ability readouts render from
# the restored states; long-press inspect works natively (it never gated on a
# live battle). No dice roll — the pips read from the un-hidden readout rows.
func _restore_review_board() -> void:
	var rs: Dictionary = _game_state().battle_review_state
	combat_manager.restore_state(rs.get("combat", {}))
	protocol_points = int(rs.get("protocol", 0))
	hero_rolls = (rs.get("hero_rolls", {}) as Dictionary).duplicate(true)
	enemy_rolls = (rs.get("enemy_rolls", {}) as Dictionary).duplicate(true)
	battle_over = true
	_update_battle_header()
	_update_protocol_bar()
	_populate_hero_cards()
	_populate_enemy_cards()
	_card_view.refresh_all_cards()
	_card_view.show_all_ability_readouts()
	# The readout rows are alpha-0 in live play (the visible pips are die-docked
	# tags drawn over the 3D dice). There are no dice in review, so un-hide the
	# rows to surface the resolved pips.
	for views_variant in [hero_card_views, enemy_card_views]:
		for view_variant in views_variant:
			var readout: Object = (view_variant as Dictionary).get("readout")
			if readout is CanvasItem and is_instance_valid(readout):
				(readout as CanvasItem).modulate = Color(1, 1, 1, 1)
	_set_battle_log_visible(false)


# Runs after the shared _ready tail: disable every action surface and turn the
# center button into "Return to Rewards".
func _finalize_review() -> void:
	if _protocol != null and is_instance_valid(_protocol):
		_protocol.reset_battle_over_state()  # disables the nudge/reroll/set/item footer
	PersistentHeader.set_debug_enabled(false)
	PersistentHeader.set_debug2_enabled(false)
	roll_button.visible = true
	roll_button.disabled = false
	roll_button.text = "RETURN TO REWARDS"
	_refresh_summary("Reviewing the last battle - read-only. Long-press any unit to inspect.")


func _show_battle_entry_briefing() -> void:
	# DevContext.is_isolated() (not OS.has_feature("headless"), which is FALSE under
	# a `-s` launch) so the modal never opens in a headless smoke, an audit, or a
	# windowed capture rig and blocks the first roll / auto-battle.
	if DevContext.is_isolated() or _review_mode or _game_state().tutorial_mode:
		return
	if _game_state().current_battle == _game_state().total_battles:
		_show_boss_alert()
	elif _game_state().current_battle == 1:
		_show_deployment_slate()


func _show_deployment_slate() -> void:
	var operation_id: String = str(_game_state().selected_operation_id)
	if OPERATION_BRIEFING_OVERLAY.operation_copy(operation_id).is_empty():
		return
	var briefing := OPERATION_BRIEFING_OVERLAY.new()
	_briefing_active = true
	add_child(briefing)
	briefing.dismissed.connect(func(_mode: String) -> void:
		_briefing_active = false
	)
	briefing.present_deployment(operation_id)


func _show_boss_alert() -> void:
	for enemy_state_variant in combat_manager.get_enemy_states():
		var enemy_state: Dictionary = enemy_state_variant as Dictionary
		var boss_name: String = _state_unit_name(enemy_state)
		var rule_text: String = CombatManager.get_boss_standing_rule(boss_name)
		if rule_text == "":
			continue
		var briefing := OPERATION_BRIEFING_OVERLAY.new()
		_briefing_active = true
		add_child(briefing)
		briefing.dismissed.connect(func(_mode: String) -> void:
			_briefing_active = false
		)
		briefing.present_boss_alert(boss_name, rule_text)
		return


func _return_from_review() -> void:
	AudioManager.play_select()
	match str(_game_state().battle_review_return_target):
		"intercept":
			_scene_manager().go_to_intercept()
		"evolution":
			_scene_manager().go_to_evolution()
		_:
			_scene_manager().go_to_reward_screen()


# Coachmark/step controller for the rigged onboarding encounter (lives on its own high layer).
func _spawn_tutorial_controller() -> void:
	var controller := TutorialController.new()
	add_child(controller)
	controller.start(self)


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
	if _briefing_active or _auto_turn_running or _auto_battle_running or battle_over:
		return
	if turn_phase == PHASE_REROLL_PICK or turn_phase == PHASE_NUDGE_PICK or turn_phase == PHASE_SET_PICK or turn_phase == PHASE_TWIN_SOURCE_PICK or turn_phase == PHASE_TWIN_TARGET_PICK or is_item_pick_phase(turn_phase):
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
	if _briefing_active or _auto_turn_running or _auto_battle_running:
		return
	if battle_over:
		_on_open_reward_button_pressed()
		return
	if turn_phase == PHASE_REROLL_PICK or turn_phase == PHASE_NUDGE_PICK or turn_phase == PHASE_SET_PICK or turn_phase == PHASE_TWIN_SOURCE_PICK or turn_phase == PHASE_TWIN_TARGET_PICK or is_item_pick_phase(turn_phase):
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
	# Safety net: whatever path left the battle, the track settles back.
	MusicManager.set_combat(false)
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
	_emit_tutorial("inspected", {"side": compact_card.side})


# The live battle-state dict backing a unit card (empty if not found).
func _find_state_for_card(card: Control) -> Dictionary:
	for view_variant in hero_card_views + enemy_card_views:
		var view: Dictionary = view_variant
		if view.get("card") == card:
			return view.get("state", {})
	return {}


func _on_roll_button_pressed() -> void:
	if _briefing_active:
		return
	if _review_mode:
		# The center button is "Return to Rewards" here — go straight back
		# without _on_open_reward_button_pressed's reward RE-ROLL.
		_return_from_review()
		return
	if battle_over:
		AudioManager.play_select()
		_on_open_reward_button_pressed()
		return
	AudioManager.play_select()
	if turn_phase == PHASE_AWAIT_ROLL:
		_emit_tutorial("roll_pressed")
		_begin_targeting_phase()
		return
	if turn_phase == PHASE_READY_TO_END:
		_emit_tutorial("end_turn_pressed")
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
	if _game_state().tutorial_mode:
		_apply_tutorial_dice_rig()
	_apply_roll_relic_overrides(skip_dice_visuals)
	_record_roll_values_for_states(combat_manager.get_hero_states(), hero_rolls)
	_record_roll_values_for_states(combat_manager.get_enemy_states(), enemy_rolls)
	_apply_post_roll_gear_effects()

	_assign_enemy_targets()
	_prepare_hero_targets()
	_card_view.refresh_all_cards()
	_card_view.show_all_ability_readouts()
	if dice_tray_3d != null and not skip_dice_visuals:
		dice_tray_3d.show_result_actions(_build_dice_action_entries(combat_manager.get_hero_states(), hero_rolls, true))
		dice_tray_3d.show_result_actions(_build_dice_action_entries(combat_manager.get_enemy_states(), enemy_rolls, false))
		_build_die_tooltip_overlays()
		_sync_die_status_visuals()
	transition(PHASE_TARGETING)
	_append_log("Dice rolled for all units.")
	_emit_tutorial("rolled", {"turn": _tutorial_turn})
	if skip_dice_visuals and is_inside_tree() and get_tree() != null:
		await get_tree().process_frame

	# Keyword primers: a new player turn begins — report the ROLL sightings
	# (Kev 2026-07-10: a keyword primes the first time it appears on a revealed
	# roll, BEFORE the player commits) and drain them.
	#
	# BOARD-READABLE GATE (Kev 2026-07-13 — the last of the anchor rounds). The
	# drain must not begin until the pip plates exist AND have been laid out:
	# the plates build in _process and their glyph children only get real global
	# rects at END of the frame they're created (Godot container sort is
	# deferred). A drain that resolves an anchor in the plate's birth frame reads
	# every glyph at the plate's origin → a screen-left anchor box (the Round-3
	# bug; Round-2's synchronous self-heal was what created the plate in that
	# doomed frame). So: build the plates now (the same readable surface the
	# die-docked result tags use — dice have already settled via roll_finished),
	# then yield ONE frame so their glyphs are laid out. Primers and plates key
	# off the same "board is readable" moment — and no coachmark shows over
	# still-bouncing dice. NEVER resolve a Control's rect in its creation frame.
	if _primer != null and is_instance_valid(_primer):
		_sync_die_tags()
		if is_inside_tree() and get_tree() != null:
			await get_tree().process_frame
		_primer.on_turn_started()
		_notice_personality_primers()
		_notice_rolled_ability_primers()
		await _primer.flush_player_phase()

	if pending_manual_target_ids.is_empty():
		transition(PHASE_READY_TO_END)
	# The refresh at the end of the roll ran while still in AWAIT_ROLL, where the
	# preview is suppressed; recompute now that the phase is settled (TARGETING or
	# READY_TO_END) so auto-targeted abilities — AoE and forced-single — show their
	# damage/heal preview immediately, not only after a manual pick (§3, Batch 4).
	_card_view.refresh_all_cards()


# pkg8.1: every die status renders on the die itself — freeze/petrify crust,
# jam tint + cap marker, rewrite/hijack pending markers.
func _sync_die_status_visuals() -> void:
	if dice_tray_3d == null:
		return
	for side_states in [["hero", combat_manager.get_hero_states()], ["enemy", combat_manager.get_enemy_states()]]:
		var side: String = str(side_states[0])
		for state_variant in side_states[1]:
			var state: Dictionary = state_variant
			if bool(state.get("dead", false)):
				continue
			dice_tray_3d.set_die_status(side, str(state["id"]), {
				"frozen": int(state.get("die_freeze_turns", 0)) > 0,
				"flavor": str(state.get("freeze_flavor", "ice")),
				"jam_cap": int(state.get("jam_cap", 0)),
				"rewrite": bool(state.get("rewrite_pending", false)),
				"hijack": bool(state.get("hijack_pending", false)),
			})


# Overwrite the just-rolled dice with the scripted tutorial values and repaint the 3D tray in
# place (same call Nudge uses), so the animation plays but the result is deterministic.
func _apply_tutorial_dice_rig() -> void:
	var turn_idx: int = clampi(_tutorial_turn, 0, TUTORIAL_HERO_ROLLS.size() - 1)
	var rig: Dictionary = TUTORIAL_HERO_ROLLS[turn_idx]
	for hero_state in combat_manager.get_hero_states():
		var unit: Object = hero_state.get("unit") as Object
		var unit_id: String = str(unit.id) if unit != null else ""
		if not rig.has(unit_id):
			continue
		var sid: String = str(hero_state["id"])
		var value: int = int(rig[unit_id])
		hero_rolls[sid] = value
		if dice_tray_3d != null:
			dice_tray_3d.update_die_result_in_place("hero", sid, value)
	for enemy_state in combat_manager.get_enemy_states():
		var esid: String = str(enemy_state["id"])
		enemy_rolls[esid] = TUTORIAL_ENEMY_ROLL
		if dice_tray_3d != null:
			dice_tray_3d.update_die_result_in_place("enemy", esid, TUTORIAL_ENEMY_ROLL)
	_tutorial_turn += 1


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
		transition(PHASE_READY_TO_END)
	if not use_pauses and is_inside_tree() and get_tree() != null:
		await get_tree().process_frame


# Report each living enemy whose personality picked a HERO target this turn
# (the primer manager decides whether any personality is a first sighting).
func _notice_personality_primers() -> void:
	if _primer == null or not is_instance_valid(_primer):
		return
	for enemy_state_variant in combat_manager.get_enemy_states():
		var enemy_state: Dictionary = enemy_state_variant
		if bool(enemy_state.get("dead", false)):
			continue
		var picked_hero: Dictionary = _find_state_by_id(combat_manager.get_hero_states(), str(enemy_state.get("selected_target_id", "")))
		if picked_hero.is_empty():
			continue
		var unit: Object = enemy_state.get("unit", null) as Object
		if unit == null:
			continue
		var personality: int = TargetingPersonality.resolve_personality(unit)
		_primer.notice_personality_assigned(TargetingPersonality.personality_name(personality), str(enemy_state["id"]))


# Kev 2026-07-10: every keyword on a revealed roll primes NOW (before the
# player assigns actions), anchored to the rolling unit.
func _notice_rolled_ability_primers() -> void:
	if _primer == null or not is_instance_valid(_primer):
		return
	var sides: Array = [
		["hero", combat_manager.get_hero_states(), hero_rolls],
		["enemy", combat_manager.get_enemy_states(), enemy_rolls],
	]
	for side_variant in sides:
		var side: String = str(side_variant[0])
		var rolls: Dictionary = side_variant[2]
		for state_variant in side_variant[1]:
			var state: Dictionary = state_variant
			if bool(state.get("dead", false)):
				continue
			var state_id: String = str(state.get("id", ""))
			if not rolls.has(state_id):
				continue
			var eff_roll: int = combat_manager.get_effective_roll(state, int(rolls[state_id]))
			var entry: Dictionary = dice_manager.get_ability_for_roll(state["unit"], eff_roll)
			_primer.notice_rolled_ability(entry.get("raw", {}), side, state_id)


func _roll_for_states(states: Array) -> Dictionary:
	return _engine.roll_states(states)


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
		# Jam value feed (Build G item 2): the die numeral must show the JAMMED
		# value, not the raw face — same cap get_effective_roll applies.
		entry["jam_cap"] = int(state.get("jam_cap", 0))
		entries.append(entry)
	return entries


func _apply_frozen_roll_overrides(states: Array, rolls: Dictionary) -> void:
	_engine.apply_frozen_roll_overrides(states, rolls)


func _record_roll_values_for_states(states: Array, rolls: Dictionary) -> void:
	_engine.record_roll_values_for_states(states, rolls)


func _get_roll_value_for_state(rolls: Dictionary, state: Dictionary) -> int:
	return _engine.roll_value_for_state(rolls, state)


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


# ── Die-docked result tags ──────────────────────────────────────────────────────
# One filled plate per die that has resolved an effect, drawn from the die's live screen
# position so it tracks settle / reroll / nudge. Rebuilt only when a die's effects change;
# repositioned every frame. Empty dice get no plate.
func _process(_delta: float) -> void:
	_sync_die_tags()


func _ensure_die_tag_layer() -> void:
	if _die_tag_layer != null and is_instance_valid(_die_tag_layer):
		return
	_die_tag_layer = Control.new()
	_die_tag_layer.name = "DieTagLayer"
	_die_tag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_die_tag_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_die_tag_layer.z_index = 80   # above the tray/cards, below inspect popups (CanvasLayers)
	add_child(_die_tag_layer)


# The VISIBLE pip surface for a unit (primer glyph anchors resolve against
# this, Kev 2026-07-12): the rail AbilityReadout is an alpha-0 data holder —
# its glyph nodes are ghosts with live rects, which is how the primer ring
# landed on empty space. Returns null when no plate exists (unrolled/empty).
func get_die_tag_plate(side: String, unit_id: String) -> Control:
	var entry: Dictionary = _die_tags.get("%s:%s" % [side, unit_id], {})
	var plate: Variant = entry.get("plate")
	if plate is Control and is_instance_valid(plate):
		return plate as Control
	return null


func _sync_die_tags() -> void:
	if dice_tray_3d == null or not is_instance_valid(dice_tray_3d):
		return
	if hero_card_views.is_empty() and enemy_card_views.is_empty():
		return
	_ensure_die_tag_layer()
	var live: Dictionary = {}
	_sync_side_die_tags("hero", hero_card_views, live)
	_sync_side_die_tags("enemy", enemy_card_views, live)
	for key in _die_tags.keys():
		if not live.has(key):
			var plate_variant: Variant = (_die_tags[key] as Dictionary).get("plate")
			if plate_variant is Control and is_instance_valid(plate_variant):
				(plate_variant as Control).queue_free()
			_die_tags.erase(key)


func _sync_side_die_tags(side: String, views: Array, live: Dictionary) -> void:
	for view_variant in views:
		var view: Dictionary = view_variant
		var readout: Object = view.get("readout")
		if readout == null or not is_instance_valid(readout) or not readout.has_method("is_showing"):
			continue
		if not bool(readout.call("is_showing")):
			continue
		var effects: Array = readout.call("tag_effects")
		if effects.is_empty():
			continue
		var unit_id: String = str((view.get("state", {}) as Dictionary).get("id", ""))
		if unit_id == "":
			continue
		var bounds: Rect2 = dice_tray_3d.get_die_screen_bounds(side, unit_id)
		if bounds.position == Vector2.INF:
			continue
		var diameter: float = dice_tray_3d.get_die_projected_diameter(side, unit_id)
		if diameter > 2.0:
			_die_tag_diameter = diameter
		var target: String = str(readout.call("tag_target"))
		var sig: String = _die_tag_signature(effects, target)
		var key: String = "%s:%s" % [side, unit_id]
		var entry: Dictionary = _die_tags.get(key, {})
		var plate_variant: Variant = entry.get("plate")
		if not (plate_variant is Control) or not is_instance_valid(plate_variant) or str(entry.get("sig", "")) != sig:
			if plate_variant is Control and is_instance_valid(plate_variant):
				(plate_variant as Control).queue_free()
			plate_variant = _build_die_tag(side, effects, target)
			_die_tag_layer.add_child(plate_variant)
			_die_tags[key] = {"plate": plate_variant, "sig": sig}
		live[key] = true
		_position_die_tag(plate_variant as Control, side, bounds)


# Signature carries the rounded diameter so tags rebuild + refit on a resize.
func _die_tag_signature(effects: Array, target: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for effect_variant in effects:
		var effect: Dictionary = effect_variant
		parts.append("%s=%s@%s" % [str(effect.get("kind", "")), str(effect.get("value", "")), str(effect.get("duration", ""))])
	return "d%d|%s|%s" % [int(round(_die_tag_diameter)), target, "/".join(parts)]


# The uniform tag size: width = projected die diameter, height = a fixed fraction of it.
# Same for every die, independent of content.
func _die_tag_size() -> Vector2:
	var w: float = round(_die_tag_diameter)
	return Vector2(w, round(w * DIE_TAG_HEIGHT_RATIO))


func _tag_pip_profile(value_font: int) -> Dictionary:
	return {
		"icon_size": int(round(value_font * 0.9)),
		"value_font": value_font,
		"duration_ratio": 0.6,
		"icon_value_gap": 2,
		"group_min_width": 0,
		"outline": 2,
		"duration_outline": 1,
	}


func _estimate_tag_content_width(effects: Array, target: String, value_font: int, profile: Dictionary) -> float:
	var total: float = 0.0
	for i in range(effects.size()):
		if i > 0:
			total += 5.0   # row separation
		total += EffectPip.estimate_display_width(effects[i] as Dictionary, profile)
	if target != "":
		total += 5.0 + float(target.length()) * float(value_font) * 0.6
	return total


# The die tag plate: transparent (pips + numbers read directly over the tray,
# their own text outline keeps them legible — Kev 2026-07-09), sized to the
# die's fixed slot. Three presentation tiers (Kev 2026-07-10):
#   1. basic ability  — full font + full pips, one line
#   2. extended       — one-step shrink (x0.72 font + pips), one line
#   3. complicated    — the shrunk size WRAPPED onto two centered lines
# The slot width is fixed per die; content never overflows it sideways.
func _build_die_tag(side: String, effects: Array, target: String) -> Panel:
	var tag_size: Vector2 = _die_tag_size()
	var slot_w: float = round(_die_tag_diameter * DIE_TAG_SLOT_WIDTH_RATIO)
	var base_font: int = int(round(tag_size.y * DIE_TAG_FONT_RATIO))
	var value_font: int = base_font
	var profile: Dictionary = _tag_pip_profile(value_font)
	var rows: Array = [{"effects": effects, "target": target}]
	if _estimate_tag_content_width(effects, target, value_font, profile) > slot_w:
		# Tier 2: one-step shrink, still a single line.
		value_font = int(round(base_font * DIE_TAG_SHRINK_STEP))
		profile = _tag_pip_profile(value_font)
		if _estimate_tag_content_width(effects, target, value_font, profile) > slot_w and effects.size() >= 2:
			# Tier 3: wrap the shrunk content onto two lines.
			rows = _split_tag_rows(effects, target, value_font, profile, slot_w)

	var row_h: float = round(tag_size.y * (1.0 if value_font == base_font else DIE_TAG_SHRINK_STEP))
	var plate: Panel = Panel.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.clip_contents = false
	plate.custom_minimum_size = Vector2(slot_w, row_h * float(rows.size()))
	plate.size = plate.custom_minimum_size
	plate.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.add_child(center)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 0)
	center.add_child(stack)
	for row_variant in rows:
		var row: Dictionary = row_variant
		var line: Control = _build_tag_content(side, row.get("effects", []), str(row.get("target", "")), value_font, profile)
		line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		stack.add_child(line)
	return plate


# Greedy split for tier 3: the largest effect prefix that fits the slot stays on
# line 1; the remainder (plus the target label) wraps to line 2.
func _split_tag_rows(effects: Array, target: String, value_font: int, profile: Dictionary, slot_w: float) -> Array:
	var split: int = 1
	for count in range(effects.size() - 1, 0, -1):
		if _estimate_tag_content_width(effects.slice(0, count), "", value_font, profile) <= slot_w:
			split = count
			break
	return [
		{"effects": effects.slice(0, split), "target": ""},
		{"effects": effects.slice(split), "target": target},
	]


func _build_tag_content(side: String, effects: Array, target: String, value_font: int, profile: Dictionary) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 5)
	for effect_variant in effects:
		row.add_child(EffectPip.build_group(effect_variant as Dictionary, profile, side))
	if target != "":
		var target_label: Label = Label.new()
		target_label.text = target
		target_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		target_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		PixelUI.apply_pixel_font(target_label)
		target_label.add_theme_font_size_override("font_size", value_font)
		target_label.add_theme_color_override("font_color", PixelUI.TEXT_MUTED)
		row.add_child(target_label)
	return row


# One shared derivation for every tag: center x on the die's bounds center, dock flush just
# OUTSIDE the die's projected bounds (a tiny gap, never overlapping) — below hero dice,
# above enemy dice. Uses the plate's OWN size (set at build): a two-line tier-3
# tag is taller and must grow AWAY from the die, not over it.
func _position_die_tag(plate: Control, side: String, die_bounds: Rect2) -> void:
	if plate == null or not is_instance_valid(plate):
		return
	var tag_size: Vector2 = plate.custom_minimum_size
	plate.size = tag_size
	var center_x: float = die_bounds.position.x + die_bounds.size.x * 0.5
	var x: float = center_x - tag_size.x * 0.5
	var y: float
	if side == "hero":
		y = die_bounds.end.y + DIE_TAG_GAP                 # flush below the die
	else:
		y = die_bounds.position.y - DIE_TAG_GAP - tag_size.y   # flush above the die
	plate.global_position = Vector2(round(x), round(y))


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
		# fix-2.2: the ±roll chip on the die resolves too — when this unit's
		# effective roll is shifted, the chip's definition rides along.
		var chip_states: Array = combat_manager.get_hero_states() if side == "hero" else combat_manager.get_enemy_states()
		for chip_state_variant in chip_states:
			var chip_state: Dictionary = chip_state_variant
			if str(chip_state.get("id", "")) != unit_id:
				continue
			var chip_mods: Dictionary = combat_manager.get_roll_modifier_totals(chip_state)
			var chip_delta: int = int(chip_mods["roll_buff"]) - int(chip_mods["roll_rfe"])
			if chip_delta != 0:
				payload["statuses"] = [InspectResolver.roll_chip_entry(chip_delta)]
			break
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

	# Build J: capture pre-round chip tokens BEFORE state applies, so deferred
	# chips keep showing their old values until their causing beat.
	_feedback.snapshot_pre_resolve_statuses()
	# Resolve the round through the shared engine (A.1 cluster 6): build effective
	# rolls, resolve_round, clear the spent roll state, drain pending protocol.
	# This scene keeps XP recording, feedback, logging, income, and scene handoff.
	var step: Dictionary = _engine.resolve_step(_state)
	var result: Dictionary = step["result"]
	var eff_hero_rolls: Dictionary = step["eff_hero_rolls"]
	for unit_id_variant in eff_hero_rolls.keys():
		_game_state().record_hero_effective_roll(str(unit_id_variant), int(eff_hero_rolls[unit_id_variant]))
	_clear_die_tooltip_overlays()
	active_targeting_hero_id = ""
	legal_target_ids.clear()
	legal_target_side = ""
	pending_manual_target_ids.clear()
	has_player_target_assignment = false
	_clear_target_assignments()
	roll_button.disabled = true
	_append_round_log(result.get("log", []))
	var protocol_grant: int = int(step["protocol_grant"])
	if protocol_grant > 0:
		_gain_protocol(protocol_grant)
		_append_log("Protocol +%d from kill -> %d" % [protocol_grant, protocol_points])
	var protocol_drain: int = int(step["protocol_drain"])
	if protocol_drain > 0:
		protocol_points = maxi(0, protocol_points - protocol_drain)
		_update_protocol_bar()
		_append_log("Protocol SIPHONED -%d -> %d" % [protocol_drain, protocol_points])
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
	_card_view.refresh_all_cards()
	if skip_feedback and is_inside_tree() and get_tree() != null:
		await get_tree().process_frame
	_is_resolving_turn = false

	var outcome: String = str(result.get("result", "ongoing"))
	if outcome == "victory":
		battle_over = true
		MusicManager.set_combat(false)
		roll_button.disabled = true
		_persist_protocol_carryover()
		_capture_battle_victory_for_xp()
		if _game_state().tutorial_mode:
			_emit_tutorial("won")
			return
		if _auto_battle_running:
			_debug_advance_after_auto_battle_victory()
		elif _game_state().is_final_battle():
			_refresh_summary("Boss defeated. Run complete.")
			_game_state().finish_run("victory")
			_scene_manager().go_to_run_end()
		else:
			_refresh_summary("Victory. Routing to rewards.")
			_store_battle_snapshot()
			_game_state().prepare_battle_rewards()
			_scene_manager().go_to_reward_screen()
	elif outcome == "defeat":
		battle_over = true
		MusicManager.set_combat(false)
		roll_button.disabled = true
		_refresh_summary("Defeat. Squad wiped.")
		_game_state().finish_run("defeat")
		_scene_manager().go_to_run_end(true)  # defeat -> POWER DOWN transition
	else:
		if _try_finish_battle_from_current_state():
			return
		# +1 PP at end of each resolved round (ongoing only). Blackout / Deep
		# Cache income debt are engine rules shared with the sim (sim-B.2).
		var income: Dictionary = _engine.end_of_round_income(_round_number, _income_debt)
		_income_debt = int(income["debt_left"])
		match str(income["reason"]):
			"blackout":
				_append_log("BLACKOUT - no Protocol income yet.")
			"debt":
				_append_log("Income owed - %d turns of debt remain." % _income_debt)
			_:
				_gain_protocol(1)
				_append_log("Protocol +1 -> %d" % protocol_points)
		_round_number += 1
		transition(PHASE_AWAIT_ROLL)
		_emit_tutorial("turn_resolved", {"protocol": protocol_points})


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


# Read-only review snapshot (Batch 5): grab the final battle frame so the reward
# screen's "View Battlescreen" can show the player what the board looked like. The
# most-recently-rendered frame is the post-feedback board (feedback is awaited before
# victory is processed). Skipped headless / auto-battle — no human reviewer there, and
# the dummy renderer's readback is meaningless.
func _store_battle_snapshot() -> void:
	if _auto_battle_running or DisplayServer.get_name() == "headless":
		return
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var viewport_texture: ViewportTexture = viewport.get_texture()
	if viewport_texture == null:
		return
	var image: Image = viewport_texture.get_image()
	if image == null:
		return
	_game_state().last_battle_snapshot = ImageTexture.create_from_image(image)


# Capture the FULL final combat state so the reward screen's "View Battlescreen"
# can re-enter this scene read-only (real cards + inspect, not the flat image).
# Deep-copied via snapshot_state (keeps unit Resource refs alive through the
# scene change); skipped headless / auto-battle like the image snapshot.
func _capture_review_state() -> void:
	if _auto_battle_running or DisplayServer.get_name() == "headless":
		return
	_game_state().battle_review_state = {
		"combat": combat_manager.snapshot_state(),
		"protocol": protocol_points,
		"hero_rolls": hero_rolls.duplicate(true),
		"enemy_rolls": enemy_rolls.duplicate(true),
	}


func _capture_battle_victory_for_xp() -> void:
	_game_state().capture_battle_end_survival(combat_manager.get_hero_states())
	# Memorial Protocol (pkg7.4) tracks who fell in the last two battles.
	var dead_ids: Array = []
	for hero_state_variant in combat_manager.get_hero_states():
		if bool((hero_state_variant as Dictionary).get("dead", false)):
			dead_ids.append(str((hero_state_variant as Dictionary).get("id", "")))
	_game_state().record_battle_hero_deaths(dead_ids)


func _finish_battle_victory() -> void:
	battle_over = true
	MusicManager.set_combat(false)
	_disable_combat_actions()
	_persist_protocol_carryover()
	_capture_battle_victory_for_xp()
	if _game_state().tutorial_mode:
		_emit_tutorial("won")
		return
	if _auto_battle_running:
		_debug_advance_after_auto_battle_victory()
	elif _game_state().is_final_battle():
		_refresh_summary("Boss defeated. Run complete.")
		_game_state().finish_run("victory")
		_scene_manager().go_to_run_end()
	else:
		# Snapshot the clean board BEFORE the round-complete modal covers it.
		_store_battle_snapshot()
		_capture_review_state()
		_show_round_complete_modal()


func _finish_battle_defeat() -> void:
	battle_over = true
	MusicManager.set_combat(false)
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
	_protocol.reset_battle_over_state()
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
	# Component: Modal (Polish Build A) — the old bright-gold border made a routine
	# end-of-round popup wear the ceremonial tier; gold is major-event only now.
	PixelUI.style_component(panel, PixelUI.COMPONENT_MODAL)
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
	title.text = "ROUND COMPLETE"
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
	_round_complete_next_button.text = "NEXT"
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


# Central protocol gain: caps at MAX_PROTOCOL; the Overflow Vent relic turns
# every point past the cap into 2 damage to a random living enemy.
func _gain_protocol(amount: int) -> void:
	if amount <= 0:
		return
	# Rule delegated to BattleEngine (A.1); the engine mutates _state.protocol_points,
	# this scene keeps the bar + logs.
	var vent_hits: Array = _engine.gain_protocol(_state, amount, _max_protocol())
	_update_protocol_bar()
	for hit_variant in vent_hits:
		var hit: Dictionary = hit_variant
		_append_log("Overflow Vent: %d damage to %s." % [int(hit["amount"]), hit["target"]["unit"].display_name])
	if not vent_hits.is_empty() and _card_view != null:
		_card_view.refresh_all_cards()


func _hero_has_gear_effect(hero_id: String, effect_type: String) -> bool:
	for gear_id in _game_state().gear_by_unit.get(hero_id, []):
		var item: ItemData = DataManager.get_item(str(gear_id)) as ItemData
		if item != null and item.effect != null and str(item.effect.get("type", "")) == effect_type:
			return true
	return false


# Intercept battle effects (pkg7.4): one-shot flags consumed at battle start.
var _battle_effects: Dictionary = {}
var _income_debt: int:
	get: return _state.income_debt
	set(value): _state.income_debt = value


func _apply_intercept_battle_effects() -> void:
	var gs: Variant = _game_state()
	_battle_effects = (gs.next_battle_effects as Dictionary).duplicate(true)
	gs.next_battle_effects.clear()
	# Prisoner Exchange's follow-up arms AFTER this battle's own modifier ran.
	gs.promote_followup_effects()

	# Rule application delegated to BattleEngine (sim-B.2) — one implementation
	# shared with the headless sim. The scene keeps the bar + logging.
	var applied: Dictionary = _engine.apply_battle_start_external_effects(
		_battle_effects, gs.hero_run_mods, int(gs.run_protocol_per_battle)
	)
	_income_debt = int(applied["income_debt"])
	for line_variant in applied["logs"]:
		_append_log(str(line_variant))
	var start_protocol: int = int(applied["start_protocol"])
	if start_protocol > 0:
		_gain_protocol(start_protocol)
		_append_log("Battle-start Protocol +%d -> %d" % [start_protocol, protocol_points])


func _squad_id_for_state(hero_state: Dictionary) -> String:
	var unit: Variant = hero_state.get("unit")
	if unit is UnitData:
		return str((unit as UnitData).id)
	return str(hero_state.get("id", ""))


# Priming Charge gear: the first Nudge each battle is free (per holder).
var _free_nudge_used: Dictionary:
	get: return _state.free_nudge_used
	set(value): _state.free_nudge_used = value

# Round counter (1-based) for turn-scoped relics (Resonant Chorus).
var _round_number: int = 1

# Root Access boss relic: once per battle, Set costs 0.
var _root_access_used: bool:
	get: return _state.root_access_used
	set(value): _state.root_access_used = value

# Twin Fates relic: once per battle, copy one hero die's result to another.
var _twin_fates_used: bool:
	get: return _state.twin_fates_used
	set(value): _state.twin_fates_used = value
var _twin_fates_source_id: String:
	get: return _state.twin_fates_source_id
	set(value): _state.twin_fates_source_id = value


# Vengeance Protocol / Dead Man's Hand (forced 20s) and Resonant Chorus (turn-1
# dice can't land below 8) — roll-time face overrides. There is no "natural 20"
# concept: forcing a 20 sets the die's face to 20 like any other override
# (ruling NK-02).
func _apply_roll_relic_overrides(skip_dice_visuals: bool = false) -> void:
	var chorus_floor: bool = combat_manager.has_relic("turn1RollFloor") and _round_number == 1
	for hero_state_variant in combat_manager.get_hero_states():
		var hero_state: Dictionary = hero_state_variant
		if bool(hero_state.get("dead", false)):
			continue
		# A frozen die is crusted static — roll overrides can't move it.
		if int(hero_state.get("die_freeze_turns", 0)) > 0:
			continue
		var hero_id: String = str(hero_state["id"])
		var changed: bool = false
		if bool(hero_state.get("forced_20_pending", false)):
			hero_state["forced_20_pending"] = false
			hero_rolls[hero_id] = 20
			changed = true
			_append_log("%s rolls a forced 20!" % hero_id)
		elif chorus_floor and int(hero_rolls.get(hero_id, 0)) > 0 and int(hero_rolls.get(hero_id, 0)) < 8:
			hero_rolls[hero_id] = 8
			changed = true
			_append_log("Resonant Chorus: %s's die is lifted to 8." % hero_id)
		if changed and dice_tray_3d != null and not skip_dice_visuals:
			dice_tray_3d.update_die_result_in_place("hero", hero_id, _get_effective_roll_for_state(hero_state, hero_id))


# Roll-time gear: Sync Antenna (holder + an ally rolling the same number both
# gain +3 to it). The Overload Capacitor Protocol grant and the lifetime 20s
# stat moved to resolution time in combat_manager, so they key on the die's
# FINAL face (a die Set/Nudged to 20 now counts — ruling NK-02) and fire once
# even under freeze=repeat (NK-04).
func _apply_post_roll_gear_effects() -> void:
	var hero_states: Array = combat_manager.get_hero_states()
	var synced_ids: Dictionary = {}
	for hero_state_variant in hero_states:
		var holder: Dictionary = hero_state_variant
		if bool(holder.get("dead", false)):
			continue
		var holder_id: String = str(holder["id"])
		if not _hero_has_gear_effect(holder_id, "syncRollBonus"):
			continue
		var holder_roll: int = int(hero_rolls.get(holder_id, 0))
		if holder_roll <= 0:
			continue
		for other_variant in hero_states:
			var other: Dictionary = other_variant
			var other_id: String = str(other["id"])
			if other_id == holder_id or bool(other.get("dead", false)):
				continue
			if int(hero_rolls.get(other_id, 0)) != holder_roll:
				continue
			for sync_state in [holder, other]:
				var sid: String = str(sync_state["id"])
				if not synced_ids.has(sid):
					synced_ids[sid] = true
					# A real 1-turn roll-buff stack so the +3 actually reaches the
					# effective roll this round (audit A-041 — the old roll_buff
					# write was a display-only cache the effective path ignored).
					combat_manager.apply_item_roll_buff(sync_state, 3, 1)
			_append_log("Sync Antenna: matched %d - both dice +3." % holder_roll)


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
		transition(PHASE_READY_TO_END)
	else:
		transition(PHASE_TARGETING)
		_refresh_summary("Select hero targets.")


# --- Effective roll helpers ---

# Rules extracted to BattleEngine (A.1); these delegate, passing this scene's
# own roll/nudge/set state. The sim owns parallel dicts and calls the same
# engine methods — one rules engine.
func _get_effective_roll_for_state(state: Dictionary, unit_id: String) -> int:
	return _engine.effective_hero_roll(state, unit_id, _state)


func _get_effective_enemy_roll(state: Dictionary, unit_id: String) -> int:
	return _engine.effective_enemy_roll(state, unit_id, _state)


# §2 (Batch 4): enemy-reroll items (Phase Scrambler / Cascade Jammer) mutate
# enemy_rolls but nothing pushed the new value to the 3D die, so its numeral went
# stale while the card pips (which read enemy_rolls) updated. Route the rerolled
# die(s) through the same in-place tray update hero nudge/set/twin use, so the
# numeral and pips always agree. Skips frozen dice (their reroll fizzles).
func sync_enemy_dice_after_item_reroll(effect_type: String, target_state: Dictionary) -> void:
	if dice_tray_3d == null:
		return
	if effect_type == "enemyRerollDie":
		if target_state.is_empty():
			return
		var eid: String = str(target_state.get("id", ""))
		if eid != "" and enemy_rolls.has(eid) and int(target_state.get("die_freeze_turns", 0)) == 0:
			dice_tray_3d.update_die_result_in_place("enemy", eid, _get_effective_enemy_roll(target_state, eid))
	elif effect_type == "enemyRerollAll":
		for es_variant in combat_manager.get_enemy_states():
			var es: Dictionary = es_variant
			if bool(es.get("dead", false)) or int(es.get("die_freeze_turns", 0)) > 0:
				continue
			var eid2: String = str(es.get("id", ""))
			if enemy_rolls.has(eid2):
				dice_tray_3d.update_die_result_in_place("enemy", eid2, _get_effective_enemy_roll(es, eid2))


# Builds a dict of effective rolls for all living units in the given states array.
# Used to pass fully-resolved roll values into combat_manager.resolve_round().
func _build_effective_rolls(raw_rolls: Dictionary, states: Array, is_hero: bool) -> Dictionary:
	return _engine.build_effective_rolls(raw_rolls, states, is_hero, _state)


# Footer pip row (pixel snap law, INVARIANTS #14) — integer physical-pixel
# layout in scripts/ui/protocol_pips.gd. Preloaded: class_name cache may not
# exist on a fresh headless run.
const ProtocolPipsScript = preload("res://scripts/ui/protocol_pips.gd")
var _protocol_pips: Control = null
# Horizontal inset matching the dice-tray edge (Content margin + tray gutter), so the
# header/footer content lines up with the tray instead of running to the screen edge.
const TRAY_EDGE_INSET := 16
# Content's authored offsets (mirror the .tscn: top 170 = 144 header band + 26
# gap; bottom 144 = the footer band). _apply_safe_area() re-derives the offsets,
# so the authored values must be named here or a zero inset (every desktop run)
# would erase them.
const CONTENT_TOP_OFFSET := 170.0
const CONTENT_BOTTOM_OFFSET := 144.0


# Safe area — Build #2 RULING: the DICE FIELD absorbs the ENTIRE inset budget.
# The whole board shifts below the grown header band (top inset) and lifts above
# the gesture bar (bottom inset); the center/dice band gives up that exact
# height in battle_layout.refresh_board_layout, so the enemy rail, hero rail,
# footer, and header content region all keep their authored heights — desktop
# stays pixel-identical (insets 0 → authored offsets exactly). This replaces the
# Build-#1 ProtocolMargin bottom-pad mechanism, which shrank the footer ROW
# instead (the footer keeps its authored anatomy now). The Build-#1 flag — the
# grown band clipping the enemy name plates on device — is what this fixes.
func _apply_safe_area() -> void:
	var content: MarginContainer = get_node_or_null("Content") as MarginContainer
	if content != null:
		content.offset_top = CONTENT_TOP_OFFSET + float(PixelUI.safe_top)
		content.offset_bottom = -(CONTENT_BOTTOM_OFFSET + float(PixelUI.safe_bottom))
	if protocol_panel != null and is_instance_valid(protocol_panel):
		# The footer band rides above the gesture reserve at full authored height
		# (its top is re-derived from the hero cards by _position_zone_dividers).
		protocol_panel.offset_bottom = -float(PixelUI.safe_bottom)
	if _layout != null and is_instance_valid(_layout):
		# Full stabilize pass (not a single deferred refresh): the footer top is
		# derived from the hero cards' SETTLED rects, and a lone refresh reads
		# them pre-shift when insets change live (rotation/fold). Same loop the
		# scene runs at _ready; inset changes are rare, so the cost is nothing.
		Callable(_layout, "stabilize_board_layout").call_deferred()


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
	# Alignment contract (Kev 2026-07-10): the stack is exactly the action-button
	# height — the visible top of PROTOCOL N/M lines up with the button tops and
	# the pip bottoms line up with the button bottoms. Manual anchors (not a
	# VBox): m5x7 pads ~30% of its line height above the caps, so the label is
	# nudged up for its VISIBLE glyph top to sit at the stack top.
	var stack := Control.new()
	stack.name = "ProtocolStack"
	stack.custom_minimum_size = Vector2(0, BOTTOM_BAR_BUTTON_SIZE.y)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	# Label sits RIGHT on top of the pips (Kev 2026-07-10: anchoring it to the
	# stack top clipped the glyphs under the panel above). Bottom-anchored just
	# above the pip bar; the overlap eats m5x7's below-baseline padding.
	protocol_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	protocol_label.offset_bottom = -PROTOCOL_PIP_BAR_H + PROTOCOL_LABEL_PIP_OVERLAP
	protocol_label.offset_top = protocol_label.offset_bottom - PROTOCOL_LABEL_BOX_H
	protocol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	protocol_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	protocol_label.add_theme_font_size_override("font_size", PROTOCOL_STACK_LABEL_FONT)
	protocol_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	protocol_bar.offset_top = -PROTOCOL_PIP_BAR_H
	protocol_bar.offset_bottom = 0.0
	# The legacy footer-display sizing (aspect-derived width) must not re-shrink
	# the anchored bar.
	protocol_bar.custom_minimum_size = Vector2.ZERO


# Deep Cells directive: the Protocol cap rises while a living carrier stands.
# Rogue Engineer intercept: the cap override replaces the base cap.
func _max_protocol() -> int:
	# Rule delegated to BattleEngine (A.1). The is_inside_tree guard stays here
	# because bare instances (headless audits) run outside the tree — no autoloads.
	var cap_override: int = 0
	if is_inside_tree() and int(_game_state().run_protocol_cap_override) > 0:
		cap_override = int(_game_state().run_protocol_cap_override)
	return _engine.max_protocol(cap_override)


func _ensure_protocol_segments() -> void:
	if protocol_bar == null or not is_instance_valid(protocol_bar):
		return
	if _protocol_pips != null and is_instance_valid(_protocol_pips):
		return
	# Direction-05: 10 discrete segments over the hidden native ProgressBar fill.
	# Integer physical-pixel layout (pixel snap law) lives in ProtocolPips.
	protocol_bar.show_percentage = false
	protocol_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	protocol_bar.add_theme_stylebox_override("fill", StyleBoxEmpty.new())
	_protocol_pips = ProtocolPipsScript.new()
	_protocol_pips.name = "ProtocolSegments"
	_protocol_pips.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	protocol_bar.add_child(_protocol_pips)


func _update_protocol_bar() -> void:
	if protocol_bar == null:
		return
	protocol_bar.max_value = _max_protocol()
	protocol_bar.value = protocol_points
	_ensure_protocol_segments()
	if _protocol_pips != null and is_instance_valid(_protocol_pips):
		_protocol_pips.total = _max_protocol()
		_protocol_pips.filled = protocol_points
	# Numeric readout folded into the label so the count is always legible above the pips.
	protocol_label.text = "PROTOCOL %d/%d" % [protocol_points, _max_protocol()]
	protocol_value_label.text = "%d / %d" % [protocol_points, _max_protocol()]
	# Cost badges + affordability dim track every pool change (UI review S-4).
	if _protocol != null:
		_protocol.refresh_action_affordability()
	_emit_tutorial("protocol_changed", {"value": protocol_points})


func _ensure_protocol_footer_layout() -> void:
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
	# The stack layout (anchored label + pips, _ensure_protocol_stack_layout)
	# owns the bar's geometry — the legacy aspect-derived min size fought the
	# BOTTOM_WIDE anchors (Kev 2026-07-10 alignment contract).
	if protocol_row == null or protocol_row.get_node_or_null("ProtocolStack") == null:
		protocol_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var protocol_height: float = BOTTOM_BAR_BUTTON_SIZE.y * 0.74
		var protocol_width: float = roundf((PROTOCOL_FOOTER_SOURCE_SIZE.x / PROTOCOL_FOOTER_SOURCE_SIZE.y) * protocol_height)
		protocol_bar.custom_minimum_size = Vector2(protocol_width, protocol_height)


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

	# Tutorial: a single weak scripted enemy instead of the operation's battle, HP tuned so the
	# win lands on turn 2's nudged Plasma Lance.
	if _game_state().tutorial_mode:
		var base_enemy: EnemyData = _data_manager().get_enemy_by_display_name(TUTORIAL_ENEMY_NAME) as EnemyData
		if base_enemy != null:
			var tutorial_enemy: EnemyData = _duplicate_enemy(base_enemy)
			tutorial_enemy.max_hp = TUTORIAL_ENEMY_HP
			enemy_units = [tutorial_enemy]
			return

	var operation: OperationData = _data_manager().get_operation(_game_state().selected_operation_id) as OperationData
	if operation == null:
		return

	var battle_index: int = maxi(_game_state().current_battle - 1, 0)
	if battle_index >= operation.battles.size():
		return

	# Templated comps (pkg7.1): the run-start roll is the source of truth;
	# fall back to the authored comp when no resolved comp exists.
	var battle_entry: Dictionary = operation.battles[battle_index]
	var comp: Dictionary = _game_state().get_current_battle_comp()
	var enemy_names: Array = comp.get("names", [])
	var cloaked_names: Array = comp.get("cloaked", [])
	if enemy_names.is_empty():
		enemy_names = battle_entry.get("enemy_names", [])
		cloaked_names = battle_entry.get("cloaked_names", [])
	# Prisoner Exchange intercept: this battle fields one fewer enemy.
	if bool(_game_state().next_battle_effects.get("minus_one_enemy", false)) and enemy_names.size() > 1:
		enemy_names = enemy_names.duplicate()
		enemy_names.remove_at(enemy_names.size() - 1)
	for enemy_name in enemy_names:
		if enemy_units.size() >= GameState.SQUAD_UNIT_LIMIT:
			break
		var enemy: EnemyData = _data_manager().get_enemy_by_display_name(str(enemy_name)) as EnemyData
		if enemy != null:
			var enemy_copy: EnemyData = _duplicate_enemy(enemy)
			if cloaked_names.has(str(enemy_name)):
				enemy_copy.starts_cloaked = true
			enemy_units.append(enemy_copy)


func _refresh_summary(_extra_text: String) -> void:
	_update_battle_header()


func _update_battle_header() -> void:
	var operation: OperationData = _data_manager().get_operation(_game_state().selected_operation_id) as OperationData
	var op_name: String = operation.battle_name() if operation != null else "OP"
	PersistentHeader.set_run_active(true)
	PersistentHeader.update_progress(_game_state().current_battle, _game_state().total_battles, op_name)


# Pre-enum string name for a phase (tutorial payloads, tests, debug logs).
func phase_name(p: int) -> String:
	return str(PHASE_NAMES.get(p, "unknown"))


func phase_from_name(name: String) -> int:
	for p in PHASE_NAMES:
		if str(PHASE_NAMES[p]) == name:
			return p
	return Phase.AWAIT_ROLL


func is_item_pick_phase(p: int) -> bool:
	return p == Phase.ITEM_PICK_ALLY or p == Phase.ITEM_PICK_DEAD 		or p == Phase.ITEM_PICK_ENEMY or p == Phase.ITEM_PICK_ANY


# THE phase choke point — every phase change in the game routes through here
# (architecture review §1 rec 2). No other code assigns turn_phase.
func transition(next_phase: int) -> void:
	# Protocol-actions teardown on any transition (Set-value popup etc.).
	_protocol.on_phase_changed(next_phase)
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
		PHASE_TWIN_SOURCE_PICK:
			roll_button.visible = false
			roll_button.disabled = true
			roll_button.text = ""
			_refresh_summary("Twin Fates: tap the die to copy FROM.")
		PHASE_TWIN_TARGET_PICK:
			roll_button.visible = false
			roll_button.disabled = true
			roll_button.text = ""
			_refresh_summary("Twin Fates: tap the die to copy TO.")
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
		PHASE_ITEM_PICK_ANY:
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
	_emit_tutorial("phase", {"phase": phase_name(turn_phase)})


func _style_roll_button_for_phase() -> void:
	match turn_phase:
		PHASE_AWAIT_ROLL:
			# Active primary action: ready to roll — teal primary button.
			roll_button.icon = null
			roll_button.custom_minimum_size = CENTER_ACTION_BUTTON_SIZE
			PixelUI.style_primary_button(roll_button, CENTER_ACTION_BUTTON_FONT_SIZE)
		PHASE_TARGETING:
			# Hidden: targetable cards use team border color (see CompactUnitCard).
			pass
		PHASE_READY_TO_END:
			# Active primary action: close out the turn — amber (commit) variant.
			roll_button.icon = null
			roll_button.custom_minimum_size = CENTER_ACTION_BUTTON_SIZE
			PixelUI.style_primary_button(roll_button, CENTER_ACTION_BUTTON_FONT_SIZE, true)
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


func _update_phase_target_sets() -> void:
	if not is_item_pick_phase(turn_phase):
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
			legal_target_ids = _get_dead_hero_ids()
		PHASE_ITEM_PICK_ENEMY:
			legal_target_side = "enemy"
			legal_target_ids = _get_legal_target_ids("enemy")
		PHASE_ITEM_PICK_ANY:
			legal_target_side = "any"
			legal_target_ids = _get_legal_target_ids("any")


func _is_target_highlight_phase() -> bool:
	if is_item_pick_phase(turn_phase):
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
	# Hostile single-target picks go through the shared personality choke-point
	# in combat_manager (slot order — PACK depends on it); the loop below only
	# fills in the non-hostile display targets (self / ally / AoE).
	var effective_enemy_rolls: Dictionary = {}
	for enemy_view_variant in enemy_card_views:
		var enemy_view: Dictionary = enemy_view_variant
		var enemy_state: Dictionary = enemy_view["state"]
		if bool(enemy_state["dead"]) or enemy_rolls.get(enemy_state["id"], null) == null:
			continue
		effective_enemy_rolls[enemy_state["id"]] = _get_effective_enemy_roll(enemy_state, str(enemy_state["id"]))
	combat_manager.assign_enemy_intents(effective_enemy_rolls, dice_manager)
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
	# Cast order: a fresh targeting phase — reset the stamp sequence and clear
	# any stale stamps (the engine already cleared them at round resolution).
	_cast_stamp_counter = 0
	for state_variant in combat_manager.get_hero_states():
		_clear_cast_stamp(state_variant)

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
			# Forced assignments are commits: stamped in squad order.
			_stamp_cast(hero_state)
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
	# Single-target taunt (G-4): pick the ONE enemy to mark. The shield halves
	# of Fortify/Challenge/Dig In are self (auto), so this stays the ability's
	# single manual pick (INVARIANTS #12).
	if bool(raw.get("taunt", false)):
		return "enemy"
	if bool(raw.get("reviveAll", false)):
		return ""
	if bool(raw.get("revive", false)):
		return "dead_hero"
	if bool(raw.get("healTgt", false)) or bool(raw.get("shTgt", false)) or bool(raw.get("wardTgt", false)):
		return "hero"
	if bool(raw.get("rfmTgt", false)):
		return "hero"
	# Every hostile flag combat_manager resolves through _hostile_single_target
	# on a hero ability MUST appear in this disjunction, or a 0-damage ability
	# carrying it falls through to auto-assign and the player never gets the
	# pick (the Build I Target Lock bug: dmg 0 + mark had no branch, so the
	# mark silently hit the first-living-enemy fallback). mark/jam/rewrite are
	# the hero-kit-authored ones today; hijack/siphon are enemy-only and breach
	# only resolves inside the damage pass, so they take no branch here.
	var has_single_enemy_effect: bool = (
		(int(raw.get("dmg", 0)) > 0 and not bool(raw.get("blastAll", false)))
		or int(raw.get("burn", 0)) > 0
		or (int(raw.get("rfe", 0)) > 0 and not bool(raw.get("rfeAll", false)))
		or bool(raw.get("rfeOnly", false))
		or bool(raw.get("mark", false))
		or bool(raw.get("jam", false))
		or bool(raw.get("rewrite", false))
	)
	if has_single_enemy_effect:
		return "enemy"
	if bool(raw.get("blastAll", false)) or bool(raw.get("healAll", false)) or bool(raw.get("shieldAll", false)):
		return ""
	return ""


func _queue_or_auto_assign_manual_target(hero_state: Dictionary, manual_side: String) -> void:
	var hero_id: String = str(hero_state["id"])
	var target_ids: Array = _get_legal_target_ids(manual_side, hero_state)
	pending_manual_target_ids.erase(hero_id)
	if target_ids.is_empty():
		_set_state_target(hero_state, "", _get_no_legal_target_display(manual_side))
		# No legal target = nothing to pick; the hero still fires (engine
		# fallback/fizzle), so it commits into the order now.
		_stamp_cast(hero_state)
		return
	if _try_auto_assign_single_manual_target(hero_state, manual_side, target_ids):
		return
	if not pending_manual_target_ids.has(hero_id):
		pending_manual_target_ids.append(hero_id)
	hero_state["target_display"] = "--"
	# Back in the pending queue: uncommitted until the target tap lands.
	_clear_cast_stamp(hero_state)


func _try_auto_assign_single_manual_target(hero_state: Dictionary, target_side: String, target_ids: Array) -> bool:
	# The tutorial teaches the explicit tap-a-die → tap-the-enemy flow. It fights a single enemy,
	# so every shot would otherwise auto-assign here: pending_manual_target_ids would be empty, the
	# turn would jump straight to READY_TO_END, the "assigned" beat would never fire, and the
	# coachmark would wait forever. Force manual targeting so the player actually performs it.
	if _game_state().tutorial_mode:
		return false
	if target_ids.size() != 1:
		return false
	var target_id: String = str(target_ids[0])
	var target_state: Dictionary = _find_manual_target_state(target_side, target_id)
	if target_state.is_empty():
		return false
	_set_state_target(hero_state, target_id, str(target_state["unit"].display_name))
	# A completed assignment (the single legal target auto-commits).
	_stamp_cast(hero_state)
	pending_manual_target_ids.erase(str(hero_state["id"]))
	if active_targeting_hero_id == str(hero_state["id"]):
		active_targeting_hero_id = ""
		legal_target_ids.clear()
		legal_target_side = ""
		_card_view.refresh_all_cards()
		if pending_manual_target_ids.is_empty():
			transition(PHASE_READY_TO_END)
		else:
			_refresh_summary("Select the next hero to target.")
	return true


func _get_no_legal_target_display(target_side: String) -> String:
	if target_side == "dead_hero":
		return "No Fallen"
	return "--"


func _auto_assign_hero_target(hero_state: Dictionary, ability_entry: Dictionary) -> void:
	# Every auto-assign is a cast-order commit: stamped immediately (squad
	# order at targeting start; end-of-order on a recommit).
	_stamp_cast(hero_state)
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
	if bool(raw.get("healLowest", false)) or bool(raw.get("shieldLowest", false)):
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
	# Hostile single-hero picks were already made by the shared personality
	# choke-point (combat_manager.assign_enemy_intents) — this function only
	# labels the remaining display targets. The old ai_type smart/dumb branch
	# (and its pure-debuff-targets-highest-HP special case) is gone; ai_type
	# itself is untouched and still gates elite summons / summon injection.
	var raw: Dictionary = ability_entry.get("raw", {})
	if str(enemy_state.get("selected_target_id", "")) != "" and str(enemy_state.get("target_display", "--")) != "--":
		return

	# AoE damage: no single pick — the whole squad is the target.
	if int(raw.get("dmg", 0)) > 0 and bool(raw.get("blastAll", false)):
		_set_state_target(enemy_state, "", "All Squad")
		return

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
	legal_target_ids = _get_legal_target_ids(legal_target_side, hero_state)
	if _try_auto_assign_single_manual_target(hero_state, legal_target_side, legal_target_ids):
		return
	_card_view.refresh_all_cards()
	_refresh_summary("Choose a target for %s." % str(hero_state["unit"].display_name))
	# Targeting has begun (a die/hero is picked, awaiting its target) — the tutorial opens up to
	# the whole screen here so the enemy is an easy tap.
	_emit_tutorial("targeting_started", {"hero": hero_id})


# Re-tap rule (cast order): an already-committed hero can always be re-tapped —
# it unassigns (manual abilities return to the pending queue) and recommitting
# appends a fresh stamp at the end of the order. This replaced the old
# _can_retarget_hero direct-retarget predicate.
func _can_unassign_hero(hero_id: String) -> bool:
	var hero_state: Dictionary = _find_state_by_id(combat_manager.get_hero_states(), hero_id)
	if hero_state.is_empty() or bool(hero_state.get("dead", false)):
		return false
	if not _has_roll_for_state(hero_rolls, hero_state):
		return false
	return _hero_cast_stamp(hero_state) > 0


# Re-tap on a committed hero. Manual abilities (with a live legal-target set and
# no taunt lock) go back to the pending queue and immediately re-open targeting,
# so a retarget stays two taps; the fresh stamp lands when the new target does.
# Auto abilities and taunt-locked heroes have nothing to re-pick — one tap moves
# them to the END of the current order.
func _unassign_hero_cast(hero_id: String) -> void:
	var hero_state: Dictionary = _find_state_by_id(combat_manager.get_hero_states(), hero_id)
	if hero_state.is_empty() or bool(hero_state.get("dead", false)):
		return
	var eff_roll: int = _get_effective_roll_for_state(hero_state, hero_id)
	var ability_entry: Dictionary = dice_manager.get_ability_for_roll(hero_state["unit"], eff_roll)
	var manual_side: String = _get_manual_target_side(ability_entry)
	var manual_retarget: bool = (
		manual_side != ""
		and _get_taunt_enemy_id() == ""
		and not _get_legal_target_ids(manual_side, hero_state).is_empty()
	)
	_clear_cast_stamp(hero_state)
	if manual_retarget:
		_set_state_target(hero_state, "", "--")
		if not pending_manual_target_ids.has(hero_id):
			pending_manual_target_ids.append(hero_id)
		if turn_phase == PHASE_READY_TO_END:
			transition(PHASE_TARGETING)
		_select_targeting_hero(hero_id)
		return
	_stamp_cast(hero_state)
	_card_view.refresh_all_cards()
	_refresh_summary("%s moves to the end of the cast order." % str(hero_state["unit"].display_name))


func _assign_target_to_active_hero(target_id: String, target_side: String) -> void:
	var hero_state: Dictionary = _find_state_by_id(combat_manager.get_hero_states(), active_targeting_hero_id)
	if hero_state.is_empty():
		return
	var target_state: Dictionary = _find_manual_target_state(target_side, target_id)
	if target_state.is_empty():
		return
	_set_state_target(hero_state, target_id, str(target_state["unit"].display_name))
	# The player's tap completes this assignment: commit into the cast order.
	_stamp_cast(hero_state)
	has_player_target_assignment = true
	pending_manual_target_ids.erase(active_targeting_hero_id)
	active_targeting_hero_id = ""
	legal_target_ids.clear()
	legal_target_side = ""
	_card_view.refresh_all_cards()
	_emit_tutorial("assigned", {"remaining": pending_manual_target_ids.size()})
	if pending_manual_target_ids.is_empty():
		transition(PHASE_READY_TO_END)
	else:
		_refresh_summary("Select the next hero to target.")


# Downed hero ids — the legal targets for a revive item (Defib Spark, A-061).
func _get_dead_hero_ids() -> Array:
	var ids: Array = []
	for hero_state_variant in combat_manager.get_hero_states():
		var hero_state: Dictionary = hero_state_variant
		if bool(hero_state.get("dead", false)):
			ids.append(str(hero_state["id"]))
	return ids


func _get_legal_target_ids(target_side: String, for_hero_state: Dictionary = {}) -> Array:
	# Taunt (enemy-side): a taunted hero's hostile picks are restricted to the
	# taunter — illegal targets don't highlight, and taps on them do nothing.
	if target_side == "enemy" and not for_hero_state.is_empty():
		var taunted_by: String = str(for_hero_state.get("lured_by_id", ""))
		if taunted_by != "":
			var taunter: Dictionary = _find_state_by_id(combat_manager.get_enemy_states(), taunted_by)
			if not taunter.is_empty() and not bool(taunter.get("dead", false)):
				return [taunted_by]
	var ids: Array = []
	var states: Array = []
	var enemy_states: Array = combat_manager.get_enemy_states()
	if target_side == "any":
		states.append_array(combat_manager.get_hero_states())
		states.append_array(enemy_states)
	elif target_side == "dead_hero":
		states = combat_manager.get_hero_states()
	else:
		states = combat_manager.get_hero_states() if target_side == "hero" else enemy_states
	for state_variant in states:
		var state: Dictionary = state_variant
		if target_side == "dead_hero":
			if bool(state["dead"]):
				ids.append(str(state["id"]))
			continue
		if bool(state["dead"]):
			continue
		# Cloak blocks HOSTILE single-target picks only; friendly picks on
		# cloaked allies are always legal (CONFIRMED per Kev 2026-07-06,
		# DECISIONS_RESOLVED #12).
		if bool(state.get("cloaked", false)) and enemy_states.has(state):
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


func _first_living_enemy_ally_state(enemy_state: Dictionary) -> Dictionary:
	for state_variant in combat_manager.get_enemy_states():
		var state: Dictionary = state_variant
		if state == enemy_state:
			continue
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


func _set_state_target(state: Dictionary, target_id: String, target_display: String) -> void:
	state["selected_target_id"] = target_id
	state["target_display"] = target_display


# --- Player-chosen cast order (stamping) ---

# Commit a hero into the firing order: the next monotonic stamp. Re-stamping an
# already-stamped hero moves it to the END of the current order (the re-tap /
# roll-modifier recommit rule).
func _stamp_cast(hero_state: Dictionary) -> void:
	_cast_stamp_counter += 1
	hero_state["cast_stamp"] = _cast_stamp_counter


func _clear_cast_stamp(hero_state: Dictionary) -> void:
	hero_state["cast_stamp"] = 0


func _hero_cast_stamp(hero_state: Dictionary) -> int:
	return int(hero_state.get("cast_stamp", 0))


# Display rank (1-based) of a stamped hero among living stamped heroes — what
# the card badge shows. 0 = unstamped (no badge).
func hero_cast_rank(hero_id: String) -> int:
	var stamps: Array = []
	var own_stamp: int = 0
	for state_variant in combat_manager.get_hero_states():
		var state: Dictionary = state_variant
		if bool(state.get("dead", false)):
			continue
		var stamp: int = int(state.get("cast_stamp", 0))
		if stamp <= 0:
			continue
		stamps.append(stamp)
		if str(state["id"]) == hero_id:
			own_stamp = stamp
	if own_stamp <= 0:
		return 0
	var rank: int = 1
	for stamp_variant in stamps:
		if int(stamp_variant) < own_stamp:
			rank += 1
	return rank


func _get_target_text(state: Dictionary) -> String:
	return str(state.get("target_display", "--"))


func _is_card_clickable(state: Dictionary, accent_color: Color) -> bool:
	if battle_over:
		return false

	# Reroll/Set pick phases: only living hero cards that have rolled. A frozen
	# die can't be rerolled (the crust is physical) or copied onto; a repeating
	# die can't be Set either — its crusted face IS the result.
	if turn_phase == PHASE_REROLL_PICK or turn_phase == PHASE_TWIN_TARGET_PICK:
		return accent_color == HERO_ACCENT and not bool(state["dead"]) \
			and _has_roll_for_state(hero_rolls, state) and int(state.get("die_freeze_turns", 0)) <= 0
	if turn_phase == PHASE_SET_PICK:
		return accent_color == HERO_ACCENT and not bool(state["dead"]) \
			and _has_roll_for_state(hero_rolls, state) and not bool(state.get("die_freeze_repeat_this_round", false))
	if turn_phase == PHASE_TWIN_SOURCE_PICK:
		return accent_color == HERO_ACCENT and not bool(state["dead"]) and _has_roll_for_state(hero_rolls, state)
	if turn_phase == PHASE_NUDGE_PICK:
		return accent_color == HERO_ACCENT and _protocol.can_nudge_hero(state)

	# Item pick phases
	if turn_phase == PHASE_ITEM_PICK_ALLY:
		return accent_color == HERO_ACCENT and not bool(state["dead"])
	if turn_phase == PHASE_ITEM_PICK_DEAD:
		return accent_color == HERO_ACCENT and bool(state["dead"])
	if turn_phase == PHASE_ITEM_PICK_ENEMY:
		return accent_color == ENEMY_ACCENT and not bool(state["dead"])
	if turn_phase == PHASE_ITEM_PICK_ANY:
		return not bool(state["dead"])

	if turn_phase != PHASE_TARGETING and turn_phase != PHASE_READY_TO_END:
		return false

	var state_id: String = str(state["id"])
	if turn_phase == PHASE_READY_TO_END:
		return accent_color == HERO_ACCENT and _can_unassign_hero(state_id)

	if active_targeting_hero_id == "":
		if accent_color != HERO_ACCENT:
			return false
		return pending_manual_target_ids.has(state_id) or _can_unassign_hero(state_id)

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


func _on_enemy_card_pressed(target_id: String) -> void:
	if battle_over:
		return
	if _protocol.handle_enemy_card_pressed(target_id):
		return
	# An enemy card is never a valid target for a roll-modifier pick — tapping one
	# cancels the armed pick and passes through (§1).
	if _protocol.in_roll_modifier_pick():
		_protocol.cancel_roll_modifier_pick()
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

	# Protocol-spend pick sub-phases (reroll/nudge/set/twin/item) live in the
	# ProtocolActions module; it reports whether it consumed the tap.
	if _protocol.handle_hero_card_pressed(target_id):
		return

	if turn_phase == PHASE_READY_TO_END:
		if _can_unassign_hero(target_id):
			AudioManager.play_select()
			_unassign_hero_cast(target_id)
		return

	if turn_phase != PHASE_TARGETING:
		return
	if active_targeting_hero_id == "":
		if pending_manual_target_ids.has(target_id):
			AudioManager.play_select()
			_select_targeting_hero(target_id)
		elif _can_unassign_hero(target_id):
			AudioManager.play_select()
			_unassign_hero_cast(target_id)
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
	if battle_log_label == null:
		return
	if battle_log_label.text == "":
		battle_log_label.text = message
	else:
		battle_log_label.text = "%s\n%s" % [message, battle_log_label.text]
	_emit_tutorial("log", {"message": message})


func _set_battle_log_visible(is_visible: bool) -> void:
	battle_log_panel.visible = is_visible


func _apply_battle_theme() -> void:
	# The header bar (FACILITY label + buttons) and its divider now live in the
	# PersistentHeader autoload, not this scene. Only the footer divider stays here.
	_ensure_zone_divider("FooterDivider", true)
	PixelUI.style_panel(hero_panel, Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	PixelUI.style_panel(enemy_panel, Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	PixelUI.style_panel(center_panel, Color.TRANSPARENT, Color.TRANSPARENT, 0, 0)
	# Battle log is a grouping surface: filled plate, no stroked outline
	# (INVARIANTS #7 — the old LINE_DIM border was border noise).
	PixelUI.style_panel(battle_log_panel, PixelUI.DT_PLATE_TRANSLUCENT, Color.TRANSPARENT, 0, 0)
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
	_style_frame_icon_action_button(protocol_spend_button, PixelUI.ICON_SWAP, BOTTOM_BAR_BUTTON_SIZE)
	_protocol.restyle_buttons()
	_ensure_protocol_footer_layout()
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

# While choosing an item target (or confirming a no-target item), a press that no unit
# handled (empty space) cancels back to the loadout.
func _unhandled_input(event: InputEvent) -> void:
	if _protocol.handle_unhandled_input(event):
		return


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
