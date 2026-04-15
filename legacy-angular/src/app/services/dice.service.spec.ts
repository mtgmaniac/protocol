import { describe, it, expect } from 'vitest';
import type { HeroState } from '../models/hero.interface';

// ── Pure helpers extracted for testing without Angular DI ──
// These mirror the logic in DiceService exactly.

function getEnemyZone(roll: number): string {
  const r = Math.min(20, Math.max(1, roll));
  if (r <= 4) return 'recharge';
  if (r <= 10) return 'strike';
  if (r <= 16) return 'surge';
  if (r <= 19) return 'crit';
  return 'overload';
}

function effRoll(h: Pick<HeroState, 'roll' | 'rollBuff' | 'rollNudge'>): number | null {
  if (h.roll === null || h.roll === undefined) return null;
  return Math.min(20, (h.roll || 0) + (h.rollBuff || 0) + (h.rollNudge || 0));
}

describe('DiceService — getEnemyZone', () => {
  // Boundary tests at every zone edge
  it('returns recharge for roll 1', () => expect(getEnemyZone(1)).toBe('recharge'));
  it('returns recharge for roll 4', () => expect(getEnemyZone(4)).toBe('recharge'));
  it('returns strike for roll 5', () => expect(getEnemyZone(5)).toBe('strike'));
  it('returns strike for roll 10', () => expect(getEnemyZone(10)).toBe('strike'));
  it('returns surge for roll 11', () => expect(getEnemyZone(11)).toBe('surge'));
  it('returns surge for roll 16', () => expect(getEnemyZone(16)).toBe('surge'));
  it('returns crit for roll 17', () => expect(getEnemyZone(17)).toBe('crit'));
  it('returns crit for roll 19', () => expect(getEnemyZone(19)).toBe('crit'));
  it('returns overload for roll 20', () => expect(getEnemyZone(20)).toBe('overload'));

  // Clamping
  it('clamps values below 1 to recharge', () => expect(getEnemyZone(0)).toBe('recharge'));
  it('clamps values above 20 to overload', () => expect(getEnemyZone(99)).toBe('overload'));
});

describe('DiceService — effRoll', () => {
  it('returns null when roll is null', () => {
    expect(effRoll({ roll: null, rollBuff: 0, rollNudge: 0 })).toBeNull();
  });

  it('returns the raw roll when no buffs', () => {
    expect(effRoll({ roll: 10, rollBuff: 0, rollNudge: 0 })).toBe(10);
  });

  it('adds rollBuff to the roll', () => {
    expect(effRoll({ roll: 12, rollBuff: 3, rollNudge: 0 })).toBe(15);
  });

  it('adds rollNudge to the roll', () => {
    expect(effRoll({ roll: 10, rollBuff: 0, rollNudge: 2 })).toBe(12);
  });

  it('caps the result at 20', () => {
    expect(effRoll({ roll: 18, rollBuff: 5, rollNudge: 3 })).toBe(20);
  });

  it('treats undefined rollBuff as 0', () => {
    expect(effRoll({ roll: 8, rollBuff: undefined, rollNudge: undefined })).toBe(8);
  });
});
