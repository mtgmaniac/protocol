# ProtocolActions — the protocol-spend subsystem, extracted from battle_scene
# per docs/ARCHITECTURE_REVIEW_JUL2026.md §1 recommendation 1 (behavior-
# preserving; every function body moved verbatim with scene state reached via
# `_scene.`). Owns the footer spend buttons (Reroll wiring, Nudge, Set, Twin
# Fates, Item), their costs and legality, and the pick-a-die sub-phases
# (reroll/nudge/set/twin picks, the item targeting overlay + Set-value popup).
#
# NARROW INTERFACE (everything battle_scene and the spotlight/primer target
# resolvers are allowed to touch):
#   setup(scene)                    — bind once from battle_scene._ready
#   build_footer_buttons()          — reroll wiring + nudge/set/twin/item buttons
#   handle_hero_card_pressed(id) -> bool   — true if a pick sub-phase consumed the tap
#   handle_enemy_card_pressed(id) -> bool  — true if the item flow consumed the tap
#   handle_unhandled_input(event) -> bool  — item overlay off-card cancel
#   on_phase_changed(next_phase)    — Set-popup teardown on any transition
#   reset_battle_over_state()       — clears pending item/pick state
#   restyle_buttons()               — theme refresh hook
#   update_item_panel() / in_item_phase() / can_use_item_in_current_phase()
#   can_nudge_hero(state) / nudge_button / set_button / twin_fates_button / item_button
# Everything else in this file is internal plumbing for those entry points.
class_name ProtocolActions
extends Node

var _scene: Node = null


func setup(scene: Node) -> void:
	_scene = scene


func build_footer_buttons() -> void:
	_scene.protocol_spend_button.pressed.connect(_on_reroll_button_pressed)
	_attach_protocol_inspect(_scene.protocol_spend_button, "reroll")
	_add_nudge_button()
	_add_set_button()
	if _scene._game_state().has_relic_effect("twinFates"):
		_add_twin_fates_button()
	_build_item_panel()
	# Cost badges (UI review S-4, restyled per Kev 2026-07-10): a bare PP number
	# in the button's bottom-right corner — no plate. The item button carries no
	# number (its cost varies per item; the loadout shows it). Twin Fates is free
	# so it carries none. Set's cost can change mid-battle (Root Access) and
	# refreshes in refresh_action_affordability.
	_attach_cost_badge(nudge_button, "1")
	_attach_cost_badge(_scene.protocol_spend_button, "2")
	_attach_cost_badge(set_button, str(_get_set_cost()))
	refresh_action_affordability()


# ── Public entry points (delegated from battle_scene) ─────────────────────────

func on_phase_changed(next_phase: int) -> void:
	if next_phase != _scene.PHASE_SET_PICK:
		_close_set_value_popup()


func reset_battle_over_state() -> void:
	_pending_item = null
	_was_in_ready_phase = false
	_phase_before_item = -1


func restyle_buttons() -> void:
	if nudge_button != null and is_instance_valid(nudge_button):
		_scene._style_frame_icon_action_button(nudge_button, PixelUI.ICON_INCREASE, _scene.BOTTOM_BAR_BUTTON_SIZE)
	if set_button != null and is_instance_valid(set_button):
		_scene._style_frame_icon_action_button(set_button, PixelUI.ICON_SET, _scene.BOTTOM_BAR_BUTTON_SIZE)
	if item_button != null and is_instance_valid(item_button):
		_scene._style_frame_icon_action_button(item_button, PixelUI.ICON_ITEM, _scene.BOTTOM_BAR_BUTTON_SIZE)


# ── Cost badges + affordability dim (UI review S-4) ────────────────────────────
# Each spend button carries its PP price as a small amber corner plate, and the
# whole button dims while the pool can't cover it. Called from
# battle_scene._update_protocol_bar so it tracks every pool change.

const _UNAFFORDABLE_DIM := Color(1.0, 1.0, 1.0, 0.45)
var _cost_badges: Dictionary = {}   # Button -> Label


func _attach_cost_badge(button: Button, text: String) -> void:
	if button == null or not is_instance_valid(button):
		return
	var badge := Label.new()
	badge.name = "CostBadge"
	badge.text = text
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	PixelUI.apply_pixel_font(badge)
	badge.add_theme_font_size_override("font_size", 48)
	badge.add_theme_color_override("font_color", PixelUI.DT_AMBER)
	# Bare number, no plate (Kev 2026-07-10) — a dark glyph outline separates it
	# from the button art instead of a box.
	badge.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	badge.add_theme_constant_override("outline_size", 5)
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_left = -66.0
	badge.offset_top = -66.0
	badge.offset_right = -6.0
	badge.offset_bottom = -2.0
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	button.add_child(badge)
	_cost_badges[button] = badge


func _set_badge_text(button: Button, text: String) -> void:
	var badge: Label = _cost_badges.get(button)
	if badge != null and is_instance_valid(badge):
		badge.text = text


func _set_action_affordable(button: Button, affordable: bool) -> void:
	if button != null and is_instance_valid(button):
		button.modulate = Color.WHITE if affordable else _UNAFFORDABLE_DIM


