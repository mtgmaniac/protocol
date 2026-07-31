# Full Project Audit — 2026-07

**Audit date:** 2026-07-14  
**Audited revision:** `3f266de Require engage for every deployment slate`  
**Scope:** evaluation only. No game code, data, scene, asset, or existing-document changes were made for this audit.

## Executive assessment

Overload Protocol already has a credible, unusually well-instrumented tactical-dice game inside it. Its best idea is not simply “dice roguelike”; it is the readable sequence **reveal a shared, visible D20 state → decide whether the roll is worth manipulating with scarce Protocol → choose order and targets → accept a deterministic enemy response**. The live game reinforces that idea through visible dice, exposed enemy intent, Nudge/Reroll/Set, freeze-as-repeat, band-specific kits, and bosses with stated standing rules.

The project is not ready to broaden. It is ready to become narrower, more measured, and more playable. The largest release risk is not a missing feature: it is that a very large amount of authored content is currently being judged through an incomplete player model and stale reporting. Current L1 simulation data spans **8.5% Hive** to **63.4% Facility** clear rate, while the canonical document still reports an older 28.7%/59.2% checkpoint. That makes global tuning, progression pacing, and any price claim premature.

The recommended product path is:

1. Make a polished, instrumented **Facility demo** the proof of the hook.
2. Use that demo to establish human difficulty and comprehension baselines.
3. Finish the five-operation campaign only after measured rebalancing and a content-quality pass, rather than adding systems.

**Bottom line:** keep the core; cut scope; fix evidence quality, first-run comprehension, audio completeness, and progression/balance before selling a complete campaign.

## Method and evidence limits

This report used current runtime code and data, `TRUTH.md`, `INVARIANTS.md`, `DECISIONS_RESOLVED.md`, `AI_AGENT_GAME_REFERENCE.md`, `TASK_QUEUE.md`, current Git history, the current sim baseline, automated gates, and representative current captures (battle, reward, deployment, boss alert). It did not rely on the GDD as authority.

Automated evidence collected on the audited tree:

- `python scripts/verify_gate.py --skip-sim`: reported passes through validation, doc/knob/caps/component/reward/panel/ability checks and launched flow smoke; the captured stream did not include the final all-gates banner, so this is not treated as proof of every hard gate.
- `python scripts/sim/ci_smoke.py`: completed without reported drift.
- Current `scripts/sim/baseline.json`: 300 L1 runs, overall clear **31.33%**; Facility **63.38%**, Hive **8.47%**, Veil **18.46%**, Void Circlet **47.37%**, Accretion **10.42%**.
- Prior current-tree ability audit: **228 passed, 0 failed**. It includes boss-rule and boss-fight regressions for all five operations.
- Windowed captures at 540×1200 show the core battle hierarchy, current reward rows, and the new ENGAGE-gated deployment slate. The pre-ENGAGE forced-roll capture did not begin a roll, confirming that gate in the live scene.

Limits:

- No player telemetry, observed new-player sessions, device-lab matrix, frame-time profiling, export build, crash analytics, accessibility testing, store assets, or asset provenance records were available.
- The simulator is a powerful rule and relative-balance tool, not evidence of human difficulty, comprehension, or fun. The repository’s own guidance conflicts on which advanced run features the balance harness represents; that parity contract needs an explicit audit before using sim output as a product decision.

## Ten strongest aspects

1. **KEEP — Critical — all releases.** The visible-roll/Protocol loop is legible, differentiated, and mechanically reinforced from UI to bosses. *Evidence: runtime code, battle captures, TRUTH combat/protocol rules.*
2. **KEEP — High — all releases.** Deterministic combat and seeded roll providers make regressions, reproduction, and measured tuning realistically possible. *Evidence: `INVARIANTS.md` #1, `BattleEngine`, sim runner.*
3. **KEEP — High — all releases.** The one-keyword and one-manual-pick budgets protect phone-scale readability. *Evidence: invariant-enforced data/audit structure.*
4. **KEEP — High — all releases.** Three-hero squads create compact composition decisions without a four-unit UI tax. *Evidence: runtime squad limit and battle layout.*
5. **KEEP — High — Demo.** Faction color language and terminal/pixel visual rules are coherent and unusually disciplined. *Evidence: `PixelUI`, component/caps gates, captures.*
6. **KEEP — High — Demo.** Enemy targeting is deterministic and inspectable rather than opaque AI. *Evidence: `TargetingPersonality`, combat-manager choke point.*
7. **KEEP — Medium — Demo.** Boss standing rules are a strong alternative to hidden phase thresholds: one stated rule, persistent counterplay, visible identity. *Evidence: `BOSS_STANDING_RULES`, boss alerts.*
8. **KEEP — Medium — Demo.** Reward selection, choice guards, evolution stops, and route/event paths have real defensive test coverage. *Evidence: reward-model/choice-guard/audit runners.*
9. **KEEP — Medium — $5 Release.** The roster has meaningful branch intentions rather than eight cosmetic reskins. *Evidence: hero/evolution/directive data.*
10. **KEEP — Medium — $5 Release.** The project has unusually good capture and audit infrastructure for a small game. *Evidence: 228-case ability audit, sim sweeps, safe-area/glyph/reward gates.*

