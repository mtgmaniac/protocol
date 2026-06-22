# UI Backlog — Direction-05 polish

Captured from playtest feedback. Grouped by area. UI lane (Claude); data-copy items
need review before they touch JSON. Keep the DT visual language (PixelUI single source
of truth, 4px borders, hard corners, portraits inset inside frames).

---

## 1. Encounter carousel (picker top) — DONE (855c60c)

- [x] **Boss image to the right of the data.**
- [x] **Carousel nav buttons half as tall.**

## 2. Squad picker — layout & typography — DONE (855c60c)

- [x] **Larger "SELECT ENCOUNTER" / "SELECT SQUAD" headers.**
- [x] **Larger description font** (encounter + detail blurbs).
- [x] **Remove "· 3 OF 8"** from the "SELECT SQUAD" header line.
- [x] **Move the focus tag (Control / Offense / Defense) to the top-right** of the box.
- [x] **Remove the 1 / 2 / 3 slot-number badges** (cyan highlight is enough).

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

- [x] **Target highlight uses the card's border color.** Legal targets brighten in team
  accent (`DT_ENEMY_DITHER` rust / `DT_HERO_DITHER` cyan); active hero picker gets gold
  border. Border width unchanged so frames do not shift.
- [x] **Don't gray out portraits for no-target units.** Heroes still needing a manual
  target get a very bright name after roll; the active picker keeps a normal name with a
  gold border; everyone else stays default.
- [ ] **Better showcase for ability scope/keywords.** Rework how "All", "Self", "2t" and
  keywords like "Cloak", "Pierce", etc. are displayed so they read clearly. *(Mostly done
  via `EffectPip` — `)value(` / `(value)` scope + superscript duration; revisit status
  chips / tooltips if still unclear at 450×1000.)*

## 6. Tooltips / rollovers

- [ ] **Update hover long-descriptions** for the new UI context: the dice rollover, the
  ability-pip rollover, and the status rollover.

---

### Suggested order (see notes)

Quick low-risk picker polish (sections 1 + 2) → unit detail popup (section 4, it's reused
in battle) → copy rewrites (section 3, needs user review) → battle feedback (section 5) →
tooltips (section 6).
