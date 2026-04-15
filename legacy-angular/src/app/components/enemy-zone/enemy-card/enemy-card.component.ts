import { Component, ChangeDetectionStrategy, input, output, computed, inject } from '@angular/core';
import { EnemyState } from '../../../models/enemy.interface';
import { EnemyAbility } from '../../../models/ability.interface';
import { Zone, ZONES } from '../../../models/types';
import { GameStateService } from '../../../services/game-state.service';
import { DiceService } from '../../../services/dice.service';
import { CombatService } from '../../../services/combat.service';
import { TargetingService } from '../../../services/targeting.service';
import { HpBarComponent } from '../../shared/hp-bar/hp-bar.component';
import { PortraitFrameComponent } from '../../shared/portrait-frame/portrait-frame.component';
import { enemyPortraitSvg } from '../../../data/sprites.data';
import { enemyUnitFrameColor } from '../../../data/unit-frame-colors';

@Component({
  selector: 'app-enemy-card',
  standalone: true,
  imports: [HpBarComponent, PortraitFrameComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './enemy-card.component.html',
  styleUrl: './enemy-card.component.scss',
})
export class EnemyCardComponent {
  private state = inject(GameStateService);
  private dice = inject(DiceService);
  private combat = inject(CombatService);
  private targeting = inject(TargetingService);

  enemy = input.required<EnemyState>();
  index = input.required<number>();
  isPickable = input(false);
  hideRoll = input(false);

  enemyClicked = output<void>();

  zones = ZONES;

  unitFrameColor = computed(() => enemyUnitFrameColor(this.enemy().type));

  rampagePortraitTip = computed((): string | null => {
    const e = this.enemy();
    const n = e.rampageCharges || 0;
    if (n <= 0) return null;
    return n === 1
      ? 'Rampage: Next attack deals 2× damage'
      : `Rampage: Next ${n} attacks deal 2× damage`;
  });

  enemySvg = computed(() => enemyPortraitSvg(this.enemy().type));

  currentZone = computed((): Zone => {
    if (this.hideRoll()) return 'recharge';
    if (this.enemy().dead) return 'recharge';
    const er = this.enemy().effRoll;
    if (er <= 0) return 'recharge';
    return this.dice.getEnemyZone(er);
  });

  currentAbility = computed((): EnemyAbility | null => {
    return this.getAbilityForZone(this.currentZone());
  });

  totalShieldAmt = computed((): number => {
    return (this.enemy().shieldStacks ?? []).reduce((s, st) => s + st.amt, 0);
  });

  targetLine = computed(() => {
    this.state.heroes();
    this.state.enemies();
    this.enemy();
    if (this.hideRoll()) {
      return {
        segments: [
          { t: 'plain' as const, text: 'Target: ' },
          { t: 'muted' as const, text: '—' },
        ],
      };
    }
    return this.targeting.getEnemyTargetLineView(this.index());
  });

  getAbilityForZone(zone: Zone): EnemyAbility | null {
    const e = this.enemy();
    const ab = this.combat.getEnemyAbility(e, zone);
    return ab?.name === '?' ? null : ab;
  }

  isCurrentZone(zone: Zone): boolean {
    if (this.hideRoll()) return false;
    if (this.enemy().dead) return false;
    const er = this.enemy().effRoll;
    if (er <= 0) return false;
    return this.dice.getEnemyZone(er) === zone;
  }

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

  onCardClick(): void {
    this.enemyClicked.emit();
  }
}
