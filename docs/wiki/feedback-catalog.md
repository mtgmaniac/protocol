# Feedback Catalog — code-verified

> **Code-verified truth as of `6d9118c` (2026-07-08); float-text rows re-verified against the float-text redesign (`feat/float-text-redesign`, 2026-07-10). Reference for UI/icon/audio work (Prompts 6, 7, 8).**
> Part of the [Overload Protocol wiki](INDEX.md). Spec source: `offline-bundle/ANIMATION.md`.

Every row below is the *actual* `if`/firing site, not the intent. Owner: `BattleFeedback`
(`scripts/battle/battle_feedback.gd`) drives the event stream; the die surface lives in
`dice_tray_3d.gd`; card chips/portrait/HP in `compact_unit_card.gd` + `battle_card_view.gd`.

The event stream: `combat_manager._emit_event(state, type, amount, side)` +
`_emit_action_event` → `battle_feedback.play_round_feedback(events)` →
`_build_action_feedback_groups` (splits on `action_start`) → `_play_action_feedback_group`
(`battle_feedback.gd:77`). Each group = one actor beat + its effect events.

---

## 1. Die / tray (`dice_tray_3d.gd`)

| Feedback | Site | Exact condition |
|---|---|---|
| Result face bright + zone emission | `_highlight_top_face:670-698` | die settles; result panel gets `_get_zone_face_style(zone)` (`:746-773`) emission — recharge/strike/surge/crit/overload energies 0.3→2.0 |
| Result face **light outline** | `_highlight_top_face:701-711` | result `FaceBevel%d` recolored to side-dither `.lightened(0.45)`, emission ×1.5 — the crisp ring around the winning face |
| Non-result faces dimmed ~40% | `_highlight_top_face:712-728` | every non-result panel+bevel → `_face_color_for(base).darkened(0.6)`, emission energy 0.15 |
| **20-face gold (die)** | `_highlight_top_face:684-687` | `elif side == "hero" and result == 20` → gold albedo `(0.46,0.26,0.03)` + orange emission `(1.0,0.58,0.10)` ×1.2. Keys on the **effective** face (`result` param), **no nat check** |
| Freeze crust — ice | `_set_die_frozen_visual:1738-1748` | `FrozenFilter` mesh @1.025 scale, `_get_frozen_filter_material()` (cyan) when `flavor != "petrify"`; `FrozenOverlay` label. Applied by `set_die_status:314` / `apply_live_event_visual_state:39-48` on a `freeze` event (reads `freeze_flavor` off state) |
| Freeze crust — petrify (stone-gray) | `_set_die_frozen_visual:1747` | `_get_petrify_filter_material()` when `flavor == "petrify"` (Accretion `beastLynx`) |
| Frozen die = physics blocker | `:168-170`, `_assign_frozen_die_origins:527`, `_adjust_spawn_for_occupants` | frozen dice are immovable static bodies at full collision size; new dice spawn-sidestep them |
| Jam tint + "JAM ≤N" | `_set_die_jam_visual:1767-1792` | `jam_cap > 0` → amber `JamFilter` shell + Label3D `"JAM ≤%d" % jam_cap` visible |
| Jam flicker (on apply) | `play_jam_flicker:1797-1811` | `jam` event → 3× `JamFilter` visible toggle (0.05s off / 0.06s on) |
| Rewrite pending marker | `_set_die_pending_marker:1835-1849` | `rewrite_pending` → `PendingMarker` Label3D `"REWRITE→3"`, purple `(0.82,0.55,1.0)` |
| Rewrite scramble (on apply) | `play_rewrite_scramble:1819-1831` | `rewrite` event → 6× `"REWRITE→%d" % randi` (0.05s) then settle `"REWRITE→3"` |
| Hijack pending marker | `_set_die_pending_marker:1835` (hijack branch) | `hijack_pending` → `PendingMarker` label (hijack text). Plus a drifting `HJ` pip (see Table 3) |
| Die roll / settle punch | `_finish_roll:445`, `_set_die_result_scale:170` | on roll resolution — result die scales its `Visuals` container (never the RigidBody, so collision stays) |
| **Roll-buff float at the die** | `battle_feedback._spawn_roll_buff_float` | `roll_buff` event → `+N` (shield blue, base font 96) rises off the affected die (`get_die_screen_position`, spawned 90px above the face). A squad-wide buff (≥2 `roll_buff` events on one side in a group) floats ONCE centered over the tray, not once per die. Relocated from the unit card (Kev's ruling: the buff affects the DIE) — this frees blue-at-a-unit to unambiguously mean shield |
| Protocol reroll fly-to-face | `reroll_die_to_result:319-390` | Reroll spend → die freezes, arcs to the new face over `SELECTED_REROLL_TIME` |

**Note (NK-03):** frozen dice are fully alteration-immune upstream (`combat_manager`) — Jam/Rewrite/
Hijack/Nudge/Reroll/Set never reach a frozen die, so no die-surface conflict can occur.

## 2. Unit frame / portrait

| Feedback | Site | Exact condition |
|---|---|---|
| Actor lunge (attack tell) | `_lunge:661-670` | `action_kind == "attack" and not is_tick` (`:89-90`); 26px toward the opposing rail (hero up / enemy down), 0.08s out / 0.16s back |
| Actor action tell (support) | `compact_unit_card.play_action_feedback(kind)` | `:87-88`; `kind` from `_get_action_feedback_kind` — attack (dmg/burn) vs support (shield/heal/cloak/roll_buff/freeze) vs neutral |
| **Frame shake (ONLY caller)** | `_shake:678-689` | fires **only** on a `damage` effect event (`:135-139`); amplitude `clampf(2.0 + amt*0.16, 2, 11)`, 0.22s, 7 decaying steps. **No shake on death, burn, or crit** |
| Portrait ghosted (cloak) | `compact_unit_card.gd:468-469` | `cloaked` state → portrait modulate `(0.70,0.80,0.95,0.42)`. State-driven, not a chip (pkg8.1) |
| Portrait grayed (dead) | `compact_unit_card.gd:467` | `dead` → modulate `(0.48,0.50,0.58,0.55)`, **plus `_death_scatter`** debris fired at the fatal-hit event (F-08) |
| Decloak flash | `_resolve_portrait_sharp:604-610` | `decloak` event → modulate `(1.35,1.35,1.4)` → base over 0.24s |
| Floating numbers | `_spawn_floating_text` → `_spawn_float_label` | any effect event with non-empty `_build_floating_text`; base font **96 raw px** (was `scale_font_size(20)`=28 — raw like the card's own name/HP at 72, so the number out-sizes the card text), outline 12, pixel-snapped spawn, spawns over the portrait (30% down the card, off the nameplate); rises 72px over 1.5s, alpha holds 0.6s then fades (Kev 2026-07-10: 0.9s read too short-lived), punch-scale-in. **Text:** damage/burn/chain/detonate/spike/execute `-N` · heal `+N` · shield `+N` (blue at a UNIT now = shield only) · block `✕`(amt≤0)/`✕ N`(partial) — the one glyph kept, negation is otherwise invisible · **freeze/mark/wipe_shields float NOTHING** (cut — redundant with chip + keyword visual) · roll_buff floats at the DIE (Table 1), never at the card · **leech/pierce/accrete/revive → "" (paired events carry the numbers)** · unknown events float nothing (default `""`). Color `_get_floating_color`; damage size scales `0.95–1.35` (slope 0.010/amt), execute ×1.6. **Stacking:** same-card floats in flight stack upward (`_live_floats_by_card`, never overlap); burn ticks are per-unit action groups, so multi-unit ticks already sweep ~0.44s apart via the sequencer |
| HP bar (green fill) | `compact_unit_card.gd:302` (`HP_FILL = DT_HP_GREEN`) | green reserved for HP only (INVARIANTS #7) |
| HP drain + chip-ghost | `compact_unit_card.gd:512` (`_set_hp_display`) | on `refresh_card_for_event` the green `_hp_fill.anchor_right` tweens down over 0.30s while the red `_hp_chip` (`HP_CHIP = COLOR_DAMAGE`) pins its left at the new HP and trails its right from the old value — the chip-ghost over the lost slice (F-06). Heal grows the green upward |
| **Six-chip row** | `_build_compact_status_tokens:382-443` | Burn `☠`(p0) · Shield `⬡`(p1) · Mark(p1) · ±Roll `🎲`(p2) · Firewall(p3) · Taunt(p3). Cap `STATUS_MAX_VISIBLE` + `+N` overflow badge. All state-driven |
| TAUNT chip (clears round-end, NK-08) | `:440-441` | chip on `lured_by_id != ""` (enemy-side taunt on a hero). Auto-expires because `lured_by_id` is cleared at the round-end tick in `combat_manager` — no persistent marker |
| Summon enters frame | `battle_scene.gd:2576` (`type == "summon"`) | injected unit builds a new card (min card size enforced). **Handled in battle_scene, not the feedback event table** |

## 3. Keyword action (`battle_feedback._play_keyword_feedback:433`)

| Feedback | Site | Exact condition |
|---|---|---|
| Line-draw tracer | `_tracer:471-487` | actor-card center → target-card center, 5px `Line2D`, fades 0.28s after 0.10s hold. Used by Chain + Leech |
| Chain (per hop) | `:435-436` | one cyan `(0.55,0.85,1.0)` tracer **per `chain` event** emitted (combat_manager emits one per jump) |
| Detonate | `_chip_flash_then_burst:493-517` (`:437-438`) | burn-color chip pops at the status strip (0.08s) → hands off to a 14-shard ember burst `(0.95,0.55,0.20)` |
| Execute | `_play_action_feedback_group` execute branch | `execute` event → heavier `_hit_pause(maxi(peak,8), 0.05)` + deep-red card flash `(1.0,0.30,0.30)` + oversized `-N` (float ×1.6 — the word "EXECUTE" was cut; the pause + deep-red flash carry the identity) |
| Breach | `_shield_shatter` | `breach` event → gold `(1.0,0.82,0.20)` `_shield_shatter` (expanding ring + angular glass slivers) on target — distinct from the square-confetti burst (F-10). `wipe_shields` also fires `_shield_shatter` |
| Leech | `:443-446` | `leech` event → dim-red `(0.85,0.30,0.30)` return tracer source→target; the paired `heal` event carries the green `+N` |
| Siphon | `_drift_pip:578-599` (`:451-455`) | `siphon` event → amber `(0.95,0.76,0.28)` pip drifts protocol-bar-center → enemy card, label `-N` |
| Hijack | `:456-458` | `hijack` event → `HJ` pip drifts tray-center → enemy card (+ the die pending marker, Table 1) |
| Spike | `:441-442` | `spike` event → rust `(0.86,0.42,0.28)` 8-shard burst on the retaliating card + `-N` float. **Readout pip only otherwise** |
| Mark applied | `MARK` chip only | `mark` event / `marked` state — the `◎ MARKED` float was cut (redundant with the chip) |
| Mark consumed | (no dedicated pip) | `marked` cleared in `combat_manager` on the next real hit — chip disappears state-driven |
| Ward consume (firewall) | `_hex_flash` (`_play_keyword_feedback` block branch) | `block` event with `amount <= 0` → cyan hexagon pop + `✕` float (was `✕ NEGATED` — the word cut, the glyph kept) |

## 4. Screen / global

| Feedback | Site | Exact condition |
|---|---|---|
| **Overload celebration** (gold wash + board shake + slow-mo) | `_celebrate_overload` + `_slow_mo` | `action.zone == "overload"` (`:95`) → `overload` sfx + full-rect gold `ColorRect` α 0→0.16→0 (~0.31s) + board `_shake(9, 0.34)`, then a brief `_slow_mo` time beat at the end of the group (F-09). **Effective-face-20, no nat check** |
| Ability-name slam | `_slam_ability_name:615-650` | on overload (`:99`) → gold ability-name label punches across the actor card, holds 0.42s, snaps out |
| Global-effect arbiter (`_global_fx_active`) | `_hit_pause` + `_slow_mo` | ONE owner of `Engine.time_scale`; time effects never compound. `_hit_pause` = `time_scale 0` for `clampf(0.04 + amt*0.0018, 0.04, 0.09) + extra` (execute +0.05, plain damage); overload uses `_slow_mo` (dilate to `SLOWMO_SCALE` for `SLOWMO_REAL_DUR` wall-clock) instead. Hit-pause **skipped after a fatal hit** so death reads immediately. **Audio pass hooks this gate for global SFX** |
| Screen shake vs frame shake | board: `_celebrate_overload:419` · card: `_shake:139` | **global** board shake only on overload; **frame-local** card shake only on `damage` |
| Round tick / turn transition | `combat_manager._tick_end_of_round_states` | burn ticks, shields + roll buffs expire per-side here. **No dedicated banner** — component events (shield-expiry, burn tick) drive card refresh |
| Protocol pip fill / spend | `protocol_pips.gd:_draw:37-77`; updated `battle_scene.gd:~1607-1626` | filled = `DT_AMBER`, empty = border + dark inset, physical-pixel grid. `+1`/turn, Nudge 1 / Reroll 2 / Set 3, cap 10 (economy in `battle_engine`/`protocol_actions`) |
| Boss standing-rule cue | *(none dedicated)* | ROOT ACCESS → `rewrite` feedback; ACCRETION → `shield`/`accrete` feedback; ASSEMBLY LINE / THE BROOD → `summon`. **No standing-rule banner** — surfaces only via component events + round log (Finding) |
| Reward / relic-draft / header | `PersistentHeader.update_progress` (`reward_screen:761`, `intercept_screen:31`, `route_fork_screen:25`, `evolution_screen:429`) | sets the run label on screen entry. No dedicated transition animation |

## 5. Audio — the Prompt-8 worklist

Every `play_sfx` call site. Assets in `assets/audio/sfx/<key>.wav` (all present, all with `.import`).

| Sound | Trigger | Site | Asset | Notes |
|---|---|---|---|---|
| `damage` | `damage` effect event | `battle_feedback.gd:172` | damage.wav | |
| `burn` | `burn` tick event | `:174` | burn.wav | `VOLUME_OVERRIDES` −5 dB |
| `heal` | `heal` event | `:176` | heal.wav | |
| `shield` | `shield` event | `:178` | shield.wav | shield.wav is a reversed clip (per AudioManager header) |
| `freeze` | `freeze` event | `:180` | freeze.wav | |
| `death` | fatal hit (`hp_after ≤ 0`), once per target | `:205` (`_try_play_death_sfx`) | death.wav | dedupes via `_death_sfx_played_ids` |
| `overload` | effective-face 20 (`zone == "overload"`) | `:405` (`_celebrate_overload`) | overload.wav | the 20-face stinger |
| `evolve` | evolution confirm | `evolution_screen.gd:208, 416` | evolve.wav | |
| `item` | item used | `protocol_actions.gd:937` | item.wav | |
| `select` | default UI tap (`play_click`) | `AudioManager.gd:65` | select.wav | `VOLUME_OVERRIDES` −6 dB |
| ~~`phase2`~~ | — | *removed* | phase2.wav (orphan on disk) | **Orphan sfx key CUT this session** (`6c987e6`); the `.wav` file remains on disk, unwired |

**Events with NO sound** (Prompt-8 candidates — currently silent): taunt, jam, rewrite, hijack, mark,
cloak/decloak, siphon, revive, chain, detonate, execute, breach, spike, block/wipe_shields, summon, and
every protocol spend (nudge / reroll / set). Only 10 of the ~26 feedback events carry audio.

---

## Findings

Cross-referenced to [INTERACTION_AUDIT.md](../audit/INTERACTION_AUDIT.md) where applicable.

### Stale (keyed off / naming a removed concept)
- **F-01 — `curse` event is dead spec.** `ANIMATION.md:13` still lists `curse` in the emitted-event
  set, but the `curseDice`/`cursed` mechanic + its `_emit_event(…, "curse", …)` emitter were fully cut
  (`6d9118c`, INVARIANTS #4). No firing site remains. → remove `curse` from `ANIMATION.md:13`.
- **F-02 — "Natural 20" terminology in the spec.** `ANIMATION.md:44` ("Natural 20 / overload") and the
  event-table row `:76` ("natural 20") predate NK-02. The code fires the celebration on the die's
  **effective** face 20 with **no raw/nat check** (`battle_feedback.gd:403`, `dice_tray_3d.gd:684`).
  Behavior is correct; the spec wording is stale. → reword to "effective-face 20 / overload".
- **F-03 — `phase2` audio orphan (RESOLVED this session).** The interaction audit flagged the `phase2`
  SFX key as registered with no emitter. Cut from `SFX_KEYS` in `6c987e6`. `phase2.wav` remains on disk
  (unwired) — image/audio-file deletion deferred to a later sweep. `ANIMATION.md:13` already notes the
  `phase2` *event* was deleted in pkg4 (accurate).

### Unimplemented spec — RESOLVED (basic-animation pass `feat/basic-animations`)
The former unimplemented list is now zero: four items built, three retired from the spec.
- **F-04 — Anticipation lean** — **RETIRED.** Removed from `ANIMATION.md`; the `_lunge` step-in is the
  whole Action tell by design. Was spec-only (zero code) — nothing to rip out.
- **F-05 — Travel tracer for melee** — **RETIRED.** Removed from `ANIMATION.md`; a melee hit IS the lunge,
  and Chain/Leech tracers stay as deliberate keyword accents. Was spec-only (zero code).
- **F-06 — Animated `drain_hp` + chip ghost bar** — **IMPLEMENTED** (in fact already present:
  `compact_unit_card._set_hp_display:512` tweens `_hp_fill.anchor_right` down over 0.30s while the red
  `_hp_chip` pins its left edge at the new HP and its right edge trails from the old value → the chip-ghost
  over the lost slice. The prior "bars snap" note was **stale** — `refresh_card_for_event` steps
  `hp_after` per hit and `_set_hp_display` animates each step. Verified this pass.)
- **F-07 — Idle bob / ambient life** — **RETIRED.** Removed from `ANIMATION.md`; the board is quiet between
  beats by design. Was spec-only (zero code).
- **F-08 — Death scatter / debris** — **IMPLEMENTED.** `battle_feedback._death_scatter:` team-tinted + ash
  debris arc-and-fall, fired at the fatal-hit event after the card grays out; multi-death micro-stagger
  (`death_ordinal * 0.05`). Fire-and-forget so it never stalls the turn.
- **F-09 — Slow-mo on the 20-celebration** — **IMPLEMENTED.** `battle_feedback._slow_mo` (brief wall-clock
  dilation) replaces the overload hit-pause, gated by the global-effect arbiter so it can't stack.
- **F-10 — Shield-break shatter** — **IMPLEMENTED.** `battle_feedback._shield_shatter` (expanding ring +
  angular glass slivers), wired to `breach` and `wipe_shields`; distinct from the square-confetti hit burst.

### Undocumented firing sites (in code, not in the ANIMATION table)
- **F-11 — Frame shake fires ONLY on `damage`** (`battle_feedback.gd:139`), not on burn, death, or a
  bare crit. The spec's event→primitive table implies shake on every hit; document the actual single caller.
- **F-12 — Summon feedback lives in `battle_scene.gd:2576`**, outside the `battle_feedback` event table,
  so it isn't sound-aware and isn't in the primitive library.
- **F-13 — `_hex_flash` Ward-consume** (`battle_feedback.gd:447`) fires on `block` events with
  `amount ≤ 0`; the amount-0 sentinel that means "firewall negate" is an undocumented convention.

### Wrong-condition / gap
- **F-14 — Boss standing-rule cue is absent** (spec §4 expects one, e.g. Matriarch's 3-round spawn).
  The rules only surface through their component events (rewrite / shield / summon) + the round log —
  no dedicated telegraph. Design gap, not a bug.

### Verified correct (no finding — called out because the prompt flagged them as risk areas)
- 20-triggered feedback (die gold face, gold wash, name slam, overload sfx, hit-pause) **all key on the
  effective face == 20**, zero raw/natural branches (`battle_feedback.gd:403`, `dice_tray_3d.gd:684`). ✓ NK-02
- TAUNT chip is **state-driven** and clears when `lured_by_id`/`taunting` clear at the round-end tick —
  no persistent marker. ✓ NK-08
- Freeze crust reads `freeze_flavor` live (ice vs petrify) and cannot conflict with jam/rewrite because
  frozen dice are alteration-immune upstream. ✓ NK-03
- Feedback labels carry no pre-NK-05 ability names (labels are the ability's live `name`/eff). ✓ NK-05
