# Combat Resolution

> Part of the [Overload Protocol wiki](INDEX.md). See also: [keywords.md](keywords.md), [statuses-and-chips.md](statuses-and-chips.md), [shields-and-ward.md](shields-and-ward.md), [dice-and-rolls.md](dice-and-rolls.md), [targeting.md](targeting.md), [bosses.md](bosses.md), [protocol-economy.md](protocol-economy.md).

## How it works

Combat is round-based. All dice roll simultaneously at round start; the player resolves every living hero in chosen order, then surviving enemies resolve, then statuses tick. The whole round is computed synchronously by `CombatManager.resolve_round()` (`scripts/battle/combat_manager.gd:629`) and replayed afterwards as feedback (`scripts/battle/battle_feedback.gd:14`). Both the live screen and the headless sim drive it through `BattleEngine.resolve_step()` (`scripts/battle/battle_engine.gd:39`) so there is exactly one rules path.

### Roll → effective roll pipeline (before resolution)

1. Raw d20 per living unit via the `RollProvider` seam (`battle_engine.gd:504` `roll_states`; physics tray in game, seeded provider in sim).
2. Frozen dice overwrite their fresh roll with the crusted face (`battle_engine.gd:513` `apply_frozen_roll_overrides`) and are flagged `die_freeze_repeat_this_round` (`battle_engine.gd:529` `record_roll_values_for_states`, which also stamps `last_die_value`).
3. Cursed flag is cleared with no effect (`scripts/battle/battle_scene.gd:562-564` — dead mechanic, see findings).
4. Effective roll per hero (`battle_engine.gd:453` `effective_hero_roll`):
   - frozen repeat → the crusted face, nothing else applies;
   - else a **Set** die → its absolute value (overrides Nudge, buffs, jam, even a pending Rewrite);
   - else `combat_manager.get_effective_roll()` (`combat_manager.gd:535`): Rewrite pending → 3 flat; otherwise `clamp(raw + roll_buffs − rfe, 1, 20)`, then Jam caps the result (`JAM_CAP := 10`, `combat_manager.gd:1304`);
   - plus the player's Nudge (+3 / −3 with Reverse Gimbal), clamped 1–20. **The Nudge is added after the Jam cap**, so a jammed die can be nudged above 10.
5. Enemy effective rolls go through the same `get_effective_roll` (no Nudge/Set) (`battle_engine.gd:468`).

### Round resolution order (`combat_manager.resolve_round`, `combat_manager.gd:629`)

```
round_start
 ├─ 1. _battle_round += 1; stash raw hero faces (enemy freeze pick reads them)   :638
 ├─ 2. BOSS ROUND-START RULES (before hero phase)                                :645, 214
 │      Overseer: +Firewall while an ally lives · Mantle Tyrant: +6 persistent shield
 ├─ 3. HIJACK override: primed enemies copy the heroes' highest EFFECTIVE die    :650
 │      (frozen dice immune)
 ├─ 4. Enemy intents assigned in slot order via TargetingPersonality             :667, 153
 ├─ 5. HERO PHASE — heroes in order, dead units skipped                          :669
 │      frozen die repeats its face · _apply_hero_ability per hero               :926
 │      final face 20 + Overload Loop / Overload Rites → the ability resolves twice :685
 ├─ 6. victory check (all enemies down → enemy phase never happens)              :689
 ├─ 7. per-enemy-turn relic auras (Bulwark Aura, Nanite Field, Gravity Well)     :694, 490
 ├─ 8. ACCRETE: carriers gain shield that survives the imminent tick             :698
 ├─ 9. BOSS ENEMY-PHASE RULES (before enemies act)                               :707, 235
 │      Assembly Line rebuild · Brood spawn · Root Access rewrite
 ├─ 10. Regenerative route modifier: enemies heal 3                              :710
 ├─ 11. ENEMY PHASE — enemies act in REVERSE slot order                          :715
 │      Decoy Beacon: whole enemy line skips round 1                             :721
 ├─ 12. END-OF-ROUND TICK  _tick_end_of_round_states                             :737, 2395
 │      per state: burn tick → lure clear → hijack/rewrite/jam skip-flag →
 │      spike clear → shield expiry → Feedback chip dmg → rfe decay → roll-buff decay
 │      then: frozen repeats spent (thaw at 0) · enemy taunt cleared
 ├─ 13. victory check, then defeat check (victory wins a same-round tie)         :739
 └─ 14. caller applies protocol grants/drains + the +1 end-of-round income
        (battle_engine.resolve_step :39, end_of_round_income :72)
```

### Hero ability resolution pipeline (`_apply_hero_ability`, `combat_manager.gd:926`)

Within one ability, components resolve in this fixed order:

