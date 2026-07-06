# Deterministic enemy targeting personalities (Task 9). One choke-point,
# personality_pick_target, shared by the battle UI (intent assignment via
# combat_manager.assign_enemy_intents) and the headless sim/audit (resolve-time
# fallback) — no randomness anywhere in here.
#
# NOTE: `targeting` is a NEW field, fully independent of `ai_type`. ai_type
# still gates nat20 elite summons (combat_manager) and the summon-injection
# guard (battle_scene) — do not conflate the two.
class_name TargetingPersonality
extends RefCounted

enum Personality { SYSTEMATIC, WOUNDED, PACK, SPITEFUL }

# Kit-default table — the ONE place kit defaults live. Resolution order:
# unit `targeting` field (enemies.data.json), else this table, else SYSTEMATIC.
const KIT_DEFAULTS := {
	# Facility — default SYSTEMATIC; pack hunters + the heavies as exceptions.
	"scrap": Personality.SYSTEMATIC,
	"rust": Personality.SYSTEMATIC,
	"signalSkimmer": Personality.SYSTEMATIC,
	"guard": Personality.PACK,
	"patrol": Personality.PACK,
	"volt": Personality.PACK,
	"warden": Personality.WOUNDED,
	"boss": Personality.WOUNDED,
	# Hive — default PACK; the apex predators go for the wounded.
	"mite": Personality.PACK,
	"skitter": Personality.PACK,
	"spewer": Personality.PACK,
	"carapace": Personality.PACK,
	"brood": Personality.PACK,
	"stalker": Personality.WOUNDED,
	"hiveBoss": Personality.WOUNDED,
	# Veil — default WOUNDED; the mindless constructs sweep systematically.
	"veilShard": Personality.SYSTEMATIC,
	"veilPrism": Personality.SYSTEMATIC,
	"veilAegis": Personality.WOUNDED,
	"veilResonance": Personality.WOUNDED,
	"veilNull": Personality.WOUNDED,
	"veilStorm": Personality.WOUNDED,
	"veilSynapse": Personality.WOUNDED,
	"veilBoss": Personality.WOUNDED,
	# Synod — default SYSTEMATIC; the controllers pick off the weak, the
	# Forked Double holds a grudge.
	"voidWisp": Personality.SYSTEMATIC,
	"voidAcolyte": Personality.SYSTEMATIC,
	"voidScribe": Personality.SYSTEMATIC,
	"voidBinder": Personality.WOUNDED,
	"voidChanneler": Personality.WOUNDED,
	"voidCircletBoss": Personality.WOUNDED,
	"voidGlimmer": Personality.SPITEFUL,
	# Accretion — default SPITEFUL; wolves and monkeys hunt in packs, the
	# panther stalks the wounded.
	"beastWolf": Personality.PACK,
	"beastMonkey": Personality.PACK,
	"beastLynx": Personality.WOUNDED,
	"beastBadger": Personality.SPITEFUL,
	"beastBison": Personality.SPITEFUL,
	"beastHyena": Personality.SPITEFUL,
	"beastTyrant": Personality.SPITEFUL,
}

const _NAMES := {
	Personality.SYSTEMATIC: "SYSTEMATIC",
	Personality.WOUNDED: "WOUNDED",
	Personality.PACK: "PACK",
	Personality.SPITEFUL: "SPITEFUL",
}

# One-line player-facing definitions (inspect popup TARGETING line).
const _BLURBS := {
	Personality.SYSTEMATIC: "attacks the squad left to right",
	Personality.WOUNDED: "hunts the lowest-HP hero",
	Personality.PACK: "joins another attacker's target",
	Personality.SPITEFUL: "strikes back at whoever hurt it last",
}


static func from_string(value: String) -> int:
	match value.strip_edges().to_lower():
		"systematic":
			return Personality.SYSTEMATIC
		"wounded":
			return Personality.WOUNDED
		"pack":
			return Personality.PACK
		"spiteful":
			return Personality.SPITEFUL
	return -1


static func personality_name(personality: int) -> String:
	return str(_NAMES.get(personality, "SYSTEMATIC"))


static func personality_blurb(personality: int) -> String:
	return str(_BLURBS.get(personality, _BLURBS[Personality.SYSTEMATIC]))


# Resolution order: unit `targeting` field, else kit default (by enemy_type),
# else SYSTEMATIC.
static func resolve_personality(unit: Object) -> int:
	if unit == null:
		return Personality.SYSTEMATIC
	var field_value: Variant = unit.get("targeting")
	if field_value != null and str(field_value) != "":
		var explicit: int = from_string(str(field_value))
		if explicit != -1:
			return explicit
	var kit: Variant = unit.get("enemy_type")
	if kit != null and KIT_DEFAULTS.has(str(kit)):
		return int(KIT_DEFAULTS[str(kit)])
	return Personality.SYSTEMATIC


# THE choke-point. Universal rules live here and nowhere else:
# - a taunting hero overrides everything (taunt beats cloak);
# - cloaked heroes are skipped (personality picks among uncloaked);
# - a personality whose preferred target is dead or illegal falls through to
#   its STATED fallback (PACK -> WOUNDED, SPITEFUL -> SYSTEMATIC), never to
#   hidden logic;
# - fully deterministic: no randi(); ties break toward the lower slot.
# assignments_so_far: {enemy_id: hero_id} written in slot order this turn —
# Godot Dictionaries preserve insertion order, which PACK relies on.
static func personality_pick_target(enemy_state: Dictionary, hero_states: Array, assignments_so_far: Dictionary) -> Dictionary:
	# Taunt overrides everything.
	for hero_variant in hero_states:
		var hero_state: Dictionary = hero_variant
		if not bool(hero_state.get("dead", false)) and bool(hero_state.get("taunting", false)):
			return hero_state
	var legal: Array = []
	for hero_variant in hero_states:
		var hero_state: Dictionary = hero_variant
		if not bool(hero_state.get("dead", false)) and not bool(hero_state.get("cloaked", false)):
			legal.append(hero_state)
	if legal.is_empty():
		return {}
	var unit: Object = enemy_state.get("unit") as Object
	match resolve_personality(unit):
		Personality.WOUNDED:
			return _lowest_hp(legal)
		Personality.PACK:
			# First hero another enemy was assigned this turn (insertion order
			# = slot order) that is still legal; none -> WOUNDED fallback.
			for assigned_hero_id in assignments_so_far.values():
				for hero_variant in legal:
					var hero_state: Dictionary = hero_variant
					if str(hero_state["id"]) == str(assigned_hero_id):
						return hero_state
			return _lowest_hp(legal)
		Personality.SPITEFUL:
			var grudge_id: String = str(enemy_state.get("last_attacker_id", ""))
			if grudge_id != "":
				for hero_variant in legal:
					var hero_state: Dictionary = hero_variant
					if str(hero_state["id"]) == grudge_id:
						return hero_state
			return legal[0]  # SYSTEMATIC fallback
		_:
			return legal[0]  # SYSTEMATIC: living heroes left to right by slot
	return legal[0]


static func _lowest_hp(legal: Array) -> Dictionary:
	var best: Dictionary = legal[0]
	for state_variant in legal:
		var state: Dictionary = state_variant
		if int(state["current_hp"]) < int(best["current_hp"]):
			best = state
	return best
