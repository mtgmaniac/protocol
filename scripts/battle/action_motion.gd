# Which motion a unit's card makes when it uses an ability (playtest 2026-10-08).
#
# An ability that attacks steps in toward the other side (the lunge). One that
# buffs, debuffs, shields, heals or controls without attacking used to stand
# still; it now shakes in place (the wiggle). The class comes from the ability's
# own data, not from the events it happened to produce, so an attack that a
# Firewall blocks still lunges and a shield that grants nothing still wiggles.
#
# Presentation only: BattleFeedback reads this. Combat never does. Preloaded by
# path, not a class_name: -s gates parse before the editor rebuilds the global
# class cache.
extends RefCounted

const LUNGE := "lunge"
const WIGGLE := "wiggle"
const NONE := "none"

# How far the lunge steps toward the other side, in design px.
const LUNGE_DIST := 26.0

# Sideways offsets of the wiggle, in design px, stepped in order and then back
# to rest. Fixed values (no RNG) so it never reads as a hit recoil, and well
# under the lunge's 26 so the two are told apart by size as well as direction.
const WIGGLE_OFFSETS: Array[float] = [12.0, -12.0, 7.0, -7.0]
# Reduced Motion keeps a smaller one. The lunge shrinks by the same ratio
# (5 of 12: 26 px becomes 11), ruled by Kev 2026-10-08.
const WIGGLE_REDUCED_OFFSETS: Array[float] = [5.0, -5.0]
const WIGGLE_STEP := 0.055

## Debug-build seam for the `action motion` gate's deliberate breaks (never set
## by the game): `no_wiggle` leaves non-attackers still (the reported bug),
## `all_lunge` makes every ability lunge, `reduced_full` ignores Reduced
## Motion (wiggle and lunge), `no_anim_ignored` ignores No animations.
const BREAK_ARG := "--action-motion-break="
static var _break: String = "?"


static func break_mode() -> String:
	if _break == "?":
		_break = ""
		if OS.is_debug_build():
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with(BREAK_ARG):
					_break = arg.trim_prefix(BREAK_ARG)
	return _break


## True when the ability hits the other side: direct damage, a burn it plants,
## or a detonation. Everything else it carries is a rider on that attack.
static func attacks(raw: Dictionary) -> bool:
	return int(raw.get("dmg", 0)) > 0 or int(raw.get("burn", 0)) > 0 or bool(raw.get("detonate", false))


## The motion class for one ability (its `raw` data entry).
static func for_ability(raw: Dictionary) -> String:
	if raw.is_empty():
		return NONE
	if attacks(raw) or break_mode() == "all_lunge":
		return LUNGE
	return NONE if break_mode() == "no_wiggle" else WIGGLE


## The lunge's distance under the current settings: full, the smaller Reduced
## Motion step, or 0 (no lunge) under No animations.
static func lunge_distance() -> float:
	if PixelUI.no_animations_enabled() and break_mode() != "no_anim_ignored":
		return 0.0
	if PixelUI.reduced_motion_enabled() and break_mode() != "reduced_full":
		return roundf(LUNGE_DIST * WIGGLE_REDUCED_OFFSETS[0] / WIGGLE_OFFSETS[0])
	return LUNGE_DIST


## The wiggle's offsets under the current settings: full, the smaller Reduced
## Motion set, or none at all under No animations.
static func wiggle_offsets() -> Array[float]:
	if PixelUI.no_animations_enabled() and break_mode() != "no_anim_ignored":
		return []
	if PixelUI.reduced_motion_enabled() and break_mode() != "reduced_full":
		return WIGGLE_REDUCED_OFFSETS
	return WIGGLE_OFFSETS
