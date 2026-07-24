# Tutorial Script Review — v2.5

Extracted 2026-07-24 from `scripts/ui/tutorial_controller.gd` (step script v2.5, 26 beats),
`scripts/battle/battle_scene.gd` (tutorial rig + event emits), `scripts/battle/protocol_actions.gd`
(v2.5 wrong-die nudge block), `scripts/ui/main_menu.gd` (first-run choice overlay), and
`scripts/ui/spotlight_layer.gd` (coachmark rendering). Copy is verbatim from code.

v2.5 polish pass (Kev-approved): hero-intro beat added (new beat 3), stage-1 assign
spotlights include the ability pip (beats 9/10/12/23), the nudge beat is hero-gated with an
input-level wrong-die block (beat 20), order-teaching consolidated to the assign-the-rest
beat (24), and copy edits on the first-run overlay and beats 13/14/23.

## Rendering notes (apply to every beat)

- Coachmark text renders in a plain `Label` — **no BBCode, no substitutions**; every copy
  string below is a literal and renders exactly as written (hyphens are plain `-`).
- A beat with a `title` renders it as a bracketed first line: `WELCOME` renders as
  `[ WELCOME ]` above the body text.
- Tap-to-advance beats append a right-aligned hint line **`Tap to continue >`** below the
  copy. Event-gated beats show no hint. The hint is SpotlightLayer chrome, not part of the
  copy string.
- On event-gated beats the overlay passes input through (the spotlighted control is fully
  interactive, and so is everything else — which is what makes the cancelled-nudge
  recovery on beat 20 work); on tap beats the overlay itself consumes the tap.
- When the player presses ROLL / END TURN on a beat that is *not* gated on that press, the
  dim drops to a whole-screen frame so the board animation is watchable.
- Diagnostics: every beat prints `[Tutorial] step N/26 advance=... holes=...` to the
  console (stage-2 retargets print again with `retarget`), and web builds publish live
  spotlight/die/button geometry to `window.__tut` (read-only test seam).

## Pre-entry: skip decision (not a beat)

There is **no in-drill Skip button**. The skip decision happens on the main menu's
first-run choice overlay, shown after the first BEGIN on a profile that has never
completed or skipped the drill:

- Title: `FIRST TIME?`
- Body: `This is your first time playing, want to run the tutorial?`
- Primary button: `RUN TUTORIAL` (enters the drill; on completion continues into the squad picker)
- Secondary button: `SKIP TUTORIAL` (sets the same tutorial_done flag; straight to squad picker)

The main menu also has a permanent `TUTORIAL` button (manual replay; exits to main menu on
completion — the Help-menu replay path is unchanged). Mid-drill abandonment: header back
button (tutorial_done stays unset, so the next BEGIN asks again).

## Global rigged state (all beats)

- Squad: Strike Unit (`combat`), Field Engineer (`engineer`), Splice Medic (`medic`) — the
  actual fresh-profile starting trio. Operation 1, battle 1.
- Enemy: ONE Scrap Drone at its **real statline** (35 HP) — honest rig: only dice values
  and the drone's aim are scripted, all outcomes are real engine math.
- Dice rig (raw rolls): turn 1 — Strike 9, Engineer 12, Medic 2, drone 6.
  turn 2 — Strike 8, Engineer 12, Medic 6, drone 6.
- Auto-assign of single-target shots is **disabled** in tutorial mode (forced manual
  targeting so the assign beats can gate on the real tap-die-tap-target flow).
- **v2.5:** during tutorial mode the nudge pick only applies to Strike's die
  (`TUTORIAL_NUDGE_HERO`); picks on other dice are silently ignored at the input level —
  the pick stays armed and no Protocol is charged.
- No consumable grant — the item loadout is empty (the item beat is a signpost only).
- Battle-entry briefing modal and encounter-counter increment are suppressed in tutorial mode.

---

## Beats

### 1
- **COPY:** `[ WELCOME ]` / `Welcome to Overload Protocol. I'll walk you through your first fight.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere.
- **SPOTLIGHT:** None — full-screen dim, coachmark only.
- **STATE:** Turn 1, AWAIT_ROLL. Nothing rolled yet.

### 2
- **COPY:** `This bar stays with you all run - squad progress and the Help menu live here.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere.
- **SPOTLIGHT:** The persistent header band (full width × 144 design px).
- **STATE:** As beat 1.

### 3  ← NEW in v2.5
- **COPY:** `Your squad - Strike Unit, Field Engineer, Splice Medic. Each rolls one die every turn.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere.
- **SPOTLIGHT:** Hero cards row (one merged hole — same target key beat 8 uses; no dice
  exist yet pre-roll).
- **STATE:** As beat 1. Intro arc is now welcome → header → YOUR side → THEIR side → roll.

### 4
- **COPY:** `This is your target - a Scrap Drone. 35 HP, and it hits back.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere.
- **SPOTLIGHT:** Enemy cards + enemy dice row (one merged hole).
- **STATE:** Drone at real 35 HP.

