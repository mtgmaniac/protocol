# Spotlight-density capture rig (Tutorial V3.1 spec §4.2). Drives the real drill
# and screenshots the DENSEST spotlight moments at true preview size so the
# discrete-sub-region cluster model can be judged before it is built on:
#   cluster_beat07  — 5 discrete holes (2 order badges + medic card/die/pips)
#   cluster_beat11  — 6 discrete holes (both hero clusters, stage 1)
#   cluster_beat11_retarget — 9 discrete holes (stage 1 + appended legal allies)
# Output: debug_artifacts/tutorial/cluster_*.png
# Run (windowed — screenshots need a real renderer):
#   godot --path . -s scripts/debug/tutorial_spotlight_capture.gd
extends SceneTree

const OUT_DIR := "res://debug_artifacts/tutorial/"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var gs: Node = root.get_node("/root/GameState")
	gs.call("start_tutorial_run")
	root.get_node("/root/SceneManager").call("go_to_battle")
	var retries := 240
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/battle/BattleScene.tscn":
			break
	await create_timer(1.2).timeout
	var scene: Node = current_scene
	var controller: Node = null
	for child in scene.get_children():
		if child.has_method("allows_action"):
			controller = child
	if controller == null:
		push_error("[SPOTLIGHT_CAPTURE] no TutorialController")
		quit(1)
		return

	var enemy_id: String = _enemy_id(scene)
	controller.call("_next")                                   # beat 1 -> 2
	await _wait_step(controller, 1)
	scene.call("_on_roll_button_pressed")                      # beat 2 -> waiter A
	await _wait_step(controller, 3)
	scene.call("_on_unit_detail_requested", (scene.get("hero_card_views") as Array)[0].get("card"))
	await create_timer(0.5).timeout
	scene.call("_close_tutorial_inspection")                   # beat 3 -> 4
	await _wait_step(controller, 4)
	controller.call("_next")                                   # beat 4 -> 5
	await _wait_step(controller, 5)
	await _assign(scene, "combat", enemy_id)                   # beat 5 -> 6
	await _wait_step(controller, 6)
	await _assign(scene, "engineer", enemy_id)                 # beat 6 -> 7
	await _wait_step(controller, 7)

	await _shot(controller, "cluster_beat07")                  # 5 discrete holes

	await _assign(scene, "medic", enemy_id)                    # beat 7 -> 8
	await _wait_step(controller, 8)
	scene.call("_on_roll_button_pressed")                      # beat 8 -> 9
	await _wait_step(controller, 9)
	scene.call("_on_roll_button_pressed")                      # beat 9 -> waiter B
	await _wait_step(controller, 11)
	var protocol: Node = scene.get("_protocol")
	protocol.call("_on_nudge_button_pressed")
	protocol.call("handle_hero_card_pressed", _state_id(scene, "combat"))
	await _wait_step(controller, 12)                           # beat 10 -> 11

	await _shot(controller, "cluster_beat11")                  # 6 discrete holes

	# Stage 2: select the medic so the legal ALLY targets get appended.
	scene.call("_on_hero_card_pressed", _state_id(scene, "medic"))
	await create_timer(0.5).timeout
	await _shot(controller, "cluster_beat11_retarget")         # 9 discrete holes

	# §5 redirect, on the same dense beat: an off-script tap while the medic is
	# targeting must pulse the LEGAL TARGET, keeping the source cluster spotlit.
	scene.set("_tutorial_redirect_msec", 0)
	scene.call("_on_enemy_card_pressed", enemy_id)             # illegal: heal wants an ally
	await create_timer(0.16).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT_DIR + "redirect_target.png"))

	# And the source-cluster form: cancel targeting, then tap the wrong hero.
	scene.call("_unassign_hero_cast", _state_id(scene, "medic"))
	await create_timer(0.4).timeout
	scene.set("_tutorial_redirect_msec", 0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT_DIR + "redirect_cluster_before.png"))
	scene.call("_on_hero_card_pressed", _state_id(scene, "engineer"))
	await create_timer(0.16).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT_DIR + "redirect_cluster.png"))
	print("[SPOTLIGHT_CAPTURE] redirect captures written (step=%d)" % int(controller.get("_step")))
	quit(0)


func _shot(controller: Node, name: String) -> void:
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT_DIR + name + ".png"))
	var holes: Array = controller.call("_compute_holes", controller.call("_current"))
	print("[SPOTLIGHT_CAPTURE] %s step=%d holes=%d size=%dx%d" % [
		name, int(controller.get("_step")), holes.size(), img.get_width(), img.get_height()])


func _assign(scene: Node, unit_id: String, target_id: String) -> void:
	scene.call("_on_hero_card_pressed", _state_id(scene, unit_id))
	await create_timer(0.2).timeout
	scene.call("_on_enemy_card_pressed", target_id)
	await create_timer(0.2).timeout


func _state_id(scene: Node, unit_id: String) -> String:
	for view_variant in (scene.get("hero_card_views") as Array):
		var state: Dictionary = (view_variant as Dictionary).get("state", {})
		var unit: Object = state.get("unit", null) as Object
		if unit != null and str(unit.get("id")) == unit_id:
			return str(state.get("id", ""))
	return ""


func _enemy_id(scene: Node) -> String:
	var views: Array = scene.get("enemy_card_views") as Array
	return str((views[0] as Dictionary).get("state", {}).get("id", "")) if not views.is_empty() else ""


func _wait_step(controller: Node, index: int) -> void:
	var frames: int = 1800
	while frames > 0:
		frames -= 1
		await process_frame
		if int(controller.get("_step")) >= index:
			await process_frame
			await process_frame
			return
	push_error("[SPOTLIGHT_CAPTURE] timed out waiting for step %d (at %d)" % [index, int(controller.get("_step"))])
