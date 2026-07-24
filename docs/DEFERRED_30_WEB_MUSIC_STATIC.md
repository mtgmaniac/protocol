# Deferred #30 — residual music static on web (post-demo)

**Status:** shipped with mitigations in 0.9.0-demo2-final (2026-07-24). Not
demo-blocking. This ticket holds everything learned so the post-demo fix
starts warm.

## Symptom

Faint intermittent static under encounter music on the web build, clearly
worse when many dice clicks fire at once. Audible on Kev's hardware;
NOT reproducible in the instrumented browser-pane test rig (which cannot
composite frames and therefore cannot generate real rendering load).

## What is ruled out (measured, 2026-07-24)

- **Clipping at the destination: ruled out.** Instrumented true-peak at the
  WebAudio destination through a real roll AND a full turn-resolve with
  combat music: worst peak 0.41 (-7.7 dBFS), zero windows ≥ 0.9 in ~1000.
  The 110 ms global click gap means dice clicks (80 ms samples) can never
  overlap each other, and ability SFX are normalized ~-13 dBFS. The sum
  never approaches full scale.
- Bus graph corruption: ruled out earlier in the hybrid work — predefined
  buses build a correct sample graph (Master→destination verified intact).

## Prime suspect

**Ring starvation on real dice-heavy frames.** The stream mixer runs on the
main thread (single-threaded export); frames spiking past the ring length
drop audio quanta. All correlations fit: static tracks the heaviest frames
(physics contacts + click spawns + 3D), it improved when the ring went
43 ms → 85 ms (demo1 → demo2), and 85 ms did not eliminate it. The ring is
now 170 ms (`output_latency.web=150`); synthetic 120 ms main-thread stalls
during a live roll log 0 glitch windows of 365 at this size (the 85 ms
ring glitched 17% under the same load).

## Isolation test (the single bit that halves the search space)

**Run on hardware that reproduces the static** — the instrumented rig
measures zero anomalies with or without dice, so the A/B is only
meaningful by ear on a reproducing machine. No special build needed:
Settings → AUDIO → DICE row → toggle OFF, play one encounter.

- Static **still present** with DICE off → the music stream/mixer path
  alone (dice were just making frames heavier). Next levers:
  `output_latency.web=200`, or a thread-enabled export variant
  (`variant/thread_support=true`, costs iOS Safari compat — would need a
  capability-gated dual upload).
- Static **gone** with DICE off → interaction between sample-path
  scheduling and the stream (summing is already excluded by the peak
  measurements). Next step: instrument the sample-path `AudioBufferSource`
  scheduling jitter under load, and try routing dice through the stream
  path (`playback_type = STREAM` on the DiceAudio pool) as an A/B.

## Mitigations shipped in demo2-final

- `output_latency.web` 100 → 150 (85 ms → 170 ms ring).
- Master bus -3 dB (default_bus_layout.tres — applies to both stream and
  sample paths; C++ mixer natively, JS master gain for samples).
- DICE channel default 0.4 → 0.2 (a further -6 dB; fresh profiles only,
  saved sliders keep their value).

## Measurement tooling (reusable)

- `DiceAudio.DEBUG_CONTACT_LOG` — per-contact decision log.
- Seeded 5-dice probe: `godot --headless --path . res://scenes/debug/DiceTrayPhysicsProbe.tscn`
  (prints the per-roll `[DiceAudio]` stats line).
- The browser monitor (destination peak + dropped-quanta windows + stall
  injector) is a `<head>` injection over `build/web/index.html`; the
  pattern is preserved in the session transcripts of 2026-07-24 and is
  ~60 lines to recreate: wrap `AudioContext`, tap nodes connecting to the
  destination with an `AnalyserNode`, scan `getFloatTimeDomainData` for
  ≥128-sample exact-zero runs (dropped quanta) and per-window peaks.
