import { Injectable, computed, signal } from '@angular/core';
import { HeroState, HeroRfmStack, createHeroState } from '../models/hero.interface';
import { HeroId } from '../models/types';
import { HeroContentService } from './hero-content.service';
import { PortraitPreloadService } from './portrait-preload.service';
import { tickStacks } from '../utils/stack.utils';

@Injectable({ providedIn: 'root' })
export class HeroStateService {
  constructor(
    private readonly heroContent: HeroContentService,
    private readonly portraitPreload: PortraitPreloadService,
  ) {}

  readonly heroes = signal<HeroState[]>([]);

  // ── Computed signals ──

  readonly allHeroesRolled = computed(() =>
    this.heroes().every(
      h =>
        h.currentHp <= 0 ||
        h.roll !== null ||
        ((h.cowerTurns || 0) > 0 && h.roll === null),
    )
  );

  readonly allHeroesReady = computed(() =>
    this.heroes().every(h => {
      if (h.currentHp <= 0) return true;
      if ((h.cowerTurns || 0) > 0 && h.roll === null) return true;
      return h.roll !== null && h.confirmed;
    })
  );

  readonly livingHeroes = computed(() =>
    this.heroes().filter(h => h.currentHp > 0)
  );

  readonly anyHeroAlive = computed(() =>
    this.heroes().some(h => h.currentHp > 0)
  );

  readonly allHeroesConfirmed = computed(() =>
    this.heroes().every(h => h.currentHp <= 0 || h.confirmed)
  );

  heroRfmPenaltyFor(heroIndex: number): number {
    const h = this.heroes()[heroIndex];
    const st = h?.heroRfmStacks;
    if (!st?.length) return 0;
    return st.reduce((s, x) => s + x.amt, 0);
  }

  // ── Mutation methods ──

  updateHero(index: number, patch: Partial<HeroState>): void {
    this.heroes.update(heroes =>
      heroes.map((h, i) => i === index ? { ...h, ...patch } : h)
    );
  }

  resetHeroForNewRound(index: number): void {
    const h = this.heroes()[index];
    if (!h) return;
    const mergedBuff = (h.rollBuff || 0) + (h.pendingRollBuff || 0);
    const mergedT = Math.max(h.rollBuffT || 0, h.pendingRollBuffT || 0);
    const keepFrozenRoll =
      (h.dieFreezeRollsRemaining || 0) > 0 && h.roll !== null && h.currentHp > 0;
    this.updateHero(index, {
      roll: keepFrozenRoll ? h.roll : null,
      rawRoll: keepFrozenRoll ? h.rawRoll : null,
      rollNudge: 0,
      rollBuff: mergedBuff,
      rollBuffT: mergedBuff > 0 ? mergedT : 0,
      pendingRollBuff: 0,
      pendingRollBuffT: 0,
      confirmed: false,
      lockedTarget: undefined,
      shTgtIdx: null,
      healTgtIdx: null,
      rfmTgtIdx: null,
      reviveTgtIdx: null,
      freezeDiceTgtHeroIdx: null,
      freezeDiceTgtEnemyIdx: null,
      noRR: false,
      splitAlloc: {},
      _evoRollRecorded: false,
      _actionLogged: false,
    });
  }

  // ── RFM stacks ──

  pushHeroRfmStack(heroIndex: number, amt: number, turns: number): void {
    const t = Math.max(1, Math.round(turns));
    const a = Math.max(1, Math.round(amt));
    this.heroes.update(heroes =>
      heroes.map((h, i) =>
        i !== heroIndex
          ? h
          : { ...h, heroRfmStacks: [...(h.heroRfmStacks || []), { amt: a, turnsLeft: t } satisfies HeroRfmStack] },
      ),
    );
  }

  /** Same cadence as squad rfm tick — end of player round after that round's rolls resolved. */
  tickHeroRfmStacksForEndOfPlayerRound(): void {
    this.heroes.update(heroes =>
      heroes.map(h => ({
        ...h,
        heroRfmStacks: tickStacks(h.heroRfmStacks || []),
      })),
    );
  }

  clearAllHeroRfmStacks(): void {
    this.heroes.update(heroes => heroes.map(h => ({ ...h, heroRfmStacks: [] })));
  }

  // ── Initialization ──

  pick3(): HeroState[] {
    const pool = [...this.heroContent.heroes()];
    const picked: HeroState[] = [];
    while (picked.length < 3 && pool.length > 0) {
      const idx = Math.floor(Math.random() * pool.length);
      picked.push(createHeroState(pool.splice(idx, 1)[0]));
    }
    return picked;
  }

  initHeroes(partyIds?: HeroId[]): void {
    let heroes: HeroState[];
    if (partyIds) {
      const defs = this.heroContent.heroes();
      heroes = partyIds
        .map(id => defs.find(h => h.id === id))
        .filter((h): h is (typeof defs)[number] => !!h)
        .map(h => createHeroState(h));
      this.heroes.set(heroes);
    } else {
      heroes = this.pick3();
      this.heroes.set(heroes);
    }
    this.portraitPreload.warmHeroPortraits(heroes);
  }

  reset(): void {
    this.heroes.set([]);
  }
}
