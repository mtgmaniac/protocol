class_name BattleFeedback
extends Node

var _scene: Control
var _death_sfx_played_ids: Dictionary = {}
# Same-card floats in flight: card instance id -> Array[Label]. New floats on a
# card stack ABOVE the lowest still-alive float so simultaneous numbers never
# overlap (float-text redesign stacking rule).
var _live_floats_by_card: Dictionary = {}


func setup(scene: Control) -> void:
	_scene = scene


# ── Public API ────────────────────────────────────────────────────────────────

func play_round_feedback(events: Array) -> void:
	reset_death_sfx_tracking()
	# Drop stale float-stacking entries (freed labels / last battle's cards) so
	# the registry never grows across a run.
	_live_floats_by_card.clear()
	var action_groups: Array = _build_action_feedback_groups(events)
	for group_variant in action_groups:
		var group: Dictionary = group_variant
		await _play_action_feedback_group(group)
		# Keyword primers pause the sequence at GROUP BOUNDARIES only: any
		# first sighting queued during this group shows now (one per turn),
		# then the sequence resumes on dismiss.
		var primer: Variant = _scene.get("_primer")
		if primer != null and is_instance_valid(primer):
			await primer.flush_at_group_boundary()


func play_death_sfx_for_event(event: Dictionary) -> void:
	_try_play_death_sfx(event)


func reset_death_sfx_tracking() -> void:
	_death_sfx_played_ids.clear()


func apply_live_event_visual_state(event: Dictionary) -> void:
	if _scene.dice_tray_3d == null:
		return
	if str(event.get("type", "")) == "freeze":
		var side: String = str(event.get("side", ""))
		var target_id: String = str(event.get("target_id", ""))
		# Petrify (Accretion) freezes render stone-gray on the die.
		var flavor: String = "ice"
		var states: Array = _scene.combat_manager.get_hero_states() if side == "hero" else _scene.combat_manager.get_enemy_states()
		for state_variant in states:
			if str((state_variant as Dictionary).get("id", "")) == target_id:
				flavor = str((state_variant as Dictionary).get("freeze_flavor", "ice"))
		_scene.dice_tray_3d.set_die_frozen_visual(side, target_id, true, flavor)


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
	# whole beat, with a longer impact freeze below. Fires on any die whose final
	# face is 20 (rolled, Nudged, Set, or buffed into the overload zone) — there
	# is no separate "natural 20" (ruling NK-02).
	if is_overload:
		_celebrate_overload()
		# pkg8.3: the ability name slams across the acting card — scale-punch
		# in, brief hold, out. Flat, palette-driven, no glow.
		_slam_ability_name(actor_card, str(action.get("ability", "")))

	if not _group_has_fatal_hit(effects):
		await get_tree().create_timer(_scene.ACTION_EFFECT_LEAD_TIME).timeout

	var peak_damage: int = 0
	var had_fatal_hit: bool = false
	var had_execute: bool = false
	var any_sfx: bool = is_overload  # the overload stinger already fired
	# Roll-buff floats live at the DIE, not the unit card (Kev's ruling: the buff
	# affects the die — relocating it frees blue-at-a-unit to mean shield only).
	# A squad-wide buff (several roll_buff events on one side in this group)
	# floats ONCE centered over the tray instead of once per die.
	var roll_buff_counts: Dictionary = {}
	for event_variant in effects:
		if str((event_variant as Dictionary).get("type", "")) == "roll_buff":
			var buff_side: String = str((event_variant as Dictionary).get("side", ""))
			roll_buff_counts[buff_side] = int(roll_buff_counts.get(buff_side, 0)) + 1
	var roll_buff_floated_sides: Dictionary = {}
	# Collision rule 3: batch simultaneous deaths, but micro-stagger them a few
	# frames each so a chain that kills two doesn't scatter both on one frame.
	var death_ordinal: int = 0
	for event_variant in effects:
		var event: Dictionary = event_variant
		var event_type: String = str(event.get("type", ""))
		if _is_fatal_hit_event(event):
			_try_play_death_sfx(event)
			had_fatal_hit = true
		# Die-tray hooks and SFX are not tied to card lookup (freeze targets a die, not always a card flash).
		apply_live_event_visual_state(event)
		# Keyword primers observe (queue only — display waits for the group
		# boundary so the beat is never interrupted mid-swing).
		var primer: Variant = _scene.get("_primer")
		if primer != null and is_instance_valid(primer):
			primer.notice_event(event)
		any_sfx = _play_event_sfx(event_type, event) or any_sfx
		if event_type == "roll_buff":
			_spawn_roll_buff_float(event, int(roll_buff_counts.get(str(event.get("side", "")), 0)) >= 2, roll_buff_floated_sides)
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
		_play_keyword_feedback(event_type, event, actor_card, target_card)
		# Death scatter: the card has just refreshed to its dead (grayed) state, so
		# the debris bursting off it reads as "this unit broke apart." Frame-local
		# and fire-and-forget, so it never stalls the turn (the fatal-hit path
		# already skips the lead-in wait and the hit-pause below).
		if _is_fatal_hit_event(event):
			_death_scatter(target_card, str(event.get("side", "")), float(death_ordinal) * 0.05)
			death_ordinal += 1
		if event_type == "execute":
			had_execute = true
		if event_type == "damage":
			var amount: int = int(event.get("amount", 0))
			peak_damage = maxi(peak_damage, amount)
			# Tier 2: struck unit recoils — jitter scales with the hit.
			_shake(target_card, clampf(2.0 + float(amount) * 0.16, 2.0, 11.0), 0.22)

	# Audio floor (Kev 2026-07-10): every ABILITY beat makes a sound. Most carry a
	# damage/heal/shield/freeze/revive/summon event that already does; an ability
	# whose effects are all silent keywords (jam, mark, cloak, taunt, siphon, ...)
	# falls back to the standard damage clip. Round ticks are exempt — a silent
	# tick stays silent — and a fatal hit already carried the death clip.
	if not any_sfx and not had_fatal_hit and not action.is_empty() and not is_tick:
		AudioManager.play_sfx("damage")

	# Tier 1: impact freeze — skip after a kill so death reads immediately, not after pause.
	# Execute (pkg8.4) lands with a heavier pause than a plain hit.
	# The overload (effective-face-20) gets the celebration slow-mo beat instead of a
	# plain freeze — routed through the same arbiter as _hit_pause so the two never
	# stack (collision rule 2). Fires on effective face == 20, no nat/raw check (NK-02).
	if is_overload:
		await _slow_mo()
	elif had_execute and not had_fatal_hit:
		await _hit_pause(maxi(peak_damage, 8), 0.05)
	elif peak_damage > 0 and not had_fatal_hit:
		await _hit_pause(peak_damage)

	if not had_fatal_hit:
		await get_tree().create_timer(_scene.ACTION_FEEDBACK_PAUSE).timeout


