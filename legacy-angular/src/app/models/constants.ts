import type { ItemRarity } from './types';

export const PROTOCOL_MAX = 10;
/** Gained at start of each player round (after prior END TURN). */
export const PROTOCOL_ROUND = 1;
export const PROTOCOL_REROLL_COST = 2;
export const PROTOCOL_NUDGE_COST = 1;
/** Added to hero rollNudge; effective roll capped at 20. */
export const PROTOCOL_NUDGE_DELTA = 5;
export const ITEM_PROTOCOL_COST: Record<ItemRarity, number> = {
  common: 1,
  uncommon: 2,
  rare: 3,
  legendary: 5,
};

export const INVENTORY_MAX = 3;

/** Reserved: milestone-only drafts (e.g. battles 3 / 6 / 9). Combat currently drafts after every battle for testing. */
export const ITEM_DRAFT_AFTER_BATTLE_IDX = [2, 5, 8] as const;

export const BUILD_VERSION = 'v0.94.0';
export const BUILD_STAMP = '2026-04-05';
