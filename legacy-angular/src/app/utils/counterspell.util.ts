/** Example chip label when ability uses default mid value in UI. */
export const COUNTER_CHIP_LABEL_EXAMPLE = 'C 50%';

export function counterChipLabel(pct: number): string {
  const p = Math.max(0, Math.min(100, Math.round(pct)));
  return `C ${p}%`;
}

export function counterAbilityTooltip(pct: number): string {
  const p = Math.max(0, Math.min(100, Math.round(pct)));
  return `Caster gains C ${p}%: next hero damage attempt has a ${p}% chance to reflect that damage to the attacker.`;
}
