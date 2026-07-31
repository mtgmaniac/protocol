# Drives the rigged onboarding encounter: dims the screen, cuts a spotlight hole around one
# real UI element at a time, attaches a coachmark, and gates each beat on the player's actual
# action (via battle_scene's tutorial_event signal) or a tap. There is NO in-drill Skip
# button (playtest deletion stands — coachmark occlusion): the skip decision happens BEFORE
# entry, on the main menu's first-run choice overlay (Kev 2026-07-21), where SKIP sets the
# same tutorial_done flag as completing. The
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
# Frames a step will wait for its target rects to become valid before showing
# anyway (playtest item 9 — steps that follow a resolution animation could
# place against a not-yet-laid-out rect).
const LAYOUT_RETRY_FRAMES := 30

# Preload (not the global class name) so a fresh checkout's headless run parses
# before the editor rebuilds the class cache — same gotcha as the sim policies.
const SpotlightLayerScript := preload("res://scripts/ui/spotlight_layer.gd")

var _scene: Node = null
var _step: int = 0
var _steps: Array = []

var _spot = null  # SpotlightLayer — the shared dim + ring + coachmark machine


var _js_refresh_cb: JavaScriptObject = null


func start(scene: Node) -> void:
	_scene = scene
	_steps = _build_steps()
	_build_ui()
	if _scene.has_signal("tutorial_event"):
		_scene.tutorial_event.connect(_on_tutorial_event)
	if OS.has_feature("web"):
		# Web test seam: `window.__tut_refresh()` re-publishes the live state on
		# demand (read-only; drives nothing).
		_js_refresh_cb = JavaScriptBridge.create_callback(_on_js_refresh)
		JavaScriptBridge.get_interface("window").set("__tut_refresh", _js_refresh_cb)
	_show_step(0)


func _on_js_refresh(_args: Array) -> void:
	_publish_debug_state(_current(), [], "poll")


