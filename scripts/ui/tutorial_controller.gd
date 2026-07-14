# Drives the rigged onboarding encounter: dims the screen, cuts a spotlight hole around one
# real UI element at a time, attaches a coachmark, and gates each beat on the player's actual
# action (via battle_scene's tutorial_event signal) or a tap. A persistent Skip ends it. The
# dim/ring/coachmark visuals live in the shared SpotlightLayer (also used by the keyword
# primers); this controller owns the step script, the event gating, and target resolution.
# The spotlight hole leaves the highlighted element fully interactive so gated steps work on
# the real control.
class_name TutorialController
extends Node

# Above the battle scene + header (8) but BELOW InspectPopup (130) / HelpMenu (135), so a
# long-press inspect shows above the coachmarks instead of being dimmed under them.
const LAYER := 110
const PAD := 14.0
const DIE_HALF_PX := 84.0       # half-size of a rendered die, for spotlighting a single unit's die
const SKIP_FONT := 26

# Preload (not the global class name) so a fresh checkout's headless run parses
# before the editor rebuilds the class cache — same gotcha as the sim policies.
const SpotlightLayerScript := preload("res://scripts/ui/spotlight_layer.gd")

var _scene: Node = null
var _step: int = 0
var _steps: Array = []

var _spot = null  # SpotlightLayer — the shared dim + ring + coachmark machine


func start(scene: Node) -> void:
	_scene = scene
	_steps = _build_steps()
	_build_ui()
	if _scene.has_signal("tutorial_event"):
		_scene.tutorial_event.connect(_on_tutorial_event)
	_show_step(0)


# ── Step script ─────────────────────────────────────────────────────────────────
# Each step: { targets:[keys], text, advance:"tap"|event, phase:"" (optional event predicate),
# title:"" (optional) }. Keys resolve to battle nodes in _target_rect().
func _build_steps() -> Array:
	return [
		# Phase 0 — orientation (tap). Inspect is taught later on the player's own unit, so no
		# separate enemy long-press beat here.
		{"targets": [], "title": "WELCOME", "text": "Welcome to Overload Protocol. I'll show you around the screen, then walk you through your first two turns."},
		{"targets": ["header"], "text": "This bar stays with you all run - squad progress and the Help menu live here. Help holds the full encyclopedia."},
		{"targets": ["hero_cards"], "text": "Your three specialists. Each has its own HP and abilities."},
		{"targets": ["enemy_cards"], "text": "Your target."},
		# Phase 1 — turn 1: the core loop
		{"targets": ["roll_button"], "text": "Tap Roll to set your dice.", "advance": "roll_pressed"},
		{"targets": ["center"], "text": "Each die slots into a band. Higher rolls fire stronger abilities."},
		# Ability pips (Batch 5): highlight the ACTUAL ability pips, not the whole unit — and
		# every unit's roll this turn is a new ability, so highlight all three at once.
		{"targets": ["ability:combat", "ability:engineer", "ability:medic"], "separate": true, "text": "These pips are what each die will do: Strike Unit marks the drone, Field Engineer shields, Splice Medic heals. The first time an ability type appears you'll get a one-time tip like this."},
		# Long-press (Batch 5): note it works on nearly everything.
		{"targets": ["hero_cards"], "text": "Long-press a card for its full breakdown - bands, keywords, all of it. Long-press works on nearly everything in the game. Try it.", "advance": "inspected"},
		# Pick a die first (heroes + pips + dice highlighted); once targeting starts we spotlight the
		# enemy to tap, then open up the whole screen to assign the rest.
		{"targets": ["heroes"], "text": "Tap a die (or its hero card) to pick who fires.", "advance": "targeting_started"},
		{"targets": ["enemy_cards"], "text": "Now tap a target to fire it - the drone for an attack, an ally for a heal or shield.", "advance": "assigned"},
		{"targets": [], "fullscreen": true, "coach_center": true, "text": "Assign your remaining dice.", "advance": "phase", "phase": "ready_to_end"},
		{"targets": ["enemy_readouts"], "text": "Enemies telegraph their moves, be sure to account for this!"},
		{"targets": ["roll_button"], "text": "Lock it in - ending the turn fires every die you assigned, then the enemy takes its action.", "advance": "turn_resolved"},
		# Status-badge lesson (Batch 5): Target Lock left a MARK chip on the drone. Spotlight it.
		{"targets": ["enemy_status"], "text": "Strike Unit's Target Lock left a mark on the drone. Units carry status badges like this after effects land - the next hit spends the mark for extra damage."},
		# Phase 2 — turn 2: Protocol & Nudge. "Roll again" waits for the dice to settle (advance
		# "rolled") before moving on.
		{"targets": ["roll_button"], "text": "Roll again.", "advance": "roll_pressed"},
		# Invisible waiter: the coach hides while the dice roll, then the
		# Protocol beat lands once they settle (Kev 2026-07-10).
		{"targets": [], "hide_coach": true, "advance": "rolled"},
		{"targets": ["protocol_value"], "text": "You earned 1 Protocol after your last turn - time to spend it. It builds +1 every turn, caps at 10."},
		# Nudge is TWO beats (Kev fix #3, 2026-07-12): the button beat advances the
		# INSTANT the press arms the pick (the "phase" event from transition() — the
		# shared choke point, zero new wiring), then the die beat gates on the
		# applied nudge. The old single beat gated on "nudged" (emitted only after
		# button + die pick + apply), so pressing the big highlighted button moved
		# nothing — it read as a consumed click.
		{"targets": ["nudge"], "text": "Nudge costs 1 Protocol - tap it.", "advance": "phase", "phase": "nudge_pick"},
		{"targets": ["combat"], "text": "Now tap Strike Unit's die - +3 pushes it into a stronger band.", "advance": "nudged"},
		{"targets": ["ability:combat"], "text": "It jumped a band - Suppression Fire became Rail Strike, and the mark makes the hit land even harder."},
		{"targets": ["reroll", "set"], "separate": true, "text": "Reroll (2) and Set (4) cost more - they unlock as you bank Protocol."},
		{"targets": [], "fullscreen": true, "coach_center": true, "text": "Tap Strike Unit's die, then the drone to fire it.", "advance": "assigned"},
		{"targets": [], "fullscreen": true, "coach_center": true, "text": "Finish it - assign the rest and end the turn.", "advance": "won"},
		{"targets": [], "text": "That's the loop. The Help menu has the full encyclopedia whenever you need it.", "title": "DRILL COMPLETE", "advance": "tap_finish"},
	]


