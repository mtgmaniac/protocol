extends "res://scripts/debug/training_flow_test.gd"

var captured: Dictionary = {}

func pause(count: int = 3) -> void:
	await super.pause(count)
	if DisplayServer.get_name() == "headless" or current_scene == null:
		return
	var tut: Node = controller(current_scene)
	var key: String = "reward" if current_scene.has_method("_claim_reward") else "other"
	if tut != null:
		key = "battle%d-step%d" % [root.get_node("GameState").current_battle, int(tut.get("_step"))]
	if find_prompt(current_scene) != null:
		key += "-choice"
	if key == "other" or captured.has(key):
		return
	captured[key] = true
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var folder: String = "res://debug_artifacts/training-captures/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder + key + ".png"))
