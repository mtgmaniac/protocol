# Overload Protocol — AUDIO SPEC (basic implementation)
*Rides on the same event system as ANIMATION.md. The BattleFeedback table already reserves an SFX key per event — this fills it in. Goal: responsive, weighty, readable. Not realistic, not busy.*

## Aesthetic fit
Cold, industrial, pixel. Lean **chiptune / synthetic / mechanical**, not orchestral or organic-realistic. Flat and punchy, like the visuals. The dice are the star — the roll and the lock should be the most satisfying sounds in the game.

---

## How different should things sound? The layered model
**Don't author a unique sound per ability — that's unscalable and unnecessary.** Layer instead:

1. **Base layer = by ACTION CATEGORY (the verb).** ~10–12 core sounds: attack-hit, heal, shield-up, shield-break, buff/roll, freeze, burn-tick, death, dice-roll, dice-lock, UI-click/confirm. This is the entire basic implementation and the correct primary axis — it maps 1:1 to the combat events you already emit.
2. **Variation layer = pitch/sample randomization.** Each base sound plays with ±small random pitch & volume, or rotates 2–3 samples. **Cheapest, highest-impact polish there is** — turns 12 sounds into something that never feels repetitive. Essential for the attack/hit sound, which fires constantly.
3. **Identity layer = faction "topper" (OPTIONAL, later).** Per-race attack flavor done right is NOT a unique clip per faction — it's the **shared base hit + a short faction topper** layered on: Facility = metallic/electronic zap; Hive = wet organic chitter; Veil = harmonic shimmer; Void = warped/sub; Beast = guttural. Scales cleanly; defer to Tier 2.
4. **The overload / natural-20 signature (YES, make this one special).** The genre's payoff beat. One bespoke stinger — a meaty hit plus a rising "charge/commit" flourish, voiced in the gold-commit identity. The single place to spend extra audio love.

**So: yes to heal/shield/attack categories (base), yes to a special overload sound, faction-specific attacks only as an optional topper layer later, and never per-ability.**

---

## Core SFX set (~12) → event mapping
Reuse the ANIMATION.md event→primitive table; add an `sfx` key per row so one event drives visual + sound.

| sfx key | fires on | notes |
|---|---|---|
| `dice_roll` | roll start | rattle/tumble; loop or one-shot under the shuffle |
| `dice_lock` | each die settle | short tick/clack; pitch up slightly for higher rolls |
| `hit` | `damage` | the workhorse — MUST have pitch variation; scale weight by amount |
| `burn_tick` | `burn` | thinner, sizzly version of hit |
| `heal` | `heal` | soft rising chime |
| `shield_up` | `shield` | synthetic "charge" |
| `shield_break`| `block`/`wipe_shields` | glassy/metallic shatter |
| `buff` | `roll_buff` | quick rising blip |
| `freeze` | `freeze` | crystalline/ice tick |
| `death` | unit downed | low thud + dropout |
| `overload` | natural 20 | **bespoke signature stinger** (gold/commit) |
| `ui_click` / `ui_confirm` | buttons, reward pick, commit | menu + footer actions |

---

## Will you need to provide assets? Yes — but you can make them fast
Claude Code can build the entire audio **system**, but it can't generate the audio **files**. Two paths, use both:

**A. Make your own (best fit for this game).** Procedural retro SFX generators — click a preset (hit/zap/powerup/explosion), tweak, export WAV. You can produce a coherent, on-aesthetic set in an afternoon, fully royalty-free:
- **ChipTone** (sbfgames, web/desktop) — cleanest UI, layering + effects, WAV export. Best starting point.
- **Bfxr** (bfxr.net) — classic, open-source, mixer + many waveforms.
- **jsfxr** (sfxr.me) — simplest, browser-only.

**B. Libraries (for richer/produced sounds — boss, overload stinger, ambience).** Check the license per file:
- **Sonniss GameAudioGDC** — royalty-free, no attribution, commercial OK.
- **Freesound** — huge; filter to **CC0** (no credit) vs CC-BY (credit required).
- **Kenney** audio packs — CC0, game-ready.
- **itch.io** audio asset packs / **Pixabay** / **Mixkit** — many CC0 / no-attribution.

License rule of thumb: **CC0 = no credit needed; CC-BY = you must credit.** Prefer CC0 to keep shipping simple; keep a credits list for anything CC-BY.

**Bridge:** Claude Code should stub every `sfx` key with a placeholder (silent or a single beep) so the system is wired and testable before real clips exist — then you drop final files into `assets/audio/sfx/<key>.wav` and they just work.

---

## Godot system scope (basic)
- **`AudioManager` autoload:** `play_sfx(key)` with built-in pitch/volume randomization and **voice limiting** (cap simultaneous instances so 5 hits at once don't clip/stack to a roar); `play_music(track)` later.
- **Buses:** Master → SFX, Music, (UI). Per-bus volume + a master mute (mobile-friendly).
- **Format:** `.wav` for SFX (low latency), `.ogg` for music/long loops.
- **Wiring:** BattleFeedback reads the `sfx` column and calls `AudioManager.play_sfx(key)` on the same hook as the visual primitive. New effect = new row, same as before.
- **Out of scope for basic:** music tracks, ambient beds, faction toppers, dynamic mixing. Wire the hooks; add content later.

---

## Build order (tiered)
- **Tier 1:** AudioManager + buses + pitch variation; wire `dice_roll`, `dice_lock`, `hit`, `ui_click`. (Dice + hits + clicks = most of "feels responsive.")
- **Tier 2:** `heal`, `shield_up`, `shield_break`, `buff`, `freeze`, `burn_tick`, `death`, and the bespoke `overload` stinger.
- **Tier 3:** faction attack toppers · music · ambience · settings-screen volume sliders.
