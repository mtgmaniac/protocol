# BattleState — the caller-owned battle state that used to be loose members on
# battle_scene.gd: the per-round roll dicts, the Nudge/Set maps, the Protocol
# pool, and the per-battle spend/economy status flags.
#
# Why a container (balance-sim A.1 / Package D prep): the L2 solver needs cheap
# snapshot + rollback for speculative lookahead. With one container that is a
# single duplicate_for_search() deep-copy instead of a scavenger hunt across a
# dozen scattered members.
#
# battle_scene keeps its field NAMES via property forwarders (references
# preserved, semantics unchanged) — it just stores them here now; the sim owns
# its own BattleState. Combat/unit status (HP, shields, freeze, burn, …) lives
# in combat_manager's unit-state dicts, NOT here; that half is snapshotted
# separately when Package D lands CombatState duplication.
class_name BattleState
extends RefCounted

# ── Per-round roll state ──────────────────────────────────────────────────────
var hero_rolls: Dictionary = {}          # unit id -> raw d20
var enemy_rolls: Dictionary = {}         # unit id -> raw d20
var hero_roll_nudges: Dictionary = {}    # hero id -> +N Nudge applied to the effective roll
var hero_roll_sets: Dictionary = {}      # hero id -> absolute effective roll from the Set action

# ── Protocol economy ──────────────────────────────────────────────────────────
var protocol_points: int = 0             # battles start at 0; +1 income at end of each turn

# ── Per-battle spend / economy status ─────────────────────────────────────────
var income_debt: int = 0                 # Deep Cache intercept: turns of owed income
var free_nudge_used: Dictionary = {}     # hero id -> Priming Charge free-Nudge consumed
var root_access_used: bool = false       # Root Access relic: first Set each battle is free
var twin_fates_used: bool = false        # Twin Fates relic: once-per-battle copy used
var twin_fates_source_id: String = ""    # Twin Fates: chosen source die mid-pick


# Deep copy for L2 speculative lookahead: mutate the clone, keep the original.
func duplicate_for_search() -> BattleState:
	var copy := BattleState.new()
	copy.hero_rolls = hero_rolls.duplicate(true)
	copy.enemy_rolls = enemy_rolls.duplicate(true)
	copy.hero_roll_nudges = hero_roll_nudges.duplicate(true)
	copy.hero_roll_sets = hero_roll_sets.duplicate(true)
	copy.protocol_points = protocol_points
	copy.income_debt = income_debt
	copy.free_nudge_used = free_nudge_used.duplicate(true)
	copy.root_access_used = root_access_used
	copy.twin_fates_used = twin_fates_used
	copy.twin_fates_source_id = twin_fates_source_id
	return copy
