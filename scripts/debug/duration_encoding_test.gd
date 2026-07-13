# Duration-encoding regression (Kev 2026-07-13): a duration field stores N
# EFFECTIVE turns — the status is present for exactly N turns and absent on turn
# N+1 — parameterized across every tick-based family, respecting each family's
# application timing. Drives the real CombatManager tick.
#
#   • roll-buff FUTURE (enemy self-buff / reactive): applied after the
#     beneficiary's roll is spent, so it skips the cast-round tick and its N
#     turns are all future rolls. FAILS on the current tick order (which
#     decremented on the cast round, eating one — the erbT bug).
#   • roll-buff CURRENT (items): fed into get_effective_roll before commit, so
#     the cast round counts; no skip. THE ITEM GUARD — a turns=1 item grants
#     exactly ONE roll, not two; a blanket skip would over-correct it and this
#     case would fail.
#   • rfe debuff / burn: already skip-flagged (N=N); included as untouched
#     controls proving the fix is scoped to roll buffs.
# freeze is consumption-gated (not a tick duration) — guarded by
# freeze_engine_regression, out of scope here.
# Run: godot --headless --path . -s scripts/debug/duration_encoding_test.gd
extends SceneTree

var _errors: Array[String] = []


func _check(cond: bool, label: String) -> void:
	if not cond:
		_errors.append(label)


func _initialize() -> void:
	await process_frame
	var dm: Node = root.get_node("/root/DataManager")
	var hero: UnitData = dm.call("get_unit", "combat") as UnitData
	var enemy: EnemyData = dm.call("get_enemy_by_display_name", "Scrap Drone") as EnemyData
	if hero == null or enemy == null:
		push_error("[DURATION] could not load units")
		print("[DURATION] FAIL — unit load")
		quit(1)
		return

	var CombatManagerScript: GDScript = load("res://scripts/battle/combat_manager.gd")
	var cm: Object = CombatManagerScript.new()
	cm.call("setup_battle", [hero], [enemy.duplicate(true)])
	var st: Dictionary = cm.call("get_hero_states")[0]

	# ── roll-buff FUTURE: present for exactly N future rolls (skips cast tick).
	# Lifetime pattern = [cast, after t1, after t2, ...]. Skip keeps it alive
	# through t1, then N decrements. turns=1 → [_, true(t1), false(t2)].
	_check(_lifetime_buff(cm, st, 1, false) == [true, true, false],
		"future buff turns=1 shapes exactly 1 future roll (present after t1, gone after t2)")
	_check(_lifetime_buff(cm, st, 2, false) == [true, true, true, false],
		"future buff turns=2 shapes exactly 2 future rolls")
	_check(_lifetime_buff(cm, st, 3, false) == [true, true, true, true, false],
		"future buff turns=3 shapes exactly 3 future rolls")

	# ── ITEM GUARD (roll-buff CURRENT): no skip, so a turns=1 item shapes the
	# CURRENT roll and is gone after one tick — exactly one roll, never two.
	_check(_lifetime_buff(cm, st, 1, true) == [true, false],
		"ITEM GUARD: current-roll buff turns=1 grants exactly one roll (gone after t1, not two)")
	_check(_lifetime_buff(cm, st, 2, true) == [true, true, false],
		"current-roll buff turns=2 grants two rolls (current + one future)")
	# The public item path must resolve to the current-roll timing.
	st["roll_buff_stacks"] = []
	cm.call("apply_item_roll_buff", st, 2, 1)
	var item_present_cast: bool = int(cm.call("get_roll_modifier_totals", st)["roll_buff"]) > 0
	cm.call("_tick_state", st)
	var item_present_after: bool = int(cm.call("get_roll_modifier_totals", st)["roll_buff"]) > 0
	_check(item_present_cast and not item_present_after,
		"apply_item_roll_buff (calibration_chip turns=1) grants exactly one roll via the public path")

	# ── rfe DEBUFF (untouched control, N=N via its own skip flag).
	_check(_lifetime_rfe(cm, st, 1) == [true, true, false], "rfe debuff turns=1 lasts exactly 1 turn (untouched)")
	_check(_lifetime_rfe(cm, st, 2) == [true, true, true, false], "rfe debuff turns=2 lasts exactly 2 turns (untouched)")

	# ── burn (untouched control): an Nt burn is present for N ticks.
	_check(_lifetime_burn(cm, st, 1) == [true, true, false], "burn turns=1 present for exactly 1 tick (untouched)")
	_check(_lifetime_burn(cm, st, 2) == [true, true, true, false], "burn turns=2 present for exactly 2 ticks (untouched)")

	if _errors.is_empty():
		print("[DURATION] PASS — every duration family stores effective turns (N present, N+1 absent)")
		quit(0)
	else:
		for e in _errors:
			push_error("[DURATION] " + e)
		print("[DURATION] FAIL — %d error(s)" % _errors.size())
		quit(1)


# Returns [present_at_cast, present_after_t1, present_after_t2, ...] until the
# first absence (inclusive), for a roll buff of the given turns / timing.
func _lifetime_buff(cm: Object, st: Dictionary, turns: int, shapes_current_roll: bool) -> Array:
	st["roll_buff_stacks"] = []
	cm.call("_add_roll_buff", st, 2, turns, shapes_current_roll)
	return _sample(func() -> bool: return int(cm.call("get_roll_modifier_totals", st)["roll_buff"]) > 0, cm, st)


func _lifetime_rfe(cm: Object, st: Dictionary, turns: int) -> Array:
	st["rfe_stacks"] = []
	cm.call("_add_rfe_stack", st, 2, turns)
	return _sample(func() -> bool: return int(cm.call("get_roll_modifier_totals", st)["roll_rfe"]) > 0, cm, st)


func _lifetime_burn(cm: Object, st: Dictionary, turns: int) -> Array:
	st["burn_stacks"] = []
	st["current_hp"] = 9999  # keep it alive through the ticks
	st["dead"] = false
	cm.call("_apply_burn", st, 3, turns)
	return _sample(func() -> bool: return not (st.get("burn_stacks", []) as Array).is_empty(), cm, st)


# Sample presence at cast, then after each tick, stopping once absent.
func _sample(read: Callable, cm: Object, st: Dictionary) -> Array:
	var out: Array = [bool(read.call())]
	for _i in range(6):
		cm.call("_tick_state", st)
		var present: bool = bool(read.call())
		out.append(present)
		if not present:
			break
	return out
