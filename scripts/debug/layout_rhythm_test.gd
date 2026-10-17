## Layout rhythm (ui-fix 2026-10-16): the header and footer bars are the same
## height, and one GAP (PixelUI.GAP, a multiple of 4 design px) separates the
## bars from the cards and every stacked band between them, mirrored top and
## bottom. Footer: the Protocol label is the LABEL role, the Protocol block and
## the action buttons sit GAP from both bar edges, the buttons are equal squares
## GAP apart. Run at the 360 and 390 px phone windows (windowed, like the
## capture tools: headless has no real window size).
## 2026-10-17, read off the rendered frame: the PROTOCOL label and the cells sit
## centred in the footer's fill (as many screen px above the caps as under the
## cells); every callsign draws all its columns between the card shell's inset
## lines (AVALANCHE lost one at 360); the header name is the HEADER role.
##   godot --path . -s scripts/debug/layout_rhythm_test.gd
extends SceneTree

const BATTLE := "res://scenes/battle/BattleScene.tscn"
const WINDOWS := [Vector2i(360, 800), Vector2i(390, 867)]
var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("[LAYOUT_RHYTHM] " + label)


func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.51


func frames(count: int = 8) -> void:
	for i in count:
		await process_frame


func start_battle() -> Node:
	var gs: Node = root.get_node("GameState")
	gs.start_run(["avalanche", "engineer", "medic"], "facility", 20261016)
	gs.advance_to_next_battle()
	change_scene_to_file(BATTLE)
	await frames(16)
	current_scene._briefing_active = false
	for child in current_scene.get_children():
		if child.get_script() != null and child.get_script().resource_path == "res://scripts/ui/operation_briefing_overlay.gd":
			child.queue_free()
	await frames(24)
	return current_scene


func battle(window: Vector2i) -> void:
	var tag := "%dx%d" % [window.x, window.y]
	var s: Node = await start_battle()
	var gap: float = PixelUI.GAP
	check(int(gap) % 4 == 0, "GAP is a multiple of 4 design px")
	var header: Node = root.get_node("PersistentHeader")
	var header_bottom: float = header.band_height()
	var screen_h: float = root.get_visible_rect().size.y - PixelUI.safe_bottom
	var divider: Control = s.get_node("FooterDivider")
	var footer_top: float = divider.get_global_rect().position.y
	var header_h: float = header_bottom - PixelUI.safe_top
	var footer_h: float = screen_h - footer_top
	print("[LAYOUT_RHYTHM] %s header %.1f footer %.1f" % [tag, header_h, footer_h])
	check(near(header_h, footer_h), "%s: header and footer bars are the same height (%.1f / %.1f)" % [tag, header_h, footer_h])
	var layout: Object = s.get("_layout")
	var enemy: Rect2 = layout.call("get_card_group_rect", s.get("enemy_card_views"))
	var hero: Rect2 = layout.call("get_card_group_rect", s.get("hero_card_views"))
	var tray: Rect2 = layout.call("get_combat_zone_rect")
	var gaps := {
		"header -> enemy cards": enemy.position.y - header_bottom,
		"enemy cards -> tray": tray.position.y - enemy.end.y,
		"tray -> hero cards": hero.position.y - tray.end.y,
		"hero cards -> footer": footer_top - hero.end.y,
	}
	for key: String in gaps:
		print("[LAYOUT_RHYTHM] %s %s %.1f" % [tag, key, gaps[key]])
		check(near(gaps[key], gap), "%s: %s is GAP (%.1f)" % [tag, key, gaps[key]])
	check(near(gaps["header -> enemy cards"], gaps["hero cards -> footer"]), "%s: the bar gaps mirror" % tag)
	# Footer anatomy.
	var panel: Rect2 = s.protocol_panel.get_global_rect()
	var protocol: Object = s.get("_protocol")
	var buttons: Array = [protocol.get("nudge_button"), s.protocol_spend_button, protocol.get("set_button"), protocol.get("item_button")]
	var first: Rect2 = (buttons[0] as Control).get_global_rect()
	for i in buttons.size():
		var r: Rect2 = (buttons[i] as Control).get_global_rect()
		check(near(r.size.x, r.size.y) and near(r.size.x, first.size.x), "%s: footer button %d is an equal square (%s)" % [tag, i, r.size])
		check(near(r.position.y - panel.position.y, gap) and near(panel.end.y - r.end.y, gap), "%s: footer button %d sits GAP from both bar edges" % [tag, i])
		if i > 0:
			var prev: Rect2 = (buttons[i - 1] as Control).get_global_rect()
			check(near(r.position.x - prev.end.x, gap), "%s: footer buttons are GAP apart (%.1f)" % [tag, r.position.x - prev.end.x])
	var label: Label = s.protocol_label
	check(label.get_theme_font_size("font_size") == PixelUI.type_px(PixelUI.TYPE_LABEL), "%s: PROTOCOL label is the LABEL role" % tag)
	var stack: Rect2 = s.protocol_bar.get_parent().get_global_rect()
	check(near(stack.position.y - panel.position.y, gap) and near(panel.end.y - stack.end.y, gap), "%s: the Protocol block sits GAP from both bar edges" % tag)
	check(near(s.protocol_bar.get_global_rect().end.y, stack.end.y), "%s: the cells sit on the Protocol block's bottom" % tag)
	await RenderingServer.frame_post_draw
	var frame: Image = root.get_texture().get_image()
	footer_centred(frame, tag, s)
	for view: Dictionary in s.get("hero_card_views") + s.get("enemy_card_views"):
		callsign_whole(frame, tag, view.card)
	var summary: Label = header.get("_summary_label")
	var header_k: float = PixelUI.screen_scale_at(summary.get_parent()) * PixelUI.block_draw_size(summary) / 16.0
	check(absf(header_k - 3.0) < 0.01, "%s: the header name draws 3 screen px per font pixel (HEADER, x4; %.2f)" % [tag, header_k])


