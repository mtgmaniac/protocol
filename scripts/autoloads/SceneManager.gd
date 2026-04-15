# Centralizes scene changes so gameplay code does not need to know tree details.
extends Node

const UNIT_SELECT_SCENE := "res://scenes/ui/UnitSelect.tscn"
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const REWARD_SCENE := "res://scenes/ui/RewardScreen.tscn"
const RUN_END_SCENE := "res://scenes/ui/RunEndScreen.tscn"
const EVOLUTION_SCENE := "res://scenes/ui/EvolutionScreen.tscn"


func go_to(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


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
