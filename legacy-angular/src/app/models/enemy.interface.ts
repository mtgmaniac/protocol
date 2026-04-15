import { EnemyAbility } from './ability.interface';
import { AIType, EnemyType, HeroId, Zone } from './types';
import type { ShieldStack } from '../utils/shield-stack.util';

/** Per-application enemy roll debuff; each stack expires after its own `turnsLeft` player end turns. */
export interface EnemyRfeStack {
  amt: number;
  turnsLeft: number;
}

export function enemyRfeFromStacks(stacks: EnemyRfeStack[]): { rfe: number; rfT: number } {
  const active = stacks.filter(s => s.turnsLeft > 0);
  const rfe = active.reduce((a, s) => a + s.amt, 0);
  const rfT = active.reduce((m, s) => Math.max(m, s.turnsLeft), 0);
  return { rfe, rfT };
}

export function tickEnemyRfeStacks(stacks: EnemyRfeStack[]): EnemyRfeStack[] {
  return stacks
    .map(s => ({ amt: s.amt, turnsLeft: s.turnsLeft - 1 }))
    .filter(s => s.turnsLeft > 0);
}

export interface EnemyDefinition {
  name: string;
  hp: number;
  dMin: number;
  dMax: number;
  type: EnemyType;
  ai: AIType;
  p2dMin?: number;
  p2dMax?: number;
  pThr?: number;
  /** Veil Concord (etc.): allows overload `summonChance` / natural-20 summon. Facility & hive elites omit this. */
  summonElite?: boolean;
}

export interface EnemyState extends EnemyDefinition {
  id: number;
  currentHp: number;
  maxHp: number;
  dead: boolean;
  rfe: number;
  rfT: number;
  rfeStacks: EnemyRfeStack[];
  p2: boolean;
  dot: number;
  dT: number;
  shield: number;
  shT: number;
  shieldStacks: ShieldStack[];
  targeting: HeroId | null;
  dumbStickyId: HeroId | null;
  preRoll: number;
  effRoll: number;
  curZone: Zone;
  plan: EnemyAbility | null;
  dmgScale: number;
  /** +d20 for zone resolution on next enemy roll (player tray reveal). */
  rollBuff: number;
  rollBuffT: number;
  /** Next direct hit(s) on a hero deal double damage; one charge consumed per damaging hit. */
  rampageCharges: number;
  /** Skip the next N squad reveal rolls; die/plan preserved across enemy→player clear until consumed. */
  dieFreezeRollsRemaining: number;
  /**
   * Enemy self-buff from counter abilities (e.g. Seal Sigil): % chance to reflect the next hero damage attempt.
   * Cleared after one attempt, at end of player round if no hero hit, or at end of enemy phase if still active.
   */
  counterReflectPct: number | null;
  /** True after a hero ability damage line targets this enemy while counter was active (this player round). */
  counterTaggedThisPlayerRound: boolean;
}

export function createEnemyState(def: EnemyDefinition, id: number): EnemyState {
  return {
    ...def,
    id,
    currentHp: def.hp,
    maxHp: def.hp,
    dead: false,
    rfe: 0,
    rfT: 0,
    rfeStacks: [],
    p2: false,
    dot: 0,
    dT: 0,
    shield: 0,
    shT: 0,
    shieldStacks: [],
    targeting: null,
    dumbStickyId: null,
    preRoll: 0,
    effRoll: 0,
    curZone: 'recharge',
    plan: null,
    dmgScale: 1,
    rollBuff: 0,
    rollBuffT: 0,
    rampageCharges: 0,
    dieFreezeRollsRemaining: 0,
    counterReflectPct: null,
    counterTaggedThisPlayerRound: false,
  };
}
