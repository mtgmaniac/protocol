#!/usr/bin/env python3
"""The full verification gate, one command (successor kit, 2026-07-06).

Runs every hard gate, then the balance sim, and prints per-op clear-rate deltas
vs scripts/sim/baseline.json as a table. Dumb and loud on purpose.

  python scripts/verify_gate.py                # everything (sim = 300 runs, ~minutes)
  python scripts/verify_gate.py --skip-sim     # hard gates only (fast)
  python scripts/verify_gate.py --runs 100     # quicker, noisier sim

Exit codes: 0 = all green · 1 = a hard gate FAILED · 3 = gates green but a
per-op delta exceeds the ±10-point ceremony line (baseline update requires
Kev's sign-off: commit message must contain BASELINE-APPROVED-BY-KEV — see
docs/INVARIANTS.md #9).
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
BASELINE = ROOT / "scripts" / "sim" / "baseline.json"
CEREMONY_PTS = 10.0  # per-op clear-rate points
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
AUDIT_MIN_PASSED = 251

GATES = [
    ("validate-data", ["npm", "run", "validate-data"], "validates against schemas", True),
    # Anti-drift gates (pure-python, fast): a duplicated constant is a bug with a
    # delay fuse — check the copies instead of trusting them to stay in sync.
    ("doc consistency", [sys.executable, str(ROOT / "scripts" / "checks" / "doc_consistency.py")], "[DOC_CONSISTENCY] PASS", False),
    ("knobs contract", [sys.executable, str(ROOT / "scripts" / "checks" / "knobs_contract.py")], "[KNOBS_CONTRACT] PASS", False),
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
    ("panel count", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/panel_count_test.gd"], "[PANEL_COUNT] PASS", False),
    # Polish Build D: consumable cap (4) + discard picker state machine, relic cap (2)
    # + display, event-consumable pool filter, and the silent-loss/swap contract.
    ("loadout cap", [GODOT, "--headless", "--path", str(ROOT), "scenes/debug/ConsumableLoadoutRunner.tscn"], "[LOADOUT_CAP] PASS", False),
    ("ability audit", [GODOT, "--headless", "--path", str(ROOT), "scenes/debug/AbilityAuditRunner.tscn"], ", 0 failed", False),
    # Build F: counter integrity (once per encounter entered), run-end-only gate
    # evaluation, delta correctness, boss-relic announcement, sim pin.
    ("unlock progression", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/unlock_progression_test.gd"], "[UNLOCK_PROGRESSION] PASS", False),
    ("flow smoke", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/flow_smoke_test.gd"], "[FLOW_SMOKE] PASS", False),
    ("tutorial smoke", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/tutorial_smoke_test.gd"], "[TUTORIAL_SMOKE] PASS", False),
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
    # Build G item 3: every item "upgrade" draw succeeds at EVERY unlock state
    # (gating forced, fresh profile included) and ELITE PRESENCE upgrades
    # exactly one slot whenever its precondition holds (non-boss battles).
    ("upgrade draws", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/upgrade_draw_test.gd"], "[UPGRADE_DRAW] PASS", False),
    ("freeze regression", [GODOT, "--headless", "--path", str(ROOT), "scenes/debug/freeze_engine_regression.tscn"], "[FREEZE] RESULT: freeze = repeat", False),
    # Batch 4 combat-bug regressions (each launches a live battle).
    ("protocol cancel", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/protocol_cancel_test.gd"], "[PROTOCOL_CANCEL] PASS", False),
    ("die reroll visual", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/die_reroll_visual_test.gd"], "[DIE_REROLL] PASS", False),
    ("auto-target preview", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/auto_target_preview_test.gd"], "[AUTO_PREVIEW] PASS", False),
    ("item burn preview", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/item_burn_preview_test.gd"], "[ITEM_BURN] PASS", False),
    # 2026-09-02, "the damage preview lies": heroes resolve BEFORE the enemy
    # phase, so the forecast has to walk the hero phase first — a doomed enemy
    # stops telegraphing, a taunt redirects the telegraph, and leech healing
    # reaches the net-HP projection.
    ("preview accuracy", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/preview_accuracy_test.gd"], "[PREVIEW_ACCURACY] PASS", False),
    # Same batch, two "the game told me something untrue" defects: Chain and its
    # siblings floated a SECOND number for one hit, and a revive with no downed
    # ally still played its banner.
    ("feedback honesty", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/feedback_honesty_test.gd"], "[FEEDBACK_HONESTY] PASS", False),
    # The ROLL/END TURN button must not sit on a settled die. The layout was
    # reserving 80px for a die that projects to ~105, so the authored 54px gap
    # was really 29 at 1080x2400.
    ("roll button clearance", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/roll_button_clearance_test.gd"], "[ROLL_CLEARANCE] PASS", False),
    # Android Build #1: safe-area insets (cutout/gesture bar) — header grows,
    # protocol row lifts, desktop reads all-zero (no-regression guarantee).
    ("safe area", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/safe_area_test.gd"], "[SAFE_AREA] PASS", False),
    # Android Build #3: allow_system_fallback=false means an m5x7-uncovered
    # codepoint is a TOFU BOX on device — every player-facing string must pass
    # actual font coverage (has_char), never a hardcoded blocklist.
    ("glyph coverage", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/glyph_coverage_check.gd"], "[GLYPH] PASS", False),
    # Stranger-readiness: feedback-nudge cadence (1st run, every 3rd, dismissal
    # skips one) + save/load round trip of the cadence state.
    ("feedback nudge", [GODOT, "--headless", "--path", str(ROOT), "-s", "scripts/debug/feedback_nudge_test.gd"], "[FEEDBACK_NUDGE_TEST] PASS", False),
]


# ── Profile isolation (Kev 2026-07-12) ──────────────────────────────────────
# No test or rig may touch the REAL player profile. DevContext redirects every
# dev-context launch to dev_* scratch files (structural); this gate proves it
# stays that way: fingerprint the real files before the suite, fail on any
# change after. Precedent: a windowed capture rig wiped and repopulated the
# real primer ledger, which then presented as a game bug.
REAL_PROFILE_FILES = ["save.json", "settings.cfg"]


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


def sim_deltas(runs: int) -> int:
    sys.path.insert(0, str(ROOT / "scripts" / "sim"))
    import ci_smoke  # noqa: E402 — reuse the pinned batch config, one source of truth

    print(f"── balance sim ({runs} runs, pinned ci_smoke config) ...", flush=True)
    cur = ci_smoke.build_metrics(runs)
    base = json.loads(BASELINE.read_text())
    print(f"\n   overall clear: {base['overall_clear']:.4f} -> {cur['overall_clear']:.4f} "
          f"({(cur['overall_clear'] - base['overall_clear']) * 100:+.1f} pts)")
    print(f"   {'operation':<18}{'baseline':>10}{'current':>10}{'delta':>9}")
    beyond = []
    for op in sorted(base["clear_by_op"]):
        b = base["clear_by_op"][op]
        c = cur["clear_by_op"].get(op, 0.0)
        d = (c - b) * 100
        flag = "  <-- BEYOND ±10" if abs(d) > CEREMONY_PTS else ""
        if flag:
            beyond.append(op)
        print(f"   {op:<18}{b:>10.4f}{c:>10.4f}{d:>+8.1f}{flag}")
    if beyond:
        # Acknowledged-drift carve-out (Kev ruling 2026-07-30): the ceremony
        # warning is silenced ONLY while the deterministic metrics match the
        # signed-off snapshot EXACTLY — any further movement re-raises it, so
        # enforcement is not loosened (nothing new can hide behind the
        # acknowledgment). This is not a re-pin: baseline.json is untouched
        # and ci_smoke standalone stays red on purpose.
        if _drift_is_acknowledged(cur):
            print(
                "\n   Drift previously ACKNOWLEDGED (Kev 2026-07-30, pre-demo ceremony\n"
                "   debt — see scripts/sim/acknowledged_drift.json and\n"
                "   docs/balance_snapshot_2026-07.md). Baseline re-pin is the first\n"
                "   task of the next balance cycle. Not a new failure."
            )
            return 0
        print(
            "\n   ⚠ CEREMONY: per-op drift beyond ±10 points ({}). A human signs off\n"
            "   on drift this size (precedents: voidCirclet +26, freeze=repeat −27.7).\n"
            "   Do NOT run ci_smoke.py --update-baseline; the baseline commit must\n"
            "   contain BASELINE-APPROVED-BY-KEV or the commit-msg hook aborts it."
            .format(", ".join(beyond))
        )
        return 3
    print("   within tolerance.")
    return 0


# True only when the current metrics EXACTLY match the acknowledged snapshot
# (overall + per-op + per-hero, tiny float epsilon). The sim is deterministic,
# so an unchanged tree reproduces the snapshot bit-for-bit; any behavior change
# breaks the match and the full ceremony warning returns.
ACKNOWLEDGED_DRIFT = ROOT / "scripts" / "sim" / "acknowledged_drift.json"

def _drift_is_acknowledged(cur: dict) -> bool:
    if not ACKNOWLEDGED_DRIFT.exists():
        return False
    try:
        ack = json.loads(ACKNOWLEDGED_DRIFT.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return False
    eps = 1e-9
    if abs(cur.get("overall_clear", -1) - ack.get("overall_clear", -2)) > eps:
        return False
    for key in ("clear_by_op", "clear_by_hero"):
        cur_map, ack_map = cur.get(key, {}), ack.get(key, {})
        if set(cur_map) != set(ack_map):
            return False
        if any(abs(cur_map[k] - ack_map[k]) > eps for k in ack_map):
            return False
    return True


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    ap = argparse.ArgumentParser(description="Full verification gate + baseline delta table")
    ap.add_argument("--skip-sim", action="store_true")
    ap.add_argument("--runs", type=int, default=300)
    args = ap.parse_args()

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
        rc = sim_deltas(args.runs)
    except Exception as exc:  # noqa: BLE001 — a crashed sim leg must FAIL loudly
        print(f"\nGATE FAILED: balance sim crashed ({exc})")
        return 1
    print("\nAll hard gates PASS." + ("" if rc == 0 else " Balance drift needs the ceremony — see above."))
    return rc


if __name__ == "__main__":
    sys.exit(main())