func refresh_action_affordability() -> void:
	var pp: int = _scene.protocol_points
	# Nudge is 1 PP unless a Priming Charge free nudge is still banked.
	_set_action_affordable(nudge_button, pp >= 1 or _has_free_nudge_available())
	_set_action_affordable(_scene.protocol_spend_button, pp >= 2)
	if set_button != null and is_instance_valid(set_button):
		var set_cost: int = _get_set_cost()
		_set_badge_text(set_button, str(set_cost))
		_set_action_affordable(set_button, pp >= set_cost)
	if item_button != null and is_instance_valid(item_button):
		# No cost badge on the item button (cost varies per item — the loadout
		# menu shows each price); the affordability dim still tracks the pool.
		_set_action_affordable(item_button, pp >= _get_item_protocol_cost(null))


func can_nudge_hero(state: Dictionary) -> bool:
	return _can_nudge_hero(state)


func in_item_phase() -> bool:
	return _in_item_phase()


func can_use_item_in_current_phase() -> bool:
	return _can_use_item_in_current_phase()


func update_item_panel() -> void:
	_update_item_panel()


# Pick sub-phase routing: returns true when this module consumed the tap.
func handle_hero_card_pressed(target_id: String) -> bool:
	if _scene.turn_phase == _scene.PHASE_REROLL_PICK:
		var reroll_state: Dictionary = _scene._find_state_by_id(_scene.combat_manager.get_hero_states(), target_id)
		if reroll_state.is_empty() or bool(reroll_state["dead"]) or not _scene._has_roll_for_state(_scene.hero_rolls, reroll_state):
			return true
		if int(reroll_state.get("die_freeze_turns", 0)) > 0:
			_scene._refresh_summary("That die is frozen solid - it can't be rerolled.")
			return true
		AudioManager.play_select()
		_apply_reroll(target_id)
		return true
	if _scene.turn_phase == _scene.PHASE_NUDGE_PICK:
		var nudge_state: Dictionary = _scene._find_state_by_id(_scene.combat_manager.get_hero_states(), target_id)
		if not _can_nudge_hero(nudge_state):
			return true
		AudioManager.play_select()
		_apply_nudge(target_id)
		return true
	if _scene.turn_phase == _scene.PHASE_SET_PICK:
		var set_state: Dictionary = _scene._find_state_by_id(_scene.combat_manager.get_hero_states(), target_id)
		if set_state.is_empty() or bool(set_state["dead"]) or not _scene._has_roll_for_state(_scene.hero_rolls, set_state):
			return true
		if int(set_state.get("die_freeze_turns", 0)) > 0:
			_scene._refresh_summary("That die is frozen solid - it can't be Set.")
			return true
		AudioManager.play_select()
		_begin_set_value_pick(target_id)
		return true
	if _scene.turn_phase == _scene.PHASE_TWIN_SOURCE_PICK or _scene.turn_phase == _scene.PHASE_TWIN_TARGET_PICK:
		var twin_state: Dictionary = _scene._find_state_by_id(_scene.combat_manager.get_hero_states(), target_id)
		if twin_state.is_empty() or bool(twin_state["dead"]) or not _scene._has_roll_for_state(_scene.hero_rolls, twin_state):
			return true
		if _scene.turn_phase == _scene.PHASE_TWIN_TARGET_PICK and int(twin_state.get("die_freeze_turns", 0)) > 0:
			_scene._refresh_summary("That die is frozen solid - it can't be overwritten.")
			return true
		AudioManager.play_select()
		if _scene.turn_phase == _scene.PHASE_TWIN_SOURCE_PICK:
			_scene._twin_fates_source_id = target_id
			_scene.transition(_scene.PHASE_TWIN_TARGET_PICK)
			_scene._refresh_summary("Twin Fates: tap the die to copy TO.")
		elif target_id != _scene._twin_fates_source_id:
			_apply_twin_fates(_scene._twin_fates_source_id, target_id)
		return true
	if _in_item_phase():
		if (_scene.turn_phase == _scene.PHASE_ITEM_PICK_ALLY or _scene.turn_phase == _scene.PHASE_ITEM_PICK_ANY or _scene.turn_phase == _scene.PHASE_ITEM_PICK_DEAD) and _scene.legal_target_ids.has(target_id) and _pending_item != null:
			var target_state: Dictionary = _scene._find_state_by_id(_scene.combat_manager.get_hero_states(), target_id)
			if not target_state.is_empty():
				AudioManager.play_select()
				_apply_item_effect(_pending_item, target_state)
				return true
		_cancel_item_to_loadout()
		return true
	return false


func handle_enemy_card_pressed(target_id: String) -> bool:
	if not _in_item_phase():
		return false
	if (_scene.turn_phase == _scene.PHASE_ITEM_PICK_ENEMY or _scene.turn_phase == _scene.PHASE_ITEM_PICK_ANY) and _scene.legal_target_ids.has(target_id) and _pending_item != null:
		var target_state: Dictionary = _scene._find_state_by_id(_scene.combat_manager.get_enemy_states(), target_id)
		if not target_state.is_empty():
			AudioManager.play_select()
			_apply_item_effect(_pending_item, target_state)
			return true
	_cancel_item_to_loadout()
	return true


