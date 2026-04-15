import { Injectable } from '@angular/core';
import { LogEntry } from '../models/game-state.interface';
import { LogClass } from '../models/types';
import { GameStateService } from './game-state.service';

const MAJOR_CLASSES = new Set<LogClass>(['pl', 'en', 'vi', 'de', 'sy']);

@Injectable({ providedIn: 'root' })
export class LogService {
  constructor(private state: GameStateService) {}

  log(msg: string, cls: LogClass = ''): void {
    this.state.addLog(msg, cls);
  }

  isMajorEntry(entry: LogEntry): boolean {
    return MAJOR_CLASSES.has(entry.cls);
  }

  getFilteredLog(): LogEntry[] {
    const log = this.state.log();
    if (this.state.logMode() === 'all') return log;
    return log.filter(e => this.isMajorEntry(e));
  }

  setMode(mode: 'min' | 'all'): void {
    this.state.logMode.set(mode);
  }

  toggleOpen(): void {
    this.state.logOpen.update(v => !v);
  }
}
