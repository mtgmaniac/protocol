import { Injectable } from '@angular/core';
import { HeroAbility } from '../models/ability.interface';
import { HeroState } from '../models/hero.interface';
import { EnemyState } from '../models/enemy.interface';
import { HeroId, TargetPickKind } from '../models/types';
import { GameStateService } from './game-state.service';
import { DiceService } from './dice.service';
import { LogService } from './log.service';
import { ProtocolService } from './protocol.service';
import { RerollAnimationRequestService } from './reroll-animation-request.service';
import { TutorialService } from './tutorial.service';
import { ItemService } from './item.service';

/** UI segments for the hero card “Target:” line (legacy heroTargetLineHTML). */
export interface HeroTargetLineSegment {
  t: 'plain' | 'muted' | 'all' | 'self' | 'enemy' | 'ally';
  text: string;
}

export interface HeroTargetLineView {
  segments: HeroTargetLineSegment[];
}

/** Party-wide and all-enemy auto-targets share one label; the ability makes the side obvious. */
const ALL_TARGETS_LABEL = 'All';

@Injectable({ providedIn: 'root' })
export class TargetingService {
  constructor(
    private state: GameStateService,
    private dice: DiceService,
    private log: LogService,
    private protocol: ProtocolService,
    private rerollAnim: RerollAnimationRequestService,
    private tutorial: TutorialService,
    private items: ItemService,
  ) {}

  // ── Pure predicates ──

  needsEnemyPick(ab: HeroAbility | null): boolean {
    if (!ab) return false;
    if (ab.blastAll || ab.multiHit) return false;
    if (ab.splitDmg) return false;
    if (ab.taunt) return true;
    if ((ab.dmg || 0) > 0) return true;
    if ((ab.dot || 0) > 0) return true;
    if ((ab.rfe || 0) > 0 && !ab.rfeAll) return true;
    return false;
  }

  needsAllyHealPick(ab: HeroAbility | null): boolean {
    return !!(ab && ab.healTgt && (ab.heal || 0) > 0 && !ab.revive);
  }

  needsAllyShieldPick(ab: HeroAbility | null): boolean {
    return !!(ab && ab.shTgt && (ab.shield || 0) > 0);
  }

  needsAllyRollBuffPick(ab: HeroAbility | null): boolean {
    return !!(ab && ab.rfmTgt && (ab.rfm || 0) > 0);
  }

  needsRevivePick(ab: HeroAbility | null): boolean {
    return !!(ab && ab.revive);
  }

  hasDeadAllyHero(): boolean {
    return this.state.heroes().some(h => h.currentHp <= 0);
  }

  reviveRequiresTargetPick(ab: HeroAbility | null): boolean {
    return this.needsRevivePick(ab) && this.hasDeadAllyHero();
  }

  needsFreezeDicePick(ab: HeroAbility | null): boolean {
    return (ab?.freezeAnyDice || 0) > 0;
  }

  abilityIsPureAutoNoHeroSelect(ab: HeroAbility | null): boolean {
    if (!ab) return true;
    if (ab.splitDmg) return true;
    if (
      (ab.dmg || 0) > 0 &&
      (ab.blastAll || ab.multiHit) &&
      !this.needsAllyShieldPick(ab) &&
      !this.needsAllyHealPick(ab) &&
      !this.needsAllyRollBuffPick(ab)
    ) {
      return true;
    }
    if (ab.healAll) return true;
    if (ab.shieldAll && ab.shield) return true;
    if (ab.healLowest && (ab.heal || 0) > 0) return true;
    if ((ab.heal || 0) > 0 && !ab.healTgt && !ab.healAll && !ab.healLowest && !this.needsEnemyPick(ab)) return true;
    if ((ab.shield || 0) > 0 && !ab.shTgt && !ab.shieldAll && !this.needsEnemyPick(ab)) return true;
    if (ab.revive && !this.hasDeadAllyHero()) return true;
    if ((ab.freezeAnyDice || 0) > 0) return false;
    return false;
  }

  // ── State-dependent targeting ──

