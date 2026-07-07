# Session log — 2026-07-06 — Engine semantics changes (human-adjudicated, FINAL)

Three rulings by Kev, 2026-07-06: **(A)** Freeze = repeat, **(B)** buff/DoT independent
instance timers, **(C)** permanent-burn Detonate = one tick, not consumed.
Resolves DECISIONS NEEDED #1, #3, #4 (see docs/DECISIONS_RESOLVED.md at closeout).

**Note:** the briefing said to read `docs/INVARIANTS.md` — that file does not exist
anywhere in the repo (checked recursively). Proceeding with `docs/TRUTH.md` as canon
per CLAUDE.md/AGENTS.md.

---

## STEP 0 — clean reference (UNTOUCHED tree, commit 90b14c8, branch main)

All gates run before any edit, 2026-07-06:

| Gate | Result |
|---|---|
| `npm run validate-data` | PASS — game data validates against schemas |
| AbilityAuditRunner (headless) | **PASS — 214 passed, 0 failed** |
| flow_smoke_test.gd | PASS — all 14 steps, no logged errors (known benign ObjectDB leak warning at exit) |
| tutorial_smoke_test.gd | PASS — all 21 steps, all spotlights resolved |
| run_smoke_test.gd | PASS — full run completed (defeat b10, 27 transitions, attempt 1) |
| DiceTrayPhysicsProbe | PASS — rolls=8, penetration_events=0, flyover_events=0, frozen_max_drift=0.0000, tilted_rests=0 |
| Sim batch (pinned ci_smoke config: policy l1, seed-base 900000, 300 runs) | reproduces `scripts/sim/baseline.json` **exactly** (byte-deterministic) |

### Per-operation baseline snapshot (CLEAN REFERENCE — all later ci_smoke deltas report against THIS)

```
overall_clear: 0.53          (300 runs, policy l1, seed-base 900000)
facility:          0.7746
hive:              0.2034
stellarMenagerie:  0.3958
veil:              0.5231
voidCirclet:       0.6842

clear_by_hero:
avalanche 0.7982 · breaker 0.4522 · combat 0.5043 · engineer 0.5676
ghost 0.5081 · medic 0.4762 · pulse 0.4673 · shield 0.4579
```

Identical to `scripts/sim/baseline.json` (accepted at 3901e06). Full metrics JSON
(incl. content_lift) = baseline.json — no drift on the untouched tree.

**±10 ceremony:** any per-op clear-rate move beyond ±10 points vs this snapshot is
reported and NOT self-approved; baseline.json is only updated after Kev signs off.
Deltas are reported against this snapshot BEFORE any `--update-baseline`.

---

## Work log

### A — FREEZE = REPEAT (done)
- `combat_manager.gd`: lockout skip deleted from both reveal loops (units now ACT
  on the repeated face, log line announces the repeat); freeze block comment now
  cites the ruling (repeat semantics, per Kev 2026-07-06, supersedes lockout and
  bank/thaw); `_freeze_die_state` lost the dead `immediate` param; state flag
  renamed `die_freeze_consumed_this_round` → `die_freeze_repeat_this_round`
  everywhere (engine, scene, policy, tests) so no lockout-era reference survives.
- Targeting: `_freeze_pick_hero_lowest_die()` — enemy AI freeze rider targets the
  hero's LOWEST revealed die (raw face stash `_current_raw_hero_rolls`, fallback
  `last_die_value`; taunt overrides, cloak excluded, slot-order tie-break, no
  randi). Hero non-damage freezes converted to `freezeAnyDice` (Glacial Lattice,
  Permafrost Weave, Permafrost Aegis); damage+freeze riders stay enemy-side.