func _current() -> Dictionary:
	return _steps[_step] if _step >= 0 and _step < _steps.size() else {}


func _advance_mode() -> String:
	return str(_current().get("advance", "tap"))


# ── Event / tap gating ──────────────────────────────────────────────────────────
func _on_tutorial_event(event: StringName, payload: Dictionary) -> void:
	var mode: String = _advance_mode()
	# A press that starts an animation (roll, end turn) but isn't our gate: reveal the whole board
	# (no dim, just the edge frame) so the spotlight doesn't linger on the now-gone/changing
	# control and the player can watch the roll / turn resolution play out.
	if (event == &"roll_pressed" or event == &"end_turn_pressed") and String(event) != mode:
		_reveal_whole_screen()
	if mode == "tap" or mode == "tap_finish":
		return
	if String(event) != mode:
		return
	# Optional payload predicate (e.g. phase == ready_to_end).
	if _current().has("phase") and str(payload.get("phase", "")) != str(_current()["phase"]):
		return
	_next()


# Drop the dim to the whole-screen frame (no dimming, just the edge border), keeping the coachmark —
# used while a roll / turn resolution animates so the player can watch the board play out.
func _reveal_whole_screen() -> void:
	if _spot != null:
		_spot.set_holes([_spot.fullscreen_hole()])


# Taps only arrive from the SpotlightLayer when the step is interactive
# (advance-on-tap); gated steps set the layer to pass input through.
func _on_spot_tapped() -> void:
	var mode: String = _advance_mode()
	if mode == "tap":
		_next()
	elif mode == "tap_finish":
		_finish()


func _next() -> void:
	if _advance_mode() == "tap_finish":
		_finish()
		return
	_step += 1
	if _step >= _steps.size():
		_finish()
		return
	_show_step(_step)


