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

# fix-2.5: ability raw field -> keyword id in keywords.data.json. Any ability
# whose eff carries one of these keywords gets the registry's one-line
# definition appended in the inspect popup. Numeric self-evident effects
# (dmg / heal / shield / burn / ±roll) are deliberately not listed.
const KEYWORD_FIELD_MAP := {
	"chain": "chain",
	"detonate": "detonate",
	"execute": "execute",
	"breach": "breach",
	"breachAll": "breach",
	"wipeShields": "breach",
	"leech": "leech",
	"lifestealPct": "leech",
	"mark": "mark",
	"spike": "spike",
	"ignSh": "pierce",
	"jam": "jam",
	"jamAll": "jam",
	"rewrite": "rewrite",
	"hijack": "hijack",
	"siphon": "siphon",
	"cloak": "cloak",
	"ward": "ward",
	"taunt": "taunt",
	"enemySelfTaunt": "taunt",
	"freezeAnyDice": "freeze",
	"freezeEnemyDice": "freeze",
	"freezeAllEnemyDice": "freeze",
}

static var _keyword_registry_cache: Dictionary = {}


# id -> keyword entry from keywords.data.json (single source, via DataManager).
static func _keyword_registry() -> Dictionary:
	if _keyword_registry_cache.is_empty():
		for kw_variant in (DataManager.get_keywords().get("keywords", []) as Array):
			var kw: Dictionary = kw_variant
			_keyword_registry_cache[str(kw.get("id", ""))] = kw
	return _keyword_registry_cache


# "Term — one-line definition." lines for every keyword the ability carries.
static func _keyword_definitions_for_raw(raw: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var seen: Dictionary = {}
	for field in KEYWORD_FIELD_MAP.keys():
		if not raw.has(field):
			continue
		var field_value: Variant = raw[field]
		var active: bool = bool(field_value) if field_value is bool else float(field_value) > 0.0
		if not active:
			continue
		var keyword_id: String = str(KEYWORD_FIELD_MAP[field])
		if seen.has(keyword_id):
			continue
		seen[keyword_id] = true
		var entry: Dictionary = _keyword_registry().get(keyword_id, {})
		if entry.is_empty():
			continue
		lines.append("%s — %s" % [str(entry.get("term", keyword_id.capitalize())), str(entry.get("def", ""))])
	return lines


# The ability's eff string plus the definitions of every keyword it carries.
static func _ability_inspect_text(raw: Dictionary, fallback: String = "") -> String:
	var text: String = str(raw.get("eff", fallback))
	for line in _keyword_definitions_for_raw(raw):
		text += "\n" + line
	return text


# ── 1. Ability (long-press a die / ability pip) ─────────────────────────────────
# `raw` is the structured ability dict (name, eff, dmg/burn/burnT/heal/rfe/shield…) as
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
			"text": _ability_inspect_text(raw),
		}],
	}


# ── 2. Unit (long-press a player OR enemy unit card) ────────────────────────────
# `state` is the unit's live battle-state dict (empty outside battle, e.g. the home screen).
# When it carries active statuses they REPLACE the role subtitle, shown as pip + description
# rows; with no statuses the role subtitle is kept.
static func resolve_unit(data: Resource, state: Dictionary = {}) -> Dictionary:
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
			# fix-2.4: the authored eff string IS the ability text — same live
			# data battle renders. fix-2.5: keyword definitions ride along.
			"text": _ability_inspect_text(raw, str(entry.get("description", ""))),
		})
	var statuses: Array = _unit_status_entries(state)
	# Active statuses take the role descriptor's place; otherwise keep the role subtitle.
	var subtitle: String = "" if not statuses.is_empty() else _unit_subtitle(data)
	# No portrait, no separate roll-range table — each ability carries its own roll band.
	var payload: Dictionary = {
		"accent": _side_accent(side),
		"header": {
			"title": str(data.get("display_name")),
			"subtitle": subtitle,
		},
		"statuses": statuses,
		"abilities": abilities,
	}
	# Boss standing rule + targeting personality — always visible in the popup.
	if is_enemy:
		var description_lines: Array[String] = []
		var standing_rule: String = CombatManager.get_boss_standing_rule(str(data.get("display_name")))
		if standing_rule != "":
			description_lines.append(standing_rule)
		# The complete truth of how this enemy picks targets (Task 9).
		var personality: int = TargetingPersonality.resolve_personality(data)
		description_lines.append("TARGETING: %s — %s." % [
			TargetingPersonality.personality_name(personality),
			TargetingPersonality.personality_blurb(personality),
		])
		payload["description"] = "\n".join(description_lines)
	return payload


