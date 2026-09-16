# SaveIO — the atomic-write / durable-read mechanics shared by BOTH save files
# (user://save.json profile, user://run.json active run). No game logic lives
# here: it takes a Dictionary, puts it somewhere durable, and gets it back.
#
# WHY A SEPARATE FILE FROM SaveManager: the ordering rules below (tmp -> bak ->
# rename, seq-wins conflict resolution, the web mirror) are the part that has to
# be exercised against deliberate corruption, and a static helper can be
# unit-tested without booting a profile. SaveManager stays the single OWNER of
# what goes in the files; this is the only thing that touches disk.
#
# ── Write safety ──────────────────────────────────────────────────────────────
# 1. write  path.tmp        (a torn write damages only the scratch file)
# 2. copy   path -> path.bak (the last known-good copy, kept for the next load)
# 3. rename path.tmp -> path (atomic on every platform Godot supports)
# A crash at any step leaves either the previous save or the new one intact —
# never a half-written primary. Verified by the interrupted-write gate.
#
# ── Web durability (Kev ruling, Q2 option b) ──────────────────────────────────
# Godot 4.6.2 mounts user:// as IDBFS with NO autoPersist hooks
# (`FS.mount(IDBFS, {}, path)` in the exported index.js), so a write lands in
# MEMFS and reaches IndexedDB only when the engine's debounced FS.syncfs fires
# from the main loop. Background the tab before that tick — which is exactly
# what iOS Safari does — and the write is lost with the page. There is no
# GDScript API to force the flush, and FS/GodotFS are module-closure locals, so
# JavaScriptBridge cannot reach them either.
#
# So every save is ALSO mirrored into localStorage, whose setItem returns having
# already handed the value to the browser. This NARROWS the window; it does not
# close it. Safari itself persists localStorage asynchronously, and inside the
# itch.io iframe both stores are subject to third-party partitioning. Treat the
# mirror as a second chance, never as a guarantee.
#
# ── Conflict resolution ───────────────────────────────────────────────────────
# Every payload carries a monotonic `save_seq` bumped on each write. On load the
# HIGHEST seq wins — not saved_at, which is wall-clock and moves backwards
# across a device clock change or a timezone-confused browser. A copy that
# fails to parse, or carries no seq, loses to any copy that parses.
class_name SaveIO
extends RefCounted

## Bumped on every write and compared on every load. Stored as a plain int:
## it is a counter, not an RNG state, and will not approach 2^53.
const SEQ_KEY := "save_seq"
const WEB_KEY_PREFIX := "overload_protocol:"

## TEST SEAM. The localStorage mirror only exists on web, so on every platform
## the gate can actually run it is unreachable — and an unreachable branch is an
## untested branch. A test stands a Dictionary in for the browser store here
## (key -> raw string) and the conflict rules run for real against it:
##   null  = use the real localStorage (the only value shipping code ever sees)
##   {...} = use this dictionary
##   {} with web_store_fails = simulate a store that throws on every access
## Structural, not disciplinary: nothing in the game ever assigns these.
static var web_store_override: Variant = null
static var web_store_fails: bool = false

## 64-bit integers (RNG `state`, seeds) are stored as STRINGS. Godot's JSON
## parses every number as a double, so anything past 2^53 comes back rounded
## AND retyped to float — silently, with no error. Verified against 4.6.2:
## JSON round-tripping 9007199254740993 yields 9007199254740992.0.
static func encode_i64(value: int) -> String:
	return str(value)


static func decode_i64(value: Variant, fallback: int = 0) -> int:
	# Only a String survived the JSON boundary intact. A raw number here means
	# somebody wrote an int64 unquoted, so the value is already suspect; take it
	# but do not pretend the low bits are trustworthy.
	if value is String:
		var text: String = value as String
		if text.is_valid_int():
			return text.to_int()
		return fallback
	if value is float or value is int:
		return int(value)
	return fallback


# ── Write ─────────────────────────────────────────────────────────────────────

## Writes `data` to `path` durably. `data` is mutated to carry the next seq.
## Returns false only when the primary file could not be written at all.
static func write_dict(path: String, data: Dictionary, mirror_to_web: bool = true) -> bool:
	data[SEQ_KEY] = next_seq(path, data)
	var text: String = JSON.stringify(data, "  ")
	# Keep the outgoing primary as the fallback BEFORE it is replaced. Taken
	# from the still-intact primary, so it is a known-good copy either way. A
	# missing primary (first ever save) simply has no backup to make.
	if FileAccess.file_exists(path):
		var dir: DirAccess = DirAccess.open(path.get_base_dir())
		if dir != null:
			dir.copy(path, path + ".bak")
	if not _atomic_write(path, text):
		return false
	if mirror_to_web:
		_web_write(path, text)
	return true


