# Combat Sponginess Benchmark — Facility (2026-09)

*Measurement only. No production balance value, data file or combat rule was changed.
Every number below comes from the live runtime data (dumped from `DataManager`) and
from the real `combat_manager` run headless by the balance sim. Build: `0.1.1`,
2026-09-21.*

---

## Executive summary

**Yes — but narrowly, not globally.** Facility combat is not uniformly spongy. Fodder
fights are fast and punchy, and heroes are fragile (a single enemy action typically
removes 15–35% of a hero). The slow feeling comes from **four specific durability
sources**, and they share one symptom: **the last enemy standing takes several low-threat
rounds to remove.**

- **Half of all combat rounds (48%) are fought against a single remaining enemy.** In
  those rounds the squad takes **half the damage** it takes in multi-enemy rounds (6% vs
  12% of squad max HP per round; 43% of solo rounds cost under 5%) while dealing **27%
  less** damage (18 vs 25 per round). That is the "solved but still grinding" feeling, measured.
- **Heavy Warden** (110 HP, heals itself) is the last enemy alive in **23% of all won
  battles** and then takes **5.5 solo rounds** to finish (p90 8). 62% of hits on it remove
  under 10% of its HP. It needs **12 hero actions** to kill; a Scrap Drone needs 4.
- **Shield Enforcer** has **98 effective HP on a printed 70 (+41%)** because its shields
  absorb ~28 damage per instance, and it shields its allies too. Battle 5 (two Shield
  Enforcers) is the slowest non-boss fight in the run: **9.8 rounds, p90 14**, the
  pacing spike in an otherwise smooth curve.
- **Volt Enforcer** is easy but slow: the lowest threat per action of any
  non-fodder enemy (8.7), yet 75 HP and 8 hero actions to kill; last enemy standing in 20% of wins.
- **Scrapmaster** fights average **12.1 rounds (median 11, p90 18)**; 73% of hits on the
  boss remove under 10% of its HP, and Assembly Line turns each 35-HP Scrap Drone into
  **83 effective HP** by rebuilding it.

A typical early Facility enemy needs **4–5 hero actions** (2–3 rounds) to kill; late
Facility enemies need **6–12** (4–7 rounds); the Scrapmaster needs **13** (10 rounds alive).

**Global knobs are the wrong tool.** Cutting all enemy HP 15% shortens the average won
battle only from 7.10 to 6.35 rounds (−11%) but lifts the pooled clear rate from **41% to
63%** and the new-player default squad from **74% to 90%**; +15% player damage does
almost exactly the same (−9% rounds, 64% clear). Both buy roughly one clear-rate point per
half-percent of fight length.

**What works (section 9):**
- **Package I (surgical, recommended first):** trim the four outliers' durability (Shield
  Enforcer shields −40%, Warden 110→95 HP with smaller heals, Volt 75→65 HP, Assembly Line
  rebuild 50%→25%) and give the threat back as +20% face damage on those same four enemies.
  Clear rate **40.6% → 39.8%** (unchanged), battle 5 **−11%**, late battles **−10%**, Scrapmaster
  fight **12.1 → 10.6 rounds**, early fights untouched, every squad within ±5 clear points.
- **Both-sides compression (E2):** −20% enemy HP with +25% enemy damage is also
  difficulty-neutral (39.3% clear) and makes *every* phase 15–20% shorter, the boss **12.1 → 8.7
  rounds**, at the cost of favouring offensive builds over defensive ones.

---

## 1. Method

| | |
|---|---|
| Engine | `scripts/sim` headless harness running the real `combat_manager` / `BattleEngine` (no reimplementation), seeded and byte-deterministic |
| Player model | L1 greedy policy (focus fire, band-aware Nudge/Reroll/Set spends, drafts, evolutions) — the policy behind the gate's clear-rate baseline |
| Op | Facility Sweep, full 10-battle runs incl. route forks, intercepts, rewards, evolutions, directives |
| Squads | default `combat,engineer,medic` (new-player default) · high-damage `combat,pulse,ghost` · defensive `shield,medic,engineer` · mixes `pulse,combat,shield`, `combat,medic,breaker`, `avalanche,pulse,medic`, `ghost,shield,engineer` · uniform-random squads |
| Sample | Baseline **4,800 runs / 39,065 battles** (600 per squad). Scenarios 400 runs per squad on the **same seeds** as the first 400 baseline seeds, so scenario deltas are paired, not independent draws |
| Data | `tools/sponginess/dump_balance.gd` dumps the runtime model (the JSON matched the runtime exactly; two documented fields — `trackHpScale`, `battleEnemyScale` — are **dead**: enemies spawn at printed HP) |
| Analytic model | `tools/sponginess/model.py`: 1v1 time-to-kill per hero kit × enemy and enemy × hero (4,000 trials each), for relative durability without squad play |
| Scenarios | In-memory sim seams only (`--tuning`, `--enemy-hp`); one new sim-only knob `enemy_ability:` (enemy kit fields) added to `sim_runner.gd` for the shield/heal scenarios |

Metric definitions used throughout:

- **Rounds** = rounds in *won* battles unless stated. **Hero actions** = every hero ability fired.
- **Offensive action** = a hero action that damaged an enemy or hit its shield.
- **Effective HP (EHP)** = printed HP + damage absorbed by its shields + HP it healed/rebuilt, as actually removed in play.
- **Actions to kill** = distinct hero actions that damaged that enemy before it died (splash included).
- **Solo round** = a round that *started* with exactly one enemy alive.
- **Cleanup (HP-decided)** = rounds beyond the one after remaining enemy HP first fell to one average round of squad output.
- **Low-threat tail** = final rounds of a win in which the squad lost < 5% of its max HP.

---

## 2. Current combat baseline

### Action economy

- Heroes: 3 per squad, each rolls one d20 per round and fires exactly one ability from its
  band (5 bands: roughly 1–4 / 5–10 / 11–15 / 16–19 / 20; bands differ per hero). Heroes act
  first, enemies second. One-round shields (a shield gained in the enemy phase covers the
  next hero phase), burn ticks at the burning unit's action.
- Enemies: 1–3 per battle, same d20 band structure (1–4 / 5–10 / 11–16 / 17–19 / 20).
- Protocol: 0 at battle start, +1 per completed turn, cap 10. Nudge (+3) costs 1, Reroll 2,
  Set 4, item use 1. L1 spends ~5 Nudges and ~0.7 Rerolls per won battle.
- Run scaling: **none on enemies** (no per-battle HP/damage multiplier is live). The
  player scales through rewards/gear/relics, one **evolution per win after battles 3–6**
  (90% of runs evolve after battle 4) and directives after battles 8–9.

### Heroes (base kit; evolution in brackets)