# Off-card tap while the item overlay is up cancels back to the loadout; an
# off-target tap (empty space) while a roll-modifier pick is armed cancels that
# pick — the ARMED state's exit edge for taps that hit no unit (§1).
func handle_unhandled_input(event: InputEvent) -> bool:
	if not _in_item_phase() and not in_roll_modifier_pick():
		return false
	var pressed := false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		pressed = mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if not pressed:
		return false
	get_viewport().set_input_as_handled()
	if _in_item_phase():
		_cancel_item_to_loadout()
	else:
		cancel_roll_modifier_pick()
	return true


# True while a roll-modifier pick (reroll/nudge/set/twin) is armed but not yet
# committed — the state §1 must always be escapable from.
func in_roll_modifier_pick() -> bool:
	var p: int = _scene.turn_phase
	return p == _scene.PHASE_REROLL_PICK or p == _scene.PHASE_NUDGE_PICK \
		or p == _scene.PHASE_SET_PICK or p == _scene.PHASE_TWIN_SOURCE_PICK \
		or p == _scene.PHASE_TWIN_TARGET_PICK


# The exit edge from ARMED (§1): drop all pending pick state and return to the
# resting phase (READY_TO_END / TARGETING) via _finish_roll_modifier_pick, which
# commits nothing and spends NO Protocol. Arming never deducts Protocol (reroll/
# nudge/set/twin only pay inside their _apply_*), so a cancel is always free.
func cancel_roll_modifier_pick() -> void:
	_close_set_value_popup()
	_pending_set_hero_id = ""
	_scene._twin_fates_source_id = ""
	_scene._finish_roll_modifier_pick()


# A Protocol button pressed while another action is armed cancels the armed one
# first (§1). Returns true when the press should stop here — the SAME action was
# re-pressed, so it toggles off with nothing armed. A DIFFERENT action returns
# false and falls through to arm normally now that the resting phase is restored.
func _cancel_armed_for_button(this_phase_a: int, this_phase_b: int = -1) -> bool:
	if not in_roll_modifier_pick():
		return false
	var same: bool = _scene.turn_phase == this_phase_a \
		or (this_phase_b != -1 and _scene.turn_phase == this_phase_b)
	cancel_roll_modifier_pick()
	return same


# ── Moved verbatim from battle_scene (scene state via _scene.) ────────────────

var item_button: Button = null


var nudge_button: Button = null


var set_button: Button = null


var _suppress_protocol_press: bool = false


var _pending_set_hero_id: String = ""


# Mobile-friendly "Set a die" value picker (thumb-draggable slider popup, replaces the old
# 1-20 vertical PopupMenu). Built on a high CanvasLayer so it floats above the 3D dice tray.
var _set_value_overlay: CanvasLayer = null


var _set_value_current: int = 1


var _set_value_display: Label = null


var _set_value_track: Control = null


var _set_value_fill: ColorRect = null


var _set_value_thumb: Control = null


var _item_menu: PopupMenu = null


var _item_menu_items: Array = []


var _pending_item: ItemData = null


var _item_targeting_card: Node = null


var _item_targeting_armed: bool = false


var _was_in_ready_phase: bool = false


var _phase_before_item: int = -1


func _on_reroll_button_pressed() -> void:
	if _consume_protocol_long_press():
		return
	if _cancel_armed_for_button(_scene.PHASE_REROLL_PICK):
		return
	if _scene.turn_phase != _scene.PHASE_READY_TO_END and _scene.turn_phase != _scene.PHASE_TARGETING:
		if _scene.hero_rolls.is_empty():
			_scene._refresh_summary("Roll dice before using Reroll.")
		return
	if _scene.protocol_points < 2:
		_scene._refresh_summary("Need 2 Protocol to Reroll.")
		return
	AudioManager.play_select()
	_scene.transition(_scene.PHASE_REROLL_PICK)


func _on_nudge_button_pressed() -> void:
	if _consume_protocol_long_press():
		return
	if _cancel_armed_for_button(_scene.PHASE_NUDGE_PICK):
		return
	if _scene.turn_phase != _scene.PHASE_READY_TO_END and _scene.turn_phase != _scene.PHASE_TARGETING:
		if _scene.hero_rolls.is_empty():
			_scene._refresh_summary("Roll dice before using Nudge.")
		return
	if _scene.protocol_points < 1 and not _has_free_nudge_available():
		_scene._refresh_summary("Need 1 Protocol to Nudge.")
		return
	if not _has_nudgeable_hero():
		_scene._refresh_summary("Every die was already nudged this turn.")
		return
	AudioManager.play_select()
	_scene.transition(_scene.PHASE_NUDGE_PICK)


func _add_nudge_button() -> void:
	var btn: Button = Button.new()
	btn.custom_minimum_size = _scene.BOTTOM_BAR_BUTTON_SIZE
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # match the scene reroll button; else it fills the row and clips off the bottom
	btn.pressed.connect(_on_nudge_button_pressed)
	_attach_protocol_inspect(btn, "nudge")
	_scene._style_frame_icon_action_button(btn, PixelUI.ICON_INCREASE, _scene.BOTTOM_BAR_BUTTON_SIZE)
	nudge_button = btn
	_scene.protocol_spend_button.get_parent().add_child(btn)
	# Order: nudge, reroll, set, item — nudge sits just BEFORE the reroll button.
	_scene.protocol_spend_button.get_parent().move_child(btn, _scene.protocol_spend_button.get_index())


