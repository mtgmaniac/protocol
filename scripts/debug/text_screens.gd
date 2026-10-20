# The screens the text-fit gate and the overflow captures open (crisp text
# step 3b, 2026-10-20), one place so both see the same state. Call
# `await TextScreens.open(tree, name)` after a profile reset; it returns the
# scene once its text is laid out. Screens:
#   squad, squad_info (unit info open), briefing (OPERATION 01 pop-up),
#   inspect (a unit's long-press pop-up), help_units, help_settings,
#   help_settings_end (PREFS scrolled to its end: the version stamp and the
#   font credit),
#   evolution, evolution_all (VIEW ALL open on both cards), unlock (NEW RELICS /
#   NEW ITEMS: unlock bucket 16, Deathburst Relay's), reward, run_end (defeat),
#   run_end_victory, battle (rolled when `roll` is true; needs a renderer).
# Autoloads and UI classes resolve at RUNTIME (TRUTH's -s convention).
extends RefCounted

const SCREENS := ["squad", "squad_info", "briefing", "inspect", "help_units", "help_settings",
	"evolution", "evolution_all", "unlock", "reward", "run_end", "run_end_victory", "battle"]
const SQUAD := ["combat", "avalanche", "medic"]
## Unlock bucket 16 (unlocks.data.json): Reverse Gimbal, Deathburst Relay,
## Wide Aperture, Opening Gambit; awarded at the 16th gate.
const UNLOCK_GATE := 15


static func open(tree: SceneTree, screen: String, roll: bool = false) -> Node:
	var root: Window = tree.root
	var sm: Node = root.get_node("/root/SaveManager")
	var gs: Node = root.get_node("/root/GameState")
	var dm: Node = root.get_node("/root/DataManager")
	gs.call("reset_run")
	var scene_path := "res://scenes/ui/UnitSelect.tscn"
	match screen:
		"battle":
			gs.call("start_run", SQUAD, "facility", 424242)
			gs.call("advance_to_next_battle")
			scene_path = "res://scenes/battle/BattleScene.tscn"
		"reward":
			gs.call("start_run", SQUAD, "facility", 424242)
			gs.call("advance_to_next_battle")
			gs.call("prepare_battle_rewards")
			scene_path = "res://scenes/ui/RewardScreen.tscn"
		"evolution", "evolution_all":
			gs.call("start_run", SQUAD, "facility", 424242)
			gs.set("pending_evolution_unit_id", "combat")
			scene_path = "res://scenes/ui/EvolutionScreen.tscn"
		"unlock":
			sm.get("data")["unlocks"]["item_gates_awarded"] = UNLOCK_GATE
			var schedule: Array = dm.call("unlock_schedule")
			(sm.get("data")["stats"] as Dictionary)["battles_fought"] = int(schedule[UNLOCK_GATE])
			sm.call("record_run_finished", "defeat", "facility", 3)
			scene_path = "res://scenes/ui/UnlockScreen.tscn"
		"run_end", "run_end_victory":
			# The squad Kev's defeat report showed, lost at battle 5 of 10.
			var victory: bool = screen == "run_end_victory"
			gs.call("start_run", ["engineer", "combat", "medic"], "facility", 424242)
			gs.set("current_battle", 10 if victory else 5)
			gs.set("run_total_turns", 23)
			gs.set("last_run_result", "victory" if victory else "defeat")
			gs.set("run_hero_deaths", ["medic"] if victory else ["engineer", "combat", "medic"])
			scene_path = "res://scenes/ui/RunEndScreen.tscn"
	tree.change_scene_to_file(scene_path)
	await tree.create_timer(1.5).timeout
	var scene: Node = tree.current_scene
	match screen:
		"squad", "squad_info":
			scene.call("_on_tile_tapped", "combat")
			if screen == "squad_info":
				scene.call("_toggle_info")
		"briefing":
			var overlay: Control = load("res://scripts/ui/operation_briefing_overlay.gd").new()
			scene.add_child(overlay)
			overlay.call("present_deployment", "facility")
		"inspect":
			var unit: Resource = dm.call("get_unit", "combat")
			load("res://scripts/ui/inspect_popup.gd").open(scene, scene.call("unit_inspect_payload", unit))
		"help_settings", "help_units", "help_settings_end":
			load("res://scripts/ui/help_menu.gd").open(scene)
			await tree.process_frame
			var menus: Array = root.find_children("*", "HelpMenu", true, false)
			if not menus.is_empty():
				(menus[0] as Node).call("_select_tab", screen.trim_prefix("help_").trim_suffix("_end"))
				if screen.ends_with("_end"):
					for i in 4:
						await tree.process_frame
					var scroll: ScrollContainer = (menus[0] as Node).get("_content_scroll")
					scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		"evolution_all":
			for button in scene.find_children("ExpandAbilities", "Button", true, false):
				(button as Button).emit_signal("pressed")
		"battle":
			if roll:
				var roll_button: Button = scene.get_node_or_null("%RollButton") as Button
				var dice_tray: Node = scene.get_node_or_null("%DiceTray3D")
				if roll_button != null and not roll_button.disabled:
					roll_button.emit_signal("pressed")
					if dice_tray != null and dice_tray.has_signal("roll_finished"):
						await dice_tray.roll_finished
	await tree.create_timer(0.5).timeout
	for i in 6:
		await tree.process_frame
	return scene
