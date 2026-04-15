import { Component, ChangeDetectionStrategy, input, computed } from '@angular/core';

@Component({
  selector: 'app-hp-bar',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './hp-bar.component.html',
  styleUrl: './hp-bar.component.scss',
})
export class HpBarComponent {
  current = input.required<number>();
  max = input.required<number>();
  /** When false, only the bar renders (use an external label row if needed). */
  showLabel = input(true);
  /** When true, HP label is full-width (no aside slot for ribbons). */
  compactHead = input(false);
  /** Tighter margins on the label row (hero card bottom stack). */
  tightMargins = input(false);

  widthPct = computed(() => {
    const m = this.max();
    if (m <= 0) return '0%';
    return Math.max(0, Math.min(100, Math.round((this.current() / m) * 100))) + '%';
  });

  fillClass = computed(() => {
    const m = this.max();
    if (m <= 0) return 'hp-fill hp-fill-r';
    const pct = this.current() / m;
    if (pct <= 0.25) return 'hp-fill hp-fill-r';
    if (pct <= 0.5) return 'hp-fill hp-fill-y';
    return 'hp-fill hp-fill-g';
  });

  labelColor = computed(() => {
    const m = this.max();
    if (m <= 0) return 'var(--hr)';
    const pct = this.current() / m;
    if (pct <= 0.25) return 'var(--hr)';
    if (pct <= 0.5) return 'var(--cell)';
    return 'var(--muted)';
  });
}