## Ten largest risks

1. **F01 — FIX — Critical — Demo.** Balance and progression are not release-trustworthy while the five-op sim spread remains 8.5–63.4%.
2. **F02 — FIX — High — Demo.** `TRUTH.md` and `TASK_QUEUE.md` report obsolete baseline/Protocol/boss facts, impairing future decisions.
3. **F03 — INVESTIGATE — High — Demo.** Sim/runtime parity for items, summons, taunt/cloak, boss rules, and run events is not documented as a tested capability matrix.
4. **F04 — FIX — High — $5 Release.** `battle_scene.gd` and `combat_manager.gd` remain 2.9k-line high-risk owners despite partial extraction.
5. **F05 — FIX — High — Demo.** The hook is still cognitively dense for a new player: bands, pips, targeting, Protocol, statuses, events, gear, evolution, directives, and bosses arrive in one short campaign.
6. **F06 — FIX — High — $5 Release.** No human playtest/telemetry loop exists to validate difficulty, touch behavior, pacing, or decision quality.
7. **F07 — FIX — Medium — Demo.** Headless runs report missing `revive.wav` and `summon.wav`; combat feedback is incomplete even before a full audio mix.
8. **F08 — REFINE — Medium — $5 Release.** Phone UI is disciplined but dense; 3v3/4-enemy states, long rewards, pips, and modal stacking remain aspect/device risks.
9. **F09 — CUT — Medium — Demo.** Full route-fork + intercept breadth is more systems than a Facility demo needs, and dilutes measurement of the core hook.
10. **F10 — INVESTIGATE — High — $10 Release.** Asset provenance, style consistency, store readiness, and platform/export readiness have no release evidence.

## Findings register

Every finding below uses: **classification · severity · target · evidence · focused human attention · dependencies / regression risk**.

