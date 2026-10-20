# Crisp text step 1 capture rig (2026-10-19). Opens one screen on one canvas,
# saves the frame and a JSON of every visible text node: its size, face, drawn
# rect, its box (nearest panel ancestor) and overflow flags. Run WINDOWED
# (headless has no renderer), flags before any `--`:
#   <godot_console> --path . -s res://scripts/debug/text_size_capture.gd \
#       --capture-window=640x960 --tsc-screen=<name> --tsc-out=<abs png path> \
#       [--crisp-alt=a|b]
# Screens: title, squad (a hero selected), squad_info (and its unit info open), battle (after a roll, dice showing),
#          inspect (squad select's unit pop-up), help_settings, help_units, reward.
# --capture-window is applied by PersistentHeader (capture_window.gd: a canvas
# taller than the monitor renders at full size inside a half-size window).
# Autoloads and UI classes resolve at RUNTIME (TRUTH's -s convention).
extends SceneTree

var _screen := "squad"
var _out := ""
var pixel_ui: GDScript


func _initialize() -> void:
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a.begins_with("--tsc-screen="):
			_screen = a.trim_prefix("--tsc-screen=")
		elif a.begins_with("--tsc-out="):
			_out = a.trim_prefix("--tsc-out=")
	call_deferred("_run")


func _run() -> void:
	await process_frame
	pixel_ui = load("res://scripts/ui/pixel_ui.gd")
	var sm: Node = root.get_node("/root/SaveManager")
	var gs: Node = root.get_node("/root/GameState")
	var dm: Node = root.get_node("/root/DataManager")
	root.get_node("/root/AudioManager").call("set_suppressed", true)
	sm.call("dev_reset_profile")
	sm.get("data")["tutorial_done"] = true
	# No first-sighting keyword primer over the rolled battle.
	sm.get("data")["onboarding"]["primers_seen"] = sm.call("_all_primer_ids")
	seed(424242)
	var scene_path := "res://scenes/ui/UnitSelect.tscn"
	match _screen:
		"title":
			scene_path = "res://scenes/ui/MainMenu.tscn"
		"battle":
			gs.call("start_run", ["combat", "avalanche", "medic"], "facility", 424242)
			gs.call("advance_to_next_battle")
			scene_path = "res://scenes/battle/BattleScene.tscn"
		"reward":
			gs.call("start_run", ["combat", "avalanche", "medic"], "facility", 424242)
			gs.call("advance_to_next_battle")
			gs.call("prepare_battle_rewards")
			scene_path = "res://scenes/ui/RewardScreen.tscn"
	change_scene_to_file(scene_path)
	# The title's logo boot-in runs before its buttons show.
	await create_timer(5.0 if _screen == "title" else 1.5).timeout
	var scene: Node = current_scene
	match _screen:
		"squad", "squad_info":
			scene.call("_on_tile_tapped", "combat")
			if _screen == "squad_info":
				scene.call("_toggle_info")
		"inspect":
			var unit: Resource = dm.call("get_unit", "combat")
			load("res://scripts/ui/inspect_popup.gd").open(scene, scene.call("unit_inspect_payload", unit))
		"help_settings", "help_units":
			load("res://scripts/ui/help_menu.gd").open(scene)
			await process_frame
			var menus: Array = root.find_children("*", "HelpMenu", true, false)
			if not menus.is_empty():
				(menus[0] as Node).call("_select_tab", _screen.trim_prefix("help_"))
		"battle":
			var roll_button: Button = scene.get_node_or_null("%RollButton") as Button
			var dice_tray: Node = scene.get_node_or_null("%DiceTray3D")
			if roll_button != null and not roll_button.disabled:
				roll_button.emit_signal("pressed")
				if dice_tray != null and dice_tray.has_signal("roll_finished"):
					await dice_tray.roll_finished
	await create_timer(1.0).timeout
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var rows: Array = []
	_walk(root, rows)
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	image.save_png(_out)
	var final_xf: Transform2D = root.get_final_transform()
	var f := FileAccess.open(_out.get_basename() + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"screen": _screen,
		"image": [image.get_width(), image.get_height()],
		"final_scale": final_xf.get_scale().x,
		"visible_rect": [root.get_visible_rect().size.x, root.get_visible_rect().size.y],
		"labels": rows,
	}, "  "))
	f.close()
	print("[TEXT_SIZE_CAPTURE] %s %dx%d scale %.4f labels %d -> %s" % [_screen, image.get_width(), image.get_height(), final_xf.get_scale().x, rows.size(), _out])
	quit(0)


