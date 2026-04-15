import type { HeroDefinition } from '../models/hero.interface';
import type { HeroId, Zone } from '../models/types';
import raw from './json/heroes.data.json';

/** Per-hero d20 zone brackets — edit `json/heroes.data.json` (see schema for shape). */
export const HERO_ZONES = raw.heroZones as Record<HeroId, [number, number, Zone][]>;

/** Squad roster definitions — edit `json/heroes.data.json`. */
export const ALL_HEROES = raw.heroes as HeroDefinition[];
