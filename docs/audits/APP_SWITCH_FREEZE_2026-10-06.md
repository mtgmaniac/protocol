# App-switch freeze on mobile web: trace and proposal (2026-10-06)

Report only. Nothing in the game changed for this item.

**Playtest report (Kev):** on the phone, switching to another app and coming
back freezes the game, and the page has to be reloaded.

**Starting point:** `DESIGN_AUDIT_2026-10-02` section 9a (branch
`claude/design-audit-2026-10-02`): the browser drops the WebGL context of a
backgrounded page, Godot cannot restore it, and its only notice is an
`alert()` that the itch frame may block.

## Verdict

The audit's cause stands, with two corrections.

1. **It is not a visibility or focus handling problem.** The build has no such
   handling and does not need any for a plain pause: a page hidden for 60
   seconds resumes cleanly (measured below).
2. **The game does not stop. It keeps running with a dead picture.** After a
   context loss the main loop, input and audio all carry on; only drawing is
   gone, and it never comes back, even when the browser hands the context back.

So what the player sees as a freeze is the last picture (or a blank one) over a
game that is still running. Reload is the only recovery the build has.

**Confirmed here:** what the shipped build does when the context is lost, by
reading the export and by forcing the loss in a desktop browser.
**Not confirmed here:** that the phone loses the context on an app switch.
That needs the phone; a 30-second check is at the end.

## What the shipped build does (read from `build/itch-2026-09-28/index.js`)

- **Context loss:** one handler, on the canvas:
  `alert("WebGL context lost, please reload the page"); ev.preventDefault()`.
  There is no `webglcontextrestored` handler anywhere in the export.
- **Visibility:** no `visibilitychange`, `pagehide`, `pageshow` or `freeze`
  handler in the engine script (the one `visibilitychange` in it belongs to
  WebXR). The main loop runs on `requestAnimationFrame`, so it simply gets no
  frames while the page is hidden.
- **Focus:** canvas `focus` / `blur` become window focus notifications; a
  window `blur` releases held inputs. Nothing in `scripts/` handles either
  (no `NOTIFICATION_APPLICATION_*` or focus notification is used).
- **Audio:** the context's state callback knows `suspended`, `running` and
  `closed`; any other state (iOS's `interrupted`) reads as suspended.
  `web/shell.html` re-resumes audio on `visibilitychange` / `pageshow` /
  `focus`. Audio does not gate the main loop in this (non-threaded) export.
- The export preset is non-threaded (`variant/thread_support=false`), canvas
  resize policy 2, custom shell `web/shell.html`.

## Experiments (desktop Chromium, the same `index.js` as the itch build)

`build/web/index.js` is byte-identical to the itch build's. A scratch copy of
its `index.html` got a small hook (frame counter, `alert` recorder, a pixel
checksum of the canvas, and commands to hide the page or lose the context).
The scratch pages are deleted; nothing in the repo or the build was changed.

| Test | Result |
|---|---|
| Page hidden + blurred, no frames for 8 s, then visible + focus | Frames resume at once, the title keeps animating, no errors, context intact |
| Same for 60 s (one 60,012 ms gap between frames) | Same: resumes, animates, no errors |
| Context lost (`WEBGL_lose_context.loseContext()`), top-level page | `webglcontextlost` fires once; the engine calls `alert("WebGL context lost, please reload the page")`; frames keep counting (about 50 a second); audio context still `running`; no script error; the canvas reads back empty |
| Then `restoreContext()` | `webglcontextrestored` fires and the context is valid again, but the canvas is one flat colour and never changes: the engine does not rebuild |
| Context lost inside a frame from another origin (ports 8123 / 8131, as itch embeds it) | Same engine behaviour: loop and audio keep running, nothing draws |

Not measured: whether Chrome shows that `alert()` inside the itch frame. The
browser used here suppresses every native dialog, so it cannot tell. Chrome's
enterprise policy documentation says `alert` / `confirm` / `prompt` are
blocked when they come from a frame whose origin differs from the page's (in
place since Chrome 92, briefly reversed in 2021), and itch serves the game from
its own origin inside a frame. So the expected result on Android Chrome is no
message at all, which matches the report (a freeze, no message). That is
documented browser behaviour, not something seen on the phone: if the phone
ever DID show "WebGL context lost, please reload the page", that alone
confirms the cause.