# ── Step script (v2.5, polish pass — 26 beats) ─────────────────────────────────
# Each step: { targets:[keys], text, advance:"tap"|event, phase:"" (optional event
# predicate), hero:"" (optional event predicate — the unit id carried in the
# event payload, e.g. assigned for a SPECIFIC hero), title:"" (optional) }.
# Keys resolve to battle nodes in _target_rect(). Copy is Kev-final; engine
# corrections only (drone's Stab is 7; badges are plain numerals — glyph law).
# v2.5 (Kev-approved polish pass): hero-intro beat added (welcome → header →
# YOUR side → THEIR side → roll), stage-1 assign spotlights include the ability
# pip, the nudge beat gates on hero=combat (with an input-level block in
# protocol_actions — the drill's only Protocol point must not be spendable on
# the wrong die), and order-teaching consolidated to the beat where ordering is
# actionable (the assign-the-rest beat).
func _build_steps() -> Array:
	return [
		# Phase 0 — orientation
		{"targets": [], "title": "WELCOME", "text": "Welcome to Overload Protocol. I'll walk you through your first fight."},
		{"targets": ["header"], "text": "This bar stays with you all run - squad progress and the Help menu live here."},
		{"targets": ["hero_cards"], "text": "Your squad - Strike Unit, Field Engineer, Splice Medic. Each rolls one die every turn."},
		{"targets": ["enemy_cards"], "text": "This is your target - a Scrap Drone. 35 HP, and it hits back."},
		# Phase 1 — turn 1
		{"targets": ["roll_button"], "text": "Tap ROLL.", "advance": "roll_pressed"},
		# Invisible waiter: the coach hides while the dice roll and settle.
		{"targets": [], "hide_coach": true, "advance": "rolled"},
		{"targets": ["center", "ability:combat", "ability:engineer", "ability:medic"], "separate": true, "text": "Each die lands in a band, and each band triggers a different ability. Higher is not always better. This turn: Strike Unit hits for 6, Field Engineer for 11, Splice Medic shields."},
		{"targets": ["hero_cards"], "text": "Long-press a card for the full breakdown - long-press works on nearly everything. Try it.", "advance": "inspected"},
		# Cast order (Model A): first mention here as setup; the actionable
		# teaching lives on the assign-the-rest beat (v2.5 consolidation).
		{"targets": ["die:combat", "card:combat", "ability:combat"], "separate": true, "text": "Tap Strike Unit's die, then the drone, to fire it. Your squad fires in the order you assign.", "advance": "assigned", "hero": "combat"},
		{"targets": ["die:engineer", "card:engineer", "ability:engineer"], "separate": true, "text": "Now Field Engineer - tap the die, then the drone.", "advance": "assigned", "hero": "engineer"},
		# Telegraph: the drone's card + its ability pip + its die (separate holes).
		{"targets": ["enemy_card", "enemy_pip", "enemy_die"], "separate": true, "text": "The drone is winding up a 7-point hit on Strike Unit. Enemies always show their hand before it lands."},
		{"targets": ["die:medic", "card:medic", "ability:medic"], "separate": true, "text": "Blunt it: tap Splice Medic's die, then Strike Unit. Shields absorb damage before HP does.", "advance": "assigned", "hero": "medic"},
		{"targets": ["roll_button"], "text": "Lock it in - your squad acts, then the drone.", "advance": "turn_resolved"},
		{"targets": ["combat", "battle_log"], "separate": true, "text": "The drone took 17. Its hit landed for 7: the shield soaked 3, Strike Unit took 4."},
		# Phase 2 — turn 2
		{"targets": ["roll_button"], "text": "Roll again.", "advance": "roll_pressed"},
		{"targets": [], "hide_coach": true, "advance": "rolled"},
		# Primer-showcase explainer (Kev 2026-07-21): on a fresh profile the
		# CLEANSE tip just displayed — the drill's ONE live primer (Splice
		# Medic's Infusion sights it; battle_scene emits "rolled" only after
		# the drain, so the modals never overlap). The copy stands alone on a
		# replay where the tip is already seen and nothing displayed.
		{"targets": ["ability:medic"], "text": "When a mechanic you've never seen appears, a one-time tip points it out - like the Cleanse on Splice Medic's roll. The Help menu keeps every keyword whenever you need a reminder."},
		{"targets": ["protocol_value"], "text": "You banked 1 Protocol - income ticks +1 every turn, caps at 10. That's exactly enough for a Nudge."},
		# Nudge stays TWO beats (Kev fix #3): button beat advances the instant the
		# press arms the pick; the die beat gates on the applied nudge. The pick
		# is cancellable (tap-away / Nudge re-press) — cancels are free and the
		# button stays tappable through the pass-through spotlight, so the die
		# beat simply waits for a re-arm + apply (v2.5 ruling: no revert beat).
		{"targets": ["nudge"], "text": "Nudge costs 1 - tap it. (Reroll and Set cost 2 and 4 - they unlock as you bank more.)", "advance": "phase", "phase": "nudge_pick"},
		# v2.5 beat-19 fix: gated on STRIKE's nudge (belt) + protocol_actions
		# ignores wrong-die picks in the drill (braces) — the only Protocol
		# point can never be spent off-script.
		{"targets": ["combat"], "text": "Tap Strike Unit's die - +3 turns an 8 into an 11.", "advance": "nudged", "hero": "combat"},
		# Band jump: the die + its ability pip, separate holes (playtest item 10).
		{"targets": ["die:combat", "ability:combat"], "separate": true, "text": "It jumped a band - Suppression Fire became Rail Strike, 6 damage became 10."},
		# Item SIGNPOST (Prompt-5 delta): informational only, while the Protocol
		# spend is fresh — no grant, no gate, the REAL cost stated. The item
		# button holes fine with an empty loadout (it always renders).
		{"targets": ["item"], "text": "Item slots. You'll collect consumables on your run - using one costs 1 Protocol, same as a Nudge, and doesn't spend a die."},
		{"targets": ["die:medic", "card:medic", "ability:medic"], "separate": true, "text": "Splice Medic rolled a targeted heal. Tap the die, then Strike Unit, to restore life.", "advance": "assigned", "hero": "medic"},
		{"targets": [], "fullscreen": true, "coach_center": true, "text": "Assign the rest - Rail Strike and Overdrive at the drone. You pick the firing order; later, order wins fights.", "advance": "phase", "phase": "ready_to_end"},
		{"targets": ["roll_button"], "text": "End the turn.", "advance": "won"},
		{"targets": [], "text": "That's the loop. The Help menu holds the full encyclopedia whenever you need it.", "title": "DRILL COMPLETE", "advance": "tap_finish"},
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
	# Two-stage assign spotlight (playtest items 5/6 — "selecting in the dark"):
	# when the GATED hero starts targeting, the hole MOVES to the legal
	# target(s) so the player never taps into dimmed screen. Reuses the
	# existing targeting_started event + set_holes; the coach text stays.
	if event == &"targeting_started" and mode == "assigned" \
			and _current().has("hero") and str(payload.get("hero", "")) == str(_current()["hero"]):
		_retarget_spotlight_to_legal()
	if mode == "tap" or mode == "tap_finish":
		return
	if String(event) != mode:
		return
	# Optional payload predicate (e.g. phase == ready_to_end).
	if _current().has("phase") and str(payload.get("phase", "")) != str(_current()["phase"]):
		return
	# Optional hero predicate (v2): the step waits for the event to land on a
	# SPECIFIC hero (unit id in the payload — "assigned" for combat/medic/
	# engineer). Same pattern as the phase predicate; an off-script hero's
	# event simply doesn't advance the step (never a dead end — the scripted
	# hero stays available).
	if _current().has("hero") and str(payload.get("hero", "")) != str(_current()["hero"]):
		return
	_next()


# Drop the dim to the whole-screen frame (no dimming, just the edge border), keeping the coachmark —
# used while a roll / turn resolution animates so the player can watch the board play out.
func _reveal_whole_screen() -> void:
	if _spot != null:
		_spot.set_holes([_spot.fullscreen_hole()])


# Stage 2 of an assign beat: move the holes to the scene's CURRENT legal
# targets — enemy card + its die for hostile picks, the legal ally card(s)
# for friendly picks. Falls back to the whole screen if nothing resolves (the
# player must never be locked out).
func _retarget_spotlight_to_legal() -> void:
	if _spot == null:
		return
	var side: String = str(_scene.get("legal_target_side"))
	var ids: Variant = _scene.get("legal_target_ids")
	if not (ids is Array) or (ids as Array).is_empty():
		return
	var holes: Array = []
	for id_variant in ids:
		var target_id: String = str(id_variant)
		if side == "enemy" or side == "any":
			var card_rect: Rect2 = _enemy_card_rect(target_id)
			if card_rect.size != Vector2.ZERO:
				holes.append(card_rect.grow(PAD))
			var die_rect: Rect2 = _die_rect("enemy", target_id)
			if die_rect.size != Vector2.ZERO:
				holes.append(die_rect.grow(PAD))
		if side == "hero" or side == "dead_hero" or side == "any":
			var hero_rect: Rect2 = _hero_card_rect(target_id)
			if hero_rect.size != Vector2.ZERO:
				holes.append(hero_rect.grow(PAD))
	if holes.is_empty():
		holes = [_fullscreen_hole()]
	_spot.set_holes(holes)
	_publish_debug_state(_current(), holes, "retarget")


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


# Persists tutorial_done, clears the run, and exits to wherever the drill was
# entered from: the first-run choice (RUN TUTORIAL on the menu overlay, which
# sets the continue flag) continues into the squad picker — no bounce to the
# menu; manual replays (splash TUTORIAL button / Help) return to the main menu
# as before. (SKIP on the overlay sets the same flag without ever entering.)
func _finish() -> void:
	if _scene != null and _scene.has_signal("tutorial_event") and _scene.tutorial_event.is_connected(_on_tutorial_event):
		_scene.tutorial_event.disconnect(_on_tutorial_event)
	var continue_to_play: bool = false
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null:
		continue_to_play = bool(gs.get("tutorial_continue_to_play"))
		gs.call("reset_run")  # clears tutorial_mode + the continue flag
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager != null:
		save_manager.call("mark_tutorial_done")
	var sm: Node = get_node_or_null("/root/SceneManager")
	print("[Tutorial] finished -> %s" % ("squad_picker" if continue_to_play else "main_menu"))
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__tut_done = '%s'" % ("squad_picker" if continue_to_play else "main_menu"), true)
	queue_free()
	if sm != null:
		sm.call("go_to_unit_select" if continue_to_play else "go_to_main_menu")


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
		_publish_debug_state(step, [])
		return
	var holes: Array = _compute_holes(step)
	# Never place against a not-yet-valid rect (playtest item 9): a step that
	# follows a resolution animation can run before its target has laid out —
	# the coach then placed off a fallback rect for a frame. Wait (bounded)
	# for a real hole; a step change while waiting abandons this pass.
	if holes.is_empty() and not (step.get("targets", []) as Array).is_empty():
		var waiting_step: int = _step
		for _i in range(LAYOUT_RETRY_FRAMES):
			if not is_inside_tree() or get_tree() == null:
				return
			await get_tree().process_frame
			if _step != waiting_step:
				return
			holes = _compute_holes(step)
			if not holes.is_empty():
				break
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
	_publish_debug_state(step, holes)


# ── Diagnostics (console) + web test seam ──────────────────────────────────────
# One console line per beat (and per stage-2 retarget) — cheap, tutorial-only,
# and it is what makes the drill verifiable from a browser console. On web it
# additionally publishes the live geometry (hole rects, per-hero die rects, the
# enemy cards, the Nudge button) to `window.__tut` so an automated page-side
# driver can tap the REAL targets. Read-only data out; no input path in.
func _publish_debug_state(step: Dictionary, holes: Array, stage: String = "step") -> void:
	print("[Tutorial] step %d/%d advance=%s %s holes=%d" % [
		_step + 1, _steps.size(), _advance_mode(), stage, holes.size()])
	if not OS.has_feature("web"):
		return
	var hole_list: Array = []
	for hole_variant in holes:
		var r: Rect2 = hole_variant
		hole_list.append([r.position.x, r.position.y, r.size.x, r.size.y])
	var dice: Dictionary = {}
	var views: Variant = _scene.get("hero_card_views")
	if views is Array:
		for view_variant in views:
			var view: Dictionary = view_variant
			var state: Dictionary = view.get("state", {})
			var unit: Object = state.get("unit", null) as Object
			if unit == null:
				continue
			var die_rect: Rect2 = _die_rect("hero", str(state.get("id", "")))
			if die_rect.size != Vector2.ZERO:
				dice[str(unit.id)] = [die_rect.position.x, die_rect.position.y, die_rect.size.x, die_rect.size.y]
	var enemies: Array = []
	var enemy_views: Variant = _scene.get("enemy_card_views")
	if enemy_views is Array:
		for view_variant in enemy_views:
			var rect: Rect2 = _node_rect((view_variant as Dictionary).get("card", null))
			if rect.size != Vector2.ZERO:
				enemies.append([rect.position.x, rect.position.y, rect.size.x, rect.size.y])
	var nudge_rect: Rect2 = _node_rect(_protocol_button("nudge_button"))
	var data: Dictionary = {
		"step": _step,
		"advance": _advance_mode(),
		"stage": stage,
		"targets": step.get("targets", []),
		"holes": hole_list,
		"dice": dice,
		"enemies": enemies,
		"nudge": [nudge_rect.position.x, nudge_rect.position.y, nudge_rect.size.x, nudge_rect.size.y] if nudge_rect.size != Vector2.ZERO else [],
		"phase": str(_scene.call("phase_name", _scene.get("turn_phase"))) if _scene.has_method("phase_name") else "",
		"active": str(_scene.get("active_targeting_hero_id")),
		"pending": _scene.get("pending_manual_target_ids"),
		"state_ids": _hero_state_ids(),
	}
	JavaScriptBridge.eval("window.__tut = %s" % JSON.stringify(data), true)


func _hero_state_ids() -> Dictionary:
	var out: Dictionary = {}
	var views: Variant = _scene.get("hero_card_views")
	if views is Array:
		for view_variant in views:
			var state: Dictionary = (view_variant as Dictionary).get("state", {})
			var unit: Object = state.get("unit", null) as Object
			if unit != null:
				out[str(unit.id)] = str(state.get("id", ""))
	return out


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
	# "die:<unit_id>" spotlights just that hero's rolled die in the tray (v2 —
	# the assign beats point at the die the copy names). Falls back to the
	# whole unit so the spotlight always resolves a hole.
	if key.begins_with("die:"):
		return _hero_die_rect_for_unit(key.substr(4))
	# "card:<unit_id>" spotlights just that hero's card (stage 1 of the
	# two-stage assign spotlight pairs it with the die as separate holes).
	if key.begins_with("card:"):
		return _hero_card_rect_for_unit(key.substr(5))
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
		# Telegraph beat (playtest item 8): the FIRST enemy's card / ability
		# pip / die as three separate keys — not the whole readout strip.
		"enemy_card":
			return _first_enemy_part_rect("card")
		"enemy_pip":
			return _first_enemy_part_rect("readout")
		"enemy_die":
			return _first_enemy_die_rect()
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
		"item":
			# The consumable slot — the footer ITEM button (v2 Shock Charge beat).
			return _node_rect(_protocol_button("item_button"))
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


# Just one hero's rolled die in the tray (v2 assign beats). Fall back to the
# whole unit (card + pips + die) if the die hasn't laid out yet.
func _hero_die_rect_for_unit(unit_id: String) -> Rect2:
	var views: Variant = _scene.get("hero_card_views")
	if views is Array:
		for view_variant in views:
			var view: Dictionary = view_variant
			var state: Dictionary = view.get("state", {})
			var unit: Object = state.get("unit", null) as Object
			if unit != null and str(unit.id) == unit_id:
				var die_rect: Rect2 = _hero_die_rect(str(state.get("id", "")))
				return die_rect if die_rect.size != Vector2.ZERO else _hero_unit_rect(unit_id)
	return _hero_unit_rect(unit_id)


# Just one hero's CARD (no readout, no die) — stage 1 of the two-stage assign
# spotlight. Falls back to the whole unit if the card hasn't laid out.
func _hero_card_rect_for_unit(unit_id: String) -> Rect2:
	var views: Variant = _scene.get("hero_card_views")
	if views is Array:
		for view_variant in views:
			var view: Dictionary = view_variant
			var state: Dictionary = view.get("state", {})
			var unit: Object = state.get("unit", null) as Object
			if unit != null and str(unit.id) == unit_id:
				var card_rect: Rect2 = _node_rect(view.get("card", null))
				return card_rect if card_rect.size != Vector2.ZERO else _hero_unit_rect(unit_id)
	return _hero_unit_rect(unit_id)


# Hero card rect by STATE id (stage-2 retarget of friendly picks).
func _hero_card_rect(state_id: String) -> Rect2:
	var views: Variant = _scene.get("hero_card_views")
	if not (views is Array):
		return Rect2()
	for view_variant in views:
		var view: Dictionary = view_variant
		var state: Dictionary = view.get("state", {})
		if str(state.get("id", "")) == state_id:
			return _node_rect(view.get("card", null))
	return Rect2()


# Enemy card rect by STATE id (stage-2 retarget of hostile picks).
func _enemy_card_rect(state_id: String) -> Rect2:
	var views: Variant = _scene.get("enemy_card_views")
	if not (views is Array):
		return Rect2()
	for view_variant in views:
		var view: Dictionary = view_variant
		var state: Dictionary = view.get("state", {})
		if str(state.get("id", "")) == state_id:
			return _node_rect(view.get("card", null))
	return Rect2()


# The FIRST enemy's card or readout node rect (telegraph beat); falls back to
# the merged enemy strip so the spotlight always resolves a hole.
func _first_enemy_part_rect(part: String) -> Rect2:
	var views: Variant = _scene.get("enemy_card_views")
	if views is Array and not (views as Array).is_empty():
		var view: Dictionary = (views as Array)[0]
		var rect: Rect2 = _node_rect(view.get(part, null))
		if rect.size != Vector2.ZERO:
			return rect
	return _merge_nonempty(_node_rect(_scene.get("enemy_cards")), _node_rect(_scene.get("enemy_readouts")))


func _first_enemy_die_rect() -> Rect2:
	var views: Variant = _scene.get("enemy_card_views")
	if views is Array and not (views as Array).is_empty():
		var view: Dictionary = (views as Array)[0]
		var state: Dictionary = view.get("state", {})
		var rect: Rect2 = _die_rect("enemy", str(state.get("id", "")))
		if rect.size != Vector2.ZERO:
			return rect
	return _node_rect(_scene.get("enemy_dice_row"))


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


# Global rect of the rendered die for one state, around its tray anchor point.
func _die_rect(side: String, state_id: String) -> Rect2:
	var layout: Object = _layout_node()
	if layout == null or state_id == "":
		return Rect2()
	var cz: Rect2 = layout.get_combat_zone_rect()
	if cz.size.x <= 2.0 or cz.size.y <= 2.0:
		return Rect2()
	var pt: Vector2 = layout.get_dice_anchor_point(side, state_id)
	if pt == Vector2.INF:
		return Rect2()
	var g: Vector2 = pt + cz.position
	return Rect2(g - Vector2(DIE_HALF_PX, DIE_HALF_PX), Vector2(DIE_HALF_PX * 2.0, DIE_HALF_PX * 2.0))


func _hero_die_rect(state_id: String) -> Rect2:
	return _die_rect("hero", state_id)


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
	# All dim/ring/coachmark visuals live in the shared SpotlightLayer. No
	# in-drill Skip button (the playtest deletion STANDS — it occluded
	# coachmarks): skipping happens on the main menu's first-run choice
	# overlay before entry (Kev 2026-07-21). Mid-drill abandonment remains via
	# the header's back button (return-to-menu → reset_run(), which clears
	# tutorial_mode and the continue flag — tutorial_done stays unset, so the
	# next BEGIN asks again).
	_spot = SpotlightLayerScript.new(LAYER)
	_spot.tapped.connect(_on_spot_tapped)
	add_child(_spot)
