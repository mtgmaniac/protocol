# Framing editor — DEV ONLY (dev/ is excluded from every export preset).
#
# A visual front end for assets/portraits/portrait_anchors.json: Kev drags the
# head_top / chin / centre lines (portraits) or the visual centre and scale
# (items, relics) and trims stray edge pixels, while every screen the asset
# appears on previews live, side by side, at real in-game size — through the
# SAME helpers the screens call. Nothing here derives anchors from pixels; the
# stray-pixel scan only suggests insets for Kev to accept or reject.
#
# Open:  godot --path . res://dev/framing_editor/FramingEditor.tscn
#        (or open the scene in the Godot editor and press F6)
# Controls: docs/tools/FRAMING_TOOL.md
#
# --framing-sheet=<png> renders the capture sheet (one sample asset of each
# type on every screen that shows it) and quits.
extends Control

const Sites := preload("res://dev/framing_editor/framing_sites.gd")
const STRAY_SCAN_PATH := "res://dev/framing_editor/stray_scan.json"
const SECTIONS: Array[String] = ["heroes", "enemies", "bosses", "items", "relics"]
const SECTION_LABELS := {"heroes": "Heroes", "enemies": "Enemies", "bosses": "Bosses", "items": "Items", "relics": "Relics"}
const TOP_LEVEL_ORDER: Array[String] = ["_schema", "_doc", "_crop_tool", "_targets", "heroes", "enemies", "bosses", "items", "relics"]
const SHEET_SAMPLES := [
	["heroes", "engineer"], ["enemies", "scrap_drone"], ["bosses", "scrapmaster"],
	["items", "patch_kit"], ["items", "combat_plating"], ["relics", "naniteField"],
]
const ONION_ALPHA := 0.4
const SCALE_STEP := 0.05
const EDITOR_WINDOW := Vector2i(1800, 1000)

var data: Dictionary = {}
var save_path: String = PixelUI.FRAMING_DATA_PATH
var stray_scan: Dictionary = {}
var section: String = "heroes"
var assets: Array[Dictionary] = []
var visible_assets: Array[Dictionary] = []
var current: Dictionary = {}
var handle: String = "head_top"
var undo_stack: Array[Dictionary] = []
var dirty := false
var show_guides := true
var grid_mode := false
var stray_only := false
var onion_on := false
var onion_ref: Dictionary = {}
var preview_scale := 0.5
var grid_site_index := 0
var _tex_cache: Dictionary = {}
var _dragging := ""
var _syncing := false

var _tabs: Array[Button] = []
var _list: ItemList
var _source: Control
var _info: Label
var _status: Label
var _previews: HFlowContainer
var _grid_scroll: ScrollContainer
var _grid: HFlowContainer
var _grid_site: OptionButton
var _body: HSplitContainer
var _inset_boxes: Dictionary = {}
var _toggle_buttons: Dictionary = {}


func _ready() -> void:
	var sheet_path: String = ""
	var shot_path: String = ""
	var select: String = ""
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--framing-sheet="):
			sheet_path = arg.get_slice("=", 1)
		elif arg.begins_with("--framing-shot="):
			shot_path = arg.get_slice("=", 1)
		elif arg.begins_with("--framing-select="):
			select = arg.get_slice("=", 1)
	var header: Node = get_node_or_null("/root/PersistentHeader")
	if header is CanvasLayer:
		(header as CanvasLayer).visible = false
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	if DisplayServer.get_name() != "headless":
		get_window().unresizable = false
		get_window().size = EDITOR_WINDOW
		get_window().move_to_center()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	data = PixelUI.framing_data()
	_load_stray_scan()
	_build_ui()
	select_section("heroes")
	if select.contains("/"):
		select_section(select.get_slice("/", 0))
		select_asset(select.get_slice("/", 1))
	if sheet_path != "":
		await render_sheet(sheet_path)
		get_tree().quit(0)
	elif shot_path != "":
		# Docs / review aid: screenshot the editor itself, then quit.
		for i in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(shot_path) if shot_path.begins_with("res://") else shot_path)
		get_tree().quit(0)


# ── Data ────────────────────────────────────────────────────────────────────
func load_data(path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	data = parsed if parsed is Dictionary else {}
	PixelUI.set_framing_data(data)
	save_path = path
	undo_stack.clear()
	dirty = false
	_tex_cache.clear()
	select_section(section)


func _load_stray_scan() -> void:
	if FileAccess.file_exists(STRAY_SCAN_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STRAY_SCAN_PATH))
		if parsed is Dictionary:
			stray_scan = parsed


func entry(create: bool = false) -> Dictionary:
	if current.is_empty():
		return {}
	var sec: Dictionary = data.get(section, {})
	if not data.has(section):
		data[section] = sec
	if not sec.has(current["key"]):
		if not create:
			return {}
		sec[current["key"]] = {}
	return sec[current["key"]]


func _push_undo() -> void:
	undo_stack.append(data.duplicate(true))
	if undo_stack.size() > 200:
		undo_stack.pop_front()
	dirty = true


func undo() -> void:
	if undo_stack.is_empty():
		return
	var snapshot: Dictionary = undo_stack.pop_back()
	data.clear()
	data.merge(snapshot, true)
	_tex_cache.clear()
	dirty = true
	_refresh_all()


