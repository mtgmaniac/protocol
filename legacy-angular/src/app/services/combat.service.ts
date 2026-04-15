import { Injectable, signal } from '@angular/core';
import { EnemyAbility } from '../models/ability.interface';
import {
  type EnemyDefinition,
  EnemyState,
  createEnemyState,
  enemyRfeFromStacks,
  tickEnemyRfeStacks,
} from '../models/enemy.interface';
import { HeroState } from '../models/hero.interface';
import { Zone } from '../models/types';
import {
  battleModeConfig,
  battleCountForMode,
  battlesForMode,
  DEFAULT_SUMMON_GRUNTS,
} from '../data/battle-modes.data';
import { GameStateService } from './game-state.service';
import { EnemyContentService } from './enemy-content.service';
import { DiceService } from './dice.service';
import { TargetingService } from './targeting.service';
import { AnimationService, STEP_MS, SUBFLASH_MS } from './animation.service';
import { LogService } from './log.service';
import { ProtocolService } from './protocol.service';
import { EvolutionService } from './evolution.service';
import { TutorialService } from './tutorial.service';
import { ItemService } from './item.service';
import { PortraitPreloadService } from './portrait-preload.service';
import { RelicService } from './relic.service';
import { SoundService } from './sound.service';
import { GearService } from './gear.service';
import {
  addShieldToUnit,
  absorbDamageThroughShield,
  coalesceShieldStacks,
  tickUnitShield,
} from '../utils/shield-stack.util';
/** Precomputed squad + enemy tray rolls (shared by dice animation and instant sim). */
export interface ComputedRollAllPayload {
  heroRolls: {
    heroIdx: number;
    finalRoll: number;
    /** Raw d20 pair before RFM when this roll resolved cursed dice (tray dual animation). */
    cursedPair?: { low: number; high: number; r1: number; r2: number };
  }[];
  enemyRolls: { enemyIdx: number; preRoll: number; displayEff: number }[];
}

export type RollAllAnimatedDelegate = { applyAnimated: () => Promise<void> };

@Injectable({ providedIn: 'root' })
export class CombatService {
  constructor(
    private state: GameStateService,
    private dice: DiceService,
    private targeting: TargetingService,
    private anim: AnimationService,
    private log: LogService,
    private protocol: ProtocolService,
    private evolution: EvolutionService,
    private tutorial: TutorialService,
    private enemyContent: EnemyContentService,
    private items: ItemService,
    private portraitPreload: PortraitPreloadService,
    private relicService: RelicService,
    private sound: SoundService,
    private gearService: GearService,
  ) {}

  /** Guard: prevents Chain Reaction from cascading recursively within one checkDead call. */
  private chainReactionInProgress = false;

  /** Sim Battle / animated roll-all: dice tray registers `applyAnimated` when present. */
  private rollAllDelegate: RollAllAnimatedDelegate | null = null;

  readonly simBattleRunning = signal(false);

  setRollAllDelegate(delegate: RollAllAnimatedDelegate | null): void {
    this.rollAllDelegate = delegate;
  }

  // ── Enemy ability resolution ──

  getEnemyAbility(e: EnemyState, zone: Zone): EnemyAbility {
    const suite = this.enemyContent.suiteFor(e.type);
    const base = suite[zone];
    if (!base) return { name: '?', eff: '—', dmg: 0, dot: 0, dT: 0, heal: 0, rfe: 0, shield: 0 };
    const ab: EnemyAbility = { ...base };
    const scale = e.dmgScale || 1;
    if (ab.dmg > 0) ab.dmg = Math.round(ab.dmg * scale);
    if (ab.dmgP2 && ab.dmgP2 > 0) ab.dmgP2 = Math.round(ab.dmgP2 * scale);
    if (ab.dot > 0) ab.dot = Math.round(ab.dot * scale);
    if (ab.heal > 0) ab.heal = Math.round(ab.heal * scale);
    if (ab.shield > 0) ab.shield = Math.round(ab.shield * scale);
    if (ab.rfm && ab.rfm > 0) ab.rfm = Math.round(ab.rfm * scale);
    if ((ab.shieldAlly || 0) > 0) ab.shieldAlly = Math.round((ab.shieldAlly || 0) * scale);
    // Phase 2 boss damage override
    if (e.p2 && ab.dmgP2) ab.dmg = ab.dmgP2;
    return ab;
  }

  /** Hero abilities must not apply incoming damage/debuffs to corpses (HP 0 or flagged dead). */
  private enemyAcceptsHeroEffects(e: EnemyState): boolean {
    return !e.dead && e.currentHp > 0;
  }

  /** Commit a raw d20 for one enemy (after debuff); updates zone + plan. */
  applyEnemyAbilityRoll(idx: number, preRoll: number): void {
    const e = this.state.enemies()[idx];
    if (!e || e.dead) return;
    const effR = Math.min(20, Math.max(1, preRoll - (e.rfe || 0) + (e.rollBuff || 0)));
    const zone = this.dice.getEnemyZone(effR);
    const plan = this.getEnemyAbility(e, zone);
    plan.zone = zone;
    this.state.updateEnemy(idx, {
      preRoll,
      effRoll: effR,
      curZone: zone,
      plan,
    });
  }

  rollEnemyAbility(idx: number): void {
    this.applyEnemyAbilityRoll(idx, this.dice.d20());
  }

  /** Clear queued enemy abilities until the squad roll reveals them. */
  clearEnemyPlansForNextPlayerRound(): void {
    this.state.enemies().forEach((e, i) => {
      if (e.dead) return;
      if ((e.dieFreezeRollsRemaining || 0) > 0) return;
      this.state.updateEnemy(i, {
        preRoll: 0,
        effRoll: 0,
        curZone: 'recharge',
        plan: null,
      });
    });
  }

  /** Roll fresh enemy plans when all squad dice are set (individual clicks, no tray anim). */
  rollFreshEnemyPlansForReveal(): void {
    const enemies = this.state.enemies();
    for (let i = 0; i < enemies.length; i++) {
      const e = enemies[i];
      if (e.dead) continue;
      if ((e.dieFreezeRollsRemaining || 0) > 0) {
        const next = e.dieFreezeRollsRemaining - 1;
        this.state.updateEnemy(i, { dieFreezeRollsRemaining: next });
        continue;
      }
      this.applyEnemyAbilityRoll(i, this.dice.d20());
    }
    this.targeting.assignTargets();
  }

  /** Apply precomputed d20s from the tray animation, then refresh targeting. */
  applyEnemyAbilityRollsFromPreRolls(pairs: { enemyIndex: number; preRoll: number }[]): void {
    for (const { enemyIndex, preRoll } of pairs) {
      this.applyEnemyAbilityRoll(enemyIndex, preRoll);
    }
    this.targeting.assignTargets();
  }

  recomputeEnemy(idx: number): void {
    const e = this.state.enemies()[idx];
    if ((e.preRoll || 0) <= 0) return;
    const effR = Math.min(20, Math.max(1, e.preRoll - (e.rfe || 0) + (e.rollBuff || 0)));
    const zone = this.dice.getEnemyZone(effR);
    const plan = this.getEnemyAbility(e, zone);
    plan.zone = zone;
    this.state.updateEnemy(idx, { effRoll: effR, curZone: zone, plan });
    this.targeting.assignTargets();
  }

  private async pulseHeroPortrait(i: number, cls: string): Promise<void> {
    this.sound.playPortraitFlash(cls);
    const el = this.anim.heroPortraitEl(i);
    if (!el || !this.state.animOn()) return;
    await this.anim.pfPulse(el, cls, SUBFLASH_MS);
    await this.anim.paceBetweenSteps();
  }

  private async pulseEnemyPortrait(i: number, cls: string): Promise<void> {
    this.sound.playPortraitFlash(cls);
    const el = this.anim.enemyPortraitEl(i);
    if (!el || !this.state.animOn()) return;
    await this.anim.pfPulse(el, cls, SUBFLASH_MS);
    await this.anim.paceBetweenSteps();
  }

