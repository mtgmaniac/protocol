# INVARIANTS — the WHY rules (read right after TRUTH.md, before any edit)

TRUTH.md says what the game IS. This file says why it must stay that way. Each rule
carries its rationale and what a violation looks like, so a session that never saw the
original argument doesn't relitigate it. Changing an invariant requires an explicit
ruling from Kev recorded in `docs/DECISIONS_RESOLVED.md` — not a clever argument in chat.

## 1. Determinism fence
All combat outcomes flow through the seeded roll provider (`scripts/sim/roll_provider.gd`
seam); the 3D tray physics is presentation only. The headless sim must reproduce any
battle byte-identically from a seed — that is what makes `baseline.json`, ci_smoke, and
every balance conclusion trustworthy. A mechanic whose outcome depends on physical dice
positions cannot be simmed and is therefore forbidden, no matter how good it feels.
**Violation looks like:** "the die that lands nearest the wall gets +1", damage read from
tray collision events, `randi()` anywhere in combat/targeting code (SeededRollProvider or
nothing). Freeze=repeat passes the fence: the crust is physics *presentation*; the locked
face is engine state.

## 2. ai_type is load-bearing; targeting is a separate field
`ai_type` gates 20-face elite summons (`ai_type=="smart"`) and the summon-injection guard
(rejects non-"dumb"). Targeting personalities live in the independent `targeting` field.
They were split deliberately (keyword batch Tasks 4+9); merging them breaks summons
silently because the audit can't see intent. **Violation looks like:** renaming/reusing
`ai_type` to pick targets, or deriving a personality from `ai_type`.

## 3. One keyword per ability, two in overload — audit-enforced; pierce counts
Ability legibility is a hard budget: a player must parse a band at a glance on a phone.
The audit enforces it; data that sneaks a third effect through a rider is still a
violation even if the audit misses it. **Violation looks like:** "12 dmg + burn + mark"
on a surge band, or treating pierce (`ignSh`) as "free" because it's just a flag.

## 4. The complexity budget is SPENT
Default-REJECT new keywords in the dice-suppression space: jam / rewrite / hijack /
freeze fills it. Four ways to mess with a die is the ceiling a player can track; a fifth
makes all five illegible. The open design spaces are hero-side RISK and MOMENTUM
mechanics — spend there. **Violation looks like:** a new enemy that "locks", "corrupts",
"glitches", or "delays" a die; a proposal that starts "it's like jam but…".

## 5. Legibility beats cleverness
If a rule can't be one sentence in an inspect popup, it's wrong. Precedent: the fix-1.4
banked-face freeze model was killed twice — first for the lockout, then for freeze=repeat
(2026-07-06, final) — both times because "keeps its face; the unit acts again on it" fits
in one sentence and bank/thaw never did. Same reason the "pure debuff targets highest HP"
targeting special case was removed. **Violation looks like:** any mechanic whose tooltip
needs the word "unless", twice.

## 6. Enemy AI is a legible rule, not a mind
Max 4 targeting personalities (SYSTEMATIC / WOUNDED / PACK / SPITEFUL), deterministic,
one choke-point (`personality_pick_target`), surfaced verbatim in the inspect popup.
Difficulty comes from composition and boss standing rules, never smarter heuristics — a
player must be able to predict and play around every enemy decision. **Violation looks
like:** a fifth personality, HP-threshold behavior switches, lookahead, or any enemy pick
the inspect text can't explain. (Enemy freeze targeting the hero's lowest revealed die is
the pattern: one deterministic sentence.)

## 7. UI doctrine
Green is reserved for HP bars and heals — nothing else is ever green. Grouping uses
filled plates, never stroked outlines. Primer/keyword text is one sentence, ~12 words
max, stating the RULE not flavor. `PixelUI` is the single source of visual constants;
`theme_overload.tres` only mirrors it. **Violation looks like:** a green buff chip, an
outlined selection rectangle, a two-sentence tooltip, a hex literal in a scene script.

**Six components (Polish Build A, Kev 2026-07-14):** every panel frame is one of six
`PixelUI.component_style` kinds; strong cyan borders belong to `selected_card` only,
strong gold to `major_event` only; one 4px frame width — rank is color, never width.
Frame strength is a RANK: when everything shouts, nothing does — that was the
border-noise defect this exists to prevent. Enforced by
`scripts/checks/component_contract.py`. **Violation looks like:** a `StyleBoxFlat.new()`
in a screen script, a DT_CYAN border on something that isn't selected, a gold frame on
a routine popup, a seventh frame style invented instead of reported.

**Capitalization law (Polish Build A, Kev 2026-07-14):** ALL CAPS for
alerts/headings/buttons/metadata/callsigns/keyword-headers; Title Case for ability
names and proper nouns; sentence case for body/lore/help — keyword mentions inline
are lowercase. Enforced (mechanical subset) by `scripts/checks/caps_law.py`.
**Violation looks like:** "applies BURN" in a desc, a Title-Case button label, a new
`"literal".to_upper()`, a shouting body paragraph.