# The saved layout matches the hand-kept file: one line per entry, whole
# numbers without a decimal point, so a load + save round trip is byte-exact.
func serialize() -> String:
	var lines: Array[String] = ["{"]
	var keys: Array = []
	for k in TOP_LEVEL_ORDER:
		if data.has(k):
			keys.append(k)
	for k in data.keys():
		if not keys.has(k):
			keys.append(k)
	for i in keys.size():
		var k: String = keys[i]
		var comma: String = "," if i < keys.size() - 1 else ""
		var v: Variant = data[k]
		if (SECTIONS.has(k) or k == "_targets") and v is Dictionary:
			var sec: Dictionary = v
			if sec.is_empty():
				lines.append("  %s: {}%s" % [JSON.stringify(k), comma])
				continue
			lines.append("  %s: {" % JSON.stringify(k))
			var entry_keys: Array = sec.keys()
			for j in entry_keys.size():
				lines.append("    %s: %s%s" % [JSON.stringify(entry_keys[j]), _json(sec[entry_keys[j]]),
					"," if j < entry_keys.size() - 1 else ""])
			lines.append("  }" + comma)
		elif v is Array:
			lines.append("  %s: [" % JSON.stringify(k))
			var arr: Array = v
			for j in arr.size():
				lines.append("    %s%s" % [_json(arr[j]), "," if j < arr.size() - 1 else ""])
			lines.append("  ]" + comma)
		else:
			lines.append("  %s: %s%s" % [JSON.stringify(k), _json(v), comma])
	lines.append("}")
	return "\n".join(lines) + "\n"


func _json(v: Variant) -> String:
	match typeof(v):
		TYPE_BOOL:
			return "true" if v else "false"
		TYPE_INT:
			return str(v)
		TYPE_FLOAT:
			var f: float = v
			if absf(f - roundf(f)) < 0.0000001 and absf(f) < 1.0e9:
				return str(int(roundf(f)))
			return String.num(f, 6)
		TYPE_STRING, TYPE_STRING_NAME:
			return JSON.stringify(str(v))
		TYPE_ARRAY:
			var parts: Array[String] = []
			for item in v:
				parts.append(_json(item))
			return "[" + ", ".join(parts) + "]"
		TYPE_DICTIONARY:
			var parts: Array[String] = []
			for key in (v as Dictionary).keys():
				parts.append("%s: %s" % [JSON.stringify(str(key)), _json(v[key])])
			return "{" + ", ".join(parts) + "}"
	return "null"


func save() -> Error:
	_prune_empty()
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		_set_status("SAVE FAILED: %s" % error_string(FileAccess.get_open_error()))
		return FileAccess.get_open_error()
	file.store_string(serialize())
	file.close()
	dirty = false
	_set_status("Saved %s" % save_path)
	_refresh_list()
	return OK


func _prune_empty() -> void:
	for sec_name in SECTIONS:
		var sec: Dictionary = data.get(sec_name, {})
		for key in sec.keys():
			var e: Dictionary = sec[key]
			if e.has("insets") and (e["insets"] as Dictionary).is_empty():
				e.erase("insets")
			if e.is_empty():
				sec.erase(key)


# ── Assets ──────────────────────────────────────────────────────────────────
func _build_assets(sec: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match sec:
		"heroes":
			for unit_variant in DataManager.units.values():
				var unit: UnitData = unit_variant
				var file: String = str(DataManager.HERO_PORTRAIT_BY_ID.get(unit.id, ""))
				if file == "":
					continue
				out.append({"key": file.get_basename(), "label": unit.display_name, "path": DataManager.HERO_PORTRAIT_ROOT + file})
				for evo in unit.evolution_paths:
					var key: String = "%s_%s" % [unit.id, str(evo.get("id", ""))]
					var path: String = "%s%s.png" % [DataManager.HERO_PORTRAIT_ROOT, key]
					if ResourceLoader.exists(path):
						out.append({"key": key, "label": "%s: %s" % [unit.display_name, str(evo.get("name", evo.get("id", "")))], "path": path})
		"enemies", "bosses":
			for enemy_variant in DataManager.enemies.values():
				var enemy: EnemyData = enemy_variant
				if DataManager.enemy_framing_section(enemy.display_name) != sec:
					continue
				var file: String = DataManager.enemy_portrait_file(enemy.display_name)
				var path: String = file if file.begins_with("res://") else DataManager.ENEMY_PORTRAIT_ROOT + file
				out.append({"key": file.get_file().get_basename(), "label": enemy.display_name, "path": path, "enemy_name": enemy.display_name})
		_:
			for item_variant in DataManager.items.values():
				var item: ItemData = item_variant
				var is_relic: bool = item.item_type == "relic"
				if is_relic != (sec == "relics"):
					continue
				var path: String = str((DataManager.RELIC_ICON_BY_ID if is_relic else DataManager.ITEM_ICON_BY_ID).get(item.id, ""))
				if path == "" or not ResourceLoader.exists(path):
					continue
				out.append({"key": item.id, "label": item.display_name, "path": path, "item_type": item.item_type})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["key"]) < str(b["key"]))
	return out


