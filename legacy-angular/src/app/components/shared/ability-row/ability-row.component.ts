import { Component, ChangeDetectionStrategy, input, computed } from '@angular/core';
import { OpTooltipDirective } from '../../../directives/op-tooltip.directive';
import { HeroAbility, EnemyAbility } from '../../../models/ability.interface';
import { Zone } from '../../../models/types';
import { clampHeroAbilityForTier1 } from '../../../utils/hero-ability-tier.util';
import { counterAbilityTooltip, counterChipLabel } from '../../../utils/counterspell.util';

type MiniIcon = 'bolt' | 'plus' | 'shield' | 'skull' | 'die' | 'frost';

/** Visual family for mini chips — matches combat badge / zone attack colors. */
type AbilityMiniTone =
  | 'dmg'
  | 'heal'
  | 'shield'
  | 'dot'
  | 'rollAlly'
  | 'rollFoe'
  | 'fear'
  | 'control'
  | 'neutral';

interface AbilityMiniToken {
  icon: MiniIcon | null;
  num?: string;
  label?: string;
  /** Long text chip (e.g. REVIVE) — tighter font */
  wide?: boolean;
  /** Show clock + this value in the same chip when > 1 (DoT, shield, ±roll durations, etc.). */
  turns?: number;
  /** Hits all valid targets (AoE / party / all enemies) — glyph instead of “ALL” text. */
  tagAll?: boolean;
  /** Effect applies to self (heal/shield when not ally/all). */
  tagSelf?: boolean;
  tone: AbilityMiniTone;
  /** Hover: one stat gloss, or full text for keyword chips (PIERCE, REVIVE, …). */
  tooltip: string;
}

@Component({
  selector: 'app-ability-row',
  standalone: true,
  imports: [OpTooltipDirective],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './ability-row.component.html',
  styleUrl: './ability-row.component.scss',
})
export class AbilityRowComponent {
  ability = input.required<HeroAbility | EnemyAbility>();
  zone = input.required<Zone>();
  rangeStr = input.required<string>();
  isCurrent = input(false);
  /**
   * After the unit’s die is set (hero rolled / enemy tray revealed), non-matching ability rows dim.
   * When false, all rows stay fully lit.
   */
  highlightLocked = input(false);
  /** Hero chart vs enemy chart — drives mini icon ordering and fields. */
  effectVariant = input<'hero' | 'enemy'>('hero');
  /** Tier 1: shield / ±roll buff durations shown and matched at resolve as 1 turn (DoT unchanged). */
  tier = input<1 | 2>(2);

  /** Dim this row only when a roll is locked in and this bracket is not the active one. */
  dimInactive = computed(() => this.highlightLocked() && !this.isCurrent());

  rangeLabel = computed(() => this.rangeStr());

  miniRowClass(tok: AbilityMiniToken): string {
    let c = `mi mi-${tok.tone}`;
    if (tok.wide) c += ' mi-wide';
    return c;
  }

  private heroAbilityView = computed((): HeroAbility => {
    const a = this.ability() as HeroAbility;
    return this.tier() === 1 ? clampHeroAbilityForTier1(a) : a;
  });

  miniTokens = computed((): AbilityMiniToken[] =>
    this.effectVariant() === 'enemy'
      ? this.buildEnemyMinis(this.ability() as EnemyAbility)
      : this.buildHeroMinis(this.heroAbilityView()),
  );

  /** Labeled numbers from ability stats (matches combat + badges). */
  effectSummary = computed((): string => {
    if (this.effectVariant() === 'enemy') {
      return this.buildEnemyEffectSummary(this.ability() as EnemyAbility);
    }
    return this.buildHeroEffectSummary(this.heroAbilityView());
  });

  /** Hover on roll range only: move name + data description (`eff`). */
  rangeTooltip = computed((): string => {
    const a = this.ability();
    const name = a.name;
    const eff = a.eff?.trim() ?? '';
    if (eff.length) return `${name}: ${eff}`;
    const fallback = this.effectSummary();
    return `${name}: ${fallback}`;
  });

  abilityAriaLabel = computed((): string => {
    const a = this.ability();
    const eff = a.eff?.trim() ?? '';
    const mech = this.effectSummary();
    if (!eff.length) return `${a.name}. ${mech}`;
    if (eff === mech) return `${a.name}. ${eff}`;
    return `${a.name}. ${eff}. ${mech}`;
  });

