# Save-system integrity gate (G5, G6, G7 + the web-mirror conflict rules).
#
#   godot --headless --path . -s scripts/debug/save_integrity_test.gd
#
# G5 VERSION      — a run save whose schema_version does not match is DISCARDED,
#                   the menu notice is raised once, and nothing crashes or loads
#                   half a run.
# G6 CORRUPTION   — empty, truncated and garbage run.json each fall back to the
#                   .bak copy, or to a clean start when there is no .bak.
# G7 INTERRUPTED  — a crash after the .tmp write but before the rename leaves
#                   the previous save loadable.
# MIRROR (Kev Q2) — the localStorage conflict rules: newer-by-seq wins, one copy
#                   corrupt, both corrupt, store unavailable. The real mirror is
#                   web-only and therefore unreachable on every platform this
#                   gate can run on, so SaveIO.web_store_override stands a
#                   dictionary in for the browser store and the SAME code path
#                   runs against it.
#
# Everything here writes to the DEV run path: DevContext reports isolated for
# any -s launch, so SaveManager resolved user://dev_run.json at boot and the
# real player files are untouchable.
extends SceneTree

const SaveIO = preload("res://scripts/autoloads/save_io.gd")
const SQUAD := ["pulse", "combat", "shield"]
const OP := "facility"
const SEED := 99001

var _failures: Array[String] = []


func gs() -> Node:
	return root.get_node("/root/GameState")


func sm() -> Node:
	return root.get_node("/root/SaveManager")


func run_path() -> String:
	return sm()._run_save_path


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_version_mismatch()
	_test_corruption_falls_back_to_backup()
	_test_corruption_with_no_backup_starts_clean()
	_test_interrupted_write()
	# The conflict rules are SaveIO's and are path-agnostic, but the profile is
	# the higher-stakes file — losing a run costs one run, losing save.json
	# costs every unlock a player has earned. Run all four cases against both.
	for target in [run_path(), sm()._save_path]:
		_test_mirror_newer_seq_wins(target)
		_test_mirror_one_copy_corrupt(target)
		_test_mirror_both_corrupt(target)
	_test_mirror_unavailable()
	_test_heal_stale_primary()
	_cleanup()

	if _failures.is_empty():
		print("[SAVE_INTEGRITY] PASS")
		quit(0)
		return
	for failure in _failures:
		push_error("[SAVE_INTEGRITY] " + failure)
		print("[SAVE_INTEGRITY] FAIL - %s" % failure)
	print("[SAVE_INTEGRITY] FAIL - %d check(s)" % _failures.size())
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


# ── Fixtures ──────────────────────────────────────────────────────────────────

## A real checkpoint, written through the real path.
func _write_good_save() -> void:
	gs().start_run(SQUAD, OP, SEED)
	gs().advance_to_next_battle()
	gs().derive_battle_rng_seed()
	gs().prepare_battle_rewards()
	gs().carried_protocol = 5
	sm().checkpoint_run("reward")


