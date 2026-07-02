# Loads structured game data from the migrated Angular JSON tables and exposes it as Resources.
extends Node

const HEROES_DATA_PATH := "res://data/raw/heroes.data.json"
const ENEMIES_DATA_PATH := "res://data/raw/enemies.data.json"
const ITEMS_DATA_PATH := "res://data/raw/items.data.json"
const GEAR_DATA_PATH := "res://data/raw/gear.data.json"
const RELICS_DATA_PATH := "res://data/raw/relics.data.json"
const BATTLE_MODES_DATA_PATH := "res://data/raw/battle-modes.json"
const KEYWORDS_DATA_PATH := "res://data/raw/keywords.data.json"
const HERO_PORTRAIT_ROOT := "res://assets/portraits/"
const ENEMY_PORTRAIT_ROOT := "res://assets/portraits/enemies/"
const LEGACY_UI_ROOT := "res://legacy-angular/public/ui/"

const ITEM_ICON_BY_ID := {
	"patch_kit": "res://assets/icons/items/patch_kit.png",
	"field_meds": "res://assets/icons/items/field_meds.png",
	"nanite_salve": "res://assets/icons/items/nanite_salve.png",
	"scrap_plate": "res://assets/icons/items/scrap_plate.png",
	"reactive_weave": "res://assets/icons/items/reactive_weave.png",
	"calibration_chip": "res://assets/icons/items/calibration_chip.png",
	"momentum_core": "res://assets/icons/items/momentum_core.png",
	"defib_spark": "res://assets/icons/items/defib_spark.png",
	"full_restore": "res://assets/icons/items/full_restore.png",
	"ghost_veil": "res://assets/icons/items/ghost_veil.png",
	"corrosion_bomb": "res://assets/icons/items/corrosion_bomb.png",
	"entropy_seed": "res://assets/icons/items/entropy_seed.png",
	"shock_charge": "res://assets/icons/items/shock_charge.png",
	"grounding_clip": "res://assets/icons/items/grounding_clip.png",
	"arc_capacitor": "res://assets/icons/items/arc_capacitor.png",
	"harmonic_injector": "res://assets/icons/items/harmonic_injector.png",
	"scatter_veil_array": "res://assets/icons/items/scatter_veil_array.png",
	"archive_cascade": "res://assets/icons/items/archive_cascade.png",
	"citadel_kernel": "res://assets/icons/items/citadel_kernel.png",
	"terminal_spike": "res://assets/icons/items/terminal_spike.png",
	"acid_vial": "res://assets/icons/items/acid_vial.png",
	"nanite_burn": "res://assets/icons/items/nanite_burn.png",
	"thermite_canister": "res://assets/icons/items/thermite_canister.png",
	"null_vector": "res://assets/icons/items/null_vector.png",
	"training_datachip": "res://assets/icons/items/training_datachip.png",
	"field_manual": "res://assets/icons/items/field_manual.png",
	"mnemonic_core": "res://assets/icons/items/mnemonic_core.png",
	"phase_scrambler": "res://assets/icons/items/phase_scrambler.png",
	"cascade_jammer": "res://assets/icons/items/cascade_jammer.png",
	"cryo_gel": "res://assets/icons/items/cryo_gel.png",
	"cryo_web": "res://assets/icons/items/cryo_web.png",
	"protocol_cell": "res://assets/icons/items/protocol_cell.png",
	"capacitor_dose": "res://assets/icons/items/capacitor_dose.png",
	"core_surge": "res://assets/icons/items/core_surge.png",
	"mainline_cache": "res://assets/icons/items/mainline_cache.png",
	"double_tap_chip": "res://assets/icons/items/double_tap_chip.png",
	"neural_splice": "res://assets/icons/items/neural_splice.png",
	"combat_plating": "res://assets/icons/items/combat_plating.png",
	"stim_injector": "res://assets/icons/items/stim_injector.png",
	"void_shard": "res://assets/icons/items/void_shard.png",
	"phase_weave": "res://assets/icons/items/phase_weave.png",
	"scavenger_rig": "res://assets/icons/items/scavenger_rig.png",
	"protocol_tap": "res://assets/icons/items/protocol_tap.png",
	"dead_mans_chip": "res://assets/icons/items/dead_mans_chip.png",
	"exile_blade_core": "res://assets/icons/items/exile_blade_core.png",
	"fortress_mesh": "res://assets/icons/items/fortress_mesh.png",
}

