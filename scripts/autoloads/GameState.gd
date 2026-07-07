# Stores run-level state that persists while the player moves between scenes.
extends Node

# Hard cap on carried consumables — matches the in-battle LoadoutMenu's slot count
# (loadout_menu.gd ITEM_SLOTS). Picking up a consumable while full requires swapping one out.
const MAX_CONSUMABLES := 3


var selected_units: Array = []
var current_battle: int = 0
var selected_operation_id: String = ""
var relics: Array = []
var consumables: Array = []
var gear_by_unit: Dictionary = {}
var equipped_gear: Dictionary = {}
var pending_reward_item_ids: Array = []
var claimed_reward_item_id: String = ""
var total_battles: int = 10
var last_run_result: String = ""
var unit_xp: Dictionary = {}
var unit_levels: Dictionary = {}
var unit_evolutions: Dictionary = {}
## unit_id -> chosen Directive name (tier-3 passives, pkg6).
var unit_directives: Dictionary = {}
var pending_evolution_unit_id: String = ""
var deferred_evolution_unit_ids: Array = []
var carried_protocol: int = 0
## Dead Man's Hand relic: the first squad wipe each RUN is survived at 1 HP.
var dead_mans_hand_used: bool = false
## Starting Directive (pkg5): an unlocked boss relic picked at run start.
## It does not consume the battle-5 relic draft — a directive run ends with
## two relics by design.
var starting_directive_relic_id: String = ""
## Templated battle comps (pkg7.1): slot battles are rolled ONCE at run start
## so previews always show exact comps. One entry per battle:
## {"names": [display names], "cloaked": [display names]}.
var resolved_battle_comps: Array = []
## Beat system (pkg7.2): exactly 3 random beats per run in distinct gaps from
## {after b2, b3, b4, b6, b7, b8}; Fork/Intercept 50/50 with >=1 of each.
## after_battle -> {"type": "fork"|"intercept", "tier": "minor"|"major"}.
var run_beats: Dictionary = {}
## Beats already visited this run (after-battle numbers).
var consumed_beats: Array = []
## Route Fork (pkg7.3): one-shot state for the NEXT battle.
var next_battle_modifier: String = ""
var next_battle_supply_grade: int = 0
var used_battle_modifiers: Array = []
## Intercept decks (pkg7.4): shuffled at run start, drawn without replacement.
var intercept_minor_deck: Array = []
var intercept_major_deck: Array = []
## Per-run hero mods from intercept outcomes:
## unit_id -> {roll_bonus, max_hp_delta, start_cloaked, start_warded,
##             nat20_twice, splice_bands}.
var hero_run_mods: Dictionary = {}
## One-shot effects armed for the NEXT battle (consumed by battle_scene):
## protocol, enemy_hp_pct, items_free, decoy, marked_highest, income_debt,
## minus_one_enemy.
var next_battle_effects: Dictionary = {}
## Effects armed for the battle AFTER next (Prisoner Exchange).
var followup_battle_effects: Dictionary = {}
## Rogue Engineer: +N Protocol at every remaining battle start; cap override.
var run_protocol_per_battle: int = 0
var run_protocol_cap_override: int = 0
## Hero unit ids that died during the last two battles (Memorial Protocol).
var deaths_last_battle: Array = []
var deaths_prev_battle: Array = []
# True only for the scripted onboarding encounter (rigged dice + coachmarks). In-memory;
# the tutorial is opt-in from the splash / Help, so it needs no persistence.
var tutorial_mode: bool = false

const XP_SURVIVAL_BONUS := 20
const XP_TO_EVOLVE := 100
## Tier-3 progression (pkg6): evolved units hitting this pick a Directive.
const XP_TO_DIRECTIVE := 250
const SQUAD_UNIT_LIMIT := 3

var _battle_effective_rolls: Dictionary = {}
var _battle_end_alive: Dictionary = {}

## Post-win rarity ladder (round = current_battle when rewards roll). Round 5 = relic only.
const RELIC_ONLY_ROUND := 5
const FIRST_RELIC_ROUND := 5
const RELIC_CHOICE_COUNT := 2

const DRAFT_RARITY_BY_ROUND: Dictionary = {
	1: {"common": 85, "uncommon": 10, "rare": 4, "legendary": 1},
	2: {"common": 70, "uncommon": 20, "rare": 8, "legendary": 2},
	3: {"common": 55, "uncommon": 28, "rare": 14, "legendary": 3},
	4: {"common": 40, "uncommon": 35, "rare": 20, "legendary": 5},
	6: {"common": 35, "uncommon": 35, "rare": 22, "legendary": 8},
	7: {"common": 28, "uncommon": 38, "rare": 26, "legendary": 8},
	8: {"common": 20, "uncommon": 40, "rare": 30, "legendary": 10},
	9: {"common": 15, "uncommon": 38, "rare": 32, "legendary": 15},
	10: {"common": 10, "uncommon": 35, "rare": 35, "legendary": 20},
}

var _reward_rng: RandomNumberGenerator = RandomNumberGenerator.new()


# rng_seed >= 0 seeds the reward RNG deterministically (used by the balance sim
# for reproducible runs); the default (-1) randomizes as normal play does.
func start_run(unit_ids: Array, operation_id: String = "", rng_seed: int = -1, tutorial: bool = false) -> void:
	tutorial_mode = tutorial
	if rng_seed >= 0:
		_reward_rng.seed = rng_seed
	else:
		_reward_rng.randomize()
	selected_units = unit_ids.duplicate()
	enforce_squad_limit()
	selected_operation_id = operation_id
	current_battle = 0
	var operation: OperationData = DataManager.get_operation(selected_operation_id) as OperationData
	if operation != null:
		total_battles = operation.battles.size()
	else:
		total_battles = 10
	_resolve_battle_comps(operation)
	_roll_run_beats()
	consumed_beats.clear()
	next_battle_modifier = ""
	next_battle_supply_grade = 0
	used_battle_modifiers.clear()
	_reset_intercept_state()
	_shuffle_intercept_decks()
	relics.clear()
	consumables.clear()
	gear_by_unit.clear()
	equipped_gear.clear()
	pending_reward_item_ids.clear()
	claimed_reward_item_id = ""
	last_run_result = ""
	unit_xp.clear()
	unit_levels.clear()
	unit_evolutions.clear()
	unit_directives.clear()
	pending_evolution_unit_id = ""
	deferred_evolution_unit_ids.clear()
	carried_protocol = 0
	dead_mans_hand_used = false
	starting_directive_relic_id = ""
	_battle_effective_rolls.clear()
	_battle_end_alive.clear()
	for unit_id in selected_units:
		unit_xp[str(unit_id)] = 0
		unit_levels[str(unit_id)] = 1
	# Tutorial runs do NOT count toward runs_started (per Kev 2026-07-06,
	# DECISIONS_RESOLVED #13) — the rung-1 pity unlock counts real runs only.
	# No retroactive save adjustment: profiles that already banked tutorial
	# runs keep their count (grandfathered).
	if not tutorial_mode:
		SaveManager.record_run_started()


# Launch the rigged onboarding encounter: forced trio (Pulse Tech required for the Nudge
# demo), first operation, battle 1. battle_scene reads tutorial_mode to rig dice/enemy and
# spawn the coachmark controller.
func start_tutorial_run() -> void:
	var op_ids: Array = DataManager.get_operation_order()
	var op_id: String = str(op_ids[0]) if not op_ids.is_empty() else ""
	start_run(["pulse", "combat", "ghost"], op_id, -1, true)
	current_battle = 1


