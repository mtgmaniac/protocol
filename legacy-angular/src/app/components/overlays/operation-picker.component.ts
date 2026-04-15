import { Component, ChangeDetectionStrategy, inject, signal, computed, output } from '@angular/core';
import { GameStateService } from '../../services/game-state.service';
import { HeroContentService } from '../../services/hero-content.service';
import { CombatService } from '../../services/combat.service';
import { BATTLE_MODES, BATTLE_MODE_ORDER, battlesForMode } from '../../data/battle-modes.data';
import { enemyPortraitHref } from '../../data/sprites.data';
import { EnemyContentService } from '../../services/enemy-content.service';
import { BUILD_VERSION, BUILD_STAMP } from '../../models/constants';
import type { BattleModeId, HeroId } from '../../models/types';
import type { HeroDefinition, HeroPickerCategory } from '../../models/hero.interface';
import { heroPortraitHref } from '../../data/sprites.data';

@Component({
  selector: 'app-operation-picker',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './operation-picker.component.html',
  styleUrl: './operation-picker.component.scss',
})
export class OperationPickerComponent {
  readonly startTutorial = output<void>();
  readonly helpClicked = output<void>();

  readonly version = BUILD_VERSION;
  readonly stamp = BUILD_STAMP;

  readonly state = inject(GameStateService);
  private readonly combat = inject(CombatService);
  private readonly heroContent = inject(HeroContentService);
  private readonly enemyContent = inject(EnemyContentService);

  readonly modes = BATTLE_MODES;
  readonly modeOrder = BATTLE_MODE_ORDER;

  readonly roster = computed(() => this.heroContent.heroes());

  readonly pickerSectionOrder: readonly HeroPickerCategory[] = ['damage', 'defense', 'support', 'control'];
  readonly pickerSectionLabels: Record<HeroPickerCategory, string> = {
    damage: 'Damage',
    defense: 'Defense',
    support: 'Support',
    control: 'Control',
  };

  readonly heroesByPickerSection = computed(() => {
    const roster = this.roster();
    const buckets = new Map<HeroPickerCategory, HeroDefinition[]>();
    for (const k of this.pickerSectionOrder) buckets.set(k, []);
    for (const h of roster) {
      const list = buckets.get(h.pickerCategory);
      if (list) list.push(h);
    }
    return this.pickerSectionOrder.map(key => ({
      key,
      label: this.pickerSectionLabels[key],
      heroes: buckets.get(key) ?? [],
    }));
  });

  /** Default: roll facility / hive / veil on BEGIN RUN. */
  readonly operationRandom = signal(true);
  readonly squadRandom = signal(true);
  /** Selection order preserved for party slot order. */
  readonly pickedOrder = signal<HeroId[]>([]);

  readonly canBegin = computed(() => {
    if (this.squadRandom()) return true;
    return this.pickedOrder().length === 3;
  });

  setOperationRandom(random: boolean): void {
    this.operationRandom.set(random);
  }

  selectMode(id: BattleModeId): void {
    this.operationRandom.set(false);
    this.state.battleModeId.set(id);
  }

  /** Final encounter’s last spawn (track capstone) for picker thumbnail. */
  trackBossPortraitSrc(id: BattleModeId): string | null {
    const battles = battlesForMode(id);
    const lastBattle = battles[battles.length - 1];
    const spawns = lastBattle?.enemies;
    if (!spawns?.length) return null;
    const spawn = spawns[spawns.length - 1];
    try {
      const def = this.enemyContent.expandFromSpawn(spawn);
      const path = enemyPortraitHref(def.type);
      return path.startsWith('/') ? path : `/${path}`;
    } catch {
      return null;
    }
  }

  setSquadRandom(random: boolean): void {
    this.squadRandom.set(random);
    if (random) this.pickedOrder.set([]);
  }

  isPicked(id: HeroId): boolean {
    return this.pickedOrder().includes(id);
  }

  /** Can click: either already picked (to deselect) or fewer than 3 picked. */
  canToggle(id: HeroId): boolean {
    if (this.isPicked(id)) return true;
    return this.pickedOrder().length < 3;
  }

  /** Raster portrait URL for squad picker thumbnails (same assets as in-battle cards). */
  pickerPortraitSrc(h: HeroDefinition): string {
    const path = heroPortraitHref(h.id, h.portraitPath ?? null);
    return path.startsWith('/') ? path : `/${path}`;
  }

  toggleHero(id: HeroId): void {
    if (this.squadRandom()) return;
    this.pickedOrder.update(arr => {
      const i = arr.indexOf(id);
      if (i >= 0) return arr.filter((_, j) => j !== i);
      if (arr.length >= 3) return arr;
      return [...arr, id];
    });
  }

  begin(): void {
    if (!this.canBegin()) return;
    if (this.operationRandom()) {
      const order = BATTLE_MODE_ORDER;
      this.state.battleModeId.set(order[Math.floor(Math.random() * order.length)]!);
    }
    this.state.showOperationPicker.set(false);
    if (this.squadRandom()) {
      this.state.initHeroes();
    } else {
      this.state.initHeroes(this.pickedOrder());
    }
    this.combat.initBattle();
  }
}
