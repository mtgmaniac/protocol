# Roll windows, live half (Kev 2026-10-08, G-53).
#
#   godot --headless --path . -s scripts/debug/roll_windows_test.gd [-- --roll-windows-break=squeeze]
#
# scripts/checks/roll_windows.py checks the ranges in the data files. This
# checks what the game does with them:
#   A. loaded   every hero, evolution and enemy the game loads carries the
#               ranges its data file gives (no shared table in between), and
#               every face 1-20 resolves to exactly the band that owns it;
#               rolls pushed past either end by a modifier clamp to the first
#               or last band.
#   B. shown    the inspect roll table prints those ranges, and follows a
#               window changed in memory (nothing on that surface is fixed).
#   C. shifted  Band Compressor, Wide Aperture, Standing Order and the Splice
#               Deal, alone and all together, on every hero and evolution:
#               still five contiguous bands covering 1-20, none emptied, each
#               shift as large as the band it takes from allows.
# scripts/checks/break_gate.py reruns it with each DiceManager
# WINDOWS_BREAK_ARG mode (shared_table, squeeze) and requires a FAIL.
extends SceneTree

const DICE_SOURCE := "res://scripts/battle/dice_manager.gd"
const INSPECT_SOURCE := "res://scripts/ui/inspect_resolver.gd"
const HEROES_PATH := "res://data/raw/heroes.data.json"
const ENEMIES_PATH := "res://data/raw/enemies.data.json"
const BANDS := ["recharge", "strike", "surge", "crit", "overload"]
const STANDING_ORDER := "standingOrder"

var _errors: PackedStringArray = []
var _dice: Object


func _initialize() -> void:
	call_deferred("_run")


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_errors.append(what)


func dm() -> Node:
	return root.get_node("/root/DataManager")


func gs() -> Node:
	return root.get_node("/root/GameState")


func _run() -> void:
	await process_frame
	_dice = load(DICE_SOURCE).new()
	var units: Array = _units()
	_check_loaded(units)
	_check_shown(units)
	_check_shifted(units)
	for error in _errors:
		print("[ROLL_WINDOWS_LIVE] FAIL - %s" % error)
	print("[ROLL_WINDOWS_LIVE] %s (%d units)" % ["PASS" if _errors.is_empty() else "FAIL - %d check(s)" % _errors.size(), units.size()])
	quit(0 if _errors.is_empty() else 1)


func _pairs(abilities: Array) -> Array:
	var out: Array = []
	for ability in abilities:
		var pair: Array = (ability as Dictionary).get("range", [])
		out.append([int(pair[0]), int(pair[1])] if pair.size() == 2 else [])
	return out


func _loaded_pairs(ranges: Array) -> Array:
	var out: Array = []
	for entry in ranges:
		out.append([int((entry as Dictionary).get("min", 0)), int((entry as Dictionary).get("max", 0))])
	return out


# Every unit the game can field: [label, resource the lookups take, the ranges
# its data file gives, is_hero].
func _units() -> Array:
	var out: Array = []
	var heroes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HEROES_PATH))
	for hero in heroes["heroes"]:
		var unit: UnitData = dm().get_unit(str(hero["id"])) as UnitData
		_expect(unit != null, "%s is not loaded" % str(hero["name"]))
		if unit == null:
			continue
		out.append([str(hero["name"]), unit, _pairs(hero["abilities"]), true])
		for evolution in hero["evolutions"]:
			var evolved: UnitData = UnitData.new()
			evolved.id = unit.id
			evolved.display_name = str(evolution["name"])
			for path in unit.evolution_paths:
				if str((path as Dictionary).get("id", "")) == str(evolution["id"]):
					var bands: Array[Dictionary] = []
					for entry in (path as Dictionary).get("abilities", []):
						bands.append((entry as Dictionary).duplicate(true))
					evolved.dice_ranges = bands
			_expect(evolved.dice_ranges.size() == 5, "%s: the loaded evolution has %d bands" % [evolved.display_name, evolved.dice_ranges.size()])
			out.append([evolved.display_name, evolved, _pairs(evolution["abilities"]), true])
	var enemies: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ENEMIES_PATH))
	for enemy_name in enemies["enemyUnitDefs"]:
		var enemy: EnemyData = dm().get_enemy_by_display_name(str(enemy_name)) as EnemyData
		_expect(enemy != null, "%s is not loaded" % str(enemy_name))
		if enemy == null:
			continue
		var suite: Dictionary = enemies["enemyAbilities"][str(enemies["enemyUnitDefs"][enemy_name]["type"])]
		var listed: Array = []
		for band in BANDS:
			listed.append(suite[band])
		out.append([str(enemy_name), enemy, _pairs(listed), false])
	return out


func _five_contiguous(label: String, pairs: Array) -> bool:
	var ok: bool = pairs.size() == 5
	if ok:
		ok = int(pairs[0][0]) == 1 and int(pairs[4][1]) == 20
		for i in 5:
			ok = ok and int(pairs[i][0]) <= int(pairs[i][1])
			if i < 4:
				ok = ok and int(pairs[i + 1][0]) == int(pairs[i][1]) + 1
	_expect(ok, "%s: not five contiguous bands covering 1-20 (%s)" % [label, str(pairs)])
	return ok


