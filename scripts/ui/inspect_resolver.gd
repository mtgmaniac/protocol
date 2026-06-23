# Turns an inspectable game target into a structured InspectPopup payload. This is the
# ONLY place that reads game data (DataManager / resources). The popup view stays data-
# blind. Adding a new inspectable type = one new resolve_* function here, no view change.
#
# Payload schema (every section optional; rendered top->bottom by InspectPopup):
#   {
#     "accent": Color,                       # title + border accent (side / rarity)
#     "header": { "icon": Texture2D, "icon_char": String, "title": String, "subtitle": String },
#     "roll_table": [ { "range": "1-4", "zone": "RECHARGE", "name": "Static Ping" }, ... ],
#     "abilities": [ { "name": String, "meta": String, "effects": Array, "text": String }, ... ],
#     "stats": [ { "label": String, "value": String }, ... ],
#     "description": String,
#   }
# `effects` are EffectPip dicts (built via EffectPip), rendered with the shared pip assets.
class_name InspectResolver
extends RefCounted

# Single source of truth for protocol-action costs (Nudge / Reroll / Set-a-die). Stage 3
# will point battle_scene's SET_DIE_COST / NUDGE_COST / REROLL_COST at these so the number
# lives in exactly one place.
const PROTOCOL_ACTIONS := {
	"nudge": {"name": "NUDGE", "cost": 1, "effect": "Add +3 to a hero's effective roll. Once per die per turn."},
	"reroll": {"name": "REROLL", "cost": 2, "effect": "Reroll a hero's die to a fresh random value."},
	"set": {"name": "SET A DIE", "cost": 3, "effect": "Set a hero's die to any value you choose."},
}


# ── 1. Ability (long-press a die / ability pip) ─────────────────────────────────
# `raw` is the structured ability dict (name, eff, dmg/dot/dT/heal/rfe/shield/shT…) as
# stored in a dice_ranges entry's "raw". `side` drives pip coloring.
static func resolve_ability(raw: Dictionary, side: String = "hero", meta: String = "") -> Dictionary:
	if raw.is_empty():
		return {}
	var effects: Array = EffectPip.effects_from_ability_raw(raw, side)
	return {
		"accent": _side_accent(side),
		"header": {"title": str(raw.get("name", "Ability")), "subtitle": meta if meta != "" else "ABILITY"},
		"abilities": [{
			"name": "",
			"meta": meta,
			"effects": effects,
			"text": _ability_text(raw, side),
		}],
	}


# ── 2. Unit (long-press a player OR enemy unit card) ────────────────────────────
static func resolve_unit(data: Resource) -> Dictionary:
	if data == null:
		return {}
	var is_enemy: bool = data is EnemyData
	var side: String = "enemy" if is_enemy else "hero"
	var ranges: Array = []
	var source: Variant = data.get("dice_ranges")
	if source is Array:
		ranges = source
	var abilities: Array = []
	for entry_variant in ranges:
		var entry: Dictionary = entry_variant
		if str(entry.get("ability_name", "")) == "":
			continue
		var raw: Dictionary = entry.get("raw", {})
		abilities.append({
			"name": str(entry.get("ability_name", "")),
			"roll": "%d - %d" % [int(entry.get("min", 0)), int(entry.get("max", 0))],
			"effects": EffectPip.effects_from_ability_raw(raw, side) if not raw.is_empty() else [],
			"text": _ability_text(raw, side) if not raw.is_empty() else str(entry.get("description", "")),
		})
	# No portrait, no separate roll-range table — each ability carries its own roll band.
	return {
		"accent": _side_accent(side),
		"header": {
			"title": str(data.get("display_name")),
			"subtitle": _unit_subtitle(data),
		},
		"abilities": abilities,
	}


# ── 3. Status / DoT pip (long-press a status icon) ──────────────────────────────
# `status` is a normalized status dict (type, value/stacks, duration, name…). If a
# cosmetic `dot_flavor` ever exists it is used as the label; today it does NOT exist in
# the data, so we fall back to the generic keyword.
static func resolve_status(status: Dictionary) -> Dictionary:
	if status.is_empty():
		return {}
	var kind: String = str(status.get("type", status.get("name", ""))).to_lower()
	var label: String = str(status.get("dot_flavor", "")).strip_edges()
	if label == "":
		label = _status_keyword(kind)
	var value: String = str(status.get("value", "")).strip_edges()
	var duration: int = int(status.get("duration", 0))
	var stats: Array = []
	if value != "":
		stats.append({"label": _value_label(kind), "value": value})
	if duration > 0:
		stats.append({"label": "TURNS LEFT", "value": str(duration)})
	return {
		"accent": _status_accent(kind),
		"header": {"title": label, "subtitle": "STATUS"},
		"stats": stats,
		"description": _status_text(kind, value, duration),
	}


