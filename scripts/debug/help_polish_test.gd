extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func settle() -> void:
	for i in 12: await process_frame
func _run() -> void:
	await process_frame
	if DisplayServer.get_name() != "headless":
		var cursor = root.get_node("DesktopCursor")
		check(cursor.arrow.get_size() == Vector2(32, 32), "Native cursor size")
		check(cursor.HOTSPOT == Vector2(2, 2), "Cursor hotspot")
		for texture in [cursor.arrow, cursor.interactive]:
			var image: Image = texture.get_image()
			for y in range(image.get_height()):
				var seen_fill := false
				var seen_gap := false
				for x in range(image.get_width()):
					var filled := image.get_pixel(x, y).a > 0.0
					if filled and seen_gap:
						check(false, "Cursor row %d contains a hole" % y)
						break
					seen_fill = seen_fill or filled
					seen_gap = seen_fill and not filled
		cursor.arrow.get_image().save_png("res://debug_artifacts/ui_polish/cursor_default.png")
		cursor.interactive.get_image().save_png("res://debug_artifacts/ui_polish/cursor_hover.png")
	var help = load("res://scripts/ui/help_menu.gd")
	root.size = Vector2i(486, 1080)
	root.content_scale_size = Vector2i(1080, 2400)
	help.open(root)
	var menu = help._active
	check(menu._tab_buttons.keys() == ["basics", "units", "log", "settings"], "Four primary tabs")
	check(menu._active_tab == "basics", "Help opens on Basics")
	var opening_text := ""
	for label in menu._content_host.find_children("*", "Label", true, false): opening_text += label.text + "\n"
	check("HOW A TURN WORKS" in opening_text, "Basics exposes turn rules")
	check("THE PROTOCOL" in opening_text, "Basics contains Protocol")
	check("EVOLUTION / REWARDS" in opening_text, "Basics contains rewards")
	check(not menu._content_host.find_children("*", "Button", true, false).filter(func(b): return b.text == "REPLAY TUTORIAL").is_empty(), "Basics exposes tutorial replay")
	check(not menu._content_host.find_children("*", "Button", true, false).filter(func(b): return b.text == "KEYWORDS / ICON GUIDE").is_empty(), "Basics exposes reference")
	menu._select_tab("units")
	await settle()
	var scroll: ScrollContainer = menu._content_scroll
	print("WIDTH host=", menu._content_host.size, " scroll=", scroll.size)
	for faction in menu._bestiary_buttons.keys():
		menu._select_bestiary_faction(faction)
		await settle()
		var hp_right := -1.0
		for node in menu._content_host.find_children("*", "Label", true, false):
			if node.text.ends_with(" HP"):
				check(node.get_global_rect().end.x <= scroll.get_global_rect().end.x - scroll.get_v_scroll_bar().size.x + 1, "HP clipped: " + node.text)
				if hp_right >= 0: check(is_equal_approx(hp_right, node.get_global_rect().end.x), "HP right alignment")
				hp_right = node.get_global_rect().end.x
		for node in menu._bestiary_detail.find_children("*", "TextureRect", true, false):
			check(node.get_parent().size.is_equal_approx(load("res://scripts/ui/pixel_ui.gd").portrait_window(menu.ROW_PORTRAIT_W)), "Uniform thumbnail box: " + str(node.get_parent().size))
	menu._select_bestiary_faction("squad")
	await settle()
	# UI batch B11: every evolution row shows that evolution's OWN portrait
	# (its "<hero>_<evo>" file, framed by its own entry), never the base art.
	var dm_node: Node = root.get_node("DataManager")
	var row_art: Dictionary = {}
	for tex_node in menu._content_host.find_children("*", "TextureRect", true, false):
		var row: Node = tex_node.get_parent().get_parent().get_parent()
		for label in row.find_children("*", "Label", true, false):
			row_art[label.text] = tex_node.texture
	var evo_rows := 0
	for unit in dm_node.units.values():
		var seen := {}
		for path in unit.evolution_paths:
			if seen.has(path.get("id", "")): continue
			seen[path.get("id", "")] = true
			var title: String = str(path.get("callsign", path.get("name", ""))).to_upper()
			var want = dm_node.get_evolution_portrait(unit.id, str(path.get("id", "")))
			evo_rows += 1
			check(want != null, "%s has no evolution portrait file" % title)
			check(row_art.get(title) == want and want != unit.portrait, "Help > Units %s row shows its own evolved portrait" % title)
	check(evo_rows == 16, "Help > Units lists 16 evolution rows (saw %d)" % evo_rows)
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_final_transform() * scroll.get_global_rect().get_center()
	Input.parse_input_event(motion)
	await process_frame
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = motion.position
	Input.parse_input_event(wheel)
	await settle()
	check(scroll.scroll_vertical > 0, "Mouse wheel scrolls Units")
	var first_unit = root.get_node("DataManager").units.values()[0]
	menu._on_reference_row_long_pressed(Vector2.ZERO, "hero", first_unit, menu._content_host)
	await settle()
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await settle()
	check(help.is_open() and not menu._breakdown_open, "Esc closes inspection before Help")
	menu._select_tab("keywords")
	await settle()
	Input.parse_input_event(esc)
	await settle()
	check(help.is_open() and menu._reference_section == "", "Esc backs out of subsection")
	Input.parse_input_event(esc)
	await settle()
	check(not help.is_open(), "Esc closes Help")
	for failure in failures: push_error(failure)
	print("[HELP_POLISH] ", "PASS" if failures.is_empty() else "FAIL", " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)
