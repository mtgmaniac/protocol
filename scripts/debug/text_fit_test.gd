# Text fit gate (crisp text step 3b, Kev 2026-10-20). Headless:
#   <godot> --headless --path . -s scripts/debug/text_fit_test.gd
# Opens every screen text_screens.gd knows at the itch canvas (640x960) and a
# 1080x2400 phone and walks every visible Label and Button:
#   1. No silent clipping: text wider than its node fails unless it ends in an
#      ellipsis; a wrapped label showing fewer lines than it has, or clipped
#      shorter than its lines, fails unless it ends in an ellipsis; text whose
#      ink a clipping ancestor (not a scroll view) cuts fails.
#   2. No mid-word wrap: a wrapping label breaks at words only
#      (AUTOWRAP_WORD), and every word fits the label's width (a longer word
#      would run out of it). The source is checked too: no AUTOWRAP_WORD_SMART
#      or AUTOWRAP_ARBITRARY (or their .tscn values 3 / 1) outside scripts/debug.
# Squad select's unit info is checked for every unit: the description takes
# at most two lines. The unlock grid reports any item or relic name that needs
# more than two lines at its cell's width (a report, not a failure).
# The profile never touches disk (dev_reset_profile in memory, scratch APPDATA
# from the gate runner). Autoloads and UI classes resolve at RUNTIME.
extends SceneTree

const CANVASES := [Vector2i(640, 960), Vector2i(1080, 2400)]
const SCREENS := ["squad", "squad_info", "squad_locked", "briefing", "inspect", "help_units",
	"help_units_evo", "help_settings", "evolution", "evolution_all", "unlock", "reward", "run_end",
	"run_end_victory", "battle", "battle_trait"]
## The pop-up screens check only the pop-up's text (the screen under it is
## checked on its own).
const POPUP_SCRIPT := {"inspect": "inspect_popup.gd", "help_units_evo": "inspect_popup.gd", "help_units": "help_menu.gd",
	"help_settings": "help_menu.gd", "briefing": "operation_briefing_overlay.gd"}
const ELLIPSIS := [TextServer.OVERRUN_TRIM_ELLIPSIS, TextServer.OVERRUN_TRIM_WORD_ELLIPSIS]

var failures: Array[String] = []
var checks := 0
var screens: GDScript


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and not failures.has(label):
		failures.append(label)
		push_error("[TEXT_FIT] " + label)


func _run() -> void:
	await process_frame
	screens = load("res://scripts/debug/text_screens.gd")
	_check_sources()
	var sm: Node = root.get_node("/root/SaveManager")
	root.get_node("/root/AudioManager").call("set_suppressed", true)
	for canvas: Vector2i in CANVASES:
		root.size = canvas
		for screen: String in SCREENS:
			sm.call("dev_reset_profile")
			sm.get("data")["tutorial_done"] = true
			sm.get("data")["onboarding"]["primers_seen"] = sm.call("_all_primer_ids")
			var scene: Node = await screens.open(self, screen)
			var tag := "%dx%d %s" % [canvas.x, canvas.y, screen]
			var host: Node = _popup(screen)
			_walk(host if host != null else scene, tag)
			if screen == "squad_info":
				await _check_unit_info(scene, tag)
			if screen == "unlock":
				_report_unlock_names(scene, tag)
	change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	await process_frame
	print("[TEXT_FIT] %s: %d checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	for f in failures:
		print("   - ", f)
	quit(0 if failures.is_empty() else 1)


func _popup(screen: String) -> Node:
	if not POPUP_SCRIPT.has(screen):
		return null
	for n in root.find_children("*", "Control", true, false):
		var s: Script = (n as Node).get_script()
		if s != null and s.resource_path.ends_with(str(POPUP_SCRIPT[screen])):
			return n
	return null


# ── Source: no wrap mode that breaks inside a word ──
func _check_sources() -> void:
	for path: String in _files("res://scripts", ".gd") + _files("res://scenes", ".tscn"):
		if path.begins_with("res://scripts/debug/") or path.begins_with("res://scenes/debug/"):
			continue
		var text := FileAccess.get_file_as_string(path)
		for bad in ["AUTOWRAP_WORD_SMART", "AUTOWRAP_ARBITRARY", "autowrap_mode = 3", "autowrap_mode = 1"]:
			check(not text.contains(bad), "%s sets %s (breaks inside a word)" % [path, bad])


func _files(dir: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(d), ext))
	return out


