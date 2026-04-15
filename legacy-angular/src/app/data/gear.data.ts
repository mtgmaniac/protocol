import rawGear from './json/gear.data.json';
import type { GearDefinition } from '../models/gear.interface';

export const ALL_GEAR: GearDefinition[] = (rawGear as { gear: GearDefinition[] }).gear;
export const GEAR_BY_ID = new Map(ALL_GEAR.map(g => [g.id, g]));

export function gearById(id: string): GearDefinition | undefined {
  return GEAR_BY_ID.get(id);
}