func is_portrait_section(sec: String = "") -> bool:
	return PixelUI.FRAMING_PORTRAIT_SECTIONS.has(sec if sec != "" else section)


func texture_for(sec: String, asset: Dictionary) -> Texture2D:
	var cache_key: String = "%s/%s" % [sec, asset["key"]]
	if _tex_cache.has(cache_key):
		return _tex_cache[cache_key]
	var tex: Texture2D
	match sec:
		"heroes":
			tex = DataManager._finalize_hero_portrait(load(asset["path"]) as Texture2D, asset["key"])
		"enemies", "bosses":
			tex = DataManager._load_enemy_portrait(asset["enemy_name"])
		_:
			tex = PixelUI.framed_art_texture(load(asset["path"]) as Texture2D, sec, asset["key"])
	_tex_cache[cache_key] = tex
	return tex


func _invalidate_current() -> void:
	if not current.is_empty():
		_tex_cache.erase("%s/%s" % [section, current["key"]])


# Status: none / anchored / reviewed (+ live anchor framing, + stray pending).
func asset_status(sec: String, key: String) -> String:
	var e: Dictionary = (data.get(sec, {}) as Dictionary).get(key, {})
	if bool(e.get("reviewed", false)):
		return "reviewed"
	var anchored: bool = e.has("head_top") if is_portrait_section(sec) else (e.has("center_x") or e.has("center_y") or e.has("scale"))
	if anchored or e.has("insets"):
		return "anchored"
	return "none"


func stray_pending(sec: String, key: String) -> bool:
	var flag: Dictionary = (stray_scan.get(sec, {}) as Dictionary).get(key, {})
	if flag.is_empty():
		return false
	var e: Dictionary = (data.get(sec, {}) as Dictionary).get(key, {})
	if str(e.get("stray", "")) == "rejected":
		return false
	var have: Dictionary = e.get("insets", {})
	for edge in (flag.get("insets", {}) as Dictionary).keys():
		if int(have.get(edge, 0)) < int(flag["insets"][edge]):
			return true
	return false


# ── Editing ─────────────────────────────────────────────────────────────────
# First anchor edit on a portrait with no head anchors: seed them from the
# CURRENT on-screen framing (the battle card's legacy look inverted through
# the class target), so switching anchor framing on changes nothing until Kev
# moves a line. Arithmetic on the framing, never a reading of the pixels.
func _seed_portrait_anchors(e: Dictionary) -> void:
	if e.has("head_top") and e.has("chin"):
		return
	var tex: Texture2D = texture_for(section, current)
	var probe_parent := Control.new()
	probe_parent.scale = Vector2.ONE * preview_scale
	add_child(probe_parent)
	var rect := TextureRect.new()
	rect.texture = tex
	probe_parent.add_child(rect)
	var fh: float = PixelUI.HERO_PORTRAIT_REGION.y
	var fw: float = PixelUI.HERO_PORTRAIT_REGION.x
	var was_live: bool = bool(e.get("use_anchors", false))
	e.erase("use_anchors")
	PixelUI.cover_fit_portrait(rect, PixelUI.HERO_PORTRAIT_REGION)
	if was_live:
		e["use_anchors"] = true
	var region: Rect2 = PixelUI.framing_region(tex)
	var s: float = rect.size.y / float(tex.get_height())
	var target: Dictionary = PixelUI.framing_target(section)
	var t_top: float = float(target.get("head_top", 0.12))
	var t_h: float = float(target.get("head_height", 0.42))
	var source_size: Vector2 = tex.get_meta("framing_source_size", region.size)
	var cx: float = region.position.x + (fw * 0.5 - rect.position.x) / s
	if bool(tex.get_meta("framing_mirrored", false)):
		cx = source_size.x - cx
	e["head_top"] = int(roundf(region.position.y + (t_top * fh - rect.position.y) / s))
	e["chin"] = int(roundf(region.position.y + ((t_top + t_h) * fh - rect.position.y) / s))
	if not e.has("center_x"):
		e["center_x"] = int(roundf(cx))
	probe_parent.queue_free()


func _source_size() -> Vector2:
	var tex: Texture2D = load(current["path"]) as Texture2D
	return Vector2(tex.get_width(), tex.get_height()) if tex != null else Vector2.ONE


func set_handle_value(name: String, value: int) -> void:
	if current.is_empty():
		return
	var size: Vector2 = _source_size()
	var e: Dictionary = entry(true)
	if is_portrait_section():
		_seed_portrait_anchors(e)
		e["use_anchors"] = true
		match name:
			"head_top":
				value = clampi(value, 0, int(e["chin"]) - 16)
			"chin":
				value = clampi(value, int(e["head_top"]) + 16, int(size.y))
			"center_x":
				value = clampi(value, 0, int(size.x))
	else:
		var had_entry_art: bool = e.has("center_x") or e.has("center_y") or e.has("scale") or e.has("insets")
		if not e.has("center_x"):
			e["center_x"] = int(size.x / 2)
		if not e.has("center_y"):
			e["center_y"] = int(size.y / 2)
		value = clampi(value, 0, int(size.x if name == "center_x" else size.y))
		if not had_entry_art:
			_invalidate_current()  # the first entry gives the item its per-id framed texture
	e[name] = value
	_refresh_current()


