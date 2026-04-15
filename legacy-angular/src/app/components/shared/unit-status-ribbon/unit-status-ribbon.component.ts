import { Component, ChangeDetectionStrategy, input } from '@angular/core';
import { OpTooltipDirective } from '../../../directives/op-tooltip.directive';

export interface UnitStatusRibbonLine {
  key: string;
  tag: string;
  /** Reminder text (hover); not shown inline beside the badge. */
  detail: string;
  /** If set, used for hover instead of `detail`. */
  tooltip?: string;
}

@Component({
  selector: 'app-unit-status-ribbon',
  standalone: true,
  imports: [OpTooltipDirective],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './unit-status-ribbon.component.html',
  styleUrl: './unit-status-ribbon.component.scss',
})
export class UnitStatusRibbonComponent {
  lines = input<UnitStatusRibbonLine[]>([]);
  /** `inline`: badges in a row (hero status bar). Default: column stack (e.g. beside HP). */
  layout = input<'stack' | 'inline'>('stack');
}