func _font_name(font: Font) -> String:
	if font == null:
		return "none"
	if font.resource_path.ends_with("m5x7.ttf"):
		return "m5x7"
	if font.resource_path.ends_with("battle_block.fnt"):
		return "battle_block"
	if font is FontFile and is_equal_approx((font as FontFile).oversampling, 1.0):
		return "m5x7_exact"
	return font.resource_path if font.resource_path != "" else font.get_class()


# A Control's rect in canvas (design) px, its own scale included.
func _canvas_rect(c: Control) -> Rect2:
	var xf: Transform2D = c.get_global_transform_with_canvas()
	return xf * Rect2(Vector2.ZERO, c.size)


# The nearest ancestor that draws a box (a panel or a button).
func _box_of(c: Control) -> Control:
	var p: Node = c.get_parent()
	while p != null and p is Control:
		if p is PanelContainer or p is Panel or p is Button:
			return p as Control
		p = p.get_parent()
	return null


# The visible region: the intersection of every clipping ancestor (scrolls).
func _clip_of(c: Control) -> Rect2:
	var clip := Rect2(-1e6, -1e6, 2e6, 2e6)
	var p: Node = c.get_parent()
	while p != null and p is Control:
		if (p as Control).clip_contents:
			clip = clip.intersection(_canvas_rect(p as Control))
		p = p.get_parent()
	return clip


# The colour the text draws in: its font colour times every modulate above it.
func _ink_color(c: Control) -> Color:
	var name := "default_color" if c is RichTextLabel else "font_color"
	if c is Button and (c as Button).disabled:
		name = "font_disabled_color"
	var col: Color = c.get_theme_color(name)
	col *= c.self_modulate
	var p: Node = c
	while p != null:
		if p is CanvasItem:
			col *= (p as CanvasItem).modulate
		p = p.get_parent()
	return col


# Which layer draws the node: a pop-up (help, inspect) or the screen.
func _layer_of(n: Node) -> String:
	var p: Node = n
	while p != null:
		var s: Script = p.get_script()
		if s != null and (s.resource_path.ends_with("inspect_popup.gd") or s.resource_path.ends_with("help_menu.gd")):
			return s.resource_path.get_file().get_basename()
		if p is CanvasLayer:
			return str(p.name)
		p = p.get_parent()
	return "screen"