  /** Mini-chip hover: `Ability name: effect` (matches roll-range column). */
  private namedTokenTooltip(ab: HeroAbility | EnemyAbility, body: string): string {
    const b = body.trim();
    if (!b) return '';
    return `${ab.name}: ${b}`;
  }

  /** Keyword chips (Fear, Summon, …): `Keyword: description` — not the card’s ability name. */
  private keywordTokenTooltip(keyword: string, body: string): string {
    const b = body.trim();
    if (!b) return keyword;
    return `${keyword}: ${b}`;
  }

  private buildHeroEffectSummary(a: HeroAbility): string {
    const parts: string[] = [];
    const dLo = a.dMin || 0;
    const dHi = a.dMax || 0;
    const hasSpread = dLo > 0 && dHi > 0 && dLo !== dHi;
    /** Combat always uses `dmg` when set; spread is legacy display only. */
    const combatDmg = (a.dmg || 0) > 0 ? a.dmg! : 0;
    const flatBracket = dLo > 0 && dHi > 0 && dLo === dHi ? dLo : 0;

    if (combatDmg > 0) {
      let s = `${combatDmg} dmg`;
      if (a.blastAll || a.multiHit) s += ' (all)';
      if (a.ignSh) s += ', pierce';
      parts.push(s);
    } else if (hasSpread) {
      let s = `${dLo}-${dHi} dmg`;
      if (a.blastAll || a.multiHit) s += ' (all)';
      if (a.ignSh) s += ', pierce';
      parts.push(s);
    } else if (flatBracket > 0) {
      let s = `${flatBracket} dmg`;
      if (a.blastAll || a.multiHit) s += ' (all)';
      if (a.ignSh) s += ', pierce';
      parts.push(s);
    }
    if (a.splitDmg && (combatDmg > 0 || hasSpread || flatBracket > 0)) parts.push('split');

    if ((a.heal || 0) > 0) {
      if (a.healAll) parts.push(`all ${a.heal} heal`);
      else if (a.healLowest) parts.push(`lowest ${a.heal} heal`);
      else if (a.healTgt) parts.push(`${a.heal} heal (ally)`);
      else if (combatDmg > 0 || hasSpread || flatBracket > 0) parts.push(`heal self ${a.heal}`);
      else parts.push(`${a.heal} heal`);
    }

    if ((a.shield || 0) > 0) {
      const t = (a.shT || 0) > 1 ? `, ${a.shT}t` : '';
      if (a.shieldAll) parts.push(`all ${a.shield} shield${t}`);
      else if (a.shTgt) parts.push(`ally ${a.shield} shield${t}`);
      else parts.push(`self ${a.shield} shield${t}`);
    }

    if ((a.dot || 0) > 0) {
      const t = (a.dT || 0) > 1 ? `, ${a.dT}t` : '';
      parts.push(`${a.dot} DoT${t}`);
    }

    if ((a.rfe || 0) > 0) {
      const t = (a.rfT || 0) > 1 ? `, ${a.rfT}t` : '';
      if (a.rfeAll) parts.push(`all -${a.rfe} roll${t}`);
      else parts.push(`-${a.rfe} roll${t}`);
    }

    if ((a.rfm || 0) > 0) {
      const t = (a.rfmT || 0) > 1 ? `, ${a.rfmT}t` : '';
      if (a.rfmTgt) parts.push(`+${a.rfm} roll ally${t}`);
      else if (a.shTgt && (a.shield || 0) > 0) parts.push(`+${a.rfm} roll any ally${t}`);
      else parts.push(`+${a.rfm} squad roll${t}`);
    }

    if (a.revive) parts.push('revive 50%');
    if (a.cloak) parts.push('Cloak');
    if (a.taunt) parts.push('taunt (picked enemy targets you)');
    if ((a.freezeAllEnemyDice || 0) > 0) {
      parts.push(`freeze (${a.freezeAllEnemyDice} reveal skip${(a.freezeAllEnemyDice || 0) > 1 ? 's' : ''})`);
    }
    if ((a.freezeEnemyDice || 0) > 0) {
      parts.push(`freeze (${a.freezeEnemyDice} reveal skip${(a.freezeEnemyDice || 0) > 1 ? 's' : ''})`);
    }
    if ((a.freezeAnyDice || 0) > 0) {
      parts.push(`freeze (${a.freezeAnyDice} reveal skip${(a.freezeAnyDice || 0) > 1 ? 's' : ''})`);
    }

    return parts.length ? parts.join(', ') : '—';
  }

