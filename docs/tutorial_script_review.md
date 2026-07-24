# Tutorial Script Review

Extracted 2026-07-24 from `scripts/ui/tutorial_controller.gd` (step script v2.4, 25 beats),
`scripts/battle/battle_scene.gd` (tutorial rig + event emits), `scripts/ui/main_menu.gd`
(first-run choice overlay), and `scripts/ui/spotlight_layer.gd` (coachmark rendering).
Copy is verbatim from code. **No code was changed.**

## Rendering notes (apply to every beat)

- Coachmark text renders in a plain `Label` — **no BBCode, no substitutions**; every copy
  string below is a literal and renders exactly as written (hyphens are plain `-`).
- A beat with a `title` renders it as a bracketed first line: `WELCOME` renders as
  `[ WELCOME ]` above the body text.
- Tap-to-advance beats append a right-aligned hint line **`Tap to continue >`** below the
  copy. Event-gated beats show no hint. The hint is SpotlightLayer chrome, not part of the
  copy string.
- On event-gated beats the overlay passes input through (the spotlighted control is fully
  interactive); on tap beats the overlay itself consumes the tap.
- When the player presses ROLL / END TURN on a beat that is *not* gated on that press, the
  dim drops to a whole-screen frame so the board animation is watchable (the spotlight
  never lingers on a stale control).

## Pre-entry: skip decision (not a beat)

There is **no in-drill Skip button** (playtest deletion — it occluded coachmarks). The skip
decision happens on the main menu's first-run choice overlay, shown after the first BEGIN
on a profile that has never completed or skipped the drill:

- Title: `FIRST TIME?`
- Body: `This is your first time playing - want to run the tutorial? You can replay it anytime from the Help menu.`
- Primary button: `RUN TUTORIAL` (enters the drill; on completion continues into the squad picker)
- Secondary button: `SKIP TUTORIAL` (sets the same tutorial_done flag; straight to squad picker)

The main menu also has a permanent `TUTORIAL` button (manual replay; exits to main menu on
completion). Mid-drill abandonment: header back button (tutorial_done stays unset, so the
next BEGIN asks again).

## Global rigged state (all beats)

- Squad: Strike Unit (`combat`), Field Engineer (`engineer`), Splice Medic (`medic`) — the
  actual fresh-profile starting trio. Operation 1, battle 1.
- Enemy: ONE Scrap Drone at its **real statline** (35 HP) — honest rig: only dice values
  and the drone's aim are scripted, all outcomes are real engine math.
- Dice rig (raw rolls): turn 1 — Strike 9, Engineer 12, Medic 2, drone 6.
  turn 2 — Strike 8, Engineer 12, Medic 6, drone 6.
- Auto-assign of single-target shots is **disabled** in tutorial mode (forced manual
  targeting so the assign beats can gate on the real tap-die-tap-target flow).
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

### 3
- **COPY:** `This is your target - a Scrap Drone. 35 HP, and it hits back.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere.
- **SPOTLIGHT:** Enemy cards + enemy dice row (one merged hole).
- **STATE:** Drone at real 35 HP.

### 4
- **COPY:** `Tap ROLL.`
- **ADVANCE:** Perform the action — press the ROLL button (`roll_pressed` event). Not a tap-anywhere.
- **SPOTLIGHT:** The ROLL button (interactive through the hole).
- **STATE:** Turn-1 dice rig armed: Strike 9 / Engineer 12 / Medic 2 / drone 6. Rigged values are fed to the 3D tray pre-roll so the physics settle shows the rigged face (no repaint flash).

### 5
- **COPY:** *(none — invisible waiter; coach and dim are hidden while the dice roll and settle)*
- **ADVANCE:** Automatic — `rolled` event when the roll resolves.
- **SPOTLIGHT:** None (overlay dismissed).
- **STATE:** Physics roll animating with rigged results.

### 6
- **COPY:** `Each die lands in a band - higher rolls, stronger abilities. This turn: Strike Unit hits for 6, Field Engineer for 11, Splice Medic shields.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere.
- **SPOTLIGHT:** Separate holes: the dice tray (combat zone) + each hero's ability-pip readout (combat, engineer, medic).
- **STATE:** Rigged rolls landed: Strike 9 → Suppression Fire (6 dmg), Engineer 12 → Overdrive (11 dmg), Medic 2 → Diagnostic Pulse (3 heal + 3 shield, targeted). Copy matches the rig.

### 7
- **COPY:** `Long-press a card for the full breakdown - long-press works on nearly everything. Try it.`
- **ADVANCE:** Perform the action — long-press any card (`inspected` event). **No side predicate**: inspecting an enemy card also advances, though the spotlight points at the hero row.
- **SPOTLIGHT:** Hero cards row.
- **STATE:** As beat 6. InspectPopup renders above the coachmarks (layer 130 > 110).