| ID | Finding | Classification / severity / target | Evidence | Focused attention | Dependencies / regression risk |
|---|---|---|---|---:|---|
| F01 | The current L1 spread is Facility 63.4%, Hive 8.5%, Veil 18.5%, Void 47.4%, Accretion 10.4%. Sequential operation unlocks make Hive a likely progression wall, while Facility is too forgiving for a final difficulty claim. | **FIX · Critical · Demo** | Current `baseline.json`; operation chain in `SaveManager`; design target in TRUTH. | 20–45h | Must first resolve F03. Any number move triggers baseline ceremony and risks every op/hero. |
| F02 | Canonical TRUTH reports an older 0.2867/0.592 checkpoint; current baseline is 0.3133/0.6338. TASK_QUEUE still says Facility .77/.53, Set costs 3, P2 boss work, and 450×1000. | **FIX · High · Demo** | `TRUTH.md`, `TASK_QUEUE.md`, current baseline, current constants. | 8–16h | Documentation-only pass after validating ownership; risk is misleading future work, not runtime. |
| F03 | Sim docs say real `CombatManager` is used; repository guidance separately says Facility simulation omits items, summons, taunt, cloak, and boss standing rules. There is no published parity matrix. | **INVESTIGATE · High · Demo** | `scripts/sim/README.md`, AGENTS guidance, sim/runtime code. | 12–24h | Do not retune from aggregate sim until this is reconciled. Requires deterministic test fixtures, not a rewrite. |
| F04 | Battle scene (2,923 lines), combat manager (2,896), GameState (1,409), and several UI owners are still oversized coordination hubs. The hook warns on battle-scene growth. | **FIX · High · $5 Release** | Current line inventory, Git hook, architecture review references. | 30–60h | Extract only stable seams with characterization tests. High regression risk in turn state, targeting, snapshots, and feedback timing. |
| F05 | The core interaction is distinct but onboarding faces a compressed teaching problem. The player can meet 5 bands, target order, Protocol actions, status pips, enemy intent, item targeting, reward selection, evolution, event risks, and boss rules inside one run. | **REFINE · High · Demo** | Tutorial/primer code, UI captures, design inference. | 16–30h | Protect the keyword ceiling and avoid adding tutorials that stop play repeatedly. Needs observation data. |
| F06 | No player instrumentation or external-playtest protocol establishes time-to-first-roll, Protocol use, death causes, abandon points, option pick rates, or comprehension. | **FIX · High · $5 Release** | No telemetry/playtest evidence in runtime/docs; design inference. | 16–32h | Privacy/platform decisions. Keep metrics local/opt-in if needed; avoid remote-service scope for demo. |
| F07 | `AudioManager` emits missing SFX warnings for revive and summon in current Godot runs. The game’s impact layer therefore has known holes. | **FIX · Medium · Demo** | Current headless Godot output. | 2–6h | Asset import/export verification; test no missing references. |
| F08 | Battle and rewards look materially better at 540×1200, but no-scroll battle rails and text/pip density are exposed to smaller portrait devices and 4–5 enemy states. | **REFINE · Medium · $5 Release** | Current captures, BATTLE UI contract, parked half-card task. | 20–40h | Must preserve pixel-snap/safe-area/component laws; regress screenshots at all target aspects. |
| F09 | Route Fork and 22 Intercept cards create real choices, but they are not necessary to prove Facility’s combat hook and complicate balance/teaching. | **CUT · Medium · Demo** | `GameState` decks/modifiers; run-flow structure. | 4–10h | Demo configuration/content lock, not deleting systems. Preserve full campaign path. |
| F10 | No evidence covers AI-asset rights/provenance, art style consistency criteria, store page, trailer, controller/desktop QA, Android export/performance, or crash handling. | **FIX · High · $10 Release** | Asset folders/docs/history; absence of release artifacts. | 40–100h | Platform owner, legal/asset provenance decisions, hardware matrix. |
| F11 | The baseline rewards show 31 gear, 25 consumables, and 35 relics. Many are mechanically specific; the current sim content-lift screen has numerous zero/large values, so dead/automatic choices are plausible but not proven. | **INVESTIGATE · Medium · $5 Release** | Current data and `baseline.json` content-lift. | 16–30h | Requires pick-rate, win-rate, and counterfactual tests before cuts/buffs. |
| F12 | Hero roles are readable, but branch pairs overlap in several places: Bladecore/Ravager both solve single-target damage; Bulwark/Trench both generate defensive sustain; Combat Medic/Synth both revive; Phantom/Shadow both cloak burst; Noise/Nullwire both suppress dice. | **REFINE · Medium · $5 Release** | Hero/evolution/directive data; design inference. | 20–40h | Do not add keywords. Validate by build-choice rates and matchup roles. |
| F13 | Factions have clear local motifs, but world cohesion is mostly visual/flavor rather than a shared systemic arc: Facility salvage, Hive reproduction, Veil firewall, Synod die rewriting, Accretion persistent armor. | **REFINE · Low · $10 Release** | Enemy data, boss rules, product copy. | 12–24h | Narrative/art direction only; no new lore system required. |
| F14 | Existing docs are useful but overgrown: canonical facts, historical rationale, old audits, task queues, and wiki material overlap. Stale “living” facts increase maintenance cost. | **FIX · Medium · Demo** | Doc search: old 450×1000, P2, baseline, Set-cost facts across living files. | 12–24h | Establish doc ownership/index first; archive rather than silently rewrite history. |
| F15 | Current verification is strong at unit/regression level, but end-to-end visibility is weak when an audit command’s captured output stops during flow smoke and no device/export acceptance summary exists. | **REFINE · Medium · Demo** | Gate output, prior flow-smoke stalls, missing device evidence. | 8–20h | Keep headless compatibility; add a concise machine-readable summary, not more test layers. |
| F16 | The immediate lore modal work is correct in behavior but adds another mandatory stop before every run. It is appropriate for a demo only if the pre-battle promise remains brief and the player does not face modal fatigue elsewhere. | **REFINE · Low · Demo** | Current deployment/boss implementation and capture; design inference. | 2–6h | Needs human observation; do not add a skip setting until usage data supports it. |

## Core identity and complete loop

### What reinforces the hook

- **Visible simultaneous rolls:** both sides expose the tactical state before resolution.
- **Protocol scarcity:** income is +1 at end of turn, with Nudge 1, Reroll 2, Set 4, and item use 1. This creates a real “spend now or retain agency later” choice.
- **Order and target decisions:** heroes resolve before enemies, and manual targeting is constrained to one follow-up pick.
- **Predictable opposition:** readable personalities and visible intent let players respond rather than guess.
- **Freeze = repeat:** it turns a die state into an immediately legible tactical object rather than a hidden debuff.
- **Boss standing rules:** they put the exception in front of the player before the first boss roll.

### What feels generic or off-theme