| Hero | HP (evo) | Expected single-target dmg / action (evo best) | Share of faces with no damage | Role in data |
|---|---|---|---|---|
| Strike (combat) | 55 (65–70) | 8.0 (10.6) | 20% | Damage |
| Pulse | 45 (60) | 8.2 (10.7) | 0% | Burn/chain |
| Ghost | 45 (60–65) | 7.6 (10.8) | 10% | Burst |
| Breaker | 45 (60–65) | 6.4 (10.5) | 35% | Debuff |
| Engineer | 50 (60–65) | 4.9 (8.9) | 50% | Buff / AoE |
| Splice (medic) | 50 (65–70) | 4.8 (4.3) | 55% | Heal |
| Avalanche | 55 (80–85) | 4.0 (6.1) | 45% | AoE / freeze |
| Shield | 55 (70–80) | 1.9 (4.8) | 80% | Tank |

Across the 16 evolution branches the median evolution adds **+33% HP** (range +18% to +55%)
but only **+23% single-target damage** (range −75% to +153%); **5 of 16 branches lose damage**
(Trench Rig −32%, Synth Medic −75%, Bulwark −21%, Combat Medic −11%, Pyro −1%). Upgrades make
the squad more durable faster than they make it lethal.

### Facility enemies

| Enemy | Role | HP | Dmg / action (expected) | Self/ally shield per round | Self-heal per round | Special |
|---|---|---|---|---|---|---|
| Scrap Drone | fodder | 35 | 8.4 | 1.6 | — | burn on hits |
| Static Skimmer | fodder | 40 | 6.2 | 1.0 | — | jam, roll-down |
| Rust Drone | fodder | 45 | 7.0 | 1.0 | — | roll-down on hits |
| Patrol Enforcer | elite | 60 | **14.2** | 1.2 | — | roll-down |
| Volt Enforcer | elite | 75 | 8.7 | 1.0 (all) | — | 4 spike (retaliation), burn |
| Shield Enforcer | support | 70 | 10.1 | **7.4 (every face shields an ally)** | — | +2 roll all enemies |
| Heavy Warden | heavy | 110 | 11.7 | 1.4 | **1.7** (7 on recharge, 6 on overload) | jam, burn |
| Scrapmaster | boss | 140 | 13.2 | 2.4 | — | **Assembly Line**: rebuilds a destroyed Scrap Drone at 50% HP every 2nd enemy phase; shield wipe; 26 dmg to all heroes on 20 |

Run structure: B1 Scrap+Rust · B2 fodder×2 · B3 elite+fodder · B4 heavy or elites ·
**B5 Shield Enforcer×2 (fixed)** · B6 elite+fodder×2 · B7 heavy+fodder · B8 heavy+elite ·
B9 elite+support+fodder · B10 Scrap Drone+Scrapmaster+Scrap Drone. Route forks can add a
flagged modifier (elite presence, jamming field, …).

### What an average won battle looks like (pooled)

| Metric | Mean | Median | p90 |
|---|---|---|---|
| Rounds | 7.1 | 6 | 11 |
| Hero actions | 21.1 | 19 | 32 |
| Offensive hero actions | 13.3 | 12 | 19 |
| Damage dealt to enemy HP | 146 | 142 | 206 |
| Player damage absorbed by enemy shields | 15 | 7 | 40 |
| Damage taken (hero HP) | 77 | 68 | 137 |
| Enemy damage absorbed by hero shields | 15 | 4 | 43 |
| Healing on heroes | 27 | 17 | 71 |
| Hero shield generated | 32 | 6 | 98 |
| Rerolls / Nudges | 0.7 / 5.0 | 0 / 4 | 2 / 9 |
| Share of hero actions spent on sustain (heal/shield only) | 21% | | |
| Solo rounds | 3.6 | 3 | 6 |
| HP-decided cleanup rounds | 0.23 | 0 | 1 |
| Low-threat tail rounds | 1.26 | 1 | 2 |

A normal offensive hero action removes **~10 HP** (hero means 7.9–14.4). Every
durability number below is best read against that yardstick.

---

## 3. Encounter pacing

### Per enemy (squad play, pooled baseline)

| Enemy | Printed HP | Effective HP | EHP vs printed | Hero actions to kill (median / p90) | Rounds alive (median / p90) | Hits removing <10% | 10–20% | 20–30% | 30–40% | 40%+ |
|---|---|---|---|---|---|---|---|---|---|---|
| Scrap Drone | 35 | 37 | +6% | 4 / 5 | 2 / 4 | 4% | 22% | 40% | 16% | 18% |
| Static Skimmer | 40 | 42 | +6% | 4 / 6 | 3 / 5 | 5% | 31% | 35% | 23% | 5% |
| Rust Drone | 45 | 48 | +6% | 5 / 6 | 3 / 5 | 8% | 32% | 42% | 13% | 5% |
| Patrol Enforcer | 60 | 68 | +13% | 6 / 8 | 4 / 7 | 19% | 50% | 26% | 5% | 0% |
| Volt Enforcer | 75 | 82 | +10% | 8 / 10 | 6 / 10 | 33% | 52% | 15% | 0% | 0% |
| Shield Enforcer | 70 | **98** | **+41%** | 8 / 10 | 6 / 12 | 34% | 42% | 23% | 1% | 0% |
| Heavy Warden | 110 | **131** | +19% | **12 / 15** | 7 / 10 | **62%** | 37% | 1% | 0% | 0% |
| Scrapmaster (B10) | 140 | 155 | +11% | **13 / 16** | 10 / 17 | **73%** | 27% | 0% | 0% | 0% |
| Scrap Drone (B10, rebuilt) | 35 | **83** | **+137%** | 7 / 16 | 7 / 16 | 6% | 16% | 36% | 12% | 31% |

(16% of Shield Enforcers and 34% of Scrapmasters are never killed — those fights are lost.)

### Per encounter (won battles; representative comps with n ≥ 400)

| Encounter | Win % | Rounds mean / median / p90 | Hero actions | Solo rounds | Damage taken | Hero deaths |
|---|---|---|---|---|---|---|
| Scrap + Rust (B1) | 100% | 4.7 / 4 / 6 | 14.7 | 2.1 | 35 | 0.02 |
| Fodder pair (B2) | 100% | 4.0–5.2 / 4–5 / 5–7 | 13–16 | 1.6–2.1 | 31–37 | 0.01–0.04 |
| Patrol + fodder | 99% | 5.5–6.1 / 5–6 / 7–8 | 16–17 | 3.1–3.3 | 73–79 | 0.46–0.57 |
| Volt + fodder | 100% | 6.3–6.7 / 6 / 8–9 | 22–23 | 3.5–3.7 | 66–72 | 0.25–0.34 |
| Heavy Warden alone | 98% | 6.7 / 6 / 10 | 20.9 | **6.7** | 65 | 0.46 |
| Heavy Warden + fodder | 99–100% | 6.9–7.3 / 7 / 9–10 | 23 | **4.9** | 63–71 | 0.19–0.27 |
| Patrol + Volt | 87% | 8.1 / 8 / 11 | 23.3 | 4.4 | 114 | 1.26 |
| Heavy Warden + elite | 98% | 8.2–8.7 / 8 / 12 | 25–28 | **5.2** | 95–105 | 0.50–0.56 |
| Elite + Shield Enforcer + fodder (B9) | 87–96% | 8.2–8.8 / 8 / 12–13 | 21–27 | 3.0–3.3 | 110–138 | 0.68–1.01 |
| **Shield Enforcer ×2 (B5)** | **75%** | **9.8 / 9 / 14** | 23.2 | **5.1** | 132 | **1.51** |
| **Scrapmaster (B10)** | **66%** | **12.1 / 11 / 18** | 35.1 | 3.2 | 189 | 1.35 |