func _get_action_feedback_kind(effects: Array) -> String:
	for event_variant in effects:
		var event: Dictionary = event_variant
		var event_type: String = str(event.get("type", ""))
		if event_type == "damage" or event_type == "burn":
			return "attack"
	for event_variant in effects:
		var event: Dictionary = event_variant
		var event_type: String = str(event.get("type", ""))
		if event_type == "shield" or event_type == "heal" or event_type == "cloak" or event_type == "roll_buff" or event_type == "freeze":
			return "support"
	return "neutral"


# Maps a combat event to its SFX; returns whether a sound fired so the group
# player can detect fully-silent abilities. Death is handled separately at the
# fatal hit moment.
func _play_event_sfx(event_type: String, _event: Dictionary) -> bool:
	match event_type:
		"damage":
			AudioManager.play_sfx("damage")
		"burn":
			AudioManager.play_sfx("burn")
		"heal":
			AudioManager.play_sfx("heal")
		"shield":
			AudioManager.play_sfx("shield")
		"freeze":
			AudioManager.play_sfx("freeze")
		"revive":
			AudioManager.play_sfx("revive")
		"summon":
			AudioManager.play_sfx("summon")
		_:
			return false
	return true


func _is_fatal_hit_event(event: Dictionary) -> bool:
	var event_type: String = str(event.get("type", ""))
	if event_type != "damage" and event_type != "burn":
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
		"shield", "block", "roll_buff", "freeze", "accrete":
			return "shield"
		"heal", "cloak", "revive":
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
		"damage", "burn":
			flash_color = Color(1.0, 0.45, 0.45, 1.0)
		"heal", "leech", "revive":
			flash_color = Color(0.45, 1.0, 0.65, 1.0)
		"shield", "block", "roll_buff", "freeze", "accrete":
			flash_color = Color(0.55, 0.82, 1.0, 1.0)
		"wipe_shields":
			flash_color = Color(1.0, 0.80, 0.20, 1.0)
		"execute":
			# pkg8.4: Execute lands with its own deep-red flash (not default white).
			flash_color = Color(1.0, 0.30, 0.30, 1.0)
	card.modulate = flash_color
	tween.tween_property(card, "modulate", base_modulate, 0.22).from(flash_color)


