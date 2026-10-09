# INVARIANTS — the WHY rules (read right after TRUTH.md, before any edit)

TRUTH.md says what the game IS. This file says why it must stay that way. Each rule
carries its rationale and what a violation looks like, so a session that never saw the
original argument doesn't relitigate it. Changing an invariant requires an explicit
ruling from Kev recorded in `docs/DECISIONS_RESOLVED.md` — not a clever argument in chat.

## 1. Determinism fence
Every d20 value enters combat through the roll provider seam (`scripts/sim/roll_provider.gd`)
as a uniform d20 draw: in live play it is the face the physics die lands on (G-24,
Kev 2026-09-26); in the headless sim and the skip-visuals path it is the seeded stream.
Everything after the draw is engine state. The headless sim must reproduce any battle
byte-identically from a seed — that is what makes `baseline.json`, ci_smoke, and every
balance conclusion trustworthy. A mechanic whose outcome depends on physical dice
POSITIONS (anything but the landed face as a d20 value) cannot be simmed and is therefore
forbidden, no matter how good it feels.
**Violation looks like:** "the die that lands nearest the wall gets +1", damage read from
tray collision events, `randi()` anywhere in combat/targeting code (SeededRollProvider or
nothing). Freeze=repeat passes the fence: the crust is a visual; the locked value is
engine state.

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
**Tuned to a target? Report a second seed base (G-58, Kev 2026-10-09).** Whenever
numbers are tuned until a batch hits a target, run the before and the after on a second
seed base the tuning never saw, and report both with the pooled difference. Tuning to one
set of seeds fits that set: on 2026-10-09 numbers within 1 point of target on the tuned
set were 3 to 6 points off on a new one. **Violation looks like:** reporting only the
batch the numbers were tuned on.

## 9. Baseline ceremony (two tiers: a tripwire, then a size check)
The sim gate has two tiers (G-58, Kev 2026-10-09; `scripts/sim/ci_smoke.py`).
**The tripwire:** 300 pinned runs per policy (`l1`, and `l1_evo2` for the second
evolutions) on every full gate. An unchanged tree reproduces them exactly, so ANY move
means combat changed. Its size is noise at 300 runs (the same change reads −15 to +19
points from one block to the next, G-57) and is never judged.
**The size check:** 1,500 pinned runs, only for a policy whose tripwire moved. A move
beyond **8 points on an operation or 4 overall** requires Kev's explicit sign-off — the
commit that re-pins must contain `BASELINE-APPROVED-BY-KEV` (enforced by the commit-msg
hook, which judges the size pins and refuses pins that were not written together).
The pins (`baseline.json`, `baseline_pins.json`) are only written by
`ci_smoke.py --update-baseline`, after reviewing the size table against the pre-change
pins. Precedents: voidCirclet +26 (flagged, pass still owed) and freeze=repeat −27.7
overall (reported, baseline left stale on purpose). **Violation looks like:** running
`ci_smoke.py --update-baseline` to "make CI green" after a mechanics change; reading the
size of a change off the 300-run tripwire; re-pinning one pin file without the other.

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
Raising the battle_scene.gd line watermark — or ANY enforcement threshold (the sim size line,
the pinned sim run counts) — requires `BASELINE-APPROVED-BY-KEV` in the commit message; lowering
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

**Text corollary (text legibility Step 1, 2026-09-26):** below scale 1.0 Godot rounds
glyph positions in DESIGN px, so almost every label lands off the physical grid; under
the LINEAR default that smeared 27–98 % of glyph pixels into half-tones (audit F2).
Pixel-font text therefore samples NEAREST (`PixelUI.install_text_filter` — never
per-node), renders at ≥ `PixelUI.TEXT_MIN_PX` (48; below it one m5x7 pixel falls
under one screen pixel on desktop web), and text containers derived from screen
fractions or centering snap to even design px (`PixelUI.even_px`). **Violation
looks like:** a text node with an explicit LINEAR filter, a raw
`add_theme_font_size_override` below 48 that bypasses `text_px`, or a popup width
like `viewport × 0.92` = 993.6.

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

## 17. Ability effect text matches its coded targets (G-9, 2026-09-06)
Approved concise text names group targets as `(all heroes)` / `(all enemies)`,
lowest-HP support as `(lowest HP)`, and chosen friendly targets as `(hero)`.
Hero self effects are implicit; enemy self effects retain `(self)`. Enemy ally
shields say `(ally)`. Single hostile targets remain implicit. Use `damage` and
explicit `turns`. This supersedes NK-17's abbreviated text markers while keeping
its reason: text must match computed target scope. The gate compares effect/target
counts, so wrong-side markers, missing targets and duplicates fail. Equipment
continues to omit `(self)` and pips keep their existing G-7 conventions.

## 18. Unlock progression: one choke point, gates at run end only (Build F)
Unlock progression is ordered buckets + battle-count gates and NOTHING else — no
trees, no currency, no collection screen, no per-item ceremonies, no mid-run pool
changes (THE FENCE, ruled by Kev 2026-07-15; a future change wanting any of those
has left the sanctioned design). The metric is `battles_fought` — encounters
ENTERED, never rounds (rounds are farmable); losing runs progress. Earning accrues
during play but gates are AWARDED at run end only (`_evaluate_item_gates`), so pool
composition is frozen for a whole run. Every pool draw routes through
`DataManager.pool_ids` — the same one-owner rule as `make_integer_icon` and the
font loader, because the next grant path added beside the choke silently bypasses
the gate. Harness pools are fully unlocked structurally (isolation) plus the
explicit sim/audit pin — a balance number must never depend on a profile's unlock
state. **Violation looks like:** a `DataManager.items` iteration in a screen
script, a pool query that consults `battles_fought` instead of
`item_gates_awarded`, an award written anywhere but run end, an unlock currency
proposal, or a sim run whose draft pool shrank because a fresh dev profile
happened to be loaded.