func _finish() -> void:
	if _scene != null and _scene.has_signal("tutorial_event") and _scene.tutorial_event.is_connected(_on_tutorial_event):
		_scene.tutorial_event.disconnect(_on_tutorial_event)
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		gs.set("tutorial_mode", false)
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager != null:
		save_manager.call("mark_tutorial_done")
	var sm: Node = get_node_or_null("/root/SceneManager")
	queue_free()
	if sm != null:
		sm.call("go_to_main_menu")


# ── Layout / spotlight ────────────────────────────────────────────────────────────
func _show_step(index: int) -> void:
	_step = index
	# Resolve next frame so freshly-built nodes (dice rows after a roll) have a real rect.
	call_deferred("_layout_step")


func _layout_step() -> void:
	var step: Dictionary = _current()
	if step.is_empty():
		return
	var mode: String = _advance_mode()
	var tap_step: bool = mode == "tap" or mode == "tap_finish"
	# hide_coach waiter steps (Kev 2026-07-10): no dim, no coach — the board
	# plays out (dice rolling) until the advance event fires.
	if bool(step.get("hide_coach", false)):
		if _spot != null:
			_spot.dismiss()
		return
	var holes: Array = _compute_holes(step)
	# Whole-screen steps pin the coach to the bottom so it never covers the
	# centre Roll/End-Turn button; coach_center steps read mid-screen instead
	# (Kev 2026-07-10: bottom text was hard to read on assign-dice beats).
	var anchor: int = SpotlightLayerScript.CoachAnchor.AUTO
	if bool(step.get("fullscreen", false)):
		anchor = SpotlightLayerScript.CoachAnchor.CENTER if bool(step.get("coach_center", false)) else SpotlightLayerScript.CoachAnchor.BOTTOM
	if _spot != null:
		_spot.spotlight(holes, str(step.get("text", "")), anchor, {
			"title": str(step.get("title", "")),
			"hint": "Tap to continue >" if tap_step else "",
			"interactive": tap_step,
		})


# Holes to spotlight this step, in screen space:
#   • "fullscreen" → one frame just inside the edges (whole board visible/interactive).
#   • "separate"   → each target key is its OWN hole (e.g. Nudge + Pulse as two distinct zones).
#   • otherwise    → all target keys merged into a single hole.
func _compute_holes(step: Dictionary) -> Array:
	if bool(step.get("fullscreen", false)):
		return [_fullscreen_hole()]
	var keys: Array = step.get("targets", [])
	if bool(step.get("separate", false)):
		var holes: Array = []
		for key in keys:
			var r: Rect2 = _target_rect(str(key))
			if r.size != Vector2.ZERO:
				holes.append(r.grow(PAD))
		return holes
	var merged: Rect2 = _targets_rect(keys)
	return [merged] if merged.size != Vector2.ZERO else []


func _fullscreen_hole() -> Rect2:
	return _spot.fullscreen_hole() if _spot != null else Rect2()


func _targets_rect(keys: Array) -> Rect2:
	var rect: Rect2 = Rect2()
	var has_any := false
	for key in keys:
		var r: Rect2 = _target_rect(str(key))
		if r.size == Vector2.ZERO:
			continue
		rect = r if not has_any else rect.merge(r)
		has_any = true
	if not has_any:
		return Rect2()
	return rect.grow(PAD)