# Floating-number presentation (float-text redesign): big signed numbers, no
# words — the ward-negate ✕ is the single glyph exception (nothing happening IS
# that event). Font is RAW px like the rest of the battle card text (name/HP are
# raw 72, not scale_font_size-scaled): floats sit ABOVE the card's own text so
# the number is the loudest thing on the card while it's alive.
const FLOAT_FONT_SIZE := 96
const FLOAT_OUTLINE_SIZE := 12
const FLOAT_RISE := 72.0
# Kev 2026-07-10: floats read too short-lived at 0.9s — hold longer, live longer.
const FLOAT_LIFETIME := 1.5
# Hold full alpha for a beat, then fade over the remainder — a linear whole-life
# fade left the number half-gone by the time the punch-in settled.
const FLOAT_FADE_HOLD := 0.6
const FLOAT_STACK_GAP := 6.0

func _spawn_floating_text(card: Control, event_type: String, amount: int) -> void:
	var float_text: String = _build_floating_text(event_type, amount)
	if float_text == "":
		return
	var origin: Vector2 = _get_card_float_origin(card)
	var mult: float = _float_size_mult(event_type, amount)
	_spawn_float_label(float_text, _get_floating_color(event_type), origin, mult, card.get_instance_id())


# Roll-buff float at the DIE (relocated from the unit card): the buff changes
# the die's roll, so the number rises off the die surface. Squad-wide buffs
# float once centered over the tray instead of once per die.
func _spawn_roll_buff_float(event: Dictionary, squad_wide: bool, floated_sides: Dictionary) -> void:
	var side: String = str(event.get("side", ""))
	if squad_wide:
		if floated_sides.has(side):
			return
		floated_sides[side] = true
	var tray: Control = _scene.dice_tray_3d
	if tray == null or not is_instance_valid(tray):
		return
	if _scene.float_layer == null or not is_instance_valid(_scene.float_layer):
		return
	var origin_global: Vector2 = Vector2.INF
	if not squad_wide:
		origin_global = tray.get_die_screen_position(side, str(event.get("target_id", "")))
		if origin_global != Vector2.INF:
			# Spawn just above the die so the number never covers the face.
			origin_global.y -= 90.0
	if origin_global == Vector2.INF:
		origin_global = tray.get_global_rect().get_center()
	var origin: Vector2 = origin_global - _scene.float_layer.get_global_position()
	_spawn_float_label("+%d" % int(event.get("amount", 0)), _get_floating_color("roll_buff"), origin, 1.0, 0)


# Shared float-label builder: punch-scale in, rise + fade, free. `origin` is the
# float-layer-space point the label centers on horizontally (its top edge).
# `stack_key` (a card instance id, 0 = no stacking) stacks simultaneous floats
# on one card upward so they never overlap.
func _spawn_float_label(text: String, color: Color, origin: Vector2, mult: float, stack_key: int) -> void:
	if _scene.float_layer == null or not is_instance_valid(_scene.float_layer):
		return
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FLOAT_FONT_SIZE)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	label.add_theme_constant_override("outline_size", FLOAT_OUTLINE_SIZE)
	label.z_as_relative = false
	label.z_index = 100
	label.modulate = color
	_scene.float_layer.add_child(label)
	label.move_to_front()
	label.reset_size()
	label.position = Vector2(origin.x - label.size.x * 0.5, origin.y)

	# Stacking rule: a new float on a card with floats still in flight spawns
	# ABOVE the highest-stacked live one (they all rise at the same speed, so
	# they never cross).
	if stack_key != 0:
		var live: Array = _live_floats_by_card.get(stack_key, [])
		var pruned: Array = []
		var min_y: float = INF
		for entry_variant in live:
			# Validity check BEFORE the cast — casting a freed instance errors.
			if entry_variant != null and is_instance_valid(entry_variant):
				var entry: Label = entry_variant
				pruned.append(entry)
				min_y = minf(min_y, entry.position.y)
		if min_y != INF:
			label.position.y = minf(label.position.y, min_y - label.size.y * mult - FLOAT_STACK_GAP)
		pruned.append(label)
		_live_floats_by_card[stack_key] = pruned

	# Pixel snap law (INVARIANTS #14): land the spawn position on whole window px.
	label.position.x = PixelUI.snap_to_physical_px(_scene.float_layer, label.position.x, 0)
	label.position.y = PixelUI.snap_to_physical_px(_scene.float_layer, label.position.y, 1)

	# punch_number: scale in from small with an overshoot, then settle, so the
	# number "pops" on arrival. Bigger hits punch larger. Scale is centered on the
	# label so it grows from its middle.
	label.pivot_offset = label.get_minimum_size() * 0.5
	label.scale = Vector2(0.5, 0.5)
	var punch: Tween = create_tween()
	punch.tween_property(label, "scale", Vector2.ONE * (mult * 1.25), 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(label, "scale", Vector2.ONE * mult, 0.13) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Rise over the whole lifetime; hold full alpha for a beat, then fade out.
	var tween: Tween = create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -FLOAT_RISE), FLOAT_LIFETIME)
	tween.parallel().tween_property(label, "modulate:a", 0.0, FLOAT_LIFETIME - FLOAT_FADE_HOLD) \
		.set_delay(FLOAT_FADE_HOLD)
	tween.tween_callback(label.queue_free)