  nextPickKindForHero(hi: number): TargetPickKind {
    const h = this.state.heroes()[hi];
    if (!h || h.roll === null) return null;
    const ab = this.dice.getAbilityOrNull(h);
    if (!ab) return null;
    // Buffs / revive first (ally targets only); then enemy targeting for damage/DoT/debuffs.
    if (this.needsAllyHealPick(ab) && h.healTgtIdx == null) return 'heal';
    if (this.needsAllyShieldPick(ab) && h.shTgtIdx == null) return 'shield';
    if (this.needsAllyRollBuffPick(ab) && h.rfmTgtIdx == null) return 'rollBuff';
    if (this.reviveRequiresTargetPick(ab) && h.reviveTgtIdx == null) return 'revive';
    if (
      this.needsFreezeDicePick(ab) &&
      h.freezeDiceTgtHeroIdx == null &&
      h.freezeDiceTgtEnemyIdx == null
    ) {
      return 'freezeDice';
    }
    if (this.needsEnemyPick(ab)) {
      const ei = h.lockedTarget;
      const enemies = this.state.enemies();
      const ok = ei !== undefined && ei !== null && enemies[ei] && !enemies[ei].dead;
      if (!ok) return 'enemy';
    }
    return null;
  }

  allHeroesReadyForEndTurn(): boolean {
    const heroes = this.state.heroes();
    for (let i = 0; i < heroes.length; i++) {
      const h = heroes[i];
      if (h.currentHp <= 0) continue;
      if ((h.cowerTurns || 0) > 0 && h.roll === null) continue;
      if (h.roll === null) return false;
      if (!h.confirmed) return false;
    }
    return true;
  }

  /**
   * Sim Battle: assign default ally/enemy targets so END TURN can resolve without manual picks.
   * (Self for heal/shield, first other living hero for rfmTgt, first living enemy, first dead for revive.)
   */
  applySimBattleAutoTargets(): void {
    const heroes = this.state.heroes();
    const enemies = this.state.enemies();
    const firstAliveEnemy = enemies.findIndex(e => !e.dead);

    for (let hi = 0; hi < heroes.length; hi++) {
      const h = heroes[hi];
      if (h.currentHp <= 0 || h.roll === null) continue;
      const ab = this.dice.getAbilityOrNull(h);
      if (!ab) continue;

      const patch: Partial<HeroState> = {};

      if (this.needsEnemyPick(ab)) {
        const ei = h.lockedTarget;
        const ok = ei !== undefined && ei !== null && enemies[ei] && !enemies[ei].dead;
        if (!ok && firstAliveEnemy >= 0) {
          patch.lockedTarget = firstAliveEnemy;
        }
      }

      if (this.needsFreezeDicePick(ab) && h.freezeDiceTgtHeroIdx == null && h.freezeDiceTgtEnemyIdx == null) {
        if (firstAliveEnemy >= 0) patch.freezeDiceTgtEnemyIdx = firstAliveEnemy;
        else patch.freezeDiceTgtHeroIdx = hi;
      }

      if (this.needsAllyHealPick(ab) && h.healTgtIdx == null) {
        patch.healTgtIdx = hi;
      }
      if (this.needsAllyShieldPick(ab) && h.shTgtIdx == null) {
        patch.shTgtIdx = hi;
      }
      if (this.needsAllyRollBuffPick(ab) && h.rfmTgtIdx == null) {
        const other = heroes.findIndex((x, j) => j !== hi && x.currentHp > 0);
        patch.rfmTgtIdx = other >= 0 ? other : hi;
      }
      if (this.reviveRequiresTargetPick(ab) && h.reviveTgtIdx == null) {
        const deadIdx = heroes.findIndex((x, j) => j !== hi && x.currentHp <= 0);
        if (deadIdx >= 0) {
          patch.reviveTgtIdx = deadIdx;
        }
      }

      if (Object.keys(patch).length > 0) {
        this.state.updateHero(hi, patch);
      }
      this.runAutoTargetForHero(hi);
      this.tryFinalizeHeroAfterTargets(hi);
    }
  }

