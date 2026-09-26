# DECISIONS RESOLVED (human-adjudicated)

## NK-17 conditional alternative: `else` + Medic 20-band fallback (Kev, 2026-09-25) — RESOLVED & IMPLEMENTED

**Grammar.** NK-17 gains a *conditional-alternative* clause: `else N effect
(scope)`, comma-joined like every clause, legal only directly after a revive
clause, and firing only when the preceding clause has nothing to act on (no
hero down). `revive 50% HP, else 20 heal (hero)`. It is one token, reads
naturally, and keeps the comma split intact. `effect_text_target.py` counts an
`else` heal as its own kind (a plain heal can never stand in for it), requires
the amount to equal `fallbackHeal`, and rejects `else` anywhere but after a revive.

**Distinct from the conditional-BONUS ruling (Kev 2026-07-12).** That ruling adds
MORE to an effect that always fires (`10 +5❄` — base + bonus + condition icon on
one pip). `else` REPLACES an effect that cannot fire with a different one. They
are not interchangeable: never write a fallback as a bonus, or a bonus as an else.

**Abilities.** Resuscitate: revive a fallen hero at 50% HP (was 70%), else 20
heal (hero). Mass Revival: revive all fallen heroes at 30% HP, else 12 heal (all
heroes) — 12, not 20, so it is a clear step up from Nanite Crossfire's 6 (all)
without the fallback outshining the revive. Data: `fallbackHeal`, `fallbackHealAll`.

**Resolved at fire time, not pick time.** An ally can fall between the pick and
the cast; the ability does the more useful thing when it fires (anyone down →
revive, else heal). Lock-in at pick time would recreate the dead roll. Targeting
offers a living pick only when the fallback will fire.

**Board-aware pips.** The battle readout shows what this roll does NOW: the
revive pip when someone is down, the heal pip when nobody is. No second pip or
condition icon (keyword density is already a known problem). Inspect has no
squad state: it shows the revive pip at the resolved percentage and the eff text
carries the `else` clause.

**Directives override the revive percentage only.** Field Surgeon (Resuscitate
→ 100%) and Resuscitation Loop (Mass Revival → 50%) leave the fallback heal
unchanged — a directive that removed the fallback would reintroduce the dead
roll for the players who invested in it. Field Surgeon stays at 100%: its end
state is strictly better than today; its gain grows from +30 to +50 points of
max HP, **flagged for the next sim run**.

**Display honesty fix (same change).** Revive pips used to show raw `revivePct`,
ignoring the directive and the reviveNoPenalty relic (Field Surgeon showed 70
while reviving at 100). `ReviveResolution.resolved_pct` is now the one source for
the engine, the readout and inspect.

**Balance:** revive 70→50 plus the new fallback — not measured alone; **flagged
for the next sim run** together with Field Surgeon.

## Experimental battle landscape Stage B2 (Kev, 2026-09-23) — APPROVED

Stage B typography approved. Updated request (2026-09-25): rearrange the same
CompactUnitCard as a horizontal plate with an aspect-preserving portrait and a
separate information/status column; compare horizontal and vertical HP bars.
Hero readouts dock left of dice, enemy readouts right, vertically centered.
Cap and center Protocol with substantially larger grouped action buttons.
Enlarge landscape dice/numerals/readouts about
1.6–2×, reduce the gap between dice columns, center/clear the Protocol label,
contain status overflow, and consolidate landscape sizing in one style table.
Capture squad select, rewards, loadout, help and run end at 960×600 and 1280×720;
report cramped presentation without changing those screens. Keep portrait,
global viewport/settings, shared behavior and the default-false flag unchanged.
Stop with screenshots for review. Original dirty checkout remains untouched.

## Experimental battle landscape Stage B (Kev, 2026-09-23) — APPROVED

Proceed from Checkpoint 2 to landscape-specific typography, status/badge sizing,
spacing and polish. Keep shared behavior, portrait presentation, non-battle
presentation and global viewport/stretch settings unchanged. The player feature
flag stays false; the original checkout's unrelated 640×960 edit remains untouched.
Do not repair the pre-existing Nudge input issue or unrelated baseline failures.

## Experimental battle landscape Stage A (Kev, 2026-09-22) — APPROVED

Use the committed portrait configuration as the regression baseline. Do not touch
the separate working tree's uncommitted viewport change. Keep current non-battle
presentation and all global viewport/stretch settings unchanged. Reuse one battle
scene, shared components, bindings and behavior; only layout/sizing varies.
Landscape remains behind a default-false feature flag, with a debug-only session
override. AUTO tutorials stay portrait; explicit FORCE LANDSCAPE may test them.
The existing 47 passes / 6 failures are the baseline: do not repair unrelated
failures. Stop at Checkpoint 2 with portrait comparisons and both desktop captures,
before Stage B typography/badge polish. This scoped experiment is an explicit
exception to INVARIANTS #11's earlier prohibition on an orientation option.

## Web demo QoL: branded loader + end-of-round battle checkpoints (Kev, 2026-09-21) — RESOLVED & IMPLEMENTED

