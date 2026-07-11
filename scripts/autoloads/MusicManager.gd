extends Node
## Global music player. ONE faction track per encounter, playing continuously and
## uninterrupted from encounter start to encounter end — battles, evolution, forks,
## rewards all ride the same unbroken loop. Track changes happen at exactly three
## moments: boot→title (loop 1), encounter start (crossfade to the faction track),
## encounter end (crossfade back to loop 1). Nothing else may call play_track /
## play_for_faction.
##
## Intensity is a two-state model on the SAME track via set_combat(): combat opens
## the lowpass, restores full volume, and leans the pitch forward; non-combat sits
## back (−6 dB, ~1400 Hz muffle). The underlying playback position never jumps.
##
## Volume model: the Music bus is always _user_music_db + _state_db + _duck_db.
## Every operation (combat state, nat-20 duck) is an OFFSET from the user's
## configured level, so slider moves mid-encounter apply immediately and ducks
## restore to the user's level, never to a hardcoded 0 dB.
##
## Routed through a runtime "Music" bus (mirrors AudioManager's SFX bus) carrying
## one lowpass filter. Master-bus mute (AudioManager) covers music too.

const MUSIC_DIR := "res://assets/audio/music/"
const TRACK_FILES := {
	&"sci_fi_loop_1": "sci_fi_loop_1.ogg",
	&"sci_fi_loop_2": "sci_fi_loop_2.ogg",
	&"sci_fi_loop_3": "sci_fi_loop_3.ogg",
	&"sci_fi_loop_4": "sci_fi_loop_4.ogg",
	&"sci_fi_loop_5": "sci_fi_loop_5.ogg",
	&"sci_fi_loop_6": "sci_fi_loop_6.ogg",
}
const TITLE_TRACK := &"sci_fi_loop_1"
# Faction → track. Hive = loop 4 is spec-fixed; the rest are the op-order
# placeholder mapping (Kev 2026-07-11) awaiting an ear-tuning pass.
const FACTION_TRACKS := {
	"facility": &"sci_fi_loop_2",
	"hive": &"sci_fi_loop_4",
	"veil": &"sci_fi_loop_3",
	"voidCirclet": &"sci_fi_loop_5",
	"stellarMenagerie": &"sci_fi_loop_6",
}

const SETTINGS_PATH := "user://settings.cfg"
const SILENCE_DB := -80.0
const DEFAULT_MUSIC_VOLUME := 0.8

@export var crossfade_duration := 2.0

# Intensity states. Non-combat sits back; combat snaps into focus. The filter is
# what actually reads as intensity — the pitch bump is a garnish. Do NOT crank
# pitch: Godot resamples (pitch+tempo rise together) and past ~1.10 it goes cartoon.
@export var noncombat_db_offset := -6.0
@export var noncombat_cutoff_hz := 1400.0
@export var combat_cutoff_hz := 20000.0
@export var combat_pitch := 1.06
@export var to_combat_duration := 0.5     # hard forward lean
@export var to_noncombat_duration := 1.0  # settling back, not slamming shut

# Nat-20 stinger duck.
@export var duck_db := -8.0
@export var duck_attack := 0.04
@export var duck_hold := 0.30
@export var duck_release := 0.45

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _current_track := &""
var _combat := false
var _music_enabled := true
var _music_volume := DEFAULT_MUSIC_VOLUME  # linear 0..1 (the user slider)
var _user_music_db := 0.0
var _state_db := 0.0
var _duck_db_now := 0.0
var _suppressed := false
var _headless := false
var _bus_idx := -1
var _filter: AudioEffectLowPassFilter
var _fade_tween: Tween
var _state_tween: Tween
var _duck_tween: Tween


func _ready() -> void:
	_ensure_music_bus()
	_load_settings()
	_user_music_db = _volume_to_db(_music_volume)
	for _i in range(2):
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		add_child(player)
		_players.append(player)
	# Boot in the non-combat state, instantly (no tween before the first track).
	_state_db = noncombat_db_offset
	_filter.cutoff_hz = noncombat_cutoff_hz
	_apply_bus_volume()
	if "--debug-battle" in OS.get_cmdline_user_args():
		_suppressed = true
	# Headless (smokes, audits, captures): run the full state machine — track keys,
	# crossfade bookkeeping, bus volumes — but never start actual playback. The dummy
	# driver is silent anyway, and an OGG playback alive at process exit leaks its
	# stream past ObjectDB cleanup, spamming every headless check's output.
	_headless = DisplayServer.get_name() == "headless"


# Shutdown: an OGG playback still running at process exit holds its stream past
# ObjectDB cleanup and spams "resources still in use" on every headless check.
func _exit_tree() -> void:
	for player in _players:
		player.stop()
		player.stream = null
	_streams.clear()


func _ensure_music_bus() -> void:
	_bus_idx = AudioServer.get_bus_index("Music")
	if _bus_idx == -1:
		AudioServer.add_bus()
		_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus_idx, "Music")
		AudioServer.set_bus_send(_bus_idx, "Master")
	if AudioServer.get_bus_effect_count(_bus_idx) == 0:
		AudioServer.add_bus_effect(_bus_idx, AudioEffectLowPassFilter.new())
	_filter = AudioServer.get_bus_effect(_bus_idx, 0) as AudioEffectLowPassFilter


## Switch to a track. Same key = strict no-op (title → encounter select must not
## restart loop 1); different key = one crossfade. The three legal call sites are
## title/select ready, encounter start, and encounter end — anywhere else is a bug.
func play_track(key: StringName) -> void:
	if key == _current_track:
		return
	if not TRACK_FILES.has(key):
		push_warning("[MusicManager] unknown track key: %s" % key)
		return
	_current_track = key
	if _suppressed or not _music_enabled:
		return
	_crossfade_to(key)


