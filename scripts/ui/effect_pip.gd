class_name EffectPip
extends RefCounted

## Single source of truth for ability / item / gear / relic effect pips.
## Notation: `)value(` = all, `(value)` = self, plain = single target.
## Keyword letters: P C T CO RA; revive R{n}%; heal-lowest ↓; freeze = icon + superscript.

# Batch 155-179 gave every keyword its own pip icon. Only `rampage` and `tag`
# remain iconless (rendered as their letter/text). Everything else draws its icon.
const LETTER_ONLY_KINDS: Array[String] = ["rampage", "tag"]

# fix-2.6: keyword pip codes are single-sourced from keywords.data.json (the
# "code" field) — battle pips, inspect rows, and the help menu all read the
# same registry. Fallbacks only guard a missing registry entry.
static var _keyword_code_cache: Dictionary = {}
static var _keyword_codes_loaded: bool = false


static func keyword_code(keyword_id: String, fallback: String) -> String:
	if not _keyword_codes_loaded:
		_keyword_codes_loaded = true
		for kw_variant in (DataManager.get_keywords().get("keywords", []) as Array):
			var kw: Dictionary = kw_variant
			if str(kw.get("code", "")) != "":
				_keyword_code_cache[str(kw.get("id", ""))] = str(kw.get("code", ""))
	return str(_keyword_code_cache.get(keyword_id, fallback))

const PROFILE_READOUT := {
	"icon_size": 56,
	"value_font": 80,
	"duration_ratio": 0.6,
	"icon_value_gap": 4,
	"group_min_width": 90,
	"outline": 3,
	"duration_outline": 2,
}

const PROFILE_CARD := {
	"icon_size": 40,
	"value_font": 48,
	"duration_ratio": 0.6,
	"icon_value_gap": 4,
	"group_min_width": 72,
	"outline": 2,
	"duration_outline": 2,
}




# Self stays parenthesized; "all" no longer uses )..( — the AoE marker icon is
# appended after the value by build_group instead (batch 161).
static func format_scoped(text: String, scope: String) -> String:
	match scope:
		"self":
			return "(%s)" % text
		_:
			return text


static func is_letter_only_kind(kind: String) -> bool:
	return kind.to_lower() in LETTER_ONLY_KINDS


static func pip_key_for_effect(effect: Dictionary, _side: String = "hero") -> String:
	var kind: String = str(effect.get("kind", ""))
	# The sign alone drives the roll channel — +roll = green (roll_up), -roll =
	# gold (roll_down) — on both sides. revive/pierce/taunt/etc. now resolve to
	# their own icon key (batch 155-179), so no per-kind overrides here.
	var value: String = str(effect.get("value", ""))
	return PixelUI.pip_key_for_effect(kind, value)


# Kinds that now carry an icon AND were authored with a leading keyword code in
# their value (e.g. "SP3", "CH×2", "BR", "MK"). The icon carries the keyword, so
# we drop the letters and keep only the numeric/×N/% remainder.
const CODE_ICON_KINDS: Array[String] = ["pierce", "cloak", "taunt", "ward", "mark", "leech", "breach", "chain", "detonate", "execute", "jam", "rewrite", "hijack", "spike", "siphon", "accrete"]


static func display_text_for_effect(effect: Dictionary) -> String:
	var kind: String = str(effect.get("kind", "")).to_lower()
	var raw_value: String = str(effect.get("value", "")).strip_edges()
	var scope: String = str(effect.get("scope", ""))
	var text: String

	match kind:
		"rampage":
			text = keyword_code("rampage", "RA")  # no icon → keep the letters
		"revive":
			text = "%s%%" % raw_value.trim_suffix("%")  # icon + "50%"
		"heal":
			if raw_value in ["LOW", "↓"]:
				text = "↓"
			else:
				text = raw_value.to_upper()
		"roll", "rfe", "rfm":
			text = PixelUI.format_amount_no_sign(raw_value.to_upper())
		"protocol", "tag":
			text = raw_value.to_upper()
		_:
			if kind in CODE_ICON_KINDS:
				text = _numeric_suffix(raw_value)
			else:
				text = raw_value.to_upper()

	return format_scoped(text, scope)


