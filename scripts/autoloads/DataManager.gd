# Loads structured game data from the migrated Angular JSON tables and exposes it as Resources.
extends Node

const HEROES_DATA_PATH := "res://data/raw/heroes.data.json"
const ENEMIES_DATA_PATH := "res://data/raw/enemies.data.json"
const ITEMS_DATA_PATH := "res://data/raw/items.data.json"
const GEAR_DATA_PATH := "res://data/raw/gear.data.json"
const RELICS_DATA_PATH := "res://data/raw/relics.data.json"
const BATTLE_MODES_DATA_PATH := "res://data/raw/battle-modes.json"
const KEYWORDS_DATA_PATH := "res://data/raw/keywords.data.json"
const PRIMERS_DATA_PATH := "res://data/raw/primers.data.json"
const HERO_PORTRAIT_ROOT := "res://assets/portraits/"
const ENEMY_PORTRAIT_ROOT := "res://assets/portraits/enemies/"
const LEGACY_UI_ROOT := "res://legacy-angular/public/ui/"

const ITEM_ICON_BY_ID := {
	"patch_kit": "res://assets/icons/items/patch_kit.png",
	"triage_broadcast": "res://assets/icons/items/triage_broadcast.png",
	"scrap_plate": "res://assets/icons/items/scrap_plate.png",
	"buckler_array": "res://assets/icons/items/buckler_array.png",
	"calibration_chip": "res://assets/icons/items/calibration_chip.png",
	"momentum_core": "res://assets/icons/items/momentum_core.png",
	"defib_spark": "res://assets/icons/items/defib_spark.png",
	"ghost_veil": "res://assets/icons/items/ghost_veil.png",
	"corrosion_bomb": "res://assets/icons/items/corrosion_bomb.png",
	"entropy_seed": "res://assets/icons/items/entropy_seed.png",
	"shock_charge": "res://assets/icons/items/shock_charge.png",
	"grounding_clip": "res://assets/icons/items/grounding_clip.png",
	"harmonic_injector": "res://assets/icons/items/harmonic_injector.png",
	"scatter_veil_array": "res://assets/icons/items/scatter_veil_array.png",
	"archive_cascade": "res://assets/icons/items/archive_cascade.png",
	"acid_vial": "res://assets/icons/items/acid_vial.png",
	"phase_scrambler": "res://assets/icons/items/phase_scrambler.png",
	"cascade_jammer": "res://assets/icons/items/cascade_jammer.png",
	"cryo_gel": "res://assets/icons/items/cryo_gel.png",
	"cryo_web": "res://assets/icons/items/cryo_web.png",
	"deep_zero_pin": "res://assets/icons/items/deep_zero_pin.png",
	"protocol_cell": "res://assets/icons/items/protocol_cell.png",
	"capacitor_dose": "res://assets/icons/items/capacitor_dose.png",
	"core_surge": "res://assets/icons/items/core_surge.png",
	"mainline_cache": "res://assets/icons/items/mainline_cache.png",
	"neural_splice": "res://assets/icons/items/neural_splice.png",
	"combat_plating": "res://assets/icons/items/combat_plating.png",
	"stim_injector": "res://assets/icons/items/stim_injector.png",
	"phase_weave": "res://assets/icons/items/phase_weave.png",
	"protocol_tap": "res://assets/icons/items/protocol_tap.png",
	"dead_mans_chip": "res://assets/icons/items/dead_mans_chip.png",
	"predator_lens": "res://assets/icons/items/predator_lens.png",
	"warframe_core": "res://assets/icons/items/warframe_core.png",
	"kill_switch": "res://assets/icons/items/kill_switch.png",
	"mainline_bus": "res://assets/icons/items/mainline_bus.png",
	"triage_gel": "res://assets/icons/items/triage_gel.png",
	"counterweight": "res://assets/icons/items/counterweight.png",
	"siphon_loop": "res://assets/icons/items/siphon_loop.png",
	"hemophage_nexus": "res://assets/icons/items/hemophage_nexus.png",
	"spike_driver": "res://assets/icons/items/spike_driver.png",
	"overkill_matrix": "res://assets/icons/items/overkill_matrix.png",
	"echo_matrix": "res://assets/icons/items/echo_matrix.png",
	"breach_tip": "res://assets/icons/items/breach_tip.png",
	"bounty_chip": "res://assets/icons/items/bounty_chip.png",
	"band_compressor": "res://assets/icons/items/band_compressor.png",
	"wide_aperture": "res://assets/icons/items/wide_aperture.png",
	"reverse_gimbal": "res://assets/icons/items/reverse_gimbal.png",
	"priming_charge": "res://assets/icons/items/priming_charge.png",
	"overload_capacitor": "res://assets/icons/items/overload_capacitor.png",
	"ignition_coil": "res://assets/icons/items/ignition_coil.png",
	"payload_fuse": "res://assets/icons/items/payload_fuse.png",
	"targeting_optic": "res://assets/icons/items/targeting_optic.png",
	"mirror_plate": "res://assets/icons/items/mirror_plate.png",
	"anchor_frame": "res://assets/icons/items/anchor_frame.png",
	"killswitch_relay": "res://assets/icons/items/killswitch_relay.png",
	"sync_antenna": "res://assets/icons/items/sync_antenna.png",
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
	"martyrdomProtocol": "res://assets/icons/items/martyrdomProtocol.png",
	"overloadLoop": "res://assets/icons/items/overloadLoop.png",
	"curatedCache": "res://assets/icons/items/curatedCache.png",
	"overflowBuffer": "res://assets/icons/items/overflowBuffer.png",
	"fieldCache": "res://assets/icons/items/fieldCache.png",
	"mercyProtocol": "res://assets/icons/items/mercyProtocol.png",
	"emergencySignal": "res://assets/icons/items/emergencySignal.png",
	"aegisField": "res://assets/icons/items/aegisField.png",
	"standingOrder": "res://assets/icons/items/standingOrder.png",
	"staticField": "res://assets/icons/items/staticField.png",
	"twinFates": "res://assets/icons/items/twinFates.png",
	"overflowVent": "res://assets/icons/items/overflowVent.png",
	"salvageDirective": "res://assets/icons/items/salvageDirective.png",
	"coldLogic": "res://assets/icons/items/coldLogic.png",
	"chainDoctrine": "res://assets/icons/items/chainDoctrine.png",
	"scavengerManifest": "res://assets/icons/items/scavengerManifest.png",
	"deadMansHand": "res://assets/icons/items/deadMansHand.png",
	"salvageRig": "res://assets/icons/items/salvageRig.png",
	"chitinGraft": "res://assets/icons/items/chitinGraft.png",
	"resonantChorus": "res://assets/icons/items/resonantChorus.png",
	"rootAccess": "res://assets/icons/items/rootAccess.png",
	"mantleCore": "res://assets/icons/items/mantleCore.png",
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
	"Static Skimmer": "static_skimmer.png",
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
	# The Accretion (files renamed to current unit names, 2026-07-07).
	"Pumice Macaque": "pumice_macaque.png",
	"Obsidian Hound": "obsidian_hound.png",
	# Hound art gap CLOSED 2026-07-07: Slag Hound has its own file now.
	"Slag Hound": "slag_hound.png",
	"Geode Panther": "geode_panther.png",
	"Magma Drake": "magma_drake.png",
	"Pyroclast Raptor": "pyroclast_raptor.png",
	"Basalt Ape": "basalt_ape.png",
	"MANTLE TYRANT": "mantle_tyrant.png",
	# Null Synod (files renamed to current unit names, 2026-07-07).
	"Glitch Sprite": "glitch_sprite.png",
	"Init Acolyte": "init_acolyte.png",
	"Checksum Scribe": "checksum_scribe.png",
	"Axiom Binder": "axiom_binder.png",
	"Forked Double": "forked_double.png",
	"Daemon Channeler": "daemon_channeler.png",
	"ROOT HIEROPHANT": "root_hierophant.png",
	# Veil Concord — previously resolved only through the _slugify fallback
	# (audited 2026-07-07: every unit landed on its own file; veil_spare.png
	# and harmonic_hexnode.png were referenced by nothing → moved to unused/).
	"Prism Charger": "prism_charger.png",
	"Shardmite": "shardmite.png",
	"Aegis Anchor": "aegis_anchor.png",
	"Resonance Warden": "resonance_warden.png",
	"Nullblade": "nullblade.png",
	"Synapse Herald": "synapse_herald.png",
	"Stormweaver": "stormweaver.png",
	"CONCLAVE OVERSEER": "conclave_overseer.png",
}