# ── 4. Relic / Gear (long-press an owned item icon) ─────────────────────────────
static func resolve_item(item: ItemData) -> Dictionary:
	if item == null:
		return {}
	var rarity: String = "legendary" if item.item_type == "relic" else (item.rarity if item.rarity != "" else "common")
	var type_label: String = item.item_type.to_upper()
	var subtitle: String = type_label if item.item_type == "relic" else "%s %s" % [rarity.to_upper(), type_label]
	return {
		"accent": PixelUI.rarity_color(rarity),
		"header": {"icon": item.icon, "title": item.display_name, "subtitle": subtitle},
		"abilities": [{
			"name": "",
			"effects": EffectPip.effects_from_passive(item.effect, item.target_kind),
			"text": "",
		}],
		"description": item.description,
	}


# ── 5. Protocol action (long-press Nudge / Reroll / Set-a-die) ──────────────────
static func resolve_protocol_action(action: String) -> Dictionary:
	var info: Dictionary = PROTOCOL_ACTIONS.get(action.to_lower(), {})
	if info.is_empty():
		return {}
	return {
		"accent": PixelUI.GOLD_ACCENT,
		"header": {"title": str(info["name"]), "subtitle": "PROTOCOL ACTION"},
		"stats": [{"label": "COST", "value": "%d Protocol" % int(info["cost"])}],
		"description": str(info["effect"]),
	}


# ── helpers ─────────────────────────────────────────────────────────────────────
static func _side_accent(side: String) -> Color:
	return PixelUI.DT_ENEMY_BORDER if side == "enemy" else PixelUI.DT_HERO_BORDER


static func _unit_subtitle(data: Resource) -> String:
	if data is UnitData:
		var role: String = str((data as UnitData).role)
		var cls: String = str((data as UnitData).class_name_text)
		if role != "" and cls != "":
			return "%s / %s" % [role, cls]
		return cls if cls != "" else role
	if data is EnemyData:
		var faction: String = str((data as EnemyData).faction)
		var etype: String = str((data as EnemyData).enemy_type)
		if faction != "" and etype != "":
			return "%s / %s" % [faction, etype]
		return etype if etype != "" else faction
	return ""


