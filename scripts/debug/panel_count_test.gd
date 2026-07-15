# Polish Build B gate: the squad/operation selection screen adds ZERO new
# framed panels. Counts every visible framed component (Panel/PanelContainer
# whose active `panel` stylebox draws a border) on the home screen and pins the
# number. Adding a frame FAILS this test; the remedy for an empty-feeling
# screen is spacing, never a new frame (Kev ruling, Build B).
#
#   godot --headless --path . -s scripts/debug/panel_count_test.gd
extends SceneTree

const HOME_SCENE := "res://scenes/ui/UnitSelect.tscn"
# Pinned at the Build B baseline (measured headless = fully-unlocked profile:
# encounter banner + boss thumb, 8 hero tiles, deploy plate). Raising this
# number is adding a framed panel to the selection screen — that needs a
# ruling, not a bump (INVARIANTS #13: enforcement only ratchets down for free).
const MAX_FRAMED_PANELS := 11


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file(HOME_SCENE)
	var retries := 120
	while retries > 0:
		retries -= 1
		await process_frame
		if current_scene != null and current_scene.scene_file_path == HOME_SCENE:
			break
	for i in 6:
		await process_frame

	var framed: Array = []
	var stack: Array = [current_scene]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.push_back(child)
		if not (node is Control) or not (node as Control).is_visible_in_tree():
			continue
		var style: StyleBox = null
		if node is PanelContainer or (node is Panel):
			style = (node as Control).get_theme_stylebox("panel")
		if style is StyleBoxFlat:
			var flat: StyleBoxFlat = style
			var has_border: bool = (flat.border_width_left + flat.border_width_top
				+ flat.border_width_right + flat.border_width_bottom) > 0 and flat.border_color.a > 0.01
			if has_border:
				framed.append(node)

	print("  framed panels on the selection screen: %d (pin %d)" % [framed.size(), MAX_FRAMED_PANELS])
	for node in framed:
		print("    - %s" % (node as Node).get_path())
	if framed.size() > MAX_FRAMED_PANELS:
		print("[PANEL_COUNT] FAIL - selection screen grew a framed panel (%d > %d)" % [framed.size(), MAX_FRAMED_PANELS])
		quit(1)
		return
	print("[PANEL_COUNT] PASS")
	quit(0)
