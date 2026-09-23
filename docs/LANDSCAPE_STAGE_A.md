# Experimental battle landscape — Checkpoint 2

Stage A only, 2026-09-23. Stop for Kev's review before Stage B typography and
polish. Keep the feature disabled for players. This implements the scoped ruling
in DECISIONS_RESOLVED; it does not change the portrait contract.

## Architecture and activation

One `BattleScene.tscn`, one set of component instances, bindings, signals and
controllers. `BattleLayout` chooses its placement strategy before cards are
created. The existing portrait path remains; `landscape_battle_layout.gd` changes
container directions, dimensions and anchors. No live orientation switching or
reparenting of populated card trees is added. Resize adapts the chosen layout.

Shared owners remain `CompactUnitCard`, `BattleCardView`, `DiceTray3D`,
`AbilityReadout`, visible die tags, `BattleFeedback`, `ProtocolActions`,
`LongPressInput`, `InspectPopup`, and `PersistentHeader`. No component behavior
was copied into a second battle implementation. The alpha-zero ability readouts
remain data holders; their old horizontal rows are hidden in landscape.

`scripts/battle/battle_layout_policy.gd` contains the single player flag:
`LANDSCAPE_BATTLE_ENABLED := false`. A future approved one-line change to `true`
enables AUTO selection. While false, AUTO is portrait on every platform.

Selection at battle initialization:

1. Only a debug build honors the session override. FORCE LANDSCAPE explicitly
   permits tutorial testing; FORCE PORTRAIT uses the original layout.
2. Otherwise tutorials stay portrait.
3. AUTO landscape requires the flag, a desktop device, width at least 960 logical
   window/CSS pixels and width/height at least 1.3. All other cases use portrait.

Device checks reject `mobile`, `web_android`, and `web_ios`. Web also uses the
existing `PixelUI.is_mobile_web()` helper (including iPad desktop UA detection)
and rejects coarse-pointer/no-hover devices. Web desktop must positively identify
`web_windows`, `web_macos`, or `web_linuxbsd`; native uses `pc`. Native size is
window size divided by screen scale; web uses the iframe/window inner size.
Desktop OS tablets cannot be perfectly distinguished from PCs by native feature
tags alone. Physical phone/tablet validation remains outstanding.

In a debug build, tap the operation title seven times rapidly to unlock the
existing developer controls. Open Help → Settings → DEBUG → BATTLE LAYOUT
(NEXT BATTLE), then choose AUTO, FORCE PORTRAIT or FORCE LANDSCAPE. The choice is
session-only, does not write a save, and takes effect on the next battle. Release
builds omit these buttons and ignore the override.

## Layout and coordinate changes

Heroes form the left column, enemies the right, and the existing dice tray fills
the middle. Existing HUD and Protocol occupy their original top/bottom bands.
Cards use their existing per-instance `apply_battle_layout` API with larger
dimensions. Ratio-derived dimensions and dice anchors use physical pixel scale.
Shared portrait cover-fit, art, filtering, fonts, statuses and badges are reused.
No global theme or font changes were made. Stage B will address text and badge
readability, HUD/footer sizing and visual balance after approval.

The three generic BoxContainers preserve the portrait directions by default.
Landscape changes directions before population. The existing card creation and
summon rebuild paths place the same controls into those containers.

Coordinate adaptations are limited to landscape:

- Dice result anchors track each owning card's vertical center and the middle
  tray's left/right lanes, replacing horizontal portrait-lane coordinates.
- The shared tray camera uses a landscape projection size of 12.5. Physical die
  radius, seeded results, materials, toss behavior and settle animations remain
  shared. Result clamping uses the actual tray bounds; settled positions refresh
  on resize and after a roll, without switching layouts.
- Existing die hit overlays follow the projected die bounds plus the visible
  ability tag. Existing click/long-press callbacks are retained.
- Readout lookups used for effects use the visible tag's current rectangle.
- Attack lunges point toward the opponent horizontally, with unchanged distance,
  easing and timing. Hijack uses the actual die position, falling back to the
  current tray center. Other card-relative effects remain shared; Siphon already
  prefers the real Protocol control, so no change was necessary.

Actual gameplay caps are three heroes and three enemies. Summons fill an open
slot or replace a dead slot. Matriarch starts with an escort, then its real Brood
standing rule adds a third unit. A fourth is blocked by existing combat rules.
The layout sizes by actual view count, reserving three rows; no scrolling or
new gameplay cap was introduced.

