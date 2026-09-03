# Headless regression for two "the game told me something that wasn't true"
# bugs, both reported 2026-09-02:
#
#   PART A — one hit, two numbers. Chain (and its siblings Detonate, Spike and
#   Execute) emitted a NUMBERED marker event and then called _damage_state,
#   which emits the real "damage" event: two red floats on one card for a hit
#   that applied once. Display-only — the damage was never double-counted — but
#   the marker also carried the PRE-mitigation figure, and a chain jump into a
#   firewall floated its number before the ward cancelled the packet.
#
#   PART B — an announcement with nothing behind it. Surge Revive played its
#   name slam and the overload celebration with no downed ally to revive. The
#   ANNOUNCE is suppressed now; the beat still resolves, so the 20-face riders
#   (Overload Capacitor, the lifetime-20s stat) still pay out.
#
# Run: godot --headless --path . -s scripts/debug/feedback_honesty_test.gd
extends SceneTree

# Surge Revive lives on the medic's FIRST EVOLUTION 20 band, which a fresh run
# has not unlocked, so this part builds the ability directly on a synthetic
# unit (the ability-audit pattern) instead of booting a battle. What is under
# test is resolve_round's announce decision, not the medic's progression.
# NOTE ON LOADING: every combat class is pulled in with load() at RUN time, not
# named directly. A `-s` SceneTree script is compiled BEFORE the autoloads
# exist, so a bare `CombatManager` reference makes GDScript compile
# combat_manager.gd too early, its `DataManager` / `GameState` identifiers fail
# to resolve, and every later `.new()` silently returns nothing — which reads as
# a PASS. _part_b_announce guards on that explicitly.
const ROLL := 10
const REVIVE_RAW := {"revive": true, "revivePct": 70, "healTgt": true, "dmg": 0, "heal": 0}
const STRIKE_RAW := {"dmg": 9}

var _errors: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[FEEDBACK_HONESTY] Starting float-duplication + empty-announce regression")
	_part_a_floats()
	_part_b_announce()
	_finish()


# ── PART A: the float vocabulary ─────────────────────────────────────────────
func _part_a_floats() -> void:
	var feedback: Node = load("res://scripts/battle/battle_feedback.gd").new()
	# The events that ARE the damage keep their number.
	for owned in ["damage", "burn"]:
		var text: String = str(feedback.call("_build_floating_text", owned, 7))
		_expect(text == "-7", "'%s' still floats its own number (got '%s')" % [owned, text])
	_expect(str(feedback.call("_build_floating_text", "heal", 5)) == "+5", "'heal' still floats +5")
	# The marker events that are FOLLOWED by a damage event must stay silent —
	# the same rule leech/pierce/accrete/revive already followed.
	for paired in ["chain", "detonate", "spike", "execute"]:
		var text2: String = str(feedback.call("_build_floating_text", paired, 7))
		_expect(text2 == "",
			"'%s' no longer floats a second number for the hit _damage_state already reports (got '%s')" % [paired, text2])
	feedback.free()


