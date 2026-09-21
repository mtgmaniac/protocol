extends SceneTree

# Store-art render of a single settled d20 on a transparent background.
#
# Nothing about the die is rebuilt here. A real DiceTray3D spawns it through its
# own _spawn_die (so body, face, bevel, edge and numeral materials all come from
# _bank_material), then applies the same result presentation a settled roll gets:
# _highlight_top_face + RESULT_SCALE. A second, larger SubViewport SHARES the
# tray's World3D, so the die is lit by the tray's own key light, fill light and
# ambient environment — no lighting constants are copied into this file, which
# would drift the first time the tray's lighting is retuned.
#
# The camera looks straight down like the tray's, and by default the die sits
# result-face-up exactly as a settled roll does in battle. An optional tilt
# rotates the DIE (not the camera), so the lights keep their battle angle.
#
# Needs a real renderer (drop --headless; see captures-run-windowed). Put the
# flags BEFORE any "--" separator, or read them as user args after it — both
# are accepted:
#   Godot_v4.6.2-stable_win64_console.exe --path . -s res://scripts/debug/dice_portrait_capture.gd --value=20 --role=hero
#
# Flags:
#   --value=N          face to show, 1-20 (required)
#   --role=hero|enemy  hero-blue or enemy-rust die (required)
#   --size=N           square output in px, min 512 (default 1024)
#   --style=result|plain
#                      result (default): the settled look — result face lit,
#                      other faces dimmed, as the player sees it after a roll.
#                      plain: every face at full brightness, as while tumbling.
#   --tilt-x=DEG --tilt-z=DEG
#                      optional three-quarter tilt (default 0 / 0 = as in
#                      battle; 24 / -16 reads the facets for store art).
# Output: docs/visuals/store/dice_<role>_<value>.png

const TRAY_SCENE := "res://scenes/battle/DiceTray3D.tscn"
const OUTPUT_DIR := "res://docs/visuals/store/"
const MIN_SIZE := 512
const DEFAULT_SIZE := 1024
const DEFAULT_TILT_X := 0.0
const DEFAULT_TILT_Z := 0.0
# Ortho frame height in world units. The die's circumradius is DIE_RADIUS and the
# settled visuals are scaled by RESULT_SCALE; this leaves a small margin all round.
const FRAME_PADDING := 1.18
const WARM_FRAMES := 12


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := _parse_args()
	var err := _validate(args)
	if err != "":
		push_error("[DICE_PORTRAIT] " + err)
		quit(2)
		return
	if DisplayServer.get_name() == "headless":
		push_error("[DICE_PORTRAIT] needs a real renderer - run without --headless")
		quit(2)
		return

	var audio := root.get_node_or_null("AudioManager")
	if audio != null and audio.has_method("set_suppressed"):
		audio.set_suppressed(true)

	var value: int = int(args["value"])
	var role: String = str(args["role"])
	var px: int = int(args.get("size", DEFAULT_SIZE))
	var style: String = str(args.get("style", "result"))
	var tilt_x: float = float(args.get("tilt-x", DEFAULT_TILT_X))
	var tilt_z: float = float(args.get("tilt-z", DEFAULT_TILT_Z))

	var tray := load(TRAY_SCENE).instantiate() as DiceTray3D
	tray.custom_minimum_size = Vector2(1056, 1100)
	root.add_child(tray)
	# The tray's own viewport never needs to draw; only its World3D is used.
	tray.visible = false
	await process_frame

	var die: RigidBody3D = tray._spawn_die({"id": "store_%s" % role, "side": role}, 0, 1)
	die.freeze = true
	die.linear_velocity = Vector3.ZERO
	die.angular_velocity = Vector3.ZERO
	tray._set_die_collision_enabled(die, false)
	tray._set_die_result_scale(die, false)
	if style == "result":
		tray._highlight_top_face(die, value, role)

	# Rest where that side's results sit (mirrors _get_unit_slot_origin: enemy
	# row is on the far side, -Z), so the omni fill light falls as in battle.
	var row_z: float = DiceTray3D.RESULT_HERO_ROW_Z if role == "hero" else -DiceTray3D.RESULT_ENEMY_ROW_Z
	var origin := Vector3(0.0, DiceTray3D.SETTLED_DIE_HALF_HEIGHT_UNITS, row_z)
	var face_up: Basis = tray._get_face_forward_result_basis(tray._get_face_index_for_result(value))
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(tilt_x)) * Basis(Vector3.BACK, deg_to_rad(tilt_z))
	die.global_transform = Transform3D((tilt * face_up).orthonormalized(), origin)

	var shot := SubViewport.new()
	shot.size = Vector2i(px, px)
	shot.transparent_bg = true
	shot.msaa_3d = Viewport.MSAA_8X
	shot.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	shot.world_3d = tray._viewport.world_3d
	root.add_child(shot)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = DiceTray3D.DIE_RADIUS * DiceTray3D.RESULT_SCALE * 2.0 * FRAME_PADDING
	camera.near = 0.05
	camera.far = 20.0
	shot.add_child(camera)
	camera.global_transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-90.0), 0.0, 0.0)), origin + Vector3.UP * 6.0)
	camera.current = true

	for _i in WARM_FRAMES:
		await process_frame
	await RenderingServer.frame_post_draw

	var image: Image = shot.get_texture().get_image()
	var dir_abs := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir_abs)
	var out_path := dir_abs.path_join("dice_%s_%d.png" % [role, value])
	var save_err := image.save_png(out_path)
	if save_err != OK:
		push_error("[DICE_PORTRAIT] save failed (%d): %s" % [save_err, out_path])
		quit(1)
		return
	print("[DICE_PORTRAIT] wrote %s (%dx%d, style=%s, tilt=%.0f/%.0f)" % [out_path, px, px, style, tilt_x, tilt_z])
	quit(0)


func _parse_args() -> Dictionary:
	var out := {}
	var all_args: PackedStringArray = OS.get_cmdline_args()
	all_args.append_array(OS.get_cmdline_user_args())
	for arg in all_args:
		if not arg.begins_with("--") or not arg.contains("="):
			continue
		var pair := arg.substr(2).split("=", true, 1)
		out[pair[0]] = pair[1]
	return out


func _validate(args: Dictionary) -> String:
	if not args.has("value") or not str(args["value"]).is_valid_int():
		return "--value=N is required (1-20)"
	var value := int(args["value"])
	if value < 1 or value > 20:
		return "--value must be 1-20, got %d" % value
	var role := str(args.get("role", ""))
	if role != "hero" and role != "enemy":
		return "--role=hero|enemy is required"
	if args.has("size") and (not str(args["size"]).is_valid_int() or int(args["size"]) < MIN_SIZE):
		return "--size must be an integer >= %d" % MIN_SIZE
	var style := str(args.get("style", "result"))
	if style != "result" and style != "plain":
		return "--style must be result or plain"
	for key in ["tilt-x", "tilt-z"]:
		if args.has(key) and not str(args[key]).is_valid_float():
			return "--%s must be a number" % key
	return ""