  /** One hero’s END TURN resolution with staggered highlights (caster → targets, left → right). */
  private async resolveHeroEndTurnWithActionPacing(hi: number): Promise<void> {
    const h = this.state.heroes()[hi];
    if (h.currentHp <= 0) return;
    if ((h.cowerTurns || 0) > 0) {
      await this.anim.gapBetweenActors();
      this.log.log(`▸ ${h.name} is paralyzed by fear — no action.`, 'bl');
      return;
    }
    const er = this.dice.effRoll(h);
    if (er === null) return;
    const ab = this.dice.getAbility(h, er);
    if (!ab) return;

    await this.anim.gapBetweenActors();
    await this.anim.pfShake(this.anim.heroPortraitEl(hi));

    const enemies = this.state.enemies();
    const tgtIdx = h.lockedTarget !== undefined && h.lockedTarget !== null ? h.lockedTarget : 0;
    const tgtE = enemies[tgtIdx];

    if (ab.revive) {
      const dead = this.state.heroes().map((x, idx) => ({ x, idx })).filter(z => z.x.currentHp <= 0);
      const ti = h.reviveTgtIdx != null ? h.reviveTgtIdx : (dead[0]?.idx ?? null);
      if (ti != null) {
        const tgt = this.state.heroes()[ti];
        if (tgt && tgt.currentHp <= 0) {
          await this.pulseHeroPortrait(ti, 'pf-flash-green');
          const revHp = Math.max(1, Math.round(tgt.maxHp * 0.5));
          this.state.updateHero(ti, {
            currentHp: revHp,
            dot: 0,
            dT: 0,
            shield: 0,
            shT: 0,
            shieldStacks: [],
            roll: null,
            rawRoll: null,
            confirmed: false,
            lockedTarget: undefined,
            healTgtIdx: null,
            shTgtIdx: null,
            rfmTgtIdx: null,
            reviveTgtIdx: null,
            splitAlloc: {},
            cowerTurns: 0,
          });
          this.targeting.clearHeroTargetingOnRollChange(ti);
          this.log.log(`▸ ${h.name} → ${ab.name}. Revived ${tgt.name} at ${revHp}/${tgt.maxHp} HP.`, 'pl');
        }
      }
    }

    if (ab.shieldAll && (ab.shield || 0) > 0) {
      const n = this.state.heroes().length;
      for (let idx = 0; idx < n; idx++) {
        const x = this.state.heroes()[idx];
        // All-allies shield: living heroes only (no corpses).
        if (x.currentHp <= 0) continue;
        await this.pulseHeroPortrait(idx, 'pf-flash-blue');
        this.state.updateHero(idx, addShieldToUnit(x, ab.shield || 0, ab.shT || 2));
      }
      this.log.log(`▸ ${h.name} → ${ab.name}. +${ab.shield} shield (all allies).`, 'pl');
    }

    if (ab.healAll && (ab.heal || 0) > 0) {
      const n = this.state.heroes().length;
      for (let idx = 0; idx < n; idx++) {
        const x = this.state.heroes()[idx];
        // Party heal: living allies only; skip dead and full HP.
        if (x.currentHp <= 0 || x.currentHp >= x.maxHp) continue;
        await this.pulseHeroPortrait(idx, 'pf-flash-green');
        this.state.updateHero(idx, { currentHp: Math.min(x.maxHp, x.currentHp + ab.heal) });
      }
      this.log.log(`▸ ${h.name} → ${ab.name}. +${ab.heal} HP (all allies).`, 'pl');
    }

    if (ab.shTgt && (ab.shield || 0) > 0 && h.shTgtIdx != null) {
      const si = h.shTgtIdx;
      const sH = this.state.heroes()[si];
      if (sH && sH.currentHp > 0) {
        await this.pulseHeroPortrait(si, 'pf-flash-blue');
        this.state.updateHero(si, addShieldToUnit(sH, ab.shield || 0, ab.shT || 2));
        this.log.log(`▸ ${h.name} → ${ab.name} on ${sH.name} (+${ab.shield} shield).`, 'pl');
      }
    }

    if ((ab.shield || 0) > 0 && !ab.shieldAll && !ab.shTgt) {
      await this.pulseHeroPortrait(hi, 'pf-flash-blue');
      const hs = this.state.heroes()[hi];
      this.state.updateHero(hi, addShieldToUnit(hs, ab.shield || 0, ab.shT || 2));
      this.log.log(`▸ ${h.name} → ${ab.name}. +${ab.shield} shield (self).`, 'pl');
    }

    if (ab.healLowest && (ab.heal || 0) > 0) {
      const alive = this.state.heroes().map((x, idx) => ({ x, idx })).filter(z => z.x.currentHp > 0);
      const best = alive.reduce((a, b) => (a.x.currentHp / a.x.maxHp) <= (b.x.currentHp / b.x.maxHp) ? a : b, alive[0]);
      if (best && best.x.currentHp < best.x.maxHp) {
        await this.pulseHeroPortrait(best.idx, 'pf-flash-green');
        this.state.updateHero(best.idx, { currentHp: Math.min(best.x.maxHp, best.x.currentHp + ab.heal) });
        this.log.log(`▸ ${h.name} → ${ab.name}. +${ab.heal} HP on ${best.x.name}.`, 'pl');
      }
    }

    if (ab.healTgt && (ab.heal || 0) > 0 && h.healTgtIdx != null) {
      const ti = h.healTgtIdx;
      const heroes = this.state.heroes();
      if (ti >= 0 && ti < heroes.length) {
        const tgt = heroes[ti];
        if (tgt && tgt.currentHp > 0 && tgt.currentHp < tgt.maxHp) {
          await this.pulseHeroPortrait(ti, 'pf-flash-green');
          this.state.updateHero(ti, { currentHp: Math.min(tgt.maxHp, tgt.currentHp + ab.heal) });
          this.log.log(`▸ ${h.name} → ${ab.name}. +${ab.heal} HP on ${tgt.name}.`, 'pl');
        }
      }
    }

    if (
      (ab.heal || 0) > 0 &&
      !ab.healTgt &&
      !ab.healLowest &&
      !ab.healAll &&
      !ab.shTgt &&
      (ab.dmg || 0) > 0
    ) {
      if (h.currentHp < h.maxHp) {
        await this.pulseHeroPortrait(hi, 'pf-flash-green');
        this.state.updateHero(hi, { currentHp: Math.min(h.maxHp, h.currentHp + ab.heal) });
        this.log.log(`▸ ${h.name} → ${ab.name}. +${ab.heal} HP (self).`, 'pl');
      }
    }

    if (
      (ab.heal || 0) > 0 &&
      !ab.healTgt &&
      !ab.healLowest &&
      !ab.healAll &&
      !ab.shTgt &&
      !(ab.dmg || 0)
    ) {
      if (h.currentHp < h.maxHp) {
        await this.pulseHeroPortrait(hi, 'pf-flash-green');
        this.state.updateHero(hi, { currentHp: Math.min(h.maxHp, h.currentHp + ab.heal) });
        this.log.log(`▸ ${h.name} → ${ab.name}. +${ab.heal} HP.`, 'pl');
      }
    }

    // Compute effective ability damage: Overcharge relic (×1.3 ceil) + hero RAMPAGE (×2, consumes 1 charge).
    let effectiveDmg = ab.dmg || 0;
    if (effectiveDmg > 0) {
      const heroDmgMult = this.relicService.getHeroDmgMult();
      if (heroDmgMult !== 1) effectiveDmg = Math.ceil(effectiveDmg * heroDmgMult);
      const hxRamp = this.state.heroes()[hi];
      if ((hxRamp.rampageCharges || 0) > 0) {
        effectiveDmg *= 2;
        this.state.updateHero(hi, { rampageCharges: hxRamp.rampageCharges - 1 });
        this.log.log(`▸ ${h.name} — RAMPAGE (×2).`, 'pl');
      }
    }

    // Gear: Exile Blade Core — +N dmg on first damaging ability this battle
    if (effectiveDmg > 0) {
      const firstBonus = this.gearService.getFirstAbilityDmgBonus(hi);
      const hxF = this.state.heroes()[hi];
      if (firstBonus > 0 && !hxF.firstAbilityFired) {
        effectiveDmg += firstBonus;
        this.state.updateHero(hi, { firstAbilityFired: true });
        this.log.log(`▸ ${h.name} — Overclock! +${firstBonus} dmg.`, 'pl');
      }
    }

    if ((ab.blastAll || ab.multiHit) && effectiveDmg > 0) {
      for (let idx = 0; idx < this.state.enemies().length; idx++) {
        const e = this.state.enemies()[idx];
        if (!this.enemyAcceptsHeroEffects(e)) continue;
        await this.pulseEnemyPortrait(idx, 'pf-flash-red');
        this.applyDamageToEnemy(idx, effectiveDmg, h.name, !!(ab.ignSh), hi);
      }
    } else if (ab.splitDmg) {
      const alloc = h.splitAlloc || {};
      let entries = Object.entries(alloc)
        .filter(([, v]) => v > 0)
        .map(([k, v]) => ({ ei: parseInt(k, 10), dmg: v }))
        .filter(x => {
          const ex = this.state.enemies()[x.ei];
          return ex && this.enemyAcceptsHeroEffects(ex);
        });
      entries.sort((a, b) => a.ei - b.ei);
      if (entries.length) {
        for (const x of entries) {
          if (x.dmg > 0) {
            await this.pulseEnemyPortrait(x.ei, 'pf-flash-red');
            this.applyDamageToEnemy(x.ei, x.dmg, h.name, !!(ab.ignSh), hi);
            this.log.log(`▸ ${h.name} splits ${x.dmg} dmg → ${this.state.enemies()[x.ei].name}.`, 'pl');
          }
        }
      } else if (tgtE && this.enemyAcceptsHeroEffects(tgtE) && effectiveDmg > 0) {
        await this.pulseEnemyPortrait(tgtIdx, 'pf-flash-red');
        this.applyDamageToEnemy(tgtIdx, effectiveDmg, h.name, !!(ab.ignSh), hi);
      }
    } else if (effectiveDmg > 0 && tgtE && this.enemyAcceptsHeroEffects(tgtE)) {
      await this.pulseEnemyPortrait(tgtIdx, 'pf-flash-red');
      this.applyDamageToEnemy(tgtIdx, effectiveDmg, h.name, !!(ab.ignSh), hi);
    }

    if (ab.rfm && ab.rfm > 0) {
      if (ab.rfmTgt) {
        const ti = h.rfmTgtIdx;
        const heroes = this.state.heroes();
        if (ti != null && ti >= 0 && ti < heroes.length) {
          const tgt = heroes[ti];
          if (tgt && tgt.currentHp > 0) {
            await this.pulseHeroPortrait(ti, 'pf-flash-green');
            this.state.updateHero(ti, {
              pendingRollBuff: (tgt.pendingRollBuff || 0) + ab.rfm,
              pendingRollBuffT: Math.max(tgt.pendingRollBuffT || 0, ab.rfmT || 1),
            });
            const rbt = ab.rfmT || 1;
            this.log.log(
              `▸ ${h.name} → ${ab.name}. +${ab.rfm} roll on ${tgt.name}'s next roll${rbt > 1 ? ` (${rbt}t)` : ''}.`,
              'pl',
            );
          }
        }
      } else if (ab.shTgt && (ab.shield || 0) > 0 && h.shTgtIdx != null) {
        const ti = h.shTgtIdx;
        const heroes = this.state.heroes();
        if (ti >= 0 && ti < heroes.length) {
          const tgt = heroes[ti];
          if (tgt && tgt.currentHp > 0) {
            await this.pulseHeroPortrait(ti, 'pf-flash-green');
            this.state.updateHero(ti, {
              pendingRollBuff: (tgt.pendingRollBuff || 0) + ab.rfm,
              pendingRollBuffT: Math.max(tgt.pendingRollBuffT || 0, ab.rfmT || 1),
            });
            const rbt = ab.rfmT || 1;
            this.log.log(
              `▸ ${h.name} → ${ab.name}. +${ab.rfm} roll on ${tgt.name}'s next roll${rbt > 1 ? ` (${rbt}t)` : ''} (shield target).`,
              'pl',
            );
          }
        }
      } else {
        await this.pulseHeroPortrait(hi, 'pf-flash-green');
        const hx = this.state.heroes()[hi];
        this.state.updateHero(hi, {
          rollBuff: (hx.rollBuff || 0) + ab.rfm,
          rollBuffT: Math.max(hx.rollBuffT || 0, ab.rfmT || 1),
        });
        const rbt = ab.rfmT || 1;
        this.log.log(
          `▸ ${h.name} → ${ab.name}. +${ab.rfm} roll${rbt > 1 ? ` (${rbt}t)` : ' next roll'}.`,
          'pl',
        );
      }
    }

    if (ab.cloak) {
      this.state.updateHero(hi, { cloaked: true });
      this.log.log(`▸ ${h.name} is cloaked.`, 'pl');
    }
    if ((ab.grantRampage || 0) > 0) {
      const hxr = this.state.heroes()[hi];
      const newCharges = (hxr.rampageCharges || 0) + (ab.grantRampage as number);
      this.state.updateHero(hi, { rampageCharges: newCharges });
      this.log.log(`▸ ${h.name} — blood up (+${ab.grantRampage} rampage).`, 'pl');
    }
    if (ab.taunt) {
      const ei = h.lockedTarget;
      if (ei !== undefined && ei !== null) {
        const ex = this.state.enemies()[ei];
        this.state.tauntHeroId.set(h.id);
        this.state.tauntEnemyIdx.set(ei);
        this.targeting.assignTargets();
        this.log.log(
          `▸ ${h.name} taunts ${ex?.name ?? 'enemy'} — must target ${h.name}.`,
          'pl',
        );
      }
    }

    if (ab.dot > 0) {
      if (ab.blastAll) {
        for (let idx = 0; idx < this.state.enemies().length; idx++) {
          const e = this.state.enemies()[idx];
          if (!this.enemyAcceptsHeroEffects(e)) continue;
          await this.pulseEnemyPortrait(idx, 'pf-flash-red');
          this.state.updateEnemy(idx, {
            dot: (e.dot || 0) + ab.dot,
            dT: Math.max(e.dT || 0, ab.dT || 0),
          });
        }
        this.log.log(
          `▸ Enemies poisoned (${ab.dot} DoT${ab.dT && ab.dT > 1 ? `, ${ab.dT}t` : ''}).`,
          'pl',
        );
      } else if (tgtE && this.enemyAcceptsHeroEffects(tgtE)) {
        await this.pulseEnemyPortrait(tgtIdx, 'pf-flash-red');
        this.state.updateEnemy(tgtIdx, {
          dot: (tgtE.dot || 0) + ab.dot,
          dT: Math.max(tgtE.dT || 0, ab.dT || 0),
        });
        this.log.log(
          `▸ ${tgtE.name} poisoned (${ab.dot} DoT${ab.dT && ab.dT > 1 ? `, ${ab.dT}t` : ''}).`,
          'pl',
        );
      }
    }

    if (ab.rfe > 0) {
      const dur = Math.max(1, ab.rfT || 1);
      if (ab.rfeAll) {
        for (let idx = 0; idx < this.state.enemies().length; idx++) {
          const e = this.state.enemies()[idx];
          if (!this.enemyAcceptsHeroEffects(e)) continue;
          await this.pulseEnemyPortrait(idx, 'pf-flash-amber');
          const nextStacks = [...(e.rfeStacks || []), { amt: ab.rfe, turnsLeft: dur }];
          const { rfe, rfT } = enemyRfeFromStacks(nextStacks);
          this.state.updateEnemy(idx, { rfeStacks: nextStacks, rfe, rfT });
          this.recomputeEnemy(idx);
        }
      } else if (tgtE && this.enemyAcceptsHeroEffects(tgtE)) {
        await this.pulseEnemyPortrait(tgtIdx, 'pf-flash-amber');
        const nextStacks = [...(tgtE.rfeStacks || []), { amt: ab.rfe, turnsLeft: dur }];
        const { rfe, rfT } = enemyRfeFromStacks(nextStacks);
        this.state.updateEnemy(tgtIdx, { rfeStacks: nextStacks, rfe, rfT });
        this.recomputeEnemy(tgtIdx);
      }
    }

    const freezeAll = ab.freezeAllEnemyDice || 0;
    if (freezeAll > 0) {
      const ens = this.state.enemies();
      for (let idx = 0; idx < ens.length; idx++) {
        const ex = ens[idx];
        if (ex.dead || !this.enemyAcceptsHeroEffects(ex)) continue;
        await this.pulseEnemyPortrait(idx, 'pf-flash-blue');
        const n = (ex.dieFreezeRollsRemaining || 0) + freezeAll;
        this.state.updateEnemy(idx, { dieFreezeRollsRemaining: n });
      }
      this.log.log(
        `▸ ${h.name} → ${ab.name}. Enemy dice frozen (${freezeAll} skip${freezeAll > 1 ? 's' : ''} on reveal).`,
        'pl',
      );
    }
    const freezeTgtSkips = ab.freezeEnemyDice || 0;
    if (freezeTgtSkips > 0) {
      const ex = this.state.enemies()[tgtIdx];
      if (ex && !ex.dead && this.enemyAcceptsHeroEffects(ex)) {
        await this.pulseEnemyPortrait(tgtIdx, 'pf-flash-blue');
        const n = (ex.dieFreezeRollsRemaining || 0) + freezeTgtSkips;
        this.state.updateEnemy(tgtIdx, { dieFreezeRollsRemaining: n });
        this.log.log(
          `▸ ${h.name} → ${ab.name}. ${ex.name}'s dice frozen (${freezeTgtSkips} reveal skip${freezeTgtSkips > 1 ? 's' : ''}).`,
          'pl',
        );
      }
    }

    const freezeAny = ab.freezeAnyDice || 0;
    if (freezeAny > 0) {
      const heroes = this.state.heroes();
      if (h.freezeDiceTgtHeroIdx != null) {
        const ti = h.freezeDiceTgtHeroIdx;
        if (ti >= 0 && ti < heroes.length) {
          const tgt = heroes[ti];
          if (tgt && tgt.currentHp > 0) {
            await this.pulseHeroPortrait(ti, 'pf-flash-blue');
            const n = (tgt.dieFreezeRollsRemaining || 0) + freezeAny;
            this.state.updateHero(ti, { dieFreezeRollsRemaining: n });
            this.log.log(
              `▸ ${h.name} → ${ab.name}. ${tgt.name}'s die frozen (${freezeAny} reveal skip${freezeAny > 1 ? 's' : ''}).`,
              'pl',
            );
          }
        }
      } else if (h.freezeDiceTgtEnemyIdx != null) {
        const ei = h.freezeDiceTgtEnemyIdx;
        const ex = this.state.enemies()[ei];
        if (ex && !ex.dead && this.enemyAcceptsHeroEffects(ex)) {
          await this.pulseEnemyPortrait(ei, 'pf-flash-blue');
          const n = (ex.dieFreezeRollsRemaining || 0) + freezeAny;
          this.state.updateEnemy(ei, { dieFreezeRollsRemaining: n });
          this.log.log(
            `▸ ${h.name} → ${ab.name}. ${ex.name}'s die frozen (${freezeAny} reveal skip${freezeAny > 1 ? 's' : ''}).`,
            'pl',
          );
        }
      }
    }
  }

