# Visual review reproducibility

Audit source: `364822d`, Godot 4.6.2, Compatibility renderer, 2026-09-06.

`build_visual_inventory.py` and `content_visual_index.py` regenerate the file/content/function indexes from this repository. They require Pillow and use Windows Consolas for contact labels. The content notes describe the reviewed edition and must be updated deliberately after content changes. Literal references and filename conventions are evidence, not a proof of reachability or permission to delete unused assets.

The two PowerShell scripts show the exact still-capture setup and flags used. They create scratch rigs under `debug_artifacts`, load HelpMenu only after autoload initialization, run hidden Godot instances, and bound each scene to 25 seconds. Paths describe this Windows checkout. `visual_extra.ps1` sets window size after initialization; this is necessary for the 390x844 / 432x960 probes.

To reproduce motion, copy the two `.gd` files into `debug_artifacts/` (the round rig extends the motion rig), then launch each with the console Godot executable, `--path` pointing to the repo, `--rendering-method gl_compatibility -s res://debug_artifacts/visual_motion.gd` (and then `visual_round.gd`). Run windowed for real rendering, in a hidden process. `-s` activates the repository's profile isolation. Do not run these probes against the player's normal profile.

Motion scratch frames live under `debug_artifacts/visual_motion`. The published GIFs use 270x600 frames, preserve measured sample intervals and add a final display hold. They are review artifacts, not real-time performance recordings. `frame-timing.json` stores capture timing. The isolated power-down probe intentionally uses the shader on a menu transition; normal runtime reserves it for defeat.

The final capture logs contain no script errors; two still rigs report resources in use on shutdown, and missing revive/summon audio warnings predate this review. The functional baseline was `python scripts/verify_gate.py --skip-sim`: all hard gates passed. No game implementation or balance changed.