## Why an app switch loses the context

Mobile browsers free a backgrounded page's GPU resources, sometimes after a
few seconds and more readily under memory pressure (this build keeps a 3D dice
viewport and a large texture set resident). The page stays alive, so nothing
reloads on return; it comes back with a lost context. This is ordinary browser
behaviour and the page cannot prevent it.

What does not fit this cause, and would point elsewhere:
- total silence and no reaction at all after returning (page frozen or
  discarded by the browser, or a script abort);
- the loading bar appearing by itself on return (the browser discarded the tab
  and reloaded it: not a freeze, and the run save is intact).

## Consequences worth knowing

- **The run keeps going blind.** Taps still land and timers still run under
  the dead picture, so a player poking at a frozen screen can press buttons
  they cannot see.
- **Saves are not at risk.** Nothing in the save path uses the GPU, and the
  loop keeps running, so the run save stays at the last checkpoint.
- **Reload then CONTINUE is the real recovery, and it was broken mid-battle.**
  Until item 1 of this batch (G-48), CONTINUE restarted a battle at round 1
  instead of restoring the round. With that fixed, reload + CONTINUE returns
  to the round's saved dice.

## Proposed fix (not built)

**Step 1, shell only (`web/shell.html`), small.** The engine cannot recover, so
make the failure visible and the recovery one tap.

- Listen for `webglcontextlost` on the canvas in the shell, registered before
  the engine's listener, and stop the event there so the engine's `alert()`
  never fires (it is either blocked or a native dialog over the game).
- Show an in-page overlay in the loader's styling, covering the canvas so
  blind taps cannot reach the game: "The display was lost. Reload to keep
  playing." with one RELOAD button (`location.reload()`).
- Suspend the audio context while the overlay is up.
- Optional: when the loss is seen while the page is hidden, reload by itself
  as the page becomes visible again, so the player returns to a loading bar
  instead of a prompt.

**Step 2, optional (a few lines in `main_menu.gd`).** The shell sets a
`sessionStorage` flag before that reload; on boot the menu reads it and goes
straight into CONTINUE. With G-48's fix that lands the player back on their
round. It should still pass through the resume guard's marker, so a reload
loop cannot form.

**Not proposed:**
- Restoring the context in place. Godot 4.6.2 has no path for it; it would be
  an engine change.
- Pausing the scene tree while hidden. It does not address the freeze. It
  would stop timers running in the background, which is a separate nicety.

**How to gate it.** `scripts/debug/web_loader_test.cjs` already drives an
exported build in a browser. Add a case: force the loss with
`WEBGL_lose_context`, expect the overlay, expect no `alert`, press RELOAD,
expect a fresh load with CONTINUE on the menu. It needs a web export, so it
sits beside the loader test, outside `verify_gate.py`.

## 30-second check on the phone

After the next freeze, before reloading:

1. Is the music still playing?
2. Tap where a button was (for example the help "?" in the header). Do you
   hear the click?

Yes to either: the game is running under a dead picture, which is the context
loss above. Silence and no reaction: a different cause, and the state code
plus the browser console (`chrome://inspect` over USB, look for
`CONTEXT_LOST_WEBGL` and "A different origin subframe tried to create a
JavaScript dialog") would be the next thing to capture.

## Open question for Kev (from the audit, still open)

Is a reload prompt acceptable as the recovery, or should the page reload by
itself on return (step 1's optional part) and resume the run (step 2)?