# --- Templated battle comps (pkg7.1) ---
# Fixed battles keep their authored comp; slot battles roll from the op
# faction's role pools once per run.
func _resolve_battle_comps(operation: OperationData) -> void:
	resolved_battle_comps.clear()
	if operation == null:
		return
	var faction: String = selected_operation_id
	for battle_variant in operation.battles:
		var battle: Dictionary = battle_variant
		var names: Array = (battle.get("enemy_names", []) as Array).duplicate()
		var cloaked: Array = (battle.get("cloaked_names", []) as Array).duplicate()
		if names.is_empty():
			names = _roll_slot_names(faction, battle.get("slots", []))
		resolved_battle_comps.append({"names": names, "cloaked": cloaked})


func _roll_slot_names(faction: String, slots: Array) -> Array:
	var names: Array = []
	for slot_variant in slots:
		var slot: String = str(slot_variant)
		if slot == "heavyOrElites":
			# 50/50: one heavy or two elites.
			if _reward_rng.randi_range(0, 1) == 0:
				names.append(_pick_from_role_pool(faction, "heavy", []))
			else:
				var first_elite: String = _pick_from_role_pool(faction, "elite", [])
				names.append(first_elite)
				names.append(_pick_from_role_pool(faction, "elite", [first_elite]))
		else:
			names.append(_pick_from_role_pool(faction, slot, []))
	# Drop any empty picks (missing pools) and respect the field cap.
	var cleaned: Array = []
	for name_variant in names:
		if str(name_variant) != "" and cleaned.size() < SQUAD_UNIT_LIMIT:
			cleaned.append(name_variant)
	return cleaned


# Rolls one name from the faction's role pool, avoiding `used` when possible.
func _pick_from_role_pool(faction: String, role: String, used: Array) -> String:
	var pool: Array = DataManager.get_role_pool(faction, role)
	var fresh: Array = pool.filter(func(n): return not used.has(n))
	if not fresh.is_empty():
		pool = fresh
	if pool.is_empty():
		return ""
	return str(pool[_reward_rng.randi_range(0, pool.size() - 1)])


# --- Beat system (pkg7.2) ---

const BEAT_GAPS := [2, 3, 4, 6, 7, 8]
const BEATS_PER_RUN := 3
## Beats placed after this battle number draw major-tier content.
const MAJOR_BEAT_FROM := 6


func _roll_run_beats() -> void:
	run_beats.clear()
	var open_gaps: Array = BEAT_GAPS.duplicate()
	var chosen_gaps: Array = []
	while chosen_gaps.size() < BEATS_PER_RUN and not open_gaps.is_empty():
		var gap: int = int(open_gaps[_reward_rng.randi_range(0, open_gaps.size() - 1)])
		open_gaps.erase(gap)
		chosen_gaps.append(gap)
	var beat_types: Array = []
	for _i in chosen_gaps.size():
		beat_types.append("fork" if _reward_rng.randi_range(0, 1) == 0 else "intercept")
	# >=1 of each type guaranteed: re-roll (flip) the third when uniform.
	if beat_types.size() == BEATS_PER_RUN:
		if not beat_types.has("fork"):
			beat_types[BEATS_PER_RUN - 1] = "fork"
		elif not beat_types.has("intercept"):
			beat_types[BEATS_PER_RUN - 1] = "intercept"
	for i in chosen_gaps.size():
		var gap: int = int(chosen_gaps[i])
		run_beats[gap] = {
			"type": str(beat_types[i]),
			"tier": "major" if gap >= MAJOR_BEAT_FROM else "minor",
		}


# The beat scheduled after this battle number ({} when none).
func get_beat_after_battle(battle_number: int) -> Dictionary:
	return run_beats.get(battle_number, {})


# --- Route Fork (pkg7.3) ---
# Flagged fights: same slot pattern + one modifier chip + "supply grade +2"
# (the reward rarity ladder rolls two rows deeper, capped at row 10).
# BALANCE-TODO: all modifier numbers provisional.
const BATTLE_MODIFIERS := {
	"hardened": {"name": "HARDENED", "desc": "Enemies spawn with 8 shield.", "amount": 8},
	"jammingField": {"name": "JAMMING FIELD", "desc": "Your dice are Jammed (cap 10) on turn 1.", "cap": 10},
	"overrun": {"name": "OVERRUN", "desc": "One extra fodder unit joins the comp.", "requires": "small_comp"},
	"elitePresence": {"name": "ELITE PRESENCE", "desc": "One enemy slot upgrades to the elite pool.", "requires": "non_elite_slot"},
	"ferocity": {"name": "FEROCITY", "desc": "Enemy hits deal +2.", "amount": 2},
	"deadMansCharge": {"name": "DEAD MAN'S CHARGE", "desc": "Enemies deal 4 to a random hero on death.", "amount": 4},
	"blackout": {"name": "BLACKOUT", "desc": "Protocol income starts on turn 3.", "fromTurn": 3},
	"sealedSupplies": {"name": "SEALED SUPPLIES", "desc": "Items cost +1 Protocol.", "amount": 1},
	"regenerative": {"name": "REGENERATIVE", "desc": "Enemies heal 3 each round.", "amount": 3},
	"warded": {"name": "FIREWALLED", "desc": "Support enemies spawn with a Firewall.", "requires": "has_support"},
}


# fix-1.5: the flagged-route comp is shaped ONCE at roll time and stashed
# here; the fork screen previews it and acceptance commits it verbatim, so
# the preview can never drift from the fight.
var pending_flagged_comp: Dictionary = {}
var pending_flagged_modifier_id: String = ""


# Rolls a modifier for the upcoming fork: no repeats per run; preconditioned
# entries are redrawn when their check fails. Invariant (fix-1.5): a modifier
# is only offered if it produces an observable delta on the offered comp.
func roll_route_modifier() -> String:
	pending_flagged_comp = {}
	pending_flagged_modifier_id = ""
	var comp: Dictionary = {}
	if current_battle >= 0 and current_battle < resolved_battle_comps.size():
		comp = resolved_battle_comps[current_battle]  # index of the NEXT battle
	var comp_names: Array = comp.get("names", [])
	var candidates: Array = []
	for modifier_id in BATTLE_MODIFIERS.keys():
		if not used_battle_modifiers.has(modifier_id):
			candidates.append(modifier_id)
	while not candidates.is_empty():
		var pick: String = str(candidates[_reward_rng.randi_range(0, candidates.size() - 1)])
		if _modifier_precondition_ok(pick, comp_names):
			pending_flagged_comp = _shape_comp_for_modifier(pick, comp)
			pending_flagged_modifier_id = pick
			return pick
		candidates.erase(pick)
	return ""


func _modifier_precondition_ok(modifier_id: String, comp_names: Array) -> bool:
	match str((BATTLE_MODIFIERS[modifier_id] as Dictionary).get("requires", "")):
		"small_comp":
			# Overrun: room for an extra unit and a fodder pool to draw from.
			return comp_names.size() <= 2 and not DataManager.get_role_pool(selected_operation_id, "fodder").is_empty()
		"has_support":
			return not _support_names_in_comp(comp_names).is_empty()
		"non_elite_slot":
			# Elite Presence: at least one non-elite slot to upgrade, and an
			# elite pool to upgrade it from.
			var elite_pool: Array = DataManager.get_role_pool(selected_operation_id, "elite")
			if elite_pool.is_empty():
				return false
			for comp_name in comp_names:
				if not elite_pool.has(str(comp_name)):
					return true
			return false
		_:
			return true


func _support_names_in_comp(comp_names: Array) -> Array:
	var raw_pools: Dictionary = DataManager.enemy_role_pools.get(selected_operation_id, {})
	var support_pool: Array = raw_pools.get("support", [])
	return comp_names.filter(func(n): return support_pool.has(str(n)))


