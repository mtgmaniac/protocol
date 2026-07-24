extends Node
## Global SFX player. play_sfx(key) with pitch/volume randomization and voice
## limiting (a small round-robin pool caps simultaneous voices). Routed through
## the SFX bus (predefined in default_bus_layout.tres), except keys in
## BUS_BY_KEY which ride a child bus (UI clicks -> "UI"). Dice impacts live in
## DiceAudio, not here.
##
## Clips live at res://assets/audio/sfx/<key>.wav. New sound = drop a file + add
## the key to SFX_KEYS + name it on the event hook. shield.wav is the reversed
## shield sound (pre-reversed at asset prep time).

const SFX_DIR := "res://assets/audio/sfx/"
const SFX_KEYS := [
	"damage", "death", "evolve", "freeze", "heal", "item", "overload",
	"burn", "revive", "select", "shield", "summon",
]
const POOL_SIZE := 12            # max simultaneous voices
const PITCH_VARIATION := 0.07    # ±7% pitch so repeats never feel machine-gun
const VOLUME_VARIATION_DB := 1.5 # ±1.5 dB
const DEBOUNCE_MS := 40          # collapse identical key within a frame (multi-target abilities → one sound)
const VOLUME_OVERRIDES := {
	"burn": -5.0,
	"select": -9.1,  # was -6.0; Kev 2026-07-10: 30% quieter again (x0.7 amplitude = -3.1 dB)
}
# Keys that route somewhere other than the general SFX bus. DICE and UI are
# children of SFX in default_bus_layout.tres, so the SOUND FX slider/mute still
# governs them as a parent while each keeps its own trim.
const BUS_BY_KEY := {
	"select": "UI",
}

const SETTINGS_PATH := "user://settings.cfg"

# The user-facing volume channels (settings rows). Each is a real bus predefined
# in default_bus_layout.tres — NEVER created at runtime (web sample playback:
# runtime AudioServer.add_bus corrupts the JS bus graph; see project.godot).
const CHANNELS := ["SFX", "DICE", "UI"]

const SILENCE_DB := -80.0

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _recent: Dictionary = {}
var _suppressed: bool = false
var _muted: bool = false
var _channel_volume: Dictionary = {"SFX": 1.0, "DICE": 1.0, "UI": 1.0}  # linear 0..1 sliders
var _channel_enabled: Dictionary = {"SFX": true, "DICE": true, "UI": true}


func _ready() -> void:
	_ensure_sfx_bus()
	_load_settings()
	_apply_mute()
	for channel in CHANNELS:
		_apply_channel(channel)
	for key in SFX_KEYS:
		var path: String = SFX_DIR + key + ".wav"
		# exists() guard: a registered key whose clip hasn't been dropped in yet
		# (asset still pending) warns without an engine load error.
		var stream: AudioStream = null
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
		if stream != null:
			_streams[key] = stream
		else:
			push_warning("[AudioManager] missing sfx clip: " + path)
	for _i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_pool.append(player)
	if "--debug-battle" in OS.get_cmdline_user_args():
		_suppressed = true


# Fallback ONLY for a context missing default_bus_layout.tres (never the real
# game). On web, runtime add_bus corrupts the JS sample-bus graph into silence
# (see project.godot [audio]) — the .tres predefining SFX/DICE/UI is what keeps
# this branch dead.
func _ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index("SFX") != -1:
		return
	AudioServer.add_bus()
	var idx: int = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, "SFX")
	AudioServer.set_bus_send(idx, "Master")


## Default UI click — select.wav for any button without a dedicated action sound.
func play_select() -> void:
	play_sfx("select")


func set_suppressed(suppressed: bool) -> void:
	_suppressed = suppressed


