import { Component, inject, isDevMode } from '@angular/core';
import { GameComponent } from './components/game/game.component';
import { DevHeroEditorComponent } from './components/dev/dev-hero-editor.component';
import { PortraitPreloadService } from './services/portrait-preload.service';

@Component({
  selector: 'app-root',
  imports: [GameComponent, DevHeroEditorComponent],
  template: `
    <app-game />
    @if (devMode) {
      <app-dev-hero-editor />
    }
  `,
  styleUrl: './app.scss',
})
export class App {
  /** In-game hero data editor + localStorage overrides (stripped from production builds). */
  readonly devMode = isDevMode();

  private portraitPreload = inject(PortraitPreloadService);

  constructor() {
    this.portraitPreload.warmDiceSpriteSheet();
  }
}
