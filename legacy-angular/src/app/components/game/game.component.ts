import { Component, ChangeDetectionStrategy, inject, signal } from '@angular/core';
import { GameStateService } from '../../services/game-state.service';
import { CombatService } from '../../services/combat.service';
import { EnemyZoneComponent } from '../enemy-zone/enemy-zone.component';
import { HeroZoneComponent } from '../hero-zone/hero-zone.component';
import { DiceTrayComponent } from '../dice-tray/dice-tray.component';
import { ResultOverlayComponent } from '../overlays/result-overlay.component';
import { HelpOverlayComponent } from '../overlays/help-overlay.component';
import { EvolutionOverlayComponent } from '../overlays/evolution-overlay.component';
import { ItemDraftOverlayComponent } from '../overlays/item-draft-overlay.component';
import { RelicDraftOverlayComponent } from '../overlays/relic-draft-overlay.component';
import { GearAssignOverlayComponent } from '../overlays/gear-assign-overlay.component';
import { TutorialOverlayComponent } from '../overlays/tutorial-overlay.component';
import { OperationPickerComponent } from '../overlays/operation-picker.component';
import { ItemPendingBannerComponent } from '../shared/item-pending-banner/item-pending-banner.component';
import { TutorialService } from '../../services/tutorial.service';
import { TUTORIAL_PARTY_IDS } from '../../data/tutorial-steps.data';

@Component({
  selector: 'app-game',
  standalone: true,
  imports: [
    EnemyZoneComponent,
    HeroZoneComponent,
    DiceTrayComponent,
    ResultOverlayComponent,
    HelpOverlayComponent,
    EvolutionOverlayComponent,
    ItemDraftOverlayComponent,
    RelicDraftOverlayComponent,
    GearAssignOverlayComponent,
    TutorialOverlayComponent,
    OperationPickerComponent,
    ItemPendingBannerComponent,
  ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './game.component.html',
  styleUrl: './game.component.scss',
})
export class GameComponent {
  readonly state = inject(GameStateService);
  private combat = inject(CombatService);
  private tutorial = inject(TutorialService);

  helpOpen = signal(false);

  onChangeOperation(): void {
    this.combat.returnToOperationPicker();
  }

  startTutorialFromHelp(): void {
    this.helpOpen.set(false);
    this.state.showOperationPicker.set(false);
    this.state.battleModeId.set('facility');
    this.tutorial.launch();
    this.state.log.set([]);
    this.state.inventory.set([null, null, null]);
    this.state.itemDraftChoices.set(null);
    this.state.pendingItemSelection.set(null);
    this.state.initHeroes(TUTORIAL_PARTY_IDS);
    this.state.battle.set(0);
    this.combat.initBattle();
    this.tutorial.applyBattleTuning();
  }

  onTutorialExitRegular(): void {
    this.combat.returnToOperationPicker();
  }
}