# Drop a leading run of letters (the keyword code) from a pip value, keeping any
# numeric / ×N / % remainder. "SP3" -> "3", "CH×2" -> "×2", "BR" -> "".
static func _numeric_suffix(value: String) -> String:
	var i: int = 0
	while i < value.length():
		var ch: String = value[i]
		var is_alpha: bool = (ch >= "A" and ch <= "Z") or (ch >= "a" and ch <= "z")
		if not is_alpha:
			break
		i += 1
	return value.substr(i)


# Must mirror build_group's actual children (leading keyword icon · value ·
# duration superscript · trailing AoE marker). The pre-icon version hardcoded a
# 48px base and ignored the AoE marker entirely, so icon-bearing rows
# under-measured and edge readouts clipped off-screen (UI review DB-2).
static func estimate_display_width(effect: Dictionary, profile: Dictionary) -> float:
	var value_font: int = int(profile.get("value_font", 48))
	var icon_size: float = float(profile.get("icon_size", 40))
	var gap: float = float(profile.get("icon_value_gap", 4))
	var effect_kind: String = str(effect.get("kind", ""))
	var width := 0.0
	# Leading keyword icon (letter-only kinds render text instead of an icon).
	if not is_letter_only_kind(effect_kind) and PixelUI.pip_texture_for_key(pip_key_for_effect(effect)) != null:
		width += icon_size + gap
	# m5x7's real glyph advance is ~0.375x the font size (measured: 21px/char at
	# font 56). The old 0.3 guess under-measured wide values, so borderline tags
	# picked a presentation tier they couldn't actually fit (die-tag overflow).
	width += maxf(28.0, float(display_text_for_effect(effect).length()) * float(value_font) * 0.38)
	var duration: int = int(effect.get("duration", 0))
	if duration > 1:
		var sup_size: int = maxi(28, int(round(float(value_font) * float(profile.get("duration_ratio", 0.6)))))
		width += float(sup_size) * 0.75
	# The "hits all" marker sits AFTER the value (batch 161).
	if str(effect.get("scope", "")) == "all":
		width += gap + icon_size * 0.95
	return maxf(float(profile.get("group_min_width", 64)), width)


static func build_group(
	effect: Dictionary,
	profile: Dictionary,
	side: String = "hero"
) -> Control:
	var effect_kind: String = str(effect.get("kind", ""))
	var pip_key: String = pip_key_for_effect(effect, side)
	var color_key: String = pip_key if pip_key != "" else effect_kind
	var value_color: Color = _value_color_for_kind(color_key, effect_kind)
	var duration: int = int(effect.get("duration", 0))
	var letter_only: bool = is_letter_only_kind(effect_kind)

	var group := HBoxContainer.new()
	group.mouse_filter = Control.MOUSE_FILTER_STOP
	group.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	group.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	group.custom_minimum_size = Vector2(float(profile.get("group_min_width", 64)), 0)
	group.alignment = BoxContainer.ALIGNMENT_CENTER
	group.add_theme_constant_override("separation", int(profile.get("icon_value_gap", 4)))

	if not letter_only:
		var icon_texture: Texture2D = PixelUI.pip_texture_for_key(pip_key)
		if icon_texture != null:
			var icon_size: int = int(profile.get("icon_size", 40))
			var icon_rect := TextureRect.new()
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon_rect.custom_minimum_size = Vector2(icon_size, icon_size)
			icon_rect.texture = icon_texture
			icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			# Roll is one gold d20; a +roll (roll_up) tints green, −roll stays gold.
			if pip_key == "roll_up":
				icon_rect.modulate = PixelUI.COLOR_HEAL
			group.add_child(icon_rect)

	if effect_kind == "freeze":
		if duration > 1:
			group.add_child(_make_duration_superscript(duration, value_color, profile))
	else:
		group.add_child(_make_value_display(effect, profile, side))

	# AoE marker (batch 161): replaces the old )value( notation — a small
	# "hits all" icon that sits AFTER the value.
	if str(effect.get("scope", "")) == "all":
		var aoe_texture: Texture2D = PixelUI.pip_texture_for_key("aoe")
		if aoe_texture != null:
			var aoe_size: int = int(round(float(profile.get("icon_size", 40)) * 0.95))
			var aoe_rect := TextureRect.new()
			aoe_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			aoe_rect.custom_minimum_size = Vector2(aoe_size, aoe_size)
			aoe_rect.texture = aoe_texture
			aoe_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			aoe_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			aoe_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			group.add_child(aoe_rect)

	return group