func play_sfx(key: String, volume_db: float = 0.0) -> void:
	if _suppressed:
		return
	var stream: AudioStream = _streams.get(key, null)
	if stream == null:
		return
	var now: int = Time.get_ticks_msec()
	if int(_recent.get(key, -10000)) + DEBOUNCE_MS > now:
		return
	_recent[key] = now
	var player: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.bus = str(BUS_BY_KEY.get(key, "SFX"))
	player.pitch_scale = 1.0 + randf_range(-PITCH_VARIATION, PITCH_VARIATION)
	var base_db: float = volume_db + float(VOLUME_OVERRIDES.get(key, 0.0))
	player.volume_db = base_db + randf_range(-VOLUME_VARIATION_DB, VOLUME_VARIATION_DB)
	player.play()


# ── Master mute (the "mute all audio" setting) ──────────────────────────────────
# Mutes the Master bus so it covers SFX and any future music in one switch, and persists
# the choice to user://settings.cfg so it survives across launches.
func is_muted() -> bool:
	return _muted


func set_muted(muted: bool) -> void:
	if _muted == muted:
		return
	_muted = muted
	_apply_mute()
	_save_settings()


func _apply_mute() -> void:
	var idx: int = AudioServer.get_bus_index("Master")
	if idx != -1:
		AudioServer.set_bus_mute(idx, _muted)


# ── Channel volumes/mutes (the user sliders; music lives on MusicManager) ───────
# channel is one of CHANNELS ("SFX", "DICE", "UI"). SFX is the parent bus, so its
# slider/mute scales DICE and UI too; their own rows are independent trims.
func get_channel_volume(channel: String) -> float:
	return float(_channel_volume.get(channel, 1.0))


func set_channel_volume(channel: String, volume: float) -> void:
	if not CHANNELS.has(channel):
		return
	_channel_volume[channel] = clampf(volume, 0.0, 1.0)
	_apply_channel(channel)
	_save_settings()


func is_channel_enabled(channel: String) -> bool:
	return bool(_channel_enabled.get(channel, true))


func set_channel_enabled(channel: String, enabled: bool) -> void:
	if not CHANNELS.has(channel):
		return
	_channel_enabled[channel] = enabled
	_apply_channel(channel)
	_save_settings()


func _apply_channel(channel: String) -> void:
	var idx: int = AudioServer.get_bus_index(channel)
	if idx == -1:
		return
	var volume: float = float(_channel_volume.get(channel, 1.0))
	var db: float = SILENCE_DB if volume <= 0.001 else linear_to_db(volume)
	AudioServer.set_bus_volume_db(idx, db)
	AudioServer.set_bus_mute(idx, not bool(_channel_enabled.get(channel, true)))


# Profile isolation (DevContext, Kev 2026-07-12): rigs/tests read+write a
# scratch settings file — the real user://settings.cfg is untouchable from any
# dev context (this write previously had NO guard at all).
func _settings_path() -> String:
	return "user://dev_settings.cfg" if DevContext.is_isolated() else SETTINGS_PATH


# Persistence keys: sfx_volume keeps its historical name (pre-channels saves
# load unchanged); DICE/UI use the lowercased channel name.
func _settings_key(channel: String, suffix: String) -> String:
	return channel.to_lower() + "_" + suffix


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_settings_path()) == OK:
		_muted = bool(cfg.get_value("audio", "muted", false))
		for channel in CHANNELS:
			_channel_volume[channel] = clampf(
				float(cfg.get_value("audio", _settings_key(channel, "volume"), 1.0)), 0.0, 1.0)
			_channel_enabled[channel] = bool(cfg.get_value("audio", _settings_key(channel, "enabled"), true))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_settings_path())  # preserve any other sections; ignore "not found" on first save
	cfg.set_value("audio", "muted", _muted)
	for channel in CHANNELS:
		cfg.set_value("audio", _settings_key(channel, "volume"), float(_channel_volume.get(channel, 1.0)))
		cfg.set_value("audio", _settings_key(channel, "enabled"), bool(_channel_enabled.get(channel, true)))
	cfg.save(_settings_path())
