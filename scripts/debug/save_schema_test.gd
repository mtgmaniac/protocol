# Run-save schema fingerprint gate.
#
#   godot --headless --path . -s scripts/debug/save_schema_test.gd
#
# Hashes the SHAPE of a real checkpoint — every key name and value type,
# recursively, never the values — and compares it to the fingerprint pinned
# beside SaveManager.RUN_SAVE_VERSION.
#
# WHY: a save format drifts one field at a time. Each individual change looks
# harmless, nobody bumps the version, and then a build ships that writes a
# shape older builds half-read: the version says "compatible", the payload is
# not, and the failure surfaces as a corrupt resume on a player's phone rather
# than as a red gate here. This makes the drift itself the build break.
#
# The fixture is deliberately RICH — gear, consumables, XP, a fork modifier, an
# intercept draw, cross-battle death memory — because a field that is empty in
# the fixture contributes "[]" (shape unknown) and would hide a change to its
# element shape. Array LENGTH is excluded on purpose: it is data, not schema.
extends SceneTree

const SaveIO = preload("res://scripts/autoloads/save_io.gd")
const SQUAD := ["pulse", "combat", "shield"]
const OP := "facility"
const SEED := 20260915

var _failures: Array[String] = []


## One place that knows the ID-keyed declaration, so no call site can forget it.
func _fp(value: Variant) -> String:
	return SaveIO.structure_fingerprint(value, gs().ID_KEYED_RUN_FIELDS)


func gs() -> Node:
	return root.get_node("/root/GameState")


func sm() -> Node:
	return root.get_node("/root/SaveManager")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var payload: Dictionary = _build_checkpoint()
	var fingerprint: String = _fp(payload)
	var pinned: String = str(sm().RUN_SAVE_SCHEMA_FINGERPRINT)

	if fingerprint != pinned:
		_failures.append(
			"the run save's key/type structure is %s but RUN_SAVE_VERSION %d pins %s.\n"
			% [fingerprint, int(sm().RUN_SAVE_VERSION), pinned]
			+ "        A field was added, removed or retyped in to_save_dict().\n"
			+ "        Bump SaveManager.RUN_SAVE_VERSION and decide the migration\n"
			+ "        (run.json discards on mismatch; save.json must never), then\n"
			+ "        set RUN_SAVE_SCHEMA_FINGERPRINT to the value above.\n"
			+ "        Structure was:\n        %s" % SaveIO.structure_of(payload))

	_check_fingerprint_ignores_values(payload)
	_check_fingerprint_ignores_id_keys(payload)
	_check_every_container_is_populated(payload)
	_check_fingerprint_catches_shape()

	if _failures.is_empty():
		print("[SAVE_SCHEMA] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[SAVE_SCHEMA] " + failure)
		print("[SAVE_SCHEMA] FAIL - %s" % failure)
	quit(1)


## A real checkpoint through the real path, with as much of the run populated as
## the fixture can reach.
func _build_checkpoint(squad: Array = SQUAD) -> Dictionary:
	sm().clear_run_save()
	gs().reset_run()
	gs().start_run(squad, OP, SEED)
	gs().advance_to_next_battle()
	gs().derive_battle_rng_seed()
	gs().carried_protocol = 3
	# Keyed off the actual squad so a different squad produces the same SHAPE.
	var lead: String = str(squad[0])
	var second: String = str(squad[1])
	gs().unit_xp[lead] = 140
	gs().unit_levels[lead] = 2
	gs().unit_evolutions[lead] = "Vanguard"
	gs().unit_directives[lead] = "Entrench"
	gs().gear_by_unit[lead] = ["predator_lens"]
	gs().equipped_gear[lead] = ["predator_lens"]
	gs().consumables.append("field_patch")
	gs().hero_run_mods[second] = {"roll_bonus": 2, "start_cloaked": true}
	gs().next_battle_effects = {"protocol": 4, "items_free": true}
	gs().followup_battle_effects = {"enemy_hp_pct": 80}
	# Every array that would otherwise be EMPTY. An empty array fingerprints as
	# "[]" — element shape unknown — so leaving one empty hides changes to what
	# it holds, and makes the gate fire later when ordinary play first fills it.
	gs().relics.append("salvageRig")
	gs().deferred_evolution_unit_ids.append(lead)
	gs().consumed_beats.append(2)
	# Twice: the first call shifts into deaths_prev_battle, so both are non-empty.
	gs().record_battle_hero_deaths([str(squad[2])])
	gs().record_battle_hero_deaths([second])
	gs().record_battle_turns(6)
	gs().prepare_battle_rewards()
	var first: String = gs().roll_route_modifier()
	if first != "":
		gs().accept_flagged_route(first)
	gs().next_battle_modifier = ""
	gs().roll_route_modifier()
	var card_id: String = gs().draw_intercept_card("minor")
	if card_id != "":
		gs().begin_intercept_state(card_id)
	# pending_choice_request is only populated mid intercept draft; without this
	# it stays {} and its shape is unpinned.
	gs().begin_intercept_item_request("consumable", "SALVAGE", ["field_patch"])
	# Checkpoint for real (so the fixture proves a write actually succeeds), then
	# fingerprint the IN-MEMORY payload from the same builder checkpoint_run uses.
	# Hashing what came back off disk would fingerprint the wire format instead,
	# where every number is a double — an int retyped to float would be invisible.
	sm().checkpoint_run("reward")
	if sm().peek_run_save().is_empty():
		_failures.append("fixture: no checkpoint was written, so nothing is under test")
	# A representative `extra`: the harness parks its two seeded stream states
	# there, and {} would leave the block's shape unpinned.
	var payload: Dictionary = sm().build_run_payload("reward",
		{"provider_state": "0", "policy_rng_state": "0"})
	sm().clear_run_save()
	return payload


