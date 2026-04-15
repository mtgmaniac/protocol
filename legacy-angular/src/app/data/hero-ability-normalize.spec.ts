import { describe, it, expect, vi, beforeEach } from 'vitest';
import { normalizeHeroAbility } from './hero-ability-normalize';
import type { HeroAbility } from '../models/ability.interface';

function ability(overrides: Partial<HeroAbility> = {}): HeroAbility {
  return {
    name: 'Test Ability',
    zone: 'strike',
    range: [7, 12],
    dmg: 0,
    dMin: 0,
    dMax: 0,
    dot: 0,
    dT: 0,
    rfe: 0,
    heal: 0,
    eff: '',
    ...overrides,
  } as HeroAbility;
}

describe('normalizeHeroAbility', () => {
  beforeEach(() => {
    vi.spyOn(console, 'warn').mockImplementation(() => {});
    vi.clearAllMocks();
  });

  // ── Numeric rounding ──

  it('rounds float dmg to nearest integer', () => {
    const result = normalizeHeroAbility(ability({ dmg: 4.7 }));
    expect(result.dmg).toBe(5);
  });

  it('rounds float heal to nearest integer', () => {
    const result = normalizeHeroAbility(ability({ heal: 3.3 }));
    expect(result.heal).toBe(3);
  });

  it('rounds float dot to nearest integer', () => {
    const result = normalizeHeroAbility(ability({ dot: 2.6, dT: 2.1 }));
    expect(result.dot).toBe(3);
    expect(result.dT).toBe(2);
  });

  it('rounds float rfe to nearest integer', () => {
    const result = normalizeHeroAbility(ability({ rfe: 1.9 }));
    expect(result.rfe).toBe(2);
  });

  it('rounds range bounds to integers', () => {
    const result = normalizeHeroAbility(ability({ range: [6.8, 12.4] as any }));
    expect(result.range[0]).toBe(7);
    expect(result.range[1]).toBe(12);
  });

  it('converts null/undefined optional numerics to 0 or undefined', () => {
    const result = normalizeHeroAbility(ability({ dmg: null as any, heal: undefined }));
    expect(result.dmg).toBe(0);
    expect(result.heal).toBe(0);
  });

  // ── Freeze fields ──

  it('keeps freezeEnemyDice when positive', () => {
    const result = normalizeHeroAbility(ability({ freezeEnemyDice: 2 }));
    expect(result.freezeEnemyDice).toBe(2);
  });

  it('drops freezeEnemyDice when zero', () => {
    const result = normalizeHeroAbility(ability({ freezeEnemyDice: 0 }));
    expect(result.freezeEnemyDice).toBeUndefined();
  });

  it('keeps freezeAnyDice when positive', () => {
    const result = normalizeHeroAbility(ability({ freezeAnyDice: 1 }));
    expect(result.freezeAnyDice).toBe(1);
  });

  // ── Validation warnings ──

  it('warns when dmg > 0 and rfeOnly: true', () => {
    normalizeHeroAbility(ability({ dmg: 5, rfeOnly: true }));
    expect(console.warn).toHaveBeenCalledWith(
      expect.stringContaining('dmg > 0 and rfeOnly'),
    );
  });

  it('warns when range values are outside [1, 20]', () => {
    normalizeHeroAbility(ability({ range: [0, 21] as any }));
    expect(console.warn).toHaveBeenCalledWith(
      expect.stringContaining('outside [1, 20]'),
    );
  });

  it('warns when heal < 0', () => {
    normalizeHeroAbility(ability({ heal: -3 }));
    expect(console.warn).toHaveBeenCalledWith(expect.stringContaining('heal < 0'));
  });

  it('warns when dmg < 0', () => {
    normalizeHeroAbility(ability({ dmg: -1 }));
    expect(console.warn).toHaveBeenCalledWith(expect.stringContaining('dmg < 0'));
  });

  it('does not warn for a clean ability', () => {
    normalizeHeroAbility(ability({ dmg: 5, range: [7, 12] }));
    expect(console.warn).not.toHaveBeenCalled();
  });
});
