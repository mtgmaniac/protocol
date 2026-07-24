extends Node
## Physical dice audio. DiceTray3D reports contacts and settles here; this owns
## the click/roll streams, the voice pool, and all shaping (velocity->volume,
## pitch spread, per-die debounce). Everything plays on the DICE bus (predefined
## in default_bus_layout.tres, child of SFX — the SOUND FX slider governs it as
## a parent, the DICE settings row is the independent trim).
##
## Zero-allocation at play time: streams are loaded once, the player pool is
## preallocated, and the per-die debounce dictionary is cleared (not rebuilt)
## each roll. The hot path allocates nothing.

## A/B switch (Kev): per-impact clicks are the shipped mode. Flip to true to
## fall back to ONE mini-roll sample per roll (dice_roll_*, scaled to dice
## count) with no contact processing at all — DiceTray3D checks this const and
## skips contact_monitor wiring entirely, so the physics cost also goes away.
const ONE_SHOT_MODE := false

const CLICK_COUNT := 9
const ROLL_COUNT := 9
const CLICK_PATH := "res://assets/audio/sfx/dice/dice_click_%02d.wav"
const ROLL_PATH := "res://assets/audio/sfx/dice/dice_roll_%02d.wav"

const POOL_SIZE := 6              # voice cap: oldest voice is stolen beyond this
const DEBOUNCE_MS := 70           # per-die: one die's rapid micro-contacts collapse
const PITCH_MIN := 0.9
const PITCH_MAX := 1.1
# Impact speed (post-collision, world units/s) -> volume. Below MIN the contact
# is a micro-jostle and stays silent; FULL and above plays at MAX_DB. Launch
# speeds are 10.5-13.5 (DiceTray3D), so direct wall hits land near full.
const IMPACT_SPEED_MIN := 1.5
const IMPACT_SPEED_FULL := 10.0
const IMPACT_DB_QUIET := -16.0
const IMPACT_DB_MAX := -3.0       # clicks are peak-normalized -3 dB; keep headroom at 5-die pileups
const VOLUME_JITTER_DB := 1.5
# Settle tick: the "die comes to rest" period — a click pitched well below the
# impact range so it reads as a full stop, not another bounce.
const SETTLE_PITCH := 0.8
const SETTLE_DB := -6.0
# One-shot mode: single mini-roll scaled roughly to expected roll energy.
const ONE_SHOT_DB_1_DIE := -8.0
const ONE_SHOT_DB_5_DICE := 0.0

var _clicks: Array[AudioStream] = []
var _rolls: Array[AudioStream] = []
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _last_impact_ms: Dictionary = {}  # die instance id -> last click Time.get_ticks_msec()
var _suppressed: bool = false


func _ready() -> void:
	for i in range(1, CLICK_COUNT + 1):
		var click_path: String = CLICK_PATH % i
		if ResourceLoader.exists(click_path):
			_clicks.append(load(click_path) as AudioStream)
		else:
			push_warning("[DiceAudio] missing click clip: " + click_path)
	for i in range(1, ROLL_COUNT + 1):
		var roll_path: String = ROLL_PATH % i
		if ResourceLoader.exists(roll_path):
			_rolls.append(load(roll_path) as AudioStream)
		else:
			push_warning("[DiceAudio] missing roll clip: " + roll_path)
	for _i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "DICE"
		add_child(player)
		_pool.append(player)
	if "--debug-battle" in OS.get_cmdline_user_args():
		_suppressed = true


func set_suppressed(suppressed: bool) -> void:
	_suppressed = suppressed


## Called once per play_rolls with the number of dice actually thrown (frozen
## dice excluded). Resets per-die debounce state; in one-shot mode this IS the
## roll sound.
func on_roll_started(rolling_count: int) -> void:
	_last_impact_ms.clear()
	if not ONE_SHOT_MODE or _suppressed or rolling_count <= 0 or _rolls.is_empty():
		return
	var energy: float = clampf(float(rolling_count - 1) / 4.0, 0.0, 1.0)
	_play(_rolls[randi_range(0, _rolls.size() - 1)],
		lerpf(ONE_SHOT_DB_1_DIE, ONE_SHOT_DB_5_DICE, energy), 1.0)


## One physics contact (die vs die, wall, or floor — DiceTray3D reports them
## all). speed is the die's post-collision speed, the energy proxy.
func on_die_impact(die_id: int, speed: float) -> void:
	if ONE_SHOT_MODE or _suppressed or _clicks.is_empty():
		return
	if speed < IMPACT_SPEED_MIN:
		return
	var now: int = Time.get_ticks_msec()
	if int(_last_impact_ms.get(die_id, -DEBOUNCE_MS)) + DEBOUNCE_MS > now:
		return
	_last_impact_ms[die_id] = now
	var t: float = clampf((speed - IMPACT_SPEED_MIN) / (IMPACT_SPEED_FULL - IMPACT_SPEED_MIN), 0.0, 1.0)
	var db: float = lerpf(IMPACT_DB_QUIET, IMPACT_DB_MAX, t) + randf_range(-VOLUME_JITTER_DB, VOLUME_JITTER_DB)
	_play(_clicks[randi_range(0, _clicks.size() - 1)], db, randf_range(PITCH_MIN, PITCH_MAX))


## The die crossed its settle threshold (fires again if it gets bumped and
## re-settles — that re-tick is physical, keep it).
func on_die_settled(_die_id: int) -> void:
	if ONE_SHOT_MODE or _suppressed or _clicks.is_empty():
		return
	_play(_clicks[randi_range(0, _clicks.size() - 1)],
		SETTLE_DB + randf_range(-VOLUME_JITTER_DB, VOLUME_JITTER_DB), SETTLE_PITCH)


func _play(stream: AudioStream, volume_db: float, pitch: float) -> void:
	var player: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()