func _apply_reroll(hero_id: String) -> void:
	# Rule delegated to BattleEngine (A.1); this scene keeps the animation + UI.
	var new_roll: int = _scene._engine.apply_reroll(_scene._state, hero_id)
	_scene._update_protocol_bar()
	_scene._append_log("Reroll: %s draws %d." % [hero_id, new_roll])
	if _scene.dice_tray_3d != null:
		await _scene.dice_tray_3d.reroll_die_to_result("hero", hero_id, new_roll)
	_scene._re_assign_hero_target(hero_id)
	_scene._refresh_dice_result_actions()
	_scene._finish_roll_modifier_pick()


func _get_nudge_cost(hero_id: String) -> int:
	return _scene._engine.nudge_cost(_scene._state, hero_id, _scene._hero_has_gear_effect(hero_id, "firstNudgeFree"))


func _apply_nudge(hero_id: String) -> void:
	# Rule delegated to BattleEngine (A.1); this scene keeps the dice-tray
	# update, retargeting, logs, and tutorial emit.
	# DESIGN-TODO(kev): confirm the Reverse Gimbal flip interaction (tap again to
	# swap +3 <-> -3) as the "may subtract" UX.
	var res: Dictionary = _scene._engine.apply_nudge(
		_scene._state,
		hero_id,
		_scene._hero_has_gear_effect(hero_id, "firstNudgeFree"),
		_scene._hero_has_gear_effect(hero_id, "nudgeMaySubtract")
	)
	match str(res["kind"]):
		"flip":
			_scene._append_log("Reverse Gimbal: nudge flipped to %+d." % int(res["value"]))
		"already":
			_scene._refresh_summary("That die was already nudged this turn.")
			return
		"applied":
			if int(res["cost"]) == 0:
				_scene._append_log("Priming Charge: free Nudge.")
			_scene._update_protocol_bar()
			_scene._append_log("Nudge: %s +3 to effective roll." % hero_id)
	var hero_state: Dictionary = _scene._find_state_by_id(_scene.combat_manager.get_hero_states(), hero_id)
	if _scene.dice_tray_3d != null and not hero_state.is_empty():
		_scene.dice_tray_3d.update_die_result_in_place("hero", hero_id, _scene._get_effective_roll_for_state(hero_state, hero_id))
	_scene._re_assign_hero_target(hero_id)
	_scene._refresh_dice_result_actions()
	_scene._finish_roll_modifier_pick()
	if str(res["kind"]) == "applied":
		_scene._emit_tutorial("nudged", {"hero": hero_id})


func _was_hero_nudged_this_turn(hero_id: String) -> bool:
	return _scene.hero_roll_nudges.has(hero_id)


func _has_free_nudge_available() -> bool:
	for hero_state_variant in _scene.combat_manager.get_hero_states():
		var hero_state: Dictionary = hero_state_variant
		if bool(hero_state.get("dead", false)):
			continue
		if _get_nudge_cost(str(hero_state["id"])) == 0:
			return true
	return false


func _can_nudge_hero(state: Dictionary) -> bool:
	if bool(state.get("dead", false)):
		return false
	if not _scene._has_roll_for_state(_scene.hero_rolls, state):
		return false
	# A frozen die is crusted static and cannot be altered at all — Nudge
	# included (ruling NK-03: full freeze immunity, one clean rule "frozen dice
	# can't be altered", matching Reroll / Set / Twin Fates).
	if int(state.get("die_freeze_turns", 0)) > 0:
		return false
	if _was_hero_nudged_this_turn(str(state["id"])):
		# Reverse Gimbal holders may re-tap to flip the nudge's sign.
		return _scene._hero_has_gear_effect(str(state["id"]), "nudgeMaySubtract")
	return true


func _has_nudgeable_hero() -> bool:
	for hero_state_variant in _scene.combat_manager.get_hero_states():
		if _can_nudge_hero(hero_state_variant):
			return true
	return false


# Root Access boss relic: once per battle, Set costs 0.
func _get_set_cost() -> int:
	return _scene._engine.set_cost(_scene._state)


func _on_set_button_pressed() -> void:
	if _cancel_armed_for_button(_scene.PHASE_SET_PICK):
		return
	if _scene.turn_phase != _scene.PHASE_READY_TO_END and _scene.turn_phase != _scene.PHASE_TARGETING:
		if _scene.hero_rolls.is_empty():
			_scene._refresh_summary("Roll dice before using Set.")
		return
	if _scene.protocol_points < _get_set_cost():
		_scene._refresh_summary("Need %d Protocol to Set." % _scene.SET_DIE_COST)
		return
	AudioManager.play_select()
	_scene.transition(_scene.PHASE_SET_PICK)


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
		InspectPopup.open(_scene, InspectResolver.resolve_protocol_action(action_key), button.get_global_rect(), button.get_instance_id())
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
	btn.custom_minimum_size = _scene.BOTTOM_BAR_BUTTON_SIZE
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_set_button_pressed)
	_attach_protocol_inspect(btn, "set")
	_scene._style_frame_icon_action_button(btn, PixelUI.ICON_SET, _scene.BOTTOM_BAR_BUTTON_SIZE)
	set_button = btn
	_scene.protocol_spend_button.get_parent().add_child(btn)
	# Set sits just AFTER the reroll button (order: nudge, reroll, set, item).
	_scene.protocol_spend_button.get_parent().move_child(btn, _scene.protocol_spend_button.get_index() + 1)


