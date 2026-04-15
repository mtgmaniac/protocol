import { Injectable, Injector, inject } from '@angular/core';
import raw from '../data/json/items.data.json';
import type { ItemDefinition } from '../models/item.interface';
import type { ItemRarity } from '../models/types';
import { ITEM_PROTOCOL_COST, INVENTORY_MAX } from '../models/constants';
import { enemyRfeFromStacks } from '../models/enemy.interface';
import { GameStateService } from './game-state.service';
import { CombatService } from './combat.service';
import { RelicService } from './relic.service';
import { GearService } from './gear.service';
import { ALL_GEAR } from '../data/gear.data';
import { addShieldToUnit } from '../utils/shield-stack.util';

const ITEMS: ItemDefinition[] = (raw as { items: ItemDefinition[] }).items;
const BY_ID = new Map(ITEMS.map(i => [i.id, i]));

/**
 * Post-win draft: weighted tiers; legendary is very rare (~2% per slot).
 * Add new legendary consumables to items.data.json to grow the pool.
 */
const DRAFT_RARITY_WEIGHTS: Record<ItemRarity, number> = {
  common: 0.68,
  uncommon: 0.21,
  rare: 0.09,
  legendary: 0.02,
};

function pickDraftRarity(): ItemRarity {
  const r = Math.random();
  let c = 0;
  for (const tier of ['common', 'uncommon', 'rare', 'legendary'] as const) {
    c += DRAFT_RARITY_WEIGHTS[tier];
    if (r < c) return tier;
  }
  return 'common';
}

@Injectable({ providedIn: 'root' })
export class ItemService {
  private state = inject(GameStateService);
  private injector = inject(Injector);
  private relicService = inject(RelicService);
  private gearService = inject(GearService);
  private draftDone: (() => void) | null = null;

  private combat(): CombatService {
    return this.injector.get(CombatService);
  }

  allDefinitions(): ItemDefinition[] {
    return ITEMS;
  }

  getDef(id: string): ItemDefinition | undefined {
    return BY_ID.get(id);
  }

  protocolCost(def: ItemDefinition): number {
    // Protocol Override relic: all items cost 0
    if (this.relicService.isProtocolFree()) return 0;
    return ITEM_PROTOCOL_COST[def.rarity];
  }

  /** Extract and clear draftDone (used by gear overlay to hand off the callback). */
  consumeDraftDone(): (() => void) | null {
    const d = this.draftDone;
    this.draftDone = null;
    return d;
  }

  /** XP draft picks only when someone can still evolve (tier 1, not yet evolved). */
  private draftPoolAllowsXpBoost(): boolean {
    return this.state.heroes().some(h => h.tier === 1 && !h.evolvedTo);
  }

  private pickRandomDraftItemId(): string {
    const rarity = pickDraftRarity();
    // Build combined pool: regular items + gear (gear only at uncommon/rare, only when not all equipped)
    type PoolEntry = { id: string; isGear: boolean };
    let pool: PoolEntry[] = ITEMS
      .filter(i => i.rarity === rarity)
      .map(i => ({ id: i.id, isGear: false }));

    if ((rarity === 'uncommon' || rarity === 'rare') && !this.gearService.allLivingHeroesEquipped()) {
      const gearPool = ALL_GEAR.filter(g => g.rarity === rarity);
      pool.push(...gearPool.map(g => ({ id: g.id, isGear: true })));
    }

    if (!this.draftPoolAllowsXpBoost()) {
      pool = pool.filter(p => p.isGear || this.getDef(p.id)?.effect.type !== 'xpBoost');
    }
    if (!pool.length) pool = [{ id: ITEMS[0]!.id, isGear: false }];
    const pick = pool[Math.floor(Math.random() * pool.length)];
    return pick?.id ?? ITEMS[0]!.id;
  }

