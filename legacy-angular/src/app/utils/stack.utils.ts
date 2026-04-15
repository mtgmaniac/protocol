/** Decrements turnsLeft on each stack entry and removes expired ones. */
export function tickStacks<T extends { turnsLeft: number }>(stacks: T[]): T[] {
  return stacks
    .map(s => ({ ...s, turnsLeft: s.turnsLeft - 1 }))
    .filter(s => s.turnsLeft > 0);
}
