# Save-system round-trip gate (G1, G3, G4) + the save-coverage contract.
#
#   godot --headless --path . -s scripts/debug/save_roundtrip_test.gd
#
# G1 ROUND TRIP  — for a seeded run checkpointed at each node type, the cycle
#                  serialize -> deserialize -> serialize returns an IDENTICAL
#                  dict. Anything that drops a field, or that survives JSON as
#                  the wrong type (2 arriving back as 2.0), fails here.
# G3 SAME OFFERS — after a reload the reward draft, the intercept card and the
#                  route-fork modifier are the same ids in the same ORDER.
# G4 64-BIT RNG  — RNG states past 2^53 round-trip exactly. Godot's JSON parses
#                  every number as a double, so an unquoted int64 comes back
#                  rounded AND retyped, silently.
# COVERAGE       — every run-state property on GameState appears in either
#                  SAVED_RUN_FIELDS or TRANSIENT_RUN_FIELDS. A field added to
#                  GameState and forgotten here would present as a corrupt
#                  resume rather than as an error; this makes it a build break.
extends SceneTree

const SaveIO = preload("res://scripts/autoloads/save_io.gd")
const SQUAD := ["pulse", "combat", "shield"]
const OP := "facility"
const SEED := 424242

var _failures: Array[String] = []


## -s rigs have no autoload identifiers at COMPILE time (the scripts are parsed
## before the tree exists), so every other headless test in this directory
## reaches them by path. Same here.
func gs() -> Node:
	return root.get_node("/root/GameState")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_coverage_contract()
	_check_battle_seed_consumes_nothing()
	_check_64bit_rng()
	for node_kind in ["battle", "reward", "fork", "intercept"]:
		_check_round_trip(node_kind)
	_check_same_offers_reward()
	_check_same_offers_intercept()
	_check_same_offers_fork()

	if _failures.is_empty():
		print("[SAVE_ROUNDTRIP] PASS")
		quit(0)
		return  # quit() only REQUESTS the tree shut down; the function runs on
	for failure in _failures:
		push_error("[SAVE_ROUNDTRIP] " + failure)
		print("[SAVE_ROUNDTRIP] FAIL - %s" % failure)
	print("[SAVE_ROUNDTRIP] FAIL - %d check(s)" % _failures.size())
	quit(1)


func _fail(message: String) -> void:
	_failures.append(message)


# ── Coverage contract ─────────────────────────────────────────────────────────

