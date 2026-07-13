# Authoritative sweep for the 2026-07-13 pip fixes — uses the REAL
# EffectPip.effects_from_ability_raw / effects_from_passive so the report is
# exactly what renders. Two sweeps:
#   A. every ability/passive carrying a roll-modifier — name, magnitude,
#      backend duration, and EFFECTIVE turns (buffs shape N-1 upcoming rolls;
#      debuffs shape N — TRUTH.md #10 / roll-modifier duration rule).
#   B. every ability/passive that emits a DUPLICATE scope marker (same scope
#      more than once on one pip).
# Read-only. Run: godot --headless --path . -s scripts/debug/rollbuff_scope_audit.gd
extends SceneTree

# Runtime load (not preload): effect_pip.gd references the DataManager autoload,
# which only resolves once the tree is up — the documented -s gotcha.
var EffectPipScript: GDScript = null


func _initialize() -> void:
	await process_frame
	EffectPipScript = load("res://scripts/ui/effect_pip.gd")
	var heroes: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/raw/heroes.data.json"))
	var enemies: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/raw/enemies.data.json"))
	var gear: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/raw/gear.data.json"))
	var relics: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/raw/relics.data.json"))

	var roll_rows: Array = []   # [owner, name, kind, mag, backend, effective]
	var dup_rows: Array = []    # [owner, name, scope, count, eff_summary]

	# ── abilities (hero base + evo, enemy per-band) via effects_from_ability_raw
	for h_variant in heroes["heroes"]:
		var h: Dictionary = h_variant
		for a in h.get("abilities", []):
			_scan_ability(str(h["id"]), a, "hero", roll_rows, dup_rows)
		for e in h.get("evolutions", []):
			for a in (e as Dictionary).get("abilities", []):
				_scan_ability("%s:%s" % [str(h["id"]), str((e as Dictionary).get("name", ""))], a, "hero", roll_rows, dup_rows)
	for etype in enemies["enemyAbilities"]:
		var bands: Dictionary = enemies["enemyAbilities"][etype]
		for band in bands:
			_scan_ability("enemy:%s" % str(etype), bands[band], "enemy", roll_rows, dup_rows)

	# ── passives (gear + relic) via effects_from_passive. gear.data.json is
	# {"gear":[...]}; relics.data.json is a bare [...] list.
	for src_name in ["gear", "relic"]:
		var list: Array = (gear as Dictionary).get("gear", []) if src_name == "gear" else (relics as Array)
		for item_variant in list:
			var item: Dictionary = item_variant
			var eff: Variant = item.get("effect", null)
			var effs: Array = eff if eff is Array else ([eff] if eff is Dictionary else [])
			for e in effs:
				if not (e is Dictionary):
					continue
				var pips: Array = EffectPipScript.effects_from_passive(e as Dictionary)
				_scan_pips("%s:%s" % [src_name, str(item.get("id", item.get("name", "?")))], str(item.get("name", "?")), pips, roll_rows, dup_rows, e)

	print("\n===== SWEEP A: roll-modifier durations =====")
	print("%-26s %-20s %-6s %-4s %-8s %s" % ["owner", "ability", "kind", "mag", "backend", "effective"])
	for r in roll_rows:
		print("%-26s %-20s %-6s %-4s %-8s %s" % r)

	print("\n===== SWEEP B: duplicate scope markers =====")
	if dup_rows.is_empty():
		print("(none)")
	for r in dup_rows:
		print("%-26s %-22s scope='%s' x%d  | %s" % r)

	print("\n[AUDIT] roll-modifiers: %d · duplicate-marker abilities: %d" % [roll_rows.size(), dup_rows.size()])
	quit(0)


func _scan_ability(owner: String, raw_variant: Variant, side: String, roll_rows: Array, dup_rows: Array) -> void:
	var raw: Dictionary = raw_variant
	var name: String = str(raw.get("name", "?"))
	var pips: Array = EffectPipScript.effects_from_ability_raw(raw, side)
	_scan_pips(owner, name, pips, roll_rows, dup_rows, raw)


func _scan_pips(owner: String, name: String, pips: Array, roll_rows: Array, dup_rows: Array, raw: Dictionary) -> void:
	# Sweep A: roll modifiers. kind "rfm" = buff (shapes N-1); kind "roll" =
	# debuff/enemy-facing (shapes N). Report both with their durations.
	var scope_counts: Dictionary = {}
	var scope_summary: Array = []
	for pip_variant in pips:
		var pip: Dictionary = pip_variant
		var kind: String = str(pip.get("kind", ""))
		var scope: String = str(pip.get("scope", ""))
		var dur: int = int(pip.get("duration", 0))
		if scope == "self" or scope == "all" or scope == "lowest":
			scope_counts[scope] = int(scope_counts.get(scope, 0)) + 1
			scope_summary.append("%s(%s%s)" % [kind, str(pip.get("value", "")), "/" + scope])
		if kind == "rfm" or (kind == "roll" and dur > 0):
			var is_buff: bool = kind == "rfm"
			var effective: String = ("%d" % maxi(dur - 1, 0)) if is_buff else ("%d" % dur)
			roll_rows.append([owner, name, ("buff" if is_buff else "debuff"),
				str(pip.get("value", "")), str(dur) + "t", effective + " roll(s)"])
	for scope in scope_counts:
		if int(scope_counts[scope]) > 1:
			dup_rows.append([owner, name, str(scope), int(scope_counts[scope]), ", ".join(scope_summary)])
