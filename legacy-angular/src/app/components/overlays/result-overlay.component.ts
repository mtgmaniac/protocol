import { Component, ChangeDetectionStrategy, inject } from '@angular/core';
import { GameStateService } from '../../services/game-state.service';

@Component({
  selector: 'app-result-overlay',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './result-overlay.component.html',
  styleUrl: './result-overlay.component.scss',
})
export class ResultOverlayComponent {
  state = inject(GameStateService);

  onBtnClick(): void {
    const action = this.state.overlayBtnAction();
    if (action) action();
  }
}
