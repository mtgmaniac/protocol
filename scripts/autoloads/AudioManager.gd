extends Node
## Global SFX player. play_sfx(key) with pitch/volume randomization and voice
## limiting (a small round-robin pool caps simultaneous voices). Routed through a
## dedicated SFX bus (created at runtime) so volume/mute can hang off it later.
##
## Clips live at res://assets/audio/sfx/<key>.wav. New sound = drop a file + add
## the key to SFX_KEYS + name it on the event hook. shield.wav is the reversed
## shield sound (pre-reversed at asset prep time).

const SFX_DIR := "res://assets/audio/sfx/"
const SFX_KEYS := [
	"damage", "death", "evolve", "freeze", "heal", "item", "overload",
	"burn", "select", "shield",
]
const POOL_SIZE := 12            # max simultaneous voices
const PITCH_VARIATION := 0.07    # ±7% pitch so repeats never feel machine-gun
const VOLUME_VARIATION_DB := 1.5 # ±1.5 dB
const DEBOUNCE_MS := 40          # collapse identical key within a frame (multi-target abilities → one sound)
const VOLUME_OVERRIDES := {
	"burn": -5.0,
	"select": -6.0,  # ~50% amplitude vs default UI click
}

const SETTINGS_PATH := "user://settings.cfg"

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _recent: Dictionary = {}
var _suppressed: bool = false
var _muted: bool = false


func _ready() -> void:
	_ensure_sfx_bus()
	_load_settings()
	_apply_mute()
	for key in SFX_KEYS:
		var path: String = SFX_DIR + key + ".wav"
		var stream: AudioStream = load(path) as AudioStream
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


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_muted = bool(cfg.get_value("audio", "muted", false))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # preserve any other sections; ignore "not found" on first save
	cfg.set_value("audio", "muted", _muted)
	cfg.save(SETTINGS_PATH)
