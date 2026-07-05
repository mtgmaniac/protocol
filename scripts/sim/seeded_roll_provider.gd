# SeededRollProvider — uniform d20 from a per-run seeded RNG stream.
#
# Used by the balance sim. Determinism law: same seed → identical sequence.
# Godot's RandomNumberGenerator is deterministic for a fixed seed, so two runs
# constructed with the same seed produce byte-identical roll streams.
#
# The sim derives this provider's seed from the run master seed as a fixed
# offset from GameState._reward_rng's seed so the two streams (rolls vs
# drafts/beats) are independent yet reproducible. NEVER call randomize().
class_name SeededRollProvider
extends RollProvider

var _rng: RandomNumberGenerator


func _init(rng_seed: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = rng_seed


func roll_d20() -> int:
	return _rng.randi_range(1, 20)


# Exposed so the engine can snapshot/restore the stream for the L2 solver's
# speculative lookahead (Package D) without perturbing the real sequence.
func get_state() -> int:
	return int(_rng.state)


func set_state(state: int) -> void:
	_rng.state = state


func describe() -> String:
	return "seeded"
