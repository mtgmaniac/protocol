# Unit traits (G-62, Kev 2026-10-09): one always-on rule on some units.
#
# The data is data/raw/traits.data.json: what each trait is called, its one
# line of text, its numbers, and who has it. This file reads it and hands a
# unit its trait as one Dictionary (`unit_trait` on UnitData / EnemyData):
#
#   {"id": "afterburn", "name": "Smoldering", "text": "Detonating leaves 1 burn
#    for 2 turns.", "burn": 1, "turns": 2}
#
# `name` is a title read with the unit's callsign: SMOLDERING PYRO, BARBED
# STALKER (G-63). `id` is the data key the rules test; it is never shown.
#
# Who carries one (G-71, Kev 2026-10-10): an enemy carries the trait the data
# gives it. A hero evolution has TWO to choose between and carries neither
# until its 250 XP pick (GameState.get_run_unit_data puts the chosen one on
# the unit); `evolution_trait_ids` lists both, the branch's signature trait
# first. On a player's first run no enemy carries one (G-72,
# DataManager.enemy_for_battle).
#
# `text` is the trait's line with its {numbers} filled in from the same entry
# the engine reads, so the text cannot print a number the engine does not
# apply. {band} is the unit's first roll window, read from its kit.
#
# `needs` (G-64) lists what the trait needs from its unit's kit, as keys of the
# file's `requirements` table. validate-data enforces it; nothing in the game
# reads it yet (groundwork for trait pools).
#
# Rules live in CombatManager (`_has_trait`) and, for the four round-start
# traits, BattleEngine.apply_round_start_traits. Nothing here changes combat.
# Preloaded by path, no class_name: headless gates parse before the editor's
# class cache exists.
extends RefCounted

const DATA_PATH := "res://data/raw/traits.data.json"
# The XP at which an evolved hero picks one of its branch's two traits (G-71).
# GameState.XP_TO_PRESTIGE is this number.
const PRESTIGE_XP := 250

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {"traits": {}, "evolutions": {}, "enemies": {}}
	return _data


# The ids of the two traits a hero evolution chooses between at 250 XP (G-71):
# the branch's signature trait, then the one that was a Directive. [] for an
# unknown evolution. A hero carries neither until it picks.
static func evolution_trait_ids(hero_id: String, evolution_id: String) -> Array:
	var listed: Variant = (data().get("evolutions", {}) as Dictionary).get("%s/%s" % [hero_id, evolution_id], [])
	return (listed as Array).duplicate() if listed is Array else []


# The trait a Directive became, by the Directive's name ("" for one that was
# not converted). Only a run saved before G-71 still holds such a name.
static func legacy_directive_trait(directive_name: String) -> String:
	return str((data().get("legacyDirectives", {}) as Dictionary).get(directive_name, ""))


# The trait id for an enemy by display name ("" when it has none).
static func enemy_trait_id(display_name: String) -> String:
	var assigned: String = str((data().get("enemies", {}) as Dictionary).get(display_name, ""))
	# The `traits` gate's `boss_trait` break: every unit without a trait gets one.
	if assigned == "" and OS.is_debug_build() and OS.get_cmdline_user_args().has("--trait-break=boss_trait"):
		return "barbed"
	return assigned


# A trait as a unit carries it. `dice_ranges` is the unit's kit, for {band}.
# {} for an unknown or empty id.
static func build(trait_id: String, dice_ranges: Array = []) -> Dictionary:
	var definition: Dictionary = (data().get("traits", {}) as Dictionary).get(trait_id, {})
	if trait_id == "" or definition.is_empty():
		return {}
	var built: Dictionary = definition.duplicate(true)
	# JSON reads every number as a float; a trait's numbers are whole.
	for key in built:
		if built[key] is float:
			built[key] = int(built[key])
	built["id"] = trait_id
	var values: Dictionary = built.duplicate()
	values["band"] = first_band_text(dice_ranges)
	built["text"] = str(definition.get("text", "")).format(values)
	return built


# The unit's first roll window as text: "1-7".
static func first_band_text(dice_ranges: Array) -> String:
	if dice_ranges.is_empty():
		return "its lowest rolls"
	var band: Dictionary = dice_ranges[0]
	var low: int = int(band.get("min", 1))
	var high: int = int(band.get("max", low))
	return str(low) if low == high else "%d-%d" % [low, high]


# The trait a unit resource carries ({} when it has none or is not a unit).
static func of_unit(unit: Variant) -> Dictionary:
	if unit == null or not (unit is Object):
		return {}
	var carried: Variant = (unit as Object).get("unit_trait")
	return carried if carried is Dictionary else {}


# A trait's name by its id ("" for an unknown id). For a log line about a
# trait whose owner is not at hand.
static func name_of(trait_id: String) -> String:
	return str(((data().get("traits", {}) as Dictionary).get(trait_id, {}) as Dictionary).get("name", ""))


# What every screen prints: "SMOLDERING: Detonating leaves 1 burn for 2 turns."
# "" when the unit has no trait.
static func line(unit_trait: Dictionary) -> String:
	if unit_trait.is_empty():
		return ""
	return "%s: %s" % [str(unit_trait.get("name", "")).to_upper(), str(unit_trait.get("text", ""))]


# What a branch shows before the pick (G-71): "AT 250 XP: SMOLDERING or SEARING".
# `options` are the branch's traits as built; "" when it has none.
static func preview_line(options: Array) -> String:
	var names: PackedStringArray = []
	for option in options:
		names.append(marker_text(option as Dictionary))
	return "" if names.is_empty() else "AT %d XP: %s" % [PRESTIGE_XP, " or ".join(names)]


# The battle card's marker: the trait's name, on the line above the callsign,
# so the two read as the unit's full name (VOLATILE VOLT).
static func marker_text(unit_trait: Dictionary) -> String:
	return str(unit_trait.get("name", "")).to_upper()


# True for a trait whose marker is drawn in the warning colour (Volatile:
# killing this unit costs the squad HP; the long-press says how much).
static func is_warning(unit_trait: Dictionary) -> bool:
	return bool(unit_trait.get("warning", false))
