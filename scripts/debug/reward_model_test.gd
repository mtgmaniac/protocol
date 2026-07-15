# Polish Build B regression: the reward screen's selection model, row geometry,
# and the integer-icon law.
#
#   godot --headless --path . -s scripts/debug/reward_model_test.gd
#
# Asserts (ordinary rewards):
#   T1  offers render as horizontal ROWS (nodes named "RewardRow"), not squares.
#   T2  CONFIRM starts disabled (no selection).
#   T3  tapping a row SELECTS it and does NOT commit (claim state untouched).
#   T4  tapping a different row MOVES the selection.
#   T5  every icon in the reward path renders at an INTEGER multiple of its
#       native size; low-res (<=48 native) icons render at exactly 4x.
#   T6  CONFIRM commits the selected reward.
# Relic cache:
#   T7  relic offers render as ceremonial cards (nodes named "RelicCard").
#   T8  the 32x32 gravityWell icon renders at exactly 4x (128) on its plate.
# Containment:
#   T9  at inset budgets (0,0) and (132,56) the confirm button and every row
#       land inside the safe screen box.
#   T10 ordinary rows have equal fixed geometry, two-line description slots,
#       and a centered choice group below the heading.
#   T11 relic cards use a shared near-full safe width, remain centered, and
#       preserve unclipped description space for the longest supported copy.
extends SceneTree

const REWARD_SCENE := "res://scenes/ui/RewardScreen.tscn"
const SQUAD := ["shield", "avalanche", "pulse"]
const ORDINARY_ITEMS := ["patch_kit", "scrap_plate", "momentum_core"]
const RELIC_ITEMS := ["gravityWell", "staticField"]
const LONG_ORDINARY_ITEMS := ["deep_zero_pin", "buckler_array", "triage_broadcast"]
const LONG_RELIC_ITEMS := ["martyrdomProtocol", "openingGambit"]
const FOOTER_GEAR_ITEMS := ["bounty_chip", "breach_tip", "mirror_plate"]

var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_ordinary(0, 0)
	await _test_relics()
	await _test_long_copy_layout()
	await _test_footer_stability()
	await _test_ordinary(132, 56)  # Pixel-8 budget: cutout top + gesture bottom
	PixelUI.safe_top = 0
	PixelUI.safe_bottom = 0
	if _failed == 0:
		print("[REWARD_MODEL] PASS")
		quit(0)
	else:
		print("[REWARD_MODEL] FAIL - %d assertion(s)" % _failed)
		quit(1)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  ok   %s" % label)
	else:
		_failed += 1
		print("  FAIL %s" % label)


func _boot_reward(force_items: Array, safe_top: int, safe_bottom: int) -> void:
	PixelUI.safe_top = safe_top
	PixelUI.safe_bottom = safe_bottom
	var gs: Node = root.get_node("/root/GameState")
	gs.call("reset_run")
	gs.call("start_run", SQUAD, "facility")
	gs.call("advance_to_next_battle")
	gs.set("pending_reward_item_ids", force_items.duplicate())
	gs.set("claimed_reward_item_id", "")
	change_scene_to_file(REWARD_SCENE)
	var retries := 120
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == REWARD_SCENE:
			break
	# Let layout flush (rows size themselves over a couple of frames).
	for i in 6:
		await process_frame


# Drive the control's gui_input signal directly — the same connection a real
# tap exercises. (Headless push_input hit-testing is unreliable with the dummy
# DisplayServer; the windowed capture harness carries the same fallback.)
func _tap(control: Control) -> void:
	var pos: Vector2 = control.global_position + control.size * 0.5
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = pos
	press.global_position = pos
	control.emit_signal("gui_input", press)


# Match by the `reward_kind` meta (Godot @-renames duplicate sibling names, so
# name prefixes are unreliable); results in child order.
func _reward_panels(base: Node, kind: String) -> Array:
	var found: Array = []
	var stack: Array = [base]
	while not stack.is_empty():
		var node: Node = stack.pop_front()
		if node is PanelContainer and str(node.get_meta("reward_kind", "")) == kind:
			found.append(node)
		for child in node.get_children():
			stack.push_back(child)
	return found


