# Keyword primers — one-shot micro-tutorials for first-sighted mechanics
# (docs/PRIMERS.md is the authoring guide; data lives in data/raw/primers.data.json).
#
# Architecture: its own CanvasLayer (same 110 band as the tutorial — above the
# battle scene + header, BELOW InspectPopup 130 / HelpMenu 135; the two never
# coexist because primers are suppressed during the tutorial). Reuses the
# shared SpotlightLayer for dim + ring + coachmark. This manager only OBSERVES
# — it never touches combat state, so it cannot move a sim number.
#
# BEHAVIOR CONTRACT (keep in sync with docs/PRIMERS.md):
# - Triggers queue candidates; display happens at safe moments only: between
#   battle-feedback action groups (flush_at_group_boundary, awaited by
#   BattleFeedback) or during an idle player phase (flush_player_phase).
# - Maximum ONE primer per turn. Additional first sightings the same turn are
#   NOT marked seen — they fire on their next natural occurrence.
# - Priority breaks same-moment ties (higher number wins; stable order after).
# - Suppressed entirely during the scripted tutorial, headless mode, and auto
#   battle. requires_feature entries skip silently when the feature is absent.
# - FAILURE SAFETY: a resolver returning nothing, a missing node, or a dead
#   layer skips the primer WITHOUT marking it seen and never blocks the battle.
# - Marked seen (SaveManager.mark_primer_seen) only after the primer displayed
#   and the player dismissed it.
class_name KeywordPrimer
extends CanvasLayer

const LAYER := 110
const PAD := 14.0
const DIE_HALF_PX := 84.0

const SpotlightLayerScript := preload("res://scripts/ui/spotlight_layer.gd")

# Feedback-stream event type → [trigger_type, param]. New mechanics that ship
# through the event stream extend this map (or use the signal_hook seam below).
const EVENT_TRIGGERS := {
	"jam": ["die_status_applied", "jam"],
	"freeze": ["die_status_applied", "freeze"],
	"rewrite": ["die_status_applied", "rewrite"],
	"hijack_primed": ["die_status_applied", "hijack"],
	"mark": ["status_applied", "mark"],
	"ward": ["status_applied", "firewall"],
	"cloak": ["status_applied", "cloak"],
	"taunt": ["status_applied", "taunt"],
	"burn": ["status_applied", "burn"],
	"spike_up": ["status_applied", "spike"],
	"accrete": ["status_applied", "accrete"],
	"chain": ["attack_keyword_resolved", "chain"],
	"detonate": ["attack_keyword_resolved", "detonate"],
	"execute": ["attack_keyword_resolved", "execute"],
	"breach": ["attack_keyword_resolved", "breach"],
	"pierce": ["attack_keyword_resolved", "pierce"],
	"leech": ["attack_keyword_resolved", "leech"],
	"siphon": ["attack_keyword_resolved", "siphon"],
	"revive": ["attack_keyword_resolved", "revive"],
}

# Features that exist in this build — requires_feature entries whose feature is
# absent are skipped silently (the entry ships before the mechanic does).
const PRESENT_FEATURES := {
	"targeting_personalities": true,
}

# Test seams (primer_smoke_test.gd only): force the manager active under
# headless, and skip the await-tap so the scripted test can drive dismissal.
var debug_force_active: bool = false
var debug_auto_dismiss: bool = false
var debug_show_count: int = 0

var _scene: Node = null
var _spot = null  # SpotlightLayer
var _shown_this_turn: bool = false
var _pending: Array = []          # same-moment candidates: [{primer, context}]
var _fired_params: Dictionary = {}  # "type/param" seen this battle (cheap dedupe)
var _by_trigger: Dictionary = {}  # "type/param" -> primer entry (built once)

# TARGET RESOLVERS — target string → Callable(context) -> Rect2 (screen space;
# Rect2() = unresolvable, skip silently). New target types register ONE entry
# here; context carries {side, target_id, param} from the trigger site.
var _target_resolvers: Dictionary = {}


func setup(scene: Node) -> void:
	_scene = scene
	layer = LAYER
	_spot = SpotlightLayerScript.new(LAYER)
	add_child(_spot)
	_spot.dismiss()
	_target_resolvers = {
		"die": _resolve_die_rect,
		"unit_card": _resolve_unit_card_rect,
		"ability_pip": _resolve_ability_pip_rect,
		"footer_button": _resolve_footer_button_rect,
		"popup_line": _resolve_popup_line_rect,
	}
	for entry_variant in DataManager.get_primers():
		var entry: Dictionary = entry_variant
		var trig: Dictionary = entry.get("trigger", {})
		_by_trigger["%s/%s" % [str(trig.get("type", "")), str(trig.get("param", ""))]] = entry


