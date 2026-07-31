# Balance snapshot — July 2026 (shipped demo build; report only, no changes)

## Facility light-hybrid pass — 2026-07-30

This pass raises only the seven non-boss Facility unit HP values (Scrap 35→40,
Rust 40→45, Static 35→40, Patrol 55→60, Guard 65→70, Volt 70→75, Warden
105→110) and every positive direct `dmg` value in their seven ability families
by exactly one. Player-facing `eff` text was updated in lockstep. SCRAPMASTER,
dice ranges, targeting/AI, status fields, shields, heals, burns, jam, and every
non-Facility operation are unchanged. Results must be read against the same
L1/300/seed-base-900000 baseline below; the deterministic tutorial now uses the
new real Scrap 40 HP and Stab 8 checkpoint. This is a single diagnostic pass,
not authorization for follow-up tuning.

*Captured 2026-07-30 at `dcc0dd5` (0.9.x demo build, post-demo2). This
snapshot ships no balance changes and does not re-pin the baseline — the
pre-demo sim freeze stands. Ruling reference:
`scripts/sim/acknowledged_drift.json` (Kev 2026-07-30). Sim artifacts under
`results/snap_*` (gitignored); everything below reproduces exactly (see
Appendix).*

---

## How these numbers were made (read this first if you've never seen the harness)

The balance sim runs the **real shipped combat engine** (`combat_manager.gd` +
`battle_engine.gd`) headless — never a reimplementation, so what it measures is
what the game does. A "run" is a full 10-battle operation attempt: squad of 3,
drafts, evolutions, beats, boss. Everything is **seeded and deterministic**:
the same seed and configuration always produce byte-identical results, which
is what makes exact drift auditing possible.

Play skill is modeled by three scripted policies:

| Tier | What it is | Read it as |
|---|---|---|
| **L0** | random legal choices | the floor — a player pressing buttons |
| **L1** | greedy heuristic (focus fire, band-aware spends, triage items) | a competent player; **the workhorse tier — all "current state" numbers below are L1 unless labeled** |
| **L2** | exact per-round solver (searches order × targets × spends) | near-optimal play; the skill ceiling proxy |

