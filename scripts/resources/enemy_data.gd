# Resource for enemy unit definitions and their dice-driven ability tables.
class_name EnemyData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var callsign: String = ""
@export var faction: String = ""
@export var enemy_type: String = ""
@export var ai_type: String = ""
@export var max_hp: int = 0
@export var damage_preview_min: int = 0
@export var damage_preview_max: int = 0
@export var phase_two_damage_preview_min: int = 0
@export var phase_two_damage_preview_max: int = 0
@export var phase_two_threshold: int = 0
@export var can_summon_elite: bool = false
@export var portrait: Texture2D
@export var dice_ranges: Array[Dictionary] = []
@export var traits: Array[Dictionary] = []

func battle_name() -> String:
	return callsign if callsign != "" else display_name