## tmp -> rename. THE only way anything in this file touches a primary save:
## a direct FileAccess.open(path, WRITE) truncates before it writes, so a crash
## mid-write destroys the very copy the caller was trying to protect. Callers
## that also want a .bak rotation or a mirror do those around this, not instead.
static func _atomic_write(path: String, text: String) -> bool:
	var tmp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_warning("[SaveIO] could not open %s for writing (err %d)" % [tmp_path, FileAccess.get_open_error()])
		return false
	file.store_string(text)
	file.close()
	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if dir == null:
		push_warning("[SaveIO] could not open %s to rename into place" % path.get_base_dir())
		return false
	var err: int = dir.rename(tmp_path, path)
	if err != OK:
		push_warning("[SaveIO] rename %s -> %s failed (err %d)" % [tmp_path, path, err])
		return false
	return true


## The seq this write should carry: one past the highest seq already on record,
## so a payload rebuilt from defaults can never look older than what it replaces.
static func next_seq(path: String, data: Dictionary) -> int:
	var highest: int = int(data.get(SEQ_KEY, 0))
	highest = maxi(highest, _seq_of(_read_file(path)))
	highest = maxi(highest, _seq_of(_read_file(path + ".bak")))
	highest = maxi(highest, _seq_of(_web_read(path)))
	return highest + 1


# ── Schema fingerprint ────────────────────────────────────────────────────────
# A hash of the save's SHAPE — keys and value types, recursively — and never of
# its values. Pinned beside RUN_SAVE_VERSION so that changing what to_save_dict
# produces without bumping the version is a build break rather than a save that
# an older build silently half-reads.

## Stable, human-readable structure string. Values are discarded; only key names
## and Variant types survive.
##
## `id_keyed` names the fields whose dictionary KEYS are data rather than schema
## — anything keyed by a unit id, an item id or a battle number. Their keys must
## be ignored for the same reason array length is ignored: swapping a hero in the
## squad, or a run scheduling its beats after different battles, is ordinary
## play, and a fingerprint that moved for it would fire constantly and be turned
## off. Only the author knows which is which, so it is declared, never guessed
## (GameState.ID_KEYED_RUN_FIELDS).
static func structure_of(value: Variant, id_keyed: Array = []) -> String:
	if value is Dictionary:
		var keys: Array = (value as Dictionary).keys()
		keys.sort()
		var parts: PackedStringArray = PackedStringArray()
		for key in keys:
			var child: Variant = (value as Dictionary)[key]
			if child is Dictionary and id_keyed.has(str(key)):
				parts.append("%s:%s" % [str(key), _id_keyed_structure(child, id_keyed)])
			else:
				parts.append("%s:%s" % [str(key), structure_of(child, id_keyed)])
		return "{" + ",".join(parts) + "}"
	if value is Array:
		# Element shapes as a sorted SET, because array LENGTH is data, not
		# shape: a run holding two relics and a run holding one must fingerprint
		# identically, or the gate fires on ordinary play instead of on schema
		# changes. An empty array yields "[]" — shape unknown, not "no shape".
		var shapes: Array = []
		for entry in (value as Array):
			var shape: String = structure_of(entry, id_keyed)
			if not shapes.has(shape):
				shapes.append(shape)
		shapes.sort()
		return "[" + ",".join(shapes) + "]"
	return type_string(typeof(value))


## An ID-keyed dictionary: the VALUE shapes as a sorted set, keys discarded.
## Angle brackets, not braces, so converting a struct into an ID-keyed map (or
## back) is itself a shape change rather than passing silently.
static func _id_keyed_structure(value: Dictionary, id_keyed: Array) -> String:
	var shapes: Array = []
	for key in value:
		var shape: String = structure_of(value[key], id_keyed)
		if not shapes.has(shape):
			shapes.append(shape)
	shapes.sort()
	return "<" + ",".join(shapes) + ">"


static func structure_fingerprint(value: Variant, id_keyed: Array = []) -> String:
	return structure_of(value, id_keyed).sha256_text().substr(0, 16)


# ── Read ──────────────────────────────────────────────────────────────────────

## Returns the best surviving copy, or {} when every source is missing/corrupt.
## Sources are ranked by save_seq; ties go to the primary file (a mirror written
## from the same payload is identical, so the tie is cosmetic).
##
## `heal`: when the winner did NOT come from the primary file, write it back.
## Without this the stale primary survives until the next ordinary save, and for
## the PROFILE that can be a long time — a player who boots, reads the menu and
## quits writes nothing, so a cleared localStorage afterwards would drop them
## back to the older file. run.json heals within a scene transition either way
## (CONTINUE checkpoints immediately), but save.json is the higher-stakes file.
## The write-back preserves the winner's seq rather than bumping it: this is a
## repair, not a new save, and bumping would make the repaired copy look newer
## than an identical mirror for no reason.
static func read_dict(path: String, heal: bool = false) -> Dictionary:
	var from_primary: Dictionary = _read_file(path)
	var candidates: Array[Dictionary] = []
	for candidate in [from_primary, _read_file(path + ".bak"), _web_read(path)]:
		if not candidate.is_empty():
			candidates.append(candidate)
	if candidates.is_empty():
		return {}
	var best: Dictionary = candidates[0]
	for candidate in candidates:
		if _seq_of(candidate) > _seq_of(best):
			best = candidate
	if heal and _seq_of(best) > _seq_of(from_primary):
		_heal_primary(path, best)
	return best


