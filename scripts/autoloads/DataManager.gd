# Loads structured game data from the migrated Angular JSON tables and exposes it as Resources.
extends Node

const HEROES_DATA_PATH := "res://data/raw/heroes.data.json"
const ENEMIES_DATA_PATH := "res://data/raw/enemies.data.json"
const ITEMS_DATA_PATH := "res://data/raw/items.data.json"
const GEAR_DATA_PATH := "res://data/raw/gear.data.json"
const RELICS_DATA_PATH := "res://data/raw/relics.data.json"
const BATTLE_MODES_DATA_PATH := "res://data/raw/battle-modes.json"
const LEGACY_HERO_PORTRAIT_ROOT := "res://legacy-angular/public/heroes/"
const LEGACY_ENEMY_PORTRAIT_ROOT := "res://legacy-angular/public/enemies/"
const LEGACY_UI_ROOT := "res://legacy-angular/public/ui/"

const ENEMY_ZONE_RANGES := {
	"recharge": Vector2i(1, 4),
	"strike": Vector2i(5, 10),
	"surge": Vector2i(11, 16),
	"crit": Vector2i(17, 19),
	"overload": Vector2i(20, 20),
}

const HERO_ROLE_BY_ID := {
	"pulse": "Protocol/utility",
	"combat": "Damage",
	"shield": "Tank/counter",
	"avalanche": "AoE damage",
	"medic": "Healer",
	"engineer": "Buffer",
	"ghost": "Burst/stealth",
	"breaker": "Debuffer",
}

const HERO_PORTRAIT_BY_ID := {
	"pulse": "pulse-portrait.png",
	"combat": "combat-portrait.png",
	"shield": "shield-portrait.png",
	"avalanche": "avalanche-portrait.png",
	"medic": "medic-portrait.png",
	"engineer": "engineer-portrait.png",
	"ghost": "ghost-portrait.png",
	"breaker": "breaker-portrait.png",
}

const ENEMY_FACTION_BY_TYPE := {
	"scrap": "facility",
	"rust": "facility",
	"patrol": "facility",
	"guard": "facility",
	"warden": "facility",
	"volt": "facility",
	"boss": "facility",
	"signalSkimmer": "facility",
	"commsHex": "facility",
	"skitter": "hive",
	"mite": "hive",
	"stalker": "hive",
	"carapace": "hive",
	"brood": "hive",
	"spewer": "hive",
	"hiveBoss": "hive",
	"veilShard": "veil",
	"veilPrism": "veil",
	"veilAegis": "veil",
	"veilResonance": "veil",
	"veilNull": "veil",
	"veilStorm": "veil",
	"veilSynapse": "veil",
	"veilBoss": "veil",
	"voidWisp": "voidCirclet",
	"voidAcolyte": "voidCirclet",
	"voidScribe": "voidCirclet",
	"voidBinder": "voidCirclet",
	"voidGlimmer": "voidCirclet",
	"voidChanneler": "voidCirclet",
	"voidCircletBoss": "voidCirclet",
	"beastMonkey": "stellarMenagerie",
	"beastWolf": "stellarMenagerie",
	"beastLynx": "stellarMenagerie",
	"beastBison": "stellarMenagerie",
	"beastHyena": "stellarMenagerie",
	"beastBadger": "stellarMenagerie",
	"beastTyrant": "stellarMenagerie",
}