### 5
- **COPY:** `Tap ROLL.`
- **ADVANCE:** Perform the action — press the ROLL button (`roll_pressed` event).
- **SPOTLIGHT:** The ROLL button (interactive through the hole).
- **STATE:** Turn-1 dice rig armed: Strike 9 / Engineer 12 / Medic 2 / drone 6.

### 6
- **COPY:** *(none — invisible waiter; coach and dim hidden while the dice roll and settle)*
- **ADVANCE:** Automatic — `rolled` event when the roll resolves.
- **SPOTLIGHT:** None (overlay dismissed).
- **STATE:** Physics roll animating with rigged results.

### 7
- **COPY:** `Each die lands in a band - higher rolls, stronger abilities. This turn: Strike Unit hits for 6, Field Engineer for 11, Splice Medic shields.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere.
- **SPOTLIGHT:** Separate holes: the dice tray (combat zone) + each hero's ability-pip readout.
- **STATE:** Strike 9 → Suppression Fire (6 dmg), Engineer 12 → Overdrive (11 dmg),
  Medic 2 → Diagnostic Pulse (3 heal + 3 shield, targeted). Copy matches the rig.

### 8
- **COPY:** `Long-press a card for the full breakdown - long-press works on nearly everything. Try it.`
- **ADVANCE:** Perform the action — long-press any card (`inspected`). No side predicate
  (enemy-card inspect also advances — accepted).
- **SPOTLIGHT:** Hero cards row.
- **STATE:** As beat 7. InspectPopup renders above the coachmarks.

### 9
- **COPY:** `Tap Strike Unit's die, then the drone, to fire it. Your squad fires in the order you assign.`
- **ADVANCE:** Perform the action — Strike's assignment (`assigned`, hero == `combat`).
  Off-script assignments are silently ignored (no dead end).
- **SPOTLIGHT:** Two-stage. Stage 1 (v2.5): Strike's die + card + **ability pip** (three
  separate holes — the player sees WHAT they're firing). Stage 2: holes move to the legal
  targets (drone card + die) when Strike's targeting starts.
- **STATE:** Manual targeting forced. First mention of cast order (setup; the actionable
  teaching is beat 24).

### 10
- **COPY:** `Now Field Engineer - tap the die, then the drone.`
- **ADVANCE:** Perform the action — Engineer's assignment (`assigned`, hero == `engineer`).
- **SPOTLIGHT:** Two-stage; stage 1 = die + card + **ability pip** (v2.5).
- **STATE:** As beat 9.

### 11
- **COPY:** `The drone is winding up a 7-point hit on Strike Unit. Enemies always show their hand before it lands.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere.
- **SPOTLIGHT:** Separate holes: the drone's card, its ability pip, and its die.
- **STATE:** Drone rigged roll 6 → Stab (7 dmg) aimed at Strike. Copy matches.

### 12
- **COPY:** `Blunt it: tap Splice Medic's die, then Strike Unit. Shields absorb damage before HP does.`
- **ADVANCE:** Perform the action — Medic's assignment (`assigned`, hero == `medic`).
- **SPOTLIGHT:** Two-stage; stage 1 = die + card + **ability pip** (v2.5); stage 2 = legal
  ally card(s).
- **STATE:** Medic 2 → Diagnostic Pulse: 3 heal + 3 shield, targeted.

### 13
- **COPY:** `Lock it in - your squad acts, then the drone.`  *(v2.5: order clause dropped — taught at beat 24)*
- **ADVANCE:** Perform the action **and wait**: gates on `turn_resolved`, not the press.
  On the press the dim drops to a whole-screen frame.
- **SPOTLIGHT:** The commit button (reads END TURN at this phase).
- **STATE:** Resolution: drone 35 − 17 → 18 HP; Stab 7: shield soaks 3, Strike takes 4.

### 14
- **COPY:** `The drone took 17. Its hit landed for 7: the shield soaked 3, Strike Unit took 4.` + `Tap to continue >`  *(v2.5: "Time to patch up." dropped)*
- **ADVANCE:** Tap anywhere.
- **SPOTLIGHT:** Separate holes: Strike Unit (card + readout + die) + the battle log panel.
- **STATE:** Drone 18 HP; Strike −4 HP. Copy matches resolved math.

### 15
- **COPY:** `Roll again.`
- **ADVANCE:** Perform the action — press ROLL (`roll_pressed`).
- **SPOTLIGHT:** The ROLL button.
- **STATE:** Turn-2 rig armed: Strike 8 / Engineer 12 / Medic 6 / drone 6.

### 16
- **COPY:** *(none — invisible waiter, as beat 6)*
- **ADVANCE:** Automatic — `rolled`.
- **SPOTLIGHT:** None.
- **STATE:** On a fresh profile, the CLEANSE keyword primer displays during this roll;
  `rolled` is emitted only after the primer is dismissed (modals never overlap).

