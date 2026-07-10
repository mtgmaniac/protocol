# UI Readability & Usability Review — Prompt 7

**Date:** 2026-07-10 · **Build:** `feat/event-sprites` (b0a07b5) · **Captures:** 24 window screenshots
(540×1200 debug window = exactly 0.5× the 1080×2400 design space, per INVARIANTS #14 corollary) +
2 engine captures (victory / defeat).

**Severity bar** (per Kev): "hand the phone to a friend."
- **blocks-demo** — the friend will be confused, lose information, or think the game is broken.
- **should-fix** — hurts comprehension or looks unpolished; fix before wider sharing.
- **polish** — cosmetic.

**Px convention:** all sizes below are DESIGN px (1080-wide space) = 2× the measured window px.
On a ~6.5" 1080×2400 phone (~16 px/mm): 20 design px ≈ 1.3 mm cap height — functional floor for
*information-carrying* text is ~24; comfortable body is ~28+. Pure accents may go smaller.

**Scope note:** animation timing excluded this pass (Kev: unfinished, reviewed separately later).

---

## DEMO-BLOCKERS (fix these five before the phone leaves your hand)

| # | Screen | Issue | Fix |
|---|--------|-------|-----|
| DB-1 | ALL (PersistentHeader) | Debug chevrons `^` `^^` visible + tappable on every screen, including title | Hide unless a debug flag is on |
| DB-2 | Battle | Rightmost hero's readout icons clip off-screen | Clamp readout row to combat-zone bounds |
| DB-3 | Battle | Floating combat words ("BLOCK 7", "SH +8") illegible: ~18px, low contrast, overlap the name row | ≥30px + outline + spawn above card |
| DB-4 | Unit select | Encounter blurb truncated mid-sentence ("…Bank Protocol") | Autowrap/height fix; it's a 2-line string |
| DB-5 | Unit select | Role legend (OFFENSIVE/DEFENSIVE/SUPPORT/CONTROL) ~14–16px — the only place roles are taught, and it's illegible | ≥24px, or teach roles in the unit info panel instead |

Details per screen below.

---

## Per-screen findings

### 1. Title screen
| Issue | Why it hurts | Fix | Severity |
|---|---|---|---|
| Debug chevrons in header (DB-1) | A friend WILL tap them; unknown/undocumented effects on a fresh run | `PersistentHeader.set_debug_enabled(false)` by default; gate behind a build flag or long-press unlock | **blocks-demo** |
| TUTORIAL button is dim/muted (~26px, LINE_DIM border) | It's the primary onboarding path for a first-time player — visually reads as disabled | Style as secondary-but-live: brighter border (DT_CYAN at lower alpha), same font as BEGIN | should-fix |
| Header `?` on title — does help bind here? | If inert (unbound per PersistentHeader contract), a dead help button on the FIRST screen teaches "buttons don't work" | Bind help on title, or hide the button when unbound | should-fix (verify binding) |
| Large dead zone below buttons | — | acceptable for a title screen | polish |

### 2. Unit select
| Issue | Why it hurts | Fix | Severity |
|---|---|---|---|
| Encounter blurb clipped (DB-4): renders "…Bank Protocol", data says "…Bank Protocol **and breach through.**" (`battle-modes.json:15`) | Loses the instruction half of the sentence and looks broken | The blurb label needs `autowrap` + enough rows for ~3 lines at its font size, or a smaller font (it competes with the boss thumbnail for width) | **blocks-demo** |
| Role legend ~14–16px (DB-5) | The colored corner chips on portraits are meaningless without it | Bump to ≥24px; alternatively drop the legend and put "OFFENSIVE" as a colored tag in the unit info panel (it already shows SUPPORT there — the legend is arguably redundant) | **blocks-demo** |
| Page dots under encounter card ~8px wide | Carousel position hard to see; also a 1px-class element → pixel-snap risk (INVARIANTS #14) | 12–14px dots via snapped draw, or "2 / 5" text | polish |
| "LV 1" + threat pips small (~18px) | Threat is a pick-relevant signal | Bump LV text to 24px; pips are fine | polish |
| Duplicate counters: "SELECT SQUAD 0/3" (top) and "0/3 SELECTED" (bottom bar) | Mild redundancy; bottom bar earns its place once it becomes DEPLOY | Leave, or make the top counter pips | polish |

### 3. Battle — pre-roll
| Issue | Why it hurts | Fix | Severity |
|---|---|---|---|
| Hidden enemy dice barely visible (dim purple on near-black) | The "enemies have pending rolls too" telegraph — a first-timer may never notice them | Raise the face-down material's value/emission ~2×; still clearly "unrevealed" | should-fix |
| Footer action buttons show no PP cost (Nudge 1 / Reroll 2 / Set 3) | Costs exist only in the help screen; a friend will tap-and-fail or hoard | Small amber cost numeral badged on each button corner (same treatment as chip values) | should-fix |
| Affordability state unclear (protocol 0–1 but all 4 buttons render identically lit) | Player can't tell what's spendable at a glance | Dim icon + border below cost threshold (`protocol_actions` already computes affordability at :230/:244/:358) | should-fix |
| PROTOCOL 0/10 label ~16px | Redundant with the pips, but it's the only numeric readout of the cap | 20–22px is enough; keep muted | polish |
| Center zone is a large void with a floating ROLL | First impression is "empty screen" | Acceptable; if touched, drop ROLL ~15% lower toward the hero rail (thumb reach) — do NOT add decoration (BATTLE_UI_V2 §5) | polish |

### 4. Battle — resolved / targeting
| Issue | Why it hurts | Fix | Severity |
|---|---|---|---|
| Rightmost readout clips off-screen (DB-2): PHANTOM's `⚡14 [aoe][shield…]` loses icons past the screen edge (093326, 093520) | Mid-combat information loss — the pierce/shield rider is simply invisible | Readout rows must clamp inside the combat zone: `position.x = clamp(x, margin, zone_w - row_w - margin)`; BATTLE_UI_V2 §13 already warns two-row cases must be screenshot-judged | **blocks-demo** |
| Floating words illegible (DB-3): "BLOCK 7" ~18px dark-cyan-on-dark above the name row; "SH +8" gray, mid-fade | This is the ONLY narration of what just happened; a friend sees HP move with no story. Damage `-N` floats scale 0.95–1.55 but base is too small | In `battle_feedback._spawn_floating_text` (:268): base font ≥30px, 2px outline (`DT_FIELD_BG`), spawn origin above the name row instead of over it. Keep 0.9s fade | **blocks-demo** |
| Enemy intent not surfaced anywhere | Intents ARE computed at reveal (`battle_scene.gd:2003` → `assign_enemy_intents`) but no capture shows who each enemy will hit — the friend can't play around WOUNDED/PACK personalities at all | Minimum: target hero's name as a die-docked tag under each enemy die ("→ SPLICE"). The die-tag plumbing exists (`battle_scene.gd:816` die-docked result tags) | should-fix |
| HP preview slivers thin + untaught (red damage / blue shield-ghost / purple burn) | Best comprehension tool in the battle; at 5–8 window px it reads as rendering noise. Widths are ratio-derived (`_place_preview_rect`) → also a pixel-snap law candidate | (a) floor each visible slice at 2 design px via `PixelUI.physical_px_width`; (b) one HELP line under HOW A TURN WORKS: "The HP bar previews the round: red = incoming, blue = saved by shield, purple = burn." | should-fix |
| Gold ±roll badge value ~20px | Carries the buff magnitude | Bump badge value font one step (STATUS_VALUE_FONT_SIZE) | polish |
| Die-status markers unverified on phone ("JAM ≤10", "REWRITE→3" Label3D) | Not captured this pass; 3D labels scale with camera, not UI | Capture once with a jammed + frozen die before the phone build; verify ≥24px effective | verify |

### 5. Battle — SET DIE VALUE dialog
| Issue | Why it hurts | Fix | Severity |
|---|---|---|---|
| "Drag to choose — costs 3 Protocol" ~16–18px | The cost disclosure is the smallest text in the dialog | 24px, amber | should-fix |
| Dialog doesn't say whose die is being set | Two blue dice look alike; mis-sets waste 3 PP | Title → "SET STRIKE'S DIE" | polish |

### 6. Battle — keyword primer (TAUNT spotlight)
| Issue | Why it hurts | Fix | Severity |
|---|---|---|---|
| Primer bar text good; "tap to continue" ~16px | Player may not know how to dismiss | 20px minimum | polish |
| Spotlight dims the affected unit's chip row too | The chip being explained (TAUNT) is dimmed along with everything else | Exempt the highlighted card's status row from the dim layer | polish |

### 7. Reward screen
| Issue | Why it hurts | Fix | Severity |
|---|---|---|---|
| "COMMON CONSUMABLE" rarity line ~18px | Rarity is a real pick signal (ladder rolls deeper later) | 22–24px; keep rarity-colored | should-fix |
| Uncommon = green (`RARITY_UNCOMMON #5cb85c`) — reward card borders, equip overlay title+buttons, item names | Direct conflict with INVARIANTS #7 "nothing else is ever green." A green-bordered card next to a green HP bar dilutes the HP=green law | **Needs a ruling:** either record rarity-green as a sanctioned exception in DECISIONS_RESOLVED, or recolor the token (suggest `#3fd0e2` teal-family or `#8fb85c` olive — one token change fixes every surface) | should-fix (pending ruling) |
| Icon circles: placeholder-quality silhouettes at inconsistent visual weight vs. the pixel-art everywhere else | Cards read grayer/emptier than the rest of the game | Existing item icon set (assets/icons/items/*) is stronger than the circle silhouettes; consider using them at 96px | polish |

### 8. Equip / discard overlays
| Issue | Why it hurts | Fix | Severity |
|---|---|---|---|
| Whole overlay adopts item rarity accent (green for uncommon) | Same doctrine conflict as above; also green SELECT buttons read as "confirmed/success" | Follows the RARITY_UNCOMMON ruling automatically | should-fix (pending ruling) |
| Overlay shows only hero names — no current gear context | Equipping Bounty Chip to someone already holding 2 gear pieces is blind | Line under each name: current gear count or names, muted 20px | polish |

### 9. Intercept screens (banner era)
| Issue | Why it hurts | Fix | Severity |
|---|---|---|---|
| Choice-button text wraps to 2 lines at ~22px and stays readable — good | — | none | ✓ |
| "INTERCEPT" type label ~18px | Pure accent; fine | — | ✓ |

### 10. Route fork
| Issue | Why it hurts | Fix | Severity |
|---|---|---|---|
| Modifier chip line ("⚠ HARDENED — Enemies spawn with 8 shield.") rust-on-dark ~18–20px | THE decision-relevant line of the screen | 24px; keep rust | should-fix |
| "◆ SUPPLY GRADE +2" gold ~18px | The reward half of the decision | Same bump | should-fix |

### 11. Evolution screen
| Issue | Why it hurts | Fix | Severity |
|---|---|---|---|
| Band effect lines ("5 dmg, mark" / "15 dmg (all), pierce") muted ~20px, 10 rows | This is a PERMANENT choice — the densest decision screen in the game at the smallest text | Effect lines to 24px TEXT_PRIMARY (keep band ranges muted); if height is tight, portraits can drop a step | should-fix |
| Branch names ("Bladecore", "Ravager") in green | Third green-doctrine surface | Follows the RARITY_UNCOMMON ruling / or DT_CYAN since it's a selection, not a rarity | should-fix (pending ruling) |
| "Choose Evolution" mixed-case title; every sibling screen is ALL-CAPS | Style drift | "CHOOSE EVOLUTION" | polish |

### 12. Relic cache
| Fine overall. "RELIC" label small (~18px) — same accent-class as reward rarity line; bump together. | should-fix (with #7) |

### 13. Help / Tactical Reference
| Issue | Why it hurts | Fix | Severity |
|---|---|---|---|
| Body bullets ~22px | The screen a lost friend goes to; 22px at arm's length is a squint (≈1.4mm) | 26–28px body; the panel has huge unused bottom space to absorb the reflow | should-fix |
| Tab grid ragged (3+3+1, SETTINGS orphan row) | Mild scan cost | 2×3 grid + SETTINGS as a footer-row button, or accept | polish |
| Faint ghost text visible in the lower panel area | Looks like a rendering artifact | Verify: low-opacity leftover label? Remove or raise above threshold | verify |
| Close pattern: this screen uses `X`; inspect uses "tap anywhere"; loadout uses tap-away | Three dismissal grammars | Pick one secondary affordance to add everywhere ("tap outside to close" works for all three) | polish |

### 14. Inspect popup (unit intel)
| Issue | Why it hurts | Fix | Severity |
|---|---|---|---|
| Keyword primer paragraphs ~20–22px muted | The rules text that INVARIANTS #5 stakes legibility on | 24px; primers are one sentence by law, so reflow is bounded | should-fix |
| Band ability names cyan ~22px — good; roll ranges good; pips good | — | — | ✓ |
| "Tap anywhere to close" ~16px | Only dismissal hint | 20px | polish |

### 15. Run end (victory / defeat)
| Issue | Why it hurts | Fix | Severity |
|---|---|---|---|
| SERVICE RECORD values ~18px muted | Lifetime stats are the retention hook on this screen | 22–24px | should-fix |
| THIS RUN body 20–22px | Borderline; one step up helps | 24px | polish |
| Banner + title + panel + button композition — good | — | — | ✓ |

---

## Cross-screen systemic issues (fix once, applies broadly)

### S-1. There is no font-size floor token — every small label is a hand-rolled constant
The same ~16–20 design-px "small amber label" appears as: role legend, PROTOCOL label, rarity
lines, SET-dialog cost line, service record, fork modifier chips, "tap to continue", primer
dismiss hints. About half are pure accents (fine); half CARRY INFORMATION (not fine).
**Fix:** add two named constants to `PixelUI` — `FONT_ACCENT_MIN := 20`, `FONT_INFO_MIN := 24` —
and migrate the info-carrying call sites listed above onto them. One review pass, ~10 call sites,
and future screens inherit the floor.

### S-2. Green doctrine conflict — one token, four screens
`RARITY_UNCOMMON #5cb85c` (reward borders, equip overlay, item text) + evolution branch names.
INVARIANTS #7 reserves green for HP/heal (+ protocol historically, now amber). **Needs Kev's
ruling** → either a DECISIONS_RESOLVED entry sanctioning rarity-green, or recolor the one token.

### S-3. Debug affordances ship in the header
`^` `^^` bound/visible everywhere (DB-1). One default-flip in PersistentHeader.

### S-4. Costs are invisible at the point of spend
Footer buttons (1/2/3 PP), items (1 PP), and disabled/affordable states all render identically.
One badge treatment + one dim treatment in `protocol_actions`/footer styling covers all.

### S-5. Pixel-snap law audit candidates (INVARIANTS #14)
- HP preview slivers: ratio-derived widths (`_place_preview_rect`) — floor visible slices at a
  snapped 2 design px so thin previews don't alias to 0/1 window px.
- Unit-select page dots: 1px-class elements.
- Status badge offsets over the portrait edge: verify snapped placement.
- All new banner strokes this branch are 2px (even) — compliant.

### S-6. Dismissal grammar
`X` (help) vs "tap anywhere" (inspect) vs tap-away (loadout, equip overlay). Standardize the
tap-outside behavior everywhere and keep the explicit hint on full-screen modals.

---

## Verify list (couldn't be judged from these captures)
1. Die-status Label3D sizes on device ("JAM ≤10", "REWRITE→3") — capture with statuses active.
2. Help-panel ghost text — artifact or leftover node.
3. Title-screen `?` binding — help reachable from title or inert.
4. Two-row readout worst case (3 heroes × 2-icon riders + protocol pip) — synthetic capture.
5. Chip overflow "+N" badge and DOWN state — no capture showed >3 chips or a death this pass.

## Explicitly excluded
- Animation timing (Kev directive: unfinished; separate pass with video frames later).
- Balance/copy content of abilities (out of scope; text SIZE only).
- Victory-capture stat oddities ("Battle 0/10", "Wins: 0") — artifacts of the synthetic capture
  harness (`run_end_capture.gd` forces `last_run_result` without finishing a run), not bugs.
