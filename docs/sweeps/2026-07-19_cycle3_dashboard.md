# Balance Cycle 3 — Post-Reprice Dashboard (Cycle-0 format)

> **ERA NOTE (Cycle 3, 2026-07-19).** Sections 1, 4, 5: **post-Cycle-3-bake**
> L1 (the `equiv_*` arms — shipped data; these rows ARE Baseline v3). Section 2
> L2 columns and Section 3 bucket-0 columns are **Cycle-0-era** (two policy/data
> generations old — directional context only; fresh L2/b0 tiers are a Cycle-4
> measurement item). Section 7 outlier lifts are Cycle-0-era and pre-reprice —
> overcharge/ironCurtain/predator_lens rows are SUPERSEDED by the Cycle-3
> post-reprice lifts (+15.3 / +15.1 / +10.6, additive estimand). Refreshed
> 8×5 row for the one changed hero (Ghost) lives in the Cycle-3 Stage-2 table.

> **Standing caveats.** The sim measures **WINNABILITY, not fun**. Cognitive-load
> problems (Veil) and turn-feel problems are invisible to every policy tier;
> those belong to the demo testers. All of Cycle 0 ran at **full unlock** except
> arm 3 (bucket-0) — the headline numbers describe a **veteran's pools**.
> Batches ran under the CURRENT operation order (facility, hive, veil,
> voidCirclet, stellarMenagerie — the pending reorder ruling has NOT landed).
> MEASUREMENT ONLY: zero game-data changes in this cycle.

## 1 · Baseline v2 — per-operation win rate (L1, full pools)

| Operation | n | v2 clear | 95% CI | dead v1 (context) | drift |
|---|--:|--:|--:|--:|--:|
| Facility (`facility`) | 1000 | **53.8%** | ±3.1% | 59.2% | -5.4pp |
| Hive (`hive`) | 1000 | **30.5%** | ±2.9% | 8.5% | +22.0pp |
| Veil (`veil`) | 1000 | **14.3%** | ±2.2% | 16.9% | -2.6pp |
| Null Synod (`voidCirclet`) | 1000 | **29.2%** | ±2.8% | 40.4% | -11.2pp |
| Accretion (`stellarMenagerie`) | 1000 | **11.3%** | ±2.0% | 8.3% | +3.0pp |
| **Overall (op-balanced)** | 5000 | **27.8%** | ±1.2% | 28.3% | -0.5pp |

_v1 is DEAD as a comparison (pre taunt-G-4, pre item-cap-4, pre NK-17, pre harness fix) — shown for context only. Overall here is op-balanced (equal n per op), unlike v1's random-op draw._

## 2 · Decision density — L1 vs L2 gap (matched seeds)

| Operation | L1 | L2 | Gap | Discordant seeds |
|---|--:|--:|--:|--:|
| Facility | 53.8% | 79.8% | **+26.0pp** | 398 |
| Hive | 30.5% | 10.6% | **-19.9pp** | 307 |
| Veil | 14.3% | 23.3% | **+9.0pp** | 246 |
| Null Synod | 29.2% | 56.9% | **+27.7pp** | 483 |
| Accretion | 11.3% | 22.3% | **+11.0pp** | 268 |

_The boredom dashboard: a SMALL gap means greedy play is near-optimal there (obvious turns). First-class metric from this cycle on. Matched seeds; discordant = seeds where the tiers disagree (McNemar-style evidence base)._

## 3 · Bucket-0 pools vs full pools (L1, matched seeds — NON-baseline arm)

| Operation | Full pools | Bucket-0 | Delta |
|---|--:|--:|--:|
| Facility | 53.8% | 71.7% | **+17.9pp** |
| Hive | 30.5% | 8.1% | **-22.4pp** |
| Veil | 14.3% | 26.7% | **+12.4pp** |
| Null Synod | 29.2% | 43.5% | **+14.3pp** |
| Accretion | 11.3% | 22.7% | **+11.4pp** |

