import { UpperCasePipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { HeroContentService } from '../../services/hero-content.service';
import { EnemyContentService } from '../../services/enemy-content.service';
import { BattleProgressSimService } from '../../services/battle-progress-sim.service';
import { GameStateService } from '../../services/game-state.service';
import { DevDataPanelService } from '../../services/dev-data-panel.service';
import { HeroDefinition, EvolutionTier } from '../../models/hero.interface';
import { HeroAbility } from '../../models/ability.interface';
import { EnemyAbility, EnemyAbilitySuite } from '../../models/ability.interface';
import { EnemyDefinition } from '../../models/enemy.interface';
import { BattleModeId, EnemyRace, HeroId, Zone, ZONES, EnemyType } from '../../models/types';
import { HERO_PORTRAIT_PATHS } from '../../data/sprites.data';
import { BATTLE_MODE_ORDER, BATTLE_MODES } from '../../data/battle-modes.data';
import { ENEMY_TYPE_TO_RACE } from '../../data/unit-frame-colors';

type BracketRow = { lo: number; hi: number; zone: Zone };

/** Contiguous evolution tiers with the same `name` = one player-facing evolution path. */
interface EvoPathGroup {
  pathName: string;
  indices: number[];
}

function groupEvolutionPaths(evolutions: EvolutionTier[]): EvoPathGroup[] {
  const groups: EvoPathGroup[] = [];
  for (let i = 0; i < evolutions.length; i++) {
    const name = evolutions[i].name;
    const prev = groups[groups.length - 1];
    if (prev && prev.pathName === name && prev.indices[prev.indices.length - 1] === i - 1) {
      prev.indices.push(i);
    } else {
      groups.push({ pathName: name, indices: [i] });
    }
  }
  return groups;
}

const ENEMY_TYPES: EnemyType[] = [
  'scrap',
  'rust',
  'patrol',
  'guard',
  'warden',
  'volt',
  'boss',
  'skitter',
  'mite',
  'stalker',
  'carapace',
  'brood',
  'spewer',
  'hiveBoss',
  'veilShard',
  'veilPrism',
  'veilAegis',
  'veilResonance',
  'veilNull',
  'veilStorm',
  'veilSynapse',
  'veilBoss',
  'voidWisp',
  'voidAcolyte',
  'voidScribe',
  'voidBinder',
  'voidGlimmer',
  'voidChanneler',
  'voidCircletBoss',
  'beastMonkey',
  'beastWolf',
  'beastLynx',
  'beastBison',
  'beastHyena',
  'beastBadger',
  'beastTyrant',
  'signalSkimmer',
  'commsHex',
];

@Component({
  selector: 'app-dev-hero-editor',
  standalone: true,
  imports: [FormsModule, UpperCasePipe],
  templateUrl: './dev-hero-editor.component.html',
  styleUrl: './dev-hero-editor.component.scss',
})
export class DevHeroEditorComponent {
  readonly devPanel = inject(DevDataPanelService);
  readonly content = inject(HeroContentService);
  readonly enemyContent = inject(EnemyContentService);
  private readonly battleSim = inject(BattleProgressSimService);
  private readonly state = inject(GameStateService);

  readonly mainTab = signal<'heroes' | 'enemies'>('heroes');
  readonly tab = signal<'core' | 'zones' | 'evo'>('core');
  readonly selectedId = signal<HeroId>('pulse');

  evoPathIdx = 0;

  draftHero: HeroDefinition | null = null;
  zoneBracketRows: BracketRow[] = [];

  enemyAbilityType: EnemyType = 'scrap';
  /** Operation track bucket for enemy editing (facility / hive / veil / void / menagerie). */
  readonly enemyEditMode = signal<BattleModeId>('facility');
  enemySuiteDraft: EnemyAbilitySuite | null = null;
  enemyUnitKey = '';
  enemyUnitDraft: Omit<EnemyDefinition, 'name'> | null = null;
  battleScaleDraft: { hp: number; dmg: number }[] = [];

  readonly enemyTypes = ENEMY_TYPES;
  readonly battleModeOrder = BATTLE_MODE_ORDER;

  readonly msg = signal('');
  readonly msgIsErr = signal(false);

  simIterations = 1500;
  readonly simRunning = signal(false);
  readonly simJustCopied = signal(false);
  readonly simOutput = signal(
    'Run for reach 1–10 + full clear % per op, and hero representation vs fair squad odds.',
  );

  readonly heroIds = computed(() => this.content.heroes().map(h => h.id));

  readonly enemyTypesInEditMode = computed(() =>
    ENEMY_TYPES.filter(t => this.typeMatchesBattleMode(t, this.enemyEditMode())),
  );

  readonly enemyUnitKeysInEditMode = computed(() =>
    this.sortedUnitKeysForMode(this.enemyContent.enemyUnitDefs(), this.enemyEditMode()),
  );

  readonly zones = ZONES;

  readonly defaultPortrait = computed(() => HERO_PORTRAIT_PATHS[this.selectedId()]);

  constructor() {
    this.reloadDraft();
  }

  evoPathGroups(): EvoPathGroup[] {
    if (!this.draftHero?.evolutions?.length) return [];
    return groupEvolutionPaths(this.draftHero.evolutions);
  }

  selectedEvoGroup(): EvoPathGroup | null {
    const g = this.evoPathGroups();
    if (!g.length) return null;
    const i = Math.max(0, Math.min(g.length - 1, this.evoPathIdx));
    return g[i] ?? null;
  }

  evoLead(grp: EvoPathGroup): EvolutionTier | null {
    const d = this.draftHero;
    if (!d) return null;
    const fi = grp.indices[0];
    return d.evolutions[fi] ?? null;
  }

  syncEvoPathName(newName: string): void {
    const g = this.selectedEvoGroup();
    if (!g || !this.draftHero) return;
    for (const i of g.indices) this.draftHero.evolutions[i].name = newName;
  }

  onMainTabEnemies(): void {
    this.mainTab.set('enemies');
    this.refreshEnemyDrafts();
  }

  battleModeLabel(id: BattleModeId): string {
    return BATTLE_MODES[id]?.label ?? id;
  }

  heroLabel(id: HeroId): string {
    return this.content.getHero(id)?.name ?? id;
  }

  /** First roster spawn name for this enemy type (for readable type picker labels). */
  typeDisplayLabel(t: EnemyType): string {
    const defs = this.enemyContent.enemyUnitDefs();
    const keys = Object.keys(defs)
      .filter(k => defs[k]?.type === t)
      .sort((a, b) => a.localeCompare(b));
    return keys[0] ?? t;
  }

  onEnemyEditModeChange(mode: string): void {
    this.enemyEditMode.set(mode as BattleModeId);
    this.refreshEnemyDrafts();
  }

  private raceMatchesBattleMode(race: EnemyRace, mode: BattleModeId): boolean {
    switch (mode) {
      case 'facility':
        return race === 'facility' || race === 'signal';
      case 'hive':
        return race === 'hive';
      case 'veil':
        return race === 'veil';
      case 'voidCirclet':
        return race === 'void';
      case 'stellarMenagerie':
        return race === 'beast';
      default:
        return false;
    }
  }

  private typeMatchesBattleMode(t: EnemyType, mode: BattleModeId): boolean {
    return this.raceMatchesBattleMode(ENEMY_TYPE_TO_RACE[t], mode);
  }

  private sortedUnitKeysForMode(
    defs: Record<string, Omit<EnemyDefinition, 'name'>>,
    mode: BattleModeId,
  ): string[] {
    return Object.keys(defs)
      .filter(k => {
        const d = defs[k];
        return d && this.typeMatchesBattleMode(d.type, mode);
      })
      .sort((a, b) => a.localeCompare(b));
  }

  refreshEnemyDrafts(): void {
    const mode = this.enemyEditMode();
    const defs = this.enemyContent.enemyUnitDefs();
    const typesInMode = ENEMY_TYPES.filter(t => this.typeMatchesBattleMode(t, mode));
    if (!typesInMode.includes(this.enemyAbilityType)) {
      this.enemyAbilityType = typesInMode[0] ?? 'scrap';
    }
    this.enemySuiteDraft = structuredClone(this.enemyContent.suiteFor(this.enemyAbilityType));
    const keys = this.sortedUnitKeysForMode(defs, mode);
    if (!this.enemyUnitKey || !keys.includes(this.enemyUnitKey)) {
      this.enemyUnitKey = keys[0] ?? '';
    }
    this.enemyUnitDraft = this.enemyUnitKey ? structuredClone(defs[this.enemyUnitKey]) : null;
    this.battleScaleDraft = structuredClone(this.enemyContent.battleEnemyScale());
  }

  evoPathAbilityRows(grp: EvoPathGroup): { tierIdx: number; ab: HeroAbility; abi: number }[] {
    const d = this.draftHero;
    if (!d) return [];
    const rows: { tierIdx: number; ab: HeroAbility; abi: number }[] = [];
    for (const ti of grp.indices) {
      const ev = d.evolutions[ti];
      if (!ev) continue;
      ev.abilities.forEach((ab, abi) => rows.push({ tierIdx: ti, ab, abi }));
    }
    return rows;
  }

  onEnemyTypeChange(t: string): void {
    const et = t as EnemyType;
    this.enemyAbilityType = et;
    this.enemySuiteDraft = structuredClone(this.enemyContent.suiteFor(et));
  }

  onEnemyUnitKeyChange(key: string): void {
    this.enemyUnitKey = key;
    const defs = this.enemyContent.enemyUnitDefs();
    this.enemyUnitDraft = key ? structuredClone(defs[key]) : null;
  }

  commitEnemyData(): void {
    if (this.enemySuiteDraft) this.enemyContent.setSuite(this.enemyAbilityType, this.enemySuiteDraft);
    if (this.enemyUnitDraft && this.enemyUnitKey) this.enemyContent.setUnitDef(this.enemyUnitKey, this.enemyUnitDraft);
    if (this.battleScaleDraft?.length === 10) this.enemyContent.setBattleScale(this.battleScaleDraft);
    this.flash('Enemy definitions updated in memory.', false);
  }

  saveEnemyStorage(): void {
    this.commitEnemyData();
    this.enemyContent.persistToLocalStorage();
    this.flash('Enemies stored in localStorage.', false);
  }

  resetEnemyBundled(): void {
    this.enemyContent.clearLocalAndResetBundled();
    this.refreshEnemyDrafts();
    this.flash('Enemies reset to bundled JSON.', false);
  }

  exportEnemyFile(): void {
    const blob = new Blob([this.enemyContent.exportJson()], { type: 'application/json' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'enemies-dev-export.json';
    a.click();
    URL.revokeObjectURL(a.href);
    this.flash('Enemy export started.', false);
  }

  onImportEnemyFile(ev: Event): void {
    const input = ev.target as HTMLInputElement;
    const file = input.files?.[0];
    input.value = '';
    if (!file) return;
    const r = new FileReader();
    r.onload = () => {
      const res = this.enemyContent.importJson(String(r.result || ''));
      if (res.ok) {
        this.refreshEnemyDrafts();
        this.enemyContent.persistToLocalStorage();
        this.flash('Enemies imported.', false);
      } else {
        this.flash(res.error, true);
      }
    };
    r.readAsText(file);
  }

  setEnemyOptNum(ab: EnemyAbility, key: 'dmgP2' | 'shT' | 'shieldAlly' | 'rfm' | 'rfmT', v: number): void {
    const n = Number(v);
    if (!Number.isFinite(n) || n <= 0) delete ab[key];
    else (ab as unknown as Record<string, number>)[key] = Math.round(n);
  }

  setUnitOptNum(key: 'p2dMin' | 'p2dMax' | 'pThr', v: number): void {
    const d = this.enemyUnitDraft;
    if (!d) return;
    const n = Math.round(Number(v) || 0);
    if (n <= 0) delete d[key];
    else (d as unknown as Record<string, number>)[key] = n;
  }

  onPickHero(id: HeroId): void {
    this.selectedId.set(id);
    this.evoPathIdx = 0;
    this.reloadDraft();
  }

  reloadDraft(): void {
    const id = this.selectedId();
    const h = this.content.getHero(id);
    if (!h) {
      this.draftHero = null;
      this.zoneBracketRows = [];
      return;
    }
    this.draftHero = structuredClone(h) as HeroDefinition;
    const z = this.content.heroZones()[id] ?? [];
    this.zoneBracketRows = z.map(([lo, hi, zone]) => ({ lo, hi, zone }));
    this.evoPathIdx = 0;
    this.flash('Loaded hero draft.', false);
  }

  commitHero(): void {
    const d = this.draftHero;
    if (!d) return;
    const id = this.selectedId();
    const tuples: [number, number, Zone][] = this.zoneBracketRows.map(r => [
      Math.round(Number(r.lo) || 1),
      Math.round(Number(r.hi) || 1),
      r.zone,
    ]);
    this.content.setHeroDefinition(d);
    this.content.setZonesForHero(id, tuples);
    this.flash('Hero saved to in-memory definitions.', false);
  }

  saveHeroStorage(): void {
    this.commitHero();
    this.content.persistToLocalStorage();
    this.flash('Heroes stored in localStorage.', false);
  }

  resetHeroBundled(): void {
    this.content.clearLocalAndResetBundled();
    this.reloadDraft();
    this.flash('Heroes reset to bundled JSON.', false);
  }

  exportHeroFile(): void {
    const blob = new Blob([this.content.exportJson()], { type: 'application/json' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = 'heroes-dev-export.json';
    a.click();
    URL.revokeObjectURL(a.href);
    this.flash('Hero export started.', false);
  }

  onImportHeroFile(ev: Event): void {
    const input = ev.target as HTMLInputElement;
    const file = input.files?.[0];
    input.value = '';
    if (!file) return;
    const r = new FileReader();
    r.onload = () => {
      const res = this.content.importJson(String(r.result || ''));
      if (res.ok) {
        this.reloadDraft();
        this.content.persistToLocalStorage();
        this.flash('Heroes imported.', false);
      } else {
        this.flash(res.error, true);
      }
    };
    r.readAsText(file);
  }

  applySquad(): void {
    this.commitHero();
    const ids = this.state.heroes().map(h => h.id);
    if (ids.length) this.state.initHeroes(ids);
    else this.state.initHeroes();
    this.flash('Squad re-built from definitions.', false);
  }

  randomSquad(): void {
    this.commitHero();
    this.state.initHeroes();
    this.flash('New random 3.', false);
  }

  addBracket(): void {
    this.zoneBracketRows = [...this.zoneBracketRows, { lo: 1, hi: 4, zone: 'recharge' }];
  }

  removeBracket(i: number): void {
    if (this.zoneBracketRows.length <= 1) return;
    this.zoneBracketRows = this.zoneBracketRows.filter((_, j) => j !== i);
  }

  setOptNum(ab: HeroAbility, key: 'rfT' | 'shield' | 'shT' | 'rfm' | 'rfmT', v: number): void {
    const n = Math.round(Number(v) || 0);
    if (n <= 0) delete ab[key];
    else (ab as unknown as Record<string, number | undefined>)[key] = n;
  }

  private flash(text: string, err: boolean): void {
    this.msg.set(text);
    this.msgIsErr.set(err);
  }

  runBattleSim(): void {
    if (this.simRunning()) return;
    this.simRunning.set(true);
    this.simOutput.set('Running…');
    const n = Math.max(50, Math.min(20000, Math.floor(Number(this.simIterations) || 1500)));
    setTimeout(() => {
      try {
        const r = this.battleSim.run(n);
        this.simOutput.set(this.battleSim.format(r));
      } catch (e) {
        this.simOutput.set(e instanceof Error ? e.message : String(e));
      }
      this.simRunning.set(false);
    }, 0);
  }

  async copyBattleSimOutput(): Promise<void> {
    const text = this.simOutput();
    if (!text || text === 'Running…') return;
    try {
      await navigator.clipboard.writeText(text);
      this.simJustCopied.set(true);
      setTimeout(() => this.simJustCopied.set(false), 2000);
    } catch {
      this.flash('Clipboard copy failed', true);
    }
  }
}
