# DECISIONS RESOLVED (human-adjudicated)

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

## 5. SCRAPMASTER "every other turn"
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

## 11. Reverse Gimbal UX
**Question:** "may subtract" implemented as tap-again to flip +3 ↔ −3.
**Ruling (verbatim):** "#11 CONFIRMED: Reverse Gimbal tap again to flip +3/−3
ships as is."

## 12. Cloak: hostile-only untargetability
**Question:** friendly picks on cloaked allies stay legal (`_get_legal_target_ids`).
**Ruling (verbatim):** "#12 CONFIRMED: cloak blocks hostile single target picks
only; friendly picks on cloaked allies are always legal. Ensure the cloak def
and tooltip state it."

## 13. Tutorial runs count toward `runs_started`
**Question:** they do today, feeding the rung-1 pity unlock (3 runs → engineer).
**Ruling (verbatim):** "#13: tutorial completion no longer increments
runs_started; the rung 1 pity unlock therefore counts real runs only. No
retroactive save adjustment; note grandfather behavior in TRUTH.md."

## 14. Directive Marks stay single-target on AoE
**Question:** Combat Sense / Marked for Death mark only the single-target hit;
AoE marking everything read too strong.
**Ruling (verbatim):** "#14 CONFIRMED, never AoE Mark: keep single target
directive behavior; update Combat Sense and Marked for Death descriptions to say
they Mark the primary target of single target hits; audit data/raw for any
ability combining AoE with mark, report any found before rewriting them; replace
the DESIGN-TODO at combat_manager.gd:1215 with a resolved citation."

## 15. Mid-run re-equip
**Question:** "freely re-equip" is deferred; deterministic stand-in in place
(`GameState.gd`). Full UI wanted?
**Ruling (verbatim):** "#15: mid run re-equip REJECTED, not deferred. Remove the
TODO at GameState.gd:623, keep the deterministic stand in, record the rejection."

## 16. Active shield total readout
**Question:** shield total only visible via HP preview/inspect since the chip was
cut — sufficient at 450×1000?
**Ruling (verbatim):** "#16 RESTORE the active shield total as a visible primary
status chip on unit cards (battle_card_view), both sides, updating live as
shields are granted, broken, and expired, styled consistently with existing
chips. Record in DECISIONS_RESOLVED that the chip's absence is reversed per Kev
and the chip is canon; HP preview behavior unchanged. Note: with per side expiry
confirmed in #2, the chip must visibly drop at the correct phase tick, not at
round end."
