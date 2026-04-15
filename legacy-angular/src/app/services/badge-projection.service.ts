import { Injectable } from '@angular/core';
import { HeroState } from '../models/hero.interface';
import { EnemyState } from '../models/enemy.interface';
import { HeroAbility } from '../models/ability.interface';
import { HeroId } from '../models/types';
import { GameStateService } from './game-state.service';
import { DiceService } from './dice.service';
import { RelicService } from './relic.service';

export interface HeroBadgeSnapshot {
  incomingDmg: number;
  incomingHeal: number;
  incomingShield: number;
  /** This-turn ally +rfm on roll, minus rust −rfm planned on this hero (per-target). */
  incomingRollNet: number;
  statusShield: number;
  /** Shield duration when shield is active (for badge display). */
  statusShieldT: number;
  statusDot: number;
  statusDotT: number;
  netRollMod: number;
  /** Queued ally +rfm already applied (shows until next squad roll). */
  pendingNextRoll: number;
}

export interface EnemyBadgeSnapshot {
  incomingDmg: number;
  /** Expected self-heal from this enemy’s next lifesteal hit (from `plan` damage × %). */
  incomingLifestealHeal: number;
  incomingRfe: number;
  incomingDot: number;
  /** DoT duration preview for incoming hero-applied DoT (same chip as incomingDot). */
  incomingDotT: number;
  statusShield: number;
  statusShieldT: number;
  statusDot: number;
  statusDotT: number;
  statusRfe: number;
  statusRfT: number;
  /** +d20 for next enemy tray roll (same cadence as hero roll buff). */
  statusErb: number;
  statusErbT: number;
}

@Injectable({ providedIn: 'root' })
export class BadgeProjectionService {
  constructor(
    private state: GameStateService,
    private dice: DiceService,
    private relicService: RelicService,
  ) {}

  /** Incoming line only in player phase, once squad dice are set (not during enemy turn / transition). */
  private showTurnPreviews(): boolean {
    if (!this.state.isPlayerPhase()) return false;
    return this.state.heroes().every(x => x.currentHp <= 0 || x.roll !== null);
  }

  /** Heroes still queued to resolve this END TURN contribute to enemy Incoming; resolved ones do not. */
  private heroContributesToEnemyIncomingPreview(hi: number): boolean {
    const c = this.state.endTurnHeroResolveCursor();
    return c === null || hi >= c;
  }

  heroBadges(heroIndex: number): HeroBadgeSnapshot {
    const h = this.state.heroes()[heroIndex];
    if (!h) {
      return {
        incomingDmg: 0,
        incomingHeal: 0,
        incomingShield: 0,
        incomingRollNet: 0,
        statusShield: 0,
        statusShieldT: 0,
        statusDot: 0,
        statusDotT: 0,
        netRollMod: 0,
        pendingNextRoll: 0,
      };
    }
    const netRollMod =
      (h.rollBuff || 0) +
      (h.relicRollBonus || 0) +
      (h.gearRollBonus || 0) -
      this.state.squadRfmPenalty() -
      this.state.heroRfmPenaltyFor(heroIndex);
    const pre = this.showTurnPreviews();
    // Ally roll buffs queued this turn; minus rust drone plan.rfm on this hero (per-target, like enemy Incoming rfe).
    const incomingRollNet = pre
      ? this.incomingThisTurnRollBuffFromAllies(heroIndex) +
          this.incomingPlannedAllyNextRollBuff(heroIndex) -
          this.incomingRustRfmPlannedOnHero(h.id)
      : 0;
    return {
      incomingDmg: pre ? this.incomingFor(h.id) : 0,
      incomingHeal: pre ? this.incomingHealFor(h.id) : 0,
      incomingShield: pre ? this.incomingShieldFor(h.id) : 0,
      incomingRollNet,
      statusShield: h.shield > 0 && h.shT > 0 ? h.shield : 0,
      statusShieldT: h.shield > 0 && h.shT > 0 ? h.shT : 0,
      statusDot: h.dot > 0 && h.dT > 0 ? h.dot : 0,
      statusDotT: h.dT || 0,
      netRollMod,
      pendingNextRoll: h.pendingRollBuff || 0,
    };
  }

  /** +rfm on this hero’s current die: own abilities only (not ally-targeted; those are next roll). */
  private incomingThisTurnRollBuffFromAllies(heroIdx: number): number {
    const heroes = this.state.heroes();
    if (!heroes[heroIdx] || heroes[heroIdx].currentHp <= 0) return 0;
    let tot = 0;
    for (let i = 0; i < heroes.length; i++) {
      if (i !== heroIdx) continue;
      const h = heroes[i];
      if (h.currentHp <= 0 || h.roll === null) continue;
      const er = this.dice.effRoll(h);
      if (er === null) continue;
      const ab = this.dice.getAbility(h, er);
      if (!ab?.rfm || ab.rfm <= 0 || ab.rfmTgt) continue;
      tot += ab.rfm;
    }
    return tot;
  }

