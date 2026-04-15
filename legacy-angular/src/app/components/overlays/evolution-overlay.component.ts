import { Component, ChangeDetectionStrategy, inject, computed } from '@angular/core';
import { GameStateService } from '../../services/game-state.service';
import { EvolutionService, GroupedEvoPath } from '../../services/evolution.service';
import { CombatService } from '../../services/combat.service';
import { PortraitFrameComponent } from '../shared/portrait-frame/portrait-frame.component';
import { AbilityRowComponent } from '../shared/ability-row/ability-row.component';
import { heroPortraitSvg } from '../../data/sprites.data';
import type { HeroAbility } from '../../models/ability.interface';

@Component({
  selector: 'app-evolution-overlay',
  standalone: true,
  imports: [PortraitFrameComponent, AbilityRowComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './evolution-overlay.component.html',
  styleUrl: './evolution-overlay.component.scss',
})
export class EvolutionOverlayComponent {
  state = inject(GameStateService);
  private evo = inject(EvolutionService);
  private combat = inject(CombatService);

  isVisible = computed(() => this.state.pendingEvolutions().length > 0);

  allChosen = computed(() =>
    this.state.pendingEvolutions().every(pe => pe.chosen !== null)
  );

  getHeroName(heroIdx: number): string {
    return this.state.heroes()[heroIdx]?.name ?? '?';
  }

  getPaths(heroIdx: number): GroupedEvoPath[] {
    const hero = this.state.heroes()[heroIdx];
    if (!hero) return [];
    return this.evo.groupEvoPaths(hero.evolutions);
  }

  portraitSvg(heroIdx: number): string {
    const h = this.state.heroes()[heroIdx];
    return h ? heroPortraitSvg(h.id, h.portraitPath) : '';
  }

  rangeStr(ab: HeroAbility): string {
    return ab.range[0] === ab.range[1] ? `${ab.range[0]}` : `${ab.range[0]}-${ab.range[1]}`;
  }

  selectEvo(pendingIdx: number, pathIdx: number): void {
    this.state.pendingEvolutions.update(evos =>
      evos.map((pe, i) => i === pendingIdx ? { ...pe, chosen: pathIdx } : pe)
    );
  }

  confirm(): void {
    const pending = this.state.pendingEvolutions();
    for (const pe of pending) {
      if (pe.chosen !== null) {
        this.evo.confirmEvolution(pe.heroIdx, pe.chosen);
      }
    }
    this.state.pendingEvolutions.set([]);
    this.combat.beginPostEvoItemDraft();
  }
}
