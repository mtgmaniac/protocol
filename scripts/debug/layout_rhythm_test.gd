## Layout rhythm (ui-fix 2026-10-16): the header and footer bars are the same
## height, and one GAP (PixelUI.GAP, a multiple of 4 design px) separates the
## bars from the cards and every stacked band between them, mirrored top and
## bottom. Footer: the Protocol label is the LABEL role, the Protocol block and
## the action buttons sit GAP from both bar edges, the buttons are equal squares
## GAP apart. Run at the 360 and 390 px phone windows (windowed, like the
## capture tools: headless has no real window size).
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
	gs.start_run(["combat", "engineer", "medic"], "facility", 20261016)
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
	# The label's line box is raised by the m5x7 pad above its caps; the caps sit on the block's top.
	check(near(label.get_global_rect().position.y + s.PROTOCOL_LABEL_CAP_PAD, stack.position.y) and near(s.protocol_bar.get_global_rect().end.y, stack.end.y), "%s: the label caps and the cells span the Protocol block" % tag)


func run() -> void:
	var window_tool: Script = load("res://scripts/debug/capture_window.gd")
	for window: Vector2i in WINDOWS:
		window_tool.apply(root, window)
		await frames(4)
		await battle(window)
	print("[LAYOUT_RHYTHM] %s: %d checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
