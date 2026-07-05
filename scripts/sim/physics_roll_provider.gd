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


func _init(dice_manager: DiceManager = null) -> void:
	_dice_manager = dice_manager if dice_manager != null else DiceManager.new()


func roll_d20() -> int:
	return _dice_manager.roll_d20()


# Matches the original battle_scene behavior exactly (`randi() % size`), so the
# live game's random picks are byte-identical to before the extraction.
func rand_index(size: int) -> int:
	if size <= 1:
		return 0
	return randi() % size


func describe() -> String:
	return "physics"
