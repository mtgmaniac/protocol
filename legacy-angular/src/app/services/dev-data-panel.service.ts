import { Injectable, signal } from '@angular/core';

/** Opens the local dev game-data editor from Help (dev builds only). */
@Injectable({ providedIn: 'root' })
export class DevDataPanelService {
  readonly open = signal(false);

  openPanel(): void {
    this.open.set(true);
  }

  closePanel(): void {
    this.open.set(false);
  }
}