# Player takes the flagged route: arm the modifier + supply grade and commit
# the comp shaped at roll time (fallback: shape now, for callers that never
# rolled — tests and legacy paths).
func accept_flagged_route(modifier_id: String) -> void:
	if modifier_id == "" or not BATTLE_MODIFIERS.has(modifier_id):
		return
	used_battle_modifiers.append(modifier_id)
	next_battle_modifier = modifier_id
	next_battle_supply_grade = 2
	if current_battle >= 0 and current_battle < resolved_battle_comps.size():
		if pending_flagged_modifier_id == modifier_id and not pending_flagged_comp.is_empty():
			resolved_battle_comps[current_battle] = pending_flagged_comp
		else:
			resolved_battle_comps[current_battle] = _shape_comp_for_modifier(modifier_id, resolved_battle_comps[current_battle])
	pending_flagged_comp = {}
	pending_flagged_modifier_id = ""


# Pure comp shaper: returns a shaped duplicate, never mutates the input. The
# roll stage uses it to build the flagged-route preview; acceptance commits
# that same comp.
func _shape_comp_for_modifier(modifier_id: String, comp: Dictionary) -> Dictionary:
	var shaped: Dictionary = comp.duplicate(true)
	var names: Array = shaped.get("names", [])
	match modifier_id:
		"overrun":
			var extra_fodder: String = _pick_from_role_pool(selected_operation_id, "fodder", [])
			if extra_fodder != "" and names.size() < SQUAD_UNIT_LIMIT:
				names.append(extra_fodder)
		"elitePresence":
			var elite_pool: Array = DataManager.get_role_pool(selected_operation_id, "elite")
			for i in names.size():
				if not elite_pool.has(str(names[i])):
					var elite_pick: String = _pick_from_role_pool(selected_operation_id, "elite", [])
					if elite_pick != "":
						names[i] = elite_pick
					break
		"warded":
			shaped["warded"] = _support_names_in_comp(names)
	shaped["names"] = names
	return shaped


# Prisoner Exchange: the effect armed for the battle AFTER next promotes when
# a battle starts (route-modifier consumption runs first in battle_scene).
func promote_followup_effects() -> void:
	var modifier_id: String = str(followup_battle_effects.get("modifier", ""))
	followup_battle_effects.clear()
	if modifier_id == "":
		return
	next_battle_modifier = modifier_id
	if current_battle >= 0 and current_battle < resolved_battle_comps.size():
		resolved_battle_comps[current_battle] = _shape_comp_for_modifier(modifier_id, resolved_battle_comps[current_battle])


# The exact comp for the current battle (1-based current_battle).
func get_current_battle_comp() -> Dictionary:
	var index: int = current_battle - 1
	if index < 0 or index >= resolved_battle_comps.size():
		return {}
	return resolved_battle_comps[index]