  /** Rust enemies’ queued −rfm on this hero’s next raw roll (EMP Spike, Signal Jam on target, etc.). */
  private incomingRustRfmPlannedOnHero(hid: HeroId): number {
    let t = 0;
    for (const e of this.state.enemies()) {
      if (
        e.dead ||
        (e.type !== 'rust' &&
          e.type !== 'mite' &&
          e.type !== 'beastMonkey' &&
          e.type !== 'veilShard' &&
          e.type !== 'voidWisp' &&
          e.type !== 'signalSkimmer') ||
        !e.plan?.rfm ||
        e.plan.rfm <= 0
      )
        continue;
      if (e.targeting !== hid) continue;
      t += e.plan.rfm;
    }
    return t;
  }

  /** +rfm allies will place on this hero for their *next* roll (preview only if not already queued). */
  private incomingPlannedAllyNextRollBuff(heroIdx: number): number {
    const heroes = this.state.heroes();
    const tgt = heroes[heroIdx];
    if (!tgt || tgt.currentHp <= 0) return 0;
    if ((tgt.pendingRollBuff || 0) > 0) return 0;
    let tot = 0;
    for (let i = 0; i < heroes.length; i++) {
      const h = heroes[i];
      if (h.currentHp <= 0 || h.roll === null) continue;
      const er = this.dice.effRoll(h);
      if (er === null) continue;
      const ab = this.dice.getAbility(h, er);
      if (!ab?.rfm || ab.rfm <= 0) continue;
      if (ab.rfmTgt) {
        if (h.rfmTgtIdx === null || h.rfmTgtIdx !== heroIdx) continue;
      } else if (ab.shTgt && (ab.shield || 0) > 0) {
        if (h.shTgtIdx === null || h.shTgtIdx !== heroIdx) continue;
      } else {
        continue;
      }
      tot += ab.rfm;
    }
    return tot;
  }

  enemyBadges(enemyIndex: number): EnemyBadgeSnapshot {
    const enemies = this.state.enemies();
    const e = enemies[enemyIndex];
    if (!e) {
      return {
        incomingDmg: 0,
        incomingLifestealHeal: 0,
        incomingRfe: 0,
        incomingDot: 0,
        incomingDotT: 0,
        statusShield: 0,
        statusShieldT: 0,
        statusDot: 0,
        statusDotT: 0,
        statusRfe: 0,
        statusRfT: 0,
        statusErb: 0,
        statusErbT: 0,
      };
    }
    if (e.dead || e.currentHp <= 0) {
      return {
        incomingDmg: 0,
        incomingLifestealHeal: 0,
        incomingRfe: 0,
        incomingDot: 0,
        incomingDotT: 0,
        statusShield: 0,
        statusShieldT: 0,
        statusDot: 0,
        statusDotT: 0,
        statusRfe: 0,
        statusRfT: 0,
        statusErb: 0,
        statusErbT: 0,
      };
    }
    const pre = this.showTurnPreviews();
    const dotIn = pre ? this.incomingDotDetailForEnemy(enemyIndex) : { dot: 0, dT: 0 };
    return {
      incomingDmg: pre ? this.projDmgOn(enemyIndex) : 0,
      incomingLifestealHeal: pre ? this.incomingLifestealHealForEnemy(e) : 0,
      incomingRfe: pre ? this.incomingRfeForEnemy(enemyIndex) : 0,
      incomingDot: dotIn.dot,
      incomingDotT: dotIn.dT,
      statusShield: e.shield > 0 && e.shT > 0 ? e.shield : 0,
      statusShieldT: e.shT || 0,
      statusDot: e.dot > 0 && e.dT > 0 ? e.dot : 0,
      statusDotT: e.dT || 0,
      statusRfe: e.rfe > 0 && e.rfT > 0 ? e.rfe : 0,
      statusRfT: e.rfT || 0,
      statusErb: (e.rollBuff || 0) > 0 && (e.rollBuffT || 0) > 0 ? e.rollBuff : 0,
      statusErbT: e.rollBuffT || 0,
    };
  }

