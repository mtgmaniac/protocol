# Balance sim (TypeScript)

Headless Monte Carlo sim used by `scripts/debug/balance_sim_*.ts` for tuning `data/raw/`.

**Not** part of the Godot runtime. Combat authority is `scripts/battle/combat_manager.gd`.

Models (among others): burn, shields, phase 2, blastAll, enemy `rfm` (hero RFE), `erb`/`erbAll`, `wipeShields`, hero `gainProtocol` (adds to track-wide reroll budget), **Tier-1 gear passives** via `gear-sim.lib.ts` + `squadGearId`, **Tier-2 consumables** via `consumable-sim.lib.ts` + `trackConsumableId` (1× per battle, heuristic timing).

**Gear modeled:** rollBonus, maxHpBonus, burnDmgBonus, dmgReduction, surviveOnce, firstAbilityDmgBonus/Echo, healOnKill (all heroes), protocol on battle start/kill, lifesteal, shieldPierce, battleStartShield, battleStartCloakRoll (+roll buff for the battle).

**Still omitted:** cloak evasion, healShieldBonus, cloak/reroll consumables, relics, full Protocol economy (per-turn +1, nudge/set costs beyond item use).

```bash
npx tsx scripts/debug/balance_sim_evo_only.ts 8000
npx tsx scripts/debug/balance_sim_item_audit.ts 3000
```
