# Boss relic rework: tuning report (2026-09-28)

The first sections are the original report (no number changed then). The
final section records Kev's two tuning changes (G-42), the re-run and the
re-pinned baseline.

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

## Baseline (original report)

Adding two relics to the draft pool changes what the battle-5 relic cache
offers, so the pinned 300-run baseline moves. It was not re-pinned in the
original report; see the final section.

## Final tuning (Kev, 2026-09-28, G-42)

Kev approved both directions: Heretic Signal costs 3 Protocol, and Tectonic
Charge becomes +3 from round 2 plus a shield on every hero while they hold in
round 1, with the shield sized by the sim to land +2 to +5. Same method as
above (l1, 2,000 matched-seed runs per arm, seed base 920000, same control arm).
Every arm below ran on the final code; the shield sweep set the amount with
`--item-field tectonicCharge/shield=N`.

| Arm | Clear | Change | Facility | Hive | Veil | Signal Purge | Mantle Hunt |
|---|---|---|---|---|---|---|---|
| No relic | 24.7% | | | | | | |
| **Heretic Signal, 3 Protocol (final)** | 27.6% | **+2.9** | +4.1 | +0.9 | +5.0 | +2.8 | +2.2 |
| Tectonic +3, no shield | 25.1% | +0.5 | +4.8 | -0.2 | -9.1 | -3.3 | +9.2 |
| Tectonic +3, shield 2 | 27.5% | +2.8 | +9.4 | +2.5 | -6.9 | -2.0 | +9.9 |
| **Tectonic +3, shield 3 (final)** | 28.3% | **+3.6** | +10.9 | +2.7 | -6.0 | -0.5 | +10.4 |
| Tectonic +3, shield 4 | 29.8% | +5.1 | +12.7 | +3.6 | -5.8 | +1.3 | +12.9 |
| Tectonic +3, shield 8 | 33.4% | +8.7 | +17.8 | +6.3 | -1.4 | +5.8 | +14.4 |

**Shield chosen: 3** (+3.6, the middle of the band). Shield 4 is +5.1, just
over the edge; shield 2 (+2.8) sits near the bottom. The shield is an ordinary
one-round shield granted to each living hero as round 1 resolves, so it covers
that round's enemy phase only.

Heretic Signal at 3 Protocol reproduces the proposal run exactly (+2.9), now
on the real rule rather than a test override.

Tectonic Charge stays uneven by operation: the hold still costs Veil (-6.0),
and Facility and Mantle Hunt gain about +10. Noted, not tuned further; the
brief's target is the overall change.

### Final boss relic table (change vs no relic)

| Relic | Change |
|---|---|
| Scrap Converter | +4.9 |
| Blood Frenzy | +5.3 |
| Firewall Hack | +4.4 |
| Heretic Signal (3 Protocol) | +2.9 |
| Tectonic Charge (+3, shield 3) | +3.6 |

Overheal Relay (+8.5) and Spillover Charge (+7.8) keep their names and numbers
(held from battle 1; a drafted relic normally arrives at battle 5).

### Baseline re-pin (BASELINE-APPROVED-BY-KEV)

`scripts/sim/baseline.json` (the pinned 300-run CI batch) re-pinned on the
final tree: overall **0.2567** · facility **0.3662** · hive **0.2542** · veil
**0.2308** · voidCirclet **0.2281** · stellarMenagerie **0.1667** (was
0.2767 · 0.4085 · 0.2373 · 0.2615 · 0.2105 · 0.2292). The CI batch holds no
boss relic, so the two tuning changes don't touch it; the move is the two new
draft relics changing the battle-5 relic cache, exactly the drift predicted in
the original report (largest per-op move -6.2, stellarMenagerie).
