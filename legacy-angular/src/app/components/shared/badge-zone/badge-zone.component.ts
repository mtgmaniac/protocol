import {
  Component,
  ChangeDetectionStrategy,
  input,
  computed,
  inject,
} from '@angular/core';
import {
  UnitStatusRibbonComponent,
  type UnitStatusRibbonLine,
} from '../unit-status-ribbon/unit-status-ribbon.component';
import { OpTooltipDirective } from '../../../directives/op-tooltip.directive';
import { GameStateService } from '../../../services/game-state.service';
import {
  BadgeProjectionService,
  HeroBadgeSnapshot,
  EnemyBadgeSnapshot,
} from '../../../services/badge-projection.service';

@Component({
  selector: 'app-badge-zone',
  standalone: true,
  imports: [UnitStatusRibbonComponent, OpTooltipDirective],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './badge-zone.component.html',
  styleUrl: './badge-zone.component.scss',
})
export class BadgeZoneComponent {
  private state = inject(GameStateService);
  private projection = inject(BadgeProjectionService);

  kind = input.required<'hero' | 'enemy'>();
  index = input.required<number>();
  /** Word chips (CURSED, CLOAK, etc.) — hero only; below numeric Status row. */
  ribbonLines = input<UnitStatusRibbonLine[]>([]);

  heroSnap = computed((): HeroBadgeSnapshot => {
    this.state.heroes();
    this.state.enemies();
    this.state.squadRfmStacks();
    this.state.squadRfmPenalty();
    this.state.allHeroesRolled();
    this.state.phase();
    return this.projection.heroBadges(this.index());
  });

  enemySnap = computed((): EnemyBadgeSnapshot => {
    this.state.heroes();
    this.state.enemies();
    this.state.squadRfmStacks();
    this.state.squadRfmPenalty();
    this.state.allHeroesRolled();
    this.state.phase();
    this.state.endTurnHeroResolveCursor();
    return this.projection.enemyBadges(this.index());
  });

  rollModLabel(net: number): string {
    if (net === 0) return '—';
    return net > 0 ? `+${net}` : `${net}`;
  }

  /** Current roll modifiers + queued ally/item buff for next roll, shown as one value. */
  heroRollCombined(h: HeroBadgeSnapshot): number {
    return h.netRollMod + h.pendingNextRoll;
  }
}