**Band vocabulary (Batch 2):** the words `recharge` / `strike` / `surge` / `crit` /
`overload` are internal zone keys ONLY. Never surface them in player-facing copy,
docs, or design discussion to name/describe dice bands — refer to a band by its
numeric range ("1–4", "20") or not at all, and never claim higher bands are strictly
stronger (they are not). Proper nouns are exempt (Strike Unit, Overload Protocol,
ability/gear/relic/enemy names). **Violation looks like:** a help line reading "the
Crit band" or "bands run Recharge > Strike > …", an inspect tooltip naming a band.

## 8. Balance numbers move together, against the pinned target
The target is 25–40% skilled full-clear of facility in real play; the sim metric is
per-op AND per-hero clear-rate variance (l1 policy, `baseline.json`). Numbers interlock —
tuning one in isolation is how voidCirclet silently jumped +26 pts (keyword batch) and
how freeze=repeat cratered Avalanche −67 pts. Tune in passes, measure the whole table.
**Violation looks like:** "just bump execute to +10" without a batch run and the per-op
delta table in the commit.

## 9. Baseline ceremony (±10)
`scripts/sim/baseline.json` is only updated after reviewing per-op deltas against the
pre-change snapshot; any per-op move beyond ±10 points requires Kev's explicit sign-off —
commit must contain `BASELINE-APPROVED-BY-KEV` (enforced by the commit-msg hook).
Precedents: voidCirclet +26 (flagged, pass still owed) and freeze=repeat −27.7 overall
(reported, baseline left stale on purpose). **Violation looks like:** running
`ci_smoke.py --update-baseline` to "make CI green" after a mechanics change.

## 10. Doc supremacy
TRUTH.md wins every doc conflict; when TRUTH disagrees with code, code wins and TRUTH is
fixed with the correction recorded. Any task that changes behavior updates TRUTH.md in
the SAME commit or the task is incomplete. Closed decisions live in
`docs/DECISIONS_RESOLVED.md` — check it before proposing; do not relitigate a ruling.
**Violation looks like:** a merged behavior change with a "will update docs later" note,
or re-arguing bank/thaw freeze because an old doc paragraph still describes it.

## 11. Legacy IDs and layout quirks are frozen
Internal ids `combat` (Strike Unit), `shield` (Spike Guard), `medic` (Splice Medic) are
legacy and permanent — saves, gear tables, and sim telemetry key on them. Portrait
1080×2400 with the five-band battle layout is the contract; `legacy-angular/` is an
asset warehouse only (never revive app code there). **Violation looks like:** an id
"cleanup" migration, a landscape "option", a TypeScript fix under legacy-angular.

## 12. Max ONE manually-picked component per hero ability — audit-enforced
Touch flow: one die tap → at most one target tap. Components sharing a pick (dmg+burn on
one enemy) count once; `freezeAnyDice` counts as the pick. **Violation looks like:** an
ability needing two different targets ("heal an ally AND jam an enemy").

## 13. Enforcement thresholds only ratchet DOWN for free
Raising the battle_scene.gd line watermark — or ANY enforcement threshold (ceremony ±10,
ci_smoke tolerances) — requires `BASELINE-APPROVED-BY-KEV` in the commit message; lowering
a threshold is always free. Enforcement that the enforced party can loosen isn't
enforcement — precedent: the 3378→3416 watermark self-raise for primer wiring, reasonable
in the moment but decided by the same agent it constrained. For FLOOR-type thresholds
(minimums, e.g. the required audit pass count `AUDIT_MIN_PASSED`) the polarity inverts:
LOWERING loosens and needs the token, raising is free — the principle is always "you
can't loosen enforcement on yourself." Second precedent: the Job-2a extraction silently
lost 6 audit recordings because the gate only checked "0 failed", not the count. The
commit-msg threshold guard (`scripts/hooks/threshold_guard.py`) enforces both polarities.
**Violation looks like:** bumping `HIGH_WATER_LINES` in the same commit as the growth it
excuses, or dropping the audit floor to make a green run, without the token.

## 14. Pixel snap law (UI)
Every UI position or size computed from a RATIO (protocol-pip spacing, chip offsets) must
round to whole PHYSICAL pixels before drawing, and 1px elements must land
on the physical pixel grid. Local-space rounding is NOT enough: the game renders
1080×2400 scaled into the window (540×1200 preview = 0.5×), so a whole local pixel is a
fraction of a screen pixel — and the scale lives in the viewport's FINAL transform
(stretch mode canvas_items), which `get_global_transform_with_canvas()` does NOT
include. Use `PixelUI.snap_to_physical_px` / `physical_px_width` (they compose it)
like `ProtocolPips` does. This also governs 1px strokes/outlines authored in DESIGN px:
at the 0.5× preview an ODD design width is a half physical pixel and smears, so use EVEN
design px (the HP-number outline is 2 design px = 1 whole physical px — Batch 6). Precedent:
the HP-bar notches were computed by accumulated float ratios and drawn 3 local px wide —
at preview scale they rendered as alternating 1px/2px ticks, some faint, some dropped
(the 2026-07-07 notch defect; the notches themselves were later REMOVED as redundant with
the HP number they overlaid — Batch 6 — but the law they exposed stands). Same failure
class: protocol pips laid out by an
`HBoxContainer` distributing fractional widths. **Violation looks like:** `frac * width`
drawn without physical rounding, a container distributing ratio widths across pip rows,
or a "1px" line whose measured width varies along the bar in a screenshot zoom.

