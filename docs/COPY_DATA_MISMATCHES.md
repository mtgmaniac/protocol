# Copy vs data report (2026-10-16, ui-cleanup phase 7)

Report only: no copy, data or code was changed for it. Branch `proto/ui-cleanup`.
Copy is Kev's to edit; each row names where the text lives and what the game
actually does.

## How it was checked

- **Ability effect strings** (`eff`, 305 abilities: heroes, evolutions, enemies)
  against their numeric and flag fields, by script: every number in the text
  matches a field and every field shows in the text (pierce = `ignSh`,
  firewall = `ward`, pack bonus +3 = `PACK_BONUS_PER_MEMBER`). **No mismatch.**
- **Relic, item and gear descriptions** (92) against their `effect` data and,
  where the number lives in code, the handler (Opening Salvo 50% / 20%, Vengeance
  Order's forced 20s, Revival Matrix 100%, Emergency Signal 50%, Dead Man's Hand
  1 HP, Band Compressor 19, Wide Aperture, Reverse Gimbal, Anchor Frame 50%,
  Tectonic Charge 3 / 3). **No mismatch** in the descriptions.
- **Keyword glossary** (`keywords.data.json`) and **primers** against the engine
  constants (jam 10, rewrite 3, execute 25% +8, chain 50%, mark +50% round up,
  hero leech 50%, rampage double, pack +3, burn once per round).
- **Enemy role lines**, **hero picker blurbs**, **evolution focus lines**,
  **operation copy** (origin, threats, boss flavor), **boss standing rules**,
  **intercept cards and battle modifiers**, **Help** (Basics, Protocol, rewards)
  read by hand against the kits and handlers.

## The Scrapmaster example

**The heal mechanic is not in the game.** On this branch, `main` and every other
local branch, the Scrapmaster still has ASSEMBLY LINE: every 2nd enemy phase from
its first, one destroyed Scrap Drone stands back up at 50% HP
(`scripts/battle/combat_manager.gd:470-487`, `SCRAPMASTER_REBUILD_PCT = 50` at
`:152`). Nothing anywhere heals the Scrapmaster per living Scrap Drone: its kit
(`data/raw/enemies.data.json` `enemyAbilities.boss`, lines 462-535) has no heal,
and no code or data on any branch mentions a per-drone heal. TRUTH.md (line 1780,
3082) still records ASSEMBLY LINE at 50% as a ruling.

So today the Scrapmaster copy **matches** the game:

| Where | Text |
|---|---|
| `scripts/battle/combat_manager.gd:141` (boss alert body) | "ASSEMBLY LINE - a Scrap Drone you already destroyed stands back up at 50% HP. The Scrapmaster rebuilds one every 2nd enemy phase, counting from its first." (It says every 2nd enemy phase, not "each round".) |
| `scripts/ui/operation_briefing_overlay.gd:69` (boss alert flavor) | "An industrial assembler that turns fallen drones into fresh troops." |
| `scripts/ui/operation_briefing_overlay.gd:26` (THREATS, squad select + briefing) | "SHIELDS · JAM · REBUILD" |
| `scripts/ui/operation_briefing_overlay.gd:24` (origin) | "...Its machines are building an army from the wreckage." |
| `data/raw/enemies.data.json:2983` (Scrapmaster role, inspect) | "...it keeps putting its drones back on the field." |
| `data/raw/battle-modes.json:15` (Facility blurb) | "Rogue war machines defend the foundry and rebuild their dead." |

If the heal-per-drone change is a ruling that is meant to land, it has not been
implemented yet, and every row above (plus the `ASSEMBLY LINE` log line at
`combat_manager.gd:483`) would need new copy at the same time.

## The trailing "ACTIVE": a bug, code appends it

`scripts/ui/operation_briefing_overlay.gd:128`, in `present_boss_alert`:

```gdscript
_add_section("%s ACTIVE" % str(parsed["name"]), ...)
```