# --- Intercept events (pkg7.4) ---
# One event card per intercept beat; choices are fully deterministic, the
# skip/alternative is always listed, and cards draw without replacement.
# `pick`: "hero" = choose a squad hero, "gear" = choose an equipped gear,
# "consumable" = spend the highest-rarity consumable (choice hidden without
# one). `draft`: a follow-up pick from rolled items. BALANCE-TODO: numbers.
const INTERCEPT_CARDS := {
	# ── Minor deck (beats after b2–b4) ──
	"overclockChamber": {"tier": "minor", "name": "OVERCLOCK CHAMBER", "desc": "A resonance rig hums, ready to push a frame past spec.", "choices": [
		{"label": "Overclock a hero: +1 to all rolls this op, -8 max HP.", "pick": "hero", "effects": [{"type": "heroRollBonus", "amount": 1}, {"type": "heroMaxHp", "amount": -8}]},
		{"label": "Decline.", "effects": []},
	]},
	"abandonedArmory": {"tier": "minor", "name": "ABANDONED ARMORY", "desc": "Sealed crates, still warm. Someone left in a hurry.", "choices": [
		{"label": "Crack the crates: draft 1 of 3 uncommon+ consumables.", "draft": {"kind": "consumable", "min_rarity": "uncommon", "count": 3}, "effects": []},
		{"label": "Strip the wiring: +2 Protocol next battle.", "effects": [{"type": "protocolNextBattle", "amount": 2}]},
	]},
	"trainingSim": {"tier": "minor", "name": "TRAINING SIM", "desc": "A live combat sim, still powered.", "choices": [
		{"label": "Focused drills: one hero gains +40 XP.", "pick": "hero", "effects": [{"type": "heroXp", "amount": 40}]},
		{"label": "Squad drills: all heroes gain +15 XP.", "effects": [{"type": "squadXp", "amount": 15}]},
	]},
	"salvageCache": {"tier": "minor", "name": "SALVAGE CACHE", "desc": "A rigged cache. The good stuff is under the alarm.", "choices": [
		{"label": "Spring it: rare gear draft now — next battle is HARDENED.", "pick": "hero", "draft": {"kind": "gear", "min_rarity": "rare", "count": 3}, "effects": [{"type": "armModifier", "id": "hardened"}]},
		{"label": "Take the loose crate: 1 common consumable.", "effects": [{"type": "consumable", "rarity": "common", "count": 1}]},
	]},
	"signalDecrypt": {"tier": "minor", "name": "SIGNAL DECRYPT", "desc": "An enemy carrier wave, weakly encrypted.", "choices": [
		{"label": "Decrypt: reveal the boss kit, +2 Protocol next battle.", "effects": [{"type": "revealBoss"}, {"type": "protocolNextBattle", "amount": 2}]},
		{"label": "Sell the intercept: 1 uncommon consumable.", "effects": [{"type": "consumable", "rarity": "uncommon", "count": 1}]},
	]},
	"decoyBeacon": {"tier": "minor", "name": "DECOY BEACON", "desc": "A beacon rig that can wear a consumable's signature.", "choices": [
		{"label": "Spend your highest-rarity consumable: enemies waste turn 1 on a decoy.", "pick": "consumable", "effects": [{"type": "nextBattleFlag", "flag": "decoy"}]},
		{"label": "Keep it.", "effects": []},
	]},
	"driftingWreck": {"tier": "minor", "name": "DRIFTING WRECK", "desc": "A dead hull. Its dead crew is still aboard.", "choices": [
		{"label": "Board it: uncommon gear draft — next battle has DEAD MAN'S CHARGE.", "pick": "hero", "draft": {"kind": "gear", "min_rarity": "uncommon", "count": 3}, "effects": [{"type": "armModifier", "id": "deadMansCharge"}]},
		{"label": "Siphon the tanks: +2 Protocol next battle.", "effects": [{"type": "protocolNextBattle", "amount": 2}]},
	]},
	"loadoutSwap": {"tier": "minor", "name": "LOADOUT SWAP", "desc": "A calibrated workbench. Time enough to re-rig.", "choices": [
		{"label": "Re-rig: rotate all gear loadouts one hero over, +1 uncommon consumable.", "effects": [{"type": "rotateGear"}, {"type": "consumable", "rarity": "uncommon", "count": 1}]},
		{"label": "Skip.", "effects": []},
	]},
	"cryoPod": {"tier": "minor", "name": "CRYO POD", "desc": "A working pod. The treatment is slow.", "choices": [
		{"label": "Treat a hero: +10 max HP this op — next battle is BLACKOUT.", "pick": "hero", "effects": [{"type": "heroMaxHp", "amount": 10}, {"type": "armModifier", "id": "blackout"}]},
		{"label": "Strip the coolant: 1 common consumable.", "effects": [{"type": "consumable", "rarity": "common", "count": 1}]},
	]},
	"supplyDrone": {"tier": "minor", "name": "SUPPLY DRONE", "desc": "A lost logistics drone pings for orders.", "choices": [
		{"label": "Redirect it: items cost 0 next battle.", "effects": [{"type": "nextBattleFlag", "flag": "items_free"}]},
		{"label": "Scrap it: 2 common consumables.", "effects": [{"type": "consumable", "rarity": "common", "count": 2}]},
	]},
	"firingSolution": {"tier": "minor", "name": "FIRING SOLUTION", "desc": "Orbital assets have a brief window.", "choices": [
		{"label": "Take the shot: the highest-HP enemy next battle starts Marked at 90% HP.", "effects": [{"type": "nextBattleFlag", "flag": "marked_highest"}]},
		{"label": "Sell the window: +2 Protocol next battle.", "effects": [{"type": "protocolNextBattle", "amount": 2}]},
	]},
	# ── Major deck (beats after b6–b8) ──
	"spliceDeal": {"tier": "major", "name": "THE SPLICE DEAL", "desc": "A back-alley splicer offers to rewire a hero's luck.", "choices": [
		{"label": "Deal: a hero's overload band becomes 19-20; recharge band widens by 2.", "pick": "hero", "effects": [{"type": "spliceBands"}]},
		{"label": "Refuse.", "effects": []},
	]},
	"blackMarketNode": {"tier": "major", "name": "BLACK MARKET NODE", "desc": "A fence with taste. Payment in hardware only.", "choices": [
		{"label": "Trade: destroy one equipped gear, draft 1 of 3 rare+ gear.", "pick": "gear", "draft": {"kind": "gear", "min_rarity": "rare", "count": 3}, "effects": [{"type": "destroyPickedGear"}]},
		{"label": "Leave.", "effects": []},
	]},
	"unstableReactor": {"tier": "major", "name": "UNSTABLE REACTOR", "desc": "A cracked core, bleeding radiation into the next sector.", "choices": [
		{"label": "Vent it forward: next battle enemies spawn at 70% HP — a random hero takes 10 now.", "effects": [{"type": "nextBattleEnemyHpPct", "pct": 70}, {"type": "randomHeroDamage", "amount": 10}]},
		{"label": "Seal it: +3 Protocol next battle.", "effects": [{"type": "protocolNextBattle", "amount": 3}]},
	]},
	"rogueEngineer": {"tier": "major", "name": "ROGUE ENGINEER", "desc": "She'll ride along and hot-feed your Protocol lines. Her way.", "choices": [
		{"label": "Take her on: +1 Protocol at every remaining battle start; Protocol cap becomes 8.", "effects": [{"type": "runProtocolPerBattle", "amount": 1, "cap": 8}]},
		{"label": "Decline.", "effects": []},
	]},
	"memorialProtocol": {"tier": "major", "name": "MEMORIAL PROTOCOL", "desc": "The squad wants to honor the fallen.", "requires": "recent_death", "choices": [
		{"label": "Honor them: the fallen hero starts every remaining battle with a Firewall.", "effects": [{"type": "memorialWard"}]},
		{"label": "Keep moving: 1 rare consumable.", "effects": [{"type": "consumable", "rarity": "rare", "count": 1}]},
	]},
	"deepCache": {"tier": "major", "name": "DEEP CACHE", "desc": "A vault seal. Cracking it will drink your Protocol lines dry.", "choices": [
		{"label": "Crack it: legendary draft 1 of 2 — next battle starts at -5 Protocol income debt.", "draft": {"kind": "any", "min_rarity": "legendary", "count": 2}, "effects": [{"type": "incomeDebt", "amount": 5}]},
		{"label": "Leave it.", "effects": []},
	]},
	"theFoundry": {"tier": "major", "name": "THE FOUNDRY", "desc": "A forge line still runs. Feed it and it feeds you.", "choices": [
		{"label": "Feed it one gear: receive a random gear one rarity higher.", "pick": "gear", "effects": [{"type": "foundryUpgrade"}]},
		{"label": "Leave.", "effects": []},
	]},
	"prisonerExchange": {"tier": "major", "name": "PRISONER EXCHANGE", "desc": "A captured cell offers a trade: safe passage for a name.", "choices": [
		{"label": "Trade: next battle has one fewer enemy; the battle after gains ELITE PRESENCE.", "effects": [{"type": "nextBattleFlag", "flag": "minus_one_enemy"}, {"type": "followupModifier", "id": "elitePresence"}]},
		{"label": "Refuse: 1 uncommon consumable.", "effects": [{"type": "consumable", "rarity": "uncommon", "count": 1}]},
	]},
	"overloadRites": {"tier": "major", "name": "OVERLOAD RITES", "desc": "A Synod rite, stolen. It burns the body to feed the die.", "choices": [
		{"label": "Undergo: a hero loses 12 max HP this op; their natural 20s resolve twice.", "pick": "hero", "effects": [{"type": "heroMaxHp", "amount": -12}, {"type": "heroNat20Twice"}]},
		{"label": "Decline.", "effects": []},
	]},
	"ghostFrequency": {"tier": "major", "name": "GHOST FREQUENCY", "desc": "A carrier wave that unmakes a silhouette. It takes something with it.", "choices": [
		{"label": "Tune a hero: starts every remaining battle Cloaked, -6 max HP.", "pick": "hero", "effects": [{"type": "heroStartCloaked"}, {"type": "heroMaxHp", "amount": -6}]},
		{"label": "Sell the wave: 1 rare consumable.", "effects": [{"type": "consumable", "rarity": "rare", "count": 1}]},
	]},
	"deepScan": {"tier": "major", "name": "DEEP SCAN", "desc": "A survey array with reach across the whole op.", "choices": [
		{"label": "Scan: reveal every remaining comp and beat this run.", "effects": [{"type": "revealRun"}]},
		{"label": "Sell the array time: +3 Protocol next battle.", "effects": [{"type": "protocolNextBattle", "amount": 3}]},
	]},
}


func _reset_intercept_state() -> void:
	intercept_minor_deck.clear()
	intercept_major_deck.clear()
	hero_run_mods.clear()
	next_battle_effects.clear()
	followup_battle_effects.clear()
	run_protocol_per_battle = 0
	run_protocol_cap_override = 0
	deaths_last_battle.clear()
	deaths_prev_battle.clear()


func _shuffle_intercept_decks() -> void:
	for card_id in INTERCEPT_CARDS.keys():
		if str((INTERCEPT_CARDS[card_id] as Dictionary).get("tier", "")) == "minor":
			intercept_minor_deck.append(card_id)
		else:
			intercept_major_deck.append(card_id)
	# Fisher-Yates with the run rng.
	for deck in [intercept_minor_deck, intercept_major_deck]:
		for i in range(deck.size() - 1, 0, -1):
			var j: int = _reward_rng.randi_range(0, i)
			var tmp = deck[i]
			deck[i] = deck[j]
			deck[j] = tmp


# Draw the next card for a beat tier, honoring preconditions (Memorial
# Protocol redraws unless a hero died in the last two battles).
func draw_intercept_card(tier: String) -> String:
	var deck: Array = intercept_major_deck if tier == "major" else intercept_minor_deck
	var skipped: Array = []
	while not deck.is_empty():
		var card_id: String = str(deck.pop_front())
		var card: Dictionary = INTERCEPT_CARDS.get(card_id, {})
		if str(card.get("requires", "")) == "recent_death" and _recent_death_hero() == "":
			skipped.append(card_id)
			continue
		for skipped_id in skipped:
			deck.append(skipped_id)
		return card_id
	for skipped_id in skipped:
		deck.append(skipped_id)
	return ""


func _recent_death_hero() -> String:
	for unit_id in deaths_last_battle + deaths_prev_battle:
		if selected_units.has(unit_id):
			return str(unit_id)
	return ""