# Screen rows, from the frame: the footer fill (the strip colour inside its 8 px
# border and 4 px inset), the PROTOCOL caps, the cells' last row.
func footer_centred(frame: Image, tag: String, s: Node) -> void:
	var to_px: Transform2D = PixelUI.physical_transform(s)
	var panel: Rect2 = s.protocol_panel.get_global_rect()
	var label: Rect2 = s.protocol_label.get_global_rect()
	var cells: Rect2 = s.protocol_bar.get_global_rect()
	var fill := Color8(13, 19, 23)
	var edge_x: int = int((to_px * Vector2(panel.position.x + 16.0, 0.0)).x)
	var cell_x: int = int((to_px * Vector2(cells.position.x + 24.0, 0.0)).x)
	var y0: int = int((to_px * panel.position).y)
	var y1: int = frame.get_height()
	var fill_top := -1
	var fill_end := -1
	for y in range(y0, y1):
		if frame.get_pixel(edge_x, y).is_equal_approx(fill):
			if fill_top < 0:
				fill_top = y
			fill_end = y + 1
	var caps := -1
	var lx0: int = int((to_px * label.position).x)
	var lx1: int = int((to_px * label.end).x)
	for y in range(fill_top, fill_end):
		for x in range(lx0, lx1):
			var c: Color = frame.get_pixel(x, y)
			if c.r + c.g + c.b > 1.76:
				caps = y
				break
		if caps >= 0:
			break
	var cells_end := -1
	for y in range(fill_top, fill_end):
		if not frame.get_pixel(cell_x, y).is_equal_approx(fill):
			cells_end = y + 1
	print("[LAYOUT_RHYTHM] %s footer fill %d..%d, caps %d, cells end %d: %d px above, %d below" % [tag, fill_top, fill_end, caps, cells_end, caps - fill_top, fill_end - cells_end])
	check(fill_top >= 0 and caps > fill_top and cells_end > caps, "%s: footer rows found" % tag)
	check(caps - fill_top == fill_end - cells_end, "%s: the PROTOCOL label and cells are centred in the footer (%d px above, %d below)" % [tag, caps - fill_top, fill_end - cells_end])


# A callsign is 7 font px tall and one font px narrower than its advance; every
# one of those columns must draw, between the shell's dark inset lines.
func callsign_whole(frame: Image, tag: String, card: Control) -> void:
	var label: Label = card.get("_name_label")
	var ink: Color = label.get_theme_color("font_color")
	var k: int = roundi(PixelUI.screen_scale_at(label.get_parent()) * PixelUI.block_draw_size(label) / 16.0)
	var font_px: int = roundi(label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x * 16.0 / float(label.get_theme_font_size("font_size")))
	var to_px: Transform2D = PixelUI.physical_transform(card)
	var a: Vector2 = to_px * Vector2.ZERO
	var b: Vector2 = to_px * Vector2(card.size.x, PixelUI.BATTLE_SHELL_WIDTH + card.NAME_ROW_HEIGHT)
	var lo := 1 << 20
	var hi := -1
	for y in range(int(a.y), int(b.y)):
		for x in range(int(a.x), int(b.x)):
			var c: Color = frame.get_pixel(x, y)
			if absf(c.r - ink.r) + absf(c.g - ink.g) + absf(c.b - ink.b) < 0.12:
				lo = mini(lo, x)
				hi = maxi(hi, x)
	var shell: float = float(PixelUI.BATTLE_SHELL_WIDTH + PixelUI.BATTLE_INSET_WIDTH) * to_px.get_scale().x
	if hi < 0:
		print("[LAYOUT_RHYTHM] %s %s ink %s not found; strip sample %s" % [tag, label.text, ink.to_html(false), frame.get_pixel(int((a.x + b.x) * 0.5), int(a.y + (b.y - a.y) * 0.6)).to_html(false)])
	check(hi - lo + 1 == (font_px - 1) * k, "%s: %s draws every column (%d of %d px)" % [tag, label.text, hi - lo + 1, (font_px - 1) * k])
	check(float(lo) >= a.x + shell - 0.5 and float(hi) + 1.0 <= b.x - shell + 0.5, "%s: %s stays inside the shell's inset lines" % [tag, label.text])


func run() -> void:
	var window_tool: Script = load("res://scripts/debug/capture_window.gd")
	for window: Vector2i in WINDOWS:
		window_tool.apply(root, window)
		await frames(4)
		await battle(window)
	print("[LAYOUT_RHYTHM] %s: %d checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