## Repairs a stale or unreadable primary from the copy that won. Deliberately
## NOT write_dict: no seq bump, no .bak rotation (the current .bak may be the
## only other good copy), and no re-mirror (the mirror is where this came from).
static func _heal_primary(path: String, data: Dictionary) -> void:
	# Same tmp -> rename path as an ordinary write. A repair that truncated the
	# primary and then died would turn a recoverable situation into a worse one.
	if not _atomic_write(path, JSON.stringify(data, "  ")):
		push_warning("[SaveIO] could not heal %s from the surviving copy" % path)


## Which sources yielded a parseable payload, for diagnostics and the gate.
## Shape: {"primary": bool, "backup": bool, "web": bool}.
static func describe_sources(path: String) -> Dictionary:
	return {
		"primary": not _read_file(path).is_empty(),
		"backup": not _read_file(path + ".bak").is_empty(),
		"web": not _web_read(path).is_empty(),
	}


## Removes the save and every copy of it. Used by run-end / abandon.
static func erase(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if dir != null:
		for victim in [path, path + ".bak", path + ".tmp"]:
			if FileAccess.file_exists(victim):
				dir.remove(victim)
	_web_erase(path)


static func exists(path: String) -> bool:
	return not read_dict(path).is_empty()


# ── Internals ─────────────────────────────────────────────────────────────────

static func _seq_of(data: Dictionary) -> int:
	return int(data.get(SEQ_KEY, 0))


## Parses one file. Every failure shape — missing, unopenable, empty, truncated,
## garbage, valid JSON that is not an object — returns {} without raising, so a
## corrupt file degrades to "this source has nothing" rather than a crash.
static func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("[SaveIO] could not open %s for reading" % path)
		return {}
	var text: String = file.get_as_text()
	file.close()
	return _parse(text, path)


static func _parse(text: String, source: String) -> Dictionary:
	if text.strip_edges() == "":
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("[SaveIO] %s is not a JSON object - ignoring this copy." % source)
		return {}
	return parsed as Dictionary


# ── localStorage mirror (web only) ────────────────────────────────────────────
# Every call is wrapped: JavaScriptBridge is absent off-web, eval can throw
# inside a partitioned iframe, and a quota-exceeded setItem raises. Any failure
# degrades to the IDBFS-only path, which is the pre-existing behavior.

## True when a mirror store is reachable at all. `OS.has_feature("web")` is the
## only honest test: JavaScriptBridge is a registered singleton on desktop too,
## so Engine.has_singleton would read true everywhere and buy nothing.
static func _web_available() -> bool:
	if web_store_override != null:
		return not web_store_fails
	return OS.has_feature("web")


static func _web_key(path: String) -> String:
	return WEB_KEY_PREFIX + path.get_file()


static func _web_write(path: String, text: String) -> void:
	if not _web_available():
		return
	if web_store_override != null:
		(web_store_override as Dictionary)[_web_key(path)] = text
		return
	var script: String = """
		(function(){ try {
			window.localStorage.setItem(%s, %s); return 1;
		} catch (e) { return 0; } })();
	""" % [JSON.stringify(_web_key(path)), JSON.stringify(text)]
	var ok: Variant = JavaScriptBridge.eval(script, true)
	if int(ok if ok != null else 0) != 1:
		push_warning("[SaveIO] localStorage mirror unavailable - relying on user:// alone.")


static func _web_read(path: String) -> Dictionary:
	if not _web_available():
		return {}
	var raw: Variant
	if web_store_override != null:
		raw = (web_store_override as Dictionary).get(_web_key(path), null)
	else:
		var script: String = """
			(function(){ try {
				return window.localStorage.getItem(%s);
			} catch (e) { return null; } })();
		""" % JSON.stringify(_web_key(path))
		raw = JavaScriptBridge.eval(script, true)
	if not (raw is String):
		return {}
	return _parse(raw as String, "localStorage:" + _web_key(path))


static func _web_erase(path: String) -> void:
	if not _web_available():
		return
	if web_store_override != null:
		(web_store_override as Dictionary).erase(_web_key(path))
		return
	var script: String = """
		(function(){ try {
			window.localStorage.removeItem(%s);
		} catch (e) {} })();
	""" % JSON.stringify(_web_key(path))
	JavaScriptBridge.eval(script, true)
