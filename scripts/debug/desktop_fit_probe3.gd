# DIAGNOSTIC ONLY — park the drill on the gated Roll beat and log every
# tutorial event with a timestamp, to see whether anything but the player can
# move it.
extends SceneTree

var _t0: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _pause(n: int) -> void:
	for _i in n:
		await process_frame


func _run() -> void:
	await _pause(3)
	root.get_node("GameState").start_tutorial_run(true)
	root.get_node("SceneManager").go_to_battle()
	await _pause(90)
	var scene: Node = current_scene
	var tut: Node = null
	for child in scene.get_children():
		if child is TutorialController:
			tut = child
	_t0 = Time.get_ticks_msec()
	scene.tutorial_event.connect(func(event: StringName, payload: Dictionary) -> void:
		print("[FIT3] t=%.1fs EVENT %s %s" % [(Time.get_ticks_msec() - _t0) / 1000.0, str(event), str(payload).substr(0, 90)]))
	tut.call("_show_step", 2)
	await _pause(6)
	print("[FIT3] parked step=%d advance=%s phase=%s focus=%s" % [
		int(tut.get("_step")), str(tut.call("_advance_mode")),
		str(scene.call("phase_name", scene.get("turn_phase"))),
		str(scene.get("roll_button").has_focus())])
	var last: int = 2
	var t: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 20000:
		await process_frame
		var s: int = int(tut.get("_step"))
		if s != last:
			print("[FIT3] t=%.1fs step %d -> %d (advance=%s)" % [(Time.get_ticks_msec() - _t0) / 1000.0, last, s, str(tut.call("_advance_mode"))])
			last = s
	print("[FIT3] final step=%d after 20s of zero input" % int(tut.get("_step")))
	quit(0)
