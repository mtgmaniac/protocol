import { Injectable, inject } from '@angular/core';
import { GameStateService } from './game-state.service';

/** Procedural retro bleeps (Web Audio). Replace with samples later if desired. */
@Injectable({ providedIn: 'root' })
export class SoundService {
  private readonly state = inject(GameStateService);
  private ctx: AudioContext | null = null;

  private getCtx(): AudioContext | null {
    if (typeof window === 'undefined') return null;
    if (!this.ctx) {
      const w = window as Window & { webkitAudioContext?: typeof AudioContext };
      const AC = window.AudioContext || w.webkitAudioContext;
      if (!AC) return null;
      this.ctx = new AC();
    }
    return this.ctx;
  }

  /** Call from click/tap handlers so the first `play*` after load is audible. */
  resume(): void {
    const c = this.getCtx();
    if (c?.state === 'suspended') void c.resume();
  }

  playPortraitFlash(cls: string): void {
    if (cls === 'pf-flash-red') this.playDmg();
    else if (cls === 'pf-flash-green') this.playHeal();
    else if (cls === 'pf-flash-blue') this.playShield();
    else if (cls === 'pf-flash-amber') this.playDebuff();
  }

  playRollReveal(): void {
    void this.withCtx(ctx => {
      const t = ctx.currentTime;
      tone(ctx, t, 520, 0.032, 'square', 0.07);
      tone(ctx, t + 0.042, 380, 0.038, 'square', 0.055);
    });
  }

  /** Instant single-hero roll (no tray animation). */
  playRollTick(): void {
    void this.withCtx(ctx => {
      tone(ctx, ctx.currentTime, 440, 0.028, 'square', 0.06);
    });
  }

  playEndTurn(): void {
    void this.withCtx(ctx => {
      const t = ctx.currentTime;
      tone(ctx, t, 196, 0.07, 'square', 0.055);
      tone(ctx, t + 0.08, 262, 0.09, 'square', 0.05);
    });
  }

  playDeath(): void {
    void this.withCtx(ctx => {
      const ctxAudio = ctx;
      const t = ctxAudio.currentTime;
      const osc = ctxAudio.createOscillator();
      const g = ctxAudio.createGain();
      osc.type = 'square';
      osc.frequency.setValueAtTime(380, t);
      osc.frequency.exponentialRampToValueAtTime(90, t + 0.22);
      g.gain.setValueAtTime(0.09, t);
      g.gain.exponentialRampToValueAtTime(0.001, t + 0.26);
      osc.connect(g);
      g.connect(ctxAudio.destination);
      osc.start(t);
      osc.stop(t + 0.28);
    });
  }

  private async withCtx(fn: (ctx: AudioContext) => void): Promise<void> {
    if (!this.state.soundOn()) return;
    const ctx = this.getCtx();
    if (!ctx) return;
    try {
      if (ctx.state === 'suspended') await ctx.resume();
      fn(ctx);
    } catch {
      /* ignore */
    }
  }

  private playDmg(): void {
    void this.withCtx(ctx => {
      const t = ctx.currentTime;
      const osc = ctx.createOscillator();
      const g = ctx.createGain();
      osc.type = 'square';
      osc.frequency.setValueAtTime(420, t);
      osc.frequency.exponentialRampToValueAtTime(180, t + 0.055);
      g.gain.setValueAtTime(0.085, t);
      g.gain.exponentialRampToValueAtTime(0.001, t + 0.07);
      osc.connect(g);
      g.connect(ctx.destination);
      osc.start(t);
      osc.stop(t + 0.075);
    });
  }

  private playHeal(): void {
    void this.withCtx(ctx => {
      const t = ctx.currentTime;
      tone(ctx, t, 523, 0.045, 'sine', 0.07);
      tone(ctx, t + 0.05, 659, 0.055, 'sine', 0.065);
    });
  }

  private playShield(): void {
    void this.withCtx(ctx => {
      const ctxAudio = ctx;
      const t = ctxAudio.currentTime;
      const osc = ctxAudio.createOscillator();
      const g = ctxAudio.createGain();
      osc.type = 'sine';
      osc.frequency.setValueAtTime(320, t);
      osc.frequency.linearRampToValueAtTime(480, t + 0.1);
      g.gain.setValueAtTime(0.001, t);
      g.gain.linearRampToValueAtTime(0.07, t + 0.02);
      g.gain.exponentialRampToValueAtTime(0.001, t + 0.14);
      osc.connect(g);
      g.connect(ctxAudio.destination);
      osc.start(t);
      osc.stop(t + 0.15);
    });
  }

  private playDebuff(): void {
    void this.withCtx(ctx => {
      tone(ctx, ctx.currentTime, 200, 0.045, 'square', 0.065);
    });
  }
}

function tone(
  ctx: AudioContext,
  when: number,
  freq: number,
  dur: number,
  type: OscillatorType,
  vol: number,
): void {
  const osc = ctx.createOscillator();
  const g = ctx.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, when);
  g.gain.setValueAtTime(vol, when);
  g.gain.exponentialRampToValueAtTime(0.001, when + dur);
  osc.connect(g);
  g.connect(ctx.destination);
  osc.start(when);
  osc.stop(when + dur + 0.02);
}