  private pickSummonGruntName(act: EnemyAbility): string {
    const n = act.summonName?.trim();
    if (n) return n;
    const pool = DEFAULT_SUMMON_GRUNTS[this.state.battleModeId()] ?? DEFAULT_SUMMON_GRUNTS.facility;
    return pool[Math.floor(Math.random() * pool.length)]!;
  }

  /** Veil Concord (summonElite) overload only: natural 20 + overload tier + explicit summonChance. */
  private async maybeEliteNaturalTwentySummon(ei: number, e: EnemyState, act: EnemyAbility): Promise<void> {
    if (e.ai !== 'smart' || e.summonElite !== true) return;
    if (e.preRoll !== 20 || e.curZone !== 'overload') return;
    const living = this.state.enemies().filter(x => !x.dead).length;
    if (living >= 3) return;
    const pct = act.summonChance;
    if (pct == null || pct <= 0) return;
    if (Math.random() * 100 >= pct) return;

    let unitName: string;
    try {
      unitName = this.pickSummonGruntName(act);
    } catch {
      return;
    }

    let rawDef;
    try {
      rawDef = this.enemyContent.expandFromSpawn({ name: unitName });
    } catch {
      this.log.log(`▸ Summon failed: unknown unit "${unitName}".`, 'sy');
      return;
    }
    if (rawDef.ai !== 'dumb') {
      this.log.log(`▸ Summon blocked: "${unitName}" must be a dumb unit.`, 'sy');
      return;
    }

    const battleIdx = this.state.battle();
    const scaled = this.enemyDefForCurrentBattle(rawDef, battleIdx);
    const nextId = Math.max(-1, ...this.state.enemies().map(x => x.id)) + 1;
    const spawned = createEnemyState(scaled, nextId);

    if (this.state.animOn()) await this.anim.paceBetweenSteps();
    const deadSlot = this.state.enemies().findIndex(x => x.dead);
    if (deadSlot >= 0) {
      this.state.replaceEnemy(deadSlot, spawned);
      this.log.log(`▸ ${e.name} — SUMMON! ${spawned.name} replaces the fallen (${pct}% on natural 20).`, 'en');
    } else {
      this.state.appendEnemy(spawned);
      this.log.log(`▸ ${e.name} — SUMMON! ${spawned.name} joins (${pct}% on natural 20).`, 'en');
    }
    this.targeting.assignTargets();
  }