  /** Begin post-win draft if there is inventory space; otherwise run `done` immediately. */
  startPostWinDraft(done: () => void): void {
    const inv = this.state.inventory();
    // Skip if inventory is full AND all heroes have gear (nothing useful can be offered)
    const invFull = inv.every(x => x != null);
    const gearFull = this.gearService.allLivingHeroesEquipped();
    if (invFull && gearFull) {
      this.state.addLog('Supply cache: inventory full and all heroes equipped. Skipped.', 'sy');
      done();
      return;
    }
    this.draftDone = done;
    const picks: string[] = [];
    for (let i = 0; i < 3; i++) {
      picks.push(this.pickRandomDraftItemId());
    }
    this.state.itemDraftChoices.set(picks);
  }

  skipDraft(): void {
    this.state.itemDraftChoices.set(null);
    const d = this.draftDone;
    this.draftDone = null;
    d?.();
  }

  /** Close draft UI without running the post-win continuation (e.g. dev skip battle). */
  abortDraftSilently(): void {
    this.state.itemDraftChoices.set(null);
    this.draftDone = null;
  }

  pickDraftItem(itemId: string): void {
    // Route gear picks to gear assignment flow
    if (this.gearService.isGearId(itemId)) {
      this.state.itemDraftChoices.set(null);
      const done = this.consumeDraftDone();
      this.gearService.startGearAssign(itemId, done ?? (() => {}));
      return;
    }
    if (!this.getDef(itemId)) return;
    const added = this.tryAddToInventory(itemId);
    if (!added) {
      this.state.addLog('Could not stash item — inventory full.', 'sy');
    } else {
      const d = this.getDef(itemId);
      this.state.addLog(`▸ Supply cache: took ${d?.name ?? itemId}.`, 'vi');
    }
    this.state.itemDraftChoices.set(null);
    const cb = this.draftDone;
    this.draftDone = null;
    cb?.();
  }

  tryAddToInventory(itemId: string): boolean {
    let ok = false;
    this.state.inventory.update(inv => {
      const next = [...inv];
      while (next.length < INVENTORY_MAX) next.push(null);
      const empty = next.findIndex(x => x == null);
      if (empty < 0) return inv;
      next[empty] = itemId;
      ok = true;
      return next;
    });
    return ok;
  }

  /** Toggle: same slot cancels. */
  beginUseInventorySlot(slot: number): void {
    if (!this.state.isPlayerPhase()) return;
    const id = this.state.inventory()[slot];
    if (!id) return;
    const def = this.getDef(id);
    if (!def) return;
    const cost = this.protocolCost(def);
    if (this.state.protocol() < cost) {
      this.state.addLog(`Not enough Protocol (${cost} needed for ${def.name}).`, 'sy');
      return;
    }

    const cur = this.state.pendingItemSelection();
    if (cur?.invSlot === slot) {
      this.state.pendingItemSelection.set(null);
      return;
    }

    this.state.pendingProtocol.set(null);
    this.state.selectedHeroIdx.set(null);

    const block = this.itemUseBlockedMessage(def);
    if (block) {
      this.state.addLog(block, 'sy');
      return;
    }

    if (def.target === 'none') {
      this.commitConsumeAndApply(slot, def, null, null);
      return;
    }

    this.state.pendingItemSelection.set({ invSlot: slot, itemId: id });
  }

  cancelPendingItem(): void {
    this.state.pendingItemSelection.set(null);
  }

  confirmOnAllyLiving(invSlot: number, heroIdx: number): void {
    const pending = this.state.pendingItemSelection();
    if (!pending || pending.invSlot !== invSlot) return;
    const def = this.getDef(pending.itemId);
    if (!def || def.target !== 'ally') return;
    const h = this.state.heroes()[heroIdx];
    if (!h || h.currentHp <= 0) return;
    this.commitConsumeAndApply(invSlot, def, heroIdx, null);
  }