static func effects_from_ability_raw(raw: Dictionary, side: String = "hero") -> Array:
	var effects: Array = []
	var damage: int = int(raw.get("dmg", 0))
	var damage_min: int = int(raw.get("dMin", 0))
	var damage_max: int = int(raw.get("dMax", 0))
	var blast_all: bool = bool(raw.get("blastAll", false))
	if damage > 0:
		_append_effect(effects, "dmg", "%d" % damage, 0, "all" if blast_all else "")
	elif damage_min > 0 or damage_max > 0:
		_append_effect(
			effects, "dmg", "%d-%d" % [damage_min, damage_max], 0, "all" if blast_all else ""
		)

	var burn: int = int(raw.get("burn", 0))
	if burn > 0:
		_append_effect(effects, "burn", "%d" % burn, int(raw.get("burnT", 0)))

	var shield_all: bool = bool(raw.get("shieldAll", false))
	var shield_self: bool = (
		not shield_all
		and not bool(raw.get("shieldAllyAll", false))
		and not bool(raw.get("shTgt", false))
	)
	var shield: int = int(raw.get("shield", 0))
	if shield > 0 and not bool(raw.get("shieldAllyAll", false)):
		var shield_scope: String = "all" if shield_all else ("self" if shield_self else "")
		_append_effect(effects, "shield", "%d" % shield, 0, shield_scope)
	var shield_ally: int = int(raw.get("shieldAlly", 0))
	if bool(raw.get("shieldAllyAll", false)) and shield_ally > 0:
		_append_effect(effects, "shield", "%d" % shield_ally, 0, "all")
	elif shield_ally > 0:
		_append_effect(effects, "shield", "%d" % shield_ally, 0)

	var heal_all: bool = bool(raw.get("healAll", false))
	var heal_self: bool = (
		not heal_all
		and not bool(raw.get("healTgt", false))
		and not bool(raw.get("healLowest", false))
	)
	var heal: int = int(raw.get("heal", 0))
	if heal > 0:
		var heal_scope: String = "all" if heal_all else ("self" if heal_self else "")
		_append_effect(effects, "heal", "%d" % heal, 0, heal_scope)
	if bool(raw.get("healLowest", false)):
		_append_effect(effects, "heal", "↓")

	var rfe: int = int(raw.get("rfe", 0))
	if rfe > 0:
		var rfe_scope: String = "all" if bool(raw.get("rfeAll", false)) else ""
		_append_effect(effects, "roll", "-%d" % rfe, int(raw.get("rfT", 0)), rfe_scope)

	var rfm: int = int(raw.get("rfm", 0))
	if rfm > 0:
		if side == "enemy":
			# Enemy rfm is hostile: "-N to a hero's roll". Render it as the
			# signed reduction it is (amber roll_down channel).
			_append_effect(effects, "roll", "-%d" % rfm, int(raw.get("rfmT", 0)))
		else:
			var rfm_scope: String = ""
			if not bool(raw.get("rfmTgt", false)):
				rfm_scope = "all"
			_append_effect(effects, "rfm", "+%d" % rfm, int(raw.get("rfmT", 0)), rfm_scope)

	# Enemy roll buff (erb): the enemy-side mirror of rfm. fix-1.3 — pure-erb
	# abilities (Checksum Scribe's Checksum Pass et al.) rendered zero pips.
	var erb: int = int(raw.get("erb", 0))
	if erb > 0:
		_append_effect(effects, "rfm", "+%d" % erb, int(raw.get("erbT", 0)), "all" if bool(raw.get("erbAll", false)) else "self")

	if bool(raw.get("ignSh", false)):
		_append_effect(effects, "pierce", keyword_code("pierce", "P"))
	var chain_jumps: int = int(raw.get("chain", 0))
	if chain_jumps > 0:
		var chain_code: String = keyword_code("chain", "CH")
		_append_effect(effects, "chain", chain_code if chain_jumps == 1 else "%s×%d" % [chain_code, chain_jumps])
	if bool(raw.get("detonate", false)):
		# pkg8 upgrades this to show the live computed value when the target is known
		_append_effect(effects, "detonate", keyword_code("detonate", "DT"))
	if bool(raw.get("execute", false)):
		_append_effect(effects, "execute", keyword_code("execute", "EX"))
	if bool(raw.get("breachAll", false)):
		_append_effect(effects, "breach", keyword_code("breach", "BR"), 0, "all")
	elif bool(raw.get("breach", false)):
		_append_effect(effects, "breach", keyword_code("breach", "BR"))
	elif bool(raw.get("wipeShields", false)):
		# Enemy "wipe shields, then N dmg" — Breach semantics against the squad.
		_append_effect(effects, "breach", keyword_code("breach", "BR"), 0, "all")
	if bool(raw.get("leech", false)):
		_append_effect(effects, "leech", keyword_code("leech", "LC"))
	elif int(raw.get("lifestealPct", 0)) > 0:
		# Enemy lifesteal is authored as a percent; same Leech keyword on the card.
		_append_effect(effects, "leech", keyword_code("leech", "LC"))
	if bool(raw.get("mark", false)):
		_append_effect(effects, "mark", keyword_code("mark", "MK"))
	var spike_value: int = int(raw.get("spike", 0))
	if spike_value > 0:
		_append_effect(effects, "spike", "%s%d" % [keyword_code("spike", "SP"), spike_value])
	if bool(raw.get("jamAll", false)):
		_append_effect(effects, "jam", keyword_code("jam", "JM"), 0, "all")
	elif bool(raw.get("jam", false)):
		_append_effect(effects, "jam", keyword_code("jam", "JM"))
	if bool(raw.get("rewrite", false)):
		_append_effect(effects, "rewrite", keyword_code("rewrite", "RW"))
	if bool(raw.get("hijack", false)):
		_append_effect(effects, "hijack", keyword_code("hijack", "HJ"))
	var siphon_amount: int = int(raw.get("siphon", 0))
	if siphon_amount > 0:
		_append_effect(effects, "siphon", "%s%d" % [keyword_code("siphon", "SI"), siphon_amount])
	if bool(raw.get("cloak", false)):
		_append_effect(effects, "cloak", keyword_code("cloak", "C"), 0, "self")
	if bool(raw.get("ward", false)):
		_append_effect(effects, "ward", keyword_code("ward", "FW"), 0, "" if bool(raw.get("wardTgt", false)) else "self")

	var freeze_turns: int = maxi(
		maxi(int(raw.get("freezeAnyDice", 0)), int(raw.get("freezeEnemyDice", 0))),
		int(raw.get("freezeAllEnemyDice", 0))
	)
	if freeze_turns > 0:
		_append_effect(effects, "freeze", "", freeze_turns)

	if bool(raw.get("taunt", false)) or bool(raw.get("enemySelfTaunt", false)):
		_append_effect(effects, "taunt", keyword_code("taunt", "T"))

	var revive_pct: int = int(raw.get("revivePct", 50))
	if bool(raw.get("reviveAll", false)):
		_append_effect(effects, "revive", "%d" % revive_pct, 0, "all")
	elif bool(raw.get("revive", false)):
		_append_effect(effects, "revive", "%d" % revive_pct)

	if bool(raw.get("grantRampageAll", false)):
		_append_effect(effects, "rampage", keyword_code("rampage", "RA"), 0, "all")
	elif int(raw.get("grantRampage", 0)) > 0:
		_append_effect(effects, "rampage", keyword_code("rampage", "RA"), 0, "self")

	return effects.slice(0, 3)


