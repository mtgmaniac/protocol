import { Component, ChangeDetectionStrategy, inject, computed } from '@angular/core';
import { GameStateService } from '../../services/game-state.service';
import { RelicService } from '../../services/relic.service';
import type { RelicDefinition } from '../../models/relic.interface';

@Component({
  selector: 'app-relic-draft-overlay',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './relic-draft-overlay.component.html',
  styleUrl: './relic-draft-overlay.component.scss',
})
export class RelicDraftOverlayComponent {
  state = inject(GameStateService);
  relics = inject(RelicService);

  choices = computed(() => this.state.relicDraftChoices());

  defFor(id: string): RelicDefinition | null {
    return this.relics.getDef(id) ?? null;
  }

  pick(id: string): void {
    this.relics.pickRelic(id);
  }
}