  private async resolveEnemyTurnActionPacing(ei: number): Promise<void> {
    const e = this.state.enemies()[ei];
    if (e.dead) return;
    const act = e.plan;
    if (!act) return;

    await this.anim.gapBetweenActors();
    await this.anim.pfShake(this.anim.enemyPortraitEl(ei));

    if (act.dmg > 0) {
      const heroes = this.state.heroes();
      let hIdx = heroes.findIndex(h => h.id === e.targeting && h.currentHp > 0);
      if (hIdx < 0) {
        const fb = heroes.findIndex(h => h.currentHp > 0);
        if (fb >= 0) {
          hIdx = fb;
          this.log.log(`▸ ${e.name} — retargeted (lock lost).`, 'sy');
        }
      }
      if (hIdx >= 0) {
        const ht = heroes[hIdx];
        let dmg = act.dmg;
        if (act.packBonus) {
          const packCount = this.state.enemies().filter(x => !x.dead && x.type === e.type && x.id !== e.id).length;
          if (packCount > 0) {
            dmg += packCount;
            this.log.log(`▸ ${e.name} — Pack bonus +${packCount}.`, 'en');
          }
        }
        if (ht.cloaked && Math.random() < 0.8) {
          this.state.updateHero(hIdx, { cloaked: false });
          this.log.log(`▸ ${e.name} attacks ${ht.name} — MISS! (Cloak)`, 'bl');
        } else {
          const exAtk = this.state.enemies()[ei];
          let rCh = exAtk.rampageCharges || 0;
          if (rCh > 0 && dmg > 0) {
            dmg *= 2;
            rCh -= 1;
            this.state.updateEnemy(ei, { rampageCharges: rCh });
            this.log.log(`▸ ${e.name} — RAMPAGE (×2).`, 'en');
          }
          // Iron Curtain relic: enemies deal 75% damage
          const enemyDmgMult = this.relicService.getEnemyDmgMult();
          if (enemyDmgMult !== 1 && dmg > 0) {
            dmg = Math.floor(dmg * enemyDmgMult);
          }
          // Gear: Signal Jammer Mk2 — reduce incoming damage
          const dmgReduction = this.gearService.getHeroDmgReduction(hIdx);
          if (dmgReduction > 0 && dmg > 0) {
            dmg = Math.max(0, dmg - dmgReduction);
          }
          await this.pulseHeroPortrait(hIdx, 'pf-flash-red');
          this.state.updateHero(hIdx, { cloaked: false });
          if (coalesceShieldStacks(ht).length > 0) {
            const { absorbed, ...shPatch } = absorbDamageThroughShield(ht, dmg);
            dmg = Math.max(0, dmg - absorbed);
            this.state.updateHero(hIdx, shPatch);
            if (absorbed > 0) this.log.log(`▸ ${ht.name}'s shield absorbs ${absorbed}.`, 'sy');
          }
          let newHpVal = Math.max(0, this.state.heroes()[hIdx].currentHp - dmg);
          // Gear: Dead Man's Chip — survive a killing blow at 1 HP (once per battle)
          const hxCurrent = this.state.heroes()[hIdx];
          if (newHpVal <= 0 && !hxCurrent.surviveOnceFired && this.gearService.hasSurviveOnce(hIdx)) {
            newHpVal = 1;
            this.state.updateHero(hIdx, { surviveOnceFired: true });
            this.log.log(`▸ ${hxCurrent.name}'s Dead Man's Chip triggers — survives at 1 HP!`, 'sy');
          }
          this.state.updateHero(hIdx, { currentHp: newHpVal });
          if (newHpVal <= 0) this.sound.playDeath();
          this.log.log(`▸ ${e.name} → ${ht.name}: ${dmg} dmg. (${newHpVal}/${ht.maxHp} HP)`, 'en');
          if (newHpVal <= 0) this.log.log(`▸ ${ht.name} is down.`, 'sy');
          const ls = act.lifestealPct;
          const hpDmg = dmg;
          if (hpDmg > 0 && ls != null && ls > 0) {
            const gain = Math.max(1, Math.round((hpDmg * ls) / 100));
            const ex = this.state.enemies()[ei];
            const nh = Math.min(ex.maxHp, ex.currentHp + gain);
            if (nh > ex.currentHp) {
              this.state.updateEnemy(ei, { currentHp: nh });
              this.log.log(`▸ ${e.name} drains +${nh - ex.currentHp} HP.`, 'en');
            }
          }
        }
      }
    }

    if (act.shield > 0) {
      await this.pulseEnemyPortrait(ei, 'pf-flash-blue');
      const ex = this.state.enemies()[ei];
      this.state.updateEnemy(ei, addShieldToUnit(ex, act.shield, act.shT || 2));
      this.log.log(`▸ ${e.name} → ${act.name}! (+${act.shield} shield)`, 'en');
    }

    if ((act.shieldAlly || 0) > 0) {
      const others = this.state.enemies().filter(x => !x.dead && x.id !== e.id);
      if (others.length) {
        const tgt = others.reduce((a, b) => a.currentHp < b.currentHp ? a : b, others[0]);
        const tgtIdx = this.state.enemies().findIndex(x => x.id === tgt.id);
        await this.pulseEnemyPortrait(tgtIdx, 'pf-flash-blue');
        this.state.updateEnemy(tgtIdx, addShieldToUnit(tgt, act.shieldAlly || 0, act.shT || 2));
        this.log.log(`▸ ${e.name} → ${tgt.name}: +${act.shieldAlly} shield (ally).`, 'en');
      }
    }

    if (act.heal > 0) {
      const alive = this.state.enemies().filter(x => !x.dead);
      const weakest = alive.reduce((a, b) => a.currentHp < b.currentHp ? a : b, alive[0]);
      if (weakest) {
        const wIdx = this.state.enemies().findIndex(x => x.id === weakest.id);
        await this.pulseEnemyPortrait(wIdx, 'pf-flash-green');
        const newHp = Math.min(weakest.maxHp, weakest.currentHp + act.heal);
        this.state.updateEnemy(wIdx, { currentHp: newHp });
        this.log.log(`▸ ${e.name} repairs ${weakest.name} +${act.heal} HP!`, 'en');
      }
    }

    if (act.rfm && act.rfm > 0) {
      const dur = act.rfmT || 2;
      if (
        e.type === 'rust' ||
        e.type === 'mite' ||
        e.type === 'beastMonkey' ||
        e.type === 'veilShard' ||
        e.type === 'voidWisp' ||
        e.type === 'signalSkimmer'
      ) {
        const hIdx = this.state.heroes().findIndex(h => h.id === e.targeting && h.currentHp > 0);
        if (hIdx >= 0) {
          const ht = this.state.heroes()[hIdx];
          await this.pulseHeroPortrait(hIdx, 'pf-flash-amber');
          this.state.pushHeroRfmStack(hIdx, act.rfm, dur);
          this.log.log(`▸ ${e.name} → ${ht.name}! -${act.rfm} roll${dur > 1 ? ` (${dur}t)` : ''}.`, 'en');
        }
      } else {
        const n = this.state.heroes().length;
        for (let hi = 0; hi < n; hi++) {
          const hx = this.state.heroes()[hi];
          if (hx.currentHp <= 0) continue;
          await this.pulseHeroPortrait(hi, 'pf-flash-amber');
        }
        this.state.pushSquadRfmStack(act.rfm, dur);
        this.log.log(`▸ ${e.name} → ${act.name}! -${act.rfm} roll${dur > 1 ? ` (${dur}t)` : ''}.`, 'en');
      }
    }

    if (act.wipeShields) {
      const n = this.state.heroes().length;
      for (let hi = 0; hi < n; hi++) {
        const hx = this.state.heroes()[hi];
        if (hx.currentHp <= 0) continue;
        await this.pulseHeroPortrait(hi, 'pf-flash-red');
        this.state.updateHero(hi, { shield: 0, shT: 0, shieldStacks: [] });
      }
      this.log.log(`▸ ${e.name} — all hero shields wiped!`, 'en');
    }

    if (act.dot > 0) {
      const hIdx = this.state.heroes().findIndex(h => h.id === e.targeting && h.currentHp > 0);
      if (hIdx >= 0) {
        const ht = this.state.heroes()[hIdx];
        await this.pulseHeroPortrait(hIdx, 'pf-flash-red');
        this.state.updateHero(hIdx, {
          dot: (ht.dot || 0) + act.dot,
          dT: Math.max(ht.dT || 0, act.dT || 2),
        });
      }
    }

    if ((act.erb || 0) > 0) {
      const amt = act.erb as number;
      const dur = Math.max(1, act.erbT || 2);
      if (act.erbAll) {
        const n = this.state.enemies().length;
        for (let i = 0; i < n; i++) {
          if (i === ei) continue;
          const ex = this.state.enemies()[i];
          if (ex.dead || ex.currentHp <= 0) continue;
          await this.pulseEnemyPortrait(i, 'pf-flash-green');
          const nb = (ex.rollBuff || 0) + amt;
          const nt = Math.max(ex.rollBuffT || 0, dur);
          this.state.updateEnemy(i, { rollBuff: nb, rollBuffT: nt });
        }
        this.log.log(`▸ ${e.name} → ${act.name}! +${amt} roll to allies (${dur}t).`, 'en');
      } else {
        await this.pulseEnemyPortrait(ei, 'pf-flash-green');
        const ex = this.state.enemies()[ei];
        const nb = (ex.rollBuff || 0) + amt;
        const nt = Math.max(ex.rollBuffT || 0, dur);
        this.state.updateEnemy(ei, { rollBuff: nb, rollBuffT: nt });
        this.log.log(`▸ ${e.name} → ${act.name}! +${amt} enemy roll (${dur}t).`, 'en');
      }
    }

    if ((act.counterspellPct ?? 0) > 0) {
      const pct = Math.max(0, Math.min(100, act.counterspellPct!));
      await this.pulseEnemyPortrait(ei, 'pf-flash-amber');
      this.state.updateEnemy(ei, { counterReflectPct: pct, counterTaggedThisPlayerRound: false });
      this.log.log(`▸ ${e.name} — COUNTER ${pct}% (next hero damage may reflect to attacker).`, 'en');
    }

    if ((act.grantRampage || 0) > 0) {
      await this.pulseEnemyPortrait(ei, 'pf-flash-red');
      const ex = this.state.enemies()[ei];
      const n = (ex.rampageCharges || 0) + (act.grantRampage as number);
      this.state.updateEnemy(ei, { rampageCharges: n });
      this.log.log(`▸ ${e.name} — blood up (+${act.grantRampage} rampage).`, 'en');
    }
    if ((act.grantRampageAll || 0) > 0) {
      const amt = act.grantRampageAll as number;
      const nEn = this.state.enemies().length;
      for (let i = 0; i < nEn; i++) {
        const ex = this.state.enemies()[i];
        if (ex.dead || ex.currentHp <= 0) continue;
        await this.pulseEnemyPortrait(i, 'pf-flash-red');
        this.state.updateEnemy(i, { rampageCharges: (ex.rampageCharges || 0) + amt });
      }
      this.log.log(`▸ ${e.name} — STAMPEDE! All beasts gain rampage (+${amt}).`, 'en');
    }

    if ((act.cowerT || 0) > 0) {
      const T = act.cowerT as number;
      const heroesNow = this.state.heroes();
      if (act.cowerAll) {
        for (let hi = 0; hi < heroesNow.length; hi++) {
          const hx = heroesNow[hi];
          if (hx.currentHp <= 0) continue;
          await this.pulseHeroPortrait(hi, 'pf-flash-amber');
          const nc = Math.max(hx.cowerTurns || 0, T);
          this.state.updateHero(hi, { cowerTurns: nc });
        }
        this.log.log(`▸ ${e.name} — dread takes the squad (${T} player round${T > 1 ? 's' : ''}).`, 'en');
      } else {
        const cIdx = heroesNow.findIndex(h => h.id === e.targeting && h.currentHp > 0);
        if (cIdx >= 0) {
          const hx = heroesNow[cIdx];
          await this.pulseHeroPortrait(cIdx, 'pf-flash-amber');
          const nc = Math.max(hx.cowerTurns || 0, T);
          this.state.updateHero(cIdx, { cowerTurns: nc });
          this.log.log(`▸ ${e.name} → ${hx.name}: cower (${T} player round${T > 1 ? 's' : ''}).`, 'en');
        }
      }
    }

    if (act.enemySelfTaunt) {
      this.state.forcedEnemyTargetIdx.set(ei);
      this.log.log(`▸ ${e.name} draws focus — heroes must target it next round.`, 'en');
    }

    if (act.curseDice) {
      const hIdx = this.state.heroes().findIndex(h => h.id === e.targeting && h.currentHp > 0);
      if (hIdx >= 0) {
        const ht = this.state.heroes()[hIdx];
        await this.pulseHeroPortrait(hIdx, 'pf-flash-amber');
        this.state.updateHero(hIdx, { cursed: true });
        this.log.log(`▸ ${e.name} curses ${ht.name} — rolls twice, keeps lower next turn.`, 'en');
      }
    }

    await this.maybeEliteNaturalTwentySummon(ei, e, act);
  }

