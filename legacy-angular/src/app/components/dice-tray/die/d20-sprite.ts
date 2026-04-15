/** 6×6 sheet; use % positions with background-size 600% 600% to avoid subpixel bleed. */
export const D20_GRID = 6;

/** Tumble frames in playback order (col, row), 0-based — excludes static [0,0]. */
export const D20_ROLL_CELLS: ReadonlyArray<readonly [number, number]> = [
  [1, 0],
  [2, 0],
  [3, 0],
  [4, 0],
  [5, 0],
  [0, 1],
  [1, 1],
  [2, 1],
  [0, 2],
  [1, 2],
];

export function d20SpritePositionPercent(col: number, row: number): string {
  const max = D20_GRID - 1;
  const x = (col / max) * 100;
  const y = (row / max) * 100;
  return `${x}% ${y}%`;
}

/**
 * Map effective D20 result 1–20 to sheet cell (col, row).
 * 10–14 use row 4 (real “10”…“14” art). The single-digit “0” at (5,3) is never used for results.
 */
export function d20ResultCell(roll: number): readonly [number, number] {
  const n = Math.min(20, Math.max(1, Math.floor(roll)));
  if (n <= 4) return [n + 1, 2] as const;
  if (n <= 9) return [n - 5, 3] as const;
  if (n <= 14) return [n - 10, 4] as const;
  return [n - 15, 5] as const;
}

export function d20NeutralCell(): readonly [number, number] {
  return [0, 0] as const;
}