# Floating-number punch scale: damage scales up with the hit (heavy hits read
# bigger), everything else stays at its base size. Clamp re-tuned for the 36px
# base so a max-size hit stays under ~60% of a card's width.
func _float_size_mult(event_type: String, amount: int) -> float:
	if event_type == "damage" or event_type == "burn":
		return clampf(0.95 + float(amount) * 0.010, 0.95, 1.35)
	# Execute (pkg8.4): the bonus reads oversized when it triggers.
	if event_type == "execute":
		return 1.6
	return 1.0


func _get_card_float_origin(card: Control) -> Vector2:
	var card_rect: Rect2 = card.get_global_rect()
	var layer_origin: Vector2 = _scene.float_layer.get_global_position()
	# Spawn over the portrait (30% down the card), not the nameplate — the big
	# number needs the dark art behind it, not name text fighting it.
	return Vector2(
		card_rect.position.x - layer_origin.x + card_rect.size.x * 0.5,
		card_rect.position.y - layer_origin.y + card_rect.size.y * 0.30
	)


# The float vocabulary: colored signed numbers only. Words are cut — statuses
# already read through chips + keyword visuals (freeze crust, mark flash,
# shield chips vanishing). The ward-negate ✕ is THE glyph exception: negation
# is otherwise invisible. roll_buff floats at the die via
# _spawn_roll_buff_float, never here.
func _build_floating_text(event_type: String, amount: int) -> String:
	match event_type:
		"damage", "burn", "chain", "detonate", "spike", "execute":
			return "-%d" % amount
		"heal", "shield":
			return "+%d" % amount
		"block":
			return "✕" if amount <= 0 else "✕ %d" % amount
		_:
			# freeze / mark / wipe_shields: cut (redundant with chip + keyword
			# visual). leech / pierce / accrete / revive: the paired damage /
			# shield / heal events carry the numbers. Everything else is silent.
			return ""


func _get_floating_color(event_type: String) -> Color:
	match event_type:
		"damage", "burn", "chain", "detonate", "spike":
			return Color(1.0, 0.42, 0.42, 1.0)
		"execute":
			return Color(1.0, 0.30, 0.30, 1.0)
		"heal":
			return Color(0.5, 1.0, 0.62, 1.0)
		"shield", "block", "roll_buff":
			return Color(0.55, 0.82, 1.0, 1.0)
		_:
			return Color(1, 1, 1, 1)


# ── Tier 1 primitives ─────────────────────────────────────────────────────────

# ── Global-effect arbiter — the SINGLE owner of Engine.time_scale ─────────────
# All screen-wide TIME effects (the hit-pause freeze and the 20-celebration
# slow-mo) route through here so they can never COMPOUND: a double hit-pause
# reads as a frame drop and stacked slow-mo reads as broken. Rule: one global
# time effect at a time — while one runs, a new request is dropped (the safe
# "never compound" approximation of strongest/most-recent-wins for this basic
# pass). Frame-local effects are EXEMPT and may run simultaneously — per-unit
# card shakes, per-unit death scatters, and HP drains on different units are all
# separate objects with no collision. The board shake (a positional effect, not
# a time effect) is likewise a separate channel and may overlap these.
# AUDIO PASS (Prompt 8): this `_global_fx_active` gate is the one choke point for
# global screen-effect timing — hook screen-effect SFX to the same arbiter.
const HIT_PAUSE_MIN := 0.04
const HIT_PAUSE_MAX := 0.09
# 20-celebration slow-mo: a BRIEF dilation (not a full freeze) that punctuates
# the overload without interrupting flow. Capped short so a run where 20s come
# up often never feels laggy (collision rule 4: the celebration must not stall).
const SLOWMO_SCALE := 0.35
const SLOWMO_REAL_DUR := 0.12
var _global_fx_active: bool = false

