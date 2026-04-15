import type { EnemyRace, EnemyType } from '../models/types';

/** Shared neutral frame for all player heroes (not per-class). */
export const HERO_UNIT_FRAME_COLOR = '#5c7fa3';

/** One border accent per enemy race — every unit of that race uses the same color. */
export const ENEMY_RACE_FRAME_COLORS: Record<EnemyRace, string> = {
  facility: '#708cad',
  hive: '#5cad72',
  veil: '#3ec9c4',
  void: '#a080ff',
  beast: '#d4a05a',
  signal: '#6b9fe8',
};

export const ENEMY_TYPE_TO_RACE: Record<EnemyType, EnemyRace> = {
  scrap: 'facility',
  rust: 'facility',
  patrol: 'facility',
  guard: 'facility',
  warden: 'facility',
  volt: 'facility',
  boss: 'facility',
  skitter: 'hive',
  mite: 'hive',
  stalker: 'hive',
  carapace: 'hive',
  brood: 'hive',
  spewer: 'hive',
  hiveBoss: 'hive',
  veilShard: 'veil',
  veilPrism: 'veil',
  veilAegis: 'veil',
  veilResonance: 'veil',
  veilNull: 'veil',
  veilStorm: 'veil',
  veilSynapse: 'veil',
  veilBoss: 'veil',
  voidWisp: 'void',
  voidAcolyte: 'void',
  voidScribe: 'void',
  voidBinder: 'void',
  voidGlimmer: 'void',
  voidChanneler: 'void',
  voidCircletBoss: 'void',
  beastMonkey: 'beast',
  beastWolf: 'beast',
  beastLynx: 'beast',
  beastBison: 'beast',
  beastHyena: 'beast',
  beastBadger: 'beast',
  beastTyrant: 'beast',
  signalSkimmer: 'signal',
  commsHex: 'signal',
};

export function enemyUnitFrameColor(type: EnemyType): string {
  const race = ENEMY_TYPE_TO_RACE[type];
  return ENEMY_RACE_FRAME_COLORS[race];
}
