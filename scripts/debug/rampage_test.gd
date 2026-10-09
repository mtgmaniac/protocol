# Rampage and pack bonus gate (G-60, Kev 2026-10-09).
#
#   godot --headless --path . -s scripts/debug/rampage_test.gd [-- --rampage-break=stack]
#
# Rampage used to be a pile of charges: every grant added one and each sat
# until an attack spent it. Now it is on or off, it lasts until the unit's next
# turn, and that turn spends it whether or not it attacks. Pack bonus went from
# +1 to +3 per other living pack member of the same kind.
# Pinned here:
#   A. duration  an attack on the next turn deals double and ends it; a turn
#                that does not attack ends it too (the hit after is plain); a
#                rampage granted during a turn is for the turn after; a turn
#                wasted on the decoy spends it; a unit that takes no turn keeps
#                it.
#   B. stacking  two grants are one rampage (one chip event, one doubled hit);
#                an all-allies grant leaves a rampaging ally at one; an attack
#                that grants to all allies leaves the attacker rampaging once.
#   C. pack      the bonus per member, same kind only, the living only; the
#                ability text, the keyword and the primer print that number.
#   D. copy      the keyword says it does not stack; the chip leaves on the
#                beat a rampage ends unused.
# scripts/checks/break_gate.py reruns it with each CombatManager
# RAMPAGE_BREAK_ARG mode (stack, keep, pack_one) and requires a FAIL.
extends SceneTree

const COMBAT_SOURCE := "res://scripts/battle/combat_manager.gd"
const DICE_SOURCE := "res://scripts/battle/dice_manager.gd"
const SEEDED_SOURCE := "res://scripts/sim/seeded_roll_provider.gd"
const FEEDBACK_SOURCE := "res://scripts/battle/battle_feedback.gd"
const KEYWORDS_PATH := "res://data/raw/keywords.data.json"
const PRIMERS_PATH := "res://data/raw/primers.data.json"
const ENEMIES_PATH := "res://data/raw/enemies.data.json"
# Rolls for the two-ability test enemy: LOW fires its first ability, HIGH its second.
const LOW := 5
const HIGH := 15

var _errors: PackedStringArray = []
var _dice: Object


func _initialize() -> void:
	call_deferred("_run")


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_errors.append(what)


func _run() -> void:
	await process_frame
	_dice = load(DICE_SOURCE).new()
	_check_duration()
	_check_stacking()
	_check_pack()
	_check_copy()
	for error in _errors:
		print("[RAMPAGE] FAIL - %s" % error)
	print("[RAMPAGE] %s" % ("PASS" if _errors.is_empty() else "FAIL - %d check(s)" % _errors.size()))
	quit(0 if _errors.is_empty() else 1)


# ── Fixtures ──────────────────────────────────────────────────────────────────
func _band(lo: int, hi: int, ability_name: String, raw: Dictionary) -> Dictionary:
	return {"min": lo, "max": hi, "zone": "audit", "ability_name": ability_name, "description": "", "raw": raw.duplicate(true)}


func _hero(id: String) -> UnitData:
	var unit: UnitData = UnitData.new()
	unit.id = id
	unit.display_name = "Hero %s" % id
	unit.max_hp = 500
	unit.dice_ranges = [_band(1, 20, "Wait", {})]
	return unit


# An enemy with two abilities: `low` on 1-10, `high` on 11-20.
func _enemy(id: String, low: Dictionary, high: Dictionary, kind: String = "test") -> EnemyData:
	var enemy: EnemyData = EnemyData.new()
	enemy.id = id
	enemy.display_name = "Enemy %s" % id
	enemy.enemy_type = kind
	enemy.max_hp = 100
	enemy.dice_ranges = [_band(1, 10, "Low Move", low), _band(11, 20, "High Move", high)]
	return enemy


func _battle(enemies: Array) -> Object:
	var cm: Object = load(COMBAT_SOURCE).new()
	cm.roll_provider = load(SEEDED_SOURCE).new(1)
	cm.setup_battle([_hero("a")], enemies)
	return cm


# One enemy phase: `rolls` is {enemy index: roll}. Returns the round's events.
func _enemy_round(cm: Object, rolls: Dictionary) -> Array:
	var enemy_rolls: Dictionary = {}
	for index in rolls:
		enemy_rolls[str(cm.get_enemy_states()[int(index)]["id"])] = int(rolls[index])
	return cm.resolve_round({}, enemy_rolls, _dice)["events"]


func _count(events: Array, type: String) -> int:
	var total: int = 0
	for event in events:
		if str((event as Dictionary).get("type", "")) == type:
			total += 1
	return total


func _hp_lost(cm: Object, before: int) -> int:
	return before - int(cm.get_hero_states()[0]["current_hp"])


func _hero_hp(cm: Object) -> int:
	return int(cm.get_hero_states()[0]["current_hp"])


func _rampaging(state: Dictionary) -> int:
	return int(state.get("rampage_charges", 0))