# ── A. What the game loads ────────────────────────────────────────────────────
func _check_loaded(units: Array) -> void:
	for row in units:
		var label: String = row[0]
		var unit: Resource = row[1]
		var loaded: Array = _loaded_pairs(unit.dice_ranges)
		_expect(loaded == row[2], "%s: the game loads %s, its data file says %s" % [label, str(loaded), str(row[2])])
		if not _five_contiguous(label, loaded):
			continue
		for face in range(1, 21):
			var entry: Dictionary = _dice.get_ability_for_roll(unit, face)
			var owner: int = -1
			for i in 5:
				if face >= int(loaded[i][0]) and face <= int(loaded[i][1]):
					owner = i
			_expect(str(entry.get("zone", "")) == str(BANDS[owner]), "%s: a %d resolves to band %d's ability (%s)" % [label, face, owner + 1, str(entry.get("ability_name", "none"))])
		# A modifier can push a roll past either end; it clamps to 1 and 20.
		_expect(str(_dice.get_ability_for_roll(unit, -2).get("zone", "")) == str(BANDS[0]), "%s: a roll below 1 uses band 1" % label)
		_expect(str(_dice.get_ability_for_roll(unit, 24).get("zone", "")) == str(BANDS[4]), "%s: a roll above 20 uses the top band" % label)


# ── B. What the inspect shows ─────────────────────────────────────────────────
func _roll_column(unit: Resource) -> Array:
	var out: Array = []
	for ability in load(INSPECT_SOURCE).resolve_unit(unit, {}).get("abilities", []):
		out.append(str((ability as Dictionary).get("roll", "")))
	return out


func _check_shown(units: Array) -> void:
	for row in units:
		var want: Array = []
		for pair in _loaded_pairs((row[1] as Resource).dice_ranges):
			want.append("%d - %d" % [int(pair[0]), int(pair[1])])
		var shown: Array = _roll_column(row[1])
		_expect(shown == want, "%s: the inspect shows %s for ranges %s" % [row[0], str(shown), str(want)])
	# A window nobody authored: the inspect and the lookup both follow it.
	var probe: UnitData = UnitData.new()
	probe.id = "probe"
	probe.display_name = "Probe"
	var odd: Array = [[1, 1], [2, 12], [13, 13], [14, 17], [18, 20]]
	var bands: Array[Dictionary] = []
	for i in 5:
		bands.append({"min": odd[i][0], "max": odd[i][1], "zone": BANDS[i], "ability_name": "Move %d" % (i + 1), "description": "", "raw": {"dmg": i + 1}})
	probe.dice_ranges = bands
	_expect(_roll_column(probe) == ["1 - 1", "2 - 12", "13 - 13", "14 - 17", "18 - 20"], "inspect: an unauthored window is shown as it is (%s)" % str(_roll_column(probe)))
	_expect(str(_dice.get_ability_for_roll(probe, 12).get("ability_name", "")) == "Move 2" and str(_dice.get_ability_for_roll(probe, 18).get("ability_name", "")) == "Move 5", "lookup: an unauthored window is used as it is")


# ── C. Gear and relics that move a band edge ──────────────────────────────────
func _adjusted(unit: Resource, gear: Array, relics: Array, splice: bool) -> Array:
	gs().gear_by_unit = {str(unit.id): gear}
	gs().relics = relics
	gs().hero_run_mods = {str(unit.id): {"splice_bands": true}} if splice else {}
	var out: Array = _loaded_pairs(_dice.get_adjusted_ranges(unit))
	gs().gear_by_unit = {}
	gs().relics = []
	gs().hero_run_mods = {}
	return out


func _width(pair: Array) -> int:
	return int(pair[1]) - int(pair[0]) + 1


func _check_shifted(units: Array) -> void:
	var aperture: int = int((dm().get_item("wide_aperture") as ItemData).effect.get("amount", 0))
	_expect(aperture > 0 and dm().get_item("band_compressor") != null and dm().get_item(STANDING_ORDER) != null, "fixture: the band-shifting gear and relic exist")
	for row in units:
		if not bool(row[3]):
			continue
		var label: String = row[0]
		var unit: Resource = row[1]
		var base: Array = _loaded_pairs(unit.dice_ranges)
		_expect(_adjusted(unit, [], [], false) == base, "%s: no gear, no shift" % label)

		var compressed: Array = _adjusted(unit, ["band_compressor"], [], false)
		if _five_contiguous("%s + Band Compressor" % label, compressed):
			_expect(int(compressed[4][0]) == mini(int(base[4][0]), 19), "%s + Band Compressor: the top band starts at %d (%d)" % [label, mini(int(base[4][0]), 19), int(compressed[4][0])])

		var wide: Array = _adjusted(unit, ["wide_aperture"], [], false)
		if _five_contiguous("%s + Wide Aperture" % label, wide):
			var take: int = mini(aperture, _width(base[1]) - 1)
			_expect(int(wide[2][0]) == int(base[2][0]) - take, "%s + Wide Aperture: band 3 starts %d lower, all band 2 can give (%s)" % [label, take, str(wide)])

		var ordered: Array = _adjusted(unit, [], [STANDING_ORDER], false)
		if _five_contiguous("%s + Standing Order" % label, ordered):
			_expect(int(ordered[3][0]) == int(base[3][0]) - mini(1, _width(base[2]) - 1), "%s + Standing Order: band 4 starts one lower (%s)" % [label, str(ordered)])

		var spliced: Array = _adjusted(unit, [], [], true)
		if _five_contiguous("%s + Splice Deal" % label, spliced):
			_expect(int(spliced[0][1]) == int(base[0][1]) + mini(2, _width(base[1]) - 1), "%s + Splice Deal: band 1 ends %d higher (%s)" % [label, mini(2, _width(base[1]) - 1), str(spliced)])
			_expect(int(spliced[4][0]) == mini(int(base[4][0]), 19), "%s + Splice Deal: the top band takes the 19" % label)

		_five_contiguous("%s + all four" % label, _adjusted(unit, ["band_compressor", "wide_aperture"], [STANDING_ORDER], true))