1. **Decloak** — dealing damage breaks the caster's cloak first (Ambush Wiring +dmg, Ghostblade queues an Execute) (`:947`).
2. **Damage pass** (`_apply_hero_ability_damage`, `:1191`) — see below.
3. **Shield grants** (self / all / lowest / targeted; Rampart, Overcharge Mesh, Bunker Doctrine riders) (`:962`).
4. **Heals** (self / all / lowest / targeted; Field Triage, heal-shield gear, Aegis Field) (`:987`).
5. **Roll buffs** (`rfm`) — targeted or squad-wide (`:1000`).
6. **gainProtocol** (+ Surge Wiring) (`:1011`).
7. **Burn-only** application when the ability has no damage (`:1019`).
8. **RFE** (roll-down) single or all (+ Noise Floor / Nullwire directive riders) (`:1024`).
9. **Taunt** — this hero taunts; any other taunting ally stops (`:1040`).
10. **Revive / reviveAll** (`:1048`).
11. **Spike** (+ Counterweight) (`:1061`).
12. **Ward/Firewall** (self or `wardTgt` ally) (`:1071`).
13. **Cloak / cloakAll** (`:1082`).
14. **Freeze** (`freezeEnemyDice` / `freezeAllEnemyDice` / `freezeAnyDice`, + Deep Freeze) (`:1093`).
15. **Jam / jamAll**, **Rewrite** (`:1127`, `:1139`).
16. **First-ability echo** (gear): the damage pass runs once more, without burn (`:1144`).
17. **Silent Running**: non-damage abilities re-cloak the caster (`:1149`).

### Damage pass order (`_apply_hero_ability_damage :1191` → `_damage_state :1765`)

For a single-target hit: **Breach strips shields → ward check (per carrier) → vsFrozenBonus → `_damage_state` → Detonate → Execute → burn application → Mark applied last → Chain jumps** (chain runs even when the primary was ward-blocked, `:1280`). Leech totals HP damage from primary + AoE hits and heals 50% after everything (`:1282`).

Inside `_damage_state` (one hit, in order):

1. pierce marker event (feedback only) (`:1777`)
2. SPITEFUL stamp: enemy remembers `last_attacker_id` (`:1785`)
3. hero gear `dmgReduction` (+ Ironclad while taunting) — a hit reduced to 0 **ends here** (no spike, no mark consume) (`:1793`)
4. **Mark consumed**: whole amount ×1.5 round up — consumed by any hit with an attacker, even one fully absorbed by shields; burn ticks and aura chip damage never consume it (`:1806`)
5. flat bonuses added AFTER the mark multiplier: Cold Logic +4 vs frozen, Deep Cuts +3 vs burning, Shatterpoint +6 vs frozen (`:1815`)
6. spike value read (before the hit can down the target) (`:1834`)
7. shield absorption stack-by-stack, with gear `shieldPierce` budget skimmed first; Salvage Rig grants +1 Protocol on a full enemy shield break (`:1843`)
8. **Spike retaliation** fires if the attack connected — even fully absorbed; the retaliation carries no attacker, so spikes can't loop (`:1879`)
9. remaining damage to HP (`:1887`)
10. gear lifesteal (`:1891`)
11. Emergency Signal low-HP squad buff trigger (`:1899`), Vanish directive (`:1906`)
12. death: `surviveOnce` gear → 1 HP once; else down → statuses cleared (`_clear_active_statuses_for_down_state :2175`), targets involving the unit cancelled (`:2208`), on-kill hooks (`_on_unit_killed :2087`), Dead Man's Hand wipe-save (`:1930`).

### Death timing

