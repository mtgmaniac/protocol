import { Injectable } from '@angular/core';
import { HeroAbility } from '../models/ability.interface';
import { HeroState } from '../models/hero.interface';
import { HeroId, Zone } from '../models/types';
import { GameStateService } from './game-state.service';
import { HeroContentService } from './hero-content.service';
import { clampHeroAbilityForTier1 } from '../utils/hero-ability-tier.util';

// Enemy zone brackets (uniform across all enemy types)
const ENEMY_ZONE_BRACKETS: [number, number, Zone][] = [
  [1, 4, 'recharge'],
  [5, 10, 'strike'],
  [11, 16, 'surge'],
  [17, 19, 'crit'],
  [20, 20, 'overload'],
];

@Injectable({ providedIn: 'root' })
export class DiceService {
  constructor(
    private state: GameStateService,
    private heroContent: HeroContentService,
  ) {}

  d20(): number {
    return Math.floor(Math.random() * 20) + 1;
  }

  effRoll(h: HeroState): number | null {
    if (!h || h.roll === null) return null;
    return Math.min(20, (h.roll || 0) + (h.rollBuff || 0) + (h.rollNudge || 0) + (h.relicRollBonus || 0) + (h.gearRollBonus || 0));
  }

  getHeroZone(roll: number, heroId: HeroId): Zone {
    const brackets = this.heroContent.heroZones()[heroId];
    if (brackets) {
      const r = Math.min(20, roll);
      for (const [min, max, zone] of brackets) {
        if (r >= min && r <= max) return zone;
      }
    }
    return this.getEnemyZone(roll); // fallback to standard brackets
  }

  getEnemyZone(roll: number): Zone {
    const r = Math.min(20, Math.max(1, roll));
    if (r <= 4) return 'recharge';
    if (r <= 10) return 'strike';
    if (r <= 16) return 'surge';
    if (r <= 19) return 'crit';
    return 'overload';
  }

  getAbility(h: HeroState, roll: number): HeroAbility | null {
    const c = Math.min(20, roll);
    const raw = h.abilities.find(a => c >= a.range[0] && c <= a.range[1]) ?? null;
    if (!raw || h.tier !== 1) return raw;
    return clampHeroAbilityForTier1(raw);
  }

  getAbilityOrNull(h: HeroState): HeroAbility | null {
    const er = this.effRoll(h);
    if (er === null) return null;
    return this.getAbility(h, er);
  }

  /** Returns zone range strings for enemy display, e.g. { recharge: '1-4', strike: '5-10', ... } */
  enemyZoneRanges(): Record<Zone, string> {
    return {
      recharge: '1-4',
      strike: '5-10',
      surge: '11-16',
      crit: '17-19',
      overload: '20',
    };
  }

  /** Returns zone range strings for a specific hero */
  heroZoneRanges(heroId: HeroId): Record<Zone, string> {
    const brackets = this.heroContent.heroZones()[heroId];
    const ranges: Record<string, string> = {};
    if (brackets) {
      for (const [min, max, zone] of brackets) {
        ranges[zone] = min === max ? `${min}` : `${min}-${max}`;
      }
    }
    return ranges as Record<Zone, string>;
  }
}