# Twin Fates relic: once per battle, copy one hero die's result to another,
# free. Two-tap flow: pick the source die, then the target die.
var twin_fates_button: Button = null


func _add_twin_fates_button() -> void:
	var btn: Button = Button.new()
	btn.custom_minimum_size = _scene.BOTTOM_BAR_BUTTON_SIZE
	btn.pressed.connect(_on_twin_fates_button_pressed)
	_scene._style_frame_icon_action_button(btn, PixelUI.ICON_DEBUG2, _scene.BOTTOM_BAR_BUTTON_SIZE)
	twin_fates_button = btn
	_scene.protocol_spend_button.get_parent().add_child(btn)
	_scene.protocol_spend_button.get_parent().move_child(btn, set_button.get_index() + 1)


func _on_twin_fates_button_pressed() -> void:
	if _cancel_armed_for_button(_scene.PHASE_TWIN_SOURCE_PICK, _scene.PHASE_TWIN_TARGET_PICK):
		return
	if _scene.turn_phase != _scene.PHASE_READY_TO_END and _scene.turn_phase != _scene.PHASE_TARGETING:
		if _scene.hero_rolls.is_empty():
			_scene._refresh_summary("Roll dice before using Twin Fates.")
		return
	if _scene._twin_fates_used:
		_scene._refresh_summary("Twin Fates was already spent this battle.")
		return
	AudioManager.play_select()
	_scene._twin_fates_source_id = ""
	_scene.transition(_scene.PHASE_TWIN_SOURCE_PICK)
	_scene._refresh_summary("Twin Fates: tap the die to copy FROM.")


# Pure state core of Twin Fates: copy the source die's result onto the target
# die (clearing its pending nudge/set) and burn the once-per-battle use.
func _twin_fates_copy_roll(source_id: String, target_id: String) -> bool:
	return _scene._engine.twin_fates_copy(_scene._state, source_id, target_id)


func _apply_twin_fates(source_id: String, target_id: String) -> void:
	if not _twin_fates_copy_roll(source_id, target_id):
		_scene._finish_roll_modifier_pick()
		return
	_scene._append_log("Twin Fates: %s's die copies %s's %d." % [target_id, source_id, int(_scene.hero_rolls.get(target_id, 0))])
	var target_state: Dictionary = _scene._find_state_by_id(_scene.combat_manager.get_hero_states(), target_id)
	if _scene.dice_tray_3d != null and not target_state.is_empty():
		_scene.dice_tray_3d.update_die_result_in_place("hero", target_id, _scene._get_effective_roll_for_state(target_state, target_id))
	_scene._re_assign_hero_target(target_id)
	_scene._refresh_dice_result_actions()
	_scene._finish_roll_modifier_pick()


# Set-pick: the player tapped a hero die; open the thumb-draggable value popup for it,
# pre-seeded with the die's current effective value.
func _begin_set_value_pick(hero_id: String) -> void:
	_pending_set_hero_id = hero_id
	var hero_state: Dictionary = _scene._find_state_by_id(_scene.combat_manager.get_hero_states(), hero_id)
	var start_val: int = 10
	if not hero_state.is_empty():
		start_val = _scene._get_effective_roll_for_state(hero_state, hero_id)
	_set_value_current = clampi(start_val, 1, 20)
	_open_set_value_popup()


