# Headless regression for the framing editor (DEV ONLY).
#   <godot> --headless --path . res://dev/framing_editor/FramingEditorTest.tscn
# Drives the editor through its key handler and checks the data AND the live
# previews respond; saves only to user:// and asserts the real
# portrait_anchors.json is byte-identical afterwards.
extends Node

const FIXTURE_PATH := "res://dev/framing_editor/framing_editor_fixture.json"

var _failures: int = 0
var _checks: int = 0
var editor: Node


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("  FAIL: %s" % label)


func _key(code: Key, shift: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	ev.shift_pressed = shift
	editor.handle_key(ev)


func _settle() -> void:
	for i in 3:
		await get_tree().process_frame


# The art TextureRect of preview cell `index` (placed by a framing helper).
func _preview_rect(index: int) -> TextureRect:
	var cells: Array = editor._previews.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())
	if index >= cells.size():
		return null
	var stack: Array = [cells[index]]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is TextureRect and node.has_meta("framing_helper"):
			return node
		for child in node.get_children():
			stack.push_back(child)
	return null


func _run() -> void:
	var real_path: String = PixelUI.FRAMING_DATA_PATH
	var real_before: String = FileAccess.get_file_as_string(real_path)
	editor = (load("res://dev/framing_editor/FramingEditor.tscn") as PackedScene).instantiate()
	add_child(editor)
	await _settle()
	editor.save_path = "user://framing_editor_test.json"

	# 1. Load + serialize is byte-exact (Save never reformats the file).
	_check(editor.serialize() == real_before, "serialize() round-trips portrait_anchors.json byte-exact")

	# The behaviour checks below start from a frozen fixture, not the live file,
	# so Kev's framing pass never moves their starting state (engineer without
	# anchor framing, patrol_elite without an entry, Nanite Field's stray flag
	# pending). Copied to user:// so a save still never touches res://.
	var fixture: String = FileAccess.get_file_as_string(FIXTURE_PATH)
	var copy := FileAccess.open(editor.save_path, FileAccess.WRITE)
	copy.store_string(fixture)
	copy.close()
	editor.load_data(editor.save_path)
	await _settle()

	# 2. Hero: anchor framing on, then a head_top nudge moves the battle card.
	editor.select_section("heroes")
	editor.select_asset("engineer")
	await _settle()
	var sites: Array = editor.Sites.sites_for("heroes")
	_check(editor._previews.get_child_count() == sites.size(), "every hero site previews (%d)" % sites.size())
	var rect: TextureRect = _preview_rect(0)
	_check(rect != null, "battle-card preview placed by a helper")
	var legacy_pos: Vector2 = rect.position if rect else Vector2.ZERO
	_key(KEY_A)
	await _settle()
	_check(bool(editor.entry().get("use_anchors", false)), "A turns anchor framing on")
	var anchored: TextureRect = _preview_rect(0)
	_check(anchored != null and anchored.position != legacy_pos, "anchor framing re-frames the battle card preview")
	# One framing, every screen: the head top and chin sit at the SAME fraction
	# of the frame height on every portrait site, whatever its size.
	var target: Dictionary = PixelUI.framing_target("heroes")
	var e_now: Dictionary = editor.entry()
	var worst: float = 0.0
	for i in sites.size():
		var r: TextureRect = _preview_rect(i)
		if r == null:
			worst = 999.0
			continue
		var fh: float = (sites[i]["size"] as Vector2).y
		var s: float = r.size.y / float(r.texture.get_height())
		var region_y: float = PixelUI.framing_region(r.texture).position.y
		var top_frac: float = (r.position.y + (float(e_now["head_top"]) - region_y) * s) / fh
		var chin_frac: float = (r.position.y + (float(e_now["chin"]) - region_y) * s) / fh
		worst = maxf(worst, maxf(absf(top_frac - float(target["head_top"])),
			absf(chin_frac - float(target["head_top"]) - float(target["head_height"]))))
	_check(worst < 0.001, "anchored head sits at the target fractions on all %d sites (worst %.4f)" % [sites.size(), worst])
	var top_before: int = int(editor.entry()["head_top"])
	var pos_before: Vector2 = anchored.position if anchored else Vector2.ZERO
	_key(KEY_DOWN, true)
	await _settle()
	_check(int(editor.entry()["head_top"]) == top_before + 5, "Shift+Down nudges head_top 5 px")
	var nudged: TextureRect = _preview_rect(0)
	_check(nudged != null and nudged.position != pos_before, "the nudge moves the live preview")
	_key(KEY_TAB)
	_check(editor.handle == "chin", "Tab selects the chin line")
	_key(KEY_UP)
	_check(int(editor.entry()["chin"]) == 289, "Up nudges chin 1 px (290 -> 289)")
	_key(KEY_RIGHT)
	_check(editor.entry().has("center_x"), "Left/Right set the centre line")
	for i in 4:
		editor.undo()
	await _settle()
	_check(int(editor.entry().get("head_top", -1)) == top_before and not editor.entry().has("use_anchors"), "undo restores head_top and anchor framing off")
	var restored: TextureRect = _preview_rect(0)
	_check(restored != null and restored.position.is_equal_approx(legacy_pos), "undo restores the legacy preview exactly")

	# 3. Enemy with no anchors: switching anchor framing on seeds the lines from
	#    the current framing, so the battle card barely moves.
	editor.select_section("enemies")
	editor.select_asset("patrol_elite")
	await _settle()
	var enemy_rect: TextureRect = _preview_rect(0)
	var enemy_legacy: Rect2 = Rect2(enemy_rect.position, enemy_rect.size) if enemy_rect else Rect2()
	_check(editor.entry().is_empty(), "patrol_elite starts with no framing entry")
	_key(KEY_A)
	await _settle()
	var seeded: TextureRect = _preview_rect(0)
	var drift: float = (seeded.position - enemy_legacy.position).length() if seeded else 999.0
	_check(editor.entry().has("head_top") and editor.entry().has("chin"), "A seeds head_top/chin for an unanchored enemy")
	_check(drift < 12.0, "seeded anchors keep the battle-card framing (drift %.1f px)" % drift)
	editor.undo()
	await _settle()
	_check(editor.entry().is_empty(), "undo removes the seeded entry")

	# 4. Relic stray flag: accept copies the suggestion into insets and the
	#    texture region drops the fragment; undo brings it back.
	editor.select_section("relics")
	editor.select_asset("naniteField")
	await _settle()
	_check(editor.stray_pending("relics", "naniteField"), "Nanite Field carries a pending stray flag")
	editor.stray_only = true
	editor._refresh_list()
	var flagged_keys: Array = editor.visible_assets.map(func(a: Dictionary) -> String: return a["key"])
	_check(flagged_keys.has("naniteField") and flagged_keys.size() < editor.assets.size(), "stray filter narrows the list (%d of %d)" % [flagged_keys.size(), editor.assets.size()])
	editor.stray_only = false
	_key(KEY_Y)
	await _settle()
	var insets: Dictionary = editor.entry().get("insets", {})
	_check(int(insets.get("left", 0)) == 44, "Y accepts the suggested left inset (44)")
	var relic_tex: Texture2D = editor.texture_for("relics", editor.current)
	_check(relic_tex is AtlasTexture and int((relic_tex as AtlasTexture).region.position.x) == 44, "the relic texture drops the trimmed columns")
	_check(not editor.stray_pending("relics", "naniteField"), "an accepted flag is no longer pending")
	editor.undo()
	await _settle()
	_check(editor.entry().is_empty(), "undo clears the accepted inset")
	_key(KEY_N)
	_check(str(editor.entry().get("stray", "")) == "rejected" and not editor.stray_pending("relics", "naniteField"), "N rejects the flag")
	editor.undo()

	# 5. Item centre and scale reach the integer-law reward row.
	editor.select_section("items")
	editor.select_asset("combat_plating")
	await _settle()
	var reward_before: TextureRect = _preview_rect(0)
	var reward_size: Vector2 = reward_before.size if reward_before else Vector2.ZERO
	_key(KEY_RIGHT)
	_key(KEY_RIGHT)
	_check(int(editor.entry().get("center_x", 0)) == 66, "Right x2 moves the item centre marker 2 px right (64 -> 66)")
	_key(KEY_EQUAL, true)
	await _settle()
	_check(is_equal_approx(float(editor.entry().get("scale", 1.0)), 1.25), "Shift + '+' scales 1.25")
	var reward_after: TextureRect = _preview_rect(0)
	_check(reward_after != null and reward_after.size != reward_size, "scale changes the reward-row art (integer law)")
	var ratio: float = reward_after.size.x / reward_after.texture.get_width() if reward_after else 0.0
	_check(absf(ratio - roundf(ratio)) < 0.001, "reward-row art stays an integer multiple (%.3f)" % ratio)

	# 6. Reviewed, grid, onion.
	_key(KEY_R)
	_check(editor.asset_status("items", "combat_plating") == "reviewed", "R marks reviewed")
	_key(KEY_O, true)
	await _settle()
	var ghosts: int = 0
	for cell in editor._previews.get_children():
		if cell.is_queued_for_deletion():
			continue
		for node in cell.find_children("*", "Control", true, false):
			if is_equal_approx((node as Control).modulate.a, editor.ONION_ALPHA):
				ghosts += 1
	_check(editor.onion_on and ghosts > 0, "Shift+O sets an onion reference drawn at 40%% (%d ghosts)" % ghosts)
	_key(KEY_G)
	await _settle()
	var grid_cells: int = editor._grid.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion()).size()
	_check(editor.grid_mode and grid_cells == editor.visible_assets.size(), "grid shows every asset (%d)" % grid_cells)
	_key(KEY_G)

	# 7. Save writes the edits (to user://), and the real file is untouched.
	_check(editor.save() == OK, "save to user:// succeeds")
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(editor.save_path))
	var saved_entry: Dictionary = (saved as Dictionary).get("items", {}).get("combat_plating", {}) if saved is Dictionary else {}
	_check(saved_entry.get("reviewed", false) == true and int(saved_entry.get("center_x", 0)) == 66, "saved file carries the edits")
	_check(FileAccess.get_file_as_string(real_path) == real_before, "the real portrait_anchors.json is untouched")

	if _failures == 0:
		print("[FRAMING_EDITOR] PASS - %d checks" % _checks)
	else:
		print("[FRAMING_EDITOR] FAIL - %d of %d checks failed" % [_failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)
