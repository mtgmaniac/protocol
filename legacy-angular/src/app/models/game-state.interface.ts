import { LogClass } from './types';

export interface LogEntry {
  msg: string;
  cls: LogClass;
}

export type TutorialUiHighlight =
  | 'enemy'
  | 'heroes'
  | 'dice'
  | 'protocolMeter'
  | 'protocolIcons'
  | 'mainRoll'
  | 'help'
  | null;

export interface TutorialState {
  active: boolean;
  introStep: number;
  introComplete: boolean;
  /** Enemy phases finished (1 = after first enemy, open turn-2 brief; 2 = tutorial done). */
  resolutions: number;
  showComplete: boolean;
  /**
   * Post-intro coach on round 1: 0 = idle until squad roll, 1 = Pulse→drone, 2 = Shield→ally,
   * 3 = Medic roll-buff ally, 4 = prompt END TURN, 5 = hidden after END TURN resolves.
   */
  coachStep: number;
}

export interface PendingEvolution {
  heroIdx: number;
  chosen: number | null;
}
