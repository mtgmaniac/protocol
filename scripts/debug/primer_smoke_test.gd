# Keyword primer smoke test (headless): exercises at least one primer per
# trigger type through the real manager pipeline (queue → flush → display →
# persist), asserting each fires ONCE, persists as seen, and never refires —
# plus the one-per-turn gate, priority ties, failure safety, and the
# grandfather clause. Uses the manager's documented test seams
# (debug_force_active / debug_auto_dismiss); display runs through the real
# SpotlightLayer (headless Godot renders Control trees fine).
# Run: godot --headless --path . -s scripts/debug/primer_smoke_test.gd
# Exit 0 = pass, 1 = fail.
extends SceneTree

# Runtime load, not parse-time preload: the manager references autoloads
# (SaveManager/DataManager), which only resolve once the tree is up — the
# documented -s gotcha (docs/TRUTH.md verify notes).
var KeywordPrimerScript: GDScript = null

var _errors: Array[String] = []


func _initialize() -> void:
	await process_frame
	KeywordPrimerScript = load("res://scripts/ui/keyword_primer.gd")
	if KeywordPrimerScript == null:
		_errors.append("keyword_primer.gd failed to load/compile")
		for e in _errors:
			push_error("[PRIMER_SMOKE] " + e)
		print("[PRIMER_SMOKE] FAIL — %d error(s)" % _errors.size())
		quit(1)
		return
	await _run()
	if _errors.is_empty():
		print("[PRIMER_SMOKE] PASS — all trigger types fire once, persist, never refire")
		quit(0)
	else:
		for e in _errors:
			push_error("[PRIMER_SMOKE] " + e)
		print("[PRIMER_SMOKE] FAIL — %d error(s)" % _errors.size())
		quit(1)


func _check(cond: bool, label: String) -> void:
	if not cond:
		_errors.append(label)


