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
	# An enemy shield-wipe IS Breach semantics (the pips render it as BR) — the
	# first wipe teaches the same rule.
	"wipe_shields": ["attack_keyword_resolved", "breach"],
	"pierce": ["attack_keyword_resolved", "pierce"],
	"leech": ["attack_keyword_resolved", "leech"],
	"siphon": ["attack_keyword_resolved", "siphon"],
	"revive": ["attack_keyword_resolved", "revive"],
	"rampage": ["attack_keyword_resolved", "rampage"],
	"pack_bonus": ["attack_keyword_resolved", "pack_bonus"],
	"summon": ["attack_keyword_resolved", "summon"],
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
	# Player opt-out (help → settings → tutorials, Kev 2026-07-10).
	if not bool(SaveManager.get_setting("ability_primers_enabled", true)):
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
		# Some events (summon) carry only a display name — the card resolver
		# falls back to it when no id matches.
		"target_name": str(event.get("target_name", "")),
	})


# Protocol actions becoming affordable during a player phase. (No loaded
# entries since 2026-07-10 — the tutorial teaches nudge/reroll/set — but the
# seam stays for future protocol mechanics.)
func notice_protocol_affordability(protocol_points: int) -> void:
	# Costs mirror battle_engine.gd (NUDGE 1, REROLL 2, SET_DIE_COST 4). Keep in sync.
	var costs: Dictionary = {"nudge": 1, "reroll": 2, "set": 4}
	for action_id in costs.keys():
		if protocol_points >= int(costs[action_id]):
			_queue("protocol_action_affordable", str(action_id), {"param": str(action_id)})


# NEVER highlight these three — they are self-evident and the tutorial covers
# them. This is the ONE exclusion list (Bug-2, Kev 2026-07-12): every OTHER
# not-yet-seen icon on a revealed roll fires its primer. Do NOT "fix" damage/
# heal/shield back in later — a pip whose icons are all exempt must never
# highlight. (Keys are PixelUI pip-icon keys, i.e. what pip_key_for_effect
# returns — "dmg" has already normalized to "damage" by then.)
const HIGHLIGHT_EXEMPT_ICONS: Array[String] = ["damage", "heal", "shield"]

# Pip-icon key → the primer trigger it teaches (Bug-2 rework, Kev 2026-07-12):
# roll sightings key on the ICONS the readout actually renders, not on raw JSON
# field names — the old RAW_FIELD_TRIGGERS map structurally couldn't see icons
# that aren't raw fields (the hits-all marker, target-lowest, ±roll). Keyword
# icons route to their existing primer keys so the seen-ledger and the
# event-stream fallback stay unified; marker/scope icons get their own
# icon_first_seen entries. Both roll icons teach ONE lesson (same gold d20).
# An icon with no loaded primer entry skips silently (the _queue null path) —
# the mechanism is ready the moment its JSON entry is authored.
const ICON_TRIGGERS := {
	"jam": ["die_status_applied", "jam"],
	"freeze": ["die_status_applied", "freeze"],
	"rewrite": ["die_status_applied", "rewrite"],
	"hijack": ["die_status_applied", "hijack"],
	"mark": ["status_applied", "mark"],
	"firewall": ["status_applied", "firewall"],
	"cloak": ["status_applied", "cloak"],
	"taunt": ["status_applied", "taunt"],
	"burn": ["status_applied", "burn"],
	"spike": ["status_applied", "spike"],
	"accrete": ["status_applied", "accrete"],
	"chain": ["attack_keyword_resolved", "chain"],
	"detonate": ["attack_keyword_resolved", "detonate"],
	"execute": ["attack_keyword_resolved", "execute"],
	"breach": ["attack_keyword_resolved", "breach"],
	"pierce": ["attack_keyword_resolved", "pierce"],
	"leech": ["attack_keyword_resolved", "leech"],
	"siphon": ["attack_keyword_resolved", "siphon"],
	"revive": ["attack_keyword_resolved", "revive"],
	"rampage": ["attack_keyword_resolved", "rampage"],
	"pack_bonus": ["attack_keyword_resolved", "pack_bonus"],
	"summon": ["attack_keyword_resolved", "summon"],
	# Non-keyword icons — the icon itself is the lesson.
	"roll_up": ["icon_first_seen", "roll"],
	"roll_down": ["icon_first_seen", "roll"],
	"aoe": ["icon_first_seen", "aoe"],
	"target_lowest": ["icon_first_seen", "target_lowest"],
	"self": ["icon_first_seen", "self"],
	"protocol": ["icon_first_seen", "protocol"],
}