# ── Live text ──
func _walk(n: Node, tag: String) -> void:
	if n is CanvasItem and not (n as CanvasItem).visible:
		return
	if n is Label or n is Button:
		_check_text(n as Control, tag)
	for c in n.get_children():
		_walk(c, tag)


func _shown(c: Control) -> String:
	var text: String = (c as Label).text if c is Label else (c as Button).text
	var upper: bool = (c is Label and (c as Label).uppercase) or (c is Button and c.get("uppercase") == true)
	return text.to_upper() if upper else text


# The node's content box: its rect less its stylebox margins (and a button's icon).
func _inner(c: Control) -> Rect2:
	var inner := Rect2(Vector2.ZERO, c.size)
	var sb: StyleBox = c.get_theme_stylebox("normal")
	if sb != null:
		inner = Rect2(sb.get_margin(SIDE_LEFT), sb.get_margin(SIDE_TOP),
			c.size.x - sb.get_margin(SIDE_LEFT) - sb.get_margin(SIDE_RIGHT),
			c.size.y - sb.get_margin(SIDE_TOP) - sb.get_margin(SIDE_BOTTOM))
	if c is Button and (c as Button).icon != null:
		var icon_w: float = (c as Button).icon.get_width() + c.get_theme_constant("h_separation")
		inner.position.x += icon_w
		inner.size.x -= icon_w
	return inner


func _check_text(c: Control, tag: String) -> void:
	var text := _shown(c)
	if text.strip_edges() == "" or c.size.x < 1.0:
		return
	var font: Font = c.get_theme_font("font")
	var size: int = c.get_theme_font_size("font_size")
	var inner := _inner(c)
	var name := "%s: '%s'" % [tag, text.left(36).replace("\n", " / ")]
	var wrap: int = (c as Label).autowrap_mode if c is Label else (c as Button).autowrap_mode
	var overrun: int = (c as Label).text_overrun_behavior if c is Label else (c as Button).text_overrun_behavior
	var ellipsis: bool = overrun in ELLIPSIS
	check(wrap == TextServer.AUTOWRAP_OFF or wrap == TextServer.AUTOWRAP_WORD, "%s wraps inside words (mode %d)" % [name, wrap])
	var widest := 0.0
	for line in text.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	if wrap == TextServer.AUTOWRAP_OFF:
		check(widest <= inner.size.x + 1.0 or ellipsis, "%s is cut off: %d of %d px shown" % [name, inner.size.x, widest])
	else:
		for word in text.replace("\n", " ").split(" ", false):
			var w: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			check(w <= inner.size.x + 1.0, "%s: the word '%s' (%d px) is wider than its line (%d px)" % [name, word, w, inner.size.x])
		if c is Label:
			var lab := c as Label
			var lines: int = lab.get_line_count()
			if lab.max_lines_visible >= 0 and lines > lab.max_lines_visible:
				check(ellipsis, "%s shows %d of %d lines with no ellipsis" % [name, lab.max_lines_visible, lines])
			var spacing := float(lab.get_theme_constant("line_spacing"))
			var shown_lines: int = lines if lab.max_lines_visible < 0 else mini(lines, lab.max_lines_visible)
			var content_h: float = shown_lines * (font.get_height(size) + spacing) - spacing
			if lab.clip_text:
				check(content_h <= inner.size.y + 1.0 or ellipsis, "%s is clipped: %d of %d px of lines shown" % [name, inner.size.y, content_h])
	# A clipping ancestor (a scroll view only scrolls) must not cut the text.
	var rect: Rect2 = c.get_global_rect()
	var ink_w: float = minf(widest, inner.size.x) if wrap != TextServer.AUTOWRAP_OFF or ellipsis else widest
	var align: int = (c as Label).horizontal_alignment if c is Label else (c as Button).alignment
	var ink_x: float = inner.position.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		ink_x += (inner.size.x - ink_w) * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		ink_x += inner.size.x - ink_w
	var ink := Rect2(rect.position.x + ink_x, rect.position.y, ink_w, rect.size.y)
	# The text stays inside the panel or button that frames it, and the screen
	# (a label sized by hand in a plain Control grows past its panel instead of
	# clipping: the run-end report's 2026-10-20 defect).
	var box: Control = _box_of(c)
	if box != null:
		var b: Rect2 = box.get_global_rect()
		check(ink.position.x >= b.position.x - 1.0 and ink.end.x <= b.end.x + 1.0,
			"%s runs out of its %s (ink %d..%d, box %d..%d)" % [name, box.name, ink.position.x, ink.end.x, b.position.x, b.end.x])
	var screen_rect: Rect2 = c.get_viewport_rect()
	check(ink.position.x >= screen_rect.position.x - 1.0 and ink.end.x <= screen_rect.end.x + 1.0,
		"%s runs off the screen (ink %d..%d)" % [name, ink.position.x, ink.end.x])
	var p: Node = c.get_parent()
	while p is Control:
		var pc := p as Control
		if pc is ScrollContainer:
			break
		if pc.clip_contents:
			var clip: Rect2 = pc.get_global_rect()
			check(ink.position.x >= clip.position.x - 1.0 and ink.end.x <= clip.end.x + 1.0,
				"%s is cut by %s (ink %d..%d, clip %d..%d)" % [name, pc.name, ink.position.x, ink.end.x, clip.position.x, clip.end.x])
			break
		p = pc.get_parent()