# ── Suppression ───────────────────────────────────────────────────────────────

func _suppressed() -> bool:
	if _scene == null or not is_instance_valid(_scene):
		return true
	if debug_force_active:
		return false
	if DisplayServer.get_name() == "headless":
		return true
	var gs: Node = get_node_or_null("/root/GameState")
	if gs != null and bool(gs.get("tutorial_mode")):
		return true
	if bool(_scene.get("_auto_battle_running")) or bool(_scene.get("_auto_turn_running")):
		return true
	return false


# ── Trigger intake (queue only — display happens at flush points) ─────────────

func on_turn_started() -> void:
	_shown_this_turn = false
	_pending.clear()


# Combat feedback events (called by BattleFeedback per effect event).
func notice_event(event: Dictionary) -> void:
	var mapping: Variant = EVENT_TRIGGERS.get(str(event.get("type", "")))
	if mapping == null:
		return
	_queue(str(mapping[0]), str(mapping[1]), {
		"side": str(event.get("side", "")),
		"target_id": str(event.get("target_id", "")),
	})


# Protocol actions becoming affordable during a player phase.
func notice_protocol_affordability(protocol_points: int) -> void:
	var costs: Dictionary = {"nudge": 1, "reroll": 2, "set": 3}
	for action_id in costs.keys():
		if protocol_points >= int(costs[action_id]):
			_queue("protocol_action_affordable", str(action_id), {"param": str(action_id)})


# A targeting personality picked a target (enemy intents assigned).
func notice_personality_assigned(personality_name: String, enemy_state_id: String) -> void:
	_queue("personality_assigned", personality_name, {
		"side": "enemy",
		"target_id": enemy_state_id,
	})


# Type-6 seam: future mechanics emit one signal and add one JSON entry — see
# docs/PRIMERS.md. Nothing calls this yet.
func notice_signal_hook(signal_name: String, context: Dictionary = {}) -> void:
	_queue("signal_hook", signal_name, context)


func _queue(trigger_type: String, param: String, context: Dictionary) -> void:
	if _suppressed():
		return
	var key: String = "%s/%s" % [trigger_type, param]
	if _fired_params.has(key):
		return
	var primer: Variant = _by_trigger.get(key)
	if primer == null:
		return
	var entry: Dictionary = primer
	var feature: Variant = entry.get("requires_feature")
	if feature != null and str(feature) != "" and not PRESENT_FEATURES.has(str(feature)):
		return  # feature absent: skip silently, never mark seen
	if SaveManager.is_primer_seen(str(entry.get("id", ""))):
		_fired_params[key] = true
		return
	context = context.duplicate()
	context["param"] = param
	_pending.append({"primer": entry, "context": context, "key": key})


# ── Flush points ──────────────────────────────────────────────────────────────

# Awaited by BattleFeedback BETWEEN action groups — pauses the sequence while
# the coachmark is up, resumes on dismiss.
func flush_at_group_boundary() -> void:
	await _flush()


# Called during idle player phases (protocol/personality sightings).
func flush_player_phase() -> void:
	await _flush()


func _flush() -> void:
	if _pending.is_empty():
		return
	if _shown_this_turn or _suppressed():
		# Not marked seen — they refire on their next natural occurrence.
		_pending.clear()
		return
	# Priority breaks same-moment ties (higher first; stable for equals).
	var candidates: Array = _pending.duplicate()
	_pending.clear()
	candidates.sort_custom(func(a, b) -> bool:
		return int((a["primer"] as Dictionary).get("priority", 0)) > int((b["primer"] as Dictionary).get("priority", 0)))
	for candidate_variant in candidates:
		var candidate: Dictionary = candidate_variant
		if await _try_show(candidate):
			_shown_this_turn = true
			return