# Battle-end bookkeeping for Memorial Protocol.
func record_battle_hero_deaths(dead_unit_ids: Array) -> void:
	deaths_prev_battle = deaths_last_battle.duplicate()
	deaths_last_battle = dead_unit_ids.duplicate()


func _hero_mods(unit_id: String) -> Dictionary:
	if not hero_run_mods.has(unit_id):
		hero_run_mods[unit_id] = {}
	return hero_run_mods[unit_id]


# Applies one choice's deterministic effects. `hero_id` / `gear` context comes
# from the intercept screen's pick stages. Returns informational text for
# reveal-type outcomes ("" otherwise).
func apply_intercept_effects(effects: Array, hero_id: String = "", gear_context: Dictionary = {}) -> String:
	var info: String = ""
	for effect_variant in effects:
		var effect: Dictionary = effect_variant
		match str(effect.get("type", "")):
			"heroRollBonus":
				var mods: Dictionary = _hero_mods(hero_id)
				mods["roll_bonus"] = int(mods.get("roll_bonus", 0)) + int(effect.get("amount", 1))
			"heroMaxHp":
				var hp_mods: Dictionary = _hero_mods(hero_id)
				hp_mods["max_hp_delta"] = int(hp_mods.get("max_hp_delta", 0)) + int(effect.get("amount", 0))
			"heroXp":
				unit_xp[hero_id] = get_unit_xp(hero_id) + int(effect.get("amount", 0))
				_queue_evolution_after_win([])
			"squadXp":
				for unit_id in selected_units:
					unit_xp[str(unit_id)] = get_unit_xp(str(unit_id)) + int(effect.get("amount", 0))
				_queue_evolution_after_win([])
			"protocolNextBattle":
				next_battle_effects["protocol"] = int(next_battle_effects.get("protocol", 0)) + int(effect.get("amount", 0))
			"consumable":
				for _i in int(effect.get("count", 1)):
					var item_id: String = _pick_random_reward_by_rarity(str(effect.get("rarity", "common")), consumables)
					if item_id != "" and consumables.size() < MAX_CONSUMABLES:
						consumables.append(item_id)
			"armModifier":
				next_battle_modifier = str(effect.get("id", ""))
			"followupModifier":
				followup_battle_effects["modifier"] = str(effect.get("id", ""))
			"nextBattleFlag":
				next_battle_effects[str(effect.get("flag", ""))] = true
			"nextBattleEnemyHpPct":
				next_battle_effects["enemy_hp_pct"] = int(effect.get("pct", 100))
			"randomHeroDamage":
				var victim: String = str(selected_units[_reward_rng.randi_range(0, selected_units.size() - 1)])
				var mods_dmg: Dictionary = _hero_mods(victim)
				mods_dmg["start_hp_damage"] = int(mods_dmg.get("start_hp_damage", 0)) + int(effect.get("amount", 0))
				info = "%s takes the hit." % victim
			"incomeDebt":
				next_battle_effects["income_debt"] = int(effect.get("amount", 0))
			"runProtocolPerBattle":
				run_protocol_per_battle = int(effect.get("amount", 1))
				run_protocol_cap_override = int(effect.get("cap", 0))
			"memorialWard":
				var fallen: String = _recent_death_hero()
				if fallen != "":
					_hero_mods(fallen)["start_warded"] = true
					info = "%s will carry the Firewall." % fallen
			"heroNat20Twice":
				_hero_mods(hero_id)["nat20_twice"] = true
			"heroStartCloaked":
				_hero_mods(hero_id)["start_cloaked"] = true
			"spliceBands":
				_hero_mods(hero_id)["splice_bands"] = true
			"rotateGear":
				_rotate_gear_loadouts()
			"destroyPickedGear":
				_destroy_equipped_gear(str(gear_context.get("hero_id", "")), str(gear_context.get("gear_id", "")))
			"foundryUpgrade":
				info = _foundry_upgrade(str(gear_context.get("hero_id", "")), str(gear_context.get("gear_id", "")))
			"revealBoss":
				info = _build_boss_reveal_text()
			"revealRun":
				info = _build_run_reveal_text()
	return info


# Mid-run re-equip is REJECTED, not deferred (per Kev 2026-07-06,
# DECISIONS_RESOLVED #15) — do not build the full re-equip UI. This
# deterministic stand-in (rotate every loadout one squad slot over) is the
# permanent behavior.
func _rotate_gear_loadouts() -> void:
	if selected_units.size() < 2:
		return
	var rotated: Dictionary = {}
	for i in selected_units.size():
		var from_id: String = str(selected_units[i])
		var to_id: String = str(selected_units[(i + 1) % selected_units.size()])
		rotated[to_id] = (gear_by_unit.get(from_id, []) as Array).duplicate()
	gear_by_unit = rotated
	equipped_gear = rotated.duplicate(true)


func _destroy_equipped_gear(hero_id: String, gear_id: String) -> void:
	var unit_gear: Array = gear_by_unit.get(hero_id, []).duplicate()
	unit_gear.erase(gear_id)
	gear_by_unit[hero_id] = unit_gear
	equipped_gear[hero_id] = unit_gear.duplicate()


const RARITY_LADDER := ["common", "uncommon", "rare", "legendary"]


func _foundry_upgrade(hero_id: String, gear_id: String) -> String:
	var old_item: ItemData = DataManager.get_item(gear_id) as ItemData
	if old_item == null:
		return ""
	var tier: int = mini(RARITY_LADDER.find(old_item.rarity) + 1, RARITY_LADDER.size() - 1)
	_destroy_equipped_gear(hero_id, gear_id)
	var upgraded_id: String = _pick_random_gear_by_rarity(RARITY_LADDER[tier], [gear_id])
	if upgraded_id == "":
		return "The Foundry consumed %s and produced nothing." % old_item.display_name
	var unit_gear: Array = gear_by_unit.get(hero_id, []).duplicate()
	unit_gear.append(upgraded_id)
	gear_by_unit[hero_id] = unit_gear
	equipped_gear[hero_id] = unit_gear.duplicate()
	var new_item: ItemData = DataManager.get_item(upgraded_id) as ItemData
	return "The Foundry forged %s." % (new_item.display_name if new_item != null else upgraded_id)


func _pick_random_gear_by_rarity(rarity: String, excluded_ids: Array) -> String:
	var pool: Array = []
	for item_key in DataManager.items.keys():
		var item: ItemData = DataManager.items[item_key] as ItemData
		if item != null and item.item_type == "gear" and item.rarity == rarity and not excluded_ids.has(item.id):
			pool.append(item.id)
	if pool.is_empty():
		return ""
	return str(pool[_reward_rng.randi_range(0, pool.size() - 1)])


# Items of a kind at or above a rarity, for intercept drafts.
func roll_intercept_draft(kind: String, min_rarity: String, count: int) -> Array:
	var floor_index: int = maxi(RARITY_LADDER.find(min_rarity), 0)
	var pool: Array = []
	for item_key in DataManager.items.keys():
		var item: ItemData = DataManager.items[item_key] as ItemData
		if item == null or item.item_type == "relic":
			continue
		if kind != "any" and item.item_type != kind:
			continue
		if RARITY_LADDER.find(item.rarity) < floor_index:
			continue
		pool.append(item.id)
	var picks: Array = []
	while picks.size() < count and not pool.is_empty():
		var index: int = _reward_rng.randi_range(0, pool.size() - 1)
		picks.append(pool[index])
		pool.remove_at(index)
	return picks


