import { EnemyType, HeroId } from '../models/types';

/**
 * Raster format for bundled portrait paths and the d20 sheet (`npm run optimize-assets` writes lossless `.webp` siblings).
 * Use `.webp` after running the optimizer for smaller downloads with identical pixels; keep `.png` until those files exist.
 */
export const RASTER_EXT: '.png' | '.webp' = '.png';

const r = (pathWithoutExt: string) => `${pathWithoutExt}${RASTER_EXT}`;

/** D20 sprite sheet — same folder as `public/dice/`. */
export const DICE_SPRITE_URL = r('dice/d20-sprite');

function portraitOverrideUrl(url: string): string {
  if (RASTER_EXT === '.png') return url;
  if (/\.webp($|[?#])/i.test(url)) return url;
  return url.replace(/\.png($|[?#])/i, '.webp$1');
}

/** CSS pixel size of `app-portrait-frame` for heroes and enemy cards (keep in sync with portrait-frame). */
export const HERO_PORTRAIT_FRAME = { width: 100, height: 132 } as const;

/** ViewBox for portrait `<image>`: uniform scale + center crop (`slice`), never non-uniform stretch. */
const PORTRAIT_IMG_W = 240;
const PORTRAIT_IMG_H = 317;

/** Full-bleed portraits — matched art style (combat reference); flavor per unit. */
export const HERO_PORTRAIT_PATHS: Record<HeroId, string> = {
  pulse: r('heroes/pulse-portrait'),
  combat: r('heroes/combat-portrait'),
  shield: r('heroes/shield-portrait'),
  avalanche: r('heroes/avalanche-portrait'),
  medic: r('heroes/medic-portrait'),
  engineer: r('heroes/engineer-portrait'),
  ghost: r('heroes/ghost-portrait'),
  breaker: r('heroes/breaker-portrait'),
};

/** Same href as embedded in `heroPortraitSvg` — use for preload. */
export function heroPortraitHref(id: HeroId, portraitPathOverride?: string | null): string {
  const o = portraitPathOverride?.trim();
  return o && o.length > 0 ? portraitOverrideUrl(o) : HERO_PORTRAIT_PATHS[id];
}

export function heroPortraitSvg(id: HeroId, portraitPathOverride?: string | null): string {
  const { width: pw, height: ph } = HERO_PORTRAIT_FRAME;
  const href = heroPortraitHref(id, portraitPathOverride);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${pw}" height="${ph}" viewBox="0 0 ${PORTRAIT_IMG_W} ${PORTRAIT_IMG_H}" preserveAspectRatio="xMidYMid slice"><image href="${href}" xlink:href="${href}" x="0" y="0" width="${PORTRAIT_IMG_W}" height="${PORTRAIT_IMG_H}" preserveAspectRatio="xMidYMid slice"/></svg>`;
}

/** Robotic unit busts under `public/enemies/` — same intrinsic size as hero portraits. */
const ENEMY_STANDALONE_PORTRAIT: Record<EnemyType, string> = {
  scrap: r('enemies/scrap-portrait'),
  rust: r('enemies/rust-portrait'),
  patrol: r('enemies/patrol-portrait'),
  guard: r('enemies/guard-portrait'),
  warden: r('enemies/warden-portrait'),
  volt: r('enemies/volt-portrait'),
  boss: r('enemies/boss-portrait'),
  skitter: r('enemies/skitter-portrait'),
  mite: r('enemies/mite-portrait'),
  stalker: r('enemies/stalker-portrait'),
  carapace: r('enemies/carapace-portrait'),
  brood: r('enemies/brood-portrait'),
  spewer: r('enemies/spewer-portrait'),
  hiveBoss: r('enemies/hive-boss-portrait'),
  veilShard: r('enemies/veil-shard-portrait'),
  veilPrism: r('enemies/veil-prism-portrait'),
  veilAegis: r('enemies/veil-aegis-portrait'),
  veilResonance: r('enemies/veil-resonance-portrait'),
  veilNull: r('enemies/veil-null-portrait'),
  veilStorm: r('enemies/veil-storm-portrait'),
  veilSynapse: r('enemies/veil-synapse-portrait'),
  veilBoss: r('enemies/veil-boss-portrait'),
  voidWisp: r('enemies/void-wisp-portrait'),
  voidAcolyte: r('enemies/void-acolyte-portrait'),
  voidScribe: r('enemies/void-scribe-portrait'),
  voidBinder: r('enemies/void-binder-portrait'),
  voidGlimmer: r('enemies/void-glimmer-portrait'),
  voidChanneler: r('enemies/void-channeler-portrait'),
  voidCircletBoss: r('enemies/void-circlet-boss-portrait'),
  beastMonkey: r('enemies/rift-macaque-portrait'),
  beastWolf: r('enemies/void-wolf-portrait'),
  beastLynx: r('enemies/eclipse-lynx-portrait'),
  beastBison: r('enemies/thunder-bison-portrait'),
  beastHyena: r('enemies/eclipse-hyena-portrait'),
  beastBadger: r('enemies/ridge-badger-portrait'),
  beastTyrant: r('enemies/void-reaver-portrait'),
  signalSkimmer: r('enemies/rust-portrait'),
  commsHex: r('enemies/volt-portrait'),
};

/** Same href as embedded in `enemyPortraitSvg` — use for preload. */
export function enemyPortraitHref(type: EnemyType): string {
  return ENEMY_STANDALONE_PORTRAIT[type];
}

export function enemyPortraitSvg(type: EnemyType): string {
  const { width: pw, height: ph } = HERO_PORTRAIT_FRAME;
  const href = enemyPortraitHref(type);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${pw}" height="${ph}" viewBox="0 0 ${PORTRAIT_IMG_W} ${PORTRAIT_IMG_H}" preserveAspectRatio="xMidYMid slice"><image href="${href}" xlink:href="${href}" x="0" y="0" width="${PORTRAIT_IMG_W}" height="${PORTRAIT_IMG_H}" preserveAspectRatio="xMidYMid slice"/></svg>`;
}

export const BDG_SVG: Record<string, string> = {
  bolt: `<svg class="bdg-svg" viewBox="0 0 24 24" fill="none"><path d="M13 2L3 14h8l-1 8 11-14h-8l0-6z" fill="currentColor" opacity=".9"/></svg>`,
  plus: `<svg class="bdg-svg" viewBox="0 0 24 24" fill="none"><path d="M11 5h2v14h-2zM5 11h14v2H5z" fill="currentColor" opacity=".9"/></svg>`,
  shield: `<svg class="bdg-svg" viewBox="0 0 24 24" fill="none"><path d="M12 2l8 4v7c0 5-3.5 8.5-8 9-4.5-.5-8-4-8-9V6l8-4z" fill="currentColor" opacity=".25"/><path d="M12 3.6l6.5 3.2v6.1c0 4.2-2.8 7.1-6.5 7.6-3.7-.5-6.5-3.4-6.5-7.6V6.8L12 3.6z" stroke="currentColor" stroke-width="1.2" opacity=".9"/></svg>`,
  skull: `<svg class="bdg-svg" viewBox="0 0 24 24" fill="none"><path d="M12 3c4.4 0 8 3 8 7.2 0 2.5-1.3 4.6-3.3 5.9V20c0 .6-.4 1-1 1h-1v-2h-2v2h-1v-2h-2v2H8.3c-.6 0-1-.4-1-1v-3.9C5.3 14.8 4 12.7 4 10.2 4 6 7.6 3 12 3z" fill="currentColor" opacity=".25"/><path d="M9.2 10.6c0 .9-.6 1.6-1.4 1.6s-1.4-.7-1.4-1.6.6-1.6 1.4-1.6 1.4.7 1.4 1.6zm8.4 0c0 .9-.6 1.6-1.4 1.6s-1.4-.7-1.4-1.6.6-1.6 1.4-1.6 1.4.7 1.4 1.6z" fill="currentColor" opacity=".9"/><path d="M10.2 15.2h3.6" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" opacity=".9"/></svg>`,
  die6: `<svg class="bdg-svg" viewBox="0 0 24 24" fill="none" aria-hidden="true">
    <rect x="4.2" y="4.2" width="15.6" height="15.6" rx="3" stroke="currentColor" stroke-width="1.4" opacity=".9"/>
    <circle cx="9" cy="8.5" r="1.35" fill="currentColor" opacity=".95"/>
    <circle cx="9" cy="12" r="1.35" fill="currentColor" opacity=".95"/>
    <circle cx="9" cy="15.5" r="1.35" fill="currentColor" opacity=".95"/>
    <circle cx="15" cy="8.5" r="1.35" fill="currentColor" opacity=".95"/>
    <circle cx="15" cy="12" r="1.35" fill="currentColor" opacity=".95"/>
    <circle cx="15" cy="15.5" r="1.35" fill="currentColor" opacity=".95"/>
  </svg>`,
};