# Active battle statuses for the unit inspect — each entry { effects:[pip], text } renders as a
# pip beside its description. Matches the compact card's status set (_build_compact_status_tokens)
# and reuses _status_text for the wording.
static func _unit_status_entries(state: Dictionary) -> Array:
	var entries: Array = []
	if state.is_empty():
		return entries
	if bool(state.get("dead", false)):
		return [{"effects": [], "text": "Knocked out. Cannot act until revived."}]
	var burn: int = int(state.get("burn", 0))
	var burn_turns: int = int(state.get("burn_turns", 0))
	if burn > 0 and burn_turns > 0:
		# Treat a very large duration (e.g. plagueProtocol's 9999) as permanent — show no
		# turn count on the pip or in the text.
		var burn_dur: int = burn_turns if burn_turns < 999 else 0
		entries.append(_status_entry("burn", "%d" % burn, burn_dur, _status_text("burn", "%d" % burn, burn_dur)))
	var shield: int = int(state.get("shield", 0))
	if shield > 0:
		entries.append(_status_entry("shield", "%d" % shield, 0, _status_text("shield", "%d" % shield, 0)))
	# Net roll delta: temporary rfe_stacks/roll_buff PLUS permanent relic/gear modifiers
	# (mirrors combat_manager.get_roll_modifier_totals).
	var total_rfe: int = int(state.get("perm_rfe", 0))
	for stack_variant in state.get("rfe_stacks", []):
		total_rfe += int((stack_variant as Dictionary).get("amt", 0))
	var roll_delta: int = int(state.get("roll_buff", 0)) + int(state.get("perm_roll_buff", 0)) - total_rfe
	if roll_delta != 0:
		entries.append(_status_entry("rfm" if roll_delta > 0 else "roll", "%+d" % roll_delta, 0, _roll_status_text(roll_delta)))
	if bool(state.get("cloaked", false)):
		entries.append(_status_entry("cloak", EffectPip.keyword_code("cloak", "C"), 0, _status_text("cloak", "", 0)))
	if bool(state.get("warded", false)):
		entries.append(_status_entry("ward", EffectPip.keyword_code("ward", "FW"), 0, _status_text("ward", "", 0)))
	if bool(state.get("marked", false)):
		entries.append(_status_entry("mark", EffectPip.keyword_code("mark", "MK"), 0, _status_text("mark", "", 0)))
	if bool(state.get("taunting", false)):
		entries.append(_status_entry("taunt", EffectPip.keyword_code("taunt", "T"), 0, _status_text("taunt", "", 0)))
	if str(state.get("lured_by_id", "")) != "":
		entries.append(_status_entry("taunt", EffectPip.keyword_code("taunt", "T"), 0, _status_text("taunted", "", 0)))
	if int(state.get("rampage_charges", 0)) > 0:
		entries.append(_status_entry("rampage", EffectPip.keyword_code("rampage", "RA"), 0, _status_text("rampage", "", 0)))
	# pkg8.1: die statuses surface in the readout too (they render on the die).
	if int(state.get("jam_cap", 0)) > 0:
		entries.append(_status_entry("jam", "≤%d" % int(state["jam_cap"]), 0, "Die is Jammed — next roll capped at %d." % int(state["jam_cap"])))
	if bool(state.get("rewrite_pending", false)):
		entries.append(_status_entry("rewrite", "→3", 0, "Die is being Rewritten — next roll becomes 3."))
	if bool(state.get("hijack_pending", false)):
		entries.append(_status_entry("hijack", EffectPip.keyword_code("hijack", "HJ"), 0, "Hijack pending — this die will copy the squad's highest roll."))
	if int(state.get("die_freeze_turns", 0)) > 0:
		var flavor: String = str(state.get("freeze_flavor", "ice"))
		entries.append(_status_entry("freeze", "%d" % int(state["die_freeze_turns"]), 0,
			"%s — the die keeps this face and the unit acts again on it %d more time(s)." % ["Petrified" if flavor == "petrify" else "Frozen", int(state["die_freeze_turns"])]))
	if int(state.get("spike", 0)) > 0:
		entries.append(_status_entry("spike", "%d" % int(state["spike"]), 0, "Spike %d — attackers take damage this round." % int(state["spike"])))
	return entries