_The true new-player pool the fully-unlocked sim never measured. Harness-side restriction through the live pool choke point; the baseline sim pin is untouched._

## 4 · Kill curve — run-ending battle (L1 defeats)

**Facility** (462 defeats): b1:0%  b2:0%  b3:3%  b4:15%  b5:3%  b6:0%  b7:0%  b8:4%  b9:1%  b10:71%
  ↳ **spike at battle 10** (71% of defeats). Top comps: Scrap Drone + SCRAPMASTER + Scrap Drone (329)

**Hive** (695 defeats): b1:0%  b2:0%  b3:6%  b4:7%  b5:4%  b6:0%  b7:0%  b8:1%  b9:4%  b10:75%
  ↳ **spike at battle 10** (76% of defeats). Top comps: Spine Stalker + Hive Matriarch (527)

**Veil** (857 defeats): b1:0%  b2:0%  b3:10%  b4:28%  b5:9%  b6:0%  b7:8%  b8:4%  b9:7%  b10:30%
  ↳ **spike at battle 10** (30% of defeats). Top comps: CONCLAVE OVERSEER + Aegis Anchor (259)

**Null Synod** (708 defeats): b1:0%  b2:0%  b3:7%  b4:3%  b5:5%  b6:1%  b7:0%  b8:2%  b9:3%  b10:77%
  ↳ **spike at battle 10** (77% of defeats). Top comps: ROOT HIEROPHANT + Checksum Scribe (546)

**Accretion** (887 defeats): b1:0%  b2:0%  b3:6%  b4:1%  b5:4%  b6:1%  b7:0%  b8:1%  b9:2%  b10:82%
  ↳ **spike at battle 10** (83% of defeats). Top comps: MANTLE TYRANT + Geode Panther (734)


## 5 · Turns per battle (L1) — slog detector

| Operation | mean | p50 | p90 | max | rounds>8 share | 500-cap stalls |
|---|--:|--:|--:|--:|--:|--:|
| Facility | 7.1 | 6 | 11 | 51 | 22.2% | 0 |
| Hive | 6.3 | 5 | 11 | 77 | 18.8% | 0 |
| Veil | 7.5 | 6 | 12 | 500 | 27.4% | 3 |
| Null Synod | 7.8 | 7 | 12 | 500 | 26.4% | 2 |
| Accretion | 8.0 | 7 | 13 | 500 | 32.3% | 5 |

