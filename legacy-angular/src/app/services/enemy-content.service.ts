import { Injectable, signal } from '@angular/core';
import type { EnemyAbilitySuite, EnemyAbility } from '../models/ability.interface';
import type { EnemyDefinition } from '../models/enemy.interface';
import type { EnemyType } from '../models/types';
import raw from '../data/json/enemies.data.json';

const STORAGE_KEY = 'op-dev-enemy-content-v1';

function cloneSuite(s: EnemyAbilitySuite): EnemyAbilitySuite {
  return structuredClone(s) as EnemyAbilitySuite;
}

function cloneUnitDefs(d: Record<string, Omit<EnemyDefinition, 'name'>>) {
  return structuredClone(d) as Record<string, Omit<EnemyDefinition, 'name'>>;
}

@Injectable({ providedIn: 'root' })
export class EnemyContentService {
  private readonly _abilities = signal<Record<EnemyType, EnemyAbilitySuite>>(
    structuredClone(raw.enemyAbilities) as Record<EnemyType, EnemyAbilitySuite>,
  );
  private readonly _unitDefs = signal(
    cloneUnitDefs(raw.enemyUnitDefs as Record<string, Omit<EnemyDefinition, 'name'>>),
  );
  private readonly _battleScale = signal<{ hp: number; dmg: number }[]>(
    structuredClone(raw.battleEnemyScale) as { hp: number; dmg: number }[],
  );

  readonly enemyAbilities = this._abilities.asReadonly();
  readonly enemyUnitDefs = this._unitDefs.asReadonly();
  readonly battleEnemyScale = this._battleScale.asReadonly();

  constructor() {
    this.hydrateFromLocalStorage();
  }

  suiteFor(type: EnemyType): EnemyAbilitySuite {
    return this._abilities()[type] || this._abilities()['scrap'];
  }

  setSuite(type: EnemyType, suite: EnemyAbilitySuite): void {
    const next = { ...this._abilities(), [type]: cloneSuite(suite) };
    this._abilities.set(next);
  }

  setUnitDef(unitName: string, def: Omit<EnemyDefinition, 'name'>): void {
    const next = { ...this._unitDefs(), [unitName]: structuredClone(def) as Omit<EnemyDefinition, 'name'> };
    this._unitDefs.set(next);
  }

  setAllUnitDefs(defs: Record<string, Omit<EnemyDefinition, 'name'>>): void {
    this._unitDefs.set(cloneUnitDefs(defs));
  }

  setBattleScale(rows: { hp: number; dmg: number }[]): void {
    this._battleScale.set(structuredClone(rows));
  }

  expandFromSpawn(spawn: { name: string }): EnemyDefinition {
    const name = spawn && spawn.name;
    const def = this._unitDefs()[name];
    if (!def) throw new Error('Unknown enemy unit name: ' + name);
    return { ...def, name };
  }

  applyBattleScale(ex: EnemyDefinition & { dmgScale?: number }, battleIndex: number): EnemyDefinition & { dmgScale: number } {
    const rows = this._battleScale();
    const idx = Math.max(0, Math.min(rows.length - 1, battleIndex | 0));
    const sc = rows[idx] || { hp: 1, dmg: 1 };
    const hpM = sc.hp,
      dmgM = sc.dmg;
    const out = { ...ex } as EnemyDefinition & { dmgScale: number };
    out.hp = Math.max(1, Math.round(ex.hp * hpM));
    out.dMin = Math.max(1, Math.round(ex.dMin * dmgM));
    out.dMax = Math.max(out.dMin, Math.round(ex.dMax * dmgM));
    if (ex.p2dMin != null && ex.p2dMax != null) {
      out.p2dMin = Math.max(1, Math.round(ex.p2dMin * dmgM));
      out.p2dMax = Math.max(out.p2dMin, Math.round(ex.p2dMax * dmgM));
    }
    if (ex.pThr != null) out.pThr = Math.max(1, Math.round(ex.pThr * hpM));
    out.dmgScale = dmgM;
    return out;
  }

  persistToLocalStorage(): void {
    try {
      localStorage.setItem(
        STORAGE_KEY,
        JSON.stringify({
          enemyAbilities: this._abilities(),
          enemyUnitDefs: this._unitDefs(),
          battleEnemyScale: this._battleScale(),
        }),
      );
    } catch {
      /* ignore */
    }
  }

  clearLocalAndResetBundled(): void {
    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch {
      /* ignore */
    }
    this._abilities.set(structuredClone(raw.enemyAbilities) as Record<EnemyType, EnemyAbilitySuite>);
    this._unitDefs.set(cloneUnitDefs(raw.enemyUnitDefs as Record<string, Omit<EnemyDefinition, 'name'>>));
    this._battleScale.set(structuredClone(raw.battleEnemyScale) as { hp: number; dmg: number }[]);
  }

  exportJson(): string {
    return JSON.stringify(
      {
        $schema: '../schemas/enemies.data.schema.json',
        enemyAbilities: this._abilities(),
        enemyUnitDefs: this._unitDefs(),
        battleEnemyScale: this._battleScale(),
      },
      null,
      2,
    );
  }

  importJson(text: string): { ok: true } | { ok: false; error: string } {
    try {
      const data = JSON.parse(text) as {
        enemyAbilities?: Record<EnemyType, EnemyAbilitySuite>;
        enemyUnitDefs?: Record<string, Omit<EnemyDefinition, 'name'>>;
        battleEnemyScale?: { hp: number; dmg: number }[];
      };
      if (!data.enemyAbilities || typeof data.enemyAbilities !== 'object') {
        return { ok: false, error: 'Missing enemyAbilities' };
      }
      this._abilities.set(structuredClone(data.enemyAbilities) as Record<EnemyType, EnemyAbilitySuite>);
      if (data.enemyUnitDefs && typeof data.enemyUnitDefs === 'object') {
        this._unitDefs.set(cloneUnitDefs(data.enemyUnitDefs));
      }
      if (data.battleEnemyScale && Array.isArray(data.battleEnemyScale) && data.battleEnemyScale.length === 10) {
        this._battleScale.set(structuredClone(data.battleEnemyScale));
      }
      return { ok: true };
    } catch (e) {
      return { ok: false, error: e instanceof Error ? e.message : 'Invalid JSON' };
    }
  }

  private hydrateFromLocalStorage(): void {
    try {
      const rawStored = localStorage.getItem(STORAGE_KEY);
      if (!rawStored) return;
      const data = JSON.parse(rawStored) as {
        enemyAbilities?: Record<EnemyType, EnemyAbilitySuite>;
        enemyUnitDefs?: Record<string, Omit<EnemyDefinition, 'name'>>;
        battleEnemyScale?: { hp: number; dmg: number }[];
      };
      if (data.enemyAbilities) this._abilities.set(structuredClone(data.enemyAbilities));
      if (data.enemyUnitDefs) this._unitDefs.set(cloneUnitDefs(data.enemyUnitDefs));
      if (data.battleEnemyScale?.length === 10) this._battleScale.set(structuredClone(data.battleEnemyScale));
    } catch {
      /* ignore */
    }
  }
}