const ENEMY_PORTRAIT_BY_TYPE := {
	"scrap": "scrap-portrait.png",
	"rust": "rust-portrait.png",
	"patrol": "patrol-portrait.png",
	"guard": "guard-portrait.png",
	"warden": "warden-portrait.png",
	"volt": "volt-portrait.png",
	"boss": "boss-portrait.png",
	"skitter": "skitter-portrait.png",
	"mite": "mite-portrait.png",
	"stalker": "stalker-portrait.png",
	"carapace": "carapace-portrait.png",
	"brood": "brood-portrait.png",
	"spewer": "spewer-portrait.png",
	"hiveBoss": "hive-boss-portrait.png",
	"veilShard": "veil-shard-portrait.png",
	"veilPrism": "veil-prism-portrait.png",
	"veilAegis": "veil-aegis-portrait.png",
	"veilResonance": "veil-resonance-portrait.png",
	"veilNull": "veil-null-portrait.png",
	"veilStorm": "veil-storm-portrait.png",
	"veilSynapse": "veil-synapse-portrait.png",
	"veilBoss": "veil-boss-portrait.png",
	"voidWisp": "void-wisp-portrait.png",
	"voidAcolyte": "void-acolyte-portrait.png",
	"voidScribe": "void-scribe-portrait.png",
	"voidBinder": "void-binder-portrait.png",
	"voidGlimmer": "void-glimmer-portrait.png",
	"voidChanneler": "void-channeler-portrait.png",
	"voidCircletBoss": "void-circlet-boss-portrait.png",
	"beastMonkey": "rift-macaque-portrait.png",
	"beastWolf": "void-wolf-portrait.png",
	"beastLynx": "eclipse-lynx-portrait.png",
	"beastBison": "thunder-bison-portrait.png",
	"beastHyena": "eclipse-hyena-portrait.png",
	"beastBadger": "ridge-badger-portrait.png",
	"beastTyrant": "void-reaver-portrait.png",
}

var units: Dictionary = {}
var enemies: Dictionary = {}
var items: Dictionary = {}
var operations: Dictionary = {}
var operation_order: Array = []
var hero_zone_ranges: Dictionary = {}


func _ready() -> void:
	_load_all_data()


func get_unit(unit_id: String) -> Resource:
	return units.get(unit_id)


func get_enemy(enemy_id: String) -> Resource:
	return enemies.get(enemy_id)


func get_enemy_by_display_name(enemy_name: String) -> Resource:
	return enemies.get(_slugify(enemy_name))


func get_item(item_id: String) -> Resource:
	return items.get(item_id)


func get_operation(operation_id: String) -> Resource:
	return operations.get(operation_id)


func get_operation_order() -> Array:
	return operation_order.duplicate()


func get_logo_texture() -> Texture2D:
	return _load_texture_if_exists("%soverload-protocol-logo.png" % LEGACY_UI_ROOT)


func get_hero_zone_ranges(hero_key: String) -> Dictionary:
	return (hero_zone_ranges.get(hero_key, {}) as Dictionary).duplicate(true)


func _load_all_data() -> void:
	units.clear()
	enemies.clear()
	items.clear()
	operations.clear()
	operation_order.clear()
	hero_zone_ranges.clear()

	_load_units()
	_load_enemies()
	_load_items()
	_load_operations()


func _load_units() -> void:
	var heroes_payload: Dictionary = _parse_json_file(HEROES_DATA_PATH)
	var zone_payload: Dictionary = heroes_payload.get("heroZones", {})
	for hero_key in zone_payload.keys():
		var zone_map: Dictionary = {}
		for zone_entry_variant in zone_payload[hero_key]:
			var zone_entry: Array = zone_entry_variant
			if zone_entry.size() < 3:
				continue
			zone_map[str(zone_entry[2])] = Vector2i(int(zone_entry[0]), int(zone_entry[1]))
		hero_zone_ranges[str(hero_key)] = zone_map
	var heroes: Array = heroes_payload.get("heroes", [])
	for hero_entry in heroes:
		var unit: UnitData = UnitData.new()
		unit.id = str(hero_entry.get("id", ""))
		unit.display_name = str(hero_entry.get("name", ""))
		unit.class_name_text = str(hero_entry.get("cls", ""))
		unit.role = str(HERO_ROLE_BY_ID.get(unit.id, ""))
		unit.picker_category = str(hero_entry.get("pickerCategory", ""))
		unit.picker_blurb = str(hero_entry.get("pickerBlurb", ""))
		unit.max_hp = int(hero_entry.get("hp", 0))
		unit.source_key = str(hero_entry.get("sk", unit.id))
		unit.portrait = _load_hero_portrait(unit.id)
		unit.dice_ranges = _build_hero_dice_ranges(hero_entry.get("abilities", []))
		unit.evolution_paths = _build_evolution_paths(hero_entry.get("evolutions", []))
		units[unit.id] = unit