func _target_rect(key: String) -> Rect2:
	# "ability:<unit_id>" spotlights just that hero's ability-pip readout (Batch 5:
	# highlight the ability, not the whole unit).
	if key.begins_with("ability:"):
		return _hero_readout_rect(key.substr(8))
	# The enemy's status-badge slot (the MARK chip); falls back to the enemy card so the
	# spotlight always resolves a hole even before the chip has laid out.
	if key == "enemy_status":
		return _enemy_status_rect()
	match key:
		"header":
			var h: Node = get_node_or_null("/root/PersistentHeader")
			var band: float = 144.0
			if h != null:
				var v: Variant = h.get("HEADER_HEIGHT")
				if v != null:
					band = float(v)
			return Rect2(0, 0, get_viewport().get_visible_rect().size.x, band)
		"roll_button":
			return _node_rect(_scene.get("roll_button"))
		"hero_cards":
			return _node_rect(_scene.get("hero_cards"))
		"hero_area":
			# The hero cards + their dice/readout row — where you tap a die to fire it.
			return _merge_nonempty(_node_rect(_scene.get("hero_cards")), _node_rect(_scene.get("hero_dice_row")))
		"heroes":
			# All three units: cards + ability pips (readouts) + their rolled dice (the dice render
			# up in the tray, not next to the cards — see _hero_unit_rect).
			var heroes_rect: Rect2 = Rect2()
			var views: Variant = _scene.get("hero_card_views")
			if views is Array:
				for v in views:
					var st: Dictionary = (v as Dictionary).get("state", {})
					var u: Object = st.get("unit", null) as Object
					if u != null:
						heroes_rect = _merge_nonempty(heroes_rect, _hero_unit_rect(str(u.id)))
			return heroes_rect
		"center":
			# The whole dice tray — the actual combat-zone rect the 3D dice roll inside, not the
			# thin layout containers (which sit empty beside the cards).
			return _dice_tray_rect()
		"enemy_cards":
			return _merge_nonempty(_node_rect(_scene.get("enemy_cards")), _node_rect(_scene.get("enemy_dice_row")))
		"enemy_readouts":
			return _merge_nonempty(_node_rect(_scene.get("enemy_readouts")), _node_rect(_scene.get("enemy_dice_row")))
		"protocol_bar":
			return _merge_nonempty(_node_rect(_scene.get("protocol_bar")), _node_rect(_scene.get("protocol_panel")))
		"protocol_value":
			# The numeric label is hidden since the footer redesign (the 10 bar
			# segments convey the count) — spotlight the bar itself, and merge the
			# label back in automatically if it ever returns.
			return _merge_nonempty(_node_rect(_scene.get("protocol_value_label")), _target_rect("protocol_bar"))
		"nudge":
			return _node_rect(_protocol_button("nudge_button"))
		"set":
			return _node_rect(_protocol_button("set_button"))
		"reroll":
			return _node_rect(_scene.get("protocol_spend_button"))
		"battle_log":
			return _node_rect(_scene.get("battle_log_panel"))
	# Any hero unit id spotlights that unit (card + pips + die) — generic form
	# of the old hardcoded "pulse" case. The nudge die beat targets "combat";
	# the old ["nudge", "combat"] step silently resolved NO hole for "combat"
	# because no such key existed (found by the 2026-07-12 step split).
	var unit_rect: Rect2 = _hero_unit_rect(key)
	if unit_rect.size != Vector2.ZERO:
		return unit_rect
	return Rect2()


# Just the ability-pip readout row for one hero (Batch 5 — highlight the ability, not the unit).
func _hero_readout_rect(unit_id: String) -> Rect2:
	var views: Variant = _scene.get("hero_card_views")
	if not (views is Array):
		return Rect2()
	for view_variant in views:
		var view: Dictionary = view_variant
		var state: Dictionary = view.get("state", {})
		var unit: Object = state.get("unit", null) as Object
		if unit != null and str(unit.id) == unit_id:
			var readout_rect: Rect2 = _node_rect(view.get("readout", null))
			# Fall back to the whole unit if the readout hasn't been built/laid out yet, so the
			# spotlight always resolves a hole.
			return readout_rect if readout_rect.size != Vector2.ZERO else _hero_unit_rect(unit_id)
	return Rect2()


# The enemy card's status-badge slot (the MARK chip lives here). Falls back to the whole enemy
# card so the spotlight always resolves a hole.
func _enemy_status_rect() -> Rect2:
	var views: Variant = _scene.get("enemy_card_views")
	if not (views is Array) or (views as Array).is_empty():
		return Rect2()
	var view: Dictionary = (views as Array)[0]
	var card: Object = view.get("card", null) as Object
	if card == null:
		return Rect2()
	var slot_rect: Rect2 = _node_rect(card.get("_status_slot"))
	return slot_rect if slot_rect.size != Vector2.ZERO else _node_rect(card)


# Spotlight one hero by unit id: their card + ability-pip readout + their rolled die. The die isn't
# next to the card — it's rendered up in the tray — so we pull its real position from the layout.
func _hero_unit_rect(unit_id: String) -> Rect2:
	var views: Variant = _scene.get("hero_card_views")
	if not (views is Array):
		return Rect2()
	for view_variant in views:
		var view: Dictionary = view_variant
		var state: Dictionary = view.get("state", {})
		var unit: Object = state.get("unit", null) as Object
		if unit == null or str(unit.id) != unit_id:
			continue
		var rect: Rect2 = _node_rect(view.get("card", null))
		rect = _merge_nonempty(rect, _node_rect(view.get("readout", null)))
		rect = _merge_nonempty(rect, _hero_die_rect(str(state.get("id", ""))))
		return rect
	return Rect2()


