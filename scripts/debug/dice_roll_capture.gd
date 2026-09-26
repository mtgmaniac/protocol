# Captures one battle roll frame by frame (P0 dice-face audit before/after).
# Same run seed + same global RNG seed => the same throws and the same drawn
# values on any build, so two builds can be compared frame for frame.
# WINDOWED only (no --headless: a headless viewport renders nothing).
#   set DICE_CAPTURE_OUT=C:/some/dir/
#   godot --path . -s scripts/debug/dice_roll_capture.gd
extends SceneTree

const RUN_SEED := 20260926
const FRAMES := 96
const INTERVAL := 0.05

var _out: String = ""


func _initialize() -> void:
	root.size = Vector2i(540, 1200)
	root.content_scale_size = Vector2i(1080, 2400)
	_out = OS.get_environment("DICE_CAPTURE_OUT")
	if _out == "":
		_out = ProjectSettings.globalize_path("res://debug_artifacts/dice_roll/")
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
	for i in range(FRAMES):
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(_out.path_join("roll_%03d.png" % i))
		await create_timer(INTERVAL).timeout
	print("[DICE_CAPTURE] %d frames -> %s" % [FRAMES, _out])
	quit()
