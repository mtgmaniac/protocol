# v0.4 polish verification (2026-10-17)

Base: `main` at `66e346e`; work branch `fix/v04-polish`. Godot remains
4.6.2.stable.official.71f334935. Unrelated deleted raw art is excluded.
The full gate runs once at final release, per the task's explicit instruction.

| Phase | Result |
|---|---|
| Width cap | Shared 1080-design-pixel centered column; existing inner margins and vertical spacing retained |
| Screens | Squad select, title, Help, battle (board/tray/footer), reward, victory and defeat; shared header aligned |
| Captures | 32 PNGs in `debug_artifacts/v04_polish`: each screen plus Help Settings at 360x800, 390x867, 540x1200, 1280x900 |
| Relevant gates | Layout rhythm 68/68; component contract PASS; panel count PASS; portrait width PASS |

No combat or balance implementation changes. The width regression checks live
centering and maximum width and captures every requested screen. Backgrounds
and modal scrims retain their existing full-window layout.

## Gate debt and analytics

| Area | Result |
|---|---|
| Title/unlock | Clears the inherited dev run save; NEW GAME behavior unchanged |
| Framing | Removed constant replaced by current TILE_PORTRAIT_W; editor 34/34 and sheet 25/25 pass; dev directory excluded from exports |
| Size-break stamp | Refreshed against G-74. Old test-only +8% Hive damage moved -7.9 pp, below the unchanged 8 pp limit. +16% fixture moves -14.6 pp and flags Hive; no live data/pin change |
| Analytics | Adapted WIP e8835cb; five requested event types, UUID, opt-out, persisted retry queue, editor/debug suppression |
| Focused gates | 10/10: telemetry, validate-data, component contract, text legibility, flow smoke and five save gates |
| Local HTML5 | Actual HTTPRequest client received 7/7 accepted responses from Vercel; no browser errors; no server credentials in client |
| Independent row count | Pending approval: protected Vercel secrets cannot be exported; dashboard access was blocked by automatic review |

G-92 records the privacy ruling and supersedes the earlier no-telemetry scope.
See `TELEMETRY.md` for verified backend fields, retry limits and test UUID.

## Matched balance (report only)

Policy `l1`, seeds 900000–901499, random three-of-eight squads using the G-74
picker sequence (including each original operation draw), each squad replayed
on all five operations: 1,500 runs per operation per revision. Reference is
G-74 commit `3d095d2`, expanded to the same sample as requested; the committed
G-74 mixed-operation pin had 1,500 runs total. Both arms use fresh sim-runner
objects and the unchanged authoritative `_run` routine. All 7,500 JSONL traces
are byte-identical between revisions. No errors, no tuning, no re-pin.

| Operation | Now | G-74 matched | Change (pp) |
|---|---:|---:|---:|
| Facility Sweep | 34.40% | 34.40% | 0.00 |
| Hive Incursion | 22.87% | 22.87% | 0.00 |
| Veil Breach | 18.47% | 18.47% | 0.00 |
| Signal Purge | 18.20% | 18.20% | 0.00 |
| Mantle Hunt | 15.73% | 15.73% | 0.00 |

Mantle Hunt's +14.6 does **not** hold. That compared different small samples;
the matched comparison has zero change.

Hive threats: `BURN · SWARM · SIPHON` → `BURN · SWARM · LEECH`.
The Mite (40%), Stalker (45%) and Matriarch (35% / 40%) have `lifestealPct`
abilities; none of the Hive kits has `siphon`. This is copy only.
