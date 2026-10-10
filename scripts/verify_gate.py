#!/usr/bin/env python3
"""The full verification gate, one command (successor kit, 2026-07-06).

Runs every hard gate, then the balance sim in two tiers (G-58): a 300-run
tripwire per policy (any move means combat changed; its size is not judged),
and, only when the tripwire moves, a 1,500-run size check against the pinned
line. Config, pins and thresholds live in scripts/sim/ci_smoke.py. Dumb and
loud on purpose.

  python scripts/verify_gate.py                # everything (sim tripwire ~75 s)
  python scripts/verify_gate.py --skip-sim     # hard gates only (fast)

Exit codes: 0 = all green · 1 = a hard gate FAILED · 3 = gates green but the
size check found a move beyond the line, 8 points on an operation or 4 overall
(the re-pin requires Kev's sign-off: commit message must contain
BASELINE-APPROVED-BY-KEV — see docs/INVARIANTS.md #9).
"""
import argparse
import hashlib
import re
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get(
    "GODOT_BIN",
    "C:/Users/Kev/Downloads/Godot_v4.6.2-stable_win64.exe/Godot_v4.6.2-stable_win64_console.exe",
)
# Audit pass-count FLOOR: "0 failed" alone can't see tests silently vanishing
# (precedent: the Job-2a extraction cost 6 recordings unnoticed until a manual
# count check). Raise when adding tests; LOWERING needs BASELINE-APPROVED-BY-KEV
# (threshold_guard, inverted polarity — floors loosen downward).
# 228 -> 234 (Build G Lane 2): +2 taunt targeting cases, +4 taunt regressions.
# 236 -> 241 (pure-mark targeting fix): +3 pure-status targeting cases
# (mark/jam/rewrite), +2 mark regressions (chosen-enemy pick, firewall block).
# 241 -> 246 (player-chosen cast order): +2 mark-order, +2 breach-order,
# +1 defensive unstamped-fallback regressions.
# 246 -> 250 (tutorial v2 honest rig): the single kill-math mirror became 5
# regressions (T1 math, T2 kill, stall-proof T1+T2, nudge band jump).
# 250 -> 251 (V3.1 selective-HP re-rig): +1 guard pinning that the drone
# outlives the first round-two guided attack, so neither guided attack can
# fizzle on an already-dead target.
# G-8: +12 frozen-20 and reinforcement-reward assertions.
# G-9: +8 copy/behavior and display-name migration assertions.
# 271 -> 282 (Medic 20-band fallback, NK-17 `else`): the floor had lagged at 271
# while the audit passed 274; +8 fallback/fire-time/directive/readout regressions.
AUDIT_MIN_PASSED = 282

