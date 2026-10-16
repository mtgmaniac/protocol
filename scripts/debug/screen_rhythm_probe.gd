# ui-fix (layout rhythm): loads each in-run screen that shares the header and
# prints, in design px, the gap from the header bar to the first visible
# content and the vertical gaps between the blocks of the screen's main column.
# Read-only. Run windowed:
#   <godot> --path . -s res://scripts/debug/screen_rhythm_probe.gd --capture-window=390x867
extends SceneTree

const SCREENS := {
	"fork": "res://scenes/ui/RouteForkScreen.tscn",
	"intercept": "res://scenes/ui/InterceptScreen.tscn",
	"reward": "res://scenes/ui/RewardScreen.tscn",
	"evolution": "res://scenes/ui/EvolutionScreen.tscn",
	"run_end": "res://scenes/ui/RunEndScreen.tscn",
	"unlock": "res://scenes/ui/UnlockScreen.tscn",
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	for screen: String in ["fork", "intercept", "reward", "evolution", "run_end", "unlock"]:
		_prepare(screen)
		change_scene_to_file(SCREENS[screen])
		await create_timer(1.2).timeout
		_report(screen)
	quit(0)


func _prepare(screen: String) -> void:
	var gs: Node = root.get_node("/root/GameState")
	var save: Node = root.get_node("/root/SaveManager")
	gs.call("reset_run")
	if screen == "unlock":
		save.call("dev_reset_profile")
		((save.get("data") as Dictionary)["stats"] as Dictionary)["battles_fought"] = 3
		save.call("record_run_finished", "defeat", "facility", 3)
	gs.call("start_run", ["combat", "avalanche", "medic"], "facility", 7)
	gs.call("advance_to_next_battle")
	match screen:
		"intercept":
			gs.call("begin_intercept_state", "firingSolution")
		"evolution":
			gs.set("pending_evolution_unit_id", "avalanche")
		"run_end":
			gs.set("last_run_result", "victory")


# A control that paints something: text, a texture, a button or a styled panel.
func _paints(c: Control) -> bool:
	if c is Label:
		return (c as Label).text.strip_edges() != ""
	if c is TextureRect:
		return (c as TextureRect).texture != null
	if c is Button:
		return true
	if c is PanelContainer or c is Panel:
		var sb: StyleBox = c.get_theme_stylebox("panel")
		return sb != null and not (sb is StyleBoxEmpty)
	return false


func _report(screen: String) -> void:
	if current_scene == null:
		print("[SCREEN_RHYTHM] %s: no scene" % screen)
		return
	var header_bottom: float = root.get_node("PersistentHeader").call("band_height")
	var screen_rect: Rect2 = root.get_visible_rect()
	var top := INF
	var top_name := ""
	for node: Node in current_scene.find_children("*", "Control", true, false):
		var c := node as Control
		if not c.is_visible_in_tree() or not _paints(c):
			continue
		var r: Rect2 = c.get_global_rect()
		# Full-screen backdrops and the scrim are not content.
		if r.size.x >= screen_rect.size.x - 1.0 and r.size.y >= screen_rect.size.y * 0.5:
			continue
		if r.position.y < top and r.position.y >= header_bottom - 1.0:
			top = r.position.y
			top_name = String(c.name)
	print("[SCREEN_RHYTHM] %s: header->content %.1f (%s)" % [screen, top - header_bottom, top_name])
	# The main column: the deepest VBox with 2+ visible children that spans most of the width.
	for node: Node in current_scene.find_children("*", "VBoxContainer", true, false):
		var v := node as VBoxContainer
		if not v.is_visible_in_tree() or v.get_global_rect().size.x < screen_rect.size.x * 0.6:
			continue
		var kids: Array = []
		for k: Node in v.get_children():
			if k is Control and (k as Control).is_visible_in_tree() and (k as Control).size.y > 1.0:
				kids.append(k)
		if kids.size() < 2:
			continue
		var gaps: PackedStringArray = []
		for i in range(1, kids.size()):
			gaps.append("%.0f" % ((kids[i] as Control).get_global_rect().position.y - (kids[i - 1] as Control).get_global_rect().end.y))
		print("[SCREEN_RHYTHM] %s:   column %s sep=%d gaps=[%s]" % [screen, v.name, v.get_theme_constant("separation"), ", ".join(gaps)])