func nudge(name: String, delta: int) -> void:
	if current.is_empty():
		return
	_push_undo()
	var e: Dictionary = entry(true)
	if is_portrait_section():
		_seed_portrait_anchors(e)
	var size: Vector2 = _source_size()
	var fallback: float = size.x / 2 if name == "center_x" else size.y / 2
	set_handle_value(name, int(e.get(name, fallback)) + delta)


func change_scale(delta: float) -> void:
	if current.is_empty() or is_portrait_section():
		return
	_push_undo()
	var e: Dictionary = entry(true)
	var fresh: bool = not (e.has("center_x") or e.has("center_y") or e.has("scale") or e.has("insets"))
	e["scale"] = snappedf(clampf(float(e.get("scale", 1.0)) + delta, 0.25, 4.0), 0.01)
	if fresh:
		_invalidate_current()
	_refresh_current()


func toggle_use_anchors() -> void:
	if current.is_empty() or not is_portrait_section():
		return
	_push_undo()
	var e: Dictionary = entry(true)
	if bool(e.get("use_anchors", false)):
		e.erase("use_anchors")
	else:
		_seed_portrait_anchors(e)
		e["use_anchors"] = true
	_refresh_current()


func toggle_reviewed() -> void:
	if current.is_empty():
		return
	_push_undo()
	var e: Dictionary = entry(true)
	if bool(e.get("reviewed", false)):
		e.erase("reviewed")
	else:
		e["reviewed"] = true
	_refresh_current()


func set_inset(edge: String, value: int) -> void:
	if current.is_empty():
		return
	_push_undo()
	var e: Dictionary = entry(true)
	var insets: Dictionary = e.get("insets", {})
	if value <= 0:
		insets.erase(edge)
	else:
		insets[edge] = value
	if insets.is_empty():
		e.erase("insets")
	else:
		e["insets"] = insets
	_invalidate_current()
	_refresh_current()


func accept_stray() -> void:
	var flag: Dictionary = (stray_scan.get(section, {}) as Dictionary).get(current.get("key", ""), {})
	if flag.is_empty():
		return
	_push_undo()
	var e: Dictionary = entry(true)
	var insets: Dictionary = e.get("insets", {})
	for edge in (flag.get("insets", {}) as Dictionary).keys():
		insets[edge] = maxi(int(insets.get(edge, 0)), int(flag["insets"][edge]))
	e["insets"] = insets
	e.erase("stray")
	_invalidate_current()
	_refresh_current()


func reject_stray() -> void:
	if current.is_empty() or not (stray_scan.get(section, {}) as Dictionary).has(current["key"]):
		return
	_push_undo()
	entry(true)["stray"] = "rejected"
	_refresh_current()


func clear_entry() -> void:
	if current.is_empty() or entry().is_empty():
		return
	_push_undo()
	(data[section] as Dictionary).erase(current["key"])
	_invalidate_current()
	_refresh_current()


func set_onion_reference() -> void:
	if current.is_empty():
		return
	onion_ref = {"section": section, "asset": current.duplicate()}
	onion_on = true
	_refresh_current()


# ── Navigation ──────────────────────────────────────────────────────────────
func select_section(sec: String) -> void:
	section = sec
	assets = _build_assets(sec)
	handle = "head_top"
	for i in _tabs.size():
		_tabs[i].button_pressed = SECTIONS[i] == sec
	_grid_site.clear()
	var item_type: String = ""
	for site in Sites.sites_for(sec, item_type):
		_grid_site.add_item(site["label"])
	grid_site_index = 0
	_grid_site.select(0)
	_refresh_list()
	if not visible_assets.is_empty():
		select_asset(visible_assets[0]["key"])
	else:
		current = {}
		_refresh_current()


func select_asset(key: String) -> void:
	for asset in assets:
		if asset["key"] == key:
			current = asset
			break
	for i in visible_assets.size():
		if visible_assets[i]["key"] == key:
			_list.select(i)
			_list.ensure_current_is_visible()
	_refresh_current()


func step_asset(delta: int) -> void:
	if visible_assets.is_empty():
		return
	var index: int = 0
	for i in visible_assets.size():
		if visible_assets[i]["key"] == current.get("key", ""):
			index = i
	select_asset(visible_assets[posmod(index + delta, visible_assets.size())]["key"])


# ── Input ───────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is LineEdit:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER:
			focus.release_focus()
		return
	if handle_key(event as InputEventKey):
		get_viewport().set_input_as_handled()


