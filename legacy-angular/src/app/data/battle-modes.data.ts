import type { BattleModeId } from '../models/types';
import raw from './json/battle-modes.json';

/** One encounter: enemy names resolve via EnemyContentService unit defs. */
export interface BattleSpawn {
  enemies: { name: string }[];
}

export interface BattleModeConfig {
  id: BattleModeId;
  label: string;
  blurb: string;
  battles: BattleSpawn[];
  victoryTitle: string;
  victorySub: string;
  /** Multiplier on enemy max HP after per-battle scale (1 = default). */
  trackHpScale: number;
}

type RawMode = {
  label: string;
  blurb: string;
  victoryTitle: string;
  victorySub: string;
  battles: BattleSpawn[];
  trackHpScale?: number;
};

const ORDER = raw.order as BattleModeId[];

function buildBattleModes(): Record<BattleModeId, BattleModeConfig> {
  const modes = raw.modes as Record<string, RawMode>;
  const out = {} as Record<BattleModeId, BattleModeConfig>;
  for (const id of ORDER) {
    const m = modes[id];
    if (!m) continue;
    out[id] = {
      id,
      label: m.label,
      blurb: m.blurb,
      battles: m.battles,
      victoryTitle: m.victoryTitle,
      victorySub: m.victorySub,
      trackHpScale: m.trackHpScale ?? 1,
    };
  }
  return out;
}

export const BATTLE_MODE_ORDER: BattleModeId[] = ORDER;

export const BATTLE_MODES: Record<BattleModeId, BattleModeConfig> = buildBattleModes();

export const DEFAULT_BATTLE_MODE = 'facility' satisfies BattleModeId;

/** Fallback grunt pool when a Veil overload has `summonChance` but no `summonName` (extend when `veil` mode exists). */
export const DEFAULT_SUMMON_GRUNTS: Record<BattleModeId, string[]> = {
  facility: ['Scrap Drone', 'Rust Drone'],
  hive: ['Skitterling', 'Bloodmite'],
  veil: ['Shardmite', 'Prism Charger'],
  voidCirclet: ['Sparksprite'],
  stellarMenagerie: ['Pack Wolf', 'Rift Macaque'],
};

export function battleModeConfig(id: BattleModeId): BattleModeConfig {
  return BATTLE_MODES[id] ?? BATTLE_MODES[DEFAULT_BATTLE_MODE];
}

export function battlesForMode(id: BattleModeId): BattleSpawn[] {
  return battleModeConfig(id).battles;
}

export function battleCountForMode(id: BattleModeId): number {
  return battlesForMode(id).length;
}