### 8
- **COPY:** `Tap Strike Unit's die, then the drone, to fire it. Your squad fires in the order you assign.`
- **ADVANCE:** Perform the action — complete Strike Unit's assignment (`assigned` event gated on hero == `combat`). Assigning another hero first is possible but silently ignored (no dead end).
- **SPOTLIGHT:** Two-stage: stage 1 = Strike's die + Strike's card (separate holes); when Strike's targeting starts, the holes MOVE to the legal targets (drone card + drone die).
- **STATE:** Manual targeting forced. Cast order = assignment order (order badges visible).

### 9
- **COPY:** `Now Field Engineer - tap the die, then the drone.`
- **ADVANCE:** Perform the action — Engineer's assignment (`assigned`, hero == `engineer`).
- **SPOTLIGHT:** Two-stage: Engineer's die + card → legal targets on targeting start.
- **STATE:** As beat 8.

### 10
- **COPY:** `The drone is winding up a 7-point hit on Strike Unit. Enemies always show their hand before it lands.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere.
- **SPOTLIGHT:** Separate holes: the drone's card, its ability pip, and its die (the telegraph).
- **STATE:** Drone rigged roll 6 → Stab (7 dmg) aimed at Strike (systematic targeting, slot 0). Copy matches.

### 11
- **COPY:** `Blunt it: tap Splice Medic's die, then Strike Unit. Shields absorb damage before HP does.`
- **ADVANCE:** Perform the action — Medic's assignment (`assigned`, hero == `medic`).
- **SPOTLIGHT:** Two-stage: Medic's die + card → legal ally card(s) on targeting start.
- **STATE:** Medic 2 → Diagnostic Pulse: 3 heal + 3 shield, targeted.

### 12
- **COPY:** `Lock it in - your squad fires in order, then the drone acts.`
- **ADVANCE:** Perform the action **and wait**: gates on `turn_resolved` (the full turn resolution finishing), not on the button press. On the press the dim drops to a whole-screen frame so the resolution is watchable.
- **SPOTLIGHT:** The commit button (reads END TURN at this phase; copy deliberately doesn't name it).
- **STATE:** Resolution math (all real): drone takes 6 + 11 = 17 → 18 HP. Drone's Stab 7: shield soaks 3, Strike takes 4 (Medic's 3 heal overflowed at full HP — honest, harmless).

### 13
- **COPY:** `The drone took 17. Its hit landed for 7: the shield soaked 3, Strike Unit took 4. Time to patch up.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere.
- **SPOTLIGHT:** Separate holes: Strike Unit (card + readout + die) + the battle log panel.
- **STATE:** Drone 18 HP; Strike −4 HP. Copy matches resolved math.

### 14
- **COPY:** `Roll again.`
- **ADVANCE:** Perform the action — press ROLL (`roll_pressed`).
- **SPOTLIGHT:** The ROLL button.
- **STATE:** Turn-2 rig armed: Strike 8 / Engineer 12 / Medic 6 / drone 6.

### 15
- **COPY:** *(none — invisible waiter, as beat 5)*
- **ADVANCE:** Automatic — `rolled`.
- **SPOTLIGHT:** None.
- **STATE:** On a fresh profile, the CLEANSE keyword primer (Medic's 6 → Infusion sights it) displays **during** this roll; the `rolled` event is emitted only after the primer is dismissed, so the primer modal and the next coachmark never overlap.

### 16  ← primer-showcase beat
- **COPY:** `When a mechanic you've never seen appears, a one-time tip points it out - like the Cleanse on Splice Medic's roll. The Help menu keeps every keyword whenever you need a reminder.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere.
- **SPOTLIGHT:** Medic's ability-pip readout.
- **STATE:** On a fresh profile the Cleanse tip just displayed (beat 15 note). On a replay the tip is already seen and nothing displayed — the copy is written to stand alone either way. **Flag:** on replays the line "the Cleanse tip just pointed it out" experience is absent; copy still reads sensibly but refers to something the replaying player didn't just see.

### 17
- **COPY:** `You banked 1 Protocol - income ticks +1 every turn, caps at 10. That's exactly enough for a Nudge.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere.
- **SPOTLIGHT:** The Protocol bar (the numeric label is hidden since the footer redesign — the target resolves to the 10-segment bar; the hidden label would merge back in automatically if it ever returns).
- **STATE:** Protocol is exactly 1 (income only). A second Nudge is unaffordable by design.

### 18
- **COPY:** `Nudge costs 1 - tap it. (Reroll and Set cost 2 and 4 - they unlock as you bank more.)`
- **ADVANCE:** Perform the action — press the Nudge button; advances the instant the press arms the pick (`phase` event with `phase == "nudge_pick"`), before any die is chosen.
- **SPOTLIGHT:** The Nudge button.
- **STATE:** Protocol 1; Reroll (2) and Set (4) unaffordable, visible with real costs.

### 19
- **COPY:** `Tap Strike Unit's die - +3 turns an 8 into an 11.`
- **ADVANCE:** Perform the action — apply the Nudge (`nudged` event). **No hero predicate** — see accidental-advance notes: nudging any die advances this beat.
- **SPOTLIGHT:** Strike Unit as one merged hole (card + readout + die).
- **STATE:** Strike's die is the rigged 8; Nudge +3 → 11.

