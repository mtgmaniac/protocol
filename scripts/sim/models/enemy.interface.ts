import type { AIType, EnemyType } from './types';

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
  summonElite?: boolean;
  /** Fallen allies (display names) restored on phase 2: dead revived, living healed to full. */
  p2ReviveNames?: string[];
}
