import { Injectable, computed, inject } from '@angular/core';
import { GameStateService } from './game-state.service';
import { ALL_RELICS, relicById } from '../data/relics.data';
import type { RelicDefinition } from '../models/relic.interface';

@Injectable({ providedIn: 'root' })
export class RelicService {
  private readonly state = inject(GameStateService);

  /** Ids of the two relics shown in the draft. Null = draft not active. */
  readonly draftChoices = computed(() => this.state.relicDraftChoices());

  /** The active relic definition, or null if none chosen yet. */
  readonly activeRelic = computed((): RelicDefinition | null => {
    const ids = this.state.relics();
    if (!ids.length) return null;
    return relicById(ids[0]) ?? null;
  });

  private draftOnDone: (() => void) | null = null;

  // ── Lookup ──────────────────────────────────────────────────────────────────

  getDef(id: string): RelicDefinition | undefined {
    return relicById(id);
  }

  hasRelic(id: string): boolean {
    return this.state.relics().includes(id);
  }

  // ── Effect value queries (used by CombatService / ItemService) ──────────────

  /** Iron Curtain: 0.75; otherwise 1. Apply to enemy damage before shield. */
  getEnemyDmgMult(): number {
    return this.hasRelic('ironCurtain') ? 0.75 : 1;
  }

  /** Overcharge: 1.3; otherwise 1. Applied to hero ability direct damage (ceil). */
  getHeroDmgMult(): number {
    return this.hasRelic('overcharge') ? 1.3 : 1;
  }

  /** Resonance Cascade: +2 per DoT tick on enemies; otherwise 0. */
  getDotBonus(): number {
    return this.hasRelic('resonanceCascade') ? 2 : 0;
  }

  /** Chain Reaction: 4 splash damage to surviving enemies on any enemy death; otherwise 0. */
  getChainReactionDmg(): number {
    return this.hasRelic('chainReaction') ? 4 : 0;
  }

  /** Protocol Override: items cost 0 Protocol. */
  isProtocolFree(): boolean {
    return this.hasRelic('protocolOverride');
  }

  // ── Draft ───────────────────────────────────────────────────────────────────

  startRelicDraft(onDone: () => void): void {
    const takenIds = this.state.relics();
    const available = ALL_RELICS.filter(r => !takenIds.includes(r.id));
    if (available.length === 0) {
      onDone();
      return;
    }
    // Shuffle and take 2 (or 1 if only 1 remains)
    const shuffled = [...available].sort(() => Math.random() - 0.5);
    const choices = shuffled.slice(0, Math.min(2, shuffled.length)).map(r => r.id);
    this.draftOnDone = onDone;
    this.state.relicDraftChoices.set(choices);
  }

  pickRelic(id: string): void {
    this.state.relics.update(r => [...r, id]);
    this.state.relicDraftChoices.set(null);
    const cb = this.draftOnDone;
    this.draftOnDone = null;
    cb?.();
  }
}
