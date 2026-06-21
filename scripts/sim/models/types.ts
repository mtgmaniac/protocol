/** Player-selectable operation / battle track (more modes later; chain into “levels” later). */
export type BattleModeId = 'facility' | 'hive' | 'veil' | 'voidCirclet' | 'stellarMenagerie';

export type Zone = 'recharge' | 'strike' | 'surge' | 'crit' | 'overload';
export type GamePhase = 'player' | 'enemy' | 'over';
export type AIType = 'dumb' | 'smart';
export type EnemyType =
  | 'scrap'
  | 'rust'
  | 'patrol'
  | 'guard'
  | 'warden'
  | 'volt'
  | 'boss'
  | 'skitter'
  | 'mite'
  | 'stalker'
  | 'carapace'
  | 'brood'
  | 'spewer'
  | 'hiveBoss'
  | 'veilShard'
  | 'veilPrism'
  | 'veilAegis'
  | 'veilResonance'
  | 'veilNull'
  | 'veilStorm'
  | 'veilSynapse'
  | 'veilBoss'
  | 'voidWisp'
  | 'voidAcolyte'
  | 'voidScribe'
  | 'voidBinder'
  | 'voidGlimmer'
  | 'voidChanneler'
  | 'voidCircletBoss'
  | 'beastMonkey'
  | 'beastWolf'
  | 'beastLynx'
  | 'beastBison'
  | 'beastHyena'
  | 'beastBadger'
  | 'beastTyrant'
  | 'signalSkimmer'
  | 'commsHex';

/** Visual grouping for enemy card frames — matches operation tracks (facility, hive, veil, void, beasts) plus comms drones. */
export type EnemyRace = 'facility' | 'hive' | 'veil' | 'void' | 'beast' | 'signal';

export type LogClass = '' | 'pl' | 'en' | 'sy' | 'bl' | 'vi' | 'de';
export type ProtocolAction = 'reroll' | 'nudge' | null;
export type TargetPickKind =
  | 'enemy'
  | 'heal'
  | 'shield'
  | 'rollBuff'
  | 'revive'
  | 'freezeDice'
  | 'itemAlly'
  | 'itemAllyDead'
  | null;

export type ItemRarity = 'common' | 'uncommon' | 'rare' | 'legendary';
export type LogMode = 'min' | 'all';
export type HeroId =
  | 'pulse'
  | 'combat'
  | 'shield'
  | 'avalanche'
  | 'medic'
  | 'engineer'
  | 'ghost'
  | 'breaker';

export const ZONES: Zone[] = ['recharge', 'strike', 'surge', 'crit', 'overload'];

export const ZONE_LABELS: Record<Zone, string> = {
  recharge: 'RECHARGE',
  strike: 'STRIKE',
  surge: 'SURGE',
  crit: 'CRIT',
  overload: 'OVERLOAD',
};

export const ZONE_COLORS: Record<Zone, string> = {
  recharge: '#1d9e75',
  strike: '#2e7dd4',
  surge: '#c47a1a',
  crit: '#e8b84a',
  overload: '#d84a2a',
};

