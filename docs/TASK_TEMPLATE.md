# TASK TEMPLATE — the skeleton every task prompt follows

Copy the skeleton, fill every section. A task that skips a section is incomplete by
definition (docs/INVARIANTS.md #10). Weaker sessions: follow this literally.

---

## Skeleton

```
TASK: <one line, imperative>

STEP 0 — CONTEXT (do before any edit):
- Read docs/TRUTH.md, then docs/INVARIANTS.md, then docs/DECISIONS_RESOLVED.md
  (check the task doesn't relitigate a ruling; if it implements a RULED-pending
  item, transcribe the ruling text into DECISIONS_RESOLVED.md FIRST).
- Run the baseline gate on the untouched tree and record the per-op snapshot:
    python scripts/verify_gate.py            (or --skip-sim if no balance surface)

CONSTRAINTS (explicit, incl. relevant invariants by number):
- <e.g. INVARIANTS #1 determinism fence — no randi, sim must reproduce>
- <e.g. INVARIANTS #3/#12 — keyword + manual-pick budgets, audit-enforced>
- <files/fields that must NOT change, e.g. ai_type (INVARIANTS #2), legacy ids (#11)>

CHANGE:
- <the actual work, smallest coherent slice>

VERIFY (all must pass; paste outputs):
- python scripts/verify_gate.py
- <task-specific regression: name the new/updated test in ability_audit.gd or
  the dedicated runner that pins the changed behavior>

REPORT — BEFORE any baseline update:
- Per-op clear-rate deltas vs the step-0 snapshot, as a table, in the commit
  message and the session log. Any |delta| > 10 pts → STOP, report to Kev,
  do NOT self-approve (INVARIANTS #9; the commit-msg hook enforces the token).

CLOSEOUT (same commit as the code):
- TRUTH.md updated to match the new behavior.
- DECISIONS_RESOLVED.md updated if a ruling was implemented.
- New regressions committed with the change they pin.
```

---

## Filled example (real, landed 2026-07-06 as part of 52e2fa5)

```
TASK: Permanent-burn Detonate deals one tick and is not consumed.

STEP 0 — CONTEXT:
- TRUTH.md keyword table says Detonate uses DETONATE_MAX_TURNS=6 for permanent
  burns — DECISIONS_RESOLVED.md #4 rules that dead: one tick, not consumed.
- Step-0 gate: all green; per-op snapshot recorded in the session log.

CONSTRAINTS:
- INVARIANTS #5 (legibility): the new rule must be one sentence — "a permanent
  Burn adds one tick's damage and is not consumed."
- INVARIANTS #10: TRUTH.md keyword row + keywords.data.json def update in the
  same commit.
- Finite-burn behavior (amount × remaining turns, consumed) must NOT change.
- The live Detonate pip must show the same number combat will deal — single-source
  the burst math, don't duplicate it in UI code.

CHANGE:
- combat_manager.gd: _detonate_burn reworked over burn stacks; permanent stacks
  contribute amount×1 and survive; DETONATE_MAX_TURNS deleted. New public
  get_expected_detonate_burst(attacker, target); battle_card_view.gd pip reads it.

VERIFY:
- python scripts/verify_gate.py  → all gates PASS (audit 224/0).
- New regressions: "permanent-burn detonate = one tick, not consumed" and
  "detonate mixed finite+permanent stacks" in _run_detonate_regression.

REPORT:
- Detonate change itself: no per-op move beyond noise (the batch's freeze ruling
  dominated the table — reported separately, baseline NOT updated, ceremony open).

CLOSEOUT:
- TRUTH.md Detonate row + keywords.data.json def updated in the same commit;
  DECISIONS_RESOLVED.md #4 marked RESOLVED & IMPLEMENTED.
```