func _layout_node() -> Object:
	return _scene.get("_layout")


# The dice tray = the combat-zone rect the dice physically roll inside (authoritative geometry).
func _dice_tray_rect() -> Rect2:
	var layout: Object = _layout_node()
	if layout == null:
		return Rect2()
	var r: Rect2 = layout.get_combat_zone_rect()
	return r if r.size.x > 2.0 and r.size.y > 2.0 else Rect2()


# Global rect of the rendered die for one hero state, around its tray anchor point.
func _hero_die_rect(state_id: String) -> Rect2:
	var layout: Object = _layout_node()
	if layout == null or state_id == "":
		return Rect2()
	var cz: Rect2 = layout.get_combat_zone_rect()
	if cz.size.x <= 2.0 or cz.size.y <= 2.0:
		return Rect2()
	var pt: Vector2 = layout.get_dice_anchor_point("hero", state_id)
	if pt == Vector2.INF:
		return Rect2()
	var g: Vector2 = pt + cz.position
	return Rect2(g - Vector2(DIE_HALF_PX, DIE_HALF_PX), Vector2(DIE_HALF_PX * 2.0, DIE_HALF_PX * 2.0))


# The spend buttons moved into the ProtocolActions module (architecture review
# §1 rec 1); resolve through it.
func _protocol_button(name: String) -> Variant:
	var protocol: Variant = _scene.get("_protocol")
	if protocol == null:
		return null
	return protocol.get(name)


func _merge_nonempty(a: Rect2, b: Rect2) -> Rect2:
	if a.size == Vector2.ZERO:
		return b
	if b.size == Vector2.ZERO:
		return a
	return a.merge(b)


func _node_rect(node: Variant) -> Rect2:
	var control: Control = node as Control
	if control == null or not is_instance_valid(control) or not control.is_inside_tree() or not control.visible:
		return Rect2()
	var r: Rect2 = control.get_global_rect()
	if r.size.x < 2.0 or r.size.y < 2.0:
		return Rect2()
	return r


# ── Build the overlay UI ──────────────────────────────────────────────────────────
func _build_ui() -> void:
	# All dim/ring/coachmark visuals live in the shared SpotlightLayer; the
	# tutorial only adds its persistent Skip button on top.
	_spot = SpotlightLayerScript.new(LAYER)
	_spot.tapped.connect(_on_spot_tapped)
	add_child(_spot)

	# Persistent Skip — always available. Sits at the very top-left, over the FACILITY header label.
	var skip := Button.new()
	skip.text = "SKIP TUTORIAL"
	skip.custom_minimum_size = Vector2(360, 84)
	skip.mouse_filter = Control.MOUSE_FILTER_STOP
	PixelUI.style_button(skip, PixelUI.BG_PANEL_ALT, PixelUI.LINE_DIM, SKIP_FONT)
	skip.add_theme_color_override("font_color", PixelUI.TEXT_MUTED)
	skip.pressed.connect(_finish)
	var skip_wrap := Control.new()
	skip_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# On the spotlight's canvas layer so Skip renders above the dim.
	_spot.add_overlay_control(skip_wrap)
	# Vertically centred within the header band's CONTENT region, pinned to the
	# left over the FACILITY label. On a cutout device the band is safe_top
	# taller and its content sits below the camera — center in that region, not
	# the raw band rect (which would seat SKIP partially under the punch-hole).
	var header_band: float = _target_rect("header").size.y
	var skip_h: float = 84.0
	var content_h: float = maxf(header_band - float(PixelUI.safe_top), skip_h)
	var skip_top: float = maxf(float(PixelUI.safe_top) + (content_h - skip_h) * 0.5, 12.0)
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	skip.offset_left = 20
	skip.offset_top = skip_top
	skip.offset_right = 380
	skip.offset_bottom = skip_top + skip_h
	skip_wrap.add_child(skip)
