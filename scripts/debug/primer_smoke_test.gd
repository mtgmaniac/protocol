# Keyword primer smoke test (headless): exercises at least one primer per
# trigger type through the real manager pipeline (queue → flush → display →
# persist), asserting each fires ONCE, persists as seen, and never refires —
# plus the FULL-DRAIN contract (Kev 2026-07-12: every unseen icon raised in a
# turn is taught in that turn, modal sequence, enqueue/spatial order, priority
# inert), glyph identity tagging, failure safety, and the grandfather clause.
# Uses the manager's documented test seams (debug_force_active /
# debug_auto_dismiss / debug_shown_ids); display runs through the real
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


# Depth-first collection of pip_icon_key metas — mirrors the primer's glyph walk.
func _collect_icon_metas(node: Node, out: Array) -> void:
	if node is TextureRect and node.has_meta("pip_icon_key"):
		out.append(str(node.get_meta("pip_icon_key")))
	for child in node.get_children():
		_collect_icon_metas(child, out)


# First tagged TextureRect for an icon, alpha-blind (test helper — used to
# locate the ghost node the resolver must NOT pick).
func _find_tagged(node: Node, icon: String) -> TextureRect:
	if node is TextureRect and node.has_meta("pip_icon_key") and str(node.get_meta("pip_icon_key")) == icon:
		return node
	for child in node.get_children():
		var found: TextureRect = _find_tagged(child, icon)
		if found != null:
			return found
	return null