# scope string (EffectPip effect "scope") → the marker icon build_group renders.
const SCOPE_MARKER_ICONS := {"all": "aoe", "self": "self", "lowest": "target_lowest"}


# A revealed roll chose this ability — resolve the icons its pip readout
# actually renders (kind icon + scope marker per effect, both sides) and queue
# a primer for every not-yet-seen NON-EXEMPT icon, anchored to the rolling
# unit's pip readout. Kev 2026-07-10: primes BEFORE the player commits; the
# event-stream triggers stay as the fallback for effects that never surface on
# a readout. The one-per-turn rule still applies at flush.
func notice_rolled_ability(raw: Dictionary, side: String, unit_id: String) -> void:
	if raw.is_empty():
		return
	var context: Dictionary = {
		"side": side,
		"target_id": unit_id,
		# Bug-2: the roll sighting highlights the PIP the icon lives in, not the
		# entry's authored anchor (which serves the mid-resolution event path).
		"target_override": "ability_pip",
	}
	for effect_variant in EffectPip.effects_from_ability_raw(raw, side):
		var effect: Dictionary = effect_variant
		var icons: Array[String] = []
		var kind_icon: String = EffectPip.pip_key_for_effect(effect, side)
		if kind_icon != "":
			icons.append(kind_icon)
		var marker_icon: String = str(SCOPE_MARKER_ICONS.get(str(effect.get("scope", "")), ""))
		if marker_icon != "":
			icons.append(marker_icon)
		# Conditional-modifier suffix icon ("+N❄" etc., Kev ruling 2026-07-12) —
		# an icon the player sees, so its first sighting teaches too.
		var bonus_icon: String = str(effect.get("bonus_icon", ""))
		if bonus_icon != "":
			icons.append(bonus_icon)
		for icon in icons:
			if icon in HIGHLIGHT_EXEMPT_ICONS:
				continue
			var mapping: Variant = ICON_TRIGGERS.get(icon)
			if mapping != null:
				_queue(str(mapping[0]), str(mapping[1]), context)


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
	# Roll sightings anchor to the pip readout (context target_override); the
	# entry's authored target serves the event-stream path.
	var target_key: String = str(context.get("target_override", ""))
	if target_key == "":
		target_key = str(entry.get("target", ""))
	var resolver: Variant = _target_resolvers.get(target_key)
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
	# Name fallback (summon events carry no target_id, only the summoner's name).
	var target_name: String = str(context.get("target_name", ""))
	if target_name != "":
		for view_variant in views:
			var view: Dictionary = view_variant
			var state: Dictionary = view.get("state", {})
			var unit: Resource = state.get("unit", null) as Resource
			if unit != null and str(unit.get("display_name")) == target_name:
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


# The protocol action button (param: nudge / reroll / set). Nudge/Set live in
# the ProtocolActions module (architecture review §1 rec 1); Reroll is the
# scene's %ProtocolSpendButton.
func _resolve_footer_button_rect(context: Dictionary) -> Rect2:
	var protocol: Variant = _scene.get("_protocol")
	match str(context.get("param", "")):
		"nudge":
			return _control_rect(protocol.get("nudge_button") if protocol != null else null)
		"reroll":
			return _control_rect(_scene.get("protocol_spend_button"))
		"set":
			return _control_rect(protocol.get("set_button") if protocol != null else null)
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
