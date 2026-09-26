class_name ReviveResolution
extends RefCounted

## Revive family (Resuscitate, Mass Revival) — the ONE place their outcome and
## percentage are decided, shared by the engine, the battle readout and inspect.
##
## NK-17 conditional alternative (Kev ruling 2026-09-25): `revive 50% HP, else
## 20 heal (hero)`. The `else` clause fires when NOBODY is down, so a 20 is never
## a dead roll. Decided at FIRE time, not pick time — an ally can fall between
## the pick and the cast, and the ability must do the more useful thing then.
## Directives (Field Surgeon, Resuscitation Loop) override the revive PERCENTAGE
## only; the fallback heal is unchanged by them.
##
## Autoloads resolve through the scene tree, never the bare global identifier:
## this script is reached from headless -s tests (TRUTH.md, Verify commands).


static func is_revive_family(raw: Dictionary) -> bool:
	return bool(raw.get("revive", false)) or bool(raw.get("reviveAll", false))


static func fallback_heal(raw: Dictionary) -> int:
	return int(raw.get("fallbackHeal", 0)) if is_revive_family(raw) else 0


static func any_hero_down(hero_states: Array) -> bool:
	for state_variant in hero_states:
		if bool((state_variant as Dictionary).get("dead", false)):
			return true
	return false


## True when this cast resolves as the `else` heal: a fallback exists and no
## hero is down.
static func fallback_active(raw: Dictionary, hero_states: Array) -> bool:
	return fallback_heal(raw) > 0 and not any_hero_down(hero_states)


## The percentage a revive actually restores: authored revivePct, then the
## reviveNoPenalty relic, then the hero's revive directive (which replaces it).
static func resolved_pct(raw: Dictionary, hero_state: Dictionary = {}, ability_name: String = "") -> int:
	var pct: int = int(raw.get("revivePct", 50))
	var game_state: Node = _autoload("GameState")
	if game_state != null:
		pct = int(game_state.call("get_revive_hp_pct", pct))
	if str(hero_state.get("directive_type", "")) == "abilityRevivePctOverride":
		var directive: Dictionary = hero_state.get("directive_effect", {}) as Dictionary
		if str(directive.get("ability", "")) == ability_name and ability_name != "":
			pct = int(directive.get("pct", pct))
	return pct


## Manual pick side: a living hero when the fallback will fire, otherwise a
## fallen one. reviveAll never picks.
static func manual_side(raw: Dictionary, hero_states: Array) -> String:
	if bool(raw.get("reviveAll", false)):
		return ""
	if fallback_active(raw, hero_states):
		return "hero"
	return "dead_hero"


## Board-aware copy of the ability for pips: exactly what this roll does now.
## Fallback active -> the heal it will perform; otherwise the revive at its
## RESOLVED percentage (the readout used to show raw revivePct and ignore the
## directive and relic).
static func display_raw(raw: Dictionary, hero_state: Dictionary, ability_name: String, hero_states: Array) -> Dictionary:
	if not is_revive_family(raw):
		return raw
	var shown: Dictionary = raw.duplicate()
	if fallback_active(raw, hero_states):
		shown.erase("revive")
		shown.erase("reviveAll")
		shown.erase("revivePct")
		shown["heal"] = fallback_heal(raw)
		if bool(raw.get("fallbackHealAll", false)):
			shown["healAll"] = true
			shown.erase("healTgt")
		else:
			shown["healTgt"] = true
		return shown
	shown["revivePct"] = resolved_pct(raw, hero_state, ability_name)
	return shown


static func _autoload(autoload_name: String) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(autoload_name)
