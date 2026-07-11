# Headless music-system regression.
# Run: godot --headless --path <project> -s scripts/debug/music_smoke_test.gd
# Pins: faction→track completeness against live operation data; same-key play_track
# as a strict no-op (the unbroken-loop contract); the additive volume model
# (user + state + duck) recomputing immediately on slider moves; and the nat-20
# duck restoring to the state target, never to a hardcoded 0 dB.
extends SceneTree

const EPS_DB := 0.5

var _errors: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("[MUSIC_SMOKE] Starting music-system smoke test")
	var mm: Node = root.get_node("/root/MusicManager")
	var dm: Node = root.get_node("/root/DataManager")

	# This test drives the real settings setters — snapshot and restore at the end.
	var orig_volume: float = mm.get_music_volume()
	var orig_enabled: bool = mm.is_music_enabled()
	mm.set_music_enabled(true)

	# 1. Every live operation maps to a loadable, looping track.
	for op_variant in dm.get_operation_order():
		var op: String = str(op_variant)
		if not mm.FACTION_TRACKS.has(op):
			_errors.append("no track mapped for operation '%s'" % op)
			continue
		var key: StringName = mm.FACTION_TRACKS[op]
		var stream: AudioStream = mm._load_track(key)
		if stream == null:
			_errors.append("track %s (op '%s') failed to load" % [key, op])
		elif stream is AudioStreamOggVorbis and not (stream as AudioStreamOggVorbis).loop:
			_errors.append("track %s is not set to loop" % key)

	# 2. Same-key play_track is a strict no-op: no player swap, no new crossfade.
	# (Headless runs skip actual .play(), so identity + fade bookkeeping is the pin.)
	mm.play_track(&"sci_fi_loop_1")
	await create_timer(0.1).timeout
	var player_before: Object = mm._players[mm._active]
	var fade_before: Object = mm._fade_tween
	mm.play_track(&"sci_fi_loop_1")
	await create_timer(0.1).timeout
	if mm._players[mm._active] != player_before:
		_errors.append("same-key play_track swapped players (track restarted)")
	if mm._fade_tween != fade_before:
		_errors.append("same-key play_track started a new crossfade")
	if mm._current_track != &"sci_fi_loop_1":
		_errors.append("current track drifted on same-key play_track")

	# 3. Faction lookup: hive is spec-fixed to loop 4.
	mm.play_for_faction("hive")
	if mm._current_track != &"sci_fi_loop_4":
		_errors.append("hive resolved to %s, expected sci_fi_loop_4" % mm._current_track)

	var bus_idx: int = AudioServer.get_bus_index("Music")

	# 4. Volume model: a slider move mid-state recomputes the bus immediately.
	mm.set_combat(true)
	await create_timer(mm.to_combat_duration + 0.2).timeout
	mm.set_music_volume(0.5)
	var expected: float = linear_to_db(0.5)  # combat state offset = 0
	var got: float = AudioServer.get_bus_volume_db(bus_idx)
	if absf(got - expected) > EPS_DB:
		_errors.append("combat bus volume %.2f dB, expected %.2f" % [got, expected])
	mm.set_combat(false)
	await create_timer(mm.to_noncombat_duration + 0.2).timeout
	expected = linear_to_db(0.5) + mm.noncombat_db_offset
	got = AudioServer.get_bus_volume_db(bus_idx)
	if absf(got - expected) > EPS_DB:
		_errors.append("non-combat bus volume %.2f dB, expected %.2f" % [got, expected])

	# 5. Duck bottoms at state+duck and restores to the state target, not 0 dB.
	mm.duck_for_stinger()
	await create_timer(mm.duck_attack + mm.duck_hold * 0.5).timeout
	expected = linear_to_db(0.5) + mm.noncombat_db_offset + mm.duck_db
	got = AudioServer.get_bus_volume_db(bus_idx)
	if absf(got - expected) > EPS_DB:
		_errors.append("duck floor %.2f dB, expected %.2f" % [got, expected])
	await create_timer(mm.duck_hold * 0.5 + mm.duck_release + 0.2).timeout
	expected = linear_to_db(0.5) + mm.noncombat_db_offset
	got = AudioServer.get_bus_volume_db(bus_idx)
	if absf(got - expected) > EPS_DB:
		_errors.append("duck restored to %.2f dB, expected state target %.2f" % [got, expected])

	mm.set_music_volume(orig_volume)
	mm.set_music_enabled(orig_enabled)

	if _errors.is_empty():
		print("[MUSIC_SMOKE] PASS — mapping, no-op replay, and volume model verified")
	else:
		for err in _errors:
			print("[MUSIC_SMOKE] FAIL: " + err)
	quit(0 if _errors.is_empty() else 1)
