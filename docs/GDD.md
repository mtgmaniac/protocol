# Overload Protocol — Game Design Document

> **Agents:** Prefer `docs/AI_AGENT_GAME_REFERENCE.md`, `docs/BATTLE_UI_V2_SPEC.md`, and `offline-bundle/GROUND_TRUTH.md` for runtime truth. This GDD is design context; when it conflicts with code/data, ground truth wins.

**Version:** 0.3 (Active Development)
**Platform:** Mobile First (Android), portrait 1080×2400 (preview 450×1000)
**Engine:** Godot 4.6
**Developer:** Solo (Kev)
**Status:** Battle loop running; ongoing combat/UI/content work

---

## 1. Vision Statement

Overload Protocol is a dark sci-fi tactical dice roguelike where you command a squad of three specialists against increasingly dangerous alien threats. Every run is a 15–30 minute puzzle of dice manipulation, squad synergy, and risk management. Inspired by the pure mechanical tension of Slice & Dice, the run structure of Slay the Spire, and the dark unit identity of Starcraft.

**Core feeling:** Tense, satisfying, and skilful. The player should feel like they earned every win and understand every loss.

---

## 2. Core Pillars

| Pillar | What it means |
|---|---|
| **Tactical tension** | Every dice roll matters. Every decision has consequences. |
| **Squad identity** | Your 3 units feel distinct and synergize in meaningful ways. |
| **Run variety** | Who you pick, what you fight, and what items you find create different runs. |
| **Readable chaos** | Dice are random but manipulable. The player always has agency. |

---

## 3. Aesthetic

- **Tone:** Dark, gritty, cold. Space gothic. Think Starcraft meets Dead Space.
- **Palette:** Deep blacks, metallics, biopunk greens and purples, warning reds.
- **UI:** Tactical HUD aesthetic. Clean readouts, damage numbers, status bars.
- **Units:** Portrait-based. Each unit has a distinct silhouette and visual identity.
- **Enemies:** Same portrait UI as players — mirrored battlefield.

---

## 4. Game Loop

### The Run
```
Select 3 Heroes (from 8)
        ↓
Select Operation (1 of 5)
        ↓
Battle 1 → Battle 2 → ... → Battle 9 → Boss (Battle 10)
        ↓
After each battle: Choose 1 of 3 rewards (consumable or gear)
After Battle 5: Choose a Relic (run-wide modifier)
        ↓
Win: Defeat the Boss
Lose: All units wiped in a single battle
```

### One Battle Turn
```
All units + enemies roll their dice simultaneously
        ↓
Player resolves their units' abilities (in chosen order)
        ↓
Surviving enemies resolve their abilities
        ↓
Dice reset, new turn begins
        ↓
Battle ends when one side is fully eliminated
```

### Between Battles
- Gear and items persist
- Dead units resurrect at start of next battle with partial HP penalty
- Protocol Bar resets each battle

---

## 5. Units

### Roster (8 Total, Player Picks 3)

| Unit | Category | Playstyle |
|---|---|---|
| **Pulse Tech** | damage | Seeds Burn, cashes it with Detonate; Chain at floor and ceiling |
| **Strike Unit** | damage | High single-target damage, pierce, Execute |
| **Spike Guard** | defense | Shields, Spike retaliation, taunt punishment |
| **Avalanche Suit** | defense | Heavy area attacks, Freeze line |
| **Splice Medic** | support | Team heals, Mark support, resurrection |
| **Field Engineer** | support | Protocol generation, shields, squad buffs |
| **Ghost Operative** | control | Cloak, decloak burst, Execute finishers |
| **Signal Breaker** | control | ±Roll chips, Jam, Firewall disruption |

### Unit Card (What Appears on the Battlefield)
Each unit is represented as a permanent portrait card. It displays:
- Portrait art
- HP bar
- Current dice result
- Current ability (mapped to dice roll)
- Status effects (frozen, DoT, cloaked, etc.)
- Gear slots
- XP bar
- Level / Evolution indicator

### Dice Ranges (D20)
Each unit maps dice roll ranges to 5 abilities. Ranges vary per unit. Example structure:

```
1–5:   Weak / Passive ability
6–9:   Defensive ability (shield or heal)
10–15: Standard ability (attack or support)
16–19: Strong ability (heavy attack or team effect)
20:    Signature / Ultimate ability
```

Exact ranges are defined per-unit in unit metadata files.

### Evolution
- On battle win: alive heroes earn **`20 + round(avg effective roll)`** XP; dead heroes earn **`round(avg effective roll)`** only
- Evolve at **100 XP** (typically ~fight 3–4 for hot rollers)
- **One progression stop per battle win** — extras deferred to the next win(s)
- Player chooses one of **two branching paths** (each path = full 5-zone kit + callsign)
- **Directives (tier 3):** evolved units keep earning XP; at **250 XP** the same
  screen offers **1 of 2 Directives** — permanent passives scoped to the chosen
  evolution path (e.g. Pyro: Flashpoint / Slow Roast)
