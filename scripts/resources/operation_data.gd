# Resource for one operation track, including encounter order and victory text.
class_name OperationData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var callsign: String = ""
@export_multiline var blurb: String = ""
@export_multiline var victory_title: String = ""
@export_multiline var victory_subtitle: String = ""
@export var track_hp_scale: float = 1.0
@export var battles: Array[Dictionary] = []

func battle_name() -> String:
	return callsign if callsign != "" else display_name
