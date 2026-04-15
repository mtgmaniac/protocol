import { HeroAbility } from '../models/ability.interface';

const ri = (n: number | undefined | null): number =>
  n == null || !Number.isFinite(n) ? 0 : Math.round(n);

/** Whole-number stats for combat, badges, and the ability panel (single source of truth). */
export function normalizeHeroAbility(ab: HeroAbility): HeroAbility {
  const shield = ab.shield != null ? ri(ab.shield) : undefined;
  const shT = ab.shT != null ? ri(ab.shT) : undefined;
  const rfm = ab.rfm != null ? ri(ab.rfm) : undefined;
  const rfmT = ab.rfmT != null ? ri(ab.rfmT) : undefined;
  const rfT = ab.rfT != null ? ri(ab.rfT) : undefined;

  const result: HeroAbility = {
    ...ab,
    range: [ri(ab.range[0]), ri(ab.range[1])] as [number, number],
    dmg: ri(ab.dmg),
    dMin: ri(ab.dMin),
    dMax: ri(ab.dMax),
    dot: ri(ab.dot),
    dT: ri(ab.dT),
    rfe: ri(ab.rfe),
    rfT: rfT || undefined,
    heal: ri(ab.heal),
    shield: shield || undefined,
    shT: shT || undefined,
    rfm: rfm || undefined,
    rfmT: rfmT || undefined,
    freezeAllEnemyDice:
      ab.freezeAllEnemyDice != null && ri(ab.freezeAllEnemyDice) > 0
        ? ri(ab.freezeAllEnemyDice)
        : undefined,
    freezeEnemyDice:
      ab.freezeEnemyDice != null && ri(ab.freezeEnemyDice) > 0
        ? ri(ab.freezeEnemyDice)
        : undefined,
    freezeAnyDice:
      ab.freezeAnyDice != null && ri(ab.freezeAnyDice) > 0 ? ri(ab.freezeAnyDice) : undefined,
  };

  // Dev-time validation warnings
  if (result.dmg > 0 && result.rfeOnly) {
    console.warn(
      `[normalizeHeroAbility] Ability "${ab.name}" has both dmg > 0 and rfeOnly: true (conflicting flags).`,
    );
  }
  if (result.range[0] < 1 || result.range[0] > 20 || result.range[1] < 1 || result.range[1] > 20) {
    console.warn(
      `[normalizeHeroAbility] Ability "${ab.name}" has range [${result.range[0]}, ${result.range[1]}] outside [1, 20].`,
    );
  }
  if (result.heal < 0) {
    console.warn(`[normalizeHeroAbility] Ability "${ab.name}" has heal < 0 after normalization.`);
  }
  if ((result.shield ?? 0) < 0) {
    console.warn(`[normalizeHeroAbility] Ability "${ab.name}" has shield < 0 after normalization.`);
  }
  if (result.dmg < 0) {
    console.warn(`[normalizeHeroAbility] Ability "${ab.name}" has dmg < 0 after normalization.`);
  }

  return result;
}
