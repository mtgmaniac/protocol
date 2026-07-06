# Overload Protocol — ANIMATION & GAME FEEL SPEC
*The plan for making battle feel alive. Built on the feedback system that already exists. Aesthetic guardrails first, because they constrain every choice below.*

## Aesthetic guardrails (do not violate)
- **Flat, no glow, no gradients, no bloom.** Pixel art. m5x7 font. Effects are flat shapes / pixel particles, palette-driven.
- **Meaning-based color holds:** cyan = player, red = enemy/damage, green = protocol/heal, gold = commit/crit/reward. Animations use these colors, never decorative hues.
- **Chase weight + readability, not spectacle.** The Slice & Dice lesson: clean, snappy, legible, with the dice roll as the star. Cold and industrial, not flashy. If an effect doesn't clarify cause→effect or add satisfying weight, cut it.
- **Snappy timing.** Never let a turn drag. Enemies resolve *visibly* so the player can follow consequences, but every beat is tight.

---

## What already exists (don't rebuild)
- **Event-driven feedback pipeline** — `combat_manager._emit_event(state, type, amount, side)` emits semantic events: `damage`, `burn`, `heal`, `shield`, `roll_buff`, `freeze`, `cloak`, `taunt`, `curse`, `evade`, `block`, `survive`, `wipe_shields`. (`burn` is the renamed DoT — see Task 7. The `phase2` event was deleted with the phase-2 system in pkg4.)
- **Sequencer** — `battle_scene._play_round_feedback` → `_build_action_feedback_groups` (groups events into actor+effects beats) → `_play_action_feedback_group` (plays them with `ACTION_EFFECT_LEAD_TIME` / `ACTION_FEEDBACK_PAUSE` pacing). This is the timing backbone.
- **Per-card hooks** — `compact_unit_card.play_action_feedback(attack|support|neutral)` (actor tell) and `play_impact_feedback(damage|heal|shield)` (target reaction).
- **Card flash** — `_flash_card(card, event_type)` tweens modulate to a per-type color and back (0.22s).
- **Floating numbers** — `_spawn_floating_text` rises 52px + fades over 0.9s, per-type color/text.
- **Dice** — `_animate_die` (2D shuffle: scale-pop, tumble, number-cycle, settle to quality color) AND `dice_tray_3d.gd` (real 3D RigidBody dice tweened to the correct face; `set_die_frozen_visual` exists).

## What's missing (the "alive" layer — all confirmed absent)
Screen/card shake · particles (none) · hit-pause/freeze-frame · projectiles/traveling effects · anticipation/wind-up · idle motion · death animation (units only gray out via modulate) · animated HP drain (bars snap).

---

## The model: every action is one BEAT with six phases
Anticipation → Action → Travel → Impact → Reaction → Settle.
You already have Action / Impact / Reaction (partially). The life is in the missing three.

| Phase | What it looks like | Hook to build on |
|---|---|---|
| **Anticipation** | Actor leans ~8px away from target (~0.12s) — wind-up. For enemies this is the telegraph. | extend `play_action_feedback` |
| **Action** | Attacker lunges toward target & back. Support = gentle rise/pulse (so attack vs support read differently). | `play_action_feedback(kind)` |
| **Travel** | Flat pixel tracer crosses attacker→target (cyan player / red enemy), arrives as impact fires. Melee = the lunge itself. | new primitive `tracer()` |
| **Impact** | hit-pause (40–80ms, scale w/ damage) + target card shake + recoil (jolt away) + pixel-particle burst. | new primitives; `_flash_card` stays |
| **Reaction** | flash (have it) + animated HP drain with a "chip" ghost bar trailing the loss. Shield-break = distinct shatter. | new `drain_hp()`; HP bar in `compact_unit_card` |
| **Settle** | Number punches in big then shrinks while floating; crits bigger/gold. Die lock = small punch + tick of shake. | extend `_spawn_floating_text`, `_animate_die` |

### Ambient life (outside the beat)
- **Idle bob:** 1–2px vertical sine per unit, slightly desynced, ~2s loop. Board breathes even when idle.
- **Active highlight:** selected/acting unit gets a stronger highlight pulse.
- **Death:** flash white → shake → scatter into pixel debris (or dissolve + fall + fade) + a longer hit-pause. Hooks: `_on_unit_killed`, `survive` event.

### The signature moment
**Natural 20 / overload** must land like an event: bigger die settle, screen flash in gold (commit color), optional brief slow-mo. This is the genre's payoff beat — make it feel earned.