const RELIC_ICON_BY_ID := {
	"ironCurtain": "res://assets/icons/items/ironCurtain.png",
	"openingGambit": "res://assets/icons/items/openingGambit.png",
	"bulwarkAura": "res://assets/icons/items/bulwarkAura.png",
	"naniteField": "res://assets/icons/items/naniteField.png",
	"plagueProtocol": "res://assets/icons/items/plagueProtocol.png",
	"overcharge": "res://assets/icons/items/overcharge.png",
	"signalJam": "res://assets/icons/items/signalJam.png",
	"coordinatedStrike": "res://assets/icons/items/coordinatedStrike.png",
	"resonanceCascade": "res://assets/icons/items/resonanceCascade.png",
	"gravityWell": "res://assets/icons/items/gravityWell.png",
	"protocolOverride": "res://assets/icons/items/protocolOverride.png",
	"entropyLeak": "res://assets/icons/items/entropyLeak.png",
	"chainReaction": "res://assets/icons/items/chainReaction.png",
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
	"Static Skimmer": "whitenoise_skimmer.png",
	"Patrol Elite": "patrol_elite.png",
	"Guard Elite": "guard_elite.png",
	"Heavy Warden": "heavy_warden.png",
	"Volt Elite": "volt_elite.png",
	"SCRAPMASTER": "scrapmaster.png",
	"Skitterling": "skitterling.png",
	"Bloodmite": "bloodmite.png",
	"Spine Stalker": "spine_stalker.png",
	"Carapace Beetle": "carapace_beetle.png",
	"Broodwarden": "broodwarden.png",
	"Caustic Spewer": "caustic_spewer.png",
	"Hive Matriarch": "hive_matriarch.png",
	# The Accretion (pkg3.3 renames) — aliases to the existing menagerie art.
	"Pumice Macaque": "res://assets/portraits/enemies/rift_macaque.png",
	"Obsidian Hound": "res://assets/portraits/enemies/void_hound.png",
	"Slag Hound": "res://assets/portraits/enemies/void_hound.png",
	"Geode Panther": "res://assets/portraits/enemies/eclipse_panther.png",
	"Magma Drake": "res://assets/portraits/enemies/ridge_drake.png",
	"Pyroclast Raptor": "res://assets/portraits/enemies/eclipse_raptor.png",
	"Basalt Ape": "res://assets/portraits/enemies/thunder_ape.png",
	"MANTLE TYRANT": "res://assets/portraits/enemies/void_reaver.png",
	# Null Synod (pkg3.3 renames) — aliases to the existing circlet art.
	"Glitch Sprite": "res://assets/portraits/enemies/sparksprite.png",
	"Init Acolyte": "res://assets/portraits/enemies/levyn_acolyte.png",
	"Checksum Scribe": "res://assets/portraits/enemies/chronicle_scribe.png",
	"Axiom Binder": "res://assets/portraits/enemies/geas_binder.png",
	"Forked Double": "res://assets/portraits/enemies/glimmer_double.png",
	"Daemon Channeler": "res://assets/portraits/enemies/arc_titan_channeler.png",
	"ROOT HIEROPHANT": "res://assets/portraits/enemies/circlet_hierophant.png",
}

var units: Dictionary = {}
var enemies: Dictionary = {}
var items: Dictionary = {}
var _keywords_cache: Dictionary = {}
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


# Combat keyword glossary (single source of truth for the help menu + tooltips). Lazy-loaded
# and cached from keywords.data.json; returns the parsed dict ({keywords, conventions, ...}).
func get_keywords() -> Dictionary:
	if _keywords_cache.is_empty():
		var parsed: Variant = _parse_json_file(KEYWORDS_DATA_PATH)
		if parsed is Dictionary:
			_keywords_cache = parsed
	return _keywords_cache


func get_operation(operation_id: String) -> Resource:
	return operations.get(operation_id)


func get_operation_order() -> Array:
	return operation_order.duplicate()


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
		unit.callsign = str(hero_entry.get("callsign", ""))
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
		enemy.callsign = str(enemy_def.get("callsign", ""))
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
		enemy.accrete = int(enemy_def.get("accrete", 0))
		enemy.starts_cloaked = bool(enemy_def.get("startsCloaked", false))
		var revive_names: Array = enemy_def.get("p2ReviveNames", [])
		enemy.phase_two_revive_names = []
		for revive_name in revive_names:
			enemy.phase_two_revive_names.append(str(revive_name))
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
	operation.callsign = str(mode_entry.get("callsign", ""))
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
			"callsign": str(evolution_entry.get("callsign", "")),
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
	item.boss_relic = bool(item_entry.get("bossRelic", false))
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
	return _crop_to_content(_load_texture_if_exists("%s%s" % [HERO_PORTRAIT_ROOT, file_name]))


func _load_enemy_portrait(enemy_name: String) -> Texture2D:
	var mapped_path: String = str(ENEMY_PORTRAIT_BY_NAME.get(enemy_name, ""))
	var tex: Texture2D = null
	if mapped_path != "":
		if mapped_path.begins_with("res://"):
			tex = _load_texture_if_exists(mapped_path)
		else:
			tex = _load_texture_if_exists("%s%s" % [ENEMY_PORTRAIT_ROOT, mapped_path])
	else:
		# Fallback: a file named after the slugified enemy name (covers enemies/bosses
		# not in the explicit map, e.g. conclave_overseer.png, aegis_anchor.png).
		tex = _load_texture_if_exists("%s%s.png" % [ENEMY_PORTRAIT_ROOT, _slugify(enemy_name)])
	return _crop_to_content(tex)


# Portrait finalisation. Two art styles coexist:
#  - cutout: transparent background, subject fills the canvas (heroes, older
#    facility/hive enemies). Cropped to the opaque bounding box so cover-fill
#    frames the character, not the padding.
#  - full-bleed: opaque scenic background with the subject centred (veil /
#    menagerie / void circlet art). Tagged with a "full_bleed" meta so
#    PixelUI.cover_fit_portrait() centres the crop instead of top-anchoring.
# The tag is how every screen frames both styles consistently without
# per-unit offsets.
func _crop_to_content(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null:
		return tex
	tex.set_meta("full_bleed", _is_full_bleed(img))
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return tex
	if used.position == Vector2i.ZERO and used.size == img.get_size():
		return tex
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(used)
	atlas.filter_clip = true
	atlas.set_meta("full_bleed", tex.get_meta("full_bleed", false))
	return atlas


# Sampled opaque coverage: scenic full-bleed art is ~100% opaque, cutout art
# leaves large transparent margins (measured range 43-72%).
func _is_full_bleed(img: Image) -> bool:
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w < 8 or h < 8:
		return false
	var opaque: int = 0
	var total: int = 0
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			total += 1
			if img.get_pixel(x, y).a > 0.8:
				opaque += 1
	return total > 0 and float(opaque) / float(total) > 0.9


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