# ── A. It lasts until the unit's next turn ────────────────────────────────────
func _check_duration() -> void:
	# Low = 6 shield (no attack), high = 10 damage.
	var cm: Object = _battle([_enemy("x", {"shield": 6}, {"dmg": 10})])
	var foe: Dictionary = cm.get_enemy_states()[0]
	_expect(cm._grant_rampage(foe), "a grant to a unit without rampage lands")
	var hp: int = _hero_hp(cm)
	var events: Array = _enemy_round(cm, {0: HIGH})
	_expect(_hp_lost(cm, hp) == 20, "an attack on the next turn deals double: 20 (%d)" % _hp_lost(cm, hp))
	_expect(_rampaging(foe) == 0, "the attack ends the rampage")
	_expect(_count(events, "rampage") == 1 and _count(events, "rampage_end") == 0, "a spent rampage reports `rampage`, not `rampage_end`")
	hp = _hero_hp(cm)
	_enemy_round(cm, {0: HIGH})
	_expect(_hp_lost(cm, hp) == 10, "the attack after is a plain 10 (%d)" % _hp_lost(cm, hp))

	# A turn that does not attack ends it.
	cm = _battle([_enemy("x", {"shield": 6}, {"dmg": 10})])
	foe = cm.get_enemy_states()[0]
	cm._grant_rampage(foe)
	events = _enemy_round(cm, {0: LOW})
	_expect(_rampaging(foe) == 0, "a turn that does not attack ends the rampage (%d left)" % _rampaging(foe))
	_expect(_count(events, "rampage_end") == 1, "the unused end is reported once (`rampage_end` x%d)" % _count(events, "rampage_end"))
	hp = _hero_hp(cm)
	_enemy_round(cm, {0: HIGH})
	_expect(_hp_lost(cm, hp) == 10, "after an unused rampage the next attack is a plain 10 (%d)" % _hp_lost(cm, hp))

	# Granted during its own turn: it is for the turn after.
	cm = _battle([_enemy("x", {"shield": 6, "grantRampage": 1}, {"dmg": 10})])
	foe = cm.get_enemy_states()[0]
	events = _enemy_round(cm, {0: LOW})
	_expect(_rampaging(foe) == 1, "a rampage granted during a turn is still up after it")
	_expect(_count(events, "rampage_up") == 1 and _count(events, "rampage_end") == 0, "the granting turn reports the grant and no end")
	hp = _hero_hp(cm)
	_enemy_round(cm, {0: HIGH})
	_expect(_hp_lost(cm, hp) == 20 and _rampaging(foe) == 0, "the turn after the grant deals double and ends it (%d, %d left)" % [_hp_lost(cm, hp), _rampaging(foe)])

	# Rampaging, and the turn grants again without attacking: still one, no end.
	cm = _battle([_enemy("x", {"shield": 6, "grantRampage": 1}, {"dmg": 10})])
	foe = cm.get_enemy_states()[0]
	cm._grant_rampage(foe)
	events = _enemy_round(cm, {0: LOW})
	_expect(_rampaging(foe) == 1 and _count(events, "rampage_end") == 0, "a turn that grants itself rampage again keeps one rampage")

	# A turn wasted on the decoy spends it.
	cm = _battle([_enemy("x", {"shield": 6}, {"dmg": 10})])
	foe = cm.get_enemy_states()[0]
	cm.set_decoy_round_one()
	cm._grant_rampage(foe)
	hp = _hero_hp(cm)
	events = _enemy_round(cm, {0: HIGH})
	_expect(_hp_lost(cm, hp) == 0 and _rampaging(foe) == 0, "a turn wasted on the decoy spends the rampage (%d left)" % _rampaging(foe))
	_expect(_count(events, "rampage_end") == 1, "the decoy turn reports the end")

	# No turn (no die this round): it waits.
	cm = _battle([_enemy("x", {"shield": 6}, {"dmg": 10}), _enemy("y", {"shield": 6}, {"dmg": 10})])
	foe = cm.get_enemy_states()[0]
	cm._grant_rampage(foe)
	_enemy_round(cm, {1: LOW})
	_expect(_rampaging(foe) == 1, "a unit that takes no turn keeps its rampage")


