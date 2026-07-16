# Polish Build D regressions: consumable cap (4) + discard picker, relic cap (2) +
# display, and the event-consumable pool filter. Each check fails on the pre-Build-D
# behavior it pins. Run via scenes/debug/ConsumableLoadoutRunner.tscn (loads autoloads).
extends Node

var _failed := 0
var _resolve_result := "<none>"


func _ready() -> void:
	await get_tree().process_frame
	_run()


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS [loadout] %s" % msg)
	else:
		_failed += 1
		push_error("FAIL [loadout] %s" % msg)


func _ids_of_type(kind: String) -> Array:
	# Through the choke point (Build F): pool_ids owns unlock filtering; this
	# headless rig reads fully unlocked (isolated context).
	return DataManager.pool_ids(kind)


func _run() -> void:
	GameState.start_run(["combat", "engineer", "medic"], "facility", 4444)
	var cons: Array = _ids_of_type("consumable")
	var relics: Array = _ids_of_type("relic")
	if cons.size() < 5 or relics.size() < 3:
		_check(false, "data has enough consumables (%d) and relics (%d)" % [cons.size(), relics.size()])
		_finish()
		return

	_test_cap_and_swap_contract(cons)
	_test_cap_derivation(cons)
	await _test_discard_state_machine(cons)
	_test_relic_invariant(relics)
	_test_relic_display(relics)
	_test_event_consumable_filter()
	_test_passive_self_scope()
	_finish()


func _finish() -> void:
	print("[LOADOUT_CAP] %s (%d failed)" % ["PASS" if _failed == 0 else "FAIL", _failed])
	get_tree().quit(1 if _failed > 0 else 0)


# ── Cap = 4 + swap-on-full contract (the silent-loss bug) ──────────────────────
func _test_cap_and_swap_contract(cons: Array) -> void:
	_check(GameState.MAX_CONSUMABLES == 4, "consumable cap is 4")
	GameState.consumables = [cons[0], cons[1], cons[2], cons[3]]
	var incoming: String = str(cons[4])
	GameState.pending_reward_item_ids = [incoming]
	# At cap with NO discard supplied: claim must fail AND leave the bag untouched
	# (this false return is the exact silent-loss the reward UI used to swallow).
	var claimed_no_swap: bool = GameState.claim_reward(incoming, "", "")
	_check(not claimed_no_swap, "consumable claim at cap without a discard returns false")
	_check(not GameState.consumables.has(incoming), "rejected claim did NOT add the incoming item")
	_check(GameState.consumables.size() == 4, "rejected claim left the bag at 4")
	# With a valid discard: swaps exactly one, size stays 4.
	var discard: String = str(cons[0])
	var claimed_swap: bool = GameState.claim_reward(incoming, "", discard)
	_check(claimed_swap, "consumable claim at cap WITH a discard succeeds")
	_check(GameState.consumables.size() == 4, "swap kept the bag at exactly 4")
	_check(GameState.consumables.has(incoming) and not GameState.consumables.has(discard), "swap replaced exactly the chosen item")


# ── LoadoutMenu slot count derives from GameState.MAX_CONSUMABLES ───────────────
func _test_cap_derivation(cons: Array) -> void:
	var host := Node.new()
	get_tree().root.add_child(host)
	GameState.consumables = [cons[0], cons[1]]
	var items: Array = [DataManager.get_item(str(cons[0])), DataManager.get_item(str(cons[1]))]
	LoadoutMenu.open(host, items, [], func(_i: ItemData) -> bool: return true)
	var menu: Node = _active_loadout()
	var slots: int = _count_named(menu, "LoadoutItemRow") if menu != null else -1
	_check(slots == GameState.MAX_CONSUMABLES, "loadout builds MAX_CONSUMABLES item slots (got %d, twin constant would give 3)" % slots)
	LoadoutMenu.dismiss()
	host.queue_free()


# ── Discard picker state machine ───────────────────────────────────────────────
func _test_discard_state_machine(cons: Array) -> void:
	var host := Node.new()
	get_tree().root.add_child(host)
	var held: Array = []
	for i in 4:
		held.append(DataManager.get_item(str(cons[i])))
	var incoming: ItemData = DataManager.get_item(str(cons[4]))

	# CONFIRM disabled until a held item is selected; select does not commit.
	var menu := _open_discard(host, held, incoming)
	await get_tree().process_frame
	_check(menu._confirm_discard_button.disabled, "CONFIRM DISCARD starts disabled")
	menu._on_discard_row_tapped(held[0])
	_check(str(menu._selected_discard_id) == str(held[0].id), "tap selects a held row")
	_check(not menu._confirm_discard_button.disabled, "CONFIRM DISCARD enables after selection")
	_check(_resolve_result == "<none>", "select alone does NOT commit")
	menu._on_discard_row_tapped(held[1])
	_check(str(menu._selected_discard_id) == str(held[1].id), "tapping another row moves the selection")

	# CONFIRM commits exactly the selected id.
	menu._resolve_discard()
	_check(_resolve_result == str(held[1].id), "CONFIRM DISCARD resolves with the selected held id")
	_check(not LoadoutMenu.is_open(), "CONFIRM closes the picker")

	# ABANDON resolves with "" (nothing destroyed).
	var menu2 := _open_discard(host, held, incoming)
	await get_tree().process_frame
	menu2._on_discard_row_tapped(held[0])
	menu2._resolve_abandon()
	_check(_resolve_result == "", "ABANDON resolves with empty (no discard)")

	# Tap-outside == ABANDON.
	var menu3 := _open_discard(host, held, incoming)
	await get_tree().process_frame
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	menu3._on_catcher_input(ev)
	_check(_resolve_result == "", "tap-outside resolves as ABANDON")
	host.queue_free()