---

## Primitive library (the reusable toolbox)
Build these as small, generic functions so every effect is a composition of primitives:
- `lunge(card, dir, dist, dur)` — actor step-in / recoil
- `shake(node, amplitude, dur)` — decaying jitter (card-level and screen-level)
- `hit_pause(ms)` — freeze the scene briefly (Engine time scale or a manual gate)
- `tracer(from_pos, to_pos, color, dur)` — flat pixel projectile/streak
- `spawn_particles(pos, color, count, kind)` — flat pixel burst (hit / shield-shatter / death debris)
- `drain_hp(bar, from, to, dur)` + chip ghost bar
- `punch_number(label)` — scale-in overshoot then settle (wrap existing float)
- `die_settle(die, quality)` — lock punch + quality color + (for 20) the signature flourish
- `flash(node, color, dur)` — generalize existing `_flash_card`

---

## Event → primitive mapping (data-driven; this is what makes it robust)
Drive feedback from a TABLE, not branching code, so new effects = new rows.

| event_type | actor | target | extras |
|---|---|---|---|
| `damage` | lunge(attack) | flash(red) + shake(scale by amt) + recoil + particles(red) + hit_pause(scale by amt) | drain_hp + punch_number("-N", red) |
| `burn` (tick) | — | flash(red, soft) + small particles(red) | punch_number("-N", red); apply burn status icon |
| `heal` | rise/pulse(support) | flash(green) + particles(green, gentle) | drain_hp upward + punch_number("+N", green) |
| `shield` | rise(support) | flash(cyan) + shield-on particles | number("SH +N", cyan); show shield pip |
| `block` / `wipe_shields` | — | shield-**shatter** particles + gold flash | number("BLOCK N" / "SHIELDS WIPED") |
| `roll_buff` | pulse(support) | flash(cyan) | number("+N ROLL", cyan) |
| `freeze` | — | ice-over die visual (`set_die_frozen_visual`) + cyan flash | number("FROZEN N") |
| `cloak` / `evade` | pulse(support) | fade-pulse on portrait | number("CLOAK"/"EVADE") |
| `survive`→death | — | white flash → shake → death-scatter + long hit_pause | — |
| natural 20 | bigger lunge | — | die_settle(signature) + gold screen flash + slow-mo |

### Keyword rows (pkg8.4 — implemented in battle_feedback._play_keyword_feedback)

| event_type | feedback |
|---|---|
| `chain` | tracer(actor→jumped target, electric cyan) + "-N" on both hits |
| `detonate` | ember particle burst on the target + "-N" |
| `execute` | heavier hit_pause + deep-red oversized "EXECUTE -N" |
| `breach` | gold shield-shatter burst on the target |
| `spike` | rust spark burst on the ATTACKER at retaliation + "-N" |
| `siphon` | amber pip drifts protocol bar → enemy card ("-N") |
| `jam` | static flicker on the die's amber tint shell + "JAM ≤N" cap stamp |
| `rewrite` | pending marker scrambles digits, slams to "REWRITE→3" |
| `hijack` | ghost label drifts from the tray to the enemy card |
| `mark` | gold "◎ MARKED" crosshair stamp punch |
| `block` (amount 0 = firewall) | hex flash (flat cyan hexagon pop) + "✕ NEGATED" tick |
| `leech` | dim red return tracer from the drained enemy (paired `leech` event) + the heal event's green number |
| `decloak` | portrait resolves sharp + white pierce flash |
| `freeze` | crust + tint on the die (ice cyan / petrify stone-gray) |
| nat-20 overload | + ability-name slam across the acting card (pkg8.3) |

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

## Build order (tiered — solo-dev friendly; don't boil the ocean)
- **Tier 1 (cheap, biggest feel gain — all extend existing hooks):** hit_pause · attacker lunge · drain_hp + chip bar · punch_number · idle bob.
- **Tier 2:** card/screen shake · ranged tracers · natural-20 celebration · shield-shatter.
- **Tier 3:** full pixel-particle system · death animations · camera/zoom flourishes · per-faction flavor.
Tier 1 alone gets most of the way to "alive."

## Reference touchpoints in code
`scripts/battle/combat_manager.gd::_emit_event` · `scripts/battle/battle_scene.gd::_play_round_feedback / _play_action_feedback_group / _flash_card / _spawn_floating_text / _animate_die` · `scripts/ui/compact_unit_card.gd::play_action_feedback / play_impact_feedback` + HP bar · `scripts/battle/dice_tray_3d.gd`.