func handle_key(event: InputEventKey) -> bool:
	var step: int = 5 if event.shift_pressed else 1
	if event.ctrl_pressed or event.meta_pressed:
		match event.keycode:
			KEY_Z:
				undo()
			KEY_S:
				save()
			_:
				return false
		return true
	match event.keycode:
		KEY_UP, KEY_DOWN:
			var d: int = -step if event.keycode == KEY_UP else step
			nudge(handle if is_portrait_section() else "center_y", d)
		KEY_LEFT, KEY_RIGHT:
			nudge("center_x", -step if event.keycode == KEY_LEFT else step)
		KEY_TAB:
			handle = "chin" if handle == "head_top" else "head_top"
			_refresh_current()
		KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
			change_scale(SCALE_STEP * (5.0 if event.shift_pressed else 1.0))
		KEY_MINUS, KEY_KP_SUBTRACT:
			change_scale(-SCALE_STEP * (5.0 if event.shift_pressed else 1.0))
		KEY_A:
			toggle_use_anchors()
		KEY_R:
			toggle_reviewed()
		KEY_G:
			grid_mode = not grid_mode
			_refresh_all()
		KEY_H:
			show_guides = not show_guides
			_refresh_current()
		KEY_O:
			if event.shift_pressed:
				set_onion_reference()
			else:
				onion_on = not onion_on and not onion_ref.is_empty()
				_refresh_current()
		KEY_F:
			stray_only = not stray_only
			_refresh_list()
		KEY_Y:
			accept_stray()
		KEY_N:
			reject_stray()
		KEY_P:
			preview_scale = 1.0 if preview_scale < 0.75 else 0.5
			_refresh_all()
		KEY_PAGEUP, KEY_W:
			step_asset(-1)
		KEY_PAGEDOWN, KEY_S:
			step_asset(1)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			select_section(SECTIONS[event.keycode - KEY_1])
		KEY_DELETE:
			clear_entry()
		_:
			return false
	_sync_toggles()
	return true


# ── UI ──────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var theme_override := Theme.new()
	theme_override.default_font = ThemeDB.fallback_font
	theme_override.default_font_size = 15
	theme = theme_override
	var bg := ColorRect.new()
	bg.color = PixelUI.DT_FIELD_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	root.add_child(bar)
	for i in SECTIONS.size():
		var tab := _button("%d %s" % [i + 1, SECTION_LABELS[SECTIONS[i]]], select_section.bind(SECTIONS[i]))
		tab.toggle_mode = true
		_tabs.append(tab)
		bar.add_child(tab)
	bar.add_child(VSeparator.new())
	for spec in [["grid", "G Grid"], ["guides", "H Guides"], ["onion", "O Onion"], ["stray", "F Stray only"]]:
		var b := _button(spec[1], _on_toggle.bind(spec[0]))
		b.toggle_mode = true
		_toggle_buttons[spec[0]] = b
		bar.add_child(b)
	bar.add_child(_button("Shift+O Set onion ref", set_onion_reference))
	bar.add_child(VSeparator.new())
	bar.add_child(_button("A Anchor framing", toggle_use_anchors))
	bar.add_child(_button("R Reviewed", toggle_reviewed))
	bar.add_child(_button("Ctrl+Z Undo", undo))
	bar.add_child(_button("Ctrl+S Save", save))
	bar.add_child(_button("P 0.5x / 1x", func() -> void:
		preview_scale = 1.0 if preview_scale < 0.75 else 0.5
		_refresh_all()))

	_body = HSplitContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_body)
	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(300, 0)
	_list.focus_mode = Control.FOCUS_NONE
	_list.item_selected.connect(func(i: int) -> void: select_asset(visible_assets[i]["key"]))
	_body.add_child(_list)

	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	_body.add_child(main)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(520, 0)
	main.add_child(left)
	_source = SourceView.new()
	_source.editor = self
	_source.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_source.custom_minimum_size = Vector2(520, 600)
	_source.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_source)
	var insets_row := HBoxContainer.new()
	insets_row.add_child(_label("Crop insets"))
	for edge in ["left", "top", "right", "bottom"]:
		insets_row.add_child(_label(edge))
		var box := SpinBox.new()
		box.min_value = 0
		box.max_value = 512
		box.value_changed.connect(func(v: float) -> void:
			if not _syncing:
				set_inset(edge, int(v)))
		_inset_boxes[edge] = box
		insets_row.add_child(box)
	left.add_child(insets_row)
	var stray_row := HBoxContainer.new()
	stray_row.add_child(_button("Y Accept stray suggestion", accept_stray))
	stray_row.add_child(_button("N Reject", reject_stray))
	stray_row.add_child(_button("Del Clear entry", clear_entry))
	left.add_child(stray_row)
	_info = _label("")
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_info)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(right)
	var grid_bar := HBoxContainer.new()
	grid_bar.add_child(_label("Grid frame:"))
	_grid_site = OptionButton.new()
	_grid_site.focus_mode = Control.FOCUS_NONE
	_grid_site.item_selected.connect(func(i: int) -> void:
		grid_site_index = i
		_refresh_grid())
	grid_bar.add_child(_grid_site)
	right.add_child(grid_bar)
	var preview_scroll := ScrollContainer.new()
	preview_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(preview_scroll)
	_previews = HFlowContainer.new()
	_previews.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_previews.add_theme_constant_override("h_separation", 16)
	_previews.add_theme_constant_override("v_separation", 16)
	preview_scroll.add_child(_previews)
	_grid_scroll = ScrollContainer.new()
	_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid_scroll.visible = false
	right.add_child(_grid_scroll)
	_grid = HFlowContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_grid_scroll.add_child(_grid)

	_status = _label("")
	root.add_child(_status)
	_sync_toggles()


func _button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	return b


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", PixelUI.INSPECT_TEXT)
	return l


func _on_toggle(which: String) -> void:
	match which:
		"grid":
			grid_mode = not grid_mode
			_refresh_all()
		"guides":
			show_guides = not show_guides
			_refresh_current()
		"onion":
			onion_on = not onion_on and not onion_ref.is_empty()
			_refresh_current()
		"stray":
			stray_only = not stray_only
			_refresh_list()
	_sync_toggles()