### "Solved but still grinding"

| | Multi-enemy rounds | Solo rounds |
|---|---|---|
| Share of all rounds | 52% | **48%** |
| Damage the squad takes per round (share of squad max HP) | 12.0% | **6.0%** |
| Rounds costing the squad < 5% of max HP | 13% | **43%** |
| Squad damage output per round | 24.9 | **18.0** |

Who is left standing, in won battles:

| Last enemy alive | Share of won battles | Solo rounds to finish (mean / p90) |
|---|---|---|
| **Heavy Warden** | **23%** | **5.5 / 8** |
| Rust Drone | 21% | 2.1 / 3 |
| **Volt Enforcer** | **21%** | **3.6 / 6** |
| **Shield Enforcer** | **13%** | **4.5 / 8** |
| Patrol Enforcer | 11% | 2.9 / 4 |
| Static Skimmer | 5% | 2.0 / 3 |
| Scrapmaster | 3% | 2.6 / 4 |

Literal overshoot — rounds spent after the fight is one round from over — is small (0.23
rounds per battle; only 3% of battles run ≥ 2 rounds past that point). The grind is *before*
that point: once the dangerous units are dead, the Warden, Volt or Shield Enforcer left
behind is a low-threat target that still needs 3.6–5.5 rounds.

---

## 4. Player durability

Heroes are **not** spongy. Enemy damage per damaging action, as a share of the target
hero's max HP:

| Enemy | Dmg per damaging action (mean / p90) | Hits ≥ 30% of the hero's max HP | Enemy actions to kill a base-kit hero (model) | …an evolved hero |
|---|---|---|---|---|
| Static Skimmer | 7.6 / 11 | 0% | 8–9 | 10–12 |
| Rust Drone | 8.6 / 12 | 1% | 7–8 | 9–10 |
| Scrap Drone | 9.9 / 15 | 4% | 5–7 | 7–8 |
| Volt Enforcer | 10.7 / 13 | 2% | 4–5 | 6 |
| Shield Enforcer | 12.2 / 15 | 9% | 5–6 | 6–7 |
| Heavy Warden | 13.8 / 24 | 17% | 4 | 5 |
| Scrapmaster | 17.3 / 21 | 20% | 4–5 | 5–6 |
| **Patrol Enforcer** | **17.5 / 21** | **52%** | **3–4** | 5 |

Squad survivability comes from sustain, not raw HP: across a won battle the squad heals 27
and blocks 15, i.e. **~42 effective HP of sustain against 77 HP of damage taken (+55%)**.
21% of hero actions are pure sustain (Splice 44%, Shield 56%). Heroes die at 0.60 per
battle; 65% of wins are flawless. Evolution raises hero HP a further 33% (median).

The defensive squad (`shield,medic,engineer`) is the degenerate case: 43% of its actions are
sustain, its battles take **9.2 rounds**, its Scrapmaster fight takes **25.5 rounds**, and it
still clears only **17%** — long *and* losing, because it cannot generate damage.

---

## 5. Damage-to-HP ratios

Expected player action (~10 HP, splash included) against each enemy's effective HP:

| Band (one normal hit removes…) | Enemies |
|---|---|
| **40%+** | none (only the 20-face capstones on fodder) |
| **30–40%** | none on average |
| **20–30%** | Scrap Drone (27%), Static Skimmer (24%), Rust Drone (21%) |
| **10–20%** | Patrol Enforcer (15%), Volt Enforcer (12%) |
| **< 10%** | **Shield Enforcer (10% of EHP, 14% of printed)**, **Heavy Warden (8%)**, **Scrapmaster (6%)** |

Reverse direction (one enemy action against a 50-HP base hero): Static 15%, Rust 17%, Scrap
20%, Volt 21%, Shield Enforcer 24%, Warden 28%, Scrapmaster 35%, **Patrol 35%**.

Defensive mechanics that make durability dramatically higher than printed HP:

- **Shield Enforcer's shields: +41% EHP on itself**, plus ally shields that inflate its partners
  (battles 5 and 9 absorb 57 and 35 player damage into enemy shields, against 5–12 elsewhere).
- **Heavy Warden's self-heal: +12 HP per instance (+11%)** on top of 9 shield absorbed, and it
  heals most when it is the last enemy — exactly the rounds that feel grindy.
- **Assembly Line: +48 EHP per Scrap Drone (+137%)**, i.e. ~96 extra HP of chaff per boss fight.
- **Low-roll faces:** the recharge-band faces of most damage heroes deal 5–6 per use (Probe
  Strike 5.1, Target Paint 5.3, Cover Fire 5.4, Static Ping 5.6, Rifle Burst 6.1, Glacial
  Shove 6.1) — 3.5–4.5% of a Scrapmaster, 4–5% of a Warden.

---

## 6. Where the sponginess comes from

| Candidate cause | Verdict | Evidence |
|---|---|---|
| Raw HP (all enemies) | **No** | Fodder 35–45 HP dies in 4–5 actions; hits remove 20–30%. Punchy. |
| Raw HP (specific enemies) | **Yes — Heavy Warden, Volt, Scrapmaster** | 12 / 8 / 13 actions to kill; 62% / 33% / 73% of hits under 10% |
| Excessive enemy shielding | **Yes — Shield Enforcer only** | +41% EHP; B5 is the pacing spike (9.8 rounds, 75% win) |
| Excessive enemy healing | **Yes — Heavy Warden** | +12 HP per fight, concentrated in solo rounds |
| Boss mechanics | **Yes — Assembly Line** | +137% EHP on each drone; boss fights 12.1 rounds (p90 18) |
| Low player damage | **Partly** | Base expected single-target damage 4–8 per action; weak faces 5–6. Evolution adds HP faster than damage. |
| Weak / defensive dice faces | **Partly** | Shield/Medic/Engineer/Avalanche have 45–80% no-damage faces; the defensive squad stalls |
| Enemy regeneration / mitigation (other) | No | Other enemies add ≤ 13% EHP |
| Status mechanics | Minor | Roll-downs and jams lower output a little; no mechanic stalls fights |
| Action economy | No | 3 hero actions vs 1–3 enemy actions per round is healthy |
| Target access | No | No untargetable phases in Facility; taunt only on player side |
| Damage variance | No | Round p90 is ~1.5× the median across encounters — normal |
| Reroll limits | No | L1 barely rerolls (0.7 per battle); Nudge carries the spend economy |
| Encounter composition | **Yes — B5 and B8** | Two Shield Enforcers (B5) and Warden + elite (B8, 8.4 rounds) |

