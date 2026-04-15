import { Component, ChangeDetectionStrategy, inject, computed } from '@angular/core';
import { GameStateService } from '../../../services/game-state.service';
import { ItemService } from '../../../services/item.service';
import { PortraitFrameComponent } from '../portrait-frame/portrait-frame.component';
import { AbilityRowComponent } from '../ability-row/ability-row.component';
import { enemyPortraitSvg, heroPortraitSvg } from '../../../data/sprites.data';
import type { HeroAbility } from '../../../models/ability.interface';
import type { ItemDefinition } from '../../../models/item.interface';

@Component({
  selector: 'app-item-pending-banner',
  standalone: true,
  imports: [PortraitFrameComponent, AbilityRowComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './item-pending-banner.component.html',
  styleUrl: './item-pending-banner.component.scss',
})
export class ItemPendingBannerComponent {
  state = inject(GameStateService);
  items = inject(ItemService);

  itemDef = computed((): ItemDefinition | null => {
    const p = this.state.pendingItemSelection();
    if (!p) return null;
    return this.items.getDef(p.itemId) ?? null;
  });

  allyHeroIndices = computed((): number[] => {
    const def = this.itemDef();
    if (!def || def.target !== 'ally') return [];
    return this.state
      .heroes()
      .map((h, i) => (h.currentHp > 0 ? i : -1))
      .filter(i => i >= 0);
  });

  deadHeroIndices = computed((): number[] => {
    const def = this.itemDef();
    if (!def || def.target !== 'allyDead') return [];
    return this.state
      .heroes()
      .map((h, i) => (h.currentHp <= 0 ? i : -1))
      .filter(i => i >= 0);
  });

  enemyIndices = computed((): number[] => {
    const def = this.itemDef();
    if (!def || def.target !== 'enemy') return [];
    return this.state
      .enemies()
      .map((e, i) => (!e.dead ? i : -1))
      .filter(i => i >= 0);
  });

  heroSvg(idx: number): string {
    const h = this.state.heroes()[idx];
    return h ? heroPortraitSvg(h.id, h.portraitPath) : '';
  }

  enemySvg(idx: number): string {
    const e = this.state.enemies()[idx];
    return e ? enemyPortraitSvg(e.type) : '';
  }

  rangeStr(ab: HeroAbility): string {
    return ab.range[0] === ab.range[1] ? `${ab.range[0]}` : `${ab.range[0]}-${ab.range[1]}`;
  }
}