  confirmOnAllyDead(invSlot: number, heroIdx: number): void {
    const pending = this.state.pendingItemSelection();
    if (!pending || pending.invSlot !== invSlot) return;
    const def = this.getDef(pending.itemId);
    if (!def || def.target !== 'allyDead') return;
    const h = this.state.heroes()[heroIdx];
    if (!h || h.currentHp > 0) return;
    this.commitConsumeAndApply(invSlot, def, heroIdx, null);
  }

  confirmOnEnemy(invSlot: number, enemyIdx: number): void {
    const pending = this.state.pendingItemSelection();
    if (!pending || pending.invSlot !== invSlot) return;
    const def = this.getDef(pending.itemId);
    if (!def || def.target !== 'enemy') return;
    const e = this.state.enemies()[enemyIdx];
    if (!e || e.dead) return;
    this.commitConsumeAndApply(invSlot, def, null, enemyIdx);
  }

  /** Blocks using items that depend on the enemy tray state (before spending Protocol). */
  private itemUseBlockedMessage(def: ItemDefinition): string | null {
    const eff = def.effect;
    if (eff.type === 'enemyRerollDie' || eff.type === 'enemyDieFreeze' || eff.type === 'enemyRerollAll') {
      if (!this.state.enemyTrayRevealed()) return 'Enemy dice not revealed yet.';
    }
    if (eff.type === 'xpBoost') {
      if (!this.state.heroes().some(h => h.tier === 1 && !h.evolvedTo && h.currentHp > 0)) {
        return 'No evolving heroes can take XP.';
      }
    }
    return null;
  }

