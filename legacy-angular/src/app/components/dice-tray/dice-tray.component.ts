import {
  Component,
  ChangeDetectionStrategy,
  inject,
  computed,
  signal,
  output,
  viewChildren,
  afterNextRender,
  DestroyRef,
} from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { GameStateService } from '../../services/game-state.service';
import { DiceService } from '../../services/dice.service';
import { CombatService, type ComputedRollAllPayload } from '../../services/combat.service';
import { ProtocolService } from '../../services/protocol.service';
import {
  RerollAnimationRequestService,
  RerollAnimationPayload,
} from '../../services/reroll-animation-request.service';
import { HeroState } from '../../models/hero.interface';
import { EnemyState } from '../../models/enemy.interface';
import { DieComponent } from './die/die.component';
import { D20_ROLL_CELLS } from './die/d20-sprite';
import { TutorialService } from '../../services/tutorial.service';
import { SoundService } from '../../services/sound.service';

const ANIM_TICK_MS = 72;
const PIXEL_SNAP = 4;
const ANIM_STEPS = 8;
const ANIM_REVEAL_STEP = 6;
/** Horizontal drift during tumble (px), applied via translateX on the die only — grid cells stay fixed. */
const ROLL_DRIFT_TOTAL = 43;

@Component({
  selector: 'app-dice-tray',
  standalone: true,
  imports: [DieComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './dice-tray.component.html',
  styleUrl: './dice-tray.component.scss',
})
export class DiceTrayComponent {
  state = inject(GameStateService);
  private dice = inject(DiceService);
  combat = inject(CombatService);
  private protocol = inject(ProtocolService);
  tutorial = inject(TutorialService);
  private rerollRequests = inject(RerollAnimationRequestService);
  private destroyRef = inject(DestroyRef);
  private sound = inject(SoundService);

  helpClicked = output<void>();

  ANIM_REVEAL_STEP = ANIM_REVEAL_STEP;

  menuOpen = signal(false);

  heroDieRefs = viewChildren<DieComponent>('heroDie');

  /** Cursed: extra die rolls in parallel during tray anim; which slot has the second die. */
  cursedRollingHeroIdx = signal<number | null>(null);
  heroExtraAnimDisplays = signal<(string | null)[]>([]);
  heroExtraAnimSpriteCells = signal<({ c: number; r: number } | null)[]>([]);

  constructor() {
    this.rerollRequests.requests$.pipe(takeUntilDestroyed()).subscribe(p => this.playRerollAnimation(p));

    afterNextRender(() => {
      this.combat.setRollAllDelegate({
        applyAnimated: () => this.runRollAllAsPromise(),
      });
      this.destroyRef.onDestroy(() => this.combat.setRollAllDelegate(null));
    });
  }

  /** Stable id is not enough after evolution — include stats so tray rows reconcile with hero cards. */
  trayHeroTrack(hero: HeroState): string {
    return `${hero.id}:${hero.tier}:${hero.maxHp}:${hero.name}`;
  }

  // ── Animation state ──
  isAnimating = signal(false);
  animStep = signal(0);
  /** Protocol reroll: this slot jitters even though `roll` is already set */
  rerollingHeroIdx = signal<number | null>(null);

  heroAnimDisplays = signal<(string | null)[]>([]);
  enemyAnimDisplays = signal<(string | null)[]>([]);
  heroAnimSpriteCells = signal<({ c: number; r: number } | null)[]>([]);
  enemyAnimSpriteCells = signal<({ c: number; r: number } | null)[]>([]);

  /**
   * Horizontal drift (px) on the die+frost wrapper only. Frozen slots always 0 — columns never leave the grid.
   */
  heroDriftPx = signal<number[]>([]);
  enemyDriftPx = signal<number[]>([]);

  /**
   * Frost overlay from game state: pending freeze skips, or just consumed freeze (enemy skips action this phase).
   * Stays through roll animation and until that enemy finishes their skipped enemy-phase action.
   */
  enemyDieFrostVisible = computed(() =>
    this.state.enemies().map(e => !e.dead && (e.dieFreezeRollsRemaining || 0) > 0),
  );

  heroDieFrostVisible = computed(() =>
    this.state.heroes().map(h => h.currentHp > 0 && (h.dieFreezeRollsRemaining || 0) > 0),
  );

  /** Match enemy-zone: hide enemy faces until squad is fully rolled, tray is revealed, and roll-all anim finished (not solo reroll). */
  hideEnemyRolls = computed(() => {
    if (!this.state.isPlayerPhase()) return false;
    if (!this.state.allHeroesRolled()) return true;
    if (this.isAnimating() && this.rerollingHeroIdx() === null) return true;
    return !this.state.enemyTrayRevealed();
  });

  /** Green pulse on END TURN only when squad is fully targeted (same gate as enabling the button). */
  endTurnReadyGlow = computed(
    () =>
      this.state.allHeroesReady() &&
      this.state.phase() === 'player' &&
      !this.isAnimating() &&
      !this.tutorial.tutorialModalOpen(),
  );

  // ── Roll animation ──

  onRollAll(): void {
    if (this.state.phase() !== 'player' || this.state.rollAllInProgress() || this.isAnimating()) return;
    this.sound.resume();

    const payload = this.combat.computeRollAllPresets();
    if (!payload) return;

    const heroes = this.state.heroes();
    const enemies = this.state.enemies();

    this.runMultiDieAnimation({
      heroes,
      enemies,
      heroRolls: payload.heroRolls,
      enemyRolls: payload.enemyRolls,
      rerollHeroIdx: null,
      progressFlag: 'rollAll',
      onFinished: () => this.combat.applyRollAllPayload(payload),
    });
  }

  /** Sim Battle (animations on): await until ROLL ALL tray animation finishes and state is applied. */
  runRollAllAsPromise(): Promise<void> {
    if (this.state.phase() !== 'player' || this.state.rollAllInProgress() || this.isAnimating()) {
      return Promise.resolve();
    }
    this.sound.resume();
    const payload = this.combat.computeRollAllPresets();
    if (!payload) return Promise.resolve();

    return new Promise<void>(resolve => {
      this.runMultiDieAnimation({
        heroes: this.state.heroes(),
        enemies: this.state.enemies(),
        heroRolls: payload.heroRolls,
        enemyRolls: payload.enemyRolls,
        rerollHeroIdx: null,
        progressFlag: 'rollAll',
        onFinished: () => {
          this.combat.applyRollAllPayload(payload);
          resolve();
        },
      });
    });
  }

  private playRerollAnimation(p: RerollAnimationPayload): void {
    if (this.state.phase() !== 'player' || this.isAnimating()) return;
    this.sound.resume();
    const rolled = this.protocol.drawRerollForAnimation(p.heroIdx);
    if (!rolled) return;
    const heroes = this.state.heroes();
    const enemies = this.state.enemies();
    const hi = p.heroIdx;

    this.runMultiDieAnimation({
      heroes,
      enemies,
      heroRolls: [{ heroIdx: hi, finalRoll: rolled.displayRoll }],
      enemyRolls: [],
      rerollHeroIdx: hi,
      progressFlag: 'rollAnim',
      onFinished: () => {
        this.protocol.commitReroll(hi, rolled.rawRoll, rolled.displayRoll);
        this.combat.clearAndAutoTarget(hi);
      },
    });
  }

  private runMultiDieAnimation(args: {
    heroes: HeroState[];
    enemies: EnemyState[];
    heroRolls: ComputedRollAllPayload['heroRolls'];
    enemyRolls: ComputedRollAllPayload['enemyRolls'];
    rerollHeroIdx: number | null;
    progressFlag: 'rollAll' | 'rollAnim';
    onFinished: () => void;
  }): void {
    const { heroes, enemies, heroRolls, enemyRolls, rerollHeroIdx, progressFlag, onFinished } = args;
    if (this.isAnimating()) return;

    this.sound.resume();
    this.isAnimating.set(true);
    this.rerollingHeroIdx.set(rerollHeroIdx);
    if (progressFlag === 'rollAll') this.state.rollAllInProgress.set(true);
    else this.state.rollAnimInProgress.set(true);

    this.cursedRollingHeroIdx.set(heroRolls.find(hr => hr.cursedPair)?.heroIdx ?? null);

    const rollingHeroSet = new Set(heroRolls.map(r => r.heroIdx));
    const rollingEnemySet = new Set(enemyRolls.map(r => r.enemyIdx));
    /** Snapshot: frozen dice never get tumble drift or sprite strip (roll-all or solo reroll). */
    const frozenEnemySet = new Set<number>();
    const frozenHeroSet = new Set<number>();
    enemies.forEach((e, i) => {
      if (!e.dead && (e.dieFreezeRollsRemaining || 0) > 0) frozenEnemySet.add(i);
    });
    heroes.forEach((h, i) => {
      if (h.currentHp > 0 && (h.dieFreezeRollsRemaining || 0) > 0) frozenHeroSet.add(i);
    });

    let step = 0;

    const interval = setInterval(() => {
      step++;
      this.animStep.set(step);

      const heroDisplays: (string | null)[] = heroes.map(() => null);
      const enemyDisplays: (string | null)[] = enemies.map(() => null);
      const heroSprites: ({ c: number; r: number } | null)[] = heroes.map(() => null);
      const enemySprites: ({ c: number; r: number } | null)[] = enemies.map(() => null);
      const heroExtraDisplays: (string | null)[] = heroes.map(() => null);
      const heroExtraSprites: ({ c: number; r: number } | null)[] = heroes.map(() => null);

      if (step < ANIM_REVEAL_STEP) {
        const rollPhaseSpan = ANIM_REVEAL_STEP - 1;
        const rollProgress = rollPhaseSpan > 0 ? (step - 1) / rollPhaseSpan : 0;
        const fi = Math.min(
          D20_ROLL_CELLS.length - 1,
          Math.round(rollProgress * (D20_ROLL_CELLS.length - 1)),
        );
        const [sc, sr] = D20_ROLL_CELLS[fi];
        const cell = { c: sc, r: sr };
        for (const hr of heroRolls) {
          heroDisplays[hr.heroIdx] = null;
          heroSprites[hr.heroIdx] = cell;
          if (hr.cursedPair) {
            heroExtraSprites[hr.heroIdx] = cell;
          }
        }
        frozenHeroSet.forEach(fi => {
          heroDisplays[fi] = null;
          heroSprites[fi] = null;
        });
        for (const er of enemyRolls) {
          enemyDisplays[er.enemyIdx] = null;
          enemySprites[er.enemyIdx] = cell;
        }
        frozenEnemySet.forEach(fi => {
          enemyDisplays[fi] = null;
          enemySprites[fi] = null;
        });

        const drift = this.snapTrayPx(rollProgress * ROLL_DRIFT_TOTAL);
        const hDrift = heroes.map((h, i) => {
          if (h.currentHp <= 0) return 0;
          if (frozenHeroSet.has(i)) return 0;
          return rollingHeroSet.has(i) ? drift : 0;
        });
        const eDrift = enemies.map((e, i) => {
          if (e.dead) return 0;
          if (frozenEnemySet.has(i)) return 0;
          return rollingEnemySet.has(i) ? drift : 0;
        });
        this.heroDriftPx.set(hDrift);
        this.enemyDriftPx.set(eDrift);
      } else {
        for (const hr of heroRolls) {
          const hx = heroes[hr.heroIdx];
          const eff = Math.min(
            20,
            hr.finalRoll + (hx.rollBuff || 0) + (hx.rollNudge || 0),
          );
          heroDisplays[hr.heroIdx] = String(eff);
          if (hr.cursedPair) {
            const effHigh = Math.min(
              20,
              hr.cursedPair.high + (hx.rollBuff || 0) + (hx.rollNudge || 0),
            );
            heroExtraDisplays[hr.heroIdx] = String(effHigh);
          }
        }
        frozenHeroSet.forEach(fi => {
          heroDisplays[fi] = null;
        });
        for (const er of enemyRolls) {
          enemyDisplays[er.enemyIdx] = String(er.displayEff);
        }
        frozenEnemySet.forEach(fi => {
          enemyDisplays[fi] = null;
        });

        this.heroDriftPx.set(heroes.map(() => 0));
        this.enemyDriftPx.set(enemies.map(() => 0));

        if (step === ANIM_REVEAL_STEP) {
          this.sound.playRollReveal();
          const dieRefs = this.heroDieRefs();
          for (const hr of heroRolls) {
            dieRefs[hr.heroIdx]?.triggerBounce();
          }
        }
      }

      this.heroAnimDisplays.set(heroDisplays);
      this.enemyAnimDisplays.set(enemyDisplays);
      this.heroAnimSpriteCells.set(heroSprites);
      this.enemyAnimSpriteCells.set(enemySprites);
      this.heroExtraAnimDisplays.set(heroExtraDisplays);
      this.heroExtraAnimSpriteCells.set(heroExtraSprites);

      if (step >= ANIM_STEPS) {
        clearInterval(interval);

        setTimeout(() => {
          this.heroAnimDisplays.set([]);
          this.enemyAnimDisplays.set([]);
          this.heroAnimSpriteCells.set([]);
          this.enemyAnimSpriteCells.set([]);
          this.heroExtraAnimDisplays.set([]);
          this.heroExtraAnimSpriteCells.set([]);
          this.heroDriftPx.set([]);
          this.enemyDriftPx.set([]);
          this.cursedRollingHeroIdx.set(null);
          this.rerollingHeroIdx.set(null);
          this.animStep.set(0);

          onFinished();

          if (progressFlag === 'rollAll') this.state.rollAllInProgress.set(false);
          else this.state.rollAnimInProgress.set(false);
          this.isAnimating.set(false);
        }, 150);
      }
    }, ANIM_TICK_MS);
  }

  onRollHero(i: number): void {
    if (this.isAnimating()) return;
    const presRoll = this.state.heroes().map(h => h.roll);
    const hr = this.combat.computeHeroRollPreset(i);
    if (!hr) return;
    if (hr.cursedPair) {
      this.runMultiDieAnimation({
        heroes: this.state.heroes(),
        enemies: this.state.enemies(),
        heroRolls: [hr],
        enemyRolls: [],
        rerollHeroIdx: i,
        progressFlag: 'rollAnim',
        onFinished: () => this.combat.applyHeroRollPreset(hr, presRoll),
      });
    } else {
      this.sound.resume();
      this.sound.playRollTick();
      this.combat.applyHeroRollPreset(hr, presRoll);
    }
  }

  onEndTurn(): void {
    if (this.isAnimating()) return;
    this.sound.resume();
    this.combat.endTurn();
  }

  canNudge(): boolean {
    return this.protocol.canNudge() && this.state.isPlayerPhase() &&
      this.state.heroes().some(h => {
        if (h.currentHp <= 0 || h.roll === null) return false;
        const eff = Math.min(20, (h.roll || 0) + (h.rollBuff || 0) + (h.rollNudge || 0));
        return eff < 20;
      });
  }

  canReroll(): boolean {
    return this.protocol.canReroll() && this.state.isPlayerPhase() &&
      this.state.heroes().some(h => h.currentHp > 0 && h.roll !== null);
  }

  onNudge(): void {
    this.protocol.startNudge();
  }

  onReroll(): void {
    this.protocol.startReroll();
  }

  simBattle(): void {
    this.menuOpen.set(false);
    void this.combat.runSimBattle();
  }

  readonly canAutoPlay = computed(
    () =>
      this.state.phase() === 'player' &&
      this.state.endTurnHeroResolveCursor() === null &&
      !this.state.rollAllInProgress(),
  );

  autoPlayTurn(): void {
    this.menuOpen.set(false);
    void this.combat.autoPlayTurn();
  }

  backToHome(): void {
    this.menuOpen.set(false);
    this.combat.returnToOperationPicker();
  }

  openHelp(): void {
    this.menuOpen.set(false);
    this.helpClicked.emit();
  }

  /** CSS transform for horizontal drift; grid columns stay fixed. */
  dieDriftStyle(px: number | undefined): string {
    const n = px ?? 0;
    return n === 0 ? 'none' : `translateX(${n}px)`;
  }

  /** Extra die (discarded higher roll): visible during parallel tray anim + 2s post-resolve. */
  cursedExtraDieVisible(heroIdx: number): boolean {
    if (this.cursedRollingHeroIdx() === heroIdx) return true;
    if (
      this.heroExtraAnimDisplays()[heroIdx] != null ||
      this.heroExtraAnimSpriteCells()[heroIdx] != null
    ) {
      return true;
    }
    const s = this.state.cursedRollShowcase();
    return s !== null && s.heroIdx === heroIdx;
  }

  /** Effective face for discarded roll (post-anim static / 2s window). */
  cursedTrayExtraRoll(heroIdx: number): number | null {
    const s = this.state.cursedRollShowcase();
    if (!s || s.heroIdx !== heroIdx) return null;
    const h = this.state.heroes()[heroIdx];
    return Math.min(20, s.high + (h.rollBuff || 0) + (h.rollNudge || 0));
  }

  private snapTrayPx(v: number): number {
    return Math.round(v / PIXEL_SNAP) * PIXEL_SNAP;
  }

  // ── Display helpers ──

  getHeroDisplayText(hero: HeroState, idx: number): string | null {
    const r = this.heroTrayDieRoll(hero, idx);
    return r === null ? null : String(r);
  }

  /** Squad die face (frozen heroes keep the same roll until the skip is consumed). */
  heroTrayDieRoll(hero: HeroState, _idx: number): number | null {
    if (hero.currentHp <= 0 || hero.roll === null) return null;
    return this.dice.effRoll(hero);
  }

  /** Enemy die: keep previous face while frozen. */
  enemyTrayDieRoll(e: EnemyState, idx: number): number | null {
    if (e.dead) return null;
    if (this.enemyDieFrostVisible()[idx]) {
      return (e.effRoll || 0) > 0 ? e.effRoll : null;
    }
    if ((e.effRoll || 0) <= 0) return null;
    if (this.hideEnemyRolls()) return null;
    return e.effRoll;
  }

}
