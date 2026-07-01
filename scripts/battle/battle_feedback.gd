class_name BattleFeedback
extends Node

var _scene: Control
var _death_sfx_played_ids: Dictionary = {}


func setup(scene: Control) -> void:
	_scene = scene


# ── Public API ────────────────────────────────────────────────────────────────

func play_round_feedback(events: Array) -> void:
	reset_death_sfx_tracking()
	var action_groups: Array = _build_action_feedback_groups(events)
	for group_variant in action_groups:
		var group: Dictionary = group_variant
		await _play_action_feedback_group(group)


func play_death_sfx_for_event(event: Dictionary) -> void:
	_try_play_death_sfx(event)


func reset_death_sfx_tracking() -> void:
	_death_sfx_played_ids.clear()


func apply_live_event_visual_state(event: Dictionary) -> void:
	if _scene.dice_tray_3d == null:
		return
	if str(event.get("type", "")) == "freeze":
		_scene.dice_tray_3d.set_die_frozen_visual(str(event.get("side", "")), str(event.get("target_id", "")), true)


# ── Sequencer ─────────────────────────────────────────────────────────────────

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
	var is_overload: bool = str(action.get("zone", "")) == "overload"
	var is_tick: bool = str(action.get("zone", "")) == "tick"
	var actor_card: Control = null
	if not action.is_empty():
		actor_card = _find_card_by_state_id(str(action.get("side", "")), str(action.get("actor_id", "")))
	if actor_card != null:
		if actor_card.has_method("play_action_feedback"):
			actor_card.call("play_action_feedback", action_kind if not is_tick else "neutral")
		if action_kind == "attack" and not is_tick:
			_lunge(actor_card, str(action.get("side", "")))
	# Tier 2: the overload signature — gold screen wash + screen shake framing the
	# whole beat, with a longer impact freeze below. Fires on any EFFECTIVE 20
	# (rolled natural OR nudged/buffed into the overload zone) — intentional.
	if is_overload:
		_celebrate_overload()

	if not _group_has_fatal_hit(effects):
		await get_tree().create_timer(_scene.ACTION_EFFECT_LEAD_TIME).timeout

	var peak_damage: int = 0
	var had_fatal_hit: bool = false
	for event_variant in effects:
		var event: Dictionary = event_variant
		var event_type: String = str(event.get("type", ""))
		if _is_fatal_hit_event(event):
			_try_play_death_sfx(event)
			had_fatal_hit = true
		# Die-tray hooks and SFX are not tied to card lookup (freeze targets a die, not always a card flash).
		apply_live_event_visual_state(event)
		_play_event_sfx(event_type, event)
		var target_card: Control = _find_card_for_event(event)
		if target_card == null:
			continue
		if target_card.has_method("play_impact_feedback"):
			target_card.call("play_impact_feedback", _get_impact_feedback_kind(event_type))
		# Refresh the card to its steady state FIRST, then start the flash tween
		# from there — otherwise configure() resets modulate to white and erases
		# the flash before it can be seen.
		_scene._card_view.refresh_card_for_event(event)
		_flash_card(target_card, event_type)
		_spawn_floating_text(target_card, event_type, int(event.get("amount", 0)))
		if event_type == "damage":
			var amount: int = int(event.get("amount", 0))
			peak_damage = maxi(peak_damage, amount)
			# Tier 2: struck unit recoils — jitter scales with the hit.
			_shake(target_card, clampf(2.0 + float(amount) * 0.16, 2.0, 11.0), 0.22)

	# Tier 1: impact freeze — skip after a kill so death reads immediately, not after pause.
	if is_overload:
		await _hit_pause(peak_damage, 0.06)
	elif peak_damage > 0 and not had_fatal_hit:
		await _hit_pause(peak_damage)

	if not had_fatal_hit:
		await get_tree().create_timer(_scene.ACTION_FEEDBACK_PAUSE).timeout


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