- Generic roguelite scaffolding (three rewards, event cards, route forks, rarity tiers, evolution picks) is competently implemented but does not itself distinguish the game. It must serve the dice/Protocol thesis, not compete with it.
- “Random gear draft plus generic stat/effect value” risks becoming spreadsheet reward handling when too many effects are only recognized through inspection.
- A five-operation campaign before the Facility is fully measured turns the strongest identity into an expensive content obligation.

### Loop assessment

| Loop stage | Assessment | Classification |
|---|---|---|
| Squad + operation selection | Three-unit choice is clean. Unlock gating is simple, but early roster breadth is deliberately low. | **KEEP · Medium · Demo** |
| Deployment and battle start | Clear operation/boss framing now exists. Mandatory deployment ENGAGE is defensible if it remains one compact action. | **REFINE · Low · Demo** |
| Battle | Strongest surface; visible state, Protocol actions, intent, pips, and 3D tray make the thesis concrete. | **KEEP · Critical · Demo** |
| Rewards / gear / consumables | Strong row presentation and commit model; decision quality needs data, especially gear-target friction. | **INVESTIGATE · Medium · $5** |
| Relic cache | A clear ceremonial spike at battle 5; retains its own visual grammar. | **KEEP · Medium · Demo** |
| Route Fork / Intercept | Good full-game variation, excessive for the smallest proof. | **DEFER/CUT FROM DEMO · Medium · Demo** |
| Evolution / directives | Branch intent is good; pacing and build distinctness are not yet evidenced by player choice data. | **REFINE · Medium · $5** |
| Boss / run end / unlocks | Clear operation chain, memorable rules, but balance makes unlock progression risky. | **FIX F01 · Critical · Demo** |
| Replay motivation | Build branches, gear, relics, events, and unlocks offer breadth. The missing proof is whether players want another run after a loss. | **INVESTIGATE · High · $5** |

## Hero audit

All eight base heroes have five base bands, two evolutions, and two directives per evolution. That is a healthy authored structure (80 evolved ability sets and 32 directives), but it is more content than should be balanced by intuition.

| Base hero | Base role / identity | Evolution and directive read | Audit verdict |
|---|---|---|---|
| Pulse Tech | Burn → detonate damage loop. | Pyro = burn timing/duration; Arc = chain reach/damage. | **KEEP · Medium · $5.** Strong clean split; verify Pyro versus Arc matchup niches. |
| Strike Unit | Mark low, delete high; pure single-target anchor. | Bladecore = pierce/breach; Ravager = burn/leech adjacency. | **REFINE · Medium · $5.** Both are damage solutions; make enemy shield vs burn composition the reason to choose. |
| Spike Guard | Taunt/spike/shield-break defender. | Bulwark = squad shields; Sentinel = self-taunt punishment. | **REFINE · Medium · $5.** Good tank split, but current baseline Shield hero lift is strongly negative; measure viability. |
| Avalanche Suit | Freeze-repeat control plus high-band healing. | Glacier = freeze/shatter; Trench = firewall/taunt/sustain. | **FIX/REFINE · High · $5.** Freeze is iconic but historically balance-sensitive; current sim still shows Avalanche below median. |
| Splice Medic | Targeted sustain, mid-roll drain, high-roll damage. | Combat Medic = frontline/mark/revive; Synth = squad triage/mass revive. | **REFINE · Medium · $5.** Two revive-centered branches risk role blur; distinguish prevention versus recovery in practical play. |
| Field Engineer | Protocol generation and support, moving to squad damage. | Overclocked = economy; Phantom = cloak/jam/ambush. | **KEEP · Medium · $5.** The most explicit Protocol-facing hero; protect it as a teaching vehicle. |
| Ghost Operative | Cloak survival and stealth burst. | Shadow = execute/vanish; Wraith = mark/execute. | **REFINE · Medium · $5.** Branches overlap in stealth-finisher fantasy; optimize different target/encounter answers. |
| Signal Breaker | Enemy roll suppression and jam. | Noise = tray-wide suppression; Nullwire = precise lock/rewrite/economy. | **KEEP · Medium · $5.** Excellent control identity; ensure suppression does not make enemies feel noninteractive. |

**Dominance/nonviability risks:** current baseline content-lift flags large positive/negative item effects and a low Shield hero result; those are screening signals, not balance verdicts. Do not buff/nerf individual kits until F03’s parity scope and human-use data are resolved.

### Complete evolution and directive coverage

