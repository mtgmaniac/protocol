# Balance Cycle 0 — Re-Baseline Dashboard

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
| Facility (`facility`) | 1000 | **54.7%** | ±3.1% | 59.2% | -4.5pp |
| Hive (`hive`) | 1000 | **3.5%** | ±1.1% | 8.5% | -5.0pp |
| Veil (`veil`) | 1000 | **14.8%** | ±2.2% | 16.9% | -2.1pp |
| Null Synod (`voidCirclet`) | 1000 | **27.4%** | ±2.8% | 40.4% | -13.0pp |
| Accretion (`stellarMenagerie`) | 1000 | **12.0%** | ±2.0% | 8.3% | +3.7pp |
| **Overall (op-balanced)** | 5000 | **22.5%** | ±1.2% | 28.3% | -5.8pp |

_v1 is DEAD as a comparison (pre taunt-G-4, pre item-cap-4, pre NK-17, pre harness fix) — shown for context only. Overall here is op-balanced (equal n per op), unlike v1's random-op draw._

## 2 · Decision density — L1 vs L2 gap (matched seeds)

| Operation | L1 | L2 | Gap | Discordant seeds |
|---|--:|--:|--:|--:|
| Facility | 54.7% | 79.8% | **+25.1pp** | 383 |
| Hive | 3.5% | 10.6% | **+7.1pp** | 109 |
| Veil | 14.8% | 23.3% | **+8.5pp** | 245 |
| Null Synod | 27.4% | 56.9% | **+29.5pp** | 471 |
| Accretion | 12.0% | 22.3% | **+10.3pp** | 255 |

_The boredom dashboard: a SMALL gap means greedy play is near-optimal there (obvious turns). First-class metric from this cycle on. Matched seeds; discordant = seeds where the tiers disagree (McNemar-style evidence base)._

## 3 · Bucket-0 pools vs full pools (L1, matched seeds — NON-baseline arm)

| Operation | Full pools | Bucket-0 | Delta |
|---|--:|--:|--:|
| Facility | 54.7% | 71.7% | **+17.0pp** |
| Hive | 3.5% | 8.1% | **+4.6pp** |
| Veil | 14.8% | 26.7% | **+11.9pp** |
| Null Synod | 27.4% | 43.5% | **+16.1pp** |
| Accretion | 12.0% | 22.7% | **+10.7pp** |

_The true new-player pool the fully-unlocked sim never measured. Harness-side restriction through the live pool choke point; the baseline sim pin is untouched._

## 4 · Kill curve — run-ending battle (L1 defeats)

**Facility** (453 defeats): b1:0%  b2:0%  b3:3%  b4:13%  b5:2%  b6:0%  b7:0%  b8:3%  b9:2%  b10:72%
  ↳ **spike at battle 10** (73% of defeats). Top comps: Scrap Drone + SCRAPMASTER + Scrap Drone (329)

**Hive** (965 defeats): b1:0%  b2:0%  b3:10%  b4:19%  b5:6%  b6:1%  b7:0%  b8:1%  b9:6%  b10:53%
  ↳ **spike at battle 10** (53% of defeats). Top comps: Spine Stalker + Hive Matriarch (515)

**Veil** (852 defeats): b1:0%  b2:0%  b3:10%  b4:26%  b5:9%  b6:1%  b7:9%  b8:5%  b9:6%  b10:30%
  ↳ **spike at battle 10** (30% of defeats). Top comps: CONCLAVE OVERSEER + Aegis Anchor (256)

**Null Synod** (726 defeats): b1:0%  b2:0%  b3:6%  b4:3%  b5:4%  b6:0%  b7:0%  b8:2%  b9:3%  b10:78%
  ↳ **spike at battle 10** (79% of defeats). Top comps: ROOT HIEROPHANT + Checksum Scribe (571)

**Accretion** (880 defeats): b1:0%  b2:0%  b3:5%  b4:1%  b5:3%  b6:1%  b7:0%  b8:1%  b9:4%  b10:83%
  ↳ **spike at battle 10** (83% of defeats). Top comps: MANTLE TYRANT + Geode Panther (734)


## 5 · Turns per battle (L1) — slog detector

| Operation | mean | p50 | p90 | max | rounds>8 share | 500-cap stalls |
|---|--:|--:|--:|--:|--:|--:|
| Facility | 7.1 | 6 | 11 | 51 | 22.0% | 0 |
| Hive | 7.0 | 6 | 12 | 52 | 25.7% | 0 |
| Veil | 7.2 | 6 | 12 | 500 | 26.0% | 1 |
| Null Synod | 7.6 | 6 | 12 | 500 | 25.4% | 3 |
| Accretion | 7.8 | 7 | 13 | 500 | 31.5% | 3 |

_A 500-cap stall is a battle the ROUND_SAFETY_CAP ended with no result; the runner then advances the run as neither victory nor defeat (harness quirk, recorded — rare: stall comps can deadlock against L1's kit)._

## 6 · Protocol economy per policy tier

| Tier | spends/run | cost/run | spend share b1-3 | b4-6 | b7-10 | mean leftover at battle end (b1-3 / b4-6 / b7-10) |
|---|--:|--:|--:|--:|--:|--:|
| L1 | 49.3 | 55.0 | 21% | 28% | 50% | 1.4 / 1.6 / 1.8 |
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
- ❌ **Facility smallest L1/L2 gap** — guessed: facility. Measured: smallest = Hive (+7.1pp).
- ✅ **Null Synod widest L1/L2 gap** — guessed: voidCirclet. Measured: widest = Null Synod (+29.5pp).