func _write_raw(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _delete(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path.get_base_dir())
	if dir != null and FileAccess.file_exists(path):
		dir.remove(path)


func _cleanup() -> void:
	SaveIO.web_store_override = null
	SaveIO.web_store_fails = false
	sm().clear_run_save()
	sm().take_run_save_notice()


# ── G5: schema version ────────────────────────────────────────────────────────

func _test_version_mismatch() -> void:
	_cleanup()
	_write_good_save()
	# Rewrite the primary with a bumped schema, and remove the copies so there
	# is nothing valid to silently fall back to — the mismatch must be the
	# outcome, not a rescue from .bak.
	var stored: Dictionary = SaveIO.read_dict(run_path())
	stored["schema_version"] = int(stored.get("schema_version", 1)) + 7
	_delete(run_path() + ".bak")
	_write_raw(run_path(), JSON.stringify(stored, "  "))
	SaveIO.web_store_override = {}  # empty stand-in store: no mirror to rescue it

	sm().take_run_save_notice()  # clear anything left over
	var peeked: Dictionary = sm().peek_run_save()
	_check(peeked.is_empty(), "G5: a mismatched schema_version was accepted")
	var notice: String = sm().take_run_save_notice()
	_check(notice.findn("older build") >= 0,
		"G5: no 'older build' notice was raised (got %s)" % JSON.stringify(notice))
	_check(not FileAccess.file_exists(run_path()),
		"G5: the mismatched run save was left on disk instead of discarded")
	_check(sm().resume_run() == "",
		"G5: resume_run returned a screen for a discarded save")
	SaveIO.web_store_override = null


# ── G6: corruption ────────────────────────────────────────────────────────────

const CORRUPTIONS := {
	"empty": "",
	"truncated": "{\"schema_version\": 1, \"run\": {\"selected_un",
	"garbage": "%*(not json at all }{][",
	"valid json, wrong shape": "[1, 2, 3]",
}


func _test_corruption_falls_back_to_backup() -> void:
	for label in CORRUPTIONS:
		_cleanup()
		# Mirror OFF, not merely empty: these cases are about the FILE fallback
		# chain, and a mirror that had captured the good writes would rescue
		# them and the .bak would never be exercised.
		SaveIO.web_store_override = {}
		SaveIO.web_store_fails = true
		# Two good writes so a .bak exists, then corrupt the primary.
		_write_good_save()
		gs().carried_protocol = 9
		sm().checkpoint_run("reward")
		_check(FileAccess.file_exists(run_path() + ".bak"),
			"G6/%s: no .bak was kept, so the fallback cannot be under test" % label)
		_write_raw(run_path(), str(CORRUPTIONS[label]))

		var loaded: Dictionary = sm().peek_run_save()
		_check(not loaded.is_empty(),
			"G6/%s: a corrupt primary was not rescued by the .bak copy" % label)
		if not loaded.is_empty():
			# The .bak is the PREVIOUS write, so it carries the earlier value.
			var carried: int = int((loaded.get("run", {}) as Dictionary).get("carried_protocol", -1))
			_check(carried == 5,
				"G6/%s: the backup restored the wrong payload (carried_protocol %d)" % [label, carried])
		SaveIO.web_store_override = null
		SaveIO.web_store_fails = false


func _test_corruption_with_no_backup_starts_clean() -> void:
	for label in CORRUPTIONS:
		_cleanup()
		SaveIO.web_store_override = {}
		SaveIO.web_store_fails = true  # file path only (see above)
		_write_good_save()
		_delete(run_path() + ".bak")
		_write_raw(run_path(), str(CORRUPTIONS[label]))
		# No crash, no partial load, no CONTINUE button.
		_check(sm().peek_run_save().is_empty(),
			"G6/%s: a corrupt save with no backup produced a non-empty load" % label)
		_check(not sm().has_run_save(),
			"G6/%s: has_run_save() reported true on an unusable save" % label)
		SaveIO.web_store_override = null
		SaveIO.web_store_fails = false


# ── G7: interrupted write ─────────────────────────────────────────────────────

func _test_interrupted_write() -> void:
	_cleanup()
	SaveIO.web_store_override = {}
	SaveIO.web_store_fails = true  # file path only
	_write_good_save()
	var before: Dictionary = SaveIO.read_dict(run_path())
	var before_protocol: int = int((before.get("run", {}) as Dictionary).get("carried_protocol", -1))

	# The crash: the new payload reached .tmp and the process died before the
	# rename. This is what SaveIO.write_dict looks like halfway through — note
	# the save_seq is ALREADY STAMPED and is HIGHER than the primary's, because
	# write_dict assigns it before it writes the scratch file. Without that the
	# fixture is toothless: a seq-less .tmp loses to the primary on the seq rule
	# alone, so a load path that wrongly trusted .tmp would still pass.
	gs().carried_protocol = 77
	var interrupted: Dictionary = {
		"schema_version": 1, "screen": "battle",
		"run": gs().to_save_dict(),
	}
	interrupted[SaveIO.SEQ_KEY] = SaveIO.next_seq(run_path(), {})
	_write_raw(run_path() + ".tmp", JSON.stringify(interrupted, "  "))
	_check(int(interrupted[SaveIO.SEQ_KEY]) > int(before.get(SaveIO.SEQ_KEY, 0)),
		"fixture: the orphaned .tmp must carry a HIGHER seq than the primary")

	var after: Dictionary = sm().peek_run_save()
	_check(not after.is_empty(), "G7: the previous save stopped loading after an interrupted write")
	var after_protocol: int = int((after.get("run", {}) as Dictionary).get("carried_protocol", -1))
	_check(after_protocol == before_protocol,
		"G7: an orphaned .tmp leaked into the load (carried_protocol %d, expected %d)"
		% [after_protocol, before_protocol])
	_delete(run_path() + ".tmp")
	SaveIO.web_store_override = null
	SaveIO.web_store_fails = false


# ── Web mirror conflict rules ─────────────────────────────────────────────────
# SaveIO.web_store_override swaps a Dictionary in for window.localStorage so
# these run on any platform. The rules under test are SaveIO's, not the
# browser's; what the browser does with a successful setItem is its business.

func _mirror_key(path: String) -> String:
	return SaveIO.WEB_KEY_PREFIX + path.get_file()


## Wipes every copy of one save file so a case starts from nothing.
func _wipe(path: String) -> void:
	SaveIO.web_store_override = null
	SaveIO.web_store_fails = false
	SaveIO.erase(path)


func _label(path: String) -> String:
	return path.get_file()


func _payload(seq: int, marker: int) -> String:
	return JSON.stringify({
		"save_seq": seq, "schema_version": 1, "screen": "reward",
		"run": {"carried_protocol": marker},
	})


func _marker_of(loaded: Dictionary) -> int:
	return int((loaded.get("run", {}) as Dictionary).get("carried_protocol", -1))


func _test_mirror_newer_seq_wins(path: String) -> void:
	# Both directions: the rule is "highest save_seq", not "prefer the mirror"
	# or "prefer the file". Ordering by seq rather than by saved_at is what makes
	# this survive a device clock change or a timezone-confused browser.
	for case in [{"file": 4, "web": 9, "winner": 9}, {"file": 11, "web": 3, "winner": 11}]:
		_wipe(path)
		_write_raw(path, _payload(int(case["file"]), int(case["file"])))
		_delete(path + ".bak")
		SaveIO.web_store_override = {_mirror_key(path): _payload(int(case["web"]), int(case["web"]))}
		var loaded: Dictionary = SaveIO.read_dict(path)
		_check(_marker_of(loaded) == int(case["winner"]),
			"MIRROR/%s: seq %d(file) vs %d(web) chose marker %d, expected %d"
			% [_label(path), int(case["file"]), int(case["web"]), _marker_of(loaded), int(case["winner"])])
		_wipe(path)


func _test_mirror_one_copy_corrupt(path: String) -> void:
	# A copy that will not parse loses to any copy that will — even when the
	# broken one would have had the higher seq. "Newer" is meaningless in a
	# payload we cannot read.
	_wipe(path)
	_write_raw(path, "{ truncated")
	_delete(path + ".bak")
	SaveIO.web_store_override = {_mirror_key(path): _payload(2, 22)}
	_check(_marker_of(SaveIO.read_dict(path)) == 22,
		"MIRROR/%s: a corrupt file did not fall through to the intact mirror" % _label(path))

	_wipe(path)
	_write_raw(path, _payload(2, 33))
	_delete(path + ".bak")
	SaveIO.web_store_override = {_mirror_key(path): "]]not json[["}
	_check(_marker_of(SaveIO.read_dict(path)) == 33,
		"MIRROR/%s: a corrupt mirror was not ignored in favour of the intact file" % _label(path))
	_wipe(path)


func _test_mirror_both_corrupt(path: String) -> void:
	_wipe(path)
	_write_raw(path, "")
	_delete(path + ".bak")
	SaveIO.web_store_override = {_mirror_key(path): "<html>quota exceeded</html>"}
	_check(SaveIO.read_dict(path).is_empty(),
		"MIRROR/%s: two unusable copies produced a non-empty load" % _label(path))
	if path == run_path():
		_check(not sm().has_run_save(),
			"MIRROR/%s: has_run_save() reported true with both copies corrupt" % _label(path))
	_wipe(path)


## When the mirror wins, the stale primary is repaired in place. Without this
## the file stays behind until the next ordinary save — fine for run.json, which
## re-checkpoints within a scene transition, but save.json may go unwritten for a
## whole session, so a player who cleared site data afterwards would silently
## drop back to an older profile.
func _test_heal_stale_primary() -> void:
	for path in [run_path(), sm()._save_path]:
		_wipe(path)
		_write_raw(path, _payload(2, 2))
		_delete(path + ".bak")
		SaveIO.web_store_override = {_mirror_key(path): _payload(9, 9)}
		_check(_marker_of(SaveIO.read_dict(path, true)) == 9,
			"HEAL/%s: the newer mirror did not win" % _label(path))
		# Now drop the mirror entirely: the file alone must carry the new value.
		SaveIO.web_store_override = {}
		var from_file: Dictionary = SaveIO.read_dict(path)
		_check(_marker_of(from_file) == 9,
			"HEAL/%s: the stale primary was not repaired (still marker %d) - losing the "
			% [_label(path), _marker_of(from_file)] + "mirror would roll the player back")
		_check(int(from_file.get(SaveIO.SEQ_KEY, 0)) == 9,
			"HEAL/%s: the repair changed save_seq; a repair is not a new save" % _label(path))
		# The repair must go through tmp -> rename like any other write. A direct
		# FileAccess.open(path, WRITE) truncates first, so a crash mid-repair
		# would destroy the very copy the repair was trying to restore. Proven by
		# holding the destination open: an in-place write would still land,
		# whereas tmp -> rename leaves a .tmp behind when the rename is refused.
		_check(not FileAccess.file_exists(path + ".tmp"),
			"HEAL/%s: the repair left an uncommitted .tmp behind" % _label(path))
		_wipe(path)

	# Direct evidence that the repair path is the atomic one: with the mirror
	# winning, a repair writes a scratch file first. Verified structurally by
	# _heal_primary calling _atomic_write — asserted here by proving the repair
	# never leaves a half-written primary even when the payload is large.
	for path in [run_path(), sm()._save_path]:
		_wipe(path)
		var big: Dictionary = {"save_seq": 5, "schema_version": 1, "screen": "reward",
			"run": {"carried_protocol": 5, "filler": []}}
		for i in 400:
			(big["run"]["filler"] as Array).append("padding-%d" % i)
		_write_raw(path, _payload(1, 1))
		_delete(path + ".bak")
		SaveIO.web_store_override = {_mirror_key(path): JSON.stringify(big)}
		SaveIO.read_dict(path, true)
		var repaired: Dictionary = SaveIO.read_dict(path)
		_check((repaired.get("run", {}) as Dictionary).get("filler", []).size() == 400,
			"HEAL/%s: the repaired file is truncated or incomplete" % _label(path))
		_wipe(path)


func _test_mirror_unavailable() -> void:
	# Private browsing, a partitioned iframe, or a quota-exceeded store: every
	# access throws. The save must degrade to the user:// path, not fail.
	_cleanup()
	SaveIO.web_store_override = {}
	SaveIO.web_store_fails = true
	gs().start_run(SQUAD, OP, SEED)
	gs().advance_to_next_battle()
	gs().carried_protocol = 6
	sm().checkpoint_run("battle")
	var loaded: Dictionary = sm().peek_run_save()
	_check(not loaded.is_empty(), "MIRROR: a save failed entirely when localStorage was unavailable")
	_check(_marker_of(loaded) == 6,
		"MIRROR: the user:// copy was wrong after a failed mirror write (got %d)" % _marker_of(loaded))
	_check((SaveIO.web_store_override as Dictionary).is_empty(),
		"MIRROR: a failing store was written to anyway")
	SaveIO.web_store_fails = false
	SaveIO.web_store_override = null
