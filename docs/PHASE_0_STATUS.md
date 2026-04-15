# Phase 0 Status

This file tracks the exact Phase 0 environment setup state so we do not accidentally jump ahead.

## Goal

Godot installed, project created, folder structure ready.

## Checklist

- [ ] Download and install Godot 4
- [x] Create new project structure in this workspace
- [x] Set up roadmap folder structure
- [x] Configure project for mobile landscape orientation
- [x] Add `GDD.md`, `ROADMAP.md`, and `CLAUDE.md` to the project
- [x] Create a minimal boot scene for the Phase 0 checkpoint

## What was verified in the workspace

- [project.godot](C:/Users/Kev/Documents/protocol/project.godot) exists and is configured for a landscape mobile-sized window.
- The expected Phase 0 folders exist under `scenes/`, `scripts/`, `data/`, and `assets/`.
- The project now has a root [CLAUDE.md](C:/Users/Kev/Documents/protocol/CLAUDE.md) as well as the full docs in [docs](C:/Users/Kev/Documents/protocol/docs).
- A minimal startup scene exists at [BootScene.tscn](C:/Users/Kev/Documents/protocol/scenes/ui/BootScene.tscn) so the project has an entry point for the roadmap checkpoint.

## What still needs manual verification

- Godot itself is not discoverable from the terminal in this session, so I could not verify the install automatically.
- I also could not press Play from here to confirm the project runs the boot scene without runtime errors.

## Important doc note

`docs/CLAUDE.md` contains one orientation conflict:

- its opening summary says portrait
- its UI rules say landscape

The roadmap also says landscape, so the project is currently configured for **landscape**.
