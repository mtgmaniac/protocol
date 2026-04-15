import { Component, ChangeDetectionStrategy, input, output, computed, inject } from '@angular/core';
import { HeroState } from '../../../models/hero.interface';
import { HeroAbility } from '../../../models/ability.interface';
import { Zone } from '../../../models/types';
import { DiceService } from '../../../services/dice.service';
import { GameStateService } from '../../../services/game-state.service';
import { TargetingService } from '../../../services/targeting.service';
import { HpBarComponent } from '../../shared/hp-bar/hp-bar.component';
import { PortraitFrameComponent } from '../../shared/portrait-frame/portrait-frame.component';
import { heroPortraitSvg } from '../../../data/sprites.data';
import { HERO_UNIT_FRAME_COLOR } from '../../../data/unit-frame-colors';

@Component({
  selector: 'app-hero-card',
  standalone: true,
  imports: [HpBarComponent, PortraitFrameComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './hero-card.component.html',
  styleUrl: './hero-card.component.scss',
})
export class HeroCardComponent {
  private dice = inject(DiceService);
  private state = inject(GameStateService);
  private targeting = inject(TargetingService);

  hero = input.required<HeroState>();
  index = input.required<number>();
  isSelected = input<boolean>(false);
  pickMode = input<string | null>(null);
  hideRoll = input<boolean>(false);

  heroClicked = output<void>();
  allyPickClicked = output<void>();

  heroSvg = computed(() => heroPortraitSvg(this.hero().id, this.hero().portraitPath));

  cardBorderColor = computed(() => {
    if (this.isSelected()) return 'rgba(100, 175, 255, 0.95)';
    return HERO_UNIT_FRAME_COLOR;
  });

  /** Stable DOM ids for tutorial spotlights (tutorial squad uses each id at most once). */
  tutorialDomId = computed((): string | null => {
    switch (this.hero().id) {
      case 'pulse':
        return 'tut-hero-pulse';
      case 'shield':
        return 'tut-hero-shield';
      case 'medic':
        return 'tut-hero-medic';
      default:
        return null;
    }
  });

  targetLine = computed(() => {
    this.state.heroes();
    this.state.enemies();
    this.hero();
    return this.targeting.getHeroTargetLineView(this.index());
  });

  xpWidth = computed(() => {
    const pct = Math.min(100, (this.hero().xp / 18) * 100);
    return pct + '%';
  });

  heroZone = computed((): Zone => {
    const h = this.hero();
    const er = this.dice.effRoll(h);
    if (er === null) return 'recharge';
    return this.dice.getHeroZone(er, h.id);
  });

  currentAbility = computed((): HeroAbility | null => {
    const h = this.hero();
    const er = this.dice.effRoll(h);
    if (er === null) return null;
    return this.dice.getAbility(h, er);
  });

  totalShield = computed((): number => {
    return (this.hero().shieldStacks ?? []).reduce((s, st) => s + st.amt, 0);
  });

  zoneAbbr(zone: Zone): string {
    const map: Record<Zone, string> = {
      recharge: 'RCHG',
      strike: 'STRK',
      surge: 'SRGE',
      crit: 'CRIT',
      overload: 'OVER',
    };
    return map[zone] ?? zone.substring(0, 4).toUpperCase();
  }

  onClick(): void {
    const hi = this.index();
    const pm = this.pickMode();
    if (
      pm === 'heal' ||
      pm === 'shield' ||
      pm === 'rollBuff' ||
      pm === 'revive' ||
      pm === 'freezeDice' ||
      pm === 'itemAlly' ||
      pm === 'itemAllyDead'
    ) {
      this.allyPickClicked.emit();
      return;
    }
    if (this.targeting.shouldCasterRetapResetTargeting(hi)) {
      this.heroClicked.emit();
      return;
    }
    this.heroClicked.emit();
  }
}
