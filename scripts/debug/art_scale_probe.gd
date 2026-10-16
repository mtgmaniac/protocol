# ui-cleanup (art scaling check): loads every in-run screen with a live run and
# reports each visible texture: source size, drawn size in design px, the scale
# factor (design px per source px), the effective filter and any sub-pixel
# position. Read-only: it changes no art and no layout.
#   <godot> --path . -s res://scripts/debug/art_scale_probe.gd [--probe-screens=fork,battle,...]
# Run windowed (the battle needs a rendered viewport to settle).
extends SceneTree

const SCREENS := {
	"fork": "res://scenes/ui/RouteForkScreen.tscn",
	"intercept": "res://scenes/ui/InterceptScreen.tscn",
	"reward": "res://scenes/ui/RewardScreen.tscn",
	"evolution": "res://scenes/ui/EvolutionScreen.tscn",
	"run_end": "res://scenes/ui/RunEndScreen.tscn",
	"unlock": "res://scenes/ui/UnlockScreen.tscn",
	"directive": "res://scenes/ui/UnitSelect.tscn",
	"battle": "res://scenes/battle/BattleScene.tscn",
}
const STRETCH_NAMES := ["SCALE", "TILE", "KEEP", "KEEP_CENTERED", "KEEP_ASPECT", "KEEP_ASPECT_CENTERED", "KEEP_ASPECT_COVERED"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var order: Array = ["fork", "intercept", "reward", "evolution", "run_end", "unlock", "directive", "battle"]
	for arg: String in OS.get_cmdline_args():
		if arg.begins_with("--probe-screens="):
			order = Array(arg.get_slice("=", 1).split(",", false))
	for screen: String in order:
		_prepare(screen)
		change_scene_to_file(SCREENS[screen])
		await create_timer(2.5 if screen == "battle" else 1.0).timeout
		if screen == "directive" and current_scene != null:
			var relics: Array = root.get_node("/root/SaveManager").call("get_unlocked_boss_relics")
			if relics.is_empty():
				relics = ["scrap_converter"]
			current_scene.call("_open_directive_picker", relics)
			await create_timer(0.5).timeout
		_report(screen)
	quit(0)


func _prepare(screen: String) -> void:
	var gs: Node = root.get_node("/root/GameState")
	var save: Node = root.get_node("/root/SaveManager")
	gs.call("reset_run")
	if screen == "directive":
		return
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


func _report(screen: String) -> void:
	if current_scene == null:
		print("[ART_SCALE] %s: no scene" % screen)
		return
	var seen := {}
	for node: Node in current_scene.find_children("*", "TextureRect", true, false):
		var rect := node as TextureRect
		if rect == null or rect.texture == null or not rect.is_visible_in_tree():
			continue
		var tex: Texture2D = rect.texture
		var src := Vector2(tex.get_width(), tex.get_height())
		var box: Rect2 = rect.get_global_rect()
		var xf: Transform2D = rect.get_global_transform()
		var s := Vector2(xf.x.length(), xf.y.length())
		box.size = rect.size * s
		var drawn: Vector2 = _drawn_size(rect, src, box.size)
		var scale := Vector2(drawn.x / src.x, drawn.y / src.y)
		var origin: Vector2 = box.position + (box.size - drawn) * 0.5
		var key: String = "%s|%s|%s" % [tex.resource_path, src, drawn]
		if seen.has(key):
			seen[key] += 1
			continue
		seen[key] = 1
		var integer: bool = absf(scale.x - roundf(scale.x)) < 0.01 and absf(scale.y - roundf(scale.y)) < 0.01 and roundf(scale.x) >= 1.0
		var subpx: bool = absf(origin.x - roundf(origin.x)) > 0.01 or absf(origin.y - roundf(origin.y)) > 0.01
		print("[ART_SCALE] %s | %s | %s | src %dx%d | drawn %.1fx%.1f | x%.3f/x%.3f %s | %s | %s | %s%s" % [
			screen, _short(rect), _tex_name(tex), src.x, src.y, drawn.x, drawn.y, scale.x, scale.y,
			"INT" if integer else "non-int", STRETCH_NAMES[rect.stretch_mode], _filter_name(rect),
			"pos %.2f,%.2f" % [origin.x, origin.y], " SUBPX" if subpx else ""])


func _drawn_size(rect: TextureRect, src: Vector2, box: Vector2) -> Vector2:
	match rect.stretch_mode:
		TextureRect.STRETCH_KEEP_ASPECT, TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
			return src * minf(box.x / src.x, box.y / src.y)
		TextureRect.STRETCH_KEEP_ASPECT_COVERED:
			return src * maxf(box.x / src.x, box.y / src.y)
		TextureRect.STRETCH_KEEP, TextureRect.STRETCH_KEEP_CENTERED, TextureRect.STRETCH_TILE:
			return src * (box.x / maxf(rect.size.x, 1.0))
	return box


func _filter_name(item: CanvasItem) -> String:
	var node: Node = item
	while node is CanvasItem:
		var f: int = (node as CanvasItem).texture_filter
		if f != CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			return "NEAREST" if f == CanvasItem.TEXTURE_FILTER_NEAREST or f == CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS else "LINEAR(%d)" % f
		node = node.get_parent()
	var default_filter: int = item.get_viewport().canvas_item_default_texture_filter
	return "NEAREST(viewport)" if default_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST else "LINEAR(viewport default)"


func _tex_name(tex: Texture2D) -> String:
	if tex is AtlasTexture and (tex as AtlasTexture).atlas != null:
		return "atlas:" + (tex as AtlasTexture).atlas.resource_path.get_file()
	return tex.resource_path.get_file() if tex.resource_path != "" else tex.get_class()


func _short(node: Node) -> String:
	var parts: PackedStringArray = []
	var n: Node = node
	while n != null and n != current_scene and parts.size() < 3:
		parts.insert(0, String(n.name))
		n = n.get_parent()
	return "/".join(parts)
