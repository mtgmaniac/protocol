import { Injectable } from '@angular/core';
import {
  PROTOCOL_MAX,
  PROTOCOL_ROUND,
  PROTOCOL_REROLL_COST,
  PROTOCOL_NUDGE_COST,
  PROTOCOL_NUDGE_DELTA,
} from '../models/constants';
import { GameStateService } from './game-state.service';
import { DiceService } from './dice.service';

@Injectable({ providedIn: 'root' })
export class ProtocolService {
  constructor(
    private state: GameStateService,
    private dice: DiceService,
  ) {}

  /** Called after END TURN resolves (enemy phase → next player round), not on battle start. */
  grantForNewRound(): void {
    this.state.protocol.update(p => Math.min(PROTOCOL_MAX, p + PROTOCOL_ROUND));
  }

  canReroll(): boolean {
    return this.state.protocol() >= PROTOCOL_REROLL_COST;
  }

  canNudge(): boolean {
    return this.state.protocol() >= PROTOCOL_NUDGE_COST;
  }

  startReroll(): void {
    if (this.state.pendingProtocol() === 'reroll') {
      this.state.pendingProtocol.set(null);
      this.state.selectedHeroIdx.set(null);
      return;
    }
    if (!this.canReroll()) return;
    this.state.pendingItemSelection.set(null);
    this.state.pendingProtocol.set('reroll');
    this.state.selectedHeroIdx.set(null);
  }

  startNudge(): void {
    if (this.state.pendingProtocol() === 'nudge') {
      this.state.pendingProtocol.set(null);
      this.state.selectedHeroIdx.set(null);
      return;
    }
    if (!this.canNudge()) return;
    this.state.pendingItemSelection.set(null);
    this.state.pendingProtocol.set('nudge');
    this.state.selectedHeroIdx.set(null);
  }

  canRerollHero(heroIdx: number): boolean {
    const h = this.state.heroes()[heroIdx];
    return !!(
      h &&
      h.currentHp > 0 &&
      (h.cowerTurns || 0) <= 0 &&
      h.roll !== null &&
      this.state.protocol() >= PROTOCOL_REROLL_COST
    );
  }

  /**
   * One d20 for reroll (after global roll debuff on raw). Stored `roll` is base face; effRoll adds rollBuff/nudge.
   */
  drawRerollForAnimation(heroIdx: number): { rawRoll: number; displayRoll: number } | null {
    if (!this.canRerollHero(heroIdx)) return null;
    let raw = this.dice.d20();
    const rfmPen = this.state.combinedHeroRawRfmPenalty(heroIdx);
    if (rfmPen > 0) raw = Math.max(1, raw - rfmPen);
    const displayRoll = Math.min(20, raw);
    return { rawRoll: raw, displayRoll };
  }

  /** Apply reroll after tray animation (deducts protocol, updates hero). */
  commitReroll(heroIdx: number, rawRoll: number, displayRoll: number): boolean {
    if (this.state.protocol() < PROTOCOL_REROLL_COST) return false;
    this.state.protocol.update(p => p - PROTOCOL_REROLL_COST);
    this.state.updateHero(heroIdx, {
      roll: displayRoll,
      rawRoll,
      rollNudge: 0,
      noRR: true,
      confirmed: false,
      lockedTarget: undefined,
      shTgtIdx: null,
      healTgtIdx: null,
      rfmTgtIdx: null,
      reviveTgtIdx: null,
      splitAlloc: {},
      _evoRollRecorded: false,
      _actionLogged: false,
    });
    return true;
  }

  /** Instant reroll (no animation) — for tests or future use. */
  applyReroll(heroIdx: number): boolean {
    const r = this.drawRerollForAnimation(heroIdx);
    if (!r) return false;
    const ok = this.commitReroll(heroIdx, r.rawRoll, r.displayRoll);
    if (ok) {
      this.state.pendingProtocol.set(null);
      this.state.selectedHeroIdx.set(null);
    }
    return ok;
  }

  /** @returns true if nudge was applied */
  applyNudge(heroIdx: number): boolean {
    const h = this.state.heroes()[heroIdx];
    if (!h || h.currentHp <= 0 || h.roll === null) return false;

    const currentEff = this.dice.effRoll(h);
    if (currentEff === null || currentEff >= 20) return false;
    if (this.state.protocol() < PROTOCOL_NUDGE_COST) return false;

    this.state.protocol.update(p => p - PROTOCOL_NUDGE_COST);

    const newNudge = (h.rollNudge || 0) + PROTOCOL_NUDGE_DELTA;

    this.state.updateHero(heroIdx, {
      rollNudge: newNudge,
      confirmed: false,
      lockedTarget: undefined,
      shTgtIdx: null,
      healTgtIdx: null,
      rfmTgtIdx: null,
      reviveTgtIdx: null,
      splitAlloc: {},
      _evoRollRecorded: false,
      _actionLogged: false,
    });

    this.state.pendingProtocol.set(null);
    this.state.selectedHeroIdx.set(null);
    return true;
  }
}