func _build_boss_reveal_text() -> String:
	var operation: OperationData = DataManager.get_operation(selected_operation_id) as OperationData
	if operation == null or operation.battles.is_empty():
		return ""
	var boss_names: Array = (operation.battles[operation.battles.size() - 1] as Dictionary).get("enemy_names", [])
	var lines: Array = []
	for boss_name in boss_names:
		var enemy: EnemyData = DataManager.get_enemy_by_display_name(str(boss_name)) as EnemyData
		if enemy == null:
			continue
		var kit_lines: Array = []
		for range_entry in enemy.dice_ranges:
			kit_lines.append("%d-%d %s" % [int(range_entry.get("min", 0)), int(range_entry.get("max", 0)), str(range_entry.get("ability_name", ""))])
		var standing_rule: String = CombatManager.get_boss_standing_rule(str(boss_name))
		lines.append("%s%s\n%s" % [str(boss_name), ("\n" + standing_rule) if standing_rule != "" else "", "\n".join(PackedStringArray(kit_lines))])
	return "\n\n".join(PackedStringArray(lines))


func _build_run_reveal_text() -> String:
	var lines: Array = []
	for i in range(current_battle, resolved_battle_comps.size()):
		var names: Array = (resolved_battle_comps[i] as Dictionary).get("names", [])
		var beat_note: String = ""
		var beat: Dictionary = get_beat_after_battle(i + 1)
		if not beat.is_empty() and not consumed_beats.has(i + 1):
			beat_note = "  → then: %s" % str(beat.get("type", "")).to_upper()
		lines.append("B%d: %s%s" % [i + 1, ", ".join(PackedStringArray(names)), beat_note])
	return "\n".join(PackedStringArray(lines))


# Starting Directive: adopt an unlocked boss relic as the run's opening relic.
# Call after start_run (start_run clears relics and the directive id).
func set_starting_directive(relic_id: String) -> void:
	if relic_id == "" or not SaveManager.get_unlocked_boss_relics().has(relic_id):
		return
	starting_directive_relic_id = relic_id
	if not relics.has(relic_id):
		relics.append(relic_id)


func enforce_squad_limit() -> void:
	if selected_units.size() <= SQUAD_UNIT_LIMIT:
		return
	selected_units = selected_units.slice(0, SQUAD_UNIT_LIMIT)


func has_relic_effect(effect_type: String) -> bool:
	for relic_id in relics:
		var item: ItemData = DataManager.get_item(str(relic_id)) as ItemData
		if item == null or item.effect == null:
			continue
		if str(item.effect.get("type", "")) == effect_type:
			return true
	return false


func save_protocol_carryover(unspent_protocol: int, carry_pct: int) -> void:
	if carry_pct <= 0 or unspent_protocol <= 0:
		carried_protocol = 0
		return
	carried_protocol = int(floor(float(unspent_protocol) * float(carry_pct) / 100.0))


func take_carried_protocol() -> int:
	var amount: int = carried_protocol
	carried_protocol = 0
	return amount


func grant_battle_start_consumables(count: int) -> void:
	var granted: int = maxi(count, 0)
	for _i in range(granted):
		if consumables.size() >= MAX_CONSUMABLES:
			break
		var item_id: String = _pick_random_item_id("consumable", consumables)
		if item_id == "":
			break
		consumables.append(item_id)


func is_consumables_full() -> bool:
	return consumables.size() >= MAX_CONSUMABLES


func get_revive_hp_pct(default_pct: int) -> int:
	if has_relic_effect("reviveNoPenalty"):
		return 100
	return default_pct


func advance_to_next_battle() -> void:
	current_battle += 1


func reset_run() -> void:
	tutorial_mode = false
	selected_units.clear()
	current_battle = 0
	selected_operation_id = ""
	relics.clear()
	consumables.clear()
	gear_by_unit.clear()
	equipped_gear.clear()
	pending_reward_item_ids.clear()
	claimed_reward_item_id = ""
	last_run_result = ""
	unit_xp.clear()
	unit_levels.clear()
	unit_evolutions.clear()
	unit_directives.clear()
	pending_evolution_unit_id = ""
	deferred_evolution_unit_ids.clear()
	carried_protocol = 0
	starting_directive_relic_id = ""
	resolved_battle_comps.clear()
	run_beats.clear()
	consumed_beats.clear()
	next_battle_modifier = ""
	next_battle_supply_grade = 0
	used_battle_modifiers.clear()
	_reset_intercept_state()
	_battle_effective_rolls.clear()
	_battle_end_alive.clear()


func prepare_battle_rewards() -> void:
	pending_reward_item_ids = _roll_reward_item_ids()
	claimed_reward_item_id = ""


func get_pending_reward_items() -> Array:
	var rewards: Array = []
	for item_id in pending_reward_item_ids:
		var item: ItemData = DataManager.get_item(str(item_id)) as ItemData
		if item != null:
			rewards.append(item)
	return rewards


# `swap_consumable_id`: when consumables are full, the id of the held consumable to discard
# to make room for the new one (the reward screen prompts for this).
func claim_reward(item_id: String, target_unit_id: String = "", swap_consumable_id: String = "") -> bool:
	var item: ItemData = DataManager.get_item(item_id) as ItemData
	if item == null:
		return false
	if not pending_reward_item_ids.has(item_id):
		return false

	match item.item_type:
		"gear":
			if target_unit_id == "":
				return false
			var unit_gear: Array = gear_by_unit.get(target_unit_id, []).duplicate()
			unit_gear.append(item_id)
			gear_by_unit[target_unit_id] = unit_gear
			equipped_gear[target_unit_id] = unit_gear.duplicate()
		"consumable":
			if consumables.size() >= MAX_CONSUMABLES:
				# Full — a valid swap target is required; the UI guarantees one.
				if swap_consumable_id == "" or not consumables.has(swap_consumable_id):
					return false
				consumables.erase(swap_consumable_id)
			consumables.append(item_id)
		"relic":
			# The Starting Directive doesn't consume the battle-5 draft slot.
			if drafted_relic_count() > 0:
				return false
			relics.append(item_id)
		_:
			return false

	claimed_reward_item_id = item_id
	pending_reward_item_ids.clear()
	return true


func get_inventory_summary() -> String:
	return "Relics: %d | Consumables: %d | Equipped Gear: %d" % [
		relics.size(),
		consumables.size(),
		_count_total_equipped_gear(),
	]


func get_battle_progress_text() -> String:
	return "Battle %d/%d" % [current_battle, total_battles]


func is_final_battle() -> bool:
	return current_battle >= total_battles


func finish_run(result: String) -> void:
	last_run_result = result
	pending_reward_item_ids.clear()
	SaveManager.record_run_finished(result, selected_operation_id, current_battle)


func get_unit_xp(unit_id: String) -> int:
	return int(unit_xp.get(unit_id, 0))


func get_unit_level(unit_id: String) -> int:
	return int(unit_levels.get(unit_id, 1))


func get_unit_evolution_name(unit_id: String) -> String:
	return str(unit_evolutions.get(unit_id, ""))


func get_unit_directive_name(unit_id: String) -> String:
	return str(unit_directives.get(unit_id, ""))


# True when the pending progression stop is a tier-3 Directive pick
# (the unit already evolved) rather than an evolution branch pick.
func is_pending_directive_stage() -> bool:
	return pending_evolution_unit_id != "" and get_unit_evolution_name(pending_evolution_unit_id) != ""


# The 1-of-2 Directive choices scoped to the pending unit's evolution path.
func get_pending_directive_choices() -> Array:
	if pending_evolution_unit_id == "":
		return []
	var unit: UnitData = DataManager.get_unit(pending_evolution_unit_id) as UnitData
	if unit == null:
		return []
	var evolved_name: String = get_unit_evolution_name(pending_evolution_unit_id)
	for path_variant in _group_evolution_paths(unit.evolution_paths):
		var path: Dictionary = path_variant
		if str(path.get("name", "")) == evolved_name:
			return (path.get("directives", []) as Array).duplicate(true)
	return []


