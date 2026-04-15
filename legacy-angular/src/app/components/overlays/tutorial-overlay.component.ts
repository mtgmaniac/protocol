import {
  Component,
  ChangeDetectionStrategy,
  computed,
  inject,
  output,
  signal,
  effect,
  afterNextRender,
  DestroyRef,
} from '@angular/core';
import { GameStateService } from '../../services/game-state.service';
import { TutorialService } from '../../services/tutorial.service';

const PANEL_W = 300;
const PANEL_GAP = 10;
const SPOT_PAD = 6;

function unionClientRect(selectors: string[]): {
  left: number;
  top: number;
  width: number;
  height: number;
} | null {
  let minL = Infinity;
  let minT = Infinity;
  let maxR = -Infinity;
  let maxB = -Infinity;
  let ok = false;
  for (const sel of selectors) {
    const el = document.querySelector(sel) as HTMLElement | null;
    if (!el) continue;
    const r = el.getBoundingClientRect();
    if (r.width < 1 && r.height < 1) continue;
    ok = true;
    minL = Math.min(minL, r.left);
    minT = Math.min(minT, r.top);
    maxR = Math.max(maxR, r.right);
    maxB = Math.max(maxB, r.bottom);
  }
  if (!ok) return null;
  return { left: minL, top: minT, width: maxR - minL, height: maxB - minT };
}

@Component({
  selector: 'app-tutorial-overlay',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './tutorial-overlay.component.html',
  styleUrl: './tutorial-overlay.component.scss',
})
export class TutorialOverlayComponent {
  state = inject(GameStateService);
  tutorial = inject(TutorialService);
  private destroyRef = inject(DestroyRef);
  exitRegular = output<void>();

  spotRect = signal<{ left: number; top: number; width: number; height: number } | null>(null);
  panelRect = signal<{ left: number; top: number } | null>(null);

  visible = computed(() => {
    const t = this.state.tutorial();
    if (!t?.active) return false;
    if (!t.introComplete) return true;
    if (t.showComplete) return true;
    if (t.resolutions === 0 && t.coachStep >= 1 && t.coachStep <= 4) return true;
    return false;
  });

  constructor() {
    const relayout = () => {
      if (!this.visible()) {
        this.spotRect.set(null);
        this.panelRect.set(null);
        return;
      }
      const tut = this.state.tutorial();
      const drone =
        (document.querySelector('#tut-drone-card') as HTMLElement | null) ??
        (document.querySelector('#tut-enemy-zone') as HTMLElement | null);
      const anchorEl = drone;
      const sels = this.tutorial.spotlightSelectors();
      const ur = unionClientRect(sels);
      if (!anchorEl || !ur) {
        this.spotRect.set(null);
        this.panelRect.set(null);
        return;
      }
      const pad = SPOT_PAD;
      this.spotRect.set({
        left: ur.left - pad,
        top: ur.top - pad,
        width: Math.max(24, ur.width + pad * 2),
        height: Math.max(24, ur.height + pad * 2),
      });
      const dr = anchorEl.getBoundingClientRect();
      const vw = window.innerWidth;
      const vh = window.innerHeight;
      const pw = Math.min(PANEL_W, vw - 20);
      let left = dr.right + PANEL_GAP;
      let top = dr.top;
      if (left + pw > vw - 8) {
        left = dr.left - pw - PANEL_GAP;
      }
      if (left < 8) {
        left = Math.max(8, (vw - pw) / 2);
        top = dr.bottom + PANEL_GAP;
      }
      top = Math.max(8, Math.min(top, vh - 100));
      this.panelRect.set({ left, top });
    };

    effect(() => {
      this.visible();
      this.state.tutorial();
      this.tutorial.spotlightSelectors();
      queueMicrotask(() => relayout());
    });

    afterNextRender(() => {
      const onWin = () => relayout();
      window.addEventListener('resize', onWin);
      window.addEventListener('scroll', onWin, true);
      this.destroyRef.onDestroy(() => {
        window.removeEventListener('resize', onWin);
        window.removeEventListener('scroll', onWin, true);
      });
      relayout();
    });
  }
}
