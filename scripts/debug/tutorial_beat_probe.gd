# DIAGNOSTIC ONLY (2026-09-20 framing-beat + long-press pass) — not a gate.
# Boots the drill at whatever window size the binary was launched with, parks it
# on a given beat, and reports the coach panel's fit plus the live long-press
# cancel tolerance. Flags (before any `--` separator):
#   --beat=<index>   which beat to park on (default 0)
#   --assist         shorten the stuck-beat budget and wait for the offer
extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _pause(n: int) -> void:
	for _i in n:
		await process_frame


func _run() -> void:
	var beat: int = 0
	var want_assist: bool = false
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--beat="):
			beat = int(arg.get_slice("=", 1))
		elif arg == "--assist":
			want_assist = true
	await _pause(3)
	root.get_node("GameState").start_tutorial_run(true)
	root.get_node("SceneManager").go_to_battle()
	await _pause(90)
	var scene: Node = current_scene
	var tut: Node = null
	for child in scene.get_children():
		if child is TutorialController:
			tut = child
	if tut == null:
		print("[BEAT] no controller")
		quit(1)
		return
	if want_assist:
		tut.set("gated_assist_secs", 1.0)
	tut.call("_show_step", beat)
	await _pause(10)
	if want_assist:
		var deadline: int = Time.get_ticks_msec() + 8000
		while Time.get_ticks_msec() < deadline and not bool(tut.call("is_assist_offered")):
			await process_frame
		await _pause(6)
		print("[BEAT] assist offered=%s" % str(tut.call("is_assist_offered")))

	var win: Vector2i = DisplayServer.window_get_size()
	var vis: Rect2 = root.get_visible_rect()
	var view_scale: float = root.get_final_transform().get_scale().x
	print("[BEAT] window=%dx%d design=%.0fx%.0f scale=%.4f beat=%d/%d advance=%s" % [
		win.x, win.y, vis.size.x, vis.size.y, view_scale,
		int(tut.get("_step")) + 1, (tut.get("_steps") as Array).size(),
		str(tut.call("_advance_mode"))])

	var spot = tut.get("_spot")
	var coach: Control = spot.get("_coach") as Control
	var label: Label = spot.get("_coach_label") as Label
	var coach_rect: Rect2 = coach.get_global_rect()
	var needed: Vector2 = coach.get_combined_minimum_size()
	print("[BEAT] coach rect=%s" % str(coach_rect))
	print("[BEAT] coach needs=%.0fx%.0f  has=%.0fx%.0f  clipped=%s" % [
		needed.x, needed.y, coach_rect.size.x, coach_rect.size.y,
		str(coach_rect.size.y + 0.5 < needed.y or coach_rect.size.x + 0.5 < needed.x)])
	print("[BEAT] inside viewport=%s  margins l=%.0f r=%.0f t=%.0f b=%.0f" % [
		str(vis.encloses(coach_rect)),
		coach_rect.position.x, vis.size.x - coach_rect.end.x,
		coach_rect.position.y, vis.size.y - coach_rect.end.y])
	print("[BEAT] label lines=%d  font=%d design px (%.1f device px)  holes=%d" % [
		label.get_line_count(), label.get_theme_font_size("font_size"),
		float(label.get_theme_font_size("font_size")) * view_scale,
		(spot.get("_dim_canvas").get("holes") as Array).size()])
	print("[BEAT] title=%s" % str(tut.call("_current").get("title", "")))

	# Live long-press cancel tolerance on a real battle card.
	var views: Variant = scene.get("hero_card_views")
	if views is Array and not (views as Array).is_empty():
		var card: Object = ((views as Array)[0] as Dictionary).get("card", null)
		var lp: Object = card.get("_portrait_long_press") if card != null else null
		if lp != null:
			var design_px: float = float(lp.call("move_cancel_distance"))
			print("[BEAT] long-press cancel: %.1f design px = %.1f device px (hold %.2fs)" % [
				design_px, design_px * view_scale, PixelUI.INSPECT_HOLD_SEC])

	var img: Image = root.get_texture().get_image()
	var out := "res://debug_artifacts/beat%d%s_%dx%d.png" % [beat, "_assist" if want_assist else "", win.x, win.y]
	img.save_png(ProjectSettings.globalize_path(out))
	print("[BEAT] shot=%s" % out)
	quit(0)