func _open_discard(host: Node, held: Array, incoming: ItemData) -> LoadoutMenu:
	_resolve_result = "<none>"
	LoadoutMenu.open_discard(host, held, incoming, func(discard_id: String) -> void: _resolve_result = discard_id)
	return _active_loadout() as LoadoutMenu


func _active_loadout() -> Node:
	# Read the class's own active reference (find_children can return a just-freed menu).
	return LoadoutMenu._active


func _count_named(node: Node, key: String) -> int:
	# Godot renames duplicate siblings to "@Name@2", so match by substring.
	var n: int = 1 if key in str(node.name) else 0
	for child in node.get_children():
		n += _count_named(child, key)
	return n


# ── Relic cap is TWO — no path yields a third ──────────────────────────────────
func _test_relic_invariant(relics: Array) -> void:
	_check(GameState.MAX_RELICS == 2, "relic cap constant is 2")
	GameState.relics = [str(relics[0]), str(relics[1])]
	# claim_reward relic path at cap: refused.
	GameState.pending_reward_item_ids = [str(relics[2])]
	var over_claim: bool = GameState.claim_reward(str(relics[2]))
	_check(not over_claim and GameState.relics.size() == 2, "claim_reward cannot seat a third relic")
	# Directive path at cap: refused (no grow past 2).
	GameState.set_starting_directive(str(relics[2]))
	_check(GameState.relics.size() == 2, "Starting Directive path cannot seat a third relic")


# ── Relic display: 0 -> no section, 1 -> one row, 2 -> two rows, never placeholder ─
func _test_relic_display(relics: Array) -> void:
	for count in [0, 1, 2]:
		var host := Node.new()
		get_tree().root.add_child(host)
		var relic_items: Array = []
		for i in count:
			relic_items.append(DataManager.get_item(str(relics[i])))
		LoadoutMenu.open(host, [], relic_items, func(_i: ItemData) -> bool: return true)
		var menu: Node = _active_loadout()
		var rows: int = _count_named(menu, "LoadoutRelicRow") if menu != null else -1
		_check(rows == count, "relic count %d renders %d rows (no placeholder)" % [count, count])
		LoadoutMenu.dismiss()
		host.queue_free()


# ── Event "consumable" grant rolls consumables, never gear ─────────────────────
func _test_event_consumable_filter() -> void:
	var only_consumables := true
	for _i in 24:
		GameState.consumables = []
		GameState.apply_intercept_effects([{"type": "consumable", "rarity": "common", "count": 1}])
		for cid in GameState.consumables:
			var item: ItemData = DataManager.get_item(str(cid)) as ItemData
			if item == null or item.item_type != "consumable":
				only_consumables = false
	_check(only_consumables, "event consumable grant only ever yields consumables (never gear)")
	# A bundled (non-interactive) grant at cap FORFEITS explicitly — never silently.
	var cons: Array = _ids_of_type("consumable")
	GameState.consumables = [cons[0], cons[1], cons[2], cons[3]]
	var info: String = GameState.apply_intercept_effects([{"type": "consumable", "rarity": "common", "count": 1}])
	_check(info.contains("FORFEITED"), "event consumable grant at cap states the forfeit (not silent)")
	_check(GameState.consumables.size() == 4, "forfeited grant left the bag at cap")


# ── Equipment self-buff exception (Build G, NK-17 amendment) ────────────────────
# Gear/relic passives never emit a self scope marker/icon — the holder is
# implicit in equipment context. Non-self scopes (all/lowest) are untouched.
func _test_passive_self_scope() -> void:
	var self_count := 0
	for effect_variant in EffectPip.effects_from_passive({"type": "battleStartShield", "amount": 5}, ""):
		if str((effect_variant as Dictionary).get("scope", "")) == "self":
			self_count += 1
	_check(self_count == 0, "equipment passive emits no self scope marker (NK-17 equipment exception)")
	var all_count := 0
	for effect_variant in EffectPip.effects_from_passive({"type": "healGrantsShieldAll", "amount": 4}, ""):
		if str((effect_variant as Dictionary).get("scope", "")) == "all":
			all_count += 1
	_check(all_count > 0, "equipment passive keeps non-self scopes (all)")
