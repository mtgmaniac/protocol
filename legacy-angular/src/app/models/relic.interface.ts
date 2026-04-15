export type RelicIcon = 'heart' | 'shield' | 'die' | 'bolt' | 'skull' | 'star';

export type RelicEffect =
  | { type: 'enemyDmgMult'; mult: number }
  | { type: 'heroDmgMult'; mult: number }
  | { type: 'heroShieldPerTurn'; amount: number }
  | { type: 'heroHealPerTurn'; amount: number }
  | { type: 'enemyDotPermanent'; amount: number }
  | { type: 'battleStartHalfHp' }
  | { type: 'enemyStartRfe'; amount: number }
  | { type: 'heroStartRollBuff'; amount: number }
  | { type: 'dotAmplified'; bonus: number }
  | { type: 'auraEnemyDmg'; amount: number }
  | { type: 'protocolFree' }
  | { type: 'enemyHpEscalation'; reductionPerBattle: number }
  | { type: 'chainReaction'; amount: number };

export interface RelicDefinition {
  id: string;
  name: string;
  desc: string;
  icon: RelicIcon;
  effect: RelicEffect;
}
