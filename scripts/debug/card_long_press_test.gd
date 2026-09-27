# Card long-press regression (UI batch 2026-09-27, B7).
#
# Long-pressing a status badge on a unit card did nothing: badges (and the HP
# bar) stop input and forwarded it to the card body, which selected on PRESS
# and had no hold gesture; only the portrait had one. Now one card-level
# LongPressInput takes the body and every stopping overlay, so on each region:
#   • a hold opens the unit's inspect (unit_detail_requested), with no tap;
#   • a quick tap selects the unit (card_pressed), with no inspect.
# Regions: the portrait, a status badge, the +N overflow badge, the HP bar and
# the card body (name strip). Badges have no inspect content of their own
# (they only forwarded input), so nothing is lost.
# FAIL-ON-OLD: holding a status badge / the HP bar / the body never emits
# unit_detail_requested, and pressing them emits card_pressed at once.
# Run: godot --headless --path . -s scripts/debug/card_long_press_test.gd
extends SceneTree

var _errors: Array[String] = []
var _taps: int = 0
var _details: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var CardScript: GDScript = load("res://scripts/ui/compact_unit_card.gd")
	var card: Control = CardScript.new()
	root.add_child(card)
	await process_frame
	card.call("configure", {"side": "hero", "name": "TEST", "current_hp": 30, "max_hp": 50,
		"interaction_enabled": true, "statuses": [
			{"type": "burn", "mode": "numeric", "icon": "B", "value": 4, "priority": 0},
			{"type": "shield", "mode": "numeric", "icon": "S", "value": 6, "priority": 1},
			{"type": "mark", "mode": "icon", "priority": 1},
			{"type": "firewall", "mode": "icon", "priority": 3},
		]})
	card.set("interaction_enabled", true)
	# The battle refresh always shows or clears a preview, which is what wires
	# the HP bar's pass-through (battle_card_view.update_card_view).
	card.call("clear_combat_preview")
	await process_frame
	await process_frame
	card.connect("card_pressed", func() -> void: _taps += 1)
	card.connect("unit_detail_requested", func(_c) -> void: _details += 1)

	var row: Node = card.get("_status_row")
	var badge: Control = null
	var overflow: Control = null
	for child in row.get_children():
		if child is PanelContainer and badge == null:
			badge = child
		elif child is Label:
			overflow = child
	var regions: Dictionary = {
		"portrait": card.get("_portrait_rect"),
		"status badge": badge,
		"HP bar": card.get("_hp_back"),
		"card body": card,
	}
	for region_name in regions.keys():
		var node: Control = regions[region_name] as Control
		if node == null:
			_errors.append("%s: region not found" % region_name)
			continue
		await _gesture(node, true)
		_check(_details == 1 and _taps == 0, "%s: a hold opens the unit inspect and does not select (detail %d, tap %d)" % [region_name, _details, _taps])
		await _gesture(node, false)
		_check(_details == 0 and _taps == 1, "%s: a tap selects and does not inspect (detail %d, tap %d)" % [region_name, _details, _taps])
	# The +N overflow badge opens the inspect on press (pkg8.1), so a hold on
	# it reaches the same popup.
	_check(overflow != null, "the four statuses fold one into the +N overflow badge")
	if overflow != null:
		await _gesture(overflow, true)
		_check(_details >= 1, "+N overflow: a hold opens the unit inspect (detail %d)" % _details)

	card.queue_free()
	await process_frame
	if _errors.is_empty():
		print("[CARD_LONG_PRESS] PASS - portrait, status badge, HP bar, body and +N all long-press to the unit inspect")
	else:
		for e in _errors:
			print("[CARD_LONG_PRESS] FAIL: " + e)
	quit(0 if _errors.is_empty() else 1)


# Press on `node`, hold (past the inspect hold) or release at once, as the
# viewport would deliver it: through the node's gui_input.
func _gesture(node: Control, hold: bool) -> void:
	_taps = 0
	_details = 0
	var at: Vector2 = node.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	press.global_position = at
	_deliver(node, press)
	if hold:
		await create_timer(0.7).timeout
	else:
		await process_frame
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = at
	release.global_position = at
	_deliver(node, release)
	await process_frame


func _deliver(node: Control, event: InputEvent) -> void:
	node.gui_input.emit(event)
	if node.has_method("_gui_input"):
		node.call("_gui_input", event)


func _check(cond: bool, label: String) -> void:
	if not cond:
		_errors.append(label)