func play_for_faction(faction_id: String) -> void:
	if not FACTION_TRACKS.has(faction_id):
		push_warning("[MusicManager] no track mapped for faction: %s" % faction_id)
		play_track(TITLE_TRACK)
		return
	play_track(FACTION_TRACKS[faction_id])


## The only thing that changes as the player moves between battle and non-battle
## screens. Volume, filter cutoff, and pitch tween together; playback never jumps.
func set_combat(active: bool) -> void:
	if _combat == active:
		return
	_combat = active
	if _state_tween != null and _state_tween.is_valid():
		_state_tween.kill()
	var duration := to_combat_duration if active else to_noncombat_duration
	var target_db := 0.0 if active else noncombat_db_offset
	var target_cutoff := combat_cutoff_hz if active else noncombat_cutoff_hz
	var target_pitch := combat_pitch if active else 1.0
	_state_tween = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_state_tween.tween_method(_set_state_db, _state_db, target_db, duration)
	_state_tween.tween_method(_set_cutoff, _filter.cutoff_hz, target_cutoff, duration)
	_state_tween.tween_method(_set_pitch, _players[_active].pitch_scale, target_pitch, duration)


## Nat-20 celebration: drop the bed so the stinger cuts through, then restore.
## _duck_db is additive, so the restore lands on the current state's target —
## the user's configured level, not full.
func duck_for_stinger() -> void:
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck_db, _duck_db_now, duck_db, duck_attack)
	_duck_tween.tween_interval(duck_hold)
	_duck_tween.tween_method(_set_duck_db, duck_db, 0.0, duck_release) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func is_music_enabled() -> bool:
	return _music_enabled


func set_music_enabled(enabled: bool) -> void:
	if _music_enabled == enabled:
		return
	_music_enabled = enabled
	_save_settings()
	if not enabled:
		if _fade_tween != null and _fade_tween.is_valid():
			_fade_tween.kill()
		for player in _players:
			player.stop()
	elif _current_track != &"" and not _suppressed:
		_crossfade_to(_current_track)


func get_music_volume() -> float:
	return _music_volume


## The user slider. Recomputes the live bus volume immediately — mid-encounter,
## mid-state-tween, mid-duck, whatever: the offsets ride on the new target.
func set_music_volume(volume: float) -> void:
	_music_volume = clampf(volume, 0.0, 1.0)
	_user_music_db = _volume_to_db(_music_volume)
	_apply_bus_volume()
	_save_settings()


func set_suppressed(suppressed: bool) -> void:
	if _suppressed == suppressed:
		return
	_suppressed = suppressed
	if suppressed:
		for player in _players:
			player.stop()
	elif _music_enabled and _current_track != &"":
		_crossfade_to(_current_track)


func _crossfade_to(key: StringName) -> void:
	var stream := _load_track(key)
	if stream == null:
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	var outgoing: AudioStreamPlayer = _players[_active]
	_active = (_active + 1) % _players.size()
	var incoming: AudioStreamPlayer = _players[_active]
	incoming.stream = stream
	incoming.pitch_scale = outgoing.pitch_scale if outgoing.playing else (combat_pitch if _combat else 1.0)
	incoming.volume_db = SILENCE_DB
	if not _headless:
		incoming.play()
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_method(_fade_player.bind(incoming), 0.0, 1.0, crossfade_duration)
	if outgoing.playing:
		_fade_tween.tween_method(_fade_player.bind(outgoing), 1.0, 0.0, crossfade_duration)
		_fade_tween.chain().tween_callback(outgoing.stop)


# Linear-amplitude fade mapped to dB — avoids the long inaudible tail a raw dB
# tween from -80 would spend most of its duration in.
func _fade_player(amount: float, player: AudioStreamPlayer) -> void:
	player.volume_db = _volume_to_db(amount)


func _load_track(key: StringName) -> AudioStream:
	if _streams.has(key):
		return _streams[key]
	var path: String = MUSIC_DIR + str(TRACK_FILES[key])
	# exists() guard: a registered track whose file hasn't been dropped in yet
	# warns without an engine load error (AudioManager pattern).
	if not ResourceLoader.exists(path):
		push_warning("[MusicManager] missing music track: " + path)
		return null
	var stream: AudioStream = load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true  # belt for the .import loop=true
	_streams[key] = stream
	return stream


func _set_state_db(value: float) -> void:
	_state_db = value
	_apply_bus_volume()


func _set_duck_db(value: float) -> void:
	_duck_db_now = value
	_apply_bus_volume()


func _set_cutoff(value: float) -> void:
	_filter.cutoff_hz = value


func _set_pitch(value: float) -> void:
	for player in _players:
		player.pitch_scale = value


func _apply_bus_volume() -> void:
	AudioServer.set_bus_volume_db(_bus_idx, _user_music_db + _state_db + _duck_db_now)


func _volume_to_db(volume: float) -> float:
	if volume <= 0.001:
		return SILENCE_DB
	return linear_to_db(volume)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_music_enabled = bool(cfg.get_value("audio", "music_enabled", true))
		_music_volume = clampf(float(cfg.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)), 0.0, 1.0)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # preserve other sections; ignore "not found" on first save
	cfg.set_value("audio", "music_enabled", _music_enabled)
	cfg.set_value("audio", "music_volume", _music_volume)
	cfg.save(SETTINGS_PATH)