# Enemy files painted in the MATTED-BUST style (fully opaque subject on a flat
# near-black mat — the 2026-07 art drops), which must be cropped and
# top-anchored like hero busts instead of framed as scenic full-bleed.
# EXPLICIT list on purpose: scenic art can be nearly as dark as a mat
# (mantle_tyrant's scenic border is 19% near-black; matted borders go as low
# as 25% when the subject bleeds to the edges), so no border heuristic can
# safely separate the styles. New matted drops add their filename here;
# anything absent keeps cutout/scenic framing.
const MATTED_ENEMY_PORTRAITS := {
	# Hive drop (2026-07-07) + shardmite riding along.
	"bloodmite.png": true,
	"broodwarden.png": true,
	"carapace_beetle.png": true,
	"caustic_spewer.png": true,
	"hive_matriarch.png": true,
	"shardmite.png": true,
	"skitterling.png": true,
	"spine_stalker.png": true,
	# Veil drop (2026-07-07).
	"aegis_anchor.png": true,
	"conclave_overseer.png": true,
	"nullblade.png": true,
	"prism_charger.png": true,
	"resonance_warden.png": true,
	"stormweaver.png": true,
	"synapse_herald.png": true,
	# Synod drop (2026-07-07) — art arrived under the legacy filenames,
	# installed at the current (renamed) paths.
	"axiom_binder.png": true,
	"checksum_scribe.png": true,
	"daemon_channeler.png": true,
	"forked_double.png": true,
	"glitch_sprite.png": true,
	"init_acolyte.png": true,
	"root_hierophant.png": true,
	# Accretion drop (2026-07-07) — incl. slag_hound.png, the hound split.
	"basalt_ape.png": true,
	"geode_panther.png": true,
	"magma_drake.png": true,
	"mantle_tyrant.png": true,
	"obsidian_hound.png": true,
	"pumice_macaque.png": true,
	"pyroclast_raptor.png": true,
	"slag_hound.png": true,
	# Facility drop (2026-07-07) — the last cutout-era enemy files replaced;
	# every enemy portrait is now matted-bust style.
	"guard_elite.png": true,
	"heavy_warden.png": true,
	"patrol_elite.png": true,
	"rust_drone.png": true,
	"scrap_drone.png": true,
	"scrapmaster.png": true,
	"static_skimmer.png": true,
	"volt_elite.png": true,
}

