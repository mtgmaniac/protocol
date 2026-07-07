# Overload Protocol — Knowledge Wiki

**The single source of truth map for agents and Kev.** Read this page, then the page for whatever you're touching, **before** editing any code, data, or doc. Every page states how a system works (code-accurate, with `file:line` cites), why it works that way, and what it replaced — so you don't relitigate a closed decision or resurrect a dead mechanic.

Doc precedence: [`docs/TRUTH.md`](../TRUTH.md) wins every doc conflict; when TRUTH disagrees with code, code wins and TRUTH gets fixed. This wiki cites both — where it disagrees with either, that's a bug in the wiki; fix the wiki. Closed rulings live in [`docs/DECISIONS_RESOLVED.md`](../DECISIONS_RESOLVED.md) and are mirrored in the [decision log](decision-log.md) — **never relitigate, never implement a pending ruling from memory**.

Known incoherences are catalogued in the [Interaction & Coherence Audit](../audit/INTERACTION_AUDIT.md); each wiki page carries a "⚠ Open findings" section linking to its findings.

---

## Read this first — the locked ground rules

Economy & core rules
- **Protocol:** start 0, +1 at end of every turn, cap **10**. Nudge **1** (±3), Reroll **2**, Set **3**. Consumable items cost **1 flat** (all rarities). → [protocol-economy.md](protocol-economy.md)
- **Squad size is 3.** → [combat-resolution.md](combat-resolution.md)
- **Shields expire after one round** (per-side "one opposing action phase" expiry; DECISIONS #2). No multi-round shield durations (`shT`) anywhere. Single named exception: `shieldsPersist` (Mantle Core relic / MANTLE TYRANT). → [shields-and-ward.md](shields-and-ward.md)
- **XP consumable items were removed entirely.** XP flows only from battle wins. → [rewards-and-shop.md](rewards-and-shop.md)
- **Max ONE manually-picked component per hero ability** (canonical example: Cover Fire = 5 dmg picked + auto 7 shield to lowest-HP ally). → [targeting.md](targeting.md)
- **One keyword per ability; overload faces may carry two** (pierce counts as a keyword). → [keywords.md](keywords.md)
- **Nat-20 overload fires the ability-name slam animation.** → [dice-and-rolls.md](dice-and-rolls.md)

Statuses & keywords
- **Persistent status chips:** burn, mark, ±roll, firewall (né ward), shield — see [statuses-and-chips.md](statuses-and-chips.md) for the doctrine (the Taunt chip's status is an open ruling — see the [audit](../audit/INTERACTION_AUDIT.md)).
- **DoT = Burn game-wide.** Venom/Decay flavors are dead. **Cower merged into freeze**; Accretion's cosmetic freeze flavor is **Petrify**. **Counterspell-% became deterministic Ward → displayed "Firewall"**. **Retaliate became spike** (carriers: Spine Stalker, Carapace Beetle, Basalt Ape, Volt Elite).
- **Instant keywords:** chain, detonate, execute, breach, leech, siphon (enemy-only). **Dice-attack statuses:** jam, rewrite, hijack. **Freeze = REPEAT** (DECISIONS #1). → [keywords.md](keywords.md), [dice-and-rolls.md](dice-and-rolls.md)
- **Shatter exists only** as the Glacier Mantle rider and the Cold Logic relic.

Content & structure
- **Factions (current names):** Null Synod (né Void Circlet), The Accretion (né Stellar Menagerie); the hero Spike Guard (né Spite Guard). Internal ids `voidCirclet`/`stellarMenagerie`/`shield` are frozen legacy keys (INVARIANTS #11) — display strings must use current names. → [factions.md](factions.md)
- **Bosses have standing rules, not phase-2 stat jumps** (e.g. Hive Matriarch's THE BROOD spawns a Bloodmite every 3 rounds). → [bosses.md](bosses.md)
- **Beats:** relic draft after b5 in event chrome; exactly 3 random beats per run; 10 fork modifiers; 22-card intercept deck; battle slots templated with fixed anchors (b1, faction signature, boss + escort). → [beats-and-events.md](beats-and-events.md)
- **32 directives at 250 XP** (2 per evolution path). Boss relics + Starting Directive exist. → [directives.md](directives.md), [relics.md](relics.md)
- **SaveManager autoload** owns `user://save.json` per the save spec. → [save-system.md](save-system.md)
- **Pulse Tech:** chain on Static Ping + Singularity Burst; the Cryo Specialist evolution was replaced by **Arc Specialist**. → [heroes.md](heroes.md)

---

## Page map

### Systems
| Page | Covers |
|---|---|
| [combat-resolution.md](combat-resolution.md) | Turn structure, phase order, resolution pipeline, death timing, status ticks, order of operations |
| [dice-and-rolls.md](dice-and-rolls.md) | D20 zones, effective-roll math, nudge/reroll/set, jam/rewrite/hijack, freeze=repeat, determinism fence |
| [protocol-economy.md](protocol-economy.md) | Income, cap, costs, every +protocol source and sink, discounts, overflow |
| [statuses-and-chips.md](statuses-and-chips.md) | Chip doctrine, persistent statuses, independent instance timers, stacking |
| [keywords.md](keywords.md) | One section per keyword with exact resolution timing, carriers, history |
| [targeting.md](targeting.md) | The 4 enemy personalities, choke point, taunt/cloak overrides, manual-pick rules |
| [shields-and-ward.md](shields-and-ward.md) | Shield grant/absorb/per-side expiry, shieldsPersist, Firewall block semantics |
| [beats-and-events.md](beats-and-events.md) | Beat scheduling, route forks + 10 modifiers, 22 intercept cards, zero-options guard, slot templates |
| [rewards-and-shop.md](rewards-and-shop.md) | Reward drafts, rarity ladder (SUPPLY GRADE sliding), relic cache, gear equip, XP awards |
| [save-system.md](save-system.md) | Save schema, hero ladder, operation chain, grandfather clauses, primers_seen, dev tools |
| [directives.md](directives.md) | All 32 tier-3 passives: handlers, coded effects, text |
| [bosses.md](bosses.md) | Per-boss standing rules with cadence + code cites, escorts, phase-2 history |
| [factions.md](factions.md) | 5 factions: identity, mechanical theme, naming history, frozen internal ids |

### Content catalogs
| Page | Covers |
|---|---|
| [heroes.md](heroes.md) | All 24 kits (8 base + 16 evolutions), every ability, callsigns, evo paths, unlocks |
| [enemies.md](enemies.md) | All 38 unit defs: stats, kits, keywords, targeting personality, ai_type, summons |
| [relics.md](relics.md) | All 35 relics (30 draftable + 5 boss): effects, handlers, triggers |
| [items-and-gear.md](items-and-gear.md) | 25 consumables + 31 gear: effects, handlers, rarities |
| [operations.md](operations.md) | 5 operations: battle-slot templates, anchors, unlock chain |

### Meta
| Page | Covers |
|---|---|
| [conventions.md](conventions.md) | Data formats, eff-text grammar, naming schemes, hard rules (keyword budget, one-pick, chip doctrine, determinism fence, pixel snap law), enforcement hooks, verify commands |
| [decision-log.md](decision-log.md) | Chronological log of every reconstructable design decision: date/era, decision, reason, superseded-by |
| [../audit/INTERACTION_AUDIT.md](../audit/INTERACTION_AUDIT.md) | The Interaction & Coherence Audit: all findings, severity table, needs-Kev-ruling list, coverage checklist |

---

## How to use this wiki (agents)

1. **Before any change:** read this page + the system page(s) you're touching + [conventions.md](conventions.md).
2. **Before proposing a mechanic change:** check [decision-log.md](decision-log.md) and `docs/DECISIONS_RESOLVED.md` — if it was ruled, don't relitigate.
3. **Before "fixing" something odd:** check the [audit](../audit/INTERACTION_AUDIT.md) — it may be a known finding awaiting a ruling, or intentional.
4. **After any behavior change:** update `docs/TRUTH.md` in the same commit (INVARIANTS #10), and update the affected wiki page(s).
