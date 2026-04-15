import { Component, ChangeDetectionStrategy, inject, computed } from '@angular/core';
import { OpTooltipDirective } from '../../directives/op-tooltip.directive';
import { GameStateService } from '../../services/game-state.service';
import { ProtocolService } from '../../services/protocol.service';
import { ItemService } from '../../services/item.service';
import { RelicService } from '../../services/relic.service';
import {
  PROTOCOL_MAX,
  PROTOCOL_REROLL_COST,
  PROTOCOL_NUDGE_COST,
  PROTOCOL_NUDGE_DELTA,
} from '../../models/constants';
import type { ItemDefinition } from '../../models/item.interface';

@Component({
  selector: 'app-protocol-strip',
  standalone: true,
  imports: [OpTooltipDirective],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './protocol-strip.component.html',
  styleUrl: './protocol-strip.component.scss',
})
export class ProtocolStripComponent {
  state = inject(GameStateService);
  protocol = inject(ProtocolService);
  items = inject(ItemService);
  relicService = inject(RelicService);

  activeRelic = computed(() => this.relicService.activeRelic());

  relicSlotTooltip = computed(() => {
    const relic = this.activeRelic();
    return relic
      ? `AUGMENT: ${relic.name} — ${relic.desc}`
      : 'Augment slot — empty this run until you draft one (after battle 5).';
  });

  max = PROTOCOL_MAX;
  rerollCost = PROTOCOL_REROLL_COST;
  nudgeCost = PROTOCOL_NUDGE_COST;
  nudgeDelta = PROTOCOL_NUDGE_DELTA;

  barWidth = computed(() => {
    const pct = Math.max(0, Math.min(100, (this.state.protocol() / PROTOCOL_MAX) * 100));
    return pct + '%';
  });

  canReroll = computed(() => {
    if (!this.state.isPlayerPhase()) return false;
    if (this.state.protocol() < PROTOCOL_REROLL_COST) return false;
    return this.state.heroes().some(h => h.currentHp > 0 && h.roll !== null);
  });

  canNudge = computed(() => {
    if (!this.state.isPlayerPhase()) return false;
    if (this.state.protocol() < PROTOCOL_NUDGE_COST) return false;
    return this.state.heroes().some(h => {
      if (h.currentHp <= 0 || h.roll === null) return false;
      const eff = Math.min(20, (h.roll || 0) + (h.rollBuff || 0) + (h.rollNudge || 0));
      return eff < 20;
    });
  });

  /**
   * One computed drives all three slots so OnPush + signal CD always refreshes when inventory / phase / pending change.
   * (Calling `canUseSlot()` / `defAt()` from the template alone can miss updates in some Angular versions.)
   */
  readonly invRows = computed(() => {
    const phase = this.state.phase();
    const inv = this.state.inventory();
    const pending = this.state.pendingItemSelection();
    return [0, 1, 2].map(slot => {
      const id = inv[slot];
      const def = id ? (this.items.getDef(id) ?? null) : null;
      const usable = phase === 'player' && def != null;
      let title = 'Empty inventory slot';
      if (def) {
        const c = this.items.protocolCost(def);
        title = `${def.name} — ${def.desc} (Use: ${c} Protocol). Tap to use; tap again to cancel.`;
      }
      return {
        slot,
        def,
        usable,
        rarityClass: def ? 'r-' + def.rarity : 'r-empty',
        activePick: pending?.invSlot === slot,
        title,
      };
    });
  });

  itemCost(d: ItemDefinition): number {
    return this.items.protocolCost(d);
  }

  toggleItem(slot: number): void {
    this.items.beginUseInventorySlot(slot);
  }
}
