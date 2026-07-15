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
extends SceneTree

const REWARD_SCENE := "res://scenes/ui/RewardScreen.tscn"
const SQUAD := ["shield", "avalanche", "pulse"]
const ORDINARY_ITEMS := ["patch_kit", "scrap_plate", "momentum_core"]
const RELIC_ITEMS := ["gravityWell", "staticField"]

var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_ordinary(0, 0)
	await _test_relics()
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


func _test_relics() -> void:
	print("-- relic cache (ceremonial)")
	await _boot_reward(RELIC_ITEMS, 0, 0)
	var screen: Node = current_scene
	var cards: Array = _reward_panels(screen, "relic")
	_check(cards.size() == 2, "T7 two RelicCard nodes (found %d)" % cards.size())
	_check_integer_icons(screen.get("reward_cards"), "T8")
