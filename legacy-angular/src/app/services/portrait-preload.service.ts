import { Injectable } from '@angular/core';
import { DICE_SPRITE_URL, enemyPortraitHref, heroPortraitHref } from '../data/sprites.data';
import type { HeroState } from '../models/hero.interface';
import type { EnemyState } from '../models/enemy.interface';
import type { EnemyType } from '../models/types';

/**
 * SVG portraits reference PNGs via <image href>; those requests often start late.
 * Warm the HTTP cache with Image() (high fetch priority) before / while the battle view renders.
 */
@Injectable({ providedIn: 'root' })
export class PortraitPreloadService {
  private readonly kicked = new Set<string>();

  warmHeroPortraits(heroes: HeroState[]): void {
    for (const h of heroes) {
      this.kick(heroPortraitHref(h.id, h.portraitPath));
    }
  }

  warmEnemyPortraits(enemies: EnemyState[]): void {
    for (const e of enemies) {
      if (!e.dead) this.kick(enemyPortraitHref(e.type));
    }
  }

  warmEnemyTypes(types: EnemyType[]): void {
    for (const t of types) {
      this.kick(enemyPortraitHref(t));
    }
  }

  /** Squad + encounter portraits for the battle about to display. */
  warmBattle(heroes: HeroState[], enemies: EnemyState[]): void {
    this.warmHeroPortraits(heroes);
    this.warmEnemyPortraits(enemies);
  }

  /** D20 sheet: `<link rel=preload>` + decode so CSS background isn’t the first fetch. */
  warmDiceSpriteSheet(): void {
    const url = DICE_SPRITE_URL;
    this.injectLinkPreloadOnce(url);
    this.kick(url);
  }

  private injectLinkPreloadOnce(url: string): void {
    if (typeof document === 'undefined') return;
    const id = 'op-preload-dice-sheet';
    if (document.getElementById(id)) return;
    const link = document.createElement('link');
    link.id = id;
    link.rel = 'preload';
    link.as = 'image';
    link.href = url;
    document.head.appendChild(link);
  }

  private kick(url: string | undefined): void {
    if (!url || this.kicked.has(url)) return;
    this.kicked.add(url);
    if (typeof Image === 'undefined') return;
    const img = new Image();
    if ('fetchPriority' in img) {
      (img as HTMLImageElement & { fetchPriority?: string }).fetchPriority = 'high';
    }
    img.src = url;
  }
}
