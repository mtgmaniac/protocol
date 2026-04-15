import { Component, ChangeDetectionStrategy, input, computed, inject } from '@angular/core';
import { OpTooltipDirective } from '../../../directives/op-tooltip.directive';
import { DomSanitizer } from '@angular/platform-browser';
import { HERO_PORTRAIT_FRAME } from '../../../data/sprites.data';

@Component({
  selector: 'app-portrait-frame',
  standalone: true,
  imports: [OpTooltipDirective],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './portrait-frame.component.html',
  styleUrl: './portrait-frame.component.scss',
})
export class PortraitFrameComponent {
  svg = input.required<string>();
  isCloaked = input(false);
  /** Red frame pulse when this unit has rampage charges (enemies). */
  rampageGlow = input(false);
  /** Tooltip when rampageGlow is on (unit name + effect). */
  rampageTip = input<string | null>(null);
  /** DOM id for combat action highlights (e.g. `action-hero-0`). */
  anchorId = input<string | null>(null);

  readonly pf = HERO_PORTRAIT_FRAME;

  private sanitizer = inject(DomSanitizer);

  safeSvg = computed(() =>
    this.sanitizer.bypassSecurityTrustHtml(this.svg())
  );
}
