# Firewall visibility regression.
#
# RULED 2026-09-02 (DECISIONS_RESOLVED, reversing Build G item 11): portrait
# corners carry NO status markers. The FirewallBadge that used to dock to the
# portrait's top-right corner is GONE; an armed firewall is an ordinary chip in
# the bottom status row, under the same STATUS_MAX_VISIBLE cap and the same +N
# overflow as every other chip. Firewall may therefore land in overflow — the
# accepted cost, since long-press shows the full breakdown.
#
#   • the card builds NO portrait-corner firewall badge (the reversal itself).
#   • a warded unit renders the firewall PIP ICON as a bottom-row chip.
#   • firewall obeys the cap: as the lowest-priority chip of four it folds into
#     the +N overflow badge and the row still renders exactly 3 chips.
#   • a dead unit renders no chips at all.
#   • combat authority: _apply_ward sets warded, _ward_blocks_hostile consumes
#     it (block-then-break, one ability).
#   • THE COURT (Conclave Overseer): the round-start ward is granted AND
#     consumed inside one resolve_round, so it is absent from both the
#     pre-resolve snapshot and the post-resolve state. BattleFeedback's
#     transient-chip injection is what makes it visible for its own beat.
# Run: godot --headless --path . -s scripts/debug/firewall_display_test.gd
extends SceneTree


# Minimal host for BattleCardView._composed_status_tokens: it reads only
# `_scene._feedback`, so the merge seam can be exercised without a battle.
class StubScene:
	extends Control
	var _feedback: Node = null


var _errors: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_errors.append(label)


# A chip whose icon TextureRect carries the firewall pip art.
func _has_firewall_chip(row: Node) -> bool:
	var wanted: Texture2D = PixelUI.pip_texture_for_key("firewall")
	if wanted == null:
		return false
	return _finds_texture(row, wanted)


func _finds_texture(node: Node, wanted: Texture2D) -> bool:
	if node is TextureRect and (node as TextureRect).texture == wanted:
		return true
	for child in node.get_children():
		if _finds_texture(child, wanted):
			return true
	return false


func _overflow_text(row: Node) -> String:
	for child in row.get_children():
		if child is Label:
			return str((child as Label).text)
	return ""


func _has_token_type(tokens: Array, wanted: String) -> bool:
	for token_variant in tokens:
		if str((token_variant as Dictionary).get("type", "")) == wanted:
			return true
	return false


func _chip_count(row: Node) -> int:
	var count: int = 0
	for child in row.get_children():
		if child is PanelContainer:
			count += 1
	return count