Design target (INVARIANTS #8, used throughout the balance cycles): each
operation's **skilled full-clear rate lands in the 25–40% band**; `l1` is the
mid-skill proxy, tuned for relative comparison rather than absolute rates.
Facility, the first operation, deliberately sits above the band.

Batches in this snapshot (all at HEAD, full item pools pinned, 0 failed runs):

- **Drift audit:** the pinned CI configuration (300 runs, L1, seed base
  900000 — the `ci_smoke.py` config) at HEAD and at four historical commits
  via git worktrees.
- **Current state:** 2000 L1 runs, 600 L0 runs, 300 L2 runs — uniform random
  squads and operations, matched seed base 100000.

Per-op sample sizes: ~400/op in the 2000-run L1 batch (±5pp at 95% conf), but
only ~60/op in any 300-run batch (±12pp). The pinned-config numbers exist for
**exact** gate comparison; the 2000-run numbers are the better *estimates* and
are what Part 2 reports.

---

## Part 1 — Does the shipped build still match the pinned baseline?

**Combat math integrity: CONFIRMED. Drift: REAL, +4.3pp overall at the pinned
config, fully attributed to two Kev-approved balance commits that landed after
the last baseline pin. No unintended combat change exists in the build.**

### The audit

The pinned baseline ("Baseline v4", commit `e4ab5f9`, Cycle-4 closeout,
BASELINE-APPROVED-BY-KEV) was re-run in a worktree at its own commit: it
reproduces `scripts/sim/baseline.json` **exactly — every op, hero, and
content-lift figure to all four decimals**. The harness is sound; whatever
moved, moved because the game changed.

Walking the pinned config forward commit by commit:

| Point (chronological) | overall | facility | hive | veil | voidCirclet | accretion |
|---|--:|--:|--:|--:|--:|--:|
| Baseline v4 pin `e4ab5f9` | .3200 | .6338 | .1864 | .3077 | .2456 | .1250 |
| + R5: deep_zero_pin rare→uncommon `e21aba0` | .3567 | .5915 | .3220 | .2923 | .2807 | .2292 |
| + Build I kit surgery (Shield/Medic/Combat + cleanse) `b8abd79` | .3633 | .6338 | .2881 | .4000 | .2281 | .1667 |
| + pure-mark targeting fix `57afaec` | .3633 | .6338 | .2881 | .4000 | .2281 | .1667 |
| **HEAD `dcc0dd5` (incl. cast order)** | **.3633** | .6338 | **.2881** | .4000 | .2281 | .1667 |

- **The entire drift comes from two approved balance commits**: the R5 rarity
  demotion and Build I kit surgery. Both were Kev-ruled; neither was followed
  by a baseline re-pin (correctly — the freeze was already in effect).
- **The two combat-code commits after Build I are provably inert.** The
  pure-mark targeting fix produced byte-identical telemetry. Player-chosen
  cast order changed telemetry bytes only (it records the cast order now);
  battle outcomes were compared for **all 300 seeds: zero differences**.
- Nothing after cast order touches combat. The 2026-07-30 feedback-feature
  session was separately proven drift-neutral by a stash-and-rerun at clean
  HEAD (identical numbers with and without the feature diff). The UI/web/audio
  work is fenced off exactly as intended.

Largest per-hero moves across the same walk: medic +12.4pp, ghost +9.7,
combat +9.4, shield +5.6; the rest within ±2.

### The "hive +10.2" ceremony warning, explained

The gate's warning is the HEAD row vs the v4 row: hive .1864 → .2881 = +10.2pp,
just over the ±10 ceremony line. It is **not** a bug and **not** noise in the
usual sense — same seeds, changed game. But be careful reading the per-op sizes:

- At the pinned config there are only **~60 runs per operation**, and a pool-
  composition change (R5 moved one item between rarity tiers) **reshuffles
  every seeded draft that follows** — a butterfly effect, not a causal item
  effect. That's how a "one-item data edit" shows up as hive +13.6 /
  accretion +10.4 in the walk above.
- The honest causal estimates were made at the time with matched-seed
  controls: Build I's closeout measured **+0.6..+2.8pp uniform** drift from
  the kit changes (TRUTH, Build I record). The 2000-run batch below is the
  authoritative current-state read.
- Direction is favorable: the drift moves hive **toward** the healthy band
  from its old 8.5% problem state.

**Ruling (Kev 2026-07-30):** acknowledged, do not chase. The sim freeze
stands: no balance changes and no baseline re-pin before the public demo.
**Baseline re-pin is the first task of the next balance cycle**
(TASK_MASTER_LIST `BAL-001`).

Mechanics of the acknowledgment: `verify_gate.py` silences the ceremony
warning only while the deterministic metrics exactly match
`scripts/sim/acknowledged_drift.json`; any further movement re-raises the full
warning. `ci_smoke.py` standalone still diffs against the pinned baseline and
stays red on purpose — the pin itself is unchanged.

### About the baseline numbers you may have in your head

The reference figures "overall 0.283 / facility 0.592 / veil 0.169 / hive
0.085" are a **mixture of older pins** (facility 0.592 is the crit-banking-era
number; hive 0.085 is the pre-Cycle-1 problem state; veil 0.169 is
pre-Cycle-4). The actual last approved pin (v4) is overall 0.320 / facility
0.634 / hive 0.186 / veil 0.308 / voidCirclet 0.246 / accretion 0.125.
Everything between those old figures and v4 was approved cycle work (Cycle-1
hive bake, Cycle-3 reprices, Cycle-4 veil/Tyrant bakes) — not drift.

---

## Part 2 — Current state (the readout for design review)

### Operations, by skill tier

| Operation | L0 floor | **L1 (n≈400/op)** | L2 ceiling | L1→L2 skill gap | vs 25–40 band |
|---|--:|--:|--:|--:|---|
| facility | 13.1% | **56.6%** | 72.3% | +15.7 | above (by design, op 1) |
| veil | 3.2% | **33.5%** | 45.8% | +12.3 | **in band** |
| hive | 6.2% | **29.7%** | 46.3% | +16.6 | **in band** |
| voidCirclet | 8.7% | **28.2%** | 46.4% | +18.2 | **in band** |
| stellarMenagerie | 2.5% | **19.4%** | 22.4% | **+3.0** | **below band, skill-flat** |