func apply_pending_directive(directive_name: String) -> bool:
	if pending_evolution_unit_id == "" or directive_name == "":
		return false
	var valid: bool = false
	for choice_variant in get_pending_directive_choices():
		if str((choice_variant as Dictionary).get("name", "")) == directive_name:
			valid = true
	if not valid:
		return false
	unit_directives[pending_evolution_unit_id] = directive_name
	pending_evolution_unit_id = ""
	return true


func begin_battle_xp_tracking() -> void:
	_battle_effective_rolls.clear()
	_battle_end_alive.clear()


func record_hero_effective_roll(unit_id: String, effective_roll: int) -> void:
	if effective_roll <= 0:
		return
	var key: String = str(unit_id)
	if not _battle_effective_rolls.has(key):
		_battle_effective_rolls[key] = []
	(_battle_effective_rolls[key] as Array).append(effective_roll)


func capture_battle_end_survival(hero_states: Array) -> void:
	_battle_end_alive.clear()
	for state_variant in hero_states:
		var state: Dictionary = state_variant
		var unit_id: String = _squad_unit_id_from_state(state)
		if unit_id == "":
			continue
		_battle_end_alive[unit_id] = not bool(state.get("dead", false))


func award_battle_xp() -> void:
	var newly_crossed_threshold: Array = []
	for unit_id_variant in selected_units:
		var unit_id: String = str(unit_id_variant)
		# Fully progressed (evolution + directive) units stop accruing.
		if get_unit_directive_name(unit_id) != "":
			continue
		var xp_before: int = get_unit_xp(unit_id)
		var gain: int = _compute_battle_xp_gain(unit_id)
		var new_total: int = xp_before + gain
		unit_xp[unit_id] = new_total
		var new_level: int = 1 + int(floor(float(new_total) / float(XP_TO_EVOLVE)))
		unit_levels[unit_id] = maxi(new_level, 1)
		var threshold: int = XP_TO_DIRECTIVE if get_unit_evolution_name(unit_id) != "" else XP_TO_EVOLVE
		if xp_before < threshold and new_total >= threshold:
			newly_crossed_threshold.append(unit_id)

	_queue_evolution_after_win(newly_crossed_threshold)
	_battle_effective_rolls.clear()
	_battle_end_alive.clear()


func _compute_battle_xp_gain(unit_id: String) -> int:
	var rolls: Array = _battle_effective_rolls.get(unit_id, [])
	var avg_roll: int = 0
	if not rolls.is_empty():
		var total: int = 0
		for roll_variant in rolls:
			total += int(roll_variant)
		avg_roll = roundi(float(total) / float(rolls.size()))
	if bool(_battle_end_alive.get(unit_id, false)):
		return XP_SURVIVAL_BONUS + avg_roll
	return avg_roll


func _queue_evolution_after_win(newly_crossed_threshold: Array) -> void:
	if pending_evolution_unit_id != "":
		return

	var ready: Array = []
	for unit_id_variant in deferred_evolution_unit_ids:
		var unit_id: String = str(unit_id_variant)
		if _is_evolution_eligible(unit_id) and not ready.has(unit_id):
			ready.append(unit_id)
	for unit_id_variant in newly_crossed_threshold:
		var unit_id: String = str(unit_id_variant)
		if _is_evolution_eligible(unit_id) and not ready.has(unit_id):
			ready.append(unit_id)
	# Catch units already past their next threshold when it opened (e.g. a
	# unit that banked 250+ XP before its evolution stop resolved).
	for unit_id_variant in selected_units:
		var unit_id: String = str(unit_id_variant)
		if _is_evolution_eligible(unit_id) and not ready.has(unit_id):
			ready.append(unit_id)

	if ready.is_empty():
		return

	var ordered: Array = []
	for unit_id_variant in deferred_evolution_unit_ids:
		var unit_id: String = str(unit_id_variant)
		if ready.has(unit_id):
			ordered.append(unit_id)
	for unit_id_variant in newly_crossed_threshold:
		var unit_id: String = str(unit_id_variant)
		if ready.has(unit_id) and not ordered.has(unit_id):
			ordered.append(unit_id)
	for unit_id_variant in selected_units:
		var unit_id: String = str(unit_id_variant)
		if ready.has(unit_id) and not ordered.has(unit_id):
			ordered.append(unit_id)

	pending_evolution_unit_id = str(ordered[0])
	deferred_evolution_unit_ids.clear()
	for i in range(1, ordered.size()):
		deferred_evolution_unit_ids.append(str(ordered[i]))


func _is_evolution_eligible(unit_id: String) -> bool:
	if get_unit_evolution_name(unit_id) == "":
		return get_unit_xp(unit_id) >= XP_TO_EVOLVE
	return get_unit_directive_name(unit_id) == "" and get_unit_xp(unit_id) >= XP_TO_DIRECTIVE


func _squad_unit_id_from_state(state: Dictionary) -> String:
	var unit: Variant = state.get("unit")
	if unit is UnitData:
		return str((unit as UnitData).id)
	if unit != null:
		return str(unit.get("id"))
	return str(state.get("id", ""))


func has_pending_evolution() -> bool:
	return pending_evolution_unit_id != ""


func get_pending_evolution_paths() -> Array:
	if pending_evolution_unit_id == "":
		return []

	var unit: UnitData = DataManager.get_unit(pending_evolution_unit_id) as UnitData
	if unit == null:
		return []

	return _group_evolution_paths(unit.evolution_paths)


func apply_pending_evolution(path_name: String) -> bool:
	if pending_evolution_unit_id == "":
		return false
	if path_name == "":
		return false

	unit_evolutions[pending_evolution_unit_id] = path_name
	pending_evolution_unit_id = ""
	return true


func get_run_unit_data(unit_id: String) -> UnitData:
	var base_unit: UnitData = DataManager.get_unit(unit_id) as UnitData
	if base_unit == null:
		return null

	var evolved_name: String = get_unit_evolution_name(unit_id)
	if evolved_name == "":
		return base_unit

	var built_unit: UnitData = base_unit.duplicate(true) as UnitData
	if built_unit == null:
		return base_unit

	var grouped_paths: Array = _group_evolution_paths(base_unit.evolution_paths)
	for path_variant in grouped_paths:
		var path: Dictionary = path_variant
		if str(path.get("name", "")) != evolved_name:
			continue
		built_unit.display_name = evolved_name
		var path_callsign: String = str(path.get("callsign", ""))
		if path_callsign != "":
			built_unit.callsign = path_callsign
		# Evolved portrait when the file exists; the duplicate already carries
		# the base portrait, so a missing file silently keeps it.
		var evolved_portrait: Texture2D = DataManager.get_evolution_portrait(unit_id, str(path.get("id", "")))
		if evolved_portrait != null:
			built_unit.portrait = evolved_portrait
		var hp_bonus: int = int(path.get("hp", 0))
		if hp_bonus > 0:
			built_unit.max_hp = hp_bonus
		var ability_map: Dictionary = path.get("abilities_by_zone", {})
		var merged_ranges: Array[Dictionary] = []
		for base_range in built_unit.dice_ranges:
			var zone: String = str(base_range.get("zone", ""))
			if ability_map.has(zone):
				merged_ranges.append((ability_map[zone] as Dictionary).duplicate(true))
			else:
				merged_ranges.append(base_range.duplicate(true))
		built_unit.dice_ranges = merged_ranges
		# Attach the chosen tier-3 Directive so combat can read its passive.
		var directive_name: String = get_unit_directive_name(unit_id)
		if directive_name != "":
			for directive_variant in path.get("directives", []):
				if str((directive_variant as Dictionary).get("name", "")) == directive_name:
					built_unit.directive = (directive_variant as Dictionary).duplicate(true)
		return built_unit

	return base_unit