# The nearest ancestor that draws a frame around the text: a panel or a button.
func _box_of(c: Control) -> Control:
	var p: Node = c.get_parent()
	while p is Control:
		if p is ScrollContainer:
			return null
		if p is PanelContainer or p is Panel or p is Button:
			return p as Control
		p = p.get_parent()
	return null


# Every unit's description fits the info bar in at most two lines.
func _check_unit_info(scene: Node, tag: String) -> void:
	var blurb: Label = scene.get("_info_blurb")
	var lines_cap: int = int(scene.get("INFO_BLURB_LINES"))
	for unit_id in scene.get("_unit_ids"):
		scene.call("_show_unit_detail", unit_id)
		await process_frame
		await process_frame
		var font: Font = blurb.get_theme_font("font")
		var pixel_ui: GDScript = load("res://scripts/ui/pixel_ui.gd")
		var lines: int = pixel_ui.wrapped_line_count(blurb.text, font, blurb.get_theme_font_size("font_size"), blurb.size.x)
		check(lines <= lines_cap, "%s: %s's description takes %d lines (cap %d)" % [tag, unit_id, lines, lines_cap])
		check(blurb.get_line_count() <= lines_cap, "%s: %s's description label wraps to %d lines" % [tag, unit_id, blurb.get_line_count()])
		_walk(scene.get("_info_bar"), "%s %s" % [tag, unit_id])
	# The bar stays as tall as what it shows, inside its reserved region.
	var bar: Control = scene.get("_info_bar")
	var region: Control = scene.get("_info_region")
	check(bar.get_global_rect().end.y <= region.get_global_rect().end.y + 1.0, "%s: the info bar runs past its reserved region" % tag)


# The unlock grid's names at the cell width: any that needs more than two lines.
func _report_unlock_names(scene: Node, tag: String) -> void:
	var cells: Array = scene.find_children("*", "VBoxContainer", true, false).filter(func(n): return (n as Node).has_meta("unlock_grid_cell"))
	if cells.is_empty():
		check(false, "%s: no unlock grid cell" % tag)
		return
	var label: Label = null
	for ch in (cells[0] as Node).get_children():
		if ch is Label:
			label = ch
	var width: float = label.size.x
	var font: Font = label.get_theme_font("font")
	var size: int = label.get_theme_font_size("font_size")
	var pixel_ui: GDScript = load("res://scripts/ui/pixel_ui.gd")
	var long: Array[String] = []
	var dm: Node = root.get_node("/root/DataManager")
	for item in dm.get("items").values():
		var n: String = str(item.get("display_name"))
		if pixel_ui.wrapped_line_count(n, font, size, width) > 2:
			long.append(n)
		for word in n.split(" ", false):
			check(font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width + 1.0,
				"%s: the item word '%s' is wider than the unlock cell (%d px)" % [tag, word, width])
	print("[TEXT_FIT] %s: unlock cell %d px wide; names over two lines: %s" % [tag, width, str(long) if not long.is_empty() else "none"])