func _load_enemies() -> void:
	var enemies_payload: Dictionary = _parse_json_file(ENEMIES_DATA_PATH)
	var enemy_unit_defs: Dictionary = enemies_payload.get("enemyUnitDefs", {})
	var enemy_abilities: Dictionary = enemies_payload.get("enemyAbilities", {})

	for enemy_name in enemy_unit_defs.keys():
		var enemy_def: Dictionary = enemy_unit_defs[enemy_name]
		var enemy: EnemyData = EnemyData.new()
		var enemy_type: String = str(enemy_def.get("type", ""))
		enemy.id = _slugify(enemy_name)
		enemy.display_name = str(enemy_name)
		enemy.enemy_type = enemy_type
		enemy.faction = str(ENEMY_FACTION_BY_TYPE.get(enemy_type, ""))
		enemy.ai_type = str(enemy_def.get("ai", ""))
		enemy.max_hp = int(enemy_def.get("hp", 0))
		enemy.damage_preview_min = int(enemy_def.get("dMin", 0))
		enemy.damage_preview_max = int(enemy_def.get("dMax", 0))
		enemy.phase_two_damage_preview_min = int(enemy_def.get("p2dMin", 0))
		enemy.phase_two_damage_preview_max = int(enemy_def.get("p2dMax", 0))
		enemy.phase_two_threshold = int(enemy_def.get("pThr", 0))
		enemy.can_summon_elite = bool(enemy_def.get("summonElite", false))
		enemy.portrait = _load_enemy_portrait(enemy.enemy_type)
		enemy.dice_ranges = _build_enemy_dice_ranges(enemy_abilities.get(enemy_type, {}))
		enemies[enemy.id] = enemy


func _load_items() -> void:
	var consumables_payload: Dictionary = _parse_json_file(ITEMS_DATA_PATH)
	var gear_payload: Dictionary = _parse_json_file(GEAR_DATA_PATH)
	var relics_payload: Array = _parse_json_file(RELICS_DATA_PATH)

	for item_entry in consumables_payload.get("items", []):
		var item: ItemData = _build_item_resource(item_entry, "consumable")
		items[item.id] = item

	for gear_entry in gear_payload.get("gear", []):
		var gear_item: ItemData = _build_item_resource(gear_entry, "gear")
		items[gear_item.id] = gear_item

	for relic_entry in relics_payload:
		var relic_item: ItemData = _build_item_resource(relic_entry, "relic")
		items[relic_item.id] = relic_item


func _load_operations() -> void:
	var battle_modes_payload: Dictionary = _parse_json_file(BATTLE_MODES_DATA_PATH)
	var modes: Dictionary = battle_modes_payload.get("modes", {})
	operation_order = battle_modes_payload.get("order", []).duplicate()
	for operation_id in operation_order:
		if modes.has(operation_id):
			_load_operation_from_entry(str(operation_id), modes[operation_id])
	for operation_id in modes.keys():
		if operations.has(str(operation_id)):
			continue
		operation_order.append(str(operation_id))
		_load_operation_from_entry(str(operation_id), modes[operation_id])


func _load_operation_from_entry(operation_id: String, mode_entry: Dictionary) -> void:
	var operation: OperationData = OperationData.new()
	operation.id = operation_id
	operation.display_name = str(mode_entry.get("label", ""))
	operation.blurb = str(mode_entry.get("blurb", ""))
	operation.victory_title = str(mode_entry.get("victoryTitle", ""))
	operation.victory_subtitle = str(mode_entry.get("victorySub", ""))
	operation.track_hp_scale = float(mode_entry.get("trackHpScale", 1.0))
	operation.battles = _build_operation_battles(mode_entry.get("battles", []))
	operations[operation.id] = operation


