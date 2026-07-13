# Transition smoke test (headless): proves the TransitionManager contract that
# the battle smokes depend on — headless suppression degrades to an INSTANT hard
# cut (no awaits, no overlay), the failure-safety path never strands the game
# between scenes (a dead snapshot falls through to the hard cut), and "none"
# bypasses entirely. The visual ramp itself can't render headless — its budget
# is a screenshot concern (docs/TRANSITIONS_SCOPE.md).
# Run: godot --headless --path . -s scripts/debug/transition_smoke_test.gd
# Exit 0 = pass, 1 = fail.
extends SceneTree

var _errors: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_errors.append(label)


func _current_scene_file() -> String:
	return str(current_scene.scene_file_path) if current_scene != null else ""


func _initialize() -> void:
	await process_frame
	var tm: Node = root.get_node_or_null("/root/TransitionManager")
	if tm == null:
		push_error("[TRANSITION_SMOKE] TransitionManager autoload missing")
		print("[TRANSITION_SMOKE] FAIL — 1 error(s)")
		quit(1)
		return

	# ── 1) Headless default: suppressed → instant hard cut, no overlay, no state.
	tm.change_scene("res://scenes/ui/MainMenu.tscn")
	await process_frame
	await process_frame
	_check(_current_scene_file().ends_with("MainMenu.tscn"), "headless change_scene lands on the target scene")
	_check(not bool(tm._running), "suppressed path never sets _running")
	_check(tm._overlay == null, "suppressed path builds no overlay")

	# ── 2) Failure safety: forced active under headless, the snapshot cannot be
	# taken → falls through to the hard cut. A transition must never be able to
	# strand the game between scenes.
	tm.debug_force_active = true
	tm.change_scene("res://scenes/ui/UnitSelect.tscn")
	await process_frame
	await process_frame
	_check(_current_scene_file().ends_with("UnitSelect.tscn"), "failed snapshot falls through to the hard cut")
	_check(not bool(tm._running), "failure-safety path leaves _running false")
	_check(tm._overlay == null, "failure-safety path leaves no overlay")
	tm.debug_force_active = false

	# ── 3) kind "none": explicit instant cut.
	tm.change_scene("res://scenes/ui/MainMenu.tscn", "none")
	await process_frame
	await process_frame
	_check(_current_scene_file().ends_with("MainMenu.tscn"), "kind 'none' is an instant cut")

	# ── 4) Unknown kind: degrades to hard cut, never raises.
	tm.change_scene("res://scenes/ui/UnitSelect.tscn", "wipe_left")
	await process_frame
	await process_frame
	_check(_current_scene_file().ends_with("UnitSelect.tscn"), "unknown kind degrades to the hard cut")

	# ── 5) Both shaders parse (compile check — a broken .gdshader would
	# otherwise only surface on a real device).
	for kind in ["dither_dissolve", "power_down"]:
		var shader: Shader = load(str(tm.SHADERS[kind])) as Shader
		_check(shader != null, "%s shader loads" % kind)
		_check(shader != null and shader.get_rid().is_valid(), "%s shader compiles to a valid RID" % kind)

	if _errors.is_empty():
		print("[TRANSITION_SMOKE] PASS — headless instant cut, failure safety, shaders compile")
		quit(0)
	else:
		for e in _errors:
			push_error("[TRANSITION_SMOKE] " + e)
		print("[TRANSITION_SMOKE] FAIL — %d error(s)" % _errors.size())
		quit(1)
