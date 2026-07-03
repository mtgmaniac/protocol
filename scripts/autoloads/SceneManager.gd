# Centralizes scene changes so gameplay code does not need to know tree details.
extends Node

const MAIN_MENU_SCENE := "res://scenes/ui/MainMenu.tscn"
const UNIT_SELECT_SCENE := "res://scenes/ui/UnitSelect.tscn"
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const REWARD_SCENE := "res://scenes/ui/RewardScreen.tscn"
const RUN_END_SCENE := "res://scenes/ui/RunEndScreen.tscn"
const EVOLUTION_SCENE := "res://scenes/ui/EvolutionScreen.tscn"
const ROUTE_FORK_SCENE := "res://scenes/ui/RouteForkScreen.tscn"
const INTERCEPT_SCENE := "res://scenes/ui/InterceptScreen.tscn"


func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


# Post-victory routing (pkg7.2): when a beat sits after the battle just won,
# detour through its screen before the next battle; otherwise advance directly.
func go_to_next_battle_or_beat() -> void:
	var beat: Dictionary = GameState.get_beat_after_battle(GameState.current_battle)
	if not beat.is_empty() and not GameState.consumed_beats.has(GameState.current_battle):
		GameState.consumed_beats.append(GameState.current_battle)
		match str(beat.get("type", "")):
			"fork":
				go_to(ROUTE_FORK_SCENE)
				return
			"intercept":
				go_to(INTERCEPT_SCENE)
				return
	GameState.advance_to_next_battle()
	go_to_battle()


func go_to_main_menu() -> void:
	go_to(MAIN_MENU_SCENE)


func go_to_unit_select() -> void:
	go_to(UNIT_SELECT_SCENE)


func go_to_battle() -> void:
	go_to(BATTLE_SCENE)


func go_to_reward_screen() -> void:
	go_to(REWARD_SCENE)


func go_to_run_end() -> void:
	go_to(RUN_END_SCENE)


func go_to_evolution() -> void:
	go_to(EVOLUTION_SCENE)
