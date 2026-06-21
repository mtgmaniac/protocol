# Balance sim (TypeScript)

Headless Monte Carlo sim used by `scripts/debug/balance_sim_*.ts` for tuning `data/raw/`.

**Not** part of the Godot runtime. Combat authority is `scripts/battle/combat_manager.gd`.

Models (among others): DoT, shields, phase 2, blastAll, enemy `rfm` (hero RFE), `erb`/`erbAll`, `wipeShields`. Still omits items, summons, taunt, cloak, cower, etc.

```bash
npx tsx scripts/debug/balance_sim_evo_only.ts 8000
```
