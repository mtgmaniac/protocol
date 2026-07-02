# Resource for gear, consumables, and relics used in the run reward loop.
class_name ItemData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var item_type: String = ""
@export var rarity: String = ""
@export var icon_key: String = ""
@export var target_kind: String = "none"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var effect: Dictionary = {}
## Boss relics never appear in the battle-5 relic draft; they unlock via first
## operation clears (pkg5) and can be taken as a Starting Directive.
@export var boss_relic: bool = false
