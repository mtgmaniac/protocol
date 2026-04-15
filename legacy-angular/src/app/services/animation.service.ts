import { Injectable, Renderer2, RendererFactory2 } from '@angular/core';
import { GameStateService } from './game-state.service';

export const STEP_MS = 120;
export const SUBFLASH_MS = 110;
/** Pause between sequential targets / heroes / enemies during END TURN resolution. */
export const ACTION_PACE_MS = 130;
export const BETWEEN_UNITS_MS = 190;

@Injectable({ providedIn: 'root' })
export class AnimationService {
  private renderer: Renderer2;

  constructor(
    rendererFactory: RendererFactory2,
    private state: GameStateService,
  ) {
    this.renderer = rendererFactory.createRenderer(null, null);
  }

  sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  heroPortraitEl(i: number): HTMLElement | null {
    if (typeof document === 'undefined') return null;
    return document.getElementById(`action-hero-${i}`);
  }

  enemyPortraitEl(i: number): HTMLElement | null {
    if (typeof document === 'undefined') return null;
    return document.getElementById(`action-enemy-${i}`);
  }

  async paceBetweenSteps(): Promise<void> {
    if (!this.state.animOn()) return;
    await this.sleep(ACTION_PACE_MS);
  }

  async gapBetweenActors(): Promise<void> {
    if (!this.state.animOn()) return;
    await this.sleep(BETWEEN_UNITS_MS);
  }

  async pfShake(el: HTMLElement | null): Promise<void> {
    if (!el || !this.state.animOn()) return;
    this.renderer.addClass(el, 'pf-shake');
    await this.sleep(190);
    this.renderer.removeClass(el, 'pf-shake');
  }

  async pfPulse(el: HTMLElement | null, cls: string, ms: number): Promise<void> {
    if (!el || !this.state.animOn()) return;
    this.renderer.addClass(el, cls);
    await this.sleep(ms);
    this.renderer.removeClass(el, cls);
  }

  async pfDeath(el: HTMLElement | null): Promise<void> {
    if (!el || !this.state.animOn()) return;
    this.renderer.addClass(el, 'pf-death');
    await this.sleep(260);
    this.renderer.removeClass(el, 'pf-death');
  }

  async doAnim(
    casterEl: HTMLElement | null,
    kind: 'dmg' | 'heal' | 'shield',
    targetEls: (HTMLElement | null)[],
    isLethalArr: boolean[] = [],
  ): Promise<void> {
    if (!this.state.animOn()) return;
    await this.pfShake(casterEl);
    for (let ti = 0; ti < targetEls.length; ti++) {
      const el = targetEls[ti];
      if (!el) continue;
      if (kind === 'dmg') await this.pfPulse(el, 'pf-flash-red', SUBFLASH_MS);
      if (kind === 'heal') await this.pfPulse(el, 'pf-flash-green', SUBFLASH_MS);
      if (kind === 'shield') await this.pfPulse(el, 'pf-flash-blue', SUBFLASH_MS);
      if (isLethalArr[ti]) await this.pfDeath(el);
    }
    await this.sleep(STEP_MS);
  }
}