Overall: L0 6.7% → L1 33.1% → L2 45.7%. Three of five operations sit inside
the target band — the best shape this project has measured. **The Accretion
(stellarMenagerie) is the outlier**: hard at L1, and near-optimal play only
buys +3pp — the "hard AND skill-flat" signature that motivated the Hive and
Veil interventions in earlier cycles now belongs to Accretion alone.

(The pinned-config per-op table differs slightly — e.g. veil 40.0% there vs
33.5% here — that's the n≈60 vs n≈400 sampling difference; trust this table
for estimates.)

### Encounters (L1): where runs actually die

Deaths by battle index, as a share of runs entering that battle:

| Op | b1–b2 | b3 | b4 | b5 | b6 | b7 | b8 | b9 | **b10 boss** | boss's share of all deaths |
|---|--:|--:|--:|--:|--:|--:|--:|--:|--:|--:|
| facility | 0% | 0.8% | 4.8% | 1.7% | 0% | 0% | 0.6% | 2.0% | **37.4%** | 78% |
| hive | 0% | 1.8% | 3.9% | 3.0% | 0.3% | 0% | 0.6% | 3.6% | **66.1%** | 82% |
| veil | 0% | 2.8% | **16.8%** | 5.3% | 0.7% | 6.0% | 4.6% | 7.4% | **47.0%** | 45% |
| voidCirclet | 0% | 2.3% | 1.4% | 2.6% | 0.2% | 0.2% | 2.2% | 2.8% | **68.2%** | 84% |
| stellarMenagerie | 0% | 2.5% | 1.0% | 1.6% | 0.5% | 0% | 1.1% | 4.9% | **78.2%** | 86% |