| Hero | Evolution A → directives | Evolution B → directives | Audit read |
|---|---|---|---|
| Pulse Tech | Pyro Specialist → Flashpoint, Slow Roast | Arc Specialist → Conductor, Amplifier | Clear burn versus chain split. |
| Strike Unit | Bladecore → Serrated, Momentum | Ravager → Deep Cuts, Open Veins | Both are kill/damage amplifiers; matchup separation needs proof. |
| Spike Guard | Bulwark → Rampart, Bunker Doctrine | Sentinel → Ironclad, Counterweight | Strong protect-versus-punish split, contingent on tank viability. |
| Avalanche Suit | Glacier Mantle → Deep Freeze, Shatterpoint | Trench Rig → Field Triage, Entrench | Most mechanically distinct branch pair; freeze balance is high risk. |
| Splice Medic | Combat Medic → Combat Sense, Field Surgeon | Synth Warden → Overcharge Mesh, Lazarus Loop | Prevention/recovery distinction is present but both advertise revival. |
| Field Engineer | Overclocked → Deep Cells, Surge Wiring | Phantom → Silent Running, Ambush Wiring | Economy versus stealth/control is a strong branch split. |
| Ghost Operative | Shadow Operative → Ghostblade, Vanish | Wraith → Marked for Death, Reaper | Both converge on cloaked execution; distinguish through encounter use. |
| Signal Breaker | Noise Floor → Wall of Static, Feedback | Nullwire → Hard Lock, Signal Theft | Area suppression versus precision/economy is a strong split. |

## Enemy and operation audit

### Roster and faction identity

| Operation | Current roster identity | Boss rule | Verdict |
|---|---|---|---|
| Facility | Scrap/Rust/Static drones plus patrol, guard, warden, volt and Scrapmaster; shields, damage, burn, roll pressure. | **Assembly Line:** rebuilds a Scrap Drone every second enemy phase. | **KEEP · Medium · Demo.** Best onboarding faction; the salvage/rebuild rule is readable. |
| Hive | Skitterling/Bloodmite/Stalker/Carapace/Broodwarden/Spewer/Matriarch; reproduction, bodies, burn/attrition. | **The Brood:** Bloodmite every 3 rounds. | **FIX F01 · High · $5.** Theme is clear; 8.5% L1 result demands encounter/HP/cadence investigation. |
| Veil Concord | Shardmite, Prism Charger, Aegis, Resonance, Nullblade, Stormweaver, Synapse, Overseer; firewall/defense and signal control. | **The Court:** boss gains Firewall while any ally lives. | **REFINE · Medium · $5.** Escort-first boss puzzle is good; clause density is high. |
| Null Synod | Glitch, Init, Checksum, Axiom, Forked Double, Daemon, Hierophant; rewrite/hijack/cloak and rule corruption. | **Root Access:** rewrites highest hero die to 3 each round. | **REFINE · High · $5.** Strongest systemic identity, but 47.4% sim versus Veil/Hive signals either intended counterplay or an imbalance. |
| Accretion | Pumice/Obsidian/Slag/Geode/Basalt/Pyroclast/Magma/Mantle; beasts with armor/accretion. | **Accretion:** +6 persistent shield every round. | **FIX F01 · High · $5.** Visual identity is distinct; 10.4% L1 result is not commercially acceptable without player confirmation. |

