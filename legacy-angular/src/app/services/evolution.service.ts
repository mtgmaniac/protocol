import { Injectable } from '@angular/core';
import { HeroAbility } from '../models/ability.interface';
import { normalizeHeroAbility } from '../data/hero-ability-normalize';
import { EvolutionTier, HeroState } from '../models/hero.interface';
import { GameStateService } from './game-state.service';
import { LogService } from './log.service';

export interface GroupedEvoPath {
  name: string;
  focus: string;
  hp: number;
  abilities: HeroAbility[];
}

@Injectable({ providedIn: 'root' })
export class EvolutionService {
  constructor(
    private state: GameStateService,
    private log: LogService,
  ) {}

  /** Group evolution tiers by name into complete paths */
  groupEvoPaths(evolutions: EvolutionTier[]): GroupedEvoPath[] {
    const map = new Map<string, GroupedEvoPath>();
    for (const evo of evolutions) {
      if (!map.has(evo.name)) {
        map.set(evo.name, {
          name: evo.name,
          focus: evo.focus,
          hp: evo.hp,
          abilities: [...evo.abilities],
        });
      } else {
        const existing = map.get(evo.name)!;
        existing.abilities.push(...evo.abilities);
        if (evo.hp > 0) existing.hp = evo.hp;
        if (evo.focus) existing.focus = evo.focus;
      }
    }
    return Array.from(map.values());
  }

  /** Calculate XP after battle win */
  calculateXp(h: HeroState): number {
    if (h.tier !== 1 || !h.bRolls || h.bRolls.length === 0) return 0;
    const avg = h.bRolls.reduce((a, b) => a + b, 0) / h.bRolls.length;
    let pts: number;
    if (avg >= 20) pts = 10;
    else if (avg >= 17) pts = 7;
    else if (avg >= 13) pts = 5;
    else if (avg >= 6) pts = 3;
    else pts = 1;
    return Math.round(pts * 1.5);
  }

  /** Check which heroes are eligible for evolution */
  getEligibleHeroes(): number[] {
    const heroes = this.state.heroes();
    const battle = this.state.battle();
    const eligible: number[] = [];
    for (let i = 0; i < heroes.length; i++) {
      const h = heroes[i];
      if (h.tier !== 1) continue;
      if (h.currentHp <= 0) continue;
      if (h.xp < 18) continue;
      if (battle < 2) continue;
      if (h.evolvedTo) continue;
      eligible.push(i);
    }
    return eligible;
  }

  /** Award XP to heroes after a battle win */
  awardXp(): void {
    const heroes = this.state.heroes();
    heroes.forEach((h, i) => {
      if (h.currentHp <= 0 || h.tier !== 1) return;
      const pts = this.calculateXp(h);
      this.state.updateHero(i, { xp: h.xp + pts });
    });
  }

  /** Apply a chosen evolution path to a hero */
  confirmEvolution(heroIdx: number, pathIdx: number): void {
    const h = this.state.heroes()[heroIdx];
    if (!h) return;
    const paths = this.groupEvoPaths(h.evolutions);
    const path = paths[pathIdx];
    if (!path) return;

    const hpRatio = h.currentHp / h.maxHp;
    const newMaxHp = path.hp;
    const newCurrentHp = Math.max(1, Math.round(newMaxHp * hpRatio));

    this.state.updateHero(heroIdx, {
      name: path.name,
      abilities: path.abilities.map(normalizeHeroAbility),
      maxHp: newMaxHp,
      hp: newMaxHp,
      currentHp: newCurrentHp,
      tier: 2,
      xp: 0,
      bRolls: [],
      evolvedTo: path.name,
      cls: path.focus || h.cls,
    });

    this.log.log(`⬡ ${h.name} evolved to ${path.name}!`, 'sy');
  }
}
