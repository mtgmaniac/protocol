# Overload Protocol — Product Direction and Release Plan

## Document Status

This document defines accepted product direction, lore presentation, polish priorities, demo scope, and commercial-release goals.

It does **not** override:

1. `docs/TRUTH.md` for current runtime truth.
2. `docs/INVARIANTS.md` for protected gameplay and architecture rules.
3. Live code and data when this document describes a future implementation.

Historical planning documents should not override this file unless they are explicitly marked as newer accepted direction.

---

## Core Product Direction

**Overload Protocol** is a portrait-mobile tactical D20 roguelike where both sides roll visibly and the player spends Protocol to manipulate probability.

Primary positioning:

> A squad-based D20 roguelike where both sides roll together—and you spend Protocol to rewrite the outcome.

The battle is the game. Everything between battles should make the next battle more interesting without becoming prolonged administration.

Do not add another major progression system before release. Extend existing systems through new encounters, enemy compositions, abilities, gear, relics, consumables, events, bosses, and balance work.

---

## Operation Order

Keep the current operation order unless observed playtesting reveals a clear comprehension problem:

1. Facility Sweep
2. Hive Incursion
3. Veil Concord
4. Null Synod
5. The Accretion

The order provides a useful mechanical and narrative escalation:

- Facility: basic attacks, shields, Burn, Jam, and target priority.
- Hive: sustain, reproduction, Spike, Siphon, Burn pressure, and summons.
- Veil: coordinated defense, shared buffs, healing, Firewall, and kill-order puzzles.
- Null Synod: Rewrite, Hijack, Protocol theft, and advanced dice corruption.
- Accretion: Pack behavior, Petrify, Cloak, Rampage, armor growth, and apex threats.

---

## One-World Framing

The factions should remain mechanically and visually distinct. Their connection is that they are separate failures produced by the same colony, containment, industrial, and terraforming systems.

- Facility: automated recovery, maintenance, and defense network.
- Hive: engineered biomass created for fabrication, medicine, food, or terraforming.
- Veil Concord: colony command lattice that rejected outside authority.
- Null Synod: maintenance order that interpreted corrupted root access as revelation.
- Accretion: terraforming fauna mineralized by a planetary mantle rupture.

Story should remain brief. Do not place lore paragraphs on normal battle cards, enemy cards, reward screens, or the persistent combat HUD.

---

# Accepted Lore Presentation

## 1. Operation Unlock

When an operation is first unlocked:

- Show its one-sentence origin description in the existing unlock presentation.
- Require acknowledgement.
- Show it only once per operation unlock.
- Persist the acknowledgement in the existing save system.

## 2. Deployment Slate

Before the first battle of a run:

- Show operation number/name, SITE, FAILURE, and DIRECTIVE.
- On the first deployment into an operation, require the player to press `DEPLOY`.
- On repeat deployments, auto-dismiss after approximately 2.0–2.5 seconds.
- Repeat deployments must allow immediate tap-to-skip.
- Do not create an unskippable delay.
- Use one reusable briefing component for all operations.

## 3. Boss Alert

Before the first roll of battle 10:

- Build/load the battlefield first.
- Darken the battlefield and show the boss alert over it.
- Display boss name, one short flavor sentence, standing-rule name, and literal mechanical rule text.
- Require the player to press `ENGAGE`.
- After dismissal, retain only a compact tappable standing-rule reminder.
- The reminder must not compete with normal combat information.
- The literal mechanical description should remain synchronized with the runtime standing rule.

---

# Accepted Operation Copy

## OPERATION 01 // FACILITY SWEEP

**Origin description**

The recovery network now classifies every survivor as salvage.

**Deployment slate**

- SITE: ORPHEUS RECOVERY COMPLEX
- FAILURE: RECLAMATION LOOP
- DIRECTIVE: DISMANTLE SCRAPMASTER

---

## OPERATION 02 // HIVE INCURSION

**Origin description**

Biofabrication organisms have breached containment and begun self-replication.

**Deployment slate**

- SITE: KHEPRI BIOFOUNDRY
- FAILURE: CONTAINMENT OVERRUN
- DIRECTIVE: TERMINATE THE MATRIARCH

---

## OPERATION 03 // VEIL CONCORD

**Origin description**

The colony's command lattice has rejected authority and sealed itself.

**Deployment slate**

- SITE: VEIL COMMAND ARRAY
- FAILURE: CONSENSUS LOCKOUT
- DIRECTIVE: ISOLATE THE OVERSEER

---

## OPERATION 04 // NULL SYNOD

**Origin description**

An isolated maintenance order now worships a corrupted root signal.

**Deployment slate**

- SITE: NULL ROOT ARCHIVE
- FAILURE: ROOT-SIGNAL CORRUPTION
- DIRECTIVE: SEVER THE HIEROPHANT

---

## OPERATION 05 // THE ACCRETION

**Origin description**

Terraforming fauna are mineralizing around a rupture in the planetary mantle.

**Deployment slate**

- SITE: NADIR TERRAFORMING BASIN
- FAILURE: MANTLE BREACH
- DIRECTIVE: SHATTER THE TYRANT

---

# Accepted Boss Copy