func _sync_toggles() -> void:
	if _toggle_buttons.is_empty():
		return
	(_toggle_buttons["grid"] as Button).set_pressed_no_signal(grid_mode)
	(_toggle_buttons["guides"] as Button).set_pressed_no_signal(show_guides)
	(_toggle_buttons["onion"] as Button).set_pressed_no_signal(onion_on)
	(_toggle_buttons["stray"] as Button).set_pressed_no_signal(stray_only)


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text


func _refresh_all() -> void:
	_refresh_list()
	_refresh_current()


func _refresh_list() -> void:
	visible_assets.clear()
	_list.clear()
	for asset in assets:
		var pending: bool = stray_pending(section, asset["key"])
		if stray_only and not pending:
			continue
		visible_assets.append(asset)
		var status: String = asset_status(section, asset["key"])
		var mark: String = {"none": "  ", "anchored": "A ", "reviewed": "R "}[status]
		var e: Dictionary = (data.get(section, {}) as Dictionary).get(asset["key"], {})
		var live: String = "*" if bool(e.get("use_anchors", false)) else " "
		var text: String = "%s%s%s %s" % [mark, live, "!" if pending else " ", asset["label"]]
		_list.add_item(text)
		if asset["key"] == current.get("key", ""):
			_list.select(_list.item_count - 1)


func _refresh_current() -> void:
	_refresh_list()
	_syncing = true
	var e: Dictionary = entry()
	var insets: Dictionary = e.get("insets", {})
	for edge in _inset_boxes.keys():
		(_inset_boxes[edge] as SpinBox).set_value_no_signal(float(insets.get(edge, 0)))
	_syncing = false
	_source.queue_redraw()
	_previews.get_parent().visible = not grid_mode
	_grid_scroll.visible = grid_mode
	if grid_mode:
		_refresh_grid()
	else:
		_refresh_previews()
	_info.text = _info_text()
	_set_status("%s · %s%s · preview %.1fx (desktop window = 0.5x) · %s" % [
		SECTION_LABELS[section], current.get("key", "-"), " · UNSAVED" if dirty else "",
		preview_scale, "onion: %s" % onion_ref.get("asset", {}).get("key", "none") if onion_on else "onion off"])


func _info_text() -> String:
	if current.is_empty():
		return "No assets."
	var e: Dictionary = entry()
	var lines: Array[String] = ["%s  (%s)  %s" % [current["label"], current["key"], current["path"]]]
	lines.append("Status: %s" % asset_status(section, current["key"]).to_upper())
	if is_portrait_section():
		lines.append("Anchor framing: %s   selected line: %s (Tab)" % ["ON" if bool(e.get("use_anchors", false)) else "OFF (legacy look)", handle])
		lines.append("head_top %s   chin %s   center_x %s" % [_num(e, "head_top"), _num(e, "chin"), _num(e, "center_x")])
		for legacy in ["legacy_zoom", "legacy_anchor_y", "legacy_down_px"]:
			if e.has(legacy):
				lines.append("%s %s (ignored while anchor framing is on)" % [legacy, _num(e, legacy)])
	else:
		lines.append("center %s, %s   scale %s" % [_num(e, "center_x"), _num(e, "center_y"), _num(e, "scale", 1.0)])
	var flag: Dictionary = (stray_scan.get(section, {}) as Dictionary).get(current["key"], {})
	if not flag.is_empty():
		lines.append("Stray scan: %d fragment(s), suggests %s%s" % [(flag["fragments"] as Array).size(), _json(flag["insets"]),
			"  [rejected]" if str(e.get("stray", "")) == "rejected" else ("  [pending]" if stray_pending(section, current["key"]) else "  [covered]")])
	lines.append("List: A anchored · R reviewed · * anchor framing on · ! stray flag pending")
	return "\n".join(lines)


func _num(e: Dictionary, key: String, fallback: Variant = null) -> String:
	if not e.has(key):
		return "-" if fallback == null else _json(fallback)
	return _json(e[key])


func _refresh_previews() -> void:
	for child in _previews.get_children():
		child.queue_free()
	if current.is_empty():
		return
	var tex: Texture2D = texture_for(section, current)
	for site in Sites.sites_for(section, str(current.get("item_type", ""))):
		_previews.add_child(_preview_cell(site, tex, site["label"]))


