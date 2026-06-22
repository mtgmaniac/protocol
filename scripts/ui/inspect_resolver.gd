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
		"header": {"title": str(raw.get("name", "Ability")), "subtitle": "ABILITY"},
		"abilities": [{
			"name": "",
			"meta": meta,
			"effects": effects,
			"text": _ability_text(raw),
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
			"text": _ability_text(raw) if not raw.is_empty() else str(entry.get("description", "")),
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


# Compose a fuller, human-readable line from the structured ability fields rather than
# echoing the terse `eff` string. Falls back to `eff` when nothing structured is present.
static func _ability_text(raw: Dictionary) -> String:
	if raw.is_empty():
		return ""
	var parts: Array = []
	var dmg: int = int(raw.get("dmg", 0))
	var d_min: int = int(raw.get("dMin", 0))
	var d_max: int = int(raw.get("dMax", 0))
	if dmg > 0:
		parts.append("Deal %d damage%s." % [dmg, " to all enemies" if bool(raw.get("blastAll", false)) else ""])
	elif d_min > 0 or d_max > 0:
		parts.append("Deal %d-%d damage." % [d_min, d_max])
	var dot: int = int(raw.get("dot", 0))
	if dot > 0:
		var dt: int = int(raw.get("dT", 0))
		parts.append("Deal %d damage per turn%s." % [dot, (" for " + _turns(dt)) if dt > 0 else ""])
	var heal: int = int(raw.get("heal", 0))
	if heal > 0:
		parts.append("Restore %d HP%s." % [heal, " to all allies" if bool(raw.get("healAll", false)) else ""])
	var shield: int = int(raw.get("shield", 0))
	if shield > 0:
		var sht: int = int(raw.get("shT", 0))
		parts.append("Gain %d shield%s." % [shield, (" for " + _turns(sht)) if sht > 0 else ""])
	var rfe: int = int(raw.get("rfe", 0))
	if rfe > 0:
		parts.append("Reduce an enemy die by %d." % rfe)
	var rfm: int = int(raw.get("rfm", 0))
	if rfm > 0:
		parts.append("Raise a hero die by %d." % rfm)
	if bool(raw.get("revive", false)) or bool(raw.get("reviveAll", false)):
		parts.append("Revive a fallen ally at %d%% max HP." % int(raw.get("revivePct", 50)))
	if bool(raw.get("cloak", false)):
		parts.append("Cloak: 80% chance to evade the next incoming hit.")
	if bool(raw.get("taunt", false)):
		parts.append("Taunt: enemies must target this unit.")
	if bool(raw.get("ignSh", false)):
		parts.append("Pierces enemy shields.")
	if parts.is_empty():
		return str(raw.get("eff", ""))
	return " ".join(parts)


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
