import { Injectable, inject } from '@angular/core';
import { BATTLE_MODE_ORDER, BATTLE_MODES } from '../data/battle-modes.data';
import type { BattleModeId } from '../models/types';
import {
  type BattleProgressSimInput,
  type BattleProgressSimResult,
  formatBattleProgressSimResult,
  runBattleProgressSim,
} from '../sim/battle-progress-sim.lib';
import { EnemyContentService } from './enemy-content.service';
import { HeroContentService } from './hero-content.service';

@Injectable({ providedIn: 'root' })
export class BattleProgressSimService {
  private readonly heroes = inject(HeroContentService);
  private readonly enemies = inject(EnemyContentService);

  /** Uses current in-memory hero + enemy definitions (including unsaved dev edits). */
  buildInput(protocolRerolls = 0): BattleProgressSimInput {
    const battlesByMode = {} as Record<BattleModeId, { enemies: { name: string }[] }[]>;
    const modeLabels = {} as Record<BattleModeId, string>;
    const trackHpScaleByMode = {} as Record<BattleModeId, number>;
    for (const id of BATTLE_MODE_ORDER) {
      const m = BATTLE_MODES[id];
      battlesByMode[id] = structuredClone(m.battles);
      modeLabels[id] = m.label;
      trackHpScaleByMode[id] = m.trackHpScale;
    }
    return {
      heroes: structuredClone(this.heroes.heroes()),
      unitDefs: structuredClone(this.enemies.enemyUnitDefs()),
      suites: structuredClone(this.enemies.enemyAbilities()) as BattleProgressSimInput['suites'],
      battleScale: structuredClone(this.enemies.battleEnemyScale()),
      modeOrder: [...BATTLE_MODE_ORDER],
      battlesByMode,
      modeLabels,
      trackHpScaleByMode,
      protocolRerolls: Math.max(0, protocolRerolls | 0),
    };
  }

  run(iterations: number, protocolRerolls = 0): BattleProgressSimResult {
    return runBattleProgressSim(this.buildInput(protocolRerolls), iterations);
  }

  format(result: BattleProgressSimResult): string {
    return formatBattleProgressSimResult(result);
  }
}