  runAutoTargetForHero(hi: number): void {
    const heroes = this.state.heroes();
    const h = heroes[hi];
    if (!h || (h.cowerTurns || 0) > 0) return;
    if (h.roll === null) return;
    const startUnconfirmed = !h.confirmed;
    const ab = this.dice.getAbilityOrNull(h);
    if (!ab) return;

    const confirmAndLog = () => {
      this.state.updateHero(hi, { confirmed: true });
      if (startUnconfirmed) {
        this.logHeroLockIn(hi);
        this.recordEvoRollIfNeeded(hi);
      }
    };

    // Split damage auto-allocation
    if (ab.splitDmg) {
      const alive = this.state.enemies().filter(e => !e.dead);
      const dmg = ab.dmg || 0;
      const splitAlloc: Record<number, number> = {};
      if (alive.length) {
        const per = Math.floor(dmg / alive.length);
        const rem = dmg - per * alive.length;
        alive.forEach((e, idx) => {
          splitAlloc[e.id] = idx === 0 ? per + rem : per;
        });
      }
      this.state.updateHero(hi, { splitAlloc });
      confirmAndLog();
      return;
    }

    if (
      (ab.dmg || 0) > 0 &&
      (ab.blastAll || ab.multiHit) &&
      !this.needsAllyShieldPick(ab) &&
      !this.needsAllyHealPick(ab) &&
      !this.needsAllyRollBuffPick(ab)
    ) {
      confirmAndLog();
      return;
    }
    if (ab.healAll || (ab.shieldAll && ab.shield)) { confirmAndLog(); return; }
    if (ab.healLowest && (ab.heal || 0) > 0) { confirmAndLog(); return; }
    if ((ab.heal || 0) > 0 && !ab.healTgt && !ab.healAll && !ab.healLowest && !this.needsEnemyPick(ab)) { confirmAndLog(); return; }
    if ((ab.shield || 0) > 0 && !ab.shTgt && !ab.shieldAll && !this.needsEnemyPick(ab)) { confirmAndLog(); return; }

    // healTgt / shTgt: player must explicitly pick an ally (including self) — no auto-pick when solo.

    if (this.needsRevivePick(ab) && !this.hasDeadAllyHero()) { confirmAndLog(); return; }

    if (!this.needsEnemyPick(ab) && !this.needsAllyHealPick(ab) &&
        !this.needsAllyShieldPick(ab) && !this.needsAllyRollBuffPick(ab) &&
        !this.reviveRequiresTargetPick(ab) && !this.needsFreezeDicePick(ab)) {
      confirmAndLog();
    }
  }

  tryFinalizeHeroAfterTargets(hi: number): void {
    const h = this.state.heroes()[hi];
    if (!h || h.roll === null || h.confirmed) return;
    if (this.nextPickKindForHero(hi) !== null) return;
    this.state.updateHero(hi, { confirmed: true });
    this.logHeroLockIn(hi);
    this.recordEvoRollIfNeeded(hi);
  }

  /** Clears manual target picks and confirmation for a hero (roll unchanged). */
  resetHeroManualTargeting(hi: number): void {
    this.state.updateHero(hi, {
      lockedTarget: undefined,
      shTgtIdx: null,
      healTgtIdx: null,
      rfmTgtIdx: null,
      reviveTgtIdx: null,
      freezeDiceTgtHeroIdx: null,
      freezeDiceTgtEnemyIdx: null,
      splitAlloc: {},
      confirmed: false,
      _evoRollRecorded: false,
      _actionLogged: false,
    });
  }

  clearHeroTargetingOnRollChange(hi: number): void {
    if (this.state.selectedHeroIdx() === hi) {
      this.state.selectedHeroIdx.set(null);
    }
    this.resetHeroManualTargeting(hi);
  }

  /** True if tapping the selected caster again should reset targets instead of deselecting. */
  private casterRetapShouldResetTargeting(h: HeroState): boolean {
    if (h.roll === null) return false;
    if (h.lockedTarget !== undefined) return true;
    if (
      h.healTgtIdx != null ||
      h.shTgtIdx != null ||
      h.rfmTgtIdx != null ||
      h.reviveTgtIdx != null ||
      h.freezeDiceTgtHeroIdx != null ||
      h.freezeDiceTgtEnemyIdx != null
    ) {
      return true;
    }
    if (h.splitAlloc && Object.keys(h.splitAlloc).length > 0) return true;
    if (h.confirmed) return true;
    return false;
  }

  /**
   * Selected caster's card also gets ally-pick styling; without this, clicks would hit
   * onAllyHeroPickClick (re-applying heal/shield/rfm to self) instead of onHeroCardClick (reset).
   */
  shouldCasterRetapResetTargeting(hi: number): boolean {
    if (this.state.selectedHeroIdx() !== hi) return false;
    const h = this.state.heroes()[hi];
    return !!h && this.casterRetapShouldResetTargeting(h);
  }

  // ── AI targeting ──

