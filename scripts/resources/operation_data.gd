# Resource for one operation track, including encounter order and victory text.
class_name OperationData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var callsign: String = ""
@export_multiline var blurb: String = ""
# One unframed flavor sentence under the operation carousel (Build B wires the
# slot; Build C authors the copy). Empty = the slot renders nothing.
@export_multiline var lore: String = ""
@export_multiline var victory_title: String = ""
@export_multiline var victory_subtitle: String = ""
## UNWIRED — parked, not cut (INVARIANTS #6/#8): authored for per-battle HP scaling, but no
## reader wires it (not even the sim). Godot combat uses flat `enemyUnitDefs` stats.
@export var track_hp_scale: float = 1.0
@export var battles: Array[Dictionary] = []

func battle_name() -> String:
	return callsign if callsign != "" else display_name
