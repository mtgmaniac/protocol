# v0.4 polish verification (2026-10-17)

Base: `main` at `66e346e`; work branch `fix/v04-polish`. Godot remains
4.6.2.stable.official.71f334935. Unrelated deleted raw art is excluded.
The full gate runs once at final release, per the task's explicit instruction.

| Phase | Result |
|---|---|
| Width cap | Shared 1080-design-pixel centered column; existing inner margins and vertical spacing retained |
| Screens | Squad select, title, Help, battle (board/tray/footer), reward, victory and defeat; shared header aligned |
| Captures | 28 PNGs in `debug_artifacts/v04_polish`: each screen at 360x800, 390x867, 540x1200, 1280x900 |
| Relevant gates | Layout rhythm 68/68; component contract PASS; panel count PASS; portrait width PASS |

No combat or balance implementation changes. The width regression checks live
centering and maximum width and captures every requested screen. Backgrounds
and modal scrims retain their existing full-window layout.
