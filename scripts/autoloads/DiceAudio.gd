extends Node
## Physical dice audio. DiceTray3D reports contacts and settles here; this owns
## the click/settle streams, the voice pool, and all shaping (velocity->volume,
## pitch spread, per-die debounce). Everything plays on the DICE bus (predefined
## in default_bus_layout.tres, child of SFX — the SOUND FX slider governs it as
## a parent, the DICE settings row is the independent trim).
##
## Asset model (pass 3): six SYNTHESIZED single-transient clicks (~55ms, zero
## internal bounce character) — the physics composes ALL rhythm — plus a
## dedicated softer/lower settle sample for the come-to-rest cue.
##
## Zero-allocation at play time: streams are loaded once, the player pool is
## preallocated, and the per-die debounce dictionary is cleared (not rebuilt)
## each roll. The hot path allocates nothing.

const CLICK_COUNT := 6
const CLICK_PATH := "res://assets/audio/sfx/dice/dice_click_%02d.wav"
const SETTLE_PATH := "res://assets/audio/sfx/dice/dice_settle_01.wav"

const POOL_SIZE := 6              # voice cap: oldest voice is stolen beyond this

# ── Trigger thinning (pass 2, retimed pass 4) — every gate is a tunable ──────
# Tuned against the seeded 5-dice physics probe (DiceTrayPhysicsProbe, seed
# 20260705): ~95-113 contacts per roll (~30/s). The pass-2 gate at 7.0 kept
# counts in the 8-15 band but killed the TIMING: mid-roll bounces run at
# speeds 2-6, so everything after ~0.9s of a ~2.4s roll was silent, then the
# settle ticks clumped at the end (per-contact log, pass 4). The fix: admit
# the mid-roll band but keep it QUIET via the curve, and pace with time
# windows instead of a per-roll budget.
const IMPACT_SPEED_MIN := 2.5     # just above the sub-2 micro-jitter tail:
                                  # mid-roll tumble bounces (2.6-5.7) now speak
const IMPACT_SPEED_FULL := 14.0   # only a hard direct hit plays at max
const VOLUME_CURVE_EXP := 2.0     # t^N: steep — mid-roll bounces sit within a
                                  # few dB of QUIET, early wall hits near MAX
const IMPACT_DB_QUIET := -20.0
const IMPACT_DB_MAX := -3.0       # headroom against pileups on the DICE bus
const DEBOUNCE_MS := 250          # per-die WINDOW (replaces the per-roll budget):
                                  # max 1 click per die per 250ms — one click per
                                  # bounce-cycle, so a die stays audible for the
                                  # whole roll instead of spending 4 clicks in
                                  # the first violent 200ms
const GLOBAL_MIN_GAP_MS := 110    # min gap between ANY two clicks game-wide
                                  # (~9 clicks/s hard ceiling); simultaneous
                                  # landings collapse (see boost below)
const COLLAPSE_BOOST_DB := 1.5    # ...into one slightly louder click, never a chord
const PITCH_MIN := 0.9            # synth clicks are clean single transients —
const PITCH_MAX := 1.15           # this spread reads as natural dice, not mush
const VOLUME_JITTER_DB := 1.5
# Per-die wind-down (pass 5): dice rocking to rest generate a late flurry of
# 3-5 speed contacts that passed the gate and read as a phantom reroll. Once a
# die's contacts have stayed below WIND_DOWN_SPEED for WIND_DOWN_MS, that die
# is DONE speaking for the roll — no further clicks no matter how many
# micro-contacts follow. It still gets its (single) settle tick.
const WIND_DOWN_SPEED := 6.0      # above the base gate: 3-5 speed rocking never
                                  # resets the clock, real bounces (6+) do
const WIND_DOWN_MS := 150         # this long below WIND_DOWN_SPEED = done

# Settle ticks: at most ONE per die per roll, staggered 30-80ms, soft, and
# subject to the global rate limiter (colliding ticks drop — fewer end sounds
# is the goal). dice_settle_01.wav is already softer/lower; near-unity pitch.
const SETTLE_DB := -14.0          # set to -80.0 for full silence at rest (Kev's call)
const SETTLE_STAGGER_MIN_S := 0.03
const SETTLE_STAGGER_MAX_S := 0.08
const SETTLE_PITCH_MIN := 0.95
const SETTLE_PITCH_MAX := 1.05

var _clicks: Array[AudioStream] = []
var _settle: AudioStream = null
var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _last_impact_ms: Dictionary = {}  # die instance id -> last click Time.get_ticks_msec()
var _lively_ms: Dictionary = {}       # die id -> last contact >= WIND_DOWN_SPEED
var _wound_down: Dictionary = {}      # die id -> true once done speaking this roll
var _settled_dice: Dictionary = {}    # die id -> true once its settle tick is spent
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

var _last_click_ms: int = -100000
var _last_click_player: AudioStreamPlayer = null
var _last_click_boosted: bool = false

# Verbose per-contact decision log (timing diagnosis): every contact prints
# time-into-roll, die, speed, and which gate decided its fate. Debug tool —
# leave off in normal play, the per-roll stats line is the always-on summary.
const DEBUG_CONTACT_LOG := false
var _log_die_names: Dictionary = {}


