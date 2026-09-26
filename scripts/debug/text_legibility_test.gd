# Text legibility Step 1 regression (docs/audits/TEXT_LEGIBILITY_AUDIT.md).
# Headless:  <godot> --headless --path . -s scripts/debug/text_legibility_test.gd
# Proves, on the live screens, that every visible pixel-font node:
#   1. samples NEAREST (PixelUI.install_text_filter owns it — audit F2),
#   2. renders at >= PixelUI.TEXT_MIN_PX (48) — the one sanctioned exception is
#      tagged `text_min_exempt` (EffectPip duration superscript) — audit F3,
# plus the rules behind them: the scale_font_size ladder floors at 48 and every
# step is a multiple of the m5x7 native size (16); theme_overload.tres mirrors
# TEXT_MIN_PX (a duplicated constant is gated, not trusted); popups sized as a
# screen fraction land on whole EVEN design px (audit F5); INSPECT_TEXT_DIM
# clears 4.5:1 on every panel surface and stays dimmer than INSPECT_TEXT (F6).
# Autoloads/UI classes resolve at runtime (TRUTH's -s convention).
extends SceneTree

const NATIVE_EM := 16
# Ladder rungs allowed off the 16-lattice, each with the reason it could not move.
# 56 → 64 was tried in Step 1 and overflowed the single-line tutorial coach hint
# (the longest hint measured 1012 px against the 952 px coach width, wording fit gate).
const OFF_LATTICE_RUNGS := {56: "tutorial coach hint does not fit at 64"}
const THEME_PATH := "res://assets/ui/theme_overload.tres"
const SCREENS := {
	"home": "res://scenes/ui/UnitSelect.tscn",
	"fork": "res://scenes/ui/RouteForkScreen.tscn",
	"intercept": "res://scenes/ui/InterceptScreen.tscn",
	"reward": "res://scenes/ui/RewardScreen.tscn",
	"runend": "res://scenes/ui/RunEndScreen.tscn",
	"menu": "res://scenes/ui/MainMenu.tscn",
	"battle": "res://scenes/battle/BattleScene.tscn",
	"evolution": "res://scenes/ui/EvolutionScreen.tscn",
}

var failures: Array[String] = []
var _checked := 0
var _saw_locked_tile := false