# A themed modal popup matching the other menus (hard pixel panel + DT colors): a big value
# readout above a wide horizontal slider you drag with your thumb (1-20), plus CANCEL/CONFIRM.
func _open_set_value_popup() -> void:
	_close_set_value_popup()
	var accent: Color = _scene.HERO_ACCENT

	_set_value_overlay = CanvasLayer.new()
	_set_value_overlay.layer = 60
	_scene.add_child(_set_value_overlay)

	# Full-rect catcher: a press outside the panel cancels. The panel (STOP) blocks presses
	# on itself from reaching the catcher, so only taps on the dimmed backdrop dismiss.
	var catcher: Control = Control.new()
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventMouseButton and event.pressed):
			_cancel_set_value_popup())
	_set_value_overlay.add_child(catcher)

	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catcher.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catcher.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Component: Modal (muted accent allowed via the accent param).
	panel.add_theme_stylebox_override("panel", PixelUI.component_style(PixelUI.COMPONENT_MODAL, accent))
	var vp: Vector2 = get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2(clampf(vp.x - 40.0, 340.0, 720.0), 0.0)
	center.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	for side_name in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side_name, 34)
	panel.add_child(margin)

	var vb: VBoxContainer = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 30)
	margin.add_child(vb)

	var title: Label = Label.new()
	title.text = "SET DIE VALUE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.style_label(title, 36, PixelUI.INSPECT_TEXT_DIM, 3)
	vb.add_child(title)

	_set_value_display = Label.new()
	_set_value_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	PixelUI.style_label(_set_value_display, 132, accent, 4)
	vb.add_child(_set_value_display)

	# Slider: a plain Control we paint ourselves (track bg + fill + thumb) so it carries the
	# pixel aesthetic and handles touch/drag directly — far friendlier for thumbs than a list.
	_set_value_track = Control.new()
	_set_value_track.custom_minimum_size = Vector2(0.0, 110.0)
	_set_value_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_value_track.mouse_filter = Control.MOUSE_FILTER_STOP
	vb.add_child(_set_value_track)

	var track_bg: Panel = Panel.new()
	track_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track_bg.add_theme_stylebox_override("panel", PixelUI.make_hard_style(PixelUI.DT_FIELD_BG, PixelUI.DT_FIELD_BORDER, 2))
	_set_value_track.add_child(track_bg)

	_set_value_fill = ColorRect.new()
	_set_value_fill.color = Color(accent.r, accent.g, accent.b, 0.30)
	_set_value_fill.position = Vector2.ZERO
	_set_value_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_value_track.add_child(_set_value_fill)

	_set_value_thumb = Panel.new()
	_set_value_thumb.size = Vector2(60.0, 110.0)
	_set_value_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_value_thumb.add_theme_stylebox_override("panel", PixelUI.make_hard_style(accent, accent.lightened(0.35), 4))
	_set_value_track.add_child(_set_value_thumb)

	_set_value_track.gui_input.connect(_on_set_value_track_input)
	_set_value_track.resized.connect(_update_set_value_visuals)

	var hint: Label = Label.new()
	hint.text = "Drag to choose - costs %d Protocol" % _scene.SET_DIE_COST
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Cost disclosure is info-carrying — floor it (UI review S-1).
	PixelUI.style_label(hint, PixelUI.FONT_INFO_MIN, PixelUI.INSPECT_TEXT_MUTED, 2)
	vb.add_child(hint)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(row)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "CANCEL"
	cancel_btn.custom_minimum_size = Vector2(0.0, 100.0)
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelUI.style_button(cancel_btn, PixelUI.DT_BTN_BG, PixelUI.DT_BTN_BORDER, 38)
	cancel_btn.pressed.connect(_cancel_set_value_popup)
	row.add_child(cancel_btn)

	var confirm_btn: Button = Button.new()
	confirm_btn.text = "CONFIRM"
	confirm_btn.custom_minimum_size = Vector2(0.0, 100.0)
	confirm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PixelUI.style_primary_button(confirm_btn, 38, true)
	confirm_btn.pressed.connect(_confirm_set_value_popup)
	row.add_child(confirm_btn)

	call_deferred("_update_set_value_visuals")


# Position the fill + thumb from the current value. Called on value change and whenever the
# track resizes (so it stays correct once layout resolves the real track width).
func _update_set_value_visuals() -> void:
	if _set_value_display != null:
		_set_value_display.text = str(_set_value_current)
	if _set_value_track == null or _set_value_thumb == null or _set_value_fill == null:
		return
	var track_w: float = _set_value_track.size.x
	var track_h: float = _set_value_track.size.y
	var thumb_w: float = _set_value_thumb.size.x
	var frac: float = float(_set_value_current - 1) / 19.0
	var x: float = frac * maxf(0.0, track_w - thumb_w)
	_set_value_thumb.position = Vector2(x, 0.0)
	_set_value_fill.size = Vector2(x + thumb_w * 0.5, track_h)


func _on_set_value_track_input(event: InputEvent) -> void:
	if _set_value_track == null or _set_value_thumb == null:
		return
	var local_x: float = -1.0
	if event is InputEventScreenTouch and event.pressed:
		local_x = event.position.x
	elif event is InputEventScreenDrag:
		local_x = event.position.x
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		local_x = event.position.x
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		local_x = event.position.x
	if local_x < 0.0:
		return
	var usable: float = maxf(1.0, _set_value_track.size.x - _set_value_thumb.size.x)
	var frac: float = clampf((local_x - _set_value_thumb.size.x * 0.5) / usable, 0.0, 1.0)
	var new_val: int = clampi(int(round(1.0 + frac * 19.0)), 1, 20)
	if new_val != _set_value_current:
		_set_value_current = new_val
		AudioManager.play_select()
		_update_set_value_visuals()


func _confirm_set_value_popup() -> void:
	var hero_id: String = _pending_set_hero_id
	var value: int = _set_value_current
	_close_set_value_popup()
	if hero_id == "":
		return
	_pending_set_hero_id = ""
	AudioManager.play_select()
	_apply_set(hero_id, clampi(value, 1, 20))


# Cancel just closes the popup; we stay in _scene.PHASE_SET_PICK so the player can tap a different die
# or back out via the Set button. No Protocol is spent until CONFIRM.
func _cancel_set_value_popup() -> void:
	if _set_value_overlay == null:
		return
	AudioManager.play_select()
	_pending_set_hero_id = ""
	_close_set_value_popup()


func _close_set_value_popup() -> void:
	if _set_value_overlay != null and is_instance_valid(_set_value_overlay):
		_set_value_overlay.queue_free()
	_set_value_overlay = null
	_set_value_display = null
	_set_value_track = null
	_set_value_fill = null
	_set_value_thumb = null


