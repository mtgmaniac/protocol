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
	"wipeShields": "wipe_shields",
	"leech": "leech",
	"lifestealPct": "leech",
	"mark": "mark",
	"spike": "spike",
	"packBonus": "pack_bonus",
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


# The authored eff string ONLY ("8 dmg, leech") — the multi-line keyword
# glossary definitions were CUT from the popup (Kev 2026-07-10: an 8-line
# definition per named ability ate the screen; keyword rules are taught by
# the first-sighting primers and live in the help-menu glossary).
static func _ability_inspect_text(raw: Dictionary, fallback: String = "") -> String:
	return str(raw.get("eff", fallback))


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
	# No role subtitle (Kev 2026-07-10: "HEALER / COMBAT AUGMENTOR" is irrelevant
	# here) — the header carries just the name; statuses render below it.
	# No portrait, no separate roll-range table — each ability carries its own roll band.
	var payload: Dictionary = {
		"accent": _side_accent(side),
		"header": {
			"title": str(data.get("display_name")),
			"subtitle": "",
		},
		"statuses": statuses,
		"abilities": abilities,
	}
	if is_enemy:
		var description_lines: Array[String] = []
		var standing_rule: String = CombatManager.get_boss_standing_rule(str(data.get("display_name")))
		if standing_rule != "":
			description_lines.append(standing_rule)
		# WHO this enemy is targeting right now — not HOW it picks (Kev
		# 2026-07-10: the personality explainer was cut from the popup).
		var target_display: String = str(state.get("target_display", "")).strip_edges()
		if target_display != "" and target_display != "--":
			description_lines.append("TARGETING: %s" % target_display.to_upper())
		if not description_lines.is_empty():
			payload["description"] = "\n".join(description_lines)
	else:
		# Equipped gear (Kev 2026-07-10): icon + name + pips + description,
		# loadout-row style, so the long-press shows what the unit is wearing.
		payload["gear"] = _unit_gear_entries(str(data.get("id")))
	return payload


static func _unit_gear_entries(unit_id: String) -> Array:
	var entries: Array = []
	if unit_id == "":
		return entries
	var gs: Node = Engine.get_main_loop().root.get_node_or_null("/root/GameState") if Engine.get_main_loop() is SceneTree else null
	if gs == null:
		return entries
	var gear_map: Dictionary = gs.get("gear_by_unit")
	for gear_id_variant in gear_map.get(unit_id, []):
		var item: ItemData = DataManager.get_item(str(gear_id_variant)) as ItemData
		if item == null:
			continue
		entries.append({
			"icon": item.icon,
			"name": item.display_name,
			"effects": EffectPip.effects_from_passive(item.effect, item.target_kind),
			"text": item.description,
		})
	return entries


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
	# One SHORT line each (Kev 2026-07-10 trim).
	if int(state.get("jam_cap", 0)) > 0:
		entries.append(_status_entry("jam", "≤%d" % int(state["jam_cap"]), 0, _status_text("jam", str(state["jam_cap"]), 0)))
	if bool(state.get("rewrite_pending", false)):
		entries.append(_status_entry("rewrite", "→3", 0, _status_text("rewrite", "", 0)))
	if bool(state.get("hijack_pending", false)):
		entries.append(_status_entry("hijack", EffectPip.keyword_code("hijack", "HJ"), 0, _status_text("hijack", "", 0)))
	if int(state.get("die_freeze_turns", 0)) > 0:
		var flavor: String = str(state.get("freeze_flavor", "ice"))
		entries.append(_status_entry("freeze", "%d" % int(state["die_freeze_turns"]), 0,
			"%s: die locked on this face (%d more)." % ["Petrified" if flavor == "petrify" else "Frozen", int(state["die_freeze_turns"])]))
	if int(state.get("spike", 0)) > 0:
		entries.append(_status_entry("spike", "%d" % int(state["spike"]), 0, _status_text("spike", str(state["spike"]), 0)))
	return entries


static func _status_entry(kind: String, value: String, duration: int, text: String) -> Dictionary:
	return {
		"effects": [{"kind": kind, "value": value, "duration": maxi(duration, 0), "scope": ""}],
		"text": text,
	}


static func _roll_status_text(delta: int) -> String:
	return "%+d to rolls." % delta


# fix-2.2: name + one-line definition for the ±roll chip pinned to a die.
static func roll_chip_entry(delta: int) -> Dictionary:
	return _status_entry(
		"rfm" if delta > 0 else "roll", "%+d" % delta, 0,
		"%+d to this die's rolls." % delta
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


# ── 7. Encounter (long-press the squad-select banner) ───────────────────────────
# The operation blurb lives HERE (squad-select redesign): the banner shows only
# name + threat; long-press surfaces the full flavor copy, verbatim from data.
static func resolve_encounter(op: OperationData, threat_level: int, threat_max: int) -> Dictionary:
	if op == null:
		return {}
	return {
		"accent": _side_accent("enemy"),
		"header": {"title": op.display_name.to_upper(), "subtitle": "ENCOUNTER"},
		"stats": [{"label": "THREAT", "value": "LV %d / %d" % [threat_level, threat_max]}],
		"description": op.blurb,
	}


# ── helpers ─────────────────────────────────────────────────────────────────────
static func _side_accent(side: String) -> Color:
	return PixelUI.DT_ENEMY_BORDER if side == "enemy" else PixelUI.DT_HERO_BORDER


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


# One SHORT line per active effect (Kev 2026-07-10: the freeze / -roll / cloak
# texts ran multi-line — trimmed hard; the rule details live in the glossary).
static func _status_text(kind: String, value: String, duration: int) -> String:
	var turns: String = "%d turn%s" % [duration, "" if duration == 1 else "s"] if duration > 0 else ""
	match kind:
		"burn":
			return "Takes %s damage each round%s." % [value if value != "" else "some", (" for " + turns) if turns != "" else ""]
		"shield":
			return "Absorbs %s incoming damage." % (value if value != "" else "")
		"frozen", "freeze", "die_freeze":
			return "Die locked on this face%s." % ((" for " + turns) if turns != "" else "")
		"cloak":
			return "Can't be targeted; breaks on dealing damage."
		"taunt":
			return "Hostiles can only target this unit."
		"taunted":
			return "Can only target the taunter."
		"rampage":
			return "Next hit deals double damage."
		"ward":
			return "Blocks the next ability, then breaks."
		"mark":
			return "Next hit on this unit deals +50%."
		"jam":
			return "Next roll capped%s." % ((" at " + value) if value != "" else "")
		"rewrite":
			return "Next roll becomes 3."
		"hijack":
			return "Next roll copies the squad's highest die."
		"spike":
			return "Attackers take %s back this round." % (value if value != "" else "damage")
	return ""


static func _status_accent(kind: String) -> Color:
	match kind:
		"burn":
			return PixelUI.COLOR_BURN
		"shield":
			return PixelUI.COLOR_SHIELD
		"frozen", "freeze", "die_freeze":
			return PixelUI.DT_CYAN
		"cloak":
			return PixelUI.COLOR_SHIELD
	return PixelUI.INSPECT_BORDER
