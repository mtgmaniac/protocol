# Glyph coverage gate (Build #3): allow_system_fallback=false (Build #2) means
# a codepoint m5x7 cannot render is now a visible TOFU BOX instead of a silent
# system-font substitute (confirmed on device: U+2014 em dash in the Tactical
# Reference copy). This walks every player-facing string — the data layer and
# the UI copy — and fails on any character the ACTUAL font lacks (has_char(),
# never a hardcoded blocklist), so the next stray codepoint dies in the gate,
# not on a phone.
#
# Sources swept:
#   - data/raw/*.json           — every string VALUE, recursively
#   - scripts/ui|battle|autoloads/*.gd — string literals (line parser: tracks
#     quotes/escapes, stops at comments; multiline strings are out of scope —
#     none exist in UI copy today)
#   - scenes/**/*.tscn          — authored `text = "..."` properties
# scripts/debug + scripts/sim are excluded (not player-facing).
#
# ASCII (<= 0x7F) is assumed covered and skipped for speed; the assumption is
# ASSERTED against the font once at startup.
# Run: godot --headless --path <project> -s scripts/debug/glyph_coverage_check.gd
extends SceneTree

const GD_DIRS := ["res://scripts/ui", "res://scripts/battle", "res://scripts/autoloads"]
const DATA_DIR := "res://data/raw"
const SCENES_DIR := "res://scenes"

var _font: Font = null
var _offenders: Array[String] = []
var _checked_chars: Dictionary = {}  # codepoint -> bool covered (cache)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[GLYPH] Sweeping player-facing strings against m5x7 coverage")
	_font = PixelUI.get_pixel_font()
	if _font == null or _font.get_font_name() != "m5x7":
		push_error("[GLYPH] could not load m5x7 (got '%s')" % (_font.get_font_name() if _font != null else "NULL"))
		print("[GLYPH] FAIL — font unavailable")
		quit(1)
		return
	# Assert the ASCII fast-path assumption once.
	for probe in [32, 35, 65, 90, 97, 122, 126]:
		if not _font.has_char(probe):
			push_error("[GLYPH] m5x7 lacks basic ASCII U+%04X — sweep assumptions invalid" % probe)
			print("[GLYPH] FAIL")
			quit(1)
			return

	for path in _list_files(DATA_DIR, ".json"):
		_sweep_json(path)
	for dir in GD_DIRS:
		for path in _list_files(dir, ".gd"):
			_sweep_gd(path)
	for path in _list_files(SCENES_DIR, ".tscn"):
		_sweep_tscn(path)

	if _offenders.is_empty():
		print("[GLYPH] PASS — every player-facing string renders in m5x7")
		quit(0)
	else:
		for o in _offenders:
			push_error("[GLYPH] " + o)
		print("[GLYPH] FAIL — %d uncovered character site(s)" % _offenders.size())
		quit(1)


func _check_string(text: String, where: String) -> void:
	for i in text.length():
		var code: int = text.unicode_at(i)
		if code <= 0x7F:
			continue
		var covered: bool
		if _checked_chars.has(code):
			covered = bool(_checked_chars[code])
		else:
			covered = _font.has_char(code)
			_checked_chars[code] = covered
		if not covered:
			var snippet: String = text.substr(maxi(i - 12, 0), 30).replace("\n", " ")
			_offenders.append("U+%04X '%s' in %s — \"…%s…\"" % [code, char(code), where, snippet])


func _sweep_json(path: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	_walk_json(parsed, path)


func _walk_json(value: Variant, where: String) -> void:
	match typeof(value):
		TYPE_STRING:
			_check_string(value, where)
		TYPE_DICTIONARY:
			for k in (value as Dictionary):
				_walk_json((value as Dictionary)[k], where)
		TYPE_ARRAY:
			for item in (value as Array):
				_walk_json(item, where)


# Extracts double-quoted string literals per line; tracks escapes; a '#'
# outside a string ends the line (comment). Multiline strings unsupported —
# acceptable: UI copy is single-line literals throughout.
func _sweep_gd(path: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var line_no: int = 0
	while not f.eof_reached():
		var line: String = f.get_line()
		line_no += 1
		var in_string := false
		var current := ""
		var i := 0
		while i < line.length():
			var c: String = line[i]
			if in_string:
				if c == "\\":
					i += 2  # skip the escaped char (keeps \" from closing)
					current += "?"
					continue
				if c == "\"":
					in_string = false
					_check_string(current, "%s:%d" % [path, line_no])
					current = ""
				else:
					current += c
			else:
				if c == "\"":
					in_string = true
				elif c == "#":
					break  # comment — non-ASCII in comments is fine
			i += 1


func _sweep_tscn(path: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var line_no: int = 0
	while not f.eof_reached():
		var line: String = f.get_line()
		line_no += 1
		var stripped: String = line.strip_edges()
		if stripped.begins_with("text = \"") and stripped.ends_with("\""):
			_check_string(stripped.substr(8, stripped.length() - 9), "%s:%d" % [path, line_no])


func _list_files(dir_path: String, extension: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				out.append_array(_list_files(full, extension))
		elif entry.ends_with(extension):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return out