func _walk(n: Node, rows: Array) -> void:
	if n is Label or n is Button or n is RichTextLabel or n is LineEdit:
		var c := n as Control
		var text := ""
		if n is Label: text = (n as Label).text
		elif n is Button: text = (n as Button).text
		elif n is RichTextLabel: text = (n as RichTextLabel).get_parsed_text()
		elif n is LineEdit: text = (n as LineEdit).text
		if c.is_visible_in_tree() and text.strip_edges() != "":
			var rtl := n is RichTextLabel
			var font: Font = c.get_theme_font("normal_font" if rtl else "font")
			var size: int = c.get_theme_font_size("normal_font_size" if rtl else "font_size")
			var shown := text
			if (n is Label and (n as Label).uppercase) or (n is Button and n.get("uppercase") == true):
				shown = text.to_upper()
			# The widest line, as one unwrapped run of the font.
			var text_w := 0.0
			for line in shown.split("\n"):
				text_w = maxf(text_w, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
			var wraps := false
			var trims := false
			var halign := HORIZONTAL_ALIGNMENT_CENTER
			var valign := VERTICAL_ALIGNMENT_CENTER
			var line_h: float = font.get_height(size)
			var content_h: float = line_h
			var inner := Rect2(Vector2.ZERO, c.size)
			if n is Label:
				var lab := n as Label
				wraps = lab.autowrap_mode != TextServer.AUTOWRAP_OFF
				trims = lab.clip_text or lab.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
				halign = lab.horizontal_alignment
				valign = lab.vertical_alignment
				var spacing := float(lab.get_theme_constant("line_spacing"))
				content_h = lab.get_line_count() * (line_h + spacing) - spacing
				var sb: StyleBox = lab.get_theme_stylebox("normal")
				if sb != null:
					inner = Rect2(sb.get_margin(SIDE_LEFT), sb.get_margin(SIDE_TOP), c.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT), c.size.y - sb.get_margin(SIDE_TOP) - sb.get_margin(SIDE_BOTTOM))
			elif n is Button:
				var b := n as Button
				trims = b.clip_text or b.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
				halign = b.alignment
				var sb: StyleBox = c.get_theme_stylebox("normal")
				if sb != null:
					inner = Rect2(sb.get_margin(SIDE_LEFT), sb.get_margin(SIDE_TOP), c.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT), c.size.y - sb.get_margin(SIDE_TOP) - sb.get_margin(SIDE_BOTTOM))
				if b.icon != null:
					var icon_w: float = b.icon.get_width() + c.get_theme_constant("h_separation")
					inner.position.x += icon_w
					inner.size.x -= icon_w
			elif rtl:
				content_h = (n as RichTextLabel).get_content_height()
				valign = VERTICAL_ALIGNMENT_TOP
				halign = HORIZONTAL_ALIGNMENT_LEFT
				wraps = true
			# The ink: where the text draws inside the node (its own scale included).
			var ink_w: float = minf(text_w, inner.size.x) if (wraps or trims) else text_w
			var ink_x: float = inner.position.x
			match halign:
				HORIZONTAL_ALIGNMENT_CENTER:
					ink_x = inner.position.x + (inner.size.x - ink_w) * 0.5
				HORIZONTAL_ALIGNMENT_RIGHT:
					ink_x = inner.position.x + inner.size.x - ink_w
			var ink_y: float = inner.position.y
			match valign:
				VERTICAL_ALIGNMENT_CENTER:
					ink_y = inner.position.y + (inner.size.y - content_h) * 0.5
				VERTICAL_ALIGNMENT_BOTTOM:
					ink_y = inner.position.y + inner.size.y - content_h
			var xf: Transform2D = c.get_global_transform_with_canvas()
			var ink: Rect2 = xf * Rect2(ink_x, ink_y, ink_w, content_h)
			var rect: Rect2 = _canvas_rect(c)
			var box: Control = _box_of(c)
			var box_rect: Rect2 = _canvas_rect(box) if box != null else Rect2()
			var clip: Rect2 = _clip_of(c)
			var scale_x: float = xf.get_scale().x
			rows.append({
				"path": str(c.get_path()).replace("/root/", ""),
				"type": c.get_class(),
				"layer": _layer_of(n),
				"ink_color": _ink_color(c).to_html(true),
				"text": shown.substr(0, 80).replace("\n", " / "),
				"font": _font_name(font),
				"size": size,
				"scale": scale_x,
				"drawn_px": float(size) * scale_x,
				"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
				"ink": [ink.position.x, ink.position.y, ink.size.x, ink.size.y],
				"text_w": text_w * scale_x,
				"inner_w": inner.size.x * scale_x,
				"content_h": content_h * scale_x,
				"inner_h": inner.size.y * scale_x,
				"wraps": wraps,
				"trims": trims,
				"lines": (n as Label).get_line_count() if n is Label else 1,
				"visible_lines": (n as Label).get_visible_line_count() if n is Label else 1,
				"box": str(box.get_path()).replace("/root/", "") if box != null else "",
				"box_rect": [] if box == null else [box_rect.position.x, box_rect.position.y, box_rect.size.x, box_rect.size.y],
				"clip": [clip.position.x, clip.position.y, clip.size.x, clip.size.y],
			})
	for ch in n.get_children():
		_walk(ch, rows)
