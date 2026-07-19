# Balance Cycle 4 — Era Refresh, Veil, Mantle Tyrant, Rarity Audit

*2026-07-19. All arms n=1000, matched seeds. Both bakes Kev-approved at the
R4 mid-cycle checkpoint; equivalence proofs exact. Results tree
`results/cycle4/`.*

## Item 1 — Era refresh (current build, matched v3 seeds)

| Op | L1 (v3) | L2 fresh | Gap | stale gap | b0 fresh | b0 delta | stale b0 |
|---|--:|--:|--:|--:|--:|--:|--:|
| Facility | 53.8% | 79.3% | +25.5 | +25.1 | 68.2% | +14.4 | +17.0 |
| Hive | 30.5% | 49.1% | **+18.6** | +7.1 | 38.8% | +8.3 | +4.6 |
| Veil | 14.3% | 21.0% | **+6.7** | +8.5 | 20.5% | +6.2 | +11.9 |
| Null Synod | 29.2% | 52.5% | +23.3 | +29.5 | 40.9% | +11.7 | +16.1 |
| Accretion | 11.3% | 20.3% | +9.0 | +10.3 | 20.2% | +8.9 | +10.7 |

Drift vs stale eras: **Hive's gap tripled** (the Cycle-1 fix made it
skill-expressive — confirmed); **Veil became the smallest gap** (14.3% AND
skill-flat — the Hive-class disease, motivating Item 2); Synod's gap narrowed
(the reprice trimmed L2-exploitable relics); **the bucket-0 advantage
attenuated everywhere but persists** (the nerfed superstars were bucket-0
relics; pool dilution remains a live finding).

## Item 2 — Veil to band (RULED 30–40 → baked at 0.85)

Diagnosis (the Hive method): HP +20.4pp vs attack +19.7pp at 0.85 — **levers
tied** (unlike Hive's 1.7× HP edge); HP picked on the cascade tiebreak. Kill
curve: **Overseer owns 30% of deaths — NOT boss-shaped, no STOP**; the b4
spike (26–28%) is reported as a comp-shaped observation for a future cycle
(same class as Hive's fixed b4). Curve: 0.90/26.7 · 0.88/28.5 · **0.85/34.7**
· 0.82/41.1. Literal table (nearest-integer; **Stormweaver floored at 90** —
0.85 would flip it below `HEAVY_HP_MIN` and gut the heavy pool to one member):
34/32/58/60/65/**90⚑**/100/153. **Baked: 33.3%** · equivalence **1000/1000
byte-identical**. HP-only → NK-17 cascades nowhere (verified).

## Item 3 — Mantle Tyrant (boss rule: ACCRETION every 2nd round)

Sweep: value 5 → 13.3% · value 4 → 14.3% · **cadence 2 → 16.3%** · 5×c2 →
17.5%. **Cadence beats value per point** and creates off-round burst windows.
**Metric finding:** the 70–75% death-share target is arithmetically
unreachable without flattening — Accretion's road kills too few runs, so
share stays ~82% for any real wall; the comparable metric is
clear-rate-of-runs-reaching-boss: **13% → 19%** (Hierophant 34%, Scrapmaster
62% — the Tyrant remains the hardest wall by a wide margin). RULED: cadence
2, value 6 kept. Briefing copy, TRUTH ruling, audit expectations (two mantle
regressions → ruled cadence; **audit 234/0, floor unchanged**) in the bake
commit. Equivalence **1000/1000 byte-identical** vs the approved arm.

## Item 4 — Rarity audit (curatedCache stays AS-IS per ruling)

Cross-table (C0 forced [2 eras stale] × C2 observational [1 era stale] ×
fresh C4 forced arms; full table in `2026-07-18_cycle2_content_observational
.csv` + `2026-07-17_cycle0_outlier_arms.csv`):

**Tier medians rank correctly in every era and method** (C2 obs: legendary
+9.4 > rare +3.7 > uncommon +2.3 > common −0.1; C0 forced agrees
directionally). **The mislabeling hypothesis is rejected at the tier level**
— the bucket-0 effect comes from uncommon+ staples, not secretly-strong
commons. curatedCache's penalty is therefore NOT mislabeling-driven.

Fresh forced arms (current era, n=1000, additive, vs matched control 29.4%):

| Item | Tier | C0 forced | C2 obs | **C4 fresh** | Verdict |
|---|---|--:|--:|--:|---|
| priming_charge | uncommon (gear) | −1.4 | +0.1 | **−2.7** | DEMOTION candidate |
| reverse_gimbal | uncommon (gear) | −1.4 | +1.0 | **−2.7** | DEMOTION candidate ⚑ DECISIONS #11 pending |
| deep_zero_pin | rare (consumable) | +0.8 | +1.0 | **−0.1** | DEMOTION candidate (rare at common level) |
| grounding_clip | common | +0.4 | −3.3 | **+0.0** | **CLEARED** — the obs number was selection bias (the Avalanche lesson, again) |

**R5 SHORTLIST (ruling point — no changes this cycle):** demote
priming_charge uncommon→common · reverse_gimbal uncommon→common (⚑ pending
UX ruling #11 — demoting a pending-ruling item may be premature) ·
deep_zero_pin rare→uncommon. **Promotions: none.**

**Cascade documentation per shortlisted item (what a ruling would touch):**
- *priming_charge / reverse_gimbal (uncommon→common):* reward-draft rarity
  odds rows; ALL-CAPS rarity metadata on reward rows; UNLOCK_BUCKETS.csv
  rarity column + pool-floor CSV pin (same commit); **curatedCache's "no
  commons" filter would newly EXCLUDE them** (its effective pool shrinks —
  a mild worsening of an already-corpse relic, worth weighing); bucket-0
  gear floors unaffected (totals unchanged, neither is rare+). Event gear
  drafts (rare+ pools) unaffected.
- *deep_zero_pin (rare→uncommon):* leaves the rare-consumable event-grant
  pools (memorialProtocol/ghostFrequency → harmonic_injector + core_surge
  remain, 2 members, no dead-screen); joins abandonedArmory's uncommon+
  draft pool; bucket-0 `consumable_rare_plus` sub-floor unaffected (it
  counts bucket 0 only; this is bucket 17); rarity metadata + CSV pin same
  commit; curatedCache unaffected.

## Combined final arm — cross-contamination + Baseline v4

| Op | v3 | final | delta | |
|---|--:|--:|--:|---|
| Facility | 53.8% | 53.8% | **+0.0** | ok |
| Hive | 30.5% | 30.5% | **+0.0** | ok |
| Veil | 14.3% | **33.3%** | +19.0 | **v4** |
| Null Synod | 29.2% | 29.2% | **+0.0** | ok |
| Accretion | 11.3% | **16.3%** | +5.0 | **v4** |

Exact zeros on the unchanged ops — op-local changes are byte-invisible
elsewhere (the determinism architecture's strongest guarantee).
**Baseline v4 (Veil + Accretion only): veil 0.333 · stellarMenagerie 0.163.**
Other ops' v3 numbers stand.
