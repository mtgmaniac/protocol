# Balance snapshot — July 2026 (shipped demo build)

*Captured 2026-07-30 from the pinned CI sim config (policy `l1`, 300 runs,
seed base 900000, full pools — `scripts/sim/ci_smoke.py`). The sim is
byte-deterministic: these numbers reproduce exactly on an unchanged tree.
**This table, not `scripts/sim/baseline.json`, is the CURRENT TRUE state of
the build the demo ships** — see the drift section below for why the two
differ.*

Design target (INVARIANTS #8): 25-40% skilled full-clear of facility in real
play; the sim's `l1` policy is a mid-skill proxy, tuned for relative
comparison rather than absolute rates.

## Clear rates — current true state

Overall clear: **36.3%**

| Operation | Clear rate |
|---|---|
| facility | 63.4% |
| hive | 28.8% |
| veil | 40.0% |
| voidCirclet | 22.8% |
| stellarMenagerie | 16.7% |

| Hero | Clear rate |
|---|---|
| combat (Strike Unit) | 47.0% |
| ghost (Ghost Operative) | 42.7% |
| breaker (Signal Breaker) | 39.1% |
| medic (Splice Medic) | 37.1% |
| engineer (Field Engineer) | 36.9% |
| avalanche (Avalanche Suit) | 30.7% |
| pulse (Pulse Tech) | 29.9% |
| shield (Spike Guard) | 25.2% |

Strongest content log-odds lifts in the current fit (top magnitude):
entropy_seed +0.67, core_surge +0.64, ignition_coil +0.58, killswitch_relay
+0.56, dead_mans_chip +0.48, harmonic_injector +0.42, phase_weave +0.39;
negative outliers protocol_cell -0.71, hero shield -0.65, deep_zero_pin
-0.49. Full metrics: `scripts/sim/acknowledged_drift.json` (clears) and the
`_ci_smoke` batch (`python scripts/sim/ci_smoke.py` regenerates them).

## Drift vs pinned baseline (ceremony debt — acknowledged)

`scripts/sim/baseline.json` still pins the older snapshot (overall 32.0%).
The delta between that pin and the table above is **accumulated debt from
earlier merges** — it predates the 2026-07-30 feedback-feature session, which
was proven drift-neutral by a stash-and-rerun at clean HEAD (identical
numbers with and without the feature diff).

| Operation | Pinned baseline | Current | Delta |
|---|---|---|---|
| facility | 63.4% | 63.4% | +0.0 |
| hive | 18.6% | 28.8% | **+10.2** (beyond the ±10 ceremony line) |
| veil | 30.8% | 40.0% | +9.2 |
| stellarMenagerie | 12.5% | 16.7% | +4.2 |
| voidCirclet | 24.6% | 22.8% | -1.8 |

Largest per-hero moves: medic +12.3 pts, ghost +9.7, combat +9.4, shield
+5.6; the rest within ±2.

**Ruling (Kev 2026-07-30):** acknowledged, do not chase. The drift moves hive
TOWARD the healthy band from its old 8.5% problem state, so the direction is
desirable. The sim freeze stands: no balance changes and no baseline re-pin
before the public demo. **Baseline re-pin is the first task of the next
balance cycle** (TASK_MASTER_LIST `BAL-001`).

Mechanics of the acknowledgment: `verify_gate.py` silences the ceremony
warning only while the deterministic metrics exactly match
`scripts/sim/acknowledged_drift.json`; any further movement re-raises the
full warning. `ci_smoke.py` standalone still diffs against the pinned
baseline and stays red on purpose — the pin itself is unchanged.