- **Battles 1–2 are a 0% death zone everywhere** — the early runway is safe.
- **Bosses are the game.** Boss clear given reaching b10: SCRAPMASTER 63%,
  Hive Matriarch 34%, CONCLAVE OVERSEER 53%, ROOT HIEROPHANT 32%,
  **MANTLE TYRANT 22%** — the Tyrant remains the hardest wall by a wide margin
  (Cycle-4's finding, unchanged), and it deals 236 damage per appearance, the
  highest of any enemy (next: Hierophant 207).
- **Veil is the one operation with a meaningful mid-run**: its b4 comp kills
  16.8% of entrants (24% of all veil deaths — the known comp-shaped
  observation from Cycle-4, still standing) and it keeps a 4–7% attrition tax
  through b7–b9. Its boss owns only 45% of deaths — every other op is
  80%-boss-shaped.
- **Veil boss fights are long**: 20.6 mean rounds at L1 (next longest:
  Accretion 16.6). Overseer fights are stall-shaped — win or lose, they grind.

### Heroes, by skill tier (clear rate when in squad; uniform random squads)

| Hero | L0 | **L1** | L2 | Notes |
|---|--:|--:|--:|---|
| ghost (Ghost Operative) | 7.9% | **40.9%** | 59.8% | top at L1 AND L2, despite the Cycle-3 flat tax |
| combat (Strike Unit) | 8.4% | **35.5%** | 49.6% | Build I trim moved it little (as the closeout scored) |
| pulse (Pulse Tech) | 6.9% | **34.6%** | 48.2% | |
| breaker (Signal Breaker) | 8.3% | **34.1%** | 47.3% | |
| engineer (Field Engineer) | 6.7% | **32.3%** | 43.5% | |
| medic (Splice Medic) | 5.8% | **32.0%** | 47.0% | biggest Build-I beneficiary (was 24.8% at v4); larger L2 lift than most |
| avalanche (Avalanche Suit) | 5.4% | **30.9%** | 34.7% | **smallest skill lift (+3.8)** — kit is skill-flat |
| shield (Spike Guard) | 3.8% | **24.7%** | 34.6% | **last at every tier**, Build I notwithstanding |

Spread at L1 is 16pp (ghost 41 / shield 25). Shield's Build I surgery was
already scored a MISS (backward, −8.3 in the matched re-measure) — this
snapshot confirms the ranking didn't change. Avalanche's near-zero L1→L2 gap
is new information: even optimal play can't express its kit much.

### Items and relics (2000-run L1 batch; usage is L1's deterministic policy, not player behavior)

**Draft behavior:** gear is near-auto-picked when offered (~87–91% pick share:
warframe_core, predator_lens, band_compressor, sync_antenna, killswitch_relay,
overkill_matrix…). Common consumables sit at ~12% pick share — offered
constantly, picked when nothing better shows. Consumables ARE used in battle
(~2.4 item casts/run; top users: entropy_seed, cryo_web, core_surge,
mainline_cache).

**Content lift** (ridge-logistic screen over 2000 runs, log-odds of full clear
with op controls; ⚠ = bootstrap 95% CI excludes zero — treat the rest as
screening signal, not proof):

Overtuned tail (top 5):

| Content | Lift | Support | Note |
|---|--:|--:|---|
| relic openingGambit ⚠ | +0.95 | 48 runs | small sample, wide CI [+0.29, +1.77] |
| gear dead_mans_chip ⚠ | +0.94 | 335 runs | the strongest well-supported item in the game |
| relic naniteField ⚠ | +0.80 | 74 runs | |
| relic entropyLeak ⚠ | +0.78 | 57 runs | |
| relic gravityWell ⚠ | +0.76 | 63 runs | |

(Right behind: overkill_matrix +0.75, echo_matrix +0.72, warframe_core +0.68 —
all ⚠, all 275+ runs. The overtuned tail is deep and gear-heavy.)

Undertuned tail (top 5):

| Content | Lift | Support | Note |
|---|--:|--:|---|
| relic protocolOverride ⚠ | −0.62 | 54 runs | the only significantly NEGATIVE item |
| relic salvageDirective | −0.38 | | |
| relic overflowVent | −0.37 | | |
| relic curatedCache | −0.26 | | the known corpse relic (Cycle-4 ruling: stays as-is) |
| consumable deep_zero_pin | −0.08 | | post-R5; ~neutral now |
| *(hero shield ⚠ −0.56 belongs in this tail but is covered above)* | | | |

**Pattern worth naming: the protocol-economy relic family is uniformly
negative** (protocolOverride, salvageDirective, overflowVent). Every
significantly positive relic is a battle-start or passive-value effect.

(The compact lift figures previously quoted from the 300-run CI batch —
entropy_seed +0.67, protocol_cell −0.71, etc. — are the same screen at ~15%
of the sample; the n=2000 fit above supersedes them.)

### Protocol economy (L1)

50 spends per run on average: Nudge 87.9%, Reroll 11.9%, Item ~5%, **Set
0.2%**. Spend-total correlates +0.115 with winning. Caveat for the design
review: L1's heuristic loves Nudge and basically never Sets (L2 Sets 7.5% and
never Rerolls) — read the Nudge/Set split as policy artifact, not player
preference.

### Keywords (realized value per trigger, L1)

