import { describe, it, expect } from 'vitest';
import type { HeroState } from '../models/hero.interface';
import type { EvolutionTier } from '../models/hero.interface';

// ── calculateXp extracted for testing without Angular DI ──
// Mirrors EvolutionService.calculateXp exactly.
function calculateXp(h: Pick<HeroState, 'tier' | 'bRolls'>): number {
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

// ── groupEvoPaths extracted for testing without Angular DI ──
interface GroupedEvoPath { name: string; focus: string; hp: number; abilities: any[]; }
function groupEvoPaths(evolutions: EvolutionTier[]): GroupedEvoPath[] {
  const map = new Map<string, GroupedEvoPath>();
  for (const evo of evolutions) {
    if (!map.has(evo.name)) {
      map.set(evo.name, { name: evo.name, focus: evo.focus, hp: evo.hp, abilities: [...evo.abilities] });
    } else {
      const existing = map.get(evo.name)!;
      existing.abilities.push(...evo.abilities);
      if (evo.hp > 0) existing.hp = evo.hp;
      if (evo.focus) existing.focus = evo.focus;
    }
  }
  return Array.from(map.values());
}

describe('EvolutionService — calculateXp', () => {
  it('returns 0 for a tier-2 hero', () => {
    expect(calculateXp({ tier: 2, bRolls: [15, 15, 15] })).toBe(0);
  });

  it('returns 0 when bRolls is empty', () => {
    expect(calculateXp({ tier: 1, bRolls: [] })).toBe(0);
  });

  it('returns 0 when bRolls is null/undefined', () => {
    expect(calculateXp({ tier: 1, bRolls: undefined as any })).toBe(0);
  });

  // XP tier thresholds (pts * 1.5 rounded)
  it('awards 2 XP for avg < 6 (pts=1)', () => {
    // avg = 3
    expect(calculateXp({ tier: 1, bRolls: [3, 3, 3] })).toBe(2);
  });

  it('awards 5 XP for avg in [6, 12] (pts=3)', () => {
    // avg = 9
    expect(calculateXp({ tier: 1, bRolls: [9, 9, 9] })).toBe(5);
  });

  it('awards 8 XP for avg in [13, 16] (pts=5)', () => {
    // avg = 15
    expect(calculateXp({ tier: 1, bRolls: [15, 15, 15] })).toBe(8);
  });

  it('awards 11 XP for avg in [17, 19] (pts=7)', () => {
    // avg = 18
    expect(calculateXp({ tier: 1, bRolls: [18, 18, 18] })).toBe(11);
  });

  it('awards 15 XP for avg = 20 (pts=10)', () => {
    expect(calculateXp({ tier: 1, bRolls: [20, 20, 20] })).toBe(15);
  });

  it('uses average across all bRolls for threshold', () => {
    // avg = (6 + 12) / 2 = 9 → pts=3 → 5 XP
    expect(calculateXp({ tier: 1, bRolls: [6, 12] })).toBe(5);
  });

  it('handles a single bRoll entry', () => {
    expect(calculateXp({ tier: 1, bRolls: [20] })).toBe(15);
  });
});

describe('EvolutionService — groupEvoPaths', () => {
  const makeTier = (name: string, hp: number, focus: string, abilities: any[] = []): EvolutionTier =>
    ({ name, hp, focus, abilities, xpCost: 0 } as any);

  it('returns one path per unique name', () => {
    const paths = groupEvoPaths([
      makeTier('Alpha', 60, 'dps'),
      makeTier('Beta', 55, 'support'),
    ]);
    expect(paths).toHaveLength(2);
    expect(paths.map(p => p.name)).toContain('Alpha');
    expect(paths.map(p => p.name)).toContain('Beta');
  });

  it('merges abilities from duplicate-named tiers', () => {
    const ab1 = { name: 'Ability 1' };
    const ab2 = { name: 'Ability 2' };
    const paths = groupEvoPaths([
      makeTier('Alpha', 60, 'dps', [ab1]),
      makeTier('Alpha', 0, '', [ab2]),
    ]);
    expect(paths).toHaveLength(1);
    expect(paths[0].abilities).toHaveLength(2);
  });

  it('updates hp from the second tier when > 0', () => {
    const paths = groupEvoPaths([
      makeTier('Alpha', 60, 'dps', []),
      makeTier('Alpha', 70, '', []),
    ]);
    expect(paths[0].hp).toBe(70);
  });

  it('does not override hp when second tier has hp = 0', () => {
    const paths = groupEvoPaths([
      makeTier('Alpha', 60, 'dps', []),
      makeTier('Alpha', 0, '', []),
    ]);
    expect(paths[0].hp).toBe(60);
  });

  it('returns an empty array for empty input', () => {
    expect(groupEvoPaths([])).toEqual([]);
  });
});