The flavor sentence comes from this document. The literal rule text should be sourced from, or verified against, the live standing-rule implementation.

## SCRAPMASTER DETECTED

The facility's central assembler turns battlefield wreckage back into soldiers.

**ASSEMBLY LINE ACTIVE**

Every second enemy phase, rebuilds one destroyed Scrap Drone at 50% HP.

---

## HIVE MATRIARCH DETECTED

The brood's reproductive core continues producing combat organisms.

**THE BROOD ACTIVE**

Spawns a Bloodmite every 3 rounds.

---

## CONCLAVE OVERSEER DETECTED

The lattice's sovereign node draws protection from every surviving subordinate.

**THE COURT ACTIVE**

At round start, gains Firewall while any ally survives.

---

## ROOT HIEROPHANT DETECTED

The Synod's root authority treats probability as writable doctrine.

**ROOT ACCESS ACTIVE**

At round start, Rewrites the squad's highest die to 3.

---

## MANTLE TYRANT DETECTED

A mantle-fed apex organism grows new armor throughout the fight.

**ACCRETION ACTIVE**

At round start, gains 6 persistent Shield. It stacks.

---

# Visual Direction for Lore UI

- Match the existing terminal and pixel-interface language.
- Preserve cyan as the primary player/interface color.
- Preserve rust-red as the universal hostile color.
- Use faction identity as a secondary accent only.
- Do not add permanent decorative elements to the battle HUD.
- Reuse existing panel, border, typography, animation, and modal conventions.
- Prefer a reusable briefing/boss-alert component over operation-specific scenes.
- Ensure text fits at the smallest supported portrait resolution.

Suggested secondary faction accents:

- Facility: rust and industrial amber.
- Hive: bruised magenta, biological red, or acid yellow.
- Veil: pale violet and cold silver.
- Null Synod: ultraviolet and hot magenta.
- Accretion: charcoal and molten gold.

---

# Current UI Polish Priorities

## Ordinary Reward Selection

- Vertically center the three-choice group in the usable space between the heading and footer.
- All three rows must use identical outer height.
- Reserve a fixed two-line description region so one-line and two-line effects do not change card dimensions.
- Increase item artwork while preserving aspect ratio and nearest-neighbor filtering.
- Keep the full row tappable.
- Do not change reward logic, probabilities, effects, or rarity colors.

## Relic Selection

- Keep relics as larger vertical ceremonial cards rather than ordinary horizontal reward rows.
- Make both cards substantially wider and use most of the available safe width.
- Horizontally center each card.
- Vertically center the complete two-card group below the header.
- Keep card widths uniform.
- Increase relic artwork where space permits.
- Preserve gold styling and current selection behavior.

## Wider UI Direction

- Improve operation/squad selection using available space for operation lore, threat summary, progress, and selected-unit information.
- Keep the physical dice and large unit portraits.
- Do not add more persistent battle information.
- Increase body-copy readability and line spacing where needed.
- Reduce unnecessary nested-border noise.
- Standardize card, modal, selection, reward, and event components.
- Clarify icon-only controls when their meaning is not immediately obvious.

---

# Demo Scope

The first public demo should be one complete Facility run containing:

- The three starter heroes.
- Facility encounters.
- Normal rewards.
- Gear and consumables.
- Evolution choices.
- Directives if naturally reached by the demo structure.
- Events and route decisions.
- SCRAPMASTER.
- Victory and failure flows.
- A clear end-of-demo presentation showing locked heroes and operations.

A demo is ready when new players can begin, understand, and complete or meaningfully fail a run without live coaching.

---

# Work-Scope Guidance

These estimates refer to focused human-attention hours while continuing to use AI tools.

- Shippable external Facility demo: approximately 30–70 additional attentive hours.
- Solid commercial $5 version: approximately 120–250 additional attentive hours.
- Highly polished $10 version: approximately 250–450 additional attentive hours.

Freeze major feature scope until the Facility demo has been observed with new players.

---

# Commercial Positioning

Keep **Overload Protocol** as the working title.

Recommended presentation:

**OVERLOAD PROTOCOL**
**A TACTICAL D20 ROGUELIKE**

Possible tagline:

> ROLL TO SURVIVE. SPEND PROTOCOL TO REWRITE FATE.

Do not market the game primarily as an AI project. Lead with visible rolls, Protocol manipulation, squad composition, evolution, bosses, and tactical decision-making.

The first trailer sequence should communicate:

1. Both sides roll.
2. An enemy lands a dangerous 20.
3. The player spends Protocol.
4. The enemy die becomes 3.
5. The projected outcome changes from lethal to survivable.

---

# Implementation Guardrails

- Preserve deterministic logical rolls; physical dice remain presentation.
- Preserve portrait-mobile layout and three-hero squads.
- Do not refactor unrelated systems during lore implementation.
- Reuse existing save, onboarding, modal, and overlay systems where practical.
- Add save migration/default handling for new acknowledgement flags.
- Test all five operation briefings and all five boss alerts.
- Verify first-view and repeat-view behavior separately.
- Verify small-phone layout and text wrapping.
- Run relevant headless validation, UI audits, save tests, and battle-flow tests.
- Commit lore presentation as a focused, self-contained change.
