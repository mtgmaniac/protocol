import type { ItemRarity } from './types';

export type ItemTargetKind = 'none' | 'ally' | 'allyDead' | 'enemy';

export type ItemEffect =
  | { type: 'heal'; amount: number }
  | { type: 'shield'; amount: number; shT: number }
  | { type: 'rollBuff'; amount: number; turns: number }
  | { type: 'revive'; pct: number }
  | { type: 'enemyRfe'; amount: number; rfT: number }
  | { type: 'enemyDmg'; amount: number }
  | { type: 'enemyDot'; amount: number; dT: number }
  | { type: 'cloak' }
  | { type: 'cloakAll' }
  | { type: 'xpBoost'; amount: number }
  | { type: 'enemyRerollDie' }
  | { type: 'enemyRerollAll' }
  | { type: 'enemyDieFreeze'; skips: number };

export interface ItemDefinition {
  id: string;
  name: string;
  desc: string;
  rarity: ItemRarity;
  /** Icon key for protocol strip / draft */
  icon: 'heart' | 'shield' | 'die' | 'bolt' | 'skull' | 'star' | 'cloak';
  target: ItemTargetKind;
  effect: ItemEffect;
}

/** Player tapped an inventory slot and must pick a target (or cancel). */
export interface PendingItemSelection {
  invSlot: number;
  itemId: string;
}