# Every ITEM-ART icon under `base` (tagged `item_icon` by
# PixelUI.make_integer_icon) must render at an integer multiple of its native
# size; low-res (<=48) natives must sit at exactly 4x. Effect-pip glyphs are
# atlas crops and are out of scope on purpose.
func _check_integer_icons(base: Node, label: String) -> void:
	var rects: Array = []
	var stack: Array = [base]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is TextureRect and (node as TextureRect).texture != null and node.get_meta("item_icon", false):
			rects.append(node)
		for child in node.get_children():
			stack.push_back(child)
	_check(not rects.is_empty(), "%s: icon TextureRect present" % label)
	for rect_variant in rects:
		var rect: TextureRect = rect_variant
		var native_w: float = float(rect.texture.get_width())
		var shown_w: float = rect.size.x
		if native_w <= 0.0 or shown_w <= 0.0:
			continue
		var ratio: float = shown_w / native_w
		var is_integer: bool = absf(ratio - roundf(ratio)) < 0.001 and ratio >= 0.999
		_check(is_integer, "%s: icon %s renders %sx%s at %.3fx native (integer)" % [
			label, rect.texture.resource_path.get_file(), shown_w, rect.size.y, ratio])
		if native_w <= 48.0:
			_check(absf(ratio - 4.0) < 0.001, "%s: low-res icon at exactly 4x" % label)


func _test_ordinary(safe_top: int, safe_bottom: int) -> void:
	print("-- ordinary rewards (insets %d,%d)" % [safe_top, safe_bottom])
	await _boot_reward(ORDINARY_ITEMS, safe_top, safe_bottom)
	var gs: Node = root.get_node("/root/GameState")
	var screen: Node = current_scene

	# T1 rows, not squares
	var rows: Array = _reward_panels(screen, "row")
	_check(rows.size() == 3, "T1 three RewardRow nodes (found %d)" % rows.size())
	if rows.size() != 3:
		return
	for row_variant in rows:
		var row: Control = row_variant
		_check(row.size.y >= 96.0, "T1 row height %.0f >= 96" % row.size.y)
		_check(row.size.x > row.size.y, "T1 row is wide (w %.0f > h %.0f)" % [row.size.x, row.size.y])
	_check_fixed_row_layout(screen, rows, "T10")

	# T2 confirm disabled before selection
	var confirm: Button = screen.get("_confirm_button") as Button
	_check(confirm != null and confirm.disabled, "T2 CONFIRM disabled with no selection")

	# T3 tap selects, does not commit
	_tap(rows[0] as Control)
	await process_frame
	await process_frame
	_check(str(screen.get("_selected_item_id")) == ORDINARY_ITEMS[0], "T3 tap selects row 0")
	_check(str(gs.get("claimed_reward_item_id")) == "", "T3 tap did NOT commit")
	_check(confirm != null and not confirm.disabled, "T3 CONFIRM armed after selection")

	# T4 tapping another row moves the selection
	_tap(rows[2] as Control)
	await process_frame
	await process_frame
	_check(str(screen.get("_selected_item_id")) == ORDINARY_ITEMS[2], "T4 selection moved to row 2")
	_check(str(gs.get("claimed_reward_item_id")) == "", "T4 still not committed")

	# T5 integer icon law
	_check_integer_icons(screen.get("reward_cards"), "T5")

	# T9 containment at this budget
	var vp_h: float = (screen as Control).get_viewport_rect().size.y
	if confirm != null:
		var confirm_bottom: float = confirm.global_position.y + confirm.size.y
		_check(confirm_bottom <= vp_h - float(safe_bottom) + 0.5,
			"T9 CONFIRM bottom %.0f inside safe box (vp %.0f - inset %d)" % [confirm_bottom, vp_h, safe_bottom])
	for row_variant in rows:
		var row: Control = row_variant
		_check(row.global_position.x >= -0.5, "T9 row left edge on-screen")
		_check(row.global_position.x + row.size.x <= (screen as Control).get_viewport_rect().size.x + 0.5,
			"T9 row right edge on-screen")

	# T6 confirm commits
	confirm.emit_signal("pressed")
	await process_frame
	_check(str(gs.get("claimed_reward_item_id")) == ORDINARY_ITEMS[2], "T6 CONFIRM committed the selection")


