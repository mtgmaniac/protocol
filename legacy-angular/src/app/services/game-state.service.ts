import { Injectable, computed, inject, signal } from '@angular/core';
import { HeroState } from '../models/hero.interface';
import { EnemyState } from '../models/enemy.interface';
import { LogEntry, PendingEvolution, TutorialState } from '../models/game-state.interface';
import { BattleModeId, GamePhase, HeroId, LogClass, LogMode, ProtocolAction } from '../models/types';
import { tickStacks } from '../utils/stack.utils';
import type { PendingItemSelection } from '../models/item.interface';
import { battleCountForMode, battleModeConfig, DEFAULT_BATTLE_MODE } from '../data/battle-modes.data';
import { HeroStateService } from './hero-state.service';
import { EnemyStateService } from './enemy-state.service';

const SOUND_PREF_KEY = 'overload-sound-on';

function readSoundPref(): boolean {
  if (typeof localStorage === 'undefined') return true;
  const v = localStorage.getItem(SOUND_PREF_KEY);
  if (v === null) return true;
  return v === '1' || v === 'true';
}

/** One enemy-applied squad roll debuff application; expires independently. */
export type SquadRfmStack = { amt: number; turnsLeft: number };

@Injectable({ providedIn: 'root' })
export class GameStateService {
  private readonly heroState = inject(HeroStateService);
  private readonly enemyState = inject(EnemyStateService);

  // ── Hero signal pass-throughs (callers can read and .update()/.set() directly) ──
  readonly heroes = this.heroState.heroes;
  readonly allHeroesRolled = this.heroState.allHeroesRolled;
  readonly allHeroesReady = this.heroState.allHeroesReady;
  readonly livingHeroes = this.heroState.livingHeroes;
  readonly anyHeroAlive = this.heroState.anyHeroAlive;
  readonly allHeroesConfirmed = this.heroState.allHeroesConfirmed;

  // ── Enemy signal pass-throughs ──
  readonly enemies = this.enemyState.enemies;
  readonly livingEnemies = this.enemyState.livingEnemies;
  readonly anyEnemyAlive = this.enemyState.anyEnemyAlive;
  readonly forcedEnemyTargetIdx = this.enemyState.forcedEnemyTargetIdx;
  readonly tauntHeroId = this.enemyState.tauntHeroId;
  readonly tauntEnemyIdx = this.enemyState.tauntEnemyIdx;

  // ── Battle-level signals ──
  /** Which operation / battle track is active (facility, hive, …). */
  readonly battleModeId = signal<BattleModeId>(DEFAULT_BATTLE_MODE);
  /** Full reset + pick mode before heroes spawn. */
  readonly showOperationPicker = signal(true);
  readonly battle = signal(0);
  readonly phase = signal<GamePhase>('player');
  readonly target = signal(0);
  readonly log = signal<LogEntry[]>([]);
  /** Independent stacks — sum of `amt` is the raw d20 penalty while any stack lives. */
  readonly squadRfmStacks = signal<SquadRfmStack[]>([]);
  readonly pendingEvolutions = signal<PendingEvolution[]>([]);
  readonly logMode = signal<LogMode>('min');
  readonly logOpen = signal(false);
  readonly animOn = signal(true);
  /** Procedural SFX (Web Audio); persisted like other UI prefs. */
  readonly soundOn = signal(readSoundPref());
  readonly tutorial = signal<TutorialState | null>(null);
  readonly protocol = signal(0);
  readonly selectedHeroIdx = signal<number | null>(null);
  readonly pendingProtocol = signal<ProtocolAction>(null);
  /** Up to 3 stashed item ids; null = empty slot (persists across battles in a run). */
  readonly inventory = signal<(string | null)[]>([null, null, null]);
  /** After winning a battle, pick one of these item ids (then cleared); skipped if inventory is full. */
  readonly itemDraftChoices = signal<string[] | null>(null);
  /** Active relic ids for this run (max 1 under current design; array for future expansion). */
  readonly relics = signal<string[]>([]);
  /** The two relic ids shown in the mid-run relic draft overlay; null = draft not active. */
  readonly relicDraftChoices = signal<string[] | null>(null);
  /** Gear id awaiting hero assignment; null = no gear draft in progress. */
  readonly pendingGearAssignment = signal<string | null>(null);
  /** Using a consumable: pick target on board. */
  readonly pendingItemSelection = signal<PendingItemSelection | null>(null);
  readonly rollAllInProgress = signal(false);
  readonly rollAnimInProgress = signal(false);
  readonly squadDiceSettling = signal(false);
  readonly squadSettleHeroIdx = signal<number | null>(null);
  readonly enemyDiceSettling = signal(false);
  readonly enemyTrayRevealed = signal(false);
  /**
   * During END TURN resolution: heroes with index < this value have already applied abilities.
   * Used so enemy "Incoming" debuff/dmg previews drop in sync with "Status" as each hero resolves.
   */
  readonly endTurnHeroResolveCursor = signal<number | null>(null);

  /**
   * After a cursed roll resolves: both dice stay visible briefly; the higher (discarded) die is removed after 2s.
   */
  readonly cursedRollShowcase = signal<{
    heroIdx: number;
    low: number;
    high: number;
  } | null>(null);
  private cursedShowcaseTimer: ReturnType<typeof setTimeout> | null = null;