**Clause-density conclusion:** the one-keyword budget is doing useful work. The threat is not individual enemy tooltips; it is composition-level stacking of shield, burn, firewall, roll control, summons, cloak, and boss rules. Keep faction rules declarative, and avoid adding another enemy die-suppression keyword (invariant #4).

### Complete enemy-kit coverage

The current raw data contains **38 enemy kits**, each with a five-band ability definition keyed by the unit type below. This audit reviewed the kits through those current type definitions, operation encounter lists, AI/targeting fields, and boss rules; the table records the concise tactical job each kit family is currently asked to perform.

| Faction | Kits reviewed | Current tactical reading | Audit verdict |
|---|---|---|---|
| Facility | Scrap Drone, Rust Drone, Static Skimmer, Patrol Elite, Guard Elite, Heavy Warden, Volt Elite, SCRAPMASTER | Intro mix of shields, direct damage, burn, roll pressure, and sturdy elites. | **KEEP · Demo.** Use as the reference teaching curve. |
| Hive | Skitterling, Bloodmite, Spine Stalker, Carapace Beetle, Broodwarden, Caustic Spewer, Hive Matriarch | Body count, attrition, reproduction, and pressure from added units. | **FIX · $5.** Individual kit clarity is adequate; composition/cadence tuning is not. |
| Veil | Shardmite, Prism Charger, Aegis Anchor, Resonance Warden, Nullblade, Stormweaver, Synapse Herald, CONCLAVE OVERSEER | Defensive lattice: firewall, shielding, elite protection, and escort ordering. | **REFINE · $5.** Highest support/defense clause density; preserve legibility. |
| Null Synod | Glitch Sprite, Init Acolyte, Checksum Scribe, Axiom Binder, Forked Double, Daemon Channeler, ROOT HIEROPHANT | Rule corruption: rewrite/hijack, cloaked threats, and highest-die pressure. | **REFINE · $5.** Excellent systemic theme; validate that counterplay, not luck, explains high clear rate. |
| Accretion | Pumice Macaque, Obsidian Hound, Slag Hound, Geode Panther, Basalt Ape, Pyroclast Raptor, Magma Drake, MANTLE TYRANT | Mineral fauna with heavier bodies, accretion, and persistent boss armor. | **FIX · $5.** Strong visual identity; low sim success needs measured encounter pass. |

## Reward economy audit

| Surface | Current state | Audit judgment |
|---|---|---|
| Gear | 31 items (13 uncommon, 10 rare, 8 legendary). Many passives are readable only after inspection. | **INVESTIGATE · Medium · $5.** Track offered/picked/equipped/win contribution; remove or merge effects with persistently low use. |
| Consumables | 25 items (10 common, 6 uncommon, 7 rare, 2 legendary), cost 1 Protocol except explicit overrides. | **REFINE · Medium · Demo.** This directly reinforces the Protocol loop; teach it earlier and measure hoarding. |
| Relics | 35 total, including five boss relics; battle-5 cache is a ceremonial two-card choice. | **KEEP · Medium · Demo.** Strong pacing beat. Investigate large sim content-lift outliers before rarity/offer changes. |
| Reward cadence | Reward after wins, relic at battle 5, events in distinct gaps, progression stops at XP thresholds. | **REFINE · Medium · $5.** Good cadence on paper; potential stop-screen fatigue needs human observation. |
| Choice quality | Choice guard prevents dead UI; model and geometry audits exist. | **KEEP · Medium · Demo.** Decision quality, not validity, remains unmeasured. |

## UI/UX and mobile presentation audit

### Confirmed strengths

- Portrait 1080×2400 / 540×1200 contract, safe-area handling, physical-pixel rules, glyph gate, and component contract are unusually strong mobile foundations.
- Battle capture shows immediate hierarchy: operation/header → enemy state → central roll field → hero state → Protocol footer.
- Reward rows make the entire choice tappable and keep effects readable; relics are appropriately more ceremonial.
- Inspect, primers, tutorial, and tactical reference are available rather than relying on hidden rules.

### Risks

- **F08 applies:** no-scroll rails make lowest-size support a content constraint, not merely a UI polish task. Test 540×1200, the smallest actual supported Android viewport, and the reference device with 3, 4, and 5 enemies; do not assume old 450×1000 references are still valid.
- The battle screen is information-rich enough that long-press inspect and primers may become a tax if first-sight pacing is not observed with newcomers.
- Current reward capture is legible but demonstrates how much vertical space three rows and a commit footer consume; gear-target flows and long descriptions need explicit small-device screenshot acceptance.
- Accessibility is partial: pixel font, color semantics, hard contrast, and ASCII glyph discipline are strengths; there is no evidence of text scaling, color-blind alternatives, screen-reader plan, haptics controls, remapping, or reduced-motion support.

## Game feel audit

**KEEP:** the 3D tray is correctly presentation-only but supplies tactility; frozen dice physically blocking the tray gives freeze an unusually concrete presence. Dice result tags, 20 feedback, battle feedback sequencing, music intensity, and deterministic outcomes form a coherent direction.

**REFINE:** feel has not been validated by play sessions. The Git history shows sustained work on float text, result tags, transition covers, music crossfades, and SFX timing, which is good iteration discipline but also a signal that the “feel” layer is still settling.

**FIX F07:** missing revive/summon clips must be resolved before demo footage. A game whose loop asks the player to notice death, revival, and summoning cannot leave those moments silent or warning-only.

**INVESTIGATE:** measure median battle duration, turns per battle, seconds spent in dice animation, time-to-reward, modal dwell time, and run duration. The desired run duration is not currently a pinned, evidenced product metric.

## Balance and simulation audit

### What the simulator can establish

- Deterministic relative comparisons under the represented rules and policies.
- Per-operation and per-hero clear deltas, policy gap, Protocol spending, keyword realized value, enemy damage, and matched-seed knob sweeps.
- Regression detection when an unchanged tree drifts from baseline.

### What requires people

- Whether visible dice create tension rather than delay.
- Whether a player understands why a loss happened.
- Whether a reward, evolution, event, or directive is attractive for the right reason.
- Touch-target comfort, information scanning, motion comfort, audio impact, and perceived fairness.

### Missing metrics

- Per-offer pick rate and post-pick win contribution for gear/relics/consumables.
- Protocol spend type/time/unused-at-death distribution.
- Hero/evolution/directive selection and survival rates.
- Death cause/turn/state snapshots, including boss-rule attribution.
- New-player completion, abandon, and comprehension checkpoints.
- Run duration and UI dwell time by screen.

### Recommended initial methodology

1. Freeze the current Facility candidate and record an L1 baseline plus selected L2 skill-band runs.
2. Publish the sim parity matrix (F03) before making claims from it.
3. Run 5–10 moderated new-player Facility sessions with a fixed observation sheet; separately run experienced-player sessions.
4. Add only local/dev telemetry needed to compare human results with the simulator.
5. Fix one bottleneck at a time through in-memory sweep candidates, then ship the chosen number only with full per-op/hero deltas and the baseline ceremony.
6. Do not tune Hive, Veil, Synod, and Accretion until Facility has a proven human difficulty target.

## Architecture audit

### What is working

- `BattleEngine`, `BattleState`, `BattleLayout`, `BattleCardView`, `BattleFeedback`, and `ProtocolActions` are meaningful extractions from the original battle monolith.
- Data-driven hero/enemy/item/relic definitions and schema validation are a sound content model.
- `SaveManager` migration/default behavior is centralized and tested.
- Choice guards, audit runners, seeded roll providers, and visual capture tools are valuable test assets.

### High-risk areas

- `battle_scene.gd` remains responsible for lifecycle, presentation, phase gating, input, battle routing, snapshots, overlays, and legacy glue.
- `combat_manager.gd` combines state ownership, effect handlers, boss rules, targeting setup, combat resolution, and tuning seams.
- `GameState.gd` combines run generation, rewards, progression, event decks, route modifiers, and cross-scene state.
- `compact_unit_card.gd`, `reward_screen.gd`, and `pixel_ui.gd` are large visual owners where a local fix can alter phone layout globally.

**Agent-created technical debt:** recent work is generally careful and test-backed, but the commit history is dominated by narrow UI patches, captures, and corrective passes. That produces valuable polish while accumulating coordination logic in the same large files. Do not “clean up” identifiers or rebuild the whole architecture. Extract only a measured, tested seam when it removes a repeated risk.

## Documentation audit

### Canonical and useful

- `TRUTH.md` and `INVARIANTS.md` are high-value guardrails.
- `DECISIONS_RESOLVED.md` correctly prevents re-litigation.
- The sim README and architecture reference are useful when kept current.

### Problems to fix

- TRUTH’s stated baseline contradicts current `baseline.json`.
- TASK_QUEUE still contains obsolete P2 boss, Set-cost, old baseline, and old preview-size statements.
- Several living docs and task exports still cite 450×1000 although current reference is 540×1200; the repository’s own interaction audit already identified this.
- Historical audits/wikis are useful evidence but easy to mistake for active truth. The current docs need one explicit “living index” and a small set of owned source-of-truth tables.

**Recommendation:** preserve history under `docs/archive/` or clearly dated audits, but reduce the active decision surface to: TRUTH (current behavior), INVARIANTS (why), DECISIONS (rulings), one current backlog, and one test/release checklist.

## Systems that should not be touched

1. The seeded deterministic combat/roll-provider fence.
2. Three-unit squad size, legacy IDs, portrait orientation, and the five-band battle layout contract.
3. The existing keyword/die-suppression ceiling and one-manual-pick limit.
4. Boss standing-rule model; tune numbers only through measured passes, do not reintroduce phases.
5. PixelUI/component/caps/safe-area/physical-pixel laws.
6. Data-driven content plus schema/audit gate approach.
7. Existing save migration behavior except for intentional, tested profile changes.

## Recommended cuts and deferrals

| Scope decision | Classification | Target | Reason |
|---|---|---|---|
| New keywords, enemy AI personalities, third evolutions, stats/attributes, multiplayer, node map, narrative layer | **CUT** | Demo and $5 | Each competes with the proven hook and violates existing complexity/scope decisions. |
| Route Fork breadth and most Intercept variety in a Facility demo | **CUT FROM DEMO** | Demo | Keep one representative optional event only if it teaches a combat tradeoff. |
| More operations/factions before balancing existing five | **CUT** | $5 | Existing campaign has enough content and unresolved difficulty spread. |
| Permanent skip-future-briefings setting | **DEFER** | Post-launch | Current mandatory slates need usage data first. |
| Half-card 4–5 enemy layout | **DEFER unless encounter data requires it** | $5 | Build only after actual encounter count and device testing proves need. |
| Full remote analytics/service stack | **DEFER** | Post-launch | Use local/dev playtest instrumentation first. |

## Missing essentials

- A human-tested Facility difficulty/comprehension baseline.
- A sim parity matrix and current baseline documentation.
- Missing combat SFX assets/references resolved.
- A concise release/device/export test checklist.
- A lightweight playtest/telemetry plan.
- Asset provenance and visual-consistency checklist.
- Store capsule, trailer capture plan, and platform crash/performance evidence for a commercial claim.

## Release definitions

### Facility demo — definition of done

- One polished Facility operation: 10 battles, Scrapmaster, all core Protocol actions, 4 starters, reward rows, consumables, one relic cache, and the tutorial.
- A first-time player can explain what Protocol is, why they spent it, and what killed them after one run.
- Facility human completion target is set from observed novice/experienced cohorts; sim is used only as a relative guardrail.
- No missing audio references, no flow soft-locks, no glyph/safe-area/component violations at supported phone sizes.
- At least one complete device capture and one desktop capture are approved for external use.
- Lock Hive onward, advanced hero unlocks, full route/intercept deck breadth, and full campaign marketing behind the demo boundary.

### Credible $5 release — definition of done

- Five operations are balanced to intentionally chosen, human-validated difficulty bands; progression never relies on an accidental Hive bottleneck.
- Eight heroes, 16 evolutions, and directives have evidence of distinct use rather than merely authored differentiation.
- Reward economy has pick-rate/dead-choice cleanup; the smallest content set is better than 91 unmeasured items.
- All current audio references work, onboarding is tested, mobile/device/export QA is repeatable, and docs/test gates are current.
- The game can promise a complete compact campaign with replayable build variety, not “endless roguelite” scope.

### Credible $10 release — definition of done

- Meets every $5 requirement plus substantially stronger human replay evidence, polished campaign pacing, cohesive/provenanced art direction, and platform confidence.
- Store page, trailer, screenshots, input/accessibility choices, performance targets, crash handling, and support plan exist before price positioning.
- The price increase must be supported by polish and breadth players can feel: not merely more relics or more modifiers.

## Ordered attention plan

### Next 30 attentive hours

1. **F02/F14 documentation truth pass** — reconcile baseline, current constants, preview-size references, stale P2 tasks; establish an active-doc index. (8–16h)
2. **F03 simulator parity matrix** — enumerate represented/omitted mechanics and add deterministic fixtures for each claimed category. (12–24h; stop if larger redesign is implied)
3. **F07 audio completeness** — resolve missing clips/references and verify in export-like run. (2–6h)
4. **Facility playtest protocol** — recruit/run first 5 sessions, capture observations without changing balance yet. (6–12h)

### Next 100 attentive hours

1. Facility balance pass using parity-aware sim sweeps and observed play. (30–50h)
2. Demo onboarding/comprehension and battle readability pass based on recordings. (20–35h)
3. Device/aspect/export acceptance matrix including reward/evolution/modal states. (15–25h)
4. Reward pick-rate/dead-choice instrumentation and one cleanup pass. (15–30h)
5. Extract one proven battle/combat coordination seam only if it reduces a recurring defect class. (20–40h; do not start before Facility stability)

### Next 250 attentive hours

1. Bring remaining operations into measured bands one at a time, beginning with Hive and Accretion. (60–100h)
2. Hero/evolution/directive distinctness pass using choice and outcome data. (40–70h)
3. Campaign pacing/replay retention pass; retain only events that create meaningful dice/Protocol tradeoffs. (30–50h)
4. Commercial QA, device/export/performance/accessibility/store/trailer/art provenance work. (60–120h)

## Proposed implementation backlog (no implementation in this audit)

1. **Audit current facts and establish release evidence sources** — F02/F14/F15.
2. **Publish simulator/runtime parity matrix and fixtures** — F03.
3. **Close missing SFX references and validate combat audio** — F07.
4. **Run Facility human playtest cohort; record core-loop metrics** — F05/F06.
5. **Facility-only balance sweep and human validation** — F01.
6. **Facility demo content lock and release checklist** — F09/F15/F16.
7. **Reward decision-quality measurement, then trim dead choices** — F11.
8. **Mobile/device/export acceptance matrix and targeted readability fixes** — F08.
9. **One-characterization-tested architecture extraction, only after a recurrent source is proven** — F04.
10. **One operation at a time: Hive then Accretion, with measured difficulty work** — F01/F12/F13.
11. **Commercial readiness package: provenance, store/trailer, platform QA, support policy** — F10.

No backlog item above authorizes a redesign, new keyword family, or extra campaign content. The smallest excellent version is a mastered Facility loop first, then a measured five-operation campaign.