# The guarded fire path: every failure skips silently (returns false, primer
# NOT marked seen, battle never blocked).
func _try_show(candidate: Dictionary) -> bool:
	var entry: Dictionary = candidate.get("primer", {})
	var context: Dictionary = candidate.get("context", {})
	if _spot == null or not is_instance_valid(_spot):
		return false
	var resolver: Variant = _target_resolvers.get(str(entry.get("target", "")))
	if resolver == null:
		return false
	var rect: Rect2 = (resolver as Callable).call(context)
	if rect.size == Vector2.ZERO:
		return false
	var text: String = str(entry.get("text", ""))
	if text == "":
		return false
	AudioManager.play_select()
	await _spot.spotlight([rect.grow(PAD)], text, SpotlightLayerScript.CoachAnchor.AUTO, {
		"hint": "tap to continue ▸",
		"interactive": true,
	})
	if not debug_auto_dismiss:
		await _spot.tapped
	_spot.dismiss()
	debug_show_count += 1
	_fired_params[str(candidate.get("key", ""))] = true
	SaveManager.mark_primer_seen(str(entry.get("id", "")))
	return true


# ── Target resolvers ──────────────────────────────────────────────────────────
# Each returns a screen-space Rect2, or Rect2() to skip silently.

# The affected die's projected rect in the 3D tray.
func _resolve_die_rect(context: Dictionary) -> Rect2:
	var tray: Variant = _scene.get("dice_tray_3d")
	if tray == null or not is_instance_valid(tray):
		return Rect2()
	var r: Rect2 = tray.get_die_screen_bounds(str(context.get("side", "")), str(context.get("target_id", "")))
	if r.size.x >= 2.0 and r.size.y >= 2.0:
		return r
	# Fallback: build a fixed-size rect around the die's screen position.
	var p: Vector2 = tray.get_die_screen_position(str(context.get("side", "")), str(context.get("target_id", "")))
	if p == Vector2.INF or p == Vector2.ZERO:
		return Rect2()
	return Rect2(p - Vector2(DIE_HALF_PX, DIE_HALF_PX), Vector2(DIE_HALF_PX * 2.0, DIE_HALF_PX * 2.0))


# The affected unit's card.
func _resolve_unit_card_rect(context: Dictionary) -> Rect2:
	var views: Variant = _scene.get("hero_card_views") if str(context.get("side", "")) == "hero" else _scene.get("enemy_card_views")
	if not (views is Array):
		return Rect2()
	for view_variant in views:
		var view: Dictionary = view_variant
		var state: Dictionary = view.get("state", {})
		if str(state.get("id", "")) != str(context.get("target_id", "")):
			continue
		return _control_rect(view.get("card", null))
	return Rect2()


# The resolving unit's effect-pip readout (falls back to its card).
func _resolve_ability_pip_rect(context: Dictionary) -> Rect2:
	var views: Variant = _scene.get("hero_card_views") if str(context.get("side", "")) == "hero" else _scene.get("enemy_card_views")
	if not (views is Array):
		return Rect2()
	for view_variant in views:
		var view: Dictionary = view_variant
		var state: Dictionary = view.get("state", {})
		if str(state.get("id", "")) != str(context.get("target_id", "")):
			continue
		var r: Rect2 = _control_rect(view.get("readout", null))
		return r if r.size != Vector2.ZERO else _control_rect(view.get("card", null))
	return Rect2()


# The protocol action button (param: nudge / reroll / set).
func _resolve_footer_button_rect(context: Dictionary) -> Rect2:
	match str(context.get("param", "")):
		"nudge":
			return _control_rect(_scene.get("_nudge_button"))
		"reroll":
			return _control_rect(_scene.get("protocol_spend_button"))
		"set":
			return _control_rect(_scene.get("_set_button"))
	return Rect2()


# The inspect popup's personality row — only resolvable while the popup is open
# AND exposes get_personality_row_rect(); otherwise skip silently. (No authored
# primer targets this yet; it exists so a popup-anchored primer is data-only.)
func _resolve_popup_line_rect(_context: Dictionary) -> Rect2:
	var popup: Node = get_node_or_null("/root/InspectPopup")
	if popup == null or not popup.has_method("get_personality_row_rect"):
		return Rect2()
	return popup.call("get_personality_row_rect")


func _control_rect(node: Variant) -> Rect2:
	var control: Control = node as Control
	if control == null or not is_instance_valid(control) or not control.is_inside_tree() or not control.visible:
		return Rect2()
	var r: Rect2 = control.get_global_rect()
	if r.size.x < 2.0 or r.size.y < 2.0:
		return Rect2()
	return r