func _hit_pause(amount: int, extra: float = 0.0) -> void:
	if _global_fx_active:
		return
	if not is_inside_tree() or get_tree() == null:
		return
	_global_fx_active = true
	var dur: float = clampf(HIT_PAUSE_MIN + float(amount) * 0.0018, HIT_PAUSE_MIN, HIT_PAUSE_MAX) + extra
	Engine.time_scale = 0.0
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0
	_global_fx_active = false


# The 20-celebration's time beat. Dilates the scene clock briefly, then restores.
# The timer is real-time (ignore_time_scale = true), so the beat lasts a fixed
# wall-clock duration regardless of the slowed scene clock. Shares the arbiter
# gate with _hit_pause, so a slow-mo and a hit-pause can never stack.
func _slow_mo() -> void:
	if _global_fx_active:
		return
	if not is_inside_tree() or get_tree() == null:
		return
	_global_fx_active = true
	Engine.time_scale = SLOWMO_SCALE
	await get_tree().create_timer(SLOWMO_REAL_DUR, true, false, true).timeout
	Engine.time_scale = 1.0
	_global_fx_active = false


# The overload signature: a brief, subtle gold screen wash (commit color) plus a
# board-wide shake, framing the payoff beat. Flat, no glow — just a flash. Fires
# on any ability whose die's final face is 20, however it reached 20 (NK-02).
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


# ── pkg8.4 keyword feedback (composed from the primitive library) ────────────
# Chain = tracer to the jumped target · Detonate = burn-chip flash then ember
# burst (the combined number floats via the generic channel) · Breach =
# shield-shatter burst · Spike = spark burst on the attacker · Siphon = amber
# pip drifts from the protocol bar to the enemy · Hijack = ghost die label
# drifts from the hero rail to the enemy card · Jam = static flicker on the
# die · Rewrite = the die's marker scrambles then slams to 3 · Decloak = the
# portrait resolves sharp · Leech = dim red return tracer from the drained
# enemy (paired event; the heal event carries the green number) · Ward
# consume = hex flash + "✕ NEGATED". Mark/Execute run through the
# floating-text and pause channels. All flat, palette-driven, no glow.
func _play_keyword_feedback(event_type: String, event: Dictionary, actor_card: Control, target_card: Control) -> void:
	match event_type:
		"chain":
			_tracer(actor_card, target_card, Color(0.55, 0.85, 1.0, 0.9))
		"detonate":
			_chip_flash_then_burst(target_card, PixelUI.DT_STATUS["burn"]["border"], Color(0.95, 0.55, 0.20, 1.0), 14)
		"breach":
			_shield_shatter(target_card, Color(1.0, 0.82, 0.20, 1.0))
		"wipe_shields":
			_shield_shatter(target_card, Color(1.0, 0.80, 0.20, 1.0))
		"spike":
			_burst_particles(target_card, Color(0.86, 0.42, 0.28, 1.0), 8)
		"leech":
			# fix-2.7: the return tracer — HP flows back from the drained enemy.
			var source_card: Control = _find_card_by_state_id(str(event.get("source_side", "")), str(event.get("source_id", "")))
			_tracer(source_card, target_card, Color(0.85, 0.30, 0.30, 0.75))
		"block":
			if int(event.get("amount", 0)) <= 0:
				# Ward consume — hex flash in the shield channel.
				_hex_flash(target_card, Color(0.55, 0.82, 1.0, 0.95))
		"siphon":
			var bar_from: Vector2 = Vector2(_scene.size.x * 0.5, _scene.size.y - 60.0)
			if _scene.protocol_bar != null and is_instance_valid(_scene.protocol_bar):
				bar_from = _scene.protocol_bar.get_global_rect().get_center()
			_drift_pip(bar_from, target_card, Color(0.95, 0.76, 0.28, 1.0), "-%d" % int(event.get("amount", 0)))
		"hijack":
			var tray_from: Vector2 = Vector2(_scene.size.x * 0.5, _scene.size.y * 0.62)
			_drift_pip(tray_from, target_card, Color(0.95, 0.45, 0.30, 1.0), EffectPip.keyword_code("hijack", "HJ"))
		"jam":
			if _scene.dice_tray_3d != null:
				_scene.dice_tray_3d.play_jam_flicker(str(event.get("side", "")), str(event.get("target_id", "")), int(event.get("amount", 0)))
		"rewrite":
			if _scene.dice_tray_3d != null:
				_scene.dice_tray_3d.play_rewrite_scramble(str(event.get("side", "")), str(event.get("target_id", "")))
		"decloak":
			_resolve_portrait_sharp(target_card)