**Difficulty vs durability.** Patrol Enforcer is the most *dangerous* Facility enemy (52% of
its hits take ≥ 30% of a hero) yet dies in 6 actions — dangerous, not spongy. Volt Enforcer is
the reverse: lowest non-fodder threat, 8 actions — **easy but slow**. Heavy Warden is
both moderately dangerous and very durable, but its danger front-loads (crit 24, overload 29)
while its durability back-loads (it heals and is left last). Shield Enforcer's threat is middling
(12 per hit) while its durability is the highest relative to printed HP.

---

## 7. Facility progression curve

| Battle | Typical comp | Win % | Rounds (mean / p90) | Enemy HP pool | Squad output / round | Damage taken | Hero deaths |
|---|---|---|---|---|---|---|---|
| 1 | Scrap + Rust | 100% | 4.7 / 6 | 80 | 20.2 | 35 | 0.02 |
| 2 | fodder ×2 | 100% | 4.7 / 6 | 80 | 20.2 | 33 | 0.02 |
| 3 | elite + fodder | 99% | 6.3 / 8 | 109 | 20.6 | 77 | 0.47 |
| 4 | heavy or 2 elites | 91% | 7.4 / 11 | 121 | 20.4 | 91 | 0.90 |
| **5** | **Shield Enforcer ×2** | **74%** | **9.8 / 14** | 140 (+57 absorbed) | 23.2 | 133 | **1.53** |
| 6 | elite + fodder ×2 | 100% | 6.7 / 9 | 147 | 27.5 | 84 | 0.42 |
| 7 | heavy + fodder | 100% | 7.1 / 10 | 150 | 26.8 | 66 | 0.22 |
| 8 | heavy + elite | 98% | 8.4 / 12 | 176 | 26.8 | 100 | 0.53 |
| 9 | elite + support + fodder | 92% | 8.5 / 13 | 178 (+35 absorbed) | 29.8 | 122 | 0.83 |
| **10** | **Scrapmaster** | **66%** | **12.1 / 18** | 210 (+83 rebuilt) | 32.7 | 189 | 1.35 |

The curve is **fast → reasonable → spike → reasonable → slow → very slow**:
4.7 → 4.7 → 6.3 → 7.4 → **9.8** → 6.7 → 7.1 → 8.4 → 8.5 → **12.1**.

**Enemies gain durability faster than the player gains offense (flag).** The enemy HP pool
grows **2.6×** from battle 1 to battle 10 (80 → 210, before shields and rebuilds), while squad
output per round grows **1.6×** (20 → 33) despite evolutions, gear and relics. Evolutions land
after battles 3–6 and add more HP (median +33%) than damage (median +23%), so rounds per battle
rise ~70% across the run while the player *feels* stronger. Battle 5 is the one step that
breaks monotonic growth: it is the fixed double-Shield-Enforcer fight, slower than battles 6–9.

---

## 8. Outliers

1. **Shield Enforcer — clearest durability outlier.** 98 EHP on 70 printed (+41%): 44% more
   effective HP than Patrol (68) and 20% more than Volt (82), for middling threat. Its
   ally shields also slow whatever it stands beside. Drives battle 5 (the slowest non-boss fight)
   and battle 9.
2. **Heavy Warden — longest cleanup.** Last enemy alive in 23% of won battles; 5.5 solo rounds
   (p90 8); 12 actions to kill; 62% of hits under 10%; self-heal worth +12 HP concentrated in
   the low-threat end phase.
3. **Scrapmaster / Assembly Line — boss repetition.** 12.1 rounds (p90 18); 73% of hits on the
   boss under 10%; each drone rebuilt to 83 EHP. The fight's threat is front-loaded while the
   rebuilt drones extend the tail.
4. **Volt Enforcer — easy but slow.** 8.7 expected damage per action (lowest non-fodder),
   75 HP, 8 actions to kill, last standing in 21% of wins (3.6 solo rounds).
5. **Battle 5 composition.** Two Shield Enforcers shielding each other: 9.8 rounds, p90 14,
   75% win, 1.5 hero deaths — a spike between battle 4 (7.4) and battle 6 (6.7).
6. **Low-damage faces.** Recharge-band faces of the damage heroes deal 5–6 per use; on Shield,
   Medic, Engineer and Avalanche 45–80% of faces deal no damage at all.
7. **Hero contribution.** Shield: 24% offensive actions, 7.9 per offensive action (lowest).
   Splice: 44% sustain. Strike/Engineer/Ghost carry damage at 11.5–14.4 per offensive action.
8. **Defensive build.** `shield,medic,engineer` produces 9.2-round battles and a 25.5-round
   boss fight while still losing 83% of runs — long without being safe.

---

## 9. Tuning simulations

All scenarios: 8 squads x 400 runs on the same seeds as the baseline (baseline cut to the
same 400 seeds per squad: 3,200 runs, pooled clear rate **40.6%**). *Mean rounds over all
won battles is biased by survivorship* (an easier scenario reaches more of the long late
battles), so pacing is reported per phase: **early** = battles 1–3, **mid** = 4–6, **late** = 7–9.

### Scenario definitions

| ID | Knobs (all in-memory, sim only) |
|---|---|
| A: hp90 / hp85 / hp80 / hp75 | every Facility enemy HP −10 / −15 / −20 / −25% (incl. summons and rebuilds) |
| B: dmg110 / dmg115 / dmg120 | every hero ability's direct damage +10 / +15 / +20% (rounded per face; burn unchanged) |
| **C** targeted | Shield Enforcer shields −40% (6/6/9/7/13 → 4/4/5/4/8) · Heavy Warden HP 110→95, self-heal 7→4 and 6→3 · Assembly Line rebuild 50%→25% |
| **C2** targeted + Volt | C + Volt Enforcer HP 75→65 |
| D mixed | C + all enemy HP −10% + every hero face dealing 1–6 damage gets +2 |
| E fast & deadly | all enemy HP −20%, all enemy damage +15% |
| **E2** fast & deadly, calibrated | all enemy HP −20%, all enemy damage +25% |
| F targeted + global threat | C + all enemy damage +10% |
| G | all enemy HP −15%, all enemy damage +10% |
| H punchy | C2 + weak faces (+2 on 1–6 damage) + all enemy damage +10% |
| **I** targeted, threat kept on the tuned units | C2 + Shield Enforcer / Heavy Warden / Volt Enforcer / Scrapmaster face damage +20% |