# Maps a combat event to its SFX. Death is handled separately at the fatal hit moment.
func _play_event_sfx(event_type: String, _event: Dictionary) -> void:
	match event_type:
		"damage":
			AudioManager.play_sfx("damage")
		"poison":
			AudioManager.play_sfx("poison")
		"heal":
			AudioManager.play_sfx("heal")
		"shield":
			AudioManager.play_sfx("shield")
		"freeze":
			AudioManager.play_sfx("freeze")
		"phase2":
			AudioManager.play_sfx("phase2")


func _is_fatal_hit_event(event: Dictionary) -> bool:
	var event_type: String = str(event.get("type", ""))
	if event_type != "damage" and event_type != "poison":
		return false
	return int(event.get("hp_after", 1)) <= 0


func _group_has_fatal_hit(effects: Array) -> bool:
	for event_variant in effects:
		if _is_fatal_hit_event(event_variant):
			return true
	return false


func _try_play_death_sfx(event: Dictionary) -> void:
	if not _is_fatal_hit_event(event):
		return
	var target_id: String = str(event.get("target_id", ""))
	if target_id != "" and _death_sfx_played_ids.has(target_id):
		return
	if target_id != "":
		_death_sfx_played_ids[target_id] = true
	AudioManager.play_sfx("death")


func _get_impact_feedback_kind(event_type: String) -> String:
	match event_type:
		"shield", "block", "roll_buff", "freeze":
			return "shield"
		"heal", "cloak":
			return "heal"
		_:
			return "damage"


# ── Card lookup ───────────────────────────────────────────────────────────────

func _find_card_for_event(event: Dictionary) -> Control:
	var side: String = str(event.get("side", ""))
	var target_id: String = str(event.get("target_id", ""))
	if target_id != "":
		return _find_card_by_state_id(side, target_id)
	var target_name: String = str(event.get("target_name", ""))
	var views: Array = _scene.hero_card_views if side == "hero" else _scene.enemy_card_views
	for view_variant in views:
		var view: Dictionary = view_variant
		var state: Dictionary = view["state"]
		var unit: Resource = state["unit"]
		if unit != null and str(unit.display_name) == target_name:
			return view["card"] as Control
	return null


func _find_card_by_state_id(side: String, state_id: String) -> Control:
	var views: Array = _scene.hero_card_views if side == "hero" else _scene.enemy_card_views
	for view_variant in views:
		var view: Dictionary = view_variant
		var state: Dictionary = view["state"]
		if str(state.get("id", "")) == state_id:
			return view["card"] as Control
	return null


# ── Visual primitives ─────────────────────────────────────────────────────────

func _flash_card(card: Control, event_type: String) -> void:
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
	tween.tween_property(card, "modulate", base_modulate, 0.22).from(flash_color)


func _spawn_floating_text(card: Control, event_type: String, amount: int) -> void:
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
	_scene.float_layer.add_child(label)
	label.move_to_front()

	# punch_number: scale in from small with an overshoot, then settle, so the
	# number "pops" on arrival. Bigger hits punch larger. Scale is centered on the
	# label so it grows from its middle.
	var mult: float = _float_size_mult(event_type, amount)
	label.pivot_offset = label.get_minimum_size() * 0.5
	label.scale = Vector2(0.5, 0.5)
	var punch: Tween = create_tween()
	punch.tween_property(label, "scale", Vector2.ONE * (mult * 1.25), 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(label, "scale", Vector2.ONE * mult, 0.13) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Rise + fade over the lifetime, then free.
	var tween: Tween = create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -52), 0.9)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tween.tween_callback(label.queue_free)


# Floating-number punch scale: damage scales up with the hit (heavy hits read
# bigger), everything else stays at its base size.
func _float_size_mult(event_type: String, amount: int) -> float:
	if event_type == "damage" or event_type == "poison":
		return clampf(0.95 + float(amount) * 0.012, 0.95, 1.55)
	return 1.0