static func effects_from_passive(effect: Dictionary, target_kind: String = "") -> Array:
	var effects: Array = []
	var effect_type: String = str(effect.get("type", ""))
	match effect_type:
		"heal":
			_append_effect(effects, "heal", "%d" % int(effect.get("amount", 0)))
		"healAll":
			_append_effect(effects, "heal", "%d" % int(effect.get("amount", 0)), 0, "all")
		"shield":
			_append_effect(effects, "shield", "%d" % int(effect.get("amount", 0)), 0, "self")
		"shieldAll":
			_append_effect(effects, "shield", "%d" % int(effect.get("amount", 0)), 0, "all")
		"rollBuff":
			_append_effect(effects, "rfm", "+%d" % int(effect.get("amount", 0)), int(effect.get("turns", 0)))
		"rollBonus", "heroStartRollBuff":
			_append_effect(effects, "rfm", "%d" % int(effect.get("amount", 0)), 0, "self")
		"revive":
			_append_effect(effects, "revive", "%d" % int(effect.get("pct", 0)))
		"cloak":
			_append_effect(effects, "cloak", "C", 0, "self")
		"cloakAll":
			_append_effect(effects, "cloak", "C", 0, "all")
		"enemyRfe":
			_append_effect(effects, "roll", "-%d" % int(effect.get("amount", 0)), int(effect.get("rfT", 0)))
		"enemyDmg":
			_append_effect(effects, "dmg", "%d" % int(effect.get("amount", 0)))
		"enemyBurn":
			_append_effect(effects, "burn", "%d" % int(effect.get("amount", 0)), int(effect.get("burnT", 0)))
		"gainProtocol":
			_append_effect(effects, "protocol", "+%d" % int(effect.get("amount", 0)))
		"battleStartShield":
			_append_effect(effects, "shield", "%d" % int(effect.get("amount", 0)), 0, "self")
		"maxHpBonus":
			_append_effect(effects, "heal", "+%d" % int(effect.get("amount", 0)))
		"burnDmgBonus", "burnAmplified":
			_append_effect(effects, "burn", "+%d" % int(effect.get("amount", effect.get("bonus", 0))))
		"battleStartCloak":
			_append_effect(effects, "cloak", "C", 0, "self")
		"battleStartCloakRoll":
			_append_effect(effects, "cloak", "C", 0, "self")
			var roll_amt: int = int(effect.get("rollAmount", 0))
			if roll_amt > 0:
				_append_effect(effects, "rfm", "%d" % roll_amt, 0, "self")
		"healOnKill", "allyDeathHealAll":
			var scope: String = "all" if effect_type == "allyDeathHealAll" else ""
			_append_effect(effects, "heal", "%d" % int(effect.get("amount", 0)), 0, scope)
		"protocolOnBattleStart", "protocolOnKill", "protocolOnKillAny":
			_append_effect(effects, "protocol", "+%d" % int(effect.get("amount", 0)), 0, "self")
		"protocolCarryover":
			_append_effect(effects, "protocol", "%d%%" % int(effect.get("amount", 0)))
		"surviveOnce":
			_append_effect(effects, "tag", "1HP", 0, "self")
		"firstAbilityDmgBonus":
			_append_effect(effects, "dmg", "+%d" % int(effect.get("amount", 0)))
		"dmgReduction":
			_append_effect(effects, "shield", "%d" % int(effect.get("amount", 0)), 0, "self")
		"enemyDmgMult":
			_append_effect(effects, "dmg", "%d%%" % int(round(float(effect.get("mult", 1.0)) * 100.0)))
		"battleStartHalfHp":
			_append_effect(effects, "dmg", "50%", 0, "self")
		"heroShieldPerTurn":
			_append_effect(effects, "shield", "%d" % int(effect.get("amount", 0)), 0, "self")
		"heroHealPerTurn":
			_append_effect(effects, "heal", "%d" % int(effect.get("amount", 0)), 0, "self")
		"enemyBurnPermanent":
			_append_effect(effects, "burn", "%d" % int(effect.get("amount", 0)))
		"heroDmgMult":
			_append_effect(effects, "dmg", "%d%%" % int(round(float(effect.get("mult", 1.0)) * 100.0)), 0, "self")
		"enemyStartRfe":
			_append_effect(effects, "roll", "-%d" % int(effect.get("amount", 0)), 0, "all")
		"auraEnemyDmg":
			_append_effect(effects, "dmg", "%d" % int(effect.get("amount", 0)))
		"protocolOnItemUse":
			_append_effect(effects, "protocol", "FREE", 0, "self")
		"enemyHpEscalation":
			_append_effect(effects, "burn", "-%d" % int(effect.get("reductionPerBattle", 0)))
		"chainReaction":
			_append_effect(effects, "dmg", "%d" % int(effect.get("amount", 0)))
		"lifesteal":
			_append_effect(effects, "heal", "%d%%" % int(effect.get("amount", 0)))
		"firstAbilityEcho":
			_append_effect(effects, "tag", "ECHO")
		"shieldPierce":
			_append_effect(effects, "pierce", "P")
		"healShieldBonus":
			_append_effect(effects, "shield", "%d" % int(effect.get("amount", 0)))
		"healGrantsShieldAll":
			_append_effect(effects, "shield", "%d" % int(effect.get("amount", 0)), 0, "all")
		"lowHpSquadRollBuff":
			_append_effect(effects, "rfm", "%d" % int(effect.get("amount", 0)), 0, "all")
		"critResolveTwice":
			_append_effect(effects, "tag", "2X")
		"rewardsNoCommon":
			_append_effect(effects, "tag", "RARE+")
		"reviveNoPenalty":
			_append_effect(effects, "revive", "100")
		"battleStartConsumable":
			_append_effect(effects, "tag", "+%d" % int(effect.get("amount", 0)))
		"enemyRerollDie":
			_append_effect(effects, "roll", "REROLL")
		"enemyRerollAll":
			_append_effect(effects, "roll", "REROLL", 0, "all")
		"anyDieFreeze":
			_append_effect(effects, "freeze", "", int(effect.get("repeats", 0)))
		"enemyDieFreezeAll":
			_append_effect(effects, "freeze", "", int(effect.get("repeats", 0)), "all")
		_:
			if target_kind != "":
				_append_effect(effects, "tag", target_kind.to_upper())
	return effects