- Immunities: frozen dice immune to Jam, Rewrite (guards in `_apply_jam` /
  `_apply_rewrite` — covers ROOT ACCESS boss rule too) and Hijack (guard at the
  hijack override in `resolve_round`). Implied consequences also enforced: a
  frozen die can't be Rerolled (item reroll fizzles; UI blocks the pick), can't
  be Twin-Fates-overwritten, roll relic overrides skip it; a repeating die can't
  be Nudged/Set (its crusted face IS the result — engine guard runs before Set).
- Items: Cryo Gel / Cryo Web → `anyDieFreeze` (`target: "any"`, `repeats` key);
  new PHASE_ITEM_PICK_ANY flow in battle_scene (both rails legal); Deep Zero Pin
  stays all-enemy with `repeats`. `battle_engine.item_freeze_die` handles either
  side; `enemyDieFreeze` effect type deleted.
- Sim: policy_l1 freezes the ENEMY with the lowest revealed die (items AND
  freeze-band ability targeting), never allied dice; skips already-frozen dice.
- HP preview: frozen units flow through `compute_preview_for_unit` on their
  locked effective roll (blastAll/heal/shield projections included); enemy-side
  frozen effective rolls now share the same guard (`build_effective_rolls` uses
  `effective_enemy_roll`).
- Text sweep: keywords.data.json freeze def + syntax `freeze (repeat N)`, all 12
  eff strings (heroes+enemies), item descs, Avalanche pickerBlurb, Deep Freeze
  directive desc, inspect popup line, audit_eff_text.py generator; Shatter Lance
  "+6 vs frozen" untouched. GROUND_TRUTH.md §7 bank/thaw paragraph explicitly
  superseded in place. No "reveal skip"/lockout/bank/thaw text remains outside
  the lineage record.

