import { describe, it, expect } from 'vitest';
import { tickStacks } from './stack.utils';

describe('tickStacks', () => {
  it('decrements turnsLeft by 1 on each entry', () => {
    const result = tickStacks([
      { turnsLeft: 3, amt: 2 },
      { turnsLeft: 1, amt: 5 },
    ]);
    expect(result[0].turnsLeft).toBe(2);
    // second entry expires so only one remains
    expect(result).toHaveLength(1);
  });

  it('removes entries whose turnsLeft reaches 0', () => {
    const result = tickStacks([{ turnsLeft: 1, amt: 4 }]);
    expect(result).toHaveLength(0);
  });

  it('removes entries whose turnsLeft would go below 0', () => {
    // Should not happen in practice, but handles it gracefully
    const result = tickStacks([{ turnsLeft: 0, amt: 1 }]);
    expect(result).toHaveLength(0);
  });

  it('returns an empty array when given an empty array', () => {
    expect(tickStacks([])).toEqual([]);
  });

  it('keeps entries with turnsLeft > 1 after decrement', () => {
    const result = tickStacks([
      { turnsLeft: 5, amt: 1 },
      { turnsLeft: 2, amt: 3 },
    ]);
    expect(result).toHaveLength(2);
    expect(result[0].turnsLeft).toBe(4);
    expect(result[1].turnsLeft).toBe(1);
  });

  it('preserves all extra fields on surviving entries', () => {
    const result = tickStacks([{ turnsLeft: 2, amt: 7, zone: 'strike' }]);
    expect(result[0].amt).toBe(7);
    expect((result[0] as any).zone).toBe('strike');
  });

  it('does not mutate the original array', () => {
    const input = [{ turnsLeft: 2, amt: 1 }];
    tickStacks(input);
    expect(input[0].turnsLeft).toBe(2); // unchanged
  });
});