  applyDamageToEnemy(
    idx: number,
    dmg: number,
    src: string,
    ignSh: boolean,
    attackingHeroIdx?: number | null,
  ): void {
    const e = this.state.enemies()[idx];
    if (!e || !this.enemyAcceptsHeroEffects(e)) return;
    if (dmg <= 0) return;

    if (
      attackingHeroIdx != null &&
      attackingHeroIdx >= 0 &&
      e.counterReflectPct != null &&
      e.counterReflectPct > 0
    ) {
      const pct = e.counterReflectPct;
      this.state.updateEnemy(idx, { counterTaggedThisPlayerRound: true, counterReflectPct: null });
      const reflects = Math.random() * 100 < pct;
        if (reflects) {
        const h = this.state.heroes()[attackingHeroIdx];
        if (h && h.currentHp > 0) {
          const newHp = Math.max(0, h.currentHp - dmg);
          this.state.updateHero(attackingHeroIdx, { currentHp: newHp });
          if (newHp <= 0) this.sound.playDeath();
          this.log.log(`▸ ${e.name} COUNTERS — ${dmg} dmg reflects to ${h.name}! (${pct}% chance)`, 'pl');
        }
        return;
      }
    }

    let actualDmg = dmg;
    if (!ignSh && coalesceShieldStacks(e).length > 0) {
      const { absorbed, ...shPatch } = absorbDamageThroughShield(e, actualDmg);
      actualDmg = Math.max(0, actualDmg - absorbed);
      this.state.updateEnemy(idx, shPatch);
      if (absorbed > 0) this.log.log(`▸ ${e.name}'s shield absorbs ${absorbed}.`, 'sy');
    }
    if (actualDmg <= 0) return;
    let newHp = Math.max(0, e.currentHp - actualDmg);
    if (this.state.tutorial()?.active && idx === 0) {
      newHp = Math.max(1, newHp);
    }
    this.state.updateEnemy(idx, { currentHp: newHp });
    this.log.log(`▸ ${src} → ${e.name}: ${actualDmg} dmg. (${newHp}/${e.maxHp} HP)`, 'pl');
    this.checkDead(idx);
  }

  checkDead(idx: number): void {
    const e = this.state.enemies()[idx];
    if (e.currentHp <= 0 && !e.dead) {
      this.sound.playDeath();
      this.state.updateEnemy(idx, {
        dead: true,
        dot: 0,
        dT: 0,
        rfeStacks: [],
        rfe: 0,
        rfT: 0,
        shield: 0,
        shT: 0,
        shieldStacks: [],
        rollBuff: 0,
        rollBuffT: 0,
        rampageCharges: 0,
        dieFreezeRollsRemaining: 0,
        counterReflectPct: null,
        counterTaggedThisPlayerRound: false,
        plan: null,
        preRoll: 0,
        effRoll: 0,
        curZone: 'recharge',
      });
      this.log.log(`▸ ${e.name} destroyed.`, 'sy');
      if (this.state.forcedEnemyTargetIdx() === idx) {
        this.state.forcedEnemyTargetIdx.set(null);
      }
      if (this.state.tauntEnemyIdx() === idx) {
        this.state.tauntHeroId.set(null);
        this.state.tauntEnemyIdx.set(null);
      }
      const enemies = this.state.enemies();
      const nextAlive = enemies.findIndex(en => !en.dead);
      if (nextAlive >= 0) {
        this.state.target.set(nextAlive);
      }
      // Chain Reaction relic: splash 4 damage to all other living enemies (no cascade)
      if (!this.chainReactionInProgress) {
        const chainDmg = this.relicService.getChainReactionDmg();
        if (chainDmg > 0) {
          this.chainReactionInProgress = true;
          this.state.enemies().forEach((en, ci) => {
            if (!en.dead && ci !== idx) {
              const newHp = Math.max(0, en.currentHp - chainDmg);
              this.state.updateEnemy(ci, { currentHp: newHp });
              this.log.log(`▸ Chain Reaction → ${en.name}: ${chainDmg} dmg.`, 'sy');
              this.checkDead(ci);
            }
          });
          this.chainReactionInProgress = false;
        }
      }
      // Gear: Scavenger Rig — heal N HP when any enemy dies
      this.state.heroes().forEach((hx, hIdx) => {
        const heal = this.gearService.getHealOnKill(hIdx);
        if (heal > 0 && hx.currentHp > 0 && hx.currentHp < hx.maxHp) {
          const newHp = Math.min(hx.maxHp, hx.currentHp + heal);
          this.state.updateHero(hIdx, { currentHp: newHp });
          this.log.log(`▸ ${hx.name}'s Scavenger Rig — +${heal} HP.`, 'sy');
        }
      });
    }
    // Boss phase 2
    const updated = this.state.enemies()[idx];
    if (
      updated.currentHp > 0 &&
      (updated.type === 'boss' ||
      updated.type === 'hiveBoss' ||
      updated.type === 'veilBoss' ||
      updated.type === 'voidCircletBoss' ||
      updated.type === 'beastTyrant') &&
      !updated.p2 &&
      updated.pThr &&
      updated.currentHp <= updated.pThr
    ) {
      this.state.updateEnemy(idx, { p2: true });
      this.log.log(`▸ ⚠ ${updated.name} — PHASE 2.`, 'sy');
    }
  }

  // ── Battle initialization ──

  /** Per-battle index scale + operation `trackHpScale` on max HP / phase threshold. */
  private enemyDefForCurrentBattle(
    raw: EnemyDefinition,
    battleIdx: number,
  ): EnemyDefinition & { dmgScale: number } {
    const scaled = this.enemyContent.applyBattleScale(raw, battleIdx);
    const t = battleModeConfig(this.state.battleModeId()).trackHpScale;
    if (!t || t === 1) return scaled;
    return {
      ...scaled,
      hp: Math.max(1, Math.round(scaled.hp * t)),
      pThr: scaled.pThr != null ? Math.max(1, Math.round(scaled.pThr * t)) : scaled.pThr,
    };
  }

  initBattle(): void {
    const battleIdx = this.state.battle();
    const battles = battlesForMode(this.state.battleModeId());
    const battleDef = battles[battleIdx];
    if (!battleDef) return;

    const enemies: EnemyState[] = battleDef.enemies.map((spawn, i) => {
      const raw = this.enemyContent.expandFromSpawn(spawn);
      return createEnemyState(this.enemyDefForCurrentBattle(raw, battleIdx), i);
    });

    this.portraitPreload.warmBattle(this.state.heroes(), enemies);
    this.state.enemies.set(enemies);
    this.state.phase.set('player');
    this.state.target.set(0);
    this.state.clearSquadRfmStacks();
    this.state.clearAllHeroRfmStacks();
    this.state.tauntHeroId.set(null);
    this.state.tauntEnemyIdx.set(null);
    this.state.forcedEnemyTargetIdx.set(null);
    this.state.selectedHeroIdx.set(null);
    this.state.pendingProtocol.set(null);
    this.state.pendingItemSelection.set(null);
    this.state.rollAllInProgress.set(false);
    this.state.rollAnimInProgress.set(false);
    this.state.squadDiceSettling.set(false);
    this.state.enemyDiceSettling.set(false);
    this.state.enemyTrayRevealed.set(false);
    this.state.endTurnHeroResolveCursor.set(null);
    this.state.showOverlay.set(false);

    // Fresh battle: no squad dice or locks until ROLL ALL / individual rolls (carries over from prior battle otherwise)
    this.state.heroes().forEach((_, i) => this.state.resetHeroForNewRound(i));
    this.state.heroes().forEach((_, i) =>
      this.state.updateHero(i, { cowerTurns: 0, rampageCharges: 0, relicRollBonus: 0, surviveOnceFired: false, firstAbilityFired: false }),
    );

    // Relic battle-start effects (applied after heroes reset so relicRollBonus is fresh)
    this.applyRelicBattleStartEffects(battleIdx);

    // Gear battle-start effects
    this.applyGearBattleStartEffects();

    // Enemy abilities roll when the player reveals the tray (ROLL ALL / last squad die)
    this.targeting.assignTargets();

    // Protocol starts at 0; first gain is +1 when returning to the player phase after the first END TURN.
    this.state.protocol.set(0);

    this.log.log(`— ${battleModeConfig(this.state.battleModeId()).label.toUpperCase()} · BATTLE ${battleIdx + 1} START —`, 'sy');
  }

  // ── Roll helpers ──

  /** Called by DiceTray after animation applies the roll value to state */
  clearAndAutoTarget(heroIdx: number): void {
    this.targeting.clearHeroTargetingOnRollChange(heroIdx);
    this.targeting.runAutoTargetForHero(heroIdx);
  }