  /**
   * Same scaling as {@link CombatService} resolve path: relic damage mult, then RAMPAGE ×2 with
   * one charge consumed per ability that has base damage greater than 0 (split-alloc hits still use raw
   * allocated damage, but the charge is burned like combat).
   */
  /**
   * Locked enemy if valid, else first living enemy — matches combat fallback when resolving
   * single-target hits so incoming damage (including rampage ×2) previews on the correct card.
   */
  private previewHeroEnemyTargetIdx(h: HeroState, ab: HeroAbility): number | null {
    const enemies = this.state.enemies();
    if (ab.blastAll || ab.multiHit) return null;
    const locked = h.lockedTarget !== undefined && h.lockedTarget !== null ? h.lockedTarget : null;
    if (locked !== null) {
      const ex = enemies[locked];
      if (ex && !ex.dead) return locked;
    }
    const first = enemies.findIndex(x => !x.dead);
    return first >= 0 ? first : null;
  }

  private heroStrikeEffectiveForPreview(hi: number, baseDmg: number, rampRem: number[]): number {
    if (baseDmg <= 0) return 0;
    let d = baseDmg;
    const mult = this.relicService.getHeroDmgMult();
    if (mult !== 1) d = Math.ceil(d * mult);
    if (rampRem[hi] > 0) {
      d *= 2;
      rampRem[hi]--;
    }
    return d;
  }

  /**
   * Net HP damage this enemy will take from hero abilities this turn, in hero resolution order,
   * with shield depletion and pierce matching {@link CombatService} (endTurn player loop).
   */
  projDmgOn(ei: number): number {
    const enemies = this.state.enemies();
    const e = enemies[ei];
    if (!e || e.dead || e.currentHp <= 0) return 0;

    let shieldRem = e.shield > 0 && e.shT > 0 ? e.shield : 0;
    let hpDmg = 0;

    const applyToEnemy = (dmg: number, ignSh: boolean): void => {
      if (dmg <= 0) return;
      if (ignSh) {
        hpDmg += dmg;
        return;
      }
      const absorbed = Math.min(shieldRem, dmg);
      shieldRem -= absorbed;
      hpDmg += dmg - absorbed;
    };

    const heroes = this.state.heroes();
    const rampRem = heroes.map(h => h.rampageCharges || 0);

    for (let hi = 0; hi < heroes.length; hi++) {
      if (!this.heroContributesToEnemyIncomingPreview(hi)) continue;
      const h = heroes[hi];
      if (h.currentHp <= 0 || h.roll === null) continue;
      const er = this.dice.effRoll(h);
      if (er === null) continue;
      const ab = this.dice.getAbility(h, er);
      const baseDmg = ab?.dmg || 0;
      if (!ab || !baseDmg) continue;

      const ignSh = !!ab.ignSh;
      const hTgt = this.previewHeroEnemyTargetIdx(h, ab);

      const effective = this.heroStrikeEffectiveForPreview(hi, baseDmg, rampRem);

      if (ab.splitDmg) {
        const alloc = h.splitAlloc || {};
        const entries = Object.entries(alloc).filter(([, v]) => v > 0);
        let d = 0;
        if (entries.length) {
          d = alloc[e.id] ?? 0;
        } else if (hTgt != null && hTgt === ei) {
          const tgtE = enemies[hTgt];
          if (tgtE && !tgtE.dead) d = effective;
        }
        applyToEnemy(d, ignSh);
        continue;
      }

      if (ab.blastAll || ab.multiHit) {
        applyToEnemy(effective, ignSh);
        continue;
      }

      if (hTgt !== ei) continue;
      applyToEnemy(effective, ignSh);
    }

    return hpDmg;
  }

  /**
   * Net HP damage from enemy attacks this turn (next enemy phase), in enemy index order,
   * with hero shield depletion. Cloak ignored (expected damage).
   */
  incomingFor(hid: HeroId): number {
    const heroes = this.state.heroes();
    const h = heroes.find(x => x.id === hid);
    if (!h || h.currentHp <= 0) return 0;

    let shieldRem = h.shield > 0 && h.shT > 0 ? h.shield : 0;
    let hpDmg = 0;

    for (const e of this.state.enemies()) {
      if (e.dead || !e.plan || e.targeting !== hid) continue;
      const dmgAmt = this.enemyAttackDamagePreview(e);
      if (dmgAmt <= 0) continue;

      const absorbed = Math.min(shieldRem, dmgAmt);
      shieldRem -= absorbed;
      hpDmg += dmgAmt - absorbed;
    }

    return hpDmg;
  }

  /**
   * Direct hit damage from `plan` only. Do not fall back to unit `dMin`/`dMax` — those describe
   * something else and falsely inflate “incoming” for shield/buff-only abilities (e.g. Iron Grazing).
   */
  private enemyAttackDamagePreview(e: EnemyState): number {
    if (!e.plan) return 0;
    if (e.plan.dmg != null && e.plan.dmg > 0) return e.plan.dmg;
    return 0;
  }

