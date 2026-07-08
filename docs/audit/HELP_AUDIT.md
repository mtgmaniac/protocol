# Overload Protocol — Help / Glossary Completeness Audit (Prompt 2)

*Single sequential pass, no subagents. Run after the description audit (Prompt 1), so definitions
validate against confirmed post-fix behavior. Branch `audit/help`.*

Date: 2026-07-07. Auditor: Claude (Opus 4.8).

Sources: `keywords.data.json` (glossary — single source of truth, rendered whole by the KEYWORDS tab),
`primers.data.json` (one-shot tutorials), `help_menu.gd` (help surface + `HELP_KEYWORD_ICON`),
`inspect_resolver.gd` (inspect popups). List A (live terms) built from `data/raw/` + code; List B from
the glossary + primers + hardcoded help.

---

## Result at a glance

| Class | Count | Detail |
|---|---|---|
| Orphans filled | 2 | `summon`, `wipe_shields` (Shield Wipe) glossary entries added |
| Orphans → needs-ruling | 1 | `pack bonus` — surfaced term backed by a **no-op** mechanic (id-comparison bug) |
| Ghosts fixed | 2 | bestiary faction labels (old names) · "Epic" rarity line (no epic content) |
| Stale defs fixed | 3 | `freeze` (NK-03), `taunt` (NK-08), `leech` (NK-09) |
| Primers trimmed / rewritten | 0 | all 23 active primers already within limits, none contradict a def |
| Icon-map improvement | 1 | `accrete` now maps to the shield pip (was a bare "A") |

No TRUTH.md edit needed — it already carries the correct NK-03/08/09 definitions.

---

## 1. Orphans (in A, not B) — a live term the game shows with no entry

### O-01 — `pack bonus` → **NEEDS KEV RULING** (not filled)
- **Surfaced:** enemy `eff` strings "6 dmg, pack bonus" / "7 dmg, pack bonus" / "14 dmg, pack bonus"
  (Pumice Macaque, Obsidian/Slag Hound) — shown in ability inspect and bestiary.
- **No glossary/primer entry.** Would normally be a HIGH orphan to fill.
- **Why it's a ruling, not a fill:** the mechanic is currently a **no-op**. `combat_manager.gd:1646-1655`
  counts other living enemies via `str(es["id"]) == str(enemy_state["id"])`, but enemy instance ids are
  unique (`_next_enemy_instance_id` → `beastMonkey#1`, `beastMonkey#2`, …), so the condition is never
  true across distinct instances and `pack_count` is always 0. The intended comparison is almost
  certainly the **kind** id (`es["unit"].id == enemy_state["unit"].id`). Until the code is fixed, writing
  a glossary def would document an effect that never fires.
- **Proposed def once fixed** (ready to paste): *"Pack Bonus — this attack deals +1 for each other
  living pack member of the same kind."* Category `offense`.
