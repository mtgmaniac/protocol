import { DOCUMENT } from '@angular/common';
import {
  Directive,
  DestroyRef,
  ElementRef,
  HostListener,
  inject,
  input,
} from '@angular/core';

/**
 * Rich tooltip matching game UI (replaces native `title` yellow box).
 * Bind `[opTooltip]="text"`; null/empty omits the tooltip.
 */
@Directive({
  selector: '[opTooltip]',
  standalone: true,
})
export class OpTooltipDirective {
  private readonly el = inject(ElementRef<HTMLElement>);
  private readonly doc = inject(DOCUMENT);
  private readonly destroyRef = inject(DestroyRef);

  /** Tooltip body; newlines preserved. Null/undefined/blank = no tooltip. */
  readonly opTooltip = input<string | null | undefined>(undefined);

  private panel: HTMLDivElement | null = null;
  private showTimer: ReturnType<typeof setTimeout> | null = null;

  private readonly hideOnViewportChange = (): void => {
    this.hide();
  };

  constructor() {
    this.destroyRef.onDestroy(() => this.teardown());
  }

  @HostListener('mouseenter')
  @HostListener('focusin')
  onShowTrigger(): void {
    this.scheduleShow();
  }

  @HostListener('mouseleave')
  @HostListener('focusout')
  onHideTrigger(): void {
    this.cancelScheduledShow();
    this.hide();
  }

  private scheduleShow(): void {
    this.cancelScheduledShow();
    const raw = this.opTooltip();
    if (raw == null || String(raw).trim() === '') return;
    this.showTimer = setTimeout(() => this.mountPanel(String(raw)), 140);
  }

  private cancelScheduledShow(): void {
    if (this.showTimer != null) {
      clearTimeout(this.showTimer);
      this.showTimer = null;
    }
  }

  private mountPanel(text: string): void {
    this.hide();
    const panel = this.doc.createElement('div');
    panel.className = 'op-tooltip-panel';
    panel.setAttribute('role', 'tooltip');
    panel.textContent = text;
    panel.style.position = 'fixed';
    panel.style.left = '-9999px';
    panel.style.top = '0';
    panel.style.visibility = 'hidden';
    this.doc.body.appendChild(panel);
    this.panel = panel;

    const host = this.el.nativeElement.getBoundingClientRect();
    const margin = 10;
    const vw = window.innerWidth;
    const vh = window.innerHeight;
    const pr = panel.getBoundingClientRect();

    let left = host.left + host.width / 2 - pr.width / 2;
    let top = host.bottom + margin;
    if (top + pr.height > vh - margin) {
      top = host.top - pr.height - margin;
    }
    left = Math.max(margin, Math.min(left, vw - pr.width - margin));
    top = Math.max(margin, Math.min(top, vh - pr.height - margin));

    panel.style.left = `${Math.round(left)}px`;
    panel.style.top = `${Math.round(top)}px`;
    panel.style.visibility = '';

    window.addEventListener('scroll', this.hideOnViewportChange, true);
    window.addEventListener('resize', this.hideOnViewportChange);
  }

  private hide(): void {
    window.removeEventListener('scroll', this.hideOnViewportChange, true);
    window.removeEventListener('resize', this.hideOnViewportChange);
    this.panel?.remove();
    this.panel = null;
  }

  private teardown(): void {
    this.cancelScheduledShow();
    this.hide();
  }
}
