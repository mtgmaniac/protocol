import { Component, ChangeDetectionStrategy, inject, computed } from '@angular/core';
import { GameStateService } from '../../services/game-state.service';
import { ItemService } from '../../services/item.service';
import { GearService } from '../../services/gear.service';
import type { ItemDefinition } from '../../models/item.interface';
import type { GearDefinition } from '../../models/gear.interface';

export type DraftEntry =
  | { kind: 'item'; def: ItemDefinition }
  | { kind: 'gear'; def: GearDefinition };

@Component({
  selector: 'app-item-draft-overlay',
  standalone: true,
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './item-draft-overlay.component.html',
  styleUrl: './item-draft-overlay.component.scss',
})
export class ItemDraftOverlayComponent {
  state = inject(GameStateService);
  items = inject(ItemService);
  gear = inject(GearService);

  choices = computed(() => this.state.itemDraftChoices());

  entryFor(id: string): DraftEntry | null {
    const item = this.items.getDef(id);
    if (item) return { kind: 'item', def: item };
    const gearDef = this.gear.getGearDef(id);
    if (gearDef) return { kind: 'gear', def: gearDef };
    return null;
  }

  /** Legacy helper used by template for backward-compat icon switch. */
  defFor(id: string): ItemDefinition | null {
    return this.items.getDef(id) ?? null;
  }

  pick(id: string): void {
    this.items.pickDraftItem(id);
  }

  skip(): void {
    this.items.skipDraft();
  }
}