func _test_footer_stability() -> void:
	print("-- reward footer stability")
	await _boot_reward(FOOTER_GEAR_ITEMS, 0, 0)
	var screen: Node = current_scene
	var scroll := screen.get_node_or_null("Content/VBox/RewardScroll") as ScrollContainer
	var rows: Array = _reward_panels(screen, "row")
	if scroll == null or rows.is_empty():
		_check(false, "T12 gear footer setup")
		return
	var height_before: float = scroll.size.y
	_tap(rows[0] as Control)
	for i in 3:
		await process_frame
	_check(absf(scroll.size.y - height_before) < 0.1, "T12 EQUIP TO keeps reward scroll height fixed")
	var footer: Label = screen.get_node_or_null("Content/VBox/FooterLabel") as Label
	_check(footer != null and footer.visible and footer.custom_minimum_size.y > 0.0, "T12 footer reserves status space")


func _test_relics() -> void:
	print("-- relic cache (ceremonial)")
	await _boot_reward(RELIC_ITEMS, 0, 0)
	var screen: Node = current_scene
	var cards: Array = _reward_panels(screen, "relic")
	_check(cards.size() == 2, "T7 two RelicCard nodes (found %d)" % cards.size())
	_check_relic_layout(screen, cards, "T11")
	_check_integer_icons(screen.get("reward_cards"), "T8")


func _test_long_copy_layout() -> void:
	print("-- long supported reward copy")
	await _boot_reward(LONG_ORDINARY_ITEMS, 0, 0)
	var screen: Node = current_scene
	var rows: Array = _reward_panels(screen, "row")
	_check(rows.size() == 3, "T10 long-copy rows render")
	_check_fixed_row_layout(screen, rows, "T10 long-copy")

	await _boot_reward(LONG_RELIC_ITEMS, 0, 0)
	screen = current_scene
	var cards: Array = _reward_panels(screen, "relic")
	_check(cards.size() == 2, "T11 long-copy relic cards render")
	_check_relic_layout(screen, cards, "T11 long-copy")
	for card_variant in cards:
		var card: Control = card_variant
		var description: Label = card.find_child("RelicDescription", true, false) as Label
		_check(description != null and not description.clip_text and description.size.y >= 100.0,
			"T11 long relic description reserves unclipped space")


func _check_fixed_row_layout(screen: Node, rows: Array, label: String) -> void:
	if rows.is_empty():
		return
	var first: Control = rows[0] as Control
	for row_variant in rows:
		var row: Control = row_variant
		_check(absf(row.size.y - first.size.y) < 0.1, "%s equal row heights" % label)
		var description: Label = row.find_child("RewardDescriptionSlot", true, false) as Label
		_check(description != null and description.max_lines_visible == 2 and description.size.y >= 100.0,
			"%s fixed two-line description slot" % label)
	_check_group_centered(screen, rows, label)


func _check_relic_layout(screen: Node, cards: Array, label: String) -> void:
	if cards.is_empty():
		return
	var scroll: Control = screen.get("reward_scroll") as Control
	var first: Control = cards[0] as Control
	for card_variant in cards:
		var card: Control = card_variant
		_check(absf(card.size.x - first.size.x) < 0.1, "%s equal relic widths" % label)
		_check(absf((card.global_position.x + card.size.x * 0.5) - (scroll.global_position.x + scroll.size.x * 0.5)) < 1.0,
			"%s relic horizontally centered" % label)
	# The runtime caps an ultra-wide desktop viewport at 1000px, while phone
	# layouts use at least 90% of the safe content width.
	_check(first.size.x >= minf(scroll.size.x * 0.9, 1000.0), "%s relic uses near-full safe width" % label)
	_check_group_centered(screen, cards, label)


func _check_group_centered(screen: Node, panels: Array, label: String) -> void:
	if panels.is_empty():
		return
	var title: Control = screen.get("reward_title_label") as Control
	var first: Control = panels[0] as Control
	var last: Control = panels[panels.size() - 1] as Control
	var group_top: float = first.global_position.y
	var group_bottom: float = last.global_position.y + last.size.y
	var top_spacer: Control = screen.find_child("RewardGroupTopSpacer", true, false) as Control
	var bottom_spacer: Control = screen.find_child("RewardGroupBottomSpacer", true, false) as Control
	if top_spacer != null and bottom_spacer != null and top_spacer.size.y > 0.0 and bottom_spacer.size.y > 0.0:
		_check(absf(top_spacer.size.y - bottom_spacer.size.y) < 1.5,
			"%s choice group centered below heading" % label)
	else:
		# On constrained layouts the spacers collapse and the ScrollContainer
		# keeps the group reachable rather than forcing clipped cards.
		_check(group_top >= title.global_position.y + title.size.y - 0.5,
			"%s constrained choice group starts below heading" % label)