### Results (pooled, L1)

| Scenario | Clear | Early rnds | Mid rnds | Late rnds | B5 rnds / win | Boss rnds mean / p90 / win | Hero actions / win | Dmg taken / battle | Hero deaths / battle | Solo rnds |
|---|---|---|---|---|---|---|---|---|---|---|
| **baseline** | **40.6%** | 5.22 | 7.93 | 7.97 | 9.7 / 76% | 12.1 / 18 / 66% | 21.1 | 87.8 | 0.60 | 3.63 |
| A hp90 | 52.2% | 4.83 | 7.25 | 7.26 | 8.9 / 82% | 11.0 / 16 / 72% | 19.9 | 79.7 | 0.49 | 3.29 |
| A hp85 | 63.3% | 4.58 | 6.94 | 6.92 | 8.6 / 85% | 10.1 / 16 / 81% | 19.2 | 74.5 | 0.42 | 3.12 |
| A hp80 | 71.5% | 4.36 | 6.57 | 6.57 | 8.1 / 89% | 9.5 / 15 / 85% | 18.4 | 69.1 | 0.36 | 2.94 |
| A hp75 | 76.6% | 4.13 | 6.18 | 6.19 | 7.7 / 90% | 8.9 / 14 / 89% | 17.5 | 63.7 | 0.30 | 2.76 |
| B dmg110 | 56.2% | 4.81 | 7.27 | 7.30 | 9.0 / 85% | 11.2 / 17 / 74% | 20.0 | 79.5 | 0.48 | 3.31 |
| B dmg115 | 63.7% | 4.66 | 6.99 | 7.01 | 8.5 / 88% | 10.6 / 17 / 79% | 19.5 | 75.5 | 0.43 | 3.15 |
| B dmg120 | 70.2% | 4.54 | 6.77 | 6.81 | 8.2 / 90% | 10.1 / 16 / 84% | 19.1 | 72.1 | 0.38 | 3.05 |
| C targeted | 60.4% | 5.22 | 7.62 | 7.46 | 9.0 / 88% | 11.0 / 17 / 82% | 20.8 | 81.9 | 0.50 | 3.40 |
| C2 targeted + Volt | 62.1% | 5.13 | 7.40 | 7.29 | 8.9 / 87% | 11.0 / 17 / 83% | 20.4 | 80.5 | 0.48 | 3.28 |
| D mixed | 80.7% | 4.66 | 6.72 | 6.59 | 7.9 / 96% | 9.7 / 15 / 90% | 19.0 | 69.9 | 0.34 | 2.95 |
| E fast & deadly | 50.3% | 4.40 | 6.39 | 6.46 | 7.7 / 77% | 9.0 / 14 / 78% | 17.2 | 79.6 | 0.54 | 2.93 |
| **E2 calibrated** | **39.3%** | **4.43** | **6.36** | **6.47** | **7.6 / 72%** | **8.7 / 13 / 73%** | **16.6** | 85.7 | 0.65 | 2.95 |
| F targeted + threat | 42.7% | 5.26 | 7.48 | 7.37 | 8.7 / 80% | 10.6 / 16 / 76% | 19.7 | 89.6 | 0.64 | 3.40 |
| G hp85 + dmg+10% | 49.3% | 4.61 | 6.84 | 6.92 | 8.3 / 78% | 9.8 / 15 / 74% | 18.4 | 81.6 | 0.55 | 3.13 |
| H punchy | 52.0% | 4.97 | 7.10 | 7.04 | 8.6 / 84% | 10.5 / 16 / 77% | 19.0 | 85.5 | 0.58 | 3.19 |
| **I targeted, threat kept** | **39.8%** | **5.15** | **7.19** | **7.19** | **8.6 / 72%** | **10.6 / 16 / 73%** | **19.0** | 88.4 | 0.66 | 3.26 |

### Per battle (mean rounds in won battles)

| Scenario | B1 | B2 | B3 | B4 | B5 | B6 | B7 | B8 | B9 | B10 |
|---|---|---|---|---|---|---|---|---|---|---|
| baseline | 4.69 | 4.67 | 6.32 | 7.46 | **9.72** | 6.75 | 7.06 | 8.40 | 8.49 | **12.06** |
| A hp85 | 4.14 | 4.14 | 5.47 | 6.36 | 8.63 | 5.94 | 6.22 | 7.19 | 7.38 | 10.12 |
| B dmg115 | 4.22 | 4.22 | 5.55 | 6.43 | 8.55 | 6.06 | 6.26 | 7.29 | 7.50 | 10.56 |
| C2 targeted + Volt | 4.69 | 4.67 | 6.05 | 6.57 | 8.94 | 6.79 | 6.46 | 7.35 | 8.11 | 11.03 |
| **I targeted, threat kept** | 4.69 | 4.67 | 6.10 | 6.58 | 8.65 | 6.55 | 6.37 | 7.32 | 7.97 | 10.55 |
| G hp85 + dmg+10% | 4.15 | 4.14 | 5.56 | 6.40 | 8.31 | 5.93 | 6.18 | 7.21 | 7.41 | 9.75 |
| **E2 calibrated** | 3.98 | 3.97 | 5.34 | 6.08 | 7.57 | 5.54 | 5.79 | 6.87 | 6.81 | 8.69 |

### Durability outliers under each approach

| Scenario | Shield Enforcer EHP | Heavy Warden EHP | Rebuilt drone EHP | Hits on Warden < 10% | Hits on Scrapmaster < 10% | Warden solo rounds when last |
|---|---|---|---|---|---|---|
| baseline | 97.8 | 130.5 | 83.0 | 62% | 73% | 5.5 |
| A hp85 | 84.5 | 110.9 | 66.0 | 49% | 67% | n/a |
| B dmg115 | 94.8 | 127.3 | 77.0 | 49% | 68% | n/a |
| C2 / I | 86.8 | 107.9 | 55.7 | 49% | 71% | 4.7 |
| E2 | 76.7 | 103.7 | 56.6 | 38% | 64% | 4.5 |