**Ruling (transcribed from Kev's request).** Two focused web-demo improvements,
no unrelated gameplay / UI / balance / layout changes:

1. Replace the generic Godot web loading presentation with a branded Overload
   Protocol loader: near-black, cyan accent, centered branding, the game's own O
   symbol pulsing (lightweight CSS), `INITIALIZING OPERATION...`, a progress bar
   only if the loader exposes reliable progress (never a fake percentage),
   `First launch may take a moment.` Visible immediately, no white flash, scales
   with the iframe, disappears cleanly; the "use whatever viewport the browser /
   itch iframe provides" behavior is preserved (no fixed portrait wrapper).
2. End-of-round battle checkpoints. An active battle is checkpointed ONCE per
   completed round, at the stable ready-to-roll boundary (after every action,
   damage, death, status tick, summon/revive and end-of-round cleanup; before
   the next Roll). Never mid-interaction (dice physics, selection, targeting,
   animation, enemy actions, Nudge/Reroll/Set). CONTINUE restores that state
   exactly, without replaying completed actions or duplicating consumables,
   rewards, XP, kills or relic triggers. **Refreshing must not reroll the upcoming
   dice** — the deterministic RNG state is checkpointed. Extend the existing
   run save with an optional `battle_checkpoint`; old saves keep loading. A
   close before the first completed round may restart the battle (as before).
   A finished battle clears its checkpoint. Exact mid-action recovery is out of
   scope.

**Supersedes in part G-21** ("Nothing mid-battle is serialized", "Live d20 FACES
are read off the settled physics tray and are NOT restorable", and "mid-battle
state serialization" under out-of-scope). Node-boundary checkpoints, the
battle-entry checkpoint and every other G-21 rule stand.

**As implemented.** Live d20 faces are drawn from the battle's seeded d20 stream
and rigged onto the physics tray (the dice still tumble; physics is presentation,
INVARIANTS #1), so the next round's dice are saveable state. `RUN_SAVE_VERSION`
1 → 2; v1 run saves are read forward (a strict subset: no block = no
checkpoint), not discarded. Details: TRUTH.md §Active-run save.

**Follow-up ruling (Kev, 2026-09-21, final QoL pass):** the saved battle RNG is
AUTHORITATIVE for dice faces and physics only visually resolves to them
(confirmed). 64-bit seeds are stored as strings (run save v3). **No backward
compatibility:** run saves older than v3 are discarded cleanly (the one-line
"older build" notice), not migrated — superseding the read-forward above.
CONTINUE into a restored checkpoint shows a brief `BATTLE RESUMED - ROUND X`;
no per-round SAVED message. Checkpoint frequency stays at the ready-to-roll
boundary; an item used after the last checkpoint may be undone by a refresh
(accepted). Tutorial/Help interaction wording is platform-neutral (Select /
Hold / Hold to inspect).

## UI consistency polish (Kev, 2026-09-20) — RESOLVED & IMPLEMENTED

Keep current battle portrait zoom and dimensions; correct friendly framing and
Scrap/Rust vertical alignment only. Merge Help into Protocol, Units, Battle Log,
Settings; retain Icon Guide within Protocol and enemy operation filters within
Units. Increase codex descriptor legibility and normalize thumbnails/HP alignment.
Add restrained pixel HUD default/hover cursors, Help hover/scroll/Escape polish,
capture before/after evidence, then bump the version. Implemented in demo4;
see `UI_CONSISTENCY_2026-09-20.md`. No combat or broader HUD redesign.

Companion to `docs/TRUTH.md` §DECISIONS NEEDED. Entries land here once Kev rules;
numbers are preserved from the TRUTH.md list so old references stay valid.
**Do not re-open a ruled item without a new explicit ruling from Kev.** Purpose:
future agents execute rulings — they do not relitigate them, and they do not
carry rulings in chat memory.

**How to read status:**
- **RESOLVED & IMPLEMENTED** — ruling landed in code+docs; done.
- **RULED — IMPLEMENTATION PENDING** — Kev has adjudicated it (2026-07 decision
  review). Where the entry says *ruling text awaiting transcription*, the ruling
  exists only in Kev's adjudication list: **step 0 of the implementing session is
  to paste the ruling text into the entry, then implement against the written
  ruling.** Implementing a pending item from a chat log or from memory — without
  the ruling written here first — is a process violation. This is the insurance
  against a session misreading an answer: the ruling lives in the repo.

---

# RESOLVED & IMPLEMENTED

## G-21. Desktop fit and tutorial recovery (Kev, 2026-09-20)

Kev approved completing and testing the existing Reddit-feedback fixes: offer help
for stalled gated tutorial actions, preserve the real lesson action instead of
skipping it, and keep THE OPERATION as the opening beat with the existing 0.22 dim.
Desktop redesign and balance changes are outside this pass. Assistance leaves
inspection open for the player to read; an impossible action offers an explicit
restart rather than advancing into invalid instructions.

**Web viewport (Kev, 2026-09-20, supersedes the same-day letterbox):** no custom
portrait-width restriction. The Web build uses whatever viewport the browser or
itch iframe supplies (Adaptive canvas, `canvas_items` + `expand` kept); no
desktop max-width, breakpoint or fixed width in code. Kev controls the desktop
presentation through itch.io's Embed Options. Mobile-sized viewports must keep
working. Per-screen responsive redesign is a separate, later decision.

Implementation and test evidence: [desktop verification](DESKTOP_TUTORIAL_2026-09-20.md).

## 1. Freeze semantics — FREEZE = REPEAT *(ruled by Kev, 2026-07-06; landed 52e2fa5)*

**Ruling.** Freeze = repeat is the original design intent, restored. Identical for
both sides: a frozen die crusts, stays static in the tray as a hard physics
blocker other dice bounce off, and on the next roll does NOT reroll. It keeps the
same face, and its unit **acts again on that same result — same zone, same
ability**. Targeting is re-picked fresh on each repeat (manual pick for heroes,
personality choke-point for enemies); only the die result is locked. After its
authored N repeats the die thaws and rerolls normally. Deep Freeze extends the
repeat count. Frozen dice are immune to Jam, Rewrite, and Hijack. Non-damage
freeze abilities (incl. shield+freeze / heal+freeze) target ANY unit via manual
pick (`freezeAnyDice`); freeze riders on damaging abilities stay enemy-side.
Enemy AI freeze targets the hero's LOWEST revealed die, deterministically.

**Lineage — kept so no future agent resurrects a dead model:**
1. **Bank/thaw (fix-1.4 "banked-face" reading, DEAD).** An unspent-reveal freeze
   "banked" the face; thaw revealed the banked value once. Written into
   `offline-bundle/GROUND_TRUTH.md` §7 with a DESIGN-TODO claiming it superseded
   the 67d95b6 revert. It did not. Killed for illegibility.
2. **Next-turn static lockout (commit-era revert, DEAD).** "Reverted per Kev from
   the fix-1.4 bank/thaw reading": the die stayed static and the unit SKIPPED its
   next N reveals — pure action denial. Live until 2026-07-06
   (`die_freeze_consumed_this_round`, item `skips` key).
3. **Repeat (2026-07-06, FINAL).** The frozen face is not denied — it is
   REPLAYED. Both prior models removed from code, data, text, and tests in one
   pass; flag is `die_freeze_repeat_this_round`, item data uses `repeats`, eff
   strings read `freeze (repeat N)`.

**Where it lives:** `combat_manager.gd` (freeze block, `_freeze_die_state`,
`_freeze_pick_hero_lowest_die`, jam/rewrite/hijack immunity guards),
`battle_engine.gd`, `policy_l1_greedy.gd`, TRUTH.md rule 7, `keywords.data.json`,
`ability_audit.gd` freeze regressions, `freeze_engine_regression.gd`.
**Balance note:** landed WITHOUT re-baselining (overall 53.0%→25.3%, Avalanche
79.8%→13.2%) — see the ±10 report in `docs/SESSION_2026-07-06_engine_semantics.md`;
rebalance is Kev's call.

## 3. Buff/DoT timers — INDEPENDENT INSTANCES *(ruled by Kev, 2026-07-06; landed 52e2fa5)*

**Ruling.** Roll buffs (`rfm` and `erb`, both sides) and DoTs (burn) stop
refreshing to max on recast. Each application is its own instance with its own
remaining duration; effective value = sum of live instances; each expires on its
own clock. Display aggregates ONE chip: summed value, longest remaining duration.
Canonical case: +3/2t cast turn 1, +5/2t cast turn 2 → turn 2 total +8, turn 3
total +5, turn 4 zero. **Rationale:** refresh-to-max made recast buffs read as
permanent and made burn stacking unpredictable; instances are the one-sentence rule.
**Known casualties (balance calls, data untouched):** `erbT: 1` (2 abilities) and
Emergency Signal's 1t buff now expire the round they're cast without shaping a roll.
**Where it lives:** `roll_buff_stacks`/`burn_stacks` in combat_manager, TRUTH rule
10, `_run_instance_timer_regressions`.

## 4. Permanent-burn Detonate — ONE TICK, NOT CONSUMED *(ruled by Kev, 2026-07-06; landed 52e2fa5)*

**Ruling.** Detonate on a PERMANENT burn (plagueProtocol) deals exactly one tick's
damage (the burn amount) and the permanent burn is NOT consumed. Finite burns
unchanged: amount × remaining turns, consumed. `DETONATE_MAX_TURNS` removed as the
mechanism. Payload Fuse +50% applies to the whole burst. **Rationale:** the 6-turn
cap was a data-derived placeholder, not a rule anyone could state; "one tick, keeps
burning" is legible and can't one-shot. **Where it lives:** `_detonate_burn` +
`get_expected_detonate_burst` (single-sourced into the Detonate pip), keywords def,
TRUTH keyword table, `_run_detonate_regression`.

## K1. Cloak = 2 clauses *(keyword batch Task 7, commit 4474ab3)*
Untargetable by hostile single-target abilities; breaks on dealing damage or being
hit by an AoE. The third clause ("first attack from Cloak gains Pierce") was
REMOVED — one keyword was doing two jobs. Ghost post-nerf sim: 43.5→50.8, no
compensation needed. Do not re-add pierce-from-cloak.

## K2. Pierce AND Breach both kept, distinct sentences *(keyword batch Task 6)*
Pierce (`ignSh`): damage ignores shields (they remain). Breach: destroys all
shield on the target BEFORE damage. They read as different verbs and support
different counterplay; merging them was considered and rejected. Keyword defs in
`keywords.data.json` are the canonical sentences.

## K3. Taunt unified, Lure deleted *(keyword batch Tasks 4+9, commit 0bd652c)*
One keyword both directions: "The taunted unit can only target the taunter."
Hero-side redirects all enemy aim (overrides everything, even cloak); enemy-side
keeps the internal `lured_by_id` split but every player-facing string says Taunt.
Do not reintroduce a separate Lure.

## K4. Jam cap = 10 *(keyword batch Task 5, commit b219162)*
`JAM_CAP := 10` (was 12). 12 barely bit (most bands sit below it); 10 clips the
surge band without deleting crit fishing. Wall of Static's own cap-15 clause is a
separate, intentional exception.

## K5. ECS rejected *(architecture review, Jul 2026 — docs/ARCHITECTURE_REVIEW_JUL2026.md)*
The dictionary-state + choke-point architecture stays. An ECS/refactor to typed
components was evaluated and rejected: the game's complexity ceiling (3v4 units,
~20 status keys) doesn't amortize the migration risk, and the sim/live-screen
shared-rule seam (BattleEngine) already gives the decoupling that mattered. The
approved structural work is the god-object split backlog, not a paradigm change.

## 17. voidCirclet 68% accepted, compensation pass owed *(accepted at 3901e06)*
The keyword batch moved voidCirclet 42.1%→68.4% (+26.3): ward cull + hijack swap +
Synod trash on SYSTEMATIC all point the same way. Kev accepted the baseline (the
mechanics were correct) and explicitly flagged a **compensating Synod pass** as
owed — a design decision on how much to claw back, folded into the post-semantics
rebalance (which now also covers the freeze=repeat regression, see #1).

**SUPERSEDED (per Kev 2026-07-06, baseline accept):** "Post repeat-freeze
checkpoint, pre repricing. Avalanche figure known biased low: L1 cannot yet play
ally crit banking. DECISIONS_RESOLVED #17 Synod compensation note is void; #6
through #10 deferred balance numbers re anchor to this checkpoint." Ruled
DEFERRED to the global balance pass (see the transcribed batch below).
Re-anchored 2026-07-06 to the crit-banking checkpoint (overall 0.2867; the
voidCirclet +10.5 is the Root Access counter — see the batch entry note).

---

# RULED — TRANSCRIBED 2026-07-06 *(implementation pending unless marked deferred)*

> Ruling text below is Kev's adjudication batch, transcribed VERBATIM (no
> paraphrase) per the cleanup order of 2026-07-06 — implement against THIS text.
> Batch preamble, verbatim: "Decision batch closeout, human adjudicated. Read
> docs/TRUTH.md and docs/INVARIANTS.md first. For every item: implement, update
> TRUTH.md in the same commit, move the entry from DECISIONS NEEDED into
> docs/DECISIONS_RESOLVED.md with date and rationale. Do NOT touch the freeze,
> buff timer, or detonate paths; those landed in a separate adjudicated session."
> Batch verify clause, verbatim: "VERIFY: validate-data, ability audit, flow
> smoke, tutorial smoke, ci_smoke. Expected drift: zero, except possibly #2's
> normalization sweep if any multi turn shields exist in data; report any delta
> before touching the baseline."

## 2. Shield "one round" per-side reading — IMPLEMENTED 2026-07-07
**Status:** CONFIRMED as coded; data audit found ZERO offenders (no shield
duration field exists; eff-text "Nt" suffixes near shields bind to the roll-buff
clause per the canonical grammar; only shieldsPersist persists). TRUTH rule 5
names the single exception; the combat_manager DESIGN-TODO is a resolved
citation. Doc-only — zero drift.
**Question:** code applies expiry per-side as "one opposing action phase" so
enemy-phase shields survive one tick (`combat_manager.gd` `_add_shield_stack`);
alternative was strict same-round expiry.
**Ruling (verbatim):** "#2 CONFIRMED plus sweep: shields last one opposing action
phase, per side expiry as coded. Audit data/raw for ANY ability, gear, or enemy
kit granting multi turn shields; normalize to one phase and fix eff text, long
descriptions, and pip descriptions. SINGLE NAMED EXCEPTION: shieldsPersist
(Mantle Core relic, MANTLE TYRANT standing rule) is untouched, and TRUTH.md rule
5 must name it as the only exception."

## 5. SCRAPMASTER "every other turn" — IMPLEMENTED 2026-07-07
**Status:** cadence now counts from FIRST ACTIVATION (per-boss
`assembly_line_first_round` stamp; phase 1 = first live enemy phase, rebuilds
on phases 2/4/6). Identical to the old even-round reading when the boss is live
from round 1 (the only shipping case → zero drift); the offset case is
regression-pinned. Player-visible rule text updated in BOSS_STANDING_RULES.
**Question:** code reads ASSEMBLY LINE as even-numbered rounds; alternative is
every 2nd enemy phase from first activation.
**Ruling (verbatim):** "#5: SCRAPMASTER's ASSEMBLY LINE fires every 2nd enemy
phase counted from first activation, not even numbered rounds. Adjust, update
player visible rule text, test the cadence."

## 6.–10. + 17. Balance numbers — DEFERRED to the global balance pass *(resolved as deferred)*
**Ruling (verbatim):** "#6, #7, #8, #9, #10, #17: record all six in
DECISIONS_RESOLVED as 'DEFERRED to the global balance pass' with file:line
cites; leave every number untouched; remove from DECISIONS NEEDED."
**Cites (current):** #6 INTERCEPT_CARDS `GameState.gd:394` · #7 route modifiers
`GameState.gd:253` · #8 boss cadence `combat_manager.gd:107` (consts + tuning
seam defaults) · #9 execute bonus `combat_manager.gd:1406` · #10 chain ratio
`combat_manager.gd:1474` · #17 Synod difficulty (see the superseded entry above).
**Checkpoint re-anchor (per Kev 2026-07-06, crit-banking checkpoint — supersedes
the repeat-freeze checkpoint anchor):** "Post crit-banking checkpoint. voidCirclet
+10.5 is mechanically coherent: frozen dice are immune to Rewrite and Hijack, so
ally banking directly counters ROOT HIEROPHANT's Root Access standing rule; the
bot found the boss tech. Avalanche at 23.7% remains the known repricing target;
no ability numbers move until that ruling. All deferred balance numbers re anchor
to this checkpoint." (Prior anchor for lineage: the repeat-freeze checkpoint,
overall 0.2533.) All six numbers are sweepable via the balance workbench
(`scripts/sim/knobs.json`).

