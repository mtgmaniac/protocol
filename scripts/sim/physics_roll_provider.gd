# PhysicsRollProvider — the live-game roll source.
#
# In real play the settled physics-tray face is the roll value. This provider
# wraps DiceManager.roll_d20() (the existing headless fallback / global-RNG
# source) so the game and the headless fallback share one seam with the sim's
# SeededRollProvider.
#
# SIM-TODO(kev): once BattleEngine owns the round loop inside battle_scene, the
# game will construct this with a callable that reads the settled tray face
# instead of DiceManager, so physics results flow through the same seam. Until
# then it delegates to DiceManager (the current behavior — unchanged).
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
## resumed battle replays the same rerolls, vents and summons. The d20 FACES are
## not restorable — in live play they are read off the settled physics mesh, not
## drawn here (see roll_provider.gd) — which is why a restarted battle can roll
## differently. That is the accepted trade, not an oversight.
func seed_streams(battle_seed: int) -> void:
	_rng.seed = battle_seed
	_dice_manager.seed_stream(battle_seed ^ 0x5BF03635)


func roll_d20() -> int:
	return _dice_manager.roll_d20()


func rand_index(size: int) -> int:
	if size <= 1:
		return 0
	return _rng.randi_range(0, size - 1)


func describe() -> String:
	return "physics"
