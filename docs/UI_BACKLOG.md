# UI Backlog — Direction-05 polish

Captured from playtest feedback. Grouped by area. UI lane (Claude); data-copy items
need review before they touch JSON. Keep the DT visual language (PixelUI single source
of truth, 4px borders, hard corners, portraits inset inside frames).

---

## 1. Encounter carousel (picker top)

- [ ] **Boss image to the right of the data.** Swap the carousel layout so the text
  block (name / threat / blurb) is on the left and the boss portrait sits on the right.
- [ ] **Carousel nav buttons half as tall.** The ◀ ▶ buttons are full-panel height now;
  cut their height ~50%.

## 2. Squad picker — layout & typography

- [ ] **Larger "SELECT ENCOUNTER" / "SELECT SQUAD" headers.** Bump the section header
  font size.
- [ ] **Larger description font.** The detail-bar blurb (and encounter blurb) font is
  too small — increase it.
- [ ] **Remove "· 3 OF 8"** from the "SELECT SQUAD" header line.
- [ ] **Move the focus tag (Control / Offense / Defense) to the top-right** of the
  detail ("SELECT A UNIT") box, instead of inline next to the name.
- [ ] **Remove the 1 / 2 / 3 slot-number badges** that appear on selected unit
  portraits — the cyan highlight border is enough.

## 3. Content / copy rewrites (data — REVIEW BEFORE APPLYING)

- [ ] **Rewrite unit descriptions.** Much more concise. No evolution info. No double
  dashes (—). Several units have changed since these were written — update to match
  current kits. (`pickerBlurb` in `data/raw/heroes.data.json`.)
- [ ] **Rewrite battle / encounter descriptions.** No double dashes. Do **not** name the
  final boss. **Show the drafts to the user to iterate before writing them into data.**
  (operation blurbs in `data/raw/battle-modes.json`.)

## 4. Unit info & detail popup

- [ ] **"MORE" button → full unit detail popup.** When a unit's description is showing
  in the detail bar, add a MORE button (bottom-right) that opens a popup with a full
  breakdown: all abilities, roll ranges, etc.
- [ ] **Reuse that same popup on battle long-press.** Long-pressing a hero or enemy
  portrait on the battle screen opens the same detail screen. It already exists with
  the new border language but is **too small to read** and needs TLC (sizing, layout,
  typography).
- [ ] **Separate "view info" from "select unit."** Today tapping a unit both shows its
  info and selects it for the squad. Design a flow where the player can browse unit
  details first and select separately — **without adding many extra clicks.** (Design
  task: needs a proposal before implementing.)

## 5. Battle screen — targeting & feedback

- [ ] **Target highlight uses the card's border color.** When choosing an enemy target,
  the card currently highlights blue; highlight it in the unit's border color (rust/red
  for enemies) — tie it directly to the border color, not a hardcoded value.
- [ ] **Don't gray out portraits for no-target units.** When an action is up, units that
  don't need targeting are dimmed. Instead, keep the portrait bright and **dull only the
  name**; and **highlight the names** of units that still need targets set.
- [ ] **Better showcase for ability scope/keywords.** Rework how "All", "Self", "2t" and
  keywords like "Cloak", "Pierce", etc. are displayed so they read clearly.

## 6. Tooltips / rollovers

- [ ] **Update hover long-descriptions** for the new UI context: the dice rollover, the
  ability-pip rollover, and the status rollover.

---

### Suggested order (see notes)

Quick low-risk picker polish (sections 1 + 2) → unit detail popup (section 4, it's reused
in battle) → copy rewrites (section 3, needs user review) → battle feedback (section 5) →
tooltips (section 6).