  /** Lifesteal preview: HP this enemy expects to regain from their queued direct hit. */
  private incomingLifestealHealForEnemy(e: EnemyState): number {
    const p = e.plan;
    if (!p || !p.lifestealPct || p.lifestealPct <= 0) return 0;
    const dmg = this.enemyAttackDamagePreview(e);
    if (dmg <= 0) return 0;
    return Math.max(1, Math.round((dmg * p.lifestealPct) / 100));
  }

  incomingHealFor(hid: HeroId): number {
    const heroes = this.state.heroes();
    const recv = heroes.find(x => x.id === hid);
    if (!recv || recv.currentHp <= 0) return 0;
    let tot = 0;

    for (const h of heroes) {
      if (h.currentHp <= 0 || h.roll === null) continue;
      const er = this.dice.effRoll(h);
      if (er === null) continue;
      const ab = this.dice.getAbility(h, er);
      if (!ab || !ab.heal) continue;

      if (ab.healAll) {
        tot += ab.heal;
        continue;
      }
      if (ab.healLowest) {
        const alive = heroes.filter(x => x.currentHp > 0);
        if (!alive.length) continue;
        const lowest = alive.reduce((a, b) => (a.currentHp < b.currentHp ? a : b));
        if (lowest.id === hid) tot += ab.heal;
        continue;
      }
      if (ab.healTgt) {
        if (h.healTgtIdx == null) continue;
        const healTarget = heroes[h.healTgtIdx];
        if (healTarget?.currentHp > 0 && healTarget.id === hid) tot += ab.heal;
        continue;
      }
      if (h.id === hid) tot += ab.heal;
    }
    return tot;
  }

  incomingShieldFor(hid: HeroId): number {
    const heroes = this.state.heroes();
    const recv = heroes.find(x => x.id === hid);
    if (!recv || recv.currentHp <= 0) return 0;
    let tot = 0;

    for (const h of heroes) {
      if (h.currentHp <= 0 || h.roll === null) continue;
      const er = this.dice.effRoll(h);
      if (er === null) continue;
      const ab = this.dice.getAbility(h, er);
      if (!ab || !ab.shield) continue;

      if (ab.shieldAll) {
        tot += ab.shield;
        continue;
      }
      if (ab.shTgt) {
        if (h.shTgtIdx === null) continue;
        const tgt = heroes[h.shTgtIdx];
        if (tgt && tgt.currentHp > 0 && tgt.id === hid) tot += ab.shield;
        continue;
      }
      if (h.id === hid) tot += ab.shield;
    }
    return tot;
  }

  incomingRfeForEnemy(ei: number): number {
    const tgt = this.state.enemies()[ei];
    if (!tgt || tgt.dead || tgt.currentHp <= 0) return 0;
    let t = 0;
    const heroes = this.state.heroes();
    for (let hi = 0; hi < heroes.length; hi++) {
      if (!this.heroContributesToEnemyIncomingPreview(hi)) continue;
      const h = heroes[hi];
      if (h.currentHp <= 0 || h.roll === null) continue;
      const er = this.dice.effRoll(h);
      if (er === null) continue;
      const ab = this.dice.getAbility(h, er);
      if (!ab?.rfe) continue;
      if (ab.rfeAll) {
        t += ab.rfe;
        continue;
      }
      const hTgt = h.lockedTarget !== undefined && h.lockedTarget !== null ? h.lockedTarget : null;
      if (hTgt === ei) t += ab.rfe;
    }
    return t;
  }

  incomingDotDetailForEnemy(ei: number): { dot: number; dT: number } {
    const tgt = this.state.enemies()[ei];
    if (!tgt || tgt.dead || tgt.currentHp <= 0) return { dot: 0, dT: 0 };
    let dot = 0;
    let dt = 0;
    const heroes = this.state.heroes();
    for (let hi = 0; hi < heroes.length; hi++) {
      if (!this.heroContributesToEnemyIncomingPreview(hi)) continue;
      const h = heroes[hi];
      if (h.currentHp <= 0 || h.roll === null) continue;
      const er = this.dice.effRoll(h);
      if (er === null) continue;
      const ab = this.dice.getAbility(h, er);
      if (!ab?.dot) continue;
      if (ab.blastAll) {
        dot += ab.dot;
        dt = Math.max(dt, ab.dT || 0);
        continue;
      }
      const hTgt = h.lockedTarget !== undefined && h.lockedTarget !== null ? h.lockedTarget : null;
      if (hTgt !== ei) continue;
      dot += ab.dot;
      dt = Math.max(dt, ab.dT || 0);
    }
    return { dot, dT: dt };
  }
}
