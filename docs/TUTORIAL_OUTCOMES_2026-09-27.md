# Tutorial free-roll outcome measurement (2026-09-27)

Step 3, using `scripts/debug/tutorial_outcome_sim.gd` and the approved shared
roll plan. No game data, HP, damage, or baseline changes. Each case has 1,000
independent seeded battles; seeds 27192026–27193025 for battle 1 and
27292026–27293025 for battle 2. Policies use matched seeds, not independent
samples of each other. Hero and enemy free rolls are uniform d20 draws through
SeededRollProvider, resolving through the real BattleEngine/CombatManager.

| Battle | Policy | Losses | Loss rate | Simulated stalls | Median victory round | Maximum victory round |
|---|---|---:|---:|---:|---:|---:|
| 1 | Basic | 0/1000 | 0% | 0 | 3 | 7 |
| 2 | Basic | 0/1000 | 0% | 0 | 4.5 | 7 |
| 1 | L1 | 0/1000 | 0% | 0 | 3 | 5 |
| 2 | L1 | 0/1000 | 0% | 0 | 4 | 7 |

Rounds include the guided opening. Basic uses no optional Protocol spending;
L1 uses its existing spend heuristic. Both use squad order, focus the lowest-HP
enemy, and direct support to the lowest-HP living hero. Guided rounds follow
the instructions, including round-two Nudge and support on Strike. The simulator
asserts the scripted enemy HP checkpoints (19, 9; practice 26).

Practice starts fresh as the actual continuation does. The selected reward is
unused, making this measurement independent of which reward the player chose.
No loss prevention, health floors, forced wins or retries are applied.

Soft-lock detection here means no legal selected target or failure to finish
within 200 rounds. These are engine simulations, not 4,000 UI playthroughs;
actual input/lesson reachability must also pass the tutorial gates. No failures
or round caps occurred. This sample does not prove safety for every possible
roll sequence or player strategy. Zero observed losses in 1,000 gives an
approximately 0.30% one-sided 95% upper bound per case.

The measured rate is below Kev's 1% stop threshold. Keep the existing SCRAP
ability table and retry prompt. Raw output: `TUTORIAL_OUTCOMES_2026-09-27.json`.

Baseline before runtime edits: `python scripts/verify_gate.py --skip-sim`,
all hard gates and profile isolation passed. Baseline unchanged.