static func _status_entry(kind: String, value: String, duration: int, text: String) -> Dictionary:
	return {
		"effects": [{"kind": kind, "value": value, "duration": maxi(duration, 0), "scope": ""}],
		"text": text,
	}


static func _roll_status_text(delta: int) -> String:
	return "%+d to this unit's die rolls." % delta


# fix-2.2: name + one-line definition for the ±roll chip pinned to a die.
static func roll_chip_entry(delta: int) -> Dictionary:
	return _status_entry(
		"rfm" if delta > 0 else "roll", "%+d" % delta, 0,
		"Roll chip — this die's effective roll is shifted %+d by active buffs and debuffs." % delta
	)


# ── 3. Status / burn pip (long-press a status icon) ──────────────────────────────
# `status` is a normalized status dict (type, value/stacks, duration, name…). If a
# cosmetic `burn_flavor` ever exists it is used as the label; today it does NOT exist in
# the data, so we fall back to the generic keyword.
static func resolve_status(status: Dictionary) -> Dictionary:
	if status.is_empty():
		return {}
	var kind: String = str(status.get("type", status.get("name", ""))).to_lower()
	var label: String = str(status.get("burn_flavor", "")).strip_edges()
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


static func _status_keyword(kind: String) -> String:
	match kind:
		"burn":
			return "BURN"
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
		"ward":
			return "FIREWALL"
		"mark":
			return "MARKED"
	return kind.to_upper()


static func _value_label(kind: String) -> String:
	match kind:
		"burn":
			return "DAMAGE / TURN"
		"shield":
			return "ABSORB"
	return "VALUE"


static func _status_text(kind: String, value: String, duration: int) -> String:
	var turns: String = "%d turn%s" % [duration, "" if duration == 1 else "s"] if duration > 0 else ""
	match kind:
		"burn":
			return "Takes %s damage at the end of each round%s." % [value if value != "" else "some", (" for " + turns) if turns != "" else ""]
		"shield":
			return "Absorbs %s incoming damage before HP is touched." % (value if value != "" else "")
		"frozen", "freeze", "die_freeze":
			return "Die result is locked — it keeps this face and the unit acts again on it%s." % ((" for " + turns) if turns != "" else "")
		"cloak":
			return "Untargetable by hostile single-target abilities; friendly picks stay legal. Breaks when this unit deals damage or is hit by an AoE."
		"taunt":
			return "Taunting — hostile units can only target this unit."
		"taunted":
			return "Taunted — this unit can only target the taunter."
		"rampage":
			return "Deals double damage this turn."
		"ward":
			return "Blocks the next ability that targets this unit, then breaks."
		"mark":
			return "The next hit on this unit deals +50%, then the Mark is consumed."
		"jam":
			return "Die is Jammed — the next roll is capped%s." % ((" at " + value) if value != "" else "")
		"rewrite":
			return "Die is being Rewritten — the next roll becomes 3."
		"hijack":
			return "Hijack pending — this die will copy the squad's highest roll."
		"spike":
			return "Spike %s — any attacker that connects this round takes that much back." % (value if value != "" else "")
	return ""


static func _status_accent(kind: String) -> Color:
	match kind:
		"burn":
			return PixelUI.COLOR_DEBUFF
		"shield":
			return PixelUI.COLOR_SHIELD
		"frozen", "freeze", "die_freeze":
			return PixelUI.DT_CYAN
		"cloak":
			return PixelUI.COLOR_SHIELD
	return PixelUI.INSPECT_BORDER