func _initialize() -> void:
	call_deferred("_run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _run() -> void:
	await process_frame
	var pixel_ui: GDScript = load("res://scripts/ui/pixel_ui.gd")
	var min_px: int = pixel_ui.TEXT_MIN_PX
	_check_rules(pixel_ui, min_px)

	var gs: Node = root.get_node("/root/GameState")
	var sm: Node = root.get_node("/root/SaveManager")
	var dm: Node = root.get_node("/root/DataManager")
	# Headless forces every unlock (_fully_unlocked_override), which would hide
	# the smallest raw-px text (LOCKED tiles, the BEST: BATTLE line). Run the
	# sweep against a real, partly-locked profile (DevContext keeps it isolated).
	var disk_was: bool = bool(sm.get("_disk_enabled"))
	sm.set("_disk_enabled", true)
	sm.call("dev_reset_profile")
	sm.get("data")["unlocks"]["heroes"] = (sm.get("ALL_HEROES") as Array).slice(0, 4)
	sm.get("data")["unlocks"]["heroes_new"] = []
	var first_op: String = str((sm.get("OPERATION_CHAIN") as Array)[0])
	((sm.call("get_stats") as Dictionary)["best_clear_by_op"] as Dictionary)[first_op] = 7
	for key in SCREENS.keys():
		if key in ["fork", "intercept", "reward", "runend", "battle", "evolution"]:
			gs.call("start_run", ["combat", "avalanche", "medic"], "facility", 424242)
			gs.call("advance_to_next_battle")
		if key == "evolution":
			gs.set("pending_evolution_unit_id", "combat")
		change_scene_to_file(str(SCREENS[key]))
		await create_timer(0.8).timeout
		_walk_text(root, key, min_px)
		if key == "fork":
			await _check_popup(dm, min_px)
		if key == "home":
			load("res://scripts/ui/help_menu.gd").open(current_scene)
			await create_timer(0.4).timeout
			_walk_text(root, "help", min_px)
			load("res://scripts/ui/help_menu.gd").dismiss()
			await process_frame
		if key == "battle":
			load("res://scripts/ui/loadout_menu.gd").open(current_scene, [], [dm.call("get_item", "ironCurtain")], func(_i: Variant) -> void: pass)
			await create_timer(0.4).timeout
			_walk_text(root, "loadout", min_px)
	sm.call("dev_reset_profile")
	sm.set("_disk_enabled", disk_was)
	check(_saw_locked_tile, "home sweep never saw a LOCKED hero tile — the smallest raw-px text went untested")
	check(_checked >= 100, "walked only %d text nodes — the screen sweep is not reaching the UI" % _checked)

	if failures.is_empty():
		print("[TEXT_LEGIBILITY] PASS (%d text nodes)" % _checked)
	else:
		for f in failures:
			print("[TEXT_LEGIBILITY] FAIL: %s" % f)
	quit(0 if failures.is_empty() else 1)


func _check_rules(pixel_ui: GDScript, min_px: int) -> void:
	check(min_px % NATIVE_EM == 0, "TEXT_MIN_PX %d is not a multiple of the m5x7 native %d" % [min_px, NATIVE_EM])
	for step in pixel_ui.UI_FONT_STEPS:
		check(int(step) >= min_px, "UI_FONT_STEPS rung %d is below the floor" % int(step))
		check(int(step) % NATIVE_EM == 0 or OFF_LATTICE_RUNGS.has(int(step)), "UI_FONT_STEPS rung %d is not a multiple of %d" % [int(step), NATIVE_EM])
	for nominal in range(1, 121):
		check(int(pixel_ui.scale_font_size(nominal)) >= min_px, "scale_font_size(%d) renders below the floor" % nominal)
	var theme: Theme = load(THEME_PATH)
	check(theme != null and theme.default_font_size == min_px,
		"theme_overload.tres default_font_size (%s) must mirror PixelUI.TEXT_MIN_PX (%d)" % [str(theme.default_font_size) if theme != null else "?", min_px])
	for v in [993.6, 43.2, 1021.5, 7.0, 0.0, -3.0]:
		var snapped: float = pixel_ui.even_px(v)
		check(is_equal_approx(fmod(absf(snapped), 2.0), 0.0) and absf(snapped - v) <= 1.0, "even_px(%s) = %s" % [v, snapped])
	# Contrast floor for the tertiary text token (WCAG 2.x, 4.5:1 body text).
	var dim: Color = pixel_ui.INSPECT_TEXT_DIM
	var panels := {
		"DT_FIELD_BG": pixel_ui.DT_FIELD_BG, "DT_PANEL_BG": pixel_ui.DT_PANEL_BG,
		"INSPECT_BG": pixel_ui.INSPECT_BG, "BG_PANEL": pixel_ui.BG_PANEL,
		"BG_PANEL_ALT": pixel_ui.BG_PANEL_ALT, "DT_HERO_BG": pixel_ui.DT_HERO_BG,
		"DT_BTN_BG": pixel_ui.DT_BTN_BG,
	}
	for name in panels.keys():
		var ratio: float = _contrast(dim, panels[name])
		check(ratio >= 4.5, "INSPECT_TEXT_DIM on %s is %.2f:1 (< 4.5)" % [name, ratio])
	check(_contrast(pixel_ui.INSPECT_TEXT, pixel_ui.INSPECT_BG) > _contrast(dim, pixel_ui.INSPECT_BG) + 3.0,
		"INSPECT_TEXT_DIM must stay visibly dimmer than INSPECT_TEXT")


func _check_popup(dm: Node, min_px: int) -> void:
	var item: Resource = dm.call("get_item", "ironCurtain")
	var payload: Dictionary = load("res://scripts/ui/inspect_resolver.gd").resolve_item(item)
	var popup_script: GDScript = load("res://scripts/ui/inspect_popup.gd")
	popup_script.open(current_scene, payload)
	await create_timer(0.5).timeout
	var panels: Array = []
	_find_panels(root, panels)
	check(not panels.is_empty(), "relic InspectPopup did not open")
	for p in panels:
		var c := p as Control
		for v in [c.position.x, c.position.y, c.size.x, c.size.y]:
			check(is_equal_approx(fmod(absf(v), 2.0), 0.0), "InspectPopup rect %s is not on whole even design px" % str(Rect2(c.position, c.size)))
	_walk_text(root, "relic popup", min_px)
	popup_script.dismiss()


func _find_panels(n: Node, out: Array) -> void:
	# The InspectPopup CanvasLayer owns the positioned panel as `_panel`.
	var script: Script = n.get_script()
	if script != null and script.resource_path.ends_with("inspect_popup.gd"):
		var panel: Variant = n.get("_panel")
		if panel is Control:
			out.append(panel)
	for ch in n.get_children():
		_find_panels(ch, out)


func _walk_text(n: Node, where: String, min_px: int) -> void:
	var pixel_ui: GDScript = load("res://scripts/ui/pixel_ui.gd")
	if pixel_ui.is_text_node(n) and (n as CanvasItem).is_visible_in_tree():
		var c := n as Control
		var text := ""
		if n is Label: text = (n as Label).text
		elif n is Button: text = (n as Button).text
		elif n is RichTextLabel: text = (n as RichTextLabel).get_parsed_text()
		elif n is LineEdit: text = (n as LineEdit).text
		if text.strip_edges() != "":
			_checked += 1
			if where == "home" and text == "LOCKED":
				_saw_locked_tile = true
			var f: int = _effective_filter(c)
			check(f == CanvasItem.TEXTURE_FILTER_NEAREST, "%s: '%s' samples filter %d, not NEAREST" % [where, text.left(30), f])
			var size: int = c.get_theme_font_size("normal_font_size" if n is RichTextLabel else "font_size")
			if not c.has_meta("text_min_exempt"):
				check(size >= min_px, "%s: '%s' renders at %d px (< %d)" % [where, text.left(30), size, min_px])
	for ch in n.get_children():
		_walk_text(ch, where, min_px)


func _effective_filter(ci: CanvasItem) -> int:
	var n: Node = ci
	while n != null:
		if n is CanvasItem and (n as CanvasItem).texture_filter != CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			return (n as CanvasItem).texture_filter
		n = n.get_parent()
	return -1


func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


func _lum(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


func _contrast(a: Color, b: Color) -> float:
	var la: float = _lum(a)
	var lb: float = _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