func _preview_cell(site: Dictionary, tex: Texture2D, caption: String, selected: bool = false) -> Control:
	var size: Vector2 = site["size"]
	var cell := VBoxContainer.new()
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	var frame := PanelContainer.new()
	var style: StyleBoxFlat = PixelUI.make_hard_style(PixelUI.DT_PANEL_BG, PixelUI.DT_AMBER if selected else PixelUI.DT_LINE, 2)
	style.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", style)
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cell.add_child(frame)
	# Real in-game size: the site's design px × the preview scale (0.5 = the
	# 540-wide desktop game window; 1.0 = native phone px). The helper sees
	# the scale through the canvas transform, as in game.
	var holder := Control.new()
	holder.custom_minimum_size = size * preview_scale
	holder.clip_contents = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(holder)
	var art: Control = Sites.build(site, tex)
	art.scale = Vector2.ONE * preview_scale
	holder.add_child(art)
	if onion_on and not onion_ref.is_empty():
		var ref_sec: String = onion_ref["section"]
		if is_portrait_section(ref_sec) == is_portrait_section():
			var ghost: Control = Sites.build(site, texture_for(ref_sec, onion_ref["asset"]))
			ghost.scale = Vector2.ONE * preview_scale
			ghost.modulate = Color(1, 1, 1, ONION_ALPHA)
			holder.add_child(ghost)
	if show_guides:
		var guides := GuideView.new()
		guides.portrait = site["kind"] == Sites.PORTRAIT
		guides.target = PixelUI.framing_target(section)
		guides.custom_minimum_size = size * preview_scale
		guides.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(guides)
	var label := _label("%s  %dx%d" % [caption, int(size.x), int(size.y)])
	cell.add_child(label)
	return cell


func _refresh_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	var sites: Array[Dictionary] = Sites.sites_for(section)
	if sites.is_empty():
		return
	var site: Dictionary = sites[clampi(grid_site_index, 0, sites.size() - 1)]
	for asset in visible_assets:
		var cell: Control = _preview_cell(site, texture_for(section, asset), str(asset["label"]).left(18), asset["key"] == current.get("key", ""))
		cell.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				select_asset(asset["key"]))
		_grid.add_child(cell)


# ── Capture sheet ───────────────────────────────────────────────────────────
# One sample asset of each type on every screen that shows it, rendered by the
# same site builders the previews use (the screens' own helpers and sizes).
func render_sheet(path: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1900, 1500)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var sheet := VBoxContainer.new()
	sheet.theme = theme
	sheet.position = Vector2(12, 12)
	sheet.add_theme_constant_override("separation", 10)
	var bg := ColorRect.new()
	bg.color = PixelUI.DT_FIELD_BG
	bg.size = Vector2(viewport.size)
	viewport.add_child(bg)
	viewport.add_child(sheet)
	sheet.add_child(_label("FRAMING CAPTURE SHEET - one sample per asset type on every screen that shows it (desktop game size, 0.5x design px)"))
	var saved_scale: float = preview_scale
	var saved_guides: bool = show_guides
	var saved_onion: bool = onion_on
	preview_scale = 0.5
	show_guides = false
	onion_on = false
	var rendered: int = 0
	var expected: int = 0
	var missing: Array[String] = []
	for sample in SHEET_SAMPLES:
		var sec: String = sample[0]
		var found: Dictionary = {}
		for asset in _build_assets(sec):
			if asset["key"] == sample[1]:
				found = asset
		if found.is_empty():
			missing.append("%s/%s" % sample)
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var name_label := _label("%s\n%s" % [SECTION_LABELS[sec].to_upper(), found["label"]])
		name_label.custom_minimum_size = Vector2(170, 0)
		row.add_child(name_label)
		var tex: Texture2D = texture_for(sec, found)
		var prev_section: String = section
		section = sec
		for site in Sites.sites_for(sec, str(found.get("item_type", ""))):
			expected += 1
			var cell: Control = _preview_cell(site, tex, site["label"])
			row.add_child(cell)
			if tex != null:
				rendered += 1
		section = prev_section
		sheet.add_child(row)
	preview_scale = saved_scale
	show_guides = saved_guides
	onion_on = saved_onion
	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	var out: String = path
	if out.begins_with("res://") or out.begins_with("user://"):
		out = ProjectSettings.globalize_path(out)
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var err: Error = image.save_png(out)
	var ok: bool = err == OK and missing.is_empty() and rendered == expected and expected > 0
	print("[FRAMING_SHEET] %s - %d/%d site frames%s -> %s (%s)" % ["PASS" if ok else "FAIL", rendered, expected,
		"" if missing.is_empty() else ", missing samples %s" % [missing], out, error_string(err)])
	viewport.queue_free()


