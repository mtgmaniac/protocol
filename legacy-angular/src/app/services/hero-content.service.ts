import { Injectable, signal } from '@angular/core';
import { HeroDefinition } from '../models/hero.interface';
import { HeroId, Zone } from '../models/types';
import { ALL_HEROES, HERO_ZONES } from '../data/heroes.data';

const STORAGE_KEY = 'op-dev-hero-content-v1';

export type HeroZoneBrackets = Record<HeroId, [number, number, Zone][]>;

function cloneHeroes(list: HeroDefinition[]): HeroDefinition[] {
  return structuredClone(list) as HeroDefinition[];
}

function cloneZones(z: HeroZoneBrackets): HeroZoneBrackets {
  return structuredClone(z) as HeroZoneBrackets;
}

function isValidRoster(heroes: HeroDefinition[]): boolean {
  if (heroes.length !== 8) return false;
  const need = new Set<HeroId>([
    'pulse',
    'combat',
    'shield',
    'avalanche',
    'medic',
    'engineer',
    'ghost',
    'breaker',
  ]);
  const ids = new Set(heroes.map(h => h.id));
  return ids.size === 8 && [...need].every(id => ids.has(id));
}

const BUNDLED_HERO_BY_ID = new Map(ALL_HEROES.map(h => [h.id, h]));

/** Fill squad-picker fields from bundle when loading legacy saves / imports. */
function normalizeHeroDefinitions(heroes: HeroDefinition[]): HeroDefinition[] {
  return heroes.map(h => {
    const base = BUNDLED_HERO_BY_ID.get(h.id);
    if (!base) return h;
    const cat = h.pickerCategory ?? base.pickerCategory;
    const blurb = h.pickerBlurb?.trim() ? h.pickerBlurb : base.pickerBlurb;
    return { ...h, pickerCategory: cat, pickerBlurb: blurb };
  });
}

/**
 * Mutable hero definitions + per-hero zone brackets. Bundled JSON is the default;
 * dev tools can override and persist to localStorage (dev builds only).
 */
@Injectable({ providedIn: 'root' })
export class HeroContentService {
  private readonly _heroes = signal<HeroDefinition[]>(cloneHeroes(ALL_HEROES));
  private readonly _heroZones = signal<HeroZoneBrackets>(cloneZones(HERO_ZONES as HeroZoneBrackets));

  readonly heroes = this._heroes.asReadonly();
  readonly heroZones = this._heroZones.asReadonly();

  constructor() {
    this.hydrateFromLocalStorage();
  }

  getHero(id: HeroId): HeroDefinition | undefined {
    return this._heroes().find(h => h.id === id);
  }

  setHeroDefinition(def: HeroDefinition): void {
    const normalized = normalizeHeroDefinitions([def])[0]!;
    const next = cloneHeroes(this._heroes());
    const i = next.findIndex(h => h.id === normalized.id);
    if (i < 0) return;
    next[i] = structuredClone(normalized) as HeroDefinition;
    this._heroes.set(next);
  }

  setZonesForHero(id: HeroId, brackets: [number, number, Zone][]): void {
    const z = cloneZones(this._heroZones());
    z[id] = structuredClone(brackets) as [number, number, Zone][];
    this._heroZones.set(z);
  }

  /** Replace all heroes (same 6 ids as bundle). */
  setAllHeroes(heroes: HeroDefinition[]): void {
    this._heroes.set(cloneHeroes(normalizeHeroDefinitions(heroes)));
  }

  setAllZones(zones: HeroZoneBrackets): void {
    this._heroZones.set(cloneZones(zones));
  }

  persistToLocalStorage(): void {
    try {
      const payload = {
        heroes: this._heroes(),
        heroZones: this._heroZones(),
      };
      localStorage.setItem(STORAGE_KEY, JSON.stringify(payload));
    } catch {
      /* quota / private mode */
    }
  }

  clearLocalAndResetBundled(): void {
    try {
      localStorage.removeItem(STORAGE_KEY);
    } catch {
      /* ignore */
    }
    this._heroes.set(cloneHeroes(ALL_HEROES));
    this._heroZones.set(cloneZones(HERO_ZONES as HeroZoneBrackets));
  }

  exportJson(): string {
    return JSON.stringify(
      {
        $schema: '../schemas/heroes.data.schema.json',
        heroZones: this._heroZones(),
        heroes: this._heroes(),
      },
      null,
      2,
    );
  }

  importJson(text: string): { ok: true } | { ok: false; error: string } {
    try {
      const data = JSON.parse(text) as { heroes?: HeroDefinition[]; heroZones?: HeroZoneBrackets };
      if (!data.heroes || !Array.isArray(data.heroes) || data.heroes.length < 1) {
        return { ok: false, error: 'Missing heroes array' };
      }
      const roster = data.heroes as HeroDefinition[];
      if (!isValidRoster(roster)) {
        return {
          ok: false,
          error:
            'Need exactly 8 heroes: pulse, combat, shield, avalanche, medic, engineer, ghost, breaker',
        };
      }
      this.setAllHeroes(roster);
      if (data.heroZones && typeof data.heroZones === 'object') {
        this.setAllZones(data.heroZones as HeroZoneBrackets);
      }
      return { ok: true };
    } catch (e) {
      return { ok: false, error: e instanceof Error ? e.message : 'Invalid JSON' };
    }
  }

  private hydrateFromLocalStorage(): void {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return;
      const data = JSON.parse(raw) as { heroes?: HeroDefinition[]; heroZones?: HeroZoneBrackets };
      if (!data.heroes || !Array.isArray(data.heroes) || data.heroes.length !== 8) return;
      this.setAllHeroes(data.heroes as HeroDefinition[]);
      if (data.heroZones && typeof data.heroZones === 'object') {
        this.setAllZones(data.heroZones);
      }
    } catch {
      /* ignore bad storage */
    }
  }
}
