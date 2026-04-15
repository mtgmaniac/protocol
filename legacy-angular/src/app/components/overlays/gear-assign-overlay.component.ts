import { Component, ChangeDetectionStrategy, inject, computed } from '@angular/core';
import { GameStateService } from '../../services/game-state.service';
import { GearService } from '../../services/gear.service';
import { PortraitFrameComponent } from '../shared/portrait-frame/portrait-frame.component';
import { AbilityRowComponent } from '../shared/ability-row/ability-row.component';
import { heroPortraitSvg } from '../../data/sprites.data';
import type { GearDefinition } from '../../models/gear.interface';
import type { HeroAbility } from '../../models/ability.interface';

@Component({
  selector: 'app-gear-assign-overlay',
  standalone: true,
  imports: [PortraitFrameComponent, AbilityRowComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './gear-assign-overlay.component.html',
  styleUrl: './gear-assign-overlay.component.scss',
})
export class GearAssignOverlayComponent {
  state = inject(GameStateService);
  gear = inject(GearService);

  pendingGear = computed((): GearDefinition | null => {
    const id = this.state.pendingGearAssignment();
    if (!id) return null;
    return this.gear.getGearDef(id) ?? null;
  });

  heroes = computed(() => this.state.heroes());

  heroHasGear(idx: number): boolean {
    return this.gear.heroHasGear(idx);
  }

  assign(idx: number): void {
    this.gear.confirmGearForHero(idx);
  }

  heroSvg(idx: number): string {
    const h = this.state.heroes()[idx];
    return h ? heroPortraitSvg(h.id, h.portraitPath) : '';
  }

  rangeStr(ab: HeroAbility): string {
    return ab.range[0] === ab.range[1] ? `${ab.range[0]}` : `${ab.range[0]}-${ab.range[1]}`;
  }
}