## The fingerprint must be blind to VALUES, or it fires on ordinary play: a
## different reward roll, a longer relic list, a different seed.
func _check_fingerprint_ignores_values(payload: Dictionary) -> void:
	var before: String = _fp(payload)
	var mutated: Dictionary = payload.duplicate(true)
	mutated["saved_at"] = "1999-01-01T00:00:00"
	mutated["screen"] = "intercept"
	# NOT save_seq: SaveIO stamps that at write time, so it is not part of the
	# schema SaveManager owns and adding it here would be a shape change, not a
	# value change. Its own rules are covered by the conflict-resolution gate.
	var run_block: Dictionary = mutated["run"]
	run_block["carried_protocol"] = 9
	run_block["reward_rng_state"] = "123456789"
	# Lengthen arrays by DUPLICATING an existing element. Appending something
	# new to an EMPTY array would change "[]" into "[String]", which is a shape
	# change under this encoding, not a value change — that is the encoding
	# behaving correctly, and asserting otherwise would be testing the wrong rule.
	for key in ["relics", "consumables", "selected_units", "pending_reward_item_ids"]:
		var list: Array = run_block[key]
		if list.is_empty():
			_failures.append("fixture: run.%s is empty, so its element shape is unpinned" % str(key))
			continue
		list.append(list[0])
	if _fp(mutated) != before:
		_failures.append("the fingerprint moved when only VALUES changed - it would "
			+ "fire on ordinary play instead of on schema changes")


## Dictionaries keyed by unit/item ids or battle numbers must fingerprint the
## same when the ids change. Two ways: a targeted key rename on the produced
## payload (precise), and a genuine second fixture with a different squad
## (end-to-end — it also catches an ID-keyed field nobody declared).
func _check_fingerprint_ignores_id_keys(payload: Dictionary) -> void:
	var before: String = _fp(payload)
	var renamed: Dictionary = payload.duplicate(true)
	var run_block: Dictionary = renamed["run"]
	var touched: int = 0
	for field in gs().ID_KEYED_RUN_FIELDS:
		if not (run_block.get(field) is Dictionary):
			continue
		var source: Dictionary = run_block[field]
		if source.is_empty():
			_failures.append("fixture: run.%s is empty, so its ID-keyed shape is unpinned" % str(field))
			continue
		var swapped: Dictionary = {}
		for key in source:
			swapped["renamed_%s" % str(key)] = source[key]
		run_block[field] = swapped
		touched += 1
	if touched == 0:
		_failures.append("fixture: no ID-keyed dictionary was populated, so nothing is under test")
	if _fp(renamed) != before:
		_failures.append("the fingerprint moved when only ID-keyed DICT KEYS changed - "
			+ "swapping a hero in the squad would read as a schema change")

	# End to end: the same run with a different squad.
	var other: Dictionary = _build_checkpoint(["medic", "ghost", "breaker"])
	if _fp(other) != before:
		_failures.append("the fingerprint moved for a different SQUAD (%s vs %s) - some "
			% [_fp(other), before]
			+ "dictionary keyed by unit id is missing from ID_KEYED_RUN_FIELDS.
        %s"
			% SaveIO.structure_of(other, gs().ID_KEYED_RUN_FIELDS))


## Every container the run save carries must be non-empty in the fixture. An
## empty array fingerprints as "[]", an empty ID-keyed map as "<>", an empty
## struct as "{}" — all three mean "shape unknown", so an unpopulated field
## pins nothing and the gate would first fire during ordinary play, when
## something finally filled it.
func _check_every_container_is_populated(payload: Dictionary) -> void:
	var run_block: Dictionary = payload.get("run", {})
	for field in run_block:
		var value: Variant = run_block[field]
		var empty: bool = (value is Array and (value as Array).is_empty()) 			or (value is Dictionary and (value as Dictionary).is_empty())
		if empty:
			_failures.append("fixture: run.%s is an empty container, so its shape is unpinned"
				% str(field))
	if (payload.get("extra", {}) as Dictionary).is_empty():
		_failures.append("fixture: the envelope's `extra` block is empty, so its shape is unpinned")


## And it must NOT be blind to shape, or it can never fail.
func _check_fingerprint_catches_shape(  ) -> void:
	var base: Dictionary = {"a": 1, "b": ["x"], "c": {"d": true}}
	var added: Dictionary = {"a": 1, "b": ["x"], "c": {"d": true}, "e": 0}
	var removed: Dictionary = {"a": 1, "b": ["x"]}
	var retyped: Dictionary = {"a": "1", "b": ["x"], "c": {"d": true}}
	var nested: Dictionary = {"a": 1, "b": [0], "c": {"d": true}}
	var renamed: Dictionary = {"a": 1, "b": ["x"], "c": {"D": true}}
	var reference: String = SaveIO.structure_fingerprint(base)
	for case in [["added key", added], ["removed key", removed], ["retyped value", retyped],
				 ["retyped array element", nested], ["renamed nested key", renamed]]:
		if SaveIO.structure_fingerprint(case[1]) == reference:
			_failures.append("the fingerprint is blind to a %s - it cannot fail" % str(case[0]))
	# Array length is data, not shape.
	if SaveIO.structure_fingerprint({"a": 1, "b": ["x", "y", "z"], "c": {"d": true}}) != reference:
		_failures.append("the fingerprint moved on array LENGTH - it would fire on ordinary play")
