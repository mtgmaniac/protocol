# Resource for player unit definitions imported from the old Angular data tables.
class_name UnitData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var callsign: String = ""
@export var class_name_text: String = ""
@export var role: String = ""
@export var picker_category: String = ""
@export_multiline var picker_blurb: String = ""
@export var max_hp: int = 0
@export var source_key: String = ""
@export var portrait: Texture2D
@export var dice_ranges: Array[Dictionary] = []
@export var passives: Array[Dictionary] = []
@export var evolution_paths: Array[Dictionary] = []

func battle_name() -> String:
	return callsign if callsign != "" else display_name
