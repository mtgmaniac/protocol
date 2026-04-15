import { Component, ChangeDetectionStrategy, inject } from '@angular/core';
import { GameStateService } from '../../services/game-state.service';
import { TargetingService } from '../../services/targeting.service';
import { ItemService } from '../../services/item.service';
import { EnemyCardComponent } from './enemy-card/enemy-card.component';

@Component({
  selector: 'app-enemy-zone',
  standalone: true,
  imports: [EnemyCardComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './enemy-zone.component.html',
  styleUrl: './enemy-zone.component.scss',
})
export class EnemyZoneComponent {
  state = inject(GameStateService);
  targeting = inject(TargetingService);
  items = inject(ItemService);

  /** Mask enemy die, highlighted ability row, and target name until squad rolls are done and tray is revealed. */
  hideEnemyRolls(): boolean {
    if (!this.state.isPlayerPhase()) return false;
    if (!this.state.allHeroesRolled()) return true;
    return !this.state.enemyTrayRevealed();
  }

  isEnemyPickable(i: number): boolean {
    const enemy = this.state.enemies()[i];
    if (!enemy || enemy.dead) return false;
    if (!this.state.isPlayerPhase()) return false;
    const pi = this.state.pendingItemSelection();
    if (pi) {
      const def = this.items.getDef(pi.itemId);
      return def?.target === 'enemy';
    }
    const shi = this.state.selectedHeroIdx();
    if (shi === null) return false;
    const nk = this.targeting.nextPickKindForHero(shi);
    return nk === 'enemy' || nk === 'freezeDice';
  }
}
