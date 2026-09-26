# PhysicsRollProvider — the live-game roll source.
#
# Wraps DiceManager.roll_d20() — the battle's seeded d20 stream — so the game
# and the headless fallback share one seam with the sim's SeededRollProvider.
# Live rolls come from the physics tray (G-24: the landed face is the roll); this
# stream serves the skip-visuals path, rerolls and the other owned randomness.
# A settled live roll is kept in the battle checkpoint as a pending roll, so a
# refresh cannot reroll it.
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
## Live d20 faces come from the physics tray (G-24), not this stream; a settled
## roll survives a refresh as the checkpoint's pending roll.
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
