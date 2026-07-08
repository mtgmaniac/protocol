# Overload Protocol — Description ↔ Behavior Audit (Prompt 1)

*Single sequential pass, no subagents. Verified against **code**, not docs. Branch `audit/description`.
Scope: every displayed effect string (hero ability bands + overload, directives, enemy abilities,
items, relics, gear, keyword glossary, inspect/status text) diffed against what the code actually
resolves, post `fix/post-audit-pass`.*

Date: 2026-07-07. Auditor: Claude (Opus 4.8).

---

## Method (why this is 100% coverage, not sampling)

1. **Every hero + enemy ability `eff` string was machine-diffed against its own data fields** in both
   directions — (a) every numeric field (`dmg`/`burn`/`burnT`/`heal`/`shield`/`shieldAlly`/`rfm`/`rfmT`/
   `rfe`/`rfT`/`lifestealPct`/`siphon`/`spike`) and every keyword flag must appear in the string, and
   (b) every keyword *word* in the string must have a backing field. **Result: 0 mismatches** across
   120 hero ability bands + 185 enemy ability bands. No wrong-number / wrong-target / wrong-keyword
   defect survived at the ability layer.
2. **Every item / relic / gear / directive `desc` was read by hand** and traced to its effect handler
   (`combat_manager.gd`, `battle_engine.gd`, `battle_scene.gd`).
3. **The keyword glossary** (`keywords.data.json`) was diffed against actual handlers and against the
   ability strings that describe those keywords.
4. **Inspect / status text** (`inspect_resolver.gd`) — the layer that also renders effect wording — was
   read line-by-line and diffed against the code paths it describes.

The high-risk targets the fix pass touched were each traced to their handler and confirmed
(details in the "verified WAD" section). The only surviving meaning defects were **stale `natural 20`
terminology (NK-02)** and **one wrong burn-timing sentence** — all fixed in-place.

---

## Severity-sorted summary

| # | Entity / where | Displayed text | Code effect | Mismatch | Severity | Status |
|---|---|---|---|---|---|---|
| D-01 | gear `overload_capacitor` `gear.data.json:26` | "A **natural 20** grants +2 Protocol." | `protocolOnNat20` grants when the die's **final face** == 20 (`combat_manager.gd:737-741`); any 20 (rolled/Set/Nudged/buffed) counts | stale keyword (NK-02: no "natural 20") | wrong-keyword | **FIXED** → "A 20 grants +2 Protocol." |
| D-02 | relic `overloadLoop` `relics.data.json:103` | "**Natural 20s** resolve their effects twice." | `critResolveTwice` echoes on final face 20, once, never on freeze repeat (`combat_manager.gd:730-733`) | stale keyword (NK-02) | wrong-keyword | **FIXED** → "20s resolve their effects twice." |
| D-03 | relic `martyrdomProtocol` (Vengeance Protocol) `relics.data.json:96` | "…next roll is all **natural 20s** (once per battle)." | forces surviving squad's next roll to 20 (`combat_manager.gd:2225-2229`) | stale keyword (NK-02) | wrong-keyword | **FIXED** → "…next roll is all 20s…" |
| D-04..D-15 | 12 enemy overload `eff` strings (`enemies.data.json`) | "summon ~N% **nat20**" | summon rolls `_rand_pct() <= summonChance` on the overload (final face 20) resolution, once, smart+`summonElite` only (`combat_manager.gd:2775-2798`) | stale keyword (NK-02); the trigger is any effective-face 20, not a "natural" roll | wrong-keyword | **FIXED** → "summon ~N% **on 20**" (all 12) |
| D-16 | `inspect_resolver.gd:361` (burn status text — unit inspect **and** status popup) | "Takes N damage **at the start of each turn**." | Burn ticks in `_tick_end_of_round_states()` — **end of round**, after both phases (`combat_manager.gd:792, 2531, 2591-2599`). Contradicts `primer_burn` ("end of each round") | wrong-duration/timing | wrong-duration | **FIXED** → "at the end of each round." |
| D-17 | `inspect_resolver.gd:365` (freeze status-pip fallback text) | "Die result is **locked and cannot change**." | Freeze = repeat: die keeps its face and the unit **acts again** on it (`combat_manager.gd` freeze handler; matches `_unit_status_entries` line 222 and `keywords.data.json` freeze `def`) | stale-model wording (pre-repeat framing; not wrong, but incomplete for a high-risk mechanic) | grammar/style→fixed | **FIXED** → "…keeps this face and the unit acts again on it." |