- A unit that dies mid-round does not act — both phase loops skip `dead` states (`:670`, `:718`).
- Down clears every active status including shields, marks, freeze, spike, ward, taunt and `perm_rfe` (`:2175`).
- `_on_unit_killed` runs kill hooks (Chain Reaction, Dead Man's Charge, Scavenger Manifest, Kill Switch heal, protocol-on-kill, Chitin Graft, Salvage Directive, Momentum, Killswitch Relay, SPITEFUL grudge clearing) behind a re-entrancy guard `_chain_reaction_active` (`:2088`) — kills caused *inside* those hooks do not re-trigger hooks (see findings).
- Burn ticks at step 12 can kill; the victory check runs before the defeat check, so a mutual wipe on the tick reads as victory (`:739-745`).

### Status tick detail (`_tick_state`, `combat_manager.gd:2446`)

Every status applied mid-round carries a `skip_next_tick`-style flag so it survives the tick of its application round and covers exactly one opposing phase. Order inside one state's tick: burn damage (then stack clocks) → lure → hijack → rewrite → jam → spike → shield expiry → Feedback directive chip damage (fires before rfe decay so a 1t roll-down still bites, `:2530`) → rfe decay → roll-buff decay.

## Why it works that way

- One synchronous resolution + replayed feedback keeps the sim byte-identical to the screen (INVARIANTS #1, determinism fence); events carry `hp_after` so the HP bar can step per hit (`:2675`).
- Player-first, enemy-second and the per-side skip-flags implement TRUTH combat rules 1–5 (shields/spike/lure granted in the enemy phase must survive one tick to ever matter).
- Boss round-start rules fire before the hero phase "so they matter this round"; turn-cadence rules fire at the start of the enemy phase (TRUTH §boss standing rules).
- Freeze=repeat consumption has a single point at the round-end tick so tray and headless flows can't diverge (DECISIONS_RESOLVED #1).
- Every 20-triggered effect keys on the die's FINAL effective face (ruling NK-02, 2026-07-08 — the "natural 20" concept was removed). A die Nudged/Set/buffed to 20 fires the identical suite (Overload Loop, Capacitor, name-slam, elite summons); under freeze=repeat those riders fire once, not per repeat (NK-04).
- Enemies resolving in REVERSE slot order dates to the initial commit. RATIONALE: unconfirmed (likely so the right-most/boss slot acts last visually).

## What it replaced

- The whole loop was extracted from the `battle_scene.gd` god object into `BattleEngine`/`CombatManager` (balance-sim packages A.1/B.2/D; K5 rejected an ECS rework).
- Freeze lineage: bank/thaw → next-turn lockout → **repeat** (DECISIONS_RESOLVED #1).
- Refresh-to-max buff/burn timers → independent instance clocks (DECISIONS_RESOLVED #3).
- `DETONATE_MAX_TURNS` cap → permanent-burn one-tick rule (DECISIONS_RESOLVED #4).
- Boss phase-2 stat jumps → standing rules from turn 1 (TRUTH doc adjudications).
- `curseDice` (roll twice, keep lower) left the data in the pkg3.3 kit rework (`3b16f36`) but its handler chain remains — dead (see findings).

## File locations

- `scripts/battle/combat_manager.gd` — resolution authority (2708 lines)
- `scripts/battle/battle_engine.gd` — roll shaping, protocol economy, item dispatch
- `scripts/battle/battle_state.gd` — caller-owned roll/nudge/set/protocol container
- `scripts/battle/battle_feedback.gd` — feedback replay (groups per `action_start`)
- `scripts/battle/targeting_personality.gd` — the enemy targeting choke-point
- `scripts/debug/ability_audit.gd` + `scripts/debug/ability_audit_runner.gd` — 228+ regressions gate (`scripts/verify_gate.py`, `AUDIT_MIN_PASSED = 228`)

## Known edge cases

- Victory beats defeat when the round-end tick wipes both sides in the same round (`:739-745`).
- A 20 on a frozen die repeats the ability, but the 20-face riders (Overload Loop, Capacitor, 20s stat, enemy summon) fire ONCE on the original resolution — not per repeat (ruling NK-04, 2026-07-08; gated on `not die_freeze_repeat_this_round`).
- A death caused by an on-kill effect (Chain Reaction splash, Dead Man's Charge, Killswitch Relay) is now processed via a work-queue, so its own on-kill hooks/stats fire (audit A-002, fixed 2026-07-08); Chain Reaction still fires only on the top-level kill (no cascade). Summoned/rebuilt units grant no kill economy (NK-10).
- Decoy Beacon skips enemy *actions* on round 1, but boss standing rules (both kinds) still fire that round (`:645`, `:707` run before the decoy check at `:721`).
- Root Access rewrites the highest **effective** hero die and bypasses Firewall and Cloak (`apply_rewrite_to_state :1336` has no ward/cloak check — the standing rule is not an "ability").
- Brood cadence is `_battle_round % 3` (battle rounds), unlike Assembly Line which counts from first activation (DECISIONS #5 ruled SCRAPMASTER only); identical in every shipping case since bosses spawn at battle start.
- A Set die bypasses Jam AND a pending Rewrite; a Nudge stacks on top of the Rewrite's forced 3 (`battle_engine.gd:453-465`). Frozen dice can't be Set/Rerolled/Nudged at all.
- Mutual-kill hooks: damage dealt inside `_on_unit_killed` (Dead Man's Charge, Killswitch Relay, Chain Reaction) that kills another unit skips that unit's own on-kill hooks (re-entrancy guard, `:2088`).

## ⚠ Open findings

<!-- AUDIT-LINKS:combat-resolution -->
- [A-003](../audit/INTERACTION_AUDIT.md#a-003) - [confusing] healLowest follows a stale selected pick
- [A-005](../audit/INTERACTION_AUDIT.md#a-005) - [confusing] enemy resolution runs undocumented reverse slot order
- [A-007](../audit/INTERACTION_AUDIT.md#a-007) - [confusing] one-keyword/one-pick rules are not in the gated audit

Resolved (2026-07-08 fix pass): [A-001](../audit/INTERACTION_AUDIT.md#a-001), [A-002](../audit/INTERACTION_AUDIT.md#a-002), [A-006](../audit/INTERACTION_AUDIT.md#a-006)
