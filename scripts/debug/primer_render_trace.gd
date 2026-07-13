# RENDER-TIME anchor trace (Kev 2026-07-13 — STOP FIXING, instrument).
# For every primer modal in a real windowed drain, samples TWICE (first
# rendered frame + 0.65s into the modal):
#   c1 icon taught          — resolver trace
#   c2 resolver rect + link — resolver trace (+ heal_ran, resolve frame, plate id)
#   c3 spotlight hole       — the dim canvas's ACTUAL holes array as drawn
#   c4 true glyph rect NOW  — re-queried fresh from the CURRENT plate at sample
#      time, plus the resolver's original glyph node (weakref): alive? moved?
#   c5 plates_alive, frame numbers, plate identity now vs at resolve
#   c6 screenshots keyed to each sample: trace_mNN_{a,b}.png
# Verdicts per sample: c3==c2.grow(PAD)? c2==c4? original glyph alive/moved?
# CHANGES NOTHING — pure observation. Profile isolation is structural.
# Run windowed: godot --path . -s scripts/debug/primer_render_trace.gd
extends SceneTree

const OUT_DIR := "res://debug_artifacts/primers/"
const PAD := 14.0  # keyword_primer grows the anchor by this before spotlighting


func _initialize() -> void:
	call_deferred("_run")


func _fmt(r: Rect2) -> String:
	return "(%.0f,%.0f %..0fx%.0f)".replace("%..0f", "%.0f") % [r.position.x, r.position.y, r.size.x, r.size.y]


func _sample(tag: String, battle: Node, primer: Node, spot: Node, shot_path: String) -> void:
	var trace: Dictionary = primer.get("debug_last_resolve")
	var icon: String = str(trace.get("icon", "?"))
	var side: String = str(trace.get("side", ""))
	var target_id: String = str(trace.get("target_id", ""))
	var c2: Rect2 = trace.get("rect", Rect2())
	var link: String = str(trace.get("link", "?"))
	var holes: Array = (spot.get("_dim_canvas") as Node).get("holes")
	var c3: Rect2 = holes[0] if not holes.is_empty() else Rect2()
	# c4: the true glyph rect RIGHT NOW, from the CURRENT plate.
	var plate_now: Control = null
	if battle.has_method("get_die_tag_plate"):
		plate_now = battle.call("get_die_tag_plate", side, target_id)
	var c4: Rect2 = Rect2()
	if plate_now != null and icon != "":
		c4 = primer.call("_find_glyph_rect", plate_now, icon)
	# Original glyph node: alive? where is it now?
	var glyph_state: String = "n/a"
	var glyph_ref: Variant = trace.get("glyph_ref")
	if glyph_ref is WeakRef:
		var node: Object = (glyph_ref as WeakRef).get_ref()
		if node == null:
			glyph_state = "FREED"
		else:
			glyph_state = "alive@" + _fmt((node as Control).get_global_rect())
	# Plate identity drift (H3/H4): same instance as at resolve time?
	var plate_id_now: int = plate_now.get_instance_id() if plate_now != null else 0
	var plate_same: bool = plate_id_now == int(trace.get("plate_id", 0))
	var plates_alive: int = 0
	for key in (battle.get("_die_tags") as Dictionary):
		var pv: Variant = ((battle.get("_die_tags") as Dictionary)[key] as Dictionary).get("plate")
		if pv is Control and is_instance_valid(pv):
			plates_alive += 1
	var frame_now: int = Engine.get_process_frames()
	var hole_matches_resolver: bool = c3.is_equal_approx(c2.grow(PAD))
	var resolver_matches_truth: bool = c4.size != Vector2.ZERO and c2.is_equal_approx(c4)
	print("[TRACE] %s icon=%-14s link=%-12s heal=%-5s | c2 resolver=%s | c3 hole=%s (c3==c2+pad: %s) | c4 truthNOW=%s (c2==c4: %s) | glyph %s | plate same=%s plates=%d | frames resolve=%d now=%d (+%d)" % [
		tag, icon, link, str(trace.get("heal_ran", false)),
		_fmt(c2), _fmt(c3), str(hole_matches_resolver),
		_fmt(c4), str(resolver_matches_truth),
		glyph_state, str(plate_same), plates_alive,
		int(trace.get("resolve_frame", 0)), frame_now, frame_now - int(trace.get("resolve_frame", 0))])
	var img: Image = root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(shot_path))


func _run() -> void:
	var gs: Node = root.get_node("/root/GameState")
	var sm: Node = root.get_node("/root/SaveManager")
	sm.call("dev_reset_primers")
	gs.call("start_run", ["combat", "shield", "avalanche"], "facility")
	change_scene_to_file("res://scenes/battle/BattleScene.tscn")
	var retries := 240
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/battle/BattleScene.tscn":
			break
	await create_timer(1.2).timeout
	var battle: Node = current_scene
	var primer: Node = battle.get("_primer")
	primer.set("debug_force_active", true)
	primer.set("debug_anchor_trace", true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var dim: Control = (primer.get("_spot") as Node).get("_dim_canvas")
	print("[TRACE] dim canvas global rect: %s (H2 sanity — expect full viewport)" % _fmt(dim.get_global_rect()))
	var roll_button: Button = battle.get_node_or_null("%RollButton") as Button
	roll_button.emit_signal("pressed")
	var spot: Node = primer.get("_spot")
	var modal_n: int = 0
	var idle: int = 0
	while idle < 240:
		await process_frame
		if spot != null and (spot as CanvasLayer).visible:
			modal_n += 1
			await RenderingServer.frame_post_draw  # the hole IS on screen now
			_sample("m%02d.a(first-frame)" % modal_n, battle, primer, spot,
				OUT_DIR + "trace_m%02d_a.png" % modal_n)
			await create_timer(0.65).timeout
			await RenderingServer.frame_post_draw
			_sample("m%02d.b(+0.65s)     " % modal_n, battle, primer, spot,
				OUT_DIR + "trace_m%02d_b.png" % modal_n)
			spot.emit_signal("tapped")
			idle = 0
			await process_frame
			await process_frame
			await process_frame
		else:
			idle += 1
	print("[TRACE] drained; shown: %s" % str(primer.get("debug_shown_ids")))
	quit(0)
