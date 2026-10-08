# What a Firewall cancelled, in words (playtest 2026-10-08).
#
# A Firewall blocks the next ability aimed at its unit, then breaks. It used to
# say so with an X over the card and "<unit>'s firewall blocks the ability!",
# which named neither the Firewall nor what was lost: a taunt eaten by a
# Firewall looked like a taunt that did nothing. Every site in CombatManager
# that asks the Firewall now names the effect it was about to apply, and the
# block carries those names to the battle log and to the BLOCKED chip.
#
# Copy only. CombatManager decides what is blocked; BattleFeedback draws the
# chip. Preloaded by path, not a class_name: -s gates parse before the editor
# rebuilds the global class cache.
extends RefCounted

# The effects a Firewall can cancel, as the log names them (sentence case,
# keywords lowercase; the relic keeps its name).
const DAMAGE := "damage"
const BURN := "burn"
const MARK := "mark"
const BREACH := "breach"
const CHAIN := "chain damage"
const ROLL_PENALTY := "roll penalty"
const TAUNT := "taunt"
const FREEZE := "freeze"
const JAM := "jam"
const REWRITE := "rewrite"
const SIPHON := "siphon"
const SPILLOVER := "Spillover Charge"

const CHIP_TEXT := "BLOCKED"
# How long the chip stays on the unit, in seconds (the battle numbers' time).
const CHIP_HOLD := 1.5

## Debug-build seam for the `firewall feedback` gate's deliberate breaks (never
## set by the game): `silent_taunt` drops the taunt's name (one effect goes
## unreported), `old_log` restores the old line, `no_chip` draws the old X,
## `animated_chip` ignores No animations.
const BREAK_ARG := "--firewall-feedback-break="
static var _break: String = "?"


static func break_mode() -> String:
	if _break == "?":
		_break = ""
		if OS.is_debug_build():
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with(BREAK_ARG):
					_break = arg.trim_prefix(BREAK_ARG)
	return _break


## The effect names one call site reports, with the gate's breaks applied.
static func named(effects: Array) -> Array:
	if break_mode() == "silent_taunt":
		return effects.filter(func(effect: Variant) -> bool: return str(effect) != TAUNT)
	return effects


## "Firewall blocked taunt on Scrap Drone." / "... damage and burn on ..."
static func log_line(effects: Array, unit_name: String) -> String:
	if break_mode() == "old_log":
		return "%s's firewall blocks the ability!" % unit_name
	return "Firewall blocked %s on %s." % [_join(effects), unit_name]


static func _join(effects: Array) -> String:
	if effects.is_empty():
		return "an ability"
	if effects.size() == 1:
		return str(effects[0])
	var head: Array = effects.slice(0, effects.size() - 1)
	return "%s and %s" % [", ".join(PackedStringArray(head)), str(effects[effects.size() - 1])]
