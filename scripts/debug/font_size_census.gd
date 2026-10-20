# Font-size census (crisp text step 1, 2026-10-19). Loads the live screens and
# lists every visible text node with the size that reaches its font, its face
# and the script that built it, so the type sizes in use can be counted.
# Headless:  <godot> --headless --path . -s scripts/debug/font_size_census.gd \
#     [--census-out=<absolute json path>]
# Battle Block labels are drawn by bind_block_snap at a per-device size; the
# census reports the size each would draw at the itch canvas (scale 0.4) and the
# phone canvas (scale 1.0) as well as the laid-out size.
# Autoloads and UI classes resolve at RUNTIME (TRUTH's -s convention).
extends SceneTree

const SCREENS := {
	"menu": "res://scenes/ui/MainMenu.tscn",
	"home": "res://scenes/ui/UnitSelect.tscn",
	"fork": "res://scenes/ui/RouteForkScreen.tscn",
	"intercept": "res://scenes/ui/InterceptScreen.tscn",
	"reward": "res://scenes/ui/RewardScreen.tscn",
	"runend": "res://scenes/ui/RunEndScreen.tscn",
	"battle": "res://scenes/battle/BattleScene.tscn",
	"evolution": "res://scenes/ui/EvolutionScreen.tscn",
	"unlock": "res://scenes/ui/UnlockScreen.tscn",
}
const HELP_TABS := ["settings", "basics", "icons", "units", "log"]

var rows: Array = []
var label3d_rows: Array = []
var pixel_ui: GDScript


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	pixel_ui = load("res://scripts/ui/pixel_ui.gd")
	var out := ProjectSettings.globalize_path("res://debug_artifacts/text_40_80_120/census.json")
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a.begins_with("--census-out="):
			out = a.trim_prefix("--census-out=")
	var gs: Node = root.get_node("/root/GameState")
	var sm: Node = root.get_node("/root/SaveManager")
	var dm: Node = root.get_node("/root/DataManager")
	root.get_node("/root/AudioManager").call("set_suppressed", true)
	var disk_was: bool = bool(sm.get("_disk_enabled"))
	sm.set("_disk_enabled", true)
	sm.call("dev_reset_profile")
	sm.get("data")["tutorial_done"] = true
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
		if key == "unlock":
			(sm.get("data")["stats"] as Dictionary)["battles_fought"] = 3
			sm.call("record_run_finished", "defeat", "facility", 3)
			sm.call("check_new_unlocks")
		change_scene_to_file(str(SCREENS[key]))
		await create_timer(5.0 if key == "menu" else 1.0).timeout
		var scene: Node = current_scene
		if key == "home":
			scene.call("_on_tile_tapped", "combat")
			await create_timer(0.3).timeout
		_walk(root, key)
		if key == "home":
			var unit: Resource = dm.call("get_unit", "combat")
			var payload: Dictionary = scene.call("unit_inspect_payload", unit)
			load("res://scripts/ui/inspect_popup.gd").open(scene, payload)
			await create_timer(0.5).timeout
			_walk_layer(root, "unit inspect", "inspect_popup.gd")
			load("res://scripts/ui/inspect_popup.gd").dismiss()
			await process_frame
			for tab in HELP_TABS:
				load("res://scripts/ui/help_menu.gd").open(scene)
				await process_frame
				var menus: Array = root.find_children("*", "HelpMenu", true, false)
				if not menus.is_empty():
					(menus[0] as Node).call("_select_tab", tab)
				await create_timer(0.4).timeout
				_walk_layer(root, "help " + tab, "help_menu.gd")
				load("res://scripts/ui/help_menu.gd").dismiss()
				await create_timer(0.2).timeout
		if key == "fork":
			var item: Resource = dm.call("get_item", "ironCurtain")
			var relic: Dictionary = load("res://scripts/ui/inspect_resolver.gd").resolve_item(item)
			load("res://scripts/ui/inspect_popup.gd").open(scene, relic)
			await create_timer(0.5).timeout
			_walk_layer(root, "relic inspect", "inspect_popup.gd")
			load("res://scripts/ui/inspect_popup.gd").dismiss()
			await process_frame
		if key == "battle":
			_walk_3d(root, "battle")
			load("res://scripts/ui/loadout_menu.gd").open(scene, [], [dm.call("get_item", "ironCurtain")], func(_i: Variant) -> void: pass)
			await create_timer(0.4).timeout
			_walk_layer(root, "loadout", "loadout_menu.gd")
	sm.call("dev_reset_profile")
	sm.set("_disk_enabled", disk_was)
	var tally := {}
	for r in rows:
		var k := "%s %d" % [r["font"], int(r["itch_px"])]
		tally[k] = int(tally.get(k, 0)) + 1
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"rows": rows, "label3d": label3d_rows, "tally": tally}, "  "))
	f.close()
	for k in tally.keys():
		print("[CENSUS] %s x%d" % [k, int(tally[k])])
	print("[CENSUS] DONE %d text nodes, %d Label3D -> %s" % [rows.size(), label3d_rows.size(), out])
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


func _owner_script(n: Node) -> String:
	var p: Node = n
	while p != null:
		var s: Script = p.get_script()
		if s != null and not s.resource_path.ends_with("long_press_input.gd"):
			return s.resource_path.get_file()
		p = p.get_parent()
	return "?"


# Only the nodes under the CanvasLayer / popup owned by `script_name`.
func _walk_layer(n: Node, where: String, script_name: String) -> void:
	var s: Script = n.get_script()
	if s != null and s.resource_path.ends_with(script_name):
		_walk(n, where)
		return
	for ch in n.get_children():
		_walk_layer(ch, where, script_name)


func _walk(n: Node, where: String) -> void:
	if n is Label or n is Button or n is RichTextLabel or n is LineEdit:
		var c := n as Control
		var text := ""
		if n is Label: text = (n as Label).text
		elif n is Button: text = (n as Button).text
		elif n is RichTextLabel: text = (n as RichTextLabel).get_parsed_text()
		elif n is LineEdit: text = (n as LineEdit).text
		if c.is_visible_in_tree() and text.strip_edges() != "":
			var rtl := n is RichTextLabel
			var size: int = c.get_theme_font_size("normal_font_size" if rtl else "font_size")
			var itch := float(size)
			var phone := float(size)
			var snap := ""
			if c.has_meta("block_px"):
				var px: Vector2 = c.get_meta("block_px")
				itch = pixel_ui.block_pixel_px(px.x, px.y, 0.4) * 16.0
				phone = pixel_ui.block_pixel_px(px.x, px.y, 1.0) * 16.0
				snap = "%s..%s" % [px.x, px.y]
			rows.append({
				"screen": where,
				"script": _owner_script(n),
				"node": str(n.name),
				"type": n.get_class(),
				"text": text.substr(0, 48).replace("\n", " / "),
				"font": _font_name(c.get_theme_font("normal_font" if rtl else "font")),
				"layout_px": size,
				"itch_px": itch,
				"phone_px": phone,
				"snap": snap,
				"exempt": c.has_meta("text_min_exempt"),
			})
	for ch in n.get_children():
		_walk(ch, where)


func _walk_3d(n: Node, where: String) -> void:
	if n is Label3D and (n as Label3D).is_visible_in_tree():
		var l := n as Label3D
		label3d_rows.append({"screen": where, "script": _owner_script(n), "node": str(n.name), "text": l.text, "font_size": l.font_size, "pixel_size": l.pixel_size})
	for ch in n.get_children():
		_walk_3d(ch, where)
