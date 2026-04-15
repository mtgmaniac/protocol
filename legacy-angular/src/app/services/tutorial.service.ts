import { Injectable, computed, inject } from '@angular/core';
import { GameStateService } from './game-state.service';
import { DiceService } from './dice.service';
import { TutorialUiHighlight } from '../models/game-state.interface';
import { HeroState } from '../models/hero.interface';
import { EnemyState } from '../models/enemy.interface';
import {
  TUTORIAL_INTRO_STEPS,
  TUTORIAL_HERO_ROLLS_R1,
  TUTORIAL_ENEMY_PRE_R1,
} from '../data/tutorial-steps.data';

@Injectable({ providedIn: 'root' })
export class TutorialService {
  private state = inject(GameStateService);
  private dice = inject(DiceService);

  readonly introSteps = TUTORIAL_INTRO_STEPS;

  readonly highlightZone = computed((): TutorialUiHighlight => {
    const t = this.state.tutorial();
    if (!t?.active || t.introComplete || t.showComplete) return null;
    const step = TUTORIAL_INTRO_STEPS[t.introStep];
    return step?.highlight ?? null;
  });

  readonly coachPanelVisible = computed(() => {
    const t = this.state.tutorial();
    if (!t?.active || !t.introComplete || t.showComplete) return false;
    return t.resolutions === 0 && t.coachStep >= 1 && t.coachStep <= 4;
  });

  /**
   * Selectors whose bounding boxes are unioned for the spotlight hole.
   * Order: intro / modals / coach / default.
   */
  readonly spotlightSelectors = computed((): string[] => {
    const t = this.state.tutorial();
    if (!t?.active) return ['#tut-drone-card'];
    if (t.showComplete) {
      return ['#tut-heroes-zone', '#tut-drone-card'];
    }

    if (t.introComplete && t.resolutions === 0) {
      if (t.coachStep === 1) {
        return ['#tut-hero-pulse', '#tut-drone-card', '#tut-die-pulse', '#tut-enemy-die-drone'];
      }
      if (t.coachStep === 2) return ['#tut-hero-shield', '#tut-hero-pulse', '#tut-hero-medic'];
      if (t.coachStep === 3) return ['#tut-hero-medic', '#tut-hero-pulse', '#tut-hero-shield'];
      if (t.coachStep === 4) return ['#tut-main-action'];
    }

    if (!t.introComplete) {
      const h: TutorialUiHighlight = TUTORIAL_INTRO_STEPS[t.introStep]?.highlight ?? null;
      switch (h) {
        case 'enemy':
          return ['#tut-drone-card'];
        case 'heroes':
          return ['#tut-heroes-zone'];
        case 'dice':
          return ['#tut-dice-tray'];
        case 'protocolMeter':
          return ['#tut-protocol-meter'];
        case 'protocolIcons':
          return ['#tut-protocol-primary-icons'];
        case 'mainRoll':
          return ['#tut-main-action'];
        case 'help':
          return ['#tut-help-btn'];
        default:
          return ['#tut-drone-card'];
      }
    }
    return ['#tut-drone-card'];
  });

  readonly tutorialModalOpen = computed(() => {
    const t = this.state.tutorial();
    if (!t?.active) return false;
    if (!t.introComplete) return true;
    if (t.showComplete) return true;
    return false;
  });

  readonly tutorialPointerWall = computed(() => {
    const t = this.state.tutorial();
    if (!t?.active) return false;
    if (!t.introComplete) return true;
    if (t.showComplete) return true;
    return false;
  });

  createInitialState() {
    return {
      active: true,
      introStep: 0,
      introComplete: false,
      resolutions: 0,
      showComplete: false,
      coachStep: 0,
    };
  }

  launch(): void {
    this.state.tutorial.set(this.createInitialState());
  }

  applyBattleTuning(): void {
    const t = this.state.tutorial();
    if (!t?.active) return;
    this.state.enemies.update(es =>
      es.map((e, i) =>
        i === 0 ? { ...e, maxHp: 160, currentHp: 160 } : e,
      ),
    );
    this.state.updateEnemy(0, {
      targeting: 'medic',
      dumbStickyId: 'medic',
    });
  }

  introNext(): void {
    this.state.tutorial.update(t => {
      if (!t?.active || t.introComplete) return t;
      const next = t.introStep + 1;
      if (next >= TUTORIAL_INTRO_STEPS.length) {
        return { ...t, introComplete: true, introStep: t.introStep };
      }
      return { ...t, introStep: next };
    });
  }

  introBack(): void {
    this.state.tutorial.update(t => {
      if (!t?.active || t.introComplete) return t;
      return { ...t, introStep: Math.max(0, t.introStep - 1) };
    });
  }

  /** After END TURN passes validation: clear coach overlay still showing. */
  finishCoachOnEndTurn(): void {
    this.state.tutorial.update(t => {
      if (!t?.active) return t;
      let coachStep = t.coachStep;
      if (t.resolutions === 0 && coachStep === 4) coachStep = 5;
      if (coachStep === t.coachStep) return t;
      return { ...t, coachStep };
    });
  }

  notifyRollAllFinished(): void {
    const t = this.state.tutorial();
    if (!t?.active || !t.introComplete) return;
    if (t.resolutions === 0 && t.coachStep === 0) {
      this.state.tutorial.update(x => (x?.active ? { ...x, coachStep: 1 } : x));
    }
  }