func _get_card_float_origin(card: Control) -> Vector2:
	var card_rect: Rect2 = card.get_global_rect()
	var layer_origin: Vector2 = _scene.float_layer.get_global_position()
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


# ── Tier 1 primitives ─────────────────────────────────────────────────────────

# Brief impact freeze (the genre "hit pause"). Bigger hits hold a touch longer so
# heavy damage reads with more weight. Engine.time_scale = 0 freezes the whole
# scene; we restore via an ignore_time_scale timer so the scaled feedback timers
# downstream keep ticking. Guard against re-entrancy so overlapping hits can't
# strand time_scale at 0.
const HIT_PAUSE_MIN := 0.04
const HIT_PAUSE_MAX := 0.09
var _hit_pause_active: bool = false

func _hit_pause(amount: int, extra: float = 0.0) -> void:
	if _hit_pause_active:
		return
	if not is_inside_tree() or get_tree() == null:
		return
	_hit_pause_active = true
	var dur: float = clampf(HIT_PAUSE_MIN + float(amount) * 0.0018, HIT_PAUSE_MIN, HIT_PAUSE_MAX) + extra
	Engine.time_scale = 0.0
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_pause_active = false


# The overload signature: a brief, subtle gold screen wash (commit color) plus a
# board-wide shake, framing the payoff beat. Flat, no glow — just a flash. Fires
# on any effective-20 ability, natural or nudged into the overload zone.
func _celebrate_overload() -> void:
	AudioManager.play_sfx("overload")
	if _scene.float_layer != null and is_instance_valid(_scene.float_layer):
		var wash: ColorRect = ColorRect.new()
		wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wash.color = Color(1.0, 0.82, 0.20, 0.0)
		wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		wash.z_as_relative = false
		wash.z_index = 200
		_scene.float_layer.add_child(wash)
		var tween: Tween = create_tween()
		tween.tween_property(wash, "color:a", 0.16, 0.05)
		tween.tween_property(wash, "color:a", 0.0, 0.26)
		tween.tween_callback(wash.queue_free)
	if _scene.board != null and is_instance_valid(_scene.board):
		_shake(_scene.board, 9.0, 0.34)


# Attacker step-in + recoil. Direction is decided by side (heroes on the bottom
# rail lunge up toward the enemy rail; enemies lunge down). The card is a
# container child, so we tween position transiently and return to base — the beat
# is layout-quiet, so the container doesn't fight it. Fire-and-forget tween.
const LUNGE_DIST := 26.0
const LUNGE_OUT := 0.08
const LUNGE_BACK := 0.16

func _lunge(card: Control, side: String) -> void:
	if card == null or not is_instance_valid(card):
		return
	var dir_y: float = -1.0 if side == "hero" else 1.0
	var base: Vector2 = card.position
	var tween: Tween = create_tween()
	tween.tween_property(card, "position", base + Vector2(0.0, dir_y * LUNGE_DIST), LUNGE_OUT) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position", base, LUNGE_BACK) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Decaying positional jitter — a struck unit's recoil. Steps to shrinking random
# offsets and lands back on base. Transient (the beat is layout-quiet), so the
# container doesn't fight the tween.
const SHAKE_STEPS := 7

func _shake(node: Control, amplitude: float, duration: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	var base: Vector2 = node.position
	var step_time: float = duration / float(SHAKE_STEPS + 1)
	var tween: Tween = create_tween()
	for i in range(SHAKE_STEPS):
		var decay: float = 1.0 - float(i) / float(SHAKE_STEPS)
		var off := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * amplitude * decay
		tween.tween_property(node, "position", base + off, step_time) \
			.set_trans(Tween.TRANS_SINE)
	tween.tween_property(node, "position", base, step_time).set_trans(Tween.TRANS_SINE)


# ── 2D dice widgets ───────────────────────────────────────────────────────────