var units: Dictionary = {}
var enemies: Dictionary = {}
var items: Dictionary = {}
var _keywords_cache: Dictionary = {}
var operations: Dictionary = {}
var operation_order: Array = []


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


# Keyword primers (one-shot micro-tutorials; docs/PRIMERS.md). Lazy-loaded and
# cached; returns the LOADED entries only ($signal_hook_examples is docs-only).
var _primers_cache: Array = []

func get_primers() -> Array:
	if _primers_cache.is_empty():
		var parsed: Variant = _parse_json_file(PRIMERS_DATA_PATH)
		if parsed is Dictionary:
			_primers_cache = (parsed as Dictionary).get("primers", [])
	return _primers_cache


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

	_load_units()
	_load_enemies()
	_build_enemy_role_pools()
	_load_items()
	_load_operations()


func _load_units() -> void:
	var heroes_payload: Dictionary = _parse_json_file(HEROES_DATA_PATH)
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
		enemy.targeting = str(enemy_def.get("targeting", ""))
		enemy.max_hp = int(enemy_def.get("hp", 0))
		enemy.damage_preview_min = int(enemy_def.get("dMin", 0))
		enemy.damage_preview_max = int(enemy_def.get("dMax", 0))
		enemy.can_summon_elite = bool(enemy_def.get("summonElite", false))
		enemy.accrete = int(enemy_def.get("accrete", 0))
		enemy.starts_cloaked = bool(enemy_def.get("startsCloaked", false))
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
			"id": str(evolution_entry.get("id", "")),
			"name": str(evolution_entry.get("name", "")),
			"callsign": str(evolution_entry.get("callsign", "")),
			"focus": str(evolution_entry.get("focus", "")),
			"hp": int(evolution_entry.get("hp", 0)),
			"abilities": _build_hero_dice_ranges(evolution_entry.get("abilities", [])),
			"directives": (evolution_entry.get("directives", []) as Array).duplicate(true),
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
		var cloaked_names: Array = []
		for enemy_entry in battle.get("enemies", []):
			enemy_names.append(str(enemy_entry.get("name", "")))
			if bool(enemy_entry.get("cloaked", false)):
				cloaked_names.append(str(enemy_entry.get("name", "")))
		built_battles.append({
			"battle_number": battle_number,
			"battle_label": "Battle %d" % battle_number,
			"enemy_names": enemy_names,
			"cloaked_names": cloaked_names,
			"slots": (battle.get("slots", []) as Array).duplicate(),
		})
		battle_number += 1
	return built_battles