**Integer icon corollary (Polish Build B, 2026-07-14):** pixel-art item icons render
ONLY at whole-integer multiples of their native size (`PixelUI.make_integer_icon`);
low-res legacy art (≤48 native) renders at exactly 4x on a Reward-chrome emblem
plate. **Violation looks like:** a TextureRect stretching 128 art to 180, or a new
icon surface bypassing the helper (`reward_model_test.gd` walks the tagged rects).

Two corollaries (2026-07-07, after the route-fork border round):
- **Godot-drawn strokes can't be per-instance snapped** (StyleBoxFlat borders), so the
  stroke width itself must survive every window scale: a border of design width N
  spans N×scale window px, and any span under 1 window px can fall entirely between
  pixel centers and rasterize to ZERO rows — which edge vanished depended only on
  where the control's rect landed (the Batch-3 game-wide "clipped border" defect: 2px
  = 0.83 window px at a ~450×1000 window; the exact-half 540×1200 preview masked it
  until the window was resized/clamped). Spans ≥ 1 always cover a pixel center, and
  odd widths are fractional window px at half scale and shimmer, so **strokes must be
  EVEN design pixels AND ≥ 4** — enforced at the source since Batch 3 (2026-07-11):
  `PixelUI.min_stroke` clamps every border built by `make_panel_style` /
  `make_hard_style` (and the per-screen stylebox factories route through it); the
  theme `.tres` mirrors 4px. A 1080-native device renders at scale 1.0 and is always
  exact. Measured precedent: at the old 450×1000 (5/12) preview, ONE panel's 2px
  border rendered 2px left, 1px right, 0px along parts of the top.
- **Window resizes change the final transform without resizing controls** — every
  snapped draw layer must `queue_redraw` on `viewport.size_changed` or it keeps the
  stale scale (HPTickLayer / ProtocolPips / CornerBracketLayer do).

## 15. No reward silently evaporates (Polish Build D, Kev 2026-07-15)
Consumables cap at **`GameState.MAX_CONSUMABLES` = 4** — the SINGLE source; `LoadoutMenu`
derives its slot count from it (no twin constant). A pickup at cap runs the **discard
picker** (`LoadoutMenu.open_discard`): the incoming item's stats are shown, any held item
can be inspected, and **ABANDON** (or tap-outside) keeps all four and drops the incoming —
nothing is ever destroyed by a dismissal. `claim_reward` requires a `swap_consumable_id` at
cap; the reward UI must run the picker before firing such a claim (debug-`assert` in
`reward_screen._claim_reward` catches a bypass). Non-interactive event grants at cap
**forfeit explicitly** ("LOADOUT FULL - ... FORFEITED"), never silently. **Violation looks
like:** a consumable claim at cap returning false into a swallowed UI path, a second
hardcoded slot constant, or a full-bag grant that vanishes with no message.

## 16. Relics are TWO, by design — one choke, display-only in the loadout (Polish Build D)
`GameState.MAX_RELICS` = 2 and every acquisition routes through `GameState._grant_relic`,
which refuses beyond the cap — so no claim / intercept / Starting-Directive path can seat a
third (a run opened on a boss-relic directive plus the battle-5 draft is the intended two).
Relics render **only** in the `LoadoutMenu` RELIC section — one row per held relic, up to
two, section hidden at zero, **never a placeholder slot** — and **never on battle chrome**
(the old `_relic_slot` was dead and is removed). **Violation looks like:** a relic count > 2
from any path, a relic pip/slot on the battle screen, or an empty relic placeholder row.

## 17. Ability effect text carries its coded target suffix (NK-17, Polish Build D)
Authored `eff` text (data/raw/{enemies,heroes}.data.json) must carry the parenthetical
target suffix its COMPUTED scope requires — `(self)` for self-buffs, `(all)` for AoE,
`(lowest)` for lowest-target — and none for single-target, matching how `effect_pip.gd`
derives scope from the structured fields. Keyword-only clauses (`cloak`, `firewall`, `jam`,
`spike`, `rampage +1 (all)`, `summon`) keep their own convention. Enforced by
`scripts/checks/effect_text_target.py` (count-based, so a double suffix fails like a missing
one — the historical double-stamp). **Violation looks like:** a self-shield authored "8
shield" with no "(self)", an AoE heal missing "(all)", or a doubled "(self) (self)".