func _check_coverage_contract() -> void:
	var declared: Array = []
	declared.append_array(gs().SAVED_RUN_FIELDS)
	declared.append_array(gs().TRANSIENT_RUN_FIELDS)
	# Everything GameState exposes that is genuinely run state. Constants are
	# not properties; the engine-supplied Node members are filtered by name.
	var ignored := ["script", "owner", "multiplayer", "process_priority",
		"process_physics_priority", "process_mode", "process_thread_group",
		"process_thread_group_order", "process_thread_messages",
		"physics_interpolation_mode", "auto_translate_mode", "editor_description",
		"name", "unique_name_in_owner", "scene_file_path"]
	for entry_variant in gs().get_property_list():
		var entry: Dictionary = entry_variant
		if int(entry.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var field: String = str(entry.get("name", ""))
		if field == "" or ignored.has(field):
			continue
		if not declared.has(field):
			_fail("GameState.%s is in neither SAVED_RUN_FIELDS nor TRANSIENT_RUN_FIELDS - "
				% field + "decide whether a resumed run needs it")
	for field in gs().SAVED_RUN_FIELDS:
		if gs().TRANSIENT_RUN_FIELDS.has(field):
			_fail("GameState.%s is listed as BOTH saved and transient" % field)


# ── The battle seed must not touch the run stream ─────────────────────────────

## The balance baseline depends on GameState._reward_rng producing the same
## sequence it always has. Deriving a per-battle seed must therefore consume
## NOTHING: an earlier version drew it with _reward_rng.randi(), which was safe
## only because the sim happens not to run battle_scene — the first seeded path
## that called it would have shifted every downstream reward, beat and intercept
## roll and moved the baseline for a non-balance reason. This makes that
## structural instead of positional.
func _check_battle_seed_consumes_nothing() -> void:
	gs().start_run(SQUAD, OP, SEED)
	gs().advance_to_next_battle()
	var state_before: int = gs().get_reward_rng_state()
	var draws_before: Array = []
	for _i in 5:
		draws_before.append(gs()._reward_rng.randi())

	# Same seeded run again, but derive a battle seed at every battle first.
	gs().start_run(SQUAD, OP, SEED)
	gs().advance_to_next_battle()
	for battle in range(1, 11):
		gs().current_battle = battle
		gs().derive_battle_rng_seed()
	gs().current_battle = 1
	if gs().get_reward_rng_state() != state_before:
		_fail("deriving battle seeds MOVED the run RNG state (%d -> %d) - every "
			% [state_before, gs().get_reward_rng_state()]
			+ "downstream reward/beat/intercept roll shifts and the balance baseline moves")
	var draws_after: Array = []
	for _i in 5:
		draws_after.append(gs()._reward_rng.randi())
	_expect_same(draws_before, draws_after, "run RNG sequence after deriving battle seeds")

	# And the derivation still has to be useful: distinct per battle, stable,
	# and reproducible from the saved run seed alone.
	var seeds: Dictionary = {}
	for battle in range(1, 11):
		gs().current_battle = battle
		seeds[battle] = gs().derive_battle_rng_seed()
	var distinct: Array = []
	for battle in seeds:
		if not distinct.has(seeds[battle]):
			distinct.append(seeds[battle])
	if distinct.size() != seeds.size():
		_fail("battle seeds collide across battles (%d distinct of %d)" % [distinct.size(), seeds.size()])
	for battle in seeds:
		gs().current_battle = int(battle)
		if gs().derive_battle_rng_seed() != seeds[battle]:
			_fail("battle seed for battle %d is not stable across calls" % int(battle))


# ── G4: 64-bit values ─────────────────────────────────────────────────────────

func _check_64bit_rng() -> void:
	# Real RNG states plus the boundary where doubles start lying, both signs.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234567890123456789
	rng.randi()
	var cases: Array[int] = [
		int(rng.state),
		9007199254740993,           # 2^53 + 1 — the first integer a double cannot hold
		9223372036854775807,        # int64 max
		-9223372036854775807,
		-4442648289396466586,       # a measured RandomNumberGenerator.state
		0, 1, -1,
	]
	for value in cases:
		# Through the ACTUAL file path, not just the codec: the point is that the
		# value survives JSON.stringify + JSON.parse_string, which is where it dies.
		var payload: Dictionary = {"state": SaveIO.encode_i64(value)}
		var parsed: Variant = JSON.parse_string(JSON.stringify(payload))
		var restored: int = SaveIO.decode_i64((parsed as Dictionary).get("state", ""))
		if restored != value:
			_fail("64-bit round trip lost %d (got %d)" % [value, restored])
		# And prove the naive form really does corrupt it, so this gate is
		# testing something real rather than restating an assumption.
		if absi(value) > 9007199254740992:
			var naive: Variant = JSON.parse_string(JSON.stringify({"state": value}))
			if int((naive as Dictionary).get("state", 0)) == value:
				_fail("unquoted %d survived JSON - the string encoding is no longer load-bearing" % value)
	# The live path: a run RNG state, saved and restored through gs().
	gs().start_run(SQUAD, OP, SEED)
	for _i in 7:
		gs()._reward_rng.randi()
	var expected: int = gs().get_reward_rng_state()
	var dict: Dictionary = gs().to_save_dict()
	var via_json: Variant = JSON.parse_string(JSON.stringify(dict))
	gs().set_reward_rng_state(0)
	gs().load_from_dict(via_json as Dictionary)
	if gs().get_reward_rng_state() != expected:
		_fail("reward RNG state did not survive the save (%d -> %d)"
			% [expected, gs().get_reward_rng_state()])


# ── G1: round trip at each node type ──────────────────────────────────────────

func _check_round_trip(node_kind: String) -> void:
	_build_run_at(node_kind)
	# Pass 1: through JSON, exactly as SaveIO writes and reads it.
	var first: Dictionary = JSON.parse_string(JSON.stringify(gs().to_save_dict())) as Dictionary
	gs().load_from_dict(first)
	# Pass 2: re-serialize the restored state and compare.
	var second: Dictionary = JSON.parse_string(JSON.stringify(gs().to_save_dict())) as Dictionary
	var diffs: Array[String] = []
	_diff(first, second, "", diffs)
	if not diffs.is_empty():
		_fail("%s checkpoint is not round-trip stable: %s" % [node_kind, ", ".join(diffs)])


## Builds a seeded run parked at the given node type, with enough state touched
## that an omission has something to lose: gear, consumables, XP, a fork
## modifier, an intercept draw, cross-battle death memory.
func _build_run_at(node_kind: String) -> void:
	gs().start_run(SQUAD, OP, SEED)
	gs().advance_to_next_battle()
	gs().derive_battle_rng_seed()
	# Non-default values in fields a lazy save would skip.
	gs().carried_protocol = 3
	gs().unit_xp["combat"] = 140
	gs().unit_levels["combat"] = 2
	gs().hero_run_mods["pulse"] = {"roll_bonus": 2, "start_cloaked": true}
	gs().next_battle_effects = {"protocol": 4, "items_free": true}
	gs().followup_battle_effects = {"enemy_hp_pct": 80}
	gs().record_battle_hero_deaths(["shield"])
	gs().record_battle_turns(6)
	gs().run_protocol_per_battle = 1
	match node_kind:
		"battle":
			pass
		"reward":
			gs().prepare_battle_rewards()
		"fork":
			# Spend one modifier first: the fork's no-repeat rule lives in
			# used_battle_modifiers, and an empty ledger asserts nothing about
			# whether the save carries it.
			var first: String = gs().roll_route_modifier()
			if first != "":
				gs().accept_flagged_route(first)
			gs().next_battle_modifier = ""
			gs().roll_route_modifier()
		"intercept":
			var card_id: String = gs().draw_intercept_card("minor")
			if card_id == "":
				_fail("intercept deck drew nothing - the fixture is not exercising the node")
				return
			gs().begin_intercept_state(card_id)


## Content comparison with a readable first difference.
func _expect_same(before: Variant, after: Variant, label: String) -> void:
	var diffs: Array[String] = []
	_diff(before, after, "", diffs)
	if not diffs.is_empty():
		_fail("%s changed across a reload: %s" % [label, ", ".join(diffs)])


func _diff(a: Variant, b: Variant, path: String, out: Array[String]) -> void:
	if out.size() > 6:
		return
	if typeof(a) != typeof(b):
		out.append("%s type %d != %d" % [path, typeof(a), typeof(b)])
		return
	if a is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		for key in da:
			if not db.has(key):
				out.append("%s/%s missing after reload" % [path, key])
				continue
			_diff(da[key], db[key], "%s/%s" % [path, key], out)
		for key in db:
			if not da.has(key):
				out.append("%s/%s appeared after reload" % [path, key])
		return
	if a is Array:
		var aa: Array = a
		var ab: Array = b
		if aa.size() != ab.size():
			out.append("%s size %d != %d" % [path, aa.size(), ab.size()])
			return
		for i in aa.size():
			_diff(aa[i], ab[i], "%s[%d]" % [path, i], out)
		return
	if a != b:
		out.append("%s %s != %s" % [path, str(a), str(b)])


# ── G3: the same offers, in the same order ────────────────────────────────────

func _check_same_offers_reward() -> void:
	_build_run_at("reward")
	var offered: Array = gs().pending_reward_item_ids.duplicate()
	if offered.is_empty():
		_fail("reward fixture produced no offers")
		return
	var restored: Array = _reload().pending_reward_item_ids
	# Arrays compare index by index, so ORDER is part of the assertion: the cards
	# must come back in the same sequence, not merely as the same set.
	_expect_same(offered, restored, "reward offers")
	# The re-entry guard is what protects this in the real screen: with the ids
	# restored, RewardScreen._ready must NOT call prepare_battle_rewards again.
	# Simulate the guard's condition rather than booting the scene.
	if gs().pending_reward_item_ids.is_empty():
		_fail("restored reward ids are empty, so the screen guard would re-roll the draft")


func _check_same_offers_intercept() -> void:
	_build_run_at("intercept")
	var card_id: String = str(gs().pending_intercept_state.get("card_id", ""))
	var minor_deck: Array = gs().intercept_minor_deck.duplicate()
	var restored: Node = _reload()
	if str(restored.pending_intercept_state.get("card_id", "")) != card_id:
		_fail("intercept card changed across a reload: %s -> %s"
			% [card_id, str(restored.pending_intercept_state.get("card_id", ""))])
	# The deck matters as much as the card: a deck that reshuffles on reload
	# would hand out the same event twice later in the run.
	_expect_same(minor_deck, restored.intercept_minor_deck, "intercept deck order")
	var choices: Array = (gs().INTERCEPT_CARDS.get(card_id, {}) as Dictionary).get("choices", [])
	var after: Array = (gs().INTERCEPT_CARDS.get(
		str(restored.pending_intercept_state.get("card_id", "")), {}) as Dictionary).get("choices", [])
	if choices.size() != after.size():
		_fail("intercept choice count changed across a reload")


func _check_same_offers_fork() -> void:
	_build_run_at("fork")
	var modifier: String = gs().pending_flagged_modifier_id
	var comp: Dictionary = gs().pending_flagged_comp.duplicate(true)
	# Captured BEFORE the reload and by VALUE. _reload() returns the same
	# GameState object, so reading this field afterwards would compare the list
	# to itself and pass no matter what the save did with it.
	var used_before: Array = gs().used_battle_modifiers.duplicate()
	if modifier == "":
		_fail("fork fixture rolled no modifier")
		return
	if used_before.is_empty():
		_fail("fork fixture left used_battle_modifiers empty - the no-repeat ledger is not under test")
		return
	var restored: Node = _reload()
	if restored.pending_flagged_modifier_id != modifier:
		_fail("fork modifier changed across a reload: %s -> %s"
			% [modifier, restored.pending_flagged_modifier_id])
	# Compared by CONTENT, not by str(): JSON.stringify sorts object keys, so a
	# dict comes back canonically ordered. Key order is not load-bearing here
	# (every consumer uses .get); array order is, and _diff checks that by index.
	_expect_same(comp, restored.pending_flagged_comp, "fork previewed comp")
	# The used-modifier ledger has to survive too, or the no-repeats rule resets
	# and the run can be offered the same modifier twice.
	_expect_same(used_before, restored.used_battle_modifiers, "used_battle_modifiers")


## Serializes the current run, wipes GameState, and loads it back — the closest
## in-process stand-in for a relaunch. (A genuinely fresh process is what the
## resume-determinism gate does; this one is about content identity.)
func _reload() -> Node:
	var saved: Variant = JSON.parse_string(JSON.stringify(gs().to_save_dict()))
	gs().reset_run()
	gs().load_from_dict(saved as Dictionary)
	return gs()