  /**
   * Precompute one hero roll (tutorial presets, cursed pair, RFM). Does not write roll/rawRoll.
   * Does not clear `cursed` — the CURSED ribbon drops at end of the player round.
   */
  computeHeroRollPreset(heroIdx: number): ComputedRollAllPayload['heroRolls'][number] | null {
    const h = this.state.heroes()[heroIdx];
    if (!h || h.currentHp <= 0 || (h.cowerTurns || 0) > 0 || h.roll !== null) return null;
    if ((h.dieFreezeRollsRemaining || 0) > 0) return null;
    if (!this.state.isPlayerPhase()) return null;

    const preset = this.tutorial.getHeroRollPreset(heroIdx);
    let raw = preset ?? this.dice.d20();
    let cursedPair: { low: number; high: number; r1: number; r2: number } | undefined;
    if (!preset && h.cursed) {
      const r1 = raw;
      const r2 = this.dice.d20();
      const low = Math.min(r1, r2);
      const high = Math.max(r1, r2);
      raw = low;
      cursedPair = { low, high, r1, r2 };
      this.log.log(`▸ ${h.name} — Cursed! Rolled twice, kept lower.`, 'sy');
    }
    const rfmPen = this.state.combinedHeroRawRfmPenalty(heroIdx);
    if (rfmPen > 0) raw = Math.max(1, raw - rfmPen);
    return { heroIdx, finalRoll: raw, cursedPair };
  }

  /** Apply a single hero roll after instant click or tray animation. */
  applyHeroRollPreset(
    hr: ComputedRollAllPayload['heroRolls'][number],
    presRoll: (number | null)[],
  ): void {
    const idx = hr.heroIdx;
    this.state.updateHero(idx, { roll: hr.finalRoll, rawRoll: hr.finalRoll });
    if (hr.cursedPair) {
      this.state.beginCursedRollShowcase(idx, hr.cursedPair.low, hr.cursedPair.high);
    }
    this.targeting.clearHeroTargetingOnRollChange(idx);
    this.targeting.runAutoTargetForHero(idx);
    if (
      this.state.heroes().every(
        x =>
          x.currentHp <= 0 ||
          x.roll !== null ||
          ((x.cowerTurns || 0) > 0 && x.roll === null),
      )
    ) {
      this.state.heroes().forEach((h, i) => {
        if (h.currentHp <= 0) return;
        if (i === idx) return;
        if ((h.dieFreezeRollsRemaining || 0) <= 0) return;
        if (presRoll[i] !== null) {
          const next = h.dieFreezeRollsRemaining - 1;
          this.state.updateHero(i, { dieFreezeRollsRemaining: next });
        }
      });
      this.rollFreshEnemyPlansForReveal();
      this.state.enemyTrayRevealed.set(true);
      this.tutorial.notifyRollAllFinished();
    }
  }

  /** Roll a single hero die (no animation — instant; dice-tray uses compute/apply + animation when cursed). */
  rollHero(idx: number): void {
    const presRoll = this.state.heroes().map(h => h.roll);
    const hr = this.computeHeroRollPreset(idx);
    if (!hr) return;
    this.applyHeroRollPreset(hr, presRoll);
  }

  /**
   * Build the same hero/enemy d20 results ROLL ALL would use (tutorial presets + RFM penalties).
   * Returns null when there is nothing left to roll on the tray.
   */
  computeRollAllPresets(): ComputedRollAllPayload | null {
    const heroes = this.state.heroes();
    const enemies = this.state.enemies();

    const heroRolls: ComputedRollAllPayload['heroRolls'] = [];
    for (let i = 0; i < heroes.length; i++) {
      const h = heroes[i];
      if (h.currentHp <= 0 || (h.cowerTurns || 0) > 0 || h.roll !== null) continue;
      if ((h.dieFreezeRollsRemaining || 0) > 0) continue;
      const preset = this.tutorial.getHeroRollPreset(i);
      let raw = preset ?? this.dice.d20();
      let cursedPair: { low: number; high: number; r1: number; r2: number } | undefined;
      if (!preset && h.cursed) {
        const r1 = raw;
        const r2 = this.dice.d20();
        const low = Math.min(r1, r2);
        const high = Math.max(r1, r2);
        raw = low;
        cursedPair = { low, high, r1, r2 };
        this.log.log(`▸ ${h.name} — Cursed! Rolled twice, kept lower.`, 'sy');
      }
      const rfmPen = this.state.combinedHeroRawRfmPenalty(i);
      if (rfmPen > 0) raw = Math.max(1, raw - rfmPen);
      heroRolls.push({ heroIdx: i, finalRoll: raw, cursedPair });
    }

    const tutEnemyPre = this.tutorial.getTutorialEnemyPreRoll();
    const enemyRolls: ComputedRollAllPayload['enemyRolls'] = [];
    for (let i = 0; i < enemies.length; i++) {
      const e = enemies[i];
      if (e.dead) continue;
      if ((e.dieFreezeRollsRemaining || 0) > 0) continue;
      const preRoll = tutEnemyPre ?? this.dice.d20();
      const displayEff = Math.min(20, Math.max(1, preRoll - (e.rfe || 0) + (e.rollBuff || 0)));
      enemyRolls.push({ enemyIdx: i, preRoll, displayEff });
    }

    if (!heroRolls.length && !enemyRolls.length) return null;
    return { heroRolls, enemyRolls };
  }

  /** Apply tray roll results after animation or instant sim (matches dice-tray onFinished). */
  applyRollAllPayload(payload: ComputedRollAllPayload): void {
    const rolledHero = new Set(payload.heroRolls.map(hr => hr.heroIdx));
    for (const hr of payload.heroRolls) {
      this.state.updateHero(hr.heroIdx, {
        roll: hr.finalRoll,
        rawRoll: hr.finalRoll,
        noRR: true,
      });
      if (hr.cursedPair) {
        this.state.beginCursedRollShowcase(hr.heroIdx, hr.cursedPair.low, hr.cursedPair.high);
      }
      this.clearAndAutoTarget(hr.heroIdx);
    }
    this.state.heroes().forEach((h, i) => {
      if (h.currentHp <= 0) return;
      if (rolledHero.has(i)) return;
      if ((h.dieFreezeRollsRemaining || 0) <= 0) return;
      const next = h.dieFreezeRollsRemaining - 1;
      this.state.updateHero(i, { dieFreezeRollsRemaining: next });
    });
    if (payload.enemyRolls.length) {
      this.applyEnemyAbilityRollsFromPreRolls(
        payload.enemyRolls.map(er => ({ enemyIndex: er.enemyIdx, preRoll: er.preRoll })),
      );
    }
    const rolledEnemy = new Set(payload.enemyRolls.map(er => er.enemyIdx));
    this.state.enemies().forEach((e, i) => {
      if (e.dead) return;
      if (rolledEnemy.has(i)) return;
      if ((e.dieFreezeRollsRemaining || 0) <= 0) return;
      const next = e.dieFreezeRollsRemaining - 1;
      this.state.updateEnemy(i, { dieFreezeRollsRemaining: next });
    });
    this.state.enemyTrayRevealed.set(true);
    this.tutorial.notifyRollAllFinished();
    this.targeting.assignTargets();
  }

  instantRollAllForSim(): void {
    const payload = this.computeRollAllPresets();
    if (payload) {
      this.applyRollAllPayload(payload);
      this.sound.playRollReveal();
    }
  }

  /** CURSED ribbon stays through roll + targeting until the player round ends. */
  private clearCursedRibbonAfterPlayerRound(): void {
    this.state.heroes().forEach((h, i) => {
      if (h.cursed) this.state.updateHero(i, { cursed: false });
    });
  }

  // ── End turn (player turn resolution) ──

  async endTurn(opts?: { chainEnemyPhase?: boolean }): Promise<void> {
    if (!this.state.isPlayerPhase()) return;
    if (this.state.pendingItemSelection()) {
      this.state.pendingItemSelection.set(null);
    }

    // Auto-target any remaining heroes
    const heroes = this.state.heroes();
    heroes.forEach((_, i) => this.targeting.runAutoTargetForHero(i));
    if (!this.targeting.allHeroesReadyForEndTurn()) return;

    const tutErr = this.tutorial.validateBeforePlayerResolve();
    if (tutErr) {
      this.state.addLog(tutErr, 'sy');
      return;
    }

    this.tutorial.finishCoachOnEndTurn();

    this.sound.playEndTurn();

    // Tick roll buff durations
    heroes.forEach((h, i) => {
      if (h.rollBuffT > 0) {
        const newT = h.rollBuffT - 1;
        this.state.updateHero(i, {
          rollBuffT: newT,
          rollBuff: newT <= 0 ? 0 : h.rollBuff,
        });
      }
    });

    // Force-roll any unrolled alive heroes (cowering heroes skip — no roll this round)
    this.state.heroes().forEach((h, i) => {
      if (h.currentHp <= 0 || (h.cowerTurns || 0) > 0 || h.roll !== null) return;
      let raw = this.dice.d20();
      const pen = this.state.combinedHeroRawRfmPenalty(i);
      if (pen > 0) raw = Math.max(1, raw - pen);
      this.state.updateHero(i, { roll: raw, rawRoll: raw, noRR: true });
      this.targeting.clearHeroTargetingOnRollChange(i);
      this.targeting.runAutoTargetForHero(i);
    });

    this.state.endTurnHeroResolveCursor.set(0);
    try {
      // Counter buff: fresh tag tracking for this player round
      this.state.enemies().forEach((e, i) => {
        if (e.dead) return;
        if (e.counterReflectPct != null) {
          this.state.updateEnemy(i, { counterTaggedThisPlayerRound: false });
        }
      });

      // Tick enemy DoTs (Resonance Cascade relic adds +2 per tick)
      const dotBonus = this.relicService.getDotBonus() + this.gearService.getTotalDotDmgBonus();
      this.state.enemies().forEach((e, i) => {
        if (e.dead) return;
        if (e.dot > 0 && e.dT > 0) {
          this.applyDamageToEnemy(i, e.dot + dotBonus, 'DoT', false);
          const newDT = e.dT - 1;
          this.state.updateEnemy(i, { dT: newDT, dot: newDT <= 0 ? 0 : e.dot });
        }
        const stacks = e.rfeStacks?.length ? e.rfeStacks : [];
        if (stacks.length > 0) {
          const next = tickEnemyRfeStacks(stacks);
          const { rfe, rfT } = enemyRfeFromStacks(next);
          this.state.updateEnemy(i, { rfeStacks: next, rfe, rfT });
        }
      });

      // If DoT cleared the fight, still tick squad/hero roll debuffs before win (otherwise stacks never age this END TURN).
      if (this.state.enemies().every(e => e.dead)) {
        this.state.tickSquadRfmStacksForEndOfPlayerRound();
        this.state.tickHeroRfmStacksForEndOfPlayerRound();
        this.won();
        return;
      }

      // Resolve each hero's ability (left → right), with optional action pacing / portrait flashes
      for (let hi = 0; hi < this.state.heroes().length; hi++) {
        await this.resolveHeroEndTurnWithActionPacing(hi);
        this.state.endTurnHeroResolveCursor.set(hi + 1);
      }

      // Counter: clear if no hero ability damage targeted this enemy this round
      this.state.enemies().forEach((e, i) => {
        if (e.dead) return;
        if (e.counterReflectPct != null && !e.counterTaggedThisPlayerRound) {
          this.state.updateEnemy(i, { counterReflectPct: null });
        }
      });

      // Squad / per-hero −roll debuff: one tick per END TURN after this round’s rolls and abilities resolve.
      this.state.tickSquadRfmStacksForEndOfPlayerRound();
      this.state.tickHeroRfmStacksForEndOfPlayerRound();

      this.state.heroes().forEach((h, i) => {
        if (h.currentHp <= 0) return;
        const ct = h.cowerTurns || 0;
        if (ct > 0) this.state.updateHero(i, { cowerTurns: ct - 1 });
      });

      // Check win
      if (this.state.enemies().every(e => e.dead)) {
        this.won();
        return;
      }

      this.clearCursedRibbonAfterPlayerRound();

      // Switch to enemy phase
      this.state.phase.set('enemy');
      if (opts?.chainEnemyPhase) {
        await this.enemyTurn();
      } else {
        setTimeout(() => void this.enemyTurn(), 700);
      }
    } finally {
      this.state.endTurnHeroResolveCursor.set(null);
    }
  }