# Stand-in battle scene exposing the visible-plate lookup (Bug-1 round 2).
class StubBattleScene extends Node:
	var hero_card_views: Array = []
	var enemy_card_views: Array = []
	var plate: Control = null

	func get_die_tag_plate(_side: String, _unit_id: String) -> Control:
		return plate


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

	# ── 1) die_status_applied fires + FULL DRAIN: two first-sightings the SAME
	# turn are BOTH taught that turn, in enqueue order (no cap, no deferral).
	primer.on_turn_started()
	primer.notice_event({"type": "jam", "side": "enemy", "target_id": "e1"})
	primer.notice_event({"type": "freeze", "side": "enemy", "target_id": "e1"})
	await primer.flush_at_group_boundary()
	_check(sm.call("is_primer_seen", "primer_jam"), "die_status_applied (jam) fires and persists")
	_check(sm.call("is_primer_seen", "primer_freeze"), "second sighting same turn ALSO taught (full drain)")
	_check(primer.debug_show_count == 2, "both primers displayed in the same turn")
	_check(primer.debug_shown_ids == ["primer_jam", "primer_freeze"], "drain runs in enqueue order")

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

	# ── 4) FULL DRAIN, ORDER (Kev 2026-07-12): three same-moment sightings all
	# teach in ONE turn, in enqueue order — the old cap dropped the losers.
	primer.on_turn_started()
	primer.debug_shown_ids.clear()
	primer.notice_event({"type": "detonate", "side": "enemy", "target_id": "e1"})
	primer.notice_event({"type": "execute", "side": "enemy", "target_id": "e1"})
	primer.notice_event({"type": "pierce", "side": "enemy", "target_id": "e1"})
	await primer.flush_at_group_boundary()
	for pid in ["primer_detonate", "primer_execute", "primer_pierce"]:
		_check(sm.call("is_primer_seen", pid), "%s taught in the turn it was raised" % pid)
	_check(primer.debug_shown_ids == ["primer_detonate", "primer_execute", "primer_pierce"],
		"three-candidate drain preserves enqueue order")

	# Priority is DEAD (ruling 2026-07-12): cloak (json prio 40) enqueued before
	# rewrite (json prio 50) shows FIRST — spatial/enqueue order, no sort.
	sm.call("dev_reset_primers")
	primer._fired_params.clear()
	primer.on_turn_started()
	primer.debug_shown_ids.clear()
	primer.notice_event({"type": "cloak", "side": "enemy", "target_id": "e1"})
	primer.notice_event({"type": "rewrite", "side": "enemy", "target_id": "e1"})
	await primer.flush_at_group_boundary()
	_check(primer.debug_shown_ids == ["primer_cloak", "primer_rewrite"],
		"priority field is inert — enqueue order wins over json priority")
	_check(sm.call("is_primer_seen", "primer_cloak") and sm.call("is_primer_seen", "primer_rewrite"),
		"both mixed-priority sightings taught in the same turn")

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
	# ±roll icon from an ENEMY ability (ECM Hiss-style erb self roll-buff): the
	# pip carries TWO teachable icons (roll_up kind + self marker) — full drain
	# teaches both in that turn, pips left-to-right (kind before marker).
	primer.on_turn_started()
	primer.debug_shown_ids.clear()
	primer.notice_rolled_ability({"erb": 2, "erbT": 2}, "enemy", "e1")
	await primer.flush_at_group_boundary()
	_check(sm.call("is_primer_seen", "primer_icon_roll"), "enemy ±roll icon fires the roll primer")
	_check(sm.call("is_primer_seen", "primer_icon_self"), "the self marker on the same pip drains the same turn")
	_check(primer.debug_shown_ids == ["primer_icon_roll", "primer_icon_self"],
		"within one pip the kind icon teaches before the scope marker")
	# Seen icons never refire through the roll path either.
	primer.on_turn_started()
	var shows_after_erb: int = primer.debug_show_count
	primer.notice_rolled_ability({"shield": 4}, "hero", "h1")
	await primer.flush_at_group_boundary()
	_check(primer.debug_show_count == shows_after_erb, "already-seen self marker does not refire on a new pip")
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

	# THREE unseen icons on one ability drain in one turn, pips left-to-right:
	# dmg effect contributes [aoe marker, freeze bonus], chain effect [chain].
	sm.call("dev_reset_primers")
	primer._fired_params.clear()
	primer.on_turn_started()
	primer.debug_shown_ids.clear()
	primer.notice_rolled_ability({"dmg": 6, "chain": 2, "blastAll": true, "vsFrozenBonus": 5}, "hero", "h1")
	await primer.flush_at_group_boundary()
	_check(primer.debug_shown_ids == ["primer_icon_aoe", "primer_freeze", "primer_chain"],
		"three icons from one roll drain in pip order (saw %s)" % str(primer.debug_shown_ids))

	# Rail order: hero sightings teach before enemy sightings raised the same
	# turn (battle_scene reports hero states first — the written rule).
	sm.call("dev_reset_primers")
	primer._fired_params.clear()
	primer.on_turn_started()
	primer.debug_shown_ids.clear()
	primer.notice_rolled_ability({"dmg": 5, "mark": true}, "hero", "h1")
	primer.notice_rolled_ability({"jam": true}, "enemy", "e1")
	await primer.flush_at_group_boundary()
	_check(primer.debug_shown_ids == ["primer_mark", "primer_jam"],
		"hero rail teaches before enemy rail (saw %s)" % str(primer.debug_shown_ids))

	# In-flight dedupe: TWO units raise the same icon in one moment — one drain
	# teaches the lesson ONCE (2026-07-12 DoD recapture found it showing twice;
	# this case fails without the _fired_params check in _flush).
	sm.call("dev_reset_primers")
	primer._fired_params.clear()
	primer.on_turn_started()
	primer.debug_shown_ids.clear()
	primer.notice_rolled_ability({"shield": 4}, "hero", "h1")   # self marker
	primer.notice_rolled_ability({"shield": 5}, "hero", "h2")   # self marker again
	await primer.flush_at_group_boundary()
	_check(primer.debug_shown_ids == ["primer_icon_self"],
		"same icon from two units teaches once per drain (saw %s)" % str(primer.debug_shown_ids))

	# ── 8) Glyph identity tags (Phase 1): every icon TextureRect carries its
	# pip_icon_key meta, so the primer spotlights ONE glyph, never the row.
	# This is the shield+self case from Kev's screenshot — both individually
	# addressable. (Runtime load, NOT the EffectPip class_name — the parse-time
	# reference would compile effect_pip.gd before autoloads exist: -s gotcha.)
	var EffectPipScript: GDScript = load("res://scripts/ui/effect_pip.gd")
	var tag_group: Control = EffectPipScript.build_group(
		{"kind": "shield", "value": "4", "duration": 0, "scope": "self", "bonus": "", "bonus_icon": ""},
		EffectPipScript.PROFILE_CARD)
	var metas: Array = []
	_collect_icon_metas(tag_group, metas)
	_check(metas == ["shield", "self"], "shield+self pip exposes both glyph identities (saw %s)" % str(metas))
	tag_group.free()
	var bonus_group: Control = EffectPipScript.build_group(
		{"kind": "dmg", "value": "10", "duration": 0, "scope": "", "bonus": "+5", "bonus_icon": "freeze"},
		EffectPipScript.PROFILE_CARD)
	metas = []
	_collect_icon_metas(bonus_group, metas)
	_check(metas == ["damage", "freeze"], "dmg+condition pip exposes kind and condition identities (saw %s)" % str(metas))
	bonus_group.free()

	# ── 8b) Field Patch retarget (2026-07-12): targets ANY ally — the shield
	# pip carries NO self marker (this check FAILS on the pre-fix self-only
	# data, where the derived scope was "self").
	var dm_units: Node = root.get_node("/root/DataManager")
	var eng: Resource = dm_units.call("get_unit", "engineer")
	var fp_raw: Dictionary = {}
	for range_variant in eng.get("dice_ranges"):
		var range_entry: Dictionary = range_variant
		if str(range_entry.get("ability_name", "")) == "Field Patch":
			fp_raw = range_entry.get("raw", {})
	_check(bool(fp_raw.get("shTgt", false)), "Field Patch is a targeted ally shield (shTgt)")
	var fp_scopes: Array = []
	for fp_effect_variant in EffectPipScript.effects_from_ability_raw(fp_raw, "hero"):
		fp_scopes.append(str((fp_effect_variant as Dictionary).get("scope", "")))
	_check(not fp_scopes.has("self"), "Field Patch pip carries no self marker (saw scopes %s)" % str(fp_scopes))

	# ── 9) GHOST-MATCH regression (Bug-1 round 2 — this test FAILS on the
	# original bug): the rail readout is an alpha-0 data holder whose tagged
	# glyph nodes are ghosts with live rects; the resolver must land on the
	# VISIBLE die-docked plate's glyph (effective alpha > 0), never the ghost.
	var stub := StubBattleScene.new()
	root.add_child(stub)
	var ghost_holder := Control.new()
	ghost_holder.modulate = Color(1, 1, 1, 0)  # exactly how AbilityReadout hides
	ghost_holder.position = Vector2(100, 100)
	ghost_holder.size = Vector2(300, 104)  # the rail readout reserves real space
	var ghost_group: Control = EffectPipScript.build_group(
		{"kind": "shield", "value": "8", "duration": 0, "scope": "self", "bonus": "", "bonus_icon": ""},
		EffectPipScript.PROFILE_CARD)
	ghost_holder.add_child(ghost_group)
	root.add_child(ghost_holder)
	var plate := Control.new()
	plate.position = Vector2(400, 900)  # far from the ghost — intersects() discriminates
	var plate_group: Control = EffectPipScript.build_group(
		{"kind": "shield", "value": "8", "duration": 0, "scope": "self", "bonus": "", "bonus_icon": ""},
		EffectPipScript.PROFILE_CARD)
	plate.add_child(plate_group)
	root.add_child(plate)
	stub.hero_card_views = [{"state": {"id": "h9"}, "readout": ghost_holder, "card": ghost_holder}]
	stub.plate = plate
	ghost_group.size = ghost_group.get_combined_minimum_size()
	plate_group.size = plate_group.get_combined_minimum_size()
	await process_frame
	await process_frame
	var primer2 = KeywordPrimerScript.new()
	root.add_child(primer2)
	primer2.setup(stub)
	var picked: Rect2 = primer2._resolve_ability_pip_rect({"side": "hero", "target_id": "h9", "icon": "self"})
	var plate_glyph: TextureRect = _find_tagged(plate, "self")
	var ghost_glyph: TextureRect = _find_tagged(ghost_holder, "self")
	_check(plate_glyph != null and ghost_glyph != null, "ghost-match rig built both trees")
	_check(picked.size != Vector2.ZERO, "resolver returns a rect with a plate present")
	if plate_glyph != null and ghost_glyph != null:
		_check(picked.intersects(plate_glyph.get_global_rect()),
			"resolved rect intersects a glyph with effective alpha > 0 (the visible plate)")
		_check(not picked.intersects(ghost_glyph.get_global_rect()),
			"resolved rect does NOT land on the alpha-0 ghost glyph")
	# With NO plate (pre-roll), the chain falls back to readout row -> card.
	stub.plate = null
	var fallback: Rect2 = primer2._resolve_ability_pip_rect({"side": "hero", "target_id": "h9", "icon": "self"})
	_check(fallback.size != Vector2.ZERO, "plate-less fallback still resolves (row/card chain intact)")

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