- Cross-ref: this is a **mechanics bug** (out of this audit's content-only scope) — flag for a combat
  fix pass.

### O-02 — `summon` → **FILLED**
- **Surfaced:** 12 enemy overload `eff` strings ("summon ~N% on 20") and the bestiary "Applies: Summon"
  tag (`help_menu.gd:646-647`). Functioning mechanic (regression-tested; `combat_manager.gd:2775-2798`).
- **Fix applied:** added glossary entry `summon` / **Summon** (offense): *"Enemy-only: on its Overload
  (a 20), this enemy may call one reinforcement into an open slot."* `syntax: "summon ~N% on 20"`.

### O-03 — `wipe shields` / "Shield Wipe" → **FILLED (+ inspect remap)**
- **Surfaced:** boss/elite `eff` "wipe shields, then N dmg" (System Purge, Acid Cataclysm, Void Gate,
  Basalt Stampede, Veil Cataclysm, Mirror Break…) and the bestiary "Applies: Shield Wipe" tag.
- **Bug in help mapping:** `inspect_resolver.gd` mapped `wipeShields → "breach"`, so a boss's
  strip-your-squad's-shields ability appended the **Breach** def ("destroys all shield on the target…
  Breach all strips every enemy") — which describes a *hero* stripping *enemy* shields, the opposite
  actor/target. Misleading.
- **Fix applied:** added glossary entry `wipe_shields` / **Shield Wipe** (offense): *"Enemy-only:
  destroys every shield on your whole squad before the attack's damage lands."* and remapped
  `inspect_resolver.gd` `wipeShields → "wipe_shields"` so the correct def now appends.

*(Low, not filled: enemy "lifesteal N%" text maps to the **Leech** entry in inspect already — not an
orphan. The Shatter-Lance "+6 vs frozen" rider is a self-evident numeric, not a keyword.)*

## 2. Ghosts (in B, not A) — an entry for something removed / never live

### G-01 — Bestiary faction labels use the **old faction names** → **FIXED**
- `help_menu.gd` `BESTIARY_FACTION_LABEL` showed `voidCirclet → "VOID CIRCLET"` and
  `stellarMenagerie → "STELLAR MENAGERIE"`. Those are the **old** names; the canonical labels
  (`battle-modes.json`) are **"Null Synod"** and **"The Accretion"** (also the faction identities in
  TRUTH). **Fixed** → "NULL SYNOD" / "THE ACCRETION". (facility/hive/veil labels are correct
  shorthand, left as-is; hero "Spike Guard" is current — no "Spite Guard" ghost anywhere.)

### G-02 — Help rewards lists an **"Epic — purple"** rarity that never drops → **FIXED**
- The RARITY section listed Common/Uncommon/Rare/**Epic**/Legendary, but no item/gear/relic in
  `data/raw/` has rarity `epic` (the ladder is common/uncommon/rare/legendary, per TRUTH). The
  `PixelUI.rarity_color` "epic" case is dormant infrastructure. **Fixed** → removed the Epic line so
  the help only teaches tiers the player can actually receive.

### Glossary / primer ghost sweep — **CLEAN**
- `keywords.data.json` contains **no** dead entries: no nat-20/"natural 20", cower, counterspell,
  venom/decay, retaliate, lure, or old-faction keyword. Every entry (burn, chain, detonate, execute,
  breach, leech, mark, rampage, spike, pierce, shield, heal, revive, roll_down, roll_up, jam, rewrite,
  hijack, freeze, cloak, ward, accrete, taunt, siphon, protocol_gain, aoe — + new wipe_shields, summon)
  is referenced by live data. `rampage` is live (beastTyrant). No XP-consumable terms.
- `primers.data.json`: all 23 active primers map to live mechanics. The three `$signal_hook_examples`
  (haunt/pilfer/counter_protocol) are explicitly **not loaded** (documentation stubs) — not ghosts.

## 3. Stale defs (in both, but wrong post-fix) — all FIXED

| # | Term | Was | Now (fix applied) | Rule |
|---|---|---|---|---|
| S-01 | freeze | "…can't be **Jammed, Rewritten, or Hijacked**." | "…can't be **altered at all — not by Jam, Rewrite, Hijack, Nudge, Reroll, or Set**." | NK-03 full die immunity |
| S-02 | taunt | "The taunted unit can only target the taunter." | "…can only target the taunter, **until the end of the round**." | NK-08 round-end clear both sides |
| S-03 | leech | "…heals **50%** of the damage dealt to HP." | "…heals **a share** of the damage… — **50% for heroes; each enemy shows its own rate as 'lifesteal N%'**." | NK-09 hero-fixed / enemy-tunable |

- **shield** def ("Lasts one round: gone at round end. Pierce goes through it; Breach destroys it.") —
  **verified correct**, matches the one-round expiry and the six-chip doctrine. No change.
- No glossary def references "natural 20". ✔

## 4. Primer violations — NONE

All 23 active primers are ≤ ~12 words, one sentence, state the RULE, and match their keyword `def`
(INVARIANTS #7). Spot-checks: `primer_burn` = "takes damage at the end of each round" (consistent with
the Prompt-1 inspect timing fix), `primer_freeze` = "the die keeps its face — that unit acts again"
(matches the def). `primer_leech` says "heals **half** the damage" — exact for heroes, a light
approximation for enemy lifesteal, but acceptable for a one-shot generic primer and not a contradiction.

## 5. Chip doctrine — N/A on the help surface (doctrine intact)

The help surface **does not enumerate status chips** — the KEYWORDS tab renders the glossary, and the
BASICS tab only says "Status icons appear when active." So there is no chip list to over- or under-count.
The six-chip doctrine (Burn / Shield / Mark / ±Roll / Firewall / Taunt, cap 3 + overflow) lives in the
card renderer per TRUTH §UI & feedback / DECISIONS_RESOLVED #16 and is unchanged. No help finding.

## 6. Icon-map coverage — every keyword renders; one improved

`_add_keyword_row` resolves an icon in three tiers: `HELP_KEYWORD_ICON` pip → the keyword's `code` pip
(CH/DT/EX/BR/LC/MK/RA/SP/JM/RW/HJ/SI/C/FW…) → the term's initial. **Nothing renders blank.**
- **Improved:** `accrete` had no icon and no `code`, so it rendered a bare "A". Mapped
  `accrete → "shield"` (accrete *is* shield gain). 
- **Acknowledged initial-fallbacks (by design, no pip texture exists):** `protocol_gain` ("P"), and the
  two new `summon` / `wipe_shields` ("S"). Consistent with the existing deliberate fallback; flagged,
  not blocking.
- `taunt` reuses the shield pip (pre-existing semantic reuse) — left as-is.

---

## Final table — every live term now has exactly one correct entry + icon

| Term (List A) | Glossary entry | Icon render | Notes |
|---|---|---|---|
| burn | ✓ | burn pip | |
| chain | ✓ | CH | |
| detonate | ✓ | DT | |
| execute | ✓ | EX | |
| breach | ✓ | BR | |
| leech | ✓ (def fixed S-03) | LC | hero 50% / enemy % |
| mark | ✓ | MK | chip |
| rampage | ✓ | RA | enemy (beastTyrant) |
| spike | ✓ | SP | |
| pierce | ✓ | damage pip | |
| shield | ✓ | shield pip | chip |
| heal | ✓ | heal pip | |
| revive | ✓ | heal pip | |
| roll_down (±roll) | ✓ | roll_down pip | chip |
| roll_up (±roll) | ✓ | roll_up pip | chip |
| jam | ✓ | JM | |
| rewrite | ✓ | RW | |
| hijack | ✓ | HJ | |
| freeze (+Petrify) | ✓ (def fixed S-01) | freeze pip | Petrify = cosmetic flavor, noted in `note` |
| cloak | ✓ | C | |
| ward / **Firewall** | ✓ | FW | chip |
| accrete | ✓ | shield pip (fixed) | |
| taunt | ✓ (def fixed S-02) | shield pip | chip |
| siphon | ✓ | SI | |
| protocol_gain | ✓ | "P" (by design) | |
| aoe | ✓ | damage pip | |
| **wipe_shields (Shield Wipe)** | ✓ NEW (O-03) | "S" (by design) | inspect remapped |
| **summon** | ✓ NEW (O-02) | "S" (by design) | |
| pack bonus | ✗ **needs ruling** (O-01) | — | mechanic is a no-op; fill after code fix |
| Nudge / Reroll / Set | ✓ (PROTOCOL tab + primers + `PROTOCOL_ACTIONS`) | — | |
| Null Synod / The Accretion (factions) | ✓ (fixed G-01) | — | Spike Guard current, no ghost |
| Boss standing rules (ASSEMBLY LINE, THE BROOD, THE COURT, ROOT ACCESS, ACCRETION) | ✓ | — | self-describing full sentences in enemy inspect |

---

## Report to Kev

- **Orphans filled: 2** — `summon` and `wipe_shields` (Shield Wipe) now have glossary entries; the
  Shield-Wipe fix also corrects a misleading inspect mapping (boss shield-wipes were showing the *Breach*
  definition).
- **Ghosts deleted/fixed: 2** — bestiary faction labels corrected to **NULL SYNOD / THE ACCRETION** (were
  the old Void Circlet / Stellar Menagerie names); the dormant **"Epic — purple"** rarity line removed.
- **Stale defs fixed: 3** — freeze (full immunity incl. Nudge/Reroll/Set, NK-03), taunt (round-end clear,
  NK-08), leech (hero 50% / enemy tunable %, NK-09).
- **Primers trimmed: 0** — all already compliant.
- **Icon coverage:** every keyword renders; added `accrete → shield`.
- **Needs a ruling (1):** **`pack bonus`** — the term appears on three enemy abilities, but the mechanic
  is a **no-op** because the pack-size loop compares unique instance ids instead of kind ids
  (`combat_manager.gd:1651`). Fix the code (compare `unit.id`), then paste the ready-made glossary def.
  This is a genuine mechanics bug surfaced by the help audit, not a wording call.
