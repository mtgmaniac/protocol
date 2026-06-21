/**
 * Tier-1 gear passive modeling for battle-progress-sim.
 * Mirrors combat_manager gear hooks; shared effect applier for future consumables (Tier 2).
 */

export interface GearEffect {
  type: string;
  amount?: number;
  rollAmount?: number;
}

export interface GearEntry {
  id: string;
  name: string;
  desc: string;
  rarity: string;
  icon: string;
  effect: GearEffect;
}

export interface SimGearTotals {
  maxHpBonus: number;
  permRollBonus: number;
  dmgReduction: number;
  dotDmgBonus: number;
  lifestealPct: number;
  shieldPierce: number;
  healOnKill: number;
  protocolOnBattleStart: number;
  protocolOnKill: number;
  protocolOnKillAny: number;
  firstAbilityDmgBonus: number;
  firstAbilityEcho: boolean;
  battleStartShield: number;
  battleStartRoll: number;
  surviveOnce: boolean;
}

export interface SimGearBattleFlags {
  firstAbilityDmgFired: boolean;
  firstAbilityEchoUsed: boolean;
  surviveOnceUsed: boolean;
}

export function emptyGearTotals(): SimGearTotals {
  return {
    maxHpBonus: 0,
    permRollBonus: 0,
    dmgReduction: 0,
    dotDmgBonus: 0,
    lifestealPct: 0,
    shieldPierce: 0,
    healOnKill: 0,
    protocolOnBattleStart: 0,
    protocolOnKill: 0,
    protocolOnKillAny: 0,
    firstAbilityDmgBonus: 0,
    firstAbilityEcho: false,
    battleStartShield: 0,
    battleStartRoll: 0,
    surviveOnce: false,
  };
}

export function emptyGearBattleFlags(): SimGearBattleFlags {
  return {
    firstAbilityDmgFired: false,
    firstAbilityEchoUsed: false,
    surviveOnceUsed: false,
  };
}

export function accumulateGearEffect(totals: SimGearTotals, effect: GearEffect): void {
  const t = effect.type;
  const amt = effect.amount ?? 0;
  switch (t) {
    case 'rollBonus':
      totals.permRollBonus += amt;
      break;
    case 'maxHpBonus':
      totals.maxHpBonus += amt;
      break;
    case 'dotDmgBonus':
      totals.dotDmgBonus += amt;
      break;
    case 'dmgReduction':
      totals.dmgReduction += amt;
      break;
    case 'surviveOnce':
      totals.surviveOnce = true;
      break;
    case 'firstAbilityDmgBonus':
      totals.firstAbilityDmgBonus += amt;
      break;
    case 'healOnKill':
      totals.healOnKill += amt;
      break;
    case 'protocolOnBattleStart':
      totals.protocolOnBattleStart += amt;
      break;
    case 'lifesteal':
      totals.lifestealPct += amt;
      break;
    case 'firstAbilityEcho':
      totals.firstAbilityEcho = true;
      break;
    case 'shieldPierce':
      totals.shieldPierce += amt;
      break;
    case 'healShieldBonus':
      break;
    case 'protocolOnKill':
      totals.protocolOnKill += amt;
      break;
    case 'protocolOnKillAny':
      totals.protocolOnKillAny += amt;
      break;
    case 'battleStartShield':
      totals.battleStartShield += amt;
      break;
    case 'battleStartCloak':
      break;
    case 'battleStartCloakRoll':
      totals.battleStartRoll += effect.rollAmount ?? 0;
      break;
    default:
      break;
  }
}

export function buildGearCatalog(raw: { gear: GearEntry[] }): Record<string, GearEntry> {
  const out: Record<string, GearEntry> = {};
  for (const entry of raw.gear ?? []) {
    out[entry.id] = entry;
  }
  return out;
}

export function gearTotalsFromIds(ids: string[], catalog: Record<string, GearEntry>): SimGearTotals {
  const totals = emptyGearTotals();
  for (const id of ids) {
    const entry = catalog[id];
    if (!entry?.effect) continue;
    accumulateGearEffect(totals, entry.effect);
  }
  return totals;
}

export function isBasicEnemyType(enemyType: string): boolean {
  const t = enemyType.toLowerCase();
  return t !== 'boss' && !t.endsWith('boss');
}

/** Apply lifesteal heal after dealing damage. */
export function applyLifesteal(attacker: { hp: number; maxHp: number; gear: SimGearTotals }, damageDealt: number): void {
  if (damageDealt <= 0 || attacker.hp <= 0 || attacker.gear.lifestealPct <= 0) return;
  const heal = Math.floor((damageDealt * attacker.gear.lifestealPct) / 100);
  if (heal <= 0) return;
  attacker.hp = Math.min(attacker.maxHp, attacker.hp + heal);
}

/** First-hit bonus for damaging abilities (once per battle). */
export function consumeFirstAbilityDmgBonus(
  flags: SimGearBattleFlags,
  gear: SimGearTotals,
  hasDamage: boolean,
): number {
  if (!hasDamage || gear.firstAbilityDmgBonus <= 0 || flags.firstAbilityDmgFired) return 0;
  flags.firstAbilityDmgFired = true;
  return gear.firstAbilityDmgBonus;
}
