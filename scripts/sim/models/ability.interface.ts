import type { Zone } from './types';

export interface HeroAbility {
  zone: Zone;
  range: [number, number];
  name: string;
  eff: string;
  dmg: number;
  dMin: number;
  dMax: number;
  burn: number;
  burnT: number;
  rfe: number;
  rfT?: number;
  heal: number;
  shTgt?: boolean;
  shield?: number;
  shieldAll?: boolean;
  healTgt?: boolean;
  healAll?: boolean;
  healLowest?: boolean;
  revive?: boolean;
  rfm?: number;
  rfmT?: number;
  /** If set, player picks an ally; that hero receives the rfm roll buff instead of the caster. */
  rfmTgt?: boolean;
  cloak?: boolean;
  taunt?: boolean;
  blastAll?: boolean;
  multiHit?: boolean;
  ignSh?: boolean;
  splitDmg?: boolean;
  rfeAll?: boolean;
  rfeOnly?: boolean;
  /** Add this many “skip tray roll” charges to every living enemy (cryo-style). */
  freezeAllEnemyDice?: number;
  /** Add skip charges to the enemy targeted by this ability’s damage (single-target). */
  freezeEnemyDice?: number;
  /** Freeze one squad/enemy die for N reveal skips — pick any hero or enemy (separate from damage target). */
  freezeAnyDice?: number;
  /** Grant N protocol when this ability resolves (applied end of round via battle_scene). */
  gainProtocol?: number;
  /** Grant N rampage charges to this hero: next N direct ability attacks deal double damage. */
  grantRampage?: number;
}

export interface EnemyAbility {
  name: string;
  eff: string;
  dmg: number;
  dmgP2?: number;
  burn: number;
  burnT: number;
  heal: number;
  rfe: number;
  rfT?: number;
  shield: number;
  shieldAlly?: number;
  rfm?: number;
  rfmT?: number;
  wipeShields?: boolean;
  /** Heal this enemy for N% of HP damage dealt (after shield); never combine with `burn` on the same ability. */
  lifestealPct?: number;
  zone?: Zone;
  /** Veil Concord overload only: % chance (0–100) on natural 20 + overload tier; requires `summonElite` on unit def; max 3 enemies. */
  summonChance?: number;
  /** Grunt unit name in enemyUnitDefs (`ai: dumb`). If omitted, uses mode pool from `DEFAULT_SUMMON_GRUNTS` (veil when added). */
  summonName?: string;
  /** +effective d20 for this enemy’s next tray roll (capped in zone math). */
  erb?: number;
  erbT?: number;
  /** If true, `erb` applies to all living enemies. */
  erbAll?: boolean;
  /** If set and positive, the caster gains a counter buff (% chance to reflect the next hero damage attempt to the attacker). */
  /** Ward: blocks the next ability that targets this unit, then breaks. */
  ward?: boolean;
  /** Add rampage charges to self: next direct hit damage ×2 per charge (consumed one per hit). */
  grantRampage?: number;
  /** Add rampage charges to all living enemies (stampede / pack frenzy). */
  grantRampageAll?: number;
  /** Freeze the targeted hero's die: locked in the tray, hero skips its next N reveals. */
  freezeEnemyDice?: number;
  /** Freeze every hero die for N reveal skips. */
  freezeAllEnemyDice?: number;
  /** Veil grunt: this enemy forces all heroes to target it next player phase (clears when it dies). */
  enemySelfTaunt?: boolean;
  /** Void grunt: targeted hero must roll twice next turn and keep the lower result. */
  curseDice?: boolean;
  /** Menagerie grunt: damage bonus based on number of living allies of the same enemy type. */
  packBonus?: boolean;
  shieldP2?: number;
  shieldAllyAll?: boolean;
  blastAll?: boolean;
}

export type EnemyAbilitySuite = Record<Zone, EnemyAbility>;
