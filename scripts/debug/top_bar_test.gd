# Top bar gate (Kev, 2026-10-19, crisp text step 3). The shared top bar
# (PersistentHeader) spans the full window on every screen that shows it, at
# the itch embed (640x960), a 1080x2400 phone and a 1920x1080 desktop window,
# and is the same bar everywhere: squad select is the reference for its height,
# background, bottom rule, and where the ? and < buttons sit.
# Windowed (a 1080x2400 canvas renders at full size inside a half-size window,
# capture_window.gd); the profile never touches disk.
#   <godot_console> --path . -s scripts/debug/top_bar_test.gd [--top-bar-out=<abs dir>]
# --top-bar-out saves one PNG per screen and window there.
# Autoloads and UI classes resolve at RUNTIME (TRUTH's -s convention).
extends SceneTree

const WINDOWS := [Vector2i(640, 960), Vector2i(1080, 2400), Vector2i(1920, 1080)]
## Every screen with the top bar (the Help menu and pop-ups overlay a screen).
## Squad select first: it is the reference.
const SCREENS := {
	"squad": "res://scenes/ui/UnitSelect.tscn",
	"title": "res://scenes/ui/MainMenu.tscn",
	"battle": "res://scenes/battle/BattleScene.tscn",
	"reward": "res://scenes/ui/RewardScreen.tscn",
	"evolution": "res://scenes/ui/EvolutionScreen.tscn",
	"fork": "res://scenes/ui/RouteForkScreen.tscn",
	"intercept": "res://scenes/ui/InterceptScreen.tscn",
	"runend": "res://scenes/ui/RunEndScreen.tscn",
	"unlock": "res://scenes/ui/UnlockScreen.tscn",
}
const IN_RUN := ["battle", "reward", "evolution", "fork", "intercept", "runend"]

var failures: Array[String] = []
var checks := 0
var _out := ""


func _initialize() -> void:
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a.begins_with("--top-bar-out="):
			_out = a.trim_prefix("--top-bar-out=")
	call_deferred("_run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("[TOP_BAR] " + label)


func near(a: float, b: float, tol: float = 1.0) -> bool:
	return absf(a - b) <= tol


func _set_window(want: Vector2i) -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1080, 2400)
	load("res://scripts/debug/capture_window.gd").apply(root, want)
	for i in 6:
		await process_frame


func _open(key: String) -> void:
	var gs: Node = root.get_node("GameState")
	var sm: Node = root.get_node("SaveManager")
	gs.call("reset_run")
	if key in IN_RUN:
		gs.call("start_run", ["combat", "avalanche", "medic"], "facility", 424242)
		gs.call("advance_to_next_battle")
	if key == "evolution":
		gs.set("pending_evolution_unit_id", "combat")
	if key == "runend":
		gs.set("last_run_result", "victory")
		gs.set("current_battle", 10)
	if key == "unlock":
		# A fresh profile each pass: the first unlock is awarded once, and with
		# nothing new the unlock screen routes away (to squad select).
		_fresh_profile(sm)
		(sm.get("data")["stats"] as Dictionary)["battles_fought"] = 3
		sm.call("record_run_finished", "defeat", "facility", 3)
		sm.call("check_new_unlocks")
	change_scene_to_file(str(SCREENS[key]))
	await create_timer(4.0 if key == "title" else 1.2).timeout
	for i in 4:
		await process_frame


func _fresh_profile(sm: Node) -> void:
	sm.call("dev_reset_profile")
	sm.get("data")["tutorial_done"] = true
	sm.get("data")["onboarding"]["primers_seen"] = sm.call("_all_primer_ids")
	sm.call("set_setting", "no_animations", true)


# What every screen must share with the reference, in design px from the
# window's right edge for the buttons.
func _measure(header: Node, vis: Rect2) -> Dictionary:
	var band: Control = header.get_node("HeaderBand")
	var bg: Control = header.get("_background")
	var divider: Control = header.get("_divider")
	var out := {
		"band": band.get_global_rect(),
		"background": bg.get_global_rect(),
		"divider": divider.get_global_rect(),
		"band_h": band.get_global_rect().size.y,
		"bg_color": (bg as ColorRect).color,
		"divider_color": (divider as ColorRect).color,
		"visible": band.is_visible_in_tree(),
	}
	for key in ["_help_button", "_back_button"]:
		var b: Button = header.get(key)
		var r: Rect2 = b.get_global_rect()
		out[key] = Rect2(vis.end.x - r.position.x, r.position.y, r.size.x, r.size.y)
		out[key + "_style"] = b.get_theme_stylebox("normal").get_class()
		out[key + "_visible"] = b.is_visible_in_tree()
	return out


func _run() -> void:
	await process_frame
	var sm: Node = root.get_node("SaveManager")
	sm.set("_disk_enabled", false)
	_fresh_profile(sm)
	root.get_node("AudioManager").call("set_suppressed", true)
	var header: Node = root.get_node("PersistentHeader")
	check(header.get_node("HeaderBand").find_children("PortraitWidthCap", "", true, false).is_empty(), "the top bar carries no PortraitWidthCap")
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	for window: Vector2i in WINDOWS:
		await _set_window(window)
		var ref: Dictionary = {}
		for key: String in SCREENS:
			await _open(key)
			var vis: Rect2 = root.get_visible_rect()
			var tag := "%dx%d %s" % [window.x, window.y, key]
			var m: Dictionary = _measure(header, vis)
			# The screen under test is the one measured (a screen that routes
			# away would measure another screen's bar).
			check(current_scene != null and current_scene.scene_file_path == str(SCREENS[key]),
				"%s: the screen is up (%s)" % [tag, current_scene.scene_file_path if current_scene else "none"])
			print("[TOP_BAR] %s: visible %s band %s" % [tag, vis.size, m["band"]])
			check(m["visible"], "%s: the top bar shows" % tag)
			for part in ["band", "background", "divider"]:
				var r: Rect2 = m[part]
				check(near(r.position.x, vis.position.x) and near(r.end.x, vis.end.x),
					"%s: the top bar's %s spans the window (%.1f..%.1f of %.1f..%.1f)" % [tag, part, r.position.x, r.end.x, vis.position.x, vis.end.x])
			check(near(m["band_h"], header.call("band_height")), "%s: the top bar is band_height() tall (%.1f)" % [tag, m["band_h"]])
			if key == "squad":
				ref = m
			else:
				check(near(m["band_h"], ref["band_h"]), "%s: the top bar's height matches squad select (%.1f / %.1f)" % [tag, m["band_h"], ref["band_h"]])
				check(m["bg_color"] == ref["bg_color"] and m["divider_color"] == ref["divider_color"], "%s: the background and bottom rule match squad select" % tag)
				for b in ["_help_button", "_back_button"]:
					var r: Rect2 = m[b]
					var want: Rect2 = ref[b]
					check(near(r.position.x, want.position.x) and near(r.position.y, want.position.y) and near(r.size.x, want.size.x),
						"%s: %s sits where squad select has it (%s / %s)" % [tag, b, r, want])
					check(m[b + "_style"] == ref[b + "_style"] and m[b + "_visible"] == ref[b + "_visible"], "%s: %s is styled as on squad select" % [tag, b])
			if _out != "":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("%s/%s_%dx%d.png" % [_out, key, window.x, window.y])
	print("[TOP_BAR] %s: %d checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