func get_pending_evolution_unit_id() -> String:
	return pending_evolution_unit_id


# Relics DRAFTED this run. The Starting Directive boss relic (pkg5) never
# consumes the battle-5 draft slot, so it doesn't count — a run that opened
# with a boss relic still gets its RELIC CACHE draft. (Fixes the battle-5
# soft lock: the old `relics.is_empty()` guards predated Starting Directives
# and rolled ZERO options for any run that owned one.)
func drafted_relic_count() -> int:
	var drafted: int = relics.size()
	if starting_directive_relic_id != "" and relics.has(starting_directive_relic_id):
		drafted -= 1
	return drafted


func _roll_reward_item_ids() -> Array:
	var round: int = current_battle
	# Supply grade (pkg7.3 flagged route): the ladder rolls two rows deeper,
	# capped at row 10. One-shot — consumed by this draft (a flagged battle 5
	# spends it on the relic cache, which has no rarity ladder).
	var supply_grade: int = next_battle_supply_grade
	next_battle_supply_grade = 0
	if round == RELIC_ONLY_ROUND:
		if drafted_relic_count() == 0:
			return _roll_relic_choice_ids(RELIC_CHOICE_COUNT)
		return []  # draft already claimed — re-entry stays empty on purpose
	if supply_grade > 0:
		round = mini(round + supply_grade, 10)
		if not DRAFT_RARITY_BY_ROUND.has(round):
			round = mini(round + 1, 10)  # row 5 is the relic cache — step past it

	var chosen_ids: Array = []
	while chosen_ids.size() < 3:
		var rarity: String = _pick_draft_rarity_for_round(round)
		var item_id: String = _pick_random_reward_by_rarity(rarity, chosen_ids)
		if item_id == "":
			item_id = _pick_any_available_reward(chosen_ids)
		if item_id == "":
			break
		chosen_ids.append(item_id)
	return chosen_ids


func _roll_relic_choice_ids(count: int) -> Array:
	var chosen: Array = []
	var excluded: Array = []
	while chosen.size() < count:
		var relic_id: String = _pick_random_item_id("relic", chosen + excluded)
		if relic_id == "":
			break
		# Boss relics never appear in the battle-5 draft — they unlock via
		# first operation clears (pkg5 Starting Directive).
		var relic_item: ItemData = DataManager.get_item(relic_id) as ItemData
		if relic_item != null and relic_item.boss_relic:
			excluded.append(relic_id)
			continue
		chosen.append(relic_id)
	return chosen


func _pick_draft_rarity_for_round(round: int) -> String:
	var weights: Dictionary = DRAFT_RARITY_BY_ROUND.get(round, DRAFT_RARITY_BY_ROUND.get(10, {}))
	if weights.is_empty():
		weights = DRAFT_RARITY_BY_ROUND[1]
	var roll: int = _reward_rng.randi_range(1, 100)
	var cumulative: int = 0
	for tier in ["common", "uncommon", "rare", "legendary"]:
		cumulative += int(weights.get(tier, 0))
		if roll <= cumulative:
			return tier
	return "common"


func _pick_random_reward_by_rarity(rarity: String, excluded_ids: Array) -> String:
	var pool: Array = []
	for item_key in DataManager.items.keys():
		var item: ItemData = DataManager.items[item_key] as ItemData
		if item == null:
			continue
		if item.item_type != "consumable" and item.item_type != "gear":
			continue
		if str(item.rarity) != rarity:
			continue
		if excluded_ids.has(item.id):
			continue
		if has_relic_effect("rewardsNoCommon") and str(item.rarity) == "common":
			continue
		pool.append(item.id)
	if pool.is_empty():
		return ""
	var index: int = _reward_rng.randi_range(0, pool.size() - 1)
	return str(pool[index])


func _pick_random_item_id(item_type: String, excluded_ids: Array) -> String:
	# Only a DRAFTED relic closes the relic pool (the Starting Directive boss
	# relic doesn't — see drafted_relic_count).
	if item_type == "relic" and drafted_relic_count() > 0:
		return ""
	var pool: Array = []
	for item_key in DataManager.items.keys():
		var item: ItemData = DataManager.items[item_key] as ItemData
		if item == null:
			continue
		if item.item_type != item_type:
			continue
		# Never offer a relic the run already owns (a Starting Directive relic
		# would otherwise be duplicable in the battle-5 draft).
		if item_type == "relic" and relics.has(item.id):
			continue
		if excluded_ids.has(item.id):
			continue
		if has_relic_effect("rewardsNoCommon") and str(item.rarity) == "common":
			continue
		pool.append(item.id)

	if pool.is_empty():
		return ""

	var index: int = _reward_rng.randi_range(0, pool.size() - 1)
	return str(pool[index])


func _pick_any_available_reward(excluded_ids: Array) -> String:
	for reward_type in ["consumable", "gear"]:
		var item_id: String = _pick_random_item_id(reward_type, excluded_ids)
		if item_id != "":
			return item_id
	return ""


func _count_total_equipped_gear() -> int:
	var total: int = 0
	for unit_id in gear_by_unit.keys():
		total += (gear_by_unit[unit_id] as Array).size()
	return total


func _group_evolution_paths(evolution_entries: Array) -> Array:
	var grouped: Dictionary = {}
	for entry_variant in evolution_entries:
		var entry: Dictionary = entry_variant
		var path_name: String = str(entry.get("name", ""))
		if path_name == "":
			continue
		if not grouped.has(path_name):
			grouped[path_name] = {
				"id": str(entry.get("id", "")),
				"name": path_name,
				"callsign": str(entry.get("callsign", "")),
				"focus": str(entry.get("focus", "")),
				"hp": int(entry.get("hp", 0)),
				"abilities_by_zone": {},
				"directives": (entry.get("directives", []) as Array).duplicate(true),
			}

		var grouped_entry: Dictionary = grouped[path_name]
		if str(grouped_entry.get("callsign", "")) == "" and str(entry.get("callsign", "")) != "":
			grouped_entry["callsign"] = str(entry.get("callsign", ""))
		if str(grouped_entry.get("focus", "")) == "" and str(entry.get("focus", "")) != "":
			grouped_entry["focus"] = str(entry.get("focus", ""))
		if int(grouped_entry.get("hp", 0)) <= 0 and int(entry.get("hp", 0)) > 0:
			grouped_entry["hp"] = int(entry.get("hp", 0))

		var ability_list: Array = entry.get("abilities", [])
		if ability_list.is_empty():
			grouped[path_name] = grouped_entry
			continue
		# Each evolution entry carries its FULL 5-zone kit — register every
		# ability (a single-entry read here silently kept the base kit for
		# all zones but the first).
		for ability_entry_variant in ability_list:
			var ability_entry: Dictionary = ability_entry_variant
			var zone: String = str(ability_entry.get("zone", ""))
			var range_pair: Array = ability_entry.get("range", [])
			var min_roll: int = int(ability_entry.get("min", range_pair[0] if range_pair.size() > 0 else 0))
			var max_roll: int = int(ability_entry.get("max", range_pair[1] if range_pair.size() > 1 else min_roll))
			var ability_name: String = str(ability_entry.get("ability_name", ability_entry.get("name", "")))
			var raw_entry: Dictionary = ability_entry.get("raw", ability_entry).duplicate(true)
			grouped_entry["abilities_by_zone"][zone] = {
				"min": min_roll,
				"max": max_roll,
				"zone": zone,
				"ability_name": ability_name,
				"description": str(raw_entry.get("eff", ability_entry.get("description", ""))),
				"raw": raw_entry,
			}
		grouped[path_name] = grouped_entry

	var grouped_paths: Array = []
	for path_name in grouped.keys():
		grouped_paths.append(grouped[path_name])
	return grouped_paths
