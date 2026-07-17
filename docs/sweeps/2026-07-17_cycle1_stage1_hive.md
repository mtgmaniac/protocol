# Balance Cycle 1 — Stage 1 report (Fix Hive)

*2026-07-17. MEASUREMENT ONLY — zero game-data changes. All arms n=1000, L1
unless stated, seed-base 220000 (= Cycle-0 `baseline_v2_hive`, so every arm is
matched-seed against the v2 baseline and each other). Results tree:
`results/cycle1/`.*

## Phase 0 — Null Synod attribution (blocking, resolved)

Pre-fix scorer re-run on voidCirclet, same 1000 seeds as `baseline_v2_voidCirclet`:
**pre-fix 27.1% vs post-fix 27.4% (+0.3pp, 137/1000 seeds diverge)**. The entire
divergence is two cards:

| Card | Flip | Seeds | Outcome delta | Sign verdict |
|---|---|--:|--:|---|
| CRYO POD | ch0→ch1 (declines +10maxHP & BLACKOUT for a common consumable) | 74 | **+6 wins** | `armModifier −1` correct — outcomes improved |
| OVERLOAD RITES | ch1→ch0 (undergoes −12maxHP / 20s-resolve-twice) | 63 | −3 wins | face-value tie, defensible; inside noise |

**Verdict: the intercept-scorer fix explains ~none of the −19.3pp pinned-config
drift on Synod.** That drift is game-build drift since the post-Batch-1 baseline
re-pin (chief suspect: taunt G-4 — TRUTH's own stale-arms note flagged the
Synod-relevant taunt arms) plus small-sample noise (n≈57/op, ±13pp). The
Cycle-0 report's attribution of the drift to the fix is corrected. **Baseline
v2 locks for real.**

## Stage 1 — the sweep

| enemy_hp_scalar@hive | Win rate (L1) |
|--:|--:|
| 1.00 (baseline) | 3.5% |
| 0.81 | 18.6% |
| 0.78 | 23.7% |
| 0.75 | **30.2%** |
| 0.72 | 33.3% |

**Attack probe:** `enemy_dmg_scalar@hive=0.85` → 10.4% (+6.9pp for a −15% cut)
vs HP's +15.1pp for a −19% cut — **HP is ≈1.7× more efficient per percent.
Hive's problem is enemy durability, not incoming damage**: long battles expose
the squad to stacked burn DoTs and lifesteal sustain; cutting HP shortens the
exposure window. HP stays the single dial (no combinatorial sweep without a
ruling).

## The killer interaction (named)

**Double Spine Stalker, a structural degeneracy.** Hive's elite pool contains
exactly ONE enemy (Spine Stalker, 65hp smart; Skitterling/Bloodmite are dumb →
fodder, Broodwarden/Spewer ≥90hp → heavy). `heavyOrElites` at b4 rolls "two
elites" 50% of the time, and the no-repeat pool pick falls back to the full
pool when exhausted (`GameState._pick_from_role_pool`) — so "two elites" is
ALWAYS the same Stalker twice (456/1000 runs at b4, 37% defeat rate vs ≤12%
for every other comp). Two smart focus-firing attackers × 12–16 dmg + two
independent stacking burn engines (up to 7 burn/turn, 3–5t) + spike-4 shield
turns punishing focus fire + 45% lifesteal — at battle-4 squad power, one
battle BEFORE the b5 relic cache. The b3 double-Stalker tail (24 runs) is the
`elitePresence` route modifier hitting the same one-elite pool; route modifiers
are out of scope this cycle.

## Comp arms (scalar 1.0, isolated)

| Arm | b4 slots | Win rate | b3-4 defeat share | b4 deaths |
|---|---|--:|--:|--:|
| baseline | `heavyOrElites` | 3.5% | 29% | 187 |
| **compA** | `heavy, fodder` | 3.4% | 24% | — |
| compB | `elite, fodder, fodder` | 2.7% | **51%** | 378 |

