import { HeroAbility } from './ability.interface';
import { normalizeHeroAbility } from '../data/hero-ability-normalize';
import { HeroId } from './types';
import type { ShieldStack } from '../utils/shield-stack.util';

/** Squad picker grouping on the operation overlay. */
export type HeroPickerCategory = 'damage' | 'defense' | 'support' | 'control';

/** Per-hero −raw d20 from enemy abilities (e.g. rust jam on target); independent stacks like squad rfm. */
export type HeroRfmStack = { amt: number; turnsLeft: number };

export interface EvolutionTier {
  name: string;
  focus: string;
  hp: number;
  abilities: HeroAbility[];
}

export interface HeroDefinition {
  id: HeroId;
  name: string;
  cls: string;
  /** Shown on the “Pick 3” squad roster. */
  pickerCategory: HeroPickerCategory;
  /** Short line for squad selection (not shown in combat). */
  pickerBlurb: string;
  hp: number;
  sk: HeroId;
  /** Optional `/heroes/...` URL; dev editor + JSON can override the default portrait art. */
  portraitPath?: string;
  abilities: HeroAbility[];
  evolutions: EvolutionTier[];
}

export interface HeroState extends HeroDefinition {
  currentHp: number;
  maxHp: number;
  roll: number | null;
  rawRoll: number | null;
  rollNudge: number;
  rollBuff: number;
  rollBuffT: number;
  /** +rfm from ally-targeted abilities; merged into rollBuff at round reset (next roll only). */
  pendingRollBuff: number;
  pendingRollBuffT: number;
  /** Enemy-applied roll penalty stacks (rust targets this hero only). */
  heroRfmStacks: HeroRfmStack[];
  /** >0: cannot roll this player round; ability skipped (Cower). Ticks down after each player END TURN. */
  cowerTurns: number;
  confirmed: boolean;
  dot: number;
  dT: number;
  shield: number;
  shT: number;
  /** Independent shield layers; `shield` / `shT` are aggregates for UI and legacy reads. */
  shieldStacks: ShieldStack[];
  shTgtIdx: number | null;
  healTgtIdx: number | null;
  rfmTgtIdx: number | null;
  reviveTgtIdx: number | null;
  lockedTarget: number | undefined;
  cloaked: boolean;
  noRR: boolean;
  splitAlloc: Record<number, number>;
  tier: 1 | 2;
  xp: number;
  /** Void Wisp: double roll (keep lower) while set; ribbon clears after that player round ends. */
  cursed?: boolean;
  /** Skip the next N squad reveal rolls; previous roll/ability zone preserved until consumed. */
  dieFreezeRollsRemaining: number;
  /** Glacial Lattice: freeze target is this hero index (mutually exclusive with freezeDiceTgtEnemyIdx). */
  freezeDiceTgtHeroIdx: number | null;
  /** Glacial Lattice: freeze target is this enemy index. */
  freezeDiceTgtEnemyIdx: number | null;
  /** Rampage charges: next N direct ability attacks deal double damage (one charge consumed per attack). */
  rampageCharges: number;
  /** Permanent per-battle roll bonus from relics; not merged into rollBuff and not reset by resetHeroForNewRound. */
  relicRollBonus: number;
  /** Permanent gear roll bonus (set at equip time, persists through run). */
  gearRollBonus: number;
  /** Max HP bonus currently applied from gear (per-battle, reset in nextBattle). */
  gearMaxHpBonus: number;
  /** Dead Man's Chip: true after survive-once has triggered this battle. */
  surviveOnceFired: boolean;
  /** Exile Blade Core: true after first-ability damage bonus was consumed this battle. */
  firstAbilityFired: boolean;
  /** Which gear id this hero has equipped (null = none). */
  equippedGear: string | null;
  bRolls: number[];
  evolvedTo: string | null;
  _evoRollRecorded?: boolean;
  _actionLogged?: boolean;
}

export function createHeroState(def: HeroDefinition): HeroState {
  const evolutions = def.evolutions.map(e => ({
    ...e,
    abilities: e.abilities.map(normalizeHeroAbility),
  }));
  return {
    ...def,
    abilities: def.abilities.map(normalizeHeroAbility),
    evolutions,
    currentHp: def.hp,
    maxHp: def.hp,
    roll: null,
    rawRoll: null,
    rollNudge: 0,
    rollBuff: 0,
    rollBuffT: 0,
    pendingRollBuff: 0,
    pendingRollBuffT: 0,
    heroRfmStacks: [],
    cowerTurns: 0,
    confirmed: false,
    dot: 0,
    dT: 0,
    shield: 0,
    shT: 0,
    shieldStacks: [],
    shTgtIdx: null,
    healTgtIdx: null,
    rfmTgtIdx: null,
    reviveTgtIdx: null,
    lockedTarget: undefined,
    cloaked: false,
    noRR: false,
    splitAlloc: {},
    tier: 1,
    xp: 0,
    bRolls: [],
    evolvedTo: null,
    dieFreezeRollsRemaining: 0,
    freezeDiceTgtHeroIdx: null,
    freezeDiceTgtEnemyIdx: null,
    rampageCharges: 0,
    relicRollBonus: 0,
    gearRollBonus: 0,
    gearMaxHpBonus: 0,
    surviveOnceFired: false,
    firstAbilityFired: false,
    equippedGear: null,
  };
}