# ── B. It does not stack ──────────────────────────────────────────────────────
func _check_stacking() -> void:
	var cm: Object = _battle([_enemy("x", {"shield": 6}, {"dmg": 10})])
	var foe: Dictionary = cm.get_enemy_states()[0]
	_expect(cm._grant_rampage(foe), "the first grant lands")
	_expect(not cm._grant_rampage(foe), "a second grant to a rampaging unit is refused")
	_expect(_rampaging(foe) == 1, "two grants are one rampage (%d)" % _rampaging(foe))
	var hp: int = _hero_hp(cm)
	_enemy_round(cm, {0: HIGH})
	_expect(_hp_lost(cm, hp) == 20, "two grants still deal double, not more (%d)" % _hp_lost(cm, hp))
	hp = _hero_hp(cm)
	_enemy_round(cm, {0: HIGH})
	_expect(_hp_lost(cm, hp) == 10, "two grants pay for one attack: the second is a plain 10 (%d)" % _hp_lost(cm, hp))

	# An all-allies grant on a rampaging ally: still one, and no second chip event.
	cm = _battle([_enemy("x", {"shield": 6}, {"dmg": 10}), _enemy("boss", {"grantRampageAll": 1}, {"dmg": 10, "grantRampageAll": 1})])
	foe = cm.get_enemy_states()[0]
	var boss: Dictionary = cm.get_enemy_states()[1]
	cm._grant_rampage(foe)
	var events: Array = _enemy_round(cm, {1: LOW})
	_expect(_rampaging(foe) == 1 and _rampaging(boss) == 1, "an all-allies grant leaves everyone at one rampage (%d, %d)" % [_rampaging(foe), _rampaging(boss)])
	_expect(_count(events, "rampage_up") == 1, "only the unit that gained it reports a grant (%d)" % _count(events, "rampage_up"))

	# An attack that also grants to all allies: the hit is doubled once and the
	# attacker is left with one fresh rampage.
	hp = _hero_hp(cm)
	events = _enemy_round(cm, {1: HIGH})
	_expect(_hp_lost(cm, hp) == 20, "a rampaging attack that grants again deals double (%d)" % _hp_lost(cm, hp))
	_expect(_rampaging(boss) == 1, "and leaves the attacker with one rampage (%d)" % _rampaging(boss))
	_expect(_count(events, "rampage") == 1 and _count(events, "rampage_end") == 0, "the doubled hit is reported, with no unused end")


# ── C. Pack bonus ─────────────────────────────────────────────────────────────
func _check_pack() -> void:
	var per: int = int(load(COMBAT_SOURCE).PACK_BONUS_PER_MEMBER)
	_expect(per == 3, "the pack bonus is 3 per other pack member (%d)" % per)
	var pack_move: Dictionary = {"dmg": 6, "packBonus": true}
	var cm: Object = _battle([_enemy("a", pack_move, pack_move, "wolf"), _enemy("b", pack_move, pack_move, "wolf"), _enemy("c", pack_move, pack_move, "wolf")])
	var hp: int = _hero_hp(cm)
	_enemy_round(cm, {0: LOW})
	_expect(_hp_lost(cm, hp) == 6 + 2 * per, "two packmates: 6 + %d (%d)" % [2 * per, _hp_lost(cm, hp)])
	cm.get_enemy_states()[2]["dead"] = true
	hp = _hero_hp(cm)
	_enemy_round(cm, {0: LOW})
	_expect(_hp_lost(cm, hp) == 6 + per, "one packmate down: 6 + %d (%d)" % [per, _hp_lost(cm, hp)])
	cm = _battle([_enemy("a", pack_move, pack_move, "wolf"), _enemy("b", pack_move, pack_move, "monkey")])
	hp = _hero_hp(cm)
	_enemy_round(cm, {0: LOW})
	_expect(_hp_lost(cm, hp) == 6, "another kind is not a packmate: a plain 6 (%d)" % _hp_lost(cm, hp))

	# Every printed copy of the number.
	var printed: String = "+%d damage per other pack member" % per
	var ability_copies: int = 0
	var suites: Dictionary = (_json(ENEMIES_PATH) as Dictionary).get("enemyAbilities", {})
	for suite in suites.values():
		for ability in (suite as Dictionary).values():
			if bool((ability as Dictionary).get("packBonus", false)):
				ability_copies += 1
				_expect(str(ability["eff"]).contains(printed), "ability text '%s' prints '%s'" % [str(ability["eff"]), printed])
	_expect(ability_copies >= 3, "the data has its pack bonus abilities (%d)" % ability_copies)
	_expect(_keyword_def("pack_bonus").contains("+%d for each other" % per), "the keyword prints +%d (%s)" % [per, _keyword_def("pack_bonus")])
	_expect(_primer_text("primer_pack_bonus").contains("+%d damage" % per), "the primer prints +%d (%s)" % [per, _primer_text("primer_pack_bonus")])


# ── D. Copy and the chip ──────────────────────────────────────────────────────
func _check_copy() -> void:
	var definition: String = _keyword_def("rampage")
	_expect(definition.contains("does not stack") and definition.contains("next turn"), "the keyword says next turn and no stacking (%s)" % definition)
	_expect(not definition.contains("charge") and not _primer_text("primer_rampage").contains("charge"), "no copy talks about charges")
	var chips: Dictionary = load(FEEDBACK_SOURCE).STATUS_EVENT_CHIP
	_expect((chips.get("rampage_end", []) as Array).has("rampage"), "the rampage chip leaves on the beat a rampage ends unused")


func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _keyword_def(id: String) -> String:
	for entry in (_json(KEYWORDS_PATH) as Dictionary).get("keywords", []):
		if str((entry as Dictionary).get("id", "")) == id:
			return str(entry["def"])
	return ""


func _primer_text(id: String) -> String:
	for entry in (_json(PRIMERS_PATH) as Dictionary).get("primers", []):
		if str((entry as Dictionary).get("id", "")) == id:
			return str(entry["text"])
	return ""