compB **rejected** (three bodies out-damage even double-Stalker). compA holds
overall (at full difficulty, removing one wall just relocates deaths) — its
value shows at the combined point. **compA is the candidate.**

## Combined + L2 confirm

| Arm | L1 | b3-4 share | b10 share |
|---|--:|--:|--:|
| 0.78 × compA | 24.4% | 12% | 80% |
| **0.75 × compA** | **29.3%** | **12%** | 79% |

L2 on 0.75×compA: **51.5% — gap +22.2pp vs the baseline's +7.1pp. The gap
WIDENED 3×**: Hive is now winnable AND skill-expressive. Kill curve is
boss-shaped (Matriarch remains a real wall at 79% of defeats; b3-4 collapsed
to facility-normal 12%).

## Bake cascade found in Stage 1 (would have broken Stage 3)

`DataManager.HEAVY_HP_MIN = 90` classifies roles from DATA HP at load. Exact
0.75× would drop Broodwarden (115→86) and Caustic Spewer (90→68) below the
heavy line → **Hive's heavy pool empties and the comp system breaks** (the
audit's slot checks would also fail). Lowering the threshold instead
cross-contaminates Accretion (Pyroclast Raptor 86 would flip to heavy) —
violates the one-op constraint. **Resolution: floor both heavies at 90** (the
Spewer keeps full HP — already the easiest heavy at 0% defeat rate) and verify
by measurement. The verification arm (`hive_bakepreview`, literal values via
the new `--enemy-hp` bake-preview seam) lands at **29.3%** — identical to the
scalar arm; b3-4 share 13%, b10 77%.

## Riders

**Per-hero (Cycle-0 v2 telemetry, with vs without, n≈1850/hero):** combat
+6.7pp and ghost +6.0pp lead; **shield −9.4pp** (hive 0.6% vs 5.1% — taunting
into double-Stalker focus is suicide; veil 6.5% vs 19.3%); avalanche −5.8pp
(known repricing target) with a Synod inversion worth a Cycle-2 look (21.5%
vs 31.1% — freeze-banking used to counter Root Access). Evolution pick table
recorded (survival-confounded, labeled): Bulwark lowest at 22.0%, consistent
with shield.

**L2 bucket-0 (facility, n=1000 matched):** full 79.8% vs bucket-0 87.7% —
**the bucket-0 advantage survives optimal play at half size** (+7.9pp vs L1's
+17.0pp). Caveat: both tiers share the rarity-greedy DRAFT heuristic; fully
separating "late content weak" from "greedy drafting" needs a draft-aware tier.

**Relic recalibration (additive estimand, cache no longer suppressed):**
overcharge **+32.4pp**, ironCurtain **+31.0pp** (vs +26.6/+25.0 confounded).
The substitution confound was worth ≈−6pp — Cycle-0's dead-relic cluster at
−9pp is really ≈−3pp additive; curatedCache ≈−6pp.

## Stage 2 — proposed literal numbers (AWAITING KEV RULING)

Dial: **HP 0.75 @ hive** · Comp: **hive b4 `heavyOrElites` → `heavy, fodder`**.
Rounding rule: nearest integer; flag when rounding (or the classification
floor) moves the effective scalar >2% from 0.75.

| Enemy | HP now | Proposed | Effective scalar | Flag |
|---|--:|--:|--:|---|
| Skitterling | 40 | 30 | 0.750 | |
| Bloodmite | 35 | 26 | 0.743 | |
| Spine Stalker | 65 | 49 | 0.754 | |
| Broodwarden | 115 | 90 | 0.783 | ⚑ +4.3% — classification floor (HEAVY_HP_MIN 90) |
| Caustic Spewer | 90 | 90 | 1.000 | ⚑ uncut — already at the floor; already the easiest heavy (0% defeat) |
| Hive Matriarch | 180 | 135 | 0.750 | |

Attack values: **unchanged** (HP was the chosen dial). The exact table above
is measured at **29.3%** (`hive_bakepreview`) — the Stage-3 equivalence run
compares against this arm byte-for-byte on the same seeds.