func _build_hero_dice_ranges(abilities: Array) -> Array[Dictionary]:
	var ranges: Array[Dictionary] = []
	for ability_entry in abilities:
		var range_pair: Array = ability_entry.get("range", [])
		var min_roll := int(range_pair[0]) if range_pair.size() > 0 else 0
		var max_roll := int(range_pair[1]) if range_pair.size() > 1 else min_roll
		var entry: Dictionary = {
			"min": min_roll,
			"max": max_roll,
			"zone": str(ability_entry.get("zone", "")),
			"ability_name": str(ability_entry.get("name", "")),
			"description": str(ability_entry.get("eff", "")),
			"raw": ability_entry.duplicate(true),
		}
		ranges.append(entry)
	return ranges


func _build_evolution_paths(evolutions: Array) -> Array[Dictionary]:
	var paths: Array[Dictionary] = []
	for evolution_entry in evolutions:
		paths.append({
			"name": str(evolution_entry.get("name", "")),
			"focus": str(evolution_entry.get("focus", "")),
			"hp": int(evolution_entry.get("hp", 0)),
			"abilities": _build_hero_dice_ranges(evolution_entry.get("abilities", [])),
		})
	return paths


func _build_enemy_dice_ranges(ability_set: Dictionary) -> Array[Dictionary]:
	var ranges: Array[Dictionary] = []
	for zone_name in ["recharge", "strike", "surge", "crit", "overload"]:
		var ability_entry: Dictionary = ability_set.get(zone_name, {})
		var zone_range: Vector2i = ENEMY_ZONE_RANGES.get(zone_name, Vector2i(1, 1))
		ranges.append({
			"min": zone_range.x,
			"max": zone_range.y,
			"zone": zone_name,
			"ability_name": str(ability_entry.get("name", "")),
			"description": str(ability_entry.get("eff", "")),
			"raw": ability_entry.duplicate(true),
		})
	return ranges


func _build_item_resource(item_entry: Dictionary, item_type: String) -> ItemData:
	var item: ItemData = ItemData.new()
	item.id = str(item_entry.get("id", ""))
	item.display_name = str(item_entry.get("name", ""))
	item.item_type = item_type
	item.rarity = str(item_entry.get("rarity", ""))
	item.icon_key = str(item_entry.get("icon", ""))
	item.target_kind = str(item_entry.get("target", "none"))
	item.description = str(item_entry.get("desc", ""))
	item.effect = item_entry.get("effect", {}).duplicate(true)
	return item


func _build_operation_battles(battles: Array) -> Array[Dictionary]:
	var built_battles: Array[Dictionary] = []
	var battle_number: int = 1
	for battle in battles:
		var enemy_names: Array = []
		for enemy_entry in battle.get("enemies", []):
			enemy_names.append(str(enemy_entry.get("name", "")))
		built_battles.append({
			"battle_number": battle_number,
			"battle_label": "Battle %d" % battle_number,
			"enemy_names": enemy_names,
		})
		battle_number += 1
	return built_battles


func _parse_json_file(file_path: String) -> Variant:
	if not FileAccess.file_exists(file_path):
		push_warning("Missing data file: %s" % file_path)
		return {}

	var file_text := FileAccess.get_file_as_string(file_path)
	var parsed: Variant = JSON.parse_string(file_text)
	if parsed == null:
		push_warning("Failed to parse JSON: %s" % file_path)
		return {}
	return parsed


func _load_hero_portrait(unit_id: String) -> Texture2D:
	var file_name: String = str(HERO_PORTRAIT_BY_ID.get(unit_id, ""))
	if file_name == "":
		return null
	return _load_texture_if_exists("%s%s" % [LEGACY_HERO_PORTRAIT_ROOT, file_name])


func _load_enemy_portrait(enemy_type: String) -> Texture2D:
	var file_name: String = str(ENEMY_PORTRAIT_BY_TYPE.get(enemy_type, ""))
	if file_name == "":
		return null
	return _load_texture_if_exists("%s%s" % [LEGACY_ENEMY_PORTRAIT_ROOT, file_name])


func _load_texture_if_exists(texture_path: String) -> Texture2D:
	if not ResourceLoader.exists(texture_path):
		return null
	return load(texture_path) as Texture2D


func _slugify(source_text: String) -> String:
	var result := source_text.to_lower().strip_edges()
	result = result.replace(" ", "_")
	result = result.replace("-", "_")
	result = result.replace("/", "_")
	result = result.replace(".", "")
	return result
