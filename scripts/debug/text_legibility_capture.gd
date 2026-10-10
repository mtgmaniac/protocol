# Text legibility capture rig (docs/audits/TEXT_LEGIBILITY_AUDIT.md, Step 1).
# Opens one screen, walks every visible text node and dumps what the player sees
# — font size, color, outline, EFFECTIVE texture filter, physical origin, rect,
# line count — then saves the viewport. Run WINDOWED (headless has no renderer):
#   <godot_console> --path . -s res://scripts/debug/text_legibility_capture.gd \
#       --tl-screen=<name> --tl-out=<absolute dir> [--tl-window=WxH]
# Screens: home_best home_enclocked home_locked unit_inspect fork intercept relic
#          reward runend menu battle help loadout evolution unlock feedback
# Autoloads and UI classes are resolved at RUNTIME (root.get_node / load()): a
# bare autoload identifier fails compile under -s (TRUTH's -s convention).
extends SceneTree

const SCENES := {
	"home": "res://scenes/ui/UnitSelect.tscn",
	"fork": "res://scenes/ui/RouteForkScreen.tscn",
	"intercept": "res://scenes/ui/InterceptScreen.tscn",
	"reward": "res://scenes/ui/RewardScreen.tscn",
	"runend": "res://scenes/ui/RunEndScreen.tscn",
	"menu": "res://scenes/ui/MainMenu.tscn",
	"battle": "res://scenes/battle/BattleScene.tscn",
	"evolution": "res://scenes/ui/EvolutionScreen.tscn",
	"unlock": "res://scenes/ui/UnlockScreen.tscn",
}
const RUN_SCREENS := ["fork", "intercept", "relic", "reward", "runend", "battle", "battle_rolled", "battle_status", "loadout", "evolution"]
# battle_rolled forces the three die-tag tiers (same payloads as die_tag_probe.gd):
# hero 0 tier 1, hero 1 tier 1 two-pip, hero 2 tier 3, enemy 0 tier 2/3.
const HERO_PAYLOADS := [
	{"effects": [{"kind": "dmg", "value": "12", "duration": 0, "scope": ""}], "target": ""},
	{"effects": [
		{"kind": "dmg", "value": "10", "duration": 0, "scope": ""},
		{"kind": "burn", "value": "3", "duration": 3, "scope": ""},
	], "target": ""},
	{"effects": [
		{"kind": "dmg", "value": "18", "duration": 0, "scope": ""},
		{"kind": "burn", "value": "12", "duration": 3, "scope": ""},
		{"kind": "rfm", "value": "+12", "duration": 2, "scope": "all"},
	], "target": "SHIELD"},
]
const ENEMY_PAYLOAD := {"effects": [
	{"kind": "dmg", "value": "11", "duration": 0, "scope": ""},
	{"kind": "burn", "value": "3", "duration": 3, "scope": ""},
	{"kind": "roll", "value": "-2", "duration": 2, "scope": "all"},
], "target": ""}


func _initialize() -> void:
	call_deferred("_run")


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_args():
		if a.begins_with("--tl-%s=" % name):
			return a.get_slice("=", 1)
	return fallback


