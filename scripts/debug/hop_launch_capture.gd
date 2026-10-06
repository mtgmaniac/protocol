# Captures the frames around a reroll hop's launch (G-47), to judge the
# random-orientation launch by eye: real speed and slowed down.
# WINDOWED only (no --headless: a headless viewport renders nothing).
#   set HOP_CAPTURE_OUT=C:/some/dir/   (default docs/ui_reference/hop_launch/)
#   godot --path . -s scripts/debug/hop_launch_capture.gd
# Writes, per hop, a contact sheet (hopN_real.png / hopN_slow.png: frame 0 is the
# last frame before the launch, one cell per drawn frame, left to right, top to
# bottom) and the individual frames under hopN_real/ and hopN_slow/.
extends SceneTree

const CaptureWindow := preload("res://scripts/debug/capture_window.gd")
const RUN_SEED := 20260926
const FRAMES := 40
const COLUMNS := 8
const SLOW_SCALE := 0.2
const HOPS := [["hero", 0], ["enemy", 0], ["hero", 1]]

var _out: String = ""


func _initialize() -> void:
	CaptureWindow.apply(root, Vector2i(1080, 2400))
	_out = OS.get_environment("HOP_CAPTURE_OUT")
	if _out == "":
		_out = ProjectSettings.globalize_path("res://docs/ui_reference/hop_launch/")
	DirAccess.make_dir_recursive_absolute(_out)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	root.get_node("SaveManager").call("set_setting", "ability_primers_enabled", false)
	var gs: Node = root.get_node("GameState")
	var dm: Node = root.get_node("DataManager")
	gs.call("start_run", ["combat", "engineer", "medic"], str(dm.call("get_operation_order")[0]), RUN_SEED)
	gs.call("advance_to_next_battle")
	change_scene_to_file("res://scenes/battle/BattleScene.tscn")
	await create_timer(1.5).timeout
	seed(RUN_SEED)
	current_scene.get_node("%RollButton").emit_signal("pressed")
	var tray: Node = current_scene.get("dice_tray_3d")
	await create_timer(1.0).timeout
	for _i in range(900):
		await process_frame
		if not bool(tray.get("_is_rolling")):
			break
	await create_timer(1.0).timeout
	var keys: Array = (tray.get("_die_by_key") as Dictionary).keys()
	keys.sort()
	var n := 0
	for pass_name in ["real", "slow"]:
		for hop in HOPS:
			n += 1
			var side: String = hop[0]
			var ids: Array = []
			for key in keys:
				var die: RigidBody3D = (tray.get("_die_by_key") as Dictionary)[key] as RigidBody3D
				var entry: Dictionary = die.get_meta("entry", {})
				if str(entry.get("side", "")) == side:
					ids.append(str(entry.get("id", "")))
			ids.sort()
			await _capture_hop(tray, side, str(ids[int(hop[1]) % ids.size()]), "hop%d_%s" % [(n - 1) % HOPS.size() + 1, pass_name], SLOW_SCALE if pass_name == "slow" else 1.0)
	print("[HOP_CAPTURE] frames and sheets -> %s" % _out)
	Engine.time_scale = 1.0
	quit()


func _capture_hop(tray: Node, side: String, unit_id: String, name: String, scale: float) -> void:
	var center: Vector2 = tray.call("get_die_screen_position", side, unit_id)
	var ratio: float = float(root.get_texture().get_width()) / float(root.get_visible_rect().size.x)
	var diameter: float = float(tray.call("get_die_projected_diameter", side, unit_id)) * ratio
	var half: float = maxf(diameter * 1.6, 120.0)
	var crop := Rect2i(Vector2i((center * ratio - Vector2(half, half * 1.3)).round()), Vector2i(int(half * 2.0), int(half * 2.0)))
	var tex_size: Vector2i = root.get_texture().get_size()
	crop.position.x = clampi(crop.position.x, 0, maxi(tex_size.x - crop.size.x, 0))
	crop.position.y = clampi(crop.position.y, 0, maxi(tex_size.y - crop.size.y, 0))
	var frames: Array = []
	await RenderingServer.frame_post_draw
	frames.append(_crop(crop))
	Engine.time_scale = scale
	tray.call("reroll_die_to_result", side, unit_id)
	for _i in range(FRAMES - 1):
		await RenderingServer.frame_post_draw
		frames.append(_crop(crop))
	Engine.time_scale = 1.0
	for _i in range(900):
		await process_frame
		if not bool(tray.get("_is_rolling")):
			break
	await create_timer(0.5).timeout
	var dir: String = _out.path_join(name)
	DirAccess.make_dir_recursive_absolute(dir)
	var cell: int = 200
	var rows: int = ceili(float(frames.size()) / COLUMNS)
	var sheet := Image.create(COLUMNS * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.05, 0.05, 0.05, 1.0))
	for i in range(frames.size()):
		var img: Image = frames[i]
		img.save_png(dir.path_join("f%02d.png" % i))
		var small: Image = img.duplicate()
		small.convert(Image.FORMAT_RGBA8)
		small.resize(cell, cell, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(small, Rect2i(0, 0, cell, cell), Vector2i((i % COLUMNS) * cell, (i / COLUMNS) * cell))
	sheet.save_png(_out.path_join(name + ".png"))
	print("[HOP_CAPTURE] %s %s:%s -> %d frames" % [name, side, unit_id, frames.size()])


func _crop(rect: Rect2i) -> Image:
	return root.get_texture().get_image().get_region(rect)
