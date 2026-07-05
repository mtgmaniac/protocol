# RollProvider — the single seam through which a d20 value enters combat.
#
# combat_manager.gd never rolls dice itself: resolve_round() takes roll VALUES
# as inputs. In the live game those values come from the physics tray; in the
# balance sim they come from a per-run seeded RNG stream. This interface lets
# both sides feed the exact same rules engine.
#
# One assumption (Package A.2): physics is PRESENTATION. The tray animates to a
# uniform face; the sim models rolls as a uniform d20 draw. Freeze / Jam /
# Rewrite / Hijack all operate on roll VALUES and reveal-skips (in
# combat_manager / BattleEngine), never on physics, so they behave identically
# under either provider.
#
# Subclass, don't instantiate: use SeededRollProvider (sim) or
# PhysicsRollProvider (game / headless fallback).
class_name RollProvider
extends RefCounted


# Returns a d20 value in [1, 20]. Overridden by every concrete provider.
func roll_d20() -> int:
	push_error("RollProvider.roll_d20() is abstract — use SeededRollProvider or PhysicsRollProvider")
	return 1


# Human-readable id for telemetry / run headers.
func describe() -> String:
	return "abstract"