# --- Enemy role pools (pkg7.1 templated battle slots) ---
# Classification (documented in battle-modes.schema.json): fodder = ai "dumb";
# boss (standing-rule) units excluded; heavy = smart with hp >= 90; support =
# remaining smart units with ally-aid fields in >= 2 distinct kit zones;
# elite = the rest.

const HEAVY_HP_MIN := 90
const ALLY_AID_FIELDS := ["shieldAlly", "shieldAllyAll", "erb", "erbAll", "grantRampage", "grantRampageAll"]

var enemy_role_pools: Dictionary = {}  # faction -> {role -> [display names]}


func _build_enemy_role_pools() -> void:
	enemy_role_pools.clear()
	for enemy_variant in enemies.values():
		var enemy: EnemyData = enemy_variant as EnemyData
		if enemy == null or enemy.faction == "":
			continue
		if CombatManager.get_boss_standing_rule(enemy.display_name) != "":
			continue
		var role: String = _classify_enemy_role(enemy)
		if not enemy_role_pools.has(enemy.faction):
			enemy_role_pools[enemy.faction] = {"fodder": [], "elite": [], "support": [], "heavy": []}
		(enemy_role_pools[enemy.faction][role] as Array).append(enemy.display_name)


func _classify_enemy_role(enemy: EnemyData) -> String:
	if enemy.ai_type == "dumb":
		return "fodder"
	if enemy.max_hp >= HEAVY_HP_MIN:
		return "heavy"
	var aid_zones: Dictionary = {}
	for range_entry in enemy.dice_ranges:
		var raw: Dictionary = (range_entry as Dictionary).get("raw", {})
		for field in ALLY_AID_FIELDS:
			if raw.get(field):
				aid_zones[str((range_entry as Dictionary).get("zone", ""))] = true
	if aid_zones.size() >= 2:
		return "support"
	return "elite"


# Returns the role pool for a faction; a missing support pool falls back to
# elite (The Accretion has no support unit — documented in the schema).
func get_role_pool(faction: String, role: String) -> Array:
	var pools: Dictionary = enemy_role_pools.get(faction, {})
	var pool: Array = (pools.get(role, []) as Array).duplicate()
	if pool.is_empty() and role == "support":
		pool = (pools.get("elite", []) as Array).duplicate()
	return pool


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
	return _crop_to_content(_load_texture_if_exists("%s%s" % [HERO_PORTRAIT_ROOT, file_name]), true)


# Evolved-unit portrait convention: assets/portraits/<hero_id>_<evo_id>.png
# (evo_id = the evolution entry's "id", the lowercased callsign). A missing
# file is never an error and never blanks a card — callers keep the base
# portrait when this returns null. Cached including the null result so the
# existence check runs once per key.
var _evolution_portraits: Dictionary = {}


func get_evolution_portrait(hero_id: String, evo_id: String) -> Texture2D:
	if hero_id == "" or evo_id == "":
		return null
	var key: String = "%s_%s" % [hero_id, evo_id]
	if _evolution_portraits.has(key):
		return _evolution_portraits[key]
	var tex: Texture2D = _crop_to_content(_load_texture_if_exists("%s%s.png" % [HERO_PORTRAIT_ROOT, key]), true)
	_evolution_portraits[key] = tex
	return tex


func _load_enemy_portrait(enemy_name: String) -> Texture2D:
	var mapped_path: String = str(ENEMY_PORTRAIT_BY_NAME.get(enemy_name, ""))
	var file_name: String = mapped_path
	if mapped_path == "":
		# Fallback: a file named after the slugified enemy name (covers enemies/bosses
		# not in the explicit map, e.g. conclave_overseer.png, aegis_anchor.png).
		file_name = "%s.png" % _slugify(enemy_name)
	var tex: Texture2D
	if mapped_path.begins_with("res://"):
		tex = _load_texture_if_exists(mapped_path)
	else:
		tex = _load_texture_if_exists("%s%s" % [ENEMY_PORTRAIT_ROOT, file_name])
	return _crop_to_content(tex, MATTED_ENEMY_PORTRAITS.has(file_name.get_file()))


