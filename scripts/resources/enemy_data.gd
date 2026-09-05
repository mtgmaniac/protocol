# Resource for enemy unit definitions and their dice-driven ability tables.
class_name EnemyData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var callsign: String = ""
@export var faction: String = ""
@export var enemy_type: String = ""
@export var ai_type: String = ""
## Targeting personality override (systematic / wounded / pack / spiteful).
## Independent of ai_type — empty means "use the kit default table".
@export var targeting: String = ""
## One-line bestiary description of what this unit DOES in play (data field
## `role` on enemyUnitDefs). Behaviour, never ability names, never a band name.
@export_multiline var role: String = ""
@export var max_hp: int = 0
@export var damage_preview_min: int = 0
@export var damage_preview_max: int = 0
@export var can_summon_elite: bool = false
## Accretion: gain N shield at the start of each of this unit's turns.
@export var accrete: int = 0
## Spawns cloaked (Forked Double); inherits the pkg2 cloak rules.
@export var starts_cloaked: bool = false
@export var portrait: Texture2D
@export var dice_ranges: Array[Dictionary] = []
@export var traits: Array[Dictionary] = []

func battle_name() -> String:
	return callsign if callsign != "" else display_name