func _apply_set(hero_id: String, value: int) -> void:
	# Rule delegated to BattleEngine (A.1); this scene keeps the logs + UI.
	var set_cost: int = _scene._engine.apply_set(_scene._state, hero_id, value)
	if set_cost == 0:
		_scene._append_log("Root Access: free Set.")
	_scene._update_protocol_bar()
	_scene._append_log("Set: %s die set to %d." % [hero_id, value])
	var hero_state: Dictionary = _scene._find_state_by_id(_scene.combat_manager.get_hero_states(), hero_id)
	if _scene.dice_tray_3d != null and not hero_state.is_empty():
		_scene.dice_tray_3d.update_die_result_in_place("hero", hero_id, _scene._get_effective_roll_for_state(hero_state, hero_id))
	_scene._re_assign_hero_target(hero_id)
	_scene._refresh_dice_result_actions()
	_scene._finish_roll_modifier_pick()


# True while an item is mid-use (choosing a target, or confirming a no-target item).
func _in_item_phase() -> bool:
	return _scene.is_item_pick_phase(_scene.turn_phase) or _scene.turn_phase == _scene.PHASE_ITEM_CONFIRM


func _get_item_protocol_cost(_item: ItemData) -> int:
	# Flat cost 1 for all rarities. Rule delegated to BattleEngine (A.1);
	# Protocol Override / Supply Drone make it 0, Sealed Supplies makes it 2.
	# Protocol Override also grants +1 on use — see _apply_item_effect.
	return _scene._engine.item_protocol_cost(bool(_scene._battle_effects.get("items_free", false)))


func _build_item_panel() -> void:
	var protocol_row: HBoxContainer = _scene.protocol_panel.get_node("ProtocolMargin/ProtocolRow") as HBoxContainer
	item_button = Button.new()
	item_button.custom_minimum_size = _scene.BOTTOM_BAR_BUTTON_SIZE
	item_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item_button.pressed.connect(_on_item_button_pressed_menu)
	_scene._style_frame_icon_action_button(item_button, PixelUI.ICON_ITEM, _scene.BOTTOM_BAR_BUTTON_SIZE)
	protocol_row.add_child(item_button)
	# Item is the last protocol action (order: nudge, reroll, set, item).
	if set_button != null and is_instance_valid(set_button):
		protocol_row.move_child(item_button, set_button.get_index() + 1)
	_item_menu = PopupMenu.new()
	_item_menu.name = "ItemMenu"
	_item_menu.id_pressed.connect(_on_item_menu_id_pressed)
	_scene.float_layer.add_child(_item_menu)
	_update_item_panel()


func _update_item_panel() -> void:
	if item_button == null:
		return
	_item_menu_items.clear()
	var item_ids: Array = _scene._game_state().consumables
	for item_id_variant in item_ids:
		var item: ItemData = _scene._data_manager().get_item(str(item_id_variant)) as ItemData
		if item != null:
			_item_menu_items.append(item)
	# The item button always opens the themed LOADOUT menu (consumables + relic), so it
	# stays enabled even with no consumables — the relic is still viewable.
	item_button.disabled = false


func _on_item_button_pressed_menu() -> void:
	if item_button == null:
		return
	# An armed roll-modifier pick is cancelled first so the item is usable in the
	# restored resting phase (§1: Set → item box cancels Set, then opens the box).
	if in_roll_modifier_pick():
		cancel_roll_modifier_pick()
	AudioManager.play_select()
	var relic_item: ItemData = null
	var relic_ids: Array = _scene._game_state().relics
	if not relic_ids.is_empty():
		relic_item = _scene._data_manager().get_item(str(relic_ids[0])) as ItemData
	LoadoutMenu.open(self, _item_menu_items, relic_item, _on_item_button_pressed, item_button.get_global_rect())


func _on_item_menu_id_pressed(id: int) -> void:
	if id < 0 or id >= _item_menu_items.size():
		return
	AudioManager.play_select()
	var item: ItemData = _item_menu_items[id] as ItemData
	if item == null:
		return
	_on_item_button_pressed(item)


# Returns true if the item tap was accepted (the loadout menu should close), false if it was
# rejected for insufficient Protocol (the menu stays open and flashes the tapped row red).
func _on_item_button_pressed(item: ItemData) -> bool:
	if _scene.battle_over:
		return true
	if not _can_use_item_in_current_phase():
		_scene._refresh_summary("Items can only be used before rolling, during targeting, or before ending the turn.")
		return true
	var cost: int = _get_item_protocol_cost(item)
	if _scene.protocol_points < cost:
		_scene._refresh_summary("Need %d Protocol to use %s." % [cost, item.display_name])
		return false

	_was_in_ready_phase = (_scene.turn_phase == _scene.PHASE_READY_TO_END)
	_phase_before_item = _scene.turn_phase
	_pending_item = item

	match item.target_kind:
		"ally":
			if _scene._get_legal_target_ids("hero").is_empty():
				_cancel_item_targeting("No living ally can use %s." % item.display_name)
				return true
			_scene.transition(_scene.PHASE_ITEM_PICK_ALLY)
		"allyDead":
			# Revive items (Defib Spark) target a DOWNED ally — one manual pick,
			# per INVARIANTS #12. This used to hard-cancel, making the item
			# unusable (audit A-061).
			if _scene._get_dead_hero_ids().is_empty():
				_cancel_item_targeting("No downed ally for %s to revive." % item.display_name)
				return true
			_scene.transition(_scene.PHASE_ITEM_PICK_DEAD)
		"enemy":
			if _scene._get_legal_target_ids("enemy").is_empty():
				_cancel_item_targeting("No living enemy can be targeted by %s." % item.display_name)
				return true
			_scene.transition(_scene.PHASE_ITEM_PICK_ENEMY)
		"any":
			if _scene._get_legal_target_ids("any").is_empty():
				_cancel_item_targeting("No unit can be targeted by %s." % item.display_name)
				return true
			_scene.transition(_scene.PHASE_ITEM_PICK_ANY)
		"none":
			# No target needed — show the card centered and wait for a confirm tap.
			_scene.transition(_scene.PHASE_ITEM_CONFIRM)
		_:
			_cancel_item_targeting("%s cannot find a valid target type." % item.display_name)

	if _scene.is_item_pick_phase(_scene.turn_phase):
		_show_item_targeting_card(item)
	elif _scene.turn_phase == _scene.PHASE_ITEM_CONFIRM:
		_show_item_targeting_card(item, true)
	return true