**Batch-1 update (Kev 2026-07-11):** #10 `chain_ratio` was explicitly set
**0.6→0.5** in the Batch-1 data/balance pass (a small-changes batch, NOT the
global balance pass). The pinned chain audit regression was updated to the new
50% expectation in the same pass (still 228/0). The other deferred numbers
(#6, #7, #8, #9, #17) remain untouched. Baseline intentionally NOT re-pinned
(a full balance pass follows; win-rate implications deferred per the batch).

## 11. Reverse Gimbal UX
**Question:** "may subtract" implemented as tap-again to flip +3 ↔ −3.
**Ruling (verbatim):** "#11 CONFIRMED: Reverse Gimbal tap again to flip +3/−3
ships as is."

## 12. Cloak: hostile-only untargetability — IMPLEMENTED 2026-07-07
**Status:** code path verified (the legality filter skips cloaked units only on
hostile enemy-side picks; "hero" and friendly "any" picks include cloaked
allies); keyword def + inspect tooltip + TRUTH now state the friendly-picks
legality explicitly; battle_scene DESIGN-TODO replaced with the citation.
**Question:** friendly picks on cloaked allies stay legal (`_get_legal_target_ids`).
**Ruling (verbatim):** "#12 CONFIRMED: cloak blocks hostile single target picks
only; friendly picks on cloaked allies are always legal. Ensure the cloak def
and tooltip state it."

## 13. Tutorial runs count toward `runs_started` — IMPLEMENTED 2026-07-07
**Status:** start_run skips record_run_started when tutorial_mode is set; the
rung-1 pity unlock (3 runs → avalanche post-Batch-1; engineer before the
2026-07-11 starter swap) counts real runs only. No retroactive
save adjustment — already-banked tutorial runs are grandfathered (TRUTH notes it).
**Question:** they do today, feeding the rung-1 pity unlock (3 runs → engineer).
**Ruling (verbatim):** "#13: tutorial completion no longer increments
runs_started; the rung 1 pity unlock therefore counts real runs only. No
retroactive save adjustment; note grandfather behavior in TRUTH.md."

## 14. Directive Marks stay single-target on AoE — IMPLEMENTED 2026-07-07
**Status:** CONFIRMED, never AoE Mark. Data audit found ZERO abilities combining
AoE with mark (reported before any rewrite; none needed). Combat Sense and
Marked for Death descs now read "Your single-target hits Mark their primary
target."; the combat_manager DESIGN-TODO is a resolved citation.
**Question:** Combat Sense / Marked for Death mark only the single-target hit;
AoE marking everything read too strong.
**Ruling (verbatim):** "#14 CONFIRMED, never AoE Mark: keep single target
directive behavior; update Combat Sense and Marked for Death descriptions to say
they Mark the primary target of single target hits; audit data/raw for any
ability combining AoE with mark, report any found before rewriting them; replace
the DESIGN-TODO at combat_manager.gd:1215 with a resolved citation."

## 15. Mid-run re-equip — IMPLEMENTED 2026-07-07 (rejection recorded)
**Status:** REJECTED, not deferred: the deterministic rotate-one-slot stand-in
is the permanent behavior; the TODO at the _rotate_gear_loadouts site is now a
rejection citation. Do not build the full re-equip UI.
**Question:** "freely re-equip" is deferred; deterministic stand-in in place
(`GameState.gd`). Full UI wanted?
**Ruling (verbatim):** "#15: mid run re-equip REJECTED, not deferred. Remove the
TODO at GameState.gd:623, keep the deterministic stand in, record the rejection."

## 16. Active shield total readout — IMPLEMENTED 2026-07-07 (cut REVERSED, chip is canon)
**Status:** the shield chip is restored as a visible primary numeric chip
(⬡ + total) on unit cards, BOTH sides — the pkg8.1 cut is reversed per Kev and
the chip is canon. State-driven, so it updates live on grant/break/expiry and
drops at the correct per-side phase tick (#2); the renderer's shield palette
and numeric mapping had survived the cut, only the token source was restored.
HP preview unchanged. Pixel-level collision verification at 450×1000 lands in
the same-day UI precision batch (its chip-clamp acceptance covers 4-chip
zero-clip, superseding a one-off check here).
**Question:** shield total only visible via HP preview/inspect since the chip was
cut — sufficient at 450×1000?
**Ruling (verbatim):** "#16 RESTORE the active shield total as a visible primary
status chip on unit cards (battle_card_view), both sides, updating live as
shields are granted, broken, and expired, styled consistently with existing
chips. Record in DECISIONS_RESOLVED that the chip's absence is reversed per Kev
and the chip is canon; HP preview behavior unchanged. Note: with per side expiry
confirmed in #2, the chip must visibly drop at the correct phase tick, not at
round end."

## 18. Rarity palette — GREEN EXITS *(ruled by Kev, 2026-07-10; UI review S-2)*
**Question:** `RARITY_UNCOMMON` green (#5cb85c) surfaced on reward-card borders,
the equip overlay, and item text — in tension with INVARIANTS #7 ("green is
reserved for HP bars and heals — nothing else is ever green"). Sanctioned
exception, or recolor?
**Ruling:** recolor. Rarity ladder is gray → blue → purple → orange:
common `#7a8290` (keep) · uncommon `#5b7fe8` (was rare's blue) · rare `#9d52d8`
(was epic's purple) · legendary `#ff8230` (keep). "epic" is unused in data; its
token stays aligned with rare. Green now has zero non-HP/heal surfaces. The
evolution branch-name green (`PixelUI.HERO_ACCENT` at its single call site) is a
selection, not a rarity — recolored to `DT_CYAN` in the same pass.
**Where it lives:** `pixel_ui.gd` RARITY_* tokens, `evolution_screen.gd:300`.

---

# BUILD G PUNCH-LIST RULINGS (Kev, 2026-07-15 playtest)

## G-21. Save system — resumable runs + persistent meta (Kev, 2026-09-15)

> **Superseded in part (2026-09-21)** by "Web demo QoL: branded loader +
> end-of-round battle checkpoints" (top of this file): battles now checkpoint at
> each completed round, and live d20 faces come from the seeded stream. The
> clauses below that say otherwise are historical.

**Ruling.** Runs are resumable across a reload. Two files with separate
lifecycles: `user://save.json` (the existing profile — tutorial flag, unlocks,
lifetime stats, settings) keeps its path and schema, and `user://run.json` is
added alongside it for the ACTIVE RUN ONLY, deleted on victory, defeat and
ABANDON RUN. **No `meta.json`, no rename, no profile migration** — the profile
gains only a `schema_version` dispatch wrapper in front of the existing
`_merge_loaded`, which may never discard: a future schema bump must not cost a
player their unlocks.

Checkpoints land at NODE BOUNDARIES only, after a node's content is generated and
before the player acts on it. Nothing mid-battle is serialized. A reload restarts
the current battle from its opening state; the reward, event, fork and intercept
screens show the identical offers, in the identical order.

**The battle-start checkpoint is taken immediately after `record_battle_entered()`
and BEFORE the remaining one-shot consumptions** in `battle_scene._init_live_battle`
(carried protocol, battle-start consumables, the route modifier, the armed
intercept effects). Saving after them would restore a post-consumption run and
then re-enter the scene, which re-consumes nothing and silently drops the route
modifier — the resumed fight would be the easy version.

**`battles_fought` stays exactly-once across a resume.** It is the unlock metric
and INVARIANTS #18 calls it farm-proof by construction; a resumed battle that
re-counted its entry would make reloading an unlock farm. The guard is
`GameState.battle_entry_counted`, saved RUN STATE rather than a checkpoint
argument — as a parameter, every routing call site had to remember to forward it
and one that forgot re-opened the hole for the width of a scene transition.
`nat20s` and `deaths` are display-only SERVICE RECORD counters and DO double-count
the replayed part of a restarted battle; accepted, not worth mid-battle buffering.

**No run save is ever written while `tutorial_mode` is true.** The drill is not
resumable; only its completion flag persists.

**RNG.** Run-affecting randomness runs on owned `RandomNumberGenerator`
instances, never Godot's global stream. The save stores RNG `state`, never the
seed — restoring from a seed would rewind the between-battle economy and let a
reload reroll every reward already offered. **64-bit values (RNG states, seeds)
are stored as STRINGS**: Godot's JSON parses every number as a double, so an
unquoted int64 comes back rounded AND retyped, silently (verified on 4.6.2:
9007199254740993 → 9007199254740992.0). `DiceManager` and `PhysicsRollProvider`
gained owned streams seeded from `GameState.battle_rng_seed`, replacing bare
`randi()` / `randi_range()`. That seed is **derived** from (`run_seed`,
`current_battle`) and consumes no stream: drawing it from the run RNG was safe
only because the balance sim happens not to run `battle_scene`, and the first
seeded path to call it would have shifted every downstream reward, beat and
intercept roll. Live d20 FACES are read off the settled physics tray and are NOT
restorable — a restarted battle can roll differently, by design (INVARIANTS #1:
the tray is presentation).

**Write safety.** Copy the outgoing primary to `.bak`, then `.tmp` → rename into
place. Every write to a primary goes through that one atomic path, the repair
below included. On load the best of primary / `.bak` / the web mirror wins by a
monotonic **`save_seq`**, not `saved_at` (wall-clock moves backwards across a
device clock change or a timezone-confused browser). A copy that will not parse
loses to any copy that will; all three unusable = clean start, logged, no crash.
Deleting a run removes the mirror key as well as the files — a surviving mirror
copy would put CONTINUE back after a finished run. When the mirror wins a load,
the stale primary is **repaired in place**, keeping the winner's `save_seq`
(a repair is not a new save): `run.json` would heal at the next checkpoint
anyway, but `save.json` can go a whole session unwritten, so clearing site data
afterwards would silently roll a profile back.

**Web durability.** Godot 4.6.2 mounts `user://` as IDBFS with **no
`autoPersist`**, so writes sit in MEMFS until the engine's debounced `FS.syncfs`
fires from the main loop, and no GDScript API can force it. Background the tab
first — which is exactly what iOS Safari does — and the write dies with the page.
Every save is therefore ALSO mirrored to `localStorage`. This **narrows** the
window; it does not close it, because Safari persists localStorage
asynchronously too and the itch.io iframe partitions both stores. Every
`JavaScriptBridge` access degrades to the IDBFS-only path on failure. On web,
`OS.is_userfs_persistent()` false raises a non-blocking menu notice.

**Schema drift is a build break.** `RUN_SAVE_SCHEMA_FINGERPRINT` pins a hash of
the save's key/type structure beside `RUN_SAVE_VERSION`, and the `save schema`
gate fails when the structure moves without a version bump. Array length, the
keys of ID-keyed dictionaries (`GameState.ID_KEYED_RUN_FIELDS`) and `save_seq`
are excluded as data — a fingerprint that moved when a hero was swapped would
fire on ordinary play and be turned off. Recorded as a rule in `CLAUDE.md`: any
change to `to_save_dict()` bumps the version in the same commit, with the
migration decision.

**Known trade, accepted for the demo:** a player who is losing a battle can
reload to restart it. No mitigation was built.

**Supersedes.** `docs/OVERLOAD_PROTOCOL_DEMO_READINESS_AUDIT.md` R-02 ("either
implement an atomic between-battle run checkpoint or scope the first demo to
desktop") — the checkpoint is implemented, so the desktop-only fallback is off
the table. R-03 (mobile pause/focus lifecycle) is NOT addressed and remains open.

**Out of scope, unchanged:** mid-battle state serialization, cloud saves,
multiple save slots, and any balance or content change.

## G-17. Icon Guide in Help (Kev, 2026-09-09)

Add the reviewed Icon Guide to Help, with Actions and Effects sections using
the existing font and icons. Explain Nudge, Reroll, Set and Item, normal costs,
and common effect symbols; retain access to the full keyword reference.
Keep the current fonts and battle header (review option A). This approval is
for the guide only; battle prompts and the compact footer remain unchanged.

## G-18. Filled boss nameplate, option C (Kev, 2026-09-09)

Implement reviewed option C: a copper-filled nameplate with dark BOSS text
above the existing callsign, inside the current name-strip footprint.
Keep portraits, HP bars, status rows and targeting borders unchanged. No glow,
new portrait-corner badge or animation. Use the existing standing-rule boss
registry; ordinary enemies and heroes retain their current nameplates.

## G-19. Compact unlocks and simpler title (Kev, 2026-09-09)

Implement the reviewed compact small-unlock composition: title above a panel
sized to its awards, centered in the available area; Continue stays at the
bottom. Large lists retain scrolling and readable icon sizes.
Remove the title-screen Tutorial button and the duplicate "Tell me what to
fix" feedback nudge. Keep the Feedback button, the first-run tutorial choice,
and Help's tutorial replay. No font replacement or first-run behavior change.

## G-14. Two-encounter training and Engineer damage (Kev, 2026-09-08)

Implement the reviewed tutorial flow: complete guided turns, independent play after
the guidance, a real item choice, and an optional second encounter with two enemies
covering Burn and item use. Offer CONTINUE TRAINING / START YOUR RUN after the reward.
Training rewards remain in training. Preserve first-time item guidance in real runs.
Both dice and portraits remain valid selection/target inputs. Unit selection needs
only its existing selection affordances, not a separate mandatory lesson.
Use normal damage, HP and status rules; never clamp damage or prevent a legal kill.
Arrange guided rolls to leave room for independent decisions, preferably round three
of encounter one and throughout encounter two. Permanently change base Field
Engineer's Overdrive (11–15) from 11 to 10 damage; Mark then gives 15 damage.
Preserve the compact footer. This supersedes the tutorial deferral in G-13.

## G-1. Operation-unlock popup FOLDED into the UnlockScreen *(ruled; landed Build G)*
**Ruling.** The separate one-time operation-unlock popup
(`OperationBriefingOverlay.present_unlock`) is retired. The UnlockScreen's NEW
OPERATION section shows the operation name (caps law: Title-Case label form -
"Facility Sweep" / "Hive Incursion" fixed in battle-modes.json) with its
one-sentence origin line beneath at body tier. Building the row acknowledges
`operation_origins_seen`. The deployment slate's first-run behavior is
unchanged.

## G-2. NK-17 amendment: equipped self-buffs drop the (self) marker *(ruled; landed Build G)*
**Ruling.** GEAR and RELIC effects that buff the HOLDER omit the `(self)`
marker and any self-target icon - equipment context makes it redundant.
ABILITY effect text keeps NK-17 exactly as-is. Encoded in TRUTH.md's grammar
section and gate-enforced both directions by
`scripts/checks/effect_text_target.py` (abilities: computed suffix required;
gear/relic/item text: `(self)` banned). `EffectPip.effects_from_passive`
strips the `self` scope at its single exit; `all`/`lowest` scopes stay.
The D sweep re-ran under the amended grammar: zero equipment offenders
existed (the amendment prevents future stamping and removes the redundant
self icon from equipment pip rows).

## G-3. Firewall must be visible *(ruled: yes; landed Build G)*
**Ruling.** Firewall (one mechanic - internal field `ward`, displayed
Firewall; NOT a duplicate of some other mechanic) displays at the portrait
tier alongside cloak/freeze: a FirewallBadge docked to the portrait corner
whenever `warded` is true, both sides, cleared on break/expiry. Not a new
chip - the sanctioned chip stays and still competes in the 3-chip row; the
badge is the always-visible tier. A hidden defensive state that eats an
ability without explanation was the defect.

## G-4. Taunt targets a SINGLE enemy *(ruled; landed Build G Lane 2)*
**Ruling.** Hero-side taunt is a single-enemy redirect, not an all-enemy
stance: casting taunt picks ONE enemy; that enemy can only target the
taunter until round end (NK-08 clearing unchanged). This aligns the code
with what the keyword def and NK-17 bare-`taunt` grammar already claimed
("The taunted unit can only target the taunter."). Enemy-side paths keep
their shapes: beastHyena's lure stays single-hero (`lured_by_id`);
veilPrism's `enemySelfTaunt` stays the all-heroes self-taunt (the taunted
units are all heroes, each restricted to the one taunter - consistent with
the def). Anchor Frame gear (`tauntAbove50`) is a standing stance and keeps
its aura behavior pending its own ruling - recorded here as the ONE
remaining aura-form taunt.

## G-5. Portrait corners carry NO status markers *(ruled by Kev, 2026-09-02; REVERSES G-3 / Build G item 11)*
**Ruling.** Nothing renders in a battle card's portrait top-right corner. The
`FirewallBadge` docked there by G-3 is DELETED. An armed firewall is an ordinary
chip in the bottom status row, on the existing priority order, under the same
3-chip cap and the same `+N` overflow as every other chip.
**This reverses G-3 ("Firewall must be visible"), which added the portrait-tier
badge precisely because the chip kept losing the 3-chip priority contest into
the `+N` overflow.** That outcome is now ACCEPTED: firewall may sit in overflow.
The cost is paid for by long-press, which shows the full status breakdown — and
the badge's own cost (a status tier that only one mechanic could ever use, and
a portrait corner permanently reserved) was the larger one.
**Corner audit at the time of ruling** (`compact_unit_card.gd`): top-LEFT is the
`CastOrderBadge` — the hero's own cast-order rank, an input the player set, not
unit state — and is UNCHANGED by this ruling; top-RIGHT is now empty;
bottom-left/right were already empty (the chip row is a full-width
`PRESET_BOTTOM_WIDE` strip, not a corner dock). The roster-tile corner badges on
the home screen (role color, pick-order slot, NEW) are selection and unlock
affordances, not unit status, and are untouched.
**Where it lives:** `scripts/ui/compact_unit_card.gd` (badge, its constants, its
layout reservation and the dead `warded` mirror all removed),
`battle_card_view.gd` (the `warded` configure key dropped — the firewall chip is
built from state by `_build_compact_status_tokens` as before), TRUTH.md chip
doctrine. Regression `scripts/debug/firewall_display_test.gd`, rewritten to
assert the new behaviour: no badge node, the chip renders, and firewall folding
into `+N` behind three higher-priority chips is a PASS, not a failure.

## G-6. Effect-pip overflow renders `+N` *(ruled by Kev, 2026-09-02)*
**Ruling.** The pip-row cap stays at 3, kept first-three-by-authoring-order.
What changes: effects past the third no longer vanish SILENTLY. They fold into
one trailing `+N` badge after the third pip, using the same overflow language
the card's status chip row already speaks (gold, "+N", TRUTH.md chip doctrine).
`effects_from_ability_raw` used to end in a bare `effects.slice(0, 3)`. Twelve
abilities were losing a keyword with nothing on the card to say so — Lattice
Link, Fortress Lash, Conclave Bulwark, Harmonic Mend and Hierophant Mantle lost
firewall; Veil Collapse, Lattice Storm, Broodlink Surge, Veil Cataclysm, Mass
Snare, Void Gate and Total Eclipse lost summon. Conclave Bulwark's long-press
read "…firewall, summon (42%)" over an icon row that showed neither.
The dropped effects remain readable: long-press renders the ability's authored
eff text beneath the pips, and that text carries every clause. Verified, and
asserted in the regression — if the eff text ever stops carrying them, the badge
points at nothing and THAT is the bug.
**Where it lives:** `scripts/ui/effect_pip.gd` (`MAX_VISIBLE_EFFECTS`,
`_cap_with_overflow`, the `overflow` letter-only kind and its gold value color),
`compact_unit_card._pip_border`. Every pip surface — readout, die-docked tag,
inspect, evolution — inherits it through `EffectPip.build_group`, one producer.
Regression `scripts/debug/effect_pip_overflow_test.gd` (gated), which also
sweeps all 230 authored abilities for a well-formed row.

## G-7. G-2's principle extends to hero-side ability PIPS *(ruled by Kev, 2026-09-02; extends G-2)*
**Ruling.** The `self` scope MARKER (the circled-figure icon) is stripped from
hero-side ability pips: on your own squad card a self-buff is already obvious,
so the icon is noise. It stays on the ENEMY side, where "who does this hit?" is
the open question, and `all`/`lowest` stay on both sides. This is the same
principle G-2 applied to gear/relic/consumable passives — redundant
self-marking is noise where context already answers it — extended from
equipment passives to hero ability pips. Recorded now because an earlier batch
landed the code without a written ruling.
**Tension to record honestly:** G-2 closed with "ABILITY eff text keeps NK-17
exactly as-is," and read narrowly that line reserves abilities from the
amendment entirely. The reconciliation: G-2's sentence governs authored eff
TEXT, and eff text IS untouched — NK-17 still owns the "(self)" suffix and
`scripts/checks/effect_text_target.py` still requires it on abilities in both
directions. What this ruling changes is the ICON, a different surface. Anyone
reading G-2's closing line as covering pips too is reading it reasonably; this
entry is the ruling that settles it, not a claim that G-2 already allowed it.
**Where it lives:** `EffectPip.effects_from_ability_raw`, the hero self-buff
exception block at its exit (mirrors `effects_from_passive`'s single-exit strip
from G-2). Gate `effect target` (`effect_text_target.py`) is unaffected and
still enforces the text side.


## G-20. Final feedback and casualty recovery (Kev, 2026-09-10)

Implement local Mark acquisition, distinct Burn application/tick cues, and summon/revive arrival effects; respect Reduced Motion and preserve turn timing. Remove the income sentence from the first item-acquired primer. Heroes dead at the end of the previous battle return at 75% of their updated maximum HP (integer floor, minimum 1), before explicit battle-start damage. Survivors retain full recovery; in-battle revival percentages stay authored. Prioritize verified source committed and pushed to main; web/physical-device release verification remains open.

## G-13. Implement approved choice mockups and Reduced Motion (Kev, 2026-09-07)

Implement V07 inspect/evolution and V08 route/reward mockups. Ability details use fixed roll columns, secondary names and bright left-aligned concise effects; evolution previews show the 20 first, expandable full abilities and selection before confirmation. Route consequences separate risk and reward; share hostile composition only when the two routes actually match. Reward names and effects remain bright regardless of rarity. Implement V12 as a persisted, default-off Reduced Motion setting: suppress decorative shake, glitch, strong washes and exaggerated scaling while keeping results, feedback and navigation functional. This supersedes G-12's mockup-only/deferred scope for V07/V08/V12 and older centered ability-row styling. Preserve gameplay and G-11's compact footer. V06 and V11 remain, with the full tutorial redesign separately deferred.

## G-12. Next visual pass scope (Kev, 2026-09-07)

Mock up V07/V08 for review; do not implement those layouts yet. Implement V09 art-outlier fixes using existing art when it fits the item's role and current style, and V10 bounded combat-number stacking. Remove the icon from the run-end Continue button. Reproduce V11's unlock-layout finding and explain V11/V12; these are investigation/explanation, not approval to redesign unlocks or add reduced motion. Twin Fates stays removed. Keep gameplay, the restored compact footer and stable item IDs unchanged.

## G-11. Restore compact battle footer (Kev, 2026-09-06)

The enlarged, labeled footer overlaps friendly health bars. Kev approved going back to the prior compact icon-only layout. Restore 112×112 buttons and bottom-right costs, and remove permanent captions. This supersedes the footer portion of G-10. Keep Twin Fates removed and preserve the other step-1 changes. Do not repeat the label enlargement without a new layout decision.

## G-10. Public-demo visual step 1 (Kev, 2026-09-06)

Kev approved step 1: preserve readable dice values under status overlays; improve the footer with icons and compact labels if they fit; replace the default application icon with the existing identity's reactor motif; hide developer controls until seven consecutive taps on the operation title unlock them for the current application session; and correct inaccurate help while deferring the full tutorial rethink to step 2.

Remove Twin Fates from the game for now, including offers, unlocks, reference content and its battle copy controls. Preserve old profile compatibility and unrelated stable IDs. This supersedes G-9's retention of Twin Fates. Existing art may remain as an unused source asset. No other relic, dice rule or progression formula changes.

## G-9. Apply the concise copy review (Kev, 2026-09-06)

Kev approved implementing the full revised copy workbook. Apply its names, lore, descriptions and compact ability tooltips, with matching runtime references and preserved internal IDs/art paths. The approved effect syntax uses “damage” and explicit “turns”; hero self effects are implicit, while enemy self effects retain `(self)`. Group targets say `(all heroes)` or `(all enemies)` and lowest-HP support says `(lowest HP)`. This updates the text portion of NK-17/G-7; target checking must still derive and verify each clause's actual scope. Gear and consumables keep concise holder/target context. Operation threat lines retain their original text. Deployment labels become SITUATION and OBJECTIVE.

Resolve the review's copy/code mismatches without tuning authored numbers: enemy ally-shield clauses work independently of self-shield; Bounty excludes every standing-rule boss, including Mantle Tyrant; Deep Freeze Charge does not change an already-frozen face (it extends that freeze). Twin Fates retains its existing free, once-per-battle base-roll copy and controls. Long intercept choices use short action buttons and separate readable consequences.

## G-8. Frozen 20s and reinforcement kill rewards (Kev, 2026-09-05; supersedes NK-04 and NK-10)

Kev requested that Overload Loop activate again on frozen turns, removed frozen-repeat exclusions, and confirmed that summoned and rebuilt enemies should count for kill rewards. Every resolution of a frozen 20 now triggers the usual 20-face riders on both sides: Loop/Rites echo, Protocol-on-20 gear, the 20s statistic, and enemy summon chance. Loop/Rites grant one extra activation, not recursive echoes; Protocol and stats pay once per resolving hero turn, not once per echo. Existing summon chances and field limits remain.

Summoned and rebuilt enemy deaths now qualify for normal kill rewards: Protocol, Bounty, Chitin Graft, Kill Switch, Momentum, and Scavenger Manifest. Killer, mark, enemy-type, inventory-capacity, and once-per-battle requirements still apply. Freeze duration and alteration immunity remain unchanged. Player copy uses “turns”; Glacier's Deep Freeze adds one turn.

## G-15. Basics before effects (Kev, 2026-09-08)

Approved: welcome first; battle one teaches damage, heal, shield and Protocol only, retaining free turn three. Battle two retains Strike and swaps Engineer for Pulse to teach Mark and Burn, inventory use, and a once-only Reroll hint when 2 Protocol and an available die make it usable. Inventory instructions spotlight only its button. Remove repeated starting-Protocol and training-reward disclaimers. Close with more effects to discover and thanks before squad selection. Training still clears its rewards on exit; authored combat rules and numbers remain unchanged.

### G-15 copy follow-up (Kev, 2026-09-08)
Approved concise battlefield/roll/inspection/intent teaching, remove the results beat, introduce income beside Nudge, shorten reward/continuation copy, clarify delayed Burn and future primers. Use Splice in instructions. Inspect redirects flash visible die and portrait rather than pip hit area. Suggested targets stay unenforced. Income wording remains each completed turn to match runtime.

## G-16. Stable squad selection and display-name copy (Kev, 2026-09-08)
Keep the detail-panel footprint on locked encounters with no focused hero, transparent when empty. Hide locked hero names while retaining silhouettes/LOCKED and layout space; supersedes prior named-locked-card presentation. Remove NO CLEARANCE for unplayed operations; keep meaningful progress and LOCKED. Tutorial refers to SCRAP and introduces new abilities without naming them early. Briefing title/keys stay uppercase; site, situation and objective use sentence case with proper boss names. No unlock or combat changes.
