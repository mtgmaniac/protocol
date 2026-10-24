# Anonymous gameplay analytics — G-92, 2026-10-17

Adapted from `codex/godot-telemetry` commit `e8835cb`. The client sends only to
`https://overload-telemetry.vercel.app/api/telemetry`. The verified handler is
`C:/Users/Kev/Documents/overload-telemetry/api/telemetry.js`, in Vercel project
`overload-telemetry`. It inserts into Supabase `game_events`. All database
credentials stay on the server; none is present in the Godot client/export.

## Verified wire contract

The handler accepts one JSON object per POST, with required `event_name`,
`player_id`, `session_id`, `game_version`; optional `run_id`, `operation`,
`battle_index`, `round_index`, `payload`. Success is HTTP 200 with `ok: true`.
Its OPTIONS handler and CORS headers permit browser POSTs with Content-Type.
The client drains at most eight sequential POSTs per batch to honor this API.

`player_id` and the legacy required `session_id` both contain the same random
install UUID. `payload.install_id` names it explicitly. Each event includes
UTC `payload.timestamp`, schema_version 2, game version and run ID. Run IDs
hash local run context; seeds and save dumps are never transmitted.

| Event | Collected gameplay fields |
|---|---|
| run_start | Operation, squad hero IDs, unit levels (no ascension system exists) |
| battle_end | Battle number, win/loss, turns, surviving hero IDs |
| run_end | cleared/wiped/abandoned, battle reached, operation, active seconds, relic IDs |
| reward_pick | Battle number, kind, offered IDs and picked ID: items/relics/evolutions/traits/intercepts/starting relic |
| tutorial | started/completed/skipped, tutorial marker |

Closing the app is not an abandonment. Explicit new-run/reset is. Continue
does not invent another start. A persisted battle guard suppresses repeated
result hooks. Tutorials are marked and excluded from normal run starts/ends.
Active seconds accrue only with a live squad while the app is focused; they
persist with events and every 30 seconds. Sudden termination can lose the last
30 seconds. Idle title time and closed/background time are excluded.

## Privacy and persistence

`telemetry_install_id` is one Crypto-generated UUID v4 in profile settings,
independent of gameplay RNG. No names, emails, IP fields, hardware identifiers,
fingerprints or account links are collected or stored by our code/database.
The host may independently keep infrastructure request logs.

Settings has **Share anonymous gameplay data**, ON by default, with one line
of explanation; Help > BASICS also explains the opt-out. OFF cancels an active
request and clears both queues/context. No new request/event is made while
OFF. The UUID remains so re-enabling does not create a second install identity.
An already accepted request cannot be recalled.

**Developer mode silences the session (Kev, DEMO v0.51, G-106).** Once Help >
PREFS > DEV > Developer mode is turned on (possible in release builds after
the seven-tap unlock), `Telemetry.silence_for_dev_session()` stops analytics
until the app is relaunched: an in-flight request is cancelled, every event
queued in this session is dropped (from memory and from the saved
`telemetry_state`), nothing new is queued or sent, and turning **Share
anonymous gameplay data** back on does not restart it. Events left over from
earlier sessions stay saved and may be sent by a later session. Turning
Developer mode off again does not resume sending. Gate: `developer unlock`.

Editor/debug builds never initialize transport without `--telemetry-debug`.
All automated gates stay loopback-only. DevContext keeps their profiles isolated.
The project-wide `overload/telemetry/enabled=false` switch also disables sending.

Events persist in `settings.telemetry_state` beside the memory queue. Writes
are coalesced at the end of the frame. The queue holds at most 128 events of
8 KiB each, retaining the in-flight head and evicting the oldest waiting event
on overflow. Batches flush at battle/run/tutorial ends and every 30 seconds.
Failures retain the event; retry begins after 60 seconds. Timeout is 5 seconds,
redirects are disabled. No gameplay awaits transport. Invalid/empty responses,
offline errors and server errors are silent. Delivery is best effort: a server
insert whose response is lost can be repeated on retry (the current backend
has no event-id deduplication). Reports must treat client events as untrusted.

## Verification

`python scripts/checks/telemetry_gate.py` tests the real client against loopback:
debug isolation, UUID/RNG, real save/resume, rewards/evolution/traits, lifecycle,
active time, opt-out/cancellation, queue bounds/persistence and retry after
500, invalid JSON and timeout. It is part of the full gate.

Manual web probe (never part of automatic gates): with GODOT_BIN set, run
`python scripts/checks/export_telemetry_probe.py`. It uses the existing Web
release preset and temporarily selects a probe scene, restoring project.godot
in a finally block. Serve `build/telemetry-web` on localhost and open it in a
browser. The probe refuses other hosts/platforms and uses a fresh
synthetic UUID in the isolated dev profile. It emits seven marked test events
through the actual HTTPRequest client and displays accepted count + UUID.
Count only that UUID's rows with a server-side HEAD/count query; never put
server credentials into the browser, project, logs or export. Production build
uses the unmodified shell and normal MainMenu scene.

Local HTML5 lifecycle check on 2026-10-17: **7/7 accepted**, no browser errors.
Real run/battle/reward/reset/tutorial hooks generated the payloads, including
normal hashed run IDs. Synthetic install UUID
`cd74ca2d-cb5a-4fb6-8129-e40774d5866b`, source
`v04_local_web_smoke`. Independent row count pending: Vercel protects the secret
values from export and approval review blocked dashboard access.
The earlier transport-only probe also received 7/7 accepted under
`e1975452-c979-40bb-a5e8-e9e606c4a8f6`; both probes are explicitly marked synthetic.