_A 500-cap stall is a battle the ROUND_SAFETY_CAP ended with no result; the runner then advances the run as neither victory nor defeat (harness quirk, recorded — rare: stall comps can deadlock against L1's kit)._

## 6 · Protocol economy per policy tier

| Tier | spends/run | cost/run | spend share b1-3 | b4-6 | b7-10 | mean leftover at battle end (b1-3 / b4-6 / b7-10) |
|---|--:|--:|--:|--:|--:|--:|
| L1 | 51.3 | 57.4 | 20% | 28% | 52% | 1.4 / 1.6 / 1.8 |
| L2 | 38.9 | 47.3 | 22% | 29% | 49% | 1.5 / 1.7 / 2.0 |

_Hoarding-equilibrium check: compare leftover protocol at battle end across phases and tiers — a hoarding tier shows fat early leftovers spent late (or never)._

## 7 · Content outliers — forced-grant A/B vs matched-seed control

_Control clear: **24.2%** over 500 runs (random squads + ops). Lift = arm − control, matched seeds; ±SE is the conservative independent-sample bound. Flag ⚑ = |lift| ≥ 5pp. Granted from battle 1 (not the natural draft point) — a documented upward bias on early-gated content._

_**Estimand caveat (relics):** a granted relic counts as drafted, so the battle-5 relic cache never rolls in relic arms (`GameState._roll_reward_item_ids`, `drafted_relic_count()==0` gate). Relic lifts are therefore **substitution** effects — this relic from battle 1 INSTEAD OF the natural battle-5 choice-of-2 — while gear/consumable lifts are **additive** (drafts continue normally). Rankings within a type are comparable; magnitudes across types are not._

| # | Content | Lift | Arm | Ctrl | ±SE | n |
|--:|---|--:|--:|--:|--:|--:|
| 1 | `overcharge` ⚑ | **+26.6pp** | 50.8% | 24.2% | 2.9pp | 500 |
| 2 | `ironCurtain` ⚑ | **+25.0pp** | 49.2% | 24.2% | 2.9pp | 500 |
| 3 | `openingGambit` ⚑ | **+18.0pp** | 42.2% | 24.2% | 2.9pp | 500 |
| 4 | `overloadLoop` ⚑ | **+15.8pp** | 40.0% | 24.2% | 2.9pp | 500 |
| 5 | `curatedCache` ⚑ | **-11.8pp** | 12.4% | 24.2% | 2.4pp | 500 |
| 6 | `martyrdomProtocol` ⚑ | **-9.2pp** | 15.0% | 24.2% | 2.5pp | 500 |
| 7 | `overflowBuffer` ⚑ | **-9.2pp** | 15.0% | 24.2% | 2.5pp | 500 |
| 8 | `overflowVent` ⚑ | **-9.2pp** | 15.0% | 24.2% | 2.5pp | 500 |
| 9 | `twinFates` ⚑ | **-9.2pp** | 15.0% | 24.2% | 2.5pp | 500 |
| 10 | `mercyProtocol` ⚑ | **-9.0pp** | 15.2% | 24.2% | 2.5pp | 500 |
| 11 | `salvageDirective` ⚑ | **-9.0pp** | 15.2% | 24.2% | 2.5pp | 500 |
| 12 | `chainDoctrine` ⚑ | **-8.6pp** | 15.6% | 24.2% | 2.5pp | 500 |
| 13 | `scavengerManifest` ⚑ | **-7.8pp** | 16.4% | 24.2% | 2.5pp | 500 |
| 14 | `resonanceCascade` ⚑ | **-7.6pp** | 16.6% | 24.2% | 2.5pp | 500 |
| 15 | `overkill_matrix` ⚑ | **+7.4pp** | 31.6% | 24.2% | 2.8pp | 500 |
| 16 | `protocolOverride` ⚑ | **-7.4pp** | 16.8% | 24.2% | 2.5pp | 500 |
| 17 | `coordinatedStrike` ⚑ | **+7.0pp** | 31.2% | 24.2% | 2.8pp | 500 |
| 18 | `standingOrder` ⚑ | **-7.0pp** | 17.2% | 24.2% | 2.6pp | 500 |
| 19 | `emergencySignal` ⚑ | **-6.8pp** | 17.4% | 24.2% | 2.6pp | 500 |
| 20 | `naniteField` ⚑ | **+6.8pp** | 31.0% | 24.2% | 2.8pp | 500 |

_86 arms screened; **31** past ±5pp. Full table in the results tree (`arm_*/`)._

## 8 · Prediction check (pre-registered, honestly scored)

- ❌ **Vengeance Protocol** — guessed: strongly positive. Measured: -9.2pp.
- ✅ **Dead Man's Hand** — guessed: strongly positive. Measured: +6.4pp.
- ❌ **Band Compressor** — guessed: strongly positive. Measured: -1.6pp.
- ✅ **Iron Curtain** — guessed: strongly positive. Measured: +25.0pp.
- ✅ **Predator Lens vs Neural Splice (identical effect, different rarity)** — guessed: similar lift = mispricing. Measured: predator +6.8pp vs splice +5.6pp.
- ❌ **Facility smallest L1/L2 gap** — guessed: facility. Measured: smallest = Veil (+9.0pp).
- ✅ **Null Synod widest L1/L2 gap** — guessed: voidCirclet. Measured: widest = Null Synod (+27.7pp).