  beginCursedRollShowcase(heroIdx: number, low: number, high: number): void {
    if (this.cursedShowcaseTimer) {
      clearTimeout(this.cursedShowcaseTimer);
      this.cursedShowcaseTimer = null;
    }
    this.cursedRollShowcase.set({ heroIdx, low, high });
    this.cursedShowcaseTimer = setTimeout(() => {
      this.cursedShowcaseTimer = null;
      this.cursedRollShowcase.set(null);
    }, 2000);
  }

  private clearCursedRollShowcaseTimers(): void {
    if (this.cursedShowcaseTimer) {
      clearTimeout(this.cursedShowcaseTimer);
      this.cursedShowcaseTimer = null;
    }
    this.cursedRollShowcase.set(null);
  }

  // ── Overlay signals ──
  readonly showOverlay = signal(false);
  readonly overlayTitle = signal('');
  readonly overlaySub = signal('');
  readonly overlayBtnText = signal('');
  readonly overlayBtnAction = signal<(() => void) | null>(null);
  readonly overlayIsVictory = signal(false);

  // ── Computed signals ──
  readonly battleCountTotal = computed(() => battleCountForMode(this.battleModeId()));

  readonly battleModeLabel = computed(() => battleModeConfig(this.battleModeId()).label);

  readonly isPlayerPhase = computed(() =>
    this.phase() === 'player'
  );

  /** Total −d20 applied to raw squad rolls from enemy abilities. */
  readonly squadRfmPenalty = computed(() =>
    this.squadRfmStacks().reduce((s, x) => s + x.amt, 0),
  );

  // ── Hero method pass-throughs ──

  /** Squad-wide + this hero's rust (etc.) stacks — raw d20 penalty for one hero's roll. */
  combinedHeroRawRfmPenalty(heroIndex: number): number {
    return this.squadRfmPenalty() + this.heroRfmPenaltyFor(heroIndex);
  }

  heroRfmPenaltyFor(heroIndex: number): number {
    return this.heroState.heroRfmPenaltyFor(heroIndex);
  }

  updateHero(index: number, patch: Partial<HeroState>): void {
    this.heroState.updateHero(index, patch);
  }

  resetHeroForNewRound(index: number): void {
    this.heroState.resetHeroForNewRound(index);
  }

  pushHeroRfmStack(heroIndex: number, amt: number, turns: number): void {
    this.heroState.pushHeroRfmStack(heroIndex, amt, turns);
  }

  tickHeroRfmStacksForEndOfPlayerRound(): void {
    this.heroState.tickHeroRfmStacksForEndOfPlayerRound();
  }

  clearAllHeroRfmStacks(): void {
    this.heroState.clearAllHeroRfmStacks();
  }

  pick3(): HeroState[] {
    return this.heroState.pick3();
  }

  initHeroes(partyIds?: HeroId[]): void {
    this.heroState.initHeroes(partyIds);
  }

  // ── Enemy method pass-throughs ──

  updateEnemy(index: number, patch: Partial<EnemyState>): void {
    this.enemyState.updateEnemy(index, patch);
  }

  appendEnemy(enemy: EnemyState): void {
    this.enemyState.appendEnemy(enemy);
  }

  replaceEnemy(index: number, enemy: EnemyState): void {
    this.enemyState.replaceEnemy(index, enemy);
  }

  // ── Squad RFM stacks ──

  pushSquadRfmStack(amt: number, turns: number): void {
    const t = Math.max(1, Math.round(turns));
    const a = Math.max(1, Math.round(amt));
    this.squadRfmStacks.update(st => [...st, { amt: a, turnsLeft: t }]);
  }

  /** Call once per player END TURN after rolls for that round (same moment as enemy rfe tick). */
  tickSquadRfmStacksForEndOfPlayerRound(): void {
    this.squadRfmStacks.update(st => tickStacks(st));
  }

  clearSquadRfmStacks(): void {
    this.squadRfmStacks.set([]);
  }

  // ── Log ──

  addLog(msg: string, cls: LogClass = ''): void {
    this.log.update(log => [{ msg, cls }, ...log]);
  }

  toggleSound(): void {
    this.soundOn.update(v => !v);
    if (typeof localStorage !== 'undefined') {
      localStorage.setItem(SOUND_PREF_KEY, this.soundOn() ? '1' : '0');
    }
  }

  // ── Reset ──

  reset(): void {
    this.battle.set(0);
    this.phase.set('player');
    this.heroState.reset();
    this.enemyState.reset();
    this.target.set(0);
    this.log.set([]);
    this.squadRfmStacks.set([]);
    this.pendingEvolutions.set([]);
    this.tutorial.set(null);
    this.protocol.set(0);
    this.selectedHeroIdx.set(null);
    this.pendingProtocol.set(null);
    this.inventory.set([null, null, null]);
    this.itemDraftChoices.set(null);
    this.relics.set([]);
    this.relicDraftChoices.set(null);
    this.pendingGearAssignment.set(null);
    this.pendingItemSelection.set(null);
    this.rollAllInProgress.set(false);
    this.rollAnimInProgress.set(false);
    this.squadDiceSettling.set(false);
    this.squadSettleHeroIdx.set(null);
    this.enemyDiceSettling.set(false);
    this.enemyTrayRevealed.set(false);
    this.endTurnHeroResolveCursor.set(null);
    this.showOverlay.set(false);
    this.clearCursedRollShowcaseTimers();
  }
}