func _log_contact(die_id: int, t_ms: int, speed: float, decision: String) -> void:
	if not DEBUG_CONTACT_LOG:
		return
	if not _log_die_names.has(die_id):
		_log_die_names[die_id] = "d%d" % (_log_die_names.size() + 1)
	print("[DiceAudio] t=%4dms %s v=%5.1f %s" % [t_ms, _log_die_names[die_id], speed, decision])


func _ready() -> void:
	for i in range(1, CLICK_COUNT + 1):
		var click_path: String = CLICK_PATH % i
		if ResourceLoader.exists(click_path):
			_clicks.append(load(click_path) as AudioStream)
		else:
			push_warning("[DiceAudio] missing click clip: " + click_path)
	if ResourceLoader.exists(SETTLE_PATH):
		_settle = load(SETTLE_PATH) as AudioStream
	else:
		push_warning("[DiceAudio] missing settle clip: " + SETTLE_PATH)
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
## dice excluded). Resets per-die debounce/budget state and the stats window.
func on_roll_started(rolling_count: int) -> void:
	_last_impact_ms.clear()
	_lively_ms.clear()
	_wound_down.clear()
	_settled_dice.clear()
	_stat_active = true
	_stat_dice = rolling_count
	_stat_contacts = 0
	_stat_gated = 0
	_stat_clicks = 0
	_stat_settles = 0
	_stat_contacts_per_die.clear()
	_stat_clicks_per_die.clear()
	_stat_start_ms = Time.get_ticks_msec()


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
	if _suppressed or _clicks.is_empty():
		return
	_stat_contacts += 1
	_stat_contacts_per_die[die_id] = int(_stat_contacts_per_die.get(die_id, 0)) + 1
	var now: int = Time.get_ticks_msec()
	var t_ms: int = now - _stat_start_ms
	# Wind-down bookkeeping runs on EVERY contact (a below-gate contact is
	# still evidence the die has lost its energy). Done is done for the roll —
	# even a later hard knock stays silent; the settle tick is the die's coda.
	if speed >= WIND_DOWN_SPEED:
		_lively_ms[die_id] = now
	elif not _wound_down.has(die_id) and now - int(_lively_ms.get(die_id, _stat_start_ms)) > WIND_DOWN_MS:
		_wound_down[die_id] = true
	if _wound_down.has(die_id):
		_log_contact(die_id, t_ms, speed, "wound-down")
		return
	if speed < IMPACT_SPEED_MIN:
		_log_contact(die_id, t_ms, speed, "below-threshold")
		return
	_stat_gated += 1
	if int(_last_impact_ms.get(die_id, -DEBOUNCE_MS)) + DEBOUNCE_MS > now:
		_log_contact(die_id, t_ms, speed, "debounced")
		return
	# Global rate limit: two dice landing in the same instant read as ONE hit.
	# The dropped click nudges the in-flight one a hair louder instead.
	if _last_click_ms + GLOBAL_MIN_GAP_MS > now:
		if _last_click_player != null and _last_click_player.playing and not _last_click_boosted:
			_last_click_player.volume_db += COLLAPSE_BOOST_DB
			_last_click_boosted = true
		_log_contact(die_id, t_ms, speed, "rate-limited")
		return
	_last_impact_ms[die_id] = now
	_log_contact(die_id, t_ms, speed, "PLAYED")
	var t: float = pow(clampf((speed - IMPACT_SPEED_MIN) / (IMPACT_SPEED_FULL - IMPACT_SPEED_MIN), 0.0, 1.0), VOLUME_CURVE_EXP)
	var db: float = lerpf(IMPACT_DB_QUIET, IMPACT_DB_MAX, t) + randf_range(-VOLUME_JITTER_DB, VOLUME_JITTER_DB)
	_stat_clicks += 1
	_stat_clicks_per_die[die_id] = int(_stat_clicks_per_die.get(die_id, 0)) + 1
	_play(_clicks[randi_range(0, _clicks.size() - 1)], db, randf_range(PITCH_MIN, PITCH_MAX))


## The die crossed its settle threshold. At most ONE tick per die per roll
## (a bumped-and-resettled die does not tick again), staggered by a random
## 30-80ms and subject to the global rate limiter — colliding ticks drop;
## fewer end sounds is the goal.
func on_die_settled(die_id: int) -> void:
	if _suppressed or _settle == null:
		return
	if _settled_dice.has(die_id):
		return
	_settled_dice[die_id] = true
	await get_tree().create_timer(randf_range(SETTLE_STAGGER_MIN_S, SETTLE_STAGGER_MAX_S)).timeout
	if _last_click_ms + GLOBAL_MIN_GAP_MS > Time.get_ticks_msec():
		if DEBUG_CONTACT_LOG:
			print("[DiceAudio] t=%4dms SETTLE dropped (rate-limited)" % (Time.get_ticks_msec() - _stat_start_ms))
		return
	_stat_settles += 1
	if DEBUG_CONTACT_LOG:
		print("[DiceAudio] t=%4dms SETTLE played" % (Time.get_ticks_msec() - _stat_start_ms))
	_play(_settle, SETTLE_DB + randf_range(-VOLUME_JITTER_DB, VOLUME_JITTER_DB),
		randf_range(SETTLE_PITCH_MIN, SETTLE_PITCH_MAX))


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