  private commitConsumeAndApply(
    invSlot: number,
    def: ItemDefinition,
    allyIdx: number | null,
    enemyIdx: number | null,
  ): void {
    const block = this.itemUseBlockedMessage(def);
    if (block) {
      this.state.addLog(block, 'sy');
      return;
    }

    const cost = this.protocolCost(def);
    if (this.state.protocol() < cost) return;

    this.state.protocol.update(p => p - cost);
    this.state.inventory.update(inv => {
      const next = [...inv];
      if (next[invSlot] === def.id) next[invSlot] = null;
      return next;
    });
    this.state.pendingItemSelection.set(null);

    const eff = def.effect;
    if (eff.type === 'heal' && allyIdx != null) {
      const h = this.state.heroes()[allyIdx];
      if (h && h.currentHp > 0) {
        const nh = Math.min(h.maxHp, h.currentHp + eff.amount);
        this.state.updateHero(allyIdx, { currentHp: nh });
        this.state.addLog(`▸ Item: ${def.name} → ${h.name} (+${eff.amount} HP).`, 'pl');
      }
    } else if (eff.type === 'shield' && allyIdx != null) {
      const h = this.state.heroes()[allyIdx];
      if (h && h.currentHp > 0) {
        this.state.updateHero(allyIdx, addShieldToUnit(h, eff.amount, eff.shT));
        this.state.addLog(`▸ Item: ${def.name} → ${h.name} (+${eff.amount} shield, ${eff.shT}t).`, 'pl');
      }
    } else if (eff.type === 'rollBuff' && allyIdx != null) {
      const h = this.state.heroes()[allyIdx];
      if (h && h.currentHp > 0) {
        this.state.updateHero(allyIdx, {
          pendingRollBuff: (h.pendingRollBuff || 0) + eff.amount,
          pendingRollBuffT: Math.max(h.pendingRollBuffT || 0, eff.turns),
        });
        this.state.addLog(`▸ Item: ${def.name} → ${h.name} (+${eff.amount} roll, ${eff.turns}t).`, 'pl');
      }
    } else if (eff.type === 'revive' && allyIdx != null) {
      const h = this.state.heroes()[allyIdx];
      if (h && h.currentHp <= 0) {
        const nh = Math.max(1, Math.round(h.maxHp * (eff.pct / 100)));
        this.state.updateHero(allyIdx, { currentHp: nh, dot: 0, dT: 0, shield: 0, shT: 0, shieldStacks: [] });
        this.state.addLog(`▸ Item: ${def.name} → revived ${h.name} at ${nh}/${h.maxHp} HP.`, 'pl');
      }
    } else if (eff.type === 'enemyRfe' && enemyIdx != null) {
      const e = this.state.enemies()[enemyIdx];
      if (e && !e.dead && e.currentHp > 0) {
        const nextStacks = [...(e.rfeStacks || []), { amt: eff.amount, turnsLeft: eff.rfT }];
        const { rfe, rfT } = enemyRfeFromStacks(nextStacks);
        this.state.updateEnemy(enemyIdx, { rfeStacks: nextStacks, rfe, rfT });
        this.combat().recomputeEnemy(enemyIdx);
        this.state.addLog(`▸ Item: ${def.name} → ${e.name} (−${eff.amount} roll, ${eff.rfT}t).`, 'pl');
      }
    } else if (eff.type === 'cloak' && allyIdx != null) {
      const h = this.state.heroes()[allyIdx];
      if (h && h.currentHp > 0) {
        this.state.updateHero(allyIdx, { cloaked: true });
        this.state.addLog(`▸ Item: ${def.name} → ${h.name} is cloaked.`, 'pl');
      }
    } else if (eff.type === 'cloakAll') {
      const heroes = this.state.heroes();
      let n = 0;
      for (let i = 0; i < heroes.length; i++) {
        const h = heroes[i];
        if (h && h.currentHp > 0) {
          this.state.updateHero(i, { cloaked: true });
          n++;
        }
      }
      if (n > 0) {
        this.state.addLog(`▸ Item: ${def.name} → whole squad cloaked (${n}).`, 'pl');
      }
    } else if (eff.type === 'enemyDmg' && enemyIdx != null) {
      const e = this.state.enemies()[enemyIdx];
      if (e && !e.dead && e.currentHp > 0) {
        this.combat().applyDamageToEnemy(enemyIdx, eff.amount, def.name, false);
      }
    } else if (eff.type === 'enemyDot' && enemyIdx != null) {
      const e = this.state.enemies()[enemyIdx];
      if (e && !e.dead && e.currentHp > 0) {
        const dot = (e.dot || 0) + eff.amount;
        const dT = Math.max(e.dT || 0, eff.dT);
        this.state.updateEnemy(enemyIdx, { dot, dT });
        const dur = eff.dT > 1 ? `, ${eff.dT}t` : '';
        this.state.addLog(`▸ Item: ${def.name} → ${e.name} (${eff.amount} DoT${dur}).`, 'pl');
      }
    } else if (eff.type === 'xpBoost') {
      const heroes = this.state.heroes();
      let n = 0;
      for (let i = 0; i < heroes.length; i++) {
        const h = heroes[i];
        if (!h || h.currentHp <= 0 || h.tier !== 1 || h.evolvedTo) continue;
        this.state.updateHero(i, { xp: h.xp + eff.amount });
        n++;
      }
      if (n > 0) {
        this.state.addLog(`▸ Item: ${def.name} → +${eff.amount} XP (${n} hero${n > 1 ? 'es' : ''}).`, 'pl');
      }
    } else if (eff.type === 'enemyRerollDie' && enemyIdx != null) {
      this.combat().rerollEnemyDie(enemyIdx, def.name);
    } else if (eff.type === 'enemyRerollAll') {
      this.combat().rerollAllEnemyDice(def.name);
    } else if (eff.type === 'enemyDieFreeze' && enemyIdx != null) {
      const e = this.state.enemies()[enemyIdx];
      if (e && !e.dead && e.currentHp > 0) {
        const n = (e.dieFreezeRollsRemaining || 0) + eff.skips;
        this.state.updateEnemy(enemyIdx, { dieFreezeRollsRemaining: n });
        const rolls = eff.skips === 1 ? '1 roll' : `${eff.skips} rolls`;
        this.state.addLog(`▸ Item: ${def.name} → ${e.name} skips next ${rolls} on the tray.`, 'pl');
      }
    }
  }
}