static func ability_readout_payload(raw: Dictionary, side: String = "hero") -> Dictionary:
	return {"effects": effects_from_ability_raw(raw, side), "target": ""}


static func _append_effect(
	effects: Array,
	kind: String,
	value: String,
	duration: int = 0,
	scope: String = ""
) -> void:
	effects.append({
		"kind": kind,
		"value": value,
		"duration": maxi(duration, 0),
		"scope": scope,
	})


static func _value_color_for_kind(color_key: String, effect_kind: String) -> Color:
	if effect_kind.to_lower() in ["protocol", "tag"]:
		return PixelUI.GOLD_ACCENT if effect_kind == "protocol" else PixelUI.effect_value_color("heal")
	return PixelUI.effect_value_color(color_key)


static func _make_value_display(effect: Dictionary, profile: Dictionary, side: String) -> Control:
	var display_value: String = display_text_for_effect(effect)
	var pip_key: String = pip_key_for_effect(effect, side)
	var color_key: String = pip_key if pip_key != "" else str(effect.get("kind", ""))
	var value_color: Color = _value_color_for_kind(color_key, str(effect.get("kind", "")))
	var duration: int = int(effect.get("duration", 0))
	var value_font: int = int(profile.get("value_font", 48))
	var outline: int = int(profile.get("outline", 2))

	if duration <= 1:
		return _make_text_label(display_value, value_font, value_color, outline)

	var cluster := HBoxContainer.new()
	cluster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cluster.alignment = BoxContainer.ALIGNMENT_END
	cluster.add_theme_constant_override("separation", 0)
	cluster.add_child(
		_make_text_label(display_value, value_font, value_color, outline, VERTICAL_ALIGNMENT_BOTTOM)
	)
	cluster.add_child(_make_duration_superscript(duration, value_color, profile))
	return cluster


static func _make_duration_superscript(duration: int, color: Color, profile: Dictionary) -> Label:
	var value_font: int = int(profile.get("value_font", 48))
	var ratio: float = float(profile.get("duration_ratio", 0.6))
	var sup_size: int = maxi(28, int(round(float(value_font) * ratio)))
	var outline: int = int(profile.get("duration_outline", 2))
	return _make_text_label(str(duration), sup_size, color, outline, VERTICAL_ALIGNMENT_TOP)


static func _make_text_label(
	text: String,
	font_size: int,
	color: Color,
	outline: int = 1,
	vertical: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER
) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.custom_minimum_size = Vector2(0, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = vertical
	label.clip_text = false
	PixelUI.apply_pixel_font(label)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.015, 0.025, 0.98))
	label.add_theme_constant_override("outline_size", outline)
	return label
