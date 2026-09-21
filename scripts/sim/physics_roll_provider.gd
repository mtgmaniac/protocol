# PhysicsRollProvider — the live-game roll source.
#
# Wraps DiceManager.roll_d20() — the battle's seeded d20 stream — so the game
# and the headless fallback share one seam with the sim's SeededRollProvider.
# In live play battle_scene draws each round's faces here and RIGS the physics
# tray with them (checkpoint system, 2026-09-21): the dice still tumble, but the
# face that rotates up is the drawn one. Physics is presentation (roll_provider.gd),
# and the round's outcome is saveable state rather than a physics accident.
class_name PhysicsRollProvider
extends RollProvider

var _dice_manager: DiceManager

# OWNED stream for the non-d20 picks (save-system refactor). These are
# run-affecting — Overflow Vent's target, Dead Man's Charge's victim, the
# elite-summon chance, chain-reaction targets — and used to draw from Godot's
# global RNG, which cannot be saved and which any stray seed() call elsewhere in
# the process could perturb. Distribution is unchanged: a uniform index over the
# same range from a uniform generator.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(dice_manager: DiceManager = null) -> void:
	_dice_manager = dice_manager if dice_manager != null else DiceManager.new()
	_rng.randomize()


## Seeds BOTH streams this provider fronts from one run-stored battle seed, so a
## battle restarted from its entry replays the same rerolls, vents and summons.
## The live d20 FACES are drawn from the d20 stream too (battle_scene rigs the
## physics tray with them; physics is presentation), so a battle restarted from
## its entry rolls the same opening dice, and an end-of-round checkpoint that
## restores get_stream_states() rolls the same next round.
func seed_streams(battle_seed: int) -> void:
	_rng.seed = battle_seed
	_dice_manager.seed_stream(battle_seed ^ 0x5BF03635)


## Both owned streams' positions, for the end-of-round battle checkpoint. The
## d20 stream now also decides the live tray faces (battle_scene rigs the tray
## from it), so restoring these makes a resumed round roll exactly what the
## interrupted one would have: a refresh cannot reroll the next dice.
func get_stream_states() -> Dictionary:
	return {"d20": _dice_manager.get_stream_state(), "pick": int(_rng.state)}


func set_stream_states(states: Dictionary) -> void:
	_dice_manager.set_stream_state(int(states["d20"]))
	_rng.state = int(states["pick"])


func roll_d20() -> int:
	return _dice_manager.roll_d20()


func rand_index(size: int) -> int:
	if size <= 1:
		return 0
	return _rng.randi_range(0, size - 1)


func describe() -> String:
	return "physics"