**12 enemy strings (D-04..D-15):** Conclave Bulwark, Veil Collapse, Total Eclipse (veilNull), Lattice
Storm, Broodlink Surge, Veil Cataclysm, Ritual Clamp, Summon Verse, Mass Snare, Warp Nova, Void Gate,
Call Friends.

**Strings fixed in-place this commit: 17** (15 data strings + 2 inspect_resolver strings).
**Surviving meaning defects: 0.** **Needs-Kev-ruling: 0** (see below for two low-severity observations
that do not need a ruling).

---

## Findings by system

### Heroes (abilities + overload + directives)
- **0 defects.** Every band's `eff` matches its fields (scripted, both directions). Directive `desc`
  strings all trace to live handlers, incl. the ability-name cross-references that a rename could have
  broken: `Field Surgeon`→"Surge Revive", `Lazarus Loop`→"Mass Revival", `Surge Wiring`→"Bias Charge"
  — all names still exist. Freeze wording on the Avalanche line ("freeze (repeat 1)" / "freeze any" /
  "freeze all") matches the repeat model. Leech abilities correctly defer to the 50% glossary value
  (`combat_manager.gd:1376` hardcodes `* 0.5`).

### Enemies (37 kits × 5 bands)
- **Only defect: stale `nat20` token** in 12 overload summon strings (D-04..D-15, fixed).
- Verified: enemy `lifesteal N%` strings each equal their `lifestealPct` field and the code heals
  `floor(dmg * pct/100)` (`combat_manager.gd:1670-1686`) — hero-fixed-50% vs enemy-tunable-% split
  (NK-09) is correct on both sides.
- Verified: every summon string sits on a unit whose def carries `summonElite:true` and `ai:"smart"`,
  so none is a dead promise.
- NK-05 renames (`Searing Nip`, `Crystal Break`, `ECM Hiss`, `Arc Strike`) are all live in the data;
  no in-game string uses an old name.

### Items (25)
- **0 hard defects.** Verified against `battle_engine.gd` handlers:
  - **Deep Zero Pin** `deep_zero_pin` — "Pin every enemy die to its weakest face and freeze it — each
    enemy repeats its recharge result next roll." Matches `item_enemy_freeze_all` (pins to LOWEST face
    = 1 = recharge zone, then freezes; `battle_engine.gd:347-350`). **The redesigned string is
    correct** — this was the item most at risk of lying and it does not.
  - **Cryo Gel / Cryo Web** — "keeps its face and repeats that result on its next roll / next two
    rolls" matches `anyDieFreeze` repeats 1 / 2.
  - roll-buff, enemyRfe, gainProtocol, revive, cloak, burn, shock items all match their amounts.
- See LOW-01 (cascade_jammer) below.

### Relics (35)
- **Only defects: D-02, D-03** (stale "Natural 20s", fixed). All others verified:
  `protocolOverride`, `overflowVent`, `salvageDirective`, `coldLogic` (+4 vs frozen die, keys on
  `die_freeze_turns>0`), `chainDoctrine`, `squadWipeSurvive` (Dead Man's Hand — "roll 20s", already
  clean), boss relics (`shieldsPersist`, `setCostZeroOncePerBattle`, `turn1RollFloor`,
  `protocolOnShieldBreak`, `heroHealOnOwnKill`).

### Gear (31)
- **Only defect: D-01** (Overload Capacitor "natural 20", fixed). Verified:
  - **Sync Antenna** `sync_antenna` — "both gain +3 to it" is now a **live** effect
    (`battle_scene.gd:1443-1471` applies a real 1-turn +3 roll-buff to both matched dice; A-041 fixed).
    String is accurate.
  - `siphon_loop`/`hemophage_nexus` (lifesteal 20%/40%), `breach_tip` (ignore up to 5 shield),
    `mirror_plate` (2 Protocol on enemy tamper), `overload_capacitor`, `band_compressor`,
    `wide_aperture` all match their handlers.

