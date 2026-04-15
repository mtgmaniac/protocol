import { Injectable, computed, signal } from '@angular/core';
import { EnemyState } from '../models/enemy.interface';
import { HeroId } from '../models/types';

@Injectable({ providedIn: 'root' })
export class EnemyStateService {
  readonly enemies = signal<EnemyState[]>([]);

  /** Veil grunt self-taunt: index of enemy forcing itself as the only valid damage target. Null when inactive. */
  readonly forcedEnemyTargetIdx = signal<number | null>(null);

  readonly tauntHeroId = signal<HeroId | null>(null);
  /** Enemy index that must target `tauntHeroId`; all other enemies use normal AI. */
  readonly tauntEnemyIdx = signal<number | null>(null);

  // ── Computed signals ──

  readonly livingEnemies = computed(() =>
    this.enemies().filter(e => !e.dead)
  );

  readonly anyEnemyAlive = computed(() =>
    this.enemies().some(e => !e.dead && e.currentHp > 0)
  );

  // ── Mutation methods ──

  updateEnemy(index: number, patch: Partial<EnemyState>): void {
    this.enemies.update(enemies =>
      enemies.map((e, i) => i === index ? { ...e, ...patch } : e)
    );
  }

  appendEnemy(enemy: EnemyState): void {
    this.enemies.update(enemies => [...enemies, enemy]);
  }

  replaceEnemy(index: number, enemy: EnemyState): void {
    this.enemies.update(enemies =>
      enemies.map((e, i) => i === index ? enemy : e)
    );
  }

  reset(): void {
    this.enemies.set([]);
    this.forcedEnemyTargetIdx.set(null);
    this.tauntHeroId.set(null);
    this.tauntEnemyIdx.set(null);
  }
}
