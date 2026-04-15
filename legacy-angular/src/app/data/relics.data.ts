import rawRelics from './json/relics.data.json';
import type { RelicDefinition } from '../models/relic.interface';

export const ALL_RELICS: RelicDefinition[] = rawRelics as RelicDefinition[];

export function relicById(id: string): RelicDefinition | undefined {
  return ALL_RELICS.find(r => r.id === id);
}