# Compose full inspect sentences from structured ability fields (hostile effects first).
static func _ability_text(raw: Dictionary, side: String = "hero") -> String:
	if raw.is_empty():
		return ""
	var hostile: Array[String] = []
	var friendly: Array[String] = []

	if bool(raw.get("wipeShields", false)):
		hostile.append("Remove all hero shields.")

	var dmg: int = int(raw.get("dmg", 0))
	var dmg_p2: int = int(raw.get("dmgP2", 0))
	var d_min: int = int(raw.get("dMin", 0))
	var d_max: int = int(raw.get("dMax", 0))
	var blast_all: bool = bool(raw.get("blastAll", false))
	if dmg > 0:
		if side == "enemy" and blast_all:
			hostile.append("Deal %d damage to all heroes." % dmg)
		elif blast_all:
			hostile.append("Deal %d damage to all enemies." % dmg)
		else:
			hostile.append("Deal %d damage." % dmg)
		if dmg_p2 > 0:
			hostile.append("Phase 2: deals %d damage instead." % dmg_p2)
	elif d_min > 0 or d_max > 0:
		if d_min == d_max:
			hostile.append("Deal %d damage." % d_min)
		else:
			hostile.append("Deal %d-%d damage." % [d_min, d_max])

	var dot: int = int(raw.get("dot", 0))
	if dot > 0:
		var dt: int = int(raw.get("dT", 0))
		hostile.append("Deal %d damage per turn%s." % [dot, (" for " + _turns(dt)) if dt > 0 else ""])

	if bool(raw.get("ignSh", false)):
		hostile.append("Pierces hero shields." if side == "enemy" else "Pierces enemy shields.")

	var lifesteal: int = int(raw.get("lifestealPct", 0))
	if lifesteal > 0:
		hostile.append("Heal for %d%% of damage dealt." % lifesteal)

	if side == "hero":
		var rfe: int = int(raw.get("rfe", 0))
		if rfe > 0:
			var rf_t: int = int(raw.get("rfT", 0))
			var rfe_suffix: String = (" for " + _turns(rf_t)) if rf_t > 0 else ""
			if bool(raw.get("rfeAll", false)):
				hostile.append("Reduce all enemy rolls by %d%s." % [rfe, rfe_suffix])
			else:
				hostile.append("Reduce an enemy roll by %d%s." % [rfe, rfe_suffix])
	else:
		var enemy_rfm: int = int(raw.get("rfm", 0))
		if enemy_rfm > 0:
			var enemy_rfm_t: int = int(raw.get("rfmT", 0))
			var debuff_suffix: String = (" for " + _turns(enemy_rfm_t)) if enemy_rfm_t > 0 else ""
			hostile.append("Reduce a hero roll by %d%s." % [enemy_rfm, debuff_suffix])

	var freeze_line: String = _freeze_inspect_text(raw)
	if freeze_line != "":
		hostile.append(freeze_line)

	if bool(raw.get("curseDice", false)):
		hostile.append("Target hero rolls twice next turn and keeps the lower result.")

	var cower: int = int(raw.get("cowerT", 0))
	if cower > 0:
		if bool(raw.get("cowerAll", false)):
			hostile.append("All heroes skip their next turn%s (%s)." % ["" if cower == 1 else "s", _turns(cower)])
		else:
			hostile.append("Target hero skips their next turn%s (%s)." % ["" if cower == 1 else "s", _turns(cower)])

	if bool(raw.get("packBonus", false)):
		hostile.append("Damage increases by the number of living allies of the same type.")

	var summon: int = int(raw.get("summonChance", 0))
	if summon > 0:
		hostile.append("%d%% chance to summon an elite on natural 20 overload." % summon)

	var heal: int = int(raw.get("heal", 0))
	if heal > 0:
		if bool(raw.get("healAll", false)):
			friendly.append("Restore %d HP to all allies." % heal)
		elif bool(raw.get("healLowest", false)):
			friendly.append("Restore %d HP to the lowest-HP ally." % heal)
		elif bool(raw.get("healTgt", false)):
			friendly.append("Restore %d HP to an ally." % heal)
		elif side == "hero" and dmg > 0:
			friendly.append("Restore %d HP to self." % heal)
		elif side == "enemy":
			friendly.append("Restore %d HP." % heal)
		else:
			friendly.append("Restore %d HP." % heal)

	var shield: int = int(raw.get("shield", 0))
	var shield_p2: int = int(raw.get("shieldP2", 0))
	if shield > 0:
		var sh_t: int = int(raw.get("shT", 0))
		var sh_suffix: String = (" for " + _turns(sh_t)) if sh_t > 0 else ""
		if bool(raw.get("shieldAll", false)):
			friendly.append("Grant %d shield to all allies%s." % [shield, sh_suffix])
		elif bool(raw.get("shTgt", false)):
			friendly.append("Grant %d shield to an ally%s." % [shield, sh_suffix])
		else:
			friendly.append("Gain %d shield%s." % [shield, sh_suffix])
		if shield_p2 > 0:
			friendly.append("Phase 2: gain %d shield instead." % shield_p2)

	var shield_ally: int = int(raw.get("shieldAlly", 0))
	if shield_ally > 0:
		var sh_ally_t: int = int(raw.get("shAllyT", raw.get("shT", 1)))
		var ally_sh_suffix: String = (" for " + _turns(sh_ally_t)) if sh_ally_t > 0 else ""
		if bool(raw.get("shieldAllyAll", false)):
			friendly.append("Grant %d shield to all allies%s." % [shield_ally, ally_sh_suffix])
		else:
			friendly.append("Grant %d shield to an ally%s." % [shield_ally, ally_sh_suffix])

	if side == "hero":
		var rfm: int = int(raw.get("rfm", 0))
		if rfm > 0:
			var rfm_t: int = int(raw.get("rfmT", 0))
			var buff_suffix: String = (" for " + _turns(rfm_t)) if rfm_t > 0 else ""
			if bool(raw.get("rfmTgt", false)):
				friendly.append("Increase an ally's roll by %d%s." % [rfm, buff_suffix])
			else:
				friendly.append("Increase all squad rolls by %d%s." % [rfm, buff_suffix])
	else:
		var erb: int = int(raw.get("erb", 0))
		if erb > 0:
			var erb_t: int = int(raw.get("erbT", 0))
			var erb_suffix: String = (" for " + _turns(erb_t)) if erb_t > 0 else ""
			if bool(raw.get("erbAll", false)):
				friendly.append("Increase all ally enemies' rolls by %d%s." % [erb, erb_suffix])
			else:
				friendly.append("Increase this enemy's roll by %d%s." % [erb, erb_suffix])

	var counter: int = int(raw.get("counterspellPct", 0))
	if counter > 0:
		friendly.append("%d%% chance to counter the next attack." % counter)

	if bool(raw.get("grantRampageAll", false)):
		friendly.append("Grant Rampage to all enemies.")
	elif int(raw.get("grantRampage", 0)) > 0:
		friendly.append("Gain Rampage (next hit deals double damage).")

	if bool(raw.get("enemySelfTaunt", false)):
		friendly.append("Taunt: all heroes must target this enemy.")
	elif bool(raw.get("taunt", false)):
		friendly.append("Taunt: enemies must target this unit.")

	if bool(raw.get("cloak", false)):
		friendly.append("Cloak: 80% chance to evade the next incoming hit.")

	if bool(raw.get("reviveAll", false)):
		friendly.append("Revive all fallen allies at %d%% max HP." % int(raw.get("revivePct", 50)))
	elif bool(raw.get("revive", false)):
		friendly.append("Revive a fallen ally at %d%% max HP." % int(raw.get("revivePct", 50)))

	var protocol: int = int(raw.get("gainProtocol", 0))
	if protocol > 0:
		friendly.append("Gain %d Protocol." % protocol)

	var parts: Array[String] = []
	parts.append_array(hostile)
	parts.append_array(friendly)
	if parts.is_empty():
		return "No effect."
	return " ".join(parts)


