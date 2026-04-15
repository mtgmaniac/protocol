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