### B — INSTANCE TIMERS (done)
- `roll_buff_stacks` / `burn_stacks` per state; effective value = sum of live
  stacks; derived `roll_buff` / `burn` / `burn_turns` caches keep the one-chip
  display (summed value, longest clock). Enemy erb refresh-to-max special case
  deleted (resolves DECISIONS #3); hero/enemy paths identical.
- Contract implemented per the required test: a roll-buff instance loses a turn
  at EVERY round-end tick (cast round included) — required case passes:
  +3/2t @t1, +5/2t @t2 → totals 3 / **8** / **5** / **0**.
- Burn audit verdict: burns REFRESHED before (summed value, `max()` timer) —
  fixed to independent instances; per-stack skip-first-tick timing preserved
  (an Nt burn still deals N ticks over the N following rounds). Proven by test:
  4/3t + 2/1t same round → ticks 0, 6, 4, 4, 0.

### C — PERMANENT-BURN DETONATE (done)
- Permanent stack (turns ≥ `PERMANENT_BURN_TURNS` 9999, plagueProtocol) adds
  exactly ONE tick (its amount) to the burst and is NOT consumed; finite stacks
  keep amount × remaining turns and are consumed. `DETONATE_MAX_TURNS` removed.
  Payload Fuse +50% applies to the whole burst. New public
  `get_expected_detonate_burst()` single-sources the live Detonate pip
  (battle_card_view no longer computes its own burst).

### Docs / closeout
- TRUTH.md: rule 7 rewritten (repeat), new rule 10 (instance timers), eff syntax
  + adjudication row + Detonate keyword row updated; DECISIONS #1/#3/#4 marked
  RESOLVED and moved to **docs/DECISIONS_RESOLVED.md** (with the full
  bank/thaw → lockout → repeat lineage under #1).

---

## Verification (post-change)

| Gate | Result |
|---|---|
| validate-data | PASS |
| AbilityAuditRunner | **PASS — 224 passed, 0 failed** (suite rewritten for repeat semantics; +10 new checks: jam/rewrite/hijack immunity both directions, chained freeze, lowest-die enemy AI pick, ally freezeAnyDice repeat, required buff-instance case, burn instance clocks, permanent/mixed detonate) |
| freeze_engine_regression | PASS (rewritten: act R1 → repeat same damage R2 → thaw R3, override holds the face) |
| flow_smoke_test | PASS |
| tutorial_smoke_test | PASS (21 steps) |
| run_smoke_test | PASS (full run, b10) |
| DiceTrayPhysicsProbe | PASS (0 penetrations/flyovers, frozen drift 0.0000) |
| ci_smoke vs baseline.json | **FAILS BY DESIGN — see ±10 report below. baseline.json NOT updated.** |

## ±10 CEREMONY — per-operation deltas vs the step-0 snapshot (NOT self-approved)

Pinned config (l1 / seed 900000 / 300 runs), measured BEFORE any baseline update:

| Metric | step-0 | post-change | delta |
|---|---|---|---|
| overall | 0.5300 | 0.2533 | **−27.7 pts** |
| facility | 0.7746 | 0.5493 | **−22.5** ⚠ beyond ±10 |
| hive | 0.2034 | 0.0678 | **−13.6** ⚠ |
| stellarMenagerie | 0.3958 | 0.0208 | **−37.5** ⚠ |
| veil | 0.5231 | 0.2308 | **−29.2** ⚠ |
| voidCirclet | 0.6842 | 0.2982 | **−38.6** ⚠ |

Per-hero: avalanche 0.798 → **0.132 (−66.7)** — the dominant driver; every other
hero −16..−26 (squads containing Avalanche drag their rates).

**Read of the cause (semantic, not a bug):** under lockout, every Avalanche
freeze CANCELLED an enemy action; under repeat, freezing a random enemy face is
roughly EV-neutral (repeat ≈ reroll distribution-wise) — Avalanche's control
budget evaporates, and the GLACIER path (freeze-heavy) with it. The engine-level
repeat behavior itself is verified correct by the rewritten regressions (enemy
repeats the SAME damage on the repeat, then thaws). The l1 policy was taught the
new play (freeze the enemy's lowest revealed die, incl. retargeting freeze-band
abilities); it claws back little — value-freeze is a precision tool the greedy
policy can't fully exploit (it can't bank ally crits, the strongest new line).
Content lift corroborates: hero__avalanche +1.97 → −1.15; consumable__cryo_web
0.0 → +0.56 (lowest-die enemy freeze is now a genuinely good item).

**Flagged design casualties of the instance-timer contract (data untouched —
balance calls are Kev's):**
- `erbT: 1` (2 enemy abilities) and Emergency Signal (`lowHpSquadRollBuff`, 1t):
  a 1-turn buff cast mid-round now expires at that round's tick without shaping
  any roll. If they should still matter, bump to 2t.
- All mid-round Nt buffs (hero rfm allies / enemy erb) now shape N−1 rolls
  (the cast round consumes a tick). Pre-roll item buffs shape N rolls, as the
  required test specifies.
- Enemy erb steady-state is SUM of live instances (Synod chains can stack +2+2)
  but each expires on its own clock — net effect visible in voidCirclet's delta
  alongside the freeze change; interacts with the open Synod compensation pass
  (DECISIONS #17).

**Baseline decision needed from Kev:** accept the new balance reality and
re-tune (Avalanche/GLACIER kit, freeze rider numbers, op difficulty), then
`python scripts/sim/ci_smoke.py --update-baseline` — or direct a compensation
pass first. Until then ci_smoke reports the regression by design.

---

## Successor kit (same session, follow-up commit)

Durable context + enforcement so future sessions inherit this project's judgment:
- **docs/INVARIANTS.md** — 12 WHY rules with rationale + "violation looks like"
  (determinism fence, ai_type split, keyword budgets, complexity budget SPENT,
  legibility precedents, legible enemy AI, UI doctrine, balance-together, baseline
  ceremony, doc supremacy, frozen legacy ids, one-manual-pick). ~110 lines.
- **docs/DECISIONS_RESOLVED.md** — expanded to all 17 adjudicated items: #1/#3/#4
  RESOLVED & IMPLEMENTED (this batch), K1–K5 shipped adjudications (cloak 2
  clauses, pierce+breach distinct, taunt unified, jam cap 10, ECS rejected), #17
  (Synod 68% accepted, pass owed), and #2/#5–#16 pre-entered as **RULED —
  IMPLEMENTATION PENDING with ruling text awaiting transcription** — the
  implementing session must paste Kev's ruling into the entry BEFORE coding, so
  rulings live in the repo, not a chat log. (Their text was not in this repo or
  this session's context; transcription is deliberately step 0 of that batch.)
- **Enforcement:** `scripts/verify_gate.py` (full gate + per-op delta table;
  `/verify` command in `.claude/commands/verify.md`); git hooks via
  `core.hooksPath scripts/hooks` — `commit-msg` aborts baseline.json commits with
  per-op drift beyond ±10 pts unless the message contains
  `BASELINE-APPROVED-BY-KEV` (tested both directions); `pre-commit` warns (never
  blocks) when battle_scene.gd grows past 3378 lines, citing the architecture
  review.
- **docs/TASK_TEMPLATE.md** — the task skeleton (read TRUTH→INVARIANTS→
  DECISIONS_RESOLVED / explicit constraints by invariant number / verify block /
  report deltas BEFORE baseline update / TRUTH.md in the same commit) + a filled
  real example (the Detonate ruling).
- Pointers wired: root CLAUDE.md, docs/CLAUDE.md, AGENTS.md, TRUTH.md living-docs
  line all direct every session to INVARIANTS.md immediately after TRUTH.md.

---

## Baseline ceremony CLOSED (cleanup batch, per Kev — BASELINE-APPROVED-BY-KEV)

`baseline.json` re-accepted against the post-repeat tree (overall 0.2533;
facility 0.5493 / hive 0.0678 / sM 0.0208 / veil 0.2308 / vC 0.2982). Kev's
annotation, verbatim: "Post repeat-freeze checkpoint, pre repricing. Avalanche
figure known biased low: L1 cannot yet play ally crit banking.
DECISIONS_RESOLVED #17 Synod compensation note is void; #6 through #10 deferred
balance numbers re anchor to this checkpoint."

### Timer-contract corrections (cleanup step 4 — NOT tuning)
The two `erbT: 1` enemy abilities (Cover Field, Aegis Bash) and Emergency Signal
(`lowHpSquadRollBuff`) are corrected to 2t. These are contract repairs: under
the instance-timer ruling a 1t buff cast mid-round expires at that same round's
tick and never shapes a roll — the authored intent (buff one subsequent roll)
requires 2t under the new clock. Values chosen to restore the pre-ruling
effective behavior, no more. Measured effect: overall −0.7 (facility +1.4,
veil −4.6), within ci tolerance.

### Cleanup step 6 — re-measure vs the accepted checkpoint (NOT re-accepted)
Pinned config (l1/900000/300), after timer corrections + L1 crit banking:

| | checkpoint | now | delta |
|---|---|---|---|
| overall | 0.2533 | 0.2867 | **+3.3** |
| facility | 0.5493 | 0.5915 | +4.2 |
| hive | 0.0678 | 0.0678 | +0.0 |
| stellarMenagerie | 0.0208 | 0.0625 | +4.2 |
| veil | 0.2308 | 0.2154 | −1.5 |
| voidCirclet | 0.2982 | 0.4035 | **+10.5 ⚠ beyond ±10** |

Per-hero: avalanche 0.132→0.237 (**+10.5** — the crit-banking recovery the
checkpoint annotation predicted), pulse +5.6, ghost +4.8, shield +4.7, combat
+3.4, medic +1.9, engineer −0.9, breaker −3.5. Baseline NOT re-accepted per the
cleanup order — voidCirclet's +10.5 crosses the ceremony line; Kev's call.

**Ceremony closed (crit-banking checkpoint, per Kev):** baseline re-accepted at
overall 0.2867 with the annotation, verbatim: "Post crit-banking checkpoint.
voidCirclet +10.5 is mechanically coherent: frozen dice are immune to Rewrite
and Hijack, so ally banking directly counters ROOT HIEROPHANT's Root Access
standing rule; the bot found the boss tech. Avalanche at 23.7% remains the known
repricing target; no ability numbers move until that ruling. All deferred
balance numbers re anchor to this checkpoint."

**WATCH ITEM (per Kev):** Breaker −3.5 per-hero delta — suspected policy
reallocation artifact from crit banking (freeze-any turns that used to serve
Breaker-adjacent control lines now bank ally crits); re-evaluate across the
next TWO measurements before treating it as a game problem. *(Measurement 1 of
2: the extraction gates re-ran the pinned sim twice at +0.0 drift — Breaker
unchanged at 0.2522, artifact hypothesis neither confirmed nor refuted; next
real balance measurement is the tiebreaker.)*

---

## battle_scene extraction (architecture review §1 recs 1+2 — behavior-preserving)

Two commits, full gate + tutorial 21/21 + primer smoke green after EACH, sim
drift +0.0 both times:
- **ProtocolActions** (`scripts/battle/protocol_actions.gd`, 971 lines): footer
  spend buttons, costs/legality, all pick-a-die sub-phases (reroll/nudge/set/
  twin picks, item overlay, Set-value popup) behind a narrow interface;
  battle_scene 3416 → 2569. Spotlight/primer footer resolvers + tutorial smoke
  re-pointed at the module.
- **Phase enum**: 13-state `Phase` enum, `PHASE_NAMES` preserving the pre-enum
  strings for tutorial payloads/tests, and ONE `transition()` choke point (the
  only assignment to `turn_phase` in the game). battle_scene lands at 2610;
  watermark LOWERED 3416 → 2610, no headroom (free per INVARIANTS #13).

---

## Battle-5 "INTERCEPT: RELIC CACHE" soft lock (diagnosed + fixed)

Root cause **(c) empty payload**: two `relics.is_empty()` guards
(`_roll_reward_item_ids`, `_pick_random_item_id`) predate the pkg5 Starting
Directive — a run opening with a boss relic rolled ZERO relic options at battle
5 while the title and claim paths (which had the correct accounting) rendered a
dead picker. (a) collision disproved: BEAT_GAPS excludes 5; 1000-seed sweep, 0
hits. (b) disproved: "RELIC CACHE" is reward_screen's own event chrome, not a
card lookup. Fix: `GameState.drafted_relic_count()` unifies roll/pick/claim/
title (Starting Directive never consumes the slot; owned relics excluded from
the offer). Universal guard: `ChoiceScreenGuard` in reward / intercept /
route-fork / evolution — zero built options asserts in debug and auto-resolves
a logged default in release (permanent fixture, TRUTH §Run structure). Three
relic-cache regressions pin the repro (seed 424242 + salvageRig) and the
beat-gap exclusion.

**Collateral find:** the Job-2a extraction had silently cost 6 audit recordings
(bare-scene audit tests calling moved cost/copy methods → runtime error →
function abort). Repaired (tests build ProtocolActions directly; audit back to
227/0) and made structurally impossible to miss again: verify_gate enforces
`AUDIT_MIN_PASSED = 227` (a FLOOR — lowering needs the KEV token; the threshold
guard is now polarity-aware). INVARIANTS #13 records the second precedent.

### Cleanup step 7 — hive HP sweep rerun (fixed policy)
docs/sweeps/2026-07-06_hive_hp_postcleanup.md: hive enters the 25–40% band at
**enemy_hp_scalar ≈ 0.75–0.78** (30.5% / 28.8%); 0.70/0.72 plateau overshoots
at 52.5%, 0.8 undershoots at 18.6%. One non-reproducing worker flake in the
first refinement attempt (identical seeds re-ran 300/300 clean twice;
determinism matrix byte-identical) — environmental, logged here for the record.
