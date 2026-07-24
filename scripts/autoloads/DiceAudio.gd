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

# ── Trigger thinning (pass 2) — every gate is a tunable ──────────────────────
# Tuned against the seeded 5-dice physics probe (DiceTrayPhysicsProbe, seed
# 20260705). Raw stream there: ~95-113 contacts per roll (~30/s), speed
# distribution min~0.7 / p50~3.6 / p75~7.5 / p90~12 / max~17. The old gates
# fired 54 clicks per 5-dice roll ("reads as ~15 dice", Kev); these cut that
# to ~10 front-loaded clicks + settle ticks.
const IMPACT_SPEED_MIN := 7.0     # ~p75 of the contact stream: first bounce or
                                  # two per die speak, micro-settles never do.
                                  # (Old value 1.5 passed 88% of all contacts.)
const IMPACT_SPEED_FULL := 14.0   # ~p90+: only a hard direct hit plays at max
const VOLUME_CURVE_EXP := 2.0     # t^N volume curve: steeper than linear, soft
                                  # end of the passing range stays nearly silent
const IMPACT_DB_QUIET := -22.0
const IMPACT_DB_MAX := -3.0       # clicks are peak-normalized -4 dB; headroom at pileups
const DEBOUNCE_MS := 120          # per-die: a double-bounce inside this is ONE hit
const GLOBAL_MIN_GAP_MS := 45     # min gap between ANY two clicks game-wide —
                                  # simultaneous landings collapse (see boost below)
const COLLAPSE_BOOST_DB := 1.5    # ...into one slightly louder click, never a chord
const PER_DIE_MAX_CLICKS := 4     # per-roll click budget per die; once spent the
                                  # die only gets its settle tick
const PITCH_MIN := 0.85           # samples are pre-pitched down 4 semitones —
const PITCH_MAX := 1.05           # keep in-engine spread modest or it goes muddy
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

# ── Per-roll trigger stats ───────────────────────────────────────────────────
# Tuning data for the thinning gates: one "[DiceAudio]" line prints per roll
# (on_roll_finished, wired from DiceTray3D). Cheap counters, always on.
var _stat_active: bool = false
var _stat_dice: int = 0
var _stat_contacts: int = 0        # raw contacts the tray reported
var _stat_gated: int = 0           # survived the velocity gate
var _stat_clicks: int = 0          # clicks actually fired
var _stat_settles: int = 0
var _stat_contacts_per_die: Dictionary = {}
var _stat_clicks_per_die: Dictionary = {}
var _stat_start_ms: int = 0


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
	_stat_active = true
	_stat_dice = rolling_count
	_stat_contacts = 0
	_stat_gated = 0
	_stat_clicks = 0
	_stat_settles = 0
	_stat_contacts_per_die.clear()
	_stat_clicks_per_die.clear()
	_stat_start_ms = Time.get_ticks_msec()
	if not ONE_SHOT_MODE or _suppressed or rolling_count <= 0 or _rolls.is_empty():
		return
	var energy: float = clampf(float(rolling_count - 1) / 4.0, 0.0, 1.0)
	_play(_rolls[randi_range(0, _rolls.size() - 1)],
		lerpf(ONE_SHOT_DB_1_DIE, ONE_SHOT_DB_5_DICE, energy), 1.0)


## Called by DiceTray3D when the roll resolves — prints the trigger stats line.
func on_roll_finished() -> void:
	if not _stat_active:
		return
	_stat_active = false
	var dur: float = maxf(float(Time.get_ticks_msec() - _stat_start_ms) / 1000.0, 0.001)
	var per_die: Array = []
	for die_id in _stat_contacts_per_die:
		per_die.append("%d/%d" % [int(_stat_clicks_per_die.get(die_id, 0)), int(_stat_contacts_per_die[die_id])])
	print("[DiceAudio] roll: dice=%d dur=%.1fs contacts=%d (%.1f/s) gated=%d clicks=%d settles=%d per-die(clicks/contacts)=%s" % [
		_stat_dice, dur, _stat_contacts, float(_stat_contacts) / dur, _stat_gated,
		_stat_clicks, _stat_settles, " ".join(per_die)])


## One physics contact (die vs die, wall, or floor — DiceTray3D reports them
## all). speed is the die's post-collision speed, the energy proxy.
func on_die_impact(die_id: int, speed: float) -> void:
	if ONE_SHOT_MODE or _suppressed or _clicks.is_empty():
		return
	_stat_contacts += 1
	_stat_contacts_per_die[die_id] = int(_stat_contacts_per_die.get(die_id, 0)) + 1
	if speed < IMPACT_SPEED_MIN:
		return
	_stat_gated += 1
	if int(_stat_clicks_per_die.get(die_id, 0)) >= PER_DIE_MAX_CLICKS:
		return
	var now: int = Time.get_ticks_msec()
	if int(_last_impact_ms.get(die_id, -DEBOUNCE_MS)) + DEBOUNCE_MS > now:
		return
	# Global rate limit: two dice landing in the same instant read as ONE hit.
	# The dropped click nudges the in-flight one a hair louder instead.
	if _last_click_ms + GLOBAL_MIN_GAP_MS > now:
		if _last_click_player != null and _last_click_player.playing and not _last_click_boosted:
			_last_click_player.volume_db += COLLAPSE_BOOST_DB
			_last_click_boosted = true
		return
	_last_impact_ms[die_id] = now
	var t: float = pow(clampf((speed - IMPACT_SPEED_MIN) / (IMPACT_SPEED_FULL - IMPACT_SPEED_MIN), 0.0, 1.0), VOLUME_CURVE_EXP)
	var db: float = lerpf(IMPACT_DB_QUIET, IMPACT_DB_MAX, t) + randf_range(-VOLUME_JITTER_DB, VOLUME_JITTER_DB)
	_stat_clicks += 1
	_stat_clicks_per_die[die_id] = int(_stat_clicks_per_die.get(die_id, 0)) + 1
	_play(_clicks[randi_range(0, _clicks.size() - 1)], db, randf_range(PITCH_MIN, PITCH_MAX))


## The die crossed its settle threshold (fires again if it gets bumped and
## re-settles — that re-tick is physical, keep it).
func on_die_settled(_die_id: int) -> void:
	if ONE_SHOT_MODE or _suppressed or _clicks.is_empty():
		return
	# Same global gap as impacts: dice force-settled in the same instant
	# collapse to one tick instead of a chord.
	if _last_click_ms + GLOBAL_MIN_GAP_MS > Time.get_ticks_msec():
		return
	_stat_settles += 1
	_play(_clicks[randi_range(0, _clicks.size() - 1)],
		SETTLE_DB + randf_range(-VOLUME_JITTER_DB, VOLUME_JITTER_DB), SETTLE_PITCH)


var _last_click_ms: int = -100000
var _last_click_player: AudioStreamPlayer = null
var _last_click_boosted: bool = false


func _play(stream: AudioStream, volume_db: float, pitch: float) -> void:
	var player: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()
	_last_click_ms = Time.get_ticks_msec()
	_last_click_player = player
	_last_click_boosted = false
