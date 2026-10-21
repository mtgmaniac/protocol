# The screens the text-fit gate and the overflow captures open (crisp text
# step 3b, 2026-10-20), one place so both see the same state. Call
# `await TextScreens.open(tree, name)` after a profile reset; it returns the
# scene once its text is laid out. Screens:
#   squad, squad_info (unit info open), briefing (OPERATION 01 pop-up),
#   inspect (a unit's long-press pop-up), help_units, help_settings,
#   help_settings_end (PREFS scrolled to its end: the version stamp and the
#   font credit), help_units_evo (UNITS with an evolution row's long-press
#   pop-up: Pulse's Pyro), squad_locked (squad select on a locked mission),
#   squad_cleared (Facility cleared: CLEARED on the card, unit info open),
#   briefing_mantle (OPERATION 05's pop-up), briefing_<operation id> (any
#   operation's pop-up, e.g. briefing_voidCirclet),
#   battle_trait (Splice evolved to Synth with OVERFLOWING, the longest trait
#   title),
#   evolution, evolution_all (VIEW ALL open on both cards), unlock (NEW RELICS /
#   NEW ITEMS: unlock bucket 16, Deathburst Relay's), reward, run_end (defeat),
#   run_end_victory, battle (rolled when `roll` is true; needs a renderer).
# Autoloads and UI classes resolve at RUNTIME (TRUTH's -s convention).
extends RefCounted

const SCREENS := ["squad", "squad_info", "squad_locked", "squad_cleared", "briefing", "briefing_mantle", "inspect", "help_units",
	"help_units_evo", "help_settings", "evolution", "evolution_all", "unlock", "reward", "run_end",
	"run_end_victory", "battle", "battle_trait"]
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
	if screen == "squad_cleared":
		var stats: Dictionary = sm.call("get_stats")
		var won: Dictionary = stats.get("runs_won_by_op", {})
		won["facility"] = 1
		stats["runs_won_by_op"] = won
	match screen:
		"battle", "battle_trait":
			gs.call("start_run", SQUAD, "facility", 424242)
			if screen == "battle_trait":
				for path in (dm.call("get_unit", "medic") as Resource).get("evolution_paths"):
					if str(path.get("id", "")) == "synth":
						(gs.get("unit_evolutions") as Dictionary)["medic"] = str(path.get("name", ""))
				(gs.get("unit_directives") as Dictionary)["medic"] = "overflow"
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
		"squad", "squad_info", "squad_cleared":
			scene.call("_on_tile_tapped", "combat")
			if screen != "squad":
				scene.call("_toggle_info")
		"squad_locked":
			# A fresh profile has only the first mission open: the next is locked.
			scene.call("_on_nav_pressed", 1)
		_ when screen.begins_with("briefing"):
			var op_id: String = "facility" if screen == "briefing" else ("stellarMenagerie" if screen == "briefing_mantle" else screen.trim_prefix("briefing_"))
			var overlay: Control = load("res://scripts/ui/operation_briefing_overlay.gd").new()
			scene.add_child(overlay)
			overlay.call("present_deployment", op_id)
		"inspect":
			var unit: Resource = dm.call("get_unit", "combat")
			load("res://scripts/ui/inspect_popup.gd").open(scene, scene.call("unit_inspect_payload", unit))
		"help_units_evo":
			var help_script: GDScript = load("res://scripts/ui/help_menu.gd")
			help_script.open(scene)
			await tree.process_frame
			var help: Node = root.find_children("*", "HelpMenu", true, false)[0]
			help.call("_select_tab", "units")
			await tree.process_frame
			var group: Dictionary = {}
			for g in help.call("_codex_evolution_groups", dm.call("get_unit", "pulse")):
				if str((g as Dictionary).get("id", "")) == "pyro":
					group = g
			help.call("_on_reference_row_long_pressed", Vector2.ZERO, "evolution", group, help.get("_content_scroll"))
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
		"battle", "battle_trait":
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
