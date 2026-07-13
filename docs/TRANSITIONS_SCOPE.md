# TRANSITIONS — DITHER DISSOLVE + POWER DOWN

**Status: RULED + BUILT (2026-07-12).** Scoped after verifying no `TransitionManager`
existed (spec-only; `SceneManager.go_to()` was a bare `change_scene_to_file` hard
cut). Kev ruled the four open questions the same day and the system was built —
this document is now the reference for how it works and why.

## Rulings (Kev, 2026-07-12 — closed, do not relitigate)

1. **Durations: DITHER 0.25s, POWER DOWN 0.8s.** The dissolve fires constantly —
   every 50ms is felt, so it runs fast. The power-down is the death screen and
   should linger.
2. **No battle-entry variant.** One transition. Ship it.
3. **Quit-to-menu is a DISSOLVE, never power-down. POWER DOWN exclusively means
   you died.** If quit used it, it would stop being a signal and become an
   animation.
4. **~~Dissolve-direct, not through-black.~~ SUPERSEDED 2026-07-13 — reversed to a
   COVER phase.** The original ruling ("dissolve the outgoing snapshot straight
   into the incoming scene, no through-black") was wrong in practice: because both
   frames are simultaneously visible during the dissolve, it read as a chaotic
   crossfade/flicker, not an authored transition. The dissolve now runs three
   beats — dissolve OUT to an opaque cover, HOLD fully covered (scene swap + load
   concealed here), dissolve IN from the cover — so the player perceives a genuine
   empty "in between", never two blended images. Timings ~0.10 out / 0.05 hold /
   0.12 in (total 0.27s). POWER DOWN keeps its collapse shape but its reveal now
   goes through the same dither-in from black, not an alpha crossfade.

## Why the architecture is cheap

Every scene change in the game funnels through **one choke point**:
`SceneManager.go_to(scene_path)` (8 routes: main menu, unit select, battle, reward,
run-end, evolution, route fork, intercept). One integration hook covers the whole
game. `PersistentHeader` (CanvasLayer, layer 8) survives transitions by design — the
transition layer simply sits above everything (proposed **layer 200**, above
HelpMenu 135) so the header is covered like the rest of the frame.

## The two effects

### DITHER DISSOLVE — the default, every scene change
The outgoing frame dissolves through an ordered-dither threshold ramp — the
Direction-05 "Dithered Terminal" signature (`assets/ui/dither_2x2.png`,
`PixelUI.make_dither_overlay`) applied as a transition. Mechanism:

1. Snapshot the outgoing viewport (`get_viewport().get_texture().get_image()` →
   `ImageTexture`) into a full-rect TextureRect on the transition CanvasLayer.
2. `change_scene_to_file` runs UNDER the snapshot at the very start; the opaque
   OUT+HOLD cover conceals the new scene's load entirely.
3. A shader runs the three-beat cover (ruling #4, revised): OUT dithers each
   Bayer cell snapshot→backdrop; HOLD is a fully opaque `DT_FIELD_BG` cover; IN
   dithers each cell backdrop→transparent (discard), revealing the new scene.
   Two frames are never simultaneously visible.
4. Duration **0.27s** — ~0.10 out / 0.05 hold / ~0.12 in (the `OUT_END`/`HOLD_END`
   ramp split lives in the shader); a single tween drives the `ramp` uniform 0→1.

Shader: `assets/shaders/dither_dissolve.gdshader` — 4×4 Bayer computed in-shader,
thresholded on **`FRAGCOORD` device pixels** (see pixel law below).

### POWER DOWN — defeat only (ruling #3: it exclusively means you died)
CRT power-off over **0.8s** (ruling #1 — the one moment that should linger): the
frame collapses vertically to a bright horizontal line, the line collapses
horizontally to a dot, dot afterglow fades over `DT_FIELD_BG`. Same snapshot
mechanism, different shader (`power_down.gdshader` — vertical/horizontal scale on
UV with brightness flare). Placement: **defeat → run-end. Nothing else.**
Quit-to-menu and victory → run-end use the standard dissolve. Audio hook: one
`AudioManager` power-down cue at collapse start — authored later, seam only.

## TransitionManager (new autoload)

`scripts/autoloads/TransitionManager.gd` + entry in `project.godot` (~120 lines):

- CanvasLayer, layer 200, always alive; owns the snapshot TextureRect and a
  full-rect input-blocking Control (`MOUSE_FILTER_STOP`) that exists ONLY during a
  transition — no input can leak into either scene mid-transition.
- API: `await TransitionManager.transition(kind, do_change: Callable)` — snapshot,
  call `do_change` (the actual `change_scene_to_file`), play the shader ramp,
  clean up. `kind` ∈ {`dither_dissolve`, `power_down`, `none`}.
- `SceneManager.go_to()` gains an optional `kind` param (default `dither_dissolve`)
  and delegates; `go_to_run_end()` picks `power_down` on defeat. ~10 lines total.

## Hard constraints (the ones that bite)

1. **Headless / auto-battle / tests skip instantly.** Same suppression shape as
   KeywordPrimer: headless display server or auto-battle running → `transition()`
   degrades to a plain `do_change` call, zero awaits. Otherwise every smoke test
   that changes scenes (flow, tutorial, the Batch-4 quartet) hangs or slows.
2. **Pixel snap law (INVARIANTS #14).** The dither threshold must be computed in
   **device pixels (`FRAGCOORD`)**, not UV/design pixels — at the exact-half
   540×1200 preview a design-space 1-px checker renders 2×2 blocks (fine) but any
   fractional scaling shimmers. Bayer cell size stays a whole device-pixel count.
3. **Determinism fence (INVARIANTS #1).** Presentation only — the manager never
   touches GameState/combat; `do_change` is the same call SceneManager makes today.
4. **Snapshot cost.** `get_image()` on a 1080×2400 viewport is a sync GPU readback
   (~ms, once per transition) — acceptable at scene-change frequency; never do it
   per-frame.
5. **Failure safety.** Snapshot fails / shader missing → fall through to the hard
   cut. A transition must never be able to strand the game between scenes.

## Deliverables + effort

| Piece | Size |
|---|---|
| `TransitionManager.gd` autoload + project.godot entry | ~120 lines |
| `dither_dissolve.gdshader` | ~30 lines |
| `power_down.gdshader` | ~45 lines |
| `SceneManager.go_to` hook + defeat routing | ~10 lines |
| `transition_smoke_test.gd` (headless skip path + non-headless ramp completes + input block released) | ~80 lines |
| verify_gate registration | 1 line |

Roughly one sitting. No data changes, no combat surface, no sim impact.

## Open design questions

None — all four ruled 2026-07-12 (see Rulings at the top).