func _cancel_item_targeting(message: String) -> void:
	_hide_item_targeting_card()
	_pending_item = null
	_scene.legal_target_ids.clear()
	_scene.legal_target_side = ""
	_restore_phase_after_item()
	_scene._refresh_summary(message)


func _can_use_item_in_current_phase() -> bool:
	return _scene.turn_phase == _scene.PHASE_AWAIT_ROLL or _scene.turn_phase == _scene.PHASE_TARGETING or _scene.turn_phase == _scene.PHASE_READY_TO_END


func _restore_phase_after_item() -> void:
	var restore_phase: int = _phase_before_item
	_phase_before_item = -1
	_was_in_ready_phase = false
	if restore_phase == _scene.PHASE_READY_TO_END:
		_scene.transition(_scene.PHASE_READY_TO_END)
	elif restore_phase == _scene.PHASE_TARGETING:
		_scene.transition(_scene.PHASE_TARGETING)
		if _scene.active_targeting_hero_id != "":
			_scene._select_targeting_hero(_scene.active_targeting_hero_id)
	else:
		_scene.transition(_scene.PHASE_AWAIT_ROLL)


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
	_scene.add_child(layer)

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
	# Selection-family target cue (border-only ring); width 8 = even design px
	# (pixel-snap law — the old 7 was already min_stroke'd elsewhere).
	ring.add_theme_stylebox_override("panel", PixelUI.make_hard_style(Color.TRANSPARENT, PixelUI.DT_HERO_DITHER, 8))
	card.add_child(ring)
	# Bound to the card so the loop dies with it; pulses the ring's alpha as the "tap me" cue.
	var tween := card.create_tween().set_loops()
	tween.tween_property(ring, "modulate:a", 0.25, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ring, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _apply_item_effect(item: ItemData, target_state: Dictionary) -> void:
	if item == null:
		return
	_hide_item_targeting_card()
	AudioManager.play_sfx("item")
	var cost: int = _get_item_protocol_cost(item)
	_scene.protocol_points = maxi(_scene.protocol_points - cost, 0)

	var effect: Dictionary = item.effect
	var effect_type: String = str(effect.get("type", ""))

	# Protocol Override: using an item refunds +1 Protocol — but NOT for a
	# protocol-gain item, which (cost 0 + its own grant + a bonus +1) turned into
	# a free Protocol printer past the cap-10 economy (audit A-063). A gainProtocol
	# item still grants its own amount below; it just gets no extra +1 on top.
	if _scene.combat_manager.has_relic("protocolOnItemUse") and effect_type != "gainProtocol":
		_scene._gain_protocol(1)
		_scene._append_log("Protocol Override: +1 Protocol -> %d" % _scene.protocol_points)

	if effect_type == "gainProtocol":
		# Pool op stays here (Overflow Vent + bar + logging live on the scene).
		var protocol_grant: int = int(effect.get("amount", 0))
		_scene._gain_protocol(protocol_grant)
		_scene._append_log("Item: %s grants +%d Protocol -> %d." % [item.display_name, protocol_grant, _scene.protocol_points])
	else:
		# Combat-state mutation is shared with the sim (sim-D).
		var revive_pct: int = _scene._game_state().get_revive_hp_pct(int(effect.get("pct", 50)))
		var log_line: String = _scene._engine.apply_consumable_effect(effect, target_state, _scene._state, revive_pct, item.display_name)
		if log_line != "":
			_scene._append_log(log_line)

	# §2: enemy-reroll items changed enemy_rolls above — push the new value to the
	# 3D die so its numeral matches the refreshed card pips.
	_scene.sync_enemy_dice_after_item_reroll(effect_type, target_state)

	_consume_item(item.id)
	_pending_item = null
	_scene.legal_target_ids.clear()
	_scene.legal_target_side = ""
	_scene._card_view.refresh_all_cards()
	_scene._update_protocol_bar()
	if _scene._try_finish_battle_from_current_state():
		return

	_restore_phase_after_item()


func _consume_item(item_id: String) -> void:
	var consumables: Array = _scene._game_state().consumables
	for i in range(consumables.size()):
		if str(consumables[i]) == item_id:
			consumables.remove_at(i)
			break
	_update_item_panel()
