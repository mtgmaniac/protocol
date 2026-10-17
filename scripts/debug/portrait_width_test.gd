# Windowed capture + resize regression for the shared 1080 design-pixel cap.
extends SceneTree

var failures: Array[String] = []
const OUT := "res://debug_artifacts/v04_polish"
const SCREENS := {
	"squad": "UnitSelect", "title": "MainMenu", "help": "UnitSelect",
	"reward": "RewardScreen", "victory": "RunEndScreen", "defeat": "RunEndScreen",
	"battle": "../battle/BattleScene",
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var sm := root.get_node("SaveManager")
	var gs := root.get_node("GameState")
	sm.dev_reset_profile()
	sm.clear_run_save()
	sm.set_setting("no_animations", true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# Exercise phone, preview and expanded desktop viewports.
	for dimensions in [Vector2i(360, 800), Vector2i(390, 867), Vector2i(540, 1200), Vector2i(1280, 900)]:
		print("[PORTRAIT_WIDTH] size ", dimensions)
		DisplayServer.window_set_size(dimensions)
		root.size = dimensions
		await process_frame
		for screen: String in SCREENS:
			gs.reset_run()
			if screen in ["battle", "reward", "victory", "defeat"]:
				gs.start_run(["combat", "avalanche", "medic"], "facility", 424242)
				gs.advance_to_next_battle()
			if screen in ["victory", "defeat"]:
				gs.last_run_result = screen
				gs.current_battle = 10 if screen == "victory" else 6
				gs.run_total_turns = 34
				gs.unit_xp = {"combat": 240, "avalanche": 210, "medic": 185}
				gs.run_hero_deaths = ["medic"] if screen == "victory" else ["combat", "avalanche", "medic"]
			change_scene_to_file("res://scenes/ui/%s.tscn" % SCREENS[screen])
			await create_timer(0.7).timeout
			if screen == "help":
				load("res://scripts/ui/help_menu.gd").open(current_scene)
			await create_timer(0.7).timeout
			var caps := root.find_children("PortraitWidthCap", "", true, false)
			for cap: Node in caps:
				var content: Control = cap.get_parent()
				var rect := content.get_global_rect()
				if rect.size.x > PixelUI.PORTRAIT_WIDTH + 0.1:
					failures.append("%s %s exceeds cap: %s" % [dimensions, screen, content.get_path()])
				if absf(rect.get_center().x - root.get_visible_rect().size.x * 0.5) > 1.0:
					failures.append("%s %s not centered: %s" % [dimensions, screen, content.get_path()])
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/%s_%dx%d.png" % [OUT, screen, dimensions.x, dimensions.y])
			print("[PORTRAIT_WIDTH] captured ", screen)
			if screen == "help":
				load("res://scripts/ui/help_menu.gd").dismiss()
	for failure in failures:
		push_error(failure)
	print("[PORTRAIT_WIDTH] %s: 28 captures at four window sizes" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