### 17  ← primer-showcase beat
- **COPY:** `When a mechanic you've never seen appears, a one-time tip points it out - like the Cleanse on Splice Medic's roll. The Help menu keeps every keyword whenever you need a reminder.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere.
- **SPOTLIGHT:** Medic's ability-pip readout.
- **STATE:** On replays the tip is already seen and nothing displayed — accepted; copy
  stands alone.

### 18
- **COPY:** `You banked 1 Protocol - income ticks +1 every turn, caps at 10. That's exactly enough for a Nudge.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere.
- **SPOTLIGHT:** The Protocol bar.
- **STATE:** Protocol is exactly 1 (income only).

### 19
- **COPY:** `Nudge costs 1 - tap it. (Reroll and Set cost 2 and 4 - they unlock as you bank more.)`
- **ADVANCE:** Perform the action — press the Nudge button; advances the instant the press
  arms the pick (`phase == "nudge_pick"`), before any die is chosen.
- **SPOTLIGHT:** The Nudge button.
- **STATE:** Protocol 1; Reroll (2) and Set (4) unaffordable, visible with real costs.
- **Cancel finding (v2.5 investigation):** the armed pick IS cancellable — off-unit tap,
  Nudge re-press (toggle-off), or another Protocol button — and cancels are always free
  (arming never deducts). Chosen recovery: **beat 20 stays active with the pick
  re-armable** (zero code — the pass-through spotlight leaves the Nudge button tappable);
  covered by the smoke test.

### 20  ← beat-19 fix landed here (v2.5)
- **COPY:** `Tap Strike Unit's die - +3 turns an 8 into an 11.`
- **ADVANCE:** Perform the action — apply the Nudge to STRIKE's die (`nudged` gated on
  hero == `combat`). **Input-level block (protocol_actions):** during the drill, pick
  attempts on any other die are silently ignored — the pick stays armed and the drill's
  only Protocol point cannot be spent off-script. The former any-die advance bug (false
  beat-21 copy + failable kill) is closed.
- **SPOTLIGHT:** Strike Unit as one merged hole (card + readout + die).
- **STATE:** Strike's die is the rigged 8; Nudge +3 → 11.

### 21
- **COPY:** `It jumped a band - Suppression Fire became Rail Strike, 6 damage became 10.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere.
- **SPOTLIGHT:** Separate holes: Strike's die + Strike's ability pip.
- **STATE:** 8 → 11 crossed a band boundary. Copy matches.

### 22
- **COPY:** `Item slots. You'll collect consumables on your run - using one costs 1 Protocol, same as a Nudge, and doesn't spend a die.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere.
- **SPOTLIGHT:** The footer ITEM button (renders even with an empty loadout).
- **STATE:** Loadout EMPTY (signpost only); Protocol now 0.

### 23
- **COPY:** `Splice Medic rolled a targeted heal. Tap the die, then Strike Unit, to restore life.`  *(v2.5: "that hit" → "life")*
- **ADVANCE:** Perform the action — Medic's assignment (`assigned`, hero == `medic`).
- **SPOTLIGHT:** Two-stage; stage 1 = die + card + **ability pip** (v2.5).
- **STATE:** Medic 6 → Infusion (10 heal, targeted); Strike at −4 from turn 1.

### 24
- **COPY:** `Assign the rest - Rail Strike and Overdrive at the drone. You pick the firing order; later, order wins fights.`  *(v2.5: order teaching consolidated here, where ordering is actionable)*
- **ADVANCE:** Perform the actions — assign both remaining dice; gates on `phase == "ready_to_end"`.
- **SPOTLIGHT:** Full-screen frame (whole board interactive); coachmark pinned mid-screen.
- **STATE:** Strike (Rail Strike 10) and Engineer (Overdrive 11) unassigned; drone 18 HP.

### 25
- **COPY:** `End the turn.`
- **ADVANCE:** Perform the action **and win**: gates on `won`, not the press.
- **SPOTLIGHT:** The commit (END TURN) button.
- **STATE:** Rail Strike 10 + Overdrive 11 = 21 into 18 — the kill closes on dice alone.

### 26
- **COPY:** `[ DRILL COMPLETE ]` / `That's the loop. The Help menu holds the full encyclopedia whenever you need it.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere (finish): persists tutorial_done, clears the run, exits — to
  the squad picker if entered via the first-run choice, to the main menu on manual replays.
- **SPOTLIGHT:** None — full-screen dim, coachmark only.
- **STATE:** Battle won; run state about to be reset.

---

## Summary notes

- **Total beat count: 26** (24 visible coachmarks + 2 invisible roll-waiters, beats 6 and 16).
- **Primer-showcase beat: #17** (the Cleanse tip itself fires during beat 16's roll on fresh profiles).
- **Help-menu pointer:** no single dedicated beat — pointed at three times: beats 2, 17, and 26.
- **Accidental-advance status (v2.5):**
  - The former beat-19 any-die nudge bug is **FIXED** (input-level block + hero gate).
  - Tap beats still advance on any tap anywhere; the double-tap-skippable runs are now
    **1→2→3→4**, **17→18**, and **21→22** — accepted by ruling (no tap-lockout).
  - Beat 8's `inspected` has no side predicate — accepted by ruling.
- **Copy vs render:** no discrepancies — all strings are plain-Label literals; the only
  rendering additions are the bracketed titles and the `Tap to continue >` hint.
