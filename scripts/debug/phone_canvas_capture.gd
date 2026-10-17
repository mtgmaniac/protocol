# Captures a screen as a phone's canvas draws it, at its PHYSICAL resolution
# (UI batch A5, type-size options). The web export renders at devicePixelRatio
# (Godot's hidpi default), so a 390 CSS px iPhone at DPR 3 draws a 1170 x 2532
# canvas: canvas_items stretch at scale min(1170 / 1080, 2532 / 2400) = 1.055,
# a 1109 x 2400 design px layout. A window that tall does not fit the monitor
# (Windows clamps it), so the loaded screen and the shared header move into a
# SubViewport of the phone's size whose 2D override stretch is that same scale
# (fonts oversample from it exactly as from the window stretch).
#
#   godot --path . -s res://scripts/debug/phone_canvas_capture.gd \
#     --phone=1170x2532 --screen=title|squad|battle|battle_rolled|reward|help \
#     --capture-output=<png> [--type-option=<id>]
#
# --type-option=snap: the type-size proposal B mock (debug only, nothing in the
# game changes): every m5x7 Label keeps its layout size and is drawn
# pixel-exact at the largest whole k screen px per font pixel that does not
# grow it (PixelUI.bind_m5x7_snap), so each stroke is k px wide. Buttons keep
# their own text (not covered).
extends SceneTree

const BASE := Vector2(1080, 2400)
var _phone := Vector2i(1080, 2400)
var _screen := "squad"
var _output := "res://debug_artifacts/batch_a5/phone.png"
var _type_option := ""


func _initialize() -> void:
	for arg: String in OS.get_cmdline_args():
		if arg.begins_with("--phone="):
			var parts := arg.trim_prefix("--phone=").split("x")
			_phone = Vector2i(int(parts[0]), int(parts[1]))
		elif arg.begins_with("--screen="):
			_screen = arg.trim_prefix("--screen=")
		elif arg.begins_with("--capture-output="):
			_output = arg.trim_prefix("--capture-output=")
		elif arg.begins_with("--type-option="):
			_type_option = arg.trim_prefix("--type-option=")
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(540, 1200))
	root.size = Vector2i(540, 1200)
	var sm: Node = root.get_node("/root/SaveManager")
	var gs: Node = root.get_node("/root/GameState")
	sm.set("data", sm.call("default_data"))
	sm.get("data")["tutorial_done"] = true
	root.get_node("/root/AudioManager").call("set_suppressed", true)
	match _screen:
		"title":
			change_scene_to_file("res://scenes/ui/MainMenu.tscn")
		"squad", "help":
			change_scene_to_file("res://scenes/ui/UnitSelect.tscn")
		"battle", "battle_rolled":
			gs.call("start_run", ["combat", "engineer", "medic"], "facility")
			gs.call("advance_to_next_battle")
			change_scene_to_file("res://scenes/battle/BattleScene.tscn")
		"reward":
			gs.call("start_run", ["combat", "engineer", "medic"], "facility")
			gs.call("advance_to_next_battle")
			if gs.has_method("prepare_battle_rewards"):
				gs.call("prepare_battle_rewards")
			change_scene_to_file("res://scenes/ui/RewardScreen.tscn")
	# The title's logo boot-in runs before its buttons show.
	await create_timer(4.5 if _screen == "title" else 1.5).timeout
	var scene: Node = current_scene
	if _screen == "help":
		load("res://scripts/ui/help_menu.gd").open(scene)
		await process_frame
	if _screen == "battle_rolled" and scene.has_method("_on_roll_button_pressed"):
		scene.call("_on_roll_button_pressed")
		await create_timer(4.0).timeout
	var scale: float = minf(float(_phone.x) / BASE.x, float(_phone.y) / BASE.y)
	var phone := SubViewport.new()
	phone.size = _phone
	phone.size_2d_override = Vector2i((Vector2(_phone) / scale).round())
	phone.size_2d_override_stretch = true
	phone.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	phone.transparent_bg = false
	root.add_child(phone)
	# Everything the screen drew under root (the scene, the header, any
	# pop-up it opened) moves into the phone canvas, in draw order.
	for child: Node in root.get_children():
		if child == phone or child.get_script() == null and not (child is CanvasItem or child is CanvasLayer):
			continue
		if child is CanvasItem or child is CanvasLayer:
			child.reparent(phone, false)
	current_scene = scene
	for i in 30:
		await process_frame
	if _type_option == "snap":
		var snapped: int = _snap_m5x7_labels(phone, scale)
		print("[PHONE_CANVAS] option snap: %d m5x7 labels bound" % snapped)
		for i in 30:
			await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = phone.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(_output) if _output.begins_with("res://") else _output
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("[PHONE_CANVAS] %s %s scale %.4f design %s -> %s" % [_screen, _phone, scale, phone.size_2d_override, path])
	quit(0)


# Option B mock: every visible m5x7 Label at the largest whole screen px per
# font pixel at or under its size (a font pixel is size / 16 design px).
func _snap_m5x7_labels(host: Node, scale: float) -> int:
	var pixel_ui: Script = load("res://scripts/ui/pixel_ui.gd")
	var m5x7: Font = pixel_ui.call("get_pixel_font")
	var count := 0
	for node: Node in host.find_children("*", "Label", true, false):
		var label := node as Label
		if label.get_theme_font("font") != m5x7 or label.has_meta("block_px") or not (label.get_parent() is CanvasItem):
			continue
		# Laid out at its own (lattice) size, so the glyphs rasterize a whole
		# number of texels per font pixel, then drawn at the largest whole k
		# screen px per font pixel that does not grow the text.
		var font_px: float = float(label.get_theme_font_size("font_size")) / 16.0
		var k: int = maxi(1, floori(font_px * scale + 0.001))
		pixel_ui.call("bind_m5x7_snap", label, float(k) / scale, maxf(font_px, float(k) / scale))
		count += 1
	return count