static func _freeze_inspect_text(raw: Dictionary) -> String:
	var freeze_any: int = maxi(
		maxi(int(raw.get("freezeAnyDice", 0)), int(raw.get("freezeEnemyDice", 0))),
		int(raw.get("freezeAllEnemyDice", 0))
	)
	if freeze_any <= 0:
		return ""
	var duration: String = _turns(freeze_any)
	if int(raw.get("freezeAllEnemyDice", 0)) > 0:
		return "Freeze all enemy dice for %s." % duration
	return "Freeze the target's die for %s." % duration


static func _turns(count: int) -> String:
	return "%d turn%s" % [count, "" if count == 1 else "s"]


static func _status_keyword(kind: String) -> String:
	match kind:
		"poison", "dot":
			return "POISON"
		"shield":
			return "SHIELD"
		"frozen", "freeze", "die_freeze":
			return "FROZEN"
		"cloak":
			return "CLOAK"
		"taunt":
			return "TAUNT"
		"rampage":
			return "RAMPAGE"
		"counter":
			return "COUNTER"
	return kind.to_upper()


static func _value_label(kind: String) -> String:
	match kind:
		"poison", "dot":
			return "DAMAGE / TURN"
		"shield":
			return "ABSORB"
	return "VALUE"


static func _status_text(kind: String, value: String, duration: int) -> String:
	var turns: String = "%d turn%s" % [duration, "" if duration == 1 else "s"] if duration > 0 else ""
	match kind:
		"poison", "dot":
			return "Takes %s damage at the start of each turn%s." % [value if value != "" else "some", (" for " + turns) if turns != "" else ""]
		"shield":
			return "Absorbs %s incoming damage before HP is touched." % (value if value != "" else "")
		"frozen", "freeze", "die_freeze":
			return "Die result is locked and cannot change%s." % ((" for " + turns) if turns != "" else "")
		"cloak":
			return "80% chance to evade the next incoming damage attempt."
		"taunt":
			return "Forces enemies to target this unit."
		"rampage":
			return "Deals double damage this turn."
		"counter":
			return "Primed to reflect the next targeted attack."
	return ""


static func _status_accent(kind: String) -> Color:
	match kind:
		"poison", "dot":
			return PixelUI.COLOR_DEBUFF
		"shield":
			return PixelUI.COLOR_SHIELD
		"frozen", "freeze", "die_freeze":
			return PixelUI.DT_CYAN
		"cloak":
			return PixelUI.COLOR_SHIELD
	return PixelUI.INSPECT_BORDER