(The "hero actions to kill" metric counts only hits that reach HP, so it *rises* when an
enemy's shields shrink; effective HP is the reliable durability measure for the Shield Enforcer.)

### Per squad clear rate

| Scenario | default | high-dmg | defensive | pulse/combat/shield | combat/medic/breaker | aval/pulse/medic | ghost/shield/eng | random |
|---|---|---|---|---|---|---|---|---|
| baseline | 74% | 48% | 17% | 14% | 78% | 27% | 32% | 35% |
| A hp85 | 90% | 84% | 29% | 41% | 94% | 52% | 58% | 58% |
| B dmg115 | 91% | 80% | 40% | 35% | 93% | 53% | 60% | 57% |
| C2 | 89% | 70% | 42% | 37% | 92% | 56% | 52% | 58% |
| **I** | **73%** | **50%** | **13%** | **19%** | **73%** | **28%** | **29%** | **34%** |
| **E2** | **71%** | **65%** | **5%** | **17%** | **77%** | **20%** | **26%** | **34%** |

### What each lever buys

- **Enemy HP −15%**: early 5.2 → 4.6 rounds, mid 7.9 → 6.9, boss 12.1 → 10.1; incoming damage
  −15%, hero deaths −29%; clear **41% → 63%** (new-player default squad 74% → 90%). Each −5% of
  enemy HP ≈ +11 clear-rate points.
- **Player damage +15%**: nearly identical profile (boss 12.1 → 10.6, clear 41% → 64%) but it
  favours already-strong damage squads and barely touches the Shield Enforcer (EHP 98 → 95,
  because its shields still absorb the first 4–13 damage of every hit).
- **Targeted C2 alone**: removes most of the excess durability (Shield Enforcer 98 → 87 EHP,
  Warden 131 → 108, rebuilt drones 83 → 56) and shortens mid/late fights 7–9%, B5 8% and the
  boss 9%, **without touching the fast early fights**, but clear rises to 62% because the long
  fights were also where heroes died.
- **Targeted + threat on the same units (I)**: same durability cuts, **clear 39.8% (neutral)**,
  B5 −11%, late −10%, boss −13% (12.1 → 10.6), Warden solo tail 5.5 → 4.7 rounds, 2.1 fewer hero
  actions per won battle, per-squad clear rates within ±5 points of baseline for every build.
- **Both sides −20% HP / +25% damage (E2)**: **clear 39.3% (neutral)**, every phase ~15–20%
  shorter, boss **12.1 → 8.7 rounds (p90 18 → 13)**, 21% fewer hero actions per battle, hero
  deaths +9%. It rewards offence (high-damage squad 48% → 65%) and punishes turtling
  (defensive squad 17% → 5%).

---

## 10. Protecting difficulty

The data supports the premise that **durability and danger are separable here**:

- Every *pure* durability cut raises the clear rate sharply (targeted C2 +22 points, hp85 +23,
  dmg115 +23), because the long fights are also where heroes die: Battle 5 and the boss account
  for most run losses. Shortening them without adding threat trivialises them.
- Returning the threat **on the same units** (scenario I: +20% face damage on the four tuned
  enemies) restores the baseline clear rate (39.8% vs 40.6%) while keeping the shorter fights.
  Battle 5 still loses 28% of attempts (baseline 24%), the boss 27% (baseline 34%).
- Reducing durability on **both** sides of the exchange (E2) produces the "faster and more
  dangerous" profile: 21% fewer player actions per battle, boss fights of 8.7 rounds, the same
  overall clear rate, slightly more hero deaths (0.65 vs 0.60 per battle), fewer flawless wins
  (62% vs 65%). Offensive builds gain and defensive builds lose: a deliberate shift, not a
  neutral one.
- Global HP or damage changes **alone** push the new-player default squad to ~90% clear and the
  high-damage squad to 80–84%: the clearest triviality risk in the study.
- Threat per solo round is unchanged under every scenario (6–7% of squad HP): none of these
  knobs makes the last-enemy cleanup *dangerous*; they make it *shorter*.

---

## 11. Recommended tuning direction (not implemented)

**1. Surgical first: package I (difficulty-neutral).** The evidence puts the sponginess in
four units, not in the HP curve:

| Knob | Current | Proposed | Why | Expected effect (with the matching threat bump) |
|---|---|---|---|---|
| Shield Enforcer shield values | 6 / 6 / 9 / 7 / 13 | **4 / 4 / 5 / 4 / 8** | +41% EHP; drives B5 and B9 | EHP 98 → 87; B5 9.7 → 8.6 rounds |
| Shield Enforcer face damage | 12 / 11 / 15 / 18 | **14 / 13 / 18 / 22** | keep B5/B9 dangerous | B5 win 76% → 72% |
| Heavy Warden HP | 110 | **95** | 62% of hits under 10%; last enemy in 23% of wins | EHP 131 → 108; solo tail 5.5 → 4.7 rounds |
| Heavy Warden self-heal | 7 / 6 | **4 / 3** | heals concentrate in the solo tail | (included above) |
| Heavy Warden face damage | 11 / 11 / 24 / 29 | **13 / 13 / 29 / 35** | trade durability for threat | B7/B8 win within 1–2 points of baseline |
| Volt Enforcer HP | 75 | **65** | lowest non-fodder threat; 8 actions to kill | EHP 82 → 71; 6 → 5 rounds alive |
| Volt Enforcer face damage | 9 / 11 / 13 / 15 | **11 / 13 / 16 / 18** | it was easy *and* slow | |
| Assembly Line rebuild | 50% | **25%** | +137% EHP per drone; boss repetition | rebuilt drone EHP 83 → 56; boss 12.1 → 10.6 rounds (p90 18 → 16) |
| Scrapmaster face damage | 12 / 17 / 21 / 26 | **14 / 20 / 25 / 31** | keep the boss the hardest fight | boss win 66% → 73% |

Net (scenario I, pooled): clear **40.6% → 39.8%**, battle 5 −11%, late battles −10%, boss −13%,
2.1 fewer hero actions per won battle, early fights untouched, every squad's clear rate within ±5
points. Share of hits removing under 10%: Heavy Warden 62% → 49%, Volt 33% → 26%, Scrapmaster
73% → 71%.

**2. If the whole run should also feel faster:** add a both-sides compression on top, scaled
down from E2 (E2 is −20% HP / +25% enemy damage and is itself difficulty-neutral: boss 12.1 → 8.7
rounds, all phases 15–20% shorter). A half-strength version (about −10% enemy HP, +12% enemy
damage) was **not** simulated on top of package I and should be before shipping; expect roughly
half of E2's per-phase gains.

**3. Not recommended on this evidence:** global player-damage buffs or global enemy-HP cuts
without compensating threat (each 5% ≈ +11 clear points; new-player squad to ~90%), and the
weak-face buff (+2 on 1–6-damage faces, in D/H): it helps pacing but raises clear rates and is a
hero-side change for an enemy-side problem.

**4. Follow-ups the benchmark exposed (not part of this tuning):**
- **Scrapmaster HP** is untouched by package I, and 71% of hits on it still remove under 10%. If
  the boss still feels long after package I, test 140 → 120 with a matching damage bump.
- **Evolution** adds median +33% HP vs +23% damage, and five branches lose damage. Worth
  reviewing if late fights remain slow after the enemy-side fix.
- **Defensive squads** are long *and* losing (9.2-round battles, 25.5-round boss, 17% clear);
  tank/healer kits have 45–80% no-damage faces.
- **Dead scaling data**: `trackHpScale` and `battleEnemyScale` in the data files are never read.
- **Balance-sim drift**: `scripts/sim/ci_smoke.py` currently reports Facility clear **29.6%**
  against the pinned 50.7% baseline and the 63.4% acknowledged-drift snapshot (2026-07-30),
  reproduced with and without today's working-tree changes, so it comes from committed history.
  The gate's sim leg is red for that reason, independent of this study.

---

## 12. Confidence and limitations

- **What the sim represents faithfully:** every combat rule, face, shield/heal timing, burn,
  spike, jam, Assembly Line, route modifiers, drafts, evolutions and directives — it is the
  live engine. Pacing, EHP and ratio numbers are measurements, not estimates.
- **Player skill:** all results use the L1 greedy policy. Humans misplay more (longer fights)
  but also plan better (focus fire on Shield Enforcers first, Nudge into kill thresholds).
  Relative comparisons between scenarios are robust to this; absolute clear rates are not.
  L2-solver check: 300 runs each with the **L2 exact round solver** (default and random squads; baseline, C,
C2, H). L2 plays much better (default squad: boss 10.5 → 7.9 rounds, solo rounds 3.2 → 2.4;
random squads: clear 35% → 54%), but every scenario moves pacing in the same direction and by
similar proportions under both policies (C2, default squad: late battles −12% under L1, −11% under L2), and the
Heavy Warden still needs 11–12 actions under either policy. Its durability is intrinsic, not a
play-quality artefact.
- **Survivorship:** later-battle rows only include runs that reached them. Weaker squads
  drop out before battle 10, so late pacing is measured on the stronger half of runs.
- **Analytic 1v1 model** ignores splash, roll buffs, jams, freezes, spikes and squad support, and
  lets a solo Shield Enforcer shield itself with its "ally" shields (the engine's fallback). Use
  it for relative durability only; the Shield Enforcer and AoE heroes (Avalanche, Engineer)
  are the least faithful rows.
- **Scenario seams:** player damage scaling rounds each face to a whole number (a 4-damage face
  becomes 4 at +10%, 5 at +15/20%); burn is not scaled. `--hero-hp` would not reach evolution
  HP, so hero durability was modelled through enemy damage instead (`enemy_dmg_scalar`).
- **Clear rate as a difficulty proxy** blends every battle; per-battle win rate and hero deaths
  are reported alongside it for that reason.

---

## 13. Reproduce

```bash
godot --headless --path . -s res://tools/sponginess/dump_balance.gd -- --out results/sponginess/balance_facility.json
python tools/sponginess/model.py -o results/sponginess/model.json
python tools/sponginess/run_bench.py --scenarios baseline --runs 600
python tools/sponginess/run_bench.py --scenarios hp90,hp85,hp80,hp75,dmg110,dmg115,dmg120 --runs 400
python tools/sponginess/run_bench.py --scenarios C_targeted,D_mixed,E_fast_deadly,F_targeted_threat --runs 400
python tools/sponginess/run_bench.py --scenarios C2_targeted_volt,G_hp85_dmg110,H_C2_punchy --runs 400
python tools/sponginess/compare.py -o results/sponginess/compare_final.json
```

Raw runs land in `results/sponginess/` (gitignored). The only change outside `tools/` is the
sim-only `enemy_ability:` knob in `scripts/sim/sim_runner.gd` / `knobs.json` (no-op when unused).

---

## 14. Round 4: trading durability for threat on the three sponge outliers (2026-09-21)

*Measurement only; nothing implemented.* Design ruling (Kev): **Scrapmaster's Assembly Line
stays at 50%**, and the Scrapmaster encounter is untouched in every scenario here. Rebuild is
meant to be strong: ignored drones do not come back, and re-killing them is partly a
strategic trap. Package I's rebuild 50→25% and boss damage +20% are withdrawn.

Scenarios (same 8 squads × 400 matched seeds, L1): each tier trims Shield Enforcer
shieldAlly, Heavy Warden HP + self-heal and Volt HP, then scales the face damage of **those
three enemies only**.

| Tier | Shield Enforcer shields (per zone) | Warden HP / heals | Volt HP |
|---|---|---|---|
| light | 6/6/9/7/13 → 5/5/7/5/10 | 110 → 100, 7/6 → 5/4 | 75 → 70 |
| mid | → 4/4/5/4/8 | → 95, 4/3 | → 65 |
| deep | → 3/3/4/4/6 | → 90, 3/2 | → 60 |

### Results (pooled)

| Scenario (dmg mult SE / HW / Volt) | Clear | Mid rnds | Late rnds | B5 rnds / win | Hero actions / win | Incoming / round | Hero deaths / battle | Per-squad max \|Δ\| |
|---|---|---|---|---|---|---|---|---|
| baseline | 40.6% | 7.93 | 7.97 | 9.72 / 76% | 21.1 | 13.0 | 0.60 | — |
| light ×1.10 | 38.1% | 7.53 | 7.48 | 9.16 / 74% | 20.1 | 13.4 | 0.62 | 5 |
| **mid ×1.10** | **42.3%** | 7.28 | 7.25 | 8.77 / **81%** | 19.9 | 13.5 | 0.59 | 6 |
| **mid 1.15 / 1.10 / 1.10 (cal3)** | **38.4%** | 7.17 | 7.14 | 8.65 / **74%** | 19.5 | 13.6 | 0.61 | 6 |
| mid 1.15 / 1.20 / 1.10 (cal1) | 38.4% | 7.21 | 7.23 | 8.69 / 74% | 19.4 | 13.8 | 0.63 | 7 |
| mid 1.15 / 1.20 / 1.15 (cal2) | 37.8% | 7.22 | 7.25 | 8.71 / 74% | 19.4 | 13.8 | 0.64 | 9 |
| mid ×1.20 | 36.1% | 7.19 | 7.19 | 8.65 / 72% | 19.2 | 13.9 | 0.66 | 11 |
| mid ×1.30 | 27.4% | 7.07 | 7.15 | 8.50 / 61% | 18.5 | 14.4 | 0.73 | 19 |
| deep ×1.30 | 31.0% | 6.90 | 6.91 | 8.27 / 67% | 18.3 | 14.4 | 0.70 | 12 |
| deep ×1.40 | 25.7% | 6.86 | 6.90 | 8.26 / 60% | 17.9 | 14.8 | 0.75 | 20 |
| SE only, mid ×1.20 | 38.1% | 7.60 | 7.87 | 8.66 / 72% | 20.6 | 13.4 | 0.62 | 8 |
| Warden only, mid ×1.20 | 39.8% | 7.67 | 7.40 | 9.62 / 75% | 20.3 | 13.3 | 0.61 | 4 |
| Volt only, mid ×1.20 | 38.2% | 7.77 | 7.80 | 9.77 / 76% | 20.4 | 13.3 | 0.62 | 5 |

B1/B2 (fodder) are identical in every scenario (4.69 / 4.67 rounds, 100%). B3 moves only
through Volt + fodder draws (6.32 → 6.06 rounds, 99% win throughout).

### Per enemy: baseline → mid tier (cal3)

| Enemy | EHP | Hero actions to kill (incl. shield hits) | Rounds alive | Dmg dealt / round alive | Dmg dealt / life | Hits < 10% | Solo rounds when last (share of wins) |
|---|---|---|---|---|---|---|---|
| Shield Enforcer | 98 → 87 | 9.0 → 8.2 | 7.1 → 6.8 | **8.7 → 10.0** | 77 → 81 | 33% → 35% | 4.4 → 3.8 (13% → 16%) |
| Heavy Warden | 131 → 108 | 12.3 → 10.3 | 7.3 → 6.2 | **9.6 → 10.4** | 70 → 65 | 62% → 49% | **5.5 → 4.6** (24% → 24%) |
| Volt Enforcer | 82 → 71 | 8.0 → 7.0 | 6.3 → 5.5 | **7.7 → 8.4** | 50 → 47 | 33% → 26% | 3.6 → 3.2 (20% → 17%) |

Per battle (rounds in wins): B4 7.46 → 6.56, B5 9.72 → 8.65, B7 7.06 → 6.32, B8 8.40 → 7.22,
B9 8.49 → 7.96. Incoming damage per round 13.0 → 13.6 while incoming per battle falls 106 → 103.

**Reading.** The durability tier sets the pacing and the damage multiplier sets the difficulty,
almost independently: every mid-tier variant lands at 7.1–7.3 late rounds whatever its damage.
The deep tier buys only ~0.25 more rounds per late battle at a large clear-rate cost. Clear
rate is **very** sensitive to Shield Enforcer damage, because battle 5 (two of them, fixed)
decides many runs. +1 on each SE face (×1.10 → ×1.15) moves B5 win 81% → 74% and the pooled
clear rate by about 4 points. Warden and Volt at ×1.10 are close to neutral. `ghost,shield,engineer`
is the squad most exposed to added Shield Enforcer threat (−6 to −11 points at SE ≥ ×1.15).

## 15. Scrapmaster under an encounter-aware strategy

Two sim-only L1 variants (`--policy l1_focus` / `l1_norekill`; plain L1 byte-identical) on
the baseline, same seeds. Runs are identical to L1 until battle 10.

| Policy | Run clear | B10 win | B10 rounds mean / p90 | Hero actions / win | Drone kills | Rebuilds | Squad damage into drones | Boss dies (round) | Incoming / round | Dmg taken | Hero deaths |
|---|---|---|---|---|---|---|---|---|---|---|---|
| L1 (lowest-HP focus) | 40.6% | 65.5% | 12.1 / 18 | 34.9 | 6.7 | 5.2 | 60% | 11.5 | 18.2 | 189 | 1.35 |
| don't re-kill rebuilt drones | 44.6% | 71.9% | 9.7 / 14 | 28.9 | 4.3 | 2.9 | 51% | 8.6 | 21.2 | 178 | 1.26 |
| **focus Scrapmaster** | **54.0%** | **87.0%** | **7.7 / 11** | **22.8** | 2.2 | 0.5 | 38%* | 6.1 | 21.6 | 144 | 0.87 |

\*Splash/AoE and the post-boss drone cleanup.

B10 win by squad, L1 → focus: default 78 → 87%, high-damage 59 → 88%, defensive 71 → 92%
(25.5 → 11.6 rounds), pulse/combat/shield 26 → 64%, combat/medic/breaker 85 → 97%,
aval/pulse/medic 64 → 88%, ghost/shield/eng 59 → 89%, random 65 → 87%.

**Reading.** The long Scrapmaster fight is the L1 player falling into the Assembly Line
trap: 60% of its damage goes into drones that come back. A player who focuses the boss
wins in 7.7 rounds (below battle 5's 8.7) and takes less total damage, though more per
round. **Boss durability is not a problem, so no change is recommended.** If anything, the
fight is on the easy side for a player who reads it (87% B10 win). The L1 baseline that the
gate calibrates against overstates boss difficulty for such players.

Reproduce:

```bash
python tools/sponginess/run_bench.py --scenarios baseline --runs 400 --policy l1_focus
python tools/sponginess/run_bench.py --scenarios baseline --runs 400 --policy l1_norekill
python tools/sponginess/run_bench.py --scenarios K_light_d110,K_mid_d110,K_mid_d120,K_mid_d130,K_deep_d130,K_deep_d140,Kse_mid_d120,Khw_mid_d120,Kvolt_mid_d120,K_mid_cal1,K_mid_cal2,K_mid_cal3 --runs 400
python tools/sponginess/compare.py -o results/sponginess/compare_k.json
python tools/sponginess/compare.py --policy l1_focus -o results/sponginess/compare_k_focus.json
python tools/sponginess/compare.py --policy l1_norekill -o results/sponginess/compare_k_norekill.json
python tools/sponginess/report_k.py --l1 results/sponginess/compare_k.json --focus results/sponginess/compare_k_focus.json --norekill results/sponginess/compare_k_norekill.json
```

## 16. Final confirmation: `K_final` (2026-09-21)

Mid tier, with faces set explicitly: Shield Enforcer 13/12/17/21, Heavy Warden 12/12/26/32,
Volt Enforcer 10/12/14/16. Scrapmaster and Rebuild 50% unchanged. 8 squads × 400 matched seeds, L1.

| Metric | Baseline | K_final |
|---|---|---|
| Facility clear rate | 40.6% | **40.9%** (+0.3) |
| Battle 5 win | 75.5% | 78.6% |
| Rounds B4–6 / B7–9 (wins) | 7.93 / 7.97 | **7.26 / 7.20** (−8% / −10%) |
| Hero deaths / battle | 0.60 | 0.59 |
| Incoming damage / battle · / round | 105.6 · 13.0 | 103.4 · 13.5 |
| Per-squad clear Δ (pts) | — | default −0.8, high-dmg −2.0, defensive −0.5, pulse/combat/shield +2.0, combat/medic/breaker +1.0, aval/pulse/medic +5.7, ghost/shield/eng −5.2, random +1.7 |
| Shield Enforcer actions to kill (incl. shields) · solo rounds when last | 9.0 · 4.44 | 8.3 · 3.83 |
| Heavy Warden actions to kill · solo rounds when last | 12.3 · 5.50 | 10.4 · 4.58 |
| Volt Enforcer actions to kill · solo rounds when last | 8.0 · 3.62 | 7.0 · 3.17 |

`python tools/sponginess/run_bench.py --scenarios K_final --runs 400`