func _initialize() -> void:
	await process_frame
	var CardScript: GDScript = load("res://scripts/ui/compact_unit_card.gd")
	var card: Control = CardScript.new()
	root.add_child(card)
	await process_frame

	var base: Dictionary = {"side": "hero", "name": "TEST", "current_hp": 10, "max_hp": 10}
	var firewall_token: Dictionary = {"type": "firewall", "mode": "icon", "priority": 3}

	# The reversal: nothing docks to a portrait corner for firewall any more.
	card.call("configure", base.merged({"statuses": [firewall_token]}, true))
	await process_frame
	_check(card.find_child("FirewallBadge", true, false) == null,
		"the card builds NO portrait-corner firewall badge (Build G item 11 reversed)")

	var row: Node = card.get("_status_row")
	_check(row != null, "the card exposes a status row")
	_check(row != null and _has_firewall_chip(row),
		"a warded unit renders the firewall chip in the bottom row")
	_check(row != null and _chip_count(row) == 1 and _overflow_text(row) == "",
		"a lone firewall is one chip with no overflow badge")

	# Cap + overflow: burn(0) shield(1) mark(1) beat firewall(3), so firewall
	# folds into +N. That is the ACCEPTED cost of the ruling, not a bug.
	card.call("configure", base.merged({"statuses": [
		{"type": "burn", "mode": "numeric", "icon": "B", "value": 4, "priority": 0},
		{"type": "shield", "mode": "numeric", "icon": "S", "value": 6, "priority": 1},
		{"type": "mark", "mode": "icon", "priority": 1},
		firewall_token,
	]}, true))
	await process_frame
	row = card.get("_status_row")
	_check(_chip_count(row) == 3, "the row renders exactly STATUS_MAX_VISIBLE chips")
	_check(_overflow_text(row) == "+1", "the 4th status folds into the +N overflow badge")
	_check(not _has_firewall_chip(row),
		"firewall loses the 3-chip priority contest and sits in overflow (accepted cost)")

	card.queue_free()

	# Death is filtered at the TOKEN PRODUCER, not the card: a dead state emits
	# no chips at all, so a corpse can never show a firewall (the old badge
	# carried its own `and not dead` guard — this is where that lives now).
	var CardViewScript: GDScript = load("res://scripts/battle/battle_card_view.gd")
	var card_view: Node = CardViewScript.new()
	var warded_state: Dictionary = {"id": "T#1", "warded": true, "burn": 0, "shield": 0}
	var live_tokens: Array = card_view.call("_build_compact_status_tokens", warded_state)
	_check(_has_token_type(live_tokens, "firewall"),
		"a warded state emits a firewall chip token")
	warded_state["dead"] = true
	_check((card_view.call("_build_compact_status_tokens", warded_state) as Array).is_empty(),
		"a dead state emits no chip tokens (no firewall on a corpse)")

	# Combat authority: ward arms on _apply_ward and is consumed by the next
	# hostile ability (state side of the same display contract).
	var dm: Node = root.get_node("/root/DataManager")
	var hero: UnitData = dm.call("get_unit", "combat") as UnitData
	var enemy: EnemyData = dm.call("get_enemy_by_display_name", "Scrap Drone") as EnemyData
	if hero == null or enemy == null:
		push_error("[FIREWALL_DISPLAY] could not load units")
		print("[FIREWALL_DISPLAY] FAIL - unit load")
		quit(1)
		return
	var CombatManagerScript: GDScript = load("res://scripts/battle/combat_manager.gd")
	var cm: Object = CombatManagerScript.new()
	cm.call("setup_battle", [hero], [enemy.duplicate(true)])
	var st: Dictionary = cm.call("get_hero_states")[0]
	cm.call("_apply_ward", st)
	_check(bool(st.get("warded", false)), "_apply_ward arms the warded state")
	_check(bool(cm.call("_ward_blocks_hostile", st)), "the next hostile ability is blocked")
	_check(not bool(st.get("warded", false)), "the firewall breaks after blocking (expiry)")
	# CombatManager is RefCounted — no free; it drops with the last reference.

	# ── THE COURT (Conclave Overseer) ──────────────────────────────────────────
	# The Overseer's standing rule raises its firewall at the TOP of
	# resolve_round and the hero phase inside the SAME call consumes it, so the
	# ward is in neither the pre-resolve snapshot nor the post-resolve state:
	# `warded` reads false on every card built afterwards. Before the fix the
	# chip never rendered at all and the block's ✕ negated something the player
	# was never shown. BattleFeedback injects the chip for exactly the beats it
	# was live. FAIL-ON-OLD: a feedback without injection returns nothing here.
	var FeedbackScript: GDScript = load("res://scripts/battle/battle_feedback.gd")
	var feedback: Node = FeedbackScript.new()
	# Round shape: round-start ward on the Overseer (group 0, no action_start of
	# its own), then a hero attack whose damage the ward blocks (group 1).
	var court_events: Array = [
		{"type": "ward", "side": "enemy", "target_id": "OVERSEER#1"},
		{"type": "action_start", "side": "hero", "actor_id": "A#1", "zone": "strike"},
		{"type": "block", "side": "enemy", "target_id": "OVERSEER#1", "amount": 0},
	]
	feedback.call("plan_status_suppression", court_events)
	_check(_has_token_type(feedback.call("injected_chip_tokens", "OVERSEER#1"), "firewall") == false,
		"nothing is injected before the first beat plays")
	feedback.call("release_group_suppression", 0)
	_check(_has_token_type(feedback.call("injected_chip_tokens", "OVERSEER#1"), "firewall"),
		"the round-start ward shows a firewall chip from its own beat")
	feedback.call("release_group_suppression", 1)
	_check(not _has_token_type(feedback.call("injected_chip_tokens", "OVERSEER#1"), "firewall"),
		"the chip clears at the beat that blocks and breaks it")
	# Edge e: the round-end clear strands no injected chip.
	feedback.call("plan_status_suppression", court_events)
	feedback.call("release_group_suppression", 0)
	feedback.call("clear_status_suppression")
	_check((feedback.call("injected_chip_tokens", "OVERSEER#1") as Array).is_empty(),
		"round-complete clear strands no injected chip")

	# A ward that OUTLIVES its round (the Aegis ally) is rendered from state as
	# before: injection fills gaps only, so it must not duplicate the live chip.
	var ally_events: Array = [
		{"type": "action_start", "side": "hero", "actor_id": "AEGIS#1", "zone": "strike"},
		{"type": "ward", "side": "hero", "target_id": "AEGIS#1"},
	]
	feedback.call("plan_status_suppression", ally_events)
	feedback.call("release_group_suppression", 0)
	var ally_injected: Array = feedback.call("injected_chip_tokens", "AEGIS#1")
	var ally_live: Array = card_view.call("_build_compact_status_tokens",
		{"id": "AEGIS#1", "warded": true, "burn": 0, "shield": 0})
	var ally_merged: Dictionary = {}
	for token_variant in ally_live + ally_injected:
		ally_merged[str((token_variant as Dictionary).get("type", ""))] = true
	_check(ally_merged.has("firewall") and ally_live.size() == 1,
		"an unconsumed ward still renders from live state, not duplicated")
	# End-to-end through the real merge seam: the card view must actually put
	# the injected chip in the row it hands the card. This is the join that was
	# broken — the feedback map alone proves nothing if the view drops it.
	var stub: Control = StubScene.new()
	root.add_child(stub)
	stub.set("_feedback", feedback)
	card_view.call("setup", stub)
	feedback.call("plan_status_suppression", court_events)
	feedback.call("release_group_suppression", 0)
	var composed: Array = card_view.call("_composed_status_tokens",
		{"id": "OVERSEER#1", "warded": false, "burn": 0, "shield": 0})
	_check(_has_token_type(composed, "firewall"),
		"the card view's composed row carries the injected firewall chip")
	feedback.call("release_group_suppression", 1)
	composed = card_view.call("_composed_status_tokens",
		{"id": "OVERSEER#1", "warded": false, "burn": 0, "shield": 0})
	_check(not _has_token_type(composed, "firewall"),
		"the composed row drops it again at the block beat")
	stub.queue_free()

	feedback.free()
	card_view.free()

	if _errors.is_empty():
		print("[FIREWALL_DISPLAY] PASS")
		quit(0)
	else:
		for e in _errors:
			push_error("[FIREWALL_DISPLAY] " + e)
		print("[FIREWALL_DISPLAY] FAIL - %d check(s)" % _errors.size())
		quit(1)
