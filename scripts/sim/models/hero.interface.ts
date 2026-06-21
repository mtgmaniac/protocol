import type { HeroAbility } from './ability.interface';
import type { HeroId } from './types';

/** Squad picker grouping on the operation overlay. */
export type HeroPickerCategory = 'damage' | 'defense' | 'support' | 'control';

export interface EvolutionTier {
  name: string;
  focus: string;
  hp: number;
  abilities: HeroAbility[];
}

export interface HeroDefinition {
  id: HeroId;
  name: string;
  cls: string;
  pickerCategory: HeroPickerCategory;
  pickerBlurb: string;
  hp: number;
  sk: HeroId;
  portraitPath?: string;
  abilities: HeroAbility[];
  evolutions: EvolutionTier[];
}