## Viewport and scope

Before and after: base 1080×2400, native preview 540×1200, non-resizable native
window, `canvas_items` / `expand`, handheld orientation 1. `project.godot`, web
shell and export presets are unchanged. Native widescreen captures use a test
harness window size; normal native launch retains its current portrait window.
The web shell already fills the viewport. No non-battle screen was redesigned
or newly constrained; its current wide presentation remains.

The unrelated 640×960 edit in Kev's original checkout was never included or
changed. Implementation is isolated on `codex/landscape-battle-layout` from
`9315334b8372a29b9aa90a5f7167294bf1a610aa`.

When enabled later, 960×600 is a proposed itch embed size, with a fullscreen
button and checks at 1280×720 and 1920×1080. The existing 640×960 embed remains
portrait under AUTO. Keep mobile portrait. No itch settings or deployment changed.
An actual proposed-size iframe validation is still outstanding.

## Verification and limits

Accepted original gate baseline: 47 passes / 6 failures. In the writable isolated
clone with the committed viewport and installed dependencies, the existing gate
(`python scripts/verify_gate.py --skip-sim`) reports **52 passes / 1 failure**:
the tutorial reachability gate. A full-output rerun of that test exits 0 and
prints PASS for real-input reachability, assist and beat counts, but also emits
Godot's Windows `Failed to read the root certificate store` error. This gate
rejects any `ERROR:` output. Do not describe the remaining gate failure as a new
tutorial assertion failure. No new gate failures were observed.
No unrelated failures were repaired; the environment, viewport baseline and
timing differ from the original dirty-checkout run. No balance simulation was
rerun because no balance surface changed; no sim baseline was updated.

The dedicated `scripts/debug/battle_layout_test.gd` passes **266 checks** covering
policy guards, both scene layouts, card bounds, six seeded results, frozen layout
selection through resize, die/tag hit bounds, real pointer long press and popup
placement, shared card Nudge handling, horizontal lunge and return, dead-slot
replacement, real Brood spawn and cap, and AUTO/forced tutorial initialization.
Run it with Godot `--headless --path . -s scripts/debug/battle_layout_test.gd`.

The existing flow smoke also passes with landscape forced, including reward,
next battle and both run-end routes. The dice physics probe completes eight rolls
with zero penetrations, flyovers, tilted rests and frozen drift. Existing missing
audio and shutdown resource warnings remain visible in logs; no assets changed.
Debug and release Web exports succeed. Real debug-browser testing at 1280×720
verified flag-off portrait, the dev selection menu, next-battle landscape, dice,
targets and Protocol display, before the final physical-pixel sizing adjustment.
Browser automation then disconnected. Full web
1920×1080, current/proposed iframe sizes, narrow-window and release visual checks
remain incomplete; native captures and policy tests do not replace those checks.

Clean committed-source screenshots were captured before edits with seed
20260921, Facility battle 6, combat/engineer/medic, three enemies and rolled dice.
The post-change portrait comparison shows pixel-identical HUD, hero/enemy cards
and Protocol regions at 540×1200, 432×960, 390×844 and desktop 1920×1080. The entire
432×960 image is identical. Two phone images differ by one dice pixel each; the
desktop difference is confined to one cosmetic 3D die region. Dice outcomes and
card rectangles match. No measured portrait layout regression was found.

There is a **pre-existing pointer issue**: pressing a die while Nudge is armed
cancels that mode before release; Protocol is not spent and targeting starts.
It was independently reproduced in the untouched original portrait source and
in landscape, including the browser. The shared card Nudge callback works. This
task preserves that behavior; do not count it as a successful die Nudge interaction.

Tutorial AUTO stays portrait. Forced-landscape initialization and a welcome-step
capture work; target highlights mostly follow live control rectangles, but coach
placement and some fallbacks retain portrait ratios. This is not full tutorial
landscape support. A later task must validate all 21 beats, coach fit, target
reachability and fallback anchors without altering tutorial content here.

Keep this as an experiment pending Checkpoint 2 review, Stage B approval and the
remaining browser/device validation. Shared feature changes should still be made
once; placement, projection, hit geometry and typography may need mode-specific
checks. The flag must remain false until separately approved for release.