  smartTarget(): HeroId | null {
    const heroes = this.state.heroes();
    const alive = heroes.filter(h => h.currentHp > 0);
    if (!alive.length) return null;
    let best = alive[0];
    let bestScore = -1;
    for (const h of alive) {
      let score = h.maxHp - h.currentHp;
      if (h.id === 'medic' || h.id === 'engineer') score += 30;
      if (h.id === 'shield' || h.id === 'avalanche') score += 10;
      if (h.id === 'ghost' || h.id === 'breaker') score += 8;
      if (score > bestScore) { bestScore = score; best = h; }
    }
    return best.id;
  }

  dumbStickyTarget(enemy: EnemyState): HeroId | null {
    const heroes = this.state.heroes();
    if (enemy.dumbStickyId) {
      const target = heroes.find(h => h.id === enemy.dumbStickyId && h.currentHp > 0);
      if (target) return target.id;
    }
    const alive = heroes.filter(h => h.currentHp > 0);
    if (!alive.length) return null;
    return alive[Math.floor(Math.random() * alive.length)].id;
  }

  assignTargets(): void {
    let tauntId = this.state.tauntHeroId();
    let tauntEi = this.state.tauntEnemyIdx();
    const heroes = this.state.heroes();
    const enemies = this.state.enemies();
    if (tauntId != null) {
      const tauntHero = heroes.find(h => h.id === tauntId && h.currentHp > 0);
      const te = tauntEi != null ? enemies[tauntEi] : null;
      if (!tauntHero || tauntEi == null || !te || te.dead) {
        this.state.tauntHeroId.set(null);
        this.state.tauntEnemyIdx.set(null);
        tauntId = null;
        tauntEi = null;
      }
    }

    enemies.forEach((e, i) => {
      if (e.dead) return;
      let tgt: HeroId | null;
      if (tauntId && tauntEi === i) {
        const tauntHero = heroes.find(h => h.id === tauntId && h.currentHp > 0);
        tgt = tauntHero ? tauntId : (e.ai === 'smart' ? this.smartTarget() : this.dumbStickyTarget(e));
      } else {
        tgt = e.ai === 'smart' ? this.smartTarget() : this.dumbStickyTarget(e);
      }
      this.state.updateEnemy(i, {
        targeting: tgt,
        dumbStickyId: e.ai === 'dumb' ? (tgt ?? e.dumbStickyId) : e.dumbStickyId,
      });
    });
  }

  // ── Click handlers ──

  onHeroCardClick(hi: number): void {
    if (!this.state.isPlayerPhase()) return;
    const h = this.state.heroes()[hi];
    if (!h) return;

    const pi = this.state.pendingItemSelection();
    if (pi) {
      const def = this.items.getDef(pi.itemId);
      if (def?.target === 'ally' && h.currentHp > 0) {
        this.items.confirmOnAllyLiving(pi.invSlot, hi);
        return;
      }
      if (def?.target === 'allyDead' && h.currentHp <= 0) {
        this.items.confirmOnAllyDead(pi.invSlot, hi);
        return;
      }
      return;
    }

    const pp = this.state.pendingProtocol();
    if (pp === 'reroll') {
      if (!this.protocol.canRerollHero(hi)) return;
      this.state.pendingProtocol.set(null);
      this.state.selectedHeroIdx.set(null);
      this.rerollAnim.emit({ heroIdx: hi });
      return;
    }
    if (pp === 'nudge') {
      if (this.protocol.applyNudge(hi)) {
        this.runAutoTargetForHero(hi);
      }
      return;
    }

    if (h.roll === null) return;

    const shiPending = this.state.selectedHeroIdx();
    if (
      shiPending != null &&
      shiPending !== hi &&
      this.nextPickKindForHero(shiPending) !== null &&
      this.nextPickKindForHero(hi) === null
    ) {
      // Another hero still owes an enemy/ally pick — ignore taps on units whose rolled ability
      // is all-enemies / self / auto-only (no manual target step), so focus stays on finishing
      // the pending targeting task.
      return;
    }

    // One tap on the caster clears heal/shield/rfm/revive/enemy lock even when selection was
    // cleared after the previous pick (otherwise the next click only re-selected).
    if (this.casterRetapShouldResetTargeting(h)) {
      this.state.selectedHeroIdx.set(hi);
      this.resetHeroManualTargeting(hi);
      this.runAutoTargetForHero(hi);
      return;
    }

    if (this.state.selectedHeroIdx() === hi) {
      this.state.selectedHeroIdx.set(null);
      return;
    }

    this.state.selectedHeroIdx.set(hi);
  }

