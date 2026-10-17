# Flat pixel B: every value 1-20 on a die's FRONT (top) face, both colors, in a
# battle-sized tray over the neutral tray floor, cropped into one grid image.
# Windowed only (needs a renderer).
#   <godot> --path . --script res://scripts/debug/dice_numeral_capture.gd \
#     --capture-window=360x800 --capture-output=<png> [--dice-render-shrink=N]
# Each round places three hero and two enemy dice with chosen values
# (DiceTray3D.place_rolls, no throw), lets the upright snap finish, grabs the
# frame and crops each die by get_die_screen_bounds.
extends SceneTree

const TRAY_RECT := Rect2(24, 742, 1032, 938)   # the battle tray, design px
const DESIGN_WIDTH := 1080.0
const PAD := 6

var _output := "res://debug_artifacts/flat_pixel_b/dice_numerals.png"
var _window := Vector2i(360, 800)


func _initialize() -> void:
	for arg: String in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg.begins_with("--capture-output="):
			_output = arg.trim_prefix("--capture-output=")
		elif arg.begins_with("--capture-window="):
			var parts := arg.trim_prefix("--capture-window=").split("x")
			_window = Vector2i(int(parts[0]), int(parts[1]))
	_run.call_deferred()


func _run() -> void:
	load("res://scripts/debug/capture_window.gd").apply(root, _window)
	var floor_rect := ColorRect.new()
	floor_rect.color = PixelUI.TRAY_GRATE_VOID
	# Grown past the tray so a crop at the tray edge never reaches the clear color.
	floor_rect.position = TRAY_RECT.position - Vector2(48, 48)
	floor_rect.size = TRAY_RECT.size + Vector2(96, 96)
	root.add_child(floor_rect)
	var host := Control.new()
	host.position = TRAY_RECT.position
	host.size = TRAY_RECT.size
	root.add_child(host)
	var tray: Control = load("res://scenes/battle/DiceTray3D.tscn").instantiate()
	host.add_child(tray)
	tray.call("set_combat_zone_rect", TRAY_RECT)
	for _i in range(4):
		await process_frame
	var crops: Dictionary = {"hero": {}, "enemy": {}}
	# Values 1-20 in both colors: 7 hero rounds of three, 10 enemy rounds of two.
	var rounds: Array = []
	for start in range(1, 21, 3):
		rounds.append({"hero": range(start, mini(start + 3, 21)), "enemy": []})
	for start in range(1, 21, 2):
		rounds.append({"hero": [], "enemy": range(start, mini(start + 2, 21))})
	for spec: Dictionary in rounds:
		var heroes: Array = []
		var enemies: Array = []
		var raws := {"hero": {}, "enemy": {}}
		for value in spec.hero:
			heroes.append({"id": "h%d" % value, "name": "h%d" % value})
			raws.hero["h%d" % value] = value
		for value in spec.enemy:
			enemies.append({"id": "e%d" % value, "name": "e%d" % value})
			raws.enemy["e%d" % value] = value
		await tray.call("place_rolls", heroes, enemies, raws)
		for _i in range(30):
			await process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = root.get_texture().get_image()
		var scale: float = float(frame.get_width()) / DESIGN_WIDTH
		for side: String in ["hero", "enemy"]:
			for value in spec[side]:
				var id: String = ("h%d" if side == "hero" else "e%d") % value
				var bounds: Rect2 = tray.call("get_die_screen_bounds", side, id)
				var px := Rect2i(Vector2i((bounds.position * scale).floor()) - Vector2i(PAD, PAD), Vector2i((bounds.size * scale).ceil()) + Vector2i(PAD * 2, PAD * 2))
				crops[side][value] = frame.get_region(px)
	# Grid: one row of 1-20 per color (wrapped in two rows of ten each).
	var cell := Vector2i.ZERO
	for side: String in crops:
		for value in crops[side]:
			var img: Image = crops[side][value]
			cell = Vector2i(maxi(cell.x, img.get_width()), maxi(cell.y, img.get_height()))
	var grid := Image.create(cell.x * 10, cell.y * 4, false, Image.FORMAT_RGBA8)
	grid.fill(Color(0.04, 0.05, 0.06))
	var row := 0
	for side: String in ["hero", "enemy"]:
		for value in range(1, 21):
			var img: Image = crops[side][value]
			img.convert(Image.FORMAT_RGBA8)
			var col: int = (value - 1) % 10
			var r: int = row + (value - 1) / 10
			grid.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(col * cell.x + (cell.x - img.get_width()) / 2, r * cell.y + (cell.y - img.get_height()) / 2))
		row += 2
	var path: String = ProjectSettings.globalize_path(_output) if _output.begins_with("res://") else _output
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	grid.save_png(path)
	print("[DICE_NUMERAL_CAPTURE] Saved: %s (cell %s, window %s)" % [path, str(cell), str(_window)])
	quit(0)
