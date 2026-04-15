import { tickStacks } from './stack.utils';

/** One shield application; FIFO damage absorption; expires when `turnsLeft` hits 0 at end of enemy phase. */
export interface ShieldStack {
  amt: number;
  turnsLeft: number;
}

export function coalesceShieldStacks(u: {
  shieldStacks?: ShieldStack[] | null;
  shield: number;
  shT: number;
}): ShieldStack[] {
  if (u.shieldStacks?.length) {
    return u.shieldStacks.filter(s => s.amt > 0 && s.turnsLeft > 0);
  }
  if (u.shield > 0 && u.shT > 0) {
    return [{ amt: u.shield, turnsLeft: u.shT }];
  }
  return [];
}

export function appendShieldLayer(stacks: ShieldStack[], amount: number, turnsLeft: number): ShieldStack[] {
  const base = stacks.filter(s => s.amt > 0 && s.turnsLeft > 0);
  const a = Math.max(0, Math.round(amount));
  const t = Math.max(1, Math.round(turnsLeft));
  if (a <= 0) return base;
  return [...base, { amt: a, turnsLeft: t }];
}

export function tickShieldLayers(stacks: ShieldStack[]): ShieldStack[] {
  return tickStacks(stacks.filter(s => s.amt > 0 && s.turnsLeft > 0));
}

/** Oldest layers absorb first (FIFO). */
export function absorbShieldDamageFifo(stacks: ShieldStack[], dmg: number): { stacks: ShieldStack[]; absorbed: number } {
  if (dmg <= 0) {
    const clean = stacks.filter(s => s.amt > 0 && s.turnsLeft > 0);
    return { stacks: clean, absorbed: 0 };
  }
  let rem = dmg;
  const out: ShieldStack[] = [];
  for (const s of stacks) {
    if (s.amt <= 0 || s.turnsLeft <= 0) continue;
    if (rem <= 0) {
      out.push({ ...s });
      continue;
    }
    const take = Math.min(s.amt, rem);
    const left = s.amt - take;
    rem -= take;
    if (left > 0) out.push({ amt: left, turnsLeft: s.turnsLeft });
  }
  return { stacks: out, absorbed: dmg - rem };
}

export function shieldFieldsFromStacks(stacks: ShieldStack[]): {
  shield: number;
  shT: number;
  shieldStacks: ShieldStack[];
} {
  const clean = stacks.filter(s => s.amt > 0 && s.turnsLeft > 0);
  const shield = clean.reduce((x, s) => x + s.amt, 0);
  const shT = clean.length ? Math.max(...clean.map(s => s.turnsLeft)) : 0;
  return {
    shield,
    shT: shield > 0 ? shT : 0,
    shieldStacks: clean,
  };
}

export function addShieldToUnit(
  u: { shieldStacks?: ShieldStack[] | null; shield: number; shT: number },
  amount: number,
  turnsLeft: number,
): { shield: number; shT: number; shieldStacks: ShieldStack[] } {
  const base = coalesceShieldStacks(u);
  const next = appendShieldLayer(base, amount, turnsLeft);
  return shieldFieldsFromStacks(next);
}

export function tickUnitShield(
  u: { shieldStacks?: ShieldStack[] | null; shield: number; shT: number },
): { shield: number; shT: number; shieldStacks: ShieldStack[] } {
  const base = coalesceShieldStacks(u);
  const ticked = tickShieldLayers(base);
  return shieldFieldsFromStacks(ticked);
}

export function absorbDamageThroughShield(
  u: { shieldStacks?: ShieldStack[] | null; shield: number; shT: number },
  dmg: number,
): { shield: number; shT: number; shieldStacks: ShieldStack[]; absorbed: number } {
  const base = coalesceShieldStacks(u);
  const { stacks, absorbed } = absorbShieldDamageFifo(base, dmg);
  return { ...shieldFieldsFromStacks(stacks), absorbed };
}