# Primitive: a flat tracer line from one card to another — snaps in bright,
# fades fast. Used by Chain (and future paired beats).
func _tracer(from_card: Control, to_card: Control, color: Color) -> void:
	if from_card == null or to_card == null or not is_instance_valid(from_card) or not is_instance_valid(to_card):
		return
	if _scene.float_layer == null or not is_instance_valid(_scene.float_layer):
		return
	var line: Line2D = Line2D.new()
	line.width = 5.0
	line.default_color = color
	line.z_as_relative = false
	line.z_index = 190
	var layer_origin: Vector2 = _scene.float_layer.get_global_position()
	line.add_point(from_card.get_global_rect().get_center() - layer_origin)
	line.add_point(to_card.get_global_rect().get_center() - layer_origin)
	_scene.float_layer.add_child(line)
	var tween: Tween = create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.28).set_delay(0.10)
	tween.tween_callback(line.queue_free)


# Detonate composition: a chip-sized flash in the burn color pops at the
# card's status strip (the consumed Burn chip's home), then hands off to the
# ember burst. Flat rects only.
func _chip_flash_then_burst(card: Control, chip_color: Color, burst_color: Color, count: int) -> void:
	if card == null or not is_instance_valid(card):
		return
	if _scene.float_layer == null or not is_instance_valid(_scene.float_layer):
		_burst_particles(card, burst_color, count)
		return
	var layer_origin: Vector2 = _scene.float_layer.get_global_position()
	var card_rect: Rect2 = card.get_global_rect()
	var chip: ColorRect = ColorRect.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.color = chip_color
	chip.size = Vector2(30, 30)
	chip.position = card_rect.position - layer_origin + Vector2(10.0, card_rect.size.y * 0.60)
	chip.z_as_relative = false
	chip.z_index = 195
	chip.pivot_offset = chip.size * 0.5
	_scene.float_layer.add_child(chip)
	chip.scale = Vector2(0.4, 0.4)
	var tween: Tween = create_tween()
	tween.tween_property(chip, "scale", Vector2(1.3, 1.3), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(chip, "modulate:a", 0.0, 0.10)
	tween.tween_callback(func() -> void:
		chip.queue_free()
		_burst_particles(card, burst_color, count)
	)


# Ward consume: a flat hexagon outline pops over the card and fades — the
# "hex flash". Palette shield cyan, no glow.
func _hex_flash(card: Control, color: Color) -> void:
	if card == null or not is_instance_valid(card):
		return
	if _scene.float_layer == null or not is_instance_valid(_scene.float_layer):
		return
	var layer_origin: Vector2 = _scene.float_layer.get_global_position()
	var center: Vector2 = card.get_global_rect().get_center() - layer_origin
	var hex: Line2D = Line2D.new()
	hex.width = 5.0
	hex.default_color = color
	hex.closed = true
	hex.z_as_relative = false
	hex.z_index = 195
	var radius: float = 46.0
	for i in 6:
		hex.add_point(center + Vector2.RIGHT.rotated(TAU * float(i) / 6.0 - TAU / 12.0) * radius)
	_scene.float_layer.add_child(hex)
	hex.scale = Vector2(0.5, 0.5)
	# Line2D points are in layer space, so scale around the hex's center.
	hex.position = center * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(hex, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(hex, "position", Vector2.ZERO, 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(hex, "modulate:a", 0.0, 0.22)
	tween.tween_callback(hex.queue_free)


# Primitive: a flat particle burst — small squares scatter from the card's
# center and fade. Palette color, no glow.
func _burst_particles(card: Control, color: Color, count: int = 10) -> void:
	if card == null or not is_instance_valid(card):
		return
	if _scene.float_layer == null or not is_instance_valid(_scene.float_layer):
		return
	var layer_origin: Vector2 = _scene.float_layer.get_global_position()
	var origin: Vector2 = card.get_global_rect().get_center() - layer_origin
	for _i in count:
		var shard: ColorRect = ColorRect.new()
		shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shard.color = color
		shard.size = Vector2(6, 6)
		shard.position = origin
		shard.z_as_relative = false
		shard.z_index = 195
		_scene.float_layer.add_child(shard)
		var direction: Vector2 = Vector2.RIGHT.rotated(randf() * TAU)
		var distance: float = randf_range(34.0, 86.0)
		var tween: Tween = create_tween()
		tween.tween_property(shard, "position", origin + direction * distance, 0.30) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, 0.30)
		tween.tween_callback(shard.queue_free)


# Primitive: death scatter — the unit breaks apart on a fatal hit. Cheap flat-
# pixel debris: a handful of team-tinted + ash shards burst from across the card
# and arc-fall as they fade, reading as "this unit died" without a bespoke
# particle system. Frame-local (per-unit), so several deaths on one frame may run
# together; callers pass a small STAGGER (a few frames) per extra death so a
# chain that kills two doesn't scatter both on the exact same frame.
const DEATH_DEBRIS_COUNT := 12

func _death_scatter(card: Control, side: String, stagger: float = 0.0) -> void:
	if card == null or not is_instance_valid(card):
		return
	if _scene.float_layer == null or not is_instance_valid(_scene.float_layer):
		return
	var layer_origin: Vector2 = _scene.float_layer.get_global_position()
	var card_rect: Rect2 = card.get_global_rect()
	var origin: Vector2 = card_rect.get_center() - layer_origin
	# Meaning-based color: the dying unit's own team line, flecked with ash — not
	# damage-red (that reads as a hit, not a death).
	var team: Color = PixelUI.DT_HERO_BORDER if side == "hero" else PixelUI.DT_ENEMY_BORDER
	var ash: Color = Color(0.42, 0.44, 0.50, 1.0)
	for i in DEATH_DEBRIS_COUNT:
		var shard: ColorRect = ColorRect.new()
		shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shard.color = ash if i % 3 == 0 else team
		var side_len: float = randf_range(6.0, 12.0)
		shard.size = Vector2(side_len, side_len)
		# Spread the origin across the card so the WHOLE frame reads as breaking,
		# not a single point-source burst.
		var start: Vector2 = origin + Vector2(
			randf_range(-card_rect.size.x * 0.30, card_rect.size.x * 0.30),
			randf_range(-card_rect.size.y * 0.30, card_rect.size.y * 0.30)
		)
		shard.position = start
		shard.z_as_relative = false
		shard.z_index = 205
		shard.modulate.a = 0.0
		_scene.float_layer.add_child(shard)
		# Up-and-out to an apex, then fall past it — a cheap gravity arc.
		var horiz: float = randf_range(-70.0, 70.0)
		var apex: Vector2 = start + Vector2(horiz, randf_range(-90.0, -40.0))
		var landing: Vector2 = apex + Vector2(horiz * 0.4, randf_range(90.0, 150.0))
		var tween: Tween = create_tween()
		tween.tween_interval(stagger)
		tween.tween_callback(func() -> void: shard.modulate.a = 1.0)
		tween.tween_property(shard, "position", apex, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "position", landing, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, 0.34)
		tween.tween_callback(shard.queue_free)


# Primitive: shield-shatter — a broken shield reads as breaking glass, distinct
# from the generic square-confetti hit burst: an expanding flat ring (the shield
# surface popping) plus thin angular slivers fanning outward. Palette-driven, no
# glow. Used by Breach and by wipe_shields.
func _shield_shatter(card: Control, color: Color) -> void:
	if card == null or not is_instance_valid(card):
		return
	if _scene.float_layer == null or not is_instance_valid(_scene.float_layer):
		return
	var layer_origin: Vector2 = _scene.float_layer.get_global_position()
	var center: Vector2 = card.get_global_rect().get_center() - layer_origin
	# 1) expanding ring — the shield surface popping outward. Line2D points live in
	# layer space, so we scale about `center` by compensating position (same trick
	# as _hex_flash): a point renders at position + p*scale, so position =
	# center*(1-scale) keeps the ring centred as it grows.
	var ring: Line2D = Line2D.new()
	ring.width = 4.0
	ring.default_color = color
	ring.closed = true
	ring.z_as_relative = false
	ring.z_index = 196
	var segments: int = 12
	for i in segments:
		ring.add_point(center + Vector2.RIGHT.rotated(TAU * float(i) / float(segments)) * 26.0)
	_scene.float_layer.add_child(ring)
	ring.scale = Vector2(0.6, 0.6)
	ring.position = center * 0.4
	var ring_tween: Tween = create_tween()
	ring_tween.tween_property(ring, "scale", Vector2(1.5, 1.5), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.parallel().tween_property(ring, "position", -center * 0.5, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
	ring_tween.tween_callback(ring.queue_free)
	# 2) angular glass slivers — thin flat rectangles (not confetti squares) rotated
	# to their fly-out direction, radiating in an even fan.
	var sliver_count: int = 10
	for i in sliver_count:
		var sliver: ColorRect = ColorRect.new()
		sliver.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sliver.color = color
		sliver.size = Vector2(randf_range(4.0, 7.0), randf_range(12.0, 20.0))
		sliver.pivot_offset = sliver.size * 0.5
		var angle: float = TAU * float(i) / float(sliver_count) + randf_range(-0.2, 0.2)
		sliver.rotation = angle
		sliver.position = center
		sliver.z_as_relative = false
		sliver.z_index = 197
		_scene.float_layer.add_child(sliver)
		var direction: Vector2 = Vector2.RIGHT.rotated(angle)
		var distance: float = randf_range(40.0, 90.0)
		var tween: Tween = create_tween()
		tween.tween_property(sliver, "position", center + direction * distance, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(sliver, "modulate:a", 0.0, 0.26)
		tween.tween_callback(sliver.queue_free)


# Primitive: a labeled pip that drifts from a point to a card (Siphon drain,
# Hijack ghost die).
func _drift_pip(from_position: Vector2, to_card: Control, color: Color, text: String) -> void:
	if to_card == null or not is_instance_valid(to_card):
		return
	if _scene.float_layer == null or not is_instance_valid(_scene.float_layer):
		return
	var layer_origin: Vector2 = _scene.float_layer.get_global_position()
	var pip: Label = Label.new()
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.text = text
	pip.add_theme_font_size_override("font_size", PixelUI.scale_font_size(16))
	pip.add_theme_color_override("font_color", color)
	pip.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	pip.add_theme_constant_override("outline_size", 4)
	pip.z_as_relative = false
	pip.z_index = 195
	pip.position = from_position - layer_origin
	_scene.float_layer.add_child(pip)
	var tween: Tween = create_tween()
	tween.tween_property(pip, "position", to_card.get_global_rect().get_center() - layer_origin, 0.40) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(pip, "modulate:a", 0.0, 0.14)
	tween.tween_callback(pip.queue_free)


# Decloak (pkg8.4): the ghosted portrait resolves sharp with a brief white
# flash.
func _resolve_portrait_sharp(card: Control) -> void:
	if card == null or not is_instance_valid(card):
		return
	var base_modulate: Color = card.modulate
	card.modulate = Color(1.35, 1.35, 1.4, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(card, "modulate", base_modulate, 0.24)


# pkg8.3: overload name slam — the ability name punches in across the acting
# card (overshoot scale-in), holds a beat, and snaps out. Flat gold on dark.
func _slam_ability_name(actor_card: Control, ability_name: String) -> void:
	if actor_card == null or not is_instance_valid(actor_card) or ability_name == "":
		return
	if _scene.float_layer == null or not is_instance_valid(_scene.float_layer):
		return
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = ability_name.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", PixelUI.scale_font_size(30))
	label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.20, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.05, 1.0))
	label.add_theme_constant_override("outline_size", 6)
	label.z_as_relative = false
	label.z_index = 210
	_scene.float_layer.add_child(label)
	label.reset_size()
	var card_rect: Rect2 = actor_card.get_global_rect()
	var layer_origin: Vector2 = _scene.float_layer.get_global_position()
	label.position = Vector2(
		card_rect.position.x - layer_origin.x + (card_rect.size.x - label.size.x) * 0.5,
		card_rect.position.y - layer_origin.y + card_rect.size.y * 0.36
	)
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2(0.2, 0.2)
	label.modulate.a = 0.0
	var slam: Tween = create_tween()
	slam.tween_property(label, "modulate:a", 1.0, 0.06)
	slam.parallel().tween_property(label, "scale", Vector2(1.28, 1.28), 0.10) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slam.tween_property(label, "scale", Vector2.ONE, 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	slam.tween_interval(0.42)
	slam.tween_property(label, "modulate:a", 0.0, 0.12)
	slam.parallel().tween_property(label, "scale", Vector2(0.85, 0.85), 0.12)
	slam.tween_callback(label.queue_free)


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


