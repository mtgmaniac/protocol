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

	# ── 4) same-priority tie-break (protocol primers were CUT 2026-07-10 — the
	# tutorial teaches nudge/reroll/set; keyword primers carry the tie test now).
	# Three same-priority (30) keyword sightings in one moment: exactly ONE
	# shows; the losers are not marked seen and fire on later turns.
	primer.on_turn_started()
	primer.notice_event({"type": "detonate", "side": "enemy", "target_id": "e1"})
	primer.notice_event({"type": "execute", "side": "enemy", "target_id": "e1"})
	primer.notice_event({"type": "pierce", "side": "enemy", "target_id": "e1"})
	await primer.flush_at_group_boundary()
	var tie_seen: int = 0
	for pid in ["primer_detonate", "primer_execute", "primer_pierce"]:
		if sm.call("is_primer_seen", pid):
			tie_seen += 1
	_check(tie_seen == 1, "same-priority ties: exactly one of three shows per turn (saw %d)" % tie_seen)
	for _round in 2:
		primer.on_turn_started()
		primer._fired_params.clear()
		primer.notice_event({"type": "detonate", "side": "enemy", "target_id": "e1"})
		primer.notice_event({"type": "execute", "side": "enemy", "target_id": "e1"})
		primer.notice_event({"type": "pierce", "side": "enemy", "target_id": "e1"})
		await primer.flush_at_group_boundary()
	for pid in ["primer_detonate", "primer_execute", "primer_pierce"]:
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

	# ── 7) Bug-2: roll sightings key on ICONS — every unseen non-exempt icon
	# fires; damage/heal/shield never do (HIGHLIGHT_EXEMPT_ICONS is the ONE
	# exclusion list). Enemy abilities go through the same path.
	sm.call("dev_reset_primers")
	primer._fired_params.clear()
	var exempt: Array = primer.HIGHLIGHT_EXEMPT_ICONS
	_check(exempt.size() == 3 and exempt.has("damage") and exempt.has("heal") and exempt.has("shield"),
		"exclusion list is exactly damage/heal/shield")
	# Exempt-only pip (plain damage): never highlights.
	primer.on_turn_started()
	var shows_before: int = primer.debug_show_count
	primer.notice_rolled_ability({"dmg": 10}, "hero", "h1")
	await primer.flush_at_group_boundary()
	_check(primer.debug_show_count == shows_before, "exempt-only pip (damage) never highlights")
	# A keyword icon on the same pip fires (unified ledger with the event path).
	primer.on_turn_started()
	primer.notice_rolled_ability({"dmg": 6, "chain": 2}, "hero", "h1")
	await primer.flush_at_group_boundary()
	_check(sm.call("is_primer_seen", "primer_chain"), "roll-sighted chain icon fires the chain primer")
	# The hits-all MARKER on an otherwise-exempt damage pip fires the aoe primer.
	primer.on_turn_started()
	primer.notice_rolled_ability({"dmg": 12, "blastAll": true}, "hero", "h1")
	await primer.flush_at_group_boundary()
	_check(sm.call("is_primer_seen", "primer_icon_aoe"), "hits-all marker fires on an exempt-damage pip")
	# The targets-lowest marker on an exempt heal pip.
	primer.on_turn_started()
	primer.notice_rolled_ability({"heal": 6, "healLowest": true}, "hero", "h1")
	await primer.flush_at_group_boundary()
	_check(sm.call("is_primer_seen", "primer_icon_target_lowest"), "target-lowest marker fires on an exempt-heal pip")
	# ±roll icon from an ENEMY ability (ECM Hiss-style erb self roll-buff).
	primer.on_turn_started()
	primer.notice_rolled_ability({"erb": 2, "erbT": 2}, "enemy", "e1")
	await primer.flush_at_group_boundary()
	_check(sm.call("is_primer_seen", "primer_icon_roll"), "enemy ±roll icon fires the roll primer")
	# The targets-self marker on an exempt shield pip.
	primer.on_turn_started()
	primer.notice_rolled_ability({"shield": 4}, "hero", "h1")
	await primer.flush_at_group_boundary()
	_check(sm.call("is_primer_seen", "primer_icon_self"), "targets-self marker fires on an exempt-shield pip")
	# Protocol-gain pip (Field Patch-style gainProtocol) fires the protocol primer.
	primer.on_turn_started()
	primer.notice_rolled_ability({"gainProtocol": 1}, "hero", "h1")
	await primer.flush_at_group_boundary()
	_check(sm.call("is_primer_seen", "primer_icon_protocol"), "protocol-gain pip fires the protocol primer")
	# Conditional-modifier condition icon (Shatter Lance-style "+5❄" on a dmg pip)
	# teaches freeze on first sight — the dmg base stays exempt.
	sm.call("dev_reset_primers")
	primer._fired_params.clear()
	primer.on_turn_started()
	primer.notice_rolled_ability({"dmg": 10, "vsFrozenBonus": 5}, "hero", "h1")
	await primer.flush_at_group_boundary()
	_check(sm.call("is_primer_seen", "primer_freeze"), "vs-frozen bonus icon fires the freeze primer")

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
