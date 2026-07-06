# DECISIONS RESOLVED (human-adjudicated, FINAL)

Companion to `docs/TRUTH.md` §DECISIONS NEEDED. Entries move here once Kev rules;
numbers are preserved from the TRUTH.md list so old references stay valid.
**Do not re-open these without a new explicit ruling from Kev.**

---

## 1. Freeze semantics — FREEZE = REPEAT *(ruled by Kev, 2026-07-06)*

**Ruling.** Freeze = repeat is the original design intent, restored. Identical for
both sides: a frozen die crusts, stays static in the tray as a hard physics
blocker other dice bounce off, and on the next roll does NOT reroll. It keeps the
same face, and its unit **acts again on that same result — same zone, same
ability**. Targeting is re-picked fresh on each repeat (manual pick for heroes,
personality choke-point for enemies); only the die result is locked. After its
authored N repeats the die thaws and rerolls normally. Deep Freeze extends the
repeat count. Frozen dice are immune to Jam, Rewrite, and Hijack. Non-damage
freeze abilities (incl. shield+freeze / heal+freeze) target ANY unit via manual
pick (`freezeAnyDice`); freeze riders on damaging abilities stay enemy-side.
Enemy AI freeze targets the hero's LOWEST revealed die, deterministically.

**Lineage — record kept so no future agent resurrects a dead model:**

1. **Bank/thaw (fix-1.4 "banked-face" reading, DEAD).** An unspent-reveal freeze
   "banked" the die's face; the unit skipped its reveals while frozen and on thaw
   revealed the banked value once. Written into `offline-bundle/GROUND_TRUTH.md`
   §7 with a DESIGN-TODO claiming it superseded the 67d95b6 revert. It did not.
2. **Next-turn static lockout (commit-era revert, DEAD).** "Reverted per Kev from
   the fix-1.4 bank/thaw reading": the die stayed static and the unit simply
   SKIPPED its next N reveals — no bank, no repeat, the freeze was pure action
   denial. Live in code until 2026-07-06 (`combat_manager.gd` ~1039, the
   `die_freeze_consumed_this_round` flag, `item_enemy_freeze` "skips").
3. **Repeat (2026-07-06 ruling, FINAL).** Restores the original intent: the
   frozen face is not denied — it is REPLAYED. Both prior models were removed
   from code, data, text, and tests in the same pass; the state flag is now
   `die_freeze_repeat_this_round`, item data uses `repeats`, eff strings read
   `freeze (repeat N)`.

**Where it lives:** `combat_manager.gd` (freeze block + `_freeze_die_state` +
`_freeze_pick_hero_lowest_die` + jam/rewrite/hijack immunity guards),
`battle_engine.gd` (frozen roll overrides, effective-roll guards, item freeze),
`policy_l1_greedy.gd` (freeze enemy's lowest revealed die, never allies),
TRUTH.md combat rule 7, `keywords.data.json`, regression coverage in
`ability_audit.gd` (`_run_enemy_freeze_regression`, `_run_freeze_repeat_regressions`)
and `freeze_engine_regression.gd`.

---

## 3. Buff/DoT timers — INDEPENDENT INSTANCES *(ruled by Kev, 2026-07-06)*

**Ruling.** Roll buffs (`rfm` and `erb`, both sides) and DoTs (burn) stop
refreshing to max on recast. Each application is its own instance with its own
remaining duration; the effective value is the sum of live instances; each
expires on its own clock. Display aggregates ONE chip: summed value, longest
remaining duration. Canonical passing case: +3 for 2 turns cast turn 1, +5 for
2 turns cast turn 2 → turn 2 total +8, turn 3 total +5, turn 4 zero.

Supersedes the fix-1.2 enemy-erb refresh-to-max compromise (which capped value
at the authored per-cast amount and refreshed the timer on re-cast). Burn
previously summed value but refreshed to the longest timer — now each burn
instance runs its own clock (skip-first-tick timing preserved: an Nt burn deals
N ticks over the N rounds after application).

**Known consequences (flagged, not silently tuned):** a 1t roll buff cast
mid-round expires at that round's tick without shaping a roll — affects
`erbT: 1` (2 enemy abilities) and the Emergency Signal relic
(`lowHpSquadRollBuff`, 1t). Follow-up duration tuning is a separate balance call.

**Where it lives:** `combat_manager.gd` (`roll_buff_stacks` / `burn_stacks` +
`_tick_state`), TRUTH.md combat rule 10, regression coverage in
`ability_audit.gd` (`_run_instance_timer_regressions`,
`_run_enemy_roll_buff_expiry_regression`).

---

## 4. Permanent-burn Detonate — ONE TICK, NOT CONSUMED *(ruled by Kev, 2026-07-06)*

**Ruling.** Detonate on a PERMANENT burn (plagueProtocol) deals exactly one
tick's damage (the burn amount) and the permanent burn is NOT consumed — it
keeps ticking. Finite burns are unchanged: amount × remaining turns, consumed.
`DETONATE_MAX_TURNS` (the 6-turn placeholder cap that bounded the 9999-turn
sentinel) is removed as the mechanism. Payload Fuse's +50% applies to the whole
burst, permanent-tick portion included.

**Where it lives:** `combat_manager.gd` (`_detonate_burn` +
`get_expected_detonate_burst`, single-sourced into the live Detonate pip in
`battle_card_view.gd`), `keywords.data.json` Detonate def, TRUTH.md keyword
table, regression coverage in `_run_detonate_regression`.