# ── PART B: no legal target, no announcement ─────────────────────────────────
func _part_b_announce() -> void:
	# Case 1: the whole squad is up. A pure revive has nothing to do, so it must
	# not announce — no action_start means no banner, no name slam, no overload
	# celebration.
	var quiet: Object = _new_manager()
	if quiet == null:
		_errors.append("could not construct a CombatManager - part B measured NOTHING")
		return
	var reviver: Object = _make_unit("audit_medic", "Audit Medic", "Surge Revive", REVIVE_RAW)
	var ally: Object = _make_unit("audit_ally", "Audit Ally", "Strike", STRIKE_RAW)
	quiet.call("setup_battle", [reviver, ally], [_make_enemy("audit_enemy", "Audit Enemy")])
	var quiet_result: Dictionary = quiet.call("resolve_round", {"audit_medic": ROLL}, {}, _new_dice())
	if quiet_result.is_empty():
		_errors.append("resolve_round returned nothing - part B measured NOTHING")
		return
	_expect(not _has_action_start(quiet_result, "audit_medic"),
		"no downed ally: the revive does NOT announce (no action_start emitted)")
	_expect(not _has_event(quiet_result, "revive"),
		"no downed ally: nothing is revived either (the beat is a true no-op)")

	# Case 2: an ally is down. The same ability announces AND fires.
	var live: Object = _new_manager()
	live.call("setup_battle", [
		_make_unit("audit_medic", "Audit Medic", "Surge Revive", REVIVE_RAW),
		_make_unit("audit_ally", "Audit Ally", "Strike", STRIKE_RAW),
	], [_make_enemy("audit_enemy", "Audit Enemy")])
	for state_variant in live.call("get_hero_states"):
		var state: Dictionary = state_variant
		if str(state["id"]) == "audit_ally":
			state["dead"] = true
			state["current_hp"] = 0
	var live_result: Dictionary = live.call("resolve_round", {"audit_medic": ROLL}, {}, _new_dice())
	_expect(_has_action_start(live_result, "audit_medic"),
		"downed ally present: the revive DOES announce (action_start emitted)")
	_expect(_has_event(live_result, "revive"),
		"downed ally present: the revive actually fires (revive event emitted)")

	# An ability that still DOES something never goes silent, even when it also
	# carries a revive that finds no body — the suppression is fail-safe.
	var mixed: Object = _new_manager()
	var mixed_raw: Dictionary = REVIVE_RAW.duplicate(true)
	mixed_raw["dmg"] = 9
	mixed.call("setup_battle", [
		_make_unit("audit_medic", "Audit Medic", "Revive Strike", mixed_raw),
		_make_unit("audit_ally", "Audit Ally", "Strike", STRIKE_RAW),
	], [_make_enemy("audit_enemy", "Audit Enemy")])
	var mixed_result: Dictionary = mixed.call("resolve_round", {"audit_medic": ROLL}, {}, _new_dice())
	_expect(_has_action_start(mixed_result, "audit_medic"),
		"a revive that still carries damage keeps announcing (fail-safe)")


func _new_manager() -> Object:
	return load("res://scripts/battle/combat_manager.gd").new()


func _new_dice() -> Object:
	return load("res://scripts/battle/dice_manager.gd").new()


func _make_unit(id: String, display_name: String, ability_name: String, raw: Dictionary) -> Object:
	var unit: Object = load("res://scripts/resources/unit_data.gd").new()
	unit.id = id
	unit.display_name = display_name
	unit.max_hp = 100
	var bands: Array[Dictionary] = [_make_ability_entry(ability_name, raw)]
	unit.dice_ranges = bands
	return unit


func _make_enemy(id: String, display_name: String) -> Object:
	var enemy: Object = load("res://scripts/resources/enemy_data.gd").new()
	enemy.id = id
	enemy.display_name = display_name
	enemy.max_hp = 100
	var bands: Array[Dictionary] = [_make_ability_entry("Noop", {})]
	enemy.dice_ranges = bands
	return enemy


func _make_ability_entry(ability_name: String, raw: Dictionary) -> Dictionary:
	return {
		"min": 1,
		"max": 20,
		"zone": "audit",
		"ability_name": ability_name,
		"description": "",
		"raw": raw.duplicate(true),
	}


func _has_action_start(result: Dictionary, actor_id: String) -> bool:
	for event_variant in result.get("events", []):
		var event: Dictionary = event_variant
		if str(event.get("type", "")) == "action_start" and str(event.get("actor_id", "")) == actor_id:
			return true
	return false


func _has_event(result: Dictionary, event_type: String) -> bool:
	for event_variant in result.get("events", []):
		if str((event_variant as Dictionary).get("type", "")) == event_type:
			return true
	return false


func _expect(cond: bool, label: String) -> void:
	if cond:
		print("PASS [feedback-honesty] %s" % label)
	else:
		_errors.append(label)


func _finish() -> void:
	if _errors.is_empty():
		print("[FEEDBACK_HONESTY] PASS")
	else:
		for e in _errors:
			print("[FEEDBACK_HONESTY] FAIL: " + e)
	quit(0 if _errors.is_empty() else 1)