### 20
- **COPY:** `It jumped a band - Suppression Fire became Rail Strike, 6 damage became 10.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere.
- **SPOTLIGHT:** Separate holes: Strike's die + Strike's ability pip.
- **STATE:** 8 → 11 crossed a band boundary: Suppression Fire (6 dmg) → Rail Strike (10 dmg). Copy matches.

### 21
- **COPY:** `Item slots. You'll collect consumables on your run - using one costs 1 Protocol, same as a Nudge, and doesn't spend a die.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere.
- **SPOTLIGHT:** The footer ITEM button (renders even with an empty loadout).
- **STATE:** Loadout is EMPTY (no grant — signpost only); Protocol is now 0 (spent on the Nudge), so the stated cost is real but not payable this turn.

### 22
- **COPY:** `Splice Medic rolled a targeted heal. Tap the die, then Strike Unit, to restore that hit.`
- **ADVANCE:** Perform the action — Medic's assignment (`assigned`, hero == `medic`).
- **SPOTLIGHT:** Two-stage: Medic's die + card → legal ally card(s) on targeting start.
- **STATE:** Medic 6 → Infusion (10 heal, targeted); Strike is at −4 from turn 1.

### 23
- **COPY:** `Assign the rest - Rail Strike and Overdrive at the drone.`
- **ADVANCE:** Perform the actions — assign both remaining dice; gates on `phase == "ready_to_end"`.
- **SPOTLIGHT:** Full-screen frame (whole board visible and interactive); coachmark pinned mid-screen (`coach_center`).
- **STATE:** Strike (Rail Strike 10) and Engineer (Overdrive 11) unassigned; drone at 18 HP.

### 24
- **COPY:** `End the turn.`
- **ADVANCE:** Perform the action **and win**: gates on the `won` event (victory at end of resolution), not the press. On the press, dim drops to whole-screen so the kill plays out.
- **SPOTLIGHT:** The commit (END TURN) button.
- **STATE:** Rail Strike 10 + Overdrive 11 = 21 into 18 HP — the kill closes on dice alone, any assignment order.

### 25
- **COPY:** `[ DRILL COMPLETE ]` / `That's the loop. The Help menu holds the full encyclopedia whenever you need it.` + `Tap to continue >`
- **ADVANCE:** Tap anywhere (finish): persists tutorial_done, clears the run, exits — to the squad picker if entered via the first-run choice, to the main menu on manual replays.
- **SPOTLIGHT:** None — full-screen dim, coachmark only.
- **STATE:** Battle won; run state about to be reset.

---

## Summary notes

- **Total beat count: 25** (23 visible coachmarks + 2 invisible roll-waiters, beats 5 and 15).
- **Primer-showcase beat: #16** (the Cleanse tip itself fires during beat 15's roll on fresh profiles).
- **Help-menu pointer:** there is no single dedicated Help beat — the Help menu is pointed at three times: beat 2 (lives in the header bar), beat 16 (keeps every keyword), and beat 25 (full encyclopedia).
- **Accidental-advance risks:**
  - Every tap beat advances on **any tap anywhere**, so consecutive tap beats are double-tap skippable before the copy is readable. The exposed runs are beats **1→2→3**, **16→17**, and **20→21** (beat 25 only ends the drill, which is its purpose).
  - **Beat 19 has no hero predicate on `nudged`**: the copy says "Tap Strike Unit's die," but nudging *any* die (e.g. Medic's 6 → 9) advances the beat — and then beat 20's band-jump copy ("Suppression Fire became Rail Strike") would be false for what the player actually did, and the turn-2 kill math (21 into 18) would still hold only via Engineer 11 + Strike's un-nudged Suppression Fire 6 = 17 < 18 — **the scripted kill can actually fail**, sending the drill into a third, unscripted turn. This is the one beat where an off-script action both advances the script and diverges the state from the copy.
  - **Beat 7's `inspected` has no side predicate**: long-pressing the enemy card advances even though the spotlight and copy point at hero cards (minor — the lesson still lands).
  - Beat 18 advances on arming the pick, not applying it — if the player then cancels the pick (if cancellation is possible in that phase), beat 19's instruction still applies and re-picking works; not a dead end, but the copy sequence assumes no cancel.
- **Copy vs render:** no discrepancies found — all strings are literals in plain Labels (no BBCode, no format substitutions). The only rendering additions are the bracketed titles (`[ WELCOME ]`, `[ DRILL COMPLETE ]`) and the `Tap to continue >` hint on tap beats, both SpotlightLayer chrome as documented above.
