# Boss relic rework: tuning report (2026-09-28)

Report only. No number was changed. Branch `boss-relic-rework`.

## Method

Balance sim, policy `l1`, 2,000 runs per arm, matched seeds (seed base
920000: every arm plays the same squads, operations and dice streams), random
squad and operation per run. A relic arm grants the relic from battle 1
through the Starting Directive slot (`batch.py --grant`), so the battle-5
relic draft still happens, exactly like a real directive run. The control arm
has no directive. Noise: about 1 point per arm; matched seeds make the
difference between two arms tighter than that, but treat anything within
about 1.5 points as a tie.

The L1 bot now uses the two active relics with simple rules:
- **Firewall Hack:** once per turn, with at least 2 Protocol, hack the enemy
  die with the highest value whose -3 drops it into a lower band.
- **Heretic Signal:** re-throw when the enemy dice sit at least 8 pips above an
  average d20 (10.5 each) more than the hero dice do. Frozen dice don't count.

## Results (clear rate, change vs no relic, points)

Target for each boss relic: roughly +2 to +5.

| Arm | Clear | Change | Facility | Hive | Veil | Signal Purge | Mantle Hunt |
|---|---|---|---|---|---|---|---|
| No relic | 24.7% | | | | | | |
| Scrap Converter | 29.6% | +4.9 | +8.6 | +2.3 | +2.7 | +6.6 | +4.7 |
| Blood Frenzy | 30.0% | +5.3 | +6.9 | +2.3 | +6.6 | +5.1 | +6.2 |
| Firewall Hack | 29.1% | +4.4 | +5.6 | +1.4 | +7.7 | +5.8 | +2.2 |
| **Heretic Signal** | 36.8% | **+12.1** | +14.5 | +10.0 | +18.1 | +12.1 | +6.7 |
| **Tectonic Charge** | 19.4% | **-5.2** | -3.6 | -8.1 | -10.2 | -7.8 | +3.2 |
| Overheal Relay (draft) | 33.2% | +8.5 | +7.1 | +7.9 | +6.6 | +13.6 | +7.2 |
| Spillover Charge (draft) | 32.5% | +7.8 | +8.9 | +8.8 | +6.6 | +8.8 | +5.4 |

Scrap Converter, Blood Frenzy and Firewall Hack are in the target (Blood
Frenzy's +5.3 is within noise of the edge).

## Proposals (measured, not applied)

| Relic | Proposal | Measured change |
|---|---|---|
| Heretic Signal (+12.1) | **Costs 3 Protocol** to use | **+2.9** (4 Protocol: +1.3) |
| Tectonic Charge (-5.2) | **+3 from round 2** (was +2) | **+0.5** (+4: +8.0) |

Heretic Signal at 3 Protocol lands in the target. It adds a cost the brief
doesn't have, so the relic text and confirm would change; that's Kev's call.

Tectonic Charge has no integer bonus inside the band: +3 is the closest
(+0.5, just under), +4 overshoots (+8.0). Losing every round 1 costs a lot on
Veil and Signal Purge (still -9.1 and -3.3 at +3). If +3 isn't enough, the
lever is the hold itself, not the number.

The two draft relics (+8.5, +7.8 when held from battle 1) are strong for a
normal relic, but a drafted relic normally arrives at battle 5, so the real
effect is smaller. There is no target for them in the brief.

## Baseline

Adding two relics to the draft pool changes what the battle-5 relic cache
offers, so the pinned 300-run baseline moves. See the handoff for the
`verify_gate` delta table; the baseline was NOT re-pinned.