  /**
   * Auto-play the current battle to completion: same RNG and rules as manual play.
   * With animations on, uses the dice-tray roll animation and normal combat pacing; with animations off, resolves instantly.
   */
  async runSimBattle(): Promise<void> {
    if (this.state.tutorial()?.active) return;
    if (this.state.pendingProtocol() != null || this.state.pendingItemSelection() != null) {
      this.log.log('▸ Finish the current action before Sim Battle.', 'sy');
      return;
    }
    if (this.simBattleRunning()) return;
    this.simBattleRunning.set(true);
    const maxRounds = 500;
    let rounds = 0;
    try {
      while (rounds < maxRounds) {
        rounds++;
        const phase = this.state.phase();
        if (phase === 'over') break;

        if (phase === 'enemy') {
          await this.enemyTurn();
          continue;
        }

        if (phase !== 'player') break;

        if (!this.state.allHeroesRolled()) {
          if (this.state.animOn() && this.rollAllDelegate) {
            await this.rollAllDelegate.applyAnimated();
          } else {
            if (this.state.animOn() && !this.rollAllDelegate) {
              this.log.log('▸ Sim battle: tray not ready for animated rolls; applying rolls instantly.', 'sy');
            }
            this.instantRollAllForSim();
          }
        }

        this.targeting.applySimBattleAutoTargets();

        if (!this.targeting.allHeroesReadyForEndTurn()) {
          this.log.log('▸ Sim battle stopped: could not auto-complete targeting.', 'sy');
          break;
        }

        const tutErr = this.tutorial.validateBeforePlayerResolve();
        if (tutErr) {
          this.state.addLog(tutErr, 'sy');
          break;
        }

        await this.endTurn({ chainEnemyPhase: true });
      }
      if (rounds >= maxRounds && this.state.phase() !== 'over') {
        this.log.log('▸ Sim battle stopped: round limit (stalemate or loop).', 'sy');
      }
    } finally {
      this.simBattleRunning.set(false);
    }
  }

  /** Auto-play a single turn with animations: roll all dice, auto-target, end turn. */
  async autoPlayTurn(): Promise<void> {
    if (!this.state.isPlayerPhase()) return;
    if (this.state.endTurnHeroResolveCursor() !== null) return;
    if (this.state.rollAllInProgress()) return;
    if (!this.state.allHeroesRolled()) {
      if (this.state.animOn() && this.rollAllDelegate) {
        await this.rollAllDelegate.applyAnimated();
      } else {
        this.instantRollAllForSim();
      }
    }
    this.targeting.applySimBattleAutoTargets();
    this.endTurn();
  }

  // ── Enemy turn ──

  async enemyTurn(): Promise<void> {
    const hadCounterAtEnemyTurnStart = this.state.enemies().map(e => e.counterReflectPct != null);
    this.log.log(`— ENEMY TURN —`, 'sy');
    this.state.tauntHeroId.set(null);
    this.state.tauntEnemyIdx.set(null);

    // Tick hero DoTs
    this.state.heroes().forEach((h, i) => {
      if (h.dot > 0 && h.dT > 0) {
        let newHp = Math.max(0, h.currentHp - h.dot);
        if (newHp <= 0 && !h.surviveOnceFired && this.gearService.hasSurviveOnce(i)) {
          newHp = 1;
          this.state.updateHero(i, { surviveOnceFired: true });
          this.state.addLog(`▸ ${h.name}'s Dead Man's Chip triggers — survives at 1 HP!`, 'sy');
        }
        const newDT = h.dT - 1;
        this.state.updateHero(i, {
          currentHp: newHp,
          dT: newDT,
          dot: newDT <= 0 ? 0 : h.dot,
        });
        this.log.log(`▸ ${h.name} takes ${h.dot} DoT damage.`, 'en');
        if (newHp <= 0) this.sound.playDeath();
      }
    });

    if (this.state.heroes().every(h => h.currentHp <= 0)) { this.lost(); return; }

    // Relic: enemy turn start effects
    this.applyRelicEnemyTurnStartEffects();
    if (this.state.heroes().every(h => h.currentHp <= 0)) { this.lost(); return; }

    // Enemy actions (left → right), staggered like player resolution
    for (let ei = 0; ei < this.state.enemies().length; ei++) {
      await this.resolveEnemyTurnActionPacing(ei);
    }

    // Counter: expire any buff that survived through a full player round + this enemy phase
    hadCounterAtEnemyTurnStart.forEach((had, i) => {
      if (!had) return;
      const ex = this.state.enemies()[i];
      if (ex.dead) return;
      if (ex.counterReflectPct != null) {
        this.state.updateEnemy(i, { counterReflectPct: null, counterTaggedThisPlayerRound: false });
      }
    });

    // Decay shields + enemy roll buff duration (used on the roll just revealed this round)
    this.state.enemies().forEach((e, i) => {
      if (e.dead) return;
      if (coalesceShieldStacks(e).length > 0) {
        this.state.updateEnemy(i, tickUnitShield(e));
      }
      if ((e.rollBuffT || 0) > 0) {
        const newBt = e.rollBuffT - 1;
        this.state.updateEnemy(i, {
          rollBuffT: newBt,
          rollBuff: newBt <= 0 ? 0 : e.rollBuff,
        });
      }
    });
    this.state.heroes().forEach((h, i) => {
      if (coalesceShieldStacks(h).length > 0) {
        this.state.updateHero(i, tickUnitShield(h));
      }
    });

    // Check loss
    if (this.state.heroes().every(h => h.currentHp <= 0)) { this.lost(); return; }

    const tut = this.state.tutorial();
    if (tut?.active) {
      const nextRes = (tut.resolutions ?? 0) + 1;
      this.state.tutorial.set({
        ...tut,
        resolutions: nextRes,
        showComplete: true,
        coachStep: 5,
      });
      this.state.phase.set('player');
      this.log.log(`— TUTORIAL COMPLETE —`, 'vi');
      return;
    }

    // Next player round: no squad rolls and no enemy plan until reveal
    this.clearEnemyPlansForNextPlayerRound();
    this.state.heroes().forEach((_, i) => this.state.resetHeroForNewRound(i));
    this.targeting.assignTargets();

    this.state.phase.set('player');
    this.state.forcedEnemyTargetIdx.set(null);
    this.state.selectedHeroIdx.set(null);
    this.state.pendingProtocol.set(null);
    this.state.pendingItemSelection.set(null);
    this.state.rollAllInProgress.set(false);
    this.state.squadDiceSettling.set(false);
    this.state.squadSettleHeroIdx.set(null);
    this.state.enemyTrayRevealed.set(false);

    this.protocol.grantForNewRound(); // +1 Protocol for the round you’re about to play (after prior END TURN)
    this.log.log(`— PLAYER TURN —`, 'sy');
  }

  // ── Win / Loss ──

  won(): void {
    if (this.state.tutorial()?.active) {
      return;
    }
    this.clearCursedRibbonAfterPlayerRound();
    this.state.phase.set('over');
    this.log.log(`▸ All enemies down. Battle ${this.state.battle() + 1} complete.`, 'vi');

    const mode = battleModeConfig(this.state.battleModeId());
    const lastBattleIdx = battleCountForMode(this.state.battleModeId()) - 1;
    if (this.state.battle() >= lastBattleIdx) {
      this.showOverlay(mode.victoryTitle, mode.victorySub, 'NEW RUN ↺', true, () => this.newRun());
      return;
    }

    const nextBattleIdx = this.state.battle() + 1;
    const nextDef = battlesForMode(this.state.battleModeId())[nextBattleIdx];
    if (nextDef) {
      const types = nextDef.enemies.map(s => this.enemyContent.expandFromSpawn(s).type);
      this.portraitPreload.warmEnemyTypes(types);
    }

    // XP → evolution (if any) → item draft → next battle overlay. ItemService skips draft when inventory full.
    this.afterBattleVictorySequence();
  }

  /** Award XP, show evolution overlay first when applicable, then item draft, then “next battle” overlay. */
  afterBattleVictorySequence(): void {
    this.evolution.awardXp();
    const eligible = this.evolution.getEligibleHeroes();
    if (eligible.length > 0) {
      this.state.pendingEvolutions.set(eligible.map(i => ({ heroIdx: i, chosen: null })));
    } else {
      this.beginPostEvoItemDraft();
    }
  }

