# Balance Cycle 3 — Stage-2 Approval Table (BLOCKING — awaiting Kev ruling)

*2026-07-18. All arms n=1000, matched seeds. Mixed-op sweeps: seed base 800000,
hero arms vs own forced-inclusion control. Per-op rows and the combined arm:
seed bases 210000+ vs Cycle-2 controls v2.1 (same policy era). Results tree
`results/cycle3/`. Nothing is baked.*

## Branch resolutions (prerequisites, resolved from data)

| Branch | Evidence | Resolution |
|---|---|---|
| Medic heal-class | naniteField +12.7 obs. mean, triage_gel +1.5, defib_spark +2.3, commons ≈0 | **B fired: numbers, not mechanic — NO overheal rule this cycle** |
| Vengeance Protocol | L1 −2.4 / L2 +1.0 (n=500, SE 3.1pp) | **Alive at L2 → PROTECT, no change** |
| Band Compressor | L1 −2.2 / L2 +2.8 | **Alive at L2 → PROTECT, no change** |
| Pulse chain-fizzle | Facility chain rate 0.36/battle — the HIGHEST, tied w/ Veil | **Hypothesis false → no change, deferred** |

## What SHIPS (measured, in target) — the approval list

| # | Change | Literal (old → new) | Effect text (NK-17, same commit) | Measured lift |
|--:|---|---|---|---|
| 1 | **Overcharge** nerf | `mult` 1.3 → **1.10** | "…130%…" → "…110%…" | +32.4 → **+15.3pp** (target +12..15 ✓) |
| 2 | **Iron Curtain** nerf | `mult` 0.75 → **0.90** | "…75%…" → "…90%…" | +31.0 → **+15.1pp** ✓ |
| 3 | **Predator Lens** rider | `effect` → `rollBonusNat20Protocol {amount 3, protocol 1}` | "+3 to all rolls." → "+3 to all rolls. A 20 grants +1 Protocol." | +8.1 → **+10.6pp**; **+4.3pp over Splice** (was +1.8) ✓ |
| 4 | **Ghost** flat tax (G2) | Probe Strike 7→**5** · System Breach 9→**7** · Phase Blade 13→**12** · Execution Protocol 16→**14** (dmg + dMin/dMax + eff strings) | four band lines | mean +7.1 → **+5.2**, spikes preserved (hive +13.5, synod +8.7), spread 16.0 |

Sweep curves: overcharge 1.10/+15.3 · 1.15/+23.6 · 1.20/+28.2; ironCurtain
0.85/+24.2 · 0.88/+19.3 · 0.90/+15.1; ghost −1-flat/+6.1-est · G2/+5.2 ·
−2-all/≈+4.3. **Ghost altitude is Kev's pick:** the +2..3 target needs roughly
−3-per-band (Probe 4 / Breach 6 / Blade 10 / Exec 13) — shape risk rises;
G2 is the measured, shape-safe point.

Audit delta expectation: ghost band-value expectations update (documented);
`rollBonusNat20Protocol` joins GEAR_HANDLED + one new audit entry; overcharge/
ironCurtain multiplier expectations update. Engine handler already shipped
inert (commit `06f66c8`-era; no data references it until this bake).

## What DOES NOT ship — defers with evidence (doctrine: no unmeasurable bakes)

- **SHIELD — defer to Cycle 4.** Nine sweep points dead flat vs a −7.4
  portfolio deficit: hp 65/70/75 (−0.5/−0.7/+0.5), Enforce 9/10/12 + Stance
  7/8/9 (+0.4/−0.7/+0.5), and the labeled outside-lever probes — crit/overload
  damage +3/+3 (−1.5) and spike +3 (−1.2). **L2 pair: −8.1pp (vs −7.4 at L1)
  — not a skill test; dead at both tiers.** No permitted or probed lever moves
  him; his deficit is structural (a defense hero in a tempo game). Cycle-4
  item: kit-mechanic redesign ruling. The Synod +8.4 spike and the 28.2 spread
  remain untouched and protected.
- **MEDIC — defer.** The heal-value ceiling is hard: doubling heals (4→8,
  8→14) + 5 HP = mean −6.0 → **−5.4** (+0.6). Even 10/16 only +2.4 mixed.
  L1's triage policy caps healing value; baking big heal literals for +0.6
  fails numbers-are-law discipline. Cycle-4 with Shield (same structural
  class).
- **COMBAT — defer; Candidate B is measured DEAD.** The carve inverted both
  criteria: mean +5.8 → **+6.4** (up) and spread 9.3 → **7.1** (COLLAPSED —
  the doctrine's explicit failure mode). Execute is op-agnostic in practice:
  L1 focus-fire drags every target through the sub-25% window on every op, so
  the "Veil/Accretion blunt it" hypothesis failed empirically (shields delay
  the window, they don't remove it). Trim-depth evidence: −12 total flat
  (C6) nets −0.6pp — a pure trim CAN move his mean but leaves him flat, the
  ruling's other named failure. Candidate A was rejected on mechanism
  (Accretion spike favors concentration). Cycle-4: a carve gated by something
  the ops actually gate.

## The combined arm (approved-set candidates together) & Hive give-back

| Op | ctrl v2.1 | combined | delta |
|---|--:|--:|--:|
| Facility | 56.3% | 55.0% | −1.3pp |
| **Hive** | 29.7% | 29.8% | **+0.1pp — NO give-back needed** |
| Veil | 15.1% | 15.1% | +0.0pp |
| Null Synod | 29.9% | 30.2% | +0.3pp |
| Accretion | 12.4% | 11.8% | −0.6pp |

The reprice redistributes value inside squads/drafts without moving op
difficulty — Ghost's tax on Hive is fully absorbed by the system (his own
Hive cell stays +13.5). *Note: this combined arm included the C1/M5
candidates that are now defer-recommended; if the approved set is exactly
items 1–4, a fresh verification arm at that exact set runs BEFORE bake and
becomes the equivalence reference (Cycle-1 protocol).*

## Dead-dozen Cycle-4 worklist (no changes this cycle, as ruled)

corpse: **curatedCache** (−3.6/−4.2 both tiers). Skill-gated (L1-dead, L2
recovers): salvageDirective (+2.6 L2), overflowVent/twinFates (+1.6),
mercyProtocol (+1.4), resonanceCascade (+1.2), martyrdomProtocol/chainDoctrine
(+1.0), protocolOverride (+0.6), overflowBuffer (+0.2), scavengerManifest
(−0.6), standingOrder (+1.2, L1-fine). All n=500, SE 3.1pp — rank, not gospel.

## Post-approval sequence

Verification arm at the approved set → bake literals (one class per commit:
relics / gear / heroes) → equivalence proof on the arm's seeds → NK-17 text +
audit deltas in the same commits → ci_smoke re-pin rides the bake ceremony
(BASELINE-APPROVED-BY-KEV) → post-bake dashboard + refreshed 8×5 rows for
changed heroes → Baseline v3 proposed for affected ops only.