### Keyword glossary (`keywords.data.json`)
- **0 conflicts** between glossary `def`s and the ability strings that carry each keyword. Spike
  ("never persists past the round"), Taunt ("can only target the taunter" — no permanence claim,
  correct for NK-08 round-end clear), Leech (50%), Freeze (repeat model, "can't be Jammed, Rewritten,
  or Hijacked"), Cloak (2 clauses) all match code.

---

## Verified WAD (the fix-pass high-risk targets, each traced to its handler)

| Target | Verdict |
|---|---|
| nat-20 removed | All player-facing "natural 20"/"nat20" strings were stale and are now fixed (D-01..D-15). Remaining "nat20" tokens are code comments / internal field names (`nat20_twice`) / a stat key (`nat20s`) — not displayed. |
| Deep Zero Pin | String matches redesigned behavior (pin-to-weakest + freeze). ✔ |
| Freeze full immunity incl. Nudge | Glossary + ability strings never imply a frozen die can be altered. ✔ (inspect fallback tightened, D-17). |
| Taunt clears round end (NK-08) | No string implies permanent hero taunt. ✔ |
| Spike once per ability (NK-06) | Glossary says "This round … takes N back"; no per-hit wording. ✔ |
| Riders fire once, not per freeze repeat (NK-04) | Capacitor / 20s-stat / Overload Loop all gate on `die_freeze_repeat_this_round`; strings carry no per-repeat claim. ✔ |
| Leech hero 50% / enemy tunable % (NK-09) | Both sides' numbers match code. ✔ |
| Renamed flavor (NK-05) | In-game strings all use new names. ✔ (docs lag — see below.) |
| Sync Antenna (A-041) | +3 is live; string accurate. ✔ |

---

## Grammar / style bucket (low-severity; NOT fixed — no meaning impact)

- **GR-01 — Heal string order is inconsistent within the heal family.** Single-target heals use a
  parenthetical suffix (`"4 heal (ally)"`, `"10 heal (ally)"`) while all/lowest heals use a target
  **prefix** (`"all 10 heal"`, `"lowest 8 heal"`). Shield strings are uniformly prefix
  (`"ally 6 shield"`, `"all 8 shield"`, `"self 5 shield"`). This is house-style drift, not a behavior
  mismatch — every value is correct. TRUTH's canonical example (`8 heal ally`, no parens) also differs
  from the data's parenthetical form, but TRUTH's syntax block is illustrative, not a quoted string, so
  no TRUTH edit is made. Left as-is pending a house-style call.

## Low-severity observations (do NOT need a ruling)

- **LOW-01 — `cascade_jammer` desc slightly over-broad.** "Reroll every living enemy's die" — the
  handler rerolls only **unfrozen** enemy dice (`battle_engine.gd:434-435`, "all unfrozen enemy dice
  rerolled"), because a frozen die is globally immune to alteration. This is consistent with the
  universal freeze rule the player already learns; spelling out "except frozen" on every reroll item
  would be noise. **Not fixed** (consistent with the game's global rule; flag only).
- **LOW-02 — Accrete value is not surfaced pre-combat for two Accretion units.** `Basalt Ape`
  (`accrete:3`) and `Magma Drake` (`accrete:4`) gain shield at the start of each of their turns, but no
  ability `eff` string or inspect line states the accrete amount up front (the shield gain + a one-shot
  `primer_accrete` are the only signals). This is a coverage/legibility gap, not a wrong string.
  **Not fixed** (no ruling needed; note for a future inspect-surface pass).

## Docs staleness (out of player-facing scope; noted, not fixed here)

- `docs/wiki/enemies.md` and the untracked `docs/ABILITY_DESCRIPTIONS_FULL.md` still list the four
  pre-NK-05 names (`ECM Jam`, `Chain Strike`, `Venom Nip`, `Crystal Shatter`). These are reference docs,
  not runtime strings, so they're outside this audit's fix scope — flagged for the wiki-sync owner.

---

## Coverage checklist (every entity id — nothing sampled)

**Heroes (8 kits × 5 base + 2 evos × 5 = 120 bands, + 32 directives) — ALL audited:**
`pulse` (base+pyro+arc) ✔ · `combat` (base+blade+ravager) ✔ · `shield` (base+bulwark+sentinel) ✔ ·
`avalanche` (base+glacier+trench) ✔ · `medic` (base+medic+synth) ✔ · `engineer` (base+overclocked+phantom) ✔ ·
`ghost` (base+shadow+wraith) ✔ · `breaker` (base+noise+nullwire) ✔. All 32 directives traced ✔.

**Enemies (37 kits × 5 bands = 185) — ALL audited:**
scrap ✔ rust ✔ patrol ✔ guard ✔ warden ✔ volt ✔ boss ✔ · skitter ✔ mite ✔ stalker ✔ carapace ✔ brood ✔
spewer ✔ hiveBoss ✔ · veilShard ✔ veilPrism ✔ veilAegis ✔ veilResonance ✔ veilNull ✔ veilStorm ✔
veilSynapse ✔ veilBoss ✔ · voidWisp ✔ voidAcolyte ✔ voidScribe ✔ voidBinder ✔ voidGlimmer ✔
voidChanneler ✔ voidCircletBoss ✔ · beastMonkey ✔ beastWolf ✔ beastLynx ✔ beastBison ✔ beastHyena ✔
beastBadger ✔ beastTyrant ✔ signalSkimmer ✔.

**Items (25) — ALL audited:** patch_kit ✔ triage_broadcast ✔ scrap_plate ✔ buckler_array ✔
calibration_chip ✔ momentum_core ✔ harmonic_injector ✔ archive_cascade ✔ defib_spark ✔ ghost_veil ✔
scatter_veil_array ✔ grounding_clip ✔ corrosion_bomb ✔ entropy_seed ✔ shock_charge ✔ acid_vial ✔
phase_scrambler ✔ cascade_jammer ✔ (LOW-01) cryo_gel ✔ cryo_web ✔ deep_zero_pin ✔ protocol_cell ✔
capacitor_dose ✔ core_surge ✔ mainline_cache ✔.

**Relics (35) — ALL audited** (30 draft + 5 boss): ironCurtain ✔ openingGambit ✔ bulwarkAura ✔
naniteField ✔ plagueProtocol ✔ overcharge ✔ signalJam ✔ coordinatedStrike ✔ resonanceCascade ✔
gravityWell ✔ protocolOverride ✔ entropyLeak ✔ chainReaction ✔ martyrdomProtocol ✔(D-03) overloadLoop ✔(D-02)
curatedCache ✔ overflowBuffer ✔ fieldCache ✔ mercyProtocol ✔ emergencySignal ✔ aegisField ✔ standingOrder ✔
staticField ✔ twinFates ✔ overflowVent ✔ salvageDirective ✔ coldLogic ✔ chainDoctrine ✔ scavengerManifest ✔
deadMansHand ✔ · salvageRig ✔ chitinGraft ✔ resonantChorus ✔ rootAccess ✔ mantleCore ✔.

**Gear (31) — ALL audited:** neural_splice ✔ predator_lens ✔ combat_plating ✔ stim_injector ✔
warframe_core ✔ phase_weave ✔ kill_switch ✔ protocol_tap ✔ mainline_bus ✔ triage_gel ✔ counterweight ✔
siphon_loop ✔ hemophage_nexus ✔ spike_driver ✔ overkill_matrix ✔ dead_mans_chip ✔ echo_matrix ✔
breach_tip ✔ bounty_chip ✔ band_compressor ✔ wide_aperture ✔ reverse_gimbal ✔ priming_charge ✔
overload_capacitor ✔(D-01) ignition_coil ✔ payload_fuse ✔ targeting_optic ✔ mirror_plate ✔ anchor_frame ✔
killswitch_relay ✔ sync_antenna ✔.

**Keyword glossary (24 entries) — ALL cross-checked** against handlers + ability strings ✔.
**Inspect/status text (`inspect_resolver.gd`) — read in full** ✔ (D-16, D-17).

---

## Report to Kev

- **Strings fixed in-place: 17** — 15 stale "natural 20"/"nat20" strings (NK-02 terminology: 1 gear,
  2 relics, 12 enemy summon `eff`s) + 2 `inspect_resolver.gd` strings (burn ticks **end of round** not
  "start of each turn"; freeze fallback now states the repeat/acts-again model).
- **Needs-Kev-ruling: none.** Two low-severity observations (LOW-01 cascade_jammer over-broad wording,
  LOW-02 accrete not surfaced pre-combat) are consistent with existing global rules and need no ruling —
  flagged only.
- **No code effect was changed.** Every fix moved a string toward the code, never the reverse.
- **Coverage: 100%, no sampling.** All 120 hero bands + 32 directives, 185 enemy bands, 25 items,
  35 relics, 31 gear, and the keyword glossary were audited; hero+enemy ability strings additionally
  passed a two-directional scripted field/keyword diff (0 residual mismatches).
- **TRUTH.md:** unchanged — it already states the NK-02 "no separate natural 20" rule and quotes none
  of the stale strings.
- **Out of scope but noted:** `docs/wiki/enemies.md` and `docs/ABILITY_DESCRIPTIONS_FULL.md` still carry
  the four pre-NK-05 ability names (reference docs, not runtime).