  private buildEnemyEffectSummary(ab: EnemyAbility): string {
    const parts: string[] = [];
    if ((ab.dmg || 0) > 0) {
      if (ab.dmgP2 != null && ab.dmgP2 > 0 && ab.dmgP2 !== ab.dmg) {
        parts.push(`${ab.dmg} dmg (P2 ${ab.dmgP2})`);
      } else {
        parts.push(`${ab.dmg} dmg`);
      }
    }
    if ((ab.dot || 0) > 0) {
      const t = (ab.dT || 0) > 1 ? `, ${ab.dT}t` : '';
      parts.push(`${ab.dot} DoT${t}`);
    }
    if ((ab.rfm || 0) > 0) {
      const t = (ab.rfmT || 0) > 1 ? `, ${ab.rfmT}t` : '';
      parts.push(`-${ab.rfm} roll${t}`);
    }
    if (ab.wipeShields) parts.push('wipe shields');
    if ((ab.heal || 0) > 0) parts.push(`${ab.heal} heal`);
    if ((ab.shield || 0) > 0) {
      const t = (ab.shT || 0) > 1 ? `, ${ab.shT}t` : '';
      parts.push(`${ab.shield} shield${t}`);
    }
    if ((ab.shieldAlly || 0) > 0) {
      const t = (ab.shT || 0) > 1 ? `, ${ab.shT}t` : '';
      parts.push(`ally ${ab.shieldAlly} shield${t}`);
    }
    if ((ab.rfe || 0) > 0) {
      const t = (ab.rfT || 0) > 1 ? `, ${ab.rfT}t` : '';
      parts.push(`-${ab.rfe} roll${t}`);
    }
    if ((ab.lifestealPct || 0) > 0) parts.push(`lifesteal ${ab.lifestealPct}%`);
    if ((ab.erb || 0) > 0) {
      const t = (ab.erbT || 0) > 1 ? `, ${ab.erbT}t` : '';
      parts.push(ab.erbAll ? `+${ab.erb} roll to allies${t}` : `+${ab.erb} roll${t}`);
    }
    if ((ab.summonChance ?? 0) > 0) parts.push(`summon ~${ab.summonChance}% nat20`);
    if ((ab.counterspellPct ?? 0) > 0) {
      parts.push(`counter ${counterChipLabel(ab.counterspellPct!)}`);
    }
    if ((ab.grantRampage || 0) > 0) parts.push(`rampage +${ab.grantRampage}`);
    if ((ab.grantRampageAll || 0) > 0) parts.push(`rampage all +${ab.grantRampageAll}`);
    if ((ab.cowerT || 0) > 0) {
      parts.push(ab.cowerAll ? `cower all ${ab.cowerT}r` : `cower ${ab.cowerT}r`);
    }
    return parts.length ? parts.join(', ') : '—';
  }

  private multiTurn(turns: number | undefined): number | undefined {
    const t = turns ?? 0;
    return t > 1 ? t : undefined;
  }

  private durTurns(t: number | undefined): string {
    const n = t ?? 0;
    return n > 1 ? ` (${n} turns)` : '';
  }

  /** Hover for rampage grant chips — never prefixed with ability name. */
  private rampageDealTooltip(n: number): string {
    return n === 1
      ? 'Rampage: Next attack deals 2× damage'
      : `Rampage: Next ${n} attacks deal 2× damage`;
  }

  /** Fear / cower — body only (wrapped with `Fear:` via {@link keywordTokenTooltip}). */
  private fearEffectDescription(n: number, all: boolean): string {
    const t = n === 1 ? 'turn' : 'turns';
    const chunk = n === 1 ? 'their next turn' : `their next ${n} ${t}`;
    return all ? `All heroes skip ${chunk}` : `Target skips ${chunk}`;
  }