Mark is the highest-value common keyword (14.8 dmg/trigger, 9k triggers —
Build I made it the Strike Unit's identity and it delivers). Freeze averages
9.6/trigger across 38.6k triggers. Hijack is rare but brutal (15.9/trigger —
enemy-side). Siphon is the weakest per-trigger effect (2.0).

---

## Part 3 — Top-5 outliers, both directions (the short list for review)

**Overtuned (watch for nerf candidates next cycle):**
1. **dead_mans_chip** (gear) — +0.94 lift at 335 runs; strongest supported item.
2. **openingGambit / naniteField / entropyLeak / gravityWell** (relics) —
   +0.76..+0.95, all significant; the relic pool's top tier is far above its
   median.
3. **Gear as a class** — eight gear pieces sit at +0.56..+0.94 with tight CIs;
   drafting gear is close to strictly correct at L1.
4. **ghost** (hero) — top clear rate at both L1 and L2 despite the Cycle-3 tax.
5. **facility→boss runway** — 0% deaths b1–b2, ≤5% everywhere pre-boss; the
   first nine battles of most ops filter almost nobody (whether that's a
   problem is a design question, not a balance one).

**Undertuned:**
1. **shield / Spike Guard** (hero) — last at every tier; −0.56 significant
   lift; Build I scored backward. The standing worst unit in the game.
2. **stellarMenagerie / MANTLE TYRANT** — 19.4% L1 (below band), +3.0 skill
   gap (skill-flat), boss kills 78% of arrivals, 86% of op deaths.
3. **protocolOverride** (relic) — only significantly negative item.
4. **avalanche** (hero) — 30.9% L1 with the smallest L1→L2 lift (+3.8); the
   kit doesn't reward better play.
5. **Common consumable shelf** (buckler_array, scrap_plate, patch_kit,
   triage_broadcast, protocol_cell…) — ~12% pick share, ~0 lift; live but
   inert.

---

## Part 4 — What would surprise Kev (vs the numbers he quoted)

1. **The quoted baseline is three pins out of date.** Vs the actual approved
   v4 pin the current build is +4.3pp overall — and vs the quoted old figures
   the apparent jumps (hive 8.5%→29.7%, veil 16.9%→33.5%) are almost entirely
   *approved cycle work*, not drift.
2. **There is no unintended combat drift. Zero.** The v4 pin reproduces
   byte-exactly; the mark fix is byte-inert; cast order is outcome-inert
   across all 300 audit seeds. The ceremony warning traces 100% to the
   R5 + Build I approved commits.
3. **Half the pinned-config drift arrived via the "one-item data edit"** (R5)
   — not because deep_zero_pin matters (its lift is ~0), but because a rarity
   change reshuffles every seeded draft after it, and per-op n≈60 amplifies
   that into ±10pp swings. Worth remembering every time the gate's per-op
   deltas get read as causal.
4. **Three of five ops are in the target band** — the healthiest shape yet
   measured. The map has one red zone left: Accretion (below band, skill-flat,
   86% boss-shaped).
5. **Shield is still last at every tier after its surgery**, and **avalanche
   barely rewards skill** — the two defense-category heroes are the bottom
   two, which reads as a category problem, not two kit problems.
6. **Veil kept its b4 spike** (16.8% of entrants die there — the known
   comp-shaped observation) and its boss fights run 20+ rounds — in-band on
   clear rate, but the *texture* is grind-shaped.
7. **The relic pool is barbelled**: four relics carry significant positive
   lift, the protocol-economy family is uniformly negative, and curatedCache
   remains a ruled corpse. Gear, by contrast, is almost uniformly good.

---

## Appendix — reproduction

```
# drift audit (pinned CI config, exact)
python scripts/sim/batch.py --name snap_ci_head --runs 300 --policy l1 --seed-base 900000
python scripts/sim/analyze.py results/snap_ci_head --metrics   # diff vs scripts/sim/baseline.json

# snapshot batches
python scripts/sim/batch.py --name snap_l1 --runs 2000 --policy l1 --seed-base 100000
python scripts/sim/batch.py --name snap_l0 --runs 600  --policy l0 --seed-base 100000
python scripts/sim/batch.py --name snap_l2 --runs 300  --policy l2 --seed-base 100000
python scripts/sim/analyze.py results/snap_l1 -o results/snap_l1_report.md
python scripts/sim/analyze.py --skillband results/snap_l1 results/snap_l2
```

Historical points were run in git worktrees at `e4ab5f9` (v4 pin), `e21aba0`
(R5), `b8abd79` (Build I), `57afaec` (mark fix) with the same pinned config.
Everything is deterministic: these commands reproduce this report's numbers
exactly. Caveats to keep attached to any conclusion drawn here: L1/L2 are
scripted policies (drafting preferences and spend habits are theirs, not
players'); content lift is an observational screen (Stage-2 matched-seed arms
are the causal instrument); per-op numbers from 300-run batches carry ±12pp.
