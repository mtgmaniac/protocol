import { Injectable, inject } from '@angular/core';
import { GameStateService } from './game-state.service';
import { ALL_GEAR, GEAR_BY_ID } from '../data/gear.data';
import type { GearDefinition } from '../models/gear.interface';
import type { HeroState } from '../models/hero.interface';

@Injectable({ providedIn: 'root' })
export class GearService {
  private state = inject(GameStateService);
  private assignDone: (() => void) | null = null;

  isGearId(id: string): boolean {
    return GEAR_BY_ID.has(id);
  }

  getGearDef(id: string): GearDefinition | undefined {
    return GEAR_BY_ID.get(id);
  }

  getHeroGearDef(heroIdx: number): GearDefinition | null {
    const h = this.state.heroes()[heroIdx];
    if (!h?.equippedGear) return null;
    return GEAR_BY_ID.get(h.equippedGear) ?? null;
  }

  /** All available gear definitions for the draft pool (filtered externally by rarity). */
  allGear(): GearDefinition[] {
    return ALL_GEAR;
  }

  /** True when all living heroes are equipped (excludes gear from draft pool). */
  allLivingHeroesEquipped(): boolean {
    const living = this.state.heroes().filter(h => h.currentHp > 0);
    return living.length > 0 && living.every(h => !!h.equippedGear);
  }

  heroHasGear(heroIdx: number): boolean {
    return !!this.state.heroes()[heroIdx]?.equippedGear;
  }

  // ── Query helpers for CombatService / DiceService ──

  getHeroDmgReduction(heroIdx: number): number {
    const g = this.getHeroGearDef(heroIdx);
    if (g?.effect.type === 'dmgReduction') return (g.effect as { type: 'dmgReduction'; amount: number }).amount;
    return 0;
  }

  hasSurviveOnce(heroIdx: number): boolean {
    return this.getHeroGearDef(heroIdx)?.effect.type === 'surviveOnce';
  }

  getFirstAbilityDmgBonus(heroIdx: number): number {
    const g = this.getHeroGearDef(heroIdx);
    if (g?.effect.type === 'firstAbilityDmgBonus') return (g.effect as { type: 'firstAbilityDmgBonus'; amount: number }).amount;
    return 0;
  }

  getHealOnKill(heroIdx: number): number {
    const g = this.getHeroGearDef(heroIdx);
    if (g?.effect.type === 'healOnKill') return (g.effect as { type: 'healOnKill'; amount: number }).amount;
    return 0;
  }

  /** Sum of all living heroes' dotDmgBonus (added to global enemy DoT tick). */
  getTotalDotDmgBonus(): number {
    return this.state.heroes().reduce((sum, _, i) => {
      const g = this.getHeroGearDef(i);
      if (g?.effect.type === 'dotDmgBonus') return sum + (g.effect as { type: 'dotDmgBonus'; amount: number }).amount;
      return sum;
    }, 0);
  }

  // ── Gear assignment flow ──

  startGearAssign(gearId: string, onDone: () => void): void {
    this.assignDone = onDone;
    this.state.pendingGearAssignment.set(gearId);
  }

  confirmGearForHero(heroIdx: number): void {
    const gearId = this.state.pendingGearAssignment();
    if (!gearId) return;
    const h = this.state.heroes()[heroIdx];
    if (!h || h.equippedGear) return; // already has gear
    const gear = this.getGearDef(gearId);
    const patch: Partial<HeroState> = { equippedGear: gearId };
    // Roll bonus is stored permanently on HeroState (not re-applied per battle)
    if (gear?.effect.type === 'rollBonus') {
      patch.gearRollBonus = (gear.effect as { type: 'rollBonus'; amount: number }).amount;
    }
    this.state.updateHero(heroIdx, patch);
    this.state.addLog(`▸ ${h.name} equipped ${gear?.name ?? gearId}.`, 'vi');
    this.state.pendingGearAssignment.set(null);
    const done = this.assignDone;
    this.assignDone = null;
    done?.();
  }

  cancelGearAssign(): void {
    this.state.pendingGearAssignment.set(null);
    const done = this.assignDone;
    this.assignDone = null;
    done?.();
  }
}