  onEnemyPickClick(ei: number): void {
    if (!this.state.isPlayerPhase()) return;
    const enemies = this.state.enemies();
    if (!enemies[ei] || enemies[ei].dead) return;

    const pi = this.state.pendingItemSelection();
    if (pi) {
      const def = this.items.getDef(pi.itemId);
      if (def?.target === 'enemy') {
        this.items.confirmOnEnemy(pi.invSlot, ei);
      }
      return;
    }

    const forced = this.state.forcedEnemyTargetIdx();
    if (forced !== null && forced !== ei) return;

    const shi = this.state.selectedHeroIdx();
    if (shi == null) return;
    const nk = this.nextPickKindForHero(shi);
    if (nk === 'freezeDice') {
      this.state.updateHero(shi, { freezeDiceTgtEnemyIdx: ei, freezeDiceTgtHeroIdx: null });
    } else if (nk === 'enemy') {
      this.state.updateHero(shi, { lockedTarget: ei });
    } else {
      return;
    }
    if (this.nextPickKindForHero(shi) === null) {
      this.state.selectedHeroIdx.set(null);
    }
    this.tryFinalizeHeroAfterTargets(shi);
    this.tutorial.syncCoachAfterTargeting();
  }

  onAllyHeroPickClick(ti: number): void {
    if (!this.state.isPlayerPhase()) return;

    const pi = this.state.pendingItemSelection();
    if (pi) {
      const def = this.items.getDef(pi.itemId);
      if (def?.target === 'ally') {
        this.items.confirmOnAllyLiving(pi.invSlot, ti);
      } else if (def?.target === 'allyDead') {
        this.items.confirmOnAllyDead(pi.invSlot, ti);
      }
      return;
    }

    const shi = this.state.selectedHeroIdx();
    if (shi == null) return;
    const nk = this.nextPickKindForHero(shi);
    const heroes = this.state.heroes();

    if (nk === 'heal') {
      if (heroes[ti].currentHp <= 0) return;
      this.state.updateHero(shi, { healTgtIdx: ti });
    } else if (nk === 'shield') {
      if (heroes[ti].currentHp <= 0) return;
      this.state.updateHero(shi, { shTgtIdx: ti });
    } else if (nk === 'rollBuff') {
      if (heroes[ti].currentHp <= 0) return;
      this.state.updateHero(shi, { rfmTgtIdx: ti });
    } else if (nk === 'revive') {
      if (heroes[ti].currentHp > 0) return;
      this.state.updateHero(shi, { reviveTgtIdx: ti });
    } else if (nk === 'freezeDice') {
      if (heroes[ti].currentHp <= 0) return;
      this.state.updateHero(shi, { freezeDiceTgtHeroIdx: ti, freezeDiceTgtEnemyIdx: null });
    } else {
      return;
    }

    if (this.nextPickKindForHero(shi) === null) {
      this.state.selectedHeroIdx.set(null);
    }
    this.tryFinalizeHeroAfterTargets(shi);
    this.tutorial.syncCoachAfterTargeting();
  }

  // ── Hero card target line (preview) ──

