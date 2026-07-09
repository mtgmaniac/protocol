# Overload Protocol — ANIMATION & GAME FEEL SPEC
*The plan for making battle feel alive. Built on the feedback system that already exists. Aesthetic guardrails first, because they constrain every choice below.*

## Aesthetic guardrails (do not violate)
- **Flat, no glow, no gradients, no bloom.** Pixel art. m5x7 font. Effects are flat shapes / pixel particles, palette-driven.
- **Meaning-based color holds:** cyan = player, red = enemy/damage, green = protocol/heal, gold = commit/crit/reward. Animations use these colors, never decorative hues.
- **Chase weight + readability, not spectacle.** The Slice & Dice lesson: clean, snappy, legible, with the dice roll as the star. Cold and industrial, not flashy. If an effect doesn't clarify cause→effect or add satisfying weight, cut it.
- **Snappy timing.** Never let a turn drag. Enemies resolve *visibly* so the player can follow consequences, but every beat is tight.

---

## What already exists (don't rebuild)
- **Event-driven feedback pipeline** — `combat_manager._emit_event(state, type, amount, side)` emits semantic events: `damage`, `burn`, `heal`, `shield`, `roll_buff`, `freeze`, `cloak`, `taunt`, `evade`, `block`, `survive`, `wipe_shields`. (`burn` is the renamed DoT — see Task 7. The `phase2` event was deleted with the phase-2 system in pkg4; the `curse`/`curseDice` mechanic was cut in `6d9118c`, INVARIANTS #4 — no `curse` event is emitted.)
- **Sequencer** — `battle_scene._play_round_feedback` → `_build_action_feedback_groups` (groups events into actor+effects beats) → `_play_action_feedback_group` (plays them with `ACTION_EFFECT_LEAD_TIME` / `ACTION_FEEDBACK_PAUSE` pacing). This is the timing backbone.
- **Per-card hooks** — `compact_unit_card.play_action_feedback(attack|support|neutral)` (actor tell) and `play_impact_feedback(damage|heal|shield)` (target reaction).
- **Card flash** — `_flash_card(card, event_type)` tweens modulate to a per-type color and back (0.22s).
- **Floating numbers** — `_spawn_floating_text` rises 52px + fades over 0.9s, per-type color/text.
- **Dice** — `_animate_die` (2D shuffle: scale-pop, tumble, number-cycle, settle to quality color) AND `dice_tray_3d.gd` (real 3D RigidBody dice tweened to the correct face; `set_die_frozen_visual` exists).
- **Game-feel primitives (`battle_feedback.gd`)** — `_hit_pause` (impact freeze) · `_slow_mo` (the 20-celebration time beat) · `_lunge` (attacker step-in) · `_shake` (per-card recoil + board shake) · `_burst_particles` · `_tracer` · `_death_scatter` (death debris) · `_shield_shatter` (breaking-glass shield break) · card flash · floating punch-numbers · HP `drain_hp` (animated bar + red chip-ghost, in `compact_unit_card._set_hp_display`).

## What's missing (the "alive" layer)
Full pixel-particle SYSTEM (only ad-hoc bursts today) · camera/zoom flourishes · per-faction flavor. Everything on the original "missing" list is now built (HP drain, death scatter, 20-celebration slow-mo, shield-shatter) or **retired** (see "Retired" below); the animation layer no longer carries unimplemented spec.

### Retired (removed from spec — do not re-add as "unimplemented")
These were spec-only intentions with zero code; they are **cut** so future feedback audits stop re-flagging them as missing:
- **Anticipation lean** (pre-attack wind-up) — the attacker `_lunge` is the whole Action tell; no separate wind-up.
- **Melee travel-tracer** — a melee hit IS the lunge; only Chain/Leech draw tracers (a deliberate keyword accent, not a normal-attack projectile).
- **Idle bob** — units do not bob at rest; the board is quiet between beats by design.

---

## The model: every action is one BEAT
Action → Impact → Reaction → Settle. (Anticipation and a separate Travel phase
were **retired** — the lunge is the whole tell, and a melee hit is the lunge
itself.)

| Phase | What it looks like | Hook |
|---|---|---|
| **Action** | Attacker lunges toward target & back. Support = gentle rise/pulse (so attack vs support read differently). | `play_action_feedback(kind)` + `_lunge` ✅ |
| **Impact** | hit-pause (40–90ms, scale w/ damage) + target card shake + recoil + pixel-particle burst. | `_hit_pause` · `_shake` · `_burst_particles` · `_flash_card` ✅ |
| **Reaction** | flash + animated HP drain with a red "chip" ghost bar trailing the loss. Shield-break = distinct shatter. | `_set_hp_display` (drain + chip-ghost) ✅ · `_shield_shatter` ✅ |
| **Settle** | Number punches in big then shrinks while floating; execute bigger/red. | `_spawn_floating_text` punch-scale ✅ |

### Ambient life (outside the beat)
- **Active highlight:** selected/acting unit gets a stronger highlight pulse.
- **Death:** the card grays out and **scatters into flat pixel debris** (`_death_scatter`, fired at the fatal-hit event; team-tinted + ash, arc-and-fall). ✅

### The signature moment
**Effective-face 20 / overload** lands like an event: gold die face, a gold
screen wash (commit color), the ability-name slam, board shake, and a **brief
slow-mo beat** (`_slow_mo`). Fires on the die's *effective* face == 20 with **no
nat/raw check** — that concept is removed game-wide (NK-02). ✅

---

## Primitive library (the reusable toolbox — all built, in `battle_feedback.gd`)
Every effect is a composition of these small generic functions:
- `_lunge(card, side)` — actor step-in / recoil
- `_shake(node, amplitude, dur)` — decaying jitter (per-card recoil AND board shake)
- `_hit_pause(amount, extra)` — brief scene freeze (routed through the global arbiter)
- `_slow_mo()` — the 20-celebration time beat (global arbiter; never stacks with `_hit_pause`)
- `_tracer(from, to, color)` — flat pixel streak (Chain / Leech)
- `_burst_particles(card, color, count)` — flat pixel square burst (hit / ember)
- `_death_scatter(card, side, stagger)` — team-tinted + ash debris, arc-and-fall
- `_shield_shatter(card, color)` — expanding ring + angular glass slivers (distinct from a hit burst)
- `_spawn_floating_text(...)` — punch-scale number that rises + fades
- HP drain lives on the card: `compact_unit_card._set_hp_display(displayed, forecast)` tweens the green fill down while the red chip-ghost trails and shrinks over the lost slice
- `_flash_card(card, event_type)` — per-type modulate flash

---

## Event → primitive mapping (data-driven; this is what makes it robust)
Drive feedback from a TABLE, not branching code, so new effects = new rows.

| event_type | actor | target | extras |
|---|---|---|---|
| `damage` | lunge(attack) | flash(red) + shake(scale by amt) + recoil + particles(red) + hit_pause(scale by amt) | drain_hp + punch_number("-N", red) |
| `burn` (tick) | — | flash(red, soft) + small particles(red) | punch_number("-N", red); apply burn status icon |
| `heal` | rise/pulse(support) | flash(green) + particles(green, gentle) | drain_hp upward + punch_number("+N", green) |
| `shield` | rise(support) | flash(cyan) + shield-on particles | number("SH +N", cyan); show shield pip |
| `wipe_shields` | — | `_shield_shatter` (gold) + gold flash | number("SHIELDS WIPED") |
| `roll_buff` | pulse(support) | flash(cyan) | number("+N ROLL", cyan) |
| `freeze` | — | ice-over die visual (`set_die_frozen_visual`) + cyan flash | number("FROZEN N") |
| `cloak` / `evade` | pulse(support) | fade-pulse on portrait | number("CLOAK"/"EVADE") |
| fatal hit (`hp_after ≤ 0`) | — | card grays out → `_death_scatter` (micro-staggered on multi-death) | death sfx once per target |
| effective-face 20 (overload) | — | gold die face + gold screen wash + ability-name slam + board shake + `_slow_mo` | overload sfx |

### Keyword rows (pkg8.4 — implemented in battle_feedback._play_keyword_feedback)

| event_type | feedback |
|---|---|
| `chain` | tracer(actor→jumped target, electric cyan) + "-N" on both hits |
| `detonate` | ember particle burst on the target + "-N" |
| `execute` | heavier hit_pause + deep-red oversized "EXECUTE -N" |
| `breach` | gold `_shield_shatter` (ring + glass slivers) on the target |
| `spike` | rust spark burst on the ATTACKER at retaliation + "-N" |
| `siphon` | amber pip drifts protocol bar → enemy card ("-N") |
| `jam` | static flicker on the die's amber tint shell + "JAM ≤N" cap stamp |
| `rewrite` | pending marker scrambles digits, slams to "REWRITE→3" |
| `hijack` | ghost label drifts from the tray to the enemy card |
| `mark` | gold "◎ MARKED" crosshair stamp punch |
| `block` (amount 0 = firewall) | hex flash (flat cyan hexagon pop) + "✕ NEGATED" tick |
| `leech` | dim red return tracer from the drained enemy (paired `leech` event) + the heal event's green number |
| `decloak` | portrait resolves sharp + white flash |
| `freeze` | crust + tint on the die (ice cyan / petrify stone-gray) |
| effective-face-20 overload | + ability-name slam across the acting card (pkg8.3) + `_slow_mo` beat |

Detonate composes chip-flash (burn-color chip pop at the status strip) →
ember burst → combined number. Execute adds its own deep-red card flash on
top of the heavier hit-pause and oversized number.

---

## Architecture (robustness)
Extract a dedicated **`BattleFeedback`** component (a node) out of `battle_scene.gd`:
- Subscribes to the combat event stream; owns the sequencer (move `_play_round_feedback` + pacing here).
- Holds the primitive library above.
- Reads the event→primitive **table** to decide what fires per event.
- Sound-aware from day one: each table row can also name an SFX key, so one event drives both a visual primitive and a sound. (Audio clips come later — out of scope for demo — but wire the hook now.)

This dovetails with the `battle_scene.gd` decomposition in **Task 2** — pull feedback out at the same time.

---

## Collision / simultaneity rules (baked into `battle_feedback.gd`)
When several effects want to fire at once, the pass follows these so it doesn't
read muddy:
- **Sequential-in-rules → sequential feedback.** Events replay in the engine's
  resolve order via `_build_action_feedback_groups` + the effects loop, so two
  keywords on one overload face play in order with the sequencer's stagger. A
  sound + a shake for the same hit are *one moment, two channels* and fire together.
- **One global-effect arbiter.** All screen-wide TIME effects (`_hit_pause`,
  `_slow_mo`) go through the `_global_fx_active` gate — they never compound
  (double freeze = frame-drop; stacked slow-mo = broken). **This is the choke
  point the audio pass hooks for global screen-effect SFX.** Frame-local effects
  (per-card shake, per-unit `_death_scatter`, HP drains on different units) are
  exempt and may run simultaneously. The board shake is a positional channel,
  separate from the time arbiter.
- **Batch simultaneous same-type effects.** Cheap effects (HP drains) fire
  together; big effects (deaths) take a **micro-stagger** (`death_ordinal *
  0.05s`) so a chain that kills two reads as two deaths, not one.
- **The 20-celebration must not stall.** `_slow_mo` is capped short
  (`SLOWMO_REAL_DUR`, wall-clock) so frequent 20s never make a run feel laggy.

## Build order (all shipped)
- **Tier 1:** hit_pause · attacker lunge · drain_hp + chip-ghost · punch_number. ✅
- **Tier 2:** card/board shake · Chain/Leech tracers · 20-celebration (gold wash + slow-mo) · shield-shatter. ✅
- **Tier 3 (open):** full pixel-particle SYSTEM (beyond ad-hoc bursts) · camera/zoom flourishes · per-faction flavor.
Death scatter (was Tier 3) is shipped via `_death_scatter`.

## Reference touchpoints in code
`scripts/battle/combat_manager.gd::_emit_event` · `scripts/battle/battle_scene.gd::_play_round_feedback / _play_action_feedback_group / _flash_card / _spawn_floating_text / _animate_die` · `scripts/ui/compact_unit_card.gd::play_action_feedback / play_impact_feedback` + HP bar · `scripts/battle/dice_tray_3d.gd`.