  /** Called after evolution confirm, or directly when no evolution was pending. */
  beginPostEvoItemDraft(): void {
    const onDone = () =>
      this.showOverlay('BATTLE CLEARED', `Battle ${this.state.battle() + 1} complete.`, 'NEXT BATTLE ▶', true, () => this.nextBattle());

    // After battle 5 (index 4): relic draft instead of item drop (once per run)
    if (this.state.battle() === 4 && this.state.relics().length === 0) {
      this.relicService.startRelicDraft(onDone);
      return;
    }
    this.items.startPostWinDraft(onDone);
  }

  rerollEnemyDie(enemyIdx: number, srcLabel: string): void {
    const e = this.state.enemies()[enemyIdx];
    if (!e || e.dead) return;
    const pre = this.dice.d20();
    this.state.updateEnemy(enemyIdx, { dieFreezeRollsRemaining: 0 });
    this.applyEnemyAbilityRoll(enemyIdx, pre);
    this.log.log(`▸ Item: ${srcLabel} → ${e.name} die rerolled (face ${e.effRoll}).`, 'pl');
  }

  rerollAllEnemyDice(srcLabel: string): void {
    const enemies = this.state.enemies();
    for (let i = 0; i < enemies.length; i++) {
      if (enemies[i].dead) continue;
      this.state.updateEnemy(i, { dieFreezeRollsRemaining: 0 });
      this.applyEnemyAbilityRoll(i, this.dice.d20());
    }
    this.log.log(`▸ Item: ${srcLabel} → all enemy dice rerolled.`, 'pl');
  }

  lost(): void {
    this.clearCursedRibbonAfterPlayerRound();
    this.state.phase.set('over');
    this.log.log(`▸ Squad wiped. Run terminated.`, 'de');
    this.showOverlay('SQUAD WIPED', `Eliminated at battle ${this.state.battle() + 1}.`, 'NEW RUN ↺', false, () => this.newRun());
  }

  nextBattle(): void {
    this.state.showOverlay.set(false);
    this.state.battle.update(b => b + 1);

    // Restore hero HP: alive = 100%, dead = revive at 80% (single set so every card gets a fresh ref)
    // Clear per-battle combat state (rampageCharges, relicRollBonus re-applied in initBattle via applyRelicBattleStartEffects)
    const heroes = this.state.heroes();
    this.state.heroes.set(
      heroes.map(h => {
        const baseMaxHp = h.maxHp - (h.gearMaxHpBonus || 0);
        return h.currentHp > 0
          ? { ...h, currentHp: baseMaxHp, maxHp: baseMaxHp, shield: 0, shT: 0, shieldStacks: [], dot: 0, dT: 0, cloaked: false, rampageCharges: 0, relicRollBonus: 0, gearMaxHpBonus: 0, surviveOnceFired: false, firstAbilityFired: false }
          : { ...h, currentHp: Math.max(1, Math.round(baseMaxHp * 0.8)), maxHp: baseMaxHp, shield: 0, shT: 0, shieldStacks: [], dot: 0, dT: 0, cloaked: false, rampageCharges: 0, relicRollBonus: 0, gearMaxHpBonus: 0, surviveOnceFired: false, firstAbilityFired: false };
      }),
    );

    this.initBattle();
  }

  newRun(): void {
    this.state.reset();
    this.state.initHeroes();
    this.state.battle.set(0);
    this.initBattle();
  }

  /** Wipe the run and return to operation selection (same session). */
  returnToOperationPicker(): void {
    this.state.reset();
    this.state.showOperationPicker.set(true);
  }

  // ── Relic effect methods ─────────────────────────────────────────────────────

  /**
   * Apply battle-start relic effects after enemies are initialized and heroes are reset.
   * Called at the end of initBattle().
   */
  private applyRelicBattleStartEffects(battleIdx: number): void {
    const relics = this.state.relics();
    if (!relics.length) return;

    // Plague Protocol: all enemies start with 3 DoT (permanent for this battle)
    if (relics.includes('plagueProtocol')) {
      this.state.enemies().forEach((_, i) => {
        this.state.updateEnemy(i, { dot: 3, dT: 999 });
      });
      this.log.log('▸ Plague Protocol — all enemies infected with 3 DoT.', 'sy');
    }

    // Signal Jam: all enemies start with −2 RFE
    if (relics.includes('signalJam')) {
      this.state.enemies().forEach((e, i) => {
        const stack = { amt: 2, turnsLeft: 999 };
        const newStacks = [...(e.rfeStacks || []), stack];
        const { rfe, rfT } = enemyRfeFromStacks(newStacks);
        this.state.updateEnemy(i, { rfeStacks: newStacks, rfe, rfT });
      });
      this.log.log('▸ Signal Jam — all enemies: −2 roll.', 'sy');
    }

    // Coordinated Strike: all heroes start with +2 roll (as relicRollBonus, not rollBuff)
    if (relics.includes('coordinatedStrike')) {
      this.state.heroes().forEach((h, i) => {
        if (h.currentHp > 0) this.state.updateHero(i, { relicRollBonus: 2 });
      });
      this.log.log('▸ Coordinated Strike — all heroes: +2 roll.', 'sy');
    }

    // Entropy Leak: enemies lose 5 max HP per battle already cleared
    if (relics.includes('entropyLeak') && battleIdx >= 5) {
      const reduction = 5 * battleIdx;
      this.state.enemies().forEach((e, i) => {
        const newMaxHp = Math.max(1, e.maxHp - reduction);
        const newCurrHp = Math.max(1, Math.min(newMaxHp, e.currentHp));
        this.state.updateEnemy(i, { maxHp: newMaxHp, currentHp: newCurrHp });
      });
      this.log.log(`▸ Entropy Leak — all enemies: −${reduction} max HP.`, 'sy');
    }

    // Opening Gambit: random enemy + random hero take 50% max HP as damage
    if (relics.includes('openingGambit')) {
      const aliveEnemies = this.state.enemies().map((e, i) => ({ e, i })).filter(x => !x.e.dead);
      if (aliveEnemies.length > 0) {
        const pick = aliveEnemies[Math.floor(Math.random() * aliveEnemies.length)];
        const dmg = Math.floor(pick.e.maxHp / 2);
        const newHp = Math.max(1, pick.e.currentHp - dmg);
        this.state.updateEnemy(pick.i, { currentHp: newHp });
        this.log.log(`▸ Opening Gambit — ${pick.e.name} takes ${dmg} (50% max HP).`, 'sy');
      }
      const aliveHeroes = this.state.heroes().map((h, i) => ({ h, i })).filter(x => x.h.currentHp > 0);
      if (aliveHeroes.length > 0) {
        const pick = aliveHeroes[Math.floor(Math.random() * aliveHeroes.length)];
        const dmg = Math.floor(pick.h.maxHp / 2);
        const newHp = Math.max(1, pick.h.currentHp - dmg);
        this.state.updateHero(pick.i, { currentHp: newHp });
        this.log.log(`▸ Opening Gambit — ${pick.h.name} takes ${dmg} (50% max HP).`, 'sy');
      }
    }
  }

  /** Apply relic effects at the start of every enemy turn, before enemies act. */
  private applyRelicEnemyTurnStartEffects(): void {
    const relics = this.state.relics();
    if (!relics.length) return;

    // Gravity Well: deal 2 damage to all living enemies
    if (relics.includes('gravityWell')) {
      this.state.enemies().forEach((e, i) => {
        if (e.dead) return;
        const newHp = Math.max(0, e.currentHp - 2);
        this.state.updateEnemy(i, { currentHp: newHp });
        this.log.log(`▸ Gravity Well → ${e.name}: 2 dmg.`, 'sy');
        this.checkDead(i);
      });
    }

    // Bulwark Aura: all heroes gain 3 shield
    if (relics.includes('bulwarkAura')) {
      this.state.heroes().forEach((h, i) => {
        if (h.currentHp <= 0) return;
        this.state.updateHero(i, addShieldToUnit(h, 3, 1));
      });
      this.log.log('▸ Bulwark Aura — all heroes gain 3 shield.', 'sy');
    }

    // Nanite Field: all heroes heal 3 HP
    if (relics.includes('naniteField')) {
      this.state.heroes().forEach((h, i) => {
        if (h.currentHp <= 0) return;
        const newHp = Math.min(h.maxHp, h.currentHp + 3);
        if (newHp > h.currentHp) this.state.updateHero(i, { currentHp: newHp });
      });
      this.log.log('▸ Nanite Field — all heroes heal 3 HP.', 'sy');
    }
  }

  private showOverlay(title: string, sub: string, btnText: string, isVictory: boolean, action: () => void): void {
    this.state.overlayTitle.set(title);
    this.state.overlaySub.set(sub);
    this.state.overlayBtnText.set(btnText);
    this.state.overlayIsVictory.set(isVictory);
    this.state.overlayBtnAction.set(action);
    this.state.showOverlay.set(true);
  }

  private applyGearBattleStartEffects(): void {
    const heroes = this.state.heroes();
    for (let i = 0; i < heroes.length; i++) {
      const gear = this.gearService.getHeroGearDef(i);
      if (!gear) continue;
      const h = this.state.heroes()[i];
      if (h.currentHp <= 0) continue;
      const eff = gear.effect;

      if (eff.type === 'maxHpBonus') {
        const bonus = eff.amount;
        const newMax = h.maxHp + bonus;
        const newCurr = Math.min(newMax, h.currentHp + bonus);
        this.state.updateHero(i, { maxHp: newMax, currentHp: newCurr, gearMaxHpBonus: bonus });
        this.log.log(`▸ ${h.name}'s Stim Injector — +${bonus} max HP.`, 'sy');
      } else if (eff.type === 'battleStartShield') {
        this.state.updateHero(i, addShieldToUnit(h, eff.amount, 999));
        this.log.log(`▸ ${h.name}'s Combat Plating — +${eff.amount} shield.`, 'sy');
      } else if (eff.type === 'battleStartCloak') {
        this.state.updateHero(i, { cloaked: true });
        this.log.log(`▸ ${h.name}'s Phase Weave — cloaked.`, 'sy');
      } else if (eff.type === 'protocolOnBattleStart') {
        this.state.protocol.update(p => Math.min(10, p + eff.amount));
        this.log.log(`▸ ${h.name}'s Protocol Tap — +${eff.amount} Protocol.`, 'sy');
      }
      // rollBonus: applied permanently via gearRollBonus on HeroState (set at equip time)
      // dmgReduction, surviveOnce, firstAbilityDmgBonus, healOnKill, dotDmgBonus: passive hooks
    }
  }
}
