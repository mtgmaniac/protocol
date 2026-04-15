import { Component, ChangeDetectionStrategy, inject, computed } from '@angular/core';
import { GameStateService } from '../../services/game-state.service';
import { TargetingService } from '../../services/targeting.service';
import { ItemService } from '../../services/item.service';
import { HeroCardComponent } from './hero-card/hero-card.component';
import { HeroState } from '../../models/hero.interface';

@Component({
  selector: 'app-hero-zone',
  standalone: true,
  imports: [HeroCardComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './hero-zone.component.html',
  styleUrl: './hero-zone.component.scss',
})
export class HeroZoneComponent {
  state = inject(GameStateService);
  targeting = inject(TargetingService);
  items = inject(ItemService);

  /** Count of non-null inventory slots. */
  itemCount = computed(() => this.state.inventory().filter(x => x !== null).length);

  /** Include tier/max/name so evolved heroes reconcile and OnPush inputs refresh (id alone is stable). */
  heroZoneTrack(hero: HeroState): string {
    return `${hero.id}:${hero.tier}:${hero.maxHp}:${hero.name}`;
  }

  getPickMode(i: number): string | null {
    const pi = this.state.pendingItemSelection();
    if (pi) {
      const def = this.items.getDef(pi.itemId);
      const heroes = this.state.heroes();
      const t = heroes[i];
      if (!t) return null;
      if (def?.target === 'ally' && t.currentHp > 0) return 'itemAlly';
      if (def?.target === 'allyDead' && t.currentHp <= 0) return 'itemAllyDead';
      return null;
    }

    const shi = this.state.selectedHeroIdx();
    if (shi === null) return null;
    const nk = this.targeting.nextPickKindForHero(shi);
    const heroes = this.state.heroes();
    const t = heroes[i];
    if (!t) return null;

    // Targeted heal/shield: any living ally, including the caster (explicit pick required).
    if (nk === 'heal' || nk === 'shield' || nk === 'rollBuff') {
      if (t.currentHp <= 0) return null;
      return nk;
    }
    // Revive: dead allies only; never the living caster card.
    if (nk === 'revive') {
      if (shi === i) return null;
      if (t.currentHp > 0) return null;
      return nk;
    }
    if (nk === 'freezeDice') {
      if (t.currentHp <= 0) return null;
      return nk;
    }
    return null;
  }
}