  getHeroTargetLineView(hi: number): HeroTargetLineView {
    const heroes = this.state.heroes();
    const enemies = this.state.enemies();
    const h = heroes[hi];

    const lineDash = (): HeroTargetLineView => ({
      segments: [
        { t: 'plain', text: 'Target: ' },
        { t: 'muted', text: '—' },
      ],
    });

    if (!h) return lineDash();

    if (h.currentHp <= 0) return lineDash();
    if (h.roll === null) return lineDash();

    const ab = this.dice.getAbilityOrNull(h);
    if (!ab) return lineDash();

    const done = (body: HeroTargetLineSegment[]): HeroTargetLineView => ({
      segments: [{ t: 'plain', text: 'Target: ' }, ...body],
    });

    if (ab.splitDmg) return done([{ t: 'all', text: ALL_TARGETS_LABEL }]);
    if (
      ab.healAll &&
      (ab.heal || 0) > 0 &&
      (ab.dmg || 0) > 0 &&
      (ab.blastAll || ab.multiHit)
    ) {
      return done([{ t: 'all', text: ALL_TARGETS_LABEL }]);
    }
    if ((ab.dmg || 0) > 0 && (ab.blastAll || ab.multiHit)) {
      const allyFirst =
        this.needsAllyHealPick(ab) ||
        this.needsAllyShieldPick(ab) ||
        this.needsAllyRollBuffPick(ab) ||
        this.reviveRequiresTargetPick(ab);
      if (!allyFirst) {
        return done([{ t: 'all', text: ALL_TARGETS_LABEL }]);
      }
    }
    if ((ab.rfe || 0) > 0 && ab.rfeAll && !this.needsEnemyPick(ab)) {
      return done([{ t: 'all', text: ALL_TARGETS_LABEL }]);
    }
    if (ab.healAll && (ab.heal || 0) > 0 && !this.needsEnemyPick(ab)) {
      return done([{ t: 'all', text: ALL_TARGETS_LABEL }]);
    }
    if (ab.shieldAll && (ab.shield || 0) > 0 && !this.needsEnemyPick(ab)) {
      return done([{ t: 'all', text: ALL_TARGETS_LABEL }]);
    }
    if (ab.healLowest) return done([{ t: 'all', text: 'Lowest HP ally' }]);
    if (
      (ab.heal || 0) > 0 &&
      !ab.healTgt &&
      !ab.healAll &&
      !ab.healLowest &&
      !this.needsEnemyPick(ab)
    ) {
      return done([{ t: 'self', text: 'Self' }]);
    }
    if (
      (ab.shield || 0) > 0 &&
      !ab.shTgt &&
      !ab.shieldAll &&
      !this.needsEnemyPick(ab)
    ) {
      return done([{ t: 'self', text: 'Self' }]);
    }

    if (
      ab.cloak &&
      !this.needsEnemyPick(ab) &&
      !this.needsAllyHealPick(ab) &&
      !this.needsAllyShieldPick(ab) &&
      !this.needsAllyRollBuffPick(ab) &&
      !this.reviveRequiresTargetPick(ab) &&
      !this.needsFreezeDicePick(ab)
    ) {
      return done([{ t: 'self', text: 'Self' }]);
    }

    const nk = this.nextPickKindForHero(hi);

    if (this.needsRevivePick(ab) && !this.hasDeadAllyHero()) {
      return done([{ t: 'muted', text: 'N/a' }]);
    }

    const allySeg = (idx: number | null): HeroTargetLineSegment | null => {
      if (idx == null) return null;
      const t = heroes[idx];
      if (!t) return null;
      if (idx === hi) return { t: 'self', text: 'Self' };
      return { t: 'ally', text: this.displayTargetName(t.name) };
    };

    /** Glacial Lattice: show ally/enemy name after pick; nk is only 'freezeDice' while unpicked. */
    if (this.needsFreezeDicePick(ab)) {
      if (h.freezeDiceTgtHeroIdx != null) {
        const s = allySeg(h.freezeDiceTgtHeroIdx);
        if (s) return done([s]);
      }
      if (h.freezeDiceTgtEnemyIdx != null) {
        const ex = enemies[h.freezeDiceTgtEnemyIdx];
        if (ex && !ex.dead) return done([{ t: 'enemy', text: this.displayTargetName(ex.name) }]);
      }
      return done([{ t: 'muted', text: '—' }]);
    }

    if (nk === 'enemy') {
      const ei = h.lockedTarget;
      const e = ei != null ? enemies[ei] : null;
      if (ei === undefined || ei === null || !e || e.dead) {
        return done([{ t: 'muted', text: '—' }]);
      }
      return done([{ t: 'enemy', text: this.displayTargetName(e.name) }]);
    }
    if (nk === 'shield') {
      const s = allySeg(h.shTgtIdx);
      if (!s) return done([{ t: 'muted', text: '—' }]);
      if ((ab.dmg || 0) > 0 && (ab.blastAll || ab.multiHit)) {
        return done([
          s,
          { t: 'plain', text: ' · ' },
          { t: 'all', text: ALL_TARGETS_LABEL },
        ]);
      }
      return done([s]);
    }
    if (nk === 'heal') {
      const s = allySeg(h.healTgtIdx);
      if (!s) return done([{ t: 'muted', text: '—' }]);
      if ((ab.dmg || 0) > 0 && (ab.blastAll || ab.multiHit)) {
        return done([
          s,
          { t: 'plain', text: ' · ' },
          { t: 'all', text: ALL_TARGETS_LABEL },
        ]);
      }
      return done([s]);
    }
    if (nk === 'rollBuff') {
      const s = allySeg(h.rfmTgtIdx);
      if (!s) return done([{ t: 'muted', text: '—' }]);
      return done([s]);
    }
    if (nk === 'revive') {
      if (h.reviveTgtIdx == null) return done([{ t: 'muted', text: '—' }]);
      const t = heroes[h.reviveTgtIdx];
      return done([{ t: 'ally', text: t ? this.displayTargetName(t.name) : '?' }]);
    }

    const bits: HeroTargetLineSegment[] = [];
    if (this.needsAllyShieldPick(ab) && h.shTgtIdx != null) {
      const s = allySeg(h.shTgtIdx);
      if (s) bits.push(s);
    }
    if (this.needsAllyHealPick(ab) && h.healTgtIdx != null) {
      const s = allySeg(h.healTgtIdx);
      if (s) bits.push(s);
    }
    if (this.needsAllyRollBuffPick(ab) && h.rfmTgtIdx != null) {
      const s = allySeg(h.rfmTgtIdx);
      if (s) bits.push(s);
    }
    if (this.needsEnemyPick(ab) && h.lockedTarget != null) {
      const e = enemies[h.lockedTarget];
      if (e && !e.dead) bits.push({ t: 'enemy', text: this.displayTargetName(e.name) });
    }
    if ((ab.dmg || 0) > 0 && (ab.blastAll || ab.multiHit) && !this.needsEnemyPick(ab)) {
      bits.push({ t: 'all', text: ALL_TARGETS_LABEL });
    }
    if (
      (ab.heal || 0) > 0 &&
      !ab.healTgt &&
      !ab.healAll &&
      !ab.healLowest &&
      this.needsEnemyPick(ab)
    ) {
      bits.push({ t: 'self', text: `heal self ${ab.heal}` });
    }
    if (this.needsRevivePick(ab) && h.reviveTgtIdx != null) {
      const t = heroes[h.reviveTgtIdx];
      if (t) bits.push({ t: 'ally', text: this.displayTargetName(t.name) });
    }

    if (bits.length) {
      const joined: HeroTargetLineSegment[] = [];
      bits.forEach((b, i) => {
        if (i > 0) joined.push({ t: 'plain', text: ' · ' });
        joined.push(b);
      });
      return done(joined);
    }

    if (!h.confirmed) return done([{ t: 'muted', text: '—' }]);
    return done([{ t: 'muted', text: '—' }]);
  }

