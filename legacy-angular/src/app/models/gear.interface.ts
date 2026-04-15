export type GearIcon = 'heart' | 'shield' | 'die' | 'bolt' | 'skull' | 'star';

export type GearEffect =
  | { type: 'rollBonus'; amount: number }
  | { type: 'maxHpBonus'; amount: number }
  | { type: 'battleStartShield'; amount: number }
  | { type: 'dmgReduction'; amount: number }
  | { type: 'battleStartCloak' }
  | { type: 'protocolOnBattleStart'; amount: number }
  | { type: 'healOnKill'; amount: number }
  | { type: 'dotDmgBonus'; amount: number }
  | { type: 'surviveOnce' }
  | { type: 'firstAbilityDmgBonus'; amount: number };

export interface GearDefinition {
  id: string;
  name: string;
  desc: string;
  rarity: 'uncommon' | 'rare';
  icon: GearIcon;
  effect: GearEffect;
}