  /** DoT chip hover: X damage per turn, for the next Y turn(s). */
  private dotDealTooltip(amount: number, dT: number | undefined, blastAll: boolean): string {
    const y = Math.max(1, dT ?? 1);
    const tail = y === 1 ? 'for the next turn' : `for the next ${y} turns`;
    const core = `${amount} damage per turn, ${tail}`;
    return blastAll ? `${core} (all enemies)` : core;
  }

  private buildHeroMinis(a: HeroAbility): AbilityMiniToken[] {
    const out: AbilityMiniToken[] = [];
    const tip = (body: string) => this.namedTokenTooltip(a, body);
    const dLo = a.dMin || 0;
    const dHi = a.dMax || 0;
    const hasSpread = dLo > 0 && dHi > 0 && dLo !== dHi;
    const combatDmg = (a.dmg || 0) > 0 ? a.dmg! : 0;
    const flatBracket = dLo > 0 && dHi > 0 && dLo === dHi ? dLo : 0;
    const allDmg = a.blastAll || a.multiHit;
    if (combatDmg > 0) {
      const n = String(combatDmg);
      out.push({
        icon: 'bolt',
        num: n,
        tagAll: allDmg,
        tone: 'dmg',
        tooltip: tip(allDmg ? `${n} Damage (all enemies)` : `${n} Damage`),
      });
    } else if (hasSpread) {
      const lbl = `${dLo}-${dHi}`;
      out.push({
        icon: 'bolt',
        label: lbl,
        tagAll: allDmg,
        tone: 'dmg',
        tooltip: tip(allDmg ? `${lbl} Damage (all enemies)` : `${lbl} Damage`),
      });
    } else if (flatBracket > 0) {
      const n = String(flatBracket);
      out.push({
        icon: 'bolt',
        num: n,
        tagAll: allDmg,
        tone: 'dmg',
        tooltip: tip(allDmg ? `${n} Damage (all enemies)` : `${n} Damage`),
      });
    }
    if ((a.heal || 0) > 0) {
      const healSelf = !a.healAll && !a.healLowest && !a.healTgt;
      let ht: string;
      if (a.healAll) ht = `Heal ${a.heal} all`;
      else if (a.healLowest) ht = `Heal ${a.heal} lowest HP ally`;
      else if (a.healTgt) ht = `Heal ${a.heal} chosen ally`;
      else ht = `Heal ${a.heal} self`;
      out.push({
        icon: 'plus',
        num: String(a.heal),
        tagAll: !!a.healAll,
        tagSelf: healSelf,
        tone: 'heal',
        tooltip: tip(ht),
      });
    }
    if ((a.shield || 0) > 0) {
      const shieldSelf = !a.shieldAll && !a.shTgt;
      const d = this.durTurns(a.shT);
      let st: string;
      if (a.shieldAll) st = `Shield ${a.shield} all${d}`;
      else if (a.shTgt) st = `Shield ${a.shield} chosen ally${d}`;
      else st = `Shield ${a.shield} self${d}`;
      out.push({
        icon: 'shield',
        num: String(a.shield),
        tagAll: !!a.shieldAll,
        tagSelf: shieldSelf,
        turns: this.multiTurn(a.shT),
        tone: 'shield',
        tooltip: tip(st),
      });
    }
    if ((a.dot || 0) > 0) {
      out.push({
        icon: 'skull',
        num: String(a.dot),
        turns: this.multiTurn(a.dT),
        tone: 'dot',
        tooltip: tip(this.dotDealTooltip(a.dot, a.dT, !!a.blastAll)),
      });
    }
    if ((a.rfe || 0) > 0) {
      const d = this.durTurns(a.rfT);
      const rt = a.rfeAll
        ? `-${a.rfe} roll to all enemies${d}`
        : `-${a.rfe} roll to enemy${d}`;
      out.push({
        icon: 'die',
        num: `-${a.rfe}`,
        tagAll: !!a.rfeAll,
        turns: this.multiTurn(a.rfT),
        tone: 'rollFoe',
        tooltip: tip(rt),
      });
    }
    if ((a.rfm || 0) > 0) {
      const d = this.durTurns(a.rfmT);
      let mt: string;
      if (a.rfmTgt) mt = `+${a.rfm} roll on chosen ally's next roll${d}`;
      else if (a.shTgt && (a.shield || 0) > 0)
        mt = `+${a.rfm} roll on shield target's next roll${d}`;
      else mt = `+${a.rfm} roll on your next roll${d}`;
      out.push({
        icon: 'die',
        num: `+${a.rfm}`,
        turns: this.multiTurn(a.rfmT),
        tone: 'rollAlly',
        tooltip: tip(mt),
      });
    }
    if (a.ignSh) {
      out.push({
        icon: null,
        label: 'P',
        tone: 'dmg',
        tooltip: tip('Ignores target shields'),
      });
    }
    if (a.splitDmg) {
      out.push({
        icon: null,
        label: 'SPLIT',
        tone: 'dmg',
        tooltip: tip(
          "Split — Divide this ability's damage across enemies you assign. If you assign none, the full amount can hit your primary target.",
        ),
      });
    }
    if (a.revive) {
      out.push({
        icon: null,
        label: 'REVIVE',
        wide: true,
        tone: 'heal',
        tooltip: tip('Revive 1 dead ally at 50% health'),
      });
    }
    if (a.cloak) {
      out.push({
        icon: null,
        label: 'CLOAK',
        tone: 'control',
        tooltip: tip('80% chance to dodge enemy attacks next turn'),
      });
    }
    if (a.taunt) {
      out.push({
        icon: null,
        label: 'T',
        tone: 'control',
        tooltip: tip('Force the targeted enemy to attack you this player round'),
      });
    }
    if ((a.freezeAllEnemyDice || 0) > 0) {
      const n = a.freezeAllEnemyDice as number;
      const turns = n === 1 ? 'turn' : 'turns';
      out.push({
        icon: 'frost',
        num: `${n}×`,
        tone: 'control',
        tooltip: tip(`Freeze every enemy's die for ${n} ${turns}.`),
      });
    }
    if ((a.freezeEnemyDice || 0) > 0) {
      const n = a.freezeEnemyDice as number;
      const turns = n === 1 ? 'turn' : 'turns';
      out.push({
        icon: 'frost',
        num: `${n}×`,
        tone: 'control',
        tooltip: tip(`Freeze a target's die for ${n} ${turns}.`),
      });
    }
    if ((a.freezeAnyDice || 0) > 0) {
      const n = a.freezeAnyDice as number;
      const turns = n === 1 ? 'turn' : 'turns';
      out.push({
        icon: 'frost',
        num: `${n}×`,
        tone: 'control',
        tooltip: tip(`Freeze a target's die for ${n} ${turns}.`),
      });
    }
    if (!out.length) out.push({ icon: null, label: '—', tone: 'neutral', tooltip: '' });
    return out;
  }