func _run() -> void:
	# Fresh in-memory profile (headless SaveManager never touches disk).
	var sm: Node = root.get_node("/root/SaveManager")
	sm.call("dev_reset_profile")
	_check((sm.get("data")["onboarding"]["primers_seen"] as Array).is_empty(), "fresh profile starts with no primers seen")

	# Stand-in battle scene: the manager only reads properties defensively.
	var stub_scene := Node.new()
	root.add_child(stub_scene)
	var primer = KeywordPrimerScript.new()
	root.add_child(primer)
	primer.setup(stub_scene)
	primer.debug_force_active = true
	primer.debug_auto_dismiss = true
	# All targets resolve to a fixed rect — resolution failure is tested separately.
	var fixed_rect := func(_context: Dictionary) -> Rect2: return Rect2(10, 10, 200, 120)
	for key in ["die", "unit_card", "ability_pip", "footer_button", "popup_line"]:
		primer._target_resolvers[key] = fixed_rect

	# ── 1) die_status_applied: fires once, persists ─────────────────────────────
	primer.on_turn_started()
	primer.notice_event({"type": "jam", "side": "enemy", "target_id": "e1"})
	await primer.flush_at_group_boundary()
	_check(sm.call("is_primer_seen", "primer_jam"), "die_status_applied (jam) fires and persists")
	_check(primer.debug_show_count == 1, "jam displayed exactly once")

	# One per turn: a second first-sighting the SAME turn shows nothing and is
	# NOT marked seen.
	primer.notice_event({"type": "freeze", "side": "enemy", "target_id": "e1"})
	await primer.flush_at_group_boundary()
	_check(not sm.call("is_primer_seen", "primer_freeze"), "second sighting same turn NOT marked seen")
	_check(primer.debug_show_count == 1, "one primer per turn (no second display)")

	# Next natural occurrence (new turn): it fires.
	primer.on_turn_started()
	primer.notice_event({"type": "freeze", "side": "enemy", "target_id": "e1"})
	await primer.flush_at_group_boundary()
	_check(sm.call("is_primer_seen", "primer_freeze"), "deferred sighting fires on its next occurrence")

	# Never refires: jam again on a fresh turn shows nothing new.
	primer.on_turn_started()
	primer.notice_event({"type": "jam", "side": "enemy", "target_id": "e2"})
	await primer.flush_at_group_boundary()
	_check(primer.debug_show_count == 2, "seen primer never refires")

	# ── 2) status_applied ────────────────────────────────────────────────────────
	primer.on_turn_started()
	primer.notice_event({"type": "mark", "side": "enemy", "target_id": "e1"})
	await primer.flush_at_group_boundary()
	_check(sm.call("is_primer_seen", "primer_mark"), "status_applied (mark) fires and persists")

	# ── 3) attack_keyword_resolved ───────────────────────────────────────────────
	primer.on_turn_started()
	primer.notice_event({"type": "chain", "side": "enemy", "target_id": "e2"})
	await primer.flush_at_group_boundary()
	_check(sm.call("is_primer_seen", "primer_chain"), "attack_keyword_resolved (chain) fires and persists")

	# ── 4) protocol_action_affordable + priority tie-break ──────────────────────
	# All three become affordable at once (same priority 60): exactly ONE shows;
	# the losers are not marked seen and fire on later turns.
	primer.on_turn_started()
	primer.notice_protocol_affordability(3)
	await primer.flush_player_phase()
	var protocol_seen: int = 0
	for pid in ["primer_nudge", "primer_reroll", "primer_set"]:
		if sm.call("is_primer_seen", pid):
			protocol_seen += 1
	_check(protocol_seen == 1, "protocol affordability: exactly one of three ties shows per turn (saw %d)" % protocol_seen)
	primer.on_turn_started()
	primer.notice_protocol_affordability(3)
	await primer.flush_player_phase()
	primer.on_turn_started()
	primer.notice_protocol_affordability(3)
	await primer.flush_player_phase()
	for pid in ["primer_nudge", "primer_reroll", "primer_set"]:
		_check(sm.call("is_primer_seen", pid), "%s eventually fires across turns" % pid)

	# Priority breaks a mixed same-moment tie: freeze-die (55) beats mark-level
	# statuses (40) — exercised with two unseen entries queued the same moment.
	sm.call("dev_reset_primers")
	primer._fired_params.clear()
	primer.on_turn_started()
	primer.notice_event({"type": "cloak", "side": "enemy", "target_id": "e1"})   # priority 40
	primer.notice_event({"type": "rewrite", "side": "enemy", "target_id": "e1"}) # priority 50
	await primer.flush_at_group_boundary()
	_check(sm.call("is_primer_seen", "primer_rewrite"), "higher priority wins the same-moment tie")
	_check(not sm.call("is_primer_seen", "primer_cloak"), "lower priority loser not marked seen")

	# ── 5) rampage + shield-wipe events route to their keyword primers ──────────
	# (Personality primers were cut 2026-07-10 — attack styles aren't tutorialized.)
	primer.on_turn_started()
	primer.notice_event({"type": "rampage", "side": "enemy", "target_id": "e1"})
	await primer.flush_at_group_boundary()
	_check(sm.call("is_primer_seen", "primer_rampage"), "rampage event fires the rampage primer and persists")
	primer.on_turn_started()
	primer.notice_event({"type": "wipe_shields", "side": "hero", "target_id": "h1"})
	await primer.flush_at_group_boundary()
	_check(sm.call("is_primer_seen", "primer_breach"), "wipe_shields event teaches the Breach rule")

	# ── 6) signal_hook seam: unknown hook is a safe no-op ────────────────────────
	primer.on_turn_started()
	primer.notice_signal_hook("haunt_applied", {})
	await primer.flush_at_group_boundary()
	_check(true, "signal_hook with no loaded entry does not crash")

	# ── Failure safety: unresolvable target skips silently, NOT marked seen ─────
	primer._target_resolvers["unit_card"] = func(_context: Dictionary) -> Rect2: return Rect2()
	primer.on_turn_started()
	primer.notice_event({"type": "taunt", "side": "hero", "target_id": "h1"})
	await primer.flush_at_group_boundary()
	_check(not sm.call("is_primer_seen", "primer_taunt"), "failed target resolution: skipped silently, not marked seen")

	# ── Suppression: headless default (seam off) queues nothing ─────────────────
	primer.debug_force_active = false
	primer.on_turn_started()
	primer.notice_event({"type": "detonate", "side": "enemy", "target_id": "e1"})
	await primer.flush_at_group_boundary()
	_check(not sm.call("is_primer_seen", "primer_detonate"), "suppressed (headless): nothing fires, nothing marked seen")
	primer.debug_force_active = true

	# ── Persistence: grandfather clause + heal-on-merge ──────────────────────────
	# Veteran save WITHOUT onboarding → all current primers pre-seen.
	sm.call("_merge_loaded", {"tutorial_done": true, "stats": {"runs_started": 4}})
	_check(sm.call("is_primer_seen", "primer_jam") and sm.call("is_primer_seen", "primer_rampage"),
		"grandfathered veteran save starts with all current primers seen")
	# Save WITH onboarding → preserved verbatim, not grandfathered.
	sm.call("_merge_loaded", {"tutorial_done": true, "stats": {"runs_started": 4}, "onboarding": {"primers_seen": ["primer_jam"]}})
	_check(sm.call("is_primer_seen", "primer_jam") and not sm.call("is_primer_seen", "primer_mark"),
		"existing onboarding block is preserved, not grandfathered")
	# RESET PRIMERS (DEV): clears only primers_seen.
	sm.call("dev_reset_primers")
	_check(not sm.call("is_primer_seen", "primer_jam"), "dev_reset_primers clears primers_seen")
	_check(bool(sm.get("data")["tutorial_done"]), "dev_reset_primers leaves the rest of the profile intact")
