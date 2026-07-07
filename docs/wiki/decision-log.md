# Decision Log — design-decision history of Overload Protocol

> Part of the [Overload Protocol wiki](INDEX.md). See also: [conventions.md](conventions.md), [keywords.md](keywords.md), [statuses-and-chips.md](statuses-and-chips.md), [bosses.md](bosses.md), [factions.md](factions.md).

Chronological reconstruction of every major design decision recoverable from git
history (`git -C C:\Users\Kev\Documents\protocol log`), `docs/DECISIONS_RESOLVED.md`
(verbatim Kev rulings), `docs/TRUTH.md`, `docs/INVARIANTS.md`,
`docs/SESSION_2026-07-06_engine_semantics.md`, and the archived docs in `docs/archive/`.

**How to read an entry:** date/era · decision · reason · superseded-by (a link to the
later entry when the decision was overturned). Entries whose rationale could not be
recovered from any doc or commit message are marked `RATIONALE: unconfirmed`.
Closed rulings must never be relitigated (INVARIANTS #10); pending rulings must never
be implemented from memory — see [conventions.md](conventions.md#decisions_resolved-process).

---

## Era A — Angular prototype (pre-April 2026)

### A1. The game was first built as an Angular web app
- **Decision:** Overload Protocol's original prototype lived in the separate
  `overload-protocol` Angular repo (`game-state.service.ts`, `combat.service.ts`,
  `dice.service.ts`, etc. — system map preserved in
  `docs/archive/ANGULAR_TO_GODOT_MAPPING.md`).
- **Reason:** rapid web prototyping of the core loop before committing to an engine.
  `RATIONALE: unconfirmed` (predates this repo's history).
- **Superseded by:** [B1](#b1-port-to-godot-46).
- Era artifacts that outlived it: **landscape orientation**, **4-unit squads**,
  **"Systems Medic"**, and "Phase 0 shell" language in the oldest docs — all now
  adjudicated stale (TRUTH.md §Doc adjudications).

## Era B — the Godot port (April – mid-June 2026)

### B1. Port to Godot 4.6
- **Date:** initial commit `253ee07`, 2026-04-14.
- **Decision:** rebuild the game in Godot 4.6, portrait mobile-first (Android),
  1080×2400 internal; the Angular app becomes reference-only.
- **Reason:** mobile-first target; the Angular build was a prototype, not a shippable
  phone game (archive mapping doc: "trust the Godot repo first for what is live").
- **Superseded by:** — (still canon). Follow-ups: Angular *app code* deleted
  2026-06-20 (`043f702` "Remove the Angular prototype and clarify that
  legacy-angular is assets-only"); `legacy-angular/` frozen as an asset warehouse
  (INVARIANTS #11 — never revive app code there).

### B2. Squad size 4 → 3
- **Date:** by `5715774` 2026-04-16 ("Prototype compact three-unit battle UI");
  formalized in docs `05bd081` 2026-06-19.
- **Decision:** squads are 3 heroes (`GameState.SQUAD_UNIT_LIMIT := 3`,
  `scripts/autoloads/GameState.gd:75`), replacing the Angular-era 4-unit squad.
- **Reason:** portrait-phone readability — three cards + dice + readouts is what fits
  the five-band layout at phone scale. `RATIONALE: unconfirmed` beyond the commit
  title (the decision predates the doc trail; every later doc treats 4-unit claims
  as stale).
- **Superseded by:** — (locked; see [heroes.md](heroes.md)).

### B3. Portrait orientation, 1080×2400
- **Date:** early Godot era; docs reconciled `05bd081` 2026-06-19.
- **Decision:** portrait 1080×2400 internal viewport, `canvas_items` stretch,
  five-band battle layout. Landscape (Angular-era GDD claim) is dead.
- **Reason:** thumb-first mobile play; the five stacked bands (header / enemy rail /
  center / hero rail / footer) require portrait. Layout later frozen as a contract
  (INVARIANTS #11).
- **Superseded by:** — (preview *window* later changed, see [I5](#i5-half-scale-preview-540x1200--even-stroke-rule)).

### B4. Battle scene split, round 1
- **Date:** `e83dded`/`5778d41`/`62f34dd`, 2026-06-19.
- **Decision:** extract `battle_layout.gd`, `battle_card_view.gd`,
  `battle_feedback.gd` from `battle_scene.gd`.
- **Reason:** god-object growth; first structural containment of `battle_scene.gd`
  (later judged incomplete by the July architecture review — the helpers reached
  back with `_scene.` 95 times).
- **Superseded by:** extended by [H8](#h8-protocolactions-extraction--phase-enum).

## Era C — Task-queue era: economy, XP, Direction-05 UI (June 20–24, 2026)

### C1. Protocol economy pinned (cap 10, start 0, costs 1/2/3, item flat 1)
- **Date:** `dbe4ff5` 2026-06-20 (Task 10 pass A); Set-a-die added `da8f25b`.
- **Decision:** `MAX_PROTOCOL` 7 → **10**; battles start at **0** (was 3);
  Nudge effect +5 → **+3** (cost stays 1); items cost **flat 1** for all rarities
  (was 0/1/2/3 by rarity); Reroll 2; Set-a-die 3.
- **Reason (commit):** economy tuning — the UI already had 10 protocol lights; flat
  item cost removes rarity bookkeeping from the spend decision.
- **Superseded by:** — (verified in TRUTH §Protocol economy). See
  [protocol-economy.md](protocol-economy.md).

### C2. Enemy summons replace dead slots, gated on nat 20
- **Date:** `0199fbe` 2026-06-20.
- **Decision:** summons fill the first dead enemy slot (living cap 3) and require an
  overload natural 20 with `can_summon_elite` (`ai_type == "smart"`).
- **Reason (commit):** stop summons from appending past the layout cap; make elite
  reinforcement a telegraphed, rare event.
- **Superseded by:** — (the `ai_type` gate is now INVARIANTS #2).

### C3. Sliding reward-rarity ladder; battle 5 = relic-only
- **Date:** `9b9c1db` 2026-06-21 (ported from the Angular methodology).
- **Decision:** per-round rarity table (`DRAFT_RARITY_BY_ROUND` in `GameState.gd`),
  three independent slot rolls, relics never before round 5, round 5 relic-only.
- **Reason:** early runs shouldn't be solved by day-one legendaries; the rarity curve
  accelerates into the fight-5 relic + evolution spike (`docs/reward-draft-rarity.md`
  §Design intent).
- **Superseded by:** — (SUPPLY GRADE fork modifier later shifts the ladder +2 rows).
  See [rewards-and-shop.md](rewards-and-shop.md).

### C4. Direction-05 "Dithered Terminal" UI; PixelUI single source of truth
- **Date:** `da54e74`…`cfc04b6` 2026-06-21 (merge "Direction-05 battle HUD");
  `c3cd9f7` UiTheme → PixelUI migration.
- **Decision:** all visual constants live in `PixelUI`
  (`scripts/ui/pixel_ui.gd`, `DT_*` palette); the old `Theme` autoload is deleted;
  `theme_overload.tres` only mirrors PixelUI. Protocol color moved **green → amber**
  (`DT_AMBER`, was `PROTOCOL_GREEN`); green reserved for HP/heals.
- **Reason:** the `Theme` autoload name collided with Godot's built-in `Theme` type;
  scattered hex literals made restyling impossible; meaning-based color needed green
  freed up for HP-only (later INVARIANTS #7).
- **Superseded by:** — (see [conventions.md](conventions.md#pixelui-token-system)).

### C5. D2 evolution XP model
- **Date:** `4325bc1` 2026-06-21.
- **Decision:** per battle win, alive → `20 + round(avg effective roll)` XP, dead →
  `round(avg effective roll)`; evolve at 100 XP; **one progression stop per win**,
  extras deferred FIFO.
- **Reason:** ties progression to actual dice performance while guaranteeing steady
  pace (first evo ~fight 3–4); one-stop-per-win keeps the post-battle flow short
  (TASK_QUEUE §Evolution XP D2 pinned design).
- **Superseded by:** — (Directives at 250 XP extend it, [E6](#e6-pkg6--directives-tier-3-passives-at-250-xp)).

### C6. EffectPip centralization / unified long-press InspectPopup / hover tooltips deleted
- **Date:** `7b107f6` (pips), `bcbcfcb`–`1f8871a` (inspect), `6861232` (tooltip
  removal), 2026-06-22/23.
- **Decision:** all effect pips build through `EffectPip`
  (`scripts/ui/effect_pip.gd`); one long-press InspectPopup replaces per-widget
  tooltips and the old detail panel.
- **Reason:** notation/icons/colors must be identical everywhere
  (`docs/EFFECT_PIP_GUIDE.md`); hover doesn't exist on touch.
- **Superseded by:** —.

### C7. Consumables capped at 3 with swap-out
- **Date:** `75c0d76` 2026-06-29.
- **Decision:** inventory holds max 3 consumables; picking a 4th at rewards forces a swap.
- **Reason:** `RATIONALE: unconfirmed` (commit title only; consistent with the
  legibility doctrine — a bounded loadout reads at a glance).
- **Superseded by:** —. See [items-and-gear.md](items-and-gear.md).

## Era D — systems polish: dice physics, HP preview, architecture review (late June – July 1, 2026)

### D1. Dice physics overhaul — hand toss, frozen dice as static blockers
- **Date:** `82af658` 2026-07-01, refined `04d9800`.
- **Decision:** real rigid-body hand-toss model: low flat launch, camera-matched
  sloped tray walls (8° lean), zero air drag + felt-grab damping, engraved numerals;
  **frozen dice are immovable static bodies at full collision size**; contact shadows
  and roll SFX removed on user direction. Regression gate:
  `DiceTrayPhysicsProbe.tscn` must stay 0 penetrations / 0 flyovers.
- **Reason:** dice must read like tabletop dice, and frozen dice must *physically*
  read as blockers (GDD §6 pinned decisions); immovable-over-pushable because result
  rows sit near tray edges and pushable frozen dice drift out of their slots.
- **Superseded by:** —. See [dice-and-rolls.md](dice-and-rolls.md).

### D2. Capped die lands its effective face once (Option A)
- **Date:** Jun 2026 (TASK_QUEUE "Capped die for RFE — Done").
- **Decision:** the tray lands the **effective** face at settle; raw roll kept
  separately for crit/overload rules. The post-roll "snap" pass was removed.
- **Reason:** rolling a raw face then visibly snapping it read as a double roll.
- **Superseded by:** —.

### D3. HP preview = net-outcome projection, not sequential slabs
- **Date:** `6f36d2c` 2026-07-01.
- **Decision:** during targeting, a card's HP bar shows one projected endpoint in
  true resolution order (hero heals/shields → enemy damage → burn tick); red = net
  loss, mint = net gain, blue = loss the shield prevents; label `cur → net / max`.
  Intermediate states deliberately not shown.
- **Reason:** resolution order is fixed, so mid-round numbers carry no decision the
  endpoint doesn't; the old sequential slabs painted contradictory futures (three
  playtest bugs — GDD §7, TASK_QUEUE HP-preview handoff).
- **Superseded by:** —. See [combat-resolution.md](combat-resolution.md).

### D4. Architecture review verdicts — ECS rejected, sim engine decision queued
- **Date:** `b366a07` 2026-07-01 (`docs/ARCHITECTURE_REVIEW_JUL2026.md`).
- **Decision:** keep the dictionary-state + choke-point architecture; **reject
  ECS/typed-component rewrite** (= **K5** in DECISIONS_RESOLVED); split the
  `battle_scene.gd` god object instead; resolve the two-engine problem (GDScript vs
  TypeScript sim).
- **Reason:** 3v4 units and ~20 status keys don't amortize a paradigm migration; the
  BattleEngine seam already decouples what mattered.
- **Superseded by:** — ; the sim decision landed as [F1](#f1-gdscript-becomes-the-only-rules-engine-ts-sim-deleted),
  the split as [H8](#h8-protocolactions-extraction--phase-enum).

## Era E — the master packages 1–9 (2026-07-02): rules foundation → close-out

One-day mega-pass; each package ends with doc hygiene in the same commit
(the habit that became doc supremacy, INVARIANTS #10).

### E1. pkg1 — rules foundation
- **pkg1.1 DoT/poison → Burn, game-wide** (`7122fb0`): one universal DoT name;
  `dot/dT` → `burn/burnT` across data/schemas/code/UI/sim; keyword id `dot` → `burn`;
  **dotFlavors (Venom/Decay) deleted** — ability flavor *names* unchanged.
  Reason: one name for one mechanic; flavors added vocabulary without rules.
- **pkg1.2 Shields last one round; `shT` removed; `shieldsPersist` hook added**
  (`84d8192`): granted this round, absorb through the opposing phase, gone at the
  round-end tick; enemy-phase grants survive one tick (`survives_current_tick`) so
  they cover exactly one hero phase. Single exception: `shieldsPersist` (Mantle Core
  relic / MANTLE TYRANT). Reason: multi-turn shield durations were unreadable;
  per-side expiry keeps enemy shields meaningful. Confirmed by Kev as **DECISIONS #2**
  (2026-07-07, zero data offenders). See [shields-and-ward.md](shields-and-ward.md).
- **pkg1.3 Cower merged into Freeze** (`8156c53`): one keyword, both sides;
  `cowerT`/`cowerAll` deleted; cosmetic `freeze_flavor` channel added (ice /
  petrify — the Accretion stone flavor). Reason: cower was freeze with a second
  name. The freeze *timing* chosen here (hero freeze cancels the imminent action)
  started the freeze lineage — superseded by [F2](#f2-freeze-lineage-bankthaw--lockout--repeat).
- **pkg1.4 Counterspell-% → Ward** (`eb98e43`): deterministic boolean status —
  blocks the next ability that targets the unit, then breaks; AoE blocked for that
  unit only. Reason: percent-reflection was random and AoE-bypassable; ward is
  deterministic and blocks the *whole* ability. Superseded (display name only) by
  [G2](#g2-ward--firewall-enemy-instances-culled-17--10).
- **pkg1.5 XP consumables removed** (`66e5075`): Training Datachip / Field Manual /
  Mnemonic Core deleted with the `xpBoost` handler. Reason:
  `RATIONALE: unconfirmed` (commit records the removal only; consistent with XP
  being a performance reward, not a purchasable).
- **pkg1.6 Max-one-manual-pick rule, audit-enforced** (`1035324`):
  `audit_ability_keywords.py` fails any hero ability demanding more than one manual
  pick; `shieldLowest`/`healLowest` auto-targets added so kits comply. Reason: touch
  flow — one die tap → at most one target tap (later INVARIANTS #12).

### E2. pkg2 — the keyword engine
- **Date:** `fb6d480`…`aea88aa` 2026-07-02.
- **Decision:** twelve keywords with one handler + one `keywords.data.json` def +
  one pip code each: Chain, Detonate, Execute, Breach, Leech, Mark, **Spike**
  (`cfc4958` — the in-round retaliation keyword; the concept previously called
  *retaliate* in kit text became Spike, later carried by Spine Stalker / Carapace
  Beetle / Basalt Ape / Volt Elite), Jam, Rewrite, Hijack (enemy-only),
  Siphon (enemy-only), plus the Cloak rework (`2672be6` — untargetable /
  breaks-on-damage-or-AoE / **first attack from cloak gains Pierce**).
  **One keyword per ability; two allowed in overload** (`7722245`, audit-enforced).
- **Reason:** replace ad-hoc riders with a legible, auditable vocabulary; the
  overload exception lets the 20 feel special without breaking band legibility
  (later INVARIANTS #3).
- **Superseded by:** cloak's third clause removed in [G3](#g3-cloak-simplified-to-2-clauses-k1);
  jam cap re-tuned in [G4](#g4-jam-cap-12--10-k4). See [keywords.md](keywords.md).

### E3. pkg3 — content rebuild + the renames
- **pkg3.1 All 8 hero kits + 16 evolutions replaced** (`2474b93`):
  **Spite Guard → Spike Guard** (callsign SPIKE; taunt/spike/breach identity —
  internal id stays `shield`, frozen); **Cryo Specialist → Arc Specialist**
  (Pulse's second evolution becomes chain-focused); new rider `vsFrozenBonus`
  (Shatter Lance). Reason: kits rebuilt around the pkg2 keyword identities; Spike
  Guard renamed to match its new spike keyword identity; Arc replaced Cryo because
  freeze belongs to the Avalanche line only (one control identity per hero —
  TRUTH §heroes legacy quirks).
- **pkg3.3 Faction renames + enemy kit rework** (`3b16f36`):
  **Void Circlet → Null Synod** (SYNOD), **Stellar Menagerie → The Accretion**
  (ACCRETION) — *internal operation ids `voidCirclet` / `stellarMenagerie`
  unchanged, frozen* (INVARIANTS #11). Unit renames in lockstep (Void Reaver →
  **MANTLE TYRANT**, Circlet Hierophant → **ROOT HIEROPHANT**, Chronicle Scribe →
  Checksum Scribe, Eclipse Panther → Geode Panther, Thunder Ape → Basalt Ape, etc.).
  Callsigns capped at 8 chars (schema `maxLength`). Kits re-riddered to faction
  identities (numbers preserved). Reason: faction mechanical identities (Synod =
  dice-attack machine cult; Accretion = igneous accrete/petrify beasts) needed names
  that state the identity. See [factions.md](factions.md), [enemies.md](enemies.md).
- **pkg3.4/3.5/3.6:** gear pool replaced + runtime band overrides (`2211dfd`);
  relic pool + 5 boss relics (`248ada0`); **items once-per-effect cleanup**
  (`0d9ff44` — one entry per behavior, ladders kept). See
  [relics.md](relics.md), [items-and-gear.md](items-and-gear.md).

### E4. pkg4 — boss phase-2 deleted; standing rules replace it
- **Date:** `3b2f159` + `2453d7b` 2026-07-02.
- **Decision:** the entire phase-2 system (dmgP2/shieldP2/pThr/p2Revive*, PHASE 2
  chip, phase2 events) deleted; each boss gets ONE always-on standing rule from
  turn 1 (`combat_manager.BOSS_STANDING_RULES`): SCRAPMASTER/ASSEMBLY LINE ·
  Matriarch/THE BROOD · OVERSEER/THE COURT · HIEROPHANT/ROOT ACCESS ·
  TYRANT/ACCRETION.
- **Reason:** flat stat jumps at an HP threshold are invisible rules; a standing
  rule is one sentence the player can plan around from turn 1 (legibility doctrine,
  INVARIANTS #5/#6). SCRAPMASTER's rebuild rehomed the old revive plumbing.
- **Superseded by:** ASSEMBLY LINE cadence refined by **DECISIONS #5**
  ([I1](#i1-decision-batch-closeout-2-5-12-16)). See [bosses.md](bosses.md).

### E5. pkg5 — SaveManager + Starting Directive
- **Date:** `a839609`/`c008601`/`6a7ebd3` 2026-07-02.
- **Decision:** `SaveManager` autoload, `user://save.json` save_version 1 (stats,
  unlocks, boss relics); boss relics unlock on first op clear and are offered as a
  **Starting Directive** at DEPLOY (a directive run ends with two relics by design);
  headless runs stay in memory and read fully unlocked.
- **Reason:** cross-run *unlocks* were pulled into scope (persistent XP stays out);
  boss relics as starting picks give clears a durable reward without a meta-XP
  system. See [save-system.md](save-system.md), [relics.md](relics.md).

### E6. pkg6 — Directives (tier-3 passives at 250 XP)
- **Date:** `ec722d9`/`953dcff` 2026-07-02.
- **Decision:** evolved units keep earning XP; at 250 the evolution screen offers 1
  of 2 path-scoped directives (32 total across 16 paths).
- **Reason:** extends the D2 one-stop-per-win progression into the back half of a
  run without new screens. See [directives.md](directives.md).

### E7. pkg7 — run structure: templated slots, beats, forks, intercepts
- **Date:** `7ee068a`…`fb46a61` 2026-07-02.
- **Decision:** battle comps are fixed anchors (b1, faction signature, boss+escort)
  or slot patterns rolled ONCE at run start; exactly 3 random beats per run in
  distinct gaps from {after b2,b3,b4,b6,b7,b8}, Fork/Intercept 50/50 with ≥1 of
  each, b6+ major; battle-5 relic draft renders as INTERCEPT: RELIC CACHE; 10 fork
  modifiers; 22-card intercept deck drawn without replacement.
- **Reason:** previews must always show exact comps (determinism + honesty); the
  relic battle's gap is structurally excluded from beats so the draft can't collide.
- **Superseded by:** —; hardened by the battle-5 soft-lock fix
  ([H9](#h9-battle-5-relic-cache-soft-lock--choicescreenguard)). See
  [beats-and-events.md](beats-and-events.md).

### E8. pkg8.1 — chip doctrine (the shield-chip cut) and the intent badge
- **Date:** `44d38fd` 2026-07-02.
- **Decision:** card chips restricted to Burn / Mark / ±Roll / Ward (cap 3, +N
  overflow); **shield, cloak, rampage chips removed**; die statuses render on the
  die; **"◎N" incoming-intent badges** added to cards.
- **Reason:** chip real estate at 450×1000 — statuses that have a better surface
  (die crust, ghosted portrait, readout pip) shouldn't spend a chip slot.
- **Superseded by:** the intent badge was **removed** at `7305a34` (2026-07-05,
  player-reported "not the intended treatment"); the **shield chip cut was REVERSED**
  by Kev — **DECISIONS #16**, restored `d606784` 2026-07-07. Current chip set:
  Burn / Shield / Mark / ±Roll / Firewall / Taunt. See
  [statuses-and-chips.md](statuses-and-chips.md).

### E9. pkg9 — close-out
- **Date:** `6c54c91` + merge `dcced82` 2026-07-02.
- **Decision:** TASK_QUEUE closed ("everything Done or superseded"); the only open
  lane is the balance pass; per-op run gate added.

## Era F — balance-sim decoupling + the freeze churn (2026-07-05)

### F1. GDScript becomes the ONLY rules engine; TS sim deleted
- **Date:** sim packages A–E, `44a31b2`…`497cd33` 2026-07-05; deletion at
  `a864ad6` ("determinism gate + delete legacy JS sim").
- **Decision:** extract `BattleEngine` (shared rules seam), add the
  `RollProvider` seam (seeded + physics), build the headless `sim_runner`, policy
  bots (L0 random `169dc38`, L1 greedy `653a49d`, L2 solver `2ea7a38`), CI balance
  regression (`497cd33`), and delete the duplicated TypeScript sim.
- **Reason:** the architecture review §2 verdict — two rules engines meant every
  keyword written twice or the sim silently lies; option (b) "one source of truth
  forever" won. The determinism fence (INVARIANTS #1) exists to keep this
  trustworthy; `58450f7` seeded the global RNG per run to close the last hole.
- **Superseded by:** —.

### F2. FREEZE lineage: bank/thaw → lockout → REPEAT
The most-relitigated mechanic in the project; full lineage preserved in
DECISIONS_RESOLVED #1 so no future agent resurrects a dead model.
1. **pkg1.3 merge reading** (`8156c53`, 2026-07-02): hero freeze cancels the
   enemy's *imminent* action; enemy freeze locks the hero's next reveal.
   Superseded ↓
2. **Next-turn static lockout** (`67d95b6`, 2026-07-05): symmetric — freeze locks
   the target's NEXT reveal; the unit still acts the round it is frozen, then skips
   N reveals with the die static. Reason: the pkg1.3 immediate-cancel read as
   *broken* freeze (crust fell off a round early). Superseded ↓
3. **Bank/thaw banked-face model** (fix-1.4 `69293c6`, 2026-07-05): the frozen face
   is "banked"; thaw reveals the banked value once; Glacial Lattice became
   `freezeAnyDice`. Reason: an attempt to make the frozen face *matter*.
   **Killed the same day** ↓
4. **Revert to static lockout** (`7305a34`, 2026-07-05, per Kev): bank/thaw made
   the die visibly "roll then change back" — reverted to the lockout Kev confirmed
   worked; all thaw machinery deleted. Superseded ↓
5. **FREEZE = REPEAT** (`52e2fa5`, 2026-07-06, **Kev, FINAL — DECISIONS #1**): the
   frozen die keeps its face and its unit **acts again on that result** for N
   repeats, then thaws; targeting re-picked each repeat; frozen dice immune to
   Jam/Rewrite/Hijack and to Reroll/Set/Twin-Fates; non-damage freezes are
   `freezeAnyDice` (freezing an ally repeats a good roll on purpose); enemy AI
   freeze targets the hero's LOWEST revealed die, deterministically.
   **Reason:** restores the original design intent; "keeps its face; the unit acts
   again on it" fits one sentence — bank/thaw never did (INVARIANTS #5 cites this
   twice-killed precedent). Landed **without** re-baselining: overall clear
   0.530 → 0.253, Avalanche 0.798 → 0.132 — reported under the ±10 ceremony, not
   self-approved (INVARIANTS #9 precedent).
- See [keywords.md](keywords.md), [dice-and-rolls.md](dice-and-rolls.md).

### F3. Enemy roll-buff recast refresh (fix-1.2) — later replaced
- **Date:** `618f8f3` 2026-07-05.
- **Decision:** enemy `erb` re-casts refresh instead of stacking unbounded.
- **Reason:** unbounded stacking broke Synod chains.
- **Superseded by:** **DECISIONS #3** independent instance timers
  ([H2](#h2-engine-semantics-batch-1-3-4)) — refresh-to-max deleted for both sides.

### F4. Detonate permanent-burn cap (sim-discovered) — later replaced
- **Date:** `85ae1d9` 2026-07-05 (`DETONATE_MAX_TURNS` cap).
- **Decision:** cap the permanent-burn detonate burst via a max-turns constant.
- **Reason:** the balance sim found plagueProtocol + Detonate one-shotting.
- **Superseded by:** **DECISIONS #4** — one tick, not consumed
  ([H2](#h2-engine-semantics-batch-1-3-4)); the cap was "a data-derived placeholder,
  not a rule anyone could state".

## Era G — the keyword batch + terminal UI + unlocks (2026-07-06)

### G1. Hijack becomes a Synod signature (Task 3)
- **Date:** `b294547`.
- **Decision:** hijack placed on voidScribe (Checksum Copy, surge) and voidGlimmer
  (Afterimage, crit); NOT on ROOT HIEROPHANT (Root Access owns its dice-attack
  slot); spewer's Mimic Gland left as a flagged future Hive-identity candidate.
- **Reason (commit):** hijack reads as a Synod mechanic; surge placement keeps the
  strike zone from being oppressive.

### G2. Ward → Firewall; enemy instances culled 17 → 10 (Task 8)
- **Date:** `376b5ad`.
- **Decision:** every player-facing surface says **Firewall** (code FW); internal
  field stays `ward` (frozen); enemy firewall instances culled to exactly 10
  (6 Veil + 4 Synod); hero-side firewalls renamed, not culled; WARDED route
  modifier → FIREWALLED.
- **Reason:** "Ward" read as fantasy vocabulary in a terminal-UI game; 17 instances
  diluted the Veil/Synod identity. See [shields-and-ward.md](shields-and-ward.md).

### G3. Cloak simplified to 2 clauses (K1)
- **Date:** `4474ab3` (Task 7).
- **Decision:** pierce-from-cloak REMOVED; cloak = untargetable by hostile
  single-target abilities + breaks on dealing damage or AoE hit.
- **Reason (K1 verbatim source):** one keyword was doing two jobs. Ghost post-nerf
  sim 43.5 → 50.8 — no compensation needed. Do not re-add.
- **Supersedes:** the pkg2.12 three-clause cloak ([E2](#e2-pkg2--the-keyword-engine)).

### G4. Jam cap 12 → 10 (K4)
- **Date:** `b219162` (Task 5).
- **Decision:** `JAM_CAP := 10` (`combat_manager.gd:1304`); Wall of Static's cap-15
  clause is a separate intentional exception.
- **Reason (K4):** 12 barely bit (most bands sit below it); 10 clips the surge band
  without deleting crit fishing.

### G5. Taunt unified, Lure deleted; targeting personalities (K3, Tasks 4+9)
- **Date:** `0bd652c`.
- **Decision:** ONE taunt keyword both directions ("The taunted unit can only
  target the taunter"); internal `lured_by_id` kept, every player-facing string
  says Taunt. Enemy targeting goes through ONE deterministic choke-point
  (`targeting_personality.gd::personality_pick_target`) with exactly 4
  personalities (SYSTEMATIC / WOUNDED / PACK / SPITEFUL), no `randi()`, stated
  fallbacks only; the "pure debuff → highest HP" special case REMOVED; `ai_type`
  left untouched and independent (INVARIANTS #2).
- **Reason:** two names for one rule; enemy AI must be a legible rule, not a mind
  (INVARIANTS #6). See [targeting.md](targeting.md).

### G6. Keyword-batch baseline accepted with voidCirclet +26 flagged (#17)
- **Date:** `3901e06`.
- **Decision (Kev):** baseline accepted at voidCirclet 42.1% → 68.4% (+26.3); a
  compensating Synod pass explicitly owed, folded into the post-semantics
  rebalance.
- **Reason:** the mechanics were correct (ward cull + hijack swap + SYSTEMATIC
  trash all point the same way); the *number* is a separate design decision.
  This incident became the ±10 baseline ceremony precedent (INVARIANTS #9).

### G7. Terminal UI overhaul + unlock system
- **Date:** `53ba832`.
- **Decision:** teal primary-button language, amber risk/confirm variant, green
  retired to HP only; hero ladder (5 rungs, ONE rung max per run end) + operation
  chain unlocks; locked content renders as black silhouettes + `[ LOCKED ]`, no
  hints; grandfather clause for veteran saves.
- **Reason:** cross-run unlocks pulled into scope (supersedes GROUND_TRUTH "out of
  scope"); one-rung-per-run mirrors one-evolution-per-win pacing.
- See [save-system.md](save-system.md).

## Era H — adjudication day: TRUTH, engine semantics, successor kit (2026-07-06)

### H1. TRUTH.md becomes canon; doc supremacy
- **Date:** `90b14c8`.
- **Decision:** `docs/TRUTH.md` wins every doc conflict; when TRUTH disagrees with
  code, code wins and TRUTH is fixed; behavior changes update TRUTH in the SAME
  commit; superseded docs archived to `docs/archive/`;
  `offline-bundle/GROUND_TRUTH.md` superseded.
- **Reason:** two generations of contradictory docs (landscape/4-unit era vs live
  code) kept misleading sessions. Later INVARIANTS #10.

### H2. Engine semantics batch (#1, #3, #4)
- **Date:** `52e2fa5` (per Kev 2026-07-06, FINAL).
- **Decisions:** **#1 Freeze = repeat** (see [F2](#f2-freeze-lineage-bankthaw--lockout--repeat));
  **#3 buff/DoT independent instance timers** — roll buffs and burn stop
  refresh-to-max; each application its own clock; value = sum of live instances;
  ONE display chip (summed value, longest clock); **#4 permanent-burn Detonate =
  one tick, not consumed** (`DETONATE_MAX_TURNS` deleted).
- **Reason (#3):** refresh-to-max made recast buffs read as permanent and burn
  stacking unpredictable; instances are the one-sentence rule. (#4): "one tick,
  keeps burning" is legible and can't one-shot.
- **Follow-up:** the three authored 1t roll buffs (Cover Field, Aegis Bash,
  Emergency Signal) were corrected to 2t (`0c160f6`) as **timer-contract repairs,
  not tuning** — under the new clock a 1t mid-round buff never shapes a roll.

### H3. The successor kit — INVARIANTS, DECISIONS_RESOLVED, enforcement hooks
- **Date:** `0331980`, extended `291f532`, `cd493b1`.
- **Decision:** `docs/INVARIANTS.md` (the WHY rules with violation examples);
  `docs/DECISIONS_RESOLVED.md` (all 17 numbered rulings + K1–K5; pending rulings
  must be transcribed VERBATIM before implementation); `scripts/verify_gate.py`
  (one-command gate + per-op delta table); git hooks — baseline ceremony (±10 pts
  needs `BASELINE-APPROVED-BY-KEV`), threshold ratchet (INVARIANTS #13: raising any
  enforcement threshold needs the token; lowering free; floors invert), battle_scene
  growth watermark (warn-only).
- **Reason:** durable judgment transfer — "future agents execute rulings; they do
  not relitigate them, and they do not carry rulings in chat memory." Precedents
  baked in: the 3378→3416 watermark self-raise, the voidCirclet +26, the silent
  loss of 6 audit recordings (→ `AUDIT_MIN_PASSED` floor).
- See [conventions.md](conventions.md#enforcement-hooks).

### H4. Keyword primer system
- **Date:** `d14da47`.
- **Decision:** one-shot micro-tutorials on first sighting of a mechanic; data-driven
  registry (`primers.data.json`), observer-only (never mutates combat), one per turn
  max, one sentence ≤ ~12 words / 90-char schema cap.
- **Reason:** teach twelve keywords without a wall of text; determinism fence
  requires observers, not participants.

### H5. Balance workbench + measurement doctrine
- **Date:** `b18a762` (workbench), `af86000`, `90accbe` (ability_field knobs).
- **Decision:** all deferred balance numbers are sweepable knobs
  (`scripts/sim/knobs.json`); numbers move together against the pinned target
  (25–40% skilled facility full-clear), never in isolation (INVARIANTS #8).
- **Reason:** voidCirclet +26 and freeze −27.7 both happened as side effects of
  correct changes — only whole-table measurement catches that.

### H6. Baseline checkpoints accepted (post-repeat, then crit-banking)
- **Date:** `f406540`, then `1bd0045` (both BASELINE-APPROVED-BY-KEV).
- **Decision (Kev, verbatim annotations in DECISIONS_RESOLVED):** post-repeat
  checkpoint 0.2533 accepted "pre repricing; Avalanche figure known biased low";
  after L1 learned crit banking (`fb11d8d`), crit-banking checkpoint 0.2867
  accepted — voidCirclet +10.5 ruled mechanically coherent (frozen dice immune to
  Rewrite/Hijack counters ROOT ACCESS; "the bot found the boss tech"); Avalanche
  23.7% remains the known repricing target; **no ability numbers move until that
  ruling**. Watch item: Breaker −3.5 (suspected policy artifact, two-measurement
  rule).

### H7. Reverse Gimbal UX confirmed (#11, ruled)
- **Decision (Kev, verbatim):** "tap again to flip +3/−3 ships as is."

### H8. ProtocolActions extraction + Phase enum
- **Date:** `a51e03b`, `aaba888`.
- **Decision:** protocol-spend subsystem extracted to
  `scripts/battle/protocol_actions.gd` (971 lines) behind a narrow interface; the
  13-state string phase machine promoted to a `Phase` enum with ONE `transition()`
  choke point; battle_scene watermark LOWERED 3416 → 2610 (free per INVARIANTS #13).
- **Reason:** architecture review §1 recs 1+2; string phases fail silently on typos.
- **Collateral precedent:** the extraction silently cost 6 audit recordings →
  `AUDIT_MIN_PASSED` floor in verify_gate (INVARIANTS #13 second precedent).

### H9. Battle-5 RELIC CACHE soft lock → ChoiceScreenGuard
- **Date:** `b2da2b9`.
- **Decision:** `GameState.drafted_relic_count()` unifies roll/pick/claim/title (a
  Starting Directive never consumes the battle-5 slot); **ChoiceScreenGuard** is a
  permanent fixture — any between-battle choice screen with ZERO options asserts in
  debug and auto-resolves a logged default in release. "A guard firing is always a
  bug in the offer roll — fix the offer, never widen the guard."
- **Reason:** two stale `relics.is_empty()` guards predating pkg5 rolled zero relic
  options when a run opened with a boss relic — a full soft lock.

## Era I — decision-batch closeout, portraits, UI precision (2026-07-07)

### I1. Decision batch closeout (#2, #5, #12–#16)
- **Date:** `27dfde9`…`d606784` (rulings transcribed verbatim first, per process).
- **#2 Shield per-side expiry CONFIRMED** (`a30a1ba`): as coded; data audit found
  zero offenders; `shieldsPersist` named the single exception in TRUTH rule 5.
- **#5 ASSEMBLY LINE cadence** (`ebe67bc`): counts from FIRST ACTIVATION (per-boss
  stamp), not even-numbered rounds; offset case regression-pinned.
- **#12 Cloak hostile-only untargetability CONFIRMED** (`60e1511`): friendly picks
  on cloaked allies always legal; stated in def + tooltip + TRUTH.
- **#13 Tutorial runs excluded from `runs_started`** (`8d80a41`): rung-1 pity
  unlock counts real runs only; banked tutorial runs grandfathered.
- **#14 Directive Marks stay single-target on AoE** (`781a1e1`): "never AoE Mark";
  zero data offenders; directive descs name the primary target.
- **#15 Mid-run re-equip REJECTED, not deferred** (`2714666`): the deterministic
  rotate-one-slot stand-in is permanent; do not build the re-equip UI.
- **#16 Shield chip RESTORED** (`d606784`): reverses the pkg8.1 cut per Kev; chip
  is canon, both sides, live at the per-side phase tick
  (supersedes [E8](#e8-pkg81--chip-doctrine-the-shield-chip-cut-and-the-intent-badge)).
- **#6–#10 + #17:** balance numbers recorded as **DEFERRED to the global balance
  pass** with file:line cites; every number untouched.

### I2. Evolution ids + portrait wiring conventions
- **Date:** `04399d4` + `993f63a`.
- **Decision:** each of the 16 evolution paths gets a stable `id` = lowercased
  callsign (schema-enforced); evolved portrait convention
  `assets/portraits/<hero_id>_<evo_id>.png` with silent fallback to base art;
  enemy portraits keyed by explicit map + slugified-display-name fallback;
  legacy-era portrait files renamed to current unit names (git preserves lineage);
  unreferenced art quarantined in `unused/`, kept not deleted.
- **Reason:** portrait resolution must be data-derived, never per-unit code.
  See [conventions.md](conventions.md#naming-schemes).

### I3. Matted-bust crop + final enemy art drops
- **Date:** `2adc06a`/`2daf48c`, art drops `84d3d40`–`19e34dc`.
- **Decision:** all portrait framing goes through the crop-to-content contract
  (`_crop_to_content`, cutout vs full-bleed auto-classification,
  `PixelUI.cover_fit_portrait()`); never per-unit pixel offsets. Slag Hound split
  onto its own file — no shared enemy art remains.

### I4. Pixel snap law (INVARIANTS #14)
- **Date:** `83ea384`.
- **Decision:** every ratio-derived UI position/size rounds to whole PHYSICAL
  window pixels via `PixelUI.snap_to_physical_px` / `physical_px_width` (the
  viewport FINAL transform, which `get_global_transform_with_canvas()` misses);
  snapped layers redraw on `viewport.size_changed`.
- **Reason:** the HP-notch defect — accumulated float ratios drew "1px" ticks that
  rendered 1px/2px/absent at preview scale.

### I5. Half-scale preview 540×1200 + even-stroke rule
- **Date:** `8f2da05` (TRUTH updated `e5cfdd7`).
- **Decision:** dev preview window changed 450×1000 → **540×1200 — exactly half**
  the design space; all stroke widths normalized to EVEN design pixels (2/4/6).
- **Reason (commit):** at 5/12 scale every 1–3px stroke landed on fractional window
  coordinates and each edge rounded independently (measured: one panel's 2px border
  rendered 2/1/0px on different edges); StyleBoxFlat borders can't be per-instance
  snapped, so the SCALE had to become integer-friendly. A 1080-native device is
  always exact.

---

## The adjudicated register (verbatim source: `docs/DECISIONS_RESOLVED.md`)

Numbers preserved from the TRUTH.md DECISIONS list. **Never relitigate; never
implement a pending ruling that hasn't been transcribed into DECISIONS_RESOLVED.md.**

| # | Ruling (condensed — the file holds the verbatim text) | Status |
|---|---|---|
| 1 | Freeze = REPEAT; full bank/thaw → lockout → repeat lineage preserved | RESOLVED & IMPLEMENTED (`52e2fa5`) |
| 2 | Shields: one opposing action phase, per-side expiry as coded; `shieldsPersist` sole exception | RESOLVED & IMPLEMENTED (2026-07-07) |
| 3 | Buff/DoT independent instance timers; sum of live instances; one display chip | RESOLVED & IMPLEMENTED (`52e2fa5`) |
| 4 | Permanent-burn Detonate = one tick, NOT consumed; `DETONATE_MAX_TURNS` dead | RESOLVED & IMPLEMENTED (`52e2fa5`) |
| 5 | ASSEMBLY LINE fires every 2nd enemy phase from first activation | RESOLVED & IMPLEMENTED (`ebe67bc`) |
| 6 | INTERCEPT_CARDS numbers (`GameState.gd:394`) | RULED — DEFERRED to global balance pass |
| 7 | Route modifier numbers (`GameState.gd:253`) | RULED — DEFERRED |
| 8 | Boss cadence numbers (`combat_manager.gd:107`) | RULED — DEFERRED |
| 9 | Execute bonus (`combat_manager.gd:1406`) | RULED — DEFERRED |
| 10 | Chain jump ratio (`combat_manager.gd:1474`) | RULED — DEFERRED |
| 11 | Reverse Gimbal: tap-again flip +3/−3 ships as is | RULED (confirmed) |
| 12 | Cloak blocks hostile single-target picks only; friendly picks always legal | RESOLVED & IMPLEMENTED (`60e1511`) |
| 13 | Tutorial runs excluded from `runs_started`; grandfathered | RESOLVED & IMPLEMENTED (`8d80a41`) |
| 14 | Directive Marks single-target only; never AoE Mark | RESOLVED & IMPLEMENTED (`781a1e1`) |
| 15 | Mid-run re-equip REJECTED; rotate-one-slot stand-in permanent | RESOLVED & IMPLEMENTED (`2714666`) |
| 16 | Shield chip restored as primary status chip, both sides | RESOLVED & IMPLEMENTED (`d606784`) |
| 17 | voidCirclet 68% accepted; compensating Synod pass owed → folded into balance pass; re-anchored to the crit-banking checkpoint | RESOLVED (deferred compensation) |
| K1 | Cloak = 2 clauses; pierce-from-cloak removed, do not re-add | shipped (`4474ab3`) |
| K2 | Pierce AND Breach both kept, distinct sentences; merge rejected | shipped (keyword batch Task 6) |
| K3 | Taunt unified, Lure deleted, both directions one sentence | shipped (`0bd652c`) |
| K4 | Jam cap = 10 (was 12); Wall of Static cap-15 an intentional exception | shipped (`b219162`) |
| K5 | ECS rejected; dictionary-state + choke-points stay; god-object split is the approved work | shipped (architecture review) |

## Rename / merge ledger (quick reference)

| Old | New | Where / when | Note |
|---|---|---|---|
| DoT / poison (Venom, Decay flavors) | **Burn** (single universal DoT) | pkg1.1 `7122fb0` | flavors deleted; ability flavor names kept |
| Cower | merged into **Freeze** | pkg1.3 `8156c53` | petrify = cosmetic `freeze_flavor` |
| Counterspell-% | **Ward** (deterministic) | pkg1.4 `eb98e43` | then displayed **Firewall** `376b5ad`; internal field `ward` frozen |
| Retaliate (kit concept) | **Spike** keyword | pkg2.7 `cfc4958` | carriers: Spine Stalker, Carapace Beetle, Basalt Ape, Volt Elite |
| Lure | **Taunt** (unified) | `0bd652c` | internal `lured_by_id` kept |
| Spite Guard | **Spike Guard** | pkg3.1 `2474b93` | id `shield` FROZEN (INVARIANTS #11) |
| Cryo Specialist | **Arc Specialist** | pkg3.1 `2474b93` | freeze belongs to Avalanche line only |
| Void Circlet | **Null Synod** | pkg3.3 `3b16f36` | id `voidCirclet` FROZEN |
| Stellar Menagerie | **The Accretion** | pkg3.3 `3b16f36` | id `stellarMenagerie` FROZEN |
| Void Reaver | **MANTLE TYRANT** | pkg3.3 `3b16f36` | portrait file renamed 2026-07-07 |
| Circlet Hierophant | **ROOT HIEROPHANT** | pkg3.3 `3b16f36` | |
| Systems Medic | **Splice Medic** | pre-TRUTH (adjudicated stale) | id `medic` FROZEN |
| Boss phase-2 stat jumps | **standing rules** | pkg4 `3b2f159`/`2453d7b` | one always-on rule per boss |
| 4-unit squad | **3-unit squad** | Godot port era `5715774` | |
| Green protocol bar | **amber** protocol pips | Direction-05 `c3cd9f7`+ | green = HP/heals ONLY |
| 450×1000 preview | **540×1200** (half-scale) | `8f2da05` 2026-07-07 | even-stroke rule |
| `dot`/`shT`/`cower*`/`counterspellPct`/`xpBoost`/phase-2 fields | deleted | pkg1/pkg4 | schema-enforced absent |

## File locations
- `docs/DECISIONS_RESOLVED.md` — verbatim rulings (the backbone of this log)
- `docs/TRUTH.md`, `docs/INVARIANTS.md` — canon + WHY rules
- `docs/SESSION_2026-07-06_engine_semantics.md` — the semantics-day session log
- `docs/ARCHITECTURE_REVIEW_JUL2026.md`, `docs/archive/*`, `offline-bundle/GROUND_TRUTH.md` — history
- `TASK_QUEUE.md` — the closed task ledger

## Known edge cases
- Rulings #6–#10 are RULED but the numbers are deliberately untouched until the
  global balance pass — treat every listed constant as provisional.
- The pkg8.1 shield-chip cut and the ◎N intent badge are both *reversed* decisions;
  do not cite pkg8.1 chip doctrine as current.
- `offline-bundle/GROUND_TRUTH.md` still contains superseded freeze/eff-text
  wording under its supersession banner — read TRUTH.md instead.

## ⚠ Open findings
<!-- AUDIT-LINKS:decision-log -->
- [A-096](../audit/INTERACTION_AUDIT.md#a-096) - [dead] TASK_QUEUE lists a landed rename as future work
