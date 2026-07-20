# Balance-sim telemetry schema (Package B.1)

*One JSONL line per event. Same seed + same config ⇒ byte-identical files (the
A.5 determinism gate enforces it). `scripts/sim/replay.py` (B.4) renders these
lines as a human-readable replay.*

**schema_version: 1** — bump when a line type or field changes meaning; add-only
changes may keep the version but must be noted here.

## Envelope (every line)

| field | type | meaning |
|---|---|---|
| `run_id` | string | `run_<seed>` |
| `seed` | int | master seed (reward-rng seeded with it; d20 stream with `seed ^ 0x9E3779B9`; policy stream with `seed ^ 0x51F15EED`) |
| `t` | int | monotonic line counter per run (0-based) |
| `type` | string | line type, below |

## Line types

### `run_header` — first line
`policy` (stub/l0/l1/…), `squad` [unit ids], `op` (operation id),
`sim_version`, `schema_version`, `roll_source` (provider description),
`order_mode` (L2 cast-order seam: "" default / search / setups / squad).

### `battle_start`
`index` (1-based battle number), `comp` [enemy display names],
`modifier` (route modifier id or ""), `battle_effects` (the consumed
next-battle effects dict; {} when none), `squad_hp` [per hero, battle start],
`protocol` (pool after battle-start grants).

### `round` — one line per resolved round
- `index` battle number, `round` 1-based round number.
- `hero_rolls` / `enemy_rolls`: {state_id: raw d20} as rolled (after frozen
  overrides + thaw reveals — i.e. the faces actually shown).
- `eff_hero_rolls` / `eff_enemy_rolls`: {state_id: effective roll} after
  set/nudge/buffs/rfe, as resolved.
- `spends`: policy protocol spends this round, in order:
  `{kind: nudge|reroll|set|item|twin_fates, unit, cost, detail}`.
- `cast_order`: [hero state ids] in the order the hero phase fired them
  (player-chosen cast order; the PLANNED order — a hero killed mid-phase by
  spike stays listed but did not act). Add-only field, schema_version kept.
- `events`: the CombatManager event stream for the round, verbatim
  (`action_start`, `damage`, `burn`, `heal`, `shield`, `freeze`, `summon`,
  keyword events, … — see combat_manager `_emit_event`/`_emit_action_event`).
- `squad_hp` / `enemy_hp`: [current HP per living slot, 0 = down] after the
  round.
- `protocol`: pool after grants/drains/income.

### `battle_end`
`index`, `result` (victory/defeat), `rounds`, `squad_hp`, `protocol_left`,
`deaths` [hero unit ids that ended the battle down].

### `draft` — post-win reward pick
`index` (battle just won), `options` [{id, type, rarity}], `picked` (item id
or "" when skipped), `target_unit` (gear only, else "").

### `beat` — fork/intercept between battles
`after_battle`, `beat_type` (fork/intercept), `tier` (minor/major, intercept),
plus per type:
- fork: `modifier` (offered id or "" when every candidate redrew away),
  `took_flagged` (bool).
- intercept: `card` (card id), `choice` (choice index), `hero` (picked hero id
  or ""), `drafted` (item id or "").

### `progression` — evolution / directive stop
`unit`, `kind` (evolution/directive), `options` [names], `picked` (name).

### `run_end` — last line
`result` (victory/defeat/battles_limit/incomplete), `battles_cleared`.

## Determinism contract

- No line may contain wall-clock time, absolute paths, or unseeded randomness.
- Dictionary field order is insertion order in the emitting code — do not
  reorder emit sites casually; the A.5 gate compares bytes.
- All three RNG streams derive from the master seed (see envelope) and
  `randomize()` is never called on the sim path.