# ── Source view: the image as on disk, with the editable lines ─────────────
class SourceView extends Control:
	var editor: Node

	func _fit() -> Dictionary:
		var tex: Texture2D = load(editor.current["path"]) as Texture2D
		var s: float = minf(size.x / tex.get_width(), size.y / tex.get_height())
		var off := (size - Vector2(tex.get_width(), tex.get_height()) * s) * 0.5
		return {"tex": tex, "s": s, "off": off}

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.03))
		if editor.current.is_empty():
			return
		var f: Dictionary = _fit()
		var tex: Texture2D = f["tex"]
		var s: float = f["s"]
		var off: Vector2 = f["off"]
		var w: float = tex.get_width()
		var h: float = tex.get_height()
		draw_rect(Rect2(off, Vector2(w, h) * s), Color(0.25, 0.0, 0.25))  # magenta-dark: shows transparency
		draw_texture_rect(tex, Rect2(off, Vector2(w, h) * s), false)
		var e: Dictionary = editor.entry()
		var insets: Dictionary = e.get("insets", {})
		var shade := Color(0, 0, 0, 0.6)
		var l: float = float(insets.get("left", 0))
		var t: float = float(insets.get("top", 0))
		var r: float = float(insets.get("right", 0))
		var b: float = float(insets.get("bottom", 0))
		draw_rect(Rect2(off, Vector2(l, h) * s), shade)
		draw_rect(Rect2(off + Vector2(w - r, 0) * s, Vector2(r, h) * s), shade)
		draw_rect(Rect2(off + Vector2(l, 0) * s, Vector2(w - l - r, t) * s), shade)
		draw_rect(Rect2(off + Vector2(l, h - b) * s, Vector2(w - l - r, b) * s), shade)
		var flag: Dictionary = (editor.stray_scan.get(editor.section, {}) as Dictionary).get(editor.current["key"], {})
		for frag in flag.get("fragments", []):
			var bb: Array = frag["bbox"]
			draw_rect(Rect2(off + Vector2(bb[0], bb[1]) * s, Vector2(bb[2], bb[3]) * s).grow(2), Color(1, 0.2, 0.2), false, 2.0)
		if editor.is_portrait_section():
			var cyan := Color(0.25, 0.85, 1.0)
			var amber := Color(1.0, 0.75, 0.2)
			for name in ["head_top", "chin"]:
				if e.has(name):
					var y: float = off.y + float(e[name]) * s
					draw_line(Vector2(off.x, y), Vector2(off.x + w * s, y), amber if editor.handle == name else cyan, 3.0 if editor.handle == name else 1.5)
					draw_string(ThemeDB.fallback_font, Vector2(off.x + 4, y - 4), "%s %d" % [name, int(e[name])], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, cyan)
			var cx: float = float(e.get("center_x", w / 2))
			draw_line(Vector2(off.x + cx * s, off.y), Vector2(off.x + cx * s, off.y + h * s), Color(0.6, 1.0, 0.4, 0.9 if e.has("center_x") else 0.35), 1.5)
			if not e.has("head_top"):
				draw_string(ThemeDB.fallback_font, Vector2(off.x + 6, off.y + 20), "no head anchors - press A or drag to set", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, amber)
		else:
			var c := Vector2(float(e.get("center_x", w / 2)), float(e.get("center_y", h / 2)))
			var p: Vector2 = off + c * s
			var green := Color(0.6, 1.0, 0.4)
			draw_line(p - Vector2(14, 0), p + Vector2(14, 0), green, 2.0)
			draw_line(p - Vector2(0, 14), p + Vector2(0, 14), green, 2.0)

	func _gui_input(event: InputEvent) -> void:
		if editor.current.is_empty():
			return
		var f: Dictionary = _fit()
		var s: float = f["s"]
		var off: Vector2 = f["off"]
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				editor._dragging = _pick(event.position, f)
				if editor._dragging != "":
					editor._push_undo()
					_drag_to(event.position, off, s)
			else:
				editor._dragging = ""
			accept_event()
		elif event is InputEventMouseMotion and editor._dragging != "":
			_drag_to(event.position, off, s)
			accept_event()

	func _pick(pos: Vector2, f: Dictionary) -> String:
		var s: float = f["s"]
		var off: Vector2 = f["off"]
		var tex: Texture2D = f["tex"]
		var e: Dictionary = editor.entry()
		if not editor.is_portrait_section():
			return "center"
		var best := ""
		var best_d: float = 10.0  # grab distance, screen px
		for name in ["head_top", "chin"]:
			if e.has(name):
				var d: float = absf(pos.y - (off.y + float(e[name]) * s))
				if d < best_d:
					best = name
					best_d = d
		var cx: float = off.x + float(e.get("center_x", tex.get_width() / 2.0)) * s
		if absf(pos.x - cx) < best_d:
			best = "center_x"
		if best == "" and not e.has("head_top"):
			best = "head_top"  # first click on an unanchored portrait sets the top line
		if best in ["head_top", "chin"]:
			editor.handle = best
		return best

	func _drag_to(pos: Vector2, off: Vector2, s: float) -> void:
		var src: Vector2 = (pos - off) / s
		match editor._dragging:
			"center":
				editor.set_handle_value("center_x", int(roundf(src.x)))
				editor.set_handle_value("center_y", int(roundf(src.y)))
			"center_x":
				editor.set_handle_value("center_x", int(roundf(src.x)))
			"head_top", "chin":
				editor.set_handle_value(editor._dragging, int(roundf(src.y)))


# Target guides over a preview: the class head_top / chin lines and the
# centre line for portraits; the box centre for items.
class GuideView extends Control:
	var portrait := true
	var target: Dictionary = {}

	func _draw() -> void:
		var c := Color(1.0, 0.2, 0.8, 0.8)
		if portrait:
			var top: float = float(target.get("head_top", 0.12)) * size.y
			var chin: float = top + float(target.get("head_height", 0.42)) * size.y
			draw_line(Vector2(0, top), Vector2(size.x, top), c, 1.0)
			draw_line(Vector2(0, chin), Vector2(size.x, chin), c, 1.0)
			draw_line(Vector2(size.x / 2, 0), Vector2(size.x / 2, size.y), Color(c, 0.4), 1.0)
		else:
			draw_line(Vector2(size.x / 2, 0), Vector2(size.x / 2, size.y), Color(c, 0.5), 1.0)
			draw_line(Vector2(0, size.y / 2), Vector2(size.x, size.y / 2), Color(c, 0.5), 1.0)