  syncCoachAfterTargeting(): void {
    const t = this.state.tutorial();
    if (!t?.active || !t.introComplete || t.resolutions !== 0) return;
    const heroes = this.state.heroes();
    const enemies = this.state.enemies();

    if (t.coachStep === 1 && this.pulseDamageTargetSatisfied(heroes, enemies)) {
      this.state.tutorial.update(x => (x?.active ? { ...x, coachStep: 2 } : x));
    } else if (t.coachStep === 2 && this.shieldAllyTargetSatisfied(heroes)) {
      this.state.tutorial.update(x => (x?.active ? { ...x, coachStep: 3 } : x));
    } else if (t.coachStep === 3 && this.medicRollBuffTargetSatisfied(heroes)) {
      this.state.tutorial.update(x => (x?.active ? { ...x, coachStep: 4 } : x));
    }
  }

  private pulseDamageTargetSatisfied(heroes: HeroState[], enemies: EnemyState[]): boolean {
    for (let i = 0; i < heroes.length; i++) {
      const h = heroes[i];
      if (h.currentHp <= 0 || h.id !== 'pulse') continue;
      const er = this.dice.effRoll(h);
      if (er === null) continue;
      const ab = this.dice.getAbility(h, er);
      if (!ab || (ab.dmg || 0) <= 0) continue;
      const ei = h.lockedTarget;
      const tgtOk =
        ei !== undefined &&
        ei !== null &&
        enemies[ei] &&
        !enemies[ei].dead;
      return tgtOk;
    }
    return false;
  }

  private shieldAllyTargetSatisfied(heroes: HeroState[]): boolean {
    for (let i = 0; i < heroes.length; i++) {
      const h = heroes[i];
      if (h.currentHp <= 0 || h.id !== 'shield') continue;
      const er = this.dice.effRoll(h);
      if (er === null) continue;
      const ab = this.dice.getAbility(h, er);
      if (!ab || !ab.shTgt || (ab.shield || 0) <= 0) continue;
      return h.shTgtIdx != null;
    }
    return false;
  }

  private medicRollBuffTargetSatisfied(heroes: HeroState[]): boolean {
    for (let i = 0; i < heroes.length; i++) {
      const h = heroes[i];
      if (h.currentHp <= 0 || h.id !== 'medic') continue;
      const er = this.dice.effRoll(h);
      if (er === null) continue;
      const ab = this.dice.getAbility(h, er);
      if (!ab || !ab.rfmTgt || (ab.rfm || 0) <= 0) continue;
      return h.rfmTgtIdx != null;
    }
    return false;
  }

  readonly coachPulseHero = computed(() => this.state.heroes().find(h => h.id === 'pulse'));
  readonly coachShieldHero = computed(() => this.state.heroes().find(h => h.id === 'shield'));
  readonly coachMedicHero = computed(() => this.state.heroes().find(h => h.id === 'medic'));
  readonly coachPulseAbilityName = computed(() => {
    const h = this.coachPulseHero();
    if (!h || h.roll === null) return 'Arc Burst';
    return this.dice.getAbilityOrNull(h)?.name ?? 'Arc Burst';
  });
  readonly coachShieldAbilityName = computed(() => {
    const h = this.coachShieldHero();
    if (!h || h.roll === null) return 'Enforce';
    return this.dice.getAbilityOrNull(h)?.name ?? 'Enforce';
  });
  readonly coachMedicAbilityName = computed(() => {
    const h = this.coachMedicHero();
    if (!h || h.roll === null) return 'Diagnostic Pulse';
    return this.dice.getAbilityOrNull(h)?.name ?? 'Diagnostic Pulse';
  });
  readonly coachMedicRfmValue = computed(() => {
    const h = this.coachMedicHero();
    if (!h || h.roll === null) return 3;
    const ab = this.dice.getAbilityOrNull(h);
    return ab?.rfm ?? 3;
  });

  getHeroRollPreset(heroIdx: number): number | null {
    const t = this.state.tutorial();
    if (!t?.active || !t.introComplete || t.resolutions !== 0) return null;
    const v = TUTORIAL_HERO_ROLLS_R1[heroIdx];
    return v === undefined ? null : v;
  }

  getTutorialEnemyPreRoll(): number | null {
    const t = this.state.tutorial();
    if (!t?.active || !t.introComplete || t.resolutions !== 0) return null;
    return TUTORIAL_ENEMY_PRE_R1;
  }

  validateBeforePlayerResolve(): string | null {
    const t = this.state.tutorial();
    if (!t?.active || !t.introComplete || t.resolutions !== 0) return null;

    const heroes = this.state.heroes();
    const enemies = this.state.enemies();
    const dice = this.dice;

    let hasDmg = false;
    let hasShield = false;
    let hasMedicRfm = false;
    for (let i = 0; i < heroes.length; i++) {
      const h = heroes[i];
      if (h.currentHp <= 0) continue;
      const er = dice.effRoll(h);
      if (er === null) continue;
      const ab = dice.getAbility(h, er);
      if (!ab) continue;
      const ei = h.lockedTarget;
      const tgtOk =
        ei !== undefined &&
        ei !== null &&
        enemies[ei] &&
        !enemies[ei].dead;
      if (h.id === 'pulse' && (ab.dmg || 0) > 0 && tgtOk) hasDmg = true;
      if (h.id === 'shield' && ab.shTgt && (ab.shield || 0) > 0 && h.shTgtIdx != null) hasShield = true;
      if (h.id === 'medic' && ab.rfmTgt && (ab.rfm || 0) > 0 && h.rfmTgtIdx != null) hasMedicRfm = true;
    }
    if (!hasDmg) return 'Tutorial: deal damage to the drone with Pulse Tech (strike roll).';
    if (!hasShield) return 'Tutorial: shield an ally with Spite Guard (strike roll).';
    if (!hasMedicRfm) {
      return 'Tutorial: assign Systems Medic’s +roll (Diagnostic Pulse) to an ally.';
    }
    return null;
  }
}
