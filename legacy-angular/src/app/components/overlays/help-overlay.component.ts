import { Component, ChangeDetectionStrategy, inject, input, output, isDevMode, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { GameStateService } from '../../services/game-state.service';
import { SoundService } from '../../services/sound.service';
import { DevDataPanelService } from '../../services/dev-data-panel.service';
import { BattleProgressSimService } from '../../services/battle-progress-sim.service';

@Component({
  selector: 'app-help-overlay',
  standalone: true,
  imports: [FormsModule],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './help-overlay.component.html',
  styleUrl: './help-overlay.component.scss',
})
export class HelpOverlayComponent {
  readonly state = inject(GameStateService);
  private readonly sound = inject(SoundService);
  private readonly devData = inject(DevDataPanelService);
  private readonly sim = inject(BattleProgressSimService);
  /** DATA panel only available in dev builds. */
  readonly devBuild = isDevMode();

  isOpen = input(false);
  closed = output<void>();
  startTutorial = output<void>();

  // ── Balance sim state ──
  readonly simRunning = signal(false);
  readonly simOutput = signal('');
  readonly simJustCopied = signal(false);
  simIterations = 500;
  simProtocolRerolls = 0;

  openDataPanel(): void {
    this.devData.openPanel();
    this.closed.emit();
  }

  toggleSound(): void {
    this.state.toggleSound();
    if (this.state.soundOn()) this.sound.resume();
  }

  runBalanceSim(): void {
    if (this.simRunning()) return;
    this.simRunning.set(true);
    this.simOutput.set('Running\u2026');
    const iters = Math.max(50, Math.min(2000, Math.floor(Number(this.simIterations) || 500)));
    const proto = Math.max(0, Math.min(20, Math.floor(Number(this.simProtocolRerolls) || 0)));
    // Defer so "Running…" renders before the synchronous sim blocks the main thread
    setTimeout(() => {
      try {
        const result = this.sim.run(iters, proto);
        this.simOutput.set(this.sim.format(result));
      } catch (e) {
        this.simOutput.set(e instanceof Error ? e.message : String(e));
      } finally {
        this.simRunning.set(false);
      }
    }, 0);
  }

  copySimOutput(): void {
    const text = this.simOutput();
    if (!text || text === 'Running\u2026') return;
    navigator.clipboard.writeText(text).then(() => {
      this.simJustCopied.set(true);
      setTimeout(() => this.simJustCopied.set(false), 1800);
    });
  }
}