- Evolution and Directive persist for the run; reset on run end

---

## 6. Dice System

### The Roll
- One D20 per living unit per turn (player and enemy)
- All dice rolled simultaneously at turn start
- Result maps directly to the unit's ability chart

### Physical Dice (3D tray) — July 2026 model
The roll is a real rigid-body simulation, tuned to read like tabletop dice
(design decisions pinned after the July 2026 physics overhaul):

- **Hand toss:** each side's dice leave one shared "hand" origin per roll as a
  cluster with a common direction plus per-die jitter, tumbling end-over-end
  around the axis perpendicular to travel. Hero hand at the bottom edge,
  enemy at the top; each side sweeps its own half.
- **Low and flat:** dice leave the hand barely above the felt (so they roll
  across the tray instead of flying over it). This is what makes frozen dice
  read as solid obstacles — verified by the physics probe (0 penetrations,
  0 flyovers).
- **Energy model:** no air drag while rolling; energy is lost to bounces and
  friction (hard-plastic die on a felt-lined tray). A "felt grab" damping ramp
  ends stragglers after ~3s.
- **Tray:** invisible walls sit exactly at the visible combat-zone edges and
  lean inward 8° like a real tray's sloped rim, so dice can never wedge
  upright in a corner.
- **Frozen dice** are immovable static bodies at full collision size — new
  dice bounce off them naturally. (Immovable over pushable: result rows sit
  near the tray edges and pushable frozen dice would drift out of their slots.)
- **Engraved faces:** numerals render as recessed engravings (dark numeral,
  occlusion rim toward the light, lit groove edge away) — not printed decals.
- The die lands its **effective** face once at settle (Capped-die Option A);
  raw roll is kept separately for crit/overload rules.

### Manipulation Methods

| Method | Source | Effect |
|---|---|---|
| **Nudge** | Protocol Bar (1) | +3 to a die (Reverse Gimbal gear can flip it) |
| **Reroll** | Protocol Bar (2) | Reroll one die completely |
| **Set** | Protocol Bar (3) | Force a die to any value (Root Access: first Set free) |
| **Twin Fates** | Relic (once per battle) | Copy one hero die's result to another, free |
| **Freeze / Petrify** | Abilities/items | Die locked; the unit skips its next N reveals |
| **Jam** | Abilities/modifiers | Next roll capped (10 default) — amber tint + cap marker on the die |
| **Rewrite** | Synod abilities / ROOT boss | Next roll SET to 3 (telegraphed marker) |
| **Hijack** | Synod enemies | Enemy die copies the squad's highest roll |
| **±Roll** | Abilities/gear/relics | Increase or decrease effective die value |

### Protocol Bar
- Battle-only resource; **resets to 0 each battle** (unless a relic carries a % over)
- **+1 at end of every turn**, cap **10**
- Spend actions: **Nudge 1** (+3 to a die, once per die per turn) · **Reroll 2** · **Set 3** (pick 1–20) · **Item 1** (flat, all rarities)
- Additional income from abilities (`gainProtocol`), gear, and relics

---

## 7. Combat System

### HP Preview (net outcome) — July 2026 model
During targeting, every card's HP bar answers exactly one question: *"if I
lock this in, where does my HP end up?"* The projection runs the round in true
resolution order (hero heals/shields land first, then enemy damage, then the
poison tick; damage and poison both drain shields before HP) and paints:

