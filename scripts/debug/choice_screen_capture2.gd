# Quick evolution-screen capture for the ability-row restyle verification.
# Run windowed: <godot> --path . --script res://scripts/debug/choice_screen_capture2.gd
extends SceneTree

const OUTPUT := "res://debug_artifacts/battle_ui/evolution_rows.png"


func _initialize() -> void:
	root.size = Vector2i(540, 1200)
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gs: Node = root.get_node("/root/GameState")
	gs.call("start_run", ["combat", "avalanche", "medic"], "facility")
	gs.set("pending_evolution_unit_id", "avalanche")
	# --directive: jump to the tier-3 directive pick (evolution already chosen).
	if "--directive" in OS.get_cmdline_args():
		(gs.get("unit_evolutions") as Dictionary)["avalanche"] = "Glacier Mantle"
	change_scene_to_file("res://scenes/ui/EvolutionScreen.tscn")
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var path: String = ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var image: Image = root.get_texture().get_image()
	if image != null:
		image.save_png(path)
		print("[EVO_CAPTURE] saved %s" % path)
	quit(0)
