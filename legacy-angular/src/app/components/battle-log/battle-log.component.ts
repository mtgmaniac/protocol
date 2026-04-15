import { Component, ChangeDetectionStrategy, inject } from '@angular/core';
import { GameStateService } from '../../services/game-state.service';
import { LogService } from '../../services/log.service';

@Component({
  selector: 'app-battle-log',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './battle-log.component.html',
  styleUrl: './battle-log.component.scss',
})
export class BattleLogComponent {
  state = inject(GameStateService);
  logService = inject(LogService);
}