- **red** `[final, current]` — net HP loss (leading **purple** slice = the
  poison tick's unshielded share)
- **mint** `[current, final]` — net HP gain
- **blue** `[no-shield final, final]` — the loss the shield prevents
  ("without your shield you'd end HERE")
- HP label reads `45 → 30 / 45` while a net-changing preview is active;
  lethal projections paint the whole fill red

Intermediate states are deliberately **not** shown — resolution order is
fixed, so mid-round numbers carry no decision the endpoint doesn't, and
sequential slabs previously painted contradictory futures. Per-source
composition (who contributes what) lives in the ability readout pips.

### Turn Structure
1. Roll phase — all dice rolled simultaneously
2. Player phase — player resolves unit abilities in chosen order
3. Enemy phase — surviving enemies resolve abilities
4. End of turn — status effects tick, dice reset

### Damage Model
- Units have HP bars
- Shields absorb damage before HP and last **one round** (granted this round,
  absorb through the opposing phase, gone at round end) — the Mantle Core relic
  and the MANTLE TYRANT boss are the only persistence exceptions
- **Burn** (the single universal DoT, data key `burn`+`burnT`) ticks at end of round
- Dead units stay on the field as downed cards; their dice no longer roll

### Status Effects & Keywords
| Effect | Behaviour |
|---|---|
| Burn | X damage at end of each round for N turns (chips can Detonate it) |
| Frozen / Petrified | Die locked; the unit skips its next N reveals (petrify = Accretion stone flavor) |
| Cloaked | Untargetable by hostile single-target abilities; breaks on dealing damage or an AoE hit |
| Firewall | Blocks the next ability that targets this unit, then breaks |
| Mark | Next hit on this unit deals +50%, then consumed |
| Spike | This round, attackers that connect take N back (readout only) |
| Jam / Rewrite / Hijack | Die statuses (see §6) |
| Taunt | The taunted unit can only target the taunter — same word both directions (hero taunts force enemy aim; enemy taunts restrict a hero's aim, TAUNT chip on the taunted hero) |
| Siphon | Enemy hits drain the squad's Protocol pool |
| Rampaging | Deals double damage (enemy erb family) |

One keyword per ability (pierce counts); overload-zone abilities may carry two.

### Enemies
- Mirror the player's structure: portrait cards, dice rolls, ability ranges
- Each enemy has 5 abilities mapped to D20 ranges
- Enemy dice visible to player (telegraphed intent)
- Enemy does not use Protocol Bar (Siphon attacks drain the player's)
- **Bosses run standing rules** active from turn 1 (no phase 2): SCRAPMASTER
  rebuilds Scrap Drones · Matriarch spawns Bloodmites · Overseer stays Warded
  while allies live · ROOT Rewrites the squad's highest die · MANTLE accretes
  persistent stacking shields

---

## 8. Progression Systems

### Within a Battle
- Protocol Bar charges
- Status effects accumulate
- Units die permanently for the battle (but resurrect next battle)

### Between Battles (Run-persistent)
- **Gear:** Equipment items placed on units. Modify stats or add passive abilities.
- **Consumables:** One-time use items (potions, grenades, etc.)
- **Relics:** Chosen at Battle 5. Run-wide passive modifiers. One relic per run.

### Reward Structure
After each battle, choose 1 of 3 rewards:
- Can be consumables (immediate use or saved)
- Can be gear (equip to a unit)
- After Battle 5: one guaranteed Relic choice instead

### Run Reset
Everything resets on: full wipe OR completion of Battle 10.

### Future: Player-Level Progression *(Out of scope for demo)*
- Persistent XP across runs
- Unlock new units, items, operations
- Not in current development scope

---

## 9. Operations

**5 operations** are defined in `data/raw/battle-modes.json`. Player picks one at run start. Each operation is **10 battles** (boss on fight 10), themed enemy faction, and a unique boss unit.

| ID | Theme | Boss (fight 10) |
|---|---|---|
| `facility` | Corporate drones, ECM, scrap | SCRAPMASTER |
| `hive` | Insectoid swarm | Hive Matriarch |
| `veil` | Harmonic / resonance | Conclave Overseer |
| `voidCirclet` | Cult casters | Circlet Hierophant |
| `stellarMenagerie` | Beasts | Void Reaver |

Enemy stats in Godot use flat `enemyUnitDefs` per fight. Balance-sim scaling keys are lab-only.

---

## 10. Reward Items (Design Notes)

### Gear
- Equips to a specific unit
- Persists until run ends
- Examples: +shield, +damage modifier, passive on roll 20, etc.

### Consumables
- One-time use during battle
- Examples: Heal a unit, modify a dice, apply a status

### Relics
- Run-wide passive
- Only one per run, chosen at Battle 5
- Examples: All units start with +2 protocol per turn, all 20s deal double damage, etc.

---

## 11. UI / UX Design Goals

- **Mobile first:** All interactions thumb-friendly. Large touch targets. Portrait (vertical) orientation, 1080×2400 internal, 450×1000 preview.
- **At-a-glance clarity:** Player should always know exactly what every die result will do.
- **Minimal menus:** Fewer screens, more battlefield.
- **Tactile feedback:** Dice roll animations, damage numbers floating, satisfying hit feedback.
- **Dark HUD aesthetic:** Inspired by sci-fi tactical interfaces, not card game pastels.

---

## 12. Out of Scope for Demo

- Player-level persistent XP and unlock system
- Overworld / node map between battles
- Multiplayer
- Story / narrative content
- Full audio implementation

---

## 13. Demo Success Criteria

A successful demo means:
- All 5 operations fully playable (10 battles each)
- All 8 units selectable with distinct mechanics
- Dice system fully functional with Protocol Bar
- Gear, consumable, and Relic reward loop working
- Clean, readable mobile UI
- Feels good to show friends