The boss alert splits the standing rule on its first " - " and shows the left
half with " ACTIVE" appended ("ASSEMBLY LINE ACTIVE"). The word is not in any
copy or data; it is a status word added by code. The comment at
`combat_manager.gd:137-139` documents the behavior, so it was intentional when
written, but the text the player reads is built in code, not copy. Reported as
asked; not changed.

## Mismatches

| # | File:line | Copy says | Game does | Severity |
|---|---|---|---|---|
| 1 | `scripts/ui/reward_screen.gd:227` (reward help) | "The selected reward lights up cyan." | The selected card is the PLAYER cobalt border and fill (`ui_card_style`) since ui-unify; nothing is cyan | clear |
| 2 | `scripts/ui/operation_briefing_overlay.gd:35` (Hive THREATS) | "BURN · SWARM · SIPHON" | No Hive enemy drains Protocol. Siphon is the glossary term for Protocol drain (`keywords.data.json`, `primer_siphon`), which only the Signal Purge units have. The Hive heals off damage (lifesteal / leech) | clear |
| 3 | `data/raw/heroes.data.json:227` (Pulse Tech picker blurb) | "Plants burn on every hit, then detonates it..." | Two of five bands burn nothing: 1-5 "4 damage, chain" and 10-13 "12 damage, detonate" | overclaim |
| 4 | `data/raw/enemies.data.json:2920` (Scrap Drone role) | "plates itself once" | "8 shield (self)" is its 1-3 band and can fire on any turn; nothing limits it to once | overclaim |
| 5 | `data/raw/enemies.data.json:3001` (Bloodmite role) | "draining a little HP back on every bite" | Only the 6-11 band has lifesteal (40%); its 12-20 bites do not | overclaim |
| 6 | `data/raw/keywords.data.json:185` and `data/raw/primers.data.json:88` (Accrete) | "gains N shield at the start of each of its turns" | True for Basalt Ape and Magma Drake (`accrete` 3 / 4). The Mantle Tyrant's ACCRETION uses the same path (`combat_manager.gd:460`, `_apply_accrete`) but fires every 2nd round, and its shields persist. If the Tyrant is the first accreting unit seen, the primer describes it wrongly. The inspect pop-up does show the cadence (`accrete_rule`, `:1487`) | partial |
| 7 | `scripts/battle/combat_manager.gd:3418` (battle log) | "VENGEANCE PROTOCOL - the squad's next roll is all 20s!" | The relic is named "Vengeance Order" (`data/raw/relics.data.json:95`); the log uses an old name | name drift |
| 8 | `data/raw/enemies.data.json:3183` (Ash Channeler role) | "the Synod's heaviest burn" | "Synod" appears in no other player-facing text (the operation is Signal Purge, "a machine cult"); it is a code-comment name for the faction | name drift |

## Checked, no mismatch

- Every ability `eff` string vs its fields (305), every relic / item / gear
  description (92), the intercept cards and their choice labels
  (`GameState.gd:620-711`, e.g. Firing Solution's 90% mark, Splice Deal's 19 and
  +2 band), the battle modifiers (`GameState.gd:380-391`).
- Boss standing rules vs code: Matriarch every 3 rounds (`BROOD_CADENCE`), Mantle
  6 shield every 2nd round (`MANTLE_ROUND_SHIELD`, `MANTLE_SHIELD_CADENCE`),
  Hierarch's highest die to 3 (`REWRITE_VALUE`), Scrapmaster as above.
- Keyword definitions and primers vs constants (jam, rewrite, execute, chain,
  mark, leech, rampage, pack bonus, burn, cleanse).
- Help Basics and Protocol pages: XP (average roll + 20 for survivors,
  `XP_SURVIVAL_BONUS`), 100 / 250 XP, Nudge +3 for 1, Reroll 2, Set 4, Item 1
  (`item_protocol_cost`), Protocol cap 10.
- Hero picker blurbs and evolution focus lines other than Pulse (row 3); the
  other 37 enemy role lines; operation origins and the other four THREATS lines.

Not covered (time-boxed): tutorial and training-prompt copy, the unlock screen's
copy, trait lines (`traits.data.json`; the traits gate already checks them
against their numbers).
