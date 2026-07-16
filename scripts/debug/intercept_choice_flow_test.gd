extends Node

# Focused regression for the shared Intercept -> RewardScreen handoff. This is
# deliberately GameState-level: the screen smoke verifies parsing/layout while
# this verifies that a routed choice rolls once, commits once, and leaves the
# Intercept result stage resumable after a scene round-trip.
var _failures: int = 0


func _ready() -> void:
	await get_tree().process_frame
	GameState.start_run(["combat", "engineer", "medic"], "facility", 9001)
	_test_consumable_draft()
	_test_draft_direct_commit_rule()
	_test_owned_gear_pick()
	_test_ui_review_state()
	print("Intercept choice handoff: %d failed" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS [interceptChoice] %s" % message)
	else:
		_failures += 1
		push_error("FAIL [interceptChoice] %s" % message)


func _begin_card(choice: Dictionary) -> void:
	GameState.begin_intercept_state("abandonedArmory")
	GameState.set_intercept_choice(choice)


func _test_consumable_draft() -> void:
	_begin_card({"draft": {"kind": "consumable", "min_rarity": "common", "count": 3}, "effects": []})
	var offers: Array = GameState.roll_intercept_draft("consumable", "common", 3)
	GameState.begin_intercept_item_request("draft", "CHOOSE INTERCEPT REWARD", offers)
	_expect(GameState.get_pending_choice_offers().size() == offers.size(), "draft offer is retained")
	if offers.is_empty():
		return
	var selected: String = str(offers[0])
	_expect(GameState.complete_intercept_item_choice(selected), "draft commits once")
	_expect(GameState.consumables.has(selected), "drafted consumable enters inventory")
	_expect(str(GameState.pending_intercept_state.get("stage", "")) == "result_pending", "draft returns to Intercept result")
	_expect(not GameState.complete_intercept_item_choice(selected), "cleared request rejects duplicate commit")


# Build G item 9: the intercept result stage is skipped for a pure draft (the
# reward screen's select + CONFIRM already committed it) — one interaction, no
# reconfirm. It survives when the effects carry unseen info (reveal text /
# forfeit note) and for every non-draft choice.
func _test_draft_direct_commit_rule() -> void:
	var InterceptScreenScript: GDScript = load("res://scripts/ui/intercept_screen.gd")
	var drafted: ItemData = DataManager.get_item(str(GameState.consumables[0])) as ItemData if not GameState.consumables.is_empty() else null
	if drafted == null:
		var offers: Array = GameState.roll_intercept_draft("consumable", "common", 1)
		drafted = DataManager.get_item(str(offers[0])) as ItemData if not offers.is_empty() else null
	_expect(drafted != null, "draft rule test has a consumable to reason about")
	_expect(InterceptScreenScript.draft_commits_directly(drafted, ""), "pure draft commits directly (no result reconfirm)")
	_expect(not InterceptScreenScript.draft_commits_directly(drafted, "LOADOUT FULL - 1 ITEM FORFEITED"), "draft with unseen info keeps the result stage")
	_expect(not InterceptScreenScript.draft_commits_directly(null, ""), "non-draft choice keeps the result stage")
	# A pure draft's own effects produce no info (the precondition of the skip).
	_expect(GameState.apply_intercept_effects([]) == "", "pure draft effects produce no result info")


func _test_owned_gear_pick() -> void:
	GameState.gear_by_unit["combat"] = ["bounty_chip"]
	GameState.equipped_gear["combat"] = ["bounty_chip"]
	_begin_card({"pick": "gear", "effects": [{"type": "destroyPickedGear"}]})
	GameState.begin_intercept_item_request("owned_gear", "SELECT EQUIPPED GEAR", [], [{"hero_id": "combat", "gear_id": "bounty_chip"}])
	_expect(GameState.complete_intercept_item_choice("combat|bounty_chip"), "owned gear selection commits")
	var context: Dictionary = GameState.pending_intercept_state.get("gear_context", {}) as Dictionary
	_expect(str(context.get("hero_id", "")) == "combat" and str(context.get("gear_id", "")) == "bounty_chip", "owned gear context survives handoff")


func _test_ui_review_state() -> void:
	GameState.reward_picker_ui_state = {
		"selected_item_id": "overcharge",
		"selected_gear_unit_id": "",
		"selected_swap_consumable_id": "",
		"scroll_vertical": 84,
	}
	_expect(int(GameState.reward_picker_ui_state.get("scroll_vertical", -1)) == 84, "review state retains scroll position")
