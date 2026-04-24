# Loads structured game data from the migrated Angular JSON tables and exposes it as Resources.
extends Node

const HEROES_DATA_PATH := "res://data/raw/heroes.data.json"
const ENEMIES_DATA_PATH := "res://data/raw/enemies.data.json"
const ITEMS_DATA_PATH := "res://data/raw/items.data.json"
const GEAR_DATA_PATH := "res://data/raw/gear.data.json"
const RELICS_DATA_PATH := "res://data/raw/relics.data.json"
const BATTLE_MODES_DATA_PATH := "res://data/raw/battle-modes.json"
const HERO_PORTRAIT_ROOT := "res://assets/portraits/"
const ENEMY_PORTRAIT_ROOT := "res://assets/portraits/enemies/"
const LEGACY_UI_ROOT := "res://legacy-angular/public/ui/"

const ITEM_ICON_BY_ID := {
	"patch_kit": "res://assets/icons/items/item_003.png",
	"biofoam": "res://assets/icons/items/item_004.png",
	"field_meds": "res://assets/icons/items/item_010.png",
	"nanite_salve": "res://assets/icons/items/item_028.png",
	"scrap_plate": "res://assets/icons/items/item_007.png",
	"reactive_weave": "res://assets/icons/items/item_006.png",
	"aegis_foil": "res://assets/icons/items/item_024.png",
	"calibration_chip": "res://assets/icons/items/item_008.png",
	"momentum_core": "res://assets/icons/items/item_032.png",
	"oracle_lens": "res://assets/icons/items/item_016.png",
	"defib_spark": "res://assets/icons/items/item_017.png",
	"full_restore": "res://assets/icons/items/item_042.png",
	"ghost_veil": "res://assets/icons/items/item_011.png",
	"rust_patch": "res://assets/icons/items/item_012.png",
	"corrosion_bomb": "res://assets/icons/items/item_013.png",
	"entropy_seed": "res://assets/icons/items/item_014.png",
	"shock_charge": "res://assets/icons/items/item_002.png",
	"grounding_clip": "res://assets/icons/items/item_026.png",
	"arc_capacitor": "res://assets/icons/items/item_025.png",
	"aegis_saturation": "res://assets/icons/items/item_020.png",
	"harmonic_injector": "res://assets/icons/items/item_030.png",
	"scatter_veil_array": "res://assets/icons/items/item_038.png",
	"archive_cascade": "res://assets/icons/items/item_033.png",
	"citadel_kernel": "res://assets/icons/items/item_037.png",
	"terminal_spike": "res://assets/icons/items/item_059.png",
	"acid_vial": "res://assets/icons/items/item_031.png",
	"nanite_burn": "res://assets/icons/items/item_029.png",
	"thermite_canister": "res://assets/icons/items/item_034.png",
	"null_vector": "res://assets/icons/items/item_035.png",
	"training_datachip": "res://assets/icons/items/item_063.png",
	"field_manual": "res://assets/icons/items/item_033.png",
	"mnemonic_core": "res://assets/icons/items/item_034.png",
	"gyro_motor": "res://assets/icons/items/item_008.png",
	"cascade_jammer": "res://assets/icons/items/item_036.png",
	"cryo_gel": "res://assets/icons/items/item_015.png",
	"cryo_web": "res://assets/icons/items/item_045.png",
	"neural_splice": "res://assets/icons/items/item_034.png",
	"combat_plating": "res://assets/icons/items/item_057.png",
	"stim_injector": "res://assets/icons/items/item_004.png",
	"void_shard": "res://assets/icons/items/item_035.png",
	"phase_weave": "res://assets/icons/items/item_011.png",
	"scavenger_rig": "res://assets/icons/items/item_019.png",
	"protocol_tap": "res://assets/icons/items/item_017.png",
	"dead_mans_chip": "res://assets/icons/items/item_063.png",
	"exile_blade_core": "res://assets/icons/items/item_059.png",
	"signal_jammer_mk2": "res://assets/icons/items/item_024.png",
}

