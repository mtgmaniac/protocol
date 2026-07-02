/**
 * Tier-2 consumable modeling for battle-progress-sim.
 * One copy of `trackConsumableId` granted at the start of each battle (audit mode).
 */

export interface ItemEffect {
  type: string;
  amount?: number;
  shT?: number;
  turns?: number;
  pct?: number;
  rfT?: number;
  burnT?: number;
  skips?: number;
}

export interface ItemEntry {
  id: string;
  name: string;
  desc: string;
  rarity: string;
  icon?: string;
  target: string;
  effect: ItemEffect;
}

export const ITEM_PROTOCOL_COST = 1;

/** Used immediately at battle start (no targeting heuristic). */
export const BATTLE_START_CONSUMABLE_TYPES = new Set([
  'healAll',
  'shieldAll',
  'gainProtocol',
  'enemyDieFreezeAll',
  'xpBoost',
]);

/** No combat impact under current sim (cloak evasion / die reroll UI). */
export const SKIPPED_CONSUMABLE_TYPES = new Set([
  'cloak',
  'cloakAll',
  'enemyRerollDie',
  'enemyRerollAll',
]);

export function buildItemCatalog(raw: { items: ItemEntry[] }): Record<string, ItemEntry> {
  const out: Record<string, ItemEntry> = {};
  for (const entry of raw.items ?? []) {
    out[entry.id] = entry;
  }
  return out;
}
