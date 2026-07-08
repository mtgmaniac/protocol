# NK-12 — Draftable Pool Tier-Budget: Trim Proposal (awaiting Kev sign-off)

**Status: PROPOSAL ONLY. No content deleted.** Per the fix-pass STOP gate, the NK-12 pool trim is a balance-sensitive content cut (INVARIANTS #8/#9) — this file presents the inventory, the over-cap math, and a proposed plan for Kev to approve or adjust. Nothing here is implemented.

## The rule (NK-12 ruling)

> The "single-entry effects + max 4 two-tier pairs" cap is **POOL-WIDE**, counting the whole draftable pool (gear + consumables + any rarity chains), not per-file and not gear-only.

So the draftable reward pool (consumables + gear; relics are a separate b5 draft) may contain **at most 4 two-tier pairs**, and **no effect with 3+ rarity tiers**. Everything else must be single-entry.

## Current inventory (verified against `data/raw/items.data.json` + `data/raw/gear.data.json`, 2026-07-08)

**Multi-tier effect chains in the draftable pool:**

| Effect | Tiers | Entries (id / rarity / amount) | Where |
|---|---|---|---|
| `rollBuff` | **4** | calibration_chip (common, 1) · momentum_core (unc, 2) · harmonic_injector (rare, 4) · archive_cascade (leg, 5) | consumable |
| `gainProtocol` | **4** | protocol_cell (common, 2) · capacitor_dose (unc, 3) · core_surge (rare, 4) · mainline_cache (leg, 5) | consumable |
| `enemyRfe` | **3** | grounding_clip (common, 1) · corrosion_bomb (unc, 2) · entropy_seed (rare, 3) | consumable |
| `anyDieFreeze` | 2 | cryo_gel (unc, 1) · cryo_web (rare, 2) | consumable |
| `rollBonus` | 2 | neural_splice (unc, +2) · predator_lens (leg, +3) | gear |
| `maxHpBonus` | 2 | stim_injector (unc, +6) · warframe_core (leg, +14) | gear |
| `protocolOnBattleStart` | 2 | protocol_tap (unc, +1) · mainline_bus (leg, +3) | gear |
| `lifesteal` | 2 | siphon_loop (rare, 20%) · hemophage_nexus (leg, 40%) | gear |
| `firstAbilityDmgBonus` | 2 | spike_driver (unc, +3) · overkill_matrix (leg, +10) | gear |

Everything else (13 consumable effects, 21 gear effects) is already single-entry.

## Over-cap math

- **Two-tier pairs:** 6 present (`anyDieFreeze`, `rollBonus`, `maxHpBonus`, `protocolOnBattleStart`, `lifesteal`, `firstAbilityDmgBonus`) — cap is **4** → **2 pairs over.**
- **3+ tier chains:** 3 present (`rollBuff` ×4, `gainProtocol` ×4, `enemyRfe` ×3) — cap is **0** → **all 3 must collapse.**

To reach compliance: pick **4** effects to keep as two-tier pairs; every other multi-tier effect collapses to a **single entry**. That removes **5 items** (one tier from each collapsed pair, and the chains drop to one tier each — net: rollBuff 4→1 drops 3, gainProtocol 4→1 drops 3, enemyRfe 3→1 drops 2, plus collapsing 2 of the 6 pairs drops 2) — i.e. up to **10 item ids removed** under the strictest reading, or fewer if some chains are kept as (allowed) pairs.

## Proposed plan (recommended — for Kev to approve/adjust)

Keep the **4 pairs** that most reward a rarity ladder (a low-tier common/uncommon + a "reach" legendary), collapse the rest to single-entry at the tier that best preserves each effect's identity.

**Keep as two-tier pairs (4):**
1. `rollBonus` gear — the flagship "+N all rolls" (unc +2 → leg +3). Universal, iconic.
2. `gainProtocol` consumable — collapse 4→2: keep **protocol_cell (common, +2)** + **mainline_cache (legendary, +5)**; drop capacitor_dose, core_surge.
3. `rollBuff` consumable — collapse 4→2: keep **calibration_chip (common, +1)** + **archive_cascade (legendary, +5)**; drop momentum_core, harmonic_injector.
4. `maxHpBonus` gear — defensive anchor (unc +6 → leg +14).

**Collapse to single-entry (keep the listed tier, drop the other):**
- `anyDieFreeze` → keep **cryo_web (rare, 2)**; drop cryo_gel.
- `protocolOnBattleStart` → keep **mainline_bus (legendary, +3)** or **protocol_tap**; drop the other.
- `lifesteal` → keep **hemophage_nexus (legendary, 40%)** or siphon_loop; drop the other.
- `firstAbilityDmgBonus` → keep **overkill_matrix (legendary, +10)** or spike_driver; drop the other.
- `enemyRfe` → keep **entropy_seed (rare, 3)**; drop grounding_clip, corrosion_bomb.

**Result:** exactly 4 two-tier pairs, no 3+ tier chains, everything else single-entry — compliant. Removes ~10 item ids.

## Open questions for Kev

1. **Is the strict count right?** The rule as ruled = "≤4 two-tier pairs, no longer chains." Confirm you want the pool collapsed to that, vs. a looser reading (e.g., "≤4 pairs *per file*" or "chains counted as one pair each").
2. **Which 4 pairs to keep** — the four above are a design recommendation; you may prefer different anchors (e.g. keep `lifesteal` as a pair over `maxHpBonus`).
3. **Which tier to keep** on each collapsed effect (I defaulted to preserving the highest-impact tier, but a common-tier keep changes draft-economy feel).

**Balance note:** removing ~10 draftable items shrinks the reward pool and reshapes the rarity ladder — this WILL move the sim baseline. Per INVARIANTS #9, the implementing commit must carry a measured per-op delta table and `BASELINE-APPROVED-BY-KEV`. **Do not implement until this plan (or an amended one) is signed off.**