  /** Enemy card target line — same segment model as {@link getHeroTargetLineView}. */
  getEnemyTargetLineView(ei: number): HeroTargetLineView {
    const enemies = this.state.enemies();
    const heroes = this.state.heroes();
    const e = enemies[ei];
    const done = (body: HeroTargetLineSegment[]): HeroTargetLineView => ({
      segments: [{ t: 'plain', text: 'Target: ' }, ...body],
    });
    if (!e || e.dead) return done([{ t: 'muted', text: '—' }]);
    const tgt = e.targeting;
    if (!tgt) return done([{ t: 'muted', text: '—' }]);
    const hero = heroes.find(h => h.id === tgt);
    if (!hero) return done([{ t: 'muted', text: '—' }]);
    return done([{ t: 'ally', text: this.displayTargetName(hero.name) }]);
  }

  // ── Private helpers ──

  /** Card “Target:” line — keep first token only so long names fit the UI. */
  private displayTargetName(fullName: string): string {
    const t = fullName.trim();
    if (!t) return fullName;
    return t.split(/\s+/)[0]!;
  }

  private logHeroLockIn(hi: number): void {
    const h = this.state.heroes()[hi];
    if (!h || h._actionLogged) return;
    const ab = this.dice.getAbilityOrNull(h);
    if (!ab) return;
    this.state.updateHero(hi, { _actionLogged: true });
    if (ab.zone === 'recharge' && h.id === 'pulse') return;
    this.log.log(`▸ ${h.name} → ${ab.name} [${this.dice.effRoll(h)}]`, 'pl');
  }

  private recordEvoRollIfNeeded(hi: number): void {
    const h = this.state.heroes()[hi];
    if (!h || h.tier !== 1 || !h.confirmed || h._evoRollRecorded) return;
    const er = this.dice.effRoll(h);
    if (er === null) return;
    const bRolls = [...(h.bRolls || []), er];
    this.state.updateHero(hi, { bRolls, _evoRollRecorded: true });
  }
}
