# DIAGNOSTIC ONLY (2026-09-20 desktop-fit investigation) — not a gate.
# Boots the tutorial battle at whatever window size the binary was launched
# with and dumps the resulting design-space geometry, so the desktop-aspect
# behaviour of stretch=expand can be measured instead of guessed.
extends SceneTree

const SETTLE_FRAMES := 90


func _initialize() -> void:
	call_deferred("_run")


func _pause(n: int) -> void:
	for _i in n:
		await process_frame


func _run() -> void:
	await _pause(3)
	var gs = root.get_node("GameState")
	var sm = root.get_node("SceneManager")
	gs.start_tutorial_run(true)
	sm.go_to_battle()
	await _pause(SETTLE_FRAMES)

	var win: Vector2i = DisplayServer.window_get_size()
	var vis: Rect2 = root.get_visible_rect()
	print("[FIT] window_px=%dx%d  design_viewport=%.0fx%.0f  scale=%.4f  content_scale_size=%s" % [
		win.x, win.y, vis.size.x, vis.size.y,
		(float(win.y) / vis.size.y) if vis.size.y > 0.0 else 0.0,
		str(root.content_scale_size)])
	print("[FIT] stretch_mode=%d aspect=%d" % [root.content_scale_mode, root.content_scale_aspect])

	var scene: Node = current_scene
	if scene == null:
		print("[FIT] no scene")
		quit(1)
		return
	print("[FIT] scene=%s" % scene.name)
	_dump_control("scene_root", scene as Control, vis)
	for prop in ["board", "center_panel", "hero_cards", "enemy_cards", "roll_button", "protocol_bar"]:
		_dump_control(prop, scene.get(prop) as Control, vis)

	var layout = scene.get("_layout")
	if layout != null:
		var cz: Rect2 = layout.get_combat_zone_rect()
		print("[FIT] combat_zone=%s inside=%s" % [str(cz), str(vis.encloses(cz))])

	var tut: Node = null
	for child in scene.get_children():
		if child is TutorialController:
			tut = child
	if tut == null:
		print("[FIT] no tutorial controller")
	else:
		print("[FIT] tutorial step=%d advance=%s" % [int(tut.get("_step")), str(tut.call("_advance_mode"))])
		for key in ["roll_button", "hero_cards", "center", "protocol_bar", "nudge", "item"]:
			var r: Rect2 = tut.call("_target_rect", key)
			print("[FIT]   target %-14s rect=%s inside=%s" % [key, str(r), str(r.size != Vector2.ZERO and vis.encloses(r))])
		var spot = tut.get("_spot")
		if spot != null:
			var coach: Control = spot.get("_coach") as Control
			if coach != null:
				print("[FIT]   coach rect=%s visible=%s inside=%s" % [str(coach.get_global_rect()), str(coach.visible), str(vis.encloses(coach.get_global_rect()))])

	var img: Image = root.get_texture().get_image()
	var out := "res://debug_artifacts/desktop_fit_%dx%d.png" % [win.x, win.y]
	img.save_png(ProjectSettings.globalize_path(out))
	print("[FIT] shot=%s" % out)
	quit(0)


func _dump_control(label: String, c: Control, vis: Rect2) -> void:
	if c == null or not is_instance_valid(c):
		print("[FIT] %-12s <null>" % label)
		return
	var r: Rect2 = c.get_global_rect()
	print("[FIT] %-12s rect=%s inside=%s" % [label, str(r), str(vis.encloses(r))])
