import { describe, it, expect, beforeEach, vi } from 'vitest';
import enemyData from '../data/json/enemies.data.json';

// ── Mock localStorage before the service loads ──
const localStorageMock = (() => {
  let store: Record<string, string> = {};
  return {
    getItem: (key: string) => store[key] ?? null,
    setItem: (key: string, value: string) => { store[key] = value; },
    removeItem: (key: string) => { delete store[key]; },
    clear: () => { store = {}; },
  };
})();
vi.stubGlobal('localStorage', localStorageMock);

// Import after stubbing global
import { EnemyContentService } from './enemy-content.service';

// All enemy ability types present in the data file
const ALL_ENEMY_TYPES = Object.keys(enemyData.enemyAbilities) as string[];
const ALL_UNIT_DEF_NAMES = Object.keys(enemyData.enemyUnitDefs) as string[];
const ZONES = ['recharge', 'strike', 'surge', 'crit', 'overload'] as const;

describe('EnemyContentService', () => {
  let service: EnemyContentService;

  beforeEach(() => {
    localStorageMock.clear();
    // Manually instantiate without Angular DI since it has no real DI deps at runtime
    service = new EnemyContentService();
  });

  // ── suiteFor ──

  describe('suiteFor', () => {
    it('returns a suite for every defined enemy type', () => {
      for (const type of ALL_ENEMY_TYPES) {
        const suite = service.suiteFor(type as any);
        expect(suite, `suiteFor("${type}") should not be null`).toBeTruthy();
      }
    });

    it('returns all five zones for every enemy type', () => {
      for (const type of ALL_ENEMY_TYPES) {
        const suite = service.suiteFor(type as any);
        for (const zone of ZONES) {
          expect(
            suite[zone],
            `enemy "${type}" is missing zone "${zone}"`,
          ).toBeTruthy();
        }
      }
    });

    it('falls back to "scrap" suite for an unknown enemy type', () => {
      const fallback = service.suiteFor('unknownEnemy' as any);
      const scrap = service.suiteFor('scrap');
      expect(fallback).toEqual(scrap);
    });

    it('each ability has a name string', () => {
      for (const type of ALL_ENEMY_TYPES) {
        const suite = service.suiteFor(type as any);
        for (const zone of ZONES) {
          expect(
            typeof suite[zone].name,
            `${type}.${zone}.name should be a string`,
          ).toBe('string');
        }
      }
    });
  });

  // ── expandFromSpawn ──

  describe('expandFromSpawn', () => {
    it('resolves every unit def name without throwing', () => {
      for (const name of ALL_UNIT_DEF_NAMES) {
        expect(
          () => service.expandFromSpawn({ name }),
          `expandFromSpawn("${name}") should not throw`,
        ).not.toThrow();
      }
    });

    it('attaches the name field to the returned definition', () => {
      const def = service.expandFromSpawn({ name: 'Scrap Drone' });
      expect(def.name).toBe('Scrap Drone');
    });

    it('throws for an unknown unit name', () => {
      expect(() => service.expandFromSpawn({ name: 'Ghost Unit' })).toThrow(
        'Unknown enemy unit name: Ghost Unit',
      );
    });
  });

  // ── applyBattleScale ──

  describe('applyBattleScale', () => {
    it('scales hp and damage by the row multipliers', () => {
      const base = service.expandFromSpawn({ name: 'Scrap Drone' });
      const scaled = service.applyBattleScale(base, 0); // first battle = lowest scale
      const rows = service.battleEnemyScale();
      const row = rows[0];
      expect(scaled.hp).toBe(Math.max(1, Math.round(base.hp * row.hp)));
      expect(scaled.dmgScale).toBe(row.dmg);
    });

    it('clamps battle index to valid range', () => {
      const base = service.expandFromSpawn({ name: 'Scrap Drone' });
      // index 999 should clamp to last row, not throw
      expect(() => service.applyBattleScale(base, 999)).not.toThrow();
    });

    it('ensures dMin <= dMax after scaling', () => {
      for (const name of ALL_UNIT_DEF_NAMES.slice(0, 10)) {
        const base = service.expandFromSpawn({ name });
        const rows = service.battleEnemyScale();
        for (let i = 0; i < rows.length; i++) {
          const scaled = service.applyBattleScale(base, i);
          expect(scaled.dMin).toBeLessThanOrEqual(scaled.dMax);
        }
      }
    });

    it('hp is always at least 1 after scaling', () => {
      const base = service.expandFromSpawn({ name: 'Scrap Drone' });
      const rows = service.battleEnemyScale();
      for (let i = 0; i < rows.length; i++) {
        const scaled = service.applyBattleScale(base, i);
        expect(scaled.hp).toBeGreaterThanOrEqual(1);
      }
    });
  });

  // ── importJson / exportJson round-trip ──

  describe('importJson / exportJson', () => {
    it('round-trips the current data without loss', () => {
      const exported = service.exportJson();
      const result = service.importJson(exported);
      expect(result.ok).toBe(true);
    });

    it('returns ok: false for invalid JSON', () => {
      const result = service.importJson('not json at all {{');
      expect(result.ok).toBe(false);
    });

    it('returns ok: false when enemyAbilities key is missing', () => {
      const result = service.importJson(JSON.stringify({ someOtherKey: {} }));
      expect(result.ok).toBe(false);
    });
  });
});
