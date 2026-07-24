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
## Combat entry is SEQUENCED, never overlapped (Batch 5): the encounter-start
## crossfade (loop 1 → faction track) fires at deploy, and the battle scene's
## set_combat(true) fires ~immediately after on load. If those overlap, the still-
## dominant OUTGOING track gets the pitch/volume boost = an audible "record drag."
## So: (1) the incoming faction track enters ALREADY at combat pitch (play_for_faction
## always precedes a battle); (2) _set_pitch touches only the ACTIVE (incoming) player,
## never the outgoing one; (3) set_combat(true) DEFERS its state ramp until any in-flight
## crossfade finishes — the old track fades out first, then the lone faction track rises
## to battle state. Battles 2–10 (no crossfade in flight) still snap immediately.
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
# Default music level (Batch 5): 30%. A saved user preference in settings.cfg still wins
# (see _load_settings) — this only sets the level for a fresh profile.
const DEFAULT_MUSIC_VOLUME := 0.3

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
		# Explicit STREAM playback: on web the project default is Sample, which
		# bypasses bus effects (the lowpass would go dead) and decodes the whole
		# track to PCM. Stream is the native default, so this is a no-op off web.
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
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
## `incoming_pitch` > 0 forces the pitch the incoming track enters at (the faction
## crossfade uses combat_pitch so the battle track is already at pitch, never swept);
## -1 = auto (combat_pitch while in combat, else 1.0).
func play_track(key: StringName, incoming_pitch: float = -1.0) -> void:
	if key == _current_track:
		return
	if not TRACK_FILES.has(key):
		push_warning("[MusicManager] unknown track key: %s" % key)
		return
	_current_track = key
	if _suppressed or not _music_enabled:
		return
	_crossfade_to(key, incoming_pitch)


func play_for_faction(faction_id: String) -> void:
	if not FACTION_TRACKS.has(faction_id):
		push_warning("[MusicManager] no track mapped for faction: %s" % faction_id)
		play_track(TITLE_TRACK)
		return
	# Encounter start always leads straight into a battle, so the faction track enters
	# already at combat pitch — set_combat(true) then has no pitch to sweep (Batch 5).
	play_track(FACTION_TRACKS[faction_id], combat_pitch)


## The only thing that changes as the player moves between battle and non-battle
## screens. Volume, filter cutoff, and pitch tween together; playback never jumps.
##
## Sequencing rule (Batch 5): if a track crossfade is still in flight (only ever the
## encounter-start loop 1 → faction fade), applying the combat ramp NOW would boost the
## still-dominant OUTGOING track — the "record drag." So we DEFER the ramp until the
## crossfade finishes; by then the old track is gone and only the faction track (already
## at combat pitch) remains to rise into battle state. No crossfade in flight (battles
## 2–10) → apply immediately, the snappy 0.5 s forward lean.
func set_combat(active: bool) -> void:
	if _combat == active:
		return
	_combat = active
	if active and _fade_tween != null and _fade_tween.is_valid():
		if not _fade_tween.finished.is_connected(_apply_combat_state):
			_fade_tween.finished.connect(_apply_combat_state, CONNECT_ONE_SHOT)
		return
	_apply_combat_state()


# Ramps volume, filter cutoff, and (active-player-only) pitch toward the CURRENT combat
# state. Read _combat freshly so a deferred call always lands on the latest intent.
func _apply_combat_state() -> void:
	if _state_tween != null and _state_tween.is_valid():
		_state_tween.kill()
	var duration := to_combat_duration if _combat else to_noncombat_duration
	var target_db := 0.0 if _combat else noncombat_db_offset
	var target_cutoff := combat_cutoff_hz if _combat else noncombat_cutoff_hz
	var target_pitch := combat_pitch if _combat else 1.0
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


func _crossfade_to(key: StringName, incoming_pitch: float = -1.0) -> void:
	var stream := _load_track(key)
	if stream == null:
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	var outgoing: AudioStreamPlayer = _players[_active]
	_active = (_active + 1) % _players.size()
	var incoming: AudioStreamPlayer = _players[_active]
	incoming.stream = stream
	# Incoming enters at its own clean target pitch — NEVER inheriting the outgoing
	# player's (possibly mid-sweep) pitch, which is what dragged the record (Batch 5).
	incoming.pitch_scale = incoming_pitch if incoming_pitch > 0.0 else (combat_pitch if _combat else 1.0)
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


# Active (incoming/current) player ONLY. The outgoing player of a crossfade is fading
# out and must keep its own pitch — sweeping it is the "record drag" (Batch 5).
func _set_pitch(value: float) -> void:
	_players[_active].pitch_scale = value


func _apply_bus_volume() -> void:
	AudioServer.set_bus_volume_db(_bus_idx, _user_music_db + _state_db + _duck_db_now)


func _volume_to_db(volume: float) -> float:
	if volume <= 0.001:
		return SILENCE_DB
	return linear_to_db(volume)


# Profile isolation (DevContext, Kev 2026-07-12): rigs/tests read+write a
# scratch settings file — the real user://settings.cfg is untouchable from any
# dev context (this write previously had NO guard at all; the music smoke could
# persist volume changes into the real settings).
func _settings_path() -> String:
	return "user://dev_settings.cfg" if DevContext.is_isolated() else SETTINGS_PATH


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_settings_path()) == OK:
		_music_enabled = bool(cfg.get_value("audio", "music_enabled", true))
		_music_volume = clampf(float(cfg.get_value("audio", "music_volume", DEFAULT_MUSIC_VOLUME)), 0.0, 1.0)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_settings_path())  # preserve other sections; ignore "not found" on first save
	cfg.set_value("audio", "music_enabled", _music_enabled)
	cfg.set_value("audio", "music_volume", _music_volume)
	cfg.save(_settings_path())