  private buildEnemyMinis(ab: EnemyAbility): AbilityMiniToken[] {
    const out: AbilityMiniToken[] = [];
    const tip = (body: string) => this.namedTokenTooltip(ab, body);
    if ((ab.dmg || 0) > 0) {
      const n =
        ab.dmgP2 != null && ab.dmgP2 > 0 && ab.dmgP2 !== ab.dmg
          ? `${ab.dmg}/${ab.dmgP2}`
          : String(ab.dmg);
      const dmgTip =
        ab.dmgP2 != null && ab.dmgP2 > 0 && ab.dmgP2 !== ab.dmg
          ? `${ab.dmg} Damage (rises to ${ab.dmgP2} in phase 2)`
          : `${ab.dmg} Damage`;
      out.push({ icon: 'bolt', num: n, tone: 'dmg', tooltip: tip(dmgTip) });
    }
    if ((ab.dot || 0) > 0) {
      out.push({
        icon: 'skull',
        num: String(ab.dot),
        turns: this.multiTurn(ab.dT),
        tone: 'dot',
        tooltip: tip(this.dotDealTooltip(ab.dot, ab.dT, false)),
      });
    }
    if ((ab.rfm || 0) > 0) {
      out.push({
        icon: 'die',
        num: `-${ab.rfm}`,
        turns: this.multiTurn(ab.rfmT),
        tone: 'rollFoe',
        tooltip: tip(`-${ab.rfm} roll${this.durTurns(ab.rfmT)}`),
      });
    }
    if (ab.wipeShields) {
      out.push({
        icon: null,
        label: 'WIPE',
        tone: 'dmg',
        tooltip: tip('Remove shields from all heroes'),
      });
    }
    if ((ab.heal || 0) > 0) {
      out.push({
        icon: 'plus',
        num: String(ab.heal),
        tagSelf: true,
        tone: 'heal',
        tooltip: tip(`Heal ${ab.heal} lowest-HP ally`),
      });
    }
    if ((ab.shield || 0) > 0) {
      out.push({
        icon: 'shield',
        num: String(ab.shield),
        tagSelf: true,
        turns: this.multiTurn(ab.shT),
        tone: 'shield',
        tooltip: tip(`Shield ${ab.shield} self${this.durTurns(ab.shT)}`),
      });
    }
    if ((ab.shieldAlly || 0) > 0) {
      out.push({
        icon: 'shield',
        num: String(ab.shieldAlly),
        turns: this.multiTurn(ab.shT),
        tone: 'shield',
        tooltip: tip(`Shield ${ab.shieldAlly} ally${this.durTurns(ab.shT)}`),
      });
    }
    if ((ab.lifestealPct || 0) > 0) {
      const pct = ab.lifestealPct as number;
      out.push({
        icon: 'plus',
        num: `${pct}%`,
        tagSelf: false,
        tone: 'heal',
        tooltip: `Lifesteal: Heals ${pct}% of damage dealt.`,
      });
    }
    if ((ab.rfe || 0) > 0) {
      out.push({
        icon: 'die',
        num: `-${ab.rfe}`,
        turns: this.multiTurn(ab.rfT),
        tone: 'rollFoe',
        tooltip: tip(`-${ab.rfe} roll${this.durTurns(ab.rfT)}`),
      });
    }
    if ((ab.erb || 0) > 0) {
      const d = this.durTurns(ab.erbT);
      const et = ab.erbAll
        ? `+${ab.erb} roll to all living allies${d}`
        : `+${ab.erb} roll to self${d}`;
      out.push({
        icon: 'die',
        num: `+${ab.erb}`,
        tagAll: !!ab.erbAll,
        tagSelf: !ab.erbAll,
        turns: this.multiTurn(ab.erbT),
        tone: 'rollAlly',
        tooltip: tip(et),
      });
    }
    if ((ab.summonChance ?? 0) > 0) {
      const pct = ab.summonChance ?? 0;
      const name = ab.summonName?.trim();
      const pool = name ? ` Summons “${name}”.` : ' Uses the mode’s grunt pool.';
      out.push({
        icon: null,
        label: 'SUM',
        tone: 'control',
        tooltip: this.keywordTokenTooltip(
          'Summon',
          `On a natural 20 (with overload tier), ~${pct}% chance to add an extra grunt.${pool}`,
        ),
      });
    }
    if ((ab.counterspellPct ?? 0) > 0) {
      const pct = Math.max(0, Math.min(100, ab.counterspellPct!));
      out.push({
        icon: null,
        label: counterChipLabel(pct),
        wide: true,
        tone: 'control',
        tooltip: this.keywordTokenTooltip('Counter', counterAbilityTooltip(pct)),
      });
    }
    if ((ab.grantRampage || 0) > 0) {
      const g = ab.grantRampage as number;
      out.push({
        icon: 'bolt',
        label: 'R',
        ...(g > 1 ? { num: String(g) } : {}),
        tone: 'dmg',
        tooltip: this.rampageDealTooltip(g),
      });
    }
    if ((ab.grantRampageAll || 0) > 0) {
      const g = ab.grantRampageAll as number;
      out.push({
        icon: 'bolt',
        label: 'R',
        ...(g > 1 ? { num: String(g) } : {}),
        tagAll: true,
        tone: 'dmg',
        tooltip:
          g === 1
            ? `${this.rampageDealTooltip(1)} (each enemy)`
            : `Each enemy: ${this.rampageDealTooltip(g)}`,
      });
    }
    if ((ab.cowerT || 0) > 0) {
      const n = ab.cowerT as number;
      out.push({
        icon: null,
        label: 'F',
        tagAll: !!ab.cowerAll,
        turns: this.multiTurn(n),
        tone: 'fear',
        tooltip: this.keywordTokenTooltip('Fear', this.fearEffectDescription(n, !!ab.cowerAll)),
      });
    }
    if (!out.length) out.push({ icon: null, label: '—', tone: 'neutral', tooltip: '' });
    return out;
  }
}