GATES = [
    ("validate-data", ["npm", "run", "validate-data"], "validates against schemas", True),
    # Anti-drift gates (pure-python, fast): a duplicated constant is a bug with a
    # delay fuse — check the copies instead of trusting them to stay in sync.
    ("doc consistency", [sys.executable, str(ROOT / "scripts" / "checks" / "doc_consistency.py")], "[DOC_CONSISTENCY] PASS", False),
    ("knobs contract", [sys.executable, str(ROOT / "scripts" / "checks" / "knobs_contract.py")], "[KNOBS_CONTRACT] PASS", False),
    # Bare autoload identifiers in the compile-time closure of an -s test are a
    # compile error that hangs the test to its timeout (4 incidents). Self-tests
    # by re-injecting every known incident on each run.
    ("autoload closure", [sys.executable, str(ROOT / "scripts" / "checks" / "autoload_closure.py")], "[AUTOLOAD_CLOSURE] PASS", False),
    # Polish Build A: the capitalization law's mechanical subset (data JSON body
    # text, .tscn button text, literal .to_upper()) and the six-component panel
    # contract (no raw styleboxes / strong accents outside PixelUI).
    ("caps law", [sys.executable, str(ROOT / "scripts" / "checks" / "caps_law.py")], "[CAPS_LAW] PASS", False),
    ("component contract", [sys.executable, str(ROOT / "scripts" / "checks" / "component_contract.py")], "[COMPONENT_CONTRACT] PASS", False),
    # Polish Build D: authored ability eff text must carry the target suffix its coded
    # scope requires (NK-17) — self-targeted self-buffs missing (self) was the defect.
    ("effect target", [sys.executable, str(ROOT / "scripts" / "checks" / "effect_text_target.py")], "[EFFECT_TARGET] PASS", False),
    # Build F: no pool draw reaches item data except through DataManager.pool_ids
    # (the choke point), and the unlock buckets stay complete, floored, and equal
    # to the Kev-approved CSV.
    ("pool choke", [sys.executable, str(ROOT / "scripts" / "checks" / "pool_choke.py")], "[POOL_CHOKE] PASS", False),
    ("pool floor", [sys.executable, str(ROOT / "scripts" / "checks" / "unlock_pool_floor.py")], "[POOL_FLOOR] PASS", False),
    # Polish Build B: reward selection model (tap selects, CONFIRM commits) +
    # integer icon law + containment at both inset budgets; and the selection
    # screen's zero-new-framed-panels pin.
    ("reward model", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/reward_model_test.gd"], "[REWARD_MODEL] PASS", False),
    # Playtest 2026-10-01: every scrolling list drag-scrolls on touch from a
    # start ON a button / card / row (phone touch and touch-laptop mouse), a
    # drag never presses, a tap still does; the inspect popup closes on a tap.
    ("touch scroll", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/touch_scroll_test.gd"], "[TOUCH_SCROLL] PASS", False),
    ("panel count", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/panel_count_test.gd"], "[PANEL_COUNT] PASS", False),
    ("boss nameplate", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/boss_nameplate_test.gd"], "[BOSS_NAMEPLATE] PASS", False),
    # Polish Build D: consumable cap (4) + discard picker state machine, relic cap (2)
    # + display, event-consumable pool filter, and the silent-loss/swap contract.
    ("loadout cap", [GODOT, "--headless", "--path", str(ROOT), "scenes/debug/ConsumableLoadoutRunner.tscn"], "[LOADOUT_CAP] PASS", False),
    ("ability audit", [GODOT, "--headless", "--path", str(ROOT), "scenes/debug/AbilityAuditRunner.tscn"], ", 0 failed", False),
    # Boss relic rework (G-34..G-41): every rule + edge case of the seven new
    # relics, the save migration, and the live screen paths.
    ("boss relics", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/boss_relic_test.gd"], "[BOSS_RELICS] PASS", False),
    # Build F: counter integrity (once per encounter entered), run-end-only gate
    # evaluation, delta correctness, boss-relic announcement, sim pin.
    ("unlock progression", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/unlock_progression_test.gd"], "[UNLOCK_PROGRESSION] PASS", False),
    # Operation lore + boss standing rules: accepted flavor metadata, the five
    # LITERAL runtime standing-rule strings reaching the inspect popup, origin
    # persistence/migration, and the surviving overlay modes. Written as a
    # SCENE runner (it builds real overlays and measures their layout), so it
    # runs by .tscn — invoking it with -s strips the autoloads and it fails to
    # compile, which is how it read as broken while it was merely ungated.
    ("operation lore", [GODOT, "--headless", "--path", str(ROOT), "scenes/debug/OperationLorePresentationRunner.tscn"], "[OPERATION_LORE] PASS", False),
    ("visual choices and motion", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/visual_choice_motion_test.gd"], "[VISUAL_CHOICE_MOTION] PASS", False),
    ("float bounds", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/float_bounds_test.gd"], "[FLOAT_BOUNDS] PASS", False),
    ("developer unlock", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/dev_unlock_test.gd"], "[DEV_UNLOCK] PASS", False),
    ("flow smoke", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/flow_smoke_test.gd"], "[FLOW_SMOKE] PASS", False),
    ("tutorial smoke", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/tutorial_smoke_test.gd"], "[TUTORIAL_SMOKE] PASS", False),
    ("tutorial recorded throws", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/tutorial_throw_gate.gd", "--", "--size=1080x2400"], "[TUTORIAL_THROWS] PASS", False),
    ("tutorial recorded throws 540x1200", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/tutorial_throw_gate.gd", "--", "--size=540x1200"], "[TUTORIAL_THROWS] PASS", False),
    # Reachability, not logic: tutorial smoke drives the drill by calling scene
    # handlers directly, so it cannot see a scripted target the player could
    # never hit, nor a gated beat that never advances. This one synthesizes real
    # mouse events at real on-screen rects, including every guided action,
    # resize recovery and clean scene teardown (about 30s).
    ("tutorial reachability", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/tutorial_reachability_test.gd"], "[TUTORIAL_REACH] PASS", False),
    ("primer smoke", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/primer_smoke_test.gd"], "[PRIMER_SMOKE] PASS", False),
    ("music smoke", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/music_smoke_test.gd"], "[MUSIC_SMOKE] PASS", False),
    ("transition smoke", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/transition_smoke_test.gd"], "[TRANSITION_SMOKE] PASS", False),
    ("duration encoding", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/duration_encoding_test.gd"], "[DURATION] PASS", False),
    # Build G: the die numeral shows the JAMMED value (value feed, not the
    # fenced dice renderer). Firewall (ruled 2026-09-02, reversing Build G item
    # 11): portrait corners carry NO status markers — the firewall is a plain
    # bottom-row chip under the shared 3-chip cap and +N overflow, and THE
    # COURT's grant-and-consume-in-one-resolve ward is made visible by
    # BattleFeedback's transient-chip injection.
    ("jam display", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/jam_display_test.gd"], "[JAM_DISPLAY] PASS", False),
    ("firewall display", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/firewall_display_test.gd"], "[FIREWALL_DISPLAY] PASS", False),
    # Build J item 1: the chip-deferral planner (chips land at their CAUSING
    # beat, not at resolve). Written 2026-07-19 and enforced by NOTHING until
    # now — the firewall work above wired THE COURT's transient-chip injection
    # straight through this planner, so the seam was carrying new load with its
    # only regression unrun. Planner-level and headless: no rendered frames.
    ("status timing", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/status_timing_test.gd"], "[STATUS_TIMING] PASS", False),
    # Ruled 2026-09-02: the effect-pip cap keeps 3 but no longer drops the tail
    # SILENTLY — everything past the third folds into a "+N" badge (the chip
    # row's overflow language). Twelve abilities were losing a keyword.
    ("effect pip overflow", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/effect_pip_overflow_test.gd"], "[EFFECT_PIP_OVERFLOW] PASS", False),
    # UI batch 2026-09-27 B2: every icon + number pair (all live abilities, the
    # live Detonate value, a stray-space value) sits exactly icon_value_gap from
    # its icon, measured on the laid-out glyphs in both pip profiles.
    # UI batch 2026-09-27 B7: a hold anywhere on a unit card (portrait, status
    # badge, +N, HP bar, body) opens the unit inspect; a tap selects.
    ("card long press", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/card_long_press_test.gd"], "[CARD_LONG_PRESS] PASS", False),
    ("pip spacing", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/pip_spacing_test.gd"], "[PIP_SPACING] PASS", False),
    # Build G item 3: every item "upgrade" draw succeeds at EVERY unlock state
    # (gating forced, fresh profile included) and ELITE PRESENCE upgrades
    # exactly one slot whenever its precondition holds (non-boss battles).
    ("upgrade draws", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/upgrade_draw_test.gd"], "[UPGRADE_DRAW] PASS", False),
    ("freeze regression", [GODOT, "--headless", "--path", str(ROOT), "scenes/debug/freeze_engine_regression.tscn"], "[FREEZE] RESULT: freeze = repeat", False),
    # Batch 4 combat-bug regressions (each launches a live battle).
    ("protocol cancel", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/protocol_cancel_test.gd"], "[PROTOCOL_CANCEL] PASS", False),
    ("die reroll visual", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/die_reroll_visual_test.gd"], "[DIE_REROLL] PASS", False),
    # P0 dice face (docs/audits/DICE_FACE_AUDIT.md): every slot x all 20 values
    # plus every modifier path (pre-roll: buff, penalty, jam, rewrite, forced
    # 20, Resonant Chorus, frozen 20s; after landing: Nudge, Set, Reroll, items,
    # Sync Antenna, live hijack). G-24..G-30: static labels, acted value,
    # same-face upright snap, modifier ranges, restore, freeze, Set, guards.
    # Mutation proof: scripts/checks/dice_face_mutations.py (separate run).
    # Dice rules (TRUTH "Dice rules"): run at the phone window and the desktop
    # preview window; headless alone is 64x64, which lays the tray out 2400 wide.
    ("dice face", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/dice_face_gate.gd", "--", "--size=1080x2400"], "[DICE_FACE_GATE] PASS", False),
    ("dice face 540x1200", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/dice_face_gate.gd", "--", "--size=540x1200"], "[DICE_FACE_GATE] PASS", False),
    ("auto-target preview", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/auto_target_preview_test.gd"], "[AUTO_PREVIEW] PASS", False),
    ("item burn preview", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/item_burn_preview_test.gd"], "[ITEM_BURN] PASS", False),
    # 2026-09-02, "the damage preview lies": heroes resolve BEFORE the enemy
    # phase, so the forecast has to walk the hero phase first — a doomed enemy
    # stops telegraphing, a taunt redirects the telegraph, and leech healing
    # reaches the net-HP projection.
    ("preview accuracy", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/preview_accuracy_test.gd"], "[PREVIEW_ACCURACY] PASS", False),
    # Playtest 2026-10-01: a taunt picked during planning shows its TAUNT chip
    # on the chosen enemy before End Turn (none when a Firewall will eat it).
    ("taunt planning chip", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/taunt_planning_chip_test.gd"], "[TAUNT_CHIP] PASS", False),
    # Same batch, two "the game told me something untrue" defects: Chain and its
    # siblings floated a SECOND number for one hit, and a revive with no downed
    # ally still played its banner.
    ("feedback honesty", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/feedback_honesty_test.gd"], "[FEEDBACK_HONESTY] PASS", False),
    # The ROLL/END TURN button must not sit on a settled die. The layout was
    # reserving 80px for a die that projects to ~105, so the authored 54px gap
    # was really 29 at 1080x2400.
    ("roll button clearance", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/roll_button_clearance_test.gd"], "[ROLL_CLEARANCE] PASS", False),
    # Landscape battle layout (PARKED 2026-09-25, flag false): policy selection,
    # forced-landscape scene geometry, shared input and spawn regression. Keeps
    # the parked path compiling and correct so re-enabling is a flag flip.
    ("battle layout", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/battle_layout_test.gd"], "[BATTLE_LAYOUT] PASS", False),
    # Android Build #1: safe-area insets (cutout/gesture bar) — header grows,
    # protocol row lifts, desktop reads all-zero (no-regression guarantee).
    ("safe area", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/safe_area_test.gd"], "[SAFE_AREA] PASS", False),
    # Android Build #3: allow_system_fallback=false means an m5x7-uncovered
    # codepoint is a TOFU BOX on device — every player-facing string must pass
    # actual font coverage (has_char), never a hardcoded blocklist.
    ("glyph coverage", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/glyph_coverage_check.gd"], "[GLYPH] PASS", False),
    # G-19 replaces the retired feedback nudge with title-entry and unlock-layout coverage.
    ("title and unlock UI", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/title_unlock_test.gd"], "[TITLE_UNLOCK] PASS", False),
    ("help polish", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/help_polish_test.gd"], "[HELP_POLISH] PASS", False),
    ("final feedback and recovery", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/final_feedback_test.gd"], "[FINAL_FEEDBACK] PASS", False),
    # Save system (Backlog #14). run.json is the ACTIVE RUN; save.json is the
    # profile. Four gates, because they fail in four unrelated ways:
    #   roundtrip  - the save carries the run (and the field-coverage contract:
    #                a new GameState run field must be classified saved or
    #                transient, or this breaks the build instead of presenting
    #                later as a corrupt resume)
    #   integrity  - schema mismatch, corrupt files, an interrupted write, and
    #                the web localStorage-mirror conflict rules
    #   lifecycle  - run.json dies at victory/defeat/abandon while unlocks live,
    #                and battles_fought stays exactly-once across a resume
    #                (INVARIANTS #18: reloading must not farm unlock gates)
    #   resume     - THREE separate Godot processes: a seeded run played straight
    #                through vs the same run saved, reloaded into a fresh scene
    #                tree, and continued. Slower than the rest by design.
    #   schema     - the save's key/type SHAPE is pinned beside RUN_SAVE_VERSION,
    #                so a field added, removed or retyped without a version bump
    #                is a build break here instead of a corrupt resume on a phone
    ("save schema", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/save_schema_test.gd"], "[SAVE_SCHEMA] PASS", False),
    ("save roundtrip", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/save_roundtrip_test.gd"], "[SAVE_ROUNDTRIP] PASS", False),
    ("save integrity", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/save_integrity_test.gd"], "[SAVE_INTEGRITY] PASS", False),
    ("save lifecycle", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/save_lifecycle_test.gd"], "[SAVE_LIFECYCLE] PASS", False),
    ("save resume", [sys.executable, str(ROOT / "scripts" / "checks" / "save_resume_gate.py")], "[SAVE_RESUME] PASS", False),
    ("battle checkpoint", [sys.executable, str(ROOT / "scripts" / "checks" / "battle_checkpoint_gate.py")], "[BATTLE_CHECKPOINT] PASS", False),
    # Dev state code (2026-10-02): export -> separate-process import -> CONTINUE
    # round-trips, the Python decoder agrees, and three deliberate breaks
    # (dropped run save, no checksum, import that writes nothing) must each fail.
    ("state code", [sys.executable, str(ROOT / "scripts" / "checks" / "state_code_gate.py")], "[STATE_CODE] PASS", False),
    # Resume guard (G-48): real menu CONTINUE in separate processes. A resume
    # that dies while loading offers RESUME EARLIER POINT on the next launch, a
    # normal one does not, a mid-battle resume restores its round; four
    # deliberate breaks must each fail.
    ("resume guard", [sys.executable, str(ROOT / "scripts" / "checks" / "resume_guard_gate.py")], "[RESUME_GUARD] PASS", False),
    # G-47: a reroll is a hop in the die's own slot (uniform faces, no contact,
    # never leaves its slot, the snap never changes the face) + 4 deliberate breaks.
    ("reroll hop", [sys.executable, str(ROOT / "scripts" / "checks" / "reroll_hop_gate.py")], "[REROLL_HOP_GATE] PASS", False),
    # G-49: the two Settings options, each off and on, then deliberate breaks
    # that must fail (break_gate.py: a clean pass alone proves nothing).
    ("auto-select target", [sys.executable, str(ROOT / "scripts" / "checks" / "break_gate.py"), "--tag", "AUTO_PICK",
        "--script", "scripts/debug/auto_pick_test.gd", "--break-arg=--auto-pick-break=", "--breaks", "off,any_count,no_cue"],
        "[AUTO_PICK_GATE] PASS", False),
    ("no animations", [sys.executable, str(ROOT / "scripts" / "checks" / "break_gate.py"), "--tag", "NO_ANIMATIONS",
        "--script", "scripts/debug/no_animations_test.gd", "--break-arg=--no-animations-break=", "--breaks", "ignored,silent_stinger"],
        "[NO_ANIMATIONS_GATE] PASS", False),
    # A Nudge that changes a hero's ability logs nothing (the hero waits with no
    # stale target for the forecast to run unstamped); break: the stale target.
    ("nudge cast order", [sys.executable, str(ROOT / "scripts" / "checks" / "break_gate.py"), "--tag", "NUDGE_CAST_ORDER",
        "--script", "scripts/debug/nudge_cast_order_test.gd", "--break-arg=--nudge-cast-order-break=", "--breaks", "stale_target"],
        "[NUDGE_CAST_ORDER_GATE] PASS", False),
    # Playtest 2026-10-08: an ability that does not attack shakes in place
    # instead of standing still. Motion class per ability (all of them), a live
    # round, Reduced Motion and No animations; four deliberate breaks.
    ("action motion", [sys.executable, str(ROOT / "scripts" / "checks" / "break_gate.py"), "--tag", "ACTION_MOTION",
        "--script", "scripts/debug/action_motion_test.gd", "--break-arg=--action-motion-break=",
        "--breaks", "no_wiggle,all_lunge,reduced_full,no_anim_ignored"],
        "[ACTION_MOTION_GATE] PASS", False),
    # Playtest 2026-10-08: every effect a Firewall cancels says so (BLOCKED
    # chip + a log line naming it). 30 cases over the 25 call sites, a live
    # taunt into a Firewall, the chip under each motion setting; four breaks.
    ("firewall feedback", [sys.executable, str(ROOT / "scripts" / "checks" / "break_gate.py"), "--tag", "FIREWALL_FEEDBACK",
        "--script", "scripts/debug/firewall_feedback_test.gd", "--break-arg=--firewall-feedback-break=",
        "--breaks", "silent_taunt,old_log,no_chip,animated_chip"],
        "[FIREWALL_FEEDBACK_GATE] PASS", False),
    # Playtest 2026-10-08: an Accrete shows the shield it applied (chip, log,
    # shield chip on that beat) and the inspect names amount and cadence.
    ("accrete display", [sys.executable, str(ROOT / "scripts" / "checks" / "break_gate.py"), "--tag", "ACCRETE_DISPLAY",
        "--script", "scripts/debug/accrete_display_test.gd", "--break-arg=--accrete-display-break=",
        "--breaks", "asked,no_chip,stale_chip,no_line"],
        "[ACCRETE_DISPLAY_GATE] PASS", False),
    # Cloak ambush (G-52, Kev 2026-10-08): the attack that breaks a cloak deals
    # +50% damage, once, on both sides; every target cloaked -> one is hit at
    # random; the cloak chip, inspect, keyword and primer name the bonus.
    ("cloak ambush", [sys.executable, str(ROOT / "scripts" / "checks" / "break_gate.py"), "--tag", "CLOAK_AMBUSH",
        "--script", "scripts/debug/cloak_ambush_test.gd", "--break-arg=--cloak-ambush-break=",
        "--breaks", "no_bonus,always,keep_cloak,fizzle,first,no_chip"],
        "[CLOAK_AMBUSH_GATE] PASS", False),
    # Roll windows (G-53, Kev 2026-10-08): every hero, evolution and enemy kit
    # has five contiguous bands covering 1-20, and only Pyro, Wraith and Spine
    # Stalker have a top band wider than the 20. Static over the data (twelve
    # in-memory breaks), then the loaded resources, the inspect table
    # and the band-shifting gear at run time (two breaks).
    ("roll windows", [sys.executable, str(ROOT / "scripts" / "checks" / "roll_windows.py")], "[ROLL_WINDOWS] PASS", False),
    ("roll windows live", [sys.executable, str(ROOT / "scripts" / "checks" / "break_gate.py"), "--tag", "ROLL_WINDOWS_LIVE",
        "--script", "scripts/debug/roll_windows_test.gd", "--break-arg=--roll-windows-break=",
        "--breaks", "shared_table,squeeze"],
        "[ROLL_WINDOWS_LIVE_GATE] PASS", False),
    # Rampage and pack bonus (G-60): rampage is on or off, lasts until the
    # unit's next turn and is spent by it; pack bonus is +3 per packmate and
    # every printed copy agrees. Breaks: the old stacking, the old carry-over,
    # the old +1.
    ("rampage", [sys.executable, str(ROOT / "scripts" / "checks" / "break_gate.py"), "--tag", "RAMPAGE",
        "--script", "scripts/debug/rampage_test.gd", "--break-arg=--rampage-break=",
        "--breaks", "stack,keep,pack_one"],
        "[RAMPAGE_GATE] PASS", False),
    # Geode Panther (G-61): an attack that freezes one die hits the hero it
    # freezes, the lowest die, in combat and in the intent shown while
    # planning. Breaks: the hit aimed apart from the freeze again; a planning
    # pick read from last round's dice.
    ("geode targeting", [sys.executable, str(ROOT / "scripts" / "checks" / "break_gate.py"), "--tag", "GEODE_TARGET",
        "--script", "scripts/debug/geode_target_test.gd", "--break-arg=--geode-break=",
        "--breaks", "split,stale"],
        "[GEODE_TARGET_GATE] PASS", False),
    # Unit traits (G-62): who has one (the ruling's roster), all 26 rules by
    # their data numbers, Static and Zealous through the die's one value, the
    # log line and chip on every trigger, the inspect / card / copy, and a
    # live round. Breaks: traits off, no chip, frozen dice moved, Zealous before
    # Static, a trait on every unit that should have none.
    ("traits", [sys.executable, str(ROOT / "scripts" / "checks" / "break_gate.py"), "--tag", "TRAITS",
        "--script", "scripts/debug/traits_test.gd", "--break-arg=--trait-break=",
        "--breaks", "off,no_chip,frozen_dice,litany_first,boss_trait"],
        "[TRAITS_GATE] PASS", False),
    # Trait preview (G-65): a card's HP bar ends where the round really leaves
    # the unit, for every trait that moves a previewed number, plus Rampage and
    # the pack bonus. The preview dry-runs the whole round with the real combat
    # code. Breaks: the dry run blind to traits, and stopped after the hero
    # phase (the preview as it was).
    ("trait preview", [sys.executable, str(ROOT / "scripts" / "checks" / "break_gate.py"), "--tag", "TRAIT_PREVIEW",
        "--script", "scripts/debug/trait_preview_test.gd", "--break-arg=--preview-break=",
        "--breaks", "trait_blind,hero_phase_only"],
        "[TRAIT_PREVIEW_GATE] PASS", False),
    # Two-tier sim gate (G-58). Part A: the size line and the tripwire on made-up
    # figures, with in-memory breaks (the old 10-point line, a blind tripwire,
    # an unlinked pin). Part B: a REAL change of about 10 points on one
    # operation (+8% enemy damage in the Hive, ci_smoke.SIZE_BREAK_TUNING) run
    # through the 1,500-run size check, which must flag it. Part B runs only
    # when scripts/sim/ci_smoke.py or a pin file changed since it last passed
    # (scripts/sim/size_break_stamp.json, G-59); otherwise this gate is instant.
    ("sim size break", [sys.executable, str(ROOT / "scripts" / "checks" / "sim_size_break.py")], "[SIM_SIZE_BREAK] PASS", False),
    ("web loader palette", [sys.executable, str(ROOT / "scripts" / "checks" / "web_loader_palette.py")], "[WEB_LOADER_PALETTE] PASS", False),
    # App-switch freeze: the shell's lost-display overlay and the menu's
    # automatic resume share a flag key by copy; plus listener order and copy.
    ("web display recovery", [sys.executable, str(ROOT / "scripts" / "checks" / "web_display_recovery.py")], "[WEB_DISPLAY_RECOVERY] PASS", False),
    ("wording fit", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/wording_fit_test.gd"], "[WORDING_FIT] PASS", False),
    # Text legibility Step 1 (docs/audits/TEXT_LEGIBILITY_AUDIT.md): every live
    # text node samples NEAREST and renders >= PixelUI.TEXT_MIN_PX; the ladder,
    # the theme mirror, popup grid alignment and the INSPECT_TEXT_DIM contrast
    # floor are asserted at the source.
    ("text legibility", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/text_legibility_test.gd"], "[TEXT_LEGIBILITY] PASS", False),
    ("checkpoint lifecycle", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/checkpoint_lifecycle_test.gd"], "[CHECKPOINT_LIFECYCLE] PASS", False),
    # Framing (docs/tools/FRAMING_TOOL.md): ONE framing entry per asset in
    # portrait_anchors.json — ids exist and values are in range; every
    # portrait/item/relic display site goes through its PixelUI helper and the
    # dev/ editor is excluded from every export preset; the editor edits,
    # previews, undoes and saves; the capture sheet renders one sample of each
    # asset type on every screen that shows it (windowed: needs a renderer).
    ("framing data", [sys.executable, str(ROOT / "scripts" / "checks" / "framing_data.py")], "[FRAMING_DATA] PASS", False),
    ("framing sites", [sys.executable, str(ROOT / "scripts" / "checks" / "framing_sites.py")], "[FRAMING_SITES] PASS", False),
    ("framing editor", [GODOT, "--headless", "--path", str(ROOT), "res://dev/framing_editor/FramingEditorTest.tscn"], "[FRAMING_EDITOR] PASS", False),
    ("framing sheet", [GODOT, "--path", str(ROOT), "res://dev/framing_editor/FramingEditor.tscn", "--framing-sheet=res://debug_artifacts/framing/capture_sheet.png"], "[FRAMING_SHEET] PASS", False),
]


# ── Profile isolation (Kev 2026-07-12) ──────────────────────────────────────
# No test or rig may touch the REAL player profile. DevContext redirects every
# dev-context launch to dev_* scratch files (structural); this gate proves it
# stays that way: fingerprint the real files before the suite, fail on any
# change after. Precedent: a windowed capture rig wiped and repopulated the
# real primer ledger, which then presented as a game bug.
# run.json joins the fingerprint with the save system: an active-run save is
# player data too, and a rig that escaped DevContext could now destroy a run in
# progress as well as a profile.
REAL_PROFILE_FILES = ["save.json", "settings.cfg", "run.json", "run.json.prev", "resume_guard.json"]


def _real_profile_dir() -> Path:
    return Path(os.environ.get("APPDATA", "")) / "Godot" / "app_userdata" / "Overload Protocol"


def profile_fingerprint() -> dict:
    fp = {}
    base = _real_profile_dir()
    for name in REAL_PROFILE_FILES:
        p = base / name
        fp[name] = hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None
    return fp


def check_profile_isolation(before: dict) -> bool:
    print("── profile isolation ...", flush=True)
    after = profile_fingerprint()
    dirty = [name for name in before if before[name] != after[name]]
    if dirty:
        print(f"   FAIL — the suite WROTE the real player profile: {', '.join(dirty)}")
        print("   A test or rig escaped DevContext isolation (scripts/autoloads/dev_context.gd).")
        return False
    print("   PASS")
    return True


# ── Per-gate hard timeout (Kev 2026-07-15, after the jam-test zombie round) ─
# A smoke that can't finish in 90 seconds is FAILED by definition — the old
# blanket 600s let one hung headless instance eat 10 minutes per gate. The
# named budgets below are the only sanctioned exceptions (structurally heavy
# suites, never a plain smoke); each is still minutes under the old ceiling.
# Budgets only ratchet DOWN for free (INVARIANTS #13); every PASS line prints
# its elapsed seconds so tightening is data, not guesswork.
GATE_TIMEOUT_DEFAULT = 90
GATE_TIMEOUT_OVERRIDES = {
    "validate-data": 180,       # npm cold start
    "ability audit": 420,       # 228+ recorded regressions, one process
    "flow smoke": 300,          # walks the entire scene flow twice
    "loadout cap": 180,         # scene runner boot + discard state machine
    "unlock progression": 180,  # full-run counter + gate-evaluation walk
    "tutorial smoke": 180,      # 23 scripted steps
    "upgrade draws": 180,       # 18 unlock states x 5 seeds x every draw
    "save resume": 420,         # 6 full Godot processes (2 configs x 3 legs)
    "battle checkpoint": 360,   # 10 Godot processes (2 configs x 3 legs + 4 fallback legs); ~160s measured
    "state code": 300,          # 8 Godot processes (round trip + 3 deliberate breaks); ~70s measured on Linux
    "resume guard": 150,        # 15 Godot processes (8 legs + 5 deliberate breaks); ~52s measured on Windows before the 4 display-recovery processes
    "dice face": 240,           # (k) on every physics step + part S six-die stress; ~100s measured on Linux
    "dice face 540x1200": 240,  # same gate at the half-size window; ~100s measured on Linux
    "reroll hop": 300,          # 10,000 hops in 8 shards + 5 break legs; ~185s measured on Windows
    "sim size break": 600,      # instant unless ci_smoke.py or the pins changed (G-59); then a 300-run tripwire + one 1,500-run sim batch, ~240s measured on Windows
}


def kill_lingering_headless() -> None:
    """Pre-run cleanup: a zombie headless instance from a hung test poisons
    every later gate (contention -> cascade timeouts). Kill anything Godot
    launched with --headless; NEVER the editor (no --headless on its line)."""
    if os.name != "nt":
        return
    ps = (
        "Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | "
        "Where-Object { $_.CommandLine -match '--headless' } | "
        "ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; $_.ProcessId }"
    )
    try:
        proc = subprocess.run(
            ["powershell", "-NoProfile", "-Command", ps],
            capture_output=True, text=True, timeout=30,
        )
        killed = [line for line in (proc.stdout or "").split() if line.strip().isdigit()]
        if killed:
            print(f"── pre-run cleanup: killed {len(killed)} lingering headless Godot instance(s): {', '.join(killed)}", flush=True)
    except Exception as exc:  # noqa: BLE001 — cleanup must never block the gate
        print(f"── pre-run cleanup skipped ({exc})", flush=True)


def run_gate(name: str, cmd: list, needle: str, use_shell: bool) -> bool:
    print(f"── {name} ...", flush=True)
    budget = GATE_TIMEOUT_OVERRIDES.get(name, GATE_TIMEOUT_DEFAULT)
    started = time.monotonic()
    try:
        proc = subprocess.run(
            " ".join(cmd) if use_shell else cmd,
            shell=use_shell, cwd=ROOT, capture_output=True, text=True, timeout=budget,
        )
    except subprocess.TimeoutExpired:
        print(f"   FAIL (TIMEOUT after {budget}s — a test that can't finish in its budget is failed by definition)")
        return False
    except Exception as exc:  # noqa: BLE001 — a dead gate must print, not raise
        print(f"   FAIL ({exc})")
        return False
    elapsed = time.monotonic() - started
    out = (proc.stdout or "") + (proc.stderr or "")
    ok = needle in out
    if name == "tutorial reachability":
        ok = ok and proc.returncode == 0 and "ERROR:" not in out
    if name == "ability audit":
        ok = ok and "FAIL" not in out.replace("0 failed", "")
        m = re.search(r"Ability Audit Complete: (\d+) passed", out)
        if m and int(m.group(1)) < AUDIT_MIN_PASSED:
            print(f"   FAIL — audit recorded {m.group(1)} passes, floor is {AUDIT_MIN_PASSED}: tests are silently vanishing")
            ok = False
    print(f"   {'PASS' if ok else 'FAIL'} ({elapsed:.0f}s / {budget}s)")
    if not ok:
        tail = "\n".join(out.strip().splitlines()[-12:])
        print(f"   ── last output ──\n{tail}")
    return ok


def sim_deltas() -> int:
    sys.path.insert(0, str(ROOT / "scripts" / "sim"))
    import ci_smoke  # noqa: E402 — the pinned config, pins and thresholds: one source of truth

    return ci_smoke.run_two_tier()


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    ap = argparse.ArgumentParser(description="Full verification gate + baseline delta table")
    ap.add_argument("--skip-sim", action="store_true")
    ap.add_argument("--only", default="", help="comma-separated gate names: run just these (no sim leg, no profile check, no pre-run cleanup)")
    ap.add_argument("--list", action="store_true", help="print the gate names and exit")
    args = ap.parse_args()

    if args.list:
        for name, _cmd, _needle, _sh in GATES:
            print(name)
        return 0
    # Working rules (root CLAUDE.md, G-59): during a task, run the gates the
    # change touches, by name. No cleanup here: it would kill a sim batch or
    # another gate running beside this one.
    if args.only:
        wanted = [name.strip() for name in args.only.split(",") if name.strip()]
        known = {name for name, _cmd, _needle, _sh in GATES}
        unknown = [name for name in wanted if name not in known]
        if unknown:
            print(f"GATE FAILED: no gate named {', '.join(unknown)} (see --list)")
            return 1
        failed = [name for name, cmd, needle, sh in GATES if name in wanted and not run_gate(name, cmd, needle, sh)]
        print(f"\n{len(wanted) - len(failed)} of {len(wanted)} named gate(s) PASS." + (f" FAILED: {', '.join(failed)}" if failed else ""))
        return 1 if failed else 0

    kill_lingering_headless()
    profile_before = profile_fingerprint()
    failed = [name for name, cmd, needle, sh in GATES if not run_gate(name, cmd, needle, sh)]
    if not check_profile_isolation(profile_before):
        failed.append("profile isolation")
    if failed:
        print(f"\nGATE FAILED: {', '.join(failed)}")
        return 1
    if args.skip_sim:
        print("\nAll hard gates PASS (sim skipped).")
        return 0
    try:
        rc = sim_deltas()
    except Exception as exc:  # noqa: BLE001 — a crashed sim leg must FAIL loudly
        print(f"\nGATE FAILED: balance sim crashed ({exc})")
        return 1
    if rc == 1:
        print("\nGATE FAILED: balance sim pins (see above)")
        return 1
    print("\nAll hard gates PASS." + ("" if rc == 0 else " A real move beyond the size line needs the ceremony — see above."))
    return rc


if __name__ == "__main__":
    sys.exit(main())