const RELIC_ICON_BY_ID := {
	"ironCurtain": "res://assets/icons/items/item_055.png",
	"openingGambit": "res://assets/icons/items/item_036.png",
	"bulwarkAura": "res://assets/icons/items/item_020.png",
	"naniteField": "res://assets/icons/items/item_047.png",
	"plagueProtocol": "res://assets/icons/items/item_013.png",
	"overcharge": "res://assets/icons/items/item_042.png",
	"signalJam": "res://assets/icons/items/item_036.png",
	"coordinatedStrike": "res://assets/icons/items/item_043.png",
	"resonanceCascade": "res://assets/icons/items/item_052.png",
	"gravityWell": "res://assets/icons/items/item_053.png",
	"protocolOverride": "res://assets/icons/items/item_032.png",
	"entropyLeak": "res://assets/icons/items/item_046.png",
	"chainReaction": "res://assets/icons/items/item_048.png",
}

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
	"pulse": "pulse.png",
	"combat": "combat.png",
	"shield": "shield.png",
	"avalanche": "avalanche.png",
	"medic": "medic.png",
	"engineer": "engineer.png",
	"ghost": "ghost.png",
	"breaker": "breaker.png",
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

const ENEMY_PORTRAIT_BY_NAME := {
	"Scrap Drone": "scrap_drone.png",
	"Rust Drone": "rust_drone.png",
	"Whitenoise Skimmer": "whitenoise_skimmer.png",
	"Patrol Elite": "patrol_elite.png",
	"Guard Elite": "guard_elite.png",
	"Heavy Warden": "heavy_warden.png",
	"Volt Elite": "volt_elite.png",
	"Harmonic Hexnode": "harmonic_hexnode.png",
	"SCRAPMASTER": "scrapmaster.png",
	"Skitterling": "skitterling.png",
	"Bloodmite": "bloodmite.png",
	"Spine Stalker": "spine_stalker.png",
	"Carapace Beetle": "carapace_beetle.png",
	"Broodwarden": "broodwarden.png",
	"Caustic Spewer": "caustic_spewer.png",
	"Hive Matriarch": "hive_matriarch.png",
	"Rift Macaque": "res://assets/portraits/enemies/rift_macaque.png",
	"Void Hound": "res://assets/portraits/enemies/void_hound.png",
	"Pack Hound": "res://assets/portraits/enemies/void_hound.png",
	"Eclipse Panther": "res://assets/portraits/enemies/eclipse_panther.png",
	"Ridge Drake": "res://assets/portraits/enemies/ridge_drake.png",
	"Eclipse Raptor": "res://assets/portraits/enemies/eclipse_raptor.png",
	"Thunder Ape": "res://assets/portraits/enemies/thunder_ape.png",
	"VOID REAVER": "res://assets/portraits/enemies/void_reaver.png",
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
		enemy.portrait = _load_enemy_portrait(enemy.display_name)
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
	var icon_path: String = ""
	if item.item_type == "relic":
		icon_path = str(RELIC_ICON_BY_ID.get(item.id, ""))
	else:
		icon_path = str(ITEM_ICON_BY_ID.get(item.id, ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		item.icon = load(icon_path) as Texture2D
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
	return _load_texture_if_exists("%s%s" % [HERO_PORTRAIT_ROOT, file_name])


func _load_enemy_portrait(enemy_name: String) -> Texture2D:
	var mapped_path: String = str(ENEMY_PORTRAIT_BY_NAME.get(enemy_name, ""))
	if mapped_path != "":
		if mapped_path.begins_with("res://"):
			return _load_texture_if_exists(mapped_path)
		return _load_texture_if_exists("%s%s" % [ENEMY_PORTRAIT_ROOT, mapped_path])
	return null


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