# Portrait finalisation. Three art styles coexist:
#  - cutout: transparent background, subject fills the canvas (older hero art,
#    facility/hive enemies). Cropped to the opaque bounding box so cover-fill
#    frames the character, not the padding.
#  - full-bleed: opaque scenic background with the subject centred (veil /
#    menagerie / void circlet art). Tagged with a "full_bleed" meta so
#    PixelUI.cover_fit_portrait() centres the crop instead of top-anchoring.
#  - matted bust (2026-07 art drops): fully opaque with the subject painted on
#    a flat near-black mat. The mat is background, not composition — cropped to
#    the subject's bounding box (vs the mat color) and framed like a cutout
#    (top-anchored), so heads sit at the frame top with no dead mat below.
#    Opt-in via `matted_bust`: ALL hero art (heroes never use scenic
#    full-bleed, so "hero + fully opaque" IS the matted style) and the enemy
#    files named in MATTED_ENEMY_PORTRAITS (explicit — scenic borders can be
#    as dark as a mat, so no heuristic can separate the styles).
# The tags are how every screen frames all styles consistently without
# per-unit offsets.
func _crop_to_content(tex: Texture2D, matted_bust: bool = false) -> Texture2D:
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null:
		return tex
	var used: Rect2i
	if matted_bust and img.detect_alpha() == Image.ALPHA_NONE:
		tex.set_meta("full_bleed", false)
		used = _mat_content_rect(img)
	else:
		tex.set_meta("full_bleed", _is_full_bleed(img))
		used = img.get_used_rect()
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


# Subject bounding box of a matted bust: everything brighter than the flat
# near-black mat counts as subject — but by ROW/COLUMN DENSITY, not any lone
# pixel. This art fades into the mat with sparse dither/noise (PHANTOM's
# static aura, BLADE's torso fade): a plain min/max bbox chases those stray
# pixels 100+px past the silhouette and puts dead mat back under the bust.
# A row/column is content only when enough of its samples are non-mat.
# Framing contract (Kev 2026-07-07): head a few pixels from the frame top
# (small top margin), NO mat below the bust (zero bottom margin — the crop
# bottom IS the last dense row); shoulders may overflow the sides.
# Sampled on a stride-4 grid, same budget as _is_full_bleed.
const _MAT_MAX_CHANNEL := 6.0 / 255.0
const _MAT_ROW_DENSITY := 0.06
const _MAT_COL_DENSITY := 0.04
const _MAT_TOP_MARGIN := 4
const _MAT_SIDE_MARGIN := 4


func _mat_content_rect(img: Image) -> Rect2i:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var xs: int = int(ceil(w / 4.0))
	var ys: int = int(ceil(h / 4.0))
	var row_hits: PackedInt32Array = PackedInt32Array()
	row_hits.resize(ys)
	var col_hits: PackedInt32Array = PackedInt32Array()
	col_hits.resize(xs)
	for yi in ys:
		for xi in xs:
			var c: Color = img.get_pixel(xi * 4, yi * 4)
			if c.r > _MAT_MAX_CHANNEL or c.g > _MAT_MAX_CHANNEL or c.b > _MAT_MAX_CHANNEL:
				row_hits[yi] += 1
				col_hits[xi] += 1
	var row_min: int = maxi(2, int(xs * _MAT_ROW_DENSITY))
	var col_min: int = maxi(2, int(ys * _MAT_COL_DENSITY))
	var top: int = -1
	var bottom: int = -1
	for yi in ys:
		if row_hits[yi] >= row_min:
			if top < 0:
				top = yi * 4
			bottom = yi * 4
	var left: int = -1
	var right: int = -1
	for xi in xs:
		if col_hits[xi] >= col_min:
			if left < 0:
				left = xi * 4
			right = xi * 4
	if top < 0 or left < 0:
		return Rect2i(0, 0, w, h)  # no dense content: keep it whole, never blank
	top = maxi(top - _MAT_TOP_MARGIN, 0)
	left = maxi(left - _MAT_SIDE_MARGIN, 0)
	right = mini(right + _MAT_SIDE_MARGIN, w - 1)
	bottom = mini(bottom, h - 1)
	return Rect2i(left, top, right - left + 1, bottom - top + 1)


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
