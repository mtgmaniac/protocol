class_name BattleFeedback
extends Node

var _scene: Control


func setup(scene: Control) -> void:
	_scene = scene


# ── Public API ────────────────────────────────────────────────────────────────

func play_round_feedback(events: Array) -> void:
	var action_groups: Array = _build_action_feedback_groups(events)
	for group_variant in action_groups:
		var group: Dictionary = group_variant
		await _play_action_feedback_group(group)


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
	var actor_card: Control = null
	if not action.is_empty():
		actor_card = _find_card_by_state_id(str(action.get("side", "")), str(action.get("actor_id", "")))
	if actor_card != null:
		if actor_card.has_method("play_action_feedback"):
			actor_card.call("play_action_feedback", action_kind)
		# Tier 1: attacker leans toward the enemy rail and recoils — the wind-up tell.
		# Heroes sit on the bottom rail (lunge up), enemies on top (lunge down).
		if action_kind == "attack":
			_lunge(actor_card, str(action.get("side", "")))

	await get_tree().create_timer(_scene.ACTION_EFFECT_LEAD_TIME).timeout

	var peak_damage: int = 0
	for event_variant in effects:
		var event: Dictionary = event_variant
		var event_type: String = str(event.get("type", ""))
		var target_card: Control = _find_card_for_event(event)
		if target_card == null:
			continue
		if target_card.has_method("play_impact_feedback"):
			target_card.call("play_impact_feedback", _get_impact_feedback_kind(event_type))
		apply_live_event_visual_state(event)
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

	# Tier 1: ONE impact freeze for the whole beat, scaled by the biggest hit, so a
	# blastAll volley lands as a single weighty pause rather than a stutter.
	if peak_damage > 0:
		await _hit_pause(peak_damage)

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

func _hit_pause(amount: int) -> void:
	if _hit_pause_active:
		return
	if not is_inside_tree() or get_tree() == null:
		return
	_hit_pause_active = true
	var dur: float = clampf(HIT_PAUSE_MIN + float(amount) * 0.0018, HIT_PAUSE_MIN, HIT_PAUSE_MAX)
	Engine.time_scale = 0.0
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_pause_active = false


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
