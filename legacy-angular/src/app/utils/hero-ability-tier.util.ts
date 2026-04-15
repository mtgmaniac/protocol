import type { HeroAbility } from '../models/ability.interface';

/** Tier-1: shield / roll buff / roll debuff durations capped at 1 turn; DoT duration unchanged. */
export function clampHeroAbilityForTier1(ab: HeroAbility): HeroAbility {
  const out: HeroAbility = { ...ab };
  if ((out.shield || 0) > 0 || out.shieldAll) {
    out.shT = Math.min(1, out.shT ?? 1);
  }
  if ((out.rfe || 0) > 0) {
    out.rfT = Math.min(1, out.rfT ?? 1);
  }
  if ((out.rfm || 0) > 0) {
    out.rfmT = Math.min(1, out.rfmT ?? 1);
  }
  return out;
}