func _run() -> void:
	var screen := _arg("screen", "home_best")
	var out_dir := _arg("out", ProjectSettings.globalize_path("user://text_legibility"))
	var win := _arg("window", "")
	if win != "":
		DisplayServer.window_set_size(Vector2i(int(win.get_slice("x", 0)), int(win.get_slice("x", 1))))
	await process_frame
	var sm: Node = root.get_node("/root/SaveManager")
	var gs: Node = root.get_node("/root/GameState")
	var dm: Node = root.get_node("/root/DataManager")
	# Deterministic: same profile and seeds on every run, so before/after
	# captures of one screen show the same content.
	sm.call("dev_reset_profile")
	seed(424242)
	var stats: Dictionary = sm.call("get_stats")
	var first_op: String = str((sm.get("OPERATION_CHAIN") as Array)[0])
	match screen:
		"home_best":
			(stats["best_clear_by_op"] as Dictionary)[first_op] = 7
		"home_locked":
			sm.get("data")["unlocks"]["heroes"] = (sm.get("ALL_HEROES") as Array).slice(0, 4)
			sm.get("data")["unlocks"]["heroes_new"] = []
		"unlock":
			(sm.get("data")["stats"] as Dictionary)["battles_fought"] = 3
			sm.call("record_run_finished", "defeat", "facility", 3)
			sm.call("check_new_unlocks")
	if screen in RUN_SCREENS:
		gs.call("start_run", ["combat", "avalanche", "medic"], "facility", 424242)
		gs.call("advance_to_next_battle")
	if screen == "evolution":
		gs.set("pending_evolution_unit_id", "combat")
	var scene_key := screen
	if screen.begins_with("home") or screen in ["unit_inspect", "help", "feedback"]:
		scene_key = "home"
	elif screen == "relic":
		scene_key = "fork"
	elif screen in ["loadout", "battle_rolled", "battle_status"]:
		scene_key = "battle"
	change_scene_to_file(str(SCENES[scene_key]))
	await create_timer(1.5).timeout
	var scene: Node = current_scene
	match screen:
		"home_enclocked":
			for i in 8:
				if bool(scene.get("_current_op_locked")):
					break
				scene.call("_on_nav_pressed", 1)
		"relic":
			var item: Resource = dm.call("get_item", "ironCurtain")
			var payload: Dictionary = load("res://scripts/ui/inspect_resolver.gd").resolve_item(item)
			load("res://scripts/ui/inspect_popup.gd").open(scene, payload)
		"unit_inspect":
			var unit: Resource = dm.call("get_unit", "combat")
			var payload2: Dictionary = load("res://scripts/ui/inspect_resolver.gd").resolve_unit(unit)
			load("res://scripts/ui/inspect_popup.gd").open(scene, payload2)
		"help":
			load("res://scripts/ui/help_menu.gd").open(scene)
		"feedback":
			load("res://scripts/ui/feedback.gd")._show_blocked_panel(scene)  # never open_form: it shell_opens a URL on desktop
		"battle_rolled":
			var roll_button: Button = scene.get_node_or_null("%RollButton") as Button
			var dice_tray: Node = scene.get_node_or_null("%DiceTray3D")
			if roll_button != null and not roll_button.disabled:
				roll_button.emit_signal("pressed")
				if dice_tray != null and dice_tray.has_signal("roll_finished"):
					await dice_tray.roll_finished
				await create_timer(0.6).timeout
			var hero_views: Array = scene.get("hero_card_views")
			for i in range(mini(hero_views.size(), HERO_PAYLOADS.size())):
				var readout: Object = (hero_views[i] as Dictionary).get("readout")
				if readout != null and is_instance_valid(readout):
					readout.call("configure", HERO_PAYLOADS[i], "hero")
					readout.call("show_pips")
			var enemy_views: Array = scene.get("enemy_card_views")
			if not enemy_views.is_empty():
				var e_readout: Object = (enemy_views[0] as Dictionary).get("readout")
				if e_readout != null and is_instance_valid(e_readout):
					e_readout.call("configure", ENEMY_PAYLOAD, "enemy")
					e_readout.call("show_pips")
			await process_frame
			scene.call("_sync_die_tags")
		"battle_status":
			# Worst-case status strips: the RAMPAGE icon chip, multi-digit numerics, and
			# the +N overflow badge (more statuses than STATUS_MAX_VISIBLE).
			var sets := [
				["RAMPAGE 3", "BRN 12", "SH 15"],
				["BRN 3", "SH 100", "RFM +12", "CL", "MK"],
				["RAMPAGE", "FREEZE", "TAUNT"],
			]
			var views: Array = (scene.get("hero_card_views") as Array) + (scene.get("enemy_card_views") as Array)
			for i in views.size():
				var card: Object = (views[i] as Dictionary).get("card")
				if card != null and is_instance_valid(card):
					card.set("status_tokens", sets[i % sets.size()])
					card.call("_populate_statuses")
		"loadout":
			var items: Array = [dm.call("get_item", "ironCurtain")]
			load("res://scripts/ui/loadout_menu.gd").open(scene, [], items, func(_i: Variant) -> void: pass)
	await create_timer(0.8).timeout
	await process_frame
	await RenderingServer.frame_post_draw

	var rows: Array = []
	_walk(root, rows)
	var inherited: Array = []
	_walk_textures(root, inherited)
	var final_xf: Transform2D = root.get_final_transform()
	var tag := "%s_%s" % [screen, win if win != "" else "default"]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f := FileAccess.open(out_dir.path_join(tag + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({
		"screen": screen,
		"final_scale": final_xf.get_scale().x,
		"visible_rect": [root.get_visible_rect().size.x, root.get_visible_rect().size.y],
		"labels": rows,
		"textures_under_text_nodes": inherited,
	}, "  "))
	f.close()
	root.get_viewport().get_texture().get_image().save_png(out_dir.path_join(tag + ".png"))
	print("[TEXT_LEGIBILITY] %s labels=%d scale=%.4f" % [screen, rows.size(), final_xf.get_scale().x])
	quit(0)


func _effective_filter(ci: CanvasItem) -> int:
	var n: Node = ci
	while n != null:
		if n is CanvasItem and (n as CanvasItem).texture_filter != CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			return (n as CanvasItem).texture_filter
		n = n.get_parent()
	return -1  # project default


# Art that inherits its filter from a text node (the Button side effect of the
# NEAREST text rule): a Button's own icon / StyleBoxTexture, or a textured child.
func _walk_textures(n: Node, out: Array) -> void:
	if n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
		var draws_texture := n is TextureRect or n is NinePatchRect or n is TextureButton or n is Sprite2D
		if n is Button:
			var b := n as Button
			draws_texture = b.icon != null or b.get_theme_stylebox("normal") is StyleBoxTexture
		if draws_texture:
			var p: Node = n
			while p != null and p is CanvasItem and (p as CanvasItem).texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE:
				p = p.get_parent()
			if p != null and p is CanvasItem and (p is Label or p is Button or p is RichTextLabel or p is LineEdit):
				out.append({"path": str(n.get_path()).replace("/root/", ""), "type": n.get_class(), "from": str(p.name), "filter": (p as CanvasItem).texture_filter})
	for ch in n.get_children():
		_walk_textures(ch, out)


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
			var gx: Transform2D = c.get_global_transform_with_canvas()
			var phys: Transform2D = load("res://scripts/ui/pixel_ui.gd").physical_transform(c)
			var parent_rect := Rect2()
			if c.get_parent() is Control:
				var p := c.get_parent() as Control
				parent_rect = Rect2(p.get_global_transform_with_canvas().origin, p.size)
			rows.append({
				"path": str(c.get_path()).replace("/root/", ""),
				"type": c.get_class(),
				"text": text.substr(0, 60).replace("\n", " / "),
				"size": c.get_theme_font_size("normal_font_size" if rtl else "font_size"),
				"color": c.get_theme_color("default_color" if rtl else "font_color").to_html(true),
				"outline": c.get_theme_constant("outline_size"),
				"filter": _effective_filter(c),
				"design_pos": [gx.origin.x, gx.origin.y],
				"design_size": [c.size.x, c.size.y],
				"min_size": [c.get_combined_minimum_size().x, c.get_combined_minimum_size().y],
				"parent_rect": [parent_rect.position.x, parent_rect.position.y, parent_rect.size.x, parent_rect.size.y],
				"phys_pos": [phys.origin.x, phys.origin.y],
				"phys_scale": phys.get_scale().x,
				"lines": (n as Label).get_line_count() if n is Label else ((n as RichTextLabel).get_line_count() if rtl else 1),
				"clip": (n as Label).clip_text if n is Label else false,
			})
	for ch in n.get_children():
		_walk(ch, rows)
